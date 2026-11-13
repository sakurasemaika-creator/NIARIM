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

  test('production prism apply selects Linear Dodge, never Addition', () {
    final source = File(
      'lib/screens/canvas/widgets/filter_panel.dart',
    ).readAsStringSync();
    expect(
      source,
      contains('layer.copyWith(blendMode: model.LayerBlendMode.linearDodge)'),
    );
    expect(
      source,
      isNot(
        contains('layer.copyWith(blendMode: model.LayerBlendMode.addition)'),
      ),
      reason: 'Prism Linear Dodge must remain distinct from Addition',
    );
  });

  test('prism directly repaints the selected source layer', () {
    final source = File(
      'lib/screens/canvas/widgets/filter_panel.dart',
    ).readAsStringSync();
    expect(source, contains('else if (_isPrism(filter))'));
    // Through ProjectService so the repaint is one Undo step, the canvas
    // redraws at once, and the source layer switches to Linear Dodge with it.
    expect(source, contains('ps.replaceLayerPixels('));
    expect(
      source,
      contains('layer.copyWith(blendMode: model.LayerBlendMode.linearDodge)'),
    );
    expect(
      source,
      isNot(
        contains("if (_isPrism(filter)) {\n      return _applyGeneratedLayer("),
      ),
    );
  });
}
