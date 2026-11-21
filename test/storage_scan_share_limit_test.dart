import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/storage_info_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// いつまでも終わらない集計（返らない問い合わせ・止まったマウント）を、
/// 後から来た呼び出しへいつまでも渡し続けない。時間は差し替えた時計で
/// 進めるので、実時間は待たない。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory root;
  late Directory docs;
  late Directory cache;
  late Duration Function() realClock;
  var now = Duration.zero;

  /// nullでなければ、書類の場所の問い合わせはこれが終わるまで返らない。
  Completer<void>? stuck;
  var documentsLookups = 0;

  setUp(() {
    root = Directory.systemTemp.createTempSync('storage-share-limit-');
    docs = Directory('${root.path}/docs')..createSync();
    cache = Directory('${root.path}/cache')..createSync();
    File('${cache.path}/thumb.bin').writeAsBytesSync(List.filled(123, 1));
    stuck = null;
    documentsLookups = 0;
    now = const Duration(minutes: 5);
    realClock = StorageInfoService.scanClock;
    StorageInfoService.scanClock = () => now;
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getApplicationCacheDirectory') return cache.path;
      documentsLookups++;
      await stuck?.future;
      return docs.path;
    });
    StorageInfoService().invalidate();
  });

  tearDown(() {
    StorageInfoService.scanClock = realClock;
    messenger.setMockMethodCallHandler(channel, null);
    root.deleteSync(recursive: true);
  });

  test('返らない集計は、上限を過ぎたら後から来た呼び出しと分け合わない', () async {
    final hang = stuck = Completer<void>();
    final service = StorageInfoService();
    final first = service.computeBreakdown({});

    // 上限までは、これまでどおり走っている1回を分け合う。
    now += storageScanShareLimit - const Duration(seconds: 1);
    expect(service.computeBreakdown({}), same(first));
    expect(documentsLookups, 1);

    // 上限を過ぎたら、新しく走査する。
    now += const Duration(seconds: 1);
    stuck = null;
    final later = service.computeBreakdown({});
    expect(later, isNot(same(first)));
    final result = await later;
    expect(documentsLookups, 2);
    expect(result.bytesOf(StorageCategory.cache), 123);
    expect(service.lastBreakdown, same(result));

    // 止まっていた集計が今ごろ終わっても、覚えている結果は入れ替わらない。
    File('${cache.path}/more.bin').writeAsBytesSync(List.filled(10, 1));
    hang.complete();
    final stale = await first;
    expect(stale.bytesOf(StorageCategory.cache), 133);
    expect(service.lastBreakdown, same(result));

    // 新しい方が終わった後は、次の呼び出しがふつうに走査できる。
    final next = await service.computeBreakdown({});
    expect(next.bytesOf(StorageCategory.cache), 133);
    expect(documentsLookups, 3);
  });

  test('始め直した集計が走っている間に来た呼び出しは、その新しい方を分け合う', () async {
    final hang = stuck = Completer<void>();
    final service = StorageInfoService();
    final first = service.computeBreakdown({});
    now += storageScanShareLimit;
    final second = service.computeBreakdown({});
    expect(second, isNot(same(first)));
    // 2つ目はまだ新しいので、3つ目は2つ目を待つ（走査を増やさない）。
    now += const Duration(seconds: 5);
    expect(service.computeBreakdown({}), same(second));
    expect(documentsLookups, 2);

    hang.complete();
    await Future.wait([first, second]);
  });

  test('始め直しを指定した呼び出しは、上限の前でも走っている集計を待たない', () async {
    final hang = stuck = Completer<void>();
    final service = StorageInfoService();
    final first = service.computeBreakdown({});
    stuck = null;
    final fresh = service.computeBreakdown({}, fresh: true);
    expect(fresh, isNot(same(first)));
    expect((await fresh).bytesOf(StorageCategory.cache), 123);
    expect(documentsLookups, 2);

    hang.complete();
    await first;
  });

  test('時計が戻っても、走っている集計はこれまでどおり分け合う', () async {
    final service = StorageInfoService();
    final first = service.computeBreakdown({});
    now -= const Duration(minutes: 1);
    expect(service.computeBreakdown({}), same(first));
    await first;
    expect(documentsLookups, 1);
  });
}
