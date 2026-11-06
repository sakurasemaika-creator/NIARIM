import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/app_chip_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/load_app_fonts.dart';

final _custom = AppThemePreset.defaultLight.copyWith(
  textColor: const Color(0xFF15623A),
  menuBgColor: const Color(0xFFF6D7AE),
  menuTextColor: const Color(0xFF613B8F),
  selectionColor: const Color(0xFF24539D),
  selectionTextColor: const Color(0xFFFFE7AC),
  buttonTextColor: const Color(0xFFEA3A77),
  accentColor: const Color(0xFF063C6D),
);

Widget _host(
  ThemeService service,
  Locale locale,
  double scale,
  bool selected,
  ValueChanged<bool> change, {
  bool enabled = true,
}) => MaterialApp(
  theme: service.themeData,
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: AppChipTheme(child: child!),
  ),
  home: Scaffold(
    body: Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: Text(
                AppLocalizations.of(context)!.homeFavoritesOnly,
                style: const TextStyle(fontFamily: 'Kuramubon'),
              ),
              selected: selected,
              onSelected: enabled ? change : null,
            ),
            ChoiceChip(
              label: const Text('choice'),
              selected: selected,
              onSelected: enabled ? change : null,
            ),
            InputChip(
              label: const Text('input'),
              selected: selected,
              onSelected: enabled ? change : null,
            ),
            const Chip(label: Text('plain')),
          ],
        ),
      ),
    ),
  ),
);

void _verify(WidgetTester tester, AppThemePreset palette, bool selected) {
  for (final type in [FilterChip, ChoiceChip, InputChip, Chip]) {
    final label = find
        .descendant(of: find.byType(type), matching: find.byType(Text))
        .first;
    final paragraph = tester.renderObject<RenderParagraph>(label);
    expect(
      paragraph.text.style!.color,
      selected && type != Chip
          ? palette.selectionTextColor
          : palette.menuTextColor,
      reason:
          '$type selected=$selected must use the foreground paired to its formal surface',
    );
  }
}

