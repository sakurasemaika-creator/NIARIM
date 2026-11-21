import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/layer.dart';
import '../models/scene.dart';
import 'list_ink_clip.dart';
import 'typing_dialog_inset.dart';
import 'menu_surface.dart';

class LayerRangeDialog extends StatefulWidget {
  const LayerRangeDialog({
    super.key,
    required this.layer,
    required this.homeSceneId,
    required this.totalFrames,
    required this.scenes,
    required this.onConfirm,
    this.title,
    this.confirmLabel,
  });

  final Layer layer;
  final String homeSceneId;
  final int totalFrames;
  final List<Scene> scenes;
  final void Function(LayerRangeMode mode, int start, int end, String? sceneId)
  onConfirm;
  final String? title;
  final String? confirmLabel;

  @override
  State<LayerRangeDialog> createState() => _LayerRangeDialogState();
}

class _LayerRangeDialogState extends State<LayerRangeDialog> {
  late final TextEditingController _start;
  late final TextEditingController _end;
  late LayerRangeMode _mode;
  String? _sceneId;

  int get _lastFrame => widget.totalFrames > 0 ? widget.totalFrames : 1;

  @override
  void initState() {
    super.initState();
    _start = TextEditingController(
      text: (widget.layer.rangeStart ?? 1).toString(),
    );
    _end = TextEditingController(
      text: (widget.layer.rangeEnd ?? _lastFrame).toString(),
    );
    _mode = widget.layer.rangeMode;
    final sceneId = widget.layer.rangeSceneId ?? widget.homeSceneId;
    _sceneId = widget.scenes.any((scene) => scene.id == sceneId)
        ? sceneId
        : widget.scenes.firstOrNull?.id;
  }

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  String? _error(AppLocalizations l10n, int? start, int? end) {
    if (_mode != LayerRangeMode.frameRange) return null;
    if (start == null ||
        end == null ||
        start < 1 ||
        start > _lastFrame ||
        end < 1 ||
        end > _lastFrame) {
      return l10n.layerPanelRangeNumberError(_lastFrame);
    }
    if (start > end) return l10n.layerPanelRangeOrderError;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final start = int.tryParse(_start.text.trim(), radix: 10);
    final end = int.tryParse(_end.text.trim(), radix: 10);
    final error = _error(l10n, start, end);
    Widget frameField(TextEditingController controller, String label) =>
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        );
    return AlertDialog(
      insetPadding: typingDialogInsetPadding(context),
      title: Text(widget.title ?? l10n.layerPanelRangeDialogTitle),
      content: RadioGroup<LayerRangeMode>(
        groupValue: _mode,
        onChanged: (mode) => setState(() => _mode = mode!),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  frameField(_start, l10n.layerPanelRangeStartFrameLabel),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(l10n.layerPanelRangeTilde),
                  ),
                  frameField(_end, l10n.layerPanelRangeEndFrameLabel),
                ],
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              TextButton(
                onPressed: () => setState(() {
                  _start.text = '1';
                  _end.text = _lastFrame.toString();
                }),
                child: Text(l10n.layerPanelRangeUseCurrentButton),
              ),
              const Divider(),
              RadioListTile<LayerRangeMode>(
                dense: true,
                title: Text(l10n.layerPanelRangeAllFrames),
                value: LayerRangeMode.allFrames,
              ),
              RadioListTile<LayerRangeMode>(
                dense: true,
                title: Text(l10n.layerPanelRangeCurrentScene),
                value: LayerRangeMode.currentScene,
              ),
              RadioListTile<LayerRangeMode>(
                dense: true,
                title: Text(l10n.layerPanelRangeSceneSpecified),
                value: LayerRangeMode.sceneRange,
              ),
              if (_mode == LayerRangeMode.sceneRange)
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 8, bottom: 8),
                  child: MenuSurface(
                    child: DropdownButtonFormField<String>(
                      initialValue: _sceneId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.layerPanelRangeTargetSceneLabel,
                        isDense: true,
                      ),
                      items: [
                        for (final scene in widget.scenes)
                          DropdownMenuItem(
                            value: scene.id,
                            child: Text(scene.displayName),
                          ),
                      ],
                      onChanged: (sceneId) =>
                          setState(() => _sceneId = sceneId),
                    ),
                  ),
                ),
              RadioListTile<LayerRangeMode>(
                dense: true,
                title: Text(l10n.layerPanelRangeFrameRangeLabel),
                value: LayerRangeMode.frameRange,
              ),
            ],
          ),
        ).clipListInk(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: error == null
              ? () {
                  widget.onConfirm(
                    _mode,
                    start ?? 1,
                    end ?? start ?? 1,
                    _mode == LayerRangeMode.sceneRange ? _sceneId : null,
                  );
                  Navigator.pop(context);
                }
              : null,
          child: Text(widget.confirmLabel ?? l10n.commonOk),
        ),
      ],
    );
  }
}
