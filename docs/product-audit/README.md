# NIARIM App＋Web 製品監査・再開記録

状態：**進行中。全体監査は未完了**。2026-09-07 Work checkpoint。

## 再開・Git安全条件

- App `sakurasemaika-creator/NIARIM` / Web `sakurasemaika-creator/NIARIM-web`。両方 `dev_branch` のみ。force push、破壊的reset、本番データ操作は禁止。
- 再開・checkpoint・push前に status / HEAD / fetch / ahead-behind / incoming diff を確認し、変更の影響がある領域だけ再監査する。
- Work checkout: `/workspace/scratch/dd8428d3aee3/NIARIM` と同階層の `NIARIM-web`。
- 今回開始時は両方clean、stash・未push commitなし。HermesのWindows作業領域にあったSwift/lockの未commit変更・stashは、このcheckoutにはない。取得した最新commitのSwift/lockを維持する。
- 今回の初期HEAD App `069c9e8` / Web `10116b5`。追加指示後fetchし、App **`353f94c`** / Web **`e53f248`** へincomingを確認してfast-forward。実投稿・認証retry・保存確認UI・Prism・Web heroの並行変更を継承した。
- HermesのREADMEは両repoとも全領域が調査中/未確認。完了として継承できる領域はない。参照されたWindowsのinventory/findings原本はリポジトリに含まれていない。

## 監査マップ

| 領域 | 状態 / 次の確認 |
| --- | --- |
| 構造・仕様・履歴 | 入口/依存/CI/全体構造を把握。00/01/31・CLAUDE、Web DESIGN/guide等確認。最新差分を反映済み |
| 永続化・復元・共有・autosave・削除 | 保存の原子的置換・順序保証を実装中。回帰test追加済み、Flutter検証待ち |
| 認証・API・公開/投稿・YouTube | ID競合と統計APIを修正・単体検証。公開設定PATCHの競合、一覧の整合性、最新投稿フローの詳細は継続 |
| workspace・旧設定・スマホ/DeX | 未精査 |
| 描画・レイヤー・Undo・timeline・export・音声・素材 | 既存テスト/構造の確認まで。詳細監査と実画面は未完了 |
| Web全ページ・問い合わせ・多言語・a11y | Workerの容量制限等を修正。問い合わせ/言語メニューを実ブラウザ検証中 |
| ブランド・サポート・用語・URL | App/Webのロゴ・書体・coralを継承。公開設定・用語・未設定外部リンクは継続 |
| 性能・メモリ・重複・依存 | 問い合わせ変換ピークとCDK未宣言依存を修正。描画/保存の実測は未完了 |
| 実画面・keyboard/mouse/touch | Web問い合わせのエラーフォーカス確認済み。他画面/実端末は未完了 |

## 問題と採択状況

| ID / 優先度 | 根拠・修正 / 状態 |
| --- | --- |
| A01 / P1 データ整合性 | authの競合後の無条件lookup再作成がUser IDを分裂させ得る。強整合read＋条件付きtransaction＋最大3試行。同じIDで欠落user修復、既存user上書き禁止。検証済み |
| A02 / P1 保存安全性 | 差分保存で元ファイルを先に削除、フル保存で直接上書き、保存が並行しdirty確定にawaitが挟まる。完成ZIPの同一FS置換・project単位の順序保証・同期dirty確定を実装。未検証、次の最優先 |
| A03 / P1 統計・公開状態 | batchGetStatsのURL/partが公式形式と不一致、statusは返らず、部分失敗をdeleted扱い。URL修正＋status別取得＋欠損数値を維持＋timeout。APIキーで読めない動画は削除と断定せずprivate相当の非表示にし再確認。検証済み |
| A04 / P1 公開状態競合 | worksUpdateは強整合readになったが、titleだけのPATCHも古い公開状態/GSIを書き直す。統計/公開変更との競合条件不足。要修正 |
| A05 / P2 CI再現性 | cdk.jsonが未宣言ts-nodeをnpxで都度取得。devDependency/lockへ固定する |

A03の根拠：[Google公式batchGetStats](https://developers.google.com/youtube/v3/docs/videos/batchGetStats)。統計失敗IDは削除の証拠にならず、statusはvideos.listから取得する。古いソース文字列assertの1件を、partial failure・非表示・競合・tombstoneの実行テストへ置き換えた。公開設定や投稿履歴を消す変更はしない。

## 検証・実画面・環境

- WorkはLinux、Node 22系。Flutter 3.47.2 SDKを準備中。SDK起動時のAzureメタデータ検出が自動審査で拒否されたため、SDKソースの分岐を確認し、メタデータへアクセスしない `CI=true` で実行する。
- 旧baseline backend: tsc成功、81件中78成功/3失敗（古いソース文字列assert）。並行開発の修正を取り込み済み。
- **統合後 `npm run build` 成功、`npm test` 105/105成功（19ファイル）**。認証4、YouTube5、統計batch4の実行テストを追加。
- `AWS_EC2_METADATA_DISABLED=true npm exec cdk -- synth --quiet -c googleClientId=ci-dummy -c youtubeApiKey=ci-dummy` 成功。実AWSデプロイなし。
- Web Worker新規6test成功（実メールなし）。Web問い合わせで入力不足→同意欄へのfocusを実ブラウザ確認。
- Flutter analyze/full suite/APK/実画面は未完了。Google/YouTube実アカウント、AWS実環境、Android/DeX実機も未検証。
- 旧監査dashboardのcompletedは本監査の完了根拠にしない。

## checkpoint / 現在地点 / 次の具体作業

- このREADMEを含む最初のbackend修正checkpointを作成する。commit IDは `git log -- docs/product-audit/README.md` で取得できる。pushは次のGit確認後。
- App保存の未commit変更は保持中、テスト未実行のためbackend checkpointから除外。
- 次：Flutter bootstrap→保存test→全analyze/test、A04競合修正、Web入力/言語のUI回帰、未精査領域を順番に監査する。
- UI全体・スマホ/PC/DeX・Workspace・App/Web横断・最終商品レビューは未完了。テスト成功だけで全体完了にしない。
