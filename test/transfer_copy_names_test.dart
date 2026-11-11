import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/niatra_serializer.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/widgets/brush_panel.dart';
import 'package:niarim/services/autofill_preset_service.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/palette_service.dart';
import 'package:niarim/services/pixel_art_palette_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/stamp_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/services/tone_service.dart';
import 'package:niarim/utils/duplicate_name.dart';
import 'package:niarim/utils/transfer_merge.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/niatra_transfer_device.dart';

/// 引き継ぎで足す複製と、アプリの「複製」の名前が同じ形で、互いに番号を
/// 数えること（英語の「(Copy)」と「(copy)」、韓国語の全角と半角の括弧の
/// ように、見分けにくい2つの名前を並べない）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final code in ['en', 'ko']) {
    testWidgets('$code: a brush duplicated in the panel and the copy a '
        'transfer adds are numbered as one series', (tester) async {
      final docs = Directory.systemTemp.createTempSync('niarim_copy_names_');
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => docs.path);
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        docs.deleteSync(recursive: true);
      });
      SharedPreferences.setMockInitialValues({
        'language': code,
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
              locale: Locale(code),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: BrushPanel(onClose: () {})),
            ),
          ),
        ),
      );
      await tester.pump();
      final panel = tester.element(find.byType(BrushPanel));
      final l10n = AppLocalizations.of(panel)!;
      final brushes = panel.read<BrushService>();
      final image = File('${docs.path}/soft.png')..writeAsBytesSync([1, 2, 3]);
      brushes.addBrush(
        customTransferBrush('BrushShared', 'Soft pencil', image.path),
      );
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('Soft pencil'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ReorderableListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final row = find.ancestor(
        of: find.text('Soft pencil').first,
        matching: find.byType(ListTile),
      );
      // 一覧の最後の行は、見える所まで送ってから押す。
      await tester.ensureVisible(row.first);
      await tester.pump();
      await tester.tap(
        find.descendant(of: row.first, matching: find.byIcon(Icons.more_vert)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text(l10n.themeDuplicateAction).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        brushes.brushes.map((b) => b.name),
        contains(l10n.projectDuplicateName('Soft pencil')),
        reason: 'パネルの複製は、引き継ぎの複製と同じ形の名前',
      );

      // もう1台で同じブラシの中身を変えたファイルを読み込む。
      final shared = brushes.brushes.singleWhere((b) => b.id == 'BrushShared');
      await tester.runAsync(
        () => NiatraSerializer.applyTo(
          NiatraData({
            'brushes': [
              {...shared.toJson(), 'spacing': 30},
            ],
          }, Archive()),
          settings: panel.read<SettingsService>(),
          brush: brushes,
          tone: panel.read<ToneService>(),
          stamp: panel.read<StampService>(),
          autofillPresets: panel.read<AutofillPresetService>(),
          theme: panel.read<ThemeService>(),
          palette: panel.read<PaletteService>(),
          pixelArtPalette: panel.read<PixelArtPaletteService>(),
          l10n: l10n,
        ),
      );
      await tester.pump();
      final names = brushes.brushes
          .where((b) => b.name.startsWith('Soft pencil'))
          .map((b) => b.name)
          .toList();
      expect(names, [
        'Soft pencil',
        l10n.projectDuplicateName('Soft pencil'),
        l10n.projectDuplicateNameNumbered('Soft pencil', 2),
      ], reason: '引き継ぎの複製はパネルの複製の次の番号');
      expect(tester.takeException(), isNull);
    });
  }

  for (final code in ['en', 'ko']) {
    testWidgets('$code: duplicating a brush that already has a copy named by '
        'the previous version continues its numbering', (tester) async {
      final docs = Directory.systemTemp.createTempSync('niarim_old_copies_');
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => docs.path);
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        docs.deleteSync(recursive: true);
      });
      SharedPreferences.setMockInitialValues({
        'language': code,
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
              locale: Locale(code),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: BrushPanel(onClose: () {})),
            ),
          ),
        ),
      );
      await tester.pump();
      final panel = tester.element(find.byType(BrushPanel));
      final l10n = AppLocalizations.of(panel)!;
      final brushes = panel.read<BrushService>();
      final pen = brushes.brushes.first;
      // 以前の版のパネルが付けた名前の複製（英語は「(Copy)」、韓国語は
      // 全角の括弧）。
      final old = l10n.themePresetDuplicateName(pen.name);
      brushes.duplicateBrush(pen.id, name: old);
      await tester.pump();

      final row = find.ancestor(
        of: find.text(pen.name).first,
        matching: find.byType(ListTile),
      );
      await tester.tap(
        find.descendant(of: row.first, matching: find.byIcon(Icons.more_vert)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text(l10n.themeDuplicateAction).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        brushes.brushes
            .map((b) => b.name)
            .where((name) => name.startsWith(pen.name)),
        [pen.name, old, l10n.projectDuplicateNameNumbered(pen.name, 2)],
        reason: '以前の版の複製を1つ目と数え、次の番号を付ける',
      );
      expect(tester.takeException(), isNull);
    });
  }

  test('copy numbers continue past copies named in any language or by the '
      'previous version', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final zh = lookupAppLocalizations(const Locale('zh'));
    final ja = lookupAppLocalizations(const Locale('ja'));
    expect(numberedCopyName(en, 'Pen', {}), 'Pen (copy)');
    expect(
      numberedCopyName(en, 'Pen', {'Pen', 'Pen (Copy)', 'Pen (Copy 2)'}),
      'Pen (copy 3)',
      reason: '以前の版の「(Copy)」「(Copy 2)」を数える',
    );
    expect(
      numberedCopyName(zh, 'Pen', {'Pen（副本）', 'Pen（副本） (2)'}),
      'Pen（副本 3）',
      reason: '以前の版のブラシの「（副本） (2)」を数える',
    );
    expect(
      numberedCopyName(ja, 'Pen', {'Pen (copy)'}),
      'Pen (コピー 2)',
      reason: 'ほかの言語の複製も数える',
    );
    expect(
      numberedCopyName(en, 'Pen', {'Pen (copy 2)'}),
      'Pen (copy)',
      reason: '空いている番号を使う',
    );
    expect(
      numberedCopyName(en, 'Pen', {'Pens (copy)', 'Pen (copy) (copy)'}),
      'Pen (copy)',
      reason: 'ほかの名前の複製は数えない',
    );
  });

  test('a transfer copy of an item whose name is already a copy name takes '
      'the next number of the original name instead of doubling the '
      'suffix', () {
    final ja = lookupAppLocalizations(const Locale('ja'));
    final en = lookupAppLocalizations(const Locale('en'));
    final report = TransferImportReport();
    final names = TransferCopyNames(ja, report: report);
    expect(names.next('Gペン (コピー)', {'Gペン', 'Gペン (コピー)'}), 'Gペン (コピー 2)');
    expect(
      names.next('Gペン (コピー 2)', {'Gペン', 'Gペン (コピー)', 'Gペン (コピー 2)'}),
      'Gペン (コピー 3)',
    );
    expect(
      names.next('Gペン (コピー)', {'Gペン (コピー)'}),
      'Gペン (コピー 2)',
      reason: '元の名前の物が無くても、複製の番号を続ける',
    );
    expect(names.next('Gペン', {'Gペン'}), 'Gペン (コピー)', reason: '複製の名前でなければ今までどおり');
    expect(
      TransferCopyNames(en).next('Pen (copy)', {'Pen', 'Pen (copy)'}),
      'Pen (copy 2)',
    );
    expect(
      TransferCopyNames(en).next('Pen (コピー)', {'Pen (コピー)'}),
      'Pen (copy 2)',
      reason: 'ほかの言語の複製の名前も、元の名前の次の番号',
    );
    expect(report.addedCopies, [
      'Gペン (コピー 2)',
      'Gペン (コピー 3)',
      'Gペン (コピー 2)',
      'Gペン (コピー)',
    ]);
  });

  test('themes and auto-fill presets are duplicated with the same copy '
      'names as brushes and transfers', () {
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.path.contains('lib/l10n/')) continue;
      if (file.path.endsWith('lib/utils/duplicate_name.dart')) continue;
      final source = file.readAsStringSync();
      for (final name in [
        'themePresetDuplicateName(',
        'autofillPresetDuplicateName(',
      ]) {
        if (source.contains(name)) offenders.add('${file.path}: $name');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          '複製の名前はnumberedCopyName（projectDuplicateName）で付ける。'
          '古い形の名前は、複製と見分けて番号を数えるためだけに使う',
    );
  });
}
