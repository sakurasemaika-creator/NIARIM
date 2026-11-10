import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/autofill/autofill_preset_screen.dart';
import 'package:niarim/screens/canvas/widgets/brush_panel.dart';
import 'package:niarim/screens/canvas/widgets/color_picker_panel.dart';
import 'package:niarim/screens/canvas/widgets/stamp_panel.dart';
import 'package:niarim/screens/canvas/widgets/tone_panel.dart';
import 'package:niarim/screens/settings/theme_settings_screen.dart';
import 'package:niarim/screens/settings/transfer_screen.dart';
import 'package:niarim/screens/settings/workspace_settings_screen.dart';
import 'package:niarim/services/autofill_preset_service.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/stamp_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/services/tone_service.dart';
import 'package:niarim/services/workspace_preset_service.dart';
import 'package:niarim/utils/app_error_reporter.dart';
import 'package:niarim/widgets/pixel_art_palette_picker_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_share_channel.dart';
import 'helpers/first_use_tooltips.dart';
import 'helpers/pump_real_async.dart';

/// 書き出した作品以外の共有（テーマ・ブラシ・トーン・スタンプ・自動塗りの
/// プリセット・ワークスペース・パレット・引き継ぎ）。
///
/// 以前はどこも、書き出しと共有を1つの`catch`で受けて「書き出しに失敗しました:
/// MissingPluginException(…)」のように出していた。書き出しはできているのに
/// 失敗と呼び、OSの例外の文をそのまま見せ、共有シートを閉じただけでも
/// 「書き出しました」と出し、二度押しで共有を二重に呼んだ。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final share = FakeShareChannel();
  const mockText = 'no share on this device 4711';

  setUp(share.install);
  tearDown(share.remove);

  Future<AppLocalizations> pumpHome(
    WidgetTester tester,
    Widget home, {
    Size size = const Size(900, 1600),
    Map<String, Object> prefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues({
      'language': 'ja',
      'first_launch': false,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      ...prefs,
    });
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (themeContext) => MaterialApp(
            theme: themeContext.watch<ThemeService>().themeData,
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: home,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    return AppLocalizations.of(tester.element(find.byType(Scaffold).first))!;
  }

  Future<void> clearSnackBars(WidgetTester tester) async {
    ScaffoldMessenger.of(
      tester.element(find.byType(Scaffold).first),
    ).clearSnackBars();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  /// SnackBarに出ている文（出ていなければ空）。
  List<String> snackBarTexts(WidgetTester tester) => [
    for (final text in tester.widgetList<Text>(
      find.descendant(of: find.byType(SnackBar), matching: find.byType(Text)),
    ))
      text.data ?? '',
  ];

  /// 行のメニューを開いて[item]を選ぶ。押せない項目のときはメニューを閉じる。
  Future<void> chooseFromMenu(
    WidgetTester tester,
    Finder menuButton,
    String item,
  ) async {
    await tester.ensureVisible(menuButton);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(menuButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text(item).last, warnIfMissed: false);
    await pumpRealAsync(tester, const Duration(milliseconds: 500));
    if (find.text(item).evaluate().isNotEmpty) {
      await tester.tapAt(const Offset(2, 2));
      await pumpRealAsync(tester, const Duration(milliseconds: 400));
    }
  }

  testWidgets('theme export: a share problem is reported as a share problem, '
      'once, without the exception text', (tester) async {
    final l10n = await pumpHome(tester, const ThemeSettingsScreen());
    final themes = tester
        .element(find.byType(ThemeSettingsScreen))
        .read<ThemeService>();
    final preset = themes.presets.firstWhere((p) => p.id != themes.current.id);
    final exportFailed = failureLead(l10n.themeExportFailedSnackbar);
    expect(exportFailed, isNotEmpty);
    final written = File('${share.directory.path}/${preset.name}.niatheme');

    Future<void> export() async {
      await tester.scrollUntilVisible(
        find.text(preset.name),
        110,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 60,
      );
      await tester.pump(const Duration(milliseconds: 250));
      await chooseFromMenu(
        tester,
        find
            .descendant(
              of: find
                  .ancestor(
                    of: find.text(preset.name),
                    matching: find.byType(Row),
                  )
                  .first,
              matching: find.byType(PopupMenuButton<String>),
            )
            .first,
        l10n.themeExportMenuItem,
      );
    }

    // 共有の仕組みが無い端末。
    final recorded = AppErrorReporter.recentErrors.length;
    share.failure = MissingPluginException(mockText);
    await export();
    expect(tester.takeException(), isNull);
    expect(share.calls, 1);
    expect(written.existsSync(), isTrue, reason: '書き出しはできている');
    expect(snackBarTexts(tester), [l10n.communityErrorUnsupported]);
    expectNoInternalText(tester, also: [mockText, exportFailed]);
    expect(AppErrorReporter.recentErrors.length, greaterThan(recorded));
    await clearSnackBars(tester);

    // それ以外の失敗。
    share.failure = PlatformException(code: 'Share failed', message: mockText);
    await export();
    expect(tester.takeException(), isNull);
    expect(share.calls, 2);
    expect(snackBarTexts(tester), [l10n.communityErrorGeneric]);
    expectNoInternalText(tester, also: [mockText, exportFailed]);
    await clearSnackBars(tester);

    // 共有シートを閉じただけなら何も出さない。
    share
      ..failure = null
      ..result = '';
    await export();
    expect(tester.takeException(), isNull);
    expect(share.calls, 3);
    expect(find.byType(SnackBar), findsNothing);

    // 共有シートが開いている間にもう一度選んでも、共有は1回だけ。
    share.pending = Completer<String>();
    await export();
    await export();
    expect(share.calls, 4, reason: '二度押しで共有を二重に呼ばない');
    share.pending!.complete('');
    share.pending = null;
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.byType(SnackBar), findsNothing);
    // 終わった後は、また共有できる。
    await export();
    expect(share.calls, 5);
  });

  // ブラシ・トーン・スタンプの一覧は同じ作り（行のメニューの「書き出し」）。
  for (final kind in ['brush', 'tone', 'stamp']) {
    testWidgets('$kind export: a share problem is reported as a share problem, '
        'once, without the exception text', (tester) async {
      final l10n = await pumpHome(
        tester,
        Scaffold(
          body: switch (kind) {
            'brush' => BrushPanel(onClose: () {}),
            'tone' => TonePanel(onClose: () {}),
            _ => StampPanel(onClose: () {}),
          },
        ),
        size: const Size(450, 1200),
      );
      final panel = tester.element(find.byType(ListTile).first);
      final name = switch (kind) {
        'brush' => panel.read<BrushService>().brushes.first.name,
        'tone' => panel.read<ToneService>().tones.first.name,
        _ => panel.read<StampService>().stamps.first.name,
      };
      final exportFailed = failureLead(switch (kind) {
        'brush' => l10n.brushExportFailedSnackbar,
        'tone' => l10n.toneExportFailedSnackbar,
        _ => l10n.stampExportFailedSnackbar,
      });
      expect(exportFailed, isNotEmpty);
      final written = File('${share.directory.path}/$name.nia$kind');

      Future<void> export() async {
        final row = find.ancestor(
          of: find.text(name).first,
          matching: find.byType(ListTile),
        );
        await chooseFromMenu(
          tester,
          find.descendant(
            of: row.first,
            matching: find.byIcon(Icons.more_vert),
          ),
          l10n.transferExport,
        );
      }

      final recorded = AppErrorReporter.recentErrors.length;
      share.failure = MissingPluginException(mockText);
      await export();
      expect(tester.takeException(), isNull);
      expect(share.calls, 1);
      expect(written.existsSync(), isTrue, reason: '書き出しはできている');
      expect(share.lastPaths, [written.path]);
      expect(snackBarTexts(tester), [l10n.communityErrorUnsupported]);
      expectNoInternalText(tester, also: [mockText, exportFailed]);
      expect(AppErrorReporter.recentErrors.length, greaterThan(recorded));
      await clearSnackBars(tester);

      share.failure = PlatformException(
        code: 'Share failed',
        message: mockText,
      );
      await export();
      expect(tester.takeException(), isNull);
      expect(snackBarTexts(tester), [l10n.communityErrorGeneric]);
      expectNoInternalText(tester, also: [mockText, exportFailed]);
      await clearSnackBars(tester);

      share
        ..failure = null
        ..result = '';
      await export();
      expect(find.byType(SnackBar), findsNothing);
      expect(share.calls, 3);

      share.pending = Completer<String>();
      await export();
      await export();
      expect(share.calls, 4, reason: '二度押しで共有を二重に呼ばない');
      share.pending!.complete('');
      share.pending = null;
      await pumpRealAsync(tester, const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      await export();
      expect(share.calls, 5);
    });
  }

  testWidgets('auto-fill preset export: a share problem is reported as a share '
      'problem, once, and the bulk export waits for the open sheet', (
    tester,
  ) async {
    final l10n = await pumpHome(
      tester,
      const AutofillPresetScreen(),
      size: const Size(450, 1200),
    );
    final preset = tester
        .element(find.byType(AutofillPresetScreen))
        .read<AutofillPresetService>()
        .presets
        .first;
    final exportFailed = failureLead(l10n.autofillPresetExportFailedSnackbar);
    expect(exportFailed, isNotEmpty);
    final written = File('${share.directory.path}/${preset.name}.niafill');

    Future<void> export() => chooseFromMenu(
      tester,
      find.descendant(
        of: find
            .ancestor(
              of: find.text(preset.name),
              matching: find.byType(ListTile),
            )
            .first,
        matching: find.byType(PopupMenuButton<String>),
      ),
      l10n.autofillPresetExportMenuItem,
    );

    final recorded = AppErrorReporter.recentErrors.length;
    share.failure = MissingPluginException(mockText);
    await export();
    expect(tester.takeException(), isNull);
    expect(share.calls, 1);
    expect(written.existsSync(), isTrue, reason: '書き出しはできている');
    expect(share.lastPaths, [written.path]);
    expect(snackBarTexts(tester), [l10n.communityErrorUnsupported]);
    expectNoInternalText(tester, also: [mockText, exportFailed]);
    expect(AppErrorReporter.recentErrors.length, greaterThan(recorded));
    await clearSnackBars(tester);

    share.failure = PlatformException(code: 'Share failed', message: mockText);
    await export();
    expect(tester.takeException(), isNull);
    expect(snackBarTexts(tester), [l10n.communityErrorGeneric]);
    expectNoInternalText(tester, also: [mockText, exportFailed]);
    await clearSnackBars(tester);

    share
      ..failure = null
      ..result = '';
    await export();
    expect(find.byType(SnackBar), findsNothing);
    expect(share.calls, 3);

    share.pending = Completer<String>();
    await export();
    await export();
    expect(share.calls, 4, reason: '二度押しで共有を二重に呼ばない');
    share.pending!.complete('');
    share.pending = null;
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);

    // まとめての書き出し：共有シートが開いている間はボタンを押せず、
    // 終わったら選択を解く。
    await tester.longPress(find.text(preset.name));
    await tester.pump(const Duration(milliseconds: 300));
    final bulk = find.widgetWithIcon(IconButton, Icons.ios_share);
    expect(tester.widget<IconButton>(bulk).onPressed, isNotNull);
    share.pending = Completer<String>();
    await tester.tap(bulk);
    await pumpRealAsync(tester, const Duration(milliseconds: 500));
    expect(share.calls, 5);
    expect(
      tester.widget<IconButton>(bulk).onPressed,
      isNull,
      reason: '終わるまで押せない',
    );
    await tester.tap(bulk, warnIfMissed: false);
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(share.calls, 5);
    share.pending!.completeError(
      PlatformException(code: 'Share failed', message: mockText),
    );
    share.pending = null;
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(snackBarTexts(tester), [l10n.communityErrorGeneric]);
    expectNoInternalText(tester, also: [mockText, exportFailed]);
    expect(bulk, findsNothing, reason: '終わったら選択を解く');
  });

  testWidgets('workspace share: a share problem is reported as a share '
      'problem, once, without the exception text', (tester) async {
    final l10n = await pumpHome(tester, const WorkspaceSettingsScreen());
    final presets = tester
        .element(find.byType(WorkspaceSettingsScreen))
        .read<WorkspacePresetService>();
    await tester.runAsync(
      () => presets.save(
        'AUDIT workspace',
        isLeftHanded: false,
        forcePcMode: null,
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final shareFailed = failureLead(l10n.workspaceShareFailedSnackbar);
    expect(shareFailed, isNotEmpty);
    final written = File(
      '${share.directory.path}/AUDIT workspace.niaworkspace',
    );

    Future<void> shareAsFile() async {
      final open = find.text(l10n.workspaceShareButton);
      await tester.scrollUntilVisible(
        open,
        300,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 60,
      );
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(open);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final row = find.widgetWithText(ListTile, 'AUDIT workspace');
      expect(row, findsOneWidget, reason: '共有するものを選ぶ一覧');
      await tester.tap(row, warnIfMissed: false);
      await pumpRealAsync(tester, const Duration(milliseconds: 500));
      // 共有中は選べないので、一覧が残る。閉じておく。
      if (row.evaluate().isNotEmpty) {
        await tester.tapAt(const Offset(2, 2));
        await pumpRealAsync(tester, const Duration(milliseconds: 400));
      }
    }

    final recorded = AppErrorReporter.recentErrors.length;
    share.failure = MissingPluginException(mockText);
    await shareAsFile();
    expect(tester.takeException(), isNull);
    expect(share.calls, 1);
    expect(written.existsSync(), isTrue, reason: '書き出しはできている');
    expect(share.lastPaths, [written.path]);
    expect(snackBarTexts(tester), [l10n.communityErrorUnsupported]);
    expectNoInternalText(tester, also: [mockText, shareFailed]);
    expect(AppErrorReporter.recentErrors.length, greaterThan(recorded));
    await clearSnackBars(tester);

    share.failure = PlatformException(code: 'Share failed', message: mockText);
    await shareAsFile();
    expect(tester.takeException(), isNull);
    expect(snackBarTexts(tester), [l10n.communityErrorGeneric]);
    expectNoInternalText(tester, also: [mockText, shareFailed]);
    await clearSnackBars(tester);

    share
      ..failure = null
      ..result = '';
    await shareAsFile();
    expect(find.byType(SnackBar), findsNothing);
    expect(share.calls, 3);

    share.pending = Completer<String>();
    await shareAsFile();
    await shareAsFile();
    expect(share.calls, 4, reason: '二度押しで共有を二重に呼ばない');
    share.pending!.complete('');
    share.pending = null;
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await shareAsFile();
    expect(share.calls, 5);
  });

  /// ダイアログの中の知らせ：先頭の印＋文、その面の文字色、読み上げへ伝わる。
  void expectInlineNotice(WidgetTester tester, Finder host, String message) {
    final notice = find.descendant(of: host, matching: find.text(message));
    expect(notice, findsOneWidget, reason: 'ダイアログの中に出す（SnackBarは幕の下に隠れる）');
    final line = find.ancestor(
      of: notice,
      matching: find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.liveRegion == true,
      ),
    );
    expect(line, findsWidgets);
    final icon = find.descendant(
      of: line.first,
      matching: find.byIcon(Icons.error_outline),
    );
    expect(icon, findsOneWidget, reason: '色だけで知らせない');
    final scheme = Theme.of(tester.element(notice)).colorScheme;
    final textColor =
        tester.widget<Text>(notice).style?.color ??
        DefaultTextStyle.of(tester.element(notice)).style.color;
    expect(textColor, scheme.onSurface, reason: 'その面の文字色');
    expect(textColor, isNot(scheme.error));
    expect(
      tester.widget<Icon>(icon).color ??
          IconTheme.of(tester.element(icon)).color,
      textColor,
    );
    expect(tester.getSize(notice).height, greaterThan(0));
    expect(notice.hitTestable(), findsOneWidget, reason: '見える所に出ている');
  }

  testWidgets('pixel-art palette dialog: the notice appears inside the dialog '
      'and clears on the next attempt', (tester) async {
    final l10n = await pumpHome(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const PixelArtPalettePickerDialog(),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      size: const Size(450, 900),
      prefs: {
        'pixel_art_palettes': [
          jsonEncode({
            'id': 'PixelPaletteAudit',
            'name': 'AUDIT palette',
            'colors': [0xFF112233, 0xFF445566],
            'isFavorite': false,
          }),
        ],
      },
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    final shareFailed = failureLead(l10n.colorPickerShareFailedSnackbar);
    expect(shareFailed, isNotEmpty);
    final written = File(
      '${share.directory.path}/AUDIT palette.niapixelpalette',
    );
    final shareButton = find.byTooltip(l10n.colorPickerSharePaletteTooltip);

    Future<void> shareAsFile() async {
      await tester.tap(shareButton, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final asFile = find.text(l10n.colorPickerShareViaFile);
      if (asFile.evaluate().isEmpty) return; // 共有中は押せない。
      await tester.tap(asFile);
      await pumpRealAsync(tester, const Duration(milliseconds: 500));
    }

    final recorded = AppErrorReporter.recentErrors.length;
    share.failure = MissingPluginException(mockText);
    await shareAsFile();
    expect(tester.takeException(), isNull);
    expect(share.calls, 1);
    expect(written.existsSync(), isTrue, reason: '書き出しはできている');
    expect(find.byType(SnackBar), findsNothing, reason: 'ダイアログの幕の下に出さない');
    expectInlineNotice(tester, dialog, l10n.communityErrorUnsupported);
    expectNoInternalText(tester, also: [mockText, shareFailed]);
    expect(AppErrorReporter.recentErrors.length, greaterThan(recorded));
    expect(find.text('AUDIT palette'), findsOneWidget, reason: '一覧は残る');

    // 次の共有を始めたら前の知らせは消える。別の失敗はその文で出す。
    share.failure = PlatformException(code: 'Share failed', message: mockText);
    await shareAsFile();
    expect(tester.takeException(), isNull);
    expect(find.text(l10n.communityErrorUnsupported), findsNothing);
    expectInlineNotice(tester, dialog, l10n.communityErrorGeneric);
    expectNoInternalText(tester, also: [mockText, shareFailed]);

    // 共有シートを閉じただけ：知らせは消えたまま、何も出さない。
    share
      ..failure = null
      ..result = '';
    await shareAsFile();
    expect(share.calls, 3);
    expect(find.text(l10n.communityErrorGeneric), findsNothing);
    expect(find.byType(SnackBar), findsNothing);

    // 共有シートが開いている間の二度目は、共有を呼ばない。
    share.pending = Completer<String>();
    await shareAsFile();
    await shareAsFile();
    expect(share.calls, 4, reason: '二度押しで共有を二重に呼ばない');
    // 開いたままでもダイアログは閉じられ、後から来た失敗で落ちない。
    await tester.tap(find.widgetWithText(TextButton, l10n.commonCancel));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
    share.pending!.completeError(PlatformException(code: 'late'));
    share.pending = null;
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expectNoInternalText(tester, also: [mockText, shareFailed]);
  });

  testWidgets('colour picker inside a dialog: the palette share notice appears '
      'inside it', (tester) async {
    final l10n = await pumpHome(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (ctx) => Dialog(
                  insetPadding: const EdgeInsets.all(16),
                  child: ColorPickerPanel(
                    currentColor: const Color(0xFF336699),
                    onColorChanged: (_) {},
                    onClose: () => Navigator.pop(ctx),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      size: const Size(450, 900),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final dialog = find.byType(Dialog);
    expect(dialog, findsOneWidget);
    final shareFailed = failureLead(l10n.colorPickerShareFailedSnackbar);

    Future<void> shareAsFile() async {
      final manage = find.byTooltip(l10n.colorPickerManagePaletteTooltip);
      await tester.ensureVisible(manage);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(manage);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text(l10n.colorPickerSharePaletteTooltip));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      final asFile = find.text(l10n.colorPickerShareViaFile);
      await tester.tap(asFile, warnIfMissed: false);
      await pumpRealAsync(tester, const Duration(milliseconds: 500));
      if (asFile.evaluate().isNotEmpty) {
        await tester.tapAt(const Offset(2, 2));
        await pumpRealAsync(tester, const Duration(milliseconds: 400));
      }
    }

    share.failure = MissingPluginException(mockText);
    await shareAsFile();
    expect(tester.takeException(), isNull);
    expect(share.calls, 1);
    expect(find.byType(SnackBar), findsNothing, reason: 'ダイアログの幕の下に出さない');
    expectInlineNotice(tester, dialog, l10n.communityErrorUnsupported);
    expectNoInternalText(tester, also: [mockText, shareFailed]);

    share
      ..failure = null
      ..result = '';
    await shareAsFile();
    expect(share.calls, 2);
    expect(find.text(l10n.communityErrorUnsupported), findsNothing);

    share.pending = Completer<String>();
    await shareAsFile();
    await shareAsFile();
    expect(share.calls, 3, reason: '二度押しで共有を二重に呼ばない');
    share.pending!.complete('');
    share.pending = null;
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('transfer export: closing the share sheet is not a success, a '
      'share problem is not an export failure, and the file keeps its name', (
    tester,
  ) async {
    final l10n = await pumpHome(tester, const TransferScreen());
    final exportFailed = failureLead(l10n.transferExportFailedSnackbar);
    expect(exportFailed, isNotEmpty);
    final exportButton = find.text(l10n.transferExport);
    expect(exportButton, findsOneWidget);

    Future<void> export({bool wait = true}) async {
      final before = share.calls;
      await tester.tap(exportButton, warnIfMissed: false);
      // 書き出し（設定・ブラシ等をまとめる）と一時ファイルの書き込みを待つ。
      for (var i = 0; i < 100 && share.calls == before; i++) {
        await pumpRealAsync(tester, const Duration(milliseconds: 100));
        if (!wait) break;
      }
      await pumpRealAsync(tester, const Duration(milliseconds: 300));
    }

    // 共有シートを閉じただけ：「書き出しました」と言わない。
    share.result = '';
    await export();
    expect(tester.takeException(), isNull);
    expect(share.calls, 1);
    expect(find.text(l10n.transferExportSuccessSnackbar), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    // 渡すファイルは.niatraの名前のまま（名前を渡さないと別の拡張子になる）。
    final name = share.lastPaths.single.split(Platform.pathSeparator).last;
    expect(name, matches(RegExp(r'^niarim_\d+\.niatra$')));
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // 共有の仕組みが無い端末。
    final recorded = AppErrorReporter.recentErrors.length;
    share.failure = MissingPluginException(mockText);
    await export();
    expect(tester.takeException(), isNull);
    expect(share.calls, 2);
    expect(snackBarTexts(tester), [l10n.communityErrorUnsupported]);
    expectNoInternalText(tester, also: [mockText, exportFailed]);
    expect(find.text(l10n.transferExportSuccessSnackbar), findsNothing);
    expect(AppErrorReporter.recentErrors.length, greaterThan(recorded));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await clearSnackBars(tester);

    // それ以外の失敗。
    share.failure = PlatformException(code: 'Share failed', message: mockText);
    await export();
    expect(tester.takeException(), isNull);
    expect(snackBarTexts(tester), [l10n.communityErrorGeneric]);
    expectNoInternalText(tester, also: [mockText, exportFailed]);
    await clearSnackBars(tester);

    // 渡せた（相手を選んだ）とき、結果が分からない端末のときは知らせる。
    for (final result in [
      'audit.synthetic.status',
      'dev.fluttercommunity.plus/share/unavailable',
    ]) {
      share
        ..failure = null
        ..result = result;
      await export();
      expect(tester.takeException(), isNull);
      expect(snackBarTexts(tester), [
        l10n.transferExportSuccessSnackbar,
      ], reason: result);
      await clearSnackBars(tester);
    }

    // 共有シートが開いている間は押せず、共有は1回だけ。
    final calls = share.calls;
    share.pending = Completer<String>();
    await export();
    expect(share.calls, calls + 1);
    await export(wait: false);
    expect(share.calls, calls + 1, reason: '二度押しで共有を二重に呼ばない');
    share.pending!.complete('');
    share.pending = null;
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await clearSnackBars(tester);

    // ボタンが押せない見た目になる前（同じフレーム）の二度押しでも、
    // 書き出しと共有は1回で、「書き出しました」も1回だけ。
    share.result = 'audit.synthetic.status';
    final callsBeforeDoubleTap = share.calls;
    await tester.tap(exportButton);
    await tester.tap(exportButton, warnIfMissed: false);
    for (var i = 0; i < 100 && share.calls == callsBeforeDoubleTap; i++) {
      await pumpRealAsync(tester, const Duration(milliseconds: 100));
    }
    await pumpRealAsync(tester, const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(share.calls, callsBeforeDoubleTap + 1);
    expect(snackBarTexts(tester), [l10n.transferExportSuccessSnackbar]);
    ScaffoldMessenger.of(
      tester.element(find.byType(Scaffold).first),
    ).hideCurrentSnackBar();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SnackBar), findsNothing, reason: '知らせを2つ積まない');
  });
}
