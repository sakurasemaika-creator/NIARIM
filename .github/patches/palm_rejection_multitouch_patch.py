from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: marker count {count}, expected 1')
    p.write_text(text.replace(old, new, 1), encoding='utf-8')

# InputHandler: reject only single-touch tool input while palm rejection is enabled,
# and clear stylus state only when the stylus itself goes up.
replace_once(
    'lib/engine/input_handler.dart',
    "  void onStylusUp() {\n    _isStylusActive = false;\n  }\n",
    "  bool shouldRejectPalmTouch(\n    InputType type, {\n    required bool palmRejectionEnabled,\n  }) =>\n      palmRejectionEnabled &&\n      type == InputType.touch &&\n      _isStylusActive;\n\n  void onPointerUp(PointerEvent event) {\n    if (event.kind == PointerDeviceKind.stylus ||\n        event.kind == PointerDeviceKind.invertedStylus) {\n      _isStylusActive = false;\n    }\n  }\n\n  void onStylusUp() {\n    _isStylusActive = false;\n  }\n",
)

# Persistent app setting; enabled by default to preserve the existing behavior.
replace_once(
    'lib/services/settings_service.dart',
    "  PenPressureCurve _penPressureCurve = PenPressureCurve.normal;\n  GestureAction _penButton1 = GestureAction.eraserToggle;\n",
    "  bool _palmRejectionEnabled = true;\n  PenPressureCurve _penPressureCurve = PenPressureCurve.normal;\n  GestureAction _penButton1 = GestureAction.eraserToggle;\n",
)
replace_once(
    'lib/services/settings_service.dart',
    "  PenPressureCurve get penPressureCurve => _penPressureCurve;\n  GestureAction get penButton1 => _penButton1;\n",
    "  bool get palmRejectionEnabled => _palmRejectionEnabled;\n  PenPressureCurve get penPressureCurve => _penPressureCurve;\n  GestureAction get penButton1 => _penButton1;\n",
)
replace_once(
    'lib/services/settings_service.dart',
    "  Future<void> setPenPressureCurve(PenPressureCurve curve) async {\n",
    "  Future<void> setPalmRejectionEnabled(bool value) async {\n    _palmRejectionEnabled = value;\n    final prefs = await SharedPreferences.getInstance();\n    await prefs.setBool('palm_rejection_enabled', value);\n    notifyListeners();\n  }\n\n  Future<void> setPenPressureCurve(PenPressureCurve curve) async {\n",
)
replace_once(
    'lib/services/settings_service.dart',
    "    _penPressureCurve =\n        PenPressureCurve.values.asNameMap()[prefs.getString(\n",
    "    _palmRejectionEnabled =\n        prefs.getBool('palm_rejection_enabled') ?? true;\n    _penPressureCurve =\n        PenPressureCurve.values.asNameMap()[prefs.getString(\n",
)

# Pen settings UI switch.
replace_once(
    'lib/screens/settings/pen_settings_screen.dart',
    "            _sectionLabel(context, l10n.penSettingsCurveSection),\n",
    "            _sectionLabel(context, l10n.penSettingsPalmRejectionSection),\n            Card(\n              elevation: 1,\n              shadowColor: ThemeService.activeColorScheme.shadow.withValues(\n                alpha: 0.15,\n              ),\n              shape: RoundedRectangleBorder(\n                borderRadius: BorderRadius.circular(14),\n              ),\n              color: Theme.of(context).colorScheme.surfaceContainerLow,\n              child: SwitchListTile(\n                title: Text(l10n.penSettingsPalmRejectionTitle),\n                subtitle: Text(\n                  l10n.penSettingsPalmRejectionHint,\n                  style: const TextStyle(fontSize: 11),\n                ),\n                value: settings.palmRejectionEnabled,\n                onChanged: settings.setPalmRejectionEnabled,\n              ),\n            ),\n            const SizedBox(height: 20),\n            _sectionLabel(context, l10n.penSettingsCurveSection),\n",
)

