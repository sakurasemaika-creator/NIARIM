import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/engine/niatra_serializer.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/home_list_filters.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/models/scene.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/services/autofill_preset_service.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/export_storage.dart';
import 'package:niarim/services/local_file_trash_service.dart';
import 'package:niarim/services/palette_service.dart';
import 'package:niarim/services/pixel_art_palette_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/stamp_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/services/tone_service.dart';
import 'package:niarim/services/work_folder_service.dart';
import 'package:niarim/utils/app_error_reporter.dart';
import 'package:niarim/widgets/sort_mode_control.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'helpers/first_use_tooltips.dart';

/// ホームのプロジェクト・作品一覧・共有・ゴミ箱で選んだ並び順・向き・
/// 絞り込みは、選んだときに保存し、アプリを起動し直しても残る（所有者の
/// 判断 DISC141：「プロジェクトと同様に、作業、共有、ゴミ箱の並べ替え順序と
/// フィルターは再起動後も維持されるべき」）。設定の引き継ぎ（.niatra の
/// 端末保存データ）にも入り、読み込むと開いている一覧にもすぐ当たる。
/// 作品一覧・共有のフォルダの中も、その一覧の並び順で並ぶ（プロジェクトの
/// フォルダと同じ）。以前はホームを開いている間だけ覚え、起動し直すと
/// 「更新日時」の新しい順・絞り込みなし・ゴミ箱の種類はすべて表示へ戻って
/// いた。プロジェクトの並び順は起動の後から読んでいて、最初のフレームは
/// 既定の並びだった。

/// 選ぶと決まった.niatraを返すファイル選択。
class _PickNiatra extends FilePicker {
  _PickNiatra(this.bytes);

  final List<int> bytes;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    @Deprecated('unused') bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => FilePickerResult([
    PlatformFile(
      name: 'moved.niatra',
      size: bytes.length,
      bytes: Uint8List.fromList(bytes),
    ),
  ]);
}

/// [rejected]のキーへの書き込みを断る（書けなかったと返す）保存。
class _RejectingStore extends InMemorySharedPreferencesStore {
  _RejectingStore() : super.empty();

  final rejected = <String>{};

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (rejected.contains(key)) return false;
    return super.setValue(type, key, value);
  }
}

const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');
const _ffmpegEventChannel = EventChannel(
  'flutter.arthenica.com/ffmpeg_kit_event',
);

const _baseline = <String, Object>{
  'first_launch': false,
  'language': 'ja',
  'force_pc_mode': 0,
};

class _App {
  _App(this.tester);

  final WidgetTester tester;
  late Directory directory;

  Element get _home => tester.element(find.byType(HomeScreen));

  AppLocalizations get l10n => AppLocalizations.of(_home)!;

