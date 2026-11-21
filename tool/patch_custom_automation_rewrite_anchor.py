from pathlib import Path

p = Path('tool/rewrite_custom_automation_visual_proof.py')
s = p.read_text()
old = """start_marker = \"  testWidgets(\\n    'production automation surfaces record a real Aurora filter and replay it',\"\nend_marker = \"\\n}\\n\\nclass _SurfaceHarness\"\n\nif \"production automation records a real Aurora filter and replays pixels\" not in s:\n    start = s.find(start_marker)\n    if start < 0:\n        raise SystemExit('test section start anchor changed')\n    end = s.find(end_marker, start)\n"""
new = """end_marker = \"\\n}\\n\\nclass _SurfaceHarness\"\n\nif \"production automation records a real Aurora filter and replays pixels\" not in s:\n    teardown = s.find('  tearDown(() {')\n    if teardown < 0:\n        raise SystemExit('tearDown anchor changed')\n    start = s.find('  testWidgets(', teardown)\n    if start < 0:\n        raise SystemExit('test section start anchor changed')\n    end = s.find(end_marker, start)\n"""
if new in s:
    raise SystemExit(0)
if old not in s:
    raise SystemExit('rewrite helper anchor changed')
p.write_text(s.replace(old, new, 1))
