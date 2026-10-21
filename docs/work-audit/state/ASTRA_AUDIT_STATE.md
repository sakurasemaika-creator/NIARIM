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
