# NIARIM Audit Evidence

今回の新規Routeの実検証だけを記録する。旧監査からの完了引継ぎなし。

## Bootstrap

- 両AGENTS・ASTRA_WORK・全品質基準を確認。
- 現行App/Webのrouter、直接遷移、screen/widget、state/input、全default資産、filter/effect/command、API、native/runtime/sourceを棚卸し。
- 全要件とsourceの割当はAUDIT_INVENTORY.json、固定順序と定義hashはAUDIT_ROUTE_LOCK.json。
- coverage検査結果はAUDIT_COVERAGE_CHECK.jsonへ保存する。構造coverageであり実機能の合格ではない。
- 実監査は全件todoから開始。

## A001 — 起動サービス・初期化契約（非UI）

status: done（2026-10-10、製品修正 App `35d229e`、証跡 https://claude.ai/artifact/C6t3uteANocXs9nTLizazi#A001）

### A001/S1-S3 restore / source order / corrupt settings reproduction

- locked Route version `2026-09-09-initial-v1`; current_id=A001。Routeは再構築・並べ替えしていない。
- `main()` order: Widgets binding → AppErrorReporter.install → bundled font license registration → orientation → `await buildAppProviders()` → `runApp`。
- `buildAppProviders()` はSettings/Performance/Premium/Advertising/Projectから各制作service、HomeWidget/Auth/Community/ShareIntentまで逐次初期化する。
- run `34533483148` のraw logsで、壊れた`custom_size_presets`と`theme_current_json`が未捕捉FormatExceptionとなりstartupを中断することを再現。root causeはpersisted structured settingsのall-or-nothing decode。

### A001/S4 persisted JSON recovery — verified

- one-shot v2 run `34575385855` conclusion `success`。job `repair-and-verify` の全step successを確認。
- `flutter test --no-pub --reporter expanded test/startup_settings_recovery_test.dart`: 3/3 PASS。
  - damaged size presetを隔離しvalid settingsをload。
  - damaged current themeはfallbackし、raw persisted JSONを上書きしない。
  - damaged saved themeがあってもvalid neighboring custom themeを保持し、元のpersisted listも保持。
- `flutter analyze lib/services/settings_service.dart lib/services/theme_service.dart test/startup_settings_recovery_test.dart --no-fatal-warnings --no-fatal-infos`: `No issues found!`。
- verified repair commit `770e2c57d0a77c11c1a174b5a07243a71383f369` がdev_branchへpush済み。

### A001/S5 duplicate initialization / failure visibility — verified portion

- source reviewでAdvertisingService.initのprovider/listener重複とAppErrorReporter.installのhandler再wrapを確認。GoogleAuthService.initには既存 `_initialized` guardあり。
- AppErrorReporter idempotent guard commit `5d71d158c0aae465dfa9122232ff01b52f6e18bd`、AdvertisingService lifecycle guard commit `9ea1c72c54f9d5ac73825c661c851083e484408d`。
- one-shot run `34575561261` conclusion `success`。job `verify-and-finish` のtargeted contractsが完走。
- `flutter test --no-pub --reporter expanded test/startup_service_contract_test.dart`: 2/2 PASS。
  - AdvertisingService initを2回呼んでもPremium listener addは1回、dispose時removeも1回。
  - AppErrorReporter.installを2回呼んでもFlutterError/PlatformDispatcher handlersは同一wrapperのまま。
- ProjectService startup recoveryの個別破損file/outer storage catchを`AppErrorReporter.record(error, stackTrace)`へ接続し、既存のskip/empty-state非fatal recoveryは維持。
- touched analyzeは`startup_service_contract_test.dart`の不要な`dart:ui` import info 1件のみ。workflowは`--no-fatal-warnings --no-fatal-infos`でsuccess。製品source側のerror/warningは記録されていない。このinfoは後続cleanup対象だがA001 contract failureではない。

### A001/S5d partial-bootstrap cleanup + failure surface/retry — verified

