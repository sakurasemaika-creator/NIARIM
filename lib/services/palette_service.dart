import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/color_palette.dart';
import '../utils/saved_list_reader.dart';
import '../utils/tolerant_preferences.dart';
import '../utils/transfer_merge.dart';

/// カラーピッカーの「最近使った色」「パレット」を管理する。
/// - 最近使った色：直近10色をタップで即座に選択できるよう保持する。
/// - パレット：ユーザーが任意の色を登録できる複数パレットを作成・切替・
///   編集（色の追加・削除・並び替え）・お気に入り登録できる。
class PaletteService extends ChangeNotifier {
  static const _recentKey = 'palette_recent_colors';
  static const _palettesKey = 'color_palettes';
  static const _activeKey = 'color_palette_active_id';
  static const int _maxRecent = 10;

  /// 初回起動で用意するパレット（どの端末も同じID）。
  static const _defaultPalette = ColorPalette(id: 'default', name: 'マイパレット');

  /// このサービスが持つ保存のキー。引き継ぎ（.niatra）の「端末保存データ」
  /// では扱わない（「パレット」の項目が[mergeTransferred]で一覧と突き合わせて
  /// 取り込む。保存を直接書き換えると、動いている一覧の次の保存で戻り、
  /// 起動し直すとこの端末にしか無いパレットが消える）。
  static const Set<String> savedPreferenceKeys = {
    _recentKey,
    _palettesKey,
    _activeKey,
  };

  final List<int> _recentColors = [];
  final List<ColorPalette> _palettes = [];

  /// 引き継ぎでもう1台の版を足した複製の記録（[init]で読む）。
  TransferCopyRecord _transferCopies = TransferCopyRecord.none();
  String? _activePaletteId;

  List<int> get recentColors => List.unmodifiable(_recentColors);
  List<ColorPalette> get palettes => List.unmodifiable(_palettes);
  String? get activePaletteId => _activePaletteId;
  ColorPalette? get activePalette =>
      _palettes.where((p) => p.id == _activePaletteId).firstOrNull;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _transferCopies = TransferCopyRecord.readFrom(
      prefs,
      TransferCopyRecord.palettes,
    );
    final rawRecent = prefs.readStringList(_recentKey) ?? const [];
    _recentColors
      ..clear()
      // 数として読めない1件は飛ばす（1件で起動を止めない）。
      ..addAll(rawRecent.map(int.tryParse).whereType<int>());

