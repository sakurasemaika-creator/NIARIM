# CLAUDE.md

このファイルは、次にこのリポジトリで作業するAIセッション（Claude Code等）が
最初に読む前提で書かれている。プロジェクトの基礎知識は`docs/AI設計書/`配下の
番号付き仕様書（特に`00_AIへの指示.md`・`01_プロジェクト概要.md`）にあるため、
先にそちらを読むこと。このファイルは、それらの仕様書には書かれていない
「実際に開発する中で踏んだ地雷・気をつけるべき癖・現在の未完了事項」を
まとめた実践的な引き継ぎメモであり、内容が古くなったら都度このファイル自体を
更新すること（他のドキュメントと同様、削除・書き換えを恐れず現状に合わせる）。

## リポジトリの基礎情報

- アプリ名：NIARIM（手書きアニメ制作Androidアプリ、Flutter/Dart）
- GitHubリポジトリ：`sakurasemaika-creator/MIRANIMA`（git remote名）。GitHub側の
  表示名は`NIARIM`へ変更済みで、`git push`時に「This repository moved. Please
  use the new location: https://github.com/sakurasemaika-creator/NIARIM.git」と
  出ることがあるが、現状のremote URL（MIRANIMA）のままでも自動リダイレクトされ
  push自体は成功する。GitHub操作系のツール（Actions一覧取得等）を呼ぶ際は
  owner/repoとして`sakurasemaika-creator`/`miranima`（小文字）を使うこと。
- 開発方針・禁止事項・命名規則は`docs/AI設計書/00_AIへの指示.md`が正。
- 実装の詳細な変更履歴（誰が何をなぜ直したか、時系列の全記録）は
  `docs/AI設計書/12_実装チェックリスト.md`にある。非常に長いファイルなので、
  末尾から遡って直近の作業内容を把握するのが早い。新しく大きめの作業を
  終えたら、このファイルの末尾に同じ書式（依頼の引用→原因→対応内容→
  検証結果）で追記する慣行になっている。
- 未着手・要再検証タスクの一覧は`docs/AI設計書/28_継続タスク（未着手一覧）.md`。
  着手前に必ず現状のコードを確認すること（記載後に状況が変わっている
  可能性がある）。

## 開発ワークフロー（毎回のセッションで踏襲する）

1. `export PATH="$PATH:/opt/flutter-sdk/bin"`（このリモート実行環境では
   flutterがデフォルトPATHに無い。`/opt/flutter-sdk/bin`に入っている）
2. コード変更後は必ず`flutter analyze`（ベースライン：72 issues、0 errors。
   全て既存のdeprecated_member_use / use_build_context_synchronousのinfoで
   増減が無いことを確認する）
3. `flutter test`（ベースライン：236 tests、全成功。うち大半は
   `test/app_smoke_test.dart`の自律スモークテスト。詳細は後述）
4. ARBファイル（`lib/l10n/app_*.arb`）を編集したら`flutter gen-l10n`を
   必ず実行し直す（対応7言語：ja/en/es/fr/ko/zh/zh_Hant、jaがテンプレート）。
   機械的な文字列置換だとES/FR等で訳が崩れることがあるため、ロケールごとに
   手で訳すこと。
5. コミットメッセージは日本語で、「ユーザーの依頼引用→調査で分かった原因→
   対応内容→検証結果（analyze/testの件数）」の構成にするのがこのリポジトリの
   慣行。ソースコード中のコメントには仕様書番号・Task番号は書かない
   （コードの技術的な説明のみ）が、`12_実装チェックリスト.md`への追記や
   コミットメッセージには経緯を書いてよい。
6. 大きめの作業が終わったら`docs/AI設計書/12_実装チェックリスト.md`へ
   追記し、必要ならこのファイルや`28_継続タスク（未着手一覧）.md`も更新する。

### APKビルド（GitHub Actions）

- `.github/workflows/build-apk.yml`は**手動実行のみ**（`workflow_dispatch`）。
  APIやツール経由で`run_workflow`する場合、`build-type`の入力を省略すると
  既定値の**`debug`**になる（`release`ではない）点に注意。
- 生成物はActions Artifacts（保持1日）に加え、GitHub Releaseへも上書き
  公開される。タグは**ビルド種別ごとに固定**：`build-debug-latest`／
  `build-release-latest`。debugビルドをトリガーしたのに`build-release-latest`
  を確認してしまうと古い内容のままに見える、という事故が起きやすいので、
  自分がどちらのビルド種別を起動したか必ず把握しておくこと。
- リリースの`body`にビルド元コミットSHAが書かれているので、最新の変更が
  含まれているかはそこで確認できる。

