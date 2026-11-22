// キャンバスの「設定/編集」メニューの項目名が、語の途中で折れず、行内に収まることを確認する（DISC190）。
//
// フランス語・スペイン語の「自動操作」は、所有者の決定に従って「Macros」に統一。
// 旧訳の長い単語が入らない条件を除外する例外は設けず、見出しそのものの幅を
// 7言語×320/360/412px×文字倍率1.0/1.3/2.0の全条件で検査する。
//
// メニュー内の他の項目名・説明も、表示領域に収まる語を途中で折らないこと、
// はみ出さないことを検査する。無料利用者には自動操作行の鍵アイコンが表示され、
// プレミアム利用者には表示されないことも確認する。
//
// 韓国語の語も、入る幅では音節の途中で折らないことを検査する。
// 旧訳の幅超過を理由に検査対象から外す例外は設けない。
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/word_breaks.dart';

const _height = 740.0;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;
  var fontsLoaded = false;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_menu_words_');
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

  Future<void> settle(WidgetTester tester, [int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// [language]のアプリで作品を1つ作ってキャンバスを開き、「設定/編集」の
  /// メニューを開く。
  Future<void> openMenu(WidgetTester tester, String language) async {
    if (!fontsLoaded) {
      await loadAppFonts(tester);
      fontsLoaded = true;
    }
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
    appRouter.push('/canvas/${project.id}');
    await settle(tester, 10);
    expect(find.byType(CanvasScreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.settings));
    await settle(tester, 3);
    expect(find.byType(BottomSheet), findsOneWidget);
  }

  /// 段落[p]の入った行（ListTile）で、項目名が使える幅：段落の左端から、
  /// 行の終わりの余白まで（行の右に置いた印・ボタンを下へ回せば使える幅）。
  double labelRoom(WidgetTester tester, RenderParagraph p) {
    final element = find
        .byElementPredicate((e) => e.widget is RichText && e.renderObject == p)
        .evaluate()
        .single;
    ListTile? tile;
    Element? tileElement;
    element.visitAncestorElements((ancestor) {
      if (ancestor.widget is ListTile) {
        tile = ancestor.widget as ListTile;
        tileElement = ancestor;
        return false;
      }
      return true;
    });
    final left = p.localToGlobal(Offset.zero).dx;
    if (tile == null) return p.constraints.maxWidth;
    final box = tileElement!.renderObject! as RenderBox;
    final right = box.localToGlobal(Offset(box.size.width, 0)).dx;
    final padding =
        (tile!.contentPadding ??
                ListTileTheme.of(tileElement!).contentPadding ??
                const EdgeInsetsDirectional.only(start: 16, end: 24))
            .resolve(TextDirection.ltr);
    return right - padding.right - left;
  }

  for (final locale in AppLocalizations.supportedLocales) {
    final tag = locale.toLanguageTag();
    final language = tag.replaceAll('-', '_');
    final l10n = lookupAppLocalizations(locale);

    testWidgets('the canvas edit menu keeps its words whole ($tag)', (
      tester,
    ) async {
      if (tag == 'fr' || tag == 'es') {
        expect(l10n.customAutomationTitle, 'Macros', reason: tag);
      }
      await openMenu(tester, language);
      final premium = tester
          .element(find.byType(CanvasScreen))
          .read<PremiumService>();
      final locked = !premium.isFeatureAvailable(
        PremiumFeature.customAutomation,
      );
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
            final at = '${width.toInt()}px x$scale';
            final sheet = find.byType(BottomSheet);
            expect(sheet, findsOneWidget, reason: at);
            // 一番下の項目まで、スクロールしながら全部の行を見る。
            final scrollable = find
                .descendant(of: sheet, matching: find.byType(Scrollable))
                .first;
            final position = tester.state<ScrollableState>(scrollable).position;
            final seen = <String>{};
            for (var offset = 0.0; ; offset += 200) {
              position.jumpTo(math.min(offset, position.maxScrollExtent));
              await tester.pump();
              for (final paragraph in textParagraphsIn(sheet)) {
                final room = labelRoom(tester, paragraph);
                for (final broken in wordsBrokenThatFit(
                  paragraph,
                  fitWidth: math.max(room, paragraph.constraints.maxWidth),
                )) {
                  seen.add('$at: $broken');
                }
              }
              if (offset >= position.maxScrollExtent) break;
            }
            problems.addAll(seen);
            // 自動操作の行には、無料の利用者には鍵の印がある。
            position.jumpTo(0);
            await tester.pump();
            final automation = find.descendant(
              of: sheet,
              matching: find.text(l10n.customAutomationTitle),
            );
            await tester.ensureVisible(automation);
            await tester.pump();
            final row = find.ancestor(
              of: automation,
              matching: find.byType(ListTile),
            );
            // 1つの語が、項目名の使える幅より広いとき（どう並べても1行に
            // 入らない。短い訳に替える、所有者の判断、2026-11-22、DISC155）。
            final title = tester.renderObject<RenderParagraph>(
              find.descendant(of: automation, matching: find.byType(RichText)),
            );
            final word = title.getMinIntrinsicWidth(double.infinity);
            final room = labelRoom(tester, title);
            expect(
              word,
              lessThanOrEqualTo(room + 0.5),
              reason:
                  '$tag $at: 「${l10n.customAutomationTitle}」 must fit '
                  'within the menu row',
            );
            expect(
              find.descendant(
                of: row.first,
                matching: find.byIcon(Icons.lock_outline),
              ),
              locked ? findsOneWidget : findsNothing,
              reason: '$at: the lock of the automations row',
            );
            position.jumpTo(0);
            await tester.pump();
            for (final error in errors) {
              problems.add('$at: $error');
            }
            errors.clear();
          }
        }
      } finally {
        FlutterError.onError = onError;
      }
      for (final problem in problems.take(12)) {
        debugPrint(problem);
      }
      expect(problems, isEmpty, reason: '${problems.length} problems');
      await tester.pumpWidget(const SizedBox.shrink());
      appRouter.go('/');
    });
  }
}
