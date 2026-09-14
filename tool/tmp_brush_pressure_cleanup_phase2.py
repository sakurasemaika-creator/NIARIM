from pathlib import Path
import re

ROOT = Path('.')

# Remove profile-overlap fields from Brush. They are fully superseded by
# pressureOn / pressureOff and no longer participate in rendering.
p = ROOT / 'lib/models/brush.dart'
s = p.read_text()
for line in [
    '  final int blurRadius;\n',
    '  final BrushMixingMode mixingMode;\n',
    '  final int mixingRate;\n',
    '  final bool edgeJitter;\n',
    '  final int edgeJitterStrength;\n',
    '    required this.blurRadius,\n',
    '    required this.mixingMode,\n',
    '    required this.mixingRate,\n',
    '    this.edgeJitter = false,\n',
    '    this.edgeJitterStrength = 50,\n',
    '    int? blurRadius,\n',
    '    BrushMixingMode? mixingMode,\n',
    '    int? mixingRate,\n',
    '    bool? edgeJitter,\n',
    '    int? edgeJitterStrength,\n',
    '      blurRadius: blurRadius ?? this.blurRadius,\n',
    '      mixingMode: mixingMode ?? this.mixingMode,\n',
    '      mixingRate: mixingRate ?? this.mixingRate,\n',
    '      edgeJitter: edgeJitter ?? this.edgeJitter,\n',
    '      edgeJitterStrength: edgeJitterStrength ?? this.edgeJitterStrength,\n',
    "    'blurRadius': blurRadius,\n",
    "    'mixingMode': mixingMode.name,\n",
    "    'mixingRate': mixingRate,\n",
    "    'edgeJitter': edgeJitter,\n",
    "    'edgeJitterStrength': edgeJitterStrength,\n",
    "    blurRadius: j['blurRadius'] as int,\n",
    "    mixingRate: j['mixingRate'] as int,\n",
    "    edgeJitter: j['edgeJitter'] as bool? ?? false,\n",
    "    edgeJitterStrength: j['edgeJitterStrength'] as int? ?? 50,\n",
]:
    s = s.replace(line, '')
s = re.sub(
    r"\n    mixingMode: BrushMixingMode\.values\.firstWhere\(\n      \(e\) => e\.name == j\['mixingMode'\],\n      orElse: \(\) => BrushMixingMode\.off,\n    \),",
    '',
    s,
)
p.write_text(s)

# Remove obsolete top-level fields from every Brush(...) literal in production.
p = ROOT / 'lib/services/brush_service.dart'
s = p.read_text()

def balanced_calls(text, needle='Brush('):
    out = []
    pos = 0
    while True:
        start = text.find(needle, pos)
        if start < 0:
            break
        depth = 0
        i = start + len(needle) - 1
        quote = None
        escaped = False
        while i < len(text):
            ch = text[i]
            if quote:
                if escaped:
                    escaped = False
                elif ch == '\\':
                    escaped = True
                elif ch == quote:
                    quote = None
            else:
                if ch in ('\"', "'"):
                    quote = ch
                elif ch == '(':
                    depth += 1
                elif ch == ')':
                    depth -= 1
                    if depth == 0:
                        out.append((start, i + 1))
                        break
            i += 1
        pos = i + 1
    return out

for start, end in reversed(balanced_calls(s)):
    block = s[start:end]
    for key in ('blurRadius', 'mixingMode', 'mixingRate', 'edgeJitter', 'edgeJitterStrength'):
        block = re.sub(rf'^\s*{key}:.*\n', '', block, flags=re.M)
    s = s[:start] + block + s[end:]

# Release has no legacy user brush data. Keep the unrelated calligraphy preset
# normalization, but remove the old edge-jitter/mixing migration branch.
s = re.sub(
    r"\n        // edgeJitter・混色設定未適用の旧データを補完\n        if \(!m\.edgeJitter \|\| m\.mixingMode == BrushMixingMode\.off\) \{.*?\n        \}",
    '',
    s,
    flags=re.S,
)
p.write_text(s)

# Current schema test must reject every superseded top-level key.
p = ROOT / 'test/models/brush_pressure_profiles_test.dart'
s = p.read_text()
for old in [
    'pressureMode',
    'pressureStrength',
    'blurRadius',
    'mixingMode',
    'mixingRate',
    'edgeJitter',
    'edgeJitterStrength',
]:
    anchor = "      expect(json.containsKey('pressureStrength'), isFalse);\n"
    if old in ('pressureMode', 'pressureStrength'):
        continue
    if f"json.containsKey('{old}')" not in s:
        s = s.replace(anchor, anchor + f"      expect(json.containsKey('{old}'), isFalse);\n")
p.write_text(s)
