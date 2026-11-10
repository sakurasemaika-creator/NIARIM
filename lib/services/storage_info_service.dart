import 'dart:io';

import 'package:disk_space_2/disk_space_2.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'export_storage.dart';

/// 容量削減画面（ホーム画面ハンバーガーメニュー）で表示するNIARIMの
/// 内部データ内訳カテゴリ。
enum StorageCategory {
  /// 全プロジェクトのMaterials/フォルダ（画像・動画・音声素材の実体）。
  materials,

  /// プロジェクト本体（Materials除く。タイル絵・レイヤーデータ等）。
  /// ゴミ箱に入っているプロジェクトは含まない（[trash]で別集計する）。
  projectData,

  /// ゴミ箱（削除済みだが自動削除待ちのプロジェクト。Materials込みの
  /// フォルダ丸ごとのサイズ）。
  trash,

  /// アプリ管理の書き出し済み動画・GIF・画像（niarim/exports/）。
  exports,

  /// 自作ブラシ・トーン・スタンプ・フォント（niarim/Brushes・Tones・
  /// Stamps・Fonts/）。
  customAssets,

  /// アプリ専用キャッシュ。OS共用の一時ディレクトリは含めない。
  cache,
}

/// NIARIMのデータ内訳の集計結果。
class StorageBreakdown {
  final Map<StorageCategory, int> bytesByCategory;

  const StorageBreakdown(this.bytesByCategory);

  int bytesOf(StorageCategory c) => bytesByCategory[c] ?? 0;

  int get totalBytes => bytesByCategory.values.fold(0, (a, b) => a + b);
}

/// 端末の空き容量情報（取得できない場合はnull。実機以外・プラグイン未対応
/// プラットフォームでは失敗しうるため、呼び出し側は必ずnullを想定する）。
class DeviceSpaceInfo {
  /// 端末の総容量（バイト）。
  final int totalBytes;

  /// 端末の空き容量（バイト）。
  final int freeBytes;

  const DeviceSpaceInfo({required this.totalBytes, required this.freeBytes});

  int get usedByOthersBytes =>
      (totalBytes - freeBytes).clamp(0, totalBytes).toInt();
}

/// 容量削減画面が使う、ディスク使用量の集計・キャッシュ削除サービス。
/// 状態を持たないヘルパー関数群（ChangeNotifierではない。呼び出しの
/// たびに最新のディスク状態を都度スキャンするため）。
class StorageInfoService {
  /// NIARIMのデータ内訳を集計する。[trashedProjectIds]はProjectServiceの
  /// `trash`（ゴミ箱）に入っているプロジェクトIDの集合で、これに応じて
  /// 各プロジェクトフォルダを[StorageCategory.trash]か
  /// [StorageCategory.materials]/[StorageCategory.projectData]かに
  /// 振り分ける。
  Future<StorageBreakdown> computeBreakdown(
    Set<String> trashedProjectIds,
  ) async {
    final docs = await getApplicationDocumentsDirectory();
    final niarimDir = Directory('${docs.path}/niarim');

    int materials = 0;
    int projectData = 0;
    int trash = 0;

    final projectsDir = Directory('${niarimDir.path}/projects');
    if (projectsDir.existsSync()) {
      for (final entry in projectsDir.listSync()) {
        if (entry is! Directory) continue;
        final projectId = entry.uri.pathSegments
            .where((s) => s.isNotEmpty)
            .last;
        final materialsDir = Directory('${entry.path}/Materials');
        final materialsBytes = materialsDir.existsSync()
            ? await _dirSize(materialsDir)
            : 0;
        final totalBytes = await _dirSize(entry);
        final ownBytes = (totalBytes - materialsBytes).clamp(0, totalBytes);
        if (trashedProjectIds.contains(projectId)) {
          trash += totalBytes;
        } else {
          materials += materialsBytes;
          projectData += ownBytes;
        }
      }
    }

    final exportsDir = ExportStorage.managedDirectoryIn(docs);
    final exportsBytes = exportsDir.existsSync()
        ? await _dirSize(exportsDir)
        : 0;

    int customAssets = 0;
    for (final name in ['Brushes', 'Tones', 'Stamps', 'Fonts']) {
      final dir = Directory('${niarimDir.path}/$name');
      if (dir.existsSync()) customAssets += await _dirSize(dir);
    }

    final cacheDir = await getApplicationCacheDirectory();
    final cacheBytes = cacheDir.existsSync() ? await _dirSize(cacheDir) : 0;

    return StorageBreakdown({
      StorageCategory.materials: materials,
      StorageCategory.projectData: projectData,
      StorageCategory.trash: trash,
      StorageCategory.exports: exportsBytes,
      StorageCategory.customAssets: customAssets,
      StorageCategory.cache: cacheBytes,
    });
  }

