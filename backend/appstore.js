'use strict';

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const APP_BUNDLE = process.env.APP_BUNDLE || 'com.kvuua.vakansio';
const ROOT_CERT_PATH = path.join(__dirname, 'AppleRootCA-G3.cer');

const PRODUCT_TIERS = {
  'com.kvuua.vakansio.starter': 'starter',
  'com.kvuua.vakansio.pro': 'pro',
  'com.kvuua.vakansio.business': 'business',
};

let appleRoot = null;

function loadAppleRoot() {
  if (appleRoot) return appleRoot;
  if (!fs.existsSync(ROOT_CERT_PATH)) throw new Error('Apple root certificate is missing');
  appleRoot = new crypto.X509Certificate(fs.readFileSync(ROOT_CERT_PATH));
  return appleRoot;
}

function decodePart(value) {
  return JSON.parse(Buffer.from(value, 'base64url').toString('utf8'));
}

function verifyAppStoreJws(jws) {
  const parts = String(jws || '').split('.');
  if (parts.length !== 3) throw new Error('Invalid App Store JWS');

  const header = decodePart(parts[0]);
  if (header.alg !== 'ES256') throw new Error('Unsupported App Store signature algorithm');
  if (!Array.isArray(header.x5c) || header.x5c.length < 2) {
    throw new Error('App Store certificate chain is missing');
  }

  const chain = header.x5c.map((encoded) => new crypto.X509Certificate(Buffer.from(encoded, 'base64')));
  const now = Date.now();
  for (const cert of chain) {
    if (new Date(cert.validFrom).getTime() > now || new Date(cert.validTo).getTime() < now) {
      throw new Error('App Store certificate is expired or not yet valid');
    }
  }

  for (let i = 0; i < chain.length - 1; i += 1) {
    if (!chain[i].verify(chain[i + 1].publicKey)) {
      throw new Error('App Store certificate chain is invalid');
    }
  }

  const root = loadAppleRoot();
  const last = chain[chain.length - 1];
  if (last.fingerprint256 !== root.fingerprint256 && !last.verify(root.publicKey)) {
    throw new Error('App Store certificate is not signed by Apple Root CA G3');
  }

  const leaf = chain[0];
  const signedData = Buffer.from(`${parts[0]}.${parts[1]}`);
  const signature = Buffer.from(parts[2], 'base64url');
  if (!crypto.verify('sha256', signedData, { key: leaf.publicKey, dsaEncoding: 'ieee-p1363' }, signature)) {
    throw new Error('App Store JWS signature is invalid');
  }

  const payload = decodePart(parts[1]);
  if (payload.bundleId !== APP_BUNDLE) throw new Error('App Store bundle id mismatch');
  if (payload.revocationDate) throw new Error('App Store transaction was revoked');

  const tier = PRODUCT_TIERS[payload.productId];
  if (!tier) throw new Error('Unknown subscription product');

  const expiresAt = Number(payload.expiresDate || 0);
  if (!Number.isFinite(expiresAt) || expiresAt <= Date.now()) {
    throw new Error('App Store subscription is expired');
  }

  return {
    tier,
    productId: payload.productId,
    expiresAt: new Date(expiresAt).toISOString(),
    transactionId: payload.transactionId || '',
    originalTransactionId: payload.originalTransactionId || '',
    environment: payload.environment || '',
  };
}

module.exports = { verifyAppStoreJws, PRODUCT_TIERS };
