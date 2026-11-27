// カラーピッカーの「最近使った色」：同じ調整の続き（描く・別の色を選ぶまで）は
// 1つの色として持ち、最近使った色を押すと先頭へ移る。
//
// 実際に使ってみたとき（2026-11-27）、スライダーを離すたびに色が足され、
// 最近使った色がほとんど同じ緑で埋まった。最近使った色を押しても先頭へ
// 移らなかった。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/undo_manager.dart' as app_undo;
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/widgets/color_picker_panel.dart';
import 'package:niarim/services/palette_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/project_storage.dart';

void main() {
  useTemporaryProjectStorage();

  testWidgets('adjusting one colour keeps one recent colour', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    var colour = const Color(0xFF3366CC);
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ColorPickerPanel(
                currentColor: colour,
                onColorChanged: (c) => setState(() => colour = c),
                onClose: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final context = tester.element(find.byType(ColorPickerPanel));
    final palette = context.read<PaletteService>();
    final undo = context.read<app_undo.UndoManager>();
    final before = palette.recentColors.length;

    // The hue slider (the first one under the wheel), dragged three times.
    final hue = find.byType(Slider).first;
    await tester.ensureVisible(hue);
    for (final dx in [40.0, 30.0, -20.0]) {
      await tester.drag(hue, Offset(dx, 0));
      await tester.pump();
    }
    expect(palette.recentColors.length, before + 1, reason: 'one adjustment');
    final adjusted = palette.recentColors.first;
    expect(adjusted, colour.toARGB32());

    // After drawing (one more undo step) the next adjustment is a new colour.
    undo.push(app_undo.ProjectEditUndoAction('stroke', () {}, () {}));
    await tester.drag(hue, const Offset(50, 0));
    await tester.pump();
    expect(palette.recentColors.length, before + 2);
    expect(palette.recentColors[1], adjusted);

    // Pressing an older recent colour moves it to the front.
    final swatch = find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).shape == BoxShape.circle &&
          (w.decoration! as BoxDecoration).color == Color(adjusted),
    );
    await tester.ensureVisible(swatch.first);
    await tester.tap(swatch.first);
    await tester.pump();
    expect(palette.recentColors.first, adjusted);
    expect(palette.recentColors.length, before + 2);
  });
}
