import '../l10n/app_localizations.dart';
import '../models/filter_def.dart';
import '../services/filter_service.dart';
import 'duplicate_name.dart';

/// A drawing filter's name in the app's language (the stored name is the
/// built-in Japanese one). A copy a transfer added (its stored name is a copy
/// name, see [copyNameParts]) shows the kind's name with the copy suffix and
/// number in the app's language, so it can be told from the filter it was
/// copied from (and is the name the import reported).
String filterDisplayName(AppLocalizations l10n, FilterDef filter) {
  final kindName = _kindName(l10n, filter);
  final copy = copyNameParts(filter.name);
  return copy == null ? kindName : copyNameIn(l10n, kindName, copy.number);
}

String _kindName(AppLocalizations l10n, FilterDef filter) {
  if (filter.id == 'Filter0025') return l10n.filterNameInvert;
  // The unified Noise tile keeps its name across all three modes.
  if (filter.id == FilterService.genericNoiseFilterId) {
    return l10n.filterNameGenericNoise;
  }
  if (filter.kind == FilterKind.noise && filter.noiseStyle == NoiseStyle.vhs) {
    return l10n.filterNameVhsNoise;
  }
  return switch (filter.kind) {
    FilterKind.prism => l10n.filterNamePrism,
    FilterKind.gaussianBlur => l10n.filterNameGaussianBlur,
    FilterKind.lensBlur => l10n.filterNameLensBlur,
    FilterKind.animeStyle => l10n.filterNameAnimeStyle,
    FilterKind.outline => l10n.filterNameOutline,
    FilterKind.toneCurve => l10n.filterNameToneCurve,
    FilterKind.levels => l10n.filterNameLevels,
    FilterKind.sharpen => l10n.filterNameSharpen,
    FilterKind.unsharpMask => l10n.filterNameUnsharpMask,
    FilterKind.vignette => l10n.filterNameVignette,
    FilterKind.noise => l10n.filterNameNoise,
    FilterKind.retroAnime => l10n.filterNameRetroAnime,
    FilterKind.crt => l10n.filterNameCrt,
    FilterKind.colorAdjust => l10n.filterNameColorAdjust,
    FilterKind.threshold => l10n.filterNameThreshold,
    FilterKind.fisheye => l10n.filterNameFisheye,
    FilterKind.chromaticAberration => l10n.filterNameChromaticAberration,
    FilterKind.lensDistortion => l10n.filterNameLensDistortion,
    FilterKind.pixelate => l10n.filterNamePixelate,
    FilterKind.mosaic => l10n.filterNameMosaic,
    FilterKind.auroraHologram => l10n.filterNameAuroraHologram,
    FilterKind.backgroundBlend => l10n.filterNameBackgroundBlend,
    FilterKind.inkPool => l10n.filterNameInkPool,
    FilterKind.autoLineart => l10n.filterNameAutoLineart,
    FilterKind.sphereShading => l10n.filterNameSphereShading,
    FilterKind.watercolorBorder => l10n.filterNameWatercolorBorder,
  };
}

/// The name of the layer a filter that draws onto a new layer (outline,
/// ink pool, auto line art) makes from the layer called [sourceName].
String generatedLayerName(
  AppLocalizations l10n,
  String sourceName,
  FilterDef filter,
) => switch (filter.kind) {
  FilterKind.outline => l10n.filterOutlineLayerNameSuffix(sourceName),
  FilterKind.inkPool => l10n.filterInkPoolLayerNameSuffix(sourceName),
  FilterKind.autoLineart => l10n.filterAutoLineartLayerNameSuffix(sourceName),
  _ => '$sourceName ${filterDisplayName(l10n, filter)}',
};

/// Whether a filter named [name] is found by the search [query]: anywhere
/// in the name, regardless of case ("blur" finds Gaussian Blur).
bool filterNameMatches(String name, String query) {
  final wanted = query.trim().toLowerCase();
  return wanted.isEmpty || name.toLowerCase().contains(wanted);
}
