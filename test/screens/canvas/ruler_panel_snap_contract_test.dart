import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/ruler.dart';
import 'package:niarim/screens/canvas/widgets/ruler_panel.dart';

void main() {
  testWidgets('snap switch keeps ruler visible and toggles constraint state', (tester) async {
    Ruler? ruler = const Ruler(
      type: RulerType.line,
      position: Offset(500, 500),
      snapEnabled: true,
      settings: RulerSettings(),
    );

    Future<void> pump() => tester.pumpWidget(MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: StatefulBuilder(builder: (context, setState) {
            return RulerPanel(
              activeRuler: ruler,
              onRulerChanged: (value) => setState(() => ruler = value),
              onClose: () {},
              canvasWidth: 1000,
              canvasHeight: 1000,
            );
          }),
        ));

    await pump();
    expect(find.byKey(const ValueKey('ruler-snap-switch')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ruler-snap-switch')));
    await tester.pump();

    expect(ruler, isNotNull);
    expect(ruler!.isVisible, isTrue);
    expect(ruler!.snapEnabled, isFalse);
  });

  testWidgets('changing ruler type preserves snap off', (tester) async {
    Ruler? ruler = const Ruler(
      type: RulerType.line,
      position: Offset(500, 500),
      snapEnabled: false,
      settings: RulerSettings(),
    );

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: StatefulBuilder(builder: (context, setState) {
        return RulerPanel(
          activeRuler: ruler,
          onRulerChanged: (value) => setState(() => ruler = value),
          onClose: () {},
          canvasWidth: 1000,
          canvasHeight: 1000,
        );
      }),
    ));

    await tester.tap(find.text('Ellipse Ruler'));
    await tester.pump();
    expect(ruler!.type, RulerType.ellipse);
    expect(ruler!.snapEnabled, isFalse);
    expect(ruler!.isVisible, isTrue);
  });
}
