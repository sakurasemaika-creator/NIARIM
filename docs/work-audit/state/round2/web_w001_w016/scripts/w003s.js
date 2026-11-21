const L=require('./lib');
(async()=>{const b=await L.chromium.launch();const ctx=await L.ctxFor(b,{width:1181,height:400});const p=await ctx.newPage();
for(const path of ['/about/','/']){for(const lang of L.LANGS){await p.setViewportSize({width:1181,height:400});await p.goto(L.url(path,lang),{waitUntil:'load'});const bad=[];
 for(let w=1181;w<=2000;w+=(w<1500?20:100)){await p.setViewportSize({width:w,height:400});await p.waitForTimeout(60);
  const o=await p.evaluate(()=>{const hdr=document.querySelector('header').getBoundingClientRect();return [...document.querySelectorAll('header nav a[href]')].filter(a=>a.offsetParent).some(a=>{const r=a.getBoundingClientRect();return r.top<hdr.top-1||r.bottom>hdr.bottom+1})});if(o)bad.push(w);}
 console.log(path,lang,'overflow widths:',bad.join(','));}}
await b.close();})();
