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
 * Returns the parsed value if found, or null if no matching property.
 */
function extractUnitsPerBundleFromProperties(properties) {
  const props = Array.isArray(properties) ? properties : [];
  const candidates = new Set([
    'units per bundle',
    'unit per bundle',
    'bundle units',
    'units_per_bundle',
    'unitsperbundle',
    'bundle_units',
    'pack_size',
  ]);

  for (const p of props) {
    const name = String(p?.name || '').trim().toLowerCase();
    if (!name || !candidates.has(name)) continue;

    const raw = String(p?.value ?? '').trim();
    const n = Number(raw);
    if (Number.isFinite(n) && n > 0) return Math.floor(n);
  }
  return null;
}

/**
 * Extract units-per-bundle from variant_title string.
 * Examples:
 *   "Single (1)" -> 1
 *   "Pack of 5" -> 5
 *   "Pack of 10 (10% off)" -> 10
 *   "Pack of 20 (15% off)" -> 20
 * Returns null if nothing valid found.
 */
function extractUnitsPerBundleFromVariantTitle(variantTitle) {
  if (!variantTitle || typeof variantTitle !== 'string') return null;
  const s = variantTitle.trim().toLowerCase();
  if (!s) return null;

  // 1) "pack of N"
  const packMatch = s.match(/pack\s+of\s+(\d+)/);
  if (packMatch) {
    const n = parseInt(packMatch[1], 10);
    if (n > 0) return n;
  }

  // 2) "(N)" where N is a number not followed by %
  const parenMatch = s.match(/\((\d+)\)/);
  if (parenMatch) {
    const afterParen = s.substring(s.indexOf(parenMatch[0]) + parenMatch[0].length);
    if (!afterParen.trimStart().startsWith('%')) {
      const n = parseInt(parenMatch[1], 10);
      if (n > 0) return n;
    }
  }

  // 3) First standalone integer not followed by %
  const standaloneMatch = s.match(/(?:^|\s)(\d+)(?!\s*%)/);
  if (standaloneMatch) {
    const n = parseInt(standaloneMatch[1], 10);
    if (n > 0) return n;
  }

  return null;
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
      extractUnitsPerBundleFromProperties(li?.properties)
      ?? extractUnitsPerBundleFromProperties(li?.custom_attributes)
      ?? extractUnitsPerBundleFromProperties(li?.properties?.custom_attributes)
      ?? extractUnitsPerBundleFromVariantTitle(li?.variant_title)
      ?? 1;

    const units = quantity * unitsPerBundle;

    unitsTotal += units;

    lines.push({
      lineItemId: li?.id != null ? String(li.id) : null,
      variantId: li?.variant_id != null ? String(li.variant_id) : null,
      sku: li?.sku != null ? String(li.sku) : null,
      title: li?.title != null ? String(li.title) : null,
      variantTitle: li?.variant_title != null ? String(li.variant_title) : null,
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

  const fromProps =
    extractUnitsPerBundleFromProperties(li?.properties)
    ?? extractUnitsPerBundleFromProperties(li?.custom_attributes)
    ?? extractUnitsPerBundleFromProperties(li?.properties?.custom_attributes);
  if (fromProps != null && fromProps > 1) return fromProps;

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

  const fromVariant = extractUnitsPerBundleFromVariantTitle(li?.variant_title);
  if (fromVariant != null) return fromVariant;

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
  extractUnitsPerBundleFromVariantTitle,
  buildOrderEntitlement,
  buildRefundEntitlement,

  readOrderEntitlementSnapshot,

  computeSlotsState,
  computeNextPlanStatus,
  applyEntitlementDeltaToAccount,

  writeOrderEntitlementSnapshot,
};
