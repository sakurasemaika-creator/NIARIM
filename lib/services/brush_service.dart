import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/brush.dart';

/// ブラシ管理サービス（仕様書17）。
/// SharedPreferencesへ永続化する（端末単位。プロジェクトファイルには含めない）。
/// 従来はインメモリのみで、お気に入り・並び替え・複製・削除・パラメータ編集の
/// すべてがアプリ再起動のたびに失われていた。
class BrushService extends ChangeNotifier {
  static const _prefsKey = 'brushes';
  static const _currentIdKey = 'brushes_current_id';

  final List<Brush> _brushes = [];
  final List<BrushFolder> _folders = [];
  Brush? _currentBrush;
  Color _currentColor = const Color(0xFF000000);

  List<Brush> get brushes => List.unmodifiable(_brushes);
  List<BrushFolder> get folders => List.unmodifiable(_folders);
  Brush? get currentBrush => _currentBrush;
  Color get currentColor => _currentColor;

  void setCurrentColor(Color color) {
    _currentColor = color;
    notifyListeners();
  }

  static List<Brush> _defaultBrushes() => [
        const Brush(
          id: 'Brush0001', name: 'ペン', size: 5, opacity: 100, spacing: 10,
          blurRadius: 0, stabilization: true, stabilizationStrength: 50,
          dotPenMode: false, pressureMode: PressureMode.size, pressureStrength: 80,
          fadeMode: FadeMode.off, strokeDecay: false,
          mixingMode: BrushMixingMode.off, mixingRate: 0,
        ),
        const Brush(
          id: 'Brush0002', name: 'Gペン', size: 3, opacity: 100, spacing: 5,
          blurRadius: 0, stabilization: true, stabilizationStrength: 60,
          dotPenMode: false, pressureMode: PressureMode.sizeAndOpacity, pressureStrength: 90,
          fadeMode: FadeMode.weak, strokeDecay: false,
          mixingMode: BrushMixingMode.off, mixingRate: 0,
        ),
        const Brush(
          id: 'Brush0003', name: 'エアブラシ', size: 30, opacity: 40, spacing: 3,
          blurRadius: 50, stabilization: false, stabilizationStrength: 0,
          dotPenMode: false, pressureMode: PressureMode.opacity, pressureStrength: 70,
          fadeMode: FadeMode.off, strokeDecay: false,
          mixingMode: BrushMixingMode.off, mixingRate: 0,
        ),
        const Brush(
          id: 'Brush0004', name: '混色ブラシ', size: 15, opacity: 80, spacing: 8,
          blurRadius: 10, stabilization: false, stabilizationStrength: 0,
          dotPenMode: false, pressureMode: PressureMode.size, pressureStrength: 60,
          fadeMode: FadeMode.off, strokeDecay: false,
          mixingMode: BrushMixingMode.simple, mixingRate: 50,
        ),
      ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey);
    _brushes.clear();
    if (raw == null) {
      // 初回起動：初期ブラシ一式を投入して即座に永続化する
      _brushes.addAll(_defaultBrushes());
      await _persist();
    } else {
      _brushes.addAll(raw.map((s) => Brush.fromJson(jsonDecode(s) as Map<String, dynamic>)));
    }
    final currentId = prefs.getString(_currentIdKey);
    _currentBrush = _brushes.where((b) => b.id == currentId).firstOrNull ?? _brushes.firstOrNull;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _brushes.map((b) => jsonEncode(b.toJson())).toList());
  }

  Future<void> _persistCurrent() async {
    final prefs = await SharedPreferences.getInstance();
    final id = _currentBrush?.id;
    if (id == null) {
      await prefs.remove(_currentIdKey);
    } else {
      await prefs.setString(_currentIdKey, id);
    }
  }

  void selectBrush(String id) {
    _currentBrush = _brushes.firstWhere((b) => b.id == id);
    notifyListeners();
    _persistCurrent();
  }

  void updateCurrentBrushSize(double size) {
    if (_currentBrush != null) {
      _currentBrush = _currentBrush!.copyWith(size: size);
      notifyListeners();
    }
  }

  void updateCurrentBrushOpacity(int opacity) {
    if (_currentBrush != null) {
      _currentBrush = _currentBrush!.copyWith(opacity: opacity);
      notifyListeners();
    }
  }

  void addBrush(Brush brush) {
    _brushes.add(brush);
    notifyListeners();
    _persist();
  }

  void deleteBrush(String id) {
    _brushes.removeWhere((b) => b.id == id);
    notifyListeners();
    _persist();
  }

  void duplicateBrush(String id) {
    final brush = _brushes.firstWhere((b) => b.id == id);
    final newId = 'Brush${DateTime.now().millisecondsSinceEpoch}';
    _brushes.add(brush.copyWith(id: newId, name: '${brush.name} (コピー)'));
    notifyListeners();
    _persist();
  }

  void toggleFavoriteBrush(String id) {
    final idx = _brushes.indexWhere((b) => b.id == id);
    if (idx >= 0) {
      _brushes[idx] = _brushes[idx].copyWith(isFavorite: !_brushes[idx].isFavorite);
      notifyListeners();
      _persist();
    }
  }

  void reorderBrush(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final brush = _brushes.removeAt(oldIndex);
    _brushes.insert(newIndex, brush);
    notifyListeners();
    _persist();
  }

  void updateBrush(Brush brush) {
    final idx = _brushes.indexWhere((b) => b.id == brush.id);
    if (idx >= 0) {
      _brushes[idx] = brush;
      if (_currentBrush?.id == brush.id) _currentBrush = brush;
      notifyListeners();
      _persist();
    }
  }
}

class BrushFolder {
  final String id;
  final String name;
  final List<String> brushIds;
  final bool isFavorite;

  BrushFolder({
    required this.id,
    required this.name,
    this.brushIds = const [],
    this.isFavorite = false,
  });
}
