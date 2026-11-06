from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f'context patch marker missing: {path}')
    p.write_text(text.replace(old, new, 1))

replace_once(
    'lib/screens/canvas/canvas_screen.dart',
    '''    context.read<CustomAutomationService>().recordStep(
      surface: CustomAutomationSurface.canvas,
      command: command,
      label: label,
      args: args,
      changesFrame: changesFrame,
      changesScene: changesScene,
    );''',
    '''    final scenes = context.read<ProjectService>().scenesOf(widget.projectId);
    final sceneIndex = scenes.indexWhere((scene) => scene.id == _currentSceneId);
    context.read<CustomAutomationService>().recordStep(
      surface: CustomAutomationSurface.canvas,
      command: command,
      label: label,
      args: args,
      changesFrame: changesFrame,
      changesScene: changesScene,
      recordedFrame: _currentFrame,
      recordedScene: sceneIndex < 0 ? null : sceneIndex,
    );''',
)

replace_once(
    'lib/screens/timeline/timeline_screen.dart',
    '''    context.read<CustomAutomationService>().recordStep(
      surface: CustomAutomationSurface.timeline,
      command: command,
      label: label,
      args: args,
      changesFrame: changesFrame,
      changesScene: changesScene,
    );''',
    '''    final sceneId = _selectedSceneId;
    final scenes = context.read<ProjectService>().scenesOf(widget.projectId);
    final sceneIndex = sceneId == null
        ? -1
        : scenes.indexWhere((scene) => scene.id == sceneId);
    context.read<CustomAutomationService>().recordStep(
      surface: CustomAutomationSurface.timeline,
      command: command,
      label: label,
      args: args,
      changesFrame: changesFrame,
      changesScene: changesScene,
      recordedFrame: _currentFrame,
      recordedScene: sceneIndex < 0 ? null : sceneIndex,
    );''',
)
print('custom automation context patch applied')
