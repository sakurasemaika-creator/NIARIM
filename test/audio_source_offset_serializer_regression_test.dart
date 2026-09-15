import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('niapro serializer persists audio sourceStartFrame with legacy fallback', () {
    final source = File('lib/engine/niapro_serializer.dart').readAsStringSync();
    expect(source, contains("'sourceStartFrame': a.sourceStartFrame"));
    expect(
      source,
      contains("sourceStartFrame: m['sourceStartFrame'] as int? ?? 0"),
    );
  });
}