- root cause: `main()`は`buildAppProviders()`の例外で`runApp`へ到達せず、無表示のまま停止。途中まで作ったServiceを破棄するownershipが無く、同一プロセスでのやり直しは購読・リスナー重複の危険があった。
- fix（`35d229e`）: 各段階を`enter(step)`／`own(service)`で記録し、失敗時は逆順disposeして`AppStartupException(step, error, stackTrace, languageCode)`を投げる。`main.dart`は`StartupFailureApp`（7言語・既定テーマ・同梱フォント・「もう一度試す」「詳細をコピー」「詳細」）を出し、`_startApp`を再実行。debug限定の失敗注入 `--dart-define=NIARIM_DEBUG_FAIL_STARTUP_STEP`。
- targeted: `test/startup_failure_recovery_test.dart` — 全28段階それぞれで失敗→作成済みServiceが全てdispose済み（`ChangeNotifier.debugAssertNotDisposed`で確認）→同プロセスで再起動成功、失敗段階名の報告、起動失敗画面の7言語・端末言語fallback・再試行の二重押し防止・詳細コピー。mutation: dispose loopを外すと`SettingsService built before performance is disposed`で失敗することを確認。
- 実画面（Linux debug/Xvfb, 1280×720 ja, 390×844 en/ko/zh/zh_Hant/fr/es）: 失敗画面→詳細展開→もう一度試す→起動画面（attempt 2成功、`Startup failed`ログ1件）。全言語で欠字・はみ出し無し。

### A001/S5e remaining startup side effects — verified

- GoogleSignIn `initialize`（1プロセス1回）を`Expando`で使い回し、失敗した初期化は次の試行でやり直す。`test/google_auth_init_once_test.dart`（`--dart-define=NIARIM_GOOGLE_CLIENT_ID=test`で3/3 PASS、未設定時はskip）。
- `ShareIntentService`はチャンネルのハンドラーを持ち主だけが外す（後から作った方を外さない）。
- 新規root cause: SharedPreferencesの`getInt`等は型不一致で例外。`language=5`・`undo_limit="fifty"`の設定で実画面再現：起動失敗→再試行しても失敗（永久に起動不能）。fix: `lib/utils/tolerant_preferences.dart`の`readXxx`へlib配下100か所を置換（型違いはnull扱い、値は書き換えずAppErrorReporterへ記録）。test: lib配下の全リテラルキー（50件超）へ別型を入れて起動成功・値保持（性能の品質レベル2キーだけは初回同様に再判定して保存）、`prefs.getXxx(`残存0件のguard。
- 描画エラー表示（ErrorWidget置換）が日本語固定→祖先ロケール／端末言語の訳で表示。`save_error_handling_test`をja/enへ。
- 同梱フォントライセンス登録は`main()`でのみ1回（再試行は`_startApp`のみ）、`font_license_test` PASS。Premium/AdMobは`isMonetizationEnabled`（2027-01-01）前にストア・SDKへ接続しない（gate実装は日付比較のまま、固定trueでないことをsourceで確認）。HomeWidget/Project/Autosaveのinitはタイマー・購読を開始しない。

### A001/S6 fresh / warm / corrupt real startup — verified

- fresh（空のHOME）→起動画面→作品をつくる→ホーム。warm（同じHOMEで再起動）→同様、設定12キーとも変化0。
- 壊れたJSON（`theme_current_json`・`theme_presets`・`custom_size_presets`の一部）＋言語en→起動成功、4値とも元のまま保持。
- 型違い設定→修正前は永久失敗、修正後は起動成功・元の値保持（上記）。
- 回帰: `flutter analyze` 0件。全件`flutter test` 成功1910・スキップ8・失敗4（失敗は既知のapp_web_reference_*3件とtexture_filter_gold_palette_test1件のみ）。

### A001 判定

- 機能 PASS / 挙動 PASS / 見た目 PASS（起動失敗画面）/ 継続性 PASS（保存値を上書きしない・やり直し可能）/ 製品品質 PASS。
- 未確認（環境なし）: Android実機・低性能端末での起動時間・プロセスlifecycle。NATIVE系ID（A098等）で扱う。
- Discovery: DISC001（初回起動の言語が端末言語に関係なく日本語）、DISC002（エラー記録を利用者が見る手段が無い）。

## A002 — 起動画面 /・2導線・テーマ救済

status: done（2026-10-10、製品修正 App `35d229e`、証跡 https://claude.ai/artifact/C6t3uteANocXs9nTLizazi#A002）

### 実操作（Linux debug/Xvfb、390×844 ja基準）

- 自動遷移なし。作品をつくる→ホーム→戻る→起動画面。作品広場→作品広場→戻る→起動画面。
- 連打: 90ms間隔2回・30ms間隔3回とも、戻る1回で起動画面（履歴の二重化なし）。作品広場も同様。
- 先読み中遷移: 起動直後に遷移しても例外なし（ログ確認）。
- 縦横切替: 390×844↔640×360等をウィンドウのresizeで切替、並びが縦↔横へ切り替わる。

### 発見と修正

