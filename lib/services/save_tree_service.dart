import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../engine/niapro_serializer.dart';
import '../engine/tile_manager.dart';
import '../models/project.dart';
import '../models/save_node.dart';
import '../models/scene.dart';
import '../utils/app_error_reporter.dart';
import 'storage_info_service.dart';

/// セーブツリーサービス
/// スロット方式：固定数のスロットで管理
/// ツリー方式：保存数制限なし・ツリー状に履歴管理
///
/// 各ノードはSaveTree/{nodeId}.niaproとして実データ（シーン・タイル）を
/// ディスクへ保存する。自動保存（クラッシュ復元専用）とは
/// 完全に別領域・別ライフサイクルで管理される。
class SaveTreeService extends ChangeNotifier {
  /// Invoked ONLY when a user-initiated save slot/tree archive succeeds.
  /// No network response is awaited; a failed sync cannot invalidate the
  /// completed on-device save. AutosaveService does not call this callback.
  void Function(String projectId)? onManualSaveCommitted;

  void _notifySuccessfulManualSave(String projectId) {
    // A failed network checkpoint must NEVER make a completed local archive
    // look like a failed save or cause a second save/overwrite attempt.
    try {
      onManualSaveCommitted?.call(projectId);
    } catch (error) {
      debugPrint('Optional editing-time checkpoint skipped: $error');
    }
  }

  int _slotMax = 10;
  int get slotMax => _slotMax;

  bool _isTreeMode = false;
  bool get isTreeMode => _isTreeMode;

  void setSlotMax(int max) {
    assert(max > 0);
    _slotMax = max;
    notifyListeners();
  }

  void setTreeMode(bool treeMode) {
    _isTreeMode = treeMode;
    notifyListeners();
  }

  final Map<String, List<SaveNode>> _nodesByProject = {};
  // A slot is a named location, even if it has no snapshot yet. Keep its
  // memo independently of SaveNode so overwriting/deleting the archive does
  // not erase the slot's user-defined label.
  final Map<String, Map<int, String>> _slotMemosByProject = {};
  // アーカイブ：スロット→ツリー方式復元時に自動復元する保存データ
  final Map<String, List<SaveNode>> _archivedByProject = {};
  int _idCounter = 0;

  String _newId() =>
      'save_${DateTime.now().millisecondsSinceEpoch}_${_idCounter++}';

  /// 作品ごとの保存の一覧のファイル名（SaveTree/の中）。
  static const String indexFileName = 'index.json';

  /// 保存の一覧を読んだ作品（一覧が無かった作品を含む）。読めなかった一覧は
  /// ここに入らず、[_writeIndex]は書き換えない（書くと、読んでいない保存が
  /// 一覧から消える）。
  final Set<String> _readProjects = {};

  /// 保存の一覧をまだ読めていない間にメモを書いたスロット（作品ごと）。
  /// 書いたメモは[_writeIndex]が保存しないので、一覧を読めたときに
  /// ディスクのメモへ重ねてから一覧を書く（[_loadProject]。読んだ一覧の
  /// メモで置き換えると、書いたメモが消えた）。
  final Map<String, Set<int>> _memosEditedUnread = {};

  /// 起動時に、各作品の保存の一覧（SaveTree/index.json）を読み込む。一覧に
  /// 無い保存のファイル（一覧を書けなかった・以前の版で保存した）も拾い直す。
  /// 読めないものは飛ばし、起動は止めない。
  Future<void> init() => loadUnread();

  /// まだ一覧を読めていない作品の保存の一覧を読む。起動時と、読めなかった
  /// 保存先を作品の一覧の「再試行」で読めたとき
  /// （`ProjectService.onProjectsReloaded`）に呼ぶ。読んだ作品・この起動中に
  /// 保存した作品は読み直さない（同じ保存を二重にしない）。読み終える前に
  /// もう一度呼ばれたら、同じ読み込みを待つ。
  Future<void> loadUnread() => _loadingUnread ??= _loadUnread().whenComplete(
    () => _loadingUnread = null,
  );
  Future<void>? _loadingUnread;

