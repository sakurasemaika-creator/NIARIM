import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/premium_service.dart';

class _Account extends Fake implements GoogleSignInAccount {
  @override
  String get id => 'checkout-test';
}

class _Auth extends GoogleAuthService {
  @override
  final GoogleSignInAccount account = _Account();
}

class _Store extends Fake implements InAppPurchase {
  final updates = StreamController<List<PurchaseDetails>>.broadcast(sync: true);
  final launched = <String>[];
  Future<bool> Function() open = () async => true;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => updates.stream;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async =>
      ProductDetailsResponse(
        productDetails: [
          for (final id in ids)
            ProductDetails(
              id: id,
              title: id,
              description: '',
              price: '€4',
              rawPrice: 4,
              currencyCode: 'EUR',
            ),
        ],
        notFoundIDs: [],
      );

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) {
    launched.add(purchaseParam.productDetails.id);
    return open();
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const monthly = PremiumService.monthlyProductId;
  const yearly = PremiumService.yearlyProductId;
  late _Store store;
  late PremiumService service;
  late _Auth auth;

  setUp(() async {
    store = _Store();
    auth = _Auth();
    service = PremiumService(store)..bindGoogleAuth(auth);
    await service.refreshStoreProducts();
  });
  tearDown(() async {
    service.dispose();
    auth.dispose();
    await store.updates.close();
  });

  test(
    'only one plan launches while verification or checkout is in progress',
    () async {
      final ready = Completer<bool>();
      service.bindPlayVerifier(
        (_, _) async => {},
        canPurchase: () => ready.future,
      );
      final first = service.buy(monthly);
      expect(service.purchasePending, isTrue);
      expect(await service.buy(yearly), isFalse);
      expect(store.launched, isEmpty);
      ready.complete(true);
      expect(await first, isTrue);
      expect(await service.buy(yearly), isFalse);
      expect(store.launched, [monthly]);
      expect(service.isPremium, isFalse);
      void cancel(String productId) {
        store.updates.add([
          PurchaseDetails(
            productID: productId,
            verificationData: PurchaseVerificationData(
              localVerificationData: '',
              serverVerificationData: '',
              source: 'test',
            ),
            transactionDate: null,
            status: PurchaseStatus.canceled,
          ),
        ]);
      }

      cancel(yearly);
      expect(service.purchasePending, isTrue);
      cancel(monthly);
      expect(service.purchasePending, isFalse);
      expect(await service.buy(yearly), isTrue);
    },
  );

  for (final throwsError in [false, true]) {
    test(
      'a failed store launch releases the selection (exception: $throwsError)',
      () async {
        service.bindPlayVerifier(
          (_, _) async => {},
          canPurchase: () async => true,
        );
        store.open = () async {
          if (throwsError) throw PlatformException(code: 'store-unavailable');
          return false;
        };
        expect(await service.buy(yearly), isFalse);
        expect(service.purchasePending, isFalse);
        expect(service.purchaseError, PremiumService.checkoutStartFailed);
        expect(service.isPremium, isFalse);
        store.open = () async => true;
        expect(await service.buy(monthly), isTrue);
        expect(service.purchaseError, isNull);
        expect(store.launched, [yearly, monthly]);
      },
    );
  }

  test(
    'a failed backend check releases the selection before opening Play',
    () async {
      service.bindPlayVerifier(
        (_, _) async => {},
        canPurchase: () => throw StateError('offline'),
      );
      expect(await service.buy(monthly), isFalse);
      expect(service.purchaseError, contains('サーバー'));
      expect(service.purchasePending, isFalse);
      expect(store.launched, isEmpty);
    },
  );
}
