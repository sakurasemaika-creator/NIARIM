import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/community/community_work_detail_screen.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('community work detail resize affordance: real Flutter captures', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await loadAppFonts(tester);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final output = Directory('build/community-work-detail-captures')
      ..createSync(recursive: true);

    final cases = [
      (
        locale: const Locale('ja'),
        size: const Size(390, 844),
        scale: 1.0,
        name: 'ja-mobile-default',
      ),
      (
        locale: const Locale('fr'),
        size: const Size(390, 844),
        scale: 2.0,
        name: 'fr-mobile-text-2x',
      ),
      (
        locale: const Locale('zh'),
        size: const Size(320, 844),
        scale: 1.3,
        name: 'zh-narrow-mobile-text-1-3x',
      ),
      (
        locale: const Locale('ja'),
        size: const Size(1280, 900),
        scale: 1.0,
        name: 'ja-desktop',
      ),
    ];

    for (final item in cases) {
      tester.view.physicalSize = item.size;
      final community = CommunityService();
      final work = community.works.first;
      final root = GlobalKey();

      await tester.pumpWidget(
        RepaintBoundary(
          key: root,
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider<CommunityService>.value(value: community),
              ChangeNotifierProvider(create: (_) => SettingsService()),
              ChangeNotifierProvider(create: (_) => GoogleAuthService()),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: item.locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: ThemeService().themeDataFor(item.locale),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(item.scale),
                ),
                child: child!,
              ),
              home: CommunityWorkDetailScreen(workId: work.id),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(item.locale);
      final handle = find.byKey(
        const Key('communityWorkDetailPreviewResizeHandle'),
      );
      expect(handle, findsOneWidget, reason: item.name);
      final target = tester.getSize(handle);
      expect(target.width, greaterThanOrEqualTo(48), reason: item.name);
      expect(target.height, greaterThanOrEqualTo(48), reason: item.name);
      expect(
        find.byTooltip(l10n.communityFloatingPreviewResizeTooltip),
        findsOneWidget,
        reason: item.name,
      );
      expect(handle.hitTestable(), findsOneWidget, reason: item.name);
      expect(tester.takeException(), isNull, reason: item.name);

      await tester.runAsync(() async {
        final render =
            root.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 1);
        try {
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('${output.path}/${item.name}.png')
              .writeAsBytes(data!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      });

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      community.dispose();
    }
  });
}