  Future<void> _loadUnread() async {
    final String base;
    final List<Directory> folders;
    try {
      base = await NiaproSerializer.projectsBasePath();
      final root = Directory(base);
      if (!root.existsSync()) return;
      folders = root.listSync().whereType<Directory>().toList();
    } catch (error, stack) {
      // 保存先を取れない・中を一覧できない（権限が無い・入出力の失敗）。
      // 作品の一覧も読めていないので、そちらの「再試行」で読めたときに
      // 読み直す。
      AppErrorReporter.record(error, stack);
      return;
    }
    for (final dir in folders) {
      final projectId = dir.path.split(RegExp(r'[\\/]')).last;
      // この起動中に保存した作品も、一覧を読めていなければ読む（読んだ
      // 一覧へこの起動の保存を重ねる。[_loadProject]）。読み直さないと、
      // 前の保存が出ないまま、次の起動で新しい保存がスロットを移り、
      // メモも消えた。
      if (_readProjects.contains(projectId)) continue;
      try {
        await _loadProject(projectId, Directory('${dir.path}/SaveTree'));
      } catch (error, stack) {
        AppErrorReporter.record(error, stack);
      }
    }
    notifyListeners();
  }

  Future<void> _loadProject(String projectId, Directory dir) async {
    // existsSyncは「無い」と「入れない」（フォルダの権限が無い・入出力の
    // 失敗）をどちらもfalseにするので、読んでみて分ける。入れない一覧は
    // この作品の保存を出さず、読んだことにもしない（[_writeIndex]が
    // 書き換えず、入れるようになれば[loadUnread]で読み直す）。
    final index = File('${dir.path}/$indexFileName');
    // 一覧を読めていない間に書いたスロットのメモ（消して空にしたものも）。
    // 下で読んだ一覧のメモへ重ね（書いたスロットは書いた方が勝つ）、
    // 読めたら一覧を1回書く。
    final editedMemos = <int, String>{
      for (final slot in _memosEditedUnread[projectId] ?? const <int>{})
        slot: ?_slotMemosByProject[projectId]?[slot],
    };
    // 一覧を読めていない間にこの起動で保存したもの。読んだ一覧へ重ねる：
    // 保存したスロットはこの起動の保存のまま、同じスロットにあった一覧の
    // 保存は（見えていなかったので）消さずに空いているスロットへ移す。
    final sessionNodes = _nodesByProject[projectId] ?? const <SaveNode>[];
    final sessionArchived = _archivedByProject[projectId] ?? const <SaveNode>[];
    final sessionIds = {
      for (final n in [...sessionNodes, ...sessionArchived]) n.id,
    };
    final sessionSlots = {
      if (!_isTreeMode)
        for (final n in sessionNodes)
          if (n.slotIndex >= 0) n.slotIndex,
    };
    String? text;
    try {
      // 文字として読めない一覧（UTF-8の途中で切れた等）は、開けない一覧と
      // 違い、待っても読めるようにならない。readAsStringSyncはどちらも
      // FileSystemExceptionにするので、開いて読めたものは緩く文字にし、
      // 下で壊れた一覧として保存のファイルから拾い直す。
      text = utf8.decode(index.readAsBytesSync(), allowMalformed: true);
    } on PathNotFoundException {
      // 一覧が無い（保存のフォルダごと無い場合も）。
    } catch (error, stack) {
      AppErrorReporter.record(error, stack);
      return;
    }
    // 一覧に無い保存のファイルを拾い直すため、フォルダの中を一覧する。
    // 一覧できないときは、一覧にある保存だけを出す（拾い直すのは次の起動）。
    // 一覧も読めていなければ、何があるか分からないので読んだことにしない。
    var files = const <File>[];
    try {
      files = dir.listSync().whereType<File>().toList();
    } on PathNotFoundException {
      // 保存のフォルダが無い：保存の無い作品。
      if (text == null) {
        _readProjects.add(projectId);
        if (editedMemos.isNotEmpty || sessionIds.isNotEmpty) {
          await _persist(projectId);
        }
        return;
      }
    } catch (error, stack) {
      AppErrorReporter.record(error, stack);
      if (text == null) return;
    }
    String? thumbnailOf(String id) {
      final file = File('${dir.path}/${id}_thumb.png');
      return file.existsSync() ? file.path : null;
    }

    bool hasData(String id) => File('${dir.path}/$id.niapro').existsSync();
    final nodes = <SaveNode>[];
    final archived = <SaveNode>[];
    // この起動の保存は、一覧からも、一覧に無いファイルとしても拾わない。
    final known = <String>{...sessionIds};
    // 一覧の保存のうち、この起動で保存したスロットにあったもの。
    final displaced = <SaveNode>[];
    if (text != null) {
      try {
        final json = jsonDecode(text);
        if (json is Map) {
          final rawMemos = json['slotMemos'];
          if (rawMemos is Map) {
            final memos = <int, String>{};
            for (final entry in rawMemos.entries) {
              final slot = int.tryParse(entry.key.toString());
              if (slot == null || slot < 0 || entry.value is! String) continue;
              memos[slot] = entry.value as String;
            }
            memos.addAll(editedMemos);
            if (memos.isNotEmpty) _slotMemosByProject[projectId] = memos;
          }
          for (final (key, into) in [
            ('nodes', nodes),
            ('archived', archived),
          ]) {
            final list = json[key];
            if (list is! List) continue;
            for (final item in list) {
              final id = item is Map ? item['id'] : null;
              // 実データの無い保存は出さない（開くと失敗するため）。
              if (id is! String || known.contains(id) || !hasData(id)) {
                continue;
              }
              final node = SaveNode.fromJson(
                item,
                projectId: projectId,
                thumbnailPath: thumbnailOf(id),
              );
              if (node == null) continue;
              known.add(id);
              if (identical(into, nodes) &&
                  sessionSlots.contains(node.slotIndex)) {
                displaced.add(node);
                continue;
              }
              into.add(node);
            }
          }
        }
      } on FormatException catch (error, stack) {
        AppErrorReporter.record(error, stack);
      }
    }
    // 一覧に無い保存のファイルを古い順に拾い直す。
    final orphans = <SaveNode>[];
    for (final file in files) {
      final name = file.uri.pathSegments.last;
      if (!name.endsWith('.niapro')) continue;
      final id = name.substring(0, name.length - '.niapro'.length);
      if (known.contains(id)) continue;
      orphans.add(
        SaveNode(
          id: id,
          projectId: projectId,
          savedAt: _savedAtOf(id) ?? file.lastModifiedSync(),
          thumbnailPath: thumbnailOf(id),
        ),
      );
    }
    orphans.sort((a, b) => a.savedAt.compareTo(b.savedAt));
    if (_isTreeMode) {
      nodes.addAll(orphans);
    } else {
      // スロット方式：空いているスロットへ入れ、入りきらない分は退避する
      // （ツリー方式へ変えると出る）。
      final used = {
        ...sessionSlots,
        for (final n in nodes)
          if (n.slotIndex >= 0) n.slotIndex,
      };
      // この起動の保存にスロットを譲った一覧の保存も、同じように移す。
      for (final orphan in [...displaced, ...orphans]) {
        int? free;
        for (var i = 0; i < _slotMax; i++) {
          if (!used.contains(i)) {
            free = i;
            break;
          }
        }
        if (free == null) {
          archived.add(orphan);
          continue;
        }
        used.add(free);
        nodes.add(
          SaveNode(
            id: orphan.id,
            projectId: projectId,
            savedAt: orphan.savedAt,
            comment: orphan.comment,
            thumbnailPath: orphan.thumbnailPath,
            parentId: orphan.parentId,
            slotIndex: free,
          ),
        );
      }
    }
    nodes.addAll(sessionNodes);
    archived.addAll(sessionArchived);
    _readProjects.add(projectId);
    if (nodes.isEmpty && archived.isEmpty) {
      if (editedMemos.isNotEmpty) await _persist(projectId);
      return;
    }
    _nodesByProject[projectId] = nodes;
    if (archived.isNotEmpty) _archivedByProject[projectId] = archived;
    if (orphans.isNotEmpty || editedMemos.isNotEmpty || sessionIds.isNotEmpty) {
      await _persist(projectId);
    }
  }

