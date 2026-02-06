// functions/shopify/entitlements.js
//
// Centralized entitlement math + account slot reconciliation.
// Use this from:
// - orderPaid.js
// - ordersUpdated.js
// - refundsCreate.js
//
// Phase-1 client alignment:
// - slots = quantity × unitsPerBundle
// - edits/refunds recalc totals (via delta reconciliation + stored snapshots)
// - planStatus is entitlement-driven (NO Brevo/Firebase activation gating):
//     slotsNet > 0  => active
//     slotsNet <= 0 => refunded

'use strict';

const admin = require('firebase-admin');

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

function asInt(v, fallback = 0) {
  const n = Number(v);
  return Number.isFinite(n) ? Math.trunc(n) : fallback;
}

function safeString(v) {
  return typeof v === 'string' ? v.trim() : String(v || '').trim();
}

function normalizeEmailLower(v) {
  const s = String(v || '').trim().toLowerCase();
  return s && s.includes('@') ? s : null;
}

/**
 * Extract Units-per-Bundle from a Shopify line_item.properties array.
 * Shopify returns properties as array: [{ name, value }, ...]
 */
function extractUnitsPerBundleFromProperties(properties) {
  if (!Array.isArray(properties)) return 1;

  for (const p of properties) {
    if (!p) continue;
    const name = String(p.name || '').toLowerCase();
    const value = String(p.value || '').trim();

    if (
      name === 'units_per_bundle' ||
      name === 'unitsperbundle' ||
      name === 'bundle_units' ||
      name === 'pack_size'
    ) {
      const n = parseInt(value, 10);
      if (!isNaN(n) && n > 0) return n;
    }
  }

  return 1;
}

/* -------------------------------------------------------------------------- */
/* Order entitlement snapshots                                                 */
/* -------------------------------------------------------------------------- */

function buildOrderEntitlement(order) {
  const lineItems = Array.isArray(order?.line_items) ? order.line_items : [];
  const lines = [];

  let unitsTotal = 0;

  for (const li of lineItems) {
    const quantity = asInt(li?.quantity, 0);
    if (quantity <= 0) continue;

 const unitsPerBundle =
  extractUnitsPerBundleFromProperties(li?.properties) ||
  extractUnitsPerBundleFromProperties(li?.custom_attributes) ||
  extractUnitsPerBundleFromProperties(li?.properties?.custom_attributes) ||
  1;
   
 const units = quantity * (unitsPerBundle || 1);

    unitsTotal += units;

    lines.push({
      lineItemId: li?.id != null ? String(li.id) : null,
      variantId: li?.variant_id != null ? String(li.variant_id) : null,
      sku: li?.sku != null ? String(li.sku) : null,
      title: li?.title != null ? String(li.title) : null,
      quantity,
      unitsPerBundle,
      units,
    });
  }

  return { unitsTotal, lines };
}

async function readOrderEntitlementSnapshot(orderId) {
  if (!orderId) return null;
  const ref = db.collection('shopifyOrders').doc(String(orderId));
  const snap = await ref.get();
  if (!snap.exists) return null;
  const d = snap.data() || {};
  return {
    entitlementUnitsTotal: asInt(d.entitlementUnitsTotal, 0),
    entitlementLines: Array.isArray(d.entitlementLines) ? d.entitlementLines : [],
  };
}

function resolveRefundUnitsPerBundle({ refundLineItem, orderEntitlementLines }) {
  const rli = refundLineItem || {};
  const li = rli?.line_item || null;

  const fromProps = extractUnitsPerBundleFromProperties(li?.properties);
  if (fromProps && fromProps !== 1) return fromProps;

  const lineItemId =
    li?.id != null
      ? String(li.id)
      : rli?.line_item_id != null
      ? String(rli.line_item_id)
      : null;

  if (lineItemId && Array.isArray(orderEntitlementLines)) {
    const match = orderEntitlementLines.find((x) => String(x?.lineItemId || '') === lineItemId);
    const u = asInt(match?.unitsPerBundle, 1);
    if (u > 0) return u;
  }

  return 1;
}

function buildRefundEntitlement(refund, { orderEntitlementLines = [] } = {}) {
  const items = Array.isArray(refund?.refund_line_items) ? refund.refund_line_items : [];

  const lines = [];
  let unitsRefundedTotal = 0;

  for (const rli of items) {
    const quantity = asInt(rli?.quantity, 0);
    if (quantity <= 0) continue;

    const unitsPerBundle = resolveRefundUnitsPerBundle({
      refundLineItem: rli,
      orderEntitlementLines,
    });

    const units = quantity * (unitsPerBundle || 1);
    unitsRefundedTotal += units;

    const li = rli?.line_item || null;

    lines.push({
      lineItemId:
        li?.id != null
          ? String(li.id)
          : rli?.line_item_id != null
          ? String(rli.line_item_id)
          : null,
      quantity,
      unitsPerBundle,
      units,
    });
  }

  return { unitsRefundedTotal, lines };
}

