'use strict';

// functions/shopify/common.js
//
// Phase-1 client alignment (Shopify-first identity):
// - Shopify is the single source of truth for customer identity.
// - Track Shopify email in shopifyEmail + shopifyEmailLower.
// - Do NOT overwrite platform login email once it diverges.
// - No activation lifecycle; planStatus entitlement-driven by orders/paid + refunds.
// - Maintain email_index/{emailLower} -> shopifyCustomerId (collision-safe) for deterministic login resolution.
// - If Shopify email changes, delete the OLD email_index mapping only if it points to the same customerId.

const admin = require('firebase-admin');
const crypto = require('crypto');

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

/* -------------------------------------------------------------------------- */
/* Helpers                                                                    */
/* -------------------------------------------------------------------------- */

function normalizeEmail(v) {
  const s = String(v || '').trim().toLowerCase();
  return s || null;
}

/**
 * Collision-safe + cleanup email index in a TX:
 * - Set newEmailLower -> customerId when safe.
 * - If mapping already exists to a different customer, DO NOT overwrite; write conflict record.
 * - Delete oldEmailLower doc ONLY if it points to the same customerId (safe cleanup).
 *
 * IMPORTANT: Firestore TX rule: all reads must occur before any writes.
 * This function therefore reads both idxRef and oldRef first, then writes.
 */
async function syncEmailIndexTx(tx, { oldEmailLower, newEmailLower, shopifyCustomerId }) {
  const customerId = shopifyCustomerId ? String(shopifyCustomerId) : null;
  if (!customerId) return;

  const now = admin.firestore.FieldValue.serverTimestamp();

  const newKey = newEmailLower ? String(newEmailLower) : null;
  const oldKey =
    oldEmailLower && oldEmailLower !== newEmailLower ? String(oldEmailLower) : null;

  const idxRef = newKey ? db.collection('email_index').doc(newKey) : null;
  const oldRef = oldKey ? db.collection('email_index').doc(oldKey) : null;

  // ✅ READS FIRST
  const [idxSnap, oldSnap] = await Promise.all([
    idxRef ? tx.get(idxRef) : Promise.resolve(null),
    oldRef ? tx.get(oldRef) : Promise.resolve(null),
  ]);

  // ✅ WRITES ONLY AFTER ALL READS

  // Upsert new mapping (collision-safe)
  if (idxRef && idxSnap) {
    if (!idxSnap.exists) {
      tx.set(idxRef, {
        emailLower: newKey,
        shopifyCustomerId: customerId,
        createdAt: now,
        updatedAt: now,
      });
    } else {
      const existing = idxSnap.data() || {};
      const existingId = existing.shopifyCustomerId ? String(existing.shopifyCustomerId) : null;

      if (existingId === customerId) {
        tx.set(idxRef, { updatedAt: now }, { merge: true });
      } else {
        const conflictRef = db
          .collection('email_index_conflicts')
          .doc(`${newKey}__${customerId}`);

        tx.set(
          conflictRef,
          {
            emailLower: newKey,
            attemptedShopifyCustomerId: customerId,
            existingShopifyCustomerId: existingId,
            createdAt: now,
          },
          { merge: true }
        );
      }
    }
  }

  // Delete old mapping safely if email changed
  if (oldRef && oldSnap && oldSnap.exists) {
    const old = oldSnap.data() || {};
    const oldId = old.shopifyCustomerId ? String(old.shopifyCustomerId) : null;

    // ✅ only delete if it belonged to this same customer
    if (oldId === customerId) {
      tx.delete(oldRef);
    }
  }
}

/**
 * Extract minimal customer info from any object that has "customer".
 */
function extractCustomerInfo(obj) {
  const customer = obj && obj.customer ? obj.customer : null;
  const customerId = customer && customer.id ? String(customer.id) : null;

  // Prefer nested customer email; fallback to top-level email
  const email = normalizeEmail((customer && customer.email) || obj?.email || null);

  const firstName = customer && customer.first_name ? customer.first_name : null;
  const lastName = customer && customer.last_name ? customer.last_name : null;
  const displayName =
    firstName || lastName ? `${firstName || ''} ${lastName || ''}`.trim() : null;

  return { customerId, email, firstName, lastName, displayName };
}

/**
 * Extract Units-per-Bundle from a Shopify line_item.properties array.
 */
