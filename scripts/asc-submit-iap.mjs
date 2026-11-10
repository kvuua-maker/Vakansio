#!/usr/bin/env node
/**
 * Attach Build 22 to the rejected 1.0.0 version and submit the app version,
 * both auto-renewable subscriptions and the subscription group as one review.
 */
import fs from 'node:fs';
import crypto from 'node:crypto';

const API = 'https://api.appstoreconnect.apple.com/v1';
const BUNDLE = 'com.kvuua.vakansio';
const BUILD_NUMBER = process.env.BUILD_NUMBER || '22';
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
    const msg = (data.errors || []).map(e => `${e.code}: ${e.detail}`).join('\n') || text.slice(0, 900);
    throw new Error(`HTTP ${r.status} ${method} ${absolute}\n${msg}`);
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
function fmt(e) { return e.message; }
(async () => {
  const appData = await req('GET', `/apps?filter%5BbundleId%5D=${BUNDLE}&limit=10`);
  const app = (appData.data || [])[0];
  if (!app) throw new Error('App not found');
  const versions = await all(`/apps/${app.id}/appStoreVersions?filter%5Bplatform%5D=IOS&limit=200`);
  const version = versions.find(v => ['REJECTED', 'DEVELOPER_REJECTED', 'PREPARE_FOR_SUBMISSION'].includes(v.attributes?.appStoreState)) || versions[0];
  if (!version) throw new Error('No App Store version');
  console.log('VERSION', version.id, version.attributes?.versionString, version.attributes?.appStoreState);

  let builds = await all(`/builds?filter%5Bapp%5D=${app.id}&limit=200&sort=-uploadedDate`);
  let build = builds.find(b => String(b.attributes?.version) === String(BUILD_NUMBER));
  for (let i = 0; !build && i < 30; i += 1) {
    await new Promise(r => setTimeout(r, 10000));
    builds = await all(`/builds?filter%5Bapp%5D=${app.id}&limit=200&sort=-uploadedDate`);
    build = builds.find(b => String(b.attributes?.version) === String(BUILD_NUMBER));
  }
  if (!build) throw new Error(`Build ${BUILD_NUMBER} not found`);
  console.log('BUILD', build.id, build.attributes?.version, build.attributes?.processingState);
  if (build.attributes?.processingState !== 'VALID') throw new Error(`Build ${BUILD_NUMBER} state ${build.attributes?.processingState}`);

  const currentRel = await req('GET', `/appStoreVersions/${version.id}/relationships/build`);
  if (currentRel.data?.id !== build.id) {
    await req('PATCH', `/appStoreVersions/${version.id}/relationships/build`, {
      data: { type: 'builds', id: build.id },
    });
    console.log('ATTACHED_BUILD', build.id);
  } else {
    console.log('BUILD_ALREADY_ATTACHED', build.id);
  }

  const groups = await all(`/apps/${app.id}/subscriptionGroups?limit=200`);
  const subscriptions = [];
  const groupVersions = [];
  for (const group of groups) {
    const gv = await all(`/subscriptionGroups/${group.id}/versions?limit=200`);
    groupVersions.push(...gv.map(v => ({ groupId: group.id, versionId: v.id, state: v.attributes?.state })));
    const subs = await all(`/subscriptionGroups/${group.id}/subscriptions?limit=200`);
    for (const sub of subs) {
      const sv = await all(`/subscriptions/${sub.id}/versions?limit=200`);
      subscriptions.push({
        productId: sub.attributes?.productId,
        state: sub.attributes?.state,
        versionId: sv[0]?.id,
        versionState: sv[0]?.attributes?.state,
      });
    }
  }
  console.log('SUBSCRIPTIONS', JSON.stringify(subscriptions));
  console.log('GROUP_VERSIONS', JSON.stringify(groupVersions));
  if (!subscriptions.length || subscriptions.some(s => !s.versionId)) throw new Error('Missing subscription versions');
  const gv = groupVersions.find(v => v.versionId && ['PREPARE_FOR_SUBMISSION', 'READY_FOR_REVIEW'].includes(v.state)) || groupVersions[0];
  if (!gv?.versionId) throw new Error('Missing subscription group version');

  let submissions = await all(`/apps/${app.id}/reviewSubmissions?filter%5Bplatform%5D=IOS&limit=200`);
  console.log('EXISTING_SUBMISSIONS', JSON.stringify(submissions.map(s => ({ id: s.id, state: s.attributes?.state }))));
  // The previous unsuccessful submission is closed for item changes. Create a fresh draft.
  const created = await req('POST', '/reviewSubmissions', {
    data: {
      type: 'reviewSubmissions',
      attributes: { platform: 'IOS' },
      relationships: { app: { data: { type: 'apps', id: app.id } } },
    },
  });
  const submission = created.data;
  console.log('CREATED_SUBMISSION', submission.id, submission.attributes?.state);

  const addItem = async (label, rel, type, id) => {
    try {
      await req('POST', '/reviewSubmissionItems', {
        data: {
          type: 'reviewSubmissionItems',
          relationships: {
            reviewSubmission: { data: { type: 'reviewSubmissions', id: submission.id } },
            [rel]: { data: { type, id } },
          },
        },
      });
      console.log('ITEM_ADDED', label, id);
    } catch (e) {
      console.log('ITEM_SKIPPED', label, id, fmt(e));
    }
  };

  await addItem('appVersion', 'appStoreVersion', 'appStoreVersions', version.id);
  for (const sub of subscriptions) {
    await addItem(`subscription:${sub.productId}`, 'subscriptionVersion', 'subscriptionVersions', sub.versionId);
  }
  await addItem('subscriptionGroupVersion', 'subscriptionGroupVersion', 'subscriptionGroupVersions', gv.versionId);

  const items = await req('GET', `/reviewSubmissions/${submission.id}/items?include=appStoreVersion,subscriptionVersion,subscriptionGroupVersion`);
  console.log('ITEMS', JSON.stringify((items.data || []).map(i => ({ id: i.id, type: i.type, rel: i.relationships }))));
  const submitted = await req('PATCH', `/reviewSubmissions/${submission.id}`, {
    data: { type: 'reviewSubmissions', id: submission.id, attributes: { submitted: true } },
  });
  console.log('SUBMITTED', JSON.stringify(submitted.data?.attributes || {}));
  const final = await req('GET', `/reviewSubmissions/${submission.id}`);
  console.log('FINAL_SUBMISSION', JSON.stringify(final.data?.attributes || {}));
})().catch(e => { console.error('IAP_SUBMIT_FAILED', e.message); process.exit(1); });
