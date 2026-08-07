import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/color_palette.dart';

/// カラーピッカーの「最近使った色」「パレット」を管理する（仕様書20：色管理仕様）。
/// - 最近使った色：直近10色をタップで即座に選択できるよう保持する。
/// - パレット：ユーザーが任意の色を登録できる複数パレットを作成・切替・
///   編集（色の追加・削除・並び替え）・お気に入り登録できる。
class PaletteService extends ChangeNotifier {
  static const _recentKey = 'palette_recent_colors';
  static const _palettesKey = 'color_palettes';
  static const _activeKey = 'color_palette_active_id';
  static const int _maxRecent = 10;

  final List<int> _recentColors = [];
  final List<ColorPalette> _palettes = [];
  String? _activePaletteId;

  List<int> get recentColors => List.unmodifiable(_recentColors);
  List<ColorPalette> get palettes => List.unmodifiable(_palettes);
  String? get activePaletteId => _activePaletteId;
  ColorPalette? get activePalette =>
      _palettes.where((p) => p.id == _activePaletteId).firstOrNull;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final rawRecent = prefs.getStringList(_recentKey) ?? const [];
    _recentColors
      ..clear()
      ..addAll(rawRecent.map(int.parse));

    final rawPalettes = prefs.getStringList(_palettesKey) ?? const [];
    _palettes
      ..clear()
      ..addAll(rawPalettes.map((s) => ColorPalette.fromJson(jsonDecode(s) as Map<String, dynamic>)));
    if (_palettes.isEmpty) {
      // 初回起動時：デフォルトパレットを1つ用意する
      _palettes.add(const ColorPalette(id: 'default', name: 'マイパレット'));
    }
    _activePaletteId = prefs.getString(_activeKey) ?? _palettes.first.id;
    if (!_palettes.any((p) => p.id == _activePaletteId)) {
      _activePaletteId = _palettes.first.id;
    }
  }

  Future<void> _persistRecent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentKey, _recentColors.map((c) => c.toString()).toList());
  }

  Future<void> _persistPalettes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_palettesKey, _palettes.map((p) => jsonEncode(p.toJson())).toList());
    if (_activePaletteId != null) {
      await prefs.setString(_activeKey, _activePaletteId!);
    }
  }

  /// 色を「最近使った色」の先頭へ追加する（重複は既存分を削除してから先頭へ）。
  /// 直近10色を超える分は末尾から破棄する。
  Future<void> addRecentColor(int argb) async {
    _recentColors.remove(argb);
    _recentColors.insert(0, argb);
    if (_recentColors.length > _maxRecent) {
      _recentColors.removeRange(_maxRecent, _recentColors.length);
    }
    await _persistRecent();
    notifyListeners();
  }

  Future<void> createPalette(String name) async {
    final palette = ColorPalette(id: 'palette_${DateTime.now().microsecondsSinceEpoch}', name: name);
    _palettes.add(palette);
    _activePaletteId = palette.id;
    await _persistPalettes();
    notifyListeners();
  }

  Future<void> renamePalette(String id, String name) async {
    final idx = _palettes.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    _palettes[idx] = _palettes[idx].copyWith(name: name);
    await _persistPalettes();
    notifyListeners();
  }

  /// パレットを削除する。最後の1件は削除できない（常に1つは残す）。
  Future<void> deletePalette(String id) async {
    if (_palettes.length <= 1) return;
    _palettes.removeWhere((p) => p.id == id);
    if (_activePaletteId == id) {
      _activePaletteId = _palettes.first.id;
    }
    await _persistPalettes();
    notifyListeners();
  }

  Future<void> setActivePalette(String id) async {
    if (!_palettes.any((p) => p.id == id)) return;
    _activePaletteId = id;
    await _persistPalettes();
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    final idx = _palettes.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    _palettes[idx] = _palettes[idx].copyWith(isFavorite: !_palettes[idx].isFavorite);
    await _persistPalettes();
    notifyListeners();
  }

  Future<void> addColorToPalette(String paletteId, int argb) async {
    final idx = _palettes.indexWhere((p) => p.id == paletteId);
    if (idx < 0) return;
    final colors = List<int>.from(_palettes[idx].colors)..add(argb);
    _palettes[idx] = _palettes[idx].copyWith(colors: colors);
    await _persistPalettes();
    notifyListeners();
  }

  Future<void> removeColorFromPalette(String paletteId, int index) async {
    final idx = _palettes.indexWhere((p) => p.id == paletteId);
    if (idx < 0) return;
    final colors = List<int>.from(_palettes[idx].colors);
    if (index < 0 || index >= colors.length) return;
    colors.removeAt(index);
    _palettes[idx] = _palettes[idx].copyWith(colors: colors);
    await _persistPalettes();
    notifyListeners();
  }

  Future<void> reorderColorInPalette(String paletteId, int oldIndex, int newIndex) async {
    final idx = _palettes.indexWhere((p) => p.id == paletteId);
    if (idx < 0) return;
    final colors = List<int>.from(_palettes[idx].colors);
    if (oldIndex < 0 || oldIndex >= colors.length) return;
    final item = colors.removeAt(oldIndex);
    final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    colors.insert(target.clamp(0, colors.length), item);
    _palettes[idx] = _palettes[idx].copyWith(colors: colors);
    await _persistPalettes();
    notifyListeners();
  }
}
