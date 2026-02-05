'use strict';

// functions/shopify/orderPaid.js
//
// Client-aligned behavior (Shopify-first identity):
// - Idempotent orders/paid handling (webhook lock + per-order credit marker)
// - Bundle-aware entitlement math (qty × unitsPerBundle)
// - Writes an immutable “credited entitlement snapshot” to shopifyOrders/{orderId}
// - Updates account slot totals + planStatus deterministically (Paid + slotsNet>0 => active)
// - NO Brevo/Firebase activation lifecycle (no activation email, no password reset link)
// - Keeps platform login email stable (do not overwrite once it diverges from Shopify email)
// - Maintains email_index/{emailLower} -> shopifyCustomerId mapping (collision-safe)

const admin = require('firebase-admin');
const { verifyShopifyWebhook } = require('./verifyShopify');
const { acquireWebhookLock, markWebhookProcessed, markWebhookFailed } = require('./common');
const { buildOrderEntitlement, computeSlotsState } = require('./entitlements');

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();
const auth = admin.auth();

/* -------------------------------------------------------------------------- */
/* Helpers                                                                    */
/* -------------------------------------------------------------------------- */

function normalizeEmail(v) {
  const s = String(v || '').trim().toLowerCase();
  return s || null;
}

function looksLikeEmail(v) {
  return typeof v === 'string' && v.includes('@') && v.includes('.');
}

function normalizeOrderFromWebhook(body) {
  if (body && Array.isArray(body.line_items)) return body;
  if (body && body.order && Array.isArray(body.order.line_items)) return body.order;
  return body || {};
}

function extractIds(order, rawBody) {
  const id =
    order?.id ??
    rawBody?.id ??
    rawBody?.order_id ??
    (rawBody?.order && rawBody.order.id) ??
    null;

  const customer =
    order?.customer ??
    rawBody?.customer ??
    (rawBody?.order && rawBody.order.customer) ??
    null;

  const emailRaw = customer?.email ?? order?.email ?? rawBody?.email ?? null;
  const email = looksLikeEmail(emailRaw) ? normalizeEmail(emailRaw) : null;

  return {
    orderId: id ? String(id) : '',
    customerId: customer?.id ? String(customer.id) : null,
    email, // normalized lower-case or null
  };
}

/**
 * Phase 1 planStatus rules (Shopify-first):
 * - If slotsNet > 0 => active
 * - If currently refunded => keep refunded
 * - Else keep current (inactive/cancelled/etc.)
 *
 * Note: "refunded" transitions should primarily be handled in refundsCreate/ordersUpdated.
 * This keeps orders/paid safe and deterministic.
 */
function computePlanStatusShopifyFirst({ currentPlanStatus, slotsNet }) {
  const cur = String(currentPlanStatus || 'inactive');
  const net = Number(slotsNet || 0);

  if (net > 0) return 'active';
  if (cur === 'refunded') return 'refunded';
  return cur;
}

/**
 * Provision Firebase Auth user for password-based login.
 * Creates user with email but no password (user must use password reset flow).
 * This is required for Firebase sendPasswordResetEmail to work.
 * 
 * Strategy: Check if user exists by email first (may have been created via social login).
 * If exists, use that UID. If not, create new user with auto-generated UID.
 * The authUid is stored in the account document for consistent mapping.
 * 
 * Note: We do NOT force UID=shopifyCustomerId because:
 * - Social login users may already have Firebase Auth accounts with random UIDs
 * - The authUid field in accounts/{customerId} tracks the mapping
 */
async function provisionFirebaseAuthUser({ email, shopifyCustomerId }) {
  if (!email || !shopifyCustomerId) {
    console.log('[provisionFirebaseAuthUser] skipping - missing email or customerId');
    return null;
  }

  const emailLower = normalizeEmail(email);

  try {
    // Check if user already exists with this email (may be from social login)
    const existingUser = await auth.getUserByEmail(emailLower).catch(() => null);
    
    if (existingUser) {
      console.log(`[provisionFirebaseAuthUser] user exists with email=${emailLower} uid=${existingUser.uid}`);
      // Return existing user - their UID will be stored as authUid in account doc
      return existingUser;
    }

    // Create new Firebase Auth user with auto-generated UID
    // Do NOT specify uid to avoid conflicts with custom token flow
    const newUser = await auth.createUser({
      email: emailLower,
      emailVerified: false,
      disabled: false,
    });

    console.log(`[provisionFirebaseAuthUser] created new user uid=${newUser.uid} email=${emailLower}`);
    return newUser;
  } catch (err) {
    console.error(`[provisionFirebaseAuthUser] error for email=${emailLower}:`, err);
    // Don't throw - webhook should still succeed even if auth user creation fails
    return null;
  }
}

/**
 * Collision-safe email_index mapping.
 * If an email is already mapped to a different customerId, do NOT overwrite.
 */
