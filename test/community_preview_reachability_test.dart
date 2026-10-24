import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/community/widgets/community_floating_preview.dart';
import 'package:niarim/services/community_preview_service.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';

/// 浮かぶプレビューの操作は、どの画面の大きさ・文字の大きさでも画面の中に
/// あること。以前は幅320の端末で最小幅356のまま右へはみ出し、「詳細へ」と
/// 拡大縮小の取っ手が画面の外にあった。高さが足りない画面（分割画面）では
/// 操作バーが画面の下へ切れて、閉じることもできなかった。
void main() {
  testWidgets('every preview control stays on screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final themes = ThemeService();
    await themes.init();
    addTearDown(themes.dispose);
    final community = CommunityService();
    final shown = community.works.firstWhere((w) => w.isNiarimPublished);
    await loadAppFonts(tester);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final screen in const [
      Size(320, 700),
      Size(340, 720),
      Size(360, 640),
      Size(412, 915),
      Size(640, 360),
      Size(640, 220),
      Size(1280, 800),
    ]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        for (final locale in AppLocalizations.supportedLocales) {
          tester.view.physicalSize = screen;
          final preview = CommunityPreviewService();
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<CommunityService>.value(
                  value: community,
                ),
                ChangeNotifierProvider<CommunityPreviewService>.value(
                  value: preview,
                ),
                ChangeNotifierProvider<PremiumService>(
                  create: (_) => PremiumService(),
                ),
              ],
              child: MaterialApp(
                theme: themes.themeData,
                locale: locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: const Scaffold(
                  body: Stack(children: [CommunityFloatingPreview()]),
                ),
              ),
            ),
          );
          preview.show(shown);
          await tester.pump();
          final why = '${screen.width}x${screen.height} x$scale $locale';
          expect(tester.takeException(), isNull, reason: why);
          final bounds = Offset.zero & screen;
          void onScreen(Finder finder, String what) {
            expect(finder, findsOneWidget, reason: '$why $what');
            final rect = tester.getRect(finder);
            expect(
              bounds.contains(rect.topLeft) &&
                  bounds.contains(rect.bottomRight - const Offset(0.01, 0.01)),
              isTrue,
              reason: '$why $what at $rect',
            );
          }

          onScreen(find.byIcon(Icons.close), 'close');
          onScreen(find.byType(TextButton), 'detail');
          final compact = find.byKey(
            const Key('communityFloatingPreviewCompactBar'),
          );
          if (compact.evaluate().isEmpty) {
            onScreen(
              find.byKey(const Key('communityFloatingPreviewResizeHandle')),
              'resize',
            );
            onScreen(
              find.byIcon(Icons.pause).evaluate().isNotEmpty
                  ? find.byIcon(Icons.pause)
                  : find.byIcon(Icons.play_arrow),
              'pause',
            );
            final player = preview.playerSizeFor(screen.width);
            expect(player.width, greaterThanOrEqualTo(200), reason: why);
            expect(player.height, greaterThanOrEqualTo(200), reason: why);
          } else {
            // プレーヤーを置けない高さのときだけ操作バーだけになる。
            expect(screen.height, lessThan(360), reason: why);
            onScreen(compact, 'compact bar');
          }
        }
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
