from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding="utf-8")
    if old not in text:
        if new in text:
            return
        raise SystemExit(f"anchor not found in {path}: {old[:120]!r}")
    p.write_text(text.replace(old, new, 1), encoding="utf-8")


def add_arb_entries(path: str, entries: dict[str, str]) -> None:
    p = Path(path)
    text = p.read_text(encoding="utf-8")
    missing = {k: v for k, v in entries.items() if f'"{k}"' not in text}
    if not missing:
        return
    end = text.rfind("}")
    if end < 0:
        raise SystemExit(f"invalid ARB: {path}")
    prefix = text[:end].rstrip()
    if not prefix.endswith(","):
        prefix += ","
    lines = [prefix]
    for i, (key, value) in enumerate(missing.items()):
        comma = "," if i < len(missing) - 1 else ""
        escaped = value.replace("\\", "\\\\").replace('"', '\\"')
        lines.append(f'  "{key}": "{escaped}"{comma}')
    p.write_text("\n".join(lines) + "\n}\n", encoding="utf-8")


# 1) Execution scope model: add explicit specified-frame mode.
replace_once(
    "lib/models/custom_automation.dart",
    "enum CustomAutomationExecutionScope { currentFrame, allFrames }",
    "enum CustomAutomationExecutionScope { currentFrame, specifiedFrames, allFrames }",
)

# 2) Manager callback carries an optional explicit target-frame list.
replace_once(
    "lib/widgets/custom_automation_manager_sheet.dart",
    """  final Future<void> Function(\n    CustomAutomation automation,\n    CustomAutomationExecutionScope scope,\n  )\n  onExecute;\n  final VoidCallback onRecordingStarted;\n  final int? recordingStartFrame;\n""",
    """  final Future<void> Function(\n    CustomAutomation automation,\n    CustomAutomationExecutionScope scope,\n    List<int>? targetFrames,\n  )\n  onExecute;\n  final VoidCallback onRecordingStarted;\n  final int? recordingStartFrame;\n  final int? frameCount;\n""",
)
replace_once(
    "lib/widgets/custom_automation_manager_sheet.dart",
    """    required this.onRecordingStarted,\n    this.recordingStartFrame,\n  });\n""",
    """    required this.onRecordingStarted,\n    this.recordingStartFrame,\n    this.frameCount,\n  });\n""",
)
replace_once(
    "lib/widgets/custom_automation_manager_sheet.dart",
    """    var scope = CustomAutomationExecutionScope.currentFrame;\n    final accepted = await showDialog<bool>(\n""",
    """    var scope = CustomAutomationExecutionScope.currentFrame;\n    final fromController = TextEditingController(text: '1');\n    final toController = TextEditingController(\n      text: '${frameCount ?? 1}',\n    );\n    final accepted = await showDialog<bool>(\n""",
)
replace_once(
    "lib/widgets/custom_automation_manager_sheet.dart",
    """                      RadioListTile<CustomAutomationExecutionScope>(\n                        value: CustomAutomationExecutionScope.allFrames,\n                        title: Text(l10n.customAutomationAllFrames),\n                        contentPadding: EdgeInsets.zero,\n                      ),\n""",
    """                      RadioListTile<CustomAutomationExecutionScope>(\n                        value: CustomAutomationExecutionScope.allFrames,\n                        title: Text(l10n.customAutomationAllFrames),\n                        contentPadding: EdgeInsets.zero,\n                      ),\n                      RadioListTile<CustomAutomationExecutionScope>(\n                        value: CustomAutomationExecutionScope.specifiedFrames,\n                        title: Text(l10n.customAutomationSpecifiedFrames),\n                        contentPadding: EdgeInsets.zero,\n                      ),\n                      if (scope ==\n                          CustomAutomationExecutionScope.specifiedFrames)\n                        Padding(\n                          padding: const EdgeInsets.only(\n                            left: 16,\n                            right: 16,\n                            bottom: 8,\n                          ),\n                          child: Row(\n                            children: [\n                              Expanded(\n                                child: TextField(\n                                  controller: fromController,\n                                  keyboardType: TextInputType.number,\n                                  decoration: InputDecoration(\n                                    labelText: l10n.customAutomationFrameFrom,\n                                    border: const OutlineInputBorder(),\n                                  ),\n                                ),\n                              ),\n                              const Padding(\n                                padding: EdgeInsets.symmetric(horizontal: 8),\n                                child: Text('–'),\n                              ),\n                              Expanded(\n                                child: TextField(\n                                  controller: toController,\n                                  keyboardType: TextInputType.number,\n                                  decoration: InputDecoration(\n                                    labelText: l10n.customAutomationFrameTo,\n                                    border: const OutlineInputBorder(),\n                                  ),\n                                ),\n                              ),\n                            ],\n                          ),\n                        ),\n""",
)
replace_once(
    "lib/widgets/custom_automation_manager_sheet.dart",
    """    if (accepted == true && context.mounted) {\n      Navigator.pop(context);\n      await onExecute(automation, scope);\n    }\n""",
    """    List<int>? targetFrames;\n    if (accepted == true &&\n        scope == CustomAutomationExecutionScope.specifiedFrames) {\n      final from = int.tryParse(fromController.text.trim());\n      final to = int.tryParse(toController.text.trim());\n      final maxFrame = frameCount ?? 0;\n      final valid = from != null &&\n          to != null &&\n          from >= 1 &&\n          to >= from &&\n          maxFrame > 0 &&\n          to <= maxFrame;\n      if (!valid) {\n        fromController.dispose();\n        toController.dispose();\n        if (context.mounted) {\n          ScaffoldMessenger.of(context).showSnackBar(\n            SnackBar(content: Text(l10n.customAutomationFrameRangeInvalid)),\n          );\n        }\n        return;\n      }\n      targetFrames = List<int>.generate(\n        to - from + 1,\n        (index) => from - 1 + index,\n      );\n    }\n    fromController.dispose();\n    toController.dispose();\n    if (accepted == true && context.mounted) {\n      Navigator.pop(context);\n      await onExecute(automation, scope, targetFrames);\n    }\n""",
)

