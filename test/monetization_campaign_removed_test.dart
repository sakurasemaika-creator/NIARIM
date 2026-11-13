import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Fresh installation stays Free without campaign entitlement', () async {
    SharedPreferences.setMockInitialValues({});
    final premium = PremiumService();
    addTearDown(premium.dispose);
    await premium.init();
    expect(premium.isPremium, isFalse);
    expect(premium.hasPurchasedPremium, isFalse);
    expect(premium.hasCoinPremium, isFalse);
  });

  test('Local premium preference alone cannot unlock Premium', () async {
    SharedPreferences.setMockInitialValues({'is_premium': true});
    final premium = PremiumService();
    addTearDown(premium.dispose);
    await premium.init();
    expect(premium.isPremium, isFalse);
  });

  test('An unbound, unattributed coin entitlement never grants Premium', () {
    final premium = PremiumService();
    addTearDown(premium.dispose);
    premium.applyServerCoinPremiumExpiry(
      DateTime.now().add(const Duration(days: 1)),
    );
    expect(premium.isPremium, isFalse);
    premium.applyServerCoinPremiumExpiry(null);
    expect(premium.isPremium, isFalse);
  });
}
