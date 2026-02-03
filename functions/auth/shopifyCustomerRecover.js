'use strict';

// functions/auth/shopifyCustomerRecover.js
//
// Step 3: Storefront customerRecover(email)
// If Storefront returns UNIDENTIFIED_CUSTOMER, fallback:
// Send "Account Invite Email" via Admin API using customerId directly.
//
// IMPORTANT:
// - Do NOT query customer by email (PII blocked on some plans/configs)
// - Pass shopifyCustomerId from Firestore to this callable
// - If client doesn't pass it, we auto-resolve via Firestore.

const admin = require('firebase-admin');
const { HttpsError } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');

const { storefrontRequest } = require('./shopifyStorefrontClient');
const { adminGraphqlRequest } = require('./shopifyAdminClient');

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

function isMyshopifyDomain(domain) {
  const d = String(domain || '').toLowerCase();
  return d.endsWith('.myshopify.com');
}

function getTraceId(req) {
  const hdr = String(req?.rawRequest?.headers?.['x-cloud-trace-context'] || '').trim();
  if (!hdr) return null;
  return hdr.split('/')[0] || null;
}

function toCustomerGid(shopifyCustomerId) {
  const raw = String(shopifyCustomerId || '').trim();
  if (!raw) return null;
  if (raw.startsWith('gid://shopify/Customer/')) return raw;
  return `gid://shopify/Customer/${raw}`; // numeric -> gid
}

/**
 * ✅ If Flutter didn't pass the customerId, resolve it from Firestore.
 * This avoids any Admin PII lookup (safe on Basic plan).
 */
async function resolveShopifyCustomerIdFromFirestore(emailLower) {
  if (!emailLower) return null;

  // 0) email_index/{emailLower} -> shopifyCustomerId
  try {
    const idxSnap = await db.collection('email_index').doc(emailLower).get();
    if (idxSnap.exists) {
      const idx = idxSnap.data() || {};
      const cid = String(idx.shopifyCustomerId || '').trim();
      if (cid) return cid;
    }
  } catch (_) {}

  // 1) accounts where shopifyEmailLower == emailLower  (docId is shopifyCustomerId)
  try {
    const snap = await db
      .collection('accounts')
      .where('shopifyEmailLower', '==', emailLower)
      .limit(1)
      .get();

    if (!snap.empty) return snap.docs[0].id;
  } catch (_) {}

  // 2) accounts where emailLower == emailLower (legacy fallback)
  try {
    const snap = await db
      .collection('accounts')
      .where('emailLower', '==', emailLower)
      .limit(1)
      .get();

    if (!snap.empty) return snap.docs[0].id;
  } catch (_) {}

  return null;
}

/**
 * ✅ Admin fallback (NO PII):
 * Send account invite email using customerId only.
 */
async function trySendAccountInviteEmail({
  traceId,
  adminShopDomain,
  apiVersion,
  adminToken,
  shopifyCustomerId,
}) {
  const customerGid = toCustomerGid(shopifyCustomerId);

  if (!customerGid) {
    logger.warn('[shopifyCustomerRecover] fallback_invite:missing_customer_id', { traceId });
    return false;
  }

  if (!adminToken) {
    logger.warn('[shopifyCustomerRecover] fallback_invite:missing_admin_token', { traceId });
    return false;
  }

  if (!adminShopDomain || !isMyshopifyDomain(adminShopDomain)) {
    logger.error('[shopifyCustomerRecover] fallback_invite:invalid_admin_domain', {
      traceId,
      adminShopDomain: adminShopDomain || null,
    });
    return false;
  }

  // ✅ Correct payload: userErrors (NOT customerUserErrors)
  const inviteMutation = `
    mutation SendInvite($customerId: ID!) {
      customerSendAccountInviteEmail(customerId: $customerId) {
        userErrors { field message }
      }
    }
  `;

  try {
    const inviteData = await adminGraphqlRequest({
      traceId,
      shopDomain: adminShopDomain,
      apiVersion,
      adminAccessToken: adminToken,
      query: inviteMutation,
      variables: { customerId: customerGid },
      label: 'customerSendAccountInviteEmail',
    });

    const errs = inviteData?.customerSendAccountInviteEmail?.userErrors || [];
    if (Array.isArray(errs) && errs.length) {
      logger.error('[shopifyCustomerRecover] fallback_invite:user_errors', { traceId, errs });
      return false;
    }

    logger.info('[shopifyCustomerRecover] fallback_invite:sent', {
      traceId,
      customerId: customerGid,
    });
    return true;
  } catch (e) {
    logger.error('[shopifyCustomerRecover] fallback_invite:send_failed', {
      traceId,
      message: String(e?.message || e),
    });
    return false;
  }
}

