# CLAUDE.md

このファイルは、次にこのリポジトリで作業するAIセッション（Claude Code等）が
最初に読む前提で書かれている。プロジェクトの基礎知識は`docs/AI設計書/`配下の
番号付き仕様書（特に`00_AIへの指示.md`・`01_プロジェクト概要.md`）にあるため、
先にそちらを読むこと。このファイルは、それらの仕様書には書かれていない
「実際に開発する中で踏んだ地雷・気をつけるべき癖・現在の未完了事項」を
まとめた実践的な引き継ぎメモであり、内容が古くなったら都度このファイル自体を
更新すること（他のドキュメントと同様、削除・書き換えを恐れず現状に合わせる）。

**作業の進め方そのもの**（環境構築・検証手順・レビューの通し方・コードの地図）は
`docs/AI設計書/31_引き継ぎガイド（AI開発者向け）.md`にまとめてある。
このリポジトリを初めて触るなら、まずそちらを読むこと。実操作＋スクショによる
自律動作確認の手順は`docs/AI設計書/30_AI自律動作確認プロンプト.md`。

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
3. `flutter test`（ベースライン：2026-10-10時点で**成功1878・スキップ5・
   失敗4**。失敗は監査担当の`test/app_web_reference_*`3件と、別セッション
   （質感変更フィルターの名前変更）の`test/texture_filter_gold_palette_test.dart`
   1件で、通常タスクでは直さない。全件で約25分かかるので、変更に関係する
   テストを先に流し、最後に全件を流す）
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
  選択範囲がキャンバス端まで届いている場合も**必ず選択範囲の外側**へ置く。
  **寄せる基準は「キャンバスの端」ではなく「CanvasAreaウィジェットの端」**
  （`reachableCanvasRectFor`）にすること。描画エリアはアスペクト比フィットで
  置かれるので外側にレターボックス／ピラーボックスの余白があり、そこは
  キャンバス外でもタップが届く。キャンバス基準で寄せると、余白があるのに
  ハンドルが選択範囲へ食い込む。逆に**寄せる際に確保する余白は四隅の半径
  ではなく回転ハンドル自身の半径**で測ること（四隅の方が小さいので、
  四隅ぶんで測ると差分だけ円が画面外で欠ける。実際に欠けていた）。
- **縁取りペン（`outlineEnabled`）の筆圧・入り抜きは「全体の形」だけを変える**：
  ユーザー指定の仕様で、プリセットに限らず縁取りオプション全体に適用される。
  筆圧・入り抜きは縁取りを含む断面全体（外径＝倍率×（太さ/2＋縁取り幅））を
  縮め、**縁取り線の太さは一定**、**透明度は一切変えない**（抜き0%の所は
  何も描かない）。断面より縁取りが太くなる先端だけは塗りが無くなり、縁取り色の
  尖った先端になる。この断面は`brush_render_plan.dart`の
  `outlinedStrokeRadii()`ただ1か所で決めていて、通常のスタンプ描画と
  折り畳みモード（`HairFoldRaster`）の両方がこれを使う。片方だけ別の式に
  すると、折り畳みON/OFFで先端の形が食い違う（ONとOFFが同じ見た目に
  なることは`test/engine/hair_fold_line_alignment_test.dart`が見張っている）。
  `HairRibbonPoint`は「倍率適用後の幅」と「倍率」を持ち、塗り半径・外径は
  **画素ごとに補間した幅と倍率から求める**（どちらも線形なので、入力点が
  まばらでも正確）。点ごとに塗り幅・縁取り幅を計算してから補間すると、
  抜きの最後の長い区間で縁取りが細り、ONだけ終点が薄く見えた（レビューで
  実測）。`width`を塗り幅に変えると横方向反復の間隔や折り返し線の長さまで
  縮むので、`width`の意味は変えないこと。
  縁取りオプションの「重なりを維持する」（`outlineKeepOverlap`、既定オン＝
  後から描いた線の縁取りが前の線の上にも描かれる）をオフにすると、
  縁取りと**折り返し線**は**そのストローク開始前のレイヤーの絵の下へ回る**
  （スタンプ描画はタイルごとに開始前の不透明度を保持、`HairFoldRaster`は
  `_before`の画素を見る）。塗りは上に描くので、重なった所の古い縁取りは
  塗りで消え、全体の周りだけが縁取られる。折り返し線だけ上に残すと、
  髪を何度も重ね描きしたとき縁取りの消えた塊の中に折り返し線だけが無数に
  浮く（ユーザー指摘）。1本のストローク内の重なり（折り畳み）には影響しない。
  **下へ回して隠れた分の扱いは2通りある**：シルエットの外周（塗りの外側）
  が隠れた所は前の絵を見せるが、折り返し線や区間の縁のように**自分の塗りの
  上**にある線が隠れた所は**自分の塗り色**で埋めること。両方とも被覆から
  差し引くと、白い髪の上で折れの内側が削れて下の白が見える（ユーザー指摘、
  `test/engine/outline_keep_overlap_test.dart`の`holesInZigzag`が見張る）。
  縁取りを入り抜きに合わせて比例で細くすると先端が灰色の細線になり
  「終点だけ色が薄い」と言われる。一定のまま外側を残すと先端に丸い点が残る。
  どちらも実際に踏んだ。
- **カスタムの入り抜きは直線ではなく`_taperShoulder`の曲線**
  （`drawing_engine.dart`、`p + p²(1 − p)`）：直線だと抜きの始まる所で
  輪郭が角を作った（髪の毛プリセットの抜き80pxで目視）。先端の傾きは直線と
  同じ（同じだけ尖る）で、全幅とは水平につながる。折り畳みの描画
  （`HairFoldRaster`）は点の間の太さを直線で補間するので、`_rebuildHairFold`は
  入り抜きの範囲の長い区間（速いはらい）に2pxごとの点を足してから渡す
  （足さないと折り畳みON/OFFで先端の形が食い違う）。
