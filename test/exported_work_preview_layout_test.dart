import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/screens/home/widgets/exported_work_preview_layout.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';

void main() {
  testWidgets(
    'preview controls wrap and remain reachable in every locale and preset',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final theme = ThemeService();
      await theme.init();
      addTearDown(theme.dispose);
      await loadAppFonts(tester);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final palettes = [
        ...theme.presets,
        AppThemePreset.defaultLight.copyWith(
          menuBgColor: const Color(0xFFFFD6BC),
          menuTextColor: const Color(0xFF153E6F),
        ),
        AppThemePreset.defaultDark.copyWith(
          menuBgColor: const Color(0x88387345),
          menuTextColor: const Color(0xFFFFD06E),
        ),
      ];
      final original = jsonEncode(palettes.map((p) => p.toJson()).toList());
      final boundary = GlobalKey();
      final root = Platform.environment['NIARIM_AUDIT_CAPTURE'];
      final manifest = <Map<String, Object?>>[];
      var conditions = 0;
      var shared = 0;
      var closed = 0;
      for (var index = 0; index < palettes.length; index++) {
        theme.previewCurrent(palettes[index]);
        for (final locale in AppLocalizations.supportedLocales) {
          for (final size in [
            const Size(320, 844),
            const Size(320, 220),
            const Size(1440, 900),
          ]) {
            for (final scale in [1.0, 2.0]) {
              tester.view.physicalSize = size;
              await tester.pumpWidget(
                MaterialApp(
                  theme: theme.themeData,
                  locale: locale,
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: RepaintBoundary(key: boundary, child: child!),
                  ),
                  home: Scaffold(
                    body: Builder(
                      builder: (context) {
                        final l10n = AppLocalizations.of(context)!;
                        return Dialog(
                          insetPadding: const EdgeInsets.all(16),
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: ExportedWorkPreviewLayout(
                            // Layout-only artwork stand-in; native valid GIF is verified separately.
                            content: const ColoredBox(color: Color(0xFF236B45)),
                            shareLabel: l10n.homeShareOpenWith,
                            closeLabel: l10n.commonClose,
                            onShare: () => shared++,
                            onClose: () => closed++,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              final context = tester.element(
                find.byType(ExportedWorkPreviewLayout),
              );
              final l10n = AppLocalizations.of(context)!;
              final share = find.ancestor(
                of: find.text(l10n.homeShareOpenWith),
                matching: find.byWidgetPredicate(
                  (widget) => widget is TextButton,
                ),
              );
              final close = find.widgetWithText(TextButton, l10n.commonClose);
              for (final button in [share, close]) {
                await tester.ensureVisible(button);
                await tester.pumpAndSettle();
                final rect = tester.getRect(button);
                expect(rect.height, greaterThanOrEqualTo(48));
                expect(rect.left, greaterThanOrEqualTo(16));
                expect(rect.right, lessThanOrEqualTo(size.width - 16));
                expect(rect.center.dy, inInclusiveRange(16, size.height - 16));
                await tester.tap(button);
                await tester.pumpAndSettle();
              }
              expect(
                tester.takeException(),
                isNull,
                reason: '$index/$locale/$size/$scale',
              );
              conditions++;
              expect(shared, conditions);
              expect(closed, conditions);
              if (root != null &&
                  locale.languageCode == 'fr' &&
                  size == const Size(320, 844) &&
                  scale == 2) {
                final file = 'preset-$index-fr320-text2.png';
                await tester.runAsync(() async {
                  final image =
                      await (boundary.currentContext!.findRenderObject()!
                              as RenderRepaintBoundary)
                          .toImage();
                  final bytes = await image.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  Directory(root).createSync(recursive: true);
                  File(
                    '$root/$file',
                  ).writeAsBytesSync(bytes!.buffer.asUint8List());
                  image.dispose();
                });
                manifest.add({
                  'image': file,
                  'preset': palettes[index].toJson(),
                  'direct_visual': false,
                });
              }
            }
          }
        }
      }
      expect(conditions, 1260);
      expect(shared, 1260);
      expect(closed, 1260);
      expect(jsonEncode(palettes.map((p) => p.toJson()).toList()), original);
      if (root != null) {
        File('$root/manifest.json').writeAsStringSync(
          jsonEncode({'conditions': conditions, 'images': manifest}),
        );
      }
    },
  );
}
