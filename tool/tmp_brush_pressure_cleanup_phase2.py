from pathlib import Path
import re

ROOT = Path('.')

# Remove superseded top-level fields only from the Brush class itself. Do not
# touch similarly named fields that belong to the new pressure profile objects.
p = ROOT / 'lib/models/brush.dart'
s = p.read_text()
brush_end = s.index('\nclass PressureRangeSetting')
head = s[:brush_end]
tail = s[brush_end:]
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
    head = head.replace(line, '')
head = re.sub(
    r"\n    mixingMode: BrushMixingMode\.values\.firstWhere\(\n      \(e\) => e\.name == j\['mixingMode'\],\n      orElse: \(\) => BrushMixingMode\.off,\n    \),",
    '',
    head,
)
p.write_text(head + tail)

# Remove only direct Brush(...) named arguments. Nested pressureOn/pressureOff
# settings with the same names are part of the new schema and must remain.
p = ROOT / 'lib/services/brush_service.dart'
s = p.read_text()
obsolete = {'blurRadius', 'mixingMode', 'mixingRate', 'edgeJitter', 'edgeJitterStrength'}

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


def strip_direct_args(block):
    lines = block.splitlines(keepends=True)
    depth = 0
    result = []
    for line in lines:
        stripped = line.lstrip()
        key_match = re.match(r'(\w+)\s*:', stripped)
        if depth == 1 and key_match and key_match.group(1) in obsolete:
            depth += line.count('(') - line.count(')')
            continue
        result.append(line)
        depth += line.count('(') - line.count(')')
    return ''.join(result)

for start, end in reversed(balanced_calls(s)):
    s = s[:start] + strip_direct_args(s[start:end]) + s[end:]

# No released legacy user data exists. Keep unrelated calligraphy normalization,
# but remove the obsolete marker edge-jitter/mixing migration branch.
s = re.sub(
    r"\n        // edgeJitter・混色設定未適用の旧データを補完\n        if \(!m\.edgeJitter \|\| m\.mixingMode == BrushMixingMode\.off\) \{.*?\n        \}",
    '',
    s,
    flags=re.S,
)
p.write_text(s)

# Current schema test rejects all superseded top-level keys.
p = ROOT / 'test/models/brush_pressure_profiles_test.dart'
s = p.read_text()
anchor = "      expect(json.containsKey('pressureStrength'), isFalse);\n"
for old in ['blurRadius', 'mixingMode', 'mixingRate', 'edgeJitter', 'edgeJitterStrength']:
    if f"json.containsKey('{old}')" not in s:
        s = s.replace(anchor, anchor + f"      expect(json.containsKey('{old}'), isFalse);\n")
p.write_text(s)
