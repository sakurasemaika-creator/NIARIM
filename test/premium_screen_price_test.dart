import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/premium/premium_screen.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';

class _Store extends PremiumService {
  _Store({required this.storeAvailable, this.products = const []});

  @override
  final bool storeAvailable;
  @override
  final List<ProductDetails> products;

  int retries = 0;

  @override
  Future<void> refreshStoreProducts() async => retries++;
}

void main() {
  Future<AppLocalizations> show(WidgetTester tester, _Store store) async {
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PremiumService>.value(value: store),
          ChangeNotifierProvider(create: (_) => SettingsService()),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PremiumScreen(),
        ),
      ),
    );
    return AppLocalizations.of(tester.element(find.byType(PremiumScreen)))!;
  }

  testWidgets('plans use storefront prices in the returned currency', (
    tester,
  ) async {
    ProductDetails product(String id, String price, double value) =>
        ProductDetails(
          id: id,
          title: 'NIARIM Premium',
          description: '',
          price: price,
          rawPrice: value,
          currencyCode: 'EUR',
        );

    final words = await show(
      tester,
      _Store(
        storeAvailable: true,
        products: [
          product(PremiumService.monthlyProductId, '4,49 €', 4.49),
          product(PremiumService.yearlyProductId, '45,99 €', 45.99),
        ],
      ),
    );
    expect(find.text('4,49 €'), findsOneWidget);
    expect(find.text('45,99 €'), findsOneWidget);
    expect(find.text(words.premiumYearlyOriginalPrice), findsNothing);
    expect(find.text(words.premiumStoreUnavailable), findsNothing);
    expect(find.text('Show or hide the official end mark'), findsOneWidget);
    final row = tester
        .widget<Table>(find.byType(Table))
        .children
        .where(
          (row) => row.children.any(
            (cell) =>
                cell is Container &&
                cell.child is Text &&
                (cell.child as Text).data == words.helpCustomAutomationTitle,
          ),
        );
    expect(row, hasLength(1));
  });

  testWidgets(
    'large text keeps the plan differences together and the plan shortcut works',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final semantics = tester.ensureSemantics();
      addTearDown(semantics.dispose);
      final words = await show(tester, _Store(storeAvailable: false));
      expect(find.byType(Table), findsNothing);
      final row = find.bySemanticsLabel(
        '${words.premiumFeatureWatermark}\n${words.premiumComparisonFree} ${words.premiumValueNo}\n${words.premiumComparisonPremium} ${words.premiumValueYes}',
      );
      await tester.ensureVisible(find.text(words.premiumFeatureWatermark));
      await tester.pumpAndSettle();
      expect(row, findsOneWidget);
      final shortcut = find.byKey(const Key('premiumSeePlansButton'));
      await tester.ensureVisible(shortcut);
      await tester.tap(shortcut);
      await tester.pumpAndSettle();
      expect(
        find.text(words.premiumPlanSectionTitle).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unavailable products hide prices and can be queried again', (
    tester,
  ) async {
    final store = _Store(storeAvailable: false);
    final words = await show(tester, store);
    expect(find.text(words.premiumMonthlyPrice), findsNothing);
    expect(find.text(words.premiumYearlyPrice), findsNothing);
    expect(find.text(words.premiumStoreUnavailable), findsOneWidget);
    final retry = find.widgetWithText(TextButton, words.communityRetry);
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    expect(store.retries, 1);
  });
}
