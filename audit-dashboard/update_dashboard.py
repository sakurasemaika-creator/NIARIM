import base64, json, os, urllib.request
from collections import defaultdict
from datetime import datetime, timezone, timedelta

TOKEN=os.environ['GH_TOKEN']; REPO=os.environ['REPO']; ISSUE=os.environ.get('ISSUE_NUMBER','3'); BRANCH=os.environ.get('BRANCH','dev_branch')
API='https://api.github.com'; JST=timezone(timedelta(hours=9), name='JST')

def req(path, method='GET', data=None):
    body=None if data is None else json.dumps(data).encode()
    r=urllib.request.Request(API+path,data=body,method=method)
    r.add_header('Authorization',f'Bearer {TOKEN}'); r.add_header('Accept','application/vnd.github+json'); r.add_header('X-GitHub-Api-Version','2022-11-28')
    if body is not None:r.add_header('Content-Type','application/json')
    with urllib.request.urlopen(r,timeout=30) as x:return json.load(x)

def load_json(path):
    o=req(f'/repos/{REPO}/contents/{path}?ref={BRANCH}')
    return json.loads(base64.b64decode(o['content']).decode())

def esc(v): return str(v or '').replace('|','\\|').replace('\n',' ')
def yes(v): return '✅' if v else '—'
def bar(p):
    n=round(p*20/100); return '█'*n+'░'*(20-n)
def run_state(r):
    if not r:return '—'
    if r.get('status') in ('queued','in_progress','waiting','requested','pending'):return '🟡 実行中'
    c=r.get('conclusion')
    if c=='success':return '🟢 PASS'
    if c in ('failure','timed_out','cancelled','action_required','startup_failure'):return '🔴 要対応'
    return f'⚪ {c or r.get("status") or "不明"}'
def latest_for(runs,paths):
    return next((r for r in runs if any((r.get('path') or '').endswith(p) for p in paths)),None)
def to_jst(iso):
    if not iso:return '—'
    try:
        d=datetime.fromisoformat(iso.replace('Z','+00:00')).astimezone(JST)
        return d.strftime('%Y-%m-%d %H:%M:%S JST')
    except Exception:return str(iso)

manifest=load_json('audit-dashboard/feature-audit-manifest.json')
try: current=load_json('audit-dashboard/current-task.json')
except Exception: current={'status':'unknown','title':'未設定','detail':'','next':'','updated_at_jst':'','next_check_jst':''}
runs=req(f'/repos/{REPO}/actions/runs?branch={BRANCH}&per_page=100').get('workflow_runs',[])
audit_runs=[r for r in runs if r.get('path')!='.github/workflows/audit-live-dashboard.yml']
allf=manifest.get('features',[])
features=[f for f in allf if not (f.get('device_required') and not f.get('final_pass'))]
excluded=len(allf)-len(features); total=len(features)
keys=['interaction','output','screenshot','visual','final_pass']; counts={k:sum(bool(f.get(k)) for f in features) for k in keys}; pct={k:round(counts[k]*100/total) if total else 0 for k in keys}
head=req(f'/repos/{REPO}/branches/{BRANCH}')['commit']['sha']; now=datetime.now(JST).strftime('%Y-%m-%d %H:%M:%S JST')
bycat=defaultdict(list)
for f in features:bycat[f.get('category','その他')].append(f)
active=[r for r in audit_runs if r.get('status') in ('queued','in_progress','waiting','requested','pending')]
latest_activity=to_jst(audit_runs[0].get('updated_at')) if audit_runs else '—'

# 連続監査キューが動いている場合は、その中の現在ジョブ名まで取得する。
queue_run=next((r for r in active if (r.get('path') or '').endswith('audit-continuous-queue.yml')),None)
queue_jobs=[]; queue_current=None; queue_done=[]
if queue_run:
    try:
        queue_jobs=req(f'/repos/{REPO}/actions/runs/{queue_run["id"]}/jobs?per_page=100').get('jobs',[])
        queue_current=next((j for j in queue_jobs if j.get('status') in ('queued','in_progress','waiting','pending')),None)
        queue_done=[j for j in queue_jobs if j.get('status')=='completed']
    except Exception:
        pass

raw_status=current.get('status','unknown')
effective_status='in_progress' if active else ('waiting' if raw_status=='in_progress' else raw_status)
status_icon={'in_progress':'🟡','waiting':'💤','blocked':'🔴','done':'🟢'}.get(effective_status,'⚪')
status_label={'in_progress':'作業中','waiting':'次回自動実行待ち','blocked':'ブロック中','done':'完了'}.get(effective_status,'状態不明')

