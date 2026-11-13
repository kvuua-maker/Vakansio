#!/usr/bin/env node
/** Attach Build 24 and leave a READY_FOR_REVIEW draft containing app+IAP. */
import crypto from 'node:crypto';
const API='https://api.appstoreconnect.apple.com/v1';
const BUNDLE='com.kvuua.vakansio';
const BUILD='24';
const KEY=process.env.ASC_PRIVATE_KEY?.replace(/\\n/g,'\n').trim()||'';
const KID=process.env.ASC_KEY_ID||'';
const ISS=process.env.ASC_ISSUER_ID||process.env.ASK_ISSUER_ID||'';
if(!KEY||!KID||!ISS){console.error('Missing ASC credentials');process.exit(2);}
const b64=v=>Buffer.from(JSON.stringify(v)).toString('base64url');
let tok='',at=0;
function auth(){const now=Math.floor(Date.now()/1000);if(!tok||Date.now()-at>600000){const input=b64({alg:'ES256',kid:KID,typ:'JWT'})+'.'+b64({iss:ISS,iat:now,exp:now+900,aud:'appstoreconnect-v1'});tok=input+'.'+crypto.sign('sha256',Buffer.from(input),{key:KEY,dsaEncoding:'ieee-p1363'}).toString('base64url');at=Date.now();}return tok;}
async function req(method,path,body){const url=path.startsWith('http')?path:API+path;const h={Authorization:'Bearer '+auth(),Accept:'application/json'};if(body!==undefined)h['Content-Type']='application/json';const r=await fetch(url,{method,headers:h,body:body===undefined?undefined:JSON.stringify(body)});const text=await r.text();let d=null;try{d=text?JSON.parse(text):{};}catch{d={raw:text};}if(!r.ok){const msg=(d.errors||[]).map(e=>`${e.code}: ${e.detail}`).join('\n')||text.slice(0,900);throw new Error(`HTTP ${r.status} ${method} ${url}\n${msg}`);}return d;}
async function all(path){const out=[];let next=path;while(next){const d=await req('GET',next);out.push(...(d.data||[]));next=d.links?.next||null;}return out;}
(async()=>{
 const app=(await req('GET',`/apps?filter%5BbundleId%5D=${BUNDLE}&limit=10`)).data[0];
 const versions=await all(`/apps/${app.id}/appStoreVersions?filter%5Bplatform%5D=IOS&limit=200`);
 const version=versions.find(v=>v.attributes?.versionString==='1.0.0')||versions[0];
 console.log('VERSION',version.id,version.attributes?.versionString,version.attributes?.appStoreState);
 const builds=await all(`/builds?filter%5Bapp%5D=${app.id}&limit=200&sort=-uploadedDate`);
 const build=builds.find(b=>String(b.attributes?.version)===BUILD);
 if(!build||build.attributes?.processingState!=='VALID')throw new Error(`Build ${BUILD} is not VALID`);
 console.log('BUILD',build.id,build.attributes?.processingState);
 const rel=await req('GET',`/appStoreVersions/${version.id}/relationships/build`);
 if(rel.data?.id!==build.id){await req('PATCH',`/appStoreVersions/${version.id}/relationships/build`,{data:{type:'builds',id:build.id}});console.log('BUILD_ATTACHED');}else console.log('BUILD_ALREADY_ATTACHED');
 const groups=await all(`/apps/${app.id}/subscriptionGroups?limit=200`);
 const group=groups.find(g=>g.attributes?.referenceName==='Vakansio Plans')||groups[0];
 const gv=(await all(`/subscriptionGroups/${group.id}/versions?limit=200`)).sort((a,b)=>(b.attributes?.version||0)-(a.attributes?.version||0))[0];
 const subs=await all(`/subscriptionGroups/${group.id}/subscriptions?limit=200`);
 const subVersions=[];for(const s of subs){const sv=await all(`/subscriptions/${s.id}/versions?limit=200`);if(sv[0])subVersions.push({productId:s.attributes?.productId,id:sv[0].id,state:sv[0].attributes?.state});}
 console.log('SUBS',JSON.stringify(subVersions));
 let subsList=await all(`/apps/${app.id}/reviewSubmissions?filter%5Bplatform%5D=IOS&limit=200`);
 console.log('SUBMISSIONS',JSON.stringify(subsList.map(s=>({id:s.id,state:s.attributes?.state}))));
 // Remove empty/canceled drafts so the app version is released for a fresh draft.
 for (const s of subsList.filter(s => ['READY_FOR_REVIEW','UNRESOLVED_ISSUES','CANCELED'].includes(s.attributes?.state))) {
   try {
     const items = await req('GET', `/reviewSubmissions/${s.id}/items`);
     if (!(items.data || []).length) {
       try { await req('DELETE', `/reviewSubmissions/${s.id}`); console.log('DELETED_EMPTY_SUBMISSION', s.id); }
       catch (e) { console.log('DELETE_EMPTY_FAILED', s.id, e.message.split('\n')[0]); }
     }
   } catch (e) { console.log('CHECK_EMPTY_FAILED', s.id, e.message.split('\n')[0]); }
 }
 for(const s of subsList.filter(s=>['READY_FOR_REVIEW','WAITING_FOR_REVIEW','IN_REVIEW','UNRESOLVED_ISSUES'].includes(s.attributes?.state))){
  try{const items=await req('GET',`/reviewSubmissions/${s.id}/items?include=appStoreVersion`);for(const item of (items.data||[])){if(item.relationships?.appStoreVersion?.data?.id===version.id){try{await req('DELETE',`/reviewSubmissionItems/${item.id}`);console.log('DELETED_ITEM',s.id);}catch(e){console.log('DELETE_ITEM_FAILED',s.id,e.message.split('\n')[0]);}}}}catch(e){console.log('ITEMS_FAILED',s.id,e.message.split('\n')[0]);}
  try{await req('PATCH',`/reviewSubmissions/${s.id}`,{data:{type:'reviewSubmissions',id:s.id,attributes:{canceled:true}}});console.log('CANCELED',s.id);}catch(e){console.log('CANCEL_FAILED',s.id,e.message.split('\n')[0]);}
 }
 await new Promise(r=>setTimeout(r,3000));
 subsList=await all(`/apps/${app.id}/reviewSubmissions?filter%5Bplatform%5D=IOS&limit=200`);
 const created=await req('POST','/reviewSubmissions',{data:{type:'reviewSubmissions',attributes:{platform:'IOS'},relationships:{app:{data:{type:'apps',id:app.id}}}}});
 const submission=created.data;console.log('DRAFT',submission.id,submission.attributes?.state);
 const add=async(label,rel,type,id,required)=>{try{await req('POST','/reviewSubmissionItems',{data:{type:'reviewSubmissionItems',relationships:{reviewSubmission:{data:{type:'reviewSubmissions',id:submission.id}},[rel]:{data:{type,id}}}}});console.log('ADDED',label);}catch(e){console.log('ADD_FAILED',label,e.message.split('\n').slice(0,3).join(' | '));if(required)throw e;}};
 await add('appVersion','appStoreVersion','appStoreVersions',version.id,true);
 await add('subscriptionGroupVersion','subscriptionGroupVersion','subscriptionGroupVersions',gv.id,true);
 for(const s of subVersions)await add('subscription:'+s.productId,'subscriptionVersion','subscriptionVersions',s.id,true);
 const items=await req('GET',`/reviewSubmissions/${submission.id}/items?include=appStoreVersion,subscriptionVersion,subscriptionGroupVersion`);
 console.log('ITEMS',JSON.stringify((items.data||[]).map(i=>({type:i.type,rel:i.relationships}))));
 const final=await req('GET',`/reviewSubmissions/${submission.id}`);console.log('DRAFT_STATE',JSON.stringify(final.data?.attributes||{}));
})().catch(e=>{console.error('PREPARE_FAILED',e.message);process.exit(1);});
