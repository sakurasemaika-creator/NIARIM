import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/save_tree/save_tree_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// セーブツリーの画面のスロットの表示（今の画面の道順からは開かないが、
/// 開いたときも正しく動くこと）：スロットへの保存に失敗したら、保存の管理の
/// 画面のダイアログと同じく、ダイアログを開いたまま中に失敗を出し、打った
/// メモを残す（以前はcatchが無く、何も出なかった）。保存の一覧を読めない
/// 間は、空に見えるスロットに「＋」（ここへ保存）ではなく読めなかった印を
/// 出す。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('niarim_slot_view_failure_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => dir.path);
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
  });

  tearDown(() {
    IOOverrides.global = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  // ファイルの読み書きのような本物の非同期の処理を実時間で待つ。
  Future<void> settleIo(WidgetTester tester, [int rounds = 8]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// セーブツリーの画面（スロットの表示）を開く。
  Future<({SaveTreeService saves, String id})> open(
    WidgetTester tester, {
    String? projectId,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    final navKey = GlobalKey<NavigatorState>();
    late ProjectService projects;
    late SaveTreeService saves;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (context) {
            projects = context.read<ProjectService>();
            saves = context.read<SaveTreeService>();
            return MaterialApp(
              navigatorKey: navKey,
              theme: context.watch<ThemeService>().themeData,
              locale: const Locale('ja'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const Scaffold(body: SizedBox.shrink()),
            );
          },
        ),
      ),
    );
    saves.setTreeMode(false);
    final id =
        projectId ??
        (await tester.runAsync(
          () => projects.createProject(
            name: '保存',
            fps: 2,
            durationSeconds: 1,
            backgroundColor: 0xFFFFFFFF,
            exportWidth: 64,
            exportHeight: 36,
          ),
        ))!.id;
    navKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => SaveTreeScreen(projectId: id)),
    );
    await settleIo(tester, 4);
    return (saves: saves, id: id);
  }

  Finder dialogField() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextField),
  );

  Finder dialogSave() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.widgetWithText(FilledButton, '保存'),
  );

  testWidgets('a failed slot save keeps the dialog open with the failure and '
      'the memo, and saving again works', (tester) async {
    final s = await open(tester);
    // 保存の置き場所をファイルにして、保存が必ず失敗するようにする。
    final blocker = File('${dir.path}/niarim/projects/${s.id}/SaveTree');
    await tester.runAsync(() async => blocker.writeAsStringSync(''));

    await tester.tap(find.byTooltip('このスロットへ保存').first);
    await settleIo(tester, 3);
    await tester.enterText(dialogField(), '線画まで');
    await tester.tap(dialogSave());
    await settleIo(tester, 10);

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byKey(const Key('saveSlotDialogFailure')),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('保存に失敗しました'), findsOneWidget);
    expect(tester.widget<TextField>(dialogField()).controller!.text, '線画まで');
    expect(s.saves.getNodes(s.id), isEmpty);
    expect(tester.takeException(), isNull);

    // 置き場所を直してもう一度押すと、打ったメモのまま保存できる。
    await tester.runAsync(() async => blocker.deleteSync());
    await tester.tap(dialogSave());
    await settleIo(tester, 10);
    expect(find.byType(AlertDialog), findsNothing);
    expect(s.saves.getNodes(s.id).single.comment, '線画まで');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a slot save that fails after the dialog was closed tells the '
      'failure on the screen', (tester) async {
    final s = await open(tester);
    final blocker = File('${dir.path}/niarim/projects/${s.id}/SaveTree');
    await tester.runAsync(() async => blocker.writeAsStringSync(''));

    await tester.tap(find.byTooltip('このスロットへ保存').first);
    await settleIo(tester, 3);
    await tester.enterText(dialogField(), '線画まで');
    await tester.tap(dialogSave());
    // 保存が終わる前に閉じる。
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'キャンセル'),
      ),
    );
    await settleIo(tester, 10);

    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.textContaining('保存に失敗しました'),
      ),
      findsOneWidget,
    );
    expect(s.saves.getNodes(s.id), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('while the save list is unread, empty slots do not show the '
      'plus (save here) picture', (tester) async {
    // 前の起動で保存の一覧を書いた作品。この起動では一覧を読めない。
    final projects = ProjectService();
    final first = SaveTreeService();
    late String id;
    await tester.runAsync(() async {
      await projects.init();
      final project = await projects.createProject(
        name: '保存',
        fps: 2,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 36,
      );
      id = project.id;
      await first.init();
      await first.setSlotMemo(id, 3, 'メモ');
    });
    first.dispose();
    projects.dispose();
    final index =
        '${dir.path}/niarim/projects/$id/SaveTree/'
        '${SaveTreeService.indexFileName}';
    expect(File(index).existsSync(), isTrue);
    IOOverrides.global = _UnreadableFile(index);

    final s = await open(tester, projectId: id);

    expect(s.saves.saveListUnreadable(id), isTrue);
    expect(find.byKey(const Key('saveListLoadFailed')), findsOneWidget);
    expect(find.byIcon(Icons.add), findsNothing);
    // 知らせの1つと、見えているスロットの絵。
    expect(find.byIcon(Icons.folder_off_outlined), findsAtLeast(3));
    expect(tester.takeException(), isNull);
  });
}

/// 1つのファイルだけを開けないように見せる（端末では、権限の無いファイル・
/// 入出力の失敗で起きる）。
final class _UnreadableFile extends IOOverrides {
  _UnreadableFile(this.path);

  final String path;

  @override
  File createFile(String path) {
    final real = super.createFile(path);
    return path == this.path ? _BlockedFile(real) : real;
  }
}

class _BlockedFile implements File {
  _BlockedFile(this._real);

  final File _real;

  PathAccessException get _denied => PathAccessException(
    path,
    const OSError('Permission denied', 13),
    'Cannot open file',
  );

  @override
  String get path => _real.path;
  @override
  Uri get uri => _real.uri;
  @override
  bool get isAbsolute => _real.isAbsolute;
  @override
  File get absolute => _real.absolute;
  @override
  Directory get parent => _real.parent;
  @override
  bool existsSync() => _real.existsSync();
  @override
  Future<bool> exists() => _real.exists();
  @override
  int lengthSync() => _real.lengthSync();
  @override
  Future<int> length() => _real.length();
  @override
  Uint8List readAsBytesSync() => throw _denied;
  @override
  Future<Uint8List> readAsBytes() async => throw _denied;
  @override
  String toString() => _real.toString();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} on a blocked file');
}
