import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/autofill_preset.dart';

/// 自動塗りプリセットの管理サービス（仕様書04・20）。
/// プロジェクト保存とは独立してプリセットを保持し、SharedPreferencesへ
/// 永続化する（端末単位。プロジェクトファイルには含めない）。
/// レイヤーパネルからのパーツ割り当てUIと、プリセット編集画面の双方から参照する。
class AutofillPresetService extends ChangeNotifier {
  static const _prefsKey = 'autofill_presets';

  final List<AutofillPreset> _presets = [];

  List<AutofillPreset> get presets => List.unmodifiable(_presets);

  /// 初回起動時（保存データが存在しない場合）のみ使用するサンプルプリセット。
  static List<AutofillPreset> _defaultPresets() => [
        AutofillPreset(id: 'p1', name: '主人公', parts: [
          AutofillPart(id: 'p1_1', name: '髪', color: 0xFF4A3728),
          AutofillPart(id: 'p1_2', name: '肌', color: 0xFFFFD5B0),
          AutofillPart(id: 'p1_3', name: '瞳', color: 0xFF3A6EA5),
          AutofillPart(id: 'p1_4', name: '服', color: 0xFF2C5F8A),
        ]),
        AutofillPreset(id: 'p2', name: 'ヒロイン', parts: [
          AutofillPart(id: 'p2_1', name: '髪', color: 0xFFE8C4A0),
          AutofillPart(id: 'p2_2', name: '肌', color: 0xFFFFE0C8),
          AutofillPart(id: 'p2_3', name: '瞳', color: 0xFF8B4513),
          AutofillPart(id: 'p2_4', name: '服', color: 0xFFFF6B9D),
          AutofillPart(id: 'p2_5', name: 'リボン', color: 0xFFFF1493),
        ]),
      ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey);
    _presets.clear();
    if (raw == null) {
      // 初回起動：サンプルプリセットを投入して即座に永続化する
      _presets.addAll(_defaultPresets());
      await _persist();
    } else {
      _presets.addAll(
          raw.map((s) => AutofillPreset.fromJson(jsonDecode(s) as Map<String, dynamic>)));
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _prefsKey, _presets.map((p) => jsonEncode(p.toJson())).toList());
  }

  AutofillPart? findPart(String partId) {
    for (final preset in _presets) {
      for (final part in preset.parts) {
        if (part.id == partId) return part;
      }
    }
    return null;
  }

  Future<void> addPreset(AutofillPreset preset) async {
    _presets.add(preset);
    await _persist();
    notifyListeners();
  }

  Future<void> updatePreset(AutofillPreset updated) async {
    final idx = _presets.indexWhere((p) => p.id == updated.id);
    if (idx >= 0) {
      _presets[idx] = updated;
      await _persist();
      notifyListeners();
    }
  }

  Future<void> removePreset(String id) async {
    _presets.removeWhere((p) => p.id == id);
    await _persist();
    notifyListeners();
  }
}