    final rawPalettes = prefs.readStringList(_palettesKey) ?? const [];
    _palettes
      ..clear()
      ..addAll(readSavedJsonList(rawPalettes, ColorPalette.fromJson));
    if (_palettes.isEmpty) {
      // 初回起動時：デフォルトパレットを1つ用意する
      _palettes.add(_defaultPalette);
    }
    _activePaletteId = prefs.readString(_activeKey) ?? _palettes.first.id;
    if (!_palettes.any((p) => p.id == _activePaletteId)) {
      _activePaletteId = _palettes.first.id;
    }
  }

  Future<void> _persistRecent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _recentKey,
      _recentColors.map((c) => c.toString()).toList(),
    );
  }

  Future<void> _persistPalettes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _palettesKey,
      _palettes.map((p) => jsonEncode(p.toJson())).toList(),
    );
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
    final palette = ColorPalette(
      id: 'palette_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
    );
    _palettes.add(palette);
    _activePaletteId = palette.id;
    await _persistPalettes();
    notifyListeners();
  }

  /// 他ユーザーから共有された（.niapalette・QRコード等）パレットを
  /// 新規パレットとして取り込む。IDは衝突を避けるため新規採番し直す
  /// （自分の別の端末からの引き継ぎ（.niatra）は[mergeTransferred]）。
  Future<ColorPalette> importPalette(ColorPalette palette) async {
    final withNewId = ColorPalette(
      id: 'palette_${DateTime.now().microsecondsSinceEpoch}',
      name: palette.name,
      colors: palette.colors,
    );
    _palettes.add(withNewId);
    await _persistPalettes();
    notifyListeners();
    return withNewId;
  }

  /// 引き継ぎ（.niatra）で受け取ったパレットと最近使った色を、この端末へ
  /// 合わせて保存する。他の人から受け取る[importPalette]と違い、自分の別の
  /// 端末の内容なのでIDで突き合わせ、この端末の内容は黙って失わない（決まりは
  /// [mergeTransferredItems]）：同じIDで色か名前が違えば、この端末の
  /// パレットを残し、受け取った方を「名前 (コピー)」として足す。最初の
  /// 「マイパレット」（どの端末も同じID）は、この端末で空のままなら受け取った
  /// 方で置き換える。最近使った色は、この端末の色をそのまま先に残し、空いて
  /// いる所にだけ受け取った色を入れる（受け取った色でこの端末の履歴を押し
  /// 出さない。埋まっていれば、同じファイルを読み直しても変わらない）。
  /// [activePaletteId]は合わせた後の一覧にあるときだけ選ぶ。
  /// 変えたときだけ保存する。
  Future<void> mergeTransferred(
    List<ColorPalette> incoming, {
    required TransferCopyNames copyNames,
    List<int> recentColors = const [],
    String? activePaletteId,
  }) async {
    // 前の読み込みでもう1台の版を足した複製（名前を変えていても見つける）。
    // 一覧は待たずに合わせる（起動のときに読んでおいた記録）。
    final copies = _transferCopies;
    final palettesChanged = mergeTransferredItems(
      _palettes,
      incoming,
      paletteMergeRules(
        copyNames: copyNames,
        idPrefix: 'palette_',
        shipped: const [_defaultPalette],
      ),
      copies: copies,
    );
    final recent = <int>{
      ..._recentColors,
      ...recentColors,
    }.take(_maxRecent).toList();
    final recentChanged = jsonEncode(recent) != jsonEncode(_recentColors);
    if (recentChanged) {
      _recentColors
        ..clear()
        ..addAll(recent);
      await _persistRecent();
    }
    final activeChanged =
        activePaletteId != null &&
        activePaletteId != _activePaletteId &&
        _palettes.any((p) => p.id == activePaletteId);
    if (activeChanged) _activePaletteId = activePaletteId;
    if (palettesChanged || activeChanged) await _persistPalettes();
    if (palettesChanged || activeChanged || recentChanged) notifyListeners();
    await copies.save();
  }

  // ─── 共有（.niapalette）：ワークスペース設定（.niaworkspace）と同じく
  // バイナリ資産を持たない単純なJSON設定のため、zip化はせずJSONそのまま
  // 書き出す。ファイル共有・QRコード共有（テキストのやり取り）の両方で
  // 同じJSON文字列を使い回せるようにするため。 ──────────────────────

  String _exportJson(ColorPalette palette) => jsonEncode(palette.toJson());

  Future<File> exportPalette(String id) async {
    final palette = _palettes.firstWhere((p) => p.id == id);
    final base = await getApplicationDocumentsDirectory();
    final safeName = palette.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File('${base.path}/$safeName.niapalette');
    await file.writeAsString(_exportJson(palette));
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
    return importPalette(ColorPalette.fromJson(decoded));
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
    _palettes[idx] = _palettes[idx].copyWith(
      isFavorite: !_palettes[idx].isFavorite,
    );
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
}

/// 引き継ぎ（.niatra）でパレットを合わせる決まり（カラーピッカーと
/// ドット絵専用で共通）。[shipped]はどの端末にもあるパレット。
TransferMergeRules<ColorPalette> paletteMergeRules({
  required TransferCopyNames copyNames,
  required String idPrefix,
  List<ColorPalette> shipped = const [],
}) => TransferMergeRules<ColorPalette>(
  idOf: (p) => p.id,
  nameOf: (p) => p.name,
  contentOf: (p) => p.colors,
  organizationOf: (p) =>
      (favorite: p.isFavorite, tags: const [], folderId: null),
  withOrganization: (p, o) => p.copyWith(isFavorite: o.favorite),
  asCopy: (p, id, name) => ColorPalette(
    id: id,
    name: name,
    colors: p.colors,
    isFavorite: p.isFavorite,
  ),
  newId: (attempt) =>
      '$idPrefix${DateTime.now().microsecondsSinceEpoch}_$attempt',
  copyNames: copyNames,
  shippedOf: (id) => shipped.where((p) => p.id == id).firstOrNull,
);
