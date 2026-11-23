import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  bool _busy = false;
  @override
  bool get purchasePending => _busy;
  void beginCheckout() {
    _busy = true;
    notifyListeners();
  }

  int retries = 0;

  @override
  Future<void> refreshStoreProducts() async => retries++;
}

class _UnavailableCheckout extends _Store {
  _UnavailableCheckout()
    : super(
        storeAvailable: true,
        products: [
          ProductDetails(
            id: PremiumService.monthlyProductId,
            title: 'Monthly',
            description: '',
            price: '€4',
            rawPrice: 4,
            currencyCode: 'EUR',
          ),
        ],
      );

  @override
  String? purchaseError;

  @override
  Future<bool> buy(String productId) async {
    purchaseError = PremiumService.checkoutStartFailed;
    notifyListeners();
    return false;
  }

  @override
  Future<void> restorePurchases() => Future.error(StateError('Store offline'));
}

void main() {
  Future<AppLocalizations> show(WidgetTester tester, _Store store) async {
    SharedPreferences.setMockInitialValues({});
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

    final store = _Store(
      storeAvailable: true,
      products: [
        product(PremiumService.monthlyProductId, '4,49 €', 4.49),
        product(PremiumService.yearlyProductId, '45,99 €', 45.99),
      ],
    );
    final words = await show(tester, store);
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

    store.beginCheckout();
    await tester.pump();
    final status = find.text(words.premiumCheckoutPending);
    await tester.ensureVisible(status);
    await tester.pump();
    expect(status, findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.ancestor(
        of: status,
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.liveRegion == true,
        ),
      ),
      findsOneWidget,
    );
    for (final price in ['4,49 €', '45,99 €']) {
      final card = find.ancestor(
        of: find.text(price),
        matching: find.byType(InkWell),
      );
      expect(tester.widget<InkWell>(card).onTap, isNull);
      final endInset =
          tester.getRect(card).right - tester.getRect(find.text(price)).right;
      expect(endInset, closeTo(16, 1));
    }
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, words.premiumRestorePurchases),
          )
          .onPressed,
      isNull,
    );
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
      final words = await show(tester, _Store(storeAvailable: false));
      final semantics = tester.ensureSemantics();
      try {
        expect(find.byType(Table), findsNothing);
        final row = find.bySemanticsLabel(
          '${words.premiumFeatureWatermark}\n${words.premiumComparisonFree} ${words.premiumValueNo}\n${words.premiumComparisonPremium} ${words.premiumValueYes}',
        );
        await tester.ensureVisible(find.text(words.premiumFeatureWatermark));
        await tester.pumpAndSettle();
        expect(row, findsOneWidget);
      } finally {
        semantics.dispose();
      }
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

  testWidgets(
    'shows the localized retry guidance when checkout or restore fails',
    (tester) async {
      final words = await show(tester, _UnavailableCheckout());
      final restore = find.widgetWithText(
        TextButton,
        words.premiumRestorePurchases,
      );
      await tester.ensureVisible(restore);
      await tester.tap(restore);
      await tester.pumpAndSettle();
      expect(find.text(words.premiumRestoreFailed), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      final monthly = find.text('€4');
      await tester.ensureVisible(monthly);
      await tester.tap(monthly);
      await tester.pumpAndSettle();
      // A purchase asks for agreement to the Terms and the Privacy Policy
      // first; agreeing continues to the checkout.
      await tester.tap(find.byKey(const Key('legalConsentAgree')));
      await tester.pumpAndSettle();
      expect(find.text(words.premiumCheckoutStartFailed), findsWidgets);
      expect(find.text(PremiumService.checkoutStartFailed), findsNothing);
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
