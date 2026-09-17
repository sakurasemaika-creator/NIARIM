from pathlib import Path
import json

ROOT = Path('.')

# Add localization keys to every ARB without rewriting unrelated values.
translations = {
    'ja': ['横方向反復','横方向反復個数','横方向間隔','縁取り','縁取り幅','縁取り色','カラーピッカー','スポイト','折り返し','発生角度','Y字枝分かれ角度','Y字長さ','Y字太さ','Y字終点入り抜き'],
    'en': ['Lateral repeat','Repeat count','Lateral spacing','Outline','Outline width','Outline color','Color picker','Eyedropper','Fold','Trigger angle','Y-branch angle','Y-branch length','Y-branch width','Y-branch end taper'],
    'es': ['Repetición lateral','Cantidad de repeticiones','Espaciado lateral','Contorno','Ancho del contorno','Color del contorno','Selector de color','Cuentagotas','Pliegue','Ángulo de activación','Ángulo de rama Y','Longitud de rama Y','Ancho de rama Y','Atenuación final de rama Y'],
    'fr': ['Répétition latérale','Nombre de répétitions','Espacement latéral','Contour','Largeur du contour','Couleur du contour','Sélecteur de couleur','Pipette','Repli','Angle de déclenchement','Angle de branche Y','Longueur de branche Y','Largeur de branche Y','Effilage final de branche Y'],
    'ko': ['가로 반복','반복 개수','가로 간격','외곽선','외곽선 두께','외곽선 색상','색상 선택기','스포이드','접힘','발생 각도','Y자 가지 각도','Y자 길이','Y자 두께','Y자 끝 테이퍼'],
    'zh': ['横向重复','重复数量','横向间距','描边','描边宽度','描边颜色','颜色选择器','吸管','折返','触发角度','Y形分支角度','Y形分支长度','Y形分支宽度','Y形分支末端渐细'],
}
keys = ['brushLateralRepeat','brushLateralRepeatCount','brushLateralRepeatSpacing','brushOutline','brushOutlineWidth','brushOutlineColor','brushOutlineColorPicker','brushOutlineEyedropper','brushFold','brushFoldTriggerAngle','brushYBranchAngle','brushYBranchLength','brushYBranchWidth','brushYBranchEndTaper']
for arb in (ROOT / 'lib/l10n').glob('app_*.arb'):
    locale = arb.stem.removeprefix('app_')
    base = locale.split('_')[0]
    if base not in translations:
        continue
    data = json.loads(arb.read_text())
    for key, value in zip(keys, translations[base]):
        data[key] = value
    arb.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')

# Wire generated AppLocalizations into the extension labels.
p = ROOT / 'lib/screens/canvas/widgets/brush_extension_settings.dart'
s = p.read_text()
if "../../../l10n/app_localizations.dart" not in s:
    s = s.replace("import 'package:flutter/material.dart';\n", "import 'package:flutter/material.dart';\n\nimport '../../../l10n/app_localizations.dart';\n", 1)
needle = "  const BrushExtensionLabels.japanese()\n"
if 'BrushExtensionLabels.fromLocalizations' not in s:
    insert = """  factory BrushExtensionLabels.fromLocalizations(AppLocalizations l) =>\n      BrushExtensionLabels(\n        lateralRepeat: l.brushLateralRepeat,\n        lateralRepeatCount: l.brushLateralRepeatCount,\n        lateralRepeatSpacing: l.brushLateralRepeatSpacing,\n        outline: l.brushOutline,\n        outlineWidth: l.brushOutlineWidth,\n        outlineColor: l.brushOutlineColor,\n        colorPicker: l.brushOutlineColorPicker,\n        eyedropper: l.brushOutlineEyedropper,\n        fold: l.brushFold,\n        foldTriggerAngle: l.brushFoldTriggerAngle,\n        yBranchAngle: l.brushYBranchAngle,\n        yBranchLength: l.brushYBranchLength,\n        yBranchWidth: l.brushYBranchWidth,\n        yBranchEndTaper: l.brushYBranchEndTaper,\n      );\n\n"""
    if needle not in s:
        raise SystemExit('labels insertion marker missing')
    s = s.replace(needle, insert + needle, 1)