function extractUnitsPerBundleFromProperties(properties) {
  const props = Array.isArray(properties) ? properties : [];
  const candidates = new Set([
    'units per bundle',
    'unit per bundle',
    'bundle units',
    'units_per_bundle',
    'unitsperbundle',
  ]);

  for (const p of props) {
    const name = String(p?.name || '').trim().toLowerCase();
    if (!name) continue;

    if (candidates.has(name)) {
      const raw = String(p?.value || '').trim();
      const n = Number(raw);
      if (Number.isFinite(n) && n > 0) return Math.floor(n);
    }
  }
  return 1;
}

/**
 * Create or update an account stub based on a Shopify customer payload.
 *
 * Phase-1 rules:
 * - New account default: planStatus="inactive" (no pendingActivation).
 * - Shopify email tracked separately and lower-cased (shopifyEmailLower).
 * - Platform email only updated if missing OR still in sync with Shopify email.
 * - Maintain email_index mapping (collision-safe) + delete old mapping when email changes (safe).
 */
async function upsertAccountFromCustomer(customerPayload) {
  const customerId = String(customerPayload.id);
  const incomingShopifyEmailLower = normalizeEmail(customerPayload.email || null);

  const firstName = customerPayload.first_name || null;
  const lastName = customerPayload.last_name || null;
  const displayName =
    firstName || lastName ? `${firstName || ''} ${lastName || ''}`.trim() : null;

  const accountRef = db.collection('accounts').doc(customerId);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(accountRef);
    const now = admin.firestore.FieldValue.serverTimestamp();

    if (!snap.exists) {
      const doc = {
        shopifyCustomerId: customerId,

        ...(incomingShopifyEmailLower
          ? {
              shopifyEmail: incomingShopifyEmailLower,
              shopifyEmailLower: incomingShopifyEmailLower,
            }
          : {}),

        ...(incomingShopifyEmailLower
          ? { email: incomingShopifyEmailLower, emailLower: incomingShopifyEmailLower }
          : {}),

        firstName,
        lastName,
        displayName,

        planStatus: 'inactive',

        slotsPurchasedTotal: 0,
        slotsRefundedTotal: 0,
        slotsNet: 0,
        slotsUsed: 0,
        slotsAvailable: 0,

        createdAt: now,
        updatedAt: now,
      };

      // ✅ IMPORTANT: syncEmailIndexTx performs reads; run it BEFORE tx.set(accountRef, ...)
      if (incomingShopifyEmailLower) {
        await syncEmailIndexTx(tx, {
          oldEmailLower: null,
          newEmailLower: incomingShopifyEmailLower,
          shopifyCustomerId: customerId,
        });
      }

      tx.set(accountRef, doc);
      return;
    }

    const data = snap.data() || {};

    const oldShopifyEmailLower =
      normalizeEmail(data.shopifyEmailLower) || normalizeEmail(data.shopifyEmail);

    const existingPlatformEmail = normalizeEmail(data.email);
    const existingShopifyEmail = normalizeEmail(data.shopifyEmailLower || data.shopifyEmail);

    // Preserve last known Shopify email if incoming is null
    const shopifyEmailToStore = incomingShopifyEmailLower || existingShopifyEmail || null;

    const shouldUpdatePlatformEmail =
      !existingPlatformEmail ||
      (existingShopifyEmail && existingPlatformEmail === existingShopifyEmail) ||
      (!existingShopifyEmail && shopifyEmailToStore && existingPlatformEmail === shopifyEmailToStore);

    const update = {
      firstName,
      lastName,
      displayName,
      updatedAt: now,
    };

    if (shopifyEmailToStore) {
      update.shopifyEmail = shopifyEmailToStore;
      update.shopifyEmailLower = shopifyEmailToStore;
    }

    if (shouldUpdatePlatformEmail && shopifyEmailToStore) {
      update.email = shopifyEmailToStore;
      update.emailLower = shopifyEmailToStore;
    }

    // ✅ IMPORTANT: syncEmailIndexTx performs reads; run it BEFORE writing accountRef
    if (shopifyEmailToStore) {
      await syncEmailIndexTx(tx, {
        oldEmailLower: oldShopifyEmailLower,
        newEmailLower: shopifyEmailToStore,
        shopifyCustomerId: customerId,
      });
    }

    // Do NOT mutate planStatus here. Entitlements webhooks control it.
    tx.set(accountRef, update, { merge: true });
  });
}

/**
 * Upsert a minimal shopifyOrders doc with order metadata.
 */
async function upsertOrderDoc(order, extraFields = {}) {
  const orderId = String(order.id);
  const { customerId, email } = extractCustomerInfo(order);
  const orderRef = db.collection('shopifyOrders').doc(orderId);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(orderRef);
    const now = admin.firestore.FieldValue.serverTimestamp();

    const base = {
      shopifyOrderId: order.id,
      shopifyCustomerId: customerId,
      email,
      financialStatus: order.financial_status || null,
      fulfillmentStatus: order.fulfillment_status || null,
      cancelledAt: order.cancelled_at || null,
      updatedAt: now,
      lastEvent: extraFields.lastEvent || null,
      ...extraFields,
    };

    if (!snap.exists) tx.set(orderRef, { ...base, createdAt: now });
    else tx.update(orderRef, base);
  });
}

