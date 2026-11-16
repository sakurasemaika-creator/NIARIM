// 打つ欄のあるダイアログは、キーボードが開いている間、上下の空き（Materialの
// 既定の24pxずつ）を取らない（DISC222）。
//
// 狭い画面の左右の空き（DISC211）は画面ごとの印からまとめて入るが、上下の空きを
// キーボードの間だけ外す`typingDialogInsetPadding`（DISC172）は保存の
// ダイアログにしか渡しておらず、ほかの打つ欄のあるダイアログ（名前を1つ打つ
// `NameEntryDialog`・QRの取り込み・数を打つ欄・ドット絵のパレット・素材の
// タグ等）は、320×568の画面・文字2倍でキーボードが開くと、中身がスクロールして
// 切れているのに上下に24pxずつ空けたままだった。
//
// 本物の部品を開き、7言語×320×568（キーボード260px）×文字2倍で、
// - ダイアログがキーボードの上の見える所に収まる、
// - 中身が切れて（スクロールして）いるのに、ダイアログが上下に空きを残さない、
// - 打っている欄が見える（1行分以上）、
// - はみ出しの例外が出ない、
// ことを見る。あわせて、lib配下（ホームを除く）の打つ欄のあるダイアログが
// `typingDialogInsetPadding`を渡していることをソースで見張る。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/widgets/asset_tag_dialog.dart';
import 'package:niarim/services/pixel_art_palette_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/editable_slider_value.dart';
import 'package:niarim/widgets/name_entry_dialog.dart';
import 'package:niarim/widgets/pixel_art_palette_edit_dialog.dart';
import 'package:niarim/widgets/qr_import_dialog.dart';
import 'package:niarim/widgets/typing_dialog_inset.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';

const _size = Size(320, 568);
const _keyboard = 260.0;

