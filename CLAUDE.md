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
2. コード変更後は必ず`flutter analyze`（ベースライン：73 issues、0 errors。
   全て既存のdeprecated_member_use / use_build_context_synchronousのinfoで
   増減が無いことを確認する）
3. `flutter test`（ベースライン：232 tests、全成功。うち大半は
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
- **R8（コード圧縮）を疑う前に本当にR8が原因か切り分けること／ドキュメント間の
  矛盾に注意**：過去に実機起動直後クラッシュの原因をffmpeg関連ライブラリの
  切替と誤って結び付け一度全面revertしたが、真因はリリースビルドのR8
  （`isMinifyEnabled`）だったと判明した経緯がある。**`pubspec.yaml`の
  ffmpeg依存コメントは「R8を無効化した状態を保っている」と書かれているが、
  これは古い記述で現状と矛盾している**：`android/app/build.gradle.kts`は
  現在`isMinifyEnabled = true`（`proguard-rules.pro`に
  `HardwareVideoEncoder`のkeepルールを追加した上で再有効化済み）になって
  おり、そのコメントには「この修正込みでのR8有効ビルドの実機起動確認は
  まだ済んでいない」と明記されている。次回セッションで実機確認したら、
  結果に応じて`pubspec.yaml`側のコメントも実態に合わせて修正すること。
- **依存パッケージのバージョン固定には必ず理由がある**：`pubspec.yaml`の
  `file_picker: 10.3.10`・`share_plus: ^12.0.2`・
  `ffmpeg_kit_flutter_new_video`等は、AARメタデータ不整合やAndroidビルド
  破壊を避けるために意図的にピン留めされている。コメントを読まずに
  `flutter pub upgrade`等で無条件に上げないこと。
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

## 人間の実操作が必要な項目（ストア公開前に必ず確認・最重要）

以下はAIによるコード修正だけでは完結しない、ユーザー本人（事業者）が
実際に操作・判断しないと進まない項目。詳細は
`docs/AI設計書/28_継続タスク（未着手一覧）.md`の同名セクション参照。

- **収益化タイマーが2027年1月1日で止まっている**：
  `lib/config/monetization_gate.dart`の`kMonetizationEnabledFrom =
  DateTime(2027, 1, 1)`により、この日時に達するまで広告SDK（AdMob）・
  アプリ内課金（in_app_purchase）が一切初期化・接続されず、代わりに
  全ユーザーへプレミアム機能が無料開放される「リリース記念キャンペーン」
  状態になっている（税務上の都合によるもの、`PremiumService`・
  `AdvertisingService`のクラスコメント参照）。**本番公開のタイミングに
  合わせてこの日付をユーザー自身が判断・変更する必要がある**（同ファイルの
  コメントには「有効化後は本ファイルを削除し、参照箇所も外すこと」と
  ある）。
- **作品広場（コミュニティ機能）のフロントエンドは、バックエンドと
  一切繋がっていない**：`lib/services/community_service.dart`は全データが
  ハードコードされたダミーデータで、`package:http`を使うコードは
  `lib/`全体で`font_service.dart`（フォントダウンロード）以外に存在しない。
  つまり`backend/`（AWS CDK+Lambda+DynamoDB、コードのみ）を実際にAWSへ
  デプロイしても（後述のTask#175）、**Flutterアプリ側は自動的には繋がらない**。
  実際に多人数で使える作品広場にするには、認証（NIARIM User ID発行フロー）・
  作品CRUD・ランキング/検索・フォロー/ブロック/通報・ブックマーク/リポストの
  各APIを呼ぶHTTPクライアント層をFlutter側に新規実装し、
  `community_service.dart`のダミーデータをすべて実データ連携へ差し替える、
  という大規模な追加実装が丸ごと未着手のまま残っている。「バックエンドさえ
  デプロイすれば作品広場が動く」わけではない点を必ず引き継ぐこと。
- **Android署名鍵がデバッグ鍵のまま**：`android/app/build.gradle.kts`の
  `release`ビルドタイプが`signingConfig = signingConfigs.getByName("debug")`
  のまま（コード内`TODO: Add your own signing config for the release
  build.`）。Google Play提出には本番用の署名鍵（keystore）が必須で、
  秘密鍵の生成・安全な保管はユーザー自身が行う必要がある（AIが代わりに
  生成・管理すべきではない）。
- **AdMob・アプリ内課金がすべてテスト用ID**：
  - `android/app/src/main/AndroidManifest.xml`の
    `com.google.android.gms.ads.APPLICATION_ID`はGoogle公式の
    サンプル用テストID（`ca-app-pub-3940256099942544~3347511713`）のまま。
  - `lib/services/admob_provider.dart`のバナー・スクエア広告ユニットIDも
    Google公式テストID（`ca-app-pub-3940256099942544/...`）のまま。
  - ユーザー自身のAdMobコンソールで実際のアプリ・広告ユニットを作成し、
    発行された本番IDへ差し替える必要がある。
  - `lib/services/premium_service.dart`のサブスクリプション商品ID
    （`niarim_premium_monthly`・`niarim_premium_yearly`）は、Google Play
    Consoleに登録する商品IDと**文字列レベルで完全一致**させる必要がある。
    ユーザーがPlay Console側でこれらのIDで商品を作成しないと課金テスト
    自体ができない。また、購入のサーバー側レシート検証（Google Play
    Developer API等）は未実装で、クライアント側の購入イベントのみを
    信頼する設計になっている（`PremiumService`のコメント参照）。
- **プライバシーポリシーの問い合わせ先が全7言語プレースホルダーのまま**
  （`privacyPolicyArt8Body`）。本アプリ専用の連絡先をユーザーから受け取り
  次第反映する。
- **特定商取引法に基づく表示が未対応**。日本向け有料課金を提供する場合、
  事業者名・電話番号・所在地等の実データが確定するまでコード側の対応
  （専用画面の追加等）は行わない方針（プレースホルダーの偽情報を実装すると
  かえって不正確な法的表示を公開することになるため）。
- **Google Play Consoleのストア掲載情報（アプリ説明・スクリーンショット・
  アイコン素材の再アップロード等）はこのリポジトリの外側の作業**であり、
  現状確認できていない。ストア公開前にユーザー側で必ず確認すること。

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
