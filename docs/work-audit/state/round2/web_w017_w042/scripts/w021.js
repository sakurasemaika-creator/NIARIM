// Performance sweep on the local Worker: LCP/CLS, transfer sizes, request counts, cache headers,
// with SP emulation (4x CPU slowdown, ~Fast 3G) and reduced motion.
const { chromium } = require('playwright');
const B = 'http://127.0.0.1:8802';
const pages = ['/', '/about/', '/features/', '/help/', '/premium/', '/coins/', '/community/', '/faq/', '/contact/', '/privacy/'];
(async () => {
  const b = await chromium.launch();
  for (const mode of (process.env.MODES||'sp-slow,pc').split(',')) {
    const ctx = await b.newContext({ locale: 'ja-JP', viewport: mode === 'pc' ? { width: 1280, height: 800 } : { width: 360, height: 740 }, deviceScaleFactor: 1 });
    const p = await ctx.newPage();
    await p.route('**/api/community**', (r) => r.fulfill({ status: 200, contentType: 'application/json', body: '{"works":[]}' }));
    const cdp = await ctx.newCDPSession(p);
    if (mode === 'sp-slow') {
      await cdp.send('Emulation.setCPUThrottlingRate', { rate: 4 });
      await cdp.send('Network.enable');
      await cdp.send('Network.emulateNetworkConditions', { offline: false, latency: 150, downloadThroughput: (1.6 * 1024 * 1024) / 8, uploadThroughput: (750 * 1024) / 8 });
    }
    await p.addInitScript(() => {
      window.__lcp = 0; window.__cls = 0; window.__lcpEl = '';
      new PerformanceObserver((l) => { for (const e of l.getEntries()) { window.__lcp = e.startTime; window.__lcpEl = (e.element && (e.element.tagName + '.' + String(e.element.className).slice(0, 30))) || e.url || ''; } }).observe({ type: 'largest-contentful-paint', buffered: true });
      new PerformanceObserver((l) => { for (const e of l.getEntries()) if (!e.hadRecentInput) window.__cls += e.value; }).observe({ type: 'layout-shift', buffered: true });
    });
    for (const path of pages) {
      const t0 = Date.now();
      await p.goto(B + path + (process.env.LG ? '?lang=' + process.env.LG : ''), { waitUntil: 'load', timeout: 90000 });
      const load = Date.now() - t0;
      await p.waitForTimeout(1500);
      // scroll through to trigger reveal and lazy content, then measure CLS
      await p.evaluate(async () => { for (let y = 0; y < document.body.scrollHeight; y += 500) { scrollTo(0, y); await new Promise((r) => setTimeout(r, 60)); } });
      await p.waitForTimeout(500);
      const m = await p.evaluate(() => {
        const res = performance.getEntriesByType('resource');
        const by = {};
        let total = 0;
        for (const r of res) { const t = r.initiatorType; by[t] = (by[t] || 0) + (r.transferSize || r.encodedBodySize || 0); total += r.transferSize || r.encodedBodySize || 0; }
        const nav = performance.getEntriesByType('navigation')[0];
        const fonts = res.filter((r) => /\.woff2/.test(r.name)).map((r) => r.name.split('/').pop() + ':' + Math.round((r.transferSize || r.encodedBodySize) / 1024) + 'k');
        const big = res.filter((r) => (r.transferSize || r.encodedBodySize) > 150000).map((r) => r.name.replace(location.origin, '') + ':' + Math.round((r.transferSize || r.encodedBodySize) / 1024) + 'k');
        return { lcp: Math.round(window.__lcp), lcpEl: window.__lcpEl, cls: +window.__cls.toFixed(3), reqs: res.length, kb: Math.round((total + (nav ? nav.transferSize : 0)) / 1024), scripts: res.filter((r) => r.initiatorType === 'script').length, fonts, big };
      });
      console.log(mode, path, 'load', load + 'ms', JSON.stringify(m));
    }
    await ctx.close();
  }
  await b.close();
})();