  Future<void> frames([int count = 8]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> settleIo([int rounds = 3]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  /// 保存先・画面の大きさを決め、[prefs]を保存した状態でアプリを起動する。
  /// [onFirstFrame]は、アプリを描いた最初のフレームで呼ぶ（待たずに見る）。
  Future<void> open({
    Map<String, Object> prefs = const {},
    void Function()? onFirstFrame,
  }) async {
    SharedPreferences.setMockInitialValues({
      ..._baseline,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      ...prefs,
    });
    directory = Directory.systemTemp.createTempSync('niarim_list_filters_');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      _pathChannel,
      (call) async => directory.path,
    );
    messenger.setMockStreamHandler(
      _ffmpegEventChannel,
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      messenger.setMockMethodCallHandler(_pathChannel, null);
      messenger.setMockStreamHandler(_ffmpegEventChannel, null);
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          if (directory.existsSync()) directory.deleteSync(recursive: true);
          return;
        } on FileSystemException {
          continue;
        }
      }
    });
    await _start(onFirstFrame: onFirstFrame);
  }

  Future<void> _start({void Function()? onFirstFrame}) async {
    ExportStorage.invalidate();
    appRouter.go('/home');
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    onFirstFrame?.call();
    await frames(6);
    await settleIo();
  }

  /// 保存してある値（端末に残っているもの）だけで、アプリを起動し直す。
  Future<void> restart({Map<String, Object>? prefs}) async {
    await close();
    final saved = await tester.runAsync(() async {
      final current = await SharedPreferences.getInstance();
      return {
        for (final key in current.getKeys())
          if (current.get(key) case final Object value) key: value,
      };
    });
    SharedPreferences.setMockInitialValues(prefs ?? saved!);
    await _start();
  }

  Future<void> close() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await settleIo(2);
  }

  Future<void> seed() async {
    final projects = _home.read<ProjectService>();
    await tester.runAsync(() async {
      final exports = await ExportStorage.createManagedDirectory();
      for (final name in const ['walk.mp4', 'run.gif']) {
        File('${exports.path}/$name').writeAsBytesSync(List.filled(64, 1));
      }
      ExportStorage.invalidate();
      await ExportEngine.listExportedFiles(forceRefresh: true);
      final project = await projects.createProject(
        name: 'ゴミの作品',
        fps: 8,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
      );
      await projects.deleteProject(project.id);
      final trashed = File('${exports.path}/run.gif');
      await LocalFileTrashService.move(trashed, LocalTrashKind.exportedWork);
      ExportStorage.invalidate();
      await ExportEngine.listExportedFiles(forceRefresh: true);
    });
    await frames(4);
    await settleIo();
  }

  /// タブを開き、その一覧の読み込み（本物のファイルの読み書き）を待つ。
  Future<void> showTab(int index) async {
    await tester.tap(find.byKey(ValueKey('home_tab_$index')));
    await frames(10);
    for (var i = 0; i < 4; i++) {
      await settleIo(3);
      await frames(4);
    }
  }

  SortModeControl sortIn(Type screen) => tester.widget<SortModeControl>(
    find.descendant(
      of: find.byType(screen),
      matching: find.byType(SortModeControl),
    ),
  );

  Finder get _worksHeader => find.ancestor(
    of: find.byKey(const Key('worksFavoritesOnlyFilter')),
    matching: find.byKey(const Key('homeCollectionSortHeader')),
  );

  SortModeControl get worksSort => tester.widget<SortModeControl>(
    find.descendant(of: _worksHeader, matching: find.byType(SortModeControl)),
  );

  Finder get projectsFavourites => find.descendant(
    of: find.byType(ProjectListWidget),
    matching: find.widgetWithText(FilterChip, l10n.homeFavoritesOnly),
  );

  bool chipSelected(Finder chip) => tester.widget<FilterChip>(chip).selected;

  /// 選んだ直後（一覧を開いたまま）に保存されていること。破棄されるときに
  /// 書くのでは、アプリを閉じる・落ちるときに残らない。
  Future<void> expectSaved(String key, Object value) async {
    await settleIo(1);
    final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
    expect(prefs.get(key), value, reason: '$key is saved when it is chosen');
  }

  /// いちばん上の画面（フォルダの中）の並び順。
  SortModeControl get topSort =>
      tester.widget<SortModeControl>(find.byType(SortModeControl).last);

  /// いちばん上の画面（フォルダの中）を閉じる。
  Future<void> back() async {
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await frames(10);
    await settleIo();
  }

  /// 作品一覧に「Box」フォルダを作り、書き出した作品を1つ入れる。
  Future<void> seedWorksFolder() async {
    final folders = _home.read<WorkFolderService>();
    await tester.runAsync(() async {
      final folder = await folders.createFolder('Box');
      await folders.moveFileToFolder('walk.mp4', folder.id);
    });
    await frames(4);
    await settleIo();
  }

  /// 共有の受け取ったものに「Inbox」フォルダを作り、Apple（先に保存）と
  /// Banana（後に保存）を入れる。
  Future<void> seedSharedFolder() async {
    final projects = _home.read<ProjectService>();
    await tester.runAsync(() async {
      final folder = await projects.createSharedFolder('Inbox');
      for (final name in const ['Apple', 'Banana']) {
        final work = await projects.importSharedProject(
          NiaproData(
            project: Project(
              id: 'source_$name',
              name: name,
              fps: 1,
              durationSeconds: 1,
              backgroundColor: 0xFFFFFFFF,
              exportWidth: 64,
              exportHeight: 64,
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
              totalWorkSeconds: 0,
            ),
            scenes: const [
              Scene(id: 'Scene0001', index: 0, frames: [Frame(index: 0)]),
            ],
            tileData: const {},
          ),
        );
        await projects.saveProject(work.id);
        await projects.moveToSharedFolder(work.id, folder.id);
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
    });
    await frames(4);
    await settleIo();
  }

  /// 共有の「Inbox」フォルダを開いたときの並び（上から）。
  Future<List<String>> sharedFolderOrder() async {
    await tester.tap(find.text('Inbox'));
    await frames(10);
    await settleIo();
    final names = ['Apple', 'Banana']
      ..sort(
        (a, b) => tester
            .getTopLeft(find.text(a))
            .dy
            .compareTo(tester.getTopLeft(find.text(b)).dy),
      );
    await back();
    return names;
  }

  /// 設定の引き継ぎの画面で[bytes]の .niatra を読み込み、ホームへ戻る。
  Future<void> importOnTransferScreen(List<int> bytes) async {
    FilePicker? previous;
    try {
      previous = FilePicker.platform;
    } catch (_) {
      previous = null;
    }
    FilePicker.platform = _PickNiatra(bytes);
    addTearDown(() {
      if (previous != null) FilePicker.platform = previous;
    });
    unawaited(appRouter.push('/settings/transfer'));
    await frames(10);
    await settleIo();
    await tester.tap(
      find.text(l10nOf(find.byType(Scaffold).last).transferImport),
    );
    final done = find.text(
      l10nOf(find.byType(Scaffold).last).transferImportSuccessSnackbar,
    );
    for (var i = 0; i < 100 && done.evaluate().isEmpty; i++) {
      await settleIo(1);
    }
    expect(done, findsOneWidget, reason: 'the import finished');
    appRouter.pop();
    await frames(10);
    await settleIo();
  }

  AppLocalizations l10nOf(Finder finder) =>
      AppLocalizations.of(tester.element(finder))!;

  Finder trashKind(TrashEntryKind kind) =>
      find.byKey(ValueKey('trashKind_${kind.name}'));

  /// どのタブでも選べるものを選ぶ：プロジェクトはお気に入りのみ・更新日時の
  /// 古い順、作品一覧はお気に入りのみ・名前の昇順、共有はお気に入りのみ・
  /// 名前の降順、ゴミ箱は書き出した作品・作成したものの種類を外して更新日時の
  /// 古い順。どれも選んだ直後（その一覧を開いたまま）に保存されている。
  Future<void> chooseFilters() async {
    await tester.tap(projectsFavourites);
    await frames(4);
    await expectSaved('home.projectFavoritesOnly.v1', true);
    sortIn(ProjectListWidget).onToggleDirection();
    await frames(4);
    await expectSaved('home.projectSortMode.v1', 'updatedAsc');
    await showTab(1);
    await tester.tap(find.byKey(const Key('worksFavoritesOnlyFilter')));
    await frames(4);
    await expectSaved('home.worksFavoritesOnly.v1', true);
    worksSort.onSortByNameChanged(true);
    await frames(4);
    await expectSaved('home.worksSortMode.v1', 'nameDesc');
    worksSort.onToggleDirection();
    await frames(4);
    await expectSaved('home.worksSortMode.v1', 'nameAsc');
    await showTab(2);
    await tester.tap(find.byKey(const Key('sharedFavoritesOnlyFilter')));
    await frames(4);
    await expectSaved('home.sharedFavoritesOnly.v1', true);
    sortIn(SharedScreen).onSortByNameChanged(true);
    await frames(4);
    await expectSaved('home.sharedSortMode.v1', 'nameDesc');
    await showTab(3);
    await tester.tap(trashKind(TrashEntryKind.exportedWork));
    await frames(4);
    await expectSaved('home.trashHiddenKinds.v1', ['exportedWork']);
    await tester.tap(trashKind(TrashEntryKind.createdShare));
    await frames(4);
    await expectSaved('home.trashHiddenKinds.v1', [
      'createdShare',
      'exportedWork',
    ]);
    sortIn(TrashScreen).onToggleDirection();
    await frames(4);
    await expectSaved('home.trashSortMode.v1', 'updatedAsc');
    await showTab(0);
  }

  /// 開いているゴミ箱のタブで、[chooseFilters]で選んだもののうち戻っていない
  /// もの。
  List<String> lostTrashFilters() => [
    for (final kind in TrashEntryKind.values)
      if (chipSelected(trashKind(kind)) ==
          (kind == TrashEntryKind.exportedWork ||
              kind == TrashEntryKind.createdShare))
        'trash kind ${kind.name}',
    if (sortIn(TrashScreen).sortByName) 'trash sort field',
    if (!sortIn(TrashScreen).sortAscending) 'trash sort direction',
  ];

  /// [chooseFilters]で選んだもののうち、今の画面で戻っているもの以外。
  Future<List<String>> lostFilters() async {
    final lost = <String>[];
    if (!chipSelected(projectsFavourites)) lost.add('projects favourites');
    final projects = sortIn(ProjectListWidget);
    if (projects.sortByName) lost.add('projects sort field');
    if (!projects.sortAscending) lost.add('projects sort direction');
    await showTab(1);
    if (!chipSelected(find.byKey(const Key('worksFavoritesOnlyFilter')))) {
      lost.add('works favourites');
    }
    if (!worksSort.sortByName) lost.add('works sort field');
    if (!worksSort.sortAscending) lost.add('works sort direction');
    await showTab(2);
    if (!chipSelected(find.byKey(const Key('sharedFavoritesOnlyFilter')))) {
      lost.add('shared favourites');
    }
    final shared = sortIn(SharedScreen);
    if (!shared.sortByName) lost.add('shared sort field');
    if (shared.sortAscending) lost.add('shared sort direction');
    await showTab(3);
    lost.addAll(lostTrashFilters());
    await showTab(0);
    return lost;
  }

  /// どのタブも既定（更新日時の新しい順・絞り込みなし・種類はすべて）か。
  Future<List<String>> notDefault() async {
    final wrong = <String>[];
    if (chipSelected(projectsFavourites)) wrong.add('projects favourites');
    final projects = sortIn(ProjectListWidget);
    if (projects.sortByName || projects.sortAscending) {
      wrong.add('projects sort');
    }
    await showTab(1);
    if (chipSelected(find.byKey(const Key('worksFavoritesOnlyFilter')))) {
      wrong.add('works favourites');
    }
    if (worksSort.sortByName || worksSort.sortAscending) {
      wrong.add('works sort');
    }
    await showTab(2);
    if (chipSelected(find.byKey(const Key('sharedFavoritesOnlyFilter')))) {
      wrong.add('shared favourites');
    }
    final shared = sortIn(SharedScreen);
    if (shared.sortByName || shared.sortAscending) wrong.add('shared sort');
    await showTab(3);
    for (final kind in TrashEntryKind.values) {
      if (!chipSelected(trashKind(kind))) wrong.add('trash kind ${kind.name}');
    }
    final trash = sortIn(TrashScreen);
    if (trash.sortByName || trash.sortAscending) wrong.add('trash sort');
    await showTab(0);
    return wrong;
  }

  /// 端末保存データだけを選んで .niatra を書き出す。
  Future<List<int>> exportDeviceData() async {
    final home = _home;
    return (await tester.runAsync(
      () => NiatraSerializer.export(
        selectedItems: const {'端末保存データ': true},
        settings: home.read<SettingsService>(),
        brush: home.read<BrushService>(),
        tone: home.read<ToneService>(),
        stamp: home.read<StampService>(),
        autofillPresets: home.read<AutofillPresetService>(),
        theme: home.read<ThemeService>(),
        palette: home.read<PaletteService>(),
        pixelArtPalette: home.read<PixelArtPaletteService>(),
      ),
    ))!;
  }
}

