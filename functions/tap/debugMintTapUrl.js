'use strict';

// functions/tap/debugMintTapUrl.js
const { signTapToken } = require('./token');

function getBaseUrl() {
  // Optional: set TAP_BASE_URL="https://reviews-everywhere.com"
  // Otherwise you can paste the function URL manually when testing.
  const v = process.env.TAP_BASE_URL;
  if (v && v.trim()) return v.trim().replace(/\/+$/, '');
  return null;
}

async function debugMintTapUrlCallable(req) {
  const allow = String(process.env.ALLOW_DEBUG_TAP_MINT || '').toLowerCase() === 'true';
  if (!allow) {
    throw new Error('Debug mint is disabled (set ALLOW_DEBUG_TAP_MINT=true)');
  }

  const data = req.data || {};
  const accountId = String(data.accountId || '').trim();
  const wristbandId = String(data.wristbandId || '').trim();

  if (!accountId || !wristbandId) {
    throw new Error('accountId and wristbandId are required');
  }

  const token = signTapToken({ accountId, wristbandId, ttlDays: 365 });

  const base = getBaseUrl();
  const url = base ? `${base}/tap?t=${token}` : `/tap?t=${token}`;

  return { token, url };
}

module.exports = { debugMintTapUrlCallable };
