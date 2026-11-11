import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show kIsWeb, listEquals;
import 'package:path_provider/path_provider.dart';

import '../l10n/app_localizations.dart';
import '../models/autofill_preset.dart';
import '../models/brush.dart';
import '../models/stamp.dart';
import '../models/tone.dart';
import '../models/watermark_asset.dart';
import '../services/autofill_preset_service.dart';
import '../services/brush_service.dart';
import '../services/stamp_service.dart';
import '../services/tone_service.dart';
import '../services/watermark_service.dart';
import '../utils/app_error_reporter.dart';
import '../utils/transfer_merge.dart';
import 'archive_security.dart';
import 'niatra_serializer.dart';

/// `.niatra` に端末固有パスだけでなく、カスタムブラシ／トーン／スタンプの
/// 画像本体も同梱するための補助レイヤー。
///
/// 旧 `.niatra` は [NiatraSerializer] がそのまま読めるよう一切変更せず、
/// このクラスが付与する `creativeAssetsVersion` が存在する新形式だけを
/// フルモデル＋埋め込み画像として復元する。
class NiatraAssetBundle {
  static const _dataFile = 'data.json';
  static const _versionKey = 'creativeAssetsVersion';
  static const _version = 1;
  static const _embeddedImageKey = 'embeddedImagePath';
  static const _embeddedImagesKey = 'embeddedImagePaths';

  /// 既存 [NiatraSerializer.export] が作ったZIPへカスタム画像を追加し、
  /// ブラシ／トーン／スタンプのJSONを各モデルの完全なtoJson()へ置き換える。
  /// これにより、画像だけでなくfolderId・fadeIn/fadeOut・edgeJitter等も欠落しない。
  ///
  /// 自動塗りのプリセットのサムネイルの画像も入れる。
  ///
  /// 端末保存データで透かしの一覧を移すときは、[watermarks]の画像の透かしの
  /// 画像も入れる（[NiatraSerializer.watermarkImagesKey]。読み込み側の
  /// `WatermarkService.mergeTransferred`が使う）。読めない画像は入れない。
  static Future<Uint8List> enrichExport(
    Uint8List original, {
    required Map<String, bool> selectedItems,
    required BrushService brush,
    required ToneService tone,
    required StampService stamp,
    WatermarkService? watermarks,
    String? restoreBasePath,
  }) async {
    final sourceArchive = ArchiveSecurity.decodeZip(original);
    final dataFile = sourceArchive.findFile(_dataFile);
    if (dataFile == null) throw const FormatException('data.json not found');
    final data =
        jsonDecode(utf8.decode(dataFile.content as List<int>))
            as Map<String, dynamic>;
    data[_versionKey] = _version;

    final output = Archive();
    for (final file in sourceArchive.files) {
      if (file.name == _dataFile) continue;
      output.addFile(ArchiveFile(file.name, file.size, file.content));
    }

    if (selectedItems['ブラシ'] ?? false) {
      final items = <Map<String, dynamic>>[];
      for (int i = 0; i < brush.brushes.length; i++) {
        final model = brush.brushes[i];
        final json = Map<String, dynamic>.from(model.toJson());
        final imagePaths = model.resolvedCustomImagePaths;
        if (imagePaths.length > 1) {
          await _embedBrushImages(
            output,
            json,
            sourcePaths: imagePaths,
            index: i,
          );
        } else {
          await _embedImage(
            output,
            json,
            sourcePath: model.customImagePath,
            category: 'Brushes',
            index: i,
            pathKey: 'customImagePath',
          );
        }
        items.add(json);
      }
      data['brushes'] = items;
    }

    if (selectedItems['素材'] ?? false) {
      final tones = <Map<String, dynamic>>[];
      for (int i = 0; i < tone.tones.length; i++) {
        final model = tone.tones[i];
        final json = Map<String, dynamic>.from(model.toJson());
        await _embedImage(
          output,
          json,
          sourcePath: model.texturePath,
          category: 'Tones',
          index: i,
          pathKey: 'texturePath',
        );
        tones.add(json);
      }
      data['tones'] = tones;

      final stamps = <Map<String, dynamic>>[];
      for (int i = 0; i < stamp.stamps.length; i++) {
        final model = stamp.stamps[i];
        final json = Map<String, dynamic>.from(model.toJson());
        await _embedImage(
          output,
          json,
          sourcePath: model.imagePath,
          category: 'Stamps',
          index: i,
          pathKey: 'imagePath',
        );
        stamps.add(json);
      }
      data['stamps'] = stamps;
    }

    // 自動塗りのプリセットに付けたサムネイルの画像。
    final presets = data['autofillPresets'];
    if ((selectedItems['プリセット'] ?? false) && presets is List) {
      for (var i = 0; i < presets.length; i++) {
        final json = presets[i];
        if (json is! Map<String, dynamic>) continue;
        await _embedImage(
          output,
          json,
          sourcePath: json['thumbnailPath'] as String?,
          category: 'AutofillThumbnails',
          index: i,
          pathKey: 'thumbnailPath',
        );
      }
    }

    final local = data['localPreferences'];
    if (watermarks != null &&
        local is Map &&
        local.containsKey('watermark_assets')) {
      final places = <String, String>{};
      for (final asset in watermarks.assets) {
        if (asset.type != WatermarkAssetType.image) continue;
        try {
          final path = await watermarks.pathOf(asset.id);
          if (path == null) continue;
          final bytes = await File(path).readAsBytes();
          final archivePath =
              'CreativeAssets/Watermarks/${places.length}.${_safeExtension(path)}';
          output.addFile(ArchiveFile(archivePath, bytes.length, bytes));
          places[asset.id] = archivePath;
        } catch (error, stack) {
          // 読めない画像1件のために引き継ぎ全体を失敗させない（その透かしは
          // 読み込み側で足さない）。
          AppErrorReporter.record(error, stack);
        }
      }
      if (places.isNotEmpty) {
        data[NiatraSerializer.watermarkImagesKey] = places;
      }
    }

    final jsonBytes = utf8.encode(jsonEncode(data));
    output.addFile(ArchiveFile(_dataFile, jsonBytes.length, jsonBytes));
    final encoded = ZipEncoder().encode(output);
    if (encoded == null) throw const FormatException('ZIP encoding failed');
    return Uint8List.fromList(encoded);
  }

