import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'implicit panel icons follow normal text without changing action roles',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final service = ThemeService();
      await service.init();
      addTearDown(service.dispose);
      final custom = AppThemePreset.defaultLight.copyWith(
        textColor: const Color(0xFF163A5F),
        menuTextColor: const Color(0xFF613B8F),
        buttonTextColor: const Color(0xFFFFE8B0),
        accentColor: const Color(0xFFB83E56),
      );
      final palettes = [
        custom,
        ...service.presets,
        custom.copyWith(textColor: const Color(0x8816563A)),
      ];
      final original = jsonEncode(palettes.map((p) => p.toJson()).toList());
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      Color? paintedColor(String key) => tester
          .renderObject<RenderParagraph>(
            find.descendant(
              of: find.byKey(ValueKey(key)),
              matching: find.byType(RichText),
            ),
          )
          .text
          .style
          ?.color;

      var conditions = 0;
      for (final preset in palettes) {
        service.previewCurrent(preset);
        for (final locale in AppLocalizations.supportedLocales) {
          for (final width in [320.0, 1440.0]) {
            tester.view.physicalSize = Size(width, 900);
            for (final scale in [1.0, 2.0]) {
              await tester.pumpWidget(
                MaterialApp(
                  theme: service.themeData,
                  locale: locale,
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: Scaffold(
                    appBar: AppBar(
                      leading: const Icon(Icons.menu, key: ValueKey('menu')),
                    ),
                    body: Wrap(
                      children: [
                        const Icon(Icons.folder, key: ValueKey('panel')),
                        FilledButton(
                          onPressed: () {},
                          child: const Icon(Icons.add, key: ValueKey('filled')),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: const Icon(
                            Icons.close,
                            key: ValueKey('text-button'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              expect(
                paintedColor('panel'),
                preset.textColor,
                reason:
                    'An unqualified folder icon must follow the configured normal foreground',
              );
              expect(paintedColor('menu'), preset.menuTextColor);
              expect(paintedColor('filled'), preset.buttonTextColor);
              expect(
                paintedColor('text-button'),
                service.themeData.colorScheme.primary,
              );
              expect(service.current.toJson(), preset.toJson());
              expect(tester.takeException(), isNull);
              conditions++;
            }
          }
        }
      }
      expect(conditions, 840);
      expect(jsonEncode(palettes.map((p) => p.toJson()).toList()), original);
    },
  );

  testWidgets(
    'implicit icon follows the interpolated foreground during a theme change',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final service = ThemeService();
      await service.init();
      addTearDown(service.dispose);
      final start = AppThemePreset.defaultLight.copyWith(
        textColor: const Color(0xFF163A5F),
      );
      final end = AppThemePreset.defaultDark.copyWith(
        textColor: const Color(0xFFFFD06E),
      );
      Widget host() => MaterialApp(
        theme: service.themeData,
        home: const Scaffold(
          body: Icon(Icons.folder, key: ValueKey('animated-icon')),
        ),
      );
      service.previewCurrent(start);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      service.previewCurrent(end);
      await tester.pumpWidget(host());
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 25));
        final icon = find.byKey(const ValueKey('animated-icon'));
        final glyph = tester.renderObject<RenderParagraph>(
          find.descendant(of: icon, matching: find.byType(RichText)),
        );
        expect(
          glyph.text.style!.color,
          Theme.of(tester.element(icon)).colorScheme.onSurface,
        );
      }
      await tester.pumpAndSettle();
      expect(service.current.toJson(), end.toJson());
      expect(tester.takeException(), isNull);
    },
  );
}
