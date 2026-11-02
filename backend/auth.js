'use strict';

const crypto = require('node:crypto');

const JWT_SECRET = process.env.JWT_SECRET || '';
const APPLE_CLIENT_ID = process.env.APPLE_CLIENT_ID || 'com.kvuua.vakansio';
const APPLE_ISSUER = 'https://appleid.apple.com';
const APPLE_KEYS_URL = 'https://appleid.apple.com/auth/keys';
const JWT_TTL_SECONDS = 30 * 24 * 60 * 60;

let appleKeys = { keys: null, fetchedAt: 0 };

function base64url(value) {
  return Buffer.from(value).toString('base64url');
}

function decodePart(value) {
  return JSON.parse(Buffer.from(value, 'base64url').toString('utf8'));
}

function signJwt(user) {
  if (!JWT_SECRET) throw new Error('JWT_SECRET is not set');

  const now = Math.floor(Date.now() / 1000);
  const header = base64url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const payload = base64url(JSON.stringify({
    sub: user.id,
    email: user.email || '',
    iat: now,
    exp: now + JWT_TTL_SECONDS,
  }));
  const input = `${header}.${payload}`;
  const signature = crypto.createHmac('sha256', JWT_SECRET).update(input).digest('base64url');
  return `${input}.${signature}`;
}

function verifyJwt(token) {
  if (!JWT_SECRET) throw new Error('JWT_SECRET is not set');
  const parts = String(token || '').split('.');
  if (parts.length !== 3) throw new Error('Invalid token');

  const input = `${parts[0]}.${parts[1]}`;
  const expected = crypto.createHmac('sha256', JWT_SECRET).update(input).digest();
  const actual = Buffer.from(parts[2], 'base64url');
  if (expected.length !== actual.length || !crypto.timingSafeEqual(expected, actual)) {
    throw new Error('Invalid token signature');
  }

  const payload = decodePart(parts[1]);
  if (!payload.sub) throw new Error('Invalid token subject');
  if (Number(payload.exp || 0) <= Math.floor(Date.now() / 1000)) {
    throw new Error('Token expired');
  }
  return payload;
}

async function getAppleKeys() {
  if (appleKeys.keys && Date.now() - appleKeys.fetchedAt < 60 * 60 * 1000) {
    return appleKeys.keys;
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 10000);
  try {
    const response = await fetch(APPLE_KEYS_URL, {
      headers: { Accept: 'application/json' },
      signal: controller.signal,
    });
    if (!response.ok) throw new Error(`Apple keys HTTP ${response.status}`);
    const data = await response.json();
    if (!Array.isArray(data.keys) || data.keys.length === 0) {
      throw new Error('Apple returned no keys');
    }
    appleKeys = { keys: data.keys, fetchedAt: Date.now() };
    return data.keys;
  } finally {
    clearTimeout(timer);
  }
}

async function verifyAppleIdentityToken(identityToken) {
  const parts = String(identityToken || '').split('.');
  if (parts.length !== 3) throw new Error('Invalid Apple identity token');

  const header = decodePart(parts[0]);
  if (header.alg !== 'RS256' || !header.kid) {
    throw new Error('Unsupported Apple token algorithm');
  }

  const keys = await getAppleKeys();
  const jwk = keys.find((key) => key.kid === header.kid);
  if (!jwk) throw new Error('Apple signing key not found');

  const publicKey = crypto.createPublicKey({ key: jwk, format: 'jwk' });
  const signedData = Buffer.from(`${parts[0]}.${parts[1]}`);
  const signature = Buffer.from(parts[2], 'base64url');

  if (!crypto.verify('RSA-SHA256', signedData, publicKey, signature)) {
    throw new Error('Apple token signature is invalid');
  }

  const payload = decodePart(parts[1]);
  if (payload.iss !== APPLE_ISSUER) throw new Error('Invalid Apple issuer');
  const audiences = Array.isArray(payload.aud) ? payload.aud : [payload.aud];
  if (!audiences.includes(APPLE_CLIENT_ID)) throw new Error('Invalid Apple audience');
  if (Number(payload.exp || 0) * 1000 <= Date.now() - 60 * 1000) {
    throw new Error('Apple token expired');
  }
  if (!payload.sub) throw new Error('Apple token has no subject');

  return payload;
}

module.exports = {
  signJwt,
  verifyJwt,
  verifyAppleIdentityToken,
  APPLE_CLIENT_ID,
};