  /// 新形式の埋め込み画像を取り込み先端末のアプリ領域へ展開し、対応する
  /// Brush/Tone/Stampと、[autofillPresets]を渡されたときは自動塗りの
  /// プリセット（サムネイルの画像）をこの端末の一覧へ合わせる（IDは元の
  /// まま。合わせ方はNiatraSerializer.mergeBrushes等と各サービスの
  /// mergeTransferred：この端末の内容は黙って失わない）。処理したカテゴリは
  /// rawから除去し、後続のNiatraSerializer.applyTo()による二重の取り込みを
  /// 防ぐ。
  ///
  /// 画像は、同じIDの項目がこの端末で同じ中身の画像を使っていればそれを使い、
  /// 無ければ中身から決まる名前（同じ画像は同じ名前）で書く。その名前の
  /// ファイルが同じ中身なら書かずに使い、違う中身なら別の名前にする。どの
  /// 場合も、この端末にあるファイルを書き換えない（読み直しでファイルを
  /// 増やさない）。展開できなかった画像は、同じIDの項目がこの端末で使って
  /// いる画像のまま（各サービスが使う）。合わせた後でどの項目も使わない
  /// 画像（同じ中身の項目が既にあって足さなかった項目の画像）は、この読み
  /// 込みで書いた物だけ消す。
  ///
  /// 旧形式（creativeAssetsVersionなし）は何もせず、従来のapplyTo()へ委ねる。
  /// Webでは永続ファイルパスを作れないため画像だけ未復元になるが、完全な
  /// モデルJSON自体は同じ経路で復元し、旧Serializerによる項目欠落を防ぐ。
  static Future<void> restoreEmbeddedAssets(
    NiatraData data, {
    required BrushService brush,
    required ToneService tone,
    required StampService stamp,
    AutofillPresetService? autofillPresets,
    String? restoreBasePath,
    AppLocalizations? l10n,
    TransferImportReport? report,
  }) async {
    if (data.raw[_versionKey] != _version) return;

    final String? basePath =
        restoreBasePath ??
        (kIsWeb ? null : (await getApplicationDocumentsDirectory()).path);
    // この読み込みで新しく書いた画像。
    final written = <String>{};
    try {
      await _restoreAndMerge(
        data,
        brush: brush,
        tone: tone,
        stamp: stamp,
        autofillPresets: autofillPresets,
        basePath: basePath,
        written: written,
        l10n: l10n,
        report: report,
      );
    } finally {
      await _removeUnused(
        written,
        used: {
          for (final b in brush.brushes) ...b.resolvedCustomImagePaths,
          for (final t in tone.tones) ?t.texturePath,
          for (final s in stamp.stamps) ?s.imagePath,
          for (final p in autofillPresets?.presets ?? const <AutofillPreset>[])
            ?p.thumbnailPath,
        },
      );
    }
  }

