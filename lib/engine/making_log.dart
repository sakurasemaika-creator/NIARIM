import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart' show getCrc32;

/// The making of a work, recorded as the steps of its history.
///
/// Each step is one change of the Undo history (an operation done, undone or
/// redone): the tiles it changed and the layers of the frame it was shown on.
/// Nothing is drawn while recording: the tiles are compressed and appended in
/// a background isolate, and identical tile contents are stored once (Undo
/// and Redo point at tiles already stored). Pictures are made only when the
/// making is played or exported ([MakingLogData]).
///
/// Files under `Making/log/`:
/// - `blobs.bin`: zlib-compressed tiles, one after another.
/// - `steps.jsonl`: one JSON object per line: layer structures
///   (`{"k":"s","id":…,"d":…}`), steps (`{"k":"t",…}`) and the storage limit
///   (`{"k":"limit"}`). A line cut short by a crash is ignored.
abstract final class MakingLog {
  static const folder = 'log';
  static const blobsFile = 'blobs.bin';
  static const stepsFile = 'steps.jsonl';

  /// Most storage a work's making may use (the earlier picture records
  /// included). Recording stops at it; nothing recorded is removed.
  static const int maxBytes = 64 * 1024 * 1024;
}

/// One changed tile of a step: its pixels, or null when the tile is gone.
class MakingTileChange {
  MakingTileChange(this.layerKey, this.tileKey, Uint8List? pixels)
    : _pixels = pixels == null
          ? null
          : TransferableTypedData.fromList([pixels]);

  final String layerKey;
  final String tileKey;
  final TransferableTypedData? _pixels;
}

/// What the writer answered for a step.
class MakingStepResult {
  const MakingStepResult({
    required this.written,
    required this.crcs,
    required this.limitReached,
  });

  /// Whether the step was added (false when nothing changed or the storage
  /// limit is reached).
  final bool written;

  /// The CRC-32 now recorded for each tile of the step (`layerKey:tileKey`,
  /// null for a tile recorded as gone).
  final Map<String, int?> crcs;

  final bool limitReached;
}

/// The background writer of the making logs (one isolate for the app).
abstract final class MakingLogWriter {
  static SendPort? _port;
  static Future<SendPort>? _starting;
  static int _nextId = 0;
  static final Map<int, Completer<Object?>> _pending = {};

  static Future<SendPort> _worker() {
    final port = _port;
    if (port != null) return Future.value(port);
    return _starting ??= () async {
      final replies = ReceivePort();
      final ready = Completer<SendPort>();
      replies.listen((message) {
        if (message is SendPort) {
          ready.complete(message);
          return;
        }
        final reply = message as List<Object?>;
        final completer = _pending.remove(reply[0] as int);
        if (completer == null) return;
        if (reply[1] case final String error?) {
          completer.completeError(StateError(error));
        } else {
          completer.complete(reply[2]);
        }
      });
      await Isolate.spawn(
        _workerMain,
        replies.sendPort,
        debugName: 'making-log-writer',
      );
      final port = await ready.future;
      _port = port;
      return port;
    }();
  }

  static Future<Object?> _call(Map<String, Object?> message) async {
    final port = await _worker();
    final id = _nextId++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    port.send({...message, 'id': id});
    return completer.future;
  }

  /// Opens the log in [directory] (`…/Making/log`) and returns the CRC-32 of
  /// every tile it holds now (`layerKey:tileKey`) and whether recording has
  /// stopped at the storage limit.
  static Future<({Map<String, int> crcs, bool limitReached})> open(
    String directory,
  ) async {
    final reply = await _call({'op': 'open', 'dir': directory}) as List;
    return (
      crcs: Map<String, int>.from(reply[0] as Map),
      limitReached: reply[1] as bool,
    );
  }

