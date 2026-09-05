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
2. コード変更後は必ず`flutter analyze`（ベースライン：**0 issues**。
   info１件も出ていない状態が正なので、**1件でも増えたらそれは自分が
   足したもの**として必ず直すこと。`Color.red/green/blue`は非推奨なので、
   テストでピクセル値と突き合わせるときは
   `test/helpers/color_channels.dart`の`.red8`/`.green8`/`.blue8`/
   `.alpha8`を使う。テスト内のデバッグ出力は`print`ではなく
   `debugPrint`を使う）
3. `flutter test`（ベースライン：**691 tests**、全成功。うち大半は
   `test/app_smoke_test.dart`の自律スモークテスト。詳細は後述）
4. **コード変更後は`dart format lib test tool`をかける**。
   リポジトリ全体を一度フォーマッタに通してあるので（コミット
   `0319d57`）、整形済みの状態が正。手で字下げを合わせようとしないこと。
   なお整形すると`curly_braces_in_flow_control_structures`が出ることが
   ある（このlintは「if文が1行に収まっていれば波括弧を省略してよい」
   という例外を持ち、tall styleが長い1行ifを2行へ折ると例外から外れる）。
   出たら`dart fix --apply --code=curly_braces_in_flow_control_structures`
   で消す。
5. ARBファイル（`lib/l10n/app_*.arb`）を編集したら`flutter gen-l10n`を
   必ず実行し直す（対応7言語：ja/en/es/fr/ko/zh/zh_Hant、jaがテンプレート）。
   機械的な文字列置換だとES/FR等で訳が崩れることがあるため、ロケールごとに
   手で訳すこと。
6. コミットメッセージは日本語で、「ユーザーの依頼引用→調査で分かった原因→
   対応内容→検証結果（analyze/testの件数）」の構成にするのがこのリポジトリの
   慣行。ソースコード中のコメントには仕様書番号・Task番号は書かない
   （コードの技術的な説明のみ）が、`12_実装チェックリスト.md`への追記や
   コミットメッセージには経緯を書いてよい。
7. 大きめの作業が終わったら`docs/AI設計書/12_実装チェックリスト.md`へ
   追記し、必要ならこのファイルや`28_継続タスク（未着手一覧）.md`も更新する。

### 書式チェック（フォーマッターの設定に癖があるので注意）

リポジトリ全体を各種フォーマッターに通してある。**呼び出し方を間違えると
「整形されていない」と誤検知して、全ファイルを別の流儀へ書き換えてしまう**
ので、必ず次の指定で使うこと。

- Dart：`dart format lib test tool`
- Markdown・YAML・JSON・HTML：Prettier 3.8.1（設定ファイルは置いていない
  ので既定のまま）
- **ARB（`lib/l10n/*.arb`）：Prettierに`--parser json`を渡す**。
  拡張子から推論できず「No parser could be inferred」になる。
- **XML・plist：`@prettier/plugin-xml` 3.4.2**を`--plugin`で明示的に渡す。
- Python：Ruff（`ruff format` / `ruff check`）
- **Kotlin：ktfmt 0.64の`--kotlinlang-style`**。既定（Facebookスタイル）や
  `--google-style`を使うと既存ファイルが全部書き換わる。
- **C/C++：clang-formatの`--style=Google`**。既定のLLVMスタイルだと
  `windows/runner/`配下に差分が出る。

なお`dart fix --apply --code=curly_braces_in_flow_control_structures`と
`dart format`は、**入れ子のforに対しては互いに打ち消し合って収束しない**
（fixが波括弧を足す→formatが1行へ畳む→lintが再発）。入れ子forの外側は
手で波括弧を付けること。

### APKビルド（GitHub Actions）

