#!/usr/bin/env node
/** Withdraw the app-only submission and resubmit app+subscriptions in one review. */
import crypto from 'node:crypto';
const API='https://api.appstoreconnect.apple.com/v1';
const BUNDLE='com.kvuua.vakansio';
const APP_VERSION='1.0.0';
const BUILD_NUMBER='22';
const KEY_ID=process.env.ASC_KEY_ID||'';
const ISSUER=process.env.ASC_ISSUER_ID||process.env.ASK_ISSUER_ID||'';
const KEY=(process.env.ASC_PRIVATE_KEY||'').replace(/\\n/g,'\n').trim();
if(!KEY_ID||!ISSUER||!KEY){console.error('Missing ASC credentials');process.exit(2);}
const b64=v=>Buffer.from(JSON.stringify(v)).toString('base64url');
let token='',tokenAt=0;
function auth(){const now=Math.floor(Date.now()/1000);if(!token||Date.now()-tokenAt>600000){const input=b64({alg:'ES256',kid:KEY_ID,typ:'JWT'})+'.'+b64({iss:ISSUER,iat:now,exp:now+900,aud:'appstoreconnect-v1'});const sig=crypto.sign('sha256',Buffer.from(input),{key:KEY,dsaEncoding:'ieee-p1363'}).toString('base64url');token=input+'.'+sig;tokenAt=Date.now();}return token;}
async function req(method,path,body){const url=path.startsWith('http')?path:API+path;const headers={Authorization:'Bearer '+auth(),Accept:'application/json'};if(body!==undefined)headers['Content-Type']='application/json';const r=await fetch(url,{method,headers,body:body===undefined?undefined:JSON.stringify(body)});const text=await r.text();let data=null;try{data=text?JSON.parse(text):{};}catch{data={raw:text};}if(!r.ok){const msg=(data.errors||[]).map(e=>`${e.code}: ${e.detail}`).join('\n')||text.slice(0,900);const err=new Error(`HTTP ${r.status} ${method} ${url}\n${msg}`);err.status=r.status;err.data=data;throw err;}return data;}
async function all(path){const out=[];let next=path;while(next){const d=await req('GET',next);out.push(...(d.data||[]));next=d.links?.next||null;}return out;}
(async()=>{
 const app=(await req('GET',`/apps?filter%5BbundleId%5D=${BUNDLE}&limit=10`)).data[0];if(!app)throw new Error('app missing');
 const versions=await all(`/apps/${app.id}/appStoreVersions?filter%5Bplatform%5D=IOS&limit=200`);
 const version=versions.find(v=>v.attributes?.versionString===APP_VERSION)||versions[0];
 console.log('APP',app.id,'VERSION',version.id,version.attributes?.versionString,version.attributes?.appStoreState);
 const builds=await all(`/builds?filter%5Bapp%5D=${app.id}&limit=200&sort=-uploadedDate`);
 const build=builds.find(b=>String(b.attributes?.version)===BUILD_NUMBER);if(!build||build.attributes?.processingState!=='VALID')throw new Error('Build 22 not VALID');
 console.log('BUILD',build.id,'VALID');
 const rel=await req('GET',`/appStoreVersions/${version.id}/relationships/build`);if(rel.data?.id!==build.id){await req('PATCH',`/appStoreVersions/${version.id}/relationships/build`,{data:{type:'builds',id:build.id}});console.log('BUILD_ATTACHED');}
 const groups=await all(`/apps/${app.id}/subscriptionGroups?limit=200`);
 const group=groups.find(g=>g.attributes?.referenceName==='Vakansio Plans')||groups[0];if(!group)throw new Error('subscription group missing');
 const gv=(await all(`/subscriptionGroups/${group.id}/versions?limit=200`)).sort((a,b)=>(b.attributes?.version||0)-(a.attributes?.version||0))[0];
 if(!gv)throw new Error('subscription group version missing');
 const subs=await all(`/subscriptionGroups/${group.id}/subscriptions?limit=200`);
 const subVersions=[];
 for(const s of subs){const sv=await all(`/subscriptions/${s.id}/versions?limit=200`);const v=sv[0];if(v)subVersions.push({productId:s.attributes?.productId,id:v.id,state:v.attributes?.state});}
 console.log('GROUP',group.id,group.attributes?.referenceName,'GROUP_VERSION',gv.id,gv.attributes?.state);
 console.log('SUBS',JSON.stringify(subVersions));
 // Withdraw every active draft/submitted submission that contains this app version.
 let submissions=await all(`/apps/${app.id}/reviewSubmissions?filter%5Bplatform%5D=IOS&limit=200`);
 console.log('SUBMISSIONS_BEFORE',JSON.stringify(submissions.map(s=>({id:s.id,state:s.attributes?.state}))));
 for (const s of submissions.filter(s => ['READY_FOR_REVIEW','WAITING_FOR_REVIEW','IN_REVIEW','UNRESOLVED_ISSUES'].includes(s.attributes?.state))) {
   try {
     const items = await req('GET', `/reviewSubmissions/${s.id}/items?include=appStoreVersion`);
     for (const item of (items.data || [])) {
       if (item.relationships?.appStoreVersion?.data?.id === version.id && s.attributes?.state !== 'IN_REVIEW') {
         try {
           await req('DELETE', `/reviewSubmissionItems/${item.id}`);
           console.log('DELETED_ITEM', s.id, item.id);
         } catch (e) {
           console.log('DELETE_ITEM_SKIP', s.id, e.message.split('\n')[0]);
         }
       }
     }
   } catch (e) {
     console.log('ITEMS_READ_FAIL', s.id, e.message.split('\n')[0]);
   }
   try {
     await req('PATCH', `/reviewSubmissions/${s.id}`, { data: { type: 'reviewSubmissions', id: s.id, attributes: { canceled: true } } });
     console.log('CANCELED', s.id);
   } catch (e) {
     console.log('CANCEL_FAILED', s.id, e.message.split('\n')[0]);
   }
 }
 await new Promise(r=>setTimeout(r,3000));
 submissions=await all(`/apps/${app.id}/reviewSubmissions?filter%5Bplatform%5D=IOS&limit=200`);
 console.log('SUBMISSIONS_AFTER',JSON.stringify(submissions.map(s=>({id:s.id,state:s.attributes?.state}))));
 const created=await req('POST','/reviewSubmissions',{data:{type:'reviewSubmissions',attributes:{platform:'IOS'},relationships:{app:{data:{type:'apps',id:app.id}}}}});const submission=created.data;console.log('NEW_SUBMISSION',submission.id,submission.attributes?.state);
 const add=async(label,rel,type,id,required)=>{try{await req('POST','/reviewSubmissionItems',{data:{type:'reviewSubmissionItems',relationships:{reviewSubmission:{data:{type:'reviewSubmissions',id:submission.id}},[rel]:{data:{type,id}}}}});console.log('ADDED',label,id);return true;}catch(e){console.log('ADD_FAILED',label,id,e.message.split('\n').slice(0,4).join(' | '));if(required)throw e;return false;}};
 await add('appVersion','appStoreVersion','appStoreVersions',version.id,true);
 await add('subscriptionGroupVersion','subscriptionGroupVersion','subscriptionGroupVersions',gv.id,true);
 for(const s of subVersions) await add('subscription:'+s.productId,'subscriptionVersion','subscriptionVersions',s.id,false);
 const items=await req('GET',`/reviewSubmissions/${submission.id}/items?include=appStoreVersion,subscriptionVersion,subscriptionGroupVersion`);console.log('ITEMS',JSON.stringify((items.data||[]).map(i=>({type:i.type,rel:i.relationships}))));
 const submitted=await req('PATCH',`/reviewSubmissions/${submission.id}`,{data:{type:'reviewSubmissions',id:submission.id,attributes:{submitted:true}}});console.log('SUBMITTED',JSON.stringify(submitted.data?.attributes||{}));
 const final=await req('GET',`/appStoreVersions/${version.id}`);console.log('FINAL_VERSION',JSON.stringify(final.data?.attributes||{}));
})().catch(e=>{console.error('FORCE_SUBMIT_FAILED',e.message);process.exit(1);});
