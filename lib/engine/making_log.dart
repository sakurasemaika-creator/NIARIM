import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
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
/// When the history kept in the log grows large, its oldest steps are turned
/// into a video segment in idle time (`MakingCompactor`), when the video is
/// smaller than the tiles it replaces: the log then starts from a key frame
/// (every tile as it was after those steps, pointing at tiles already
/// stored) and keeps only the steps after it.
///
/// Files under `Making/`:
/// - `log/blobs.bin`: zlib-compressed tiles, one after another.
/// - `log/steps.jsonl`: one JSON object per line: the key frame
///   (`{"k":"key",…}`, first when the log was compacted, listing the video
///   segments before it), layer structures (`{"k":"s","id":…,"d":…}`), steps
///   (`{"k":"t",…}`) and the storage limit (`{"k":"limit"}`). A line cut
///   short by a crash is ignored.
/// - `segments/seg_NNNNNN.mp4`: the compacted steps as H.264 video, one frame
///   per step at [MakingExport.fps], in order. Only the files the key frame
///   lists are part of the making.
/// - `log.next/`, `log.old/`: a compacted log being put in place. The new
///   log is written whole to `log.next/` and swapped in by renaming, so a
///   crash at any point leaves either the old log or the new one.
abstract final class MakingLog {
  static const folder = 'log';
  static const nextFolder = 'log.next';
  static const oldFolder = 'log.old';
  static const segmentsFolder = 'segments';
  static const blobsFile = 'blobs.bin';
  static const stepsFile = 'steps.jsonl';

  /// The frame rate of the making video (one step per frame).
  static const int fps = 8;

  /// Most storage a work's making may use (the earlier picture records, the
  /// log and the video segments together). Recording stops at it; nothing
  /// recorded is removed.
  ///
  /// It is only a safety net for the device's storage: the log is turned into
  /// video whenever the video is smaller, so it is reached only when that is
  /// not possible on the device (no working video encoder) or the work itself
  /// is that large (the log holds every tile of the work once).
  static const int maxBytes = 2 * 1024 * 1024 * 1024;

  /// The size of the making video for a canvas of [width]×[height]: fitted in
  /// 1920×1080 (1080×1920 upright; the size every device's encoder takes),
  /// never larger than the canvas, with even sides (the encoder needs them).
  static (int, int) frameSize(int width, int height) {
    final upright = height > width;
    final boxWidth = upright ? 1080 : 1920;
    final boxHeight = upright ? 1920 : 1080;
    final scale = math.min(1.0, math.min(boxWidth / width, boxHeight / height));
    int even(double value) => math.max(2, value.floor() & ~1);
    return (even(width * scale), even(height * scale));
  }

  /// What a segment of [width]×[height] is expected to take per frame before
  /// one has been made: the bit rate the device's encoder is given (0.1 bit
  /// per pixel, at least 1 Mbit/s), the most a frame costs.
  static int defaultFrameBytes(int width, int height) {
    final bitsPerSecond = math.max(1000000, (width * height * fps * 0.1));
    return (bitsPerSecond / fps / 8).ceil();
  }
}

/// One video segment of a making.
class MakingSegment {
  const MakingSegment({
    required this.path,
    required this.frames,
    required this.width,
    required this.height,
    required this.fps,
    required this.bytes,
  });

  final String path;
  final int frames;
  final int width;
  final int height;
  final int fps;
  final int bytes;

  static MakingSegment? fromJson(Object? json, String segmentsDir) {
    if (json is! Map) return null;
    final name = json['f'];
    final frames = json['n'];
    final width = json['w'];
    final height = json['h'];
    if (name is! String ||
        !_segmentName.hasMatch(name) ||
        frames is! int ||
        width is! int ||
        height is! int ||
        frames <= 0) {
      return null;
    }
    return MakingSegment(
      path: '$segmentsDir/$name',
      frames: frames,
      width: width,
      height: height,
      fps: json['fps'] is int ? json['fps'] as int : MakingLog.fps,
      bytes: json['b'] is int ? json['b'] as int : 0,
    );
  }
}

