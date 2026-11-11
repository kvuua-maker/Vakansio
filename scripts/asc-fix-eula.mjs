#!/usr/bin/env node
/**
 * Add the required EULA/privacy links to every App Store description and
 * resubmit the current version with both auto-renewable subscriptions.
 * No iOS code or binary changes.
 */
import fs from 'node:fs';
import crypto from 'node:crypto';

const API = 'https://api.appstoreconnect.apple.com/v1';
const BUNDLE = 'com.kvuua.vakansio';
const BUILD_NUMBER = process.env.BUILD_NUMBER || '22';
const EULA = 'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
const PRIVACY = 'https://kvuua-maker.github.io/Vakansio/legal/privacy.html';
const KEY_ID = process.env.ASC_KEY_ID || '';
const ISSUER = process.env.ASC_ISSUER_ID || process.env.ASK_ISSUER_ID || '';
const PRIVATE_KEY = (process.env.ASC_PRIVATE_KEY || '').replace(/\\n/g, '\n').trim();
if (!KEY_ID || !ISSUER || !PRIVATE_KEY) { console.error('Missing ASC credentials'); process.exit(2); }

const b64 = (v) => Buffer.from(JSON.stringify(v)).toString('base64url');
let token = ''; let tokenAt = 0;
function authToken() {
  const now = Math.floor(Date.now() / 1000);
  if (!token || Date.now() - tokenAt > 600000) {
    const input = b64({ alg: 'ES256', kid: KEY_ID, typ: 'JWT' }) + '.' +
      b64({ iss: ISSUER, iat: now, exp: now + 900, aud: 'appstoreconnect-v1' });
    const sig = crypto.sign('sha256', Buffer.from(input), { key: PRIVATE_KEY, dsaEncoding: 'ieee-p1363' }).toString('base64url');
    token = `${input}.${sig}`; tokenAt = Date.now();
  }
  return token;
}
async function req(method, path, body) {
  const absolute = path.startsWith('http') ? path : `${API}${path}`;
  const headers = { Authorization: `Bearer ${authToken()}`, Accept: 'application/json' };
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  const r = await fetch(absolute, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
  const text = await r.text();
  let data = null; try { data = text ? JSON.parse(text) : {}; } catch { data = { raw: text }; }
  if (!r.ok) {
    const msg = (data.errors || []).map(e => `${e.code}: ${e.detail}`).join('\n') || text.slice(0, 900);
    throw new Error(`HTTP ${r.status} ${method} ${absolute}\n${msg}`);
  }
  return data;
}
async function all(path) {
  const out = []; let next = path;
  while (next) { const d = await req('GET', next); out.push(...(d.data || [])); next = d.links?.next || null; }
  return out;
}
function err(e) { return e.message; }
(async () => {
  const appData = await req('GET', `/apps?filter%5BbundleId%5D=${BUNDLE}&limit=10`);
  const app = (appData.data || [])[0]; if (!app) throw new Error('App not found');
  const versions = await all(`/apps/${app.id}/appStoreVersions?filter%5Bplatform%5D=IOS&limit=200`);
  const version = versions.find(v => ['REJECTED', 'DEVELOPER_REJECTED', 'PREPARE_FOR_SUBMISSION'].includes(v.attributes?.appStoreState)) || versions[0];
  if (!version) throw new Error('No App Store version');
  console.log('VERSION', version.id, version.attributes?.versionString, version.attributes?.appStoreState);

  const localizations = await all(`/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=200`);
  console.log('LOCALIZATIONS', JSON.stringify(localizations.map(l => ({ id: l.id, locale: l.attributes?.locale, length: (l.attributes?.description || '').length }))));
  for (const loc of localizations) {
    const original = loc.attributes?.description || '';
    const suffix = [
      `Terms of Use (EULA): ${EULA}`,
      `Privacy Policy: ${PRIVACY}`,
    ].filter(line => !original.includes(line.split(': ')[0] + ':')).join('\n');
    if (!suffix) { console.log('DESCRIPTION_ALREADY_OK', loc.id, loc.attributes?.locale); continue; }
    const updated = original.trimEnd() + '\n\n' + suffix;
    await req('PATCH', `/appStoreVersionLocalizations/${loc.id}`, {
      data: { type: 'appStoreVersionLocalizations', id: loc.id, attributes: { description: updated } },
    });
    const fresh = await req('GET', `/appStoreVersionLocalizations/${loc.id}`);
    const final = fresh.data?.attributes?.description || '';
    console.log('DESCRIPTION_UPDATED', loc.id, loc.attributes?.locale, final.slice(-260).replace(/\n/g, ' | '));
    if (!final.includes(EULA) || !final.includes(PRIVACY)) throw new Error(`Description verification failed for ${loc.id}`);
  }

  const builds = await all(`/builds?filter%5Bapp%5D=${app.id}&limit=200&sort=-uploadedDate`);
  const build = builds.find(b => String(b.attributes?.version) === String(BUILD_NUMBER));
  if (!build) throw new Error(`Build ${BUILD_NUMBER} not found`);
  console.log('BUILD', build.id, build.attributes?.version, build.attributes?.processingState);
  if (build.attributes?.processingState !== 'VALID') throw new Error(`Build ${BUILD_NUMBER} not VALID`);
  const rel = await req('GET', `/appStoreVersions/${version.id}/relationships/build`);
  if (rel.data?.id !== build.id) {
    await req('PATCH', `/appStoreVersions/${version.id}/relationships/build`, { data: { type: 'builds', id: build.id } });
    console.log('BUILD_ATTACHED', build.id);
  } else { console.log('BUILD_ALREADY_ATTACHED', build.id); }

  const groups = await all(`/apps/${app.id}/subscriptionGroups?limit=200`);
  const subscriptions = []; const groupVersions = [];
  for (const group of groups) {
    const gv = await all(`/subscriptionGroups/${group.id}/versions?limit=200`);
    groupVersions.push(...gv.map(v => ({ id: v.id, state: v.attributes?.state })));
    const subs = await all(`/subscriptionGroups/${group.id}/subscriptions?limit=200`);
    for (const sub of subs) {
      const sv = await all(`/subscriptions/${sub.id}/versions?limit=200`);
      subscriptions.push({ productId: sub.attributes?.productId, versionId: sv[0]?.id, state: sub.attributes?.state });
    }
  }
  const groupVersion = groupVersions.find(v => ['PREPARE_FOR_SUBMISSION', 'READY_FOR_REVIEW'].includes(v.state)) || groupVersions[0];
  if (!subscriptions.length || subscriptions.some(s => !s.versionId) || !groupVersion?.id) throw new Error('Subscriptions/group versions missing');
  console.log('SUBSCRIPTIONS', JSON.stringify(subscriptions), 'GROUP', JSON.stringify(groupVersion));

  let submissions = await all(`/apps/${app.id}/reviewSubmissions?filter%5Bplatform%5D=IOS&limit=200`);
  console.log('SUBMISSIONS', JSON.stringify(submissions.map(s => ({ id: s.id, state: s.attributes?.state }))));
  for (const old of submissions.filter(s => ['UNRESOLVED_ISSUES', 'READY_FOR_REVIEW'].includes(s.attributes?.state))) {
    try {
      const items = await req('GET', `/reviewSubmissions/${old.id}/items?include=appStoreVersion`);
      for (const item of (items.data || [])) {
        if (item.relationships?.appStoreVersion?.data?.id === version.id) {
          await req('DELETE', `/reviewSubmissionItems/${item.id}`);
          console.log('DELETED_STALE_VERSION_ITEM', old.id, item.id);
        }
      }
    } catch (e) { console.log('CLEANUP_FAILED', old.id, err(e)); }
    if (old.attributes?.state === 'UNRESOLVED_ISSUES') {
      try { await req('PATCH', `/reviewSubmissions/${old.id}`, { data: { type: 'reviewSubmissions', id: old.id, attributes: { canceled: true } } }); console.log('CANCELED', old.id); } catch (e) { console.log('CANCEL_FAILED', old.id, err(e)); }
    }
  }
  const created = await req('POST', '/reviewSubmissions', {
    data: { type: 'reviewSubmissions', attributes: { platform: 'IOS' }, relationships: { app: { data: { type: 'apps', id: app.id } } } },
  });
  const submission = created.data;
  console.log('CREATED_SUBMISSION', submission.id, submission.attributes?.state);
  const add = async (label, relName, type, id, required = false) => {
    try {
      await req('POST', '/reviewSubmissionItems', { data: { type: 'reviewSubmissionItems', relationships: {
        reviewSubmission: { data: { type: 'reviewSubmissions', id: submission.id } },
        [relName]: { data: { type, id } },
      } } });
      console.log('ITEM_ADDED', label);
    } catch (e) {
      console.log('ITEM_FAILED', label, err(e));
      if (required) throw e;
    }
  };
  await add('appVersion', 'appStoreVersion', 'appStoreVersions', version.id, true);
  for (const sub of subscriptions) await add(`subscription:${sub.productId}`, 'subscriptionVersion', 'subscriptionVersions', sub.versionId, true);
  await add('subscriptionGroupVersion', 'subscriptionGroupVersion', 'subscriptionGroupVersions', groupVersion.id, true);
  const submitted = await req('PATCH', `/reviewSubmissions/${submission.id}`, {
    data: { type: 'reviewSubmissions', id: submission.id, attributes: { submitted: true } },
  });
  console.log('SUBMITTED', JSON.stringify(submitted.data?.attributes || {}));
  const finalVersion = await req('GET', `/appStoreVersions/${version.id}`);
  console.log('FINAL_VERSION', JSON.stringify(finalVersion.data?.attributes || {}));
})().catch(e => { console.error('EULA_FIX_FAILED', e.message); process.exit(1); });
