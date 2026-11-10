import 'dart:async';
import 'dart:io';

import 'package:disk_space_2/disk_space_2.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_error_reporter.dart';
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

  /// 読めない所があった分類。その分類の値は読めた分だけの合計なので、
  /// 実際より少ない。
  final Set<StorageCategory> incomplete;

  const StorageBreakdown(this.bytesByCategory, {this.incomplete = const {}});

  int bytesOf(StorageCategory c) => bytesByCategory[c] ?? 0;

  int get totalBytes => bytesByCategory.values.fold(0, (a, b) => a + b);

  /// どの分類も読めなかった（＝内訳として出せるものが無い）。
  bool get isUnreadable => StorageCategory.values.every(incomplete.contains);
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

/// 走っている集計を、後から来た呼び出しと分け合う長さの上限。これより前に
/// 始まってまだ終わらない集計（返らない問い合わせ・止まったマウント）を
/// いつまでも渡し続けると、画面を開き直しても集計中のまま戻れない。
const storageScanShareLimit = Duration(seconds: 30);

/// 容量削減画面が使う、ディスク使用量の集計・キャッシュ削除サービス。
/// 集計は呼ぶたびにディスクを走査する（ChangeNotifierではない）。
///
/// 画面を開き直したとき、新しい集計が終わるまで前回の値を出せるように、
/// 直近の結果だけをプロセスの中で覚えている（[lastBreakdown]・
/// [lastDeviceSpace]）。大きさを変える操作の後は[invalidate]で捨てること
/// （容量削減の画面の外でファイルを消す所も含む）。
class StorageInfoService {
  static StorageBreakdown? _lastBreakdown;
  static DeviceSpaceInfo? _lastDeviceSpace;

  static final Stopwatch _sinceStart = Stopwatch()..start();
  static Duration _elapsedSinceStart() => _sinceStart.elapsed;

  /// 走っている集計の古さを計る時計（進むだけで、端末の時刻合わせでは
  /// 動かない）。テストは差し替えて、実時間を待たずに進める。
  @visibleForTesting
  static Duration Function() scanClock = _elapsedSinceStart;

  /// 大きさを変える操作のたびに進む。進む前に始めた集計・問い合わせは
  /// 操作の前のディスクを見ているので、結果を覚えず、後から来た呼び出しとも
  /// 共有しない。
  static int _epoch = 0;

  static _RunningScan? _running;

  /// 直近の集計結果。まだ集計していない・[invalidate]の後はnull。
  StorageBreakdown? get lastBreakdown => _lastBreakdown;

  /// 直近に取得できた端末の容量。
  DeviceSpaceInfo? get lastDeviceSpace => _lastDeviceSpace;

  /// 覚えている結果を捨てる。ファイルを消す・増やす操作の後に呼ぶ
  /// （[clearCache]・[eraseAllData]は自分で呼ぶ）。
  void invalidate() {
    _epoch++;
    _lastBreakdown = null;
    _lastDeviceSpace = null;
  }

  /// NIARIMのデータ内訳を集計する。[trashedProjectIds]はProjectServiceの
  /// `trash`（ゴミ箱）に入っているプロジェクトIDの集合で、これに応じて
  /// 各プロジェクトフォルダを[StorageCategory.trash]か
  /// [StorageCategory.materials]/[StorageCategory.projectData]かに
  /// 振り分ける。
  ///
  /// 1か所が読めなくても残りの分類は返し、読めない所があった分類を
  /// [StorageBreakdown.incomplete]に入れる（原因は[AppErrorReporter]へ
  /// 記録する）。
  ///
  /// 同じ条件の集計がまだ走っていれば、新しく走査を始めずにその結果を待つ
  /// （画面を開き直すたびに走査が重なって、互いに遅くなるのを防ぐ）。
  /// ただし[storageScanShareLimit]より前に始まった集計は待たない。[fresh]を
  /// 渡すと、走っている集計があっても新しく始める（終わらない集計を待って
  /// いた画面が、利用者の操作で取り直すとき）。
  Future<StorageBreakdown> computeBreakdown(
    Set<String> trashedProjectIds, {
    bool fresh = false,
  }) {
    final running = _running;
    if (!fresh && running != null && running.serves(trashedProjectIds)) {
      return running.result;
    }
    final scan = _RunningScan(
      Set.of(trashedProjectIds),
      _epoch,
      Zone.current,
      scanClock(),
    );
    _running = scan;
    Future<StorageBreakdown> run() async {
      try {
        final breakdown = await _scanBreakdown(scan.trashedProjectIds);
        if (identical(_running, scan) &&
            scan.epoch == _epoch &&
            !breakdown.isUnreadable) {
          _lastBreakdown = breakdown;
        }
        return breakdown;
      } finally {
        if (identical(_running, scan)) _running = null;
      }
    }

    return scan.result = run();
  }

