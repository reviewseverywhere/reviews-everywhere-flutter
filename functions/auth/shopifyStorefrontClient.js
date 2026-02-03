'use strict';

// functions/auth/shopifyStorefrontClient.js

const logger = require('firebase-functions/logger');
const crypto = require('crypto');

function requireNonEmpty(name, value) {
  if (!value || typeof value !== 'string' || !value.trim()) {
    throw new Error(`Missing required config: ${name}`);
  }
  return value.trim();
}

function tokenFingerprint(token) {
  const t = String(token || '').trim();
  if (!t) return null;
  return `len=${t.length},last6=${t.slice(-6)}`;
}

function summarizeGraphQLErrors(errors) {
  if (!Array.isArray(errors)) return [];
  return errors.slice(0, 5).map((e) => {
    const ext = e?.extensions || {};
    return {
      message: e?.message || null,
      path: e?.path || null,
      // Shopify often includes codes + required access hints here
      extensions: {
        code: ext.code || null,
        documentation: ext.documentation || null,
        requiredAccess: ext.requiredAccess || null,
        requiredAccessScopes: ext.requiredAccessScopes || null,
        typeName: ext.typeName || null,
        fieldName: ext.fieldName || null,
      },
    };
  });
}

function extractUserErrors(data) {
  const hits = [];
  function walk(obj, path) {
    if (!obj || typeof obj !== 'object') return;

    for (const key of ['userErrors', 'customerUserErrors']) {
      const v = obj[key];
      if (Array.isArray(v) && v.length) {
        hits.push({
          at: path ? `${path}.${key}` : key,
          errors: v.slice(0, 5).map((er) => ({
            code: er?.code || null,
            field: er?.field || null,
            message: er?.message || null,
          })),
        });
      }
    }

    for (const [k, v] of Object.entries(obj)) {
      if (v && typeof v === 'object') walk(v, path ? `${path}.${k}` : k);
    }
  }

  walk(data, '');
  return hits;
}

async function storefrontRequest({
  shopDomain,
  apiVersion,
  accessToken,
  query,
  variables,
  buyerIp,
  label,
}) {
  shopDomain = requireNonEmpty('shopDomain', shopDomain);
  apiVersion = requireNonEmpty('apiVersion', apiVersion);
  accessToken = requireNonEmpty('accessToken', accessToken);
  requireNonEmpty('query', query);

  const endpoint = `https://${shopDomain}/api/${apiVersion}/graphql.json`;
  const requestId = crypto.randomBytes(6).toString('hex');
  const startedAt = Date.now();
  const qHash = crypto.createHash('sha1').update(String(query)).digest('hex').slice(0, 10);

  logger.info('[Storefront] request:start', {
    requestId,
    label: label || null,
    endpoint,
    shopDomain,
    apiVersion,
    tokenFp: tokenFingerprint(accessToken),
    buyerIp: buyerIp ? String(buyerIp).trim() : null,
    variablesKeys: variables && typeof variables === 'object' ? Object.keys(variables).slice(0, 20) : [],
    queryHash: qHash,
  });

  const headers = {
    'Content-Type': 'application/json',
    'X-Shopify-Storefront-Access-Token': accessToken,
  };

  // IMPORTANT: Shopify says this header is case-sensitive
  if (buyerIp && typeof buyerIp === 'string' && buyerIp.trim()) {
    headers['Shopify-Storefront-Buyer-IP'] = buyerIp.trim();
  }

  const body = JSON.stringify({ query, variables: variables || {} });

  let resp;
  try {
    resp = await fetch(endpoint, { method: 'POST', headers, body });
  } catch (e) {
    logger.error('[Storefront] request:network_error', {
      requestId,
      label: label || null,
      endpoint,
      message: String(e?.message || e),
    });
    throw new Error('Storefront API network error');
  }

  const latencyMs = Date.now() - startedAt;
  const text = await resp.text();

  logger.info('[Storefront] request:http_response', {
    requestId,
    label: label || null,
    endpoint,
    status: resp.status,
    ok: resp.ok,
    latencyMs,
    bodyPreview: text ? text.slice(0, 300) : '',
  });

  let json;
  try {
    json = JSON.parse(text);
  } catch (e) {
    logger.error('[Storefront] response:non_json', {
      requestId,
      label: label || null,
      endpoint,
      status: resp.status,
      latencyMs,
      textPreview: text ? text.slice(0, 2000) : '',
    });
    throw new Error(`Storefront API returned non-JSON (${resp.status})`);
  }

  if (!resp.ok) {
    logger.error('[Storefront] response:http_error', {
      requestId,
      label: label || null,
      endpoint,
      status: resp.status,
      latencyMs,
      errors: summarizeGraphQLErrors(json?.errors),
      hasData: !!json?.data,
    });
    throw new Error(`Storefront API HTTP error (${resp.status})`);
  }

  if (Array.isArray(json.errors) && json.errors.length) {
    logger.error('[Storefront] response:gql_errors', {
      requestId,
      label: label || null,
      endpoint,
      latencyMs,
      errors: summarizeGraphQLErrors(json.errors),
    });
    throw new Error('Storefront API GraphQL error');
  }

  const data = json.data;
  const userErrorHits = extractUserErrors(data);

  if (userErrorHits.length) {
    logger.warn('[Storefront] response:user_errors', {
      requestId,
      label: label || null,
      endpoint,
      latencyMs,
      hits: userErrorHits,
    });
  } else {
    logger.info('[Storefront] response:ok', {
      requestId,
      label: label || null,
      endpoint,
      latencyMs,
    });
  }

  return data;
}

async function shopHealthCheck({ shopDomain, apiVersion, accessToken }) {
  // Keep it extremely simple
  const query = `query { shop { name myshopifyDomain } }`;

  const data = await storefrontRequest({
    shopDomain,
    apiVersion,
    accessToken,
    query,
    variables: {},
    label: 'healthCheck',
  });

  logger.info('[Storefront] healthCheck:result', {
    shopName: data?.shop?.name || null,
    myshopifyDomain: data?.shop?.myshopifyDomain || null,
  });

  return data?.shop || null;
}

module.exports = { storefrontRequest, shopHealthCheck };
