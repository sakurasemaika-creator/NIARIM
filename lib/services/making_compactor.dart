import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import '../engine/making_export.dart';
import '../engine/making_log.dart';
import '../engine/making_player.dart';
import '../engine/making_video.dart';
import '../utils/app_error_reporter.dart';
import 'storage_info_service.dart';

/// Turns the oldest steps of the making logs into video, only while the app
/// is idle.
///
/// A log keeps every tile its steps changed. Once the history in it (tiles no
/// longer shown at its end) passes [triggerBytes], the oldest steps whose
/// video is smaller than what they keep ([MakingLogWriter.plan]) are drawn
/// one frame at a time, encoded by the device's H.264 encoder in parts of at
/// most [chunkFrames] frames, each part checked (all frames
/// there, the last one showing its picture), and then put in the making in
/// place of those steps ([MakingLogWriter.compact]). Nothing is drawn while
/// the user touches the screen or types, or while the app is not in front:
/// the work waits until nothing has happened for [idleDelay]. When a part
/// cannot be made or checked, the steps stay in the log as they are (and the
/// work is not tried again until the app starts again).
class MakingCompactor {
  MakingCompactor({
    required this.isWorkActive,
    this.onCompacted,
    this.idleDelay = const Duration(seconds: 4),
    this.tools,
  }) {
    try {
      GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
      HardwareKeyboard.instance.addHandler(_onKey);
      _listening = true;
    } catch (_) {
      // No binding (a test of the services alone): only the history counts.
    }
  }

  /// History in a log that makes it worth looking at.
  static const int triggerBytes = 16 * 1024 * 1024;

  /// More history needed before looking again at a log whose steps were not
  /// worth turning into video.
  static const int recheckBytes = 8 * 1024 * 1024;

  /// Frames of one segment at most (15 seconds): the encoder, which goes on
  /// once started, is busy for a few seconds at most when the user starts
  /// drawing again.
  static const int chunkFrames = 120;

  /// Whether the work [projectId] is still a work being made (not in the
  /// Trash or deleted).
  final bool Function(String projectId) isWorkActive;

  /// Told when [projectId]'s log has been compacted.
  final void Function(String projectId)? onCompacted;

  final Duration idleDelay;

  /// The video tools (those in use when null).
  final MakingVideoTools? tools;
  MakingVideoTools get _video => tools ?? MakingVideoTools.instance;

  final Stopwatch _clock = Stopwatch()..start();
  int _lastInput = 0;
  bool _listening = false;
  bool _disposed = false;

  /// project → log folder, in the order they became worth looking at.
  final LinkedHashMap<String, String> _wanted = LinkedHashMap();

  /// project → the history a log needs before it is looked at again.
  final Map<String, int> _nextCheck = {};

  /// Works whose video could not be made in this launch.
  final Set<String> _failed = {};
  Timer? _timer;
  _Job? _job;
  Future<void>? _running;

  void _onPointer(PointerEvent event) => noteInput();

  bool _onKey(KeyEvent event) {
    noteInput();
    return false;
  }

  /// Something was done (drawn, undone, touched, typed): the drawing of
  /// video frames waits.
  void noteInput() => _lastInput = _clock.elapsedMicroseconds;

  Duration get _sinceInput =>
      Duration(microseconds: _clock.elapsedMicroseconds - _lastInput);

  bool get _appInFront {
    try {
      final state = WidgetsBinding.instance.lifecycleState;
      return state == null || state == AppLifecycleState.resumed;
    } catch (_) {
      return true;
    }
  }

  bool get _idle => _sinceInput >= idleDelay && _appInFront;

  /// The log of [projectId] in [dir] now keeps [historyBytes] of history.
  void noteHistory(String projectId, String dir, int historyBytes) {
    if (_disposed || _failed.contains(projectId)) return;
    _history[projectId] = historyBytes;
    if (historyBytes < triggerBytes) {
      _nextCheck.remove(projectId);
      return;
    }
    if (historyBytes < (_nextCheck[projectId] ?? 0)) return;
    _wanted[projectId] = dir;
    _schedule(Duration.zero);
  }