- **縁取りの「強弱」（`outlineAccentEnabled`）はストローク全体の形で決まる**：
  カーブごとに「曲がり始め（全体の曲がりの5%）・頂点（50%）・曲がり終わり
  （95%）」を求め、縁取り幅→「頂点の縁取り幅」へsmoothstepで太くする
  （`lib/engine/outline_accent.dart`）。カーブの終わりは描き終えるまで
  分からないので、通常の描画では**ペンを離した後の描き直し**
  （`needsFinalFadeReplay`、カスタムの入り抜きと同じ仕組み）で反映する。
  折り畳みモードは毎回全体を描き直すので、描いている途中も描いた所までの
  カーブで太らせる。`HairRibbonPoint.outline`が点ごとの縁取り幅で、
  `HairFoldRaster`の「一直線に並んだ点を1区間にまとめる」処理は縁取り幅も
  同じときだけまとめること（まとめると区間の端から端まで縁取り幅が直線で
  補間され、角の太りが辺全体に広がった。実際に踏んだ）。
- **折り返し線は手前側の内側縁取り線の「延長」として1本に見せる**：
  手前側の縁取りは、奥側の上では折り返し線の始点まで隠す
  （`_composite`の`hidden`）。折れ点からの固定半径で隠していた頃は、
  鋭い折れで縁取りの直線が始点の先まで残り、カーブする折り返し線と
  二股（「線が2本あって枝分かれ」）に見えた。
- **折り畳み線の始点は「内側の縁取り線どうしが交わる点」を幾何で求める**：
  `_foldLineStart`は、手前側の区間の内側縁取り線（各サンプル自身の幅で
  オフセット）を折り目から外へたどり、奥側の区間の内側縁取り線を越える点を
  探す。頂点サンプルからの二等分線で出す式は、角が入力サンプル上に
  無い場合・手描きの丸い角・筆圧で左右の幅が違う場合に2〜6pxずれた
  （レビューで実測）。「最も鋭いサンプルへ頂点を寄せる」方式は手ぶれに
  引っ張られて頂点が最大25px動いたので撤回した。
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
  **逆に、中身を変えたのに同じインスタンスのまま渡すと一度も再描画されない**。
  投げ縄の`_lassoPoints.add(...)`がこれで、ドラッグ中の投げ縄の線が
  キャンバスに出ていなかった（`test/lasso_snap_canvas_test.dart`が、
  ドラッグ途中の画面に線が描かれていることを見張る）。中身が変わったら
  新しいリストを代入すること。
- **キャンバスの外からレイヤーの画素を丸ごと書き換えるときは
  `ProjectService.replaceLayerPixels`を使うこと**：描画フィルターの適用・
  自動操作の手順など、`CanvasArea`の外で`TileManager.replaceLayerPixels`を
  直接呼ぶと、（1）Undoに何も積まれず元に戻せない、（2）`CanvasArea`は
  自分の操作以外では現在レイヤーを合成し直さないため、**画面には古い絵が
  出たまま**になる、の2つが同時に起きる（実際に、フィルターを「適用」しても
  キャンバスが変わらず、取り消しもできなかった）。`ProjectService.
  replaceLayerPixels`はタイル差分のUndo（プリズムの合成モード変更も含めて
  1手）を積み、`TileManager.addLayerContentListener`経由で`CanvasArea`が
  そのレイヤーを描き直す。自動操作のようにレイヤーを作ってから加工する
  一連の処理は`runWithGroupedUndo`の中で行うこと（その中で作ったレイヤーの
  画素は個別に記録せず、レイヤー追加のUndo/Redoが最終状態ごと戻す。部分的な
  タイル差分を再生すると、途中の結合結果を古いタイルで上書きしてしまう）。
  検証は`test/layer_pixels_replace_test.dart`。
- **レイヤーの画素は「乗算済み（premultiplied）」RGBAである**：タイルは
  `toByteData(format: ImageByteFormat.rawRgba)`（乗算済み）で読み、
  `ImageDescriptor.raw`（乗算済みとして解釈）で描くため、描画フィルター等が
  受け取る`Uint8List`のRGBは**既に不透明度が掛かっている**（不透明度50%の
  黄色は`[128, 128, 0, 128]`）。不透明度を変える処理（ドット絵の縁を
  不透明にする等）でRGBをそのまま書き戻すと、縁だけ暗い色になり、
  パレットへ寄せると別の色（黄色の縁が赤）になる（ドット絵で実際に踏んだ）。
  色を判定するときは`RGB×255÷α`で戻し、書き戻すときは新しいαを掛けること
  （`pixel_art_engine.dart`が実例）。テストの入力画素も乗算済みで作ること。
  色を変える処理は`lib/engine/premultiplied.dart`の`onStraightColour`
  （戻す→処理→掛け直す）か`applyStraightChannelLuts`を通し、輪郭強調の
  ように画素をまたぐ処理は最後に`clampChannelsToAlpha`で抑えること。
  トーンカーブ・レベル補正・ノイズ・2値化・アニメ調など9種がこの誤りで
  透明部分に色を出し（反転で透明部分が白くなる等）、縁を光らせていた。
  `test/engine/filter_premultiplied_validity_test.dart`が全描画フィルターの
  出力を「どのチャンネルもα以下」で見張っている。
- **合成画像（`LayerCompositor.composite`）には背景が入っていない**：
  レイヤーだけを重ねた透明な画像なので、プレビュー・サムネイルにそのまま
  出すと、透明な所に**パネルの色**が透けて見え、キャンバスと見え方が
  食い違う（フレーム一覧がテーマ色、タイムラインのプレビューがテーマの
  文字色になっていて、黒やベージュの背景が反映されていなかった）。
  背景を描き込むのはキャンバス（`_paintBackground`）と書き出し
  （`ExportEngine.renderFrame`）だけ。プレビューを新しく作るときは
  `lib/widgets/frame_preview_background.dart`の`FramePreviewBackground`で
  **プロジェクトごとの背景色**（`Project.backgroundColor`、作成時・編集時に
  選ぶもの）を絵の矩形の後ろへ敷くこと（透明なら市松模様）。画像へ
  焼き込むと背景色の変更で作り直しが要るが、ウィジェットで敷けば
  ProjectServiceの通知だけで即座に追従する。
  **ただし合成モードは用紙（背景色）にも効く**：加算（発光）・スクリーン等の
  レイヤーは用紙を明るくする（プリズムの光が暗い色のまま見えていた）。
  `composite(paperColor:)`へ不透明な背景色を渡すと用紙を一番下に敷いてから
  合成する。キャンバス（背景表示中）と書き出しは常に渡し、プレビューは
  `LayerCompositor.paperForBlendModes(layers, 背景色)`（通常以外の合成モードの
  レイヤーがあるときだけ背景色、無ければnull＝従来どおりウィジェットで敷く）
  を渡して、背景色が変わったら作り直すこと。
  キャンバスは現在レイヤーより**上のレイヤーを`compositeToPicture`の
  Picture**で描く（画像にすると下の絵と合成されず、乗算レイヤーが
  下を暗くしなかった）。GPUに無い合成モード（減算・リニアライト等）は
  ライブ表示では`displayBlendMode`の近似、確定後は`blendOnto`の正確な
  CPU合成に差し替える（`test/canvas_blend_mode_display_test.dart`）。
