import base64, json, os, re, urllib.request
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
def exact_bar(done,total): return '█'*done+'░'*(max(total-done,0))
def run_state(r):
    if not r:return '—'
    if r.get('status') in ('queued','in_progress','waiting','requested','pending'):return '🟡 実行中'
    c=r.get('conclusion')
    if c=='success':return '🟢 正常終了'
    if c in ('failure','timed_out','cancelled','action_required','startup_failure'):return '🔴 要対応'
    return f'⚪ {c or r.get("status") or "不明"}'
def latest_for(runs,paths): return next((r for r in runs if any((r.get('path') or '').endswith(p) for p in paths)),None)
def to_jst(iso):
    if not iso:return '—'
    try:return datetime.fromisoformat(iso.replace('Z','+00:00')).astimezone(JST).strftime('%Y-%m-%d %H:%M:%S JST')
    except Exception:return str(iso)

def explain_job(name):
    n=name or ''
    if n.startswith('01 '): return ('以前に監査済みの描画機能を、より厳しい新基準でもう一度確認中','以前は「操作できた」「画像が変化した」ことを中心に確認していましたが、現在はそこから一段厳しくし、混色なら色が自然に混ざるか、色伸びなら設定値に応じて引きずる量が変わるか、透視定規なら実際に引いた複数の線が正しい消失点へ収束するか、というように、その機能ならではの正しい結果までスクリーンショットと数値の両方で確認しています。','この再確認を通過した機能だけを「最終確認済み」として台帳の緑に戻し、その後は実操作相当の入力を使った機能監査へ進みます。')
    if n.startswith('02 '): return ('アプリの各機能を、実際に操作した場合と同じ入力でまとめて確認中','描画・編集・アニメーションなどへ実操作相当の入力を与え、単に処理が終了するだけでなく、出力結果やスクリーンショットが意図したものになっているか確認しています。問題が見つかった項目は「確認済み」にはせず、原因を調べて修正・再実行する対象にします。','この確認が終わったら、Canvas画面の主要パネルを実際に開閉・操作して見た目と挙動を確認します。')
    if n.startswith('03 '): return ('Canvas画面の主要パネルを実際に開いて、表示と操作結果を確認中','Canvas上の各パネルや操作UIを実操作相当で開閉し、必要な項目が表示されるか、操作後の状態が意図どおりか、レイアウトが崩れていないかをスクリーンショットでも確認しています。','この確認が終わったら、アプリ内の全主要画面と全フィルターの見た目をまとめて確認します。')
    if n.startswith('04 '): return ('アプリ内の全主要画面と全フィルターの見た目を確認中','各画面を実際に描画してスクリーンショットを取得し、表示崩れがないか確認しています。フィルターも「元画像から変化したからOK」ではなく、それぞれの機能に期待される見た目になっているかまで確認します。','この確認が終わったら、全自動テストを実行して監査漏れや壊れた機能がないか広く確認します。')
    if n.startswith('05 '): return ('アプリ全体の自動テストを実行し、見落としている不具合がないか確認中','個別監査だけでは拾えない問題がないか、アプリ全体のテストをまとめて実行しています。同時に、どのコードまで自動テストで確認できているかも計測します。ここでテストが正常終了しても、それだけで各機能を最終確認済みにはしません。','この確認が終わったら、コード解析と全回帰テストで今回の変更が別の機能を壊していないか最終確認します。')
    if n.startswith('06 '): return ('今回の監査や修正で別の機能を壊していないか、アプリ全体を最終確認中','特定の画面を操作している工程ではありません。コード全体を解析してエラーがないか確認し、さらに全テストをもう一度実行して、これまでの監査・修正による副作用や回帰不具合がないか確認しています。ここが正常終了しても、台帳に未確認項目が残っていれば監査完了ではありません。','終了後は台帳の未確認項目を確認し、残っている機能固有の再監査へすぐ進みます。')
    if n.startswith('07 '): return ('未確認の機能が残っていないか台帳を確認し、残っていれば次の監査をすぐ開始','一連の共通チェックが終わったので、67機能の台帳を確認しています。未確認の機能が1件でも残っていれば待機せず次の監査サイクルを起動します。','未確認項目が残っていれば、そのまま次の連続監査を開始します。')
    return (f'監査処理を実行中 — {n}','現在の監査処理を実行しています。結果が期待どおりでなければ確認済みにはせず、原因を切り分けて修正・再確認します。','終了後は次の未確認項目へ進みます。')

