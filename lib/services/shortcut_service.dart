import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/shortcut_binding.dart';
import '../utils/saved_list_reader.dart';
import '../utils/tolerant_preferences.dart';
import '../utils/transfer_merge.dart';

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
    final raw = prefs.readStringList(_prefsKey);
    // 1件ずつ読む（読めない1件で起動を止めない）。
    var intact = true;
    final saved = raw == null
        ? const <ShortcutBinding>[]
        : readSavedJsonList(
            raw,
            ShortcutBinding.fromJson,
            onSkipped: () => intact = false,
          );
    if (saved.isEmpty) {
      // 既定値：従来ハードコードされていたUndo/Redoのキー割り当てを
      // そのまま初期状態として引き継ぐ。
      _bindings.addAll([
        ..._defaultUndoRedoBindings,
        ..._defaultClipboardBindings,
      ]);
      // 保存が無い（初回）・空のときだけ既定を保存する。読めない値・
      // 読めない項目だけの保存は、既定の内容で動かすだけで書き換えない。
      if (raw == null ? !prefs.containsKey(_prefsKey) : raw.isEmpty) {
        await _persist();
      }
    } else {
      _bindings.addAll(saved);
      // 既に保存済みの環境（Ctrl+A/C/X/Vが既定値に無かった旧バージョン）
      // でも、キーの組み合わせが未使用であれば追加の既定値として補う。
      var added = false;
      for (final candidate in _defaultClipboardBindings) {
        if (findConflict(candidate) == null &&
            !_bindings.any((b) => b.id == candidate.id)) {
          _bindings.add(candidate);
          added = true;
        }
      }
      // 読めない項目があった保存は、起動では書き換えない。
      if (added && intact) await _persist();
    }
  }

  static final List<ShortcutBinding> _defaultUndoRedoBindings = [
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
  ];

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

  /// 引き継ぎ（.niatra）の端末保存データで受け取ったショートカット（保存と
  /// 同じ1件ずつのJSON）のうち、この端末に無いものを足す。この端末の割り当ては
  /// 書き換えず、同じIDのもの・この端末で同じキーの組み合わせを使っている
  /// ものは足さない（1つのキーに2つの操作が付かないように）。同じキーを
  /// この端末では別の操作に使っているものは、黙って捨てずに[report]へ書く
  /// （読み込みの知らせで名前とキーを出す。同じ操作なら足したのと同じなので
  /// 書かない）。もう1台で最初のまま（触っていない）の既定の割り当ては、
  /// この端末に無ければ足さない（この端末で消した。早替えツールの最初の
  /// 登録と同じ）。ツールの割り当てのブラシと自動操作は、合わせた後でその
  /// 中身を持つこの端末のブラシ・自動操作にする（[brushIds]・
  /// [automationIds]、[transferredItemId]）。
  Future<void> mergeTransferred(
    List<String> saved, {
    Map<String, String> brushIds = const {},
    Map<String, String> automationIds = const {},
    TransferImportReport? report,
  }) async {
    final shipped = {
      for (final binding in [
        ..._defaultUndoRedoBindings,
        ..._defaultClipboardBindings,
      ])
        binding.id: jsonEncode(binding.toJson()),
    };
    var changed = false;
    for (final received in readSavedJsonList(saved, ShortcutBinding.fromJson)) {
      if (_bindings.any((b) => b.id == received.id)) continue;
      if (shipped[received.id] == jsonEncode(received.toJson())) continue;
      final brushId = transferredItemId(received.brushId, brushIds);
      final automationId = transferredItemId(
        received.automationId,
        automationIds,
      );
      final binding =
          brushId == received.brushId && automationId == received.automationId
          ? received
          : ShortcutBinding.fromJson({
              ...received.toJson(),
              'brushId': brushId,
              'automationId': automationId,
            });
      final conflict = findConflict(binding);
      if (conflict != null) {
        if (!_sameAction(conflict, binding)) {
          report?.notAddedShortcuts.add(binding);
        }
        continue;
      }
      _bindings.add(binding);
      changed = true;
    }
    if (!changed) return;
    await _persist();
    notifyListeners();
  }

  /// 2つの割り当てが同じ操作をするか（名前・IDは比べない）。
  static bool _sameAction(ShortcutBinding a, ShortcutBinding b) =>
      a.toolKey == b.toolKey &&
      a.brushId == b.brushId &&
      a.sizeOverride == b.sizeOverride &&
      a.command == b.command &&
      a.automationId == b.automationId;

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
