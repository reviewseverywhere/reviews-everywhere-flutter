'use strict';

// functions/shopify/resendActivation.js
//
// Phase-1 client alignment (Shopify-first identity):
// - No platform activation lifecycle.
// - No Brevo activation emails.
// - No Firebase password reset link used as "activation".
// - This callable is kept only to avoid breaking existing clients,
//   but it is intentionally DISABLED and always returns { ok: true }.
//
// IMPORTANT:
// - After deploying this, also remove the export from functions/index.js
//   (recommended) so the callable is not publicly exposed.

async function resendActivationCallable(_request) {
  // Always respond OK to avoid email enumeration / leaking account existence.
  return {
    ok: true,
    disabled: true,
    reason: 'Activation is handled by Shopify native customer account flow. No resend supported.',
  };
}

module.exports = { resendActivationCallable };
