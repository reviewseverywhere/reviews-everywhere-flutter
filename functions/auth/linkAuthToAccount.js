'use strict';

// functions/auth/linkAuthToAccount.js
//
// Phase-1 client alignment (Shopify-first identity):
// - Shopify is the single source of truth for customer identity.
// - Firebase links auth ONLY AFTER Shopify has a stable customer record (via webhooks).
// - NO activation lifecycle. Access is entitlement-driven:
//     planStatus === 'active'  => allow
//     otherwise               => block (must purchase / not entitled)
//
// Determinism + NO merge workaround:
// - Prefer email_index/{emailLower} -> shopifyCustomerId -> accounts/{id}.
// - If email_index is missing, we still query accounts but:
//     - we query with limit(2) and FAIL if duplicates exist.
//     - we do NOT auto-merge or consolidate.
// - Firebase Auth uid is deterministic: uid === shopifyCustomerId.
// - Social email MUST match the Shopify email (accounts.shopifyEmail/shopifyEmailLower).
//
// Input (callable, used by Flutter):
//   { provider: 'google' | 'facebook',
//     idToken?: string,        // for Google
//     accessToken?: string }   // for Facebook
//
// Returns:
//   { linked: true, accountId, planStatus, customToken }

const admin = require('firebase-admin');
const { HttpsError } = require('firebase-functions/v2/https');
const { OAuth2Client } = require('google-auth-library');

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

function normalizeEmail(v) {
  const s = String(v || '').trim().toLowerCase();
  return s || null;
}

function looksLikeEmail(v) {
  return typeof v === 'string' && v.includes('@') && v.includes('.');
}

async function querySingleAccountOrFail(query, label) {
  const snap = await query.limit(2).get();
  if (snap.empty) return null;

  if (snap.size > 1) {
    throw new HttpsError(
      'failed-precondition',
      `Identity conflict: multiple Shopify accounts match this email (${label}). Support required.`
    );
  }

  const doc = snap.docs[0];
  return { id: doc.id, ref: doc.ref, data: doc.data() || {} };
}

/**
 * Safety: if we resolve via email_index, ensure the email truly belongs to that account.
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
 * Deterministic account resolution:
 * 1) email_index/{emailLower} -> shopifyCustomerId -> accounts/{id}
 * 2) accounts where shopifyEmailLower == emailLower
 * 3) accounts where shopifyEmail == emailLower
 * 4) accounts where emailLower == emailLower
 */
async function resolveAccountByEmailDeterministically(emailRaw, emailLower) {
  if (!emailLower || !looksLikeEmail(emailLower)) return null;

  // 1) Best: email_index/{emailLower}
  try {
    const idxSnap = await db.collection('email_index').doc(emailLower).get();
    if (idxSnap.exists) {
      const idx = idxSnap.data() || {};
      const shopifyCustomerId = idx.shopifyCustomerId ? String(idx.shopifyCustomerId) : null;

      if (shopifyCustomerId) {
        const ref = db.collection('accounts').doc(shopifyCustomerId);
        const accSnap = await ref.get();
        if (accSnap.exists) {
          const data = accSnap.data() || {};
          assertEmailBelongsToAccount(data, emailLower);
          return { id: accSnap.id, ref, data, via: 'email_index' };
        }
      }
    }
  } catch (e) {
    console.error('[linkAuthToAccount] email_index read failed:', e);
  }

  // 2) Shopify emailLower
  const byShopifyLower = await querySingleAccountOrFail(
    db.collection('accounts').where('shopifyEmailLower', '==', emailLower),
    'shopifyEmailLower'
  );
  if (byShopifyLower) return { ...byShopifyLower, via: 'shopifyEmailLower' };

  // 3) Shopify email (normalized)
  const byShopify = await querySingleAccountOrFail(
    db.collection('accounts').where('shopifyEmail', '==', emailLower),
    'shopifyEmail'
  );
  if (byShopify) return { ...byShopify, via: 'shopifyEmail' };

  // 4) Platform emailLower
  const byEmailLower = await querySingleAccountOrFail(
    db.collection('accounts').where('emailLower', '==', emailLower),
    'emailLower'
  );
  if (byEmailLower) return { ...byEmailLower, via: 'emailLower' };

  return null;
}

function getPlanStatus(data) {
  return String(data?.planStatus || 'inactive');
}

function assertAccountIsActive(accData) {
  const planStatus = getPlanStatus(accData);
  if (planStatus !== 'active') {
    throw new HttpsError('failed-precondition', `Account not active (planStatus=${planStatus}).`);
  }
  return planStatus;
}

/**
 * Social login acceptance criteria:
 * - Social email MUST match Shopify customer email.
 */
function assertSocialEmailMatchesShopify(accData, emailLower) {
  const shopifyEmail = normalizeEmail(accData?.shopifyEmailLower || accData?.shopifyEmail);
  if (!shopifyEmail) {
    throw new HttpsError(
      'failed-precondition',
      'Account is missing Shopify email. Please contact support.'
    );
  }
  if (shopifyEmail !== emailLower) {
    throw new HttpsError(
      'failed-precondition',
      'Email mismatch. Social login email must match the Shopify customer email.'
    );
  }
}

/**
 * Ensure Firebase user exists with uid == shopifyCustomerId and correct email.
 * No merge: if email belongs to another uid, Firebase throws and we fail.
 */
