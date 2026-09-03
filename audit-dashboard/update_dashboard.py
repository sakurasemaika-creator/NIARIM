import base64, json, os, re, urllib.request
from collections import defaultdict
from datetime import datetime, timezone, timedelta

TOKEN=os.environ['GH_TOKEN']; REPO=os.environ['REPO']; ISSUE=os.environ.get('ISSUE_NUMBER','3'); BRANCH=os.environ.get('BRANCH','dev_branch')
API='https://api.github.com'; JST=timezone(timedelta(hours=9), name='JST')
RETIRED_WORKFLOWS={
    '.github/workflows/one-shot-close-blockers-and-full-suite.yml',
    '.github/workflows/one-shot-ruler-post-stabilization-fix-v3.yml',
}

def req(path, method='GET', data=None):
    body=None if data is None else json.dumps(data).encode()
    r=urllib.request.Request(API+path,data=body,method=method)
    r.add_header('Authorization',f'Bearer {TOKEN}')
    r.add_header('Accept','application/vnd.github+json')
    r.add_header('X-GitHub-Api-Version','2022-11-28')
    if body is not None:r.add_header('Content-Type','application/json')
    with urllib.request.urlopen(r,timeout=30) as x:return json.load(x)

def load_json(path):
    o=req(f'/repos/{REPO}/contents/{path}?ref={BRANCH}')
    return json.loads(base64.b64decode(o['content']).decode())

def esc(v): return str(v or '').replace('|','\\|').replace('\n',' ')
def yes(v): return '✅' if v else '—'
def exact_bar(done,total): return '█'*done+'░'*(max(total-done,0))
def to_jst(iso):
    if not iso:return '—'
    try:return datetime.fromisoformat(iso.replace('Z','+00:00')).astimezone(JST).strftime('%Y-%m-%d %H:%M:%S JST')
    except Exception:return str(iso)

def current_run_state(r, head):
    if not r:return '—'
    if r.get('status') in ('queued','in_progress','waiting','requested','pending'):return '🟡 実行中'
    c=r.get('conclusion')
    if c=='success':return '🟢 正常終了'
    if c in ('failure','timed_out','cancelled','action_required','startup_failure'):
        if r.get('head_sha') and r.get('head_sha') != head:
            return '⚪ 過去の失敗（現在HEADより前）'
        return '🔴 現在要対応'
    return f'⚪ {c or r.get("status") or "不明"}'

def latest_for(runs,paths):
    return next((r for r in runs if any((r.get('path') or '').endswith(p) for p in paths)),None)

def explain_job(name,total):
    n=name or ''
    if n.startswith('00 '): return ('検出済みの不具合を修正し、同じ失敗が消えたか再確認中','前の監査で見つかった不具合を先に修正しています。修正後は失敗していたテストを同じ条件でもう一度実行し、直ったことを確認できるまで次工程へ進みません。','修正確認が成功したら、機能ごとの見た目の再監査へ進みます。')
    if n.startswith('01 '): return ('以前に監査済みの描画機能を、より厳しい新基準でもう一度確認中','以前は「操作できた」「画像が変化した」ことを中心に確認していましたが、現在はその機能ならではの正しい結果まで、スクリーンショットと数値の両方で確認しています。','この再確認を通過した機能だけを「最終確認済み」として台帳の緑に戻します。')
    if n.startswith('02 '): return ('アプリの各機能を、実際に操作した場合と同じ入力でまとめて確認中','描画・編集・アニメーションなどへ実操作相当の入力を与え、処理が終わるだけでなく出力結果が意図どおりか確認しています。','終わったらCanvas画面の主要パネルを実際に開閉・操作して確認します。')
    if n.startswith('03 '): return ('Canvas画面の主要パネルを実際に開いて、表示と操作結果を確認中','各パネルを実操作相当で開閉し、表示項目・操作後の状態・レイアウトをスクリーンショットでも確認しています。','終わったら全主要画面と全フィルターの見た目を確認します。')
    if n.startswith('04 '): return ('アプリ内の全主要画面と全フィルターの見た目を確認中','画面ごとの表示崩れを確認し、フィルターも「変化した」だけでなく各効果らしい結果になっているか確認しています。','終わったらアプリ全体の自動テストを実行します。')
    if n.startswith('05 '): return ('アプリ全体の自動テストを実行し、見落としている不具合がないか確認中','個別監査だけでは拾えない問題がないか全テストをまとめて実行し、どこまで自動検証できているかも計測しています。ここで失敗した場合は06へ進まず、原因修正と05の再実行が先です。','05がすべて成功した場合だけ、コード解析と全回帰テストへ進みます。')
    if n.startswith('06 '): return ('今回の監査や修正で別の機能を壊していないか、アプリ全体を最終確認中','コード全体を解析し、全テストをもう一度実行して、これまでの修正による副作用や回帰不具合がないか確認しています。','正常終了後も未確認機能が残っていれば、その機能固有の再監査を続けます。')
    if n.startswith('07 '): return ('未確認の機能が残っていないか確認し、残っていれば次の監査をすぐ開始','一連の共通チェック終了後、機能台帳を確認しています。未確認が1件でも残っていれば待機せず次の監査サイクルを起動します。',f'AIで確認可能な全{total}機能が最終確認済みになるまで続けます。')
    return (f'監査処理を実行中 — {n}','現在の監査処理を実行しています。期待どおりでなければ確認済みにせず、原因を修正して再確認します。','終了後は次の未確認項目へ進みます。')

