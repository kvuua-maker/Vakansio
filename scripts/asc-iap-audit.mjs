#!/usr/bin/env node
import fs from 'node:fs';
import crypto from 'node:crypto';

const API = 'https://api.appstoreconnect.apple.com/v1';
const BUNDLE = 'com.kvuua.vakansio';
const KEY_ID = process.env.ASC_KEY_ID || '';
const ISSUER = process.env.ASC_ISSUER_ID || process.env.ASK_ISSUER_ID || '';
const PRIVATE_KEY = (process.env.ASC_PRIVATE_KEY || '').replace(/\\n/g, '\n').trim();

if (!KEY_ID || !ISSUER || !PRIVATE_KEY) {
  console.error('Missing ASC_KEY_ID / ASC_ISSUER_ID / ASC_PRIVATE_KEY');
  process.exit(2);
}
const b64 = (v) => Buffer.from(JSON.stringify(v)).toString('base64url');
let token = '';
let tokenAt = 0;
function authToken() {
  const now = Math.floor(Date.now() / 1000);
  if (!token || Date.now() - tokenAt > 600000) {
    const input = b64({ alg: 'ES256', kid: KEY_ID, typ: 'JWT' }) + '.' +
      b64({ iss: ISSUER, iat: now, exp: now + 900, aud: 'appstoreconnect-v1' });
    const sig = crypto.sign('sha256', Buffer.from(input), { key: PRIVATE_KEY, dsaEncoding: 'ieee-p1363' }).toString('base64url');
    token = `${input}.${sig}`;
    tokenAt = Date.now();
  }
  return token;
}
async function req(method, path, body) {
  const absolute = path.startsWith('http') ? path : `${API}${path}`;
  const headers = { Authorization: `Bearer ${authToken()}`, Accept: 'application/json' };
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  const r = await fetch(absolute, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
  const text = await r.text();
  let data = null;
  try { data = text ? JSON.parse(text) : {}; } catch { data = { raw: text }; }
  if (!r.ok) {
    const err = new Error(`HTTP ${r.status} ${method} ${absolute}\n${(data.errors || []).map(e => `${e.code}: ${e.detail}`).join('\n') || text.slice(0, 800)}`);
    err.status = r.status; err.data = data; throw err;
  }
  return data;
}
async function all(path) {
  const out = [];
  let next = path;
  while (next) {
    const d = await req('GET', next);
    out.push(...(d.data || []));
    next = d.links?.next || null;
  }
  return out;
}
function summary(x, keys) {
  const a = x.attributes || {};
  const out = { id: x.id };
  for (const k of keys) if (a[k] !== undefined) out[k] = a[k];
  return out;
}
(async () => {
  const appData = await req('GET', `/apps?filter%5BbundleId%5D=${BUNDLE}&limit=10`);
  const app = (appData.data || [])[0];
  if (!app) throw new Error('app not found');
  console.log('APP', app.id, app.attributes?.name);
  const versions = await all(`/apps/${app.id}/appStoreVersions?filter%5Bplatform%5D=IOS&limit=200`);
  console.log('VERSIONS', JSON.stringify(versions.map(v => summary(v, ['versionString', 'appStoreState', 'platform']))));
  for (const v of versions.slice(0, 3)) {
    try {
      const buildRel = await req('GET', `/appStoreVersions/${v.id}/relationships/build`);
      console.log('VERSION_BUILD', v.id, JSON.stringify(buildRel.data || null));
    } catch (e) { console.log('VERSION_BUILD_ERR', v.id, e.message.split('\n')[0]); }
  }
  const builds = await all(`/builds?filter%5Bapp%5D=${app.id}&limit=200&sort=-uploadedDate`);
  console.log('BUILDS', JSON.stringify(builds.map(b => summary(b, ['version', 'processingState', 'uploadedDate', 'expired']))));
  const groups = await all(`/apps/${app.id}/subscriptionGroups?limit=200`);
  console.log('GROUPS', JSON.stringify(groups.map(g => summary(g, ['referenceName']))));
  for (const group of groups) {
    try {
      const gv = await all(`/subscriptionGroups/${group.id}/versions?limit=200`);
      console.log('GROUP_VERSIONS', group.id, JSON.stringify(gv.map(v => summary(v, ['version', 'state']))));
    } catch (e) { console.log('GROUP_VERSIONS_ERR', group.id, e.message.split('\n')[0]); }
    const subs = await all(`/subscriptionGroups/${group.id}/subscriptions?limit=200`);
    console.log('SUBSCRIPTIONS', group.id, JSON.stringify(subs.map(s => summary(s, ['productId', 'name', 'state', 'subscriptionPeriod']))));
    for (const sub of subs) {
      try {
        const sv = await all(`/subscriptions/${sub.id}/versions?limit=200`);
        console.log('SUB_VERSIONS', sub.id, JSON.stringify(sv.map(v => summary(v, ['version', 'state']))));
      } catch (e) { console.log('SUB_VERSIONS_ERR', sub.id, e.message.split('\n')[0]); }
      try {
        const shot = await req('GET', `/subscriptions/${sub.id}/appStoreReviewScreenshot`);
        console.log('SUB_SHOT', sub.id, JSON.stringify(summary(shot.data || {}, ['fileName', 'assetDeliveryState'])));
      } catch (e) { console.log('SUB_SHOT_ERR', sub.id, e.message.split('\n')[0]); }
    }
  }
  const rs = await all(`/apps/${app.id}/reviewSubmissions?filter%5Bplatform%5D=IOS&limit=200`);
  console.log('REVIEW_SUBMISSIONS', JSON.stringify(rs.map(s => summary(s, ['state', 'submittedDate']))));
  for (const s of rs) {
    try {
      const items = await req('GET', `/reviewSubmissions/${s.id}/items?include=appStoreVersion,subscriptionVersion,subscriptionGroupVersion,inAppPurchaseVersion`);
      console.log('REVIEW_ITEMS', s.id, JSON.stringify({ data: (items.data || []).map(i => ({ id: i.id, type: i.type, rel: i.relationships })), included: (items.included || []).map(i => ({ id: i.id, type: i.type, attrs: i.attributes })) }));
    } catch (e) { console.log('REVIEW_ITEMS_ERR', s.id, e.message.split('\n')[0]); }
  }
})().catch(e => { console.error('AUDIT_FAILED', e.message); process.exit(1); });
