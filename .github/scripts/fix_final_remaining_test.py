from pathlib import Path
import re

p = Path('test/final_remaining_strict_evidence_test.dart')
s = p.read_text()

# Replace the obsolete EffectFilterType.blur/applyEffectFilters block with the
# actual drawing-filter implementation used by NIARIM.
s = re.sub(
    r"\s*final effect = EffectFilterInstance\(\s*id: 'b\$strength',\s*type: EffectFilterType\.blur,\s*startFrame: 0,\s*endFrame: 0,\s*param1: strength\.toDouble\(\),\s*\);\s*final got = FilterEngine\(\)\.applyEffectFilters\(\s*Uint8List\.fromList\(input\),\s*w,\s*h,\s*\[effect\],\s*0,\s*\);",
    "\n      final got = FilterEngine().applyGaussianBlur(\n        Uint8List.fromList(input),\n        w,\n        h,\n        strength.toDouble(),\n      );",
    s,
    flags=re.S,
)

# Remove the now-unused model import if the obsolete effect instance is gone.
if 'EffectFilterInstance(' not in s:
    s = s.replace("import 'package:niarim/models/effect_filter_instance.dart';\n", '')

# w/h are runtime locals, so this Rect cannot be const.
s = s.replace(
    'const ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble())',
    'ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble())',
)

if 'EffectFilterType.blur' in s:
    raise SystemExit('repair failed: EffectFilterType.blur still present')

p.write_text(s)
