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

### A002 再調整（2026-10-16・17、ユーザー指摘）

- 指摘：PC 1280×800で起動画面が全体に小さい（並びが画面幅の約半分）。PCはロゴを控えめにボタンを大きく、SPは大きさを変えずボタンとロゴの間隔を広く。続けて「どの画面比率でもアプリアイコン・アプリ名よりボタンを大きく」。全画面でこの水準の釣り合いの調整まで行う（監査基準`HANDS_ON_UI_STANDARD.md`へ「画面ごとの大きさの比率・余白の釣り合い」をApp・Webとも追加）。
- 原因：ロゴ・ボタンとも画面に関係ない固定寸法。アプリ名のロゴ（幅220px）がボタン（150px）より広かった。A002の表示マトリクスの「PC」行は高さを変えただけでPCモードではなく、PCの見た目を確かめていなかった（判定の見落とし）。
- 修正（App `7c96013`・`b928b22`）：ロゴはボタンの基準幅に対する比（モノグラム0.6倍、PC・タブレット0.55倍、アプリ名0.9倍）。PC（isWideScreen）とタブレット（短辺600dp以上）は並び全体を画面幅の約8割まで拡大（2.2倍まで）。SPはボタン150pxのまま、間隔を余白に応じて最大64px。
- 検証：`splash_layout_test`のPC行をPCモードで描画、84通り・336通りの全セルで「ロゴの幅・高さ＜ボタン」、PC/タブレット/SP縦横の比率テスト（変更前は落ちる）。全336画像を目視。実画面でPC 1280×800・1024×768・1920×1080、SP 390×844・360×640・横844×390・横568×320（証跡 A002_rebalance）。

## A003 — ホーム /home・初回案内・ドロワー（Opusブランチの証跡）

status: Opusのブランチ（`ccr-f56ee68e-77ag7y`）で2026-10-17にdoneと判定した記録。2026-10-23にdev_branchへ統合した後のRoute状態はAUDIT_ROUTE.mdに従う（A003 in_progress。この節はA003の完了判定で再利用できる証跡で、現在のHEADで再確認してから使う）。製品修正 App（`d83cbe4`）、証跡 https://claude.ai/artifact/C6t3uteANocXs9nTLizazi#A003）

### 実操作（Linux debug/Xvfb、390×844 ja基準、PC 1280×800・900×800、プロジェクト0件／120件／初回）

- 初回：起動画面→作品をつくる→初回案内「手描きアニメーションを制作できます」→はじめる／Esc／外側タップ／戻る→再起動しても出ない。既訪：案内なし。
- 3タブ（プロジェクト・作品一覧・ブクマ済み）の切替、120件の一覧を下までスクロール→別タブ→戻る、検索（キーワード・タグ切替、日本語・英数入力、Esc、戻る、Ctrl+A）、複数選択中のタブ切替。
- ドロワー8項目（共有・ゴミ箱・自動塗り設定・容量削減・設定・ヘルプ・活用Tips・プレミアム）へ遷移→戻る→ホーム、ドロワーのEsc。
- 起動画面へ戻る：左上の矢印・端末の戻る（検索中・選択中・フォルダ内は1段ずつ閉じる）、キャンバス→ホームボタン（`go('/home')`で履歴1枚）→矢印で起動画面。
- PC：1280×800（PCモード）で左に常設の項目一覧、ゴミ箱→戻る、1000px未満はメニューボタン。

### 発見と修正

