#!/usr/bin/env python3
"""Read-only integrity/coverage check for the locked product audit route.

This does not generate, reorder, unlock, or mark audit work done.
Run from either repository. --check-source is a bootstrap snapshot check only;
ordinary resume checks lock integrity without requiring unchanged product code.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys


def digest(value):
    return hashlib.sha256(value if isinstance(value, bytes) else value.encode()).hexdigest()


def check(repo, peer=None, check_source=False):
    state = repo / 'docs/work-audit/state'
    route = (state / 'AUDIT_ROUTE.md').read_text()
    lock = json.loads((state / 'AUDIT_ROUTE_LOCK.json').read_text())
    raw = (state / 'AUDIT_INVENTORY.json').read_bytes()
    inv = json.loads(raw)
    errors = []

    def require(condition, message):
        if not condition:
            errors.append(message)

    entries = []
    for line in route.splitlines():
        if re.match(r'^\| [AW]\d{3}(?:\.\d+)? \|', line):
            fields = [part.strip() for part in line.strip('|').split('|')]
            require(len(fields) == 8, f'Invalid row schema: {fields[0]}')
            if len(fields) == 8:
                entries.append(fields)
    ids = [row[0] for row in entries]
    idset = set(ids)
    require(len(ids) == len(idset), 'Duplicate TODO IDs')
    require(ids == lock['ids'], 'Locked TODO order or membership changed')
    definition = '\n'.join('|'.join(row[:-1]) for row in entries)
    require(digest(definition) == lock['definition_sha256'], 'Locked TODO definitions changed')
    if 'preamble_sha256' in lock:
        require(digest(route.split('\n| A001 |', 1)[0]) == lock['preamble_sha256'], 'Locked profiles/preamble changed')
    require(lock['state'] == 'locked' and '状態: `locked`' in route, 'Route is not locked')
    require(digest(raw) == lock['inventory_sha256'], 'Locked inventory changed')
    require(inv['baseline'] == lock['baseline'], 'Baseline mismatch')

    valid_status = {'todo', 'in_progress', 'blocked', 'done'}
    unfinished = []
    for row in entries:
        require(all(row), f'Empty required TODO field: {row[0]}')
        require(row[-1] in valid_status, f'Unknown status: {row[0]}')
        if row[-1] != 'done':
            unfinished.append(row[0])
        else:
            require(not unfinished, f'Out-of-order done: {row[0]}')
    first = unfinished[0] if unfinished else 'complete'
    progress = (state / 'ASTRA_CONTINUATION.md').read_text()
    found = re.search(r'^current_id:\s*(\S+)', progress, re.M)
    require(found is not None and found[1] == first, f'current_id must equal {first}')
    require(sum(row[-1] in {'in_progress', 'blocked'} for row in entries) <= 1, 'Multiple active IDs')
    for row in entries:
        if row[-1] in {'in_progress', 'blocked'}:
            require(row[0] == first, f'Active ID skips the first unfinished: {row[0]}')

    totals = {}
    for collection in ['source_files', 'source_anchors', 'requirements']:
        unassigned = 0
        for item in inv[collection]:
            refs = item.get('ids', [])
            if not refs:
                unassigned += 1
            require(bool(refs) and set(refs) <= idset,
                    f'Unassigned or invalid {collection}: {item.get("path", item.get("id"))}')
        totals[collection] = len(inv[collection])
        totals['unassigned_' + collection] = unassigned
    requirements = inv['requirements']
    require(len({r['id'] for r in requirements}) == len(requirements), 'Duplicate requirement IDs')
    for item in requirements:
        require(digest(item['text']) == item['sha256'], f'Requirement text/hash differs: {item["id"]}')
        require(item['disposition'] in {'assigned', 'superseded-by-current-user-and-route-policy'}, 'Unexplained requirement disposition')
        if item['disposition'] != 'assigned':
            require(bool(item['note']), 'Superseded requirement needs an explanation')
    for collection in ['app_routes', 'web_routes', 'backend_routes']:
        for item in inv[collection]:
            require(item.get('id') in idset, f'Unassigned {collection}: {item["path"]}')
        totals[collection] = len(inv[collection])

    roots = {repo.name: repo}
    if peer:
        roots[peer.name] = peer
        for filename in ['AUDIT_ROUTE.md', 'AUDIT_ROUTE_LOCK.json', 'AUDIT_INVENTORY.json',
                         'ASTRA_CONTINUATION.md', 'ASTRA_AUDIT_STATE.md', 'verify_audit_route.py']:
            require((state / filename).read_bytes() == (peer / 'docs/work-audit/state' / filename).read_bytes(),
                    f'Mirror differs: {filename}')
    if check_source:
        for item in inv['source_files']:
            root = roots.get(item['repo'])
            require(root is not None, f'Missing snapshot checkout: {item["repo"]}')
            if root:
                file = root / item['path']
                require(file.is_file() and digest(file.read_bytes()) == item['sha256'],
                        f'Source differs from bootstrap: {item["repo"]}/{item["path"]}')
        for name, root in roots.items():
            for req in [r for r in requirements if r['repo'] == name]:
                require(req['text'] in (root / req['path']).read_text(), f'Requirement missing from source: {req["id"]}')
        app = roots.get('NIARIM')
        web = roots.get('NIARIM-web')
        if app:
            actual = set(re.findall(r"path:\s*'([^']+)'", (app / 'lib/router.dart').read_text()))
            require(actual == {r['path'] for r in inv['app_routes']}, 'App route coverage differs')
            actual_api = set(re.findall(r'route\("(GET|POST|PATCH|DELETE|PUT)",\s*"([^"]+)"',
                                        (app / 'backend/src/api/handler.ts').read_text()))
            require(actual_api == {(r['method'], r['path']) for r in inv['backend_routes']}, 'Backend route coverage differs')
        if web:
            pages = {'/' + p.relative_to(web / 'public').as_posix().removesuffix('index.html')
                     for p in (web / 'public').rglob('*.html')}
            require(pages == {r['path'] for r in inv['web_routes']}, 'Web page coverage differs')

    evidence = (state / 'ASTRA_AUDIT_STATE.md').read_text()
    for row in entries:
        if row[-1] == 'done':
            require(re.search(r'^## ' + re.escape(row[0]) + r'\b', evidence, re.M) is not None,
                    f'Done ID lacks an evidence section: {row[0]}')

    result = dict(ok=not errors, scope='structural coverage and lock integrity; not product quality PASS',
                  version=lock['version'], baseline=lock['baseline'], todo_count=len(ids),
                  done_count=sum(row[-1] == 'done' for row in entries), current_id=first,
                  source_snapshot_checked=check_source, mirror_checked=bool(peer),
                  counts=totals, errors=errors)
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--peer', type=Path)
    parser.add_argument('--check-source', action='store_true')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[3]
    output = check(root, args.peer.resolve() if args.peer else None, args.check_source)
    print(json.dumps(output, ensure_ascii=False, indent=2))
    sys.exit(0 if output['ok'] else 1)
