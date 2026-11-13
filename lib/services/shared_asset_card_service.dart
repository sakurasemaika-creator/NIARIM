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

import '../config/font_fallback.dart';
import '../l10n/app_localizations.dart';
import '../models/brush.dart';
import '../models/stamp.dart';
import '../models/tone.dart';
import 'brush_service.dart';
import 'stamp_service.dart';
import 'tone_service.dart';
import 'shared_asset_card_codec.dart';
import 'shared_asset_card_preview.dart';
import '../widgets/export_share_feedback.dart';

/// One public sharing format for brushes, tones and stamps: a complete PNG.
/// A ZIP is used only as an *in-memory* implementation of the compressed
/// model+original-image payload; users never select or share that container.
/// The picked card is for another asset list (brush, tone or stamp).
class _WrongCardKind implements Exception {
  const _WrongCardKind(this.kind);

  /// The card's own kind: 'brush', 'tone' or 'stamp'.
  final String kind;
}

class SharedAssetCardService {
  SharedAssetCardService._();

  static String exportMenuLabel(BuildContext context) =>
      AppLocalizations.of(context)!.shareCardExportMenu;

  /// The card is created once. Save-as writes the original PNG bytes to a
  /// user-selected location; Share uses the same original file unchanged.
  static Future<void> showExportResult(BuildContext context, File card) async {
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final action = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.shareCardCreatedTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.file(card, height: 310, fit: BoxFit.contain),
              const SizedBox(height: 12),
              Text(l10n.shareCardKeepOriginalNote),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(l10n.commonClose),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(dialog, 'save'),
            icon: const Icon(Icons.save_alt),
            label: Text(l10n.shareCardSaveToDevice),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialog, 'share'),
            icon: const Icon(Icons.share_outlined),
            label: Text(l10n.commonShare),
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
          dialogTitle: l10n.shareCardSaveDialogTitle,
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['png'],
          bytes: await card.readAsBytes(),
        );
        if (selected != null && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.shareCardSavedSnackbar)));
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.shareCardSaveFailedSnackbar('$error'))),
          );
        }
      }
    }
  }

  /// The card's texts are drawn in [l10n]'s language (the app language at the
  /// time the card is made).
  static Future<File> exportBrush(
    BrushService service,
    Brush brush, {
    required AppLocalizations l10n,
  }) async {
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
      a.addFile(
        ArchiveFile('images/${i.toString().padLeft(3, '0')}.$ext', b.length, b),
      );
    }
    return _createCard('brush', brush.name, _toZip(a), l10n);
  }

  static Future<File> exportTone(
    ToneService service,
    Tone tone, {
    required AppLocalizations l10n,
  }) async {
    final settings = Map<String, dynamic>.from(tone.toJson())
      ..['folderId'] = null
      ..['texturePath'] = tone.texturePath == null ? null : 'image';
    final a = _assetArchive(settings);
    if (tone.texturePath != null) {
      final f = File(tone.texturePath!);
      if (!await f.exists()) {
        throw const FormatException('Tone texture is missing');
      }
      final b = await f.readAsBytes();
      final ext = tone.texturePath!.split('.').last;
      a.addFile(ArchiveFile('image.$ext', b.length, b));
    }
    return _createCard('tone', tone.name, _toZip(a), l10n);
  }

  static Future<File> exportStamp(
    StampService service,
    Stamp stamp, {
    required AppLocalizations l10n,
  }) async {
    final settings = Map<String, dynamic>.from(stamp.toJson())
      ..['folderId'] = null
      ..['imagePath'] = stamp.imagePath == null ? null : 'image';
    final a = _assetArchive(settings);
    if (stamp.imagePath != null) {
      final f = File(stamp.imagePath!);
      if (!await f.exists()) {
        throw const FormatException('Stamp image is missing');
      }
      final b = await f.readAsBytes();
      final ext = stamp.imagePath!.split('.').last;
      a.addFile(ArchiveFile('image.$ext', b.length, b));
    }
    return _createCard('stamp', stamp.name, _toZip(a), l10n);
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
    if (pick == null ||
        pick.files.isEmpty ||
        pick.files.first.path == null ||
        !context.mounted) {
      return;
    }
    final selected = File(pick.files.first.path!);
    final l10n = AppLocalizations.of(context)!;
    try {
      final card = await inspect(selected);
      if (card.kind != expected) {
        throw _WrongCardKind(card.kind);
      }
      if (!context.mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.shareCardImportConfirmTitle(expected)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.file(selected, height: 220, fit: BoxFit.contain),
                const SizedBox(height: 8),
                Text(card.name, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.commonAdd),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      await importCard(
        card,
        brushService: brushService,
        toneService: toneService,
        stampService: stampService,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.shareCardAddedSnackbar(expected, card.name)),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is _WrongCardKind
                  ? l10n.shareCardWrongKind(error.kind)
                  : l10n.shareCardImportFailedSnackbar('$error'),
            ),
          ),
        );
      }
    }
  }

  static Future<SharedAssetCardPayload> inspect(File file) async {
    final bytes = await file.readAsBytes();
    final card = SharedAssetCardCodec.extract(bytes);
    // Validate ZIP sizes and paths before expanding the archive.
    _validateZipEnvelope(card.data);
    final archive = ZipDecoder().decodeBytes(card.data);
    var total = 0;
    for (final entry in archive.files) {
      if (!entry.isFile) continue;
      if (entry.name.startsWith('/') ||
          entry.name.contains('..') ||
          entry.name.contains('\\')) {
        throw const FormatException('Unsafe shared asset image name');
      }
      total += entry.size;
      if (total > SharedAssetCardCodec.maxAssetBytes) {
        throw const FormatException(
          'Shared asset expands beyond the size limit',
        );
      }
    }
    final settings = archive.findFile('data.json');
    if (settings == null) {
      throw const FormatException('Shared asset settings are missing');
    }
    final obj = jsonDecode(utf8.decode(settings.content as List<int>));
    if (obj is! Map<String, dynamic>) {
      throw const FormatException('Invalid shared asset settings');
    }
    final sourceFiles = archive.files
        .where(
          (f) =>
              f.isFile &&
              (f.name.startsWith('images/') || f.name.startsWith('image.')),
        )
        .length;
    final expectedCount = card.kind == 'brush'
        ? (obj['customImagePaths'] is List
              ? (obj['customImagePaths'] as List).length
              : obj['customImagePath'] != null
              ? 1
              : 0)
        : (obj[card.kind == 'tone' ? 'texturePath' : 'imagePath'] != null
              ? 1
              : 0);
    if (sourceFiles != expectedCount) {
      throw const FormatException('Source images missing from share card');
    }
    switch (card.kind) {
      case 'brush':
        final brush = Brush.fromJson(obj);
        if (!brush.size.isFinite || brush.size <= 0 || brush.size > 200) {
          throw const FormatException('Invalid brush size');
        }
        break;
      case 'tone':
        Tone.fromJson(obj);
        break;
      case 'stamp':
        final stamp = Stamp.fromJson(obj);
        if (!stamp.density.isFinite ||
            !stamp.scatter.isFinite ||
            stamp.density <= 0 ||
            stamp.density > 10 ||
            stamp.scatter < 0 ||
            stamp.scatter > 1) {
          throw const FormatException('Invalid stamp parameters');
        }
        break;
    }
    return card;
  }

  static void _validateZipEnvelope(Uint8List bytes) {
    const maxEntries = 18;
    const maxExpanded = SharedAssetCardCodec.maxAssetBytes;
    if (bytes.length < 22 || bytes.length > maxExpanded) {
      throw const FormatException('Oversized or invalid shared ZIP data');
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
    if (eocd < 0) throw const FormatException('Missing ZIP directory');
    final count = data.getUint16(eocd + 10, Endian.little);
    final centralSize = data.getUint32(eocd + 12, Endian.little);
    final centralStart = data.getUint32(eocd + 16, Endian.little);
    var cursor = centralStart;
    if (count < 1 ||
        count > maxEntries ||
        centralStart >= eocd ||
        centralSize > eocd - centralStart) {
      throw const FormatException('Invalid ZIP central directory');
    }
    final names = <String>{};
    var expanded = 0;
    var images = 0;
    for (var index = 0; index < count; index++) {
      if (cursor + 46 > eocd ||
          data.getUint32(cursor, Endian.little) != 0x02014b50) {
        throw const FormatException('Invalid ZIP file header');
      }
      final flags = data.getUint16(cursor + 8, Endian.little);
      final method = data.getUint16(cursor + 10, Endian.little);
      final size = data.getUint32(cursor + 24, Endian.little);
      final length = data.getUint16(cursor + 28, Endian.little);
      final extra = data.getUint16(cursor + 30, Endian.little);
      final comment = data.getUint16(cursor + 32, Endian.little);
      if ((flags & 1) != 0 ||
          (method != 0 && method != 8) ||
          size == 0xffffffff ||
          size > maxExpanded - expanded ||
          cursor + 46 + length + extra + comment > eocd) {
        throw const FormatException('Unsafe ZIP compression or entry size');
      }
      final name = utf8.decode(
        Uint8List.sublistView(bytes, cursor + 46, cursor + 46 + length),
      );
      final isImage =
          RegExp(r'^images/[0-9]{3}\.[A-Za-z0-9]{1,8}$').hasMatch(name) ||
          RegExp(r'^image\.[A-Za-z0-9]{1,8}$').hasMatch(name);
      if (!names.add(name) || !(name == 'data.json' || isImage)) {
        throw const FormatException('Unexpected or duplicated archive path');
      }
      if (isImage) images++;
      if (images > 16) throw const FormatException('Too many source images');
      expanded += size;
      cursor += 46 + length + extra + comment;
    }
    if (!names.contains('data.json') || cursor - centralStart != centralSize) {
      throw const FormatException('Incomplete asset ZIP');
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
    _validateZipEnvelope(card.data);
    final dir = await getTemporaryDirectory();
    final suffix = card.kind == 'brush'
        ? 'niabrush'
        : card.kind == 'tone'
        ? 'niatone'
        : 'niastamp';
    final file = File(
      '${dir.path}/.card-import-${DateTime.now().microsecondsSinceEpoch}.$suffix',
    );
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
        brushService.updateBrush(
          imported.copyWith(
            name: _uniqueName(original.name, names),
            isFavorite: false,
            tags: original.tags,
          ),
        );
        brushService.selectBrush(imported.id);
      } else if (toneService != null) {
        final original = Tone.fromJson(data);
        final names = {for (final t in toneService.tones) t.name};
        final imported = await toneService.importToneFile(file.path);
        toneService.updateTone(
          imported.copyWith(
            name: _uniqueName(original.name, names),
            patternName: original.patternName,
            isFavorite: false,
            tags: original.tags,
          ),
        );
        toneService.selectTone(imported.id);
      } else {
        final original = Stamp.fromJson(data);
        final stamps = stampService!;
        final names = {for (final t in stamps.stamps) t.name};
        final imported = await stamps.importStampFile(file.path);
        stamps.updateStamp(
          imported.copyWith(
            name: _uniqueName(original.name, names),
            isFavorite: false,
            tags: original.tags,
          ),
        );
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
    String kind,
    String name,
    Uint8List originalArchive,
    AppLocalizations l10n,
  ) async {
    if (originalArchive.isEmpty ||
        originalArchive.length > SharedAssetCardCodec.maxAssetBytes) {
      throw const FormatException('Shared asset file is too large');
    }
    _validateZipEnvelope(originalArchive);
    final digest = sha256.convert(originalArchive).toString();
    final rendered = await _renderCard(
      kind,
      name,
      originalArchive,
      digest,
      l10n,
    );
    final cardBytes = SharedAssetCardCodec.embed(
      png: rendered,
      kind: kind,
      name: name,
      data: originalArchive,
    );
    final check = SharedAssetCardCodec.extract(cardBytes);
    if (check.digest != digest) {
      throw StateError('Shared asset card failed its own verification');
    }
    final outDir = await getApplicationDocumentsDirectory();
    final safeName = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_');
    final short = digest.substring(0, 12);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final out = File(
      '${outDir.path}/${safeName.isEmpty ? kind : safeName}-$short-$stamp.png',
    );
    try {
      await out.writeAsBytes(cardBytes, flush: true);
      await inspect(out); // Verify the exact file the recipient will import.
      return out;
    } catch (_) {
      if (await out.exists()) await out.delete();
      rethrow;
    }
  }

  static Future<Uint8List> _renderCard(
    String kind,
    String name,
    Uint8List originalArchive,
    String digest,
    AppLocalizations l10n,
  ) async {
    const width = 1200;
    const height = 1600;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 1200, 1600));
    final bg = Paint()..color = const Color(0xfff6f7fa);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 1200, 1600), bg);
    final paper = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(46, 46, 1108, 1510),
        const Radius.circular(26),
      ),
      paper,
    );
    final pink = Paint()..color = const Color(0xffed5475);
    canvas.drawRect(const Rect.fromLTWH(46, 46, 1108, 12), pink);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(87, 355, 1025, 450),
        const Radius.circular(15),
      ),
      Paint()..color = const Color(0xffe6eaf1),
    );

    final images = <ui.Image>[];
    var strokeRendered = false;
    final archive = ZipDecoder().decodeBytes(originalArchive);
    final sourceEntries = archive.files
        .where(
          (entry) =>
              entry.isFile &&
              (entry.name.startsWith('images/') ||
                  entry.name.startsWith('image.')),
        )
        .toList();
    // Decode every source before offering the exported file. Missing or
    // corrupt images must never create a misleading "complete" card.
    for (final entry in sourceEntries) {
      final data = entry.content as List<int>;
      final codec = await ui.instantiateImageCodec(Uint8List.fromList(data));
      try {
        final frame = await codec.getNextFrame();
        if (frame.image.width > 4096 || frame.image.height > 4096) {
          frame.image.dispose();
          throw const FormatException('Source image exceeds 4096px');
        }
        if (images.length < 4) {
          images.add(frame.image);
        } else {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    }
    if (images.isNotEmpty) {
      // Original bytes are in the PNG payload; shown thumbnails are visual only.
      final main = images.first;
      final sx = main.width.toDouble();
      final sy = main.height.toDouble();
      final scale = [920 / sx, 310 / sy].reduce((a, b) => a < b ? a : b);
      final w = sx * scale;
      final h = sy * scale;
      canvas.drawImageRect(
        main,
        Rect.fromLTWH(0, 0, sx, sy),
        Rect.fromLTWH(600 - w / 2, 550 - h / 2, w, h),
        Paint()..filterQuality = FilterQuality.medium,
      );
      for (var i = 0; i < images.length; i++) {
        final source = images[i];
        const boxSize = 68.0;
        final dw = source.width.toDouble();
        final dh = source.height.toDouble();
        final small = [
          boxSize / dw,
          boxSize / dh,
        ].reduce((a, b) => a < b ? a : b);
        final x = 104 + i * 105.0;
        final y = 821.0;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x - 3, y - 3, boxSize + 6, boxSize + 6),
            const Radius.circular(6),
          ),
          Paint()..color = const Color(0xffedf0f4),
        );
        canvas.drawImageRect(
          source,
          Rect.fromLTWH(0, 0, dw, dh),
          Rect.fromLTWH(
            x + (boxSize - dw * small) / 2,
            y + (boxSize - dh * small) / 2,
            dw * small,
            dh * small,
          ),
          Paint()..filterQuality = FilterQuality.medium,
        );
      }
    } else {
      // Render a genuine stroke using the very same raster engines as the
      // live pen sub-tool panel; parameters are never approximated by a
      // hand-drawn line when a source image is not attached.
      final settings = archive.findFile('data.json');
      var rendered = false;
      if (settings != null) {
        try {
          final data = jsonDecode(utf8.decode(settings.content as List<int>));
          if (data is Map<String, dynamic>) {
            final sample = await SharedAssetCardPreview.render(kind, data);
            try {
              canvas.drawImageRect(
                sample,
                Rect.fromLTWH(
                  0,
                  0,
                  sample.width.toDouble(),
                  sample.height.toDouble(),
                ),
                const Rect.fromLTWH(120, 470, 960, 192),
                Paint()..filterQuality = FilterQuality.medium,
              );
              rendered = true;
            } finally {
              sample.dispose();
            }
          }
        } catch (_) {
          // Settings are independently validated when importing this card.
        }
      }
      strokeRendered = rendered;
    }
    // QR is an identifying marker, not a standalone lightweight share mode.
    final qr = QrPainter(
      data: 'NIARIM:ASSET-CARD:1:$kind:${digest.substring(0, 24)}',
      version: QrVersions.auto,
      // Drawn on the white paper, so no background of its own is needed.
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Colors.black,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Colors.black,
      ),
      gapless: true,
    );
    canvas.save();
    canvas.translate(120, 1117);
    qr.paint(canvas, const Size(310, 310));
    canvas.restore();
    // Every text on the card, fitted into its box in the card's language.
    for (final block in _cardTexts(
      l10n,
      kind: kind,
      name: name,
      sourceImageCount: sourceEntries.length,
      shownImageCount: images.length,
      strokeRendered: strokeRendered,
      digest: digest,
    )) {
      final fitted = block.fit(l10n);
      try {
        fitted.painter.paint(canvas, fitted.offset);
      } finally {
        fitted.painter.dispose();
      }
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        throw const FormatException('Could not encode asset card image');
      }
      return bytes.buffer.asUint8List();
    } finally {
      image.dispose();
      for (final loaded in images) {
        loaded.dispose();
      }
    }
  }

  /// The texts drawn on a card, each fitted into its box (for tests: every
  /// label must fit in every language without being cut off).
  @visibleForTesting
  static List<SharedAssetCardTextLayout> debugCardTextLayout(
    AppLocalizations l10n, {
    required String kind,
    required String name,
    required int sourceImageCount,
    bool strokeRendered = true,
  }) => [
    for (final block in _cardTexts(
      l10n,
      kind: kind,
      name: name,
      sourceImageCount: sourceImageCount,
      shownImageCount: sourceImageCount.clamp(0, 4),
      strokeRendered: strokeRendered,
      digest: '0' * 64,
    ))
      block.layoutOnly(l10n),
  ];

  /// Every text block of the card in [l10n]'s language. Boxes are in card
  /// pixels (1200 × 1600); a block shrinks its type, down to its minimum, to
  /// stay inside its box rather than being cut off.
  static List<_CardText> _cardTexts(
    AppLocalizations l10n, {
    required String kind,
    required String name,
    required int sourceImageCount,
    required int shownImageCount,
    required bool strokeRendered,
    required String digest,
  }) {
    final kindLabel = switch (kind) {
      'brush' => l10n.penSubToolTabBrush,
      'tone' => l10n.penSubToolTabTone,
      _ => l10n.penSubToolTabStamp,
    };
    return [
      _CardText(
        'NIARIM  /  $kindLabel',
        const Rect.fromLTWH(90, 92, 1020, 64),
        44,
        30,
        const Color(0xff343c55),
        bold: true,
      ),
      // The asset's own name is the user's text: it may end with an
      // ellipsis after shrinking to the minimum (two lines).
      _CardText(
        name,
        const Rect.fromLTWH(90, 166, 1020, 120),
        55,
        32,
        const Color(0xff171d30),
        bold: true,
        userText: true,
      ),
      _CardText(
        l10n.shareCardSampleHeading,
        const Rect.fromLTWH(90, 292, 1020, 52),
        31,
        22,
        const Color(0xff5d687b),
      ),
      if (sourceImageCount > 0)
        _CardText(
          sourceImageCount > shownImageCount
              ? l10n.shareCardSourceImageCountFirst(
                  sourceImageCount,
                  shownImageCount,
                )
              : l10n.shareCardSourceImageCount(sourceImageCount),
          const Rect.fromLTWH(105, 772, 990, 34),
          22,
          15,
          const Color(0xff445068),
        )
      else ...[
        _CardText(
          strokeRendered
              ? l10n.shareCardStrokeSample
              : l10n.shareCardBuiltInPattern,
          const Rect.fromLTWH(120, 690, 960, 48),
          28,
          18,
          const Color(0xff4e5b6d),
          center: true,
        ),
        _CardText(
          l10n.shareCardNoSourceImages,
          const Rect.fromLTWH(120, 742, 960, 42),
          22,
          15,
          const Color(0xff68758a),
          center: true,
        ),
      ],
      _CardText(
        l10n.shareCardCompleteTitle,
        const Rect.fromLTWH(90, 920, 1020, 62),
        38,
        26,
        const Color(0xff171d30),
        bold: true,
      ),
      _CardText(
        l10n.shareCardRestoreHint(l10n.creativePanelImportButton),
        const Rect.fromLTWH(90, 990, 1020, 112),
        25,
        17,
        const Color(0xff4a566a),
      ),
      _CardText(
        l10n.shareCardQrNote,
        const Rect.fromLTWH(505, 1142, 610, 98),
        28,
        18,
        const Color(0xff454e62),
      ),
      _CardText(
        l10n.shareCardQrCannotRestore,
        const Rect.fromLTWH(505, 1246, 610, 94),
        24,
        16,
        const Color(0xff6b7488),
      ),
      // The format marker and the identifier are the same in every language.
      _CardText(
        'NIARIM ASSET CARD v1',
        const Rect.fromLTWH(505, 1352, 610, 50),
        30,
        20,
        const Color(0xff3d455b),
        bold: true,
      ),
      _CardText(
        'ID: ${digest.substring(0, 24)}',
        const Rect.fromLTWH(505, 1412, 610, 40),
        23,
        16,
        const Color(0xff657083),
      ),
    ];
  }
}

