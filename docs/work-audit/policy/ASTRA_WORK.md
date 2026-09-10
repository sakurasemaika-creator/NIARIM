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

## 2. locked後のscope lock + Discovery

Routeがlockedになった後は、`current_id` の未完了Baseline項目からID順に進める。毎回「次に何を調べるか」を再判断しない。最近のcommit、別セッションの話題、興味深い機能、CI失敗を理由にrouteを飛び越えない。

**Route lockはBaseline TODOのID・順序・coverage基準を固定するものであり、実監査で新たに実証された監査対象の追加を禁止しない。** 静的coverageが通っていても、実操作・実画面・実データ・組合せ検証で初めて判明する画面、状態、操作、分岐、入力条件、回帰条件、品質リスク等はあり得る。発見した対象を「628件にないから」等の理由で無視・既存項目へ無理に包含してはならない。

新たな監査対象を発見した場合：

1. 既存Baseline IDの意味・順序・完了済み状態を変更せず、`D001`, `D002`... の安定したDiscovery TODOとして `AUDIT_ROUTE.md` のDiscovery section末尾へ追記する。
2. Discoveryには `discovered_from`（発見元Baseline/Discovery ID）、対象、再現/前提、必要な検証、期待結果、証拠条件、statusを記録する。同一対象の重複D-IDは作らない。
3. 現在IDの完了を妨げる問題、security/data-loss/privacy等の重大リスク、または後続監査の前提を壊す問題だけ即時対応してよい。それ以外はDiscovery backlogへ積み、Baselineの固定順序へ戻る。
4. Baseline全件完了後、D-IDを番号順に全件消化する。Discovery監査中にさらに未想定対象を発見した場合も次のD-IDを末尾へ追加する。
5. Discovery TODOが追加されてもBaseline Routeを再bootstrap/relockせず、既存IDをrenumber/reorderしない。

新規画面/機能がroute lock後の製品変更として追加された場合も既存Baselineを並べ替えず、変更差分回帰フェーズの対象として追跡する。巡回中の実監査から自然に発見された未想定状態等は上記Discoveryへ入れる。

## 3. 最短再開手順

1. 両repoの最新 `dev_branch` と現在HEADを確認し、安全に追従する。
2. `AUDIT_ROUTE.md` を読む。bootstrap-requiredならSection 1だけを行う。lockedなら `ASTRA_CONTINUATION.md` の `current_id` を読む。
3. current IDに必要な仕様/品質基準の該当節だけ確認し、直ちにそのTODOを実行する。
4. checkpoint後のremote差分は現在IDの前提を壊すかだけscope-boundedに確認する。全commit・全CIを網羅的に再調査してStateを再構築しない。
5. 完了条件を満たしたIDだけdoneにして次IDへ進む。Baseline完了後は未完了D-IDの最小番号へ進む。利用枠終了時は現在IDを保存する。

開始時刻記録だけのcommit/push、理由のない再監査・重いsuite再実行、復元のためだけの広範な履歴探索をしない。

## 4. 実装・監査品質

NIARIMを世界最高水準の商用製品へ仕上げることを優先し、App/Webを1製品として扱う。必要に応じて再現→影響範囲→root cause→修正→検証→実画面→regressionまで完結させる。品質上有利なら影響を理解した上でrefactor/rewriteしてよい。重大な製品全体変更のみ事前確認する。

変更ごとに最小かつ十分なformat/static analysis/test/build/visual checkを行う。CI/test PASSだけで品質保証済みにしない。UI/UX、PC/SP差別化、7言語、336表示matrix、全画面・全操作の実操作/目視、SEO/ASO、法務等は各正本を適用する。

## 5. AI/非AI作業の効率

単純反復・matrix・lint/test/build/screenshot等はActions/CI/決定論的自動化へ寄せ、Astraは設計、root-cause、実装、UI/UX、翻訳品質、法務リスク、異常差分など判断価値の高い作業へ使う。

サブエージェントは品質/総合効率が明確に上がる独立作業または独立レビューだけ必要最小限。Codex系では原則 `fork_turns:"none"`、必要でも1〜2、`all`は使わない。子から子を増やさない。wait既定値を設定できる場合120秒、個別wait/timeoutは予想実行時間の約2倍を一度に指定する。

## 6. State更新と完了条件

Route/Progress/Evidenceは全面監査Work自身が実際に検証した事実だけ更新する。旧監査記録や通常タスクの成果だけでTODOをdoneにしない。

State更新commitには `[audit-state]`、policy/guard変更にはユーザーの明示依頼のもと `[audit-policy-approved]` を使う。

全面監査completeには、少なくとも **Baseline未完了=0、Discovery未完了=0、現在認識している未登録Discovery=0** を満たし、各品質正本の完了条件と最終回帰フェーズも完了していることが必要。Baseline coverageの通過だけを「これ以上発見対象はない」「監査complete」の根拠にしてはならない。
