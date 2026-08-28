import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/color_palette.dart';

/// ドット絵専用パレット（ブラシのピクセルモード・ドット絵フィルターの
/// 「パレットから選ぶ」で使う）を管理するサービス。
///
/// カラーピッカーの一般用途パレット（[PaletteService]/[ColorPalette]）とは
/// 別の一覧として保持する（ユーザーが「ドット絵専用パレットを作成できる
/// 画面」と明示的に区別して求めたため）。データの形自体は同じで良いため
/// [ColorPalette]モデルをそのまま再利用し、永続化キーだけ分ける。
class PixelArtPaletteService extends ChangeNotifier {
  static const _prefsKey = 'pixel_art_palettes';

  final List<ColorPalette> _palettes = [];

  List<ColorPalette> get palettes => List.unmodifiable(_palettes);

  ColorPalette? paletteById(String? id) =>
      id == null ? null : _palettes.where((p) => p.id == id).firstOrNull;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? const [];
    _palettes
      ..clear()
      ..addAll(raw.map((s) => ColorPalette.fromJson(jsonDecode(s) as Map<String, dynamic>)));
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _prefsKey, _palettes.map((p) => jsonEncode(p.toJson())).toList());
  }

  /// 新規パレットを追加する。[name]は事前に空でないことを呼び出し側
  /// （UI層）で検証しておくこと（本サービスはバリデーションを行わない）。
  Future<ColorPalette> addPalette(String name, List<int> colors) async {
    final palette = ColorPalette(
      id: 'PixelPalette${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      colors: colors,
    );
    _palettes.add(palette);
    notifyListeners();
    await _persist();
    return palette;
  }

  Future<void> updatePalette(String id, {String? name, List<int>? colors}) async {
    final idx = _palettes.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    _palettes[idx] = _palettes[idx].copyWith(name: name, colors: colors);
    notifyListeners();
    await _persist();
  }

  Future<void> deletePalette(String id) async {
    _palettes.removeWhere((p) => p.id == id);
    notifyListeners();
    await _persist();
  }
}
