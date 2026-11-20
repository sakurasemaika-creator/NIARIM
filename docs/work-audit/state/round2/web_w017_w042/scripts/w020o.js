const { chromium } = require('playwright');
const B='http://127.0.0.1:8802', OUT=process.argv[2];
(async()=>{
  const b=await chromium.launch();
  for (const [lang,path] of [['ja','/'],['fr','/premium/'],['en','/help/']]){
  const ctx=await b.newContext({locale:'ja-JP',viewport:{width:360,height:740}});
  await ctx.route('**/api/community**',r=>r.fulfill({contentType:'application/json',body:'{"works":[]}'}));
  const p=await ctx.newPage();
  await p.goto(B+path+'?lang='+lang,{waitUntil:'networkidle'});
  await p.click('button.nav-toggle'); await p.waitForTimeout(700);
  const out=[];
  for(let i=0;i<3;i++){ await p.keyboard.press('Tab'); await p.waitForTimeout(150);
    out.push(await p.evaluate(()=>{const a=document.activeElement; const r=a.getBoundingClientRect(); const cx=Math.min(Math.max(r.left+r.width/2,1),innerWidth-1), cy=r.top+r.height/2; const top=(cy>=0&&cy<innerHeight)?document.elementFromPoint(cx,cy):null; return (a.innerText||a.getAttribute('aria-label')||a.tagName).trim().slice(0,18)+' in='+(a.closest('#main-nav')?'nav':a.closest('main')?'main':a.closest('header')?'header':'other')+' y='+Math.round(cy)+' covered='+(top? !(top===a||a.contains(top)) : 'offscreen')+' bodyOverflow='+getComputedStyle(document.body).overflow+' mainInert='+(document.querySelector('main').inert);})); }
  await p.screenshot({path:OUT+'/w020-menu-tab3-'+lang+'.png'});
  console.log(lang,path,out.join(' || '));
  await ctx.close(); }
  await b.close();
})();