## 繰り返し踏んだ地雷・気をつけるべきクセ（重要）

このセクションは実際にバグとして踏んだ／踏みかけた事例。同じパターンの
新規コードを書く・レビューする際は必ず確認すること。

- **`context.go()` と `context.push()`（go_router）の混同**：`go()`は
  ナビゲーション履歴を丸ごと置き換える。画面の奥深く（キャンバス編集中等）
  から`go()`で遷移すると、戻る手段が無くストランドする。新しい遷移コードは
  基本`push()`を使い、`go()`は「一連の操作フローを完了して意図的に履歴を
  リセットしたい場面」（書き出し完了後・プロジェクト作成完了後等）に限定
  して使う。実際に`premium_lock_widget.dart`と`community_work_detail_screen.dart`
  の2箇所でこの誤用によるバグを発見・修正した。新規に`go()`を追加する際は
  「この画面から戻れなくなって困る人がいないか」を必ず自問すること。
- **Material3のTheme個別スタイル未設定でフォントが化ける**：
  `ListTileThemeData.titleTextStyle`・`DialogThemeData.titleTextStyle`・
  `AppBarTheme.titleTextStyle`は、`textTheme`から自動継承されず、明示的に
  設定しないと見出し用フォント（Kuramubon）ではなく本文フォント
  （HakkouMincho）にフォールバックする。`theme_service.dart`の
  `listTileTheme`・`dialogTheme`は既に修正済みだが、新しくMaterialの
  テーマ系クラス（`XxxThemeData`）を触る／新設する際は同じ罠が無いか
  必ず確認すること。
- **`FloatingActionButtonThemeData(shape: CircleBorder())`のグローバル
  設定**：`theme_service.dart`で丸FAB用に設定されているが、
  `FloatingActionButton.extended`（アイコン+ラベル）にもそのまま適用され、
  ラベルがクリップ／オーバーフローする。`extended`なFABを新設する際は
  必ず`shape: const StadiumBorder()`を個別指定すること。
- **`Navigator`/`Overlay`の外側にいるウィジェットへの`tooltip:`指定は
  クラッシュする**：`MaterialApp.router`の`builder`層（画面遷移をまたいで
  常駐する`CommunityFloatingPreview`等）は`Overlay`の外側にいるため、
  子の`IconButton`に非nullの`tooltip:`を渡すと`RawTooltip`が
  「No Overlay widget found」で例外を投げる。この例外はビルド時に
  ウィジェットツリーを壊し、原因と無関係に見える巨大な
  `RenderFlex overflowed by 200000+ pixels`のような誤誘導的なテスト失敗を
  引き起こす（実際に発生し、原因特定に時間がかかった）。この層に新しい
  `IconButton`を追加する場合は`tooltip:`を使わず、
  `Semantics(label: ..., button: true, child: IconButton(...))`で代替する。
- **ダイアログ内`TextEditingController`を`showDialog().then()`で破棄すると
  クラッシュしうる**：ダイアログの閉じるトランジション中にまだ`TextField`が
  controllerを参照しているタイミングと競合し、「used after being disposed」
  で落ちる。`lib/widgets/dispose_on_unmount.dart`の`DisposeOnUnmount`
  ラッパー（`State.dispose()`まで破棄を遅延させる）を必ず使うこと。19箇所で
  実際に発生した既知のバグパターンで、新しいダイアログ入力欄を追加する際は
  最初からこのパターンで書くこと。
- **フォントの代替列（fontFamilyFallback）は本文用と見出し用で別物**：
  `lib/config/font_fallback.dart`に`kBodyFontFallback`（明朝系）と
  `kHeadingFontFallback`（ゴシック系）の2本がある。**見出し用には明朝を
  絶対に入れないこと**。入れると「550엔」のように極太の数字と細い明朝の
  ハングルが同じ単語内に並んで明確に浮く。この不変条件は
  `test/font_coverage_test.dart`が機械的に守っている。
  併せて、コード中で`TextStyle(fontFamily: 'Kuramubon')`と直接指定すると、
  `TextStyle.merge`の仕様で**祖先の（＝本文用の）**代替列を継承してしまう。
  見出しフォントを直接指定する新しいコードを書くときは、必ず
  `fontFamilyFallback: kHeadingFontFallback`も併記すること
  （既存187箇所は対応済み）。
