import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/brush_presets_extension.dart';

import 'hair_fold_bangs_render_capture_test.dart' as base;

/// The user's reference: a zigzag strand whose segments shorten toward the
/// tip, alternating down-right and down-left (like the ribbon diagrams).
List<ui.Offset> zigzagStrand() {
  const corners = [
    ui.Offset(150, 110),
    ui.Offset(420, 360),
    ui.Offset(150, 520),
    ui.Offset(380, 700),
    ui.Offset(200, 810),
    ui.Offset(340, 900),
    ui.Offset(230, 975),
  ];
  final points = <ui.Offset>[corners.first];
  for (var i = 1; i < corners.length; i++) {
    final a = corners[i - 1], b = corners[i];
    final count = ((b - a).distance / 3).ceil();
    for (var j = 1; j <= count; j++) {
      points.add(ui.Offset.lerp(a, b, j / count)!);
    }
  }
  return points;
}

/// A freehand-like wave whose amplitude and wavelength shrink toward the tip.
List<ui.Offset> taperedWave() => [
  for (var i = 0; i <= 300; i++)
    () {
      final t = i / 300;
      final amplitude = 150 * (1 - t * .55);
      final phase = math.pi * (t * 4.2 + t * t * 1.8);
      return ui.Offset(330 + amplitude * math.sin(phase), 100 + 860 * t);
    }(),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('NotoSerifJP')
      ..addFont(rootBundle.load('assets/fonts/NotoSerifJP.ttf'));
    await loader.load();
  });
  test('five fold modes on the reference zigzag and tapered wave', () async {
    final hair = brushExtensionPresets().singleWhere(
      (b) => b.id == 'Brush0023',
    );
    for (final entry in base.modeNames.entries) {
      final ribbon = hair.copyWith(
        size: 64,
        outlineWidth: 2.5,
        stabilization: false,
        fadeMode: FadeMode.off,
        foldMode: entry.key,
      );
      await base.capture(
        ribbon,
        'reference_zigzag_${entry.value}',
        input: zigzagStrand(),
      );
      // Image 1 of the reference uses pressure and the ordinary taper.
      await base.capture(
        hair.copyWith(size: 64, outlineWidth: 2.5, foldMode: entry.key),
        'reference_wave_${entry.value}',
        input: taperedWave(),
      );
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
  test('the three fold sliders change the fold line independently', () async {
    final hair = brushExtensionPresets().singleWhere(
      (b) => b.id == 'Brush0023',
    );
    final ribbon = hair.copyWith(
      size: 64,
      outlineWidth: 2.5,
      stabilization: false,
      fadeMode: FadeMode.off,
      foldMode: HairFoldMode.waveTopView,
    );
    final corner = [
      for (var i = 0; i <= 90; i++) ui.Offset(160 + i * 3.0, 160 + i * 2.2),
      for (var i = 1; i <= 90; i++) ui.Offset(430 - i * 3.0, 358 + i * 2.2),
    ];
    final variants = <String, Brush>{
      'length_25': ribbon.copyWith(foldLengthRatio: .25),
      'length_50': ribbon,
      'length_100': ribbon.copyWith(foldLengthRatio: 1),
      'angle_0': ribbon.copyWith(foldAngleRatio: 0),
      'angle_50': ribbon,
      'angle_100': ribbon.copyWith(foldAngleRatio: 1),
      'curve_start_0': ribbon,
      'curve_start_60': ribbon.copyWith(foldCurveStartRatio: .6),
    };
    for (final entry in variants.entries) {
      await base.capture(
        entry.value,
        'reference_slider_${entry.key}',
        input: corner,
      );
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
