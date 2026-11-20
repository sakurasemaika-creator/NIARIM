const { chromium } = require('playwright');
const B='http://127.0.0.1:8802', OUT=process.argv[2];
(async()=>{
  const b=await chromium.launch();
  const ctx=await b.newContext({locale:'ja-JP',viewport:{width:360,height:740},reducedMotion:'reduce'});
  await ctx.route('**/api/community**',r=>r.fulfill({contentType:'application/json',body:'{"works":[]}'}));
  const p=await ctx.newPage();
  for(const path of ['/','/font-licenses/','/help/']){
    await p.goto(B+path+'?lang=en',{waitUntil:'networkidle'}); await p.waitForTimeout(300);
    await p.keyboard.press('Tab'); await p.waitForTimeout(500);
    const first=await p.evaluate(()=>{const a=document.activeElement;const r=a.getBoundingClientRect();return a.innerText.trim()+' rect='+[r.left,r.top,r.width,r.height].map(Math.round).join(',')+' op='+getComputedStyle(a).opacity;});
    await p.screenshot({path:OUT+'/w020-skip'+path.replace(/\//g,'_')+'.png',clip:{x:0,y:0,width:360,height:160}});
    await p.keyboard.press('Enter'); await p.waitForTimeout(300); await p.keyboard.press('Tab');
    const next=await p.evaluate(()=>{const a=document.activeElement;return (a.innerText||a.getAttribute('aria-label')||a.tagName).trim().slice(0,30)+' inMain='+!!a.closest('main')+' hash='+location.hash;});
    console.log('skip',path,first,'| next tab:',next);
  }
  await p.goto(B+'/?lang=en',{waitUntil:'networkidle'});
  const sel='button[aria-label="Open menu"]';
  const info=await p.evaluate(()=>[...document.querySelectorAll('header button')].map(b=>b.className+'|'+b.getAttribute('aria-label')+'|'+b.getAttribute('aria-expanded')+'|'+b.getAttribute('aria-controls')));
  console.log(info.join(' ; '));
  const m=await p.$(sel); await m.focus(); await p.keyboard.press('Enter'); await p.waitForTimeout(500);
  const st=await p.evaluate(()=>[...document.querySelectorAll('header button')].map(b=>b.getAttribute('aria-label')+'='+b.getAttribute('aria-expanded')).join(';'));
  const order=[]; for(let i=0;i<12;i++){await p.keyboard.press('Tab'); order.push(await p.evaluate(()=>(document.activeElement.innerText||document.activeElement.getAttribute('aria-label')||document.activeElement.tagName).trim().slice(0,16)));}
  await p.screenshot({path:OUT+'/w020-sp-menu-en.png'});
  await p.keyboard.press('Escape'); await p.waitForTimeout(400);
  const st2=await p.evaluate(()=>[...document.querySelectorAll('header button')].map(b=>b.getAttribute('aria-label')+'='+b.getAttribute('aria-expanded')).join(';')+' focus='+(document.activeElement.getAttribute('aria-label')||document.activeElement.tagName));
  console.log('open:',st,'| order:',order.join(' > '),'| after Esc:',st2);
  await b.close();
})();
