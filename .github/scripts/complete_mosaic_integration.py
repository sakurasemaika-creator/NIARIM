from pathlib import Path
import re

engine = Path('lib/engine/filter_engine.dart')
s = engine.read_text()

# Keep the latest dev_branch FilterEngine architecture and only splice in the
# verified shared pixel-art behavior. Do not replace the file with the old
# feature-branch facade, because dev_branch contains newer production engines.
pixel_import = "import 'pixel_art_engine.dart';\n"
if pixel_import not in s:
    marker = "import 'prism_filter_engine.dart';\n"
    if marker not in s:
        raise SystemExit('pixel-art import marker not found')
    s = s.replace(marker, marker + pixel_import, 1)

if 'FilterKind.mosaic => engine.applyMosaic(' not in s:
    marker = '''    FilterKind.pixelate => engine.applyPixelate(
      data,
      width,
      height,
      mosaicSize: filter.strength.round().clamp(1, 64),
      colorMode: filter.pixelColorMode,
      colorLevels: filter.colorLevels,
      paletteColors: filter.pixelExplicitColors,
    ),'''
    replacement = marker + '''
    FilterKind.mosaic => engine.applyMosaic(
      data,
      width,
      height,
      filter.strength.round().clamp(1, 64),
    ),'''
    if marker not in s:
        raise SystemExit('isolate pixelate switch marker not found')
    s = s.replace(marker, replacement, 1)

if 'Uint8List applyMosaic(' not in s:
    class_end_marker = '\n  Uint8List applyNoise('
    method = '''
  /// Classic mosaic: each block becomes its arithmetic mean RGBA.
  /// This intentionally remains separate from true pixel-art conversion.
  Uint8List applyMosaic(
    Uint8List data,
    int width,
    int height,
    int mosaicSize,
  ) {
    if (width <= 0 || height <= 0 || data.length < width * height * 4) {
      return Uint8List.fromList(data);
    }
    final size = mosaicSize.clamp(1, 64);
    final out = Uint8List.fromList(data);
    for (var by = 0; by < height; by += size) {
      final yEnd = (by + size).clamp(0, height);
      for (var bx = 0; bx < width; bx += size) {
        final xEnd = (bx + size).clamp(0, width);
        var r = 0;
        var g = 0;
        var b = 0;
        var a = 0;
        var count = 0;
        for (var y = by; y < yEnd; y++) {
          for (var x = bx; x < xEnd; x++) {
            final i = (y * width + x) * 4;
            r += data[i];
            g += data[i + 1];
            b += data[i + 2];
            a += data[i + 3];
            count++;
          }
        }
        final rr = (r / count).round();
        final gg = (g / count).round();
        final bb = (b / count).round();
        final aa = (a / count).round();
        for (var y = by; y < yEnd; y++) {
          for (var x = bx; x < xEnd; x++) {
            final i = (y * width + x) * 4;
            out[i] = rr;
            out[i + 1] = gg;
            out[i + 2] = bb;
            out[i + 3] = aa;
          }
        }
      }
    }
    return out;
  }
'''
    if class_end_marker not in s:
        raise SystemExit('FilterEngine applyNoise marker not found')
    s = s.replace(class_end_marker, method + class_end_marker, 1)

# Replace the old block-average+quantize Pixel Art implementation with the
# shared contract. This preserves source alpha exactly, keeps transparent outer
# edges and horizontal/vertical boundaries crisp, and only permits a middle
# color at opaque diagonal crossings when the active palette policy allows it.
pixel_method = '''  Uint8List applyPixelate(
    Uint8List data,
    int width,
    int height, {
    int mosaicSize = 8,
    PixelColorMode colorMode = PixelColorMode.count,
    int colorLevels = 6,
    List<int> paletteColors = const [],
  }) => const PixelArtEngine().convert(
    data,
    width,
    height,
    pixelSize: mosaicSize,
    colorMode: colorMode,
    colorLevels: colorLevels,
    paletteColors: paletteColors,
  );

'''
pattern = re.compile(
    r'  Uint8List applyPixelate\(.*?\n  Uint8List applyFade\(', re.S
)
match = pattern.search(s)
if not match:
    raise SystemExit('FilterEngine applyPixelate range not found')
s = s[:match.start()] + pixel_method + '  Uint8List applyFade(' + s[match.end():]
engine.write_text(s)

panel = Path('lib/screens/canvas/widgets/filter_panel.dart')
s = panel.read_text()
if 'case FilterKind.mosaic:' not in s:
    control_marker = '''      case FilterKind.pixelate:
        return Column('''
    control_replacement = '''      case FilterKind.mosaic:
        return _paramSlider(
          l10n.filterPixelateBlockSize,
          current.strength,
          1,
          64,
          (v) => service.updateFilterParams(current.id, strength: v),
        );
      case FilterKind.pixelate:
        return Column('''
    if control_marker not in s:
        raise SystemExit('filter controls pixelate marker not found')
    s = s.replace(control_marker, control_replacement, 1)

name_marker = '      FilterKind.pixelate => l10n.filterNamePixelate,\n'
if 'FilterKind.mosaic => ' not in s:
    if name_marker not in s:
        raise SystemExit('display-name pixelate marker not found')
    s = s.replace(name_marker, name_marker + "      FilterKind.mosaic => 'モザイク',\n", 1)

icon_marker = '      FilterKind.pixelate => Icons.grid_view,\n'
if "FilterKind.mosaic => Icons.grid_on," not in s:
    if icon_marker not in s:
        raise SystemExit('icon pixelate marker not found')
    s = s.replace(icon_marker, icon_marker + '      FilterKind.mosaic => Icons.grid_on,\n', 1)

run_marker = '''      case FilterKind.pixelate:
        return _engine.applyPixelate(
          data,
          width,
          height,
          mosaicSize: filter.strength.round().clamp(1, 64),
          colorMode: filter.pixelColorMode,
          colorLevels: filter.colorLevels,
          paletteColors: filter.pixelExplicitColors,
        );'''
if 'return _engine.applyMosaic(' not in s:
    run_replacement = run_marker + '''
      case FilterKind.mosaic:
        return _engine.applyMosaic(
          data,
          width,
          height,
          filter.strength.round().clamp(1, 64),
        );'''
    if run_marker not in s:
        raise SystemExit('preview pixelate marker not found')
    s = s.replace(run_marker, run_replacement, 1)
panel.write_text(s)

service = Path('lib/services/filter_service.dart')
s = service.read_text()
if 'static const mosaicFilterId' not in s:
    s = s.replace(
        "  static const vhsNoiseFilterId = 'Filter0024';\n",
        "  static const vhsNoiseFilterId = 'Filter0024';\n  static const mosaicFilterId = 'Filter0026';\n",
        1,
    )
if "id: mosaicFilterId" not in s:
    marker = "    FilterDef(id: 'Filter0025', name: '色反転', kind: FilterKind.toneCurve, toneCurvePreset: ToneCurvePreset.invert),\n"
    addition = marker + "    FilterDef(id: mosaicFilterId, name: 'モザイク', kind: FilterKind.mosaic, strength: 8),\n"
    if marker not in s:
        raise SystemExit('FilterService tail preset marker not found')
    s = s.replace(marker, addition, 1)
service.write_text(s)