- `.github/workflows/build-apk.yml`は**手動実行のみ**（`workflow_dispatch`）で、
  位置づけは**最終確認用**。細かな修正ごとに起動せず、対象テスト・
  `flutter analyze`・必要な実キャプチャを先に済ませ、一連の追加修正が
  すべて揃った最後に1回だけ起動すること。同一ブランチで多重起動すると
  `concurrency`（`cancel-in-progress: true`）で古い実行が打ち切られる。
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
  （HakkouMincho）にフォールバックする。
  **`XxxButton.styleFrom(textStyle:)`はさらに悪く、素の`TextStyle()`を
  渡すとそれがラベル書式を丸ごと決めてしまい、`ThemeData.fontFamily`すら
  継承されない**（＝端末標準のRobotoで描かれ、同梱フォントの周囲から
  明確に浮く）。`filledButtonTheme`が実際にこれで、
  `TextStyle(fontWeight: w700)`とだけ書かれていたためアプリ内の
  **全FilledButtonのラベル**が端末標準フォントになっていた。太さ等を
  変えたいときは`textTheme.labelLarge?.copyWith(...)`のように
  **textThemeを土台にして上書き**すること。
  `SnackBarThemeData.contentTextStyle`もまったく同じ罠で、素の
  `TextStyle(color: ...)`が入っていたため**アプリ中のSnackBarの文字が
  すべて端末標準フォント**だった（テーマ一覧の操作をPNGへ焼いて目視した
  ところ豆腐＝フォント未指定と分かり発覚）。
  `test/theme_button_font_test.dart`がボタン系4テーマ＋snackBarThemeを
  機械的に見張っている。`theme_service.dart`の
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
  ラッパー（`State.dispose()`まで破棄を遅延させる）を必ず使うこと。24箇所で
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
  （既存192箇所は対応済み）。
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
- **子から親へ「状態が変わった」を知らせるコールバックは、
  `didUpdateWidget`から呼ばれる経路が無いか確認すること**：
  `CanvasArea`は「全選択」「全解除」「選択範囲を反転」をトークン方式
  （親が`int`をインクリメント→子の`didUpdateWidget`で検知）で受け取る。
  この経路は**ビルド中に走る**ため、その中から
  `widget.onSelectionActiveChanged?.call(...)`のように親の`setState`を
  直接呼ぶと`setState() called during build`で例外になり、
  **通知そのものが親へ届かない**。実際に「全選択」を押しても
  全解除ボタンもモードボタンも出ない不具合になっていた
  （例外はコンソールに出るだけなので、テストが無いと気付けない）。
  `canvas_area.dart`の`_notifySelectionActive()`のように、
  `SchedulerBinding.instance.schedulerPhase`を見てビルド中なら
  `addPostFrameCallback`へ回すこと。テスト側も、この経路の反映には
  **pumpが2回**要る点に注意。
- **選択範囲の変形ハンドルは「画面px基準」で大きさを決め、位置の計算と
  当たり判定に同じ値を使うこと**：`canvas_area.dart`の
  `kSelectionHandleScreenRadius`（四隅の拡大縮小＝7px）と
  `kSelectionRotateHandleScreenRadius`（回転＝11px）は**画面px**での半径で、
  キャンバスpxへは描画エリアの拡大率（ピンチズームぶんを含む）で割り戻す。
  キャンバスpx基準にすると、高解像度プロジェクトではハンドルが極端に小さく、
  低解像度では巨大になる（指の大きさは画面基準なので掴みやすさも画面基準が
  正しい）。また、**位置の計算だけに下限を効かせて当たり判定には効かせない**
  ようなことをすると、小さいキャンバスで回転ハンドルと四隅のハンドルが
  当たり判定上重なり、角を掴んだのに回転してしまう。
  回転ハンドルは`kSelectionRotateHandleGap`ぶん角から離し、全選択のように
  選択範囲がキャンバス端まで届いている場合も**必ず選択範囲の外側**へ置く
  （横方向だけはウィジェットの外へ出ると指が届かないのでキャンバス幅の
  内側へ寄せる）。
- **キャンバスモードのバー（上部バー・太さ/不透明度スライダー・
  ツールバー・折りたたみハンドル）へ背景色を塗らないこと**：これらは
  「アイコンだけがキャンバスの上に浮かぶ」意匠だが、実装上はキャンバスの
  Stackの**外側**（`Column`の別の行）にいる。そのため`Colors.transparent`に
  しても透過した先はキャンバス外周ではなく**Scaffold本来の背景色**で、
  バーの帯だけが明るい別パネルのように浮いて見える。`canvas_screen.dart`の
  `Scaffold`へ`backgroundColor: kCanvasOutsideColor`を指定して**背後の側**を
  揃えてあるので、バー側は透明のままにすること（過去に2度、バー側へ色を
  塗る／塗り直しが剥がれる形で再発している）。
  `test/canvas_bar_transparency_test.dart`が両側を見張っている。
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
  描画・選択が始まらない。ゾーンは**幅が32\*3 = 96px未満のときだけ**無効化
  される（96ちょうどは有効）ので、幅96pxのキャンバスでは左右32pxずつ＝
  **幅の3分の2が描画不能**になる。実端末の全画面ではまず起きないが、
  PC/DeXでドッキングパネルを極端に狭くした場合と、テストで小さい
  `SizedBox`にCanvasAreaを載せた場合に踏む。テストではキャンバスを
  十分広く（例：エクスポート幅の3倍）取るか、`PointerDeviceKind.mouse`を
  使ってこの分岐を回避する。
