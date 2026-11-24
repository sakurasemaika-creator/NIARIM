import fnmatch, json, re, sys
from pathlib import Path
app = Path(__file__).resolve().parents[4]; web = Path(sys.argv[2]) if len(sys.argv) > 2 else app.parent / 'NIARIM-web'
route = (app/'docs/work-audit/state/AUDIT_ROUTE.md').read_text()
rows = [[x.strip() for x in l.strip('|').split('|')] for l in route.splitlines()
        if re.match(r'^\| [AW]\d{3}(?:\.\d+)? \|', l)]
# App: test file -> lib files it imports
app_tests = {}
for t in sorted((app/'test').rglob('*_test.dart')):
    s = t.read_text(errors='ignore')
    libs = {'lib/' + m for m in re.findall(r"package:niarim/([^'\"]+\.dart)", s)}
    app_tests[str(t.relative_to(app))] = libs
lib_to_tests = {}
for t, libs in app_tests.items():
    for l in libs: lib_to_tests.setdefault(l, set()).add(t)
all_libs = sorted({str(p.relative_to(app)) for p in (app/'lib').rglob('*.dart')})
# Web: test script -> referenced public paths / page names
web_tests = {}
for t in sorted(list((web/'tests').glob('*.mjs')) + list((web/'tests').glob('*.js')) + list((web/'tools').glob('audit*.js'))):
    web_tests[str(t.relative_to(web))] = t.read_text(errors='ignore')
backend_tests = {str(t.relative_to(app)): t.read_text(errors='ignore')
                 for t in sorted((app/'backend/test').glob('*.test.ts'))}


def sources(row):
    return [s.strip() for s in row[6].split(';') if s.strip()]
out = {}
for r in rows:
    rid, prof = r[0], r[5]
    tests = set()
    for src in sources(r):
        if src.startswith('lib/'):
            pats = [src] if '*' not in src else [l for l in all_libs if fnmatch.fnmatch(l, src)]
            for p in pats: tests |= lib_to_tests.get(p, set())
        elif src.startswith('public/'):
            key = src.replace('public/', '').replace('*', '')
            base = key.split('/')[-1] if key.endswith(('.js', '.css')) else key.rstrip('/').replace('index.html', '')
            for t, body in web_tests.items():
                if base and base in body: tests.add('web:' + t)
    if any(x.startswith('backend/') for x in sources(r)):
        m = re.search(r'(GET|POST|PATCH|DELETE|PUT)\s+(/[^\s|]*)', r[1])
        words = [w for w in re.split(r'[^a-z]+', (m.group(2) if m else r[1]).lower()) if len(w) > 3]
        if 'statsupdate' in r[6].lower() or 'push' in r[6].lower():
            words += ['stats', 'push', 'ranking', 'notification']
        for t, body in backend_tests.items():
            name = t.lower()
            if words and any(w in name for w in words):
                tests.add(t)
    if r[5] == 'NATIVE' or 'android/' in r[6]:
        for t in app_tests:
            if any(k in t for k in ['native', 'android', 'platform', 'lifecycle', 'widget_cell', 'home_widget', 'hw_video', 'r8', 'proguard']):
                tests.add(t)
    for src in sources(r):
        if src.startswith(('tests/', 'test/')) and '*' not in src:
            tests.add(('web:' if rid.startswith('W') else '') + src)
    out[rid] = sorted(tests)
json.dump(out, open(sys.argv[1], 'w'), ensure_ascii=False, indent=0)
empty = [k for k, v in out.items() if not v]
print(len(out), 'ids;', len(empty), 'without tests:', empty[:60])
