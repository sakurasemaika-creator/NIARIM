import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/autofill_preset.dart';

/// 自動塗りプリセットの管理サービス。
/// プロジェクト保存とは独立してプリセットを保持し、SharedPreferencesへ
/// 永続化する（端末単位。プロジェクトファイルには含めない）。
/// レイヤーパネルからのパーツ割り当てUIと、プリセット編集画面の双方から参照する。
class AutofillPresetService extends ChangeNotifier {
  static const _prefsKey = 'autofill_presets';

  final List<AutofillPreset> _presets = [];

  List<AutofillPreset> get presets => List.unmodifiable(_presets);

  /// [base]のHSLを操作して陰影・ハイライト色を作る（アニメ塗りの定番手法：
  /// 影は明度を下げつつ彩度をやや上げる、ハイライトは明度を上げつつ彩度を
  /// 下げる）。サンプルプリセットの「1影・2影・ハイライト」を色相の近い
  /// 一貫した配色で機械的に生成するために使う。サンプルは使い方を学んで
  /// もらうためのものなので、すべてのパーツにきちんと陰影を用意する。
  static int _shade(
    int argb, {
    required double lightnessDelta,
    double saturationDelta = 0,
  }) {
    final a = (argb >> 24) & 0xFF;
    final r = ((argb >> 16) & 0xFF) / 255.0;
    final g = ((argb >> 8) & 0xFF) / 255.0;
    final b = (argb & 0xFF) / 255.0;
    final maxV = [r, g, b].reduce((x, y) => x > y ? x : y);
    final minV = [r, g, b].reduce((x, y) => x < y ? x : y);
    var l = (maxV + minV) / 2;
    double h = 0, s = 0;
    if (maxV != minV) {
      final d = maxV - minV;
      s = l > 0.5 ? d / (2 - maxV - minV) : d / (maxV + minV);
      if (maxV == r) {
        h = ((g - b) / d) % 6;
      } else if (maxV == g) {
        h = (b - r) / d + 2;
      } else {
        h = (r - g) / d + 4;
      }
      h *= 60;
      if (h < 0) h += 360;
    }
    l = (l + lightnessDelta).clamp(0.0, 1.0);
    s = (s + saturationDelta).clamp(0.0, 1.0);
    final c = (1 - (2 * l - 1).abs()) * s;
    final x = c * (1 - ((h / 60) % 2 - 1).abs());
    final m = l - c / 2;
    double rr, gg, bb;
    if (h < 60) {
      rr = c;
      gg = x;
      bb = 0;
    } else if (h < 120) {
      rr = x;
      gg = c;
      bb = 0;
    } else if (h < 180) {
      rr = 0;
      gg = c;
      bb = x;
    } else if (h < 240) {
      rr = 0;
      gg = x;
      bb = c;
    } else if (h < 300) {
      rr = x;
      gg = 0;
      bb = c;
    } else {
      rr = c;
      gg = 0;
      bb = x;
    }
    final nr = ((rr + m) * 255).round().clamp(0, 255);
    final ng = ((gg + m) * 255).round().clamp(0, 255);
    final nb = ((bb + m) * 255).round().clamp(0, 255);
    return (a << 24) | (nr << 16) | (ng << 8) | nb;
  }

  static int _shadow1(int base) =>
      _shade(base, lightnessDelta: -0.12, saturationDelta: 0.05);
  static int _shadow2(int base) =>
      _shade(base, lightnessDelta: -0.26, saturationDelta: 0.08);
  static int _highlight(int base) =>
      _shade(base, lightnessDelta: 0.20, saturationDelta: -0.15);

  /// 髪・肌・服の各パーツ用に、基本色＋1影＋2影＋ハイライトの4パーツを
  /// まとめて生成する（サンプルのすべてのパーツにこれらを用意する）。
  static List<AutofillPart> _shadedSet(
    String idPrefix,
    String name,
    int base,
  ) => [
    AutofillPart(id: '${idPrefix}_base', name: name, color: base),
    AutofillPart(
      id: '${idPrefix}_s1',
      name: '${name}1影',
      color: _shadow1(base),
    ),
    AutofillPart(
      id: '${idPrefix}_s2',
      name: '${name}2影',
      color: _shadow2(base),
    ),
    AutofillPart(
      id: '${idPrefix}_hl',
      name: '$nameハイライト',
      color: _highlight(base),
    ),
  ];

  /// 瞳（白目・瞳孔・虹彩本体・虹彩の影・キャッチライト）をまとめて生成する。
  /// 白目・瞳孔・キャッチライトは実際の作画でも陰影を付けずフラットに
  /// 塗ることが多いため単色のみ、虹彩本体のみ1影を用意する。瞳だけだと
  /// ざっくりしすぎるため、白目や瞳孔の色も別パーツとして持たせている。
  static List<AutofillPart> _eyeSet(String idPrefix, int irisBase) => [
    AutofillPart(id: '${idPrefix}_white', name: '白目', color: 0xFFFAFAF8),
    AutofillPart(id: '${idPrefix}_pupil', name: '瞳孔', color: 0xFF1A1410),
    AutofillPart(id: '${idPrefix}_iris', name: '瞳', color: irisBase),
    AutofillPart(
      id: '${idPrefix}_iris_s1',
      name: '瞳1影',
      color: _shadow1(irisBase),
    ),
    AutofillPart(
      id: '${idPrefix}_iris_hl',
      name: '瞳キャッチライト',
      color: 0xFFFFFFFF,
    ),
  ];

