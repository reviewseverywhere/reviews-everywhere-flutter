'use strict';

// functions/auth/shopifyCustomerLogin.js
//
// Client-required step 6 (Normal login; no emails, no redirects, no Shopify UI):
// - customerAccessTokenCreate(email, password)
// - customer(customerAccessToken) -> customer.id
// - Verify downstream entitlement (accounts/{customerId}.planStatus === 'active')
// - Issue Firebase Custom Token (uid = Shopify customerId)

const admin = require('firebase-admin');
const { HttpsError } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');
const { storefrontRequest } = require('./shopifyStorefrontClient');

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

function normalizeEmail(emailRaw) {
  return String(emailRaw || '').trim().toLowerCase();
}

function looksLikeEmail(v) {
  return typeof v === 'string' && v.includes('@') && v.includes('.');
}

function firstForwardedFor(xff) {
  if (!xff) return null;
  const s = String(xff);
  return s.split(',')[0].trim() || null;
}

function tokenFp(token) {
  const t = String(token || '').trim();
  if (!t) return null;
  return `len=${t.length},last6=${t.slice(-6)}`;
}

async function ensureAuthUserByUidAndEmail(uid, emailRaw) {
  const auth = admin.auth();

  try {
    const u = await auth.getUser(uid);
    if (!u.email) {
      await auth.updateUser(uid, { email: emailRaw, emailVerified: true });
    }
    return u;
  } catch (e) {
    if (e?.code !== 'auth/user-not-found') throw e;
  }

  try {
    const byEmail = await auth.getUserByEmail(emailRaw);
    if (byEmail.uid !== uid) {
      throw new HttpsError(
        'failed-precondition',
        'Identity conflict: Firebase user already exists for this email. Please contact support.'
      );
    }
    return byEmail;
  } catch (e) {
    if (e?.code !== 'auth/user-not-found') throw e;
  }

  return await auth.createUser({ uid, email: emailRaw, emailVerified: true });
}

/**
 * Callable: shopifyCustomerLogin
 * Input: { email, password }
 * Output: { ok, accountId, planStatus, firebaseToken }
 */
