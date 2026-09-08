import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/custom_automation.dart';

class CustomAutomationDraft {
  final String id;
  String name;
  final DateTime createdAt;
  final int? recordingStartFrame;
  final List<CustomAutomationStep> steps;

  CustomAutomationDraft({
    required this.id,
    required this.name,
    required this.createdAt,
    this.recordingStartFrame,
    List<CustomAutomationStep>? steps,
  }) : steps = steps ?? [];
}

class CustomAutomationService extends ChangeNotifier {
  static const _prefsKey = 'custom_automations_v1';

  final List<CustomAutomation> _items = [];
  CustomAutomationDraft? _draft;
  bool _recording = false;
  CustomAutomationSurface? _recordingSurface;

  List<CustomAutomation> get items => List.unmodifiable(_items);
  CustomAutomationDraft? get draft => _draft;
  bool get isRecording => _recording;
  CustomAutomationSurface? get recordingSurface => _recordingSurface;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? const [];
    _items
      ..clear()
      ..addAll(
        raw.map((entry) {
          try {
            final decoded = jsonDecode(entry);
            if (decoded is! Map) return null;
            return CustomAutomation.fromJson(decoded.cast<String, Object?>());
          } catch (_) {
            return null;
          }
        }).whereType<CustomAutomation>(),
      );
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKey,
      _items.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  void beginDraft({
    required String name,
    required CustomAutomationSurface surface,
    int? recordingStartFrame,
  }) {
    final now = DateTime.now();
    _draft = CustomAutomationDraft(
      id: 'automation_${now.microsecondsSinceEpoch}',
      name: name.trim(),
      createdAt: now,
      recordingStartFrame: recordingStartFrame,
    );
    _recordingSurface = surface;
    _recording = true;
    notifyListeners();
  }

  void resumeRecording(CustomAutomationSurface surface) {
    if (_draft == null) return;
    _recordingSurface = surface;
    _recording = true;
    notifyListeners();
  }

  void stopRecording() {
    if (!_recording) return;
    _recording = false;
    notifyListeners();
  }

  void cancelDraft() {
    _draft = null;
    _recording = false;
    _recordingSurface = null;
    notifyListeners();
  }

  void recordStep({
    required CustomAutomationSurface surface,
    required String command,
    required String label,
    Map<String, Object?> args = const {},
    bool changesFrame = false,
    int? recordedFrame,
  }) {
    final draft = _draft;
    if (!_recording || draft == null) return;
    final step = CustomAutomationStep(
      id: '${draft.id}_step_${draft.steps.length + 1}',
      surface: surface,
      command: command,
      label: label,
      args: Map.unmodifiable(args),
      changesFrame: changesFrame,
      recordedFrame: recordedFrame,
    );

    // Slider/color drags may emit many callbacks. Consecutive writes of the same
    // deterministic command in the same recorded frame are one logical operation,
    // so retain only the latest value. Frame navigation is never coalesced because
    // its sequence is semantically meaningful and also disables all-frame execution.
    if (!changesFrame && draft.steps.isNotEmpty) {
      final last = draft.steps.last;
      if (!last.changesFrame &&
          last.surface == surface &&
          last.command == command &&
          last.recordedFrame == recordedFrame) {
        draft.steps[draft.steps.length - 1] = CustomAutomationStep(
          id: last.id,
          surface: surface,
          command: command,
          label: label,
          args: Map.unmodifiable(args),
          recordedFrame: recordedFrame,
        );
        notifyListeners();
        return;
      }
    }
    draft.steps.add(step);
    notifyListeners();
  }

  void reorderDraftStep(int oldIndex, int newIndex) {
    final draft = _draft;
    if (draft == null || oldIndex < 0 || oldIndex >= draft.steps.length) return;
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    target = target.clamp(0, draft.steps.length - 1);
    final step = draft.steps.removeAt(oldIndex);
    draft.steps.insert(target, step);
    notifyListeners();
  }

  void removeDraftStep(int index) {
    final draft = _draft;
    if (draft == null || index < 0 || index >= draft.steps.length) return;
    draft.steps.removeAt(index);
    notifyListeners();
  }

  void renameDraft(String name) {
    final draft = _draft;
    if (draft == null) return;
    draft.name = name.trim();
    notifyListeners();
  }

  Future<CustomAutomation?> saveDraft() async {
    final draft = _draft;
    if (draft == null || draft.name.trim().isEmpty || draft.steps.isEmpty) {
      return null;
    }
    final now = DateTime.now();
    final item = CustomAutomation(
      id: draft.id,
      name: draft.name.trim(),
      steps: List.unmodifiable(draft.steps),
      recordingStartFrame: draft.recordingStartFrame,
      createdAt: draft.createdAt,
      updatedAt: now,
    );
    final existing = _items.indexWhere((entry) => entry.id == item.id);
    if (existing >= 0) {
      _items[existing] = item;
    } else {
      _items.add(item);
    }
    _draft = null;
    _recording = false;
    _recordingSurface = null;
    await _persist();
    notifyListeners();
    return item;
  }

  void editExisting(String id) {
    final item = _items.where((entry) => entry.id == id).firstOrNull;
    if (item == null) return;
    _draft = CustomAutomationDraft(
      id: item.id,
      name: item.name,
      createdAt: item.createdAt,
      recordingStartFrame: item.recordingStartFrame,
      steps: List.of(item.steps),
    );
    _recording = false;
    _recordingSurface = null;
    notifyListeners();
  }

  Future<void> rename(String id, String name) async {
    final index = _items.indexWhere((entry) => entry.id == id);
    if (index < 0 || name.trim().isEmpty) return;
    _items[index] = _items[index].copyWith(
      name: name.trim(),
      updatedAt: DateTime.now(),
    );
    await _persist();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    _items.removeWhere((entry) => entry.id == id);
    await _persist();
    notifyListeners();
  }

  String exportJson(String id) {
    final item = _items.where((entry) => entry.id == id).firstOrNull;
    if (item == null) {
      throw ArgumentError.value(id, 'id', 'Unknown automation');
    }
    return item.toJsonString();
  }

  Future<CustomAutomation> importJson(String raw, {bool keepId = false}) async {
    final parsed = CustomAutomation.fromJsonString(raw);
    if (parsed.name.trim().isEmpty || parsed.steps.isEmpty) {
      throw const FormatException(
        'Automation must have a name and at least one step',
      );
    }
    final now = DateTime.now();
    final id = keepId && _items.every((entry) => entry.id != parsed.id)
        ? parsed.id
        : 'automation_${now.microsecondsSinceEpoch}';
    final imported = CustomAutomation(
      id: id,
      name: parsed.name,
      steps: List.unmodifiable(parsed.steps),
      recordingStartFrame: parsed.recordingStartFrame,
      createdAt: now,
      updatedAt: now,
    );
    _items.add(imported);
    await _persist();
    notifyListeners();
    return imported;
  }
}
