import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/screens/settings/storage_screen.dart';
import 'package:niarim/screens/settings/widgets/erase_all_dialog.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/file_size_label.dart';
import 'package:niarim/widgets/confirm_delete.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/storage_screen_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final presets = [
    AppThemePreset.defaultLight.copyWith(
      textColor: const Color(0xFF153515),
      menuTextColor: const Color(0xFFE8E8FF),
      menuBgColor: const Color(0xFF171735),
      accentColor: const Color(0xFF81BDB5),
      accentTextColor: const Color(0xFF351535),
      buttonTextColor: const Color(0xFF151535),
    ),
    AppThemePreset.defaultDark.copyWith(
      textColor: const Color(0xFFE8FFE8),
      menuTextColor: const Color(0xFF171735),
      menuBgColor: const Color(0xFFE8E8FF),
      accentColor: const Color(0xFFB9A5D2),
      accentTextColor: const Color(0xFFFFE8FF),
      buttonTextColor: const Color(0xFF351515),
    ),
  ];

  setUp(() => SharedPreferences.setMockInitialValues({}));
  Color? ink(WidgetTester tester, Finder finder) => tester
      .renderObject<RenderParagraph>(
        find.descendant(of: finder, matching: find.byType(RichText)),
      )
      .text
      .style
      ?.color;

  for (var i = 0; i < presets.length; i++) {
    final preset = presets[i];
    testWidgets('storage action surfaces follow custom appearance $i', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final theme = ThemeService()..previewCurrent(preset);
      final service = ScriptedStorage();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ProjectService()),
            ChangeNotifierProvider(create: (_) => SettingsService()),
          ],
          child: MaterialApp(
            theme: theme.themeData,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: StorageScreen(service: service),
          ),
        ),
      );
      service.scans.single.complete(storageBreakdownOf(cache: 123));
      service.deviceQueries.single.complete(null);
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(StorageScreen)),
      )!;
      final erase = find.text(l10n.storageEraseAllButton);
      await tester.scrollUntilVisible(erase, 160, maxScrolls: 20);
      await tester.ensureVisible(erase);
      await tester.pumpAndSettle();
      for (final label in [
        l10n.storageEraseAllButton,
        l10n.storageOrganizeProjectsButton,
        l10n.storageClearCacheButton,
        l10n.storageRemoveUnusedMaterialsButton,
      ]) {
        final tile = find.widgetWithText(ListTile, label);
        expect(
          ink(tester, find.descendant(of: tile, matching: find.text(label))),
          preset.menuTextColor,
        );
        for (final context in tester.elementList(
          find.descendant(of: tile, matching: find.byType(Icon)),
        )) {
          final icon = context.widget as Icon;
          expect(
            icon.color ?? IconTheme.of(context).color,
            preset.menuTextColor,
          );
        }
      }
      expect(
        ink(
          tester,
          find.descendant(
            of: find.widgetWithText(ListTile, l10n.storageClearCacheButton),
            matching: find.text(fileSizeLabel(l10n, 123)),
          ),
        ),
        preset.menuTextColor,
      );
      expect(
        ink(tester, find.text(l10n.storageEmptyTrashButton)),
        preset.menuTextColor.withValues(alpha: 0.38),
      );
      await tester.tap(erase);
      await tester.pumpAndSettle();
      // 確かめの言葉を打つまで押せない。打つと塗りのボタンになる。
      await tester.enterText(
        find.byKey(EraseAllDataDialog.wordFieldKey),
        l10n.storageEraseAllConfirmWord,
      );
      await tester.pumpAndSettle();
      final confirm = find.byType(FilledButton);
      final fill = tester.widget<Material>(
        find.descendant(of: confirm, matching: find.byType(Material)),
      );
      expect(fill.color, preset.accentColor);
      expect(
        ink(
          tester,
          find.descendant(
            of: confirm,
            matching: find.text(l10n.storageEraseAllButton),
          ),
        ),
        preset.buttonTextColor,
      );
      await tester.tap(find.widgetWithText(TextButton, l10n.commonCancel));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        service.invalidations,
        0,
        reason: 'Cancelling must not change storage',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
      'shared delete confirmation uses button colors and preserves outcomes $i',
      (tester) async {
        final theme = ThemeService()..previewCurrent(preset);
        bool? result;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme.themeData,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async => result = await confirmDelete(
                    context,
                    itemName: 'Owned audit file',
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(
          tester.element(find.byType(Scaffold)),
        )!;
        for (final accept in [false, true]) {
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          expect(
            find.text(l10n.confirmDeleteNamedBody('Owned audit file')),
            findsOneWidget,
          );
          final confirm = find.byType(FilledButton);
          final fill = tester.widget<Material>(
            find.descendant(of: confirm, matching: find.byType(Material)),
          );
          expect(fill.color, preset.accentColor);
          expect(
            ink(tester, find.text(l10n.commonDelete).last),
            preset.buttonTextColor,
          );
          await tester.tap(
            accept
                ? confirm
                : find.widgetWithText(TextButton, l10n.commonCancel),
          );
          await tester.pumpAndSettle();
          expect(result, accept);
          expect(find.byType(AlertDialog), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