/// Where and how large a card text ended up (see
/// [SharedAssetCardService.debugCardTextLayout]).
@visibleForTesting
class SharedAssetCardTextLayout {
  const SharedAssetCardTextLayout({
    required this.text,
    required this.box,
    required this.fontSize,
    required this.size,
    required this.fits,
    required this.userText,
  });

  final String text;

  /// The box the text must stay inside, in card pixels.
  final Rect box;
  final double fontSize;

  /// The laid-out size of the text.
  final Size size;

  /// Whether the whole text is drawn inside [box] (no ellipsis).
  final bool fits;

  /// The asset's own name (may be shortened with an ellipsis).
  final bool userText;
}

class _CardText {
  const _CardText(
    this.text,
    this.box,
    this.fontSize,
    this.minFontSize,
    this.color, {
    this.bold = false,
    this.center = false,
    this.userText = false,
  });

  final String text;
  final Rect box;
  final double fontSize;
  final double minFontSize;
  final Color color;
  final bool bold;
  final bool center;
  final bool userText;

  static Locale _localeOf(AppLocalizations l10n) {
    final parts = l10n.localeName.split('_');
    return parts.length > 1 && parts[1].length == 4
        ? Locale.fromSubtags(languageCode: parts[0], scriptCode: parts[1])
        : Locale(parts.first);
  }

