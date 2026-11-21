import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/widgets/docked_panel_close_scope.dart';
import 'package:niarim/screens/canvas/widgets/panel_close_bar.dart';

void main() {
  testWidgets('floating panel keeps its close button', (tester) async {
    var called = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: PanelCenterCloseBar(onClose: () => called++)),
      ),
    );
    expect(find.byIcon(Icons.close), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    expect(called, 1);
  });

  testWidgets('docked panel hides duplicate embedded close control', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DockedPanelCloseScope(
            child: PanelCenterCloseBar(onClose: () {}),
          ),
        ),
      ),
    );
    expect(find.byType(PanelCenterCloseBar), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
  });
}
