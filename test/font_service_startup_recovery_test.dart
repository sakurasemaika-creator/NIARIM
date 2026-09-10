import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/font_asset.dart';
import 'package:niarim/services/font_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory root;
  late Uint8List fontBytes;

  final savedFont = FontAsset(
    id: 'Font0000',
    displayName: 'Saved font',
    fileName: 'Font0000.ttf',
    sizeBytes: 0,
    addedAt: DateTime.utc(2026, 1, 1),
  );
  final savedMetadata = jsonEncode([savedFont.toJson()]);

  setUpAll(() async {
    final data = await rootBundle.load('assets/fonts/HakkouMincho.ttf');
    fontBytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    root = Directory.systemTemp.createTempSync('niarim_font_startup_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => root.path);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  File writeSavedFont([String name = 'Font0000.ttf']) {
    final dir = Directory('${root.path}/niarim/Fonts')
      ..createSync(recursive: true);
    return File('${dir.path}/$name')..writeAsBytesSync(fontBytes);
  }

  for (final entry in <String, Object>{
    'invalid JSON': '{',
    'invalid entry after a valid font': jsonEncode([
      savedFont.toJson(),
      <String, Object>{},
    ]),
    'wrong preference type': true,
  }.entries) {
    test(
      'corrupt metadata (${entry.key}) preserves files and fails startup',
      () async {
        final expectedError = entry.value == '{'
            ? isA<FormatException>()
            : isA<TypeError>();
        SharedPreferences.setMockInitialValues({'user_fonts': entry.value});
        final original = writeSavedFont();
        final source = File('${root.path}/new.ttf')
          ..writeAsBytesSync([1, 2, 3]);
        final service = FontService();
        addTearDown(service.dispose);

        await expectLater(service.init(), throwsA(expectedError));
        expect(service.fonts, isEmpty, reason: 'a partial list is not usable');
        await expectLater(
          service.addFont(source.path, 'New font'),
          throwsA(expectedError),
        );

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.get('user_fonts'), entry.value);
        expect(await original.readAsBytes(), orderedEquals(fontBytes));
        expect(original.parent.listSync().whereType<File>(), hasLength(1));
      },
    );
  }

  test(
    'failed startup retries after repair and successful init stays single',
    () async {
      SharedPreferences.setMockInitialValues({'user_fonts': '{'});
      final original = writeSavedFont();
      final service = FontService();
      addTearDown(service.dispose);
      await expectLater(service.init(), throwsFormatException);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_fonts', savedMetadata);
      await Future.wait([service.init(), service.init()]);
      await service.init();
      expect(service.fonts.map((font) => font.id), ['Font0000']);
      expect(prefs.getString('user_fonts'), savedMetadata);

      final source = File('${root.path}/next.ttf')..writeAsBytesSync(fontBytes);
      final added = await service.addFont(source.path, 'Next font');
      expect(added?.id, 'Font0001');
      expect(await original.readAsBytes(), orderedEquals(fontBytes));
      expect(service.fonts, hasLength(2));
    },
  );

  test(
    'font directory I/O failure is retryable without replacing metadata',
    () async {
      SharedPreferences.setMockInitialValues({'user_fonts': savedMetadata});
      Directory('${root.path}/niarim').createSync(recursive: true);
      final blocker = File('${root.path}/niarim/Fonts')
        ..writeAsStringSync('preserve this file');
      final service = FontService();
      addTearDown(service.dispose);

      await expectLater(service.init(), throwsA(isA<FileSystemException>()));
      expect(service.fonts, isEmpty);
      expect(blocker.readAsStringSync(), 'preserve this file');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_fonts'), savedMetadata);

      blocker.deleteSync();
      writeSavedFont();
      await service.init();
      expect(service.fonts.map((font) => font.id), ['Font0000']);
    },
  );

  test(
    'new fonts preserve orphan files of either supported extension',
    () async {
      final first = writeSavedFont();
      final second = writeSavedFont('Font0001.otf');
      final source = File('${root.path}/new.ttf')..writeAsBytesSync(fontBytes);
      final service = FontService();
      addTearDown(service.dispose);
      await service.init();

      final added = await service.addFont(source.path, 'New font');
      expect(added?.id, 'Font0002');
      expect(await first.readAsBytes(), orderedEquals(fontBytes));
      expect(await second.readAsBytes(), orderedEquals(fontBytes));
      expect(service.fonts.map((font) => font.id), ['Font0002']);
    },
  );

  test('corrupt font cleanup cannot delete an orphan font', () async {
    final original = writeSavedFont();
    final source = File('${root.path}/corrupt.ttf')
      ..writeAsBytesSync([1, 2, 3]);
    final service = FontService();
    addTearDown(service.dispose);
    await service.init();

    await expectLater(
      service.addFont(source.path, 'Corrupt font'),
      throwsA(isA<FontCorruptedException>()),
    );
    expect(await original.readAsBytes(), orderedEquals(fontBytes));
    expect(original.parent.listSync().whereType<File>(), hasLength(1));
    expect(service.fonts, isEmpty);
  });

  test(
    'bundled import preserves an existing path absent from metadata',
    () async {
      final original = writeSavedFont();
      final service = FontService();
      addTearDown(service.dispose);
      await service.init();

      await service.importBundledFont(
        id: 'DifferentId',
        displayName: 'Incoming font',
        fileName: 'Font0000.ttf',
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(await original.readAsBytes(), orderedEquals(fontBytes));
      expect(service.fonts, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('user_fonts'), isFalse);
    },
  );
}
