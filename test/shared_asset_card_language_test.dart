// 共有カードの画像（ブラシ・トーン・スタンプの完全共有カード）に焼き込む文が、
// 作ったときのアプリの言語で出ることを見張る（DISC108）。
//
// 以前は「完全共有カード」「素材の見本・使用画像」「この画像をNIARIMの「読込」
// から選ぶと…」「QRはカードの識別用です」等を日本語だけでPNGへ描いていて、
// 英語で作っても日本語のカードになった（どの言語でも同じ画像）。
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/widgets/brush_panel.dart';
import 'package:niarim/config/font_fallback.dart';
import 'package:niarim/models/tone.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/shared_asset_card_service.dart';
import 'package:niarim/services/tone_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'font_coverage_test.dart' show coverageOf;
import 'helpers/fake_share_channel.dart';
import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/pump_real_async.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final share = FakeShareChannel();
  setUp(share.install);
  tearDown(share.remove);

  /// ブラシの一覧の行のメニューから共有カードを作り、できたカードの画素を返す。
  Future<(Uint8List, int)> exportCardFromPanel(
    WidgetTester tester,
    Locale locale,
  ) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    tester.view.physicalSize = const Size(450, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (themeContext) => MaterialApp(
            theme: themeContext.watch<ThemeService>().themeData,
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: BrushPanel(onClose: () {})),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    final l10n = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    )!;
    final panel = tester.element(find.byType(ListTile).first);
    final name = panel.read<BrushService>().brushes.first.name;
    final row = find.ancestor(
      of: find.text(name).first,
      matching: find.byType(ListTile),
    );
    final menu = find.descendant(
      of: row.first,
      matching: find.byIcon(Icons.more_vert),
    );
    await tester.ensureVisible(menu);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(menu);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text(l10n.shareCardExportMenu).last);
    // カードの作成（見本の描画・PNGの書き出し・読み直し）は本物の非同期処理。
    for (var i = 0; i < 40; i++) {
      await pumpRealAsync(tester, const Duration(milliseconds: 200));
      if (find.text(l10n.shareCardCreatedTitle).evaluate().isNotEmpty) break;
    }
    expect(find.text(l10n.shareCardCreatedTitle), findsOneWidget);
    final image = tester.widget<Image>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(Image),
      ),
    );
    final file = (image.image as FileImage).file;
    final bytes = (await tester.runAsync(file.readAsBytes))!;
    final pixels = (await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      final width = frame.image.width;
      frame.image.dispose();
      codec.dispose();
      return (data!.buffer.asUint8List(), width);
    }))!;
    final dir = Directory('build/share-card')..createSync(recursive: true);
    await tester.runAsync(
      () => File(
        '${dir.path}/panel_brush_${locale.toLanguageTag()}.png',
      ).writeAsBytes(bytes),
    );
    // ダイアログを閉じて次の言語へ。
    await tester.tap(find.text(l10n.commonClose));
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    return pixels;
  }

  /// [top]〜[bottom]の行の画素が2枚で同じか。
  bool sameRows((Uint8List, int) a, (Uint8List, int) b, int top, int bottom) {
    final width = a.$2;
    for (var y = top; y < bottom; y++) {
      for (var x = 0; x < width * 4; x++) {
        if (a.$1[y * width * 4 + x] != b.$1[y * width * 4 + x]) return false;
      }
    }
    return true;
  }

  testWidgets('英語で作った共有カードの文は日本語のカードと違う（説明・見出し・'
      'QRの注記がその言語で焼かれる）', (tester) async {
    await loadAppFonts(tester);
    final ja = await exportCardFromPanel(tester, const Locale('ja'));
    final en = await exportCardFromPanel(tester, const Locale('en'));
    final ko = await exportCardFromPanel(tester, const Locale('ko'));
    // 1600pxの縦の中で、文だけが並ぶ帯：見本の見出し（約290〜345）、
    // 「完全共有カード」とその説明（約920〜1100）、QRの右の注記（約1140〜1300）。
    for (final (label, top, bottom) in const [
      ('見本の見出し', 290, 345),
      ('完全共有カードと説明', 920, 1100),
      ('QRの注記', 1140, 1300),
    ]) {
      expect(
        sameRows(ja, en, top, bottom),
        isFalse,
        reason: '英語のカードの「$label」が日本語のカードと同じ画素（日本語のまま）',
      );
      expect(
        sameRows(ja, ko, top, bottom),
        isFalse,
        reason: '韓国語のカードの「$label」が日本語のカードと同じ画素（日本語のまま）',
      );
    }
  });

  /// ブラシの名前の長いもの（利用者の文。最小の大きさでも入らなければ…で
  /// 終わってよいのは名前だけ）。
  const longName =
      'Pinceau d’encrage très doux pour les contours de cheveux 0.3';

  testWidgets('7言語で作ったカードの文は、どれも枠の中に収まる（…で切らない）・'
      '同梱フォントに字がある', (tester) async {
    await loadAppFonts(tester);
    final card = coverageOf(['NotoSerifJP', ...kBodyFontFallback]);
    final problems = <String>[];
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      for (final (kind, images, rendered) in const [
        ('brush', 0, true),
        ('tone', 0, false),
        ('stamp', 1, true),
        ('brush', 6, true),
      ]) {
        for (final name in const ['ペン', longName]) {
          final blocks = SharedAssetCardService.debugCardTextLayout(
            l10n,
            kind: kind,
            name: name,
            sourceImageCount: images,
            strokeRendered: rendered,
          );
          for (final block in blocks) {
            final where =
                '${locale.toLanguageTag()} $kind/$images: '
                '«${block.text}»';
            if (!block.fits && !block.userText) {
              problems.add('$where が枠に入らない（${block.fontSize}px）');
            }
            if (block.size.width > block.box.width + 0.5 ||
                (block.fits && block.size.height > block.box.height + 0.5)) {
              problems.add('$where が枠からはみ出す ${block.size}');
            }
            if (block.userText) continue;
            for (final rune in block.text.runes) {
              if (rune <= 0x20 || card.contains(rune)) continue;
              problems.add(
                '$where の字 ${String.fromCharCode(rune)} '
                '(U+${rune.toRadixString(16)}) が同梱フォントに無い',
              );
            }
          }
          // 名前は最小の大きさでも2行まで。
          final nameBlock = blocks.firstWhere((b) => b.userText);
          expect(
            nameBlock.size.height,
            lessThanOrEqualTo(nameBlock.box.height),
          );
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  testWidgets('7言語のカードを作って画像を残す（build/share-card）。日本語のカードの'
      '文は日本語、英語のカードには日本語が入らない', (tester) async {
    // 文字を実際の字形で焼く（目視の確認に使う）。
    await loadAppFonts(tester);
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      final dir = Directory('build/share-card')..createSync(recursive: true);
      final brushes = BrushService();
      await brushes.init();
      final tones = ToneService();
      await tones.init();
      final pen = brushes.brushes.first;
      final tone = Tone(
        id: 'share-card-language-tone',
        name: 'Trame de points 10 %',
        patternName: tones.tones.first.patternName,
      );
      tones.addTone(tone);
      final japanese = RegExp(r'[぀-ヿ]');
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = lookupAppLocalizations(locale);
        final tag = locale.toLanguageTag();
        final brushCard = await SharedAssetCardService.exportBrush(
          brushes,
          pen,
          l10n: l10n,
        );
        await brushCard.copy('${dir.path}/brush_$tag.png');
        final toneCard = await SharedAssetCardService.exportTone(
          tones,
          tone,
          l10n: l10n,
        );
        await toneCard.copy('${dir.path}/tone_$tag.png');
        // 読み込みに必要な中身は言語に関係なく同じ。
        expect((await SharedAssetCardService.inspect(brushCard)).kind, 'brush');
        expect((await SharedAssetCardService.inspect(toneCard)).kind, 'tone');
        final texts = [
          for (final block in SharedAssetCardService.debugCardTextLayout(
            l10n,
            kind: 'brush',
            name: 'x',
            sourceImageCount: 0,
          ))
            block.text,
        ].join('\n');
        if (locale.languageCode == 'ja') {
          expect(texts, contains(l10n.shareCardCompleteTitle));
        } else {
          expect(japanese.hasMatch(texts), isFalse, reason: '$tag: $texts');
        }
      }
      brushes.dispose();
      tones.dispose();
    });
  });
}
