import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/custom_automation.dart';
import 'package:niarim/models/custom_automation_builtin_presets.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/services/custom_automation_service.dart';
import 'package:niarim/utils/custom_automation_labels.dart';
import 'package:niarim/utils/filter_display_name.dart';
import 'package:niarim/widgets/custom_automation_manager_sheet.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _japanese = RegExp(r'[぀-ヿ]');

CustomAutomationStep _step(String command, [Map<String, Object?>? args]) =>
    CustomAutomationStep(
      id: 'step',
      surface: CustomAutomationSurface.canvas,
      command: command,
      label: 'stored label',
      args: args ?? const {},
    );

/// The official automation presets ship (and are stored on the device) with
/// Japanese names and step labels; they are shown in the app's language,
/// as are the steps a recording makes, and the layers a filter adds when an
/// automation or a recorded filter runs it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('in every language', () {
    for (final locale in AppLocalizations.supportedLocales) {
      test('$locale: the official presets and their steps', () async {
        final l10n = await AppLocalizations.delegate.load(locale);
        for (final preset in CustomAutomationBuiltinPresets.all()) {
          final name = customAutomationDisplayName(l10n, preset.name);
          expect(name, isNotEmpty);
          if (locale.languageCode != 'ja') {
            expect(name, isNot(preset.name));
            if (locale.languageCode != 'zh') {
              expect(name, isNot(matches(_japanese)), reason: name);
            }
          }
          for (final step in preset.steps) {
            final label = customAutomationStepLabel(l10n, step);
            expect(label, isNot('stored label'));
            expect(label, isNotEmpty);
            if (!{'ja', 'zh'}.contains(locale.languageCode)) {
              expect(label, isNot(matches(_japanese)), reason: label);
            }
          }
        }
      });
    }
  });

  test('a name of the user\'s own is shown as it is', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(customAutomationDisplayName(l10n, 'My lines'), 'My lines');
  });

  test('recorded steps say what they do', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(
      customAutomationStepLabel(
        l10n,
        _step('canvas.selectFrame', {'frame': 4}),
      ),
      'Go to frame 5',
    );
    expect(
      customAutomationStepLabel(l10n, _step('canvas.brushSize', {'value': 12})),
      'Brush size 12px',
    );
    expect(
      customAutomationStepLabel(
        l10n,
        _step('canvas.brushOpacity', {'value': 40}),
      ),
      'Brush opacity 40%',
    );
    expect(
      customAutomationStepLabel(l10n, _step('canvas.tool', {'tool': 'eraser'})),
      'Tool: ${l10n.toolbarItemEraser}',
    );
    expect(
      customAutomationStepLabel(
        l10n,
        _step('canvas.color', {'argb': 0xFF12AB34}),
      ),
      'Drawing color #12AB34',
    );
    expect(
      customAutomationStepLabel(l10n, _step('timeline.addFrame')),
      'Add a frame',
    );
    const blur = FilterDef(
      id: 'Filter0001',
      name: 'ガウスぼかし',
      kind: FilterKind.gaussianBlur,
    );
    expect(
      customAutomationStepLabel(
        l10n,
        _step('canvas.filterApply', {'filter': blur.toJson()}),
      ),
      'Apply filter: ${l10n.filterNameGaussianBlur}',
    );
    // A command this version does not know keeps the label it came with.
    expect(
      customAutomationStepLabel(l10n, _step('canvas.somethingNew')),
      'stored label',
    );
  });

  test('a filter\'s new layer is named in the app\'s language', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    const outline = FilterDef(
      id: 'Filter0006',
      name: '縁取り',
      kind: FilterKind.outline,
    );
    const inkPool = FilterDef(
      id: 'Filter0021',
      name: '墨溜まり',
      kind: FilterKind.inkPool,
    );
    expect(generatedLayerName(en, 'Hair', outline), 'Hair (Outline)');
    expect(
      generatedLayerName(en, 'Hair', inkPool),
      en.filterInkPoolLayerNameSuffix('Hair'),
    );
    expect(generatedLayerName(en, 'Hair', inkPool), isNot(contains('墨')));
  });

  testWidgets('the manager lists the official presets in English', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final service = CustomAutomationService();
    await service.init();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: service,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CustomAutomationManagerSheet(
              surface: CustomAutomationSurface.canvas,
              onExecute: (_, _, _) async {},
              onRecordingStarted: () {},
              frameCount: 12,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(CustomAutomationManagerSheet)),
    )!;
    expect(find.text(l10n.customAutomationBuiltinDraftToLineart), findsOne);
    expect(find.text(l10n.customAutomationBuiltinAnalogLineart), findsOne);
    expect(find.text(l10n.customAutomationBuiltinLineartColorTrace), findsOne);
    expect(find.textContaining(_japanese), findsNothing);
  });
}
