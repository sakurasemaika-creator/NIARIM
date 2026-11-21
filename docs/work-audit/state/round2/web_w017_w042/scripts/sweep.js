const { chromium } = require('playwright');
const fs = require('fs');
const out = process.argv[2];
const AXE = process.env.SP + '/w-run/axe/node_modules/axe-core/axe.min.js';
const B = 'http://127.0.0.1:8802';
const pages = ['/', '/about/', '/features/', '/help/', '/premium/', '/coins/', '/community/', '/news/', '/faq/', '/contact/', '/privacy/', '/terms/', '/font-licenses/', '/account-deletion/', '/no-such-page'];
const langs = ['', 'ja', 'en', 'fr', 'es', 'ko', 'zh-Hans', 'zh-Hant'];
(async () => {
  const b = await chromium.launch();
  const all = []; const agg = {};
  for (const [w, h, vp] of [[1280, 800, 'pc'], [360, 740, 'sp']]) {
    for (const lang of langs) {
      if (vp==='sp' && lang==='') continue;
      const ctx = await b.newContext({ locale: 'ja-JP', viewport: { width: w, height: h }, reducedMotion: 'reduce', bypassCSP: true });
      await ctx.route('**/api/community**', (r) => r.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ works: [] }) }));
      const p = await ctx.newPage();
      let errs = [], ext = [];
      p.on('console', m => { if (m.type() === 'error') errs.push(m.text().slice(0, 160)); });
      p.on('pageerror', e => errs.push('PAGEERROR ' + String(e).slice(0, 160)));
      p.on('request', r => { if (!r.url().startsWith(B) && !r.url().startsWith('data:')) ext.push(r.url().slice(0,120)); });
      for (const path of pages) {
        errs = []; ext = [];
        const url = B + path + (lang ? '?lang=' + lang : '');
        const raw = await (await ctx.request.get(url)).text().catch(()=> '');
        const rawTitle = (raw.match(/<title>(.*?)<\/title>/s) || [])[1] || '';
        await p.goto(url, { waitUntil: path.startsWith('/account') ? 'load' : 'networkidle' });
        await p.waitForTimeout(path.startsWith('/account') ? 1500 : 300);
        const extra = await p.evaluate(() => {
          const vis = (el) => { const s = getComputedStyle(el); const r = el.getBoundingClientRect(); return s.visibility !== 'hidden' && s.display !== 'none' && r.width > 0 && r.height > 0; };
          const texts = [];
          const tw = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
          let n; while ((n = tw.nextNode())) { const t = n.nodeValue.trim(); if (!t) continue; const pe = n.parentElement; if (!pe || ['SCRIPT','STYLE','NOSCRIPT','TEMPLATE'].includes(pe.tagName)) continue; if (pe.closest('[data-lang-option],[lang],.lang-menu,.language-menu,.lang-switcher,[class*="lang"]')) continue; texts.push({ t, v: vis(pe), sel: pe.tagName.toLowerCase() + (pe.className && typeof pe.className==='string' ? '.' + pe.className.split(' ')[0] : '') + (pe.dataset.i18n ? '[' + pe.dataset.i18n + ']' : '') }); }
          const attrs = [...document.querySelectorAll('[alt],[aria-label],[placeholder],[title]')].flatMap(e => ['alt','aria-label','placeholder','title'].filter(a => e.getAttribute(a)).map(a => ({ t: e.getAttribute(a), v: true, sel: e.tagName.toLowerCase() + '@' + a })));
          const skip = document.querySelector('a[href="#main"]');
          return { texts: texts.concat(attrs), skip: !!skip, main: !!document.querySelector('main#main'), h1: document.querySelectorAll('h1').length, h1t: (document.querySelector('h1')||{}).innerText || ((document.querySelector('h1 img')||{}).alt), lang: document.documentElement.lang, title: document.title, desc: (document.querySelector('meta[name=description]')||{}).content, canon: (document.querySelector('link[rel=canonical]')||{}).href, ovx: document.documentElement.scrollWidth - innerWidth };
        });
        await p.addScriptTag({ path: AXE });
        const res = await p.evaluate(async () => {
          const r = await window.axe.run(document, { runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa', 'best-practice'] }, resultTypes: ['violations'] });
          return r.violations.map((v) => ({ id: v.id, impact: v.impact, n: v.nodes.length, sample: v.nodes.slice(0, 4).map((n) => n.target.join(' ') + ' :: ' + (n.failureSummary || '').split('\n').slice(1, 2).join('').slice(0, 200)) }));
        });
        for (const v of res) { const k = v.id + ' [' + v.impact + ']'; agg[k] = agg[k] || { pages: new Set(), nodes: 0, sample: v.sample }; agg[k].pages.add(vp + ':' + lang + ':' + path); agg[k].nodes += v.n; }
        const L = lang || 'en';
        const kana = /[ぁ-ゖァ-ヺ]/, han = /[一-鿿]/, hang = /[가-힯]/;
        let leaks = [];
        for (const x of extra.texts) {
          let bad = false;
          if (L !== 'ja' && kana.test(x.t)) bad = true;
          if (['en','fr','es'].includes(L) && (han.test(x.t) || hang.test(x.t))) bad = true;
          if (L !== 'ko' && hang.test(x.t)) bad = true;
          if (bad) leaks.push((x.v ? 'V ' : 'h ') + x.sel + ' | ' + x.t.slice(0, 50));
        }
        delete extra.texts;
        all.push({ vp, lang, path, extra, rawTitle, leaks, errs: errs.slice(0,5), ext: [...new Set(ext)].slice(0,8), violations: res });
      }
      await ctx.close();
    }
  }
  fs.writeFileSync(out + '/sweep.json', JSON.stringify(all, null, 1));
  for (const [k, v] of Object.entries(agg).sort((a, b) => b[1].nodes - a[1].nodes)) console.log(k, 'pages', v.pages.size, 'nodes', v.nodes, '| e.g.', [...v.pages].slice(0, 4).join(' '), '\n    ', v.sample.join('\n     '));
  await b.close();
})();
