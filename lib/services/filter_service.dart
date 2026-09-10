import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/filter_def.dart';
import '../models/pixel_color_mode.dart';

class FilterService extends ChangeNotifier {
  static const _prefsKey = 'draw_filters';
  static const prismFilterId = 'Filter0022';
  static const vhsNoiseFilterId = 'Filter0024';

  final List<FilterDef> _filters = [];
  String? _currentFilterId;
  String _searchQuery = '';
  bool _favoritesOnly = false;

  List<FilterDef> get filters => List.unmodifiable(_filters);
  FilterDef? get currentFilter =>
      _filters.where((f) => f.id == _currentFilterId).firstOrNull;
  String get searchQuery => _searchQuery;
  bool get favoritesOnly => _favoritesOnly;

  List<FilterDef> get visibleFilters {
    return _filters.where((f) {
      if (_favoritesOnly && !f.isFavorite) return false;
      if (_searchQuery.isEmpty) return true;
      return f.name.contains(_searchQuery);
    }).toList();
  }

  static List<FilterDef> _defaultFilters() => const [
    FilterDef(
      id: 'Filter0001',
      name: 'ガウスぼかし',
      kind: FilterKind.gaussianBlur,
      strength: 8,
    ),
    FilterDef(
      id: 'Filter0002',
      name: 'レンズぼかし',
      kind: FilterKind.lensBlur,
      strength: 8,
    ),
    FilterDef(
      id: 'Filter0003',
      name: 'アニメ風加工',
      kind: FilterKind.animeStyle,
      colorLevels: 6,
      edgeStrength: 0.4,
    ),
    FilterDef(id: 'Filter0004', name: 'トーンカーブ', kind: FilterKind.toneCurve),
    FilterDef(id: 'Filter0005', name: 'レベル補正', kind: FilterKind.levels),
    FilterDef(
      id: 'Filter0006',
      name: '縁取り',
      kind: FilterKind.outline,
      outlineColor: 0xFF000000,
      outlineWidth: 6,
    ),
    FilterDef(
      id: 'Filter0007',
      name: 'シャープ',
      kind: FilterKind.sharpen,
      strength: 50,
    ),
    FilterDef(
      id: 'Filter0008',
      name: 'アンシャープマスク',
      kind: FilterKind.unsharpMask,
      strength: 4,
      edgeStrength: 1.0,
    ),
    FilterDef(
      id: 'Filter0009',
      name: '周辺減光',
      kind: FilterKind.vignette,
      strength: 40,
    ),
    FilterDef(
      id: 'Filter0010',
      name: 'フィルムグレイン',
      kind: FilterKind.noise,
      strength: 15,
    ),
    FilterDef(
      id: 'Filter0011',
      name: 'レトロアニメ',
      kind: FilterKind.retroAnime,
      strength: 60,
    ),
    FilterDef(
      id: 'Filter0012',
      name: 'ブラウン管',
      kind: FilterKind.crt,
      strength: 50,
    ),
    FilterDef(
      id: 'Filter0013',
      name: 'モノクロ',
      kind: FilterKind.monochrome,
      strength: 100,
    ),
    FilterDef(
      id: 'Filter0014',
      name: '二値化',
      kind: FilterKind.threshold,
      thresholdValue: 128,
    ),
    FilterDef(
      id: 'Filter0015',
      name: '魚眼レンズ',
      kind: FilterKind.fisheye,
      strength: 50,
    ),
    FilterDef(
      id: 'Filter0016',
      name: '色収差',
      kind: FilterKind.chromaticAberration,
      strength: 8,
    ),
    FilterDef(
      id: 'Filter0017',
      name: '眼鏡断層',
      kind: FilterKind.lensDistortion,
      strength: 50,
    ),
    FilterDef(
      id: 'Filter0018',
      name: 'ドット絵',
      kind: FilterKind.pixelate,
      strength: 8,
      colorLevels: 8,
    ),
    FilterDef(
      id: 'Filter0019',
      name: 'オーロラホログラム',
      kind: FilterKind.auroraHologram,
      strength: 60,
    ),
    FilterDef(
      id: 'Filter0020',
      name: '背景馴染ませ',
      kind: FilterKind.backgroundBlend,
    ),
    FilterDef(
      id: 'Filter0021',
      name: '墨溜まり',
      kind: FilterKind.inkPool,
      inkPoolColor: 0xFF000000,
      inkPoolRange: 12,
      inkPoolCenterWidth: 6,
    ),
    FilterDef(
      id: 'Filter0023',
      name: '自動線画',
      kind: FilterKind.autoLineart,
      autoLineartRoughWidth: 12,
      autoLineartOutputWidth: 2,
      autoLineartTaperLength: 8,
      autoLineartSmoothing: 5,
      autoLineartColor: 0xFF000000,
    ),
    // Prism is dispatched by stable id to PrismFilterEngine. It directly repaints
    // the selected/reference layer using that layer's alpha as an opacity-lock mask.
    FilterDef(
      id: prismFilterId,
      name: 'プリズム',
      kind: FilterKind.prism,
      prismBlurPx: 17,
      prismDirectionDegrees: 90,
    ),
    // VHS noise uses the generic slots only under this stable built-in ID:
    // strength=noise, caSaturation=scanlines, caBrightness=color bleed,
    // caContrast=tracking, thresholdValue=deterministic seed.
    FilterDef(
      id: vhsNoiseFilterId,
      name: 'VHSノイズ',
      kind: FilterKind.noise,
      strength: 35,
      caSaturation: 35,
      caBrightness: 35,
      caContrast: 25,
      thresholdValue: 1984,
    ),
  ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey);
    _filters.clear();
    if (raw == null) {
      _filters.addAll(_defaultFilters());
      await _persist();
    } else {
      var migratedAutoLineartSmoothing = false;
      _filters.addAll(
        raw.map((s) {
          var filter = FilterDef.fromJson(
            jsonDecode(s) as Map<String, dynamic>,
          );
          if (filter.id == prismFilterId) {
            final usesLegacyDefaults =
                filter.prismBlurPx == 8 && filter.prismDirectionDegrees == 45;
            if (filter.kind != FilterKind.prism || usesLegacyDefaults) {
              filter = filter.copyWith(
                kind: FilterKind.prism,
                prismBlurPx: usesLegacyDefaults ? 17 : filter.prismBlurPx,
                prismDirectionDegrees: usesLegacyDefaults
                    ? 90
                    : filter.prismDirectionDegrees,
              );
              migratedAutoLineartSmoothing = true;
            }
          }
          if (filter.kind == FilterKind.autoLineart &&
              filter.autoLineartSmoothing > 10) {
            filter = filter.copyWith(
              autoLineartSmoothing: (filter.autoLineartSmoothing / 10)
                  .round()
                  .clamp(0, 10)
                  .toDouble(),
            );
            migratedAutoLineartSmoothing = true;
          }
          return filter;
        }),
      );
      final existingIds = _filters.map((f) => f.id).toSet();
      final missing = _defaultFilters().where(
        (f) => !existingIds.contains(f.id),
      );
      if (missing.isNotEmpty) {
        _filters.addAll(missing);
      }
      if (missing.isNotEmpty || migratedAutoLineartSmoothing) {
        await _persist();
      }
    }
    _currentFilterId = _filters.firstOrNull?.id;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKey,
      _filters.map((f) => jsonEncode(f.toJson())).toList(),
    );
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
    double? lensCenterOffsetX,
    double? lensCenterOffsetY,
    PixelColorMode? pixelColorMode,
    List<int>? pixelExplicitColors,
    double? hologramBrightness,
    double? hologramSaturation,
    AuroraHologramPreset? hologramPreset,
    int? bgBlendColor,
    double? bgBlendDirection,
    double? bgBlendLength,
    double? bgBlendBlur,
    bool? bgBlendAutoLight,
    double? bgBlendStrength,
    double? bgBlendLightStrength,
    double? bgBlendShadowStrength,
    double? bgBlendAmbientStrength,
    double? bgBlendReflectionStrength,
    double? bgBlendColorBleed,
    double? bgBlendSoftness,
    double? bgBlendSecondaryStrength,
    double? bgBlendMaterialProtection,
    double? bgBlendSamplingBand,
    int? bgBlendLightColor,
    int? bgBlendAmbientColor,
    int? bgBlendShadowColor,
    int? bgBlendReflectionColor,
    bool? bgBlendShowAnalysis,
    int? inkPoolColor,
    double? inkPoolRange,
    double? inkPoolCenterWidth,
    double? autoLineartRoughWidth,
    double? autoLineartOutputWidth,
    double? autoLineartTaperLength,
    double? autoLineartSmoothing,
    int? autoLineartColor,
    double? prismBlurPx,
    double? prismDirectionDegrees,
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
      lensCenterOffsetX: lensCenterOffsetX,
      lensCenterOffsetY: lensCenterOffsetY,
      pixelColorMode: pixelColorMode,
      pixelExplicitColors: pixelExplicitColors,
      hologramBrightness: hologramBrightness,
      hologramSaturation: hologramSaturation,
      hologramPreset: hologramPreset,
      bgBlendColor: bgBlendColor,
      bgBlendDirection: bgBlendDirection,
      bgBlendLength: bgBlendLength,
      bgBlendBlur: bgBlendBlur,
      bgBlendAutoLight: bgBlendAutoLight,
      bgBlendStrength: bgBlendStrength,
      bgBlendLightStrength: bgBlendLightStrength,
      bgBlendShadowStrength: bgBlendShadowStrength,
      bgBlendAmbientStrength: bgBlendAmbientStrength,
      bgBlendReflectionStrength: bgBlendReflectionStrength,
      bgBlendColorBleed: bgBlendColorBleed,
      bgBlendSoftness: bgBlendSoftness,
      bgBlendSecondaryStrength: bgBlendSecondaryStrength,
      bgBlendMaterialProtection: bgBlendMaterialProtection,
      bgBlendSamplingBand: bgBlendSamplingBand,
      bgBlendLightColor: bgBlendLightColor,
      bgBlendAmbientColor: bgBlendAmbientColor,
      bgBlendShadowColor: bgBlendShadowColor,
      bgBlendReflectionColor: bgBlendReflectionColor,
      bgBlendShowAnalysis: bgBlendShowAnalysis,
      inkPoolColor: inkPoolColor,
      inkPoolRange: inkPoolRange,
      inkPoolCenterWidth: inkPoolCenterWidth,
      autoLineartRoughWidth: autoLineartRoughWidth,
      autoLineartOutputWidth: autoLineartOutputWidth,
      autoLineartTaperLength: autoLineartTaperLength,
      autoLineartSmoothing: autoLineartSmoothing,
      autoLineartColor: autoLineartColor,
      prismBlurPx: prismBlurPx,
      prismDirectionDegrees: prismDirectionDegrees,
    );
    notifyListeners();
    _persist();
  }

  void toggleFavorite(String id) {
    final idx = _filters.indexWhere((f) => f.id == id);
    if (idx >= 0) {
      _filters[idx] = _filters[idx].copyWith(
        isFavorite: !_filters[idx].isFavorite,
      );
      notifyListeners();
      _persist();
    }
  }

  static final Set<String> _builtInIds = _defaultFilters()
      .map((f) => f.id)
      .toSet();
  bool isBuiltIn(String id) => _builtInIds.contains(id);

  void addFilter(FilterDef filter) {
    _filters.add(filter);
    _currentFilterId = filter.id;
    notifyListeners();
    _persist();
  }

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

  bool removeFilter(String id) {
    if (isBuiltIn(id)) return false;
    final idx = _filters.indexWhere((f) => f.id == id);
    if (idx < 0 || _filters[idx].isFavorite) return false;
    _filters.removeAt(idx);
    if (_currentFilterId == id) _currentFilterId = _filters.firstOrNull?.id;
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
