// ホームのカードの星・︙は、カードのダブルタップ（キャンバスを開く）を待たずに
// 離したときに働く。カードの本体のタップ・ダブルタップ・長押しは今までどおり。
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/router.dart';

import 'helpers/home_app_harness.dart';

void main() {
  String topLocation() =>
      appRouter.routerDelegate.currentConfiguration.last.matchedLocation;

  Future<(HomeAppHarness, String)> openHome(WidgetTester tester) async {
    final h = HomeAppHarness.prepare(
      tester,
      preferences: {'home.projectViewMode.v1': 'small'},
    );
    late String id;
    await h.open(
      seed: (s) async {
        for (var i = 0; i < 3; i++) {
          id = (await HomeAppHarness.work(s, '作品$i')).id;
        }
      },
    );
    return (h, id);
  }

  for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    testWidgets('星はすぐ働く（$kind）', (tester) async {
      final (h, id) = await openHome(tester);
      final service = h.service;
      final star = find.byKey(Key('collectionFavorite_$id'));
      expect(star, findsOneWidget);
      expect(service.isFavoriteSaving(id), isFalse);
      await tester.tap(star, kind: kind);
      // ダブルタップを待つ時間（kDoubleTapTimeout）より前に働いている。
      await tester.pump(const Duration(milliseconds: 16));
      expect(service.isFavoriteSaving(id), isTrue);
      for (var i = 0; i < 40 && service.isFavoriteSaving(id); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      await h.settle();
      expect(service.projects.firstWhere((p) => p.id == id).isFavorite, isTrue);
      expect(topLocation(), '/home');
      await h.close();
    });

    testWidgets('︙はすぐメニューを開く（$kind）', (tester) async {
      final (h, id) = await openHome(tester);
      final menu = find.descendant(
        of: find.byKey(Key('collectionMenu_$id')),
        matching: find.byWidgetPredicate((w) => w is PopupMenuButton<String>),
      );
      expect(menu, findsOneWidget);
      await tester.tap(menu, kind: kind);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        find.byWidgetPredicate((w) => w is PopupMenuItem<String>),
        findsWidgets,
      );
      expect(topLocation(), '/home');
      await h.close();
    });
  }

  testWidgets('カードの本体：1回はダブルタップを待ってから作品を開き、2回でキャンバスを開く', (tester) async {
    final (h, id) = await openHome(tester);
    final body = find.text('作品2');
    expect(body, findsOneWidget);

    await tester.tap(body);
    await tester.pump(const Duration(milliseconds: 100));
    expect(topLocation(), '/home', reason: 'まだダブルタップを待っている');
    await tester.pump(kDoubleTapTimeout);
    await tester.pump();
    expect(topLocation(), '/project/$id');
    appRouter.pop();
    await h.settle();
    expect(topLocation(), '/home');

    await tester.tap(body);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(body);
    await tester.pump();
    expect(topLocation(), '/canvas/$id');
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    appRouter.pop();
    await h.settle();
    await h.close();
    await tester.pump(const Duration(seconds: 10));
  });
}
