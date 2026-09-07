from pathlib import Path

p = Path('lib/screens/canvas/widgets/filter_panel.dart')
s = p.read_text(encoding='utf-8')

# Engine import.
imp = "import '../../../engine/auto_lineart_engine.dart';\n"
if imp not in s:
    marker = "import '../../../engine/background_acclimation_engine.dart';\n"
    if marker not in s:
        raise SystemExit('background engine import anchor missing')
    s = s.replace(marker, marker + imp, 1)

# Transient vector-like preview cache. Nothing here becomes a project layer.
if 'AutoLineartGraph? _autoLineartPreviewGraph;' not in s:
    marker = '  BackgroundAcclimationAnalysis? _lastBgBlendAnalysis;\n'
    if marker not in s:
        raise SystemExit('preview state anchor missing')
    s = s.replace(
        marker,
        marker
        + '  AutoLineartGraph? _autoLineartPreviewGraph;\n'
        + '  double? _autoLineartPreviewRoughWidth;\n',
        1,
    )

# Preview: analyze only when rough-width changes, otherwise re-render cached paths.
preview_new = '''    final Uint8List filtered;\n    if (filter.kind == FilterKind.autoLineart) {\n      if (_autoLineartPreviewGraph == null ||\n          _autoLineartPreviewRoughWidth != filter.autoLineartRoughWidth) {\n        _autoLineartPreviewGraph = AutoLineartEngine.analyze(\n          base,\n          _previewW,\n          _previewH,\n          roughWidthPx: math.max(2.0, filter.autoLineartRoughWidth * _previewScale),\n        );\n        _autoLineartPreviewRoughWidth = filter.autoLineartRoughWidth;\n      }\n      filtered = AutoLineartEngine.render(\n        _autoLineartPreviewGraph!,\n        _previewW,\n        _previewH,\n        outputWidthPx:\n            math.max(1.0, filter.autoLineartOutputWidth * _previewScale),\n        taperLengthPx: filter.autoLineartTaperLength * _previewScale,\n        smoothing: filter.autoLineartSmoothing,\n      );\n    } else {\n      filtered = _runFilter(filter, base, _previewW, _previewH);\n    }\n'''
if preview_new not in s:
    old = '    final filtered = _runFilter(filter, base, _previewW, _previewH);\n'
    if old not in s:
        raise SystemExit('preview filter assignment missing')
    s = s.replace(old, preview_new, 1)

# Controls: scope to _buildControls so another FilterKind switch cannot steal the
# insertion. Smoothing is intentionally 0..100 and has no px suffix.
controls_start = s.index('  Widget _buildControls(')
controls_end = s.index('\n  String _filterDisplayName', controls_start)
controls_region = s[controls_start:controls_end]
if 'case FilterKind.autoLineart:' not in controls_region:
    marker = '      case FilterKind.inkPool:\n'
    pos = controls_region.find(marker)
    if pos < 0:
        raise SystemExit('inkPool control case missing')
    addition = '''      case FilterKind.autoLineart:\n        return Column(\n          children: [\n            _integerStepperSlider(\n              l10n.filterAutoLineartRoughWidth,\n              current.autoLineartRoughWidth.round(),\n              2,\n              80,\n              (v) {\n                service.updateFilterParams(\n                  current.id,\n                  autoLineartRoughWidth: v.toDouble(),\n                );\n                _autoLineartPreviewGraph = null;\n                _autoLineartPreviewRoughWidth = null;\n                _updatePreview();\n              },\n              suffix: 'px',\n            ),\n            _integerStepperSlider(\n              l10n.filterAutoLineartOutputWidth,\n              current.autoLineartOutputWidth.round(),\n              1,\n              30,\n              (v) {\n                service.updateFilterParams(\n                  current.id,\n                  autoLineartOutputWidth: v.toDouble(),\n                );\n                _updatePreview();\n              },\n              suffix: 'px',\n            ),\n            _integerStepperSlider(\n              l10n.filterAutoLineartTaperLength,\n              current.autoLineartTaperLength.round(),\n              0,\n              100,\n              (v) {\n                service.updateFilterParams(\n                  current.id,\n                  autoLineartTaperLength: v.toDouble(),\n                );\n                _updatePreview();\n              },\n              suffix: 'px',\n            ),\n            _integerStepperSlider(\n              l10n.filterAutoLineartSmoothing,\n              current.autoLineartSmoothing.round(),\n              0,\n              100,\n              (v) {\n                service.updateFilterParams(\n                  current.id,\n                  autoLineartSmoothing: v.toDouble(),\n                );\n                _updatePreview();\n              },\n            ),\n          ],\n        );\n'''
    controls_region = controls_region[:pos] + addition + controls_region[pos:]
    s = s[:controls_start] + controls_region + s[controls_end:]

p.write_text(s, encoding='utf-8')
print('auto-lineart panel import/cache/preview/controls completed')
