const { chromium } = require('playwright');
const B='http://127.0.0.1:8802', OUT=process.argv[2];
const pages=['/', '/about/', '/features/', '/help/', '/premium/', '/coins/', '/community/', '/news/', '/faq/', '/contact/', '/privacy/', '/terms/', '/font-licenses/', '/account-deletion/','/no-such-page'];
(async()=>{
  const b=await chromium.launch();
  const ctx=await b.newContext({locale:'ja-JP',viewport:{width:360,height:740},reducedMotion:'reduce'});
  await ctx.route('**/api/community**',r=>r.fulfill({contentType:'application/json',body:'{"works":[]}'}));
  const p=await ctx.newPage();
  const go=async(u)=>{await p.goto(B+u,{waitUntil:u.startsWith('/account')?'load':'networkidle'});await p.waitForTimeout(250);};
  for(const w of [320,640]){
    await p.setViewportSize({width:w,height:800});
    const bad=[];
    for(const lang of ['fr','ko','es','ja','en','zh-Hans']) for(const path of pages){ await go(path+'?lang='+lang);
      const o=await p.evaluate(()=>{const ov=document.documentElement.scrollWidth-innerWidth; let clipped=[]; if(ov>1){for(const e of document.querySelectorAll('body *')){const r=e.getBoundingClientRect(); if(r.right>innerWidth+1&&r.width>0&&getComputedStyle(e).position!=='fixed'){clipped.push(e.tagName+'.'+String(e.className).slice(0,30)); if(clipped.length>2)break;}}} return {ov,clipped};});
      if(o.ov>1) bad.push(lang+path+':'+o.ov+JSON.stringify(o.clipped)); }
    console.log('overflow at',w,bad.length?bad.join(' | '):'none');
  }
  await p.setViewportSize({width:360,height:740});
  for(const path of ['/', '/help/', '/coins/','/font-licenses/','/account-deletion/']){
    await go(path+'?lang=en');
    await p.keyboard.press('Tab');
    const first=await p.evaluate(()=>{const a=document.activeElement;const r=a.getBoundingClientRect();const s=getComputedStyle(a);return (a.innerText||a.getAttribute('aria-label')||'').trim().slice(0,30)+' href='+a.getAttribute('href')+' vis='+(r.top>=0&&r.width>1&&r.height>1)+' outline='+s.outlineStyle+' '+s.outlineWidth+' boxshadow='+(s.boxShadow!=='none');});
    await p.keyboard.press('Enter'); await p.waitForTimeout(200);
    const after=await p.evaluate(()=>(document.activeElement.id||document.activeElement.tagName)+' y='+scrollY);
    console.log('skip',path,first,'-> after Enter',after);
  }
  await go('/?lang=en');
  const menu=await p.$('.nav-toggle, button[aria-controls]');
  if(menu){ await menu.focus(); await p.keyboard.press('Enter'); await p.waitForTimeout(400);
    const st=await p.evaluate(()=>{const m=document.querySelector('.nav-toggle, button[aria-controls]');return {expanded:m.getAttribute('aria-expanded'),label:m.getAttribute('aria-label')};});
    const order=[]; for(let i=0;i<14;i++){await p.keyboard.press('Tab'); order.push(await p.evaluate(()=>(document.activeElement.innerText||document.activeElement.getAttribute('aria-label')||document.activeElement.tagName).trim().slice(0,18)));}
    await p.screenshot({path:OUT+'/w020-sp-menu-en.png'});
    await p.keyboard.press('Escape'); await p.waitForTimeout(300);
    const st2=await p.evaluate(()=>{const m=document.querySelector('.nav-toggle, button[aria-controls]');return {expanded:m.getAttribute('aria-expanded'),focusIsMenu:document.activeElement===m};});
    console.log('menu',JSON.stringify(st),'tab order',order.join(' > '),'after Esc',JSON.stringify(st2)); }
  // focus visibility sample: tab through first 25 stops on home PC, count stops without visible focus indicator
  await p.setViewportSize({width:1280,height:800}); await go('/?lang=en');
  let noInd=[]; for(let i=0;i<40;i++){await p.keyboard.press('Tab'); const r=await p.evaluate(()=>{const a=document.activeElement; if(!a||a===document.body) return null; const s=getComputedStyle(a); const rc=a.getBoundingClientRect(); return {t:(a.innerText||a.getAttribute('aria-label')||a.tagName).trim().slice(0,20), ind:(s.outlineStyle!=='none'&&parseFloat(s.outlineWidth)>0)||s.boxShadow!=='none', w:Math.round(rc.width),h:Math.round(rc.height)};}); if(r&&!r.ind) noInd.push(r.t); }
  console.log('home PC first 40 tab stops without outline/box-shadow:',noInd.join(' | ')||'none');
  // target sizes SP
  await p.setViewportSize({width:360,height:740});
  for(const path of ['/','/coins/','/help/','/account-deletion/']){ await go(path+'?lang=ja');
    const small=await p.evaluate(()=>[...document.querySelectorAll('a[href],button,input,select,summary,[role=button],[role=tab]')].filter(e=>{const r=e.getBoundingClientRect();const s=getComputedStyle(e);return r.width>0&&r.height>0&&s.visibility!=='hidden'&&(r.width<24||r.height<24)&&s.display!=='inline';}).map(e=>e.tagName+'.'+String(e.className).slice(0,24)+' '+Math.round(e.getBoundingClientRect().width)+'x'+Math.round(e.getBoundingClientRect().height)+' "'+(e.innerText||e.getAttribute('aria-label')||'').trim().slice(0,14)+'"').slice(0,8));
    console.log('targets <24px',path,small.join(' | ')||'none'); }
  for(const [u,n,w] of [['/coins/?lang=fr','coins-fr-360',360],['/help/?lang=ko','help-ko-360',360],['/font-licenses/?lang=fr','fontlic-fr-360',360],['/?lang=en','home-en-360',360],['/account-deletion/?lang=ja','accdel-ja-1280',1280],['/coins/?lang=es','coins-es-1280',1280]]){
    await p.setViewportSize({width:w,height:800}); await go(u); await p.screenshot({path:OUT+'/w020-'+n+'.png',fullPage:false}); }
  await b.close();
})();