- **`Tooltip`で包んだボタンに外側から`onLongPress`を足しても発火しない**：
  Materialの`Tooltip`は既定でタッチの長押しに反応する
  （`TooltipTriggerMode.longPress`）。`Tooltip`を含むボタンを
  `GestureDetector(onLongPress: ...)`で包むと、ジェスチャーアリーナで
  **内側のTooltipが勝つ**ため、外側の長押しは一度も呼ばれずツールチップ
  だけが出る。実際にこれで、キャンバスのツールバーの**長押しメニュー5つが
  全て無反応**になっていた（ペンのサブツール・バケツのベタ/トーン・
  指ツール・クイックツールパネル・選択ツールのメニュー）。
  `CanvasIconButton`に`longPressTooltip`を追加し、外側で長押しを扱う
  ボタンでは`TooltipTriggerMode.manual`にして長押しを譲っている。
  新しく長押しメニューを足すときは必ず`longPressTooltip: false`を付ける
  こと（falseでもマウスホバーのツールチップは出るのでPC/DeXでは困らない）。
  なお、この不具合はウィジェットテストでも再現する
  （`test/canvas_panel_screenshot_audit_test.dart`が実例）。
- **狭い画面のテストではツールバー・シートを必ずスクロールしてからタップ
  する**：キャンバスのツールバーは横スクロール、設定シートは縦スクロール
  なので、論理320px幅の端末ではボタンが表示領域の外に出る。座標が外だと
  タップはヒットテストに当たらず、例外も出ないまま「押したのに何も
  起きない」形の失敗になる。`tester.ensureVisible()`を挟むこと。
  併せて、キャンバスのオーバーレイパネルは画面左側へ縦いっぱいに開いて
  **ツールバーを覆う**ため、次のツールバー操作の前に閉じる必要がある。
- **`FirstUseTooltip`の吹き出しは画面全体の透明バリアを敷く**：吹き出しが
  出ている間はどこをタップしても閉じられるよう`Positioned.fill`の
  `GestureDetector`をOverlayへ置いている。そのため、吹き出しが出た直後の
  操作はバリアに吸われて何も起きない。ツールバーを操作するテストでは
  `SharedPreferences.setMockInitialValues({firstUseTooltipsSeenKey:
kAllFirstUseTooltipKeys})`で全キーを表示済みにしておくこと（一覧は
  `test/helpers/first_use_tooltips.dart`。lib配下の実際の`tooltipKey:`と
  一致していることを`test/first_use_tooltip_keys_test.dart`が見張っている
  ので、吹き出しを増やしたらこのファイルにも足す）。
- **`Table`のセルは既定（`top`）だと自分の中身ぶんの高さしか持たない**：
  1つのセルが2行に折り返すと行だけが高くなり、他の列の
  `Container(color: ...)`は**行の下端まで届かず背景に白い帯が残る**
  （プレミアム比較表で実際に発生）。`defaultVerticalAlignment:
TableCellVerticalAlignment.intrinsicHeight`を指定すること。
  `fill`は「**全セルがfillだと行の高さが0になる**」ため使わない。
- **スクリーンショットを撮るテストは`theme:`とフォント読み込みを必ず
  入れる**：`MaterialApp`に`theme:`を書き忘れるとFlutter既定
  （Roboto・M3既定配色）で描かれ、`flutter test`は既定でフォントを
  読み込まないためアイコンも文字も豆腐（□）になる。**本番と違う画面を
  撮って「問題なし」と判断する**事故になるので、
  `test/helpers/load_app_fonts.dart`の`loadAppFonts(tester)`を呼び、
  テーマは`context.watch<ThemeService>().themeData`を渡すこと。
