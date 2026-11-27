// 利用者の動き（初めて使う人・作品を整理する人）を想定してLinuxの実画面で
// 動かしたときに見つかった、ホーム・作品詳細・編集の出入りの食い違い。
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' hide UndoManager;
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/engine/undo_manager.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart'
    show ProjectSortMode, ProjectViewMode;
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/screens/home/widgets/work_folder_move_sheet.dart';
import 'package:niarim/screens/project/new_project_screen.dart';
import 'package:niarim/services/autosave_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// 作品の保存先を一時フォルダにする。
Directory _mockDocuments({bool resetPrefs = true}) {
  if (resetPrefs) SharedPreferences.setMockInitialValues({});
  final directory = Directory.systemTemp.createTempSync('user-flow-');
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (_) async => directory.path);
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });
  return directory;
}

Future<Project> _create(ProjectService service, {String? folderId}) =>
    service.createProject(
      name: 'Walk',
      fps: 2,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      exportWidth: 64,
      exportHeight: 64,
      folderId: folderId,
    );

/// 作るのは止めたまま、渡されたフォルダを覚える。
class _FolderRecordingCreation extends ProjectService {
  final folderArgs = <String?>[];

  @override
  Future<Project> createProject({
    required String name,
    required int fps,
    required int durationSeconds,
    required int backgroundColor,
    int exportWidth = 1920,
    int exportHeight = 1080,
    double drawingAreaScale = 1.0,
    List<String>? enabledAutofillPresetIds,
    bool makingEnabled = false,
    String? folderId,
  }) {
    folderArgs.add(folderId);
    return Completer<Project>().future;
  }
}

/// 作品を開くと「前回の起動で残った、新しい自動保存」を返す。
class _NewerAutosave extends AutosaveService {
  _NewerAutosave(this.data);

  final NiaproData data;

  @override
  Future<({NiaproData data, DateTime savedAt})?> newerThanWorkFile(
    ProjectService projectService,
    String projectId,
  ) async => (data: data, savedAt: DateTime.now());
}

/// フォルダ1つと作品1つの一覧（移動を記録する）。
class _ListProjects extends ProjectService {
  final moves = <String?>[];

  @override
  List<Project> get projects => [
    Project(
      id: 'project',
      name: 'Walk',
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      totalWorkSeconds: 0,
    ),
  ];

  @override
  List<ProjectFolder> get folders => [
    ProjectFolder(id: 'folder', name: 'Class'),
  ];

