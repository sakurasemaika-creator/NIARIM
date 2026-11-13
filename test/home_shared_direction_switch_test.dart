import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/export_storage.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

// 共有タブの「受け取ったもの／自分が作成したもの」の切り替え（所有者の判断3）。
// 2つの名前が元の大きさのまま入る幅では文字、入らない幅ではアイコンだけにし、
// 文字を縮めない。アイコンのときも長押し・ホバーで元の名前を出し、読み上げの
// 名前は元の名前のまま。本物のアプリを起動処理から組み立てて確かめる。

const _languages = ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant'];

// 受け取ったもの（受信トレイ）・自分が作成したもの（送信トレイ）。
const _receivedIcon = Icons.move_to_inbox_outlined;
const _outgoingIcon = Icons.outbox_outlined;

final _switch = find.byKey(const Key('sharedDirectionSegmentedControl'));

Future<void> _frames(WidgetTester tester, [int count = 6]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _settleIo(WidgetTester tester, [int rounds = 3]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  await _frames(tester, 3);
}

Future<SettingsService> _openShared(
  WidgetTester tester, {
  Size size = const Size(1280, 800),
  double scale = 1,
}) async {
  await loadAppFonts(tester);
  SharedPreferences.setMockInitialValues({
    'first_launch': false,
    'language': 'ja',
    'force_pc_mode': 0,
    firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
  });
  final dir = Directory.systemTemp.createTempSync('home-shared-switch-');
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(channel, (_) async => dir.path);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    try {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } on FileSystemException {
      // 後始末の途中で保存が走っていても、テストの結果は変えない。
    }
  });
  ExportStorage.invalidate();
  Directory('${dir.path}/exports').createSync();
  await tester.runAsync(
    () => ExportEngine.listExportedFiles(forceRefresh: true),
  );
  appRouter.go('/home');
  final providers = await tester.runAsync(buildAppProviders);
  await tester.pumpWidget(
    MultiProvider(providers: providers!, child: const NiarimApp()),
  );
  await _frames(tester);
  await _settleIo(tester);
  tester.widget<TabBarView>(find.byType(TabBarView)).controller!.animateTo(2);
  await _frames(tester, 8);
  await _settleIo(tester, 2);
  return tester.element(find.byType(HomeScreen)).read<SettingsService>();
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(HomeScreen)))!;

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 100));
}

Set<bool> _selected(WidgetTester tester) =>
    tester.widget<SegmentedButton<bool>>(_switch).selected;

/// 切り替えを縮めて描いているか（描いた幅÷本来の幅）。
double _drawnScale(WidgetTester tester) {
  final box = tester.renderObject<RenderBox>(_switch);
  return tester.getRect(_switch).width / box.size.width;
}

/// 切り替えの中に、元の名前が切れずに1行で描かれているか。
List<String> _cutLabels(WidgetTester tester, List<String> names) {
  final cut = <String>[];
  for (final name in names) {
    final text = find.descendant(of: _switch, matching: find.text(name));
    if (text.evaluate().length != 1) {
      cut.add('$name missing');
      continue;
    }
    final paragraph = tester.renderObject<RenderParagraph>(text);
    if (paragraph.didExceedMaxLines ||
        paragraph.getMaxIntrinsicWidth(double.infinity) >
            paragraph.size.width + 0.5) {
      cut.add('$name cut');
    }
  }
  return cut;
}

/// 画面の読み上げの部品（親へまとめられたものは親で数える）のうち、
/// ラベルかツールチップに[name]を含むもの。
List<String> _semanticsNaming(WidgetTester tester, String name) {
  final found = <String>[];
  void visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    if (!node.isMergedIntoParent &&
        (data.label.contains(name) || data.tooltip.contains(name))) {
      found.add('label="${data.label}" tooltip="${data.tooltip}"');
    }
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(tester.getSemantics(find.byType(HomeScreen)));
  return found;
}