  /// 端末の総容量・空き容量を取得する（disk_space_2プラグイン経由）。
  /// プラグインが利用できない環境（単体テスト・非対応プラットフォーム等）
  /// では例外を握りつぶしてnullを返す。
  Future<DeviceSpaceInfo?> deviceSpace() async {
    try {
      final freeMb = await DiskSpace.getFreeDiskSpace;
      final totalMb = await DiskSpace.getTotalDiskSpace;
      if (freeMb == null || totalMb == null) return null;
      const mib = 1024 * 1024;
      return DeviceSpaceInfo(
        totalBytes: (totalMb * mib).round(),
        freeBytes: (freeMb * mib).round(),
      );
    } catch (_) {
      return null;
    }
  }

  /// アプリ専用キャッシュの中身を削除する（フォルダ自体は残す）。
  /// OS共用の一時領域には触れない。削除できた項目のバイト数を返す。
  /// 一部でも削除できない場合は例外を返し、全量削除の成功とはしない。
  Future<int> clearCache() async {
    final cacheDir = await getApplicationCacheDirectory();
    if (!cacheDir.existsSync()) return 0;
    var freed = 0;
    var failed = false;
    await for (final entry in cacheDir.list(followLinks: false)) {
      try {
        final bytes = entry is File
            ? await entry.length()
            : entry is Directory
            ? await _dirSize(entry)
            : 0;
        await entry.delete(recursive: true);
        freed += bytes;
      } on FileSystemException {
        // 他の項目は削除を続け、残った分はUIから再試行できるようにする。
        failed = true;
      }
    }
    if (failed) {
      throw const FileSystemException('Could not clear all application cache');
    }
    return freed;
  }

  /// NIARIMの全データを削除する（初期化・工場出荷状態に戻す）。
  /// ディスク上のniarim/（アプリ管理のexports/を含む）・キャッシュに加え、
  /// SharedPreferences（全Serviceの設定・素材メタデータ・プロジェクト
  /// 一覧索引等が保存されている）も全消去する。以前の共有exports/は保持する。
  ///
  /// 【重要】この呼び出しの時点で既にメモリ上に初期化済みの各Service
  /// （ProjectService・MaterialService等、main()で一度だけ生成される）
  /// は古い状態を保持したままになる。ディスク上の実体が消えた後もこれら
  /// のServiceを使い続けると、存在しないファイルを参照するなどの不整合が
  /// 起きうるため、呼び出し側（UI）は必ずこの後にアプリの再起動を促す
  /// こと（本サービス側では対応しない。プロセス全体の再起動が必要な
  /// ため、Flutterの画面遷移だけでは完全にはリセットできない）。
  Future<void> eraseAllData() async {
    final docs = await getApplicationDocumentsDirectory();
    for (final dir in [Directory('${docs.path}/niarim')]) {
      if (dir.existsSync()) {
        try {
          await dir.delete(recursive: true);
        } catch (_) {
          // 一部ファイルが使用中等で削除できなくても、可能な範囲で続行する。
        }
      }
    }
    ExportStorage.invalidate();
    final cacheDir = await getApplicationCacheDirectory();
    if (cacheDir.existsSync()) {
      for (final entry in cacheDir.listSync()) {
        try {
          await entry.delete(recursive: true);
        } catch (_) {}
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<int> _dirSize(Directory dir) async {
    int total = 0;
    try {
      await for (final entry in dir.list(recursive: true, followLinks: false)) {
        if (entry is File) {
          try {
            total += await entry.length();
          } catch (_) {
            // 列挙中に削除された等は無視する。
          }
        }
      }
    } catch (_) {
      // ディレクトリ自体へのアクセスに失敗した場合はここまでの合計を返す。
    }
    return total;
  }
}

/// バイト数を「12.3MB」のような読みやすい文字列に整形する。
String formatStorageBytes(num bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  double value = bytes.toDouble();
  int unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  final decimals = unitIndex == 0 ? 0 : 1;
  return '${value.toStringAsFixed(decimals)}${units[unitIndex]}';
}
