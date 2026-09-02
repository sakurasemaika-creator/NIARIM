#!/usr/bin/env python3
from pathlib import Path

path = Path('lib/services/project_service.dart')
text = path.read_text(encoding='utf-8')
old = '''  void _insertLayerById(\n    String projectId,\n    String sceneId,\n    int frameIndex,\n    String layerId,\n  ) {\n    final layer = _removedLayers[layerId];\n    if (layer == null) return;\n    _applyLayerInsert(projectId, sceneId, frameIndex, layer, 0);\n    _registerHomeIfNeeded(projectId, sceneId, frameIndex, layer);\n  }\n'''
new = '''  void _insertLayerById(\n    String projectId,\n    String sceneId,\n    int frameIndex,\n    String layerId,\n    int insertIndex,\n  ) {\n    final layer = _removedLayers[layerId];\n    if (layer == null) return;\n    _applyLayerInsert(projectId, sceneId, frameIndex, layer, insertIndex);\n    _registerHomeIfNeeded(projectId, sceneId, frameIndex, layer);\n  }\n'''
count = text.count(old)
if count != 1:
    raise SystemExit(f'guard failed: expected exactly one _insertLayerById block, found {count}')
path.write_text(text.replace(old, new), encoding='utf-8', newline='\n')
print('patched project_service.dart: layer undo/redo now preserves insert index')
