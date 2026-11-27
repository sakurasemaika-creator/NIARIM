import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

import '../models/layer.dart';
import '../models/layer_mask.dart';
import '../services/making_service.dart';
import 'layer_compositor.dart';
import 'layer_keyframe_engine.dart';
import 'making_log.dart';
import 'niapro_serializer.dart';
import 'tile_manager.dart';
import 'timeline_stack.dart';

/// Plays a work's making: first the picture records of earlier versions,
/// then the recorded steps, whose pictures are made here as they are shown.
///
/// Rebuilding a step replays the tile references up to it (no pixels) and
/// reads and decompresses only the tiles that differ from the last picture,
/// so playing forward costs about one stroke's tiles per step.
class MakingPlayer {
  MakingPlayer._(
    this._pictures,
    this._log,
    this._blobsPath,
    this.sizeBytes,
    this.limitReached,
  );

  static Future<MakingPlayer> open(String projectId) async {
    final history = await MakingService.history(projectId);
    final dir = await MakingService.logDirectory(projectId);
    final log = await Isolate.run(() => MakingLogData.read(dir));
    return MakingPlayer._(
      history.snapshots,
      log,
      '$dir/${MakingLog.blobsFile}',
      history.sizeBytes + log.bytes,
      history.limitReached || log.limitReached,
    );
  }

  /// An empty making (nothing recorded).
  factory MakingPlayer.empty() =>
      MakingPlayer._(const [], MakingLogData.empty, '', 0, false);

  final List<MakingSnapshot> _pictures;
  final MakingLogData _log;
  final String _blobsPath;

  /// Storage the making uses.
  final int sizeBytes;

  /// Recording stopped at the storage limit.
  final bool limitReached;

  /// The pictures of the making, in order.
  int get length => _pictures.length + _log.steps.length;

  /// The picture record at [index], or null when it is a recorded step (made
  /// with [render]).
  String? picturePath(int index) =>
      index < _pictures.length ? _pictures[index].path : null;

  /// Longest edge of the pictures written for the export.
  static const int maxEdge = 720;

  static final _keyframes = LayerKeyframeEngine();

  final Map<String, Map<String, (int, int)>> _refs = {};
  final Map<String, Map<String, (int, int)>> _loaded = {};
  final Map<int, _Structure> _structures = {};
  int _applied = -1;
  TileManager? _tiles;
  RandomAccessFile? _blobs;
  Future<void> _busy = Future.value();

  /// The picture of the recorded step at [index], at the work's size (the
  /// caller disposes it).
  Future<ui.Image> render(int index) {
    final result = _busy.then((_) => _render(index - _pictures.length));
    _busy = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<ui.Image> _render(int stepIndex) async {
    final steps = _log.steps;
    if (stepIndex < _applied) {
      _refs.clear();
      _applied = -1;
    }
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
    final structure = _structures[steps[stepIndex].structure] ??= _Structure(
      _log.structures[steps[stepIndex].structure]!,
    );
    var tiles = _tiles;
    if (tiles == null ||
        tiles.canvasWidth != structure.width ||
        tiles.canvasHeight != structure.height) {
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
    final file = _blobs ??= File(_blobsPath).openSync();
    file.setPositionSync(ref.$1);
    return Uint8List.fromList(zlib.decode(file.readSync(ref.$2)));
  }

  /// Writes every picture of the making to [directory] as JPEG files (the
  /// picture records as they are) and returns them in order.
  Future<List<String>> writePictures(
    Directory directory, {
    void Function(int done, int total)? onProgress,
  }) async {
    final paths = <String>[];
    for (var i = 0; i < length; i++) {
      final picture = picturePath(i);
      if (picture != null) {
        paths.add(picture);
      } else {
        final full = await render(i);
        // Made smaller before it is read back (a 4K picture would be more
        // than 30 MB).
        final scale = math.min(
          1.0,
          maxEdge / math.max(full.width, full.height),
        );
        final width = math.max(1, (full.width * scale).round());
        final height = math.max(1, (full.height * scale).round());
        final recorder = ui.PictureRecorder();
        ui.Canvas(recorder).drawImageRect(
          full,
          ui.Rect.fromLTWH(0, 0, full.width.toDouble(), full.height.toDouble()),
          ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
          ui.Paint()..filterQuality = ui.FilterQuality.medium,
        );
        full.dispose();
        final picture = recorder.endRecording();
        final image = await picture.toImage(width, height);
        picture.dispose();
        final ByteData? data;
        try {
          data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        } finally {
          image.dispose();
        }
        if (data == null) throw StateError('The making picture is empty.');
        final pixels = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        final path =
            '${directory.path}/step_${i.toString().padLeft(6, '0')}.jpg';
        await Isolate.run(() {
          final jpeg = img.encodeJpg(
            img.Image.fromBytes(
              width: width,
              height: height,
              bytes: pixels.buffer,
              bytesOffset: pixels.offsetInBytes,
              numChannels: 4,
            ),
            quality: 85,
          );
          File(path).writeAsBytesSync(jpeg, flush: true);
        });
        paths.add(path);
      }
      onProgress?.call(i + 1, length);
    }
    return paths;
  }

  void dispose() {
    _blobs?.closeSync();
    _blobs = null;
    _tiles?.dispose();
    _tiles = null;
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
