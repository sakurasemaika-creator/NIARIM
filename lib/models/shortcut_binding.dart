import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show SingleActivator;

/// キーボード・左手デバイス用ショートカットに割り当てられる、
/// ツール選択・カスタム自動操作以外の主要操作。
enum ShortcutCommand {
  undo,
  redo,
  toggleLayerPanel,
  playPause,
  previousFrame,
  nextFrame,
  selectAll,
  copy,
  cut,
  paste,
}

/// キーボード・左手デバイス用ショートカットの1件分の割り当て。
/// 割り当て先は次のいずれか1つ：
/// - ツール選択 → [toolKey]（必須）・[brushId]・[sizeOverride]
/// - 主要操作 → [command]
/// - Premiumのカスタム自動操作 → [automationId]
class ShortcutBinding {
  final String id;
  final String label;
  final int keyId; // LogicalKeyboardKey.keyId
  final bool control;
  final bool shift;
  final bool alt;
  final bool meta;
  final String? toolKey;
  final String? brushId;
  final double? sizeOverride;
  final ShortcutCommand? command;
  final String? automationId;

  const ShortcutBinding({
    required this.id,
    required this.label,
    required this.keyId,
    this.control = false,
    this.shift = false,
    this.alt = false,
    this.meta = false,
    this.toolKey,
    this.brushId,
    this.sizeOverride,
    this.command,
    this.automationId,
  });

  LogicalKeyboardKey get key => LogicalKeyboardKey(keyId);

  bool get isToolAction => toolKey != null;
  bool get isAutomationAction => automationId != null;

  SingleActivator get activator => SingleActivator(
    key,
    control: control,
    shift: shift,
    alt: alt,
    meta: meta,
  );

  /// 同じキー＋修飾キーの組み合わせかどうか（重複登録の検出に使用）。
  bool sameKeyCombo(ShortcutBinding other) =>
      keyId == other.keyId &&
      control == other.control &&
      shift == other.shift &&
      alt == other.alt &&
      meta == other.meta;

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

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'keyId': keyId,
    'control': control,
    'shift': shift,
    'alt': alt,
    'meta': meta,
    'toolKey': toolKey,
    'brushId': brushId,
    'sizeOverride': sizeOverride,
    'command': command?.name,
    'automationId': automationId,
  };

  factory ShortcutBinding.fromJson(Map<String, dynamic> json) =>
      ShortcutBinding(
        id: json['id'] as String,
        label: json['label'] as String,
        keyId: json['keyId'] as int,
        control: json['control'] as bool? ?? false,
        shift: json['shift'] as bool? ?? false,
        alt: json['alt'] as bool? ?? false,
        meta: json['meta'] as bool? ?? false,
        toolKey: json['toolKey'] as String?,
        brushId: json['brushId'] as String?,
        sizeOverride: (json['sizeOverride'] as num?)?.toDouble(),
        command: (json['command'] as String?) == null
            ? null
            : ShortcutCommand.values.byName(json['command'] as String),
        automationId: json['automationId'] as String?,
      );
}
