import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/screens/canvas/widgets/brush_extension_settings.dart';

void main() {
  const brush = Brush(
    id: 'integration-test',
    name: 'Integration Test',
    size: 20,
    opacity: 100,
    spacing: 10,
    stabilization: false,
    stabilizationStrength: 0,
    pixelMode: false,
    fadeMode: FadeMode.off,
    strokeDecay: false,
  );

  testWidgets('localized extension settings expose independent outline actions',
      (tester) async {
    var picked = 0;
    var eyedropped = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: BrushExtensionSettings(
              brush: brush.copyWith(outlineEnabled: true),
              onChanged: (_) {},
              labels: BrushExtensionLabels.fromLocalizations(
                AppLocalizations.of(context)!,
              ),
              onPickOutlineColor: () => picked++,
              onEyedropOutlineColor: () => eyedropped++,
            ),
          ),
        ),
      ),
    );

    expect(find.text('縁取り'), findsOneWidget);
    await tester.tap(find.byKey(const Key('brush-outline-color-picker')));
    await tester.tap(find.byKey(const Key('brush-outline-eyedropper')));
    expect(picked, 1);
    expect(eyedropped, 1);
  });
}
