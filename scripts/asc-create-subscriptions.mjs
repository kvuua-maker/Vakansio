#!/usr/bin/env node
/**
 * Creates the Vakansio auto-renewable subscriptions in App Store Connect.
 * Requires ASC_KEY_ID, ASC_ISSUER_ID and ASC_PRIVATE_KEY (or ASC_KEY_PATH).
 */
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const API = 'https://api.appstoreconnect.apple.com/v1';
const BUNDLE = 'com.kvuua.vakansio';
const GROUP_NAME = 'Vakansio Plans';

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
  const timer = setTimeout(() => controller.abort(), 45000);
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
      const details = (data?.errors || []).map((e) => `${e.status || ''} ${e.code || ''}: ${e.title || ''} ${e.detail || ''}`).join('\n');
      const error = new Error(`HTTP ${response.status} ${method} ${absolute}\n${details || text.slice(0, 1000)}`);
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
  if (!app) throw new Error(`App ${BUNDLE} not found in App Store Connect`);
  return app;
}

async function ensureAppAvailability(appId) {
  let existing = null;
  try {
    existing = await request('GET', `/apps/${appId}/appAvailabilityV2`);
  } catch (error) {
    if (error.status !== 404) throw error;
  }
  if (existing?.data?.id) {
    return { skipped: true, id: existing.data.id };
  }

  const territories = await listAll('/territories?limit=200');
  if (!territories.length) throw new Error('Apple territory catalog is empty');
  const included = territories.map((territory) => ({
    type: 'territoryAvailabilities',
    attributes: { available: true },
    relationships: {
      territory: { data: { type: 'territories', id: territory.id } },
    },
  }));
  const created = await request('POST', 'https://api.appstoreconnect.apple.com/v2/appAvailabilities', {
    data: {
      type: 'appAvailabilities',
      attributes: { availableInNewTerritories: true },
      relationships: { app: { data: { type: 'apps', id: appId } } },
    },
    included,
  });
  return { skipped: false, id: created.data?.id, territories: territories.length };
}

async function findOrCreateGroup(appId) {
  const groups = await listAll(`/apps/${appId}/subscriptionGroups?limit=200`);
  let group = groups.find((item) => item.attributes?.referenceName === GROUP_NAME);
  if (group) return { group, created: false };
  const data = await request('POST', '/subscriptionGroups', {
    data: {
      type: 'subscriptionGroups',
      attributes: { referenceName: GROUP_NAME },
      relationships: { app: { data: { type: 'apps', id: appId } } },
    },
  });
  return { group: data.data, created: true };
}

async function ensureGroupLocalization(group) {
  let versions = await listAll(`/subscriptionGroups/${group.id}/versions?limit=200`);
  let version = versions[0];
  if (!version) {
    const created = await request('POST', '/subscriptionGroupVersions', {
      data: {
        type: 'subscriptionGroupVersions',
        relationships: {
          subscriptionGroup: { data: { type: 'subscriptionGroups', id: group.id } },
        },
      },
    });
    version = created.data;
  }
  if (!version) return { skipped: true };

  try {
    const versionDetails = await request('GET', `/subscriptionGroupVersions/${version.id}`);
    console.log(`GROUP_VERSION ${JSON.stringify(versionDetails.data?.attributes || {})}`);
  } catch (error) {
    console.warn(`GROUP_VERSION_STATE_FAILED ${error.message}`);
  }
  const localizations = await listAll(`/subscriptionGroupVersions/${version.id}/localizations?limit=200`);
  if (localizations.some((row) => ['uk', 'uk-UA'].includes(row.attributes?.locale))) {
    return { skipped: true, versionId: version.id };
  }

  let lastError = null;
  for (const locale of ['uk', 'uk-UA']) {
    try {
      await request('POST', 'https://api.appstoreconnect.apple.com/v2/subscriptionGroupLocalizations', {
        data: {
          type: 'subscriptionGroupLocalizations',
          attributes: {
            name: 'Плани Vakansio',
            locale,
          },
          relationships: {
            version: { data: { type: 'subscriptionGroupVersions', id: version.id } },
          },
        },
      });
      return { skipped: false, versionId: version.id, locale };
    } catch (error) {
      lastError = error;
      if (!/UNSUPPORTED_LOCALE_CODE/i.test(error.message)) throw error;
    }
  }
  throw lastError || new Error('No supported subscription group locale');
}