  /// Adds a step shown on [frameIndex] of [sceneId] with the frame's layer
  /// [structure] (JSON) and the [tiles] it changed.
  static Future<MakingStepResult> step(
    String directory, {
    required int time,
    required String sceneId,
    required int frameIndex,
    required String structure,
    required List<MakingTileChange> tiles,
  }) async {
    final reply =
        await _call({
              'op': 'step',
              'dir': directory,
              'time': time,
              'scene': sceneId,
              'frame': frameIndex,
              'structure': structure,
              'tiles': [
                for (final tile in tiles)
                  [tile.layerKey, tile.tileKey, tile._pixels],
              ],
            })
            as List;
    return MakingStepResult(
      written: reply[0] as bool,
      crcs: Map<String, int?>.from(reply[1] as Map),
      limitReached: reply[2] as bool,
    );
  }

  /// Waits until every step sent so far is written.
  static Future<void> flush() async {
    if (_port == null && _starting == null) return;
    await _call({'op': 'flush'});
  }

  /// Forgets what the writer knows of the log in [directory] (it is about to
  /// be deleted). Waits for the steps sent before.
  static Future<void> forget(String directory) async {
    if (_port == null && _starting == null) return;
    await _call({'op': 'forget', 'dir': directory});
  }

  /// Forgets every log (all data is erased). Does not wait.
  static void forgetAll() {
    if (_port == null && _starting == null) return;
    unawaited(_call({'op': 'forgetAll'}).catchError((_) => null));
  }
}

// ─── Writer isolate ───────────────────────────────────────────────────────

class _Log {
  _Log(this.dir);

  final String dir;

  /// tile (`layerKey:tileKey`) → CRC-32 of its recorded content.
  final Map<String, int> crcs = {};

  /// content (`crc:fnv`) → [offset, length] in the blobs.
  final Map<String, List<int>> blobs = {};

  /// structure JSON → id.
  final Map<String, int> structures = {};

  /// `scene#frame` → structure id of the last step shown there.
  final Map<String, int> lastStructure = {};
  int blobBytes = 0;
  int bytes = 0;
  int steps = 0;
  bool limitReached = false;

  File get blobsFile => File('$dir/${MakingLog.blobsFile}');
  File get stepsFile => File('$dir/${MakingLog.stepsFile}');
}

void _workerMain(SendPort replies) {
  final requests = ReceivePort();
  replies.send(requests.sendPort);
  final logs = <String, _Log>{};
  requests.listen((message) {
    final request = message as Map<String, Object?>;
    final id = request['id'] as int;
    try {
      final Object? result = switch (request['op']) {
        'open' => () {
          final log = logs[request['dir'] as String] ??= _load(
            request['dir'] as String,
          );
          return [log.crcs, log.limitReached];
        }(),
        'step' => _writeStep(
          logs[request['dir'] as String] ??= _load(request['dir'] as String),
          request,
        ),
        'forget' => () {
          logs.remove(request['dir'] as String);
          return null;
        }(),
        'forgetAll' => () {
          logs.clear();
          return null;
        }(),
        _ => null,
      };
      replies.send([id, null, result]);
    } catch (error) {
      replies.send([id, '$error', null]);
    }
  });
}

/// FNV-1a over the 32-bit words of a tile (with the CRC-32, the key under
/// which a tile's content is stored once).
int _fnv(Uint8List pixels) {
  final words = pixels.buffer.asUint32List(
    pixels.offsetInBytes,
    pixels.lengthInBytes ~/ 4,
  );
  var hash = 0x811c9dc5;
  for (var i = 0; i < words.length; i++) {
    hash = ((hash ^ words[i]) * 0x01000193) & 0xffffffff;
  }
  return hash;
}

