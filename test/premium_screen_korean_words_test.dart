// プレミアムの画面の文が、韓国語で語の途中で折れない（P4-13）。
//
// ストアから値段を読めなかったときの「스토어에서 구매 정보를 불러오지
// 못했습니다. 연결을 확인하고 다시 시도해 주세요.」が、412pxで「다시 시 /
// 도해 주세요」と語の途中で折れた（Flutterはハングルのどの字の間でも行を
// 変える）。同じ画面のほかの文（比べる表の注記・購入中・加入中の日付・主な
// 違い・プランの題・比べる表の機能名）も普通の Text だった。
//
// 韓国語ほか7言語×320/360/412px×文字1.0/1.3/2.0で、値段を読めなかったとき・
// 購入中・加入中の画面の文が、1行に入る語を途中で折らないことを見張る。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/premium/premium_screen.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';
import 'helpers/paragraph_lines.dart';
import 'helpers/word_breaks.dart';

class _Store extends PremiumService {
  _Store({this.pending = false, this.purchased = false});

  final bool pending;
  final bool purchased;

  @override
  bool get storeAvailable => false;

  @override
  bool get purchasePending => pending;

  @override
  bool get hasPurchasedPremium => purchased;

  @override
  DateTime? get purchaseDate => purchased ? DateTime(2026, 11, 3) : null;

  @override
  DateTime? get nextRenewalDate => purchased ? DateTime(2026, 12, 3) : null;

  @override
  Future<void> refreshStoreProducts() async {}
}

void main() {
  var fontsLoaded = false;
  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
    binding.platformDispatcher.clearTextScaleFactorTestValue();
  });

  for (final locale in AppLocalizations.supportedLocales) {
    final tag = locale.toLanguageTag();
    for (final (state, store) in [
      ('store unavailable', () => _Store()),
      ('checkout pending', () => _Store(pending: true)),
      ('premium member', () => _Store(purchased: true)),
    ]) {
      testWidgets('premium texts keep their words ($tag, $state)', (
        tester,
      ) async {
        if (!fontsLoaded) {
          await loadAppFonts(tester);
          fontsLoaded = true;
        }
        SharedPreferences.setMockInitialValues({});
        final premium = store();
        addTearDown(premium.dispose);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(412, 20000);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<PremiumService>.value(value: premium),
              ChangeNotifierProvider(create: (_) => SettingsService()),
            ],
            child: MaterialApp(
              locale: locale,
              theme: ThemeService().themeDataFor(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const PremiumScreen(),
            ),
          ),
        );
        // 購入中は回る印が止まらないので、決まった時間だけ進める。
        Future<void> settle() async {
          for (var i = 0; i < 4; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        }

        await settle();
        final l10n = lookupAppLocalizations(locale);
        final problems = <String>[];
        for (final width in [320.0, 360.0, 412.0]) {
          for (final scale in [1.0, 1.3, 2.0]) {
            tester.view.physicalSize = Size(width, 20000);
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            await settle();
            final at = '${width.toInt()}px x$scale';
            final error = tester.takeException();
            if (error != null) problems.add('$at: $error');
            final body = find.byType(PremiumScreen);
            for (final paragraph in textParagraphsIn(body)) {
              for (final broken in wordsBrokenThatFit(paragraph)) {
                problems.add('$at: $broken');
              }
            }
            if (state == 'store unavailable') {
              final notice = ParagraphLines(
                textParagraphsIn(
                  find.text(l10n.premiumStoreUnavailable),
                ).single,
              );
              if (notice.visible != l10n.premiumStoreUnavailable) {
                problems.add('$at: the store notice is cut: ${notice.lines}');
              }
            }
          }
        }
        for (final problem in problems.take(12)) {
          debugPrint('$tag $state $problem');
        }
        expect(problems, isEmpty, reason: '${problems.length} problems');
      });
    }
  }
}