async function findOrCreateSubscription(groupId, spec) {
  const subs = await listAll(`/subscriptionGroups/${groupId}/subscriptions?limit=200`);
  let sub = subs.find((item) => item.attributes?.productId === spec.productId);
  if (sub) return { sub, created: false };
  const data = await request('POST', '/subscriptions', {
    data: {
      type: 'subscriptions',
      attributes: {
        name: spec.internalName,
        productId: spec.productId,
        subscriptionPeriod: 'ONE_MONTH',
        familySharable: false,
        groupLevel: spec.groupLevel,
        reviewNote: 'Vakansio employer subscription. Used to publish job vacancies.',
      },
      relationships: { group: { data: { type: 'subscriptionGroups', id: groupId } } },
    },
  });
  return { sub: data.data, created: true };
}

async function ensureLocalization(sub, spec) {
  const rows = await listAll(`/subscriptions/${sub.id}/subscriptionLocalizations?limit=200`);
  if (rows.some((row) => ['uk', 'uk-UA'].includes(row.attributes?.locale))) {
    return { created: false, locale: rows.find((row) => ['uk', 'uk-UA'].includes(row.attributes?.locale))?.attributes?.locale };
  }

  let lastError = null;
  // App Store Connect accepts the Ukrainian language as "uk" on some API versions,
  // while older documentation shows "uk-UA". Try both, preferring the supported one.
  for (const locale of ['uk', 'uk-UA']) {
    try {
      await request('POST', '/subscriptionLocalizations', {
        data: {
          type: 'subscriptionLocalizations',
          attributes: {
            name: spec.localizedName,
            description: spec.localizedDescription,
            locale,
          },
          relationships: { subscription: { data: { type: 'subscriptions', id: sub.id } } },
        },
      });
      return { created: true, locale };
    } catch (error) {
      lastError = error;
      if (!/UNSUPPORTED_LOCALE_CODE/i.test(error.message)) throw error;
    }
  }
  throw lastError || new Error('No supported Ukrainian locale');
}

async function pricePoints(subId) {
  return listAll(`/subscriptions/${subId}/pricePoints?filter%5Bterritory%5D=UKR&limit=200`);
}

async function ensurePlanAvailability(sub) {
  const existing = await listAll(`/subscriptions/${sub.id}/planAvailabilities?limit=200&include=availableTerritories&limit%5BavailableTerritories%5D=50`);
  const results = [];
  for (const planType of ['UPFRONT', 'MONTHLY']) {
    const match = existing.find((row) => row.attributes?.planType === planType);
    try {
      if (match) {
        const territories = (match.relationships?.availableTerritories?.data || []).map((row) => row.id);
        if (!territories.includes('UKR')) {
          await request('PATCH', `/subscriptionPlanAvailabilities/${match.id}`, {
            data: {
              type: 'subscriptionPlanAvailabilities',
              id: match.id,
              attributes: { availableInNewTerritories: true },
              relationships: {
                availableTerritories: { data: [{ type: 'territories', id: 'UKR' }] },
              },
            },
          });
        }
        results.push({ planType, id: match.id, updated: true });
      } else {
        const created = await request('POST', '/subscriptionPlanAvailabilities', {
          data: {
            type: 'subscriptionPlanAvailabilities',
            attributes: { planType, availableInNewTerritories: true },
            relationships: {
              subscription: { data: { type: 'subscriptions', id: sub.id } },
              availableTerritories: { data: [{ type: 'territories', id: 'UKR' }] },
            },
          },
        });
        results.push({ planType, id: created.data?.id, created: true });
      }
    } catch (error) {
      results.push({ planType, error: error.message });
      console.warn(`WARN: plan availability ${planType} for ${sub.id}: ${error.message}`);
    }
  }
  return results;
}

