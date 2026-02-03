'use strict';

// functions/shopify/ordersUpdated.js

const { verifyShopifyWebhook } = require('./verifyShopify');
const {
  admin,
  db,
  acquireWebhookLock,
  markWebhookProcessed,
  markWebhookFailed,
} = require('./common');

// ✅ Centralized entitlement + consistent slot/status math
const {
  buildOrderEntitlement,
  computeSlotsState,
  computeNextPlanStatus,
} = require('./entitlements');

function normalizeEmail(v) {
  const s = String(v || '').trim().toLowerCase();
  return s || null;
}

function normalizeOrderFromWebhook(body) {
  if (body && Array.isArray(body.line_items)) return body;
  if (body && body.order && Array.isArray(body.order.line_items)) return body.order;
  return body || {};
}

function extractCustomerId(order) {
  const customerId =
    order?.customer?.id != null ? String(order.customer.id) : null;
  return customerId;
}

function extractShopifyEmail(order) {
  const emailRaw =
    order?.customer?.email ??
    order?.email ??
    null;

  return emailRaw ? normalizeEmail(emailRaw) : null;
}

function isPaidFinancialStatus(financialStatus) {
  const s = String(financialStatus || '').toLowerCase();
  // We only credit entitlements when Shopify confirms a paid state.
  // (Refunds are handled separately via refunds/create.)
  return s === 'paid';
}

