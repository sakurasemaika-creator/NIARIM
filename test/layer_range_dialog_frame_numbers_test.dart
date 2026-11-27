// レイヤーの表示範囲：番号を打つ・「最初から最後のフレームまで」を押すと、
// 「フレーム範囲指定」になる（番号はその指定のときだけ使う）。
//
// 実際に使ってみたとき（2026-11-27）、「現在範囲を使用」というボタンが
// 1〜最後のコマを入れるだけで、何の範囲か分からなかった。「全フレーム」の
// まま番号を打っても、番号は使われなかった。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/widgets/layer_range_dialog.dart';

void main() {
  Future<List<Object?>> confirmAfter(
    WidgetTester tester,
    Future<void> Function(AppLocalizations l10n) act,
  ) async {
    List<Object?>? result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LayerRangeDialog(
            layer: const Layer(
              id: 'l',
              name: 'star',
              type: LayerType.common,
              rangeMode: LayerRangeMode.allFrames,
            ),
            homeSceneId: 's',
            totalFrames: 24,
            scenes: const [],
            onConfirm: (mode, start, end, scene) => result = [mode, start, end],
          ),
        ),
      ),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('ja'));
    await act(l10n);
    await tester.pump();
    await tester.tap(find.text(l10n.commonOk));
    await tester.pump();
    return result!;
  }

  testWidgets('the whole-scene button picks the frame range', (tester) async {
    final result = await confirmAfter(tester, (l10n) async {
      await tester.tap(find.text(l10n.layerPanelRangeUseCurrentButton));
    });
    expect(result, [LayerRangeMode.frameRange, 1, 24]);
  });

  testWidgets('typing a frame number picks the frame range', (tester) async {
    final result = await confirmAfter(tester, (l10n) async {
      await tester.enterText(find.byType(TextField).first, '5');
    });
    expect(result, [LayerRangeMode.frameRange, 5, 24]);
  });
}
