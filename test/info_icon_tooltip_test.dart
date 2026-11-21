import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/widgets/info_icon_tooltip.dart';

/// 「i」アイコンの説明の吹き出し：スクリーンリーダーから開ける・戻る操作で
/// 閉じる・文字を大きくした小さな横画面でも画面内に収まる。
void main() {
  const message =
      '線画の色を読み取って、近い色の線ごとに塗り分けます。'
      'しきい値を上げると、少し違う色の線も同じ線として扱います。'
      '線の色が場所によって揺れている絵では、しきい値を上げてから試してください。'
      '細い線が途切れているときは、線の隙間許容も合わせて調整してください。';

  Future<void> pumpIcon(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double textScale = 1,
    Alignment alignment = Alignment.center,
    List<DisplayFeature> displayFeatures = const [],
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ja'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            displayFeatures: displayFeatures,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Align(
            alignment: alignment,
            child: const InfoIconTooltip(message: message),
          ),
        ),
      ),
    );
  }

  testWidgets('screen readers can open it as a button', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpIcon(tester);
    final node = tester.getSemantics(find.byType(InfoIconTooltip));
    expect(
      node,
      matchesSemantics(
        label: '説明を表示',
        hint: message,
        isButton: true,
        hasTapAction: true,
      ),
    );
    tester.semantics.tap(find.semantics.byLabel('説明を表示'));
    await tester.pumpAndSettle();
    expect(find.text(message), findsOneWidget);
    handle.dispose();
  });

  testWidgets('back closes the bubble, not the screen', (tester) async {
    await pumpIcon(tester);
    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();
    expect(find.text(message), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(message), findsNothing);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
  });

  for (final alignment in [
    const Alignment(0, -0.2),
    Alignment.center,
    const Alignment(0, 0.2),
  ]) {
    testWidgets('a long explanation stays on a small landscape screen '
        'at 2x text ($alignment)', (tester) async {
      const size = Size(760, 360);
      await pumpIcon(tester, size: size, textScale: 2, alignment: alignment);
      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();
      final bubble = tester.getRect(
        find
            .ancestor(of: find.text(message), matching: find.byType(Container))
            .first,
      );
      expect(bubble.top, greaterThanOrEqualTo(0));
      expect(bubble.bottom, lessThanOrEqualTo(size.height));
      // 収まらない分は吹き出しの中でスクロールして最後まで読める。
      final scrollable = find.ancestor(
        of: find.text(message),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.maxScrollExtent, greaterThan(0));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('on a half-opened foldable the bubble stays by its icon', (
    tester,
  ) async {
    // 縦のヒンジで画面が左右に分かれた端末。右半分のアイコンの吹き出しは
    // 右半分のアイコンの近くに出る（分けた片側へ置く画面だと左上の基準で
    // 位置がずれ、画面の外へはみ出していた）。
    const size = Size(820, 800);
    await pumpIcon(
      tester,
      size: size,
      alignment: const Alignment(0.6, 0),
      displayFeatures: const [
        DisplayFeature(
          bounds: Rect.fromLTWH(400, 0, 20, 800),
          type: DisplayFeatureType.hinge,
          state: DisplayFeatureState.postureHalfOpened,
        ),
      ],
    );
    final icon = tester.getCenter(find.byIcon(Icons.info_outline));
    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();
    final bubble = tester.getRect(
      find
          .ancestor(of: find.text(message), matching: find.byType(Container))
          .first,
    );
    expect(bubble.left, greaterThanOrEqualTo(0));
    expect(bubble.right, lessThanOrEqualTo(size.width));
    expect((bubble.center.dx - icon.dx).abs(), lessThan(1));
    // 吹き出しを置く画面（Stack）の内側にある＝切り取られずに見える。
    final page = tester.getRect(
      find.ancestor(of: find.text(message), matching: find.byType(Stack)).first,
    );
    expect(page.left, lessThanOrEqualTo(bubble.left));
    expect(page.right, greaterThanOrEqualTo(bubble.right));
    expect(
      bubble.top >= icon.dy || bubble.bottom <= icon.dy,
      isTrue,
      reason: 'the bubble sits above or below its icon',
    );
  });
}