async function ordersUpdatedHandler(req, res) {
  let lock = null;

  try {
    if (req.method === 'GET') {
      res.status(200).send('orders/updated webhook live');
      return;
    }
    if (req.method !== 'POST') {
      res.status(405).send('Method not allowed');
      return;
    }

    // 🔐 Security: HMAC verification
    if (!verifyShopifyWebhook(req)) {
      console.error('Invalid HMAC on orders/updated');
      res.status(401).send('Unauthorized');
      return;
    }

    const rawBody = req.body || {};
    const order = normalizeOrderFromWebhook(rawBody);

    const orderId = order?.id != null ? String(order.id) : '';
    const customerId = extractCustomerId(order);
    const shopifyEmail = extractShopifyEmail(order);

    // ✅ Phase 0: Webhook idempotency
    lock = await acquireWebhookLock(req, {
      topic: 'orders/updated',
      orderId: orderId || null,
      customerId: customerId || null,
    });

    if (!lock.shouldProcess) {
      res.status(200).send('OK');
      return;
    }

    if (!orderId) {
      await markWebhookProcessed(lock.eventRef);
      res.status(200).send('OK');
      return;
    }

    console.log('▶️ orders/updated', { orderId, customerId });

    const orderRef = db.collection('shopifyOrders').doc(orderId);
    const accountRef =
      customerId ? db.collection('accounts').doc(customerId) : null;

    // ✅ Bundle-aware snapshot from the updated order payload
    const entitlement = buildOrderEntitlement(order);
    const newUnitsTotal = Number(entitlement.unitsTotal || 0);

    const paidNow = isPaidFinancialStatus(order?.financial_status);

    await db.runTransaction(async (tx) => {
      const now = admin.firestore.FieldValue.serverTimestamp();

      // 1) ALL READS FIRST
      const orderSnap = await tx.get(orderRef);

      let accountSnap = null;
      if (accountRef) {
        accountSnap = await tx.get(accountRef);
      }

      const prevOrderData = orderSnap.exists ? (orderSnap.data() || {}) : {};

      // Previous credited units (idempotency + reconciliation)
      const prevCreditedUnits =
        prevOrderData.entitlementUnitsCredited != null
          ? Number(prevOrderData.entitlementUnitsCredited || 0)
          : (prevOrderData.slotsCredited != null ? Number(prevOrderData.slotsCredited || 0) : 0);

      // We only change purchased totals when the order is in a PAID state.
      // If Shopify updates the order for other reasons (fulfilled, refunded, etc.),
      // refunds/create is responsible for slot deductions.
      const shouldReconcilePurchasedUnits = paidNow;

      const unitsDelta = shouldReconcilePurchasedUnits
        ? (newUnitsTotal - prevCreditedUnits)
        : 0;

      // 2) WRITE ORDER DOC (always keep metadata fresh; keep credit marker stable unless paidNow)
      const baseOrderUpdate = {
        shopifyOrderId: orderId,
        shopifyCustomerId: customerId || prevOrderData.shopifyCustomerId || null,
        email: shopifyEmail || prevOrderData.email || null,
        shopifyEmail: shopifyEmail || prevOrderData.shopifyEmail || null,

        financialStatus: order?.financial_status || prevOrderData.financialStatus || null,
        fulfillmentStatus: order?.fulfillment_status || prevOrderData.fulfillmentStatus || null,
        cancelledAt: order?.cancelled_at || prevOrderData.cancelledAt || null,

        // Entitlement snapshot (for audit/debug + future reconciliation)
        entitlementUnitsTotal: newUnitsTotal,
        entitlementLines: Array.isArray(entitlement.lines) ? entitlement.lines : [],

        lastWebhookAt: now,
        lastEvent: 'orders/updated',
        updatedAt: now,
      };

      if (!orderSnap.exists) {
        // Create order doc if missing (orders/updated may arrive before orders/paid)
        tx.set(orderRef, {
          ...baseOrderUpdate,
          createdAt: now,
          // Do NOT mark processedAt here; orders/paid does that.
        });
      } else {
        tx.update(orderRef, baseOrderUpdate);
      }

      // 3) RECONCILE ACCOUNT PURCHASED UNITS (ONLY IF PAID)
      if (!accountRef || !customerId) return;

      if (!shouldReconcilePurchasedUnits) {
        // Not paid: do not touch counters
        return;
      }

      // If no delta, nothing to do beyond snapshot update.
      if (!Number.isFinite(unitsDelta) || unitsDelta === 0) {
        // Still ensure credited marker exists when paid and was missing/legacy
        if (paidNow && prevOrderData.entitlementUnitsCredited == null) {
          tx.set(
            orderRef,
            {
              entitlementUnitsCredited: newUnitsTotal,
              slotsCredited: newUnitsTotal, // backwards
              slotsFromOrder: newUnitsTotal, // backwards
            },
            { merge: true }
          );
        }
        return;
      }

      const accountExists = accountSnap && accountSnap.exists;
      const accountData = accountExists ? (accountSnap.data() || {}) : {};

      const prevPurchased = Number(accountData.slotsPurchasedTotal || 0);
      const prevRefunded = Number(accountData.slotsRefundedTotal || 0);
      const prevUsed = Number(accountData.slotsUsed || 0);

      const newPurchased = Math.max(0, prevPurchased + unitsDelta);

      const { slotsNet, slotsAvailable } = computeSlotsState({
        slotsPurchasedTotal: newPurchased,
        slotsRefundedTotal: prevRefunded,
        slotsUsed: prevUsed,
      });

      const activatedAt = accountData.activatedAt || null;

      const nextPlanStatus = computeNextPlanStatus({
        currentPlanStatus: accountData.planStatus,
        slotsNet,
        activatedAt,
      });

      // ✅ Platform email stability rule:
      // - do NOT overwrite platform email once set, unless it was previously in sync with Shopify
      const existingPlatformEmail = normalizeEmail(accountData.email);
      const existingShopifyEmail = normalizeEmail(accountData.shopifyEmail);
      const incomingShopifyEmail = shopifyEmail || existingShopifyEmail || null;

      const shouldUpdatePlatformEmail =
        !existingPlatformEmail ||
        (existingShopifyEmail && existingPlatformEmail === existingShopifyEmail);

      const platformEmailToUse = shouldUpdatePlatformEmail
        ? (existingPlatformEmail || incomingShopifyEmail)
        : existingPlatformEmail;

      const accountUpdate = {
        shopifyCustomerId: customerId,

        // platform login email (stable)
        ...(platformEmailToUse
          ? { email: platformEmailToUse, emailLower: normalizeEmail(platformEmailToUse) }
          : {}),

        // shopify email (can change)
        shopifyEmail: incomingShopifyEmail,

        slotsPurchasedTotal: newPurchased,
        slotsRefundedTotal: prevRefunded,
        slotsNet,
        slotsUsed: prevUsed,
        slotsAvailable,

        planStatus: nextPlanStatus,

        entitlementLastReason: 'orders/updated(reconcile)',
        entitlementUpdatedAt: now,
        updatedAt: now,
      };

      if (!accountExists) {
        // Rare, but possible if orders/paid didn't run yet and the order is already paid.
        tx.set(accountRef, { ...accountUpdate, createdAt: now });
      } else {
        tx.update(accountRef, accountUpdate);
      }

      // ✅ Update the order’s credited marker to the new reconciled amount
      tx.set(
        orderRef,
        {
          entitlementUnitsCredited: newUnitsTotal,
          slotsCredited: newUnitsTotal,  // backwards
          slotsFromOrder: newUnitsTotal, // backwards
          creditedUpdatedAt: now,
        },
        { merge: true }
      );
    });

    await markWebhookProcessed(lock.eventRef);
    res.status(200).send('OK');
  } catch (err) {
    console.error('Error in ordersUpdatedHandler:', err);

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
  ordersUpdatedHandler,
};
