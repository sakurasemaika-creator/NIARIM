import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/layer_compositor.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/engine/timeline_stack.dart';
import 'package:niarim/engine/timeline_video_layer_pixels.dart';
import 'package:niarim/engine/video_frame_decoder.dart';
import 'package:niarim/engine/video_frame_provider.dart';
import 'package:niarim/engine/video_frame_timeline.dart';
import 'package:niarim/engine/video_material_snapshot.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/layer_keyframe.dart';
import 'package:niarim/models/layer_mask.dart';
import 'package:niarim/models/material_asset.dart';

const _w = 16;
const _h = 12;

/// Premultiplied RGBA with a colour gradient and a transparent band, so
/// blend modes, clipping and masks all see varied pixels.
Uint8List _pattern({required int seed, bool transparentBand = false}) {
  final bytes = Uint8List(_w * _h * 4);
  for (var y = 0; y < _h; y++) {
    for (var x = 0; x < _w; x++) {
      final i = (y * _w + x) * 4;
      final alpha = transparentBand && x < 3 ? 0 : 255;
      bytes[i] = (x * 15 + seed * 37) % 256 * alpha ~/ 255;
      bytes[i + 1] = (y * 20 + seed * 53) % 256 * alpha ~/ 255;
      bytes[i + 2] = ((x + y) * 9 + seed * 71) % 256 * alpha ~/ 255;
      bytes[i + 3] = alpha;
    }
  }
  return bytes;
}

final _placeholder = Uint8List.fromList(
  List.generate(_w * _h * 4, (i) => i % 4 == 3 ? 255 : 128),
);
final _frame = _pattern(seed: 3, transparentBand: true);
final _base = _pattern(seed: 1);
final _over = _pattern(seed: 7);

Layer _video({
  LayerBlendMode blend = LayerBlendMode.normal,
  int opacity = 100,
  bool hasClipping = false,
  String? folder,
  LayerMask? mask,
}) => Layer(
  id: 'video',
  name: 'video',
  type: LayerType.timelineVideo,
  blendMode: blend,
  opacity: opacity,
  hasClipping: hasClipping,
  parentFolderId: folder,
  mask: mask,
);

Layer _normal(String id, {bool hasClipping = false, String? folder}) => Layer(
  id: id,
  name: id,
  type: LayerType.normal,
  hasClipping: hasClipping,
  parentFolderId: folder,
);

