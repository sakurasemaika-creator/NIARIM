import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/screens/canvas/widgets/color_picker_panel.dart';
import 'package:niarim/screens/settings/theme_settings_screen.dart';
import 'package:niarim/services/palette_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ThemeFilePicker extends FilePicker {
  String? path;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    void Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => FilePickerResult([
    PlatformFile(name: 'test.niatheme', size: 0, path: path),
  ]);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ThemeService> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = ThemeService();
    await service.init();
    final settings = SettingsService();
    await settings.init();
    addTearDown(settings.dispose);
    final palette = PaletteService();
    await palette.init();
    addTearDown(service.dispose);
    addTearDown(palette.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: service),
          ChangeNotifierProvider.value(value: palette),
          ChangeNotifierProvider.value(value: settings),
        ],
        child: Consumer<ThemeService>(
          builder: (context, theme, child) => MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: theme.themeData,
            home: child,
          ),
          child: const ThemeSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return service;
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      170,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 60,
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'every color picker dismissal keeps the visible color on restart',
    (tester) async {
      final service = await pumpSettings(tester);
      final open = find.text('Accent Color');
      await reveal(tester, open);
      for (final (color, dismiss) in [
        (
          const Color(0xFF1C744C),
          () async {
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          },
        ),
        (
          const Color(0xFF614B8A),
          () async {
            await tester.tapAt(const Offset(3, 3));
          },
        ),
        (
          const Color(0xFF346B83),
          () async {
            await tester.binding.handlePopRoute();
          },
        ),
        (
          const Color(0xFF953D49),
          () async {
            tester
                .widget<ColorPickerPanel>(find.byType(ColorPickerPanel))
                .onClose();
          },
        ),
      ]) {
        await tester.tap(open);
        await tester.pumpAndSettle();
        tester
            .widget<ColorPickerPanel>(find.byType(ColorPickerPanel))
            .onColorChanged(color);
        await tester.pumpAndSettle();
        await dismiss();
        await tester.pumpAndSettle();
        expect(find.byType(ColorPickerPanel), findsNothing);
        expect(service.current.accentColor, color);
        final reloaded = ThemeService();
        await reloaded.init();
        expect(reloaded.current.accentColor, color);
        expect(
          reloaded.presets
              .singleWhere((p) => p.id == service.current.id)
              .accentColor,
          color,
        );
        reloaded.dispose();
      }
    },
  );

  testWidgets(
    'custom themes require a name and require deletion confirmation',
    (tester) async {
      final service = await pumpSettings(tester);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ThemeSettingsScreen)),
      )!;
      final saveNew = find.text(l10n.themeSaveAsNewButton);
      final count = service.presets.length;
      await reveal(tester, saveNew);
      await tester.tap(saveNew);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '  ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(service.presets, hasLength(count));
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), '  My custom theme  ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(service.presets, hasLength(count + 1));
      final created = service.presets.last;
      expect(created.name, 'My custom theme');

      Future<void> openMenu(String id) async {
        final row = find.byKey(ValueKey(id));
        await reveal(tester, row);
        await tester.tap(
          find.descendant(
            of: row,
            matching: find.byType(PopupMenuButton<String>),
          ),
        );
        await tester.pumpAndSettle();
      }

      await openMenu(created.id);
      await tester.tap(find.text(l10n.commonRename));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(service.presets.last.name, created.name);
      await tester.enterText(find.byType(TextField), 'Renamed theme');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await openMenu(created.id);
      await tester.tap(find.text(l10n.commonDelete));
      await tester.pumpAndSettle();
      expect(service.presets.last.name, 'Renamed theme');
      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();
      expect(service.presets, hasLength(count + 1));
      await openMenu(created.id);
      await tester.tap(find.text(l10n.commonDelete));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, l10n.commonDelete));
      await tester.pumpAndSettle();
      final reloaded = ThemeService();
      await reloaded.init();
      expect(reloaded.presets, hasLength(count));
      expect(reloaded.presets.any((p) => p.id == created.id), isFalse);
      reloaded.dispose();
    },
  );

  testWidgets(
    'invalid theme imports use localized messages and keep the current theme',
    (tester) async {
      final service = await pumpSettings(tester);
      final picker = _ThemeFilePicker();
      FilePicker.platform = picker;
      final directory = Directory.systemTemp.createTempSync('theme-import-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ThemeSettingsScreen)),
      )!;
      final button = find.text(l10n.themeImportButton);
      final original = service.current;
      final count = service.presets.length;
      final incomplete = AppThemePreset.defaultLight.toJson()
        ..remove('textColor');
      final typedWrong = AppThemePreset.defaultLight.toJson()
        ..['textColor'] = 'black';
      await reveal(tester, button);
      for (final (contents, expected) in [
        ('raw content from the input', l10n.themeImportInvalidFile),
        (jsonEncode(incomplete), l10n.themeImportMissingColors),
        (jsonEncode(typedWrong), l10n.themeImportMissingColors),
        (null, l10n.themeImportReadFailed),
        (
          jsonEncode(original.copyWith(textColor: Colors.transparent).toJson()),
          l10n.themeImportLowContrast,
        ),
      ]) {
        final file = File('${directory.path}/test.niatheme');
        if (file.existsSync()) file.deleteSync();
        if (contents != null) file.writeAsStringSync(contents);
        picker.path = file.path;
        await tester.tap(button);
        for (
          var trial = 0;
          trial < 30 && find.text(expected).evaluate().isEmpty;
          trial++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(find.text(expected), findsOneWidget);
        expect(service.current, same(original));
        final imported = expected == l10n.themeImportLowContrast;
        expect(service.presets, hasLength(imported ? count + 1 : count));
        if (imported) {
          expect(service.presets.last.textColor, Colors.transparent);
        }
        ScaffoldMessenger.of(
          tester.element(find.byType(ThemeSettingsScreen)),
        ).removeCurrentSnackBar();
        await tester.pumpAndSettle();
      }
    },
  );

  test(
    'disabled switches fall back to the disabled colors even when selected',
    () {
      final theme = ThemeService().themeData;
      final thumb = theme.switchTheme.thumbColor!;
      final track = theme.switchTheme.trackColor!;
      expect(
        thumb.resolve({WidgetState.selected}),
        theme.colorScheme.onPrimary,
      );
      expect(track.resolve({WidgetState.selected}), theme.colorScheme.primary);
      expect(
        thumb.resolve({WidgetState.selected, WidgetState.disabled}),
        isNull,
      );
      expect(
        track.resolve({WidgetState.selected, WidgetState.disabled}),
        isNull,
      );
    },
  );
}
