import json
from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f'marker not found in {path}: {old[:80]!r}')
    p.write_text(text.replace(old, new, 1))


# Premium gate.
replace_once(
    'lib/services/premium_service.dart',
    '  unlimitedDuration,\n}',
    '  unlimitedDuration,\n  customAutomation,\n}',
)

# Global provider.
replace_once(
    'lib/app_bootstrap.dart',
    "import 'services/quick_tool_service.dart';\n",
    "import 'services/quick_tool_service.dart';\nimport 'services/custom_automation_service.dart';\n",
)
replace_once(
    'lib/app_bootstrap.dart',
    '  final quickToolService = QuickToolService();\n  await quickToolService.init();\n',
    '  final quickToolService = QuickToolService();\n  await quickToolService.init();\n  final customAutomationService = CustomAutomationService();\n  await customAutomationService.init();\n',
)
replace_once(
    'lib/app_bootstrap.dart',
    '    ChangeNotifierProvider.value(value: quickToolService),\n',
    '    ChangeNotifierProvider.value(value: quickToolService),\n    ChangeNotifierProvider.value(value: customAutomationService),\n',
)

# Canvas integration.
p = Path('lib/screens/canvas/canvas_screen.dart')
s = p.read_text()
s = s.replace(
    "import '../../services/quick_tool_service.dart';\n",
    "import '../../services/quick_tool_service.dart';\nimport '../../services/custom_automation_service.dart';\nimport '../../services/premium_service.dart';\n",
    1,
)
s = s.replace(
    "import '../../models/shortcut_binding.dart';\n",
    "import '../../models/shortcut_binding.dart';\nimport '../../models/custom_automation.dart';\n",
    1,
)
s = s.replace(
    "import '../../widgets/scrollable_sheet_body.dart';\n",
    "import '../../widgets/scrollable_sheet_body.dart';\nimport '../../widgets/custom_automation_manager_sheet.dart';\nimport '../../widgets/custom_automation_draft_sheet.dart';\nimport '../../widgets/premium_lock_widget.dart';\n",
    1,
)
s = s.replace(
    '  double? _toolPanelWidthDragOverride;\n',
    '  double? _toolPanelWidthDragOverride;\n  OverlayEntry? _customAutomationRecordingOverlay;\n',
    1,
)
s = s.replace(
    '  @override\n  void dispose() {\n    ImmersiveMode.exitWorkspace();',
    '  @override\n  void dispose() {\n    _customAutomationRecordingOverlay?.remove();\n    _customAutomationRecordingOverlay = null;\n    ImmersiveMode.exitWorkspace();',
    1,
)
canvas_methods = r'''
  void _showCustomAutomationManager() {
    final premium = context.read<PremiumService>();
    if (!premium.isFeatureAvailable(PremiumFeature.customAutomation)) {
      showPremiumBanner(context);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CustomAutomationManagerSheet(
        surface: CustomAutomationSurface.canvas,
        onExecute: _executeCustomAutomation,
        onRecordingStarted: _showCustomAutomationRecordingOverlay,
      ),
    );
  }

  void _showCustomAutomationRecordingOverlay() {
    _customAutomationRecordingOverlay?.remove();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          CustomAutomationRecordingStopButton(
            onStop: () {
              context.read<CustomAutomationService>().stopRecording();
              entry.remove();
              if (identical(_customAutomationRecordingOverlay, entry)) {
                _customAutomationRecordingOverlay = null;
              }
              _showCustomAutomationDraftReview();
            },
          ),
        ],
      ),
    );
    _customAutomationRecordingOverlay = entry;
    Overlay.of(context).insert(entry);
  }

  void _showCustomAutomationDraftReview() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CustomAutomationDraftSheet(
        surface: CustomAutomationSurface.canvas,
        onResumeRecording: _showCustomAutomationRecordingOverlay,
      ),
    );
  }

  void _recordCanvasAutomation(
    String command,
    String label, {
    Map<String, Object?> args = const {},
    bool changesFrame = false,
    bool changesScene = false,
  }) {
    context.read<CustomAutomationService>().recordStep(
      surface: CustomAutomationSurface.canvas,
      command: command,
      label: label,
      args: args,
      changesFrame: changesFrame,
      changesScene: changesScene,
    );
  }

  Future<void> _executeCustomAutomation(
    CustomAutomation automation,
    CustomAutomationExecutionScope scope,
  ) async {
    final total = context.read<ProjectService>().frameCount(
      widget.projectId,
      _currentSceneId,
    );
    final frames = scope == CustomAutomationExecutionScope.allFrames
        ? List<int>.generate(total, (index) => index)
        : <int>[_currentFrame];
    for (final frame in frames) {
      for (final step in automation.steps) {
        if (step.surface != CustomAutomationSurface.canvas) {
          throw StateError('Timeline command cannot run from Canvas mode');
        }
        await _executeCanvasAutomationStep(step, frame);
      }
    }
  }

  Future<void> _executeCanvasAutomationStep(
    CustomAutomationStep step,
    int targetFrame,
  ) async {
    switch (step.command) {
      case 'canvas.tool':
        final toolName = step.args['tool'] as String?;
        if (toolName == null) throw StateError('Missing tool');
        final tool = DrawingTool.values.where((value) => value.name == toolName).firstOrNull;
        if (tool == null) throw StateError('Unknown tool: $toolName');
        setState(() => _currentTool = tool);
      case 'canvas.brushSize':
        final value = (step.args['value'] as num?)?.toDouble();
        if (value == null) throw StateError('Missing brush size');
        setState(() => _brushSize = value);
        context.read<BrushService>().updateCurrentBrushSize(value);
      case 'canvas.brushOpacity':
        final value = (step.args['value'] as num?)?.round();
        if (value == null) throw StateError('Missing brush opacity');
        setState(() => _brushOpacity = value.clamp(0, 100));
        context.read<BrushService>().updateCurrentBrushOpacity(_brushOpacity);
      case 'canvas.color':
        final argb = (step.args['argb'] as num?)?.toInt();
        if (argb == null) throw StateError('Missing color');
        final color = Color(argb);
        setState(() => _currentColor = color);
        context.read<BrushService>().setCurrentColor(color);
      case 'canvas.selectFrame':
        final frame = (step.args['frame'] as num?)?.round();
        if (frame == null) throw StateError('Missing frame');
        if (frame < 0 || frame >= context.read<ProjectService>().frameCount(widget.projectId, _currentSceneId)) {
          throw StateError('Frame is outside the current scene');
        }
        setState(() => _currentFrame = frame);
      default:
        throw StateError('Unsupported Canvas automation command: ${step.command}');
    }
  }

  Future<void> _runAutomationBlockedAction(VoidCallback action) async {
    final service = context.read<CustomAutomationService>();
    if (!service.isRecording) {
      action();
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final stop = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.customAutomationStopConfirmTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.customAutomationStopConfirmStop),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.customAutomationStopConfirmContinue),
          ),
        ],
      ),
    );
    if (stop != true || !mounted) return;
    service.cancelDraft();
    _customAutomationRecordingOverlay?.remove();
    _customAutomationRecordingOverlay = null;
    action();
  }

'''
marker = '  /// キャンバス上部バーの「設定/編集」メニュー（\n'
if marker not in s:
    raise SystemExit('canvas edit menu marker missing')
