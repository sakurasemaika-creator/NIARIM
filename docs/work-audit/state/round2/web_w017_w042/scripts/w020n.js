const { chromium } = require('playwright');
const B='http://127.0.0.1:8802', OUT=process.argv[2];
(async()=>{
  const b=await chromium.launch();
  const ctx=await b.newContext({locale:'ja-JP',viewport:{width:360,height:740},reducedMotion:'reduce'});
  await ctx.route('**/api/community**',r=>r.fulfill({contentType:'application/json',body:'{"works":[]}'}));
  const p=await ctx.newPage();
  for (const path of ['/','/about/']){
  await p.goto(B+path+'?lang=en',{waitUntil:'networkidle'});
  const name=()=>p.evaluate(()=>{const a=document.activeElement;return (a.innerText||a.getAttribute('aria-label')||a.tagName).trim().slice(0,16)+(a.closest('#main-nav')?'[nav]':a.closest('main')?'[main]':a.closest('header')?'[hdr]':'')});
  // natural order from top with menu closed
  const closed=[]; for(let i=0;i<6;i++){await p.keyboard.press('Tab'); closed.push(await name());}
  await p.goto(B+path+'?lang=en',{waitUntil:'networkidle'});
  const m=await p.$('button.nav-toggle'); await m.focus(); await p.keyboard.press('Enter'); await p.waitForTimeout(500);
  const f0=await name();
  const fwd=[]; for(let i=0;i<4;i++){await p.keyboard.press('Tab'); fwd.push(await name());}
  await m.focus(); const back=[]; for(let i=0;i<12;i++){await p.keyboard.press('Shift+Tab'); back.push(await name());}
  if(path==='/') await p.screenshot({path:OUT+'/w020-sp-menu-open-en.png'});
  console.log(path,'closed order:',closed.join(' > '),'\n  after open focus:',f0,'| Tab:',fwd.join(' > '),'\n  Shift+Tab from toggle:',back.join(' > '));
  }
  await b.close();
})();