current_title=current.get('title')
current_detail=current.get('detail')
current_next=current.get('next')
if queue_current:
    current_title=f'連続監査キュー — {queue_current.get("name")}'
    current_detail='GitHub Actions側の連続監査キューが稼働中です。現在ジョブが終了すると、ユーザー確認や1時間待機を挟まず次の監査ジョブへ自動で進みます。'
    following=[j.get('name') for j in queue_jobs if j.get('status')=='queued']
    current_next=(following[0] if following else 'このジョブ終了後に次のneedsジョブへ自動進行')

L=['# NIARIM Audit Live Dashboard','',f'> **更新方式:** 状態変更時に更新  ·  **ダッシュボード最終更新:** `{now}`','',f'**Branch:** `{BRANCH}`  ·  **HEAD:** [`{head[:10]}`](https://github.com/{REPO}/commit/{head})','','## 🔎 現在の作業','']
L += [f'### {status_icon} {status_label} — {esc(current_title)}', '', esc(current_detail), '', f'**次:** {esc(current_next)}', f'**作業内容の最終更新:** `{esc(current.get("updated_at_jst"))}`', f'**直近の監査Action活動:** `{latest_activity}`']
if queue_run:
    L.append(f'**連続監査キュー:** [Run #{queue_run.get("run_number")}]({queue_run.get("html_url")})')
    if queue_current:L.append(f'**現在のキュージョブ:** `{esc(queue_current.get("name"))}` — `{esc(queue_current.get("status"))}`')
    if queue_done:
        passed=sum(1 for j in queue_done if j.get('conclusion')=='success')
        failed=sum(1 for j in queue_done if j.get('conclusion') not in ('success','skipped'))
        L.append(f'**キュー進行:** 完了 {len(queue_done)}/{len(queue_jobs)} ジョブ（PASS {passed} / 要確認 {failed}）')
elif current.get('next_check_jst'):
    L.append(f'**次回自動確認予定:** `{esc(current.get("next_check_jst"))}`')
L.append('')
if active:
    L += ['**現在実行中の監査Action:**']+[f'- 🟡 [{esc(r.get("name") or r.get("display_title"))}]({r.get("html_url")})' for r in active]+['']
else:
    L += ['**現在実行中の監査Action:** なし', '> 現在は処理を計算し続けている状態ではありません。連続監査キューが停止している場合のみ次の自律サイクルで再開します。','']
L += ['## AI監査カバレッジ','',f'`{bar(pct["final_pass"])}` **{pct["final_pass"]}%** — **{counts["final_pass"]} / {total} 機能 最終PASS** · 残り **{total-counts["final_pass"]}**','', '> **strict-v2:** 「PNGがある／差分が出た」だけではPASSにせず、その機能固有の正しさと、必要な場合は設定値に応じた段階変化まで証拠画像＋数値で確認します。','', '| 工程 | 完了 | 進捗 |','|---|---:|---:|']
labels={'interaction':'実操作','output':'実出力/状態確認','screenshot':'スクショ取得','visual':'目視確認','final_pass':'**最終PASS**'}
for k in keys:L.append(f'| {labels[k]} | {counts[k]}/{total} | **{pct[k]}%** |')
L += ['',f'- 実機専用として今回のIssueから除外: **{excluded}項目**','- 連続監査キュー稼働中は、上の「現在のキュージョブ」で何を実行しているか確認できます。','','## 機能別AI監査台帳','', '| カテゴリ | 機能 | 実操作 | 出力 | SS | 目視 | 最終 | 関連Action（参考） |','|---|---|:---:|:---:|:---:|:---:|:---:|---|']
for cat in sorted(bycat):
    for f in bycat[cat]:
        r=latest_for(audit_runs,f.get('workflows') or []) if f.get('workflows') else None
        action=f'[{run_state(r)}]({r.get("html_url")})' if r else '—'
        L.append(f'| {esc(cat)} | {esc(f.get("name"))} | {yes(f.get("interaction"))} | {yes(f.get("output"))} | {yes(f.get("screenshot"))} | {yes(f.get("visual"))} | {"🟢" if f.get("final_pass") else "⚪"} | {action} |')
L += ['','## 直近の監査Actions','', '| 状態 | Workflow | Run |','|---|---|---|']
for r in audit_runs[:12]:L.append(f'| {run_state(r)} | `{esc(r.get("name"))}` | [{esc(r.get("display_title"))}]({r.get("html_url")}) |')
L += ['','---','_実機専用項目は進捗・残件数・100%条件に含みません。ダッシュボード更新用Action自体は常駐させません。_']
req(f'/repos/{REPO}/issues/{ISSUE}',method='PATCH',data={'body':'\n'.join(L)})
print(f'updated {counts["final_pass"]}/{total} at {now}; state={effective_status}; active={len(active)}; queue_job={queue_current.get("name") if queue_current else "none"}')
