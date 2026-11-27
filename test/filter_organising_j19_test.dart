// 描画フィルターの並べ替え・タグ・フォルダ（所有者の判断、2026-11-27、全部入りの
// 作品づくりの判断カードJ19「フィルターの並べ替え・タグ・フォルダ」）。以前は
// フィルターの一覧はおすすめのフィルターが先に並ぶ決まった順で、並べ替えも
// タグもフォルダも無く、お気に入りと名前の検索だけで探した（ブラシ・トーン・
// スタンプにはタグとフォルダがある）。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/niatra_serializer.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/screens/canvas/widgets/filter_panel.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:niarim/utils/transfer_merge.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

void _doNothing() {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the service', () {
    late FilterService service;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      service = FilterService();
      await service.init();
    });

    Future<FilterService> reopened() async {
      // The writes are not awaited by the callers; let them land.
      await Future<void>.delayed(Duration.zero);
      final again = FilterService();
      await again.init();
      return again;
    }

    List<String> ids(FilterService s) => [
      for (final f in s.galleryFilters) f.id,
    ];

    test(
      'a filter moved in the list stays there, and the order comes back',
      () async {
        final before = ids(service);
        expect(service.inUserOrder, isFalse);
        // The recommended built-ins are first until the user moves something.
        expect(before.first, FilterService.signatureFilterIds.first);
        final moved = before.last;
        service.moveInGallery(moved, 0);
        expect(ids(service).first, moved);
        expect(service.inUserOrder, isTrue);
        expect(ids(service).sublist(1), before.sublist(0, before.length - 1));

        final again = await reopened();
        expect(ids(again), ids(service), reason: 'kept after starting again');
        expect(again.inUserOrder, isTrue);

        again.resetGalleryOrder();
        expect(ids(again), before);
        expect(again.inUserOrder, isFalse);
        expect(ids(await reopened()), before);
      },
    );

    test('folders: make, put a filter in, delete keeps the filter', () async {
      final folder = await service.createFolder('Lines');
      service.moveToFolder('Filter0001', folder.id);
      final filter = service.filters.firstWhere((f) => f.id == 'Filter0001');
      expect(filter.folderId, folder.id);

      var again = await reopened();
      expect(again.folders.map((f) => f.name), ['Lines']);
      expect(
        again.filters.firstWhere((f) => f.id == 'Filter0001').folderId,
        folder.id,
      );

      await again.deleteFolder(folder.id);
      expect(again.folders, isEmpty);
      expect(
        again.filters.firstWhere((f) => f.id == 'Filter0001').folderId,
        isNull,
      );
      again = await reopened();
      expect(again.filters.firstWhere((f) => f.id == 'Filter0001'), isNotNull);
    });

    test(
      'tags are kept with the filter, also when its settings change',
      () async {
        service.setTags('Filter0001', ['Soft', ' soft ', 'Glow']);
        expect(service.filters.firstWhere((f) => f.id == 'Filter0001').tags, [
          'Soft',
          'Glow',
        ]);
        service.setTags('Filter0002', ['glow']);
        expect(service.allTags(), ['Glow', 'Soft']);
        service.updateFilterParams('Filter0001', strength: 21);
        final edited = service.filters.firstWhere((f) => f.id == 'Filter0001');
        expect(edited.strength, 21);
        expect(edited.tags, ['Soft', 'Glow']);
        final again = await reopened();
        expect(again.filters.firstWhere((f) => f.id == 'Filter0001').tags, [
          'Soft',
          'Glow',
        ]);
      },
    );

    test('a filter saved before tags and folders reads as it did', () {
      final old = FilterDef.fromJson({
        'id': 'custom_1',
        'name': 'Old',
        'kind': 'gaussianBlur',
        'tags': 'not a list',
        'folderId': 3,
      });
      expect(old.tags, isEmpty);
      expect(old.folderId, isNull);
      final json = const FilterDef(
        id: 'custom_2',
        name: 'New',
        kind: FilterKind.gaussianBlur,
      ).toJson();
      expect(json.containsKey('tags'), isFalse);
      expect(json.containsKey('folderId'), isFalse);
    });

    test(
      'a transfer brings the other device’s folders with its filters',
      () async {
        final l10n = await AppLocalizations.delegate.load(const Locale('ja'));
        final mine = await service.createFolder('Mine');
        service.moveToFolder('Filter0001', mine.id);
        final theirs = const FilterFolder(
          id: 'FilterFolderTheirs',
          name: 'Theirs',
        );
        final copy = const FilterDef(
          id: 'custom_theirs',
          name: 'Their blur',
          kind: FilterKind.gaussianBlur,
          strength: 30,
          folderId: 'FilterFolderTheirs',
          tags: ['night'],
        );
        final lost = const FilterDef(
          id: 'custom_lost',
          name: 'Lost folder',
          kind: FilterKind.gaussianBlur,
          strength: 31,
          folderId: 'FilterFolderGone',
        );
        await service.mergeTransferred(
          [jsonEncode(copy.toJson()), jsonEncode(lost.toJson())],
          copyNames: TransferCopyNames(l10n),
          folders: [jsonEncode(theirs.toJson())],
        );
        expect(service.folders.map((f) => f.id), [mine.id, theirs.id]);
        final added = service.filters.firstWhere(
          (f) => f.id == 'custom_theirs',
        );
        expect(added.folderId, theirs.id);
        expect(added.tags, ['night']);
        expect(
          service.filters.firstWhere((f) => f.id == 'custom_lost').folderId,
          isNull,
          reason: 'its folder did not come along',
        );
        expect(
          service.filters.firstWhere((f) => f.id == 'Filter0001').folderId,
          mine.id,
          reason: 'this device keeps its own folders',
        );
        // The folders travel with the filters; the order stays this device's.
        expect(
          NiatraSerializer.mergedListKeys,
          contains(FilterService.foldersKey),
        );
        expect(
          NiatraSerializer.keptSettingKeys,
          contains('draw_filters_user_order'),
        );
      },
    );
  });

  testWidgets('the list: folders, tags in the search, and dragging the order', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    final dir = Directory.systemTemp.createTempSync('niarim-j19-');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(pathChannel, (_) async => dir.path);
    addTearDown(() {
      messenger.setMockMethodCallHandler(pathChannel, null);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: FilterPanel(
                projectId: '',
                sceneId: '',
                layerId: null,
                frameIndex: 0,
                onClose: _doNothing,
                onCanvasPreviewChanged: (image) => image?.dispose(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(FilterPanel));
    final service = context.read<FilterService>();
    final l10n = AppLocalizations.of(context)!;
    Finder card(String id) => find.byKey(ValueKey('filter-card-$id'));

    // No folder yet: no folder chips.
    expect(find.byKey(const ValueKey('filter-folder-all')), findsNothing);
    final folder = await tester.runAsync(() => service.createFolder('線画'));
    await tester.pump();
    expect(find.byKey(const ValueKey('filter-folder-all')), findsOneWidget);

    // A filter's long-press menu puts it in the folder.
    final first = FilterService.signatureFilterIds.first;
    await tester.longPress(card(first));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filter-action-move')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('線画').last);
    await tester.pumpAndSettle();
    expect(
      service.filters.firstWhere((f) => f.id == first).folderId,
      folder!.id,
    );

    // The folder's chip shows only that filter.
    await tester.tap(find.byKey(ValueKey('filter-folder-${folder.id}')));
    await tester.pumpAndSettle();
    expect(card(first), findsOneWidget);
    expect(card(FilterService.signatureFilterIds[1]), findsNothing);
    await tester.tap(find.byKey(const ValueKey('filter-folder-all')));
    await tester.pumpAndSettle();

    // A tag is found by the search.
    service.setTags('Filter0001', ['やわらか']);
    service.setSearchQuery('やわら');
    await tester.pumpAndSettle();
    expect(card('Filter0001'), findsOneWidget);
    expect(card(first), findsNothing);
    service.setSearchQuery('');
    await tester.pumpAndSettle();

    // Reordering: the rows with handles; dropping one moves it.
    await tester.tap(find.byKey(const ValueKey('filter-reorder')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.filterReorderHint), findsOneWidget);
    expect(find.byKey(const ValueKey('filter-reorder-reset')), findsNothing);
    final list = tester.widget<ReorderableListView>(
      find.byKey(const ValueKey('filter-reorder-list')),
    );
    final second = service.galleryFilters[1].id;
    list.onReorderItem!(1, 0);
    await tester.pumpAndSettle();
    expect(service.galleryFilters.first.id, second);
    expect(find.byKey(const ValueKey('filter-reorder-reset')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('filter-reorder-done')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('filter-tile-grid')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
