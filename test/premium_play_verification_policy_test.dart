import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/premium_service.dart';

void main() {
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
          response, PremiumService.monthlyProductId, now,
        );
    expect(accepted(active), isTrue);
    expect(accepted({...active, 'verified': false}), isFalse);
    expect(accepted({...active, 'productId': PremiumService.yearlyProductId}), isFalse);
    expect(accepted({...active, 'verifiedUntilEpochMs': ms - 1}), isFalse);
    expect(accepted({...active, 'expiresAtEpochMs': ms - 1}), isFalse);
    expect(accepted({...active, 'verifiedUntilEpochMs':
        ms + const Duration(minutes: 30).inMilliseconds}), isFalse);
  });
}
