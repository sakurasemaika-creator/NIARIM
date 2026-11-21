import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/community/community_post_screen.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'community post submit stays reachable across locales and sizes',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await loadAppFonts(tester);
      final theme = ThemeService();
      await theme.init();
      addTearDown(theme.dispose);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.devicePixelRatio = 1;

      final output = Directory('build/community-post-captures')
        ..createSync(recursive: true);
      final cases = <({Locale locale, Size size, double scale, String name})>[];
      for (final locale in AppLocalizations.supportedLocales) {
        for (final width in [320.0, 390.0, 600.0, 1280.0]) {
          for (final scale in [1.0, 2.0]) {
            cases.add((
              locale: locale,
              size: Size(width, width >= 760 ? 900 : 640),
              scale: scale,
              name: '${locale.languageCode}-${width.toInt()}-${scale}x',
            ));
          }
        }
      }

      for (final item in cases) {
        tester.view.physicalSize = item.size;
        final root = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: root,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: item.locale,
              theme: theme.themeDataFor(item.locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(item.scale)),
                child: child!,
              ),
              home: const CommunityPostScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpAndSettle();

        final submit = find.byKey(const Key('communityPostSubmitButton'));
        expect(submit, findsOneWidget, reason: item.name);
        expect(submit.hitTestable(), findsOneWidget, reason: item.name);
        final initialRect = tester.getRect(submit);
        expect(initialRect.left, greaterThanOrEqualTo(0), reason: item.name);
        expect(
          initialRect.right,
          lessThanOrEqualTo(item.size.width),
          reason: item.name,
        );
        expect(initialRect.top, greaterThanOrEqualTo(0), reason: item.name);
        expect(
          initialRect.bottom,
          lessThanOrEqualTo(item.size.height),
          reason: item.name,
        );
        expect(initialRect.height, greaterThanOrEqualTo(52), reason: item.name);
        expect(tester.takeException(), isNull, reason: item.name);

        if (item.name == 'ja-390-1.0x' ||
            item.name == 'fr-320-2.0x' ||
            item.name == 'zh-1280-1.0x') {
          final boundary =
              root.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            try {
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                '${output.path}/${item.name}.png',
              ).writeAsBytes(data!.buffer.asUint8List());
            } finally {
              image.dispose();
            }
          });
        }

        final scrollable = find.byType(Scrollable).first;
        await tester.drag(scrollable, const Offset(0, -5000));
        await tester.pumpAndSettle();
        expect(
          submit.hitTestable(),
          findsOneWidget,
          reason: '${item.name}/scrolled',
        );
        expect(
          tester.getRect(submit),
          initialRect,
          reason: '${item.name}/fixed',
        );
        expect(tester.takeException(), isNull, reason: '${item.name}/scrolled');

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    },
  );
}
