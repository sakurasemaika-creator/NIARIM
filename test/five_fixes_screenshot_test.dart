import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/models/community_work.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/community/community_screen.dart';
import 'package:niarim/screens/community/community_author_works_screen.dart';
import 'package:niarim/screens/community/community_my_works_screen.dart';
import 'package:niarim/screens/community/community_work_settings_screen.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/community_preview_service.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'community_header_quality_test.dart' as quality;
import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

/// Actual Flutter renders for the five Oct 28 changes. No manual mockups.
/// A PDF can be assembled from the five numbered PNG artifacts.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final output = Platform.environment['NIARIM_FIVE_FIXES_CAPTURE'];
  if (output == null) return;

  Future<void> capture(GlobalKey key, String fileName, WidgetTester tester) async {
    expect(tester.takeException(), isNull, reason: fileName);
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final directory = Directory(output)..createSync(recursive: true);
      File('${directory.path}/$fileName.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  testWidgets('capture mute words, mute tags, tag search and French tabs',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'community.mutedWords': ['既存の語'],
      'community.mutedTags': ['既存タグ'],
      'theme_original_builtin_palette_restored_v1': true,
    });
    final themes = ThemeService();
    await themes.init();
    final community = CommunityService();
    final preview = CommunityPreviewService();
    final auth = GoogleAuthService();
    await auth.init();
    await tester.runAsync(() => community.contentFiltersReady);
    addTearDown(themes.dispose);
    addTearDown(community.dispose);
    addTearDown(preview.dispose);
    addTearDown(auth.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await loadAppFonts(tester);
    final root = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: root,
      child: ChangeNotifierProvider.value(
        value: auth,
        child: quality.host(themes, community, preview,
            locale: const Locale('ja'), scale: 1),
      ),
    ));
    await tester.pumpAndSettle();
    await capture(root, '06_work_plaza_post_button', tester);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(CommunityScreen)))!;
    await tester.tap(find.byKey(const Key('communityContentFilterButton')));
    await tester.pumpAndSettle();
    final words = find.byKey(const Key('communityMutedWordsDisplay_0'));
    final tags = find.byKey(const Key('communityMutedTagsDisplay_0'));
    expect(tester.getRect(words).top, lessThan(tester.getRect(tags).top));
    expect(tester.getRect(tags).top,
        lessThan(tester.getRect(find.byType(SwitchListTile)).top));
    await tester.tap(find.byKey(const Key('communityMutedWordsAddButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('communityMutedWordsEntry_1')), 'ネタバレ');
    await tester.pumpAndSettle();
    await capture(root, '01_mute_words', tester);
    await tester.ensureVisible(find.byKey(const Key('communityMutedTagsAddButton')));
    await tester.tap(find.byKey(const Key('communityMutedTagsAddButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('communityMutedTagsEntry_1')), '手描き');
    await tester.ensureVisible(find.byKey(const Key('communityMutedTagsEntry_1')));
    await tester.pumpAndSettle();
    await capture(root, '02_mute_tags', tester);
    // Cancel screenshot edits; the underlying service remains untouched.
    await tester.tap(find.text(l10n.commonCancel));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('communityMyWorksButton')));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityMyWorksScreen), findsOneWidget);
    expect(find.byKey(const Key('communityMyWorksPostButton')), findsOneWidget);
    await capture(root, '07_my_works_after_button', tester);
    // Owner management: the bulk action panel is present only while selected.
    await tester.tap(find.byKey(const Key('communityMyWorksSelectAll')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('communityMyWorksBulkActions')), findsOneWidget);
    await capture(root, '09_my_works_bulk_selection', tester);
    await tester.tap(find.byKey(const Key('communityMyWorksClearSelection')));
    await tester.pumpAndSettle();

    // The wrench opens per-work settings; deletion always asks confirmation.
    final firstWork = community.worksByAuthor(
      kDummySelfAuthorId, includeHidden: true,
    ).first;
    final settingsButton = find.byKey(
      ValueKey('communityMyWorksSettings-${firstWork.id}'),
    );
    await tester.ensureVisible(settingsButton);
    await tester.tap(settingsButton);
    await tester.pumpAndSettle();
    expect(find.byType(CommunityWorkSettingsScreen), findsOneWidget);
    await capture(root, '10_individual_work_settings', tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('communityWorkSettingsDelete')), 160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('communityWorkSettingsDelete')));
    await tester.pumpAndSettle();
    await capture(root, '11_individual_delete_confirmation', tester);
    await tester.tap(find.text(l10n.commonCancel));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(CommunityWorkSettingsScreen))).pop();
    await tester.pumpAndSettle();

    // Direct access to the author's public-facing works list.
    await tester.ensureVisible(find.byKey(const Key('communityMyWorksViewAuthorPage')));
    await tester.tap(find.byKey(const Key('communityMyWorksViewAuthorPage')));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityAuthorWorksScreen), findsOneWidget);
    await capture(root, '12_my_public_works_page', tester);
    Navigator.of(tester.element(find.byType(CommunityAuthorWorksScreen))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('communityMyWorksPostButton')));
    await tester.pumpAndSettle();
    await capture(root, '08_after_post_action', tester);
    Navigator.of(tester.element(find.byType(CommunityMyWorksScreen))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(l10n.commonSearch));
    await tester.pumpAndSettle();
    final switcher = find.byKey(const Key('communitySearchModeToggle'));
    expect(tester.getSize(switcher).width, lessThan(60));
    await tester.tap(switcher);
    await tester.pumpAndSettle();
    expect(find.descendant(of: switcher, matching: find.byIcon(Icons.search)),
        findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '手描き');
    await tester.pumpAndSettle();
    await capture(root, '04_compact_tag_search', tester);

    // New French render at a narrow smartphone viewport for tab alignment.
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.physicalSize = const Size(320, 844);
    await tester.pumpWidget(RepaintBoundary(
      key: root,
      child: ChangeNotifierProvider.value(
        value: auth,
        child: quality.host(themes, community, preview,
            locale: const Locale('fr'), scale: 1),
      ),
    ));
    await tester.pumpAndSettle();
    final fr = AppLocalizations.of(
      tester.element(find.byType(CommunityScreen)))!;
    final bar = tester.widget<TabBar>(find.byType(TabBar));
    if (bar.isScrollable) {
      expect(bar.tabAlignment, TabAlignment.start);
    }
    final first = find.descendant(
      of: find.byType(TabBar), matching: find.text(fr.communityTabNew));
    final firstRect = tester.getRect(first);
    expect(firstRect.left, greaterThanOrEqualTo(0));
    expect(firstRect.right, lessThanOrEqualTo(320));
    await capture(root, '05_french_tab_alignment', tester);
  }, timeout: const Timeout(Duration(minutes: 4)));

  testWidgets('capture selected white favorite chip on real home screen',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'theme_original_builtin_palette_restored_v1': true,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final temporary = Directory.systemTemp.createTempSync('five-fixes-home');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => temporary.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (temporary.existsSync()) temporary.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadAppFonts(tester);
    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    final root = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: root,
      child: MultiProvider(providers: providers!, child: const NiarimApp()),
    ));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(HomeScreen)))!;
    final chip = find.widgetWithText(FilterChip, l10n.homeFavoritesOnly);
    expect(chip, findsOneWidget);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    final selected = tester.widget<FilterChip>(chip);
    expect(selected.selected, isTrue);
    expect((selected.label as Text).style?.color, Colors.white);
    expect(selected.checkmarkColor, Colors.white);
    expect(selected.selectedColor,
        Theme.of(tester.element(chip)).colorScheme.primary);
    await capture(root, '03_selected_favorites_white', tester);
    await tester.pumpWidget(const SizedBox.shrink());
  }, timeout: const Timeout(Duration(minutes: 4)));
}
