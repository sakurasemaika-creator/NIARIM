from pathlib import Path

p = Path('test/auto_lineart_panel_state_test.dart')
s = p.read_text()

# Initial preview is async as well: project pixels are composited and analyzed before
# the editable overlay can exist. Do not encode runner speed into the test.
old_initial = """      show.notifyListeners();\n      await tester.pump(const Duration(milliseconds: 900));\n      expect(find.byType(AutoLineartControlOverlay), findsOneWidget);\n"""
new_initial = """      show.notifyListeners();\n      for (var i = 0;\n          i < 40 && find.byType(AutoLineartControlOverlay).evaluate().isEmpty;\n          i++) {\n        await tester.pump(const Duration(milliseconds: 100));\n      }\n      expect(find.byType(AutoLineartControlOverlay), findsOneWidget);\n"""
if old_initial in s:
    s = s.replace(old_initial, new_initial, 1)

# Closing/reopening creates a fresh async preview and must not inherit the old manual
# graph. Wait for that fresh overlay by observable widget state, not a fixed delay.
old_reopen = """      show.value = true;\n      await tester.pump(const Duration(milliseconds: 900));\n      final freshWide = graph();\n"""
new_reopen = """      show.value = true;\n      for (var i = 0;\n          i < 40 && find.byType(AutoLineartControlOverlay).evaluate().isEmpty;\n          i++) {\n        await tester.pump(const Duration(milliseconds: 100));\n      }\n      expect(find.byType(AutoLineartControlOverlay), findsOneWidget);\n      final freshWide = graph();\n"""
if old_reopen in s:
    s = s.replace(old_reopen, new_reopen, 1)

if 'for (var i = 0;' not in s:
    raise SystemExit('no async overlay waits were installed')
p.write_text(s)
print('auto lineart initial/reopen state waits applied')
