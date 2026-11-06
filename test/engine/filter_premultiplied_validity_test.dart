import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/autofill_engine.dart';
import 'package:niarim/engine/color_trace_adjust_engine.dart';
import 'package:niarim/engine/filter_preview.dart';
import 'package:niarim/models/autofill_preset.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every drawing filter returns valid premultiplied pixels (no colour
/// channel above the pixel's alpha): a layer is premultiplied RGBA, and a
/// channel above alpha draws as a glowing fringe around half-transparent
/// edges or as colour inside transparent areas.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// A 48×48 layer: transparent around a disc of colour whose edge fades
  /// out (premultiplied), with a few saturated and dark patches inside.
  Uint8List layer() {
    const size = 48;
    final out = Uint8List(size * size * 4);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final dx = x - 24, dy = y - 24;
        final d = (dx * dx + dy * dy).toDouble();
        final a = d < 196
            ? 255
            : (d < 400 ? (255 * (400 - d) / 204).round() : 0);
        final (r, g, b) = x < 20
            ? (230, 40, 30)
            : y < 20
            ? (20, 20, 20)
            : (90, 180, 240);
        final i = (y * size + x) * 4;
        out[i] = (r * a / 255).round();
        out[i + 1] = (g * a / 255).round();
        out[i + 2] = (b * a / 255).round();
        out[i + 3] = a;
      }
    }
    return out;
  }

  test('no filter writes a colour channel above alpha', () async {
    SharedPreferences.setMockInitialValues({});
    final service = FilterService();
    await service.init();
    final data = layer();
    final failures = <String>[];
    for (final filter in service.filters) {
      // Layer-generating filters (outline, ink pool, auto line art) and
      // background blend need other inputs; they are covered elsewhere.
      if (filter.kind == FilterKind.backgroundBlend) continue;
      final out = runFilterPreview((
        filter: filter,
        data: Uint8List.fromList(data),
        width: 48,
        height: 48,
        scale: 1,
        canvasWidth: 48,
        canvasHeight: 48,
        mask: null,
        background: null,
        frameIndex: 0,
      ));
      var bad = 0;
      for (var i = 0; i < out.length; i += 4) {
        if (out[i] > out[i + 3] ||
            out[i + 1] > out[i + 3] ||
            out[i + 2] > out[i + 3]) {
          bad++;
        }
      }
      if (bad > 0) failures.add('${filter.id} ${filter.kind.name}: $bad px');
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  int invalid(Uint8List out) {
    var bad = 0;
    for (var i = 0; i < out.length; i += 4) {
      if (out[i] > out[i + 3] ||
          out[i + 1] > out[i + 3] ||
          out[i + 2] > out[i + 3]) {
        bad++;
      }
    }
    return bad;
  }

  test('the colour trace adjustment keeps edges valid and true', () {
    // The same orange, solid and at 25 %.
    final data = Uint8List.fromList([240, 160, 80, 255, 60, 40, 20, 64]);
    final out = applyColorTraceAdjust(data, lightnessShift: 20);
    expect(invalid(out), 0);
    for (var c = 0; c < 3; c++) {
      expect(out[4 + c] * 255 / 64, closeTo(out[c].toDouble(), 6));
    }
  });

  test('autofill line colours keep anti-aliased edges premultiplied', () {
    final lines = Uint8List.fromList([0, 0, 0, 255, 0, 0, 0, 96]);
    final out = AutofillEngine().recolorLineart(
      lineartData: lines,
      width: 2,
      height: 1,
      part: const AutofillPart(
        id: 'p',
        name: 'p',
        color: 0xFF000000,
        lineColor: 0xFFE04020,
      ),
    );
    expect(invalid(out), 0);
    expect(out.sublist(0, 4), [0xE0, 0x40, 0x20, 255]);
    expect(out[4], closeTo(0xE0 * 96 / 255, 1));
    expect(out[7], 96);
  });
}
