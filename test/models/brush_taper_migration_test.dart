// 以前の版で保存したブラシのフェードを、入り抜きの意味へ1度だけ移す
// （所有者の方針「今できる機能を削る行為でなければ…」：以前のカスタムの
// フェードは端を細くしていた。今のフェードは透け方だけなので、そのままでは
// 細い入り抜きの線が描けなくなる）。
//
// - `taperMode`の無い保存（入り抜きができる前の版）だけを移す。縁取りの無い
//   ブラシのカスタムのフェードは、同じ値の入り抜きに（フェードは切る）。
//   縁取りペンのフェード（形を細くしていた）は、どの設定も入り抜きに。
//   縁取りの無いブラシの弱・中・強はフェード（透け方）のまま。
// - 今の版の保存は書いてあるとおりに読む。読み直しても同じで、保存し直す
//   までは古い形のまま残る（読むたびに同じに移す）。
// - 入り抜きの値の型が違っても、ブラシは読める（入り抜きは切り）。
// - 入り抜きができる前に作ったブラシのQRコードも読める。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Brush _base({bool outline = false}) => Brush(
  id: 'Mine',
  name: 'Mine',
  size: 12,
  opacity: 100,
  spacing: 1,
  stabilization: false,
  stabilizationStrength: 0,
  pixelMode: false,
  fadeMode: FadeMode.off,
  strokeDecay: false,
  outlineEnabled: outline,
);

/// [brush] as an older version saved it: no 入り抜き, and its ends in the
/// fade fields.
Map<String, dynamic> _savedBefore(
  Brush brush, {
  required FadeMode fade,
  FadeEndpointSettings fadeIn = FadeEndpointSettings.full,
  FadeEndpointSettings fadeOut = FadeEndpointSettings.full,
}) {
  final json = brush.toJson()
    ..['fadeMode'] = fade.name
    ..['fadeIn'] = fadeIn.toJson()
    ..['fadeOut'] = fadeOut.toJson();
  json
    ..remove('taperMode')
    ..remove('taperIn')
    ..remove('taperOut');
  return json;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const start = FadeEndpointSettings(value: 20, rangePx: 30);
  const end = FadeEndpointSettings(value: 5, rangePx: 70);

  test('a custom fade saved before 入り抜き becomes 入り抜き, with the fade '
      'off', () {
    final read = Brush.fromJson(
      _savedBefore(_base(), fade: FadeMode.custom, fadeIn: start, fadeOut: end),
    );
    expect(read.fadeMode, FadeMode.off);
    expect(read.taperMode, FadeMode.custom);
    expect(read.taperIn.toJson(), start.toJson());
    expect(read.taperOut.toJson(), end.toJson());
    // Saved again, it is read as it is now.
    final again = Brush.fromJson(read.toJson());
    expect(again.toJson(), read.toJson());
  });

  test('the weak, medium and strong fades of other brushes stay fades', () {
    for (final mode in [FadeMode.weak, FadeMode.medium, FadeMode.strong]) {
      final read = Brush.fromJson(_savedBefore(_base(), fade: mode));
      expect(read.fadeMode, mode);
      expect(read.taperMode, FadeMode.off);
    }
    final none = Brush.fromJson(_savedBefore(_base(), fade: FadeMode.off));
    expect(none.fadeMode, FadeMode.off);
    expect(none.taperMode, FadeMode.off);
  });

  test('an outline pen saved before 入り抜き keeps its shape as 入り抜き', () {
    for (final mode in [FadeMode.weak, FadeMode.strong, FadeMode.custom]) {
      final read = Brush.fromJson(
        _savedBefore(
          _base(outline: true),
          fade: mode,
          fadeIn: start,
          fadeOut: end,
        ),
      );
      expect(read.fadeMode, FadeMode.off, reason: mode.name);
      expect(read.taperMode, mode, reason: mode.name);
      expect(read.taperOut.toJson(), end.toJson(), reason: mode.name);
      expect(read.shapeTaperMode, mode, reason: mode.name);
    }
  });

  test('a brush saved with 入り抜き is read as it is: its fade stays a '
      'fade', () {
    final brush = _base().copyWith(
      fadeMode: FadeMode.custom,
      fadeIn: start,
      taperMode: FadeMode.medium,
    );
    final read = Brush.fromJson(brush.toJson());
    expect(read.fadeMode, FadeMode.custom);
    expect(read.fadeIn.toJson(), start.toJson());
    expect(read.taperMode, FadeMode.medium);
  });

  test('入り抜き of another type does not stop the brush loading', () {
    final json = _base().toJson()
      ..['taperMode'] = 42
      ..['taperIn'] = 'thin'
      ..['taperOut'] = {'value': 'x', 'rangePx': 10};
    final read = Brush.fromJson(json);
    expect(read.taperMode, FadeMode.off);
    expect(read.taperIn.toJson(), FadeEndpointSettings.full.toJson());
    expect(read.taperOut.toJson(), FadeEndpointSettings.full.toJson());
  });

  test('a saved list is moved each time it is read', () async {
    final old = jsonEncode(
      _savedBefore(_base(), fade: FadeMode.custom, fadeIn: start, fadeOut: end),
    );
    SharedPreferences.setMockInitialValues({
      'brushes': [old],
    });
    for (var i = 0; i < 2; i++) {
      final service = BrushService();
      await service.init();
      final mine = service.brushes.singleWhere((b) => b.id == 'Mine');
      expect(mine.fadeMode, FadeMode.off);
      expect(mine.taperMode, FadeMode.custom);
      expect(mine.taperIn.toJson(), start.toJson());
      service.dispose();
    }
  });

  test('a brush QR code made before 入り抜き still reads, its fade moved', () {
    final service = BrushService();
    final brush = _base().copyWith(id: '', name: 'Q', size: 9);
    final json = _savedBefore(
      brush,
      fade: FadeMode.custom,
      fadeIn: start,
      fadeOut: end,
    );
    json['folderId'] = null;
    json['customImagePath'] = null;
    json['customImagePaths'] = <String>[];
    Object? pack(Object? value, Object? schema) => schema is Map && value is Map
        ? [for (final key in schema.keys) pack(value[key], schema[key])]
        : value;
    // Settings added after 入り抜き (bristle marks) were not in the code
    // either.
    final schema = BrushService.builtInBrushes.first.toJson()
      ..remove('taperMode')
      ..remove('taperIn')
      ..remove('taperOut')
      ..remove('bristleStreaks')
      ..remove('dryBrush');
    final payload =
        '${BrushService.brushQrPrefix}${base64UrlEncode(gzip.encode(utf8.encode(jsonEncode(pack(json, schema)))))}';
    final imported = service.importBrushQrPayload(payload);
    expect(imported.name, 'Q');
    expect(imported.fadeMode, FadeMode.off);
    expect(imported.taperMode, FadeMode.custom);
    expect(imported.taperOut.toJson(), end.toJson());
    service.dispose();
  });
}
