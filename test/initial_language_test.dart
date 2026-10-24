import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/utils/app_locale.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 表示言語を一度も選んでいないときは、端末の言語で始まること。以前は
/// 端末の言語に関係なく日本語で始まっていた（英語・韓国語等の端末でも
/// 起動画面から設定まで日本語）。
void main() {
  final japaneseDevice = SettingsService.deviceLocales;
  tearDown(() => SettingsService.deviceLocales = japaneseDevice);

  test('device languages map to the seven supported languages', () {
    const cases = <List<Locale>, String>{
      [Locale('en', 'US')]: 'en',
      [Locale('fr', 'CA')]: 'fr',
      [Locale('es', 'MX')]: 'es',
      [Locale('ko', 'KR')]: 'ko',
      [Locale('ja', 'JP')]: 'ja',
      [Locale('zh', 'CN')]: 'zh',
      [Locale('zh', 'SG')]: 'zh',
      [Locale('zh', 'TW')]: 'zh_Hant',
      [Locale('zh', 'HK')]: 'zh_Hant',
      [Locale('zh', 'MO')]: 'zh_Hant',
      [Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')]: 'zh_Hant',
      [
        Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
          countryCode: 'HK',
        ),
      ]: 'zh',
      // 対応していない言語は飛ばし、次に優先する言語を使う。
      [Locale('de', 'DE'), Locale('fr', 'FR')]: 'fr',
      // どれも対応していなければ英語（ユーザー指定）。
      [Locale('de', 'DE')]: 'en',
      [Locale('pt', 'BR')]: 'en',
      []: 'en',
    };
    for (final MapEntry(key: locales, value: code) in cases.entries) {
      expect(appLanguageCodeFor(locales), code, reason: '$locales');
    }
  });

  test('an unsaved language follows the device and is not saved', () async {
    SharedPreferences.setMockInitialValues({});
    SettingsService.deviceLocales = () => const [Locale('ko', 'KR')];
    final settings = SettingsService();
    await settings.init();
    expect(settings.language, 'ko');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('language'), isFalse);
  });

  test('a chosen language is kept on any device', () async {
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    SettingsService.deviceLocales = () => const [Locale('en', 'US')];
    final settings = SettingsService();
    await settings.init();
    expect(settings.language, 'ja');
  });

  testWidgets('a first launch on an English device starts in English', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    SettingsService.deviceLocales = () => const [Locale('en', 'US')];
    final directory = Directory.systemTemp.createTempSync('initial_language_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => directory.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    appRouter.go('/');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pump(const Duration(milliseconds: 500));
    final english = lookupAppLocalizations(const Locale('en'));
    final japanese = lookupAppLocalizations(const Locale('ja'));
    expect(find.text(english.splashCreateButton), findsOneWidget);
    expect(find.text(japanese.splashCreateButton), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
