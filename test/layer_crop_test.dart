import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/crop_frame.dart';
import 'package:niarim/engine/layer_compositor.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/engine/timeline_stack.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/layer_crop.dart';
import 'package:niarim/models/layer_keyframe.dart';
import 'package:niarim/models/layer_mask.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/models/scene.dart';
import 'package:niarim/screens/timeline/widgets/material_gizmo.dart';

const _w = 16;
const _h = 12;

/// Keeps x 4–11 and y 3–8 (whole pixels, so no edge is half covered).
const _crop = LayerCrop(left: 0.25, top: 0.25, right: 0.75, bottom: 0.75);

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

/// [pixels] with everything outside [_crop] transparent: what a crop must
/// look like.
Uint8List _cutOutside(Uint8List pixels) {
  final out = Uint8List.fromList(pixels);
  for (var y = 0; y < _h; y++) {
    for (var x = 0; x < _w; x++) {
      if (x >= 4 && x < 12 && y >= 3 && y < 9) continue;
      out.fillRange((y * _w + x) * 4, (y * _w + x) * 4 + 4, 0);
    }
  }
  return out;
}

Future<Uint8List> _rgba(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('crop values', () {
    test('saves the four edges; a missing, whole or broken crop reads as '
        'none', () {
      expect(LayerCrop.fromJson(_crop.toJson()), _crop);
      expect(LayerCrop.fromJson(null), isNull);
      expect(LayerCrop.fromJson(LayerCrop.full.toJson()), isNull);
      for (final broken in [
        {'left': 0.6, 'right': 0.4},
        {'top': -0.1},
        {'bottom': 1.5},
        {'left': double.nan},
        {'left': 0.5, 'right': 0.5},
      ]) {
        expect(LayerCrop.fromJson(broken), isNull, reason: '$broken');
      }
    });

    test('a picture is fitted, centred, into the layer', () {
      expect(
        fittedContentRect(const ui.Size(100, 100), 160, 90),
        const ui.Rect.fromLTWH(35, 0, 90, 90),
      );
      expect(
        fittedContentRect(const ui.Size(1920, 1080), 160, 90),
        const ui.Rect.fromLTWH(0, 0, 160, 90),
      );
      expect(
        fittedContentRect(ui.Size.zero, 160, 90),
        const ui.Rect.fromLTWH(0, 0, 160, 90),
      );
    });

    test('the panel\'s percentages are of the material\'s drawn part', () {
      // A square picture in a 160 × 90 layer: x 35–125.
      const frame = ui.Rect.fromLTWH(35, 0, 90, 90);
      final crop = cropFromCuts(
        (left: 10, top: 20, right: 30, bottom: 0),
        frame,
        160,
        90,
      )!;
      expect(crop.left * 160, closeTo(44, 1e-9));
      expect(crop.right * 160, closeTo(98, 1e-9));
      expect(crop.top * 90, closeTo(18, 1e-9));
      expect(crop.bottom, 1);
      final cuts = cropCutsIn(crop, frame, 160, 90);
      expect(cuts.left, closeTo(10, 1e-9));
      expect(cuts.right, closeTo(30, 1e-9));
      expect(cuts.top, closeTo(20, 1e-9));
      expect(cuts.bottom, closeTo(0, 1e-9));
      // Nothing cut is no crop; opposite cuts keep at least 1%.
      expect(
        cropFromCuts((left: 0, top: 0, right: 0, bottom: 0), frame, 160, 90),
        isNull,
      );
      final most = cropFromCuts(
        (left: 80, top: 0, right: 80, bottom: 0),
        frame,
        160,
        90,
      )!;
      expect((most.right - most.left) * 160, closeTo(0.9, 1e-9));
    });

    test('preview handles move their edges and stay inside the picture', () {
      const frame = ui.Rect.fromLTWH(10, 0, 100, 50);
      const start = ui.Rect.fromLTRB(20, 10, 90, 40);
      const topLeft = (left: true, top: true, right: false, bottom: false);
      const right = (left: false, top: false, right: true, bottom: false);
      expect(
        MaterialCropGizmo.dragged(
          start,
          topLeft,
          const ui.Offset(5, -4),
          frame,
        ),
        const ui.Rect.fromLTRB(25, 6, 90, 40),
      );
      expect(
        MaterialCropGizmo.dragged(start, right, const ui.Offset(99, 0), frame),
        const ui.Rect.fromLTRB(20, 10, 110, 40),
      );
      // An edge cannot pass the opposite one.
      expect(
        MaterialCropGizmo.dragged(
          start,
          right,
          const ui.Offset(-500, 0),
          frame,
        ).width,
        1,
      );
      expect(MaterialCropGizmo.cropOf(frame, frame, 120, 50), isNull);
      expect(
        MaterialCropGizmo.cropOf(start, frame, 120, 50),
        LayerCrop(left: 20 / 120, top: 0.2, right: 0.75, bottom: 0.8),
      );
      expect(MaterialCropGizmo.keptRect(null, frame, 120, 50), frame);
    });
  });

  group('drawing', () {
    late TileManager cropped;
    late TileManager reference;
    final base = _pattern(1);
    final picture = _pattern(5);
    final over = _pattern(9);

    setUp(() {
      cropped = TileManager(canvasWidth: _w, canvasHeight: _h);
      reference = TileManager(canvasWidth: _w, canvasHeight: _h);
      for (final tiles in [cropped, reference]) {
        tiles.replaceLayerPixels('base', base);
        tiles.replaceLayerPixels('over', over);
      }
      cropped.replaceLayerPixels('picture', picture);
      reference.replaceLayerPixels('picture', _cutOutside(picture));
    });
    tearDown(() {
      cropped.dispose();
      reference.dispose();
    });

    /// The cropped layer draws exactly like a layer whose pixels were cut
    /// outside the crop beforehand, whatever else is drawn with it.
    Future<void> expectLikeCutPixels(
      List<Layer> layers, {
      LayerKeyframe? Function(Layer layer)? keyframeOf,
      LayerKeyframe? Function(Layer layer)? groupKeyframeOf,
      List<LayerMaskGroup> maskGroups = const [],
      ui.Size? rasterSize,
      bool viaSuppliedImage = false,
      Set<int> partialRows = const {},
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
              groupKeyframeOf: groupKeyframeOf,
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
        for (final l in layers) l.id == 'picture' ? l.copyWith(crop: null) : l,
      ]);
      final actual = await run(cropped, layers);
      if (partialRows.isEmpty) {
        expect(actual, expected);
      } else {
        // Every row the crop's edge does not cross matches exactly.
        final rowBytes = (rasterSize?.width.toInt() ?? _w) * 4;
        expect(actual.length, expected.length);
        for (var row = 0; row * rowBytes < actual.length; row++) {
          if (partialRows.contains(row)) continue;
          final from = row * rowBytes;
          expect(
            actual.sublist(from, from + rowBytes),
            expected.sublist(from, from + rowBytes),
            reason: 'row $row',
          );
        }
      }
      // The crop shows in this drawing (the material is not hidden behind
      // another layer), so the comparison means something.
      final uncut = await run(cropped, [
        for (final l in layers) l.id == 'picture' ? l.copyWith(crop: null) : l,
      ]);
      expect(uncut, isNot(expected));
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
      crop: _crop,
    );
    const baseLayer = Layer(id: 'base', name: 'base', type: LayerType.normal);

    test('on its own and over other layers', () async {
      await expectLikeCutPixels([pictureLayer()]);
      // The first layer is the front one.
      await expectLikeCutPixels([pictureLayer(), baseLayer]);
    });

    test('with a blend mode the GPU has and one drawn on the CPU', () async {
      for (final blend in [LayerBlendMode.multiply, LayerBlendMode.subtract]) {
        await expectLikeCutPixels([pictureLayer(blend: blend), baseLayer]);
      }
    });

    test(
      'clipped to a layer, and as the layer another is clipped to',
      () async {
        await expectLikeCutPixels([pictureLayer(hasClipping: true), baseLayer]);
        await expectLikeCutPixels([
          const Layer(
            id: 'over',
            name: 'over',
            type: LayerType.normal,
            hasClipping: true,
          ),
          pictureLayer(),
        ]);
      },
    );

    test(
      'with a mask: the crop and the mask both cut, in either order',
      () async {
        await expectLikeCutPixels([
          pictureLayer(
            mask: const LayerMask(centerX: 40, centerY: 50, width: 50),
          ),
          baseLayer,
        ]);
      },
    );

    test(
      'before the material\'s move, scale and turn, and its group\'s',
      () async {
        LayerKeyframe? moved(Layer layer) => layer.id == 'picture'
            ? const LayerKeyframe(frameIndex: 0, x: 3, y: -2, scale: 1.5)
            : null;
        await expectLikeCutPixels([
          pictureLayer(),
          baseLayer,
        ], keyframeOf: moved);
        await expectLikeCutPixels(
          [pictureLayer(), baseLayer],
          groupKeyframeOf: (l) => l.id == 'picture'
              ? const LayerKeyframe(frameIndex: 0, rotation: 30)
              : null,
        );
      },
    );

    test(
      'at a smaller raster (the preview) and on a supplied video frame',
      () async {
        // At half size the crop's top and bottom (rows 3 and 9) fall half
        // way through preview rows 1 and 4: cutting the smaller picture
        // and shrinking the cut picture mix those rows' colours in a
        // different order, so only the other rows are compared exactly.
        await expectLikeCutPixels(
          [pictureLayer(), baseLayer],
          rasterSize: const ui.Size(8, 6),
          partialRows: const {1, 4},
        );
        await expectLikeCutPixels([
          pictureLayer(type: LayerType.timelineVideo),
          baseLayer,
        ], viaSuppliedImage: true);
      },
    );
  });

  test('the crop is saved with the project', () async {
    final dir = await Directory.systemTemp.createTemp('niarim-crop-save-');
    addTearDown(() => dir.delete(recursive: true));
    final now = DateTime.utc(2026);
    final path = '${dir.path}/p.niapro';
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
      scenes: const [
        Scene(
          id: 'S',
          index: 0,
          frames: [
            Frame(
              index: 0,
              layers: [
                Layer(
                  id: 'a',
                  name: 'a',
                  type: LayerType.timelineImage,
                  crop: _crop,
                ),
                Layer(id: 'b', name: 'b', type: LayerType.timelineVideo),
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
    expect(layers['a']!.crop, _crop);
    expect(layers['b']!.crop, isNull);
  });
}
