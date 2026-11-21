import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/widgets/tone_panel.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/tone_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('editing a tone updates the active drawing and fill selections', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final tones = ToneService();
    final brushes = BrushService();
    addTearDown(tones.dispose);
    addTearDown(brushes.dispose);
    await tester.runAsync(tones.init);
    tones.duplicateTone('Tone0011', name: 'テストのトーン');
    final tone = tones.tones.last;
    tones.reorderTone(tones.tones.length - 1, 0);
    tones.selectTone(tone.id);
    tones.setLastBucketTone(tone);
    tones.setLastLassoTone(tone);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: tones),
          ChangeNotifierProvider.value(value: brushes),
        ],
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: TonePanel(onClose: () {})),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.text('テストのトーン'));
    await tester.pumpAndSettle();
    final pixelMode = find.widgetWithText(SwitchListTile, 'ドット絵モード');
    expect(tester.widget<SwitchListTile>(pixelMode).value, isFalse);
    await tester.tap(pixelMode);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(pixelMode).value, isTrue);
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(tones.currentTone!.pixelMode, isTrue);
    expect(tones.lastBucketTone!.pixelMode, isTrue);
    expect(tones.lastLassoTone!.pixelMode, isTrue);
    final restarted = ToneService();
    addTearDown(restarted.dispose);
    await tester.runAsync(restarted.init);
    expect(
      restarted.tones.singleWhere((item) => item.id == tone.id).pixelMode,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
