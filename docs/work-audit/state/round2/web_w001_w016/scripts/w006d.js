const L=require('./lib');
const IDS=['drawing','animation','editing','advanced','audio','save','workspace','widget','export'];
(async()=>{const b=await L.chromium.launch();
for(const [vp,lang] of [['s320','fr'],['s320','ja'],['sp','es'],['sp','zh-Hans'],['pc','fr']]){const ctx=await L.ctxFor(b,vp);const p=await ctx.newPage();const d=[];
 for(const id of IDS){await p.goto('about:blank');await p.goto(L.url('/features/#'+id,lang),{waitUntil:'networkidle'});const t=[];for(const w of [300,1200,2500]){await p.waitForTimeout(w);t.push(await p.evaluate(id=>Math.round(document.getElementById(id).getBoundingClientRect().top),id));}d.push(id+'='+t.join('/'));if(t[2]<100||t[2]>400)await p.screenshot({path:L.SHOTS+`/w006-${vp}-${lang}-hash-${id}.png`});}
 console.log(vp,lang,'sec top @0.3/1.5/4s:',d.join(' '));await ctx.close();}
await b.close();})();
