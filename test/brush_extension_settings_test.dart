import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/screens/canvas/widgets/brush_extension_settings.dart';

void main() {
  const base = Brush(
    id: 'test',
    name: 'Test',
    size: 20,
    opacity: 100,
    spacing: 10,
    stabilization: false,
    stabilizationStrength: 0,
    pixelMode: false,
    fadeMode: FadeMode.off,
    strokeDecay: false,
  );

  Widget host(Brush brush, ValueChanged<Brush> onChanged) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BrushExtensionSettings(
              brush: brush,
              onChanged: onChanged,
              labels: const BrushExtensionLabels.japanese(),
              onPickOutlineColor: null,
              onEyedropOutlineColor: null,
            ),
          ),
        ),
      );

  testWidgets('lateral repeat dependants are hidden while disabled', (tester) async {
    await tester.pumpWidget(host(base, (_) {}));
    expect(find.text('横方向反復個数'), findsNothing);
    expect(find.text('横方向間隔'), findsNothing);

    await tester.tap(find.text('横方向反復'));
    await tester.pump();
    expect(find.text('横方向反復個数'), findsOneWidget);
    expect(find.text('横方向間隔'), findsOneWidget);
  });

  testWidgets('fold controls require outline and fold enabled', (tester) async {
    await tester.pumpWidget(host(base, (_) {}));
    expect(find.text('折り返し'), findsNothing);

    await tester.tap(find.text('縁取り'));
    await tester.pump();
    expect(find.text('折り返し'), findsOneWidget);
    expect(find.text('Y字長さ'), findsNothing);

    await tester.tap(find.text('折り返し'));
    await tester.pump();
    expect(find.text('発生角度'), findsOneWidget);
    expect(find.text('Y字枝分かれ角度'), findsOneWidget);
    expect(find.text('Y字長さ'), findsOneWidget);
    expect(find.text('Y字太さ'), findsOneWidget);
    expect(find.text('Y字終点入り抜き'), findsOneWidget);
  });

  testWidgets('outline exposes picker and eyedropper actions', (tester) async {
    var picked = 0;
    var eyedropped = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BrushExtensionSettings(
          brush: base.copyWith(outlineEnabled: true),
          onChanged: (_) {},
          labels: const BrushExtensionLabels.japanese(),
          onPickOutlineColor: () => picked++,
          onEyedropOutlineColor: () => eyedropped++,
        ),
      ),
    ));

    await tester.tap(find.byKey(const Key('brush-outline-color-picker')));
    await tester.tap(find.byKey(const Key('brush-outline-eyedropper')));
    expect(picked, 1);
    expect(eyedropped, 1);
  });
}
