const L=require('./lib');
(async()=>{const b=await L.chromium.launch();
for(const [path,lang] of [['/','ja'],['/about/','ja'],['/features/','fr'],['/help/','en']]){
 const ctx=await L.ctxFor(b,'sp');const p=await ctx.newPage();
 await p.goto(L.url(path,lang),{waitUntil:'networkidle'});
 await p.locator('.nav-toggle').focus();await p.keyboard.press('Enter');await p.waitForTimeout(400);
 const seq=[];
 for(let i=0;i<14;i++){await p.keyboard.press('Shift+Tab');seq.push(await p.evaluate(()=>{const a=document.activeElement;const r=a.getBoundingClientRect();return (a.textContent.trim().slice(0,16)||a.getAttribute('aria-label')||a.className)+'@'+Math.round(r.top)+(a.closest('header')?'':'!OUT')}));}
 console.log('==',path,lang,'REVERSE:',seq.join(' < '));
 console.log(' DOM order:',await p.evaluate(()=>[...document.querySelectorAll('header a,header button')].map(a=>(a.textContent.trim().slice(0,10)||a.className)).join(' | ')));
 await ctx.close();}
await b.close();})();
