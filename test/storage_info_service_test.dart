import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/storage_info_service.dart';

/// StorageInfoService（Task#138：容量削減画面）のうち、ファイルI/O・
/// path_providerに依存しない純粋な部分（バイト数の整形・集計値の
/// 派生プロパティ）の単体テスト。実際のディレクトリ走査
/// （computeBreakdown・clearCache・eraseAllData）はpath_providerの
/// プラットフォームチャンネルに依存するため単体テスト環境では検証できず、
/// 実機での確認が必要。
void main() {
  group('formatStorageBytes', () {
    test('1024未満はB単位で整数表示', () {
      expect(formatStorageBytes(0), '0B');
      expect(formatStorageBytes(512), '512B');
      expect(formatStorageBytes(1023), '1023B');
    });

    test('KB/MB/GB単位は小数点1桁で表示', () {
      expect(formatStorageBytes(1024), '1.0KB');
      expect(formatStorageBytes(1536), '1.5KB');
      expect(formatStorageBytes(1024 * 1024), '1.0MB');
      expect(formatStorageBytes(1024 * 1024 * 1024), '1.0GB');
    });

    test('TBまで到達したらそれ以上は繰り上げない', () {
      final huge = 1024 * 1024 * 1024 * 1024 * 5.0;
      expect(formatStorageBytes(huge), '5.0TB');
    });
  });

  group('StorageBreakdown', () {
    test('bytesOfは未登録カテゴリで0を返し、totalBytesは合計になる', () {
      const breakdown = StorageBreakdown({
        StorageCategory.materials: 100,
        StorageCategory.exports: 50,
      });
      expect(breakdown.bytesOf(StorageCategory.materials), 100);
      expect(breakdown.bytesOf(StorageCategory.cache), 0);
      expect(breakdown.totalBytes, 150);
    });
  });

  group('DeviceSpaceInfo', () {
    test('usedByOthersBytesはtotal-freeを返し、負にならない', () {
      const normal = DeviceSpaceInfo(totalBytes: 1000, freeBytes: 300);
      expect(normal.usedByOthersBytes, 700);

      // 端末側の丸め誤差等でfree>totalになっても0未満にはしない。
      const overFree = DeviceSpaceInfo(totalBytes: 1000, freeBytes: 1500);
      expect(overFree.usedByOthersBytes, 0);
    });
  });
}
