from pathlib import Path

p = Path("test/functional_audit_batch36_test.dart")
s = p.read_text(encoding="utf-8")
old = """        // Anchor around (70,92) is closest to the bottom/top VP3=(64,8) in this compact test scene.
        distance: (x, y) => _distanceToInfiniteLine(ui.Offset(x, y), const ui.Offset(64, 8), const ui.Offset(70, 92)),
"""
new = """        // Anchor (70,92) is nearest VP2=(113,40); RulerEngine chooses the nearest
        // vanishing point at stroke start and keeps that ray for the whole stroke.
        distance: (x, y) => _distanceToInfiniteLine(ui.Offset(x, y), const ui.Offset(113, 40), const ui.Offset(70, 92)),
"""
if old not in s:
    raise SystemExit("perspective3 audit anchor missing")
s = s.replace(old, new, 1)
p.write_text(s, encoding="utf-8", newline="\n")
