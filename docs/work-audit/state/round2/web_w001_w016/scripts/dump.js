const L=require('./lib');const fs=require('fs');
(async()=>{const b=await L.chromium.launch();const ctx=await L.ctxFor(b,'pc');const p=await ctx.newPage();const sum=[];
for(const path of L.PAGES)for(const lang of L.LANGS){await p.goto(L.url(path,lang),{waitUntil:'networkidle'});await p.waitForTimeout(150);
 // textContent-based to include collapsed content
 const t=await p.evaluate(()=>{const out=[];const w=document.createTreeWalker(document.querySelector('main'),NodeFilter.SHOW_TEXT);let n;while(n=w.nextNode()){const pe=n.parentElement;if(pe.closest('script,style,[hidden],template'))continue;const s=n.textContent.replace(/\s+/g,' ').trim();if(s)out.push(s);}return out.join('\n')});
 const name=(path.replace(/\//g,'')||'home')+'-'+lang;fs.writeFileSync(L.OUT+'/text/'+name+'.txt',t);
 sum.push({name,len:t.length,nakaguro:(t.match(/・/g)||[]).length,kagi:(t.match(/[「」『』]/g)||[]).length,bsn:(t.match(/\\n/g)||[]).length,kana:(t.match(/[぀-ゟァ-ヺ]/g)||[]).length,hangul:(t.match(/[가-힯]/g)||[]).length});}
fs.writeFileSync(L.OUT+'/textsum.json',JSON.stringify(sum));
for(const s of sum){const lang=s.name.split('-').slice(1).join('-');const flag=(lang==='ko'&&s.nakaguro)||(/zh/.test(lang)&&s.nakaguro)||(lang==='zh-Hans'&&s.kagi)||s.bsn||(lang!=='ja'&&s.kana)||(lang!=='ko'&&s.hangul);if(flag)console.log(JSON.stringify(s));}
console.log('done',sum.length);await b.close();})();
