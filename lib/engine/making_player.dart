import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:path_provider/path_provider.dart';

import '../models/layer.dart';
import '../models/layer_mask.dart';
import '../services/making_service.dart';
import 'frame_png.dart';
import 'layer_compositor.dart';
import 'layer_keyframe_engine.dart';
import 'making_export.dart';
import 'making_log.dart';
import 'making_video.dart';
import 'niapro_serializer.dart';
import 'tile_manager.dart';
import 'timeline_stack.dart';
import 'video_frame_timeline.dart';

/// Makes the pictures of the recorded steps of a log, from its key frame.
///
/// Rebuilding a step replays the tile references up to it (no pixels) and
/// reads and decompresses only the tiles that differ from the last picture,
/// so going forward costs about one stroke's tiles per step.
class MakingLogRenderer {
  MakingLogRenderer(this.log, this._blobsPath);

  final MakingLogData log;
  final String _blobsPath;

  static final _keyframes = LayerKeyframeEngine();

  final Map<String, Map<String, (int, int)>> _refs = {};
  final Map<String, Map<String, (int, int)>> _loaded = {};
  final Map<int, _Structure> _structures = {};
  int _applied = -2;
  TileManager? _tiles;
  RandomAccessFile? _blobs;
  Future<void> _busy = Future.value();

  int get length => log.steps.length;

  /// The canvas size of step [index].
  (int, int) canvasSizeOf(int index) {
    final structure = _structureOf(log.steps[index].structure);
    return (structure.width, structure.height);
  }

  _Structure _structureOf(int id) =>
      _structures[id] ??= _Structure(log.structures[id]!);

  /// Opens the blobs file now (it is read from the file as it is then, even
  /// when a compaction puts another one in its place).
  void open() {
    _blobs ??= File(_blobsPath).existsSync()
        ? File(_blobsPath).openSync()
        : null;
  }

  /// The picture of step [index] at its canvas size (the caller disposes it).
  Future<ui.Image> render(int index) {
    final result = _busy.then((_) => _render(index));
    _busy = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  void _resetRefs() {
    _refs.clear();
    for (final tile in log.initial) {
      _refs.putIfAbsent(tile.layerKey, () => {})[tile.tileKey] = (
        tile.offset!,
        tile.length!,
      );
    }
    _applied = -1;
  }

  Future<ui.Image> _render(int stepIndex) async {
    final steps = log.steps;
    if (stepIndex < _applied || _applied == -2) _resetRefs();
    for (var i = _applied + 1; i <= stepIndex; i++) {
      for (final tile in steps[i].tiles) {
        final layer = _refs.putIfAbsent(tile.layerKey, () => {});
        if (tile.offset == null) {
          layer.remove(tile.tileKey);
        } else {
          layer[tile.tileKey] = (tile.offset!, tile.length!);
        }
      }
    }
    _applied = stepIndex;
    final structure = _structureOf(steps[stepIndex].structure);
    var tiles = _tiles;
    if (tiles == null ||
        tiles.canvasWidth != structure.width ||
        tiles.canvasHeight != structure.height) {
      tiles?.dispose();
      tiles = _tiles = TileManager(
        canvasWidth: structure.width,
        canvasHeight: structure.height,
        compositeCacheMax: 8,
      );
      _loaded.clear();
    }
    for (final key in structure.keys.toSet()) {
      final wanted = _refs[key] ?? const <String, (int, int)>{};
      final loaded = _loaded.putIfAbsent(key, () => {});
      // Tile by tile: the other tiles' decoded images are kept.
      for (final MapEntry(key: tileKey, value: ref) in wanted.entries) {
        if (loaded[tileKey] == ref) continue;
        tiles.putTile(key, tileKey, _read(ref));
        loaded[tileKey] = ref;
      }
      for (final tileKey in loaded.keys.toList()) {
        if (wanted.containsKey(tileKey)) continue;
        tiles.putTile(key, tileKey, null);
        loaded.remove(tileKey);
      }
    }
    final keyOf = {
      for (var i = 0; i < structure.layers.length; i++)
        structure.layers[i].id: structure.keys[i],
    };
    final frameIndex = steps[stepIndex].frameIndex;
    return LayerCompositor.composite(
      tiles,
      structure.layers,
      (layer) => keyOf[layer.id]!,
      structure.width,
      structure.height,
      // キーフレーム（倍率・回転等）で動かしたレイヤーは、そのコマの位置で。
      keyframeOf: (layer) => layer.keyframes.isEmpty
          ? null
          : _keyframes.valueAt(layer.keyframes, frameIndex),
      // The paper under the picture, as on the canvas (white when it is
      // transparent: a picture has to have something under it).
      paperColor: (structure.paper >>> 24) == 0xFF
          ? structure.paper
          : 0xFFFFFFFF,
      // At full size: the layers that did not change come from the
      // compositor's caches (a reduced raster draws every tile again, about
      // 8 times slower). The screen scales the picture.
      maskGroups: structure.masks,
    );
  }

  Uint8List _read((int, int) ref) {
    open();
    final file = _blobs;
    if (file == null) throw StateError('The making log has no tiles.');
    file.setPositionSync(ref.$1);
    return Uint8List.fromList(zlib.decode(file.readSync(ref.$2)));
  }

  void dispose() {
    _blobs?.closeSync();
    _blobs = null;
    _tiles?.dispose();
    _tiles = null;
  }
}

/// [image] in a picture of exactly [width]×[height]: stretched when it has
/// about the same shape (the even sides of the video), otherwise fitted in
/// the middle on black. The caller disposes the result (which is [image]
/// itself when it already has that size).
Future<ui.Image> makingFit(ui.Image image, int width, int height) async {
  if (image.width == width && image.height == height) return image;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final source = ui.Rect.fromLTWH(
    0,
    0,
    image.width.toDouble(),
    image.height.toDouble(),
  );
  final sameShape =
      ((image.width / image.height) / (width / height) - 1).abs() < 0.01;
  ui.Rect target;
  if (sameShape) {
    target = ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
  } else {
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..color = const ui.Color(0xFF000000),
    );
    final scale = math.min(width / image.width, height / image.height);
    final w = image.width * scale;
    final h = image.height * scale;
    target = ui.Rect.fromLTWH((width - w) / 2, (height - h) / 2, w, h);
  }
  canvas.drawImageRect(
    image,
    source,
    target,
    ui.Paint()..filterQuality = ui.FilterQuality.medium,
  );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(width, height);
  } finally {
    picture.dispose();
  }
}

