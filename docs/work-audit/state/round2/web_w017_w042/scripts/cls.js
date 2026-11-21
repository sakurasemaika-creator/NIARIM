const { chromium } = require('playwright');
const B='http://127.0.0.1:8802';
(async()=>{
  const b=await chromium.launch();
  for(const [u,w,h,slow] of [['/',1280,800,0],['/',1280,800,0],['/?lang=en',1280,800,0],['/coins/?lang=ja',360,740,1],['/coins/?lang=en',360,740,1],['/community/?lang=ja',360,740,1],['/faq/?lang=en',360,740,1]]){
    const ctx=await b.newContext({locale:'ja-JP',viewport:{width:w,height:h}});
    await ctx.route('**/api/community**',r=>r.fulfill({contentType:'application/json',body:'{"works":[]}'}));
    const p=await ctx.newPage();
    if(slow){const cdp=await ctx.newCDPSession(p); await cdp.send('Emulation.setCPUThrottlingRate',{rate:4}); await cdp.send('Network.enable'); await cdp.send('Network.emulateNetworkConditions',{offline:false,latency:150,downloadThroughput:(1.6*1024*1024)/8,uploadThroughput:(750*1024)/8});}
    await p.addInitScript(()=>{window.__s=[];new PerformanceObserver(l=>{for(const e of l.getEntries()) if(!e.hadRecentInput) window.__s.push({v:+e.value.toFixed(3),t:Math.round(e.startTime),src:(e.sources||[]).slice(0,3).map(s=>s.node&&(s.node.nodeName+'.'+String(s.node.className||'').slice(0,28))).join(',')});}).observe({type:'layout-shift',buffered:true});});
    await p.goto(B+u,{waitUntil:'load',timeout:90000}); await p.waitForTimeout(2500);
    const noScroll=await p.evaluate(()=>window.__s.reduce((a,x)=>a+x.v,0).toFixed(3));
    await p.evaluate(async()=>{for(let y=0;y<document.body.scrollHeight;y+=500){scrollTo(0,y);await new Promise(r=>setTimeout(r,60));}}); await p.waitForTimeout(500);
    const s=await p.evaluate(()=>window.__s);
    console.log(u,w,slow?'slow':'fast','cls(before scroll)',noScroll,'total',s.reduce((a,x)=>a+x.v,0).toFixed(3),JSON.stringify(s.filter(x=>x.v>=0.02).slice(0,5)));
    await ctx.close();
  }
  await b.close();
})();
