const L=require('./lib');
(async()=>{const b=await L.chromium.launch();
for(const [vp,lang] of [['s320','fr'],['sp','fr'],['sp','ja'],['pc','fr']]){const res={};for(const id of ['animation','editing','widget']){res[id]=[];for(let i=0;i<4;i++){const ctx=await L.ctxFor(b,vp);const p=await ctx.newPage();await p.goto(L.url('/features/#'+id,lang),{waitUntil:'networkidle'});await p.waitForTimeout(2500);res[id].push(await p.evaluate(id=>Math.round(document.getElementById(id).getBoundingClientRect().top),id));await ctx.close();}}
 console.log(vp,lang,JSON.stringify(res));}
await b.close();})();
