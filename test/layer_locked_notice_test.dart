import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/widgets/app_toast_messenger.dart';
import 'package:niarim/widgets/layer_locked_notice.dart';

// The notice for a locked layer (drawing on it in the canvas, applying a
// filter to it) is shown again at each press. It used to close whatever
// notice was showing first (hideCurrentSnackBar), so another feature's notice
// and its "Undo" disappeared. Now only the previous locked-layer notice is
// withdrawn.
void main() {
  late BuildContext screen;

  // The messenger checks its notices on a timer, so the frames are pumped
  // for a while instead of waiting for no more frames.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => AppToastMessenger(child: child!),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              screen = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
  }

  testWidgets('another notice stays, and only one locked notice is queued', (
    tester,
  ) async {
    await pump(tester);
    final messenger = ScaffoldMessenger.of(screen);
    messenger.showSnackBar(
      SnackBar(
        content: const Text('other notice'),
        persist: false,
        action: SnackBarAction(label: 'Undo', onPressed: () {}),
      ),
    );
    await settle(tester);
    final locked = AppLocalizations.of(screen)!.canvasLayerLockedNotice;

    showLayerLockedNotice(screen);
    showLayerLockedNotice(screen);
    showLayerLockedNotice(screen);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The other notice is still showing with its action.
    expect(find.text('other notice'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text(locked), findsNothing);

    // When it ends, exactly one locked notice follows (not three).
    messenger.hideCurrentSnackBar();
    await settle(tester);
    expect(find.text(locked), findsOneWidget);
    messenger.hideCurrentSnackBar();
    await settle(tester);
    expect(find.text(locked), findsNothing);
  });
}