# Canvas: multi-touch remains available while stylus is active. Palm rejection applies
# to one-finger tool input, not to deliberate multi-touch gestures.
replace_once(
    'lib/screens/canvas/widgets/canvas_area.dart',
    "  /// スタイラス使用中は誤操作防止のため2本指キャンバス操作を無効化する\n  /// （手のひらツール選択中のみ例外的に許可）。既存のInteractiveViewerの\n  /// panEnabled/scaleEnabledと同じ条件（パームリジェクション）。\n  bool get _canTouchTransform =>\n      // メッシュ変形ツール中は、2本指以上でもキャンバス自体のパン・ズーム・\n      // 回転へ渡さず、各指を個別に別々の格子点操作へ渡す（複数指で複数の\n      // 角を同時につまんで引っ張る＝回転・拡大縮小相当の操作）。\n      widget.currentTool != DrawingTool.meshTransform &&\n      (!_inputHandler.isStylusActive || widget.currentTool == DrawingTool.pan);\n",
    "  /// 2本指以上は明示的なキャンバスジェスチャーとして扱う。\n  /// パームリジェクションはスタイラス使用中の単指タッチ描画だけを抑止し、\n  /// 2本指パン・ピンチ・回転までは無効化しない。\n  bool get _canTouchTransform =>\n      // メッシュ変形ツール中は、2本指以上でもキャンバス自体のパン・ズーム・\n      // 回転へ渡さず、各指を個別に別々の格子点操作へ渡す。\n      widget.currentTool != DrawingTool.meshTransform;\n",
)
replace_once(
    'lib/screens/canvas/widgets/canvas_area.dart',
    "  final Set<int> _toolHandledPointers = {};\n\n  // ─── 長押しスポイト",
    "  final Set<int> _toolHandledPointers = {};\n  final MultiTouchTapTracker _multiTouchTapTracker = MultiTouchTapTracker();\n\n  // ─── 長押しスポイト",
)
# Add import for tracker.
replace_once(
    'lib/screens/canvas/widgets/canvas_area.dart',
    "import '../../../engine/mesh_warp_engine.dart';\n",
    "import '../../../engine/mesh_warp_engine.dart';\nimport '../../../engine/multi_touch_tap_tracker.dart';\n",
)
# Global palm rejection gates, before any tool-specific touch behavior.
replace_once(
    'lib/screens/canvas/widgets/canvas_area.dart',
    "  void _onPointerDown(PointerEvent event) {\n    final type = _inputHandler.classifyInput(event);\n    final canvasPos = _canvasPosition(event.localPosition);\n",
    "  void _onPointerDown(PointerEvent event) {\n    final type = _inputHandler.classifyInput(event);\n    final canvasPos = _canvasPosition(event.localPosition);\n    final settings = context.read<SettingsService>();\n    if (_inputHandler.shouldRejectPalmTouch(\n      type,\n      palmRejectionEnabled: settings.palmRejectionEnabled,\n    )) {\n      return;\n    }\n",
)
replace_once(
    'lib/screens/canvas/widgets/canvas_area.dart',
    "  void _onPointerMove(PointerEvent event) {\n    if (_middleClickPanning) {\n",
    "  void _onPointerMove(PointerEvent event) {\n    if (_middleClickPanning) {\n",
)
# Insert move gate after classifyInput/canvas position.
replace_once(
    'lib/screens/canvas/widgets/canvas_area.dart',
    "    final type = _inputHandler.classifyInput(event);\n    final canvasPos = _canvasPosition(event.localPosition);\n\n    if (widget.currentTool == DrawingTool.pan) {\n",
    "    final type = _inputHandler.classifyInput(event);\n    final canvasPos = _canvasPosition(event.localPosition);\n    if (_inputHandler.shouldRejectPalmTouch(\n      type,\n      palmRejectionEnabled: context.read<SettingsService>().palmRejectionEnabled,\n    )) {\n      return;\n    }\n\n    if (widget.currentTool == DrawingTool.pan) {\n",
)
# Up gate before all tool-specific completion paths.
replace_once(
    'lib/screens/canvas/widgets/canvas_area.dart',
    "    final type = _inputHandler.classifyInput(event);\n\n    if (widget.currentTool == DrawingTool.pan) {\n",
    "    final type = _inputHandler.classifyInput(event);\n    if (_inputHandler.shouldRejectPalmTouch(\n      type,\n      palmRejectionEnabled: context.read<SettingsService>().palmRejectionEnabled,\n    )) {\n      _disarmHoldEyedropper(event.pointer);\n      return;\n    }\n\n    if (widget.currentTool == DrawingTool.pan) {\n",
)
# All stylus-state clearing in this file becomes pointer-kind-aware.
p = Path('lib/screens/canvas/widgets/canvas_area.dart')
text = p.read_text(encoding='utf-8')
text = text.replace('_inputHandler.onStylusUp();', '_inputHandler.onPointerUp(event);')
p.write_text(text, encoding='utf-8')

