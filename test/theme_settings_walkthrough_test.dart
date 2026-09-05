// テーマ一覧を実際に操作して各段階を撮り、意図どおりかを目視監査できるようにする。
//
// 変更の要点は「カードのタップ＝配色の取り込みだけ（チェックは付かない）」
// 「テーマ自体の編集は三点メニューの『編集』から（このときだけチェックが付く）」。
// 挙動は theme_preset_adopt_test.dart が数値で見張っているが、
// 見た目（チェックの有無・カードの強調・SnackBarの文言）はPNGで確認する。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/settings/theme_settings_screen.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/theme-walkthrough');
  setUpAll(() => out.createSync(recursive: true));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('テーマ一覧のタップと三点メニューの編集を実操作して撮る', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadAppFonts(tester);

    final providers = (await tester.runAsync(buildAppProviders))!;
    final rootKey = GlobalKey();

    await tester.pumpWidget(
      RepaintBoundary(
        key: rootKey,
        child: MultiProvider(
          providers: providers,
          child: Builder(
            builder: (themeContext) => MaterialApp(
              theme: themeContext.watch<ThemeService>().themeData,
              locale: const Locale('ja'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const ThemeSettingsScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    var shot = 0;
    Future<void> capture(String name) async {
      await tester.pump(const Duration(milliseconds: 200));
      await tester.runAsync(
        () => _capture(
          rootKey,
          '${out.path}/${shot.toString().padLeft(2, '0')}_$name.png',
        ),
      );
      shot++;
    }

    final context = tester.element(find.byType(ThemeSettingsScreen));
    final service = context.read<ThemeService>();
    final l10n = AppLocalizations.of(context)!;

    // 起動直後は既定テーマが編集対象（＝チェックが1つ付いている）。
    expect(service.isEditingPreset, isTrue);
    expect(find.byIcon(Icons.check), findsOneWidget);
    await capture('theme_list_initial');

    // 別のテーマのカードをタップする＝配色の取り込みだけ。
    final target = service.presets.firstWhere(
      (p) => p.id != service.current.id,
    );
    await tester.ensureVisible(find.text(target.name));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(find.text(target.name));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      service.current.accentColor,
      target.accentColor,
      reason: 'タップした配色が現在の色へ入ること',
    );
    expect(service.isEditingPreset, isFalse, reason: 'タップではテーマの編集対象にならないこと');
    expect(
      find.byIcon(Icons.check),
      findsNothing,
      reason: 'タップではどのテーマにもチェックが付かないこと',
    );
    await capture('after_tap_adopt_colors');

    // 三点メニューを開く（対象テーマの行のもの）。
    final menuButton = find
        .descendant(
          of: find
              .ancestor(of: find.text(target.name), matching: find.byType(Row))
              .first,
          matching: find.byType(PopupMenuButton<String>),
        )
        .first;
    await tester.tap(menuButton);
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.text(l10n.commonEdit),
      findsOneWidget,
      reason: '三点メニューに編集が並ぶこと',
    );
    // 既存の項目が編集の追加で押し出されていないことも確かめる。
    for (final label in [
      l10n.commonRename,
      l10n.themeDuplicateAction,
      l10n.themeExportMenuItem,
      l10n.commonDelete,
    ]) {
      expect(find.text(label), findsOneWidget, reason: '$label が消えている');
    }
    await tester.pump(const Duration(milliseconds: 400));
    await capture('three_dot_menu');

    // 「編集」でこのテーマ自体を編集対象にする＝チェックが付く。
    await tester.tap(find.text(l10n.commonEdit));
    // メニューの退場アニメーションが終わるまで待たずに撮ると、閉じかけの
    // メニューが被ったPNGになりチェックの有無を目視できない。
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.text(l10n.commonRename),
      findsNothing,
      reason: 'メニューが閉じきってから撮ること',
    );
    expect(service.isEditingPreset, isTrue);
    expect(service.current.id, target.id);
    expect(
      find.byIcon(Icons.check),
      findsOneWidget,
      reason: '編集対象にしたテーマにだけチェックが付くこと',
    );
    await capture('after_edit_from_menu');
  });
}

Future<void> _capture(GlobalKey key, String path) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(png!.buffer.asUint8List());
  image.dispose();
}
