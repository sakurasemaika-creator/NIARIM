import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/canvas_dock_panel.dart';
import '../models/toolbar_item.dart';

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
  // ツールバー編集（仕様書08：表示するツールをチェックボックスで選択・ドラッグで並び替え）
  List<ToolbarItemId> _toolbarOrder = List.of(ToolbarItemId.values);
  Set<ToolbarItemId> _hiddenToolbarItems = {};
  // PC/DeXモードでキャンバス画面を開いた際に既定でドッキング表示する
  // パネル（仕様書08：ワークスペース設定）。スマホ版は常に全パネル
  // 非表示スタートのため、この設定は使わない。
  Set<CanvasDockPanel> _defaultDockedPanels = {
    CanvasDockPanel.brush,
    CanvasDockPanel.colorPicker,
    CanvasDockPanel.layer,
  };

  int get defaultFps => _defaultFps;
  int get undoLimit => _undoLimit;
  int get trashAutoDeleteDays => _trashAutoDeleteDays;
  String get language => _language;
  bool get defaultDrawingAreaEnabled => _defaultDrawingAreaEnabled;
  double get defaultDrawingAreaScale => _defaultDrawingAreaScale;
  bool? get forcePcMode => _forcePcMode;
  bool get isLeftHanded => _isLeftHanded;
  List<ToolbarItemId> get toolbarOrder => List.unmodifiable(_toolbarOrder);
  Set<ToolbarItemId> get hiddenToolbarItems => Set.unmodifiable(_hiddenToolbarItems);
  Set<CanvasDockPanel> get defaultDockedPanels => Set.unmodifiable(_defaultDockedPanels);

  // ─── バケツ塗り詳細設定（設定画面「バケツ塗り」） ───────────────────────
  // 許容誤差：クリックした位置の色からどこまで色差を許容して同一領域とみなすか
  double _bucketTolerance = 30.0;
  // 拡張px：フラッドフィルで検出した領域を境界の外側へ何px広げるか
  // （線画とのわずかな隙間・塗り残しをカバーする）
  int _bucketExpandPx = 0;
  // 線の下まで潜る：拡張分を線画の上から上書きせず、既存ピクセルの背後へ
  // 塗り色を合成する（線の見た目を保ったまま隙間だけを塗り色で埋める）
  bool _bucketFillUnderLine = false;

  double get bucketTolerance => _bucketTolerance;
  int get bucketExpandPx => _bucketExpandPx;
  bool get bucketFillUnderLine => _bucketFillUnderLine;

  Future<void> setBucketTolerance(double value) async {
    _bucketTolerance = value.clamp(0.0, 100.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('bucket_tolerance', _bucketTolerance);
    notifyListeners();
  }

  Future<void> setBucketExpandPx(int value) async {
    _bucketExpandPx = value.clamp(0, 10);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('bucket_expand_px', _bucketExpandPx);
    notifyListeners();
  }

  Future<void> setBucketFillUnderLine(bool value) async {
    _bucketFillUnderLine = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bucket_fill_under_line', value);
    notifyListeners();
  }

  // ─── 長押しスポイト（設定画面「ジェスチャー」） ─────────────────────────
  // ペン・消しゴムでの描画中、指を動かさず一定時間押し続けるとその場の色を
  // スポイトのように拾う機能のON/OFFと保持秒数。既定はON。
  bool _holdEyedropperEnabled = true;
  double _holdEyedropperSeconds = 0.5;

  bool get holdEyedropperEnabled => _holdEyedropperEnabled;
  double get holdEyedropperSeconds => _holdEyedropperSeconds;

  Future<void> setHoldEyedropperEnabled(bool value) async {
    _holdEyedropperEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hold_eyedropper_enabled', value);
    notifyListeners();
  }

  Future<void> setHoldEyedropperSeconds(double value) async {
    _holdEyedropperSeconds = value.clamp(0.2, 3.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('hold_eyedropper_seconds', _holdEyedropperSeconds);
    notifyListeners();
  }

  // ─── タイムラインモードのプレビュー欄の高さ ───────────────────────────
  // プレビュー下端のドラッグハンドルで変更できる、プレビュー欄が占める
  // 縦方向の割合（0.0〜1.0）。プロジェクトごとではなくアプリ全体で共通の
  // 設定として保存するため、作業を中断したり別のプロジェクトへ移動しても
  // 最後に設定した位置が引き継がれる。
  double _timelinePreviewHeightFraction = 0.42;

  double get timelinePreviewHeightFraction => _timelinePreviewHeightFraction;

  Future<void> setTimelinePreviewHeightFraction(double value) async {
    _timelinePreviewHeightFraction = value.clamp(0.18, 0.7);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('timeline_preview_height_fraction', _timelinePreviewHeightFraction);
    notifyListeners();
  }

  // ─── エンドカードのプレミアム既定設定 ─────────────────────────────────
  // プレミアム会員限定：ONにすると、以後タイムラインを開いた時点で
  // エンドカードが最初から非表示（削除済み）の状態になる。無料会員には
  // 一切関係がなく、プレミアム権限が切れて無料会員に戻った時点でこの設定
  // 自体も自動でOFFへリセットする（main.dartでPremiumServiceの状態変化を
  // 監視して呼び出す）。
  bool _endCardDefaultHiddenForPremium = false;

  bool get endCardDefaultHiddenForPremium => _endCardDefaultHiddenForPremium;

  Future<void> setEndCardDefaultHiddenForPremium(bool value) async {
    _endCardDefaultHiddenForPremium = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('endcard_default_hidden_for_premium', value);
    notifyListeners();
  }

  GestureAction _twoFingerTap = GestureAction.undo;
  GestureAction _threeFingerTap = GestureAction.redo;
  GestureAction _twoFingerSwipe = GestureAction.frameMove;
  GestureAction _longPress = GestureAction.eyedropper;

  GestureAction get twoFingerTap => _twoFingerTap;
  GestureAction get threeFingerTap => _threeFingerTap;
  GestureAction get twoFingerSwipe => _twoFingerSwipe;
  GestureAction get longPress => _longPress;

  // ─── ペン入力設定（仕様書08：筆圧カーブ・ペンボタン） ─────────────────
  // 注：筆圧の「無効／サイズ／不透明度／両方」反映モードは仕様書17（ブラシ仕様）
  // により「ブラシ個別設定」と明記されているため、ブラシ設定側(Brush.pressureMode)
  // のみで管理する（グローバル設定としては持たない＝仕様書08との重複記載を解消）。
  // 筆圧カーブのみアプリ全体に適用される設定としてここで管理する。
  PenPressureCurve _penPressureCurve = PenPressureCurve.normal;
  GestureAction _penButton1 = GestureAction.eraserToggle;
  GestureAction _penButton2 = GestureAction.eyedropper;

  PenPressureCurve get penPressureCurve => _penPressureCurve;
  GestureAction get penButton1 => _penButton1;
  GestureAction get penButton2 => _penButton2;

  /// 筆圧カーブに応じて生の筆圧値（0.0〜1.0）を補正する（仕様書08：
  /// 筆圧カーブはアプリ全体に適用）。弱＝立ち上がりを緩やかに、
  /// 強＝立ち上がりを鋭くする指数カーブ。カスタムのみ、_customPressurePoints
  /// （最大10点の制御点）を結ぶ折れ線で補間する。
  double applyPressureCurve(double rawPressure) {
    final p = rawPressure.clamp(0.0, 1.0);
    if (_penPressureCurve == PenPressureCurve.custom) {
      return _evalCustomCurve(p);
    }
    final exponent = switch (_penPressureCurve) {
      PenPressureCurve.weak => 1.6,
      PenPressureCurve.normal => 1.0,
      PenPressureCurve.strong => 0.6,
      PenPressureCurve.custom => 1.0, // 到達しない（上でハンドリング済み）
    };
    if (exponent == 1.0) return p;
    return math.pow(p, exponent).toDouble();
  }

  double _evalCustomCurve(double x) {
    final pts = _customPressurePoints;
    for (int i = 0; i < pts.length - 1; i++) {
      final a = pts[i];
      final b = pts[i + 1];
      if (x >= a.$1 && x <= b.$1) {
        if (b.$1 == a.$1) return a.$2;
        final t = (x - a.$1) / (b.$1 - a.$1);
        return a.$2 + (b.$2 - a.$2) * t;
      }
    }
    return pts.last.$2;
  }

  /// カスタム筆圧カーブの制御点（x=筆圧、y=反映される太さ・不透明度の
  /// 倍率、いずれも0.0〜1.0）。x昇順に並べ、最大10点まで持てる。
  /// 先頭（x=0）・末尾（x=1）は常に存在し、xは動かせない
  /// （0〜1全域をカバーするため）。デフォルトは対角線（傾き1）の2点のみ。
  static const int maxPressurePoints = 10;
  List<(double, double)> _customPressurePoints = const [(0.0, 0.0), (1.0, 1.0)];
  List<(double, double)> get customPressurePoints => List.unmodifiable(_customPressurePoints);

  Future<void> setPenPressureCurve(PenPressureCurve curve) async {
    _penPressureCurve = curve;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pen_pressure_curve', curve.name);
    notifyListeners();
  }

  Future<void> _persistCustomPressurePoints() async {
    final prefs = await SharedPreferences.getInstance();
    final flat = _customPressurePoints.expand((p) => [p.$1, p.$2]).toList();
    await prefs.setStringList(
        'pen_pressure_custom_points', flat.map((v) => v.toString()).toList());
  }

  /// 新しい制御点を追加する（最大10点まで。x昇順を保つ）。
  Future<void> addCustomPressurePoint(double x, double y) async {
    if (_customPressurePoints.length >= maxPressurePoints) return;
    final points = List<(double, double)>.from(_customPressurePoints)
      ..add((x.clamp(0.0, 1.0), y.clamp(0.0, 1.0)));
    points.sort((a, b) => a.$1.compareTo(b.$1));
    _customPressurePoints = points;
    await _persistCustomPressurePoints();
    notifyListeners();
  }

  /// 制御点を移動する。先頭・末尾（index 0・最後）はxを固定しyのみ動かす。
  /// 中間点は前後の制御点の間からxが出ないようクランプする。
  Future<void> moveCustomPressurePoint(int index, double x, double y) async {
    final points = List<(double, double)>.from(_customPressurePoints);
    if (index < 0 || index >= points.length) return;
    final isEndpoint = index == 0 || index == points.length - 1;
    final clampedY = y.clamp(0.0, 1.0);
    if (isEndpoint) {
      points[index] = (points[index].$1, clampedY);
    } else {
      final minX = points[index - 1].$1 + 0.01;
      final maxX = points[index + 1].$1 - 0.01;
      final clampedX = x.clamp(minX, maxX);
      points[index] = (clampedX, clampedY);
    }
    _customPressurePoints = points;
    await _persistCustomPressurePoints();
    notifyListeners();
  }

  /// 中間の制御点を削除する（先頭・末尾は削除不可）。
  Future<void> removeCustomPressurePoint(int index) async {
    if (index <= 0 || index >= _customPressurePoints.length - 1) return;
    final points = List<(double, double)>.from(_customPressurePoints)..removeAt(index);
    _customPressurePoints = points;
    await _persistCustomPressurePoints();
    notifyListeners();
  }

  /// 筆圧カーブをデフォルト（対角線の2点のみ）へリセットする（ユーザー
  /// 指示：誤って点を増やしすぎた時に簡単に戻せるようにするため）。
  Future<void> resetCustomPressureCurve() async {
    _customPressurePoints = const [(0.0, 0.0), (1.0, 1.0)];
    await _persistCustomPressurePoints();
    notifyListeners();
  }

  Future<void> setPenButton(int buttonNumber, GestureAction action) async {
    final prefs = await SharedPreferences.getInstance();
    if (buttonNumber == 1) {
      _penButton1 = action;
      await prefs.setString('pen_button_1', action.name);
    } else {
      _penButton2 = action;
      await prefs.setString('pen_button_2', action.name);
    }
    notifyListeners();
  }

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
    _bucketTolerance = prefs.getDouble('bucket_tolerance') ?? 30.0;
    _bucketExpandPx = prefs.getInt('bucket_expand_px') ?? 0;
    _bucketFillUnderLine = prefs.getBool('bucket_fill_under_line') ?? false;
    _holdEyedropperEnabled = prefs.getBool('hold_eyedropper_enabled') ?? true;
    _holdEyedropperSeconds = prefs.getDouble('hold_eyedropper_seconds') ?? 0.5;
    _timelinePreviewHeightFraction =
        prefs.getDouble('timeline_preview_height_fraction') ?? 0.42;
    _endCardDefaultHiddenForPremium = prefs.getBool('endcard_default_hidden_for_premium') ?? false;
    final toolbarOrderNames = prefs.getStringList('toolbar_order');
    if (toolbarOrderNames != null && toolbarOrderNames.isNotEmpty) {
      final map = ToolbarItemId.values.asNameMap();
      final restored = toolbarOrderNames.map((n) => map[n]).whereType<ToolbarItemId>().toList();
      // バージョンアップで項目が追加された場合、欠けている項目は末尾へ補完
      for (final id in ToolbarItemId.values) {
        if (!restored.contains(id)) restored.add(id);
      }
      _toolbarOrder = restored;
    }
    final hiddenNames = prefs.getStringList('toolbar_hidden') ?? const [];
    _hiddenToolbarItems = hiddenNames.map((n) => ToolbarItemId.values.asNameMap()[n]).whereType<ToolbarItemId>().toSet();
    final dockedPanelNames = prefs.getStringList('default_docked_panels');
    if (dockedPanelNames != null) {
      final map = CanvasDockPanel.values.asNameMap();
      _defaultDockedPanels = dockedPanelNames.map((n) => map[n]).whereType<CanvasDockPanel>().toSet();
    }
    _twoFingerTap = _gestureActionFromName(prefs.getString('gesture_two_finger_tap'), GestureAction.undo);
    _threeFingerTap = _gestureActionFromName(prefs.getString('gesture_three_finger_tap'), GestureAction.redo);
    _twoFingerSwipe = _gestureActionFromName(prefs.getString('gesture_two_finger_swipe'), GestureAction.frameMove);
    _longPress = _gestureActionFromName(prefs.getString('gesture_long_press'), GestureAction.eyedropper);
    _penPressureCurve = PenPressureCurve.values.asNameMap()[prefs.getString('pen_pressure_curve')] ?? PenPressureCurve.normal;
    final rawPoints = prefs.getStringList('pen_pressure_custom_points');
    if (rawPoints != null && rawPoints.length >= 4 && rawPoints.length.isEven) {
      final values = rawPoints.map((s) => double.tryParse(s)).toList();
      if (values.every((v) => v != null)) {
        final points = <(double, double)>[];
        for (int i = 0; i < values.length; i += 2) {
          points.add((values[i]!, values[i + 1]!));
        }
        _customPressurePoints = points;
      }
    } else {
      // 旧バージョン（単一exponent値）からの引き継ぎ：以前の指数カーブの
      // 形状を、新しい制御点方式の3点（始点・中間点・終点）で近似する。
      final legacyExponent = prefs.getDouble('pen_pressure_custom_exponent');
      if (legacyExponent != null && legacyExponent != 1.0) {
        final midY = math.pow(0.5, legacyExponent).toDouble().clamp(0.0, 1.0);
        _customPressurePoints = [(0.0, 0.0), (0.5, midY), (1.0, 1.0)];
      }
    }
    _penButton1 = _gestureActionFromName(prefs.getString('pen_button_1'), GestureAction.eraserToggle);
    _penButton2 = _gestureActionFromName(prefs.getString('pen_button_2'), GestureAction.eyedropper);
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

  /// UI表示言語（'ja'/'en'）。MaterialAppのlocaleに反映され、
  /// AppLocalizationsで参照される全画面の表示言語が切り替わる。
  Future<void> setLanguage(String languageCode) async {
    _language = languageCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', languageCode);
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

  /// ツールバーの表示順を変更する（仕様書08：ドラッグで並び替え）。
  Future<void> setToolbarOrder(List<ToolbarItemId> order) async {
    _toolbarOrder = List.of(order);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('toolbar_order', _toolbarOrder.map((e) => e.name).toList());
    notifyListeners();
  }

  /// ツールバー項目の表示/非表示を切り替える（仕様書08：チェックボックスで選択）。
  Future<void> setToolbarItemVisible(ToolbarItemId id, bool visible) async {
    if (visible) {
      _hiddenToolbarItems.remove(id);
    } else {
      _hiddenToolbarItems.add(id);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('toolbar_hidden', _hiddenToolbarItems.map((e) => e.name).toList());
    notifyListeners();
  }

  /// PC/DeXモードで既定でドッキング表示するパネルの一覧を丸ごと入れ替える
  /// （仕様書08：ワークスペース設定＞PC版で既定で開くパネル）。
  Future<void> setDefaultDockedPanels(Set<CanvasDockPanel> panels) async {
    _defaultDockedPanels = Set.of(panels);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('default_docked_panels', _defaultDockedPanels.map((e) => e.name).toList());
    notifyListeners();
  }

  /// ツールバー編集を初期状態（全項目表示・デフォルト順）へ戻す。
  Future<void> resetToolbarDefault() async {
    _toolbarOrder = List.of(ToolbarItemId.values);
    _hiddenToolbarItems = {};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('toolbar_order', _toolbarOrder.map((e) => e.name).toList());
    await prefs.setStringList('toolbar_hidden', const []);
    notifyListeners();
  }

  /// ワークスペースプリセットの読込用：並び順・非表示項目をまとめて適用する
  /// （仕様書08：「切り替えると表示ツール・早替えツール・パネル配置が一括で変わる」）。
  Future<void> applyToolbarPreset(List<ToolbarItemId> order, Set<ToolbarItemId> hidden) async {
    _toolbarOrder = order.isEmpty ? List.of(ToolbarItemId.values) : List.of(order);
    _hiddenToolbarItems = Set.of(hidden);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('toolbar_order', _toolbarOrder.map((e) => e.name).toList());
    await prefs.setStringList('toolbar_hidden', _hiddenToolbarItems.map((e) => e.name).toList());
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
  // オニオンスキンON/OFF切替（仕様書22：ジェスチャーに割り当て可能）
  onionSkinToggle,
}

/// 筆圧カーブ（仕様書08・17：アプリ全体に適用）。
enum PenPressureCurve { weak, normal, strong, custom }
