import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/quick_tool_entry.dart';
import '../utils/saved_list_reader.dart';
import '../utils/transfer_merge.dart';
import '../utils/tolerant_preferences.dart';

/// ツール早替え機能（「↺ ツール早替えボタン」）。
/// 登録済みツールを順番にサイクルし、最後まで行くと先頭へループする。
/// 早替えツールの編集はキャンバス上のポップアップで行う（設定画面では管理しない）。
class QuickToolService extends ChangeNotifier {
  static const _prefsKey = 'quick_tool_entries';

  final List<QuickToolEntry> _entries = [];

  /// 最初から登録してある早替えツール（どの端末にも同じIDである）。
  static const List<QuickToolEntry> _defaults = [
    QuickToolEntry(
      id: 'qt1',
      label: 'Gペン 細',
      toolKey: 'pen',
      brushId: 'Brush0002',
      sizeOverride: 3,
    ),
    QuickToolEntry(
      id: 'qt2',
      label: 'Gペン 太',
      toolKey: 'pen',
      brushId: 'Brush0002',
      sizeOverride: 8,
    ),
    QuickToolEntry(
      id: 'qt3',
      label: 'エアブラシ',
      toolKey: 'pen',
      brushId: 'Brush0003',
    ),
    QuickToolEntry(id: 'qt4', label: '消しゴム', toolKey: 'eraser'),
    QuickToolEntry(id: 'qt5', label: 'スポイト', toolKey: 'eyedropper'),
  ];
  int _currentIndex = -1;

  List<QuickToolEntry> get entries => List.unmodifiable(_entries);

  Future<void> init() async {
    if (_entries.isNotEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.readStringList(_prefsKey);
    // 1件ずつ読む（読めない1件で起動を止めない）。
    final saved = raw == null
        ? const <QuickToolEntry>[]
        : readSavedJsonList(raw, QuickToolEntry.fromJson);
    if (saved.isEmpty) {
      _entries.addAll(_defaults);
      // 保存が無い（初回）・空のときだけ既定を保存する。読めない値・
      // 読めない項目だけの保存は、既定の内容で動かすだけで書き換えない。
      if (raw == null ? !prefs.containsKey(_prefsKey) : raw.isEmpty) {
        await _persist();
      }
    } else {
      _entries.addAll(saved);
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKey,
      _entries.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  /// 引き継ぎ（.niatra）の端末保存データで受け取った早替えツール（保存と
  /// 同じ1件ずつのJSON）を、この端末の登録へ足す。この端末の登録は書き換え
  /// ない（同じIDで中身か名前が違えば、受け取った方を「名前 (コピー)」として
  /// 足す。最初からある登録は、この端末でそのままなら受け取った方にする。
  /// 決まりは[mergeTransferredItems]）。使うブラシは、合わせた後でその
  /// ブラシの中身を持つこの端末のブラシにする（[brushIds]、
  /// [transferredBrushId]）。比べるときは、もう1台のブラシと、引き継ぎで
  /// その版を足したこの端末の複製を同じブラシとみなす（もう1台がブラシを
  /// この端末と同じ版にしてから送り直しても、複製を指す早替えツールを
  /// 別の物として足さない。[TransferCopyRecord.origin]）。
  Future<void> mergeTransferred(
    List<String> saved, {
    required TransferCopyNames copyNames,
    Map<String, String> brushIds = const {},
  }) async {
    final shipped = {for (final entry in _defaults) entry.id: entry};
    final brushes = await TransferCopyRecord.read(TransferCopyRecord.brushes);
    // 前の読み込みでもう1台の版を足した複製（名前を変えていても見つける）。
    final copies = await TransferCopyRecord.read(TransferCopyRecord.quickTools);
    final changed = mergeTransferredItems(
      _entries,
      [
        for (final entry in readSavedJsonList(saved, QuickToolEntry.fromJson))
          _transferred(entry, brushIds),
      ],
      TransferMergeRules<QuickToolEntry>(
        idOf: (e) => e.id,
        nameOf: (e) => e.label,
        contentOf: (e) => e.toJson()
          ..remove('id')
          ..remove('label')
          ..['brushId'] = e.brushId == null ? null : brushes.origin(e.brushId!),
        organizationOf: (_) =>
            (favorite: false, tags: const [], folderId: null),
        withOrganization: (e, _) => e,
        asCopy: (e, id, name) =>
            QuickToolEntry.fromJson({...e.toJson(), 'id': id, 'label': name}),
        newId: (attempt) =>
            'qt_${DateTime.now().microsecondsSinceEpoch}_$attempt',
        copyNames: copyNames,
        shippedOf: (id) => shipped[id],
      ),
      copies: copies,
    );
    await copies.save();
    if (!changed) return;
    await _persist();
    notifyListeners();
  }

  /// 受け取った早替えツール[entry]の使うブラシを、合わせた後のこの端末の
  /// ブラシにする（[transferredBrushId]）。
  static QuickToolEntry _transferred(
    QuickToolEntry entry,
    Map<String, String> brushIds,
  ) {
    final brushId = transferredBrushId(entry.brushId, brushIds);
    if (brushId == entry.brushId) return entry;
    return QuickToolEntry(
      id: entry.id,
      label: entry.label,
      toolKey: entry.toolKey,
      brushId: brushId,
      sizeOverride: entry.sizeOverride,
    );
  }

  /// 次のツールへ進めて返す（登録が空の場合はnull）。
  QuickToolEntry? next() {
    if (_entries.isEmpty) return null;
    _currentIndex = (_currentIndex + 1) % _entries.length;
    notifyListeners();
    return _entries[_currentIndex];
  }

  void addEntry(QuickToolEntry entry) {
    _entries.add(entry);
    notifyListeners();
    _persist();
  }

  void removeEntry(String id) {
    _entries.removeWhere((e) => e.id == id);
    if (_currentIndex >= _entries.length) _currentIndex = -1;
    notifyListeners();
    _persist();
  }

  /// ワークスペースプリセットの読込用：登録内容を丸ごと置き換える（
  /// 「切り替えると表示ツール・早替えツール・パネル配置が一括で変わる」）。
  void replaceAll(List<QuickToolEntry> newEntries) {
    _entries
      ..clear()
      ..addAll(newEntries);
    _currentIndex = -1;
    notifyListeners();
    _persist();
  }

  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = _entries.removeAt(oldIndex);
    _entries.insert(newIndex, item);
    notifyListeners();
    _persist();
  }
}
