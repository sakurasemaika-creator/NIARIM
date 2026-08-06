import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'project_service.dart';

class AutosaveService extends ChangeNotifier {
  static const int maxSlots = 3;
  static const Duration _interval = Duration(minutes: 3);

  final List<AutosaveSlot> _slots = [];
  int _nextSlotIndex = 0;
  Timer? _timer;
  ProjectService? _projectService;
  String? _currentProjectId;

  List<AutosaveSlot> get slots => List.unmodifiable(_slots);

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

  void attach(ProjectService projectService, String projectId) {
    _projectService = projectService;
    _currentProjectId = projectId;
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _autoSave());
  }

  void detach() {
    _timer?.cancel();
    _timer = null;
    _currentProjectId = null;
  }

  Future<void> _autoSave() async {
    final id = _currentProjectId;
    final ps = _projectService;
    if (id == null || ps == null) return;
    await save(id, ps);
  }

  Future<void> save(String projectId, ProjectService projectService) async {
    final slotIndex = _nextSlotIndex % maxSlots;
    _nextSlotIndex++;
    _slots.removeWhere((s) => s.slotIndex == slotIndex && s.projectId == projectId);
    _slots.add(AutosaveSlot(
      projectId: projectId,
      savedAt: DateTime.now(),
      slotIndex: slotIndex,
    ));
    await projectService.saveProject(projectId);
    await _persist();
    notifyListeners();
  }

  Future<void> restore(String projectId, int slotIndex) async {
    // 実際の復元はProjectServiceのload経由で行う（現状はスナップショット通知のみ）
    notifyListeners();
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
