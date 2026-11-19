import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/canvas_dock_panel.dart';
import 'package:niarim/screens/settings/bucket_fill_settings_screen.dart';
import 'package:niarim/screens/settings/pc_workspace_layout_settings_screen.dart';
import 'package:niarim/screens/settings/settings_screen.dart';
import 'package:niarim/screens/settings/workspace_settings_screen.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/quick_tool_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/workspace_preset_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SettingsService settings;
  late AppLocalizations ja;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsService();
    ja = lookupAppLocalizations(const Locale('ja'));
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    Locale? locale,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider(create: (_) => PremiumService()),
          ChangeNotifierProvider(create: (_) => QuickToolService()),
          ChangeNotifierProvider(create: (_) => WorkspacePresetService()),
        ],
        child: Consumer<SettingsService>(
          builder: (context, settings, _) => MaterialApp(
            locale: locale ?? Locale(settings.language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: screen,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('basic settings relocalizes without closing the sheet', (
    tester,
  ) async {
    await pumpScreen(tester, const SettingsScreen());
    expect(find.text('FPS・言語・描画領域'), findsOneWidget);
    await tap(tester, find.text(ja.settingsBasicTitle));
    expect(find.text(ja.settingsBasicSheetTitle), findsOneWidget);
    await tap(tester, find.text(ja.settingsLanguage));
    await tap(tester, find.text('English'));
    final en = lookupAppLocalizations(const Locale('en'));
    expect(find.text(en.settingsBasicSheetTitle), findsOneWidget);
    expect(find.text(en.settingsDefaultFps), findsOneWidget);
    expect(find.text(en.settingsDrawingAreaTitle), findsOneWidget);
    expect(find.text(ja.settingsBasicSheetTitle), findsNothing);
    expect((await SharedPreferences.getInstance()).getString('language'), 'en');
  });

  testWidgets('the account deletion entry opens the localized page', (
    tester,
  ) async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    final urls = <Uri>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'launch');
      urls.add(Uri.parse(call.arguments['url'] as String));
      return urls.length == 1;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await pumpScreen(tester, const SettingsScreen());
    final entry = find.text(ja.settingsAccountDeletionTitle);
    await tap(tester, find.byTooltip(ja.commonSearch));
    await tester.enterText(find.byType(TextField), '退会');
    await tester.pumpAndSettle();

    await tap(tester, entry);
    expect(urls.single.scheme, 'https');
    expect(urls.single.host, 'niarim.miranima-studio.com');
    expect(urls.single.path, '/account-deletion/');
    expect(urls.single.queryParameters, {'lang': 'ja'});

    await tap(tester, entry);
    expect(urls, hasLength(2));
    expect(find.text(ja.settingsAccountDeletionLinkFailed), findsOneWidget);
  });

  testWidgets('the deletion page distinguishes the two Chinese locales', (
    tester,
  ) async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    final languageTags = <String?>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      final uri = Uri.parse(call.arguments['url'] as String);
      languageTags.add(uri.queryParameters['lang']);
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    for (final locale in const [
      Locale('zh'),
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    ]) {
      final l10n = lookupAppLocalizations(locale);
      await pumpScreen(
        tester,
        SettingsScreen(key: ValueKey(locale)),
        locale: locale,
      );
      await tap(tester, find.byTooltip(l10n.commonSearch));
      await tester.enterText(find.byType(TextField), 'delete account');
      await tester.pumpAndSettle();
      await tap(tester, find.text(l10n.settingsAccountDeletionTitle));
    }
    expect(languageTags, ['zh-Hans', 'zh-Hant']);
  });

  testWidgets('bucket values expose the scale and pixel unit', (tester) async {
    await settings.setBucketTolerance(30);
    await settings.setBucketExpandPx(0);
    await pumpScreen(tester, const BucketFillSettingsScreen());
    expect(find.text('色の許容誤差'), findsOneWidget);
    expect(find.text('30 / 100'), findsOneWidget);
    await tap(tester, find.text('0px'));
    final field = find.byType(TextField);
    expect(tester.widget<TextField>(field).decoration?.suffixText, 'px');
    await tester.enterText(field, '4');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(settings.bucketExpandPx, 4);
    expect(find.text('4px'), findsOneWidget);
  });

  testWidgets('workspace save, rename and load require the intended actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpScreen(tester, const WorkspaceSettingsScreen());
    final save = find.text(ja.workspaceSaveAsButton);
    final load = find.text(ja.workspaceLoadButton);
    final field = find.byType(TextField);
    final dialog = find.byType(AlertDialog);
    await tester.scrollUntilVisible(
      save,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    final presets = tester.element(save).read<WorkspacePresetService>();
    await tap(tester, save);
    final overwrite = find.widgetWithText(
      TextButton,
      ja.workspaceOverwriteButton,
    );
    expect(tester.widget<TextButton>(overwrite).onPressed, isNull);
    await tester.enterText(field, '  ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(presets.presets, isEmpty);
    expect(find.text(ja.workspaceNameRequiredError), findsOneWidget);

    await tester.enterText(field, ' Left layout ');
    await settings.setLeftHanded(true);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(presets.presets.single.name, 'Left layout');
    expect(dialog, findsNothing);

    await settings.setLeftHanded(false);
    await tester.pumpAndSettle();
    await tester.ensureVisible(save);
    await tap(tester, save);
    await tester.enterText(field, 'Left layout');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text(ja.workspaceOverwriteConfirmTitle), findsOneWidget);
    expect(presets.presets.single.isLeftHanded, isTrue);
    await tap(tester, find.widgetWithText(TextButton, ja.commonCancel).last);
    await tap(tester, find.widgetWithText(TextButton, ja.commonCancel));
    await tester.ensureVisible(load);
    await tap(tester, load);
    await tap(tester, find.byTooltip(ja.commonRename));
    await tester.enterText(field, ' Renamed layout ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Renamed layout'), findsOneWidget);

    await tap(tester, find.text('Renamed layout'));
    expect(settings.isLeftHanded, isFalse);
    await tap(tester, find.widgetWithText(TextButton, ja.commonCancel));
    expect(settings.isLeftHanded, isFalse);

    await tap(tester, find.text('Renamed layout'));
    await tap(
      tester,
      find.widgetWithText(TextButton, ja.workspaceSaveDialogTitle),
    );
    expect(find.text(ja.workspaceSaveDialogTitle), findsOneWidget);
    expect(settings.isLeftHanded, isFalse);
    await tap(tester, find.widgetWithText(TextButton, ja.commonCancel));
    await tap(tester, load);
    await tap(tester, find.text('Renamed layout'));
    await tap(
      tester,
      find.widgetWithText(FilledButton, ja.workspaceLoadButton),
    );
    expect(settings.isLeftHanded, isTrue);
    expect(dialog, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PC layout reset actions leave settings alone until confirmed', (
    tester,
  ) async {
    await settings.setDesktopPanelWidth(326);
    await settings.setDesktopDockHeight(CanvasDockPanel.layer, 340);
    await settings.setToolOptionDockOrder([CanvasDockPanel.ruler]);
    await pumpScreen(tester, const PcWorkspaceLayoutSettingsScreen());
    final cancel = find.widgetWithText(TextButton, ja.commonCancel);
    final ok = find.widgetWithText(FilledButton, ja.commonOk);
    final order = find.text(ja.pcWorkspaceLayoutResetOrderButton);
    final size = find.text(ja.pcWorkspaceLayoutResetWidthButton);
    final all = find.byKey(const Key('resetDesktopWorkspaceLayout'));

    for (final action in [order, size, all]) {
      await tap(tester, action);
      expect(settings.desktopPanelWidth, 326);
      expect(settings.desktopDockHeight(CanvasDockPanel.layer), 340);
      expect(settings.toolOptionDockOrder, [CanvasDockPanel.ruler]);
      await tap(tester, cancel);
    }

    await tap(tester, order);
    await tap(tester, ok);
    expect(settings.toolOptionDockOrder, isNot([CanvasDockPanel.ruler]));
    expect(settings.desktopPanelWidth, 326);
    await tap(tester, size);
    await tap(tester, ok);
    expect(settings.desktopPanelWidth, 280);
    expect(settings.desktopDockHeight(CanvasDockPanel.layer), 260);
    await settings.setDesktopPanelWidth(342);
    await tap(tester, all);
    await tap(tester, ok);
    expect(settings.desktopPanelWidth, 280);
    expect(tester.takeException(), isNull);
  });
}