  TextPainter _painter(AppLocalizations l10n, double size, {int? maxLines}) =>
      TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: 'NotoSerifJP',
            // Hangul and simplified Chinese come from the bundled subsets.
            fontFamilyFallback: kBodyFontFallback,
            fontSize: size,
            color: color,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textAlign: center ? TextAlign.center : TextAlign.start,
        textDirection: TextDirection.ltr,
        locale: _localeOf(l10n),
        maxLines: maxLines,
        ellipsis: maxLines == null ? null : '…',
      )..layout(maxWidth: box.width);

  /// Lays the text out at the largest size, from [fontSize] down to
  /// [minFontSize], at which it fits in [box]. Only the user's own name is
  /// ever shortened (with an ellipsis) when even the minimum does not fit.
  ({TextPainter painter, Offset offset, double size, bool fits}) fit(
    AppLocalizations l10n,
  ) {
    var size = fontSize;
    while (true) {
      final painter = _painter(l10n, size);
      if (painter.height <= box.height + 0.5) {
        return (
          painter: painter,
          offset: Offset(
            center ? box.left + (box.width - painter.width) / 2 : box.left,
            box.top,
          ),
          size: size,
          fits: true,
        );
      }
      if (size <= minFontSize) {
        final lines = painter.computeLineMetrics();
        final lineHeight = lines.isEmpty ? size : lines.first.height;
        painter.dispose();
        final shortened = _painter(
          l10n,
          size,
          maxLines: (box.height / lineHeight).floor().clamp(1, 3),
        );
        return (
          painter: shortened,
          offset: Offset(box.left, box.top),
          size: size,
          fits: false,
        );
      }
      painter.dispose();
      size = (size * 0.94).clamp(minFontSize, fontSize);
    }
  }

  SharedAssetCardTextLayout layoutOnly(AppLocalizations l10n) {
    final fitted = fit(l10n);
    final result = SharedAssetCardTextLayout(
      text: text,
      box: box,
      fontSize: fitted.size,
      size: fitted.painter.size,
      fits: fitted.fits && !fitted.painter.didExceedMaxLines,
      userText: userText,
    );
    fitted.painter.dispose();
    return result;
  }
}
