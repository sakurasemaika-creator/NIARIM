import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  int _defaultFps = 12;
  int _undoLimit = 50;
  int _trashAutoDeleteDays = 0;
  String _language = 'ja';
  // 描画領域初期値（ホーム画面設定・仕様書26）
  bool _defaultDrawingAreaEnabled = false;
  double _defaultDrawingAreaScale = 2.0;

  int get defaultFps => _defaultFps;
  int get undoLimit => _undoLimit;
  int get trashAutoDeleteDays => _trashAutoDeleteDays;
  String get language => _language;
  bool get defaultDrawingAreaEnabled => _defaultDrawingAreaEnabled;
  double get defaultDrawingAreaScale => _defaultDrawingAreaScale;

  GestureAction _twoFingerTap = GestureAction.undo;
  GestureAction _threeFingerTap = GestureAction.redo;
  GestureAction _twoFingerSwipe = GestureAction.frameMove;
  GestureAction _longPress = GestureAction.eyedropper;

  GestureAction get twoFingerTap => _twoFingerTap;
  GestureAction get threeFingerTap => _threeFingerTap;
  GestureAction get twoFingerSwipe => _twoFingerSwipe;
  GestureAction get longPress => _longPress;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _defaultFps = prefs.getInt('default_fps') ?? 12;
    _undoLimit = prefs.getInt('undo_limit') ?? 50;
    _trashAutoDeleteDays = prefs.getInt('trash_auto_delete') ?? 0;
    _language = prefs.getString('language') ?? 'ja';
    _defaultDrawingAreaEnabled = prefs.getBool('default_drawing_area_enabled') ?? false;
    _defaultDrawingAreaScale = prefs.getDouble('default_drawing_area_scale') ?? 2.0;
    _isFirstLaunch = prefs.getBool('first_launch') ?? true;
  }

  bool _isFirstLaunch = true;
  bool get isFirstLaunch => _isFirstLaunch;

  Future<void> markFirstLaunchDone() async {
    _isFirstLaunch = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('first_launch', false);
    notifyListeners();
  }

  Future<void> setDefaultFps(int fps) async {
    _defaultFps = fps;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('default_fps', fps);
    notifyListeners();
  }

  Future<void> setDefaultDrawingArea({required bool enabled, required double scale}) async {
    _defaultDrawingAreaEnabled = enabled;
    _defaultDrawingAreaScale = scale.clamp(1.0, 10.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('default_drawing_area_enabled', _defaultDrawingAreaEnabled);
    await prefs.setDouble('default_drawing_area_scale', _defaultDrawingAreaScale);
    notifyListeners();
  }

  Future<void> setUndoLimit(int limit) async {
    _undoLimit = limit;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('undo_limit', limit);
    notifyListeners();
  }

  Future<void> setTrashAutoDelete(int days) async {
    _trashAutoDeleteDays = days;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('trash_auto_delete', days);
    notifyListeners();
  }

  Future<void> setGesture(GestureType type, GestureAction action) async {
    switch (type) {
      case GestureType.twoFingerTap:
        _twoFingerTap = action;
      case GestureType.threeFingerTap:
        _threeFingerTap = action;
      case GestureType.twoFingerSwipe:
        _twoFingerSwipe = action;
      case GestureType.longPress:
        _longPress = action;
    }
    notifyListeners();
  }
}

enum GestureType { twoFingerTap, threeFingerTap, twoFingerSwipe, longPress }

enum GestureAction {
  undo, redo, eyedropper, panTool, eraserToggle,
  brushToggle, frameMove, nextTool, none,
}