/**
 * Slot calculation from a refund payload (bundle-aware).
 */
function calculateSlotsFromRefund(refund) {
  const items = Array.isArray(refund?.refund_line_items) ? refund.refund_line_items : [];
  let totalUnits = 0;

  for (const item of items) {
    const qty = Number(item?.quantity || 0);
    if (!Number.isFinite(qty) || qty <= 0) continue;

    const lineItem = item?.line_item || null;
    const unitsPerBundle = extractUnitsPerBundleFromProperties(lineItem?.properties);
    totalUnits += qty * (Number.isFinite(unitsPerBundle) ? unitsPerBundle : 1);
  }

  return totalUnits;
}

/* -------------------------------------------------------------------------- */
/* Webhook idempotency                                                        */
/* -------------------------------------------------------------------------- */

function getShopifyHeader(req, name) {
  return (req.get && req.get(name)) || req.headers[name.toLowerCase()] || null;
}

function rawBodyToBuffer(req) {
  if (!req || !req.rawBody) return Buffer.from('', 'utf8');
  if (Buffer.isBuffer(req.rawBody)) return req.rawBody;
  return Buffer.from(String(req.rawBody), 'utf8');
}

async function acquireWebhookLock(req, meta = {}) {
  const shopifyEventId = getShopifyHeader(req, 'X-Shopify-Event-Id');
  const shopifyWebhookId = getShopifyHeader(req, 'X-Shopify-Webhook-Id');

  let dedupeId = shopifyEventId || shopifyWebhookId;

  if (!dedupeId) {
    const raw = rawBodyToBuffer(req);
    const hash = crypto.createHash('sha256').update(raw).digest('hex');
    dedupeId = `missing-shopify-id:${hash}`;
  }

  const docId = String(dedupeId);
  const eventRef = db.collection('webhookEvents').doc(docId);
  const now = admin.firestore.FieldValue.serverTimestamp();

  const base = {
    dedupeId: docId,
    shopifyEventId: shopifyEventId ? String(shopifyEventId) : null,
    shopifyWebhookId: shopifyWebhookId ? String(shopifyWebhookId) : null,

    topic: meta.topic || getShopifyHeader(req, 'X-Shopify-Topic') || null,
    shopDomain: getShopifyHeader(req, 'X-Shopify-Shop-Domain') || null,
    triggeredAt: getShopifyHeader(req, 'X-Shopify-Triggered-At') || null,

    orderId: meta.orderId != null ? String(meta.orderId) : null,
    customerId: meta.customerId != null ? String(meta.customerId) : null,
    refundId: meta.refundId != null ? String(meta.refundId) : null,

    updatedAt: now,
  };

  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(eventRef);

    if (!snap.exists) {
      tx.create(eventRef, {
        ...base,
        status: 'processing',
        attempts: 1,
        createdAt: now,
        processingStartedAt: now,
      });
      return { shouldProcess: true };
    }

    const data = snap.data() || {};
    const status = String(data.status || '');

    if (status === 'processed') return { shouldProcess: false };

    const attempts = Number(data.attempts || 1) + 1;

    tx.update(eventRef, {
      ...base,
      status: 'processing',
      attempts,
      retriedAt: now,
      processingStartedAt: now,
    });

    return { shouldProcess: true };
  });

  return { webhookId: docId, dedupeId: docId, shouldProcess: result.shouldProcess, eventRef };
}

async function markWebhookProcessed(eventRef) {
  if (!eventRef) return;
  const now = admin.firestore.FieldValue.serverTimestamp();
  await eventRef.update({ status: 'processed', processedAt: now, updatedAt: now });
}

async function markWebhookFailed(eventRef, err) {
  if (!eventRef) return;
  const now = admin.firestore.FieldValue.serverTimestamp();
  await eventRef.update({
    status: 'failed',
    failedAt: now,
    error: String(err?.message || err || 'unknown_error').slice(0, 500),
    updatedAt: now,
  });
}

module.exports = {
  admin,
  db,
  extractCustomerInfo,
  upsertAccountFromCustomer,
  upsertOrderDoc,
  calculateSlotsFromRefund,
  getShopifyHeader,
  acquireWebhookLock,
  markWebhookProcessed,
  markWebhookFailed,
};
