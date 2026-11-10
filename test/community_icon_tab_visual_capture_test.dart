import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/community/community_screen.dart';
import 'package:niarim/screens/community/widgets/community_work_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';
import 'helpers/first_use_tooltips.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('five plaza icon tabs fit and capture actual Flutter rendering at device widths', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final temp = Directory.systemTemp.createTempSync('niarim_plaza_icons_');
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => temp.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null);
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });
    await loadAppFonts(tester);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final output = Directory('build/community-five-icon-captures')
      ..createSync(recursive: true);

    for (final width in <int>[
      320, 360, 375, 390, 430, 480, 640, 720, 1024, 1440,
    ]) {
      final pc = width >= 720;
      await tester.pumpWidget(const SizedBox.shrink());
      SharedPreferences.setMockInitialValues({
        'first_launch': false,
        'language': 'ja',
        'force_pc_mode': pc ? 1 : 0,
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      });
      tester.view.physicalSize = Size(width.toDouble(), pc ? 900 : 844);
      final boundary = GlobalKey();
      appRouter.go('/community');
      final providers = await tester.runAsync(buildAppProviders);
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MultiProvider(
            providers: providers!,
            child: const NiarimApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> capture(String suffix) async {
        expect(tester.takeException(), isNull, reason: '$width $suffix');
        final render =
            boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final bytes = await tester.runAsync(() async {
          final picture = await render.toImage(pixelRatio: 1);
          final data = await picture.toByteData(format: ui.ImageByteFormat.png);
          picture.dispose();
          return data!.buffer.asUint8List();
        });
        await tester.runAsync(
          () => File(output.path + '/' + width.toString() + 'dp-' + suffix + '.png').writeAsBytes(bytes!),
        );
      }

      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabBar.tabs.length, 5, reason: '$width tabs count');
      expect(tabBar.isScrollable, isTrue);
      final tabArea = tester.getRect(find.byType(TabBar));
      for (var index = 0; index < 5; index++) {
        final rect = tester.getRect(find.byKey(Key('communityTabWidth$index')));
        expect(rect.width, closeTo(tabArea.width / 5, 0.6),
            reason: '$width tab $index width');
        expect(rect.left, greaterThanOrEqualTo(tabArea.left - 0.5));
        expect(rect.right, lessThanOrEqualTo(tabArea.right + 0.5));
        expect(rect.height, greaterThanOrEqualTo(48));
        expect(
          find.descendant(
            of: find.byKey(Key('communityTab$index')),
            matching: find.byType(Icon),
          ),
          findsOneWidget,
        );
        final tabLabel = find.descendant(
          of: find.byKey(Key('communityTabWidth$index')),
          matching: find.byType(Text),
        );
        if (width <= 480) {
          expect(tabLabel, findsNothing,
              reason: '$width dp shows compact icon-only tabs');
        } else if (width >= 1024) {
          expect(tabLabel, findsOneWidget,
              reason: '$width dp shows icon-and-name tabs');
        }
        final firstHasLabel = find.descendant(
          of: find.byKey(const Key('communityTabWidth0')),
          matching: find.byType(Text),
        ).evaluate().isNotEmpty;
        expect(tabLabel.evaluate().isNotEmpty, firstHasLabel,
            reason: 'all five tabs must switch display modes together');
      }
      expect(find.byKey(const Key('communityTab4')), findsOneWidget);
      final visibleCard = find.byType(CommunityWorkCard).first;
      final workId = tester.widget<CommunityWorkCard>(visibleCard).work.id;
      final title = tester.widget<CommunityWorkCard>(visibleCard).work.title;
      final titleRect = tester.getRect(
        find.descendant(of: visibleCard, matching: find.text(title)),
      );
      final authorRect = tester.getRect(
        find.byKey(ValueKey('community-author-$workId')),
      );
      final countRect = tester.getRect(
        find.byKey(ValueKey('community-bookmark-count-$workId')),
      );
      final saveRect = tester.getRect(
        find.byKey(ValueKey('community-bookmark-$workId')),
      );
      final menuRect = tester.getRect(
        find.byKey(ValueKey('communityMuteMenu-$workId')),
      );
      expect(titleRect.bottom, lessThanOrEqualTo(authorRect.top + 1),
          reason: '$width title / author order');
      expect(authorRect.bottom, lessThanOrEqualTo(countRect.top + 1),
          reason: '$width author / action row order');
      expect(countRect.right, lessThanOrEqualTo(saveRect.left + 1),
          reason: '$width count must precede bookmark button');
      expect(saveRect.right, lessThanOrEqualTo(menuRect.left + 1),
          reason: '$width bookmark button must precede menu');
      expect((saveRect.center.dy - menuRect.center.dy).abs(), lessThan(3),
          reason: '$width bookmark and menu must share a horizontal row');
      expect(tester.getSize(find.byKey(ValueKey('community-bookmark-$workId'))),
          const Size(48, 48));
      expect(tester.takeException(), isNull);
      await capture('new-arrivals');
      await tester.tap(find.byKey(const Key('communityTab4')));
      await tester.pumpAndSettle();
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 4);
      await capture('bookmarks');
      await tester.longPress(find.byKey(const Key('communityTab1')));
      await tester.pump(const Duration(milliseconds: 250));
      final l10n = AppLocalizations.of(tester.element(find.byType(CommunityScreen)))!;
      expect(find.text(l10n.communityTabRanking), findsWidgets,
          reason: '$width long press keeps the localized ranking name discoverable');
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 4);
      await capture('ranking-tooltip');
      await tester.pumpWidget(const SizedBox.shrink());
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}