async function ensurePrice(sub, spec) {
  const availability = await ensurePlanAvailability(sub);
  console.log(`AVAILABILITY ${spec.productId}: ${JSON.stringify(availability)}`);
  const existing = await listAll(`/subscriptions/${sub.id}/prices?limit=200`);
  if (existing.length > 0) {
    return { skipped: true, existingCount: existing.length };
  }
  const points = await pricePoints(sub.id);
  if (!points.length) throw new Error('No UKR subscription price points returned');
  const exact = points.find((point) => Number(point.attributes?.customerPrice) === spec.price);
  const nearest = exact || points
    .map((point) => ({ point, diff: Math.abs(Number(point.attributes?.customerPrice || 0) - spec.price) }))
    .sort((a, b) => a.diff - b.diff)[0]?.point;
  if (!nearest) throw new Error('No usable subscription price point');
  if (!exact) {
    const nearby = points
      .map((point) => Number(point.attributes?.customerPrice || 0))
      .filter((value) => value > 0)
      .sort((a, b) => Math.abs(a - spec.price) - Math.abs(b - spec.price))
      .slice(0, 8);
    console.warn(`WARN: exact ${spec.price} UAH point not found; using ${nearest.attributes?.customerPrice} UAH; nearby=${nearby.join(',')}`);
  }
  // The first price is the starting price: Apple rejects a future startDate
  // until a starting price exists. Future price changes may include startDate.
  await request('POST', '/subscriptionPrices', {
    data: {
      type: 'subscriptionPrices',
      attributes: {},
      relationships: {
        subscription: { data: { type: 'subscriptions', id: sub.id } },
        subscriptionPricePoint: { data: { type: 'subscriptionPricePoints', id: nearest.id } },
      },
    },
  });
  return { skipped: false, price: nearest.attributes?.customerPrice, exact: Boolean(exact) };
}

async function uploadScreenshot(sub, label) {
  let existing = null;
  try {
    existing = await request('GET', `/subscriptions/${sub.id}/appStoreReviewScreenshot`);
  } catch (error) {
    if (error.status !== 404) throw error;
  }
  if (existing?.data?.id) {
    console.log(`SCREENSHOT ${label}: already present ${existing.data.id}`);
    return { skipped: true, id: existing.data.id };
  }

  const imagePath = path.join(__dirname, 'assets', 'subscription-review.png');
  const bytes = fs.readFileSync(imagePath);
  const checksum = crypto.createHash('md5').update(bytes).digest('hex');
  const created = await request('POST', '/subscriptionAppStoreReviewScreenshots', {
    data: {
      type: 'subscriptionAppStoreReviewScreenshots',
      attributes: {
        fileName: `${label.toLowerCase()}-paywall.png`,
        fileSize: bytes.length,
      },
      relationships: { subscription: { data: { type: 'subscriptions', id: sub.id } } },
    },
  });
  const screenshot = created.data;
  const operations = screenshot.attributes?.uploadOperations || [];
  for (const op of operations) {
    const headers = {};
    for (const header of op.requestHeaders || []) headers[header.name] = header.value;
    const slice = bytes.subarray(op.offset || 0, (op.offset || 0) + (op.length || bytes.length));
    const response = await fetch(op.url, { method: op.method || 'PUT', headers, body: slice });
    if (!response.ok) {
      const text = await response.text();
      throw new Error(`Screenshot upload failed HTTP ${response.status}: ${text.slice(0, 300)}`);
    }
  }
  console.log(`SCREENSHOT ${label}: uploaded ${screenshot.id}`);
  await request('PATCH', `/subscriptionAppStoreReviewScreenshots/${screenshot.id}`, {
    data: {
      type: 'subscriptionAppStoreReviewScreenshots',
      id: screenshot.id,
      attributes: { uploaded: true, sourceFileChecksum: checksum },
    },
  });
  return { skipped: false, id: screenshot.id };
}

async function verify(sub, spec) {
  const fresh = await request('GET', `/subscriptions/${sub.id}`);
  console.log(`SUBSCRIPTION_ATTRIBUTES ${spec.productId} ${JSON.stringify(fresh.data?.attributes || {})}`);
  const localizations = await listAll(`/subscriptions/${sub.id}/subscriptionLocalizations?limit=200`);
  const prices = await listAll(`/subscriptions/${sub.id}/prices?limit=200`);
  return {
    productId: spec.productId,
    id: sub.id,
    state: fresh.data?.attributes?.state || 'UNKNOWN',
    localizations: localizations.map((row) => row.attributes?.locale).filter(Boolean),
    priceCount: prices.length,
  };
}

