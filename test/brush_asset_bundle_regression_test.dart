import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled hair brush assets are loadable from the Flutter asset bundle', () async {
    for (var i = 1; i <= 5; i++) {
      final name = 'assets/brushes/bangs_${i.toString().padLeft(2, '0')}.png';
      final data = await rootBundle.load(name);
      expect(
        data.lengthInBytes,
        greaterThan(0),
        reason: '$name must stay registered in pubspec.yaml and packaged',
      );
    }
  });
}
