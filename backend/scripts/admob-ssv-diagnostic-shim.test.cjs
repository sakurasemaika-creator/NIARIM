
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const script=fs.readFileSync(__dirname+'/admob-ssv-diagnostic-shim.cjs','utf8');
test('only whitelisted field names and booleans are logged; response unchanged',async()=>{
  const logs=[];
  const mod={exports:{handler:async()=>({statusCode:403,body:'original'})}};
  const sensitive='PRIVATE-DATA-DO-NOT-LOG';
  vm.runInNewContext(script,{module:mod,URLSearchParams,process:{env:{
    ADMOB_REWARDED_AD_UNIT_ID:'ca-app-pub-4380578821900659/6321761453'}},
    console:{info:(...xs)=>logs.push(xs.join(' '))},Date,Set});
  const ev={rawPath:'/admob/ssv',rawQueryString:'ad_unit=6321761453&reward_amount=10&reward_item=coins&custom_data='+sensitive+'&signature='+sensitive+'&key_id=12',
    requestContext:{http:{path:'/admob/ssv',method:'GET'}}};
  const r=await mod.exports.handler(ev,{});
  assert.equal(r.statusCode,403);assert.equal(logs.length,1);
  assert.ok(logs[0].includes('NIARIM_ADMOB_SSV_SHAPE_V1'));
  assert.ok(!logs[0].includes(sensitive));
  assert.ok(JSON.parse(logs[0].split(' ').slice(1).join(' ')).hasCustomData);
  assert.equal((await mod.exports.handler({...ev,rawPath:'/works/latest'},{})).statusCode,403);
  assert.equal(logs.length,1);
});