  Future<StorageBreakdown> _scanBreakdown(Set<String> trashedProjectIds) async {
    int materials = 0;
    int projectData = 0;
    int trash = 0;
    int exportsBytes = 0;
    int customAssets = 0;
    int cacheBytes = 0;
    final incomplete = <StorageCategory>{};

    // 読めないファイルが多いとエラーの記録がそれだけで埋まるので、
    // 分類ごとに最初の1件だけ記録する。
    void unreadable(
      List<StorageCategory> categories,
      Object error,
      StackTrace? stack,
    ) {
      var first = false;
      for (final category in categories) {
        if (incomplete.add(category)) first = true;
      }
      if (first) AppErrorReporter.record(error, stack);
    }

    Future<int> sizeOf(Directory dir, List<StorageCategory> categories) async {
      if (!dir.existsSync()) return 0;
      final size = await _measure(dir);
      if (size.error != null) unreadable(categories, size.error!, size.stack);
      return size.bytes;
    }

    Directory? docs;
    try {
      docs = await getApplicationDocumentsDirectory();
    } catch (error, stack) {
      unreadable(_documentsCategories, error, stack);
    }
    if (docs != null) {
      final niarimDir = Directory('${docs.path}/niarim');

      final projectsDir = Directory('${niarimDir.path}/projects');
      var projects = const <FileSystemEntity>[];
      try {
        if (projectsDir.existsSync()) projects = projectsDir.listSync();
      } catch (error, stack) {
        if (!_vanished(error)) unreadable(_projectCategories, error, stack);
      }
      for (final entry in projects) {
        if (entry is! Directory) continue;
        final projectId = entry.uri.pathSegments
            .where((s) => s.isNotEmpty)
            .last;
        final trashed = trashedProjectIds.contains(projectId);
        final size = await _measure(entry, splitMaterials: true);
        if (trashed) {
          trash += size.bytes;
        } else {
          materials += size.materialsBytes;
          projectData += size.bytes - size.materialsBytes;
        }
        if (size.error != null) {
          unreadable(
            trashed ? const [StorageCategory.trash] : _liveProjectCategories,
            size.error!,
            size.stack,
          );
        }
      }

      exportsBytes = await sizeOf(
        ExportStorage.managedDirectoryIn(docs),
        const [StorageCategory.exports],
      );

      for (final name in ['Brushes', 'Tones', 'Stamps', 'Fonts']) {
        customAssets += await sizeOf(
          Directory('${niarimDir.path}/$name'),
          const [StorageCategory.customAssets],
        );
      }
    }

    try {
      cacheBytes = await sizeOf(await getApplicationCacheDirectory(), const [
        StorageCategory.cache,
      ]);
    } catch (error, stack) {
      unreadable(const [StorageCategory.cache], error, stack);
    }

    return StorageBreakdown({
      StorageCategory.materials: materials,
      StorageCategory.projectData: projectData,
      StorageCategory.trash: trash,
      StorageCategory.exports: exportsBytes,
      StorageCategory.customAssets: customAssets,
      StorageCategory.cache: cacheBytes,
    }, incomplete: incomplete);
  }

  /// 端末の総容量・空き容量を取得する（disk_space_2プラグイン経由）。
  /// プラグインが利用できない環境（単体テスト・非対応プラットフォーム等）
  /// では例外を握りつぶしてnullを返す。
  Future<DeviceSpaceInfo?> deviceSpace() async {
    final epoch = _epoch;
    try {
      final freeMb = await DiskSpace.getFreeDiskSpace;
      final totalMb = await DiskSpace.getTotalDiskSpace;
      if (freeMb == null || totalMb == null) return null;
      const mib = 1024 * 1024;
      final info = DeviceSpaceInfo(
        totalBytes: (totalMb * mib).round(),
        freeBytes: (freeMb * mib).round(),
      );
      if (epoch == _epoch) _lastDeviceSpace = info;
      return info;
    } catch (_) {
      return null;
    }
  }