typedef _Opener = void Function(BuildContext context);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var fontsLoaded = false;

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio()
      ..resetViewInsets();
    binding.platformDispatcher.clearTextScaleFactorTestValue();
  });

  /// 開くダイアログ（名前・開き方）。開き方が[EditableSliderValue]を押す
  /// ものは null（画面の上の数を押して開く）。
  final dialogs = <String, _Opener?>{
    'NameEntryDialog': (context) {
      final l10n = AppLocalizations.of(context)!;
      showDialog<void>(
        context: context,
        builder: (_) => NameEntryDialog(
          title: l10n.fontRenameDialogTitle,
          confirmLabel: l10n.commonChange,
          cancelLabel: l10n.commonCancel,
          initialName: 'Croquis',
          labelText: l10n.folderNameLabel,
          onSubmit: (_) async {},
        ),
      );
    },
    'QrImportDialog': (context) {
      showDialog<void>(
        context: context,
        builder: (_) => QrImportDialog(
          title: AppLocalizations.of(context)!.qrImportPasteButton,
          onImport: (_) async => true,
        ),
      );
    },
    'PixelArtPaletteEditDialog': (context) {
      showDialog<void>(
        context: context,
        builder: (_) => const PixelArtPaletteEditDialog(),
      );
    },
    'AssetTagDialog': (context) {
      showAssetTagDialog(
        context,
        assetName: 'Fond',
        currentTags: const ['ciel', 'nuit'],
        suggestions: const ['ville', 'forêt', 'mer'],
        onSave: (_) {},
      );
    },
    'EditableSliderValue': null,
  };

  Future<void> pumpHost(WidgetTester tester, Locale locale) async {
    if (!fontsLoaded) {
      await loadAppFonts(tester);
      fontsLoaded = true;
    }
    SharedPreferences.setMockInitialValues({});
    final palettes = PixelArtPaletteService();
    await tester.runAsync(palettes.init);
    await tester.pumpWidget(
      ChangeNotifierProvider<PixelArtPaletteService>.value(
        value: palettes,
        child: MaterialApp(
          locale: locale,
          theme: ThemeService().themeDataFor(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final MapEntry(key: name, value: open)
                        in dialogs.entries)
                      if (open != null)
                        TextButton(
                          key: Key('open_$name'),
                          onPressed: () => open(context),
                          child: Text(name),
                        ),
                    EditableSliderValue(
                      key: const Key('open_EditableSliderValue'),
                      text: '12',
                      value: 12,
                      min: 1,
                      max: 500,
                      title: AppLocalizations.of(
                        context,
                      )!.brushSettingsSizeLabel,
                      isInt: true,
                      onChanged: (_) {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final locale in AppLocalizations.supportedLocales) {
    final tag = locale.toLanguageTag();
    testWidgets('typing dialogs take the room above the keyboard ($tag)', (
      tester,
    ) async {
      final problems = <String>[];
      final errors = <String>[];
      final onError = FlutterError.onError;
      FlutterError.onError = (d) => errors.add(d.exceptionAsString());
      try {
        tester.view.physicalSize = _size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        await pumpHost(tester, locale);
        for (final name in dialogs.keys) {
          final at = '$tag $name';
          tester.view.viewInsets = FakeViewPadding.zero;
          await tester.pump();
          await tester.tap(find.byKey(Key('open_$name')));
          await tester.pumpAndSettle();
          final dialog = find.byType(AlertDialog);
          expect(dialog, findsOneWidget, reason: at);
          // 欄にフォーカスがなければ押して打ち始める。
          final field = find.descendant(
            of: dialog,
            matching: find.byType(EditableText),
          );
          final editable = tester.state<EditableTextState>(field.first);
          if (!editable.widget.focusNode.hasFocus) {
            await tester.tap(field.first, warnIfMissed: false);
            await tester.pump();
          }
          // キーボードが開く。
          tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
          await tester.pumpAndSettle();
          const room = 568.0 - _keyboard;
          final material = find
              .descendant(of: dialog, matching: find.byType(Material))
              .first;
          final box = tester.getRect(material);
          if (box.top < -0.5 || box.bottom > room + 0.5) {
            problems.add('$at: the dialog $box is not inside 0–$room');
          }
          // 中身が切れているのに上下に空きを残さない。
          var cut = 0.0;
          for (final e
              in find
                  .descendant(of: dialog, matching: find.byType(Scrollable))
                  .evaluate()) {
            final position = (e as StatefulElement).state as ScrollableState;
            if (position.position.axis != Axis.vertical) continue;
            final extent =
                position.position.maxScrollExtent -
                position.position.minScrollExtent;
            if (extent > cut) cut = extent;
          }
          final above = box.top;
          final below = room - box.bottom;
          debugPrint(
            '$at dialog ${box.top.toStringAsFixed(1)}–'
            '${box.bottom.toStringAsFixed(1)} (room $room), '
            'content scrolls ${cut.toStringAsFixed(1)}px',
          );
          if (cut > 0.5 && (above > 0.5 || below > 0.5)) {
            problems.add(
              '$at: the content scrolls ${cut.toStringAsFixed(0)}px but the '
              'dialog leaves ${above.toStringAsFixed(0)}px above and '
              '${below.toStringAsFixed(0)}px below while the keyboard is open',
            );
          }
          // 打っている欄が見える（1行分以上）。
          final focused = find
              .descendant(of: dialog, matching: find.byType(EditableText))
              .evaluate()
              .firstWhere(
                (e) => ((e as StatefulElement).state as EditableTextState)
                    .widget
                    .focusNode
                    .hasFocus,
                orElse: () => field.evaluate().first,
              );
          final render = focused.renderObject! as RenderBox;
          final fieldRect = MatrixUtils.transformRect(
            render.getTransformTo(null),
            Offset.zero & render.size,
          );
          final visible = fieldRect.intersect(
            Rect.fromLTRB(0, box.top, _size.width, box.bottom),
          );
          // 1行分（欄そのものがそれより低ければ欄の高さ）。欄が押しつぶされて
          // 高さが無いときも見えていないことになる。
          final line =
              (focused.widget as EditableText).style.fontSize! * 2.0 - 0.5;
          final needed = line < fieldRect.height ? line : fieldRect.height;
          if (fieldRect.height < 1 || visible.height < needed - 0.5) {
            problems.add(
              '$at: only ${visible.height.toStringAsFixed(0)}px of the field '
              '$fieldRect shows above the keyboard',
            );
          }
          for (final error in errors) {
            problems.add('$at ${error.split('\n').first}');
          }
          errors.clear();
          // 閉じる。
          tester.view.viewInsets = FakeViewPadding.zero;
          await tester.pumpAndSettle();
          Navigator.of(tester.element(dialog)).pop();
          await tester.pumpAndSettle();
        }
      } finally {
        FlutterError.onError = onError;
      }
      for (final p in problems) {
        debugPrint(p);
      }
      expect(problems, isEmpty, reason: '${problems.length} problems');
    });
  }

  testWidgets('a wide typing dialog keeps its side inset and drops the '
      'vertical one while the keyboard is open', (tester) async {
    tester.view.physicalSize = _size;
    tester.view.devicePixelRatio = 1;
    const usual = EdgeInsets.symmetric(horizontal: 16, vertical: 24);
    final seen = <EdgeInsets?>[];
    Future<void> pumpWith(double keyboard) async {
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              seen.add(typingDialogInsetPadding(context, usual: usual));
              return const SizedBox();
            },
          ),
        ),
      );
    }

    await pumpWith(0);
    await pumpWith(_keyboard);
    expect(seen.first, usual);
    expect(seen.last, const EdgeInsets.symmetric(horizontal: 16));
  });

  test('typing dialogs outside Home pass typingDialogInsetPadding', () {
    final missing = <String>[];
    var seen = 0;
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      final path = file.path.replaceAll('\\', '/');
      if (!path.endsWith('.dart') || path.startsWith('lib/screens/home/')) {
        continue;
      }
      final source = file.readAsStringSync();
      for (final dialog in _dialogCalls(source)) {
        if (!_typingField.hasMatch(dialog.body)) continue;
        seen++;
        if (!_passesTypingInset(dialog.body, source)) {
          missing.add('$path:${dialog.line} ${dialog.kind}');
        }
      }
    }
    debugPrint('typing dialogs outside Home: $seen');
    expect(seen, greaterThan(40));
    expect(missing, isEmpty, reason: missing.join('\n'));
  });
}