final _segmentName = RegExp(r'^seg_[0-9]{6}\.mp4$');

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
    this.historyBytes = 0,
  });

  /// Whether the step was added (false when nothing changed or the storage
  /// limit is reached).
  final bool written;

  /// The CRC-32 now recorded for each tile of the step (`layerKey:tileKey`,
  /// null for a tile recorded as gone).
  final Map<String, int?> crcs;

  final bool limitReached;

  /// About how much of the log is history (tiles no longer shown at the end
  /// of the log, and the step lines): what turning the steps into video can
  /// free.
  final int historyBytes;
}

/// The oldest steps of a log worth turning into video ([MakingLogWriter.plan]).
class MakingCompactionPlan {
  const MakingCompactionPlan({
    required this.token,
    required this.steps,
    required this.width,
    required this.height,
    required this.frameBytes,
    required this.saving,
  });

  /// The log the plan is for (a log compacted or deleted since has another).
  final int token;

  /// How many steps, from the first of the log, to turn into video.
  final int steps;

  /// The size of the video frames.
  final int width;
  final int height;

  /// What a video frame is expected to take.
  final int frameBytes;

  /// The bytes expected to be saved.
  final int saving;
}

/// A video segment made from the first steps of a log, ready to be put in
/// the making ([MakingLogWriter.compact]).
class MakingSegmentFile {
  const MakingSegmentFile({
    required this.path,
    required this.frames,
    required this.width,
    required this.height,
  });

  /// Where it was made (it is moved into the making).
  final String path;
  final int frames;
  final int width;
  final int height;
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

  static Future<Object?> _call(Map<String, Object?> message) {
    final id = _nextId++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    final port = _port;
    // Sent at once when the worker runs, so messages keep the order they
    // were sent in (a compaction is never overtaken by a later reader).
    if (port != null) {
      port.send({...message, 'id': id});
    } else {
      _worker().then(
        (port) => port.send({...message, 'id': id}),
        onError: (Object error, StackTrace stack) {
          _pending.remove(id);
          completer.completeError(error, stack);
        },
      );
    }
    return completer.future;
  }

  /// Opens the log in [directory] (`…/Making/log`) and returns the CRC-32 of
  /// every tile it holds now (`layerKey:tileKey`) and whether recording has
  /// stopped at the storage limit.
  static Future<({Map<String, int> crcs, bool limitReached, int historyBytes})>
  open(String directory) async {
    final reply = await _call({'op': 'open', 'dir': directory}) as List;
    return (
      crcs: Map<String, int>.from(reply[0] as Map),
      limitReached: reply[1] as bool,
      historyBytes: reply[2] as int,
    );
  }

