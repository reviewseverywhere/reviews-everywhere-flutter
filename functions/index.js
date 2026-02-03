'use strict';

// functions/index.js
//
// Client-required Shopify-first identity (IN-APP ONLY):
// - Email/password auth must NOT use Shopify-hosted pages (/account/login, /account/register, etc).
// - Use Storefront API only: customerRecover -> deep link -> customerReset -> customerAccessTokenCreate.
// - Shopify webhooks remain source of truth for provisioning + planStatus.
// - Social login remains separate.
// - Tap engine unchanged.

const admin = require('firebase-admin');
if (!admin.apps.length) admin.initializeApp();

const { onRequest, onCall } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');

// -----------------------------------------------------------------------------
// Secrets (MUST be set in Firebase Secret Manager)
// -----------------------------------------------------------------------------

// Shopify webhooks
const SHOPIFY_WEBHOOK_SECRET = defineSecret('SHOPIFY_WEBHOOK_SECRET'); // webhook HMAC verification

// Legacy App Proxy signature verification (NOT used by client-required email/password flow)
const SHOPIFY_API_SECRET = defineSecret('SHOPIFY_API_SECRET');

// ✅ Storefront private token (required for customerRecover/reset/login)
const SHOPIFY_STOREFRONT_PRIVATE_TOKEN = defineSecret('SHOPIFY_STOREFRONT_PRIVATE_TOKEN');

// ✅ Admin API token (required for UNIDENTIFIED_CUSTOMER fallback invite)
const SHOPIFY_ADMIN_ACCESS_TOKEN = defineSecret('SHOPIFY_ADMIN_ACCESS_TOKEN');

// Tap token signing secret (for /tap?t=...)
const TAP_TOKEN_SECRET = defineSecret('TAP_TOKEN_SECRET');

// -----------------------------------------------------------------------------
// Region / Invoker
// -----------------------------------------------------------------------------
const REGION = 'us-central1';
const PUBLIC_INVOKER = 'public';

// -----------------------------------------------------------------------------
// Shopify → Firebase Webhooks (public endpoints)
// -----------------------------------------------------------------------------
const { shopifyOrderPaidHandler } = require('./shopify/orderPaid');
const { customersCreateHandler } = require('./shopify/customersCreate');
const { customersUpdateHandler } = require('./shopify/customersUpdate');
const { ordersCreateHandler } = require('./shopify/ordersCreate');
const { ordersUpdatedHandler } = require('./shopify/ordersUpdated');
const { ordersFulfilledHandler } = require('./shopify/ordersFulfilled');
const { ordersCancelledHandler } = require('./shopify/ordersCancelled');
const { refundsCreateHandler } = require('./shopify/refundsCreate');

// -----------------------------------------------------------------------------
// Auth (deterministic linking; NO activation lifecycle)
// -----------------------------------------------------------------------------
const { lookupAccountByEmailCallable } = require('./auth/lookupAccountByEmail');
const { linkAuthToAccountCallable } = require('./auth/linkAuthToAccount');

// ✅ Client-required Storefront email/password auth (IN-APP ONLY)
const { shopifyCustomerRecoverCallable } = require('./auth/shopifyCustomerRecover');
const { shopifyCustomerResetPasswordCallable } = require('./auth/shopifyCustomerResetPassword');
const { shopifyCustomerLoginCallable } = require('./auth/shopifyCustomerLogin');

// -----------------------------------------------------------------------------
// Tap redirect engine
// -----------------------------------------------------------------------------
const { tapRedirectHandler } = require('./tap/tapRedirect');
const { debugMintTapUrlCallable } = require('./tap/debugMintTapUrl');

/* -------------------------------------------------------------------------- */
/* Shopify → Firebase Webhooks                                                */
/* -------------------------------------------------------------------------- */

exports.shopifyOrderPaid = onRequest(
  {
    region: REGION,
    invoker: PUBLIC_INVOKER,
    secrets: [SHOPIFY_WEBHOOK_SECRET],
  },
  shopifyOrderPaidHandler
);

exports.shopifyCustomersCreate = onRequest(
  {
    region: REGION,
    invoker: PUBLIC_INVOKER,
    secrets: [SHOPIFY_WEBHOOK_SECRET],
  },
  customersCreateHandler
);

