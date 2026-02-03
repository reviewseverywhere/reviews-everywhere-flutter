'use strict';

// functions/shopify/brevoEmail.js

const BREVO_API_URL = "https://api.brevo.com/v3/smtp/email";

function requireEnv(name) {
  const v = process.env[name];
  if (!v) throw new Error(`${name} is missing in environment`);
  return v;
}

function isValidEmail(email) {
  return typeof email === "string" && email.includes("@") && email.includes(".");
}

/**
 * Send a transactional email via Brevo (Sendinblue).
 *
 * Expected env vars (runtime env / Secrets):
 * - BREVO_API_KEY            (Secret Manager via defineSecret)
 *
 * Optional env vars (non-secret):
 * - BREVO_SENDER_EMAIL       (must be a verified sender/domain in Brevo)
 * - BREVO_SENDER_NAME
 * - BREVO_TIMEOUT_MS         (default 15000)
 */
async function sendBrevoTransactionalEmail({
  toEmail,
  toName,
  subject,
  htmlContent,
  textContent,
  replyToEmail,
  replyToName,
  tags,
  headers,
}) {
  // ✅ Required: API key (comes from Firebase Secret at runtime)
  const apiKey = requireEnv("BREVO_API_KEY");

  // ✅ Sender: strongly recommended to set explicitly (verified in Brevo)
  // If not set, we keep a safe fallback for local tests only.
  const senderEmail = process.env.BREVO_SENDER_EMAIL || "devcodesky@gmail.com";
  const senderName = process.env.BREVO_SENDER_NAME || "Reviews Everywhere";

  // Basic validation (fail fast, prevents wasted retries)
  if (!isValidEmail(toEmail)) throw new Error("Invalid toEmail");
  if (!subject || typeof subject !== "string") throw new Error("Missing subject");
  if (!htmlContent && !textContent) throw new Error("Provide htmlContent or textContent");

  const payload = {
    sender: { email: senderEmail, name: senderName },
    to: [{ email: toEmail, name: toName || undefined }],
    subject,
    htmlContent: htmlContent || undefined,
    textContent: textContent || undefined,

    // Optional extras
    replyTo: replyToEmail ? { email: replyToEmail, name: replyToName || undefined } : undefined,
    tags: Array.isArray(tags) ? tags : undefined,
    headers: headers && typeof headers === "object" ? headers : undefined,
  };

  // Remove undefined keys (keeps payload clean)
  Object.keys(payload).forEach((k) => payload[k] === undefined && delete payload[k]);

  const timeoutMs = Number(process.env.BREVO_TIMEOUT_MS || 15000);
  const controller = new AbortController();
  const t = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const res = await fetch(BREVO_API_URL, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "accept": "application/json",
        "api-key": apiKey,
      },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });

    const bodyText = await res.text();
    let bodyJson = null;
    try {
      bodyJson = JSON.parse(bodyText);
    } catch (_) {
      // Brevo usually returns JSON, but keep robust
    }

    if (!res.ok) {
      // Keep error short to avoid huge logs / bills
      throw new Error(`Brevo send failed (${res.status}): ${bodyText.slice(0, 400)}`);
    }

    return bodyJson || { raw: bodyText };
  } finally {
    clearTimeout(t);
  }
}

module.exports = { sendBrevoTransactionalEmail };