- **`AlertDialog`の`icon:`スロットを「右上の×」置き場に使わない**：
  `icon`が非nullだと、Flutterは**タイトルを強制的に中央寄せ**にする
  （`dialog.dart`の
  `textAlign: icon == null ? TextAlign.start : TextAlign.center`）。
  ×だけのつもりで入れると、そのダイアログだけタイトルが中央寄せになり
  他と不揃いになる。×は`title: Row(children: [Expanded(child: ...),
IconButton(...)])`のようにタイトル行の右端へ置くこと。
  あわせて、閉じるボタンを取り除いた跡の**空の`actions: []`は必ず消す**
  （`AlertDialog`は空でもアクション領域ぶんの余白を描くため、下部に
  無駄な空白が出る）。どちらも`test/popup_close_affordance_test.dart`が
  ソースを走査して見張っている。
  **画像の上に重なる×**（プレミアム誘導バナー等）は、絵柄しだいで
  ほとんど見えなくなるため、`surface`/`onSurface`の組み合わせの下地を
  必ず敷くこと。
- **タップを観測したいだけの親を`GestureDetector`で作らない（アリーナに
  参加してしまう）**：`GestureDetector`のタップ認識はジェスチャーアリーナへ
  参加するため、タップを扱う相手とは必ずどちらか一方しか勝てない。
  アリーナは「ヒットテスト経路の内側から順に追加され、先に入った方が
  勝つ」ので、
  **子がタップを扱う場合は子が勝ち（＝親の`onTap`が一度も呼ばれない）**、
  **親がタップを扱う場合は自分が勝つ（＝親の機能が動かなくなる）**。
  `FirstUseTooltip`が実際にこれで、`GestureDetector(behavior: translucent,
onTap: ...)`だったために
  （1）lib配下8箇所の初回吹き出しが**一度も表示されていなかった**、
  （2）`TabBar`が各タブを自前の`InkWell`で包む＝親側なので、ペンサブ
  ツールパネルの**トーン・スタンプのタブがタップで切り替わらなかった**、
  という二通りの壊れ方を同時に起こしていた。子の邪魔をせずタップを
  観測したいときは、アリーナに参加しない`Listener`でポインターを見て、
  「移動量が`kTouchSlop`以内」「離すまでに`kLongPressTimeout`が経過して
  いない」で判定すること。なお**長押しの判定に
  `PointerEvent.timeStamp`を使ってはいけない**：ウィジェットテストでは
  常に0のまま（`TestGesture.up`の既定値）なので、テスト上は必ず
  「短いタップ」に見えて検証できない。`Timer`なら実機では実時間、
  テストではFakeAsyncの時計に従うので両方で正しく判定できる。
  検証は`test/first_use_tooltip_gesture_test.dart`。
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
- **`SliverMultiBoxAdaptorElement`の「見えている子」は描画範囲ぶんだけ**：
  `ListView.builder`はcacheExtent（既定250px）ぶん先の子も**生成・レイアウト
  する**が、`debugVisitOnstageChildren`が返すのは**実際に描画される範囲の
  子だけ**。つまりキャッシュ範囲にあるだけの行は、既定の`find.byKey`
  （`skipOffstage: true`）から**見つからない**。症状は「確かに作ったはずの
  Keyが`findsNothing`」で、原因が分かりにくい。テストでは一覧を十分広い
  ビューポートへ載せるか、`skipOffstage: false`で探して
  `scrollUntilVisible`で画面内へ持ってくること
  （`test/frame_strip_gesture_test.dart`が実例）。
- **`MultiProvider`自身のElementは、それが差し込むProviderより上にいる**：
  `tester.element(find.byType(MultiProvider)).read<T>()`は必ず
  `ProviderNotFoundException`で落ちる。`MaterialApp`と
  `AppLocalizations.of()`の関係（後者がnullになる）とまったく同じ罠で、
  **必ず子孫のcontext**（`find.byType(Scaffold)`や対象ウィジェット自身）
  から読むこと。
- **ポストフレームコールバックで始まるアニメーションは、pumpを1回
  挟んでも進まない**：`didUpdateWidget`→`addPostFrameCallback`→
  `animateTo`という定番の流れだと、次の`tester.pump(Duration)`は
  Tickerの**開始時刻を決めるだけ**で値が動かない（＝アニメーション前の
  値のまま止まって見える）。`pumpAndSettle()`を使うか、pumpを2回以上
  重ねること。
