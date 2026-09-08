from pathlib import Path


def replace_once(path, old, new):
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f'pattern not found in {path}: {old[:80]!r}')
    text = text.replace(old, new, 1)
    p.write_text(text)


# Multi-touch tracker: route any deliberate tap with >=4 fingers to one setting.
replace_once(
    'lib/engine/multi_touch_tap_tracker.dart',
    'enum MultiTouchTapKind { twoFinger, threeFinger }',
    'enum MultiTouchTapKind { twoFinger, threeFinger, fourOrMoreFinger }',
)
replace_once(
    'lib/engine/multi_touch_tap_tracker.dart',
    '/// Distinguishes deliberate two/three-finger taps from pan/pinch/rotation.',
    '/// Distinguishes deliberate multi-finger taps from pan/pinch/rotation.',
)
replace_once(
    'lib/engine/multi_touch_tap_tracker.dart',
    '''    if (!durationOk || moved) return null;\n    return switch (count) {\n      2 => MultiTouchTapKind.twoFinger,\n      3 => MultiTouchTapKind.threeFinger,\n      _ => null,\n    };''',
    '''    if (!durationOk || moved) return null;\n    if (count >= 4) return MultiTouchTapKind.fourOrMoreFinger;\n    return switch (count) {\n      2 => MultiTouchTapKind.twoFinger,\n      3 => MultiTouchTapKind.threeFinger,\n      _ => null,\n    };''',
)

# Settings model + persistence. Default stays none for backward compatibility.
replace_once(
    'lib/services/settings_service.dart',
    '''  GestureAction _twoFingerTap = GestureAction.undo;\n  GestureAction _threeFingerTap = GestureAction.redo;\n  GestureAction _twoFingerSwipe = GestureAction.frameMove;''',
    '''  GestureAction _twoFingerTap = GestureAction.undo;\n  GestureAction _threeFingerTap = GestureAction.redo;\n  GestureAction _fourOrMoreFingerTap = GestureAction.none;\n  GestureAction _twoFingerSwipe = GestureAction.frameMove;''',
)
replace_once(
    'lib/services/settings_service.dart',
    '''  GestureAction get twoFingerTap => _twoFingerTap;\n  GestureAction get threeFingerTap => _threeFingerTap;\n  GestureAction get twoFingerSwipe => _twoFingerSwipe;''',
    '''  GestureAction get twoFingerTap => _twoFingerTap;\n  GestureAction get threeFingerTap => _threeFingerTap;\n  GestureAction get fourOrMoreFingerTap => _fourOrMoreFingerTap;\n  GestureAction get twoFingerSwipe => _twoFingerSwipe;''',
)
replace_once(
    'lib/services/settings_service.dart',
    '''    _threeFingerTap = _gestureActionFromName(\n      prefs.getString('gesture_three_finger_tap'),\n      GestureAction.redo,\n    );\n    _twoFingerSwipe = _gestureActionFromName(''',
    '''    _threeFingerTap = _gestureActionFromName(\n      prefs.getString('gesture_three_finger_tap'),\n      GestureAction.redo,\n    );\n    _fourOrMoreFingerTap = _gestureActionFromName(\n      prefs.getString('gesture_four_or_more_finger_tap'),\n      GestureAction.none,\n    );\n    _twoFingerSwipe = _gestureActionFromName(''',
)
replace_once(
    'lib/services/settings_service.dart',
    '''      case GestureType.threeFingerTap:\n        _threeFingerTap = action;\n        await prefs.setString('gesture_three_finger_tap', action.name);\n      case GestureType.twoFingerSwipe:''',
    '''      case GestureType.threeFingerTap:\n        _threeFingerTap = action;\n        await prefs.setString('gesture_three_finger_tap', action.name);\n      case GestureType.fourOrMoreFingerTap:\n        _fourOrMoreFingerTap = action;\n        await prefs.setString('gesture_four_or_more_finger_tap', action.name);\n      case GestureType.twoFingerSwipe:''',
)
replace_once(
    'lib/services/settings_service.dart',
    'enum GestureType { twoFingerTap, threeFingerTap, twoFingerSwipe, longPress }',
    '''enum GestureType {\n  twoFingerTap,\n  threeFingerTap,\n  fourOrMoreFingerTap,\n  twoFingerSwipe,\n  longPress,\n}''',
)

# Gesture settings UI.
replace_once(
    'lib/screens/settings/gesture_settings_screen.dart',
    '''                  _item(\n                    context,\n                    l10n.gestureThreeFingerTap,\n                    settings.threeFingerTap,\n                    (a) => settings.setGesture(GestureType.threeFingerTap, a),\n                  ),\n                  const Divider(height: 1),\n                  // 2本指スワイプ左右のみ、連続動作前提の「フレーム移動」を選択肢に含める。''',
    '''                  _item(\n                    context,\n                    l10n.gestureThreeFingerTap,\n                    settings.threeFingerTap,\n                    (a) => settings.setGesture(GestureType.threeFingerTap, a),\n                  ),\n                  const Divider(height: 1),\n                  _item(\n                    context,\n                    l10n.gestureFourOrMoreFingerTap,\n                    settings.fourOrMoreFingerTap,\n                    (a) => settings.setGesture(\n                      GestureType.fourOrMoreFingerTap,\n                      a,\n                    ),\n                  ),\n                  const Divider(height: 1),\n                  // 2本指スワイプ左右のみ、連続動作前提の「フレーム移動」を選択肢に含める。''',
)

