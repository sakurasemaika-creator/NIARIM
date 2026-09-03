import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/services/frame_thumbnail_renderer.dart';
import 'package:niarim/services/home_widget_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/widgets/sort_mode_control.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ホーム画面ウィジェット機能（設定画面の並び替え済みラジオボタン・
/// 作品を選ぶ画面・フレームを選ぶ画面）を、実機無しでも「AIだけで
/// 操作→キャプチャ→検証」できることを示すための自律テスト。
///
/// - フレームごとに全く異なる色をTileManagerへ直接塗り、合成結果が
///   フレームごとに正しく異なることを画素値そのもので検証する
///   （見た目の雰囲気ではなく、意図した機能特有の動作そのものを確認）。
/// - 実際のウィジェットツリーに対して本物のタップを打ち、
///   作品を選ぶ→フレームを選ぶ→別フレームへ切り替え→確定、という
///   一連の操作を駆動する。各段階でPNGスクリーンショットを保存する
///   （目視確認用）と同時に、[HomeWidgetService]の状態を都度アサートする
///   （目視だけに頼らない検証）。
/// - 作成/広場ウィジェットの背景色ラジオボタン（テーマに合わせる／
///   色を選ぶ）についても、実際にダイアログを開いてHEX入力→確定する
///   操作を駆動し、状態と見た目の両方を確認する。
class _FakeFilePicker extends FilePicker {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    @Deprecated('unused') bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ホーム画面ウィジェット：作品選択→フレーム選択→確定と背景色ラジオボタンを実タップで検証する', (tester) async {
    SharedPreferences.setMockInitialValues({});
    FilePicker.platform = _FakeFilePicker();
    final tempDir = Directory.systemTemp.createTempSync(
      'niarim_widget_picker_test_',
    );
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // スクリーンショットの文字が判読できるよう、実フォントを読み込む
    // （all_routes_screenshot_audit_test.dartと同じ方式）。
    await tester.runAsync(() async {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = manifest.listAssets();
      Future<void> loadFamily(String family, String needle) async {
        final matches = assets.where((a) => a.contains(needle)).toList();
        if (matches.isEmpty) return;
        final loader = FontLoader(family)
          ..addFont(rootBundle.load(matches.first));
        await loader.load();
      }

      // アイコン（戻る矢印・チェックボックス・検索等）もキャプチャで
      // 判読できるよう、SDK同梱のMaterialIconsも読み込む
      // （all_routes_screenshot_audit_test.dartと同じ方式）。
      Future<void> loadSdkMaterialIcons() async {
        final flutterRoot = Platform.environment['FLUTTER_ROOT'];
        if (flutterRoot == null) return;
        final file = File(
          '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        );
        if (!file.existsSync()) return;
        final data = ByteData.sublistView(
          Uint8List.fromList(await file.readAsBytes()),
        );
        final loader = FontLoader('MaterialIcons')
          ..addFont(Future<ByteData>.value(data));
        await loader.load();
      }

      await Future.wait([
        loadFamily('HakkouMincho', 'assets/fonts/HakkouMincho.ttf'),
        loadFamily('Kuramubon', 'assets/fonts/Kuramubon.otf'),
        loadFamily('NotoSerifJP', 'assets/fonts/NotoSerifJP.ttf'),
        loadSdkMaterialIcons(),
      ]);
    });

    appRouter.go('/');
    final providers = await tester.runAsync(buildAppProviders);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MultiProvider(providers: providers!, child: const NiarimApp()),
      ),
    );

    Future<void> settle({int rounds = 10}) async {
      for (var i = 0; i < rounds; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
    }

    await settle();

    final out = Directory('build/home-widget-picker-test-screenshots')
      ..createSync(recursive: true);
    var shotIndex = 0;
    Future<void> capture(String name) async {
      await settle(rounds: 6);
      expect(
        tester.takeException(),
        isNull,
        reason: '$name キャプチャ直前にFlutter例外が発生',
      );
      final boundary =
          boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return data?.buffer.asUint8List();
      });
      shotIndex++;
      final fileName = '${shotIndex.toString().padLeft(2, '0')}_$name.png';
      await tester.runAsync(
        () => File('${out.path}/$fileName').writeAsBytes(bytes!),
      );
    }

    // MaterialApp自身のBuildContextはMaterialAppが内部で構築する
    // LocalizationsのANCESTORではなくDESCENDANT側に無いため
    // （AppLocalizations.of()がnullになる）、常に画面上に実在する
    // Scaffoldのcontextを都度取り直して使う。Providerの読み取りも
    // 同じ関数から行う（値そのもの＝サービスの参照は取得後に画面遷移が
    // 起きても有効なままなので、都度の再取得はLocalizations対策に限る）。
    BuildContext liveContext() => tester.element(find.byType(Scaffold).first);
    AppLocalizations l10nOf() => AppLocalizations.of(liveContext())!;

    final l10n = l10nOf();
    final ps = liveContext().read<ProjectService>();

    // ── テスト用作品：フレームごとに全く別の色を直接塗る ──────────────
    // キャンバスUIを経由せず、TileManagerへ直接書き込むことで
    // 「フレームごとに独立した絵になっているか」を確実に検証できるようにする。
    // 64x64（drawingAreaScale=1.0）＝1タイル(256x256)以内に収まるサイズに
    // することで、タイル(0,0)を塗るだけでキャンバス全面が単色になり、
    // 合成結果の画素検証が座標計算に依存せず単純になる。
    final project = await tester.runAsync(
      () => ps.createProject(
        name: 'ウィジェットテスト用作品',
        fps: 4,
        durationSeconds: 1,
        backgroundColor: 0xFFB2DFDB,
        exportWidth: 64,
        exportHeight: 64,
      ),
    );
    final sceneId = ps.scenesOf(project!.id).first.id;
    final tm = ps.tileManagerOf(project.id);

    const frameColors = <(int, int, int)>[
      (255, 0, 0), // フレーム1：赤
      (0, 200, 0), // フレーム2：緑
      (0, 0, 255), // フレーム3：青
      (255, 210, 0), // フレーム4：黄
    ];
    for (var i = 0; i < frameColors.length; i++) {
      final (r, g, b) = frameColors[i];
      final key = frameLayerKey(sceneId, i, 'Layer0001');
      final tile = tm.getOrCreateTile(key, 0, 0);
      for (var px = 0; px < tile.length; px += 4) {
        tile[px] = r;
        tile[px + 1] = g;
        tile[px + 2] = b;
        tile[px + 3] = 255;
      }
    }

    // ── 合成パイプライン自体の検証（ウィジェット層を介さず直接） ──────
    // frame_thumbnail_renderer.dartがフレームごとに正しく異なる画素を
    // 合成できているかを、画素値そのもので確認する。
    for (var i = 0; i < frameColors.length; i++) {
      final (r, g, b) = frameColors[i];
      final image = await tester.runAsync(
        () => compositeFrameThumbnail(
          ps,
          projectId: project.id,
          sceneId: sceneId,
          frameIndex: i,
          maxSize: 64,
        ),
      );
      final byteData = await tester.runAsync(
        () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      final bytes = byteData!.buffer.asUint8List();
      final w = image!.width, h = image.height;
      final idx = ((h ~/ 2) * w + (w ~/ 2)) * 4;
      expect(bytes[idx], r, reason: 'フレーム$iのR成分が期待値と異なる');
      expect(bytes[idx + 1], g, reason: 'フレーム$iのG成分が期待値と異なる');
      expect(bytes[idx + 2], b, reason: 'フレーム$iのB成分が期待値と異なる');
      image.dispose();
    }

    // ── ここから実タップでの操作→キャプチャ→検証 ─────────────────────
    // 設定トップから実際にpush()で潜っていく（go()での直接ジャンプだと
    // 前画面がスタックに積まれず、戻るボタンの検証にならないため）。
    appRouter.go('/settings');
    await settle();
    await tester.tap(find.text(l10n.widgetSettingsTitle));
    await capture('settings_before_pick');
    expect(find.text(l10n.widgetArtworkPickButton), findsOneWidget);
    // 設定トップへ戻るボタン（go_routerのpush()に対する自動back）が
    // 出ていることを確認する。
    expect(find.byType(BackButton), findsOneWidget);

    // 「作品を選ぶ」行をタップ→作品一覧画面（プロジェクトタブ流用）。
    await tester.tap(find.text(l10n.widgetArtworkPickButton));
    await capture('artwork_picker_list');
    // 並び替え・表示方法・検索・お気に入り絞込のコントロールが
    // ここでも使えることを確認する（プロジェクトタブからの流用）。
    expect(find.byType(SortModeControl), findsOneWidget);
    expect(find.byIcon(Icons.view_module), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.text(l10n.homeFavoritesOnly), findsOneWidget);
    expect(find.text('ウィジェットテスト用作品'), findsOneWidget);
    // この画面にも「ウィジェット設定へ戻る」ボタンがある。push()は前画面を
    // ツリーに残したままにする（CLAUDE.md記載の既知挙動）ため、この時点では
    // 前画面（ウィジェット設定）ぶんのBackButtonも含めて複数存在しうる
    // ＝1個以上であることだけを確認する。
    expect(find.byType(BackButton), findsWidgets);

    // 作品をタップ→フレーム選択画面。
    await tester.tap(find.text('ウィジェットテスト用作品'));
    await capture('frame_picker_initial');
    expect(find.text(project.name), findsWidgets);
    expect(
      find.text(l10n.widgetArtworkFramePickerConfirmButton),
      findsOneWidget,
    );
    // 初期状態は先頭フレーム（赤）がハイライトされている。
    expect(find.byKey(const ValueKey('widgetFrameStripCell0')), findsOneWidget);
    // 確定ボタンだけでなく、確定せずキャンセルして戻る手段
    // （自動backボタン）も存在する。
    expect(find.byType(BackButton), findsWidgets);

    // ── タイムラインモードと同じ再生系コントロールを検証する ──────────
    // 最終フレームへ（skip_next）→4枚目（黄）になる。
    await tester.tap(find.byIcon(Icons.skip_next));
    await settle();
    expect(find.text(l10n.widgetArtworkFrameNumberLabel(4)), findsOneWidget);

    // 1フレーム戻る（fast_rewind）→3枚目（青）になる。
    await tester.tap(find.byIcon(Icons.fast_rewind));
    await settle();
    expect(find.text(l10n.widgetArtworkFrameNumberLabel(3)), findsOneWidget);

    // 先頭フレームへ（skip_previous）→1枚目（赤）に戻る。
    await tester.tap(find.byIcon(Icons.skip_previous));
    await settle();
    expect(find.text(l10n.widgetArtworkFrameNumberLabel(1)), findsOneWidget);

    // 再生（play_arrow）：アイコンが一時停止に変わり、fpsに合わせて
    // フレームが自動で進む。少し待ってからもう一度押して止める
    // （このプロジェクトはfps=4=250ms間隔なので、600ms待てば
    // 2ティック以上は確実に進む）。
    await tester.tap(find.byIcon(Icons.play_arrow));
    await settle();
    expect(find.byIcon(Icons.pause), findsOneWidget);
    await capture('frame_picker_playing');
    await settle(rounds: 12);
    await tester.tap(find.byIcon(Icons.pause));
    await settle();
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    // 自動再生で先頭から進んでいるはずなので、もう1枚目ではない。
    expect(find.text(l10n.widgetArtworkFrameNumberLabel(1)), findsNothing);

    // 1フレーム進む（fast_forward）も検証しておく。まず先頭へ戻して
    // 既知の位置から検証する（一時停止後の位置は再生時間依存で
    // 決定的でないため）。
    await tester.tap(find.byIcon(Icons.skip_previous));
    await settle();
    expect(find.text(l10n.widgetArtworkFrameNumberLabel(1)), findsOneWidget);
    await tester.tap(find.byIcon(Icons.fast_forward));
    await settle();
    expect(find.text(l10n.widgetArtworkFrameNumberLabel(2)), findsOneWidget);

    // シークバー（SteppedSlider）で先頭へ戻し、以降のアサートを決定的にする。
    await tester.tap(find.byKey(const ValueKey('widgetFrameStripCell0')));
    await settle();
    expect(find.text(l10n.widgetArtworkFrameNumberLabel(1)), findsOneWidget);

    // ストリップの3コマ目（インデックス2＝青）をタップ→即座に閉じず、
    // プレビューだけが差し替わることを確認する。
    await tester.tap(find.byKey(const ValueKey('widgetFrameStripCell2')));
    await capture('frame_picker_switched_to_frame3');
    // まだフレーム選択画面に留まっている（確定ボタンがまだ見えている）。
    expect(
      find.text(l10n.widgetArtworkFramePickerConfirmButton),
      findsOneWidget,
    );

    // 確定ボタンをタップ→2画面ぶん一気に閉じてウィジェット設定画面へ戻る。
    // pop()の遷移アニメーションが完全に終わり、ポップされた2画面が
    // ツリーから外れるまで十分待ってから検証する（push直後の前画面同様、
    // pop直後もアニメーション完了までは前画面がツリーに残り得るため）。
    // なお確定処理はpopの前にウィジェットの画像（作品のフレーム＋
    // ショートカット2種の意匠）を実際にPNGへ焼く。これは`toImage`と
    // ファイル書き込みという**本物の非同期処理**なので、FakeAsyncのまま
    // pumpを重ねても進まない。settleがrunAsyncで実時間を渡しているので
    // 回数を多めに取る。
    await tester.tap(find.text(l10n.widgetArtworkFramePickerConfirmButton));
    await settle(rounds: 40);
    await capture('settings_after_pick');

    final widgets = liveContext().read<HomeWidgetService>();
    expect(widgets.projectId, project.id);
    expect(widgets.sceneId, sceneId);
    expect(widgets.frameIndex, 2, reason: '3コマ目（インデックス2）を選んだはず');
    // 設定画面の要約行に作品名とフレーム番号（3枚目）が反映されている。
    expect(find.text(project.name), findsOneWidget);
    expect(find.text(l10n.widgetArtworkFrameNumberLabel(3)), findsOneWidget);
    // 「作品を選ぶ」という未選択時の文言はもう出ていない。
    expect(find.text(l10n.widgetArtworkPickButton), findsNothing);

    // ── 作品をつくるウィジェットの背景色ラジオボタン ──────────────────
    // 「色を選ぶ」（作成ウィジェット側、1つ目）をタップ→ダイアログを開き、
    // HEX欄に入力して確定する。
    final customRadios = find.text(l10n.widgetColorCustom);
    expect(customRadios, findsNWidgets(2)); // 作成・広場の2箇所ぶん
    await tester.tap(customRadios.at(0));
    await capture('color_dialog_opened');
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), '3399FF');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle();

    await tester.tap(find.byIcon(Icons.close));
    await capture('settings_after_color_pick');

    expect(widgets.followsTheme(HomeWidgetKind.create), isFalse);
    expect(widgets.backgroundColorOf(HomeWidgetKind.create), 0xFF3399FF);
    // 広場ウィジェット側は影響を受けず、テーマ追従のまま。
    expect(widgets.followsTheme(HomeWidgetKind.plaza), isTrue);

    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