- **`tester.drag`はタッチスロップぶん短く動く／手動ジェスチャーは
  まったく動かない**：Scrollableの`DragStartBehavior.start`は「スロップを
  超えた地点」を起点に取り直すため、超えるまでの移動量はスクロールに
  効かない。`tester.drag(finder, offset)`は既定で`kDragSlopDefault`(20px)を
  内部で足して辻褄を合わせているので**実際に動くのは offset − 20px**。
  `startGesture`＋`moveBy`を自分で書く場合はスロップぶんが丸ごと捨てられ、
  **1回のmoveByだけだとスクロール量が0になる**。スロップ用と本番用の
  2回に分けること。
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

- **`ReorderableListView`の並び替えは、newIndexの意味がコールバックで
  違う**：非推奨の`onReorder`は「移動元をまだ取り除いていないリスト上の
  挿入位置」、後継の`onReorderItem`は「取り除いた後のリスト上の最終位置」を
  渡す。下方向へ動かしたときだけ1ずれる。
  このアプリの各サービスの並び替えメソッド（`reorderBrush`・`reorderLayer`・
  `reorderTone`・`reorderStamp`・`reorderEffectFilters`・
  `QuickToolService.reorder`・`ThemeService.reorder`・
  `reorderCustomSizePresets`）は**全て前者（取り除く前）の規約**で書かれて
  いて、内部に`if (newIndex > oldIndex) newIndex--;`を持っている。
  しかもドラッグ以外の呼び出し元がある（`AutofillBatchRunner`は自動塗り
  レイヤーを線画の上へ、`FilterPanel`は縁取りレイヤーを、どちらも
  `indexWhere(...) + 1`という「取り除く前」の位置を自分で計算して
  `reorderLayer`を呼ぶ。`reorderBrush`と`QuickToolService.reorder`は
  テストからも呼ばれる）。**サービス側の`-1`を消すとこれらが黙って壊れる**。
  UI側は`lib/utils/reorder_index.dart`の`preRemovalIndex(old, new)`で
  `onReorderItem`の添字を元の規約へ戻してからサービスへ渡す形に統一して
  あるので、新しく`ReorderableListView`を足すときもこの形に乗せること
  （`onReorder`は使わない）。正しさは`test/reorder_index_test.dart`が
  総当たりで検証している。

- **`http.Response.body`を使わないこと（日本語が化ける・例外になる）**：
  `body`はContent-Typeの`charset`を見て復号し、**charsetの指定が無ければ
  RFC通りlatin1へ倒す**。バックエンドは`charset=utf-8`を付けているが、
  途中のプロキシやエラーページはその限りではなく、日本語のエラー文が
  返ると文字化けするか「Contains invalid characters」で例外になる
  （実際に踏んだ）。JSONはRFC 8259でUTF-8と決まっているので、
  `utf8.decode(response.bodyBytes, allowMalformed: true)`で読むこと
  （`niarim_api_client.dart`の`_decode`が実例）。
  なお**テスト側の`http.Response('日本語...', 400)`も同じ理由で落ちる**
  （こちらはエンコード時）。MockClientの応答には必ず
  `headers: {'content-type': 'application/json; charset=utf-8'}`を付ける。
- **通信の再試行はGETだけにすること**：POST/PATCH/PUT/DELETEは、サーバーへ
  届いたあとで応答が失われた場合に二重投稿・二重通報を起こしうる。
  投稿APIはworkId=youtubeVideoIdの冪等キーで守られているが、通報のように
  冪等でないものもあるため、層としては一律で投げ直さない方針にしてある
  （`_sendWithRetry`の`retries`引数）。GETでも4xxは投げ直さない
  （何度やっても同じため）。
- **ダイアログ・ボトムシートは「開いた状態」を撮って目視すること**：
  ルート単位のスクショ監査は1ルート1状態しか撮らないため、
  `showDialog`／`showModalBottomSheet`／`showMenu`（lib配下に204箇所）で
  開く画面はほぼ検証されない。`test/dialog_screenshot_audit_test.dart`が
  26ルートを巡回してモーダルを1枚ずつ`build/dialog-screenshots/`へ焼く
  （中身はタップせず必ずpopで閉じるので、確認ダイアログでデータは壊れない）。
  **テストが緑でも見た目の不具合は残る**：この監査で
  「ジェスチャー選択シートが77pxオーバーフローして下の選択肢を選べない」
  「FilledButtonのラベルが端末標準フォント」の2件が実際に見つかった。
  なお`showModalBottomSheet`は既定で画面高の9/16（360x760で約427dp）までしか
  取らない。**件数が可変の一覧を出すシートは必ず
  `lib/widgets/scrollable_sheet_body.dart`の`ScrollableSheetBody`で包むこと**
  （SafeArea＋SingleChildScrollView）。包み忘れると下の項目が縞模様で潰れて
  選べなくなる。クイックツールの「追加」がブラシ15件で**654px**
  オーバーフローし、登録できるブラシが数件に限られていた。
  `test/bottom_sheet_scrollable_test.dart`がソースを走査して再発を防ぐ。
  「今は入りきる」は保証にならない（組み込みブラシは実際に後から増えた）。
