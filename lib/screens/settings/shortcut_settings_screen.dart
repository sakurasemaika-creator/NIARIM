import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/shortcut_binding.dart';
import '../../services/brush_service.dart';
import '../../services/shortcut_service.dart';
import '../../widgets/confirm_delete.dart';
import '../../widgets/editable_slider_value.dart';
import '../../widgets/help_button.dart';
import '../../widgets/responsive.dart';
import '../../widgets/stepped_slider.dart';

/// キーボード・左手デバイス用ショートカットの設定画面。
/// ツール選択（早替えツールと同じ粒度：ツール＋ブラシ＋太さ）と、
/// Undo/Redoなどの主要操作の両方を、キー＋修飾キーの組み合わせへ
/// 割り当てる。キャンバス・タイムライン両モードで共通の設定。
class ShortcutSettingsScreen extends StatelessWidget {
  const ShortcutSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = context.watch<ShortcutService>();
    final bindings = service.bindings;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.shortcutSettingsTitle),
        actions: const [HelpButton(topic: 'ショートカット設定')],
      ),
      body: desktopCentered(
        context,
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.shortcutSettingsHint,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: bindings.isEmpty
                  ? Center(
                      child: Text(
                        l10n.shortcutEmpty,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: bindings.length,
                      itemBuilder: (context, index) {
                        final b = bindings[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: _keyChip(context, b.comboLabel),
                            title: Text(
                              b.label,
                              style: const TextStyle(fontFamily: 'Kuramubon'),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: l10n.commonDelete,
                              onPressed: () async {
                                if (!await confirmDelete(
                                  context,
                                  itemName: b.label,
                                )) {
                                  return;
                                }
                                service.removeBinding(b.id);
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startAddFlow(context, service),
        icon: const Icon(Icons.add),
        label: Text(l10n.commonAdd),
      ),
    );
  }

  Widget _keyChip(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _startAddFlow(
    BuildContext context,
    ShortcutService service,
  ) async {
    final captured = await _showKeyCaptureDialog(context);
    if (captured == null || !context.mounted) return;
    await _showActionPicker(context, service, captured);
  }

  /// 「キーを押してください」ダイアログ：次に押されたキー＋その時点の
  /// 修飾キー状態を記録して返す。
  Future<_CapturedKey?> _showKeyCaptureDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<_CapturedKey>(
      context: context,
      builder: (ctx) => _KeyCaptureDialog(l10n: l10n),
    );
  }

  Future<void> _showActionPicker(
    BuildContext context,
    ShortcutService service,
    _CapturedKey captured,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final brushService = context.read<BrushService>();
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                l10n.shortcutChooseActionTitle(captured.comboLabel),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Kuramubon',
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              title: Text(
                l10n.shortcutActionTypeTool,
                style: const TextStyle(fontFamily: 'Kuramubon'),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                _showToolPicker(context, service, captured, brushService);
              },
            ),
            ListTile(
              title: Text(
                l10n.shortcutActionTypeCommand,
                style: const TextStyle(fontFamily: 'Kuramubon'),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                _showCommandPicker(context, service, captured);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showToolPicker(
    BuildContext context,
    ShortcutService service,
    _CapturedKey captured,
    BrushService brushService,
  ) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final brush in brushService.brushes)
              ListTile(
                leading: const Icon(Icons.brush),
                title: Text(brush.name),
                onTap: () {
                  Navigator.pop(ctx);
                  _showSizeDialog(
                    context,
                    service,
                    captured,
                    brush.id,
                    brush.name,
                    brush.size,
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.auto_fix_high),
              title: Text(l10n.quickToolEraser),
              onTap: () => _saveToolBinding(
                context,
                service,
                captured,
                toolKey: 'eraser',
                label: l10n.quickToolEraser,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.colorize),
              title: Text(l10n.quickToolEyedropper),
              onTap: () => _saveToolBinding(
                context,
                service,
                captured,
                toolKey: 'eyedropper',
                label: l10n.quickToolEyedropper,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.format_color_fill),
              title: Text(l10n.quickToolBucket),
              onTap: () => _saveToolBinding(
                context,
                service,
                captured,
                toolKey: 'bucket',
                label: l10n.quickToolBucket,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSizeDialog(
    BuildContext context,
    ShortcutService service,
    _CapturedKey captured,
    String brushId,
    String brushName,
    double defaultSize,
  ) {
    double size = defaultSize;
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(l10n.quickToolSizeDialogTitle(brushName)),
          content: Row(
            children: [
              Expanded(
                child: SteppedSlider(
                  value: size.clamp(1, 200),
                  min: 1,
                  max: 200,
                  label: '${size.round()}px',
                  onChanged: (v) => setS(() => size = v),
                ),
              ),
              SizedBox(
                width: 48,
                child: EditableSliderValue(
                  text: '${size.round()}px',
                  textAlign: TextAlign.center,
                  value: size,
                  min: 1,
                  max: 200,
                  onChanged: (v) => setS(() => size = v.toDouble()),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _saveToolBinding(
                  context,
                  service,
                  captured,
                  toolKey: 'pen',
                  brushId: brushId,
                  sizeOverride: size,
                  label: '$brushName ${size.round()}px',
                );
              },
              child: Text(l10n.commonAdd),
            ),
          ],
        ),
      ),
    );
  }

  void _showCommandPicker(
    BuildContext context,
    ShortcutService service,
    _CapturedKey captured,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final commands = <ShortcutCommand, String>{
      ShortcutCommand.undo: l10n.shortcutCommandUndo,
      ShortcutCommand.redo: l10n.shortcutCommandRedo,
      ShortcutCommand.toggleLayerPanel: l10n.shortcutCommandToggleLayerPanel,
      ShortcutCommand.playPause: l10n.shortcutCommandPlayPause,
      ShortcutCommand.previousFrame: l10n.shortcutCommandPreviousFrame,
      ShortcutCommand.nextFrame: l10n.shortcutCommandNextFrame,
    };
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in commands.entries)
              ListTile(
                title: Text(entry.value),
                onTap: () {
                  Navigator.pop(ctx);
                  _saveCommandBinding(
                    context,
                    service,
                    captured,
                    entry.key,
                    entry.value,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _saveToolBinding(
    BuildContext context,
    ShortcutService service,
    _CapturedKey captured, {
    required String toolKey,
    String? brushId,
    double? sizeOverride,
    required String label,
  }) {
    final binding = ShortcutBinding(
      id: 'sc_${DateTime.now().microsecondsSinceEpoch}',
      label: label,
      keyId: captured.key.keyId,
      control: captured.control,
      shift: captured.shift,
      alt: captured.alt,
      meta: captured.meta,
      toolKey: toolKey,
      brushId: brushId,
      sizeOverride: sizeOverride,
    );
    _confirmAndSave(context, service, binding);
  }

  void _saveCommandBinding(
    BuildContext context,
    ShortcutService service,
    _CapturedKey captured,
    ShortcutCommand command,
    String label,
  ) {
    final binding = ShortcutBinding(
      id: 'sc_${DateTime.now().microsecondsSinceEpoch}',
      label: label,
      keyId: captured.key.keyId,
      control: captured.control,
      shift: captured.shift,
      alt: captured.alt,
      meta: captured.meta,
      command: command,
    );
    _confirmAndSave(context, service, binding);
  }

  Future<void> _confirmAndSave(
    BuildContext context,
    ShortcutService service,
    ShortcutBinding binding,
  ) async {
    final conflict = service.findConflict(binding);
    if (conflict != null) {
      final l10n = AppLocalizations.of(context)!;
      final overwrite = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.shortcutConflictTitle),
          content: Text(
            l10n.shortcutConflictBody(binding.comboLabel, conflict.label),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.shortcutConflictOverwrite),
            ),
          ],
        ),
      );
      if (overwrite != true) return;
      service.removeBinding(conflict.id);
    }
    service.addBinding(binding);
  }
}

class _CapturedKey {
  final LogicalKeyboardKey key;
  final bool control;
  final bool shift;
  final bool alt;
  final bool meta;

  const _CapturedKey({
    required this.key,
    required this.control,
    required this.shift,
    required this.alt,
    required this.meta,
  });

  String get comboLabel {
    final parts = <String>[
      if (control) 'Ctrl',
      if (shift) 'Shift',
      if (alt) 'Alt',
      if (meta) 'Meta',
      key.keyLabel,
    ];
    return parts.join('+');
  }
}

/// 「キーを押してください」ダイアログ本体。フォーカスを持つ間に押された
/// 最初のキーイベントを記録して閉じる（修飾キー単体は無視し、次に押された
/// 実キーとその時点の修飾キー状態を組み合わせて確定する）。
class _KeyCaptureDialog extends StatefulWidget {
  final AppLocalizations l10n;
  const _KeyCaptureDialog({required this.l10n});

  @override
  State<_KeyCaptureDialog> createState() => _KeyCaptureDialogState();
}

class _KeyCaptureDialogState extends State<_KeyCaptureDialog> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  static final _modifierKeys = {
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.alt,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.meta,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
  };

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.handled;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.pop(context);
      return KeyEventResult.handled;
    }
    if (_modifierKeys.contains(event.logicalKey)) {
      return KeyEventResult.handled;
    }
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    Navigator.pop(
      context,
      _CapturedKey(
        key: event.logicalKey,
        control:
            keys.contains(LogicalKeyboardKey.controlLeft) ||
            keys.contains(LogicalKeyboardKey.controlRight),
        shift:
            keys.contains(LogicalKeyboardKey.shiftLeft) ||
            keys.contains(LogicalKeyboardKey.shiftRight),
        alt:
            keys.contains(LogicalKeyboardKey.altLeft) ||
            keys.contains(LogicalKeyboardKey.altRight),
        meta:
            keys.contains(LogicalKeyboardKey.metaLeft) ||
            keys.contains(LogicalKeyboardKey.metaRight),
      ),
    );
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      title: Text(l10n.shortcutCaptureTitle),
      content: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.keyboard, size: 40),
              const SizedBox(height: 12),
              Text(
                l10n.shortcutCaptureHint,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
      ],
    );
  }
}
