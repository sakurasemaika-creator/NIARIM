import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/config/accent_text_theme.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/models/community_work.dart';
import 'package:niarim/screens/community/widgets/community_floating_preview.dart';
import 'package:niarim/screens/community/widgets/community_work_card.dart';
import 'package:niarim/services/community_preview_service.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/color_contrast.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 作品広場のカード・サムネイルの上の札・浮かぶプレビューの操作バーは、
/// テーマ・外観の色で描く（読みやすさのために黒・白へ差し替えない）。
/// 以前はカードの文字を黒・白へ差し替え、札は固定の黒地に白、プレビューの
/// 操作バーは下地と記号の両方が本文の文字色で、記号が下地に溶けていた。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final work = CommunityWork(
    id: 'fixture',
    title: 'Audit title',
    authorId: 'creator',
    authorName: 'Audit creator',
    viewCount: 1234,
    likeCount: 0,
    bookmarkCount: 56,
    postedAt: DateTime.utc(2026, 10, 24),
    durationSeconds: 75,
    thumbnailColorIndex: 0,
    isShort: true,
    isNiarimPublished: false,
  );

  Future<List<AppThemePreset>> themesToCheck() async {
    SharedPreferences.setMockInitialValues({});
    final service = ThemeService();
    await service.init();
    final presets = service.presets.toList();
    service.dispose();
    return [
      ...presets,
      // 本文の文字色がカードの下地に近く、以前なら黒・白へ差し替えられた色。
      AppThemePreset.defaultLight.copyWith(
        id: 'low_contrast',
        textColor: const Color(0xFFB0A8A0),
        menuBgColor: const Color(0xFF223344),
        menuTextColor: const Color(0xFFFFE08A),
      ),
    ];
  }

  Color menuColour(ThemeData theme) => opaqueOver(
    theme.appBarTheme.backgroundColor!,
    theme.scaffoldBackgroundColor,
  );

  testWidgets('work cards use the theme text and menu colours', (tester) async {
    final presets = await tester.runAsync(themesToCheck);
    final service = ThemeService();
    addTearDown(service.dispose);
    for (final preset in presets!) {
      service.previewCurrent(preset);
      final theme = service.themeData;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          themeAnimationDuration: Duration.zero,
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 220,
              height: 360,
              child: CommunityWorkCard(
                work: work,
                isBookmarked: true,
                onTap: () {},
                onBookmarkToggle: () {},
                onAuthorTap: () {},
                rankNumber: 3,
                repostedByAuthorName: 'Reposter',
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final why = preset.id;
      for (final title in tester.widgetList<Text>(find.text(work.title))) {
        expect(title.style?.color, preset.textColor, reason: why);
      }
      final ink = theme.appBarTheme.foregroundColor;
      final bookmark = tester.widget<Icon>(
        find.descendant(
          of: find.byType(IconButton),
          matching: find.byIcon(Icons.bookmark),
        ),
      );
      expect(bookmark.color, ink, reason: why);
      // 再生の印（サムネイルの上、大きさ28）。数の行の小さな再生の記号は
      // 本文の補足の文字色。
      final play = tester
          .widgetList<Icon>(find.byIcon(Icons.play_arrow_rounded))
          .firstWhere((icon) => icon.size == 28);
      expect(play.color, ink, reason: why);
      for (final badge in tester.widgetList<Container>(
        find.descendant(
          of: find.byType(Tooltip),
          matching: find.byType(Container),
        ),
      )) {
        final colour = (badge.decoration as BoxDecoration?)?.color;
        if (colour == null) continue;
        expect(colour, menuColour(theme).withValues(alpha: 0.88), reason: why);
      }
    }
  });

  testWidgets('the floating preview bar is readable in every theme', (
    tester,
  ) async {
    final presets = await tester.runAsync(themesToCheck);
    final theme = ThemeService();
    addTearDown(theme.dispose);
    final community = CommunityService();
    final preview = CommunityPreviewService();
    final shown = community.works.firstWhere((w) => w.isNiarimPublished);
    for (final preset in presets!) {
      theme.previewCurrent(preset);
      final data = theme.themeData;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CommunityService>.value(value: community),
            ChangeNotifierProvider<CommunityPreviewService>.value(
              value: preview,
            ),
            ChangeNotifierProvider<PremiumService>(
              create: (_) => PremiumService(),
            ),
          ],
          child: MaterialApp(
            theme: data,
            themeAnimationDuration: Duration.zero,
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: Stack(children: [CommunityFloatingPreview()]),
            ),
          ),
        ),
      );
      preview.show(shown);
      await tester.pump();
      final why = preset.id;
      final bar = menuColour(data);
      final ink = data.appBarTheme.foregroundColor!;
      final barBox = tester.widget<Container>(
        find
            .ancestor(
              of: find.byIcon(Icons.close),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(barBox.color, bar, reason: why);
      for (final icon in [
        Icons.close,
        Icons.open_in_full,
        if (find.byIcon(Icons.pause).evaluate().isNotEmpty)
          Icons.pause
        else
          Icons.play_arrow,
      ]) {
        expect(tester.widget<Icon>(find.byIcon(icon)).color, ink, reason: why);
      }
      // 右下のリサイズの記号は当たり判定の真ん中で、バーの他のボタン・
      // 「詳細へ」と同じ高さ（以前は32px四方の右下へ寄せていて、ウィンドウの
      // 右下にずれて見えた）。
      final handle = find.byKey(
        const Key('communityFloatingPreviewResizeHandle'),
      );
      final resize = tester.getCenter(find.byIcon(Icons.open_in_full));
      expect(resize, tester.getCenter(handle), reason: why);
      expect(
        resize.dy,
        moreOrLessEquals(tester.getCenter(find.byIcon(Icons.close)).dy),
        reason: why,
      );
      expect(
        resize.dy,
        moreOrLessEquals(tester.getCenter(find.byType(TextButton)).dy),
        reason: why,
      );
      // 以前は下地と記号が同じ色だった。メニューの文字はメニュー背景の上で
      // 読めることを救済判定が見張っている組み合わせ。
      expect(apcaContrast(ink, bar).abs(), greaterThan(30), reason: why);
      final detail = find.byType(TextButton);
      expect(
        tester.widget<TextButton>(detail).style!.foregroundColor!.resolve({}),
        AccentTextTheme.of(tester.element(detail)),
        reason: why,
      );
      preview.close();
      await tester.pump();
    }
  });

  test('tooltips take the inverse of the theme text and background', () {
    final service = ThemeService();
    addTearDown(service.dispose);
    for (final preset in [
      AppThemePreset.defaultLight,
      AppThemePreset.defaultDark,
      AppThemePreset.defaultLight.copyWith(
        textColor: const Color(0xFF0B3D2E),
        panelBgColor: const Color(0xFFF2FFF8),
      ),
    ]) {
      service.previewCurrent(preset);
      final theme = service.themeData;
      final box = theme.tooltipTheme.decoration! as BoxDecoration;
      expect(box.color, theme.colorScheme.inverseSurface);
      expect(box.color!.a, 1.0);
      expect(
        theme.tooltipTheme.textStyle!.color,
        theme.colorScheme.onInverseSurface,
      );
      expect(theme.colorScheme.onInverseSurface, preset.panelBgColor);
      expect(theme.tooltipTheme.textStyle!.fontFamily, 'HakkouMincho');
    }
  });
}
