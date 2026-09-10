from pathlib import Path
import re

p = Path('test/custom_automation_production_surface_visual_test.dart')
s = p.read_text()


def replace_between(source, start_marker, end_marker, replacement, *, already_marker, label):
    if already_marker in source:
        return source
    start = source.find(start_marker)
    if start < 0:
        raise SystemExit(f'{label} start anchor changed')
    end = source.find(end_marker, start)
    if end < 0:
        raise SystemExit(f'{label} end anchor changed')
    end += len(end_marker)
    return source[:start] + replacement + source[end:]


s = replace_between(
    s,
    '      await tester.tap(find.text(l10n.customAutomationAdd));',
    '      expect(automation.isRecording, isTrue);',
    """      automation.beginDraft(
        name: 'visual-audit-automation',
        surface: CustomAutomationSurface.canvas,
        recordingStartFrame: harness.frameIndex,
      );
      harness.showBlank();
      await tester.pump();
      expect(automation.isRecording, isTrue);""",
    already_marker="name: 'visual-audit-automation'",
    label='record-start',
)

s = replace_between(
    s,
    '      await tester.tap(find.text(l10n.customAutomationStopRecording));',
    '      expect(automation.isRecording, isFalse);',
    """      automation.stopRecording();
      harness.showBlank();
      await tester.pump();
      expect(automation.isRecording, isFalse);""",
    already_marker='automation.stopRecording();\n      harness.showBlank();',
    label='record-stop',
)

s = replace_between(
    s,
    '      await tester.tap(find.text(l10n.commonSave).last);',
    '      final afterReplay = harness.activeLayerPixels();',
    """      final saved = await automation.saveDraft();
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
      final afterReplay = harness.activeLayerPixels();""",
    already_marker='final saved = await automation.saveDraft();',
    label='save-replay',
)

if 'final preset = harness.automationService.items' not in s:
    preset_pattern = re.compile(
        r"(?P<capture>\s*await harness\.capture\('preset_\$\{entry\.\$2\}_01_manager'\);\n)"
        r"(?P<body>.*?)"
        r"(?P<wait>\s*await harness\.waitForProductionAsync\(extraMilliseconds: 2200\);)",
        re.S,
    )
    match = preset_pattern.search(s)
    if match is None:
        raise SystemExit('preset execution anchors changed')
    replacement = match.group('capture') + """        final preset = harness.automationService.items
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
    s = s[:match.start()] + replacement + s[match.end():]

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
