import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Turns GIF frames into palette images of at most [maxColours] colours with
/// the octree method of the image package (colours told apart by their top
/// 7 bits per channel; while there are too many, the octree node with the
/// fewest pixels is merged into its parent), but works on the frame's bytes:
/// the colours are counted once per pixel and the octree is built from the
/// distinct colours only, and each pixel then finds its palette entry with
/// one table lookup.
///
/// The image package's own quantizer walks its tree and re-sorts a heap for
/// every pixel (about 75 ms for a 1920×1080 frame) and its colour lookup sends
/// the colours it merged to the wrong palette entry once a frame has more
/// than 256 colours (a gradient sky came out in dark streaks).
///
/// A frame with at most [maxColours] distinct colours keeps them exactly (up
/// to the octree's 7 bits). One instance is reused frame after frame: its
/// lookup table (4 MB) and working buffers live as long as the instance and
/// are not allocated again per frame.
class GifPaletteMapper {
  GifPaletteMapper({this.maxColours = 255});

  final int maxColours;

  /// 7-bit RGB key → 1 + index of the frame's distinct colour, or 0. A frame
  /// with more distinct colours than fit (a photograph) keeps the rest in
  /// [_moreLeaves].
  final Uint16List _slotOfKey = Uint16List(1 << 21);
  final Map<int, int> _moreLeaves = {};
  static const int _slots = 0xFFFF;

  // The frame's distinct colours: key, pixel count, colour sums.
  final _leafKey = _Uint32Buffer();
  final _leafCount = _Uint32Buffer();
  final _leafR = _Uint32Buffer();
  final _leafG = _Uint32Buffer();
  final _leafB = _Uint32Buffer();

  // The octree (node 0 is the root; children 8 per node, -1: none).
  final _children = _Int32Buffer();
  final _parent = _Int32Buffer();
  final _childIndex = _Int32Buffer();
  final _childCount = _Int32Buffer();
  final _depth = _Int32Buffer();
  final _count = _Uint32Buffer();
  final _sumR = _Uint32Buffer();
  final _sumG = _Uint32Buffer();
  final _sumB = _Uint32Buffer();

  /// [frame] as a palette image.
  img.Image paletteFrame(img.Image frame) {
    final (:indices, :rgb, :colours, :width, :height) = paletteIndices(frame);
    final palette = img.PaletteUint8(colours, 3);
    palette.toUint8List().setAll(0, rgb);
    final out = img.Image(
      width: width,
      height: height,
      numChannels: 1,
      palette: palette,
    );
    (out.data! as img.ImageDataUint8).data.setAll(0, indices);
    return out;
  }

  /// [frame] as palette indices (one byte a pixel, row by row) and the
  /// palette ([colours] entries of 3 bytes, red, green, blue): what
  /// [paletteFrame] puts in its palette image.
  ({Uint8List indices, Uint8List rgb, int colours, int width, int height})
  paletteIndices(img.Image frame) {
    var source = frame;
    if (source.hasPalette ||
        source.format != img.Format.uint8 ||
        source.numChannels < 3) {
      source = source.convert(format: img.Format.uint8, numChannels: 3);
    }
    final (:indices, :rgb, :colours) = paletteIndicesOfBytes(
      (source.data! as img.ImageDataUint8).data,
      source.width * source.height,
      source.numChannels,
    );
    return (
      indices: indices,
      rgb: rgb,
      colours: colours,
      width: source.width,
      height: source.height,
    );
  }

