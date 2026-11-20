import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/autofill_preset.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/screens/autofill/autofill_preset_screen.dart';
import 'package:niarim/services/autofill_preset_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/widgets/menu_action_label.dart';
import 'package:niarim/widgets/name_entry_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/project_storage.dart';

const part = AutofillPart(id: 'part-fixture', name: 'Hair', color: 0xff875036);
const preset = AutofillPreset(
  id: 'preset-fixture',
  name: 'Practice',
  parts: [part],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useTemporaryProjectStorage();

  final l10n = lookupAppLocalizations(const Locale('en'));

  Future<BuildContext> open(
    WidgetTester tester, {
    ThemeData? theme,
    ValueNotifier<Locale>? locale,
  }) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final providers = (await tester.runAsync(buildAppProviders))!;
    final language = locale ?? ValueNotifier(const Locale('en'));
    addTearDown(language.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: ValueListenableBuilder<Locale>(
          valueListenable: language,
          builder: (context, value, child) => MaterialApp(
            theme: theme,
            locale: value,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: child,
          ),
          child: const AutofillPresetScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(AutofillPresetScreen));
    await context.read<AutofillPresetService>().addPreset(preset);
    await tester.pumpAndSettle();
    return context;
  }

  Future<void> presetMenu(
    WidgetTester tester,
    String name,
    String action,
  ) async {
    final row = find.widgetWithText(ListTile, name);
    await tester.tap(
      find.descendant(of: row, matching: find.byType(PopupMenuButton<String>)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(action).hitTestable());
    await tester.pumpAndSettle();
  }

  testWidgets('language changes translate only shipped preset names', (
    tester,
  ) async {
    final locale = ValueNotifier(const Locale('en'));
    await open(tester, locale: locale);
    expect(find.text(l10n.autofillSampleGray), findsOneWidget);
    await presetMenu(tester, l10n.autofillSampleLead, l10n.commonRename);
    await tester.enterText(find.byType(TextField), '主人公');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    locale.value = const Locale('fr');
    await tester.pumpAndSettle();
    final french = lookupAppLocalizations(locale.value);
    expect(find.text(french.autofillSampleGray), findsOneWidget);
    expect(find.text(l10n.autofillSampleGray), findsNothing);
    expect(find.text(french.autofillSampleLead), findsNothing);
    expect(find.text('主人公'), findsOneWidget);
    expect(find.text(preset.name), findsOneWidget);
  });

  test(
    'legacy duplicate part IDs are separated while the first lookup is preserved',
    () async {
      final copy = preset.copyWith(
        id: 'legacy-copy',
        parts: [part.copyWith(color: 0xff112233)],
      );
      SharedPreferences.setMockInitialValues({
        'autofill_presets': [
          jsonEncode(preset.toJson()),
          jsonEncode(copy.toJson()),
        ],
      });
      final first = AutofillPresetService();
      await first.init();
      final repaired = first.presets
          .firstWhere((p) => p.id == copy.id)
          .parts
          .single;
      expect(repaired.id, isNot(part.id));
      expect(repaired.color, 0xff112233);
      expect(first.findPart(part.id)?.color, part.color);
      final restarted = AutofillPresetService();
      await restarted.init();
      expect(restarted.findPart(repaired.id)?.color, 0xff112233);
      expect(restarted.findPart(part.id)?.color, part.color);
      const newPart = AutofillPart(
        id: 'unique-imported-part',
        name: 'Shirt',
        color: 0xff778899,
      );
      await restarted.addPreset(
        preset.copyWith(id: 'imported', parts: [part, newPart]),
      );
      final imported = restarted.presets.last;
      expect(imported.parts.first.id, isNot(part.id));
      expect(imported.parts.last.id, newPart.id);
      expect(restarted.findPart(part.id)?.color, part.color);
      first.dispose();
      restarted.dispose();
    },
  );

  testWidgets(
    'duplicate and paste assign distinct parts and show which works use them',
    (tester) async {
      final context = await open(tester);
      final presets = context.read<AutofillPresetService>();
      final projects = context.read<ProjectService>();
      final project = (await tester.runAsync(
        () => projects.createProject(
          name: 'Part references',
          fps: 2,
          durationSeconds: 1,
          backgroundColor: 0xffffffff,
          exportWidth: 32,
          exportHeight: 32,
        ),
      ))!;
      final scene = projects.scenesOf(project.id).first;
      for (var i = 0; i < scene.frames.length; i++) {
        final layer = scene.frames[i].layers.first;
        projects.updateLayer(
          projectId: project.id,
          sceneId: scene.id,
          frameIndex: i,
          layer: layer.copyWith(
            id: scene.frames.first.layers.first.id,
            type: LayerType.autoFillLineart,
            partId: part.id,
          ),
        );
      }
      await tester.pumpAndSettle();

      final originalRow = find.widgetWithText(ListTile, preset.name);
      await tester.longPress(originalRow);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(l10n.commonDuplicate));
      await tester.pumpAndSettle();
      Iterable<AutofillPreset> copies() =>
          presets.presets.where((p) => p.name.startsWith(preset.name));
      expect(copies(), hasLength(2));
      final copiedPart = copies().last.parts.single;
      expect(copiedPart.id, isNot(part.id));
      expect(copiedPart.color, part.color);

      await tester.longPress(originalRow);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(l10n.commonPaste));
      await tester.pumpAndSettle();
      expect(copies().map((p) => p.parts.single.id).toSet(), hasLength(3));
      await presets.updatePreset(
        copies().last.copyWith(
          parts: [copies().last.parts.single.copyWith(color: 0xff001122)],
        ),
      );
      expect(
        presets.findPart(copies().last.parts.single.id)?.color,
        0xff001122,
      );
      expect(presets.findPart(part.id)?.color, part.color);

      await presetMenu(tester, preset.name, l10n.commonDelete);
      expect(find.text(l10n.autofillDeleteUsage(1, 1)), findsOneWidget);
      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();
      expect(presets.findPart(part.id), isNotNull);
    },
  );

  testWidgets('preset and part delete controls use the dark surface colors', (
    tester,
  ) async {
    const menuInk = Color(0xffe8e0ff);
    const error = Color(0xff741620);
    final theme = ThemeData(
      colorScheme: const ColorScheme.dark(error: error),
      popupMenuTheme: const PopupMenuThemeData(
        iconColor: menuInk,
        textStyle: TextStyle(color: menuInk),
      ),
    );
    final context = await open(tester, theme: theme);
    final row = find.widgetWithText(ListTile, preset.name);
    await tester.tap(
      find.descendant(of: row, matching: find.byType(PopupMenuButton<String>)),
    );
    await tester.pumpAndSettle();

    final action = find.widgetWithText(MenuActionLabel, l10n.commonDelete);
    final menuIcon = find.descendant(
      of: action,
      matching: find.byIcon(Icons.delete_outline),
    );
    expect(tester.widget<Icon>(menuIcon).color, menuInk);
    final label = find.descendant(
      of: action,
      matching: find.text(l10n.commonDelete),
    );
    final rename = find.text(l10n.commonRename).hitTestable();
    expect(
      DefaultTextStyle.of(tester.element(label)).style.color,
      DefaultTextStyle.of(tester.element(rename)).style.color,
    );
    expect(tester.widget<Text>(label).style?.color, isNull);
    await tester.tap(label);
    await tester.pumpAndSettle();
    final confirm = find.widgetWithText(FilledButton, l10n.commonDelete);
    expect(tester.widget<FilledButton>(confirm).style?.backgroundColor, isNull);
    await tester.tap(find.widgetWithText(TextButton, l10n.commonCancel));
    await tester.pumpAndSettle();

    await tester.tap(row);
    await tester.pumpAndSettle();
    final partDelete = find.byTooltip(l10n.commonDelete);
    final partIcon = find.descendant(
      of: partDelete,
      matching: find.byIcon(Icons.delete),
    );
    expect(tester.widget<Icon>(partIcon).color, isNull);
    await tester.tap(partDelete);
    await tester.pumpAndSettle();
    expect(find.text(l10n.confirmDeleteNamedBody(part.name)), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, l10n.commonDelete));
    await tester.pumpAndSettle();
    expect(context.read<AutofillPresetService>().findPart(part.id), isNull);
  });

  testWidgets(
    'preset and part names validate on Enter, and missing tones cannot be applied',
    (tester) async {
      final context = await open(tester);
      final presets = context.read<AutofillPresetService>();
      final nameDialog = find.byType(NameEntryDialog);
      Future<void> enter(String name) async {
        await tester.enterText(
          find.descendant(of: nameDialog, matching: find.byType(TextField)),
          name,
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
      }

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.autofillPresetNewDialogTitle));
      await tester.pumpAndSettle();
      await enter('  ');
      expect(nameDialog, findsOneWidget);
      await enter('  Practice  ');
      expect(presets.presets.last.name, 'Practice (2)');

      await presetMenu(tester, 'Practice (2)', l10n.commonRename);
      await enter('  ');
      expect(nameDialog, findsOneWidget);
      await enter('Practice');
      expect(presets.presets.last.name, 'Practice (2)');

      await tester.tap(find.widgetWithText(ListTile, preset.name));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await enter('  ');
      expect(nameDialog, findsOneWidget);
      await enter(' Hair ');
      final newPart = presets.presets
          .firstWhere((p) => p.id == preset.id)
          .parts
          .last;
      expect(newPart.name, 'Hair (2)');
      await tester.tap(
        find.descendant(
          of: find.byKey(ValueKey(newPart.id)),
          matching: find.byTooltip(l10n.commonEdit),
        ),
      );
      await tester.pumpAndSettle();
      await enter('  ');
      expect(nameDialog, findsOneWidget);
      await enter('Hair');
      expect(presets.findPart(newPart.id)?.name, 'Hair (2)');

      final row = tester.widget<ListTile>(find.byKey(ValueKey(part.id)));
      await tester.tap(find.byWidget(row.leading!));
      await tester.pumpAndSettle();
      final toneSwitch = find.widgetWithText(
        CheckboxListTile,
        l10n.autofillPartUseToneCheckbox,
      );
      await tester.ensureVisible(toneSwitch);
      await tester.pumpAndSettle();
      await tester.tap(toneSwitch.hitTestable());
      await tester.pumpAndSettle();
      final apply = find.widgetWithText(
        FilledButton,
        l10n.autofillPartApplyButton,
      );
      expect(tester.widget<FilledButton>(apply).onPressed, isNull);
      expect(presets.findPart(part.id)?.useTone, isFalse);
      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();
      expect(presets.findPart(part.id)?.useTone, isFalse);

      await tester.pageBack();
      await tester.pumpAndSettle();
      final saved = presets.presets.firstWhere((p) => p.id == preset.id);
      await presets.updatePreset(
        saved.copyWith(parts: [part.copyWith(useTone: true), newPart]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, preset.name));
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.autofillPartUnconfiguredBanner(1, part.name)),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, preset.name), findsOneWidget);
    },
  );
  testWidgets('gradient stops match the circular editor preview endpoints', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.widgetWithText(ListTile, preset.name));
    await tester.pumpAndSettle();
    final row = tester.widget<ListTile>(find.byKey(ValueKey(part.id)));
    await tester.tap(find.byWidget(row.leading!));
    await tester.pumpAndSettle();
    final set = find.text(l10n.autofillPartGradientSetButton);
    await tester.ensureVisible(set);
    await tester.pumpAndSettle();
    await tester.tap(set.hitTestable());
    await tester.pumpAndSettle();
    final preview = find.byKey(const ValueKey('autofillGradientPreview'));
    Gradient gradient() =>
        (tester.widget<DecoratedBox>(preview).decoration as BoxDecoration)
            .gradient!;
    final linear = gradient() as LinearGradient;
    expect(linear.begin, const Alignment(-1, 0));
    expect(linear.end, const Alignment(1, 0));
    expect(linear.stops, [0, 1]);
    expect(linear.colors, [Color(part.color), Colors.white]);
    final radial = find.text(l10n.autofillGradientTypeRadialCenterOut);
    await tester.ensureVisible(radial);
    await tester.pumpAndSettle();
    await tester.tap(radial.hitTestable());
    await tester.pumpAndSettle();
    expect((gradient() as RadialGradient).radius, 0.5);
    expect((gradient() as RadialGradient).center, Alignment.center);
  });
}
