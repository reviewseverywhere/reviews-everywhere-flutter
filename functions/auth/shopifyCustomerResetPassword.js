'use strict';

// functions/auth/shopifyCustomerResetPassword.js
//
// Client-required step 5:
// - App receives a deep link token from the email.
// - Backend calls Storefront API to set the password on Shopify.
//
// ✅ Supports BOTH:
// 1) Reset email:    /account/reset/...    -> customerResetByUrl
// 2) Invite email:   /account/activate/... -> customerActivateByUrl
//
// Input contract (accepts any of these):
// - req.data.token (recommended, URL-encoded full Shopify URL)
// - req.data.resetUrl
// - req.data.activationUrl
// - req.data.newPassword (required)

const admin = require('firebase-admin');
const { HttpsError } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');
const { storefrontRequest } = require('./shopifyStorefrontClient');

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

function tokenFp(token) {
  const t = String(token || '').trim();
  if (!t) return null;
  return `len=${t.length},last6=${t.slice(-6)}`;
}

function safeDecodeURIComponent(v) {
  try {
    return decodeURIComponent(v);
  } catch (_) {
    return v;
  }
}

function firstForwardedFor(xff) {
  if (!xff) return null;
  const s = String(xff);
  return s.split(',')[0].trim() || null;
}

function normalizeBaseUrl(v) {
  const s = String(v || '').trim();
  if (!s) return null;
  return s.replace(/\/+$/, '');
}

