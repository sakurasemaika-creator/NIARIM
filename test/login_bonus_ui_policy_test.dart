import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/rewards/login_bonus_panel.dart';

void main() {
  test('a login reward requires an eligible unclaimed server offer', () {
    expect(
      canClaimLoginBonus(enabled: true, achieved: true, claimed: false),
      isTrue,
    );
    expect(
      canClaimLoginBonus(enabled: false, achieved: true, claimed: false),
      isFalse,
    );
    expect(
      canClaimLoginBonus(enabled: true, achieved: false, claimed: false),
      isFalse,
    );
    expect(
      canClaimLoginBonus(enabled: true, achieved: true, claimed: true),
      isFalse,
    );
  });
}
