import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/filter_def.dart';
import '../models/pixel_color_mode.dart';

class FilterService extends ChangeNotifier {
  static const _prefsKey = 'draw_filters';
  static const prismFilterId = 'Filter0022';
  static const vhsNoiseFilterId = 'Filter0024';
  static const mosaicFilterId = 'Filter0026';
  static const genericNoiseFilterId = 'Filter0027';

  final List<FilterDef> _filters = [];
  String? _currentFilterId;
  String _searchQuery = '';
  bool _favoritesOnly = false;
  final List<FilterDef> _filterEditUndo = [];
  final List<FilterDef> _filterEditRedo = [];
  int _editGroupDepth = 0;
  bool _editGroupRecorded = false;

  List<FilterDef> get filters => List.unmodifiable(_filters);
  FilterDef? get currentFilter =>
      _filters.where((f) => f.id == _currentFilterId).firstOrNull;
  String get searchQuery => _searchQuery;
  bool get favoritesOnly => _favoritesOnly;
  bool get canUndoFilterEdit => _filterEditUndo.isNotEmpty;
  bool get canRedoFilterEdit => _filterEditRedo.isNotEmpty;

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
      strength: 50,
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
      colorLevels: 6,
      pixelExplicitColors: [
        0xFF000000,
        0xFFFFFFFF,
        0xFFFF0000,
        0xFFFFFF00,
        0xFF0000FF,
        0xFF00FF00,
      ],
    ),
    FilterDef(
      id: 'Filter0019',
      name: '質感変更フィルター',
      kind: FilterKind.auroraHologram,
      strength: 100,
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
    FilterDef(
      id: prismFilterId,
      name: 'プリズム',
      kind: FilterKind.prism,
      prismBlurPx: 17,
      prismDirectionDegrees: 90,
    ),
    FilterDef(
      id: vhsNoiseFilterId,
      name: 'VHSノイズ',
      kind: FilterKind.noise,
      noiseStyle: NoiseStyle.vhs,
      strength: 35,
      caSaturation: 35,
      caBrightness: 35,
      caContrast: 25,
      thresholdValue: 1984,
    ),
    FilterDef(
      id: 'Filter0025',
      name: '色反転',
      kind: FilterKind.toneCurve,
      toneCurvePreset: ToneCurvePreset.invert,
    ),
    FilterDef(
      id: mosaicFilterId,
      name: 'モザイク',
      kind: FilterKind.mosaic,
      strength: 8,
    ),
    FilterDef(
      id: genericNoiseFilterId,
      name: 'ノイズ',
      kind: FilterKind.noise,
      noiseStyle: NoiseStyle.color,
      strength: 15,
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
      final stored = raw
          .map((s) => jsonDecode(s) as Map<String, dynamic>)
          .toList();
      // A filter kind that has been removed from the app is dropped rather
      // than shown as some other filter under its old name.
      final known = stored.where(FilterDef.hasKnownKind).toList();
      var migratedFilterState = known.length != stored.length;
      _filters.addAll(
        known.map((json) {
          var filter = FilterDef.fromJson(json);
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
              migratedFilterState = true;
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
            migratedFilterState = true;
          }
          return filter;
        }),
      );
      final existingIds = _filters.map((f) => f.id).toSet();
      final missing = _defaultFilters().where(
        (f) => !existingIds.contains(f.id),
      );
      if (missing.isNotEmpty) _filters.addAll(missing);
      if (missing.isNotEmpty || migratedFilterState) await _persist();
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
    _filterEditUndo.clear();
    _filterEditRedo.clear();
    notifyListeners();
  }

  void clearCurrentFilter() {
    if (_currentFilterId == null) return;
    _currentFilterId = null;
    notifyListeners();
  }

  void updateFilterParams(
    String id, {
    double? strength,
    NoiseStyle? noiseStyle,
    int? noiseSeed,
    int? colorLevels,
    double? edgeStrength,
    int? inputBlack,
    int? inputWhite,
    double? inputGamma,
    int? outputBlack,
    int? outputWhite,
    List<double>? levelsRed,
    List<double>? levelsGreen,
    List<double>? levelsBlue,
    ToneCurvePreset? toneCurvePreset,
    List<double>? toneCurvePoints,
    List<double>? toneCurveRedPoints,
    List<double>? toneCurveGreenPoints,
    List<double>? toneCurveBluePoints,
    int? outlineColor,
    double? outlineWidth,
    int? vignetteColor,
    double? caSaturation,
    double? caBrightness,
    double? caContrast,
    double? thresholdValue,
    double? lensCenterOffsetX,
    double? lensCenterOffsetY,
    double? fisheyeRadius,
    double? fisheyeCenterX,
    double? fisheyeCenterY,
    double? chromaticShiftX,
    double? chromaticShiftY,
    double? chromaticShiftZ,
    PixelColorMode? pixelColorMode,
    List<int>? pixelExplicitColors,
    bool? pixelArtMatchCanvas,
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
    final before = _filters[idx];
    final after = before.copyWith(
      strength: strength,
      noiseStyle: noiseStyle,
      noiseSeed: noiseSeed,
      colorLevels: colorLevels,
      edgeStrength: edgeStrength,
      inputBlack: inputBlack,
      inputWhite: inputWhite,
      inputGamma: inputGamma,
      outputBlack: outputBlack,
      outputWhite: outputWhite,
      levelsRed: levelsRed,
      levelsGreen: levelsGreen,
      levelsBlue: levelsBlue,
      toneCurvePreset: toneCurvePreset,
      toneCurvePoints: toneCurvePoints,
      toneCurveRedPoints: toneCurveRedPoints,
      toneCurveGreenPoints: toneCurveGreenPoints,
      toneCurveBluePoints: toneCurveBluePoints,
      outlineColor: outlineColor,
      outlineWidth: outlineWidth,
      vignetteColor: vignetteColor,
      caSaturation: caSaturation,
      caBrightness: caBrightness,
      caContrast: caContrast,
      thresholdValue: thresholdValue,
      lensCenterOffsetX: lensCenterOffsetX,
      lensCenterOffsetY: lensCenterOffsetY,
      fisheyeRadius: fisheyeRadius,
      fisheyeCenterX: fisheyeCenterX,
      fisheyeCenterY: fisheyeCenterY,
      chromaticShiftX: chromaticShiftX,
      chromaticShiftY: chromaticShiftY,
      chromaticShiftZ: chromaticShiftZ,
      pixelColorMode: pixelColorMode,
      pixelExplicitColors: pixelExplicitColors,
      pixelArtMatchCanvas: pixelArtMatchCanvas,
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
    if (jsonEncode(after.toJson()) == jsonEncode(before.toJson())) return;
    // Inside an edit group (one drag) only the first change is recorded, so
    // Undo takes the whole drag back in one step.
    if (_editGroupDepth == 0 || !_editGroupRecorded) {
      _filterEditUndo.add(before);
      if (_filterEditUndo.length > 100) _filterEditUndo.removeAt(0);
      _filterEditRedo.clear();
      _editGroupRecorded = _editGroupDepth > 0;
    }
    _filters[idx] = after;
    notifyListeners();
    _persist();
  }

  /// Starts a run of edits (a drag on a slider or a curve) that Undo takes
  /// back in one step. Calls nest; every call needs an [endFilterEditGroup].
  void beginFilterEditGroup() {
    if (_editGroupDepth++ == 0) _editGroupRecorded = false;
  }

  void endFilterEditGroup() {
    if (_editGroupDepth > 0) _editGroupDepth--;
  }

  void undoFilterEdit() {
    final id = _currentFilterId;
    if (id == null || _filterEditUndo.isEmpty) return;
    final idx = _filters.indexWhere((f) => f.id == id);
    if (idx < 0) return;
    _filterEditRedo.add(_filters[idx]);
    _filters[idx] = _filterEditUndo.removeLast();
    notifyListeners();
    _persist();
  }

  void redoFilterEdit() {
    final id = _currentFilterId;
    if (id == null || _filterEditRedo.isEmpty) return;
    final idx = _filters.indexWhere((f) => f.id == id);
    if (idx < 0) return;
    _filterEditUndo.add(_filters[idx]);
    _filters[idx] = _filterEditRedo.removeLast();
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
