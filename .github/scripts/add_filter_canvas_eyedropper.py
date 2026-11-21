from pathlib import Path
import json
import re


def replace_once(path: str, old: str, new: str):
    p = Path(path)
    s = p.read_text(encoding='utf-8')
    if old not in s:
        raise SystemExit(f'pattern not found in {path}: {old[:120]!r}')
    p.write_text(s.replace(old, new, 1), encoding='utf-8')

# ---------------------------------------------------------------------------
# FilterPanel: expose filter-color canvas eyedropper controls.
# ---------------------------------------------------------------------------
p = Path('lib/screens/canvas/widgets/filter_panel.dart')
s = p.read_text(encoding='utf-8')

anchor = "/// 描画フィルターパネル。\n"
if 'enum FilterColorEyedropperTarget' not in s:
    s = s.replace(
        anchor,
        "enum FilterColorEyedropperTarget { inkPool, outline }\n\n" + anchor,
        1,
    )

old_fields = """  final Set<int>? bulkFrameIndices;\n  final VoidCallback onClose;\n\n  const FilterPanel({\n"""
new_fields = """  final Set<int>? bulkFrameIndices;\n  final VoidCallback onClose;\n  final ValueChanged<FilterColorEyedropperTarget>? onStartCanvasEyedropper;\n  final FilterColorEyedropperTarget? activeCanvasEyedropperTarget;\n\n  const FilterPanel({\n"""
if 'onStartCanvasEyedropper' not in s:
    if old_fields not in s:
        raise SystemExit('FilterPanel fields anchor not found')
    s = s.replace(old_fields, new_fields, 1)

old_ctor = """    this.bulkFrameIndices,\n    required this.onClose,\n  });\n"""
new_ctor = """    this.bulkFrameIndices,\n    required this.onClose,\n    this.onStartCanvasEyedropper,\n    this.activeCanvasEyedropperTarget,\n  });\n"""
if 'this.onStartCanvasEyedropper' not in s:
    if old_ctor not in s:
        raise SystemExit('FilterPanel ctor anchor not found')
    s = s.replace(old_ctor, new_ctor, 1)

# Add a shared helper for the eyedropper icon.
helper_anchor = """  @override\n  void initState() {\n"""
helper = r'''  Widget _canvasEyedropperButton(
    BuildContext context,
    FilterColorEyedropperTarget target,
  ) {
    final active = widget.activeCanvasEyedropperTarget == target;
    final l10n = AppLocalizations.of(context)!;
    return IconButton(
      icon: const Icon(Icons.colorize, size: 18),
      tooltip: l10n.filterCanvasEyedropperTooltip,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor: active
            ? Theme.of(context).colorScheme.primaryContainer
            : null,
        foregroundColor: active
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : null,
      ),
      onPressed: () => widget.onStartCanvasEyedropper?.call(target),
    );
  }

'''
if '_canvasEyedropperButton(' not in s:
    if helper_anchor not in s:
        raise SystemExit('FilterPanel helper anchor not found')
    s = s.replace(helper_anchor, helper + helper_anchor, 1)

# Add button beside ink-pool chip. Match only inside inkPool block using a bounded regex.
def add_button_to_color_block(text: str, kind: str, target: str) -> str:
    pattern = re.compile(
        rf"(if \(current\.kind == FilterKind\.{kind}\) \.\.\.\[.*?GestureDetector\(\n\s+onTap:.*?\n\s+child: Container\(.*?\n\s+\),\n\s+\),)(\n\s+\],)",
        re.S,
    )
    m = pattern.search(text)
    if not m:
        raise SystemExit(f'{kind} color block not found')
    if f'FilterColorEyedropperTarget.{target}' in m.group(0):
        return text
    insertion = m.group(1) + f"\n                                const SizedBox(width: 2),\n                                _canvasEyedropperButton(\n                                  context,\n                                  FilterColorEyedropperTarget.{target},\n                                )," + m.group(2)
    return text[:m.start()] + insertion + text[m.end():]

s = add_button_to_color_block(s, 'inkPool', 'inkPool')
s = add_button_to_color_block(s, 'outline', 'outline')
p.write_text(s, encoding='utf-8')

