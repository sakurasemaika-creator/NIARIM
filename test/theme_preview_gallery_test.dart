import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/settings/theme_preview_gallery_screen.dart';
import 'package:niarim/screens/canvas/widgets/canvas_icon_button.dart';
import 'package:niarim/screens/settings/theme_settings_screen.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  void mockPathProvider() {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final dir = Directory.systemTemp.createTempSync('niarim_preview_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => dir.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
  }

  test('gallery contains 16 everyday screens, no tab variants or settings', () {
    final ids = themePreviewEntries.map((e) => e.id).toList();
    const expected = [
      'splash', 'projects', 'new', 'detail', 'canvas', 'timeline',
      'export', 'complete', 'save', 'materials', 'community', 'work',
      'post', 'author', 'mine', 'notifications',
    ];
    expect(ids, expected);
    expect(ids.toSet().length, ids.length);
    // Shared and Trash are existing Home tabs, not separate previews.
    expect(ids, isNot(contains('shared')));
    expect(ids, isNot(contains('trash')));
    // Settings are still present in the application but excluded here.
    for (final id in [
      'settings', 'theme', 'performance', 'gestures', 'shortcuts', 'pen',
      'bucket', 'workspace', 'pc_layout', 'transfer', 'widgets',
      'widget_art', 'widget_frame', 'watermark', 'fonts', 'storage',
      'premium', 'help', 'tips', 'autofill', 'sizes', 'license', 'privacy',
    ]) {
      expect(ids, isNot(contains(id)), reason: 'Excluded preview: $id');
    }
  });

  testWidgets('swipe gallery renders adjacent pages, then closes', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final themeService = ThemeService();
    await themeService.init();
    await tester.pumpWidget(ChangeNotifierProvider<ThemeService>.value(
      value: themeService,
      child: MaterialApp(
        locale: const Locale('ja'),
        supportedLocales: const [Locale('ja'), Locale('en')],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: themeService.themeData,
        home: const ThemePreviewGalleryScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('themePreviewPager')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('themePreviewTitle'))).data, '起動画面');
    expect(find.text('作品広場'), findsOneWidget);
    expect(find.byIcon(Icons.movie_filter_outlined), findsOneWidget);
    await tester.tap(find.byKey(const Key('themePreviewNext')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('themePreviewTitle'))).data, 'プロジェクト一覧');
    expect(find.text('作品広場'), findsNothing);
    await tester.drag(find.byKey(const Key('themePreviewPager')), const Offset(-450, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('themePreviewTitle'))).data, themePreviewEntries[2].ja);
    await tester.tap(find.byKey(const Key('themePreviewHideControls')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('themePreviewNext')), findsNothing);
    expect(find.byKey(const Key('themePreviewPager')), findsOneWidget);
    await tester.tap(find.byKey(const Key('themePreviewShowControls')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('themePreviewNext')), findsOneWidget);
    await tester.tap(find.byKey(const Key('themePreviewClose')));
    await tester.pumpAndSettle();
  });

  testWidgets('remaining previews follow active theme without settings page',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = ThemeService();
    await service.init();
    final preset = AppThemePreset.defaultLight.copyWith(
      accentColor: const Color(0xFF008B79),
      buttonTextColor: const Color(0xFF00CC11),
      textColor: const Color(0xFF112233),
    );
    service.previewCurrent(preset);
    await tester.pumpWidget(ChangeNotifierProvider<ThemeService>.value(
      value: service,
      child: Builder(builder: (context) => MaterialApp(
        locale: const Locale('ja'),
        supportedLocales: const [Locale('ja'), Locale('en')],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: context.watch<ThemeService>().themeData,
        home: const ThemePreviewGalleryScreen(),
      )),
    ));
    await tester.pumpAndSettle();

    // Splash still uses the user-selected foreground token.
    final logo = tester.widget<SvgPicture>(
      find.byKey(const Key('themePreviewSplashAppLogo')));
    expect(logo.colorFilter,
      const ColorFilter.mode(Color(0xFF00CC11), BlendMode.srcIn));

    // The next gallery page is Projects, not Shared/Trash or settings.
    await tester.tap(find.byKey(const Key('themePreviewNext')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(
      find.byKey(const Key('themePreviewTitle'))).data, 'プロジェクト一覧');
    expect(themePreviewEntries.length, 16);
    expect(service.current.accentColor, const Color(0xFF008B79));
    expect(find.byKey(const Key('themePreviewPager')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('theme settings shows live scaled preview and opens gallery', (tester) async {
    // Capture the actual Flutter rendering at a representative phone size.
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    mockPathProvider();
    await loadAppFonts(tester);
    final providers = await tester.runAsync(buildAppProviders);
    final screenshot = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: screenshot,
      child: MultiProvider(
        providers: providers!,
        child: Builder(
          builder: (context) => MaterialApp(
            locale: const Locale('ja'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: context.watch<ThemeService>().themeData,
            debugShowCheckedModeBanner: false,
            home: const ThemeSettingsScreen(),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('themePreviewOpen')), findsOneWidget);
    expect(find.byKey(const Key('themeInlinePreview')), findsOneWidget);
    // The miniature is real Flutter content, not a fixed picture.
    expect(find.text('プロジェクトがありません'), findsOneWidget);
    expect(tester.takeException(), isNull);

    Future<void> saveCapture(String name) async {
      final boundary = screenshot.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return data!.buffer.asUint8List();
      });
      final output = Directory('build/theme-inline-preview')
        ..createSync(recursive: true);
      await tester.runAsync(() => File(
        '${output.path}/$name',
      ).writeAsBytes(bytes!));
    }

    await saveCapture('theme_settings_default.png');

    final themeService = Provider.of<ThemeService>(
      tester.element(find.byKey(const Key('themeInlinePreview'))),
      listen: false,
    );
    final captureDefaultTheme = themeService.current;
    final before = Theme.of(tester.element(
      find.byKey(const Key('themeInlinePreview')))).colorScheme.primary;
    themeService.previewCurrent(themeService.current.copyWith(
      accentColor: const Color(0xFF008B79),
    ));
    await tester.pumpAndSettle();
    final after = Theme.of(tester.element(
      find.byKey(const Key('themeInlinePreview')))).colorScheme.primary;
    expect(after, isNot(before));
    expect(find.byKey(const Key('themeInlinePreview')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await saveCapture('theme_settings_accent_changed.png');

    // All-route screenshots use the default light theme. Reset the sample
    // before gallery captures so comparisons reflect layout differences,
    // rather than unrelated accent-color differences.
    themeService.previewCurrent(captureDefaultTheme);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('themePreviewOpen')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('themePreviewPager')), findsOneWidget);

    // Capture each full-screen live Flutter gallery page for a human-readable
    // visual PDF. These are real rendered frames reached through the preview
    // button, not illustrations or the embedded miniature preview.
    for (var i = 0; i < themePreviewEntries.length; i++) {
      if (i > 0) {
        await tester.tap(find.byKey(const Key('themePreviewNext')));
        await tester.pumpAndSettle();
      }
      expect(tester.widget<Text>(
        find.byKey(const Key('themePreviewTitle'))).data,
        themePreviewEntries[i].ja);
      await saveCapture(
        'theme_gallery_${(i + 1).toString().padLeft(2, '0')}_${themePreviewEntries[i].id}.png',
      );
      expect(tester.takeException(), isNull);
    }

    await tester.tap(find.byKey(const Key('themePreviewClose')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('themeInlinePreview')), findsOneWidget);
  });

  testWidgets('static gallery uses landscape paper and no scrollable mock data',
      (tester) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final service = ThemeService();
    await service.init();
    await tester.pumpWidget(ChangeNotifierProvider<ThemeService>.value(
      value: service,
      child: MaterialApp(
        locale: const Locale('ja'),
        supportedLocales: const [Locale('ja'), Locale('en')],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: service.themeData,
        home: const ThemePreviewGalleryScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    final pages = tester.widget<PageView>(find.byKey(
      const Key('themePreviewPager')));
    Future<void> visit(String id) async {
      final index = themePreviewEntries.indexWhere((e) => e.id == id);
      expect(index, greaterThanOrEqualTo(0));
      pages.controller!.jumpToPage(index);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: id);
    }

    await visit('new');
    final mockList = tester.widget<ListView>(
      find.byKey(const Key('themePreviewContentList')));
    expect(mockList.physics, isA<NeverScrollableScrollPhysics>());
    expect(find.byKey(const Key('themePreviewMockName')), findsOneWidget);
    expect(find.byKey(const Key('themePreviewMockSizes')), findsOneWidget);

    await visit('detail');
    final detailPaper = tester.getSize(
      find.byKey(const Key('themePreviewFakeProjectCanvas')));
    expect(detailPaper.width / detailPaper.height, closeTo(16 / 9, 0.05));
    expect(find.text('0.1s'), findsOneWidget);
    expect(find.text('2/12'), findsOneWidget);
    expect(find.text('1.0s'), findsOneWidget);
    final detailCurrent = tester.getRect(
      find.byKey(const Key('themePreviewDetailCurrentSeconds')));
    final detailTotal = tester.getRect(
      find.byKey(const Key('themePreviewDetailTotalSeconds')));
    final detailCount = tester.getRect(
      find.byKey(const Key('themePreviewDetailFrameCounter')));
    final detailLoop = tester.getRect(
      find.byKey(const Key('themePreviewDetailLoopButton')));
    final detailSeek = tester.getRect(
      find.byKey(const Key('themePreviewDetailSeekBar')));
    final detailImage = tester.getRect(
      find.byKey(const Key('themePreviewFakeProjectCanvas')));
    expect(detailCurrent.left, lessThan(detailCount.left));
    expect(detailCount.right, lessThan(detailLoop.left));
    expect(detailLoop.right, lessThan(detailTotal.left));
    expect(detailCurrent.top, greaterThan(detailImage.bottom));
    expect(detailCurrent.bottom, lessThanOrEqualTo(detailSeek.top));
    // Seconds retain their edge positions; all three intervening gaps
    // between the four items must be equal (not equal-sized cells).
    final gap1 = detailCount.left - detailCurrent.right;
    final gap2 = detailLoop.left - detailCount.right;
    final gap3 = detailTotal.left - detailLoop.right;
    expect(gap2, closeTo(gap1, 2));
    expect(gap3, closeTo(gap1, 2));

    await visit('canvas');
    final canvasPaper = tester.getSize(
      find.byKey(const Key('themePreviewCanvasPaper')));
    expect(canvasPaper.width / canvasPaper.height, closeTo(16 / 9, 0.05));
    final canvasScaffold = tester.widget<Scaffold>(
      find.byKey(const Key('themePreviewCanvasScaffold')));
    final canvasViewport = tester.widget<Container>(
      find.byKey(const Key('themePreviewCanvasViewport')));
    final canvasStrip = tester.widget<Container>(
      find.byKey(const Key('themePreviewCanvasFrameStrip')));
    expect(canvasScaffold.backgroundColor,
      Theme.of(tester.element(
        find.byKey(const Key('themePreviewCanvasScaffold'))))
          .colorScheme.surfaceContainerHighest);
    expect(canvasViewport.color, canvasScaffold.backgroundColor);
    expect(canvasStrip.color, Colors.transparent);
    // Background remains clear, but text and icons keep their actual
    // eight-direction glyph outlines, including non-tool status controls.
    final undoIcon = tester.widget<Icon>(find.byIcon(Icons.undo));
    expect(undoIcon.shadows, hasLength(8));
    final opacityLabel = tester.widget<Text>(find.text('100%'));
    expect(opacityLabel.style?.shadows, hasLength(8));
    final gripIcons = tester.widgetList<Icon>(
      find.byIcon(Icons.keyboard_arrow_down)).toList();
    expect(gripIcons.length, greaterThanOrEqualTo(2));
    expect(gripIcons.every((icon) => icon.shadows?.length == 8), isTrue);
    final canvasSwatch = tester.widget<Container>(
      find.byKey(const Key('themePreviewCanvasColorSwatch')));
    final swatchDecoration = canvasSwatch.decoration! as BoxDecoration;
    final colorScheme = Theme.of(tester.element(
      find.byKey(const Key('themePreviewCanvasScaffold')))).colorScheme;
    expect((swatchDecoration.border! as Border).top.color,
      CanvasIconButton.outlineColor(Colors.black, colorScheme));
    final timelineSwitch = find.byKey(
      const Key('themePreviewCanvasTimelineButton'));
    expect(timelineSwitch, findsOneWidget);
    expect(find.descendant(of: timelineSwitch,
      matching: find.byIcon(Icons.movie_filter_outlined)), findsOneWidget);
    expect(find.descendant(of: timelineSwitch,
      matching: find.byIcon(Icons.arrow_forward)), findsOneWidget);
    final timelineArrow = tester.widget<Icon>(find.descendant(
      of: timelineSwitch, matching: find.byIcon(Icons.arrow_forward)));
    expect(timelineArrow.shadows, hasLength(8));

    await visit('timeline');
    final timelinePaper = tester.getSize(
      find.byKey(const Key('themePreviewTimelinePaper')));
    expect(timelinePaper.width / timelinePaper.height, closeTo(16 / 9, 0.05));
    expect(find.byKey(const Key('themePreviewTimelineTracks')),
      findsOneWidget);
    // Every material kind must be visible in the first static viewport,
    // without creating a project or scrolling.
    for (var i = 0; i < 9; i++) {
      final kind = find.byKey(Key('themePreviewMaterialTrack$i'));
      expect(kind, findsOneWidget);
      expect(tester.getBottomLeft(kind).dy,
        lessThan(tester.getTopLeft(
          find.byKey(const Key('themePreviewClose'))).dy),
        reason: 'Material $i must appear above gallery navigation');
      final label = tester.widget<Text>(
        find.descendant(of: kind, matching: find.byType(Text)).first);
      expect(label.style?.fontFamily, 'Kuramubon',
        reason: 'Material track label $i must use Kuramubon');
    }
    expect(find.byKey(const Key('themePreviewLoopButton')), findsOneWidget);
    expect(find.byKey(const Key('themePreviewFrameCounter')), findsOneWidget);
    expect(find.text('10/100'), findsOneWidget);
    final handle = tester.getCenter(
      find.byKey(const Key('themePreviewResizeGrip')));
    final currentRect = tester.getRect(
      find.byKey(const Key('themePreviewCurrentSeconds')));
    final totalRect = tester.getRect(
      find.byKey(const Key('themePreviewTotalSeconds')));
    final firstRect = tester.getRect(
      find.byKey(const Key('themePreviewSkipPrevious')));
    final lastRect = tester.getRect(
      find.byKey(const Key('themePreviewSkipNext')));
    expect(currentRect.right, lessThanOrEqualTo(firstRect.left + 1));
    expect(totalRect.left, greaterThanOrEqualTo(lastRect.right - 1));
    expect((currentRect.center.dy - firstRect.center.dy).abs(), lessThan(12));
    expect((totalRect.center.dy - lastRect.center.dy).abs(), lessThan(12));
    expect(currentRect.center.dy, greaterThan(handle.dy + 10));
    expect(totalRect.center.dy, greaterThan(handle.dy + 10));
    expect(find.byIcon(Icons.repeat), findsOneWidget);

    await visit('export');
    for (final label in ['プリセット', '標準', '高画質', 'カスタム',
      '形式', 'MP4', 'GIF', '透過WebM', 'AVI']) {
      final text = tester.widget<Text>(find.text(label));
      expect(text.style?.fontFamily, 'Kuramubon',
        reason: 'Export field $label must use Kuramubon');
    }

    await visit('community');
    final communityAuthors = tester.widgetList<Text>(
      find.text('サンプル作者')).toList();
    expect(communityAuthors, isNotEmpty);
    for (final name in communityAuthors) {
      expect(name.style?.fontFamily, 'Kuramubon');
    }
    await visit('author');
    final authorLabels = tester.widgetList<Text>(
      find.text('サンプル作者')).toList();
    expect(authorLabels, isNotEmpty);
    for (final name in authorLabels) {
      expect(name.style?.fontFamily, 'Kuramubon');
    }
  });

  testWidgets('gallery works at narrow 320px portrait width', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final themeService = ThemeService();
    await themeService.init();
    await tester.pumpWidget(ChangeNotifierProvider<ThemeService>.value(
      value: themeService,
      child: MaterialApp(
        locale: const Locale('ja'),
        supportedLocales: const [Locale('ja'), Locale('en')],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: themeService.themeData,
        home: const ThemePreviewGalleryScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    // Cover every registered independent screen, not only the first dozen.
    for (var i = 1; i < themePreviewEntries.length; i++) {
      await tester.tap(find.byKey(const Key('themePreviewNext')));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(
        find.byKey(const Key('themePreviewTitle'))).data,
        themePreviewEntries[i].ja);
      expect(tester.takeException(), isNull);
    }
  });
}
