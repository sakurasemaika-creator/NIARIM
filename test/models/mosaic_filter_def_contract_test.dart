import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/filter_def.dart';

void main() {
  test('mosaic filter kind survives FilterDef JSON round trip', () {
    const original = FilterDef(
      id: 'mosaic',
      name: 'Mosaic',
      kind: FilterKind.mosaic,
      strength: 12,
    );

    final restored = FilterDef.fromJson(original.toJson());

    expect(restored.kind, FilterKind.mosaic);
    expect(restored.strength, 12);
  });
}