- **アイコンの縁取りに`Icon`を8個重ねない**：`CanvasIconButton`は
  `Icon.shadows`（ぼかし半径0のShadow×8）で1ウィジェットにしてある。
  `Positioned`で重ねる方式に戻すと、1ボタン9ウィジェット×常時20個前後＝
  ツールバーだけで180個のRenderObjectになる。テスト側でも`find.byIcon`が
  1ボタンにつき9件ヒットして`findsOneWidget`が使えなくなる。
  同様に、`CustomPainter`で同じ字形を何度も描くときは`TextPainter`を
  1回だけ`layout()`して使い回すこと（`layout()`はテキストシェーピングを
  伴う重い処理。縁取りなら、1回`layout()`した`TextPainter`をオフセットだけ
  変えて8回`paint()`する）。
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
- **`CanvasArea`をテストへ直接載せるときは、Providerを8つ揃える**：
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
- **スクロールする領域の中で「点をつかんでドラッグする」部品は、つかんだら
  アリーナを取ること**：`GestureDetector`の`onPan*`は**タッチスロップの2倍**
  動くまで勝たないが、縦スクロールは**スロップ1倍**で勝つため、点を上下に
  ドラッグすると周りのパネルがスクロールして点は動かない（フィルターパネルの
  トーンカーブで実際に起きていた）。`Listener`で点を動かす作りは
  アリーナに参加しないので、**点が動きながらパネルもスクロールする**
  （自動線画の制御点で実際に起きていた）。どちらも
  `lib/widgets/grab_pan_gesture_recognizer.dart`の`GrabPanGestureRecognizer`
  （`grabs`が真の位置で押されたら、少し動いた時点＝または押した時点で
  勝つ）で直してある。新しく同種の部品を足すときもこれを使い、
  `test/filter_edit_undo_group_test.dart`のように「スクロール位置が
  変わらないこと」まで確かめること（既に最大までスクロールしていると
  上向きのドラッグでは差が出ないので、戻る向きに動かす）。
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
- **ポップアップ・トーストの下地は必ず不透明にする**：テーマの色は
  カラーピッカーで透明度まで選べるため、メニュー背景色をそのまま
  ダイアログ等の下地に使うと後ろの画面が透ける。`theme_service.dart`は
  ダイアログ・ボトムシート・SnackBar・カード（カラーピッカーのダイアログの
  本体）の下地を`opaqueOver()`（`color_contrast.dart`）でパネル背景色の
  上へ平たくした不透明色にし、吹き出しの下地になるアクセント色も同様に
  している。Flutter既定のツールチップは**90%の不透明度**なので
  `tooltipTheme`で不透明にしてある。ポップアップへ個別に
  `backgroundColor:`を渡すときも半透明の色を使わないこと
  （`test/popup_opaque_background_test.dart`が、全組み込みテーマと
  わざと半透明にしたテーマで、赤い画面の上に出したポップアップの色を
  画素で見張る）。なおボトムシートの中身に幅の無い`SizedBox(height:)`
  だけを入れるとシートの幅が0になり何も描かれない（テストで踏んだ）。
- **パネル表示中の「外側タップで閉じる」透明バリアは、キャンバスへの
  タッチを全部吸う**：スマホでは`_anyToolPanelOpen`の間、
  `canvas_screen.dart`がキャンバスの上へ全面の`GestureDetector`を敷く。
  そのためパネルからキャンバスを使う機能（フィルターのキャンバス上の
  つまみ、フィルターパネルの「キャンバスから色を取る」）はタッチが
  キャンバスへ届かず、押すとパネルが閉じるだけだった。
  `_filterPanelUsesCanvas()`の間はバリアを`IgnorePointer`で素通しにして
  ある。**バリアを`if`で外すのは不可**：Stackの子の並びがずれて
  パネルのElementが作り直され、編集中のフィルターが一覧へ戻る（実際に
  踏んだ）。同種の機能を足すときはこの判定に足すこと
  （`test/sphere_shading_canvas_e2e_test.dart`が見張る）。あわせて、
  PC/DeXの横に出す編集中のフィルターパネルは`Material(type: transparency)`＋
  `hitTestBehavior: deferToChild`のスクロールで、**何も無い所のタッチは
  下のキャンバスへ通す**（`Card`や既定のScrollableは全面で吸う）。
- **スマホのフィルター調整中は「調整モード」：キャンバスモードの表示を
  隠し、プレビューはキャンバスへ直接出す**：`canvas_screen.dart`の
  `filterAdjusting`（`_showFilterPanel && !isDesktop`）の間は、上部バー
  （独自のUndo/Redoを持つ）・太さ/不透明度スライダー・ツールバー・
  フレーム一覧を出さず、`FilterPanel(bottomBar: true)`を画面下部に
  横幅いっぱいで出す（Undo/Redoボタンを2か所に出さない、というユーザー
  指定）。プレビューは別枠ではなく、`FilterPanel.onCanvasPreviewChanged`
  で受けた縮小画像を`CanvasArea.currentLayerPreview`へ渡し、**編集中の
  レイヤーの合成画像だけを差し替えて**描く（レイヤーの画素は適用まで
  変えない）。この間`CanvasArea.lockToolInput`で描画を止め、つまみ以外は
  反応しない。プレビュー計算は`lib/engine/filter_preview.dart`の
  `runFilterPreview`を`compute`で回す純関数で、パネル側は実行中に来た
  要求を1つに畳んで最新だけ描く。調整モードの出入りで画像を破棄し忘れる
  と`ui.Image`がリークするので、`onClose`と`dispose`の両方で捨てている。
  **キャンバスの選択範囲は描画フィルターを内側に限る**：`CanvasArea.
  onSelectionMaskChanged`→`canvas_screen`→`FilterPanel.selectionMask`と渡り、
  プレビューは`runFilterPreviewInSelection`、適用は`restrictToSelection`
  （新規レイヤーを作る種類は`clearOutsideSelection`）で外側を元のまま残す
  （`lib/engine/filter_selection.dart`）。眼鏡断層だけは自分の「レンズの範囲」
  （`FilterLensMask`、`canvas_screen`が持ちCanvasAreaとFilterPanelへ渡す）を
  使い、調整中のタッチはつまみより後・描画ロックより前に
  `_beginLensMaskEdit`がペン・消しゴム・バケツとして受ける。範囲の変更は
  `FilterLensMask.edit`でフィルター編集のUndoへ1手ずつ積むこと
  （`test/filter_selection_lens_mask_e2e_test.dart`）。
