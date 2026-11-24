import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// 同梱のTrueType（glyf）フォントの、どの字にも「字の枠から大きく離れた
/// 輪郭」が無いことを見張る。
///
/// 白光明朝の元のフォントは「之」「林」「活」の3字に、字の枠から約4em右へ
/// 離れた小さな星の輪郭を持っていて、文の中で後ろの字の上に小さな「×」の
/// ような印が描かれていた。字の枠（送り幅）から0.5em以上外にある輪郭は、
/// その字の一部ではない。幅0の字（結合記号）は対象外。
void main() {
  final fonts = Directory(
    'assets/fonts',
  ).listSync().whereType<File>().where((f) => f.path.endsWith('.ttf')).toList();

  test('同梱のフォントが見つかる', () {
    expect(
      fonts.map((f) => f.uri.pathSegments.last),
      contains('HakkouMincho.ttf'),
    );
  });

  for (final file in fonts) {
    final name = file.uri.pathSegments.last;
    test('$name の字に、字の枠から離れた輪郭が無い', () {
      final strays = _strayGlyphs(file.readAsBytesSync());
      expect(strays, isEmpty, reason: '$name: 離れた輪郭を持つ字の番号 $strays');
    });
  }
}

List<int> _strayGlyphs(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final tables = <String, (int, int)>{};
  final numTables = data.getUint16(4);
  for (var i = 0; i < numTables; i++) {
    final record = 12 + i * 16;
    final tag = String.fromCharCodes(bytes.sublist(record, record + 4));
    tables[tag] = (data.getUint32(record + 8), data.getUint32(record + 12));
  }
  if (!tables.containsKey('glyf')) return const [];

  final head = tables['head']!.$1;
  final unitsPerEm = data.getUint16(head + 18);
  final longLoca = data.getInt16(head + 50) == 1;
  final numGlyphs = data.getUint16(tables['maxp']!.$1 + 4);
  final numberOfHMetrics = data.getUint16(tables['hhea']!.$1 + 34);
  final hmtx = tables['hmtx']!.$1;
  final loca = tables['loca']!.$1;
  final glyf = tables['glyf']!.$1;
  final margin = unitsPerEm * 0.5;

  int advanceOf(int glyph) => data.getUint16(
    hmtx + 4 * (glyph < numberOfHMetrics ? glyph : numberOfHMetrics - 1),
  );
  int offsetOf(int glyph) => longLoca
      ? data.getUint32(loca + glyph * 4)
      : data.getUint16(loca + glyph * 2) * 2;

  final strays = <int>[];
  for (var glyph = 0; glyph < numGlyphs; glyph++) {
    final start = offsetOf(glyph);
    if (offsetOf(glyph + 1) == start) continue;
    final at = glyf + start;
    final contours = data.getInt16(at);
    if (contours <= 0) continue; // 空の字・複合の字
    final advance = advanceOf(glyph);
    if (advance <= 0) continue;

    final endPoints = [
      for (var c = 0; c < contours; c++) data.getUint16(at + 10 + c * 2),
    ];
    final points = endPoints.last + 1;
    var p = at + 10 + contours * 2;
    final instructions = data.getUint16(p);
    p += 2 + instructions;

    final flags = Uint8List(points);
    for (var i = 0; i < points;) {
      final flag = data.getUint8(p++);
      flags[i++] = flag;
      if (flag & 0x08 != 0) {
        var repeat = data.getUint8(p++);
        while (repeat-- > 0) {
          flags[i++] = flag;
        }
      }
    }
    final xs = Int32List(points);
    var x = 0;
    for (var i = 0; i < points; i++) {
      final flag = flags[i];
      if (flag & 0x02 != 0) {
        final dx = data.getUint8(p++);
        x += flag & 0x10 != 0 ? dx : -dx;
      } else if (flag & 0x10 == 0) {
        x += data.getInt16(p);
        p += 2;
      }
      xs[i] = x;
    }

    var first = 0;
    for (final last in endPoints) {
      var minX = xs[first], maxX = xs[first];
      for (var i = first; i <= last; i++) {
        if (xs[i] < minX) minX = xs[i];
        if (xs[i] > maxX) maxX = xs[i];
      }
      if (minX > advance + margin || maxX < -margin) {
        strays.add(glyph);
        break;
      }
      first = last + 1;
    }
  }
  return strays;
}
