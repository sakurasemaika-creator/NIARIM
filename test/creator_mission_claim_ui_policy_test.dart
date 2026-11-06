import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/rewards/creator_missions_screen.dart';

void main() {
  test('claim button requires achieved, ready, unclaimed and approved', () {
    expect(
      missionClaimActionAllowed(
        eligible: true,
        ready: true,
        claimed: false,
        enabled: true,
      ),
      isTrue,
    );
    expect(
      missionClaimActionAllowed(
        eligible: false,
        ready: true,
        claimed: false,
        enabled: true,
      ),
      isFalse,
    );
    expect(
      missionClaimActionAllowed(
        eligible: true,
        ready: false,
        claimed: false,
        enabled: true,
      ),
      isFalse,
    );
    expect(
      missionClaimActionAllowed(
        eligible: true,
        ready: true,
        claimed: true,
        enabled: true,
      ),
      isFalse,
    );
    expect(
      missionClaimActionAllowed(
        eligible: true,
        ready: true,
        claimed: false,
        enabled: false,
      ),
      isFalse,
    );
  });
}
