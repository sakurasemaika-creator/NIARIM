const L=require('./lib');
const work=(i)=>({youtubeVideoId:'abcdefghi'+(10+i),workId:'w'+i,title:'作品'+i,channelName:'チャンネル'+i,bookmarkCount:100-i,periodBookmarkCount:10-i,thumbnailUrl:'',youtubeUrl:'https://www.youtube.com/watch?v=test'+i});
const op=p=>p.evaluate(()=>{const g=document.querySelector('[data-community-gallery]');const c=[...g.children];return {n:c.length,kids:c.slice(0,3).map(a=>a.tagName+'.'+String(a.className).slice(0,50)+' op='+getComputedStyle(a).opacity).join(' ; '),text:g.innerText.slice(0,40)}});
(async()=>{const b=await L.chromium.launch();
for(const [label,opts] of [['empty',{}],['empty-reduced',{reducedMotion:'reduce'}],['works-reduced',{reducedMotion:'reduce',community:JSON.stringify({works:Array.from({length:9},(_,i)=>work(i))})}],['works-tab-before-scroll',{community:JSON.stringify({works:Array.from({length:9},(_,i)=>work(i))})}]]){const ctx=await L.ctxFor(b,'sp',opts);const p=await ctx.newPage();
 await p.goto(L.url('/community/','ja'),{waitUntil:'networkidle'});await p.waitForTimeout(600);
 if(label==='works-tab-before-scroll'){await p.evaluate(()=>document.querySelector('[data-community-tab="weekly"]').click());await p.waitForTimeout(500);}
 for(let i=0;i<14;i++){const t=await p.evaluate(()=>document.querySelector('[data-community-tab]').getBoundingClientRect().top);if(t<250)break;await p.mouse.move(200,300);await p.mouse.wheel(0,250);await p.waitForTimeout(300);}
 await p.waitForTimeout(1000);console.log(label,'initial',JSON.stringify(await op(p)));
 if(label!=='works-tab-before-scroll'){await p.click(`[data-community-tab="weekly"]`);await p.waitForTimeout(1500);console.log(label,'after weekly',JSON.stringify(await op(p)));}
 await p.screenshot({path:L.SHOTS+`/w008-sp-${label}.png`});
 await ctx.close();}
await b.close();})();