  /// アプリ専用キャッシュの中身を削除する（フォルダ自体は残す）。
  /// OS共用の一時領域には触れない。削除できた項目のバイト数を返す。
  /// 一部でも削除できない場合は例外を返し、全量削除の成功とはしない。
  Future<int> clearCache() async {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      if (!cacheDir.existsSync()) return 0;
      var freed = 0;
      var failed = false;
      await for (final entry in cacheDir.list(followLinks: false)) {
        try {
          final bytes = entry is File
              ? await entry.length()
              : entry is Directory
              ? (await _measure(entry)).bytes
              : 0;
          await entry.delete(recursive: true);
          freed += bytes;
        } on FileSystemException {
          // 他の項目は削除を続け、残った分はUIから再試行できるようにする。
          failed = true;
        }
      }
      if (failed) {
        throw const FileSystemException(
          'Could not clear all application cache',
        );
      }
      return freed;
    } finally {
      // 一部だけ消えた場合も含め、前の集計はもう合っていない。
      invalidate();
    }
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
    try {
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
    } finally {
      invalidate();
    }
  }

  /// [dir]の中のファイルの大きさを、リンクをたどらずに合計する。
  /// 読めないフォルダ・ファイルは飛ばして残りを数え、最初のエラーを
  /// [_FolderSize.error]に残す。[splitMaterials]なら直下の`Materials/`の
  /// 中の分を[_FolderSize.materialsBytes]にも数える（同じフォルダを2回
  /// 走査しないため）。
  Future<_FolderSize> _measure(
    Directory dir, {
    bool splitMaterials = false,
  }) async {
    final size = _FolderSize();
    void failed(Object error, StackTrace stack) {
      // 一覧を取った後に消えた項目は、読めなかったうちに入れない
      // （無いものを数えないのは正しい合計）。
      if (_vanished(error)) return;
      size.error ??= error;
      size.stack ??= stack;
    }

    final root = dir.path;
    final rootLength = root.endsWith('/') || root.endsWith(r'\')
        ? root.length - 1
        : root.length;
    try {
      // 一覧のエラー（読めない下位フォルダ）はストリームのエラーとして届き、
      // 走査自体はその先へ続く。ここで受けないと最初の1件でループが終わる。
      final entries = dir
          .list(recursive: true, followLinks: false)
          .handleError(failed);
      await for (final entry in entries) {
        if (entry is! File) continue;
        try {
          final length = await entry.length();
          size.bytes += length;
          if (splitMaterials &&
              entry.path.startsWith(_materialsFolder, rootLength)) {
            size.materialsBytes += length;
          }
        } catch (error, stack) {
          failed(error, stack);
        }
      }
    } catch (error, stack) {
      failed(error, stack);
    }
    return size;
  }
}

const _projectCategories = [
  StorageCategory.materials,
  StorageCategory.projectData,
  StorageCategory.trash,
];
const _liveProjectCategories = [
  StorageCategory.materials,
  StorageCategory.projectData,
];
const _documentsCategories = [
  ..._projectCategories,
  StorageCategory.exports,
  StorageCategory.customAssets,
];

/// プロジェクトのフォルダから見た、素材フォルダの中のパスの先頭。
final _materialsFolder = RegExp(r'[/\\]Materials[/\\]');

bool _vanished(Object error) => error is PathNotFoundException;

class _FolderSize {
  int bytes = 0;
  int materialsBytes = 0;
  Object? error;
  StackTrace? stack;
}

/// 走っている途中の集計。
class _RunningScan {
  _RunningScan(this.trashedProjectIds, this.epoch, this.zone, this.startedAt);

  final Set<String> trashedProjectIds;
  final int epoch;

  /// 始めたときの[StorageInfoService.scanClock]の値。
  final Duration startedAt;

  /// 始めたゾーン。Futureの続きは作ったゾーンで動くので、別のゾーン
  /// （テストごとの偽の時計）で始まった集計を待つと、そのゾーンが
  /// 止まった後は二度と終わらない。同じゾーンの呼び出しとだけ共有する。
  final Zone zone;
  late final Future<StorageBreakdown> result;

  bool serves(Set<String> trashedProjectIds) =>
      epoch == StorageInfoService._epoch &&
      identical(zone, Zone.current) &&
      StorageInfoService.scanClock() - startedAt < storageScanShareLimit &&
      setEquals(this.trashedProjectIds, trashedProjectIds);
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