1. タブを切り替えるとプロジェクト一覧のスクロールが先頭へ戻る→フォルダ・表示サイズごとの`PageStorageKey`。
2. ブクマ済みタブが「近日公開」（作品広場のブックマークは実装済み）→空のときの説明と「作品広場を見る」（7言語）。
3. 検索を開いても入力欄にフォーカスが無い・Escで閉じない・戻るでホームごと離れる→開いたら入力欄へ、Esc・戻る・左上の矢印は検索だけ閉じる。
4. 検索欄でCtrl+Aを押すと、検索で隠れた作品まで122件すべて選択（画面全体の`CallbackShortcuts`が入力欄より先にキーを取る）→`TypingAwareShortcuts`（入力中は画面のショートカットを無視、ホーム・キャンバス・タイムライン）。Enter・欄外のクリックで入力を終えたら画面へフォーカスを戻す（戻さないとショートカットが以後効かない）。キャンバスは描き始めたら入力欄からフォーカスを戻す。キーの押し続けによる繰り返しは取り消し・やり直し・コマ送りだけ（Ctrl+V押し続けで作品が次々に複製された）。
5. 戻る：作品一覧/ブクマ済みでも選択・検索が残る→プロジェクトタブを離れたら解除、上部の操作とショートカットはプロジェクトタブだけ。`go('/home')`で来たホーム（履歴1枚）で戻るとアプリが閉じる（go_router 13は`PopScope`を呼ばない）→`BackButtonListener`で受けて起動画面へ。引き出しを開いたまま戻ると裏で選択が解除され引き出しは残る→引き出しから閉じる。保存容量の画面から開いたホームで「起動画面へ戻る」矢印が前の画面へ戻る→常に起動画面。
6. 初回案内が「はじめる」以外で閉じると表示済みにならず再起動のたびに出る→閉じ方に関わらず表示済み。案内そのものが1文だけで操作を学べない→DISC014（統合時にDISC003から番号を振り直し）。
7. 初回の説明カード（`FirstUseTooltip`）：戻るで閉じず下の画面へ戻る・Escが効かない・背面のCtrl+Zが動く・同じタップで開いたダイアログが先に閉じる・Android 16の予測型「戻る」でアプリが閉じる（Overlayで重ねていたため）→専用のルートとして積む。画面とServiceの破棄後の記録で例外→破棄後は記録しない。
8. PC（DeX）幅でもスマホの画面を引き伸ばしただけ→1000px以上は引き出しの中身を左に常設（上部バー・タブはその右）。
9. その他：ツールチップ未設定（＋ボタン・表示サイズ）を追加、情報アイコンのタップ領域40px・読み上げ・吹き出しの幅/位置、空状態の表示を狭い高さでもスクロール、タブバーの高さを文字倍率で計測。

### 表示マトリクス・回帰

- `test/home_display_matrix_test.dart`：24幅×SP(844)/PC(900、PCモード)×7言語=336通り（作品一覧・ブクマ済みは5幅でも撮影）で例外・タブ名の省略・上部ボタン/FABの画面外・PCの側面パネルの有無が0件。全画像を言語×モードの14枚のシートで目視（影を本物で描画）。
- `test/home_navigation_state_test.dart`（18件：検索のフォーカスと絞り込み、検索欄のCtrl+A、Enter後のCtrl+Aは見つかった作品だけ、閉じる/Esc後のショートカット、戻る3段、矢印、`go('/home')`のホーム、引き出しを開いたままの戻る×2、別画面の上の矢印、タブ離脱、スクロール保持、初回案内、ブクマ→作品広場、非公開・削除で表示できないブクマ、PC側面パネル、スマホのメニュー）、`first_use_tooltip_gesture_test`（7件追加：戻る・破棄・フォーカスとEsc・ダイアログとの順序・PopScope画面・破棄後のService・押したボタンの画面の作り直し）、`info_icon_tooltip_test`（読み上げから開く・戻るで閉じる・760×360の文字2倍で画面内×3・ヒンジのある折りたたみ端末）、`canvas_focus_return_test`（タッチ・マウス）、`shortcut_repeat_test`、`typing_aware_shortcuts_test`（入力中は止まる・Enter/フォーカス解除で画面へ戻る・ダイアログの上では戻さない・3画面のソース）。
- 独立レビュー（並列の観点別レビュー＋反証役）の1回目で8件（フォーカス・引き出し・ダイアログ順・予測型戻る・矢印・繰り返し）、2回目で7件（表示できないブクマ、情報アイコンの吹き出しの戻る/はみ出し/読み上げ、側面パネルのシステムバー、タブの自動スクロールと1タブの縮小、全選択は見えている作品だけ、zh_Hant/es/frの誤訳とサブセットフォントの欠字、テストの欠落）、3回目で3件（入力欄でEnter後に画面のショートカットが効かない、タイムラインの全画面表示の初回説明が出ない、折りたたみ端末で情報アイコンの吹き出しが切れる）を修正済み。
- `flutter analyze` 0件。全件`flutter test`は成功1952・スキップ8・失敗4（既知の4件。3回目のレビューの修正前に実行し、修正後に関係するテストを再実行）。

