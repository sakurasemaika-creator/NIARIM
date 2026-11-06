import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/project/new_project_screen.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// 「サイズ設定」（保存したキャンバスサイズの管理）と、新規プロジェクトでの
/// 選び方。範囲外のサイズは保存しない・空白の名前にしない・複製の名前・
/// 組み込みと同じ大きさのサイズでも選んだチップだけが選ばれる。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SettingsService> open(
    WidgetTester tester, {
    List<Map<String, Object>> presets = const [],
  }) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'custom_size_presets': [for (final p in presets) jsonEncode(p)],
    });
    final directory = Directory.systemTemp.createTempSync('size-presets-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(420, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = await tester.runAsync(buildAppProviders);
    appRouter.go('/new-project');
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pumpAndSettle();
    return tester
        .element(find.byType(NewProjectScreen))
        .read<SettingsService>();
  }

  Future<void> openManager(WidgetTester tester) async {
    await tester.tap(find.text('サイズ設定').first);
    await tester.pumpAndSettle();
  }

  Future<void> menu(WidgetTester tester, String item) async {
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(item).last);
    await tester.pumpAndSettle();
  }

  const wide = {'id': 'size_wide', 'name': '横長', 'width': 1920, 'height': 1080};

  testWidgets('a size outside 64–1920 cannot be saved; Enter saves a valid '
      'one', (tester) async {
    final settings = await open(tester, presets: [wide]);
    await openManager(tester);
    await menu(tester, 'サイズを編集');
    final width = find.byKey(const Key('presetWidthField'));
    final height = find.byKey(const Key('presetHeightField'));
    final save = find.widgetWithText(FilledButton, '変更');
    await tester.enterText(width, '5000');
    await tester.pump();
    expect(find.text('64〜1920の数字を入力してください'), findsOneWidget);
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.enterText(width, '');
    await tester.pump();
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    // 数字以外は打てない。
    await tester.enterText(height, '1a0');
    await tester.pump();
    expect(tester.widget<TextField>(height).controller!.text, '10');
    await tester.enterText(width, '1280');
    await tester.enterText(height, '720');
    await tester.pump();
    expect(find.text('64〜1920の数字を入力してください'), findsNothing);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(settings.customSizePresets.single.width, 1280);
    expect(settings.customSizePresets.single.height, 720);
    expect(find.text('1280×720'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rename refuses blank names; copies are numbered', (
    tester,
  ) async {
    final settings = await open(tester, presets: [wide]);
    await openManager(tester);
    await menu(tester, '名前変更');
    final field = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, '   ');
    await tester.pump();
    final change = find.widgetWithText(FilledButton, '変更');
    expect(tester.widget<FilledButton>(change).onPressed, isNull);
    await tester.enterText(field, ' 動画 ');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(settings.customSizePresets.single.name, '動画');

    await menu(tester, 'コピー');
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('コピー').last);
    await tester.pumpAndSettle();
    expect(settings.customSizePresets.map((p) => p.name), [
      '動画',
      '動画 (コピー)',
      '動画 (コピー 2)',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a saved size equal to a built-in one is chosen on its own, '
      'and follows edits', (tester) async {
    final settings = await open(tester, presets: [wide]);
    ChoiceChip chip(String start) => tester.widget<ChoiceChip>(
      find.ancestor(
        of: find.textContaining(start),
        matching: find.byType(ChoiceChip),
      ),
    );
    // 最初は組み込みのFull HDだけ。
    expect(chip('Full HD').selected, isTrue);
    expect(chip('横長').selected, isFalse);
    await tester.ensureVisible(find.textContaining('横長'));
    await tester.tap(find.textContaining('横長'));
    await tester.pumpAndSettle();
    expect(chip('Full HD').selected, isFalse);
    expect(chip('横長').selected, isTrue);

    // サイズ設定で大きさを変えると、選んでいる大きさも変わる。
    await settings.updateCustomSizePreset('size_wide', width: 640, height: 480);
    await tester.pumpAndSettle();
    expect(chip('横長').selected, isTrue);
    expect(find.textContaining('640×480'), findsWidgets);
    expect(find.text('書き出しサイズ: 640×480'), findsOneWidget);

    // 消すと、今の大きさのままカスタムになる。
    await settings.removeCustomSizePreset('size_wide');
    await tester.pumpAndSettle();
    expect(chip('カスタム').selected, isTrue);
    expect(find.text('書き出しサイズ: 640×480'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a size saved out of range by an older version is kept in '
      'range when read and chosen', (tester) async {
    final settings = await open(
      tester,
      presets: [
        {'id': 'size_big', 'name': '大きすぎ', 'width': 5000, 'height': 5000},
      ],
    );
    expect(settings.customSizePresets.single.width, 1920);
    expect(settings.customSizePresets.single.height, 1920);
    await tester.ensureVisible(find.textContaining('大きすぎ'));
    expect(find.textContaining('大きすぎ (1920×1920)'), findsOneWidget);
    await tester.tap(find.textContaining('大きすぎ'));
    await tester.pumpAndSettle();
    expect(find.text('書き出しサイズ: 1920×1920'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
