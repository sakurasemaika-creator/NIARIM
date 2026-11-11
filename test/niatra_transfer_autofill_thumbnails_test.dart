import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/autofill_preset.dart';
import 'package:niarim/services/autofill_preset_service.dart';
import 'package:niarim/utils/transfer_merge.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/niatra_transfer_device.dart';

/// 自動塗りプリセットに利用者が付けたサムネイルの画像は、ブラシ・トーン・
/// スタンプ・透かしの画像と同じく引き継ぎ（.niatra）で移る。複製として足した
/// プリセットがこの端末のプリセットと同じ画像のファイルを使っていても、
/// 片方のサムネイルを替える・外すと、もう片方の画像が消えない。

const _red = 0xFFFF0000;
const _blue = 0xFF0000FF;

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

const _mine = AutofillPreset(
  id: 'p_mine',
  name: 'Mine',
  parts: [AutofillPart(id: 'mine_base', name: 'Base', color: _red)],
);

/// 画像の中身（読めなければnull）。
List<int>? _bytes(String? path) => path != null && File(path).existsSync()
    ? File(path).readAsBytesSync()
    : null;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  late Directory temp;
  late Directory storage;
  setUp(() {
    temp = Directory.systemTemp.createTempSync('niatra_autofill_thumbs_');
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

  /// [who]の端末の書類フォルダへ切り替え、[saved]の保存で起動し直す
  /// （読み込みは引き継ぎ画面と同じく、その端末の書類フォルダへ画像を置く）。
  Future<TransferDevice> useDevice(String who, Map<String, Object> saved) {
    storage = Directory('${temp.path}/$who')..createSync(recursive: true);
    SharedPreferences.setMockInitialValues(saved);
    return TransferDevice.start();
  }

  /// サムネイルの画像のファイルの数（読み直しでファイルを増やさない）。
  int thumbnailFiles() {
    final dir = Directory('${storage.path}/niarim/autofill_thumbnails');
    return dir.existsSync() ? dir.listSync().length : 0;
  }

  test('a thumbnail picked for a preset on the other device arrives with the '
      'preset; a preset that is the same here and has no thumbnail takes it; '
      'one with its own keeps it; reading again writes no file', () async {
    final a = await useDevice('A', {'language': 'ja'});
    await a.autofill.addPreset(_mine);
    await a.autofill.addPreset(
      const AutofillPreset(
        id: 'p_shared',
        name: 'Shared',
        parts: [AutofillPart(id: 'shared_base', name: 'Base', color: _red)],
      ),
    );
    await a.autofill.addPreset(
      const AutofillPreset(
        id: 'p_own',
        name: 'Own',
        parts: [AutofillPart(id: 'own_base', name: 'Base', color: _red)],
      ),
    );
    await a.autofill.setPresetThumbnailBytes(
      'p_mine',
      Uint8List.fromList([9, 9, 9]),
    );
    await a.autofill.setPresetThumbnailBytes(
      'p_shared',
      Uint8List.fromList([8, 8, 8]),
    );
    await a.autofill.setPresetThumbnailBytes(
      'p_own',
      Uint8List.fromList([7, 7, 7]),
    );
    await settleTransfer();
    final bytes = await a.export();
    // もう1台（Aの画像はBには無い）。
    Directory('${temp.path}/A').deleteSync(recursive: true);

    final b = await useDevice('B', {'language': 'ja'});
    await b.autofill.addPreset(
      const AutofillPreset(
        id: 'p_shared',
        name: 'Shared',
        parts: [AutofillPart(id: 'shared_base', name: 'Base', color: _red)],
      ),
    );
    await b.autofill.addPreset(
      const AutofillPreset(
        id: 'p_own',
        name: 'Own',
        parts: [AutofillPart(id: 'own_base', name: 'Base', color: _red)],
      ),
    );
    await b.autofill.setPresetThumbnailBytes(
      'p_own',
      Uint8List.fromList([1, 1, 1]),
    );
    await settleTransfer();
    await b.import(bytes, storage);

    final p = _Problems();
    String? thumb(AutofillPresetService s, String id) =>
        s.presets.firstWhere((x) => x.id == id).thumbnailPath;
    p.check(_bytes(thumb(b.autofill, 'p_mine')), [9, 9, 9], '付けた画像が届く');
    p.check(
      thumb(b.autofill, 'p_mine')?.startsWith('${temp.path}/B/'),
      isTrue,
      'この端末の書類フォルダに置く',
    );
    p.check(_bytes(thumb(b.autofill, 'p_shared')), [
      8,
      8,
      8,
    ], 'この端末で画像の無い同じプリセットには付ける');
    p.check(_bytes(thumb(b.autofill, 'p_own')), [1, 1, 1], 'この端末で付けた画像はそのまま');
    p.check(thumbnailFiles(), 3, '使わない画像は残さない');
    final saved = await _snapshot();
    await b.import(bytes, storage);
    p.check(
      (await _snapshot())['autofill_presets'],
      saved['autofill_presets'],
      '読み直しても変わらない',
    );
    p.check(thumbnailFiles(), 3, '読み直しても画像のファイルは増えない');
    p.verify();
  });

  test('changing or removing the thumbnail of a copy that a transfer added '
      'keeps the thumbnail of this device\'s preset, and the other way '
      'round', () async {
    final a = await useDevice('A', {'language': 'ja'});
    await a.autofill.addPreset(_mine);
    await a.autofill.setPresetThumbnailBytes(
      'p_mine',
      Uint8List.fromList([9, 9, 9]),
    );
    await settleTransfer();
    final backup = await a.export();
    // バックアップの後で色を変え、古いバックアップを読む。
    final mine = a.autofill.presets.firstWhere((x) => x.id == 'p_mine');
    await a.autofill.updatePreset(
      mine.copyWith(parts: [mine.parts.single.copyWith(color: _blue)]),
    );
    await settleTransfer();
    await a.import(backup, storage);

    final p = _Problems();
    AutofillPreset original() =>
        a.autofill.presets.firstWhere((x) => x.id == 'p_mine');
    AutofillPreset? copy() =>
        a.autofill.presets.where((x) => x.name == 'Mine (コピー)').firstOrNull;
    p.check(copy(), isNotNull, 'バックアップの版を複製として足す');
    p.check(_bytes(copy()?.thumbnailPath), [9, 9, 9], '複製にも同じ画像');
    final copyId = copy()?.id;
    if (copyId != null) {
      await a.autofill.setPresetThumbnailBytes(
        copyId,
        Uint8List.fromList([5, 5, 5]),
      );
      p.check(_bytes(original().thumbnailPath), [
        9,
        9,
        9,
      ], '複製の画像を替えても、この端末のプリセットの画像は消えない');
      await a.autofill.clearPresetThumbnail(copyId);
      p.check(_bytes(original().thumbnailPath), [
        9,
        9,
        9,
      ], '複製の画像を外しても、この端末のプリセットの画像は消えない');
    }

    // 逆向き：もう一度読んで複製が元と同じ画像を使うようにしてから、元の
    // 画像を外す。
    final again = await useDevice('A2', {'language': 'ja'});
    await again.autofill.addPreset(_mine);
    await again.autofill.setPresetThumbnailBytes(
      'p_mine',
      Uint8List.fromList([9, 9, 9]),
    );
    await settleTransfer();
    final file = await again.export();
    final mine2 = again.autofill.presets.firstWhere((x) => x.id == 'p_mine');
    await again.autofill.updatePreset(
      mine2.copyWith(parts: [mine2.parts.single.copyWith(color: _blue)]),
    );
    await settleTransfer();
    await again.import(file, storage);
    final copy2 = again.autofill.presets
        .where((x) => x.name == 'Mine (コピー)')
        .firstOrNull;
    await again.autofill.clearPresetThumbnail('p_mine');
    p.check(_bytes(copy2?.thumbnailPath), [9, 9, 9], '元の画像を外しても、複製の画像は消えない');
    p.verify();
  });

  test('a sample preset whose parts are as shipped here but that has a '
      'thumbnail picked here is not replaced by the other device\'s version: '
      'that version comes as a copy with its own thumbnail', () async {
    final a = await useDevice('A', {'language': 'ja'});
    final heroA = a.autofill.presets.firstWhere((x) => x.id == 'p1');
    await a.autofill.updatePreset(
      heroA.copyWith(
        parts: [
          heroA.parts.first.copyWith(color: 0xFF00FF00),
          ...heroA.parts.skip(1),
        ],
      ),
    );
    await a.autofill.setPresetThumbnailBytes(
      'p1',
      Uint8List.fromList([7, 7, 7]),
    );
    await settleTransfer();
    final bytes = await a.export();
    Directory('${temp.path}/A').deleteSync(recursive: true);

    // B：見本のパーツはそのままで、サムネイルだけ付けた。
    final b = await useDevice('B', {'language': 'ja'});
    final shippedParts = [
      for (final part
          in b.autofill.presets.firstWhere((x) => x.id == 'p1').parts)
        part.color,
    ];
    await b.autofill.setPresetThumbnailBytes(
      'p1',
      Uint8List.fromList([1, 1, 1]),
    );
    await settleTransfer();
    final report = TransferImportReport();
    await b.import(bytes, storage, report: report);

    final p = _Problems();
    final hero = b.autofill.presets.firstWhere((x) => x.id == 'p1');
    p.check(_bytes(hero.thumbnailPath), [1, 1, 1], 'この端末で付けた画像はそのまま');
    p.check(
      [for (final part in hero.parts) part.color],
      shippedParts,
      'この端末の見本のまま',
    );
    final copy = b.autofill.presets
        .where((x) => x.name == '主人公 (コピー)')
        .firstOrNull;
    p.check(copy?.parts.first.color, 0xFF00FF00, 'もう1台の版は複製として足す');
    p.check(_bytes(copy?.thumbnailPath), [7, 7, 7], '複製はもう1台の画像を持つ');
    p.check(report.addedCopies, ['主人公 (コピー)'], '足した複製を知らせる');
    p.check(thumbnailFiles(), 2, '使う画像だけを残す');
    final saved = await _snapshot();
    await b.import(bytes, storage);
    p.check(
      (await _snapshot())['autofill_presets'],
      saved['autofill_presets'],
      '読み直しても変わらない',
    );
    p.check(thumbnailFiles(), 2, '読み直しても画像のファイルは増えない');
    p.verify();
  });
}
