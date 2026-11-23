import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/ruler.dart';
import 'package:niarim/screens/canvas/widgets/ruler_panel.dart';

/// 定規のパネルの「削除」は、押せる所が48×48ある。以前は字11px・余白0の
/// 約36×20pxで、押し損ねたり隣を押したつもりで定規が消えたりした。
void main() {
  for (final code in ['ja', 'fr']) {
    testWidgets('the ruler delete button is a 48x48 target ($code)', (
      tester,
    ) async {
      Ruler? changed = const Ruler(
        type: RulerType.line,
        position: Offset(100, 100),
        settings: RulerSettings(),
      );
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(code),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: RulerPanel(
                activeRuler: changed,
                onRulerChanged: (ruler) {
                  calls++;
                  changed = ruler;
                },
                onClose: () {},
                canvasWidth: 800,
                canvasHeight: 600,
              ),
            ),
          ),
        ),
      );
      final l10n = lookupAppLocalizations(Locale(code));
      final button = find.ancestor(
        of: find.text(l10n.commonDelete),
        matching: find.byType(TextButton),
      );
      expect(button, findsOneWidget);
      final size = tester.getSize(button);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      // A tap near the edge of the 48dp target still deletes.
      final rect = tester.getRect(button);
      await tester.tapAt(Offset(rect.center.dx, rect.top + 3));
      await tester.pump();
      expect(calls, 1);
      expect(changed, isNull);
    });
  }
}
