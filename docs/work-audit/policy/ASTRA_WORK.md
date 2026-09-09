# NIARIM Work Audit — Astra execution policy

> このpolicyは、ユーザーが現在のトップレベル依頼でNIARIMの全面監査/全面監査再開を明示した場合だけ有効化する。通常タスクはこのpolicy/state領域を実行指示として使わない。

> 起動判定は明示トリガー制。「監査」「PNG監査」「最終green」等の語、作業範囲の広さ、前回作業の継続だけから全面監査へ昇格しない。「以下の会話の続きから」「引き続き」「前回の続き」も全面監査トリガーではない。

## 0. Policy / State / 通常タスクの分離

- 今回のユーザー指示: 今回何を行うか。
- Policy: どう監査するか。
- State: 全面監査Work自身が検証して確定した進捗。

通常タスクや別セッションの変更・話題を、そのままStateへ昇格させない。ユーザーが今回の全面監査で順序を明示した場合はその順序を採用し、単に「全面監査を再開」と依頼された場合はStateの次の1手をscope lockとする。

## 1. Scope lock / context isolation

全面監査の優先順位を決めるために最近の会話履歴や別セッションの話題を採用しない。別セッションのremote変更は現在scope/stateの前提を壊すかだけ確認する。現在の作業は、今回の全面監査での明示作業、Stateの次の1手、その前提を壊すremote変更、または明確な重大regression/security/data-loss riskのいずれかに限定する。

## 2. 正本

- branch: `dev_branch`
- 製品仕様・禁止事項: `docs/AI設計書/00_AIへの指示.md`
- 監査policy: `docs/work-audit/policy/ASTRA_WORK.md`
- 品質基準: `docs/product-audit/QUALITY_STANDARD.md`
- 法務/IP: `docs/product-audit/LEGAL_IP_STANDARD.md`
- State: `docs/work-audit/state/ASTRA_CONTINUATION.md` + `docs/work-audit/state/ASTRA_AUDIT_STATE.md`
- 実装固有資料: `CLAUDE.md`、`docs/AI設計書/31_引き継ぎガイド（AI開発者向け）.md` 等

開始時はStateと今回必要な正本の該当節だけ確認し、長大な文書を理由なく全文再読しない。

## 3. 最短再開手順 — 復元を仕事化しない

1. 両repoの最新 `dev_branch` と現在HEADを確認し、他セッションの変更を失わず追従する。
2. Stateから検証済み事実・未解決・次の1手を復元し、原則そのscope lockから実作業へ入る。
3. checkpoint後のremote差分はscope-boundedに確認する。全commit・全CI・全変更を網羅的に再調査して「最新Stateを再構築」しない。まず変更概要を見て、現在scopeの前提を壊す、直接競合する、または重大リスクを示す差分だけ深掘りする。
4. 通常タスク由来の変更は外部変更として認識するだけで、新しい監査優先順位にしない。現在scopeに無関係なら再監査やState昇格を後回しにしてscopeへ戻る。
5. 過去CIは、State根拠の欠落/矛盾、現在scopeの前提確認、または今回の検証確定に必要な場合だけ確認する。「Stateが古そう」「変更が多い」だけで広く履歴を掘らない。
6. State破損・汚染・移行など、ユーザーが監査State修復を明示した場合だけGit/CI証拠から広く復元してよい。その特殊修復を通常の再開手順へ持ち込まない。
7. 今回のユーザー明示指示があればStateと整合させ、必要な該当節だけ確認して作業する。

開始時刻記録だけのcommit/push、理由のない再監査・重いsuite再実行、復元のためだけの広範な履歴探索をしない。再開処理は実監査へ入るための最小コストに留める。

## 4. 実装・監査

NIARIMを世界最高水準の商用製品へ仕上げることを優先し、利用枠節約のため品質を落とさない。App/Webを1製品として扱い、必要に応じて再現→影響範囲→root cause→修正→検証→実画面→regressionまで完結させる。品質上有利なら影響を理解した上でrefactor/rewriteしてよい。重大な製品全体変更のみ事前確認する。

変更ごとに最小かつ十分なformat/static analysis/test/build/visual checkを行う。同一HEAD・入力・環境で既にPASSした重いsuiteを根拠なく再実行しない。CI/test PASSだけで品質保証済みにしない。UI/UX、PC/SP差別化、7言語、336表示matrix、全画面・全操作の実操作/目視、SEO/ASO、法務等は各正本を適用する。

## 5. AI/非AI作業の効率

単純反復・matrix・lint/test/build/screenshot等は可能な限りActions/CI/決定論的自動化へ寄せ、Astraは設計、root-cause、実装、UI/UX、翻訳品質、法務リスク、異常差分など判断価値の高い作業へ使う。

サブエージェントは品質/総合効率が明確に上がる独立作業または独立レビューだけ必要最小限。Codex系では原則 `fork_turns:"none"`、必要でも1〜2、`all`は使わない。子から子を増やさない。wait既定値を設定できる場合120秒、個別wait/timeoutは予想実行時間の約2倍を一度に指定する。

## 6. State更新と終了

Stateは全面監査モードで実際に検証した事実だけ更新する。通常タスクで実装済みという理由だけで監査済み/完了済みにしない。

`ASTRA_CONTINUATION.md` は開始/終了HEAD、完了事項、主要検証、未解決、次の1手を簡潔に保持し、`ASTRA_AUDIT_STATE.md` は監査マップ・検証根拠を保持する。同じ内容を重複記載しない。

State更新commitには `[audit-state]`、policy/guard変更にはユーザーの明示依頼のもと `[audit-policy-approved]` を使う。合理的な作業単位で検証済み変更をcommitし、安全に`dev_branch`へpushする。全面監査completeは各品質正本の条件を満たした場合だけとする。
