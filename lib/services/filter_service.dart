import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/filter_def.dart';

/// 描画フィルターサービス（仕様書18）。
/// フィルター一覧・現在選択中フィルター・お気に入り・検索を管理する。
/// 実際のピクセル処理はFilterEngineが担当し、本サービスは定義とパラメータの
/// 状態管理のみを行う（ToneService／StampServiceと同じ設計方針）。
/// パラメータ・お気に入りはSharedPreferencesへ永続化する（端末単位）。
/// 従来はインメモリのみで、アプリ再起動のたびに失われていた。
class FilterService extends ChangeNotifier {
  static const _prefsKey = 'draw_filters';

  final List<FilterDef> _filters = [];
  String? _currentFilterId;
  String _searchQuery = '';
  bool _favoritesOnly = false;

  List<FilterDef> get filters => List.unmodifiable(_filters);
  FilterDef? get currentFilter =>
      _filters.where((f) => f.id == _currentFilterId).firstOrNull;
  String get searchQuery => _searchQuery;
  bool get favoritesOnly => _favoritesOnly;

  /// 検索・お気に入り絞り込みを反映した一覧
  List<FilterDef> get visibleFilters {
    return _filters.where((f) {
      if (_favoritesOnly && !f.isFavorite) return false;
      if (_searchQuery.isEmpty) return true;
      return f.name.contains(_searchQuery);
    }).toList();
  }

