
// Temporary, metadata-only diagnostics for AdMob's SSV URL verification.
// No raw URLs, query values, user IDs, transaction IDs, keys, signatures, or
// user data are logged. Never grants rewards or modifies HTTP responses.
(function () {
  'use strict';
  const originalHandler = module.exports.handler;
  if (typeof originalHandler !== 'function') {
    throw new Error('NIARIM handler not found');
  }
  module.exports = { ...module.exports, handler: async function niarimSsvDiagnostic(event, context) {
    const path = event && (event.rawPath || event.requestContext?.http?.path);
    const method = event?.requestContext?.http?.method;
    if (path === '/admob/ssv') {
      const raw = event?.rawQueryString;
      const params = new URLSearchParams(typeof raw === 'string' ? raw : '');
      const value = key => params.getAll(key);
      const single = key => value(key).length === 1 ? value(key)[0] : null;
      const ts = Number(single('timestamp'));
      const now = Date.now();
      const lastExpected = (process.env.ADMOB_REWARDED_AD_UNIT_ID || '').split('/')[1] || '';
      const flags = {
        methodGET: method === 'GET',
        rawQueryProvided: typeof raw === 'string',
        hasSignature: value('signature').length === 1,
        hasKeyId: value('key_id').length === 1,
        hasTransaction: value('transaction_id').length === 1,
        hasCustomData: value('custom_data').some(x => x.length > 0),
        hasUserId: value('user_id').some(x => x.length > 0),
        adUnitMatches: !!lastExpected && single('ad_unit') === lastExpected,
        itemCoins: single('reward_item') === 'coins',
        amountTen: single('reward_amount') === '10',
        timestampValid: Number.isSafeInteger(ts) && ts > 1e12,
        timestampWithinHour: Number.isSafeInteger(ts) && ts <= now + 5 * 60_000 &&
          ts >= now - 60 * 60_000,
        keyNames: [...new Set([...params.keys()].filter(x =>
          ['ad_network','ad_unit','custom_data','user_id','reward_amount','reward_item',
           'timestamp','transaction_id','signature','key_id'].includes(x)))].sort(),
      };
      console.info('NIARIM_ADMOB_SSV_SHAPE_V1', JSON.stringify(flags));
    }
    return originalHandler(event, context);
  } };
})();
