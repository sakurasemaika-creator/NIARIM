const L=require('./lib');
const st=p=>p.evaluate(()=>({url:location.pathname+location.search+location.hash,lang:document.documentElement.lang,trig:document.querySelector('[data-current-lang-label]')?.textContent.trim(),exp:document.querySelector('.lang-trigger')?.getAttribute('aria-expanded'),h1:(document.querySelector('main h1')||document.querySelector('h1'))?.textContent.trim().slice(0,30),faq:document.querySelector('header nav a[href*="/faq/"]')?.getAttribute('href'),title:document.title.slice(0,40),desc:document.querySelector('meta[name=description]')?.content.slice(0,30),ls:(()=>{try{return JSON.stringify(Object.assign({},localStorage))}catch(e){return 'ERR'}})()}));
(async()=>{const b=await L.chromium.launch();
for(const loc of ['ja-JP','fr-FR','zh-TW','de-DE','ko-KR','en-US']){const ctx=await L.ctxFor(b,'pc',{locale:loc});const p=await ctx.newPage();await p.goto(L.BASE+'/about/',{waitUntil:'networkidle'});console.log('browser',loc,JSON.stringify(await st(p)));await ctx.close();}
{const ctx=await L.ctxFor(b,'pc',{locale:'en-US'});const p=await ctx.newPage();const errs=L.track(p);
 await p.goto(L.BASE+'/faq/',{waitUntil:'networkidle'});await p.focus('.lang-trigger');await p.keyboard.press('Enter');await p.waitForTimeout(300);
 console.log('opened',JSON.stringify(await st(p)),await p.evaluate(()=>({active:document.activeElement.outerHTML.slice(0,140),opts:[...document.querySelectorAll('[data-lang-menu] *')].filter(e=>e.children.length==0).map(e=>e.textContent.trim()+':'+(e.closest('[role]')?.getAttribute('role'))+':'+(e.closest('[aria-selected],[aria-current],[aria-checked]')?.outerHTML.match(/aria-(selected|current|checked)="[^"]*"/)||[''])[0])})));
 await p.screenshot({path:L.SHOTS+'/w002-pc-menu.png'});
 await p.keyboard.press('ArrowDown');await p.keyboard.press('ArrowDown');console.log('arrow',await p.evaluate(()=>document.activeElement.textContent.trim().slice(0,20)));
 await p.keyboard.press('Escape');await p.waitForTimeout(200);console.log('esc',(await st(p)).exp,await p.evaluate(()=>document.activeElement.className));
 await p.click('.lang-trigger');await p.waitForTimeout(200);await p.mouse.click(600,600);await p.waitForTimeout(200);console.log('outside',(await st(p)).exp);
 // keyboard select fr
 await p.focus('.lang-trigger');await p.keyboard.press('Enter');await p.waitForTimeout(200);
 await p.click('[data-lang-menu] >> text=Français');await p.waitForTimeout(600);console.log('fr',JSON.stringify(await st(p)));
 await p.click('header nav a[href*="/help/"]');await p.waitForLoadState('networkidle');console.log('nav',JSON.stringify(await st(p)));
 await p.goBack();await p.waitForLoadState('networkidle');console.log('back',JSON.stringify(await st(p)));
 await p.goto(L.BASE+'/news/',{waitUntil:'networkidle'});console.log('bare after fr',JSON.stringify(await st(p)));
 await p.goto(L.BASE+'/news/?lang=xx',{waitUntil:'networkidle'});console.log('invalid',JSON.stringify(await st(p)));
 await p.goto(L.BASE+'/features/?lang=ko#save',{waitUntil:'networkidle'});await p.waitForTimeout(500);console.log('ko hash',JSON.stringify(await st(p)),await p.evaluate(()=>Math.round(document.querySelector('#save').getBoundingClientRect().top)));
 await p.click('.lang-trigger');await p.click('[data-lang-menu] >> text=Español');await p.waitForTimeout(800);console.log('switch w/ hash',JSON.stringify(await st(p)));
 await p.click('.lang-trigger');await p.click('[data-lang-menu] >> text=English');await p.waitForTimeout(800);console.log('to en',JSON.stringify(await st(p)));
 await p.click('.lang-trigger');await p.click('[data-lang-menu] >> text=日本語');await p.waitForTimeout(800);console.log('to ja',JSON.stringify(await st(p)));
 console.log('errs',errs);await ctx.close();}
// storage denied
{const ctx=await L.ctxFor(b,'pc',{locale:'es-ES'});await ctx.addInitScript(()=>{Object.defineProperty(window,'localStorage',{get(){throw new Error('denied')}});Object.defineProperty(window,'sessionStorage',{get(){throw new Error('denied')}});});const p=await ctx.newPage();const errs=L.track(p);await p.goto(L.BASE+'/premium/?lang=zh-Hant',{waitUntil:'networkidle'});console.log('storage denied',JSON.stringify(await st(p)),errs);
 await p.click('.lang-trigger');await p.click('[data-lang-menu] >> text=한국어');await p.waitForTimeout(600);console.log('denied switch',JSON.stringify(await st(p)),errs);await ctx.close();}
// font failure
{const ctx=await L.ctxFor(b,'pc');await ctx.route('**/*.woff2',r=>r.abort());const p=await ctx.newPage();await p.goto(L.url('/about/','fr'),{waitUntil:'networkidle'});console.log('fonts blocked',JSON.stringify(await st(p)),'h1 visible',await p.evaluate(()=>{const h=document.querySelector('main h1');const s=getComputedStyle(h);return s.visibility+s.opacity+' '+h.getBoundingClientRect().height}));await p.screenshot({path:L.SHOTS+'/w002-fonts-blocked-fr.png'});await ctx.close();}
// SP dropdown open, each lang
for(const vp of ['sp','s320']){const ctx=await L.ctxFor(b,vp);const p=await ctx.newPage();await p.goto(L.url('/about/','fr'),{waitUntil:'networkidle'});await p.click('.nav-toggle');await p.waitForTimeout(300);await p.locator('.lang-trigger').scrollIntoViewIfNeeded();await p.click('.lang-trigger');await p.waitForTimeout(400);
 console.log(vp,'menu opts in viewport',await p.evaluate(()=>[...document.querySelectorAll('[data-lang-menu] li')].map(li=>{const r=li.getBoundingClientRect();return li.textContent.trim()+':'+Math.round(r.top)+'-'+Math.round(r.bottom)+(r.right>innerWidth||r.left<0?'!X':'')})));await p.screenshot({path:L.SHOTS+`/w002-${vp}-langmenu.png`});
 await p.click('[data-lang-menu] >> text=繁體中文');await p.waitForTimeout(600);console.log(vp,JSON.stringify(await st(p)));await ctx.close();}
await b.close();})();
