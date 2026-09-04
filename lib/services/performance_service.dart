import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PerformanceService extends ChangeNotifier {
  QualityLevel _qualityLevel = QualityLevel.medium;
  QualityLevel get qualityLevel => _qualityLevel;

  // カスタム品質設定
  bool _customTiltEnabled = false;
  bool _customShowPrev = true;
  bool _customShowNext = true;
  int _customOnionSkinPrev = 3;
  int _customOnionSkinNext = 3;
  SaveMode _customSaveMode = SaveMode.slot;
  int _customSlotCount = 10;

  // 初回起動時に自動判定されたプリセット（リセット用）
  QualityLevel _defaultPreset = QualityLevel.medium;

  bool get tiltEnabled => switch (_qualityLevel) {
    QualityLevel.low || QualityLevel.medium => false,
    QualityLevel.high => true,
    QualityLevel.custom => _customTiltEnabled,
  };

  bool get showPrevOnion => switch (_qualityLevel) {
    QualityLevel.low || QualityLevel.medium || QualityLevel.high => true,
    QualityLevel.custom => _customShowPrev,
  };

  bool get showNextOnion => switch (_qualityLevel) {
    QualityLevel.low || QualityLevel.medium || QualityLevel.high => true,
    QualityLevel.custom => _customShowNext,
  };

  int get prevOnionSkinFrames => switch (_qualityLevel) {
    QualityLevel.low => 1,
    QualityLevel.medium => 3,
    QualityLevel.high => 5,
    QualityLevel.custom => _customOnionSkinPrev,
  };

  int get nextOnionSkinFrames => switch (_qualityLevel) {
    QualityLevel.low => 1,
    QualityLevel.medium => 3,
    QualityLevel.high => 5,
    QualityLevel.custom => _customOnionSkinNext,
  };

  SaveMode get saveMode => switch (_qualityLevel) {
    QualityLevel.low => SaveMode.slot,
    QualityLevel.medium => SaveMode.slot,
    QualityLevel.high => SaveMode.tree,
    QualityLevel.custom => _customSaveMode,
  };

  int get slotCount => switch (_qualityLevel) {
    QualityLevel.low => 5,
    QualityLevel.medium => 10,
    QualityLevel.high => 0, // ツリー方式のためスロット数なし（参照不可）
    QualityLevel.custom => _customSlotCount,
  };

  /// 初回起動時に自動判定されたプリセット（リセット先として表示用）
  QualityLevel get defaultPreset => _defaultPreset;

  /// CPUコア数から簡易的に品質プリセットを判定する。2万円台の低スペック
  /// 端末は概ね4コア以下、中位機は6コア前後、ハイエンド機は8コア以上が多い。
  QualityLevel _detectQualityFromCpuCores() {
    try {
      final cores = Platform.numberOfProcessors;
      if (cores <= 4) return QualityLevel.low;
      if (cores <= 6) return QualityLevel.medium;
      return QualityLevel.high;
    } catch (_) {
      return QualityLevel.medium;
    }
  }

  /// 初回起動時：端末性能を判定し、プリセットを決定。
  /// カスタム設定が未保存の場合のみ、そのプリセット値をカスタム初期値としてコピー。
  Future<void> detectDeviceCapability() async {
    final prefs = await SharedPreferences.getInstance();

    // 保存済み品質レベルを復元
    final savedLevel = prefs.getString('quality_level');
    if (savedLevel != null) {
      _qualityLevel = QualityLevel.values.firstWhere(
        (e) => e.name == savedLevel,
        orElse: () => QualityLevel.medium,
      );
    } else {
      // 初回：端末性能判定。追加パッケージなしで取得できるCPUコア数を
      // 簡易指標として使用する（低スペック端末ほどコア数が少ない傾向）。
      _qualityLevel = _detectQualityFromCpuCores();
      await prefs.setString('quality_level', _qualityLevel.name);
    }

    // 初回判定プリセットを保存・復元
    final savedDefault = prefs.getString('default_preset');
    if (savedDefault != null) {
      _defaultPreset = QualityLevel.values.firstWhere(
        (e) => e.name == savedDefault,
        orElse: () => QualityLevel.medium,
      );
    } else {
      // 初回のみ：現在の判定結果をデフォルトとして記録
      _defaultPreset = _qualityLevel == QualityLevel.custom
          ? QualityLevel.medium
          : _qualityLevel;
      await prefs.setString('default_preset', _defaultPreset.name);
    }

    // カスタム設定を復元（保存済みがあれば）
    final hasCustom = prefs.getBool('custom_saved') ?? false;
    if (hasCustom) {
      _customTiltEnabled = prefs.getBool('custom_tilt') ?? false;
      _customShowPrev = prefs.getBool('custom_show_prev') ?? true;
      _customShowNext = prefs.getBool('custom_show_next') ?? true;
      _customOnionSkinPrev = prefs.getInt('custom_onion_prev') ?? 3;
      _customOnionSkinNext = prefs.getInt('custom_onion_next') ?? 3;
      _customSaveMode = (prefs.getString('custom_save_mode') == 'tree')
          ? SaveMode.tree
          : SaveMode.slot;
      _customSlotCount = prefs.getInt('custom_slot_count') ?? 10;
    } else {
      // 初回のみ：判定されたプリセット値をカスタム初期値としてコピー
      _copyPresetValues(_defaultPreset);
    }

    notifyListeners();
  }

  void setQualityLevel(QualityLevel level) {
    _qualityLevel = level;
    _saveQualityLevel();
    notifyListeners();
  }

  void setCustomTilt(bool enabled) {
    _customTiltEnabled = enabled;
    _saveCustomSettings();
    notifyListeners();
  }

  void setCustomShowPrev(bool show) {
    _customShowPrev = show;
    _saveCustomSettings();
    notifyListeners();
  }

  void setCustomShowNext(bool show) {
    _customShowNext = show;
    _saveCustomSettings();
    notifyListeners();
  }

  void setCustomOnionSkinPrev(int prev) {
    assert(prev >= 1 && prev <= 10);
    _customOnionSkinPrev = prev;
    _saveCustomSettings();
    notifyListeners();
  }

  void setCustomOnionSkinNext(int next) {
    assert(next >= 1 && next <= 10);
    _customOnionSkinNext = next;
    _saveCustomSettings();
    notifyListeners();
  }

  void setCustomSaveMode(SaveMode mode) {
    _customSaveMode = mode;
    _saveCustomSettings();
    notifyListeners();
  }

  void setCustomSlotCount(int count) {
    _customSlotCount = count;
    _saveCustomSettings();
    notifyListeners();
  }

  /// カスタム設定を初回判定プリセットの値にリセット
  void resetCustomToDefault() {
    _copyPresetValues(_defaultPreset);
    _saveCustomSettings();
    notifyListeners();
  }

  /// 指定プリセットの値をカスタム設定へコピー
  void copyPresetToCustom(QualityLevel preset) {
    assert(preset != QualityLevel.custom);
    _copyPresetValues(preset);
    _saveCustomSettings();
    notifyListeners();
  }

  void _copyPresetValues(QualityLevel preset) {
    switch (preset) {
      case QualityLevel.low:
        _customTiltEnabled = false;
        _customShowPrev = true;
        _customShowNext = true;
        _customOnionSkinPrev = 1;
        _customOnionSkinNext = 1;
        _customSaveMode = SaveMode.slot;
        _customSlotCount = 5;
      case QualityLevel.medium:
        _customTiltEnabled = false;
        _customShowPrev = true;
        _customShowNext = true;
        _customOnionSkinPrev = 3;
        _customOnionSkinNext = 3;
        _customSaveMode = SaveMode.slot;
        _customSlotCount = 10;
      case QualityLevel.high:
        _customTiltEnabled = true;
        _customShowPrev = true;
        _customShowNext = true;
        _customOnionSkinPrev = 5;
        _customOnionSkinNext = 5;
        _customSaveMode = SaveMode.tree;
        _customSlotCount = 10;
      case QualityLevel.custom:
        break; // no-op
    }
  }

  Future<void> _saveQualityLevel() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('quality_level', _qualityLevel.name);
  }

  Future<void> _saveCustomSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('custom_saved', true);
    await prefs.setBool('custom_tilt', _customTiltEnabled);
    await prefs.setBool('custom_show_prev', _customShowPrev);
    await prefs.setBool('custom_show_next', _customShowNext);
    await prefs.setInt('custom_onion_prev', _customOnionSkinPrev);
    await prefs.setInt('custom_onion_next', _customOnionSkinNext);
    await prefs.setString(
      'custom_save_mode',
      _customSaveMode == SaveMode.tree ? 'tree' : 'slot',
    );
    await prefs.setInt('custom_slot_count', _customSlotCount);
  }
}

enum QualityLevel { low, medium, high, custom }

enum SaveMode { slot, tree }