- **ARBへ文言を足したらサブセットフォントを作り直す**：韓国語・簡体字は
  `assets/fonts/Noto*Subset.ttf`（Noto Serif KR/SC・Noto Sans KR/SC Black
  から、UIに出る文字だけを抜いた改変版。元の約75MB→約3.6MB）で補完して
  いる。`lib/l10n/app_*.arb`に新しい文言を足すと、増えた文字がサブセットに
  入っていないためその字だけシステムフォントで表示され、見た目が崩れる。
  `python3 tool/build_fallback_fonts.py <元フォントのディレクトリ>`で
  作り直すこと。`test/font_coverage_test.dart`が取りこぼしを検出する
  （実際に「객」1字の欠落をこれで検出した）。
  ★フォントのcmapを自前で解析する処理を書く場合、**platformID 1
  （Macintosh）のサブテーブルは絶対にUnicodeとして数えないこと**。
  非Unicodeのマルチバイトコードなので、「収録していない字を収録済み」と
  誤判定する（サイト側でこれにより91字が欠落する不具合を起こした実績が
  ある）。読んでよいのはplatformID 0（Unicode）と3/1・3/10（Windows）だけ。
  また、カバー判定は**スタックごとに単独で**行うこと。本文用が持っていても
  見出し用の字抜けは埋まらない（和集合ではなく積集合で判定する）。
- **同梱フォントを増やしたらライセンス登録も3箇所必要**：`assets/fonts/`
  配下は`showLicensePage`に自動収集されない。`assets/licenses/
  FONT_LICENSES.txt`への本文・著作権表示の追記、`license_screen.dart`の
  クレジット、`main.dart`の`_registerBundledFontLicenses()`の
  パッケージ名一覧、の3つを揃えること（`test/font_license_test.dart`が
  監視）。太さ固定やサブセット化はOFL上の「改変版」にあたるので、その旨と
  取得元も書く。Noto Sans KR/SCは予約フォント名（Reserved Font Name）
  `Source`を持つため、採用するファミリー名にこの語を含めてはならない。
- **SVGレンダリングエンジンごとの`<mask>`対応差**：`cairosvg`（Python）は
  `assets/logo/app_logo.svg`が使う`<mask>`要素（ペンとフィルムコマ交差部の
  斜め切り欠き等）を正しく解釈できず、切り欠きが消えて塗りつぶし帯になる
  不具合があった。アプリ内（`flutter_svg`）とChromium（Blink）は仕様通りに
  描画できる。`tool/gen_app_icon.py`はこの理由でChromium
  （Playwright経由、`_find_chromium_executable()`でプリインストール済み
  バイナリを自動検出）を使っている。今後SVGから画像を生成するツールを
  増やす場合もcairosvgは避けること。
- **`ExportEngine`は`Theme`/`BuildContext`にアクセスできない**：
  ウィジェットツリー外の純粋な描画エンジンのため、エンドカード
  （`_renderEndCardPng`）の背景色は既定テーマのアクセントカラー
  （`0xFFFF5C7A`）を直接ハードコードしている。この値は
  `tool/gen_app_icon.py`・`pubspec.yaml`の`adaptive_icon_background`と
  合わせて**3箇所を同期**する必要がある。既定テーマの配色を変更したら
  3箇所とも更新すること。
- **R8（コード圧縮）を疑う前に本当にR8が原因か切り分けること**：過去に
  実機起動直後クラッシュの原因をffmpeg関連ライブラリの切替と誤って
  結び付け一度全面revertしたが、真因はリリースビルドのR8
  （`isMinifyEnabled`）が2つの異なるクラスを誤除去していたことだった
  （1. 自作の`HardwareVideoEncoder`〔Kotlinの`object`〕のシングルトン
  インスタンスフィールド、2. `google_mobile_ads`が内部で使う
  WorkManager/RoomのWorkDatabase実装クラス。後者は
  `androidx.startup.InitializationProvider`というContentProvider経由で
  `Application.onCreate()`より前に初期化されるため、通常の未捕捉例外
  ハンドラーでは原理的に捕捉できないタイミングで落ちており、原因特定に
  最も時間がかかった）。`android/app/proguard-rules.pro`へのkeepルール
  追加（自作コード一式・`androidx.work`/`androidx.room`/
  `androidx.startup`）で両方修正し、**この修正込みのR8有効ビルド
  （`isMinifyEnabled = true`）をユーザーが実機に再インストールし、
  起動・書き出しとも正常に動作することを確認済み**（詳細は
  `docs/AI設計書/12_実装チェックリスト.md`「R8起動時クラッシュの真の
  原因を実機バグレポートで特定」の節）。この経緯があるため、実機での
  原因不明のクラッシュ（特に例外ハンドラーでも捕捉できないもの）に
  遭遇したら、まずR8のusage.txt（GitHub ActionsのArtifactに残る）や
  ユーザーに取得してもらうAndroidの「バグレポート」機能でのログ確認を
  早い段階で検討すること。
