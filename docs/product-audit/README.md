# NIARIM App＋Web 製品監査checkpoint

状態: **in-progress。全面監査は未完了**。最新セッションは2026-09-08 18:12:46 JST開始。

再開の手順・Git安全条件は両 `AGENTS.md`、品質・範囲・完了条件は `QUALITY_STANDARD.md`、最新HEAD・環境・次の1手は `docs/work-continuation.md` を正とする。本書は監査マップと検証根拠を保持する。

## 監査マップ

| 領域                                               | 現在地点 / 未完了                                                                                                        |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| 構造・仕様・履歴                                   | App/Webを1製品として復元。最新incoming App `df119850` / Web `439ebf9` を継承                                             |
| 永続化・復元・共有・autosave・削除                 | A02の原子的ZIP置換・保存順序・dirty追跡を実ファイルで検証し本体反映。破損ZIP、復元サイズ、削除競合、保存エラー通知は継続 |
| 認証・API・公開/投稿・YouTube                      | A01/A03/A04検証済み。一覧/投稿フローと全体テストの契約不一致・Provider不足を継続                                         |
| workspace・旧設定・スマホ/DeX                      | 破損JSON/範囲外panel設定等は未精査。実機未検証                                                                           |
| 描画・レイヤー・Undo・timeline・export・音声・素材 | 多数の既存テスト成功を確認。縮小/回転4件の失敗、最新追加機能の統合、詳細UI/UX監査は継続                                  |
| Web全ページ・問い合わせ・7言語・a11y               | Worker6件成功、W07表示CI全ジョブ成功。問い合わせ成功/reset/添付、未設定X案内、最新変更の回帰は継続                       |
| App/Webのブランド・用語・画面・URL                 | ロゴ/書体/coralを維持。自動線画の実装とmockのラベル・値・線画色を照合中                                                  |
| 性能・メモリ・依存・重複                           | 問い合わせ変換ピークとCDK未宣言依存を修正。描画/保存の実測は未完了                                                       |
| 操作手順・プリセット・一括処理                     | 新品質基準の必須範囲。追加されたカスタム自動操作を含め、取消/Undo/復元/進捗/適用範囲を監査する                           |
| SEO・Discoverability・ASO                          | 新品質基準の必須範囲。Webの最新SEO/言語URL実装を継承。公開応答/索引/店舗情報等は未確認                                   |
| 最終商品・実操作レビュー                           | 全幅×PC/SP×7言語・各状態、実端末、最終再監査は未完了。CI成功だけで完了にしない                                           |

製品へのAI/LLM/生成/チャット/アシスタント等の機能追加・提案は禁止。開発支援としてのAI利用と区別する。

## 検証済み改善