/// [image] as a PNG file. The pixels are read back as they are and compressed
/// by [encodeFramePng] in another isolate: the engine's own PNG encoder took
/// about 75 ms for a 1920×1080 frame, this about 30 ms, and neither runs on
/// the UI isolate. The file only carries the frame to the video encoder, so
/// only its decoded pixels matter.
Future<int> makingWritePng(ui.Image image, String path) async {
  final data = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  if (data == null) throw StateError('The making picture is empty.');
  final width = image.width;
  final height = image.height;
  final pixels = TransferableTypedData.fromList([
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  ]);
  return Isolate.run(() {
    final bytes = encodeFramePng(
      pixels.materialize().asUint8List(),
      width,
      height,
    );
    File(path).writeAsBytesSync(bytes);
    return bytes.length;
  });
}

/// The picture in the image file at [path] (the caller disposes it).
Future<ui.Image> makingDecodeFile(String path) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(
    await File(path).readAsBytes(),
  );
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  buffer.dispose();
  final codec = await descriptor.instantiateCodec();
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
    descriptor.dispose();
  }
}

Future<(int, int)?> _sizeOfFile(String path) async {
  try {
    final buffer = await ui.ImmutableBuffer.fromUint8List(
      await File(path).readAsBytes(),
    );
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    buffer.dispose();
    final size = (descriptor.width, descriptor.height);
    descriptor.dispose();
    return size;
  } catch (_) {
    return null;
  }
}

/// The picture record files of earlier versions as frames of a making.
class MakingPictureFrames implements MakingFrames {
  MakingPictureFrames(this.paths, this.width, this.height);

  /// [paths] at the size of the first of them.
  static Future<MakingPictureFrames> of(List<String> paths) async {
    final size = await _sizeOfFile(paths.first);
    if (size == null) {
      throw StateError('Making snapshot image is unreadable.');
    }
    return MakingPictureFrames(paths, size.$1, size.$2);
  }

  final List<String> paths;

  @override
  final int width;

  @override
  final int height;

