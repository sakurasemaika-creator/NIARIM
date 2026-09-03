from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        if new in text:
            print(f'{label}: already applied')
            return text
        raise SystemExit(f'{label}: pattern not found')
    return text.replace(old, new, 1)

# 1) Selection toolbar default: rectangle -> lasso.
toolbar = Path('lib/screens/canvas/widgets/toolbar_widget.dart')
s = toolbar.read_text()
s = replace_once(
    s,
    '        onPressed: () => onToolSelected(DrawingTool.selectRect),',
    '        onPressed: () => onToolSelected(DrawingTool.selectLasso),',
    'default lasso selection',
)
toolbar.write_text(s)

# 2) CanvasScreen tokens + left-bottom Select All / Deselect controls.
screen = Path('lib/screens/canvas/canvas_screen.dart')
s = screen.read_text()
s = replace_once(
    s,
    '  int _invertSelectionToken = 0;\n',
    '  int _invertSelectionToken = 0;\n  int _selectAllSelectionToken = 0;\n  int _clearSelectionToken = 0;\n',
    'selection command tokens',
)
s = replace_once(
    s,
    '                                  invertSelectionToken: _invertSelectionToken,\n',
    '                                  invertSelectionToken: _invertSelectionToken,\n                                  selectAllSelectionToken: _selectAllSelectionToken,\n                                  clearSelectionToken: _clearSelectionToken,\n',
    'selection token wiring',
)
anchor = '''                                ),
                                // ツールオプション系フローティングパネル（ブラシ・トーン・'''
overlay = '''                                ),
                                if (_isSelectionToolActive)
                                  Positioned(
                                    left: 12,
                                    bottom: 12,
                                    child: SafeArea(
                                      child: Material(
                                        elevation: 4,
                                        borderRadius: BorderRadius.circular(10),
                                        child: Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              FilledButton.tonalIcon(
                                                onPressed: () => setState(
                                                  () => _selectAllSelectionToken++,
                                                ),
                                                icon: const Icon(Icons.select_all),
                                                label: const Text('全選択'),
                                              ),
                                              const SizedBox(width: 6),
                                              FilledButton.tonalIcon(
                                                onPressed: _hasActiveSelection
                                                    ? () => setState(
                                                        () => _clearSelectionToken++,
                                                      )
                                                    : null,
                                                icon: const Icon(Icons.deselect),
                                                label: const Text('全解除'),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                // ツールオプション系フローティングパネル（ブラシ・トーン・'''
s = replace_once(s, anchor, overlay, 'selection left-bottom controls')
screen.write_text(s)

# 3) CanvasArea: receive commands and operate the real selection mask.
area = Path('lib/screens/canvas/widgets/canvas_area.dart')
s = area.read_text()
s = replace_once(
    s,
    '  final int invertSelectionToken;\n  final ValueChanged<bool>? onSelectionActiveChanged;\n',
    '  final int invertSelectionToken;\n  final int selectAllSelectionToken;\n  final int clearSelectionToken;\n  final ValueChanged<bool>? onSelectionActiveChanged;\n',
    'CanvasArea selection token fields',
)
s = replace_once(
    s,
    '    this.invertSelectionToken = 0,\n    this.onSelectionActiveChanged,\n',
    '    this.invertSelectionToken = 0,\n    this.selectAllSelectionToken = 0,\n    this.clearSelectionToken = 0,\n    this.onSelectionActiveChanged,\n',
    'CanvasArea selection token ctor',
)
s = replace_once(
    s,
    '''    if (old.invertSelectionToken != widget.invertSelectionToken) {
      _invertSelectionMask();
    }
''',
    '''    if (old.invertSelectionToken != widget.invertSelectionToken) {
      _invertSelectionMask();
    }
    if (old.selectAllSelectionToken != widget.selectAllSelectionToken) {
      _selectAllSelectionMask();
    }
    if (old.clearSelectionToken != widget.clearSelectionToken) {
      _clearSelectionMask();
    }
''',
    'CanvasArea selection command handling',
)
marker = '''  /// 選択範囲を反転する（選択されていた部分と外側を入れ替える）。
'''
method = '''  /// キャンバスの全ピクセルを選択する。UIの「全選択」から呼ばれる。
  void _selectAllSelectionMask() {
    final w = _tileManager.canvasWidth;
    final h = _tileManager.canvasHeight;
    _setSelectionMask(Uint8List(w * h)..fillRange(0, w * h, 0xFF), w, h);
  }

'''
if method not in s:
    if marker not in s:
        raise SystemExit('select-all insertion marker not found')
    s = s.replace(marker, method + marker, 1)
area.write_text(s)

print('selection requirements applied')
