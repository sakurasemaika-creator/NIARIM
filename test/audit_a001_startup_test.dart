import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/app_startup.dart';
import 'package:niarim/config/monetization_gate.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/models/scene.dart';
import 'package:niarim/services/advertising_service.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/utils/app_error_reporter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory documents;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() {
    documents = Directory.systemTemp.createTempSync('niarim_a001_');
    SharedPreferences.setMockInitialValues({});
    AppErrorReporter.recentErrors.clear();
    messenger.setMockMethodCallHandler(
      pathChannel,
      (_) async => documents.path,
    );
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(pathChannel, null);
    if (documents.existsSync()) documents.deleteSync(recursive: true);
  });

  Future<File> saveFixture(String id) async {
    final date = DateTime.utc(2026, 9, 10);
    return NiaproSerializer.save(
      project: Project(
        id: id,
        name: '保存済み $id',
        fps: 1,
        durationSeconds: 1,
        backgroundColor: 0xffffffff,
        createdAt: date,
        updatedAt: date,
        totalWorkSeconds: 0,
        exportWidth: 16,
        exportHeight: 16,
      ),
      scenes: [
        Scene(
          id: 'Scene0001',
          index: 0,
          frames: [Frame(index: 0, layers: [])],
        ),
      ],
      tileManager: TileManager(canvasWidth: 16, canvasHeight: 16),
    );
  }

  testWidgets('fresh and warm bootstrap preserve saved settings and artwork', (
    tester,
  ) async {
    AppServices? services;
    Future<void> mount() async {
      services = await tester.runAsync(buildAppServices);
      await tester.pumpWidget(
        MultiProvider(
          providers: services!.providers,
          child: Builder(
            builder: (context) {
              final premium = context.read<PremiumService>();
              final ads = context.read<AdvertisingService>();
              final auth = context.read<GoogleAuthService>();
              expect(premium.isLaunchCampaignActive, !isMonetizationEnabled);
              expect(ads.shouldShowAds, isFalse);
              expect(auth.isConfigured, isFalse);
              expect(auth.isInitialized, isTrue);
              expect(auth.isSignedIn, isFalse);
              return const SizedBox();
            },
          ),
        ),
      );
    }

    await mount();
    expect(services!.providers, hasLength(30));
    await tester.pumpWidget(const SizedBox());
    services!.dispose();
    final file = (await tester.runAsync(() => saveFixture('a001_saved')))!;
    final before = file.readAsBytesSync();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', 'fr');
    await prefs.setInt('undo_limit', 100);
    await prefs.setString('quality_level', 'custom');
    await prefs.setBool('custom_saved', true);
    await prefs.setString('custom_save_mode', 'slot');
    await prefs.setInt('custom_slot_count', 7);
    await mount();
    await tester.pumpWidget(
      MultiProvider(
        providers: services!.providers,
        child: Builder(
          builder: (context) {
            expect(context.read<SettingsService>().language, 'fr');
            expect(context.read<SettingsService>().undoLimit, 100);
            expect(context.read<SaveTreeService>().slotMax, 7);
            expect(
              context.read<ProjectService>().projects.single.id,
              'a001_saved',
            );
            return const SizedBox();
          },
        ),
      ),
    );
    expect(file.readAsBytesSync(), before);
    await tester.pumpWidget(const SizedBox());
    services!.dispose();
    expect(tester.takeException(), isNull);
  });

  for (final entry in {
    'custom_size_presets': <String>['{'],
    'theme_current_json': '{',
    'project_folders': '[{"id":"good","name":"保存"},{',
    'shared_folders': '{',
    'trashed_projects': <String>['saved|invalid-date'],
  }.entries) {
    test(
      'corrupt ${entry.key} fails visibly upstream without overwriting the saved value',
      () async {
        SharedPreferences.setMockInitialValues({entry.key: entry.value});
        final prefs = await SharedPreferences.getInstance();
        final before = jsonEncode(prefs.get(entry.key));
        await expectLater(buildAppServices(), throwsA(anything));
        expect(jsonEncode(prefs.get(entry.key)), before);
      },
    );
  }

  test(
    'startup dependency dispatch handles the newly introduced prism kind',
    () {
      final source = Uint8List.fromList(List.filled(24, 255));
      final result = applyDrawFilterInIsolate((
        source,
        6,
        1,
        const FilterDef(
          id: 'custom_prism',
          name: 'Prism',
          kind: FilterKind.prism,
          prismBlurPx: 0,
          prismDirectionDegrees: 0,
        ),
        null,
      ));
      expect(result.length, source.length);
      expect(result.sublist(0, 4), [77, 0, 0, 255]);
      expect(result, isNot(orderedEquals(source)));
    },
  );

  test(
    'invalid saved Undo bounds use a safe default without rewriting settings',
    () async {
      for (final value in [-1, 0, 9, 201, 0x7fffffff]) {
        SharedPreferences.setMockInitialValues({'undo_limit': value});
        final settings = SettingsService();
        await settings.init();
        expect(settings.undoLimit, 50);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt('undo_limit'), value);
        settings.dispose();
      }
    },
  );

  test(
    'project storage failure propagates and the same instance can retry',
    () async {
      final service = ProjectService();
      addTearDown(service.dispose);
      messenger.setMockMethodCallHandler(
        pathChannel,
        (_) async => throw PlatformException(code: 'unavailable'),
      );
      await expectLater(service.init(), throwsA(isA<PlatformException>()));
      messenger.setMockMethodCallHandler(
        pathChannel,
        (_) async => documents.path,
      );
      final file = await saveFixture('a001_retry');
      final before = file.readAsBytesSync();
      await Future.wait([service.init(), service.init()]);
      await service.init();
      expect(service.projects.map((p) => p.id), ['a001_retry']);
      expect(file.readAsBytesSync(), before);
    },
  );

  test('one corrupt project leaves the complete catalogue uncommitted and all files intact', () async {
    final good = await saveFixture('a001_good');
    final bad = await saveFixture('a001_bad');
    final goodBytes = good.readAsBytesSync();
    final badBytes = bad.readAsBytesSync();
    bad.writeAsStringSync('invalid archive');
    final service = ProjectService();
    addTearDown(service.dispose);
    await expectLater(service.init(), throwsA(anything));
    expect(service.projects, isEmpty);
    expect(good.readAsBytesSync(), goodBytes);
    expect(bad.readAsStringSync(), 'invalid archive');
    bad.writeAsBytesSync(badBytes);
    await service.init();
    expect(
      service.projects.map((p) => p.id),
      unorderedEquals(['a001_good', 'a001_bad']),
    );
  });

  testWidgets(
    'startup displays errors, serializes retry, and releases services once',
    (tester) async {
      final completer = Completer<AppServices>();
      var attempts = 0;
      var disposals = 0;
      await tester.pumpWidget(
        AppStartup(
          initialize: () async {
            attempts++;
            if (attempts == 1) throw const FormatException('saved preferences');
            return completer.future;
          },
          child: const SizedBox(key: Key('ready')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('startup-retry')), findsOneWidget);
      expect(
        AppErrorReporter.recentErrors.single,
        contains('saved preferences'),
      );
      final retry = tester
          .widget<FilledButton>(find.byKey(const Key('startup-retry')))
          .onPressed!;
      retry();
      retry();
      await tester.pump();
      expect(attempts, 2);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      completer.complete(
        AppServices([Provider.value(value: 1)], [() => disposals++]),
      );
      await tester.pump();
      expect(find.byKey(const Key('ready')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(disposals, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unmount during initialization disposes the late result', (
    tester,
  ) async {
    final completer = Completer<AppServices>();
    var disposals = 0;
    await tester.pumpWidget(
      AppStartup(initialize: () => completer.future, child: const SizedBox()),
    );
    await tester.pumpWidget(const SizedBox());
    completer.complete(AppServices([], [() => disposals++]));
    await tester.pump();
    expect(disposals, 1);
    expect(tester.takeException(), isNull);
  });
}
