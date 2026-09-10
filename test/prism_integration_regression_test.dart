import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:niarim/engine/prism_filter_engine.dart';
import 'package:niarim/models/filter_def.dart';

void main() {
  test('prism defaults match the product specification', () {
    const filter = FilterDef(
      id: 'Filter0022',
      name: 'プリズム',
      kind: FilterKind.prism,
    );
    expect(filter.prismBlurPx, PrismFilterEngine.defaultBlurPx);
    expect(
      filter.prismDirectionDegrees,
      PrismFilterEngine.defaultDirectionDegrees,
    );
  });

  test('serialized prism defaults restore to the product specification', () {
    final filter = FilterDef.fromJson({
      'id': 'Filter0022',
      'name': 'プリズム',
      'kind': FilterKind.prism.name,
    });
    expect(filter.prismBlurPx, PrismFilterEngine.defaultBlurPx);
    expect(
      filter.prismDirectionDegrees,
      PrismFilterEngine.defaultDirectionDegrees,
    );
  });

  test('prism directly repaints the selected source layer', () {
    final source = File(
      'lib/screens/canvas/widgets/filter_panel.dart',
    ).readAsStringSync();
    expect(source, contains('else if (_isPrism(filter))'));
    expect(source, contains('tm.replaceLayerPixels(key, result);'));
    expect(
      source,
      isNot(
        contains("if (_isPrism(filter)) {\n      return _applyGeneratedLayer("),
      ),
    );
  });
}
