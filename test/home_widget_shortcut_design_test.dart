import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/splash/splash_screen.dart';
import 'package:niarim/services/home_widget_refresh.dart';
import 'package:niarim/services/home_widget_service.dart';
import 'package:niarim/services/shortcut_widget_renderer.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/color_channels.dart';

/// 「作品をつくる」「作品広場」のホーム画面ウィジェットが、起動画面
/// （[SplashScreen]）にある2つの導線ボタンと**同じデザイン**になっている
/// ことを、実際に描いた画素で検証する。
///
/// ウィジェットの意匠はネイティブのレイアウトではなくアプリ側で焼いた
/// PNG（`shortcut_widget_renderer.dart`）なので、そのPNGの画素と、
/// 本物の起動画面をレンダリングした画素を突き合わせれば、実機を待たずに
/// 一致を確認できる。生成物は`build/home-widget-shortcut-design/`へ
/// 保存するので目視でも比べられる。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final out = Directory('build/home-widget-shortcut-design');

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

      // Materialアイコンはpubspecのassetではなくflutter本体に同梱されて
      // いるため、FLUTTER_ROOTから直接読む（読めない環境では豆腐になる
      // だけで、色の検証には影響しない）。
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
        loadFamily('HakkouMincho', 'assets/fonts/HakkouMincho.ttf'),
        loadFamily('Kuramubon', 'assets/fonts/Kuramubon.otf'),
        loadSdkMaterialIcons(),
      ]);
    });
  }

  /// [image]の画素を取り出す（`toByteData`は本物の非同期処理なので
  /// runAsyncが要る）。
  Future<ByteData> pixelsOf(WidgetTester tester, ui.Image image) async {
    final data = await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    return data!;
  }

  Color pixelAt(ByteData data, int width, int x, int y) {
    final offset = (y * width + x) * 4;
    return Color.fromARGB(
      data.getUint8(offset + 3),
      data.getUint8(offset),
      data.getUint8(offset + 1),
      data.getUint8(offset + 2),
    );
  }

  Future<void> savePng(WidgetTester tester, ui.Image image, String name) async {
    final data = await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.png),
    );
    final bytes = data?.buffer.asUint8List();
    if (bytes == null) return;
    await tester.runAsync(() async {
      out.createSync(recursive: true);
      await File('${out.path}/$name.png').writeAsBytes(bytes);
    });
  }

  /// `LinearGradient(begin: topLeft, end: bottomRight)`（起動画面のボタンと
  /// ウィジェット画像が両方使う向き）で、[rect]内の点[p]に出るはずの色。
  ///
  /// 角丸の内側という条件で「端の色そのもの」を拾える点は取れないため、
  /// 端の色と比べるのではなく**その位置の理論値**と比べる。これで
  /// グラデーションの向き・2色の組み合わせの両方を同時に検証できる。
  Color gradientColorAt(Rect rect, List<Color> colors, Offset p) {
    final d = rect.bottomRight - rect.topLeft;
    final v = p - rect.topLeft;
    final t = ((v.dx * d.dx + v.dy * d.dy) / (d.dx * d.dx + d.dy * d.dy)).clamp(
      0.0,
      1.0,
    );
    return Color.lerp(colors.first, colors.last, t)!;
  }

  void expectCloseColor(Color actual, Color expected, {int tolerance = 6}) {
    expect(
      (actual.red8 - expected.red8).abs(),
      lessThanOrEqualTo(tolerance),
      reason: 'R: $actual vs $expected',
    );
    expect(
      (actual.green8 - expected.green8).abs(),
      lessThanOrEqualTo(tolerance),
      reason: 'G: $actual vs $expected',
    );
    expect(
      (actual.blue8 - expected.blue8).abs(),
      lessThanOrEqualTo(tolerance),
      reason: 'B: $actual vs $expected',
    );
  }

  testWidgets('ウィジェット画像が起動画面ボタンと同じ角丸・グラデーション・前景色で描かれる', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await loadFonts(tester);

    // ThemeServiceのthemeDataを一度作らせて、activeColorSchemeを
    // 実アプリと同じ状態にする（起動画面のボタンが読むのと同じ値）。
    final theme = ThemeService();
    final scheme = theme.themeData.colorScheme;
    final widgets = HomeWidgetService();
    final l10n = lookupAppLocalizations(const Locale('ja'));

    for (final kind in const [HomeWidgetKind.create, HomeWidgetKind.plaza]) {
      final colors = shortcutWidgetColors(widgets, kind);
      // テーマ追従のとき、起動画面のボタンとまったく同じ2色になっている。
      expect(
        colors,
        kind == HomeWidgetKind.plaza
            ? [scheme.secondary, scheme.secondaryContainer]
            : [scheme.primary, scheme.primaryContainer],
      );

      final image = (await tester.runAsync(
        () => renderShortcutWidgetImage(
          icon: shortcutWidgetIcon(kind),
          label: shortcutWidgetLabel(l10n, kind),
          subLabel: shortcutWidgetSubLabel(l10n, kind),
          colors: colors,
          foreground: shortcutWidgetForeground(widgets, theme, kind),
          scale: 3,
        ),
      ))!;
      await savePng(tester, image, 'widget_${kind.name}');

      final data = await pixelsOf(tester, image);
      final w = image.width;
      const margin = ShortcutWidgetDesign.shadowMargin;
      const tile = ShortcutWidgetDesign.tileSize;
      int px(double logical) => (logical * 3).round();

      // 画像の四隅（タイルの外側）は透明。＝角丸のタイルとして切り抜かれて
      // いる。ここが不透明だと、ホーム画面で四角い色板に見えてしまう。
      expect(pixelAt(data, w, 1, 1).a, lessThan(0.05));

      // タイル内が、起動画面と同じ左上→右下のグラデーションになっている。
      // 中央にはアイコンと文字が乗るので、高さ中央の左右端寄り
      // （＝アイコンの外側）を複数点サンプリングし、その位置の理論値と
      // 突き合わせる。
      const tileRect = Rect.fromLTWH(margin, margin, tile, tile);
      for (final f in [0.05, 0.2, 0.8, 0.95]) {
        final p = Offset(margin + tile * f, margin + tile / 2);
        expectCloseColor(
          pixelAt(data, w, px(p.dx), px(p.dy)),
          gradientColorAt(tileRect, colors, p),
          tolerance: 10,
        );
      }

      // 中央付近にアイコン・文字が、テーマの「メニュー背景色」
      // （＝起動画面の導線ボタンと同じ前景色）で実際に描かれている。
      final fg = shortcutWidgetForeground(widgets, theme, kind);
      expect(fg, theme.current.menuBgColor);
      var foregroundHits = 0;
      for (var y = px(margin + 30); y < px(margin + tile - 20); y++) {
        for (var x = px(margin + 20); x < px(margin + tile - 20); x++) {
          final c = pixelAt(data, w, x, y);
          if ((c.red8 - fg.red8).abs() <= 12 &&
              (c.green8 - fg.green8).abs() <= 12 &&
              (c.blue8 - fg.blue8).abs() <= 12) {
            foregroundHits++;
          }
        }
      }
      expect(
        foregroundHits,
        greaterThan(200),
        reason: '${kind.name}: アイコン・ラベルが前景色で描かれていない',
      );

      image.dispose();
    }
  });

  testWidgets('起動画面の実描画と、ウィジェット画像の配色が一致する', (tester) async {
    SharedPreferences.setMockInitialValues({});
    // 起動画面は表示中にexportsフォルダの先読みを始めるため、
    // path_providerを差し替えておかないと未実装例外で落ちる。
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    final tempDir = Directory.systemTemp.createTempSync(
      'niarim_splash_design_',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });
    await loadFonts(tester);
    tester.view.physicalSize = const Size(720, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final providers = await tester.runAsync(buildAppProviders);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MultiProvider(
          providers: providers!,
          child: Builder(
            builder: (context) {
              final themeService = context.watch<ThemeService>();
              return MaterialApp(
                theme: themeService.themeData,
                locale: const Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: const SplashScreen(),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final shot = (await tester.runAsync(
      () => boundary.toImage(pixelRatio: 1),
    ))!;
    await savePng(tester, shot, 'splash_screen');
    final shotData = await pixelsOf(tester, shot);

    final scheme = ThemeService.activeColorScheme;
    // 起動画面の2つのボタンを、ボタンの矩形から直接サンプリングする。
    // （どちらのボタンかはラベルで特定する。）
    final l10n = lookupAppLocalizations(const Locale('ja'));
    for (final entry in <(HomeWidgetKind, String)>[
      (HomeWidgetKind.plaza, l10n.splashCommunityButtonSubtitle),
      (HomeWidgetKind.create, l10n.splashCreateButton),
    ]) {
      final (kind, labelText) = entry;
      final tile = tester.getRect(
        find
            .ancestor(
              of: find.text(labelText),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final expected = kind == HomeWidgetKind.plaza
          ? [scheme.secondary, scheme.secondaryContainer]
          : [scheme.primary, scheme.primaryContainer];
      expect(tile.width, ShortcutWidgetDesign.tileSize, reason: 'ボタンの矩形');
      // 実際に描かれた起動画面のボタンが、この2色の左上→右下グラデーション
      // になっていることを、アイコン・文字を避けた複数点で確かめる。
      for (final f in [0.05, 0.2, 0.8, 0.95]) {
        final p = Offset(
          tile.left + tile.width * f,
          tile.top + tile.height / 2,
        );
        expectCloseColor(
          pixelAt(shotData, shot.width, p.dx.round(), p.dy.round()),
          gradientColorAt(tile, expected, p),
          tolerance: 10,
        );
      }

      // 同じ2色でウィジェット画像も描かれる（＝デザインが揃っている）。
      expect(shortcutWidgetColors(HomeWidgetService(), kind), expected);
    }
    shot.dispose();
  });
}
