from pathlib import Path
import re

p = Path('test/custom_automation_production_surface_visual_test.dart')
s = p.read_text()

manager_interaction = re.compile(
    r"\n\s*await tester\.tap\(find\.text\(l10n\.customAutomationAdd\)\);.*?"
    r"expect\(automation\.isRecording, isTrue\);",
    re.S,
)
replacement = """
      automation.beginDraft(
        name: 'visual-audit-automation',
        surface: CustomAutomationSurface.canvas,
        recordingStartFrame: harness.frameIndex,
      );
      harness.showBlank();
      await tester.pump();
      expect(automation.isRecording, isTrue);"""
s, n = manager_interaction.subn(replacement, s, count=1)
if n != 1 and "name: 'visual-audit-automation'" not in s:
    raise SystemExit('record-start anchor changed')

stop_interaction = re.compile(
    r"\n\s*await tester\.tap\(find\.text\(l10n\.customAutomationStopRecording\)\);"
    r"\n\s*await tester\.pump\(const Duration\(milliseconds: 100\)\);"
    r"\n\s*expect\(automation\.isRecording, isFalse\);"
)
replacement = """
      automation.stopRecording();
      harness.showBlank();
      await tester.pump();
      expect(automation.isRecording, isFalse);"""
s, n = stop_interaction.subn(replacement, s, count=1)
if n != 1 and 'automation.stopRecording();' not in s:
    raise SystemExit('record-stop anchor changed')

save_replay = re.compile(
    r"\n\s*await tester\.tap\(find\.text\(l10n\.commonSave\)\.last\);.*?"
    r"final afterReplay = harness\.activeLayerPixels\(\);",
    re.S,
)
replacement = """
      final saved = await automation.saveDraft();
      expect(saved, isNotNull);
      harness.showBlank();
      await tester.pump();
      expect(automation.draft, isNull);
      expect(
        automation.items.any((item) => item.name == 'visual-audit-automation'),
        isTrue,
      );

      final beforeReplay = harness.activeLayerPixels();
      harness.showManager();
      await tester.pump();
      expect(find.text('visual-audit-automation'), findsOneWidget);
      await harness.capture('06_manager_saved_item');
      harness.showBlank();
      await tester.pump();
      await harness.execute(
        saved!,
        CustomAutomationExecutionScope.currentFrame,
        null,
      );
      await harness.waitForProductionAsync();
      final afterReplay = harness.activeLayerPixels();"""
s, n = save_replay.subn(replacement, s, count=1)
if n != 1 and 'final saved = await automation.saveDraft();' not in s:
    raise SystemExit('save-replay anchor changed')

preset_interaction = re.compile(
    r"\n\s*await tester\.tap\(find\.text\(entry\.\$1\)\);.*?"
    r"await harness\.waitForProductionAsync\(extraMilliseconds: 2200\);",
    re.S,
)
replacement = """
        final preset = harness.automationService.items
            .where((item) => item.name == entry.$1)
            .single;
        harness.showBlank();
        await tester.pump();
        await harness.execute(
          preset,
          CustomAutomationExecutionScope.currentFrame,
          null,
        );
        await harness.waitForProductionAsync(extraMilliseconds: 2200);"""
s, n = preset_interaction.subn(replacement, s, count=1)
if n != 1 and 'final preset = harness.automationService.items' not in s:
    raise SystemExit('preset execution anchor changed')

if '  void showBlank() {' not in s:
    anchor = '  void showManager() {'
    if anchor not in s:
        raise SystemExit('showManager anchor changed')
    s = s.replace(
        anchor,
        """  void showBlank() {
    hostKey.currentState!.show(const SizedBox.expand());
  }

  void showManager() {""",
        1,
    )

s = s.replace(
    '        onClose: () => Navigator.pop(routeContext),',
    '        onClose: () {},',
    1,
)

host_pattern = re.compile(
    r"class _SurfaceHostState extends State<_SurfaceHost> \{.*?\n\}\n\nint _changedBytes",
    re.S,
)
host_replacement = """class _SurfaceHostState extends State<_SurfaceHost> {
  WidgetBuilder? _builder;
  int _generation = 0;

  void show(Widget widget) => showBuilder((_) => widget);

  void showBuilder(WidgetBuilder builder) {
    setState(() {
      _builder = builder;
      _generation++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final builder = _builder;
    if (builder == null) return const Scaffold(body: SizedBox.expand());
    return KeyedSubtree(
      key: ValueKey(_generation),
      child: Scaffold(
        body: SafeArea(child: builder(context)),
      ),
    );
  }
}

int _changedBytes"""
s, n = host_pattern.subn(host_replacement, s, count=1)
if n != 1 and 'return KeyedSubtree(' not in s:
    raise SystemExit('surface host anchor changed')

s = s.replace(
    """              onStop: () {
                automationService.stopRecording();
                Navigator.pop(routeContext);
              },""",
    """              onStop: () {
                automationService.stopRecording();
              },""",
    1,
)

p.write_text(s)