- **`backend/`のDynamoDB容量はAlways Free枠25 RCU/25 WCUちょうど**：
  `lib/niarim-backend-stack.ts`の`CAPACITY_PLAN`はテーブル本体15＋GSI 7本
  合計10＝25で上限いっぱい。GSIを足すときは必ずどこかを減らすこと。
  超過するとProvisioned Throughputの課金が発生する。合成時に総和を検証する
  `assertCapacityWithinFreeTier()`を入れてあるので、はみ出せば
  `cdk synth`（＝CIの`backend-ci.yml`）の段階で落ちる。
  なお**GSIを4本足すような機能（期間別ランキング等）は枠に入らない**ため、
  「バッチが事前計算した結果を1アイテムへ書き出し、GetItem 1回で読む」
  方式を採っている（`src/lib/ranking.ts`の設計メモ参照）。同種の機能を
  足すときも、まずGSIを使わずに済ませられないか検討すること。
- **依存パッケージのバージョン固定には必ず理由がある**：`pubspec.yaml`の
  `file_picker: 10.3.10`・`share_plus: ^12.0.2`・
  `ffmpeg_kit_flutter_new_video`等は、AARメタデータ不整合やAndroidビルド
  破壊を避けるために意図的にピン留めされている。コメントを読まずに
  `flutter pub upgrade`等で無条件に上げないこと。
- **OSの文字サイズ設定（textScaler）を前提に置いていないレイアウト**：
  Androidの「フォントサイズ」「表示サイズ」を大きくしている端末では、
  固定幅・固定高のRow/Column/ListTileのleadingが簡単に破綻する。実際に
  「昇順降順ボタンでflowed byのエラーが出る」というユーザー報告の真因が
  これで、既定の1.0倍では再現せず1.3倍以上で確実に再現した。さらに
  ListTileのleadingが幅を専有するケースでは、オーバーフロー警告ではなく
  レイアウト自体が失敗し**実機では画面が真っ白になる**。新しくRow/Column
  へ固定サイズのテキストを並べる際は、Flexible＋`overflow: ellipsis`か
  Wrapを使うこと。`test/text_scale_layout_test.dart`が1.3倍・2.0倍で
  全ルートを巡回して監視しているので、レイアウトを触ったらこのテストが
  通ることを確認する。
- **`shouldRepaint`を1行で無効化しないこと**：`_CanvasPainter.shouldRepaint`は
  30項目を比較しているが、`build()`側で`Map.unmodifiable(...)`のように
  **毎回新しいオブジェクト**を作って渡すと、その1項目が常に不一致になり
  他の29項目に関係なく必ず再描画される（実際にオニオンスキン画像で
  これが起きていて、ストローク1点ごとにキャンバス全体が描き直されていた）。
  ペインターへコレクションを渡すときは、中身が変わったときだけ作り直す
  フィールド（`_onionImagesView`のような形）を経由して**同一インスタンス**を
  渡すこと。
- **アイコンの縁取りに`Icon`を8個重ねない**：`CanvasIconButton`は
  `Icon.shadows`（ぼかし半径0のShadow×8）で1ウィジェットにしてある。
  `Positioned`で重ねる方式に戻すと、1ボタン9ウィジェット×常時20個前後＝
  ツールバーだけで180個のRenderObjectになる。テスト側でも`find.byIcon`が
  1ボタンにつき9件ヒットして`findsOneWidget`が使えなくなる。
  同様に、`CustomPainter`で同じ字形を何度も描くときは`TextPainter`を
  1回だけ`layout()`して使い回すこと（`layout()`はテキストシェーピングを
  伴う重い処理。`help_diagrams.dart`の`_drawOutlinedIcon`が参考）。
- **`TransformationController`にblanketなリスナーを張らない**：
  `addListener(() => setState(() {}))`にすると、パン・ピンチのたびに
  `CanvasArea`全体（build()は150行超）が再ビルドされる。変換値に依存するのは
  `Transform`以下だけなので`AnimatedBuilder`で囲うこと。あわせて
  `_transformController.value = ...`を`setState()`で包まないこと
  （コントローラ自身が通知するため、1フレームに2回ビルドが走る）。
- **`MediaQuery.of(context)`ではなく`sizeOf`/`paddingOf`/`orientationOf`**：
  前者はMediaQueryのあらゆる変化（キーボード開閉・文字サイズ変更等）で
  再ビルドを起こす。
