import 'package:flutter_test/flutter_test.dart';

/// Builds scheduled widgets, lets real image/file callbacks finish, then paints.
/// Advancing FakeAsync alone cannot complete toImage/toByteData/decode callbacks.
Future<void> pumpRealAsync(WidgetTester tester, Duration duration) async {
  await tester.pump();
  const tick = Duration(milliseconds: 20);
  for (var elapsed = Duration.zero; elapsed < duration; elapsed += tick) {
    await tester.runAsync(() => Future<void>.delayed(tick));
    // Image callbacks can schedule another real operation from a fake-zone
    // continuation. Interleave both clocks, including menu route animations.
    await tester.pump(tick);
  }
}
