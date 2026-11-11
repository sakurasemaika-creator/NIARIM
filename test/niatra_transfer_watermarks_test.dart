import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niatra_serializer.dart';
import 'package:niarim/models/watermark_asset.dart';
import 'package:niarim/services/watermark_service.dart';
import 'package:niarim/utils/transfer_merge.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/niatra_transfer_device.dart';

/// 引き継ぎ（.niatra）の端末保存データで、利用者が登録した透かし（文字・
/// 画像）が移ること。この端末の透かしは書き換えず、同じファイルを読み直して
/// も、起動し直しても、もう1台へ戻しても増えない。画像の透かしは画像ごと
/// 移す（画像の無い透かしは使えないので足さない）。

/// 今の保存（1台の端末の中身）。
Future<Map<String, Object>> _snapshot() async {
  final prefs = await SharedPreferences.getInstance();
  return {for (final key in prefs.getKeys()) key: prefs.get(key)!};
}

/// 見つけた食い違いを最後にまとめて報告する。
class _Problems {
  final _found = <String>[];

  void check(Object? actual, Object? matcher, String reason) {
    try {
      expect(actual, matcher, reason: reason);
    } on TestFailure catch (e) {
      _found.add('$e'.trim());
    }
  }

  void verify() {
    if (_found.isEmpty) return;
    fail('${_found.length} problem(s):\n\n${_found.join('\n\n')}');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  late Directory temp;
  late Directory storage;
  var imports = 0;
  Directory nextDir() =>
      Directory('${temp.path}/import${imports++}')..createSync();

  setUp(() {
    temp = Directory.systemTemp.createTempSync('niatra_watermarks_');
    storage = temp;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, (_) async => storage.path);
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, null);
    await settleTransfer();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  /// [who]の端末の書類フォルダへ切り替え、[saved]の保存で起動し直す。
  void useDevice(String who, Map<String, Object> saved) {
    storage = Directory('${temp.path}/$who')..createSync(recursive: true);
    SharedPreferences.setMockInitialValues(saved);
  }

  /// 起動し直したときの透かしの一覧（ID・名前・種類・文字・色・影・縁取り・
  /// 画像の中身）。
  Future<List<String>> marks() async {
    final service = WatermarkService();
    await service.init();
    return [
      for (final m in service.assets)
        '${m.name}|${m.type.name}|${m.text}|${m.textColor}|'
            '${m.shadowEnabled}|${m.outlineEnabled}|${m.outlineWidth}|'
            '${await _picture(service, m)}',
    ];
  }

  /// 透かしの画像のファイルの数（読み直しでファイルを増やさない）。
  int pictureFiles() {
    final dir = Directory('${storage.path}/niarim/watermarks');
    return dir.existsSync() ? dir.listSync().length : 0;
  }

  test('text and image watermarks registered on the other device arrive '
      'with their settings and picture, this device keeps its own, and '
      'reading the file again, restarting or taking them back changes '
      'nothing', () async {
    useDevice('A', {'language': 'ja'});
    final aMarks = WatermarkService();
    await aMarks.init();
    await aMarks.addTextWatermark(
      '@my_account',
      color: 0xFFFF0000,
      shadowEnabled: true,
      outlineEnabled: true,
      outlineWidth: 5,
    );
    final logo = File('${temp.path}/logo.png')
      ..writeAsBytesSync([1, 2, 3, 4, 5, 6]);
    await aMarks.addWatermark(logo.path);
    await settleTransfer();
    final aMarksBefore = await marks();
    final a = await TransferDevice.start();
    final bytes = await a.export();
    final savedA = await _snapshot();

    // 別のミリ秒で登録する（IDは時刻から付く）。
    await Future<void>.delayed(const Duration(milliseconds: 3));
    useDevice('B', {'language': 'ja'});
    final bMarks = WatermarkService();
    await bMarks.init();
    await bMarks.addTextWatermark('B mark', color: 0xFF00FF00);
    await settleTransfer();
    final b = await TransferDevice.start();
    final report = TransferImportReport();
    await b.import(bytes, nextDir(), report: report);

    final p = _Problems();
    const expected = [
      'B mark|text|B mark|4278255360|false|false|3.0|-',
      '@my_account|text|@my_account|4294901760|true|true|5.0|-',
      'logo|image|null|null|false|false|3.0|1,2,3,4,5,6',
    ];
    p.check(await marks(), expected, '文字・画像の透かしが届き、この端末の透かしも残る');
    p.check(report.addedCopies, isEmpty, '知らせる複製は無い');
    final saved = await _snapshot();
    final files = pictureFiles();
    await b.import(bytes, nextDir());
    p.check(
      (await _snapshot())['watermark_assets'],
      saved['watermark_assets'],
      '読み直しても変わらない',
    );
    p.check(pictureFiles(), files, '読み直しても画像のファイルは増えない');
    final back = await b.export();

    useDevice('A', savedA);
    final aAgain = await TransferDevice.start();
    final backReport = TransferImportReport();
    await aAgain.import(back, nextDir(), report: backReport);
    p.check(await marks(), [
      ...aMarksBefore,
      'B mark|text|B mark|4278255360|false|false|3.0|-',
    ], 'もう1台へ戻しても、自分の透かしは増えない');
    p.check(backReport.addedCopies, isEmpty, '戻しても複製は足さない');
    p.check(pictureFiles(), 1, 'もう1台の画像のファイルは増えない');
    p.verify();
  });

  test('a watermark both devices edited differently keeps this device\'s '
      'version and adds the other one as a copy; a file from an earlier '
      'version adds its text watermarks and skips image watermarks whose '
      'picture is not in the file', () async {
    useDevice('A', {'language': 'ja'});
    final aMarks = WatermarkService();
    await aMarks.init();
    final shared = await aMarks.addTextWatermark('Sign', color: 0xFF000000);
    await settleTransfer();
    final first = await (await TransferDevice.start()).export();
    await aMarks.updateAsset(shared.copyWith(textColor: 0xFF0000FF));
    await settleTransfer();
    final second = await (await TransferDevice.start()).export();

    useDevice('B', {'language': 'ja'});
    var b = await TransferDevice.start();
    await b.import(first, nextDir());
    final p = _Problems();
    p.check(await marks(), [
      'Sign|text|Sign|4278190080|false|false|3.0|-',
    ], 'もう1台の透かしが届く');
    final bMarks = WatermarkService();
    await bMarks.init();
    final received = bMarks.assets.where((m) => m.id == shared.id).firstOrNull;
    if (received != null) {
      await bMarks.updateAsset(received.copyWith(textColor: 0xFF00FF00));
    }
    await settleTransfer();
    b = await TransferDevice.start();
    final report = TransferImportReport();
    await b.import(second, nextDir(), report: report);

    p.check(await marks(), [
      'Sign|text|Sign|4278255360|false|false|3.0|-',
      'Sign (コピー)|text|Sign|4278190335|false|false|3.0|-',
    ], 'この端末の版を残し、もう1台の版を複製として足す');
    p.check(report.addedCopies, ['Sign (コピー)'], '足した複製を知らせる');
    await b.import(second, nextDir());
    p.check((await marks()).length, 2, '読み直しても増えない');

    // 以前の版のファイル：端末保存データに透かしの一覧だけがある（画像は
    // 入っていない）。
    useDevice('C', {'language': 'ja'});
    final cMarks = WatermarkService();
    await cMarks.init();
    final cLogo = File('${temp.path}/c.png')..writeAsBytesSync([9, 9]);
    await cMarks.addWatermark(cLogo.path);
    await settleTransfer();
    final c = await TransferDevice.start();
    await c.importData(
      NiatraData({
        'localPreferences': {
          'watermark_assets': [
            jsonEncode(
              const WatermarkAsset(
                id: 'wm_old_text',
                name: 'Old sign',
                type: WatermarkAssetType.text,
                // 文字の透かしにファイル名が付いていても使わない。
                fileName: '../outside.png',
                text: 'Old sign',
                textColor: 0xFF123456,
              ).toJson(),
            ),
            jsonEncode(
              const WatermarkAsset(
                id: 'wm_old_image',
                name: 'Old logo',
                fileName: 'wm_old_image.png',
              ).toJson(),
            ),
          ],
        },
      }, Archive()),
      nextDir(),
    );
    p.check(await marks(), [
      'c|image|null|null|false|false|3.0|9,9',
      'Old sign|text|Old sign|4279383126|false|false|3.0|-',
    ], '文字の透かしは届き、画像の無い画像の透かしは足さない');
    final cAfter = WatermarkService();
    await cAfter.init();
    p.check(
      cAfter.assets.where((m) => m.id == 'wm_old_text').map((m) => m.fileName),
      [null],
      '文字の透かしはファイルを持たない（消すときにほかのファイルを消さない）',
    );
    p.verify();
  });

  _imageWatermarkTests(() => temp, useDevice, nextDir, () => storage);
}

void _imageWatermarkTests(
  Directory Function() temp,
  void Function(String who, Map<String, Object> saved) useDevice,
  Directory Function() nextDir,
  Directory Function() storage,
) {
  int pictureFiles() {
    final dir = Directory('${storage().path}/niarim/watermarks');
    return dir.existsSync() ? dir.listSync().length : 0;
  }

  Future<List<String>> pictures() async {
    final service = WatermarkService();
    await service.init();
    return [
      for (final m in service.assets)
        '${m.name}|${m.shadowEnabled}|${m.outlineEnabled}|'
            '${await _picture(service, m)}',
    ];
  }

  test('the same picture registered as a watermark on both devices is not '
      'added twice and leaves no extra file', () async {
    final logo = File('${temp().path}/logo.png')..writeAsBytesSync([7, 7, 7]);
    useDevice('A', {'language': 'ja'});
    final aMarks = WatermarkService();
    await aMarks.init();
    await aMarks.addWatermark(logo.path);
    await settleTransfer();
    final bytes = await (await TransferDevice.start()).export();

    await Future<void>.delayed(const Duration(milliseconds: 3));
    useDevice('B', {'language': 'ja'});
    final bMarks = WatermarkService();
    await bMarks.init();
    await bMarks.addWatermark(logo.path);
    await settleTransfer();
    final b = await TransferDevice.start();
    final report = TransferImportReport();
    await b.import(bytes, nextDir(), report: report);
    expect(await pictures(), ['logo|false|false|7,7,7']);
    expect(report.addedCopies, isEmpty);
    expect(pictureFiles(), 1, reason: '足さなかった透かしの画像を残さない');
  });

  test('an image watermark both devices edited differently arrives as a copy '
      'with the same picture; deleting either one keeps the other\'s '
      'picture', () async {
    final logo = File('${temp().path}/logo.png')..writeAsBytesSync([5, 4, 3]);
    useDevice('A', {'language': 'ja'});
    final aMarks = WatermarkService();
    await aMarks.init();
    final mark = await aMarks.addWatermark(logo.path);
    await settleTransfer();
    final first = await (await TransferDevice.start()).export();
    await aMarks.updateAsset(mark.copyWith(shadowEnabled: true));
    await settleTransfer();
    final second = await (await TransferDevice.start()).export();

    useDevice('B', {'language': 'ja'});
    await (await TransferDevice.start()).import(first, nextDir());
    final bMarks = WatermarkService();
    await bMarks.init();
    final received = bMarks.assets.where((m) => m.id == mark.id).firstOrNull;
    expect(received, isNotNull, reason: '画像の透かしが届く');
    await bMarks.updateAsset(received!.copyWith(outlineEnabled: true));
    await settleTransfer();
    await (await TransferDevice.start()).import(second, nextDir());
    expect(await pictures(), [
      'logo|false|true|5,4,3',
      'logo (コピー)|true|false|5,4,3',
    ], reason: 'この端末の版を残し、もう1台の版を同じ画像の複製として足す');

    final after = WatermarkService();
    await after.init();
    await after.removeWatermark(mark.id);
    expect(await pictures(), [
      'logo (コピー)|true|false|5,4,3',
    ], reason: '元の透かしを消しても、複製の画像は残る');
  });
}

/// 透かしの画像の中身（文字の透かし・画像の無い透かしは「-」）。
Future<String> _picture(WatermarkService service, WatermarkAsset mark) async {
  final path = await service.pathOf(mark.id);
  if (path == null) return '-';
  return File(path).readAsBytesSync().join(',');
}