  /// [file]が無いと確かめられるか（入れない・入出力の失敗で分からないときは
  /// false）。
  static bool _isMissing(File file) {
    try {
      file.lengthSync();
      return false;
    } on PathNotFoundException {
      return true;
    } on FileSystemException {
      return false;
    }
  }

  /// 保存のIDは`save_<ミリ秒>_<連番>`なので、そこから保存した時刻が分かる。
  static DateTime? _savedAtOf(String id) {
    final match = RegExp(r'^save_(\d+)_').firstMatch(id);
    if (match == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(int.parse(match.group(1)!));
  }

  final Map<String, Future<void>> _persisting = {};

  /// 作品の保存の一覧を書く。同じ作品の書き込みは1つずつ順に行う。失敗は
  /// 記録だけして続ける（保存のファイル自体は残り、次の起動で拾い直す）。
  Future<void> _persist(String projectId) {
    final previous = _persisting[projectId] ?? Future<void>.value();
    final next = previous.then((_) => _writeIndex(projectId));
    _persisting[projectId] = next;
    return next;
  }

  Future<void> _writeIndex(String projectId) async {
    try {
      final base = await NiaproSerializer.projectsBasePath();
      // 作品ごと消えたあとは書かない（フォルダを作り直さない）。
      if (!Directory('$base/$projectId').existsSync()) return;
      final dir = Directory('$base/$projectId/SaveTree');
      final index = File('${dir.path}/$indexFileName');
      // 読めなかった（まだ読んでいない）一覧は書き換えない。この起動中の
      // 保存は一覧に入らないが、ファイルは残り、次に起動したとき拾い直す。
      // 一覧が無いと確かめられたとき（この起動中に作った作品等）だけ書く
      // （existsSyncは入れないフォルダの中でもfalseになる）。
      if (!_readProjects.contains(projectId) && !_isMissing(index)) return;
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final json = jsonEncode({
        'nodes': [
          for (final n in _nodesByProject[projectId] ?? const <SaveNode>[])
            n.toJson(),
        ],
        'archived': [
          for (final n in _archivedByProject[projectId] ?? const <SaveNode>[])
            n.toJson(),
        ],
        'slotMemos': {
          for (final entry
              in (_slotMemosByProject[projectId] ?? const <int, String>{})
                  .entries)
            '${entry.key}': entry.value,
        },
      });
      // 書き込みと置き換えは同期で行い、途中で別の書き込みが割り込まない
      // ようにする（作品の保存と同じ）。
      File('${index.path}.tmp')
        ..writeAsStringSync(json, flush: true)
        ..renameSync(index.path);
      // 一覧はこの起動の内容と同じになった（この起動中に作った作品も、
      // 次からは書き換えてよい）。
      _readProjects.add(projectId);
      _memosEditedUnread.remove(projectId);
    } catch (error, stack) {
      AppErrorReporter.record(error, stack);
    }
  }

  List<SaveNode> getNodes(String projectId) =>
      List.unmodifiable(_nodesByProject[projectId] ?? []);

  /// A slot memo may exist even before the slot has a saved archive.
  /// null means the user has never named this slot; '' means explicitly blank.
  String? slotMemoOf(String projectId, int slotIndex) =>
      _slotMemosByProject[projectId]?[slotIndex];

  /// Prefer the slot's independent memo, retaining legacy snapshot names
  /// for projects that have no explicit slot memo yet.
  String? slotDisplayMemoOf(String projectId, int slotIndex) {
    final memo = slotMemoOf(projectId, slotIndex);
    if (memo != null) return memo;
    for (final node in _nodesByProject[projectId] ?? const <SaveNode>[]) {
      if (node.slotIndex == slotIndex) return node.comment;
    }
    return null;
  }

  /// Edits metadata only: never changes or deletes .niapro data, thumbnail,
  /// save time or tree relationships. Retain empty memos as explicit clears.
  ///
  /// 戻り値は「メモを保存の一覧と一緒に残せるか」（スロットの番号が
  /// 正しくなければfalse）。保存の一覧をまだ読めていない作品では、まず
  /// 一覧を読み直す：読めれば、それまでに書いたメモごと一覧へ重ねて書く
  /// （[_loadProject]）。読めなければ、メモはこの起動の間だけ持ってfalseを
  /// 返し（画面は保存データを読み込めなかったと知らせる）、一覧を読めた
  /// とき（[loadUnread]・次のメモ）に重ねて書く。
  Future<bool> setSlotMemo(String projectId, int slotIndex, String memo) async {
    if (slotIndex < 0) return false;
    final normalized = memo.trim();
    final bySlot = _slotMemosByProject.putIfAbsent(projectId, () => {});
    if (!_readProjects.contains(projectId)) {
      // 一覧を読めていない間は、保存してあるメモが欄に出ない（空で開く）。
      // メモの無い（空の）スロットを空のまま確定しただけでは、見えて
      // いなかったメモを消したことにしない。この起動で書いたメモを
      // 消したときは、消したことにする。
      if (normalized.isNotEmpty || (bySlot[slotIndex]?.isNotEmpty ?? false)) {
        if (bySlot[slotIndex] != normalized) {
          bySlot[slotIndex] = normalized;
          notifyListeners();
        }
        _memosEditedUnread.putIfAbsent(projectId, () => {}).add(slotIndex);
      }
      await _readListIfReadable(projectId);
      return _readProjects.contains(projectId);
    }
    if (bySlot[slotIndex] == normalized) return true;
    bySlot[slotIndex] = normalized;
    notifyListeners();
    await _persist(projectId);
    return true;
  }

  /// まだ一覧を読めていない作品の保存の一覧を、読めるようになっていれば
  /// 読む（[loadUnread]の1作品分）。ホームの「再試行」が出ない場合
  /// （保存の一覧だけを読めなかった等）も、メモを書いたときに読めるように
  /// する。
  Future<void> _readListIfReadable(String projectId) async {
    final loading = _loadingUnread;
    if (loading != null) await loading;
    try {
      final base = await NiaproSerializer.projectsBasePath();
      if (_readProjects.contains(projectId)) return;
      await _loadProject(projectId, Directory('$base/$projectId/SaveTree'));
    } catch (error, stack) {
      AppErrorReporter.record(error, stack);
    }
    notifyListeners();
  }

  /// Rename a save snapshot without rewriting the archive or changing its
  /// capture time, thumbnail, parent link or slot position.
  ///
  /// Names are stored in the existing index.json so they survive app restarts.
  Future<bool> renameSave(String projectId, String nodeId, String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty) return false;
    final nodes = _nodesByProject[projectId];
    if (nodes == null) return false;
    final index = nodes.indexWhere((node) => node.id == nodeId);
    if (index < 0) return false;
    final old = nodes[index];
    if (old.comment == normalized) return true;
    nodes[index] = SaveNode(
      id: old.id,
      projectId: old.projectId,
      savedAt: old.savedAt,
      comment: normalized,
      thumbnailPath: old.thumbnailPath,
      parentId: old.parentId,
      slotIndex: old.slotIndex,
    );
    notifyListeners();
    await _persist(projectId);
    return true;
  }

