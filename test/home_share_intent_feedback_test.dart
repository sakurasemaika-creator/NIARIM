import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/share_intent_service.dart';

import 'helpers/home_clipboard_harness.dart';

void main() {
  testWidgets(
    'cold and warm share intents explain read failures and clean up',
    (tester) async {
      const channel = MethodChannel('com.niarim.niarim/share_intent');
      const uri = 'content://test/transfer.niashare';
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      String? errorCode = 'FILE_TOO_LARGE';
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'getInitialUri':
            return uri;
          case 'readUri':
            expect(call.arguments, {'uri': uri});
            if (errorCode case final code?) throw PlatformException(code: code);
            return Uint8List.fromList([1, 2, 3]);
          default:
            throw MissingPluginException();
        }
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final home = await HomeClipboardHarness.open(tester);
      final l10n = home.l10n;
      final dialog = find.byType(AlertDialog);

      Future<void> receive(String source) async {
        await messenger.handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(MethodCall('onSharedFile', source)),
          null,
        );
      }

      void clearNotice() {
        final context = tester.element(find.byType(HomeScreen));
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
      }

      await home.waitFor(() => home.snackText() == l10n.homeSharedFileTooLarge);
      expect(dialog, findsNothing);

      clearNotice();
      errorCode = 'READ_FAILED';
      await receive(uri);
      await home.waitFor(
        () => home.snackText() == l10n.homeSharedFileUnreadable,
      );
      expect(dialog, findsNothing);

      clearNotice();
      final local = File('${home.dir.path}/oversized.niashare');
      local.openSync(mode: FileMode.write)
        ..truncateSync(maxShareIntentBytes + 1)
        ..closeSync();
      await receive(local.uri.toString());
      await home.waitFor(() => home.snackText() == l10n.homeSharedFileTooLarge);
      expect(dialog, findsNothing);
      expect(local.existsSync(), isTrue);

      clearNotice();
      errorCode = null;
      await receive(uri);
      await home.waitFor(() => dialog.evaluate().isNotEmpty);
      await home.settle();
      expect(find.text(l10n.homeShareFileDialogTitle), findsOneWidget);
      Iterable<Directory> staged() =>
          home.dir.listSync().whereType<Directory>().where(
            (dir) => dir.uri.pathSegments.any(
              (segment) => segment.startsWith('shared-'),
            ),
          );
      expect(staged(), hasLength(1));
      await tester.tap(find.widgetWithText(TextButton, l10n.commonCancel));
      await home.waitFor(() => staged().isEmpty);
      expect(home.projects.shared, isEmpty);
      await home.close();
    },
  );
}
