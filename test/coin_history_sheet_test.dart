import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/widgets/coin_history_sheet.dart';

void main() {
  testWidgets('only server data is shown; pagination remains owner-scoped', (
    tester,
  ) async {
    final owner = ValueNotifier<String?>('owner-a');
    final cursors = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        home: Scaffold(
          body: CoinHistorySheet(
            ownerId: 'owner-a',
            accountChanges: owner,
            currentAccountId: () => owner.value,
            fetchPage: ({String? cursor, int limit = 20}) async {
              cursors.add(cursor);
              expect(limit, 20);
              if (cursor == null) {
                return {
                  'entries': [
                    {
                      'source': 'rewarded-ad',
                      'deltaCoins': 10,
                      'occurredAtEpochMs': 1760000000000,
                    },
                  ],
                  'nextCursor': 'server-cursor',
                };
              }
              return {
                'entries': [
                  {
                    'source': 'coin-redemption',
                    'deltaCoins': -55000,
                    'occurredAtEpochMs': 1760001000000,
                  },
                ],
                'nextCursor': null,
              };
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('+10 opals'), findsOneWidget);
    expect(find.text('Rewarded ad'), findsOneWidget);
    await tester.tap(find.byKey(const Key('coinHistoryMoreButton')));
    await tester.pumpAndSettle();
    expect(cursors, [null, 'server-cursor']);
    expect(find.text('-55000 opals'), findsOneWidget);
    expect(find.byKey(const Key('coinHistoryMoreButton')), findsNothing);

    owner.value = 'owner-b';
    await tester.pumpAndSettle();
    expect(find.text('+10 opals'), findsNothing);
    expect(find.text('-55000 opals'), findsNothing);
    owner.dispose();
  });

  testWidgets('does not invent zero or transactions when server fails', (
    tester,
  ) async {
    final owner = ValueNotifier<String?>('account-a');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoinHistorySheet(
            ownerId: 'account-a',
            accountChanges: owner,
            currentAccountId: () => owner.value,
            fetchPage: ({String? cursor, int limit = 20}) async {
              throw StateError('offline');
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Could not load history'), findsOneWidget);
    expect(find.byKey(const Key('coinHistoryAmount')), findsNothing);
    owner.dispose();
  });
}
