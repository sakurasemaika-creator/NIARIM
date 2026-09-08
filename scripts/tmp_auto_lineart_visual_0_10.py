from pathlib import Path

p = Path('test/auto_lineart_filter_panel_visual_audit_test.dart')
s = p.read_text()
# Update visual labels and selected line color.
s = s.replace("Text('smoothing $smoothing / 100')", "Text('smoothing $smoothing / 10')")
s = s.replace("autoLineartSmoothing: smoothing.toDouble(),\n    );", "autoLineartSmoothing: smoothing.toDouble(),\n      autoLineartColor: 0xFF2E62D5,\n    );")
# Replace old specific audit cases with 0/1/5/9/10 plus representative panel captures.
start = s.index("  testWidgets(\n    'SP auto lineart smoothing 45 visual audit'")
end = s.rindex("}\n")
new_tests = r'''  for (final level in <int>[0, 1, 5, 9, 10]) {
    testWidgets(
      'auto lineart 200px smoothing $level visual audit',
      (tester) async {
        if (!visualAudit) return;
        await pumpControlAudit(
          tester,
          smoothing: level,
          goldenName: 'auto_lineart_preview_200_$level.png',
        );
      },
      skip: !visualAudit,
    );
  }

  for (final level in <int>[0, 5, 10]) {
    testWidgets(
      'SP filter panel smoothing $level visual audit',
      (tester) async {
        if (!visualAudit) return;
        await pumpPanelAudit(
          tester,
          smoothing: level,
          size: const Size(390, 844),
          goldenName: 'auto_lineart_sp_$level.png',
        );
      },
      skip: !visualAudit,
    );
  }
'''
p.write_text(s[:start] + new_tests + '}\n')
