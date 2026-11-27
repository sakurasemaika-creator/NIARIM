import 'dart:typed_data';

/// Runs a two-pass thinning (Zhang–Suen, Guo–Hall...) on [image], in
/// place: each pass removes, all at once, the pixels inside the border
/// that [removable] picks from the picture as it stood when the pass began
/// (pass 0, then pass 1), and the thinning stops after a round of both
/// passes that removes nothing, or after [maxRounds] rounds.
///
/// [removable] must decide from the 3×3 pixels around a pixel only. A pass
/// then looks again only at the pixels next to one removed since it last
/// looked at them (and, the first time, at every pixel): around the others
/// nothing has changed, so they would decide as they did. The thinning
/// removes the same pixels, pass by pass, as looking at every pixel every
/// time, but a thick shape is peeled a ring at a time instead of all of it
/// being looked at again for each ring.
void thinTwoPass(
  Uint8List image,
  int width,
  int height, {
  int? maxRounds,
  required bool Function(int pixel, int pass) removable,
}) {
  if (width < 3 || height < 3) return;
  // Which passes each pixel is waiting for (bit 0: pass 0, bit 1: pass 1).
  final queued = Uint8List(width * height);
  var waiting = [_Pixels(), _Pixels()];
  for (var y = 1; y < height - 1; y++) {
    for (var x = 1; x < width - 1; x++) {
      final p = y * width + x;
      if (image[p] == 0) continue;
      waiting[0].add(p);
      waiting[1].add(p);
      queued[p] = 3;
    }
  }
  var spare = _Pixels();
  final remove = _Pixels();
  for (var round = 0; maxRounds == null || round < maxRounds; round++) {
    var changed = false;
    for (var pass = 0; pass < 2; pass++) {
      final bit = 1 << pass;
      final looking = waiting[pass];
      waiting[pass] = spare;
      remove.length = 0;
      final pixels = looking.data;
      for (var k = 0; k < looking.length; k++) {
        final p = pixels[k];
        queued[p] &= ~bit;
        if (image[p] == 0) continue;
        if (removable(p, pass)) remove.add(p);
      }
      looking.length = 0;
      spare = looking;
      if (remove.length == 0) continue;
      changed = true;
      final removed = remove.data;
      for (var k = 0; k < remove.length; k++) {
        image[removed[k]] = 0;
      }
      // Both passes look again around what was removed.
      for (var k = 0; k < remove.length; k++) {
        final p = removed[k];
        final x = p % width;
        final y = p ~/ width;
        for (var dy = -1; dy <= 1; dy++) {
          final ny = y + dy;
          if (ny < 1 || ny > height - 2) continue;
          for (var dx = -1; dx <= 1; dx++) {
            final nx = x + dx;
            if (nx < 1 || nx > width - 2) continue;
            final q = ny * width + nx;
            if (image[q] == 0) continue;
            final was = queued[q];
            if (was == 3) continue;
            if (was & 1 == 0) waiting[0].add(q);
            if (was & 2 == 0) waiting[1].add(q);
            queued[q] = 3;
          }
        }
      }
    }
    if (!changed) break;
  }
}

/// A growable list of pixel indices that keeps its storage when emptied.
class _Pixels {
  Int32List data = Int32List(1024);
  int length = 0;

  void add(int value) {
    if (length == data.length) {
      data = Int32List(data.length * 2)..setAll(0, data);
    }
    data[length++] = value;
  }
}
