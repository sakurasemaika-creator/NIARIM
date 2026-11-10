import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/creator_mission_labels.dart';

void main() {
  testWidgets('ranking card text makes prerequisites explicit in Japanese',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ja'),
      supportedLocales: const [Locale('ja'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(builder: (context) {
        final labels = CreatorMissionLabels.of(context);
        return SingleChildScrollView(child: Column(children: [
          Text(labels.format('rank', 10)),
          Text(labels.get('rankOne')),
          Text(labels.get('detailsCreatorBookmarkRule')),
          Text(labels.get('detailsCreatorWorksRule')),
          Text(labels.get('detailsCreatorFollowerRule')),
          Text(labels.get('detailsCreatorTimeRule')),
          Text(labels.get('detailsCreatorClaimRule')),
          Text(labels.format('rankDetailsRules', 5, each: 10)),
          Text(labels.get('rankDetailsHold')),
          Text(labels.format('rankCommunityWait', 80, each: 100)),
          Text(labels.format('rankBookmarkWait', 4, each: 15)),
          Text(labels.format('rankRankWait', 8, each: 5)),
        ]));
      }),
    ));
    expect(
      find.text('ブックマークランキング10位以内'),
      findsOneWidget,
    );

    expect(
      find.text('ブックマークランキング1位'),
      findsOneWidget,
    );
    expect(find.textContaining('小数点以下切り捨て'), findsOneWidget);
    expect(find.textContaining('作品ごとに別途'), findsNothing);
    expect(find.textContaining('作品ごとに判定'), findsOneWidget);
    expect(find.textContaining('現在コイン報酬'), findsNothing);
    expect(find.textContaining('48時間経過後'), findsOneWidget);
    expect(find.textContaining('同じ作品の同じ順位報酬は1回限り'), findsOneWidget);
    expect(find.textContaining('現在80件／必要100件'), findsOneWidget);
    expect(find.textContaining('現在4件／必要15件'), findsOneWidget);
    expect(find.textContaining('現在8位／条件は5位以内'), findsOneWidget);
  });
}
