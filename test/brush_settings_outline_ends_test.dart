// 縁取りペン（髪・リボン）の端は形だけを細くする（入り抜き）。透けない
// （所有者の仕様「全体の形だけ」）ので、設定のシートにフェードは出さず、
// 入り抜きだけを出す。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/widgets/brush_panel.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final appDocs = Directory(
    '${Directory.systemTemp.path}/niarim_brush_settings_sheet_docs',
  );
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() {
    appDocs.createSync(recursive: true);
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (_) async {
          return appDocs.path;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  testWidgets('an outline pen has 入り抜き but no フェード in its sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadAppFonts(tester);

    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (themeContext) => MaterialApp(
            theme: themeContext.watch<ThemeService>().themeData,
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: BrushPanel(onClose: () {})),
          ),
        ),
      ),
    );
    await tester.pump();
    final context = tester.element(find.byType(BrushPanel));
    final brushes = context.read<BrushService>();
    // 組み込みブラシは長押しで開かないので、複製した髪のブラシを編集する。
    final before = brushes.brushes.map((b) => b.id).toSet();
    brushes.duplicateBrush('Brush0023');
    final copy = brushes.brushes.firstWhere((b) => !before.contains(b.id));
    await tester.pump();
    final tile = find.text(copy.name);
    await tester.scrollUntilVisible(
      tile,
      200,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first,
    );
    await tester.longPress(tile);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('brush-fade-off')), findsNothing);
    final taperCustom = find.byKey(const Key('brush-taper-custom'));
    await tester.ensureVisible(taperCustom);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(taperCustom).selected, isTrue);
    expect(tester.takeException(), isNull);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  });
}
