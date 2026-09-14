import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/custom_automation.dart';
import 'package:niarim/services/custom_automation_service.dart';
import 'package:niarim/widgets/custom_automation_manager_sheet.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<CustomAutomationService> _service() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final service = CustomAutomationService();
  await service.init();
  return service;
}

Widget _app(CustomAutomationService service) {
  return ChangeNotifierProvider<CustomAutomationService>.value(
    value: service,
    child: MaterialApp(
      locale: const Locale('ja'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              key: const ValueKey('open-automation-manager'),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => CustomAutomationManagerSheet(
                  surface: CustomAutomationSurface.canvas,
                  frameCount: 8,
                  onExecute: (_, _, _) async {},
                  onRecordingStarted: () {},
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

void _prepareViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1200, 1000);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}

Future<void> _openManager(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('open-automation-manager')));
  await tester.pumpAndSettle();
  expect(find.byType(CustomAutomationManagerSheet), findsOneWidget);
}

void _expectNoLifecycleException(WidgetTester tester) {
  expect(tester.takeException(), isNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('new automation dialog can close without disposed controller use', (
    tester,
  ) async {
    _prepareViewport(tester);
    final service = await _service();
    await tester.pumpWidget(_app(service));
    await _openManager(tester);

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    final cancel = find.widgetWithText(TextButton, 'キャンセル');
    expect(cancel, findsOneWidget);
    await tester.tap(cancel);
    await tester.pumpAndSettle();

    _expectNoLifecycleException(tester);
  });

  testWidgets('rename dialog can close without disposed controller use', (
    tester,
  ) async {
    _prepareViewport(tester);
    final service = await _service();
    await tester.pumpWidget(_app(service));
    await _openManager(tester);

    final firstItem = service.visibleItems.first;
    await tester.tap(find.byKey(ValueKey(firstItem.id)));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    final cancel = find.widgetWithText(TextButton, 'キャンセル');
    expect(cancel, findsOneWidget);
    await tester.tap(cancel);
    await tester.pumpAndSettle();

    _expectNoLifecycleException(tester);
  });

  testWidgets('execute dialog can close without disposed controller use', (
    tester,
  ) async {
    _prepareViewport(tester);
    final service = await _service();
    await tester.pumpWidget(_app(service));
    await _openManager(tester);

    final firstItem = service.visibleItems.first;
    await tester.tap(find.byKey(ValueKey(firstItem.id)));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    final no = find.widgetWithText(TextButton, 'いいえ');
    expect(no, findsOneWidget);
    await tester.tap(no);
    await tester.pumpAndSettle();

    _expectNoLifecycleException(tester);
  });
}
