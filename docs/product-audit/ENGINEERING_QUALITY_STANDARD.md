# NIARIM Engineering Quality Audit Standard

この文書はNIARIM全面監査Workで必ず適用する横断品質基準である。App/Webを1製品として扱い、既存のlock済みBaseline Routeを再構築・renumber・並べ替えずに適用する。通常チャットの作業結果だけで監査済みにしてはならない。

## 1. セキュリティ

認証・認可・権限制御を、UI表示だけでなく実際の境界/API/保存層まで確認する。未認証、別ユーザー、無料/Premium、期限切れ/失効状態、直接URL/route/API呼出し、改変入力等で権限を迂回できないことを検証する。

入力値、ファイル、URL、query/path/body/header、import/export、共有/公開データ、外部連携等のvalidation・sanitization・サイズ/形式/境界値・不正値を確認する。外部公開APIについて認証、認可、rate/abuse耐性、replay、enumeration、過剰情報露出、エラー情報漏えい等の悪用可能性を確認する。

個人情報、認証情報、token、secret、session、ログ、cache、端末保存、通信、CI/artifact等について不要な収集・露出・永続化がなく、適切な保護と失効が行われることを確認する。実秘密情報を監査証拠へ記録しない。

## 2. 安定性・クラッシュ耐性

race/concurrency/async、二重実行、キャンセル、timeout、画面破棄後callback、再試行、ネットワーク断、部分失敗、起動/終了、background/foreground等でcrash/hang/state破損が起きないことを確認する。

resource lifecycle、listener/controller/stream/timer/worker/image/buffer/cache等の解放を確認し、メモリリーク、無制限増加、不要な再描画・再計算・再通信を検出する。失敗時は安全に回復・再試行でき、ユーザーデータを壊さないことを要求する。

## 3. コードの保守性

主要class/module/service/state層について責務分離、依存方向、命名、状態管理、error handling、重複、dead/obsolete code、巨大class/function、暗黙契約、循環依存等を確認する。

将来の機能追加・変更・テストが局所的に行える構造かを評価し、patchの累積より設計整理/refactorが安全性・可読性・testability・変更容易性を明確に高める場合は影響範囲を検証して改善する。既存の良い抽象化は理由なく作り直さない。

## 4. パフォーマンス

起動時間、主要画面遷移、入力/描画/編集、保存/読込、network/API、重いデータ、長時間利用等の実利用経路でlatency、jank、CPU/GPU、memory、I/O、network、不要なbuild/render/reflow/repaint等を確認する。

平均値だけでなくcold/warm、低性能端末相当、境界/大規模データ、連続操作を考慮し、体感遅延や異常なメモリ増加を見逃さない。最適化は測定・再現根拠を持ち、機能正確性や画質を不必要に犠牲にしない。

## 5. アクセシビリティ・国際化

色だけに依存しない情報伝達、contrast、focus、keyboard操作、tap target、semantic/accessible name、screen reader、読み上げ順、動的状態通知、zoom/text scaling、reduced motion等、対象platformで適用可能なaccessibilityを実画面/実操作で確認する。

対応7言語は日本語原文の意味・意図・温度感を基準に、自然さ、register、専門用語、スラング混入、切断/overflow、複数形、日付/時刻/数値/単位等を確認する。単なる文字列キー一致や機械翻訳済みを合格根拠にしない。

## Routeへの適用

このStandard追加を理由にlock済みBaseline Routeを再bootstrapしない。Astra全面監査Workは、現在以降の該当Baseline IDでこの基準を適用する。既に完了済みBaselineに対して、この新基準の実証的検証が必要だが証拠がない領域は、既存doneを推測で書き換えたり通常チャットの成果を流用したりせず、PolicyのDiscovery TODOとして追加して監査する。

全面監査completeには、このStandardの各領域について未説明の未確認事項がなく、発見した問題の必要な修正・検証・regressionが完了していることを要求する。
