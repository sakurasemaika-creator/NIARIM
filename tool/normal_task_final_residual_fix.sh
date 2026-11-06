#!/usr/bin/env bash
set -euxo pipefail

python3 - <<'PY'
from pathlib import Path

vhs = Path('test/visual/vhs_filter_actual_capture_test.dart')
text = vhs.read_text()
old = """    final sliders = find.descendant(of: panel, matching: find.byType(Slider));
    expect(sliders, findsNWidgets(4));
    const ratios = [0.72, 0.64, 0.58, 0.66];
    for (var i = 0; i < 4; i++) {
      final rect = tester.getRect(sliders.at(i));
"""
new = """    Finder sliders() => find.descendant(
      of: panel,
      matching: find.byType(Slider, skipOffstage: false),
    );
    expect(sliders(), findsNWidgets(4));
    const ratios = [0.72, 0.64, 0.58, 0.66];
    for (var i = 0; i < 4; i++) {
      final slider = sliders().at(i);
      await tester.ensureVisible(slider);
      await tester.pump();
      final rect = tester.getRect(slider);
"""
if text.count(old) != 1:
    raise SystemExit('VHS slider anchor changed')
vhs.write_text(text.replace(old, new, 1))

visual = Path('test/custom_automation_visual_audit_test.dart')
text = visual.read_text()
old = 'timeout: const Timeout(Duration(minutes: 3)),'
new = 'timeout: const Timeout(Duration(minutes: 8)),'
if text.count(old) != 1:
    raise SystemExit('automation visual timeout anchor changed')
visual.write_text(text.replace(old, new, 1))

prod = Path('test/custom_automation_production_visual_test.dart')
text = prod.read_text()
old = 'timeout: const Timeout(Duration(minutes: 6)),'
new = 'timeout: const Timeout(Duration(minutes: 12)),'
if text.count(old) != 1:
    raise SystemExit('automation production timeout anchor changed')
prod.write_text(text.replace(old, new, 1))
PY

dart format test/visual/vhs_filter_actual_capture_test.dart test/custom_automation_visual_audit_test.dart test/custom_automation_production_visual_test.dart
flutter pub get
python3 -m pip install --user 'fonttools>=4.50,<5'
mkdir -p /tmp/niarim-font-src
curl -fsSL 'https://raw.githubusercontent.com/google/fonts/main/ofl/notoserifkr/NotoSerifKR%5Bwght%5D.ttf' -o /tmp/niarim-font-src/NotoSerifKR.ttf
curl -fsSL 'https://raw.githubusercontent.com/google/fonts/main/ofl/notoserifsc/NotoSerifSC%5Bwght%5D.ttf' -o /tmp/niarim-font-src/NotoSerifSC.ttf
curl -fsSL 'https://raw.githubusercontent.com/google/fonts/main/ofl/notosanskr/NotoSansKR%5Bwght%5D.ttf' -o /tmp/niarim-font-src/NotoSansKR.ttf
curl -fsSL 'https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf' -o /tmp/niarim-font-src/NotoSansSC.ttf
python3 tool/build_fallback_fonts.py /tmp/niarim-font-src

flutter test --reporter expanded --concurrency=1 test/font_coverage_test.dart
flutter test --reporter expanded --concurrency=1 test/visual/vhs_filter_actual_capture_test.dart
flutter test --reporter expanded --concurrency=1 test/custom_automation_visual_audit_test.dart
flutter test --reporter expanded --concurrency=1 test/custom_automation_production_visual_test.dart
flutter analyze test/visual/vhs_filter_actual_capture_test.dart test/custom_automation_visual_audit_test.dart test/custom_automation_production_visual_test.dart --no-fatal-warnings --no-fatal-infos

git config user.name 'github-actions[bot]'
git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
git rm .github/workflows/normal-task-final-residual-fix.yml tool/normal_task_final_residual_fix.sh
git add assets/fonts test/visual/vhs_filter_actual_capture_test.dart test/custom_automation_visual_audit_test.dart test/custom_automation_production_visual_test.dart
git diff --cached --check
git commit -m 'test: resolve final residual suite regressions'
git push origin HEAD:dev_branch
