// GIFには公式エンドマークを付けず、無料会員には隅に小さく半透明のNIARIMのロゴを
// 入れる（所有者の依頼、2026-11-27「gifにはエンドマークではなくウォーターマーク的な
// 感じでNIARIMのロゴを隅に透かしておくのはありですよね」）。付けるかどうかは
// エンドマークと同じ決まり（PremiumService.shouldAppendOfficialEndCard）。
//
// ロゴはバッジの右にアプリ名（エンドマークと同じ書き文字）を半透明の暗い下地に
// 白で並べる（所有者の依頼、2026-11-27「gifで出す透かしはアプリアイコンだけでなく
// アプリ名も出しておいてほしいです。じゃないと宣伝にならないので。」）。小さすぎる
// 絵ではバッジだけ。
//
// 作品の書き出し・メイキング動画のGIFのどのコマにもロゴ（名前つき）が入り、明るい・
// 暗い・紺のコマで名前が読めること、ロゴの所の外の画素は付けないときと同じ
// （パレットを乱さない）こと、利用者のウォーターマークのある隅を避けること、
// 書き出しの画面の文を見張る。
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/corner_logo.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/engine/gif_palette.dart';
import 'package:niarim/engine/making_export.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/scene.dart';
import 'package:niarim/screens/export/export_screen.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/clock_duration_label.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/project_storage.dart';

const _w = 320;
const _h = 180;
const _sceneId = 'Scene0001';
const _layer = Layer(id: 'Layer0001', name: 'L', type: LayerType.normal);
const _mark = Layer(id: 'Mark0001', name: 'W', type: LayerType.watermark);

class _Premium extends PremiumService {
  @override
  bool get hasVerifiedPlayPremium => true;
}

/// A [_w]×[_h] layer: transparent (white paper shows) or filled with [rgb].
Uint8List _filled(int? rgb) {
  final pixels = Uint8List(_w * _h * 4);
  if (rgb == null) return pixels;
  for (var i = 0; i < pixels.length; i += 4) {
    pixels
      ..[i] = (rgb >> 16) & 0xFF
      ..[i + 1] = (rgb >> 8) & 0xFF
      ..[i + 2] = rgb & 0xFF
      ..[i + 3] = 255;
  }
  return pixels;
}

/// The user's own watermark: a red block in the bottom right corner.
Uint8List _bottomRightMark() => _markAt(_w - 90, _h - 40, _w - 6, _h - 6);

/// A small watermark that only the app name would cover (left of the
/// right margin, right of where the badge would go).
Uint8List _underNameMark() => _markAt(_w - 60, _h - 20, _w - 40, _h - 10);

Uint8List _markAt(int left, int top, int right, int bottom) {
  final pixels = Uint8List(_w * _h * 4);
  for (var y = top; y < bottom; y++) {
    for (var x = left; x < right; x++) {
      final i = (y * _w + x) * 4;
      pixels
        ..[i] = 220
        ..[i + 3] = 255;
    }
  }
  return pixels;
}

bool _inside(math.Rectangle<int> area, int x, int y) =>
    x >= area.left &&
    x < area.left + area.width &&
    y >= area.top &&
    y < area.top + area.height;

/// Pixels of [a] and [b] that differ outside [area].
int _differencesOutside(img.Image a, img.Image b, math.Rectangle<int> area) {
  var count = 0;
  for (var y = 0; y < a.height; y++) {
    for (var x = 0; x < a.width; x++) {
      if (_inside(area, x, y)) continue;
      final p = a.getPixel(x, y);
      final q = b.getPixel(x, y);
      if (p.r != q.r || p.g != q.g || p.b != q.b) count++;
    }
  }
  return count;
}

/// Whether [frame] shows the translucent pink badge at [placement]: the left
/// edge of the badge is pink mixed with what is under it, never the opaque
/// badge colour.
bool _showsBadge(img.Image frame, img.Image plain, CornerLogoPlacement at) {
  final x = at.left + (at.size * 0.06).round();
  final y = at.top + at.size ~/ 2;
  final p = frame.getPixel(x, y);
  final under = plain.getPixel(x, y);
  final pinkish = p.r - p.g > 70 && p.r - p.b > 40;
  final translucent =
      (p.r - 0xFF).abs() > 8 ||
      (p.g - 0x5C).abs() > 8 ||
      (p.b - 0x7A).abs() > 8;
  final changed = p.r != under.r || p.g != under.g || p.b != under.b;
  return pinkish && translucent && changed;
}