async function shopifyCustomerRecoverCallable(req, storefrontAccessToken, adminAccessTokenOverride) {
  const DEBUG_VERBOSE = String(process.env.SHOPIFY_DEBUG_VERBOSE || '').trim() === '1';

  const envShopDomain = normalizeShopDomain(process.env.SHOPIFY_SHOP_DOMAIN || '');
  const envMyshopify = normalizeShopDomain(process.env.SHOPIFY_MYSHOPIFY_DOMAIN || '');

  const storefrontDomain = envMyshopify || envShopDomain;

  // ✅ Admin domain MUST be myshopify
  const adminShopDomain =
    envMyshopify || (isMyshopifyDomain(envShopDomain) ? envShopDomain : '');

  const apiVersion = String(process.env.SHOPIFY_STOREFRONT_API_VERSION || '2024-10').trim();

  const accessToken = (
    storefrontAccessToken ||
    String(
      process.env.SHOPIFY_STOREFRONT_PRIVATE_TOKEN ||
        process.env.SHOPIFY_STOREFRONT_ACCESS_TOKEN ||
        ''
    )
  ).trim();

  const adminToken = String(
    adminAccessTokenOverride || process.env.SHOPIFY_ADMIN_ACCESS_TOKEN || ''
  ).trim();

  const emailRaw = String(req.data?.email || '').trim();
  const emailLower = normalizeEmail(emailRaw);

  // ✅ accept multiple keys to prevent client mismatch
  let shopifyCustomerId = String(
    req.data?.shopifyCustomerId || req.data?.accountId || req.data?.customerId || ''
  ).trim();

  const buyerIp =
    firstForwardedFor(req.rawRequest?.headers?.['x-forwarded-for']) ||
    req.rawRequest?.ip ||
    null;

  const traceId = getTraceId(req);

  logger.info('[shopifyCustomerRecover] start', {
    traceId,
    storefrontDomain,
    adminShopDomain: adminShopDomain || null,
    apiVersion,
    emailLower,
    buyerIp,
    ua: String(req.rawRequest?.headers?.['user-agent'] || '').slice(0, 160),
    hasStorefrontAccessToken: !!accessToken,
    tokenFp: tokenFp(accessToken),
    hasAdminToken: !!adminToken,
    adminTokenFp: tokenFp(adminToken),
    shopifyCustomerId: shopifyCustomerId || null,
    debugVerbose: DEBUG_VERBOSE,
  });

  if (!looksLikeEmail(emailLower)) throw new HttpsError('invalid-argument', 'Valid email is required.');
  if (!storefrontDomain) throw new HttpsError('failed-precondition', 'Missing SHOPIFY_SHOP_DOMAIN.');
  if (!accessToken) throw new HttpsError('failed-precondition', 'Missing Storefront access token.');

  // Throttle per email (avoid spam)
  const nowMs = Date.now();
  const cooldownMs = 60 * 1000;

  const throttleRef = db.collection('auth_recover_throttle').doc(emailLower);
  const throttleSnap = await throttleRef.get();
  const lastMs = throttleSnap.exists ? Number(throttleSnap.data()?.lastSentAtMs || 0) : 0;

  if (lastMs && nowMs - lastMs < cooldownMs) {
    logger.info('[shopifyCustomerRecover] throttled', { traceId, emailLower, lastMs, nowMs });
    return { ok: true, sent: false, throttled: true };
  }

  await throttleRef.set(
    {
      emailLower,
      lastSentAtMs: nowMs,
      count: admin.firestore.FieldValue.increment(1),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  // Storefront mutation: customerRecover(email)
  const mutation = `
    mutation customerRecover($email: String!) {
      customerRecover(email: $email) {
        customerUserErrors { code field message }
      }
    }
  `;

  let data;
  try {
    data = await storefrontRequest({
      shopDomain: storefrontDomain,
      apiVersion,
      accessToken,
      query: mutation,
      variables: { email: emailRaw.trim() },
      buyerIp: buyerIp || undefined,
      label: 'customerRecover',
    });
  } catch (e) {
    logger.error('[shopifyCustomerRecover] storefront call failed', {
      traceId,
      message: String(e?.message || e),
    });

    // do not leak existence
    return { ok: true, sent: true, throttled: false };
  }

  const errs = data?.customerRecover?.customerUserErrors || [];
  const friendlyErrs = Array.isArray(errs)
    ? errs.map((x) => ({
        code: x?.code || null,
        field: x?.field || null,
        message: x?.message || null,
      }))
    : [];

  if (friendlyErrs.length) {
    const codes = friendlyErrs.map((e) => e.code).filter(Boolean);

    logger.warn('[shopifyCustomerRecover] customerUserErrors', {
      traceId,
      emailLower,
      codes,
      errs: friendlyErrs,
    });

    // ✅ UNIDENTIFIED_CUSTOMER => fallback invite by ID (NO PII)
    if (codes.includes('UNIDENTIFIED_CUSTOMER')) {
      // if missing, auto-resolve from Firestore
      if (!shopifyCustomerId) {
        shopifyCustomerId = await resolveShopifyCustomerIdFromFirestore(emailLower);
        logger.info('[shopifyCustomerRecover] resolvedCustomerIdFromFirestore', {
          traceId,
          emailLower,
          shopifyCustomerId: shopifyCustomerId || null,
        });
      }

      const inviteSent = await trySendAccountInviteEmail({
        traceId,
        adminShopDomain,
        apiVersion,
        adminToken,
        shopifyCustomerId,
      });

      logger.info('[shopifyCustomerRecover] fallback_invite:result', {
        traceId,
        emailLower,
        inviteSent: !!inviteSent,
      });

      return { ok: true, sent: true, throttled: false };
    }

    return { ok: true, sent: true, throttled: false };
  }

  logger.info('[shopifyCustomerRecover] sent', { traceId, emailLower, sent: true });
  return { ok: true, sent: true, throttled: false };
}

module.exports = { shopifyCustomerRecoverCallable };