_Log _load(String dir) {
  final log = _Log(dir);
  final directory = Directory(dir);
  if (directory.parent.existsSync()) {
    // The earlier picture records of the same work count toward the limit.
    for (final entry in directory.parent.listSync(followLinks: false)) {
      if (entry is File &&
          RegExp(r'making_[0-9]{6}\.jpg$').hasMatch(entry.path)) {
        log.bytes += entry.lengthSync();
      }
    }
  }
  final blobs = log.blobsFile;
  log.blobBytes = blobs.existsSync() ? blobs.lengthSync() : 0;
  log.bytes += log.blobBytes;
  final steps = log.stepsFile;
  if (!steps.existsSync()) return log;
  final text = steps.readAsStringSync();
  log.bytes += utf8.encode(text).length;
  for (final line in const LineSplitter().convert(text)) {
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } catch (_) {
      continue; // cut short by a crash
    }
    if (decoded is! Map<String, dynamic>) continue;
    switch (decoded['k']) {
      case 's':
        final id = decoded['id'];
        if (id is int) log.structures[jsonEncode(decoded['d'])] = id;
      case 't':
        log.steps++;
        final structure = decoded['st'];
        if (structure is int) {
          log.lastStructure['${decoded['sc']}#${decoded['f']}'] = structure;
        }
        for (final entry in decoded['e'] as List? ?? const []) {
          if (entry is! List || entry.length < 2) continue;
          final tileId = '${entry[0]}:${entry[1]}';
          if (entry.length < 6) {
            log.crcs.remove(tileId);
            continue;
          }
          final crc = entry[2] as int;
          final offset = entry[4] as int;
          final length = entry[5] as int;
          if (offset + length > log.blobBytes) {
            // The blob never reached the file: the tile is unknown.
            log.crcs.remove(tileId);
            continue;
          }
          log.crcs[tileId] = crc;
          log.blobs['$crc:${entry[3]}'] = [offset, length];
        }
      case 'limit':
        log.limitReached = true;
    }
  }
  return log;
}

List<Object?> _writeStep(_Log log, Map<String, Object?> request) {
  final crcs = <String, int?>{};
  if (log.limitReached) return [false, crcs, true];
  final entries = <List<Object?>>[];
  final newBlobs = BytesBuilder(copy: false);
  final newBlobKeys = <String, List<int>>{};
  for (final raw in request['tiles'] as List) {
    final tile = raw as List;
    final layerKey = tile[0] as String;
    final tileKey = tile[1] as String;
    final tileId = '$layerKey:$tileKey';
    final transferable = tile[2] as TransferableTypedData?;
    if (transferable == null) {
      if (log.crcs.containsKey(tileId)) {
        entries.add([layerKey, tileKey]);
        crcs[tileId] = null;
      }
      continue;
    }
    final pixels = transferable.materialize().asUint8List();
    final crc = getCrc32(pixels);
    if (log.crcs[tileId] == crc) continue;
    final fnv = _fnv(pixels);
    final contentKey = '$crc:$fnv';
    var blob = log.blobs[contentKey] ?? newBlobKeys[contentKey];
    if (blob == null) {
      final compressed = ZLibCodec(level: 6).encode(pixels);
      blob = [log.blobBytes + newBlobs.length, compressed.length];
      newBlobs.add(compressed);
      newBlobKeys[contentKey] = blob;
    }
    entries.add([layerKey, tileKey, crc, fnv, blob[0], blob[1]]);
    crcs[tileId] = crc;
  }

  final scene = request['scene'] as String;
  final frame = request['frame'] as int;
  final structureJson = request['structure'] as String;
  var structureId = log.structures[structureJson];
  final lines = StringBuffer();
  if (structureId == null) {
    structureId = log.structures.length;
    lines.writeln('{"k":"s","id":$structureId,"d":$structureJson}');
  }
  final frameKey = '$scene#$frame';
  if (entries.isEmpty && log.lastStructure[frameKey] == structureId) {
    // Nothing visible changed (e.g. a layer renamed).
    return [false, crcs, false];
  }
  lines.writeln(
    jsonEncode({
      'k': 't',
      'n': log.steps,
      't': request['time'],
      'sc': scene,
      'f': frame,
      'st': structureId,
      'e': entries,
    }),
  );
  final lineBytes = utf8.encode(lines.toString());
  if (log.bytes + newBlobs.length + lineBytes.length > MakingLog.maxBytes) {
    log.limitReached = true;
    Directory(log.dir).createSync(recursive: true);
    log.stepsFile.writeAsStringSync('{"k":"limit"}\n', mode: FileMode.append);
    return [false, <String, int?>{}, true];
  }
  Directory(log.dir).createSync(recursive: true);
  if (newBlobs.isNotEmpty) {
    final added = newBlobs.takeBytes();
    log.blobsFile.writeAsBytesSync(added, mode: FileMode.append);
    log.blobBytes += added.length;
    log.bytes += added.length;
    log.blobs.addAll(newBlobKeys);
  }
  log.stepsFile.writeAsBytesSync(lineBytes, mode: FileMode.append);
  log.bytes += lineBytes.length;
  log.structures[structureJson] = structureId;
  log.lastStructure[frameKey] = structureId;
  log.steps++;
  for (final entry in crcs.entries) {
    if (entry.value == null) {
      log.crcs.remove(entry.key);
    } else {
      log.crcs[entry.key] = entry.value!;
    }
  }
  return [true, crcs, false];
}