### 判定・申し送り

- 機能 PASS / 挙動 PASS / 見た目 PASS / 継続性 PASS / 製品品質 PASS（初回案内の中身はDISC014で扱う）。
- 未確認（環境なし）：Android実機の戻るジェスチャー（予測型を含む）・ソフトキーボードの確定キー・折りたたみ端末。ウィジェットテストで戻る処理（`handlePopRoute`）とNavigatorの`canPop`、ヒンジのある画面を確認済み。
- 後続IDへの申し送り（既存IDで扱う）：
  - A004：黒い背景色のプロジェクトのカード名が読めない（カードの文字とグラデーションが同じ色）、詳細表示で透明な背景に市松模様が無い、表示サイズ・並び順のメニューに今の選択が出ない、ルートでフォルダが見えるか、簡体字で「お気に入り」と「ブックマーク」が同じ「收藏」、空の一覧の文言、表示サイズ・並び順の保存、仏語の並び替え表示が360〜375pxで「Mis à…」に省略、320pxで並び替えがアイコンだけになる時の読み上げ名。
  - A005：390px幅で選択中の操作バーが86pxはみ出す、一括削除がお気に入りを無視、貼り付けの完了表示、フォルダ名ダイアログの入力欄が`DisposeOnUnmount`を使っていない（全選択が検索・お気に入り絞り込みで隠れた作品を含む件はA003で修正済み）。
  - A006：パンくずリストのタップ領域。
  - A010/A063：キャンバス・書き出しの`go('/home')`で状態を失う、何もしていない新規プロジェクトでも「変更を保存して戻りますか？」、「保存して戻る」がセーブスロット画面を開く。キャンバス・タイムラインの`TypingAwareShortcuts`の実操作確認。タイムラインの全画面表示ではショートカット（再生・Esc等）が一切効かない。
  - A064：書き出し後に作品一覧が古いまま、PNG/JPGのプレビュー、同期のファイル情報取得。A065：共有シートがスクロールしない、ホーム以外で受けた共有の取りこぼし。A066：ゴミ箱の行が詰まる。A069：保存容量の画面がホームをもう1枚積む、120件で読み込み中表示が長い。

### 統合時（2026-10-23）にdev_branchを優先したもの

- PCの側面パネル（広いPC画面で引き出しの中身を左に常設）は取り下げた。dev_branchのテスト（`home_entry_navigation_test`・`home_scroll_continuity_test`）はPCでも引き出しを開閉する仕様。
- 初回案内を閉じ方に関わらず表示済みにする変更は取り下げた（dev_branchの仕様：「はじめる」を押すまで表示済みにしない、`home_entry_navigation_test`）。
- ホームのタブバーはdev_branchの実装（画面の大きさが変わっても選んだタブを画面内へ寄せる）に、読み上げの「何番目のタブか」と48pxの高さだけを足した。ブクマ済みタブはdev_branchの状態別の表示（読み込み中・取得失敗・未ログイン・表示フィルター）。検索中はホームのショートカットを効かせない（dev_branch）。
- 引き出しの見出しはdev_branchの単色（グラデーションではなく差し色1色）。

### 2026-10-23 統合後の現在HEADでの再確認（Opus・`ccr-f56ee68e-77ag7y`）

