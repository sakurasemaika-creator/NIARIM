// 中国語（簡体字・繁体字）の本文をNoto Serif SCで描くようにした（DISC132）後も、
// 字の広くなった画面で文を切らないことを見張る。
//
// Noto Serif SCは白光明朝より漢字（1em：白光明朝は0.65em）もラテン文字も
// 広いので、中国語の画面の文はおよそ1.5倍の幅になる。本物のアプリ
// （NiarimApp：表示言語のテーマ）で開くと、文字の倍率を上げたときに
// ショートカットのキー「Ctrl+Shift+Z」が「Ctrl+S…」、新規作成の大きさの
// 選択肢（「1:1 正方形（适合Twitter/Instagram发布） (1080×1080)」等）が
// 2行で「…」と切れていた。言語なしのテーマ（白光明朝）で描く見張りでは
// 見つからない。保存の画面の空のスロットの「没有存档数据」「沒有存檔資料」も、
// 1行で「…」と切れていた（320px×文字2倍）。
//
// ショートカットのキーのチップは、入らなければ修飾キーの後の「+」の後で
// 折り返す。キーの名前の中（「Ctrl++」のキーの「+」の前、「Arrow Left」の
// 空白）では折り返さない。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/models/shortcut_binding.dart';
import 'package:niarim/router.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/shortcut_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/text_fit_problems.dart';

/// Removes the documents folder a test opened the app on. Writes the app
/// started (settings, the work list) can still be finishing on real I/O when
/// the screen is taken down and add a file while the folder is deleted (CI
/// once failed with "Directory not empty"): try again once they finish.
Future<void> _removeFolder(WidgetTester tester, Directory dir) async {
  for (var attempt = 0; ; attempt++) {
    try {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      return;
    } on FileSystemException {
      if (attempt >= 4) rethrow;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
    }
  }
}

