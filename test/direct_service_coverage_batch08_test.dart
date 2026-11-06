import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/watermark_asset.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/storage_info_service.dart';
import 'package:niarim/services/watermark_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory root;
  late Directory docs;
  late Directory temp;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    root = Directory.systemTemp.createTempSync('niarim_direct_storage_');
    docs = Directory('${root.path}/docs')..createSync(recursive: true);
    temp = Directory('${root.path}/temp')..createSync(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async {
          if (call.method == 'getTemporaryDirectory') return temp.path;
          return docs.path;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  group('WatermarkService direct coverage', () {
    test('image/text add update path persistence and removal work', () async {
      final source = File('${root.path}/source.logo.png')
        ..writeAsBytesSync([1, 2, 3, 4, 5]);
      final service = WatermarkService();
      await service.init();
      expect(service.assets, isEmpty);

      final image = await service.addWatermark(source.path);
      expect(image.type, WatermarkAssetType.image);
      expect(image.name, 'source.logo');
      final copiedPath = await service.pathOf(image.id);
      expect(copiedPath, isNotNull);
      expect(File(copiedPath!).readAsBytesSync(), [1, 2, 3, 4, 5]);

      final text = await service.addTextWatermark(
        '1234567890123456',
        color: 0xFFAABBCC,
        fontFamily: 'HakkouMincho',
        shadowEnabled: true,
        shadowColor: 0x99010203,
        shadowOffsetX: 2,
        shadowOffsetY: 3,
        shadowBlur: 4,
        outlineEnabled: true,
        outlineColor: 0xFFF0F0F0,
        outlineWidth: 5,
      );
      expect(text.type, WatermarkAssetType.text);
      expect(text.name, '123456789012…');
      expect(text.text, '1234567890123456');
      expect(text.textColor, 0xFFAABBCC);
      expect(text.shadowEnabled, isTrue);
      expect(text.outlineEnabled, isTrue);
      expect(
        await service.pathOf(text.id),
        isNull,
        reason: 'text watermarks do not have backing image files',
      );
      expect(await service.pathOf('missing'), isNull);

      await service.updateAsset(
        text.copyWith(
          name: 'Edited',
          text: 'edited text',
          shadowBlur: 8,
          outlineWidth: 2,
        ),
      );
      final edited = service.assets.firstWhere((a) => a.id == text.id);
      expect(edited.name, 'Edited');
      expect(edited.text, 'edited text');
      expect(edited.shadowBlur, 8);
      expect(edited.outlineWidth, 2);
      await service.updateAsset(
        const WatermarkAsset(
          id: 'missing',
          name: 'ignored',
          type: WatermarkAssetType.text,
        ),
      );

      final restored = WatermarkService();
      await restored.init();
      expect(restored.assets, hasLength(2));
      expect(restored.assets.firstWhere((a) => a.id == text.id).name, 'Edited');
      expect(await restored.pathOf(image.id), isNotNull);

      await restored.removeWatermark(image.id);
      expect(restored.assets.any((a) => a.id == image.id), isFalse);
      expect(File(copiedPath).existsSync(), isFalse);
      await restored.removeWatermark('missing');
      await restored.removeWatermark(text.id);
      expect(restored.assets, isEmpty);
    });

    test('image without extension is copied with png extension', () async {
      final source = File('${root.path}/source_without_ext')
        ..writeAsBytesSync([7, 7]);
      final service = WatermarkService();
      await service.init();
      final asset = await service.addWatermark(source.path);
      expect(asset.fileName, endsWith('.png'));
      expect(await service.pathOf(asset.id), isNotNull);
    });
  });

  group('StorageInfoService direct coverage', () {
    test(
      'breakdown assigns live/trash/materials/exports/assets/cache exactly',
      () async {
        void write(String path, int bytes) {
          final file = File(path)..createSync(recursive: true);
          file.writeAsBytesSync(List<int>.filled(bytes, 1));
        }

        write('${docs.path}/niarim/projects/live/project.json', 11);
        write('${docs.path}/niarim/projects/live/tiles/a.bin', 13);
        write('${docs.path}/niarim/projects/live/Materials/image.png', 17);
        write('${docs.path}/niarim/projects/trashp/project.json', 19);
        write('${docs.path}/niarim/projects/trashp/Materials/audio.wav', 23);
        write('${docs.path}/exports/a.mp4', 29);
        write('${docs.path}/niarim/Brushes/a.bin', 31);
        write('${docs.path}/niarim/Tones/a.bin', 37);
        write('${docs.path}/niarim/Stamps/a.bin', 41);
        write('${docs.path}/niarim/Fonts/a.ttf', 43);
        write('${temp.path}/wave.cache', 47);

        final service = StorageInfoService();
        final b = await service.computeBreakdown({'trashp'});
        expect(b.bytesOf(StorageCategory.materials), 17);
        expect(b.bytesOf(StorageCategory.projectData), 24);
        expect(b.bytesOf(StorageCategory.trash), 42);
        expect(b.bytesOf(StorageCategory.exports), 29);
        expect(b.bytesOf(StorageCategory.customAssets), 152);
        expect(b.bytesOf(StorageCategory.cache), 47);
        expect(b.totalBytes, 311);

        final freed = await service.clearCache();
        expect(freed, 47);
        expect(temp.listSync(), isEmpty);
        expect(
          (await service.computeBreakdown({
            'trashp',
          })).bytesOf(StorageCategory.cache),
          0,
        );

        final space = await service.deviceSpace();
        expect(
          space,
          isNull,
          reason: 'disk_space plugin is unavailable in widget-test runtime',
        );
      },
    );

    test(
      'eraseAllData clears NIARIM exports cache and SharedPreferences',
      () async {
        File('${docs.path}/niarim/x.bin')
          ..createSync(recursive: true)
          ..writeAsBytesSync([1]);
        File('${docs.path}/exports/x.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync([2]);
        File('${temp.path}/x.cache')
          ..createSync(recursive: true)
          ..writeAsBytesSync([3]);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('probe', 'value');

        await StorageInfoService().eraseAllData();
        expect(Directory('${docs.path}/niarim').existsSync(), isFalse);
        expect(Directory('${docs.path}/exports').existsSync(), isFalse);
        expect(temp.listSync(), isEmpty);
        expect(
          (await SharedPreferences.getInstance()).getString('probe'),
          isNull,
        );
      },
    );

    test(
      'byte formatter and DeviceSpaceInfo clamping cover unit boundaries',
      () {
        expect(formatStorageBytes(0), '0B');
        expect(formatStorageBytes(1023), '1023B');
        expect(formatStorageBytes(1024), '1.0KB');
        expect(formatStorageBytes(1024 * 1024), '1.0MB');
        expect(formatStorageBytes(1024 * 1024 * 1024), '1.0GB');
        const info = DeviceSpaceInfo(totalBytes: 100, freeBytes: 40);
        expect(info.usedByOthersBytes, 60);
        const overFree = DeviceSpaceInfo(totalBytes: 100, freeBytes: 140);
        expect(overFree.usedByOthersBytes, 0);
      },
    );
  });

  group('PremiumService local/non-store coverage', () {
    test(
      'init campaign/local purchase metadata and renewal estimates persist',
      () async {
        final service = PremiumService();
        await service.init();
        expect(
          service.storeAvailable,
          isFalse,
          reason: 'widget-test runtime must never connect to mobile billing',
        );
        expect(service.hasPurchasedPremium, isFalse);
        expect(service.purchaseDate, isNull);
        expect(service.nextRenewalDate, isNull);

        final monthlyStart = DateTime.now().subtract(const Duration(days: 40));
        await service.setPremium(
          true,
          purchaseDate: monthlyStart,
          productId: PremiumService.monthlyProductId,
        );
        expect(service.hasPurchasedPremium, isTrue);
        expect(service.purchaseDate, monthlyStart);
        expect(service.nextRenewalDateEstimate, isNotNull);
        expect(
          service.nextRenewalDateEstimate!.isAfter(DateTime.now()),
          isTrue,
        );

        final restoredMonthly = PremiumService();
        await restoredMonthly.init();
        expect(restoredMonthly.hasPurchasedPremium, isTrue);
        expect(
          restoredMonthly.purchaseDate?.millisecondsSinceEpoch,
          monthlyStart.millisecondsSinceEpoch,
        );
        expect(restoredMonthly.nextRenewalDate, isNotNull);

        final yearlyStart = DateTime.now().subtract(const Duration(days: 500));
        await restoredMonthly.setPremium(
          true,
          purchaseDate: yearlyStart,
          productId: PremiumService.yearlyProductId,
        );
        expect(restoredMonthly.nextRenewalDateEstimate, isNotNull);
        expect(
          restoredMonthly.nextRenewalDateEstimate!.isAfter(DateTime.now()),
          isTrue,
        );

        await restoredMonthly.setPremium(false);
        expect(restoredMonthly.hasPurchasedPremium, isFalse);
        expect(restoredMonthly.purchaseDate, isNull);
        expect(restoredMonthly.nextRenewalDate, isNull);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt('premium_purchase_date'), isNull);
        expect(prefs.getString('premium_purchase_product_id'), isNull);
      },
    );

    test('buy cannot start without a store and restore is a no-op', () async {
      final service = PremiumService();
      await service.init();
      final started = await service.buy(PremiumService.monthlyProductId);
      expect(started, isFalse);
      expect(service.purchasePending, isFalse);
      expect(service.purchaseError, isNotNull);
      await service.restorePurchases();
    });
  });
}
