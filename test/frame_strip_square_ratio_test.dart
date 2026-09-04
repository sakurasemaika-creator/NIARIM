import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/screens/canvas/widgets/frame_strip_widget.dart',
  ).readAsStringSync();

  test('フレーム一覧の通常セル・追加セル・現在枠は50x50の1:1', () {
    final squareCellPattern = RegExp(
      r'width:\s*50,\s*\n\s*height:\s*50,',
      multiLine: true,
    );

    // 通常フレームセル、末尾の追加セル、中央の現在フレーム枠の3系統が
    // すべて50x50で固定されていることを守る。
    expect(squareCellPattern.allMatches(source).length, greaterThanOrEqualTo(3));
    expect(source, contains('static const double _itemExtent = 50;'));
  });

  test('フレームセル内部のプレビュー領域もセル全体へ1:1で展開される', () {
    expect(source, contains('fit: StackFit.expand'));
    expect(source, contains('_FrameThumbnail('));
  });

  test('元キャンバス比率はBoxFit.containで保持し、正方形セルへ引き伸ばさない', () {
    expect(
      source,
      contains('return RawImage(image: image, fit: BoxFit.contain);'),
    );

    // サムネイル生成時は元のexport比率を保持する。表示先の50x50セル側で
    // containすることで、縦長/横長キャンバスも歪ませず正方形一覧へ収める。
    expect(
      source,
      contains(
        'final thumbH = (thumbW * exportH / exportW).round().clamp(1, 300).toInt();',
      ),
    );
  });
}
