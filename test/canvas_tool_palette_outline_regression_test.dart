import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/canvas/widgets/canvas_icon_button.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/pc_workspace.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ThemeService> setup() async {
    SharedPreferences.setMockInitialValues({});
    final service = ThemeService();
    await service.init();
    addTearDown(service.dispose);
    return service;
  }

  testWidgets('readable PC dock icons have no unnecessary dark outline',
      (tester) async {
    final service = await setup();
    await tester.pumpWidget(ChangeNotifierProvider<ThemeService>.value(
      value: service,
      child: MaterialApp(
        theme: service.themeData,
        home: const Scaffold(
          body: PcPaletteScope(child: CanvasIconButton(
            icon: Icons.add, tooltip: 'Tool', onPressed: null,
          )),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.widget<Icon>(find.byIcon(Icons.add)).shadows, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('low contrast dock icons keep slim protective outline',
      (tester) async {
    final service = await setup();
    final base = service.themeData;
    await tester.pumpWidget(ChangeNotifierProvider<ThemeService>.value(
      value: service,
      child: MaterialApp(
        theme: base.copyWith(
          colorScheme: base.colorScheme.copyWith(
            onSurface: base.colorScheme.surface,
          ),
        ),
        home: const Scaffold(
          body: PcPaletteScope(child: CanvasIconButton(
            icon: Icons.add, tooltip: 'Low contrast', onPressed: null,
          )),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.widget<Icon>(find.byIcon(Icons.add)).shadows, hasLength(8));
  });

  testWidgets('canvas icons over arbitrary artwork still have slim outline',
      (tester) async {
    final service = await setup();
    await tester.pumpWidget(ChangeNotifierProvider<ThemeService>.value(
      value: service,
      child: MaterialApp(
        theme: service.themeData,
        home: const Scaffold(
          body: CanvasIconButton(
            icon: Icons.add, tooltip: 'Canvas', onPressed: null,
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.widget<Icon>(find.byIcon(Icons.add)).shadows, hasLength(8));
  });

  testWidgets('custom glyph is drawn only once in a readable dock',
      (tester) async {
    final service = await setup();
    await tester.pumpWidget(ChangeNotifierProvider<ThemeService>.value(
      value: service,
      child: MaterialApp(
        theme: service.themeData,
        home: Scaffold(
          body: PcPaletteScope(child: CanvasIconButton(
            iconBuilder: (color) =>
                Text('E', style: TextStyle(color: color)),
            tooltip: 'Eraser', onPressed: null,
          )),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('E'), findsOneWidget);
  });
}
