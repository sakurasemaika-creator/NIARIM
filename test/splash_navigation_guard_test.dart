import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/splash/splash_screen.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');

  testWidgets(
    'splash destinations remain usable after a pushed route is replaced with go("/")',
    (tester) async {
      final temp = Directory.systemTemp.createTempSync('niarim-splash-route-');
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(pathChannel, null);
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, (call) async => temp.path);

      final providers = (await tester.runAsync(buildAppProviders))!;
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
          GoRoute(
            path: '/home',
            builder: (context, _) => Scaffold(
              body: TextButton(
                key: const ValueKey('return-from-home'),
                onPressed: () => context.go('/'),
                child: const Text('Return to splash'),
              ),
            ),
          ),
          GoRoute(
            path: '/community',
            builder: (context, _) => Scaffold(
              body: TextButton(
                key: const ValueKey('return-from-community'),
                onPressed: () => context.go('/'),
                child: const Text('Return to splash'),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: providers,
          child: Builder(
            builder: (context) => MaterialApp.router(
              theme: context.watch<ThemeService>().themeData,
              routerConfig: router,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('splashCreateActionButton')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('return-from-home')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('return-from-home')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('splashCommunityActionButton')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('splashCommunityActionButton')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('return-from-community')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('return-from-community')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('splashCreateActionButton')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('return-from-home')), findsOneWidget);
    },
  );
}
