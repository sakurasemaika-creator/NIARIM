import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/autofill_engine.dart';
import 'package:niarim/models/autofill_preset.dart';

void main() {
  const width = 9;
  const height = 9;
  const part = AutofillPart(
    id: 'part',
    name: 'part',
    color: 0xFF00CC66,
  );

  Uint8List lineartRect(int left, int top, int right, int bottom) {
    final data = Uint8List(width * height * 4);
    void setLine(int x, int y) {
      data[(y * width + x) * 4 + 3] = 255;
    }

    for (var x = left; x <= right; x++) {
      setLine(x, top);
      setLine(x, bottom);
    }
    for (var y = top; y <= bottom; y++) {
      setLine(left, y);
      setLine(right, y);
    }
    return data;
  }

  void setRgba(Uint8List data, int x, int y, int r, int g, int b, int a) {
    final i = (y * width + x) * 4;
    data[i] = r;
    data[i + 1] = g;
    data[i + 2] = b;
    data[i + 3] = a;
  }

  List<int> rgba(Uint8List data, int x, int y) {
    final i = (y * width + x) * 4;
    return data.sublist(i, i + 4);
  }

  test('smart update preserves edited overlap and fills newly added area', () {
    final lineart = lineartRect(1, 1, 7, 7);
    final existing = Uint8List(width * height * 4);

    // Existing manually adjusted fill occupies only the old center region.
    for (var y = 3; y <= 5; y++) {
      for (var x = 3; x <= 5; x++) {
        setRgba(existing, x, y, 210, 40, 70, 255);
      }
    }

    final result = AutofillEngine().smartUpdate(
      lineartData: lineart,
      existingData: existing,
      width: width,
      height: height,
      part: part,
    );

    // Existing manual color survives where old and new shapes overlap.
    expect(rgba(result, 4, 4), [210, 40, 70, 255]);
    // Newly exposed area uses the current part color.
    expect(rgba(result, 2, 2), [0, 204, 102, 255]);
    // Outside the current lineart remains transparent.
    expect(rgba(result, 0, 0), [0, 0, 0, 0]);
  });

  test('smart update removes paint that is no longer inside current lineart', () {
    final lineart = lineartRect(2, 2, 6, 6);
    final existing = Uint8List(width * height * 4);
    setRgba(existing, 1, 1, 210, 40, 70, 255);
    setRgba(existing, 4, 4, 210, 40, 70, 255);

    final result = AutofillEngine().execute(
      mode: AutofillMode.smartUpdate,
      lineartData: lineart,
      existingData: existing,
      width: width,
      height: height,
      part: part,
    )!;

    expect(rgba(result, 1, 1), [0, 0, 0, 0]);
    expect(rgba(result, 4, 4), [210, 40, 70, 255]);
  });
}
