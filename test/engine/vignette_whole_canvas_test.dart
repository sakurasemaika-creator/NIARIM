import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _w = 160, _h = 120;

List<int> _px(Uint8List d, int x, int y) {
  final i = (y * _w + x) * 4;
  return d.sublist(i, i + 4);
}

Uint8List _vignette(
  Uint8List input, {
  double strength = 50,
  double range = 40,
}) => applyDrawFilterInIsolate((
  input,
  _w,
  _h,
  FilterDef(
    id: 'Filter0009',
    name: '周辺減光',
    kind: FilterKind.vignette,
    strength: strength,
    vignetteRange: range,
  ),
  null,
));

/// 周辺減光 darkens the four corners of the whole canvas, softly, like a
/// camera's vignette: transparent canvas gets the shadow too (it is not
/// limited to what is drawn), the middle is left alone, and the default
/// strength is 50.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the default strength is 50', () async {
    SharedPreferences.setMockInitialValues({});
    final service = FilterService();
    await service.init();
    final vignette = service.filters.firstWhere(
      (f) => f.kind == FilterKind.vignette,
    );
    expect(vignette.strength, 50);
  });

  test('on a transparent layer the corners get a soft shadow', () {
    final out = _vignette(Uint8List(_w * _h * 4));
    for (final (x, y) in const [(0, 0), (_w - 1, 0), (0, _h - 1)]) {
      final p = _px(out, x, y);
      expect(p[3], greaterThan(90), reason: 'corner ($x, $y) is shaded');
      expect(p.sublist(0, 3), [0, 0, 0], reason: 'in black');
    }
    // The four corners alike.
    expect(_px(out, 0, 0), _px(out, _w - 1, _h - 1));
    expect(_px(out, _w - 1, 0), _px(out, 0, _h - 1));
    // The middle and the area round it stay clear.
    expect(_px(out, _w ~/ 2, _h ~/ 2), [0, 0, 0, 0]);
    expect(_px(out, _w ~/ 2 + 30, _h ~/ 2 + 20), [0, 0, 0, 0]);
    // It deepens smoothly towards the corner, with no hard edge.
    var previous = 0;
    for (var k = 0; k <= 20; k++) {
      final x = (_w / 2 + (_w / 2 - 1) * k / 20).floor();
      final y = (_h / 2 + (_h / 2 - 1) * k / 20).floor();
      final a = _px(out, x, y)[3];
      expect(a, greaterThanOrEqualTo(previous));
      expect(a - previous, lessThan(40), reason: 'no step at $k');
      previous = a;
    }
  });

  test('on a painted picture it darkens the corners and keeps the middle', () {
    final input = Uint8List(_w * _h * 4)..fillRange(0, _w * _h * 4, 255);
    final out = _vignette(input);
    expect(_px(out, _w ~/ 2, _h ~/ 2), [255, 255, 255, 255]);
    final corner = _px(out, 0, 0);
    expect(corner[3], 255);
    expect(corner[0], lessThan(170));
    expect(corner[0], corner[1]);
    expect(corner[1], corner[2]);
    // The same shadow as on the transparent canvas, laid over white.
    final shadow = _px(_vignette(Uint8List(_w * _h * 4)), 0, 0)[3];
    expect(corner[0], closeTo(255 - shadow, 1));
  });

  test('a stronger vignette is darker, and 0 changes nothing', () {
    final transparent = Uint8List(_w * _h * 4);
    final weak = _px(_vignette(transparent, strength: 30), 2, 2)[3];
    final strong = _px(_vignette(transparent, strength: 90), 2, 2)[3];
    expect(strong, greaterThan(weak));
    expect(_vignette(transparent, strength: 0), transparent);
  });

  test('a coloured vignette stays valid premultiplied colour', () {
    final out = applyDrawFilterInIsolate((
      Uint8List(_w * _h * 4),
      _w,
      _h,
      const FilterDef(
        id: 'v',
        name: 'v',
        kind: FilterKind.vignette,
        strength: 80,
        vignetteColor: 0xFFFF8020,
      ),
      null,
    ));
    for (var i = 0; i < out.length; i += 4) {
      expect(out[i], lessThanOrEqualTo(out[i + 3]));
      expect(out[i + 1], lessThanOrEqualTo(out[i + 3]));
      expect(out[i + 2], lessThanOrEqualTo(out[i + 3]));
    }
    final corner = _px(out, 0, 0);
    expect(corner[0], greaterThan(corner[2]), reason: 'orange, not black');
  });

  test('the cathode-ray tube darkens only its own picture', () {
    final engine = FilterEngine();
    final out = engine.applyVignette(
      Uint8List(_w * _h * 4),
      _w,
      _h,
      50,
      onlyOnPaint: true,
    );
    expect(out.every((v) => v == 0), isTrue);
  });

  // 「範囲」 and 「濃さ」 work on their own: the range sets how far in from
  // the corners the shade reaches, the density how dark the corners are.
  test('the range sets how far in it reaches, the density how dark', () {
    final white = Uint8List(_w * _h * 4)..fillRange(0, _w * _h * 4, 255);
    int shade(Uint8List d, int x, int y) => 255 - _px(d, x, y)[0];
    // Halfway from the middle to a corner (along the diagonal).
    final hx = (_w * .75).round(), hy = (_h * .75).round();

    final narrow = _vignette(white, range: 20);
    final wide = _vignette(white, range: 80);
    expect(shade(narrow, hx, hy), 0, reason: 'a 20 % range stops short');
    expect(shade(wide, hx, hy), greaterThan(20), reason: '80 % reaches it');
    // The corners are as dark either way: that is the density's.
    expect(shade(narrow, 0, 0), closeTo(shade(wide, 0, 0), 3));
    expect(shade(_vignette(white), _w ~/ 2, _h ~/ 2), 0);

    final light = _vignette(white, strength: 20);
    final dark = _vignette(white, strength: 90);
    expect(shade(dark, 0, 0), greaterThan(shade(light, 0, 0) * 3));
    expect(_vignette(white, range: 0), white, reason: 'no range, no shade');
  });

  test('the range is saved and restored (40 for older settings)', () {
    const filter = FilterDef(
      id: 'v',
      name: 'v',
      kind: FilterKind.vignette,
      strength: 50,
    );
    expect(filter.vignetteRange, 40);
    final changed = filter.copyWith(vignetteRange: 75);
    expect(FilterDef.fromJson(changed.toJson()).vignetteRange, 75);
    final old = changed.toJson()..remove('vignetteRange');
    expect(FilterDef.fromJson(old).vignetteRange, 40);
  });
}
