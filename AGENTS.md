# AGENTS.md — NIARIM 自律開発・監査ルール

このファイルは、このリポジトリでWork / Codex / その他の自律開発エージェントが最初に読む実行ルールです。**同じ指示を複数文書から丸ごと読み直さない**ことを前提に、各文書の役割を分けます。

## 0. 権威と読み込み順

- 作業対象は **`dev_branch` のみ**。ユーザーから明示指示がない限り、`main` その他へ変更・push・mergeしない。
- 製品仕様・禁止事項の正本：`docs/AI設計書/00_AIへの指示.md`
- 全面監査の品質基準・監査範囲・完了条件の正本：`docs/product-audit/QUALITY_STANDARD.md`
- 現在地点・未完了事項：`docs/work-continuation.md` と `docs/product-audit/README.md`
- 実装上の地雷・環境・個別手順：`CLAUDE.md`、`docs/AI設計書/31_引き継ぎガイド（AI開発者向け）.md`、`30_AI自律動作確認プロンプト.md`、`28_継続タスク（未着手一覧）.md`、`12_実装チェックリスト.md` 等

開始時は上の**正本4系統**から現在の目的と状態を復元する。長大な引き継ぎ文書・履歴は最初から全文を投入せず、触る機能・ファイル・失敗内容に応じて見出し・検索・該当箇所だけを読む。特にコード変更前は `CLAUDE.md` と31番ガイドを対象機能名・ファイル名・利用ツール名で検索し、関連する地雷や検証手順を確認する。

この「段階的に必要箇所だけ読む」という読み込み方は、参照文書にある一般的な「最初に全部読む」指示より優先する。ただし、参照文書にある**具体的な技術制約・禁止事項・検証条件そのものを省略してよいという意味ではない**。

同じ方針を複数文書で再解釈しない。監査方針は `QUALITY_STANDARD.md`、Git/再開/チェックポイントはこの `AGENTS.md`、現在地点はcontinuation/checkpointを正とする。

## 1. セッション開始

1. 現在時刻をAsia/Tokyo (JST)で取得し、`docs/work-continuation.md` の最新セッションに開始時刻を記録する。
2. `git fetch origin dev_branch` 相当でremoteを確認し、`git status`、branch、HEAD、未コミット変更、未push commit、`origin/dev_branch`との差分を確認する。
3. 他セッションの変更を失わない安全な方法で最新 `dev_branch` へ追従する。破壊的reset、force push、ユーザー変更の無断破棄は禁止。競合は双方の意図を理解して意味的に統合する。
4. `docs/work-continuation.md` と `docs/product-audit/README.md` のcheckpointを照合し、前回終了後に変更されたコードの影響だけ再確認して未完了地点から再開する。監査済み領域を理由なく最初からやり直さない。

## 2. Workの再開

- 現時点では、Scheduled Taskから **Work + GPT-6 Astra最大effortへ確実に自動復帰できることを前提にしない**。標準はユーザーがWorkを開き、現在利用可能な最大effortで再開する運用とする。
- 再開は会話履歴に依存せず、最新 `dev_branch` → `AGENTS.md` → 仕様/品質基準 → continuation/audit checkpoint の順で復元する。
- 自動Scheduled Workが実証された場合のみ補助的に利用する。それまではエージェント自身が予約作成・重複確認に監査時間を使わない。

## 3. サブエージェント

- メイン単体より品質または総合効率に明確な利益がある独立タスクだけに必要最小限で使う。
- Codex系で `fork_turns` を指定できる場合、**`fork_turns: "all"` は原則使用しない**。独立タスクは `"none"`、文脈が必要でも原則 `"1"`〜`"2"` 程度とし、必要情報はtask messageへ明示する。`none`で必要なtool/contextが欠ける場合だけ最小限増やす。
- 待機の既定timeoutを設定できる場合は **120秒** を基準にする。個々のwait/timeoutは予想実行時間の**約2倍**を一度に指定し、短いwait→timeout→親再推論→再waitの反復、不要なstatus polling/retryを避ける。
- 待機中に独立作業があればそちらを進める。
- GitHub Actions / CI / build / test / lint / Playwright / 静的解析等の**非AI処理の並列化はこの制限の対象外**。

## 4. 実装・検証・チェックポイント

- 問題は症状だけpatchせず、必要に応じて再現条件・影響範囲・root causeを確認してから直す。大胆なrefactor/rewriteを含む判断基準は `QUALITY_STANDARD.md` に従う。
- 変更ごとに、**その変更を検証する最小かつ十分な**format / static analysis / test / visual checkを実行する。Flutter固有のコマンド・フォーマッタの癖は `CLAUDE.md` / 31番ガイドの関連箇所を確認する。
- 同一HEAD・同一入力・同一環境ですでにPASSした重いsuiteを、根拠なく何度も再実行しない。コード・依存・環境・入力・テスト自体が変わった場合、失敗原因の再確認が必要な場合、または `QUALITY_STANDARD.md` がfull regressionを要求するcheckpointでは再実行する。
- CI/testのPASSを無条件に品質保証とみなさず、テストの網羅性・妥当性を評価する。
- 合理的な作業単位ごとに `docs/work-continuation.md` と必要な監査checkpointを更新し、検証済み変更をcommitする。push直前にremoteを再確認し、安全に統合して `dev_branch` へpushする。中途半端で壊れた状態はpushしない。

## 5. 継続情報

`docs/work-continuation.md` は巨大な作業日記にせず、次回短時間で復元できる情報だけを最新セッションとして残す：

- セッション開始/終了時刻（JST）
- 開始時HEAD / 終了時HEAD
- 今回の目的と完了した作業
- 主要な変更ファイル
- 実行した検証と結果
- 未解決問題 / 失敗中テスト
- 重要な設計判断
- **次に行う具体的な1手**
- 必要なら利用上限画面で確認した次回利用可能時刻等

## 6. 終了

- 全面監査の完了判定は `QUALITY_STANDARD.md` に従う。build/test/CI成功や利用枠到達だけでcompleteにしない。
- 未完了ならcontinuationを `paused` または `in-progress` とし、次の1手を必ず残す。
- 利用枠・権限・環境で停止する場合も、可能な限り通常終了と同じcheckpoint・commit/push手順を踏み、次回が会話履歴なしでも復元できる状態にする。
