import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/canvas/widgets/hsv_color_wheel.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final panelWidth in <double>[236, 264, 288]) {
    testWidgets(
      'Wheel corners do not overlap hue ring or clip RGB at $panelWidth dp',
      (tester) async {
        final theme = ThemeService();
        addTearDown(theme.dispose);
        await tester.pumpWidget(
          ChangeNotifierProvider<ThemeService>.value(
            value: theme,
            child: MaterialApp(
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: HsvColorWheel(
                    size: 236,
                    controlsWidth: panelWidth,
                    hue: 0,
                    saturation: 0.6,
                    value: 0.8,
                    onHueChanged: (_) {},
                    onSvChanged: (_, __) {},
                    onEyedropperTap: () {},
                    onToggleTransparent: () {},
                    onSliderModeChanged: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );

        final wheel = tester.getRect(find.byType(HsvColorWheel));
        const radius = 118.0;
        final center = Offset(wheel.left + panelWidth / 2,
            wheel.top + radius);
        for (final name in [
          'color-picker-transparent-toggle',
          'color-picker-eyedropper',
          'color-slider-mode-hsv',
          'color-slider-mode-rgb',
        ]) {
          final key = find.byKey(ValueKey(name));
          expect(key, findsOneWidget, reason: name);
          final rect = tester.getRect(key);
          final nearest = Offset(
            math.max(rect.left, math.min(center.dx, rect.right)),
            math.max(rect.top, math.min(center.dy, rect.bottom)),
          );
          expect((nearest - center).distance,
              greaterThanOrEqualTo(radius - 2),
              reason: '$name overlapped the ring at $panelWidth dp');
        }
        final rgb = tester.getRect(
            find.byKey(const ValueKey('color-slider-mode-rgb')));
        expect(rgb.right, lessThanOrEqualTo(wheel.right - 4),
            reason: 'RGB must leave space for a scroll bar');
        expect(rgb.bottom, lessThanOrEqualTo(wheel.bottom),
            reason: 'The picker must allocate enough height for the pill');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