- 対象：dev_branch `25723b3`を取り込んだApp `6028253`（ホーム・引き出し・初回案内・空の表示のファイルは`7a33039`と同一であることを確認し、そのビルドで操作）→修正後の`63d6ee8`で再撮影。Linux debug/Xvfb、390×844・1280×800、ライト（既定）・ダーク（レッド（ダーク））。
- 実操作：新規の状態で初回案内（外側タップ・Escでは閉じず「はじめる」で閉じる＝dev_branchの仕様、再起動で出ない・`first_launch=false`保存）、空の一覧の表示、引き出し8項目（共有・ゴミ箱・自動塗り設定・容量削減・設定・ヘルプ・活用Tips・プレミアム）へそれぞれ遷移→戻る、120件で下までスクロール→作品一覧・ブクマ済み→プロジェクトへ戻ると位置を保持、検索（「11」で10件、検索欄のCtrl+Aは文字だけ選び作品は選ばない、Escで閉じ元の位置へ）、左下のFABで起動画面、PCで10列・引き出しのEsc、ダークで各タブ・引き出し・ゴミ箱。いずれも期待どおり。
- ユーザー指摘で直したもの（App `63d6ee8`）：ゴミ箱の「ゴミ箱は空です」が左に寄る（共通の空の表示が幅を取っていなかった、Scaffoldのbodyに置く画面で発生）→幅いっぱいに取る。ブクマ済みの空のアイコンだけ黒（`contrastingForeground`で差し色を黒へ差し替え）→作品一覧と同じ差し色の淡い円に差し色のアイコン、見出しも同じ大きさ（18では390pxで最後の1字だけ改行）。作品一覧の空の表示が上に寄る（高さ400pxの固定の箱）→一覧の高さいっぱい。テスト：`empty_state_placeholder_test`（修正前はx=80.9で失敗）、`home_navigation_state_test`の作品一覧の空の表示（修正前は高さ400で失敗）、`home_entry_navigation_test`のブクマ済みのアイコンは「作品一覧と同じ色・大きさ・下地の円」を見る形へ（ユーザー指定。dev_branchは背景との差3以上を見ていた）。
- 引き出しの見出し「NIARIM」は白光明朝（dev_branch、起動画面の「N-I-A-R-I-M」と同じロゴの書体）。見出しの書体の決まりの対象外（ロゴ）として変えていない。
- ユーザーの判断待ち：ホームのタブの選択中の文字（`selectedTextColor`、ライトでは黒）と、ブクマ済みの読み込み中の表示・ボタン（「作品広場」等、ライトでは黒）は、まだ`contrastingForeground`で差し色を黒へ差し替えている（dev_branchの`28823bd`「contrast-safe selected tabs」の意図的な実装）。ブクマ済みのアイコンと同じく差し色に戻すかはユーザーに確認する。
- 申し送り：
  - A069：容量削減の画面は`_reload`に例外処理が無く、集計（`computeBreakdown`）が失敗すると読み込み中のまま止まる（Linuxでは一時フォルダ＝/tmp全体を数えるため実際に10秒以上止まった。Androidの一時フォルダはアプリ専用で小さいので製品で同じ遅さにはならない）。
  - 監査担当のテスト：`app_web_reference_export_exact_test`は、dev_branchがキャンバスのタイムラインのボタンを`iconBuilder`（矢印つき、Key `canvasTimelineModeButton`）に変えたため、`icon == Icons.movie_filter_outlined`で探せず失敗（dev_branch `25723b3`単体でも同じ）。
- 判定：A003の機能・挙動・継続性はこのHEADでPASS。見た目はユーザー指摘の3件を直したうえで、上の`contrastingForeground`の2か所がユーザーの判断待ちのため、A003はdev_branchのRoute状態どおりin_progressのまま（dev_branchのS9の正式色の対応表とあわせて閉じる）。証跡 https://claude.ai/artifact/C6t3uteANocXs9nTLizazi#A003 （A003_recheck）。

## A004 — プロジェクト一覧・検索・表示・ソート（Opusブランチの証跡）

status: Opusのブランチで2026-10-17にdoneと判定した記録。統合後のRoute状態はAUDIT_ROUTE.mdに従う（A004 todo。A004の監査で現在のHEADで再確認してから再利用する）。製品修正 App（`adf4176`）、証跡 https://claude.ai/artifact/C6t3uteANocXs9nTLizazi#A004）

