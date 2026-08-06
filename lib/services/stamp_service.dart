import 'package:flutter/foundation.dart';
import '../models/stamp.dart';

class StampFolder {
  final String id;
  final String name;
  final bool isFavorite;
  StampFolder({required this.id, required this.name, this.isFavorite = false});
}

class StampService extends ChangeNotifier {
  final List<Stamp> _stamps = [];
  final List<StampFolder> _folders = [];
  Stamp? _currentStamp;

  List<Stamp> get stamps => List.unmodifiable(_stamps);
  List<StampFolder> get folders => List.unmodifiable(_folders);
  Stamp? get currentStamp => _currentStamp;

  Future<void> init() async {
    _stamps.addAll([
      const Stamp(id: 'Stamp0001', name: '三角形'),
      const Stamp(id: 'Stamp0002', name: '五角形'),
      const Stamp(id: 'Stamp0003', name: '六角形'),
      const Stamp(id: 'Stamp0004', name: '星'),
      const Stamp(id: 'Stamp0005', name: 'ハート'),
      const Stamp(id: 'Stamp0006', name: '吹き出し'),
      const Stamp(id: 'Stamp0007', name: '矢印'),
    ]);
    _currentStamp = _stamps.first;
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
    }
  }

  void addStamp(Stamp stamp) {
    _stamps.add(stamp);
    notifyListeners();
  }

  void deleteStamp(String id) {
    _stamps.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  void updateStamp(Stamp stamp) {
    final idx = _stamps.indexWhere((s) => s.id == stamp.id);
    if (idx >= 0) {
      _stamps[idx] = stamp;
      notifyListeners();
    }
  }
}
