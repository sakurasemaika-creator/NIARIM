import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/screens/community/widgets/community_work_card.dart';
import 'package:niarim/screens/settings/theme_preview_gallery_screen.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/color_contrast.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// テーマ・外観の見本（作品広場・作品詳細・投稿者の作品）が、
/// 実際の作品広場と同じ色の役目で描かれること：サムネイルは
/// `communityThumbnailGradient`、カードの上の再生の印・ブックマーク・時間の札は
/// 上部バーの背景色（ほぼ不透明）の上に上部バーの文字色、作品詳細の再生の印は
/// 本文の文字色を薄くしたもの。以前は固定のピンクの絵と黒地に白の印で、
/// テーマを変えても見本だけ実際の画面と違う色のままだった。
void main() {
  // 見分けやすいよう、メニュー（上部バー）の色を本文・差し色と別にしたテーマ。
  final preset = AppThemePreset.defaultLight.copyWith(
    menuBgColor: const Color(0xFF203A5C),
    menuTextColor: const Color(0xFFF4E3A1),
  );

  Future<ThemeData> open(WidgetTester tester, String id) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final service = ThemeService();
    await tester.runAsync(service.init);
    service.previewCurrent(preset);
    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeService>.value(
        value: service,
        child: MaterialApp(
          locale: const Locale('ja'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: service.themeData,
          home: const ThemePreviewGalleryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final pages = tester.widget<PageView>(
      find.byKey(const Key('themePreviewPager')),
    );
    pages.controller!.jumpToPage(
      themePreviewEntries.indexWhere((e) => e.id == id),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    return service.themeData;
  }

  List<List<Color>> thumbnailGradients(WidgetTester tester) => tester
      .widgetList<DecoratedBox>(find.byType(DecoratedBox))
      .map((box) => box.decoration)
      .whereType<BoxDecoration>()
      .map((d) => d.gradient)
      .whereType<LinearGradient>()
      .map((g) => g.colors)
      .toList();

  void expectOverlayIcon(
    WidgetTester tester,
    IconData icon,
    ThemeData theme,
    String where,
  ) {
    final card = theme.colorScheme.surface;
    final overlay = opaqueOver(
      theme.appBarTheme.backgroundColor!,
      card,
    ).withValues(alpha: 0.88);
    final icons = find.byIcon(icon);
    expect(icons, findsWidgets, reason: '$where $icon');
    for (final element in icons.evaluate()) {
      expect(
        (element.widget as Icon).color,
        preset.menuTextColor,
        reason: '$where $icon ink',
      );
      final circle = find.ancestor(
        of: find.byWidget(element.widget),
        matching: find.byType(Container),
      );
      final decoration =
          tester.widget<Container>(circle.first).decoration as BoxDecoration;
      expect(decoration.color, overlay, reason: '$where $icon ground');
    }
  }

  for (final id in ['community', 'author']) {
    testWidgets('$id cards use the Work Plaza thumbnail and overlay roles', (
      tester,
    ) async {
      final theme = await open(tester, id);
      final scheme = theme.colorScheme;
      final real = communityThumbnailGradients(scheme);
      final drawn = thumbnailGradients(tester);
      expect(
        drawn.where((g) => real.any((r) => listEquals(r, g))),
        isNotEmpty,
        reason: '$id thumbnails use communityThumbnailGradient',
      );
      for (final g in drawn) {
        for (final colour in g) {
          expect(
            colour,
            isNot(anyOf(const Color(0xFFFFB9C8), const Color(0xFFFF6485))),
            reason: '$id no fixed pink artwork',
          );
        }
      }
      expectOverlayIcon(tester, Icons.play_arrow_rounded, theme, id);
      expectOverlayIcon(tester, Icons.bookmark_border, theme, id);
    });
  }

  testWidgets('work detail matches the real detail screen', (tester) async {
    final theme = await open(tester, 'work');
    final scheme = theme.colorScheme;
    final play = tester.widget<Icon>(
      find.byIcon(Icons.play_circle_fill_rounded),
    );
    expect(play.color, scheme.onSurface.withValues(alpha: .7));
    expect(
      thumbnailGradients(
        tester,
      ).any((g) => listEquals(g, communityThumbnailGradient(scheme, 1))),
      isTrue,
    );
  });

  testWidgets('Work Plaza header and cards use the bar and card roles', (
    tester,
  ) async {
    final theme = await open(tester, 'community');
    // 1段目：戻る・画面名・通知・ヘルプは上部バーの文字色。
    final title = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('themePreviewPager')),
        matching: find.text('作品広場'),
      ),
    );
    expect(title.style!.color, preset.menuTextColor);
    expect(title.style!.fontFamily, 'Kuramubon');
    for (final icon in [
      Icons.arrow_back,
      Icons.notifications_none,
      Icons.help_outline,
      Icons.tune,
    ]) {
      expect(
        tester.widget<Icon>(find.byIcon(icon)).color,
        preset.menuTextColor,
        reason: '$icon',
      );
    }
    // 2段目の左に検索窓、右にフィルター。
    final search = tester.getRect(find.text('作品タイトル・投稿者名で検索'));
    final tune = tester.getRect(find.byIcon(Icons.tune));
    expect(search.center.dx, lessThan(tune.center.dx));
    expect((search.center.dy - tune.center.dy).abs(), lessThan(12));
    expect(
      tester.getRect(find.byIcon(Icons.help_outline)).center.dy,
      lessThan(search.top),
    );
    // カードはテーマのカードの色（メニュー背景色）で、枠を付けない。
    final cards = tester.widgetList<Card>(find.byType(Card)).toList();
    expect(cards, isNotEmpty);
    for (final card in cards) {
      expect(card.color, isNull, reason: 'theme card colour');
      final shape = card.shape! as RoundedRectangleBorder;
      expect(shape.side, BorderSide.none);
    }
    expect(
      theme.cardTheme.color,
      opaqueOver(preset.menuBgColor, preset.panelBgColor),
    );
    // カードの作品名は見出しの書体。
    final cardTitle = tester.widget<Text>(find.text('雨上がりの約束').first);
    expect(cardTitle.style!.fontFamily, 'Kuramubon');
  });

  testWidgets('splash tiles use the heading font like the real splash', (
    tester,
  ) async {
    await open(tester, 'splash');
    for (final label in ['作品広場', '作品をつくる']) {
      final text = tester.widget<Text>(find.text(label));
      expect(text.style!.fontFamily, 'Kuramubon', reason: label);
    }
  });
}