# Canvas dispatch.
replace_once(
    'lib/screens/canvas/widgets/canvas_area.dart',
    '''          } else if (completedTap == MultiTouchTapKind.threeFinger) {\n            _handleGesture(context, settings.threeFingerTap);\n          }\n          if (!_toolHandledPointers.remove(e.pointer)) return;''',
    '''          } else if (completedTap == MultiTouchTapKind.threeFinger) {\n            _handleGesture(context, settings.threeFingerTap);\n          } else if (completedTap == MultiTouchTapKind.fourOrMoreFinger) {\n            _handleGesture(context, settings.fourOrMoreFingerTap);\n          }\n          if (!_toolHandledPointers.remove(e.pointer)) return;''',
)

# Localizations.
labels = {
    'app_ja.arb': '4本指以上のタップ',
    'app_en.arb': 'Four-or-more-finger tap',
    'app_zh.arb': '四指及以上轻触',
    'app_zh_Hant.arb': '四指以上輕觸',
    'app_ko.arb': '네 손가락 이상 탭',
    'app_fr.arb': 'Appui à quatre doigts ou plus',
    'app_es.arb': 'Toque con cuatro dedos o más',
}
for filename, label in labels.items():
    path = f'lib/l10n/{filename}'
    p = Path(path)
    text = p.read_text()
    marker = '  "gestureThreeFingerTap": '
    idx = text.find(marker)
    if idx < 0:
        raise SystemExit(f'gestureThreeFingerTap not found in {path}')
    line_end = text.find('\n', idx)
    insertion = f'  "gestureFourOrMoreFingerTap": "{label}",\n'
    if '"gestureFourOrMoreFingerTap"' not in text:
        text = text[: line_end + 1] + insertion + text[line_end + 1 :]
    p.write_text(text)

# Regression tests: four and five fingers both resolve to configurable 4+ kind.
p = Path('test/multi_touch_tap_tracker_test.dart')
text = p.read_text()
old = '''    test('recognizes a three-finger tap and ignores four fingers', () {\n      final t0 = DateTime(2026, 1, 1);\n      final three = MultiTouchTapTracker();\n      for (var i = 1; i <= 3; i++) {\n        three.pointerDown(i, Offset(i * 10.0, 10), t0);\n      }\n      three.pointerUp(1, t0.add(const Duration(milliseconds: 60)));\n      three.pointerUp(2, t0.add(const Duration(milliseconds: 80)));\n      expect(\n        three.pointerUp(3, t0.add(const Duration(milliseconds: 100))),\n        MultiTouchTapKind.threeFinger,\n      );\n\n      final four = MultiTouchTapTracker();\n      for (var i = 1; i <= 4; i++) {\n        four.pointerDown(i, Offset(i * 10.0, 10), t0);\n      }\n      for (var i = 1; i <= 3; i++) {\n        four.pointerUp(i, t0.add(const Duration(milliseconds: 80)));\n      }\n      expect(\n        four.pointerUp(4, t0.add(const Duration(milliseconds: 100))),\n        isNull,\n      );\n    });'''
new = '''    test('recognizes three-finger and four-or-more-finger taps', () {\n      final t0 = DateTime(2026, 1, 1);\n      final three = MultiTouchTapTracker();\n      for (var i = 1; i <= 3; i++) {\n        three.pointerDown(i, Offset(i * 10.0, 10), t0);\n      }\n      three.pointerUp(1, t0.add(const Duration(milliseconds: 60)));\n      three.pointerUp(2, t0.add(const Duration(milliseconds: 80)));\n      expect(\n        three.pointerUp(3, t0.add(const Duration(milliseconds: 100))),\n        MultiTouchTapKind.threeFinger,\n      );\n\n      for (final count in [4, 5]) {\n        final tracker = MultiTouchTapTracker();\n        for (var i = 1; i <= count; i++) {\n          tracker.pointerDown(i, Offset(i * 10.0, 10), t0);\n        }\n        for (var i = 1; i < count; i++) {\n          expect(\n            tracker.pointerUp(i, t0.add(const Duration(milliseconds: 80))),\n            isNull,\n          );\n        }\n        expect(\n          tracker.pointerUp(\n            count,\n            t0.add(const Duration(milliseconds: 100)),\n          ),\n          MultiTouchTapKind.fourOrMoreFinger,\n        );\n      }\n    });'''
if old not in text:
    raise SystemExit('test block not found')
p.write_text(text.replace(old, new, 1))