/// The whole logo (badge and name) of [at].
math.Rectangle<int> _logoRect(CornerLogoPlacement at) =>
    math.Rectangle(at.left, at.top, at.logoWidth, at.size);

/// Whether [frame] shows the app name of [at] readably: white lettering on
/// the darker plate (luminance spread inside the name's box), and the box
/// changed from [plain].
bool _showsName(img.Image frame, img.Image plain, CornerLogoPlacement at) {
  if (!at.showsName) return false;
  final top = at.top + (at.size - at.nameHeight) ~/ 2;
  final lums = <int>[];
  var changed = 0;
  for (var y = top; y < top + at.nameHeight; y++) {
    for (
      var x = at.left + at.nameLeft;
      x < at.left + at.nameLeft + at.nameWidth;
      x++
    ) {
      final p = frame.getPixel(x, y);
      final q = plain.getPixel(x, y);
      if (p.r != q.r || p.g != q.g || p.b != q.b) changed++;
      lums.add((0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b).round());
    }
  }
  lums.sort();
  final light = lums[(lums.length * 0.97).floor()];
  final dark = lums[(lums.length * 0.3).floor()];
  final lettering = lums.where((l) => l >= 200).length;
  return changed > lums.length ~/ 2 && light - dark >= 110 && lettering >= 20;
}

