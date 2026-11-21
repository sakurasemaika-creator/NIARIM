const L=require('./lib');const fs=require('fs');
const IDS=['drawing','animation','editing','advanced','audio','save','workspace','widget','export'];
(async()=>{const b=await L.chromium.launch();
for(const vp of ['pc','sp','s320']){const ctx=await L.ctxFor(b,vp);const p=await ctx.newPage();const errs=L.track(p);const r=[];
 for(const id of IDS){await p.goto('about:blank');await p.goto(L.url('/features/#'+id,vp==='s320'?'fr':'ja'),{waitUntil:'networkidle'});await p.waitForTimeout(900);
  r.push(await p.evaluate(id=>{const s=document.getElementById(id);const hd=s.querySelector('.feature-section-head, h2')||s;const hdr=document.querySelector('header').getBoundingClientRect().bottom;const st=document.querySelector('.feature-nav');const stb=st?st.getBoundingClientRect():null;const t=hd.getBoundingClientRect().top;const h2=s.querySelector('h2');return id+':sec='+Math.round(s.getBoundingClientRect().top)+' head='+Math.round(t)+' h2='+(h2?Math.round(h2.getBoundingClientRect().top):'-')+' hdrBottom='+Math.round(hdr)+(stb?' nav='+Math.round(stb.top)+'-'+Math.round(stb.bottom)+'/'+getComputedStyle(st).position:'')},id));
  if(id==='save')await p.screenshot({path:L.SHOTS+`/w006-${vp}-hash-save.png`});}
 console.log(vp,r.join('\n   '),errs.slice(0,3));await ctx.close();}
// click + keyboard + back
{const ctx=await L.ctxFor(b,'pc');const p=await ctx.newPage();await p.goto(L.url('/features/','ja'),{waitUntil:'networkidle'});
 const links=await p.evaluate(()=>[...document.querySelectorAll('main a[href*="#"]')].map(a=>a.textContent.trim().slice(0,16)+'→'+a.getAttribute('href')));console.log('anchors',links.join(' | '));
 const y0=600;await p.evaluate(y=>window.scrollTo(0,y),y0);await p.waitForTimeout(300);
 const a=p.locator('main a[href$="#audio"]').first();await a.focus();await p.keyboard.press('Enter');await p.waitForTimeout(1200);
 console.log('kbd enter →',await p.evaluate(()=>location.hash+' y='+Math.round(scrollY)+' h2top='+Math.round(document.querySelector('#audio h2').getBoundingClientRect().top)+' active='+document.activeElement.tagName+'.'+document.activeElement.className));
 await p.keyboard.press('Tab');console.log('next tab focus',await p.evaluate(()=>{const a=document.activeElement;return a.textContent.trim().slice(0,20)+' in#'+(a.closest('section[id]')||{}).id+' top='+Math.round(a.getBoundingClientRect().top)}));
 await p.goBack();await p.waitForTimeout(900);console.log('back',await p.evaluate(()=>location.hash+' y='+Math.round(scrollY)));
 await p.goForward();await p.waitForTimeout(900);console.log('fwd',await p.evaluate(()=>location.hash+' y='+Math.round(scrollY)));
 for(const id of IDS){const s=await p.evaluate(id=>{const out=[];const w=document.createTreeWalker(document.getElementById(id),NodeFilter.SHOW_TEXT);let n;while(n=w.nextNode()){if(n.parentElement.closest('script,style,[hidden]'))continue;const t=n.textContent.replace(/\s+/g,' ').trim();if(t)out.push((n.parentElement.closest('[aria-hidden=true],svg')?'[mock] ':'')+t);}return out.join('\n')},id);fs.writeFileSync(L.OUT+'/text/features-'+id+'-ja.txt',s);}
 await ctx.close();}
// per-lang section item counts
for(const lang of L.LANGS){const ctx=await L.ctxFor(b,'pc');const p=await ctx.newPage();await p.goto(L.url('/features/',lang),{waitUntil:'networkidle'});
 console.log(lang,await p.evaluate(IDS=>IDS.map(id=>{const s=document.getElementById(id);return id+':'+s.querySelectorAll('h3,h4').length+'/'+s.innerText.length}).join(' '),IDS));await ctx.close();}
await b.close();})();