void main() {
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('中国語（簡体字・繁体字）×320/360/412px×文字1.0/1.3/2.0で、ショートカットの'
      'キーと新規作成の大きさの選択肢を切らず、語の途中で折らない', (tester) async {
    await loadAppFonts(tester);
    final problems = <String>[];
    for (final language in const ['zh', 'zh_Hant']) {
      for (final width in const [320.0, 360.0, 412.0]) {
        for (final scale in const [1.0, 1.3, 2.0]) {
          for (final route in const ['/settings/shortcuts', '/new-project']) {
            final where = '$language ${width.round()}px ×$scale $route';
            SharedPreferences.setMockInitialValues({
              'first_launch': false,
              'language': language,
              firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
            });
            final dir = Directory.systemTemp.createTempSync('niarim_zh_fit_');
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .setMockMethodCallHandler(
                  pathChannel,
                  (call) async => dir.path,
                );
            tester.view.physicalSize = Size(width, 760);
            tester.view.devicePixelRatio = 1;
            final errors = <String>[];
            final previous = FlutterError.onError;
            FlutterError.onError = (details) =>
                errors.add(details.exceptionAsString().split('\n').first);
            try {
              final providers = (await tester.runAsync(buildAppProviders))!;
              await tester.pumpWidget(const SizedBox());
              await tester.pumpWidget(
                MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 760),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: MultiProvider(
                    providers: providers,
                    child: const NiarimApp(),
                  ),
                ),
              );
              await tester.pump(const Duration(milliseconds: 500));
              appRouter.go(route);
              for (var i = 0; i < 8; i++) {
                await tester.pump(const Duration(milliseconds: 250));
              }
              final seen = <String>{};
              Future<void> look() async {
                for (final p
                    in tester
                        .renderObjectList<RenderParagraph>(
                          find.byType(RichText),
                        )
                        .where((p) => p.attached && p.hasSize)) {
                  for (final problem in textFitProblems(p)) {
                    final line =
                        '$where: «${p.text.toPlainText().replaceAll('⁠', '').replaceAll('​', '')}» '
                        '$problem';
                    if (seen.add(line)) problems.add(line);
                  }
                }
              }

              // 一覧は下までスクロールしながら見る（画面の外の行は描かれない）。
              final scrollables = find.byType(Scrollable);
              await look();
              for (final element in scrollables.evaluate().toList()) {
                final state = (element as StatefulElement).state;
                if (state is! ScrollableState) continue;
                final position = state.position;
                if (position.axis != Axis.vertical) continue;
                while (position.pixels < position.maxScrollExtent) {
                  position.jumpTo(
                    (position.pixels + position.viewportDimension / 2).clamp(
                      0,
                      position.maxScrollExtent,
                    ),
                  );
                  await tester.pump(const Duration(milliseconds: 100));
                  await look();
                }
              }
            } finally {
              FlutterError.onError = previous;
            }
            for (final e in errors.toSet()) {
              problems.add('$where: $e');
            }
            appRouter.go('/home');
            await tester.pumpWidget(const SizedBox());
            await tester.pump(const Duration(milliseconds: 300));
            await _removeFolder(tester, dir);
          }
        }
      }
    }
    expect(
      problems,
      isEmpty,
      reason: '${problems.length}件\n${problems.join('\n')}',
    );
  }, timeout: const Timeout(Duration(minutes: 10)));

  /// 本物のアプリ（表示言語のテーマ）で[route]を開く。[prepare]は開く前に
  /// 呼ぶ（サービスへ項目を足す・作品を作る）。開いた後、縦の一覧を下まで
  /// スクロールしながら[look]を呼ぶ。
  Future<void> open(
    WidgetTester tester, {
    required String language,
    required double width,
    required double scale,
    required Future<String> Function(BuildContext context) prepare,
    required void Function() look,
  }) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': language,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final dir = Directory.systemTemp.createTempSync('niarim_zh_fit_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => dir.path);
    tester.view.physicalSize = Size(width, 760);
    tester.view.devicePixelRatio = 1;
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: Size(width, 760),
          textScaler: TextScaler.linear(scale),
        ),
        child: MultiProvider(providers: providers, child: const NiarimApp()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    final route = (await tester.runAsync(
      () => prepare(tester.element(find.byType(Navigator).first)),
    ))!;
    appRouter.go(route);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    look();
    for (final element in find.byType(Scrollable).evaluate().toList()) {
      final state = (element as StatefulElement).state;
      if (state is! ScrollableState) continue;
      final position = state.position;
      if (position.axis != Axis.vertical) continue;
      while (position.pixels < position.maxScrollExtent) {
        position.jumpTo(
          (position.pixels + position.viewportDimension / 2).clamp(
            0,
            position.maxScrollExtent,
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        look();
      }
    }
    appRouter.go('/home');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 300));
    await _removeFolder(tester, dir);
  }

  testWidgets('中国語（簡体字・繁体字）×320/360/412px×文字1.0/1.3/2.0で、保存の'
      '画面の空のスロットの「保存データなし」を切らない', (tester) async {
    await loadAppFonts(tester);
    final problems = <String>{};
    for (final language in const ['zh', 'zh_Hant']) {
      for (final width in const [320.0, 360.0, 412.0]) {
        for (final scale in const [1.0, 1.3, 2.0]) {
          final where = '$language ${width.round()}px ×$scale /save-tree';
          await open(
            tester,
            language: language,
            width: width,
            scale: scale,
            prepare: (context) async {
              final project = await context
                  .read<ProjectService>()
                  .createProject(
                    name: 'fit',
                    fps: 12,
                    durationSeconds: 1,
                    backgroundColor: 0xFFFFFFFF,
                  );
              return '/save-tree/${project.id}';
            },
            look: () {
              for (final p
                  in tester
                      .renderObjectList<RenderParagraph>(find.byType(RichText))
                      .where((p) => p.attached && p.hasSize)) {
                for (final problem in textFitProblems(p)) {
                  problems.add('$where: «${p.text.toPlainText()}» $problem');
                }
              }
            },
          );
        }
      }
    }
    expect(
      problems,
      isEmpty,
      reason: '${problems.length}件\n${problems.join('\n')}',
    );
  }, timeout: const Timeout(Duration(minutes: 10)));

  testWidgets('ショートカットのキーは、修飾キーの後の「+」の後でだけ折り返す'
      '（「Ctrl++」のキーの「+」の前、「Arrow Left」の空白では折らない）', (tester) async {
    await loadAppFonts(tester);
    const modifiers = ['Ctrl+', 'Shift+', 'Alt+', 'Meta+'];
    final keys = [
      LogicalKeyboardKey.add,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.numpadAdd,
    ];
    final labels = <String>{};
    final problems = <String>{};
    var wrapped = 0;
    for (final language in const ['zh', 'en']) {
      for (final width in const [320.0, 360.0, 412.0]) {
        for (final scale in const [1.3, 2.0]) {
          final where = '$language ${width.round()}px ×$scale';
          await open(
            tester,
            language: language,
            width: width,
            scale: scale,
            prepare: (context) async {
              final service = context.read<ShortcutService>();
              for (final key in keys) {
                // 修飾キーを4つ・3つ・2つ（長さを変えて、折り返す所を変える）。
                for (final count in const [4, 3, 2]) {
                  final binding = ShortcutBinding(
                    id: 'test_${key.keyId}_$count',
                    label: 'test',
                    keyId: key.keyId,
                    control: true,
                    shift: true,
                    alt: count >= 3,
                    meta: count >= 4,
                    command: ShortcutCommand.undo,
                  );
                  labels.add(binding.comboLabel);
                  service.addBinding(binding);
                }
              }
              return '/settings/shortcuts';
            },
            look: () {
              for (final p
                  in tester
                      .renderObjectList<RenderParagraph>(find.byType(RichText))
                      .where((p) => p.attached && p.hasSize)) {
                final text = p.text.toPlainText();
                String plain(String s) => s
                    .replaceAll('\u200B', '')
                    .replaceAll('\u2060', '')
                    .replaceAll('\u00A0', ' ');
                final label = plain(text);
                if (!labels.contains(label)) continue;
                double widthOf(String part) {
                  final painter = TextPainter(
                    text: TextSpan(text: part, style: p.text.style),
                    textDirection: p.textDirection,
                    textScaler: p.textScaler,
                    locale: p.locale,
                  )..layout();
                  final width = painter.width;
                  painter.dispose();
                  return width;
                }

                // 描かれた幅と、それより狭い幅（折り返してよい所で分けた
                // ひとかたまり〔修飾キー1つ、キーの名前。キーが「+」なら最後の
                // 修飾キーと一緒〕の最も長いものが入る幅から）で、折り返す所を
                // 見る。
                final chunks = <String>[];
                var key = label;
                for (final m in modifiers) {
                  if (!key.startsWith(m)) continue;
                  chunks.add(m);
                  key = key.substring(m.length);
                }
                if (key.startsWith('+') && chunks.isNotEmpty) {
                  chunks.last += key;
                } else {
                  chunks.add(key);
                }
                final narrowest = chunks
                    .map(widthOf)
                    .reduce((a, b) => a > b ? a : b);
                final widths = <double>{
                  p.constraints.maxWidth,
                  for (
                    var w = narrowest.ceilToDouble() + 1;
                    w < p.constraints.maxWidth;
                    w += 2
                  )
                    w,
                };
                for (final maxWidth in widths) {
                  final painter = TextPainter(
                    text: p.text,
                    textDirection: p.textDirection,
                    textScaler: p.textScaler,
                    locale: p.locale,
                  )..layout(maxWidth: maxWidth);
                  final lines = painter.computeLineMetrics();
                  if (maxWidth == p.constraints.maxWidth && lines.length > 1) {
                    wrapped++;
                  }
                  for (var i = 0; i < lines.length - 1; i++) {
                    final end = painter
                        .getLineBoundary(
                          painter.getPositionForOffset(
                            Offset(0, lines[i].baseline - lines[i].ascent + 1),
                          ),
                        )
                        .end;
                    final before = plain(text.substring(0, end)).trimRight();
                    final after = plain(text.substring(end)).trimLeft();
                    // 修飾キーの「+」の後で、次が修飾キーか「+」で始まらない
                    // キーの名前のときだけ折り返してよい。
                    final allowed =
                        modifiers.any(before.endsWith) &&
                        (modifiers.any(
                              (m) => after.startsWith(
                                m.substring(0, m.length - 1),
                              ),
                            ) ||
                            (after == key && !key.startsWith('+')));
                    if (!allowed) {
                      problems.add(
                        '$where: «$label»が«$before»の後で折り返す'
                        '（${maxWidth.round()}px）',
                      );
                    }
                  }
                  painter.dispose();
                }
              }
            },
          );
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
    expect(wrapped, greaterThan(0), reason: '折り返したチップを見ていない');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
