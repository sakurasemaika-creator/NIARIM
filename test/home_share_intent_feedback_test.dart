import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/archive_security.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/share_intent_service.dart';
import 'package:niarim/utils/file_size_label.dart';

import 'helpers/home_clipboard_harness.dart';

void main() {
  testWidgets(
    'cold and warm share intents explain read failures and clean up',
    (tester) async {
      // Files open up to what a received work may be on this device.
      ArchiveSecurity.debugReceivedWorkBudget = 1024 * 1024 * 1024;
      addTearDown(() => ArchiveSecurity.debugReceivedWorkBudget = null);
      const channel = MethodChannel('com.niarim.niarim/share_intent');
      const uri = 'content://test/transfer.niashare';
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      String? errorCode = 'FILE_TOO_LARGE';
      var sharedBytes = Uint8List.fromList([1, 2, 3]);
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'getInitialUri':
            return uri;
          case 'copyUri':
            final args = call.arguments as Map;
            expect(args['uri'], uri);
            expect(args['maxBytes'], maxShareIntentBytes());
            if (errorCode case final code?) {
              throw PlatformException(code: code, details: 3 << 20);
            }
            // The platform side copies the file into the given path.
            File(args['path'] as String).writeAsBytesSync(sharedBytes);
            return sharedBytes.length;
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

      final tooLarge = l10n.homeSharedFileTooLarge(
        fileSizeLabel(l10n, maxShareIntentBytes()),
      );
      await home.waitFor(() => home.snackText() == tooLarge);
      expect(tooLarge, '共有ファイルが大きすぎるため開けません。この端末で開けるのは1.0GB以下のファイルです。');
      expect(dialog, findsNothing);

      clearNotice();
      errorCode = 'NO_SPACE';
      await receive(uri);
      await home.waitFor(
        () =>
            home.snackText() ==
            l10n.homeSharedFileNoSpace(fileSizeLabel(l10n, 3 << 20)),
      );
      expect(
        home.snackText(),
        '端末の空き容量が足りないため、共有ファイルを開けません。空き容量をあと3.0MB以上増やしてから、もう一度開いてください。',
      );
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
        ..truncateSync(maxShareIntentBytes() + 1)
        ..closeSync();
      await receive(local.uri.toString());
      await home.waitFor(() => home.snackText() == tooLarge);
      expect(dialog, findsNothing);
      expect(local.existsSync(), isTrue);

      clearNotice();
      errorCode = null;
      // Copies of opened files wait in the cache's intake folder.
      final intake = Directory(
        '${home.dir.path}/${ShareIntentService.intakeFolderName}',
      );
      Iterable<File> staged() => intake.existsSync()
          ? intake.listSync().whereType<File>()
          : const <File>[];
      await receive(uri);
      await home.waitFor(
        () => home.snackText() == l10n.homeSharedFileUnreadable,
      );
      expect(dialog, findsNothing);
      await home.waitFor(() => staged().isEmpty);

      clearNotice();
      final project = await home.addWork('Share source');
      sharedBytes = (await tester.runAsync(() async {
        final archive = await home.projects.createOutgoingShare(
          project: project,
        );
        return archive.readAsBytes();
      }))!;
      await receive(uri);
      await home.waitFor(() => dialog.evaluate().isNotEmpty);
      await home.settle();
      expect(find.text(l10n.homeShareFileDialogTitle), findsOneWidget);
      expect(staged(), hasLength(1));
      await tester.tap(find.widgetWithText(TextButton, l10n.commonCancel));
      await home.waitFor(() => staged().isEmpty);
      await home.settle();
      expect(home.projects.shared, isEmpty);

      await receive(uri);
      final save = find.widgetWithText(FilledButton, l10n.commonSave);
      await home.waitFor(() => save.hitTestable().evaluate().isNotEmpty);
      await home.settle();
      await tester.tap(save);
      await home.waitFor(
        () => home.projects.shared.length == 1 && staged().isEmpty,
      );
      await home.close();
    },
  );
}
