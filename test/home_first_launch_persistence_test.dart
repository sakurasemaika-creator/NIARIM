import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

class _FirstLaunchStore extends SharedPreferencesStorePlatform {
  _FirstLaunchStore(this.delegate);
  final SharedPreferencesStorePlatform delegate;
  String mode = 'off';
  int attempts = 0;
  Completer<bool>? pending;

  @override
  Future<bool> setValue(String type, String key, Object value) {
    if (key != 'flutter.first_launch' || value != false) {
      return delegate.setValue(type, key, value);
    }
    attempts++;
    return switch (mode) {
      'reject' => Future.value(false),
      'throw' => Future.error(StateError('Audit first-launch write rejected')),
      'pending' => (pending ??= Completer<bool>()).future,
      _ => delegate.setValue(type, key, value),
    };
  }

  @override
  Future<Map<String, Object>> getAll() => delegate.getAll();
  @override
  Future<bool> remove(String key) => delegate.remove(key);
  @override
  Future<bool> clear() => delegate.clear();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<
    ({SettingsService settings, AppLocalizations l10n, _FirstLaunchStore store})
  >
  open(
    WidgetTester tester, {
    String language = 'en',
    bool pc = false,
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': true,
      'language': language,
      'force_pc_mode': pc ? 1 : 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final delegate = SharedPreferencesStorePlatform.instance;
    final store = _FirstLaunchStore(delegate);
    SharedPreferencesStorePlatform.instance = store;
    final dir = Directory.systemTemp.createTempSync('first-launch-save-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => dir.path);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(() {
      SharedPreferencesStorePlatform.instance = delegate;
      messenger.setMockMethodCallHandler(channel, null);
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      dir.deleteSync(recursive: true);
    });
    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pumpAndSettle();
    final home = tester.element(find.byType(HomeScreen));
    return (
      settings: home.read<SettingsService>(),
      l10n: AppLocalizations.of(home)!,
      store: store,
    );
  }

  testWidgets('first-use acknowledgement survives outside clicks and Back', (
    tester,
  ) async {
    final c = await open(tester);
    expect(find.text(c.l10n.homeFirstLaunchMessage), findsOneWidget);
    await tester.tapAt(const Offset(2, 2));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(c.l10n.homeFirstLaunchMessage), findsOneWidget);
    expect(c.settings.isFirstLaunch, isTrue);
    expect(c.store.attempts, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final mode in ['reject', 'throw']) {
    testWidgets('first-use acknowledgement can retry a $mode save', (
      tester,
    ) async {
      final c = await open(tester);
      c.store.mode = mode;
      await tester.tap(
        find.widgetWithText(FilledButton, c.l10n.homeFirstLaunchStart),
      );
      await tester.pumpAndSettle();
      expect(find.text(c.l10n.homeFirstLaunchMessage), findsOneWidget);
      expect(c.settings.isFirstLaunch, isTrue);
      expect(find.text(c.l10n.communityErrorGeneric), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      expect(prefs.getBool('first_launch'), isTrue);
      expect(c.store.attempts, 1);
      c.store.mode = 'off';
      await tester.tap(
        find.widgetWithText(FilledButton, c.l10n.homeFirstLaunchStart),
      );
      await tester.pumpAndSettle();
      expect(find.text(c.l10n.homeFirstLaunchMessage), findsNothing);
      expect(c.settings.isFirstLaunch, isFalse);
      await prefs.reload();
      expect(prefs.getBool('first_launch'), isFalse);
      expect(c.store.attempts, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'first-use acknowledgement waits for storage and prevents double activation',
    (tester) async {
      final c = await open(tester);
      c.store.mode = 'pending';
      final start = find.widgetWithText(
        FilledButton,
        c.l10n.homeFirstLaunchStart,
      );
      await tester.tap(start);
      await tester.pump();
      await tester.tap(start);
      await tester.pump();
      expect(c.store.attempts, 1);
      expect(c.settings.isFirstLaunch, isTrue);
      expect(find.text(c.l10n.homeFirstLaunchMessage), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text(c.l10n.homeFirstLaunchMessage), findsOneWidget);
      c.store.pending!.complete(false);
      await tester.pumpAndSettle();
      expect(find.text(c.l10n.communityErrorGeneric), findsOneWidget);
      expect(c.settings.isFirstLaunch, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('save failure remains readable and retryable in every locale', (
    tester,
  ) async {
    await loadAppFonts(tester);
    for (final language in ['ja', 'en', 'zh', 'zh_Hant', 'ko', 'fr', 'es']) {
      for (final (pc, size, scale) in [
        (false, const Size(320, 844), 2.0),
        (false, const Size(640, 360), 2.0),
        (true, const Size(641, 360), 1.0),
        (true, const Size(1440, 900), 2.0),
      ]) {
        final c = await open(
          tester,
          language: language,
          pc: pc,
          size: size,
          scale: scale,
        );
        c.store.mode = 'reject';
        final start = find.widgetWithText(
          FilledButton,
          c.l10n.homeFirstLaunchStart,
        );
        await tester.ensureVisible(start);
        await tester.tap(start);
        await tester.pumpAndSettle();
        final error = find.text(c.l10n.communityErrorGeneric);
        await tester.ensureVisible(error);
        await tester.pumpAndSettle();
        expect(
          tester.renderObject<RenderParagraph>(error).didExceedMaxLines,
          isFalse,
          reason: '$language $pc $size $scale',
        );
        final bounds = tester.getRect(error);
        expect(bounds.left, greaterThanOrEqualTo(0));
        expect(bounds.right, lessThanOrEqualTo(size.width));
        expect(bounds.top, greaterThanOrEqualTo(0));
        expect(bounds.bottom, lessThanOrEqualTo(size.height));
        expect(
          find.ancestor(
            of: error,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics && widget.properties.liveRegion == true,
            ),
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<Text>(error).style!.color,
          Theme.of(tester.element(error)).colorScheme.error,
        );
        await tester.ensureVisible(start);
        expect(tester.getSize(start).height, greaterThanOrEqualTo(48));
        c.store.mode = 'off';
        await tester.tap(start);
        await tester.pumpAndSettle();
        expect(find.text(c.l10n.homeFirstLaunchMessage), findsNothing);
        expect(c.settings.isFirstLaunch, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });
}
