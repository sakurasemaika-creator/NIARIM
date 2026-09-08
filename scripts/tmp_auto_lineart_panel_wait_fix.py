from pathlib import Path

p = Path('test/auto_lineart_panel_state_test.dart')
s = p.read_text()
old = """      show.value = true;\n      await tester.pump(const Duration(milliseconds: 900));\n      final freshWide = graph();\n"""
new = """      show.value = true;\n      for (var i = 0;\n          i < 30 && find.byType(AutoLineartControlOverlay).evaluate().isEmpty;\n          i++) {\n        await tester.pump(const Duration(milliseconds: 100));\n      }\n      expect(find.byType(AutoLineartControlOverlay), findsOneWidget);\n      final freshWide = graph();\n"""
if old not in s:
    raise SystemExit('reopen wait marker not found')
p.write_text(s.replace(old, new, 1))
print('auto lineart panel wait fix applied')