const SPECS = [
  {
    productId: 'com.kvuua.vakansio.pro',
    internalName: 'Vakansio Pro',
    localizedName: 'Тариф Профі',
    localizedDescription: '10 активних вакансій, розширена аналітика',
    price: 499,
    groupLevel: 1,
  },
  {
    productId: 'com.kvuua.vakansio.business',
    internalName: 'Vakansio Business',
    localizedName: 'Тариф Бізнес',
    localizedDescription: 'Безлімітна кількість вакансій, пріоритетна підтримка',
    price: 1299,
    groupLevel: 2,
  },
];

const report = { appId: null, groupId: null, groupCreated: false, subscriptions: [], errors: [] };
try {
  const app = await findApp();
  report.appId = app.id;
  console.log(`App: ${app.id} ${BUNDLE}`);
  try {
    report.appAvailability = await ensureAppAvailability(app.id);
    console.log('APP_AVAILABILITY ' + JSON.stringify(report.appAvailability));
  } catch (error) {
    report.appAvailabilityError = error.message;
    console.error('APP_AVAILABILITY_FAILED ' + error.message);
  }

  const { group, created } = await findOrCreateGroup(app.id);
  report.groupId = group.id;
  report.groupCreated = created;
  console.log(`Group: ${group.id} ${GROUP_NAME} (${created ? 'created' : 'existing'})`);
  try {
    report.groupLocalization = await ensureGroupLocalization(group);
    console.log(`GROUP_LOCALIZATION ${JSON.stringify(report.groupLocalization)}`);
  } catch (error) {
    report.groupLocalizationError = error.message;
    console.error(`GROUP_LOCALIZATION_FAILED ${error.message}`);
  }

  for (const spec of SPECS) {
    const entry = { productId: spec.productId };
    report.subscriptions.push(entry);
    try {
      const { sub, created: subCreated } = await findOrCreateSubscription(group.id, spec);
      entry.id = sub.id;
      entry.created = subCreated;
      console.log(`Subscription ${spec.productId}: ${sub.id} (${subCreated ? 'created' : 'existing'})`);

      try {
        entry.localization = await ensureLocalization(sub, spec);
        console.log(`LOCALIZATION ${spec.productId}: ${JSON.stringify(entry.localization)}`);
      } catch (error) {
        entry.localizationError = error.message;
        report.errors.push(`${spec.productId} localization: ${error.message}`);
        console.error(`LOCALIZATION_FAILED ${spec.productId}\n${error.message}`);
      }

      try {
        entry.price = await ensurePrice(sub, spec);
      } catch (error) {
        entry.priceError = error.message;
        report.errors.push(`${spec.productId} price: ${error.message}`);
        console.error(`PRICE_FAILED ${spec.productId}\n${error.message}`);
        if (/agreement|paid apps|tax|banking/i.test(error.message)) {
          console.error('ACTION_REQUIRED: complete Paid Applications agreement / tax / banking in App Store Connect.');
        }
      }

      try {
        entry.screenshot = await uploadScreenshot(sub, spec.internalName);
      } catch (error) {
        entry.screenshotError = error.message;
        report.errors.push(`${spec.productId} screenshot: ${error.message}`);
        console.error(`SCREENSHOT_FAILED ${spec.productId}\n${error.message}`);
      }

      entry.verified = await verify(sub, spec);
      console.log(`VERIFY ${JSON.stringify(entry.verified)}`);
    } catch (error) {
      entry.error = error.message;
      report.errors.push(`${spec.productId}: ${error.message}`);
      console.error(`SUBSCRIPTION_FAILED ${spec.productId}\n${error.message}`);
    }
  }

  const finalSubs = await listAll(`/subscriptionGroups/${group.id}/subscriptions?limit=200`);
  report.finalProducts = finalSubs.map((row) => ({
    id: row.id,
    productId: row.attributes?.productId,
    state: row.attributes?.state,
  }));
  console.log('FINAL_PRODUCTS ' + JSON.stringify(report.finalProducts));
} catch (error) {
  report.errors.push(error.message);
  console.error('FATAL ' + error.message);
}

console.log('REPORT ' + JSON.stringify(report));
const allExist = report.subscriptions.length === SPECS.length && report.subscriptions.every((entry) => entry.id);
const pricesOk = report.subscriptions.every((entry) => entry.price && !entry.priceError);
process.exit(allExist && pricesOk ? 0 : 1);
