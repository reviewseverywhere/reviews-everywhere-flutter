// functions/shopify/verifyShopify.js
const crypto = require("crypto");

// ✅ Shopify webhook secret from environment variable / Secret Manager
// Example:
//   SHOPIFY_WEBHOOK_SECRET=shpss_...
const SHOPIFY_SECRET = process.env.SHOPIFY_WEBHOOK_SECRET;

/**
 * Verify that the webhook really comes from Shopify (HMAC signature).
 *
 * Shopify sends header: X-Shopify-Hmac-Sha256 (base64)
 * We must compute HMAC on the RAW body bytes (req.rawBody).
 */
function verifyShopifyWebhook(req) {
  try {
    if (!SHOPIFY_SECRET) {
      console.error("SHOPIFY_WEBHOOK_SECRET is not set");
      return false;
    }

    const hmacHeader =
      req.get("X-Shopify-Hmac-Sha256") ||
      req.get("x-shopify-hmac-sha256") ||
      "";

    const rawBody = req.rawBody;

    if (!hmacHeader || !rawBody) {
      console.error("Missing HMAC header or rawBody");
      return false;
    }

    // Ensure we always hash bytes
    const bodyBuffer = Buffer.isBuffer(rawBody)
      ? rawBody
      : Buffer.from(rawBody, "utf8");

    // Compute digest as raw bytes
    const digestBuffer = crypto
      .createHmac("sha256", SHOPIFY_SECRET)
      .update(bodyBuffer)
      .digest(); // Buffer

    // Shopify header is base64; decode to bytes
    const headerBuffer = Buffer.from(hmacHeader, "base64");

    // timingSafeEqual requires same length
    if (headerBuffer.length !== digestBuffer.length) {
      return false;
    }

    return crypto.timingSafeEqual(headerBuffer, digestBuffer);
  } catch (err) {
    console.error("verifyShopifyWebhook error:", err);
    return false;
  }
}

module.exports = {
  verifyShopifyWebhook,
};
