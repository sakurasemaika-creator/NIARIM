const { chromium } = require('playwright');
const B='http://127.0.0.1:8802', OUT=process.env.OUT;
(async () => {
  const b = await chromium.launch();
  const ctx = await b.newContext({ locale: 'ja-JP', viewport: { width: 360, height: 740 } });
  await ctx.route('**/api/community**', r => r.fulfill({ contentType:'application/json', body:'{"works":[]}' }));
  const p = await ctx.newPage();
  const reqs=[]; p.on('request', r=>{ if(!r.url().startsWith(B)) reqs.push(r.url()); }); p.on('requestfailed', r=>reqs.push('FAIL '+r.url()+' '+(r.failure()||{}).errorText));
  p.on('console', m=>{ if(m.type()==='error') console.log('console', m.text().slice(0,200)); });
  for (const u of ['/account-deletion/?lang=ko','/account-deletion/','/font-licenses/?lang=fr']) {
    const r = await p.goto(B + u, { waitUntil: 'load' });
    await p.waitForTimeout(2500);
    const info = await p.evaluate(() => ({ lang: document.documentElement.lang, title: document.title, h1: document.querySelector('h1') && document.querySelector('h1').innerText, body: document.querySelector('main') && document.querySelector('main').innerText.replace(/\s+/g, ' ').slice(0, 400), ovx: document.documentElement.scrollWidth > innerWidth + 1 }));
    console.log(r.status(), u, JSON.stringify(info));
    await p.screenshot({ path: OUT+'/w017'+u.replace(/[\/?=]/g,'_')+'.png', fullPage: true });
  }
  console.log('external', reqs);
  await p.goto(B+'/about/', { waitUntil: 'networkidle' });
  await p.goto(B+'/zzz', { waitUntil: 'networkidle' });
  await p.goBack(); const back = p.url(); await p.goForward(); console.log('back', back, 'fwd', p.url());
  await p.goto(B+'/zzz?lang=fr', { waitUntil: 'networkidle' });
  await p.screenshot({ path: OUT+'/w017-404-fr.png', fullPage: true });
  await b.close();
})();
