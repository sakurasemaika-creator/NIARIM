import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/splash/splash_screen.dart';
import 'package:niarim/utils/line_break.dart';
import 'package:niarim/widgets/startup_failure_app.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 韓国語の語の途中で折り返さないよう字の間に入れる語結合子（U+2060）は、
/// 表示のためだけのもの。読み上げ（TalkBack）・点字には元の文を渡す
/// （以前は語結合子ごと渡り、音節ごとに区切りが入っていた）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const joiner = '\u2060';

  /// 画面の読み上げの木にある全ての読み上げの文。
  List<String> spokenLabels() => [
    for (final node in find.semantics.byPredicate((_) => true).evaluate())
      if (node.label.isNotEmpty) node.label,
  ];

  /// 語結合子を含む読み上げの文が無く、[expected]がそれぞれどこかで
  /// 元の文のまま読まれること。
  void expectSpokenPlainly(List<String> expected) {
    final labels = spokenLabels();
    expect(
      labels.where((label) => label.contains(joiner)).toList(),
      isEmpty,
      reason: 'labels: $labels',
    );
    for (final text in expected) {
      expect(
        labels.any((label) => label.contains(text)),
        isTrue,
        reason: '"$text" in $labels',
      );
    }
  }

  test('plainSemanticsLabel returns the text without word joiners', () {
    final shown = keepKoreanWordsTogether('애니메이션 만들기');
    expect(shown, contains(joiner));
    expect(plainSemanticsLabel(shown), '애니메이션 만들기');
    // 語結合子の無い文は、表示の文をそのまま読む（null）。
    expect(plainSemanticsLabel('作品をつくる'), isNull);
    expect(plainSemanticsLabel(''), isNull);
  });

  testWidgets('the Korean startup failure screen is read without word '
      'joiners', (tester) async {
    final handle = tester.ensureSemantics();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final gate = Completer<void>();
    await tester.pumpWidget(
      StartupFailureApp(
        details: 'step: brush\nerror: Bad state: boom',
        languageCode: 'ko',
        onRetry: () => gate.future,
      ),
    );
    await tester.pumpAndSettle();
    final l10n = lookupAppLocalizations(const Locale('ko'));
    // 表示は語の途中で折り返さないよう語結合子を入れたまま。
    expect(
      find.text(keepKoreanWordsTogether(l10n.startupFailedTitle)),
      findsOneWidget,
    );
    expectSpokenPlainly([
      l10n.startupFailedTitle,
      l10n.startupFailedBody,
      l10n.startupFailedRetry,
      l10n.startupFailedCopyDetails,
      l10n.startupFailedDetails,
    ]);

    await tester.tap(
      find.text(keepKoreanWordsTogether(l10n.startupFailedRetry)),
    );
    await tester.pump();
    expectSpokenPlainly([l10n.startupFailedRetrying]);
    gate.complete();
    await tester.pumpAndSettle();

    await tester.tap(
      find.text(keepKoreanWordsTogether(l10n.startupFailedCopyDetails)),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(keepKoreanWordsTogether(l10n.startupFailedDetailsCopied)),
      findsOneWidget,
    );
    expectSpokenPlainly([l10n.startupFailedDetailsCopied]);

    await tester.tap(
      find.text(keepKoreanWordsTogether(l10n.startupFailedDetails)),
    );
    await tester.pumpAndSettle();
    expectSpokenPlainly([l10n.startupFailedDetails]);
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  group('splash', () {
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    late Directory tempDir;
    setUp(() {
      SharedPreferences.setMockInitialValues({'first_launch': false});
      tempDir = Directory.systemTemp.createTempSync('niarim_joiner_splash_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    testWidgets('the Korean entry tiles are read without word joiners', (
      tester,
    ) async {
      final providers = (await tester.runAsync(buildAppProviders))!;
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MultiProvider(
          providers: providers,
          child: const MaterialApp(
            locale: Locale('ko'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: SplashScreen(),
          ),
        ),
      );
      await tester.pump();
      final l10n = lookupAppLocalizations(const Locale('ko'));
      expect(
        find.text(keepKoreanWordsTogether(l10n.splashCreateButton)),
        findsOneWidget,
      );
      expectSpokenPlainly([
        '${l10n.splashCommunityButtonTitle}\n'
            '${l10n.splashCommunityButtonSubtitle}',
        l10n.splashCreateButton,
      ]);
      // 1つのボタンとして、題と副題をそのままの文で読む。
      expect(
        tester.getSemantics(
          find.text(keepKoreanWordsTogether(l10n.splashCreateButton)),
        ),
        matchesSemantics(
          label: l10n.splashCreateButton,
          isButton: true,
          hasTapAction: true,
          isFocusable: true,
          hasFocusAction: true,
        ),
      );
      handle.dispose();
    });
  });
}
