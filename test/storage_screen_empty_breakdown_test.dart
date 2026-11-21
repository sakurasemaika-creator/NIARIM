import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/settings/storage_screen.dart';
import 'package:niarim/services/storage_info_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/app_locale.dart';
import 'package:niarim/widgets/app_scroll_behavior.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'helpers/storage_screen_harness.dart';

/// 全データを削除した後（中身の無い内訳）の容量削減の画面（DISC121）。
///
/// - 「NIARIMの内訳」の欄は棒が1本も無く、文の無い空白になっていた。中身が
///   無いことを文で伝える。
/// - 「端末の容量」の欄は、NIARIMの分が0になると棒が2本になるのに、3本分の
///   高さを取ったままで、下に棒1本分の空白が残っていた。端末の容量は
///   NIARIM・その他・空きの3つで全体なので、0の分も「0B」の棒として出し、
///   いつも3本にする（開いている間は欄を縮めない決まりと両立する）。
/// - 操作の行（「全データを削除」等）は、届いた結果で動かない。文の高さは、
///   操作の後で内訳が空になりうると分かった時点（確かめるダイアログが閉じる
///   間・ホームから戻る間）に取る。以前は空の結果が届いてから取ったので、
///   文字が大きいと文が棒より高く、結果が届いたときに行が12〜92px下へ
///   動いた（レビューで実測）。消し終えるまで時間がかかっても、その間に
///   行は動かない。
/// - キャッシュだけの端末は、開いたときから文の高さを取っている（キャッシュを
///   消しても行は動かない）。
/// - 作品が残るときは空にならないので、文の高さを取らない（取ると、文字の
///   大きいときに残った棒の下が空く）。
StorageBreakdown _emptyBreakdown() => StorageBreakdown({
  for (final category in StorageCategory.values) category: 0,
});

StorageBreakdown _breakdownWith(Map<StorageCategory, int> bytes) =>
    StorageBreakdown({
      for (final category in StorageCategory.values)
        category: bytes[category] ?? 0,
    });

/// 作品のある端末の、ふつうの内訳（棒2本）。
StorageBreakdown _projectAndCache() => _breakdownWith({
  StorageCategory.projectData: 4096,
  StorageCategory.cache: 123,
});

