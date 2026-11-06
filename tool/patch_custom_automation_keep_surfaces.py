from pathlib import Path
import re

p = Path('test/custom_automation_production_surface_visual_test.dart')
s = p.read_text()

if 'child: IndexedStack(' in s:
    raise SystemExit(0)

pattern = re.compile(
    r"class _SurfaceHostState extends State<_SurfaceHost> \{.*?\n\}\n\nint _changedBytes",
    re.S,
)
replacement = """class _SurfaceHostState extends State<_SurfaceHost> {
  final List<Widget> _surfaces = <Widget>[];

  void show(Widget widget) => showBuilder((_) => widget);

  void showBuilder(WidgetBuilder builder) {
    final widget = builder(context);
    setState(() {
      _surfaces.add(widget);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_surfaces.isEmpty) {
      return const Scaffold(body: SizedBox.expand());
    }
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _surfaces.length - 1,
          children: _surfaces,
        ),
      ),
    );
  }
}

int _changedBytes"""
s, count = pattern.subn(replacement, s, count=1)
if count != 1:
    raise SystemExit('surface host anchor changed')

p.write_text(s)
