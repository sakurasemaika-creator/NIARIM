import 'dart:io';
import 'dart:math' as math;
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
import 'package:niarim/models/audio_clip.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/widgets/onion_skin_panel.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/advertising_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/ad_banner_widget.dart';
import 'package:niarim/widgets/ad_banner_mock_widget.dart';

// Reference screenshots intentionally show a paid-member layout. Production
// PremiumService rightly rejects editable local flags, so this test supplies
// an explicit in-memory preview fixture rather than bypassing Play checks.
class _ScreenshotPremiumService extends PremiumService {
  @override
  bool get isPremium => true;
}

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

/// Frames of the bouncing ball drawn into the captured project.
const int _artFrames = 5;

/// Draws frame [i] of a short bouncing-ball animation (top, falling, squashed
/// on the ground, rising, top) on a [width]×[height] transparent canvas, so
/// the published captures show artwork instead of an empty canvas.
void _drawBounceFrame(Canvas c, int width, int height, int i) {
  final w = width.toDouble();
  final h = height.toDouble();
  final s = math.min(w, h) / 1080.0;
  const ink = Color(0xFF2B2A3A);
  final groundY = h * 0.82;
  final line = Paint()
    ..color = ink
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  // The ground: a gently uneven hand-drawn line with a few tufts.
  c.drawPath(
    Path()
      ..moveTo(w * 0.05, groundY + 2 * s)
      ..cubicTo(
        w * 0.32,
        groundY - 7 * s,
        w * 0.62,
        groundY + 7 * s,
        w * 0.95,
        groundY - 2 * s,
      ),
    line..strokeWidth = 7 * s,
  );
  for (final fx in const [0.12, 0.47, 0.86]) {
    final x = w * fx;
    for (final dx in const [-14.0, 0.0, 14.0]) {
      c.drawLine(
        Offset(x + dx * s, groundY - 2 * s),
        Offset(x + dx * 1.6 * s, groundY - (dx == 0 ? 30 : 20) * s),
        line..strokeWidth = 5 * s,
      );
    }
  }

  const lifts = [1.0, 0.36, 0.0, 0.36, 1.0];
  const scales = [
    (1.0, 1.0),
    (0.9, 1.14),
    (1.3, 0.74),
    (0.9, 1.14),
    (1.0, 1.0),
  ];
  final t = i / (_artFrames - 1);
  // Kept inside the middle square, which the timeline's frame cells show.
  final r = 135 * s;
  final x = w * (0.28 + 0.44 * t);
  final lift = (h * 0.42) * lifts[i];
  final (sx, sy) = scales[i];
  final cy = groundY - r * sy - lift;

  // The shadow grows and darkens as the ball comes down.
  final near = 1 - lifts[i];
  c.drawOval(
    Rect.fromCenter(
      center: Offset(x, groundY + 6 * s),
      width: r * (1.3 + 0.9 * near) * (i == 2 ? 1.25 : 1),
      height: 26 * s,
    ),
    Paint()..color = ink.withValues(alpha: 0.10 + 0.12 * near),
  );

  // Speed lines behind the moving ball, impact marks on the ground.
  final speed = Paint()
    ..color = ink.withValues(alpha: 0.5)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 6 * s;
  if (i == 1 || i == 3) {
    final up = i == 1 ? -1.0 : 1.0;
    for (var k = -1; k <= 1; k++) {
      final from = Offset(x - r * 1.25, cy + k * r * 0.45 + up * r * 0.35);
      c.drawLine(from, from + Offset(-r * 0.8, up * r * 0.55), speed);
    }
  } else if (i == 2) {
    for (final side in const [-1.0, 1.0]) {
      for (var k = 0; k < 3; k++) {
        final angle = (0.25 + 0.22 * k) * math.pi;
        final dir = Offset(side * math.cos(angle), -math.sin(angle));
        final start = Offset(x + side * r * 1.45, groundY - 8 * s);
        c.drawLine(start + dir * 18 * s, start + dir * 62 * s, speed);
      }
    }
  }

  // The ball: coral with a cream band that turns as it travels.
  c.save();
  c.translate(x, cy);
  c.scale(sx, sy);
  final ball = Rect.fromCircle(center: Offset.zero, radius: r);
  c.drawCircle(
    Offset.zero,
    r,
    Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.35, -0.4),
        radius: 1.0,
        colors: [Color(0xFFFF8A73), Color(0xFFE5483D)],
      ).createShader(ball),
  );
  c.save();
  c.clipPath(Path()..addOval(ball));
  c.rotate(-0.5 + t * math.pi * 1.1);
  c.drawRect(
    Rect.fromCenter(center: Offset.zero, width: r * 2.4, height: r * 0.5),
    Paint()..color = const Color(0xFFFFE6A6),
  );
  c.drawLine(
    Offset(-r * 1.2, -r * 0.25),
    Offset(r * 1.2, -r * 0.25),
    line..strokeWidth = 4 * s,
  );
  c.drawLine(
    Offset(-r * 1.2, r * 0.25),
    Offset(r * 1.2, r * 0.25),
    line..strokeWidth = 4 * s,
  );
  c.restore();
  c.drawOval(
    Rect.fromCenter(
      center: Offset(-r * 0.38, -r * 0.45),
      width: r * 0.42,
      height: r * 0.26,
    ),
    Paint()..color = const Color(0xB3FFFFFF),
  );
  c.drawCircle(Offset.zero, r, line..strokeWidth = 8 * s / ((sx + sy) / 2));
  c.restore();
}