- **キャンバス周りの実描画テストは`tester.runAsync`が要る（最重要）**：
  `flutter_test`は既定でFakeAsync（偽装時間）の下で走るため、次のような
  **本物の非同期処理は`tester.pump(Duration)`を何回回しても完了しない**。
  - `picture.toImage()` / `compositeLayerToImage()` / `toByteData()`
  - `ui.decodeImageFromPixels()`のコールバック
  - `ImageDescriptor`→`instantiateCodec`→`getNextFrame`（PNGエンコード）
  - `File`の読み書き
  症状は「何も起きない」か「10分のタイムアウトでハング」で、原因が
  分かりにくい。実際に`functional_audit_batch20_test.dart`が
  **追加以来一度も通っていなかった**（PNG保存でハング＋選択範囲の切り取りが
  完了しない）。待つ側は`await tester.runAsync(() => Future.delayed(d));`
  してから`await tester.pump();`する形にすること。ジェスチャー自体は
  runAsyncの外で駆動する（runAsyncはネストできない）。
- **`CanvasArea`をテストへ直接載せるときは、Providerを6つ揃える**：
  `ProjectService`・`UndoManager`に加えて`SettingsService`・`ThemeService`・
  `BrushService`・`ToneService`・`StampService`・`PerformanceService`を
  `context.read/watch`する。1つでも欠けると
  `ProviderNotFoundException`でビルドに失敗する。`app_bootstrap.dart`の
  `buildAppProviders()`を使うのが早い（非同期なので`tester.runAsync`で呼ぶ）。
- **キャンバス左右端32pxは「画面端ダブルタップ（前/次フレーム）」専用ゾーン**：
  touch/stylusのポインターは、このゾーンだと`_onPointerDown`へ渡らず
  描画・選択が始まらない。ゾーンは**幅が32*3 = 96px未満のときだけ**無効化
  される（96ちょうどは有効）ので、幅96pxのキャンバスでは左右32pxずつ＝
  **幅の3分の2が描画不能**になる。実端末の全画面ではまず起きないが、
  PC/DeXでドッキングパネルを極端に狭くした場合と、テストで小さい
  `SizedBox`にCanvasAreaを載せた場合に踏む。テストではキャンバスを
  十分広く（例：エクスポート幅の3倍）取るか、`PointerDeviceKind.mouse`を
  使ってこの分岐を回避する。
- **`ListView(children: [...])`は「遅延している」ように見えて半分しか遅延
  していない**：`SliverChildListDelegate`はElementの生成（＝実際の
  レイアウト・描画・`Image`のデコード）は画面内ぶんだけに絞るが、
  **子のWidgetオブジェクト自体は毎回のbuildで全件作られる**。一覧が
  数十件を超える画面で`ListView(children: ...)`を使うと、1件チェックを
  付け外しするたびに全行のListTile・Checkbox・PopupMenuButton・
  CustomPaintを作って捨てることになる。行数が可変の一覧は
  `ListView.builder`にすること（セーブツリー一覧の2箇所をこれで直した）。
  なお、この違いは**Element数を数えるテストでは検出できない**（どちらも
  画面内ぶんしかmountしないため、`find.byType(ListTile)`の件数は同じに
  なる）。実際に「全件生成へ戻すと落ちるはずのテスト」を書いたつもりで
  両方通ってしまう事故を起こしたので、検証したい場合は
  `ListView.childrenDelegate`が`SliverChildBuilderDelegate`であることを
  直接assertすること（`test/save_tree_lazy_list_test.dart`が実例）。
- **ローカルファイルのサムネイルを`Image.file`で並べるときは
  `cacheWidth`を必ず指定する**：指定しないと保存されている解像度のまま
  デコードされて画像キャッシュに載る。セーブノードのサムネイルは長辺
  200pxで保存しているが、一覧での表示は40〜58px。`cacheWidth:
  (size * MediaQuery.devicePixelRatioOf(context)).round()`のように
  表示画素数へ落とすこと。
- **`flutter test`環境での既知の制約**：
  - `path_provider`はデフォルトで未登録。ディスクI/Oを伴うテストは
    `test/app_smoke_test.dart`の`mockPathProvider`ヘルパーを使うこと。
  - `file_picker`も未登録で、呼び出すと`tester.takeException()`を経由
    しない捕捉不能な例外になる。`FilePicker.platform`をフェイクへ
    差し替えて回避する既存パターンがある。
  - `GoRouter.push()`は前の画面をツリーに残したまま
    （`ModalRoute.isCurrent`はfalse）にする。全ツリーを無条件に操作対象に
    すると隠れた前画面の要素を誤ってタップする。`probeAllControls`／
    `visitRoutesAndPop`（`app_smoke_test.dart`）は`ModalRoute`の同一性で
    正しく絞り込む実装になっているので、新しい自律テストもこのヘルパーに
    乗せること。
