import 'dart:convert';
import 'package:flutter/foundation.dart';
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
      ..addAll(raw.map((s) => WorkspacePreset.fromJson(jsonDecode(s) as Map<String, dynamic>)));
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _presets.map((p) => jsonEncode(p.toJson())).toList());
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
  }) async {
    _presets.removeWhere((p) => p.name == name);
    _presets.add(WorkspacePreset(
      id: 'ws_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      isLeftHanded: isLeftHanded,
      forcePcMode: forcePcMode,
      toolbarOrder: toolbarOrder,
      hiddenToolbarItems: hiddenToolbarItems,
      quickToolEntries: quickToolEntries,
    ));
    await _persist();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    _presets.removeWhere((p) => p.id == id);
    await _persist();
    notifyListeners();
  }
}
