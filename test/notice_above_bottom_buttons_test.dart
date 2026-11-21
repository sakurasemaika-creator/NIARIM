// 画面の下にボタンの段がある画面で、知らせ（SnackBar）が段にかぶらないこと。
//
// * 設定の引き継ぎ：読み込みの知らせが、段（読み込み・全選択・全解除・
//   書き出し）にかぶる。
// * PCのワークスペースの配置：前の画面（ワークスペースの設定）で出た知らせが
//   付いてきて、段（並び順・配置・幅を戻す）にかぶる。
//
// どちらも段を本文（body）の列の最後に置いていたため、浮かぶ知らせが段の上に
// 重なり、出ている間（最長で約5秒）段のボタンを押せなかった。段を
// `Scaffold.bottomNavigationBar`へ置くと、Scaffoldが知らせを段の上へ浮かべる。
//
// * PCのワークスペースの配置：段の上の配置の見本の右下にある「全体を表示」
//   のボタン（見本を枠に合わせ直す）も、段のすぐ上なので同じ知らせに
//   隠れた（412x860で約4秒）。見本の中ではなく`Scaffold.floatingActionButton`
//   に置くと、Scaffoldが知らせをボタンの上へ浮かべる。
import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/settings/pc_workspace_layout_settings_screen.dart';
import 'package:niarim/screens/settings/widgets/pc_workspace_layout_preview.dart';
import 'package:niarim/screens/settings/transfer_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/pump_real_async.dart';

/// 選ぶと読めないファイルを返すファイル選択（読み込みの失敗の知らせを出す）。
class _PickBroken extends FilePicker {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    @Deprecated('unused') bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => FilePickerResult([
    PlatformFile(
      name: 'broken.niatra',
      size: 4,
      bytes: Uint8List.fromList([1, 2, 3, 4]),
    ),
  ]);
}

