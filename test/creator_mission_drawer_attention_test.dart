import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/home/widgets/home_drawer.dart';

void main() {
  test('menu marker requires a positive, server-owned mission achievement', () {
    expect(
      missionDrawerNeedsAttention({
        'hasAchievedUnclaimed': true,
        'provisional': true,
      }),
      isTrue,
    );
    expect(
      missionDrawerNeedsAttention({'hasAchievedUnclaimed': false}),
      isFalse,
    );
    expect(missionDrawerNeedsAttention({'claimed': false}), isFalse);
    expect(missionDrawerNeedsAttention(null), isFalse);
  });
}