- **プリズムの「ぼかし量」はガウスぼかしの標準偏差（σ）**：一般的な
  ペイントアプリのガウスぼかしと同じ尺度（ユーザーの参考手順は「ぼかし17」）。
  `applyGaussianBlur`の強さはσの3倍（半径）なので、プリズムは
  `applyGaussianBlurSigma`を使う。半径のまま渡していた頃は同じ17でもぼかしが
  3分の1で、6色の帯が混ざらず縞のまま残った。虹の6色は**形ごと**（つながった
  不透明部分ごと）に割り振るので、1枚のレイヤーに小さな光の筋を何本描いても
  それぞれが虹全体になる。見本は「暗い赤の細い葉の形」を絵の上で使う
  （キャラクター全体にかけると帯が大きな旗のようになり、参考と違って見えた）。
- **フィルターが作る新規レイヤーは`generatedLayerFitted`を通すこと**：縁取り・
  墨溜まり（元の直下）・自動線画（元の直上）の新規レイヤーをそのまま挿入すると、
  クリッピングしている元レイヤーのクリッピング先が新規レイヤーに変わる
  （元が自分の縁取りに切り抜かれる）。`filter_def.dart`の
  `generatedLayerFitted`が元のフォルダを引き継ぎ、直上がクリッピングなら
  自分もクリッピングにする。作る場所はFilterPanel・記録再生・自動操作の
  3か所（`test/generated_layer_clipping_test.dart`）。
  同じ理由で、キャンバスの「現在レイヤーより上」は**全レイヤーの一覧を
  `shouldRender`で絞って**合成すること（部分リストにすると、現在レイヤーへ
  クリッピングしたレイヤーのクリッピング先が見つからず、全面に描かれる）。
- **公式の自動操作プリセットは端末に保存されたコピーが動く**：
  `CustomAutomationService.init`の`_refreshBuiltins`が、編集されていない
  （`updatedAt`が配布時のエポックのままの）公式プリセットを最新の手順に
  置き換え、配布をやめたものを消し、新しいものを1回だけ足す。手順を変えた
  公式プリセットは`updatedAt`をエポックのままにすること（変えると更新が
  届かない）。
  公式プリセットの名前・手順名は保存データでは日本語のままで、**表示時に**
  `lib/utils/custom_automation_labels.dart`が訳す（名前は配布時の日本語名と
  一致したときだけ訳すので、配布名を変えるならそこの対応表も直すこと）。
  手順名は保存された`label`ではなく手順の種類と設定から作るため、テストで
  `find.text(step.label)`を探しても見つからない。`customAutomationStepLabel`
  で表示名を求めること。
- **縦スクロールのスクロールバーはアプリ全体で常時表示（個別に`Scrollbar`で
  包まない）**：`app.dart`の`scrollBehavior: const AppScrollBehavior()`
  （`lib/widgets/app_scroll_behavior.dart`）が、縦スクロールすべての右端に
  つまみを出す（ユーザー指定）。画面側でさらに`Scrollbar`で包むと二重に出る。
  スマホでは表示だけの`AlwaysShownScrollIndicator`を使っていて、Flutterの
  `Scrollbar(thumbVisibility: true)`は使っていない。後者はコントローラーが
  1つのスクロールにだけ付いていることを要求するが、スマホではコントローラーを
  渡していない縦スクロールが画面ごとの`PrimaryScrollController`を共有するため、
  同じ画面に2つあるだけで例外になる。テストで自前の`MaterialApp`を組むと
  この振る舞いが入らないので、本番と同じ見た目を撮るときは
  `scrollBehavior: const AppScrollBehavior()`を渡すこと
  （`test/app_scroll_behavior_test.dart`が見張る）。
- **フィルターでブレンドモードを使うときは`lib/engine/blend_math.dart`**：
  レイヤー合成（GPUの`BlendMode`と一部CPU）と同じ式を純Dartで持つ。
  25種すべてが実際の合成結果と一致することを
  `test/engine/blend_math_test.dart`が照合している。自前で式を書くと、
  同じ「乗算」でもレイヤーで重ねたときと見え方が食い違う。
  不透明度（重み）を掛けて重ねるときは`blendRgbOver`を使うこと。加算だけは
  GPUのPlus（上の色×重みを足す）で、他のモードの「混ぜた色へ重みの割合だけ
  寄せる」とは違う（半透明で加算の方が明るい）。手で`b + (blend − b) × w`と
  書くと加算だけ合成と食い違う。50%でも25種すべて照合している。