async function upsertEmailIndexTx(tx, { emailLower, shopifyCustomerId }) {
  if (!emailLower || !shopifyCustomerId) return;

  const idxRef = db.collection('email_index').doc(String(emailLower));
  const now = admin.firestore.FieldValue.serverTimestamp();

  const snap = await tx.get(idxRef);
  if (!snap.exists) {
    tx.set(idxRef, {
      emailLower: String(emailLower),
      shopifyCustomerId: String(shopifyCustomerId),
      createdAt: now,
      updatedAt: now,
    });
    return;
  }

  const existing = snap.data() || {};
  const existingId = existing.shopifyCustomerId ? String(existing.shopifyCustomerId) : null;

  if (existingId && existingId === String(shopifyCustomerId)) {
    tx.set(idxRef, { updatedAt: now }, { merge: true });
    return;
  }

  const conflictRef = db
    .collection('email_index_conflicts')
    .doc(`${String(emailLower)}__${String(shopifyCustomerId)}`);

  tx.set(
    conflictRef,
    {
      emailLower: String(emailLower),
      attemptedShopifyCustomerId: String(shopifyCustomerId),
      existingShopifyCustomerId: existingId,
      createdAt: now,
    },
    { merge: true }
  );
}

/* -------------------------------------------------------------------------- */
/* Main handler                                                               */
/* -------------------------------------------------------------------------- */

