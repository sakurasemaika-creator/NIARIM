import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

/// 演出フィルターのシートの見出しと「追加」が、長い言語・大きな文字・狭い
/// 画面でも重ならず、はみ出さない（DISC027：仏語320px・文字2倍で重なり、
/// 右端にはみ出しの縞が出た）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> settle(WidgetTester tester, [int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  for (final language in ['fr', 'es', 'ja', 'ko']) {
    testWidgets('$language 320px, text x2: header and Add do not overlap', (
      tester,
    ) async {
      tempDir = Directory.systemTemp.createTempSync('niarim_effect_header_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
      appRouter.go('/home');
      SharedPreferences.setMockInitialValues({
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
        'first_launch': false,
        'language': language,
        'force_pc_mode': 0,
      });
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await loadAppFonts(tester);
      final providers = (await tester.runAsync(buildAppProviders))!;
      await tester.pumpWidget(
        MultiProvider(providers: providers, child: const NiarimApp()),
      );
      await settle(tester, 4);
      final service = tester
          .element(find.byType(HomeScreen))
          .read<ProjectService>();
      late String id;
      await tester.runAsync(() async {
        final project = await service.createProject(
          name: 'header',
          fps: 4,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 160,
          exportHeight: 90,
        );
        id = project.id;
      });
      appRouter.push('/timeline/$id');
      await settle(tester, 12);
      final l10n = lookupAppLocalizations(Locale(language));
      final opener = find.byTooltip(l10n.timelineEffectFilterLabel).first;
      await tester.ensureVisible(opener);
      await tester.tap(opener);
      await settle(tester, 6);
      expect(tester.takeException(), isNull);
      final add = find.byKey(const ValueKey('timelineEffectFilterAdd'));
      expect(add, findsOneWidget);
      final title = find.text(l10n.timelineEffectFilterLabel).last;
      final addRect = tester.getRect(add);
      final titleRect = tester.getRect(title);
      expect(
        addRect.overlaps(titleRect),
        isFalse,
        reason: 'title $titleRect, add $addRect',
      );
      expect(addRect.right, lessThanOrEqualTo(320));
    });
  }
}
