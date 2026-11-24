// タイムラインの「読み上げ」のダイアログ（端末の音声エンジンで文を音声にして
// 音声の素材として足す）を開いて、リポジトリの決まりどおりに動くことの見張り。
//
// - 音声を作れなかったときは、ダイアログを閉じずに中で知らせ、打った文を
//   残す（知らせ〔SnackBar〕はダイアログの幕の下に隠れて見えない）。
// - 打った文の欄のコントローラーは、閉じる動きが終わってから破棄する
//   （showDialogが返った直後に破棄すると、閉じる途中の欄が破棄済みの
//   コントローラーを使う）。
// - メニューの背景だけ暗い自作テーマでも、ダイアログの中の補足の文は
//   メニューの面の文字色で描く（画面の文字色だと暗い下地に暗い字になる）。
// - 狭い画面・大きな文字・仏語でもはみ出さない。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/router.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/icon_notice.dart';
import 'package:niarim/widgets/labeled_slider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/pump_real_async.dart';

const _tts = MethodChannel('com.niarim.niarim/text_to_speech');
const _paths = MethodChannel('plugins.flutter.io/path_provider');

/// メニューの背景だけ暗く、本文の文字も暗い自作テーマ。
const _darkMenu = AppThemePreset(
  id: ThemeService.customCurrentId,
  name: 'Dark menu',
  accentColor: Color(0xFF1E88A8),
  accentTextColor: Color(0xFF0B5F78),
  textColor: Color(0xFF20242A),
  buttonTextColor: Color(0xFFFFFFFF),
  menuTextColor: Color(0xFFEDEFF2),
  selectionTextColor: Color(0xFFFFFFFF),
  panelBgColor: Color(0xFFF4F1EA),
  menuBgColor: Color(0xFF262B33),
  selectionColor: Color(0xFF2F6F5E),
  updateMarkColor: Color(0xFFFFB020),
);

Color? _painted(WidgetTester tester, Finder finder) => tester
    .renderObject<RenderParagraph>(
      find.descendant(of: finder, matching: find.byType(RichText)).first,
    )
    .text
    .style
    ?.color;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  var synthesizeCalls = 0;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('timeline_read_aloud_');
    synthesizeCalls = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_paths, (_) async => temp.path);
    messenger.setMockMethodCallHandler(_tts, (call) async {
      switch (call.method) {
        case 'offlineVoices':
          return [
            {'name': 'voice-ja', 'locale': 'ja-JP', 'quality': 400},
            {'name': 'voice-fr', 'locale': 'fr-FR', 'quality': 400},
            {'name': 'voice-en', 'locale': 'en-US', 'quality': 400},
          ];
        case 'synthesizeToFile':
          synthesizeCalls++;
          // 音声エンジンが音声を作れなかった。
          throw PlatformException(code: 'tts_failed');
        default:
          return null;
      }
    });
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_paths, null);
    messenger.setMockMethodCallHandler(_tts, null);
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  Future<void> openDialog(
    WidgetTester tester, {
    required Locale locale,
    required Size size,
    required double textScale,
    bool darkMenu = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'language': locale.languageCode,
      'force_pc_mode': 0,
    });
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    appRouter.go('/');
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(MaterialApp));
    if (darkMenu) context.read<ThemeService>().previewCurrent(_darkMenu);
    final project = (await tester.runAsync(
      () => context.read<ProjectService>().createProject(
        name: 'Read aloud',
        fps: 12,
        durationSeconds: 2,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 128,
        exportHeight: 128,
      ),
    ))!;
    appRouter.go('/timeline/${project.id}');
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('timelineAddMaterialMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('timelineReadAloudMenuItem')));
    await pumpRealAsync(tester, const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timelineReadAloudTextField')), findsOneWidget);
  }

  for (final (locale, size, scale) in [
    (const Locale('ja'), const Size(360, 800), 1.0),
    (const Locale('fr'), const Size(320, 640), 2.0),
  ]) {
    testWidgets(
      'a failed synthesis keeps the dialog and the text, and says so inside '
      '(${locale.languageCode}, ${size.width.toInt()}px, x$scale)',
      (tester) async {
        await openDialog(tester, locale: locale, size: size, textScale: scale);
        final l10n = lookupAppLocalizations(locale);
        final dialog = find.byType(AlertDialog);
        // 話す速さ・声の高さ・始まりのコマは横幅いっぱいのスライダー。
        expect(
          find.descendant(of: dialog, matching: find.byType(LabeledSlider)),
          findsNWidgets(3),
        );
        // 声の選択欄は、言語の合う声から始まる。
        expect(
          find.descendant(
            of: dialog,
            matching: find.textContaining(
              locale.languageCode == 'ja' ? 'voice-ja' : 'voice-fr',
            ),
          ),
          findsWidgets,
        );

        await tester.enterText(
          find.byKey(const Key('timelineReadAloudTextField')),
          'Bonjour',
        );
        await tester.pump();
        final generate = find.byKey(
          const Key('timelineReadAloudGenerateButton'),
        );
        await tester.ensureVisible(generate);
        await tester.pumpAndSettle();
        await tester.tap(generate);
        await pumpRealAsync(tester, const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(synthesizeCalls, 1);
        // ダイアログは開いたまま、打った文も残っている。
        expect(dialog, findsOneWidget);
        expect(
          tester
              .widget<TextField>(
                find.byKey(const Key('timelineReadAloudTextField')),
              )
              .controller!
              .text,
          'Bonjour',
        );
        // 失敗はダイアログの中に出す（幕の下の知らせにしない）。
        expect(
          find.descendant(
            of: dialog,
            matching: find.widgetWithText(IconNotice, l10n.makingSpeechFailed),
          ),
          findsOneWidget,
        );
        expect(find.byType(SnackBar), findsNothing);
        // もう一度押せる（作っている間の印が残らない）。
        expect(tester.widget<FilledButton>(generate).onPressed, isNotNull);

        // 閉じる動きの途中でも、破棄済みのコントローラーを使わない。
        await tester.tap(find.text(l10n.commonCancel));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpAndSettle();
        expect(dialog, findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('the note inside the dialog uses the menu surface ink', (
    tester,
  ) async {
    await openDialog(
      tester,
      locale: const Locale('ja'),
      size: const Size(390, 844),
      textScale: 1,
      darkMenu: true,
    );
    final l10n = lookupAppLocalizations(const Locale('ja'));
    final dialogTheme = Theme.of(tester.element(find.byType(AlertDialog)));
    final screenTheme = Theme.of(
      tester.element(find.byKey(const Key('timelineAddMaterialMenu'))),
    );
    // 自作テーマでは、ダイアログの中はメニューの面のテーマ（メニューの
    // 文字色）で描かれる。
    expect(
      dialogTheme.colorScheme.onSurface,
      isNot(screenTheme.colorScheme.onSurface),
    );
    final note = find.text(l10n.makingSpeechNotice);
    await tester.ensureVisible(note);
    await tester.pumpAndSettle();
    final painted = _painted(tester, note);
    expect(painted, dialogTheme.colorScheme.onSurfaceVariant);
    expect(painted, isNot(screenTheme.colorScheme.onSurfaceVariant));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