/* -------------------------------------------------------------------------- */
/* Account reconciliation + status transitions                                 */
/* -------------------------------------------------------------------------- */

function computeSlotsState({ slotsPurchasedTotal, slotsRefundedTotal, slotsUsed }) {
  const purchased = Math.max(0, asInt(slotsPurchasedTotal, 0));
  const refunded = Math.max(0, asInt(slotsRefundedTotal, 0));
  const used = Math.max(0, asInt(slotsUsed, 0));

  const net = purchased - refunded; // do NOT clamp; status needs <= 0
  const available = Math.max(0, net - used);

  return { slotsNet: net, slotsAvailable: available };
}

/**
 * Phase-1 Shopify-first planStatus:
 * - If slotsNet <= 0 => refunded
 * - If slotsNet > 0  => active
 *
 * No activatedAt / pendingActivation gating (Brevo/Firebase activation removed).
 */
function computeNextPlanStatus({ currentPlanStatus, slotsNet }) {
  const net = asInt(slotsNet, 0);
  if (net <= 0) return 'refunded';
  return 'active';
}

/**
 * Apply entitlement deltas to an account document in a single transaction.
 *
 * Use cases:
 * - orders/paid: deltaPurchasedUnits = +unitsFromOrder
 * - refunds/create: deltaRefundedUnits = +unitsRefunded
 * - orders/updated: deltaPurchasedUnits = (newUnits - oldUnits)
 *
 * NOTE: This must NOT modify platform email fields. Identity fields belong to
 * customer/order handlers, not entitlement reconciliation.
 */
async function applyEntitlementDeltaToAccount({
  customerId,
  deltaPurchasedUnits = 0,
  deltaRefundedUnits = 0,
  reason = null,
}) {
  if (!customerId) throw new Error('applyEntitlementDeltaToAccount: customerId is required');

  const accountRef = db.collection('accounts').doc(String(customerId));
  const now = admin.firestore.FieldValue.serverTimestamp();

  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(accountRef);
    const data = snap.exists ? snap.data() || {} : {};

    const prevPurchased = asInt(data.slotsPurchasedTotal, 0);
    const prevRefunded = asInt(data.slotsRefundedTotal, 0);
    const slotsUsed = asInt(data.slotsUsed, 0);

    const newPurchased = prevPurchased + asInt(deltaPurchasedUnits, 0);
    const newRefunded = prevRefunded + asInt(deltaRefundedUnits, 0);

    const { slotsNet, slotsAvailable } = computeSlotsState({
      slotsPurchasedTotal: newPurchased,
      slotsRefundedTotal: newRefunded,
      slotsUsed,
    });

    const nextPlanStatus = computeNextPlanStatus({
      currentPlanStatus: data.planStatus,
      slotsNet,
    });

    const patch = {
      planStatus: nextPlanStatus,

      slotsPurchasedTotal: newPurchased,
      slotsRefundedTotal: newRefunded,
      slotsNet,
      slotsAvailable,

      entitlementLastReason: reason ? safeString(reason).slice(0, 120) : null,
      entitlementUpdatedAt: now,
      updatedAt: now,
    };

    if (!snap.exists) {
      tx.set(accountRef, {
        shopifyCustomerId: String(customerId),
        slotsUsed: 0,
        createdAt: now,
        ...patch,
      });
    } else {
      tx.update(accountRef, patch);
    }

    return { slotsNet, slotsAvailable, planStatus: nextPlanStatus };
  });

  return result;
}

async function writeOrderEntitlementSnapshot({ orderId, customerId, email, entitlement, lastEvent = null }) {
  if (!orderId) throw new Error('writeOrderEntitlementSnapshot: orderId is required');

  const ref = db.collection('shopifyOrders').doc(String(orderId));
  const now = admin.firestore.FieldValue.serverTimestamp();

  const payload = {
    shopifyOrderId: String(orderId),
    shopifyCustomerId: customerId != null ? String(customerId) : null,
    emailLower: normalizeEmailLower(email),

    entitlementUnitsTotal: asInt(entitlement?.unitsTotal, 0),
    entitlementLines: Array.isArray(entitlement?.lines) ? entitlement.lines : [],

    lastEvent: lastEvent || null,
    updatedAt: now,
  };

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      tx.set(ref, { ...payload, createdAt: now });
    } else {
      tx.update(ref, payload);
    }
  });
}

module.exports = {
  extractUnitsPerBundleFromProperties,
  buildOrderEntitlement,
  buildRefundEntitlement,

  readOrderEntitlementSnapshot,

  computeSlotsState,
  computeNextPlanStatus,
  applyEntitlementDeltaToAccount,

  writeOrderEntitlementSnapshot,
};