  /// Makes the files in [directory] whole again after a crash (a compacted
  /// log half put in place), after every message sent before. Call it before
  /// reading the log.
  static Future<void> prepare(String directory) async {
    await _call({'op': 'prepare', 'dir': directory});
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
      historyBytes: reply[3] as int,
    );
  }

  /// The oldest steps of the log in [directory] whose video is expected to
  /// be smaller than what they keep in the log, or null when none are.
  /// [frameBytes] overrides the expected size of a video frame.
  static Future<MakingCompactionPlan?> plan(
    String directory, {
    int? frameBytes,
  }) async {
    final reply = await _call({
      'op': 'plan',
      'dir': directory,
      'frameBytes': frameBytes,
    });
    if (reply is! List) return null;
    return MakingCompactionPlan(
      token: reply[0] as int,
      steps: reply[1] as int,
      width: reply[2] as int,
      height: reply[3] as int,
      frameBytes: reply[4] as int,
      saving: reply[5] as int,
    );
  }

  /// Puts [segments] (made from the first steps of the log, in order) in the
  /// making and rewrites the log to start after them. Nothing changes when
  /// the log is no longer the one [token] names. Returns whether it did, and
  /// how much history the log keeps.
  static Future<({bool done, int historyBytes})> compact(
    String directory, {
    required int token,
    required List<MakingSegmentFile> segments,
  }) async {
    final reply =
        await _call({
              'op': 'compact',
              'dir': directory,
              'token': token,
              'segments': [
                for (final segment in segments)
                  [segment.path, segment.frames, segment.width, segment.height],
              ],
            })
            as List;
    return (done: reply[0] as bool, historyBytes: reply[1] as int);
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

// ─── Parsing (shared by the writer and the readers) ──────────────────────

/// A tile of a step or of the key frame. [offset] is null for a tile gone.
class _Entry {
  _Entry(
    this.layerKey,
    this.tileKey, [
    this.crc,
    this.fnv,
    this.offset,
    this.length,
  ]);

  final String layerKey;
  final String tileKey;
  final int? crc;
  final int? fnv;
  final int? offset;
  final int? length;

  String get tileId => '$layerKey:$tileKey';
  String get content => '$crc:$fnv';
  bool get gone => offset == null;

  List<Object?> toJson([int? newOffset]) => gone
      ? [layerKey, tileKey]
      : [layerKey, tileKey, crc, fnv, newOffset ?? offset, length];
}

class _ParsedStep {
  _ParsedStep(this.json, this.structure, this.entries, this.lineBytes);

  final Map<String, dynamic> json;
  final int structure;
  final List<_Entry> entries;
  final int lineBytes;
}

/// A log's lines as read.
class _Parsed {
  int base = 0;
  final List<Object?> segments = [];
  final Map<String, int> lastStructure = {};
  final List<_Entry> key = [];
  int keyLineBytes = 0;

  /// id → the structure as recorded.
  final Map<int, Object?> structures = {};
  final List<_ParsedStep> steps = [];
  bool limit = false;
}

/// Reads the lines of a log whose blobs file holds [blobBytes] bytes. Tiles
/// whose blob never reached the file are left out (as if unknown), and so are
/// steps whose structure is missing: every reader sees the same steps.
_Parsed _parse(String text, int blobBytes) {
  final parsed = _Parsed();
  _Entry? entryOf(Object? raw) {
    if (raw is! List || raw.length < 2) return null;
    final layerKey = raw[0];
    final tileKey = raw[1];
    if (layerKey is! String || tileKey is! String) return null;
    if (raw.length < 6) return _Entry(layerKey, tileKey);
    final crc = raw[2];
    final fnv = raw[3];
    final offset = raw[4];
    final length = raw[5];
    if (crc is! int || fnv is! int || offset is! int || length is! int) {
      return null;
    }
    // The blob never reached the file: the tile is unknown.
    if (offset < 0 || length <= 0 || offset + length > blobBytes) return null;
    return _Entry(layerKey, tileKey, crc, fnv, offset, length);
  }

  var first = true;
  for (final line in const LineSplitter().convert(text)) {
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } catch (_) {
      continue; // cut short by a crash
    }
    if (decoded is! Map<String, dynamic>) continue;
    switch (decoded['k']) {
      case 'key' when first:
        parsed.base = decoded['base'] as int? ?? 0;
        parsed.keyLineBytes = utf8.encode(line).length + 1;
        if (decoded['seg'] case final List segments) {
          parsed.segments.addAll(segments);
        }
        if (decoded['ls'] case final Map last) {
          for (final MapEntry(:key, :value) in last.entries) {
            if (key is String && value is int) {
              parsed.lastStructure[key] = value;
            }
          }
        }
        for (final raw in decoded['e'] as List? ?? const []) {
          final entry = entryOf(raw);
          if (entry != null && !entry.gone) parsed.key.add(entry);
        }
      case 's':
        if (decoded['id'] case final int id) {
          if (decoded['d'] case final Map<String, dynamic> data) {
            parsed.structures[id] = data;
          }
        }
      case 't':
        final structure = decoded['st'];
        if (structure is! int || !parsed.structures.containsKey(structure)) {
          break;
        }
        final entries = <_Entry>[];
        for (final raw in decoded['e'] as List? ?? const []) {
          final entry = entryOf(raw);
          if (entry != null) entries.add(entry);
        }
        parsed.steps.add(
          _ParsedStep(
            decoded,
            structure,
            entries,
            utf8.encode(line).length + 1,
          ),
        );
      case 'limit':
        parsed.limit = true;
    }
    first = false;
  }
  return parsed;
}

