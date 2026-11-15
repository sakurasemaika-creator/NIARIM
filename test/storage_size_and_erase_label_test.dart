import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/project/project_detail_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/paragraph_lines.dart';
import 'helpers/storage_screen_harness.dart';

/// 容量削減の画面の「全データを削除（初期化）」の名前の折り返しと、アプリの
/// ファイルの大きさの書き方（DISC130）。
///
/// * 仏語・360px・文字2倍で「Effacer toutes les données (réinitialiser)」の
///   「)」だけが最後の行へ落ちた（一覧の行と確認のボタン）。「(réinitialiser)」
///   1語が行より広く、語の途中で折れていた（行に入らない1語は、つないでも
///   字の途中で折れる）。仏語は語の短い「(remise à zéro)」にする。日本語・
///   中国語・韓国語は412pxで「（初 / 期化）」と括弧の中で折れた。
/// * 確認のボタンは文字2倍で2行に折れると、上下の余白が0で文字がボタンの縁に
///   付いていた。
/// * 大きさが言語によらず「1.4KB」「0B」だった（仏語は「1,4 Ko」と書く）。
///   言語ごとの書き方そのものは file_size_label_test.dart。
void main() {
  const nbsp = '\u00a0';

  testWidgets('fr: the storage screen writes sizes the French way', (
    tester,
  ) async {
    final providers = await bootstrapStorageScreen(tester);
    final service = ScriptedStorage();
    final l10n = await showStorageScreen(
      tester,
      providers,
      service,
      language: 'fr',
    );
    service.scans.last.complete(storageBreakdownOf());
    service.deviceQueries.last.complete(storageTestDevice);
    await tester.pump();
    // 素材 2048B・プロジェクト 4096B・キャッシュ 123B・端末の空き 400MB。
    for (final label in [
      '2,0${nbsp}Ko',
      '4,0${nbsp}Ko',
      '123${nbsp}o',
      '400,0${nbsp}Mo',
    ]) {
      expect(
        find.text(label, skipOffstage: false),
        findsWidgets,
        reason: '「$label」が出ていない',
      );
    }
    expect(find.textContaining(RegExp(r'\dKB|\dMB|\dB$')), findsNothing);
    expect(l10n.localeName, 'fr');
  });

  /// 段落の中の、括弧でくくった空白の無い語（「（初期化）」「(reset)」）。
  List<String> bracketed(String text) => [
    for (final m in RegExp(r'[（(][^（）()\s]+[）)]').allMatches(text)) m.group(0)!,
  ];

  RenderParagraph paragraphOf(WidgetTester tester, Finder text) =>
      tester.renderObject<RenderParagraph>(
        find.descendant(of: text, matching: find.byType(RichText)).first,
      );

  /// [paragraph]の文を、同じ書式・同じ欄の幅の普通のTextで並べたときの行数。
  int plainLineCount(RenderParagraph paragraph, String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: paragraph.text.style),
      textAlign: paragraph.textAlign,
      textDirection: paragraph.textDirection,
      textScaler: paragraph.textScaler,
      maxLines: paragraph.maxLines,
      locale: paragraph.locale,
      strutStyle: paragraph.strutStyle,
      textWidthBasis: paragraph.textWidthBasis,
      textHeightBehavior: paragraph.textHeightBehavior,
    )..layout(maxWidth: paragraph.constraints.maxWidth);
    final lines = painter.computeLineMetrics().length;
    painter.dispose();
    return lines;
  }

  /// [paragraph]の行の禁則・括弧の語の折れ・行の数を調べる（[where]は場所の
  /// 名前）。入る幅なら括弧の語を途中で折らず、入らない幅でも普通のTextより
  /// 行を増やさない。
  List<String> wrapProblems(
    RenderParagraph paragraph,
    String text,
    String where,
  ) {
    final lines = ParagraphLines(paragraph);
    final shown = lines.lines.join(' / ');
    final problems = <String>[
      for (final p in lines.lineEdgeViolations()) '$where: $p',
    ];
    final width = paragraph.constraints.maxWidth;
    for (final part in bracketed(text)) {
      // かたまりとして描いた幅（字と字の間に幅の無い字を挟むので、字と字の
      // 間の詰めが切れる分だけ普通の文より少し広いことがある）。
      final painter = TextPainter(
        text: TextSpan(
          style: paragraph.text.style,
          children: [
            for (final (i, char) in part.characters.indexed) ...[
              if (i > 0)
                const TextSpan(
                  text: wordJoiner,
                  style: TextStyle(letterSpacing: 0),
                ),
              TextSpan(text: char),
            ],
          ],
        ),
        textDirection: TextDirection.ltr,
        textScaler: paragraph.textScaler,
        locale: paragraph.locale,
      )..layout();
      final fits = painter.width <= width;
      painter.dispose();
      if (!fits) continue;
      final start = lines.visible.replaceAll(nbsp, ' ').indexOf(part);
      if (start < 0) continue;
      if (lines.breaksWithin(start, start + part.length).isNotEmpty) {
        problems.add('$where: 入る幅なのに「$part」が折れている: $shown');
      }
    }
    final plain = plainLineCount(paragraph, text);
    if (lines.lines.length > plain) {
      problems.add('$where: 普通のTextより行が多い（$plain行）: $shown');
    }
    return problems;
  }

  /// 描いた画素で、[button]の塗りの上端・下端と、名前の字（塗りの色と
  /// はっきり違う画素）の上端・下端の間（px）。角の丸みは避け、左右の端から
  /// 24pxより内側だけを見る。
  Future<({int top, int bottom})> inkGaps(
    WidgetTester tester,
    Finder button,
  ) async {
    final rect = tester.getRect(button);
    late RenderRepaintBoundary boundary;
    for (final element
        in find
            .ancestor(of: button, matching: find.byType(RepaintBoundary))
            .evaluate()) {
      final candidate = element.renderObject! as RenderRepaintBoundary;
      final bounds = candidate.localToGlobal(Offset.zero) & candidate.size;
      if (bounds.contains(rect.topLeft - const Offset(2, 2)) &&
          bounds.contains(rect.bottomRight + const Offset(2, 2))) {
        boundary = candidate;
        break;
      }
    }
    final origin = boundary.localToGlobal(Offset.zero);
    final (bytes, width) = (await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final width = image.width;
      image.dispose();
      return (data!, width);
    }))!;
    final fill = tester
        .widget<Material>(
          find.descendant(of: button, matching: find.byType(Material)),
        )
        .color!;
    double distance(int x, int y) {
      final i = (y * width + x) * 4;
      final r = bytes.getUint8(i) - fill.r * 255;
      final g = bytes.getUint8(i + 1) - fill.g * 255;
      final b = bytes.getUint8(i + 2) - fill.b * 255;
      return r * r + g * g + b * b;
    }

    final left = (rect.left - origin.dx + 24).round();
    final right = (rect.right - origin.dx - 24).round();
    int? fillTop, fillBottom, inkTop, inkBottom;
    for (
      var y = (rect.top - origin.dy - 3).round();
      y <= (rect.bottom - origin.dy + 3).round();
      y++
    ) {
      var filled = 0;
      for (var x = left; x < right; x++) {
        if (distance(x, y) < 40 * 40) filled++;
      }
      if (filled >= (right - left) * 0.2) {
        fillTop ??= y;
        fillBottom = y;
      }
    }
    for (var y = fillTop!; y <= fillBottom!; y++) {
      for (var x = left; x < right; x++) {
        if (distance(x, y) > 60 * 60) {
          inkTop ??= y;
          inkBottom = y;
          break;
        }
      }
    }
    return (top: inkTop! - fillTop, bottom: fillBottom - inkBottom!);
  }

  /// 容量削減の画面の「整理する」の行の名前と、「全データを削除」の確認の
  /// ボタンを、幅[width]・文字[scale]倍で調べ、見つけた問題を返す。
  /// [platform]がnullでなければ、その機器の詰め方（PC は
  /// VisualDensity.compact）で調べる。
  Future<List<String>> checkStorageLabels(
    WidgetTester tester,
    List<SingleChildWidget> providers, {
    required String language,
    required double width,
    required double scale,
    TargetPlatform? platform,
  }) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      final service = ScriptedStorage();
      final l10n = await showStorageScreen(
        tester,
        providers,
        service,
        size: Size(width, 800),
        language: language,
      );
      service.scans.last.complete(storageBreakdownOf());
      service.deviceQueries.last.complete(storageTestDevice);
      await tester.pump();
      final where =
          '${width.toInt()}px・文字$scale倍'
          '${platform == null ? '' : '・${platform.name}の詰め方'}';
      final problems = <String>[];
      final erase = l10n.storageEraseAllButton;
      for (final title in [
        l10n.storageClearCacheButton,
        l10n.storageRemoveUnusedMaterialsButton,
        l10n.storageEmptyTrashButton,
        l10n.storageOrganizeProjectsButton,
        erase,
      ]) {
        final row = find.text(title, skipOffstage: false);
        await tester.scrollUntilVisible(row.first, 120);
        await tester.pump();
        problems.addAll(
          wrapProblems(
            paragraphOf(tester, row.first),
            title,
            '$where 行「$title」',
          ),
        );
      }

      await tester.tap(find.text(erase, skipOffstage: false).first);
      await tester.pumpAndSettle();
      final button = find.byType(FilledButton);
      final label = find.descendant(of: button, matching: find.text(erase));
      final paragraph = paragraphOf(tester, label);
      problems.addAll(wrapProblems(paragraph, erase, '$where ボタン'));
      // 名前が折れても、描いた字はボタンの縁から離れている。
      final gaps = await inkGaps(tester, button);
      if (gaps.top < 8 || gaps.bottom < 8) {
        problems.add(
          '$where ボタン: 字と縁の間が上${gaps.top}px・下${gaps.bottom}px'
          '（${ParagraphLines(paragraph).lines.join(' / ')}）',
        );
      }
      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();
      return problems;
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    }
  }

  // 書体の読み込み（1回に約40MB）を言語ごとに1回にするため、幅・文字の
  // 大きさ・詰め方は1つのテストの中で回す。
  for (final language in ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant']) {
    testWidgets('$language: the storage row titles and the erase-all button '
        'wrap without splitting a bracket and keep the button padding '
        '(320/360/412px, text x1/x1.3/x2, phone and compact density)', (
      tester,
    ) async {
      final providers = await bootstrapStorageScreen(tester);
      final problems = <String>[];
      for (final width in [320.0, 360.0, 412.0]) {
        for (final scale in [1.0, 1.3, 2.0]) {
          // PC（Linux 等）の詰めた表示は、ボタンの上下の余白から8pxずつ引く。
          for (final platform in [null, TargetPlatform.linux]) {
            problems.addAll(
              await checkStorageLabels(
                tester,
                providers,
                language: language,
                width: width,
                scale: scale,
                platform: platform,
              ),
            );
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  }

  testWidgets('fr: the project detail writes the project size the French way', (
    tester,
  ) async {
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    final dir = Directory.systemTemp.createTempSync('niarim_size_fr_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => dir.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'fr',
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    tester.view.physicalSize = const Size(412, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    appRouter.go('/home');
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    final projects = tester
        .element(find.byType(Navigator).first)
        .read<ProjectService>();
    final project = (await tester.runAsync(
      () => projects.createProject(
        name: 'taille',
        fps: 2,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 36,
      ),
    ))!;
    appRouter.push('/project/${project.id}');
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    final screen = tester.element(find.byType(ProjectDetailScreen));
    final l10n = AppLocalizations.of(screen)!;
    // 大きさの行（「Taille」の右）の値。
    final row = find.ancestor(
      of: find.text(l10n.projectDetailInfoSize, skipOffstage: false),
      matching: find.byType(Row),
    );
    final values = [
      for (final t in tester.widgetList<Text>(
        find.descendant(of: row.first, matching: find.byType(Text)),
      ))
        t.data ?? '',
    ]..remove(l10n.projectDetailInfoSize);
    expect(
      values,
      contains(matches(RegExp('^\\d+(,\\d)?$nbsp(o|Ko|Mo)\$'))),
      reason: 'the size row shows $values',
    );
    appRouter.go('/home');
    await tester.pumpAndSettle();
  });
}
