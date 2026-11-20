const { chromium } = require('playwright');
const B='http://127.0.0.1:8802';
(async()=>{
  const b=await chromium.launch();
  const ctx=await b.newContext({locale:'ja-JP',viewport:{width:1280,height:900},reducedMotion:'reduce'});
  await ctx.route('**/api/community**',r=>r.fulfill({contentType:'application/json',body:'{"works":[]}'}));
  const p=await ctx.newPage(); const hits={es:new Set(),fr:new Set()};
  for(const lang of ['es','fr']) for(const path of ['/','/coins/','/premium/','/faq/','/help/','/about/','/features/','/community/','/news/']){
    await p.goto(B+path+'?lang='+lang,{waitUntil:'networkidle'}); await p.waitForTimeout(300);
    const t=await p.evaluate(()=>document.title+'\n'+document.body.innerText+'\n'+[...document.querySelectorAll('details')].map(d=>d.textContent).join('\n'));
    const re= lang==='es' ? /[^.\n]{0,25}\b(las|unas|una|la|muchas|tus|estas|esas|todas|cuántas|pocas|más|gratuitas|necesarias|obtenidas|ganadas|acumuladas)\s+ópalos?\b[^.\n]{0,20}|[^.\n]{0,25}ópalos?\s+(gratuitas|necesarias|obtenidas|ganadas|acumuladas|usadas|canjeadas)\b|(^|[.!?¡¿]\s+|\n)ópalos?\b[^.\n]{0,25}/g : /(^|[.!?]\s+|\n)opales?\b[^.\n]{0,25}/g;
    for(const m of t.matchAll(re)) hits[lang].add(path+': '+m[0].trim().replace(/\s+/g,' '));
  }
  for(const l of ['es','fr']){ console.log(l, hits[l].size); [...hits[l]].slice(0,25).forEach(x=>console.log('  ',x)); }
  await b.close();
})();
