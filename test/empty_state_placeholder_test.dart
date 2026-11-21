import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/widgets/empty_state_placeholder.dart';

/// 空の表示は、置かれた場所の横幅の中央に出ること。Scaffoldのbodyは幅を
/// 「最大まで」としか渡さないので、幅を取らないと中身の幅に縮んで左に
/// 寄る（ゴミ箱の「ゴミ箱は空です」が左に寄っていた）。
void main() {
  testWidgets('the empty state is centred when it is the Scaffold body', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyStatePlaceholder(
            icon: Icons.delete_outline,
            title: 'ゴミ箱は空です',
          ),
        ),
      ),
    );
    expect(
      tester.getCenter(find.text('ゴミ箱は空です')).dx,
      moreOrLessEquals(195, epsilon: 1),
    );
    expect(
      tester.getCenter(find.byIcon(Icons.delete_outline)).dx,
      moreOrLessEquals(195, epsilon: 1),
    );
  });

  testWidgets(
    'a fitting sliver empty state leaves scrolling to its outer list',
    (tester) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              controller: controller,
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 900,
                    child: const Center(child: Text('preceding content')),
                  ),
                ),
                EmptyStateSliver(
                  builder: (size) => SizedBox(
                    height: size.height,
                    child: const Center(child: Text('empty state')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.text('empty state'), findsOneWidget);
      expect(controller.offset, greaterThan(0));

      // The inner viewport has no overflow. A downward gesture on its content
      // must therefore reach the outer list and reveal the preceding content.
      await tester.drag(find.text('empty state'), const Offset(0, 180));
      await tester.pumpAndSettle();
      expect(
        controller.offset,
        lessThan(900),
        reason: 'the fitting inner scroll view must not trap outer scrolling',
      );
    },
  );
}
