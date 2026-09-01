import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';

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

/// 主要画面を「一般的な小型Android端末相当の320論理px幅」で実際に描画し、
/// 操作の直前・直後をPNGとして build/visual-smoke/ に保存する。
///
/// 既存app_smoke_test.dartは例外検出を主目的としており、テスト画面幅が
/// 1080論理pxだったため、実機の狭いAppBarでのみ発生するRenderFlex overflowを
/// 見逃す余地があった。このテストは狭幅でのレイアウト崩れ検出と、CIでの
/// 人間によるスクリーンショット確認を補完する。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final screenshotKey = GlobalKey();
  late Directory tempDir;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appRouter.go('/');
    FilePicker.platform = _FakeFilePicker();

    tempDir = Directory.systemTemp.createTempSync('niarim_visual_smoke_');
    const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProvider, (call) async => tempDir.path);
  });

  tearDown(() {
    const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProvider, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  void useCompactPhoneSize(WidgetTester tester) {
    // 960 / DPR 3 = 320 logical px, 2160 / DPR 3 = 720 logical px.
    // 320px幅でもAppBarが崩れないことを明示的に確認する。
    tester.view.physicalSize = const Size(960, 2160);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> loadAppFonts(WidgetTester tester) async {
    await tester.runAsync(() async {
      final hakkou = FontLoader('HakkouMincho')
        ..addFont(rootBundle.load('assets/fonts/HakkouMincho.ttf'));
      final kuramubon = FontLoader('Kuramubon')
        ..addFont(rootBundle.load('assets/fonts/Kuramubon.otf'));
      final noto = FontLoader('NotoSerifJP')
        ..addFont(rootBundle.load('assets/fonts/NotoSerifJP.ttf'));
      await Future.wait([hakkou.load(), kuramubon.load(), noto.load()]);
    });
  }

  Future<void> capture(WidgetTester tester, String name) async {
    // RenderRepaintBoundary.toImage()/Image.toByteDataは実Rasterizerの非同期処理を
    // 待つため、fake-async支配下のtestWidgets本体で直接awaitすると、画面の
    // 状態によってはFutureが進まずタイムアウトする。runAsyncで実時間ゾーンへ
    // 逃がし、操作ごとの画像取得が確実に完了するようにする。
    await tester.pump(const Duration(milliseconds: 120));
    final renderObject =
        screenshotKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await renderObject.toImage(pixelRatio: 1.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data!.buffer.asUint8List();
    });
    final dir = Directory('build/visual-smoke');
    dir.createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(bytes!);
    // CIログから、どの操作まで画像化できたかを即座に特定できるようにする。
    // ignore: avoid_print
    print('visual-smoke captured: $name');
  }

  void expectNoFlutterException(WidgetTester tester, String operation) {
    final exception = tester.takeException();
    expect(exception, isNull, reason: '$operation でFlutter例外/overflow');
  }

  Future<void> boot(WidgetTester tester) async {
    useCompactPhoneSize(tester);
    await loadAppFonts(tester);
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      RepaintBoundary(
        key: screenshotKey,
        child: MultiProvider(providers: providers!, child: const NiarimApp()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expectNoFlutterException(tester, '起動画面表示');
    await capture(tester, '01_splash');
  }

  Future<void> goHome(WidgetTester tester) async {
    final create = find.byIcon(Icons.brush_outlined);
    expect(create, findsOneWidget);
    await tester.tap(create);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
    expectNoFlutterException(tester, '作品をつくる→ホーム');

    final firstLaunch = find.text('はじめる');
    if (firstLaunch.evaluate().isNotEmpty) {
      await capture(tester, '02_first_launch_dialog');
      await tester.tap(firstLaunch);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));
      expectNoFlutterException(tester, '初回案内を閉じる');
    }
    await capture(tester, '03_home_default');
  }

  testWidgets(
    '320px幅の主要ホーム操作をスクリーンショット付きで巡回しoverflowしない',
    (tester) async {
      await boot(tester);
      await goHome(tester);

      // 1. 昇順/降順切り替え。今回報告されたoverflowの直接再現ポイント。
      final down = find.byIcon(Icons.arrow_downward);
      expect(down, findsOneWidget);
      await tester.tap(down);
      await tester.pump(const Duration(milliseconds: 250));
      expectNoFlutterException(tester, '昇順/降順切り替え');
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      await capture(tester, '04_home_sort_ascending');

      // 2. 並び替え基準メニューを開く。
      final sortPopup = find.byType(PopupMenuButton<bool>);
      expect(sortPopup, findsWidgets);
      await tester.tap(sortPopup.first);
      await tester.pump(const Duration(milliseconds: 250));
      expectNoFlutterException(tester, '並び替え基準メニュー表示');
      await capture(tester, '05_home_sort_menu_open');

      final nameItem = find.text('名前');
      expect(nameItem, findsWidgets);
      await tester.tap(nameItem.last);
      await tester.pump(const Duration(milliseconds: 250));
      expectNoFlutterException(tester, '名前順へ変更');
      await capture(tester, '06_home_sort_by_name');

      // 3. 表示サイズメニュー。
      final viewMode = find.byIcon(Icons.view_module);
      expect(viewMode, findsOneWidget);
      await tester.tap(viewMode);
      await tester.pump(const Duration(milliseconds: 250));
      expectNoFlutterException(tester, '表示サイズメニュー表示');
      await capture(tester, '07_home_view_mode_menu');
      // PopupMenuRouteは通常のページではないためtester.pageBack()では閉じられない。
      // メニュー外をタップし、実機と同じdismiss操作で閉じる。
      await tester.tapAt(const Offset(8, 220));
      await tester.pump(const Duration(milliseconds: 250));
      expectNoFlutterException(tester, '表示サイズメニューを閉じる');

      // 4. 検索モード。長い入力でもAppBar内が崩れないことを確認。
      final search = find.byIcon(Icons.search);
      expect(search, findsOneWidget);
      await tester.tap(search);
      await tester.pump(const Duration(milliseconds: 250));
      expectNoFlutterException(tester, '検索モード開始');
      await capture(tester, '08_home_search_empty');
      await tester.enterText(
        find.byType(TextField).first,
        '非常に長い検索キーワードを入力してもレイアウトが壊れない確認用テキスト',
      );
      await tester.pump(const Duration(milliseconds: 250));
      expectNoFlutterException(tester, '検索文字入力');
      await capture(tester, '09_home_search_long_text');

      final closeSearch = find.byIcon(Icons.close);
      expect(closeSearch, findsOneWidget);
      await tester.tap(closeSearch);
      await tester.pump(const Duration(milliseconds: 250));
      expectNoFlutterException(tester, '検索モード終了');

      // 5. ドロワー。
      final menu = find.byIcon(Icons.menu);
      expect(menu, findsOneWidget);
      await tester.tap(menu);
      await tester.pump(const Duration(milliseconds: 300));
      expectNoFlutterException(tester, 'ホームドロワー表示');
      await capture(tester, '10_home_drawer');
      // Drawerもページではないので、画面右端のscrimをタップして閉じる。
      await tester.tapAt(const Offset(315, 360));
      await tester.pump(const Duration(milliseconds: 250));
      expectNoFlutterException(tester, 'ホームドロワーを閉じる');

      // 6. 作品一覧タブ。
      final worksTab = find.text('作品一覧');
      if (worksTab.evaluate().isNotEmpty) {
        await tester.tap(worksTab.first);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        expectNoFlutterException(tester, '作品一覧タブ切り替え');
        await capture(tester, '11_home_works_tab');
      }

      // 7. 新規プロジェクト画面。
      final scaffoldContext = tester.element(find.byType(Scaffold).first);
      GoRouter.of(scaffoldContext).push('/new-project');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));
      expectNoFlutterException(tester, '新規プロジェクト画面表示');
      await capture(tester, '12_new_project');

      // 8. 設定一覧画面。
      final currentScaffold = tester.element(find.byType(Scaffold).first);
      GoRouter.of(currentScaffold).go('/settings');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));
      expectNoFlutterException(tester, '設定一覧画面表示');
      await capture(tester, '13_settings');
    },
    timeout: const Timeout(Duration(seconds: 180)),
  );
}