### 実操作（Linux debug/Xvfb、390×844 ja基準、1280×800）

- 22作品の状態：3階層のフォルダ（シリーズA／第1話／カット素材）・空のフォルダ・同じ名前（ルートとフォルダに「シーン1」）・62字の長い名前・タグ（大文字小文字違い・半角カナ・韓国語）・お気に入り（作品・フォルダ）・英字（apple/Banana/cherry）・全角英字・半角カナ・数字入り（作品1/2/10）・黒/白/透明/ベージュの背景・サムネイル（正常・ファイル無し・壊れたファイル）。
- 更新日時⇔名前、昇順⇔降順、大/中/小/詳細、検索（英字・全角・カナ・一致なし）、お気に入りの絞り込み、フォルダに入る、起動し直し、キャンバスで描いて戻る×3（サムネイルの更新）。

### 発見と修正

1. 名前順が文字コード順（作品10＜作品2、Banana＜apple、全角・半角カナが最後）、フォルダが作品に混ざり作成日時で並ぶ→`compareNames`（全角/半角・カナ・大小をそろえ、数字は数として）、フォルダを先に、フォルダの更新日時は中の作品の最後の更新。ゴミ箱の名前順も同じ。
2. 検索で「abc」→「ＡＢＣ全角」、「かたかな」→「ｶﾀｶﾅ」が見つからない→`nameMatches`（名前・タグ）。一致なし・お気に入りなしでも「プロジェクトがありません／＋ボタンから新規作成」→「一致する作品はありません＋検索をやめる」「お気に入りの作品はありません＋すべて表示」「このフォルダは空です」。検索結果にフォルダの場所を添える（同名の作品を見分ける）。
3. 黒い背景の作品のカード名が読めない（文字と帯が同じテーマの文字色）→作品・フォルダ共通のカードで名前を絵の下の帯へ。サムネイルに背景が無く黒い作品が白く見える・縦長の絵が切れる→作品の背景色（透明なら市松模様）の上に縦横比のまま。詳細表示：作品のお気に入りの星が無い・フォルダの行だけ名前がずれる→星を出し左端を48px四方にそろえ、更新日を添える。
4. 表示サイズ・並び替えのメニューに今の選択が無く、ボタンを覆って開く→チェック（読み上げで選択中）とボタンの下に開く、表示サイズのボタンのアイコンが今の表示を表す。表示サイズ・並び順が起動し直すと戻る→`SettingsService`に保存。
5. サムネイルが同じファイル名への上書きで、画像キャッシュにより2回目以降の編集が一覧に出ない（A064の「書き出し後に作品一覧が古いまま」の原因と同じ）→作るたびに別の名前、使われていない前のファイルは削除（複製が共有するものは残す）。縮小を補間せず細い線が点線→補間。通常以外の合成モードは背景色を敷いて合成。
6. 簡体字で「お気に入り（收藏）」とブクマ済みタブ（已收藏）が同じ語→作品広場のブックマークを「书签」に（ホーム・作品広場・ヘルプ）。仏語の並び替え「Mis à jour」が360〜375pxで省略→「Modifié」。

### 表示マトリクス・回帰