  /// この作品の保存のうち一番新しいものの時刻（無ければnull）。保存の画面へ
  /// 移る前と戻った後で比べると、その間に保存したかが分かる。
  DateTime? latestSaveOf(String projectId) {
    DateTime? latest;
    for (final n in _nodesByProject[projectId] ?? const <SaveNode>[]) {
      if (latest == null || n.savedAt.isAfter(latest)) latest = n.savedAt;
    }
    return latest;
  }

  /// [before]（保存の画面へ移る前の[latestSaveOf]）より新しい保存があるか。
  /// 時刻が「変わった」かではなく「新しくなった」かで見る：一番新しい保存を
  /// 消す・退避すると、保存していなくても一番新しい時刻は前の保存へ変わる。
  bool savedSince(String projectId, DateTime? before) {
    final latest = latestSaveOf(projectId);
    return latest != null && (before == null || latest.isAfter(before));
  }

  List<SaveNode> getArchivedNodes(String projectId) =>
      List.unmodifiable(_archivedByProject[projectId] ?? []);

  /// スロット方式：指定スロットへ上書き保存。実データ（シーン・タイル）を
  /// SaveTree/{nodeId}.niaproへ書き込む。
  Future<SaveNode> saveToSlot({
    required String projectId,
    required int slotIndex,
    required Project project,
    required List<Scene> scenes,
    required TileManager tileManager,
    String? comment,
    Uint8List? thumbnailPngBytes,
  }) async {
    assert(
      slotIndex >= 0 && slotIndex < _slotMax,
      'slotIndex must be 0..${_slotMax - 1}',
    );
    _nodesByProject.putIfAbsent(projectId, () => []);
    final old = _nodesByProject[projectId]!
        .where((n) => n.slotIndex == slotIndex)
        .toList();
    final nodeId = _newId();
    // 【重要】既存スロットの差し替えは「新しい保存が完全に書き終わってから」
    // 行う。以前はここより前に removeWhere で既存ノードを一覧から外して
    // いたため、この書き込みが失敗すると（空き容量不足・書き込みエラー等）
    // 新しい保存が作られないまま古い保存だけが失われ、上書き保存の失敗が
    // そのままデータ損失になっていた。書き込み成功後に入れ替えることで、
    // 失敗しても直前の保存がそのまま残るようにする。
    await NiaproSerializer.saveSaveTreeNode(
      project: project,
      scenes: scenes,
      tileManager: tileManager,
      nodeId: nodeId,
    );
    String? thumbnailPath;
    if (thumbnailPngBytes != null) {
      thumbnailPath = await NiaproSerializer.saveSaveTreeThumbnail(
        projectId,
        nodeId,
        thumbnailPngBytes,
      );
    }
    _nodesByProject[projectId]!.removeWhere((n) => n.slotIndex == slotIndex);
    // A newly committed save updates its slot memo only after archive/thumbnail
    // persistence succeeds. An existing empty slot memo is not lost on delete.
    _slotMemosByProject
        .putIfAbsent(projectId, () => {})
        .putIfAbsent(
          slotIndex,
          () => (comment ?? old.firstOrNull?.comment ?? '').trim(),
        );
    final node = SaveNode(
      id: nodeId,
      projectId: projectId,
      savedAt: DateTime.now(),
      comment: comment,
      thumbnailPath: thumbnailPath,
      slotIndex: slotIndex,
    );
    for (final o in old) {
      await _deleteNodeFiles(projectId, o.id);
    }
    _nodesByProject[projectId]!.add(node);
    notifyListeners();
    await _persist(projectId);
    _notifySuccessfulManualSave(projectId);
    return node;
  }

