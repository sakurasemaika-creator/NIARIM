import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/screens/community/community_screen.dart';
import 'package:niarim/services/community_preview_service.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/color_contrast.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  testWidgets('display-filter switch remains visible and saves both states', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final themes = ThemeService();
    await themes.init();
    final service = CommunityService();
    await service.contentFiltersReady;
    addTearDown(themes.dispose);
    addTearDown(service.dispose);
    await loadAppFonts(tester);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final failures = <String, String>{};
    for (final preset in [
      ...themes.presets,
      AppThemePreset.defaultLight.copyWith(
        accentColor: Colors.white,
        selectionColor: Colors.black,
      ),
    ]) {
      await tester.runAsync(() => service.setHideGenerativeAiImageVideo(true));
      themes.previewCurrent(preset);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CommunityService>.value(value: service),
            ChangeNotifierProvider(create: (_) => SettingsService()),
            ChangeNotifierProvider(create: (_) => PremiumService()),
            ChangeNotifierProvider(create: (_) => CommunityPreviewService()),
          ],
          child: MaterialApp(
            theme: themes.themeData,
            locale: const Locale('fr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.3)),
              child: child!,
            ),
            home: const CommunityScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('communityContentFilterButton')));
      await tester.pumpAndSettle();
      for (final selected in [true, false]) {
        final control = find.byType(Switch);
        final w = tester.widget<Switch>(control);
        expect(w.value, selected);
        final context = tester.element(control);
        final theme = Theme.of(context);
        final style = SwitchTheme.of(context);
        final states = <WidgetState>{if (selected) WidgetState.selected};
        final bg = opaqueOver(
          theme.dialogTheme.backgroundColor ??
              theme.colorScheme.surfaceContainerHigh,
          theme.scaffoldBackgroundColor,
        );
        final track = opaqueOver(
          (selected ? w.activeTrackColor : w.inactiveTrackColor) ??
              style.trackColor?.resolve(states) ??
              theme.colorScheme.surfaceContainerHighest,
          bg,
        );
        final thumb = opaqueOver(
          (selected ? w.activeThumbColor : w.inactiveThumbColor) ??
              style.thumbColor?.resolve(states) ??
              theme.colorScheme.onSurface,
          track,
        );
        final outlineWidth =
            w.trackOutlineWidth?.resolve(states) ??
            style.trackOutlineWidth?.resolve(states) ??
            (selected ? 0.0 : 2.0);
        final outline = outlineWidth > 0
            ? opaqueOver(
                w.trackOutlineColor?.resolve(states) ??
                    style.trackOutlineColor?.resolve(states) ??
                    (selected ? Colors.transparent : theme.colorScheme.outline),
                bg,
              )
            : bg;
        final boundary = [
          contrastRatio(track, bg),
          contrastRatio(outline, bg),
        ].reduce((a, b) => a > b ? a : b);
        if (contrastRatio(thumb, track) < 3 || boundary < 3) {
          failures['${preset.id}/${preset.accentColor.toARGB32()}/$selected'] =
              'thumb/track=${contrastRatio(thumb, track)} boundary=$boundary';
        }
        if (selected) {
          await tester.tap(control);
          await tester.pumpAndSettle();
        }
      }
      await tester.tap(
        find.byKey(const Key('communityContentFilterSaveButton')),
      );
      await tester.pumpAndSettle();
      expect(service.hideGenerativeAiImageVideo, isFalse);
      await tester.tap(find.byKey(const Key('communityContentFilterButton')));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(AlertDialog)),
      )!;
      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();
    }
    expect(
      failures,
      isEmpty,
      reason:
          'Thumb and control boundary must remain perceptible on the actual popup; selected and unselected are distinct saved states.',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('display-filter Cancel is readable on every built-in popup', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final themes = ThemeService();
    await themes.init();
    final service = CommunityService();
    await service.contentFiltersReady;
    addTearDown(themes.dispose);
    addTearDown(service.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final failures = <String, double>{};
    for (final preset in themes.presets) {
      themes.previewCurrent(preset);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CommunityService>.value(value: service),
            ChangeNotifierProvider(create: (_) => SettingsService()),
            ChangeNotifierProvider(create: (_) => PremiumService()),
            ChangeNotifierProvider(create: (_) => CommunityPreviewService()),
          ],
          child: MaterialApp(
            theme: themes.themeData,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const CommunityScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('communityContentFilterButton')));
      await tester.pumpAndSettle();
      final cancel = find.widgetWithText(TextButton, 'Cancel');
      expect(cancel, findsOneWidget);
      final context = tester.element(cancel);
      final theme = Theme.of(context);
      final button = tester.widget<TextButton>(cancel);
      final fg =
          button.style?.foregroundColor?.resolve({}) ??
          TextButtonTheme.of(context).style?.foregroundColor?.resolve({}) ??
          theme.colorScheme.primary;
      final bg =
          theme.dialogTheme.backgroundColor ??
          theme.colorScheme.surfaceContainerHigh;
      final ratio = contrastRatio(
        opaqueOver(bg, theme.scaffoldBackgroundColor),
        opaqueOver(fg, bg),
      );
      if (ratio < 4.5) failures[preset.id] = ratio;
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    }
    expect(
      failures,
      isEmpty,
      reason:
          'Normal-sized dialog action labels need contrast >= 4.5 on their actual popup.',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
