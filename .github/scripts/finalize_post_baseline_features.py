from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if text.count(old) != 1:
        raise SystemExit(f"{path}: expected exactly one match, found {text.count(old)}\n--- OLD ---\n{old[:500]}")
    p.write_text(text.replace(old, new, 1))


# ---------------------------------------------------------------------------
# Video clip volume: persist independently from visual opacity.
# ---------------------------------------------------------------------------
replace_once(
    'lib/models/layer.dart',
    "  final int? sourceTrimStart;\n  final int? sourceTrimEnd;\n",
    "  final int? sourceTrimStart;\n  final int? sourceTrimEnd;\n  // 動画素材の音量（0.0〜1.0）。不透明度とは独立して保持する。\n  // LayerType.timelineVideoでのみ使用する。\n  final double videoVolume;\n",
)
replace_once(
    'lib/models/layer.dart',
    "    this.sourceTrimStart,\n    this.sourceTrimEnd,\n    this.watermarkAssetId,\n",
    "    this.sourceTrimStart,\n    this.sourceTrimEnd,\n    this.videoVolume = 1.0,\n    this.watermarkAssetId,\n",
)
replace_once(
    'lib/models/layer.dart',
    "    Object? sourceTrimStart = _sentinel,\n    Object? sourceTrimEnd = _sentinel,\n    Object? watermarkAssetId = _sentinel,\n",
    "    Object? sourceTrimStart = _sentinel,\n    Object? sourceTrimEnd = _sentinel,\n    double? videoVolume,\n    Object? watermarkAssetId = _sentinel,\n",
)
replace_once(
    'lib/models/layer.dart',
    "      sourceTrimEnd: sourceTrimEnd == _sentinel\n          ? this.sourceTrimEnd\n          : sourceTrimEnd as int?,\n      watermarkAssetId: watermarkAssetId == _sentinel\n",
    "      sourceTrimEnd: sourceTrimEnd == _sentinel\n          ? this.sourceTrimEnd\n          : sourceTrimEnd as int?,\n      videoVolume: videoVolume ?? this.videoVolume,\n      watermarkAssetId: watermarkAssetId == _sentinel\n",
)
replace_once(
    'lib/engine/niapro_serializer.dart',
    "    'sourceTrimStart': l.sourceTrimStart,\n    'sourceTrimEnd': l.sourceTrimEnd,\n    'watermarkAssetId': l.watermarkAssetId,\n",
    "    'sourceTrimStart': l.sourceTrimStart,\n    'sourceTrimEnd': l.sourceTrimEnd,\n    'videoVolume': l.videoVolume,\n    'watermarkAssetId': l.watermarkAssetId,\n",
)
replace_once(
    'lib/engine/niapro_serializer.dart',
    "    sourceTrimStart: j['sourceTrimStart'] as int?,\n    sourceTrimEnd: j['sourceTrimEnd'] as int?,\n    watermarkAssetId: j['watermarkAssetId'] as String?,\n",
    "    sourceTrimStart: j['sourceTrimStart'] as int?,\n    sourceTrimEnd: j['sourceTrimEnd'] as int?,\n    videoVolume: (j['videoVolume'] as num?)?.toDouble() ?? 1.0,\n    watermarkAssetId: j['watermarkAssetId'] as String?,\n",
)
replace_once(
    'lib/screens/timeline/timeline_screen.dart',
    "    await controller.setVolume(clip.videoOpacity.clamp(0.0, 1.0));\n",
    "    await controller.setVolume(clip.volume.clamp(0.0, 1.0));\n",
)
replace_once(
    'lib/screens/timeline/timeline_screen.dart',
    "        opacity: (clip.videoOpacity * 100).round(),\n        sourceTrimStart: clip.trackType == _ClipTrackType.video\n",
    "        opacity: (clip.videoOpacity * 100).round(),\n        videoVolume: clip.trackType == _ClipTrackType.video\n            ? clip.volume.clamp(0.0, 1.0)\n            : 1.0,\n        sourceTrimStart: clip.trackType == _ClipTrackType.video\n",
)
replace_once(
    'lib/screens/timeline/timeline_screen.dart',
    "      useEnd: clip.useEnd,\n      videoOpacity: clip.videoOpacity,\n      trackRow: targetRow,\n",
    "      useEnd: clip.useEnd,\n      volume: clip.volume,\n      videoOpacity: clip.videoOpacity,\n      trackRow: targetRow,\n",
)
replace_once(
    'lib/screens/timeline/timeline_screen.dart',
    "          opacity: (clip.videoOpacity * 100).round(),\n          sourceTrimStart: clip.useStart,\n          sourceTrimEnd: clip.useEnd,\n",
    "          opacity: (clip.videoOpacity * 100).round(),\n          videoVolume: clip.volume.clamp(0.0, 1.0),\n          sourceTrimStart: clip.useStart,\n          sourceTrimEnd: clip.useEnd,\n",
)
replace_once(
    'lib/screens/timeline/timeline_screen.dart',
    "          useEnd: layer.sourceTrimEnd ?? (length - 1),\n          videoOpacity: layer.opacity / 100.0,\n          trackRow: layer.trackRow,\n",
    "          useEnd: layer.sourceTrimEnd ?? (length - 1),\n          volume: layer.type == LayerType.timelineVideo\n              ? layer.videoVolume.clamp(0.0, 1.0)\n              : 1.0,\n          videoOpacity: layer.opacity / 100.0,\n          trackRow: layer.trackRow,\n",
)
replace_once(
    'lib/screens/timeline/timeline_screen.dart',
    "                if (_c.trackType == _ClipTrackType.video) ...[\n                  _row(\n                    l10n.layerPanelOpacityLabel,\n",
    "                if (_c.trackType == _ClipTrackType.video) ...[\n                  _row(\n                    l10n.timelineClipVolumeLabel,\n                    _c.volume,\n                    0,\n                    1,\n                    100,\n                    (v) {\n                      _c.volume = v;\n                      _notify();\n                    },\n                    '${(_c.volume * 100).round()}%',\n                    step: 0.01,\n                  ),\n                  _row(\n                    l10n.layerPanelOpacityLabel,\n",
)