  static Future<void> _restoreAndMerge(
    NiatraData data, {
    required BrushService brush,
    required ToneService tone,
    required StampService stamp,
    required AutofillPresetService? autofillPresets,
    required String? basePath,
    required Set<String> written,
    AppLocalizations? l10n,
    TransferImportReport? report,
  }) async {
    final brushesJson = data.raw['brushes'] as List<dynamic>?;
    if (brushesJson != null) {
      final brushes = <Brush>[];
      for (int i = 0; i < brushesJson.length; i++) {
        final json = Map<String, dynamic>.from(
          brushesJson[i] as Map<String, dynamic>,
        );
        final id = NiatraSerializer.transferredId(json['id'], 'Brush', i);
        json['id'] = id;
        // 組み込みブラシは定義をこの版のものにするので、画像を展開しない。
        if (!brush.isBuiltIn(id)) {
          final existing = brush.brushes.where((b) => b.id == id).firstOrNull;
          final restoredImages = await _restoreBrushImages(
            data,
            json,
            basePath: basePath,
            written: written,
            stem: _fileStem(id),
            existingPaths:
                existing?.resolvedCustomImagePaths ?? const <String>[],
          );
          if (restoredImages.isNotEmpty) {
            json['customImagePath'] = restoredImages.length == 1
                ? restoredImages.first
                : null;
            json['customImagePaths'] = restoredImages;
          } else {
            json['customImagePath'] = await _restoreImage(
              data,
              json,
              basePath: basePath,
              written: written,
              category: 'Brushes',
              stem: _fileStem(id),
              pathKey: 'customImagePath',
              existingPath: existing?.customImagePath,
            );
            json['customImagePaths'] = <String>[];
          }
        }
        brushes.add(Brush.fromJson(json));
      }
      await NiatraSerializer.mergeBrushes(
        data,
        brush,
        brushes,
        l10n: l10n,
        report: report,
      );
    }

    final tonesJson = data.raw['tones'] as List<dynamic>?;
    if (tonesJson != null) {
      final tones = <Tone>[];
      for (int i = 0; i < tonesJson.length; i++) {
        final json = Map<String, dynamic>.from(
          tonesJson[i] as Map<String, dynamic>,
        );
        final id = NiatraSerializer.transferredId(json['id'], 'Tone', i);
        json['id'] = id;
        if (!tone.isBuiltIn(id)) {
          json['texturePath'] = await _restoreImage(
            data,
            json,
            basePath: basePath,
            written: written,
            category: 'Tones',
            stem: _fileStem(id),
            pathKey: 'texturePath',
            existingPath: tone.tones
                .where((t) => t.id == id)
                .firstOrNull
                ?.texturePath,
          );
        }
        tones.add(Tone.fromJson(json));
      }
      await NiatraSerializer.mergeTones(
        data,
        tone,
        tones,
        l10n: l10n,
        report: report,
      );
    }

    final stampsJson = data.raw['stamps'] as List<dynamic>?;
    if (stampsJson != null) {
      final stamps = <Stamp>[];
      for (int i = 0; i < stampsJson.length; i++) {
        final json = Map<String, dynamic>.from(
          stampsJson[i] as Map<String, dynamic>,
        );
        final id = NiatraSerializer.transferredId(json['id'], 'Stamp', i);
        json['id'] = id;
        if (!stamp.isBuiltIn(id)) {
          json['imagePath'] = await _restoreImage(
            data,
            json,
            basePath: basePath,
            written: written,
            category: 'Stamps',
            stem: _fileStem(id),
            pathKey: 'imagePath',
            existingPath: stamp.stamps
                .where((s) => s.id == id)
                .firstOrNull
                ?.imagePath,
          );
        }
        stamps.add(Stamp.fromJson(json));
      }
      await NiatraSerializer.mergeStamps(
        data,
        stamp,
        stamps,
        l10n: l10n,
        report: report,
      );
    }

    // 自動塗りのプリセットは、パーツが使うトーンを合わせ終えてから合わせる。
    final presetsJson = data.raw['autofillPresets'];
    if (autofillPresets != null && presetsJson is List) {
      final presets = <AutofillPreset>[];
      for (final item in presetsJson) {
        if (item is! Map<String, dynamic>) continue;
        final json = Map<String, dynamic>.from(item);
        final id = json['id'];
        json['thumbnailPath'] = await _restoreImage(
          data,
          json,
          basePath: basePath,
          written: written,
          category: 'autofill_thumbnails',
          stem: _fileStem(id is String ? id : 'preset'),
          pathKey: 'thumbnailPath',
          existingPath: autofillPresets.presets
              .where((p) => p.id == id)
              .firstOrNull
              ?.thumbnailPath,
        );
        presets.add(AutofillPreset.fromJson(json));
      }
      await NiatraSerializer.mergeAutofillPresets(
        data,
        autofillPresets,
        presets,
        l10n: l10n,
        report: report,
      );
    }
  }

