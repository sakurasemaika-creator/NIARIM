# NIARIM 全面監査領域

このディレクトリはNIARIM全面監査の専用領域です。通常の実装・修正タスクでは、ユーザーが全面監査を明示していない限り、この領域のState/Routeを監査済み判定や作業優先順位の根拠として使用しません。

## 全面監査の正本

### 起動・実行契約
- `docs/work-audit/FULL_AUDIT_ENTRYPOINT.md`
- `docs/work-audit/state/FULL_AUDIT_EXECUTION_STANDARD.md`

### 実行Policy
- `docs/work-audit/policy/ASTRA_WORK.md`
- `docs/work-audit/policy/AUDIT_REMOTE_OPERATIONS.md` — 承認の継続、GitHub/Driveの操作範囲、確認・拒否時の扱い

### 固定Baseline / Delta
- `docs/work-audit/state/AUDIT_ROUTE.md`
- `docs/work-audit/state/AUDIT_DELTA_ROUTE.md`
- `docs/work-audit/state/AUDIT_INVENTORY.json`
- `docs/work-audit/state/AUDIT_ROUTE_LOCK.json`

### 進捗・証拠・整合性
- `docs/work-audit/state/ASTRA_CONTINUATION.md`
- `docs/work-audit/state/ASTRA_AUDIT_STATE.md`
- `docs/work-audit/state/AUDIT_COVERAGE_CHECK.json`
- `docs/work-audit/state/verify_audit_route.py`
- `docs/work-audit/state/verify_audit_delta.py`
- `docs/work-audit/state/verify_full_audit_state.py`

## 横断品質基準

全面監査では、次を必要範囲に応じて必ず併用します。

- `docs/product-audit/QUALITY_STANDARD.md` — 商用品質、Visual、UX、IA、theme、responsive、アクセシビリティ、国際化、受賞水準等
- `docs/product-audit/ENGINEERING_QUALITY_STANDARD.md` — セキュリティ、安定性、保守性、性能、データ整合性等
- `docs/product-audit/HANDS_ON_UI_STANDARD.md` — 全画面・全操作・実操作・実画面目視・Visual evidence
- `docs/product-audit/LEGAL_IP_STANDARD.md` — 著作権、OSS、商標、特許/実用新案、意匠、Privacy、Terms、Consumer law等

## Backend/APIの現行ルート棚卸しと監査チェックリスト

- `docs/work-audit/BACKEND_API_AUDIT_CHECKLIST.md` — 登録時49 HTTPルート、認証/本人境界、ランキング公開状態、フォロー、YouTube・Google、FCM、AdMob SSV、Play課金、DynamoDB・AWS/CI等の追加検証観点。正式Delta `D001.61` / `D021` に紐づく**未実施の監査対象**であり、完了証拠ではない。全面監査開始時には最新App/Web HEADと実API定義を再inventoryする。

## 容量削減画面の追加監査ケース（未実施）

- `docs/work-audit/STORAGE_BAR_UI_DELTA_20261110.md` — 2026-11-10の棒グラフ専用UI・固定明度・端末側+18°配色・明るい色の文字視認性・再取得/失敗・7言語/PC-SP等。正式 `D001.63` / `D001` に紐づく追加チェック。**完了判定や現在の監査IDを変更しない。**

## 補助資料

`docs/AI設計書/**`、機能別verification、security audit、operation capture等は、現在の実装と照合するための仕様・過去証拠・補助資料として使用します。これらの古い記述や過去の結果だけで現在の監査完了を判定してはいけません。

日付付きverification/audit資料は履歴として保持し、現在のdev_branch HEADと矛盾する場合は現在の実装を一次事実として扱い、必要ならDelta/Discoveryへ登録します。

## 原則

1. 全面監査開始時は必ず最新の `dev_branch` を取得し、開始SHAを記録する。
2. Baseline RouteのID・順序・definitionを勝手に変更しない。
3. lock後に追加された画面・状態・操作・機能・品質リスクはDelta/Discoveryへ登録する。
4. 自動テスト、snapshot、DOM/source reviewだけでは実操作PASSにしない。
5. 機能・意図挙動・見た目・継続性・製品品質を独立判定する。
6. 明確な改善余地があれば、根拠を記録したうえで修正→再操作→regressionまで行う。
7. 最終完了は、未完了Baseline/Discovery/Delta、未登録Discovery、advisor-pending、必要証拠がすべて0になってからとする。
