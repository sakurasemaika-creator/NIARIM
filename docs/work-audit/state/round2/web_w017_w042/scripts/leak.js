const { chromium } = require('playwright');
const fs=require('fs');
const B='http://127.0.0.1:8802';
const pages=['/', '/about/', '/features/', '/help/', '/premium/', '/coins/', '/community/', '/news/', '/faq/', '/contact/', '/privacy/', '/terms/', '/font-licenses/', '/account-deletion/','/no-such-page'];
(async()=>{
  const b=await chromium.launch(); const res={};
  for(const lang of ['en','fr','es','ko','zh-Hans','zh-Hant']){
    const ctx=await b.newContext({locale:'ja-JP',viewport:{width:1280,height:900},reducedMotion:'reduce'});
    await ctx.route('**/api/community**',r=>r.fulfill({contentType:'application/json',body:'{"works":[]}'}));
    const p=await ctx.newPage();
    for(const path of pages){
      await p.goto(B+path+'?lang='+lang,{waitUntil:path.startsWith('/account')?'load':'networkidle'}); await p.waitForTimeout(400);
      if(path==='/help/'||path==='/faq/') await p.evaluate(()=>document.querySelectorAll('details').forEach(d=>d.open=true));
      const t=await p.evaluate(()=>{const out=[];const tw=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT);let n;while((n=tw.nextNode())){const t=n.nodeValue.trim();if(!t)continue;const e=n.parentElement;if(!e||['SCRIPT','STYLE','NOSCRIPT','TEMPLATE','OPTION'].includes(e.tagName))continue;if(e.closest('#language-menu,.lang-menu,.lang-trigger,[data-lang],[hreflang],.font-license-text,pre'))continue;const r=e.getBoundingClientRect();const s=getComputedStyle(e);const v=r.width>0&&r.height>0&&s.visibility!=='hidden';out.push([t,v,e.tagName.toLowerCase()+'.'+String(e.className).split(' ')[0]+(e.dataset.i18n?'['+e.dataset.i18n+']':'')]);}return out;});
      const kana=/[ぁ-ゖァ-ヺ]/, han=/[一-鿿]/, hang=/[가-힯]/;
      for(const [x,v,sel] of t){ let bad=false; if(kana.test(x))bad=true; if(['en','fr','es'].includes(lang)&&(han.test(x)||hang.test(x)))bad=true; if(lang!=='ko'&&hang.test(x))bad=true;
        if(bad){const k=path+' | '+sel+' | '+x.slice(0,40)+(v?'':' (hidden)'); (res[k]=res[k]||[]).push(lang);} }
    }
    await ctx.close();
  }
  fs.writeFileSync(process.argv[2]+'/leak.json',JSON.stringify(res,null,1));
  for(const [k,v] of Object.entries(res)) console.log(v.length,v.join(','),k);
  await b.close();
})();