  /// ファイル名に使えるIDの形（受け取ったIDに`/`や`..`があっても、
  /// アプリの画像フォルダの外へ書かない）。
  static String _fileStem(String id) {
    final safe = id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return safe.length > 64 ? safe.substring(0, 64) : safe;
  }

  /// [bytes]を[directory]に置いたファイルのパスを返す。この端末にある
  /// ファイルは書き換えない：[existingPath]が同じ中身ならそれを使い、
  /// 無ければ中身から決まる名前（[stem]_CRC32_長さ）で書く。その名前の
  /// ファイルが既にあれば、同じ中身なら使い、違えば別の名前にする。
  /// 新しく書いたファイルは[written]へ書き留める。
  static Future<String> _writeOrReuse(
    List<int> bytes,
    Directory directory, {
    required String stem,
    required String ext,
    required Set<String> written,
    String? existingPath,
  }) async {
    if (existingPath != null && await _sameBytes(existingPath, bytes)) {
      return existingPath;
    }
    final crc = getCrc32(bytes).toRadixString(16).padLeft(8, '0');
    final base = '${directory.path}/${stem}_${crc}_${bytes.length}';
    var destination = File('$base.$ext');
    for (var n = 2; await destination.exists(); n++) {
      if (await _sameBytes(destination.path, bytes)) return destination.path;
      destination = File('${base}_$n.$ext');
    }
    await destination.writeAsBytes(bytes, flush: true);
    written.add(destination.path);
    return destination.path;
  }

