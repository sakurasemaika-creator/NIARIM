import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/utils/app_error_reporter.dart';
import 'package:niarim/utils/app_locale.dart';
import 'package:niarim/utils/tolerant_preferences.dart';
import 'package:niarim/widgets/startup_failure_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 起動処理の途中で初期化が失敗したとき、それまでに作ったServiceが
/// 片付けられ、同じプロセスで起動をやり直せることを確かめる。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() {
    SharedPreferences.setMockInitialValues({'language': 'en'});
    tempDir = Directory.systemTemp.createTempSync('niarim_startup_failure_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<List<String>> recordSteps() async {
    final steps = <String>[];
    final created = <ChangeNotifier>[];
    final providers = await buildAppProviders(
      beforeStep: steps.add,
      debugOnCreated: created.add,
    );
    expect(providers, isNotEmpty);
    for (final service in created.reversed) {
      service.dispose();
    }
    return steps;
  }

  test('every startup step can fail, rolls back what it built and a retry '
      'starts cleanly', () async {
    final steps = await recordSteps();
    expect(steps.first, 'settings');
    expect(steps, contains('share_intent'));
    expect(steps.toSet().length, steps.length, reason: 'names are unique');

    for (final failing in steps) {
      final created = <ChangeNotifier>[];
      final disposeErrors = <String>[];
      final previousDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message != null && message.contains('Could not dispose')) {
          disposeErrors.add(message);
        }
      };
      AppStartupException? failure;
      try {
        await buildAppProviders(
          beforeStep: (step) {
            if (step == failing) throw StateError('boom at $step');
          },
          debugOnCreated: created.add,
        );
      } on AppStartupException catch (error) {
        failure = error;
      } finally {
        debugPrint = previousDebugPrint;
      }

      expect(failure, isNotNull, reason: 'failing at $failing');
      expect(failure!.step, failing);
      expect(failure.error, isA<StateError>());
      expect(
        failure.languageCode,
        failing == 'settings' ? isNull : 'en',
        reason: 'language is known once settings loaded ($failing)',
      );
      expect(disposeErrors, isEmpty, reason: 'rollback at $failing');
      for (final service in created) {
        expect(
          () => ChangeNotifier.debugAssertNotDisposed(service),
          throwsFlutterError,
          reason: '${service.runtimeType} built before $failing is disposed',
        );
      }

      // The same process can start again right away.
      final retried = <ChangeNotifier>[];
      final providers = await buildAppProviders(debugOnCreated: retried.add);
      expect(providers, isNotEmpty, reason: 'retry after $failing');
      for (final service in retried.reversed) {
        service.dispose();
      }
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('a failing initializer reports the step that failed', () async {
    await expectLater(
      buildAppProviders(
        beforeStep: (step) async {
          if (step == 'theme') throw const FormatException('broken theme');
        },
      ),
      throwsA(
        isA<AppStartupException>()
            .having((e) => e.step, 'step', 'theme')
            .having((e) => e.error, 'error', isA<FormatException>())
            .having((e) => '$e', 'message', contains('theme')),
      ),
    );
  });

  test(
    'preferences saved with another type do not stop startup and are kept',
    () async {
      // Every literal key read through the typed helpers gets a value of
      // a different type, as after a format change between versions.
      final pattern = RegExp(
        r"prefs\.read(Int|Bool|Double|String|StringList)\(\s*'([^'$]+)'",
      );
      final corrupt = <String, Object>{};
      for (final file in Directory('lib').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        for (final match in pattern.allMatches(file.readAsStringSync())) {
          final key = match.group(2)!;
          corrupt[key] = switch (match.group(1)) {
            'String' || 'StringList' => 7,
            _ => 'not-a-number',
          };
        }
      }
      expect(corrupt.length, greaterThan(50));
      SharedPreferences.setMockInitialValues(corrupt);
      AppErrorReporter.recentErrors.clear();

      final created = <ChangeNotifier>[];
      final providers = await buildAppProviders(debugOnCreated: created.add);
      expect(providers, isNotEmpty);
      // Each skipped value is recorded (the log keeps the newest ones).
      expect(AppErrorReporter.recentErrors, isNotEmpty);
      expect(
        AppErrorReporter.recentErrors,
        everyElement(contains('Ignored preference')),
      );

      // Unreadable values are left as they were (startup reads, it does
      // not repair by overwriting). The only exception is the device
      // performance level, which is detected again and saved exactly as on
      // a first launch when no readable level exists.
      const redetected = {'quality_level', 'default_preset'};
      final prefs = await SharedPreferences.getInstance();
      final rewritten = corrupt.keys
          .where((key) => !redetected.contains(key))
          .where((key) => prefs.get(key) != corrupt[key])
          .toList();
      expect(
        rewritten,
        isEmpty,
        reason: 'startup overwrote unreadable values: $rewritten',
      );
      for (final service in created.reversed) {
        service.dispose();
      }
    },
  );

  test('saved settings are read through the tolerant helpers only', () {
    // SharedPreferences.getInt etc. throw when the stored type differs,
    // which stops startup for good (see TolerantPreferences).
    final direct = RegExp(r'prefs\.get(Int|Bool|Double|String|StringList)\(');
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (direct.hasMatch(file.readAsStringSync())) offenders.add(file.path);
    }
    expect(offenders, isEmpty);
  });

  test('tolerant reads return null for another type', () async {
    SharedPreferences.setMockInitialValues({
      'b': 'x',
      'i': 1.5,
      'd': 3,
      's': true,
      'l': ['a', 'b'],
      'ok_b': true,
      'ok_i': 4,
      'ok_d': 2.5,
      'ok_s': 'v',
    });
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.readBool('b'), isNull);
    expect(prefs.readInt('i'), isNull);
    expect(prefs.readDouble('d'), 3.0, reason: 'an int is read as a double');
    expect(prefs.readString('s'), isNull);
    expect(prefs.readStringList('l'), ['a', 'b']);
    expect(prefs.readStringList('s'), isNull);
    expect(prefs.readBool('ok_b'), isTrue);
    expect(prefs.readInt('ok_i'), 4);
    expect(prefs.readDouble('ok_d'), 2.5);
    expect(prefs.readString('ok_s'), 'v');
    expect(prefs.readString('missing'), isNull);
  });

  group('StartupFailureApp', () {
    Future<void> pumpFailure(
      WidgetTester tester, {
      required Future<void> Function() onRetry,
      String? languageCode,
    }) async {
      await tester.pumpWidget(
        StartupFailureApp(
          details: 'step: brush\nerror: Bad state: boom',
          languageCode: languageCode,
          onRetry: onRetry,
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final locale in AppLocalizations.supportedLocales) {
      final code = locale.scriptCode == 'Hant'
          ? 'zh_Hant'
          : locale.languageCode;
      testWidgets('shows the saved language ($code)', (tester) async {
        await pumpFailure(tester, onRetry: () async {}, languageCode: code);
        final l10n = lookupAppLocalizations(localeFromLanguageCode(code));
        expect(find.text(l10n.startupFailedTitle), findsOneWidget);
        expect(find.text(l10n.startupFailedBody), findsOneWidget);
        expect(find.text(l10n.startupFailedRetry), findsOneWidget);
        expect(find.text(l10n.startupFailedCopyDetails), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('falls back to the device language without a saved one', (
      tester,
    ) async {
      tester.platformDispatcher.localesTestValue = const [Locale('ko', 'KR')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await pumpFailure(tester, onRetry: () async {});
      expect(
        find.text(
          lookupAppLocalizations(const Locale('ko')).startupFailedTitle,
        ),
        findsOneWidget,
      );
    });

    testWidgets('retry runs once and shows progress while it runs', (
      tester,
    ) async {
      var calls = 0;
      final gate = Completer<void>();
      await pumpFailure(
        tester,
        languageCode: 'ja',
        onRetry: () {
          calls++;
          return gate.future;
        },
      );
      final l10n = lookupAppLocalizations(const Locale('ja'));
      await tester.tap(find.text(l10n.startupFailedRetry));
      await tester.pump();
      expect(calls, 1);
      expect(find.text(l10n.startupFailedRetrying), findsOneWidget);
      // A second tap while retrying does nothing.
      await tester.tap(find.text(l10n.startupFailedRetrying));
      await tester.pump();
      expect(calls, 1);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text(l10n.startupFailedRetry), findsOneWidget);
    });

    testWidgets('copies the details for reporting', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpFailure(tester, languageCode: 'en', onRetry: () async {});
      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(l10n.startupFailedCopyDetails));
      await tester.pumpAndSettle();
      expect(copied, contains('step: brush'));
      expect(find.text(l10n.startupFailedDetailsCopied), findsOneWidget);

      await tester.tap(find.text(l10n.startupFailedDetails));
      await tester.pumpAndSettle();
      expect(find.textContaining('Bad state: boom'), findsOneWidget);
    });
  });

  group('appLocalizationsFor', () {
    test('picks traditional Chinese for Taiwan without a script code', () {
      expect(
        appLocalizationsFor(const Locale('zh', 'TW')).localeName,
        'zh_Hant',
      );
      expect(appLocalizationsFor(const Locale('zh', 'CN')).localeName, 'zh');
    });

    test('falls back to Japanese for unsupported languages', () {
      expect(appLocalizationsFor(const Locale('de')).localeName, 'ja');
      expect(appLocalizationsFor(null).localeName, 'ja');
      expect(appLocalizationsFor(const Locale('fr', 'CA')).localeName, 'fr');
    });
  });
}
