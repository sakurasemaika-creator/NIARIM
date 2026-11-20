const L=require('./lib');const {execFileSync}=require('child_process');
// node strip.js name path lang vp [maxShots] [scale] ; ... groups of 6 separated by ';' not needed: one per call
(async()=>{const [name,path,lang,vp,max,scale,pre]=process.argv.slice(2);const b=await L.chromium.launch();const ctx=await L.ctxFor(b,vp);const p=await ctx.newPage();await p.goto(L.url(path,lang),{waitUntil:'networkidle'});if(pre)await p.evaluate(pre);await p.waitForTimeout(300);
const vh=p.viewportSize().height,vw=p.viewportSize().width;const files=[];let i=0;
while(i<(+max||12)){const f=`${L.SHOTS}/_tmp-${name}-${i}.png`;await p.waitForTimeout(650);await p.screenshot({path:f});files.push(f);const before=await p.evaluate(()=>scrollY);await p.mouse.move(vw/2,vh/2);await p.mouse.wheel(0,vh-90);await p.waitForTimeout(200);const after=await p.evaluate(()=>scrollY);if(after===before)break;i++;}
const s=+scale||0.5;execFileSync('montage',[...files,'-tile',files.length+'x1','-geometry',`${Math.round(vw*s)}x${Math.round(vh*s)}+2+2`,`${L.SHOTS}/${name}.png`]);for(const f of files)require('fs').unlinkSync(f);console.log(name,files.length,'shots');await b.close();})();