  /// [written]（この読み込みで書いた画像）のうち、どの項目も使わない物を
  /// 消す。消せなくても読み込みは続ける。
  static Future<void> _removeUnused(
    Set<String> written, {
    required Set<String> used,
  }) async {
    for (final path in written) {
      if (used.contains(path)) continue;
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } on UnsupportedError {
        // ファイルを扱えない環境では何もしない。
      } on FileSystemException {
        // 消せない1件は残す（使われていないだけで害は無い）。
      }
    }
  }

  static Future<bool> _sameBytes(String path, List<int> bytes) async {
    try {
      final file = File(path);
      if (!await file.exists() || await file.length() != bytes.length) {
        return false;
      }
      return listEquals(await file.readAsBytes(), bytes);
    } on UnsupportedError {
      return false;
    } on FileSystemException {
      return false;
    }
  }

  static Future<void> _embedBrushImages(
    Archive archive,
    Map<String, dynamic> json, {
    required List<String> sourcePaths,
    required int index,
  }) async {
    final embedded = <String>[];
    for (var imageIndex = 0; imageIndex < sourcePaths.length; imageIndex++) {
      final sourcePath = sourcePaths[imageIndex];
      try {
        final source = File(sourcePath);
        if (!await source.exists()) continue;
        final bytes = await source.readAsBytes();
        final ext = _safeExtension(sourcePath);
        final archivePath =
            'CreativeAssets/Brushes/$index/${imageIndex.toString().padLeft(3, '0')}.$ext';
        archive.addFile(ArchiveFile(archivePath, bytes.length, bytes));
        embedded.add(archivePath);
      } on UnsupportedError {
        // Keep processing the remaining creative assets.
      } on FileSystemException {
        // A missing/unreadable variant must not abort the whole export.
      }
    }
    if (embedded.isNotEmpty) {
      json[_embeddedImagesKey] = embedded;
      json['customImagePath'] = null;
      json['customImagePaths'] = <String>[];
    }
  }

  static Future<List<String>> _restoreBrushImages(
    NiatraData data,
    Map<String, dynamic> json, {
    required String? basePath,
    required Set<String> written,
    required String stem,
    required List<String> existingPaths,
  }) async {
    final embedded = (json[_embeddedImagesKey] as List<dynamic>?)
        ?.whereType<String>()
        .toList();
    if (embedded == null || embedded.isEmpty || basePath == null) {
      return const <String>[];
    }
    final dir = Directory('$basePath/niarim/Brushes');
    if (!await dir.exists()) await dir.create(recursive: true);
    final restored = <String>[];
    for (var index = 0; index < embedded.length; index++) {
      final embeddedPath = embedded[index];
      final entry = data.archive.findFile(embeddedPath);
      if (entry == null) continue;
      restored.add(
        await _writeOrReuse(
          entry.content as List<int>,
          dir,
          stem: '${stem}_${index.toString().padLeft(3, '0')}',
          ext: _safeExtension(embeddedPath),
          written: written,
          existingPath: index < existingPaths.length
              ? existingPaths[index]
              : null,
        ),
      );
    }
    return restored;
  }

  static Future<void> _embedImage(
    Archive archive,
    Map<String, dynamic> json, {
    required String? sourcePath,
    required String category,
    required int index,
    required String pathKey,
  }) async {
    if (sourcePath == null || sourcePath.isEmpty) return;
    try {
      final source = File(sourcePath);
      if (!await source.exists()) return;
      final bytes = await source.readAsBytes();
      final ext = _safeExtension(sourcePath);
      final archivePath = 'CreativeAssets/$category/$index.$ext';
      archive.addFile(ArchiveFile(archivePath, bytes.length, bytes));
      json[_embeddedImageKey] = archivePath;
      // 元端末の絶対パスを別端末へ持ち越さない。
      json[pathKey] = null;
    } on UnsupportedError {
      // dart:ioが利用できない環境では従来形式相当へフォールバックする。
    } on FileSystemException {
      // 読めない画像1件のために引き継ぎ全体を失敗させない。
    }
  }

  static Future<String?> _restoreImage(
    NiatraData data,
    Map<String, dynamic> json, {
    required String? basePath,
    required Set<String> written,
    required String category,
    required String stem,
    required String pathKey,
    String? existingPath,
  }) async {
    final embeddedPath = json[_embeddedImageKey] as String?;
    if (embeddedPath != null) {
      if (basePath == null) return null;
      final entry = data.archive.findFile(embeddedPath);
      if (entry == null) return null;
      final dir = Directory('$basePath/niarim/$category');
      if (!await dir.exists()) await dir.create(recursive: true);
      return _writeOrReuse(
        entry.content as List<int>,
        dir,
        stem: stem,
        ext: _safeExtension(embeddedPath),
        written: written,
        existingPath: existingPath,
      );
    }

    // 新形式なのに画像が埋め込まれていない場合でも、同一端末内で元パスが
    // まだ有効なら利用できる。別端末で存在しない絶対パスはnullへ落とす。
    if (basePath == null) return null;
    final legacyPath = json[pathKey] as String?;
    if (legacyPath == null || legacyPath.isEmpty) return null;
    try {
      return await File(legacyPath).exists() ? legacyPath : null;
    } on UnsupportedError {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  static String _safeExtension(String path) {
    final fileName = path.replaceAll('\\', '/').split('/').last;
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return 'png';
    final ext = fileName.substring(dot + 1).toLowerCase();
    return RegExp(r'^[a-z0-9]{1,8}$').hasMatch(ext) ? ext : 'png';
  }
}
