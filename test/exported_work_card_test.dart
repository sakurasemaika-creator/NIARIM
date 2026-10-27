import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/screens/home/widgets/exported_work_card.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';

void main() {
  final boundary = GlobalKey();
  const name = 'AUDIT_1_animation_海と空_Animation_étude_动画_動畫_애니메이션.gif';
  Widget host(
    ThemeService theme,
    Locale locale,
    double scale,
    void Function(String) action, {
    bool bold = false,
  }) => MaterialApp(
    theme: theme.themeData,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale), boldText: bold),
      child: RepaintBoundary(key: boundary, child: child!),
    ),
    home: Scaffold(
      body: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context)!;
          return ListView(
            children: [
              ExportedWorkCard(
                name: name,
                metadata: '2026/10/27 12:34 ・ 863B',
                icon: Icons.gif_box_outlined,
                shareLabel: l10n.homeShareOpenWith,
                deleteLabel: l10n.commonDelete,
                onOpen: () => action('open'),
                onMove: () => action('move'),
                onShare: () => action('share'),
                onDelete: () => action('delete'),
              ),
            ],
          );
        },
      ),
    ),
  );

  testWidgets(
    'export actions stay independent for mouse, long press and keyboard',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final theme = ThemeService();
      await theme.init();
      addTearDown(theme.dispose);
      await loadAppFonts(tester);
      final actions = <String>[];
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(host(theme, const Locale('fr'), 2, actions.add));
      await tester.pumpAndSettle();
      final label = find.text(name);
      await tester.tap(label);
      await tester.pumpAndSettle();
      await tester.longPress(label);
      await tester.pumpAndSettle();
      for (final icon in [Icons.ios_share, Icons.delete_outline]) {
        final button = find.ancestor(
          of: find.byIcon(icon),
          matching: find.byType(IconButton),
        );
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(tester.getSize(button), const Size(48, 48));
      }
      expect(actions, ['open', 'move', 'share', 'delete']);
      Focus.of(tester.element(label)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(actions, ['open', 'move', 'share', 'delete', 'open']);
      tester.view.physicalSize = const Size(320, 220);
      await tester.pumpAndSettle();
      final share = find.ancestor(
        of: find.byIcon(Icons.ios_share),
        matching: find.byType(IconButton),
      );
      await tester.ensureVisible(share);
      await tester.pumpAndSettle();
      await tester.tap(share);
      await tester.pumpAndSettle();
      expect(actions.last, 'share');
      final semantics = tester.ensureSemantics();
      await tester.ensureVisible(label);
      await tester.pumpAndSettle();
      expect(tester.getSemantics(label).label, contains(name));
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'bold export names fit and actions remain reachable in a short viewport',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final theme = ThemeService();
      await theme.init();
      addTearDown(theme.dispose);
      await loadAppFonts(tester);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final width in [
        320,
        321,
        390,
        559,
        560,
        639,
        640,
        759,
        760,
        1024,
        1440,
      ]) {
        tester.view.physicalSize = Size(width.toDouble(), 220);
        await tester.pumpWidget(
          host(theme, const Locale('fr'), 2, (_) {}, bold: true),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .renderObject<RenderParagraph>(find.text(name))
              .didExceedMaxLines,
          isFalse,
        );
        final button = find.ancestor(
          of: find.byIcon(Icons.delete_outline),
          matching: find.byType(IconButton),
        );
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        expect(tester.getCenter(button).dy, inInclusiveRange(24, 196));
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'all preset surfaces, locales and widths preserve complete export identity',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final theme = ThemeService();
      await theme.init();
      addTearDown(theme.dispose);
      await loadAppFonts(tester);
      final presets = [
        ...theme.presets,
        AppThemePreset.defaultLight.copyWith(
          menuBgColor: const Color(0xFFFFD6BC),
          menuTextColor: const Color(0xFF153E6F),
          panelBgColor: const Color(0xFFF5DFAF),
          textColor: const Color(0xFF163A5F),
        ),
        AppThemePreset.defaultDark.copyWith(
          menuBgColor: const Color(0x88387345),
          panelBgColor: const Color(0xAA652D7D),
          menuTextColor: const Color(0xFFFFD06E),
        ),
      ];
      final original = jsonEncode(presets.map((p) => p.toJson()).toList());
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final capture = Platform.environment['NIARIM_AUDIT_CAPTURE'];
      final manifest = <Map<String, Object?>>[];
      var conditions = 0;
      for (var index = 0; index < presets.length; index++) {
        final preset = presets[index];
        theme.previewCurrent(preset);
        for (final locale in AppLocalizations.supportedLocales) {
          for (final width in [
            320,
            321,
            390,
            559,
            560,
            639,
            640,
            759,
            760,
            1024,
            1440,
          ]) {
            for (final scale in [1.0, 2.0]) {
              tester.view.physicalSize = Size(width.toDouble(), 844);
              await tester.pumpWidget(host(theme, locale, scale, (_) {}));
              await tester.pumpAndSettle();
              final paragraph = tester.renderObject<RenderParagraph>(
                find.text(name),
              );
              expect(paragraph.didExceedMaxLines, isFalse);
              expect(paragraph.text.style?.color, preset.menuTextColor);
              final card = tester.widget<Card>(find.byType(Card));
              expect(card.color, theme.themeData.cardTheme.color);
              for (final button in tester.widgetList<IconButton>(
                find.byType(IconButton),
              )) {
                expect(button.color, preset.menuTextColor);
                expect(button.tooltip, contains(name));
              }
              expect(
                tester.takeException(),
                isNull,
                reason: '$index/$locale/$width/$scale',
              );
              conditions++;
              if (capture != null &&
                  locale.languageCode == 'fr' &&
                  width == 320 &&
                  scale == 2) {
                final file = 'preset-$index-fr320-text2.png';
                await tester.runAsync(() async {
                  final image =
                      await (boundary.currentContext!.findRenderObject()!
                              as RenderRepaintBoundary)
                          .toImage();
                  final data = await image.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  final dir = Directory(capture)..createSync(recursive: true);
                  File(
                    '${dir.path}/$file',
                  ).writeAsBytesSync(data!.buffer.asUint8List());
                  image.dispose();
                });
                manifest.add({
                  'image': file,
                  'preset': preset.toJson(),
                  'locale': locale.toString(),
                  'viewport': [320, 844],
                  'scale': scale,
                  'direct_visual': false,
                });
              }
            }
          }
        }
      }
      expect(conditions, 4620);
      expect(jsonEncode(presets.map((p) => p.toJson()).toList()), original);
      if (capture != null) {
        File('$capture/manifest.json').writeAsStringSync(
          jsonEncode({'conditions': conditions, 'images': manifest}),
        );
      }
    },
  );
}
