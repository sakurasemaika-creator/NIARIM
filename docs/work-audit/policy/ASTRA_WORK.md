# NIARIM Work Audit — Astra execution policy

> このpolicyは、ユーザーがNIARIMの全面監査/全面監査再開を明示した場合だけ有効化する。通常のChatGPT/Codex/Sol作業はこのpolicy/state領域を読まず、実行指示として使わず、編集しない。モデル名やWork利用だけでは監査モードを有効化しない。

## 0. Policy / State / 通常タスクの分離

全面監査では、次の3種類を混同しない。

- **今回のユーザー指示**: 今回何を行うか、明示された優先順位・制約。今回のセッションではこれを最優先する。
- **Policy**: どう監査するか。`docs/work-audit/policy/ASTRA_WORK.md` と `docs/product-audit/*STANDARD.md` を正本とする。
- **State**: 前回までに全面監査Work自身が検証して確定した進捗。`docs/work-audit/state/ASTRA_CONTINUATION.md` と `docs/work-audit/state/ASTRA_AUDIT_STATE.md` を正本とする。

通常タスクで行われた変更、別チャット/別Work/Personal Context/メモリの話題、ユーザーの未検証な進捗申告を、そのまま監査Stateへ昇格させない。最新HEADとの差分として認識し、全面監査で必要な検証を行って事実確認できたものだけStateへ反映する。

ユーザーが今回の全面監査で具体的な作業順序を明示した場合は、その順序を採用する。ユーザーが単に「全面監査を再開」とだけ依頼した場合は、Stateの「次の具体的な1手」をscope lockとする。Stateと今回の明示指示が食い違う場合はStateを勝手に書き換えず、最新HEADと検証結果で矛盾を確認してから更新する。

## 1. Scope lock / context isolation

全面監査の作業優先順位を決めるために最近の会話履歴、Personal Context、メモリ、別セッションの話題を検索・採用しない。別セッションのremote変更は、現在のscope/stateの前提を壊すかだけ確認する。

最初のコード変更前に、現在の作業が次のいずれかであることを確認する。

1. 今回のユーザーが全面監査内で明示した作業。
2. Stateの次の1手。
3. 1または2の前提を壊したremote変更への必要対応。
4. 明確な重大regression / security / data-loss risk。

該当しない話題へ「最近触られていたから」という理由で乗り換えない。

## 2. 正本

- branch: `dev_branch` のみ。明示指示なしにmain等へ変更・push・mergeしない。
- 製品仕様・禁止事項: `docs/AI設計書/00_AIへの指示.md`
- 監査実行policy: `docs/work-audit/policy/ASTRA_WORK.md`
- 品質・範囲・完了条件: `docs/product-audit/QUALITY_STANDARD.md`
- 法務/IP: `docs/product-audit/LEGAL_IP_STANDARD.md`
- 監査State: `docs/work-audit/state/ASTRA_CONTINUATION.md` + `docs/work-audit/state/ASTRA_AUDIT_STATE.md`
- 実装固有の地雷/手順: `CLAUDE.md`、`docs/AI設計書/31_引き継ぎガイド（AI開発者向け）.md` 等

開始時はStateを読んで現在地点を復元し、今回必要なpolicy/仕様の該当節だけ確認する。毎回長大な文書を全文再読しない。具体的な禁止・技術制約・検証条件は省略しない。

## 3. 最短再開手順

1. 両repoのremote `dev_branch`、現在HEAD、未commit/未push、remoteとの差分を確認し、他セッションの変更を失わず最新へ追従する。force push、破壊的reset、ユーザー変更の無断破棄は禁止。
2. `ASTRA_CONTINUATION.md` と `ASTRA_AUDIT_STATE.md` から、検証済み事実・未解決・次の1手を復元する。
3. 前回checkpoint後のremote diffを確認する。通常タスク由来の変更は「外部変更」として扱い、検証前に監査完了/監査済みへ昇格させない。
4. 今回のユーザー明示指示があればそれとStateを整合させ、必要な正本の該当節だけ確認して作業へ入る。

会話履歴やScheduled Task成功を再開根拠にしない。開始時刻記録だけのcommit/pushや、理由のない再監査・重いsuite再実行をしない。

## 4. 実装・監査

NIARIMを世界最高水準の商用製品へ仕上げることを優先し、利用枠節約のため品質を落とさない。App/Webを1製品として扱い、必要に応じて再現→影響範囲→root cause→修正→検証→実画面→regressionまで完結させる。patch温存を目的化せず、品質上有利なら影響を理解した上でrefactor/rewriteしてよい。製品全体rewriteや意図的互換性破壊など重大変更のみ事前確認する。

変更ごとに最小かつ十分なformat/static analysis/test/build/visual checkを行う。同一HEAD・入力・環境で既にPASSした重いsuiteを根拠なく再実行しない。CI/test PASSだけで品質保証済みにしない。UI/UX、PC/SP差別化、7言語、336表示matrix、全画面・全操作の実操作/目視、SEO/ASO、法務等は各正本を適用する。

## 5. AI/非AI作業の効率

単純反復・matrix・lint/test/build/screenshot等は可能な限りActions/CI/決定論的自動化へ寄せ、Astraは設計、root-cause、実装、UI/UX、翻訳品質、法務リスク、異常差分など判断価値の高い作業へ使う。

サブエージェントはメイン単体より品質/総合効率が明確に上がる独立作業または独立レビューだけ必要最小限。Codex系では原則 `fork_turns:"none"`、必要でも`1`〜`2`、`all`は使わない。子から子を増やさない。wait既定値を設定できる場合120秒、個別wait/timeoutは予想実行時間の約2倍を一度に指定し、短いpollingを避ける。

## 6. State更新と終了

Stateは**全面監査モードで実際に検証した事実だけ**更新する。通常タスクで実装済みという理由だけで「監査済み」「完了済み」にしない。ユーザーが完了と申告した事項も、全面監査の完了Stateへ書く前に可能な範囲でGit/CI/実画面等の根拠を確認する。

`ASTRA_CONTINUATION.md` は開始/終了HEAD、完了事項、主要検証、未解決、次の1手を簡潔に保持する。`ASTRA_AUDIT_STATE.md` は監査マップ・検証根拠を保持する。同じ内容を両方へ重複記載しない。

State更新commitには **`[audit-state]`** を含める。`AGENTS.md`、`docs/work-audit/README.md`、`docs/work-audit/policy/*`、監査品質基準、guard自体を変更するのはユーザーが監査システム変更を明示した場合だけで、commitには **`[audit-policy-approved]`** を含める。通常タスクはmarkerを使用しない。

合理的な作業単位で検証済み変更をcommitし、push直前にremoteを再確認して安全に`dev_branch`へpushする。壊れた中間状態はpushしない。利用枠等で停止しても可能な限りState→commit→pushする。全面監査completeは各品質正本の条件を満たした場合だけとする。