- **実機（Android端末）が無い環境での限界**：この開発環境には物理Android
  端末が無く、`flutter test`と静的なコードレビューでしか検証できない。
  タップ位置・ジェスチャー・実際の描画速度・動画コンテナの再生互換性
  （AVI等）・新しいブラシの描き味・ランチャーアイコンの実機での見え方
  などは、コードレビューだけで「直った」と断定せず「直っている可能性が
  高いが実機要確認」と正直に報告すること。

- **`monetization_gate.dart`を一時的に書き換えたら必ず元に戻すこと**：
  過去に「test: キャンペーン条件を無効化し無料会員挙動でAPKテスト」
  （コミット54e4743）で`isMonetizationEnabled`の実装をコメントアウトして
  `=> true`固定にしたまま残り、**広告SDKとアプリ内課金が無条件で有効**な
  状態が長く続いていた（税務上の都合による一時停止という設計意図とも、
  CLAUDE.md・7言語のキャンペーン文言とも食い違う）。検証のために一時的に
  値を固定する場合は、戻し忘れないよう作業を分けること。

## 人間の実操作が必要な項目（ストア公開前に必ず確認・最重要）

以下はAIによるコード修正だけでは完結しない、ユーザー本人（事業者）が
実際に操作・判断しないと進まない項目。**使うサービス名・具体的な手順・
値を貼り戻す先（ファイル・行）まで書いてある**ので、上から順に進めれば
そのまま実行できるはず。より詳細な一覧・重複しない補足は
`docs/AI設計書/28_継続タスク（未着手一覧）.md`の同名セクションにもある。

1. **収益化タイマーが2027年1月1日で止まっている**（判断のみ、外部サービス
   不要）：`lib/config/monetization_gate.dart`の`kMonetizationEnabledFrom =
   DateTime(2027, 1, 1)`により、この日時に達するまで広告SDK（AdMob）・
   アプリ内課金（in_app_purchase）が一切初期化・接続されず、代わりに
   全ユーザーへプレミアム機能が無料開放される「リリース記念キャンペーン」
   状態になっている（税務上の都合、`PremiumService`・`AdvertisingService`
   のクラスコメント参照）。**本番公開のタイミングに合わせてこの日付を
   ユーザー自身が判断・変更**すること。恒久的に有効化する場合は、同ファイル
   のコメントの指示どおり`monetization_gate.dart`自体を削除し、参照箇所
   （`kMonetizationEnabledFrom`を条件式に使っている箇所。
   `grep -rn kMonetizationEnabledFrom lib/`で洗い出せる）も外す。

2. **Android署名鍵（keystore）を発行し、リリースビルドに設定する**：
   - 手順（ローカル端末のターミナルで実行。JDKに同梱の`keytool`コマンドを
     使う。Android Studioの「Build > Generate Signed Bundle / APK」の
     ウィザードでも同じことができる）：
     ```bash
     keytool -genkeypair -v -keystore niarim-release.keystore \
       -alias niarim -keyalg RSA -keysize 2048 -validity 10000
     ```
     対話式でパスワード（keystore用・key用）と証明書情報（氏名・組織等、
     適当でよい）を入力する。**生成された`.keystore`ファイルと2つの
     パスワードは絶対にこのリポジトリにコミットしない**（`.gitignore`で
     除外されるパスに置くか、リポジトリ外で保管する）。紛失すると同じ
     `applicationId`（`com.niarim.niarim`）でのアプリ更新が二度とできなく
     なるため、パスワードマネージャー等での安全な保管が必須。
   - リポジトリ側の反映：`android/`直下に`key.properties`を作る
     （`android/.gitignore`に`key.properties`・`**/*.keystore`・
     `**/*.jks`が既に入っているため、追加の除外設定は不要）。内容は
     ```properties
     storeFile=/absolute/path/to/niarim-release.keystore
     storePassword=<keystore用パスワード>
     keyAlias=niarim
     keyPassword=<key用パスワード>
     ```
     を書く。`android/app/build.gradle.kts`（現状`signingConfigs`ブロックが
     無く、33行目付近の`release { signingConfig =
     signingConfigs.getByName("debug") }`がTODOのまま）に、
     `key.properties`を読み込む`signingConfigs.create("release")`を追加し、
     `release`ブロックの`signingConfig`をそれに差し替える（標準的な
     FlutterプロジェクトのGradle Kotlin DSLでのkeystore設定パターンに
     従えばよい）。

