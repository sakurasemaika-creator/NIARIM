import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/community_work.dart';
import 'package:niarim/screens/community/community_work_detail_screen.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/settings_service.dart';

void main() {
  testWidgets('作品詳細にNIARIM制作情報が表示される', (tester) async {
    final service = CommunityService();
    final work = service.works.first;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CommunityService>.value(value: service),
          ChangeNotifierProvider(create: (_) => SettingsService()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CommunityWorkDetailScreen(workId: work.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('${work.projectFrameCount}f'), findsOneWidget);
    expect(find.text('${work.projectFps}fps'), findsOneWidget);
    expect(
      find.text('${work.projectCanvasWidth}×${work.projectCanvasHeight}'),
      findsOneWidget,
    );
    expect(
      find.text(formatProjectWorkTime(work.projectWorkSeconds)),
      findsOneWidget,
    );
  });

  test('横画面の詳細へと縦画面の情報アイコンは同じ作品詳細ルートを使う', () {
    final horizontal = File(
      'lib/screens/community/widgets/community_floating_preview.dart',
    ).readAsStringSync();
    final vertical = File(
      'lib/screens/community/widgets/community_shorts_viewer.dart',
    ).readAsStringSync();

    expect(horizontal, contains("appRouter.push('/community/work/\$workId')"));
    expect(vertical, contains("appRouter.push('/community/work/\${work.id}')"));
    expect(vertical, contains('Icons.info_outline_rounded'));
  });

  test('縦画面の作品情報UIは動画領域の後ろにある別Material領域', () {
    final source = File(
      'lib/screens/community/widgets/community_shorts_viewer.dart',
    ).readAsStringSync();
    final videoMarker = source.indexOf('// 将来のYouTubeプレーヤーはこの矩形だけを置き換える。');
    final outsideMarker = source.indexOf('// 作者・タグ・制作情報・詳細導線はすべて動画領域の外。');
    final infoIcon = source.indexOf('Icons.info_outline_rounded');

    expect(videoMarker, greaterThanOrEqualTo(0));
    expect(outsideMarker, greaterThan(videoMarker));
    expect(infoIcon, greaterThan(outsideMarker));
  });
}