  static List<FilterDef> _defaultFilters() => const [
        FilterDef(id: 'Filter0001', name: 'ガウスぼかし', kind: FilterKind.gaussianBlur, strength: 8),
        FilterDef(id: 'Filter0002', name: 'レンズぼかし', kind: FilterKind.lensBlur, strength: 8),
        FilterDef(id: 'Filter0003', name: 'アニメ風加工', kind: FilterKind.animeStyle, colorLevels: 6, edgeStrength: 0.4),
        FilterDef(id: 'Filter0004', name: 'トーンカーブ', kind: FilterKind.toneCurve),
        FilterDef(id: 'Filter0005', name: 'レベル補正', kind: FilterKind.levels),
        FilterDef(id: 'Filter0006', name: '縁取り', kind: FilterKind.outline, outlineColor: 0xFF000000, outlineWidth: 6),
        FilterDef(id: 'Filter0007', name: 'シャープ', kind: FilterKind.sharpen, strength: 50),
        FilterDef(id: 'Filter0008', name: 'アンシャープマスク', kind: FilterKind.unsharpMask, strength: 4, edgeStrength: 1.0),
        FilterDef(id: 'Filter0009', name: '周辺減光', kind: FilterKind.vignette, strength: 40),
        FilterDef(id: 'Filter0010', name: 'フィルムグレイン', kind: FilterKind.noise, strength: 15),
        FilterDef(id: 'Filter0011', name: 'レトロアニメ', kind: FilterKind.retroAnime, strength: 60),
        FilterDef(id: 'Filter0012', name: 'ブラウン管', kind: FilterKind.crt, strength: 50),
        FilterDef(id: 'Filter0013', name: 'モノクロ', kind: FilterKind.monochrome, strength: 100),
        FilterDef(id: 'Filter0014', name: '二値化', kind: FilterKind.threshold, thresholdValue: 128),
      ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey);
    _filters.clear();
    if (raw == null) {
      _filters.addAll(_defaultFilters());
      await _persist();
    } else {
      _filters.addAll(raw.map((s) => FilterDef.fromJson(jsonDecode(s) as Map<String, dynamic>)));
      // 既存ユーザーにも新規追加した組み込みフィルター（シャープ・
      // アンシャープマスク）を反映する。
      final existingIds = _filters.map((f) => f.id).toSet();
      final missing = _defaultFilters().where((f) => !existingIds.contains(f.id));
      if (missing.isNotEmpty) {
        _filters.addAll(missing);
        await _persist();
      }
    }
    _currentFilterId = _filters.firstOrNull?.id;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _filters.map((f) => jsonEncode(f.toJson())).toList());
  }

  void selectFilter(String id) {
    _currentFilterId = id;
    notifyListeners();
  }

  void updateFilterParams(
    String id, {
    double? strength,
    int? colorLevels,
    double? edgeStrength,
    int? inputBlack,
    int? inputWhite,
    int? outputBlack,
    int? outputWhite,
    ToneCurvePreset? toneCurvePreset,
    int? outlineColor,
    double? outlineWidth,
    int? vignetteColor,
    double? caSaturation,
    double? caBrightness,
    double? caContrast,
    int? monochromeColor,
    double? thresholdValue,
  }) {
    final idx = _filters.indexWhere((f) => f.id == id);
    if (idx < 0) return;
    _filters[idx] = _filters[idx].copyWith(
      strength: strength,
      colorLevels: colorLevels,
      edgeStrength: edgeStrength,
      inputBlack: inputBlack,
      inputWhite: inputWhite,
      outputBlack: outputBlack,
      outputWhite: outputWhite,
      toneCurvePreset: toneCurvePreset,
      outlineColor: outlineColor,
      outlineWidth: outlineWidth,
      vignetteColor: vignetteColor,
      caSaturation: caSaturation,
      caBrightness: caBrightness,
      caContrast: caContrast,
      monochromeColor: monochromeColor,
      thresholdValue: thresholdValue,
    );
    notifyListeners();
    _persist();
  }

  void toggleFavorite(String id) {
    final idx = _filters.indexWhere((f) => f.id == id);
    if (idx >= 0) {
      _filters[idx] = _filters[idx].copyWith(isFavorite: !_filters[idx].isFavorite);
      notifyListeners();
      _persist();
    }
  }

  // ─── ユーザー作成フィルターの追加・複製・削除 ──────────────────────────
  // プリインストールされている初期実装フィルター（_defaultFilters()の
  // 12件）は削除・複製の対象外とし、色調調整などから新規に追加した
  // フィルターのみ、フィルター一覧の三点メニューから削除・複製できる。

  static final Set<String> _builtInIds = _defaultFilters().map((f) => f.id).toSet();

  bool isBuiltIn(String id) => _builtInIds.contains(id);

  /// 新規フィルターを一覧へ追加する（色調調整の「フィルターに追加する」等）。
  void addFilter(FilterDef filter) {
    _filters.add(filter);
    _currentFilterId = filter.id;
    notifyListeners();
    _persist();
  }

  /// [id]のフィルターを複製する（名前の末尾に「のコピー」を付けて追加）。
  /// プリインストールのフィルターも複製自体は可能（複製後の新しいIDは
  /// プリインストール扱いにならない）。
  void duplicateFilter(String id) {
    final idx = _filters.indexWhere((f) => f.id == id);
    if (idx < 0) return;
    final source = _filters[idx];
    final copy = source.copyWith(
      id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
      name: '${source.name}_copy',
      isFavorite: false,
    );
    _filters.insert(idx + 1, copy);
    notifyListeners();
    _persist();
  }

  /// [id]のフィルターを削除する。プリインストール、またはお気に入り登録中の
  /// 場合は削除せずfalseを返す（呼び出し元でその旨のポップアップを表示する）。
  bool removeFilter(String id) {
    if (isBuiltIn(id)) return false;
    final idx = _filters.indexWhere((f) => f.id == id);
    if (idx < 0) return false;
    if (_filters[idx].isFavorite) return false;
    _filters.removeAt(idx);
    if (_currentFilterId == id) {
      _currentFilterId = _filters.firstOrNull?.id;
    }
    notifyListeners();
    _persist();
    return true;
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setFavoritesOnly(bool value) {
    _favoritesOnly = value;
    notifyListeners();
  }

  // ─── フィルター表示順の並べ替え ────────────────────────────────────
  // ドラッグハンドルによる並べ替え。順序は_filtersの配列順そのものを
  // SharedPreferencesへ永続化する既存の仕組み（_persist）をそのまま使う
  // ため、追加の保存キーは不要。FilterServiceはアプリ全体で単一の
  // Providerとして共有されるので、この並び順はプロジェクトに依存せず
  // アプリ内共通になる。

  /// [id]のフィルターを[newIndex]の位置へ移動する。一覧全体（フィルター順
  /// が絞り込みなしの状態）に対するインデックスで指定する。
  void reorderFilter(String id, int newIndex) {
    final oldIndex = _filters.indexWhere((f) => f.id == id);
    if (oldIndex < 0) return;
    final target = newIndex.clamp(0, _filters.length - 1);
    if (oldIndex == target) return;
    final item = _filters.removeAt(oldIndex);
    _filters.insert(target, item);
    notifyListeners();
    _persist();
  }
}