s = s.replace(marker, canvas_methods + marker, 1)
# Add menu entry just before filters.
filter_tile = '''              ListTile(\n                leading: const Icon(Icons.blur_on),\n                title: Text(l10n.filterPanelTitle),'''
auto_tile = '''              ListTile(\n                leading: Icon(\n                  Icons.playlist_play,\n                  color: context.read<PremiumService>().isFeatureAvailable(\n                    PremiumFeature.customAutomation,\n                  )\n                      ? null\n                      : Theme.of(context).colorScheme.outline,\n                ),\n                title: Text(l10n.customAutomationTitle),\n                trailing: context.read<PremiumService>().isFeatureAvailable(\n                  PremiumFeature.customAutomation,\n                )\n                    ? null\n                    : const Icon(Icons.lock_outline, size: 18),\n                onTap: () {\n                  Navigator.pop(ctx);\n                  _showCustomAutomationManager();\n                },\n              ),\n'''
if filter_tile not in s:
    raise SystemExit('canvas filter tile marker missing')
s = s.replace(filter_tile, auto_tile + filter_tile, 1)
# Record core deterministic Canvas commands.
s = s.replace(
    '    onToolSelected: (tool) => setState(() => _currentTool = tool),',
    "    onToolSelected: (tool) {\n      setState(() => _currentTool = tool);\n      _recordCanvasAutomation('canvas.tool', tool.name, args: {'tool': tool.name});\n    },",
    1,
)
s = s.replace(
    "    onSaveTap: () => context.push('/save-tree/${widget.projectId}'),",
    "    onSaveTap: () => _runAutomationBlockedAction(\n      () => context.push('/save-tree/${widget.projectId}'),\n    ),",
    1,
)
s = s.replace(
    '                        onFrameSelected: (idx) =>\n                            setState(() => _currentFrame = idx),',
    "                        onFrameSelected: (idx) {\n                          setState(() => _currentFrame = idx);\n                          _recordCanvasAutomation(\n                            'canvas.selectFrame',\n                            'Frame ${idx + 1}',\n                            args: {'frame': idx},\n                            changesFrame: true,\n                          );\n                        },",
    1,
)
s = s.replace(
    "                        onTimelineTap: () =>\n                            context.go('/timeline/${widget.projectId}'),",
    "                        onTimelineTap: () => _runAutomationBlockedAction(\n                          () => context.go('/timeline/${widget.projectId}'),\n                        ),",
    1,
)
# Brush slider appears once in production build.
s = s.replace(
    '                        onSizeChanged: (v) {\n                          setState(() => _brushSize = v);\n                          context.read<BrushService>().updateCurrentBrushSize(\n                            v,\n                          );\n                        },',
    "                        onSizeChanged: (v) {\n                          setState(() => _brushSize = v);\n                          context.read<BrushService>().updateCurrentBrushSize(v);\n                          _recordCanvasAutomation(\n                            'canvas.brushSize',\n                            'Brush size',\n                            args: {'value': v},\n                          );\n                        },",
    1,
)
s = s.replace(
    '                        onOpacityChanged: (v) {\n                          setState(() => _brushOpacity = v);\n                          context\n                              .read<BrushService>()\n                              .updateCurrentBrushOpacity(v);\n                        },',
    "                        onOpacityChanged: (v) {\n                          setState(() => _brushOpacity = v);\n                          context.read<BrushService>().updateCurrentBrushOpacity(v);\n                          _recordCanvasAutomation(\n                            'canvas.brushOpacity',\n                            'Brush opacity',\n                            args: {'value': v},\n                          );\n                        },",
    1,
)
p.write_text(s)