# Replace immediate 2/3-finger firing with tap tracking.
replace_once(
    'lib/screens/canvas/widgets/canvas_area.dart',
    "            _touchCount++;\n            _activeTouchPositions[e.pointer] = e.localPosition;\n            if (_touchCount == 2) {\n              _handleGesture(context, settings.twoFingerTap);\n            }\n            if (_touchCount == 3) {\n              _handleGesture(context, settings.threeFingerTap);\n            }\n",
    "            _touchCount++;\n            _activeTouchPositions[e.pointer] = e.localPosition;\n            _multiTouchTapTracker.pointerDown(\n              e.pointer,\n              e.localPosition,\n              DateTime.now(),\n            );\n",
)
replace_once(
    'lib/screens/canvas/widgets/canvas_area.dart',
    "          if (e.kind == PointerDeviceKind.touch &&\n              _activeTouchPositions.containsKey(e.pointer)) {\n            if (_touchTransformActive) {\n",
    "          if (e.kind == PointerDeviceKind.touch &&\n              _activeTouchPositions.containsKey(e.pointer)) {\n            _multiTouchTapTracker.pointerMove(e.pointer, e.localPosition);\n            if (_touchTransformActive) {\n",
)
replace_once(
    'lib/screens/canvas/widgets/canvas_area.dart',
    "          if (e.kind == PointerDeviceKind.touch) {\n            _touchCount = (_touchCount - 1).clamp(0, 10);\n            _activeTouchPositions.remove(e.pointer);\n            // 全ての指が離れて初めて、次のタッチを新規の描画として扱えるように戻す\n            // （2本指→1本指に減った直後に、残りの指で不意に描画が始まるのを防ぐ）。\n            if (_activeTouchPositions.isEmpty) _touchTransformActive = false;\n          }\n",
    "          MultiTouchTapKind? completedTap;\n          if (e.kind == PointerDeviceKind.touch) {\n            _touchCount = (_touchCount - 1).clamp(0, 10);\n            _activeTouchPositions.remove(e.pointer);\n            completedTap = _multiTouchTapTracker.pointerUp(\n              e.pointer,\n              DateTime.now(),\n            );\n            // 全ての指が離れて初めて、次のタッチを新規の描画として扱えるように戻す。\n            if (_activeTouchPositions.isEmpty) _touchTransformActive = false;\n          }\n          if (completedTap == MultiTouchTapKind.twoFinger) {\n            _handleGesture(context, settings.twoFingerTap);\n          } else if (completedTap == MultiTouchTapKind.threeFinger) {\n            _handleGesture(context, settings.threeFingerTap);\n          }\n",
)
replace_once(
    'lib/screens/canvas/widgets/canvas_area.dart',
    "            _activeTouchPositions.remove(e.pointer);\n            if (_activeTouchPositions.isEmpty) _touchTransformActive = false;\n",
    "            _activeTouchPositions.remove(e.pointer);\n            _multiTouchTapTracker.pointerCancel(e.pointer);\n            if (_activeTouchPositions.isEmpty) _touchTransformActive = false;\n",
)

# Remove redundant old palm checks now covered globally.
p = Path('lib/screens/canvas/widgets/canvas_area.dart')
text = p.read_text(encoding='utf-8')
text = text.replace("      if (type == InputType.touch && _inputHandler.isStylusActive) return;\n", "")
text = text.replace("    if (type == InputType.touch && _inputHandler.isStylusActive) return;\n", "")
# Remove the now-unreachable legacy Up palm block.
legacy = "    // パームリジェクションで無視されたタッチ（スタイラス使用中の誤タッチ）はここで終了。\n    // スタイラス未使用時のタッチ描画は下のendStroke()まで到達させ、正しく確定させる。\n    if (type == InputType.touch && _inputHandler.isStylusActive) {\n      return;\n    }\n"
text = text.replace(legacy, "")
p.write_text(text, encoding='utf-8')

# ARB strings: calm, literal tone aligned with the Japanese source.
translations = {
    'app_ja.arb': ('パームリジェクション', 'パームリジェクション', 'ペン使用中の1本指タッチによる誤操作を防ぎます。2本指以上のジェスチャーは引き続き使用できます。'),
    'app_en.arb': ('Palm Rejection', 'Palm rejection', 'Prevents accidental input from single-finger touches while using a stylus. Gestures with two or more fingers remain available.'),
    'app_es.arb': ('Rechazo de palma', 'Rechazo de palma', 'Evita entradas accidentales con un solo dedo mientras usas un lápiz. Los gestos con dos o más dedos siguen disponibles.'),
    'app_fr.arb': ('Rejet de la paume', 'Rejet de la paume', 'Évite les entrées accidentelles avec un seul doigt pendant l’utilisation d’un stylet. Les gestes à deux doigts ou plus restent disponibles.'),
    'app_ko.arb': ('손바닥 터치 방지', '손바닥 터치 방지', '펜을 사용하는 동안 한 손가락 터치로 인한 오작동을 방지합니다. 두 손가락 이상의 제스처는 계속 사용할 수 있습니다.'),
    'app_zh.arb': ('防误触', '防误触', '使用触控笔时，防止单指触摸造成误操作。双指及以上手势仍可正常使用。'),
    'app_zh_Hant.arb': ('防誤觸', '防誤觸', '使用觸控筆時，防止單指觸控造成誤操作。雙指及以上手勢仍可正常使用。'),
}
for filename, (section, title, hint) in translations.items():
    path = Path('lib/l10n') / filename
    text = path.read_text(encoding='utf-8')
    marker = '  "penSettingsCurveSection":'
    idx = text.find(marker)
    if idx < 0:
        raise SystemExit(f'{filename}: penSettingsCurveSection marker missing')
    if '"penSettingsPalmRejectionTitle"' in text:
        continue
    insert = (
        f'  "penSettingsPalmRejectionSection": "{section}",\n'
        f'  "penSettingsPalmRejectionTitle": "{title}",\n'
        f'  "penSettingsPalmRejectionHint": "{hint}",\n'
    )
    text = text[:idx] + insert + text[idx:]
    path.write_text(text, encoding='utf-8')
