// 打つ欄の無い確認のダイアログ（キャンバス・タイムラインの「プロジェクト一覧へ
// 戻る」、ゴミ箱へ移す・完全に削除する確認）も、狭い画面で題・本文・ボタンの
// 名前を語の途中で折らない（DISC189）。
//
// 320px・文字2倍の仏語で、キャンバスの「プロジェクト一覧へ戻る」の確認の
// ボタンが「Revenir sans enregistre / r」「Enregistre / r et revenir」と語の
// 途中で折れていた。ダイアログが画面の左右に既定の40pxずつ空けるので、
// 320pxの画面ではMaterialの最小の幅（280px）より狭い240pxになり、縦に並べた
// ボタンにも1つの語（「enregistrer」）が入らなかった（DISC172の保存の
// ダイアログと同じ原因）。打つ欄のあるダイアログと同じく、最小の幅が取れる
// ところまで左右の空きを縮める。
//
// ダイアログはMaterialの最小の幅（280px）を、画面の左右に16pxずつ残せる限り
// 取る。7言語×320/360/412px×文字1.0/1.3/2.0で、その幅に入る語が途中で
// 折れないこと、はみ出さないことを見張る。広い画面（360px以上）では、
// ダイアログの左右の空きは今までどおり（40px）。「プロジェクト一覧へ戻る」の
// 確認の題・本文・ボタンは普通の`Text`で、韓国語の語は音節の間で折れる
// （アプリ全体の決まりを待っている別の件、DISC111）ので、そこだけは数えない。
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/timeline/timeline_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/project_trash_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/word_breaks.dart';

const _height = 740.0;

/// Materialのダイアログの最小の幅・画面の左右に残す空きの下限と既定。
const _minDialogWidth = 280.0;
const _screenMargin = 16.0;
const _usualMargin = 40.0;

/// 幅[width]の画面で、ダイアログが少なくとも取れる幅（最小の幅280pxを、
/// 左右に16pxずつ残せる限り。広い画面では既定の空き40pxを除いた幅）。
double _dialogRoom(double width) {
  final usual = width - 2 * _usualMargin;
  final widest = width - 2 * _screenMargin;
  final room = usual > _minDialogWidth ? usual : _minDialogWidth;
  return room < widest ? room : widest;
}

/// 開いているダイアログ（[AlertDialog]の面）の幅。
double _dialogWidth(WidgetTester tester) => tester
    .getRect(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(Material),
          )
          .first,
    )
    .width;

final RegExp _hangul = RegExp(r'[\uAC00-\uD7A3\u1100-\u11FF\u3130-\u318F]');

