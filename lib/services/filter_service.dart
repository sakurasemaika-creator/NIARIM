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

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setFavoritesOnly(bool value) {
    _favoritesOnly = value;
    notifyListeners();
  }
}
