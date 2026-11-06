import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/utils/app_error_reporter.dart';
import 'package:niarim/widgets/project_trash_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

class _Store extends InMemorySharedPreferencesStore {
  _Store()
    : super.withData({
        'flutter.first_launch': false,
        'flutter.language': 'en',
        'flutter.force_pc_mode': 1,
        'flutter.is_premium': true,
        'flutter.$firstUseTooltipsSeenKey': kAllFirstUseTooltipKeys,
      });

  Completer<void>? gate;
  Completer<void>? started;

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key == 'flutter.trashed_projects' && gate != null) {
      final wait = gate!;
      gate = null;
      started?.complete();
      await wait.future;
    }
    return super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late ProjectService service;
  var serviceDisposed = false;
  late SharedPreferencesStorePlatform previous;
  late _Store store;
  const channel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    serviceDisposed = false;
    SharedPreferences.resetStatic();
    previous = SharedPreferencesStorePlatform.instance;
    store = _Store();
    SharedPreferencesStorePlatform.instance = store;
    directory = Directory.systemTemp.createTempSync('favorite-delete-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
    service = ProjectService();
    await service.init();
  });
  tearDown(() {
    if (!serviceDisposed) service.dispose();
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = previous;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    directory.deleteSync(recursive: true);
  });

  Future<Project> create(String name) => service.createProject(
    name: name,
    fps: 1,
    durationSeconds: 1,
    backgroundColor: 0xFF123456,
    exportWidth: 64,
    exportHeight: 64,
  );
  Future<File> archive(String id) async =>
      File('${await NiaproSerializer.projectsBasePath()}/$id/$id.niapro');
  Future<void> favorite(String id) async {
    await service.toggleFavorite(id);
    await service.saveProject(id);
  }

  Future<ProjectService> cold() async {
    SharedPreferences.resetStatic();
    final next = ProjectService();
    await next.init();
    addTearDown(next.dispose);
    return next;
  }

  for (final initiallyFavorite in [false, true]) {
    test(
      'favorite file write denial retains ${initiallyFavorite ? 'on' : 'off'} and retries to cold state',
      () async {
        final project = await create('WRITE DENIED');
        if (initiallyFavorite) await favorite(project.id);
        final file = await archive(project.id);
        final bytes = file.readAsBytesSync();
        final originalMode = (file.parent.statSync().mode & 0x1ff)
            .toRadixString(8);
        Object? caught;
        late bool inMemory;
        AppErrorReporter.recentErrors.clear();
        final restricted = await Process.run('chmod', [
          '0555',
          file.parent.path,
        ]);
        expect(restricted.exitCode, 0);
        try {
          expect(
            () => File(
              '${file.parent.path}/.owned-write-probe',
            ).writeAsStringSync('probe'),
            throwsA(isA<FileSystemException>()),
            reason:
                'The controlled POSIX write denial must be real before testing the operation.',
          );
          try {
            await service.toggleFavorite(project.id);
          } catch (error) {
            caught = error;
          }
          inMemory = service.projects.single.isFavorite;
          expect(file.readAsBytesSync(), bytes);
        } finally {
          final restored = await Process.run('chmod', [
            originalMode,
            file.parent.path,
          ]);
          expect(restored.exitCode, 0);
        }
        final loaded = await cold();
        debugPrint(
          'FAVORITE WRITE DENIAL old=$initiallyFavorite error=${caught.runtimeType} '
          'memory=$inMemory cold=${loaded.projects.single.isFavorite} '
          'reportedFs=${AppErrorReporter.recentErrors.any((e) => e.contains('Permission denied') && e.contains(file.parent.path))}',
        );
        expect(caught, isA<FileSystemException>());
        expect(inMemory, initiallyFavorite);
        expect(loaded.projects.single.isFavorite, initiallyFavorite);
        await service.toggleFavorite(project.id);
        final retry = await cold();
        expect(retry.projects.single.isFavorite, !initiallyFavorite);
      },
      skip: Platform.isWindows,
    );
  }

  ({Future<void> started, Completer<void> release, List<MethodCall> calls})
  holdNextSave() {
    final started = Completer<void>();
    final release = Completer<void>();
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (!started.isCompleted) {
            started.complete();
            await release.future;
          }
          return directory.path;
        });
    return (started: started.future, release: release, calls: calls);
  }

  test(
    'favorite completion preserves concurrent name and background edits',
    () async {
      final project = await create('ORIGINAL');
      final held = holdNextSave();
      final saving = service.setFavorite(project.id, true);
      await held.started;
      expect(service.isFavoriteSaving(project.id), isTrue);
      expect(service.projects.single.isFavorite, isFalse);
      await service.renameProject(project.id, 'RENAMED');
      service.updateProjectBackgroundColor(project.id, 0xFF234567);
      held.release.complete();
      await saving;
      await service.saveProject(project.id);
      final loaded = await cold();
      for (final current in [service.projects.single, loaded.projects.single]) {
        expect(current.name, 'RENAMED');
        expect(current.backgroundColor, 0xFF234567);
        expect(current.isFavorite, isTrue);
      }
      expect(service.isFavoriteSaving(project.id), isFalse);
    },
  );

  test(
    'repeated explicit favorite intent saves once and never inverts it',
    () async {
      final project = await create('INTENT');
      final held = holdNextSave();
      final first = service.setFavorite(project.id, true);
      await held.started;
      final duplicate = service.setFavorite(project.id, true);
      held.release.complete();
      await Future.wait([first, duplicate]);
      expect(held.calls, hasLength(1));
      expect(service.projects.single.isFavorite, isTrue);
      await service.setFavorite(project.id, true);
      expect(held.calls, hasLength(1));
      await service.setFavorite(project.id, false);
      expect(held.calls, hasLength(2));
      final loaded = await cold();
      expect(loaded.projects.single.isFavorite, isFalse);
      expect(service.isFavoriteSaving(project.id), isFalse);
    },
  );

  test(
    'accepted favorite still protects queued Trash after disposal',
    () async {
      final project = await create('DISPOSE');
      final held = holdNextSave();
      final saving = service.setFavorite(project.id, true);
      await held.started;
      final moving = expectLater(
        service.deleteProject(project.id),
        throwsA(anything),
      );
      service.dispose();
      serviceDisposed = true;
      held.release.complete();
      await saving;
      await moving;
      final loaded = await cold();
      expect(loaded.projects.single.id, project.id);
      expect(loaded.projects.single.isFavorite, isTrue);
      expect(loaded.trash, isEmpty);
    },
  );

  test(
    'favorite stays active on disk and can move only after unfavoriting',
    () async {
      final project = await create('KEPT');
      await favorite(project.id);
      final file = await archive(project.id);
      final bytes = file.readAsBytesSync();
      final before = await store.getAll();
      var notifications = 0;
      service.addListener(() => notifications++);
      await expectLater(service.deleteProject(project.id), throwsA(anything));
      expect(await store.getAll(), before);
      expect(file.readAsBytesSync(), bytes);
      expect(notifications, 0);
      final loaded = await cold();
      expect(loaded.projects.single.isFavorite, isTrue);
      expect(loaded.trash, isEmpty);
      await favorite(project.id);
      await service.deleteProject(project.id);
      final after = await cold();
      expect(after.projects, isEmpty);
      expect(after.trash.single.isFavorite, isFalse);
    },
  );

  test(
    'favorite is checked when queued deletion runs, not when it is requested',
    () async {
      final first = await create('FIRST');
      final protected = await create('KEPT');
      final gate = Completer<void>();
      store.gate = gate;
      store.started = Completer<void>();
      final moving = service.deleteProject(first.id);
      await store.started!.future;
      final queued = service.deleteProject(protected.id);
      await favorite(protected.id);
      final file = await archive(protected.id);
      final bytes = file.readAsBytesSync();
      gate.complete();
      await moving;
      await expectLater(queued, throwsA(anything));
      expect(file.readAsBytesSync(), bytes);
      final loaded = await cold();
      expect(loaded.projects.single.id, protected.id);
      expect(loaded.projects.single.isFavorite, isTrue);
      expect(loaded.trash.single.id, first.id);
    },
  );

  test(
    'a favorite toggle waits for an in-flight Trash acknowledgement',
    () async {
      final project = await create('OPEN');
      final gate = Completer<void>();
      store.gate = gate;
      store.started = Completer<void>();
      final moving = service.deleteProject(project.id);
      await store.started!.future;
      final toggling = service.toggleFavorite(project.id);
      final favoriteDuringPendingDelete = service.projects.single.isFavorite;
      gate.complete();
      await Future.wait([moving, toggling]);
      expect(favoriteDuringPendingDelete, isFalse);
      final loaded = await cold();
      expect(loaded.projects, isEmpty);
      expect(loaded.trash.single.isFavorite, isFalse);
    },
  );

  Future<AppLocalizations> home(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadAppFonts(tester);
    final owned = <ChangeNotifier>[];
    final providers = await tester.runAsync(
      () => buildAppProviders(debugOnCreated: owned.add),
    );
    addTearDown(() {
      for (final notifier in owned.reversed) {
        notifier.dispose();
      }
    });
    appRouter.go('/home');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ...providers!,
          ChangeNotifierProvider<ProjectService>.value(value: service),
        ],
        child: const NiarimApp(),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(HomeScreen)))!;
  }

  Future<void> selectBoth(WidgetTester tester) async {
    await tester.longPress(find.text('OPEN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('KEPT'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'mixed bulk selection explains favorite protection before moving anything',
    (tester) async {
      await tester.runAsync(() async {
        await create('OPEN');
        final kept = await create('KEPT');
        await favorite(kept.id);
      });
      final l10n = await home(tester);
      await selectBoth(tester);
      await tester.tap(find.byTooltip(l10n.homeMoveToTrash));
      await tester.pumpAndSettle();
      expect(find.byType(ProjectTrashDialog), findsNothing);
      expect(find.text(l10n.commonFavoriteDeleteBlocked), findsOneWidget);
      expect(find.text(l10n.homeSelectionCount(2)), findsOneWidget);
      expect(service.projects, hasLength(2));
      expect(service.trash, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'favoriting while a bulk dialog is open keeps all targets and explains the block',
    (tester) async {
      late Project kept;
      await tester.runAsync(() async {
        await create('OPEN');
        kept = await create('KEPT');
      });
      final l10n = await home(tester);
      await selectBoth(tester);
      await tester.tap(find.byTooltip(l10n.homeMoveToTrash));
      await tester.pumpAndSettle();
      expect(find.byType(ProjectTrashDialog), findsOneWidget);
      await tester.runAsync(() => favorite(kept.id));
      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(FilledButton, l10n.commonMove));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.byType(ProjectTrashDialog), findsOneWidget);
      expect(find.text(l10n.commonFavoriteDeleteBlocked), findsOneWidget);
      expect(find.text(l10n.homeSelectionCount(2)), findsOneWidget);
      expect(service.projects, hasLength(2));
      expect(service.trash, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
