import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
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
      if (_dedupeIds()) await _persist();
    }
  }

  /// プリセットID・パーツID（プリセット内）の重複を検出し、2件目以降を
  /// 新しいIDへ差し替えて自己修復する（ユーザー報告により発覚：過去に
  /// 同一ミリ秒での連続タップ等でID採番（'p_${DateTime.now().
  /// millisecondsSinceEpoch}'）が衝突すると、パーツ一覧の
  /// ReorderableListViewが`part.id`をキーに使っているため
  /// 「Duplicate GlobalKeys detected」の例外でパーツ一覧が完全に壊れる。
  /// 一度保存されてしまった重複IDは再起動しても直らないため、起動時に
  /// 検出して修復する）。戻り値は修復が発生したかどうか（trueなら
  /// 呼び出し元で再永続化が必要）。
  bool _dedupeIds() {
    var changed = false;
    final seenPresetIds = <String>{};
    for (int i = 0; i < _presets.length; i++) {
      var preset = _presets[i];
      if (!seenPresetIds.add(preset.id)) {
        preset = preset.copyWith(id: 'p_${DateTime.now().microsecondsSinceEpoch}_$i');
        changed = true;
      }
      final seenPartIds = <String>{};
      final parts = <AutofillPart>[];
      var partsChanged = false;
      for (int j = 0; j < preset.parts.length; j++) {
        var part = preset.parts[j];
        if (!seenPartIds.add(part.id)) {
          part = part.copyWith(id: 'part_${DateTime.now().microsecondsSinceEpoch}_${i}_$j');
          partsChanged = true;
        }
        parts.add(part);
      }
      if (partsChanged) {
        preset = preset.copyWith(parts: parts);
        changed = true;
      }
      _presets[i] = preset;
    }
    return changed;
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

  Future<Directory> _thumbnailsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/niarim/autofill_thumbnails');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// [pngBytes]（1:1トリミング済みのPNG）をプリセットのサムネイル画像として
  /// 登録する（仕様書20：三点メニュー「サムネイル画像設定」）。アプリ専用
  /// 領域へ保存して永続化する。
  Future<void> setPresetThumbnailBytes(String presetId, Uint8List pngBytes) async {
    final idx = _presets.indexWhere((p) => p.id == presetId);
    if (idx < 0) return;
    final dir = await _thumbnailsDir();
    final fileName = '${presetId}_${DateTime.now().microsecondsSinceEpoch}.png';
    final destPath = '${dir.path}/$fileName';
    await File(destPath).writeAsBytes(pngBytes);
    // 旧サムネイルが存在すれば削除する
    final oldPath = _presets[idx].thumbnailPath;
    if (oldPath != null && oldPath != destPath) {
      final oldFile = File(oldPath);
      if (oldFile.existsSync()) {
        try { await oldFile.delete(); } catch (_) {}
      }
    }
    _presets[idx] = _presets[idx].copyWith(thumbnailPath: destPath);
    await _persist();
    notifyListeners();
  }

  Future<void> clearPresetThumbnail(String presetId) async {
    final idx = _presets.indexWhere((p) => p.id == presetId);
    if (idx < 0) return;
    final oldPath = _presets[idx].thumbnailPath;
    if (oldPath != null) {
      final oldFile = File(oldPath);
      if (oldFile.existsSync()) {
        try { await oldFile.delete(); } catch (_) {}
      }
    }
    _presets[idx] = _presets[idx].copyWith(thumbnailPath: null);
    await _persist();
    notifyListeners();
  }
}