p.write_text(s)

# Connect the extension settings to the existing brush settings sheet. Color
# actions are passed through callbacks so the canvas owner can provide the
# existing picker/eyedropper implementation without creating a second global color.
p = ROOT / 'lib/screens/canvas/widgets/brush_panel.dart'
s = p.read_text()
if "brush_extension_settings.dart" not in s:
    anchor = "import '../../../services/brush_service.dart';\n"
    s = s.replace(anchor, anchor + "import 'brush_extension_settings.dart';\n", 1)

# Add optional callbacks at panel boundary, preserving all existing call sites.
field_anchor = '  final VoidCallback? onClose;\n'
if 'onPickOutlineColor' not in s:
    s = s.replace(field_anchor, field_anchor + '  final Future<int?> Function(int currentColor)? onPickOutlineColor;\n  final Future<int?> Function(int currentColor)? onEyedropOutlineColor;\n', 1)
    ctor_anchor = '    this.onClose,\n'
    s = s.replace(ctor_anchor, ctor_anchor + '    this.onPickOutlineColor,\n    this.onEyedropOutlineColor,\n', 1)

# Pass callbacks into settings sheet.
call = '          brush: brush,\n          service: widget.service,\n'
if 'onPickOutlineColor: widget.onPickOutlineColor' not in s:
    s = s.replace(call, call + '          onPickOutlineColor: widget.onPickOutlineColor,\n          onEyedropOutlineColor: widget.onEyedropOutlineColor,\n', 1)

# Settings sheet fields/constructor.
sheet_field = '  final BrushService service;\n'
# There may be multiple service fields; target only after _BrushSettingsSheet declaration.
idx = s.find('class _BrushSettingsSheet')
if idx < 0:
    raise SystemExit('settings sheet missing')
head, tail = s[:idx], s[idx:]
if 'onPickOutlineColor' not in tail.split('class _BrushSettingsSheetState',1)[0]:
    tail = tail.replace(sheet_field, sheet_field + '  final Future<int?> Function(int currentColor)? onPickOutlineColor;\n  final Future<int?> Function(int currentColor)? onEyedropOutlineColor;\n', 1)
    tail = tail.replace('    required this.service,\n', '    required this.service,\n    this.onPickOutlineColor,\n    this.onEyedropOutlineColor,\n', 1)
s = head + tail

# Insert the actual extension section immediately before the sheet action buttons.
idx = s.find('class _BrushSettingsSheetState')
head, tail = s[:idx], s[idx:]
if 'BrushExtensionSettings(' not in tail:
    marker = '              const SizedBox(height: 16),\n              Row(\n'
    section = """              const SizedBox(height: 8),\n              const Divider(),\n              BrushExtensionSettings(\n                brush: _brush,\n                labels: BrushExtensionLabels.fromLocalizations(\n                  AppLocalizations.of(context)!,\n                ),\n                onChanged: (value) => setState(() => _brush = value),\n                onPickOutlineColor: widget.onPickOutlineColor == null\n                    ? null\n                    : () async {\n                        final color = await widget.onPickOutlineColor!(\n                          _brush.outlineColor,\n                        );\n                        if (!mounted || color == null) return;\n                        setState(() => _brush = _brush.copyWith(outlineColor: color));\n                      },\n                onEyedropOutlineColor: widget.onEyedropOutlineColor == null\n                    ? null\n                    : () async {\n                        final color = await widget.onEyedropOutlineColor!(\n                          _brush.outlineColor,\n                        );\n                        if (!mounted || color == null) return;\n                        setState(() => _brush = _brush.copyWith(outlineColor: color));\n                      },\n              ),\n"""
    if marker not in tail:
        raise SystemExit('settings action marker missing')
    tail = tail.replace(marker, section + marker, 1)
s = head + tail

# AppLocalizations is needed by the sheet.
if "../../../l10n/app_localizations.dart" not in s:
    s = s.replace("import 'package:flutter/material.dart';\n", "import 'package:flutter/material.dart';\n\nimport '../../../l10n/app_localizations.dart';\n", 1)
p.write_text(s)