// ─── Reading for playback and export ─────────────────────────────────────

/// A tile of a step: where its content is in the blobs, or gone.
typedef MakingTileRef = ({
  String layerKey,
  String tileKey,
  int? offset,
  int? length,
});

/// One recorded step.
class MakingLogStep {
  const MakingLogStep({
    required this.time,
    required this.sceneId,
    required this.frameIndex,
    required this.structure,
    required this.tiles,
  });

  final DateTime time;
  final String sceneId;
  final int frameIndex;
  final int structure;
  final List<MakingTileRef> tiles;
}

/// A making log as read for playback and export.
class MakingLogData {
  const MakingLogData({
    required this.steps,
    required this.structures,
    required this.bytes,
    required this.limitReached,
  });

  static const empty = MakingLogData(
    steps: [],
    structures: {},
    bytes: 0,
    limitReached: false,
  );

  final List<MakingLogStep> steps;

  /// structure id → the layer structure as recorded (JSON).
  final Map<int, Map<String, dynamic>> structures;
  final int bytes;
  final bool limitReached;

  /// Reads the log in [directory] (`…/Making/log`). Blocking: run it in an
  /// isolate.
  static MakingLogData read(String directory) {
    final blobs = File('$directory/${MakingLog.blobsFile}');
    final stepsFile = File('$directory/${MakingLog.stepsFile}');
    if (!stepsFile.existsSync()) return empty;
    final blobBytes = blobs.existsSync() ? blobs.lengthSync() : 0;
    final text = stepsFile.readAsStringSync();
    final steps = <MakingLogStep>[];
    final structures = <int, Map<String, dynamic>>{};
    var limitReached = false;
    for (final line in const LineSplitter().convert(text)) {
      final Object? decoded;
      try {
        decoded = jsonDecode(line);
      } catch (_) {
        continue;
      }
      if (decoded is! Map<String, dynamic>) continue;
      switch (decoded['k']) {
        case 's':
          if (decoded['id'] case final int id) {
            if (decoded['d'] case final Map<String, dynamic> data) {
              structures[id] = data;
            }
          }
        case 't':
          final structure = decoded['st'];
          if (structure is! int || !structures.containsKey(structure)) {
            continue;
          }
          final tiles = <MakingTileRef>[];
          for (final entry in decoded['e'] as List? ?? const []) {
            if (entry is! List || entry.length < 2) continue;
            final layerKey = entry[0] as String;
            final tileKey = entry[1] as String;
            if (entry.length < 6) {
              tiles.add((
                layerKey: layerKey,
                tileKey: tileKey,
                offset: null,
                length: null,
              ));
              continue;
            }
            final offset = entry[4] as int;
            final length = entry[5] as int;
            if (offset + length > blobBytes) continue;
            tiles.add((
              layerKey: layerKey,
              tileKey: tileKey,
              offset: offset,
              length: length,
            ));
          }
          steps.add(
            MakingLogStep(
              time: DateTime.fromMillisecondsSinceEpoch(
                decoded['t'] as int? ?? 0,
              ),
              sceneId: decoded['sc'] as String? ?? '',
              frameIndex: decoded['f'] as int? ?? 0,
              structure: structure,
              tiles: tiles,
            ),
          );
        case 'limit':
          limitReached = true;
      }
    }
    return MakingLogData(
      steps: steps,
      structures: structures,
      bytes: blobBytes + stepsFile.lengthSync(),
      limitReached: limitReached,
    );
  }
}
