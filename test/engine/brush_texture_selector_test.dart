import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/brush_texture_selector.dart';
import 'package:niarim/models/brush.dart';

void main() {
  test('sequential selection advances once per stroke and wraps', () {
    final selector = BrushTextureSelector();
    const paths = ['a.png', 'b.png', 'c.png'];

    expect(
      selector.beginStroke(
        brushId: 'brush',
        paths: paths,
        mode: BrushImageSelectionMode.sequential,
      ),
      'a.png',
    );
    expect(selector.activePath, 'a.png');
    expect(selector.activePath, 'a.png');
    selector.endStroke();

    expect(
      selector.beginStroke(
        brushId: 'brush',
        paths: paths,
        mode: BrushImageSelectionMode.sequential,
      ),
      'b.png',
    );
    selector.endStroke();
    expect(
      selector.beginStroke(
        brushId: 'brush',
        paths: paths,
        mode: BrushImageSelectionMode.sequential,
      ),
      'c.png',
    );
    selector.endStroke();
    expect(
      selector.beginStroke(
        brushId: 'brush',
        paths: paths,
        mode: BrushImageSelectionMode.sequential,
      ),
      'a.png',
    );
  });

  test('empty texture list resolves to no active texture', () {
    final selector = BrushTextureSelector();
    expect(
      selector.beginStroke(
        brushId: 'brush',
        paths: const [],
        mode: BrushImageSelectionMode.random,
      ),
      isNull,
    );
    expect(selector.activePath, isNull);
  });

  test('random selection is fixed for the whole stroke', () {
    final selector = BrushTextureSelector(randomSeed: 17);
    const paths = ['a.png', 'b.png', 'c.png', 'd.png'];
    final selected = selector.beginStroke(
      brushId: 'brush',
      paths: paths,
      mode: BrushImageSelectionMode.random,
    );
    expect(selected, isNotNull);
    for (var i = 0; i < 20; i++) {
      expect(selector.activePath, selected);
    }
    selector.endStroke();
    expect(selector.activePath, isNull);
  });

  test('sequential cursors are independent per brush', () {
    final selector = BrushTextureSelector();
    const paths = ['a.png', 'b.png'];
    selector.beginStroke(
      brushId: 'one',
      paths: paths,
      mode: BrushImageSelectionMode.sequential,
    );
    selector.endStroke();
    expect(
      selector.beginStroke(
        brushId: 'two',
        paths: paths,
        mode: BrushImageSelectionMode.sequential,
      ),
      'a.png',
    );
    selector.endStroke();
    expect(
      selector.beginStroke(
        brushId: 'one',
        paths: paths,
        mode: BrushImageSelectionMode.sequential,
      ),
      'b.png',
    );
  });
}