exports.shopifyCustomersUpdate = onRequest(
  {
    region: REGION,
    invoker: PUBLIC_INVOKER,
    secrets: [SHOPIFY_WEBHOOK_SECRET],
  },
  customersUpdateHandler
);

exports.shopifyOrdersCreate = onRequest(
  {
    region: REGION,
    invoker: PUBLIC_INVOKER,
    secrets: [SHOPIFY_WEBHOOK_SECRET],
  },
  ordersCreateHandler
);

exports.shopifyOrdersUpdated = onRequest(
  {
    region: REGION,
    invoker: PUBLIC_INVOKER,
    secrets: [SHOPIFY_WEBHOOK_SECRET],
  },
  ordersUpdatedHandler
);

exports.shopifyOrdersFulfilled = onRequest(
  {
    region: REGION,
    invoker: PUBLIC_INVOKER,
    secrets: [SHOPIFY_WEBHOOK_SECRET],
  },
  ordersFulfilledHandler
);

exports.shopifyOrdersCancelled = onRequest(
  {
    region: REGION,
    invoker: PUBLIC_INVOKER,
    secrets: [SHOPIFY_WEBHOOK_SECRET],
  },
  ordersCancelledHandler
);

exports.shopifyRefundsCreate = onRequest(
  {
    region: REGION,
    invoker: PUBLIC_INVOKER,
    secrets: [SHOPIFY_WEBHOOK_SECRET],
  },
  refundsCreateHandler
);

/* -------------------------------------------------------------------------- */
/* Auth (NO activation lifecycle)                                             */
/* -------------------------------------------------------------------------- */

exports.lookupAccountByEmail = onCall(
  { region: REGION, invoker: PUBLIC_INVOKER },
  lookupAccountByEmailCallable
);

exports.linkAuthToAccount = onCall(
  { region: REGION, invoker: PUBLIC_INVOKER },
  linkAuthToAccountCallable
);

/* -------------------------------------------------------------------------- */
/* ✅ Client-required Shopify Email/Password (Storefront API, in-app only)    */
/* -------------------------------------------------------------------------- */

// Step 3: customerRecover(email) -> Shopify sends reset email
exports.shopifyCustomerRecover = onCall(
  {
    region: REGION,
    invoker: PUBLIC_INVOKER,
    secrets: [SHOPIFY_STOREFRONT_PRIVATE_TOKEN, SHOPIFY_ADMIN_ACCESS_TOKEN],
  },
  (req) =>
    shopifyCustomerRecoverCallable(
      req,
      SHOPIFY_STOREFRONT_PRIVATE_TOKEN.value(),
      SHOPIFY_ADMIN_ACCESS_TOKEN.value()
    )
);

// Step 5: customerReset(token/newPassword) (reset-by-url supported)
exports.shopifyCustomerResetPassword = onCall(
  {
    region: REGION,
    invoker: PUBLIC_INVOKER,
    secrets: [SHOPIFY_STOREFRONT_PRIVATE_TOKEN],
  },
  (req) => shopifyCustomerResetPasswordCallable(req, SHOPIFY_STOREFRONT_PRIVATE_TOKEN.value())
);

// Step 6: customerAccessTokenCreate(email,password) -> Firebase custom token
exports.shopifyCustomerLogin = onCall(
  {
    region: REGION,
    invoker: PUBLIC_INVOKER,
    secrets: [SHOPIFY_STOREFRONT_PRIVATE_TOKEN],
  },
  (req) => shopifyCustomerLoginCallable(req, SHOPIFY_STOREFRONT_PRIVATE_TOKEN.value())
);

/* -------------------------------------------------------------------------- */
/* Tap Redirect Engine (core runtime)                                         */
/* -------------------------------------------------------------------------- */

exports.tap = onRequest(
  {
    region: REGION,
    invoker: PUBLIC_INVOKER,
    secrets: [TAP_TOKEN_SECRET],
  },
  tapRedirectHandler
);

exports.debugMintTapUrl = onCall(
  {
    region: REGION,
    invoker: PUBLIC_INVOKER,
    secrets: [TAP_TOKEN_SECRET],
  },
  debugMintTapUrlCallable
);
