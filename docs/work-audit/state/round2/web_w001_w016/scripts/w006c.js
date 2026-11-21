const L=require('./lib');
(async()=>{const b=await L.chromium.launch();
for(const vp of ['pc','sp']){const ctx=await L.ctxFor(b,vp);const p=await ctx.newPage();await p.goto(L.url('/features/','ja'),{waitUntil:'networkidle'});
 const info=()=>p.evaluate(()=>{const e=document.elementFromPoint(innerWidth/2,300);const n=document.querySelector('.feature-nav');return {y:Math.round(scrollY),H:document.documentElement.scrollHeight,at:(e.closest('section[id]')||{}).id+':'+e.textContent.trim().slice(0,20),navTop:Math.round(n.getBoundingClientRect().top+scrollY),hash:location.hash}});
 for(const y of [400,2500]){await p.mouse.move(200,300);await p.evaluate(y=>window.scrollTo(0,y),y);await p.waitForTimeout(1500);console.log(vp,'before',JSON.stringify(await info()));
  await p.locator('.feature-nav a[href$="#audio"]').click();await p.waitForTimeout(1800);console.log(vp,' after click',JSON.stringify(await info()));
  await p.goBack();await p.waitForTimeout(1800);console.log(vp,' after back',JSON.stringify(await info()));}
 await ctx.close();}
await b.close();})();
