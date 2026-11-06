from pathlib import Path
import json

# 1) 選択ツール既定を投げ縄へ
p = Path('lib/screens/canvas/widgets/toolbar_widget.dart')
s = p.read_text()
s = s.replace(
    'onPressed: () => onToolSelected(DrawingTool.selectRect),',
    'onPressed: () => onToolSelected(DrawingTool.selectLasso),',
    1,
)
p.write_text(s)

# 2) CanvasArea に全選択/全解除トークンを追加
p = Path('lib/screens/canvas/widgets/canvas_area.dart')
s = p.read_text()
anchor = '  final int invertSelectionToken;\n  final ValueChanged<bool>? onSelectionActiveChanged;'
if anchor in s and 'selectAllSelectionToken' not in s:
    s = s.replace(anchor, '''  final int invertSelectionToken;\n  final int selectAllSelectionToken;\n  final int clearSelectionToken;\n  final ValueChanged<bool>? onSelectionActiveChanged;''', 1)

anchor = '    this.invertSelectionToken = 0,\n    this.onSelectionActiveChanged,'
if anchor in s and 'this.selectAllSelectionToken' not in s:
    s = s.replace(anchor, '''    this.invertSelectionToken = 0,\n    this.selectAllSelectionToken = 0,\n    this.clearSelectionToken = 0,\n    this.onSelectionActiveChanged,''', 1)

anchor = '''    if (old.invertSelectionToken != widget.invertSelectionToken) {\n      _invertSelectionMask();\n    }\n  }'''
if anchor in s and 'old.selectAllSelectionToken' not in s:
    s = s.replace(anchor, '''    if (old.invertSelectionToken != widget.invertSelectionToken) {\n      _invertSelectionMask();\n    }\n    if (old.selectAllSelectionToken != widget.selectAllSelectionToken) {\n      _selectAllSelectionMask();\n    }\n    if (old.clearSelectionToken != widget.clearSelectionToken) {\n      _clearSelectionMask();\n    }\n  }''', 1)

anchor = '  /// 選択範囲を反転する（選択されていた部分と外側を入れ替える）。'
if anchor in s and '_selectAllSelectionMask()' not in s:
    s = s.replace(anchor, '''  /// キャンバス全域を選択する。左下の「全選択」ボタンから呼ばれる。\n  void _selectAllSelectionMask() {\n    final w = _tileManager.canvasWidth;\n    final h = _tileManager.canvasHeight;\n    final mask = Uint8List(w * h);\n    mask.fillRange(0, mask.length, 0xFF);\n    _setSelectionMask(mask, w, h);\n  }\n\n''' + anchor, 1)
p.write_text(s)

# 3) CanvasScreen: トークンと左下常設ボタンを追加
p = Path('lib/screens/canvas/canvas_screen.dart')
s = p.read_text()
anchor = '  int _invertSelectionToken = 0;'
if anchor in s and '_selectAllSelectionToken' not in s:
    s = s.replace(anchor, '''  int _invertSelectionToken = 0;\n  int _selectAllSelectionToken = 0;\n  int _clearSelectionToken = 0;''', 1)

anchor = '''                                  invertSelectionToken: _invertSelectionToken,\n                                  onSelectionActiveChanged: (v) {'''
if anchor in s and 'selectAllSelectionToken:' not in s:
    s = s.replace(anchor, '''                                  invertSelectionToken: _invertSelectionToken,\n                                  selectAllSelectionToken: _selectAllSelectionToken,\n                                  clearSelectionToken: _clearSelectionToken,\n                                  onSelectionActiveChanged: (v) {''', 1)

anchor = '''                                  },\n                                ),\n                                // ツールオプション系フローティングパネル'''
if anchor in s and 'selection_select_all_floating' not in s:
    controls = '''                                  },\n                                ),\n                                if (_isSelectionToolActive)\n                                  Positioned(\n                                    left: 12,\n                                    bottom: 12,\n                                    child: Material(\n                                      key: const ValueKey('selection_select_all_floating'),\n                                      elevation: 4,\n                                      borderRadius: BorderRadius.circular(10),\n                                      color: Theme.of(context).colorScheme.surfaceContainerHigh,\n                                      child: Padding(\n                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),\n                                        child: Row(\n                                          mainAxisSize: MainAxisSize.min,\n                                          children: [\n                                            TextButton.icon(\n                                              onPressed: () => setState(() => _selectAllSelectionToken++),\n                                              icon: const Icon(Icons.select_all, size: 18),\n                                              label: const Text('全選択'),\n                                            ),\n                                            const SizedBox(width: 2),\n                                            TextButton.icon(\n                                              onPressed: _hasActiveSelection\n                                                  ? () => setState(() => _clearSelectionToken++)\n                                                  : null,\n                                              icon: const Icon(Icons.deselect, size: 18),\n                                              label: const Text('全解除'),\n                                            ),\n                                          ],\n                                        ),\n                                      ),\n                                    ),\n                                  ),\n                                // ツールオプション系フローティングパネル'''
    s = s.replace(anchor, controls, 1)
p.write_text(s)

# 4) 監査台帳へ追加（未確認として登録）
p = Path('audit-dashboard/feature-audit-manifest.json')
data = json.loads(p.read_text())
features = data['features']
existing = {f['id'] for f in features}
new_features = [
    {
        'id':'timeline.bulk_duration_change','category':'アニメーション','name':'タイムラインのフレーム枚数一括変更',
        'interaction':False,'output':False,'screenshot':False,'visual':False,'final_pass':False,'device_required':False,
        'workflows':['audit-continuous-queue.yml'],
        'recheck_reason':'1枚ずつの追加だけでなくスライダー/数値入力で複数フレームを一括変更し、指定値どおりの総フレーム数になることを実操作で確認'
    },
    {
        'id':'selection.pixel_nudge','category':'塗り/選択','name':'選択範囲移動のX/Y 1px微調整',
        'interaction':False,'output':False,'screenshot':False,'visual':False,'final_pass':False,'device_required':False,
        'workflows':['audit-continuous-queue.yml'],
        'recheck_reason':'X/Yそれぞれのスライダー・数値入力・±1px微調整を操作し、実画素が指定方向へ正確に1pxずつ移動することを画像差分と座標で確認'
    },
    {
        'id':'selection.select_all_clear','category':'塗り/選択','name':'選択ツールの全選択・全解除',
        'interaction':False,'output':False,'screenshot':False,'visual':False,'final_pass':False,'device_required':False,
        'workflows':['audit-continuous-queue.yml'],
        'recheck_reason':'選択ツール中だけ左下に常時表示され、全選択でキャンバス全域、全解除で選択マスクが完全に消えることを実操作とスクリーンショットで確認'
    },
    {
        'id':'selection.default_lasso','category':'塗り/選択','name':'選択ツールの既定が投げ縄',
        'interaction':False,'output':False,'screenshot':False,'visual':False,'final_pass':False,'device_required':False,
        'workflows':['audit-continuous-queue.yml'],
        'recheck_reason':'選択ツールを通常タップした直後に矩形ではなく投げ縄が選択されることをUI状態と実操作で確認'
    },
]
for f in new_features:
    if f['id'] not in existing:
        features.append(f)
p.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
print('selection/timeline audit requirements applied')