manifest=load_json('audit-dashboard/feature-audit-manifest.json')
try: current=load_json('audit-dashboard/current-task.json')
except Exception: current={'status':'unknown','title':'未設定','detail':'','next':'','updated_at_jst':'','next_check_jst':''}
head=req(f'/repos/{REPO}/branches/{BRANCH}')['commit']['sha']
runs=req(f'/repos/{REPO}/actions/runs?branch={BRANCH}&per_page=100').get('workflow_runs',[])
audit_runs=[r for r in runs if r.get('path')!='.github/workflows/audit-live-dashboard.yml' and r.get('path') not in RETIRED_WORKFLOWS]
allf=manifest.get('features',[])
features=[f for f in allf if not (f.get('device_required') and not f.get('final_pass'))]
excluded=len(allf)-len(features); total=len(features)
keys=['interaction','output','screenshot','visual','final_pass']
counts={k:sum(bool(f.get(k)) for f in features) for k in keys}; pct={k:round(counts[k]*100/total) if total else 0 for k in keys}
remaining_features=[f for f in features if not f.get('final_pass')]
now=datetime.now(JST).strftime('%Y-%m-%d %H:%M:%S JST')
bycat=defaultdict(list)
for f in features:bycat[f.get('category','その他')].append(f)
active=[r for r in audit_runs if r.get('status') in ('queued','in_progress','waiting','requested','pending')]
latest_activity=to_jst(audit_runs[0].get('updated_at')) if audit_runs else '—'
queue_run=next((r for r in active if (r.get('path') or '').endswith('audit-continuous-queue.yml')),None)
queue_jobs=[]; queue_current=None; queue_stage=None
if queue_run:
    try:
        queue_jobs=req(f'/repos/{REPO}/actions/runs/{queue_run["id"]}/jobs?per_page=100').get('jobs',[])
        queue_current=next((j for j in queue_jobs if j.get('status') in ('queued','in_progress','waiting','pending')),None)
        if queue_current:
            m=re.match(r'^(\d+)',queue_current.get('name') or '')
            if m: queue_stage=int(m.group(1))
    except Exception:pass

# 未確認が残っているのに何も動いていない状態を「待機」とは呼ばない。
if active:
    effective_status='in_progress'
elif remaining_features:
    effective_status='blocked'
else:
    effective_status='done'
status_icon={'in_progress':'🟡','blocked':'🔴','done':'🟢'}.get(effective_status,'⚪')
status_label={'in_progress':'作業中','blocked':'監査停止・復旧が必要','done':'完了'}.get(effective_status,'状態不明')
current_title=current.get('title'); current_detail=current.get('detail'); current_next=current.get('next')
if queue_current: current_title,current_detail,current_next=explain_job(queue_current.get('name'),total)
elif effective_status=='blocked':
    current_title='未確認の機能が残っていますが、現在動いている監査処理がありません'
    current_detail='これは正常な待機状態ではありません。連続監査または修復処理を再起動し、残件の確認を続ける必要があります。'
    current_next='停止原因を確認して監査を再開します。'

