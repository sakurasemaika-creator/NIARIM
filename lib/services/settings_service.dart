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
  // PC/DeXモードの手動切替（仕様書02：ワークスペース設定）。
  // null=自動（画面幅で判定）、true/false=手動で強制ON/OFF。
  bool? _forcePcMode;
  // 左利きモード（仕様書08）：ONの場合、キャンバスのドッキングパネルを
  // 左右反転して配置する。
  bool _isLeftHanded = false;

  int get defaultFps => _defaultFps;
  int get undoLimit => _undoLimit;
  int get trashAutoDeleteDays => _trashAutoDeleteDays;
  String get language => _language;
  bool get defaultDrawingAreaEnabled => _defaultDrawingAreaEnabled;
  double get defaultDrawingAreaScale => _defaultDrawingAreaScale;
  bool? get forcePcMode => _forcePcMode;
  bool get isLeftHanded => _isLeftHanded;

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
    // -1=自動（未設定）、0=OFF、1=ON
    final pcModeValue = prefs.getInt('force_pc_mode') ?? -1;
    _forcePcMode = pcModeValue == -1 ? null : pcModeValue == 1;
    _isLeftHanded = prefs.getBool('is_left_handed') ?? false;
    _twoFingerTap = _gestureActionFromName(prefs.getString('gesture_two_finger_tap'), GestureAction.undo);
    _threeFingerTap = _gestureActionFromName(prefs.getString('gesture_three_finger_tap'), GestureAction.redo);
    _twoFingerSwipe = _gestureActionFromName(prefs.getString('gesture_two_finger_swipe'), GestureAction.frameMove);
    _longPress = _gestureActionFromName(prefs.getString('gesture_long_press'), GestureAction.eyedropper);
  }

  GestureAction _gestureActionFromName(String? name, GestureAction fallback) {
    if (name == null) return fallback;
    return GestureAction.values.asNameMap()[name] ?? fallback;
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

  /// PC/DeXモードを手動で切り替える（仕様書02）。[value]がnullなら自動判定
  /// （画面幅ベース）に戻す。
  Future<void> setForcePcMode(bool? value) async {
    _forcePcMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('force_pc_mode', value == null ? -1 : (value ? 1 : 0));
    notifyListeners();
  }

  /// 左利きモードを切り替える（仕様書08：キャンバスのドッキングパネル配置を反転）。
  Future<void> setLeftHanded(bool value) async {
    _isLeftHanded = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_left_handed', value);
    notifyListeners();
  }

  Future<void> setGesture(GestureType type, GestureAction action) async {
    final prefs = await SharedPreferences.getInstance();
    switch (type) {
      case GestureType.twoFingerTap:
        _twoFingerTap = action;
        await prefs.setString('gesture_two_finger_tap', action.name);
      case GestureType.threeFingerTap:
        _threeFingerTap = action;
        await prefs.setString('gesture_three_finger_tap', action.name);
      case GestureType.twoFingerSwipe:
        _twoFingerSwipe = action;
        await prefs.setString('gesture_two_finger_swipe', action.name);
      case GestureType.longPress:
        _longPress = action;
        await prefs.setString('gesture_long_press', action.name);
    }
    notifyListeners();
  }
}

enum GestureType { twoFingerTap, threeFingerTap, twoFingerSwipe, longPress }

enum GestureAction {
  undo, redo, eyedropper, panTool, eraserToggle,
  brushToggle, frameMove, nextTool, none,
}
