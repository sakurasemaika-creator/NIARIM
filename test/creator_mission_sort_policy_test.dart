import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/rewards/creator_missions_screen.dart';

void main() {
  test('unclaimed achievements always rise above incomplete templates', () {
    expect(
      missionSortPriority({
        'eligible': true,
        'claimed': false,
        'readyForClaim': true,
      }),
      0,
    );
    expect(
      missionSortPriority({
        'eligible': true,
        'claimed': false,
        'readyForClaim': false,
      }),
      1,
    );
    expect(missionSortPriority({'eligible': true, 'claimed': true}), 2);
    expect(missionSortPriority({'eligible': false, 'claimed': false}), 3);
    expect(
      missionSortPriority({
        '_genericTemplate': true,
        'eligible': false,
        'claimed': false,
      }),
      4,
    );
  });
  test('never enables a button on uncertain progress or a draft payout', () {
    expect(
      missionClaimActionAllowed(
        eligible: true,
        ready: true,
        claimed: false,
        enabled: true,
      ),
      true,
    );
    expect(
      missionClaimActionAllowed(
        eligible: false,
        ready: true,
        claimed: false,
        enabled: true,
      ),
      false,
    );
    expect(
      missionClaimActionAllowed(
        eligible: true,
        ready: true,
        claimed: false,
        enabled: false,
      ),
      false,
    );
  });
}
