from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'{label} anchor changed')
    return text.replace(old, new, 1)


# 1. Allow the canvas to be pinched down to 1% while keeping the matrix non-singular.
p = Path('lib/screens/canvas/widgets/canvas_area.dart')
s = p.read_text()
s = replace_once(
    s,
    '/// キャンバス表示の縮小下限。等倍表示時の1/5まで縮小できる。\nconst double kCanvasMinScale = 0.2;',
    '/// キャンバス表示の縮小下限。ほぼ任意に縮小できる操作感を保ちつつ、\n'
    '/// 変換行列が特異になる0倍だけは避けるため、等倍表示時の1/100を下限にする。\n'
    'const double kCanvasMinScale = 0.01;',
    'canvas minimum scale',
)
p.write_text(s)

p = Path('test/canvas_pinch_gesture_test.dart')
s = p.read_text()
s = replace_once(
    s,
    "  testWidgets('下限未満の縮小要求は0.2倍へ正確にクランプされる', (tester) async {\n"
    "    final scaleOf = await pumpCanvas(tester);\n"
    "    final center = tester.getCenter(find.byType(CanvasArea));\n"
    "    // CanvasAreaは指間4px未満を角度計算の不安定域として無視する。\n"
    "    // その有効域の端（4px）でも要求倍率は4/200=0.02で十分に下限未満。\n"
    "    await pinch(tester, center, from: 200, to: 4);\n"
    "    expect(tester.takeException(), isNull);\n"
    "    expect(\n"
    "      scaleOf(),\n"
    "      closeTo(kCanvasMinScale, 0.001),\n"
    "      reason: '下限未満を要求しても1/5より小さくならず、境界値へ到達すること',\n"
    "    );\n"
    "  });",
    "  testWidgets('下限未満の縮小要求は0.01倍へ正確にクランプされる', (tester) async {\n"
    "    final scaleOf = await pumpCanvas(tester);\n"
    "    final center = tester.getCenter(find.byType(CanvasArea));\n"
    "    // CanvasAreaは指間4px未満を角度計算の不安定域として無視するため、\n"
    "    // 有効域のジェスチャーを2回使って1%未満を要求し、下限へ到達させる。\n"
    "    await pinch(tester, center, from: 200, to: 4);\n"
    "    await pinch(tester, center, from: 200, to: 50);\n"
    "    expect(tester.takeException(), isNull);\n"
    "    expect(\n"
    "      scaleOf(),\n"
    "      closeTo(kCanvasMinScale, 0.001),\n"
    "      reason: '1%未満を要求しても特異行列にせず、1/100の境界値へ到達すること',\n"
    "    );\n"
    "  });",
    'pinch minimum test',
)
s = replace_once(
    s,
    "  testWidgets('0.2倍へ到達する同一ジェスチャーでも45度回転は保持される', (tester) async {\n"
    "    await pumpCanvas(tester);\n"
    "    final center = tester.getCenter(find.byType(CanvasArea));\n"
    "    final anchor = center - const Offset(60, 0);\n"
    "    final movingStart = center + const Offset(60, 0);\n"
    "    final atMinScale = anchor + const Offset(24, 0);\n"
    "    final rotatedAtMinScale = anchor + Offset.fromDirection(math.pi / 4, 24);",
    "  testWidgets('0.01倍へ到達する同一ジェスチャーでも45度回転は保持される', (tester) async {\n"
    "    await pumpCanvas(tester);\n"
    "    final center = tester.getCenter(find.byType(CanvasArea));\n"
    "    // まず5%まで縮小し、次の同一ジェスチャー内で1%到達と回転を行う。\n"
    "    // これなら4px未満の不安定な指間距離を使わず境界を検証できる。\n"
    "    await pinch(tester, center, from: 200, to: 10);\n"
    "    final anchor = center - const Offset(60, 0);\n"
    "    final movingStart = center + const Offset(60, 0);\n"
    "    final atMinScale = anchor + const Offset(24, 0);\n"
    "    final rotatedAtMinScale = anchor + Offset.fromDirection(math.pi / 4, 24);",
    'pinch rotation test setup',
)
p.write_text(s)

# 2. Make the production automation proof wait for real async completion instead of
# assuming a fixed 1.5-second CI budget. The app code remains production-authentic.
p = Path('tool/rewrite_custom_automation_visual_proof.py')
s = p.read_text()
s = replace_once(
    s,
    "      await harness.waitForProductionAsync();\n"
    "      expect(find.byType(FilterPanel), findsOneWidget);\n"
    "      await harness.capture('04_aurora_filter_panel_during_recording');",
    "      await harness.waitForFilterPanelReady();\n"
    "      expect(find.byType(FilterPanel), findsOneWidget);\n"
    "      await harness.capture('04_aurora_filter_panel_during_recording');",
    'filter preview wait',
)
s = replace_once(
    s,
    "      await tester.tap(find.text(l10n.filterApplyButton));\n"
    "      await harness.waitForProductionAsync();\n"
    "      final afterApply = harness.activeLayerPixels();",
    "      await tester.tap(find.text(l10n.filterApplyButton));\n"
    "      await harness.waitForRecordedFilterApply(automation);\n"
    "      final afterApply = harness.activeLayerPixels();",
    'recorded apply wait',
)
s = replace_once(
    s,
    "      await harness.execute(\n"
    "        saved!,\n"
    "        CustomAutomationExecutionScope.currentFrame,\n"
    "        null,\n"
    "      );\n"
    "      await harness.waitForProductionAsync();",
    "      await tester.runAsync(\n"
    "        () => harness.execute(\n"
    "          saved!,\n"
    "          CustomAutomationExecutionScope.currentFrame,\n"
    "          null,\n"
    "        ),\n"
    "      );\n"
    "      await tester.pump();",
    'saved replay async boundary',
)
s = replace_once(
    s,
    "        await harness.execute(\n"
    "          preset,\n"
    "          CustomAutomationExecutionScope.currentFrame,\n"
    "          null,\n"
    "        );\n"
    "        await harness.waitForProductionAsync(extraMilliseconds: 2200);",
    "        await tester.runAsync(\n"
    "          () => harness.execute(\n"
    "            preset,\n"
    "            CustomAutomationExecutionScope.currentFrame,\n"
    "            null,\n"
    "          ),\n"
    "        );\n"
    "        await tester.pump();",
    'preset executor async boundary',
)

# Inject completion-based helpers into the test generator. Use ordinary quoted
# strings here so this Python patcher cannot conflict with the generator's raw
# triple-quoted Dart templates.
write_call = '\np.write_text(s)\n'
if write_call not in s:
    raise SystemExit('rewrite script write anchor changed')
helper_patch = """
\nwait_anchor = \"  Future<void> waitForProductionAsync({int extraMilliseconds = 1500}) async {\\n\"
if 'Future<void> waitForFilterPanelReady()' not in s:
    if wait_anchor not in s:
        raise SystemExit('production wait helper anchor changed')
    completion_helpers = r'''  Future<void> waitForFilterPanelReady() async {
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (DateTime.now().isBefore(deadline)) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 20));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
    }
    throw TestFailure('FilterPanel preview did not finish within 20 seconds');
  }

  Future<void> waitForRecordedFilterApply(
    CustomAutomationService automation,
  ) async {
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(deadline)) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 20));
      if ((automation.draft?.steps.length ?? 0) == 1) return;
    }
    throw TestFailure('Production FilterPanel Apply did not complete within 30 seconds');
  }

'''
    s = s.replace(wait_anchor, completion_helpers + wait_anchor, 1)
"""
s = s.replace(write_call, helper_patch + write_call, 1)
p.write_text(s)
