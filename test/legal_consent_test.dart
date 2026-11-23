import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/legal_consent.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';

// Agreement to the Terms of Service and the Privacy Policy is asked before a
// Premium purchase, a Google sign-in and a post to the Work Plaza (owner's
// decision, 2026-11-23). Drawing never asks. The agreed version and time are
// saved on the device, and a new version asks again.
Widget _app(Locale locale, void Function(BuildContext) onReady) => MaterialApp(
  locale: locale,
  theme: ThemeService().themeData,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Builder(
    builder: (context) {
      onReady(context);
      return const Scaffold(body: SizedBox.expand());
    },
  ),
);

Future<BuildContext> _pumpApp(
  WidgetTester tester, {
  Locale locale = const Locale('ja'),
}) async {
  late BuildContext captured;
  await tester.pumpWidget(_app(locale, (context) => captured = context));
  return captured;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('asks first, and cancel saves nothing and stops the action', (
    tester,
  ) async {
    final context = await _pumpApp(tester);
    final result = ensureLegalConsent(context);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('legalConsentDialog')), findsOneWidget);
    expect(find.byKey(const Key('legalConsentReadTerms')), findsNothing);
    await tester.tap(find.byKey(const Key('legalConsentCancel')));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey(kLegalConsentVersionKey), isFalse);
    expect(preferences.containsKey(kLegalConsentAgreedAtKey), isFalse);
    expect(await hasCurrentLegalConsent(), isFalse);
  });

  testWidgets('agree saves the version and the time, and is not asked again', (
    tester,
  ) async {
    final context = await _pumpApp(tester);
    final before = DateTime.now().toUtc();
    final first = ensureLegalConsent(context);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('legalConsentAgree')));
    await tester.pumpAndSettle();
    expect(await first, isTrue);
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(kLegalConsentVersionKey),
      kLegalDocumentsVersion,
    );
    final agreedAt = DateTime.parse(
      preferences.getString(kLegalConsentAgreedAtKey)!,
    );
    expect(agreedAt.isUtc, isTrue);
    expect(
      agreedAt.isBefore(before.subtract(const Duration(seconds: 1))),
      isFalse,
    );

    final second = ensureLegalConsent(context);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('legalConsentDialog')), findsNothing);
    expect(await second, isTrue);
  });

  testWidgets('a new version of the documents asks again', (tester) async {
    SharedPreferences.setMockInitialValues({
      kLegalConsentVersionKey: '2026-01-01',
      kLegalConsentAgreedAtKey: '2026-01-01T00:00:00.000Z',
    });
    final context = await _pumpApp(tester);
    final result = ensureLegalConsent(context);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('legalConsentDialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('legalConsentAgree')));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    expect(await hasCurrentLegalConsent(), isTrue);
  });

  testWidgets('a saved value of another type is read as not agreed', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({kLegalConsentVersionKey: 20261123});
    final context = await _pumpApp(tester);
    final result = ensureLegalConsent(context);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('legalConsentDialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('legalConsentCancel')));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
  });

  testWidgets('the question fits at 320px with text twice as large', (
    tester,
  ) async {
    await loadAppFonts(tester);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final locale in AppLocalizations.supportedLocales) {
      late BuildContext captured;
      await tester.pumpWidget(_app(locale, (context) => captured = context));
      final result = ensureLegalConsent(captured);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$locale');
      final agree = find.byKey(const Key('legalConsentAgree'));
      await tester.ensureVisible(agree);
      await tester.pumpAndSettle();
      expect(agree.hitTestable(), findsOneWidget, reason: '$locale');
      await tester.tap(find.byKey(const Key('legalConsentCancel')));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    }
  });

  test('every sign-in, purchase and post asks for agreement first', () {
    // Each call that signs in, buys or posts is preceded in its function by
    // ensureLegalConsent. Checked on the source, so a new call site that
    // forgets the question fails here.
    final calls = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('google_auth_service.dart') ||
          entity.path.endsWith('premium_service.dart')) {
        continue;
      }
      final source = entity.readAsStringSync();
      for (final pattern in [
        RegExp(r'\.signInInteractively\(\)'),
        RegExp(r'premium\.buy\('),
      ]) {
        for (final match in pattern.allMatches(source)) {
          calls.add(entity.path);
          final before = source.substring(0, match.start);
          final consent = before.lastIndexOf('ensureLegalConsent(');
          final functionStart = before.lastIndexOf(
            RegExp(r'\n  (Future<[^>]*>|void|Widget) _?\w+\('),
          );
          expect(
            consent > functionStart,
            isTrue,
            reason: '${entity.path}: ${match[0]} without ensureLegalConsent',
          );
        }
      }
    }
    expect(calls, isNotEmpty);
  });
}