manifest=load_json('audit-dashboard/feature-audit-manifest.json')
try: current=load_json('audit-dashboard/current-task.json')
except Exception: current={'status':'unknown','title':'未設定','detail':'','next':'','updated_at_jst':'','next_check_jst':''}
runs=req(f'/repos/{REPO}/actions/runs?branch={BRANCH}&per_page=100').get('workflow_runs',[])
audit_runs=[r for r in runs if r.get('path')!='.github/workflows/audit-live-dashboard.yml']
allf=manifest.get('features',[])
features=[f for f in allf if not (f.get('device_required') and not f.get('final_pass'))]
excluded=len(allf)-len(features); total=len(features)
keys=['interaction','output','screenshot','visual','final_pass']
counts={k:sum(bool(f.get(k)) for f in features) for k in keys}; pct={k:round(counts[k]*100/total) if total else 0 for k in keys}
remaining_features=[f for f in features if not f.get('final_pass')]
head=req(f'/repos/{REPO}/branches/{BRANCH}')['commit']['sha']; now=datetime.now(JST).strftime('%Y-%m-%d %H:%M:%S JST')
bycat=defaultdict(list)
for f in features:bycat[f.get('category','その他')].append(f)
active=[r for r in audit_runs if r.get('status') in ('queued','in_progress','waiting','requested','pending')]
latest_activity=to_jst(audit_runs[0].get('updated_at')) if audit_runs else '—'
queue_run=next((r for r in active if (r.get('path') or '').endswith('audit-continuous-queue.yml')),None)
queue_jobs=[]; queue_current=None; queue_done=[]; queue_stage=None
if queue_run:
    try:
        queue_jobs=req(f'/repos/{REPO}/actions/runs/{queue_run["id"]}/jobs?per_page=100').get('jobs',[])
        queue_current=next((j for j in queue_jobs if j.get('status') in ('queued','in_progress','waiting','pending')),None)
        queue_done=[j for j in queue_jobs if j.get('status')=='completed']
        if queue_current:
            m=re.match(r'^(\d+)',queue_current.get('name') or '')
            if m: queue_stage=int(m.group(1))
    except Exception:pass
raw_status=current.get('status','unknown'); effective_status='in_progress' if active else ('waiting' if raw_status=='in_progress' else raw_status)
status_icon={'in_progress':'🟡','waiting':'💤','blocked':'🔴','done':'🟢'}.get(effective_status,'⚪'); status_label={'in_progress':'作業中','waiting':'次回自動実行待ち','blocked':'ブロック中','done':'完了'}.get(effective_status,'状態不明')
current_title=current.get('title'); current_detail=current.get('detail'); current_next=current.get('next')
if queue_current: current_title,current_detail,current_next=explain_job(queue_current.get('name'))

L=['# NIARIM Audit Live Dashboard','',f'> **更新方式:** 状態変更時に更新  ·  **ダッシュボード最終更新:** `{now}`','',f'**Branch:** `{BRANCH}`  ·  **HEAD:** [`{head[:10]}`](https://github.com/{REPO}/commit/{head})','','## 🔎 現在の作業','',f'### {status_icon} {status_label} — {esc(current_title)}','',esc(current_detail),'',f'**このあと:** {esc(current_next)}',f'**直近の監査Action活動:** `{latest_activity}`']
if queue_run:
    L.append(f'**連続監査の実行状況:** [GitHub Actionsを開く]({queue_run.get("html_url")})')
    if queue_stage:L.append(f'**現在の共通チェック工程:** **{queue_stage} / 7**')
    if queue_current:L.append(f'> 内部識別名: `{esc(queue_current.get("name"))}`')