- **アプリ内の文言に絵文字を混ぜない（アイコンで表す）**：意味を表す記号は
  すべてMaterialアイコン（`Icon(Icons.xxx)`）を使う。絵文字は端末・OS
  バージョン・フォント設定で字形も色も変わり、同梱フォント
  （Kuramubon・HakkouMincho・Notoサブセット）にも入っていないため、
  周囲の文字から明らかに浮く。過去に素材一覧の「⚠ 不足」とヘルプ本文の
  「更新マーク（❗）」が混ざっていて、前者は`Icons.warning_amber_rounded`
  へ、後者は記号を落として文章だけにした。`test/no_emoji_in_ui_test.dart`が
  7言語のARBを走査して再発を防いでいる（ソースコードのコメント中の
  「→」等は画面に出ないので対象外）。
- **`RemoteViews`ではグラデーション背景も同梱フォントも使えない**：
  ホーム画面ウィジェットの「作品をつくる」「作品広場」は、起動画面の
  2つの導線ボタンと同じ意匠（角丸＋2色グラデーション＋影＋Materialアイコン
  ＋見出しフォントKuramubon）にしてあるが、これは**アプリ側が1枚のPNGへ
  焼いて渡している**（`lib/services/shortcut_widget_renderer.dart`）。
  `RemoteViews.setInt(..., "setBackgroundColor", ...)`は単色しか受け付けず、
  `GradientDrawable`はリソースに静的に書いた色しか使えず、`setTypeface`は
  assetのフォントを読めないため、ネイティブ側だけでは再現できない。
  ネイティブ（`widget_shortcut.xml`）は受け取った画像を`fitCenter`で出す
  だけで、画像が無いときだけアイコン＋ラベルの簡易表示へ倒す。
  意匠は**正方形・横長・縦長の3通り**を焼いてあり、Kotlin側の
  `imageKeyFor()`が`getAppWidgetOptions()`から読んだマスの縦横比で
  選ぶ（横長だけアイコンと文字が横並び）。**`onUpdate`はリサイズでは
  呼ばれない**ので、`onAppWidgetOptionsChanged`を実装しないと横長へ
  広げても正方形の画像が中央に残ったままになる。判定のしきい値はDart側の
  `shortcutWidgetShapeFor()`と二重管理になるが、
  `test/home_widget_cell_size_test.dart`がKotlinのソースから実際に値を
  読んで一致を検証しているので、片方だけ変えると落ちる。
  **起動画面のボタンのデザインを変えたら、レンダラー側の定数
  （`ShortcutWidgetDesign`）も必ず一緒に変えること**。一致は
  `test/home_widget_shortcut_design_test.dart`が、本物の起動画面を
  レンダリングした画素と焼いたPNGの画素を突き合わせて守っている。
  なお文言もこの画像に焼き込まれるため、Androidの文字列リソースではなく
  **アプリ内の表示言語設定に追従する**（`app.dart`の`_syncHomeWidgets`が
  テーマ色と言語の両方をキーにして焼き直す）。
- **テーマの文字色と背景色を同じ色にすると詰む（対策済み・壊さないこと）**：
  テーマ・外観設定は文字色も背景色も自由に選べるため、同じ色にすると
  設定画面の文字まで読めなくなり自力で戻せなくなる。対策は2段構え：
  1. テーマ・外観設定がその組み合わせを保存しない
     （`theme_settings_screen.dart`。判定は`lib/utils/color_contrast.dart`）
  2. それでも読めないテーマになった場合（引き継ぎファイルの取り込み等）
     に備え、起動画面の右上へ**テーマ色を一切使わない固定色**の
     リセットボタンを条件付きで出す（`splash_screen.dart`の
     `_ThemeRescueButton`）
     しきい値`kMinReadableContrast`は**1.4**。組み込み28プリセットの最小値が
     約1.75（水色のアクセント色に白抜き文字）なので、WCAGのAA基準
     （4.5／大きい文字3.0）を使うと**既定テーマ自体が弾かれる**。
     組み込みテーマが全て通ることは`test/theme_contrast_rescue_test.dart`が
     検証しているので、しきい値を上げるときは必ずこのテストを見ること。
