from pathlib import Path

p = Path('test/custom_automation_production_visual_test.dart')
s = p.read_text()
needle = """        PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
"""
replacement = """        PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          maintainState: false,
"""
count = s.count(needle)
if count < 4:
    raise SystemExit(f'expected at least 4 generated routes, found {count}')
s = s.replace(needle, replacement)
p.write_text(s)