elif current.get('next_check_jst'):L.append(f'**次回自動確認予定:** `{esc(current.get("next_check_jst"))}`')
L.append('')
if active:L += ['**現在実行中の監査処理:**']+[f'- 🟡 [{esc(r.get("name") or r.get("display_title"))}]({r.get("html_url")})' for r in active]+['']
else:L += ['**現在実行中の監査処理:** なし','> 未確認項目が残っているのに連続監査が停止している場合は異常です。次の自律確認で再開対象になります。','']

L += ['## AIで確認できる機能の最終確認状況','',f'`{exact_bar(counts["final_pass"],total)}`',f'**{pct["final_pass"]}% — {counts["final_pass"]} / {total} 機能を最終確認済み** · 未確認/再確認中 **{total-counts["final_pass"]}**','', '> このバーは「今走っているGitHub Actionsが何%進んだか」ではありません。**1マス＝1機能**で、67機能のうち新しい厳格な基準で最終確認まで終えた数を表しています。共通テストが正常終了しただけでは増えず、各機能について必要な実出力・スクリーンショット・見た目・設定値ごとの変化まで確認できた時にだけ増えます。','']
if queue_stage:
    L += ['### 今回の連続監査そのものの進み具合',f'現在は **7工程中 {queue_stage} 番目**です。これは上の「34/67機能」とは別の進捗です。','']
if remaining_features:
    L += ['### 次に最終確認していく機能','共通チェックが終わった後は、未確認/再確認中の機能を順に証拠まで確認して台帳を更新します。現在の先頭候補は次のとおりです。','']
    for f in remaining_features[:7]:
        reason=f.get('recheck_reason') or '不足している確認を追加し、機能固有の結果まで確認する'
        L.append(f'- **{esc(f.get("name"))}** — {esc(reason)}')
    L.append('')
L += ['> 現在は、以前いったん確認済みになった項目も含めて基準を引き上げて再監査しています。「操作できた」「画像が変化した」だけでは確認済みにせず、その機能に期待される結果になっていることを実出力・スクリーンショット・数値で確かめ、必要な設定項目は値を何段階か変えて効果も正しく変化するところまで確認できた機能だけを最終確認済みとしています。','', '| 確認工程 | 完了 | 進捗 |','|---|---:|---:|']
labels={'interaction':'実際の操作に相当する入力まで確認','output':'処理結果・出力まで確認','screenshot':'結果画像を取得','visual':'結果画像の見た目まで確認','final_pass':'**必要な確認をすべて終えた機能**'}
for k in keys:L.append(f'| {labels[k]} | {counts[k]}/{total} | **{pct[k]}%** |')
L += ['',f'- 実機でしか確認できないため今回の進捗から除外: **{excluded}項目**','','## 機能別AI監査台帳','', '| カテゴリ | 機能 | 実操作 | 出力 | SS | 目視 | 最終確認 | 関連する自動処理（参考） |','|---|---|:---:|:---:|:---:|:---:|:---:|---|']
for cat in sorted(bycat):
    for f in bycat[cat]:
        r=latest_for(audit_runs,f.get('workflows') or []) if f.get('workflows') else None
        action=f'[{run_state(r)}]({r.get("html_url")})' if r else '—'
        L.append(f'| {esc(cat)} | {esc(f.get("name"))} | {yes(f.get("interaction"))} | {yes(f.get("output"))} | {yes(f.get("screenshot"))} | {yes(f.get("visual"))} | {"🟢" if f.get("final_pass") else "⚪"} | {action} |')
L += ['','## 直近の自動監査処理','', '| 状態 | 処理名 | 実行結果 |','|---|---|---|']
for r in audit_runs[:12]:L.append(f'| {run_state(r)} | `{esc(r.get("name"))}` | [{esc(r.get("display_title"))}]({r.get("html_url")}) |')
L += ['','---','_実機でしか確認できない項目は、このAI監査の進捗・残件数・100%達成条件には含めていません。_']
req(f'/repos/{REPO}/issues/{ISSUE}',method='PATCH',data={'body':'\n'.join(L)})
print(f'updated final={counts["final_pass"]}/{total}; queue_stage={queue_stage}; remaining={len(remaining_features)} at {now}')