async function ensureAuthUserByUidAndEmail(uid, emailLower) {
  try {
    const u = await admin.auth().getUser(uid);

    const currentEmail = normalizeEmail(u.email || '');
    if (emailLower && currentEmail && currentEmail !== emailLower) {
      await admin.auth().updateUser(uid, { email: emailLower });
    } else if (emailLower && !currentEmail) {
      await admin.auth().updateUser(uid, { email: emailLower });
    }

    return u;
  } catch (e) {
    if (e?.code === 'auth/user-not-found') {
      return await admin.auth().createUser({
        uid,
        email: emailLower || undefined,
        emailVerified: false,
        disabled: false,
      });
    }
    throw e;
  }
}

/**
 * Verify Google ID token and extract verified email.
 * Requires env: GOOGLE_CLIENT_IDS="webClientId,iosClientId,androidClientId"
 */
async function verifyGoogleIdToken(idToken) {
  const raw = String(process.env.GOOGLE_CLIENT_IDS || '').trim();
  const audiences = raw
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);

  if (!audiences.length) {
    throw new HttpsError(
      'internal',
      'Server misconfigured: GOOGLE_CLIENT_IDS is not set in Functions runtime.'
    );
  }

  const client = new OAuth2Client();
  const ticket = await client.verifyIdToken({ idToken, audience: audiences });

  const payload = ticket.getPayload() || {};
  const emailRaw = payload.email ? String(payload.email).trim() : null;
  const emailLower = normalizeEmail(emailRaw);
  const emailVerified = !!payload.email_verified;

  if (!emailLower || !emailVerified) {
    throw new HttpsError('permission-denied', 'Google account email missing or not verified.');
  }

  return { emailRaw, emailLower };
}

/**
 * Verify Facebook token and extract email.
 */
async function verifyFacebookAccessToken(accessToken) {
  if (typeof fetch !== 'function') {
    throw new HttpsError(
      'internal',
      'Server runtime missing fetch(). Ensure Node 18+ for Functions runtime.'
    );
  }

  const url =
    `https://graph.facebook.com/me?fields=id,name,email&access_token=` +
    encodeURIComponent(accessToken);

  const resp = await fetch(url);
  const json = await resp.json().catch(() => ({}));

  if (!resp.ok || json?.error) {
    throw new HttpsError(
      'permission-denied',
      `Facebook token invalid: ${json?.error?.message || 'Unknown error'}`
    );
  }

  const emailRaw = json.email ? String(json.email).trim() : null;
  const emailLower = normalizeEmail(emailRaw);

  if (!emailLower) {
    throw new HttpsError(
      'invalid-argument',
      'Facebook account has no email. Add an email in Facebook first.'
    );
  }

  return { emailRaw, emailLower };
}

/**
 * Callable handler: social login only (google/facebook).
 */
async function linkAuthToAccountCallable(req) {
  const provider = String(req.data?.provider || '').trim().toLowerCase();

  if (!provider) {
    throw new HttpsError('invalid-argument', 'provider is required (google|facebook).');
  }

  let emailRaw = null;
  let emailLower = null;

  if (provider === 'google') {
    const idToken = String(req.data?.idToken || '').trim();
    if (!idToken) throw new HttpsError('invalid-argument', 'Missing idToken.');
    ({ emailRaw, emailLower } = await verifyGoogleIdToken(idToken));
  } else if (provider === 'facebook') {
    const accessToken = String(req.data?.accessToken || '').trim();
    if (!accessToken) throw new HttpsError('invalid-argument', 'Missing accessToken.');
    ({ emailRaw, emailLower } = await verifyFacebookAccessToken(accessToken));
  } else {
    throw new HttpsError('invalid-argument', 'provider must be google|facebook');
  }

  // 1) Resolve email -> Shopify account deterministically
  const acc = await resolveAccountByEmailDeterministically(emailRaw, emailLower);
  if (!acc) {
    throw new HttpsError(
      'not-found',
      'No Shopify account found for this email. Please purchase on the website first.'
    );
  }

  // 2) Enforce active plan
  const planStatus = assertAccountIsActive(acc.data);

  // 3) Social email MUST match Shopify email
  assertSocialEmailMatchesShopify(acc.data, emailLower);

  // 4) Deterministic uid: uid == shopifyCustomerId
  const shopifyCustomerId = acc.id;
  const uid = shopifyCustomerId;

  try {
    await ensureAuthUserByUidAndEmail(uid, emailLower);
  } catch (e) {
    const code = String(e?.code || '');
    if (code.includes('email-already-exists')) {
      // Another Firebase user already uses this email -> duplicate identity risk.
      throw new HttpsError(
        'failed-precondition',
        'Email already linked to another Firebase user. Please contact support to resolve duplicate accounts.'
      );
    }
    throw e;
  }

  // 5) Create custom token for app sign-in
  const customToken = await admin.auth().createCustomToken(uid, {
    shopifyCustomerId,
    loginMethod: 'social',
    provider,
    email: emailLower,
  });

  // 6) Persist link + last login info
  const now = admin.firestore.FieldValue.serverTimestamp();
  await acc.ref.set(
    {
      authUid: uid,
      emailLower: acc.data.emailLower ? acc.data.emailLower : emailLower,
      updatedAt: now,
      lastLoginAt: now,
      lastLoginMethod: 'social',
      lastLoginProvider: provider,
    },
    { merge: true }
  );

  return {
    linked: true,
    accountId: shopifyCustomerId,
    planStatus,
    customToken,
  };
}

module.exports = { linkAuthToAccountCallable };
