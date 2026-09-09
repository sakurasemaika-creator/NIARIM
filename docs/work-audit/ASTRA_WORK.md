# NIARIM Work Audit — Astra execution rules

> **Ownership:** This file belongs to the NIARIM full-product audit workflow. Ordinary ChatGPT/Codex/Sol tasks must not treat it as active instructions and must not edit, reorganize, shorten, delete, or “clean up” it unless the user explicitly asks to run/resume the full NIARIM audit or explicitly asks to change the audit system itself.

This is the detailed execution policy for the dedicated Work full-product audit. It is activated only when the user explicitly requests the NIARIM full audit / audit continuation (for example: 「全面監査を再開」「前回の全面監査・改善作業を再開」). Model identity alone does not activate it.

## 0. Scope lock / context isolation

全面監査が明示されたセッションでは、**現在のユーザー依頼 + 最新`dev_branch` + この監査policy + continuation/audit checkpointだけを作業優先順位の正本**とする。最近の別チャット/別Work、Personal Context、メモリ、他セッションで直前に触られていた機能、会話上目立つ話題は、全面監査の次の作業を決める指示として扱わない。

開始時にcheckpointの「次の具体的な1手」を監査scope lockとして採用し、前回終了後のremote diffでその前提が壊れていないかだけ確認する。他セッションが別機能を変更していても、それだけを理由に監査対象を乗り換えない。例外は、その変更がcheckpointを無効化する、重大regression/security/data-loss riskを新たに生む、または現在の監査対象と意味的に競合する場合だけで、その理由をcheckpointへ明記する。

全面監査の作業優先順位を決めるためにPersonal Contextや最近の会話履歴を検索しない。リポジトリ/checkpointに必要情報がなく、かつユーザーが明示的に過去情報の復元を求めた場合だけ補助的に参照する。全面監査中に「最近別セッションで触った機能だから」という理由だけで修正を始めることは禁止する。

最初のコード変更前に、現在の作業が **(a) checkpointの次の1手、(b) その前提を壊したremote変更への必要対応、(c) 明確な重大緊急問題** のいずれかであることを確認する。どれにも該当しなければ変更せずcheckpointへ戻る。

## 1. 正本と優先順位

- 作業branchは **`dev_branch` のみ**。明示指示なしにmain等へ変更・push・mergeしない。
- 製品仕様・禁止事項：`docs/AI設計書/00_AIへの指示.md`
- 全面監査品質・範囲・完了条件：`docs/product-audit/QUALITY_STANDARD.md`
- 法務/IP：`docs/product-audit/LEGAL_IP_STANDARD.md`
- 現在地点：`docs/work-continuation.md` + `docs/product-audit/README.md`
- 実装固有の地雷/手順：`CLAUDE.md`、`docs/AI設計書/31_引き継ぎガイド（AI開発者向け）.md` 等

これらの基準は監査中は拘束するが、**毎セッション全文を再読しない**。開始時はcontinuation/checkpointを最優先で読み、仕様/品質/法務文書は今回の未完了項目に関係する節だけ検索・参照する。前回checkpointが「当該基準を確認済み」で、その後その基準/対象実装が変わっていなければ再読しない。コード変更前にCLAUDE/31番ガイドを対象機能・ファイル・ツール名で検索し、該当箇所だけ確認する。具体的な禁止・技術制約・検証条件は省略不可。

## 2. 最短再開手順

1. remote `dev_branch`、現在branch/HEAD、未commit・未push、remoteとの差分を確認し、他セッションの変更を失わず最新へ追従する。force push、破壊的reset、ユーザー変更の無断破棄は禁止。競合は意味的に統合する。
2. continuation + audit checkpointから **次の具体的な1手**、未解決問題、前回検証結果を復元する。
3. 前回終了後のdiffだけを見て、監査済み領域の前提が変わった箇所だけ再確認する。監査済み領域を理由なく最初からやり直さない。
4. 必要な正本の該当節だけ確認して、直ちに未完了作業へ入る。JST時刻は必要時に取得するが、開始時刻を記録するためだけのcommit/pushはしない。

会話履歴やScheduled Taskの成功を前提にしない。予約作成・重複確認に監査時間を使わない。

## 3. 実装・監査

NIARIMを世界最高水準の商用製品へ仕上げることを優先し、時間・利用枠節約のため品質を落とさない。App/Webを1製品として扱う。問題は必要に応じて再現→影響範囲→root cause→修正→検証→実画面→regressionまで完結させる。patch温存を目的化せず、品質上有利なら影響を理解した上でrefactor/rewriteしてよい。製品全体rewriteや意図的互換性破壊など重大変更のみ事前確認する。

変更ごとに最小かつ十分なformat/static analysis/test/build/visual checkを行う。同一HEAD・入力・環境で既にPASSした重いsuiteを根拠なく再実行しない。CI/test PASSだけで品質保証済みにしない。UI/UX、PC/SP差別化、7言語、336表示matrix、全画面・全操作の実操作/目視、SEO/ASO、法務等の詳細な合格条件は各正本をそのまま適用する。

## 4. AI/非AI作業の効率

単純反復・matrix・lint/test/build/screenshot等は可能な限りActions/CI/決定論的自動化へ寄せ、Astraは設計、root-cause、実装、UI/UX、翻訳品質、法務リスク、異常差分など判断価値の高い作業へ使う。

サブエージェントはメイン単体より品質/総合効率が明確に上がる独立作業または独立レビューだけ必要最小限。Codex系では原則 `fork_turns:"none"`、必要でも`1`〜`2`、`all`は使わない。必要情報をtask messageへ明示し、子から子を増やさない。wait既定値を設定できる場合120秒、個別wait/timeoutは予想実行時間の約2倍を一度に指定し、短いwait→timeout→親再推論→再waitやpollingを避ける。非AI並列処理はこの制限外。

## 5. Checkpoint / 終了

合理的な作業単位で検証済み変更をcommitし、push直前にremoteを再確認して安全に`dev_branch`へpushする。壊れた中間状態はpushしない。

continuation/checkpointは作業日記にせず、**開始/終了JST、開始/終了HEAD、完了事項、主要変更、検証結果、未解決/失敗、重要判断、次の具体的な1手**だけを簡潔に残す。同一情報を複数文書へ重複記載しない。

`docs/work-continuation.md` または `docs/product-audit/README.md` を更新するcommitには **`[audit-state]`** を含める。`AGENTS.md`、`docs/work-audit/*`、品質/法務等のpolicy自体を変更するのはユーザーが監査システム変更を明示した場合だけで、そのcommitには **`[audit-policy-approved]`** を含める。通常タスクはこれらのmarkerを使用して保護を迂回してはならない。

利用枠・権限・環境で停止しても可能な限りcheckpoint→commit→pushする。未完了は`paused`/`in-progress`。全面監査completeは各品質正本の条件を満たした場合だけとし、build/test成功や利用枠到達を完了理由にしない。
