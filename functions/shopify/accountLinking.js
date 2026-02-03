'use strict';

// functions/shopify/accountLinking.js
//
// Implements:
// - accountsByEmail/{emailLower} -> { primaryCustomerId, ... }
// - accountAliases/{aliasCustomerId} -> { primaryCustomerId, ... }
//
// Design goal:
// - If Shopify creates multiple customer IDs for the same email, we always credit and activate
//   the SAME "primary" account (accounts/{primaryCustomerId}).
// - We never overwrite an existing mapping to a different primary (we record a conflict instead).

const { admin, db } = require('./common');

function normalizeEmail(v) {
  const s = String(v || '').trim().toLowerCase();
  return s.includes('@') ? s : '';
}

function safeId(v) {
  return String(v || '').trim();
}

function accountsByEmailRef(emailLower) {
  return db.collection('accountsByEmail').doc(emailLower);
}

function aliasRef(aliasCustomerId) {
  return db.collection('accountAliases').doc(String(aliasCustomerId));
}

/**
 * Ensure the emailLower maps to a primaryCustomerId.
 * Rules:
 * - If no mapping exists => create it (emailLower -> primaryCustomerId)
 * - If mapping exists to a DIFFERENT primary => DO NOT overwrite; record a conflict doc
 * - If mapping exists to SAME primary => refresh updatedAt
 */
async function ensureEmailMapsToPrimaryTx(tx, { emailLower, primaryCustomerId, lastSeenCustomerId }) {
  const now = admin.firestore.FieldValue.serverTimestamp();
  const e = normalizeEmail(emailLower);
  const p = safeId(primaryCustomerId);

  if (!e || !p) return { mappedTo: p || null, created: false, conflict: false };

  const ref = accountsByEmailRef(e);
  const snap = await tx.get(ref);

  if (!snap.exists) {
    tx.set(ref, {
      emailLower: e,
      primaryCustomerId: p,
      createdAt: now,
      updatedAt: now,
      lastSeenCustomerId: safeId(lastSeenCustomerId || p) || null,
    });
    return { mappedTo: p, created: true, conflict: false };
  }

  const data = snap.data() || {};
  const existing = safeId(data.primaryCustomerId);

  // Conflict: never overwrite mapping to a different primary
  if (existing && existing !== p) {
    const conflictRef = db.collection('accountLinkConflicts').doc(e);
    tx.set(
      conflictRef,
      {
        emailLower: e,
        existingPrimaryCustomerId: existing,
        attemptedPrimaryCustomerId: p,
        attemptedCustomerId: safeId(lastSeenCustomerId || '') || null,
        updatedAt: now,
      },
      { merge: true }
    );
    return { mappedTo: existing, created: false, conflict: true };
  }

  tx.set(
    ref,
    {
      primaryCustomerId: existing || p,
      updatedAt: now,
      lastSeenCustomerId: safeId(lastSeenCustomerId || p) || null,
    },
    { merge: true }
  );

  return { mappedTo: existing || p, created: false, conflict: false };
}

/**
 * Resolve primary customer id using accountsByEmail mapping (transaction-safe).
 * - If emailLower exists and mapping exists => use mapped primary
 * - If emailLower exists and mapping missing => create mapping to incoming customerId
 * - If emailLower missing => primary = incoming customerId
 */
async function resolvePrimaryCustomerIdTx(tx, { customerId, emailLower }) {
  const incomingId = safeId(customerId);
  const e = normalizeEmail(emailLower);

  if (!incomingId) return { primaryCustomerId: '', emailLower: e || '' };

  // No email -> no merge rule possible
  if (!e) return { primaryCustomerId: incomingId, emailLower: '' };

  const ref = accountsByEmailRef(e);
  const snap = await tx.get(ref);

  if (snap.exists) {
    const data = snap.data() || {};
    const mapped = safeId(data.primaryCustomerId);
    return { primaryCustomerId: mapped || incomingId, emailLower: e };
  }

  // Create mapping to this incoming id
  const now = admin.firestore.FieldValue.serverTimestamp();
  tx.set(ref, {
    emailLower: e,
    primaryCustomerId: incomingId,
    createdAt: now,
    updatedAt: now,
    lastSeenCustomerId: incomingId,
  });

  return { primaryCustomerId: incomingId, emailLower: e };
}

/**
 * Record that aliasCustomerId should resolve to primaryCustomerId.
 */
function recordAliasTx(tx, { aliasCustomerId, primaryCustomerId, emailLower }) {
  const now = admin.firestore.FieldValue.serverTimestamp();
  const aliasId = safeId(aliasCustomerId);
  const primaryId = safeId(primaryCustomerId);
  const e = normalizeEmail(emailLower);

  if (!aliasId || !primaryId || aliasId === primaryId) return;

  tx.set(
    aliasRef(aliasId),
    {
      aliasCustomerId: aliasId,
      primaryCustomerId: primaryId,
      emailLower: e || null,
      createdAt: now,
      updatedAt: now,
    },
    { merge: true }
  );
}

/**
 * Add alias id into primary account doc for audit/debug.
 */
function addAliasToPrimaryAccountTx(tx, primaryAccountRef, aliasCustomerId) {
  const now = admin.firestore.FieldValue.serverTimestamp();
  const aliasId = safeId(aliasCustomerId);
  if (!aliasId) return;

  tx.set(
    primaryAccountRef,
    {
      shopifyCustomerIds: admin.firestore.FieldValue.arrayUnion(aliasId),
      updatedAt: now,
    },
    { merge: true }
  );
}

module.exports = {
  normalizeEmail,
  ensureEmailMapsToPrimaryTx,
  resolvePrimaryCustomerIdTx,
  recordAliasTx,
  addAliasToPrimaryAccountTx,
};
