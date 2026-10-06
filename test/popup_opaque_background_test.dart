import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/color_contrast.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Popups (dialogs, bottom sheets, menus, tooltips, the colour picker's card)
/// and toasts (SnackBars) never let the screen behind them show through —
/// not with any built-in theme, and not with a theme whose colours were
/// picked with transparency (the theme colour picker allows that).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// A custom theme with every background colour see-through.
  AppThemePreset translucent(AppThemePreset base) => base.copyWith(
    id: 'translucent',
    menuBgColor: const Color(0x80FFF2C0),
    panelBgColor: const Color(0x99203040),
    accentColor: const Color(0x6600AAFF),
  );

  Future<ThemeService> themes() async {
    SharedPreferences.setMockInitialValues({});
    final service = ThemeService();
    await service.init();
    return service;
  }

  /// Every background a popup or a toast takes from the theme.
  Map<String, Color?> popupBackgrounds(ThemeData theme) => {
    'dialog': theme.dialogTheme.backgroundColor,
    'bottom sheet': theme.bottomSheetTheme.backgroundColor,
    'modal bottom sheet': theme.bottomSheetTheme.modalBackgroundColor,
    'snack bar': theme.snackBarTheme.backgroundColor,
    'card (colour picker dialog)': theme.cardTheme.color,
    'tooltip': (theme.tooltipTheme.decoration as BoxDecoration?)?.color,
    'popup menu (surfaceContainer)': theme.colorScheme.surfaceContainer,
    'dropdown (canvasColor)': theme.canvasColor,
    'first-use bubble (primary)': theme.colorScheme.primary,
  };

  test('every built-in theme and a see-through custom theme give popups and '
      'toasts an opaque background', () async {
    final service = await themes();
    final presets = [...service.presets, translucent(service.presets.first)];
    expect(service.presets.length, greaterThanOrEqualTo(28));
    for (final preset in presets) {
      service.previewCurrent(preset);
      for (final entry in popupBackgrounds(service.themeData).entries) {
        expect(entry.value, isNotNull, reason: '${preset.id}: ${entry.key}');
        expect(
          entry.value!.a,
          1.0,
          reason: '${preset.id}: ${entry.key} lets the screen show through',
        );
      }
    }
  });

  test('an opaque theme keeps its own menu colour; a see-through one shows '
      'the colour it had over the panel', () async {
    final service = await themes();
    final preset = service.presets.first;
    service.previewCurrent(preset);
    expect(service.themeData.dialogTheme.backgroundColor, preset.menuBgColor);
    expect(service.themeData.colorScheme.primary, preset.accentColor);

    final custom = translucent(preset);
    service.previewCurrent(custom);
    final panel = Color.alphaBlend(custom.panelBgColor, Colors.black);
    expect(
      service.themeData.dialogTheme.backgroundColor,
      Color.alphaBlend(custom.menuBgColor, panel),
    );
    expect(
      opaqueOver(const Color(0xFF123456), Colors.red),
      const Color(0xFF123456),
    );
  });

  testWidgets('on screen, nothing behind a popup or a toast shows through', (
    tester,
  ) async {
    final service = await tester.runAsync(themes);
    service!.previewCurrent(translucent(service.presets.first));
    final theme = service.themeData;
    final popup = theme.dialogTheme.backgroundColor!;
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final boundary = GlobalKey();
    final tooltip = GlobalKey<TooltipState>();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          theme: theme,
          home: Scaffold(
            // Bright red behind everything: any of it in a popup means the
            // popup is see-through.
            backgroundColor: const Color(0xFFFF0000),
            body: Center(
              child: Tooltip(
                key: tooltip,
                message: 'hint',
                child: const SizedBox(width: 40, height: 40),
              ),
            ),
          ),
        ),
      ),
    );
    final context = tester.element(find.byType(SizedBox).last);

    /// The colour on screen at [point] (logical pixels).
    Future<Color> colourAt(Offset point) async {
      final pixel = await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final i = (point.dy.round() * image.width + point.dx.round()) * 4;
        image.dispose();
        return data!.buffer.asUint8List().sublist(i, i + 4);
      });
      return Color.fromARGB(pixel![3], pixel[0], pixel[1], pixel[2]);
    }

    void expectColour(Color actual, Color expected, String what) {
      for (final (a, e) in [
        (actual.r, expected.r),
        (actual.g, expected.g),
        (actual.b, expected.b),
      ]) {
        expect((a - e).abs(), lessThan(3 / 255), reason: '$what: $actual');
      }
    }

    // A dialog: its padding beside the content.
    showDialog<void>(
      context: context,
      builder: (_) =>
          const AlertDialog(content: SizedBox(width: 200, height: 120)),
    );
    await tester.pumpAndSettle();
    var rect = tester.getRect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(Material),
      ),
    );
    expectColour(
      await colourAt(Offset(rect.left + 12, rect.center.dy)),
      popup,
      'dialog',
    );
    Navigator.of(context).pop();
    await tester.pumpAndSettle();

    // A modal bottom sheet.
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => const SizedBox(width: double.infinity, height: 200),
    );
    await tester.pumpAndSettle();
    rect = tester.getRect(find.byType(BottomSheet));
    expectColour(await colourAt(rect.center), popup, 'bottom sheet');
    Navigator.of(context).pop();
    await tester.pumpAndSettle();

    // A toast.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: SizedBox(height: 20),
        duration: Duration(seconds: 30),
      ),
    );
    await tester.pumpAndSettle();
    rect = tester.getRect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.byType(Material),
      ),
    );
    expectColour(
      await colourAt(Offset(rect.left + 6, rect.center.dy)),
      theme.snackBarTheme.backgroundColor!,
      'snack bar',
    );
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    await tester.pumpAndSettle();

    // A popup menu.
    showMenu<void>(
      context: context,
      position: const RelativeRect.fromLTRB(40, 200, 40, 0),
      items: const [PopupMenuItem<void>(child: SizedBox(width: 120))],
    );
    await tester.pumpAndSettle();
    rect = tester.getRect(find.byType(PopupMenuItem<void>));
    expectColour(
      await colourAt(Offset(rect.left + 4, rect.center.dy)),
      theme.colorScheme.surfaceContainer,
      'popup menu',
    );
    Navigator.of(context).pop();
    await tester.pumpAndSettle();

    // A tooltip: its padding beside the text.
    tooltip.currentState!.ensureTooltipVisible();
    await tester.pumpAndSettle();
    rect = tester.getRect(find.text('hint'));
    expectColour(
      await colourAt(Offset(rect.left - 4, rect.center.dy)),
      (theme.tooltipTheme.decoration! as BoxDecoration).color!,
      'tooltip',
    );
    Tooltip.dismissAllToolTips();
    await tester.pumpAndSettle();
  });
}
