#!/usr/bin/env node
/**
 * Updates the Ukrainian App Store listing and audits iPhone screenshots.
 * Requires ASC_KEY_ID, ASC_ISSUER_ID and ASC_PRIVATE_KEY (or ASC_KEY_PATH).
 */
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const API = 'https://api.appstoreconnect.apple.com/v1';
const BUNDLE = 'com.kvuua.vakansio';
const LOCALE = 'uk';

const DESCRIPTION = `Vakansio — це розумний додаток для пошуку роботи в Україні, який об'єднує фахівців будь-якого рівня: від IT та маркетингу до будівництва, медицини та сфери послуг.

🛡 Безпека та довіра: Ми використовуємо штучний інтелект, щоб перевіряти кожну вакансію. Жодних кол-центрів, шахраїв чи вимог «заплатити за працевлаштування».

⚡ Резюме за 1 хвилину: Не знаєте, як скласти резюме? Наш AI-помічник сам згенерує його за вас. Просто дайте відповіді на кілька запитань або завантажте фото.

💬 Спілкування без спаму: Забудьте про дзвінки на особистий телефон. Спілкуйтеся з роботодавцем у внутрішньому чаті додатка.

🔍 Розумний пошук: Опишіть бажану посаду або сферу діяльності цілою фразою (наприклад, «водій на своєму авто з Києва»), і наш ШІ знайде саме те, що потрібно.

Знаходьте роботу швидко, безпечно та зручно. Завантажуйте Vakansio вже сьогодні!`;

const KEYWORDS = 'робота,вакансії,пошук роботи,підробіток,резюме,зарплата,hr,найм,робота вдома,робота київ,it,маркетинг,продажі,медицина,будівництво,офіс';
const PROMOTIONAL = 'Знайдіть роботу мрії за 1 хвилину! ШІ-перевірка вакансій, захист від шахраїв та зручний чат з роботодавцем. Для всіх професій!';
const WHATS_NEW = 'Перший реліз Vakansio. Розумний пошук, AI-модерація вакансій та зручний чат.';
const SUPPORT_URL = 'https://178.105.32.46:8443/legal/privacy';
const MARKETING_URL = 'https://178.105.32.46:8443/legal/terms';

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

function clampedKeywords(value) {
  const parts = value.split(',');
  const selected = [];
  for (const part of parts) {
    const candidate = [...selected, part].join(',');
    if (candidate.length <= 100) selected.push(part);
  }
  return selected.join(',');
}

async function findApp() {
  const data = await request('GET', `/apps?filter%5BbundleId%5D=${encodeURIComponent(BUNDLE)}&limit=200`);
  const app = (data.data || []).find((item) => item.attributes?.bundleId === BUNDLE);
  if (!app) throw new Error(`App ${BUNDLE} not found`);
  return app;
}

async function findVersion(appId) {
  const versions = await listAll(`/apps/${appId}/appStoreVersions?filter%5Bplatform%5D=IOS&limit=200`);
  console.log('APP_VERSIONS ' + JSON.stringify(versions.map((v) => ({ id: v.id, version: v.attributes?.versionString, state: v.attributes?.appStoreState }))));
  const editable = versions.find((v) => ['PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED', 'REJECTED', 'WAITING_FOR_REVIEW'].includes(v.attributes?.appStoreState));
  const version = editable || versions[0];
  if (!version) throw new Error('No iOS App Store version found');
  return version;
}

async function ensureLocalization(versionId) {
  const localizations = await listAll(`/appStoreVersions/${versionId}/appStoreVersionLocalizations?limit=200`);
  console.log('LOCALIZATIONS ' + JSON.stringify(localizations.map((l) => ({ id: l.id, locale: l.attributes?.locale }))));
  const existing = localizations.find((l) => [LOCALE, 'uk-UA'].includes(l.attributes?.locale));
  if (existing) return existing;
  const created = await request('POST', '/appStoreVersionLocalizations', {
    data: {
      type: 'appStoreVersionLocalizations',
      attributes: { locale: LOCALE },
      relationships: { version: { data: { type: 'appStoreVersions', id: versionId } } },
    },
  });
  return created.data;
}

async function patchLocalization(localization, attributes) {
  const data = await request('PATCH', `/appStoreVersionLocalizations/${localization.id}`, {
    data: {
      type: 'appStoreVersionLocalizations',
      id: localization.id,
      attributes,
    },
  });
  return data.data;
}

