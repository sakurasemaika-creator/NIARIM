import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/services/premium_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'legacy local premium setting and manual setter cannot bypass verification',
    () async {
      SharedPreferences.setMockInitialValues({'is_premium': true});
      final premium = PremiumService();
      await premium.init();
      expect(premium.hasPurchasedPremium, isFalse);
      expect(premium.verifiedExpiryDate, isNull);
      await premium.setPremium(
        true,
        purchaseDate: DateTime.now(),
        productId: PremiumService.monthlyProductId,
      );
      expect(premium.hasPurchasedPremium, isFalse);
      premium.dispose();
    },
  );

  test('only a matching, time-limited Google Play response is trusted', () {
    final now = DateTime(2027, 2, 1);
    final ms = now.millisecondsSinceEpoch;
    final active = <String, dynamic>{
      'verified': true,
      'productId': PremiumService.monthlyProductId,
      'expiresAtEpochMs': ms + const Duration(days: 28).inMilliseconds,
      'verifiedUntilEpochMs': ms + const Duration(minutes: 15).inMilliseconds,
    };
    bool accepted(Map<String, dynamic> response) =>
        PremiumService.isValidPlayVerification(
          response,
          PremiumService.monthlyProductId,
          now,
        );
    expect(accepted(active), isTrue);
    expect(accepted({...active, 'verified': false}), isFalse);
    expect(
      accepted({...active, 'productId': PremiumService.yearlyProductId}),
      isFalse,
    );
    expect(accepted({...active, 'verifiedUntilEpochMs': ms - 1}), isFalse);
    expect(accepted({...active, 'expiresAtEpochMs': ms - 1}), isFalse);
    expect(
      accepted({
        ...active,
        'verifiedUntilEpochMs': ms + const Duration(minutes: 30).inMilliseconds,
      }),
      isFalse,
    );
  });
}