/// [labels]のボタンが知らせ（[notice]の面）と重ならず、押せること。
List<String> _coveredButtons(
  WidgetTester tester,
  Finder notice,
  List<String> labels,
) {
  final noticeRect = tester.getRect(
    find.descendant(of: notice, matching: find.byType(Material)).first,
  );
  final problems = <String>[];
  for (final text in labels) {
    final button = find.ancestor(
      of: find.text(text),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );
    final rect = tester.getRect(button.first);
    if (rect.overlaps(noticeRect)) {
      problems.add('「$text」$rect が知らせ $noticeRect と重なる');
    }
    if (button.hitTestable().evaluate().isEmpty) {
      problems.add('「$text」を押せない（知らせの下）');
    }
  }
  // 知らせは画面の中に出る（段の上へ浮かべて画面の外へ押し出さない）。
  if (noticeRect.top <= 0) problems.add('知らせ $noticeRect が画面の外');
  return problems;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  late Directory temp;
  FilePicker? previousPicker;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('transfer_notice_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, (_) async => temp.path);
    try {
      previousPicker = FilePicker.platform;
    } catch (_) {
      previousPicker = null;
    }
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, null);
    if (previousPicker != null) FilePicker.platform = previousPicker!;
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  for (final (label, size, pc, scale) in const [
    ('phone 360x760', Size(360, 760), false, 1.0),
    ('phone 360x760 text x2', Size(360, 760), false, 2.0),
    ('PC 1280x800', Size(1280, 800), true, 1.0),
  ]) {
    testWidgets('$label: the import notice floats above the button row and '
        'every button stays tappable', (tester) async {
      SharedPreferences.setMockInitialValues({
        'language': 'ja',
        'first_launch': false,
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
        'force_pc_mode': pc ? 1 : 0,
      });
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final providers = (await tester.runAsync(buildAppProviders))!;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: MultiProvider(providers: providers, child: const NiarimApp()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      appRouter.go('/settings/transfer');
      await tester.pumpAndSettle();
      final screen = tester.element(find.byType(TransferScreen));
      final l10n = AppLocalizations.of(screen)!;
      FilePicker.platform = _PickBroken();

      await tester.tap(find.text(l10n.transferImport));
      final notice = find.byType(SnackBar);
      for (var i = 0; i < 50 && notice.evaluate().isEmpty; i++) {
        await pumpRealAsync(tester, const Duration(milliseconds: 100));
      }
      expect(notice, findsOneWidget, reason: '読み込みの失敗の知らせが出る');
      // 出切るまで（250ms）進める。
      await tester.pump(const Duration(milliseconds: 300));
      final problems = _coveredButtons(tester, notice, [
        l10n.transferImport,
        l10n.homeSelectionAllSelect,
        l10n.homeSelectionAllDeselect,
        l10n.transferExport,
      ]);
      expect(problems, isEmpty, reason: problems.join('\n'));

      // 出ている間に「全解除」を押せば、項目のチェックが外れる。
      await tester.tap(find.text(l10n.homeSelectionAllDeselect));
      await tester.pump();
      final checked = tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .where((t) => t.value == true);
      expect(checked, isEmpty, reason: '知らせが出ている間も「全解除」が効く');
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });
  }
  for (final (label, size, pc, scale) in const [
    ('phone 360x760', Size(360, 760), false, 1.0),
    ('phone 360x760 text x2', Size(360, 760), false, 2.0),
    ('PC 1280x800', Size(1280, 800), true, 1.0),
  ]) {
    testWidgets('$label: a notice carried over from the workspace settings '
        'floats above the PC layout screen\'s reset buttons', (tester) async {
      SharedPreferences.setMockInitialValues({
        'language': 'ja',
        'first_launch': false,
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
        'force_pc_mode': pc ? 1 : 0,
      });
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final providers = (await tester.runAsync(buildAppProviders))!;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: MultiProvider(providers: providers, child: const NiarimApp()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      appRouter.go('/settings/workspace');
      await tester.pumpAndSettle();
      unawaited(
        appRouter.routerDelegate.navigatorKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const PcWorkspaceLayoutSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final screen = tester.element(
        find.byType(PcWorkspaceLayoutSettingsScreen),
      );
      final l10n = AppLocalizations.of(screen)!;
      // ワークスペースの設定で出た知らせ（「適用しました」等）が付いてくる。
      ScaffoldMessenger.of(
        screen,
      ).showSnackBar(SnackBar(content: Text(l10n.workspaceAppliedSnackbar)));
      final notice = find.byType(SnackBar);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(notice, findsOneWidget);
      final problems = _coveredButtons(tester, notice, [
        l10n.pcWorkspaceLayoutResetOrderButton,
        l10n.pcLayoutResetWorkspace,
        l10n.pcWorkspaceLayoutResetWidthButton,
      ]);
      expect(problems, isEmpty, reason: problems.join('\n'));
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });
  }

  for (final (label, size, pc, scale) in const [
    ('phone 412x860', Size(412, 860), false, 1.0),
    ('phone 360x760 text x2', Size(360, 760), false, 2.0),
    ('PC 1280x800', Size(1280, 800), true, 1.0),
  ]) {
    testWidgets('$label: the preview\'s fit button stays above a notice '
        'carried over from the workspace settings and still fits the '
        'preview', (tester) async {
      SharedPreferences.setMockInitialValues({
        'language': 'ja',
        'first_launch': false,
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
        'force_pc_mode': pc ? 1 : 0,
      });
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final providers = (await tester.runAsync(buildAppProviders))!;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: MultiProvider(providers: providers, child: const NiarimApp()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      appRouter.go('/settings/workspace');
      await tester.pumpAndSettle();
      unawaited(
        appRouter.routerDelegate.navigatorKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const PcWorkspaceLayoutSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final screen = tester.element(
        find.byType(PcWorkspaceLayoutSettingsScreen),
      );
      final l10n = AppLocalizations.of(screen)!;
      final viewer = find.byKey(const Key('pcWorkspaceInteractivePreview'));
      final controller = tester
          .widget<InteractiveViewer>(viewer)
          .transformationController!;
      final fitted = controller.value.clone();

      // 見本を動かしてから、付いてきた知らせが出ている間に「全体を表示」を押す。
      await tester.drag(viewer, const Offset(-60, -40));
      await tester.pumpAndSettle();
      expect(controller.value, isNot(equals(fitted)));
      ScaffoldMessenger.of(
        screen,
      ).showSnackBar(SnackBar(content: Text(l10n.workspaceAppliedSnackbar)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final notice = find.byType(SnackBar);
      expect(notice, findsOneWidget);
      final noticeRect = tester.getRect(
        find.descendant(of: notice, matching: find.byType(Material)).first,
      );
      final fit = find.byKey(const Key('pcWorkspaceFitPreview'));
      expect(fit, findsOneWidget);
      final fitRect = tester.getRect(fit);
      expect(
        fitRect.overlaps(noticeRect),
        isFalse,
        reason: '「全体を表示」$fitRect が知らせ $noticeRect と重なる',
      );
      expect(fit.hitTestable(), findsOneWidget, reason: '知らせの下で押せない');
      // ボタンは見本の右下の角の上（見本の外へは置かない）。
      final previewRect = tester.getRect(find.byType(PcWorkspaceLayoutPreview));
      expect(
        previewRect.contains(fitRect.topLeft) &&
            previewRect.contains(fitRect.bottomRight - const Offset(1, 1)),
        isTrue,
        reason: '「全体を表示」$fitRect が見本 $previewRect の外',
      );
      expect(
        fitRect.center.dx > previewRect.center.dx &&
            fitRect.center.dy > previewRect.center.dy,
        isTrue,
        reason: '「全体を表示」$fitRect が見本の右下にない',
      );
      // 名前は「全体を表示」（以前は画面の名前「PCレイアウト設定」だった）。
      expect(tester.widget<IconButton>(fit).tooltip, l10n.pcViewFit);

      await tester.tap(fit);
      await tester.pump();
      expect(controller.value, equals(fitted), reason: '押しても見本が合わない');
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });
  }
}