1. 押下フィードバック・キーボードフォーカスが不可視（root cause: グラデーションを`Container`で描きInkWellのink層を覆っていた）→`Ink`へ、波紋/ホバー/フォーカス色を文字色から作成、タイル外側3pxのフォーカス枠。実画面で押下中の波紋、Tab×1/×2の枠、Enterで遷移を確認。スクリーンリーダー: `isButton`が無かった→`Semantics(button: true)`（test `matchesSemantics`）。
2. 文言の欠け: en「Browse posted …」、fr「Place des …」、es「Plaza de O…」、ko「NIARIM 갤…」と「만들／기」、zh/zh_Hant「NIARIM 作…」→最大3行で折り返し、2つのタイルの高さを揃える（Materialの`bodyMedium`を土台に計測）、韓国語は語中で折り返さない（`lib/utils/line_break.dart`）、ko/zh/zh_Hantの訳を他画面と同じ「작품 광장／作品广场／作品廣場」へ統一。OSの文字サイズ倍率に合わせタイル幅を拡大。
3. 小幅横画面のはみ出し: 568×320で80px、640×360で8px「作品をつくる」が画面外→横画面と標準文字の縦画面は幅・高さに収まるよう`FittedBox(scaleDown)`、縦画面の間隔を40→12pxまで詰める。文字拡大時の縦画面はスクロール。
4. テーマ救済: 読めないテーマ（文字色=背景色）で固定色の「テーマをもとに戻す」のみ表示→押下で既定配色＋SnackBar→再起動後も既定、ボタン非表示。読めるテーマ・既定ダークでは非表示。

### 表示マトリクス・回帰

- `test/splash_layout_test.dart`: 7言語×文字1.0/1.3/2.0×(390×844, 320×568, 568×320, 640×360)=84通りで、文言の省略なし・2タイル同寸・横画面と標準文字の縦画面は画面内。監査の表示マトリクス24幅×SP(844)/PC(900)×7言語=336通りで例外・省略・寸法差・画面外0件（`build/splash-matrix/manifest.json`、全336画像を言語×モードの14枚のシートで目視）。
- 回帰: `home_widget_shortcut_design_test`（起動画面とホーム画面ウィジェットの意匠一致。タイルの探し方を`Ink`へ）、`text_scale_layout_test`、`theme_contrast_rescue_test`、`app_smoke_test`、`visual_smoke_test`、`all_routes_screenshot_audit_test`ほか66件 PASS。`flutter analyze` 0件。

### 判定・申し送り

- 機能 PASS / 挙動 PASS / 見た目 PASS / 継続性 PASS / 製品品質 PASS。PC幅（1920等）では中央に小さく置かれるが、2択のみの画面として妥当と判定（変更なし）。
- 未確認（環境なし）: 指のタッチ・Android実機の見え方（UA項目のため実機は必須条件外。NATIVE系IDへ）。
- 後続IDへの申し送り（既存IDで扱う。Discoveryではない）:
  - A003: 初回案内「手描きアニメーションを制作できます」は「はじめる」を押すまで再起動のたびに出る。
  - A079/A080（ホーム画面ウィジェット）: ウィジェット画像はサブ文言を1行で切るため、en/fr/esの「作品広場」ウィジェットで文言が省略される可能性（起動画面は修正済み、ウィジェットは未確認）。
  - A102: 韓国語の語中折り返しはアプリ全体の問題（起動画面のみ対処）。
  - A103: 起動画面は全プロジェクトのサムネイルを先読みデコードする（大量作品時の負荷とメモリを実測する）。
  - 作品広場（該当ID）: 390px幅でアプリバーの題名が「作…」に省略される。

## 2026-10-06 state freshness synchronization

- 最新の**製品実装**として確認したApp `dev_branch` は `ce94a15597f213a168abc682a8f49d53fa3c8508`。
- 最新の**製品実装**として確認したWeb `dev_branch` は `ed944b291732f5d9bc4ca0617b7213f8ec212be4`。
- その後の `dev_branch` の先端には監査Policy/Route/Progress/Evidence/Verifierだけを変更する `[audit-*]` commit が積まれている。したがってbranchの最新SHAと製品実装snapshot SHAは同一とは限らない。
- 監査開始時は必ず現在の `dev_branch` HEADを取得し、開始時点以降の変更について監査対象コードが変わっていないか確認する。
- 以前の `770e2c57...` を現在製品HEADとして扱わない。A001は依然 `in_progress` であり、過去のEvidenceから完了を推定しない。
