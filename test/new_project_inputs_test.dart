import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/project/new_project_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/utils/app_locale.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// 新規プロジェクトの入力：カスタムサイズの保存のダイアログ、幅・高さ・長さの
/// 数字の欄の範囲外・数字でない入力。
class _RecordingCreation extends ProjectService {
  final created = <({int width, int height, int seconds})>[];

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
  }) {
    created.add((
      width: exportWidth,
      height: exportHeight,
      seconds: durationSeconds,
    ));
    // 作成中のまま止めて、画面に残す。
    return Completer<Project>().future;
  }
}

/// すぐに作り終える作成（呼ばれた回数を数える）。
class _InstantCreation extends ProjectService {
  var calls = 0;

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
  }) async {
    calls++;
    return Project(
      id: 'quick$calls',
      name: name,
      fps: fps,
      durationSeconds: durationSeconds,
      backgroundColor: backgroundColor,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      totalWorkSeconds: 0,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SettingsService> open(
    WidgetTester tester, {
    ProjectService? projects,
  }) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final directory = Directory.systemTemp.createTempSync('new-project-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(420, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = await tester.runAsync(buildAppProviders);
    appRouter.go('/new-project');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ...providers!,
          if (projects != null)
            ChangeNotifierProvider<ProjectService>.value(value: projects),
        ],
        child: const NiarimApp(),
      ),
    );
    await tester.pumpAndSettle();
    return tester
        .element(find.byType(NewProjectScreen))
        .read<SettingsService>();
  }

  Future<void> chooseCustom(WidgetTester tester) async {
    final custom = find.widgetWithText(ChoiceChip, 'カスタム');
    await tester.ensureVisible(custom);
    await tester.tap(custom);
    await tester.pumpAndSettle();
  }

  testWidgets('saving a custom size: no blank names, Enter saves, the '
      'screen keeps working', (tester) async {
    final settings = await open(tester);
    await chooseCustom(tester);
    final save = find.text('このサイズを保存する');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    final field = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, '   ');
    await tester.pump();
    final confirm = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, '保存'),
    );
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(settings.customSizePresets, isEmpty);

    await tester.enterText(field, '  横長  ');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(settings.customSizePresets.single.name, '横長');
    expect(tester.takeException(), isNull);
    // 閉じた後も画面がそのまま使える（以前は閉じる途中で入力欄の
    // コントローラーを破棄し、画面全体がエラーの表示になった）。
    expect(find.text('このサイズを保存する'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(ErrorWidget), findsNothing);
  });

  Finder field(String label) => find.widgetWithText(TextField, label);
  String text(WidgetTester tester, String label) =>
      tester.widget<TextField>(field(label)).controller!.text;
  const sizeError = '64〜1920の数字を入力してください';

  testWidgets('width and height: out of range shows why, leaving the field '
      'shows the size that will be used', (tester) async {
    await open(tester);
    await chooseCustom(tester);
    await tester.enterText(field('幅(px)'), '5000');
    await tester.pump();
    expect(find.text(sizeError), findsOneWidget);
    // 打った値のままでは作れないので、使うのは上限の1920。
    expect(find.textContaining('1920×1080'), findsWidgets);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(text(tester, '幅(px)'), '1920');
    expect(find.text(sizeError), findsNothing);

    // 数字以外は打てない。空にすると理由を出し、前の値のまま。
    await tester.enterText(field('高さ(px)'), 'abc');
    await tester.pump();
    expect(text(tester, '高さ(px)'), '');
    expect(find.text(sizeError), findsOneWidget);
    await tester.enterText(field('高さ(px)'), '10');
    await tester.pump();
    expect(find.text(sizeError), findsOneWidget);
    // 欄から出ると（別の欄を押す）、使う値の64になる。
    await tester.tap(field('幅(px)'));
    await tester.pump();
    expect(text(tester, '高さ(px)'), '64');
    expect(find.text(sizeError), findsNothing);
    expect(find.textContaining('1920×64'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('duration: out of range shows why and snaps back', (
    tester,
  ) async {
    await open(tester);
    final duration = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.suffixText == '秒',
    );
    await tester.ensureVisible(duration);
    await tester.enterText(duration, '0');
    await tester.pump();
    expect(find.textContaining('の数字を入力してください'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(tester.widget<TextField>(duration).controller!.text, '1');
    await tester.enterText(duration, '99999');
    await tester.pump();
    // 4桁まで。上限（無料は90秒、プレミアムは2時間）を超えると理由を出す。
    expect(tester.widget<TextField>(duration).controller!.text, '9999');
    expect(find.textContaining('の数字を入力してください'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(
      tester.widget<TextField>(duration).controller!.text,
      anyOf('90', '7200'),
    );
    expect(find.textContaining('の数字を入力してください'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('creating right after typing uses and shows the clamped size', (
    tester,
  ) async {
    final projects = _RecordingCreation();
    addTearDown(projects.dispose);
    await open(tester, projects: projects);
    await chooseCustom(tester);
    await tester.enterText(field('幅(px)'), '5000');
    await tester.pump();
    final create = find.text('作成');
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pump();
    expect(projects.created.single.width, 1920);
    await tester.ensureVisible(field('幅(px)'));
    expect(text(tester, '幅(px)'), '1920');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the range messages fit a 320px phone at 2x text in every '
      'language', (tester) async {
    final settings = await open(tester);
    tester.view.physicalSize = const Size(320, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    // 横に並べた行が画面からはみ出していないか（例外は1つの行につき
    // 1回しか出ないので、言語ごとに行の幅を直接数える）。
    void expectNoOverflow(String where) {
      void visit(RenderObject object) {
        if (object is RenderFlex &&
            object.direction == Axis.horizontal &&
            object.hasSize) {
          var total = 0.0;
          object.visitChildren((child) {
            if (child is RenderBox && child.hasSize) total += child.size.width;
          });
          expect(
            total,
            lessThanOrEqualTo(object.size.width + 0.5),
            reason: '$where ${object.debugCreator}',
          );
        }
        object.visitChildren(visit);
      }

      visit(tester.renderObject(find.byType(NewProjectScreen)));
    }

    for (final locale in AppLocalizations.supportedLocales) {
      final code = locale.toLanguageTag().replaceAll('-', '_');
      await tester.runAsync(() => settings.setLanguage(code));
      await tester.pumpAndSettle();
      expectNoOverflow('$code presets');
    }
    final custom = find.byWidgetPredicate(
      (w) => w is ChoiceChip && w.selected == false,
    );
    await tester.ensureVisible(custom.last);
    await tester.tap(custom.last);
    await tester.pumpAndSettle();
    for (final locale in AppLocalizations.supportedLocales) {
      final code = locale.toLanguageTag().replaceAll('-', '_');
      await tester.runAsync(() => settings.setLanguage(code));
      await tester.pumpAndSettle();
      expectNoOverflow('$code custom');
      final l10n = appLocalizationsFor(locale);
      final sizeFields = find.byWidgetPredicate(
        (w) => w is TextField && w.inputFormatters != null && w.maxLines == 1,
      );
      await tester.enterText(sizeFields.at(1), '5');
      await tester.pump();
      final message = find.text(l10n.newProjectNumberRangeError(64, 1920));
      expect(message, findsOneWidget, reason: code);
      await tester.ensureVisible(message);
      await tester.pump();
      final rect = tester.getRect(message);
      expect(rect.left, greaterThanOrEqualTo(0), reason: code);
      expect(rect.right, lessThanOrEqualTo(320.5), reason: code);
      expect(tester.takeException(), isNull, reason: code);
      expectNoOverflow('$code error');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
    }
  });

  testWidgets('a second press after a quick creation does not make a second '
      'project while the screen is leaving', (tester) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    tester.view.physicalSize = const Size(420, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = await tester.runAsync(buildAppProviders);
    final projects = _InstantCreation();
    addTearDown(projects.dispose);
    // キャンバスの代わりの画面（作った後の移り先だけを見る）。
    final router = GoRouter(
      initialLocation: '/new-project',
      routes: [
        GoRoute(
          path: '/new-project',
          builder: (_, _) => const NewProjectScreen(),
        ),
        GoRoute(
          path: '/canvas/:id',
          builder: (_, state) =>
              Scaffold(body: Text('canvas ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ...providers!,
          ChangeNotifierProvider<ProjectService>.value(value: projects),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('ja'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final create = find.text('作成');
    await tester.ensureVisible(create);
    await tester.pumpAndSettle();
    final at = tester.getCenter(create);
    // ダブルクリック：作り終えた後、次の画面を描く前に2回目が届く
    // （描くのが遅い端末では、ボタンがまだ押せる見た目のまま残る）。
    await tester.tapAt(at, kind: PointerDeviceKind.mouse);
    await tester.tapAt(at, kind: PointerDeviceKind.mouse);
    await tester.pump();
    await tester.tapAt(at, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(projects.calls, 1);
    expect(find.text('canvas quick1'), findsOneWidget);
  });
}
