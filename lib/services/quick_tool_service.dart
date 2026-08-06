import 'package:flutter/foundation.dart';
import '../models/quick_tool_entry.dart';

/// ツール早替え機能（仕様書08・仕様書02のUI仕様「↺ ツール早替えボタン」）。
/// 登録済みツールを順番にサイクルし、最後まで行くと先頭へループする。
/// 早替えツールの編集はキャンバス上のポップアップで行う（設定画面では管理しない）。
class QuickToolService extends ChangeNotifier {
  final List<QuickToolEntry> _entries = [];
  int _currentIndex = -1;

  List<QuickToolEntry> get entries => List.unmodifiable(_entries);

  Future<void> init() async {
    if (_entries.isNotEmpty) return;
    _entries.addAll(const [
      QuickToolEntry(id: 'qt1', label: 'Gペン 細', toolKey: 'pen', brushId: 'Brush0002', sizeOverride: 3),
      QuickToolEntry(id: 'qt2', label: 'Gペン 太', toolKey: 'pen', brushId: 'Brush0002', sizeOverride: 8),
      QuickToolEntry(id: 'qt3', label: 'エアブラシ', toolKey: 'pen', brushId: 'Brush0003'),
      QuickToolEntry(id: 'qt4', label: '消しゴム', toolKey: 'eraser'),
      QuickToolEntry(id: 'qt5', label: 'スポイト', toolKey: 'eyedropper'),
    ]);
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
  }

  void removeEntry(String id) {
    _entries.removeWhere((e) => e.id == id);
    if (_currentIndex >= _entries.length) _currentIndex = -1;
    notifyListeners();
  }

  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = _entries.removeAt(oldIndex);
    _entries.insert(newIndex, item);
    notifyListeners();
  }
}
