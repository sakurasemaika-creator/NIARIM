import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/making_export.dart';
import 'package:niarim/engine/niatra_serializer.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/export/export_screen.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/project/making_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/pump_real_async.dart';

/// 作品の書き出しとメイキング動画の書き出しは、それぞれ最後に選んだ形式で
/// 始まる（以前は開くたびにMP4へ戻った。Linuxの実画面で発見、P3-10）。
/// 選んだ形式は設定に残り（起動し直しても）、設定の引き継ぎでも移る。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  final l10n = lookupAppLocalizations(const Locale('ja'));
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('niarim-export-format-');
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

  test('both choices move with the settings transfer', () {
    expect(NiatraSerializer.settingKeys, contains('export_format'));
    expect(NiatraSerializer.settingKeys, contains('making_export_format'));
  });

  testWidgets('the work’s export opens with the format chosen last', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    appRouter.go('/home');
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    final projects = tester
        .element(find.byType(HomeScreen))
        .read<ProjectService>();
    final work = (await tester.runAsync(
      () => projects.createProject(
        name: '書き出し',
        fps: 2,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 64,
      ),
    ))!;

    ExportFormat shown() => tester
        .widget<RadioGroup<ExportFormat>>(find.byType(RadioGroup<ExportFormat>))
        .groupValue!;

    Future<void> openExport() async {
      appRouter.push('/export/${work.id}');
      await pumpRealAsync(tester, const Duration(milliseconds: 400));
      expect(find.byType(ExportScreen), findsOneWidget);
    }

    await openExport();
    expect(shown(), ExportFormat.mp4, reason: '選んだことが無ければMP4');
    final gif = find.widgetWithText(RadioListTile<ExportFormat>, 'GIF');
    await tester.ensureVisible(gif);
    await tester.tap(gif);
    await pumpRealAsync(tester, const Duration(milliseconds: 200));
    expect(shown(), ExportFormat.gif);
    appRouter.pop();
    await pumpRealAsync(tester, const Duration(milliseconds: 400));

    await openExport();
    expect(shown(), ExportFormat.gif, reason: '最後に選んだ形式で始まる');
    final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
    expect(prefs.getString('export_format'), 'gif');
    // 起動し直しても残る。
    final again = SettingsService();
    await tester.runAsync(again.init);
    expect(again.exportFormat, 'gif');
    expect(again.makingExportFormat, isNull);
    appRouter.pop();
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the making video’s export opens with the format chosen last', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // 以前の版の絵の記録（3枚）。
    const id = 'making_project';
    final making = Directory('${temp.path}/niarim/projects/$id/Making')
      ..createSync(recursive: true);
    for (var i = 1; i <= 3; i++) {
      final picture = img.Image(width: 32, height: 24)
        ..clear(img.ColorRgb8(255, 255, 255));
      File(
        '${making.path}/making_${i.toString().padLeft(6, '0')}.jpg',
      ).writeAsBytesSync(img.encodeJpg(picture));
    }
    final themes = ThemeService();
    await tester.runAsync(themes.init);

    Future<void> pumpMaking() async {
      final settings = SettingsService();
      await tester.runAsync(settings.init);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: themes),
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider(create: (_) => ProjectService()),
          ],
          child: MaterialApp(
            theme: themes.themeData,
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const MakingScreen(projectId: id),
          ),
        ),
      );
      final format = find.byType(DropdownButtonFormField<MakingExportFormat>);
      for (var i = 0; i < 100 && format.evaluate().isEmpty; i++) {
        await pumpRealAsync(tester, const Duration(milliseconds: 50));
      }
      expect(format, findsOneWidget);
    }

    MakingExportFormat shown() => tester
        .widget<DropdownButtonFormField<MakingExportFormat>>(
          find.byType(DropdownButtonFormField<MakingExportFormat>),
        )
        .initialValue!;

    await pumpMaking();
    expect(shown(), MakingExportFormat.mp4, reason: '選んだことが無ければMP4');
    await tester.tap(find.byType(DropdownButtonFormField<MakingExportFormat>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.exportFormatAvi).last);
    await tester.pumpAndSettle();
    await pumpRealAsync(tester, const Duration(milliseconds: 100));

    // 開き直す（起動し直しても同じ設定を読む）。
    await pumpMaking();
    expect(shown(), MakingExportFormat.avi, reason: '最後に選んだ形式で始まる');
    final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
    expect(prefs.getString('making_export_format'), 'avi');
    expect(prefs.getString('export_format'), isNull, reason: '作品の書き出しとは別');
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpRealAsync(tester, const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });
}