async function shopifyOrderPaidHandler(req, res) {
  let lock = null;

  try {
    if (req.method === 'GET') return res.status(200).send('shopifyOrderPaid is live');
    if (req.method !== 'POST') return res.status(405).send('Method not allowed');

    if (!verifyShopifyWebhook(req)) {
      console.error('❌ Invalid Shopify HMAC (orders/paid)');
      return res.status(401).send('Unauthorized');
    }

    const rawBody = req.body || {};
    const order = normalizeOrderFromWebhook(rawBody);
    const { orderId, customerId, email } = extractIds(order, rawBody);

    // ⚠️ TEMP SHOPIFY WEBHOOK DEBUG – REMOVE AFTER VERIFICATION
    console.log('⚠️ TEMP SHOPIFY WEBHOOK DEBUG – REMOVE AFTER VERIFICATION');
    console.log('='.repeat(60));
    console.log('RAW req.body:', req.body);
    console.log('FULL WEBHOOK PAYLOAD (formatted):', JSON.stringify(rawBody, null, 2));
    console.log('='.repeat(60));
    console.log('EXTRACTED IDS:');
    console.log('  order.id:', order?.id ?? rawBody?.id ?? 'MISSING');
    console.log('  customer.id:', order?.customer?.id ?? rawBody?.customer?.id ?? 'MISSING');
    console.log('  customer.email:', order?.customer?.email ?? rawBody?.customer?.email ?? 'MISSING');
    console.log('='.repeat(60));
    console.log('LINE ITEMS COUNT:', Array.isArray(order?.line_items) ? order.line_items.length : 0);
    if (Array.isArray(order?.line_items)) {
      order.line_items.forEach((li, idx) => {
        console.log(`LINE ITEM [${idx}]:`);
        console.log('  title:', li?.title ?? 'MISSING');
        console.log('  quantity:', li?.quantity ?? 'MISSING');
        console.log('  variant_title:', li?.variant_title ?? 'MISSING');
        console.log('  properties:', JSON.stringify(li?.properties ?? [], null, 2));
      });
    }
    console.log('='.repeat(60));
    console.log('⚠️ END TEMP DEBUG');
    // ⚠️ END TEMP SHOPIFY WEBHOOK DEBUG

    lock = await acquireWebhookLock(req, {
      topic: 'orders/paid',
      orderId: orderId || null,
      customerId: customerId || null,
    });

    if (!lock.shouldProcess) return res.status(200).send('OK');

    // Missing stable IDs => acknowledge to prevent retry loops
    if (!orderId || !customerId) {
      await markWebhookProcessed(lock.eventRef);
      return res.status(200).send('OK');
    }

    const entitlement = buildOrderEntitlement(order);
    const unitsFromOrder = Number(entitlement?.unitsTotal || 0);

    const orderRef = db.collection('shopifyOrders').doc(orderId);
    const accountRef = db.collection('accounts').doc(customerId);

    const emailLower = email ? normalizeEmail(email) : null;

    await db.runTransaction(async (tx) => {
      const now = admin.firestore.FieldValue.serverTimestamp();

      // ✅ READS FIRST (and only reads)
      const [existingOrderSnap, accountSnap] = await Promise.all([
        tx.get(orderRef),
        tx.get(accountRef),
      ]);

      // ✅ upsertEmailIndexTx includes a tx.get internally, so it MUST run before any writes
      if (emailLower) {
        await upsertEmailIndexTx(tx, {
          emailLower,
          shopifyCustomerId: customerId,
        });
      }

      const orderExists = existingOrderSnap.exists;
      const orderData = orderExists ? existingOrderSnap.data() || {} : {};

      // Credit ONCE per order
      const creditedUnitsFromDoc =
        orderData.entitlementUnitsCredited != null
          ? Number(orderData.entitlementUnitsCredited || 0)
          : (orderData.slotsCredited != null ? Number(orderData.slotsCredited || 0) : null);

      const hasCreditMarker = creditedUnitsFromDoc != null;
      const shouldCreditUnits = !orderExists || !hasCreditMarker;
      const unitsDelta = shouldCreditUnits ? unitsFromOrder : 0;

      // --- Order doc snapshot (immutable baseline) --------------------------
      if (!orderExists) {
        tx.set(orderRef, {
          shopifyOrderId: orderId,
          shopifyCustomerId: customerId,
          shopifyEmail: emailLower || null,

          entitlementUnitsTotal: unitsFromOrder,
          entitlementLines: Array.isArray(entitlement.lines) ? entitlement.lines : [],
          entitlementUnitsCredited: unitsFromOrder,

          // Backward-compatible
          slotsFromOrder: unitsFromOrder,
          slotsCredited: unitsFromOrder,

          processedAt: now,
          financialStatus: order.financial_status || null,
          fulfillmentStatus: order.fulfillment_status || null,
          cancelledAt: order.cancelled_at || null,

          createdAt: now,
          updatedAt: now,
          lastWebhookAt: now,
          lastEvent: 'orders/paid',
        });
      } else {
        const hasSnapshot =
          orderData.entitlementUnitsTotal != null && Array.isArray(orderData.entitlementLines);

        tx.update(orderRef, {
          shopifyEmail: emailLower || orderData.shopifyEmail || null,

          ...(hasSnapshot
            ? {}
            : {
                entitlementUnitsTotal: unitsFromOrder,
                entitlementLines: Array.isArray(entitlement.lines) ? entitlement.lines : [],
              }),

          ...(!hasCreditMarker
            ? {
                entitlementUnitsCredited: unitsFromOrder,
                slotsCredited: unitsFromOrder,
                slotsFromOrder: unitsFromOrder,
              }
            : {}),

          financialStatus: order.financial_status || orderData.financialStatus || null,
          fulfillmentStatus: order.fulfillment_status || orderData.fulfillmentStatus || null,
          cancelledAt: order.cancelled_at || orderData.cancelledAt || null,

          lastWebhookAt: now,
          lastEvent: 'orders/paid',
          updatedAt: now,
        });
      }

      // --- Account totals + Shopify-first planStatus ------------------------
      const accountData = accountSnap.exists ? accountSnap.data() || {} : {};

      const prevPurchased = Number(accountData.slotsPurchasedTotal || 0);
      const prevRefunded = Number(accountData.slotsRefundedTotal || 0);
      const prevUsed = Number(accountData.slotsUsed || 0);

      const newPurchased = Math.max(0, prevPurchased + Number(unitsDelta || 0));

      const { slotsNet, slotsAvailable } = computeSlotsState({
        slotsPurchasedTotal: newPurchased,
        slotsRefundedTotal: prevRefunded,
        slotsUsed: prevUsed,
      });

      const existingPlatformEmail = normalizeEmail(accountData.email);
      const existingShopifyEmail = normalizeEmail(accountData.shopifyEmail);
      const incomingShopifyEmail = emailLower || existingShopifyEmail || null;

      const shouldUpdatePlatformEmail =
        !existingPlatformEmail ||
        (existingShopifyEmail && existingPlatformEmail === existingShopifyEmail) ||
        (!existingShopifyEmail && existingPlatformEmail === incomingShopifyEmail);

      const platformEmailToUse = shouldUpdatePlatformEmail
        ? (existingPlatformEmail || incomingShopifyEmail)
        : existingPlatformEmail;

      const nextPlanStatus = computePlanStatusShopifyFirst({
        currentPlanStatus: accountData.planStatus,
        slotsNet,
      });

      const baseAccount = {
        shopifyCustomerId: customerId,

        ...(platformEmailToUse
          ? { email: platformEmailToUse, emailLower: normalizeEmail(platformEmailToUse) }
          : {}),

        ...(incomingShopifyEmail
          ? { shopifyEmail: incomingShopifyEmail, shopifyEmailLower: incomingShopifyEmail }
          : {}),

        slotsPurchasedTotal: newPurchased,
        slotsRefundedTotal: prevRefunded,
        slotsNet,
        slotsUsed: prevUsed,
        slotsAvailable,

        planStatus: nextPlanStatus,
        updatedAt: now,
      };

      if (!accountSnap.exists) tx.set(accountRef, { ...baseAccount, createdAt: now });
      else tx.set(accountRef, baseAccount, { merge: true });
    });

    // Provision Firebase Auth user for password-based login (outside transaction)
    // This enables Firebase password reset emails to work
    if (emailLower && customerId) {
      const authUser = await provisionFirebaseAuthUser({
        email: emailLower,
        shopifyCustomerId: customerId,
      });
      
      // Update account with authUid if user was created/found
      if (authUser?.uid) {
        await db.collection('accounts').doc(customerId).set({
          authUid: authUser.uid,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      }
    }

    await markWebhookProcessed(lock.eventRef);
    return res.status(200).send('OK');
  } catch (err) {
    console.error('[shopifyOrderPaidHandler] error:', err);
    if (lock?.eventRef) {
      try {
        await markWebhookFailed(lock.eventRef, err);
      } catch (_) {}
    }
    return res.status(500).send('Internal error');
  }
}

module.exports = { shopifyOrderPaidHandler };
