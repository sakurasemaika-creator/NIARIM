const L=require('./lib');
(async()=>{const b=await L.chromium.launch();
for(const [vp,lang] of [['pc','ja'],['sp','fr']]){const ctx=await L.ctxFor(b,vp);const p=await ctx.newPage();const errs=L.track(p);await p.goto(L.url('/',lang),{waitUntil:'networkidle'});await L.revealAll(p);
 // interactive elements inside mocks?
 console.log(vp,lang,'links in main',await p.evaluate(()=>[...document.querySelectorAll('main a[href]')].map(a=>a.textContent.trim().slice(0,24)+'→'+a.getAttribute('href')).join(' | ')));
 console.log('buttons in main',await p.evaluate(()=>[...document.querySelectorAll('main button, main [role=button], main [tabindex]')].map(a=>(a.textContent.trim().slice(0,14)||a.getAttribute('aria-label'))+(a.disabled?'[dis]':'')+'/'+(a.getAttribute('aria-pressed')||'')).join(' | ')));
 console.log('details/acc',await p.evaluate(()=>[...document.querySelectorAll('main details summary')].map(s=>s.textContent.trim().slice(0,30))));
 // palette
 const pal=p.locator('main button:has-text("Palette"), main [aria-label*="Palette"], main [aria-label*="パレット"], main [aria-label*="テーマ"]');console.log('palette count',await pal.count());
 const sw=await p.evaluate(()=>[...document.querySelectorAll('main button')].filter(b=>/palette|theme|swatch/i.test(b.className+b.getAttribute('aria-label'))).map(b=>b.className+'|'+b.getAttribute('aria-label')+'|'+b.getAttribute('aria-pressed')));console.log('swatches',sw);
 // open viewer
 const zoom=p.locator('main button').filter({hasText:lang==='ja'?'拡大する':/Agrandir|Zoom|Voir/}).first();
 if(await zoom.count()){await zoom.scrollIntoViewIfNeeded();await zoom.focus();await p.keyboard.press('Enter');await p.waitForTimeout(600);
  console.log('viewer',await p.evaluate(()=>{const d=document.querySelector('dialog[open],[role=dialog]');return d?{tag:d.tagName,label:d.getAttribute('aria-label')||d.getAttribute('aria-labelledby'),modal:d.getAttribute('aria-modal'),focus:document.activeElement.tagName+'.'+document.activeElement.className+':'+(document.activeElement.getAttribute('aria-label')||document.activeElement.textContent.trim().slice(0,20)),btns:[...d.querySelectorAll('button,a')].map(b=>b.getAttribute('aria-label')||b.textContent.trim().slice(0,20))}:null}));
  await p.screenshot({path:L.SHOTS+`/w004-${vp}-${lang}-viewer.png`});
  const seq=[];for(let i=0;i<6;i++){await p.keyboard.press('Tab');seq.push(await p.evaluate(()=>(document.activeElement.getAttribute('aria-label')||document.activeElement.textContent.trim().slice(0,15))+(document.activeElement.closest('dialog,[role=dialog]')?'':'!OUT')));}console.log('viewer tab',seq.join(' > '));
  await p.keyboard.press('ArrowRight');await p.waitForTimeout(300);await p.keyboard.press('Escape');await p.waitForTimeout(400);
  console.log('after esc open?',await p.evaluate(()=>!!document.querySelector('dialog[open]')+' focus='+document.activeElement.textContent.trim().slice(0,12)+' bodyOv='+getComputedStyle(document.body).overflow));}
 else console.log('no zoom button found',await p.evaluate(()=>[...document.querySelectorAll('main button')].map(b=>b.textContent.trim().slice(0,20)).slice(0,20)));
 console.log('errs',errs.slice(0,5));await ctx.close();}
// zoom labels all langs + broken images
for(const lang of L.LANGS){const ctx=await L.ctxFor(b,'pc');const p=await ctx.newPage();await p.goto(L.url('/',lang),{waitUntil:'networkidle'});await L.revealAll(p);await p.waitForTimeout(500);
 console.log(lang,await p.evaluate(()=>({zoom:[...new Set([...document.querySelectorAll('main button')].map(b=>b.textContent.trim()||b.getAttribute('aria-label')))].slice(0,8),imgs:document.images.length,broken:[...document.images].filter(i=>i.complete&&i.naturalWidth===0).map(i=>i.src).slice(0,5),noalt:[...document.images].filter(i=>!i.hasAttribute('alt')).length,jaLeft:(lang=>lang==='ja'?0:[...document.querySelectorAll('main *')].filter(e=>e.children.length===0&&/[぀-ヿ]/.test(e.textContent)&&e.offsetParent).map(e=>e.textContent.trim().slice(0,30)).slice(0,8))(document.documentElement.lang),price:[...document.querySelectorAll('main *')].filter(e=>e.children.length===0&&/550|¥|円/.test(e.textContent)).map(e=>e.textContent.trim().slice(0,40))})));await ctx.close();}
await b.close();})();
