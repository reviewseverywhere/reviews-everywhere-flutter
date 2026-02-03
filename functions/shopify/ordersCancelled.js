// functions/shopify/ordersCancelled.js
const { verifyShopifyWebhook } = require("./verifyShopify");
const {
  upsertOrderDoc,
  acquireWebhookLock,
  markWebhookProcessed,
  markWebhookFailed,
} = require("./common");

async function ordersCancelledHandler(req, res) {
  let lock = null;

  try {
    if (req.method === "GET") {
      res.status(200).send("orders/cancelled webhook live");
      return;
    }
    if (req.method !== "POST") {
      res.status(405).send("Method not allowed");
      return;
    }

    // 🔐 Security: HMAC verification
    if (!verifyShopifyWebhook(req)) {
      console.error("Invalid HMAC on orders/cancelled");
      res.status(401).send("Unauthorized");
      return;
    }

    const order = req.body;
    const orderId = String(order?.id || "");
    const customerId =
      order && order.customer && order.customer.id ? String(order.customer.id) : null;

    // ✅ Phase 0: Webhook idempotency
    lock = await acquireWebhookLock(req, {
      topic: "orders/cancelled",
      orderId: orderId || null,
      customerId: customerId || null,
    });

    if (!lock.shouldProcess) {
      res.status(200).send("OK");
      return;
    }

    console.log("▶️ orders/cancelled", { id: order.id });

    await upsertOrderDoc(order, {
      lastEvent: "orders/cancelled",
      cancelledAt: order.cancelled_at || null,
      cancelReason: order.cancel_reason || null,
    });

    await markWebhookProcessed(lock.eventRef);
    res.status(200).send("OK");
  } catch (err) {
    console.error("Error in ordersCancelledHandler:", err);

    if (lock?.eventRef) {
      try {
        await markWebhookFailed(lock.eventRef, err);
      } catch (_) {
        // ignore secondary failure
      }
    }

    res.status(500).send("Internal error");
  }
}

module.exports = {
  ordersCancelledHandler,
};
