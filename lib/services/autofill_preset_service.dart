import 'package:flutter/foundation.dart';
import '../models/autofill_preset.dart';

/// 自動塗りプリセットの管理サービス（仕様書04）。
/// プロジェクト保存とは独立してプリセットを保持する。
/// レイヤーパネルからのパーツ割り当てUIと、プリセット編集画面の双方から参照する。
class AutofillPresetService extends ChangeNotifier {
  final List<AutofillPreset> _presets = [
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

  List<AutofillPreset> get presets => List.unmodifiable(_presets);

  AutofillPart? findPart(String partId) {
    for (final preset in _presets) {
      for (final part in preset.parts) {
        if (part.id == partId) return part;
      }
    }
    return null;
  }

  void addPreset(AutofillPreset preset) {
    _presets.add(preset);
    notifyListeners();
  }

  void updatePreset(AutofillPreset updated) {
    final idx = _presets.indexWhere((p) => p.id == updated.id);
    if (idx >= 0) {
      _presets[idx] = updated;
      notifyListeners();
    }
  }

  void removePreset(String id) {
    _presets.removeWhere((p) => p.id == id);
    notifyListeners();
  }
}
