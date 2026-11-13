import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/community/community_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture exact Japanese icon-and-label width threshold', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final temp = Directory.systemTemp.createTempSync('plaza-threshold-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => temp.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadAppFonts(tester);

    final boundary = GlobalKey();
    appRouter.go('/community');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MultiProvider(providers: providers!, child: const NiarimApp()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CommunityScreen), findsOneWidget);

    bool showLabels() {
      final bar = find.byType(TabBar);
      expect(bar, findsOneWidget);
      expect(tester.widget<TabBar>(bar).tabs.length, 5);
      return find
          .descendant(
            of: find.byKey(const Key('communityTabWidth0')),
            matching: find.byType(Text),
          )
          .evaluate()
          .isNotEmpty;
    }

    Future<void> setWidth(int width) async {
      tester.view.physicalSize = Size(width.toDouble(), 844);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'width $width');
    }

    const lowerBoundary = 480;
    const upperBoundary = 640;
    await setWidth(lowerBoundary);
    expect(showLabels(), isFalse);
    await setWidth(upperBoundary);
    expect(showLabels(), isTrue);
    var lower = lowerBoundary;
    var upper = upperBoundary;
    while (upper - lower > 1) {
      final mid = (upper + lower) ~/ 2;
      await setWidth(mid);
      if (showLabels()) {
        upper = mid;
      } else {
        lower = mid;
      }
    }

    final dir = Directory('build/community-tab-label-threshold')
      ..createSync(recursive: true);
    for (final width in [lower, upper]) {
      await setWidth(width);
      final expectedVisible = width == upper;
      for (var i = 0; i < 5; i++) {
        final tab = find.byKey(Key('communityTabWidth$i'));
        final textVisible = find
            .descendant(of: tab, matching: find.byType(Text))
            .evaluate()
            .isNotEmpty;
        expect(textVisible, expectedVisible, reason: 'width $width tab $i');
        expect(
          find.descendant(of: tab, matching: find.byType(Icon)),
          findsOneWidget,
        );
        expect(tester.getRect(tab).width, closeTo(width / 5, 0.5));
      }
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final png = await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return data!.buffer.asUint8List();
      });
      File(
        "${dir.path}/${width}dp-${expectedVisible ? 'icon-and-label' : 'icon-only'}.png",
      ).writeAsBytesSync(png!);
    }
    File('${dir.path}/threshold.txt').writeAsStringSync(
      'NIARIM dev_branch, ja, text scale 1.0, devicePixelRatio 1\n'
      'Last icon-only viewport: ${lower}dp\n'
      'First icon-and-label viewport: ${upper}dp\n',
    );
    debugPrint(
      'ADAPTIVE_TAB_THRESHOLD_JA: ${lower}dp icons / ${upper}dp labels',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  }, timeout: const Timeout(Duration(minutes: 6)));
}