/// ダイアログの引数[body]が`typingDialogInsetPadding`の空きを渡すか（その場で
/// 呼ぶか、同じファイルで`typingDialogInsetPadding`から決めた変数を渡す。
/// `NameEntryDialog`は中でキーボードの分を取り除くので、外で決めて渡す）。
bool _passesTypingInset(String body, String source) {
  if (body.contains('insetPadding: typingDialogInsetPadding(')) return true;
  final named = RegExp(r'insetPadding: ([A-Za-z_]\w*),').firstMatch(body);
  if (named == null) return false;
  return source.contains('${named.group(1)} = typingDialogInsetPadding(');
}

/// 打つ欄（入力欄・入力欄を持つ色の選び方のパネル）。
final _typingField = RegExp(
  r'(?<![A-Za-z0-9_])(TextField|TextFormField|ColorPickerPanel)\(',
);

final _dialogStart = RegExp(
  r'(?<![A-Za-z0-9_.])(AlertDialog|Dialog|SimpleDialog)(\.fullscreen)?\(',
);

/// [source]の中のダイアログの呼び出し（種類・行・引数の中身）。
Iterable<({String kind, int line, String body})> _dialogCalls(
  String source,
) sync* {
  for (final m in _dialogStart.allMatches(source)) {
    final open = m.end - 1;
    final close = _matchingParen(source, open);
    // 自分の中の別のダイアログ（中から開くダイアログ）の中身は数えない。
    var body = source.substring(open + 1, close);
    final inner = _dialogStart.firstMatch(body);
    if (inner != null) {
      final innerClose = _matchingParen(body, inner.end - 1);
      body = body.substring(0, inner.start) + body.substring(innerClose + 1);
    }
    yield (
      kind: m.group(0)!,
      line: '\n'.allMatches(source.substring(0, m.start)).length + 1,
      body: body,
    );
  }
}

/// [open]の`(`と対になる`)`の位置（文字列・注釈の中の括弧は数えない）。
int _matchingParen(String s, int open) {
  var depth = 0;
  var i = open;
  String? quote;
  while (i < s.length) {
    final c = s[i];
    if (quote != null) {
      if (c == r'\') {
        i += 2;
        continue;
      }
      if (s.startsWith(quote, i)) {
        i += quote.length;
        quote = null;
        continue;
      }
      i++;
      continue;
    }
    if (s.startsWith("'''", i) || s.startsWith('"""', i)) {
      quote = s.substring(i, i + 3);
      i += 3;
      continue;
    }
    if (c == "'" || c == '"') {
      quote = c;
      i++;
      continue;
    }
    if (s.startsWith('//', i)) {
      final end = s.indexOf('\n', i);
      i = end < 0 ? s.length : end;
      continue;
    }
    if (c == '(') depth++;
    if (c == ')') {
      depth--;
      if (depth == 0) return i;
    }
    i++;
  }
  return s.length;
}