/// 開いているダイアログを、幅と文字の大きさを変えながら調べる。ダイアログが
/// 取れる幅より狭く描かれているときは、その差だけ広い欄で入る語を数える。
/// [korean]が偽なら、韓国語の語が音節の間で折れるのは数えない（普通の`Text`の
/// 文。アプリ全体の決まりを待っている別の件、DISC111）。
Future<List<String>> _sweep(
  WidgetTester tester,
  String where, {
  bool korean = true,
}) async {
  final problems = <String>[];
  final errors = <String>[];
  final onError = FlutterError.onError;
  FlutterError.onError = (d) => errors.add(d.exceptionAsString());
  try {
    for (final width in [320.0, 360.0, 412.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        tester.view.physicalSize = Size(width, _height);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final at = '$where ${width.toInt()}px x$scale';
        final dialog = find.byType(AlertDialog);
        expect(dialog, findsOneWidget, reason: at);
        final missing = math.max(
          0.0,
          _dialogRoom(width) - _dialogWidth(tester),
        );
        for (final paragraph in textParagraphsIn(dialog)) {
          for (final broken in wordsBrokenThatFit(
            paragraph,
            fitWidth: paragraph.constraints.maxWidth + missing,
          )) {
            final word = RegExp(r'「([^」]*)」').firstMatch(broken)?.group(1);
            if (!korean && _hangul.hasMatch(word ?? '')) continue;
            problems.add('$at: $broken');
          }
        }
        for (final error in errors) {
          problems.add('$at: $error');
        }
        errors.clear();
      }
    }
  } finally {
    FlutterError.onError = onError;
  }
  tester.view.physicalSize = const Size(360, _height);
  tester.platformDispatcher.clearTextScaleFactorTestValue();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return problems;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;
  var fontsLoaded = false;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_narrow_dialog_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
    binding.platformDispatcher.clearTextScaleFactorTestValue();
  });

  Future<void> fonts(WidgetTester tester) async {
    if (fontsLoaded) return;
    await loadAppFonts(tester);
    fontsLoaded = true;
  }

  Future<void> settle(WidgetTester tester, [int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// [language]のアプリで作品を1つ作り、[route]（`/canvas/` か
  /// `/timeline/`）で開く。
  Future<void> openProject(
    WidgetTester tester,
    String language,
    String route,
  ) async {
    await fonts(tester);
    tester.view.physicalSize = const Size(360, _height);
    tester.view.devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'language': language,
    });
    appRouter.go('/home');
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await settle(tester, 4);
    final service = tester
        .element(find.byType(HomeScreen))
        .read<ProjectService>();
    final project = (await tester.runAsync(
      () => service.createProject(
        name: 'Storyboard',
        fps: 2,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 160,
        exportHeight: 90,
      ),
    ))!;
    appRouter.push('$route${project.id}');
    await settle(tester, 10);
  }

  Future<void> closeDialog(WidgetTester tester, AppLocalizations l10n) async {
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(l10n.commonCancel),
      ),
    );
    for (
      var i = 0;
      i < 20 && find.byType(AlertDialog).evaluate().isNotEmpty;
      i++
    ) {
      await settle(tester, 1);
    }
    expect(find.byType(AlertDialog), findsNothing);
  }

  void report(List<String> problems) {
    for (final problem in problems.take(12)) {
      debugPrint(problem);
    }
    expect(problems, isEmpty, reason: '${problems.length} problems');
  }

  for (final locale in AppLocalizations.supportedLocales) {
    final tag = locale.toLanguageTag();
    final language = tag.replaceAll('-', '_');
    final l10n = lookupAppLocalizations(locale);

    for (final (name, route, screen) in [
      ('canvas', '/canvas/', CanvasScreen),
      ('timeline', '/timeline/', TimelineScreen),
    ]) {
      testWidgets('the $name back-to-projects question keeps its words whole '
          '($tag)', (tester) async {
        await openProject(tester, language, route);
        expect(find.byType(screen), findsOneWidget);
        await tester.tap(
          find.byTooltip(l10n.timelineBackToProjectListTooltip).first,
        );
        await settle(tester, 3);
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(l10n.timelineBackToProjectListDialogTitle),
          ),
          findsOneWidget,
        );
        // 題・本文・ボタンは普通のTextなので、韓国語の語の音節の間の折り返しは
        // 数えない（DISC111）。
        final problems = await _sweep(tester, name, korean: false);
        await closeDialog(tester, l10n);
        report(problems);
        await tester.pumpWidget(const SizedBox.shrink());
        appRouter.go('/');
      });
    }

    testWidgets('the trash questions keep their words whole ($tag)', (
      tester,
    ) async {
      await fonts(tester);
      tester.view.physicalSize = const Size(360, _height);
      tester.view.devicePixelRatio = 1;
      final host = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          theme: ThemeService().themeDataFor(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(key: host, body: const SizedBox.expand()),
        ),
      );
      final context = host.currentContext!;
      final problems = <String>[];
      final korean = locale.languageCode == 'ko';
      final names = korean
          ? ['애니메이션 연습', '애니메이션 연습 2']
          : ['Storyboard practice', 'Storyboard practice 2'];
      for (final (where, title, message, confirm) in [
        (
          'move to trash',
          l10n.homeMoveToTrash,
          '${l10n.homeMoveToTrashConfirm(2)}\n'
              '${l10n.homeMoveToTrashFolderContents(l10n.homeFolderContents(2, 1))}',
          l10n.homeMoveToTrash,
        ),
        (
          'delete for good',
          l10n.homePermanentDeleteConfirmTitle,
          l10n.homePermanentDeleteConfirmBody,
          l10n.commonDelete,
        ),
      ]) {
        showDialog<void>(
          context: context,
          builder: (_) => ProjectTrashDialog(
            title: title,
            message: message,
            confirmLabel: confirm,
            itemNames: names,
            onApply: () async {},
          ),
        );
        await tester.pumpAndSettle();
        problems.addAll(await _sweep(tester, where));
        await tester.tap(find.byKey(const Key('trash-dialog-cancel')));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
      }
      report(problems);
    });
  }

  // 広い画面では、ダイアログの形（左右の空き）は今までのまま（狭い画面だけ
  // 空きを縮める）。
  testWidgets('a wide screen keeps the usual dialog margins', (tester) async {
    await openProject(tester, 'fr', '/canvas/');
    final l10n = lookupAppLocalizations(const Locale('fr'));
    await tester.tap(
      find.byTooltip(l10n.timelineBackToProjectListTooltip).first,
    );
    await settle(tester, 3);
    for (final width in [360.0, 412.0]) {
      for (final scale in [1.0, 2.0]) {
        tester.view.physicalSize = Size(width, _height);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final dialog = tester.getRect(
          find
              .descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(dialog.left, greaterThanOrEqualTo(_usualMargin - 0.5));
        expect(dialog.right, lessThanOrEqualTo(width - _usualMargin + 0.5));
        // 上下の空きも既定のまま（キーボードの無いダイアログ）。
        expect(dialog.top, greaterThanOrEqualTo(24 - 0.5));
      }
    }
    // 320pxでは、最小の幅（280px）を取る。
    tester.view.physicalSize = const Size(320, _height);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_dialogWidth(tester), closeTo(_minDialogWidth, 0.5));
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await closeDialog(tester, l10n);
    await tester.pumpWidget(const SizedBox.shrink());
    appRouter.go('/');
  });
}
