const { test } = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(__dirname + '/admob-ssv-verify-shim.cjs', 'utf8');
const { privateKey, publicKey } = crypto.generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
const pem = publicKey.export({ type: 'spki', format: 'pem' }).toString();
const unit = 'ca-app-pub-4380578821900659/6321761453';
const stamp = Date.now();
function query({ custom = null, amount = '10', item = 'coins', unitId = '6321761453', tamper = false } = {}) {
  const data = 'ad_network=12345&ad_unit=' + unitId + '&reward_amount=' + amount +
    '&reward_item=' + item + '&timestamp=' + stamp +
    '&transaction_id=18fa792de1bca816048293fc71035638' +
    (custom === null ? '' : '&custom_data=' + encodeURIComponent(custom));
  const sign = crypto.sign('sha256', Buffer.from(data), privateKey).toString('base64url');
  return data + '&signature=' + (tamper ? 'invalid' : sign) + '&key_id=123';
}
function makeHandler() {
  let calls = 0;
  const old = async () => { calls++; return { statusCode: 403, body: 'ORIGINAL' }; };
  const m = { exports: { handler: old } };
  vm.runInNewContext(source, {
    module: m, require, URLSearchParams, Buffer, AbortSignal, Date,
    process: { env: { ADMOB_REWARDED_AD_UNIT_ID: unit } },
    fetch: async () => ({ ok: true, json: async () => ({ keys: [{ keyId: 123, pem }] }) }),
  });
  return { handler: m.exports.handler, originalCalls: () => calls };
}
function event(rawQueryString, path = '/admob/ssv') {
  return { rawQueryString, rawPath: path, requestContext: { http: { method: 'GET', path } } };
}
test('valid signed unbound URL verification receives 200 without calling original', async () => {
  const x = makeHandler(); const response = await x.handler(event(query()));
  assert.equal(response.statusCode, 200); assert.equal(JSON.parse(response.body).credited, false);
  assert.equal(x.originalCalls(), 0);
});
test('real user-bound callbacks pass to original handler', async () => {
  const x = makeHandler(); const response = await x.handler(event(query({ custom: 'v1.real-user.nonce' })));
  assert.equal(response.statusCode, 403); assert.equal(x.originalCalls(), 1);
});
test('Google-signed URL test with a distinct ad_unit is acknowledged without coins', async () => {
  const x = makeHandler();
  const response = await x.handler(event(query({ unitId: '0000000000' })));
  assert.equal(response.statusCode, 200);
  assert.deepEqual(JSON.parse(response.body), { verified: true, credited: false });
  assert.equal(x.originalCalls(), 0);
});
test('invalid signatures, missing unit, reward, and other endpoints pass to original', async () => {
  for (const q of [query({ tamper: true }), query({ amount: '500' }), query({ item: 'gems' }), query({ unitId: '' })]) {
    const x = makeHandler(); assert.equal((await x.handler(event(q))).statusCode, 403); assert.equal(x.originalCalls(), 1);
  }
  const x = makeHandler(); assert.equal((await x.handler(event(query(), '/me/works'))).statusCode, 403);
  assert.equal(x.originalCalls(), 1);
});
