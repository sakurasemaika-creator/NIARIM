import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/color_palette.dart';
import '../utils/saved_list_reader.dart';
import '../utils/tolerant_preferences.dart';
import '../utils/transfer_merge.dart';
import 'palette_service.dart' show paletteMergeRules;

/// ドット絵専用パレット（ブラシのピクセルモード・ドット絵フィルターの
/// 「パレットから選ぶ」で使う）を管理するサービス。
///
/// カラーピッカーの一般用途パレット（[PaletteService]/[ColorPalette]）とは
/// 別の一覧として保持する（ユーザーが「ドット絵専用パレットを作成できる
/// 画面」と明示的に区別して求めたため）。データの形自体は同じで良いため
/// [ColorPalette]モデルをそのまま再利用し、永続化キーだけ分ける。
class PixelArtPaletteService extends ChangeNotifier {
  static const _prefsKey = 'pixel_art_palettes';

  /// このサービスが持つ保存のキー。引き継ぎ（.niatra）の「端末保存データ」
  /// では扱わない（「パレット」の項目が[mergeTransferred]で取り込む）。
  static const Set<String> savedPreferenceKeys = {_prefsKey};

  final List<ColorPalette> _palettes = [];

  /// 引き継ぎでもう1台の版を足した複製の記録（[init]で読む）。
  TransferCopyRecord _transferCopies = TransferCopyRecord.none();

  List<ColorPalette> get palettes => List.unmodifiable(_palettes);

  ColorPalette? paletteById(String? id) =>
      id == null ? null : _palettes.where((p) => p.id == id).firstOrNull;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _transferCopies = TransferCopyRecord.readFrom(
      prefs,
      TransferCopyRecord.pixelArtPalettes,
    );
    final raw = prefs.readStringList(_prefsKey) ?? const [];
    _palettes
      ..clear()
      ..addAll(readSavedJsonList(raw, ColorPalette.fromJson));
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKey,
      _palettes.map((p) => jsonEncode(p.toJson())).toList(),
    );
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

  /// 引き継ぎ（.niatra）で受け取ったパレットを、この端末の一覧へ合わせて
  /// 保存する。自分の別の端末の内容なのでIDで突き合わせ、同じIDで色か名前が
  /// 違えば、この端末のパレットを残して受け取った方を「名前 (コピー)」として
  /// 足す（決まりは[mergeTransferredItems]。何度読んでも増えない）。
  Future<void> mergeTransferred(
    List<ColorPalette> incoming, {
    required TransferCopyNames copyNames,
  }) async {
    // 前の読み込みでもう1台の版を足した複製（名前を変えていても見つける）。
    // 一覧は待たずに合わせる（起動のときに読んでおいた記録）。
    final copies = _transferCopies;
    final changed = mergeTransferredItems(
      _palettes,
      incoming,
      paletteMergeRules(copyNames: copyNames, idPrefix: 'PixelPalette'),
      copies: copies,
    );
    if (!changed) return;
    notifyListeners();
    await _persist();
    await copies.save();
  }

  Future<void> updatePalette(
    String id, {
    String? name,
    List<int>? colors,
  }) async {
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

  // ─── 共有（.niapixelpalette）：バイナリ資産を持たない単純なJSON設定
  // のため、zip化はせずJSONそのまま書き出す（palette_service.dartの
  // .niapaletteと同じ方針）。 ────────────────────────────────────────

  Future<File> exportPalette(String id) async {
    final palette = _palettes.firstWhere((p) => p.id == id);
    final base = await getApplicationDocumentsDirectory();
    final safeName = palette.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File('${base.path}/$safeName.niapixelpalette');
    await file.writeAsString(jsonEncode(palette.toJson()));
    return file;
  }

  Future<ColorPalette> importPaletteFile(String filePath) async {
    final content = await File(filePath).readAsString();
    return importPaletteJson(content);
  }

  /// JSON文字列（`exportPalette`が書き出す形式と同じ）からパレットを取り込む。
  /// QRコード共有で読み取ったテキストの取り込みにも使う。
  Future<ColorPalette> importPaletteJson(String json) async {
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    return addPalette(
      (decoded['name'] as String?) ?? '',
      ((decoded['colors'] as List<dynamic>?) ?? const [])
          .map((e) => e as int)
          .toList(),
    );
  }
}
