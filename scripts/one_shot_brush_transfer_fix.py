#!/usr/bin/env python3
"""Apply the remaining audited brush/stamp/transfer wiring fixes exactly once.

Every replacement is guarded by an expected match count so this script fails instead
of silently editing an unexpected code shape. The one-shot CI formats/tests the result
before it is committed to dev_branch.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write(path: str, text: str) -> None:
    (ROOT / path).write_text(text, encoding="utf-8", newline="\n")


def replace_once(path: str, old: str, new: str) -> None:
    text = read(path)
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{path}: expected one literal match, found {count}")
    write(path, text.replace(old, new, 1))
    print(f"patched {path}")


def regex_once(path: str, pattern: str, replacement: str, flags: int = re.S) -> None:
    text = read(path)
    new_text, count = re.subn(pattern, replacement, text, count=1, flags=flags)
    if count != 1:
        raise RuntimeError(f"{path}: expected one regex match, found {count}")
    write(path, new_text)
    print(f"patched {path}")


def replace_all_checked(path: str, old: str, new: str, allowed_counts: set[int]) -> None:
    text = read(path)
    count = text.count(old)
    if count not in allowed_counts:
        raise RuntimeError(
            f"{path}: expected literal match count in {sorted(allowed_counts)}, found {count}"
        )
    write(path, text.replace(old, new))
    print(f"patched {path} ({count} occurrences)")


# ---------------------------------------------------------------------------
# Stamp opacity: Model/UI already expose the value, but it was not connected to
# actual compositing. Multiply the texture's intrinsic alpha by the setting.
# ---------------------------------------------------------------------------
STAMP = "lib/engine/stamp_engine.dart"
text = read(STAMP)
old = """      double scatter,\n      double density,\n    }) args) {"""
new = """      double scatter,\n      double density,\n      int opacity,\n    }) args) {"""
if text.count(old) != 1:
    raise RuntimeError(f"{STAMP}: isolate record shape changed")
text = text.replace(old, new, 1)
old = """    scatter: args.scatter,\n    density: args.density,\n  );"""
new = """    scatter: args.scatter,\n    density: args.density,\n    opacity: args.opacity,\n  );"""
if text.count(old) != 1:
    raise RuntimeError(f"{STAMP}: isolate forwarding shape changed")
text = text.replace(old, new, 1)
old = """    double density = 1.0,\n    int seed = 0,"""
new = """    double density = 1.0,\n    int opacity = 100,\n    int seed = 0,"""
if text.count(old) != 1:
    raise RuntimeError(f"{STAMP}: stampAlongPath signature changed")
text = text.replace(old, new, 1)
old = """        stampSize,\n        stampAngle,\n      );"""
new = """        stampSize,\n        stampAngle,\n        opacity,\n      );"""
if text.count(old) != 1:
    raise RuntimeError(f"{STAMP}: _blitStamp call changed")
text = text.replace(old, new, 1)
old = """    double size,\n    double angle,\n  ) {"""
new = """    double size,\n    double angle,\n    int opacity,\n  ) {"""
if text.count(old) != 1:
    raise RuntimeError(f"{STAMP}: _blitStamp signature changed")
text = text.replace(old, new, 1)
old = """        final ta = tex[tIdx + 3];\n        if (ta == 0) continue;"""
new = """        final ta = (tex[tIdx + 3] * opacity.clamp(1, 100) / 100.0)\n            .round()\n            .clamp(0, 255);\n        if (ta == 0) continue;"""
if text.count(old) != 1:
    raise RuntimeError(f"{STAMP}: texture alpha sampling changed")
text = text.replace(old, new, 1)
write(STAMP, text)
print(f"patched {STAMP}")

replace_all_checked(
    "lib/screens/canvas/widgets/canvas_area.dart",
    """      density: stamp.density,\n    ));""",
    """      density: stamp.density,\n      opacity: stamp.opacity,\n    ));""",
    {1, 2},
)

# ---------------------------------------------------------------------------
# Brush settings UI.
# ---------------------------------------------------------------------------
PANEL = "lib/screens/canvas/widgets/brush_panel.dart"
replace_once(
    PANEL,
    """          // ぼかし半径（0〜100・デフォルト0）\n          _sliderRow(l10n.brushSettingsBlurRadiusLabel, _brush.blurRadius.toDouble(), 0, 100,\n              (v) => setState(() => _brush = _brush.copyWith(blurRadius: v.round()))),\n          const Divider(),\n          // 手ブレ補正""",
    """          // ぼかし半径（0〜100・デフォルト0）\n          _sliderRow(l10n.brushSettingsBlurRadiusLabel, _brush.blurRadius.toDouble(), 0, 100,\n              (v) => setState(() => _brush = _brush.copyWith(blurRadius: v.round()))),\n          const Divider(),\n          // 回転・密度・散布（スタンプと同じ意味／範囲）\n          SwitchListTile(\n            title: Text(l10n.stampRotationLabel),\n            value: _brush.rotation,\n            onChanged: (v) => setState(() => _brush = _brush.copyWith(rotation: v)),\n          ),\n          _decimalSliderRow(\n            l10n.stampDensityLabel,\n            _brush.density,\n            0.1,\n            5.0,\n            0.1,\n            (v) => setState(() => _brush = _brush.copyWith(density: v)),\n          ),\n          _decimalSliderRow(\n            l10n.stampScatterLabel,\n            _brush.scatter,\n            0.0,\n            1.0,\n            0.01,\n            (v) => setState(() => _brush = _brush.copyWith(scatter: v)),\n          ),\n          const Divider(),\n          // 手ブレ補正""",
)
replace_once(
    PANEL,
    """  String _pressureLabel(AppLocalizations l10n, PressureMode mode) => switch (mode) {""",
    """  Widget _decimalSliderRow(\n    String label,\n    double value,\n    double min,\n    double max,\n    double step,\n    ValueChanged<double> onChanged,\n  ) {\n    return Row(\n      children: [\n        SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 12))),\n        Expanded(\n          child: SteppedSlider(\n            min: min,\n            max: max,\n            value: value.clamp(min, max),\n            step: step,\n            onChanged: onChanged,\n          ),\n        ),\n        SizedBox(\n          width: 40,\n          child: EditableSliderValue(\n            text: value.toStringAsFixed(step < 0.1 ? 2 : 1),\n            style: const TextStyle(fontSize: 12),\n            value: value,\n            min: min,\n            max: max,\n            isInt: false,\n            onChanged: (v) => onChanged(v.toDouble()),\n          ),\n        ),\n      ],\n    );\n  }\n\n  String _pressureLabel(AppLocalizations l10n, PressureMode mode) => switch (mode) {""",
)

