const { chromium } = require('playwright');
const BASE='http://127.0.0.1:8801';
const LANGS=['ja','en','fr','es','ko','zh-Hans','zh-Hant'];
const PAGES=['/','/about/','/features/','/help/','/faq/','/news/','/premium/','/coins/','/community/','/contact/','/terms/','/privacy/'];
const VPS={pc:{width:1280,height:800},sp:{width:360,height:740},s320:{width:320,height:640}};
async function ctxFor(b,vp,opts={}){
  const ctx=await b.newContext({viewport:VPS[vp]||vp,locale:opts.locale||'ja-JP',bypassCSP:!!opts.bypassCSP,colorScheme:opts.colorScheme||'light',reducedMotion:opts.reducedMotion||'no-preference',javaScriptEnabled:opts.js!==false,hasTouch:false});
  await ctx.route('**/api/community**',r=>r.fulfill({status:200,contentType:'application/json; charset=utf-8',body:opts.community||'{"works":[]}'}));
  await ctx.route('**/api/contact**',r=>(opts.contact?opts.contact(r):r.fulfill({status:500,contentType:'application/json',body:'{"error":"internal_error"}'})));
  await ctx.route('**/api/account-deletion**',r=>r.fulfill({status:500,contentType:'application/json',body:'{"error":"internal_error"}'}));
  // block any non-local request
  await ctx.route(u=>!/^(http:\/\/127\.0\.0\.1:8801|data:|blob:|about:)/.test(u.toString()),r=>{ (ctx._ext=ctx._ext||[]).push(r.request().url()); r.abort();});
  return ctx;
}
function url(path,lang){ if(!lang||lang==='') return BASE+path; const [p,h]=path.split('#'); return BASE+p+(p.includes('?')?'&':'?')+'lang='+lang+(h?'#'+h:''); }
function track(p){const errs=[];p.on('pageerror',e=>errs.push('pageerror:'+e.message.slice(0,200)));p.on('console',m=>{if(m.type()==='error')errs.push('console:'+m.text().slice(0,200))});p.on('response',r=>{if(r.status()>=400)errs.push('http'+r.status()+':'+r.url())});return errs;}
async function revealAll(p){ await p.evaluate(async()=>{const h=document.documentElement.scrollHeight;for(let y=0;y<h;y+=500){window.scrollTo(0,y);await new Promise(r=>setTimeout(r,40));}window.scrollTo(0,0);});await p.waitForTimeout(200);}
module.exports={chromium,BASE,LANGS,PAGES,VPS,ctxFor,url,track,revealAll,SHOTS:__dirname+'/shots',OUT:__dirname+'/out'};
