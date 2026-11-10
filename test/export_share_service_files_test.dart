import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/services/export_share_service.dart';
import 'package:niarim/widgets/export_share_feedback.dart';

import 'helpers/fake_share_channel.dart';

/// 共有の入口（`ExportShareService`）：複数のファイル・バイト列の共有、
/// 同じものの二重の共有を1つにまとめること、書き出しから共有までを
/// 一度に1つだけ走らせること。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final share = FakeShareChannel();
  setUp(share.install);
  tearDown(share.remove);

  test('several files go out in one native share, in order', () async {
    final files = [
      for (final name in ['a.niafill', 'b.niafill'])
        File('${share.directory.path}/$name')..writeAsStringSync('{}'),
    ];
    final result = await ExportShareService.shareFiles(
      [for (final file in files) XFile(file.path)],
      key: 'audit-several',
      origin: const Rect.fromLTWH(1, 2, 30, 40),
    );
    expect(result.status, ShareResultStatus.success);
    expect(share.calls, 1);
    expect(share.lastPaths, [for (final file in files) file.path]);
    expect(share.requests.single['originX'], 1);
    expect(share.requests.single['originHeight'], 40);
  });

  test('bytes are shared under the given file name', () async {
    Future<String> sharedName({List<String>? overrides}) async {
      await ExportShareService.shareFiles(
        [
          XFile.fromData(
            Uint8List.fromList([1, 2, 3]),
            name: 'niarim_1.niatra',
            mimeType: 'application/octet-stream',
          ),
        ],
        key: 'audit-bytes',
        fileNameOverrides: overrides,
      );
      return share.lastPaths.single.split(Platform.pathSeparator).last;
    }

    // 名前を渡さないと、Web以外ではXFile.fromDataの`name`は使われない
    // （この前提が変わったら、引き継ぎの書き出しの名前の渡し方を見直す）。
    expect(await sharedName(), isNot(endsWith('.niatra')));
    expect(await sharedName(overrides: ['niarim_1.niatra']), 'niarim_1.niatra');
    expect(File(share.lastPaths.single).readAsBytesSync(), [1, 2, 3]);
  });

  test('a second share with the same key joins the open sheet', () async {
    final file = File('${share.directory.path}/a.niabrush')
      ..writeAsStringSync('x');
    final other = File('${share.directory.path}/b.niabrush')
      ..writeAsStringSync('y');
    share.pending = Completer<String>();
    final first = ExportShareService.shareFiles([
      XFile(file.path),
    ], key: 'audit-same');
    final second = ExportShareService.shareFiles([
      XFile(file.path),
    ], key: 'audit-same');
    expect(identical(first, second), isTrue);
    // 書き出したファイル1つの共有（以前からの入口）も、同じ決まりで合流する。
    final byFile = ExportShareService.share(file);
    expect(
      identical(byFile, ExportShareService.share(File(file.path))),
      isTrue,
    );
    // 別のものの共有は別に呼ぶ。
    final third = ExportShareService.shareFiles([
      XFile(other.path),
    ], key: 'audit-other');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(share.calls, 3);
    share.pending!.complete('');
    share.pending = null;
    for (final result in await Future.wait([first, byFile, third])) {
      expect(result.status, ShareResultStatus.dismissed);
    }
    // 終わったら、同じ名前でもう一度共有できる。失敗しても名前は空く。
    share.failure = PlatformException(code: 'Share failed');
    await expectLater(
      ExportShareService.shareFiles([XFile(file.path)], key: 'audit-same'),
      throwsA(isA<PlatformException>()),
    );
    share.failure = null;
    await ExportShareService.shareFiles([XFile(file.path)], key: 'audit-same');
    expect(share.calls, 5);
  });

  test('one write-then-share flow per key at a time', () async {
    final gate = Completer<void>();
    var runs = 0;
    Future<void> flow() async {
      runs++;
      await gate.future;
    }

    expect(ExportShareService.isRunning('audit-flow'), isFalse);
    final first = ExportShareService.runExclusive('audit-flow', flow);
    expect(ExportShareService.isRunning('audit-flow'), isTrue);
    // 走っている間の二度目は何もしない（同じファイルを同時に書かない）。
    expect(await ExportShareService.runExclusive('audit-flow', flow), isFalse);
    expect(runs, 1);
    // 別の名前は止めない。
    expect(
      await ExportShareService.runExclusive('audit-flow-2', () async {}),
      isTrue,
    );
    gate.complete();
    expect(await first, isTrue);
    expect(ExportShareService.isRunning('audit-flow'), isFalse);
    // 途中で例外になっても、次は始められる。
    await expectLater(
      ExportShareService.runExclusive(
        'audit-flow',
        () async => throw StateError('write failed'),
      ),
      throwsStateError,
    );
    expect(ExportShareService.isRunning('audit-flow'), isFalse);
    expect(await ExportShareService.runExclusive('audit-flow', flow), isTrue);
    expect(runs, 2);
  });

  test(
    'listeners hear when a flow starts and ends, also when it fails',
    () async {
      var changes = 0;
      void heard() => changes++;
      ExportShareService.running.addListener(heard);
      addTearDown(() => ExportShareService.running.removeListener(heard));
      final gate = Completer<void>();
      final first = ExportShareService.runExclusive(
        'audit-listen',
        () => gate.future,
      );
      expect(changes, 1, reason: '始まりを知らせる');
      expect(ExportShareService.isRunning('audit-listen'), isTrue);
      // 走っている間の二度目は何も始めないので、知らせもしない。
      expect(
        await ExportShareService.runExclusive('audit-listen', () async {}),
        isFalse,
      );
      expect(changes, 1);
      gate.complete();
      await first;
      expect(changes, 2, reason: '終わりを知らせる');
      expect(ExportShareService.isRunning('audit-listen'), isFalse);
      await expectLater(
        ExportShareService.runExclusive(
          'audit-listen',
          () async => throw StateError('write failed'),
        ),
        throwsStateError,
      );
      expect(changes, 4, reason: '失敗で終わっても知らせる');
    },
  );

  test('the notice names the kind of problem, never the exception', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      for (final error in <Object>[
        // Linuxのshare_plusがファイルの共有で投げる例外。
        UnimplementedError('Sharing files not supported on Linux'),
        UnsupportedError('no share'),
        MissingPluginException('No implementation found for method share'),
      ]) {
        expect(
          exportShareFailureText(l10n, error),
          l10n.communityErrorUnsupported,
          reason: '$locale $error',
        );
      }
      for (final error in <Object>[
        PlatformException(code: 'Share failed', message: 'native text'),
        const FileSystemException('gone', '/private/path'),
        StateError('bad'),
      ]) {
        final text = exportShareFailureText(l10n, error);
        expect(text, l10n.communityErrorGeneric, reason: '$locale $error');
        expect(text, isNot(contains('native text')));
        expect(text, isNot(contains('/private/path')));
      }
      expect(l10n.communityErrorUnsupported, isNotEmpty);
      expect(l10n.communityErrorUnsupported, isNot(l10n.communityErrorGeneric));
    }
  });
}
