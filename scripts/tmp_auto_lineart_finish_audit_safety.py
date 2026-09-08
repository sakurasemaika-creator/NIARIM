from pathlib import Path

p = Path('lib/services/project_service.dart')
s = p.read_text()
old = '''    final frameLayers = layersOf(projectId, sceneId, frameIndex);
    final safeInsertIndex = insertIndex.clamp(0, frameLayers.length);'''
new = '''    final scene = sceneOf(projectId, sceneId);
    final physicalLayerCount = scene != null && frameIndex < scene.frames.length
        ? scene.frames[frameIndex].layers.length
        : 0;
    final safeInsertIndex = insertIndex.clamp(0, physicalLayerCount);'''
if old not in s:
    raise SystemExit('insert-index clamp anchor not found')
p.write_text(s.replace(old, new, 1))