bool _showsIcons(WidgetTester tester) =>
    find
        .descendant(of: _switch, matching: find.byIcon(_receivedIcon))
        .evaluate()
        .isNotEmpty &&
    find
        .descendant(of: _switch, matching: find.byIcon(_outgoingIcon))
        .evaluate()
        .isNotEmpty;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the switch keeps full-size names where they fit and shows '
      'icons where they do not, without shrinking (7 languages)', (
    tester,
  ) async {
    final settings = await _openShared(tester);
    final problems = <String>[];
    final textCells = <String>[];
    final iconCells = <String>[];
    for (final language in _languages) {
      await tester.runAsync(() => settings.setLanguage(language));
      for (final width in [320.0, 360.0, 1280.0]) {
        for (final scale in [1.0, 1.3, 2.0]) {
          tester.view.physicalSize = Size(width, 800);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          await _frames(tester, 3);
          final where = '$language ${width.round()} x$scale';
          final l10n = _l10n(tester);
          final names = [
            l10n.homeSharedReceivedFilter,
            l10n.homeSharedCreatedFilter,
          ];
          final drawn = _drawnScale(tester);
          if (drawn < 0.999) {
            problems.add('$where drawn at ${(drawn * 100).round()}%');
          }
          if (_showsIcons(tester)) {
            iconCells.add(where);
            for (final name in names) {
              // 文字は出さない（縮めた文字・切れた文字を出さない）。
              if (find
                  .descendant(of: _switch, matching: find.text(name))
                  .evaluate()
                  .isNotEmpty) {
                problems.add('$where shows "$name" next to the icons');
              }
              final tips = find.descendant(
                of: _switch,
                matching: find.byWidgetPredicate(
                  (w) => w is Tooltip && w.message == name,
                ),
              );
              if (tips.evaluate().length != 1) {
                problems.add('$where has no tooltip "$name"');
              }
            }
          } else {
            textCells.add(where);
            for (final cut in _cutLabels(tester, names)) {
              problems.add('$where $cut');
            }
          }
          final error = tester.takeException();
          if (error != null) problems.add('$where $error');
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
    // 広い画面（PC）では、どの言語・文字の大きさでも文字で出す。
    for (final language in _languages) {
      for (final scale in [1.0, 1.3, 2.0]) {
        expect(textCells, contains('$language 1280 x$scale'));
      }
      // 幅320px・文字2倍はどの言語でも2つの名前が並ばない。
      expect(iconCells, contains('$language 320 x2.0'));
    }
    await _close(tester);
  });

  testWidgets('as icons, the original names show on long press and hover, '
      'stay the screen-reader names, and the choice survives resizing', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _openShared(tester);
    final l10n = _l10n(tester);
    final received = l10n.homeSharedReceivedFilter;
    final created = l10n.homeSharedCreatedFilter;
    // 広い画面で「自分が作成したもの」を選んでから、狭く・文字を大きくする。
    expect(_cutLabels(tester, [received, created]), isEmpty);
    await tester.tap(find.byKey(const Key('sharedOutgoingFilter')));
    await _settleIo(tester);
    expect(_selected(tester), {true});
    tester.view.physicalSize = const Size(320, 800);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await _frames(tester, 4);
    expect(_showsIcons(tester), isTrue);
    expect(_selected(tester), {true});
    expect(find.text(l10n.sharedArchiveEmpty), findsOneWidget);

    // 読み上げの名前は元の名前。
    final outgoingIcon = find.descendant(
      of: _switch,
      matching: find.byIcon(_outgoingIcon),
    );
    final receivedIcon = find.descendant(
      of: _switch,
      matching: find.byIcon(_receivedIcon),
    );
    expect(tester.getSemantics(outgoingIcon).getSemanticsData().label, created);
    expect(
      tester.getSemantics(receivedIcon).getSemanticsData().label,
      received,
    );
    // 名前は1度だけ渡す。ラベルとツールチップの両方に入れると、読み上げが
    // 名前を2度読む（Android 9より前のTalkBackは2つをつないで読む）。
    for (final name in [received, created]) {
      expect(_semanticsNaming(tester, name), [
        'label="$name" tooltip=""',
      ], reason: name);
    }

    // 長押しで元の名前を出す（押しても切り替わらない）。
    expect(find.text(created), findsNothing);
    await tester.longPress(outgoingIcon);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(created), findsOneWidget);
    expect(_selected(tester), {true});
    await tester.pump(const Duration(seconds: 3));
    await _frames(tester, 4);
    expect(find.text(created), findsNothing);

    // マウスを重ねても元の名前を出す。
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(receivedIcon));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(received), findsOneWidget);
    await mouse.moveTo(Offset.zero);
    await tester.pump(const Duration(seconds: 1));
    await _frames(tester, 4);

    // アイコンを押せば切り替わり、広い画面へ戻しても選んだまま。
    await tester.tap(receivedIcon);
    await _settleIo(tester);
    expect(_selected(tester), {false});
    expect(find.text(l10n.homeSharedEmpty), findsOneWidget);
    tester.view.physicalSize = const Size(1280, 800);
    tester.platformDispatcher.textScaleFactorTestValue = 1;
    await _frames(tester, 4);
    expect(_showsIcons(tester), isFalse);
    expect(_selected(tester), {false});
    expect(_cutLabels(tester, [received, created]), isEmpty);
    expect(tester.takeException(), isNull);
    semantics.dispose();
    await _close(tester);
  });

  testWidgets('as icons, the switch is reachable and usable by keyboard', (
    tester,
  ) async {
    await _openShared(tester, size: const Size(320, 800), scale: 2);
    expect(_showsIcons(tester), isTrue);
    expect(_selected(tester), {false});
    final outgoing = find.descendant(
      of: _switch,
      matching: find.ancestor(
        of: find.byIcon(_outgoingIcon),
        matching: find.byType(TextButton),
      ),
    );
    bool focusInside() {
      final focused = FocusManager.instance.primaryFocus?.context;
      if (focused == null) return false;
      final target = outgoing.evaluate().single;
      if (focused == target) return true;
      var inside = false;
      focused.visitAncestorElements((element) {
        inside = element == target;
        return !inside;
      });
      return inside;
    }

    for (var i = 0; i < 60 && !focusInside(); i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(focusInside(), isTrue, reason: 'Tab never reached the icon');
    // フォーカスを表す色が付く（押せる場所が見える）。
    final states = tester.widget<TextButton>(outgoing).statesController!.value;
    expect(states, contains(WidgetState.focused));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settleIo(tester);
    expect(_selected(tester), {true});
    // 一覧が「作成したもの」に替わっても、フォーカスは押したアイコンに
    // 残る（続けて切り替えられる）。
    expect(focusInside(), isTrue, reason: 'the focus left the switch');
    expect(tester.takeException(), isNull);
    await _close(tester);
  });
}
