const L=require('./lib');
(async()=>{const b=await L.chromium.launch();
for(const [path,lang] of [['/about/','ja'],['/','ja']]){
 const ctx=await L.ctxFor(b,'sp');const p=await ctx.newPage();
 await p.goto(L.url(path,lang),{waitUntil:'networkidle'});
 await p.locator('.nav-toggle').focus();await p.keyboard.press('Enter');await p.waitForTimeout(400);
 await p.keyboard.press('Tab');await p.waitForTimeout(500);
 console.log(path,await p.evaluate(()=>{const a=document.activeElement;const r=a.getBoundingClientRect();const top=document.elementFromPoint(r.left+r.width/2,r.top+r.height/2);return {focus:a.textContent.trim().slice(0,20),rect:[Math.round(r.top),Math.round(r.bottom)],scrollY,exp:document.querySelector('.nav-toggle').getAttribute('aria-expanded'),coveredBy:top&&(top.closest('.main-nav')?'main-nav':top.className)}}));
 await p.screenshot({path:L.SHOTS+'/w001-sp-menu-tab-escape'+path.replace(/\//g,'_')+'.png'});
 console.log('skiplinks',await p.evaluate(()=>[...document.querySelectorAll('a[href="#main"],a[class*=skip]')].map(a=>a.outerHTML.slice(0,160))));
 await ctx.close();}
await b.close();})();
