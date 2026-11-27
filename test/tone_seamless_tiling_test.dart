import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/procedural_texture.dart';
import 'package:niarim/models/tone.dart';
import 'package:niarim/services/tone_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 組み込みのトーンは、タイルを並べた継ぎ目で模様が途切れない。
///
/// トーンは1枚のタイルを縦横に繰り返して貼る。以前はどのトーンも64pxの
/// タイルで、模様の間隔（ライン6px・クロスハッチ7px・ストッキングの網目
/// 3〜10px）が64で割り切れず、継ぎ目だけ線の間隔が狭くなって64pxごとに
/// 筋が出ていた。タイツ（40・60・80デニール）は網目の片方の斜線を対角線で
/// 折り返していて、タイルの中にも斜めの継ぎ目があった。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 縦横それぞれ、タイルの中で模様が繰り返す最小の間隔（繰り返さなければnull）。
  ({int? x, int? y}) periods(Uint8List rgba, int size) {
    int alpha(int x, int y) => rgba[(y * size + x) * 4 + 3];
    int? along(bool horizontal) {
      for (var p = 1; p < size; p++) {
        var same = true;
        for (var y = 0; y < size && same; y++) {
          for (var x = 0; x < size && same; x++) {
            final nx = horizontal ? x + p : x;
            final ny = horizontal ? y : y + p;
            if (nx >= size || ny >= size) continue;
            same = alpha(x, y) == alpha(nx, ny);
          }
        }
        if (same) return p;
      }
      return null;
    }

    return (x: along(true), y: along(false));
  }

  /// 粒の大きさ[cell]のノイズは、粒がタイルの縁で欠けない。
  bool wholeCells(Uint8List rgba, int size, int cell) {
    if (size % cell != 0) return false;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final first = rgba[((y - y % cell) * size + (x - x % cell)) * 4 + 3];
        if (rgba[(y * size + x) * 4 + 3] != first) return false;
      }
    }
    return true;
  }

  /// 紙・布の質感（タイルの中では繰り返さない模様）の継ぎ目：タイルの右端の
  /// 列と左端の列（下端の行と上端の行）の濃さの相関が、タイルの中の隣り合う
  /// 列・行の相関の平均の半分以上ある（継ぎ目で模様が途切れていれば、端どうし
  /// はほとんど相関しない。凹凸の細かい紙では差の大きさでは見分けられない）。
  ({double seam, double inside}) seamAndInside(Uint8List rgba, int size) {
    double alpha(int x, int y) => rgba[(y * size + x) * 4 + 3].toDouble();
    double correlation(double Function(int k) a, double Function(int k) b) {
      var ma = 0.0, mb = 0.0;
      for (var k = 0; k < size; k++) {
        ma += a(k);
        mb += b(k);
      }
      ma /= size;
      mb /= size;
      var ab = 0.0, aa = 0.0, bb = 0.0;
      for (var k = 0; k < size; k++) {
        final da = a(k) - ma, db = b(k) - mb;
        ab += da * db;
        aa += da * da;
        bb += db * db;
      }
      return aa == 0 || bb == 0 ? 1 : ab / math.sqrt(aa * bb);
    }

    double columns(int i, int j) =>
        correlation((k) => alpha(i, k), (k) => alpha(j, k));
    double rows(int i, int j) =>
        correlation((k) => alpha(k, i), (k) => alpha(k, j));
    var inside = 0.0;
    for (var j = 0; j < size - 1; j++) {
      inside += columns(j, j + 1) + rows(j, j + 1);
    }
    inside /= 2 * (size - 1);
    final seam = math.min(columns(size - 1, 0), rows(size - 1, 0));
    return (seam: seam, inside: inside);
  }

  late List<Tone> builtIns;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final service = ToneService();
    await service.init();
    builtIns = [
      for (final tone in service.tones)
        if (tone.texturePath?.startsWith('assets/tones/') ?? false) tone,
    ];
    service.dispose();
  });

  test('どの組み込みのトーンの画像も、継ぎ目で模様がつながる大きさで作ってある', () async {
    expect(builtIns.length, greaterThanOrEqualTo(60));
    // The images are really read (the 20 denier image is antialiased; the
    // pattern made from the name is not).
    final twenty = builtIns.firstWhere((t) => t.id == 'Tone0011');
    await ensureToneTextureLoaded(twenty);
    final twentyAlpha = generateBuiltInToneTexture(twenty);
    expect(
      [
        for (var i = 3; i < twentyAlpha.length; i += 4) twentyAlpha[i],
      ].any((a) => a > 0 && a < 255),
      isTrue,
    );
    for (final tone in builtIns) {
      final size = toneTileSize(tone);
      await ensureToneTextureLoaded(tone);
      final rgba = generateBuiltInToneTexture(tone);
      expect(rgba.length, size * size * 4, reason: tone.name);
      final name = tone.name;
      if (name.contains('砂目')) {
        final cell = name.contains('粗')
            ? 3
            : name.contains('中')
            ? 2
            : 1;
        expect(wholeCells(rgba, size, cell), isTrue, reason: name);
        continue;
      }
      if (name.contains('同心円')) {
        // 中心から同じ距離の縁の画素どうしで隣のタイルと出会う（鏡映し）。
        for (var y = 0; y < size; y++) {
          for (var x = 0; x < size; x++) {
            final a = rgba[(y * size + x) * 4 + 3];
            final b = rgba[(y * size + (size - 1 - x)) * 4 + 3];
            final c = rgba[((size - 1 - y) * size + x) * 4 + 3];
            expect(a, b, reason: '$name at ($x, $y)');
            expect(a, c, reason: '$name at ($x, $y)');
          }
        }
        continue;
      }
      final p = periods(rgba, size);
      if (p.x == null && p.y == null) {
        // A paper or canvas texture: one tile is one period of its relief.
        expect(size, greaterThanOrEqualTo(96), reason: name);
        final edges = seamAndInside(rgba, size);
        expect(edges.inside, greaterThan(0.2), reason: name);
        expect(
          edges.seam,
          greaterThanOrEqualTo(edges.inside / 2),
          reason: '$name: seam ${edges.seam} vs inside ${edges.inside}',
        );
        continue;
      }
      expect(p.x, isNotNull, reason: '$name repeats across');
      expect(p.y, isNotNull, reason: '$name repeats down');
      expect(size % p.x!, 0, reason: '$name: period ${p.x} in a $size tile');
      expect(size % p.y!, 0, reason: '$name: period ${p.y} in a $size tile');
    }
  });

  test('組み込みの画像は、名前から作る模様と同じ大きさ・同じ模様', () async {
    for (final tone in builtIns) {
      final size = toneTileSize(tone);
      expect(size, toneTileSizeForPattern(tone.name), reason: tone.name);
      // The 20 denier stocking image is antialiased on purpose.
      if (tone.id == 'Tone0011') continue;
      await ensureToneTextureLoaded(tone);
      final fromImage = generateBuiltInToneTexture(tone);
      final fromName = generateBuiltInToneTexture(
        Tone(id: tone.id, name: tone.name),
      );
      expect(fromImage, fromName, reason: tone.name);
    }
  });

  test('ストッキング・タイツの網目は、対角線の両側で同じ位置に線がある', () {
    for (final denier in [10, 20, 30, 40, 60, 80]) {
      final tone = Tone(id: 'd$denier', name: 'タイツ $denierデニール');
      final size = toneTileSize(tone);
      final rgba = generateBuiltInToneTexture(tone);
      // The mesh is the same after moving one diagonal step in any direction
      // by the spacing, so it has no mirrored half.
      final p = periods(rgba, size);
      expect(p.x, p.y, reason: '$denier');
      expect(size % p.x!, 0, reason: '$denier');
    }
  });

  test('利用者の画像のトーンは、今までどおり64pxのタイル', () {
    const custom = Tone(
      id: 'mine',
      name: 'ストッキング 30デニール',
      texturePath: '/data/user/0/tones/mine.png',
    );
    expect(toneTileSize(custom), defaultToneTileSize);
  });
}