async function auditScreenshots(localization) {
  const sets = await listAll(`/appStoreVersionLocalizations/${localization.id}/appScreenshotSets?limit=200`);
  const result = { sets: [], removedIPad: [], iphoneSets: 0, wrongSizes: [] };
  for (const set of sets) {
    const displayType = set.attributes?.screenshotDisplayType || '';
    if (displayType.startsWith('APP_IPAD')) {
      try {
        await request('DELETE', `/appScreenshotSets/${set.id}`);
        result.removedIPad.push({ id: set.id, displayType });
      } catch (error) {
        result.removedIPad.push({ id: set.id, displayType, error: error.message });
      }
      continue;
    }
    if (!displayType.startsWith('APP_IPHONE')) continue;
    result.iphoneSets += 1;
    const screenshots = await listAll(`/appScreenshotSets/${set.id}/appScreenshots?limit=200`);
    const sizes = screenshots.map((shot) => ({
      width: shot.attributes?.imageAsset?.width ?? null,
      height: shot.attributes?.imageAsset?.height ?? null,
      state: shot.attributes?.assetDeliveryState?.state ?? null,
    }));
    const valid = sizes.some((size) => (
      (size.width === 1320 && size.height === 2868) ||
      (size.width === 1290 && size.height === 2796)
    ));
    if (!valid) result.wrongSizes.push({ displayType, sizes });
    result.sets.push({ id: set.id, displayType, screenshots: sizes, valid });
  }
  if (result.iphoneSets === 0) result.error = 'No iPhone screenshot set found';
  return result;
}

async function auditPrices(appId) {
  const groups = await listAll(`/apps/${appId}/subscriptionGroups?limit=200`);
  const result = [];
  for (const group of groups) {
    const subscriptions = await listAll(`/subscriptionGroups/${group.id}/subscriptions?limit=200`);
    for (const sub of subscriptions) {
      const prices = await listAll(`/subscriptions/${sub.id}/prices?include=subscriptionPricePoint&limit=200`);
      result.push({
        group: group.attributes?.referenceName,
        productId: sub.attributes?.productId,
        state: sub.attributes?.state,
        prices: prices.map((price) => ({
          id: price.id,
          pricePoint: price.relationships?.subscriptionPricePoint?.data?.id || null,
        })),
      });
    }
  }
  return result;
}

async function main() {
  const report = { appId: null, versionId: null, localizationId: null, updated: false, keywordsUsed: null, keywordWarning: null, whatsNew: null, screenshots: null, prices: null, errors: [] };
  try {
    const app = await findApp();
    report.appId = app.id;
    const version = await findVersion(app.id);
    report.versionId = version.id;
    const localization = await ensureLocalization(version.id);
    report.localizationId = localization.id;

    const attributes = {
      description: DESCRIPTION,
      keywords: KEYWORDS,
      promotionalText: PROMOTIONAL,
      supportUrl: SUPPORT_URL,
      marketingUrl: MARKETING_URL,
    };
    try {
      await patchLocalization(localization, attributes);
      report.keywordsUsed = KEYWORDS;
      report.updated = true;
    } catch (error) {
      if (!/KEYWORDS|keyword|100|too long/i.test(error.message)) throw error;
      report.keywordWarning = error.message;
      attributes.keywords = clampedKeywords(KEYWORDS);
      await patchLocalization(localization, attributes);
      report.keywordsUsed = attributes.keywords;
      report.updated = true;
    }

    try {
      await patchLocalization(localization, { whatsNew: WHATS_NEW });
      report.whatsNew = true;
    } catch (error) {
      report.whatsNew = false;
      report.whatsNewError = error.message;
      console.warn('WHATS_NEW_NOT_EDITABLE ' + error.message);
    }
    console.log('METADATA_UPDATED ' + JSON.stringify({ version: version.attributes?.versionString, state: version.attributes?.appStoreState, locale: localization.attributes?.locale, keywords: report.keywordsUsed, whatsNew: report.whatsNew }));

    try {
      report.screenshots = await auditScreenshots(localization);
      console.log('SCREENSHOTS ' + JSON.stringify(report.screenshots));
    } catch (error) {
      report.screenshotsError = error.message;
      console.error('SCREENSHOTS_FAILED ' + error.message);
    }

    try {
      report.prices = await auditPrices(app.id);
      console.log('PRICES ' + JSON.stringify(report.prices));
    } catch (error) {
      report.pricesError = error.message;
      console.error('PRICES_FAILED ' + error.message);
    }
  } catch (error) {
    report.errors.push(error.message);
    console.error('METADATA_FAILED ' + error.message);
  }
  console.log('METADATA_REPORT ' + JSON.stringify(report));
  if (report.errors.length) process.exitCode = 1;
}

main();
