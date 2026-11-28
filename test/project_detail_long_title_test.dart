import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/project/project_detail_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/widgets/fit_or_hide_title.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

/// 作品詳細の題（作品名）は、入らなければ1行で「…」にし（隠さない）、押すと
/// 全部の名前を吹き出しで出す。以前は13字の「Bouncing Ball Practice」でも
/// 「Bouncing B…」のまま、全部の名前を見る所が無かった（Linuxの実画面で
/// 発見、P1-18）。入る名前はそのまま（吹き出しも付けない）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('niarim-detail-title-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => temp.path);
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'language': 'ja',
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  Future<void> openDetail(WidgetTester tester, String name) async {
    await loadAppFonts(tester);
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    appRouter.go('/home');
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await tester.pump();
    final service = tester
        .element(find.byType(HomeScreen))
        .read<ProjectService>();
    final work = (await tester.runAsync(
      () => service.createProject(
        name: name,
        fps: 2,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 64,
      ),
    ))!;
    appRouter.go('/project/${work.id}');
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(ProjectDetailScreen), findsOneWidget);
  }

  Finder title() => find.descendant(
    of: find.byType(AppBar),
    matching: find.byType(DataTitle),
  );

  testWidgets('a long work name ends in … and a tap shows all of it', (
    tester,
  ) async {
    const name = 'Bouncing Ball Practice for Monday';
    await openDetail(tester, name);
    expect(title(), findsOneWidget);
    final text = tester.widget<Text>(
      find.descendant(of: title(), matching: find.text(name)),
    );
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.maxLines, 1);
    final tooltip = tester.widget<Tooltip>(
      find.byKey(const Key('dataTitleFullName')),
    );
    expect(tooltip.message, name);
    // 押すと全部の名前が吹き出しに出る。
    await tester.tap(title());
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text(name), findsNWidgets(2));
    // 読み上げは全部の名前（吹き出しで二重にしない）。
    expect(tooltip.excludeFromSemantics, isTrue);
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a short work name is shown as it is', (tester) async {
    await openDetail(tester, 'Ball');
    expect(title(), findsOneWidget);
    expect(find.byKey(const Key('dataTitleFullName')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