# 3) Canvas integration: supply frame count and honor explicit target frames.
replace_once(
    "lib/screens/canvas/canvas_screen.dart",
    """        onRecordingStarted: _showCustomAutomationRecordingOverlay,\n        recordingStartFrame: _currentFrame,\n      ),\n""",
    """        onRecordingStarted: _showCustomAutomationRecordingOverlay,\n        recordingStartFrame: _currentFrame,\n        frameCount: context.read<ProjectService>().frameCount(\n          widget.projectId,\n          _currentSceneId,\n        ),\n      ),\n""",
)
replace_once(
    "lib/screens/canvas/canvas_screen.dart",
    """  Future<void> _executeCustomAutomation(\n    CustomAutomation automation,\n    CustomAutomationExecutionScope scope,\n  ) async {\n""",
    """  Future<void> _executeCustomAutomation(\n    CustomAutomation automation,\n    CustomAutomationExecutionScope scope,\n    List<int>? targetFrames,\n  ) async {\n""",
)
replace_once(
    "lib/screens/canvas/canvas_screen.dart",
    """    final frames = scope == CustomAutomationExecutionScope.allFrames\n        ? List<int>.generate(total, (index) => index)\n        : <int>[_currentFrame];\n""",
    """    final frames = scope == CustomAutomationExecutionScope.allFrames\n        ? List<int>.generate(total, (index) => index)\n        : scope == CustomAutomationExecutionScope.specifiedFrames\n        ? (targetFrames ?? const <int>[])\n              .where((frame) => frame >= 0 && frame < total)\n              .toList(growable: false)\n        : <int>[_currentFrame];\n    if (frames.isEmpty) return;\n""",
)

# 4) Pixel grid: canvas-only foreground overlay, 30% opacity, and include
# tone/stamp strokes whenever the active brush is in pixel mode.
replace_once(
    "lib/screens/canvas/widgets/canvas_area.dart",
    """    final pixelBrushActive =\n        currentBrush?.pixelMode == true &&\n        ((widget.currentTool == DrawingTool.pen &&\n                widget.currentSubTool == PenSubTool.brush) ||\n            widget.currentTool == DrawingTool.eraser ||\n            widget.currentTool == DrawingTool.ruler ||\n            widget.currentTool == DrawingTool.shape);\n""",
    """    final pixelBrushActive =\n        currentBrush?.pixelMode == true &&\n        ((widget.currentTool == DrawingTool.pen &&\n                (widget.currentSubTool == PenSubTool.brush ||\n                    widget.currentSubTool == PenSubTool.tone ||\n                    widget.currentSubTool == PenSubTool.stamp)) ||\n            widget.currentTool == DrawingTool.eraser ||\n            widget.currentTool == DrawingTool.ruler ||\n            widget.currentTool == DrawingTool.shape);\n""",
)
replace_once(
    "lib/screens/canvas/widgets/canvas_area.dart",
    "..color = color.withValues(alpha: 0.18)",
    "..color = color.withValues(alpha: 0.30)",
)

# 5) Localization sources. flutter gen-l10n in CI regenerates Dart accessors.
translations = {
    "app_en.arb": {
        "customAutomationSpecifiedFrames": "Run on specified frames",
        "customAutomationFrameFrom": "From frame",
        "customAutomationFrameTo": "To frame",
        "customAutomationFrameRangeInvalid": "Enter a valid frame range.",
    },
    "app_ja.arb": {
        "customAutomationSpecifiedFrames": "指定したフレームで行う",
        "customAutomationFrameFrom": "開始フレーム",
        "customAutomationFrameTo": "終了フレーム",
        "customAutomationFrameRangeInvalid": "有効なフレーム範囲を入力してください。",
    },
    "app_es.arb": {
        "customAutomationSpecifiedFrames": "Ejecutar en fotogramas especificados",
        "customAutomationFrameFrom": "Fotograma inicial",
        "customAutomationFrameTo": "Fotograma final",
        "customAutomationFrameRangeInvalid": "Introduce un intervalo de fotogramas válido.",
    },
    "app_fr.arb": {
        "customAutomationSpecifiedFrames": "Exécuter sur les images spécifiées",
        "customAutomationFrameFrom": "Image de début",
        "customAutomationFrameTo": "Image de fin",
        "customAutomationFrameRangeInvalid": "Saisissez une plage d’images valide.",
    },
    "app_ko.arb": {
        "customAutomationSpecifiedFrames": "지정한 프레임에서 실행",
        "customAutomationFrameFrom": "시작 프레임",
        "customAutomationFrameTo": "종료 프레임",
        "customAutomationFrameRangeInvalid": "올바른 프레임 범위를 입력하세요.",
    },
    "app_zh.arb": {
        "customAutomationSpecifiedFrames": "在指定帧执行",
        "customAutomationFrameFrom": "起始帧",
        "customAutomationFrameTo": "结束帧",
        "customAutomationFrameRangeInvalid": "请输入有效的帧范围。",
    },
}
for filename, entries in translations.items():
    add_arb_entries(f"lib/l10n/{filename}", entries)

print("automation scope + pixel grid patch applied")
