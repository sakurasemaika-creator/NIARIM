// ボタンのラベルが折り返したとき・字がとても大きいとき、ボタンがラベルに
// 合わせて伸び、ラベルの上下に余白が残ることを見張る（アプリのテーマで、
// 塗り・枠・文字・浮きのボタンすべて）。
//
// Material 3のボタンは上下の余白が0で、ボタンはラベルの行の高さぴったりまで
// しか伸びない。くらむぼんは行の高さが字の大きさと同じ（1em）で、アクセント
// （É）や下に伸びる字（p・g）が行の外へ出るので、2行になったラベルは字が
// ボタンの枠を越えた（品質の設定の「Réinitialiser aux valeurs par défaut」、
// プロジェクト詳細の「Commencer l’édition」、仏語360px×文字2倍）。
//
// 余白は字の描かれる所（インク）から測る。くらむぼんのアクセント・下に
// 伸びる字は行の外へ出るので、行の端から8px取っても、字と枠の間は3〜6pxしか
// 残らなかった（「Réinitialiser aux valeurs par défaut」上6px・下3px、報酬の
// 「Vérifier les doublons et l’expiration」上6px・下3px）。字を描いた画素で
// 測り、7言語×360/1280px×文字1.0/2.0で8px以上あることを見張る。
//
// 1行のラベル（文字2倍まで）はボタンの最小の高さに収まるので、高さも見た目も
// 変わらないこと、自分で小さくしたボタン（最小の大きさ0）の1行のラベルも
// 変わらないことも見張る。
//
// テーマにラベルの余白の仕組み（foregroundBuilder）を付けると、Flutterは
// ボタンの面で中身を切る（clipBehaviorの既定がClip.antiAliasになる）。上下の
// 余白を0にした小さなボタン（ルーラーのパネルの「削除」）では、行の外へ出る
// 字（「Supprimer」のp）が面の縁で切れたので、その字が全部描かれることも
// 見張る。塗りのボタン（FilledButton、.iconも）はclipBehaviorの既定が
// Clip.noneで、テーマの仕組みを付けても切らない。上下の余白0の塗りのボタン
// （キャンバスのフレームを選んでフィルターをかけるボタン）の字が面の外まで
// 描かれることも見張る。
//
// ゴミ箱へ移す確認の「ゴミ箱へ移動」（DISC136）は、ボタンの文字の部品
// （trashConfirmLabelText）が自分でも上下に6px空けていた。テーマの余白と
// 重なると二重に空くので、テーマの余白だけで字と枠の間が8px以上になり、
// 同じ文字の素のボタンと同じ余白であることも見張る。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/ruler.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/widgets/ruler_panel.dart';
import 'package:niarim/screens/settings/performance_settings_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/project_trash_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

/// 段落[p]が描く行の数（書体の違う字が混ざっても、行の数で数える）。
int _lines(RenderParagraph p) {
  final painter = TextPainter(
    text: p.text,
    textDirection: p.textDirection,
    textScaler: p.textScaler,
    locale: p.locale,
    maxLines: p.maxLines,
    ellipsis: p.overflow == TextOverflow.ellipsis ? '\u2026' : null,
    strutStyle: p.strutStyle,
    textWidthBasis: p.textWidthBasis,
    textHeightBehavior: p.textHeightBehavior,
  )..layout(maxWidth: p.constraints.maxWidth);
  final lines = painter.computeLineMetrics().length;
  painter.dispose();
  return lines;
}

/// ボタン[button]の中の、ラベルの段落とボタンの面（Material）の上下の間。
({double top, double bottom, int lines, double height}) _gaps(
  WidgetTester tester,
  Finder button,
) {
  final material = tester.renderObject<RenderBox>(
    find.descendant(of: button, matching: find.byType(Material)).first,
  );
  final paragraph = tester
      .renderObjectList<RenderParagraph>(
        find.descendant(of: button, matching: find.byType(RichText)),
      )
      // アイコンも段落なので、文字のラベル（アイコンの書体でないもの）を取る。
      .firstWhere((p) => p.text.style?.fontFamily != 'MaterialIcons');
  final m = material.localToGlobal(Offset.zero) & material.size;
  final p = paragraph.localToGlobal(Offset.zero) & paragraph.size;
  final lines = _lines(paragraph);
  return (
    top: p.top - m.top,
    bottom: m.bottom - p.bottom,
    lines: lines,
    height: m.height,
  );
}

