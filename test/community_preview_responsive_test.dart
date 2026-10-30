import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/community/widgets/community_floating_preview.dart';
import 'package:niarim/services/community_preview_service.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'helpers/load_app_fonts.dart';

Widget previewHost(
  ThemeService theme,
  CommunityService community,
  CommunityPreviewService preview, {
  Locale locale = const Locale('fr'),
  double scale = 2,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: community),
      ChangeNotifierProvider.value(value: preview),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme.themeData,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: Stack(children: [child!, const CommunityFloatingPreview()]),
      ),
      home: const Scaffold(),
    ),
  );
}

void main() {
  testWidgets(
    'narrow preview remains inside viewport with reachable controls',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final theme = ThemeService();
      await theme.init();
      final community = CommunityService();
      final preview = CommunityPreviewService();
      addTearDown(theme.dispose);
      addTearDown(community.dispose);
      addTearDown(preview.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      preview.show(community.discoverableWorks.first);
      await tester.pumpWidget(previewHost(theme, community, preview));
      await tester.pumpAndSettle();
      final panel = find.byWidgetPredicate(
        (w) => w is Material && w.elevation == 10,
      );
      final rect = tester.getRect(panel);
      expect(rect.right, lessThanOrEqualTo(320));
      for (final button
          in find
              .descendant(of: panel, matching: find.byType(IconButton))
              .evaluate()) {
        final target = tester.getRect(find.byWidget(button.widget));
        expect(target.width, greaterThanOrEqualTo(48));
        expect(target.height, greaterThanOrEqualTo(48));
        expect(rect.contains(target.center), isTrue);
        expect(target.right, lessThanOrEqualTo(320));
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('preview geometry covers all languages, widths and preset roles', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final theme = ThemeService();
    await theme.init();
    final community = CommunityService();
    final preview = CommunityPreviewService();
    addTearDown(theme.dispose);
    addTearDown(community.dispose);
    addTearDown(preview.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    await loadAppFonts(tester);
    preview.show(community.discoverableWorks.first);
    final boundary = GlobalKey();
    final captureDir = Platform.environment['NIARIM_PREVIEW_CAPTURE_DIR'];
    final failures = <String>[];
    final manifest = <Map<String, Object>>[];
    var cases = 0;
    const widths = <double>[
      320,
      360,
      375,
      390,
      430,
      480,
      520,
      559,
      560,
      600,
      640,
      641,
      700,
      759,
      760,
      834,
      900,
      1024,
      1180,
      1280,
      1366,
      1440,
      1600,
      1920,
    ];
    Future<void> inspect(
      Locale locale,
      Size size,
      double scale,
      double desiredWidth,
      AppThemePreset preset, {
      bool capture = false,
    }) async {
      tester.view.physicalSize = size;
      theme.previewCurrent(preset);
      preview.updateWidth(desiredWidth);
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: previewHost(
            theme,
            community,
            preview,
            locale: locale,
            scale: scale,
          ),
        ),
      );
      await tester.pumpAndSettle();
      cases++;
      final tag =
          '${locale.toLanguageTag()}/${size.width}x${size.height}/'
          '$scale/$desiredWidth/${preset.id}';
      final panel = find.byWidgetPredicate(
        (w) => w is Material && w.elevation == 10,
      );
      final rect = tester.getRect(panel);
      if (rect.left < 0 ||
          rect.right > size.width + .01 ||
          rect.top < 74 ||
          rect.bottom > size.height + .01) {
        failures.add('$tag panel $rect');
      }
      final player = find.byKey(const Key('communityPreviewPlayer'));
      if (player.evaluate().isNotEmpty) {
        final media = tester.getRect(player);
        if (media.width < 200 || media.height < 200) {
          failures.add('$tag small player');
        }
        final controls = tester.getRect(
          find.byKey(const Key('communityPreviewControls')),
        );
        if (controls.top < media.bottom - .01) {
          failures.add('$tag controls overlap player');
        }
      }
      final targets = <Finder>[
        if (player.evaluate().isNotEmpty)
          find.byKey(const Key('communityPreviewPlay')),
        find.byKey(const Key('communityPreviewClose')),
        find.byKey(const Key('communityPreviewDetails')),
        if (player.evaluate().isNotEmpty)
          find.byKey(const Key('communityPreviewResize')),
      ];
      for (final target in targets) {
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        final hit = tester.getRect(target);
        if (hit.width < 48 ||
            hit.height < 48 ||
            hit.left < -.01 ||
            hit.right > size.width + .01 ||
            hit.top < 74 - .01 ||
            hit.bottom > size.height + .01) {
          failures.add('$tag target $hit');
        }
      }
      final label = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byKey(const Key('communityPreviewDetails')),
          matching: find.byType(Text),
        ),
      );
      if (label.didExceedMaxLines ||
          label.size.width + .01 <
              label.getMaxIntrinsicWidth(double.infinity)) {
        failures.add('$tag clipped Details');
      }
      final bar = tester.widget<Container>(
        find.byKey(const Key('communityPreviewControls')),
      );
      if (bar.color != preset.menuBgColor) {
        failures.add('$tag wrong menu background');
      }
      for (final button in tester.widgetList<IconButton>(
        find.descendant(of: panel, matching: find.byType(IconButton)),
      )) {
        if ((button.icon as Icon).color != preset.menuTextColor) {
          failures.add('$tag wrong menu foreground');
        }
      }
      final exception = tester.takeException();
      if (exception != null) failures.add('$tag $exception');
      if (capture && captureDir != null) {
        final name =
            '${locale.toLanguageTag()}-${size.width.toInt()}x'
            '${size.height.toInt()}-$scale-${desiredWidth.toInt()}-${preset.id}.png';
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('$captureDir/$name');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        manifest.add({
          'file': name,
          'condition': tag,
          'player': player.evaluate().isNotEmpty,
        });
      }
    }

    for (final locale in AppLocalizations.supportedLocales) {
      for (final preset in [
        AppThemePreset.defaultLight,
        AppThemePreset.defaultDark,
      ]) {
        for (final width in widths) {
          for (final scale in [1.0, 2.0]) {
            for (final desired in [200.0, 356.0, 640.0]) {
              await inspect(
                locale,
                Size(width, 844),
                scale,
                desired,
                preset,
                capture:
                    preset == AppThemePreset.defaultDark &&
                    scale == 2 &&
                    ((width == 320 && desired == 356) ||
                        (locale.languageCode == 'fr' && desired == 640)),
              );
            }
          }
        }
      }
      for (final size in [
        const Size(640, 220),
        const Size(640, 360),
        const Size(320, 280),
        const Size(180, 844),
        const Size(400, 160),
      ]) {
        await inspect(
          locale,
          size,
          2,
          356,
          AppThemePreset.defaultDark,
          capture: true,
        );
      }
      for (final preset in theme.presets) {
        await inspect(locale, const Size(320, 844), 2, 356, preset);
      }
    }
    if (captureDir != null) {
      await tester.runAsync(
        () => File('$captureDir/manifest.json').writeAsString(
          jsonEncode({
            'cases': cases,
            'captures': manifest,
            'failures': failures,
          }),
        ),
      );
    }
    // ignore: avoid_print
    print(
      'Preview matrix: $cases cases, ${manifest.length} captures, '
      '${failures.length} failures',
    );
    expect(failures, isEmpty);
  });

  testWidgets('preview keyboard, resize and drag use current visible bounds', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final theme = ThemeService();
    await theme.init();
    final community = CommunityService();
    final preview = CommunityPreviewService();
    addTearDown(theme.dispose);
    addTearDown(community.dispose);
    addTearDown(preview.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    preview.updateWidth(640);
    preview.updatePosition(const Offset(1100, 600));
    await tester.pumpWidget(previewHost(theme, community, preview, scale: 1));
    await tester.pumpAndSettle();
    // Open from an already mounted route, as the card action does in the app.
    preview.show(community.discoverableWorks.first);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'Community preview play',
      reason: 'opening must focus the preview',
    );
    tester.view.physicalSize = const Size(320, 844);
    await tester.pumpAndSettle();
    expect(
      preview.width,
      640,
      reason: 'temporary resize must retain desired width',
    );
    final resize = find.byKey(const Key('communityPreviewResize'));
    await tester.drag(resize, const Offset(-60, 0));
    await tester.pumpAndSettle();
    expect(preview.width, lessThan(320));
    expect(preview.width, greaterThanOrEqualTo(200));
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'Community preview resize',
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pumpAndSettle();
    expect(preview.width, 200);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    expect(preview.width, 320);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pumpAndSettle();
    final panel = find.byWidgetPredicate(
      (w) => w is Material && w.elevation == 10,
    );
    final before = tester.getRect(panel);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();
    expect(tester.getRect(panel).left, before.left - 16);
    for (final size in [
      const Size(320, 280),
      const Size(320, 844),
      const Size(320, 280),
      const Size(320, 844),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        size.height == 280
            ? 'Community preview details'
            : 'Community preview play',
      );
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(preview.work, isNull);
    preview.show(community.discoverableWorks.first);
    await tester.pumpAndSettle();
    final play = find.byKey(const Key('communityPreviewPlay'));
    expect(
      find.descendant(of: play, matching: find.byIcon(Icons.pause)),
      findsOneWidget,
    );
    Focus.of(
      tester.element(
        find.descendant(of: play, matching: find.byIcon(Icons.pause)),
      ),
    ).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: play, matching: find.byIcon(Icons.play_arrow)),
      findsOneWidget,
    );
    final mouse = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getCenter(find.byKey(const Key('communityPreviewClose'))),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Fermer'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await mouse.removePointer();
  });
  testWidgets(
    'rapid preview movement and resizing retain every pointer delta',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final theme = ThemeService();
      await theme.init();
      final community = CommunityService();
      final preview = CommunityPreviewService();
      addTearDown(theme.dispose);
      addTearDown(community.dispose);
      addTearDown(preview.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(640, 900);
      preview.updateWidth(300);
      await tester.pumpWidget(previewHost(theme, community, preview, scale: 1));
      await tester.pumpAndSettle();
      preview.show(community.discoverableWorks.first);
      await tester.pumpAndSettle();
      final failures = <String>[];
      final drag = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('communityPreviewPlayer'))),
      );
      await drag.moveBy(const Offset(40, 0));
      await tester.pump();
      final position = preview.position;
      for (var i = 0; i < 20; i++) {
        await drag.moveBy(const Offset(2, 1));
      }
      await drag.up();
      await tester.pumpAndSettle();
      if ((preview.position - position - const Offset(40, 20)).distance > .01) {
        failures.add(
          'lost movement: ${preview.position - position}, expected40,20',
        );
      }
      final resize = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('communityPreviewResize'))),
      );
      await resize.moveBy(const Offset(40, 0));
      await tester.pump();
      final width = preview.width;
      for (var i = 0; i < 20; i++) {
        await resize.moveBy(const Offset(2, 0));
      }
      await resize.up();
      await tester.pumpAndSettle();
      if ((preview.width - width - 40).abs() > .01) {
        failures.add('lost resize: ${preview.width - width}, expected40');
      }
      expect(failures, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
