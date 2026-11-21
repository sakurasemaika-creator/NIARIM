import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/filter_def.dart';

void main() {
  test('mosaic filter kind survives JSON round-trip', () {
    const filter = FilterDef(
      id: 'mosaic-contract',
      name: 'モザイク',
      kind: FilterKind.mosaic,
      strength: 8,
    );

    final restored = FilterDef.fromJson(filter.toJson());

    expect(restored.kind, FilterKind.mosaic);
    expect(restored.strength, 8);
  });
}