- **背景馴染ませのブレンドモードは段ごとに決めてある（ユーザー指定）**：
  光と影はハードライト（「ハードライトにしてください」の指定）、それ以外は
  ユーザーから渡された「背景と人物の馴染ませ方」のチュートリアルどおりに、
  周りの色（環境光）はオーバーレイ、照り返し・色移りはスクリーン、ネオンの
  ような強い有色光（`isGlowingLight`）は加算・発光。影の色は黒や灰色ではなく
  背景の暗い3分の1の平均色を暗くしたもの（`_shadowColour`。ハードライトで
  暗くなるよう明るさ25%以下）。「明るさ・色みを背景に合わせる」
  （`bgBlendToneMatch`、`_matchTones`）は背景より明るすぎ・鮮やかすぎる所を
  背景の範囲へ寄せ、明るさごとに背景の色みへ寄せる（線画の黒は触らない）。
  加算の光を体全体にかけると全身が光るので、強い光は輪郭寄りにだけ当てる。
  光の色はその方向の標本の明るい4分の1の平均（全体の平均だと暗い壁の中の
  ネオンがくすみ、ハードライトでかえって暗くした）。形の内側の向きは距離の
  傾きを5×5画素で取る（3×3だと扇状の筋が出て、加算の光が放射状に見えた）。
  「ぼかし具合」（`bgBlendBlur`）は以前どこでも使われていない飾りのスライダー
  だった（今は色を拾う背景のぼかし）。`test/engine/background_blend_tutorial_test.dart`。
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

- **投げ縄の「線に吸着」は「領域を選ぶ」方式（経路を寄せる方式ではない）**：
  `lib/engine/lasso_region_snap_engine.dart`の`LassoRegionSnap.select`が、
  バケツ塗りと同じ考え方で絵を領域に分け（紙＝透明か白い所を線で区切った所、
  線より太い同じ色の塗り）、投げ縄の内側に半分以上入る領域を選ぶ。
  **キャンバスの端まで続く領域（絵の周りの紙）は9割以上囲んだときだけ**
  （投げ縄をキャンバスいっぱいに描いても周りの紙は選ばない）。線は選んだ
  領域から線の太さぶんだけ**外側の縁まで**取り込む（ユーザー指定「1個の線画に
  投げ縄がぴったり沿う」）。輪郭から外へ伸びる線は輪郭の所で切れ、投げ縄を
  横切るだけの線は入らない。以前は線を最寄りの領域へ割り振って縁＝線の中央
  にしていたうえ、色を塗った面まで「線」と見なしていたため、塗りのある
  レイヤーでは選べる領域が無く囲んだ形のまま選択され「不安定」に見えた
  （ユーザー指摘）。角まで取り込むため、線への取り込みは斜めの隣も1歩と
  数える。「線画の隙間許容」は線を許容幅の半分だけ太らせて領域を求める
  隙間閉じ。囲む領域が無いときは`null`＝囲んだ形のまま。`compute`で回すので
  テストは`tester.runAsync`で待つこと（`test/lasso_snap_canvas_test.dart`）。
  ユーザー指定で、旧方式（指の軌跡を線へ寄せる`lasso_line_snap_engine`）は
  削除済み。戻さないこと。
  投げ縄塗りの「囲って塗る」（`LassoFillEngine.fillEnclosed`）も同じ考え方で、
  囲んだ中の**線で閉じた透明な領域だけ**をいくつでも一括で塗る（半分以上
  囲んだ領域を丸ごと。キャンバスの端まで続く領域は9割以上）。投げ縄と絵の
  間の余白は塗らない（以前は投げ縄の内側の透明部分をすべて塗っていた）。
- **細線化（Zhang-Suen）の結果を数えるときは「隣の画素の数」でなく「隣の線の
  塊の数」で分岐を判定すること**：斜めの線の階段の角の画素は隣が3つあるが
  1本の線。画素数で数えると階段の全部が分岐になり、自動線画の線が細切れに
  なって捨てられた（「とぎれとぎれ」の原因）。`auto_lineart_engine.dart`の
  `_lineDegree`（塊の数、2×2の結び目は分岐）と`_removeRedundantSteps`が実例。
  Zhang-Suenは2×2の塊や小さな点を**丸ごと消す**ので、点（目）は
  `_keepVanishedDots`で残している。
  **素のZhang-Suenは斜めの線を丸ごと消すことがある**：斜め線を2px幅の階段まで
  削ると端の画素は隣が2つになり、それを毎回取り除くので端から線全体を食べる
  （Xの交差で片方の線が消え、45°の線が短くなった）。自動線画はLü-Wangの補正
  （隣3つ以上だけ消す）→残る2pxの階段をGuo-Hallで1pxに、の2段にしてある。
  Guo-Hallを最初から使うと交差・重なりの中心線の位置が変わり、後段の判定が
  崩れた（髪と頭の輪郭の重なりで折れが出た）。`_removeRedundantSteps`は
  上下と左右の両方に隣がある「段の角」だけを消す（線の端を消すと階段の端から
  縮む）。墨溜まり（`ink_pool_engine.dart`）は素のZhang-Suenのまま
  （2段に替えると`ink_pool_sweep_test`の角の形が崩れた）で、線が消えたときだけ
  `_restoreVanished`がその部分の中心線を2段の細線化から補う（インクが中心線から
  線幅より遠い所があるときだけ働くので、普段の結果は変わらない）。直角のX交差は
  細線化で「どの画素も分岐3本にならない小さな結び目」になることもあり、
  `_addKnotJunctions`が周囲2pxの枠を3本以上の線が横切る所を交点にする
  （`test/engine/ink_pool_x_crossing_test.dart`）。浅い角度で交わる細い線は
  細線化で「分かれ目＋短い橋＋分かれ目」になり、遠い方の分かれ目のすぐ先では
  2本がまだくっついている。線を数える輪（`ringDistance`）は**最後の分かれ目
  から**測ること（交点からの距離で測ると2本を1本と数え、片側の狭い角に
  溜まらなかった。線3〜8px・25〜50°の288通り中25通り）。
  逆に、**階段の余分な角を取り除いた後**（`_removeRedundantSteps`の後）は、
  隣が3画素以上なら分岐として扱うこと（`_branchDegree`）。2本の線が浅い角度で
  合流する所は「互いに隣り合う3画素の三角形」になり、塊で数えるとどの画素も
  1本の線に見えて分岐を見落とす。見落とすと分岐の無い線として扱われ、
  内側の線が2画素ずつの断片に切れて点線になった（頭の輪郭と生え際で実際に
  踏んだ）。
