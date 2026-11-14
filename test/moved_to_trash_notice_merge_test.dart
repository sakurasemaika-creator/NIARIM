import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/widgets/moved_to_trash_snack_bar.dart';

/// ゴミ箱に[ids]の作品が1件ずつ入っているProjectService（ファイルは読み
/// 書きしない）。知らせは、前に移したもののうち、いまもゴミ箱にあるものだけを
/// 数える。
class _TrashHolding extends ProjectService {
  _TrashHolding(this.ids);

  final Set<String> ids;

  @override
  List<Project> get looseTrash => [
    for (final id in ids)
      Project(
        id: id,
        name: id,
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        totalWorkSeconds: 0,
      ),
  ];
}

// 素のScaffoldMessenger（アプリの外・部品だけ）でも、続けてゴミ箱へ移した
// 知らせは1つにまとまり、前の知らせが残り続けない（DISC092の残り）。
// アプリの中（AppToastMessenger）は home_notice_lifetime_test が見る。
void main() {
  Future<(ScaffoldMessengerState, AppLocalizations)> pumpPlain(
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: SizedBox.expand()),
      ),
    );
    final context = tester.element(find.byType(Scaffold));
    return (ScaffoldMessenger.of(context), AppLocalizations.of(context)!);
  }

  List<String?> snackTexts(WidgetTester tester) => [
    for (final element
        in find
            .descendant(of: find.byType(SnackBar), matching: find.byType(Text))
            .evaluate())
      (element.widget as Text).data,
  ];

  testWidgets('a second move while the first notice is shown replaces it '
      'with one notice for both', (tester) async {
    final (messenger, l10n) = await pumpPlain(tester);
    final service = _TrashHolding({'a', 'b'});
    addTearDown(service.dispose);
    showMovedToTrashSnackBar(messenger, l10n, service, ['a']);
    await tester.pump(const Duration(milliseconds: 600));
    expect(snackTexts(tester), contains(l10n.homeMovedToTrashSnackbar(1)));
    showMovedToTrashSnackBar(messenger, l10n, service, ['b']);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(snackTexts(tester), contains(l10n.homeMovedToTrashSnackbar(2)));
    expect(
      snackTexts(tester),
      isNot(contains(l10n.homeMovedToTrashSnackbar(1))),
    );
    // まとめた知らせも時間で消え、前の知らせは後から出てこない。
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        snackTexts(tester),
        isNot(contains(l10n.homeMovedToTrashSnackbar(1))),
      );
    }
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a notice waiting behind another one is withdrawn when it '
      'comes up, and the counts include it', (tester) async {
    final (messenger, l10n) = await pumpPlain(tester);
    final service = _TrashHolding({'a', 'b', 'c'});
    addTearDown(service.dispose);
    messenger.showSnackBar(
      const SnackBar(content: Text('other'), duration: Duration(seconds: 2)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    showMovedToTrashSnackBar(messenger, l10n, service, ['a']);
    showMovedToTrashSnackBar(messenger, l10n, service, ['b', 'c']);
    await tester.pump(const Duration(milliseconds: 300));
    expect(snackTexts(tester), ['other']);
    final seen = <String?>{};
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      seen.addAll(snackTexts(tester));
    }
    expect(seen, contains(l10n.homeMovedToTrashSnackbar(3)));
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // 前の知らせが出ている間に、そこで移した作品がゴミ箱から出た（ゴミ箱の
  // タブから戻した・完全に削除した）ときは、次の知らせはその作品を数えない。
  // 戻してまた移した作品は1回だけ数える。
  testWidgets('works that left the Trash meanwhile are not counted, and a '
      'work moved again is counted once', (tester) async {
    final (messenger, l10n) = await pumpPlain(tester);
    final service = _TrashHolding({'a', 'b'});
    addTearDown(service.dispose);
    showMovedToTrashSnackBar(messenger, l10n, service, ['a', 'b']);
    await tester.pump(const Duration(milliseconds: 600));
    expect(snackTexts(tester), contains(l10n.homeMovedToTrashSnackbar(2)));
    // 「b」はゴミ箱から出て、「a」はゴミ箱から戻した後でまた移した。
    service.ids
      ..remove('b')
      ..add('c');
    showMovedToTrashSnackBar(messenger, l10n, service, ['a', 'c']);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(SnackBar), findsOneWidget);
    expect(snackTexts(tester).first, l10n.homeMovedToTrashSnackbar(2));
    // 前の移動が残らないときは、1回だけ移したときと同じ。
    service.ids
      ..clear()
      ..add('d');
    showMovedToTrashSnackBar(messenger, l10n, service, ['d']);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(SnackBar), findsOneWidget);
    expect(snackTexts(tester).first, l10n.homeMovedToTrashSnackbar(1));
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
