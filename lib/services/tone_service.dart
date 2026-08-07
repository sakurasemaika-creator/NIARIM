import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tone.dart';

class ToneFolder {
  final String id;
  final String name;
  final bool isFavorite;
  ToneFolder({required this.id, required this.name, this.isFavorite = false});
}

/// トーン管理サービス（仕様書04・17・25）。SharedPreferencesへ永続化する
/// （端末単位。プロジェクトファイルには含めない）。従来はインメモリのみで、
/// お気に入り・追加・削除・編集のすべてがアプリ再起動のたびに失われていた。
class ToneService extends ChangeNotifier {
  static const _prefsKey = 'tones';

  final List<Tone> _tones = [];
  final List<ToneFolder> _folders = [];
  Tone? _currentTone;
  // バケツ塗りと投げ縄塗りはそれぞれ独立して最後に使用したトーンを保持
  Tone? _lastBucketTone;
  Tone? _lastLassoTone;
  // 投げ縄塗り：ベタ塗り／トーンの選択状態（仕様書25）
  bool _lassoUseTone = false;
  // バケツ塗り：ベタ塗り／トーンの選択状態（仕様書04・17）
  bool _bucketUseTone = false;

  List<Tone> get tones => List.unmodifiable(_tones);
  List<ToneFolder> get folders => List.unmodifiable(_folders);
  Tone? get currentTone => _currentTone;
  Tone? get lastBucketTone => _lastBucketTone;
  Tone? get lastLassoTone => _lastLassoTone;
  bool get lassoUseTone => _lassoUseTone;
  bool get bucketUseTone => _bucketUseTone;

  void setLassoUseTone(bool value) {
    _lassoUseTone = value;
    notifyListeners();
  }

  void setBucketUseTone(bool value) {
    _bucketUseTone = value;
    notifyListeners();
  }

  static List<Tone> _defaultTones() => [
        const Tone(id: 'Tone0001', name: '網点 10%'),
        const Tone(id: 'Tone0002', name: '網点 30%'),
        const Tone(id: 'Tone0003', name: '網点 50%'),
        const Tone(id: 'Tone0004', name: '網点 70%'),
        const Tone(id: 'Tone0005', name: 'ライン 細'),
        const Tone(id: 'Tone0006', name: 'ライン 太'),
      ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey);
    _tones.clear();
    if (raw == null) {
      _tones.addAll(_defaultTones());
      await _persist();
    } else {
      _tones.addAll(raw.map((s) => Tone.fromJson(jsonDecode(s) as Map<String, dynamic>)));
    }
    _currentTone = _tones.firstOrNull;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _tones.map((t) => jsonEncode(t.toJson())).toList());
  }

  void selectTone(String id) {
    _currentTone = _tones.firstWhere((t) => t.id == id);
    notifyListeners();
  }

  void setLastBucketTone(Tone tone) {
    _lastBucketTone = tone;
    notifyListeners();
  }

  void setLastLassoTone(Tone tone) {
    _lastLassoTone = tone;
    notifyListeners();
  }

  void toggleFavorite(String id) {
    final idx = _tones.indexWhere((t) => t.id == id);
    if (idx >= 0) {
      _tones[idx] = _tones[idx].copyWith(isFavorite: !_tones[idx].isFavorite);
      notifyListeners();
      _persist();
    }
  }

  void addTone(Tone tone) {
    _tones.add(tone);
    notifyListeners();
    _persist();
  }

  void deleteTone(String id) {
    _tones.removeWhere((t) => t.id == id);
    notifyListeners();
    _persist();
  }

  void updateTone(Tone tone) {
    final idx = _tones.indexWhere((t) => t.id == tone.id);
    if (idx >= 0) {
      _tones[idx] = tone;
      notifyListeners();
      _persist();
    }
  }
}
