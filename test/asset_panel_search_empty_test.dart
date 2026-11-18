import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/widgets/brush_panel.dart';
import 'package:niarim/screens/canvas/widgets/stamp_panel.dart';
import 'package:niarim/screens/canvas/widgets/tone_panel.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/stamp_service.dart';
import 'package:niarim/services/tone_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/project_storage.dart';

/// ブラシ・トーン・スタンプの一覧を検索で全部隠したとき、「ブラシ／トーン／
/// スタンプがありません」とは言わず、一致しない旨と検索をやめる操作を出す
/// （DISC277：ブラシだけ直り、トーン・スタンプは「ありません」のままだった）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useTemporaryProjectStorage();

  for (final kind in ['brush', 'tone', 'stamp']) {
    testWidgets('$kind: 検索で全部隠れたら「ありません」と言わず検索をやめる道を出す', (tester) async {
      SharedPreferences.setMockInitialValues({
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      });
      final brushes = BrushService();
      final tones = ToneService();
      final stamps = StampService();
      addTearDown(brushes.dispose);
      addTearDown(tones.dispose);
      addTearDown(stamps.dispose);
      await tester.runAsync(() async {
        await brushes.init();
        await tones.init();
        await stamps.init();
      });
      final l10n = lookupAppLocalizations(const Locale('ja'));
      final (Widget panel, String empty) = switch (kind) {
        'brush' => (BrushPanel(onClose: () {}), l10n.brushEmpty),
        'tone' => (TonePanel(onClose: () {}), l10n.toneEmpty),
        _ => (StampPanel(onClose: () {}), l10n.stampEmpty),
      };
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BrushService>.value(value: brushes),
            ChangeNotifierProvider<ToneService>.value(value: tones),
            ChangeNotifierProvider<StampService>.value(value: stamps),
          ],
          child: MaterialApp(
            locale: const Locale('ja'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(body: Center(child: panel)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.search).hitTestable().first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).hitTestable().first,
        'zzzz該当なしqqqq',
      );
      await tester.pumpAndSettle();
      expect(find.text(empty), findsNothing);
      expect(find.text(l10n.helpNoResults), findsOneWidget);
      await tester.tap(find.text(l10n.projectListClearSearch));
      await tester.pumpAndSettle();
      expect(find.text(l10n.helpNoResults), findsNothing);
      expect(find.text(empty), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