/// Frame [i] as premultiplied RGBA, the format a layer's pixels use.
Future<Uint8List> _bounceFramePixels(int width, int height, int i) async {
  final recorder = ui.PictureRecorder();
  _drawBounceFrame(Canvas(recorder), width, height, i);
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// A small PNG of frame [i] on white paper, for the saved slot's thumbnail.
Future<Uint8List> _bounceThumbnail(int width, int height, int i) async {
  final scale = 200 / math.max(width, height);
  final tw = (width * scale).round();
  final th = (height * scale).round();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(
      Rect.fromLTWH(0, 0, tw.toDouble(), th.toDouble()),
      Paint()..color = const Color(0xFFFFFFFF),
    )
    ..scale(scale);
  _drawBounceFrame(canvas, width, height, i);
  final image = await recorder.endRecording().toImage(tw, th);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final screenshotKey = GlobalKey();
  late Directory tempDir;

  setUp(() {
    SharedPreferences.setMockInitialValues({'is_premium': true});
    appRouter.go('/');
    FilePicker.platform = _FakeFilePicker();
    tempDir = Directory.systemTemp.createTempSync('niarim_web_reference_v2_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => tempDir.path);
  });

  tearDown(() {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  void useReferencePhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(960, 1707);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> loadFonts(WidgetTester tester) async {
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
        loadFamily('FontAwesomeSolid', 'fa-solid-900.ttf'),
        loadFamily('FontAwesomeRegular', 'fa-regular-400.ttf'),
        loadFamily('FontAwesomeBrands', 'fa-brands-400.ttf'),
        loadSdkMaterialIcons(),
      ]);
    });
  }

  AppThemePreset webReferenceTheme(String name) {
    const themes = <String, AppThemePreset>{
      '01_canvas_default': AppThemePreset(
        id: 'web_canvas',
        name: 'Web Canvas',
        accentColor: Color(0xFF3AA6FF),
        textColor: Color(0xFF16232E),
        buttonTextColor: Color(0xFFFFFFFF),
        menuTextColor: Color(0xFF16232E),
        selectionTextColor: Color(0xFFFFFFFF),
        panelBgColor: Color(0xFFF1F7FC),
        menuBgColor: Color(0xFFFFFFFF),
        selectionColor: Color(0xFF3AA6FF),
        updateMarkColor: Color(0xFF7C4DFF),
      ),
      '04_timeline_default': AppThemePreset(
        id: 'web_timeline',
        name: 'Web Timeline',
        accentColor: Color(0xFFF2B90F),
        textColor: Color(0xFF2E2A12),
        buttonTextColor: Color(0xFF17161C),
        menuTextColor: Color(0xFF2E2A12),
        selectionTextColor: Color(0xFF17161C),
        panelBgColor: Color(0xFFFFFBEA),
        menuBgColor: Color(0xFFFFFFFF),
        selectionColor: Color(0xFFF2B90F),
        updateMarkColor: Color(0xFFFF8A3D),
      ),
      '02_canvas_layer_panel': AppThemePreset(
        id: 'web_layers',
        name: 'Web Layers',
        accentColor: Color(0xFFB15CFF),
        textColor: Color(0xFF2B2033),
        buttonTextColor: Color(0xFFFFFFFF),
        menuTextColor: Color(0xFF2B2033),
        selectionTextColor: Color(0xFFFFFFFF),
        panelBgColor: Color(0xFFF8F1FC),
        menuBgColor: Color(0xFFFFFFFF),
        selectionColor: Color(0xFFB15CFF),
        updateMarkColor: Color(0xFFFF7EB3),
      ),
      '03_canvas_onion_skin': AppThemePreset(
        id: 'web_onion',
        name: 'Web Onion',
        accentColor: Color(0xFF10B981),
        textColor: Color(0xFF13291F),
        buttonTextColor: Color(0xFFFFFFFF),
        menuTextColor: Color(0xFF13291F),
        selectionTextColor: Color(0xFFFFFFFF),
        panelBgColor: Color(0xFFECFAF4),
        menuBgColor: Color(0xFFFFFFFF),
        selectionColor: Color(0xFF10B981),
        updateMarkColor: Color(0xFFF2B90F),
      ),
      '05_timeline_audio_editor': AppThemePreset(
        id: 'web_audio',
        name: 'Web Audio',
        accentColor: Color(0xFFFF8A3D),
        textColor: Color(0xFF2E2013),
        buttonTextColor: Color(0xFF17161C),
        menuTextColor: Color(0xFF2E2013),
        selectionTextColor: Color(0xFF17161C),
        panelBgColor: Color(0xFFFFF6EE),
        menuBgColor: Color(0xFFFFFFFF),
        selectionColor: Color(0xFFFF8A3D),
        updateMarkColor: Color(0xFFFF5C7A),
      ),
      '06_save_tree': AppThemePreset(
        id: 'web_save',
        name: 'Web Save',
        accentColor: Color(0xFF5C6BFF),
        textColor: Color(0xFF1E2033),
        buttonTextColor: Color(0xFFFFFFFF),
        menuTextColor: Color(0xFF1E2033),
        selectionTextColor: Color(0xFFFFFFFF),
        panelBgColor: Color(0xFFF3F3FC),
        menuBgColor: Color(0xFFFFFFFF),
        selectionColor: Color(0xFF5C6BFF),
        updateMarkColor: Color(0xFF90CAF9),
      ),
      '08_workspace': AppThemePreset(
        id: 'web_workspace',
        name: 'Web Workspace',
        accentColor: Color(0xFFD8A0A6),
        textColor: Color(0xFF2E2325),
        buttonTextColor: Color(0xFF17161C),
        menuTextColor: Color(0xFF2E2325),
        selectionTextColor: Color(0xFF17161C),
        panelBgColor: Color(0xFFFAF2F2),
        menuBgColor: Color(0xFFFFFFFF),
        selectionColor: Color(0xFFD8A0A6),
        updateMarkColor: Color(0xFF8FB89D),
      ),
      '07_export': AppThemePreset(
        id: 'web_export',
        name: 'Web Export',
        accentColor: Color(0xFF8DA9C4),
        textColor: Color(0xFF212B33),
        buttonTextColor: Color(0xFF17161C),
        menuTextColor: Color(0xFF212B33),
        selectionTextColor: Color(0xFF17161C),
        panelBgColor: Color(0xFFF1F5F9),
        menuBgColor: Color(0xFFFFFFFF),
        selectionColor: Color(0xFF8DA9C4),
        updateMarkColor: Color(0xFFFF7EB3),
      ),
    };
    return themes[name] ?? AppThemePreset.defaultLight;
  }

  const webCaptureAccents = <Color>[
    Color(0xFF3AA6FF),
    Color(0xFFF2B90F),
    Color(0xFFB15CFF),
    Color(0xFF10B981),
    Color(0xFFFF8A3D),
    Color(0xFF5C6BFF),
    Color(0xFFD8A0A6),
    Color(0xFF8DA9C4),
    Color(0xFFE85D75),
    Color(0xFF00A6A6),
    Color(0xFFCA7A18),
    Color(0xFF7A6FF0),
    Color(0xFF2E9B4F),
    Color(0xFFD45AA6),
    Color(0xFF567D46),
    Color(0xFFEF6C57),
    Color(0xFF4B8FDC),
    Color(0xFFA46B3C),
    Color(0xFF8E62B6),
    Color(0xFF2F9D8F),
    Color(0xFFC15F35),
    Color(0xFF6678B8),
    Color(0xFFB36B86),
    Color(0xFF6F8F3D),
    Color(0xFF0086C9),
    Color(0xFFE08B00),
    Color(0xFF9A4FD0),
    Color(0xFF00A36C),
    Color(0xFFE65F2B),
    Color(0xFF485CC7),
    Color(0xFFC76C8A),
    Color(0xFF607D2D),
    Color(0xFF00796B),
    Color(0xFFAD5A00),
    Color(0xFF6D5BD0),
    Color(0xFFB04A72),
  ];

  int webCaptureBaseIndex(String name) {
    const names = <String>[
      '01_canvas_default',
      '02_canvas_layer_panel',
      '03_canvas_onion_skin',
      '04_timeline_default',
      '05_timeline_audio_editor',
      '06_save_tree',
      '07_export',
      '08_workspace',
      '09_widget',
    ];
    return names.indexOf(name);
  }

  /// Lets the real asynchronous work (layer compositing, thumbnails, image
  /// files) finish between frames; the fake clock alone never completes it.
  Future<void> settleAsync(WidgetTester tester, {int rounds = 6}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    // Image files (saved thumbnails) decode only with real time.
    for (final element in find.byType(Image).evaluate().toList()) {
      final image = (element.widget as Image).image;
      if (image is FileImage ||
          (image is ResizeImage && image.imageProvider is FileImage)) {
        await tester.runAsync(() => precacheImage(image, element));
      }
    }
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> capture(WidgetTester tester, String name) async {
    final appContext = tester.element(find.byType(NiarimApp));
    final premium = appContext.read<PremiumService>();
    final ads = appContext.read<AdvertisingService>();
    expect(
      premium.isPremium,
      isTrue,
      reason: 'Web reference capture must use paid-member UI',
    );
    expect(
      ads.shouldShowAds,
      isFalse,
      reason:
          'Paid-member web reference capture must not reserve or request ads',
    );

    final baseIndex = webCaptureBaseIndex(name);
    expect(
      baseIndex,
      isNonNegative,
      reason: 'Every web capture needs a stable unique-theme index',
    );
    final baseTheme = webReferenceTheme(name);
    for (var variant = 0; variant < 4; variant++) {
      final accent = webCaptureAccents[baseIndex * 4 + variant];
      // Every published variant is a genuinely re-themed app capture. Tint
      // the large surfaces as well as the accent so the screenshot visibly
      // belongs to the matching Web frame instead of looking pink/default.
      final surfaceTint = Color.alphaBlend(
        accent.withValues(alpha: 0.12),
        const Color(0xFFFFFFFF),
      );
      final panelTint = Color.alphaBlend(
        accent.withValues(alpha: 0.08),
        const Color(0xFFFFFFFF),
      );
      final theme = baseTheme.copyWith(
        id: '${baseTheme.id}_v${variant + 1}',
        name: '${baseTheme.name} ${variant + 1}',
        accentColor: accent,
        selectionColor: accent,
        panelBgColor: panelTint,
        menuBgColor: surfaceTint,
        updateMarkColor: accent,
      );
      appContext.read<ThemeService>().restoreCurrent(theme);
      // AnimatedTheme begins its color interpolation on the first pump.
      // Capturing on that same frame leaked the PREVIOUS variant's accent:
      // the first layer screenshot was green while its frame was orange.
      // Advance a separate settled frame before encoding either SP or PC.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await settleAsync(tester);
      final displayedTheme = Theme.of(
        tester.element(find.byType(Scaffold).first),
      );
      expect(
        displayedTheme.colorScheme.primary,
        accent,
        reason:
            'Captured app theme must match the website frame for $name variant ${variant + 1}',
      );

      expect(find.byType(AdBannerWidget, skipOffstage: false), findsNothing);
      expect(
        find.byType(AdBannerMockWidget, skipOffstage: false),
        findsNothing,
      );
      expect(
        find.byKey(
          const Key('persistent-horizontal-ad-mock'),
          skipOffstage: false,
        ),
        findsNothing,
      );

      Future<Uint8List> renderPng(double scale) async {
        final boundary =
            screenshotKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        return (await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: scale);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          return data!.buffer.asUint8List();
        }))!;
      }

      final dir = Directory('build/visual-smoke')..createSync(recursive: true);
      final suffix = variant == 0 ? '' : '_v${variant + 1}';
      // SP is rendered at the actual 320x569 logical screen, but saved at
      // retina resolution for legible website zooming.
      final phoneBytes = await renderPng(2.0);
      File('${dir.path}/webref_$name$suffix.png').writeAsBytesSync(phoneBytes);

      // Capture the EXACT same Flutter route/palette at PC/DeX width, not an
      // enlarged smartphone screenshot or a CSS approximation.
      final phonePhysicalSize = tester.view.physicalSize;
      final phoneDevicePixelRatio = tester.view.devicePixelRatio;
      try {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        await tester.pump(const Duration(milliseconds: 300));
        await settleAsync(tester);
        final pcBytes = await renderPng(1.0);
        File(
          '${dir.path}/webref_pc_$name$suffix.png',
        ).writeAsBytesSync(pcBytes);
      } finally {
        tester.view.physicalSize = phonePhysicalSize;
        tester.view.devicePixelRatio = phoneDevicePixelRatio;
        await tester.pump(const Duration(milliseconds: 300));
      }
      // ignore: avoid_print
      print(
        'web-reference SP + PC: $name$suffix accent=${accent.toARGB32().toRadixString(16)}',
      );
    }
  }

  void expectClean(WidgetTester tester, String operation) {
    final exception = tester.takeException();
    expect(
      exception,
      isNull,
      reason: '$operation でFlutter例外/overflow: $exception',
    );
  }

  void consumeKnownTimelineOverflow(WidgetTester tester) {
    final exception = tester.takeException();
    if (exception == null) return;
    if (!exception.toString().contains(
      'RenderFlex overflowed by 24 pixels on the right',
    )) {
      fail('Timelineで想定外のFlutter例外: $exception');
    }
  }

  Future<void> bootToHome(WidgetTester tester) async {
    useReferencePhone(tester);
    await loadFonts(tester);
    final providers = await tester.runAsync(buildAppProviders);
    final premiumPreview = _ScreenshotPremiumService();
    addTearDown(premiumPreview.dispose);
    final screenshotProviders = providers!.map((provider) {
      if (provider is ChangeNotifierProvider<PremiumService>) {
        return ChangeNotifierProvider<PremiumService>.value(
          value: premiumPreview,
        );
      }
      return provider;
    }).toList();
    await tester.pumpWidget(
      RepaintBoundary(
        key: screenshotKey,
        child: MultiProvider(
          providers: screenshotProviders,
          child: const NiarimApp(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expectClean(tester, '起動');
    await tester.tap(find.byIcon(Icons.brush_outlined));
    await tester.pump(const Duration(milliseconds: 700));
    expectClean(tester, '作品をつくる→ホーム');
    final firstLaunch = find.byKey(const Key('tutorialSkip'));
    if (firstLaunch.evaluate().isNotEmpty) {
      await tester.tap(firstLaunch);
      await tester.pump(const Duration(milliseconds: 700));
      expectClean(tester, '初回案内を閉じる');
    }
  }

  Future<void> dragIntoView(WidgetTester tester, Finder target) async {
    expect(target, findsWidgets);
    final viewport = find.byType(SingleChildScrollView).first;
    expect(viewport, findsOneWidget);
    await tester.dragUntilVisible(
      target.first,
      viewport,
      const Offset(0, -320),
      maxIteration: 12,
    );
    await tester.pump(const Duration(milliseconds: 180));
  }

  Future<void> tapVisible(WidgetTester tester, Finder target) async {
    expect(target, findsWidgets);
    await tester.tap(target.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 350));
  }

  /// Draws the bouncing ball into the first frames and keeps one manual save
  /// of it, so the canvas, layers, onion skin, timeline and saves show work.
  Future<void> seedArtwork(
    WidgetTester tester,
    ({String projectId, String sceneId}) ids,
  ) async {
    final context = tester.element(find.byType(Scaffold).first);
    final ps = context.read<ProjectService>();
    final tm = ps.tileManagerOf(ids.projectId);
    final width = tm.canvasWidth;
    final height = tm.canvasHeight;
    int frameCount() => ps
        .scenesOf(ids.projectId)
        .firstWhere((scene) => scene.id == ids.sceneId)
        .frames
        .length;
    while (frameCount() < _artFrames) {
      ps.addFrame(ids.projectId, ids.sceneId);
    }
    for (var i = 0; i < _artFrames; i++) {
      final pixels = (await tester.runAsync(
        () => _bounceFramePixels(width, height, i),
      ))!;
      final layer = ps
          .layersOf(ids.projectId, ids.sceneId, i)
          .firstWhere((layer) => layer.type == LayerType.normal);
      ps.replaceLayerPixels(
        projectId: ids.projectId,
        sceneId: ids.sceneId,
        frameIndex: i,
        layerId: layer.id,
        pixels: pixels,
      );
    }
    await tester.runAsync(() => ps.renameProject(ids.projectId, 'ボールのバウンド'));
    final thumbnail = (await tester.runAsync(
      () => _bounceThumbnail(width, height, 2),
    ))!;
    final project = ps.projects.firstWhere((p) => p.id == ids.projectId);
    await tester.runAsync(
      () => context.read<SaveTreeService>().saveToSlot(
        projectId: ids.projectId,
        slotIndex: 0,
        project: project,
        scenes: ps.scenesOf(ids.projectId),
        tileManager: tm,
        comment: 'ボールのバウンド',
        thumbnailPngBytes: thumbnail,
      ),
    );
    // Show the squashed frame in the middle, so the onion skin has frames
    // on both sides.
    final middle = find.byKey(const ValueKey('frameStripCell2'));
    if (middle.evaluate().isNotEmpty) {
      await tester.tap(middle, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
    }
    await settleAsync(tester, rounds: 8);
    expectClean(tester, '絵を描き込む');
  }

  Future<({String projectId, String sceneId})> createProjectAndOpenCanvas(
    WidgetTester tester,
  ) async {
    await bootToHome(tester);
    GoRouter.of(
      tester.element(find.byType(Scaffold).first),
    ).push('/new-project');
    await tester.pump(const Duration(milliseconds: 650));
    expectClean(tester, '新規プロジェクト画面');
    final createButton = find.widgetWithText(
      FilledButton,
      '作成',
      skipOffstage: false,
    );
    await dragIntoView(tester, createButton);
    final rect = tester.getRect(createButton.first);
    final logicalHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(logicalHeight));
    await tapVisible(tester, createButton);
    await tester.pump(const Duration(milliseconds: 900));
    expectClean(tester, '作成→キャンバス');
    final ps = tester
        .element(find.byType(Scaffold).first)
        .read<ProjectService>();
    expect(ps.projects, isNotEmpty);
    final project = ps.projects.first;
    final scenes = ps.scenesOf(project.id);
    expect(scenes, isNotEmpty);
    final ids = (projectId: project.id, sceneId: scenes.first.id);
    await seedArtwork(tester, ids);
    return ids;
  }

  Future<void> tapToolbarControl(WidgetTester tester, String tooltip) async {
    final target = find.byTooltip(tooltip, skipOffstage: false);
    expect(target, findsWidgets);
    final realTarget = target.last;
    await tester.ensureVisible(realTarget);
    await tester.pump(const Duration(milliseconds: 180));
    await tester.tap(realTarget, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 350));
  }

  Future<void> closeOverlay(WidgetTester tester) async {
    final close = find.byIcon(Icons.close, skipOffstage: false);
    expect(close, findsWidgets);
    await tester.tap(close.last, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 350));
    expectClean(tester, 'オーバーレイを閉じる');
  }

  Future<void> openTimeline(
    WidgetTester tester, {
    required String projectId,
  }) async {
    // The production canvas no longer exposes a text-labelled "タイムライン"
    // control in every layout. Navigation itself is the stable contract used
    // by the real button (context.go('/timeline/<projectId>')), so reference
    // capture should not depend on a presentation label.
    GoRouter.of(
      tester.element(find.byType(Scaffold).first),
    ).go('/timeline/$projectId');
    await tester.pump(const Duration(milliseconds: 700));
    consumeKnownTimelineOverflow(tester);
    // The frame thumbnails are drawn one by one with real time.
    await settleAsync(tester, rounds: 20);
    consumeKnownTimelineOverflow(tester);
  }

  testWidgets('Web比較基準v2: Canvas / Layer / OnionSkin', (tester) async {
    await createProjectAndOpenCanvas(tester);
    await capture(tester, '01_canvas_default');

    await tapToolbarControl(tester, 'レイヤー');
    expectClean(tester, 'レイヤーパネルを開く');
    await capture(tester, '02_canvas_layer_panel');
    await closeOverlay(tester);

    final settingsEdit = find.byTooltip('設定/編集', skipOffstage: false);
    expect(settingsEdit, findsWidgets);
    await tester.tap(settingsEdit.last, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 350));
    final onion = find.ancestor(
      of: find.text('オニオンスキン', skipOffstage: false).first,
      matching: find.byType(ListTile),
    );
    expect(onion, findsOneWidget);
    await tester.ensureVisible(onion);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(onion);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
    final onionSwitch = find.descendant(
      of: find.byType(OnionSkinPanel),
      matching: find.byType(Switch),
    );
    expect(onionSwitch, findsWidgets);
    await tester.tap(onionSwitch.first);
    await tester.pump(const Duration(milliseconds: 350));
    // Close the settings so the faint previous and next frames show on the
    // canvas around the current one.
    await closeOverlay(tester);
    await settleAsync(tester, rounds: 8);
    expectClean(tester, 'オニオンスキンを開く');
    await capture(tester, '03_canvas_onion_skin');
  }, timeout: const Timeout(Duration(seconds: 180)));

  testWidgets('Web比較基準v2: Timeline / Audio編集', (tester) async {
    final ids = await createProjectAndOpenCanvas(tester);
    await openTimeline(tester, projectId: ids.projectId);
    await capture(tester, '04_timeline_default');

    // CIではOSのファイル選択UIを開けないため、永続AudioClipだけを実サービスへ投入する。
    // TimelineScreen側のローカル表示への復元は非同期かつ内部実装なので、ここでは
    // 特定ラベルの出現をCI全体の必須条件にはしない。復元できた場合だけ実UIから
    // クリップ編集シートを撮影し、できない場合も他の基準画面・厳密状態テストを続行する。
    final ps = tester
        .element(find.byType(Scaffold).first)
        .read<ProjectService>();
    ps.addAudioClip(
      ids.projectId,
      ids.sceneId,
      const AudioClip(
        id: 'webref_audio',
        label: '比較用音声',
        startFrame: 0,
        lengthFrames: 24,
        volume: 0.72,
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));
    GoRouter.of(
      tester.element(find.byType(Scaffold).first),
    ).go('/canvas/${ids.projectId}');
    await tester.pump(const Duration(milliseconds: 700));
    await openTimeline(tester, projectId: ids.projectId);
    await tester.pump(const Duration(milliseconds: 700));
    final audio = find.text('比較用音声', skipOffstage: false);
    if (audio.evaluate().isNotEmpty) {
      await tester.ensureVisible(audio.last);
      await tester.tap(audio.last, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 350));
      consumeKnownTimelineOverflow(tester);
      await capture(tester, '05_timeline_audio_editor');
    } else {
      // ignore: avoid_print
      print(
        'web-reference audio editor skipped: clip label not materialized in widget tree',
      );
    }
  }, timeout: const Timeout(Duration(seconds: 180)));

  testWidgets('Web比較基準v2: SaveTree / Export', (tester) async {
    final ids = await createProjectAndOpenCanvas(tester);
    await tapToolbarControl(tester, '保存（セーブツリー）');
    await tester.pump(const Duration(milliseconds: 550));
    expectClean(tester, 'Canvas→SaveTree');
    await capture(tester, '06_save_tree');

    GoRouter.of(
      tester.element(find.byType(Scaffold).first),
    ).go('/canvas/${ids.projectId}');
    await tester.pump(const Duration(milliseconds: 700));
    await openTimeline(tester, projectId: ids.projectId);
    GoRouter.of(
      tester.element(find.byType(Scaffold).first),
    ).push('/export/${ids.projectId}');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 600)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expectClean(tester, 'Timeline→Export');
    await capture(tester, '07_export');
  }, timeout: const Timeout(Duration(seconds: 180)));

  testWidgets('Web比較基準v2: Workspace', (tester) async {
    await bootToHome(tester);
    GoRouter.of(tester.element(find.byType(Scaffold).first)).push('/settings');
    await tester.pump(const Duration(milliseconds: 650));
    expectClean(tester, '設定画面');
    GoRouter.of(
      tester.element(find.byType(Scaffold).first),
    ).push('/settings/workspace');
    await tester.pump(const Duration(milliseconds: 650));
    expectClean(tester, '設定→Workspace');
    await capture(tester, '08_workspace');

    GoRouter.of(
      tester.element(find.byType(Scaffold).first),
    ).push('/settings/widget');
    await tester.pump(const Duration(milliseconds: 650));
    expectClean(tester, '設定→Widget');
    await capture(tester, '09_widget');
  }, timeout: const Timeout(Duration(seconds: 180)));
}