# Timeline imports and menu entry. The full command coverage is intentionally semantic,
# not raw pointer replay, so cross-device imported actions stay stable.
p = Path('lib/screens/timeline/timeline_screen.dart')
s = p.read_text()
s = s.replace(
    "import '../../services/premium_service.dart';\n",
    "import '../../services/premium_service.dart';\nimport '../../services/custom_automation_service.dart';\n",
    1,
)
s = s.replace(
    "import '../../models/watermark_asset.dart';\n",
    "import '../../models/watermark_asset.dart';\nimport '../../models/custom_automation.dart';\n",
    1,
)
s = s.replace(
    "import '../../widgets/scrollable_sheet_body.dart';\n",
    "import '../../widgets/scrollable_sheet_body.dart';\nimport '../../widgets/custom_automation_manager_sheet.dart';\nimport '../../widgets/custom_automation_draft_sheet.dart';\nimport '../../widgets/premium_lock_widget.dart';\n",
    1,
)
s = s.replace(
    'class _TimelineScreenState extends State<TimelineScreen> {\n',
    'class _TimelineScreenState extends State<TimelineScreen> {\n  OverlayEntry? _customAutomationRecordingOverlay;\n',
    1,
)
timeline_methods = r'''
  void _showCustomAutomationManager() {
    final premium = context.read<PremiumService>();
    if (!premium.isFeatureAvailable(PremiumFeature.customAutomation)) {
      showPremiumBanner(context);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CustomAutomationManagerSheet(
        surface: CustomAutomationSurface.timeline,
        onExecute: _executeCustomAutomation,
        onRecordingStarted: _showCustomAutomationRecordingOverlay,
      ),
    );
  }

  void _showCustomAutomationRecordingOverlay() {
    _customAutomationRecordingOverlay?.remove();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          CustomAutomationRecordingStopButton(
            onStop: () {
              context.read<CustomAutomationService>().stopRecording();
              entry.remove();
              if (identical(_customAutomationRecordingOverlay, entry)) {
                _customAutomationRecordingOverlay = null;
              }
              _showCustomAutomationDraftReview();
            },
          ),
        ],
      ),
    );
    _customAutomationRecordingOverlay = entry;
    Overlay.of(context).insert(entry);
  }

  void _showCustomAutomationDraftReview() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CustomAutomationDraftSheet(
        surface: CustomAutomationSurface.timeline,
        onResumeRecording: _showCustomAutomationRecordingOverlay,
      ),
    );
  }

  Future<void> _executeCustomAutomation(
    CustomAutomation automation,
    CustomAutomationExecutionScope scope,
  ) async {
    if (scope == CustomAutomationExecutionScope.allFrames) {
      throw StateError('Timeline automation cannot run in all-frame scope');
    }
    for (final step in automation.steps) {
      if (step.surface != CustomAutomationSurface.timeline) {
        throw StateError('Canvas command cannot run from Timeline mode');
      }
      switch (step.command) {
        case 'timeline.selectFrame':
          final frame = (step.args['frame'] as num?)?.round();
          if (frame == null || frame < 0 || frame >= _totalFrames) {
            throw StateError('Frame is outside the current timeline');
          }
          setState(() => _currentFrame = frame);
        case 'timeline.addFrame':
          final sceneId = _selectedSceneId;
          if (sceneId == null) throw StateError('No scene selected');
          if (!_canAddFrames(1)) throw StateError('Frame limit reached');
          context.read<ProjectService>().addFrame(widget.projectId, sceneId);
        default:
          throw StateError('Unsupported Timeline automation command: ${step.command}');
      }
    }
  }

  void _recordTimelineAutomation(
    String command,
    String label, {
    Map<String, Object?> args = const {},
    bool changesFrame = false,
    bool changesScene = false,
  }) {
    context.read<CustomAutomationService>().recordStep(
      surface: CustomAutomationSurface.timeline,
      command: command,
      label: label,
      args: args,
      changesFrame: changesFrame,
      changesScene: changesScene,
    );
  }

'''
# Insert helpers before the first Timeline-specific scene menu method.
marker = '  // 三点メニュー（シーン名変更・複製・削除）\n'
if marker not in s:
    raise SystemExit('timeline helper insertion marker missing')
