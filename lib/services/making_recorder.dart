import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../engine/making_log.dart';
import '../engine/making_video.dart';
import '../engine/niapro_serializer.dart';
import '../engine/tile_manager.dart';
import '../engine/undo_manager.dart';
import '../models/layer.dart';
import '../utils/app_error_reporter.dart';
import '../utils/making_strings.dart';
import 'making_compactor.dart';
import 'making_service.dart';
import 'project_service.dart';
import 'push_notification_service.dart';

/// Records the making of the works whose making is switched on.
///
/// Every change of the Undo history (an operation done, undone or redone)
/// becomes one step: the tiles it changed, copied as they are, and the layers
/// of the frame it shows on. Undone and redone operations are steps too, so
/// the making shows them. Nothing is drawn or encoded while drawing: the
/// copies go to [MakingLogWriter], which compresses and stores them in the
/// background. Pictures are made only when the making is played or exported.
///
/// The first time a frame's layer shows in a step (after the work is opened
/// or recording is switched on), the layer's tiles are compared with what the
/// log holds, so changes made while recording was off show up there. Tiles
/// unchanged since the work file was read are compared by the work file's
/// CRC-32 without being copied.
///
/// When a log keeps a lot of history, its oldest steps are turned into video
/// while the app is idle ([MakingCompactor]): recording never stops for it.
class MakingRecorder {
  MakingRecorder(
    this._projects,
    this._history, {
    MakingVideoTools? videoTools,
    Duration idleDelay = const Duration(seconds: 4),
  }) {
    compactor = MakingCompactor(
      isWorkActive: (id) => _projects.projects.any((p) => p.id == id),
      onCompacted: (id) => _works[id]?.limitReached = false,
      idleDelay: idleDelay,
      tools: videoTools,
    );
    _history.addListener(_onHistoryChanged);
    _projects.addListener(_onProjectsChanged);
    current = this;
  }

  /// Turns the oldest steps of the logs into video in idle time.
  late final MakingCompactor compactor;

  /// The recorder of the running app (the making history is deleted through
  /// it).
  static MakingRecorder? current;

  final ProjectService _projects;
  final UndoManager _history;
  final Map<String, _Work> _works = {};
  final Map<String, bool> _recording = {};
  Future<void> _queue = Future.value();
  bool _scheduled = false;

  void _onProjectsChanged() {
    for (final project in _projects.projects) {
      final was = _recording[project.id];
      // Switched back on: look again at every layer (it may have changed
      // while off).
      if (project.makingEnabled && was == false) {
        _works[project.id]?.verified.clear();
      }
      _recording[project.id] = project.makingEnabled;
    }
  }

  void _onHistoryChanged() {
    compactor.noteInput();
    if (_scheduled) return;
    _scheduled = true;
    // Several changes in one go (a grouped operation) make one step.
    scheduleMicrotask(_capture);
  }

  void _capture() {
    _scheduled = false;
    final change = _history.lastChange;
    final projectId = change?.projectId;
    if (change == null || projectId == null) return;
    final project = _projects.projects
        .where((p) => p.id == projectId)
        .firstOrNull;
    if (project == null || !project.makingEnabled) return;
    final tiles = _projects.tileManagerOf(projectId);
    final work = _works.putIfAbsent(projectId, _Work.new);
    if (!identical(work.tiles, tiles) ||
        work.generation != tiles.importGeneration) {
      work
        ..tiles = tiles
        ..generation = tiles.importGeneration
        ..verified.clear();
    }

    final shownOn = change.frame;
    final frames = <String, HistoryFrame>{};
    final changes = <String, List<MakingTileChange>>{};
    // Changes not shown on any frame yet wait for the next step.
    final unplaced = work.carried;
    for (final key in tiles.consumeMakingDirtyTiles()) {
      final split = key.lastIndexOf(':');
      if (split <= 0) continue;
      final layerKey = key.substring(0, split);
      final tileKey = key.substring(split + 1);
      final tileChange = MakingTileChange(
        layerKey,
        tileKey,
        tiles.layerTiles(layerKey)[tileKey],
      );
      final frame = _frameShowing(projectId, layerKey, shownOn);
      if (frame == null) {
        unplaced.add(tileChange);
        continue;
      }
      final frameKey = '${frame.sceneId}#${frame.frameIndex}';
      frames[frameKey] = frame;
      changes.putIfAbsent(frameKey, () => []).add(tileChange);
    }
    if (shownOn != null) {
      // The frame the operation was on comes last (the making ends where
      // the user was).
      final key = '${shownOn.sceneId}#${shownOn.frameIndex}';
      frames.remove(key);
      frames[key] = shownOn;
    }

    final steps = <_Step>[];
    for (final entry in frames.entries) {
      final frameChanges = [...?changes[entry.key]];
      final step = _stepFor(
        project.id,
        project.backgroundColor,
        tiles,
        work,
        frameChanges,
        entry.value,
      );
      if (step == null) {
        unplaced.addAll(frameChanges);
      } else {
        steps.add(step);
      }
    }
    if (steps.isEmpty) return; // the changes wait for the next step
    steps.first.changes.addAll(unplaced);
    work.carried = [];
    final time = DateTime.now().millisecondsSinceEpoch;
    _queue = _queue.then((_) => _send(projectId, work, time, steps)).catchError(
      (Object error, StackTrace stack) {
        AppErrorReporter.record(error, stack);
      },
    );
  }

