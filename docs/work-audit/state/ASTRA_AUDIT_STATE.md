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


## 2026-10-21 / A003 — current-head execution checkpoint (not done)

- Start/re-fetched HEAD: App `ec93d84c8156bdeb12573e3821a685ef2ed4e6cd`, Web `de017642ba6f1c642e3e26c242695b9755286eda`.
- Full state / baseline / delta preflight: PASS, mirrors consistent, locked definition/inventory unchanged. Baseline done2/628, current A003; Delta todo37.
- Environment: Flutter 3.47.7 stable / Dart 3.13.5; Linux debug production runner, software GL, Xvfb TCP local display, xdotool mouse/keyboard; isolated XDG paths. Flutter metadata probe was rejected by automatic approval review. SDK BotDetector source confirmed CI short-circuits that probe; subsequent commands use CI=true/BOT=true and FLUTTER_SUPPRESS_ANALYTICS=true. No metadata endpoint is used by the safe configuration.

### A003/S2 — tab scope and selected semantics

- Before: home_navigation_contract_test 3/3 FAIL on the current product. Hidden project selection remains actionable on Works; project search input remains on unrelated tabs; selected semantics absent.
- Direct production UI before: created `A003 protected project` via new-project form, returned to home, long-pressed the project, switched to Works. Selection count and cut/copy/trash remain while the target is offscreen. Project search `query` also remains on Works. Actual captures opened and inspected.
- Fix: leaving Projects clears selection/search/query and unfocuses search. Project sort/view/search/paste controls and edit shortcuts apply only to Projects; works/bookmarks show their own title. Tabs expose selected state and button semantics.
- Targeted regression: home navigation, export failure/retry, existing home favorites responsive, project tag search: 11/11 PASS. Touched analyze: No issues found. Linux debug build PASS. These are automation/build evidence, separate from direct UI verification.

### A003/S3 / DISC003 — exported-list failure recovery

- Direct production reproduction: absent documents directory resolver produced an uncaught splash prefetch MissingPlatformDirectoryException; Works remained a spinner. This is an actual error path, not a declared success/empty state.
- Root cause: splash unawaited prefetch has no error handler; FutureBuilder conflates error with waiting. Existing reload returns a Future from a setState arrow callback.
- Fix: record failed optional prefetch; explicit translated load-failure message and Retry on Works and folder view; synchronous setState callback and caught refresh failure.
- Direct post-fix: opened Works→read error message/Retry→retried while unavailable→same recoverable error→restored real xdg-user-dir/documents configuration→Retry→empty exported-works state. Inspected actual screenshots; post-fix app log has no uncaught directory exception. Full 7-language/matrix/folder conditions remain open.

### DISC004 — observed initial-save data loss, priority follow-up

- Under the same missing documents directory condition, new-project creation still navigated to a usable canvas and the home list contained the project. It was absent after restarting the runner.
- Source confirms createProject calls _saveAsync; that catches serializer errors and substitutes an empty File. Initial persistence is neither awaited nor surfaced. This is a data-loss risk and is registered for immediate treatment before A003 can close.

### Evidence and incomplete work

- Local execution logs: a003-contract-before.log, a003-export-failure-before.log, a003-regression.log, a003-analysis.log, linux-build-before/after.log. Production captures under native-evidence/A003-*. Full-root originals retained; cropped derivatives must use the actual client origin, not the erroneous doubled xdotool geometry reported by this WM.
- Drive binary backup/manifest: pending at this checkpoint; no upload claimed yet.
- Required next: direct post-fix selected-project/search PC/SP operations, full home/drawer/first-use/state and display matrix, DISC004 fix/regression/persistence. Neither A003 nor the comprehensive audit is complete.


### 2026-10-21 additional checkpoint — A003/S4 + DISC004 priority fix

