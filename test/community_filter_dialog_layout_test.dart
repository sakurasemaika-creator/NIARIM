import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/screens/community/community_screen.dart';
import 'package:niarim/services/community_preview_service.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'community_header_quality_test.dart' as quality;
import 'helpers/load_app_fonts.dart';

void main() {
  testWidgets(
    'mute settings controls and instructions remain complete at large text',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final themes = ThemeService();
      await themes.init();
      themes.previewCurrent(AppThemePreset.defaultDark);
      final community = CommunityService();
      final preview = CommunityPreviewService();
      await tester.runAsync(() => community.contentFiltersReady);
      addTearDown(themes.dispose);
      addTearDown(community.dispose);
      addTearDown(preview.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      await loadAppFonts(tester);
      final failures = <String>[];
      for (final locale in AppLocalizations.supportedLocales) {
        for (final size in [const Size(320, 844), const Size(640, 360)]) {
          for (final pc in [false, true]) {
            tester.view.physicalSize = size;
            await tester.pumpWidget(
              quality.host(
                themes,
                community,
                preview,
                locale: locale,
                scale: 2,
              ),
            );
            await tester.pumpAndSettle();
            final screen = tester.element(find.byType(CommunityScreen));
            await tester.runAsync(
              () => screen.read<SettingsService>().setForcePcMode(pc),
            );
            await tester.pumpAndSettle();
            final l10n = AppLocalizations.of(screen)!;
            await tester.ensureVisible(
              find.byKey(const Key('communityMuteSettingsButton')),
            );
            await tester.tap(
              find.byKey(const Key('communityMuteSettingsButton')),
            );
            await tester.pumpAndSettle();
            await tester.ensureVisible(
              find.byKey(const Key('communityMutedWordsAccordion')),
            );
            await tester.tap(
              find.byKey(const Key('communityMutedWordsAccordion')),
            );
            await tester.pumpAndSettle();
            await tester.ensureVisible(
              find.byKey(const Key('communityMutedTagsAccordion')),
            );
            await tester.tap(
              find.byKey(const Key('communityMutedTagsAccordion')),
            );
            await tester.pumpAndSettle();
            final suffix =
                '${locale.toLanguageTag()}/$size/${pc ? 'pc' : 'sp'}';
            final save = find.byKey(
              const Key('communityContentFilterSaveButton'),
            );
            final label = tester.renderObject<RenderParagraph>(
              find.descendant(of: save, matching: find.text(l10n.commonSave)),
            );
            if (label.size.width + .01 <
                label.getMaxIntrinsicWidth(double.infinity)) {
              failures.add('$suffix Save label breaks mid-word');
            }
            for (final text in [
              l10n.communityMutedWordsHint,
              l10n.communityMutedTagsHint,
            ]) {
              final p = tester.renderObject<RenderParagraph>(find.text(text));
              if (p.didExceedMaxLines) {
                failures.add('$suffix hidden filter instructions');
              }
            }
            for (final button in [
              save,
              find.widgetWithText(TextButton, l10n.commonCancel),
            ]) {
              final rect = tester.getRect(button);
              if (rect.height < 48 ||
                  rect.top < 0 ||
                  rect.bottom > size.height) {
                failures.add('$suffix action unreachable or undersized: $rect');
              }
            }
            final error = tester.takeException();
            if (error != null) failures.add('$suffix $error');
            await tester.tap(
              find.widgetWithText(TextButton, l10n.commonCancel),
            );
            await tester.pumpAndSettle();
            await tester.pumpWidget(const SizedBox.shrink());
          }
        }
      }
      expect(failures, isEmpty);
    },
  );
}
