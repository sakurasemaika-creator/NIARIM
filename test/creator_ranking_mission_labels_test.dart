import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/creator_mission_labels.dart';

void main() {
  testWidgets('ranking card text makes prerequisites explicit in Japanese',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ja'),
      supportedLocales: const [Locale('ja'), Locale('en')],
      home: Builder(builder: (context) {
        final labels = CreatorMissionLabels.of(context);
        return SingleChildScrollView(child: Column(children: [
          Text(labels.format('rankGoal', 10, each: 15)),
          Text(labels.format('rankCommunityWait', 80, each: 100)),
          Text(labels.format('rankBookmarkWait', 4, each: 15)),
          Text(labels.format('rankRankWait', 8, each: 5)),
        ]));
      }),
    ));
    expect(find.textContaining('10位以内＋ブクマ15件'), findsOneWidget);
    expect(find.textContaining('現在80件／必要100件'), findsOneWidget);
    expect(find.textContaining('現在4件／必要15件'), findsOneWidget);
    expect(find.textContaining('現在8位／条件は5位以内'), findsOneWidget);
  });
}
