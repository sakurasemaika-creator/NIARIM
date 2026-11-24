import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/engine/layer_range_resolver.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/engine/timeline_frame_renderer.dart';
import 'package:niarim/engine/timeline_stack.dart';
import 'package:niarim/engine/timeline_video_layer_pixels.dart';
import 'package:niarim/engine/video_frame_decoder.dart';
import 'package:niarim/engine/video_frame_provider.dart';
import 'package:niarim/engine/video_frame_timeline.dart';
import 'package:niarim/engine/video_material_snapshot.dart';
import 'package:niarim/models/camera_keyframe.dart';
import 'package:niarim/models/effect_filter_instance.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/layer_crop.dart';
import 'package:niarim/models/layer_region_edit.dart';
import 'package:niarim/models/material_asset.dart';
import 'package:niarim/models/scene.dart';
import 'package:niarim/services/export_storage.dart';

const _w = 24;
const _h = 16;
const _fps = 10;
const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');

/// Video frames whose red channel is 10 × the source frame index.
class _NumberedDecoder implements VideoFrameDecoder {
  _NumberedDecoder({this.onDecode});

  final void Function(int frameIndex)? onDecode;
  final decodes = <int>[];

  @override
  Future<VideoFrameTimeline> probe(String path) async =>
      VideoFrameTimeline.fromPresentationMicros([
        for (var i = 0; i < 24; i++) i * 100000,
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
    onDecode?.call(frameIndex);
    final rgba = Uint8List(width * height * 4);
    for (var i = 0; i < rgba.length; i += 4) {
      rgba
        ..[i] = frameIndex * 10
        ..[i + 1] = 60
        ..[i + 2] = 140
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

// Timeline frames 2–9 play the source from frame 5 (trim 5–12).
const _video = Layer(
  id: 'video',
  name: 'video',
  type: LayerType.timelineVideo,
  materialId: 'M1',
  rangeMode: LayerRangeMode.frameRange,
  rangeStart: 3,
  rangeEnd: 10,
  sourceTrimStart: 5,
  sourceTrimEnd: 12,
  opacity: 90,
);
const _ink = Layer(id: 'ink', name: 'ink', type: LayerType.normal);

/// A part of the video moved, a part copied turned, and a part erased.
final _regionEdits = [
  LayerRegionEdit(
    id: 'move',
    kind: RegionEditKind.move,
    region: RegionSelection.box(
      RegionShape.rectangle,
      const ui.Rect.fromLTRB(0.1, 0.1, 0.4, 0.5),
    ),
    dx: 0.3,
    dy: 0.2,
    scaleX: 1.5,
  ),
  LayerRegionEdit(
    id: 'copy',
    kind: RegionEditKind.duplicate,
    region: RegionSelection.box(
      RegionShape.ellipse,
      const ui.Rect.fromLTRB(0.5, 0.2, 0.9, 0.6),
    ),
    dx: -0.3,
    rotation: 30,
  ),
  LayerRegionEdit(
    id: 'erase',
    kind: RegionEditKind.erase,
    region: RegionSelection.freehand(const [
      ui.Offset(0.6, 0.6),
      ui.Offset(0.95, 0.7),
      ui.Offset(0.7, 0.95),
    ]),
  ),
];

Scene _scene({
  List<EffectFilterInstance> effects = const [],
  LayerCrop? crop,
  List<LayerRegionEdit> regionEdits = const [],
}) => Scene(
  id: 'S1',
  index: 0,
  frames: [
    for (var i = 0; i < 12; i++)
      Frame(
        index: i,
        layers: i == 0
            ? [_ink, _video.copyWith(crop: crop, regionEdits: regionEdits)]
            : const [_ink],
      ),
  ],
  cameraKeyframes: const [
    CameraKeyframe(frameIndex: 0),
    CameraKeyframe(frameIndex: 11, x: 3, zoom: 1.2, rotation: 8),
  ],
  effectFilters: effects,
);

VideoMaterialSnapshot _materials({String? path = '/m/clip.mp4'}) =>
    VideoMaterialSnapshot.fromAssets(
      [
        MaterialAsset(
          id: 'M1',
          originalFileName: 'clip.mp4',
          type: MaterialType.video,
          sizeBytes: 1,
          addedAt: DateTime(2026),
        ),
      ],
      {'M1': path},
    );

TileManager _tiles(Scene scene) {
  final tiles = TileManager(canvasWidth: _w, canvasHeight: _h);
  // The project stores a grey placeholder in the video layer.
  tiles.replaceLayerPixels(
    frameLayerKey(scene.id, 0, _video.id),
    Uint8List.fromList(
      List.generate(_w * _h * 4, (i) => i % 4 == 3 ? 255 : 128),
    ),
  );
  // Ink in the left third of every frame.
  for (final frame in scene.frames) {
    final ink = Uint8List(_w * _h * 4);
    for (var y = 0; y < _h; y++) {
      for (var x = 0; x < _w ~/ 3; x++) {
        final i = (y * _w + x) * 4;
        ink
          ..[i] = 20
          ..[i + 1] = 20
          ..[i + 2] = 20
          ..[i + 3] = 255;
      }
    }
    tiles.replaceLayerPixels(
      frameLayerKey(scene.id, frame.index, _ink.id),
      ink,
    );
  }
  return tiles;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory root;
  late Directory documents;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('niarim-video-export-');
    documents = Directory('${root.path}/documents')..createSync();
    ExportStorage.invalidate();
    messenger.setMockMethodCallHandler(_pathChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return documents.path;
      }
      return root.path;
    });
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(_pathChannel, null);
    ExportStorage.invalidate();
    if (await root.exists()) await root.delete(recursive: true);
  });