/// [child]を左上に置いた画面（[home]を渡せばその画面）。
Widget _app(
  ThemeData theme,
  Locale locale,
  double scale, {
  Widget? child,
  Widget? home,
}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  theme: theme,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home:
      home ??
      Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
);

/// 段落[p]の字が描かれる所（インク）。段落と同じ文・幅で、周りに余白を
/// 取った透明な画像へ描き、色の付いた画素の範囲を求める（段落の左上が原点）。
Future<Rect?> _inkOf(WidgetTester tester, RenderParagraph p) async {
  final painter = TextPainter(
    text: p.text,
    textAlign: p.textAlign,
    textDirection: p.textDirection,
    textScaler: p.textScaler,
    maxLines: p.maxLines,
    ellipsis: p.overflow == TextOverflow.ellipsis ? '\u2026' : null,
    locale: p.locale,
    strutStyle: p.strutStyle,
    textWidthBasis: p.textWidthBasis,
    textHeightBehavior: p.textHeightBehavior,
  )..layout(minWidth: p.constraints.minWidth, maxWidth: p.constraints.maxWidth);
  const margin = 64.0;
  final width = (p.size.width + margin * 2).ceil();
  final height = (p.size.height + margin * 2).ceil();
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), const Offset(margin, margin));
  painter.dispose();
  final picture = recorder.endRecording();
  final rgba = (await tester.runAsync(() async {
    final image = await picture.toImage(width, height);
    final data = await image.toByteData();
    image.dispose();
    picture.dispose();
    return data!.buffer.asUint8List();
  }))!;
  var top = height, bottom = -1, left = width, right = -1;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (rgba[(y * width + x) * 4 + 3] == 0) continue;
      if (y < top) top = y;
      if (y > bottom) bottom = y;
      if (x < left) left = x;
      if (x > right) right = x;
    }
  }
  if (bottom < 0) return null;
  return Rect.fromLTRB(
    left - margin,
    top - margin,
    right + 1 - margin,
    bottom + 1 - margin,
  );
}

/// ボタン[button]のラベルの字（インク）と、ボタンの面（Material）の上下の間。
Future<({double top, double bottom, int lines})?> _inkGaps(
  WidgetTester tester,
  Finder button,
) async {
  final material = tester.renderObject<RenderBox>(
    find.descendant(of: button, matching: find.byType(Material)).first,
  );
  final paragraph = tester
      .renderObjectList<RenderParagraph>(
        find.descendant(of: button, matching: find.byType(RichText)),
      )
      .firstWhere((p) => p.text.style?.fontFamily != 'MaterialIcons');
  final ink = await _inkOf(tester, paragraph);
  if (ink == null) return null;
  final face = material.localToGlobal(Offset.zero) & material.size;
  final global = ink.shift(paragraph.localToGlobal(Offset.zero));
  return (
    top: global.top - face.top,
    bottom: face.bottom - global.bottom,
    lines: _lines(paragraph),
  );
}

