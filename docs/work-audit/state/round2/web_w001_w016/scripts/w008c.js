const L=require('./lib');
const work=(i)=>({youtubeVideoId:'abcdefghi'+(10+i),workId:'w'+i,title:'作品'+i,channelName:'チャンネル'+i,bookmarkCount:100-i,periodBookmarkCount:10-i,thumbnailUrl:'',youtubeUrl:'https://www.youtube.com/watch?v=test'+i});
const op=p=>p.evaluate(()=>{const g=document.querySelector('[data-community-gallery]');const c=[...g.querySelectorAll('a')];const r=g.getBoundingClientRect();return {n:c.length,ops:c.slice(0,4).map(a=>getComputedStyle(a).opacity).join(','),gop:getComputedStyle(g).opacity,gtop:Math.round(r.top),gcls:g.className}});
(async()=>{const b=await L.chromium.launch();
for(const vp of ['pc','sp']){const ctx=await L.ctxFor(b,vp,{community:JSON.stringify({view:'latest',works:Array.from({length:9},(_,i)=>work(i))})});const p=await ctx.newPage();
 await p.goto(L.url('/community/','ja'),{waitUntil:'networkidle'});await p.waitForTimeout(800);
 for(let i=0;i<14;i++){const t=await p.evaluate(()=>document.querySelector('[data-community-tab]').getBoundingClientRect().top);if(t<250)break;await p.mouse.move(200,300);await p.mouse.wheel(0,250);await p.waitForTimeout(300);}
 await p.waitForTimeout(1000);console.log(vp,'initial',JSON.stringify(await op(p)));
 for(const v of ['weekly','overall','latest']){await p.click(`[data-community-tab="${v}"]`);await p.waitForTimeout(1500);console.log(vp,v,JSON.stringify(await op(p)));}
 await p.screenshot({path:L.SHOTS+`/w008-${vp}-ja-after-tab.png`});
 await p.mouse.wheel(0,200);await p.waitForTimeout(1200);console.log(vp,'after small scroll',JSON.stringify(await op(p)));
 await ctx.close();}
await b.close();})();
