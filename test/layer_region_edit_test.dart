import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/layer_compositor.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/engine/timeline_stack.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/layer_crop.dart';
import 'package:niarim/models/layer_keyframe.dart';
import 'package:niarim/models/layer_mask.dart';
import 'package:niarim/models/layer_region_edit.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/models/scene.dart';

const _w = 16;
const _h = 12;

/// Each pixel its own colour, so a moved pixel can be told where it came
/// from.
Uint8List _pattern(int seed) {
  final bytes = Uint8List(_w * _h * 4);
  for (var y = 0; y < _h; y++) {
    for (var x = 0; x < _w; x++) {
      final i = (y * _w + x) * 4;
      bytes[i] = (x * 15 + seed * 37) % 256;
      bytes[i + 1] = (y * 20 + seed * 53) % 256;
      bytes[i + 2] = ((x + y) * 9 + seed * 71) % 256;
      bytes[i + 3] = 255;
    }
  }
  return bytes;
}

List<int> _px(Uint8List rgba, int x, int y) {
  final i = (y * _w + x) * 4;
  return rgba.sublist(i, i + 4);
}

/// [source] with the pixels for which [where] holds made transparent, then
/// each pixel (x, y) for which [from] gives a source pixel set to that
/// pixel of [source].
Uint8List _expected(
  Uint8List source, {
  bool Function(int x, int y)? clear,
  (int, int)? Function(int x, int y)? from,
}) {
  final out = Uint8List.fromList(source);
  for (var y = 0; y < _h; y++) {
    for (var x = 0; x < _w; x++) {
      final i = (y * _w + x) * 4;
      if (clear?.call(x, y) ?? false) out.fillRange(i, i + 4, 0);
    }
  }
  for (var y = 0; y < _h; y++) {
    for (var x = 0; x < _w; x++) {
      final src = from?.call(x, y);
      if (src == null) continue;
      final i = (y * _w + x) * 4;
      final j = (src.$2 * _w + src.$1) * 4;
      out.setRange(i, i + 4, source, j);
    }
  }
  return out;
}

Future<ui.Image> _image(Uint8List rgba) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: _w,
    height: _h,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await descriptor.instantiateCodec();
  final frame = await codec.getNextFrame();
  codec.dispose();
  descriptor.dispose();
  buffer.dispose();
  return frame.image;
}

