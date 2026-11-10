import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 共有のネイティブ側の代わり。呼ばれた回数と渡された内容を覚え、
/// 「共有の仕組みが無い」「失敗」「閉じた」「まだ開いている」を再現する
/// （外へは何も送らない）。書類・一時フォルダは作業用のフォルダへ向ける。
class FakeShareChannel {
  static const _share = MethodChannel('dev.fluttercommunity.plus/share');
  static const _paths = MethodChannel('plugins.flutter.io/path_provider');

  /// ネイティブの共有が呼ばれた回数。
  int calls = 0;

  /// 投げる例外（無ければ[result]を返す）。
  Object? failure;

  /// ネイティブが返す値。空文字は「共有シートを閉じた」。
  String result = 'audit.synthetic.status';

  /// 共有シートが開いたままの状態（終わるまで返さない）。
  Completer<String>? pending;

  final requests = <Map<dynamic, dynamic>>[];
  late Directory directory;

  /// 最後の共有で渡されたファイルのパス。
  List<String> get lastPaths => (requests.last['paths'] as List).cast<String>();

  void install() {
    calls = 0;
    failure = null;
    result = 'audit.synthetic.status';
    pending = null;
    requests.clear();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    directory = Directory.systemTemp.createTempSync('niarim_share_sites_');
    messenger.setMockMethodCallHandler(_paths, (_) async => directory.path);
    messenger.setMockMethodCallHandler(_share, (call) async {
      if (call.method != 'share') throw StateError('Unexpected share method');
      calls++;
      requests.add(Map<dynamic, dynamic>.from(call.arguments as Map));
      if (pending != null) return pending!.future;
      if (failure != null) throw failure!;
      return result;
    });
  }

  void remove() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_paths, null);
    messenger.setMockMethodCallHandler(_share, null);
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  }
}

/// 画面に出ている文をすべて集める（SnackBar・ダイアログ・メニューを含む）。
List<String> visibleTexts(WidgetTester tester) => [
  for (final text in tester.widgetList<RichText>(find.byType(RichText)))
    text.text.toPlainText(),
];

/// 利用者に見せてはいけない内部の文（例外の型・OSの文）が出ていないこと。
void expectNoInternalText(
  WidgetTester tester, {
  Iterable<String> also = const [],
  String? reason,
}) {
  final shown = visibleTexts(tester);
  for (final word in [
    'UnimplementedError',
    'UnsupportedError',
    'MissingPluginException',
    'PlatformException',
    ...also,
  ]) {
    if (word.isEmpty) continue;
    expect(
      shown.where((text) => text.contains(word)),
      isEmpty,
      reason: '${reason ?? ''} 「$word」が画面に出ている',
    );
  }
}

/// 「…に失敗しました: {error}」の、例外の文より前の部分。
String failureLead(String Function(String error) message) =>
    message('\u0001').split('\u0001').first.trim();
