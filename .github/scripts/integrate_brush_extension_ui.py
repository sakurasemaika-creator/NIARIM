from pathlib import Path
import json

ROOT = Path('.')

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
    base = arb.stem.removeprefix('app_').split('_')[0]
    if base not in translations:
        continue
    data = json.loads(arb.read_text())
    for key, value in zip(keys, translations[base]):
        data[key] = value
    arb.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')

p = ROOT / 'lib/screens/canvas/widgets/brush_extension_settings.dart'
s = p.read_text()
if "../../../l10n/app_localizations.dart" not in s:
    s = s.replace("import 'package:flutter/material.dart';\n", "import 'package:flutter/material.dart';\n\nimport '../../../l10n/app_localizations.dart';\n", 1)
if 'BrushExtensionLabels.fromLocalizations' not in s:
    marker = '  const BrushExtensionLabels.japanese()\n'
    factory = """  factory BrushExtensionLabels.fromLocalizations(AppLocalizations l) => BrushExtensionLabels(\n        lateralRepeat: l.brushLateralRepeat, lateralRepeatCount: l.brushLateralRepeatCount,\n        lateralRepeatSpacing: l.brushLateralRepeatSpacing, outline: l.brushOutline,\n        outlineWidth: l.brushOutlineWidth, outlineColor: l.brushOutlineColor,\n        colorPicker: l.brushOutlineColorPicker, eyedropper: l.brushOutlineEyedropper,\n        fold: l.brushFold, foldTriggerAngle: l.brushFoldTriggerAngle,\n        yBranchAngle: l.brushYBranchAngle, yBranchLength: l.brushYBranchLength,\n        yBranchWidth: l.brushYBranchWidth, yBranchEndTaper: l.brushYBranchEndTaper,\n      );\n\n"""
    if marker not in s: raise SystemExit('labels marker missing')
    s = s.replace(marker, factory + marker, 1)
p.write_text(s)

p = ROOT / 'lib/screens/canvas/widgets/brush_panel.dart'
s = p.read_text()
for imp in ["import 'brush_extension_settings.dart';\n", "import 'color_picker_panel.dart';\n"]:
    if imp not in s:
        s = s.replace("import 'panel_close_bar.dart';\n", "import 'panel_close_bar.dart';\n" + imp, 1)

# The canvas owner supplies only sampling. The full color UI is the existing
# ColorPickerPanel, so outline gets HSV/RGB/alpha/HEX/recent colors/palettes.
if 'onEyedropOutlineColor' not in s.split('class _BrushPanelState',1)[0]:
    s = s.replace('  final VoidCallback onClose;\n', '  final VoidCallback onClose;\n  final Future<int?> Function()? onEyedropOutlineColor;\n', 1)
    s = s.replace('  const BrushPanel({super.key, required this.onClose});', '  const BrushPanel({\n    super.key,\n    required this.onClose,\n    this.onEyedropOutlineColor,\n  });', 1)

# Pass sampling callback into settings sheet.
s = s.replace('_BrushSettingsSheet(brush: brush)', '_BrushSettingsSheet(\n        brush: brush,\n        onEyedropOutlineColor: widget.onEyedropOutlineColor,\n      )')

idx = s.find('class _BrushSettingsSheet extends')
if idx < 0: raise SystemExit('settings sheet missing')
head, tail = s[:idx], s[idx:]
header_end = tail.find('class _BrushSettingsSheetState')
header = tail[:header_end]
body = tail[header_end:]
if 'onEyedropOutlineColor' not in header:
    header = header.replace('  final Brush brush;\n', '  final Brush brush;\n  final Future<int?> Function()? onEyedropOutlineColor;\n', 1)
    header = header.replace('    required this.brush,\n', '    required this.brush,\n    this.onEyedropOutlineColor,\n', 1)
tail = header + body
s = head + tail

idx = s.find('class _BrushSettingsSheetState')
head, tail = s[:idx], s[idx:]
if 'Future<void> _showOutlineColorPicker()' not in tail:
    state_open = tail.find('{') + 1
    methods = """
  Future<void> _showOutlineColorPicker() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ColorPickerPanel(
          currentColor: Color(_brush.outlineColor),
          onColorChanged: (color) {
            if (!mounted) return;
            setState(() => _brush = _brush.copyWith(outlineColor: color.toARGB32()));
          },
          onClose: () => Navigator.of(dialogContext).pop(),
          onEyedropperTap: widget.onEyedropOutlineColor == null
              ? null
              : () async {
                  Navigator.of(dialogContext).pop();
                  final sampled = await widget.onEyedropOutlineColor!();
                  if (!mounted || sampled == null) return;
                  setState(() => _brush = _brush.copyWith(outlineColor: sampled));
                },
        ),
      ),
    );
  }

  Future<void> _eyedropOutlineColor() async {
    final callback = widget.onEyedropOutlineColor;
    if (callback == null) return;
    final sampled = await callback();
    if (!mounted || sampled == null) return;
    setState(() => _brush = _brush.copyWith(outlineColor: sampled));
  }
"""
    tail = tail[:state_open] + methods + tail[state_open:]

if 'BrushExtensionSettings(' not in tail:
    marker = '              const SizedBox(height: 16),\n              Row(\n'
    section = """              const SizedBox(height: 8),
              const Divider(),
              BrushExtensionSettings(
                brush: _brush,
                labels: BrushExtensionLabels.fromLocalizations(AppLocalizations.of(context)!),
                onChanged: (value) => setState(() => _brush = value),
                onPickOutlineColor: _showOutlineColorPicker,
                onEyedropOutlineColor: widget.onEyedropOutlineColor == null ? null : _eyedropOutlineColor,
              ),
"""
    if marker not in tail: raise SystemExit('action marker missing')
    tail = tail.replace(marker, section + marker, 1)
s = head + tail
p.write_text(s)