  /// project → the history its log was last told to keep.
  final Map<String, int> _history = {};

  void _schedule(Duration atLeast) {
    if (_disposed || _running != null || _wanted.isEmpty) return;
    _timer?.cancel();
    var wait = idleDelay - _sinceInput;
    if (wait < atLeast) wait = atLeast;
    _timer = Timer(wait, _onTimer);
  }

  void _onTimer() {
    _timer = null;
    if (_disposed || _running != null) return;
    if (!_idle) {
      _schedule(const Duration(seconds: 1));
      return;
    }
    var deferred = false;
    _running = _runWanted().then((value) => deferred = value).whenComplete(() {
      _running = null;
      // A work being played is looked at again a little later.
      _schedule(deferred ? const Duration(seconds: 5) : Duration.zero);
    });
  }

  /// Compacts the works wanted; whether some were left for later (their
  /// making is open).
  Future<bool> _runWanted() async {
    final later = <String, String>{};
    while (!_disposed && _wanted.isNotEmpty) {
      final MapEntry(key: projectId, value: dir) = _wanted.entries.first;
      _wanted.remove(projectId);
      if (MakingPlayer.isOpen(projectId)) {
        later[projectId] = dir;
        continue;
      }
      try {
        final compacted = await compactNow(projectId, dir, waitForIdle: true);
        if (!compacted && !_failed.contains(projectId)) {
          // Not worth it now: looked at again after more history.
          _nextCheck[projectId] = (_history[projectId] ?? 0) + recheckBytes;
        }
      } catch (error, stackTrace) {
        AppErrorReporter.record(error, stackTrace);
        _failed.add(projectId);
      }
    }
    if (_disposed) return false;
    _wanted.addAll(later);
    return later.isNotEmpty;
  }

  /// Turns the steps of [projectId]'s log in [dir] that are worth it into
  /// video now (while idle when [waitForIdle]). Returns whether the log was
  /// compacted.
  Future<bool> compactNow(
    String projectId,
    String dir, {
    bool waitForIdle = false,
    int? frameBytes,
  }) async {
    if (_disposed || !isWorkActive(projectId)) return false;
    final previous = _job;
    if (previous != null) await previous.done.future;
    final job = _job = _Job(projectId);
    try {
      return await _compact(job, dir, waitForIdle, frameBytes);
    } finally {
      if (identical(_job, job)) _job = null;
      job.done.complete();
    }
  }

  /// Waits until nothing is being done (or the work is cancelled).
  Future<bool> _waitIdle(_Job job, bool waitForIdle) async {
    while (waitForIdle && !job.cancelled && !_disposed && !_idle) {
      final wait = idleDelay - _sinceInput;
      await Future<void>.delayed(
        wait > Duration.zero ? wait : const Duration(seconds: 2),
      );
    }
    return !job.cancelled && !_disposed && isWorkActive(job.projectId);
  }

