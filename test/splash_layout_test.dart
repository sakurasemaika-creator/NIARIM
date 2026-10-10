import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/splash/splash_screen.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/line_break.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';

/// 起動画面の2つの導線ボタンが、7言語・文字サイズ1.0/1.3/2.0倍・縦画面と
/// 小さな横画面のどれでも、文言を省略せず、同じ大きさで、画面内に収まる
/// ことを確かめる（英語・仏語・西語・韓国語・中国語で「作品広場」の文言が
/// 「…」で切れ、小さな横画面では「作品をつくる」が画面外へはみ出していた）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;
  setUp(() {
    SharedPreferences.setMockInitialValues({'first_launch': false});
    tempDir = Directory.systemTemp.createTempSync('niarim_splash_layout_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  const sizes = {
    'portrait 390x844': Size(390, 844),
    'portrait 320x568': Size(320, 568),
    'landscape 568x320': Size(568, 320),
    'landscape 640x360': Size(640, 360),
  };

  testWidgets('both entry tiles show their whole label, match in size and '
      'fit the screen', (tester) async {
    await loadAppFonts(tester);
    final providers = (await tester.runAsync(buildAppProviders))!;
    final out = Directory('build/splash-layout')..createSync(recursive: true);
    final failures = <String>[];

    for (final locale in AppLocalizations.supportedLocales) {
      final code = locale.scriptCode == 'Hant'
          ? 'zh_Hant'
          : locale.languageCode;
      for (final scale in const [1.0, 1.3, 2.0]) {
        for (final entry in sizes.entries) {
          final size = entry.value;
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          final boundary = GlobalKey();
          await tester.pumpWidget(
            MultiProvider(
              providers: providers,
              child: Builder(
                builder: (context) => RepaintBoundary(
                  key: boundary,
                  child: MediaQuery(
                    data: MediaQueryData(
                      size: size,
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: MaterialApp(
                      debugShowCheckedModeBanner: false,
                      theme: context.watch<ThemeService>().themeData,
                      locale: locale,
                      supportedLocales: AppLocalizations.supportedLocales,
                      localizationsDelegates: const [
                        AppLocalizations.delegate,
                        GlobalMaterialLocalizations.delegate,
                        GlobalWidgetsLocalizations.delegate,
                        GlobalCupertinoLocalizations.delegate,
                      ],
                      home: const SplashScreen(),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          final where = '$code x$scale ${entry.key}';
          final error = tester.takeException();
          if (error != null) failures.add('$where: $error');

          final tiles = find.byType(Ink);
          if (tiles.evaluate().length != 2) {
            failures.add('$where: expected 2 tiles');
            continue;
          }
          final rects = [
            for (final element in tiles.evaluate())
              tester.getRect(find.byWidget(element.widget)),
          ];
          if ((rects[0].height - rects[1].height).abs() > 0.5 ||
              (rects[0].width - rects[1].width).abs() > 0.5) {
            failures.add('$where: tiles differ ${rects[0]} vs ${rects[1]}');
          }
          final screen = Offset.zero & size;
          for (final rect in rects) {
            if (!screen.contains(rect.topLeft) ||
                !screen.contains(rect.bottomRight - const Offset(1, 1))) {
              // 横画面は常に、縦画面も標準の文字サイズなら、スクロール
              // せずに両方のボタンが見えること。
              if (entry.key.startsWith('landscape') || scale == 1.0) {
                failures.add('$where: tile off screen $rect');
              }
            }
          }
          for (final element
              in find
                  .descendant(of: tiles, matching: find.byType(RichText))
                  .evaluate()) {
            final paragraph = element.renderObject! as RenderParagraph;
            if (paragraph.didExceedMaxLines) {
              failures.add(
                '$where: label cut "${paragraph.text.toPlainText()}"',
              );
            }
          }

          if (scale == 1.0) {
            final name = '${code}_${entry.key.replaceAll(' ', '_')}.png';
            await tester.runAsync(() async {
              final render =
                  boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await render.toImage();
              final png = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              image.dispose();
              File(
                '${out.path}/$name',
              ).writeAsBytesSync(png!.buffer.asUint8List());
            });
          }
        }
      }
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  // 監査の表示マトリクス（24幅 × スマホ/PCの高さ × 7言語 = 336通り）。
  // 各セルで例外・省略・大きさの不一致・画面外のボタンが無いことを確かめ、
  // 目視用に全セルの画像と一覧（manifest.json）を build/splash-matrix へ出す。
  testWidgets('display matrix: 24 widths x phone/PC height x 7 languages', (
    tester,
  ) async {
    await loadAppFonts(tester);
    final providers = (await tester.runAsync(buildAppProviders))!;
    final out = Directory('build/splash-matrix')..createSync(recursive: true);
    const widths = [
      320, 360, 375, 390, 430, 480, 520, 559, 560, 600, 640, 641, 700, //
      759, 760, 834, 900, 1024, 1180, 1280, 1366, 1440, 1600, 1920,
    ];
    const heights = {'sp': 844.0, 'pc': 900.0};
    final manifest = <Map<String, Object?>>[];
    final failures = <String>[];
    for (final locale in AppLocalizations.supportedLocales) {
      final code = locale.scriptCode == 'Hant'
          ? 'zh_Hant'
          : locale.languageCode;
      for (final h in heights.entries) {
        for (final w in widths) {
          final size = Size(w.toDouble(), h.value);
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          final boundary = GlobalKey();
          await tester.pumpWidget(
            MultiProvider(
              providers: providers,
              child: Builder(
                builder: (context) => RepaintBoundary(
                  key: boundary,
                  child: MaterialApp(
                    debugShowCheckedModeBanner: false,
                    theme: context.watch<ThemeService>().themeData,
                    locale: locale,
                    supportedLocales: AppLocalizations.supportedLocales,
                    localizationsDelegates: const [
                      AppLocalizations.delegate,
                      GlobalMaterialLocalizations.delegate,
                      GlobalWidgetsLocalizations.delegate,
                      GlobalCupertinoLocalizations.delegate,
                    ],
                    home: const SplashScreen(),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          final cell = '${code}_${h.key}_$w';
          final problems = <String>[];
          final error = tester.takeException();
          if (error != null) problems.add('$error');
          final tiles = find.byType(Ink).evaluate().toList();
          if (tiles.length != 2) problems.add('tiles=${tiles.length}');
          final rects = [
            for (final e in tiles) tester.getRect(find.byWidget(e.widget)),
          ];
          if (rects.length == 2 &&
              ((rects[0].width - rects[1].width).abs() > 0.5 ||
                  (rects[0].height - rects[1].height).abs() > 0.5)) {
            problems.add('tile sizes differ');
          }
          final screen = Offset.zero & size;
          for (final r in rects) {
            if (!screen.contains(r.topLeft) ||
                !screen.contains(r.bottomRight - const Offset(1, 1))) {
              problems.add('tile off screen $r');
            }
          }
          for (final e
              in find
                  .descendant(
                    of: find.byType(Ink),
                    matching: find.byType(RichText),
                  )
                  .evaluate()) {
            if ((e.renderObject! as RenderParagraph).didExceedMaxLines) {
              problems.add('label cut');
            }
          }
          await tester.runAsync(() async {
            final render =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await render.toImage(pixelRatio: 0.5);
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            image.dispose();
            File(
              '${out.path}/$cell.png',
            ).writeAsBytesSync(png!.buffer.asUint8List());
          });
          manifest.add({
            'cell': cell,
            'language': code,
            'mode': h.key,
            'width': w,
            'height': h.value,
            'orientation': w > h.value ? 'landscape' : 'portrait',
            'tiles': [
              for (final r in rects)
                [
                  r.left,
                  r.top,
                  r.width,
                  r.height,
                ].map((v) => v.round()).toList(),
            ],
            'problems': problems,
          });
          if (problems.isNotEmpty) {
            failures.add('$cell: ${problems.join(', ')}');
          }
        }
      }
    }
    File('${out.path}/manifest.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'cells': manifest.length,
        'failures': failures,
        'results': manifest,
      }),
    );
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    expect(manifest.length, 336);
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  testWidgets('screen readers get each tile as a labelled button', (
    tester,
  ) async {
    final providers = (await tester.runAsync(buildAppProviders))!;
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: const MaterialApp(
          locale: Locale('ja'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: SplashScreen(),
        ),
      ),
    );
    await tester.pump();
    final l10n = lookupAppLocalizations(const Locale('ja'));
    for (final label in [
      '${l10n.splashCommunityButtonTitle}\n${l10n.splashCommunityButtonSubtitle}',
      l10n.splashCreateButton,
    ]) {
      expect(
        tester.getSemantics(find.text(label.split('\n').first)),
        matchesSemantics(
          label: label,
          isButton: true,
          hasTapAction: true,
          isFocusable: true,
          hasFocusAction: true,
        ),
        reason: label,
      );
    }
    handle.dispose();
  });

  test('Korean words are not broken in the middle', () {
    const joiner = '\u2060';
    expect(
      keepKoreanWordsTogether('애니메이션 만들기'),
      ['애니메이션'.split('').join(joiner), '만들기'.split('').join(joiner)].join(' '),
    );
    expect(keepKoreanWordsTogether('作品をつくる'), '作品をつくる');
    expect(
      keepKoreanWordsTogether('Create an Animation'),
      'Create an Animation',
    );
    expect(keepKoreanWordsTogether(''), '');
  });
}
