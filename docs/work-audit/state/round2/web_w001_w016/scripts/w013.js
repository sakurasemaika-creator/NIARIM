const L=require('./lib');const T=__dirname+'/tmpfiles/';
const state=p=>p.evaluate(()=>({status:(s=>s.className.includes('is-visible')?s.className.replace('form-status is-visible ','')+':'+s.textContent.replace(/\s+/g,' ').trim():'')(document.getElementById('form-status')),err:[...document.querySelectorAll('.form-error')].filter(e=>e.offsetParent!==null&&e.textContent.trim()).map(e=>e.textContent.trim()),vals:[document.getElementById('type').value,document.getElementById('name').value,document.getElementById('email').value,document.getElementById('message').value,document.getElementById('agree').checked,document.getElementById('attachments').files.length].join('/'),focus:document.activeElement.id||document.activeElement.tagName,btn:document.getElementById('submit-btn').disabled+':'+document.getElementById('submit-btn').textContent.trim(),fields:document.getElementById('contact-fields').disabled}));
(async()=>{const b=await L.chromium.launch();let posts=0,mode='ok',delay=0;
const handler=async r=>{posts++;if(delay)await new Promise(x=>setTimeout(x,delay));const J=(s,b)=>r.fulfill({status:s,contentType:'application/json',body:JSON.stringify(b)});
 switch(mode){case 'ok':return J(200,{ok:true});case '200html':return r.fulfill({status:200,contentType:'text/html',body:'<html>maintenance</html>'});case '200okfalse':return J(200,{ok:false});case '400':return J(400,{error:'invalid_body'});case '403':return J(403,{error:'forbidden_origin'});case '413':return J(413,{error:'payload_too_large'});case '429':return J(429,{error:'rate_limited'});case '500':return J(500,{error:'internal_error',detail:'SECRET stack trace'});case '502':return J(502,{error:'mail_send_failed'});case '500html':return r.fulfill({status:500,contentType:'text/html',body:'<h1>Internal</h1>'});case 'network':return r.abort('failed');case 'hang':return;}};
const ctx=await L.ctxFor(b,'pc',{contact:handler});const p=await ctx.newPage();const pe=L.track(p);
const fillAll=async()=>{await p.selectOption('#type','request');await p.fill('#name','山田 太郎');await p.fill('#email','taro@example.com');await p.fill('#message','本文テスト');await p.check('#agree');await p.setInputFiles('#attachments',[T+'a.png']);};
await p.goto(L.url('/contact/','ja'),{waitUntil:'networkidle'});
for(const m of ['200html','200okfalse','400','403','413','429','500','502','500html','network']){mode=m;posts=0;await p.reload({waitUntil:'networkidle'});await fillAll();await p.click('#submit-btn');await p.waitForTimeout(600);const s=await state(p);console.log(m,'posts',posts,JSON.stringify(s));
 // retry once with ok
 mode='ok';posts=0;await p.click('#submit-btn');await p.waitForTimeout(600);const s2=await state(p);console.log('   retry→ posts',posts,s2.status.slice(0,40),'vals',s2.vals);}
// double click + requestSubmit + pending state + edit during pending
mode='ok';delay=1500;posts=0;await p.reload({waitUntil:'networkidle'});await fillAll();
await p.evaluate(()=>{const b=document.getElementById('submit-btn');b.click();b.click();document.getElementById('contact-form').requestSubmit();});await p.waitForTimeout(300);
const pend=await state(p);console.log('pending',JSON.stringify(pend));
const editable=await p.evaluate(()=>{const m=document.getElementById('message');const before=m.value;m.focus();return {disabled:m.disabled||m.matches(':disabled'),before}});await p.keyboard.type('送信中に書き足し').catch(()=>{});console.log('edit during pending',JSON.stringify(editable),'value now',await p.$eval('#message',m=>m.value));
await p.keyboard.press('Enter');await p.waitForTimeout(1800);console.log('after success posts',posts,JSON.stringify(await state(p)));
// honeypot filled → what the client sends
delay=0;
// timeout with fake clock
{const ctx2=await L.ctxFor(b,'pc',{contact:handler});const p2=await ctx2.newPage();await p2.clock.install();await p2.goto(L.url('/contact/','ja'),{waitUntil:'load'});await p2.clock.runFor(1500);mode='hang';posts=0;
 await p2.selectOption('#type','bug');await p2.fill('#name','A');await p2.fill('#email','a@b.co');await p2.fill('#message','m');await p2.check('#agree');await p2.click('#submit-btn');await p2.clock.runFor(29000);
 const s1=await p2.evaluate(()=>document.getElementById('submit-btn').disabled+' '+document.getElementById('form-status').className);await p2.clock.runFor(2000);await p2.waitForTimeout(300);
 const s2=await p2.evaluate(()=>({btn:document.getElementById('submit-btn').disabled,status:document.getElementById('form-status').textContent.replace(/\s+/g,' ').trim(),vals:document.getElementById('name').value+'/'+document.getElementById('message').value}));console.log('timeout: at29s',s1,'| at31s',JSON.stringify(s2),'posts',posts);
 mode='ok';await p2.click('#submit-btn');await p2.clock.runFor(500);await p2.waitForTimeout(400);console.log('retry after timeout',await p2.evaluate(()=>document.getElementById('form-status').textContent.replace(/\s+/g,' ').trim().slice(0,30)),'posts',posts);await ctx2.close();}
console.log('status attrs',await p.evaluate(()=>{const s=document.getElementById('form-status');return s.getAttribute('role')+'/'+s.getAttribute('aria-live')+'/tabindex='+s.getAttribute('tabindex')}));
console.log('pe',pe.filter(e=>!/^http|status of|view-transition|ERR_FAILED/.test(e)).slice(0,4));
await b.close();})();
