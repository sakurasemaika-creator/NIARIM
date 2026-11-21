from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if text.count(old) != 1:
        raise SystemExit(f'{path}: expected 1 match, got {text.count(old)}')
    p.write_text(text.replace(old, new, 1))


p = Path('audit-dashboard/update_dashboard.py')
text = p.read_text()
old = """current_declared = current.get('status')
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
"""
new = """# 「未完タスクがある」と「GitHub上で処理が今走っている」を分離する。
# これによりActionが0件なのに見出しだけ「作業中」となる矛盾をなくす。
if running:
    effective_status = 'in_progress'
elif not baseline_completed and remaining_baseline:
    effective_status = 'blocked'
elif post_open:
    effective_status = 'pending'
else:
    effective_status = 'done'

status_icon = {
    'in_progress': '🟡',
    'pending': '⚪',
    'blocked': '🔴',
    'done': '🟢',
}.get(effective_status, '⚪')
status_label = {
    'in_progress': 'GitHubで実行中',
    'pending': '未完了・次工程待ち',
    'blocked': '監査停止・復旧が必要',
    'done': '完了',
}.get(effective_status, '状態不明')
"""
if text.count(old) != 1:
    raise SystemExit(f'update_dashboard.py: live-state block matches={text.count(old)}')
p.write_text(text.replace(old, new, 1))

# Register current post-baseline workflows so requested/in_progress/completed
# events refresh Issue #3 immediately instead of waiting for another push.
w = Path('.github/workflows/audit-live-dashboard.yml')
text = w.read_text()
needle = "      - 'One-shot Background Acclimation V2'\n"
addition = "      - 'One-shot Background Acclimation V2'\n      - 'One-shot Post-baseline Inspect'\n      - 'One-shot Finalize Post-baseline Features'\n      - 'One-shot Final Post-baseline Gate'\n"
if text.count(needle) != 1:
    raise SystemExit(f'audit-live-dashboard.yml: workflow insertion matches={text.count(needle)}')
w.write_text(text.replace(needle, addition, 1))
