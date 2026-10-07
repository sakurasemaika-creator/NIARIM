import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/custom_automation.dart';
import '../models/custom_automation_builtin_presets.dart';

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
  static const _favoritesPrefsKey = 'custom_automation_favorites_v1';
  // The official presets this device's list has been given, so one the user
  // deleted is not brought back and a newly shipped one is added once.
  static const _offeredBuiltinsKey = 'custom_automation_offered_builtins_v1';

  static const Set<String> _coalescibleCommands = {
    'canvas.brushSize',
    'canvas.brushOpacity',
    'canvas.color',
  };

  final List<CustomAutomation> _items = [];
  final Set<String> _favoriteIds = {};
  CustomAutomationDraft? _draft;
  bool _recording = false;
  CustomAutomationSurface? _recordingSurface;
  bool _favoritesOnly = false;

  List<CustomAutomation> get items => List.unmodifiable(_items);
  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);
  bool get favoritesOnly => _favoritesOnly;
  List<CustomAutomation> get visibleItems => List.unmodifiable(
    _favoritesOnly
        ? _items.where((item) => _favoriteIds.contains(item.id))
        : _items,
  );
  CustomAutomationDraft? get draft => _draft;
  bool get isRecording => _recording;
  CustomAutomationSurface? get recordingSurface => _recordingSurface;

  bool isFavorite(String id) => _favoriteIds.contains(id);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey);

    _items.clear();
    if (raw == null) {
      _items.addAll(CustomAutomationBuiltinPresets.all());
      await prefs.setStringList(
        _offeredBuiltinsKey,
        _items.map((item) => item.id).toList(),
      );
      await _persist();
    } else {
      _items.addAll(
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
      if (await _refreshBuiltins(prefs)) await _persist();
    }
    _favoriteIds
      ..clear()
      ..addAll(prefs.getStringList(_favoritesPrefsKey) ?? const <String>[]);
    _favoriteIds.removeWhere((id) => _items.every((item) => item.id != id));
    await _persistFavorites();
    notifyListeners();
  }

  /// Brings the official presets in a saved list up to date: a copy the
  /// user has not edited (still dated as shipped) is replaced by the current
  /// recipe, or dropped when it is no longer shipped (the aurora hologram);
  /// an official preset this list has never been given is added once. Edited
  /// copies and the user's own automations stay as they are. Returns whether
  /// the list changed.
  Future<bool> _refreshBuiltins(SharedPreferences prefs) async {
    final shipped = {
      for (final preset in CustomAutomationBuiltinPresets.all())
        preset.id: preset,
    };
    var changed = false;
    for (var i = _items.length - 1; i >= 0; i--) {
      final item = _items[i];
      final unedited =
          item.id.startsWith('builtin_') &&
          item.updatedAt.millisecondsSinceEpoch == 0;
      if (!unedited) continue;
      final latest = shipped[item.id];
      if (latest == null) {
        _items.removeAt(i);
        changed = true;
      } else if (jsonEncode(latest.toJson()) != jsonEncode(item.toJson())) {
        _items[i] = latest;
        changed = true;
      }
    }
    // A list saved before this record was kept had every preset shipped so
    // far offered to it.
    final offered =
        prefs.getStringList(_offeredBuiltinsKey)?.toSet() ??
        shipped.keys.toSet();
    for (final preset in shipped.values) {
      if (offered.contains(preset.id)) continue;
      if (_items.every((item) => item.id != preset.id)) {
        _items.add(preset);
        changed = true;
      }
    }
    await prefs.setStringList(
      _offeredBuiltinsKey,
      {...offered, ...shipped.keys}.toList(),
    );
    return changed;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKey,
      _items.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  Future<void> _persistFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesPrefsKey, _favoriteIds.toList());
  }

  Future<void> toggleFavorite(String id) async {
    if (_items.every((item) => item.id != id)) return;
    if (!_favoriteIds.add(id)) {
      _favoriteIds.remove(id);
    }
    await _persistFavorites();
    notifyListeners();
  }

  void setFavoritesOnly(bool value) {
    if (_favoritesOnly == value) return;
    _favoritesOnly = value;
    notifyListeners();
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

    if (!changesFrame &&
        _coalescibleCommands.contains(command) &&
        draft.steps.isNotEmpty) {
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
    _favoriteIds.remove(id);
    await _persist();
    await _persistFavorites();
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
