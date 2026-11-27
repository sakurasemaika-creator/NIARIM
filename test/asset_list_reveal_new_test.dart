// ブラシ・トーン・スタンプを複製したら、足した物（一覧の最後）を見える所まで
// 送る。ブラシは足したブラシを選ぶ。
//
// 実際に使ってみたとき（2026-11-27）、複製・新しく作った素材が一覧の末尾に
// 黙って入り、検索で探さないと見つからなかった。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/widgets/brush_panel.dart';
import 'package:niarim/screens/canvas/widgets/stamp_panel.dart';
import 'package:niarim/screens/canvas/widgets/tone_panel.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/stamp_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/services/tone_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/project_storage.dart';

void main() {
  useTemporaryProjectStorage();

  Future<void> mount(WidgetTester tester, Widget panel) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(400, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (context) => MaterialApp(
            theme: context.watch<ThemeService>().themeData,
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: panel),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> duplicateFirst(WidgetTester tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('ja'));
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.themeDuplicateAction).last);
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  bool shown(WidgetTester tester, String name) =>
      find.text(name).hitTestable().evaluate().isNotEmpty;

  testWidgets('a duplicated brush is chosen and shown', (tester) async {
    await mount(tester, BrushPanel(onClose: () {}));
    final brushes = tester
        .element(find.byType(BrushPanel))
        .read<BrushService>();
    final count = brushes.brushes.length;
    await duplicateFirst(tester);
    expect(brushes.brushes.length, count + 1);
    final copy = brushes.brushes.last;
    expect(brushes.currentBrush?.id, copy.id);
    expect(shown(tester, copy.name), isTrue, reason: 'scrolled to the copy');
  });

  testWidgets('a duplicated tone is shown', (tester) async {
    await mount(tester, TonePanel(onClose: () {}));
    final tones = tester.element(find.byType(TonePanel)).read<ToneService>();
    final count = tones.tones.length;
    await duplicateFirst(tester);
    expect(tones.tones.length, count + 1);
    expect(shown(tester, tones.tones.last.name), isTrue);
  });

  testWidgets('a duplicated stamp is shown', (tester) async {
    await mount(tester, StampPanel(onClose: () {}));
    final stamps = tester.element(find.byType(StampPanel)).read<StampService>();
    final count = stamps.stamps.length;
    await duplicateFirst(tester);
    expect(stamps.stamps.length, count + 1);
    expect(shown(tester, stamps.stamps.last.name), isTrue);
  });
}