# ---------------------------------------------------------------------------
# Text body/outline arbitrary color chips + canvas eyedropper.
# The draft is materialized as a temporary TextObject only; no project data is
# committed until the normal Apply button is pressed.
# ---------------------------------------------------------------------------
replace_once(
    'lib/screens/canvas/canvas_screen.dart',
    "  FilterColorEyedropperTarget? _filterColorEyedropperTarget;\n",
    "  FilterColorEyedropperTarget? _filterColorEyedropperTarget;\n  _TextColorEyedropperTarget? _textColorEyedropperTarget;\n  ValueChanged<Color>? _pendingTextColorEyedropper;\n",
)
replace_once(
    'lib/screens/canvas/canvas_screen.dart',
    "  void _handleCanvasEyedropper(Color color) {\n    final target = _filterColorEyedropperTarget;\n",
    "  void _handleCanvasEyedropper(Color color) {\n    final textTarget = _textColorEyedropperTarget;\n    final pendingText = _pendingTextColorEyedropper;\n    if (textTarget != null && pendingText != null) {\n      setState(() {\n        _textColorEyedropperTarget = null;\n        _pendingTextColorEyedropper = null;\n      });\n      pendingText(color);\n      return;\n    }\n    final target = _filterColorEyedropperTarget;\n",
)
replace_once(
    'lib/screens/canvas/canvas_screen.dart',
    "  String _filterEyedropperHint(BuildContext context) {\n    final l10n = AppLocalizations.of(context)!;\n    return _filterColorEyedropperTarget == FilterColorEyedropperTarget.inkPool\n        ? l10n.filterInkPoolEyedropperHint\n        : l10n.filterOutlineEyedropperHint;\n  }\n",
    "  String _activeColorEyedropperHint(BuildContext context) {\n    final l10n = AppLocalizations.of(context)!;\n    if (_textColorEyedropperTarget != null) {\n      return l10n.filterCanvasEyedropperTooltip;\n    }\n    return _filterColorEyedropperTarget == FilterColorEyedropperTarget.inkPool\n        ? l10n.filterInkPoolEyedropperHint\n        : l10n.filterOutlineEyedropperHint;\n  }\n",
)
replace_once(
    'lib/screens/canvas/canvas_screen.dart',
    "                                  filterEyedropperActive:\n                                      _filterColorEyedropperTarget != null,\n",
    "                                  filterEyedropperActive:\n                                      _filterColorEyedropperTarget != null ||\n                                      _textColorEyedropperTarget != null,\n",
)
replace_once(
    'lib/screens/canvas/canvas_screen.dart',
    "                                if (_filterColorEyedropperTarget != null)\n",
    "                                if (_filterColorEyedropperTarget != null ||\n                                    _textColorEyedropperTarget != null)\n",
)
replace_once(
    'lib/screens/canvas/canvas_screen.dart',
    "                                                    _filterEyedropperHint(\n                                                      context,\n                                                    ),\n",
    "                                                    _activeColorEyedropperHint(\n                                                      context,\n                                                    ),\n",
)
replace_once(
    'lib/screens/canvas/canvas_screen.dart',
    "    final l10n = AppLocalizations.of(context)!;\n    showDialog(\n",
    "    final l10n = AppLocalizations.of(context)!;\n\n    model.TextObject textDraft() {\n      final base =\n          existing ??\n          model.TextObject(\n            id: '__text_color_draft__',\n            text: controller.text,\n            position: position,\n          );\n      return base.copyWith(\n        text: controller.text,\n        fontSize: fontSize,\n        color: Color(color),\n        isBold: isBold,\n        isItalic: isItalic,\n        fontFamily: fontFamily,\n        lineHeight: lineHeight,\n        letterSpacing: letterSpacing,\n        align: textAlign,\n        direction: direction,\n        outline: model.TextOutline(\n          enabled: outlineEnabled,\n          color: Color(outlineColor),\n          width: outlineWidth,\n        ),\n      );\n    }\n\n    void startTextCanvasEyedropper(\n      _TextColorEyedropperTarget target,\n      BuildContext dialogContext,\n    ) {\n      final draft = textDraft();\n      Navigator.of(dialogContext).pop();\n      setState(() {\n        _textColorEyedropperTarget = target;\n        _pendingTextColorEyedropper = (picked) {\n          final next = target == _TextColorEyedropperTarget.body\n              ? draft.copyWith(color: picked)\n              : draft.copyWith(\n                  outline: model.TextOutline(\n                    enabled: true,\n                    color: picked,\n                    width: draft.outline?.width ?? outlineWidth,\n                  ),\n                );\n          WidgetsBinding.instance.addPostFrameCallback((_) {\n            if (!mounted) return;\n            _showTextInputDialog(\n              position,\n              existingLayerId: existingLayerId,\n              existing: next,\n            );\n          });\n        };\n      });\n    }\n\n    Future<void> pickTextColor(\n      BuildContext dialogContext,\n      int current,\n      ValueChanged<int> onChanged,\n    ) async {\n      await showDialog<void>(\n        context: dialogContext,\n        builder: (pickerContext) => Dialog(\n          child: ConstrainedBox(\n            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),\n            child: ColorPickerPanel(\n              currentColor: Color(current),\n              onColorChanged: (picked) {\n                onChanged(picked.toARGB32());\n                Navigator.of(pickerContext).pop();\n              },\n            ),\n          ),\n        ),\n      );\n    }\n\n    showDialog(\n",
)
# Body current-color chip and eyedropper before the quick palette.
replace_once(
    'lib/screens/canvas/canvas_screen.dart',
    "                  const SizedBox(height: 8),\n                  Wrap(\n                    spacing: 6,\n                    children: _textColorPalette\n",
    "                  const SizedBox(height: 8),\n                  Row(\n                    children: [\n                      GestureDetector(\n                        onTap: () => pickTextColor(\n                          ctx,\n                          color,\n                          (v) => setS(() => color = v),\n                        ),\n                        child: Container(\n                          width: 34,\n                          height: 34,\n                          decoration: BoxDecoration(\n                            color: Color(color),\n                            shape: BoxShape.circle,\n                            border: Border.all(\n                              color: Theme.of(ctx).colorScheme.outline,\n                              width: 2,\n                            ),\n                          ),\n                        ),\n                      ),\n                      const SizedBox(width: 6),\n                      IconButton(\n                        icon: const Icon(Icons.colorize),\n                        tooltip: l10n.toolbarItemEyedropper,\n                        onPressed: () => startTextCanvasEyedropper(\n                          _TextColorEyedropperTarget.body,\n                          ctx,\n                        ),\n                      ),\n                    ],\n                  ),\n                  const SizedBox(height: 4),\n                  Wrap(\n                    spacing: 6,\n                    children: _textColorPalette\n",
)
# Outline current-color chip and eyedropper before the outline quick palette.
replace_once(
    'lib/screens/canvas/canvas_screen.dart',
    "                  if (outlineEnabled) ...[\n                    const SizedBox(height: 4),\n                    Wrap(\n",
    "                  if (outlineEnabled) ...[\n                    const SizedBox(height: 4),\n                    Row(\n                      children: [\n                        GestureDetector(\n                          onTap: () => pickTextColor(\n                            ctx,\n                            outlineColor,\n                            (v) => setS(() => outlineColor = v),\n                          ),\n                          child: Container(\n                            width: 30,\n                            height: 30,\n                            decoration: BoxDecoration(\n                              color: Color(outlineColor),\n                              shape: BoxShape.circle,\n                              border: Border.all(\n                                color: Theme.of(ctx).colorScheme.outline,\n                                width: 2,\n                              ),\n                            ),\n                          ),\n                        ),\n                        const SizedBox(width: 6),\n                        IconButton(\n                          icon: const Icon(Icons.colorize),\n                          tooltip: l10n.toolbarItemEyedropper,\n                          onPressed: () => startTextCanvasEyedropper(\n                            _TextColorEyedropperTarget.outline,\n                            ctx,\n                          ),\n                        ),\n                      ],\n                    ),\n                    const SizedBox(height: 4),\n                    Wrap(\n",
)
replace_once(
    'lib/screens/canvas/canvas_screen.dart',
    "enum DrawingTool {\n",
    "enum _TextColorEyedropperTarget { body, outline }\n\nenum DrawingTool {\n",
)

