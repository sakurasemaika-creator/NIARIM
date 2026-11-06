import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/community/community_screen.dart';
import 'package:niarim/services/community_preview_service.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}
