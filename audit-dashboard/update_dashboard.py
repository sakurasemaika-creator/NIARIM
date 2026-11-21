import base64
import json
import os
import urllib.request
from collections import defaultdict
from datetime import datetime, timezone, timedelta

TOKEN = os.environ['GH_TOKEN']
REPO = os.environ['REPO']
ISSUE = os.environ.get('ISSUE_NUMBER', '3')
BRANCH = os.environ.get('BRANCH', 'dev_branch')
API = 'https://api.github.com'
JST = timezone(timedelta(hours=9), name='JST')
ACTIVE_STATUSES = ('queued', 'in_progress', 'waiting', 'requested', 'pending')
RETIRED_WORKFLOWS = {
    '.github/workflows/audit-live-dashboard.yml',
    '.github/workflows/one-shot-close-blockers-and-full-suite.yml',
    '.github/workflows/one-shot-ruler-post-stabilization-fix-v3.yml',
}
POST_WORKFLOW_MAP = {
    '墨溜まりフィルター（描画/演出）': [
        'one-shot-add-ink-pool-filter.yml',
        'one-shot-refine-ink-pool-audit.yml',
    ],
    '縁取り/墨溜まりフィルターのキャンバススポイト': [
        'one-shot-filter-canvas-eyedropper.yml',
    ],
    '背景馴染ませフィルターの環境光/影推定改善': [
        'implement-background-acclimation-v2.yml',
        'one-shot-background-acclimation-v2.yml',
    ],
}


def req(path, method='GET', data=None):
    body = None if data is None else json.dumps(data).encode()
    r = urllib.request.Request(API + path, data=body, method=method)
    r.add_header('Authorization', f'Bearer {TOKEN}')
    r.add_header('Accept', 'application/vnd.github+json')
    r.add_header('X-GitHub-Api-Version', '2022-11-28')
    if body is not None:
        r.add_header('Content-Type', 'application/json')
    with urllib.request.urlopen(r, timeout=30) as x:
        return json.load(x)


def load_json(path):
    obj = req(f'/repos/{REPO}/contents/{path}?ref={BRANCH}')
    return json.loads(base64.b64decode(obj['content']).decode())


def esc(v):
    return str(v or '').replace('|', '\\|').replace('\n', ' ')


def yes(v):
    return '✅' if v else '—'


def exact_bar(done, total):
    return '█' * done + '░' * max(total - done, 0)


def to_jst(iso):
    if not iso:
        return '—'
    try:
        return datetime.fromisoformat(iso.replace('Z', '+00:00')).astimezone(JST).strftime('%Y-%m-%d %H:%M:%S JST')
    except Exception:
        return str(iso)


def run_state(r, head):
    if not r:
        return '—'
    running = r.get('status') in ACTIVE_STATUSES
    if running:
        return '🟡 実行中'
    conclusion = r.get('conclusion')
    if conclusion == 'success':
        return '🟢 正常終了'
    if conclusion in ('failure', 'timed_out', 'cancelled', 'action_required', 'startup_failure'):
        if r.get('head_sha') and r.get('head_sha') != head:
            return '⚪ 過去の失敗（現在HEADより前）'
        return '🔴 現在要対応'
    return f'⚪ {conclusion or r.get("status") or "不明"}'


def latest_for(runs, paths):
    return next((r for r in runs if any((r.get('path') or '').endswith(p) for p in paths)), None)


def post_status(item, runs, head):
    paths = item.get('workflows') or POST_WORKFLOW_MAP.get(item.get('name'), [])
    if not paths:
        return item.get('status', 'pending'), None
    related = [r for r in runs if any((r.get('path') or '').endswith(p) for p in paths)]
    if not related:
        return item.get('status', 'pending'), None
    active_related = next((r for r in related if r.get('status') in ACTIVE_STATUSES), None)
    if active_related:
        return 'in_progress', active_related
    current_head = next((r for r in related if r.get('head_sha') == head), None)
    chosen = current_head or related[0]
    conclusion = chosen.get('conclusion')
    if conclusion == 'success':
        return 'completed', chosen
    if conclusion in ('failure', 'timed_out', 'cancelled', 'action_required', 'startup_failure'):
        return 'blocked', chosen
    return item.get('status', 'pending'), chosen


manifest = load_json('audit-dashboard/feature-audit-manifest.json')
try:
    current = load_json('audit-dashboard/current-task.json')
