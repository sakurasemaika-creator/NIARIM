// Static checks over every Web i18n dictionary file: key parity, placeholders, script leftovers.
const fs = require('fs');
const dir = '/tmp/claude-0/-home-user/c76781dd-e3f8-52a1-af75-d04751258bd4/scratchpad/w-run/r2b/public/js/';
const files = fs.readdirSync(dir).filter((f) => /^i18n.*\.js$|^app-help-sync.*\.js$/.test(f));
global.window = { location: { search: '' }, addEventListener() {}, matchMedia: () => ({ matches: false }) };
global.document = { addEventListener() {}, documentElement: { lang: 'ja' }, querySelectorAll: () => [], readyState: 'complete' };
const merged = {};
const perFile = {};
for (const f of files) {
  window.NIARIM_I18N_DICT = {};
  try { eval(fs.readFileSync(dir + f, 'utf8')); } catch (e) { perFile[f] = 'eval error ' + e.message.slice(0, 60); continue; }
  const D = window.NIARIM_I18N_DICT;
  const langs = Object.keys(D);
  if (!langs.length) { perFile[f] = 'no dict'; continue; }
  const keys = new Set(langs.flatMap((l) => Object.keys(D[l] || {})));
  const missing = {};
  for (const l of ['ja', 'en', 'fr', 'es', 'ko', 'zh-Hans', 'zh-Hant']) {
    const m = [...keys].filter((k) => !(D[l] && k in D[l]));
    if (m.length) missing[l] = m.length;
  }
  perFile[f] = { langs: langs.length, keys: keys.size, missing };
  for (const l of langs) { merged[l] = merged[l] || {}; Object.assign(merged[l], D[l]); }
}
console.log(JSON.stringify(perFile, null, 0).replace(/\},"/g, '},\n"'));
const L = ['ja', 'en', 'fr', 'es', 'ko', 'zh-Hans', 'zh-Hant'];
const kana = /[぀-ゟ゠-ヺー-ヿ]/; // excludes ・ (U+30FB)
const ph = (s) => (String(s).match(/%[ds]|\{[a-zA-Z0-9_]+\}|\$\{[^}]+\}/g) || []).sort().join(',');
const out = { kanaLeft: {}, phMismatch: [], emptyVals: {}, enInJa: [] };
for (const k of Object.keys(merged.ja || {})) {
  const base = ph(merged.ja[k]);
  for (const l of L.slice(1)) {
    const v = merged[l] && merged[l][k];
    if (v === undefined) continue;
    if (typeof v === 'string' && kana.test(v.replace(/<[^>]+>/g, '')) && !/^(NIARIM|ニアリム)/.test(v)) (out.kanaLeft[l] = out.kanaLeft[l] || []).push(k + '=' + v.slice(0, 40));
    if (ph(v) !== base) out.phMismatch.push(l + ':' + k + ' ja[' + base + '] ' + l + '[' + ph(v) + ']');
    if (v === '') (out.emptyVals[l] = out.emptyVals[l] || []).push(k);
  }
  const j = String(merged.ja[k]).replace(/<[^>]+>/g, '');
  if (/^[\x20-\x7e]+$/.test(j) && /[a-z]{3,}/i.test(j) && !/NIARIM|https?:|^[A-Z0-9 .\-\/|&]+$/.test(j)) out.enInJa.push(k + '=' + j.slice(0, 40));
}
for (const l of Object.keys(out.kanaLeft)) console.log('kana left in', l, out.kanaLeft[l].length, out.kanaLeft[l].slice(0, 6).join(' | '));
console.log('placeholder mismatches', out.phMismatch.length, out.phMismatch.slice(0, 8).join(' | '));
for (const l of Object.keys(out.emptyVals)) console.log('empty values', l, out.emptyVals[l].join(' '));
console.log('ja values that are English-only words', out.enInJa.length, out.enInJa.slice(0, 25).join(' | '));
