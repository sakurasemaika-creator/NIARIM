const L=require('./lib');
(async()=>{const b=await L.chromium.launch();
for(const rm of ['no-preference','reduce'])for(const [path,vp] of [['/about/','pc'],['/about/','sp'],['/premium/','sp'],['/features/','pc']]){const ctx=await L.ctxFor(b,vp,{reducedMotion:rm});const p=await ctx.newPage();await p.goto(L.url(path,'ja'),{waitUntil:'networkidle'});
 const H=await p.evaluate(()=>document.documentElement.scrollHeight);const vh=p.viewportSize().height;const res=[];
 for(let y=0;y<H;y+=vh){await p.mouse.wheel(0,y?vh:0);await p.waitForTimeout(900);
  const hid=await p.evaluate(()=>{const out=[];for(const e of document.querySelectorAll('main *')){const r=e.getBoundingClientRect();if(r.bottom<80||r.top>innerHeight-40||r.height<10)continue;const s=getComputedStyle(e);if((+s.opacity<0.2||s.visibility==='hidden')&&e.textContent.trim().length>5&&!e.closest('[hidden],[aria-hidden=true]')){out.push(e.tagName+'.'+String(e.className).slice(0,30)+':'+s.opacity);}}return out.slice(0,3)});
  if(hid.length){res.push(y+':'+hid.join(','));if(res.length===1)await p.screenshot({path:L.SHOTS+`/reveal-${rm}-${vp}${path.replace(/\//g,'_')}.png`});}}
 console.log(rm,path,vp,'H',H,'hidden-in-view:',res.length,res.slice(0,4));await ctx.close();}
await b.close();})();