  @override
  int get length => paths.length;

  @override
  List<MakingVideoSpan> get videoSpans => const [];

  @override
  Future<List<String>> writeFrames(
    Directory directory,
    int from,
    int to, {
    required int width,
    required int height,
    MakingPictureMode pictures = MakingPictureMode.sameSize,
  }) async => [
    for (var i = from; i < to; i++)
      await _picture(paths[i], directory, i, width, height, pictures),
  ];
}

Future<String> _picture(
  String path,
  Directory directory,
  int index,
  int width,
  int height,
  MakingPictureMode mode,
) async {
  if (mode == MakingPictureMode.asIs) return path;
  if (mode == MakingPictureMode.sameSize &&
      await _sizeOfFile(path) == (width, height)) {
    return path;
  }
  final image = await makingDecodeFile(path);
  final fitted = await makingFit(image, width, height);
  if (!identical(fitted, image)) image.dispose();
  try {
    final out = makingFramePath(directory, index);
    await makingWritePng(fitted, out);
    return out;
  } finally {
    fitted.dispose();
  }
}

/// Writes step [step] of [renderer] as frame [index] of [width]×[height].
Future<String> _writeStep(
  MakingLogRenderer renderer,
  int step,
  Directory directory,
  int index,
  int width,
  int height,
) async {
  final full = await renderer.render(step);
  final fitted = await makingFit(full, width, height);
  if (!identical(fitted, full)) full.dispose();
  try {
    final path = makingFramePath(directory, index);
    await makingWritePng(fitted, path);
    return path;
  } finally {
    fitted.dispose();
  }
}

/// The recorded steps of a log as frames (for turning them into video).
class MakingLogFrames implements MakingFrames {
  MakingLogFrames(this.renderer, this.width, this.height);

  final MakingLogRenderer renderer;

  @override
  final int width;

  @override
  final int height;

  @override
  int get length => renderer.length;

  @override
  List<MakingVideoSpan> get videoSpans => const [];

  @override
  Future<List<String>> writeFrames(
    Directory directory,
    int from,
    int to, {
    required int width,
    required int height,
    MakingPictureMode pictures = MakingPictureMode.sameSize,
  }) async => [
    for (var i = from; i < to; i++)
      await _writeStep(renderer, i, directory, i, width, height),
  ];
}

/// Where a frame written for the making video goes.
String makingFramePath(Directory directory, int index) =>
    '${directory.path}/f_${index.toString().padLeft(6, '0')}.png';

/// Plays a work's making: first the picture records of earlier versions,
/// then the video segments of the steps turned into video, then the steps of
/// the log, whose pictures are made here as they are shown.
class MakingPlayer implements MakingFrames, MakingFramePicker {
  MakingPlayer._(
    this.projectId,
    this._pictures,
    this._log,
    this._renderer,
    this.sizeBytes,
    this.limitReached,
    this._tools,
  );

  static final Map<String, int> _open = {};

  /// Whether a player of [projectId]'s making is open (its log is not put
  /// in place of another while it is).
  static bool isOpen(String projectId) => (_open[projectId] ?? 0) > 0;

  static Future<MakingPlayer> open(
    String projectId, {
    MakingVideoTools? tools,
  }) async {
    _open[projectId] = (_open[projectId] ?? 0) + 1;
    try {
      final history = await MakingService.history(projectId);
      final dir = await MakingService.logDirectory(projectId);
      // After every compaction sent before (none starts while this is open).
      await MakingLogWriter.prepare(dir);
      final log = await Isolate.run(() => MakingLogData.read(dir));
      final renderer = MakingLogRenderer(log, '$dir/${MakingLog.blobsFile}')
        ..open();
      final player = MakingPlayer._(
        projectId,
        history.snapshots,
        log,
        renderer,
        history.sizeBytes + log.bytes,
        history.limitReached || log.limitReached,
        tools,
      );
      await player._readPictureSize();
      return player;
    } catch (_) {
      _release(projectId);
      rethrow;
    }
  }

  static void _release(String projectId) {
    final count = (_open[projectId] ?? 1) - 1;
    if (count <= 0) {
      _open.remove(projectId);
    } else {
      _open[projectId] = count;
    }
  }

