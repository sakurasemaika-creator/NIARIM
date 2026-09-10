import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/shortcut_binding.dart';

/// キーボード・左手デバイス用ショートカット。ツール選択（早替えツールと
/// 同じ粒度でツール＋ブラシ＋太さまで指定できる）と、Undo/Redoなどの
/// 主要操作の両方を、キー＋修飾キーの組み合わせへ自由に割り当てられる。
/// 設定はキャンバス・タイムライン両モードで共通（アプリ全体で1セット）。
class ShortcutService extends ChangeNotifier {
  static const _prefsKey = 'shortcut_bindings';

  final List<ShortcutBinding> _bindings = [];

  List<ShortcutBinding> get bindings => List.unmodifiable(_bindings);

  Future<void> init() async {
    if (_bindings.isNotEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey);
    if (raw == null) {
      // 既定値：従来ハードコードされていたUndo/Redoのキー割り当てを
      // そのまま初期状態として引き継ぐ。
      _bindings.addAll([
        ShortcutBinding(
          id: 'default_undo',
          label: 'Undo',
          keyId: LogicalKeyboardKey.keyZ.keyId,
          control: true,
          command: ShortcutCommand.undo,
        ),
        ShortcutBinding(
          id: 'default_redo',
          label: 'Redo',
          keyId: LogicalKeyboardKey.keyY.keyId,
          control: true,
          command: ShortcutCommand.redo,
        ),
        ShortcutBinding(
          id: 'default_redo_shift',
          label: 'Redo (Shift)',
          keyId: LogicalKeyboardKey.keyZ.keyId,
          control: true,
          shift: true,
          command: ShortcutCommand.redo,
        ),
        ..._defaultClipboardBindings,
      ]);
      await _persist();
    } else {
      _bindings.addAll(
        raw
            .map(
              (s) => ShortcutBinding.fromJson(
                jsonDecode(s) as Map<String, dynamic>,
              ),
            )
            .toList(),
      );
      // A saved list is authoritative, including an empty list or deliberately
      // removed clipboard shortcuts. New defaults belong only to first launch.
    }
  }

  static final List<ShortcutBinding> _defaultClipboardBindings = [
    ShortcutBinding(
      id: 'default_select_all',
      label: 'Select All',
      keyId: LogicalKeyboardKey.keyA.keyId,
      control: true,
      command: ShortcutCommand.selectAll,
    ),
    ShortcutBinding(
      id: 'default_copy',
      label: 'Copy',
      keyId: LogicalKeyboardKey.keyC.keyId,
      control: true,
      command: ShortcutCommand.copy,
    ),
    ShortcutBinding(
      id: 'default_cut',
      label: 'Cut',
      keyId: LogicalKeyboardKey.keyX.keyId,
      control: true,
      command: ShortcutCommand.cut,
    ),
    ShortcutBinding(
      id: 'default_paste',
      label: 'Paste',
      keyId: LogicalKeyboardKey.keyV.keyId,
      control: true,
      command: ShortcutCommand.paste,
    ),
  ];

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKey,
      _bindings.map((b) => jsonEncode(b.toJson())).toList(),
    );
  }

  void addBinding(ShortcutBinding binding) {
    _bindings.add(binding);
    notifyListeners();
    _persist();
  }

  void updateBinding(ShortcutBinding binding) {
    final idx = _bindings.indexWhere((b) => b.id == binding.id);
    if (idx < 0) return;
    _bindings[idx] = binding;
    notifyListeners();
    _persist();
  }

  void removeBinding(String id) {
    _bindings.removeWhere((b) => b.id == id);
    notifyListeners();
    _persist();
  }

  /// 同じキー＋修飾キーの組み合わせを使っている既存の割り当て
  /// （[excludeId]は自分自身の編集時に除外するため）。
  ShortcutBinding? findConflict(
    ShortcutBinding candidate, {
    String? excludeId,
  }) {
    for (final b in _bindings) {
      if (b.id == excludeId) continue;
      if (b.sameKeyCombo(candidate)) return b;
    }
    return null;
  }
}
