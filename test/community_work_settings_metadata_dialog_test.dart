import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/community_work.dart';
import 'package:niarim/screens/community/community_my_works_screen.dart';
import 'package:niarim/services/community_preview_service.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The title and description fields of a posted work's edit dialog had their
/// controllers disposed as soon as the dialog's Future completed, while the
/// dialog was still closing and its text fields still used them: the
/// keyboard closing with it rebuilt the fields and Flutter's debug check
/// failed with "A TextEditingController was used after being disposed"
/// (found by walking the app against a local copy of the backend,
/// 2026-11-28). The controllers now live until the dialog is gone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final action in ['save', 'cancel']) {
    testWidgets('closing the edit dialog with $action while the keyboard '
        'goes away keeps its fields usable to the end', (tester) async {
      tester.view.physicalSize = const Size(800, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      SharedPreferences.setMockInitialValues({});
      final service = CommunityService();
      final auth = GoogleAuthService();
      await auth.init();
      addTearDown(service.dispose);
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: service),
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider(create: (_) => CommunityPreviewService()),
            ChangeNotifierProvider(create: (_) => SettingsService()),
            ChangeNotifierProvider(create: (_) => PremiumService()),
          ],
          child: MaterialApp(
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const CommunityMyWorksScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final work = service
          .worksByAuthor(kDummySelfAuthorId, includeHidden: true)
          .first;
      await tester.tap(
        find.byKey(ValueKey('communityMyWorksSettings-${work.id}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('communityWorkSettingsEditMetadata')),
      );
      // The screen shows it is busy while the dialog is open.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final title = find.byKey(const Key('communityWorkSettingsTitleInput'));
      await tester.enterText(title, '新しい題');
      // The software keyboard is up while typing.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();

      await tester.tap(
        action == 'save'
            ? find.byKey(const Key('communityWorkSettingsMetadataSave'))
            : find.text('キャンセル'),
      );
      // The dialog closes and the keyboard slides away with it: every
      // frame of the closing animation lays the dialog out again.
      for (var bottom = 250.0; bottom >= 0; bottom -= 50) {
        tester.view.viewInsets = FakeViewPadding(bottom: bottom);
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull);
      }
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(title, findsNothing);
      expect(tester.takeException(), isNull);
      if (action == 'save') {
        expect(service.byId(work.id)!.title, '新しい題');
      } else {
        expect(service.byId(work.id)!.title, work.title);
      }
    });
  }
}
