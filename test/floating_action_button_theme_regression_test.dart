import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all built-in themes flatten only the floating buttons', () async {
    SharedPreferences.setMockInitialValues({});
    final service = ThemeService();
    await service.init();
    addTearDown(service.dispose);
    expect(service.presets, isNotEmpty);
    for (final preset in service.presets) {
      service.applyPreset(preset.id);
      final theme = service.themeData;
      final fab = theme.floatingActionButtonTheme;
      expect(fab.elevation, 0, reason: preset.name);
      expect(fab.focusElevation, 0, reason: preset.name);
      expect(fab.hoverElevation, 0, reason: preset.name);
      expect(fab.highlightElevation, 0, reason: preset.name);
      expect(fab.disabledElevation, 0, reason: preset.name);
      expect(fab.shape, isA<CircleBorder>(), reason: preset.name);
      expect((fab.shape! as CircleBorder).side, BorderSide.none,
          reason: preset.name);
      expect(fab.backgroundColor, theme.colorScheme.primary,
          reason: preset.name);
      expect(fab.foregroundColor, theme.colorScheme.onPrimary,
          reason: preset.name);
      expect(theme.shadowColor, isNot(Colors.transparent),
          reason: 'Card/dialog shadows must remain independent of FAB');
      expect(theme.snackBarTheme.elevation, 0, reason: preset.name);
    }
  });

  testWidgets('normal, mini and extended FABs inherit zero elevation',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = ThemeService();
    await service.init();
    addTearDown(service.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: service.themeData,
      home: Scaffold(
        body: const Center(child: Text('Floating action button audit')),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              key: const Key('normal-fab'), heroTag: 'normal',
              onPressed: () {}, child: const Icon(Icons.add),
            ),
            FloatingActionButton(
              key: const Key('mini-fab'), heroTag: 'mini', mini: true,
              onPressed: () {}, child: const Icon(Icons.edit),
            ),
            FloatingActionButton.extended(
              key: const Key('extended-fab'), heroTag: 'extended',
              onPressed: () {}, shape: const StadiumBorder(),
              label: const Text('Create'),
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    for (final name in ['normal-fab', 'mini-fab', 'extended-fab']) {
      final button = find.byKey(Key(name));
      expect(button, findsOneWidget);
      final fab = tester.widget<FloatingActionButton>(button);
      expect(fab.elevation, isNull, reason: name);
      expect(fab.focusElevation, isNull, reason: name);
      expect(fab.hoverElevation, isNull, reason: name);
      expect(fab.highlightElevation, isNull, reason: name);
      expect(fab.disabledElevation, isNull, reason: name);
      final materials = tester.widgetList<Material>(
        find.descendant(of: button, matching: find.byType(Material)),
      ).toList();
      expect(materials, isNotEmpty, reason: name);
      expect(materials.every((m) => m.elevation == 0), isTrue,
          reason: 'No thick shadow on $name');
    }
    await tester.tap(find.byKey(const Key('normal-fab')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
