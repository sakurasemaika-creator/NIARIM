import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/settings/error_log_screen.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/utils/app_error_reporter.dart';
import 'package:niarim/utils/app_locale.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 設定の「エラーの記録」：アプリで起きたエラーを見て、まとめてコピーし、
/// 消せること。以前は記録されるだけで、起動に失敗した画面以外からは
/// 見る手段が無かった。
void main() {
  setUp(AppErrorReporter.recentErrors.clear);
  tearDown(AppErrorReporter.recentErrors.clear);

  test('personal and sign-in details are masked', () {
    final masked = AppErrorReporter.maskPersonalDetails(
      'HttpException: 401 for user taro.yamada+art@example.co.jp '
      'Authorization: Bearer abc.def-123 '
      'token eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiIxIn0.c2lnbmF0dXJl '
      'https://api.example.com/works?id_token=secret123&page=2&key=AIzaXyz',
    );
    expect(masked, isNot(contains('taro.yamada')));
    expect(masked, isNot(contains('abc.def-123')));
    expect(masked, isNot(contains('eyJhbGci')));
    expect(masked, isNot(contains('secret123')));
    expect(masked, isNot(contains('AIzaXyz')));
    expect(masked, contains('[email]'));
    expect(masked, contains('Bearer [token]'));
    expect(masked, contains('id_token=[hidden]'));
    // 原因を探すのに要る部分は残す。
    expect(masked, contains('HttpException: 401'));
    expect(masked, contains('page=2'));
    expect(
      AppErrorReporter.maskPersonalDetails('RangeError: index 3'),
      'RangeError: index 3',
    );
  });

  test('entries carry the time and are kept short', () {
    AppErrorReporter.record('x' * 5000, null);
    final entry = AppErrorReporter.recentErrors.single;
    expect(entry, matches(RegExp(r'^\[\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\] x+…$')));
    expect(entry.length, lessThan(2100));
  });

  Widget screen(Locale locale, {double scale = 1.0}) =>
      ChangeNotifierProvider<SettingsService>(
        create: (_) => SettingsService(),
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const ErrorLogScreen(),
        ),
      );

  testWidgets('errors can be read, copied and cleared', (tester) async {
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    AppErrorReporter.record(StateError('older problem'), null);
    AppErrorReporter.record(StateError('newer problem'), null);
    await tester.pumpWidget(screen(const Locale('ja')));
    final l10n = lookupAppLocalizations(const Locale('ja'));
    final newer = find.textContaining('newer problem');
    final older = find.textContaining('older problem');
    expect(newer, findsOneWidget);
    expect(older, findsOneWidget);
    // 新しい順。
    expect(tester.getTopLeft(newer).dy, lessThan(tester.getTopLeft(older).dy));

    await tester.tap(find.byKey(const Key('errorLogCopyAll')));
    await tester.pump();
    expect(copied, contains('newer problem'));
    expect(copied, contains('older problem'));
    expect(find.text(l10n.errorLogCopied), findsOneWidget);

    await tester.tap(find.byKey(const Key('errorLogClear')));
    await tester.pump();
    expect(AppErrorReporter.recentErrors, isEmpty);
    expect(find.text(l10n.errorLogEmpty), findsOneWidget);
  });

  testWidgets('the screen fits every language and large text', (tester) async {
    AppErrorReporter.record(StateError('a problem ' * 30), null);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final locale in AppLocalizations.supportedLocales) {
      for (final scale in [1.0, 2.0]) {
        await tester.pumpWidget(
          KeyedSubtree(
            key: ValueKey('$locale $scale'),
            child: screen(locale, scale: scale),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$locale x$scale');
        final l10n = appLocalizationsFor(locale);
        // 大きな文字では説明の下になるので、スクロールして届くこと。
        final copy = find.text(l10n.errorLogCopyAll, skipOffstage: false);
        expect(copy, findsOneWidget, reason: '$locale x$scale');
        await tester.ensureVisible(copy);
        await tester.pump();
        final rect = tester.getRect(copy);
        expect(rect.bottom, lessThanOrEqualTo(640), reason: '$locale x$scale');
        expect(rect.right, lessThanOrEqualTo(320), reason: '$locale x$scale');
      }
    }
  });

  testWidgets('settings lead to the error log', (tester) async {
    SharedPreferences.setMockInitialValues({'first_launch': false});
    final directory = Directory.systemTemp.createTempSync('error_log_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => directory.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    appRouter.go('/settings');
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final l10n = lookupAppLocalizations(const Locale('ja'));
    final tile = find.text(l10n.settingsErrorLogTitle);
    await tester.scrollUntilVisible(
      tile,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(tile);
    await tester.pump();
    await tester.tap(tile);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(ErrorLogScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
