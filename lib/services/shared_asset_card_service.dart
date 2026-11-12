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

/// One public sharing format for brushes, tones and stamps: a complete PNG.
/// A ZIP is used only as an *in-memory* implementation of the compressed
/// model+original-image payload; users never select or share that container.
class SharedAssetCardService {
  SharedAssetCardService._();

  static Future<File> exportBrush(BrushService service, Brush brush) async {
    final a = _assetArchive(brush.toJson());
    final paths = brush.resolvedCustomImagePaths;
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
    final a = _assetArchive(tone.toJson());
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
    final a = _assetArchive(stamp.toJson());
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
    // Decode ZIP only after the bounded PNG parser and digest succeeded.
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
    if (archive.findFile('data.json') == null) {
      throw const FormatException('Shared asset settings are missing');
    }
    return card;
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
    final dir = await getTemporaryDirectory();
    final suffix = card.kind == 'brush'
        ? 'niabrush'
        : card.kind == 'tone'
            ? 'niatone'
            : 'niastamp';
    final file = File('${dir.path}/.card-import-${DateTime.now().microsecondsSinceEpoch}.$suffix');
    try {
      await file.writeAsBytes(card.data, flush: true);
      if (brushService != null) {
        await brushService.importBrushFile(file.path);
      } else if (toneService != null) {
        await toneService.importToneFile(file.path);
      } else {
        await stampService!.importStampFile(file.path);
      }
    } finally {
      if (await file.exists()) await file.delete();
    }
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