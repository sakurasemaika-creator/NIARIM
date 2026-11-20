const L=require('./lib');const fs=require('fs');
(async()=>{const b=await L.chromium.launch();const out=[];
for(const vp of ['pc','sp','s320']){const ctx=await L.ctxFor(b,vp);const p=await ctx.newPage();const errs=L.track(p);
 for(const lang of L.LANGS)for(const path of L.PAGES){errs.length=0;const r=await p.goto(L.url(path,lang),{waitUntil:'networkidle'});await p.waitForTimeout(150);
  const info=await p.evaluate(()=>{const vis=e=>{const r=e.getBoundingClientRect();const s=getComputedStyle(e);return r.width>0&&r.height>0&&s.visibility!=='hidden'&&s.display!=='none'};
   const hdr=document.querySelector('header');const navLinks=[...document.querySelectorAll('header nav a[href], header a.btn, header a[class*=download]')].filter(vis);
   const wrap=navLinks.map(a=>{const lh=parseFloat(getComputedStyle(a).lineHeight)||20;const rg=document.createRange();rg.selectNodeContents(a);const rects=[...rg.getClientRects()].filter(r=>r.width>1);const tops=[...new Set(rects.map(r=>Math.round(r.top/4)))];return {t:a.textContent.trim().slice(0,30),lines:tops.length,out:(()=>{const r=a.getBoundingClientRect();const h=hdr.getBoundingClientRect();return r.top<h.top-1||r.bottom>h.bottom+1||r.right>innerWidth+1})()}});
   return {lang:document.documentElement.lang,hdr:!!hdr,hdrPos:hdr&&getComputedStyle(hdr).position,hdrH:hdr&&Math.round(hdr.getBoundingClientRect().height),ftr:!!document.querySelector('footer'),nav:navLinks.length,fl:document.querySelectorAll('footer a[href]').length,cur:[...document.querySelectorAll('header [aria-current]')].map(a=>a.getAttribute('href')),wrapBad:wrap.filter(w=>w.lines>1||w.out),toggleVis:(()=>{const t=document.querySelector('.nav-toggle,header button[aria-expanded][aria-controls]');return t?vis(t):null})(),overflowX:document.documentElement.scrollWidth-innerWidth,mainjs:[...document.scripts].map(s=>s.src).filter(s=>/main\.js|common-ui/.test(s)).map(s=>s.split('/').pop())}});
  out.push({vp,lang,path,code:r.status(),...info,errs:[...errs]});}
 await ctx.close();}
fs.writeFileSync(L.OUT+'/w001.json',JSON.stringify(out));
const bad=out.filter(o=>o.code!==200||!o.hdr||!o.ftr||o.overflowX>1||o.errs.length||o.wrapBad.length||o.lang!==o.lang);
console.log('total',out.length,'bad',bad.length);for(const o of bad.slice(0,60))console.log(o.vp,o.lang,o.path,o.code,'ovf',o.overflowX,JSON.stringify(o.wrapBad).slice(0,200),o.errs.slice(0,3));
const s=o=>`${o.vp} ${o.lang} ${o.path} lang=${o.lang} nav=${o.nav} fl=${o.fl} cur=${o.cur} hdr=${o.hdrPos}/${o.hdrH} tog=${o.toggleVis} ${o.mainjs}`;
console.log(out.filter(o=>o.lang==='ja'&&o.vp!=='s320').map(s).join('\n'));
await b.close();})();