  /// An empty making (nothing recorded).
  factory MakingPlayer.empty() => MakingPlayer._(
    null,
    const [],
    MakingLogData.empty,
    MakingLogRenderer(MakingLogData.empty, ''),
    0,
    false,
    null,
  );

  final String? projectId;
  final List<MakingSnapshot> _pictures;
  final MakingLogData _log;
  final MakingLogRenderer _renderer;
  final MakingVideoTools? _tools;
  MakingVideoTools get _video => _tools ?? MakingVideoTools.instance;

  /// Storage the making uses.
  final int sizeBytes;

  /// Recording stopped at the storage limit.
  final bool limitReached;

  int get _segmentFrames =>
      _log.segments.fold(0, (sum, segment) => sum + segment.frames);

  /// The pictures of the making, in order.
  @override
  int get length => _pictures.length + _segmentFrames + _log.steps.length;

  /// The picture record at [index], or null when it is a frame of a video
  /// segment or a recorded step (made with [render]).
  String? picturePath(int index) =>
      index < _pictures.length ? _pictures[index].path : null;

  /// Longest edge of the pictures shown while playing a video segment.
  static const int playbackMaxEdge = 1280;

  /// Frames decoded at once while playing a video segment.
  static const int _run = 8;

  Future<void> _busy = Future.value();
  bool _disposed = false;

  /// What [index] is: a picture, frame [frame] of segment [segment], or
  /// step [step] of the log.
  ({int? segment, int frame, int? step}) _locate(int index) {
    var i = index - _pictures.length;
    for (var s = 0; s < _log.segments.length; s++) {
      final frames = _log.segments[s].frames;
      if (i < frames) return (segment: s, frame: i, step: null);
      i -= frames;
    }
    return (segment: null, frame: 0, step: i);
  }