void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('折り返したラベルは上下に8px以上の余白を取り、ボタンが伸びる'
      '（7言語×文字1.0/2.0、塗り・枠・文字・浮き・アイコン付き）', (tester) async {
    await loadAppFonts(tester);
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    final problems = <String>[];
    for (final locale in AppLocalizations.supportedLocales) {
      final l = lookupAppLocalizations(locale);
      final theme = ThemeService().themeDataFor(locale);
      // 360pxの画面で、文字1倍でも折り返す長さの文言。
      final label =
          '${l.perfSettingsResetButton} ${l.perfSettingsCopyPresetButton} '
          '${l.perfSettingsQualityDescHigh}';
      for (final scale in const [1.0, 2.0]) {
        final kinds = <String, Widget>{
          'Filled': FilledButton(onPressed: () {}, child: Text(label)),
          'Filled.icon': FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.edit),
            label: Text(label),
          ),
          'Outlined': OutlinedButton(onPressed: () {}, child: Text(label)),
          'Outlined.icon(12px)': OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.copy, size: 16),
            label: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          'Text': TextButton(onPressed: () {}, child: Text(label)),
          'Elevated': ElevatedButton(onPressed: () {}, child: Text(label)),
          'Filled(全幅・高さ48)': FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.edit),
            label: Text(label),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        };
        for (final kind in kinds.entries) {
          final key = GlobalKey();
          await tester.pumpWidget(
            _app(
              theme,
              locale,
              scale,
              child: KeyedSubtree(key: key, child: kind.value),
            ),
          );
          final g = _gaps(tester, find.byKey(key));
          final where = '${locale.toLanguageTag()} ×$scale ${kind.key}';
          if (g.lines < 2) {
            problems.add('$where: ラベルが折り返していない（テストの前提）');
            continue;
          }
          if (g.top < 8 - 0.01 || g.bottom < 8 - 0.01) {
            problems.add(
              '$where: ${g.lines}行のラベルの上${g.top.toStringAsFixed(1)}px・'
              '下${g.bottom.toStringAsFixed(1)}px（8px未満）',
            );
          }
        }
      }
    }
    expect(
      problems,
      isEmpty,
      reason: '${problems.length}件\n${problems.join('\n')}',
    );
  });

  testWidgets('1行のラベルはボタンの高さが変わらない（自分で小さくしたボタンも）', (tester) async {
    await loadAppFonts(tester);
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    final theme = ThemeService().themeDataFor(const Locale('fr'));
    final problems = <String>[];
    for (final scale in const [1.0, 2.0]) {
      final kinds = <String, (Widget, double?)>{
        'Filled': (FilledButton(onPressed: () {}, child: const Text('OK')), 48),
        'Outlined': (
          OutlinedButton(onPressed: () {}, child: const Text('OK')),
          48,
        ),
        'Text': (TextButton(onPressed: () {}, child: const Text('OK')), 44),
        // 自分で小さくしたボタン（行の中の小さな文字のボタン）は、1行なら
        // ラベルの行の高さのまま（余白を足さない）。
        'Text(最小0)': (
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('OK'),
          ),
          null,
        ),
      };
      for (final kind in kinds.entries) {
        final key = GlobalKey();
        await tester.pumpWidget(
          _app(
            theme,
            const Locale('fr'),
            scale,
            child: KeyedSubtree(key: key, child: kind.value.$1),
          ),
        );
        final g = _gaps(tester, find.byKey(key));
        final expected = kind.value.$2 ?? g.height - g.top - g.bottom;
        if ((g.height - expected).abs() > 0.01) {
          problems.add(
            '×$scale ${kind.key}: 高さ${g.height.toStringAsFixed(1)}'
            '（${expected.toStringAsFixed(1)}のはず）',
          );
        }
        if (kind.value.$2 == null && (g.top > 0.01 || g.bottom > 0.01)) {
          problems.add('×$scale ${kind.key}: 1行なのに余白を足した');
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  testWidgets('品質の設定（カスタム）の「既定に戻す」「今のプリセットをコピー」は、'
      '仏語・西語の360px×文字2倍で字がボタンの枠の中に収まる', (tester) async {
    await loadAppFonts(tester);
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'quality_level': 'custom',
      'default_preset': 'low',
      'custom_saved': true,
    });
    final dir = Directory.systemTemp.createTempSync('niarim_button_room_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => dir.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final providers = (await tester.runAsync(buildAppProviders))!;
    // 縦に長い画面にして、どの行も作られた状態で測る。
    tester.view.physicalSize = const Size(360, 4000);
    tester.view.devicePixelRatio = 1;
    final problems = <String>[];
    for (final locale in const [Locale('fr'), Locale('es')]) {
      final l = lookupAppLocalizations(locale);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MultiProvider(
          providers: providers,
          child: Builder(
            builder: (context) => _app(
              context.watch<ThemeService>().themeDataFor(locale),
              locale,
              2.0,
              home: const PerformanceSettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in [
        l.perfSettingsResetButton,
        l.perfSettingsCopyPresetButton,
      ]) {
        final button = find.ancestor(
          of: find.byWidgetPredicate(
            (w) => w is Text && (w.semanticsLabel == label || w.data == label),
          ),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        );
        final g = _gaps(tester, button.first);
        if (g.top < 8 - 0.01 || g.bottom < 8 - 0.01) {
          problems.add(
            '${locale.toLanguageTag()} «$label»: ${g.lines}行、上'
            '${g.top.toStringAsFixed(1)}px・下${g.bottom.toStringAsFixed(1)}px',
          );
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  testWidgets('上下の余白の無い小さなボタン（ルーラーのパネルの「削除」）は、'
      '行の外へ出る字（「Supprimer」のp）を面の縁で切らない', (tester) async {
    await loadAppFonts(tester);
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    const locale = Locale('fr');
    final l = lookupAppLocalizations(locale);
    final theme = ThemeService().themeDataFor(locale);
    final shot = GlobalKey();

    /// [area]の中の、背景[bg]から離れた色の量（字の画素の濃さの合計）。
    Future<double> ink(Rect area, Color Function(ByteData, int) bg) async {
      final (data, width) = (await tester.runAsync(() async {
        final img =
            await (shot.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 3);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
        final w = img.width;
        img.dispose();
        return (bytes!, w);
      }))!;
      final origin = tester.getTopLeft(find.byKey(shot));
      final back = bg(data, width);
      var sum = 0.0;
      final r = area.shift(-origin);
      for (var y = (r.top * 3).floor(); y < (r.bottom * 3).ceil(); y++) {
        for (var x = (r.left * 3).floor(); x < (r.right * 3).ceil(); x++) {
          final i = (y * width + x) * 4;
          sum += [
            (data.getUint8(i) - (back.r * 255).round()).abs(),
            (data.getUint8(i + 1) - (back.g * 255).round()).abs(),
            (data.getUint8(i + 2) - (back.b * 255).round()).abs(),
          ].reduce((a, b) => a > b ? a : b);
        }
      }
      return sum;
    }

    Color pixel(ByteData data, int width, Offset at) {
      final origin = tester.getTopLeft(find.byKey(shot));
      final p = (at - origin) * 3;
      final i = (p.dy.round() * width + p.dx.round()) * 4;
      return Color.fromARGB(
        255,
        data.getUint8(i),
        data.getUint8(i + 1),
        data.getUint8(i + 2),
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: theme,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: shot,
              child: RulerPanel(
                activeRuler: const Ruler(
                  type: RulerType.line,
                  position: Offset(500, 500),
                  settings: RulerSettings(),
                ),
                onRulerChanged: (_) {},
                onClose: () {},
                canvasWidth: 1000,
                canvasHeight: 1000,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final label = find.descendant(
      of: find.byWidgetPredicate((w) => w is TextButton),
      matching: find.text(l.commonDelete),
    );
    expect(label, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: label, matching: find.byType(RichText)),
    );
    final labelRect = tester.getRect(label);
    // ボタンの中で字の右の余白（ボタンの背景＝パネルの色）を背景とする。
    final backAt = Offset(labelRect.right + 3, labelRect.center.dy);
    final inButton = await ink(
      labelRect.inflate(6),
      (data, width) => pixel(data, width, backAt),
    );

    // 同じ段落を、切るもののない所に描いたときの字の量。
    final reference = GlobalKey();
    late Color back;
    await tester.runAsync(() async {
      final img =
          await (shot.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 3);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      back = pixel(bytes!, img.width, backAt);
      img.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: shot,
              child: Container(
                color: back,
                padding: const EdgeInsets.all(20),
                child: RichText(
                  key: reference,
                  text: paragraph.text,
                  textScaler: paragraph.textScaler,
                  textDirection: TextDirection.ltr,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final free = await ink(
      tester.getRect(find.byKey(reference)).inflate(6),
      (_, _) => back,
    );
    expect(free, greaterThan(0));
    expect(
      inButton,
      greaterThanOrEqualTo(free * 0.99),
      reason:
          '«${l.commonDelete}»の字の量がボタンの中で'
          '${(100 * inButton / free).toStringAsFixed(1)}%（面の縁で切れている）',
    );
  });

  testWidgets('上下の余白の無い塗りのボタン（キャンバスのフレームを選んで'
      'フィルターをかけるボタン）は、面の外へ出る字を切らない', (tester) async {
    await loadAppFonts(tester);
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    // 縦長（スマホの配置）で、行の全部のボタンが画面に入る幅。
    const size = Size(1200, 1600);
    final root = GlobalKey();
    var measured = 0.0;
    final problems = <String>[];

    Future<void> settle([int rounds = 6]) async {
      for (var i = 0; i < rounds; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<(ByteData, int)> shoot() async => (await tester.runAsync(() async {
      final img =
          await (root.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 3);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      final w = img.width;
      img.dispose();
      return (bytes!, w);
    }))!;

    /// [areas]の中の、[back]から離れた色の量（字の画素の濃さの合計）。
    double ink(ByteData data, int width, List<Rect> areas, Color back) {
      var sum = 0.0;
      for (final r in areas) {
        for (var y = (r.top * 3).round(); y < (r.bottom * 3).round(); y++) {
          for (var x = (r.left * 3).round(); x < (r.right * 3).round(); x++) {
            final i = (y * width + x) * 4;
            sum += [
              (data.getUint8(i) - (back.r * 255).round()).abs(),
              (data.getUint8(i + 1) - (back.g * 255).round()).abs(),
              (data.getUint8(i + 2) - (back.b * 255).round()).abs(),
            ].reduce((a, b) => a > b ? a : b);
          }
        }
      }
      return sum;
    }

    Color pixel(ByteData data, int width, Offset at) {
      final i = ((at.dy * 3).round() * width + (at.dx * 3).round()) * 4;
      return Color.fromARGB(
        255,
        data.getUint8(i),
        data.getUint8(i + 1),
        data.getUint8(i + 2),
      );
    }

    for (final (language, scale) in const [
      ('fr', 1.0),
      ('fr', 2.0),
      ('ja', 2.0),
    ]) {
      final where = '$language ×$scale';
      final dir = Directory.systemTemp.createTempSync('niarim_filter_btn_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, (call) async => dir.path);
      appRouter.go('/home');
      SharedPreferences.setMockInitialValues({
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
        'first_launch': false,
        'language': language,
      });
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      final providers = (await tester.runAsync(buildAppProviders))!;
      await tester.pumpWidget(
        RepaintBoundary(
          key: root,
          child: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(scale),
            ),
            child: MultiProvider(
              providers: providers,
              child: const NiarimApp(),
            ),
          ),
        ),
      );
      await settle(4);
      final l = lookupAppLocalizations(Locale(language));
      late String id;
      await tester.runAsync(() async {
        final project = await tester
            .element(find.byType(Navigator).first)
            .read<ProjectService>()
            .createProject(
              name: 'filter',
              fps: 2,
              durationSeconds: 1,
              backgroundColor: 0xFFFFFFFF,
              exportWidth: 160,
              exportHeight: 90,
            );
        id = project.id;
      });
      appRouter.push('/canvas/$id');
      await settle(10);
      // 設定/編集メニューの「フレーム複数選択」で行を出し、全部を選ぶ。
      await tester.tap(find.byIcon(Icons.settings));
      await settle(3);
      final entry = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text(l.canvasEditMenuFrameMultiSelect),
      );
      await tester.ensureVisible(entry);
      await tester.pump();
      await tester.tap(entry);
      await settle(6);
      await tester.tap(find.text(l.canvasSelectAllButton));
      await settle(2);

      final label = find.text(l.canvasApplyFilterButton);
      final button = find
          .ancestor(
            of: label,
            matching: find.byWidgetPredicate((w) => w is FilledButton),
          )
          .first;
      final face = tester.renderObject<RenderBox>(
        find.descendant(of: button, matching: find.byType(Material)).first,
      );
      final f = face.localToGlobal(Offset.zero) & face.size;
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: label, matching: find.byType(RichText)),
      );
      final p = tester.getRect(label);
      // 面の上下（縁の1px幅のにじみを除く）の、ラベルの横の範囲。
      List<Rect> outside(Rect para, Rect face) => [
        Rect.fromLTRB(para.left, para.top - 6, para.right, face.top - 0.5),
        Rect.fromLTRB(
          para.left,
          face.bottom + 0.5,
          para.right,
          para.bottom + 6,
        ),
      ];
      final (data, width) = await shoot();
      // 行の地の色（面の上の、何も無い所）。
      final back = pixel(data, width, Offset(p.center.dx, f.top - 10));
      final inButton = ink(data, width, outside(p, f), back);

      // 同じ段落を、同じ地の色の上に切るもののない所に描いたときの、面の
      // 外に当たる所の字の量。
      final reference = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: root,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Container(
              color: back,
              padding: const EdgeInsets.all(20),
              alignment: Alignment.topLeft,
              child: RichText(
                key: reference,
                text: paragraph.text,
                textScaler: paragraph.textScaler,
                textDirection: TextDirection.ltr,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final q = tester.getRect(find.byKey(reference));
      final (refData, refWidth) = await shoot();
      final free = ink(
        refData,
        refWidth,
        outside(q, f.shift(q.topLeft - p.topLeft)),
        back,
      );
      measured += free;
      if (inButton < free * 0.99) {
        problems.add(
          '$where: 面の外の字の量が${(100 * inButton / free).toStringAsFixed(1)}%'
          '（面の縁で切れている）',
        );
      }
      debugPrint(
        'frame filter $where face=$f label=$p '
        'outside ink ${inButton.round()} / free ${free.round()}',
      );
      await tester.pumpWidget(const SizedBox());
      await settle(2);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null);
      dir.deleteSync(recursive: true);
    }
    // 字が面の外へ出ていなければ、何も見ていない。
    expect(measured, greaterThan(0));
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  testWidgets('折り返したラベルの字（アクセント・下に伸びる字）とボタンの枠の間が'
      '8px以上（7言語×360/1280px×文字1.0/2.0、字を描いた画素で測る）', (tester) async {
    await loadAppFonts(tester);
    tester.view.devicePixelRatio = 1;
    final problems = <String>[];
    var measured = 0;
    for (final locale in AppLocalizations.supportedLocales) {
      final l = lookupAppLocalizations(locale);
      final theme = ThemeService().themeDataFor(locale);
      for (final width in const [360.0, 1280.0]) {
        tester.view.physicalSize = Size(width, 900);
        // 1行目はアクセントの付いた大文字、最後の行は下に伸びる字で終わる、
        // その幅で折り返す長さの文言。
        final words =
            '${l.perfSettingsResetButton} ${l.perfSettingsCopyPresetButton} '
            '${l.perfSettingsQualityDescHigh}';
        final label =
            'ÓÀÉ ${List.filled(width > 400 ? 4 : 1, words).join(' ')} gjpqyç';
        for (final scale in const [1.0, 2.0]) {
          final kinds = <String, Widget>{
            'Filled': FilledButton(onPressed: () {}, child: Text(label)),
            'Filled.icon': FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.edit),
              label: Text(label),
            ),
            'Outlined': OutlinedButton(onPressed: () {}, child: Text(label)),
            'Outlined.icon(12px)': OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.copy, size: 16),
              label: Text(label, style: const TextStyle(fontSize: 12)),
            ),
            'Text': TextButton(onPressed: () {}, child: Text(label)),
            'Elevated': ElevatedButton(onPressed: () {}, child: Text(label)),
            'Filled(全幅・高さ48)': FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.edit),
              label: Text(label),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          };
          for (final kind in kinds.entries) {
            final key = GlobalKey();
            await tester.pumpWidget(
              _app(
                theme,
                locale,
                scale,
                child: KeyedSubtree(key: key, child: kind.value),
              ),
            );
            final where =
                '${locale.toLanguageTag()} ${width.round()}px ×$scale '
                '${kind.key}';
            final g = await _inkGaps(tester, find.byKey(key));
            if (g == null || g.lines < 2) {
              problems.add('$where: ラベルが折り返していない（テストの前提）');
              continue;
            }
            measured++;
            if (g.top < 8 - 0.01 || g.bottom < 8 - 0.01) {
              problems.add(
                '$where: ${g.lines}行のラベルの字と枠の間が上'
                '${g.top.toStringAsFixed(1)}px・下${g.bottom.toStringAsFixed(1)}px'
                '（8px未満）',
              );
            }
          }
        }
      }
    }
    expect(measured, 7 * 2 * 2 * 7);
    expect(
      problems,
      isEmpty,
      reason: '${problems.length}件\n${problems.join('\n')}',
    );
  }, timeout: const Timeout(Duration(minutes: 10)));

  testWidgets('本物の画面の折り返したボタン（品質の設定の「既定に戻す」「今の'
      'プリセットをコピー」・特典交換の「重複と期限を確認」「目標にする」・会員の'
      '「プレミアムを見る」）の字と枠の間が8px以上（7言語×360/1280px×'
      '文字1.0/2.0、字を描いた画素で測る）', (tester) async {
    await loadAppFonts(tester);
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    final problems = <String>[];
    var measured = 0;
    final wrappedAtFr360x2 = <String>{};
    // アプリはホーム画面のウィジェットの画像を後から書くので、作業用の
    // フォルダはテストの最後に消す。
    final dir = Directory.systemTemp.createTempSync('niarim_button_ink_');
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => dir.path);
    for (final locale in AppLocalizations.supportedLocales) {
      final tag = locale.scriptCode == null
          ? locale.languageCode
          : '${locale.languageCode}_${locale.scriptCode}';
      SharedPreferences.setMockInitialValues({
        'first_launch': false,
        'language': tag,
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
        'quality_level': 'custom',
        'default_preset': 'low',
        'custom_saved': true,
      });
      final providers = (await tester.runAsync(buildAppProviders))!;
      for (final width in const [360.0, 1280.0]) {
        for (final scale in const [1.0, 2.0]) {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          final l = lookupAppLocalizations(locale);
          Finder labelled(String label) => find.ancestor(
            of: find.byWidgetPredicate(
              (w) =>
                  w is Text && (w.semanticsLabel == label || w.data == label),
            ),
            matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
          );
          for (final (route, buttons) in [
            (
              '/settings/performance',
              {
                'reset': labelled(l.perfSettingsResetButton),
                'copy': labelled(l.perfSettingsCopyPresetButton),
              },
            ),
            (
              '/rewards',
              {
                'review': find.byKey(const Key('rewardOverlapPreviewButton')),
                'goal': find.byKey(const Key('rewardSetGoalButton')),
              },
            ),
            (
              '/membership',
              {
                'premium': find.byKey(
                  const Key('membershipLearnPremiumButton'),
                ),
              },
            ),
          ]) {
            await tester.pumpWidget(const SizedBox());
            await tester.pumpWidget(
              MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 900),
                  textScaler: TextScaler.linear(scale),
                ),
                child: MultiProvider(
                  providers: providers,
                  child: const NiarimApp(),
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 300));
            appRouter.go(route);
            for (var i = 0; i < 6; i++) {
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 40)),
              );
              await tester.pump(const Duration(milliseconds: 150));
            }
            for (final MapEntry(key: name, value: button) in buttons.entries) {
              final where = '$tag ${width.round()}px ×$scale $route $name';
              // 縦の一覧を、ボタンが作られるまで下へ送る（画面の外の行は
              // 作られない）。
              for (final element
                  in find.byType(Scrollable).evaluate().toList()) {
                final position =
                    ((element as StatefulElement).state as ScrollableState)
                        .position;
                if (position.axis != Axis.vertical) continue;
                for (
                  var i = 0;
                  i < 60 &&
                      button.evaluate().isEmpty &&
                      position.pixels < position.maxScrollExtent;
                  i++
                ) {
                  position.jumpTo(
                    (position.pixels + position.viewportDimension / 2).clamp(
                      0,
                      position.maxScrollExtent,
                    ),
                  );
                  await tester.pump(const Duration(milliseconds: 100));
                }
                if (button.evaluate().isNotEmpty) break;
              }
              await tester.ensureVisible(button.first);
              await tester.pump();
              final g = await _inkGaps(tester, button.first);
              if (g == null) {
                problems.add('$where: ラベルの字が無い');
                continue;
              }
              if (g.lines < 2) continue;
              if (tag == 'fr' && width == 360 && scale == 2.0) {
                wrappedAtFr360x2.add('$route $name');
              }
              measured++;
              if (g.top < 8 - 0.01 || g.bottom < 8 - 0.01) {
                problems.add(
                  '$where: ${g.lines}行のラベルの字と枠の間が上'
                  '${g.top.toStringAsFixed(1)}px・下'
                  '${g.bottom.toStringAsFixed(1)}px（8px未満）',
                );
              }
            }
          }
        }
      }
      appRouter.go('/home');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    // 実操作で8px未満だった5つのボタンは、仏語の360px×文字2倍で折り返す。
    expect(wrappedAtFr360x2, hasLength(5), reason: '$wrappedAtFr360x2');
    expect(measured, greaterThan(5));
    expect(
      problems,
      isEmpty,
      reason: '${problems.length}件\n${problems.join('\n')}',
    );
  }, timeout: const Timeout(Duration(minutes: 15)));

  testWidgets('ゴミ箱へ移す確認の「ゴミ箱へ移動」は、折り返しても字と枠の間が'
      '上下8px以上で、余白はテーマの分だけ（二重に取らない）。1行なら高さ48の'
      'まま（仏360/320px・韓320px×文字2倍、日360px・仏1280px×文字1倍）', (tester) async {
    await loadAppFonts(tester);
    tester.view.devicePixelRatio = 1;
    final problems = <String>[];
    // (言語, 画面の幅, 文字の倍率, ボタンの文字の行の数)
    for (final (language, width, scale, lines) in const [
      ('fr', 360.0, 2.0, 2),
      ('fr', 320.0, 2.0, 3),
      ('ko', 320.0, 2.0, 2),
      ('ja', 360.0, 1.0, 1),
      ('fr', 1280.0, 1.0, 1),
    ]) {
      final locale = Locale(language);
      final l = lookupAppLocalizations(locale);
      final theme = ThemeService().themeDataFor(locale);
      final where = '$language ${width.round()}px ×$scale';
      tester.view.physicalSize = Size(width, 900);
      // 前の言語・幅のダイアログを残さない（アプリを作り直す）。
      await tester.pumpWidget(
        KeyedSubtree(
          key: ValueKey(where),
          child: _app(
            theme,
            locale,
            scale,
            home: const Scaffold(body: SizedBox()),
          ),
        ),
      );
      showDialog<bool>(
        context: tester.element(find.byType(Scaffold)),
        builder: (_) => ProjectTrashDialog(
          title: l.homeMoveToTrash,
          message: l.homeMoveToTrashConfirm(1),
          confirmLabel: l.homeMoveToTrash,
          itemNames: const ['Sketch'],
          onApply: () async {},
        ),
      );
      await tester.pumpAndSettle();
      final confirm = find.byKey(const Key('trash-dialog-confirm'));
      final ink = await _inkGaps(tester, confirm);
      final box = _gaps(tester, confirm);
      if (ink == null || ink.lines != lines) {
        problems.add('$where: ボタンの文字が$lines行でない（${ink?.lines}行。テストの前提）');
        continue;
      }
      if (lines == 1) {
        if ((box.height - 48).abs() > 0.01) {
          problems.add('$where: 1行のボタンの高さが${box.height}（48でない）');
        }
        continue;
      }
      if (ink.top < 8 - 0.01 || ink.bottom < 8 - 0.01) {
        problems.add(
          '$where: $lines行の字と枠の間が上${ink.top.toStringAsFixed(1)}px・'
          '下${ink.bottom.toStringAsFixed(1)}px（8px未満）',
        );
      }
      // 同じ幅・同じ文字の素の塗りのボタン（テーマの余白だけ）と、文字の行と
      // 枠の間が同じ（ボタンの文字の部品が自分でも空けると、その分広い）。
      final buttonWidth = tester.getSize(confirm).width;
      final plain = GlobalKey();
      await tester.pumpWidget(
        _app(
          theme,
          locale,
          scale,
          child: SizedBox(
            width: buttonWidth,
            child: FilledButton(
              key: plain,
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                visualDensity: VisualDensity.standard,
              ),
              onPressed: () {},
              child: Text(l.homeMoveToTrash),
            ),
          ),
        ),
      );
      final reference = _gaps(tester, find.byKey(plain));
      if (reference.lines != lines ||
          (box.top - reference.top).abs() > 0.5 ||
          (box.bottom - reference.bottom).abs() > 0.5) {
        problems.add(
          '$where: 文字の行と枠の間が上${box.top.toStringAsFixed(1)}px・'
          '下${box.bottom.toStringAsFixed(1)}px（素のボタンは${reference.lines}行で'
          '上${reference.top.toStringAsFixed(1)}px・'
          '下${reference.bottom.toStringAsFixed(1)}px）',
        );
      }
    }
    expect(
      problems,
      isEmpty,
      reason: '${problems.length}件\n${problems.join('\n')}',
    );
  });
}
