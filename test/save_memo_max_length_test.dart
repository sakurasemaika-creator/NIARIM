import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/save_tree/widgets/save_rename_button.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('Memo dialog uses only one heading and handles 100 characters',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = SaveTreeService();
    addTearDown(service.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<SaveTreeService>.value(
        value: service,
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: Center(
              child: SaveSlotMemoButton(
                projectId: 'memo_test',
                slotIndex: 0,
                initialMemo: '',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('saveSlotMemo_memo_test_0')));
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    expect(find.descendant(of: dialog, matching: find.text('メモ')),
        findsOneWidget,
        reason: 'The title must not be repeated as a floating input label');
    final field = find.descendant(
        of: dialog, matching: find.byType(TextField));
    expect(field, findsOneWidget);
    expect(tester.widget<TextField>(field).maxLength, 100);
    expect(tester.widget<TextField>(field).maxLines, 3);

    final sample = List.filled(100, 'あ').join();
    await tester.enterText(field, sample);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller!.text, sample);
    expect(tester.takeException(), isNull);

    final rect = tester.getRect(dialog);
    const logical = Size(360, 760);
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(logical.width));
    expect(rect.bottom, lessThanOrEqualTo(logical.height));
    // Confirm that the one-line slot label truncates independently.
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