  /// The picture of the video frame or recorded step at [index] (the caller
  /// disposes it). A recorded step is at the work's size, a video frame at
  /// most [playbackMaxEdge] wide.
  Future<ui.Image> render(int index) {
    final result = _busy.then((_) => _renderAt(index));
    _busy = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<ui.Image> _renderAt(int index) async {
    final at = _locate(index);
    if (at.segment == null) {
      final step = at.step!;
      final warm = _warm;
      if (step == 0 && warm != null) {
        _warm = null;
        _warming = false;
        return warm;
      }
      return _renderer.render(step);
    }
    final segment = at.segment!;
    final images = await _runOf(segment, at.frame - at.frame % _run);
    final image = images[at.frame % _run].clone();
    // The next run is decoded while this one plays.
    if (at.frame % _run >= _run ~/ 2) _prefetchAfter(segment, at.frame);
    return image;
  }

  // ─── Video segments ────────────────────────────────────────────────────

  final Map<(int, int), Future<List<ui.Image>>> _runs = {};
  final Map<int, Future<VideoFrameTimeline>> _timelines = {};
  Directory? _work;
  ui.Image? _warm;
  bool _warming = false;

  Future<Directory> _workDirectory() async => _work ??= await Directory(
    '${(await getTemporaryDirectory()).path}/niarim_making_play_'
    '${DateTime.now().microsecondsSinceEpoch}',
  ).create(recursive: true);

  Future<VideoFrameTimeline> _timelineOf(int segment) =>
      _timelines[segment] ??= () async {
        final work = await _workDirectory();
        return _video.decoder(work).probe(_log.segments[segment].path);
      }();

  (int, int) _playbackSize(MakingSegment segment) {
    final scale = math.min(
      1.0,
      playbackMaxEdge / math.max(segment.width, segment.height),
    );
    int even(double value) => math.max(2, value.floor() & ~1);
    return (even(segment.width * scale), even(segment.height * scale));
  }

  Future<List<ui.Image>> _runOf(int segment, int start) {
    final key = (segment, start);
    final existing = _runs[key];
    if (existing != null) return existing;
    final run = _decodeRun(segment, start);
    _runs[key] = run;
    // At most three runs are kept (the one playing, the next and the last).
    while (_runs.length > 3) {
      final oldest = _runs.keys.first;
      final dropped = _runs.remove(oldest)!;
      unawaited(
        dropped.then((images) {
          for (final image in images) {
            image.dispose();
          }
        }, onError: (_) {}),
      );
    }
    return run;
  }

  Future<List<ui.Image>> _decodeRun(int segment, int start) async {
    final info = _log.segments[segment];
    final timeline = await _timelineOf(segment);
    final (width, height) = _playbackSize(info);
    final frames = await _video
        .decoder(await _workDirectory())
        .decodeRun(
          path: info.path,
          timeline: timeline,
          firstFrameIndex: start,
          count: math.min(_run, info.frames - start),
          stride: 1,
          width: width,
          height: height,
        );
    final images = <ui.Image>[];
    for (final frame in frames) {
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        frame.rgba,
        frame.width,
        frame.height,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
      images.add(await completer.future);
    }
    if (_disposed) {
      for (final image in images) {
        image.dispose();
      }
      throw StateError('The making player is closed.');
    }
    if (images.isEmpty) throw StateError('No frames in ${info.path}.');
    return images;
  }

  void _prefetchAfter(int segment, int frame) {
    final next = frame - frame % _run + _run;
    if (next < _log.segments[segment].frames) {
      unawaited(_runOf(segment, next).then((_) {}, onError: (_) {}));
      return;
    }
    if (segment + 1 < _log.segments.length) {
      unawaited(_runOf(segment + 1, 0).then((_) {}, onError: (_) {}));
    } else if (_log.steps.isNotEmpty && !_warming && _warm == null) {
      // The first step of the log follows: its picture is made now.
      _warming = true;
      unawaited(
        _renderer.render(0).then((image) {
          if (_disposed) {
            image.dispose();
          } else {
            _warm = image;
          }
        }, onError: (_) {}),
      );
    }
  }

  // ─── Frames for the export ─────────────────────────────────────────────

  @override
  int get width => frameSize.$1;

  @override
  int get height => frameSize.$2;

  /// The size of the making's video frames: the size of its video segments,
  /// or the making size of the first recorded step's canvas, or the size of
  /// the first picture record.
  (int, int) get frameSize {
    if (_log.segments.isNotEmpty) {
      return (_log.segments.first.width, _log.segments.first.height);
    }
    if (_log.steps.isNotEmpty) {
      final (w, h) = _renderer.canvasSizeOf(0);
      return MakingLog.frameSize(w, h);
    }
    return _pictureSize ?? (2, 2);
  }

  (int, int)? _pictureSize;

  /// Reads the size of the first picture record ([frameSize] for a making
  /// of picture records only).
  Future<void> _readPictureSize() async {
    if (_pictures.isEmpty) return;
    _pictureSize = await _sizeOfFile(_pictures.first.path);
  }

  @override
  List<MakingVideoSpan> get videoSpans {
    var start = _pictures.length;
    return [
      for (final segment in _log.segments)
        MakingVideoSpan(
          start: (start += segment.frames) - segment.frames,
          frames: segment.frames,
          path: segment.path,
          width: segment.width,
          height: segment.height,
          fps: segment.fps,
        ),
    ];
  }

  @override
  Future<List<String>> writeFrames(
    Directory directory,
    int from,
    int to, {
    required int width,
    required int height,
    MakingPictureMode pictures = MakingPictureMode.sameSize,
  }) async {
    final paths = <String>[];
    var i = from;
    while (i < to) {
      if (i < _pictures.length) {
        paths.add(
          await _picture(
            _pictures[i].path,
            directory,
            i,
            width,
            height,
            pictures,
          ),
        );
        i++;
        continue;
      }
      final at = _locate(i);
      if (at.segment != null) {
        // The frames of one segment in one pass.
        final segment = _log.segments[at.segment!];
        final count = math.min(to - i, segment.frames - at.frame);
        paths.addAll(
          await _extract(
            at.segment!,
            at.frame,
            count,
            i,
            directory,
            width,
            height,
          ),
        );
        i += count;
        continue;
      }
      paths.add(
        await _writeStep(_renderer, at.step!, directory, i, width, height),
      );
      i++;
    }
    return paths;
  }

  @override
  Future<List<String>> writePickedFrames(
    Directory directory,
    List<int> indices, {
    required int width,
    required int height,
    MakingPictureMode pictures = MakingPictureMode.sameSize,
  }) async {
    final paths = <String>[];
    var k = 0;
    while (k < indices.length) {
      final index = indices[k];
      final at = index < _pictures.length ? null : _locate(index);
      final segment = at?.segment;
      if (segment == null) {
        paths.addAll(
          await writeFrames(
            directory,
            index,
            index + 1,
            width: width,
            height: height,
            pictures: pictures,
          ),
        );
        k++;
        continue;
      }
      // The chosen frames of this segment, in one pass.
      final start = index - at!.frame;
      final end = start + _log.segments[segment].frames;
      final picked = <int>[];
      while (k < indices.length && indices[k] < end) {
        picked.add(indices[k] - start);
        k++;
      }
      paths.addAll(
        await _extractPicked(segment, picked, start, directory, width, height),
      );
    }
    return paths;
  }

  /// Frames [picked] (increasing) of [segment], whose frame 0 is the
  /// making's frame [start], as files named by their index in the making.
  Future<List<String>> _extractPicked(
    int segment,
    List<int> picked,
    int start,
    Directory directory,
    int width,
    int height,
  ) async {
    final first = picked.first;
    if (picked.last - first + 1 == picked.length) {
      return _extract(
        segment,
        first,
        picked.length,
        start + first,
        directory,
        width,
        height,
      );
    }
    final timeline = await _timelineOf(segment);
    final out = await Directory(
      '${directory.path}/picked_${segment}_$first',
    ).create(recursive: true);
    try {
      final ok = await _video.runFfmpeg(
        MakingVideo.extractArguments(
          path: _log.segments[segment].path,
          seekTime: timeline.seekTimeFor(first),
          count: picked.length,
          width: width,
          height: height,
          pattern: '${out.path}/f_%06d.png',
          startNumber: 0,
          pick: [for (final frame in picked) frame - first],
        ),
      );
      final paths = <String>[];
      for (var i = 0; i < picked.length; i++) {
        final written = File(makingFramePath(out, i));
        if (!ok || !written.existsSync()) {
          throw StateError(
            'Could not read frames $picked of '
            '${_log.segments[segment].path}.',
          );
        }
        final path = makingFramePath(directory, start + picked[i]);
        written.renameSync(path);
        paths.add(path);
      }
      return paths;
    } finally {
      try {
        await out.delete(recursive: true);
      } on FileSystemException {
        // Removed with the export's staging folder.
      }
    }
  }

  Future<List<String>> _extract(
    int segment,
    int frame,
    int count,
    int index,
    Directory directory,
    int width,
    int height,
  ) async {
    final timeline = await _timelineOf(segment);
    final ok = await _video.runFfmpeg(
      MakingVideo.extractArguments(
        path: _log.segments[segment].path,
        seekTime: timeline.seekTimeFor(frame),
        count: count,
        width: width,
        height: height,
        pattern: '${directory.path}/f_%06d.png',
        startNumber: index,
      ),
    );
    final paths = [
      for (var i = 0; i < count; i++) makingFramePath(directory, index + i),
    ];
    if (!ok || !paths.every((path) => File(path).existsSync())) {
      throw StateError(
        'Could not read frames $frame+$count of '
        '${_log.segments[segment].path}.',
      );
    }
    return paths;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _warm?.dispose();
    _warm = null;
    for (final run in _runs.values) {
      unawaited(
        run.then((images) {
          for (final image in images) {
            image.dispose();
          }
        }, onError: (_) {}),
      );
    }
    _runs.clear();
    _renderer.dispose();
    final work = _work;
    if (work != null) {
      unawaited(work.delete(recursive: true).then((_) {}, onError: (_) {}));
    }
    if (projectId case final id?) _release(id);
  }
}

class _Structure {
  _Structure(Map<String, dynamic> json)
    : width = json['w'] as int,
      height = json['h'] as int,
      paper = json['paper'] as int,
      layers = [
        for (final layer in json['layers'] as List)
          NiaproSerializer.layerFromJson(layer as Map<String, dynamic>),
      ],
      keys = List<String>.from(json['keys'] as List),
      masks = [
        for (final group in json['masks'] as List? ?? const [])
          if (LayerMask.fromJson((group as Map)['mask']) case final mask?)
            LayerMaskGroup(
              layerIds: Set<String>.from(group['ids'] as List),
              mask: mask,
            ),
      ];

  final int width;
  final int height;
  final int paper;
  final List<Layer> layers;
  final List<String> keys;
  final List<LayerMaskGroup> masks;
}