  List<String> leftoverVideoFolders() => [
    for (final entity in root.listSync())
      if (entity.path.contains('export_video_frames')) entity.path,
  ];

  Future<Uint8List> previewRgba(
    Scene scene,
    TileManager tiles,
    int frameIndex,
    TimelineVideoLayerPixels video,
  ) async {
    // What _TimelinePreview builds for the frame (ProjectService
    // .stackedLayersOf = stackFrameLayers over the resolved layers).
    final homes = buildLayerHomeIndex([scene]);
    final stacked = stackFrameLayers(
      scene,
      frameIndex,
      resolveFrameLayers(
        [scene],
        homes,
        scene.id,
        frameIndex,
        scene.frames[frameIndex].layers,
      ),
    );
    final image = await TimelineFrameRenderer().renderImage(
      TimelineFrameRequest(
        tileManager: tiles,
        layers: stacked.layers,
        keyOf: (l) => resolveTileKey(homes, scene.id, frameIndex, l.id),
        frameIndex: frameIndex,
        drawingWidth: tiles.canvasWidth,
        drawingHeight: tiles.canvasHeight,
        outputWidth: _w - 4,
        outputHeight: _h - 2,
        backgroundColor: 0xFFFFFFFF,
        maskGroups: stacked.maskGroups,
        groups: scene.groups,
        cameraKeyframes: scene.cameraKeyframes,
        effectFilters: scene.effectFilters,
        pixelsOf: video.atFrame(frameIndex),
      ),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  Future<Uint8List> exportRgba(
    Scene scene,
    TileManager tiles,
    int frameIndex,
    TimelineVideoLayerPixels video,
  ) {
    final homes = buildLayerHomeIndex([scene]);
    return ExportEngine().renderFrame(
      layers: resolveFrameLayers(
        [scene],
        homes,
        scene.id,
        frameIndex,
        scene.frames[frameIndex].layers,
      ),
      tileManager: tiles,
      sceneId: scene.id,
      scene: scene,
      frameIndex: frameIndex,
      drawingWidth: _w,
      drawingHeight: _h,
      width: _w - 4,
      height: _h - 2,
      backgroundColor: 0xFFFFFFFF,
      cameraKeyframes: scene.cameraKeyframes,
      effectFilters: scene.effectFilters,
      layerHomes: homes,
      groups: scene.groups,
      videoPixels: video,
    );
  }

  TimelineVideoLayerPixels pixelsWith(VideoFrameProvider frames) =>
      TimelineVideoLayerPixels(
        frames: frames,
        framesPerSecond: _fps.toDouble(),
        canvasWidth: _w,
        canvasHeight: _h,
      );

  group('preview and export draw the same frame', () {
    for (final (label, effects, crop, regions) in [
      (
        'without effects',
        const <EffectFilterInstance>[],
        null,
        const <LayerRegionEdit>[],
      ),
      (
        'with an effect filter',
        const [
          EffectFilterInstance(
            id: 'sepia',
            type: EffectFilterType.sepia,
            startFrame: 0,
            endFrame: 11,
          ),
        ],
        null,
        const <LayerRegionEdit>[],
      ),
      (
        'with the video cropped',
        const <EffectFilterInstance>[],
        const LayerCrop(left: 0.25, top: 0.25, right: 0.75, bottom: 0.75),
        const <LayerRegionEdit>[],
      ),
      (
        'with parts of the video moved, copied and erased',
        const <EffectFilterInstance>[],
        const LayerCrop(left: 0.05, top: 0, right: 1, bottom: 1),
        _regionEdits,
      ),
    ]) {
      test('every timeline frame, $label', () async {
        final scene = _scene(
          effects: effects,
          crop: crop,
          regionEdits: regions,
        );
        final tiles = _tiles(scene);
        addTearDown(tiles.dispose);
        // Separate providers, as the preview and an export job have.
        final previewFrames = VideoFrameProvider(
          snapshot: _materials(),
          decoder: _NumberedDecoder(),
        );
        final exportFrames = VideoFrameProvider(
          snapshot: _materials(),
          decoder: _NumberedDecoder(),
          cacheBudgetBytes: _w * _h * 4 * 3,
        );
        addTearDown(previewFrames.dispose);
        addTearDown(exportFrames.dispose);
        for (var frame = 0; frame < scene.frames.length; frame++) {
          expect(
            await previewRgba(scene, tiles, frame, pixelsWith(previewFrames)),
            await exportRgba(scene, tiles, frame, pixelsWith(exportFrames)),
            reason: 'timeline frame $frame',
          );
        }
      });
    }

    test('the crop cuts the decoded frame, in the preview and the '
        'export alike', () async {
      final plain = _scene();
      final cropped = _scene(
        crop: const LayerCrop(left: 0.5, top: 0, right: 1, bottom: 1),
      );
      final tiles = _tiles(plain);
      addTearDown(tiles.dispose);
      final frames = VideoFrameProvider(
        snapshot: _materials(),
        decoder: _NumberedDecoder(),
      );
      addTearDown(frames.dispose);
      // Frame 4 shows the video.
      final whole = await exportRgba(plain, tiles, 4, pixelsWith(frames));
      final cut = await exportRgba(cropped, tiles, 4, pixelsWith(frames));
      expect(cut, isNot(whole));
      expect(await previewRgba(cropped, tiles, 4, pixelsWith(frames)), cut);
    });

    test('the parts selected are changed on the decoded frame, in the '
        'preview and the export alike', () async {
      final plain = _scene();
      final edited = _scene(regionEdits: _regionEdits);
      final tiles = _tiles(plain);
      addTearDown(tiles.dispose);
      final frames = VideoFrameProvider(
        snapshot: _materials(),
        decoder: _NumberedDecoder(),
      );
      addTearDown(frames.dispose);
      // Frames 4 and 7 show different video frames, each edited alike.
      for (final frame in [4, 7]) {
        final whole = await exportRgba(plain, tiles, frame, pixelsWith(frames));
        final changed = await exportRgba(
          edited,
          tiles,
          frame,
          pixelsWith(frames),
        );
        expect(changed, isNot(whole), reason: 'frame $frame');
        expect(
          await previewRgba(edited, tiles, frame, pixelsWith(frames)),
          changed,
          reason: 'frame $frame',
        );
      }
    });

    test(
      'the video frame follows the trim and replaces the placeholder',
      () async {
        final scene = _scene();
        final tiles = _tiles(scene);
        addTearDown(tiles.dispose);
        final decoder = _NumberedDecoder();
        final frames = VideoFrameProvider(
          snapshot: _materials(),
          decoder: decoder,
        );
        addTearDown(frames.dispose);
        for (var frame = 0; frame < 12; frame++) {
          await exportRgba(scene, tiles, frame, pixelsWith(frames));
        }
        // Frames 2–9 show source frames 5–12, decoded once each.
        expect(decoder.decodes, [for (var i = 5; i <= 12; i++) i]);
      },
    );
  });

  group('export jobs', () {
    Future<img.Image> exportStill(
      ExportEngine engine,
      int frameIndex, {
      VideoMaterialSnapshot? materials,
    }) async {
      final scene = _scene();
      final tiles = _tiles(scene);
      addTearDown(tiles.dispose);
      final path = await engine.exportFrameImage(
        scenes: [scene],
        tileManager: tiles,
        sceneId: scene.id,
        frameIndex: frameIndex,
        drawingWidth: _w,
        drawingHeight: _h,
        width: _w,
        height: _h,
        backgroundColor: 0xFFFFFFFF,
        asJpeg: false,
        sourceFps: _fps,
        videoMaterials: materials ?? _materials(),
      );
      return img.decodePng(await File(path).readAsBytes())!;
    }

    test('a still export shows the decoded frame and cleans up', () async {
      final engine = ExportEngine(videoDecoderFor: (_) => _NumberedDecoder());
      final png = await exportStill(engine, 4);
      final pixel = png.getPixel(_w - 2, _h ~/ 2);
      // Source frame 7 (red 70) at 90% over white paper.
      expect(pixel.r, closeTo(70 * 0.9 + 255 * 0.1, 1));
      expect(pixel.g, closeTo(60 * 0.9 + 255 * 0.1, 1));
      expect(engine.videoLeftOut, 0);
      expect(leftoverVideoFolders(), isEmpty);
    });

    test('a missing material draws nothing and is counted', () async {
      final engine = ExportEngine(videoDecoderFor: (_) => _NumberedDecoder());
      final png = await exportStill(
        engine,
        4,
        materials: _materials(path: null),
      );
      final pixel = png.getPixel(_w - 2, _h ~/ 2);
      // White paper, not the grey placeholder.
      expect([pixel.r, pixel.g, pixel.b], [255, 255, 255]);
      expect(engine.videoLeftOut, 1);
      expect(leftoverVideoFolders(), isEmpty);
    });

    test('without a snapshot the export keeps the stored pixels', () async {
      var made = 0;
      final engine = ExportEngine(
        videoDecoderFor: (_) {
          made++;
          return _NumberedDecoder();
        },
      );
      final scene = _scene();
      final tiles = _tiles(scene);
      addTearDown(tiles.dispose);
      await engine.exportFrameImage(
        scenes: [scene],
        tileManager: tiles,
        sceneId: scene.id,
        frameIndex: 4,
        drawingWidth: _w,
        drawingHeight: _h,
        width: _w,
        height: _h,
        backgroundColor: 0xFFFFFFFF,
        asJpeg: false,
      );
      expect(made, 0);
    });

    test('a GIF export decodes each source frame once, in order', () async {
      final decoder = _NumberedDecoder();
      final engine = ExportEngine(videoDecoderFor: (_) => decoder);
      final scene = _scene();
      final tiles = _tiles(scene);
      addTearDown(tiles.dispose);
      await engine.exportGif(
        scenes: [scene],
        tileManager: tiles,
        fps: _fps,
        drawingWidth: _w,
        drawingHeight: _h,
        width: _w,
        height: _h,
        backgroundColor: 0xFFFFFFFF,
        videoMaterials: _materials(),
      );
      expect(decoder.decodes, [for (var i = 5; i <= 12; i++) i]);
      expect(engine.videoLeftOut, 0);
      expect(leftoverVideoFolders(), isEmpty);
    });

    test('cancelling stops decoding and releases the job', () async {
      final token = ExportCancelToken();
      late _NumberedDecoder decoder;
      decoder = _NumberedDecoder(
        onDecode: (_) {
          if (decoder.decodes.length == 2) token.cancel();
        },
      );
      final engine = ExportEngine(videoDecoderFor: (_) => decoder);
      final scene = _scene();
      final tiles = _tiles(scene);
      addTearDown(tiles.dispose);
      await expectLater(
        engine.exportGif(
          scenes: [scene],
          tileManager: tiles,
          fps: _fps,
          drawingWidth: _w,
          drawingHeight: _h,
          width: _w,
          height: _h,
          backgroundColor: 0xFFFFFFFF,
          videoMaterials: _materials(),
          cancelToken: token,
        ),
        throwsA(isA<ExportCancelledException>()),
      );
      expect(decoder.decodes, hasLength(2));
      expect(leftoverVideoFolders(), isEmpty);
    });
  });

  group(
    'real FFmpeg decoding through preview and export',
    () {
      late Directory videos;
      late String numbered;

      Future<bool> run(String tool, List<String> arguments) async =>
          (await Process.run(tool, arguments)).exitCode == 0;

      VideoFrameDecoder systemDecoder(Directory workDirectory) =>
          FfmpegVideoFrameDecoder(
            workDirectory: workDirectory,
            runFfmpeg: (arguments) => run('ffmpeg', arguments),
            runFfprobe: (arguments) => run('ffprobe', arguments),
          );

      setUpAll(() async {
        if (!_ffmpegTests) return;
        videos = await Directory.systemTemp.createTemp('niarim-video-src-');
        numbered = '${videos.path}/numbered.mp4';
        final made = await Process.run('ffmpeg', [
          '-hide_banner', '-loglevel', 'error', '-y', //
          '-f', 'lavfi',
          '-i',
          'nullsrc=s=48x32:r=10:d=2,format=yuv444p,'
              "geq=lum='16+N*10':cb=128:cr=128",
          '-c:v', 'libx264', '-qp', '0', '-bf', '2', '-pix_fmt', 'yuv444p',
          numbered,
        ]);
        if (made.exitCode != 0) fail('ffmpeg failed: ${made.stderr}');
      });
      tearDownAll(() async {
        if (_ffmpegTests) await videos.delete(recursive: true);
      });

      test(
        'preview and export RGBA match and show the trimmed frame',
        () async {
          final scene = _scene();
          final tiles = _tiles(scene);
          addTearDown(tiles.dispose);
          final materials = _materials(path: numbered);
          final previewFrames = VideoFrameProvider(
            snapshot: materials,
            decoder: systemDecoder(Directory('${root.path}/preview')),
          );
          final exportFrames = VideoFrameProvider(
            snapshot: materials,
            decoder: systemDecoder(Directory('${root.path}/export')),
          );
          addTearDown(previewFrames.dispose);
          addTearDown(exportFrames.dispose);
          for (var frame = 0; frame < 12; frame++) {
            final preview = await previewRgba(
              scene,
              tiles,
              frame,
              pixelsWith(previewFrames),
            );
            final export = await exportRgba(
              scene,
              tiles,
              frame,
              pixelsWith(exportFrames),
            );
            expect(preview, export, reason: 'timeline frame $frame');
          }

          final engine = ExportEngine(videoDecoderFor: systemDecoder);
          for (final (timelineFrame, sourceFrame) in [
            (2, 5),
            (6, 9),
            (9, 12),
          ]) {
            final path = await engine.exportFrameImage(
              scenes: [scene],
              tileManager: tiles,
              sceneId: scene.id,
              frameIndex: timelineFrame,
              drawingWidth: _w,
              drawingHeight: _h,
              width: _w,
              height: _h,
              backgroundColor: 0xFFFFFFFF,
              asJpeg: false,
              sourceFps: _fps,
              videoMaterials: materials,
            );
            final png = img.decodePng(await File(path).readAsBytes())!;
            // Grey 10N (limited range) at 90% over white paper.
            final grey = (png.getPixel(_w ~/ 2, _h ~/ 2).r - 255 * 0.1) / 0.9;
            expect(
              (grey * 219 / 2550).round(),
              sourceFrame,
              reason: 'timeline frame $timelineFrame',
            );
          }
          expect(leftoverVideoFolders(), isEmpty);
        },
        timeout: const Timeout(Duration(minutes: 3)),
      );
    },
    skip: _ffmpegTests
        ? false
        : 'Set NIARIM_VIDEO_FRAME_FFMPEG_TESTS=1 with ffmpeg and ffprobe on '
              'PATH (required in timeline-preview-export-parity CI).',
  );
}

final _ffmpegTests =
    Platform.environment['NIARIM_VIDEO_FRAME_FFMPEG_TESTS'] == '1';