/// Makes the files of the making in [makingDir] whole again after a crash
/// while a compacted log was being put in place.
void _recover(String makingDir) {
  final current = Directory('$makingDir/${MakingLog.folder}');
  final next = Directory('$makingDir/${MakingLog.nextFolder}');
  final old = Directory('$makingDir/${MakingLog.oldFolder}');
  if (next.existsSync()) {
    if (current.existsSync()) {
      // Not put in place yet: the old log is whole.
      next.deleteSync(recursive: true);
    } else {
      // Written whole, half put in place.
      next.renameSync(current.path);
    }
  }
  if (old.existsSync()) old.deleteSync(recursive: true);
}

/// Deletes the video files of [makingDir] the log does not list (made but not
/// put in place before a crash).
void _removeUnlisted(String makingDir, Iterable<Object?> segments) {
  final dir = Directory('$makingDir/${MakingLog.segmentsFolder}');
  if (!dir.existsSync()) return;
  final listed = {
    for (final segment in segments)
      if (segment is Map && segment['f'] is String) segment['f'] as String,
  };
  for (final entry in dir.listSync(followLinks: false)) {
    final name = entry.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
    if (!listed.contains(name)) entry.deleteSync(recursive: true);
  }
}

// ─── Writer isolate ───────────────────────────────────────────────────────

int _tokens = 0;

class _Log {
  _Log(this.dir) : token = ++_tokens;

  final String dir;

  /// Changes whenever the log is read again (after a compaction).
  final int token;

  String get makingDir => Directory(dir).parent.path;

  /// tile (`layerKey:tileKey`) → CRC-32 of its recorded content.
  final Map<String, int> crcs = {};

  /// content (`crc:fnv`) → [offset, length] in the blobs.
  final Map<String, List<int>> blobs = {};

  /// structure JSON → id.
  final Map<String, int> structures = {};
  int nextStructure = 0;

  /// `scene#frame` → structure id of the last step shown there.
  final Map<String, int> lastStructure = {};

  /// The content each tile shows at the end of the log, how many tiles show
  /// each content, and the bytes of the contents shown.
  final Map<String, String> tileContent = {};
  final Map<String, int> contentRefs = {};
  int liveBytes = 0;

  int pictureBytes = 0;
  int blobBytes = 0;
  int lineBytes = 0;
  int segmentBytes = 0;
  int steps = 0;
  int base = 0;
  final List<Object?> segments = [];
  bool limitReached = false;

  int get bytes => pictureBytes + blobBytes + lineBytes + segmentBytes;
  int get historyBytes => math.max(0, blobBytes + lineBytes - liveBytes);

  File get blobsFile => File('$dir/${MakingLog.blobsFile}');
  File get stepsFile => File('$dir/${MakingLog.stepsFile}');

  void show(String tileId, String? content) {
    final previous = tileContent.remove(tileId);
    if (previous != null) {
      final count = contentRefs[previous]! - 1;
      if (count == 0) {
        contentRefs.remove(previous);
        liveBytes -= blobs[previous]?[1] ?? 0;
      } else {
        contentRefs[previous] = count;
      }
    }
    if (content == null) return;
    tileContent[tileId] = content;
    final count = (contentRefs[content] ?? 0) + 1;
    contentRefs[content] = count;
    if (count == 1) liveBytes += blobs[content]?[1] ?? 0;
  }
}