  /// ツリー方式：親ノードから枝分かれして保存。実データ（シーン・タイル）を
  /// SaveTree/{nodeId}.niaproへ書き込む。
  Future<SaveNode> saveAsChild({
    required String projectId,
    required Project project,
    required List<Scene> scenes,
    required TileManager tileManager,
    String? parentId,
    String? comment,
    Uint8List? thumbnailPngBytes,
  }) async {
    _nodesByProject.putIfAbsent(projectId, () => []);
    final nodeId = _newId();
    await NiaproSerializer.saveSaveTreeNode(
      project: project,
      scenes: scenes,
      tileManager: tileManager,
      nodeId: nodeId,
    );
    String? thumbnailPath;
    if (thumbnailPngBytes != null) {
      thumbnailPath = await NiaproSerializer.saveSaveTreeThumbnail(
        projectId,
        nodeId,
        thumbnailPngBytes,
      );
    }
    final node = SaveNode(
      id: nodeId,
      projectId: projectId,
      savedAt: DateTime.now(),
      comment: comment,
      thumbnailPath: thumbnailPath,
      parentId: parentId,
      slotIndex: -1,
    );
    _nodesByProject[projectId]!.add(node);
    notifyListeners();
    await _persist(projectId);
    _notifySuccessfulManualSave(projectId);
    return node;
  }

