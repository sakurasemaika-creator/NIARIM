import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/font_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory root;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    root = Directory.systemTemp.createTempSync('niarim_font_direct_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => root.path);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<Uint8List> bundledFontBytes() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final path = manifest.listAssets().firstWhere(
      (p) => p.contains('assets/fonts/HakkouMincho.ttf'),
    );
    final data = await rootBundle.load(path);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  test(
    'real font add/read/rename/favorite/pixel/persist/remove works',
    () async {
      final service = FontService();
      await service.init();
      expect(
        service.catalog,
        isNotEmpty,
        reason: 'downloadable font catalog asset must be readable',
      );
      expect(service.fonts, isEmpty);

      final unsupported = File('${root.path}/bad.txt')..writeAsStringSync('x');
      expect(await service.addFont(unsupported.path, 'bad'), isNull);

      final bytes = await bundledFontBytes();
      final source = File('${root.path}/valid.ttf')..writeAsBytesSync(bytes);
      final added = await service.addFont(source.path, 'Valid Font');
      expect(added, isNotNull);
      expect(added!.id, 'Font0000');
      expect(added.sizeBytes, bytes.length);
      expect(service.familyNameOf(added), 'UserFont_Font0000');
      expect(await service.readFontBytes(added), orderedEquals(bytes));

      await service.renameFont(added.id, 'Renamed Font');
      expect(service.fonts.single.displayName, 'Renamed Font');
      await service.renameFont('missing', 'ignored');

      await service.toggleFavorite(added.id);
      expect(service.fonts.single.isFavorite, isTrue);
      await service.toggleFavorite('missing');

      expect(service.pixelModeForFamily(service.familyNameOf(added)), isFalse);
      await service.togglePixelMode(added.id);
      expect(service.fonts.single.pixelMode, isTrue);
      expect(service.pixelModeForFamily(service.familyNameOf(added)), isTrue);
      expect(service.pixelModeForFamily('BuiltInUnknown'), isFalse);
      await service.togglePixelMode('missing');

      final restored = FontService();
      await restored.init();
      expect(restored.fonts, hasLength(1));
      expect(restored.fonts.single.displayName, 'Renamed Font');
      expect(restored.fonts.single.isFavorite, isTrue);
      expect(restored.fonts.single.pixelMode, isTrue);

      final path = Directory(
        '${root.path}/niarim/Fonts',
      ).listSync().whereType<File>().single.path;
      expect(File(path).existsSync(), isTrue);

      await restored.removeFont(added.id);
      expect(restored.fonts, isEmpty);
      expect(File(path).existsSync(), isFalse);
      await restored.removeFont('missing');
      expect(await restored.readFontBytes(added), isNull);
    },
    timeout: const Timeout(Duration(seconds: 120)),
  );

  test(
    'bundled import preserves id, prevents duplicate and advances generated id',
    () async {
      final bytes = await bundledFontBytes();
      final service = FontService();
      await service.init();

      await service.importBundledFont(
        id: 'Font0042',
        displayName: 'Bundled',
        fileName: 'Font0042.ttf',
        bytes: bytes,
      );
      expect(service.fonts.map((f) => f.id), ['Font0042']);
      final imported = service.fonts.single;
      expect(service.familyNameOf(imported), 'UserFont_Font0042');
      expect(await service.readFontBytes(imported), orderedEquals(bytes));

      await service.importBundledFont(
        id: 'Font0042',
        displayName: 'Duplicate',
        fileName: 'Font0042.ttf',
        bytes: bytes,
      );
      expect(service.fonts, hasLength(1));

      final nextSource = File('${root.path}/next.otf')..writeAsBytesSync(bytes);
      final next = await service.addFont(nextSource.path, 'Next');
      expect(next, isNotNull);
      expect(next!.id, 'Font0043');

      final catalogEntry = service.catalog.first;
      expect(
        service.isCatalogFontDownloaded(catalogEntry),
        service.fonts.any((f) => f.id == catalogEntry.id),
      );
    },
    timeout: const Timeout(Duration(seconds: 120)),
  );

  test(
    'corrupt ttf throws FontCorruptedException and cleans copied file',
    () async {
      final service = FontService();
      await service.init();
      final corrupt = File('${root.path}/corrupt.ttf')
        ..writeAsBytesSync(List<int>.generate(64, (i) => i));
      await expectLater(
        () => service.addFont(corrupt.path, 'Corrupt'),
        throwsA(isA<FontCorruptedException>()),
      );
      expect(service.fonts, isEmpty);
      final fontsDir = Directory('${root.path}/niarim/Fonts');
      expect(
        fontsDir.existsSync()
            ? fontsDir.listSync().whereType<File>()
            : const [],
        isEmpty,
      );
    },
  );
}
