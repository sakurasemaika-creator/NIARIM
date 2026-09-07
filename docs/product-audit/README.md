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

| 領域                                               | 状態 / 次の確認                                                                                                     |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| 構造・仕様・履歴                                   | 入口/依存/CI/全体構造を把握。00/01/31・CLAUDE、Web DESIGN/guide等確認。最新差分を反映済み                           |
| 永続化・復元・共有・autosave・削除                 | 前回未commit実装は環境再作成で消失。現行コードから復元・実行検証を再開                                              |
| 認証・API・公開/投稿・YouTube                      | ID競合と統計APIを修正・単体検証。公開設定PATCHの競合も修正・110件検証済み。一覧の整合性、最新投稿フローの詳細は継続 |
| workspace・旧設定・スマホ/DeX                      | 未精査                                                                                                              |
| 描画・レイヤー・Undo・timeline・export・音声・素材 | 既存テスト/構造の確認まで。詳細監査と実画面は未完了                                                                 |
| Web全ページ・問い合わせ・多言語・a11y              | Workerの容量制限等を修正。問い合わせ/言語メニューを実ブラウザ検証中                                                 |
| ブランド・サポート・用語・URL                      | App/Webのロゴ・書体・coralを継承。公開設定・用語・未設定外部リンクは継続                                            |
| 性能・メモリ・重複・依存                           | 問い合わせ変換ピークとCDK未宣言依存を修正。描画/保存の実測は未完了                                                  |
| 実画面・keyboard/mouse/touch                       | Web問い合わせのエラーフォーカス確認済み。他画面/実端末は未完了                                                      |

## 問題と採択状況

| ID / 優先度             | 根拠・修正 / 状態                                                                                                                                                                                                      |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| A01 / P1 データ整合性   | authの競合後の無条件lookup再作成がUser IDを分裂させ得る。強整合read＋条件付きtransaction＋最大3試行。同じIDで欠落user修復、既存user上書き禁止。検証済み                                                                |
| A02 / P1 保存安全性     | 差分保存で元ファイルを先に削除、フル保存で直接上書き、保存が並行しdirty確定にawaitが挟まる。前回の未commit実装は残っていない。完成ZIPの同一FS置換・project単位の順序保証・同期dirty確定を復元し検証する。次の最優先    |
| A03 / P1 統計・公開状態 | batchGetStatsのURL/partが公式形式と不一致、statusは返らず、部分失敗をdeleted扱い。URL修正＋status別取得＋欠損数値を維持＋timeout。APIキーで読めない動画は削除と断定せずprivate相当の非表示にし再確認。検証済み         |
| A04 / P1 公開状態競合   | タイトルだけのPATCHから公開属性/GSI更新を分離。明示的公開変更はYouTube状態/統計/ブクマの条件付き更新・強整合再読込・最大3試行。非公開からの再公開時も現在の統計でscoreを復元。実行6test成功、旧コード5失敗/1成功で再現 |
| A05 / P2 CI再現性       | cdk.jsonの未宣言ts-nodeをdevDependency/lockに10.9.2で固定。ローカルsynth成功                                                                                                                                           |

A03の根拠：[Google公式batchGetStats](https://developers.google.com/youtube/v3/docs/videos/batchGetStats)。統計失敗IDは削除の証拠にならず、statusはvideos.listから取得する。古いソース文字列assertの1件を、partial failure・非表示・競合・tombstoneの実行テストへ置き換えた。公開設定や投稿履歴を消す変更はしない。

## 検証・実画面・環境

- WorkはLinux、Node 24.19.0（CIは22）。既存pubspec.lockを変えずFlutter 3.44.7で依存復元を実施。SDK起動時のAzureメタデータ検出が自動審査で拒否されたため、SDKソースの分岐を確認し、メタデータへアクセスしない `CI=true` で実行する。
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

## 2026-09-08 JST 再開checkpoint

- 最新開始HEAD App `f297642` / Web `d8fc6cf`。両AGENTS・QUALITY_STANDARDを最初に確認し、既読のCLAUDE/引き継ぎ資料との差分なしを確認。28継続タスクも現行実装と照合する。
- 前回push App `5076259` / Web `4815f96` は保持。App自動線画フィルタ、Web24幅監査・community狭幅・同意checkboxなど新規incomingを維持。
- A04/A05を復元し、`npm run build`成功、`npm test` **110/110成功（20ファイル）**、CDK synth成功。公開設定の古いソース文字列assert1件を実行テスト6件へ置き換えた。
- データ永続化・破損workspace/settings、全Flutter検証・UI/UXは未完了。最新Web CIは288画面の操作領域監査で失敗しており、原因を追跡中。
- 次の1手：A02原子的保存とautosave復元後の差分保存を、実ファイル/タイルの往復テストで再現して直す。
