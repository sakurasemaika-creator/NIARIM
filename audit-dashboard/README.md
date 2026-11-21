# NIARIM Audit Live Dashboard

監査の最新状況は GitHub Issue #3 に集約しています。

- Dashboard: https://github.com/sakurasemaika-creator/NIARIM/issues/3
- Actions: https://github.com/sakurasemaika-creator/NIARIM/actions?query=branch%3Adev_branch
- Branch: `dev_branch`
- Feature ledger: `audit-dashboard/feature-audit-manifest.json`
- Current work: `audit-dashboard/current-task.json`

`.github/workflows/audit-live-dashboard.yml` は、`audit-dashboard/**` または監査Workflowの変更が `dev_branch` に入ったとき、手動実行時、および対象監査Workflowの開始・完了時に Issue #3 を更新します。

ダッシュボードの進捗値は `feature-audit-manifest.json` から動的に算出します。旧HEADで継続中のActionは現在作業とは分離して参考表示し、現在HEADの処理だけを「実行中」として扱います。
