const { chromium } = require('playwright');
const fs=require('fs');
const B='http://127.0.0.1:8802';
const pages=['/', '/about/', '/features/', '/help/', '/premium/', '/coins/', '/community/', '/news/', '/faq/', '/contact/', '/privacy/', '/terms/', '/font-licenses/', '/account-deletion/','/no-such-page'];
const langs=(process.env.LANGS||'ja,en,fr,es,ko,zh-Hans,zh-Hant').split(',');
(async()=>{
  const b=await chromium.launch();
  const res={};
  for(const lang of langs){
    const ctx=await b.newContext({locale:'ja-JP',viewport:{width:1280,height:900},reducedMotion:'reduce'});
    await ctx.route('**/api/community**',r=>r.fulfill({contentType:'application/json',body:'{"works":[]}'}));
    const p=await ctx.newPage(); const cdp=await ctx.newCDPSession(p);
    for(const path of pages){
      await p.goto(B+path+'?lang='+lang,{waitUntil:path.startsWith('/account')?'load':'networkidle'});
      await p.evaluate(()=>document.fonts.ready); await p.waitForTimeout(400);
      await p.evaluate(()=>{let i=0;const tw=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT);let n;const seen=new Set();while((n=tw.nextNode())){if(!n.nodeValue.trim())continue;const e=n.parentElement;if(!e||seen.has(e)||['SCRIPT','STYLE','NOSCRIPT'].includes(e.tagName))continue;const r=e.getBoundingClientRect();if(r.width===0||r.height===0)continue;seen.add(e);e.setAttribute('data-fa',String(i++));}});
      await cdp.send('DOM.enable'); await cdp.send('CSS.enable');
      const {root}=await cdp.send('DOM.getDocument',{depth:0});
      const {nodeIds}=await cdp.send('DOM.querySelectorAll',{nodeId:root.nodeId,selector:'[data-fa]'});
      for(const id of nodeIds){
        let f; try{f=await cdp.send('CSS.getPlatformFontsForNode',{nodeId:id});}catch(e){continue;}
        for(const x of f.fonts){ if(x.isCustomFont) continue;
          const k=lang+'|'+x.familyName; res[k]=res[k]||{glyphs:0,ex:[]}; res[k].glyphs+=x.glyphCount;
          if(res[k].ex.length<12){const t=await p.evaluate(i=>{const e=document.querySelector('[data-fa="'+i+'"]');return [...e.childNodes].filter(n=>n.nodeType===3).map(n=>n.nodeValue.trim()).join(' ').slice(0,60)+' <'+e.tagName+'.'+String(e.className).slice(0,30)+'>';}, (await cdp.send('DOM.getAttributes',{nodeId:id})).attributes.reduce((a,v,i,arr)=>arr[i-1]==='data-fa'?v:a,null)); res[k].ex.push(path+' :: '+t+' x'+x.glyphCount);}
        }
      }
    }
    await ctx.close();
  }
  fs.writeFileSync(process.argv[2]+'/fonts.json',JSON.stringify(res,null,1));
  for(const [k,v] of Object.entries(res)) console.log(k,v.glyphs);
  await b.close();
})();
