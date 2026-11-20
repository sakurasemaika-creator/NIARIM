const L=require('./lib');
(async()=>{const b=await L.chromium.launch();
for(const [path,lang] of [['/','ja'],['/about/','ja'],['/features/','fr'],['/help/','en'],['/contact/','ko']]){
 const ctx=await L.ctxFor(b,'sp');const p=await ctx.newPage();const errs=L.track(p);
 await p.goto(L.url(path,lang),{waitUntil:'networkidle'});
 const tog=p.locator('.nav-toggle').first();
 console.log('==',path,lang,'toggle',await tog.getAttribute('aria-expanded'),await tog.getAttribute('aria-label'));
 await tog.click();await p.waitForTimeout(400);
 console.log('open exp',await tog.getAttribute('aria-expanded'),'bodyOverflow',await p.evaluate(()=>getComputedStyle(document.body).overflow+'/'+getComputedStyle(document.documentElement).overflow));
 if(path==='/'||path==='/features/')await p.screenshot({path:L.SHOTS+`/w001-sp-menu-${lang}${path.replace(/\//g,'_')}.png`});
 // scroll background attempt
 const y0=await p.evaluate(()=>scrollY);await p.mouse.move(180,400);await p.mouse.wheel(0,600);await p.waitForTimeout(300);
 console.log('scroll while open',y0,'->',await p.evaluate(()=>scrollY));
 await tog.focus();const seq=[];
 for(let i=0;i<18;i++){await p.keyboard.press('Tab');seq.push(await p.evaluate(()=>{const a=document.activeElement;const r=a.getBoundingClientRect();return (a.textContent.trim().slice(0,18)||a.getAttribute('aria-label')||a.className)+'@'+Math.round(r.top)+(a.closest('header')?'':'!OUT')}));}
 console.log('tab',seq.join(' > '));
 const back=[];for(let i=0;i<4;i++){await p.keyboard.press('Shift+Tab');back.push(await p.evaluate(()=>{const a=document.activeElement;return (a.textContent.trim().slice(0,18)||a.className)+'@'+Math.round(a.getBoundingClientRect().top)}));}
 console.log('shift-tab',back.join(' > '));
 await p.keyboard.press('Escape');await p.waitForTimeout(300);
 console.log('esc exp',await tog.getAttribute('aria-expanded'),'focus',await p.evaluate(()=>document.activeElement.className));
 // link nav + back
 await tog.click();await p.waitForTimeout(300);
 await p.locator('header nav a[href*="/faq/"]').first().click();await p.waitForLoadState('networkidle');
 console.log('after link',await p.evaluate(()=>location.pathname+location.search+' exp='+document.querySelector('.nav-toggle')?.getAttribute('aria-expanded')+' cur='+[...document.querySelectorAll('header [aria-current]')].map(a=>a.getAttribute('href'))+' y='+scrollY));
 await p.goBack();await p.waitForLoadState('networkidle');await p.waitForTimeout(300);
 console.log('back',await p.evaluate(()=>location.pathname+location.search+' exp='+document.querySelector('.nav-toggle')?.getAttribute('aria-expanded')+' bodyOv='+getComputedStyle(document.body).overflow));
 await p.goForward();await p.waitForLoadState('networkidle');console.log('fwd',await p.evaluate(()=>location.pathname+location.search));
 // sticky
 await p.evaluate(()=>window.scrollTo(0,1500));await p.waitForTimeout(300);console.log('sticky top',await p.evaluate(()=>Math.round(document.querySelector('header').getBoundingClientRect().top)));
 console.log('errs',errs.slice(0,5));await ctx.close();}
// PC keyboard: Tab order & skip link, resize 360->1280->360
{const ctx=await L.ctxFor(b,'pc');const p=await ctx.newPage();await p.goto(L.url('/about/','ja'),{waitUntil:'networkidle'});const seq=[];
 for(let i=0;i<15;i++){await p.keyboard.press('Tab');seq.push(await p.evaluate(()=>{const a=document.activeElement;const s=getComputedStyle(a);return (a.textContent.trim().slice(0,14)||a.className)+'['+s.outlineStyle+s.outlineWidth+']'}));}
 console.log('pc tab',seq.join(' > '));
 await p.goto(L.url('/about/','ja'));await p.keyboard.press('Tab');await p.keyboard.press('Enter');await p.waitForTimeout(300);console.log('skip ->',await p.evaluate(()=>location.hash+' active='+document.activeElement.tagName+'#'+document.activeElement.id));
 await p.setViewportSize({width:360,height:740});await p.waitForTimeout(300);const tog=p.locator('.nav-toggle').first();await tog.click();await p.waitForTimeout(300);await p.setViewportSize({width:1280,height:800});await p.waitForTimeout(400);
 console.log('resize open->pc: bodyOv',await p.evaluate(()=>getComputedStyle(document.body).overflow+' navVisible='+!!document.querySelector('header nav a').offsetParent+' y-scrollable='+(document.documentElement.scrollHeight>innerHeight)));
 await p.mouse.wheel(0,500);await p.waitForTimeout(300);console.log('pc scroll after resize',await p.evaluate(()=>scrollY));
 await ctx.close();}
await b.close();})();
