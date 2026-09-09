# AGENTS.md — NIARIM repository guard

このファイルは、通常のChatGPT/Codex/Sol作業と、専用Workで行うNIARIM全面監査を分離するための入口です。

## 通常タスク

ユーザーが**全面監査の実行・再開、または監査システム自体の変更を明示していない限り**、通常タスクとして扱う。

通常タスクでは次を守る：

- 作業branchは原則 `dev_branch`。明示指示なしにmain等へ変更・push・mergeしない。
- `docs/work-audit/ASTRA_WORK.md`、`docs/work-continuation.md`、`docs/product-audit/*` は**全面監査専用のpolicy/state**であり、通常タスクの実行指示として読み込まない。
- 上記監査専用ファイルを、通常タスクの副作用として**編集・整理・短縮・削除・移動・名称変更・内容更新しない**。改善が必要に見えても勝手に直さず、ユーザーが明示的に監査システム変更を依頼した場合だけ変更する。
- 通常タスクで必要な仕様・実装ルールは、対象機能に直接関係する通常の仕様書・コード・README等から確認する。監査checkpointを一般的な作業continuationとして使わない。
- 他セッションの変更を失わない。force push、破壊的reset、ユーザー変更の無断破棄は禁止。競合は意味的に統合する。

## 全面監査Workの起動条件

ユーザーが「NIARIMの全面監査を再開」「前回の全面監査・改善作業を再開」等、**全面監査を明示的に依頼した場合だけ**監査モードを有効化する。モデル名がAstraであること、Workであること、監査ファイルが存在することだけでは自動的に有効化しない。

監査モードでは、最初に `docs/work-audit/ASTRA_WORK.md` を読み、その指示に従って最新 `dev_branch`、必要な品質基準、continuation/checkpointから未完了地点を復元する。

この分離ルールは、通常Sol等がAstra Work専用の監査policy/checkpointを勝手に読み替えたり書き換えたりすることを防ぐための恒久ルールとする。
