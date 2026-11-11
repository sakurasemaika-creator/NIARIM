// 作品広場の絞り込みの「〇分以内（スライダー）」で、スライダーの上に出る
// 長さ（「1分以内」「1 minute or less」）が、その言語の単数・複数で、数と
// 単位を空白なしでつなぐ言語では空白を入れずに出ることを、本物の作品広場の
// 画面で確かめる。
//
// 以前は'${分} ${l10n.communityDurationMinutes}'とコードで数と単位の語を
// つないでいて、英語・スペイン語・フランス語は1分で「1 minutes or less」
// 「1 minutos o menos」「1 minutes maximum」、日本語・中国語・韓国語は
// どの値でも「5 分以内」「1 分钟以内」のように数と単位の間に空白が入った。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/community/community_screen.dart';
import 'package:niarim/services/community_preview_service.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 言語ごとの、既定の5分・最小の1分・最大の60分の文。
const _expected = <String, Map<int, String>>{
  'ja': {5: '5分以内', 1: '1分以内', 60: '60分以内'},
  'en': {
    5: '5 minutes or less',
    1: '1 minute or less',
    60: '60 minutes or less',
  },
  'es': {
    5: '5 minutos o menos',
    1: '1 minuto o menos',
    60: '60 minutos o menos',
  },
  'fr': {
    5: '5 minutes maximum',
    1: '1 minute maximum',
    60: '60 minutes maximum',
  },
  'ko': {5: '5분 이하', 1: '1분 이하', 60: '60분 이하'},
  'zh': {5: '5分钟以内', 1: '1分钟以内', 60: '60分钟以内'},
  'zh_Hant': {5: '5分鐘以內', 1: '1分鐘以內', 60: '60分鐘以內'},
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'language': 'ja'}));

  const locales = <String, Locale>{
    'ja': Locale('ja'),
    'en': Locale('en'),
    'es': Locale('es'),
    'fr': Locale('fr'),
    'ko': Locale('ko'),
    'zh': Locale('zh'),
    'zh_Hant': Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  };

  for (final MapEntry(key: name, value: locale) in locales.entries) {
    testWidgets('「〇分以内」の長さがその言語の単数・複数で出る（$name）', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1600);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = CommunityService();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CommunityService>.value(value: service),
            ChangeNotifierProvider(create: (_) => SettingsService()),
            ChangeNotifierProvider(create: (_) => PremiumService()),
            ChangeNotifierProvider(create: (_) => GoogleAuthService()),
            ChangeNotifierProvider(create: (_) => CommunityPreviewService()),
          ],
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const CommunityScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> tapVisible(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      final l10n = lookupAppLocalizations(locale);
      await tapVisible(find.byKey(const Key('communityContentFilterButton')));
      expect(find.byType(AlertDialog), findsOneWidget);
      await tapVisible(find.byKey(const Key('communityDurationMode')));
      await tapVisible(find.text(l10n.communityDurationUpTo).last);
      final slider = find.byKey(const Key('communityDurationSlider'));
      expect(slider, findsOneWidget);

      final expected = _expected[name]!;
      expect(find.text(expected[5]!), findsOneWidget, reason: '$name: 既定の5分');
      await tester.ensureVisible(slider);
      await tester.drag(slider, const Offset(-2000, 0));
      await tester.pumpAndSettle();
      expect(find.text(expected[1]!), findsOneWidget, reason: '$name: 1分');
      await tester.drag(slider, const Offset(2000, 0));
      await tester.pumpAndSettle();
      expect(find.text(expected[60]!), findsOneWidget, reason: '$name: 60分');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
    });
  }
}