async function shopifyCustomerLoginCallable(req, storefrontAccessToken) {
  const shopDomain = String(process.env.SHOPIFY_SHOP_DOMAIN || '').trim();
  const apiVersion = String(process.env.SHOPIFY_STOREFRONT_API_VERSION || '2024-10').trim();

  // ✅ Prefer deployed secret env var; fallback for local dev.
  const accessToken = (
    storefrontAccessToken ||
    String(
      process.env.SHOPIFY_STOREFRONT_PRIVATE_TOKEN ||
      process.env.SHOPIFY_STOREFRONT_ACCESS_TOKEN ||
      ''
    )
  ).trim();

  const emailRaw = String(req.data?.email || '').trim();
  const password = String(req.data?.password || '').trim();
  const emailLower = normalizeEmail(emailRaw);

  logger.info('[shopifyCustomerLogin] start', {
    shopDomain,
    apiVersion,
    emailLower,
    hasTokenParam: !!storefrontAccessToken,
    hasPrivateTokenEnv: !!process.env.SHOPIFY_STOREFRONT_PRIVATE_TOKEN,
    hasAccessTokenEnv: !!process.env.SHOPIFY_STOREFRONT_ACCESS_TOKEN,
    tokenFp: tokenFp(accessToken),
    ua: String(req.rawRequest?.headers?.['user-agent'] || '').slice(0, 160),
  });

  if (!shopDomain) throw new HttpsError('failed-precondition', 'Missing SHOPIFY_SHOP_DOMAIN.');
  if (!accessToken) throw new HttpsError('failed-precondition', 'Missing Storefront access token.');
  if (!looksLikeEmail(emailLower)) throw new HttpsError('invalid-argument', 'Valid email is required.');
  if (!password) throw new HttpsError('invalid-argument', 'Password is required.');

  const buyerIp =
    firstForwardedFor(req.rawRequest?.headers?.['x-forwarded-for']) ||
    req.rawRequest?.ip ||
    null;

  // 1) Create customer access token
  const loginMutation = `
    mutation customerAccessTokenCreate($input: CustomerAccessTokenCreateInput!) {
      customerAccessTokenCreate(input: $input) {
        customerAccessToken { accessToken expiresAt }
        customerUserErrors { code field message }
      }
    }
  `;

  let data;
  try {
    data = await storefrontRequest({
      shopDomain,
      apiVersion,
      accessToken,
      query: loginMutation,
      variables: { input: { email: emailRaw, password } },
      buyerIp: buyerIp || undefined,
      label: 'customerAccessTokenCreate',
    });
  } catch (e) {
    logger.error('[shopifyCustomerLogin] Storefront login call failed', {
      message: String(e?.message || e),
      emailLower,
      shopDomain,
      apiVersion,
    });
    throw new HttpsError('internal', 'Login failed (Shopify Storefront error).');
  }

  const payload = data?.customerAccessTokenCreate;
  const errs = payload?.customerUserErrors || [];

  if (errs.length || !payload?.customerAccessToken?.accessToken) {
    logger.info('[shopifyCustomerLogin] invalid credentials', { emailLower, errs });
    throw new HttpsError('unauthenticated', 'Invalid email or password.');
  }

  const customerAccessToken = payload.customerAccessToken.accessToken;

  // 2) Fetch customer identity (id/email)
  const customerQuery = `
    query customer($customerAccessToken: String!) {
      customer(customerAccessToken: $customerAccessToken) {
        id
        email
      }
    }
  `;

  let data2;
  try {
    data2 = await storefrontRequest({
      shopDomain,
      apiVersion,
      accessToken,
      query: customerQuery,
      variables: { customerAccessToken },
      buyerIp: buyerIp || undefined,
      label: 'customerQuery',
    });
  } catch (e) {
    logger.error('[shopifyCustomerLogin] Storefront customer query failed', {
      message: String(e?.message || e),
      emailLower,
      shopDomain,
      apiVersion,
    });
    throw new HttpsError('internal', 'Login failed (Shopify Storefront error).');
  }

  const gid = data2?.customer?.id || '';
  const m = /\/Customer\/(\d+)$/.exec(gid);
  const shopifyCustomerId = m ? m[1] : null;

  if (!shopifyCustomerId) {
    logger.error('[shopifyCustomerLogin] missing customer id', { gid });
    throw new HttpsError('failed-precondition', 'Unable to resolve Shopify customer.');
  }

  // 3) Downstream entitlement check
  const accRef = db.collection('accounts').doc(String(shopifyCustomerId));
  const accSnap = await accRef.get();

  if (!accSnap.exists) {
    throw new HttpsError(
      'failed-precondition',
      'Account not found yet. If you purchased recently, wait a moment for sync and try again.'
    );
  }

  const acc = accSnap.data() || {};
  const planStatus = String(acc.planStatus || '');

  if (planStatus !== 'active') {
    throw new HttpsError(
      'permission-denied',
      `Account not active (planStatus=${planStatus}). Please purchase or contact support.`
    );
  }

  // 4) Ensure Firebase Auth user (uid = Shopify customerId) and issue custom token
  await ensureAuthUserByUidAndEmail(String(shopifyCustomerId), emailRaw);

  const firebaseToken = await admin.auth().createCustomToken(String(shopifyCustomerId), {
    accountId: String(shopifyCustomerId),
    emailLower,
    identityProvider: 'shopify_password',
  });

  await accRef.set(
    {
      authUid: String(shopifyCustomerId),
      authLinkedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
      lastLoginAtMs: Date.now(),
      lastLoginProvider: 'shopify_password',
    },
    { merge: true }
  );

  return {
    ok: true,
    accountId: String(shopifyCustomerId),
    planStatus,
    firebaseToken,
  };
}

module.exports = { shopifyCustomerLoginCallable };
