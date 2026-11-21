const L=require('./lib');
const IDS=['drawing','animation','editing','advanced','audio','save','workspace','widget','export'];
(async()=>{const b=await L.chromium.launch();
for(const [vp,lang] of [['pc','ja'],['sp','ja'],['s320','fr'],['s320','ja'],['sp','es']]){const ctx=await L.ctxFor(b,vp);const p=await ctx.newPage();
 // click from top nav then back
 await p.goto(L.url('/features/',lang),{waitUntil:'networkidle'});await p.evaluate(()=>window.scrollTo(0,400));await p.waitForTimeout(500);
 const r=[];for(const id of ['audio','widget','export','animation']){const y0=await p.evaluate(()=>Math.round(scrollY));await p.locator(`.feature-nav a[href$="#${id}"]`).click();await p.waitForTimeout(1800);
  const o=await p.evaluate(id=>{const s=document.getElementById(id);const st=document.querySelector('.feature-nav').getBoundingClientRect().bottom;const h=(s.querySelector('h2')||s).getBoundingClientRect();return {hash:location.hash,secTop:Math.round(s.getBoundingClientRect().top),h2:Math.round(h.top),navBottom:Math.round(st),vh:innerHeight}},id);
  await p.goBack();await p.waitForTimeout(1500);const yb=await p.evaluate(()=>Math.round(scrollY)+location.hash);r.push(`${id}: sec=${o.secTop} h2=${o.h2} navB=${o.navBottom} | back y ${y0}→${yb}`);}
 console.log(vp,lang,'CLICK',r.join(' ; '));
 // direct entry, wait 3s
 const d=[];for(const id of IDS){await p.goto('about:blank');await p.goto(L.url('/features/#'+id,lang),{waitUntil:'networkidle'});await p.waitForTimeout(3000);d.push(await p.evaluate(id=>{const s=document.getElementById(id);return id+'='+Math.round(s.getBoundingClientRect().top)+'/'+Math.round((s.querySelector('h2')||s).getBoundingClientRect().top)},id));if(vp==='s320'&&lang==='fr'&&(id==='animation'||id==='widget'))await p.screenshot({path:L.SHOTS+`/w006-s320-fr-hash-${id}.png`});}
 console.log(vp,lang,'DIRECT(sec/h2)',d.join(' '));await ctx.close();}
await b.close();})();
