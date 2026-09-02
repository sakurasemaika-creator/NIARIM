from pathlib import Path

path = Path('lib/screens/timeline/timeline_screen.dart')
text = path.read_text()
old = """          IconButton(\n            icon: const Row(\n              mainAxisSize: MainAxisSize.min,\n              children: [\n                Icon(Icons.arrow_back),\n                Icon(Icons.palette_outlined, size: 18),\n              ],\n            ),\n            tooltip: l10n.timelineBackToCanvasTooltip,\n            onPressed: _saveAndGoToCanvas,\n          ),\n"""
new = """          IconButton(\n            icon: const SizedBox(\n              width: 24,\n              height: 24,\n              child: Stack(\n                clipBehavior: Clip.none,\n                children: [\n                  Positioned(left: 0, top: 0, child: Icon(Icons.arrow_back, size: 22)),\n                  Positioned(\n                    right: -2,\n                    bottom: -2,\n                    child: Icon(Icons.palette_outlined, size: 12),\n                  ),\n                ],\n              ),\n            ),\n            tooltip: l10n.timelineBackToCanvasTooltip,\n            onPressed: _saveAndGoToCanvas,\n          ),\n"""
if old not in text:
    raise SystemExit('target timeline back-button block was not found')
path.write_text(text.replace(old, new, 1))