Future<Uint8List> _rgba(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Tiles that hold the real frame in the video layer (the reference) and
  /// tiles that hold a placeholder there (what the project stores).
  late TileManager reference;
  late TileManager stored;
  final supplied = <ui.Image>[];

  setUp(() {
    reference = TileManager(canvasWidth: _w, canvasHeight: _h);
    stored = TileManager(canvasWidth: _w, canvasHeight: _h);
    for (final tiles in [reference, stored]) {
      tiles.replaceLayerPixels('base', _base);
      tiles.replaceLayerPixels('over', _over);
    }
    reference.replaceLayerPixels('video', _frame);
    stored.replaceLayerPixels('video', _placeholder);
    supplied.clear();
  });
  tearDown(() {
    reference.dispose();
    stored.dispose();
  });

  /// Supplies the reference frame for the video layer only.
  Future<LayerPixels> supplyFrame(Layer layer, ui.Size? rasterSize) async {
    if (layer.type != LayerType.timelineVideo) {
      return const LayerPixelsFromTiles();
    }
    final image = await reference.compositeLayerToImage(
      'video',
      rasterSize: rasterSize,
    );
    supplied.add(image);
    return LayerPixelsImage(image);
  }

  Future<void> expectSameAsStoredFrame(
    List<Layer> layers, {
    LayerKeyframe? Function(Layer layer)? keyframeOf,
    LayerKeyframe? Function(Layer layer)? groupKeyframeOf,
    List<LayerMaskGroup> maskGroups = const [],
    int? paperColor,
    ui.Size? rasterSize,
  }) async {
    Future<Uint8List> run(
      TileManager tiles,
      LayerPixelSource? pixelsOf,
    ) async => _rgba(
      await LayerCompositor.composite(
        tiles,
        layers,
        (l) => l.id,
        _w,
        _h,
        keyframeOf: keyframeOf,
        groupKeyframeOf: groupKeyframeOf,
        maskGroups: maskGroups,
        paperColor: paperColor,
        rasterSize: rasterSize,
        pixelsOf: pixelsOf,
      ),
    );
    final expected = await run(reference, null);
    final actual = await run(stored, supplyFrame);
    expect(actual, expected);
    final placeholderShown = await run(stored, null);
    expect(
      placeholderShown,
      isNot(expected),
      reason: 'the case must depend on the video layer pixels',
    );
  }

  group('a supplied frame composites exactly like stored pixels', () {
    test('normal layer over another layer', () async {
      await expectSameAsStoredFrame([_video(), _normal('base')]);
    });

    test('layer and folder opacity', () async {
      const folder = Layer(
        id: 'folder',
        name: 'folder',
        type: LayerType.folder,
        opacity: 50,
      );
      await expectSameAsStoredFrame([
        folder,
        _video(opacity: 40, folder: 'folder'),
        _normal('base'),
      ]);
    });

    for (final mode in [
      LayerBlendMode.multiply,
      LayerBlendMode.screen,
      LayerBlendMode.overlay,
      LayerBlendMode.subtract,
      LayerBlendMode.linearDodge,
      LayerBlendMode.hardMix,
      LayerBlendMode.divide,
    ]) {
      test(
        'blend mode ${mode.name} '
        '(${LayerCompositor.requiresCpuBlend(mode) ? 'CPU' : 'GPU'})',
        () async {
          await expectSameAsStoredFrame([
            _video(blend: mode, opacity: 80),
            _normal('base'),
          ], paperColor: 0xFFFFFFFF);
        },
      );
    }

    test('the video as a clipping source', () async {
      await expectSameAsStoredFrame([
        _normal('over', hasClipping: true),
        _video(),
        _normal('base'),
      ]);
    });

    test('the video clipped to the layer below', () async {
      await expectSameAsStoredFrame([
        _video(hasClipping: true, opacity: 70),
        _normal('base'),
      ]);
    });

    test('a CPU blend mode on a video clipped to the layer below', () async {
      await expectSameAsStoredFrame([
        _video(hasClipping: true, blend: LayerBlendMode.subtract),
        _normal('base'),
      ]);
    });

    test('a layer mask on the video', () async {
      await expectSameAsStoredFrame([
        _video(
          mask: const LayerMask(
            shape: LayerMaskShape.ellipse,
            width: 70,
            height: 50,
            rotation: 20,
          ),
        ),
        _normal('base'),
      ]);
    });

    test('a frame mask over a run of layers', () async {
      await expectSameAsStoredFrame(
        [_video(), _normal('over'), _normal('base')],
        maskGroups: [
          LayerMaskGroup(
            layerIds: const {'over', 'video'},
            mask: const LayerMask(centerX: 40, width: 50, height: 80),
          ),
        ],
      );
    });

    test('layer and group keyframe transforms', () async {
      await expectSameAsStoredFrame(
        [_video(), _normal('base')],
        keyframeOf: (l) => l.id == 'video'
            ? const LayerKeyframe(frameIndex: 0, x: 3, y: -2, scale: 0.8)
            : null,
        groupKeyframeOf: (l) => l.id == 'video'
            ? const LayerKeyframe(frameIndex: 0, rotation: 15)
            : null,
      );
    });

    test('a composite at a smaller raster size', () async {
      await expectSameAsStoredFrame([
        _video(opacity: 90),
        _normal('base'),
      ], rasterSize: const ui.Size(8, 6));
    });

    test('the compositor disposes every supplied image', () async {
      await expectSameAsStoredFrame([
        _normal('over', hasClipping: true),
        _video(blend: LayerBlendMode.subtract),
        _normal('base'),
      ]);
      expect(supplied, isNotEmpty);
      expect(supplied.every((image) => image.debugDisposed), isTrue);
    });
  });

  group('a layer with nothing to draw', () {
    Future<Uint8List> composite(
      TileManager tiles,
      List<Layer> layers, {
      LayerPixelSource? pixelsOf,
    }) async => _rgba(
      await LayerCompositor.composite(
        tiles,
        layers,
        (l) => l.id,
        _w,
        _h,
        pixelsOf: pixelsOf,
      ),
    );

    Future<LayerPixels> nothingForVideo(Layer layer, ui.Size? _) async =>
        layer.type == LayerType.timelineVideo
        ? const LayerPixelsEmpty()
        : const LayerPixelsFromTiles();

    test('draws nothing instead of its stored placeholder', () async {
      final empty = TileManager(canvasWidth: _w, canvasHeight: _h)
        ..replaceLayerPixels('base', _base);
      addTearDown(empty.dispose);
      final layers = [_video(), _normal('base')];
      expect(
        await composite(stored, layers, pixelsOf: nothingForVideo),
        await composite(empty, [_normal('base')]),
      );
    });

    test('hides the layers clipped to it', () async {
      final empty = TileManager(canvasWidth: _w, canvasHeight: _h)
        ..replaceLayerPixels('base', _base);
      addTearDown(empty.dispose);
      expect(
        await composite(stored, [
          _normal('over', hasClipping: true),
          _video(),
          _normal('base'),
        ], pixelsOf: nothingForVideo),
        await composite(empty, [_normal('base')]),
      );
    });
  });

  group('TimelineVideoLayerPixels', () {
    late _SolidDecoder decoder;
    late VideoFrameProvider frames;
    final problems = <VideoLayerProblem>[];

    setUp(() {
      decoder = _SolidDecoder();
      frames = VideoFrameProvider(
        snapshot: VideoMaterialSnapshot.fromAssets(
          [
            for (final id in ['M1', 'gone'])
              MaterialAsset(
                id: id,
                originalFileName: '$id.mp4',
                type: MaterialType.video,
                sizeBytes: 1,
                addedAt: DateTime(2026),
              ),
          ],
          {'M1': '/m/1.mp4', 'gone': null},
        ),
        decoder: decoder,
      );
      problems.clear();
    });
    tearDown(() => frames.dispose());

    TimelineVideoLayerPixels pixels() => TimelineVideoLayerPixels(
      frames: frames,
      framesPerSecond: 10,
      canvasWidth: _w,
      canvasHeight: _h,
      onProblem: problems.add,
    );

    Layer clip({String? materialId = 'M1'}) => Layer(
      id: 'clip',
      name: 'clip',
      type: LayerType.timelineVideo,
      materialId: materialId,
      rangeMode: LayerRangeMode.frameRange,
      // Timeline frames 4–9, playing the source from frame 2.
      rangeStart: 5,
      rangeEnd: 10,
      sourceTrimStart: 2,
      sourceTrimEnd: 7,
    );

    test('supplies the source frame for the timeline frame', () async {
      final source = pixels();
      for (final (frameIndex, sourceFrame) in [(4, 2), (6, 4), (9, 7)]) {
        final result = await source.pixelsOf(clip(), frameIndex, null);
        final image = (result as LayerPixelsImage).image;
        expect((image.width, image.height), (_w, _h));
        expect((await _rgba(image))[0], sourceFrame);
      }
      expect(problems, isEmpty);
    });

    test('supplies raster-size frames for a smaller composite', () async {
      final result = await pixels().pixelsOf(clip(), 4, const ui.Size(8, 6));
      final image = (result as LayerPixelsImage).image;
      expect((image.width, image.height), (8, 6));
      image.dispose();
    });

    test('leaves other layers to their stored pixels', () async {
      expect(
        await pixels().pixelsOf(_normal('base'), 4, null),
        isA<LayerPixelsFromTiles>(),
      );
      expect(decoder.decodes, isEmpty);
    });

    test('draws nothing outside the clip', () async {
      expect(
        await pixels().pixelsOf(clip(), 10, null),
        isA<LayerPixelsEmpty>(),
      );
      expect(decoder.decodes, isEmpty);
      expect(problems, isEmpty);
    });

    test('reports a missing material and draws nothing', () async {
      expect(
        await pixels().pixelsOf(clip(materialId: 'gone'), 4, null),
        isA<LayerPixelsEmpty>(),
      );
      expect(
        await pixels().pixelsOf(clip(materialId: null), 4, null),
        isA<LayerPixelsEmpty>(),
      );
      expect(problems.map((p) => p.reason), [
        VideoFrameUnavailableReason.missingFile,
        VideoFrameUnavailableReason.unknownMaterial,
      ]);
    });

    test('does not report a cancelled request as a problem', () async {
      final source = TimelineVideoLayerPixels(
        frames: frames,
        framesPerSecond: 10,
        canvasWidth: _w,
        canvasHeight: _h,
        isCancelled: () => true,
        onProblem: problems.add,
      );
      expect(await source.pixelsOf(clip(), 4, null), isA<LayerPixelsEmpty>());
      expect(problems, isEmpty);
    });

    test('feeds the compositor through atFrame', () async {
      final tiles = TileManager(canvasWidth: _w, canvasHeight: _h)
        ..replaceLayerPixels(
          'clip',
          Uint8List(_w * _h * 4)..fillRange(0, _w * _h * 4, 200),
        );
      addTearDown(tiles.dispose);
      final rgba = await _rgba(
        await LayerCompositor.composite(
          tiles,
          [clip()],
          (l) => l.id,
          _w,
          _h,
          pixelsOf: pixels().atFrame(5),
        ),
      );
      expect(rgba.sublist(0, 4), [3, 7, 9, 255]);
    });
  });
}

/// Solid frames whose red channel is the frame index.
class _SolidDecoder implements VideoFrameDecoder {
  final decodes = <int>[];

  @override
  Future<VideoFrameTimeline> probe(String path) async =>
      VideoFrameTimeline.fromPresentationMicros([
        for (var i = 0; i < 30; i++) i * 100000,
      ]);

  @override
  Future<DecodedVideoFrame> decode({
    required String path,
    required VideoFrameTimeline timeline,
    required int frameIndex,
    required int width,
    required int height,
  }) async {
    decodes.add(frameIndex);
    final rgba = Uint8List(width * height * 4);
    for (var i = 0; i < rgba.length; i += 4) {
      rgba
        ..[i] = frameIndex
        ..[i + 1] = 7
        ..[i + 2] = 9
        ..[i + 3] = 255;
    }
    return DecodedVideoFrame(
      rgba: rgba,
      width: width,
      height: height,
      frameIndex: frameIndex,
    );
  }
}
