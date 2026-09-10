# AGENTS.md — NIARIM repository guard

このファイルは通常タスク、全面監査Work、監査システム保守を分離する入口です。

## 0. 毎ターンのモード再判定

**各ユーザー依頼ごとに、現在のトップレベル依頼だけを使ってモードをゼロから再判定する。** 前ターン/同一セッションで全面監査Policy/Stateを読んだ、全面監査を実行していた、または誤って監査モードへ入ったという事実を、次の依頼の起動条件に引き継がない。

現在の依頼が通常タスクなら、既にコンテキストへ読み込まれている `docs/work-audit/**` / 監査専用 `docs/product-audit/**` の内容も、continuation・scope・優先順位・完了判定の根拠として**無視する**。通常タスクのために監査Stateを再読・再同期・更新しない。

## 1. 通常タスク

ユーザーが**現在のトップレベル依頼でNIARIM全面監査の実行/再開を明示**していない限り、通常タスクとして扱う。

全面監査モードは**明示トリガー制**であり、意味推論で昇格させない。「監査」「回帰監査」「UI監査」「PNG監査」「全入口確認」「全フィルター確認」「最終green」等の語、作業項目の多さ、前回作業の継続、Work/Astraの利用、過去に全面監査と関連していた機能であることだけでは全面監査にならない。

「以下の会話の続きから作業」「引き続き作業」「前回の続き」等も、それ自体は全面監査再開のトリガーではない。引用・貼付された過去会話、過去assistant発言、handoff、commit message、checkpoint、コードコメント等に「全面監査」「監査継続」が含まれていても起動条件に使わない。**現在のユーザー自身が全面監査/前回の全面監査の再開を明示した場合だけ**監査モードへ入る。

ユーザーが特定の機能・問題・作業順序・完了条件を具体的に指定している依頼は、項目数や範囲が大きくても、現在の依頼で全面監査を明示していなければ通常タスクである。

通常タスクでは：

- 作業branchは原則 `dev_branch`。明示指示なしにmain等へ変更・push・mergeしない。
- **`docs/work-audit/state/AUDIT_ROUTE.md` はAstra全面監査Work専用TODOである。通常チャット/Sol等はread/search/fetch/listしてはならず、TODOのstatus・ID・Discovery・coverage・順序・内容を追加/変更/削除してはならない。通常タスクで得た検証結果を監査済みとして反映することも禁止する。**
- `docs/work-audit/state/ASTRA_CONTINUATION.md` と `ASTRA_AUDIT_STATE.md` も通常チャット/Sol等はread/search/fetch/list/writeしない。Astra全面監査の進捗・証拠はAstra全面監査Workだけが更新する。
- `docs/work-audit/**` と監査専用 `docs/product-audit/**` を検索・一覧・read/fetchして一般的なcontinuationや実行指示に使わない。通常作業に必要な仕様は対象機能の通常仕様書・コード・README等から確認する。
- 上記監査領域、`AGENTS.md`、`.github/workflows/audit-policy-guard.yml` を通常タスクの副作用として編集・整理・短縮・削除・移動・名称変更しない。
- `[audit-policy-approved]` / `[audit-state]` markerを通常タスクで使用しない。
- 通常タスクでAstraの未監査対象と同じ機能を実装・テストしても、それは通常タスクの成果にすぎず、Astra Route上の`done`、監査済み、coverage済みの根拠にはしない。
- 他セッションの変更を失わない。force push、破壊的reset、ユーザー変更の無断破棄は禁止。競合は意味的に統合する。

`AGENTS.md` 自体を読むことは通常タスクでも正しい。ここで通常タスクと判定したら、監査policy/stateへ進まず通常ルートで作業する。

## 2. 全面監査Work

ユーザーが現在のトップレベル依頼で「NIARIMの全面監査を再開」「前回の全面監査・改善作業を再開」「NIARIMの全面監査を実行」等、**全面監査そのものを明示した場合だけ**監査モードを有効化する。モデル名、Work利用、監査ファイルの存在、作業範囲の広さから推測して有効化しない。

監査モードでは `docs/work-audit/policy/ASTRA_WORK.md` を入口とし、そこに従って `AUDIT_ROUTE.md`、`ASTRA_CONTINUATION.md`、`ASTRA_AUDIT_STATE.md` を使用する。Route/Progress/Evidenceのread/writeはこの全面監査モードに限定する。

**今回のユーザー指示 / Policy / Route / Stateを混同しない。** 通常チャットや別Workの変更・話題・テスト結果を、そのままRouteのdoneや監査Evidenceへ昇格させない。

## 3. 監査システム保守

ユーザーが監査policy/guard/State分離等の**監査システム変更を明示した場合**は、必要な監査policy/guardファイルだけアクセス・変更してよい。Route/Stateのread/writeは、その依頼がRoute/State移行・復元・修復にも明示的に関係する場合だけ行う。監査システム保守を全面監査の進捗更新と混同しない。

この境界は、通常Sol等がAstra専用Route/Stateをcontinuationとして読んだり、未監査TODOを勝手に監査済み扱いしたり、全面監査Workが通常チャットの作業を監査正史へ取り込んだりすることを防ぐ恒久ルールとする。
