import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart' show getCrc32;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/watermark_asset.dart';
import '../utils/app_error_reporter.dart';
import '../utils/duplicate_name.dart';
import '../utils/saved_list_reader.dart';
import '../utils/tolerant_preferences.dart';
import '../utils/transfer_merge.dart';

/// ユーザーウォーターマーク管理サービス（プレミアム限定）。
/// ウォーターマークは専用機能ではなく画像素材と同じタイムライン素材として
/// 扱うが、登録・管理自体はプロジェクトをまたぐアプリ全体の設定として行う。
class WatermarkService extends ChangeNotifier {
  static const _prefsKey = 'watermark_assets';

  final List<WatermarkAsset> _assets = [];
  int _counter = 0;

  List<WatermarkAsset> get assets => List.unmodifiable(_assets);

  Future<Directory> _watermarksDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/niarim/watermarks');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.readStringList(_prefsKey) ?? const [];
    _assets.addAll(readSavedJsonList(raw, WatermarkAsset.fromJson));
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKey,
      _assets.map((a) => jsonEncode(a.toJson())).toList(),
    );
  }

  /// [sourcePath]の画像をウォーターマークとして登録する。
  Future<WatermarkAsset> addWatermark(String sourcePath) async {
    final dir = await _watermarksDir();
    final ext = sourcePath.contains('.') ? sourcePath.split('.').last : 'png';
    final id = 'wm_${DateTime.now().millisecondsSinceEpoch}_${_counter++}';
    final fileName = '$id.$ext';
    await File(sourcePath).copy('${dir.path}/$fileName');
    final name = sourcePath
        .split(RegExp(r'[\\/]'))
        .last
        .replaceAll(RegExp(r'\.[^.]+$'), '');
    final asset = WatermarkAsset(
      id: id,
      name: name,
      type: WatermarkAssetType.image,
      fileName: fileName,
    );
    _assets.add(asset);
    await _persist();
    notifyListeners();
    return asset;
  }

  /// 入力した文字列をウォーターマークとして登録する（
  /// 「設定項目：画像選択 / 文字入力」の文字入力側）。ドロップシャドウ・
  /// 縁取りも登録時点で既定値として設定できる。
  Future<WatermarkAsset> addTextWatermark(
    String text, {
    required int color,
    String? fontFamily,
    bool shadowEnabled = false,
    int shadowColor = 0x99000000,
    double shadowOffsetX = 4,
    double shadowOffsetY = 4,
    double shadowBlur = 6,
    bool outlineEnabled = false,
    int outlineColor = 0xFFFFFFFF,
    double outlineWidth = 3,
  }) async {
    final id = 'wm_${DateTime.now().millisecondsSinceEpoch}_${_counter++}';
    final asset = WatermarkAsset(
      id: id,
      name: textNameOf(text),
      type: WatermarkAssetType.text,
      text: text,
      textColor: color,
      fontFamily: fontFamily,
      shadowEnabled: shadowEnabled,
      shadowColor: shadowColor,
      shadowOffsetX: shadowOffsetX,
      shadowOffsetY: shadowOffsetY,
      shadowBlur: shadowBlur,
      outlineEnabled: outlineEnabled,
      outlineColor: outlineColor,
      outlineWidth: outlineWidth,
    );
    _assets.add(asset);
    await _persist();
    notifyListeners();
    return asset;
  }

  /// 文字の透かしの名前（文字の先頭12文字）。
  static String textNameOf(String text) =>
      text.length > 12 ? '${text.substring(0, 12)}…' : text;

  /// 文字の透かし[existing]の文字を[text]にしたときの名前。名前は文字から
  /// 作るが、引き継ぎで足した複製（文字から作った名前に「 (コピー)」を
  /// 付けた名前）は複製の印を残す（印を外すと、元の透かしと同じ名前が並び
  /// 見分けられない）。
  static String renamedTextWatermark(WatermarkAsset existing, String text) {
    final mark = copyNameMark(existing.name);
    final copied =
        mark != null &&
        existing.name != textNameOf(existing.text ?? '') &&
        mark.name == textNameOf(existing.text ?? '');
    return copied ? '${textNameOf(text)}${mark.mark}' : textNameOf(text);
  }

  /// 登録済みウォーターマークの内容を更新する。過去に作成した
  /// ウォーターマークの編集もタップで後からできるようにする。
  /// 画像そのものの差し替えは行わず、名前・文字/色/フォント・ドロップ
  /// シャドウ/縁取りの既定設定のみを更新する。
  Future<void> updateAsset(WatermarkAsset updated) async {
    final idx = _assets.indexWhere((a) => a.id == updated.id);
    if (idx < 0) return;
    _assets[idx] = updated;
    await _persist();
    notifyListeners();
  }

  Future<void> removeWatermark(String id) async {
    final idx = _assets.indexWhere((a) => a.id == id);
    if (idx < 0) return;
    final fileName = _assets[idx].fileName;
    // 引き継ぎで足した複製は、元の透かしと同じ画像のファイルを使うことが
    // ある。ほかの透かしが使っている画像は消さない。
    final shared = _assets.any((a) => a.id != id && a.fileName == fileName);
    if (fileName != null && !shared) {
      final dir = await _watermarksDir();
      final file = File('${dir.path}/$fileName');
      if (file.existsSync()) await file.delete();
    }
    _assets.removeAt(idx);
    await _persist();
    notifyListeners();
  }

  /// 引き継ぎ（.niatra）の端末保存データで受け取った透かし（保存と同じ
  /// 1件ずつのJSON）を、この端末の一覧へ足す。この端末の透かしは書き換え
  /// ない（決まりは[mergeTransferredItems]：同じIDで中身か名前が違えば、
  /// 受け取った方を「名前 (コピー)」として足す。同じ中身が既にあれば足さ
  /// ない。同じファイルを何度読んでも増えない）。
  ///
  /// 画像の透かしは[images]（透かしのID → 画像のバイト列）の画像をこの端末の
  /// 透かしのフォルダへ書いて使う（この端末にあるファイルは書き換えず、同じ
  /// 中身のファイルがあればそれを使う）。画像の無い画像の透かし（画像を
  /// 入れていなかった以前の版のファイル）は使えないので足さない。画像は
  /// 置いた場所ではなく中身で比べる。合わせた後でどの透かしも使わない、
  /// この読み込みで書いた画像は消す。変えたときだけ保存する。受け取った
  /// 透かしのIDごとの、合わせた後でその中身を持つこの端末の透かしのIDを
  /// [placed]へ書く（移した作品の透かしのレイヤーを合わせるため）。
  Future<void> mergeTransferred(
    List<String> saved, {
    required TransferCopyNames copyNames,
    Map<String, List<int>> images = const {},
    Map<String, String>? placed,
  }) async {
    Directory? dir;
    final written = <String>{};
    final incoming = <WatermarkAsset>[];
    for (final asset in readSavedJsonList(saved, WatermarkAsset.fromJson)) {
      if (asset.type == WatermarkAssetType.text) {
        // 文字の透かしはファイルを持たない（受け取ったファイル名は使わない。
        // 消すときにそのファイルを消しに行かないように）。
        incoming.add(
          WatermarkAsset.fromJson({...asset.toJson(), 'fileName': null}),
        );
        continue;
      }
      final bytes = images[asset.id];
      if (bytes == null) continue;
      try {
        dir ??= await _watermarksDir();
        incoming.add(
          WatermarkAsset.fromJson({
            ...asset.toJson(),
            'fileName': await _placeImage(bytes, dir, asset, written: written),
          }),
        );
      } catch (error, stack) {
        // 書けない画像1件のために、ほかの透かしの読み込みを止めない。
        AppErrorReporter.record(error, stack);
      }
    }
    if (incoming.isEmpty) return;
    String? pathOfFile(String? fileName) =>
        fileName == null || dir == null ? null : '${dir.path}/$fileName';
    final pictures = await TransferImageDigests.read([
      for (final a in [..._assets, ...incoming])
        if (a.type == WatermarkAssetType.image) pathOfFile(a.fileName),
    ]);
    // 前の読み込みでもう1台の版を足した複製（名前を変えていても見つける）。
    final copies = await TransferCopyRecord.read(TransferCopyRecord.watermarks);
    final changed = mergeTransferredItems(
      _assets,
      incoming,
      TransferMergeRules<WatermarkAsset>(
        idOf: (a) => a.id,
        nameOf: (a) => a.name,
        contentOf: (a) => a.toJson()
          ..remove('id')
          ..remove('name')
          ..remove('fileName')
          ..['picture'] = a.type == WatermarkAssetType.image
              ? pictures.of(pathOfFile(a.fileName) ?? a.fileName)
              : null,
        organizationOf: (_) =>
            (favorite: false, tags: const [], folderId: null),
        withOrganization: (a, _) => a,
        asCopy: (a, id, name) =>
            WatermarkAsset.fromJson({...a.toJson(), 'id': id, 'name': name}),
        newId: (attempt) =>
            'wm_${DateTime.now().millisecondsSinceEpoch}_t$attempt',
        copyNames: copyNames,
      ),
      placed: placed,
      copies: copies,
    );
    await copies.save();
    final used = {for (final a in _assets) a.fileName};
    for (final fileName in written) {
      if (used.contains(fileName)) continue;
      try {
        final file = File(pathOfFile(fileName)!);
        if (file.existsSync()) await file.delete();
      } on FileSystemException {
        // 消せない1件は残す（使われていないだけで害は無い）。
      }
    }
    if (!changed) return;
    await _persist();
    notifyListeners();
  }

  /// 受け取った画像[bytes]を置くファイルの名前。同じIDの透かしがこの端末で
  /// 同じ中身の画像を使っていればそのファイル、無ければ中身から決まる名前で
  /// 書く（その名前のファイルが同じ中身なら書かずに使い、違えば別の名前に
  /// する。この端末にあるファイルは書き換えない）。書いたファイルの名前は
  /// [written]へ書き留める。
  Future<String> _placeImage(
    List<int> bytes,
    Directory dir,
    WatermarkAsset asset, {
    required Set<String> written,
  }) async {
    final mine = _assets.where((a) => a.id == asset.id).firstOrNull?.fileName;
    if (mine != null && await _sameBytes(File('${dir.path}/$mine'), bytes)) {
      return mine;
    }
    final ext = _extensionOf(asset.fileName);
    final crc = getCrc32(bytes).toRadixString(16).padLeft(8, '0');
    final base = 'wm_transfer_${crc}_${bytes.length}';
    var name = '$base.$ext';
    for (var n = 2; File('${dir.path}/$name').existsSync(); n++) {
      if (await _sameBytes(File('${dir.path}/$name'), bytes)) return name;
      name = '${base}_$n.$ext';
    }
    await File('${dir.path}/$name').writeAsBytes(bytes, flush: true);
    written.add(name);
    return name;
  }

  static Future<bool> _sameBytes(File file, List<int> bytes) async {
    if (!file.existsSync() || await file.length() != bytes.length) {
      return false;
    }
    return listEquals(await file.readAsBytes(), bytes);
  }

  /// 画像のファイルの拡張子（使えない形ならpng）。
  static String _extensionOf(String? fileName) {
    final dot = fileName?.lastIndexOf('.') ?? -1;
    if (fileName == null || dot < 0) return 'png';
    final ext = fileName.substring(dot + 1).toLowerCase();
    return RegExp(r'^[a-z0-9]{1,8}$').hasMatch(ext) ? ext : 'png';
  }

  /// ウォーターマークIDの実ファイルパスを解決する（画像タイプのみ・
  /// 見つからない場合や文字タイプの場合はnull）。
  Future<String?> pathOf(String id) async {
    final asset = _assets.where((a) => a.id == id).firstOrNull;
    if (asset == null || asset.fileName == null) return null;
    final dir = await _watermarksDir();
    final file = File('${dir.path}/${asset.fileName}');
    return file.existsSync() ? file.path : null;
  }
}
