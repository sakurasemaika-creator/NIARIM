# NIARIM Work Audit — Astra execution policy

> このpolicyは、ユーザーが現在のトップレベル依頼でNIARIMの全面監査/全面監査再開を明示した場合だけ有効化する。通常タスクはこのpolicy/state領域を実行指示として使わない。

> 起動判定は明示トリガー制。「監査」「PNG監査」「最終green」等の語、作業範囲の広さ、前回作業の継続だけから全面監査へ昇格しない。「以下の会話の続きから」「引き続き」「前回の続き」も全面監査トリガーではない。

## 0. 正本と分離

- 今回のユーザー指示: 今回何を行うか。
- Policy: どう監査するか。本ファイルと `docs/product-audit/*STANDARD.md`。
- Route: **何をどの順番で監査するか**。`docs/work-audit/state/AUDIT_ROUTE.md` を唯一の正本とする。
- Progress: `ASTRA_CONTINUATION.md` の `current_id` 等。
- Evidence: `ASTRA_AUDIT_STATE.md` の検証根拠。

通常タスクや別セッションの変更・話題を、そのままRoute/Progress/Evidenceへ昇格させない。

## 1. Route bootstrap — 一度だけ

`AUDIT_ROUTE.md` が `bootstrap-required` の場合、通常の修正作業へ入る前に**一度だけ**最新App/Webを構造調査し、全画面・全状態・全操作・横断品質要件を一周で検証できる完全なTODOを作る。

- App=`A###`、Web=`W###` の安定IDを付け、実UI/navigationに沿う固定順序にする。
- 画面だけでなくモーダル、パネル、empty/error/loading、無料/Premium、設定、入力、ジェスチャー、編集、保存/復元、共有/export等を含める。
- 各TODOへ対象、前提状態、実操作、期待結果、必要なviewport/PC-SP/7言語/Premium条件、必要な画像・証拠、statusを定義する。
- QUALITY / HANDS_ON_UI（該当repo）/ LEGAL_IPの全要件をTODOへ割り当て、coverage checkで未割当がないことを確認してから `locked` にする。
- **旧checkpoint、過去会話、最近の別セッションからTODOや完了状態を復元しない。** 最新実装と品質基準から作る。

## 2. locked後のscope lock

Routeがlockedになった後は、`current_id` の未完了項目からID順に進める。毎回「次に何を調べるか」を再判断しない。最近のcommit、別セッションの話題、興味深い機能、CI失敗を理由にrouteを飛び越えない。

例外は、現在IDの前提を直接壊す変更、または明確な重大regression/security/data-loss riskだけ。通常タスク由来の無関係な変更は存在を認識するだけでroute順を変えない。

新規画面/機能は既存IDを並べ替えずrouteへ追記する。1周完了後にroute作成後の変更差分を回帰フェーズとして扱い、巡回監査と混ぜない。

## 3. 最短再開手順

1. 両repoの最新 `dev_branch` と現在HEADを確認し、安全に追従する。
2. `AUDIT_ROUTE.md` を読む。bootstrap-requiredならSection 1だけを行う。lockedなら `ASTRA_CONTINUATION.md` の `current_id` を読む。
3. current IDに必要な仕様/品質基準の該当節だけ確認し、直ちにそのTODOを実行する。
4. checkpoint後のremote差分は現在IDの前提を壊すかだけscope-boundedに確認する。全commit・全CIを網羅的に再調査してStateを再構築しない。
5. 完了条件を満たしたIDだけdoneにして次IDへ進む。利用枠終了時は現在IDを保存する。

開始時刻記録だけのcommit/push、理由のない再監査・重いsuite再実行、復元のためだけの広範な履歴探索をしない。

## 4. 実装・監査品質

NIARIMを世界最高水準の商用製品へ仕上げることを優先し、App/Webを1製品として扱う。必要に応じて再現→影響範囲→root cause→修正→検証→実画面→regressionまで完結させる。品質上有利なら影響を理解した上でrefactor/rewriteしてよい。重大な製品全体変更のみ事前確認する。

変更ごとに最小かつ十分なformat/static analysis/test/build/visual checkを行う。CI/test PASSだけで品質保証済みにしない。UI/UX、PC/SP差別化、7言語、336表示matrix、全画面・全操作の実操作/目視、SEO/ASO、法務等は各正本を適用する。

## 5. AI/非AI作業の効率

単純反復・matrix・lint/test/build/screenshot等はActions/CI/決定論的自動化へ寄せ、Astraは設計、root-cause、実装、UI/UX、翻訳品質、法務リスク、異常差分など判断価値の高い作業へ使う。

サブエージェントは品質/総合効率が明確に上がる独立作業または独立レビューだけ必要最小限。Codex系では原則 `fork_turns:"none"`、必要でも1〜2、`all`は使わない。子から子を増やさない。wait既定値を設定できる場合120秒、個別wait/timeoutは予想実行時間の約2倍を一度に指定する。

## 6. State更新

Route/Progress/Evidenceは全面監査Work自身が実際に検証した事実だけ更新する。旧監査記録や通常タスクの成果だけでTODOをdoneにしない。

State更新commitには `[audit-state]`、policy/guard変更にはユーザーの明示依頼のもと `[audit-policy-approved]` を使う。全面監査completeはRoute全件と各品質正本の完了条件を満たし、最終回帰フェーズを終えた場合だけとする。
