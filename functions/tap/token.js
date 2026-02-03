'use strict';

// functions/tap/token.js
const crypto = require('crypto');

function b64urlEncode(buf) {
  return Buffer.from(buf)
    .toString('base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
}

function b64urlDecode(str) {
  const s = String(str).replace(/-/g, '+').replace(/_/g, '/');
  const pad = s.length % 4 === 0 ? '' : '='.repeat(4 - (s.length % 4));
  return Buffer.from(s + pad, 'base64');
}

function getSecret() {
  const secret = process.env.TAP_TOKEN_SECRET;
  if (!secret) throw new Error('TAP_TOKEN_SECRET is not set');
  return secret;
}

/**
 * Token format:
 *   v1.<payloadB64url>.<sigB64url>
 *
 * payload JSON:
 *   { a: accountId, w: wristbandId, exp: unixMs }
 */
function signTapToken({ accountId, wristbandId, ttlDays = 365 }) {
  if (!accountId || !wristbandId) {
    throw new Error('accountId and wristbandId are required');
  }

  const exp = Date.now() + ttlDays * 24 * 60 * 60 * 1000;
  const payload = { a: String(accountId), w: String(wristbandId), exp };
  const payloadB64 = b64urlEncode(JSON.stringify(payload));

  const secret = getSecret();
  const sig = crypto
    .createHmac('sha256', secret)
    .update(`v1.${payloadB64}`)
    .digest();

  const sigB64 = b64urlEncode(sig);
  return `v1.${payloadB64}.${sigB64}`;
}

function verifyTapToken(token) {
  const t = String(token || '').trim();
  const parts = t.split('.');
  if (parts.length !== 3) throw new Error('invalid_token_format');
  const [ver, payloadB64, sigB64] = parts;
  if (ver !== 'v1') throw new Error('unsupported_token_version');

  const secret = getSecret();

  const expected = crypto
    .createHmac('sha256', secret)
    .update(`v1.${payloadB64}`)
    .digest();

  const got = b64urlDecode(sigB64);

  // Constant-time compare
  if (got.length !== expected.length || !crypto.timingSafeEqual(got, expected)) {
    throw new Error('invalid_token_signature');
  }

  const payloadJson = b64urlDecode(payloadB64).toString('utf8');
  const payload = JSON.parse(payloadJson);

  if (!payload || !payload.a || !payload.w || !payload.exp) {
    throw new Error('invalid_token_payload');
  }

  if (Date.now() > Number(payload.exp)) {
    throw new Error('token_expired');
  }

  return { accountId: String(payload.a), wristbandId: String(payload.w) };
}

module.exports = { signTapToken, verifyTapToken };
