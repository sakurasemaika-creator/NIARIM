const L=require('./lib');
(async()=>{const b=await L.chromium.launch();
for(const [w,lang,path] of [[1181,'ja','/about/'],[1440,'es','/about/'],[1920,'fr','/about/'],[1440,'fr','/'],[1600,'fr','/'],[1600,'es','/'],[1366,'ja','/'],[1200,'ja','/'],[1240,'ja','/'],[1920,'es','/'],[1280,'ko','/'],[1181,'en','/'],[1181,'zh-Hans','/'],[1181,'ko','/']]){const ctx=await L.ctxFor(b,{width:w,height:400});const p=await ctx.newPage();await p.goto(L.url(path,lang),{waitUntil:'networkidle'});await p.waitForTimeout(400);
 const r=await p.evaluate(()=>{const hdr=document.querySelector('header').getBoundingClientRect();const a=[...document.querySelectorAll('header nav a[href]')].filter(a=>a.offsetParent).map(a=>{const r=a.getBoundingClientRect();return Math.round(r.top)+'-'+Math.round(r.bottom)});return {hdr:[Math.round(hdr.top),Math.round(hdr.bottom)],a:[...new Set(a)]}});
 console.log(w,lang,path,JSON.stringify(r));await p.screenshot({path:L.SHOTS+`/w003-nav-${w}-${lang}.png`,clip:{x:0,y:0,width:w,height:110}});await ctx.close();}
await b.close();})();