  @override
  Future<void> moveToFolder(String projectId, String? folderId) async {
    moves.add(folderId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a work made inside a folder', () {
    test('is created in that folder and kept there', () async {
      final documents = _mockDocuments();
      final service = ProjectService();
      addTearDown(service.dispose);
      final folder = await service.createFolder('Class');
      final project = await _create(service, folderId: folder.id);
      expect(project.folderId, folder.id);
      final file = documents
          .listSync(recursive: true)
          .whereType<File>()
          .singleWhere((f) => f.path.endsWith('${project.id}.niapro'));
      final stored = await NiaproSerializer.load(file.path, withTiles: false);
      expect(stored.project.folderId, folder.id);
      // 作る間に消えたフォルダなら一番上に作る。
      final loose = await _create(service, folderId: 'gone');
      expect(loose.folderId, isNull);
    });

    testWidgets('the home + button passes the open folder to the new '
        'project screen', (tester) async {
      SharedPreferences.setMockInitialValues({
        'first_launch': false,
        'language': 'ja',
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      });
      _mockDocuments(resetPrefs: false);
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final providers = await tester.runAsync(buildAppProviders);
      final recording = _FolderRecordingCreation();
      addTearDown(recording.dispose);
      final folder = await tester.runAsync(
        () => recording.createFolder('Class'),
      );
      appRouter.go('/home');
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ...providers!,
            ChangeNotifierProvider<ProjectService>.value(value: recording),
          ],
          child: const NiarimApp(),
        ),
      );
      await tester.pumpAndSettle();

      // フォルダを開き、空の表示の案内どおり＋から新規プロジェクトを作る。
      await tester.tap(find.text('Class').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add).last);
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(Scaffold).first),
      )!;
      await tester.tap(find.text(l10n.homeAddSheetNewProject));
      await tester.pumpAndSettle();
      final screen = tester.widget<NewProjectScreen>(
        find.byType(NewProjectScreen),
      );
      expect(screen.folderId, folder!.id);
      final create = find.byType(FilledButton).last;
      await tester.ensureVisible(create);
      await tester.tap(create);
      await tester.pump();
      expect(recording.folderArgs, [folder.id]);
    });

    testWidgets('home reopens the folder that was open when it is built '
        'again (the editor’s home button)', (tester) async {
      SharedPreferences.setMockInitialValues({
        'first_launch': false,
        'language': 'ja',
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      });
      _mockDocuments(resetPrefs: false);
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final providers = await tester.runAsync(buildAppProviders);
      appRouter.go('/home');
      await tester.pumpWidget(
        MultiProvider(providers: providers!, child: const NiarimApp()),
      );
      await tester.pumpAndSettle();
      final service = tester
          .element(find.byType(Scaffold).first)
          .read<ProjectService>();
      final folder = await tester.runAsync(() => service.createFolder('Class'));
      await tester.runAsync(() => _create(service, folderId: folder!.id));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Class').first);
      await tester.pumpAndSettle();
      expect(find.text('Walk'), findsOneWidget);

      // キャンバス・タイムラインの家のボタンと同じく、ホームを作り直す。
      appRouter.go('/settings');
      await tester.pumpAndSettle();
      appRouter.go('/home');
      await tester.pumpAndSettle();
      expect(service.homeProjectFolderId, folder!.id);
      expect(find.text('Walk'), findsOneWidget);
    });
  });

  group('opening and leaving the editor without changes', () {
    test('keeps the last-saved time; a drawn tile moves it', () async {
      _mockDocuments();
      final service = ProjectService();
      addTearDown(service.dispose);
      final project = await _create(service);
      final opened = project.updatedAt;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      service.beginWorkTracking(project.id);
      service.endWorkTracking();
      await service.saveProject(project.id).then((_) {}, onError: (_) {});
      // saveProject itself is a real save: look at the tracking save only.
      final afterView = service.projects.first.updatedAt;
      expect(afterView, isNot(opened)); // the explicit save above moved it

      // Leave again without changes: the time stays.
      service.beginWorkTracking(project.id);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      service.endWorkTracking();
      await _settle(service, project.id);
      expect(service.projects.first.updatedAt, afterView);

      // Drawing is a change.
      service.beginWorkTracking(project.id);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final layer = service.tileKeyFor(
        project.id,
        service.scenesOf(project.id).first.id,
        0,
        'Layer0001',
      );
      service.tileManagerOf(project.id).getOrCreateTile(layer, 0, 0)[3] = 255;
      service.endWorkTracking();
      await _settle(service, project.id);
      expect(service.projects.first.updatedAt.isAfter(afterView), isTrue);
    });

    test('the automatic cover made on leaving is not a change', () async {
      _mockDocuments();
      final service = ProjectService();
      addTearDown(service.dispose);
      final project = await _create(service);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // As when the canvas closes: tracking ends, the cover is made.
      service.beginWorkTracking(project.id);
      service.endWorkTracking();
      await service.generateAndSaveThumbnail(project.id);
      await _settle(service, project.id);
      expect(service.projects.first.thumbnailPath, isNotNull);
      expect(service.projects.first.updatedAt, project.updatedAt);
    });

    test('the back-to-list question is only needed after a change', () async {
      _mockDocuments();
      final history = UndoManager();
      final service = ProjectService()..setUndoManager(history);
      addTearDown(service.dispose);
      final project = await _create(service);
      history.selectProject(project.id);
      service.beginWorkTracking(project.id);
      expect(service.unchangedSinceEditStart(project.id), isTrue);

      await service.setProjectTags(project.id, ['walk']);
      expect(service.unchangedSinceEditStart(project.id), isFalse);
      // Undone back to where the editor opened: nothing to save.
      history.undo();
      expect(service.unchangedSinceEditStart(project.id), isTrue);

      // Going on in the timeline counts from when the canvas opened.
      await service.setProjectTags(project.id, ['walk']);
      service.beginWorkTracking(project.id);
      expect(service.unchangedSinceEditStart(project.id), isFalse);
      // A manual save makes the current state the saved one.
      service.onManualSaveCommitted(project.id);
      expect(service.unchangedSinceEditStart(project.id), isTrue);
      service.endWorkTracking();
    });
  });

  group('moving to a folder', () {
    Widget host(_ListProjects service) =>
        ChangeNotifierProvider<ProjectService>.value(
          value: service,
          child: MaterialApp(
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ProjectListWidget(
                viewMode: ProjectViewMode.medium,
                sortMode: ProjectSortMode.nameAsc,
                isSelectionMode: false,
                selectedIds: const {},
                onLongPress: (_) {},
                onSelectionChanged: (_) {},
                currentFolderId: null,
                onOpenFolder: (_) {},
              ),
            ),
          ),
        );

    testWidgets('the card menu moves a work, marks where it is and says '
        'where it went', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = _ListProjects();
      addTearDown(service.dispose);
      await tester.pumpWidget(host(service));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('collectionMenu_project')),
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('フォルダへ移動').last);
      await tester.pumpAndSettle();

      final sheet = find.byType(WorkFolderMoveSheet);
      expect(
        find.descendant(of: sheet, matching: find.text('フォルダへ移動')),
        findsOneWidget,
      );
      // The work is at the top level: that row has the mark and is selected.
      final rootRow = find.ancestor(
        of: find.text('フォルダなし（ルート）'),
        matching: find.byType(ListTile),
      );
      expect(
        find.descendant(of: rootRow, matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
      // Choosing where it already is moves nothing.
      await tester.tap(rootRow);
      await tester.pumpAndSettle();
      expect(service.moves, isEmpty);

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('collectionMenu_project')),
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('フォルダへ移動').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(WorkFolderMoveSheet),
          matching: find.text('Class'),
        ),
      );
      await tester.pumpAndSettle();
      expect(service.moves, ['folder']);
      expect(find.text('「Class」へ移動しました'), findsOneWidget);
    });

    testWidgets('the sheet offers a new folder when there is none', (
      tester,
    ) async {
      var created = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: WorkFolderMoveSheet(
              folders: const [],
              filename: 'Walk',
              markCurrent: true,
              onMove: (_) async {},
              onCreate: () => created++,
            ),
          ),
        ),
      );
      expect(find.text('新規フォルダを作成'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });
  });

  testWidgets('the work’s details show the newer automatic save it opened '
      'with', (tester) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    _mockDocuments(resetPrefs: false);
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = await tester.runAsync(buildAppProviders);
    final service = ProjectService();
    addTearDown(service.dispose);
    final project = (await tester.runAsync(() => _create(service)))!;
    // The automatic save holds a red picture; the work file is blank.
    final layer = service.tileKeyFor(
      project.id,
      service.scenesOf(project.id).first.id,
      0,
      'Layer0001',
    );
    final tiles = service.tileManagerOf(project.id);
    final red = tiles.getOrCreateTile(layer, 0, 0);
    for (var i = 0; i < red.length; i += 4) {
      red[i] = 255;
      red[i + 3] = 255;
    }
    final newer = NiaproData(
      project: project,
      scenes: service.scenesOf(project.id),
      tileData: {
        layer: {'0,0': Uint8List.fromList(red)},
      },
    );
    tiles.importAll(const {}, asStoredInWorkFile: true);
    tiles.consumeDirtyTiles();

    appRouter.go('/project/${project.id}');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ...providers!,
          ChangeNotifierProvider<ProjectService>.value(value: service),
          ChangeNotifierProvider<AutosaveService>.value(
            value: _NewerAutosave(newer),
          ),
        ],
        child: const NiarimApp(),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    final image = tester
        .widgetList<RawImage>(
          find.descendant(
            of: find.byKey(const Key('projectDetailPreviewArtwork')),
            matching: find.byType(RawImage),
          ),
        )
        .first
        .image!;
    final bytes = await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    final centre = (image.height ~/ 2 * image.width + image.width ~/ 2) * 4;
    expect(bytes!.getUint8(centre), greaterThan(200)); // red
    expect(bytes.getUint8(centre + 1), lessThan(60));
  });
}

/// The tracking save runs in the work's save queue; wait for it.
Future<void> _settle(ProjectService service, String id) async {
  for (var i = 0; i < 50; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