# .niabrush import must preserve all model settings.
regex_once(
    "lib/services/brush_service.dart",
    r"    // customImagePathは元端末のパスをそのまま引き継げないため、copyWith[\s\S]*?    addBrush\(brush\);",
    """    // 元端末固有のID・フォルダ・画像パスだけ差し替え、それ以外の\n    // rotation/density/scatter/fade/edgeJitter/pixelColor等は全て保持する。\n    final restoredJson = Map<String, dynamic>.from(imported.toJson())\n      ..['id'] = id\n      ..['folderId'] = null\n      ..['customImagePath'] = newImagePath;\n    final brush = Brush.fromJson(restoredJson);\n    addBrush(brush);""",
)

# Base .niatra serializer also preserves complete model JSON.
NIATRA = "lib/engine/niatra_serializer.dart"
replace_once(NIATRA, "import '../models/pixel_color_mode.dart';\n", "")
regex_once(
    NIATRA,
    r"  static Map<String, dynamic> _serializeBrush\(Brush b\) => \{[\s\S]*?\n      \);\n\n  // ─── Tone / Stamp",
    """  static Map<String, dynamic> _serializeBrush(Brush b) => b.toJson();\n\n  static Brush _deserializeBrush(Map<String, dynamic> j) {\n    final json = Map<String, dynamic>.from(j)\n      ..['id'] = 'Brush${DateTime.now().microsecondsSinceEpoch}_${j['id']}'\n      ..['folderId'] = null;\n    return Brush.fromJson(json);\n  }\n\n  // ─── Tone / Stamp""",
)
regex_once(
    NIATRA,
    r"  static Map<String, dynamic> _serializeTone\(Tone t\) =>[\s\S]*?\n      \);\n\n  // ─── AutofillPreset",
    """  static Map<String, dynamic> _serializeTone(Tone t) => t.toJson();\n\n  static Tone _deserializeTone(Map<String, dynamic> j) {\n    final json = Map<String, dynamic>.from(j)\n      ..['id'] = 'Tone${DateTime.now().microsecondsSinceEpoch}_${j['id']}'\n      ..['folderId'] = null;\n    return Tone.fromJson(json);\n  }\n\n  static Map<String, dynamic> _serializeStamp(Stamp s) => s.toJson();\n\n  static Stamp _deserializeStamp(Map<String, dynamic> j) {\n    final json = Map<String, dynamic>.from(j)\n      ..['id'] = 'Stamp${DateTime.now().microsecondsSinceEpoch}_${j['id']}'\n      ..['folderId'] = null;\n    return Stamp.fromJson(json);\n  }\n\n  // ─── AutofillPreset""",
)

print("all guarded patches applied")