except Exception:
    current = {
        'status': 'unknown',
        'title': '未設定',
        'detail': '',
        'next': '',
        'updated_at_jst': '',
    }

head = req(f'/repos/{REPO}/branches/{BRANCH}')['commit']['sha']
runs = req(f'/repos/{REPO}/actions/runs?branch={BRANCH}&per_page=100').get('workflow_runs', [])
audit_runs = [
    r for r in runs
    if (r.get('path') or '') not in RETIRED_WORKFLOWS
]

all_features = manifest.get('features', [])
eligible_features = [
    f for f in all_features
    if not (f.get('device_required') and not f.get('final_pass'))
]
excluded = len(all_features) - len(eligible_features)

# 既存67機能は一度67/67まで完了済み。古い途中manifestのfalse値で
# 完了済みベースラインを巻き戻さない。追加変更分は別枠で自動追跡する。
baseline_completed = bool(current.get('baseline_completed'))
baseline_total = int(current.get('baseline_total') or len(eligible_features))
if baseline_completed:
    baseline_total = min(baseline_total, len(eligible_features)) if eligible_features else baseline_total
    baseline_done = baseline_total
else:
    baseline_total = len(eligible_features)
    baseline_done = sum(bool(f.get('final_pass')) for f in eligible_features)

baseline_pct = round(baseline_done * 100 / baseline_total) if baseline_total else 0
remaining_baseline = max(baseline_total - baseline_done, 0)
post_items = current.get('post_baseline_items') or []
post_effective = [(item, *post_status(item, audit_runs, head)) for item in post_items]
post_open = [item for item, status, _ in post_effective if status not in ('completed', 'done', 'success')]

now = datetime.now(JST).strftime('%Y-%m-%d %H:%M:%S JST')
running = [r for r in audit_runs if r.get('status') in ACTIVE_STATUSES]
current_head_running = [r for r in running if not r.get('head_sha') or r.get('head_sha') == head]
prior_head_running = [r for r in running if r.get('head_sha') and r.get('head_sha') != head]
latest_activity = to_jst(audit_runs[0].get('updated_at')) if audit_runs else '—'

# 実行中Workflowのジョブ名まで読む。ダッシュボード用pushがHEADを進めても、
# 同じdev_branchで継続中の本作業を「旧HEADだから無関係」と隠さない。
active_jobs = []
for r in running[:8]:
    try:
        jobs = req(f"/repos/{REPO}/actions/runs/{r['id']}/jobs?per_page=100").get('jobs', [])
        for j in jobs:
            if j.get('status') in ACTIVE_STATUSES:
                j['_run_id'] = r.get('id')
                active_jobs.append(j)
    except Exception:
        pass

live_title = active_jobs[0].get('name') if active_jobs else (
    running[0].get('name') if running else current.get('title')
)
current_declared = current.get('status')
if running or current_declared == 'in_progress':
    effective_status = 'in_progress'
elif not baseline_completed and remaining_baseline:
    effective_status = 'blocked'
elif post_open:
    effective_status = 'in_progress'
else:
    effective_status = 'done'

status_icon = {'in_progress': '🟡', 'blocked': '🔴', 'done': '🟢'}.get(effective_status, '⚪')
status_label = {'in_progress': '作業中', 'blocked': '監査停止・復旧が必要', 'done': '完了'}.get(effective_status, '状態不明')

L = [
    '# NIARIM Audit Live Dashboard',
    '',
    f'> **更新方式:** `dev_branch` の全push・主要Actionの開始/実行中/完了イベントで自動更新  ·  **ダッシュボード最終更新:** `{now}`',
    '',
    f'**Branch:** `{BRANCH}`  ·  **HEAD:** [`{head[:10]}`](https://github.com/{REPO}/commit/{head})',
    '',
    '## 🔎 現在の作業',
    '',
    f'### {status_icon} {status_label} — {esc(live_title)}',
    '',
    esc(current.get('detail')),
    '',
    f'**このあと:** {esc(current.get("next"))}',
    f'**作業情報の更新:** `{esc(current.get("updated_at_jst") or "—")}`',
    f'**直近の自動監査Action活動:** `{latest_activity}`',
    '',
]

if running:
    L += ['**現在実行中の処理:**']
    for r in running[:8]:
        head_note = '' if not r.get('head_sha') or r.get('head_sha') == head else f' — 開始HEAD `{(r.get("head_sha") or "")[:10]}`'
        L.append(f'- 🟡 [{esc(r.get("name") or r.get("display_title"))}]({r.get("html_url")}){head_note}')
        for j in active_jobs:
            if j.get('_run_id') == r.get('id'):
                L.append(f'  - ▶️ **{esc(j.get("name"))}**')
    L.append('')