void _workerMain(SendPort replies) {
  final requests = ReceivePort();
  replies.send(requests.sendPort);
  final logs = <String, _Log>{};
  _Log logOf(Map<String, Object?> request) =>
      logs[request['dir'] as String] ??= _load(request['dir'] as String);
  requests.listen((message) {
    final request = message as Map<String, Object?>;
    final id = request['id'] as int;
    try {
      final Object? result = switch (request['op']) {
        'open' => () {
          final log = logOf(request);
          return [log.crcs, log.limitReached, log.historyBytes];
        }(),
        'prepare' => () {
          logOf(request);
          return null;
        }(),
        'step' => _writeStep(logOf(request), request),
        'plan' => _plan(logOf(request), request['frameBytes'] as int?),
        'compact' => () {
          final log = logOf(request);
          final done = _compact(log, request);
          if (!done) return [false, log.historyBytes];
          // Read again from the new files.
          final reloaded = logs[log.dir] = _load(log.dir);
          return [true, reloaded.historyBytes];
        }(),
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
  final makingDir = log.makingDir;
  if (Directory(makingDir).existsSync()) {
    _recover(makingDir);
    // The earlier picture records of the same work count toward the limit.
    for (final entry in Directory(makingDir).listSync(followLinks: false)) {
      if (entry is File &&
          RegExp(r'making_[0-9]{6}\.jpg$').hasMatch(entry.path)) {
        log.pictureBytes += entry.lengthSync();
      }
    }
  }
  final blobs = log.blobsFile;
  log.blobBytes = blobs.existsSync() ? blobs.lengthSync() : 0;
  final steps = log.stepsFile;
  if (!steps.existsSync()) {
    _removeUnlisted(makingDir, const []);
    return log;
  }
  final bytes = steps.readAsBytesSync();
  log.lineBytes = bytes.length;
  final parsed = _parse(
    utf8.decode(bytes, allowMalformed: true),
    log.blobBytes,
  );
  _removeUnlisted(makingDir, parsed.segments);
  log.base = parsed.base;
  log.segments.addAll(parsed.segments);
  for (final segment in parsed.segments) {
    if (segment is Map && segment['f'] is String) {
      final file = File(
        '$makingDir/${MakingLog.segmentsFolder}/${segment['f']}',
      );
      if (file.existsSync()) log.segmentBytes += file.lengthSync();
    }
  }
  for (final MapEntry(:key, :value) in parsed.structures.entries) {
    log.structures[jsonEncode(value)] = key;
    log.nextStructure = math.max(log.nextStructure, key + 1);
  }
  log.lastStructure.addAll(parsed.lastStructure);
  void apply(_Entry entry) {
    final tileId = entry.tileId;
    if (entry.gone) {
      log.crcs.remove(tileId);
      log.show(tileId, null);
      return;
    }
    log.crcs[tileId] = entry.crc!;
    log.blobs[entry.content] = [entry.offset!, entry.length!];
    log.show(tileId, entry.content);
  }

  parsed.key.forEach(apply);
  for (final step in parsed.steps) {
    log.steps++;
    log.lastStructure['${step.json['sc']}#${step.json['f']}'] = step.structure;
    step.entries.forEach(apply);
  }
  log.limitReached = parsed.limit;
  return log;
}

List<Object?> _writeStep(_Log log, Map<String, Object?> request) {
  final crcs = <String, int?>{};
  if (log.limitReached) return [false, crcs, true, log.historyBytes];
  final entries = <List<Object?>>[];
  final newBlobs = BytesBuilder(copy: false);
  final newBlobKeys = <String, List<int>>{};
  final shown = <String, String?>{};
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
        shown[tileId] = null;
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
    shown[tileId] = contentKey;
  }

  final scene = request['scene'] as String;
  final frame = request['frame'] as int;
  final structureJson = request['structure'] as String;
  var structureId = log.structures[structureJson];
  final lines = StringBuffer();
  if (structureId == null) {
    structureId = log.nextStructure;
    lines.writeln('{"k":"s","id":$structureId,"d":$structureJson}');
  }
  final frameKey = '$scene#$frame';
  if (entries.isEmpty && log.lastStructure[frameKey] == structureId) {
    // Nothing visible changed (e.g. a layer renamed).
    return [false, crcs, false, log.historyBytes];
  }
  lines.writeln(
    jsonEncode({
      'k': 't',
      'n': log.base + log.steps,
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
    log.lineBytes += 14;
    return [false, <String, int?>{}, true, log.historyBytes];
  }
  Directory(log.dir).createSync(recursive: true);
  if (newBlobs.isNotEmpty) {
    final added = newBlobs.takeBytes();
    log.blobsFile.writeAsBytesSync(added, mode: FileMode.append);
    log.blobBytes += added.length;
    log.blobs.addAll(newBlobKeys);
  }
  log.stepsFile.writeAsBytesSync(lineBytes, mode: FileMode.append);
  log.lineBytes += lineBytes.length;
  if (structureId == log.nextStructure) {
    log.structures[structureJson] = structureId;
    log.nextStructure++;
  }
  log.lastStructure[frameKey] = structureId;
  log.steps++;
  for (final entry in crcs.entries) {
    if (entry.value == null) {
      log.crcs.remove(entry.key);
    } else {
      log.crcs[entry.key] = entry.value!;
    }
  }
  for (final MapEntry(:key, :value) in shown.entries) {
    log.show(key, value);
  }
  return [true, crcs, false, log.historyBytes];
}

/// Fewest steps worth a video segment.
const int _minCompactedSteps = 16;

/// Fewest bytes a compaction has to save.
const int _minSaving = 2 * 1024 * 1024;

/// About what one tile of the key frame takes in its line.
const int _keyEntryBytes = 64;

/// The video segments a log lists so far: their frames and bytes.
({int frames, int bytes, int? width, int? height}) _segmentTotals(
  List<Object?> segments,
  String makingDir,
) {
  var frames = 0;
  var bytes = 0;
  int? width;
  int? height;
  for (final raw in segments) {
    final segment = MakingSegment.fromJson(
      raw,
      '$makingDir/${MakingLog.segmentsFolder}',
    );
    if (segment == null) continue;
    width ??= segment.width;
    height ??= segment.height;
    frames += segment.frames;
    bytes += segment.bytes;
  }
  return (frames: frames, bytes: bytes, width: width, height: height);
}

_Parsed? _readParsed(_Log log) {
  final steps = log.stepsFile;
  if (!steps.existsSync()) return null;
  final blobs = log.blobsFile;
  return _parse(
    utf8.decode(steps.readAsBytesSync(), allowMalformed: true),
    blobs.existsSync() ? blobs.lengthSync() : 0,
  );
}

/// The prefix of the log whose video saves the most, if it saves enough.
///
/// A tile content is freed by turning the first k steps into video when no
/// tile shows it any more after step k−1 and no later step points at it:
/// with e the step that overwrites a tile showing it (none: never freed),
/// when k > every such e.
List<Object?>? _plan(_Log log, int? frameBytesOverride) {
  final parsed = _readParsed(log);
  if (parsed == null) return null;
  final steps = parsed.steps;
  final n = steps.length;
  if (n < _minCompactedSteps) return null;
  final totals = _segmentTotals(parsed.segments, log.makingDir);
  int width;
  int height;
  if (totals.width != null) {
    width = totals.width!;
    height = totals.height!;
  } else {
    final structure = parsed.structures[steps.first.structure];
    if (structure is! Map || structure['w'] is! int || structure['h'] is! int) {
      return null;
    }
    (width, height) = MakingLog.frameSize(
      structure['w'] as int,
      structure['h'] as int,
    );
  }
  final frameBytes =
      frameBytesOverride ??
      (totals.frames >= 32
          ? (totals.bytes / totals.frames).ceil()
          : MakingLog.defaultFrameBytes(width, height));

  final lengthOf = <String, int>{};
  final lastNeeded = <String, int>{};
  final state = <String, String>{};
  const never = 1 << 40;
  for (final entry in parsed.key) {
    state[entry.tileId] = entry.content;
    lengthOf[entry.content] = entry.length!;
  }
  // Tiles shown after each step, for the size of the key frame.
  final shownAfter = List<int>.filled(n + 1, 0);
  shownAfter[0] = state.length;
  for (var i = 0; i < n; i++) {
    for (final entry in steps[i].entries) {
      final previous = state[entry.tileId];
      if (previous != null) {
        lastNeeded[previous] = math.max(lastNeeded[previous] ?? -1, i);
      }
      if (entry.gone) {
        state.remove(entry.tileId);
      } else {
        state[entry.tileId] = entry.content;
        lengthOf[entry.content] = entry.length!;
      }
    }
    shownAfter[i + 1] = state.length;
  }
  for (final content in state.values) {
    lastNeeded[content] = never;
  }
  // Contents never overwritten while shown are needed after every k.
  final freedAt = List<int>.filled(n + 1, 0);
  for (final MapEntry(key: content, value: last) in lastNeeded.entries) {
    if (last < n) freedAt[last + 1] += lengthOf[content] ?? 0;
  }
  var freed = 0;
  var lines = 0;
  var bestSteps = 0;
  var bestSaving = 0;
  for (var k = 1; k <= n; k++) {
    freed += freedAt[k];
    lines += steps[k - 1].lineBytes;
    if (k < _minCompactedSteps) continue;
    final saving =
        freed +
        lines +
        parsed.keyLineBytes -
        shownAfter[k] * _keyEntryBytes -
        k * frameBytes;
    if (saving > bestSaving) {
      bestSaving = saving;
      bestSteps = k;
    }
  }
  if (bestSteps == 0 || bestSaving < _minSaving) return null;
  return [log.token, bestSteps, width, height, frameBytes, bestSaving];
}

/// Moves [from] to [to] (copying when they are on different file systems).
void _move(File from, String to) {
  try {
    from.renameSync(to);
  } on FileSystemException {
    from.copySync(to);
    from.deleteSync();
  }
}

/// Puts the video segments of the request in the making and rewrites the log
/// to start, with a key frame, after the steps they show. False when the log
/// is not the one planned for, is gone, or the segments do not fit it.
bool _compact(_Log log, Map<String, Object?> request) {
  if (request['token'] != log.token) return false;
  final makingDir = log.makingDir;
  if (!Directory(log.dir).existsSync()) return false;
  final parsed = _readParsed(log);
  if (parsed == null) return false;
  final made = [
    for (final raw in request['segments'] as List)
      (
        path: (raw as List)[0] as String,
        frames: raw[1] as int,
        width: raw[2] as int,
        height: raw[3] as int,
      ),
  ];
  final k = made.fold(0, (sum, segment) => sum + segment.frames);
  if (made.isEmpty || k <= 0 || k > parsed.steps.length) return false;
  for (final segment in made) {
    if (!File(segment.path).existsSync()) return false;
  }

  // Every tile as it is after the compacted steps.
  final state = <String, _Entry>{
    for (final entry in parsed.key) entry.tileId: entry,
  };
  for (final step in parsed.steps.take(k)) {
    for (final entry in step.entries) {
      if (entry.gone) {
        state.remove(entry.tileId);
      } else {
        state[entry.tileId] = entry;
      }
    }
  }
  final kept = parsed.steps.sublist(k);

  // The blobs still pointed at, in their order in the old file.
  final live = <int, int>{}; // offset → length
  for (final entry in state.values) {
    live[entry.offset!] = entry.length!;
  }
  for (final step in kept) {
    for (final entry in step.entries) {
      if (!entry.gone) live[entry.offset!] = entry.length!;
    }
  }
  final offsets = live.keys.toList()..sort();

  final next = Directory('$makingDir/${MakingLog.nextFolder}');
  if (next.existsSync()) next.deleteSync(recursive: true);
  next.createSync();
  final moved = <File>[];
  try {
    final newOffsets = <int, int>{}; // old offset → new offset
    final source = log.blobsFile.openSync();
    final target = File(
      '${next.path}/${MakingLog.blobsFile}',
    ).openSync(mode: FileMode.writeOnly);
    try {
      var position = 0;
      for (final offset in offsets) {
        final length = live[offset]!;
        source.setPositionSync(offset);
        final bytes = source.readSync(length);
        if (bytes.length != length) {
          throw FileSystemException('A tile of the log is cut short', log.dir);
        }
        target.writeFromSync(bytes);
        newOffsets[offset] = position;
        position += length;
      }
      target.flushSync();
    } finally {
      source.closeSync();
      target.closeSync();
    }

    // Names of the new segments, after the ones listed.
    final segmentsDir = Directory('$makingDir/${MakingLog.segmentsFolder}');
    var number = 0;
    for (final raw in parsed.segments) {
      if (raw is Map && raw['f'] is String) {
        number = math.max(
          number,
          int.tryParse((raw['f'] as String).substring(4, 10)) ?? 0,
        );
      }
    }
    final segmentLines = [...parsed.segments];
    final names = <String>[];
    for (final segment in made) {
      number++;
      final name = 'seg_${number.toString().padLeft(6, '0')}.mp4';
      names.add(name);
      segmentLines.add({
        'f': name,
        'n': segment.frames,
        'w': segment.width,
        'h': segment.height,
        'fps': MakingLog.fps,
        'b': File(segment.path).lengthSync(),
      });
    }

    final usedStructures = <int>{
      for (final step in kept) step.structure,
      ...log.lastStructure.values,
    };
    final text = StringBuffer()
      ..writeln(
        jsonEncode({
          'k': 'key',
          'v': 2,
          'base': parsed.base + k,
          'seg': segmentLines,
          'ls': log.lastStructure,
          'e': [
            for (final entry in state.values)
              entry.toJson(newOffsets[entry.offset]),
          ],
        }),
      );
    for (final id in usedStructures.toList()..sort()) {
      final structure = parsed.structures[id];
      if (structure == null) continue;
      text.writeln(jsonEncode({'k': 's', 'id': id, 'd': structure}));
    }
    for (final step in kept) {
      text.writeln(
        jsonEncode({
          ...step.json,
          'e': [
            for (final entry in step.entries)
              entry.toJson(entry.gone ? null : newOffsets[entry.offset]),
          ],
        }),
      );
    }
    File(
      '${next.path}/${MakingLog.stepsFile}',
    ).writeAsStringSync(text.toString(), flush: true);

    // The video files go in before the swap (a crash before it leaves them
    // unlisted, and they are removed when the log is read again).
    segmentsDir.createSync();
    for (var i = 0; i < made.length; i++) {
      final target = '${segmentsDir.path}/${names[i]}';
      _move(File(made[i].path), target);
      moved.add(File(target));
    }
  } catch (_) {
    for (final file in moved) {
      if (file.existsSync()) file.deleteSync();
    }
    if (next.existsSync()) next.deleteSync(recursive: true);
    rethrow;
  }

  final old = Directory('$makingDir/${MakingLog.oldFolder}');
  Directory(log.dir).renameSync(old.path);
  next.renameSync(log.dir);
  old.deleteSync(recursive: true);
  return true;
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
    this.initial = const [],
    this.segments = const [],
    this.base = 0,
  });

  static const empty = MakingLogData(
    steps: [],
    structures: {},
    bytes: 0,
    limitReached: false,
  );

  final List<MakingLogStep> steps;

  /// Every tile before the first step (the key frame of a compacted log).
  final List<MakingTileRef> initial;

  /// The video segments that play before the steps, in order.
  final List<MakingSegment> segments;

  /// How many steps the segments show.
  final int base;

  /// structure id → the layer structure as recorded (JSON).
  final Map<int, Map<String, dynamic>> structures;

  /// The bytes of the log and its video segments.
  final int bytes;
  final bool limitReached;

  /// Reads the log in [directory] (`…/Making/log`). Blocking: run it in an
  /// isolate.
  static MakingLogData read(String directory) {
    final blobs = File('$directory/${MakingLog.blobsFile}');
    final stepsFile = File('$directory/${MakingLog.stepsFile}');
    if (!stepsFile.existsSync()) return empty;
    final blobBytes = blobs.existsSync() ? blobs.lengthSync() : 0;
    final raw = stepsFile.readAsBytesSync();
    final parsed = _parse(utf8.decode(raw, allowMalformed: true), blobBytes);
    MakingTileRef refOf(_Entry entry) => (
      layerKey: entry.layerKey,
      tileKey: entry.tileKey,
      offset: entry.offset,
      length: entry.length,
    );
    final segmentsDir =
        '${Directory(directory).parent.path}/${MakingLog.segmentsFolder}';
    final segments = <MakingSegment>[];
    var segmentBytes = 0;
    for (final raw in parsed.segments) {
      final segment = MakingSegment.fromJson(raw, segmentsDir);
      if (segment == null) continue;
      final file = File(segment.path);
      if (!file.existsSync()) continue;
      segmentBytes += file.lengthSync();
      segments.add(segment);
    }
    return MakingLogData(
      steps: [
        for (final step in parsed.steps)
          MakingLogStep(
            time: DateTime.fromMillisecondsSinceEpoch(
              step.json['t'] as int? ?? 0,
            ),
            sceneId: step.json['sc'] as String? ?? '',
            frameIndex: step.json['f'] as int? ?? 0,
            structure: step.structure,
            tiles: [for (final entry in step.entries) refOf(entry)],
          ),
      ],
      initial: [for (final entry in parsed.key) refOf(entry)],
      segments: segments,
      base: parsed.base,
      structures: {
        for (final MapEntry(:key, :value) in parsed.structures.entries)
          key: value as Map<String, dynamic>,
      },
      bytes: blobBytes + raw.length + segmentBytes,
      limitReached: parsed.limit,
    );
  }
}