- Authorized push completed for App `184ef3d743650f2d44ad926d7fa9447954dfda75` and Web `7d021c84fc9e3884acfc7ef27018fef87c932741`. Tested local trees exactly match the published trees; fetched and checked. This entry describes the next tested working-tree checkpoint anchored at that App HEAD.
- Actual post-fix UI: SP390×844 and PC1440×900 ja, long-press project→Works clears selection/actions; enter project query→Works closes search and shows Works title. Actual images opened and inspected. These two viewports are not the 336 display matrix.
- DISC004 fix: initial NiaproSerializer.save is awaited before publishing project/scenes/TileManager/counter; failure disposes the unpublished TileManager and rethrows. New-project form prevents duplicate submission, displays localized Creating, retains inputs on failure and presents a generic inline liveRegion error. Error does not disclose raw filesystem paths or cover the retry control.
- Mutation/reproduction before fix: initial-persistence tests fail because success has no on-disk file and unavailable documents still returns a Project. After fix: initial save is immediately readable by a fresh service; unavailable documents throws with zero published projects/notifications; actual filesystem blocker remains byte-for-byte and retry succeeds after removal.
- UI guard test: two rapid submissions cause one call; busy control disabled; failed request keeps name; retry starts a second call; completion after leaving causes no navigation/exception. Targeted storage/home/folder regression: 19 PASS.
- Broad service regression: 79 files, 182 PASS/4 FAIL. The same four save-slot tests fail before this change because host CPU auto-selects high/tree while tests assume slots. Fixtures now explicitly select medium/slots in three tests and low/five-slot complete SP layout in the visual test; all four follow-up tests PASS. Existing assertions/actions retained. This is fixture determinism, not product quality-mode coverage.
- Full flutter analyze: No issues found. Linux debug build succeeds. Actual native binary was rebuilt with these product changes; tests and direct runner evidence remain separate.
- Actual DISC004 recovery: temporary absence of xdg-user-dir inside the isolated audit runtime→new project create stays in form with failure message→existing saved project count remains one→restore real resolver→retry submitted name `DISC004 retry survives restart`→canvas→terminate/relaunch runner→Home contains new and existing project. On-disk ZIP manifest confirms name, fps12, duration10, size1280×720. Resolver restored; no user storage touched.
- Evidence archive: `audit-evidence-2026-10-21-A003-DISC004.zip`, 862508 bytes, SHA256 `02fe5c2c7390f8839ccc8152422770234b7b1680eab94b8eb360ac0c8d592f19`, 49 entries. Includes original roots, corrected crops, manifest and relevant logs; local VM service URLs redacted. Archive ZIP integrity checked. Product diff identity is in manifest.
- Drive backup: **uploaded / readback verified** on 2026-10-21 after explicit user authorization for this ZIP/destination. File [audit-evidence-2026-10-21-A003-DISC004.zip](https://drive.google.com/file/d/1V357zq7uAQmhZt7wBaPRKj0NPnlaBlvr/view?usp=drivesdk), id `1V357zq7uAQmhZt7wBaPRKj0NPnlaBlvr`, 862508 bytes. Readback confirms filename, application/zip MIME, byte size and parent `1fiZEjCVqLtNVk_mkNIOUC3MWn6ys6e8q`. Local ZIP SHA256 `02fe5c2c7390f8839ccc8152422770234b7b1680eab94b8eb360ac0c8d592f19`; local ZIP integrity verified. Earlier automatic approval rejection was resolved by the subsequent explicit user authorization. This closes backup for this checkpoint ZIP only; earlier A001/A002 evidence and final audit closure are not declared complete.
- Remaining: full A003 first-use/drawer/empty-large/state/7-language matrix/theme/textScale/continuity, DISC003 folder/languages/retry branches, DISC004 remaining language/device/storage failure branches; all later Baseline/Discovery/Delta/final Visual requirements. Android/DeX/stylus/multitouch and Linux codec limitation remain. A003 and DISC003/004 are not done; full audit is not complete.

### 2026-10-21 authorized evidence backup completion

- User explicitly authorized saving the evidence ZIP to the previously identified audit Drive folder. Upload succeeded and connector metadata readback verified the returned file and destination.
- Product fix was published at App `41413d5951835be21e11957ad42b0f869b900ecb`; mirrored State at Web `b8cc30ed9bca0516efd5c9fc9d440232a94e9866`. Re-fetched both dev_branch heads before this State-only update; both matched. No product or audit-completion status changed.
- Remaining work stays at A003 in_progress and the previously recorded Discovery/Delta/Visual requirements.

### 2026-10-21 S5復元・S6 current-source checkpoint — A003は未完了

- 再開時に両dev_branchをfetch/fast-forwardし、App `b6cd7e28abd97c9536ae562be2edbc14bd402de8` / Web `a217e33bca378dc8bf36a5c13d1d95c36acc0e1f` を一次事実として再確認。S5の未pushローカルcommitは今回の環境には無かった。過去の完了申告をremote反映済みと扱わず、保存済みDrive ZIPから復旧し、現在sourceで再検証した。
- 旧S5 main ZIPはDriveから再取得し、64,559,011 bytes / 2,388 entries、SHA256 `25e868a789e53118a6a9715a2eb2205e54d3a0a100409f19f5d38f17efa7b26d` と全entry CRC一致。ZIP内の20製品source中18件をbyte-identicalに復元（ARB/generated全14件、theme_service、color_contrast、ProjectList、共通empty）。Home/Drawerとtestは再構成して今回のテスト・native実画面で検証。旧S5の全証拠を現在の全面完了へ昇格させていない。
- S5修正を復元: 実accent/selectionを不透明な背景へ合成し、その実色に対してonPrimary/onSecondaryを4.5以上へ選ぶ。28 built-in＋透明/相反customのテスト、保存preset値不変を確認。Drawer headerは単色＋不透明な前景、共通emptyはshort-heightで情報を切らずscroll可能、ProjectListの重複emptyを統合。Bookmarksの未実装扱いを7言語で実際のempty文言へ改め、作品広場への明示導線を追加。French Startの語中改行をdialog幅/paddingで防ぐ。これらはDISC005/006の全caller closureを意味しない。
- 追加の実画像検査で、白accent時のBookmark icon/CTA不可視化と既定Home selected tab比2.787を発見。再現test FAIL→背景とのcontrastから前景を選び、tab文字/indicator、Bookmark icon/CTAを修正→targeted PASS。保存色や収益化gateは変更していない。カスタム配色の起動画面ではlogo/tilesの低contrastをnativeで観察しており、DISC005の残るA002関連確認として保持する。
- DISC007再現: production serializerで120件の実ファイルfixture（32x32、fps1、duration1、Unicode名）を生成。SP390/PC1440のwidget実行で1180px→Bookmarks→Projectsが0pxへ戻り、両case FAIL。Homeの各tabとprojectの有限な閲覧scope（folder/view/favorites/search mode）へPageStorageKeyを付け、任意のquery文字列ごとの無制限なoffset保存を避けた。修正後、Project tab往復とDrawer→Settings→backをSP/PCでテストPASS。Works/Bookmarks非emptyやfolder/search/view/filter全相互作用は未完了。
- native Linux debug/Xvfb/xdotool（mouse/keyboard）で修正前後を直接操作・画像目視。SP390×844/forcePC=0: wheel後先頭project092→Bookmarks往復が修正前119、修正後092。PC1440×900/forcePC=1: 同079→往復が修正前119、修正後079、Settings往復後も079。Empty Bookmarks→実Community grid→native back→同Bookmarks tabも確認。native既定文字倍率であり、Android/DeX/touch/stylus確認の代用ではない。
- French320のnative custom fixtureはaccent白/selection黒/panel FAF7F5/menu CCCCCC/text2B2730。Bookmarksのselected tab/icon/CTAが読めることを実画像で確認。first_launch=falseの保存を確認したが、first-guidance名のcaptureは古いSplash frameであり、案内のnative Visual evidenceとして使わない。全captureの成功を一括申告せず、初期resolver未準備のempty/no-op画像もmanifestで区別した。
- 現在の自動回帰: 14 files / 実test69件 PASS（loading14 events除外、最終done.success=true）、tap miss warning0。S6反例3件も修正後PASS。表示matrixは6主要状態×336=2016＋7言語×6状態×7mutation=294、計2310 PNGとmanifest、layout例外0。tab切替はensureVisible＋selected assertionで検証し、単なるmiss tapで緑にしない。全2310画像を個別目視した意味ではない。320の7言語×6状態のdefault/dark-scale2 contact、French scale2原寸、白accent原寸、上記native結果を開いて確認。
- full flutter analyze: No issues found。Linux debug build成功。69-test実行後の変更は古いcomment削除とfixtureのif bracesのみで、analyze/buildを再実行。app_smokeは全caseに実隔離保存先を用意し初回saveの完了を待つ（既存drawing/timeline等のassertionは維持）。保存済み旧S5の12 FAILと今回のfixture修正を区別し、今回の69 PASSを一次結果とする。
- DISC005/006/007/008を登録。DISC008は保存済みbookmarked IDsに対する未取得/閲覧フィルター/取得失敗と0 bookmarksのempty表示理由を区別できるかというsource由来の品質リスクで、実データ再現・判断待ち。sourceだけで不具合確定/PASSとはしていない。
- Tutorial判定: Bookmarksの新しい明示ラベル付き1-step CTAはinline説明で目的が分かるため、独立tutorial不要。初回案内の目的/acknowledgment仕様は維持。後続の隠れgestureや多手順機能のtutorial判定を代替しない。

#### 今回の永続証跡（Drive readback＋実bytes再取得検証済み）

| ZIP | size / entries | SHA256 |
| --- | --- | --- |
| [A003 S5-S6 main](https://drive.google.com/file/d/1ASxcsh5ABYTvYXUYxVA6RSjN_c_EgFFa/view?usp=drivesdk) | 65,020,718 bytes / 2,482 | `f567a166fa3650c43fe65554db8fd2f3bb7af65e0f5da03589c95dfa32b8d91f` |
| [A003 S5-S6 intermediate](https://drive.google.com/file/d/1QqQp-hLw-qka_quhnyEa14_5ru0goLk1/view?usp=drivesdk) | 79,931,037 bytes / 3,016 | `386d55b9c2199d543a49ffb57f1dd4eb6b38f8ad1716b565565c8e764a5e4c9f` |

- 保存先は承認済み `1fiZEjCVqLtNVk_mkNIOUC3MWn6ys6e8q`。両file IDのname/MIME(application/zip)/size/parentをmetadataで照合した後、Driveからraw ZIPを再取得して上記SHA256・size・全entry CRCを独立検証。ローカルhashだけをremote検証済みと呼んでいない。
- ZIPは全writer停止後にtemp→close/fsync→atomic replaceで作成し、別execでも整合性を検証してupload。Mainにはcurrent matrix/native before-after/serializer fixture/設定/ログ/source hashes/再適用可能なproduct-source.patch/reproduction scriptsを含め、raw VM service URL入りrunner.logは除外してredact版のみ保存。Intermediateは復元時のmatrixと未採用の試行を保持する。Gitをsource/State正本とし、Drive ZIPでの未完了状態を最終closureと呼ばない。
- 残り: 通常/大量/error等の全主要状態matrix、Works/Bookmarks非emptyとfilter/取得状態、検索・folder・view・resizeのcontinuity、free/paid/current campaign、DISC003–008全条件、後続Baseline/Discovery/Deltaと最新HEAD最終Visual。Android/DeX実機・touch/multitouch/筆圧は未用意、Linux FFmpeg dlopenも未成立でcodec/exportをPASSにしない。Baseline done2/628、current A003/in_progress、DISC001–008 todo、Delta not_startedを維持する。


### 2026-10-22 A003/S7 — DISC009 account boundaryの優先修正（全面監査は未完了）

- 再取得した最新HEADはApp `f6acd1a80e423012ac8a747c5dad0944ac8c6930` / Web `4509c0fba504c23253bad12a027a341ce433f180`。S5/S6のremote反映は保持されていた。一方で作業環境が初期snapshotへ戻り、直前の未push S7 source/log/native画像が残っていなかった。未保存の過去観察を今回の一次証跡へ使わず、修正を再構成し、before/afterとnative操作をfreshに再実行した。既存S5/S6 mainもDriveから再取得して65,020,718B、SHA256/全CRC一致を確認。
- fresh before（上記App HEADの独立worktree）: owner応答を待機→forgetOwner/new-owner→旧private応答で旧owner/作品が復元、旧social応答でbookmarks復元、旧toggle成功でsignout後のbookmark復元、の3testがFAIL。MockClient・example.invalidの合成token/データのみ。DISC009として登録、privacy上の優先修正を現在A003から行った。
- CommunityServiceはaccount revisionとdisposeで旧応答を無効にし、owner/social/following/author/toggle/edit/AI/visibilityの成功・失敗・rollbackが次accountへ適用されないようにした。unknown ownerでもforgetOwnerでrevisionが進む。signoutでprivate store/owner author-page cache/social/errorを消す。bootstrapのlearnPoster連鎖と投稿復旧時のowner設定もaccount確認後へ置いた。owner画面はaccount変更時にcached private rows/error/busyを破棄し、reload世代とaccount一致で結果を扱う。取消を別accountの失敗toastにしない。
- 追加発見: 同じownerへ再ログインした後のedit2が処理中でも、古いedit1のfinallyがbusyを解除できる。AI/visibilityの2widget反例が最初FAIL。callerの成功/error/finallyにもrevisionを適用し、旧処理が新処理のbusyを解除しないよう修正。busyの2反例を含め最終回帰へ収録。
- 検証: 27files / 実174tests PASS（hidden loading eventsを除外、最終done.success=true）。新規はunit13＋owner/feedback/busy widget5。full flutter analyze指摘0。最終busy guard後のdefault Linux debug build成功。native harness buildも同じ製品sourceで成功。ZIP source hashesはpublishするproduct/test全9fileと照合する。初回の一時harnessを含むanalyze指摘は、製品へ入れずscratchを除去してfull analyze再実行後0件。
- 旧HEADのHair Fold Production Green run `39638288550` はfailureを確認。その2件のfilter_custom_replay_testもbeforeでMissingPluginExceptionをfresh再現。DISC004の初回save awaitに必要な実隔離保存先fixtureを加えて2件ともPASSにした。Prism/Linear Dodge/pixelsの既存assertionは変更していない。このCI fixture対処をHair Fold機能の全面監査完了とはしない。新HEAD CIは反映後に確認する。
- fresh直接操作: production CommunityMyWorksScreen、CommunityService、CommunityApi/NiarimApiClientを明示ラベル付き隔離harnessで実行。native Linux debug＋Xvfb＋mouse、forced SP390×844とPC1440×900、en/light/textScale1。両modeで旧private表示→旧応答をhold→新accountの応答もholdして切替（旧行が消える）→旧応答をrelease（旧行は戻らず取消）→新応答をrelease（new privateだけ）→signout（privateなし）。5状態ずつの原本10枚をすべて開き目視し、action history・harness source・設定/再現方法を保存した。合成auth/APIなのでlive Google OAuth、YouTube、実backendの合格ではない。
- 留保: owner loading時はspinnerと一時的な0 worksが並ぶため、全状態polish時に表記も確認する。Android/DeX/touch/stylus/multitouch未用意、Linux FFmpeg dlopen失敗は継続。全7言語/336matrix、全caller・実auth/backend・private/deleted/offline等のDISC009残条件、DISC008のempty理由分岐は未完了。Baseline done2/628、current A003 in_progress、discovery_current_id DISC001、DISC001–DISC009 todo、Delta not_startedを保持する。

#### S7証跡保存（両ZIPのDrive metadata＋raw bytes再取得で検証）

| ZIP | bytes / entries | SHA256 |
| --- | --- | --- |
| [S7 core recovery checkpoint](https://drive.google.com/file/d/1ZTrSTaVsPKMYcuJlFt0nz0JQKYvlPEH8/view?usp=drivesdk) | 85,961 / 22 | `479ae79512c0854c287b708ea48cb07c109edd2bf2f220b90cdbec59b7be18d3` |
| [S7 final priority-fix checkpoint](https://drive.google.com/file/d/1cjryM9pqobXiiRLjkzY2LHoe1yUwxkIy/view?usp=drivesdk) | 473,236 / 38 | `4c15e5a3b8c5c05be3e3644e4fa73d2d4cde395f5e13b4cbd6b7e5ca543cdfc4` |

- 承認済みfolder `1fiZEjCVqLtNVk_mkNIOUC3MWn6ys6e8q`、file name/MIME(application/zip)/size/parent一致。両ZIPをDriveから実再取得しSHA256・bytes・全entry CRC一致を検証した。coreはbusy追加修正前の中間checkpoint、finalが現在の174testと10native画像・最終source/patch/reproductionを含む。raw runnerのVM service URLは除外しredact版のみ収録。finalというファイル名はS7優先対策のcheckpoint名であり、全面監査最終Visual closureを意味しない。


### 2026-10-22 A003/S8 — 再開時の復元と中断前保存checkpoint

- 再開時にscratchが初期snapshot（App ec93d84）へ戻っていた。最新dev_branchを取得してApp `7e44c07e98688a21f03227eff652e9625b5f2aa6` / Web `292316f3aa6649717b271f68a8017ffadfc6be53` までfast-forward。未pushの直前S8最終matrix/native原本は保持されていなかった。過去の207/195件や5901画像を、今回保存済みの一次証跡として扱わない。
- 保存済みS8 progress ZIP（Drive [1KqZV8_oVaGJCO6KWdvSp6BOIJxN0rWIR](https://drive.google.com/file/d/1KqZV8_oVaGJCO6KWdvSp6BOIJxN0rWIR/view?usp=drivesdk)）を再取得し77,337,683 bytes /2893 entries、SHA256 `0363406303392f885fad5e4ef0189bfca791e7ab3e511265e73f44fd09b92687` と全CRCを照合。21source/testのhashも照合して復元。旧checkpointはHome理由分岐の修正前8 FAIL・184 PASS・拡張12 PASS、card/dialog2 FAIL、7状態完了後のnonempty文字2倍9.8px overflowという部分証拠でありfull matrix PASSではない。
- DISC010/011を上記保存済みRouteから復元。DISC012は選択中tabが拡大/resizeで画面外へ残る観察に基づく継続対象。未保存原本を失ったことを明記し、fresh再現・修正後実画面を必要条件とした。全DiscoveryのstatusとBaseline/Delta cursorは進めていない。
- ユーザーから、利用上限前に未保存内容を確実に保存し、再開ごとの復元・再実行を減らすよう明示指示。今回、検証完了を待たずpending sourceを独立checkpointへ保存した。今後は作業単位ごと・長い検証/captureの前後、節目のない連続作業では30〜45分を目安に短く外部保存する。再開はbase/現在HEADとsource hashを照合し、引継ぎ可能な保存済み証拠を無駄に再生成しない。環境初期化自体を防ぐとは保証しない。
- [A003-S8 recovery checkpoint 01](https://drive.google.com/file/d/1qmboL2voMdTrOmYY9Wa1CYo0IuwnzRIc/view?usp=drivesdk): **1,310,156 bytes /39 entries**、SHA256 `8495cd2cd07ad235483067207ba9d2c1dfaac577ad01765ba6094e2362c09afa`。26変更ファイル（未追跡test含む）、tracked patch、全source hash、MANIFEST/RESUME、構築script/logを収録。承認済みfolder `1fiZEjCVqLtNVk_mkNIOUC3MWn6ys6e8q`。保存後name/MIME(application/zip)/size/parentを照合し、Drive raw bytes再取得でSHA256と全CRC一致を確認済み。
- checkpoint01には再構成途中のcard/grid・Home social状態・accountの追加guard・tab追従等を含むが、現在sourceでの再検証は未完了。生成l10n/環境scriptの修正もpendingとして記録した。製品sourceをPASSやpush済みとしない。修正は検証・native・証跡保存後に通常pushする。
- 現在A003 in_progress、Baseline done2/628、discovery_current_id DISC001、DISC001–012 todo、Delta not_started。後続全Baseline/Discovery/Delta・最新HEADの最終Visualを継続する。

- 復元後のfresh検証: `flutter test --no-pub test/home_bookmark_states_test.dart test/community*_test.dart test/services/filter_custom_replay_test.dart --concurrency=2 --machine` は実197件/32files PASS（hidden loading除外、done.success=true、85.538s）。Cardは7言語×6variants×14幅×3倍率=1764組合せでlayout・48px target・bookmarkのactual semantic label・独立callbackを確認。Homeはreason/retry/pullの16件にtab resize2件を含む。これはnative/全監査PASSの代用ではない。
- full analyzeはtestのif braces13 infoを検出。3test fileへ機械的なbraces修正を行い、`flutter analyze --no-pub` 再実行はNo issues found。製品sourceは197件実行後に変更なし。Home/social/accountの21件を機械修正後に再確認し21 PASS。matrix testはanimation静止待機・rendered action contrast・選択tab可視性・bookmarks別outputを追加したがopt-in実行はこの時点で未実施。
- State保存前に最新remoteがApp `9259de657d87fdef500909d679d8a19ac33c0758` / Web `4e641080ace3a434b3ecb9bd50bccbb14677b6eb` へ進んだことを確認。5監査資料の追加保存ルール（シナリオ単位、節目なし時30〜45分）を読み、local State commitをその後へrebaseして保持。これらの追加変更は監査文書のみで、197件検証の製品sourceに変更はない。

- 追加永続保存 [recovery checkpoint 02](https://drive.google.com/file/d/1MUptn_C42U5HpeUVIchh0Esyvh-s6fhY/view?usp=drivesdk) は1,403,254 bytes /49 entries、SHA256 `ec94fa4986daf900d1bc71f78d2563424696d272dfcf0434f5c56b1bc257341d`。最新source/patch/State/hash、197件log、style修正と0件analyze、21件再確認、再開手順とclean環境scriptを保存。Drive metadata name/MIME/size/parentとraw bytes再取得hash/全CRC一致。197件時点の製品sourceは不変、3testsのbracesと未実施opt-in matrix検査の追加は区別する。native/build/matrix/最終Visual・製品pushは未完了。


### 2026-10-22 A003/S8 — current source・表示状態・操作の優先修正 checkpoint（全面監査は未完了）

- 最新取得HEADはApp `f989fc39501eb34b348c3eb9151557a01232d999` / Web `2f8bfbc3a10b91b0dd48c35a36572f2f1d619abe`。この先端からの製品差分を対象とし、承認済みdev_branchへ通常pushする。State-only履歴と製品sourceのhashを区別した。
- Home Bookmarks: 初回loading/取得失敗/Retry/未取得/guest/保存IDが表示filterで隠れる/未解決ID/neutral empty/cached contentを区別。取得はaccount-scopedかつ重複抑止、失敗時はcache保持。APIがprivate/deleted IDを返さないため、0件を「一度も保存していない」と断定しない7言語表現へ修正した。既存保存値・収益化gateは維持。
- Card/Grid: text scaleに応じた列数と自然高で固定aspect-ratio由来のoverflowを修正。実背景に対する文字色、黒overlay/白icon、rank/private/short/duration/repost、48px bookmark/author target、独立callbackとsemantic labelを確認。Communityの短い一覧でもpull-to-refresh領域を全viewportへ広げた。Home選択tabはindex/幅/label/文字倍率の変化で可視範囲へ追従し、無関係なrebuildで手動scrollを戻さない。
- DISC009追加反例: 正確な旧remote Serviceだけへ一時復元したfresh counterは1 FAIL（AI/visibilityのAPI呼出中・microtask境界でaccountが変わり旧privateが再適用）。現在sourceへbyte-identicalに復旧し1 PASS、24 interleavingsを検査。API呼出前のrevision captureとcaller適用前の再確認を追加。保存済み197件との単純合算はしない。
- 自動検証: 復元後197 real tests/32files PASS、style修正後21 PASS。静止後matrixは13 real tests PASS / 5901 PNG（Home6状態×385=2310、Bookmarks9状態×399=3591、7言語・PC/SP・24幅・theme/text scale/short-height mutation）。source309hash snapshot保存。6contact sheetsを開いて9状態×7言語の320 dark2と640 short2 controlsを確認し、全5901原本の個別目視は申告しない。
- native Linux実操作: error→Retry/loading→success、cached loading/error→Retry/success→unbookmark/neutral empty、640×360文字2倍でscrollして操作へ到達。French/white custom/文字1.3のhidden bookmark→作品広場→表示filter OFF→保存→実Back→同じ作品がHomeに表示されることを原本で確認。Back hover tooltipがheaderを覆う画像はclean Visual closureにしない。private/short/plain card、bookmarkだけの独立削除、preview、作者route、Followingのrepost、Rankingの順位badgeもPC1440で実操作・原本目視。最初のranking名画像は実際にはNewであり、settled画像でRanking選択を確認した。
- 表示filter ONswitchが白custom popupで消えるfresh native反例を観察。29profile（28preset+white custom）×ON/OFFのthumb/track・track/popup境界testがbefore FAIL→after PASS。実popupを基準に前景/2px outlineを選び、native ON/OFF→Save→再表示も確認。関連filter+Homeの最終42 real tests/6files PASS、full analyze0。最終修正後のdefault Linux debug buildと隔離native harness build成功。最終build後generated l10nのformatは0変更、git diff --check成功。
- 検証の失敗も保存: 最初のtransition fixtureはAppBar ancestor finder重複で無効、最初のSwitch修正は未対応Tile parameterでcompile失敗、別runは存在しない推測test pathがあり23 PASSでもgreenとはしない。修正後の有効42件runを一次結果とする。生成l10nのformat-only差分とcompiled時raw生成ファイルを保存し、同一UIに影響しないdialog局所変更のため静的Home5901画像を無駄に再生成していない。
- DISC012未解決観察: 初回nativeではbody Bookmarksに対しheader/selected Works+folder FABが残った。原本2枚を保持し、環境のGLib静的link不整合を修復後にfull harness rebuild。通常/即時resizeと1764card render-load下の再現probe、0/10/50/100/200/300/500ms移動中resizeの2widget testsでは再現しない。初回episodeを環境原因と断定せず、未解決のまま全3tab/continuityを継続する。
- 次単位: French white customの作品広場heading/selected tab不可視、SPの画面名省略とcontrol密度（DISC005/010）、preview操作bar低contrast、Works/大量Bookmarks120件・folder/search/view/favorites・全continuity・free/paid/campaign条件。初回案内/各caller/全preset実操作も残る。合成HTTP/auth/dataはlive OAuth/backend/mediaの合格ではない。Android/DeX/touch/multitouch/筆圧未用意、Linux FFmpeg dlopen未成立。
- Baseline done2/628、A003 in_progress、Discovery cursorDISC001/全DISC001–012 todo、Delta not_startedを維持。これはS8優先修正のcheckpointであり、最新HEADの全面Visual closureではない。

#### S8 current static matrix — Drive metadataとraw再取得bytes/SHA256/全CRC一致

| ZIP | bytes / entries | SHA256 |
| --- | --- | --- |
| [S8 home](https://drive.google.com/file/d/1Owj-3Tz2Md-RZeKhQfAn1TnNE2aBlaMG/view?usp=drivesdk) | 62,357,237 / 2,333 | `aef92b455f66d4c7fbd1c0ef63c76cf2cf26b653f02b7b8c7ad5424b8fb3be7c` |
| [S8 bookmarks-A](https://drive.google.com/file/d/1UCWisshiOYRdOTev_ywzgECIgWDkMxdS/view?usp=drivesdk) | 35,805,048 / 1,203 | `a16e3104b8ef09aa78e41a964b827c2682756b0a6f3d73b6a3f2483fc8373a6c` |
| [S8 bookmarks-B](https://drive.google.com/file/d/1Dny4cfIAGE3myMwDAdwn-pakh5uudBTS/view?usp=drivesdk) | 27,958,626 / 1,203 | `d824f16a87144b8920e2a0bb7b867fc64c73b4a616403066088d8c0bc8f19882` |
| [S8 bookmarks-C](https://drive.google.com/file/d/1FeF5LS1rdFwyDklaBhQ9lhdlHz0hntxU/view?usp=drivesdk) | 40,228,309 / 1,203 | `a4ae8e11b158775091288209adcd26781a23c62c8228055cd985c621211e2be7` |

- 承認済みfolder `1fiZEjCVqLtNVk_mkNIOUC3MWn6ys6e8q`。各ZIPは100MiB未満で分割、すべてmetadata name/MIME/size/parentと実再取得hash/全entry CRC確認済み。nativeの初回不整合も隠さず保存。
- 追加controls WIP backup: [1IncGukiWsmKGrLG70uNufCEGEebpPEOE](https://drive.google.com/file/d/1IncGukiWsmKGrLG70uNufCEGEebpPEOE/view?usp=drivesdk)、3,117,706 bytes /105 entries、SHA256 `640b2f3ad2ec71bd0a4aaa840d34a53ff214a483197e435eb16cd2a0566ccca5`、metadata/raw hash/CRC一致。この時点後の最終native操作・default buildは別coreへ保存する。

- S8最終core保存/readback完了: [A003-S8-final-core](https://drive.google.com/file/d/1cIujXWuS6HUuCpo1WbwQ3w7gK3yJXT0d/view?usp=drivesdk)、3,733,807 bytes /118 entries、SHA256 `1665c54099ab5d25711cb39abb4f2c7576d0a09b7d04d2b807e41b4b067ce677`。全writer停止後のsource30files/patch/hash、5901matrix参照、最終native原本・action log・redacted runner、197/42件と失敗を含むlog、最終default build、再現環境/次操作を収録。metadata name/MIME/size/parentとraw再取得hash/全CRC一致。ZIP内Stateは自己参照追加前であり、本receiptはGit Stateに保持する。S8の局所checkpointであって全面Visual closureではない。


### 2026-10-22 A003/S9 — 最新正本同期・ユーザーのテーマ色方針を優先（WIP）

- 最新取得: App `042f9921ce02d87bfec54ed68bc77ce521483480` / Web `aac9e1e1447483333d89578a48f9872bf9723200`。S8製品push後に通常UI色のtoken対応・自由な配色・復旧専用判定の変更が入ったため、現在HEADのPolicy/Quality/Hands-on/実行標準とテーマ仕様を再確認した。新規APCA/CVD判定・memoized cache・確認付きreset・7言語・唯一の固定色復旧ボタンを旧checkpointで上書きしない。
- ユーザーは、通常UIをテーマ・外観の正式色から取得し、見やすさのために固定黒白/任意RGBへ自動置換する変更を認めないと明示した。assistantは撮影用ではなく製品UIの自動補正を追加していた事実を説明し、誤りとして取り下げる。保存済みS5/S8/S9の固定neutral表示を、現方針に対するVisual合格としない。機能/layout等の無変更部分の証拠はscopeを限定して保持する。
- S9復元ZIP [before-matrix](https://drive.google.com/file/d/1ovtX7I89CnS-yVhZeoigK5plVgqORU5R/view?usp=drivesdk) は291,778B/67entries、SHA256 `14acf5475c3e7ad02c474c0846a86c5bbe068e8428d09292a54e19ce09397936`。今回もmetadataとraw再取得SHA256/全CRC/MANIFEST各hash一致を確認。これは方針訂正前のWIPであり、自動黒白化を再導入してよい証拠ではない。
- 再開環境が初期ec93へ戻ったため、最新remoteへfast-forwardした。S9の未push layout3製品/2testだけは2805親と最新HEADが同一であることを確認し復元。最新ThemeService/color_contrast/rescue/翻訳/Policyは保持。前回palette訂正途中の未保存変更・analyze結果は残っておらず、PASSを引き継がない。
- 維持するS9 layout: 狭幅で画面名と操作列を分離、自然幅tab、48px video filter、ranking sort chips折返し、検索modeのbounded label/角丸shape。以前の180画像smoke成功でも、実原本でStadium clipの文字欠けを発見し、actual renderer clip counterで1 FAIL→修正後1 PASS。これらは配色修正後の最新sourceで関連再確認が必要。
- 次の具体操作: 現在HEADの正式色マッピングを表に記録→通常UIのcontrastingForeground/固定badge/preview/tooltipを正式tokenへ修正→設定色を反映するregressionと既存APCA/rescue回帰→実製品でテーマ変更/保存復元/PC-SP導線・原本目視→証跡をDrive保存/readback→検証済み差分を通常push。復旧専用ボタンの固定色・APCA閾値20/CVD/cacheを一般UIの配色補正へ流用しない。
- Baseline2/628、A003 in_progress、DISC001–013 todo/cursorDISC001、Delta not_startedを維持。全面監査/最新HEAD Visual closureは未完了。

### 2026-10-26 A003/S9 — 最新ソース取得・更新差分確認・環境停止checkpoint

- ユーザーの全面監査再開・pull指示に従い、App `9fd84f36abd516a895aab2f15ce86f4dc14e13c9` / Web `74af216e1ae11345465326447abe97af262537a0` をfetchし、両local dev_branchをfast-forwardした。既存のfont差分は破棄していない。最新HEADのState/テーマ仕様/関連実装を確認し、以後の継続条件を [A003_S9_20261026_RESUME.md](A003_S9_20261026_RESUME.md) に記録した。
- S9の保存済み最新WIPは [token-50 checkpoint](https://drive.google.com/file/d/1J-dHvefks5UDwJy8zrzOPbnzabijnHCY/view?usp=drivesdk)。926,107 bytes /61 entries、SHA256 `2beadd3077dd20ab43f6f282d0520a27a3663f1c80c321dc1d562f7ef5e4f740`。今回はmetadata name/MIME/size/parentとraw再取得SHA256/全CRC/MANIFEST全entry hashを再確認して復元した。保存済み50 real PASSは当時のS9 sourceに限定し、今回の9fd84f3に対するPASSへ昇格しない。重複する先行52/49件を加算しない。
- 最新のテーマは9色項目・4種類の必須前景色を持つ。onPrimaryはbuttonTextColor、onSecondaryはselectionTextColor、AppBar/PopupはmenuTextColor、通常/淡色container文字はtextColor。旧WIPのonPrimary/onSecondary=menuBgColorという契約は廃止されたため、そのThemeService・モデル・APCA・翻訳・テストを一括上書きしない。救済は最新の厳密なAPCA絶対値10未満/CVD/cacheを保持する。
- 新しいテーマプレビューは現在のコード・テストでは16画面。設計書の41画面記載と不一致があり、日英分岐による他言語表示も要確認。DISC014として新規機能/品質リスクを登録。現実装を一次事実とし、旧41画面を無条件に復元しない。見本データ画面を本番UIの実操作証拠へ代用しない。
- DISC005継続: 最新Home/CardにはcontrastingForeground、Cardの固定白overlay、共通errorには固定neutral fallbackが残ることをsourceで確認。ユーザー方針との整合・正式tokenの役割を確認し、再現→修正→実操作→回帰が必要。source確認だけで機能/Visual PASSにしない。
- pull/ZIP復元後、作業環境がunavailableとなり、実行toolは `exec-server transport disconnected` で失敗。SDK/native復旧とpreflightの開始要求は実行できておらず、今回の新規test/analyze/build/native/captureは未実施。未検証の製品差分をpushしない。新規ZIP生成/uploadはbackup-pending、既存の検証済みZIPは保持。
- 次の1手: 作業環境の復旧後に両remoteを再fetch→このState/最新仕様を確認→保存済みtoken-50 ZIPをhash検証して必要部分だけ復元→最新9色の対応へS9差分を意味的統合。正式verifier/関連回帰/full analyze/native build後、実製品でTheme設定変更→Card/preview/menu→保存/再起動、header6状態×7言語×55条件と連続resize/keyboardを検証し原本目視。証跡保存/readback→検証済み製品を通常pushし、DISC013とA003残条件へ進む。
- Baseline done2/628、A003 in_progress、DISC001–014 todo/cursorDISC001、Delta not_startedを維持。今回の環境停止はadvisor-pendingや製品合格を意味せず、全面監査/最新HEAD Visual closureは未完了。

### 2026-10-26 A003/S9 — 設定色・responsive優先修正の検証checkpoint

- 開始/再fetch App15fe5ff（製品9fd84f3）/Web8d74e80。最新9色/4前景・28preset・厳密APCA10未満/CVD/cacheを保持してS9を意味的統合。固定neutralをHome/Card/preview/tooltipから正式roleへ変更。全callerのDISC005は未完了。
- 最新HEAD counter5 non-success、KO search/tag2反例、Drawer/outline2反例、modal説明/保存label1反例を記録し、修正後の対象回帰/native再操作を確認。helper全文/大文字Saveは7言語×2viewport×2mode=28条件を追加検証。詳細/source影響はA003_S9_20261026_RESUME.md。
- 最終関連28 PASS、最終modal3 PASS（28layout条件を含む）、最新analyze0、harness/通常Linux debug build成功。41/13/2等の先行回帰との重複合算なし。initial34中の旧FAB期待2件は最新Back FAB仕様へ更新して2 PASS。
- Header6状態×7言語×55=2310 PNG/6 real PASS229.484s、Home6主要状態×7×55=2310 PNG/1 real PASS444.695s。modalだけの後続修正は他コードbyte一致/source-impact proofと新規modal test/nativeで検証。全4620枚の個別目視や全remote/大量状態を合格としない。
- Native enPC非neutral9色でUIからmenu HEX変更→Card/preview/menu反映→process再起動で9値/3bookmarks保持。koPCtext2の検索/切替、frSP390→320text2のtab移動/heading/本文/Back FAB、modal全文scroll/Saveを原本で確認。placeholder toggleは実動画再生ではない。
- 最新2matrix ZIPはDriveへ保存しmetadata/raw SHA256/CRC/MANIFEST一致。下表参照。native最終coreはこのcheckpointへ追記する。DelaGothic既存差分を保全し、検証はHEAD fontを使用、最終push後に元bytesを復旧する。

| ZIP | bytes / entries | SHA256 |
| --- | --- | --- |
| [Header 2310](https://drive.google.com/file/d/1UPq6ciQdW2sx_Wpt3bdJ14LhVBC6AUMQ/view?usp=drivesdk) | 58,933,489 / 2,319 | `089c3792ffc6083888cb66dc3302518788c35c1667875ab8318ae7230b9181d9` |
| [Home 2310](https://drive.google.com/file/d/1bswQ8JhaX9pUEHhDVbwg3WMhpx5C0PRH/view?usp=drivesdk) | 59,179,335 / 2,314 | `490c01d3f247d0199b9c798abb37b4e1eda49a023eb994a779c91c666b7a1efb` |
| [Runtime core（最終dialog修正前）](https://drive.google.com/file/d/1b7BT7GW1V2hDkimWmoKYIjJjPEX1upN4/view?usp=drivesdk) | 3,572,247 / 121 | `4f3e91a364b870028240eb56d8a6eaa0d74947103209d2fd647d3e72ad938192` |

- 次はS10/狭幅preview（DISC013）。FR320text2実原本で356px幅とoffscreen resize handleを確認。YouTube公式最小200×200/16:9推奨との違いを確認済み、幅/高さ適応・代替導線・48target/keyboardを実装/検証する。Home tab source46px等も確認し、実再生をplaceholderから推定しない。
- Baseline2/628、A003 in_progress、DISC001–014 todo/cursorDISC001、Delta not_started。Android/DeX/touch/筆圧、live backend/OAuth、FFmpeg runtime codec、全Visual closureは未完了。

- S9最終core保存/readback完了: [A003-S9-OCT26-final-core](https://drive.google.com/file/d/1h0nUV4MooTp7QId9njeGpW8L0g1whQKx/view?usp=drivesdk)、5,085,891 bytes /164 entries、SHA256 `49c80f61427947714b13d315f7d483e35ef37ff3b71a4cdd4184c2844dfa5604`。metadataとraw再取得hash/全CRC/MANIFEST全entry hash一致。全source/patch/hash、全反例/回帰/最新default buildログ、native原本/action/redacted runner、modal限定のsource-impact proof、2matrix参照、再開scriptを収録。ZIP内Stateはこの自己参照receipt追加前。Git Stateへreceiptを保持し、全面監査の完了にはしない。

### 2026-10-26 A003/S10 — S9公開完了・preview responsive継続（WIP）

- S9修正をApp `8c6a6bab39c946c1a954808d15a9b051363191b2`（tree `9c9260d4c16a8da4f53da40145e577551519e2cd`、29 files）、Web Stateを `fba682f6e66b38a81e6e6a470eb80b03f3ae905c`（tree `53e6a9ff0f16a8b1e8f216dd00be15aa5aa9e242`、4 files）へ公開。fresh parent lease / nonforce update、remote HEAD/tree/compare path一致を確認。local tested commitはbackup branchに保持。CIは13件success・Save safety実行中の時点で記録し、全greenとは判定していない。
- 前在user font（SHA256 `4e88513583b672a759fbb967dcaef291e46d52902a963e8140c441fd55b0f350`）をS9検証/公開後に復元済み。S10 canonical検証中のみHEAD font `4ff87a0965f1b0505e5a2c58424bc6ad3cff27e56a82f21c2fc9d6b0e3857ee2`へ一時切替。元ファイルはpreexisting-assetsと既存検証済みDrive ZIPへ保存済み。完了/中断前に必ず元のuser fontを戻し、commitへ含めない。
- DISC013をA003/S10として継続。fresh counter `oct26-s10-preview-before.jsonl` はFrench320/text2でpanel幅356と4px内部overflowを再現（1 real test ERROR）。このcounterはuser fontのまま実行、寸法反例であり現HEAD font画像証拠ではない。
- WIP: previewの幅適応/200px高下限、48px操作領域、詳細の別行、短画面fallback、visible位置からのdrag/resize、keyboard/tooltipを実装中。通常UIは正式menu background/menuText。新規3文言は7言語に追加。最初のafterでSemantics increased/decreasedValue不足のassertionを検出し修正。関連targeted runはPASSだが、matrix/native/関連回帰/full analyze/通常build未完了のため未検証WIPとして扱う。
- 現在 `oct26-s10-preview-matrix01.jsonl` 実行中。次の1手: 正確なdone/失敗を確認→不具合修正→対応matrixとnative FR320/text2・200px resize・short viewport・keyboard/戻るを実操作→原本目視→回帰。再現環境と旧S9原本は既存最終coreから復元可能。動画本体はplaceholderのままで、実再生/外部接続/法的非侵害PASSではない。
- Baseline done2/628・A003 in_progress、DISC001–014 todo/cursorDISC001、Delta not_started、全面監査・最新HEAD Visual closure未完了を維持。

### 2026-10-26/S10 CIの再確認・DISC015登録

S9公開後CIは14 workflow中13success、Save safety auditがfailure。full-gatesはfull analyze成功、globalformat32files、fulltest2101PASS/23skip/4FAIL。保存専用jobはserializerformatで停止し保存testを実行していない。4反例はProjectDetail文字2倍右59pxoverflow、exact exportのCanvas finder0、unused ARB homeSelectionAddFavorite/homeSelectionRemoveFavorite、popup pixel不一致。DISC015をtodoとして追加。原因/修正/実画面/回帰未完了のため全CIgreenとは扱わない。raw log oct26-s9-CI-full-gates.logを次checkpointへ保存。

S10 final regression log oct26-s10-preview-final-regression.jsonlは28 real tests PASS /69.433s、うちmatrix2247条件/66PNG・0failure。実装/ARB/資産はmatrix freezeとhash一致。テストソースだけ6箇所のif bracesを静的解析に従い機械修正中、製品ソース変更ではない。全体analyzeとnative buildを実行し、次は実製品UI操作。

### S10 latest-source invalidation after native input counter

28PASS/69.433s・2247条件/66PNG・解析問題なし3.8sはnative focus修正前のsource結果。実FR320でresize click後End無反応、Tabで背後Backにfocusする反例を発見。初期focus/resize press-drag focus/再配置とplayer-fallback間の保持を修正中。実routeをmountしてから開くfocused testはPASS6.792s。native再build/同操作、最新sourceのmatrix/regression/analyze/defaultbuildは未完了。前結果を最新sourceの完了証拠へ流用しない。旧raw画像/失敗log/修正根拠はobservations.mdとcheckpointに保存。

### 2026-10-26 A003/S10 優先修正の最終検証記録

# A003/S10 — 2026-10-26 shared preview priority fixes

## 正本・位置
App source base `8c6a6bab39c946c1a954808d15a9b051363191b2`、Web State base `fba682f6e66b38a81e6e6a470eb80b03f3ae905c`。再fetchで一致。最新9色/4前景、strict APCA absLc<10、CVD/cache、保存形式、現Home Back FAB/新16枚galleryを維持。通常のUI前景/背景をローカル黒白へ置換していない。

Baseline done2/628・A003 in_progress、DISC001–016 todo/cursorDISC001、Delta not_started。S10は優先修正の検証単位であり、A003/Discovery/全面監査/最新HEAD Visual closureの完了ではない。

## 修正
- 希望幅356（200–640）を保持し、実幅をviewport safe areaへ適応。動画領域は200px高以上、十分な幅では16:9。幅/高さが足りない場合は動画を作らず、詳細への案内とDetails/Closeを表示。操作部分は必要ならscroll可能。
- 再生状態toggle（placeholderのみ）/Close/Details/resizeの48px以上target。locale/font/textScaleから測ったDetailsを必要に応じ別行へ配置。resize handleがDetailsを覆わない。bar/hint/iconは正式menu背景/menuTextを使用。
- resizeクリック/横drag、左右/上下キー、Home/End、Alt+矢印の移動、Escape。開いた時のfocus、pointer resizeでのfocus、行組替えとplayer/fallback間のfocus保持、fallbackのfocused action表示。既存routeの外側でもhover tooltipを提供。
- 高速pointer updateはlive service値へ積算。gesture開始時に現在の可視位置/幅へanchorし、過去の画面外希望値や同一frame内の古いbuild値で操作を上書きしない。
- 3文言を7言語へ追加しgen-l10n。既存role testsのbar参照を安定keyへ変更、size testsを200px高下限/48px rowへ整合。通常仕様29も挙動/keyboard/実動画未接続を整合し、過去会話由来の未確認特許断定を削除。

## 反例と検証
- `oct26-s10-preview-before.jsonl`: FR320/text2で幅356/内部4px overflow、1 real test ERROR。この反例のみ前在user font、後の最終canonical検証はHEAD font。
- 初回afterはSemantics increased/decreasedValue不足を検出し修正。KO等の旧S9反例をS10の反例として水増ししない。
- nativeでentry focusが背後Backに残りEnd無反応を再現。以前のtestの直接requestFocusが実entry差を隠していたため、route mount後にopen→pointer dragでfocus→Home/End/Alt→short/tall反復→Escapeを検証するtestへ強化。初期Navigator生成前のautofocus試案の失敗logも保持。
- `oct26-s10-rapid-drag-before.jsonl`: 20イベント/frameが移動Offset(2,1)（期待40,20）、幅+2（期待+40）へ落ちる、1 ERROR。afterは1 PASS/13.013s。短画面/keyboard afterは1 PASS/8.862s。これらは最終runと重複し、件数を加算しない。
- **最終** `oct26-s10-preview-complete-final-regression.jsonl`: **29 real tests PASS /136.198s**。含む2247 matrix条件/66 original PNG/0 failures。7言語×24指定幅×希望幅200/356/640×文字1/2×light/dark、short/tiny幅35条件、全28preset×7言語196条件。PC/SP独自layoutを持たないshared widgetのgeometry/labels/正式色role検証であり、2247回の個別手動操作とは区別。
- `matrix-source-final-complete.json` の23 product/test/ARB/font hashは最終検証と一致。古いmatrix-final/focus-finalは修正前の履歴。最終66原本のpreview cropを11 contact sheetsで全件目視し、代表全原本とnative原本を別途確認。captureだけのPASSではない。
- `oct26-s10-complete-final-analyze.log`: No issues/7.1s。最終manual Linux debug build成功。通常entrypoint buildは別logで確認し、結果を後述receiptへ記録。

## 実アプリ操作と判定
合成HTTP/owner/dataを使うproduction app/router/providers/UIの隔離Linux runner。実YouTube/実OAuth/実backendではない。
- FR/SP320×844/dark/text2: Home→Back→Splash→Plaza→作品。全操作可視、pause見た目toggle、resize click最小200/2行、Home/End/Alt移動、速いbody dragが指定44/200pxに追従、640×220 fallbackで説明とDetails/Close、実Details route→Back、Plaza→Splashでも位置/サイズを保持、resizeへfocus後Escapeで閉じる。最終原本は `s10-final-fr-*`。
- EN/PC1440×900/9色を意図的に異ならせたpalette: menu peach/darkblueのpreview bar、body/card等と正式roleの区別、pause見た目toggle、handle drag/End最大640。Home Bookmarkedのown private作品も実際にopen。
- forcedPC320のcold/settled Home/Bookmarksでは320px内にplayer/全controlが収まり、希望640→320（4s settle）→1440（4s settle）で640を復元。最終 `s10-pc320-settled-*` / `s10-pc1440-settled-*` 原本を確認。
- cold/連続操作の最初のcard tapで即openを確認できない事例はDISC010へ保持。settled retryを初回成功と扱わない。
- **高速連続native resizeは未解決**。759/760/641/640/560/559/430/320のsweepで旧GLframeのcropが残り、logは論理viewport320と旧frameのOpenGL待ち時間超過を示す。軽いHomeでも初回frame待ち時間超過があり、Community gridだけを原因と断定しない。DISC016に登録し、settled layoutの合格から性能/連続resizeの合格を推測しない。
- 7言語と全28presetは自動matrix、直接nativeはFR/SPとEN/PCの条件差ケース。物理Android/DeX、touch/multi-touch/pen、screen reader全操作、外部modal focusの実操作、profile実機性能、実メディアは未完了。特にplaceholderのtoggleを実再生合格にしない。FFmpeg dlopen環境も未成立。
- ガイド判定: 戻る/再生/閉じる/Details/一般resizeの主要価値は既存の一般UIと7言語tooltip/accessible名で到達するため、この優先修正に独立onboardingは追加しない。通常仕様は更新。製品全体のHelp/Tips/初心者導線とoptional keyboard発見性は後続の全件監査対象として維持。

## CI / 新規Discovery
S9公開 `8c6a6ba` の14 workflowsは13success/Save safety failure。full analyzeはsuccess、global format32files、full suite2101PASS/23skip/4FAIL（ProjectDetail文字2倍右59pxoverflow、exact-export Canvas finder0、unused ARB2key、popup pixel不一致）。保存専用jobはserializer formatで停止し保存test未実行。raw `oct26-s9-CI-full-gates.log`、run40279021471。DISC015をtodo追加し未解決。S10/全面監査allgreenとは記録しない。
DISC016はLinux software Impellerの高速resize/GLframe同期。source layoutとrenderer/実機性能を分けて反例/比較/対策/回帰を継続する。

## 保存・font・次の1手
- GitHub通常dev_branch pushと既定Drive folderへのZIP保存は承認済み。force/reset/main/deploy/他人への連絡へ拡張しない。
- 前在user fontは1022464B/SHA256 `4e88513583b672a759fbb967dcaef291e46d52902a963e8140c441fd55b0f350` をpreexisting-assetsと検証済みDrive ZIPへ保持。canonical検証はHEAD font2508848B/SHA256 `4ff87a0965f1b0505e5a2c58424bc6ad3cff27e56a82f21c2fc9d6b0e3857ee2`。最終build後に前在fontを復元し、その差分をcommitしない。
- 先行layout WIP: Drive `1GIboUHCTSIQtlaoDfw9mGJJG9b73-pUI`、2129600B/106entries、SHA256 `44329f7e20abb5fb4ae7a9c321c513d729b8e53c522085e05e40e01d0dd7ffb0`。focus WIP: `1Vw6QjaqlVY6ohWusRxTj6KsutfWnkkJH`、10136947B/247entries、SHA256 `c2ed0c9c25e88bb24446a24a84070a96fdeaaddcfda8d0efe859947c5cc2ff8f`。双方metadata/raw SHA/CRC/manifest readback一致。現最終sourceより前のWIPである。
- 現最終coreのupload/readbackと公開のreceiptは本資料末尾へ追加する。ZIP内Stateは自身のreadback receipt追加前となり、receipt追記はStateだけを変更する。
- 次の1手: canonical source/State/evidenceを通常pushしてremote tree/HEAD/CIを記録。その後A003/S11としてDISC015の関連popup/unused2key・formatの反例を分類/修正し、DISC016のrenderer/profile比較、Home48px target/Card作者keyboard、残るA003状態/continuityへ進む。Discovery cursorを飛ばしてdoneにしない。
- `source tools/niarim-env.sh`、Flutter3.47.7/Dart3.13.5、`--no-pub`、Flutter CLIの並列実行禁止。最後の通常build後のbundleはlib/main.dart。native fixtureはreproduction/home_audit_manual.dartを再buildしてからnative_console.pyを同一PTYで使う。既検証の29tests/2247条件はsource変更・失われた結果・未解決事項がない限り再実行しない。

### 最終通常build / 前在fontの復元

`oct26-s10-default-build.log`: 通常lib/main.dart Linux debug build成功。native app/console/Xvfbを停止し、前在user fontを1022464B/SHA256 `4e88513583b672a759fbb967dcaef291e46d52902a963e8140c441fd55b0f350`へ復元済み。Git commitから除外する。product source/test/ARBは最終29PASSのfreezeと同一、Git正本のfontは検証時HEAD assetのまま。

### S10最終core backup — readback検証済み

[2026-10-26 S10 final core](https://drive.google.com/file/d/1mjAztPx92Jblr1uYUJuFT17kA3z3QqgS/view?usp=drivesdk)。14,016,730 bytes /295 entries、SHA256 `98c2bbf3f131e5c38d5b0b5b7c74ed5600539fc8c3dd71406b150f53e22470b9`。metadata name/MIME/size/parent、raw再取得size/SHA256、全CRC/manifest各entry hash一致。最終23source hash、29PASS log/2247条件66原本＋11比較シート、native原本/入力履歴/redacted runner、失敗反例/CI log、State/再開手順、元user fontを保持。高速resizeGL遅延とCI4fail等の未解決を明記。ZIP内Stateは本readback receipt追記前で、追記はGit Stateへ保存する。

### 2026-10-26 S10公開完了・S11開始

# A003/S11 — 2026-10-26 CI/related quality follow-up (WIP)

App dev_branch3b9acd833be242d91b01f9d1998a7647564aa155、Web673ce587da6cdd0376945acdec30d68665a2f5ccへS10を通常push済み。remotehead/tree/compare path/ancestor、localfetch/equaltree/indexを確認。S10 finalcore Drive1mjAztPx92Jblr1uYUJuFT17kA3z3QqgS14016730B295entries/SHA98c2bbf3f131e5c38d5b0b5b7c74ed5600539fc8c3dd71406b150f53e22470b9、canonical公開receipt Drive1CTC0RiwE5fo9dxE7ZX-jpNOYDk1Nfwtv15784B11entries/SHA4082982c05ffc08c35e36e877b422aca96aebf9f53ce8ef8aac311e7afab7701。両ZIPmetadata/rawsize/hash/CRC/manifest一致。S10の29PASS/2247条件66原本/実FR-SP/EN-PC検証を、理由なく復元・再実行しない。高速GLframe遅延はDISC016で未解決。

S11 freshbefore: oct26-s11-popup-l10n-before.jsonl、4 real cases=2PASS/1FAIL/1ERROR、donefalse11.556s。popup pixelはgeneric surfaceContainerを期待する旧仮定、sourceは正式popupMenuTheme.colorを指定済み。実装の色を変更せず、testに実際の明示roleを使い、opaque検査には明示popup色とgeneric container双方を含めた。未使用2keyはユーザーが不要とした一括お気に入り操作の残骸。7ARBsから2keyだけを削除、全残キー/値が同一であることをJSON比較で証明しgen-l10n。Role binding/propagationを含むafter7 realPASS14.922s（件数はS10へ加算しない）。UI色や表示中の文言は変更していない。テーマ実装/9色契約は変更なし。

次の1手: S11 WIPを外部保存→canonical fontでtext_scale_layout_test.dartとapp_web_reference_export_exact_test.dartの残るCI反例をfresh実行。ProjectDetailの4要素固定34pxrow/text2右59pxはsource確認、原因/修正/実nativeはこれから。exact-export testの既存24px Timeline overflow抑制もDISC015の調査範囲とし、抑制追加でgreen化しない。全体format32件はdry-runで照合してから必要な範囲を機械整形し、product意図/最新ユーザー変更を保持する。

前在fontはoriginal1022464B/SHA4e88513583b672a759fbb967dcaef291e46d52902a963e8140c441fd55b0f350を復元済み。Git操作でHEADassetへ戻る挙動があり、Git書込み後は必ずoriginal再照合/復元する。退避preexisting-assetsとDrive複数ZIPを保持、commitしない。今後canonical視覚検証では一時HEADfont4ff87a0965f1b0505e5a2c58424bc6ad3cff27e56a82f21c2fc9d6b0e3857ee2を使い、終了時originalへ戻す。S11 popup testsはFontLoaderを使わないtest描画であり、実UI再操作/字形確認の代替ではない。

Baseline done2/628/A003in_progress、DISC001–016todo/cursor001、Deltanot_started、fullaudit/最新HEAD Visual closure未完了。Sourceformatterやtest成功を商用品質完了と扱わない。正常push/既定Drive保存は継続承認済み。No subagents。

### S11 layout/export priority WIP — 2026-10-26

Fresh canonical before oct26-s11-layout-export-before.jsonl:3 realcases1PASS/2ERROR18.388s。ProjectDetail textScale2は右59pxoverflow、exact-exportは旧単体icon getterを探すため複合iconBuilderのCanvasTimelineModeButtonを見つけない。testを現行key/実tapへ整合し、320pxから横scrollでexportへ到達するよう変更。旧24pxoverflowの黙認と420pxへの一時拡幅を削除して全例外を検出。直後の新counterはtoolbar export hit height39pxで1ERROR9.470s。

製品WIP: ProjectPlaybackStatus widgetへ分離し、従来の4要素/3等間隔を保ちながら収まらない場合は現在/総秒とframe+loopの2行へ。Loopは48targetでtoggle semantics。Timeline toolbarはtop border1px+48px操作帯と各control48pxを確保、export key追加。色は既存Theme役割のまま。after oct26-s11-layout-export-after.jsonl5realPASS77.191s、含む再生値3/20→0.2s/2.0s/loopcallbackと7言語×24幅×文字1/2×normal/fullscreen親padding×5frame境界=3360case/0failure。元popup7PASSとは実行範囲を区別し単純合計しない。native/全状態/全体解析/通常build/公開は未完了、WIPを完成と扱わない。

次: ここまでをDrive保存→production nativeで長い実projectのbefore/afterとloop/seek/play/fullscreen/短画面/keyboard、実Canvas→Timeline toolbar横scroll→Exportを確認。現在bundleはS10通常lib/main.dart。新nativeharnessを用意し、beforeは3b9acd8のProjectDetail/Timeline2filesを一時使用してbuild、finally必ずS11source+元fontへ戻す。修正前GUIを新sourceの証拠へ混ぜない。source/証拠hashと全体formatter30前後の残差、full analyze/defaultbuild、関連回帰を続ける。OS bold・fullscreen short-heightの反例確認も残る。初回誤pathのCLI2loaderrorsはoct26-s11-layout-export-invalid-path.jsonlへ隔離し、製品反例の件数へ数えない。

### S11 Discovery追加

actual10008-frame projectでHome白thumbnailに名称white textが重なり読みにくい反例をnative原本で確認、DISC017をtodo登録。palette反転/固定色ではなく正式なcaption surfaceとfont/target/長い名称を確認する。現在はbefore runner起動中、previewのlastframe/loop/seek/fullscreen beforeを先に確認する。

### S11追加riskを登録（完了へ昇格しない）

DISC018: ProjectDetailの_rendering中に最新seek要求が落ちる可能性。現nativeは全blankframesで絵の違いを検出できないためsource品質リスクとして登録し、異なる絵柄/遅延境界のcounterをA006/Discoveryで実施。DISC019: nativeFR320/text2の4列quick actionsでÉtiquettes語中改行等の読みやすさを登録。S11のCI/再生status修正だけでA006/実描画/これらの解決を申告しない。

### 2026-10-27 A003/S11 validated source / incomplete visual evidence

## Current continuation — 2026-10-27 (authoritative over historical notes below)

- Baseline done2/628, current A003 in_progress. DISC001–019 todo/cursorDISC001, Delta not_started. No full-audit or latest-HEAD Visual closure claim.
- Source is restored exactly from Drive1U1EGKOdKX4T095ku6V-IqY4RNZTjTaQO (4,830,664 bytes /256entries /SHA256 d00fcf77d4fbb3c36b519f070dfdc8dc8eb38bcdbab71785ce89b9754e8be1a8). Metadata, raw byte count/hash, ZIP CRC and all255 manifest hashes verified. Current remote parents re-fetched: App3b9acd833be242d91b01f9d1998a7647564aa155 /Web673ce587da6cdd0376945acdec30d68665a2f5cc.
- Validated repair unit being published: responsive Project playback status with48px loop/toggle semantics, cached widest proportional-digit measurements to prevent statusheight changes during playback, adaptive fullscreen/short-height scrolling/Escape/back; Timeline49px toolbar including1px border and48px controls; exact-export test uses actual320px scroll/tap/current compositeicon key without overflow suppression; popup test respects explicit formal menu surface; only two unused bulk-favorite keys removed across7languages. All product colors remain formal theme roles; no fixed neutral/automatic recoloring.
- Saved completed tests: layout/export5PASS77.191s; fullscreen/matrix5PASS74.642s; latest numeric continuity+OSbold/matrix/globaltextscale/exact-export6PASS60.417s (3360 matrix conditions). These overlap and must not be added. Community details actual horizontal/vertical productionRouter taps3PASS8.996s. Popup/l10n/role tests7PASS14.922s. Latest full analyzeNoissues5.1s.30format-only files are byte-identical to formatting their original HEAD with package languageVersion3.12, hashes verified after restore.
- Fresh native BEFORE originals are saved: real10008 blank-frame/24fps/417s project, FR320/text2; oldloop34px and shortfullscreen image~42px. Native AFTER was operated and images opened twice before environment resets: first/last counter/time, loopoff/restartpause, stable transportheight,320x220 fullscreen. Those AFTER files/build receipts were created after the savedZIP and were lost; do not claim archived Visual closure. They must be recaptured and immediately uploaded.
- The12-file related-final regression (save safety/tile/slot/tree/allroutes/timeline/popup/role/l10n) was interrupted by reset; at least36cases had passed but no done receipt survived. Its outcome is UNKNOWN; rerun this unfinished job, not completed unchanged matrices. Normal lib/main.dart build for this unit remains pending; native fixture AFTER builds had succeeded but their receipts were lost. CI for S10 was14success/1failure workflow; fullgates2104PASS/23skip/5FAIL (old4 plus obsolete source-string community-route assertion). Allgreen is not claimed.
- Immediate next action: complete normal expected-parent push and remotehead/tree verification, save publication receipt; then recreate only runtime needed for unfinished native/export checks and related regression. Finish A003 thumbnail/selection/folder/Works/Bookmarks/continuity conditions, including DISC017 caption readability, DISC016 renderer delay and the remaining registered issues. DISC018 renderinglatest and DISC019 narrow labels are unclosed; this playback repair does not close them.
- Environment resets reverted local workspace to initial Oct21 twice. Source and completed logs survive in verifiedDrive; no source reimplementation or broad history reconstruction is needed. Store binary/reproduction cache or capture+upload in the same meaningful step before longer work. Previous process IDs are dead; no current nativeapp/FlutterCLI/SDK is assumed.
- Pinned runtime recovery: Flutter3.47.7/Dart3.13.5 archive https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.7-stable.tar.xz (NO extra /flutter path), SHA256 af7455f540df951184c7953fbe3cf884766e7541dacf8571f9f582db03dd6230. Restore187pub packages/223native packages using saved scripts. SDK bootstrap: directly run `dart pub --directory tools/flutter/packages/flutter_tools get --offline --enforce-lockfile` before app `flutter pub get --offline --enforce-lockfile`; otherwise SDK-internal get may wait online. Never run Flutter CLIs in parallel.
- Original user font1,022,464B/SHA2564e88513583b672a759fbb967dcaef291e46d52902a963e8140c441fd55b0f350 is preserved and EXCLUDED from commits. Canonical Gitfont SHA2564ff87a0965f1b0505e5a2c58424bc6ad3cff27e56a82f21c2fc9d6b0e3857ee2 is used only under a temporary guard. After interrupted commands/Git writes explicitly recheck/restore original; SIGINT may terminate before finally. No physical Android/DeX/touch/pen/SR/liveOAuth/backend/codec PASS.


### 2026-10-27 S11 completed unit / S12 quality risks

# A003/S12 — 2026-10-27 current continuation

Baseline done2/628/current A003 in_progress. DISC001–023 todo/cursorDISC001; Delta not_started. Full audit and latest-HEAD Visual closure remain incomplete. LockedBaseline IDs/order/definitions unchanged. Detail parentIDs inDISC018/019 corrected to A009 (A006 isfolder).

## Completed S11 unit

App9b1f43c3b016d19b1b0f6a6a3fdbb14ecd4a6c32 /Web3f5430648f503d94084a344dd9c50c8aaabf6c01 pushed nonforce, expectedparent/head/tree/comparepaths/ahead1behind0 and actualfetch/equalindex/tree/localrefverified. App57files include playback status responsive48target/cached proportional digit width/OSbold continuity, adaptivefullscreen/shortscroll/Escape, Timeline48targets+border, actualExport route test without overflow suppression, popup explicitrole test,2unusedbulkfavoritekeys removed7locales,30canonical-format-only files. Nofixed UIneutral colors.

Latest9b1 CI20workflowsSUCCESS. SaveSafetyfullgates job121671993802: format727files0changes; analyzeNoissues24.6s; fullsuite2112PASS/23skip/0FAIL17m26s. Save-regressions/community-contracts/allroutes/persistence/pinch/theme etcsuccess. Saved rawlog s11-current-CI-full-gates.log and s11-ci-final.json. These replace the reset-interrupted local12file relatedjob; do not rerun unchanged completed tests. Earlier targeted6PASS60.417s includes3360geometry conditions andOSbold continuity; community actualRouter3PASS; popup/role7PASS are saved, overlappingruns not summed. Normal lib/main.dart Linux debug build oct27-s11-normal-build.log SUCCESS; canonicalfontguard restored original.

Actual productionUI/isolatedsaved10008blankframe project (24fps/417s/320x180): FR/SP320/text2 first→last with stabletransportheight; loopoff atlast→play/restart→pause23/10008/0.9s; fullscreen320x220 usefulimage+allcontrols;320x160scroll reachestransport, Escape returns withframe/loop preserved. Detail editCTA→Canvas compositeTimelineglyph→Timeline actualhorizontaldrag→Export works. Alloriginals individuallyopened; exportcodec/file success NOT claimed. EN/forcedPC1440x900/text1/paperfixture sets all9formal settings (navy/sand/peach/burgundy/cream/blue), first/last417s/fullscreen/Escape verified; artwork stayswhite. No physicalAndroid/DeX/touch/pen/SR/liveOAuth/backend/codec/performancePASS.

## Durable evidence and replay

Original S11 source/tests/pre-nativeZIP1U1EGKOdKX4T095ku6V-IqY4RNZTjTaQO4,830,664B/SHAd00fcf77d4fbb3c36b519f070dfdc8dc8eb38bcdbab71785ce89b9754e8be1a8 verified. Publication receipt1fbdjasfK7QkLMGiytCBK6QBpYPNcHBCR9,683B/SHA36423056e77137239918cc71a995adda072ccd34ef14beb4e575ec768d8c5e89 verified. Native01 Drive1dfBfWWZl5ZkGQtcTmD9_CE_Hneo2Anvo3,529,835B/SHAba136cd6799bb2f5ffc305984ea464bf2d82111245aec3515227670957c2cfa5; Native02 Drive12ABfGdjJPZGl2L1E41gb4pZL0GmWMFTI3,582,729B/SHA5d00def8f530b88692a343dc074463543917c9965cc9b67029963311651a6458; Native03 Drive1_LrKeik0ZbyToV8XB6m-5U8hCytO7tnj3,806,429B/SHA29ead3fd1ac991f0eb8f480a79c7626c7b2a655eecb66a94e3f2a58bc2c1da74. Metadata/rawbytes/SHA/CRC/allmanifestverified for each. Native04 withPC/normalbuild/currentnotes is next.

Compiled9b1 auditfixture replay is now saved in TWO independent validZIPs (connectorlimit100MiB; original110MBfile rejectedbeforewrite): part1 Drive1fnjRJnB5rMVHduIefcuuL_J0U902gIgG68,385,858B/SHA78b3aa5ec66e4d92f3b23a2af7abed9f1a2f48e5882f44a0c751f792ffef5770; part2 Drive1Lo6zm88M5dksm8u2xa0YXNJ1YU364a1_31,371,062B/SHA890cdd502ae6270bbb2d1fbacb0a3a60fc677186e737900ed2a6dfd91d52198f. Bothmetadata/rawSHA/CRCverified, all73globalmanifestfiles verified acrossparts. ExtractBOTH into root, restore recordedmodes, restore223nativepackages/relocate via saved scripts, run saved nativeconsole. Replay of thissource needs noFlutterSDK/rebuild. It is an auditfixture, not a releasebuild. Currentlocalbundle nowNORMAL lib/main.dart; usecachedfixture orrebuildharness beforeUIchecks. Nativeconsole48230/Xvfb83alive butappSTOPPED.

Runtime rebuildscript ZIP1-S7KSwfKMk2qszV4f9TrPNlAyYpKd-D5/30,299B/SHA35bafc1d78de6edcaac6d90f75606b8e0be5230152e306f3cca0a4ef403f55ec metadata/rawCRCmanifestverified. `tools/restore_s11_runtime.py --build-fixture` restores pinnedSDK3.47.7/Dart3.13.5, pub/native/FFmpeg and builds onlyharness, without completedtestrepeats. InitializeSDKtooloffline packageconfig beforeapp pubget. NeverparallelFlutterCLIs. Originaluserfont1,022,464B/SHA4e88513583b672a759fbb967dcaef291e46d52902a963e8140c441fd55b0f350 preserved/excludedfromcommits; canonical4ff87a0965f1b0505e5a2c58424bc6ad3cff27e56a82f21c2fc9d6b0e3857ee2 onlyunder guard. Gitwrites/SIGINT canleavecanonical; recheckoriginalafterward.

## Current S12 work and next action

No S12 productcode fix yet. One uncommitted assertion was added to existing exactExport test to require Export visible beforehorizontal scrolling; fresh oct27-s12-export-visibility-before.jsonl FAIL1/32.088s: Export rect.right344>320. This is a valid newproductquality counter; HEAD9b1 CIstillgreen and does not contain thisnewassertion. Do notpushfailingtestalone.

Priority: (1) DISC017 currentA003 thumbnail/name: actualPNG200x113 hasalphaall0 afterCanvas/autosave; Detailretainswhiteprojectbackground butHome showspeachCardthroughPNG. Composite actual project.backgroundColor behindtransparentthumbnail (functionalcontentcolor), add formalcaption surface/text, readable longnames and adequate independentmenu/selection/favorite targets without hardcodedUIblack/white. (2) DISC021 makeprimaryExport visible; review logicalgrouping ofAddWatermark withAddMaterial whilepreservingeveryaction andfree/Premiumgates; avoidmerelyhidingcontrols inhorizontal scroll. (3) DISC022 adapt3preset choices to actualtextwidth/scale/7languages; currentKuramubonfont is correct, do notreplaceitbecauseLatinlooksDela-derived. Thenrelatedtests/matrices, realbefore/after+regression+save/push. DISC020 Canvas32/33targets andDISC023 white-art Timelinecounter are registered risks, noPASS. DISC018 latest-render andDISC019 quicklabel wrap remainpending.

KeepA003 ordinary/empty/large/Works/Bookmarks/errors, selection/folder/search/view/favorites andcontinuity remainingconditions. Afterpriorityrepairs continuefixedRoute, notnewclosureclaim. Save captures BEFORE review, thenrecordreview, so resetsneed download/view ratherthanre-operation. Source/code belongsGit; evidence/repro backups belong authorizedDrivefolder1fiZEjCVqLtNVk_mkNIOUC3MWn6ys6e8q. No repeatedpermissionrequests fornormalpush/save.

Native04 Drive1aR8-fL1bf6-MOZ1i_15YsbBfcJi5s1hG/3,933,769B/SHA16b1e62fac8ca25b976453b7caa6f34a72515c08aa6e466741fb268613ea551f is metadata/rawSHA/CRC/allmanifestverified; includes15individuallyreviewedsource9b1 originals, completednormalbuild/CI2112 logs, registeredrisks, cachedreplay receipts andnewS12counter. This is scopedS11 evidence, notfinalfullauditVisualclosure.


### 2026-10-27 S12 検証単位・リセット復元

# A003 / S12 — 2026-10-27 再開正本

## 進捗と一次事実

Baseline done 2/628、current A003 in_progress。Discovery DISC001–027 は todo、cursor DISC001。Delta not_started。全面監査・最終Visual closureは未完了。locked BaselineのID/順序/definitionは変更していない。

本単位の親HEADは App f9c756a73c65ae4e0a1597ca21cc4ccf7346942b / Web 40f4cf835064a586b2bbad35c4945c0fe615c7d3。再fetch済み、追加更新なし。S11製品修正9b1f43c3b016d19b1b0f6a6a3fdbb14ecd4a6c32のCI20workflow成功・fullsuite2112PASS/23skip/0FAILは既存証拠で引き継ぐ。S12とは別の結果であり、重複加算しない。

## 検証したS12修正単位

- Home: 透明PNGの背後に実作品backgroundColorを合成。project/folder名を画像から分離し、正式Card/Menu背景とMenuText前景のcaptionへ配置。長名は1行省略＋全名semantics/hover tooltip。caption長押しは親の選択操作へ届く。三点menuを48pxにし、文字倍率/太字を測定した最小高さでmenu・favorite・captionの重なりを防ぐ。選択/pickerではmenu枠を残さない。
- Timeline: Exportを右端48pxに常時表示。他5controlは320pxで収まり、極端な小幅だけ横scroll。watermark追加をAddMaterialの5項目目へ集約し、選択時にもPremium gateを再評価。text/image/video/audio経路は保持。
- Export: 同じenum値をmodels/export_preset.dartへ移し、旧export_screen.dartからreexportしてAPI互換を保持。全ラベルが収まる時は3分割、狭幅は3項目popup。文字を縮小せず、長いLatin単語の途中分断を避ける。選択前景は正式selectionTextColorを継承。
- Help: 7言語でwatermark導線、standard/high/customとcustomFPSの説明を更新。特許/ライセンス上安全と断定する未裏付け表現を削除。法務適合そのものを合格にしたわけではない。

UI固定黒白/自動neutralは追加していない。サムネイルbackgroundColorは作品内容の色。caption/menuはTheme.cardTheme.color・popupMenuTheme、favoriteはcolorScheme.primary、選択は既存selection role、Export popupは正式menu前景/背景を使う。既存9設定/4前景/APCA absLc<10救済/CVD/cache/保存形式/28presetを変更していない。

## 保存済み検証

- oct27-s12-responsive-related.jsonl: canonical fontで7file/33realPASS/0FAIL/28.684s。8透明thumbnail条件、formal caption前景/背景、長押し、48menu、favorite/selection/picker、実Timeline/AddMaterial/watermark/Export導線、textmaterial、Premium wiring、unused key、7ARB×2フォントcoverageを含む。
- oct27-s12-export-preset-matrix.jsonl: 3realPASS/74.551s。24幅×7言語×標準/2倍×通常/OS太字×3選択×明暗＋28theme catalogの4620条件、70PNG、0failures。3選択callbackとEscape cancel、wide選択前景を確認。70部品原本の上部を等倍contact sheetsで全件確認し、Spanish custom/lightとFrench highQuality/darkの全原本も開いた。部品matrixを製品全画面の完了に置換しない。
- S12 canonical native fixture build成功。production NiarimApp/router/providersを隔離された実10008 blank-frame projectで操作。native build時の全303製品Dart hashは復元後ソースと全件一致。実描画フレーム差/codec/性能の合格ではない。
- FR/SP320/text2: Home透明thumbnail/caption/menu、Detail→Canvas→Timeline→Export、scroll前からExportを実tap、AddMaterial5項目、watermark未登録dialog、3preset選択、customFPS30→31、BackでTimeline復帰を操作・目視。
- EN/PC1440/text1/formal paper設定: caption full-name hover、長押し選択、menuからfavorite追加、keyboardでOpen→Canvas→Timelineを操作・目視。作品背景は白、UIはnavy/sand/peach/burgundy等の9正式設定が反映。
- full analyze cleanはリセット前に観測したが、そのrawlogは未uploadで消失。testのみのif braces修正を再適用。CIでformat/analyzeを追跡する。通常mainのS12 build、最新wide native Export原本、全A003表示条件は未完了。

## 証拠と復元

- Source/matrix/33tests/70PNG checkpoint: Drive [matrix-current](https://drive.google.com/file/d/139xlyIhjg2xHHOYEGiJZC4Be4k-IqmuN/view?usp=drivesdk)、5,642,906bytes、SHA256 35c12ba7d33654d475dde9daec50c19358cb3ccb19c7f4ecf207e886259a5a1e。metadata/rawSHA/CRC/全364manifestを再検証して復元。
- Native最新保存済み: Drive [native10-captures](https://drive.google.com/file/d/1Ekn9Uv5argZXqByNmFYDQwhBhet0Z2xi/view?usp=drivesdk)、865,559bytes、SHA256 f808977e84571f5f2a764c00c8d0ad7729be474f5b8b9fdb8b745965f8462c43。metadata/rawSHA/CRC/全27manifestを再検証。23原本＋actions＋native source proofを保持。
- 原本名訂正: s12-fr320-add-material-menu.pngは実際は演出filter sheet、s12-fr320-add-material-options.pngはExport画面。正しいAddMaterialはs12-fr320-add-material-actual.png。s12-en-pc1440-paper-home.pngは実際FR（LANG環境変数誤指定）、以降tooltip/selected/menu/favorite/canvas/timelineは正しいLANGUAGE=en。誤原本を成功の代用にしない。
- 環境リセットで、後続projectgrid4620条件の追加test/source/log/report、wide Export最新原本、full-analyze-clean rawlogが失われた。正式coverageへ加算しない。復元済みの33tests・Export4620・native sourceは再実行不要。projectgrid追加matrixだけ必要時に再構成する。
- ユーザー既存font 1,022,464bytes/SHA256 4e88513583b672a759fbb967dcaef291e46d52902a963e8140c441fd55b0f350を復元・保持しcommit対象外。canonical font 4ff87a0965f1b0505e5a2c58424bc6ad3cff27e56a82f21c2fc9d6b0e3857ee2は検証時のみ。Git書込み/中断後に再確認。

## 未完了と次の操作

S12修正単位をexpected-parent/nonforceで通常pushし、remote HEAD/tree/path差分、実fetchを確認。CI追跡、publication receiptと最新source/State/証跡をDrive保存/readback。次にA003通常3件/大量120件・Works/Bookmarks loading/error/nonempty、folder/search/view/favorite/選択とtab往復の継続性を固定Routeに従って続ける。

DISC017/021/022の優先修正済み部分をDiscovery doneへ昇格しない。DISC018 render/seek、019 quicklabel、020 Canvas targets、023 Timeline白作品counter、024 exportFPSと作品時間、025法務copy/実rights、026共有temp並列、027演出filter header等は残る。Android/DeX/touch/pen/SR/liveOAuth/backend/codec/performanceは未検証。正常main buildや全presetの製品実操作をテスト/存在確認で代用しない。上限前の一括保存を待たず、検証済み単位を先にGitへ確定する。