function normalizeShopDomain(raw) {
  const s = String(raw || '').trim();
  if (!s) return '';
  try {
    if (s.startsWith('http://') || s.startsWith('https://')) {
      return new URL(s).host.trim().toLowerCase();
    }
  } catch (_) {}
  const noProto = s.replace(/^https?:\/\//i, '');
  return noProto.split('/')[0].trim().toLowerCase();
}

/**
 * Convert token into an absolute Shopify URL.
 * Accepts:
 * - https://.../account/reset/...
 * - https://.../account/activate/...
 * - www.reviewseverywhere.com/account/reset/...
 * - www.reviewseverywhere.com/account/activate/...
 * - /account/reset/...
 * - /account/activate/...
 * - account/reset/...
 * - account/activate/...
 */
function normalizeAccountUrl({ tokenRaw, loginBase, shopDomain }) {
  const decoded = String(safeDecodeURIComponent(tokenRaw || '')).trim();
  if (!decoded) return null;

  if (/^https?:\/\//i.test(decoded)) return decoded;
  if (/^www\./i.test(decoded)) return `https://${decoded}`;

  const base = loginBase || `https://${shopDomain}`;

  if (decoded.startsWith('/')) return `${base}${decoded}`;

  if (decoded.startsWith('account/reset/') || decoded.startsWith('account/activate/')) {
    return `${base}/${decoded}`;
  }

  return null;
}

function urlKind(url) {
  const s = String(url || '');
  if (s.includes('/account/reset/')) return 'reset';
  if (s.includes('/account/activate/')) return 'activate';
  return 'unknown';
}

/**
 * Extract numeric customerId from gid if present:
 * gid://shopify/Customer/8033785610358 -> 8033785610358
 */
function extractNumericCustomerIdFromGid(gid) {
  const s = String(gid || '').trim();
  const m = /\/Customer\/(\d+)$/.exec(s);
  return m ? m[1] : null;
}

async function tryUpdateAccountDoc(customerId, patch) {
  try {
    const ref = db.collection('accounts').doc(String(customerId));
    const snap = await ref.get();
    if (!snap.exists) return;
    await ref.set(
      { ...patch, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
      { merge: true }
    );
  } catch (e) {
    logger.warn('[shopifyCustomerResetPassword] account update failed', {
      message: String(e?.message || e),
    });
  }
}

/**
 * Callable: shopifyCustomerResetPassword
 * Input: { token|resetUrl|activationUrl, newPassword }
 * Output: { ok, customerId, accessToken?, expiresAt? }
 */
async function shopifyCustomerResetPasswordCallable(req, storefrontAccessToken) {
  const shopDomain = normalizeShopDomain(
    process.env.SHOPIFY_MYSHOPIFY_DOMAIN || process.env.SHOPIFY_SHOP_DOMAIN || ''
  );

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

  // Accept multiple param names from deep link handler
  const tokenRaw =
    String(req.data?.resetUrl || '').trim() ||
    String(req.data?.activationUrl || '').trim() ||
    String(req.data?.token || '').trim();

  const newPassword = String(req.data?.newPassword || '').trim();

  logger.info('[shopifyCustomerResetPassword] start', {
    shopDomain,
    apiVersion,
    hasTokenParam: !!storefrontAccessToken,
    hasPrivateTokenEnv: !!process.env.SHOPIFY_STOREFRONT_PRIVATE_TOKEN,
    hasAccessTokenEnv: !!process.env.SHOPIFY_STOREFRONT_ACCESS_TOKEN,
    tokenFp: tokenFp(accessToken),
    hasToken: !!tokenRaw,
    newPasswordLen: newPassword ? newPassword.length : 0,
    ua: String(req.rawRequest?.headers?.['user-agent'] || '').slice(0, 160),
  });

  if (!shopDomain) throw new HttpsError('failed-precondition', 'Missing SHOPIFY_SHOP_DOMAIN / SHOPIFY_MYSHOPIFY_DOMAIN.');
  if (!accessToken) throw new HttpsError('failed-precondition', 'Missing Storefront access token.');
  if (!tokenRaw) throw new HttpsError('invalid-argument', 'token/resetUrl/activationUrl is required.');
  if (!newPassword || newPassword.length < 8) {
    throw new HttpsError('invalid-argument', 'Password must be at least 8 characters.');
  }

  const loginBase = normalizeBaseUrl(process.env.SHOPIFY_LOGIN_BASE);

  const accountUrl = normalizeAccountUrl({ tokenRaw, loginBase, shopDomain });
  if (!accountUrl) {
    throw new HttpsError(
      'failed-precondition',
      'Invalid token. Deep link must include FULL Shopify URL (customer.reset_password_url OR customer.account_activation_url) URL-encoded.'
    );
  }

  const kind = urlKind(accountUrl);
  logger.info('[shopifyCustomerResetPassword] token_kind', { kind });

  const buyerIp =
    firstForwardedFor(req.rawRequest?.headers?.['x-forwarded-for']) ||
    req.rawRequest?.ip ||
    null;

  // ✅ CASE A: Reset password URL
  if (kind === 'reset') {
    const mutationByUrl = `
      mutation customerResetByUrl($resetUrl: URL!, $password: String!) {
        customerResetByUrl(resetUrl: $resetUrl, password: $password) {
          customer { id email }
          customerAccessToken { accessToken expiresAt }
          customerUserErrors { code field message }
        }
      }
    `;

    let dataByUrl;
    try {
      dataByUrl = await storefrontRequest({
        shopDomain,
        apiVersion,
        accessToken,
        query: mutationByUrl,
        variables: { resetUrl: accountUrl, password: newPassword },
        buyerIp: buyerIp || undefined,
        label: 'customerResetByUrl',
      });
    } catch (e) {
      logger.error('[shopifyCustomerResetPassword] customerResetByUrl call failed', {
        message: String(e?.message || e),
        shopDomain,
        apiVersion,
      });
      throw new HttpsError('internal', 'Unable to set password (Shopify Storefront error).');
    }

    const payloadByUrl = dataByUrl?.customerResetByUrl;
    const errsByUrl = payloadByUrl?.customerUserErrors || [];

    if (Array.isArray(errsByUrl) && errsByUrl.length) {
      logger.warn('[shopifyCustomerResetPassword] customerResetByUrl errors', { errsByUrl });
      throw new HttpsError('failed-precondition', 'Reset token is invalid or expired.');
    }

    const customerId = extractNumericCustomerIdFromGid(payloadByUrl?.customer?.id || '');
    if (customerId) {
      await tryUpdateAccountDoc(customerId, {
        shopifyPasswordSetAtMs: Date.now(),
        shopifyPasswordSetAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return {
      ok: true,
      customerId: customerId || null,
      accessToken: payloadByUrl?.customerAccessToken?.accessToken || null,
      expiresAt: payloadByUrl?.customerAccessToken?.expiresAt || null,
    };
  }

  // ✅ CASE B: Activation / Account invite URL
  if (kind === 'activate') {
    const mutationActivate = `
      mutation customerActivateByUrl($activationUrl: URL!, $password: String!) {
        customerActivateByUrl(activationUrl: $activationUrl, password: $password) {
          customer { id email }
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
        query: mutationActivate,
        variables: { activationUrl: accountUrl, password: newPassword },
        buyerIp: buyerIp || undefined,
        label: 'customerActivateByUrl',
      });
    } catch (e) {
      logger.error('[shopifyCustomerResetPassword] customerActivateByUrl call failed', {
        message: String(e?.message || e),
        shopDomain,
        apiVersion,
      });
      throw new HttpsError('internal', 'Unable to activate customer (Shopify Storefront error).');
    }

    const payload = data?.customerActivateByUrl;
    const errs = payload?.customerUserErrors || [];

    if (Array.isArray(errs) && errs.length) {
      logger.warn('[shopifyCustomerResetPassword] customerActivateByUrl errors', { errs });
      throw new HttpsError('failed-precondition', 'Activation token is invalid or expired.');
    }

    const customerId = extractNumericCustomerIdFromGid(payload?.customer?.id || '');
    if (customerId) {
      await tryUpdateAccountDoc(customerId, {
        shopifyPasswordSetAtMs: Date.now(),
        shopifyPasswordSetAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return {
      ok: true,
      customerId: customerId || null,
      accessToken: payload?.customerAccessToken?.accessToken || null,
      expiresAt: payload?.customerAccessToken?.expiresAt || null,
    };
  }

  // Unknown link type
  logger.warn('[shopifyCustomerResetPassword] unknown_token_type', { accountUrl });
  throw new HttpsError(
    'failed-precondition',
    'Invalid URL. Expected /account/reset/... or /account/activate/...'
  );
}

module.exports = { shopifyCustomerResetPasswordCallable };