  /// [paletteIndices] of [pixelCount] pixels of 8-bit [channels] (3 or 4:
  /// red, green, blue first) in [bytes], row by row.
  ({Uint8List indices, Uint8List rgb, int colours}) paletteIndicesOfBytes(
    Uint8List bytes,
    int pixelCount,
    int channels,
  ) {
    final slotOfKey = _slotOfKey;
    final moreLeaves = _moreLeaves;

    // 1. The distinct 7-bit colours, with their pixel counts and colour sums.
    final leafKey = _leafKey..length = 0;
    final leafCount = _leafCount..length = 0;
    final leafR = _leafR..length = 0;
    final leafG = _leafG..length = 0;
    final leafB = _leafB..length = 0;
    // A run of pixels of the same colour is looked up once and counted at
    // once (the same counts and sums as one pixel at a time).
    for (var p = 0, i = 0; p < pixelCount;) {
      final r = bytes[i];
      final g = bytes[i + 1];
      final b = bytes[i + 2];
      var run = 1;
      p++;
      i += channels;
      while (p < pixelCount &&
          bytes[i] == r &&
          bytes[i + 1] == g &&
          bytes[i + 2] == b) {
        run++;
        p++;
        i += channels;
      }
      final key = ((r >> 1) << 14) | ((g >> 1) << 7) | (b >> 1);
      var leaf = slotOfKey[key] - 1;
      if (leaf < 0 && moreLeaves.isNotEmpty) leaf = moreLeaves[key] ?? -1;
      if (leaf < 0) {
        leaf = leafKey.length;
        if (leaf < _slots) {
          slotOfKey[key] = leaf + 1;
        } else {
          moreLeaves[key] = leaf;
        }
        leafKey.add(key);
        leafCount.add(run);
        leafR.add(r * run);
        leafG.add(g * run);
        leafB.add(b * run);
      } else {
        leafCount.data[leaf] += run;
        leafR.data[leaf] += r * run;
        leafG.data[leaf] += g * run;
        leafB.data[leaf] += b * run;
      }
    }
    final leaves = leafKey.length;

    // 2. The palette entry of each distinct colour.
    final paletteOfLeaf = Uint8List(leaves);
    final palette = <int>[];
    if (leaves <= maxColours) {
      for (var leaf = 0; leaf < leaves; leaf++) {
        paletteOfLeaf[leaf] = leaf;
        palette.add(
          _average(
            leafR.data[leaf],
            leafG.data[leaf],
            leafB.data[leaf],
            leafCount.data[leaf],
          ),
        );
      }
    } else {
      _reduce(leaves, paletteOfLeaf, palette);
    }

    // 3. Each pixel's palette entry, then the table is cleared for the next
    // frame (only the keys this frame used).
    final indices = Uint8List(pixelCount);
    var lastKey = -1;
    var lastIndex = 0;
    for (var p = 0, i = 0; p < pixelCount; p++, i += channels) {
      final key =
          ((bytes[i] >> 1) << 14) |
          ((bytes[i + 1] >> 1) << 7) |
          (bytes[i + 2] >> 1);
      if (key != lastKey) {
        final slot = slotOfKey[key];
        lastIndex = paletteOfLeaf[slot > 0 ? slot - 1 : moreLeaves[key]!];
        lastKey = key;
      }
      indices[p] = lastIndex;
    }
    final keys = leafKey.data;
    for (var leaf = 0; leaf < leaves && leaf < _slots; leaf++) {
      slotOfKey[keys[leaf]] = 0;
    }
    moreLeaves.clear();

    final rgb = Uint8List(palette.length * 3);
    for (var index = 0; index < palette.length; index++) {
      final colour = palette[index];
      rgb[index * 3] = (colour >> 16) & 0xFF;
      rgb[index * 3 + 1] = (colour >> 8) & 0xFF;
      rgb[index * 3 + 2] = colour & 0xFF;
    }
    return (indices: indices, rgb: rgb, colours: palette.length);
  }

  static int _average(int r, int g, int b, int count) =>
      ((r / count).round() << 16) |
      ((g / count).round() << 8) |
      (b / count).round();

  int _addNode(int parent, int childIndex, int depth) {
    final node = _parent.length;
    for (var i = 0; i < 8; i++) {
      _children.add(-1);
    }
    _parent.add(parent);
    _childIndex.add(childIndex);
    _childCount.add(0);
    _depth.add(depth);
    _count.add(0);
    _sumR.add(0);
    _sumG.add(0);
    _sumB.add(0);
    return node;
  }