- **自動線画は「紙が見えている所は別の線」**（ユーザー指定）：近くに並んだ
  2本の線を1本にまとめない。埋めるのは線の中の小さな白い点（ラフ線幅の
  半分以下の大きさ・3分の1四方以下の面積で、四方を線に囲まれたもの）だけ
  （`_fillPinholes`）。以前は線から「ラフ線幅の半分」以内の囲まれた隙間を
  すべて埋めていたため、頭の輪郭と生え際・首と襟のように近い線が1本に
  なっていた。`test/engine/auto_lineart_continuity_test.dart`が見張る。
  あわせて、Catmull-Romの接線は**その区間の長さの割合**で縮めること
  （`_curveThrough`）。両隣の区間の長さが大きく違う所（閉じた輪の継ぎ目等）で
  弦の半分をそのまま使うと、短い区間が10px近く外へはみ出した。
- **自動線画で2本の線が合流する所は`_separateMerges`が2本に戻す**：細線化だと
  合流した所がY字になり、2本の線が交点へ折れ曲がって真ん中に1本の線が続く
  （ユーザー指摘「ラフのように2本の線が徐々にくっついていくように」）。
  距離変換（`_distanceToPaper`、Felzenszwalbの厳密なユークリッド距離）で各点の
  インクの幅を測り、「3本が出会い、うち2本が75°未満の鋭角で同じ側から来て、
  交点のインクが1本の幅の1.4倍以上」の所だけ、残りの1本に沿って両側へ
  （幅−1本の幅）/2ずらした2本に置き換える（幅が1本分まで細ったら1本に戻る）。
  普通の分かれ道・T字は対象外。生成AIは使っていない（ユーザー指定）。
  ただし、**合流した線が次の交点まで2本分の太さのまま**続く所（頭の丸い下端が
  襟の線の下へ重なる所。2本は交差して一瞬1本になるだけ）は`_overlapping`で
  見分けて対象外にし、`_resolveJunctions`に任せる。ここで2本へ割ると、襟が
  波打ち頭の下端が消えた。
- **自動線画の交点は`_resolveJunctions`がラフの描き方どおりにつなぎ直す**
  （ユーザー指定「イメージそのまま線画の細さを整えるくらい」）：細線化は交点で
  各線を交点へ折り曲げ、重なった2本を真ん中の1本にする。各線を交点の曲げが
  始まる所まで戻し、最もなめらかに続く組（曲がり110°まで・インクの内側を
  通る）から順に3次曲線でつなぐ（Xは2本の直線のまま、襟は直線、頭の下端は
  円のまま襟の下を通る）。重なりの真ん中の線は、つないだ線が8割以上覆うとき
  だけ捨てる。その後`_evenOut`（線幅の半分のσでならし、40°以上の角は固定）と
  `_keepShape`（Douglas–Peucker）で手ぶれのぐにゃぐにゃを消す。
  太い線の角は細線化で平らに削れるので、`_restoreCorners`は**角から離れた
  まっすぐな腕どうしの向き**で曲がりを測る（角の近くで測ると平らな底のぶん
  緩く見え、98°のV字が直されず2.5px浅くなった）。目のような点は
  `AutoLineartPath.dotRadius`でラフの点の大きさのまま塗りつぶす。
  `test/engine/auto_lineart_fidelity_test.dart`がキャラクターのラフで
  （頭が丸いまま・襟が直線・目が塗りつぶし・線がラフのインクの外へ出ない・
  Xの交差がどの画素の並びでも2本の直線）を見張る。
- **自動線画で2本の線が1本のインクの帯になって並ぶ所（頭のすぐ外側を沿う
  髪の輪郭）は、帯を左右の「辺の線」に分ける**（ユーザー指摘「ラフでは髪の
  右側が頭より外側に飛び出しているのに一体化している」）：`_resolveJunctions`は
  帯の両側のインクの縁から線幅の半分内側に2本の線を引き、帯の両端に入る線を
  **両端まとめて**割り当てる（入る線＋辺の線＋出る線が一番なめらかな曲線に
  なる組、`_smoothFitError`）。端の線の向きで1つずつ選ぶと、2本が1〜3pxまで
  近づく髪の先端で決まらず、髪と頭が帯の中で入れ替わった。帯の端は前髪など
  他の線のインクで太るので、辺の線は「2本だけが並ぶ最長の区間」に限り、
  2つの帯が出会う所（口が襟に触れて帯が途中で切れる所）は帯ごとに決めない
  （`contested`）。
- **自動線画の斜めの交差の真ん中は「2本が重なった線」として扱う**：浅い角度の
  Xは細線化で「交点＋短い線＋交点」になり、各交点で2本が鋭角に合流するので
  `_separateMerges`が合流と見なして割り、4本の腕が切れていた（15°〜60°の
  すべて、以前から）。両端で他の2本が外向きに離れていく短い線
  （`_crossingArms`）は割らずに重なりとして扱い、帯の辺の線にもしない（間隔が
  真ん中で最小になり両側で開く、短い帯なら向こう側の線へ続く方がまっすぐ）。
  つなぐ組の費用は交点での向き（`mismatch`）＋その先6線幅のなめらかさ
  （`runsOn`の15倍）：交点だけでは、触れ合うだけの2本（髪の輪郭が頭に触れる
  所）と交差する2本がどちらも同じようになめらかに続いて見分けられない。
  `mismatch`は曲率つきとまっすぐの延長の近い方（画素の階段で出た曲率を広い
  交点の先まで延ばすと、まっすぐな線が別の線へ曲がった）。線の端の向き
  （`_headingAtCut`）は、6線幅で見てまっすぐなら直線の当てはめ（2次曲線の
  端での傾きは階段で最大20°ぶれる）、¾px以上曲がって見えるときだけ3線幅の
  2次曲線。交点どうしをつなぐ線幅0.7倍以下のくびれ（口の下が襟に触れた所）は
  線ではないので描かない。**交差のテストは端の距離でなく全点が自分の
  ストロークの上にあるかを見ること**（V字2本に折れても端の距離はほぼ同じで、
  実際に見逃した）。`auto_lineart_fidelity_test`が髪と頭・前髪の先端・
  15°〜60°の交差を見張る。
