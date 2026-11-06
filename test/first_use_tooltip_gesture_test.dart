import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/services/first_use_tooltip_service.dart';
import 'package:niarim/widgets/first_use_tooltip.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `FirstUseTooltip`が**ジェスチャーアリーナへ参加しない**ことを見張る。
///
/// 以前は`GestureDetector(behavior: translucent, onTap: ...)`で実装されて
/// いたが、GestureDetectorのタップ認識はアリーナへ参加するため、子または
/// 親のタップ認識と必ずどちらか一方しか勝てない。アリーナは
/// 「ヒットテスト経路の内側から順に追加され、先に入った方が勝つ」ため、
/// 次の二通りの壊れ方をしていた。
///
/// - 子がタップを扱う場合（IconButton・InkWell等）→ 子が勝ち、
///   吹き出しが**一度も表示されない**（lib配下8箇所すべてが該当し、
///   初回説明の機能が丸ごと死んでいた）
/// - 親がタップを扱う場合（TabBarは各タブをInkWellで包むので親側）→
///   吹き出し側が勝ち、**タブが切り替わらない**（ペンサブツールパネルの
///   トーン・スタンプタブがタップで選べなかった）
///
/// 現在はアリーナに参加しない`Listener`でポインターを観測している。
/// この2ケースと「長押し時は出さない」要件を機械的に検証する。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpTooltip(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<FirstUseTooltipService>(
        create: (_) => FirstUseTooltipService(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ja'),
          home: Scaffold(
            body: Center(
              child: FirstUseTooltip(
                tooltipKey: 'test_key',
                message: 'テスト用の説明文',
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('子がタップを扱っていても吹き出しが出る（子のタップも動く）', (tester) async {
    var tapped = 0;
    await pumpTooltip(
      tester,
      IconButton(icon: const Icon(Icons.brush), onPressed: () => tapped++),
    );
    await tester.tap(find.byIcon(Icons.brush));
    await tester.pumpAndSettle();
    expect(tapped, 1, reason: '子のタップが吹き出し側に吸われてはいけない');
    expect(find.text('テスト用の説明文'), findsOneWidget, reason: '吹き出しが表示されていない');
  });

  testWidgets('TabBarのタブを包んでもタブが切り替わる（吹き出しも出る）', (tester) async {
    late TabController controller;
    await tester.pumpWidget(
      ChangeNotifierProvider<FirstUseTooltipService>(
        create: (_) => FirstUseTooltipService(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ja'),
          home: DefaultTabController(
            length: 2,
            child: Builder(
              builder: (context) {
                controller = DefaultTabController.of(context);
                return Scaffold(
                  appBar: AppBar(
                    bottom: TabBar(
                      tabs: [
                        const Tab(text: 'ブラシ'),
                        FirstUseTooltip(
                          tooltipKey: 'test_key',
                          message: 'テスト用の説明文',
                          child: const Tab(text: 'トーン'),
                        ),
                      ],
                    ),
                  ),
                  body: const TabBarView(
                    children: [Text('brush'), Text('tone')],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('トーン'));
    await tester.pumpAndSettle();
    expect(controller.index, 1, reason: 'タブ切り替えが吹き出し側に吸われてはいけない');
    expect(find.text('テスト用の説明文'), findsOneWidget);
  });

  testWidgets('長押しでは吹き出しを出さない（長押しで開く機能を邪魔しない）', (tester) async {
    var longPressed = 0;
    await pumpTooltip(
      tester,
      GestureDetector(
        onLongPress: () => longPressed++,
        child: const SizedBox(width: 80, height: 80, child: Icon(Icons.brush)),
      ),
    );
    await tester.longPress(find.byIcon(Icons.brush));
    await tester.pumpAndSettle();
    expect(longPressed, 1);
    expect(find.text('テスト用の説明文'), findsNothing, reason: '長押しでは出さない約束');
  });

  testWidgets('表示済みのキーでは出さない', (tester) async {
    SharedPreferences.setMockInitialValues({
      'first_use_tooltips_seen': <String>['test_key'],
    });
    final service = FirstUseTooltipService();
    await service.init();
    var tapped = 0;
    await tester.pumpWidget(
      ChangeNotifierProvider<FirstUseTooltipService>.value(
        value: service,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ja'),
          home: Scaffold(
            body: Center(
              child: FirstUseTooltip(
                tooltipKey: 'test_key',
                message: 'テスト用の説明文',
                child: IconButton(
                  icon: const Icon(Icons.brush),
                  onPressed: () => tapped++,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.brush));
    await tester.pumpAndSettle();
    expect(tapped, 1);
    expect(find.text('テスト用の説明文'), findsNothing);
  });
}
