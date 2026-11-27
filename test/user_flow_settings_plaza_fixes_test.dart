// 利用者の動き（設定を触る人・作品を整理する人・作品広場を見る人）を想定して
// Linuxの実画面で動かしたときに見つかった食い違い。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/community_work.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/screens/home/home_screen.dart'
    show ProjectSortMode, ProjectViewMode;
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/screens/settings/shortcut_settings_screen.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/shortcut_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

CommunityWork _work(String id, {String authorId = 'author'}) => CommunityWork(
  id: id,
  title: 'Walk $id',
  authorId: authorId,
  authorName: 'Painter',
  viewCount: 0,
  likeCount: 0,
  bookmarkCount: 0,
  postedAt: DateTime(2026),
  durationSeconds: 10,
  thumbnailColorIndex: 0,
  tags: const ['手描き'],
);

class _TwoProjects extends ProjectService {
  @override
  List<Project> get projects => [
    for (final id in ['a', 'b'])
      Project(
        id: id,
        name: 'Work $id',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        totalWorkSeconds: 0,
      ),
  ];

  @override
  List<ProjectFolder> get folders => const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Work Plaza mute', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('“show this work again” also shows a work of a muted creator; a '
        'blocked creator stays hidden', () async {
      final service = CommunityService();
      final work = _work('w1');
      service.replaceWorksForTest([work]);
      await service.setAuthorMuted('author', true);
      expect(service.isWorkMuted(work), isTrue);

      await service.unmuteWork(work.id, permanently: false);
      expect(service.isWorkMuted(work), isFalse);
      service.clearTemporaryUnmutes();
      expect(service.isWorkMuted(work), isTrue);
      await service.unmuteWork(work.id, permanently: true);
      expect(service.isWorkMuted(work), isFalse);
      // Other works of the muted creator stay hidden.
      expect(service.isWorkMuted(_work('w2')), isTrue);
    });
  });

  testWidgets('Ctrl+click on a card selects it instead of opening it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _TwoProjects();
    addTearDown(service.dispose);
    final longPressed = <String>[];
    await tester.pumpWidget(
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
              onLongPress: longPressed.add,
              onSelectionChanged: (_) {},
              currentFolderId: null,
              onOpenFolder: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.text('Work a'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    // Wait out the double-tap window of the card.
    await tester.pump(const Duration(milliseconds: 400));
    expect(longPressed, ['a']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('choosing the eraser for a new shortcut closes the sheet, and '
      'deleting it names the key', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final shortcuts = ShortcutService();
    await tester.runAsync(shortcuts.init);
    final settings = SettingsService();
    await tester.runAsync(settings.init);
    final brushes = BrushService();
    await tester.runAsync(brushes.init);
    const locale = Locale('ja');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ShortcutService>.value(value: shortcuts),
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<BrushService>.value(value: brushes),
        ],
        child: MaterialApp(
          locale: locale,
          theme: ThemeService().themeDataFor(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ShortcutSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = lookupAppLocalizations(locale);
    final before = shortcuts.bindings.length;
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyI);
    await tester.pumpAndSettle();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyI);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.shortcutActionTypeTool).last);
    await tester.pumpAndSettle();
    final eraser = find.text(l10n.quickToolEraser).last;
    await tester.ensureVisible(eraser);
    await tester.tap(eraser);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(shortcuts.bindings.length, before + 1);

    final added = shortcuts.bindings.last;
    final delete = find.descendant(
      of: find.ancestor(
        of: find.text(added.comboLabel).first,
        matching: find.byType(ListTile),
      ),
      matching: find.byIcon(Icons.delete_outline),
    );
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        l10n.shortcutBindingName(added.comboLabel, l10n.quickToolEraser),
      ),
      findsOneWidget,
    );
  });

  group('the save tree goes on from the last save', () {
    late Directory tempDir;
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      tempDir = Directory.systemTemp.createTempSync('user_flow_tree_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => tempDir.path);
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('a save becomes the current one; a loaded save does too', () async {
      final ps = ProjectService();
      await ps.init();
      addTearDown(ps.dispose);
      final p = await ps.createProject(
        name: 'tree',
        fps: 2,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 36,
      );
      final saves = SaveTreeService()..setTreeMode(true);
      await saves.init();
      expect(saves.currentNodeOf(p.id), isNull);
      final first = await saves.saveAsChild(
        projectId: p.id,
        project: p,
        scenes: ps.scenesOf(p.id),
        tileManager: ps.tileManagerOf(p.id),
      );
      expect(saves.currentNodeOf(p.id), first.id);
      final second = await saves.saveAsChild(
        projectId: p.id,
        project: p,
        scenes: ps.scenesOf(p.id),
        tileManager: ps.tileManagerOf(p.id),
        parentId: saves.currentNodeOf(p.id),
      );
      expect(second.parentId, first.id);
      saves.markCurrentNode(p.id, first.id);
      expect(saves.currentNodeOf(p.id), first.id);
      // A deleted save is not current any more.
      await saves.deleteNode(p.id, first.id);
      expect(saves.currentNodeOf(p.id), isNull);
    });
  });
}
