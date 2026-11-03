#!/usr/bin/env node
/**
 * Uploads the four iPhone 6.7"/6.9" screenshots to the Ukrainian App Store
 * version. Requires ASC_KEY_ID, ASC_ISSUER_ID and ASC_PRIVATE_KEY.
 */
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const API = 'https://api.appstoreconnect.apple.com/v1';
const BUNDLE = 'com.kvuua.vakansio';
const DISPLAY_TYPE = process.env.SCREENSHOT_DISPLAY_TYPE || 'APP_IPHONE_67';
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SCREENSHOT_DIR = path.resolve(__dirname, '..', 'appstore-screenshots');
const FILES = [
  'iphone69-01-login.png',
  'iphone69-02-feed.png',
  'iphone69-03-detail.png',
  'iphone69-04-paywall.png',
].map((name) => path.join(SCREENSHOT_DIR, name));

const keyId = process.env.ASC_KEY_ID || '';
const issuerId = process.env.ASC_ISSUER_ID || process.env.ASK_ISSUER_ID || '';
const privateKey = (process.env.ASC_PRIVATE_KEY || '')
  .replace(/\\n/g, '\n')
  .trim() || (process.env.ASC_KEY_PATH ? fs.readFileSync(process.env.ASC_KEY_PATH, 'utf8') : '');

if (!keyId || !issuerId || !privateKey) {
  console.error('Missing ASC_KEY_ID / ASC_ISSUER_ID / ASC_PRIVATE_KEY');
  process.exit(2);
}

const b64 = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
function mintToken() {
  const now = Math.floor(Date.now() / 1000);
  const input = b64({ alg: 'ES256', kid: keyId, typ: 'JWT' }) + '.' +
    b64({ iss: issuerId, iat: now, exp: now + 900, aud: 'appstoreconnect-v1' });
  const signature = crypto.sign('sha256', Buffer.from(input), {
    key: privateKey,
    dsaEncoding: 'ieee-p1363',
  }).toString('base64url');
  return `${input}.${signature}`;
}
let token = mintToken();
let tokenCreated = Date.now();
function authToken() {
  if (Date.now() - tokenCreated > 10 * 60 * 1000) {
    token = mintToken();
    tokenCreated = Date.now();
  }
  return token;
}

async function request(method, url, body) {
  const absolute = url.startsWith('http') ? url : `${API}${url}`;
  const headers = { Authorization: `Bearer ${authToken()}`, Accept: 'application/json' };
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 60000);
  try {
    const response = await fetch(absolute, {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: controller.signal,
    });
    const text = await response.text();
    let data = null;
    try { data = text ? JSON.parse(text) : {}; } catch { data = { raw: text }; }
    if (!response.ok) {
      const details = (data?.errors || [])
        .map((e) => `${e.status || ''} ${e.code || ''}: ${e.title || ''} ${e.detail || ''}`)
        .join('\n');
      const error = new Error(`HTTP ${response.status} ${method} ${absolute}\n${details || text.slice(0, 1200)}`);
      error.status = response.status;
      error.data = data;
      throw error;
    }
    return data;
  } finally {
    clearTimeout(timer);
  }
}

async function listAll(url) {
  const items = [];
  let next = url;
  while (next) {
    const data = await request('GET', next);
    items.push(...(data.data || []));
    next = data.links?.next || null;
  }
  return items;
}

async function findApp() {
  const data = await request('GET', `/apps?filter%5BbundleId%5D=${encodeURIComponent(BUNDLE)}&limit=200`);
  const app = (data.data || []).find((item) => item.attributes?.bundleId === BUNDLE);
  if (!app) throw new Error(`App ${BUNDLE} not found`);
  return app;
}

async function findLocalization(appId) {
  const versions = await listAll(`/apps/${appId}/appStoreVersions?filter%5Bplatform%5D=IOS&limit=200`);
  const version = versions.find((v) => ['PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED', 'REJECTED'].includes(v.attributes?.appStoreState)) || versions[0];
  if (!version) throw new Error('No iOS App Store version');
  const localizations = await listAll(`/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=200`);
  const localization = localizations.find((l) => ['uk', 'uk-UA'].includes(l.attributes?.locale));
  if (!localization) throw new Error('No uk localization');
  return { version, localization };
}

