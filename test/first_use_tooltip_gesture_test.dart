import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets('戻る操作は下の画面ではなく吹き出しを閉じ、表示済みにする', (tester) async {
    await pumpTooltip(
      tester,
      IconButton(icon: const Icon(Icons.brush), onPressed: () {}),
    );
    await tester.tap(find.byIcon(Icons.brush));
    await tester.pumpAndSettle();
    expect(find.text('テスト用の説明文'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('テスト用の説明文'), findsNothing);
    expect(find.byIcon(Icons.brush), findsOneWidget, reason: '画面は残る');
    final service = tester
        .element(find.byType(Scaffold))
        .read<FirstUseTooltipService>();
    expect(service.hasSeen('test_key'), isTrue);
    // 閉じた後の戻る操作は、もう吹き出しの履歴に吸われない。
    final route = ModalRoute.of(tester.element(find.byType(Scaffold)))!;
    expect(route.willHandlePopInternally, isFalse);
  });

  testWidgets('吹き出しを出したまま画面とServiceが破棄されても例外にならない', (tester) async {
    await pumpTooltip(
      tester,
      IconButton(icon: const Icon(Icons.brush), onPressed: () {}),
    );
    await tester.tap(find.byIcon(Icons.brush));
    await tester.pumpAndSettle();
    expect(find.text('テスト用の説明文'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('吹き出しはキーボードのフォーカスを取り、Escで閉じて元へ戻す', (tester) async {
    var undo = 0;
    final screenFocus = FocusNode();
    addTearDown(screenFocus.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<FirstUseTooltipService>(
        create: (_) => FirstUseTooltipService(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ja'),
          home: CallbackShortcuts(
            bindings: {
              const SingleActivator(
                LogicalKeyboardKey.keyZ,
                control: true,
              ): () =>
                  undo++,
            },
            child: Focus(
              focusNode: screenFocus,
              autofocus: true,
              child: Scaffold(
                body: Center(
                  child: FirstUseTooltip(
                    tooltipKey: 'test_key',
                    message: 'テスト用の説明文',
                    child: IconButton(
                      icon: const Icon(Icons.brush),
                      onPressed: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(screenFocus.hasPrimaryFocus, isTrue);
    await tester.tap(find.byIcon(Icons.brush));
    await tester.pumpAndSettle();
    expect(find.text('テスト用の説明文'), findsOneWidget);
    // 吹き出しの間は、背面の画面のショートカットは効かない。
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(undo, 0, reason: '背面の画面の取り消しが動いてはいけない');
    expect(screenFocus.hasFocus, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('テスト用の説明文'), findsNothing);
    expect(screenFocus.hasPrimaryFocus, isTrue, reason: '閉じたら元の画面へ戻す');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(undo, 1);
  });

  testWidgets('同じタップでダイアログが開いても、戻る操作は先に吹き出しを閉じる', (tester) async {
    await pumpTooltip(
      tester,
      Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.brush),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const AlertDialog(content: Text('ダイアログ')),
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.brush));
    await tester.pumpAndSettle();
    expect(find.text('ダイアログ'), findsOneWidget);
    expect(find.text('テスト用の説明文'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('テスト用の説明文'), findsNothing, reason: '上にある吹き出しから');
    expect(find.text('ダイアログ'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('ダイアログ'), findsNothing);
  });

  testWidgets('戻る操作を自分で受ける画面（PopScope）でも吹き出しから閉じる', (tester) async {
    var screenBack = 0;
    await tester.pumpWidget(
      ChangeNotifierProvider<FirstUseTooltipService>(
        create: (_) => FirstUseTooltipService(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ja'),
          home: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) screenBack++;
            },
            child: Scaffold(
              body: Center(
                child: FirstUseTooltip(
                  tooltipKey: 'test_key',
                  message: 'テスト用の説明文',
                  child: IconButton(
                    icon: const Icon(Icons.brush),
                    onPressed: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.brush));
    await tester.pumpAndSettle();
    // 1枚だけの画面でも、吹き出しの間はアプリが戻る操作を受ける
    // （Android 16の予測型「戻る」で、OSへ渡してアプリを閉じない）。
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isTrue);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('テスト用の説明文'), findsNothing);
    expect(screenBack, 0, reason: '画面側の戻る処理は動かない');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(screenBack, 1);
  });

  test('破棄した後のServiceは表示済みの記録を受け付けない（例外にしない）', () async {
    final service = FirstUseTooltipService();
    await service.init();
    service.dispose();
    await service.markSeen('test_key');
    expect(service.hasSeen('test_key'), isFalse);
  });

  testWidgets('押したボタンの画面が作り直されても説明を出し、表示済みにする', (tester) async {
    // タイムラインの全画面表示のボタンのように、押すと画面ごと別の
    // ウィジェットへ作り変わる場合（説明のウィジェットは次のフレームを
    // 待たずに無くなる）。
    final service = FirstUseTooltipService();
    await tester.pumpWidget(
      ChangeNotifierProvider<FirstUseTooltipService>.value(
        value: service,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ja'),
          home: StatefulBuilder(
            builder: (context, setState) {
              var full = false;
              return StatefulBuilder(
                builder: (context, setInner) => full
                    ? const Scaffold(body: Text('全画面'))
                    : Scaffold(
                        body: Center(
                          child: FirstUseTooltip(
                            tooltipKey: 'rebuilt_key',
                            message: '全画面の説明',
                            child: IconButton(
                              icon: const Icon(Icons.fullscreen),
                              onPressed: () => setInner(() => full = true),
                            ),
                          ),
                        ),
                      ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.fullscreen));
    await tester.pumpAndSettle();
    expect(find.text('全画面'), findsOneWidget);
    expect(find.text('全画面の説明'), findsOneWidget);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.text('全画面の説明'), findsNothing);
    expect(service.hasSeen('rebuilt_key'), isTrue);
  });
}
