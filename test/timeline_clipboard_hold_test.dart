import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/services/project_service.dart';

/// What the timeline's clipboard keeps of a cut clip, which is no longer in
/// the scene: its material stays in use and its pixels stay as they were.
void main() {
  test('a material held by the clipboard stays in use until let go', () {
    final ps = ProjectService();
    expect(ps.isMaterialUsed('p', 'm'), isFalse);
    ps.holdClipboardMaterials('p', ['m']);
    expect(ps.isMaterialUsed('p', 'm'), isTrue);
    // Only in its own project.
    expect(ps.isMaterialUsed('q', 'm'), isFalse);
    ps.holdClipboardMaterials('p', const []);
    expect(ps.isMaterialUsed('p', 'm'), isFalse);
  });

  test('shared layer tiles stay as they were when the layer is drawn on or '
      'removed, and can be put under another layer', () {
    final tiles = TileManager(canvasWidth: 256, canvasHeight: 256);
    tiles.getOrCreateTile('a', 0, 0)[0] = 10;
    final kept = tiles.shareLayerTiles('a')!;
    expect(kept['0,0']![0], 10);

    // Drawing on the layer after it was kept does not reach the copy.
    tiles.getOrCreateTile('a', 0, 0)[0] = 99;
    expect(tiles.getTile('a', 0, 0)![0], 99);
    expect(kept['0,0']![0], 10);

    // Nor does removing it.
    tiles.removeLayer('a');
    expect(kept['0,0']![0], 10);

    tiles.putLayerTiles('b', kept);
    expect(tiles.getTile('b', 0, 0)![0], 10);
    // Drawing on the new layer leaves the kept tiles as they were, so they
    // can be pasted again.
    tiles.getOrCreateTile('b', 0, 0)[0] = 50;
    expect(kept['0,0']![0], 10);
    expect(tiles.shareLayerTiles('missing'), isNull);
    expect(Uint8List.fromList(kept['0,0']!).length, 256 * 256 * 4);
  });
}