# ---------------------------------------------------------------------------
# CanvasArea: allow a transient forced eyedropper mode without changing the
# user's selected drawing tool. Sampling reuses _pickColor(), which already
# composites every visible layer with blend mode/opacity/clipping applied.
# ---------------------------------------------------------------------------
p = Path('lib/screens/canvas/widgets/canvas_area.dart')
s = p.read_text(encoding='utf-8')
if 'final bool filterEyedropperActive;' not in s:
    s = s.replace(
        "  final ValueChanged<Color>? onEyedropper;\n",
        "  final ValueChanged<Color>? onEyedropper;\n  final bool filterEyedropperActive;\n",
        1,
    )
if 'this.filterEyedropperActive = false,' not in s:
    s = s.replace(
        "    this.onEyedropper,\n",
        "    this.onEyedropper,\n    this.filterEyedropperActive = false,\n",
        1,
    )

pointer_anchor = """  void _onPointerDown(PointerEvent event) {\n    final type = _inputHandler.classifyInput(event);\n    final canvasPos = _canvasPosition(event.localPosition);\n\n"""
pointer_new = pointer_anchor + """    // フィルターパネルから起動した一時スポイト中は、現在選択中の描画\n    // ツールを変更せず、このタップを色取得だけに使う。_pickColor()は\n    // 表示中の全レイヤーを合成した見た目色を返す。\n    if (widget.filterEyedropperActive) {\n      _pickColor(canvasPos);\n      return;\n    }\n\n"""
if 'if (widget.filterEyedropperActive)' not in s:
    if pointer_anchor not in s:
        raise SystemExit('CanvasArea pointer anchor not found')
    s = s.replace(pointer_anchor, pointer_new, 1)
p.write_text(s, encoding='utf-8')

# ---------------------------------------------------------------------------
# CanvasScreen: own transient filter eyedropper state, route sampled visible
# color to the selected filter instead of BrushService, and show a persistent
# on-canvas instruction while sampling is active.
# ---------------------------------------------------------------------------
p = Path('lib/screens/canvas/canvas_screen.dart')
s = p.read_text(encoding='utf-8')
if "../../services/filter_service.dart" not in s:
    s = s.replace(
        "import '../../services/performance_service.dart';\n",
        "import '../../services/performance_service.dart';\nimport '../../services/filter_service.dart';\n",
        1,
    )

state_anchor = "  bool _showColorAdjustPanel = false;\n"
if '_filterColorEyedropperTarget' not in s:
    s = s.replace(
        state_anchor,
        state_anchor + "  FilterColorEyedropperTarget? _filterColorEyedropperTarget;\n",
        1,
    )

method_anchor = """  /// 背景切替（白/プロジェクト背景色 ⟷ 透過、\n"""
methods = r'''  void _toggleFilterColorEyedropper(FilterColorEyedropperTarget target) {
    setState(() {
      _filterColorEyedropperTarget = _filterColorEyedropperTarget == target
          ? null
          : target;
    });
  }

  void _handleCanvasEyedropper(Color color) {
    final target = _filterColorEyedropperTarget;
    if (target != null) {
      final filterService = context.read<FilterService>();
      final current = filterService.currentFilter;
      if (current != null) {
        switch (target) {
          case FilterColorEyedropperTarget.inkPool:
            filterService.updateFilterParams(
              current.id,
              inkPoolColor: color.toARGB32(),
            );
          case FilterColorEyedropperTarget.outline:
            filterService.updateFilterParams(
              current.id,
              outlineColor: color.toARGB32(),
            );
        }
      }
      setState(() => _filterColorEyedropperTarget = null);
      return;
    }
    setState(() => _currentColor = color);
    context.read<BrushService>().setCurrentColor(color);
  }

  String _filterEyedropperHint(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _filterColorEyedropperTarget == FilterColorEyedropperTarget.inkPool
        ? l10n.filterInkPoolEyedropperHint
        : l10n.filterOutlineEyedropperHint;
  }

'''
if '_toggleFilterColorEyedropper(' not in s:
    if method_anchor not in s:
        raise SystemExit('CanvasScreen method anchor not found')
    s = s.replace(method_anchor, methods + method_anchor, 1)

# Replace normal eyedropper callback with routed handler and enable forced mode.
old_eye = """                                  onEyedropper: (color) {\n                                    setState(() => _currentColor = color);\n                                    context\n                                        .read<BrushService>()\n                                        .setCurrentColor(color);\n                                  },\n                                  project: project,\n"""
new_eye = """                                  onEyedropper: _handleCanvasEyedropper,\n                                  filterEyedropperActive:\n                                      _filterColorEyedropperTarget != null,\n                                  project: project,\n"""
if old_eye in s:
    s = s.replace(old_eye, new_eye, 1)