# Dedicated source/model contract tests for the two newly completed items.
Path('test/post_baseline_remaining_contract_test.dart').write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/layer.dart';

void main() {
  test('timeline video volume is independent from opacity and survives copyWith', () {
    const layer = Layer(
      id: 'video',
      name: 'video',
      type: LayerType.timelineVideo,
      opacity: 25,
      videoVolume: 0.72,
    );
    expect(layer.opacity, 25);
    expect(layer.videoVolume, closeTo(0.72, 1e-9));
    final changed = layer.copyWith(opacity: 80, videoVolume: 0.18);
    expect(changed.opacity, 80);
    expect(changed.videoVolume, closeTo(0.18, 1e-9));
  });

  test('timeline UI and playback use clip.volume for video audio', () {
    final source = File('lib/screens/timeline/timeline_screen.dart').readAsStringSync();
    expect(source, contains('controller.setVolume(clip.volume.clamp(0.0, 1.0))'));
    expect(source, isNot(contains('controller.setVolume(clip.videoOpacity')));
    final videoBranch = source.substring(source.indexOf('if (_c.trackType == _ClipTrackType.video)'));
    expect(videoBranch, contains('l10n.timelineClipVolumeLabel'));
    expect(videoBranch, contains('_c.volume = v'));
    expect(source, contains('videoVolume: clip.volume.clamp(0.0, 1.0)'));
    expect(source, contains('volume: layer.type == LayerType.timelineVideo'));
  });

  test('text body and outline expose current-color chips and canvas eyedropper', () {
    final source = File('lib/screens/canvas/canvas_screen.dart').readAsStringSync();
    expect(source, contains('_TextColorEyedropperTarget.body'));
    expect(source, contains('_TextColorEyedropperTarget.outline'));
    expect(source, contains('startTextCanvasEyedropper'));
    expect(source, contains('pickTextColor'));
    expect(source, contains('_pendingTextColorEyedropper'));
    expect(source, contains('existing: next'));
    expect(source, contains('_textColorEyedropperTarget != null'));
  });

  test('project serialization stores videoVolume with backward-compatible default', () {
    final source = File('lib/engine/niapro_serializer.dart').readAsStringSync();
    expect(source, contains("'videoVolume': l.videoVolume"));
    expect(source, contains("(j['videoVolume'] as num?)?.toDouble() ?? 1.0"));
  });
}
''')
