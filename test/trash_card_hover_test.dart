import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/splash/splash_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// DISC098の4：ゴミ箱のカードにマウスを載せた色（とカードを押せる所）は、
/// カード全体に届く。以前は名前の行（ListTile）だけで、ボタンの行の空いた
/// 所に載せると色が付かず、カードの上半分だけが反応していた。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_trash_hover_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    appRouter.go('/');
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'language': 'en',
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    for (var attempt = 0; tempDir.existsSync(); attempt++) {
      try {
        await tempDir.delete(recursive: true);
      } on FileSystemException {
        if (attempt == 19) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }
  });

  Future<void> settle(WidgetTester tester, {int rounds = 4}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('the whole trash card, button row included, takes the hover '
      'and the long press', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final service = tester
        .element(find.byType(SplashScreen))
        .read<ProjectService>();
    late final String workId;
    await tester.runAsync(() async {
      final work = await service.createProject(
        name: 'Seaside sketch',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
      );
      workId = work.id;
      await service.deleteProject(work.id);
    });
    await tester.tap(find.byIcon(Icons.brush_outlined));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('home_tab_3')));
    await settle(tester, rounds: 6);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);

    for (final size in const [Size(360, 800), Size(1280, 800)]) {
      tester.view.physicalSize = size;
      await settle(tester, rounds: 2);
      final delete = find.byKey(ValueKey('trash-delete-$workId'));
      final cardFinder = find
          .ancestor(of: delete, matching: find.byType(Card))
          .first;
      // カードの面（Cardの外側の余白を除いた所）。
      final card = tester.getRect(
        find.descendant(of: cardFinder, matching: find.byType(Material)).first,
      );
      // カードを押す・長押しする所（ボタン自身のものを除く）。
      final surface = find.descendant(
        of: cardFinder,
        matching: find.byWidgetPredicate(
          (widget) => widget is InkWell && widget.onLongPress != null,
        ),
      );
      expect(surface, findsOneWidget, reason: '$size');
      final surfaceRect = tester.getRect(surface);
      expect(
        surfaceRect.height,
        moreOrLessEquals(card.height, epsilon: 0.5),
        reason: '$size: the hover/press area stops at the name row',
      );
      final target = tester.renderObject(surface);
      final button = tester.getRect(delete);
      // ボタンの行の空いた所（狭いカードは左側、広いカードは下の端の近く）。
      final points = [
        Offset(card.left + 24, button.center.dy),
        Offset(card.left + 24, card.bottom - 3),
        Offset(card.right - 3, button.center.dy),
      ];
      for (final point in points) {
        await mouse.moveTo(point);
        await tester.pump(const Duration(milliseconds: 200));
        final hit = tester.hitTestOnBinding(point);
        expect(
          hit.path.any((entry) => identical(entry.target, target)),
          isTrue,
          reason: '$size: hovering $point is outside the card surface',
        );
      }
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
