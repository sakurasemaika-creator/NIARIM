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
}