/// 文字が大きく幅の狭いときほど、中身の無い文は棒より高い。
const _layouts = [
  ('ja', 390.0, 1.0),
  ('fr', 320.0, 1.3),
  ('fr', 320.0, 1.5),
  ('ja', 390.0, 2.0),
  ('en', 412.0, 2.0),
  ('es', 320.0, 2.0),
  ('fr', 320.0, 2.0),
  ('ko', 360.0, 2.0),
  ('zh', 320.0, 2.0),
  ('zh_Hant', 320.0, 2.0),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('storage-empty-');
    messenger.setMockMethodCallHandler(pathChannel, (call) async => root.path);
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(pathChannel, null);
    root.deleteSync(recursive: true);
  });

  /// [section]の中に見えている文（高さの見本・見出しは除く）。
  List<String> visibleTexts(WidgetTester tester, Key section, String title) => [
    for (final element
        in find
            .descendant(
              of: find.byKey(section, skipOffstage: false),
              matching: find.byType(Text, skipOffstage: false),
            )
            .evaluate())
      if (Visibility.of(element) &&
          (element.widget as Text).data != title &&
          ((element.widget as Text).data ?? '').trim().isNotEmpty)
        (element.widget as Text).data!,
  ];

  Finder sectionBlock(Key section) => find.descendant(
    of: find.byKey(section, skipOffstage: false),
    matching: find.byType(IndexedStack, skipOffstage: false),
  );

  /// [section]の欄で、取っておいた高さ（IndexedStack）と中身の高さの差
  /// （中身の下に残る空白）。
  double blankBelow(WidgetTester tester, Key section) {
    final block = sectionBlock(section);
    final content = find
        .descendant(
          of: block,
          matching: find.byType(Column, skipOffstage: false),
        )
        .first;
    return tester.getSize(block).height - tester.getSize(content).height;
  }

  /// 内訳の欄に、中身の無い文の高さの見本（または文そのもの）があるか。
  bool emptyTextInBreakdown(WidgetTester tester, AppLocalizations l10n) => find
      .descendant(
        of: sectionBlock(const ValueKey('storageBreakdownSection')),
        matching: find.text(l10n.storageBreakdownEmpty, skipOffstage: false),
      )
      .evaluate()
      .isNotEmpty;

  /// 中身の無い文が見えているか（高さの見本は描かれない）。
  bool emptyTextShown(WidgetTester tester, AppLocalizations l10n) => find
      .text(l10n.storageBreakdownEmpty, skipOffstage: false)
      .evaluate()
      .any(Visibility.of);

  List<String> problems(WidgetTester tester, AppLocalizations l10n) {
    final out = <String>[];
    final breakdownTexts = visibleTexts(
      tester,
      const ValueKey('storageBreakdownSection'),
      l10n.storageBreakdownChartTitle,
    );
    if (breakdownTexts.isEmpty) out.add('NIARIMの内訳の欄に文が無い（空白）');
    final deviceBlank = blankBelow(
      tester,
      const ValueKey('storageDeviceSection'),
    );
    if (deviceBlank > 0.5) {
      out.add('端末の容量の欄の下に${deviceBlank.toStringAsFixed(0)}pxの空白');
    }
    return out;
  }

  /// 操作の行の上端。
  Map<String, double> rows(WidgetTester tester, AppLocalizations l10n) => {
    for (final title in [
      l10n.storageClearCacheButton,
      l10n.storageRemoveUnusedMaterialsButton,
      l10n.storageEmptyTrashButton,
      l10n.storageOrganizeProjectsButton,
      l10n.storageEraseAllButton,
    ])
      title: tester.getTopLeft(storageTile(title)).dy,
  };

  /// [moments]の行の位置がどれも同じでなければ、その食い違いを[failures]へ。
  void sameRows(
    List<String> failures,
    String label,
    Map<String, Map<String, double>> moments,
  ) {
    final names = moments.keys.toList();
    final first = moments[names.first]!;
    for (final name in names.skip(1)) {
      for (final MapEntry(key: row, value: top) in moments[name]!.entries) {
        final was = first[row]!;
        if ((top - was).abs() > 0.5) {
          failures.add(
            '$label: 「$row」が${names.first}→$nameで'
            '${(top - was).toStringAsFixed(0)}px動いた',
          );
        }
      }
    }
  }

  /// 確かめるダイアログで[confirmLabel]を押し、閉じていく間の行の位置
  /// （閉じ始めた直後と閉じ終わった後）を返す。
  Future<List<Map<String, double>>> confirm(
    WidgetTester tester,
    AppLocalizations l10n,
    String confirmLabel,
  ) async {
    await tester.tap(find.widgetWithText(FilledButton, confirmLabel));
    await tester.pump();
    await tester.pump();
    final closing = rows(tester, l10n);
    await tester.pump(const Duration(milliseconds: 400));
    return [closing, rows(tester, l10n)];
  }

  testWidgets('a breakdown that becomes empty while the screen is open says '
      'so, the device section has no blank, and the rows stay put', (
    tester,
  ) async {
    final providers = await bootstrapStorageScreen(tester);
    final service = ScriptedStorage();
    final l10n = await showStorageScreen(
      tester,
      providers,
      service,
      size: const Size(390, 1200),
    );
    service.deviceQueries.single.complete(storageTestDevice);
    service.scans.single.complete(storageBreakdownOf());
    await tester.pump();
    await tester.pump();
    final eraseRow = storageTile(l10n.storageEraseAllButton);
    final eraseTop = tester.getTopLeft(eraseRow).dy;

    // 全データを削除した後は、どの分類も0になる。
    await tester.tap(eraseRow);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await confirm(tester, l10n, l10n.storageEraseAllButton);
    expect(service.erasures, 1);
    service.deviceQueries.last.complete(storageTestDevice);
    service.scans.last.complete(_emptyBreakdown());
    await tester.pump();
    await tester.pump();

    final found = problems(tester, l10n);
    expect(found, isEmpty, reason: found.join('\n'));
    // 開いている間は欄を縮めない：届いた結果で操作の行は動かない。
    expect(tester.getTopLeft(eraseRow).dy, eraseTop);
    expect(tester.takeException(), isNull);
  });

  for (final (language, size) in const [
    ('ja', Size(390, 1200)),
    ('fr', Size(320, 1200)),
    ('zh', Size(320, 1200)),
  ]) {
    testWidgets('$language: opened again after erasing everything, the '
        'breakdown says it is empty and the device section has no blank', (
      tester,
    ) async {
      final providers = await bootstrapStorageScreen(tester);
      final service = ScriptedStorage()
        ..rememberedBreakdown = _emptyBreakdown()
        ..rememberedCategories = const {}
        ..rememberedDevice = storageTestDevice;
      final l10n = await showStorageScreen(
        tester,
        providers,
        service,
        size: size,
        language: language,
      );
      final eraseTop = tester
          .getTopLeft(storageTile(l10n.storageEraseAllButton))
          .dy;
      // 覚えている値で出ている間も、集計し直した結果が届いた後も同じ。
      var found = problems(tester, l10n);
      expect(found, isEmpty, reason: 'remembered: ${found.join('\n')}');
      service.deviceQueries.single.complete(storageTestDevice);
      service.scans.single.complete(_emptyBreakdown());
      await tester.pump();
      await tester.pump();
      found = problems(tester, l10n);
      expect(found, isEmpty, reason: 'scanned: ${found.join('\n')}');
      expect(
        tester.getTopLeft(storageTile(l10n.storageEraseAllButton)).dy,
        eraseTop,
      );
      expect(tester.takeException(), isNull);
    });
  }

  // ── 開いている間の操作で内訳が空になる：届いた結果で行が動かない ──

  testWidgets('erase everything with a remembered 2-bar breakdown: the empty '
      'result does not move the rows (large text, narrow widths)', (
    tester,
  ) async {
    final providers = await bootstrapStorageScreen(tester);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    // 作品のある端末。全データを削除しても、作品の一覧はメモリに古いまま
    // 残る（アプリの再起動を促す）。
    final projects = await storageProjectServiceOf(tester, providers);
    await addStorageTestProject(tester, projects);
    final failures = <String>[];
    for (final (language, width, scale) in _layouts) {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      final service = ScriptedStorage()
        ..rememberedBreakdown = _projectAndCache()
        ..rememberedCategories = const {
          StorageCategory.projectData,
          StorageCategory.cache,
        }
        ..rememberedDevice = storageTestDevice;
      final l10n = await showStorageScreen(
        tester,
        providers,
        service,
        size: Size(width, 1600),
        language: language,
      );
      service.deviceQueries.single.complete(storageTestDevice);
      service.scans.single.complete(_projectAndCache());
      await tester.pump();
      await tester.pump();
      final shown = rows(tester, l10n);

      await tester.tap(storageTile(l10n.storageEraseAllButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // 消し終えるまで時間がかかる（その間にも行を押せる）。
      service.erasing = Completer<void>();
      final [closing, erasing] = await confirm(
        tester,
        l10n,
        l10n.storageEraseAllButton,
      );
      expect(service.scans, hasLength(1), reason: 'まだ消している');
      service.erasing!.complete();
      await tester.pump();
      await tester.pump();
      expect(service.scans, hasLength(2), reason: '消し終えて集計し直す');
      final erased = rows(tester, l10n);
      service.deviceQueries.last.complete(storageTestDevice);
      await tester.pump();
      final deviceAnswered = rows(tester, l10n);
      service.scans.last.complete(_emptyBreakdown());
      await tester.pump();
      await tester.pump();
      final landed = rows(tester, l10n);
      final label = '$language ${width.toInt()} x$scale';
      if (!emptyTextShown(tester, l10n)) {
        failures.add('$label: 中身の無い文が出ていない');
      }
      sameRows(failures, label, {
        'closing': closing,
        'erasing': erasing,
        'erased': erased,
        'deviceAnswered': deviceAnswered,
        'landed': landed,
      });
      final eraseRow = l10n.storageEraseAllButton;
      debugPrint(
        'erase all $label: ${shown[eraseRow]} → closing ${closing[eraseRow]}'
        ' → landed ${landed[eraseRow]}',
      );
      expect(tester.takeException(), isNull, reason: label);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  testWidgets(
    'clear the cache when the breakdown is only the cache: the rows '
    'do not move, neither when confirming nor when the empty result arrives',
    (tester) async {
      final providers = await bootstrapStorageScreen(tester);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final failures = <String>[];
      final cacheOnly = _breakdownWith({StorageCategory.cache: 123456});
      for (final (language, width, scale) in _layouts) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        final service = ScriptedStorage()
          ..rememberedBreakdown = cacheOnly
          ..rememberedCategories = const {StorageCategory.cache}
          ..rememberedDevice = storageTestDevice;
        final l10n = await showStorageScreen(
          tester,
          providers,
          service,
          size: Size(width, 1600),
          language: language,
        );
        service.deviceQueries.single.complete(storageTestDevice);
        service.scans.single.complete(cacheOnly);
        await tester.pump();
        await tester.pump();
        final shown = rows(tester, l10n);

        await tester.tap(storageTile(l10n.storageClearCacheButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        service.clearing = Completer<int>();
        final [closing, clearing] = await confirm(
          tester,
          l10n,
          l10n.commonDelete,
        );
        expect(service.cacheClears, 1);
        service.clearing!.complete(123456);
        await tester.pump();
        await tester.pump();
        final cleared = rows(tester, l10n);
        service.deviceQueries.last.complete(storageTestDevice);
        service.scans.last.complete(_emptyBreakdown());
        await tester.pump();
        await tester.pump();
        final landed = rows(tester, l10n);
        final label = '$language ${width.toInt()} x$scale';
        if (!emptyTextShown(tester, l10n)) {
          failures.add('$label: 中身の無い文が出ていない');
        }
        // キャッシュだけの端末は開いたときから文の高さを取っているので、消すと
        // 決めたときにも行は動かない。
        sameRows(failures, label, {
          'shown': shown,
          'closing': closing,
          'clearing': clearing,
          'cleared': cleared,
          'landed': landed,
        });
        expect(tester.takeException(), isNull, reason: label);
        await tester.pumpWidget(const SizedBox.shrink());
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    },
  );

  /// ホームへの行き来を本物の道順（go_router）で通す。
  Future<(AppLocalizations, GoRouter)> showWithHome(
    WidgetTester tester,
    List<SingleChildWidget> providers,
    StorageInfoService service, {
    required Size size,
    required String language,
  }) async {
    tester.view.physicalSize = size;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => StorageScreen(service: service),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('home')),
        ),
      ],
    );
    await tester.pumpWidget(
      MultiProvider(
        key: UniqueKey(),
        providers: providers,
        child: Builder(
          builder: (context) => MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: context.watch<ThemeService>().themeData,
            scrollBehavior: const AppScrollBehavior(),
            locale: localeFromLanguageCode(language),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pump();
    return (
      AppLocalizations.of(tester.element(find.byType(StorageScreen)))!,
      router,
    );
  }

  for (final (language, width, scale) in const [
    ('fr', 320.0, 1.5),
    ('ja', 390.0, 2.0),
    ('fr', 320.0, 2.0),
    ('ko', 360.0, 2.0),
  ]) {
    testWidgets('$language ${width.toInt()} x$scale: deleting every project '
        'from 「作品を整理する」 and coming back, the empty result does not '
        'move the rows', (tester) async {
      final providers = await bootstrapStorageScreen(tester);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final projects = await storageProjectServiceOf(tester, providers);
      final only = await addStorageTestProject(tester, projects);
      final service = ScriptedStorage()
        ..rememberedCategories = const {
          StorageCategory.projectData,
          StorageCategory.cache,
        };
      final (l10n, router) = await showWithHome(
        tester,
        providers,
        service,
        size: Size(width, 1600),
        language: language,
      );
      addTearDown(router.dispose);
      service.deviceQueries.single.complete(storageTestDevice);
      service.scans.single.complete(_projectAndCache());
      await tester.pump();
      await tester.pump();

      await tester.tap(storageTile(l10n.storageOrganizeProjectsButton));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('home'), findsOneWidget);
      // ホームで、ただ1つの作品をゴミ箱へ移し、ゴミ箱からも消して戻る。
      await tester.runAsync(() async {
        await projects.deleteProject(only);
        await projects.permanentDelete(only);
      });
      expect(projects.projects, isEmpty);
      expect(projects.trash, isEmpty);
      router.pop();
      await tester.pump();
      await tester.pump();
      final returning = rows(tester, l10n);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(service.scans, hasLength(2));
      final returned = rows(tester, l10n);
      service.deviceQueries.last.complete(storageTestDevice);
      service.scans.last.complete(_emptyBreakdown());
      await tester.pump();
      await tester.pump();
      final landed = rows(tester, l10n);
      expect(emptyTextShown(tester, l10n), isTrue);
      final failures = <String>[];
      sameRows(failures, '$language ${width.toInt()} x$scale', {
        'returning': returning,
        'returned': returned,
        'landed': landed,
      });
      expect(failures, isEmpty, reason: failures.join('\n'));
      expect(tester.takeException(), isNull);
    });
  }

  for (final (language, width, scale) in const [
    ('fr', 320.0, 2.0),
    ('ko', 360.0, 2.0),
  ]) {
    testWidgets('$language ${width.toInt()} x$scale: emptying the trash that '
        'held everything, the empty result does not move the rows', (
      tester,
    ) async {
      final providers = await bootstrapStorageScreen(tester);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final projects = await storageProjectServiceOf(tester, providers);
      final trashed = await addStorageTestProject(
        tester,
        projects,
        trashed: true,
      );
      final trashOnly = _breakdownWith({StorageCategory.trash: 8192});
      final service = ScriptedStorage()
        ..rememberedBreakdown = trashOnly
        ..rememberedTrashedIds = {trashed}
        ..rememberedCategories = const {StorageCategory.trash}
        ..rememberedDevice = storageTestDevice;
      final l10n = await showStorageScreen(
        tester,
        providers,
        service,
        size: Size(width, 1600),
        language: language,
      );
      service.deviceQueries.single.complete(storageTestDevice);
      service.scans.single.complete(trashOnly);
      await tester.pump();
      await tester.pump();

      await tester.tap(storageTile(l10n.storageEmptyTrashButton));
      // The Trash's file items are read before the confirmation opens (real
      // file access).
      final confirmButton = find.byKey(const Key('trash-dialog-confirm'));
      for (var i = 0; i < 250 && confirmButton.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 400));
      // The Korean label can be carried by a RichText span for line breaking.
      await tester.tap(find.byKey(const Key('trash-dialog-confirm')));
      // ゴミ箱の作品を本当に消す（ファイルの削除は実時間で進む。重い端末でも
      // 待てるよう、最大5秒）。
      for (var i = 0; i < 250 && service.scans.length < 2; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(service.scans, hasLength(2));
      expect(projects.trash, isEmpty);
      await tester.pump();
      final closing = rows(tester, l10n);
      await tester.pump(const Duration(milliseconds: 400));
      final closed = rows(tester, l10n);
      service.deviceQueries.last.complete(storageTestDevice);
      service.scans.last.complete(_emptyBreakdown());
      await tester.pump();
      await tester.pump();
      final landed = rows(tester, l10n);
      expect(emptyTextShown(tester, l10n), isTrue);
      final failures = <String>[];
      sameRows(failures, '$language ${width.toInt()} x$scale', {
        'closing': closing,
        'closed': closed,
        'landed': landed,
      });
      expect(failures, isEmpty, reason: failures.join('\n'));
      expect(tester.takeException(), isNull);
    });
  }

  // ── 空にならないときは、文の高さを取らない（空白を残さない） ──

  testWidgets('clearing the cache while a project remains does not reserve the '
      'empty text: the project bar is not followed by its blank', (
    tester,
  ) async {
    final providers = await bootstrapStorageScreen(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final projects = await storageProjectServiceOf(tester, providers);
    await addStorageTestProject(tester, projects);
    final service = ScriptedStorage()
      ..rememberedBreakdown = _projectAndCache()
      ..rememberedCategories = const {
        StorageCategory.projectData,
        StorageCategory.cache,
      }
      ..rememberedDevice = storageTestDevice;
    final l10n = await showStorageScreen(
      tester,
      providers,
      service,
      size: const Size(320, 1600),
      language: 'fr',
    );
    service.deviceQueries.single.complete(storageTestDevice);
    service.scans.single.complete(_projectAndCache());
    await tester.pump();
    await tester.pump();
    final before = blankBelow(
      tester,
      const ValueKey('storageBreakdownSection'),
    );

    await tester.tap(storageTile(l10n.storageClearCacheButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await confirm(tester, l10n, l10n.commonDelete);
    service.deviceQueries.last.complete(storageTestDevice);
    service.scans.last.complete(
      _breakdownWith({StorageCategory.projectData: 4096}),
    );
    await tester.pump();
    await tester.pump();
    // 作品が残るので、内訳は空にならない（文の高さを取らない）。取って
    // おいた2本分の高さは開いている間は縮めない（棒1本分だけ空く）。
    expect(emptyTextInBreakdown(tester, l10n), isFalse);
    final after = blankBelow(tester, const ValueKey('storageBreakdownSection'));
    expect(before, lessThan(0.5));
    expect(after, closeTo(42, 0.5));
    expect(tester.takeException(), isNull);
  });
}