- **ホーム画面ウィジェットのPendingIntentは`requestCode`を必ず変えること**：
  `NiarimWidgetProviders.kt`の3種のウィジェット（作品／作品をつくる／
  作品広場）は同じ`MainActivity`を起動するIntentを使うため、
  `PendingIntent.getActivity()`の`requestCode`が同じだと**後から作った
  Intentのextraで既存のPendingIntentが上書きされ、3つとも同じ画面へ飛ぶ**
  （AndroidはIntentのextraをPendingIntentの同一性判定に含めない）。
  ルートごとに異なる`requestCode`を渡し、あわせて`niarim://widget<route>`の
  data URIも設定してある。ウィジェットを増やす際は必ず両方を新しい値にすること。
  なお`RemoteViews`は動画再生もWebViewもできない（ImageView/TextView等の
  限られた部品のみ）ので、ウィジェットへ出せるのは静止画だけ。
  タップ後の遷移は`go()`ではなく`push()`（上記のgo/push地雷と同じ理由）。
  ただし作品ウィジェットの行き先は起動画面（`'/'`）＝Routerの初期位置な
  ので、冷たい起動ではそのままpushすると**起動画面が二重に積まれる**。
  `lib/app.dart`側で「今いる場所と同じルートなら何もしない」ガードを
  入れてあるので、新しい行き先を足すときもこの判定を通すこと。
  設定は**アプリ内の設定画面**（`/settings/widget`）に置いている。
  Androidの設定用Activity（`android:configure`）は配置時に一度開くだけで
  **後から設定を変え直せず**、しかも終了時に`RESULT_OK`＋
  `EXTRA_APPWIDGET_ID`を返し損ねると**ウィジェットの配置自体が
  キャンセルされて何も出ない**ため採っていない。
- **`monetization_gate.dart`を一時的に書き換えたら必ず元に戻すこと**：
  過去に「test: キャンペーン条件を無効化し無料会員挙動でAPKテスト」
  （コミット54e4743）で`isMonetizationEnabled`の実装をコメントアウトして
  `=> true`固定にしたまま残り、**広告SDKとアプリ内課金が無条件で有効**な
  状態が長く続いていた（税務上の都合による一時停止という設計意図とも、
  CLAUDE.md・7言語のキャンペーン文言とも食い違う）。検証のために一時的に
  値を固定する場合は、戻し忘れないよう作業を分けること。

- **一連の操作でしか現れない画面は、操作ウォークスルーのPNGで確認する**：
  ルート単位・ダイアログ単位のスクショ監査は1画面1状態しか撮らないため、
  「ツールを切り替えて→範囲を囲んで→モードを選んで→ドラッグする」のような
  途中経過は一切検証されない。`test/selection_tool_walkthrough_test.dart`・
  `test/theme_settings_walkthrough_test.dart`が本番画面を実タップ・実ドラッグで
  通して各段階を`build/selection-walkthrough/`・`build/theme-walkthrough/`へ
  焼くので、同種の機能を足したらこの形で1本足すこと。実際にこの監査で
  「SnackBarの文字だけ端末標準フォント」を見つけている。
  手順そのものは`docs/AI設計書/30_AI自律動作確認プロンプト.md`に、
  他のモデルへそのまま渡せる形でまとめてある。
  なお**ドラッグ位置はウィジェットの割合ではなくプロジェクトのピクセル座標**
  で指定すること（描画エリアはCanvasAreaの中央へアスペクト比フィットで
  置かれるため割合指定だとずれる）。加えて**選択ツールへ入るとツールバーと
  フレーム一覧が畳まれてキャンバスの矩形が変わる**ので、座標の基準は
  操作のたびに取り直すこと（キャッシュすると畳まれた後にずれる）。
  ストロークの実画素化も本物の非同期処理なので、1点動かすごとに
  `tester.runAsync`で実時間を進めないと最初の点しか描かれない。

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
     `properties
     storeFile=/absolute/path/to/niarim-release.keystore
     storePassword=<keystore用パスワード>
     keyAlias=niarim
     keyPassword=<key用パスワード>
     `
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

