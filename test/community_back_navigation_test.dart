import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/splash/splash_screen.dart';
import 'package:niarim/screens/community/community_screen.dart';
import 'package:niarim/services/community_preview_service.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  testWidgets('plaza leading arrow returns to launch route', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final community = CommunityService();
    addTearDown(community.dispose);
    final router = GoRouter(
      initialLocation: '/community',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              const Scaffold(body: Center(child: Text('launch-route-marker'))),
        ),
        GoRoute(path: '/community', builder: (_, _) => const CommunityScreen()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: community),
          ChangeNotifierProvider(create: (_) => SettingsService()),
          ChangeNotifierProvider(create: (_) => PremiumService()),
          ChangeNotifierProvider(create: (_) => GoogleAuthService()),
          ChangeNotifierProvider(create: (_) => CommunityPreviewService()),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final back = find.byKey(const Key('communityBackToSplashButton'));
    expect(back, findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(find.text('launch-route-marker'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'the splash create action works after returning from the community page',
    (tester) async {
      await loadAppFonts(tester);
      final tempDir = Directory.systemTemp.createTempSync(
        'niarim_community_back_',
      );
      const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            pathChannel,
            (call) async => tempDir.path,
          );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(pathChannel, null);
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      SharedPreferences.setMockInitialValues({
        'first_launch': false,
        'language': 'ja',
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      });
      appRouter.go('/');
      final providers = (await tester.runAsync(buildAppProviders))!;
      await tester.pumpWidget(
        MultiProvider(providers: providers, child: const NiarimApp()),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SplashScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('splashCommunityActionButton')));
      await tester.pumpAndSettle();
      expect(find.byType(CommunityScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('communityBackToSplashButton')));
      await tester.pumpAndSettle();
      expect(find.byType(SplashScreen), findsOneWidget);

      // The splash button's push future must have completed and released its
      // re-entry guard after the plaza returned to the launch screen.
      await tester.tap(find.byKey(const Key('splashCreateActionButton')));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      appRouter.go('/');
      await tester.pumpAndSettle();
    },
  );

}
