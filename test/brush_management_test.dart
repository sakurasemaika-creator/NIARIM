import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/widgets/brush_panel.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// ブラシの一覧の読み込み・削除・複製（A013で見つけた不具合）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BrushService', () {
    test(
      'a broken saved brush is dropped instead of stopping start-up',
      () async {
        SharedPreferences.setMockInitialValues({});
        final first = BrushService();
        await first.init();
        first.duplicateBrush('Brush0001', name: 'mine');
        await Future<void>.delayed(Duration.zero);
        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getStringList('brushes')!;
        // 途中で切れた1件・項目の欠けた1件・同じIDの1件を混ぜる。
        await prefs.setStringList('brushes', [
          ...saved,
          '{"id": "Brush9',
          jsonEncode({'name': 'no id'}),
          saved.first,
        ]);
        await prefs.setStringList('brush_folders', [
          '{"id"',
          ...?prefs.getStringList('brush_folders'),
        ]);

        final again = BrushService();
        await again.init();
        expect(again.brushes.length, first.brushes.length);
        expect(again.brushes.where((b) => b.name == 'mine'), hasLength(1));
        expect(again.folders, isEmpty);
        // 読めなかった分を除いて保存し直してある。
        final cleaned = (await SharedPreferences.getInstance()).getStringList(
          'brushes',
        )!;
        expect(cleaned.length, first.brushes.length);
      },
    );

    test('deleting the brush in use moves to the next one', () async {
      SharedPreferences.setMockInitialValues({});
      final s = BrushService();
      await s.init();
      final copyId = s.duplicateBrush('Brush0002', name: 'copy')!;
      final other = s.duplicateBrush('Brush0003', name: 'other')!;
      s.selectBrush(copyId);
      expect(s.deleteBrush(copyId), isTrue);
      expect(s.currentBrush?.id, other, reason: '消したブラシの次');
      expect(s.brushes.any((b) => b.id == s.currentBrush?.id), isTrue);
      await Future<void>.delayed(Duration.zero);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('brushes_current_id'), other);
      // 最後のブラシを消したときは前のブラシへ。
      s.selectBrush(other);
      s.deleteBrush(other);
      expect(s.currentBrush?.id, s.brushes.last.id);
      // 無いIDを選んでも例外にしない。
      s.selectBrush('missing');
      expect(s.currentBrush, isNotNull);
    });
  });

  testWidgets('the panel numbers copies in the app language and asks before '
      'deleting', (tester) async {
    final docs = Directory.systemTemp.createTempSync('niarim_brush_mgmt_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => docs.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      docs.deleteSync(recursive: true);
    });
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (themeContext) => MaterialApp(
            theme: themeContext.watch<ThemeService>().themeData,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: BrushPanel(onClose: () {})),
          ),
        ),
      ),
    );
    await tester.pump();
    final brushes = tester
        .element(find.byType(BrushPanel))
        .read<BrushService>();
    final pen = brushes.brushes.first;

    Future<void> menu(String brushName, String action) async {
      // 一覧は見える分だけ作るので、複製（一覧の最後）まで送る。
      await tester.scrollUntilVisible(
        find.text(brushName),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ReorderableListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final row = find.ancestor(
        of: find.text(brushName).first,
        matching: find.byType(ListTile),
      );
      await tester.tap(
        find.descendant(of: row.first, matching: find.byIcon(Icons.more_vert)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final l10n = AppLocalizations.of(
        tester.element(find.byType(BrushPanel)),
      )!;
      await tester.tap(
        find.text(switch (action) {
          'duplicate' => l10n.themeDuplicateAction,
          _ => l10n.commonDelete,
        }).last,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    final l10n = AppLocalizations.of(tester.element(find.byType(BrushPanel)))!;
    await menu(pen.name, 'duplicate');
    await menu(pen.name, 'duplicate');
    final first = '${pen.name} (Copy)';
    final second = '${pen.name} (Copy 2)';
    expect(brushes.brushes.where((b) => b.name == first), hasLength(1));
    expect(brushes.brushes.where((b) => b.name == second), hasLength(1));
    expect(first, isNot(contains('コピー')));

    // 削除は確かめてから。キャンセルなら残る。
    final count = brushes.brushes.length;
    await menu(second, 'delete');
    expect(
      find.text(l10n.brushPanelDeleteConfirmTitle(second)),
      findsOneWidget,
    );
    await tester.tap(find.text(l10n.commonCancel));
    await tester.pumpAndSettle();
    expect(brushes.brushes.length, count);
    await menu(second, 'delete');
    await tester.tap(find.byKey(const Key('brushDeleteConfirm')));
    await tester.pumpAndSettle();
    expect(brushes.brushes.length, count - 1);
    expect(brushes.brushes.where((b) => b.name == second), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