Future<Uint8List> _rgba(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// x 4–7, y 4–7 (whole pixels, so no edge is half covered).
final _square = RegionSelection.box(
  RegionShape.rectangle,
  const ui.Rect.fromLTRB(4 / _w, 4 / _h, 8 / _w, 8 / _h),
);

bool _inSquare(int x, int y) => x >= 4 && x < 8 && y >= 4 && y < 8;

LayerRegionEdit _edit(
  RegionEditKind kind, {
  RegionSelection? region,
  double dx = 0,
  double dy = 0,
  double scaleX = 1,
  double scaleY = 1,
  double rotation = 0,
  String id = 'e',
}) => LayerRegionEdit(
  id: id,
  kind: kind,
  region: region ?? _square,
  dx: dx,
  dy: dy,
  scaleX: scaleX,
  scaleY: scaleY,
  rotation: rotation,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('saved values', () {
    test('each kind and shape is saved and read back', () {
      final edits = [
        _edit(
          RegionEditKind.move,
          dx: 0.25,
          dy: -0.1,
          scaleX: -1.5,
          scaleY: 0.5,
          rotation: 30,
          id: 'a',
        ),
        _edit(
          RegionEditKind.duplicate,
          region: RegionSelection.box(
            RegionShape.ellipse,
            const ui.Rect.fromLTRB(0.1, 0.2, 0.6, 0.9),
          ),
          dx: 0.1,
          id: 'b',
        ),
        _edit(
          RegionEditKind.erase,
          region: RegionSelection.freehand(const [
            ui.Offset(0.1, 0.1),
            ui.Offset(0.9, 0.2),
            ui.Offset(0.4, 0.8),
          ]),
          id: 'c',
        ),
      ];
      final read = LayerRegionEdit.listFromJson([
        for (final e in edits) e.toJson(),
      ]);
      expect(read, edits);
      expect(read[2].region.bounds, const ui.Rect.fromLTRB(0.1, 0.1, 0.9, 0.8));
    });

    test('a broken edit is left out; the rest are kept, at most '
        '${LayerRegionEdit.maxCount}', () {
      final good = _edit(RegionEditKind.erase, id: 'good').toJson();
      final read = LayerRegionEdit.listFromJson([
        null,
        'x',
        {
          ...good,
          'id': 'outside',
          'region': {..._square.toJson(), 'right': 1.5},
        },
        {...good, 'id': 'no-kind', 'kind': 'melt'},
        {
          ...good,
          'id': 'tiny',
          'region': {..._square.toJson(), 'right': _square.bounds.left},
        },
        {..._edit(RegionEditKind.move, id: 'huge').toJson(), 'scaleX': 1000},
        {
          ..._edit(RegionEditKind.move, id: 'nan').toJson(),
          'rotation': double.nan,
        },
        {
          ...good,
          'id': 'line',
          'region': {
            'shape': 'freehand',
            'points': [0.1, 0.1, 0.5, 0.5],
          },
        },
        good,
        {...good}, // the same id again
      ]);
      expect(read.map((e) => e.id), ['good']);

      final many = LayerRegionEdit.listFromJson([
        for (var i = 0; i < 40; i++)
          _edit(RegionEditKind.erase, id: 'e$i').toJson(),
      ]);
      expect(many, hasLength(LayerRegionEdit.maxCount));
      expect(LayerRegionEdit.listFromJson(null), isEmpty);
      expect(LayerRegionEdit.listFromJson({'a': 1}), isEmpty);
    });

    test('an erase keeps no move, size or turn', () {
      final json = _edit(RegionEditKind.erase, dx: 0.5, rotation: 40).toJson();
      expect(json.containsKey('dx'), isFalse);
      final read = LayerRegionEdit.fromJson({
        ...json,
        'dx': 0.5,
        'rotation': 40,
      })!;
      expect(read.isIdentityTransform, isTrue);
    });

    test('a selection moved by a drag stays inside the picture', () {
      final moved = _square.translated(const ui.Offset(2, -2));
      expect(moved.bounds.right, 1);
      expect(moved.bounds.top, 0);
      expect(moved.bounds.size, _square.bounds.size);
      final free = RegionSelection.freehand(const [
        ui.Offset(0.5, 0.5),
        ui.Offset(0.7, 0.5),
        ui.Offset(0.6, 0.7),
      ]).translated(const ui.Offset(0.5, 0));
      expect(free.bounds.right, closeTo(1, 1e-12));
      expect(free.points.first.dx, closeTo(0.8, 1e-12));
    });
  });

  group('drawing a picture', () {
    final source = _pattern(3);

    Future<Uint8List> apply(List<LayerRegionEdit> edits) async => _rgba(
      await LayerCompositor.applyRegionEdits(await _image(source), edits),
    );

    test('erase makes the part transparent and leaves the rest', () async {
      expect(
        await apply([_edit(RegionEditKind.erase)]),
        _expected(source, clear: _inSquare),
      );
    });

    test('move lifts the part out and puts it where it was moved', () async {
      final out = await apply([
        _edit(RegionEditKind.move, dx: 6 / _w, dy: 2 / _h),
      ]);
      expect(
        out,
        _expected(
          source,
          clear: _inSquare,
          from: (x, y) => _inSquare(x - 6, y - 2) ? (x - 6, y - 2) : null,
        ),
      );
    });

    test(
      'duplicate keeps the part and puts a copy where it was moved',
      () async {
        final out = await apply([
          _edit(RegionEditKind.duplicate, dx: -4 / _w, dy: 3 / _h),
        ]);
        expect(
          out,
          _expected(
            source,
            from: (x, y) => _inSquare(x + 4, y - 3) ? (x + 4, y - 3) : null,
          ),
        );
      },
    );

    test('a copy turned a quarter, flipped and moved', () async {
      // About the square's centre (6, 6): a quarter turn clockwise takes
      // (x, y) to (12 − y, x); then it is moved 5 to the right.
      final turned = await apply([
        _edit(RegionEditKind.duplicate, rotation: 90, dx: 5 / _w),
      ]);
      expect(
        turned,
        _expected(
          source,
          from: (x, y) {
            final ox = y, oy = 12 - (x - 5) - 1;
            return _inSquare(ox, oy) ? (ox, oy) : null;
          },
        ),
      );
      final flipped = await apply([
        _edit(RegionEditKind.move, scaleX: -1, scaleY: -1),
      ]);
      expect(
        flipped,
        _expected(
          source,
          from: (x, y) => _inSquare(x, y) ? (11 - x, 11 - y) : null,
        ),
      );
    });

    test('a part made twice as big covers twice as much', () async {
      final out = await apply([
        _edit(RegionEditKind.move, scaleX: 2, scaleY: 2),
      ]);
      // The square doubles about (6, 6): x 2–9, y 2–9, each source pixel
      // drawn as 2×2.
      expect(_px(out, 2, 2), _px(source, 4, 4));
      expect(_px(out, 9, 9), _px(source, 7, 7));
      expect(_px(out, 1, 1), _px(source, 1, 1));
      expect(_px(out, 10, 5), _px(source, 10, 5));
    });

    test('an ellipse and a freehand outline erase their shape', () async {
      final ellipse = await apply([
        _edit(
          RegionEditKind.erase,
          region: RegionSelection.box(
            RegionShape.ellipse,
            const ui.Rect.fromLTRB(0, 0, 1, 1),
          ),
        ),
      ]);
      expect(_px(ellipse, 8, 6)[3], 0);
      expect(_px(ellipse, 0, 0), _px(source, 0, 0));
      expect(_px(ellipse, 15, 11), _px(source, 15, 11));

      final triangle = await apply([
        _edit(
          RegionEditKind.erase,
          region: RegionSelection.freehand(const [
            ui.Offset(0, 0),
            ui.Offset(1, 0),
            ui.Offset(0, 1),
          ]),
        ),
      ]);
      expect(_px(triangle, 1, 1)[3], 0);
      expect(_px(triangle, 14, 10), _px(source, 14, 10));
    });

    test('edits are drawn in order, each onto the one before', () async {
      final out = await apply([
        _edit(RegionEditKind.move, dx: 6 / _w, id: 'a'),
        // Erases the moved part's left half where it landed.
        _edit(
          RegionEditKind.erase,
          region: RegionSelection.box(
            RegionShape.rectangle,
            const ui.Rect.fromLTRB(10 / _w, 4 / _h, 12 / _w, 8 / _h),
          ),
          id: 'b',
        ),
      ]);
      expect(
        out,
        _expected(
          source,
          clear: (x, y) =>
              _inSquare(x, y) || (x >= 10 && x < 12 && y >= 4 && y < 8),
          from: (x, y) =>
              x >= 12 && x < 14 && y >= 4 && y < 8 ? (x - 6, y) : null,
        ),
      );
    });

    test('a copy over its own part changes nothing', () async {
      expect(await apply([_edit(RegionEditKind.duplicate)]), source);
    });
  });

  group('drawing a material with other layers', () {
    late TileManager edited;
    late TileManager reference;
    final base = _pattern(1);
    final picture = _pattern(5);
    final over = _pattern(9);
    // Moves the square 6 to the right and erases a strip at the top.
    final edits = [
      _edit(RegionEditKind.move, dx: 6 / _w, id: 'move'),
      _edit(
        RegionEditKind.erase,
        region: RegionSelection.box(
          RegionShape.rectangle,
          const ui.Rect.fromLTRB(0, 0, 1, 2 / _h),
        ),
        id: 'erase',
      ),
    ];
    bool cleared(int x, int y) => _inSquare(x, y) || y < 2;
    (int, int)? moved(int x, int y) => _inSquare(x - 6, y) ? (x - 6, y) : null;

    setUp(() {
      edited = TileManager(canvasWidth: _w, canvasHeight: _h);
      reference = TileManager(canvasWidth: _w, canvasHeight: _h);
      for (final tiles in [edited, reference]) {
        tiles.replaceLayerPixels('base', base);
        tiles.replaceLayerPixels('over', over);
      }
      edited.replaceLayerPixels('picture', picture);
      reference.replaceLayerPixels(
        'picture',
        _expected(picture, clear: cleared, from: moved),
      );
    });
    tearDown(() {
      edited.dispose();
      reference.dispose();
    });

    /// The edited layer draws exactly like a layer whose pixels were edited
    /// beforehand, whatever else is drawn with it.
    Future<void> expectLikeEditedPixels(
      List<Layer> layers, {
      LayerKeyframe? Function(Layer layer)? keyframeOf,
      List<LayerMaskGroup> maskGroups = const [],
      ui.Size? rasterSize,
      bool viaSuppliedImage = false,
    }) async {
      Future<Uint8List> run(TileManager tiles, List<Layer> drawn) async =>
          _rgba(
            await LayerCompositor.composite(
              tiles,
              drawn,
              (l) => l.id,
              _w,
              _h,
              keyframeOf: keyframeOf,
              maskGroups: maskGroups,
              rasterSize: rasterSize,
              pixelsOf: viaSuppliedImage
                  ? (layer, size) async => layer.id == 'picture'
                        ? LayerPixelsImage(
                            await tiles.compositeLayerToImage(
                              'picture',
                              rasterSize: size,
                            ),
                          )
                        : const LayerPixelsFromTiles()
                  : null,
            ),
          );
      final expected = await run(reference, [
        for (final l in layers)
          l.id == 'picture' ? l.copyWith(regionEdits: const []) : l,
      ]);
      final actual = await run(edited, layers);
      expect(actual, expected);
      // The edits show in this drawing (the material is not hidden behind
      // another layer), so the comparison means something.
      final unedited = await run(edited, [
        for (final l in layers)
          l.id == 'picture' ? l.copyWith(regionEdits: const []) : l,
      ]);
      expect(unedited, isNot(expected));
    }

    Layer pictureLayer({
      LayerBlendMode blend = LayerBlendMode.normal,
      bool hasClipping = false,
      LayerMask? mask,
      LayerType type = LayerType.timelineImage,
    }) => Layer(
      id: 'picture',
      name: 'picture',
      type: type,
      blendMode: blend,
      hasClipping: hasClipping,
      mask: mask,
      regionEdits: edits,
    );
    const baseLayer = Layer(id: 'base', name: 'base', type: LayerType.normal);

    test('on its own, over other layers and with a CPU blend mode', () async {
      await expectLikeEditedPixels([pictureLayer()]);
      // The first layer is the front one.
      await expectLikeEditedPixels([pictureLayer(), baseLayer]);
      for (final blend in [LayerBlendMode.multiply, LayerBlendMode.subtract]) {
        await expectLikeEditedPixels([pictureLayer(blend: blend), baseLayer]);
      }
    });

    test('clipped, as the layer clipped to, and with a mask', () async {
      await expectLikeEditedPixels([
        pictureLayer(hasClipping: true),
        baseLayer,
      ]);
      await expectLikeEditedPixels([
        const Layer(
          id: 'over',
          name: 'over',
          type: LayerType.normal,
          hasClipping: true,
        ),
        pictureLayer(),
      ]);
      await expectLikeEditedPixels([
        pictureLayer(
          mask: const LayerMask(centerX: 40, centerY: 50, width: 80),
        ),
        baseLayer,
      ]);
    });

    test('before the material\'s own move, scale and turn', () async {
      await expectLikeEditedPixels(
        [pictureLayer(), baseLayer],
        keyframeOf: (l) => l.id == 'picture'
            ? const LayerKeyframe(frameIndex: 0, x: 3, y: -2, scale: 1.5)
            : null,
      );
    });

    test(
      'at the preview\'s smaller raster and on a supplied video frame',
      () async {
        await expectLikeEditedPixels([
          pictureLayer(),
          baseLayer,
        ], rasterSize: const ui.Size(8, 6));
        await expectLikeEditedPixels([
          pictureLayer(type: LayerType.timelineVideo),
          baseLayer,
        ], viaSuppliedImage: true);
      },
    );

    test('after the crop: a part moved out of the crop still shows', () async {
      // The crop keeps x 0–7; the square moves to x 10–13.
      const crop = LayerCrop(left: 0, top: 0, right: 0.5, bottom: 1);
      final layer = Layer(
        id: 'picture',
        name: 'picture',
        type: LayerType.timelineImage,
        crop: crop,
        regionEdits: [edits.first],
      );
      final out = await _rgba(
        await LayerCompositor.composite(edited, [layer], (l) => l.id, _w, _h),
      );
      expect(_px(out, 11, 5), _px(picture, 5, 5));
      expect(_px(out, 9, 9)[3], 0); // cropped away
      expect(_px(out, 5, 5)[3], 0); // lifted out
      expect(_px(out, 2, 9), _px(picture, 2, 9));
    });
  });

  test('the edits are saved with the project', () async {
    final dir = await Directory.systemTemp.createTemp('niarim-region-save-');
    addTearDown(() => dir.delete(recursive: true));
    final now = DateTime.utc(2026);
    final path = '${dir.path}/p.niapro';
    final edits = [
      _edit(RegionEditKind.move, dx: 0.2, rotation: 15, id: 'a'),
      _edit(
        RegionEditKind.erase,
        region: RegionSelection.freehand(const [
          ui.Offset(0.1, 0.1),
          ui.Offset(0.5, 0.1),
          ui.Offset(0.3, 0.6),
        ]),
        id: 'b',
      ),
    ];
    await NiaproSerializer.saveToPath(
      filePath: path,
      project: Project(
        id: 'p',
        name: 'p',
        fps: 10,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        createdAt: now,
        updatedAt: now,
        totalWorkSeconds: 0,
      ),
      scenes: [
        Scene(
          id: 'S',
          index: 0,
          frames: [
            Frame(
              index: 0,
              layers: [
                Layer(
                  id: 'm',
                  name: 'm',
                  type: LayerType.timelineImage,
                  regionEdits: edits,
                ),
                const Layer(id: 'n', name: 'n', type: LayerType.timelineVideo),
              ],
            ),
          ],
        ),
      ],
      tileManager: TileManager(canvasWidth: 8, canvasHeight: 8),
    );
    final layers = {
      for (final l in (await NiaproSerializer.load(
        path,
      )).scenes.single.frames.single.layers)
        l.id: l,
    };
    expect(layers['m']!.regionEdits, edits);
    expect(layers['n']!.regionEdits, isEmpty);
  });
}