- `test/home_display_matrix_test.dart`：作品を黒/透明/ベージュの背景・縦長・お気に入り・フォルダ（お気に入り）にし、24幅×SP/PC×7言語=336通り＋境目の5幅で詳細表示と検索の一致なしも撮影。例外・タブ名の省略・上部ボタン/FABの画面外・詳細表示/一致なしが出ないことが0件。全シートを目視（320pxの韓国語で詳細表示の日付が語の途中で折れていたため、更新日を別の行へ）。
- `test/project_list_order_search_test.dart`（16件：名前の比較・検索のそろえ方、フォルダが先で読む順、フォルダの更新日時、全角/カナの検索とフォルダの場所、一致なし→検索をやめる、お気に入りなし→すべて表示、検索に当たりお気に入りで隠れているだけ、空のフォルダ、メニューのチェックと起動し直しでの保存、カードの名前は絵の下・背景色と縦横比、詳細表示の星、文字2倍・320px・小表示の検索結果）、`project_thumbnail_refresh_test`（別のファイル・保存し終えてから前のファイルを削除・複製が使うものは残す）、`home_navigation_state_test`に全選択が共有から取り込んだ作品を含めないことを追加。主なテストは修正を外すと落ちることを確認。
- 独立レビューで6件（並べ替えのたびの名前のそろえ直し〔500件で約7.5ms〕、保存前の旧サムネイル削除、検索＋お気に入りの空表示、文字2倍の小表示カードのはみ出し、仏語の表記ゆれ、全選択が共有の作品を含む〔A003の修正で入った〕）を修正。
- `flutter analyze` 0件。全件`flutter test`は成功1973・スキップ8・失敗4（既知の4件）。

### 判定・申し送り

- 機能 PASS / 挙動 PASS / 見た目 PASS / 継続性 PASS / 製品品質 PASS。
- 未確認（環境なし）：Android実機での一覧のスクロール性能とサムネイルのデコード負荷。
- 後続IDへの申し送り（既存IDで扱う）：
  - A085：簡体字の利用規約・プライバシーポリシーは作品広場のブックマークを「收藏」と書いている（画面は「书签」）。法務文書の改訂として扱う。
  - A090/A091：作品広場・作品詳細で簡体字の「书签」の表示を確かめる。
  - A005：複製した作品はサムネイルのファイルを複製元と共有する（複製元をゴミ箱から完全に削除すると複製のサムネイルが消える）。

## A005 — プロジェクト単体・複数選択・クリップボード（Opusブランチの証跡）

status: Opusのブランチで2026-10-23に実操作・修正・再検証した記録（製品修正 App `14c53d7`、証跡 https://claude.ai/artifact/C6t3uteANocXs9nTLizazi#A005）。同日dev_branchへ統合した後のRoute状態はAUDIT_ROUTE.mdに従う（A005 todo。A005の監査で現在のHEADで再確認してから再利用する）。

### 実操作（Linux debug/Xvfb、390×844 ja基準、1280×800）

- A004と同じ22作品の状態（3階層のフォルダ・空のフォルダ・お気に入りの作品とフォルダ・黒/白/透明/ベージュの背景・サムネイル有無）。
- 長押しで選択→作品・フォルダを追加選択→一括で切り取り・コピー・ゴミ箱→確認ダイアログ→元に戻す（時間で消えるまで待つ・押して戻す）、右クリックのメニュー→ゴミ箱→元に戻す、フォルダを切り取り→自分の中へ貼り付け→Escで切り取りをやめる、作品をコピー→貼り付け（複製のサムネイル）、PC幅で選択。

### 発見と修正

