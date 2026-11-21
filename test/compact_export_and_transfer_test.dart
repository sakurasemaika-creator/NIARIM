import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/export/export_screen.dart';
import 'package:niarim/screens/export/widgets/export_complete_dialog.dart';
import 'package:niarim/screens/settings/transfer_screen.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';
import 'helpers/project_storage.dart';

void main() {
  useTemporaryProjectStorage();
  const locale = Locale('fr');
  final l10n = lookupAppLocalizations(locale);

  Future<void> open(WidgetTester tester, Size size, Widget screen) async {
    SharedPreferences.setMockInitialValues({'language': 'fr'});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await loadAppFonts(tester);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (context) => MaterialApp(
            theme: context.watch<ThemeService>().themeDataFor(locale),
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: screen,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in const [Size(360, 640), Size(600, 340)]) {
    testWidgets('export start stays visible at ${size.width.toInt()} px', (
      tester,
    ) async {
      await open(tester, size, const ExportScreen(projectId: 'missing'));
      final start = find.widgetWithText(FilledButton, l10n.exportStartButton);
      expect(start.hitTestable(), findsOneWidget);
      if (size.width > 500) {
        final menu = find.byKey(const Key('exportPresetMenu'));
        await tester.tap(menu);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('exportPresetOption-custom')),
        );
        await tester.pumpAndSettle();
        final customLabel = find.descendant(
          of: menu,
          matching: find.text(l10n.exportPresetCustom),
        );
        final paragraph = tester.renderObject<RenderParagraph>(customLabel);
        final lines = paragraph.getBoxesForSelection(
          TextSelection(
            baseOffset: 0,
            extentOffset: l10n.exportPresetCustom.length,
          ),
        );
        expect(lines.map((line) => line.top).toSet(), hasLength(1));
      }
      final initialPosition = tester.getRect(start);
      final avi = find.widgetWithText(
        RadioListTile<ExportFormat>,
        l10n.exportFormatAvi,
      );
      await tester.ensureVisible(avi);
      await tester.pumpAndSettle();
      await tester.tap(avi);
      await tester.pumpAndSettle();
      expect(tester.widget<RadioListTile<ExportFormat>>(avi).selected, isTrue);
      expect(tester.getRect(start), initialPosition);
      expect(start.hitTestable(), findsOneWidget);

      // A missing project exercises the inline error without starting an encode.
      await tester.tap(start);
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.exportProjectNotFoundError).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('opening Works takes one tap after export in a short window', (
    tester,
  ) async {
    const opener = Key('dialog-origin');
    await open(
      tester,
      const Size(520, 275),
      const Scaffold(body: SizedBox.expand(key: opener)),
    );
    final result = showDialog<ExportDestination>(
      context: tester.element(find.byKey(opener)),
      builder: (_) =>
          ExportCompleteDialog(file: File('Croquis du soir.mp4'), frames: 120),
    );
    await tester.pumpAndSettle();
    final works = find.widgetWithText(FilledButton, l10n.exportOpenWorks);
    expect(works.hitTestable(), findsOneWidget);
    await tester.tap(works);
    await tester.pumpAndSettle();
    expect(await result, ExportDestination.works);
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape transfer leaves item selection and actions in view', (
    tester,
  ) async {
    await open(tester, const Size(600, 340), const TransferScreen());
    final settings = find.widgetWithText(
      CheckboxListTile,
      l10n.transferItemSettings,
    );
    final materials = find.widgetWithText(
      CheckboxListTile,
      l10n.transferItemMaterials,
    );
    final clear = find.byTooltip(l10n.homeSelectionAllDeselect);
    final export = find.widgetWithText(FilledButton, l10n.transferExport);
    expect(settings.hitTestable(), findsOneWidget);
    expect(materials.hitTestable(), findsOneWidget);
    expect(clear.hitTestable(), findsOneWidget);
    expect(export.hitTestable(), findsOneWidget);

    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(settings).value, isFalse);
    expect(tester.widget<FilledButton>(export).onPressed, isNull);

    await tester.tap(settings);
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(settings).value, isTrue);
    expect(tester.widget<FilledButton>(export).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
