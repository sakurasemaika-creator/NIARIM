import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/brush.dart';
import '../models/stamp.dart';
import '../models/tone.dart';
import 'brush_service.dart';
import 'stamp_service.dart';
import 'tone_service.dart';
import 'shared_asset_card_codec.dart';
import '../widgets/export_share_feedback.dart';

/// One public sharing format for brushes, tones and stamps: a complete PNG.
/// A ZIP is used only as an *in-memory* implementation of the compressed
/// model+original-image payload; users never select or share that container.
class SharedAssetCardService {
  SharedAssetCardService._();

  static String exportMenuLabel(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'ja'
          ? '共有カードを書き出す'
          : 'Export share card';

  /// The card is created once. Save-as writes the original PNG bytes to a
  /// user-selected location; Share uses the same original file unchanged.
  static Future<void> showExportResult(BuildContext context, File card) async {
    if (!context.mounted) return;
    final isJapanese = Localizations.localeOf(context).languageCode == 'ja';
    final action = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(isJapanese ? '共有カードを作成しました' : 'Share card created'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.file(card, height: 310, fit: BoxFit.contain),
              const SizedBox(height: 12),
              Text(isJapanese
                  ? '元のPNGファイルをそのまま保存・共有してください。SNSで画像を再保存すると復元データが失われる場合があります。'
                  : 'Save or share the original PNG. Re-encoding the image can strip its import data.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(isJapanese ? '閉じる' : 'Close'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(dialog, 'save'),
            icon: const Icon(Icons.save_alt),
            label: Text(isJapanese ? '端末に保存' : 'Save'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialog, 'share'),
            icon: const Icon(Icons.share_outlined),
            label: Text(isJapanese ? '共有' : 'Share'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (action == 'share') {
      await shareExportedFileWithNotice(context, card);
    } else if (action == 'save') {
      try {
        final fileName = card.uri.pathSegments.last;
        final selected = await FilePicker.platform.saveFile(
          dialogTitle: isJapanese ? '共有カードの保存先' : 'Save share card',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['png'],
          bytes: await card.readAsBytes(),
        );
        if (selected != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isJapanese ? '共有カードを保存しました' : 'Share card saved'),
          ));
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isJapanese
                ? '保存できませんでした: $error'
                : 'Could not save card: $error'),
          ));
        }
      }
    }
  }

  static Future<File> exportBrush(BrushService service, Brush brush) async {
    final paths = brush.resolvedCustomImagePaths;
    final settings = Map<String, dynamic>.from(brush.toJson())
      ..['folderId'] = null
      ..['customImagePath'] = paths.length == 1 ? 'images/000' : null
      ..['customImagePaths'] = [
        for (var i = 0; i < paths.length; i++) 'images/$i',
      ];
    final a = _assetArchive(settings);
    for (var i = 0; i < paths.length; i++) {
      final f = File(paths[i]);
      if (!await f.exists()) {
        throw FormatException('Brush source image is missing: ${paths[i]}');
      }
      final b = await f.readAsBytes();
      final ext = paths[i].split('.').last;
      a.addFile(ArchiveFile('images/${i.toString().padLeft(3, '0')}.$ext',
          b.length, b));
    }
    return _createCard('brush', brush.name, _toZip(a));
  }

  static Future<File> exportTone(ToneService service, Tone tone) async {
    final settings = Map<String, dynamic>.from(tone.toJson())
      ..['folderId'] = null
      ..['texturePath'] = tone.texturePath == null ? null : 'image';
    final a = _assetArchive(settings);
    if (tone.texturePath != null) {
      final f = File(tone.texturePath!);
      if (!await f.exists()) throw const FormatException('Tone texture is missing');
      final b = await f.readAsBytes();
      final ext = tone.texturePath!.split('.').last;
      a.addFile(ArchiveFile('image.$ext', b.length, b));
    }
    return _createCard('tone', tone.name, _toZip(a));
  }

  static Future<File> exportStamp(StampService service, Stamp stamp) async {
    final settings = Map<String, dynamic>.from(stamp.toJson())
      ..['folderId'] = null
      ..['imagePath'] = stamp.imagePath == null ? null : 'image';
    final a = _assetArchive(settings);
    if (stamp.imagePath != null) {
      final f = File(stamp.imagePath!);
      if (!await f.exists()) throw const FormatException('Stamp image is missing');
      final b = await f.readAsBytes();
      final ext = stamp.imagePath!.split('.').last;
      a.addFile(ArchiveFile('image.$ext', b.length, b));
    }
    return _createCard('stamp', stamp.name, _toZip(a));
  }

  static Archive _assetArchive(Map<String, dynamic> model) {
    final json = utf8.encode(jsonEncode(model));
    return Archive()..addFile(ArchiveFile('data.json', json.length, json));
  }

  static Uint8List _toZip(Archive a) =>
      Uint8List.fromList(ZipEncoder().encode(a)!);

  /// The *only* public import entry: select one PNG card in the asset tab.
  static Future<void> pickAndImport(
    BuildContext context, {
    BrushService? brushService,
    ToneService? toneService,
    StampService? stampService,
  }) async {
    final expected = brushService != null
        ? 'brush'
        : toneService != null
            ? 'tone'
            : stampService != null
                ? 'stamp'
                : null;
    if (expected == null) return;
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png'],
    );
    if (pick == null || pick.files.isEmpty ||
        pick.files.first.path == null || !context.mounted) return;
    final selected = File(pick.files.first.path!);
    try {
      final card = await inspect(selected);
      if (card.kind != expected) {
        throw const FormatException('このカードは別の素材タブ用です');
      }
      if (!context.mounted) return;
      final kindName = switch (expected) {
        'brush' => 'ブラシ',
        'tone' => 'トーン',
        _ => 'スタンプ',
      };
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('$kindName を読み込みますか？'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Image.file(selected, height: 220, fit: BoxFit.contain),
              const SizedBox(height: 8),
              Text(card.name, maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('追加'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      await importCard(card,
        brushService: brushService,
        toneService: toneService,
        stampService: stampService,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$kindName「${card.name}」を追加しました')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('共有カードを読み込めませんでした: $error'),
        ));
      }
    }
  }

  static Future<SharedAssetCardPayload> inspect(File file) async {
    final bytes = await file.readAsBytes();
    final card = SharedAssetCardCodec.extract(bytes);
    // Check central-directory declared decompression sizes before ZipDecoder
    // allocates the unpacked data, rejecting ZIP bombs and path traversal.
    _validateZipEnvelope(card.data);
    final archive = ZipDecoder().decodeBytes(card.data);
    var total = 0;
    for (final entry in archive.files) {
      if (!entry.isFile) continue;
      if (entry.name.startsWith('/') || entry.name.contains('..') ||
          entry.name.contains('\\')) {
        throw const FormatException('Unsafe shared asset image name');
      }
      total += entry.size;
      if (total > SharedAssetCardCodec.maxAssetBytes) {
        throw const FormatException('Shared asset expands beyond the size limit');
      }
    }
    final settings = archive.findFile('data.json');
    if (settings == null) {
      throw const FormatException('Shared asset settings are missing');
    }
    final obj = jsonDecode(utf8.decode(settings.content as List<int>));
    if (obj is! Map<String, dynamic>) {
      throw const FormatException('Malformed shared asset settings');
    }
    final assetCount = archive.files.where((f) => f.isFile &&
      (f.name.startsWith('images/') || f.name.startsWith('image.'))).length;
    final declaredCount = card.kind == 'brush'
        ? (obj['customImagePaths'] is List
            ? (obj['customImagePaths'] as List).length
            : obj['customImagePath'] != null ? 1 : 0)
        : (obj[card.kind == 'tone' ? 'texturePath' : 'imagePath'] != null ? 1 : 0);
    if (assetCount != declaredCount) {
      throw const FormatException('Shared asset images are missing or inconsistent');
    }
    // Validate model types and required properties before any file is saved.
    switch (card.kind) {
      case 'brush':
        final b = Brush.fromJson(obj);
        if (!b.size.isFinite || b.size <= 0 || b.size > 200 ||
            b.opacity < 0 || b.opacity > 100) {
          throw const FormatException('Invalid shared brush parameters');
        }
      case 'tone':
        Tone.fromJson(obj);
      case 'stamp':
        final t = Stamp.fromJson(obj);
        if (!t.density.isFinite || !t.scatter.isFinite ||
            t.density <= 0 || t.density > 10 || t.scatter < 0 || t.scatter > 1) {
          throw const FormatException('Invalid shared stamp parameters');
        }
    }
    return card;
  }

  static void _validateZipEnvelope(Uint8List bytes) {
    const maxEntries = 18; // settings + up to 16 images (+ one spare)
    const maxExpanded = SharedAssetCardCodec.maxAssetBytes;
    if (bytes.length < 22 || bytes.length > maxExpanded) {
      throw const FormatException('Shared asset archive is too large');
    }
    final data = ByteData.sublistView(bytes);
    var eocd = -1;
    final min = bytes.length > 65557 ? bytes.length - 65557 : 0;
    for (var i = bytes.length - 22; i >= min; i--) {
      if (data.getUint32(i, Endian.little) == 0x06054b50 &&
          i + 22 + data.getUint16(i + 20, Endian.little) == bytes.length) {
        eocd = i;
        break;
      }
    }
    if (eocd < 0) throw const FormatException('Invalid ZIP directory');
    final count = data.getUint16(eocd + 10, Endian.little);
    final centralBytes = data.getUint32(eocd + 12, Endian.little);
    var cursor = data.getUint32(eocd + 16, Endian.little);
    if (count < 1 || count > maxEntries ||
        cursor >= eocd || centralBytes > eocd - cursor) {
      throw const FormatException('Invalid shared asset ZIP structure');
    }
    final names = <String>{};
    var expanded = 0;
    var imageCount = 0;
    for (var index = 0; index < count; index++) {
      if (cursor + 46 > eocd ||
          data.getUint32(cursor, Endian.little) != 0x02014b50) {
        throw const FormatException('Damaged shared asset ZIP directory');
      }
      final flags = data.getUint16(cursor + 8, Endian.little);
      final method = data.getUint16(cursor + 10, Endian.little);
      final rawSize = data.getUint32(cursor + 24, Endian.little);
      final fileNameLength = data.getUint16(cursor + 28, Endian.little);
      final extraLength = data.getUint16(cursor + 30, Endian.little);
      final commentLength = data.getUint16(cursor + 32, Endian.little);
      if ((flags & 1) != 0 || (method != 0 && method != 8) ||
          rawSize == 0xffffffff || rawSize > maxExpanded - expanded ||
          cursor + 46 + fileNameLength + extraLength + commentLength > eocd) {
        throw const FormatException('Invalid ZIP entry or uncompressed size');
      }
      final name = utf8.decode(Uint8List.sublistView(bytes,
          cursor + 46, cursor + 46 + fileNameLength));
      final isSource = RegExp(r'^images/[0-9]{3}\\.[A-Za-z0-9]{1,8}
    SharedAssetCardPayload card, {
    BrushService? brushService,
    ToneService? toneService,
    StampService? stampService,
  }) async {
    final expected = brushService != null
        ? 'brush'
        : toneService != null
            ? 'tone'
            : stampService != null
                ? 'stamp'
                : null;
    if (expected == null || card.kind != expected) {
      throw const FormatException('The selected card is for another asset tab');
    }
    // Callers invoking importCard directly must meet the same safety checks.
    _validateZipEnvelope(card.data);
    final dir = await getTemporaryDirectory();
    final suffix = card.kind == 'brush'
        ? 'niabrush'
        : card.kind == 'tone'
            ? 'niatone'
            : 'niastamp';
    final file = File('${dir.path}/.card-import-${DateTime.now().microsecondsSinceEpoch}.$suffix');
    try {
      // The internal temporary archive is never offered to the user.
      // Reuse the tested archive importer, then restore fields that older
      // tone/stamp importers historically dropped (tags and pattern key).
      await file.writeAsBytes(card.data, flush: true);
      final archive = ZipDecoder().decodeBytes(card.data);
      final dataFile = archive.findFile('data.json');
      if (dataFile == null) {
        throw const FormatException('Shared asset settings are missing');
      }
      final data = jsonDecode(utf8.decode(dataFile.content as List<int>));
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Invalid shared asset settings');
      }
      if (brushService != null) {
        final original = Brush.fromJson(data);
        final names = {for (final b in brushService.brushes) b.name};
        final imported = await brushService.importBrushFile(file.path);
        brushService.updateBrush(imported.copyWith(
          name: _uniqueName(original.name, names),
          isFavorite: false,
          tags: original.tags,
        ));
        brushService.selectBrush(imported.id);
      } else if (toneService != null) {
        final original = Tone.fromJson(data);
        final names = {for (final t in toneService.tones) t.name};
        final imported = await toneService.importToneFile(file.path);
        toneService.updateTone(imported.copyWith(
          name: _uniqueName(original.name, names),
          patternName: original.patternName,
          isFavorite: false,
          tags: original.tags,
        ));
        toneService.selectTone(imported.id);
      } else {
        final original = Stamp.fromJson(data);
        final stamps = stampService!;
        final names = {for (final t in stamps.stamps) t.name};
        final imported = await stamps.importStampFile(file.path);
        stamps.updateStamp(imported.copyWith(
          name: _uniqueName(original.name, names),
          isFavorite: false,
          tags: original.tags,
        ));
        stamps.selectStamp(imported.id);
      }
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  static String _uniqueName(String original, Set<String> existing) {
    if (!existing.contains(original)) return original;
    var number = 2;
    while (existing.contains('$original ($number)')) {
      number++;
    }
    return '$original ($number)';
  }

  static Future<File> _createCard(
      String kind, String name, Uint8List originalArchive) async {
    if (originalArchive.isEmpty ||
        originalArchive.length > SharedAssetCardCodec.maxAssetBytes) {
      throw const FormatException('Shared asset file is too large');
    }
    final digest = sha256.convert(originalArchive).toString();
    final rendered = await _renderCard(kind, name, originalArchive, digest);
    final cardBytes = SharedAssetCardCodec.embed(
      png: rendered, kind: kind, name: name, data: originalArchive,
    );
    final check = SharedAssetCardCodec.extract(cardBytes);
    if (check.digest != digest) {
      throw const StateError('Shared asset card failed its own verification');
    }
    final outDir = await getApplicationDocumentsDirectory();
    final safeName = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_');
    final short = digest.substring(0, 12);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final out = File('${outDir.path}/${safeName.isEmpty ? kind : safeName}-$short-$stamp.png');
    await out.writeAsBytes(cardBytes, flush: true);
    return out;
  }

  static Future<Uint8List> _renderCard(
    String kind,
    String name,
    Uint8List originalArchive,
    String digest,
  ) async {
    const width = 1200;
    const height = 1600;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 1200, 1600));
    final bg = Paint()..color = const Color(0xfff6f7fa);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 1200, 1600), bg);
    final paper = Paint()..color = Colors.white;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(46, 46, 1108, 1510), const Radius.circular(26)), paper);
    final pink = Paint()..color = const Color(0xffed5475);
    canvas.drawRect(const Rect.fromLTWH(46, 46, 1108, 12), pink);
    void label(String text, double x, double y, double size, Color color,
        {FontWeight weight = FontWeight.normal, double maxWidth = 1040}) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: TextStyle(
          fontFamily: 'NotoSerifJP', fontSize: size, color: color,
          fontWeight: weight,
        )),
        textDirection: TextDirection.ltr,
        maxLines: 3,
        ellipsis: '…',
      );
      tp.layout(maxWidth: maxWidth);
      tp.paint(canvas, Offset(x, y));
    }
    final displayKind = switch (kind) {
      'brush' => 'ブラシ',
      'tone' => 'トーン',
      _ => 'スタンプ',
    };
    label('NIARIM  /  $displayKind', 90, 98, 44, const Color(0xff343c55), weight: FontWeight.bold);
    label(name, 90, 177, 55, const Color(0xff171d30), weight: FontWeight.bold);
    label('素材の見本・使用画像', 90, 295, 31, const Color(0xff5d687b));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(87, 355, 1025, 500), const Radius.circular(15)), Paint()..color = const Color(0xffe6eaf1));

    final images = <ui.Image>[];
    final archive = ZipDecoder().decodeBytes(originalArchive);
    for (final entry in archive.files) {
      if (!entry.isFile || !entry.name.startsWith('images/') && !entry.name.startsWith('image.')) continue;
      if (images.length == 4) break;
      try {
        final data = entry.content as List<int>;
        final codec = await ui.instantiateImageCodec(Uint8List.fromList(data));
        final frame = await codec.getNextFrame();
        codec.dispose();
        images.add(frame.image);
      } catch (_) {
        // Visible preview decoding is best effort; binary payload remains
        // original. Import verification is performed independently.
      }
    }
    if (images.isNotEmpty) {
      final main = images.first;
      final sx = main.width.toDouble(), sy = main.height.toDouble();
      final sc = [920 / sx, 405 / sy].reduce((a,b)=>a<b?a:b);
      final w = sx * sc, h = sy * sc;
      canvas.drawImageRect(main, Rect.fromLTWH(0, 0, sx, sy),
          Rect.fromLTWH(600 - w/2, 605 - h/2, w, h), Paint()..filterQuality = FilterQuality.medium);
      label('オリジナル画像 ${images.length}枚${archive.files.where((e) => e.name.startsWith('images/')).length > images.length ? '（一部表示）' : ''}', 105, 808, 22, const Color(0xff445068));
    } else {
      // Procedural brush/tone/stamp: all editable parameters still travel in
      // the hidden original-archive payload; this label is not a fake stroke.
      label('内蔵パターン / 設定で生成', 280, 565, 37, const Color(0xff4e5b6d));
      label('外部の使用画像はありません', 310, 627, 24, const Color(0xff68758a));
    }
    label('完全共有カード', 90, 927, 38, const Color(0xff171d30), weight: FontWeight.bold);
    label('この画像をNIARIMの「読込」から選ぶと、設定と使用画像を復元できます。', 90, 998, 25, const Color(0xff4a566a), maxWidth: 1000);
    // QR is an identifying marker, not a standalone lightweight share mode.
    final qr = QrPainter(
      data: 'NIARIM:ASSET-CARD:1:$kind:${digest.substring(0,24)}',
      version: QrVersions.auto,
      color: Colors.black,
      emptyColor: Colors.white,
      gapless: true,
    );
    canvas.save();
    canvas.translate(120, 1117);
    qr.paint(canvas, const Size(310, 310));
    canvas.restore();
    label('QRはカードの識別用です', 505, 1160, 28, const Color(0xff454e62));
    label('単独のQRでは素材を復元できません', 505, 1215, 24, const Color(0xff6b7488));
    label('NIARIM ASSET CARD v1', 505, 1355, 30, const Color(0xff3d455b), weight: FontWeight.bold);
    label('ID: ${digest.substring(0, 24)}', 505, 1415, 23, const Color(0xff657083));

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw const FormatException('Could not encode asset card image');
      return bytes.buffer.asUint8List();
    } finally {
      image.dispose();
      for (final loaded in images) loaded.dispose();
    }
  }
}).hasMatch(name) ||
          RegExp(r'^image\\.[A-Za-z0-9]{1,8}
    SharedAssetCardPayload card, {
    BrushService? brushService,
    ToneService? toneService,
    StampService? stampService,
  }) async {
    final expected = brushService != null
        ? 'brush'
        : toneService != null
            ? 'tone'
            : stampService != null
                ? 'stamp'
                : null;
    if (expected == null || card.kind != expected) {
      throw const FormatException('The selected card is for another asset tab');
    }
    // Callers invoking importCard directly must meet the same safety checks.
    _validateZipEnvelope(card.data);
    final dir = await getTemporaryDirectory();
    final suffix = card.kind == 'brush'
        ? 'niabrush'
        : card.kind == 'tone'
            ? 'niatone'
            : 'niastamp';
    final file = File('${dir.path}/.card-import-${DateTime.now().microsecondsSinceEpoch}.$suffix');
    try {
      // The internal temporary archive is never offered to the user.
      // Reuse the tested archive importer, then restore fields that older
      // tone/stamp importers historically dropped (tags and pattern key).
      await file.writeAsBytes(card.data, flush: true);
      final archive = ZipDecoder().decodeBytes(card.data);
      final dataFile = archive.findFile('data.json');
      if (dataFile == null) {
        throw const FormatException('Shared asset settings are missing');
      }
      final data = jsonDecode(utf8.decode(dataFile.content as List<int>));
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Invalid shared asset settings');
      }
      if (brushService != null) {
        final original = Brush.fromJson(data);
        final names = {for (final b in brushService.brushes) b.name};
        final imported = await brushService.importBrushFile(file.path);
        brushService.updateBrush(imported.copyWith(
          name: _uniqueName(original.name, names),
          isFavorite: false,
          tags: original.tags,
        ));
        brushService.selectBrush(imported.id);
      } else if (toneService != null) {
        final original = Tone.fromJson(data);
        final names = {for (final t in toneService.tones) t.name};
        final imported = await toneService.importToneFile(file.path);
        toneService.updateTone(imported.copyWith(
          name: _uniqueName(original.name, names),
          patternName: original.patternName,
          isFavorite: false,
          tags: original.tags,
        ));
        toneService.selectTone(imported.id);
      } else {
        final original = Stamp.fromJson(data);
        final stamps = stampService!;
        final names = {for (final t in stamps.stamps) t.name};
        final imported = await stamps.importStampFile(file.path);
        stamps.updateStamp(imported.copyWith(
          name: _uniqueName(original.name, names),
          isFavorite: false,
          tags: original.tags,
        ));
        stamps.selectStamp(imported.id);
      }
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  static String _uniqueName(String original, Set<String> existing) {
    if (!existing.contains(original)) return original;
    var number = 2;
    while (existing.contains('$original ($number)')) {
      number++;
    }
    return '$original ($number)';
  }

  static Future<File> _createCard(
      String kind, String name, Uint8List originalArchive) async {
    if (originalArchive.isEmpty ||
        originalArchive.length > SharedAssetCardCodec.maxAssetBytes) {
      throw const FormatException('Shared asset file is too large');
    }
    final digest = sha256.convert(originalArchive).toString();
    final rendered = await _renderCard(kind, name, originalArchive, digest);
    final cardBytes = SharedAssetCardCodec.embed(
      png: rendered, kind: kind, name: name, data: originalArchive,
    );
    final check = SharedAssetCardCodec.extract(cardBytes);
    if (check.digest != digest) {
      throw const StateError('Shared asset card failed its own verification');
    }
    final outDir = await getApplicationDocumentsDirectory();
    final safeName = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_');
    final short = digest.substring(0, 12);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final out = File('${outDir.path}/${safeName.isEmpty ? kind : safeName}-$short-$stamp.png');
    await out.writeAsBytes(cardBytes, flush: true);
    return out;
  }

  static Future<Uint8List> _renderCard(
    String kind,
    String name,
    Uint8List originalArchive,
    String digest,
  ) async {
    const width = 1200;
    const height = 1600;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 1200, 1600));
    final bg = Paint()..color = const Color(0xfff6f7fa);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 1200, 1600), bg);
    final paper = Paint()..color = Colors.white;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(46, 46, 1108, 1510), const Radius.circular(26)), paper);
    final pink = Paint()..color = const Color(0xffed5475);
    canvas.drawRect(const Rect.fromLTWH(46, 46, 1108, 12), pink);
    void label(String text, double x, double y, double size, Color color,
        {FontWeight weight = FontWeight.normal, double maxWidth = 1040}) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: TextStyle(
          fontFamily: 'NotoSerifJP', fontSize: size, color: color,
          fontWeight: weight,
        )),
        textDirection: TextDirection.ltr,
        maxLines: 3,
        ellipsis: '…',
      );
      tp.layout(maxWidth: maxWidth);
      tp.paint(canvas, Offset(x, y));
    }
    final displayKind = switch (kind) {
      'brush' => 'ブラシ',
      'tone' => 'トーン',
      _ => 'スタンプ',
    };
    label('NIARIM  /  $displayKind', 90, 98, 44, const Color(0xff343c55), weight: FontWeight.bold);
    label(name, 90, 177, 55, const Color(0xff171d30), weight: FontWeight.bold);
    label('素材の見本・使用画像', 90, 295, 31, const Color(0xff5d687b));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(87, 355, 1025, 500), const Radius.circular(15)), Paint()..color = const Color(0xffe6eaf1));

    final images = <ui.Image>[];
    final archive = ZipDecoder().decodeBytes(originalArchive);
    for (final entry in archive.files) {
      if (!entry.isFile || !entry.name.startsWith('images/') && !entry.name.startsWith('image.')) continue;
      if (images.length == 4) break;
      try {
        final data = entry.content as List<int>;
        final codec = await ui.instantiateImageCodec(Uint8List.fromList(data));
        final frame = await codec.getNextFrame();
        codec.dispose();
        images.add(frame.image);
      } catch (_) {
        // Visible preview decoding is best effort; binary payload remains
        // original. Import verification is performed independently.
      }
    }
    if (images.isNotEmpty) {
      final main = images.first;
      final sx = main.width.toDouble(), sy = main.height.toDouble();
      final sc = [920 / sx, 405 / sy].reduce((a,b)=>a<b?a:b);
      final w = sx * sc, h = sy * sc;
      canvas.drawImageRect(main, Rect.fromLTWH(0, 0, sx, sy),
          Rect.fromLTWH(600 - w/2, 605 - h/2, w, h), Paint()..filterQuality = FilterQuality.medium);
      label('オリジナル画像 ${images.length}枚${archive.files.where((e) => e.name.startsWith('images/')).length > images.length ? '（一部表示）' : ''}', 105, 808, 22, const Color(0xff445068));
    } else {
      // Procedural brush/tone/stamp: all editable parameters still travel in
      // the hidden original-archive payload; this label is not a fake stroke.
      label('内蔵パターン / 設定で生成', 280, 565, 37, const Color(0xff4e5b6d));
      label('外部の使用画像はありません', 310, 627, 24, const Color(0xff68758a));
    }
    label('完全共有カード', 90, 927, 38, const Color(0xff171d30), weight: FontWeight.bold);
    label('この画像をNIARIMの「読込」から選ぶと、設定と使用画像を復元できます。', 90, 998, 25, const Color(0xff4a566a), maxWidth: 1000);
    // QR is an identifying marker, not a standalone lightweight share mode.
    final qr = QrPainter(
      data: 'NIARIM:ASSET-CARD:1:$kind:${digest.substring(0,24)}',
      version: QrVersions.auto,
      color: Colors.black,
      emptyColor: Colors.white,
      gapless: true,
    );
    canvas.save();
    canvas.translate(120, 1117);
    qr.paint(canvas, const Size(310, 310));
    canvas.restore();
    label('QRはカードの識別用です', 505, 1160, 28, const Color(0xff454e62));
    label('単独のQRでは素材を復元できません', 505, 1215, 24, const Color(0xff6b7488));
    label('NIARIM ASSET CARD v1', 505, 1355, 30, const Color(0xff3d455b), weight: FontWeight.bold);
    label('ID: ${digest.substring(0, 24)}', 505, 1415, 23, const Color(0xff657083));

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw const FormatException('Could not encode asset card image');
      return bytes.buffer.asUint8List();
    } finally {
      image.dispose();
      for (final loaded in images) loaded.dispose();
    }
  }
}).hasMatch(name);
      if (!names.add(name) || !(name == 'data.json' || isSource)) {
        throw const FormatException('Unsafe or duplicate shared asset file');
      }
      if (isSource) imageCount++;
      if (imageCount > 16) throw const FormatException('Too many source images');
      expanded += rawSize;
      cursor += 46 + fileNameLength + extraLength + commentLength;
    }
    if (!names.contains('data.json') ||
        cursor > eocd || cursor - data.getUint32(eocd + 16, Endian.little) != centralBytes) {
      throw const FormatException('Incomplete shared asset ZIP');
    }
  }

  static Future<void> importCard(
    SharedAssetCardPayload card, {
    BrushService? brushService,
    ToneService? toneService,
    StampService? stampService,
  }) async {
    final expected = brushService != null
        ? 'brush'
        : toneService != null
            ? 'tone'
            : stampService != null
                ? 'stamp'
                : null;
    if (expected == null || card.kind != expected) {
      throw const FormatException('The selected card is for another asset tab');
    }
    // Callers invoking importCard directly must meet the same safety checks.
    _validateZipEnvelope(card.data);
    final dir = await getTemporaryDirectory();
    final suffix = card.kind == 'brush'
        ? 'niabrush'
        : card.kind == 'tone'
            ? 'niatone'
            : 'niastamp';
    final file = File('${dir.path}/.card-import-${DateTime.now().microsecondsSinceEpoch}.$suffix');
    try {
      // The internal temporary archive is never offered to the user.
      // Reuse the tested archive importer, then restore fields that older
      // tone/stamp importers historically dropped (tags and pattern key).
      await file.writeAsBytes(card.data, flush: true);
      final archive = ZipDecoder().decodeBytes(card.data);
      final dataFile = archive.findFile('data.json');
      if (dataFile == null) {
        throw const FormatException('Shared asset settings are missing');
      }
      final data = jsonDecode(utf8.decode(dataFile.content as List<int>));
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Invalid shared asset settings');
      }
      if (brushService != null) {
        final original = Brush.fromJson(data);
        final names = {for (final b in brushService.brushes) b.name};
        final imported = await brushService.importBrushFile(file.path);
        brushService.updateBrush(imported.copyWith(
          name: _uniqueName(original.name, names),
          isFavorite: false,
          tags: original.tags,
        ));
        brushService.selectBrush(imported.id);
      } else if (toneService != null) {
        final original = Tone.fromJson(data);
        final names = {for (final t in toneService.tones) t.name};
        final imported = await toneService.importToneFile(file.path);
        toneService.updateTone(imported.copyWith(
          name: _uniqueName(original.name, names),
          patternName: original.patternName,
          isFavorite: false,
          tags: original.tags,
        ));
        toneService.selectTone(imported.id);
      } else {
        final original = Stamp.fromJson(data);
        final stamps = stampService!;
        final names = {for (final t in stamps.stamps) t.name};
        final imported = await stamps.importStampFile(file.path);
        stamps.updateStamp(imported.copyWith(
          name: _uniqueName(original.name, names),
          isFavorite: false,
          tags: original.tags,
        ));
        stamps.selectStamp(imported.id);
      }
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  static String _uniqueName(String original, Set<String> existing) {
    if (!existing.contains(original)) return original;
    var number = 2;
    while (existing.contains('$original ($number)')) {
      number++;
    }
    return '$original ($number)';
  }

  static Future<File> _createCard(
      String kind, String name, Uint8List originalArchive) async {
    if (originalArchive.isEmpty ||
        originalArchive.length > SharedAssetCardCodec.maxAssetBytes) {
      throw const FormatException('Shared asset file is too large');
    }
    final digest = sha256.convert(originalArchive).toString();
    final rendered = await _renderCard(kind, name, originalArchive, digest);
    final cardBytes = SharedAssetCardCodec.embed(
      png: rendered, kind: kind, name: name, data: originalArchive,
    );
    final check = SharedAssetCardCodec.extract(cardBytes);
    if (check.digest != digest) {
      throw const StateError('Shared asset card failed its own verification');
    }
    final outDir = await getApplicationDocumentsDirectory();
    final safeName = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_');
    final short = digest.substring(0, 12);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final out = File('${outDir.path}/${safeName.isEmpty ? kind : safeName}-$short-$stamp.png');
    await out.writeAsBytes(cardBytes, flush: true);
    return out;
  }

  static Future<Uint8List> _renderCard(
    String kind,
    String name,
    Uint8List originalArchive,
    String digest,
  ) async {
    const width = 1200;
    const height = 1600;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 1200, 1600));
    final bg = Paint()..color = const Color(0xfff6f7fa);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 1200, 1600), bg);
    final paper = Paint()..color = Colors.white;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(46, 46, 1108, 1510), const Radius.circular(26)), paper);
    final pink = Paint()..color = const Color(0xffed5475);
    canvas.drawRect(const Rect.fromLTWH(46, 46, 1108, 12), pink);
    void label(String text, double x, double y, double size, Color color,
        {FontWeight weight = FontWeight.normal, double maxWidth = 1040}) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: TextStyle(
          fontFamily: 'NotoSerifJP', fontSize: size, color: color,
          fontWeight: weight,
        )),
        textDirection: TextDirection.ltr,
        maxLines: 3,
        ellipsis: '…',
      );
      tp.layout(maxWidth: maxWidth);
      tp.paint(canvas, Offset(x, y));
    }
    final displayKind = switch (kind) {
      'brush' => 'ブラシ',
      'tone' => 'トーン',
      _ => 'スタンプ',
    };
    label('NIARIM  /  $displayKind', 90, 98, 44, const Color(0xff343c55), weight: FontWeight.bold);
    label(name, 90, 177, 55, const Color(0xff171d30), weight: FontWeight.bold);
    label('素材の見本・使用画像', 90, 295, 31, const Color(0xff5d687b));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(87, 355, 1025, 500), const Radius.circular(15)), Paint()..color = const Color(0xffe6eaf1));

    final images = <ui.Image>[];
    final archive = ZipDecoder().decodeBytes(originalArchive);
    for (final entry in archive.files) {
      if (!entry.isFile || !entry.name.startsWith('images/') && !entry.name.startsWith('image.')) continue;
      if (images.length == 4) break;
      try {
        final data = entry.content as List<int>;
        final codec = await ui.instantiateImageCodec(Uint8List.fromList(data));
        final frame = await codec.getNextFrame();
        codec.dispose();
        images.add(frame.image);
      } catch (_) {
        // Visible preview decoding is best effort; binary payload remains
        // original. Import verification is performed independently.
      }
    }
    if (images.isNotEmpty) {
      final main = images.first;
      final sx = main.width.toDouble(), sy = main.height.toDouble();
      final sc = [920 / sx, 405 / sy].reduce((a,b)=>a<b?a:b);
      final w = sx * sc, h = sy * sc;
      canvas.drawImageRect(main, Rect.fromLTWH(0, 0, sx, sy),
          Rect.fromLTWH(600 - w/2, 605 - h/2, w, h), Paint()..filterQuality = FilterQuality.medium);
      label('オリジナル画像 ${images.length}枚${archive.files.where((e) => e.name.startsWith('images/')).length > images.length ? '（一部表示）' : ''}', 105, 808, 22, const Color(0xff445068));
    } else {
      // Procedural brush/tone/stamp: all editable parameters still travel in
      // the hidden original-archive payload; this label is not a fake stroke.
      label('内蔵パターン / 設定で生成', 280, 565, 37, const Color(0xff4e5b6d));
      label('外部の使用画像はありません', 310, 627, 24, const Color(0xff68758a));
    }
    label('完全共有カード', 90, 927, 38, const Color(0xff171d30), weight: FontWeight.bold);
    label('この画像をNIARIMの「読込」から選ぶと、設定と使用画像を復元できます。', 90, 998, 25, const Color(0xff4a566a), maxWidth: 1000);
    // QR is an identifying marker, not a standalone lightweight share mode.
    final qr = QrPainter(
      data: 'NIARIM:ASSET-CARD:1:$kind:${digest.substring(0,24)}',
      version: QrVersions.auto,
      color: Colors.black,
      emptyColor: Colors.white,
      gapless: true,
    );
    canvas.save();
    canvas.translate(120, 1117);
    qr.paint(canvas, const Size(310, 310));
    canvas.restore();
    label('QRはカードの識別用です', 505, 1160, 28, const Color(0xff454e62));
    label('単独のQRでは素材を復元できません', 505, 1215, 24, const Color(0xff6b7488));
    label('NIARIM ASSET CARD v1', 505, 1355, 30, const Color(0xff3d455b), weight: FontWeight.bold);
    label('ID: ${digest.substring(0, 24)}', 505, 1415, 23, const Color(0xff657083));

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw const FormatException('Could not encode asset card image');
      return bytes.buffer.asUint8List();
    } finally {
      image.dispose();
      for (final loaded in images) loaded.dispose();
    }
  }
}