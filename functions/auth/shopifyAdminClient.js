'use strict';

const logger = require('firebase-functions/logger');

async function adminGraphqlRequest({
  shopDomain,
  apiVersion,
  adminAccessToken,
  query,
  variables,
  label,
  traceId,
  allowPartialData = false,
}) {
  const url = `https://${shopDomain}/admin/api/${apiVersion}/graphql.json`;

  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Shopify-Access-Token': adminAccessToken,
    },
    body: JSON.stringify({ query, variables: variables || {} }),
  });

  const raw = await res.text();

  let json;
  try {
    json = JSON.parse(raw);
  } catch (_) {
    json = null;
  }

  if (!res.ok) {
    logger.error('[Admin] http_error', {
      traceId,
      label,
      status: res.status,
      bodyPreview: raw.slice(0, 800),
      url,
    });
    throw new Error(`Admin API HTTP ${res.status}`);
  }

  // Shopify sometimes returns { errors: [...], data: {...} }
  if (json?.errors?.length) {
    logger.error('[Admin] graphql_errors', {
      traceId,
      label,
      errors: json.errors,
      bodyPreview: raw.slice(0, 800),
      url,
    });

    if (allowPartialData && json?.data) {
      return json.data;
    }

    throw new Error('[Admin] graphql_errors');
  }

  return json?.data;
}

module.exports = { adminGraphqlRequest };