3. **AdMob（Google公式の広告配信サービス、admob.google.com）で本番広告
   ユニットを発行する**：
   - AdMobコンソール（<https://admob.google.com>）にPlay Consoleと同じ
     Googleアカウントでログイン → 左メニュー「アプリ」→「アプリを追加」で
     Android／NIARIMを登録（Play Storeにまだ未公開の場合は「いいえ、
     追加しますか」の手動登録フローで進める）。
   - 登録後に発行される**App ID**（`ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`
     形式）を`android/app/src/main/AndroidManifest.xml`の
     `com.google.android.gms.ads.APPLICATION_ID`（現状Google公式テストID
     `ca-app-pub-3940256099942544~3347511713`）に上書きする。
   - 同アプリ配下で「広告ユニット」→「広告ユニットを追加」→
     「バナー」を選び、`lib/services/admob_provider.dart`の
     `_bannerAdUnitId`（Android向け、現状テストID
     `ca-app-pub-3940256099942544/6300978111`）に対応する**AndroidバナーID**
     を発行・差し替え。iOS向けにも別途アプリ登録・バナー広告ユニットを
     作成し、同ファイルの`_bannerAdUnitId`のiOS分岐（現状テストID
     `ca-app-pub-3940256099942544/2934735716`）を差し替える（iOS版を出す
     予定が無ければ後回しでよい）。
   - 正方形（`_squareAdUnitId`）用の広告ユニットも本番では専用に発行する
     ことが望ましい（同ファイルのコメント参照。現状はテスト用として
     バナーIDを流用している）。「メディエーション」「レクタングル」等の
     サイズ指定で追加できる。

4. **Google Play Console（play.google.com/console）でアプリ内課金の
   サブスクリプション商品を作成する**：
   - Play Consoleでアプリを開く → 左メニュー「収益化」→
     「アプリ内アイテム」→「サブスクリプション」→「サブスクリプションを
     作成」。
   - **商品IDは`lib/services/premium_service.dart`の
     `monthlyProductId`（`niarim_premium_monthly`）・`yearlyProductId`
     （`niarim_premium_yearly`）と文字列レベルで完全一致させる**
     （Play Console側は登録名を自由に付けられるが、商品ID欄はコード側の
     この2つの値をそのまま入力すること。一致しないと購入フローが商品を
     見つけられずテストもできない）。
   - 価格・課金周期（月次/年次）・利用規約リンク等を設定して「有効化」。
     Play Consoleの審査・公開ステータスによっては実機でのテスト購入に
     テイスター（ライセンステスター）登録が必要な場合がある
     （「設定」→「ライセンステスト」）。
   - 注意：サーバー側のレシート検証（Google Play Developer APIでの
     購入確認）は未実装で、クライアント側の購入イベントを直接信頼する
     設計（`PremiumService`のコメント参照）。不正購入対策を強化したい
     場合はサーバー検証の追加実装が別途必要（現状は未着手）。

5. **プライバシーポリシーの問い合わせ先を実際の連絡先に差し替える**：
   本アプリ専用の連絡先（無料Gmailアドレス等でよい）を用意し、
   `lib/l10n/app_ja.arb`をはじめとする7言語すべての`privacyPolicyArt8Body`
   キー（`lib/l10n/app_*.arb`、対象言語はja/en/es/fr/ko/zh/zh_Hant）を
   実際の連絡先を含む文言に更新した上で、`flutter gen-l10n`を実行して
   生成コードへ反映する（各言語の訳文はCLAUDE.mdの開発ワークフロー節の
   注意どおり機械的な一括置換を避け、言語ごとに文として自然になるよう
   手直しすること）。

6. **特定商取引法に基づく表示（日本向け有料課金を提供する場合に必須）**：
   事業者名・所在地・電話番号・問い合わせ先等の実データがユーザー側で
   確定してから、専用画面（例：設定画面から遷移する静的ページ）を追加する
   方針。実データが無いままプレースホルダーで実装すると、かえって不正確な
   法的表示を公開することになるため、**現時点ではコード側の対応を意図的に
   保留している**。実データが揃ったら、既存の利用規約・プライバシー
   ポリシー画面（`lib/screens/`配下の該当画面を参照）と同じ構成で新規画面を
   追加し、設定画面からの導線を張ること。

7. **Google Play Consoleのストア掲載情報を仕上げる**：
   Play Console「ストアの掲載情報」から、アプリ説明文・スクリーンショット
   （最新の画面デザインのもの）・フィーチャーグラフィック・
   最新アイコン素材（`assets/icon/app_icon.png`を元にした
   512×512のハイレゾアイコン）を登録する。このリポジトリの外側（Play
   Console画面上）の作業であり、現状未着手・未確認。「コンテンツの
   レーティング」「対象年齢」「データセーフティ」の各アンケートも
   公開前に必須。

