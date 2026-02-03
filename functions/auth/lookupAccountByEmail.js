'use strict';

// functions/auth/lookupAccountByEmail.js
//
// Phase-1 client alignment (Shopify-first identity):
// - No activation / pendingActivation logic.
// - Shopify remains the source of truth for identity + entitlements.
// - Primary resolution path: email_index/{emailLower} -> shopifyCustomerId -> accounts/{id}.
// - Fallbacks MUST be unique; if duplicates exist, we fail (no merge, no guessing).
// - Access is determined purely by planStatus === 'active' (set by Shopify webhooks).
//
// Input (callable):
//   { email }
// Returns:
//   { found: false }
//   { found: true, isActive, planStatus,
//     accountId, shopifyCustomerId, emailLower, slotsNet,
//     slotsAvailable, authUid }

const admin = require('firebase-admin');
const { HttpsError } = require('firebase-functions/v2/https');

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

function normalizeEmail(v) {
  const s = String(v || '').trim().toLowerCase();
  return s || null;
}

function looksLikeEmail(v) {
  return typeof v === 'string' && v.includes('@') && v.includes('.');
}

/**
 * Safety: prevent stale/wrong email_index mapping from returning a mismatched account.
 */
function assertEmailBelongsToAccount(accData, emailLower) {
  const aEmailLower = normalizeEmail(accData?.emailLower || accData?.email);
  const sEmailLower = normalizeEmail(accData?.shopifyEmailLower || accData?.shopifyEmail);

  if (aEmailLower === emailLower) return;
  if (sEmailLower === emailLower) return;

  throw new HttpsError(
    'failed-precondition',
    'Identity conflict: email_index mapping does not match this account email. Please contact support.'
  );
}

/**
 * Query must return exactly one document. If more than one result exists, we refuse.
 */
async function uniqueAccountQuery(field, value, label) {
  const snap = await db.collection('accounts').where(field, '==', value).limit(2).get();

  if (snap.empty) return null;

  if (snap.size > 1) {
    throw new HttpsError(
      'failed-precondition',
      `Multiple accounts found for this email (field=${label}). Duplicate Shopify customers must be cleaned up in Shopify.`
    );
  }

  const doc = snap.docs[0];
  return { id: doc.id, ref: doc.ref, data: doc.data() || {}, via: `query:${label}` };
}

/**
 * Shopify-first deterministic resolution:
 * 0) email_index/{emailLower} -> shopifyCustomerId -> accounts/{id} (with safety check)
 * 1) accounts.shopifyEmailLower == emailLower
 * 2) accounts.shopifyEmail == emailLower
 * 3) accounts.emailLower == emailLower
 * 4) legacy raw email == emailRaw (case-sensitive)
 */
async function findAccountByEmail(emailRaw) {
  const emailLower = normalizeEmail(emailRaw);
  if (!emailLower) return null;

  // 0) Best: email_index/{emailLower} -> shopifyCustomerId -> accounts/{id}
  try {
    const idxSnap = await db.collection('email_index').doc(emailLower).get();
    if (idxSnap.exists) {
      const idx = idxSnap.data() || {};
      const customerId = idx.shopifyCustomerId ? String(idx.shopifyCustomerId) : null;

      if (customerId) {
        const accRef = db.collection('accounts').doc(customerId);
        const accSnap = await accRef.get();

        if (accSnap.exists) {
          const data = accSnap.data() || {};
          assertEmailBelongsToAccount(data, emailLower);
          return { id: accSnap.id, ref: accRef, data, via: 'email_index' };
        }
      }
    }
  } catch (e) {
    console.error('[lookupAccountByEmail] email_index read failed:', e);
  }

  // 1) Shopify email lower
  const byShopifyLower = await uniqueAccountQuery('shopifyEmailLower', emailLower, 'shopifyEmailLower');
  if (byShopifyLower) return byShopifyLower;

  // 2) Shopify email (often stored lowercased already)
  const byShopify = await uniqueAccountQuery('shopifyEmail', emailLower, 'shopifyEmail');
  if (byShopify) return byShopify;

  // 3) Platform emailLower
  const byEmailLower = await uniqueAccountQuery('emailLower', emailLower, 'emailLower');
  if (byEmailLower) return byEmailLower;

  // 4) Legacy raw fields (case-sensitive)
  if (emailRaw) {
    const byEmailRaw = await uniqueAccountQuery('email', emailRaw, 'email(raw)');
    if (byEmailRaw) return byEmailRaw;
  }

  return null;
}

async function lookupAccountByEmailCallable(req) {
  const emailRaw = String(req.data?.email || '').trim();
  const emailLower = normalizeEmail(emailRaw);

  if (!emailLower || !looksLikeEmail(emailLower)) {
    throw new HttpsError('invalid-argument', 'Valid email is required.');
  }

  const acc = await findAccountByEmail(emailRaw);
  if (!acc) {
    return { found: false };
  }

  const data = acc.data || {};
  const planStatus = String(data.planStatus || 'inactive');
  const isActive = planStatus === 'active';

  // ✅ IMPORTANT: accountId == shopifyCustomerId in your system
  const shopifyCustomerId = String(data.shopifyCustomerId || acc.id || '').trim();

  return {
    found: true,
    isActive,
    planStatus,
    accountId: acc.id,
    shopifyCustomerId, // ✅ ADD THIS
    emailLower: data.emailLower || emailLower,
    slotsNet: Number(data.slotsNet || 0),
    slotsAvailable: Number(data.slotsAvailable || 0),
    authUid: data.authUid || null,
  };
}

module.exports = { lookupAccountByEmailCallable };