/// このテストで覚えるキー（プロジェクトの並び順は以前から残している）。
const _keys = [
  'home.projectSortMode.v1',
  'home.projectFavoritesOnly.v1',
  'home.worksSortMode.v1',
  'home.worksFavoritesOnly.v1',
  'home.sharedSortMode.v1',
  'home.sharedFavoritesOnly.v1',
  'home.trashSortMode.v1',
  'home.trashHiddenKinds.v1',
];

void main() {
  testWidgets('並び順・向き・絞り込みは、アプリを起動し直しても4つのタブで残る', (tester) async {
    final app = _App(tester);
    await app.open();
    await app.seed();
    await app.chooseFilters();
    // 起動し直さなくても（タブを行き来しても）残っている。
    expect(await app.lostFilters(), isEmpty, reason: 'lost by a tab switch');

    await app.restart();
    expect(
      await app.lostFilters(),
      isEmpty,
      reason: 'reset by restarting the app',
    );
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('壊れた・知らない保存の値では既定で始まり、起動で書き換えない', (tester) async {
    const corrupt = <String, Object>{
      'home.projectSortMode.v1': 5,
      'home.projectFavoritesOnly.v1': 'yes',
      'home.worksSortMode.v1': 7,
      'home.worksFavoritesOnly.v1': 1,
      'home.sharedSortMode.v1': 'sideways',
      'home.sharedFavoritesOnly.v1': 'true',
      'home.trashSortMode.v1': true,
      'home.trashHiddenKinds.v1': 3,
    };
    final app = _App(tester);
    await app.open(prefs: corrupt);
    await app.seed();
    expect(await app.notDefault(), isEmpty);
    final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
    expect(
      {for (final key in corrupt.keys) key: prefs.get(key)},
      corrupt,
      reason: 'startup must not overwrite unreadable values',
    );
    expect(tester.takeException(), isNull);

    // 後の版の種類の名前は飛ばし、知っている種類だけを外す。
    await app.restart(
      prefs: {
        ..._baseline,
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
        'home.trashHiddenKinds.v1': ['someLaterKind', 'receivedShare'],
      },
    );
    await app.showTab(3);
    for (final kind in TrashEntryKind.values) {
      expect(
        app.chipSelected(app.trashKind(kind)),
        kind != TrashEntryKind.receivedShare,
        reason: kind.name,
      );
    }
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('起動した最初のフレームから、覚えた絞り込みで出す（後から切り替わらない）', (tester) async {
    final app = _App(tester);
    bool? projectsFavouritesAtFirstFrame;
    (bool, bool)? projectsSortAtFirstFrame;
    await app.open(
      prefs: const {
        'home.projectSortMode.v1': 'nameAsc',
        'home.projectFavoritesOnly.v1': true,
        'home.trashSortMode.v1': 'nameAsc',
        'home.trashHiddenKinds.v1': ['exportedWork'],
      },
      onFirstFrame: () {
        projectsFavouritesAtFirstFrame = app.chipSelected(
          app.projectsFavourites,
        );
        final sort = app.sortIn(ProjectListWidget);
        projectsSortAtFirstFrame = (sort.sortByName, sort.sortAscending);
      },
    );
    expect(projectsFavouritesAtFirstFrame, isTrue);
    expect(projectsSortAtFirstFrame, (true, true), reason: 'name, ascending');
    // ゴミ箱のタブも、作られた最初のフレームから覚えた値で出る（タブは
    // 見えるときに作り直される）。
    await tester.tap(find.byKey(const ValueKey('home_tab_3')));
    final exportedChip = app.trashKind(TrashEntryKind.exportedWork);
    for (var i = 0; i < 30 && exportedChip.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(app.chipSelected(exportedChip), isFalse);
    expect(
      app.chipSelected(app.trashKind(TrashEntryKind.createdProject)),
      isTrue,
    );
    final trash = app.sortIn(TrashScreen);
    expect(trash.sortByName, isTrue);
    expect(trash.sortAscending, isTrue);
    await app.frames(10);
    await app.settleIo();
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('設定の引き継ぎ（.niatra の端末保存データ）で、もう1台へ移る', (tester) async {
    final app = _App(tester);
    await app.open();
    await app.seed();
    await app.chooseFilters();
    final bytes = await app.exportDeviceData();

    // もう1台：何も選んでいない端末で読み込み、起動し直す。
    await app.close();
    SharedPreferences.setMockInitialValues({
      ..._baseline,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    await tester.runAsync(
      () => NiatraSerializer.restoreLocalPreferences(
        NiatraSerializer.loadFromBytes(bytes),
      ),
    );
    final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
    expect(
      [
        for (final key in _keys)
          if (!prefs.containsKey(key)) key,
      ],
      isEmpty,
      reason: 'not carried by the settings transfer',
    );
    await app.restart();
    expect(await app.lostFilters(), isEmpty, reason: 'not applied on import');
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('引き継ぎの画面で読み込むと、開いているホームの一覧にもすぐ当たる', (tester) async {
    final app = _App(tester);
    await app.open();
    await app.seed();
    await app.chooseFilters();
    final bytes = await app.exportDeviceData();

    // もう1台：何も選んでいない端末で、ゴミ箱のタブを開いたまま読み込む。
    await app.restart(
      prefs: {..._baseline, firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys},
    );
    expect(await app.notDefault(), isEmpty);
    await app.showTab(3);
    await app.importOnTransferScreen(bytes);
    // 開いたままだったゴミ箱のタブ（作り直していない）。
    expect(app.lostTrashFilters(), isEmpty, reason: 'the open Trash tab');
    await app.showTab(0);
    expect(await app.lostFilters(), isEmpty, reason: 'not applied on import');
    expect(tester.takeException(), isNull);

    // 読み込んだ値は保存にも入っていて、起動し直しても同じ。
    await app.restart();
    expect(await app.lostFilters(), isEmpty, reason: 'lost after a restart');
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('作品一覧のフォルダの中で選んだ並び順は作品一覧の並び順になり、起動し直しても残る', (tester) async {
    final app = _App(tester);
    await app.open();
    await app.seed();
    await app.seedWorksFolder();
    await app.showTab(1);
    await tester.tap(find.text('Box'));
    await app.frames(10);
    await app.settleIo();
    expect((app.topSort.sortByName, app.topSort.sortAscending), (false, false));
    app.topSort.onSortByNameChanged(true);
    await app.frames(4);
    app.topSort.onToggleDirection();
    await app.frames(4);
    await app.expectSaved('home.worksSortMode.v1', 'nameAsc');
    expect((app.topSort.sortByName, app.topSort.sortAscending), (true, true));

    // 戻った作品一覧も同じ並び順。
    await app.back();
    expect(
      (app.worksSort.sortByName, app.worksSort.sortAscending),
      (true, true),
      reason: 'the Works list after going back',
    );

    // 起動し直しても、作品一覧とフォルダの中の両方で残る。
    await app.showTab(0);
    await app.restart();
    await app.showTab(1);
    expect(
      (app.worksSort.sortByName, app.worksSort.sortAscending),
      (true, true),
      reason: 'the Works list after a restart',
    );
    await tester.tap(find.text('Box'));
    await app.frames(10);
    await app.settleIo();
    expect(
      (app.topSort.sortByName, app.topSort.sortAscending),
      (true, true),
      reason: 'the folder after a restart',
    );
    await app.back();
    await app.showTab(0);
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('受け取ったもののフォルダの中も、共有の並び順で並ぶ', (tester) async {
    final app = _App(tester);
    await app.open(prefs: const {'home.sharedViewMode.v1': 'detail'});
    await app.seedSharedFolder();
    await app.showTab(2);
    // 既定は更新日時の新しい順。
    expect(await app.sharedFolderOrder(), ['Banana', 'Apple']);
    app.sortIn(SharedScreen).onSortByNameChanged(true);
    await app.frames(4);
    app.sortIn(SharedScreen).onToggleDirection();
    await app.frames(4);
    expect(await app.sharedFolderOrder(), ['Apple', 'Banana']);
    // 起動し直しても、フォルダの中は覚えた並び順。
    await app.showTab(0);
    await app.restart();
    await app.showTab(2);
    expect(await app.sharedFolderOrder(), ['Apple', 'Banana']);
    await app.showTab(0);
    expect(tester.takeException(), isNull);
    await app.close();
  });

  test('保存できなかった項目はエラーの記録に残し、次に選び直したときに書き直す', () async {
    final previous = SharedPreferencesStorePlatform.instance;
    final store = _RejectingStore();
    SharedPreferencesStorePlatform.instance = store;
    SharedPreferences.resetStatic();
    addTearDown(() {
      SharedPreferencesStorePlatform.instance = previous;
      SharedPreferences.resetStatic();
    });
    final settings = SettingsService();
    await settings.init();
    Future<Object?> stored(String key) async =>
        (await store.getAll())['flutter.$key'];

    store.rejected.add('flutter.home.worksSortMode.v1');
    final errors = AppErrorReporter.recentErrors.length;
    await settings.updateHomeListFilters(HomeList.works, sort: 'nameAsc');
    expect(await stored('home.worksSortMode.v1'), isNull);
    expect(
      AppErrorReporter.recentErrors.length,
      errors + 1,
      reason: 'a refused write is recorded',
    );
    // 開いている間は選んだまま。
    expect(settings.homeListFilters(HomeList.works).sort, 'nameAsc');

    // 次に（別の項目を）選び直したときに、書けなかった項目も書く。
    store.rejected.clear();
    await settings.updateHomeListFilters(HomeList.works, favoritesOnly: true);
    expect(await stored('home.worksFavoritesOnly.v1'), isTrue);
    expect(await stored('home.worksSortMode.v1'), 'nameAsc');

    // 書けた後は、変えていない項目を書き直さない。
    store.rejected.add('flutter.home.worksSortMode.v1');
    await settings.updateHomeListFilters(HomeList.works, favoritesOnly: false);
    expect(await stored('home.worksFavoritesOnly.v1'), isFalse);
    expect(AppErrorReporter.recentErrors.length, errors + 1);
    settings.dispose();
  });

  test('覚えるキーの無い（前の版の）ファイルを読み込んでも、この端末の値は残る', () async {
    const thisDevice = <String, Object>{
      'home.projectFavoritesOnly.v1': true,
      'home.worksSortMode.v1': 'nameAsc',
      'home.worksFavoritesOnly.v1': true,
      'home.sharedSortMode.v1': 'updatedAsc',
      'home.sharedFavoritesOnly.v1': true,
      'home.trashSortMode.v1': 'nameDesc',
      'home.trashHiddenKinds.v1': ['exportedWork'],
    };
    SharedPreferences.setMockInitialValues(thisDevice);
    await NiatraSerializer.restoreLocalPreferences(
      NiatraData({
        'localPreferences': {'home.projectSortMode.v1': 'nameAsc'},
      }, Archive()),
    );
    final prefs = await SharedPreferences.getInstance();
    expect({
      for (final key in thisDevice.keys) key: prefs.get(key),
    }, thisDevice);
    expect(prefs.get('home.projectSortMode.v1'), 'nameAsc');
  });

  test('覚えるキーは設定として移し、この端末の記録にはしない', () {
    for (final key in _keys) {
      expect(
        NiatraSerializer.settingKeys.contains(key) ||
            NiatraSerializer.settingListKeys.contains(key),
        isTrue,
        reason: key,
      );
      expect(NiatraSerializer.deviceRecordKeys, isNot(contains(key)));
    }
  });
}
