import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/services/export_storage.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'first_use_tooltips.dart';
import 'load_app_fonts.dart';

/// ホームの切り取り・コピー・貼り付けを、本物のアプリ（起動処理と
/// NiarimApp）で動かすテストの道具。保存先は一時フォルダ。
class HomeClipboardHarness {
  HomeClipboardHarness._(this.tester, this.dir, this.projects);

  final WidgetTester tester;

  /// 書類フォルダ（作品・書き出し・ゴミ箱の保存先）。
  final Directory dir;
  final ProjectService projects;

  /// ホームを開く。[language]は表示の言語（'zh_Hant'等）。[exports]の名前の
  /// ファイルを書き出し済みの作品として置いてから起動する。
  static Future<HomeClipboardHarness> open(
    WidgetTester tester, {
    String language = 'ja',
    Size size = const Size(800, 900),
    double textScale = 1,
    bool realFonts = false,
    List<String> exports = const [],
    Map<String, Object> prefs = const {},
  }) async {
    if (realFonts) await loadAppFonts(tester);
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': language,
      'force_pc_mode': 0,
      'home_view_mode': 'medium',
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      ...prefs,
    });
    final dir = Directory.systemTemp.createTempSync('home-clipboard-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => dir.path);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    if (textScale != 1) {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
    }
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      for (var i = 0; i < 5; i++) {
        try {
          if (dir.existsSync()) dir.deleteSync(recursive: true);
          break;
        } on FileSystemException {
          // 保存がまだ書いている。
          sleep(const Duration(milliseconds: 20));
        }
      }
    });
    // 作品一覧は書き出したファイルを本物の読み書きで調べる。先に調べておく
    // （偽の時計の下では終わらず、タブが読み込み中のままになる）。
    ExportStorage.invalidate();
    final exportsDir = Directory('${dir.path}/exports')..createSync();
    for (final name in exports) {
      File('${exportsDir.path}/$name').writeAsBytesSync(List.filled(64, 7));
    }
    await tester.runAsync(
      () => ExportEngine.listExportedFiles(forceRefresh: true),
    );
    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    final harness = HomeClipboardHarness._(
      tester,
      dir,
      tester.element(find.byType(HomeScreen)).read<ProjectService>(),
    );
    await harness.settle();
    return harness;
  }

  AppLocalizations get l10n =>
      AppLocalizations.of(tester.element(find.byType(HomeScreen)))!;

  Future<void> settle() async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  /// 本物のファイルの読み書き（複製・保存・ゴミ箱）を待ってから描く。
  Future<void> settleIo([int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> waitFor(bool Function() done, {String? reason}) async {
    for (var i = 0; i < 100 && !done(); i++) {
      await settleIo(1);
    }
    expect(
      done(),
      isTrue,
      reason: reason ?? 'waited for a state that never came',
    );
  }

  Future<Project> addWork(String name, {String? folderId}) async {
    late Project project;
    await tester.runAsync(() async {
      project = await projects.createProject(
        name: name,
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
      );
      await projects.saveProject(project.id);
      if (folderId != null) await projects.moveToFolder(project.id, folderId);
      await Future<void>.delayed(const Duration(milliseconds: 3));
    });
    await settleIo(2);
    return project;
  }

  Future<ProjectFolder> addFolder(String name, {String? parentId}) async {
    final folder = (await tester.runAsync(
      () => projects.createFolder(name, parentFolderId: parentId),
    ))!;
    await settleIo(2);
    return folder;
  }

  /// 「共有」の「受け取ったもの」に入る作品。
  Future<Project> addReceived(String name, {String? sharedFolderId}) async {
    late Project project;
    await tester.runAsync(() async {
      project = await projects.importSharedProject(
        NiaproData(
          project: Project(
            id: 'source-$name',
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
          scenes: const [],
          tileData: const {},
        ),
      );
      await projects.saveProject(project.id);
      if (sharedFolderId != null) {
        await projects.moveToSharedFolder(project.id, sharedFolderId);
      }
    });
    await settleIo(2);
    return project;
  }

  /// プロジェクトの一覧の、名前が[name]のカード（作品・フォルダ）。
  Finder card(String name) => find.descendant(
    of: find.byType(ProjectListWidget),
    matching: find.text(name),
  );

  /// いま出ている知らせ（SnackBar）の本文。無ければnull。韓国語の語の
  /// 途中で折り返さないために入れた語結合子（U+2060）は除く。
  String? snackText() {
    final texts = find.descendant(
      of: find.byType(SnackBar),
      matching: find.byType(Text),
    );
    if (texts.evaluate().isEmpty) return null;
    return (texts.evaluate().first.widget as Text).data?.replaceAll(
      '\u2060',
      '',
    );
  }

  Finder get pasteButton => find.byKey(const Key('homeCrossTabPasteButton'));
  Finder get clearButton => find.byKey(const Key('homeClearClipboardButton'));

  Future<void> select(Iterable<String> names) async {
    var first = true;
    for (final name in names) {
      // 文字の大きい画面ではカードの列が減り（collectionTileColumnCount）、
      // 押すカードが一覧の下の浮かぶボタンの下にあることがある。一覧を
      // 送って見える所へ出してから押す。
      await tester.ensureVisible(card(name).first);
      await settle();
      if (first) {
        await tester.longPress(card(name).first);
        first = false;
      } else {
        await tester.tap(card(name).first);
      }
      await settle();
    }
  }

  Future<void> copy(Iterable<String> names) async {
    await select(names);
    await tester.tap(find.byTooltip(l10n.commonCopy));
    await settle();
    expect(pasteButton, findsOneWidget);
  }

  Future<void> cut(Iterable<String> names) async {
    await select(names);
    await tester.tap(find.byTooltip(l10n.commonCut));
    await settle();
    expect(pasteButton, findsOneWidget);
  }

  /// 貼り付けを押し、貼り付けが終わる（ボタンがまた押せる・消える）まで待つ。
  Future<void> paste() async {
    await tester.tap(pasteButton);
    await tester.pump();
    await waitFor(() {
      final button = pasteButton.evaluate();
      if (button.isEmpty) return true;
      final widget = tester.widget(pasteButton);
      return widget is ButtonStyleButton
          ? widget.onPressed != null
          : widget is IconButton
          ? widget.onPressed != null
          : true;
    }, reason: 'the paste never finished');
    await settleIo(2);
  }

  Future<void> showTab(int index) async {
    await tester.tap(find.byKey(ValueKey('home_tab_$index')));
    await settleIo(3);
    await settle();
  }

  /// 選択中の操作バーのコピー（どのタブでも同じボタン）。
  Future<void> copySelection() async {
    await tester.tap(find.byTooltip(l10n.commonCopy));
    await settle();
    expect(pasteButton, findsOneWidget);
  }

  /// カード（作品・フォルダ）のメニューを右クリックで開き、[label]を選ぶ。
  Future<void> chooseFromCardMenu(String name, String label) async {
    await tester.tap(card(name).first, buttons: kSecondaryMouseButton);
    await settle();
    await tester.tap(find.text(label).last);
    await tester.pump();
  }

  Future<void> close() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }
}
