import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/niapro_serializer.dart';
import '../engine/undo_manager.dart';
import 'project_service.dart';
import '../utils/tolerant_preferences.dart';

/// 自動保存（作業の再開・クラッシュやファイル破損からの復旧用）。
/// 最大3件固定・古い順に自動削除。手動保存（セーブスロット・セーブツリー）とは完全に独立。
/// 描画などで変更が発生したタイミング（Undo更新と連動）で自動保存する。
class AutosaveService extends ChangeNotifier {
  static const int maxSlots = 3;
  static const Duration _interval = Duration(minutes: 3);
  static const Duration _debounceAfterChange = Duration(seconds: 5);

  final List<AutosaveSlot> _slots = [];
  int _nextSlotIndex = 0;
  Future<void>? _pendingSave;
  bool _disposed = false;
  Timer? _timer;
  Timer? _debounce;
  ProjectService? _projectService;
  UndoManager? _undoManager;
  String? _currentProjectId;
  List<AutosaveSlot> get slots => List.unmodifiable(_slots);

  /// Most recently written first, even if the device clock moved backwards.
  Iterable<AutosaveSlot> slotsForProject(String projectId) =>
      _slots.reversed.where((slot) => slot.projectId == projectId);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    // 保存する件数は[maxSlots]までなので、それより大きい値は壊れた保存。
    // そのまま回すと、とても大きな数では起動が終わらない。
    final count = (prefs.readInt('autosave_count') ?? 0).clamp(0, maxSlots);
    for (int i = 0; i < count; i++) {
      final projectId = prefs.readString('autosave_${i}_project');
      final savedAtMs = prefs.readInt('autosave_${i}_savedAt');
      final slotIndex = prefs.readInt('autosave_${i}_slot');
      if (projectId == null ||
          savedAtMs == null ||
          slotIndex == null ||
          slotIndex < 0 ||
          slotIndex >= maxSlots) {
        continue;
      }
      // 日時として読めない1件は使わない（1件で起動を止めない）。
      final savedAt = dateTimeFromSavedMillis(
        'autosave_${i}_savedAt',
        savedAtMs,
      );
      if (savedAt == null) continue;
      final slot = AutosaveSlot(
        projectId: projectId,
        savedAt: savedAt,
        slotIndex: slotIndex,
      );
      _slots.add(slot);
      _fromEarlierLaunch.add(slot);
    }
    _nextSlotIndex = prefs.readInt('autosave_next_slot') ?? 0;
    notifyListeners();
  }

  /// プロジェクトを開いた際に呼び出す。定期保存タイマーとUndo更新連動を開始する。
  void attach(
    ProjectService projectService,
    String projectId, {
    UndoManager? undoManager,
  }) {
    _projectService = projectService;
    _currentProjectId = projectId;
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _autoSave());
    _undoManager?.removeListener(_onProjectChanged);
    _undoManager = undoManager;
    _undoManager?.addListener(_onProjectChanged);
  }

  /// プロジェクトを離れた際に呼び出す。
  void detach() {
    _timer?.cancel();
    _timer = null;
    _debounce?.cancel();
    _debounce = null;
    _undoManager?.removeListener(_onProjectChanged);
    _undoManager = null;
    _currentProjectId = null;
  }

  /// Undo更新（描画・レイヤー操作等）と連動した自動保存（デバウンス）。
  void _onProjectChanged() {
    _debounce?.cancel();
    _debounce = Timer(_debounceAfterChange, _autoSave);
  }

  Future<void> _autoSave() async {
    final id = _currentProjectId;
    final ps = _projectService;
    if (id == null || ps == null) return;
    await save(id, ps, skipUnchanged: true);
  }

  /// 指定プロジェクトを自動保存スロットへ書き出す（3件固定・古い順に上書き）。
  Future<void> save(
    String projectId,
    ProjectService projectService, {
    bool skipUnchanged = false,
  }) {
    final previous = _pendingSave;
    Future<void> write() =>
        _writeSlot(projectId, projectService, skipUnchanged);
    final save = previous == null ? write() : previous.then((_) => write());
    final settled = save.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _pendingSave = settled;
    return save.whenComplete(() {
      if (identical(_pendingSave, settled)) _pendingSave = null;
    });
  }

  Future<void> _writeSlot(
    String projectId,
    ProjectService projectService,
    bool skipUnchanged,
  ) async {
    if (_disposed) return;
    final lastSlot = skipUnchanged
        ? slotsForProject(projectId).firstOrNull
        : null;
    final previous = lastSlot == null ? null : await _loadSlot(lastSlot);
    final project = projectService.projects
        .where((p) => p.id == projectId)
        .firstOrNull;
    if (project == null) return;
    final scenes = projectService.scenesOf(projectId);
    final tileManager = projectService.tileManagerOf(projectId);
    if (previous != null &&
        NiaproSerializer.sameContent(
          previous,
          NiaproData(
            project: project,
            scenes: scenes,
            tileData: tileManager.exportAll(),
          ),
        )) {
      return;
    }

    final slotIndex = _nextSlotIndex % maxSlots;
    try {
      await NiaproSerializer.saveAutosave(
        project: project,
        scenes: scenes,
        tileManager: tileManager,
        slotIndex: slotIndex,
      );
    } catch (_) {
      return; // 保存失敗はサイレントに無視（自動保存は補助機能のため）
    }
    _nextSlotIndex++;
    _slots.removeWhere((s) => s.slotIndex == slotIndex);
    _slots.add(
      AutosaveSlot(
        projectId: projectId,
        savedAt: DateTime.now(),
        slotIndex: slotIndex,
      ),
    );
    while (_slots.length > maxSlots) {
      _slots.removeAt(0);
    }
    await _persist();
    if (!_disposed) notifyListeners();
  }

  final Set<String> _offeredProjectIds = {};

  /// Snapshots read at start-up, i.e. written before this launch. Only these
  /// can hold work that never reached the work file (the app was closed
  /// first); a snapshot written during this launch is the session's own
  /// history (the work may have been undone since), not something to offer.
  final Set<AutosaveSlot> _fromEarlierLaunch = {};

  /// Tests: treat the snapshots written so far as left by an earlier launch
  /// (as if the app had been restarted and read them at start-up).
  @visibleForTesting
  void debugTreatSlotsAsFromEarlierLaunch() =>
      _fromEarlierLaunch.addAll(_slots);

  /// The newest autosave of [projectId] when it is newer than the work file
  /// and holds different content (the app was closed before the work file
  /// caught up, e.g. it was forced to quit). Offered once per launch; null
  /// when there is nothing to offer.
  ///
  /// Only a snapshot saved after the work file counts: an autosave older than
  /// the file (the last strokes were saved to the file but not yet to an
  /// autosave) would take the work back, not forward.
  Future<NiaproData?> newerThanWorkFile(
    ProjectService projectService,
    String projectId,
  ) async {
    if (!_offeredProjectIds.add(projectId)) return null;
    await _pendingSave;
    final slot = slotsForProject(projectId).firstOrNull;
    final project = projectService.projects
        .where((p) => p.id == projectId)
        .firstOrNull;
    if (slot == null || project == null) return null;
    if (!_fromEarlierLaunch.contains(slot)) return null;
    if (!slot.savedAt.isAfter(project.updatedAt)) return null;
    final backup = await _loadSlot(slot);
    if (backup == null) return null;
    final current = NiaproData(
      project: project,
      scenes: projectService.scenesOf(projectId),
      tileData: projectService.tileManagerOf(projectId).exportAll(),
    );
    return NiaproSerializer.sameContent(current, backup) ? null : backup;
  }

  /// Skip damaged snapshots and recover from the newest readable one.
  Future<({NiaproData data, DateTime savedAt})?> latestReadable(
    String projectId,
  ) async {
    await _pendingSave;
    for (final slot in slotsForProject(projectId).toList()) {
      final data = await readSlot(slot);
      if (data != null) return (data: data, savedAt: slot.savedAt);
    }
    return null;
  }

  /// Resolve the selected snapshot, even if its slot has since been reused.
  Future<NiaproData?> readSlot(AutosaveSlot slot) async {
    await _pendingSave;
    return _loadSlot(slot);
  }

  Future<NiaproData?> _loadSlot(AutosaveSlot slot) async {
    try {
      if (!_slots.contains(slot)) return null;
      final data = await NiaproSerializer.loadAutosave(
        slot.projectId,
        slot.slotIndex,
      );
      if (!_slots.contains(slot) ||
          data.project.id != slot.projectId ||
          !data.hasEditableFrames) {
        return null;
      }
      return data;
    } catch (_) {
      return null;
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('autosave_count', _slots.length);
    for (int i = 0; i < _slots.length; i++) {
      await prefs.setString('autosave_${i}_project', _slots[i].projectId);
      await prefs.setInt(
        'autosave_${i}_savedAt',
        _slots[i].savedAt.millisecondsSinceEpoch,
      );
      await prefs.setInt('autosave_${i}_slot', _slots[i].slotIndex);
    }
    await prefs.setInt('autosave_next_slot', _nextSlotIndex);
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _debounce?.cancel();
    _undoManager?.removeListener(_onProjectChanged);
    super.dispose();
  }
}

class AutosaveSlot {
  final String projectId;
  final DateTime savedAt;
  final int slotIndex;

  AutosaveSlot({
    required this.projectId,
    required this.savedAt,
    required this.slotIndex,
  });
}
