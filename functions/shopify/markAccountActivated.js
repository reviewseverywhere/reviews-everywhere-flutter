'use strict';

// functions/shopify/markAccountActivated.js
//
// Phase-1 client alignment (Shopify-first identity):
// - No platform-side "activation" lifecycle.
// - Do NOT set planStatus, activatedAt, or any activation flags from the app.
// - Shopify remains the identity owner; Firebase only syncs downstream from Shopify webhooks.
//
// This callable is intentionally DISABLED and always returns { ok: true } to:
// - avoid leaking account existence (no enumeration)
// - avoid breaking existing deployed clients that may still call it
//
// IMPORTANT:
// - After deploying this, also remove the export from functions/index.js (recommended),
//   so it is not publicly exposed.

async function markAccountActivatedCallable(_request) {
  return {
    ok: true,
    disabled: true,
    reason: 'Activation is handled by Shopify native customer account flow. No platform activation is supported.',
  };
}

// Keep both exports to avoid breaking index.js imports.
module.exports = {
  markAccountActivatedCallable,
  markAccountActivatedHandler: markAccountActivatedCallable,
};