L=['# NIARIM Audit Live Dashboard','',f'> **更新方式:** 状態変更時に更新  ·  **ダッシュボード最終更新:** `{now}`','',f'**Branch:** `{BRANCH}`  ·  **HEAD:** [`{head[:10]}`](https://github.com/{REPO}/commit/{head})','','## 🔎 現在の作業','',f'### {status_icon} {status_label} — {esc(current_title)}','',esc(current_detail),'',f'**このあと:** {esc(current_next)}',f'**直近の監査Action活動:** `{latest_activity}`']
if queue_run:
    L.append(f'**連続監査の実行状況:** [GitHub Actionsを開く]({queue_run.get("html_url")})')
    if queue_stage is not None:L.append(f'**現在の共通チェック工程:** `{queue_current.get("name")}`')
L.append('')
if active:L += ['**現在実行中の監査処理:**']+[f'- 🟡 [{esc(r.get("name") or r.get("display_title"))}]({r.get("html_url")})' for r in active]+['']
else:L += ['**現在実行中の監査処理:** なし','']

L += ['## AIで確認できる機能の最終確認状況','',f'`{exact_bar(counts["final_pass"],total)}`',f'**{pct["final_pass"]}% — {counts["final_pass"]} / {total} 機能を最終確認済み** · 未確認/再確認中 **{total-counts["final_pass"]}**','',f'> このバーはGitHub Actionsの進捗ではありません。**1マス＝1機能**で、AI/CIで確認可能な{total}機能のうち、必要な実出力・スクリーンショット・見た目・設定値ごとの変化まで確認できた数を表しています。','']
if remaining_features:
    L += ['### 次に最終確認していく機能','共通チェックが終わった後は、未確認/再確認中の機能を順に証拠まで確認して台帳を更新します。','']
    for f in remaining_features[:7]:
        reason=f.get('recheck_reason') or '不足している確認を追加し、機能固有の結果まで確認する'
        L.append(f'- **{esc(f.get("name"))}** — {esc(reason)}')
    L.append('')
L += ['> 以前いったん確認済みになった項目も含めて基準を引き上げて再監査しています。「操作できた」「画像が変化した」だけでは確認済みにせず、その機能に期待される結果になっていることまで確かめています。','', '| 確認工程 | 完了 | 進捗 |','|---|---:|---:|']
labels={'interaction':'実際の操作に相当する入力まで確認','output':'処理結果・出力まで確認','screenshot':'結果画像を取得','visual':'結果画像の見た目まで確認','final_pass':'**必要な確認をすべて終えた機能**'}
for k in keys:L.append(f'| {labels[k]} | {counts[k]}/{total} | **{pct[k]}%** |')
L += ['',f'- 実機でしか確認できないため今回の進捗から除外: **{excluded}項目**','','## 機能別AI監査台帳','', '| カテゴリ | 機能 | 実操作 | 出力 | SS | 目視 | 最終確認 | 関連する自動処理（参考） |','|---|---|:---:|:---:|:---:|:---:|:---:|---|']
for cat in sorted(bycat):
    for f in bycat[cat]:
        r=latest_for(audit_runs,f.get('workflows') or []) if f.get('workflows') else None
        action=f'[{current_run_state(r,head)}]({r.get("html_url")})' if r else '—'
        L.append(f'| {esc(cat)} | {esc(f.get("name"))} | {yes(f.get("interaction"))} | {yes(f.get("output"))} | {yes(f.get("screenshot"))} | {yes(f.get("visual"))} | {"🟢" if f.get("final_pass") else "⚪"} | {action} |')

# 実行履歴はWorkflowごとの最新1件だけ。古い同一Workflowの失敗を現在の要対応に見せない。
latest_by_path=[]; seen=set()
for r in audit_runs:
    p=r.get('path') or r.get('name') or str(r.get('id'))
    if p in seen: continue
    seen.add(p); latest_by_path.append(r)
    if len(latest_by_path)>=12: break
L += ['','## 現在の自動監査・修復処理の状態','', '> 同じWorkflowの古い失敗はここには重ねて表示しません。現在HEADより前の失敗は「過去の失敗」として区別し、**今も解決が必要なものだけ赤い「現在要対応」**になります。','', '| 状態 | 処理名 | 最新実行 |','|---|---|---|']
for r in latest_by_path:
    L.append(f'| {current_run_state(r,head)} | `{esc(r.get("name"))}` | [{esc(r.get("display_title"))}]({r.get("html_url")}) |')
L += ['','---','_実機でしか確認できない項目は、このAI監査の進捗・残件数・100%達成条件には含めていません。_']
req(f'/repos/{REPO}/issues/{ISSUE}',method='PATCH',data={'body':'\n'.join(L)})
print(f'updated final={counts["final_pass"]}/{total}; remaining={len(remaining_features)} at {now}')
