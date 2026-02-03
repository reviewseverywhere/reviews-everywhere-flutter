'use strict';

// functions/shopify/refundsCreate.js

const { verifyShopifyWebhook } = require('./verifyShopify');
const {
  admin,
  db,
  acquireWebhookLock,
  markWebhookProcessed,
  markWebhookFailed,
} = require('./common');

// ✅ NEW: centralized entitlement helpers (bundle-aware) + consistent status rules
const {
  buildRefundEntitlement,
  computeSlotsState,
  computeNextPlanStatus,
} = require('./entitlements');

function normalizeRefundFromWebhook(body) {
  // Shopify sometimes wraps payload; be defensive
  if (body && body.refund && typeof body.refund === 'object') return body.refund;
  return body || {};
}

async function refundsCreateHandler(req, res) {
  let lock = null;

  try {
    if (req.method === 'GET') {
      res.status(200).send('refunds/create webhook live');
      return;
    }
    if (req.method !== 'POST') {
      res.status(405).send('Method not allowed');
      return;
    }

    // 🔐 Security: HMAC verification
    if (!verifyShopifyWebhook(req)) {
      console.error('Invalid HMAC on refunds/create');
      res.status(401).send('Unauthorized');
      return;
    }

    const refund = normalizeRefundFromWebhook(req.body);
    const refundId = String(refund?.id || '');
    const orderId = String(refund?.order_id || '');

    // ✅ Phase 0: Webhook idempotency (Shopify retries deliveries)
    lock = await acquireWebhookLock(req, {
      topic: 'refunds/create',
      refundId: refundId || null,
      orderId: orderId || null,
    });

    if (!lock.shouldProcess) {
      res.status(200).send('OK');
      return;
    }

    if (!refundId) {
      console.error('refunds/create missing refund.id');
      await markWebhookProcessed(lock.eventRef);
      res.status(200).send('OK');
      return;
    }

    console.log('▶️ refunds/create', { refundId, orderId });

    const refundRef = db.collection('shopifyRefunds').doc(refundId);
    const orderRef = orderId ? db.collection('shopifyOrders').doc(orderId) : null;

    // ✅ Bundle-aware refund units
    const entitlement = buildRefundEntitlement(refund);
    const unitsRefunded = Number(entitlement.unitsRefundedTotal || 0);

    await db.runTransaction(async (tx) => {
      const now = admin.firestore.FieldValue.serverTimestamp();

      // 1) ALL READS FIRST
      const refundSnap = await tx.get(refundRef);
      const orderSnap = orderRef ? await tx.get(orderRef) : null;

      // Local idempotency safety: if refund doc already exists, do nothing
      if (refundSnap.exists) {
        tx.update(refundRef, { lastWebhookAt: now, updatedAt: now });
        return;
      }

      const orderData = orderSnap && orderSnap.exists ? (orderSnap.data() || {}) : null;
      const customerId = orderData ? String(orderData.shopifyCustomerId || '') : null;

      let accountRef = null;
      let accountSnap = null;

      if (customerId) {
        accountRef = db.collection('accounts').doc(customerId);
        accountSnap = await tx.get(accountRef); // still part of reads
      }

      // 2) WRITES AFTER ALL READS

      // Record the refund itself (auditable; do not delete)
      tx.set(refundRef, {
        shopifyRefundId: String(refund.id),
        shopifyOrderId: orderId || null,
        shopifyCustomerId: customerId || null,

        amount:
          Array.isArray(refund?.transactions) && refund.transactions[0]
            ? Number(refund.transactions[0].amount || 0)
            : null,
        currency: refund?.currency || null,

        // ✅ Bundle-aware units
        entitlementUnitsRefunded: unitsRefunded,
        entitlementLines: Array.isArray(entitlement.lines) ? entitlement.lines : [],

        // Backward-compatible field (if you used it elsewhere)
        slotsRefunded: unitsRefunded,

        createdAt: now,
        updatedAt: now,
        lastWebhookAt: now,
        lastEvent: 'refunds/create',
        rawReason: refund?.note || null,
      });

      // Optionally annotate the order doc (useful for future reconciliation)
      if (orderRef) {
        if (orderSnap && orderSnap.exists) {
          tx.update(orderRef, {
            entitlementUnitsRefundedTotal: admin.firestore.FieldValue.increment(
              Number.isFinite(unitsRefunded) ? unitsRefunded : 0
            ),
            lastRefundAt: now,
            updatedAt: now,
          });
        } else {
          // Order doc missing (should be rare). We do NOT create it here.
        }
      }

      // Adjust account slot counters if we know the customer and account exists
      if (accountRef && accountSnap && accountSnap.exists) {
        const data = accountSnap.data() || {};

        const prevPurchased = Number(data.slotsPurchasedTotal || 0);
        const prevRefunded = Number(data.slotsRefundedTotal || 0);
        const prevUsed = Number(data.slotsUsed || 0);

        // Add refund units; clamp to purchased total to avoid negative net from data mismatch
        const rawNewRefunded = prevRefunded + (Number.isFinite(unitsRefunded) ? unitsRefunded : 0);
        const newRefunded =
          Number.isFinite(prevPurchased) && prevPurchased >= 0
            ? Math.min(rawNewRefunded, prevPurchased)
            : rawNewRefunded;

        const { slotsNet, slotsAvailable } = computeSlotsState({
          slotsPurchasedTotal: prevPurchased,
          slotsRefundedTotal: newRefunded,
          slotsUsed: prevUsed,
        });

        const activatedAt = data.activatedAt || null;

        // ✅ Client-aligned status logic:
        // - net <= 0 => refunded (ineligible)
        // - otherwise keep current, unless returning from refunded with entitlement restored (handled elsewhere)
        const nextPlanStatus = computeNextPlanStatus({
          currentPlanStatus: data.planStatus,
          slotsNet,
          activatedAt,
        });

        tx.update(accountRef, {
          slotsRefundedTotal: newRefunded,
          slotsNet,
          slotsAvailable,
          planStatus: nextPlanStatus,
          entitlementLastReason: 'refunds/create',
          entitlementUpdatedAt: now,
          updatedAt: now,
        });
      }
    });

    await markWebhookProcessed(lock.eventRef);
    res.status(200).send('OK');
  } catch (err) {
    console.error('Error in refundsCreateHandler:', err);

    if (lock?.eventRef) {
      try {
        await markWebhookFailed(lock.eventRef, err);
      } catch (_) {
        // ignore secondary failure
      }
    }

    res.status(500).send('Internal error');
  }
}

module.exports = {
  refundsCreateHandler,
};