  /// 指定ノードの実データを読み込む（復元用）。ファイルが存在しない・
  /// 破損している場合はnullを返す。
  Future<NiaproData?> loadNode(String projectId, String nodeId) async {
    try {
      return await NiaproSerializer.loadSaveTreeNode(projectId, nodeId);
    } catch (_) {
      return null;
    }
  }

  /// ノードの実データとサムネイルを消す。容量削減の画面が覚えている集計結果は
  /// 消す前のものなので、捨てさせる（途中で失敗しても、消せた分だけ大きさは
  /// 変わっている）。
  Future<void> _deleteNodeFiles(String projectId, String nodeId) async {
    try {
      await NiaproSerializer.deleteSaveTreeNode(projectId, nodeId);
    } finally {
      StorageInfoService().invalidate();
    }
  }

  Future<void> deleteNode(String projectId, String nodeId) async {
    _nodesByProject[projectId]?.removeWhere((n) => n.id == nodeId);
    notifyListeners();
    await _deleteNodeFiles(projectId, nodeId);
    await _persist(projectId);
  }

  List<SaveNode> getChildren(String projectId, String? parentId) {
    return (_nodesByProject[projectId] ?? [])
        .where((n) => n.parentId == parentId)
        .toList();
  }

  List<int> getUsedSlots(String projectId) {
    return (_nodesByProject[projectId] ?? [])
        .where((n) => n.slotIndex >= 0)
        .map((n) => n.slotIndex)
        .toList();
  }

