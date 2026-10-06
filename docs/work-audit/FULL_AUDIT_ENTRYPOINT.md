# NIARIM 全面監査 — 開始入口

## 起動トリガー

ユーザーが「NIARIMの全面監査をしてください」「NIARIMを全面監査して」「前回のNIARIM全面監査を再開してください」等、製品全体を対象とする依頼を明示した場合、追加質問なしで全面監査モードへ入る。

## 開始時に必ず読む正本

1. 最新 `dev_branch` のApp/Web HEADと開始SHA
2. `AGENTS.md`
3. `docs/work-audit/README.md`
4. `docs/work-audit/policy/ASTRA_WORK.md`
5. `docs/work-audit/state/AUDIT_ROUTE.md`
6. `docs/work-audit/state/AUDIT_DELTA_ROUTE.md`
7. `docs/work-audit/state/FULL_AUDIT_EXECUTION_STANDARD.md`
8. `docs/product-audit/QUALITY_STANDARD.md`
9. `docs/product-audit/ENGINEERING_QUALITY_STANDARD.md`
10. `docs/product-audit/HANDS_ON_UI_STANDARD.md`
11. `docs/product-audit/LEGAL_IP_STANDARD.md`
12. State / inventory / verifier群

`docs/AI設計書/**` や日付付きverificationは、現在実装の意図・仕様・過去証拠を確認する補助資料として必要な箇所だけ参照する。

## 実行順

1. 最新HEADを取得し、実装inventoryと開始SHAを記録する。
2. baseline verifier / delta verifier / full-audit state preflightを実行し、State整合性を確認する。
3. Baseline current_idから固定順序で監査する。
4. 実行中に新規画面・状態・操作・分岐・品質リスクを発見したらDiscoveryへ登録する。
5. Baseline完了後、Discoveryを番号順に消化し、その後Deltaを番号順に消化する。
6. Deltaでは最新HEADから、全フィルター、質感変更/質感偏光、Brush Custom、縁取りペン、Hair Fold、髪/前髪preset、Community/API、Help/Tips、保存/export、native/backend連携等を再inventoryし、漏れなく追跡する。
7. 問題は列挙だけで終わらせず、可能ならroot cause→fix→targeted test→production UI再操作→Visual確認→regressionまで行う。
8. 全画面・全visible control・全固有操作を実際に操作する。機能結果、意図挙動、見た目、継続性、製品品質を別々に判定する。
9. PC/SP、対応7言語、指定responsive widths、theme/appearance、入力方式、権限/free/Premium等の条件差を、該当する全機能で確認する。
10. 最終Visual closureは最新HEADから再生成し、BEFORE/SETTINGS/AFTER、機能名、preset/mode、主要設定を識別可能にし、全ページrender＋実画像目視を行う。
11. 最終coverage、quality、evidence、advisor-pending、unregistered Discoveryを確認する。

## 「全通り」の扱い

数学的な無限直積を意味しない。ユーザーが実際に取り得る固有の操作、状態遷移、分岐、離散preset/選択肢、境界値を全件実操作し、viewport/language/theme/device等はmatrixと条件差ケースで漏れを防ぐ。

数値はminimum / maximum / boundary / representative middle / invalid / empty / largeを、相互作用がある場合は組合せを確認する。

## 完了条件

- Baseline incomplete = 0
- Discovery incomplete = 0
- Delta incomplete = 0
- unregistered Discovery = 0
- advisor-pending = 0
- 必要Visual evidence未完了 = 0
- 必要regression未完了 = 0
- 重大な機能・安定性・データ損失・セキュリティ・法務/IPリスクが未処理で残っていない
- 商用品質として明確な改善候補を放置していない、または放置理由をEvidenceへ記録している

過去会話、旧PDF、旧CI、旧checkpoint、古いHEADだけで現在の完了を判定しない。現在のdev_branchが一次事実である。