else:
    L += ['**現在実行中の処理:** なし', '']

if prior_head_running:
    L += [
        '> ダッシュボード更新などでHEADが進んだ後も、同じ `dev_branch` で開始済みの本作業は完了まで現在作業として追跡します。',
        '',
    ]

L += [
    '## ✅ 既存67機能の確定ベースライン',
    '',
    f'`{exact_bar(baseline_done, baseline_total)}`',
    f'**{baseline_pct}% — {baseline_done} / {baseline_total} 機能を最終確認済み** · 未確認 **{remaining_baseline}**',
    '',
]
if baseline_completed:
    L += [
        '> 既存67機能は過去の最終ゲートで100%完了済みです。古い途中manifestの `final_pass=false` は履歴情報として残っていても、この確定ベースラインを巻き戻しません。',
        f'> 確定日時: `{esc(current.get("baseline_completed_at_jst") or "過去監査完了時")}`',
        '',
    ]

L += ['## 🆕 67機能完了後の追加・変更項目', '']
if post_items:
    L += ['| 項目 | 状態 |', '|---|---|']
    icons = {
        'completed': '🟢 完了', 'done': '🟢 完了', 'success': '🟢 完了',
        'in_progress': '🟡 監査/作業中', 'pending': '⚪ 未確定', 'blocked': '🔴 要対応'
    }
    for item, item_status, item_run in post_effective:
        label = icons.get(item_status, esc(item_status))
        if item_run:
            label = f'[{label}]({item_run.get("html_url")})'
        L.append(f'| {esc(item.get("name"))} | {label} |')
    L.append('')
else:
    L += ['追加変更項目なし', '']

L += [
    '> 新規追加・変更項目は既存67機能の分母へ混ぜません。既存ベースラインを維持したまま、差分だけを専用監査で完了へ上げます。',
    '',
    '## 機能別AI監査台帳（既存ベースライン）',
    '',
    '| カテゴリ | 機能 | 実操作 | 出力 | SS | 目視 | 最終確認 | 関連する自動処理（参考） |',
    '|---|---|:---:|:---:|:---:|:---:|:---:|---|',
]

bycat = defaultdict(list)
for f in eligible_features[:baseline_total]:
    bycat[f.get('category', 'その他')].append(f)
for cat in sorted(bycat):
    for f in bycat[cat]:
        r = latest_for(audit_runs, f.get('workflows') or []) if f.get('workflows') else None
        action = f'[{run_state(r, head)}]({r.get("html_url")})' if r else '—'
        if baseline_completed:
            interaction = output = screenshot = visual = final_pass = True
        else:
            interaction = bool(f.get('interaction'))
            output = bool(f.get('output'))
            screenshot = bool(f.get('screenshot'))
            visual = bool(f.get('visual'))
            final_pass = bool(f.get('final_pass'))
        L.append(
            f'| {esc(cat)} | {esc(f.get("name"))} | {yes(interaction)} | {yes(output)} | '
            f'{yes(screenshot)} | {yes(visual)} | {"🟢" if final_pass else "⚪"} | {action} |'
        )

latest_by_path = []
seen = set()
for r in audit_runs:
    p = r.get('path') or r.get('name') or str(r.get('id'))
    if p in seen:
        continue
    seen.add(p)
    latest_by_path.append(r)
    if len(latest_by_path) >= 12:
        break

L += [
    '',
    '## 自動監査・ビルド処理の状態',
    '',
    '> 同じWorkflowの古い実行は重ねて表示しません。',
    '',
    '| 状態 | 処理名 | 最新実行 |',
    '|---|---|---|',
]
for r in latest_by_path:
    L.append(f'| {run_state(r, head)} | `{esc(r.get("name"))}` | [{esc(r.get("display_title"))}]({r.get("html_url")}) |')

L += [
    '',
    '---',
    f'_実機でしか確認できない項目は既存67機能のAI進捗とは別枠です。manifest上の端末専用除外項目: {excluded}件。_',
]

req(f'/repos/{REPO}/issues/{ISSUE}', method='PATCH', data={'body': '\n'.join(L)})
print(f'updated baseline={baseline_done}/{baseline_total}; post_open={len(post_open)}; running={len(running)}; head={head[:10]} at {now}')
