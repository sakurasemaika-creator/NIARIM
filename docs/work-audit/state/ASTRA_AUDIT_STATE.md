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

## A003 — ホーム /home・初回案内・ドロワー

status: done（2026-10-17、製品修正 App（`d83cbe4`）、証跡 https://claude.ai/artifact/C6t3uteANocXs9nTLizazi#A003）

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
6. 初回案内が「はじめる」以外で閉じると表示済みにならず再起動のたびに出る→閉じ方に関わらず表示済み。案内そのものが1文だけで操作を学べない→DISC003。
7. 初回の説明カード（`FirstUseTooltip`）：戻るで閉じず下の画面へ戻る・Escが効かない・背面のCtrl+Zが動く・同じタップで開いたダイアログが先に閉じる・Android 16の予測型「戻る」でアプリが閉じる（Overlayで重ねていたため）→専用のルートとして積む。画面とServiceの破棄後の記録で例外→破棄後は記録しない。
8. PC（DeX）幅でもスマホの画面を引き伸ばしただけ→1000px以上は引き出しの中身を左に常設（上部バー・タブはその右）。
9. その他：ツールチップ未設定（＋ボタン・表示サイズ）を追加、情報アイコンのタップ領域40px・読み上げ・吹き出しの幅/位置、空状態の表示を狭い高さでもスクロール、タブバーの高さを文字倍率で計測。

### 表示マトリクス・回帰

- `test/home_display_matrix_test.dart`：24幅×SP(844)/PC(900、PCモード)×7言語=336通り（作品一覧・ブクマ済みは5幅でも撮影）で例外・タブ名の省略・上部ボタン/FABの画面外・PCの側面パネルの有無が0件。全画像を言語×モードの14枚のシートで目視（影を本物で描画）。
- `test/home_navigation_state_test.dart`（18件：検索のフォーカスと絞り込み、検索欄のCtrl+A、Enter後のCtrl+Aは見つかった作品だけ、閉じる/Esc後のショートカット、戻る3段、矢印、`go('/home')`のホーム、引き出しを開いたままの戻る×2、別画面の上の矢印、タブ離脱、スクロール保持、初回案内、ブクマ→作品広場、非公開・削除で表示できないブクマ、PC側面パネル、スマホのメニュー）、`first_use_tooltip_gesture_test`（7件追加：戻る・破棄・フォーカスとEsc・ダイアログとの順序・PopScope画面・破棄後のService・押したボタンの画面の作り直し）、`info_icon_tooltip_test`（読み上げから開く・戻るで閉じる・760×360の文字2倍で画面内×3・ヒンジのある折りたたみ端末）、`canvas_focus_return_test`（タッチ・マウス）、`shortcut_repeat_test`、`typing_aware_shortcuts_test`（入力中は止まる・Enter/フォーカス解除で画面へ戻る・ダイアログの上では戻さない・3画面のソース）。
- 独立レビュー（並列の観点別レビュー＋反証役）の1回目で8件（フォーカス・引き出し・ダイアログ順・予測型戻る・矢印・繰り返し）、2回目で7件（表示できないブクマ、情報アイコンの吹き出しの戻る/はみ出し/読み上げ、側面パネルのシステムバー、タブの自動スクロールと1タブの縮小、全選択は見えている作品だけ、zh_Hant/es/frの誤訳とサブセットフォントの欠字、テストの欠落）、3回目で3件（入力欄でEnter後に画面のショートカットが効かない、タイムラインの全画面表示の初回説明が出ない、折りたたみ端末で情報アイコンの吹き出しが切れる）を修正済み。
- `flutter analyze` 0件。全件`flutter test`は成功1952・スキップ8・失敗4（既知の4件。3回目のレビューの修正前に実行し、修正後に関係するテストを再実行）。

### 判定・申し送り

- 機能 PASS / 挙動 PASS / 見た目 PASS / 継続性 PASS / 製品品質 PASS（初回案内の中身はDISC003で扱う）。
- 未確認（環境なし）：Android実機の戻るジェスチャー（予測型を含む）・ソフトキーボードの確定キー・折りたたみ端末。ウィジェットテストで戻る処理（`handlePopRoute`）とNavigatorの`canPop`、ヒンジのある画面を確認済み。
- 後続IDへの申し送り（既存IDで扱う）：
  - A004：黒い背景色のプロジェクトのカード名が読めない（カードの文字とグラデーションが同じ色）、詳細表示で透明な背景に市松模様が無い、表示サイズ・並び順のメニューに今の選択が出ない、ルートでフォルダが見えるか、簡体字で「お気に入り」と「ブックマーク」が同じ「收藏」、空の一覧の文言、表示サイズ・並び順の保存、仏語の並び替え表示が360〜375pxで「Mis à…」に省略、320pxで並び替えがアイコンだけになる時の読み上げ名。
  - A005：390px幅で選択中の操作バーが86pxはみ出す、一括削除がお気に入りを無視、貼り付けの完了表示、フォルダ名ダイアログの入力欄が`DisposeOnUnmount`を使っていない（全選択が検索・お気に入り絞り込みで隠れた作品を含む件はA003で修正済み）。
  - A006：パンくずリストのタップ領域。
  - A010/A063：キャンバス・書き出しの`go('/home')`で状態を失う、何もしていない新規プロジェクトでも「変更を保存して戻りますか？」、「保存して戻る」がセーブスロット画面を開く。キャンバス・タイムラインの`TypingAwareShortcuts`の実操作確認。タイムラインの全画面表示ではショートカット（再生・Esc等）が一切効かない。
  - A064：書き出し後に作品一覧が古いまま、PNG/JPGのプレビュー、同期のファイル情報取得。A065：共有シートがスクロールしない、ホーム以外で受けた共有の取りこぼし。A066：ゴミ箱の行が詰まる。A069：保存容量の画面がホームをもう1枚積む、120件で読み込み中表示が長い。

## 2026-10-06 state freshness synchronization

- 最新の**製品実装**として確認したApp `dev_branch` は `ce94a15597f213a168abc682a8f49d53fa3c8508`。
- 最新の**製品実装**として確認したWeb `dev_branch` は `ed944b291732f5d9bc4ca0617b7213f8ec212be4`。
- その後の `dev_branch` の先端には監査Policy/Route/Progress/Evidence/Verifierだけを変更する `[audit-*]` commit が積まれている。したがってbranchの最新SHAと製品実装snapshot SHAは同一とは限らない。
- 監査開始時は必ず現在の `dev_branch` HEADを取得し、開始時点以降の変更について監査対象コードが変わっていないか確認する。
- 以前の `770e2c57...` を現在製品HEADとして扱わない。A001は依然 `in_progress` であり、過去のEvidenceから完了を推定しない。
