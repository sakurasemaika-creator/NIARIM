const L=require('./lib');
const work=(i)=>({youtubeVideoId:'abcdefghi'+(10+i),workId:'w'+i,title:i===0?'とても長い作品のタイトルがここに入ります。横幅が狭い端末でどう折り返されるかを確かめるための題名です':i===1?'Été à Paris — 한국어 제목 繁體中文標題 简体中文标题':'作品'+i,channelName:'チャンネル'+i,bookmarkCount:100-i,periodBookmarkCount:10-i,thumbnailUrl:'',youtubeUrl:'https://www.youtube.com/watch?v=test'+i});
(async()=>{const b=await L.chromium.launch();
for(const vp of ['pc','sp']){const ctx=await L.ctxFor(b,vp,{community:JSON.stringify({view:'latest',works:Array.from({length:9},(_,i)=>work(i))})});const p=await ctx.newPage();
 await p.goto(L.url('/community/','ja'),{waitUntil:'networkidle'});await p.waitForTimeout(800);
 // real wheel scroll to the gallery
 for(let i=0;i<12;i++){const t=await p.evaluate(()=>document.querySelector('[data-community-gallery]').getBoundingClientRect().top);if(t<300)break;await p.mouse.move(200,300);await p.mouse.wheel(0,250);await p.waitForTimeout(350);}
 await p.waitForTimeout(1200);
 console.log(vp,await p.evaluate(()=>{const g=document.querySelector('[data-community-gallery]');const chain=[];let e=g.querySelector('a');while(e&&e!==document.body){const s=getComputedStyle(e);chain.push(e.tagName+'.'+String(e.className).slice(0,40)+' op='+s.opacity+' vis='+s.visibility+' disp='+s.display+' h='+Math.round(e.getBoundingClientRect().height));e=e.parentElement;}return chain.slice(0,7)}));
 await p.screenshot({path:L.SHOTS+`/w008-${vp}-ja-cards2.png`});await ctx.close();}
await b.close();})();
