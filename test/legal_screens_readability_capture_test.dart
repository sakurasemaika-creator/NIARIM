import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/settings/error_log_screen.dart';
import 'package:niarim/screens/settings/license_screen.dart';
import 'package:niarim/screens/settings/privacy_policy_screen.dart';
import 'package:niarim/services/advertising_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/utils/app_error_reporter.dart';
import 'package:provider/provider.dart';

const _captureLocales = <Locale>[Locale('fr'), Locale('ko')];

Widget _largeTextApp(Locale locale, Widget home) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: home,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
    child: child!,
  ),
);

Future<void> _capture(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String name,
) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(boundaryKey),
  );
  final image = await boundary.toImage(pixelRatio: 1);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final directory = Directory('build/legal-ui-captures')
    ..createSync(recursive: true);
  File(
    '${directory.path}/$name.png',
  ).writeAsBytesSync(bytes!.buffer.asUint8List());
  image.dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppErrorReporter.recentErrors.clear();
  });

  tearDown(() {
    AppErrorReporter.recentErrors.clear();
  });

  testWidgets('privacy policy remains readable at 200% text in every locale', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final locale in AppLocalizations.supportedLocales) {
      final premium = PremiumService();
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: ChangeNotifierProvider<AdvertisingService>(
            create: (_) => AdvertisingService(premiumService: premium),
            child: _largeTextApp(locale, const PrivacyPolicyScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(locale);
      final paragraphFinder = find.text(l10n.privacyPolicyArt1Body);
      expect(paragraphFinder, findsOneWidget, reason: locale.toLanguageTag());
      final paragraph = tester.widget<Text>(paragraphFinder);
      expect(paragraph.style?.fontSize, 14);
      expect(paragraph.style?.height, 1.65);
      expect(tester.takeException(), isNull, reason: locale.toLanguageTag());

      if (_captureLocales.contains(locale)) {
        await _capture(
          tester,
          boundaryKey,
          'privacy_${locale.languageCode}_top',
        );
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -420));
        await tester.pumpAndSettle();
        await _capture(
          tester,
          boundaryKey,
          'privacy_${locale.languageCode}_middle',
        );
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      premium.dispose();
    }
  });

  testWidgets(
    'terms and license credits remain readable at 200% text in every locale',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      for (final locale in AppLocalizations.supportedLocales) {
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: _largeTextApp(locale, const LicenseScreen()),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(locale);
        final paragraphFinder = find.text(l10n.licenseTermsArt1Body);
        expect(paragraphFinder, findsOneWidget, reason: locale.toLanguageTag());
        final paragraph = tester.widget<Text>(paragraphFinder);
        expect(paragraph.style?.fontSize, 14);
        expect(paragraph.style?.height, 1.65);
        expect(tester.takeException(), isNull, reason: locale.toLanguageTag());

        if (_captureLocales.contains(locale)) {
          await _capture(
            tester,
            boundaryKey,
            'license_${locale.languageCode}_top',
          );
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -420),
          );
          await tester.pumpAndSettle();
          await _capture(
            tester,
            boundaryKey,
            'license_${locale.languageCode}_middle',
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets('error log actions and long entries fit at 200% text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final longLayout = List.filled(
      18,
      'responsive state and safe area details',
    ).join(' / ');
    final longRendering = List.filled(
      12,
      'long localized message wrapping',
    ).join(' / ');
    AppErrorReporter.recentErrors.addAll([
      '[2026-11-21 09:30:00] Layout sample: $longLayout',
      '[2026-11-21 09:29:00] Rendering sample: $longRendering',
    ]);

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: _largeTextApp(const Locale('fr'), const ErrorLogScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final copy = find.byKey(const Key('errorLogCopyAll'));
    final clear = find.byKey(const Key('errorLogClear'));
    expect(copy, findsOneWidget);
    expect(clear, findsOneWidget);
    expect(tester.getRect(copy).left, greaterThanOrEqualTo(0));
    expect(tester.getRect(copy).right, lessThanOrEqualTo(320));
    expect(tester.getRect(clear).left, greaterThanOrEqualTo(0));
    expect(tester.getRect(clear).right, lessThanOrEqualTo(320));
    expect(
      tester
          .widget<SelectableText>(find.byType(SelectableText).first)
          .style
          ?.fontSize,
      14,
    );
    expect(tester.takeException(), isNull);
    await _capture(tester, boundaryKey, 'error_log_fr');
  });
}