s = s.replace(marker, timeline_methods + marker, 1)
# Top three-dot menu handler and entry.
s = s.replace(
    "              if (action == 'autofill') _showAutofillDialog();\n",
    "              if (action == 'autofill') _showAutofillDialog();\n              if (action == 'automation') _showCustomAutomationManager();\n",
    1,
)
s = s.replace(
    '            itemBuilder: (_) => [\n              PopupMenuItem(\n                value: \'save_tree\',',
    "            itemBuilder: (_) => [\n              PopupMenuItem(\n                value: 'automation',\n                child: Row(\n                  children: [\n                    const Icon(Icons.playlist_play, size: 18),\n                    const SizedBox(width: 8),\n                    Text(l10n.customAutomationTitle),\n                  ],\n                ),\n              ),\n              PopupMenuItem(\n                value: 'save_tree',",
    1,
)
p.write_text(s)

# Localization keys in all supported ARBs.
translations = {
    'ja': {
        'customAutomationTitle': '自動操作', 'customAutomationAdd': '自動操作を新規追加',
        'customAutomationNewTitle': '新しい自動操作', 'customAutomationNameLabel': '名前',
        'customAutomationStartRecording': '操作記録開始', 'customAutomationStopRecording': '操作記録停止',
        'customAutomationRunConfirmTitle': '実行しますか？', 'customAutomationCurrentFrame': 'この操作を現在のフレームに行う',
        'customAutomationAllFrames': 'この操作を全フレームに行う', 'customAutomationRenameTitle': '名前を変更',
        'customAutomationDeleteTitle': '自動操作を削除しますか？', 'customAutomationImport': '自動操作を読み込む',
        'customAutomationExport': '自動操作を配布・書き出し', 'customAutomationRerecord': '再記録',
        'customAutomationEmpty': '記録済みの自動操作はありません', 'customAutomationImportInvalid': 'この自動操作ファイルは読み込めません',
        'customAutomationReviewHint': '手順を並べ替えたり削除してから保存できます', 'customAutomationNoRecordedSteps': '記録された操作がありません',
        'customAutomationCanvasStep': 'キャンバス操作', 'customAutomationTimelineStep': 'タイムライン操作',
        'customAutomationBackToRecording': '操作記録に戻る', 'customAutomationStopConfirmTitle': '自動操作の登録をやめますか？',
        'customAutomationStopConfirmStop': 'やめる', 'customAutomationStopConfirmContinue': '続ける',
        'customAutomationStepCount': '{count} 手順',
    },
    'en': {
        'customAutomationTitle': 'Automations', 'customAutomationAdd': 'Add automation',
        'customAutomationNewTitle': 'New automation', 'customAutomationNameLabel': 'Name',
        'customAutomationStartRecording': 'Start recording', 'customAutomationStopRecording': 'Stop recording',
        'customAutomationRunConfirmTitle': 'Run this automation?', 'customAutomationCurrentFrame': 'Run on the current frame',
        'customAutomationAllFrames': 'Run on all frames', 'customAutomationRenameTitle': 'Rename',
        'customAutomationDeleteTitle': 'Delete this automation?', 'customAutomationImport': 'Import automation',
        'customAutomationExport': 'Share / export automation', 'customAutomationRerecord': 'Re-record',
        'customAutomationEmpty': 'No recorded automations', 'customAutomationImportInvalid': 'This automation file cannot be imported',
        'customAutomationReviewHint': 'Reorder or delete steps before saving', 'customAutomationNoRecordedSteps': 'No actions were recorded',
        'customAutomationCanvasStep': 'Canvas action', 'customAutomationTimelineStep': 'Timeline action',
        'customAutomationBackToRecording': 'Back to recording', 'customAutomationStopConfirmTitle': 'Stop registering this automation?',
        'customAutomationStopConfirmStop': 'Stop', 'customAutomationStopConfirmContinue': 'Continue',
        'customAutomationStepCount': '{count} steps',
    },
    'es': {
        'customAutomationTitle': 'Automatizaciones', 'customAutomationAdd': 'Añadir automatización', 'customAutomationNewTitle': 'Nueva automatización', 'customAutomationNameLabel': 'Nombre', 'customAutomationStartRecording': 'Iniciar grabación', 'customAutomationStopRecording': 'Detener grabación', 'customAutomationRunConfirmTitle': '¿Ejecutar esta automatización?', 'customAutomationCurrentFrame': 'Ejecutar en el fotograma actual', 'customAutomationAllFrames': 'Ejecutar en todos los fotogramas', 'customAutomationRenameTitle': 'Cambiar nombre', 'customAutomationDeleteTitle': '¿Eliminar esta automatización?', 'customAutomationImport': 'Importar automatización', 'customAutomationExport': 'Compartir / exportar', 'customAutomationRerecord': 'Volver a grabar', 'customAutomationEmpty': 'No hay automatizaciones grabadas', 'customAutomationImportInvalid': 'No se puede importar este archivo', 'customAutomationReviewHint': 'Reordena o elimina pasos antes de guardar', 'customAutomationNoRecordedSteps': 'No se grabaron acciones', 'customAutomationCanvasStep': 'Acción de lienzo', 'customAutomationTimelineStep': 'Acción de línea de tiempo', 'customAutomationBackToRecording': 'Volver a grabación', 'customAutomationStopConfirmTitle': '¿Dejar de registrar esta automatización?', 'customAutomationStopConfirmStop': 'Dejar', 'customAutomationStopConfirmContinue': 'Continuar', 'customAutomationStepCount': '{count} pasos',
    },
    'fr': {
        'customAutomationTitle': 'Automatisations', 'customAutomationAdd': 'Ajouter une automatisation', 'customAutomationNewTitle': 'Nouvelle automatisation', 'customAutomationNameLabel': 'Nom', 'customAutomationStartRecording': 'Démarrer l’enregistrement', 'customAutomationStopRecording': 'Arrêter l’enregistrement', 'customAutomationRunConfirmTitle': 'Exécuter cette automatisation ?', 'customAutomationCurrentFrame': 'Exécuter sur l’image actuelle', 'customAutomationAllFrames': 'Exécuter sur toutes les images', 'customAutomationRenameTitle': 'Renommer', 'customAutomationDeleteTitle': 'Supprimer cette automatisation ?', 'customAutomationImport': 'Importer une automatisation', 'customAutomationExport': 'Partager / exporter', 'customAutomationRerecord': 'Réenregistrer', 'customAutomationEmpty': 'Aucune automatisation enregistrée', 'customAutomationImportInvalid': 'Impossible d’importer ce fichier', 'customAutomationReviewHint': 'Réordonnez ou supprimez des étapes avant d’enregistrer', 'customAutomationNoRecordedSteps': 'Aucune action enregistrée', 'customAutomationCanvasStep': 'Action de canevas', 'customAutomationTimelineStep': 'Action de timeline', 'customAutomationBackToRecording': 'Revenir à l’enregistrement', 'customAutomationStopConfirmTitle': 'Arrêter l’enregistrement de cette automatisation ?', 'customAutomationStopConfirmStop': 'Arrêter', 'customAutomationStopConfirmContinue': 'Continuer', 'customAutomationStepCount': '{count} étapes',
    },
    'ko': {
        'customAutomationTitle': '자동 작업', 'customAutomationAdd': '자동 작업 새로 추가', 'customAutomationNewTitle': '새 자동 작업', 'customAutomationNameLabel': '이름', 'customAutomationStartRecording': '작업 기록 시작', 'customAutomationStopRecording': '작업 기록 중지', 'customAutomationRunConfirmTitle': '실행하시겠습니까?', 'customAutomationCurrentFrame': '현재 프레임에 실행', 'customAutomationAllFrames': '모든 프레임에 실행', 'customAutomationRenameTitle': '이름 변경', 'customAutomationDeleteTitle': '이 자동 작업을 삭제할까요?', 'customAutomationImport': '자동 작업 불러오기', 'customAutomationExport': '자동 작업 공유 / 내보내기', 'customAutomationRerecord': '다시 기록', 'customAutomationEmpty': '기록된 자동 작업이 없습니다', 'customAutomationImportInvalid': '이 자동 작업 파일을 불러올 수 없습니다', 'customAutomationReviewHint': '저장 전에 단계 순서를 바꾸거나 삭제할 수 있습니다', 'customAutomationNoRecordedSteps': '기록된 작업이 없습니다', 'customAutomationCanvasStep': '캔버스 작업', 'customAutomationTimelineStep': '타임라인 작업', 'customAutomationBackToRecording': '기록으로 돌아가기', 'customAutomationStopConfirmTitle': '자동 작업 등록을 중지할까요?', 'customAutomationStopConfirmStop': '중지', 'customAutomationStopConfirmContinue': '계속', 'customAutomationStepCount': '{count}단계',
    },
    'zh': {
        'customAutomationTitle': '自动操作', 'customAutomationAdd': '新建自动操作', 'customAutomationNewTitle': '新自动操作', 'customAutomationNameLabel': '名称', 'customAutomationStartRecording': '开始记录操作', 'customAutomationStopRecording': '停止记录', 'customAutomationRunConfirmTitle': '要执行吗？', 'customAutomationCurrentFrame': '在当前帧执行', 'customAutomationAllFrames': '在所有帧执行', 'customAutomationRenameTitle': '重命名', 'customAutomationDeleteTitle': '删除此自动操作吗？', 'customAutomationImport': '导入自动操作', 'customAutomationExport': '分享 / 导出自动操作', 'customAutomationRerecord': '重新记录', 'customAutomationEmpty': '没有已记录的自动操作', 'customAutomationImportInvalid': '无法导入此自动操作文件', 'customAutomationReviewHint': '保存前可调整顺序或删除步骤', 'customAutomationNoRecordedSteps': '没有记录任何操作', 'customAutomationCanvasStep': '画布操作', 'customAutomationTimelineStep': '时间轴操作', 'customAutomationBackToRecording': '返回记录', 'customAutomationStopConfirmTitle': '要停止注册此自动操作吗？', 'customAutomationStopConfirmStop': '停止', 'customAutomationStopConfirmContinue': '继续', 'customAutomationStepCount': '{count} 个步骤',
    },
    'zh_Hant': {
        'customAutomationTitle': '自動操作', 'customAutomationAdd': '新增自動操作', 'customAutomationNewTitle': '新自動操作', 'customAutomationNameLabel': '名稱', 'customAutomationStartRecording': '開始記錄操作', 'customAutomationStopRecording': '停止記錄', 'customAutomationRunConfirmTitle': '要執行嗎？', 'customAutomationCurrentFrame': '在目前影格執行', 'customAutomationAllFrames': '在所有影格執行', 'customAutomationRenameTitle': '重新命名', 'customAutomationDeleteTitle': '刪除此自動操作嗎？', 'customAutomationImport': '匯入自動操作', 'customAutomationExport': '分享 / 匯出自動操作', 'customAutomationRerecord': '重新記錄', 'customAutomationEmpty': '沒有已記錄的自動操作', 'customAutomationImportInvalid': '無法匯入此自動操作檔案', 'customAutomationReviewHint': '儲存前可調整順序或刪除步驟', 'customAutomationNoRecordedSteps': '沒有記錄任何操作', 'customAutomationCanvasStep': '畫布操作', 'customAutomationTimelineStep': '時間軸操作', 'customAutomationBackToRecording': '返回記錄', 'customAutomationStopConfirmTitle': '要停止登錄此自動操作嗎？', 'customAutomationStopConfirmStop': '停止', 'customAutomationStopConfirmContinue': '繼續', 'customAutomationStepCount': '{count} 個步驟',
    },
}
for locale, values in translations.items():
    path = Path(f'lib/l10n/app_{locale}.arb')
    data = json.loads(path.read_text())
    for key, value in values.items():
        data[key] = value
    if locale == 'ja':
        data['@customAutomationStepCount'] = {
            'placeholders': {'count': {'type': 'int'}}
        }
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')

print('custom automation foundation patch applied')
