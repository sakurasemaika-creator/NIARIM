// スライダーはスマホの狭い画面でも横幅いっぱいに使う（ユーザー指定）：
// 1行目に項目名と値（鉛筆マーク付き）を同じ高さで並べ、2行目は
// －・スライダー・＋だけにする。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/widgets/labeled_slider.dart';

void main() {
  testWidgets('項目名と値は同じ高さ、スライダーは画面幅いっぱい', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var value = 40.0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LabeledSlider(
                label: '水分量',
                value: value,
                min: 0,
                max: 100,
                valueText: '${value.round()}',
                onChanged: (v) => setState(() => value = v),
              ),
            ),
          ),
        ),
      ),
    );

    final label = tester.getRect(find.text('水分量'));
    final shown = tester.getRect(find.text('40'));
    // 値は項目名と同じ行の右端（鉛筆マークも同じ行）。
    expect(shown.center.dy, closeTo(label.center.dy, 1));
    expect(shown.left, greaterThan(360 / 2));
    expect(
      tester.getRect(find.byIcon(Icons.edit)).center.dy,
      closeTo(label.center.dy, 2),
    );
    // スライダーは項目名の下で、－と＋の間を埋める。
    final slider = tester.getRect(find.byType(Slider));
    expect(slider.top, greaterThanOrEqualTo(label.bottom));
    expect(slider.width, greaterThanOrEqualTo(360 - 32 - 2 * 40));
    final minus = tester.getRect(find.byIcon(Icons.remove_circle_outline));
    final plus = tester.getRect(find.byIcon(Icons.add_circle_outline));
    expect(minus.center.dy, closeTo(slider.center.dy, 1));
    expect(plus.center.dy, closeTo(slider.center.dy, 1));

    // ＋で1つ増え、値の表示も変わる。
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pump();
    expect(find.text('41'), findsOneWidget);
  });
}