  /// 保存データ変更フロー専用処理
  /// （ツリー→スロット変換・スロット数削減）
  /// [keepIds] 保持するノードID一覧
  /// [archive] true=アーカイブ、false=完全削除（実ファイルも削除する）
  /// [newSlotMax] スロット方式の場合の新スロット数（null=ツリー方式へ変更）
  Future<void> applyModeChange({
    required String projectId,
    required List<String> keepIds,
    required bool archive,
    required bool newIsTreeMode,
    int? newSlotMax,
  }) async {
    final all = _nodesByProject[projectId] ?? [];
    final keep = all.where((n) => keepIds.contains(n.id)).toList();
    final discard = all.where((n) => !keepIds.contains(n.id)).toList();

    if (archive) {
      _archivedByProject.putIfAbsent(projectId, () => []);
      _archivedByProject[projectId]!.addAll(discard);
    } else {
      // 完全削除：実データ（SaveTree/{nodeId}.niapro）も削除する
      for (final n in discard) {
        await _deleteNodeFiles(projectId, n.id);
      }
    }

    // スロット方式の場合、選択ノードにスロット番号を再割り当て
    List<SaveNode> newNodes;
    if (!newIsTreeMode) {
      newNodes = keep.asMap().entries.map((e) {
        return SaveNode(
          id: e.value.id,
          projectId: e.value.projectId,
          savedAt: e.value.savedAt,
          comment: e.value.comment,
          thumbnailPath: e.value.thumbnailPath,
          slotIndex: e.key,
        );
      }).toList();
      if (newSlotMax != null) _slotMax = newSlotMax;
    } else {
      newNodes = keep
          .map(
            (n) => SaveNode(
              id: n.id,
              projectId: n.projectId,
              savedAt: n.savedAt,
              comment: n.comment,
              thumbnailPath: n.thumbnailPath,
              parentId: null,
              slotIndex: -1,
            ),
          )
          .toList();
    }

    _nodesByProject[projectId] = newNodes;
    _isTreeMode = newIsTreeMode;
    notifyListeners();
    await _persist(projectId);
  }

  /// スロット→ツリー方式へ変更した時にアーカイブを自動復元（外部呼び出し用）
  void restoreArchive(String projectId) {
    final archived = _archivedByProject[projectId];
    if (archived == null || archived.isEmpty) return;
    _nodesByProject.putIfAbsent(projectId, () => []);
    _nodesByProject[projectId]!.addAll(archived);
    _archivedByProject[projectId] = [];
    notifyListeners();
    unawaited(_persist(projectId));
  }
}
