import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import '../models/brush.dart';

class BrushService extends ChangeNotifier {
  final List<Brush> _brushes = [];
  final List<BrushFolder> _folders = [];
  Brush? _currentBrush;
  Color _currentColor = const Color(0xFF000000);

  List<Brush> get brushes => List.unmodifiable(_brushes);
  List<BrushFolder> get folders => List.unmodifiable(_folders);
  Brush? get currentBrush => _currentBrush;
  Color get currentColor => _currentColor;

  void setCurrentColor(Color color) {
    _currentColor = color;
    notifyListeners();
  }

  Future<void> init() async {
    _brushes.addAll([
      const Brush(
        id: 'Brush0001', name: 'ペン', size: 5, opacity: 100, spacing: 10,
        blurRadius: 0, stabilization: true, stabilizationStrength: 50,
        dotPenMode: false, pressureMode: PressureMode.size, pressureStrength: 80,
        fadeMode: FadeMode.off, strokeDecay: false,
        mixingMode: BrushMixingMode.off, mixingRate: 0,
      ),
      const Brush(
        id: 'Brush0002', name: 'Gペン', size: 3, opacity: 100, spacing: 5,
        blurRadius: 0, stabilization: true, stabilizationStrength: 60,
        dotPenMode: false, pressureMode: PressureMode.sizeAndOpacity, pressureStrength: 90,
        fadeMode: FadeMode.weak, strokeDecay: false,
        mixingMode: BrushMixingMode.off, mixingRate: 0,
      ),
      const Brush(
        id: 'Brush0003', name: 'エアブラシ', size: 30, opacity: 40, spacing: 3,
        blurRadius: 50, stabilization: false, stabilizationStrength: 0,
        dotPenMode: false, pressureMode: PressureMode.opacity, pressureStrength: 70,
        fadeMode: FadeMode.off, strokeDecay: false,
        mixingMode: BrushMixingMode.off, mixingRate: 0,
      ),
      const Brush(
        id: 'Brush0004', name: '混色ブラシ', size: 15, opacity: 80, spacing: 8,
        blurRadius: 10, stabilization: false, stabilizationStrength: 0,
        dotPenMode: false, pressureMode: PressureMode.size, pressureStrength: 60,
        fadeMode: FadeMode.off, strokeDecay: false,
        mixingMode: BrushMixingMode.simple, mixingRate: 50,
      ),
    ]);
    _currentBrush = _brushes.first;
  }

  void selectBrush(String id) {
    _currentBrush = _brushes.firstWhere((b) => b.id == id);
    notifyListeners();
  }

  void updateCurrentBrushSize(double size) {
    if (_currentBrush != null) {
      _currentBrush = _currentBrush!.copyWith(size: size);
      notifyListeners();
    }
  }

  void updateCurrentBrushOpacity(int opacity) {
    if (_currentBrush != null) {
      _currentBrush = _currentBrush!.copyWith(opacity: opacity);
      notifyListeners();
    }
  }

  void addBrush(Brush brush) {
    _brushes.add(brush);
    notifyListeners();
  }

  void deleteBrush(String id) {
    _brushes.removeWhere((b) => b.id == id);
    notifyListeners();
  }

  void duplicateBrush(String id) {
    final brush = _brushes.firstWhere((b) => b.id == id);
    final newId = 'Brush${DateTime.now().millisecondsSinceEpoch}';
    _brushes.add(brush.copyWith(id: newId, name: '${brush.name} (コピー)'));
    notifyListeners();
  }

  void toggleFavoriteBrush(String id) {
    final idx = _brushes.indexWhere((b) => b.id == id);
    if (idx >= 0) {
      _brushes[idx] = _brushes[idx].copyWith(isFavorite: !_brushes[idx].isFavorite);
      notifyListeners();
    }
  }

  void reorderBrush(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final brush = _brushes.removeAt(oldIndex);
    _brushes.insert(newIndex, brush);
    notifyListeners();
  }

  void updateBrush(Brush brush) {
    final idx = _brushes.indexWhere((b) => b.id == brush.id);
    if (idx >= 0) {
      _brushes[idx] = brush;
      notifyListeners();
    }
  }
}

class BrushFolder {
  final String id;
  final String name;
  final List<String> brushIds;
  final bool isFavorite;

  BrushFolder({
    required this.id,
    required this.name,
    this.brushIds = const [],
    this.isFavorite = false,
  });
}
