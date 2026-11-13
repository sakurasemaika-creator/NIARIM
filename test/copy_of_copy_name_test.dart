import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/screens/canvas/widgets/brush_panel.dart';
import 'package:niarim/screens/canvas/widgets/stamp_panel.dart';
import 'package:niarim/screens/canvas/widgets/tone_panel.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/stamp_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/services/tone_service.dart';
import 'package:niarim/utils/duplicate_name.dart';
import 'package:niarim/utils/transfer_merge.dart';
import 'package:niarim/widgets/preset_stroke_row.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

Project _project(String name) => Project(
  id: name,
  name: name,
  fps: 12,
  durationSeconds: 1,
  backgroundColor: 0xFFFFFFFF,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  totalWorkSeconds: 0,
);

ProjectFolder _folder(String name) => ProjectFolder(id: name, name: name);

/// 複製の複製の名前は、どこで複製しても同じ決まり：付いている複製の印
/// （どの言語の形でも）を1つ外した元の名前に、空いている次の番号を付ける
/// （「Gペン (コピー)」の複製は「Gペン (コピー 2)」。「Gペン (コピー) (コピー)」
/// にしない）。設定の引き継ぎで足す複製と同じ。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String copyIn(AppLocalizations l10n, String name, [int number = 1]) =>
      number == 1
      ? l10n.projectDuplicateName(name)
      : l10n.projectDuplicateNameNumbered(name, number);

  group('one rule for the copy of a copy', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      final tag = locale.toLanguageTag();
      String copy(String name, [int number = 1]) => copyIn(l10n, name, number);

      test('$tag: copying a copy numbers the original name', () {
        const base = 'Gペン';
        expect(
          numberedCopyName(l10n, copy(base), {base, copy(base)}),
          copy(base, 2),
        );
        // 番号の付いた複製の複製は、空いている次の番号。
        expect(
          numberedCopyName(l10n, copy(base, 2), {
            base,
            copy(base),
            copy(base, 2),
          }),
          copy(base, 3),
        );
        // 間の番号が空いていれば、そこを使う。
        expect(
          numberedCopyName(l10n, copy(base, 3), {
            base,
            copy(base),
            copy(base, 3),
          }),
          copy(base, 2),
        );
        // 元を消した後でも、元の名前に番号を付ける。
        expect(numberedCopyName(l10n, copy(base), {copy(base)}), copy(base, 2));
        // 作品・フォルダの複製、引き継ぎで足す複製も同じ名前。
        expect(
          duplicateProjectName(
            l10n,
            copy(base),
            folderId: null,
            projects: [_project(base), _project(copy(base))],
          ),
          copy(base, 2),
        );
        expect(
          duplicateFolderName(
            l10n,
            copy(base),
            parentId: null,
            folders: [_folder(base), _folder(copy(base))],
          ),
          copy(base, 2),
        );
        expect(
          TransferCopyNames(l10n).next(copy(base), {base, copy(base)}),
          numberedCopyName(l10n, copy(base), {base, copy(base)}),
        );
      });

      test('$tag: a copy named in another language is a copy too', () {
        // 表示の言語を変えた後で、前の言語で作った複製を複製する。
        for (final other in AppLocalizations.supportedLocales) {
          final theirs = lookupAppLocalizations(
            other,
          ).projectDuplicateName('Pen');
          expect(
            numberedCopyName(l10n, theirs, {'Pen', theirs}),
            copy('Pen', 2),
            reason: 'from ${other.toLanguageTag()}',
          );
        }
      });

      test('$tag: a name that only looks like a copy mark', () {
        // 印だけの名前（「(コピー)」）には元の名前が無いので、そのまま印を付ける。
        final mark = l10n.projectDuplicateName('').trim();
        expect(numberedCopyName(l10n, mark, {mark}), copy(mark));
        // 以前の版で重なった「Pen (コピー) (コピー)」は、印を1つだけ外す
        // （引き継ぎが同じ物と見なす範囲と同じ）。
        final nested = copy(copy('Pen'));
        expect(
          numberedCopyName(l10n, nested, {'Pen', copy('Pen'), nested}),
          copy(copy('Pen'), 2),
        );
      });

      test('$tag: a number in a copy-shaped name is read as a copy number', () {
        // 「Sketch (copy 2019)」は、利用者が付けた番号か複製で付いた番号かを
        // 名前から見分けられないので、複製の名前として印を外す（元を消した
        // 後の複製と同じ）。複製の番号は元の名前で数え直し、名前の中の
        // 番号は残らない。引き継ぎで足す複製も同じ名前。
        final numbered = copy('Sketch', 2019);
        expect(numberedCopyName(l10n, numbered, {numbered}), copy('Sketch'));
        expect(
          TransferCopyNames(l10n).next(numbered, {numbered}),
          copy('Sketch'),
        );
      });
    }
  });

  group('services that name the copy themselves', () {
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('niarim_copy_of_copy_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, (_) async => tempDir.path);
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null);
      for (var attempt = 0; tempDir.existsSync(); attempt++) {
        try {
          await tempDir.delete(recursive: true);
        } on FileSystemException {
          if (attempt == 19) rethrow;
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      }
    });

    test('a brush copied without a name', () async {
      final s = BrushService();
      await s.init();
      final pen = s.brushes.first;
      String nameOf(String id) => s.brushes.firstWhere((b) => b.id == id).name;
      final copyId = s.duplicateBrush(pen.id)!;
      expect(nameOf(copyId), '${pen.name} (コピー)');
      expect(nameOf(s.duplicateBrush(copyId)!), '${pen.name} (コピー 2)');
    });

    test('tones and stamps copied without a name', () async {
      final tones = ToneService();
      await tones.init();
      final dots = tones.tones.first;
      tones.duplicateTone(dots.id);
      expect(tones.tones.last.name, '${dots.name} (コピー)');
      tones.duplicateTone(tones.tones.last.id);
      expect(tones.tones.last.name, '${dots.name} (コピー 2)');

      final stamps = StampService();
      await stamps.init();
      final star = stamps.stamps.first;
      stamps.duplicateStamp(star.id);
      expect(stamps.stamps.last.name, '${star.name} (コピー)');
      stamps.duplicateStamp(stamps.stamps.last.id);
      expect(stamps.stamps.last.name, '${star.name} (コピー 2)');
    });

    test('works and folders pasted on Home', () async {
      final service = ProjectService();
      await service.init();
      final work = await service.createProject(
        name: '作品',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
      );
      // ホームの貼り付けは名前を渡さない。
      await service.duplicateProject(work.id);
      final copy = service.projects.singleWhere((p) => p.id != work.id);
      expect(copy.name, '作品 (コピー)');
      await service.duplicateProject(copy.id);
      expect(service.projects.map((p) => p.name).toSet(), {
        '作品',
        '作品 (コピー)',
        '作品 (コピー 2)',
      });

      final box = await service.createFolder('箱');
      // ホームはフォルダの名前に「 (コピー)」を付けて渡す。
      final boxCopy = await service.duplicateFolder(
        box.id,
        name: '${box.name} (コピー)',
      );
      expect(boxCopy!.name, '箱 (コピー)');
      final again = await service.duplicateFolder(
        boxCopy.id,
        name: '${boxCopy.name} (コピー)',
      );
      expect(again!.name, '箱 (コピー 2)');
      // 画面の言語で作った名前を渡しても同じ。
      final en = lookupAppLocalizations(const Locale('en'));
      final third = await service.duplicateFolder(
        again.id,
        name: duplicateFolderName(
          en,
          again.name,
          parentId: null,
          folders: service.folders,
        ),
      );
      expect(third!.name, '箱 (copy 3)');
      // 複製の名前でない名前が並びにあれば「名前 (2)」…（フォルダの名前の
      // 決まり）。
      final named = await service.duplicateFolder(box.id, name: '箱');
      expect(named!.name, '箱 (2)');
    });
  });

  group('the copy menu of the brush, tone and stamp lists', () {
    Future<List<SingleChildWidget>> start(WidgetTester tester) async {
      final docs = Directory.systemTemp.createTempSync('niarim_copy_panels_');
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
      // 一覧の見出しの行は狭い幅で入りきらない（仏語は450pxでもはみ出す）ので、
      // 複製の名前だけを見るよう広く取る。
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      return (await tester.runAsync(buildAppProviders))!;
    }

    Future<void> show(
      WidgetTester tester,
      List<SingleChildWidget> providers,
      Locale locale,
      Widget panel,
    ) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: providers,
          child: Builder(
            builder: (themeContext) => MaterialApp(
              theme: themeContext.watch<ThemeService>().themeData,
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: panel),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Future<void> duplicateRow(
      WidgetTester tester,
      Type panel,
      String name,
    ) async {
      await tester.scrollUntilVisible(
        find.text(name),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ReorderableListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final row = find.ancestor(
        of: find.text(name).first,
        matching: find.byType(PresetStrokeRow),
      );
      await tester.ensureVisible(row.first);
      await tester.pump();
      await tester.tap(
        find.descendant(of: row.first, matching: find.byIcon(Icons.more_vert)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final l10n = AppLocalizations.of(tester.element(find.byType(panel)))!;
      await tester.tap(find.text(l10n.themeDuplicateAction).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    /// 7言語それぞれで、元を複製してからその複製を複製する。
    Future<void> copyTwiceInEveryLanguage(
      WidgetTester tester,
      List<SingleChildWidget> providers,
      Widget panel,
      String Function(String tag) addSource,
      Iterable<String> Function() names,
    ) async {
      for (final locale in AppLocalizations.supportedLocales) {
        final tag = locale.toLanguageTag();
        await show(tester, providers, locale, panel);
        final l10n = lookupAppLocalizations(locale);
        final source = addSource(tag);
        await tester.pump();
        String made() =>
            '$tag: ${names().where((n) => n.startsWith(source)).join(' | ')}';
        await duplicateRow(tester, panel.runtimeType, source);
        expect(names(), contains(copyIn(l10n, source)), reason: made());
        await duplicateRow(tester, panel.runtimeType, copyIn(l10n, source));
        expect(names(), contains(copyIn(l10n, source, 2)), reason: made());
        expect(
          names(),
          isNot(contains(copyIn(l10n, copyIn(l10n, source)))),
          reason: made(),
        );
      }
      expect(tester.takeException(), isNull);
    }

    testWidgets('brushes', (tester) async {
      final providers = await start(tester);
      await show(
        tester,
        providers,
        const Locale('ja'),
        BrushPanel(onClose: () {}, embedded: true, embeddedHeight: 1000),
      );
      final brushes = tester
          .element(find.byType(BrushPanel))
          .read<BrushService>();
      final pen = brushes.brushes.first;
      await copyTwiceInEveryLanguage(
        tester,
        providers,
        BrushPanel(onClose: () {}, embedded: true, embeddedHeight: 1000),
        (tag) {
          final id = brushes.duplicateBrush(pen.id, name: 'Base-$tag')!;
          return brushes.brushes.firstWhere((b) => b.id == id).name;
        },
        () => brushes.brushes.map((b) => b.name),
      );
    });

    testWidgets('tones', (tester) async {
      final providers = await start(tester);
      await show(
        tester,
        providers,
        const Locale('ja'),
        TonePanel(onClose: () {}, embedded: true, embeddedHeight: 1000),
      );
      final tones = tester.element(find.byType(TonePanel)).read<ToneService>();
      final dots = tones.tones.first;
      await copyTwiceInEveryLanguage(
        tester,
        providers,
        TonePanel(onClose: () {}, embedded: true, embeddedHeight: 1000),
        (tag) {
          tones.addTone(dots.copyWith(id: 'base_$tag', name: 'Base-$tag'));
          return 'Base-$tag';
        },
        () => tones.tones.map((t) => t.name),
      );
    });

    testWidgets('stamps', (tester) async {
      final providers = await start(tester);
      await show(
        tester,
        providers,
        const Locale('ja'),
        StampPanel(onClose: () {}, embedded: true, embeddedHeight: 1000),
      );
      final stamps = tester
          .element(find.byType(StampPanel))
          .read<StampService>();
      final star = stamps.stamps.first;
      await copyTwiceInEveryLanguage(
        tester,
        providers,
        StampPanel(onClose: () {}, embedded: true, embeddedHeight: 1000),
        (tag) {
          stamps.addStamp(star.copyWith(id: 'base_$tag', name: 'Base-$tag'));
          return 'Base-$tag';
        },
        () => stamps.stamps.map((s) => s.name),
      );
    });
  });
}
