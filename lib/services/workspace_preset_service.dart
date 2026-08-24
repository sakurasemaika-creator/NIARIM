import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workspace_preset.dart';

/// ワークスペース（左利き設定・PC/DeXモード）を名前を付けて保存・読込・削除する
/// （仕様書08：ワークスペース保存・読込。例：アニメ用／線画用／背景用）。
class WorkspacePresetService extends ChangeNotifier {
  static const _prefsKey = 'workspace_presets';
  final List<WorkspacePreset> _presets = [];

  List<WorkspacePreset> get presets => List.unmodifiable(_presets);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? const [];
    _presets
      ..clear()
      ..addAll(
        raw.map(
          (s) =>
              WorkspacePreset.fromJson(jsonDecode(s) as Map<String, dynamic>),
        ),
      );
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKey,
      _presets.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }

  /// 現在の操作環境を[name]で保存する。同名の既存プリセットは上書きする。
  /// 表示ツール・並び順・ツール早替え登録内容も併せて保存する（仕様書08）。
  Future<void> save(
    String name, {
    required bool isLeftHanded,
    required bool? forcePcMode,
    List<String> toolbarOrder = const [],
    List<String> hiddenToolbarItems = const [],
    List<Map<String, dynamic>> quickToolEntries = const [],
    List<String> defaultDockedPanels = const [],
    double? desktopPanelWidth,
    double? desktopToolPanelWidth,
    List<String> toolOptionDockOrder = const [],
    List<String> rightDockOrder = const [],
  }) async {
    _presets.removeWhere((p) => p.name == name);
    _presets.add(
      WorkspacePreset(
        id: 'ws_${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        isLeftHanded: isLeftHanded,
        forcePcMode: forcePcMode,
        toolbarOrder: toolbarOrder,
        hiddenToolbarItems: hiddenToolbarItems,
        quickToolEntries: quickToolEntries,
        defaultDockedPanels: defaultDockedPanels,
        desktopPanelWidth: desktopPanelWidth,
        desktopToolPanelWidth: desktopToolPanelWidth,
        toolOptionDockOrder: toolOptionDockOrder,
        rightDockOrder: rightDockOrder,
      ),
    );
    await _persist();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    _presets.removeWhere((p) => p.id == id);
    await _persist();
    notifyListeners();
  }

  /// 保存済みワークスペースの名前だけを変更する（保存内容は変更しない）。
  Future<void> rename(String id, String newName) async {
    final idx = _presets.indexWhere((p) => p.id == id);
    if (idx < 0 || newName.trim().isEmpty) return;
    final p = _presets[idx];
    _presets[idx] = WorkspacePreset(
      id: p.id,
      name: newName.trim(),
      isLeftHanded: p.isLeftHanded,
      forcePcMode: p.forcePcMode,
      toolbarOrder: p.toolbarOrder,
      hiddenToolbarItems: p.hiddenToolbarItems,
      quickToolEntries: p.quickToolEntries,
      defaultDockedPanels: p.defaultDockedPanels,
      desktopPanelWidth: p.desktopPanelWidth,
      desktopToolPanelWidth: p.desktopToolPanelWidth,
      toolOptionDockOrder: p.toolOptionDockOrder,
      rightDockOrder: p.rightDockOrder,
    );
    await _persist();
    notifyListeners();
  }

  /// [id]のワークスペースを現在の設定で上書きする。[newName]を指定しない
  /// （null）場合は既存の名前をそのまま使う。IDは変えない。
  Future<void> overwrite(
    String id, {
    String? newName,
    required bool isLeftHanded,
    required bool? forcePcMode,
    List<String> toolbarOrder = const [],
    List<String> hiddenToolbarItems = const [],
    List<Map<String, dynamic>> quickToolEntries = const [],
    List<String> defaultDockedPanels = const [],
    double? desktopPanelWidth,
    double? desktopToolPanelWidth,
    List<String> toolOptionDockOrder = const [],
    List<String> rightDockOrder = const [],
  }) async {
    final idx = _presets.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    final current = _presets[idx];
    _presets[idx] = WorkspacePreset(
      id: current.id,
      name: (newName != null && newName.trim().isNotEmpty)
          ? newName.trim()
          : current.name,
      isLeftHanded: isLeftHanded,
      forcePcMode: forcePcMode,
      toolbarOrder: toolbarOrder,
      hiddenToolbarItems: hiddenToolbarItems,
      quickToolEntries: quickToolEntries,
      defaultDockedPanels: defaultDockedPanels,
      desktopPanelWidth: desktopPanelWidth,
      desktopToolPanelWidth: desktopToolPanelWidth,
      toolOptionDockOrder: toolOptionDockOrder,
      rightDockOrder: rightDockOrder,
    );
    await _persist();
    notifyListeners();
  }

  // ─── 共有（.niaworkspace、仕様書08）：バイナリ資産を持たない単純な
  // JSON設定のため、トーン・ブラシ等と異なりzip化はせずJSONそのまま
  // 書き出す。 ─────────────────────────────────────────────────────

  Future<File> exportPreset(String id) async {
    final preset = _presets.firstWhere((p) => p.id == id);
    final base = await getApplicationDocumentsDirectory();
    final safeName = preset.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File('${base.path}/$safeName.niaworkspace');
    await file.writeAsString(jsonEncode(preset.toJson()));
    return file;
  }

  Future<WorkspacePreset> importPresetFile(String filePath) async {
    final content = await File(filePath).readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;
    final imported = WorkspacePreset.fromJson(json);
    // IDは取り込み先で既存プリセットと衝突しないよう振り直す。
    final preset = WorkspacePreset(
      id: 'ws_${DateTime.now().microsecondsSinceEpoch}',
      name: imported.name,
      isLeftHanded: imported.isLeftHanded,
      forcePcMode: imported.forcePcMode,
      toolbarOrder: imported.toolbarOrder,
      hiddenToolbarItems: imported.hiddenToolbarItems,
      quickToolEntries: imported.quickToolEntries,
      defaultDockedPanels: imported.defaultDockedPanels,
      desktopPanelWidth: imported.desktopPanelWidth,
      desktopToolPanelWidth: imported.desktopToolPanelWidth,
      toolOptionDockOrder: imported.toolOptionDockOrder,
      rightDockOrder: imported.rightDockOrder,
    );
    _presets.add(preset);
    await _persist();
    notifyListeners();
    return preset;
  }
}