8. **YouTube Data API v3のAPIキー、およびGoogleログイン用OAuthクライアント
   IDをGoogle Cloud Consoleで発行し、バックエンドのデプロイ時に渡す**：
   バックエンド（`backend/`）の統計更新バッチ（`videos.batchGetStats`）と
   ログイン認証（Google OAuthのIDトークン検証）が、それぞれ
   `YOUTUBE_API_KEY`・`GOOGLE_CLIENT_ID`という2つの値を必要とする
   （`backend/lib/niarim-backend-stack.ts`の129行目・165行目、
   CDKの`this.node.tryGetContext(...)`で読み込む設計。未設定だと
   `'REPLACE_ME'`のまま動いてしまう）。
   - Google Cloud Console（<https://console.cloud.google.com>）で
     プロジェクトを作成（または既存のものを流用）→「APIとサービス」→
     「ライブラリ」で「YouTube Data API v3」を有効化。
   - 「認証情報」→「認証情報を作成」→「APIキー」で**YouTube Data
     APIキー**を発行し、キーの設定で「YouTube Data API v3」のみに制限
     しておく（推奨）。
   - 同じく「認証情報を作成」→「OAuthクライアントID」で**Googleログイン用
     OAuthクライアントID**を発行（先に「OAuth同意画面」の設定が必要）。
   - デプロイ時にこの2値を`backend/`ディレクトリで
     ```bash
     npx cdk deploy \
       -c googleClientId=<発行したOAuthクライアントID> \
       -c youtubeApiKey=<発行したYouTube APIキー>
     ```
     のように`-c`オプションで渡す（`backend/README.md`の「デプロイ手順」
     に同じ内容がある。バックエンドのデプロイ手順全体・前提条件・
     `youtube.upload`スコープのGoogle審査についてはそちらを参照）。

9. **作品広場（コミュニティ機能）のフロントエンドは、バックエンドと
   一切繋がっていない**（上記8の後もこれ単独では解決しない、大規模な
   追加実装項目）：`lib/services/community_service.dart`は全データが
   ハードコードされたダミーデータで、`package:http`を使うコードは
   `lib/`全体で`font_service.dart`（フォントダウンロード）以外に存在しない。
   つまり`backend/`（AWS CDK+Lambda+DynamoDB、コードのみ）を実際にAWSへ
   デプロイしても、**Flutterアプリ側は自動的には繋がらない**。実際に
   多人数で使える作品広場にするには、認証（NIARIM User ID発行フロー）・
   作品CRUD・ランキング/検索・フォロー/ブロック/通報・ブックマーク/リポストの
   各APIを呼ぶHTTPクライアント層をFlutter側に新規実装し、
   `community_service.dart`のダミーデータをすべて実データ連携へ差し替える、
   という大規模な追加実装が丸ごと未着手のまま残っている（人間の判断という
   より純粋な追加開発work。ユーザー自身の操作が要るのは上記8のAPIキー
   発行部分のみ）。

## 現在の未完了事項（その他・概要）

詳細・経緯は`docs/AI設計書/28_継続タスク（未着手一覧）.md`とタスクボード
（Task#128・#134・#172〜#178等）を参照。要点のみ：

- **バックエンド（`backend/`、AWS CDK+Lambda+DynamoDB）はコードのみで
  未デプロイ**。この開発環境にAWSデプロイ用の認証情報が無いため、実際の
  デプロイ・動作確認は未実施。期間別ランキング・被ブックマーク一覧API・
  真のプッシュ通知(FCM)・通報レート制限の本格実装・User ID二重発行対策・
  CI/CD設定はコード未着手（`backend/README.md`の既知の制約も参照）。
  デプロイ後も上記の通りFlutter側のAPI連携実装が別途必要。
- **キャンバス・タイムラインの独自ジェスチャーの自律テスト化**が進行中
  （Task#128）。
- **利用規約・プライバシーポリシーの7言語見直しプロジェクト**が進行中
  （Task#134）。
- **実機でしか真偽を確認できない既知の懸念**：フレーム一覧のタップ・
  スワイプ吸着挙動、AVI書き出しの実機再生確認、PC/DeXレイアウトの
  実機での見え方、新しいマーカーペン（カリグラフィー特性）の描き味、
  R8有効ビルドでの実機起動確認（上記「繰り返し踏んだ地雷」参照）など。
