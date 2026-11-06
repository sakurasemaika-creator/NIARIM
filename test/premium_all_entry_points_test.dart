import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/home/widgets/home_drawer.dart';
import 'package:niarim/screens/settings/settings_screen.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/widgets/premium_lock_widget.dart';
import 'package:provider/provider.dart';

class _FreePremiumService extends PremiumService {
  @override
  bool get isPremium => false;

  @override
  bool get isLaunchCampaignActive => false;

  @override
  bool isFeatureAvailable(PremiumFeature feature) => false;
}

Future<void> _pumpFrames(WidgetTester tester, {int count = 8}) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  await tester.pump();
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final dir = Directory(
      Platform.environment['STEP4_EVIDENCE_DIR'] ?? 'build/step4-premium/png',
    );
    await dir.create(recursive: true);
    await File(
      '${dir.path}/$name.png',
    ).writeAsBytes(data!.buffer.asUint8List());
  });
}

Widget _routerApp(GoRouter router, GlobalKey boundaryKey) => RepaintBoundary(
  key: boundaryKey,
  child: MaterialApp.router(
    routerConfig: router,
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every PremiumFeature remains independently addressable', () {
    expect(PremiumFeature.values.toSet(), {
      PremiumFeature.endCardEdit,
      PremiumFeature.watermark,
      PremiumFeature.toneCurve,
      PremiumFeature.levelAdjustment,
      PremiumFeature.unlimitedDuration,
      PremiumFeature.customAutomation,
    });
  });

  testWidgets(
    'shared Premium lock blocks feature, opens upsell, and reaches /premium',
    (tester) async {
      final boundaryKey = GlobalKey();
      final premium = _FreePremiumService();
      addTearDown(premium.dispose);
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                ChangeNotifierProvider<PremiumService>.value(
                  value: premium,
                  child: Scaffold(
                    body: Center(
                      child: PremiumLockWidget(
                        feature: PremiumFeature.toneCurve,
                        child: FilledButton(
                          onPressed: () =>
                              fail('locked child action must not execute'),
                          child: const Text('LOCKED ACTION'),
                        ),
                      ),
                    ),
                  ),
                ),
          ),
          GoRoute(
            path: '/premium',
            builder: (context, state) =>
                const Scaffold(body: Text('PREMIUM DESTINATION')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(_routerApp(router, boundaryKey));
      await _pumpFrames(tester, count: 2);
      expect(find.byIcon(Icons.lock), findsOneWidget);
      await tester.tap(find.byIcon(Icons.lock));
      await _pumpFrames(tester);
      expect(find.byType(Dialog), findsOneWidget);
      await _capture(tester, boundaryKey, 'shared-lock-upsell');

      final register = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(FilledButton),
      );
      expect(register, findsOneWidget);
      await tester.tap(register);
      await _pumpFrames(tester);
      expect(find.text('PREMIUM DESTINATION'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Home drawer Premium entry reaches /premium directly', (
    tester,
  ) async {
    final boundaryKey = GlobalKey();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            appBar: AppBar(),
            drawer: const HomeDrawer(),
            body: const SizedBox.expand(),
          ),
        ),
        GoRoute(
          path: '/premium',
          builder: (context, state) =>
              const Scaffold(body: Text('PREMIUM DESTINATION')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_routerApp(router, boundaryKey));
    await _pumpFrames(tester);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await _pumpFrames(tester, count: 12);
    final drawerList = find.descendant(
      of: find.byType(Drawer),
      matching: find.byType(Scrollable),
    );
    expect(drawerList, findsOneWidget);
    await tester.scrollUntilVisible(
      find.byIcon(Icons.workspace_premium_outlined),
      240,
      scrollable: drawerList,
    );
    await _pumpFrames(tester, count: 2);
    expect(find.byIcon(Icons.workspace_premium_outlined), findsOneWidget);
    await _capture(tester, boundaryKey, 'home-drawer-premium-entry');
    await tester.tap(find.byIcon(Icons.workspace_premium_outlined));
    await _pumpFrames(tester, count: 12);
    expect(find.text('PREMIUM DESTINATION'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Settings watermark entry stays locked for a free user and opens upsell',
    (tester) async {
      final boundaryKey = GlobalKey();
      final premium = _FreePremiumService();
      final settings = SettingsService();
      addTearDown(premium.dispose);
      addTearDown(settings.dispose);
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => MultiProvider(
              providers: [
                ChangeNotifierProvider<PremiumService>.value(value: premium),
                ChangeNotifierProvider<SettingsService>.value(value: settings),
              ],
              child: const SettingsScreen(),
            ),
          ),
          GoRoute(
            path: '/premium',
            builder: (context, state) =>
                const Scaffold(body: Text('PREMIUM DESTINATION')),
          ),
          GoRoute(
            path: '/settings/watermark',
            builder: (context, state) =>
                const Scaffold(body: Text('WATERMARK SETTINGS')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(_routerApp(router, boundaryKey));
      await _pumpFrames(tester, count: 4);
      final settingsList = find.descendant(
        of: find.byType(SettingsScreen),
        matching: find.byType(Scrollable),
      );
      expect(settingsList, findsOneWidget);
      await tester.scrollUntilVisible(
        find.byIcon(Icons.lock_outline),
        260,
        scrollable: settingsList,
      );
      await _pumpFrames(tester, count: 2);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      await tester.tap(find.byIcon(Icons.lock_outline));
      await _pumpFrames(tester, count: 12);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('WATERMARK SETTINGS'), findsNothing);
      await _capture(tester, boundaryKey, 'settings-watermark-upsell');
      expect(tester.takeException(), isNull);
    },
  );
}
