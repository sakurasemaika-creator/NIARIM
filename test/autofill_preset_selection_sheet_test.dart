import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/autofill_preset.dart';
import 'package:niarim/widgets/autofill_preset_selection_sheet.dart';

void main() {
  test('project preset filter limits part-assignment candidates', () {
    final all = [
      AutofillPreset(id: 'a', name: 'A', parts: const []),
      AutofillPreset(id: 'b', name: 'B', parts: const []),
      AutofillPreset(id: 'c', name: 'C', parts: const []),
    ];
    expect(enabledAutofillPresets(all, null).map((p) => p.id), ['a', 'b', 'c']);
    expect(enabledAutofillPresets(all, const ['c', 'a']).map((p) => p.id), ['a', 'c']);
    expect(enabledAutofillPresets(all, const []), isEmpty);
  });


  Widget host(List<AutofillPreset> presets, void Function(AutofillPresetSelectionResult) onResult) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => onResult(
              await showAutofillPresetSelectionSheet(
                context,
                allPresets: presets,
                initiallyEnabledIds: null,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }

  final presets = [
    AutofillPreset(id: 'a', name: 'A', parts: const []),
    AutofillPreset(id: 'b', name: 'B', parts: const []),
  ];

  testWidgets('autofill preset sheet returns selected project ids', (tester) async {
    AutofillPresetSelectionResult? result;
    await tester.pumpWidget(host(presets, (v) => result = v));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(CheckboxListTile), findsNWidgets(2));
    await tester.tap(find.byType(CheckboxListTile).at(1));
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(result?.cancelled, isFalse);
    expect(result?.ids, ['a']);
  });

  testWidgets('all selected maps to null meaning all presets', (tester) async {
    AutofillPresetSelectionResult? result;
    await tester.pumpWidget(host(presets, (v) => result = v));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(result?.cancelled, isFalse);
    expect(result?.ids, isNull);
  });
}
