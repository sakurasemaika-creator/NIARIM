import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stamp.dart';

class StampFolder {
  final String id;
  final String name;
  final bool isFavorite;
  StampFolder({required this.id, required this.name, this.isFavorite = false});
}

/// スタンプ管理サービス（仕様書17）。SharedPreferencesへ永続化する
/// （端末単位。プロジェクトファイルには含めない）。従来はインメモリのみで、
/// お気に入り・追加・削除・編集のすべてがアプリ再起動のたびに失われていた。
class StampService extends ChangeNotifier {
  static const _prefsKey = 'stamps';

  final List<Stamp> _stamps = [];
  final List<StampFolder> _folders = [];
  Stamp? _currentStamp;

  List<Stamp> get stamps => List.unmodifiable(_stamps);
  List<StampFolder> get folders => List.unmodifiable(_folders);
  Stamp? get currentStamp => _currentStamp;

  static List<Stamp> _defaultStamps() => [
        const Stamp(id: 'Stamp0001', name: '三角形'),
        const Stamp(id: 'Stamp0002', name: '五角形'),
        const Stamp(id: 'Stamp0003', name: '六角形'),
        const Stamp(id: 'Stamp0004', name: '星'),
        const Stamp(id: 'Stamp0005', name: 'ハート'),
        const Stamp(id: 'Stamp0006', name: '吹き出し'),
        const Stamp(id: 'Stamp0007', name: '矢印'),
      ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey);
    _stamps.clear();
    if (raw == null) {
      _stamps.addAll(_defaultStamps());
      await _persist();
    } else {
      _stamps.addAll(raw.map((s) => Stamp.fromJson(jsonDecode(s) as Map<String, dynamic>)));
    }
    _currentStamp = _stamps.firstOrNull;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _stamps.map((s) => jsonEncode(s.toJson())).toList());
  }

  void selectStamp(String id) {
    _currentStamp = _stamps.firstWhere((s) => s.id == id);
    notifyListeners();
  }

  void toggleFavorite(String id) {
    final idx = _stamps.indexWhere((s) => s.id == id);
    if (idx >= 0) {
      _stamps[idx] = _stamps[idx].copyWith(isFavorite: !_stamps[idx].isFavorite);
      notifyListeners();
      _persist();
    }
  }

  void addStamp(Stamp stamp) {
    _stamps.add(stamp);
    notifyListeners();
    _persist();
  }

  void deleteStamp(String id) {
    _stamps.removeWhere((s) => s.id == id);
    notifyListeners();
    _persist();
  }

  void updateStamp(Stamp stamp) {
    final idx = _stamps.indexWhere((s) => s.id == stamp.id);
    if (idx >= 0) {
      _stamps[idx] = stamp;
      notifyListeners();
      _persist();
    }
  }
}
