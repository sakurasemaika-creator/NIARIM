import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/services/home_widget_refresh.dart';
import 'package:niarim/services/home_widget_service.dart';
import 'package:niarim/services/shortcut_widget_renderer.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/color_channels.dart';

/// ホーム画面ウィジェットが、**ランチャー上のいろいろなマス目サイズに
/// 置かれたときどう見えるか**を、実際に描いて検証する。
///
/// この開発環境にはAndroid端末もエミュレータも（KVMも）無いため、ランチャー
/// そのもののスクリーンショットは撮れない。ただしウィジェットの表示は
/// - アプリが焼いた正方形のPNG（`shortcut_widget_renderer.dart`）
/// - それを`ImageView`の`scaleType="fitCenter"`で表示するだけのレイアウト
///   （`widget_shortcut.xml`）
/// という2要素しかないので、**`BoxFit.contain`＋実際のマス目寸法**という
/// 同じ条件で再現でき、
/// - 極端に横長／縦長のマスでも意匠が切れず中央に収まるか
/// - 小さいマスでも文字が潰れず読めるか
/// - Android 12以降のウィジェットホストが施す角丸マスクで意匠が欠けないか
/// は機械的に確認できる。
///
/// 生成した一覧画像は`build/home-widget-cell-sizes/`に残るので目視でも
/// 確認できる。ランチャーの壁紙・アイコンとの並びといった「実機でしか
/// 分からないもの」だけが残る。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final out = Directory('build/home-widget-cell-sizes');

  /// `appwidget-provider`の`android:minResizeWidth`等（"110dp"形式）を読む。
  /// **宣言した下限と実際の可読性を結び付けて**検証するため、テスト側で
  /// 値を二重に持たずXMLから直接読む。
  double dimenOf(String file, String attr) {
    final xml = File('android/app/src/main/res/xml/$file').readAsStringSync();
    final m = RegExp('android:$attr="([0-9.]+)dp"').firstMatch(xml);
    expect(m, isNotNull, reason: '$file に $attr が宣言されていない');
    return double.parse(m!.group(1)!);
  }

  /// ランチャーのマス目1つぶんのおおよその論理サイズ（dp）。
  /// Androidのマス目換算式 minWidth = 70*n - 30 の逆で、1マスは約70dp。
  const cellW = 70.0;
  const cellH = 70.0;

  /// Android 12以降のウィジェットホストがウィジェットへ施す角丸
  /// （`system_app_widget_background_radius`＝28dp）と、ホスト側の余白。
  const hostCornerRadius = 28.0;
  const hostPadding = 8.0;

  /// 検証するマス目の大きさ（列×行）。ウィジェットは
  /// `resizeMode="horizontal|vertical"`なので、ユーザーが自由に伸ばせる。
  /// 1x1は`minResizeWidth`(110dp≒2マス)より小さく**到達できない**ので
  /// 入れていない。到達できる最小は下の`smallest`で別途検証する。
  const cells = <({String name, int cols, int rows})>[
    (name: '2x2_default', cols: 2, rows: 2), // targetCellWidth/Heightの既定
    (name: '4x2_wide', cols: 4, rows: 2),
    (name: '2x4_tall', cols: 2, rows: 4),
    (name: '4x4_large', cols: 4, rows: 4),
    (name: '5x3_widest', cols: 5, rows: 3),
  ];

  Future<void> loadFonts(WidgetTester tester) async {
    await tester.runAsync(() async {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = manifest.listAssets();

      Future<void> loadFamily(String family, String needle) async {
        final matches = assets.where((a) => a.contains(needle)).toList();
        if (matches.isEmpty) return;
        final loader = FontLoader(family)
          ..addFont(rootBundle.load(matches.first));
        await loader.load();
      }

      Future<void> loadSdkMaterialIcons() async {
        final flutterRoot = Platform.environment['FLUTTER_ROOT'];
        if (flutterRoot == null) return;
        final file = File(
          '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        );
        if (!file.existsSync()) return;
        final data = ByteData.sublistView(
          Uint8List.fromList(await file.readAsBytes()),
        );
        final loader = FontLoader('MaterialIcons')
          ..addFont(Future<ByteData>.value(data));
        await loader.load();
      }

      await Future.wait([
        loadFamily('Kuramubon', 'assets/fonts/Kuramubon.otf'),
        loadFamily('HakkouMincho', 'assets/fonts/HakkouMincho.ttf'),
        loadSdkMaterialIcons(),
      ]);
    });
  }

  testWidgets('どのマス目サイズでも意匠が切れず、文字が読める大きさで収まる', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await loadFonts(tester);

    final theme = ThemeService();
    theme.themeData; // activeColorSchemeを実アプリと同じ状態にする
    final widgets = HomeWidgetService();
    final l10n = lookupAppLocalizations(const Locale('ja'));

    for (final kind in const [HomeWidgetKind.create, HomeWidgetKind.plaza]) {
      final design = (await tester.runAsync(
        () => renderShortcutWidgetImage(
          icon: shortcutWidgetIcon(kind),
          label: shortcutWidgetLabel(l10n, kind),
          subLabel: shortcutWidgetSubLabel(l10n, kind),
          colors: shortcutWidgetColors(widgets, kind),
          foreground: shortcutWidgetForeground(widgets, theme, kind),
        ),
      ))!;

      // 宣言した下限そのもの（＝ユーザーが縮められる限界）も必ず見る。
      final minW = dimenOf(
        'widget_${kind == HomeWidgetKind.plaza ? 'plaza' : 'create'}_info.xml',
        'minResizeWidth',
      );
      final minH = dimenOf(
        'widget_${kind == HomeWidgetKind.plaza ? 'plaza' : 'create'}_info.xml',
        'minResizeHeight',
      );
      final sizes = <({String name, double w, double h})>[
        (name: 'smallest_declared', w: minW, h: minH),
        for (final c in cells)
          (name: c.name, w: cellW * c.cols, h: cellH * c.rows),
      ];

      for (final cell in sizes) {
        final hostW = cell.w;
        final hostH = cell.h;

        // ネイティブ側と同じ条件で置く：ホストの角丸でマスクし、
        // 余白の内側へ fitCenter（= BoxFit.contain）で入れる。
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final hostRect = Rect.fromLTWH(0, 0, hostW, hostH);
        canvas.save();
        canvas.clipRRect(
          RRect.fromRectAndRadius(
            hostRect,
            const Radius.circular(hostCornerRadius),
          ),
        );
        final inner = hostRect.deflate(hostPadding);
        final scale =
            (inner.width / design.width) < (inner.height / design.height)
            ? inner.width / design.width
            : inner.height / design.height;
        final drawW = design.width * scale;
        final drawH = design.height * scale;
        final dst = Rect.fromLTWH(
          inner.left + (inner.width - drawW) / 2,
          inner.top + (inner.height - drawH) / 2,
          drawW,
          drawH,
        );
        canvas.drawImageRect(
          design,
          Rect.fromLTWH(
            0,
            0,
            design.width.toDouble(),
            design.height.toDouble(),
          ),
          dst,
          Paint()..filterQuality = FilterQuality.high,
        );
        canvas.restore();

        final picture = recorder.endRecording();
        final shot = (await tester.runAsync(
          () => picture.toImage(hostW.round(), hostH.round()),
        ))!;
        picture.dispose();

        // 保存（目視確認用）
        final png = await tester.runAsync(
          () => shot.toByteData(format: ui.ImageByteFormat.png),
        );
        final bytes = png?.buffer.asUint8List();
        if (bytes != null) {
          await tester.runAsync(() async {
            out.createSync(recursive: true);
            await File(
              '${out.path}/${kind.name}_${cell.name}.png',
            ).writeAsBytes(bytes);
          });
        }

        // ── 検証 ──────────────────────────────────────────────
        final data = (await tester.runAsync(
          () => shot.toByteData(format: ui.ImageByteFormat.rawRgba),
        ))!;
        Color at(int x, int y) {
          final o = (y * shot.width + x) * 4;
          return Color.fromARGB(
            data.getUint8(o + 3),
            data.getUint8(o),
            data.getUint8(o + 1),
            data.getUint8(o + 2),
          );
        }

        // 1. 意匠は必ず正方形のまま（縦横比が保たれ、切れていない）。
        //    fitCenterなので短辺いっぱい・長辺は余白になる。
        expect(
          (drawW - drawH).abs(),
          lessThan(1.0),
          reason: '${kind.name}/${cell.name}: 縦横比が崩れている',
        );
        expect(
          drawW,
          lessThanOrEqualTo(inner.width + 0.5),
          reason: '${kind.name}/${cell.name}: 横にはみ出している',
        );
        expect(
          drawH,
          lessThanOrEqualTo(inner.height + 0.5),
          reason: '${kind.name}/${cell.name}: 縦にはみ出している',
        );

        // 2. ホストの角丸マスクで意匠が欠けていない。
        //    タイル本体は意匠PNGの中央部（外周は影用の余白）にあるので、
        //    そこがマスクの内側に収まっていることを確認する。
        const marginRatio =
            ShortcutWidgetDesign.shadowMargin /
            (ShortcutWidgetDesign.tileSize +
                ShortcutWidgetDesign.shadowMargin * 2);
        final tileRect = Rect.fromLTRB(
          dst.left + drawW * marginRatio,
          dst.top + drawH * marginRatio,
          dst.right - drawW * marginRatio,
          dst.bottom - drawH * marginRatio,
        );
        for (final corner in [
          tileRect.topLeft,
          tileRect.topRight,
          tileRect.bottomLeft,
          tileRect.bottomRight,
        ]) {
          final inMask =
              corner.dx >= hostPadding - 0.5 &&
              corner.dy >= hostPadding - 0.5 &&
              corner.dx <= hostW - hostPadding + 0.5 &&
              corner.dy <= hostH - hostPadding + 0.5;
          expect(
            inMask,
            isTrue,
            reason:
                '${kind.name}/${cell.name}: '
                'タイルの角$cornerがホストの余白($hostPadding)の外へ出ている',
          );
        }

        // 3. 実際に前景色（アイコン・文字）の画素が出ている＝潰れていない。
        final fg = shortcutWidgetForeground(widgets, theme, kind);
        var fgHits = 0;
        for (var y = dst.top.ceil(); y < dst.bottom.floor(); y++) {
          for (var x = dst.left.ceil(); x < dst.right.floor(); x++) {
            final c = at(x, y);
            if ((c.red8 - fg.red8).abs() <= 20 &&
                (c.green8 - fg.green8).abs() <= 20 &&
                (c.blue8 - fg.blue8).abs() <= 20) {
              fgHits++;
            }
          }
        }
        // 縮小されるほど画素は減るが、宣言した下限でも一定量は残るはず。
        // ここが落ちたら、minResizeWidth/Heightを上げるか意匠を見直す。
        expect(
          fgHits,
          greaterThan(120),
          reason:
              '${kind.name}/${cell.name}: '
              'アイコン・文字が潰れて見えなくなっている（前景画素$fgHits）',
        );

        // 4. ラベルの実効フォントサイズ。意匠は論理170px幅
        //    （タイル150＋影用の余白10×2）で描いてあり、その中でラベルは
        //    18px。縮小率を掛けた実効サイズが小さすぎないことを確かめる。
        final effectiveLabelPx =
            ShortcutWidgetDesign.labelSize *
            (drawW /
                (ShortcutWidgetDesign.tileSize +
                    ShortcutWidgetDesign.shadowMargin * 2));
        expect(
          effectiveLabelPx,
          greaterThanOrEqualTo(9.0),
          reason:
              '${kind.name}/${cell.name}: '
              'ラベルが実効${effectiveLabelPx.toStringAsFixed(1)}pxまで潰れている',
        );

        shot.dispose();
      }
      design.dispose();
    }
  });
}