1. 選択中の操作バーが390px幅で86pxはみ出し、削除ボタンが画面外→Opusのブランチでは2行に分けたが、統合時にdev_branchの1行の操作バー（全選択・全解除・件数を省略して1行、一括のお気に入りは撤去、`effdd14`、ユーザー指定）へ置き換えた。フォルダを含む選択ではコピーを押せない理由をツールチップで出す点だけを足した。
2. 一括のゴミ箱がお気に入りを無視して移す・フォルダは黙って対象外・移した後に何も出ず戻せない→お気に入りでない作品だけを移し、残す件数と理由を確認ダイアログに出す。移せる作品が無ければダイアログを出さずに伝える。移した後に「N件をゴミ箱へ移動しました［元に戻す］」（1件ずつのメニューも）。操作ボタン付きSnackBarは既定で消えない（`persist`）ので6秒で消す。戻すときフォルダが削除されていれば一番上へ。
3. 貼り付けが結果を確かめず必ず「貼り付けました」、切り取りのクリップボードを空にする（自分の中へ移せないフォルダも消える）→元が残っているか・自分の中かを確かめ、件数と理由を伝え、移せなかったフォルダは切り取ったまま。途中の失敗も移せた分を外して伝える。連打で重ねない。切り取り中は薄く表示し読み上げでも伝え、SnackBarの「元に戻す」とEscでやめられる。Escは引き出しを先に閉じる。Ctrl+Cはフォルダを含む選択をコピーしない（検索中はdev_branchの仕様どおりショートカット自体を効かせない）。
4. 複製が素材（Materials/）を写さず「不足」になる・サムネイルを複製元と共有・名前の「(コピー)」が全言語で日本語→素材とサムネイルを写し終えてから一覧に出し、名前は表示言語で。完全削除は、以前の版の複製が共有するサムネイルを先に写す。
5. 右クリックで何も出ない・Escで選択が終わらない→カード・詳細表示の行の右クリックでメニュー、Escで選択を終える。
6. 名前の入力で空白だけの名前を確定できる・フォルダ作成を二度押しで2つできる・フォルダの編集ダイアログが入力欄を`DisposeOnUnmount`で破棄していない→`NameEntryDialog`、編集ダイアログは`DisposeOnUnmount`。
7. SnackBarの操作ボタンがMaterial3既定の`inversePrimary`で白い下地にほぼ見えない（実画面）→ダイアログの文字ボタンと同じ`primary`。

### 表示マトリクス・回帰

- `test/project_selection_clipboard_test.dart`（320/390px・文字2倍で操作バーが1行に収まる、一括のお気に入りが無い、お気に入りとフォルダを残す一括削除と元に戻す、自分の中への貼り付け、ゴミ箱へ移した作品のコピーの貼り付け、素材とサムネイルを持つ複製、右クリック、Esc、引き出しを先に閉じるEsc、Ctrl+Cとフォルダ、切り取りの取り消しと読み上げ、途中で失敗する貼り付け、空白の名前・Enter・二度押し、保存に失敗する名前のダイアログ、元に戻すが時間で消える、消えたフォルダからの元に戻す）、`snack_bar_action_contrast_test`、`project_thumbnail_refresh_test`、`home_display_matrix_test`（境目の幅で選択中の操作バー）。
- 独立レビュー3観点（データの安全・UI/読み上げ/文言・既存コードとの整合）の指摘のうちA005の範囲を修正。

### 判定・申し送り

- 機能 PASS / 挙動 PASS / 見た目 PASS / 継続性 PASS / 製品品質 PASS（Opusのブランチ時点。Route状態は上記のとおりdev_branchに従う）。
- 未確認（環境なし）：Android実機でのタッチの長押し選択、大きな素材を持つ作品の複製にかかる時間。
- 後続IDへの申し送り（既存IDで扱う）：
  - A006：フォルダの「移動」の行き先に自分の下の階層が出る（選ぶと何も起きず閉じる）。グリッドのカードのメニューはdev_branchの`14e1f6f`で解決済み。
  - A009：詳細画面の名前の変更は空白だけの名前を確定できる（`NameEntryDialog`へ）。詳細画面からゴミ箱へ移しても通知と元に戻すが無い（`showMovedToTrashSnackBar`へ）。
  - A010：キャンバスの「不足素材」のSnackBarは操作ボタン付きで時間で消えない（`persist: false`）。
  - A081：書体の決まり（2026-10-23ユーザー指定：見出し・タイトル・ボタンはくらむぼん、説明文・本文・エラー文・注釈は白光明朝。SnackBarの「元に戻す」は白光明朝のまま）をテーマ全体で確認する。テーマのボタン・SnackBar本文・初回の説明カードの「閉じる」は反映済み（App `8763583`、`test/theme_button_font_test.dart`）。

### 2026-10-23 dev_branch統合後の再確認（Opus・`ccr-f56ee68e-77ag7y`）

