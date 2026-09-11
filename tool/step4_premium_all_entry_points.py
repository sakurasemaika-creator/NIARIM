from pathlib import Path


def replace(path: str, old: str, new: str, count: int = 1) -> None:
    p = Path(path)
    text = p.read_text()
    actual = text.count(old)
    if actual != count:
        raise SystemExit(
            f"{path}: expected {count} matches, found {actual}: {old!r}"
        )
    p.write_text(text.replace(old, new))


replace(
    "lib/screens/settings/settings_screen.dart",
    "if (!context.read<PremiumService>().isPremium) {",
    "if (!context.read<PremiumService>().isFeatureAvailable(PremiumFeature.watermark)) {",
)
replace(
    "lib/screens/export/export_screen.dart",
    "if (!premiumService.isPremium) {",
    "if (!premiumService.isFeatureAvailable(PremiumFeature.unlimitedDuration)) {",
)
replace(
    "lib/screens/export/export_screen.dart",
    "!premiumService.isPremium &&",
    "!premiumService.isFeatureAvailable(PremiumFeature.endCardEdit) &&",
)
replace(
    "lib/services/premium_service.dart",
    "int get maxProjectDurationSeconds => isPremium ? 999999 : 90;",
    "int get maxProjectDurationSeconds =>\n      isFeatureAvailable(PremiumFeature.unlimitedDuration) ? 999999 : 90;",
)
replace(
    "lib/screens/timeline/timeline_screen.dart",
    "final isPremium = context.watch<PremiumService>().isPremium;",
    "final canUseWatermark = context\n        .watch<PremiumService>()\n        .isFeatureAvailable(PremiumFeature.watermark);",
)
replace(
    "lib/screens/timeline/timeline_screen.dart",
    "_buildWatermarkButton(isPremium),",
    "_buildWatermarkButton(canUseWatermark),",
)
replace(
    "lib/screens/timeline/timeline_screen.dart",
    "Widget _buildWatermarkButton(bool isPremium) {\n    final l10n = AppLocalizations.of(context)!;\n    if (isPremium) {",
    "Widget _buildWatermarkButton(bool canUseWatermark) {\n    final l10n = AppLocalizations.of(context)!;\n    if (canUseWatermark) {",
)
replace(
    "lib/screens/timeline/timeline_screen.dart",
    "final isPremium = context.read<PremiumService>().isPremium;\n    final ps = context.read<ProjectService>();\n    final maxSeconds = isPremium ? 7200 : 90;",
    "final hasUnlimitedDuration = context\n        .read<PremiumService>()\n        .isFeatureAvailable(PremiumFeature.unlimitedDuration);\n    final ps = context.read<ProjectService>();\n    final maxSeconds = hasUnlimitedDuration ? 7200 : 90;",
)
replace(
    "lib/screens/timeline/timeline_screen.dart",
    "isPremium\n              ? l10n.timelineDurationLimitBodyPremium",
    "hasUnlimitedDuration\n              ? l10n.timelineDurationLimitBodyPremium",
)
replace(
    "lib/screens/timeline/timeline_screen.dart",
    "final l10n = AppLocalizations.of(context)!;\n        final defaultHidden =\n            premium.isPremium && settings.endCardDefaultHiddenForPremium;",
    "final l10n = AppLocalizations.of(context)!;\n        final canEditEndCard = premium.isFeatureAvailable(\n          PremiumFeature.endCardEdit,\n        );\n        final defaultHidden =\n            canEditEndCard && settings.endCardDefaultHiddenForPremium;",
)
replace(
    "lib/screens/timeline/timeline_screen.dart",
    "onTap: premium.isPremium ? null : () => showPremiumBanner(context),",
    "onTap: canEditEndCard ? null : () => showPremiumBanner(context),",
)
replace(
    "lib/screens/timeline/timeline_screen.dart",
    "if (!premium.isPremium)\n                  Icon(",
    "if (!canEditEndCard)\n                  Icon(",
)

Path("test/premium_all_entry_points_test.dart").write_text(
r'''import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/home/widgets/home_drawer.dart';
import 'package:niarim/screens/settings/settings_screen.dart';
import 'package:niarim/services/premium_service.dart';
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
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1.0);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final dir = Directory(
    Platform.environment['STEP4_EVIDENCE_DIR'] ?? 'build/step4-premium/png',
  );
  await dir.create(recursive: true);
  await File('${dir.path}/$name.png').writeAsBytes(data!.buffer.asUint8List());
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
            builder: (context, state) => ChangeNotifierProvider<PremiumService>.value(
              value: premium,
              child: Scaffold(
                body: Center(
                  child: PremiumLockWidget(
                    feature: PremiumFeature.toneCurve,
                    child: FilledButton(
                      onPressed: () => fail('locked child action must not execute'),
                      child: const Text('LOCKED ACTION'),
                    ),
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/premium',
            builder: (context, state) => const Scaffold(
              body: Text('PREMIUM DESTINATION'),
            ),
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

  testWidgets('Home drawer Premium entry reaches /premium directly', (tester) async {
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
          builder: (context, state) => const Scaffold(
            body: Text('PREMIUM DESTINATION'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_routerApp(router, boundaryKey));
    await _pumpFrames(tester);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await _pumpFrames(tester, count: 12);
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
      addTearDown(premium.dispose);
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => ChangeNotifierProvider<PremiumService>.value(
              value: premium,
              child: const SettingsScreen(),
            ),
          ),
          GoRoute(
            path: '/premium',
            builder: (context, state) => const Scaffold(
              body: Text('PREMIUM DESTINATION'),
            ),
          ),
          GoRoute(
            path: '/settings/watermark',
            builder: (context, state) => const Scaffold(
              body: Text('WATERMARK SETTINGS'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(_routerApp(router, boundaryKey));
      await _pumpFrames(tester, count: 12);
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
'''
)
