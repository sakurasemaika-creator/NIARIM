import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/stamp.dart';
import 'package:niarim/models/tone.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/stamp_service.dart';
import 'package:niarim/services/tone_service.dart';
import 'package:niarim/services/shared_asset_card_codec.dart';
import 'package:niarim/services/shared_asset_card_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PNG card round-trips three asset kinds, source images, and tags', () async {
    SharedPreferences.setMockInitialValues({});
    final directory = Directory.systemTemp.createTempSync('niarim-share-card-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    final pixels = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4////fwAJ+wP9KobjigAAAABJRU5ErkJggg==');
    final screenshots = Directory('build/shared-asset-card-captures')..createSync(recursive: true);
    final originalImage = File('${directory.path}/source.png');
    await originalImage.writeAsBytes(pixels);

    final brushes = BrushService();
    await brushes.init();
    final base = brushes.brushes.first;
    final custom = base.copyWith(
      id: 'outside-custom-brush',
      name: '共有テスト・ブラシ',
      customImagePath: originalImage.path,
      customImagePaths: [originalImage.path],
      isFavorite: true,
      tags: ['my tag'],
    );
    brushes.addBrush(custom);
    final brushPng = await SharedAssetCardService.exportBrush(brushes, custom);
    expect(brushPng.path, endsWith('.png'));
    await brushPng.copy('${screenshots.path}/brush_complete_share_card.png');
    final brushCard = await SharedAssetCardService.inspect(brushPng);
    expect(brushCard.kind, 'brush');
    expect(brushCard.name, custom.name);
    await SharedAssetCardService.importCard(brushCard, brushService: brushes);
    final restoredBrush = brushes.brushes.last;
    expect(restoredBrush.id, isNot(custom.id));
    expect(restoredBrush.name, '共有テスト・ブラシ (2)');
    expect(restoredBrush.isFavorite, isFalse);
    expect(restoredBrush.tags, custom.tags);
    expect(restoredBrush.pressureOn.toJson(), custom.pressureOn.toJson());
    expect(restoredBrush.customImagePaths, hasLength(1));
    expect(await File(restoredBrush.resolvedCustomImagePaths.first).readAsBytes(), pixels);
    brushes.dispose();

    final tones = ToneService();
    await tones.init();
    final customTone = Tone(
      id: 'outside-custom-tone',
      name: '共有テスト・トーン',
      patternName: 'ピクセル散らし（1px）',
      texturePath: originalImage.path,
      tags: const ['pixel'],
      isFavorite: true,
    );
    tones.addTone(customTone);
    final tonePng = await SharedAssetCardService.exportTone(tones, customTone);
    await tonePng.copy('${screenshots.path}/tone_complete_share_card.png');
    final toneCard = await SharedAssetCardService.inspect(tonePng);
    await SharedAssetCardService.importCard(toneCard, toneService: tones);
    final restoredTone = tones.tones.last;
    expect(restoredTone.name, '共有テスト・トーン (2)');
    expect(restoredTone.patternName, customTone.patternName);
    expect(restoredTone.tags, customTone.tags);
    expect(restoredTone.isFavorite, isFalse);
    expect(await File(restoredTone.texturePath!).readAsBytes(), pixels);
    tones.dispose();

    final stamps = StampService();
    await stamps.init();
    final customStamp = Stamp(
      id: 'outside-custom-stamp',
      name: '共有テスト・スタンプ',
      imagePath: originalImage.path,
      opacity: 77,
      density: 2.2,
      scatter: .25,
      isFavorite: true,
      tags: const ['effect'],
    );
    stamps.addStamp(customStamp);
    final stampPng = await SharedAssetCardService.exportStamp(stamps, customStamp);
    await stampPng.copy('${screenshots.path}/stamp_complete_share_card.png');
    final stampCard = await SharedAssetCardService.inspect(stampPng);
    await SharedAssetCardService.importCard(stampCard, stampService: stamps);
    final restoredStamp = stamps.stamps.last;
    expect(restoredStamp.name, '共有テスト・スタンプ (2)');
    expect(restoredStamp.opacity, 77);
    expect(restoredStamp.density, 2.2);
    expect(restoredStamp.scatter, .25);
    expect(restoredStamp.tags, customStamp.tags);
    expect(restoredStamp.isFavorite, isFalse);
    expect(await File(restoredStamp.imagePath!).readAsBytes(), pixels);
    stamps.dispose();
  });

  test('a plain PNG or a stripped chunk cannot be imported', () {
    final raw = Uint8List.fromList(base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4////fwAJ+wP9KobjigAAAABJRU5ErkJggg=='));
    expect(() => SharedAssetCardCodec.extract(raw), throwsFormatException);
    final card = SharedAssetCardCodec.embed(
      png: raw,
      kind: 'stamp',
      name: 'test',
      data: Uint8List.fromList([1, 2, 3]),
    );
    expect(SharedAssetCardCodec.extract(card).kind, 'stamp');
    expect(() => SharedAssetCardCodec.extract(raw), throwsFormatException);
  });
}