- **自動線画の太いペン（線幅10px前後）で踏んだ3つ**：(1) 2本の線の間に細い
  紙の隙間が残ると、その内側の線は両端が太い交点の短い線になり、両端から
  「曲げが始まる所」まで戻すと線が残らない。戻し幅は両端の比で分け合って
  両端ともつなぐこと（片方の端を捨てると線が途切れ、隙間の端に「く」の字の
  フックが出た）。(2) `_separateMerges`は、合流して見える2本の一方がすでに
  2本分の太さ（髪と頭が並ぶ帯）なら割らない（割ると帯が辺の線に分けられず、
  髪と頭が真ん中の1本になった）。(3) 口の底が襟に押し付けられると、線1本より
  太いインクの短い線が口から襟へ渡る。両端で残りの2本がそのまま通り抜けて
  いて、この線が真横に渡るだけなら線にしない（`_bridgesAcross`）。円を並べて
  描くテストのラフでは(1)が再現しなかった（キャンバスと同じアンチエイリアスの
  線で初めて出た）ので、太いペンのテストは`_penRough`で描くこと。
- **ドット絵の色の限り方（`pixel_art_engine.dart`）**：色を限るとき、フィルター
  （描画・演出・プレビュー＝`applyPixelate`の既定`dither: true`）は**規則的な
  ディザリング**（4×4のBayer、Yliluoma式で最大3色）で元の色に近づける。誤差拡散に
  しないこと（アニメーションのフレームごとに模様が動いてちらつく）。2色だけでは
  作れない色が多い（6色の原色で明るい肌色は白・黄・赤の3色が要る）。混ぜ方の数は
  色の差（CIELAB）を最小にして決め、点どうしの明るさ・色みのばらつきの手間は
  「どの組を使うか」の比較にだけ足すこと（数の決定に混ぜると、全部の混ぜ方が
  目立たない側へ1段ずれた）。1色で差10以内なら混ぜず、それ以上も1色の差の
  5〜8割まで縮むときだけ混ぜる（明るい空が白黒の市松、顔にそばかすになった）。
  3色の割合は線形光の最小二乗を起点に、1点ずつ移す山登りで決める（最小二乗の
  周り±1だけだと良い組が選ばれず、紫の服が赤・青・緑の点になった）。
  隣と色がはっきり違うドット（輪郭）は「輪郭でない最も似た隣」の混ぜ方を使い、
  無ければ1色（混ぜると輪郭沿いに第3の色の点が散った）。ブラシのピクセルモードと
  スタンプは`dither: false`で従来どおり1色。ドット絵フィルターには入切の
  スイッチがある（ユーザー指定）：描画フィルターは`FilterDef.pixelDither`、
  演出フィルターは`EffectFilterInstance.pixelDither`（.niaproの`pixelDither`）。
  どちらも既定はオンで、項目の無い古い保存データもオンとして読む。色を限らない
  （`PixelColorMode.none`）ときはスイッチを出さない。演出フィルターの複製
  （`timeline_screen.dart`の`_duplicate`）は項目を1つずつ写すので、項目を
  足したらそこにも足すこと。色数指定の色は「最も離れた色から
  順に」ではなく、そこから重み付きk-means（見た目の差）で絵の多くを占める色へ
  寄せ、最後に実在の色へ合わせる（最遠点だけだと肌色の顔が端の色でベタ塗り
  になった）。`test/engine/pixel_art_dither_test.dart`が見張る。
  **ドットの色はブロックの単純平均にしないこと**：目・口のような小さな暗い
  特徴は、8pxのブロックの4分の1程度しかなく、平均は肌色よりわずかに暗い
  だけになる。見た目の近さ（CIELAB）で色を選ぶと肌色になり、顔が
  のっぺらぼうになった（ユーザー指摘。RGB距離だった頃は偶然ピンク等に
  なって残っていた）。`_keepDetails`（Weber et al. 2016の詳細保持縮小）で、
  各画素を「そのドットと周り8ドットの平均色」からの距離で重み付けして
  ドットの色を決める（指数1。0.5では口が消えた）。広い面の色は周りと同じ
  なので軽く、浮いている特徴が重くなる。`test/engine/pixel_art_details_test.dart`
  が4通り（パレット／色数×ディザリング入切）で目と口が残ることを見張る。
- **アニメ風加工の境界線は「暗い側」へ引き、アンチエイリアスの中間色は
  境目の一部として扱う**（`lib/engine/anime_border_lines.dart`）：隣どうしの
  差（CIELABのΔE＋不透明度）が閾値以上の所に線を引くが、ペンの柔らかい縁
  （線画とその外側の中間色の画素）を「別の色の境目」として扱うと、中間色の
  画素が真っ黒になり線画が1pxずつ太る（実際に踏んだ）。中間色を最大2画素
  まで飛ばして両側の色を求め、混ざり具合が半々の所に境目を置き、中間色の
  画素は暗い色の分（`light`で残す明るい色の分を引いた残り）だけを暗くする。
  境目は白い紙の上での見え方で探すので、不透明度を4つ目の成分に入れないと
  白い形の縁に線が引かれない。
- **質感変更の「線画を残す」は、線を「段になった縁」で見分ける**
  （`filter_engine.dart`の`_lineArtShare`）：明るさだけで決めると、形の縁へ
  向かって暗くなる陰影（球の暗い側等）まで線として残り、縁に黒い斑点が出た。
  両側に明るい所があり、その明るさへ最後の2pxで上がること、片側は不透明な
  面であること、24画素以上つながっていることの3つで絞っている。
- **Dijkstra等で距離を`Float32List`に入れないこと**：√2を足していくと、
  格納時の丸めで「取り出した距離＞格納した距離」になり、まだ使う画素を
  読み飛ばす（墨溜まりの枝が途中で切れた）。距離は`Float64List`で持つ。
