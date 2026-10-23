import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/canvas_dock_panel.dart';
import 'package:niarim/models/toolbar_item.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'settings numeric, workspace and first-launch values persist with clamping',
    () async {
      final s = SettingsService();
      await s.init();

      expect(SettingsService.trackHeightForLevel(0), 28.0);
      expect(SettingsService.trackHeightForLevel(6), 60.0);

      await s.setBucketTolerance(150);
      await s.setBucketExpandPx(-4);
      await s.setBucketFillUnderLine(true);
      await s.setHoldEyedropperEnabled(false);
      await s.setHoldEyedropperSeconds(99);
      await s.setTimelinePreviewHeightFraction(0.01);
      await s.setTimelineTrackHeightLevel(99);
      await s.setDesktopPanelWidth(1000);
      await s.setDesktopToolPanelWidth(10);
      await s.setDefaultFps(24);
      await s.setLanguage('en');
      await s.setDefaultDrawingArea(enabled: true, scale: 99);
      await s.setUndoLimit(123);
      await s.setTrashAutoDelete(30);
      await s.setForcePcMode(true);
      await s.setLeftHanded(true);
      await s.setEndCardDefaultHiddenForPremium(true);
      await s.markFirstLaunchDone();

      expect(s.bucketTolerance, 100);
      expect(s.bucketExpandPx, 0);
      expect(s.bucketFillUnderLine, isTrue);
      expect(s.holdEyedropperEnabled, isFalse);
      expect(s.holdEyedropperSeconds, 3.0);
      expect(s.timelinePreviewHeightFraction, 0.18);
      expect(s.timelineTrackHeightLevel, 5);
      expect(s.desktopPanelWidth, 480);
      expect(s.desktopToolPanelWidth, 200);
      expect(s.defaultFps, 24);
      expect(s.language, 'en');
      expect(s.defaultDrawingAreaEnabled, isTrue);
      expect(s.defaultDrawingAreaScale, 10);
      expect(s.undoLimit, 123);
      expect(s.trashAutoDeleteDays, 30);
      expect(s.forcePcMode, isTrue);
      expect(s.isLeftHanded, isTrue);
      expect(s.endCardDefaultHiddenForPremium, isTrue);
      expect(s.isFirstLaunch, isFalse);

      s.notifyPointerDeviceSeen(PointerDeviceKind.touch);
      expect(s.hasNonTouchPointer, isFalse);
      s.notifyPointerDeviceSeen(PointerDeviceKind.mouse);
      expect(s.hasNonTouchPointer, isTrue);
      s.notifyPointerDeviceSeen(PointerDeviceKind.stylus);
      s.notifyPointerDeviceSeen(PointerDeviceKind.invertedStylus);
      expect(s.hasNonTouchPointer, isTrue);

      final restored = SettingsService();
      await restored.init();
      expect(restored.bucketTolerance, 100);
      expect(restored.bucketExpandPx, 0);
      expect(restored.bucketFillUnderLine, isTrue);
      expect(restored.holdEyedropperEnabled, isFalse);
      expect(restored.holdEyedropperSeconds, 3.0);
      expect(restored.timelinePreviewHeightFraction, 0.18);
      expect(restored.timelineTrackHeightLevel, 5);
      expect(restored.desktopPanelWidth, 480);
      expect(restored.desktopToolPanelWidth, 200);
      expect(restored.defaultFps, 24);
      expect(restored.language, 'en');
      expect(restored.defaultDrawingAreaEnabled, isTrue);
      expect(restored.defaultDrawingAreaScale, 10);
      expect(restored.undoLimit, 123);
      expect(restored.trashAutoDeleteDays, 30);
      expect(restored.forcePcMode, isTrue);
      expect(restored.isLeftHanded, isTrue);
      expect(restored.endCardDefaultHiddenForPremium, isTrue);
      expect(restored.isFirstLaunch, isFalse);

      await restored.setForcePcMode(null);
      expect(restored.forcePcMode, isNull);
      await restored.setForcePcMode(false);
      expect(restored.forcePcMode, isFalse);
    },
  );

  test(
    'toolbar, docks, all gesture actions and pressure curves round-trip',
    () async {
      final s = SettingsService();
      await s.init();

      const allToolbar = <ToolbarItemId>[
        ToolbarItemId.pen,
        ToolbarItemId.eraser,
        ToolbarItemId.bucket,
        ToolbarItemId.eyedropper,
        ToolbarItemId.finger,
        ToolbarItemId.pan,
        ToolbarItemId.select,
        ToolbarItemId.text,
        ToolbarItemId.shape,
      ];
      const allDockPanels = <CanvasDockPanel>{
        CanvasDockPanel.brush,
        CanvasDockPanel.colorPicker,
        CanvasDockPanel.layer,
        CanvasDockPanel.tone,
        CanvasDockPanel.stamp,
        CanvasDockPanel.penSubTool,
        CanvasDockPanel.onionSkin,
        CanvasDockPanel.ruler,
        CanvasDockPanel.filter,
        CanvasDockPanel.quickTool,
        CanvasDockPanel.colorAdjust,
        CanvasDockPanel.canvasPreview,
      };
      expect(ToolbarItemId.values, allToolbar);
      expect(CanvasDockPanel.values.toSet(), allDockPanels);

      final reversed = allToolbar.reversed.toList();
      await s.setToolbarOrder(reversed);
      await s.setToolbarItemVisible(ToolbarItemId.bucket, false);
      await s.setToolbarItemVisible(ToolbarItemId.text, false);
      expect(s.toolbarOrder, reversed);
      expect(
        s.hiddenToolbarItems,
        containsAll([ToolbarItemId.bucket, ToolbarItemId.text]),
      );
      await s.setToolbarItemVisible(ToolbarItemId.bucket, true);
      expect(s.hiddenToolbarItems, isNot(contains(ToolbarItemId.bucket)));

      await s.setDefaultDockedPanels(allDockPanels);
      expect(s.defaultDockedPanels, allDockPanels);
      final toolDockOrder = <CanvasDockPanel>[
        CanvasDockPanel.quickTool,
        CanvasDockPanel.filter,
        CanvasDockPanel.ruler,
        CanvasDockPanel.onionSkin,
        CanvasDockPanel.stamp,
        CanvasDockPanel.tone,
        CanvasDockPanel.brush,
        CanvasDockPanel.penSubTool,
        CanvasDockPanel.colorAdjust,
      ];
      await s.setToolOptionDockOrder(toolDockOrder);
      expect(s.toolOptionDockOrder, toolDockOrder);
      await s.resetToolOptionDockOrder();
      expect(s.toolOptionDockOrder, isNotEmpty);

      final rightDockOrder = <CanvasDockPanel>[
        CanvasDockPanel.layer,
        CanvasDockPanel.colorPicker,
        CanvasDockPanel.canvasPreview,
      ];
      await s.setRightDockOrder(rightDockOrder);
      expect(s.rightDockOrder, rightDockOrder);
      await s.resetRightDockOrder();
      expect(s.rightDockOrder, isNotEmpty);

      await s.applyToolbarPreset(
        [ToolbarItemId.pen, ToolbarItemId.eraser],
        {ToolbarItemId.shape},
      );
      expect(s.toolbarOrder, [ToolbarItemId.pen, ToolbarItemId.eraser]);
      expect(s.hiddenToolbarItems, {ToolbarItemId.shape});
      await s.resetToolbarDefault();
      expect(s.toolbarOrder, ToolbarItemId.values);
      expect(s.hiddenToolbarItems, isEmpty);
      await s.applyToolbarPreset(const [], {ToolbarItemId.finger});
      expect(s.toolbarOrder, ToolbarItemId.values);
      expect(s.hiddenToolbarItems, {ToolbarItemId.finger});

      const actions = <GestureAction>[
        GestureAction.undo,
        GestureAction.redo,
        GestureAction.eyedropper,
        GestureAction.panTool,
        GestureAction.eraserToggle,
        GestureAction.brushToggle,
        GestureAction.frameMove,
        GestureAction.nextTool,
        GestureAction.none,
        GestureAction.onionSkinToggle,
      ];
      expect(GestureAction.values, actions);
      const types = <GestureType>[
        GestureType.twoFingerTap,
        GestureType.threeFingerTap,
        GestureType.fourOrMoreFingerTap,
        GestureType.twoFingerSwipe,
        GestureType.longPress,
      ];
      expect(GestureType.values, types);
      for (var i = 0; i < types.length; i++) {
        await s.setGesture(types[i], actions[i]);
      }
      expect(s.twoFingerTap, GestureAction.undo);
      expect(s.threeFingerTap, GestureAction.redo);
      expect(s.fourOrMoreFingerTap, GestureAction.eyedropper);
      expect(s.twoFingerSwipe, GestureAction.panTool);
      expect(s.longPress, GestureAction.eraserToggle);
      for (final action in actions.skip(types.length)) {
        await s.setGesture(GestureType.longPress, action);
        expect(s.longPress, action);
      }

      await s.setPenButton(1, GestureAction.brushToggle);
      await s.setPenButton(2, GestureAction.onionSkinToggle);
      expect(s.penButton1, GestureAction.brushToggle);
      expect(s.penButton2, GestureAction.onionSkinToggle);

      const curves = <PenPressureCurve>[
        PenPressureCurve.weak,
        PenPressureCurve.normal,
        PenPressureCurve.strong,
        PenPressureCurve.custom,
      ];
      expect(PenPressureCurve.values, curves);
      await s.setPenPressureCurve(PenPressureCurve.weak);
      expect(s.applyPressureCurve(0.5), lessThan(0.5));
      await s.setPenPressureCurve(PenPressureCurve.normal);
      expect(s.applyPressureCurve(0.5), closeTo(0.5, 1e-9));
      await s.setPenPressureCurve(PenPressureCurve.strong);
      expect(s.applyPressureCurve(0.5), greaterThan(0.5));

      await s.addCustomPressurePoint(0.5, 0.8);
      await s.moveCustomPressurePoint(1, 0.4, 0.7);
      await s.setPenPressureCurve(PenPressureCurve.custom);
      expect(s.customPressurePoints, hasLength(3));
      expect(s.applyPressureCurve(0.4), closeTo(0.7, 1e-9));
      await s.moveCustomPressurePoint(0, 0.9, 0.2);
      expect(s.customPressurePoints.first.$1, 0.0);
      await s.removeCustomPressurePoint(1);
      expect(s.customPressurePoints, hasLength(2));
      await s.removeCustomPressurePoint(0);
      expect(s.customPressurePoints, hasLength(2));
      await s.resetCustomPressureCurve();
      expect(s.customPressurePoints, const [(0.0, 0.0), (1.0, 1.0)]);

      final restored = SettingsService();
      await restored.init();
      expect(restored.defaultDockedPanels, allDockPanels);
      expect(restored.penButton1, GestureAction.brushToggle);
      expect(restored.penButton2, GestureAction.onionSkinToggle);
      expect(restored.penPressureCurve, PenPressureCurve.custom);
      expect(restored.customPressurePoints, const [(0.0, 0.0), (1.0, 1.0)]);
    },
  );

  test(
    'custom canvas size presets add update duplicate reorder and remove persist',
    () async {
      final s = SettingsService();
      await s.init();
      await s.addCustomSizePreset('A', 100, 200);
      await Future<void>.delayed(const Duration(microseconds: 1));
      await s.addCustomSizePreset('B', 300, 400);
      expect(s.customSizePresets, hasLength(2));

      final firstId = s.customSizePresets.first.id;
      await s.updateCustomSizePreset(
        firstId,
        name: 'A2',
        width: 111,
        height: 222,
      );
      expect(s.customSizePresets.first.name, 'A2');
      expect(s.customSizePresets.first.width, 111);
      expect(s.customSizePresets.first.height, 222);

      await s.duplicateCustomSizePreset(firstId, 'A copy');
      expect(s.customSizePresets, hasLength(3));
      expect(s.customSizePresets.last.name, 'A copy');
      expect(s.customSizePresets.last.width, 111);
      expect(s.customSizePresets.last.height, 222);
      await s.duplicateCustomSizePreset('missing', 'ignored');
      expect(s.customSizePresets, hasLength(3));

      await s.reorderCustomSizePresets(0, 3);
      expect(s.customSizePresets.last.id, firstId);
      await s.removeCustomSizePreset(firstId);
      expect(s.customSizePresets.map((e) => e.id), isNot(contains(firstId)));

      final restored = SettingsService();
      await restored.init();
      expect(restored.customSizePresets, hasLength(2));
      expect(restored.customSizePresets.map((e) => e.name), contains('A copy'));
    },
  );
}