elif 'filterEyedropperActive:' not in s:
    raise SystemExit('CanvasScreen onEyedropper block not found')

# Persistent visual instruction over the canvas; IgnorePointer keeps every pixel
# beneath it tappable for the eyedropper.
canvas_anchor = """                                if (_isSelectionToolActive)\n                                  Positioned(\n"""
banner = r'''                                if (_filterColorEyedropperTarget != null)
                                  Positioned(
                                    top: 12,
                                    left: 12,
                                    right: 12,
                                    child: IgnorePointer(
                                      child: Center(
                                        child: Material(
                                          elevation: 4,
                                          borderRadius: BorderRadius.circular(10),
                                          color: Theme.of(context)
                                              .colorScheme
                                              .inverseSurface,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 9,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.colorize,
                                                  size: 18,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onInverseSurface,
                                                ),
                                                const SizedBox(width: 8),
                                                Flexible(
                                                  child: Text(
                                                    _filterEyedropperHint(context),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onInverseSurface,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
'''
if '_filterEyedropperHint(context)' not in s:
    if canvas_anchor not in s:
        raise SystemExit('CanvasScreen canvas banner anchor not found')
    s = s.replace(canvas_anchor, banner + canvas_anchor, 1)

# Wire FilterPanel through whichever helper builds it; regex avoids dependence on
# exact line wrapping of the existing onClose callback.
if 'activeCanvasEyedropperTarget:' not in s:
    pattern = re.compile(r"(Widget _filterPanel\(\) => FilterPanel\(.*?bulkFrameIndices: _filterBulkFrames,)(.*?\n\s*\);)", re.S)
    m = pattern.search(s)
    if not m:
        raise SystemExit('CanvasScreen _filterPanel helper not found')
    tail = m.group(2)
    # Add props before the existing onClose if present, otherwise before closing.
    insertion = "\n    activeCanvasEyedropperTarget: _filterColorEyedropperTarget,\n    onStartCanvasEyedropper: _toggleFilterColorEyedropper,"
    updated = m.group(1) + insertion + tail
    s = s[:m.start()] + updated + s[m.end():]

p.write_text(s, encoding='utf-8')

# ---------------------------------------------------------------------------
# Localization. Keep all shipped locales complete so gen-l10n doesn't create
# new untranslated warnings for this feature.
# ---------------------------------------------------------------------------
translations = {
    'lib/l10n/app_ja.arb': (
        'キャンバスから色を選択',
        'タップで墨溜まりの色を選択してください',
        'タップで縁取りの色を選択してください',
    ),
    'lib/l10n/app_en.arb': (
        'Pick color from canvas',
        'Tap the canvas to choose the ink pooling color',
        'Tap the canvas to choose the outline color',
    ),
    'lib/l10n/app_es.arb': (
        'Elegir color del lienzo',
        'Toca el lienzo para elegir el color de acumulación de tinta',
        'Toca el lienzo para elegir el color del contorno',
    ),
    'lib/l10n/app_fr.arb': (
        'Choisir une couleur sur la toile',
        'Touchez la toile pour choisir la couleur de l’accumulation d’encre',
        'Touchez la toile pour choisir la couleur du contour',
    ),
    'lib/l10n/app_ko.arb': (
        '캔버스에서 색상 선택',
        '캔버스를 탭하여 먹물 고임 색상을 선택하세요',
        '캔버스를 탭하여 테두리 색상을 선택하세요',
    ),
    'lib/l10n/app_zh.arb': (
        '从画布选取颜色',
        '点击画布选择积墨颜色',
        '点击画布选择描边颜色',
    ),
    'lib/l10n/app_zh_Hant.arb': (
        '從畫布選取顏色',
        '點擊畫布選擇積墨顏色',
        '點擊畫布選擇描邊顏色',
    ),
}
for path, values in translations.items():
    p = Path(path)
    obj = json.loads(p.read_text(encoding='utf-8'))
    obj['filterCanvasEyedropperTooltip'] = values[0]
    obj['filterInkPoolEyedropperHint'] = values[1]
    obj['filterOutlineEyedropperHint'] = values[2]
    p.write_text(json.dumps(obj, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

print('filter canvas eyedropper patch applied')
