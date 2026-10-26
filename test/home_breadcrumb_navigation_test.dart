import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'folder breadcrumbs offer named 48px navigation in every locale',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await loadAppFonts(tester);
      const parentName = 'Archive / アーカイブ / Dossier';
      const childName = 'Nested / 子フォルダー';
      var conditions = 0;
      for (final locale in AppLocalizations.supportedLocales) {
        for (final pc in [false, true]) {
          SharedPreferences.setMockInitialValues({
            'first_launch': false,
            'language': locale.toString(),
            'force_pc_mode': pc ? 1 : 0,
            firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
          });
          final dir = Directory.systemTemp.createTempSync(
            'breadcrumb-navigation-',
          );
          const channel = MethodChannel('plugins.flutter.io/path_provider');
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, (_) async => dir.path);
          tester.view.physicalSize = pc
              ? const Size(1440, 900)
              : const Size(320, 844);
          appRouter.go('/home');
          final providers = await tester.runAsync(buildAppProviders);
          await tester.pumpWidget(
            MultiProvider(providers: providers!, child: const NiarimApp()),
          );
          await tester.pumpAndSettle();
          final service = tester
              .element(find.byType(HomeScreen))
              .read<ProjectService>();
          await tester.runAsync(() async {
            final parent = await service.createFolder(parentName);
            await service.createFolder(childName, parentFolderId: parent.id);
          });
          await tester.pumpAndSettle();
          await tester.tap(find.text(parentName));
          await tester.pumpAndSettle();
          await tester.tap(find.text(childName));
          await tester.pumpAndSettle();
          final home = find.byIcon(Icons.home);
          final target = find
              .ancestor(
                of: home,
                matching: find.byWidgetPredicate(
                  (w) => w is InkWell || w is IconButton,
                ),
              )
              .first;
          expect(
            tester.getSize(target).width,
            greaterThanOrEqualTo(48),
            reason: '$locale/$pc root width',
          );
          expect(
            tester.getSize(target).height,
            greaterThanOrEqualTo(48),
            reason: '$locale/$pc root height',
          );
          final l10n = AppLocalizations.of(
            tester.element(find.byType(HomeScreen)),
          )!;
          expect(
            Localizations.localeOf(tester.element(find.byType(HomeScreen))),
            locale,
          );
          expect(
            find.byTooltip(l10n.projectListFolderRootOption),
            findsOneWidget,
          );
          final parentButton = find.ancestor(
            of: find.text(parentName),
            matching: find.byType(TextButton),
          );
          expect(parentButton, findsOneWidget);
          expect(tester.getSize(parentButton).height, greaterThanOrEqualTo(48));
          expect(tester.getSize(parentButton).width, greaterThanOrEqualTo(48));
          await tester.ensureVisible(parentButton);
          await tester.tap(parentButton);
          await tester.pumpAndSettle();
          expect(
            find.ancestor(
              of: find.text(childName),
              matching: find.byType(Card),
            ),
            findsOneWidget,
          );
          await tester.ensureVisible(
            find.byTooltip(l10n.projectListFolderRootOption),
          );
          await tester.tap(find.byTooltip(l10n.projectListFolderRootOption));
          await tester.pumpAndSettle();
          expect(find.byIcon(Icons.home), findsNothing);
          expect(
            find.ancestor(
              of: find.text(parentName),
              matching: find.byType(Card),
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          conditions++;
          await tester.pumpWidget(const SizedBox.shrink());
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
          dir.deleteSync(recursive: true);
        }
      }
      debugPrint('Breadcrumb navigation: $conditions locale/device conditions');
    },
  );
}
