import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/widgets/qr_share_dialog.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  for (final width in [320.0, 1280.0]) {
    testWidgets('QR sharing opens and fits at ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 540);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const QrShareDialog(
                      title: 'Share palette',
                      payload: '{"colors":[4278190080]}',
                    ),
                  ),
                  child: const Text('Show QR'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show QR'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final qr = find.byType(QrImageView);
      expect(qr, findsOneWidget);
      final bounds = tester.getRect(qr);
      expect(bounds.width, greaterThan(0));
      expect(bounds.width, bounds.height);
      expect(bounds.left, greaterThanOrEqualTo(0));
      expect(bounds.right, lessThanOrEqualTo(width));
      expect(tester.widget<QrImageView>(qr).backgroundColor, Colors.white);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(qr, findsNothing);
    });
  }
}
