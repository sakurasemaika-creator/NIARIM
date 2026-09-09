# NIARIM App＋Web 全面監査State

状態: `reset-for-route-bootstrap`

2026-09-10 JST、ユーザー指示により旧全面監査の部分的な監査マップ、検証済み扱い、未完了順序、復元記録を**新しい全面監査の進捗根拠として破棄**した。

これは製品コード・テスト・通常タスクの成果を削除または巻き戻す操作ではない。既存実装は最新 `dev_branch` に存在するものをそのまま扱う。ただし旧監査Stateに「確認済み」と書かれていたことだけを理由に、新routeのTODOを完了扱いしてはならない。

新しい正本は `docs/work-audit/state/AUDIT_ROUTE.md`。最初の全面監査Workでrouteを一度だけ完全に作成・coverage checkして `locked` にし、その後はID順に完了させる。

本ファイルはroute locked後、各IDの詳細な検証根拠が必要な場合だけ追記する。監査対象の選択や順序は本ファイルではなく `AUDIT_ROUTE.md` を正とする。