| ID / 優先度 | 原因と修正                                                                                                                                      | 根拠                                                                                                                |
| ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| A01 / P1    | auth競合後の無条件lookup再作成でUser IDが分裂し得た。強整合read＋条件付きtransaction＋最大3試行。欠落userを同じIDで修復し既存userを上書きしない | `5076259`、認証4件等の実行テスト                                                                                    |
| A02 / P1    | 既存ZIPの直接上書き/先行削除、同名tmp並行使用、非同期close、保存後のdirty消失、復元/copy/renameのdirty欠落                                      | 修正前12件中11失敗。修正後保存12件＋既存関連16件成功、対象analyze0。下記詳細                                        |
| A03 / P1    | YouTube batch統計URL/part不整合、status未取得、部分失敗を削除扱い。公式形式・status別取得・欠損統計維持・timeout・再確認へ修正                  | `5076259`、YouTube5件/統計batch4件等。[公式API](https://developers.google.com/youtube/v3/docs/videos/batchGetStats) |
| A04 / P1    | タイトルだけのPATCHが公開属性/GSIを上書き。メタデータと公開更新を分離、強整合read/条件付き更新/最大3試行、再公開時score復元                     | `022128d`、旧実装5失敗/1成功→6成功                                                                                  |
| A05 / P2    | CDKが未宣言ts-nodeに依存                                                                                                                        | `022128d`、ts-node10.9.2固定、synth成功                                                                             |

Backend統合checkpoint `022128d`: TypeScript build、**110/110テスト（20ファイル）**、CDK synth成功。実AWSデプロイ・実アカウント操作なし。後続コード全体の合格とは扱わない。

## A02 保存安全性の本体反映

- `lib/engine/niapro_serializer.dart`: project ID単位に最初のawait前からFIFO化。完成ZIPを同一FS内でcloseSync→renameSyncし、正常な通常保存だけdirtyを同期確定。失敗は呼出元へ伝え、後続要求は継続。共有/autosave/save-treeは通常保存用dirtyを消費しない。
- `lib/engine/tile_manager.dart`: writable取得、invalidate、copy、import、renameの全移動タイルをdirty対象へ。autosave等で置き換えた同じパスの画素を旧archiveから流用しない。
- `test/project_save_safety_test.dart`: 実ZIP/画素で失敗時保全と再試行、8並行保存、通常/共有/autosave/save-tree、復元/copy/rename、保存直後の追加編集を検証する12件。
- 修正前 `3aecad6`: **1成功/11失敗**。候補CI `6cb290b`: 対象analyze **0 issues**、関連6ファイル **28/28成功**。[実行34187201572](https://github.com/sakurasemaika-creator/NIARIM/actions/runs/34187201572) のverified.patchを本体と照合済み。
- 対象3ファイルは `df119850` までincoming変更なし。検証済み本体へ反映しpending草案を削除。workflowを通常の保存回帰＋全gateに変更した。最新統合後の実行結果は確認待ち。
- 残り: 破損した通常ZIPからの復旧後の差分保存、復元時TileManagerサイズ、削除と保存の競合、非同期保存エラーの通知。停電/OS強制終了/実端末の耐久性は未検証。

## 全体gateで観測した未解決事項

候補CI `34187201572` のfull-gatesは **802成功/5skip/23失敗**。保存回帰12件は全件成功。以下は失敗領域の分類であり、全件を既存問題と断定するための独立baseline比較はまだ行っていない。

| 失敗数 | 領域 / 観測                                                                                      |
| ------ | ------------------------------------------------------------------------------------------------ |
| 4      | community detail/search/tag-limitのテスト起動にSettingsService Providerがない                    |
| 6      | community APIのisNiarimPublished追加、week/month→weekly/monthly、GET /me/worksのテスト契約不一致 |
| 4      | canvas pinch/angle visualで要求した0.2倍に到達せず1.0のまま。実ジェスチャーと入力条件を優先調査  |
| 2      | canvas mesh/rulerの浮動小数点完全一致（175と174.99999999999997等）                               |
| 3      | FilterKind追加後の固定件数/列挙期待（direct service/engine、visual reaudit）                     |
| 1      | 未使用ARB12キー。最新追加機能で参照状態が変わっている可能性あり                                  |
| 1      | canvas背景構造のソース文字列assertが旧child: CanvasAreaを要求                                    |
| 2      | community shortsの同一アイコン複数、app smokeの旧タグ検索表示期待                                |

- Analyzer: **14 issues**（filter panel未使用field2、community側null-aware等6、canvasテストの波括弧6）。候補対象3ファイルは0。
- Format: **50ファイル**が非整形。候補対象3ファイル以外。現在はさらにincomingがあり、最新結果で差分分類する。
- 失敗テスト削除・無条件skip・成功へのfallbackは行わない。実装不良と古いテスト条件を分け、実際の振る舞いを確認して修正する。

## Web側の確定checkpoint

- W01〜W06 `4815f96`: Worker容量制限・変換メモリ等、模擬メール6件成功。問い合わせの必須入力/エラーフォーカスを実ブラウザ確認。
- W07 `56a6610`: FAQ見出しの存在しないselectorとscrollbar幅の誤検知を修正。失敗を既存JSON検証に差し替えるfallbackを削除。24幅監査を全7言語×PC/SPへ拡張。
- [CI 34186579146](https://github.com/sakurasemaika-creator/NIARIM-web/actions/runs/34186579146): format/audit/final-matrix/14 fullpage jobsがすべて成功。**24幅×2mode×7言語×12ページ=4,032条件**の静止表示検査が成功。
- fr/SPの問い合わせ実画面で、未設定Xへの案内が残る不整合を確認。Web側で修正・検証継続中。最新 `439ebf9` のSEO/CSS等と新しい修正には旧CI結果を流用しない。

## 次の具体作業

1. 保存の本体反映後CIを取得し、最新状態の失敗を分類して直す。
2. Web問い合わせ案内/模擬送信と自動線画mockの最新App整合を実行検証・実画面で確認する。
3. 破損workspace/settingsと未精査の監査マップを進め、重要修正後に必要な全体回帰・商品レビューを行う。

旧一時workflow v8/v11の構文破損は原文を `pending/retired-workflows/*.yml.txt` へ退避。v8は後続v9/v10実装に継承、v11未実行案は完了扱いにしない。Windows/旧Work作業領域の消失した未commit成果は、Git上の検証済み成果と区別する。