- **墨溜まりは「最大角度」以下の角の内側だけ**（ユーザー指定、0〜180°、
  初期値90°＝鋭角と直角）：`ink_pool_engine.dart`の`angleLimit`。手描きの
  ぶれを見込んで設定の1割（最大6°）の余裕を足し、170°で頭打ち（まっすぐな
  線の両側には溜めない）。初期値では96°未満の側だけ（T字・四角い角には出し、
  鈍角には出さない。オリンピックの輪の広い側＝106°は太い線だと99°前後に
  測れるので、余裕を増やすときは`ink_pool_taper_test`の輪のテストを見ること）。
  広い設定で踏んだこと：(a) 1本の線の曲がり角を見つける余裕（細線化で角が
  斜めに削れて広く測れる分）を初期値のまま使うと、角のすぐ先の線上の点が
  「曲がって見える」ので角と誤認され、外側に塊が出た→角が広いほど余裕を
  小さくする（`_slack`）。(b) 「ほぼ反対向きの2本は1本の直線」とまとめる
  規則（30°以内）が160°の角を180°にしてしまった→「180°−上限」より狭いとき
  だけまとめる。(c) 円などの曲線は近くより遠くで鋭く測れるので、広い設定では
  近くと遠くの差が15°を超える所は角としない。演出フィルターの墨溜まりは
  param3が既存データで2.0のため流用できず、初期値90°のまま。
  `test/engine/ink_pool_max_angle_test.dart`が0/30/90/120/150/180°で見張る。
  太さは**線の縁から**測り、出会う点で「中央の太さ」→範囲の端で**0px**
  （ユーザー指定。1pxで止めると先端に段が残ってひっかかって見えた。0pxなら
  アンチエイリアスでなめらかにとがる）。
  範囲の途中で線が途切れているときは、**その線だけ**途切れた所（細線化の
  端からインクの端まで延ばし、丸い端の半径ぶん戻した所＝線の側面が終わる所）を
  終点にして0pxまで細くする（ユーザー指定、`reachOf`）。別の交点へ続く線は
  途切れではない。出会う点から`near`（最大12px）より短い線は、そもそも線として
  数えない（ひげのような短い線で溜まらない）。
  **片方の線だけ短いとき、長い方を自分の長さどおりに細くしてはいけない**：
  長い方がまだ太い所で短い方が細り、角の中心が短い方へずれて長い方だけ
  膨らんで見える（ユーザー指摘）。`taperOf`／`_Taper`で、2つの墨溜まりの
  輪郭が**角の二等分線上で出会う**（そこでの線の縁からの太さが両方同じ）よう、
  長い方もそこまでは短い方と同じ傾きで細くし、そこから自分の端まで0pxへ
  細くする。`ink_pool_taper_test`の途切れのテストが、縦線の横（縦線自身の
  傾き）と横線の下（範囲の端で0）をそれぞれ直線で当てはめ、交点が45°±5°に
  あることを見張っている。
  **中央の太さを大きくしてもふくらませない**（ユーザー指定）：各線の溜まりは
  「2つの溜まりの端どうしを結ぶ直線」までで止める（`_Taper.flatSlope`、線の縁の
  出会う点から測る）。止めないと、範囲に比べて太さが大きいとき2本の輪郭が
  二等分線上で外へ尖ってふくらんだ。最大でも中央は平ら。
  `test/engine/ink_pool_sweep_test.dart`が中央の太さ×範囲の30通りを理想の形と
  画素で突き合わせている。角度・太さを狂わせた原因は全部実際に踏んだので、
  触るときは次を崩さないこと：(1) 線の向きは細線化の画素ではなく**線の
  インクの中心**へ寄せた点で測る（斜めの細線の中心画素は半画素片側へ
  寄り、鋭角では角の位置が1pxずれる）、(2) 交差は細線化で**2つの分岐**に
  なるので、その中点を交点にし、各線の測定は最後の分岐から始める、
  (3) 曲線（輪）は前半と後半の向きの差で曲がりを測り交点まで戻す
  （放物線の外挿は斜め線の1px段差を曲がりと誤認した）、(4) 交点間の短い線は
  交点の反対側の同じ線の向きを使う、(5) 線に沿った距離は画素の道のり
  （斜めで最大1割長い）ではなく直線距離、(6) 線の縁は「中心から外へ積分した
  インク量」で測り、隣の中心画素どうしでは距離でなく**縁の位置**を平均する、
  (7) 円（カプセル）で押すと太さの半分だけ線方向へ膨らむので、線に直角な
  帯（スライス）を並べ、帯の中でも太さを傾ける。
- **`dart format lib test tool`は他セッションの未整形ファイルまで書き換える**：
  別セッションがGitHub API経由で未整形のまま入れたファイル
  （`brush_texture_selector.dart`等）があり、全体にかけると無関係なファイルが
  数十〜百件変わる
  （`frame_strip_square_ratio_test.dart`や監査担当の`app_web_reference_*`も
  含む）。**自分が触ったファイルだけ**を指定して整形すること。同じく、別
  セッションが生成ファイル（`app_localizations_*.dart`）だけを手で直して
  ARBと食い違っていることがある（簡体字に繁体字が入っていた）。ARBが正なので
  `flutter gen-l10n`で戻す。

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

9. **作品広場のAPIクライアント層・書き込みの配線は実装済み。残るのは
   デプロイと通報・ブロックの画面**：`lib/services/api/`にバックエンドの
   **22エンドポイント全て**を
   型付きで呼ぶ層がある（`community_api.dart`＋HTTP下請けの
   `niarim_api_client.dart`＋DTOの`niarim_api_models.dart`）。接続先は
   ビルド時の`--dart-define=NIARIM_API_BASE_URL=https://...`で渡し、
   未指定なら`CommunityService`は従来どおりダミーデータで動く
   （デプロイ前でも画面確認・スクリーンショット・テストが一通りできる
   状態を保つため）。読み取り系（新着一覧・ランキング）は
   `CommunityService.refreshFromBackend()`・`fetchRanking()`で配線済み。
   状況は次のとおり：
   - 書き込み系（投稿・タグ・公開設定・「AI画像・AI動画使用」・
     ブックマーク・リポスト・フォロー）は`GoogleAuthService.backendIdToken`
     のIDトークンで送る形まで配線済み（手元へ即反映→送信→サーバーの返事で
     置き換え、断られたら巻き戻して`lastError`）。起動時はGoogleアカウント
     ごとに覚えた投稿者IDを`restoreOwner`で先に戻し、`/me/works`→
     `loadSocial`（ブックマーク・フォロー中・リポスト→フォロー中フィード）の
     順に取り込む。作者ページは開いたときに`refreshAuthorWorks`で取得する。
     ストアの作品は「サーバーが確認したもの」だけに絞る
     （`_pruneUnconfirmed`）ので、新しい取得経路を足すときは確認済みIDの
     集合にも足すこと（足さないと次の新着取得で消える）。
     通報・ブロックはまだ画面から呼んでいない。
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