- 統合後のHEAD（dev_branch `d9c9531`を取り込んだApp `ab2b946`）をLinux debug/Xvfb 390×844で操作：ホームは左上がハンバーガーだけ、左下に「起動画面へ戻る」・右下に追加のFAB（影なし）。選択中の操作バーは1行（「全選択」「全解除」はくらむぼん、「N件選択中」は白光明朝、切り取り・コピー〔フォルダを含むと押せない〕・ゴミ箱）。ゴミ箱の確認ダイアログは題とボタンがくらむぼん・本文が白光明朝、移した後のSnackBarは本文と「元に戻す」が白光明朝。
- 発見と修正：プロジェクトの一覧（グリッド・詳細表示）・作品一覧・ブクマ済みの一覧の下端が8pxだけで、一番下までスクロールしても最後の行の名前とメニューが左右のFABに隠れたまま（複数選択で画面にちょうど収まるとスクロールもできず、左下の作品名が読めなかった）→一覧の下端に「FAB 56px＋余白16px＋端末のナビゲーションバー」ぶんの余白（App `baae313`）。`home_navigation_state_test`の「一番下までスクロールすると最後の行の名前がFABより上に出る」は修正前に落ちる（名前の下端830px＞FABの上端772px）。修正後の実画面で、複数選択中に一番下までスクロールすると最後の行がFABの上に出ることを確認。
- dev_branchの新しい仕様に合わせたテスト：`home_navigation_state_test`（検索は右上の×で閉じてホームに残る・左下のFABで起動画面へ）、`home_bookmark_states_test`（ブクマ済みのタブのFABは「起動画面へ戻る」1つだけで、追加・新規フォルダは出ない）。
- 表示マトリクス（統合後のHEAD、境目の5幅×スマホ/PC×7言語の選択中の操作バー）：320px幅の仏語・韓国語で「全選択」「全解除」がどちらも「Tou…」「전체 …」と同じに省略され、2つのボタンを見分けられない（長押しのツールチップでは読める。英語・西語は「Sel…」「Des…」で見分けられる。559px以上は全言語で区別できる）。dev_branchの1行の操作バーはユーザー指定の形のため変更せず、ユーザーの判断待ち（案：省略されるときだけアイコン〔select_all／deselect〕にする）。
- 証跡ページ（https://claude.ai/artifact/C6t3uteANocXs9nTLizazi#A005 、Version 4）にA005の節・統合後の画像・操作バーの表示マトリクス7枚を追加し、A003〜A005を「記録・再確認待ち」、頁頭の進捗をdev_branchのRoute状態（Baseline 2/628・現在A003）に直した。
- 上記の操作バーの省略はユーザーの判断で解決（2026-10-23「ラベルが切り詰められた時だけアイコンに切り替える…そうしてください」）：全選択・全解除のどちらかが欄に1行で収まらないときは、2つともアイコン（select_all／deselect、24px、文字のボタンと同じアクセント色。全文はツールチップ）にし、件数はアイコンのすぐ右に左寄せ（App `7ee6139`）。表示マトリクスで調べ直すと英語・西語・簡体字でも一部の幅で省略されていた（西語・仏語は559pxでも）。`home_display_matrix_test`に「全選択・全解除の文字が省略されていない・ツールチップが1つずつある」を足し、修正前のコードで落ちることを確認。実画面：仏語320px（アイコン→全18件選択→ホバーで全文→選択終了）、韓国語320px、日本語390px（文字のまま）。全件のテストでdev_branchの`home_favorites_responsive_test`が240px幅で失敗（左の欄が80pxで48pxのアイコン2つが16pxはみ出し、全解除を文字で探していた）→アイコンの幅を欄の3分の1（最大48px）にし、同テストは全解除をツールチップで探す形に（App `7a33039`）。実画面の240pxで収まることを確認。
- dev_branch `e086838`（お気に入りの星をアクセント色に、ボタンのラベルをくらむぼんの太字に、タイムラインの秒数を送りボタンの横へ等）を取り込んだ（App `2cea8e7`）。こちらのボタンの書式・タイムラインの`?? 0`の修正はdev_branchの実装へ置き換え、SnackBarの本文・操作ボタンの色・切り替えボタンのくらむぼんだけを残した。

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
