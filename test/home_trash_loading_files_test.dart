import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/local_file_trash_service.dart';

import 'helpers/home_clipboard_harness.dart';

/// ゴミ箱のタブで、書き出した作品・作成した共有ファイルの控えを読み込んで
/// いる間は、読めた行（作品）を出したまま、読み込み中の印を出す。以前は印が
/// 行の無いときだけで、4,000件の控えを読む約31秒の間、作品の5行だけを
/// 「全部」のように出し、その後に一度に4,005行へ替わった。読み込みの遅さは
/// [IOOverrides]で控えの置き場所の一覧を止めて作る。印は回らないので、
/// 読み込み中も「落ち着くまで待つ」（pumpAndSettle）が終わる。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 読み込み中の印（ほかに回る印があれば、それも数える）。
  Finder progressIn(Finder scope) => find.descendant(
    of: scope,
    matching: find.byWidgetPredicate(
      (w) => w is ProgressIndicator || w.key == const Key('trashFilesLoading'),
    ),
  );

  testWidgets('Trash shows a loading mark while the file entries load', (
    tester,
  ) async {
    final home = await HomeClipboardHarness.open(
      tester,
      exports: ['clip_slow.gif'],
    );
    final apple = await home.addWork('apple');
    await tester.runAsync(() async {
      await home.projects.deleteProject(apple.id);
      await LocalFileTrashService.move(
        File('${home.dir.path}/exports/clip_slow.gif'),
        LocalTrashKind.exportedWork,
      );
    });
    await home.settleIo(2);

    final gate = Completer<void>();
    final previous = IOOverrides.current;
    IOOverrides.global = _SlowTrashListing(gate.future);
    addTearDown(() => IOOverrides.global = previous);

    await home.showTab(3);
    final trash = find.byType(TrashScreen);
    // 作品の行は出たまま、控えはまだ（読み込み中の印がある）。
    expect(find.descendant(of: trash, matching: find.text('apple')), findsOne);
    expect(find.textContaining('clip_slow'), findsNothing);
    expect(progressIn(trash), findsOneWidget, reason: 'no loading mark');
    // ほかのテストが使う「落ち着くまで待つ」を止めない。
    await tester.pumpAndSettle();
    expect(progressIn(trash), findsOneWidget);
    expect(
      find.text(home.l10n.homeTrashLoadingFiles),
      findsOneWidget,
      reason: 'the mark does not say what is still loading',
    );

    gate.complete();
    await home.waitFor(
      () => find.textContaining('clip_slow').evaluate().isNotEmpty,
      reason: 'the file entry never appeared',
    );
    await home.settle();
    expect(progressIn(trash), findsNothing, reason: 'the mark stayed');
    expect(find.text(home.l10n.homeTrashLoadingFiles), findsNothing);
    expect(find.descendant(of: trash, matching: find.text('apple')), findsOne);
    expect(tester.takeException(), isNull);
    IOOverrides.global = previous;
    await home.close();
  });

  testWidgets('no loading mark when only project kinds are shown', (
    tester,
  ) async {
    final home = await HomeClipboardHarness.open(tester);
    final apple = await home.addWork('apple');
    await tester.runAsync(() => home.projects.deleteProject(apple.id));
    await home.settleIo(2);
    final gate = Completer<void>();
    final previous = IOOverrides.current;
    await home.showTab(3);
    // 書き出した作品・作成した共有ファイルの種類を外す。
    for (final kind in ['createdShare', 'exportedWork']) {
      await tester.tap(find.byKey(ValueKey('trashKind_$kind')));
      await home.settle();
    }
    IOOverrides.global = _SlowTrashListing(gate.future);
    addTearDown(() => IOOverrides.global = previous);
    // 読み込み直す（控えの変化の知らせ）。
    LocalFileTrashService.changes.value++;
    await home.settle();
    final trash = find.byType(TrashScreen);
    expect(find.descendant(of: trash, matching: find.text('apple')), findsOne);
    expect(progressIn(trash), findsNothing);
    gate.complete();
    await home.settleIo(2);
    IOOverrides.global = previous;
    await home.close();
  });
}

/// ゴミ箱の控えの置き場所（niarim/trash/files）の一覧だけを、[gate]まで
/// 止める。ほかのファイル操作はそのまま。
final class _SlowTrashListing extends IOOverrides {
  _SlowTrashListing(this.gate);

  final Future<void> gate;

  @override
  Directory createDirectory(String path) {
    final real = super.createDirectory(path);
    return path.endsWith('/niarim/trash/files')
        ? _GatedDirectory(real, gate)
        : real;
  }
}

class _GatedDirectory implements Directory {
  _GatedDirectory(this._real, this._gate);

  final Directory _real;
  final Future<void> _gate;

  @override
  String get path => _real.path;

  @override
  Uri get uri => _real.uri;

  @override
  Future<bool> exists() => _real.exists();

  @override
  bool existsSync() => _real.existsSync();

  @override
  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) async* {
    await _gate;
    yield* _real.list(recursive: recursive, followLinks: followLinks);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} is not gated');
}
