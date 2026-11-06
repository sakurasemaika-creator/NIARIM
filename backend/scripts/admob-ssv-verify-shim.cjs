;
// Targeted compatibility wrapper for the deployed NIARIM Lambda bundle.
// Only Google-signed AdMob URL tests with NO user custom_data are acknowledged.
// All real user callbacks and other API endpoints use the existing handler.
// No DynamoDB operations or coin grants occur inside this wrapper.
(function attachAdmobVerificationCompatibility() {
  'use strict';
  const crypto = require('node:crypto');
  const originalHandler = module.exports.handler;
  if (typeof originalHandler !== 'function') {
    throw new Error('Existing Lambda handler unavailable');
  }
  async function signedUnboundCheck(event) {
    const raw = event && event.rawQueryString;
    if (typeof raw !== 'string' || !raw || raw.length > 4096 || /[\r\n\u0000]/.test(raw)) return false;
    const match = /^(.*)&signature=([A-Za-z0-9_-]+)&key_id=([0-9]+)$/.exec(raw);
    if (!match || !match[1] || match[2].length > 300) return false;
    const params = new URLSearchParams(match[1]);
    const custom = params.getAll('custom_data');
    if (custom.length > 1 || (custom.length === 1 && custom[0])) return false;
    function single(name) {
      const values = params.getAll(name);
      return values.length === 1 && values[0] ? values[0] : null;
    }
    // AdMob's "Verify URL" tool can send a Google-signed test ad_unit
    // different from the registered production unit. This branch never
    // credits a reward and never processes a bound user session; therefore
    // require only a bounded, nonempty ad_unit plus a valid Google signature.
    // The normal reward-granting handler retains strict ad-unit matching.
    const adUnit = single('ad_unit');
    if (!adUnit || adUnit.length > 128 ||
        single('reward_amount') !== '10' || single('reward_item') !== 'coins' ||
        !single('transaction_id')) return false;
    const stamp = single('timestamp');
    if (!/^\d{12,17}$/.test(stamp || '')) return false;
    const timestamp = Number(stamp);
    const now = Date.now();
    if (!Number.isSafeInteger(timestamp) || timestamp > now + 5 * 60_000 ||
        now - timestamp > 60 * 60_000) return false;
    const keyId = Number(match[3]);
    if (!Number.isSafeInteger(keyId)) return false;
    try {
      const response = await fetch('https://www.gstatic.com/admob/reward/verifier-keys.json', {
        signal: AbortSignal.timeout(3000),
        headers: { accept: 'application/json' },
      });
      if (!response.ok) return false;
      const body = await response.json();
      if (!Array.isArray(body.keys) || body.keys.length > 30) return false;
      const key = body.keys.find(item => item.keyId === keyId);
      if (!key || typeof key.pem !== 'string' || key.pem.length > 2000 ||
          !key.pem.startsWith('-----BEGIN PUBLIC KEY-----')) return false;
      const publicKey = crypto.createPublicKey(key.pem);
      if (publicKey.asymmetricKeyType !== 'ec') return false;
      return crypto.verify('sha256', Buffer.from(match[1], 'utf8'), publicKey,
        Buffer.from(match[2], 'base64url'));
    } catch (_) {
      return false;
    }
  }
  // esbuild exports handler via a read-only getter; replace its export object.
  module.exports = { ...module.exports, handler: async function niarimAdmobSsvGuard(event, context) {
    const method = event && event.requestContext && event.requestContext.http && event.requestContext.http.method;
    const path = event && (event.rawPath ||
      (event.requestContext && event.requestContext.http && event.requestContext.http.path));
    if (method === 'GET' && path === '/admob/ssv' && await signedUnboundCheck(event)) {
      return {
        statusCode: 200,
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ verified: true, credited: false }),
      };
    }
    return originalHandler(event, context);
  } };
})();
