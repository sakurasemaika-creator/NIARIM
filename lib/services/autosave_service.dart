import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../engine/niapro_serializer.dart';
import '../engine/undo_manager.dart';
import 'project_service.dart';

/// 自動保存（クラッシュ・ファイル破損時の復元専用）。
/// 最大3件固定・古い順に自動削除。手動保存（セーブスロット・セーブツリー）とは完全に独立。
/// 描画などで変更が発生したタイミング（Undo更新と連動）で自動保存する。
class AutosaveService extends ChangeNotifier {
  static const int maxSlots = 3;
  static const Duration _interval = Duration(minutes: 3);
  static const Duration _debounceAfterChange = Duration(seconds: 5);

  final List<AutosaveSlot> _slots = [];
  int _nextSlotIndex = 0;
  Timer? _timer;
  Timer? _debounce;
  ProjectService? _projectService;
  UndoManager? _undoManager;
  String? _currentProjectId;
  // クラッシュ復元確認ダイアログを、同一アプリセッション中に同じ
  // プロジェクトへ再度提示しないようにするための記録。CanvasScreenは
  // タイムラインモードとの往復（context.go）のたびに再生成されるため、
  // Widget側の状態だけで「一度確認済み」を覚えることができない。
  // AutosaveServiceはアプリ起動時に1つだけ生成されアプリ全体で共有される
  // ため、ここに記録することで「編集再開のたびに自動保存ダイアログが
  // 毎回出る」不具合を防ぐ。
  final Set<String> _promptedProjectIds = {};

  List<AutosaveSlot> get slots => List.unmodifiable(_slots);

  /// このアプリセッション中に既にクラッシュ復元確認を行ったプロジェクトか。
  bool hasPromptedThisSession(String projectId) => _promptedProjectIds.contains(projectId);

  /// クラッシュ復元確認を行った（結果に関わらず）ことを記録する。
  void markPrompted(String projectId) => _promptedProjectIds.add(projectId);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt('autosave_count') ?? 0;
    for (int i = 0; i < count; i++) {
      final projectId = prefs.getString('autosave_${i}_project');
      final savedAtMs = prefs.getInt('autosave_${i}_savedAt');
      final slotIndex = prefs.getInt('autosave_${i}_slot');
      if (projectId != null && savedAtMs != null && slotIndex != null) {
        _slots.add(AutosaveSlot(
          projectId: projectId,
          savedAt: DateTime.fromMillisecondsSinceEpoch(savedAtMs),
          slotIndex: slotIndex,
        ));
      }
    }
    _nextSlotIndex = prefs.getInt('autosave_next_slot') ?? 0;
    notifyListeners();
  }

  /// プロジェクトを開いた際に呼び出す。定期保存タイマーとUndo更新連動を開始する。
  void attach(ProjectService projectService, String projectId, {UndoManager? undoManager}) {
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
    await save(id, ps);
  }

  /// 指定プロジェクトを自動保存スロットへ書き出す（3件固定・古い順に上書き）。
  Future<void> save(String projectId, ProjectService projectService) async {
    final project = projectService.projects.where((p) => p.id == projectId).firstOrNull;
    if (project == null) return;
    final scenes = projectService.scenesOf(projectId);
    final tileManager = projectService.tileManagerOf(projectId);

    final slotIndex = _nextSlotIndex % maxSlots;
    _nextSlotIndex++;
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
    _slots.removeWhere((s) => s.slotIndex == slotIndex);
    _slots.add(AutosaveSlot(
      projectId: projectId,
      savedAt: DateTime.now(),
      slotIndex: slotIndex,
    ));
    while (_slots.length > maxSlots) {
      _slots.removeAt(0);
    }
    await _persist();
    notifyListeners();
  }

  /// 指定プロジェクト・最新の自動保存スロットを返す（クラッシュ復元候補の検出用）。
  AutosaveSlot? latestSlotFor(String projectId) {
    final matches = _slots.where((s) => s.projectId == projectId).toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return matches.isEmpty ? null : matches.first;
  }

  /// 自動保存データを読み込む（実際の反映はProjectService.restoreFromAutosave経由）。
  Future<NiaproData?> restore(String projectId, int slotIndex) async {
    try {
      return await NiaproSerializer.loadAutosave(projectId, slotIndex);
    } catch (_) {
      return null;
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('autosave_count', _slots.length);
    for (int i = 0; i < _slots.length; i++) {
      await prefs.setString('autosave_${i}_project', _slots[i].projectId);
      await prefs.setInt('autosave_${i}_savedAt', _slots[i].savedAt.millisecondsSinceEpoch);
      await prefs.setInt('autosave_${i}_slot', _slots[i].slotIndex);
    }
    await prefs.setInt('autosave_next_slot', _nextSlotIndex);
  }

  @override
  void dispose() {
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