9. **作品広場のAPIクライアント層は実装済み。残るのはGoogleログインと
   デプロイ**：`lib/services/api/`にバックエンドの**21エンドポイント全て**を
   型付きで呼ぶ層がある（`community_api.dart`＋HTTP下請けの
   `niarim_api_client.dart`＋DTOの`niarim_api_models.dart`）。接続先は
   ビルド時の`--dart-define=NIARIM_API_BASE_URL=https://...`で渡し、
   未指定なら`CommunityService`は従来どおりダミーデータで動く
   （デプロイ前でも画面確認・スクリーンショット・テストが一通りできる
   状態を保つため）。読み取り系（新着一覧・ランキング）は
   `CommunityService.refreshFromBackend()`・`fetchRanking()`で配線済み。
   **残っているのは次の2つ**：
   - **Googleログイン（NIARIM User ID発行フロー）が未実装**。書き込み系
     （投稿・ブックマーク・フォロー・通報・ブロック）はIDトークンが要る。
     クライアント側は`NiarimAuthTokenProvider`（`Future<String?>`を返す
     関数）を受け取る形で口を開けてあるので、ログイン基盤ができたら
     `NiarimApiConfig.createApi(tokenProvider: ...)`へ渡し、
     `CommunityService`のトグル系メソッドをAPI呼び出し＋楽観更新へ
     差し替える。これはユーザー操作ではなく純粋な追加開発work。
   - 上記8のAPIキー発行と、`backend/`の実デプロイ（Task#175）。
10. **規約・法令コンプライアンス監査（2026年9月実施）で見つかった、
    人間の判断・ストア管理画面操作が必要な項目**（コード側で対応できる
    部分は既に対応済み。詳細は`12_実装チェックリスト.md`の「アプリ全体の
    規約・法令コンプライアンス監査」節参照）：
    - **Google Playコンソールの「対象年齢」宣言**を、今回追加した利用規約
      第2条3項（未成年者は保護者等の同意を得て利用）・実際の想定
      ユーザー層と矛盾しない内容にしておくこと。あわせて
      `advertising_service.dart`の`tagForUnderAgeOfConsent: false`
      （AdMob UMP同意フローでの年齢申告、一般向けアプリとしては妥当な
      既定値）とも整合させること。
    - **YouTube API利用時の必須ブランディング要件**（YouTubeロゴの
      表示・YouTube利用規約へのリンク等）を、上記9の作品広場バックエンド
      接続作業に着手する際に満たすこと。
    - **UGCモデレーションの実運用**（通報を受けて実際にレビュー・
      対応する体制）と**アカウント/データ削除手段**（Google Playポリシーが
      要求する、アプリ内アカウント削除とWeb上のデータ削除申請窓口）も、
      同じく作品広場のバックエンド接続後に必要になる。

## 現在の未完了事項（その他・概要）

詳細・経緯は`docs/AI設計書/28_継続タスク（未着手一覧）.md`とタスクボード
（Task#128・#134・#175）を参照。要点のみ：

- **バックエンド（`backend/`、AWS CDK+Lambda+DynamoDB）はコード実装が
  完了しており、未デプロイのまま残っている**。この開発環境にAWSデプロイ
  用の認証情報が無いため、実際のデプロイ・動作確認だけが未実施（唯一
  残っているバックエンド側タスク）。期間別ランキング・被ブックマーク
  一覧API・真のプッシュ通知(FCM)・通報レート制限の本格実装・User ID
  二重発行対策・CI/CD設定は**いずれもコード実装済み**（かつてはここに
  「未着手」と書かれていたが、実際にはすべて完了している。詳細・経緯は
  `12_実装チェックリスト.md`、`28_継続タスク（未着手一覧）.md`の
  「未着手：バックエンド関連」節を参照）。デプロイ後も上記9の通り
  Flutter側のAPI連携実装が別途必要。
- **キャンバス・タイムラインの独自ジェスチャーの自律テスト化**が進行中
  （Task#128）。
- **利用規約・プライバシーポリシーの7言語見直しプロジェクト**が進行中
  （Task#134）。
- **実機でしか真偽を確認できない既知の懸念**：フレーム一覧のタップ・
  スワイプ吸着挙動、AVI書き出しの実機再生確認、PC/DeXレイアウトの
  実機での見え方、新しいマーカーペン（カリグラフィー特性）の描き味、
  R8有効ビルドでの実機起動確認（上記「繰り返し踏んだ地雷」参照）など。