int _colours(img.Image frame) => {
  for (final p in frame) (p.r.toInt() << 16) | (p.g.toInt() << 8) | p.b.toInt(),
}.length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('placement', () {
    test('a tenth of the shorter side, at least 24 px, 3% from the edges', () {
      final big = CornerLogoPlacement(1920, 1080, LogoCorner.bottomRight);
      expect(big.size, 108);
      expect(big.margin, 32);
      expect(big.left, 1920 - 32 - big.logoWidth);
      expect(big.top, 1080 - 32 - 108);
      final gif = CornerLogoPlacement(360, 203, LogoCorner.bottomRight);
      expect(gif.size, 24);
      expect(gif.margin, 6);
      final tiny = CornerLogoPlacement(40, 40, LogoCorner.topLeft);
      expect(tiny.size, 10);
      expect(tiny.left, tiny.margin);
      expect(tiny.top, tiny.margin);
    });

    test('the app name follows the badge, half the badge high; badge only '
        'below ${CornerLogoPlacement.minBadgeForName} px or when the logo '
        'would take more than half the width', () {
      for (final (w, h) in const [(1920, 1080), (480, 270), (360, 203)]) {
        final at = CornerLogoPlacement(w, h, LogoCorner.bottomRight);
        expect(at.showsName, isTrue, reason: '${w}x$h');
        expect(at.nameHeight, (at.size * 0.5).round());
        expect(at.nameLeft, greaterThan(at.size));
        expect(at.logoWidth, greaterThan(at.nameLeft + at.nameWidth));
        expect(at.logoWidth, lessThanOrEqualTo(w / 2));
        // The right corners keep the whole logo inside the margin.
        expect(at.left + at.logoWidth, w - at.margin);
      }
      final big = CornerLogoPlacement(1920, 1080, LogoCorner.bottomRight);
      expect(big.nameHeight, 54);
      // Too small for readable lettering: the badge alone.
      for (final (w, h) in const [(84, 84), (40, 40)]) {
        final at = CornerLogoPlacement(w, h, LogoCorner.bottomRight);
        expect(at.size, lessThan(CornerLogoPlacement.minBadgeForName));
        expect(at.showsName, isFalse);
        expect(at.logoWidth, at.size);
      }
      // Too narrow for the name.
      final narrow = CornerLogoPlacement(120, 400, LogoCorner.bottomLeft);
      expect(narrow.showsName, isFalse);
      expect(narrow.logoWidth, narrow.size);
      // The watermark's clear area covers the name too.
      final left = CornerLogoPlacement(480, 270, LogoCorner.bottomLeft);
      expect(left.clearArea.width, greaterThan(left.logoWidth));
    });

    test('bottom right unless the watermark is there', () {
      expect(chooseLogoCorner((_) => 0), LogoCorner.bottomRight);
      expect(
        chooseLogoCorner((c) => c == LogoCorner.bottomRight ? 5 : 0),
        LogoCorner.bottomLeft,
      );
      // Everywhere: the corner with the least of it.
      expect(
        chooseLogoCorner((c) => c == LogoCorner.topRight ? 1 : 9),
        LogoCorner.topRight,
      );
    });
  });

  test('GIF frames with more than 256 colours keep each pixel near its '
      'colour (the octree lookup sent merged colours to the wrong entry)', () {
    final frame = img.Image(width: 480, height: 270);
    for (var y = 0; y < 270; y++) {
      for (var x = 0; x < 480; x++) {
        final t = y / 270;
        frame.setPixelRgb(
          x,
          y,
          (12 + 60 * t).round(),
          (16 + 30 * t).round(),
          (48 + 80 * t + 20 * (x / 480)).round(),
        );
      }
    }
    final indexed = GifPaletteMapper().paletteFrame(frame);
    expect(indexed.hasPalette, isTrue);
    expect(indexed.palette!.numColors, lessThanOrEqualTo(256));
    var worst = 0;
    for (var y = 0; y < 270; y++) {
      for (var x = 0; x < 480; x++) {
        final p = frame.getPixel(x, y);
        final q = indexed.getPixel(x, y);
        final d = (p.r - q.r).abs() + (p.g - q.g).abs() + (p.b - q.b).abs();
        if (d > worst) worst = d.toInt();
      }
    }
    expect(worst, lessThanOrEqualTo(24));
    // A frame with few colours keeps them (up to the octree's 7 bits).
    final flat = img.Image(width: 8, height: 8)
      ..clear(img.ColorRgb8(255, 255, 255));
    flat.setPixelRgb(1, 1, 30, 60, 220);
    final mapper = GifPaletteMapper();
    final kept = mapper.paletteFrame(flat);
    expect(kept.palette!.numColors, 2);
    final blue = kept.getPixel(1, 1);
    expect([blue.r, blue.g, blue.b], [30, 60, 220]);
    // More distinct colours than the 16-bit table holds (a photograph), with
    // the same mapper reused: every pixel still finds a near palette entry,
    // and the next frame starts clean.
    final dense = img.Image(width: 512, height: 256);
    for (var i = 0; i < 512 * 256; i++) {
      dense.setPixelRgb(
        i % 512,
        i ~/ 512,
        (i >> 14) * 2,
        ((i >> 7) & 127) * 2,
        (i & 127) * 2,
      );
    }
    final reduced = mapper.paletteFrame(dense);
    expect(reduced.palette!.numColors, lessThanOrEqualTo(255));
    var total = 0;
    for (var y = 0; y < 256; y++) {
      for (var x = 0; x < 512; x++) {
        final p = dense.getPixel(x, y);
        final q = reduced.getPixel(x, y);
        total += ((p.r - q.r).abs() + (p.g - q.g).abs() + (p.b - q.b).abs())
            .toInt();
      }
    }
    expect(total / (512 * 256), lessThan(60));
    final again = mapper.paletteFrame(flat);
    expect(again.palette!.numColors, 2);
    final blueAgain = again.getPixel(1, 1);
    expect([blueAgain.r, blueAgain.g, blueAgain.b], [30, 60, 220]);
  });

  group('work export', () {
    late Directory root;
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');

    setUp(() async {
      root = await Directory.systemTemp.createTemp('niarim-gif-logo-');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, (_) async => root.path);
    });
    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null);
      if (await root.exists()) await root.delete(recursive: true);
    });

    /// A light frame (white paper), a dark frame (black) and a dark blue
    /// frame, optionally with the user's watermark on every frame.
    Future<List<img.Image>> export({
      required bool cornerLogo,
      bool watermark = false,
      Uint8List Function() mark = _bottomRightMark,
    }) async {
      final tiles = TileManager(canvasWidth: _w, canvasHeight: _h);
      addTearDown(tiles.dispose);
      final fills = [null, 0x000000, 0x1B2A6B];
      for (final (index, rgb) in fills.indexed) {
        tiles.replaceLayerPixels(
          frameLayerKey(_sceneId, index, _layer.id),
          _filled(rgb),
        );
        if (watermark) {
          tiles.replaceLayerPixels(
            frameLayerKey(_sceneId, index, _mark.id),
            mark(),
          );
        }
      }
      final output = await ExportEngine().exportGif(
        scenes: [
          Scene(
            id: _sceneId,
            index: 0,
            frames: [
              for (var i = 0; i < fills.length; i++)
                Frame(index: i, layers: [if (watermark) _mark, _layer]),
            ],
          ),
        ],
        tileManager: tiles,
        fps: 2,
        drawingWidth: _w,
        drawingHeight: _h,
        width: _w,
        height: _h,
        backgroundColor: 0xFFFFFFFF,
        cornerLogo: cornerLogo,
      );
      final gif = img.decodeGif(File(output).readAsBytesSync())!;
      return [for (final frame in gif.frames) frame.convert(numChannels: 3)];
    }

    test('a free member\'s GIF has the logo in the bottom right corner of '
        'every frame, light or dark, and nothing else changes', () async {
      final plain = await export(cornerLogo: false);
      final logo = await export(cornerLogo: true);
      expect(logo, hasLength(3));
      final at = CornerLogoPlacement(_w, _h, LogoCorner.bottomRight);
      for (var i = 0; i < logo.length; i++) {
        expect(_showsBadge(logo[i], plain[i], at), isTrue, reason: 'frame $i');
        expect(_showsName(logo[i], plain[i], at), isTrue, reason: 'frame $i');
        expect(
          _differencesOutside(logo[i], plain[i], _logoRect(at)),
          0,
          reason: 'frame $i: only the logo changes',
        );
        // The translucent logo adds few colours to the 256-colour palette.
        expect(
          _colours(logo[i]) - _colours(plain[i]),
          lessThan(128),
          reason: 'frame $i',
        );
        // No logo anywhere else.
        for (final corner in LogoCorner.values.skip(1)) {
          expect(
            _showsBadge(logo[i], plain[i], CornerLogoPlacement(_w, _h, corner)),
            isFalse,
          );
        }
      }
    });

    for (final (name, mark) in const [
      ('in the corner', _bottomRightMark),
      ('only where the name would go', _underNameMark),
    ]) {
      test('the logo keeps out of the user\'s own watermark ($name)', () async {
        final right = CornerLogoPlacement(_w, _h, LogoCorner.bottomRight);
        expect(
          right.clearArea.left,
          lessThan(_w - 60),
          reason: 'the bottom right logo would cover the watermark',
        );
        final plain = await export(
          cornerLogo: false,
          watermark: true,
          mark: mark,
        );
        final logo = await export(
          cornerLogo: true,
          watermark: true,
          mark: mark,
        );
        final left = CornerLogoPlacement(_w, _h, LogoCorner.bottomLeft);
        for (var i = 0; i < logo.length; i++) {
          expect(_showsBadge(logo[i], plain[i], left), isTrue, reason: '$i');
          expect(_showsName(logo[i], plain[i], left), isTrue, reason: '$i');
          // The watermark (and everything but the logo) is as without the logo.
          expect(_differencesOutside(logo[i], plain[i], _logoRect(left)), 0);
        }
      });
    }

    test('Premium members and the end mark perk: no logo', () async {
      // The work export screen asks the same rule as the end mark.
      for (final premium in [_Premium(), _EndMarkPerk()]) {
        addTearDown(premium.dispose);
        expect(
          premium.shouldAppendOfficialEndCard(
            projectHidden: null,
            defaultHidden: true,
          ),
          isFalse,
        );
      }
      final free = PremiumService();
      addTearDown(free.dispose);
      expect(
        free.shouldAppendOfficialEndCard(
          projectHidden: true,
          defaultHidden: true,
        ),
        isTrue,
      );
      final a = await export(cornerLogo: false);
      final b = await export(cornerLogo: false);
      for (var i = 0; i < a.length; i++) {
        expect(
          _differencesOutside(a[i], b[i], const math.Rectangle(0, 0, 0, 0)),
          0,
        );
        expect(
          _showsBadge(
            a[i],
            b[i],
            CornerLogoPlacement(_w, _h, LogoCorner.bottomRight),
          ),
          isFalse,
        );
      }
    });
  });

  group('making video', () {
    late Directory root;
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    late List<String> snapshots;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('niarim-making-gif-logo-');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, (_) async => root.path);
      snapshots = [
        for (final (index, rgb) in const [
          (0, 0xFFFFFF),
          (1, 0x000000),
          (2, 0x1B2A6B),
        ])
          (File('${root.path}/making_$index.png')..writeAsBytesSync(
                img.encodePng(
                  img.Image(width: _w, height: _h)..clear(
                    img.ColorRgb8(
                      (rgb >> 16) & 0xFF,
                      (rgb >> 8) & 0xFF,
                      rgb & 0xFF,
                    ),
                  ),
                ),
              ))
              .path,
      ];
    });
    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null);
      if (await root.exists()) await root.delete(recursive: true);
    });

    Future<List<img.Image>> export({
      required bool officialMark,
      List<ui.Rect> watermarkAreas = const [],
    }) async {
      final output =
          '${root.path}/out_${DateTime.now().microsecondsSinceEpoch}.gif';
      await MakingExport.export(
        snapshotPaths: snapshots,
        format: MakingExportFormat.gif,
        outputPath: output,
        officialMark: officialMark,
        watermarkAreas: watermarkAreas,
      );
      final gif = img.decodeGif(File(output).readAsBytesSync())!;
      return [for (final frame in gif.frames) frame.convert(numChannels: 3)];
    }

    test('a free member\'s making GIF has the logo on every frame', () async {
      final plain = await export(officialMark: false);
      final logo = await export(officialMark: true);
      expect(logo, hasLength(snapshots.length));
      final at = CornerLogoPlacement(_w, _h, LogoCorner.bottomRight);
      for (var i = 0; i < logo.length; i++) {
        expect(_showsBadge(logo[i], plain[i], at), isTrue, reason: '$i');
        expect(_showsName(logo[i], plain[i], at), isTrue, reason: '$i');
        expect(_differencesOutside(logo[i], plain[i], _logoRect(at)), 0);
        expect(
          _showsBadge(plain[i], plain[i], at),
          isFalse,
          reason: 'without the mark',
        );
      }
    });

    test('the making GIF logo keeps out of the watermark too', () async {
      final plain = await export(officialMark: false);
      final logo = await export(
        officialMark: true,
        watermarkAreas: const [ui.Rect.fromLTRB(0.7, 0.75, 0.98, 0.97)],
      );
      final left = CornerLogoPlacement(_w, _h, LogoCorner.bottomLeft);
      for (var i = 0; i < logo.length; i++) {
        expect(_showsBadge(logo[i], plain[i], left), isTrue, reason: '$i');
        expect(_showsName(logo[i], plain[i], left), isTrue, reason: '$i');
        expect(_differencesOutside(logo[i], plain[i], _logoRect(left)), 0);
      }
    });
  });

  group('export screen', () {
    useTemporaryProjectStorage();
    var zero = '';

    Future<String> summary(WidgetTester tester, PremiumService? premium) async {
      SharedPreferences.setMockInitialValues({'language': 'ja'});
      final providers = (await tester.runAsync(buildAppProviders))!;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ...providers,
            if (premium != null)
              ChangeNotifierProvider<PremiumService>.value(value: premium),
          ],
          child: Builder(
            builder: (context) => MaterialApp(
              theme: context.watch<ThemeService>().themeData,
              locale: const Locale('ja'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const ExportScreen(projectId: 'missing'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = lookupAppLocalizations(const Locale('ja'));
      final gif = find.widgetWithText(
        RadioListTile<ExportFormat>,
        l10n.exportFormatGif,
      );
      await tester.ensureVisible(gif);
      await tester.pumpAndSettle();
      await tester.tap(gif);
      await tester.pumpAndSettle();
      final line = find.byKey(const ValueKey('exportOutputSummary'));
      zero = clockDurationLabel(
        MaterialLocalizations.of(tester.element(line)),
        0,
      );
      return tester.widget<Text>(line).data!;
    }

    testWidgets('a free member\'s GIF says the logo goes in a corner', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('ja'));
      expect(
        await summary(tester, null),
        l10n.exportOutputWithCornerLogo(zero),
      );
    });

    testWidgets('a Premium member\'s GIF has no logo', (tester) async {
      final premium = _Premium();
      addTearDown(premium.dispose);
      final l10n = lookupAppLocalizations(const Locale('ja'));
      expect(
        await summary(tester, premium),
        l10n.exportOutputWithoutEndCard(zero),
      );
    });
  });
}

/// Not a member, with the end mark editing perk exchanged with opals.
class _EndMarkPerk extends PremiumService {
  @override
  bool isServerCoinBenefitActive(String benefit) => benefit == 'endCardEdit';
}