async function ensureSet(localizationId) {
  const sets = await listAll(`/appStoreVersionLocalizations/${localizationId}/appScreenshotSets?limit=200`);
  const existing = sets.find((set) => set.attributes?.screenshotDisplayType === DISPLAY_TYPE);
  if (existing) return existing;
  const created = await request('POST', '/appScreenshotSets', {
    data: {
      type: 'appScreenshotSets',
      attributes: { screenshotDisplayType: DISPLAY_TYPE },
      relationships: {
        appStoreVersionLocalization: {
          data: { type: 'appStoreVersionLocalizations', id: localizationId },
        },
      },
    },
  });
  return created.data;
}

async function uploadOne(filePath, set) {
  const bytes = fs.readFileSync(filePath);
  const fileName = path.basename(filePath);
  const checksum = crypto.createHash('md5').update(bytes).digest('hex');
  const created = await request('POST', '/appScreenshots', {
    data: {
      type: 'appScreenshots',
      attributes: { fileName, fileSize: bytes.length },
      relationships: {
        appScreenshotSet: { data: { type: 'appScreenshotSets', id: set.id } },
      },
    },
  });
  const screenshot = created.data;
  const operations = screenshot.attributes?.uploadOperations || [];
  if (!operations.length) throw new Error(`${fileName}: no upload operations`);
  for (const operation of operations) {
    const chunk = bytes.subarray(Number(operation.offset || 0), Number(operation.offset || 0) + Number(operation.length || 0));
    const headers = {};
    for (const header of operation.requestHeaders || []) {
      if (header?.name && header?.value) headers[header.name] = header.value;
    }
    if (!Object.keys(headers).some((key) => key.toLowerCase() === 'content-type')) {
      headers['Content-Type'] = 'application/octet-stream';
    }
    const response = await fetch(operation.url, {
      method: operation.method || 'PUT',
      headers,
      body: chunk,
    });
    if (!response.ok) {
      throw new Error(`${fileName}: upload chunk failed HTTP ${response.status}`);
    }
  }
  await request('PATCH', `/appScreenshots/${screenshot.id}`, {
    data: {
      type: 'appScreenshots',
      id: screenshot.id,
      attributes: { uploaded: true, sourceFileChecksum: checksum },
    },
  });

  for (let attempt = 0; attempt < 24; attempt += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5000));
    const current = await request('GET', `/appScreenshots/${screenshot.id}`);
    const state = current.data?.attributes?.assetDeliveryState?.state;
    console.log(`SCREENSHOT ${fileName} state=${state || 'unknown'}`);
    if (state === 'COMPLETE' || state === 'UPLOAD_COMPLETE') {
      return { fileName, id: screenshot.id, state };
    }
    if (state === 'FAILED' || state === 'INVALID') {
      throw new Error(`${fileName}: delivery state ${state}`);
    }
  }
  throw new Error(`${fileName}: upload did not reach COMPLETE`);
}

async function main() {
  const report = { displayType: DISPLAY_TYPE, set: null, uploaded: [], errors: [] };
  try {
    for (const file of FILES) {
      if (!fs.existsSync(file)) throw new Error(`Missing screenshot ${file}`);
    }
    const app = await findApp();
    const { localization } = await findLocalization(app.id);
    const set = await ensureSet(localization.id);
    report.set = { id: set.id, displayType: set.attributes?.screenshotDisplayType };
    console.log('SCREENSHOT_SET ' + JSON.stringify(report.set));
    for (const file of FILES) {
      const result = await uploadOne(file, set);
      report.uploaded.push(result);
      console.log('SCREENSHOT_UPLOADED ' + JSON.stringify(result));
    }
  } catch (error) {
    report.errors.push(error.message);
    console.error('SCREENSHOT_UPLOAD_FAILED ' + error.message);
    process.exitCode = 1;
  }
  console.log('SCREENSHOT_REPORT ' + JSON.stringify(report));
}

main();
