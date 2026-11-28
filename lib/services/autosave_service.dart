import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/niapro_serializer.dart';
import '../engine/tile_manager.dart';
import '../engine/undo_manager.dart';
import 'project_service.dart';
import '../utils/tolerant_preferences.dart';

/// 自動保存（作業の再開・クラッシュやファイル破損からの復旧用）。
/// 最大3件固定・古い順に自動削除。手動保存（セーブスロット・セーブツリー）とは完全に独立。
/// 描画などで変更が発生したタイミング（Undo更新と連動）で自動保存する。
///
/// 作品ファイルは線を描くたびには書かない（キャンバス・タイムラインを離れる・
/// アプリが裏へ回る・レイヤーやコマを足す等の時と手動の保存）。その間の線は
/// この自動保存だけが持つので、描くのを止めて[_debounceAfterChange]後に書き、
/// 休まずに描き続けていても[_longestUnsaved]を過ぎたら次の線を描き終えた所で書く
/// （以前は休まず描くと[_interval]の3分ごとにしか書かず、その間に落ちると
/// 3分ぶんの線が残らなかった）。
class AutosaveService extends ChangeNotifier {
  static const int maxSlots = 3;
  static const Duration _interval = Duration(minutes: 3);
  static const Duration _debounceAfterChange = Duration(seconds: 5);
  static const Duration _longestUnsaved = Duration(seconds: 30);

  final List<AutosaveSlot> _slots = [];
  int _nextSlotIndex = 0;
  Future<void>? _pendingSave;
  bool _disposed = false;
  Timer? _timer;
  Timer? _debounce;
  // 書いていない変更が最初に出てから[_longestUnsaved]で切れる。切れた後は、
  // 次の変更（線を描き終えた所。ペンが離れている）ですぐに書く。
  Timer? _unsavedCeiling;
  bool _saveDue = false;
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
    _clearUnsaved();
    _undoManager?.removeListener(_onProjectChanged);
    _undoManager = null;
    _currentProjectId = null;
  }

  /// Undo更新（描画・レイヤー操作等）と連動した自動保存（デバウンス）。
  void _onProjectChanged() {
    _debounce?.cancel();
    if (_saveDue) {
      _debounce = null;
      unawaited(_autoSave());
      return;
    }
    _debounce = Timer(_debounceAfterChange, _autoSave);
    _unsavedCeiling ??= Timer(_longestUnsaved, () => _saveDue = true);
  }

  void _clearUnsaved() {
    _unsavedCeiling?.cancel();
    _unsavedCeiling = null;
    _saveDue = false;
  }

  /// Tests: how many times an automatic save was started by the timers.
  @visibleForTesting
  int debugAutoSaveStarts = 0;

  Future<void> _autoSave() async {
    _clearUnsaved();
    debugAutoSaveStarts++;
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

  /// The automatic save this session wrote last for each work, with the
  /// tiles and content it holds: the next one copies the unchanged tiles from
  /// it instead of compressing every tile again.
  final Map<String, ({AutosaveSlot slot, TileManager tiles, String content})>
  _writtenThisLaunch = {};

  Future<void> _writeSlot(
    String projectId,
    ProjectService projectService,
    bool skipUnchanged,
  ) async {
    if (_disposed) return;
    // A work whose picture could not be read would be saved empty and push
    // the last good automatic saves out.
    if (projectService.tilesUnreadable(projectId)) return;
    final project = projectService.projects
        .where((p) => p.id == projectId)
        .firstOrNull;
    if (project == null) return;
    final scenes = projectService.scenesOf(projectId);
    final tileManager = projectService.tileManagerOf(projectId);
    final content = NiaproSerializer.contentSignature(project, scenes);
    final last = _writtenThisLaunch[projectId];
    // This session's last automatic save of the work, still in its slot and
    // made from the same tiles.
    final follows =
        last != null &&
        identical(last.tiles, tileManager) &&
        _slots.contains(last.slot);
    final fromWorkFile =
        !follows && projectService.workFileMatchesUnchangedTiles(projectId);

    final slotIndex = _nextSlotIndex % maxSlots;
    try {
      if (!skipUnchanged) {
        // Asked for explicitly: every tile is written as it is now.
        await NiaproSerializer.saveAutosave(
          project: project,
          scenes: scenes,
          tileManager: tileManager,
          slotIndex: slotIndex,
        );
      } else {
        // Nothing changed since the last automatic save, or since the work
        // file was saved: the work is already kept.
        if (follows) {
          if (!tileManager.hasAutosaveDirtyTiles && last.content == content) {
            return;
          }
        } else if (fromWorkFile &&
            !tileManager.hasDirtyTiles &&
            await NiaproSerializer.workFileContentSignature(projectId) ==
                content) {
          return;
        }
        if (_disposed) return;
        await NiaproSerializer.saveAutosaveFrom(
          project: project,
          scenes: scenes,
          tileManager: tileManager,
          slotIndex: slotIndex,
          base: follows
              ? AutosaveBase.slot(last.slot.slotIndex)
              : fromWorkFile
              ? AutosaveBase.workFile
              : null,
        );
      }
    } catch (_) {
      return; // 保存失敗はサイレントに無視（自動保存は補助機能のため）
    }
    _nextSlotIndex++;
    _slots.removeWhere((s) => s.slotIndex == slotIndex);
    final written = AutosaveSlot(
      projectId: projectId,
      savedAt: DateTime.now(),
      slotIndex: slotIndex,
    );
    _slots.add(written);
    while (_slots.length > maxSlots) {
      _slots.removeAt(0);
    }
    _writtenThisLaunch[projectId] = (
      slot: written,
      tiles: tileManager,
      content: content,
    );
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

  /// The newest autosave of [projectId] and its time when it is newer than
  /// the work file and holds different content (the app was closed before the
  /// work file caught up, e.g. it was forced to quit). Looked for once per
  /// launch; null when there is none.
  ///
  /// Only a snapshot saved after the work file counts: an autosave older than
  /// the file (the last strokes were saved to the file but not yet to an
  /// autosave) would take the work back, not forward.
  Future<({NiaproData data, DateTime savedAt})?> newerThanWorkFile(
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
    return NiaproSerializer.sameContent(current, backup)
        ? null
        : (data: backup, savedAt: slot.savedAt);
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
    _unsavedCeiling?.cancel();
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