  /// The frame a change of [layerKey]'s tiles is shown on: its own frame, or
  /// for a layer shown over several frames (a common layer, whose tiles are
  /// kept under the frame it was made on) the frame the operation was on.
  HistoryFrame? _frameShowing(
    String projectId,
    String layerKey,
    HistoryFrame? shownOn,
  ) {
    final parts = parseFrameLayerKey(layerKey);
    if (parts == null) return shownOn;
    final own = (sceneId: parts.sceneId, frameIndex: parts.frameIndex);
    if (shownOn == null) return own;
    final layer = _projects
        .storedLayersOf(projectId, parts.sceneId, parts.frameIndex)
        .where((l) => l.id == parts.layerId)
        .firstOrNull;
    return layer != null && isRangeLayerType(layer.type) ? shownOn : own;
  }

  _Step? _stepFor(
    String projectId,
    int paper,
    TileManager tiles,
    _Work work,
    List<MakingTileChange> changes,
    HistoryFrame frame,
  ) {
    if (_projects.sceneOf(projectId, frame.sceneId) == null) return null;
    final stacked = _projects.stackedLayersOf(
      projectId,
      frame.sceneId,
      frame.frameIndex,
    );
    final keys = [
      for (final layer in stacked.layers)
        _projects.tileKeyFor(
          projectId,
          frame.sceneId,
          frame.frameIndex,
          layer.id,
        ),
    ];
    final structure = jsonEncode({
      'w': tiles.canvasWidth,
      'h': tiles.canvasHeight,
      'paper': paper,
      'layers': [
        for (final layer in stacked.layers) NiaproSerializer.layerToJson(layer),
      ],
      'keys': keys,
      'masks': [
        for (final group in stacked.maskGroups)
          {'ids': group.layerIds.toList(), 'mask': group.mask.toJson()},
      ],
    });
    final unverified = [
      for (final key in keys.toSet())
        if (work.verified.add(key)) key,
    ];
    return _Step(frame, structure, changes, unverified);
  }

  Future<void> _send(
    String projectId,
    _Work work,
    int time,
    List<_Step> steps,
  ) async {
    final dir = work.dir ??= await MakingService.logDirectory(projectId);
    await (work.opened ??= MakingLogWriter.open(dir).then((opened) {
      work.crcs.addAll(opened.crcs);
      work.limitReached = opened.limitReached;
      compactor.noteHistory(projectId, dir, opened.historyBytes);
    }));
    if (work.limitReached) return;
    final tiles = work.tiles!;
    for (final step in steps) {
      final changes = step.changes;
      final listed = {
        for (final change in changes) '${change.layerKey}:${change.tileKey}',
      };
      for (final layerKey in step.unverified) {
        final present = tiles.layerTiles(layerKey);
        for (final MapEntry(key: tileKey, value: pixels) in present.entries) {
          final id = '$layerKey:$tileKey';
          if (!listed.add(id)) continue;
          final stored = tiles.storedCrc(layerKey, tileKey);
          if (stored != null && work.crcs[id] == stored) continue;
          changes.add(MakingTileChange(layerKey, tileKey, pixels));
        }
        final prefix = '$layerKey:';
        for (final id in work.crcs.keys) {
          if (!id.startsWith(prefix) || !listed.add(id)) continue;
          changes.add(
            MakingTileChange(layerKey, id.substring(prefix.length), null),
          );
        }
      }
      final result = await MakingLogWriter.step(
        dir,
        time: time,
        sceneId: step.frame.sceneId,
        frameIndex: step.frame.frameIndex,
        structure: step.structure,
        tiles: changes,
      );
      for (final MapEntry(:key, :value) in result.crcs.entries) {
        if (value == null) {
          work.crcs.remove(key);
        } else {
          work.crcs[key] = value;
        }
      }
      compactor.noteHistory(projectId, dir, result.historyBytes);
      if (result.limitReached) {
        work.limitReached = true;
        _tellLimitReached();
        return;
      }
    }
  }

  bool _limitToldThisLaunch = false;

  void _tellLimitReached() {
    if (_limitToldThisLaunch) return;
    _limitToldThisLaunch = true;
    final messenger = PushNotificationService.scaffoldMessengerKey.currentState;
    final context = PushNotificationService.scaffoldMessengerKey.currentContext;
    if (messenger == null || context == null) return;
    messenger.showSnackBar(
      SnackBar(content: Text(MakingStrings.storageLimit(context))),
    );
  }

  /// Waits until every step taken so far is stored (and, once disposed,
  /// until nothing is being turned into video).
  Future<void> flush() async {
    // A step taken in this microtask turn is queued first.
    await Future<void>.microtask(() {});
    await _queue;
    await MakingLogWriter.flush();
    if (_disposed) await compactor.settled;
  }

  bool _disposed = false;

  /// Forgets [projectId]'s making (its history is about to be deleted). The
  /// steps already taken are stored first.
  Future<void> forget(String projectId) async {
    await compactor.cancel(projectId);
    await flush();
    final work = _works.remove(projectId);
    final dir = work?.dir ?? await MakingService.logDirectory(projectId);
    await MakingLogWriter.forget(dir);
    // Tiles changed before deleting are not recorded after it.
    if (work?.tiles case final tiles?) tiles.consumeMakingDirtyTiles();
  }

  void dispose() {
    _disposed = true;
    compactor.dispose();
    _history.removeListener(_onHistoryChanged);
    _projects.removeListener(_onProjectsChanged);
    if (identical(current, this)) current = null;
  }
}

class _Work {
  TileManager? tiles;
  int generation = -1;

  /// Layer keys compared with the log since the work was opened or recording
  /// was switched on.
  final Set<String> verified = {};

  /// tile (`layerKey:tileKey`) → CRC-32 the log holds for it.
  final Map<String, int> crcs = {};
  List<MakingTileChange> carried = [];
  String? dir;
  Future<void>? opened;
  bool limitReached = false;
}

class _Step {
  _Step(this.frame, this.structure, this.changes, this.unverified);

  final HistoryFrame frame;
  final String structure;
  final List<MakingTileChange> changes;
  final List<String> unverified;
}
