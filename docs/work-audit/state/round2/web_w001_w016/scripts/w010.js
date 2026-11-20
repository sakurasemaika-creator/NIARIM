const L=require('./lib');
(async()=>{const b=await L.chromium.launch();
for(const lang of L.LANGS){const ctx=await L.ctxFor(b,'sp');const p=await ctx.newPage();const errs=L.track(p);await p.goto(L.url('/faq/',lang),{waitUntil:'networkidle'});
 const n=await p.locator('.faq-question').count();let ok=0,cut=0;
 for(let i=0;i<n;i++){const q=p.locator('.faq-question').nth(i);await q.scrollIntoViewIfNeeded();if(i%2){await q.focus();await p.keyboard.press(i%4===1?'Enter':'Space');}else await q.click();await p.waitForTimeout(450);
  const s=await q.evaluate(e=>{const a=document.getElementById(e.getAttribute('aria-controls'));return {exp:e.getAttribute('aria-expanded'),h:a.getBoundingClientRect().height,sh:a.scrollHeight,tag:e.tagName,role:a.getAttribute('role'),ring:getComputedStyle(e).outlineStyle}});if(s.exp==='true'&&s.h>20)ok++;if(s.h<s.sh-2)cut++;}
 const links=await p.evaluate(()=>[...document.querySelectorAll('.faq-answer a, main .btn')].map(a=>a.textContent.trim().slice(0,22)+'→'+a.getAttribute('href')));
 if(lang==='fr'||lang==='ja')await p.screenshot({path:L.SHOTS+`/w010-sp-${lang}-open.png`,fullPage:true});
 // close all
 let closed=0;for(let i=0;i<n;i++){const q=p.locator('.faq-question').nth(i);await q.click();await p.waitForTimeout(350);if(await q.getAttribute('aria-expanded')==='false')closed++;}
 console.log(lang,'q',n,'opened',ok,'cut',cut,'closed',closed,'ovf',await p.evaluate(()=>document.documentElement.scrollWidth-innerWidth),links.join(' | '),errs.slice(0,2));await ctx.close();}
await b.close();})();