  /// The octree reduction: builds the tree of the frame's [leaves] distinct
  /// colours, merges the node with the fewest pixels (scaled by depth, leaves
  /// before nodes that still have children) into its parent until at most
  /// [maxColours] nodes hold pixels, and gives each distinct colour the
  /// palette entry of the node it ends up in.
  void _reduce(int leaves, Uint8List paletteOfLeaf, List<int> palette) {
    _children.length = 0;
    _parent.length = 0;
    _childIndex.length = 0;
    _childCount.length = 0;
    _depth.length = 0;
    _count.length = 0;
    _sumR.length = 0;
    _sumG.length = 0;
    _sumB.length = 0;
    _addNode(-1, 0, 0);
    final leafNode = Int32List(leaves);
    for (var leaf = 0; leaf < leaves; leaf++) {
      final key = _leafKey.data[leaf];
      final r7 = key >> 14;
      final g7 = (key >> 7) & 0x7F;
      final b7 = key & 0x7F;
      var node = 0;
      for (var level = 0; level < 7; level++) {
        final shift = 6 - level;
        final i =
            ((g7 >> shift) & 1) * 4 +
            ((r7 >> shift) & 1) * 2 +
            ((b7 >> shift) & 1);
        var child = _children.data[node * 8 + i];
        if (child < 0) {
          child = _addNode(node, i, level + 1);
          _children.data[node * 8 + i] = child;
          _childCount.data[node]++;
        }
        node = child;
      }
      leafNode[leaf] = node;
      _count.data[node] = _leafCount.data[leaf];
      _sumR.data[node] = _leafR.data[leaf];
      _sumG.data[node] = _leafG.data[leaf];
      _sumB.data[node] = _leafB.data[leaf];
    }

    final nodes = _parent.length;
    final children = _children.data;
    final parent = _parent.data;
    final childIndex = _childIndex.data;
    final childCount = _childCount.data;
    final depth = _depth.data;
    final count = _count.data;
    final sumR = _sumR.data;
    final sumG = _sumG.data;
    final sumB = _sumB.data;
    final heapAt = Int32List(nodes)..fillRange(0, nodes, -1);
    final heap = Int32List(nodes);
    var size = 0;
    bool before(int a, int b) {
      if (childCount[a] != childCount[b]) return childCount[a] < childCount[b];
      final ca = count[a] >> depth[a];
      final cb = count[b] >> depth[b];
      if (ca != cb) return ca < cb;
      return a < b;
    }

    void place(int node, int at) {
      heap[at] = node;
      heapAt[node] = at;
    }

    void up(int at) {
      final node = heap[at];
      while (at > 0) {
        final above = (at - 1) >> 1;
        if (!before(node, heap[above])) break;
        place(heap[above], at);
        at = above;
      }
      place(node, at);
    }

    void down(int at) {
      final node = heap[at];
      while (true) {
        var next = at * 2 + 1;
        if (next >= size) break;
        if (next + 1 < size && before(heap[next + 1], heap[next])) next++;
        if (!before(heap[next], node)) break;
        place(heap[next], at);
        at = next;
      }
      place(node, at);
    }

    void push(int node) {
      final at = heapAt[node];
      if (at >= 0) {
        down(at);
        up(heapAt[node]);
        return;
      }
      heap[size] = node;
      size++;
      up(size - 1);
    }

    int pop() {
      final top = heap[0];
      heapAt[top] = -1;
      size--;
      if (size > 0) {
        place(heap[size], 0);
        down(0);
      }
      return top;
    }

    for (var leaf = 0; leaf < leaves; leaf++) {
      push(leafNode[leaf]);
    }
    while (size > maxColours) {
      final node = pop();
      final above = parent[node];
      if (childCount[node] > 0 || above < 0) {
        // Not reached in practice: leaves always come first.
        break;
      }
      count[above] += count[node];
      sumR[above] += sumR[node];
      sumG[above] += sumG[node];
      sumB[above] += sumB[node];
      childCount[above]--;
      children[above * 8 + childIndex[node]] = -1;
      push(above);
    }

    final paletteOfNode = Int32List(nodes)..fillRange(0, nodes, -1);
    for (var at = 0; at < size; at++) {
      final node = heap[at];
      paletteOfNode[node] = palette.length;
      palette.add(_average(sumR[node], sumG[node], sumB[node], count[node]));
    }
    for (var leaf = 0; leaf < leaves; leaf++) {
      final key = _leafKey.data[leaf];
      final r7 = key >> 14;
      final g7 = (key >> 7) & 0x7F;
      final b7 = key & 0x7F;
      var node = 0;
      for (var level = 0; level < 7; level++) {
        final shift = 6 - level;
        final i =
            ((g7 >> shift) & 1) * 4 +
            ((r7 >> shift) & 1) * 2 +
            ((b7 >> shift) & 1);
        final child = children[node * 8 + i];
        if (child < 0) break;
        node = child;
      }
      final entry = paletteOfNode[node];
      paletteOfLeaf[leaf] = entry < 0 ? 0 : entry;
    }
  }
}

/// A growable list of unsigned 32-bit numbers that keeps its storage when
/// emptied.
class _Uint32Buffer {
  Uint32List data = Uint32List(256);
  int length = 0;

  void add(int value) {
    if (length == data.length) {
      data = Uint32List(data.length * 2)..setAll(0, data);
    }
    data[length++] = value;
  }
}

/// A growable list of signed 32-bit numbers that keeps its storage when
/// emptied.
class _Int32Buffer {
  Int32List data = Int32List(256);
  int length = 0;

  void add(int value) {
    if (length == data.length) {
      data = Int32List(data.length * 2)..setAll(0, data);
    }
    data[length++] = value;
  }
}