  Future<bool> _compact(
    _Job job,
    String dir,
    bool waitForIdle,
    int? frameBytes,
  ) async {
    final plan = await MakingLogWriter.plan(dir, frameBytes: frameBytes);
    if (plan == null) return false;
    if (!await _waitIdle(job, waitForIdle)) return false;
    final log = await Isolate.run(() => MakingLogData.read(dir));
    if (log.steps.length < plan.steps) return false;
    final renderer = MakingLogRenderer(log, '$dir/${MakingLog.blobsFile}')
      ..open();
    final frames = MakingLogFrames(renderer, plan.width, plan.height);
    final work = await Directory(
      '${(await getTemporaryDirectory()).path}/niarim_making_compact_'
      '${DateTime.now().microsecondsSinceEpoch}',
    ).create(recursive: true);
    final segments = <MakingSegmentFile>[];
    try {
      var i = 0;
      try {
        while (i < plan.steps) {
          final paths = <String>[];
          var bytes = 0;
          while (i < plan.steps &&
              paths.length < chunkFrames &&
              bytes < MakingExport.maxChunkBytes) {
            if (!await _waitIdle(job, waitForIdle)) return false;
            final written = await frames.writeFrames(
              work,
              i,
              i + 1,
              width: plan.width,
              height: plan.height,
            );
            for (final path in written) {
              bytes += await File(path).length();
            }
            paths.addAll(written);
            i++;
          }
          if (!await _waitIdle(job, waitForIdle)) return false;
          final segment = '${work.path}/seg_${segments.length}.mp4';
          await _video.encodeMp4(
            framePaths: paths,
            fps: MakingLog.fps,
            width: plan.width,
            height: plan.height,
            outputPath: segment,
          );
          if (!await _verify(segment, paths, plan.width, plan.height, work)) {
            throw StateError(
              'The making video made from ${paths.length} steps did not '
              'show them.',
            );
          }
          for (final path in paths) {
            await File(path).delete();
          }
          segments.add(
            MakingSegmentFile(
              path: segment,
              frames: paths.length,
              width: plan.width,
              height: plan.height,
            ),
          );
        }
      } catch (error, stackTrace) {
        // The device cannot make the video: the log keeps the steps (the
        // parts already made are still put in place).
        if (job.cancelled || _disposed) return false;
        AppErrorReporter.record(error, stackTrace);
        _failed.add(job.projectId);
      }
      if (segments.isEmpty) return false;
      // Not put in place while the making is being played or exported.
      while (MakingPlayer.isOpen(job.projectId)) {
        if (!await _waitIdle(job, false)) return false;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      if (job.cancelled || _disposed || !isWorkActive(job.projectId)) {
        return false;
      }
      final result = await MakingLogWriter.compact(
        dir,
        token: plan.token,
        segments: segments,
      );
      StorageInfoService().invalidate();
      if (result.done) {
        _nextCheck.remove(job.projectId);
        onCompacted?.call(job.projectId);
      }
      return result.done;
    } finally {
      renderer.dispose();
      try {
        await work.delete(recursive: true);
      } on FileSystemException {
        // A leftover temporary folder is removed with the cache.
      }
    }
  }

  /// Whether the MP4 at [path] has a frame for each of [framePaths] at
  /// [width]×[height], and its last frame shows the last picture.
  Future<bool> _verify(
    String path,
    List<String> framePaths,
    int width,
    int height,
    Directory work,
  ) async {
    final decoder = _video.decoder(work);
    final timeline = await decoder.probe(path);
    if (timeline.frameCount != framePaths.length) return false;
    if (timeline.displayWidth != null &&
        (timeline.displayWidth != width || timeline.displayHeight != height)) {
      return false;
    }
    final decoded = await decoder.decode(
      path: path,
      timeline: timeline,
      frameIndex: timeline.frameCount - 1,
      width: width,
      height: height,
    );
    final picture = await makingDecodeFile(framePaths.last);
    try {
      final data = await picture.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      if (data == null) return false;
      return MakingVideo.looksLike(
        decoded.rgba,
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        width,
        height,
      );
    } finally {
      picture.dispose();
    }
  }

  /// Stops turning [projectId]'s log into video (its history is about to be
  /// deleted) and waits until it has stopped.
  Future<void> cancel(String projectId) async {
    _wanted.remove(projectId);
    _nextCheck.remove(projectId);
    final job = _job;
    if (job != null && job.projectId == projectId) {
      job.cancelled = true;
      await job.done.future;
    }
  }

  /// Completes when nothing is being turned into video.
  Future<void> get settled async {
    final job = _job;
    if (job != null) await job.done.future;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _wanted.clear();
    _job?.cancelled = true;
    if (_listening) {
      try {
        GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
        HardwareKeyboard.instance.removeHandler(_onKey);
      } catch (_) {}
    }
  }
}

class _Job {
  _Job(this.projectId);

  final String projectId;
  bool cancelled = false;
  final Completer<void> done = Completer<void>();
}
