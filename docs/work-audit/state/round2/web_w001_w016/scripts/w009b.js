const L=require('./lib');const fs=require('fs');
(async()=>{const rows=fs.readFileSync(L.OUT+'/w009-route.tsv','utf8').trim().split('\n').map(l=>l.split('\t'));const b=await L.chromium.launch();const ctx=await L.ctxFor(b,'pc');const p=await ctx.newPage();await p.goto(L.url('/help/','ja'),{waitUntil:'networkidle'});
const cards=await p.evaluate(()=>[...document.querySelectorAll('[data-help-card]')].map(c=>({k:c.querySelector('h3').getAttribute('data-i18n').replace(/\.title$/,''),t:c.querySelector('h3').textContent.trim(),cat:c.closest('[data-help-category]').id,len:c.querySelector('p').textContent.length})));
const res=[];for(const [id,title] of rows){let c=cards.find(c=>c.t===title);let note='';if(!c){c=cards.find(c=>c.t.replace(/\s/g,'')===title.replace(/\s/g,''))||cards.find(c=>c.t.includes(title)||title.includes(c.t));note=c?'title differs: '+c.t:'NOT FOUND';}
 let found=null,open=null;if(c){await p.fill('#help-search-input',c.t);await p.waitForTimeout(120);[found,open]=await p.evaluate(t=>{const x=[...document.querySelectorAll('[data-help-card]')].find(x=>x.querySelector('h3').textContent.trim()===t);return [!x.hidden&&x.offsetParent!==null,x.open]},c.t);}
 res.push({id,title,key:c&&c.k,cat:c&&c.cat,len:c&&c.len,found,open,note});}
// per-lang non-empty check for each key
const per={};for(const lang of L.LANGS){await p.goto(L.url('/help/',lang),{waitUntil:'networkidle'});per[lang]=await p.evaluate(()=>Object.fromEntries([...document.querySelectorAll('[data-help-card]')].map(c=>[c.querySelector('h3').getAttribute('data-i18n').replace(/\.title$/,''),[c.querySelector('h3').textContent.trim().length,c.querySelector('p').textContent.trim().length,c.querySelectorAll('a,img,svg').length]])));}
for(const r of res){r.langs=L.LANGS.map(l=>per[l][r.key]?per[l][r.key][0]+'/'+per[l][r.key][1]:'MISSING').join(' ');r.media=r.key?per.ja[r.key][2]:null;}
fs.writeFileSync(L.OUT+'/w009-items.json',JSON.stringify(res,null,1));
console.log('rows',res.length,'bad',res.filter(r=>r.note||!r.found||!r.open||/MISSING| 0\/|\/0/.test(r.langs)).map(r=>r.id+':'+r.title+':'+r.note+':'+r.found));
const routeKeys=new Set(res.map(r=>r.key));console.log('cards not in route:',cards.filter(c=>!routeKeys.has(c.k)).map(c=>c.k+':'+c.t));console.log('media in cards',res.filter(r=>r.media).length);
await b.close();})();
