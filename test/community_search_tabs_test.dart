import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/community/community_screen.dart';
import 'package:niarim/services/community_preview_service.dart';
import 'package:niarim/services/community_service.dart';

void main() {
  Widget app({String? initialTag}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CommunityService()),
        ChangeNotifierProvider(create: (_) => CommunityPreviewService()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CommunityScreen(initialTagFilter: initialTag),
      ),
    );
  }

  testWidgets('タグチップ遷移ではタグ検索タブと検索語を自動選択する', (tester) async {
    await tester.pumpWidget(app(initialTag: '手描き'));
    await tester.pumpAndSettle();

    final segmented = tester.widget<SegmentedButton<bool>>(
      find.byType(SegmentedButton<bool>),
    );
    expect(segmented.selected, {true});

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, '手描き');
  });

  testWidgets('キーワード/タグ検索を切り替えると古い検索語を持ち越さない', (tester) async {
    await tester.pumpWidget(app(initialTag: '手描き'));
    await tester.pumpAndSettle();

    var segmented = tester.widget<SegmentedButton<bool>>(
      find.byType(SegmentedButton<bool>),
    );
    segmented.onSelectionChanged?.call({false});
    await tester.pump();

    segmented = tester.widget<SegmentedButton<bool>>(
      find.byType(SegmentedButton<bool>),
    );
    expect(segmented.selected, {false});
    expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, '');
  });
}
