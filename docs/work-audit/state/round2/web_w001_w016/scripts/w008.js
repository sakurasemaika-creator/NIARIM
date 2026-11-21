const L=require('./lib');
const work=(i,x={})=>({youtubeVideoId:('abcdefghij'+i).slice(-11).padStart(11,'x'),workId:'w'+i,title:i===0?'とても長い作品のタイトルがここに入ります。横幅が狭い端末でどう折り返されるかを確かめるための題名です':i===1?'Été à Paris — 한국어 제목 繁體中文標題 简体中文标题':'作品'+i,channelName:'チャンネル'+i,bookmarkCount:100-i,periodBookmarkCount:10-i,thumbnailUrl:'',youtubeUrl:'https://www.youtube.com/watch?v=test'+i,...x});
(async()=>{const b=await L.chromium.launch();
for(const [vp,lang] of [['pc','ja'],['sp','ja'],['sp','fr'],['s320','es']]){let mode='ready',pb='available';const calls=[];
 const ctx=await b.newContext({viewport:L.VPS[vp]});const ext=[];
 await ctx.route(u=>!/^(http:\/\/127\.0\.0\.1:8801|data:|blob:|about:)/.test(u.toString()),r=>{ext.push(r.request().url()+(r.request().isNavigationRequest()?' [NAV '+(r.request().frame()===r.request().frame().page().mainFrame()?'same-tab':'frame')+']':''));r.abort();});
 await ctx.route('**/api/community**',async route=>{const u=new URL(route.request().url());calls.push(u.search);
  if(u.searchParams.has('playbackId')){if(pb==='fail')return route.fulfill({status:502,contentType:'application/json',body:'{}'});return route.fulfill({status:200,contentType:'application/json',body:JSON.stringify({status:pb})});}
  if(mode==='error')return route.fulfill({status:502,contentType:'application/json',body:'{"error":"upstream_unavailable"}'});
  if(mode==='empty')return route.fulfill({status:200,contentType:'application/json',body:JSON.stringify({view:u.searchParams.get('view'),works:[]})});
  if(mode==='unavail')return route.fulfill({status:200,contentType:'application/json',body:JSON.stringify({view:u.searchParams.get('view'),works:[],unavailableReason:'BOOKMARK_PERIOD_NOT_IMPLEMENTED'})});
  return route.fulfill({status:200,contentType:'application/json; charset=utf-8',body:JSON.stringify({view:u.searchParams.get('view'),metric:'periodBookmarks',works:Array.from({length:9},(_,i)=>work(i))})});});
 const p=await ctx.newPage();const errs=L.track(p);const pages=[];ctx.on('page',pg=>pages.push(pg.url()));
 await p.goto(L.url('/community/',lang),{waitUntil:'networkidle'});await p.waitForTimeout(500);
 const G='[data-community-gallery]';
 console.log('==',vp,lang,'tabs',await p.$$eval('[data-community-tab]',bs=>bs.map(b=>b.textContent.trim()+':'+b.tagName+':'+b.getAttribute('aria-pressed')+':'+Math.round(b.getBoundingClientRect().height)).join(' | ')));
 for(const v of ['daily','overall','latest']){await p.click(`[data-community-tab="${v}"]`);await p.waitForTimeout(400);console.log(v,await p.evaluate(G=>{const g=document.querySelector(G);const c=[...g.querySelectorAll('a')];return {n:c.length,first:c[0]&&c[0].innerText.replace(/\s+/g,' ').slice(0,110),target:c[0]&&c[0].getAttribute('target'),href:c[0]&&c[0].getAttribute('href'),pressed:[...document.querySelectorAll('[data-community-tab][aria-pressed=true]')].length}},G));}
 console.log('title font',await p.evaluate(G=>{const c=document.querySelector(G+' a');const t=[...c.querySelectorAll('*')].find(e=>e.children.length===0&&/長い/.test(e.textContent));return t?getComputedStyle(t).fontFamily+' | lines~'+Math.round(t.getBoundingClientRect().height/parseFloat(getComputedStyle(t).lineHeight)):'?'},G));
 await p.locator(G).scrollIntoViewIfNeeded();await p.evaluate(G=>window.scrollTo(0,document.querySelector(G).getBoundingClientRect().top+scrollY-200),G);await p.waitForTimeout(700);await p.screenshot({path:L.SHOTS+`/w008-${vp}-${lang}-cards.png`});
 // keyboard on tabs
 await p.focus('[data-community-tab="weekly"]');await p.keyboard.press('Enter');await p.waitForTimeout(300);await p.keyboard.press('Tab');console.log('kbd weekly pressed',await p.getAttribute('[data-community-tab="weekly"]','aria-pressed'),'next focus',await p.evaluate(()=>document.activeElement.getAttribute('data-community-tab')||document.activeElement.tagName+':'+document.activeElement.textContent.trim().slice(0,20)));
 // click card: available
 ext.length=0;await p.locator(G+' a').nth(2).click();await p.waitForTimeout(900);console.log('click available → ext',ext.slice(0,2),'newpages',pages.length,'url',p.url().slice(0,60));
 if(!p.url().includes('127.0.0.1')){await p.goto(L.url('/community/',lang),{waitUntil:'networkidle'});}
 await p.waitForTimeout(400);
 pb='private';await p.locator(G+' a').nth(2).click();await p.waitForTimeout(900);console.log('click private → msg',await p.evaluate(()=>{const f=document.querySelector('.community-playback-message');return f&&!f.hidden?f.textContent+' role='+f.getAttribute('role'):'(none)'}),'url ok',p.url().includes('8801'));
 pb='fail';await p.locator(G+' a').nth(3).click();await p.waitForTimeout(900);console.log('click fail → msg',await p.evaluate(()=>{const f=document.querySelector('.community-playback-message');const r=f.getBoundingClientRect();return f&&!f.hidden?f.textContent+' inView='+(r.top>=0&&r.bottom<=innerHeight):'(none)'}));
 await p.screenshot({path:L.SHOTS+`/w008-${vp}-${lang}-playfail.png`});
 for(const m of ['empty','error','unavail']){mode=m;await p.click('[data-community-tab="monthly"]');await p.waitForTimeout(200);await p.click('[data-community-tab="weekly"]');await p.waitForTimeout(500);console.log(m,await p.evaluate(G=>document.querySelector(G).innerText.replace(/\s+/g,' ').slice(0,140),G));}
 console.log('overflowX',await p.evaluate(()=>document.documentElement.scrollWidth-innerWidth),'errs',errs.filter(e=>!/502|ERR_FAILED|view-transition/.test(e)).slice(0,4));await ctx.close();}
// tab labels all langs
for(const lang of L.LANGS){const ctx=await L.ctxFor(b,'sp');const p=await ctx.newPage();await p.goto(L.url('/community/',lang),{waitUntil:'networkidle'});await p.waitForTimeout(300);console.log(lang,await p.$$eval('[data-community-tab]',bs=>bs.map(b=>b.textContent.trim()).join(' | ')),'||',await p.evaluate(()=>document.querySelector('[data-community-gallery]').innerText.replace(/\s+/g,' ').slice(0,100)));await ctx.close();}
await b.close();})();
