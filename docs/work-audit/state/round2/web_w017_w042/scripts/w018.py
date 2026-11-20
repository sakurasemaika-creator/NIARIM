import re, json, html, urllib.request, collections, sys
B = 'http://127.0.0.1:8802'
ORIG = 'https://niarim-web.niarim.workers.dev'
sm = urllib.request.urlopen(B + '/sitemap.xml').read().decode()
locs = re.findall(r'<loc>([^<]+)</loc>', sm)
print('sitemap urls', len(locs))
rows = []
def get(u):
    r = urllib.request.urlopen(urllib.request.Request(u, headers={'User-Agent': 'audit-crawler'}))
    return r.status, dict(r.headers), r.read().decode('utf-8', 'replace')
kana = re.compile(r'[぀-ヿ]')
cjk = re.compile(r'[぀-ヿ一-鿿가-힯]')
hang = re.compile(r'[가-힯]')
for loc in locs:
    path = loc.replace(ORIG, '')
    st, hd, body = get(B + path)
    m = lambda rx: (re.search(rx, body, re.S) or [None, None])[1]
    title = html.unescape(m(r'<title>(.*?)</title>') or '')
    desc = html.unescape(m(r'<meta name="description" content="([^"]*)"') or '')
    lang = m(r'<html[^>]*\blang="([^"]+)"')
    canon = m(r'<link rel="canonical" href="([^"]+)"')
    hre = re.findall(r'<link rel="alternate" hreflang="([^"]+)" href="([^"]+)"', body)
    ogt = html.unescape(m(r'<meta property="og:title" content="([^"]*)"') or '')
    ogl = m(r'<meta property="og:locale" content="([^"]*)"')
    ogu = m(r'<meta property="og:url" content="([^"]*)"')
    ogi = m(r'<meta property="og:image" content="([^"]*)"')
    tw = m(r'<meta name="twitter:card" content="([^"]*)"')
    jl = re.findall(r'<script type="application/ld\+json">(.*?)</script>', body, re.S)
    jl_ok = True
    for j in jl:
        try: json.loads(j)
        except Exception: jl_ok = False
    h1 = re.sub(r'<[^>]+>', '', m(r'<h1[^>]*>(.*?)</h1>') or '').strip()
    h1alt = m(r'<h1[^>]*>.*?alt="([^"]*)"')
    mainm = re.search(r'<main[^>]*>(.*?)</main>', body, re.S)
    text = re.sub(r'\s+', ' ', html.unescape(re.sub(r'<script.*?</script>|<style.*?</style>|<[^>]+>', ' ', mainm.group(1) if mainm else '', flags=re.S)))
    imgs = re.findall(r'<img\b[^>]*>', body)
    noalt = [i for i in imgs if not re.search(r'\balt="', i)]
    rows.append(dict(cjk_in_main=len(cjk.findall(text)), hang=len(hang.findall(text)), text=text[:300], xdef=[h[1] for h in hre if h[0]=='x-default'], jl_lang=re.findall(r'"inLanguage"\s*:\s*"([^"]+)"', ' '.join(jl)), robots=m(r'<meta name="robots" content="([^"]*)"'), path=path, st=st, title=title, desc=desc, lang=lang, canon=canon, hreflang=len(hre), hre_self=any(h[1] == loc for h in hre), ogt=ogt, ogl=ogl, ogu=ogu, ogi=ogi, tw=tw, jl=len(jl), jl_ok=jl_ok, h1=h1 or ('[img alt]' + (h1alt or '')), kana_in_main=len(kana.findall(text)), mainlen=len(text), noalt=len(noalt)))
json.dump(rows, open(sys.argv[1] + '/w018-rows.json', 'w'), ensure_ascii=False, indent=1)
bad = collections.Counter()
for r in rows:
    nonja = '?lang=' in r['path'] and 'lang=ja' not in r['path']
    issues = []
    if r['st'] != 200: issues.append('status')
    if r['canon'] != ORIG + r['path']: issues.append('canon=' + str(r['canon']))
    if r['hreflang'] != 8: issues.append('hreflang=%d' % r['hreflang'])
    if not r['hre_self']: issues.append('noSelfHreflang')
    if not r['title'] or not r['desc']: issues.append('noTitleDesc')
    if not r['ogt'] or not r['ogi'] or not r['ogu']: issues.append('og')
    if r['ogu'] and r['ogu'] != r['canon']: issues.append('ogurl!=canon')
    if not r['jl_ok']: issues.append('jsonld')
    if r['noalt']: issues.append('imgNoAlt=%d' % r['noalt'])
    if nonja and r['kana_in_main'] > 20: issues.append('jaBody(kana=%d)' % r['kana_in_main'])
    if nonja and kana.search(r['title'] + r['desc']): issues.append('jaTitleDesc')
    lg=(re.search(r'lang=([\w-]+)', r['path']) or [None,'en'])[1]
    if lg in ('en','fr','es') and r['cjk_in_main']>5: issues.append('cjkBody(%d)'%r['cjk_in_main'])
    if lg=='ko' and r['hang']<50: issues.append('noHangul')
    if r['lang']!=lg: issues.append('htmllang=%s'%r['lang'])
    if 'index' not in (r['robots'] or '') or 'noindex' in (r['robots'] or ''): issues.append('robots=%s'%r['robots'])
    for i in issues: bad[i.split('=')[0].split('(')[0]] += 1
    if issues: print(r['path'], r['lang'], '|', ' '.join(issues), '| h1:', r['h1'][:40])
print('issue counts', dict(bad))
titles = collections.Counter(r['title'] for r in rows)
print('duplicate titles', [(t, c) for t, c in titles.items() if c > 1][:8])
descs = collections.Counter(r['desc'] for r in rows)
print('duplicate descs', sum(1 for c in descs.values() if c > 1))
print('langs', collections.Counter(r['lang'] for r in rows))