  /// 初回起動時（保存データが存在しない場合）のみ使用するサンプルプリセット。
  /// 各パーツへ1影・2影・ハイライトを用意し、瞳は白目・瞳孔・キャッチライト
  /// まで、服はトップス／ボトムス／シューズへ細分化した、実際の塗り方が
  /// 学べる内容にしている。
  static List<AutofillPreset> _defaultPresets() => [
    AutofillPreset(
      id: 'p1',
      name: '主人公',
      parts: [
        ..._shadedSet('p1_hair', '髪', 0xFF4A3728),
        ..._shadedSet('p1_skin', '肌', 0xFFFFD5B0),
        ..._eyeSet('p1_eye', 0xFF3A6EA5),
        ..._shadedSet('p1_top', 'トップス', 0xFF2C5F8A),
        ..._shadedSet('p1_bottom', 'ボトムス', 0xFF33302E),
        ..._shadedSet('p1_shoes', 'シューズ', 0xFF4A3020),
      ],
    ),
    AutofillPreset(
      id: 'p2',
      name: 'ヒロイン',
      parts: [
        ..._shadedSet('p2_hair', '髪', 0xFFE8C4A0),
        ..._shadedSet('p2_skin', '肌', 0xFFFFE0C8),
        ..._eyeSet('p2_eye', 0xFF8B4513),
        ..._shadedSet('p2_top', 'トップス', 0xFFFF6B9D),
        ..._shadedSet('p2_bottom', 'ボトムス', 0xFFFF8CB0),
        ..._shadedSet('p2_shoes', 'シューズ', 0xFFD94F7A),
        ..._shadedSet('p2_ribbon', 'リボン', 0xFFFF1493),
      ],
    ),
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
        raw.map(
          (s) => AutofillPreset.fromJson(jsonDecode(s) as Map<String, dynamic>),
        ),
      );
      var changed = _dedupeIds();
      if (_upgradeSampleContent()) changed = true;
      if (changed) await _persist();
    }
  }

  /// 既存ユーザーが持っているサンプルプリセット（id: 'p1'/'p2'）が、まだ
  /// 旧仕様（ベースカラーのみ・4〜5パーツ）のままの場合、新しい内容
  /// （1影・2影・ハイライト・瞳の細分化・服の細分化を含む）へ差し替える。
  /// パーツ数がそれより多い場合は既にユーザーが手を加えたとみなし触らない。
  bool _upgradeSampleContent() {
    var changed = false;
    final defaults = {for (final p in _defaultPresets()) p.id: p};
    for (int i = 0; i < _presets.length; i++) {
      final preset = _presets[i];
      final fresh = defaults[preset.id];
      if (fresh == null) continue;
      if (preset.parts.length <= 7 &&
          preset.parts.length < fresh.parts.length) {
        _presets[i] = preset.copyWith(parts: fresh.parts);
        changed = true;
      }
    }
    return changed;
  }

  /// プリセットID・パーツID（プリセット内）の重複を検出し、2件目以降を
  /// 新しいIDへ差し替えて自己修復する。過去に同一ミリ秒での連続タップ等で
  /// ID採番（'p_${DateTime.now().millisecondsSinceEpoch}'）が衝突すると、
  /// パーツ一覧のReorderableListViewが`part.id`をキーに使っているため
  /// 「Duplicate GlobalKeys detected」の例外でパーツ一覧が完全に壊れる。
  /// 一度保存されてしまった重複IDは再起動しても直らないため、起動時に
  /// 検出して修復する。戻り値は修復が発生したかどうか（trueなら
  /// 呼び出し元で再永続化が必要）。
  bool _dedupeIds() {
    var changed = false;
    final seenPresetIds = <String>{};
    for (int i = 0; i < _presets.length; i++) {
      var preset = _presets[i];
      if (!seenPresetIds.add(preset.id)) {
        preset = preset.copyWith(
          id: 'p_${DateTime.now().microsecondsSinceEpoch}_$i',
        );
        changed = true;
      }
      final seenPartIds = <String>{};
      final parts = <AutofillPart>[];
      var partsChanged = false;
      for (int j = 0; j < preset.parts.length; j++) {
        var part = preset.parts[j];
        if (!seenPartIds.add(part.id)) {
          part = part.copyWith(
            id: 'part_${DateTime.now().microsecondsSinceEpoch}_${i}_$j',
          );
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
      _prefsKey,
      _presets.map((p) => jsonEncode(p.toJson())).toList(),
    );
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
  /// 登録する。アプリ専用領域へ保存して永続化する。
  Future<void> setPresetThumbnailBytes(
    String presetId,
    Uint8List pngBytes,
  ) async {
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
        try {
          await oldFile.delete();
        } catch (_) {}
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
        try {
          await oldFile.delete();
        } catch (_) {}
      }
    }
    _presets[idx] = _presets[idx].copyWith(thumbnailPath: null);
    await _persist();
    notifyListeners();
  }
}