void main() {
  testWidgets(
    'chips follow menu and selected foregrounds through actual changes',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final service = ThemeService();
      await service.init();
      addTearDown(service.dispose);
      service.previewCurrent(_custom);
      var selected = true;
      final changes = <bool>[];
      await tester.pumpWidget(
        AnimatedBuilder(
          animation: service,
          builder: (context, _) => StatefulBuilder(
            builder: (context, update) => _host(
              service,
              const Locale('en'),
              1,
              selected,
              (value) => update(() {
                selected = value;
                changes.add(value);
              }),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      _verify(tester, _custom, true);
      expect(
        service.themeData.chipTheme.checkmarkColor,
        _custom.selectionTextColor,
      );
      for (final name in ['Favorites', 'choice', 'input']) {
        final target = name == 'Favorites'
            ? find.byType(FilterChip)
            : find.text(name);
        await tester.tap(target);
        await tester.pumpAndSettle();
        _verify(tester, _custom, selected);
      }
      expect(changes, [false, true, false]);
      final changed = _custom.copyWith(
        selectionTextColor: const Color(0xFFADE4EF),
        menuTextColor: const Color(0xFF713E25),
      );
      service.previewCurrent(changed);
      await tester.pumpAndSettle();
      _verify(tester, changed, false);
      await tester.tap(find.byType(FilterChip));
      await tester.pumpAndSettle();
      _verify(tester, changed, true);
      expect(service.current.toJson(), changed.toJson());
      expect(
        service.themeData.colorScheme.onSecondaryContainer,
        changed.textColor,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('selected chip foreground keeps its role during theme animation', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final service = ThemeService();
    await service.init();
    addTearDown(service.dispose);
    service.previewCurrent(_custom);
    await tester.pumpWidget(
      AnimatedBuilder(
        animation: service,
        builder: (context, _) =>
            _host(service, const Locale('en'), 1, true, (_) {}),
      ),
    );
    await tester.pumpAndSettle();
    service.previewCurrent(
      _custom.copyWith(
        menuTextColor: const Color(0xFF21653C),
        selectionTextColor: const Color(0xFFB9E8F1),
      ),
    );
    await tester.pump();
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 25));
      for (final type in [FilterChip, ChoiceChip, InputChip]) {
        final chip = find.byType(type);
        final label = find
            .descendant(of: chip, matching: find.byType(Text))
            .first;
        expect(
          tester.renderObject<RenderParagraph>(label).text.style!.color,
          Theme.of(tester.element(chip)).colorScheme.onSecondary,
          reason:
              '$type frame$frame must interpolate the selected foreground, not the menu foreground',
        );
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'disabled chip labels preserve the normal role and cannot select',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final service = ThemeService();
      await service.init();
      addTearDown(service.dispose);
      service.previewCurrent(_custom);
      final changes = <bool>[];
      for (final selected in [false, true]) {
        await tester.pumpWidget(
          _host(
            service,
            const Locale('en'),
            1,
            selected,
            changes.add,
            enabled: false,
          ),
        );
        await tester.pumpAndSettle();
        for (final type in [FilterChip, ChoiceChip, InputChip]) {
          final label = find
              .descendant(of: find.byType(type), matching: find.byType(Text))
              .first;
          expect(
            tester.renderObject<RenderParagraph>(label).text.style!.color,
            _custom.textColor,
          );
          await tester.tap(find.byType(type), warnIfMissed: false);
        }
        await tester.pumpAndSettle();
        expect(changes, isEmpty);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('nested preset preview retains its own chip colors', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final outer = ThemeService();
    final preview = ThemeService();
    await outer.init();
    await preview.init();
    addTearDown(outer.dispose);
    addTearDown(preview.dispose);
    outer.previewCurrent(_custom);
    final inner = _custom.copyWith(
      menuTextColor: const Color(0xFF286549),
      selectionTextColor: const Color(0xFFB9E8F1),
    );
    preview.previewCurrent(inner);
    await tester.pumpWidget(
      MaterialApp(
        theme: outer.themeData,
        builder: (context, child) => AppChipTheme(child: child!),
        home: Theme(
          data: preview.themeData,
          child: Scaffold(
            body: FilterChip(
              label: const Text('preview'),
              selected: true,
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .renderObject<RenderParagraph>(find.text('preview'))
          .text
          .style!
          .color,
      inner.selectionTextColor,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('chip foregrounds follow every formal palette and locale', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final service = ThemeService();
    await service.init();
    addTearDown(service.dispose);
    await loadAppFonts(tester);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 320);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final palettes = [
      ...service.presets,
      _custom,
      _custom.copyWith(
        menuBgColor: const Color(0xAAE8CBAD),
        selectionColor: const Color(0xCC264591),
      ),
    ];
    final dir = Platform.environment['NIARIM_CHIP_CAPTURE_DIR'];
    final captures = <Map<String, Object>>[];
    var conditions = 0;
    final boundary = GlobalKey();
    for (var p = 0; p < palettes.length; p++) {
      final palette = palettes[p];
      service.previewCurrent(palette);
      for (final locale in AppLocalizations.supportedLocales) {
        for (final scale in [1.0, 2.0]) {
          for (final selected in [false, true]) {
            await tester.pumpWidget(
              RepaintBoundary(
                key: boundary,
                child: _host(service, locale, scale, selected, (_) {}),
              ),
            );
            await tester.pumpAndSettle();
            _verify(tester, palette, selected);
            expect(
              service.themeData.chipTheme.checkmarkColor,
              palette.selectionTextColor,
            );
            expect(service.current.toJson(), palette.toJson());
            expect(tester.takeException(), isNull);
            conditions++;
            if (dir != null && locale == const Locale('ja') && scale == 2) {
              final filename = 'chip-$p-${palette.id}-$selected.png';
              final bytes = await tester.runAsync(() async {
                final image =
                    await (boundary.currentContext!.findRenderObject()
                            as RenderRepaintBoundary)
                        .toImage(pixelRatio: 1);
                final data = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                image.dispose();
                return data!.buffer.asUint8List();
              });
              Directory(dir).createSync(recursive: true);
              File('$dir/$filename').writeAsBytesSync(bytes!);
              captures.add({
                'file': filename,
                'palette': palette.id,
                'selected': selected,
              });
            }
          }
        }
      }
    }
    if (dir != null) {
      File('$dir/manifest.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'conditions': conditions,
          'formal_palettes': service.presets.length,
          'additional_custom_palettes': 2,
          'captures': captures,
          'scope':
              'component state/role render; native Home verification separate',
        }),
      );
    }
    debugPrint(
      'Chip foreground matrix: $conditions conditions, ${captures.length} captures',
    );
  }, timeout: const Timeout(Duration(minutes: 5)));
}
