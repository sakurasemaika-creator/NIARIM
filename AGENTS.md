# AGENTS.md — NIARIM repository guard

このファイルは通常タスク、全面監査Work、監査システム保守を分離する入口です。

## 1. 通常タスク

ユーザーが**NIARIM全面監査の実行/再開**または**監査システム自体の変更**を明示していない限り、通常タスクとして扱う。

通常タスクでは：

- 作業branchは原則 `dev_branch`。明示指示なしにmain等へ変更・push・mergeしない。
- `docs/work-audit/**` と監査専用 `docs/product-audit/**` を**検索・一覧・read/fetchして一般的なcontinuationや実行指示に使わない**。通常作業に必要な仕様は対象機能の通常仕様書・コード・README等から確認する。
- 上記監査領域、`AGENTS.md`、`.github/workflows/audit-policy-guard.yml` を通常タスクの副作用として編集・整理・短縮・削除・移動・名称変更しない。
- `[audit-policy-approved]` / `[audit-state]` markerを通常タスクで使用しない。
- 他セッションの変更を失わない。force push、破壊的reset、ユーザー変更の無断破棄は禁止。競合は意味的に統合する。

`AGENTS.md` 自体を読むことは通常タスクでも正しい。ここで通常タスクと判定したら、監査policy/stateへ進まず通常ルートで作業する。

## 2. 全面監査Work

ユーザーが「NIARIMの全面監査を再開」「前回の全面監査・改善作業を再開」等、**全面監査を明示した場合だけ**監査モードを有効化する。モデル名がAstra、Work利用、監査ファイルの存在だけでは有効化しない。

監査モードでは `docs/work-audit/policy/ASTRA_WORK.md` を入口とし、そこに従って `docs/work-audit/state/ASTRA_CONTINUATION.md` と `ASTRA_AUDIT_STATE.md` から検証済みStateを復元する。

**今回のユーザー指示 / Policy / Stateを混同しない。** 今回の明示指示は今回何をするか、Policyはどう監査するか、Stateは全面監査Work自身が過去に検証して確定した進捗を表す。通常チャットや別Workの変更・話題を、そのままStateへ昇格させない。

## 3. 監査システム保守

ユーザーが監査policy/guard/State分離等の**監査システム変更を明示した場合**は、必要な監査policyファイルだけアクセス・変更してよい。Stateのread/writeは、その依頼がState移行・復元・修復にも明示的に関係する場合だけ行う。監査システム保守を全面監査の進捗更新と混同しない。

この境界は、通常Sol等がAstra専用Stateをcontinuationとして読んだり、全面監査Workが通常チャットの作業を監査正史へ取り込んだりすることを防ぐ恒久ルールとする。
