import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/export_preset.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/screens/export/widgets/export_preset_selector.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/load_app_fonts.dart';

Widget _host(
  ThemeService theme,
  Locale locale,
  double scale,
  ExportPreset value,
  ValueChanged<ExportPreset> onChanged, {
  bool bold = false,
}) => MaterialApp(
  theme: theme.themeData,
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(scale), boldText: bold),
    child: child!,
  ),
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Align(
        alignment: Alignment.topCenter,
        child: ExportPresetSelector(value: value, onChanged: onChanged),
      ),
    ),
  ),
);

void _expectWordsIntact(WidgetTester tester, Finder labels) {
  for (final paragraph in tester.renderObjectList<RenderParagraph>(labels)) {
    final text = paragraph.text.toPlainText();
    for (final word in RegExp(r'[A-Za-zÀ-ÖØ-öø-ÿ]+').allMatches(text)) {
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: word.start, extentOffset: word.end),
      );
      if (boxes.isNotEmpty) {
        final first = boxes.first.toRect();
        for (final box in boxes.skip(1)) {
          final rect = box.toRect();
          final lineHeight = rect.height < first.height
              ? rect.height
              : first.height;
          expect(
            (rect.center.dy - first.center.dy).abs(),
            lessThan(lineHeight / 2),
            reason: 'Word split in "$text"',
          );
        }
      }
    }
    expect(paragraph.didExceedMaxLines, isFalse);
  }
}

void main() {
  testWidgets(
    'compact presets expose all choices and preserve cancel and callback',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final theme = ThemeService();
      await theme.init();
      addTearDown(theme.dispose);
      await loadAppFonts(tester);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 760);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var value = ExportPreset.standard;
      final changes = <ExportPreset>[];
      for (final locale in AppLocalizations.supportedLocales) {
        Future<void> show() async {
          await tester.pumpWidget(
            _host(theme, locale, 2, value, (v) {
              changes.add(v);
              value = v;
            }),
          );
          await tester.pumpAndSettle();
        }

        await show();
        final menu = find.byKey(const Key('exportPresetMenu'));
        expect(menu, findsOneWidget);
        expect(tester.getSize(menu).height, greaterThanOrEqualTo(48));
        _expectWordsIntact(
          tester,
          find.descendant(
            of: find.byType(ExportPresetSelector),
            matching: find.byType(Text),
          ),
        );
        final beforeCancel = value;
        final changesBeforeCancel = changes.length;
        await tester.tap(menu);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(value, beforeCancel);
        expect(changes.length, changesBeforeCancel);
        for (final choice in ExportPreset.values) {
          await tester.tap(menu);
          await tester.pumpAndSettle();
          final options = find.byType(PopupMenuItem<ExportPreset>);
          expect(options, findsNWidgets(3));
          _expectWordsIntact(
            tester,
            find.descendant(of: options, matching: find.byType(Text)),
          );
          await tester.tap(
            find.byKey(ValueKey('exportPresetOption-${choice.name}')),
          );
          await tester.pumpAndSettle();
          expect(value, choice);
          await show();
        }
        expect(changes.skip(changes.length - 3).toList(), ExportPreset.values);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'preset labels fit all widths, languages, typography and formal presets',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final theme = ThemeService();
      await theme.init();
      addTearDown(theme.dispose);
      await loadAppFonts(tester);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
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
      final failures = <String>[];
      final captures = <Map<String, Object>>[];
      final boundary = GlobalKey();
      final captureDir =
          Platform.environment['NIARIM_EXPORT_PRESET_CAPTURE_DIR'];
      var cases = 0;
      Future<void> inspect(
        AppThemePreset palette,
        Locale locale,
        double width,
        double scale,
        bool bold,
        ExportPreset selected, {
        bool capture = false,
        String phase = 'matrix',
      }) async {
        theme.previewCurrent(palette);
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: _host(theme, locale, scale, selected, (_) {}, bold: bold),
          ),
        );
        await tester.pumpAndSettle();
        cases++;
        final tag =
            '$phase/${palette.id}/${locale.toLanguageTag()}/$width/$scale/$bold/${selected.name}';
        final root = tester.getRect(find.byType(ExportPresetSelector));
        if (root.left < -.01 || root.right > width + .01 || root.height < 48) {
          failures.add('$tag bad bounds $root');
        }
        try {
          _expectWordsIntact(
            tester,
            find.descendant(
              of: find.byType(ExportPresetSelector),
              matching: find.byType(Text),
            ),
          );
        } catch (error) {
          failures.add('$tag $error');
        }
        final error = tester.takeException();
        if (error != null) failures.add('$tag $error');
        if (capture && captureDir != null) {
          final name =
              '$phase-${palette.id}-${locale.toLanguageTag()}-${selected.name}.png';
          final data = await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 1);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            image.dispose();
            return data!.buffer.asUint8List();
          });
          final dir = Directory(captureDir)..createSync(recursive: true);
          File('${dir.path}/$name').writeAsBytesSync(data!);
          captures.add({
            'file': name,
            'condition': tag,
            'scope': 'component only; production native checks separate',
          });
        }
        if (cases % 500 == 0) {
          debugPrint(
            'Export preset matrix: $cases conditions, ${failures.length} failures',
          );
        }
      }

      for (final palette in [
        AppThemePreset.defaultLight,
        AppThemePreset.defaultDark,
      ]) {
        for (final locale in AppLocalizations.supportedLocales) {
          for (final width in widths) {
            for (final scale in [1.0, 2.0]) {
              for (final bold in [false, true]) {
                for (final selected in ExportPreset.values) {
                  await inspect(
                    palette,
                    locale,
                    width,
                    scale,
                    bold,
                    selected,
                    capture: width == 320 && scale == 2 && !bold,
                  );
                }
              }
            }
          }
        }
      }
      final presets = List<AppThemePreset>.from(theme.presets);
      for (final palette in presets) {
        for (final locale in AppLocalizations.supportedLocales) {
          for (final selected in ExportPreset.values) {
            await inspect(
              palette,
              locale,
              320,
              2,
              false,
              selected,
              phase: 'catalog',
              capture:
                  locale == const Locale('ja') &&
                  selected == ExportPreset.standard,
            );
          }
        }
      }
      if (captureDir != null) {
        File('$captureDir/manifest.json').writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert({
            'conditions': cases,
            'catalog_presets': presets.length,
            'captures': captures,
            'failures': failures,
          }),
        );
      }
      debugPrint(
        'Export preset matrix: $cases conditions, ${presets.length} presets, ${captures.length} captures, ${failures.length} failures',
      );
      expect(failures, isEmpty);
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );

  testWidgets('wide segments inherit the configured selected foreground', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final theme = ThemeService();
    await theme.init();
    theme.previewCurrent(
      AppThemePreset.defaultDark.copyWith(
        selectionTextColor: const Color(0xFFF5D88A),
        textColor: const Color(0xFF97CAD5),
      ),
    );
    addTearDown(theme.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await loadAppFonts(tester);
    await tester.pumpWidget(
      _host(theme, const Locale('en'), 1, ExportPreset.standard, (_) {}),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exportPresetSegments')), findsOneWidget);
    final text = find.text('Standard');
    expect(
      DefaultTextStyle.of(tester.element(text)).style.color,
      theme.current.selectionTextColor,
    );
    _expectWordsIntact(
      tester,
      find.descendant(
        of: find.byType(ExportPresetSelector),
        matching: find.byType(Text),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
