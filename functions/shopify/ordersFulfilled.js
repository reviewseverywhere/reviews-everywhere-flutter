// functions/shopify/ordersFulfilled.js
const { verifyShopifyWebhook } = require("./verifyShopify");
const {
  upsertOrderDoc,
  acquireWebhookLock,
  markWebhookProcessed,
  markWebhookFailed,
} = require("./common");

async function ordersFulfilledHandler(req, res) {
  let lock = null;

  try {
    if (req.method === "GET") {
      res.status(200).send("orders/fulfilled webhook live");
      return;
    }
    if (req.method !== "POST") {
      res.status(405).send("Method not allowed");
      return;
    }

    // 🔐 Security: HMAC verification
    if (!verifyShopifyWebhook(req)) {
      console.error("Invalid HMAC on orders/fulfilled");
      res.status(401).send("Unauthorized");
      return;
    }

    const order = req.body;
    const orderId = String(order?.id || "");
    const customerId =
      order && order.customer && order.customer.id ? String(order.customer.id) : null;

    // ✅ Phase 0: Webhook idempotency
    lock = await acquireWebhookLock(req, {
      topic: "orders/fulfilled",
      orderId: orderId || null,
      customerId: customerId || null,
    });

    if (!lock.shouldProcess) {
      res.status(200).send("OK");
      return;
    }

    console.log("▶️ orders/fulfilled", { id: order.id });

    await upsertOrderDoc(order, {
      lastEvent: "orders/fulfilled",
      fulfilledAt: order.fulfilled_at || null,
    });

    await markWebhookProcessed(lock.eventRef);
    res.status(200).send("OK");
  } catch (err) {
    console.error("Error in ordersFulfilledHandler:", err);

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
  ordersFulfilledHandler,
};
