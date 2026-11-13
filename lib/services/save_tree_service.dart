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
    _fitAllIntoSlots();
    notifyListeners();
  }

  void setTreeMode(bool treeMode) {
    _isTreeMode = treeMode;
    _fitAllIntoSlots();
    notifyListeners();
  }

  /// スロット方式で、今のスロットに無い保存（ツリー方式で保存した・減らした
  /// スロットにあった）を、読んだ作品ごとに空いているスロットへ入れる
  /// （[_fitIntoSlots]）。以前は方式・スロット数を変えても保存のスロットは
  /// そのままで、スロットの画面のどこにも出なかった（次の起動でも同じ）。
  void _fitAllIntoSlots() {
    if (_isTreeMode) return;
    for (final projectId in [..._nodesByProject.keys]) {
      if (_fitIntoSlots(projectId)) unawaited(_persist(projectId));
    }
  }

  /// [projectId]の、今のスロットに無い保存を、古い順に空いているスロットへ
  /// 入れる（メモだけが付いたスロットは後回し。書いている途中の保存の
  /// スロットには入れない）。全部が入りきらないときは何も動かさない（保存
  /// 方式を変える画面で残す保存を選ぶ。選ばずに次に起動したときは、一覧に
  /// 無い保存と同じく空いているスロットへ入れ、残りは退避する。
  /// [_loadProject]）。保存の名前（減らしたスロットのメモ、ツリー方式の
  /// 保存のコメント）は、名前の無い入れ先のスロットへ持っていく。入れた
  /// 保存があればtrue。
  bool _fitIntoSlots(String projectId) {
    final nodes = _nodesByProject[projectId];
    if (_isTreeMode || nodes == null) return false;
    bool inSlots(SaveNode n) => n.slotIndex >= 0 && n.slotIndex < _slotMax;
    final outside = [
      for (final n in nodes)
        if (!inSlots(n)) n,
    ]..sort((a, b) => a.savedAt.compareTo(b.savedAt));
    if (outside.isEmpty) return false;
    final taken = {
      for (final n in nodes)
        if (inSlots(n)) n.slotIndex,
      for (final s in _saving[projectId] ?? const <SlotSave>[])
        if (s.slotIndex >= 0) s.slotIndex,
    };
    if (outside.length > _slotMax - taken.where((i) => i < _slotMax).length) {
      return false;
    }
    final memos = _slotMemosByProject.putIfAbsent(projectId, () => {});
    bool labelled(int slot) => memos[slot]?.isNotEmpty ?? false;
    var changed = false;
    for (final node in outside) {
      final used = {
        for (final n in nodes)
          if (inSlots(n)) n.slotIndex,
        for (final s in _saving[projectId] ?? const <SlotSave>[])
          if (s.slotIndex >= 0) s.slotIndex,
      };
      int? free;
      for (final skipLabelled in [true, false]) {
        for (var i = 0; i < _slotMax && free == null; i++) {
          if (!used.contains(i) && !(skipLabelled && labelled(i))) free = i;
        }
      }
      if (free == null) break;
      final name =
          (node.slotIndex >= 0 && labelled(node.slotIndex)
                  ? memos[node.slotIndex]
                  : node.comment)
              ?.trim();
      if (name != null && name.isNotEmpty && !labelled(free)) {
        memos[free] = name;
        _slotMemoTimes.putIfAbsent(projectId, () => {})[free] = DateTime.now();
      }
      nodes
        ..remove(node)
        ..add(
          SaveNode(
            id: node.id,
            projectId: node.projectId,
            savedAt: node.savedAt,
            comment: node.comment,
            thumbnailPath: node.thumbnailPath,
            parentId: node.parentId,
            slotIndex: free,
          ),
        );
      changed = true;
    }
    return changed;
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

  /// 一覧を読めない間の保存の控え（`{保存のID}.pending.json`、保存のファイルの
  /// 隣）の名前の終わり。一覧へ書けない間、保存ごとにスロット・コメント・
  /// 親と、その起動で書いたそのスロットのメモを書く（[_writePendingSaves]）。
  /// 次に一覧を読めたとき（次の起動を含む）、[_loadProject]がこの起動の
  /// 保存と同じく一覧へ重ね、一覧を書けたら消す。控えが無いと、読めない間の
  /// 保存は次の起動で一覧に無いファイルとして拾い直され、コメントも
  /// スロットも失った（空いた最初のスロットへ入り、メモだけのスロットなら
  /// そのメモの名前で呼ばれた）。
  static const String pendingSuffix = '.pending.json';

  /// スロットのメモを利用者が書いた時刻（作品ごと、[setSlotMemo]）。一覧
  /// （`slotMemoTimes`）と控え（`memoAt`）にも書く。控えのメモは、一覧の
  /// そのスロットのメモが控えより後に書かれていないときだけ使う（後の起動で
  /// 書き直した名前を、前の起動の控えの古いメモで置き換えていた）。
  final Map<String, Map<int, DateTime>> _slotMemoTimes = {};

  /// 控えを読めなかった保存（作品ごと、保存のID→拾ったときの保存）。一覧に
  /// 無いファイルとして拾って見せるが、拾ったときのまま（利用者が名前を
  /// 変える・動かす・そのスロットに名前を付ける等をしていない）なら一覧へ
  /// 書かない。控えは消さないので、控えを読めたとき（次の起動を含む）に
  /// スロットとコメントごと戻る（以前は拾った後に控えを消し、読めるように
  /// なっても戻らなかった）。
  final Map<String, Map<String, SaveNode>> _heldSaves = {};

  /// 保存先にあると分かっている控え（作品ごと、保存のID）。一覧を書けたら、
  /// 一覧に入った保存の控えを消す。
  final Map<String, Set<String>> _pendingIds = {};

  /// 保存の一覧を読もうとして読めなかった作品（一覧を開けない・保存の
  /// フォルダに入れない）。読めるまで、この起動の保存しか出ない。
  final Set<String> _unreadLists = {};

  /// 書いている途中の保存（作品ごと）：保存の画面で「保存」を押してから
  /// （[beginSlotSave]）、または[saveToSlot]・[saveAsChild]を呼んでから、
  /// 終わるまで。その間に一覧を読んだとき（「再試行」等）、[_loadProject]は
  /// 書いている保存のファイルを一覧に無い保存として拾わず（拾うと、保存が
  /// 終わったときに同じ保存が2つ並んだ）、保存先のスロットにあった一覧の
  /// 保存は、この起動の保存と同じく空いているスロットへ移す（そのスロットに
  /// 置くと、保存が終わったときに、確かめていない保存を差し替えて消した）。
  final Map<String, List<SlotSave>> _saving = {};

  /// 保存の画面で「保存」を押したときに呼ぶ（サムネイルを作る前）。押した
  /// ときに見せていたスロットの中身で保存する：[replacing]は上書きを確かめた
  /// 保存のID（空に見えたスロットはnull）。返した[SlotSave]を[saveToSlot]の
  /// `intent`へ渡し、保存が終わったら（失敗・取りやめも）[SlotSave.end]を呼ぶ。
  /// それまで、そのスロットは保存中として扱う。
  SlotSave beginSlotSave(String projectId, int slotIndex, {String? replacing}) {
    final save = SlotSave._(this, projectId, slotIndex, replacing);
    _saving.putIfAbsent(projectId, () => []).add(save);
    return save;
  }

  /// [projectId]の保存の一覧を読めなかったか。保存の画面は、空に見える
  /// スロットを「保存データなし」と言わず、読めなかったことと「再試行」
  /// （[retryReadList]）を出す。
  bool saveListUnreadable(String projectId) => _unreadLists.contains(projectId);

  /// 保存の画面の「再試行」：読めなかった保存の一覧を読み直す（この起動の
  /// 保存とメモは、読んだ一覧へ重ねる。[_loadProject]）。読めたらtrue。
  Future<bool> retryReadList(String projectId) async {
    await _readListIfReadable(projectId);
    return _readProjects.contains(projectId);
  }

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
    // 書いている途中の保存（[_saving]）も、この起動の保存と同じく扱う：
    // そのスロットにあった一覧の保存は空いているスロットへ移し、書いている
    // 保存のファイルは一覧に無い保存として拾わない。
    final saving = _saving[projectId] ?? const <SlotSave>[];
    final sessionSlots = {
      if (!_isTreeMode)
        for (final n in sessionNodes)
          if (n.slotIndex >= 0) n.slotIndex,
      if (!_isTreeMode)
        for (final s in saving)
          if (s.slotIndex >= 0) s.slotIndex,
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
      _unreadLists.add(projectId);
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
        _unreadLists.remove(projectId);
        if (editedMemos.isNotEmpty || sessionIds.isNotEmpty) {
          await _persist(projectId);
        }
        return;
      }
    } catch (error, stack) {
      AppErrorReporter.record(error, stack);
      if (text == null) {
        _unreadLists.add(projectId);
        return;
      }
    }
    String? thumbnailOf(String id) {
      final file = File('${dir.path}/${id}_thumb.png');
      return file.existsSync() ? file.path : null;
    }

    bool hasData(String id) => File('${dir.path}/$id.niapro').existsSync();
    // 前の起動で、一覧を読めない間にした保存の控え（[_writePendingSaves]）。
    // 古い順に、この起動の保存と同じく下で一覧へ重ねる。読めない控えは
    // 消さず、その保存は一覧に無いファイルとして拾うが、控えを読めるまで
    // 拾った置き場所を一覧へ書かない（[_heldSaves]）。
    final pending = <SaveNode>[];
    final pendingArchived = <String>{};
    final pendingMemos = <String, String>{};
    // 控えのメモを書いた時刻（古い控えは保存した時刻）。
    final pendingMemoTimes = <String, DateTime>{};
    // 保存のある控え（一覧を書いたら消す）。
    var pendingOnDisk = false;
    // 読めない控え（権限・入出力の失敗）の保存。控えは消さない。
    final unreadNotes = <String>{};
    for (final file in files) {
      final name = file.uri.pathSegments.last;
      if (!name.endsWith(pendingSuffix)) continue;
      final id = name.substring(0, name.length - pendingSuffix.length);
      if (!hasData(id)) continue;
      pendingOnDisk = true;
      final Object? json;
      try {
        json = sessionIds.contains(id)
            ? null
            : jsonDecode(
                utf8.decode(file.readAsBytesSync(), allowMalformed: true),
              );
      } on PathNotFoundException {
        continue;
      } on FileSystemException catch (error, stack) {
        AppErrorReporter.record(error, stack);
        unreadNotes.add(id);
        continue;
      } on FormatException catch (error, stack) {
        // 壊れた控えは、読めるようになることが無いので消してよい。
        AppErrorReporter.record(error, stack);
        _pendingIds.putIfAbsent(projectId, () => {}).add(id);
        continue;
      }
      // 読めた控え（一覧に入ったら消す）。
      _pendingIds.putIfAbsent(projectId, () => {}).add(id);
      if (sessionIds.contains(id)) continue;
      try {
        if (json is! Map) continue;
        final node = SaveNode.fromJson(
          json['node'],
          projectId: projectId,
          thumbnailPath: thumbnailOf(id),
        );
        if (node == null || node.id != id) continue;
        pending.add(node);
        if (json['archived'] == true) pendingArchived.add(id);
        final memo = json['memo'];
        if (memo is String) {
          pendingMemos[id] = memo;
          final memoAt = json['memoAt'];
          pendingMemoTimes[id] =
              (memoAt is String ? DateTime.tryParse(memoAt) : null) ??
              node.savedAt;
        }
      } catch (error, stack) {
        AppErrorReporter.record(error, stack);
      }
    }
    pending.sort((a, b) => a.savedAt.compareTo(b.savedAt));
    final nodes = <SaveNode>[];
    final archived = <SaveNode>[];
    // この起動の保存は、一覧からも、一覧に無いファイルとしても拾わない。
    final known = <String>{...sessionIds, for (final s in saving) ?s.nodeId};
    // 一覧の保存のうち、この起動で保存したスロットにあったもの。
    final displaced = <SaveNode>[];
    // 一覧にあったスロットのメモ（この起動で書いたメモを重ねる前）。
    final diskMemos = <int, String>{};
    // 一覧にあったスロットのメモを書いた時刻（[_slotMemoTimes]）。
    final diskMemoTimes = <int, DateTime>{};
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
            diskMemos.addAll(memos);
            memos.addAll(editedMemos);
            if (memos.isNotEmpty) _slotMemosByProject[projectId] = memos;
          }
          final rawTimes = json['slotMemoTimes'];
          if (rawTimes is Map) {
            for (final entry in rawTimes.entries) {
              final slot = int.tryParse(entry.key.toString());
              final at = entry.value is String
                  ? DateTime.tryParse(entry.value as String)
                  : null;
              if (slot != null && at != null) diskMemoTimes[slot] = at;
            }
          }
          for (final (key, into) in [
            ('nodes', nodes),
            ('archived', archived),
          ]) {
            final list = json[key];
            if (list is! List) continue;
            // 同じIDが2つある一覧（書いている保存を拾ってしまった前の版）は、
            // 後の方（保存が終わったときに入れた方）を使う。
            final lastOf = <Object?, Object?>{
              for (final item in list)
                if (item is Map) item['id']: item,
            };
            for (final item in list) {
              final id = item is Map ? item['id'] : null;
              // 実データの無い保存は出さない（開くと失敗するため）。
              if (id is! String ||
                  known.contains(id) ||
                  !hasData(id) ||
                  !identical(lastOf[id], item)) {
                continue;
              }
              final node = SaveNode.fromJson(
                item,
                projectId: projectId,
                thumbnailPath: thumbnailOf(id),
              );
              if (node == null) continue;
              known.add(id);
              // 今のスロットに無い保存（ツリー方式で保存した・スロット数を
              // 減らした）も、空いているスロットへ移す（以前の版は方式を
              // 変えても移さず、どのスロットにも出なかった）。
              if (identical(into, nodes) &&
                  (sessionSlots.contains(node.slotIndex) ||
                      (!_isTreeMode &&
                          (node.slotIndex < 0 ||
                              node.slotIndex >= _slotMax)))) {
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
    // 控えの保存を、この起動の保存と同じく重ねる：保存したスロットへ入れ、
    // そこにあった保存は（新しい方が残り）消さずに空いているスロットへ移す。
    // 一覧にある保存の控え（一覧を書いた後に消せなかったもの）は一覧のまま。
    pending.removeWhere((p) => known.contains(p.id));
    known.addAll([for (final p in pending) p.id]);
    final claimed = <int, SaveNode>{};
    for (final p in pending) {
      if (pendingArchived.contains(p.id)) {
        archived.add(p);
        continue;
      }
      if (_isTreeMode) {
        nodes.add(p);
        continue;
      }
      // 今のスロットに無い番号（スロット数を減らした・ツリー方式で保存した
      // 枝）は、この起動の保存に譲った保存と同じく空いているスロットへ
      // （無ければ退避へ）、コメント・親・控えのメモごと移す（番号のまま
      // 置くと、どのスロットにも退避にも出ず、見えなかった）。
      if (p.slotIndex < 0 ||
          p.slotIndex >= _slotMax ||
          sessionSlots.contains(p.slotIndex)) {
        displaced.add(p);
        continue;
      }
      final i = nodes.indexWhere((n) => n.slotIndex == p.slotIndex);
      if (i >= 0) {
        if (nodes[i].savedAt.isAfter(p.savedAt)) {
          displaced.add(p);
          continue;
        }
        displaced.add(nodes.removeAt(i));
      }
      nodes.add(p);
      claimed[p.slotIndex] = p;
    }
    // スロットのメモを書いた時刻：一覧の時刻に、この起動で書いたメモの時刻を
    // 重ねる。
    final memoTimes = {...diskMemoTimes, ...?_slotMemoTimes[projectId]};
    // 控えのメモ（その起動で書いたスロットのメモ）は、入ったスロットへ
    // （この起動で書いたメモと、一覧のそのスロットに控えより後に書いた
    // メモが勝つ）。
    for (final MapEntry(key: slot, value: p) in claimed.entries) {
      final memo = pendingMemos[p.id];
      if (memo == null || editedMemos.containsKey(slot)) continue;
      final at = pendingMemoTimes[p.id]!;
      if (memoTimes[slot]?.isAfter(at) ?? false) continue;
      _slotMemosByProject.putIfAbsent(projectId, () => {})[slot] = memo;
      memoTimes[slot] = at;
    }
    final pendingIds = {for (final p in pending) p.id};
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
      // 譲った保存は、メモだけが付いた空きスロットを避け（入るとそのメモの
      // 名前で呼ばれた）、一覧にあった自分のメモを移した先へ持っていく。
      bool labelled(int slot) =>
          _slotMemosByProject[projectId]?[slot]?.isNotEmpty ?? false;
      for (final orphan in [...displaced, ...orphans]) {
        final moving = displaced.contains(orphan);
        int? free;
        for (final skipLabelled in moving ? [true, false] : [false]) {
          for (var i = 0; i < _slotMax && free == null; i++) {
            if (!used.contains(i) && !(skipLabelled && labelled(i))) free = i;
          }
        }
        if (free == null) {
          archived.add(orphan);
          continue;
        }
        used.add(free);
        final from = orphan.slotIndex;
        // 控えの保存が譲ったときは自分の控えのメモ（元のスロットの一覧の
        // メモは、そこにあった一覧の保存のもの）。
        final ownPending = pendingIds.contains(orphan.id);
        final memo = ownPending ? pendingMemos[orphan.id] : diskMemos[from];
        if (moving && memo != null && memo.isNotEmpty && !labelled(free)) {
          final memos = _slotMemosByProject.putIfAbsent(projectId, () => {});
          memos[free] = memo;
          final at = ownPending
              ? pendingMemoTimes[orphan.id]
              : diskMemoTimes[from];
          if (at != null) {
            memoTimes[free] = at;
          } else {
            memoTimes.remove(free);
          }
          // コメントを空にして保存した（メモを書いていない）スロットには、
          // 譲った保存のメモを残さない（新しい保存がそのメモで呼ばれ、
          // 2つのスロットが同じ名前になった）。移せなかったメモは消さない。
          final edited =
              (_memosEditedUnread[projectId]?.contains(from) ?? false) ||
              pendingMemos.containsKey(claimed[from]?.id);
          final blank =
              [...sessionNodes, ...claimed.values].any(
                (n) =>
                    n.slotIndex == from && (n.comment?.trim().isEmpty ?? true),
              ) ||
              saving.any(
                (s) =>
                    s.slotIndex == from &&
                    s.nodeId != null &&
                    (s.comment?.trim().isEmpty ?? true),
              );
          if (!ownPending && !edited && blank && memos[from] == memo) {
            memos[from] = '';
            memoTimes.remove(from);
          }
        }
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
    // 控えを読めなかった保存は、拾ったときのまま一覧へ書かない（[_heldSaves]）。
    final held = {
      for (final n in [...nodes, ...archived])
        if (unreadNotes.contains(n.id)) n.id: n,
    };
    if (held.isEmpty) {
      _heldSaves.remove(projectId);
    } else {
      _heldSaves[projectId] = held;
    }
    nodes.addAll(sessionNodes);
    archived.addAll(sessionArchived);
    _readProjects.add(projectId);
    _unreadLists.remove(projectId);
    _slotMemoTimes[projectId] = memoTimes;
    if (nodes.isEmpty && archived.isEmpty) {
      if (editedMemos.isNotEmpty) await _persist(projectId);
      return;
    }
    _nodesByProject[projectId] = nodes;
    if (archived.isNotEmpty) _archivedByProject[projectId] = archived;
    if (orphans.isNotEmpty ||
        displaced.isNotEmpty ||
        editedMemos.isNotEmpty ||
        sessionIds.isNotEmpty ||
        pendingOnDisk) {
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
      if (!_readProjects.contains(projectId) && !_isMissing(index)) {
        _writePendingSaves(projectId, dir);
        return;
      }
      if (!dir.existsSync()) dir.createSync(recursive: true);
      // 控えを読めなかった保存は、拾ったときのままなら書かない。
      final held = _heldSaves[projectId] ?? const <String, SaveNode>{};
      final json = jsonEncode({
        'nodes': [
          for (final n in _nodesByProject[projectId] ?? const <SaveNode>[])
            if (!identical(held[n.id], n)) n.toJson(),
        ],
        'archived': [
          for (final n in _archivedByProject[projectId] ?? const <SaveNode>[])
            if (!identical(held[n.id], n)) n.toJson(),
        ],
        'slotMemos': {
          for (final entry
              in (_slotMemosByProject[projectId] ?? const <int, String>{})
                  .entries)
            '${entry.key}': entry.value,
        },
        if (_slotMemoTimes[projectId]?.isNotEmpty ?? false)
          'slotMemoTimes': {
            for (final entry in _slotMemoTimes[projectId]!.entries)
              '${entry.key}': entry.value.toIso8601String(),
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
      _unreadLists.remove(projectId);
      _memosEditedUnread.remove(projectId);
      _deletePendingSaves(projectId, dir);
    } catch (error, stack) {
      AppErrorReporter.record(error, stack);
    }
  }

  /// 保存の一覧へ書けない間（一覧を読めていない）、この起動の保存ごとに
  /// 控えを書く（[pendingSuffix]）。一覧を読めていない間の保存の一覧には
  /// この起動の保存しか無い。
  void _writePendingSaves(String projectId, Directory dir) {
    final edited = _memosEditedUnread[projectId] ?? const <int>{};
    final memos = _slotMemosByProject[projectId] ?? const <int, String>{};
    for (final (node, archived) in [
      for (final n in _nodesByProject[projectId] ?? const <SaveNode>[])
        (n, false),
      for (final n in _archivedByProject[projectId] ?? const <SaveNode>[])
        (n, true),
    ]) {
      // メモは、この起動で書いたスロットのものだけ（書いていなければ、
      // 一覧のメモのまま）。
      final memo = node.slotIndex >= 0 && edited.contains(node.slotIndex)
          ? memos[node.slotIndex]
          : null;
      final memoAt = memo == null
          ? null
          : _slotMemoTimes[projectId]?[node.slotIndex];
      try {
        final file = File('${dir.path}/${node.id}$pendingSuffix');
        File('${file.path}.tmp')
          ..writeAsStringSync(
            jsonEncode({
              'node': node.toJson(),
              if (archived) 'archived': true,
              'memo': ?memo,
              'memoAt': ?memoAt?.toIso8601String(),
            }),
            flush: true,
          )
          ..renameSync(file.path);
        _pendingIds.putIfAbsent(projectId, () => {}).add(node.id);
      } catch (error, stack) {
        AppErrorReporter.record(error, stack);
      }
    }
  }

  /// 一覧を書けたので、一覧に入った保存の控えを消す（消せなかった控えは、
  /// 次に読んだとき一覧にあるので使わず、次に一覧を書いたときに消し直す）。
  void _deletePendingSaves(String projectId, Directory dir) {
    final pending = _pendingIds[projectId];
    if (pending == null || pending.isEmpty) return;
    final listed = {
      for (final n in [
        ..._nodesByProject[projectId] ?? const <SaveNode>[],
        ..._archivedByProject[projectId] ?? const <SaveNode>[],
      ])
        n.id,
    };
    pending.removeWhere((id) {
      if (!listed.contains(id)) return false;
      try {
        File('${dir.path}/$id$pendingSuffix').deleteSync();
      } on PathNotFoundException {
        // もう無い。
      } catch (error, stack) {
        AppErrorReporter.record(error, stack);
        return false;
      }
      return true;
    });
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
        _slotMemoTimes.putIfAbsent(projectId, () => {})[slotIndex] =
            DateTime.now();
        // この起動でそのスロットへ保存していれば、メモを保存の控えにも
        // 書く（次に一覧を読めたとき、次の起動でも保存と一緒に戻る）。
        await _persist(projectId);
      }
      await _readListIfReadable(projectId);
      return _readProjects.contains(projectId);
    }
    if (bySlot[slotIndex] == normalized) return true;
    bySlot[slotIndex] = normalized;
    // 控えを読めなかった保存のスロットに名前を付けたら、その保存は今の
    // スロットのまま一覧へ書く。
    _heldSaves[projectId]?.removeWhere((_, n) => n.slotIndex == slotIndex);
    _slotMemoTimes.putIfAbsent(projectId, () => {})[slotIndex] = DateTime.now();
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
  ///
  /// [intent]は、保存の画面で「保存」を押したときの[beginSlotSave]。渡すと、
  /// 押したときに見せていた保存（上書きを確かめた保存）だけを差し替え、
  /// それ以外にスロットへ入っていた保存は消さずに空いているスロットへ移す。
  /// 渡さないと、呼んだときにスロットにある保存を差し替える。
  Future<SaveNode> saveToSlot({
    required String projectId,
    required int slotIndex,
    required Project project,
    required List<Scene> scenes,
    required TileManager tileManager,
    String? comment,
    Uint8List? thumbnailPngBytes,
    SlotSave? intent,
  }) async {
    assert(
      intent == null ||
          (intent.projectId == projectId && intent.slotIndex == slotIndex),
    );
    final save = intent ?? beginSlotSave(projectId, slotIndex);
    try {
      return await _saveToSlot(
        save: save,
        confirmedOnly: intent != null,
        projectId: projectId,
        slotIndex: slotIndex,
        project: project,
        scenes: scenes,
        tileManager: tileManager,
        comment: comment,
        thumbnailPngBytes: thumbnailPngBytes,
      );
    } finally {
      if (intent == null) save.end();
    }
  }

  Future<SaveNode> _saveToSlot({
    required SlotSave save,
    required bool confirmedOnly,
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
    // 差し替える保存。保存の画面から押したときは、押したときに見せていた
    // 保存（空に見えたスロットなら無し）だけ。
    final old = _nodesByProject[projectId]!
        .where(
          (n) =>
              n.slotIndex == slotIndex &&
              (!confirmedOnly || n.id == save.replacing),
        )
        .toList();
    final nodeId = _newId();
    save
      ..nodeId = nodeId
      ..comment = comment;
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
      thumbnailPath = await _saveThumbnail(
        projectId,
        nodeId,
        thumbnailPngBytes,
      );
    }
    // 差し替えるのは、確かめた保存がまだこのスロットにあるときだけ。書いて
    // いる間にこのスロットへ入った、差し替えを確かめていない保存（押す前に
    // 読んだ一覧の保存等）は、消さずに空いているスロットへ移す。
    final nodes = _nodesByProject[projectId]!;
    final inSlot = [
      for (final n in nodes)
        if (n.slotIndex == slotIndex && n.id != nodeId) n,
    ];
    final replaced = [
      for (final n in inSlot)
        if (old.any((o) => o.id == n.id)) n,
    ];
    nodes.removeWhere((n) => n.slotIndex == slotIndex || n.id == nodeId);
    for (final n in inSlot) {
      if (!replaced.contains(n)) _moveAside(projectId, n, slotIndex);
    }
    // A newly committed save updates its slot memo only after archive/thumbnail
    // persistence succeeds. An existing empty slot memo is not lost on delete.
    _slotMemosByProject
        .putIfAbsent(projectId, () => {})
        .putIfAbsent(
          slotIndex,
          () => (comment ?? replaced.firstOrNull?.comment ?? '').trim(),
        );
    final node = SaveNode(
      id: nodeId,
      projectId: projectId,
      savedAt: DateTime.now(),
      comment: comment,
      thumbnailPath: thumbnailPath,
      slotIndex: slotIndex,
    );
    for (final o in replaced) {
      try {
        await _deleteNodeFiles(projectId, o.id);
      } on FileSystemException catch (error, stack) {
        // 新しい保存は書けたので失敗にしない。消せなかった前の保存は
        // ファイルが残っているので、消さずに空いているスロットへ残す。
        AppErrorReporter.record(error, stack);
        _moveAside(projectId, o, slotIndex);
      }
    }
    _nodesByProject[projectId]!.add(node);
    notifyListeners();
    await _persist(projectId);
    _notifySuccessfulManualSave(projectId);
    return node;
  }

  /// 保存のサムネイルを書く。書けなかったら（空き容量が無い等）記録して、
  /// サムネイルの無い保存にする（null。書きかけのファイルは消す）。保存の
  /// 中身（.niapro）は書けているので、保存を失敗にしない：以前は保存全体を
  /// 失敗にし、書けた保存のファイルが一覧に無いまま残り、次の起動で名前の
  /// 無い保存として戻った（もう一度保存した利用者には同じ保存が2つ）。
  Future<String?> _saveThumbnail(
    String projectId,
    String nodeId,
    Uint8List pngBytes,
  ) async {
    try {
      return await NiaproSerializer.saveSaveTreeThumbnail(
        projectId,
        nodeId,
        pngBytes,
      );
    } catch (error, stack) {
      AppErrorReporter.record(error, stack);
      try {
        final base = await NiaproSerializer.projectsBasePath();
        File('$base/$projectId/SaveTree/${nodeId}_thumb.png').deleteSync();
      } on FileSystemException {
        // 書き始めていない・消せない（保存は表示の代わりの絵で出る）。
      }
      return null;
    }
  }

  /// [node]を空いているスロットへ移す（メモだけが付いたスロットは避ける。
  /// 空きが無ければ退避する。ツリー方式へ変えると出る）。保存は消さない。
  /// [slotIndex]（いま保存しているスロット）と、書いている途中の保存の
  /// スロットにも入れない。
  void _moveAside(String projectId, SaveNode node, int slotIndex) {
    final nodes = _nodesByProject.putIfAbsent(projectId, () => []);
    final memos = _slotMemosByProject[projectId] ?? const <int, String>{};
    final used = {
      slotIndex,
      for (final n in nodes)
        if (n.slotIndex >= 0) n.slotIndex,
      for (final s in _saving[projectId] ?? const <SlotSave>[])
        if (s.slotIndex >= 0) s.slotIndex,
    };
    int? free;
    for (final skipLabelled in [true, false]) {
      for (var i = 0; i < _slotMax && free == null; i++) {
        if (used.contains(i)) continue;
        if (skipLabelled && (memos[i]?.isNotEmpty ?? false)) continue;
        free = i;
      }
    }
    final moved = SaveNode(
      id: node.id,
      projectId: node.projectId,
      savedAt: node.savedAt,
      comment: node.comment,
      thumbnailPath: node.thumbnailPath,
      parentId: node.parentId,
      slotIndex: free ?? node.slotIndex,
    );
    if (free == null) {
      _archivedByProject.putIfAbsent(projectId, () => []).add(moved);
    } else {
      nodes.add(moved);
    }
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
    // 書いている間に一覧を読んでも、このファイルを一覧に無い保存として拾わ
    // ない（[_saving]）。書き終えたら、待たずにすぐ一覧へ入れる。
    final save = SlotSave._(this, projectId, -1, null)..nodeId = nodeId;
    _saving.putIfAbsent(projectId, () => []).add(save);
    String? thumbnailPath;
    try {
      await NiaproSerializer.saveSaveTreeNode(
        project: project,
        scenes: scenes,
        tileManager: tileManager,
        nodeId: nodeId,
      );
      if (thumbnailPngBytes != null) {
        thumbnailPath = await _saveThumbnail(
          projectId,
          nodeId,
          thumbnailPngBytes,
        );
      }
    } finally {
      save.end();
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
  ///
  /// 保存（.niapro）を消せた後の後片付け（サムネイル・控え）が失敗しても、
  /// 記録して続ける（保存を書き終えた・消し終えた後で[saveToSlot]・
  /// [deleteNode]を失敗にしない）。残ったサムネイル・控えは、保存が無いので
  /// 次に一覧を読んだときも使わない（[_loadProject]）。保存を消せなかった
  /// ときは呼び出し元へ投げる。
  Future<void> _deleteNodeFiles(String projectId, String nodeId) async {
    try {
      try {
        await NiaproSerializer.deleteSaveTreeNode(projectId, nodeId);
      } on FileSystemException catch (error, stack) {
        final base = await NiaproSerializer.projectsBasePath();
        if (!_isMissing(File('$base/$projectId/SaveTree/$nodeId.niapro'))) {
          rethrow;
        }
        AppErrorReporter.record(error, stack);
      }
      // 消した保存の控え（一覧を読めない間に書いたもの）も消す。
      final heldNote = _heldSaves[projectId]?.remove(nodeId) != null;
      if ((_pendingIds[projectId]?.remove(nodeId) ?? false) || heldNote) {
        try {
          final base = await NiaproSerializer.projectsBasePath();
          File('$base/$projectId/SaveTree/$nodeId$pendingSuffix').deleteSync();
        } on PathNotFoundException {
          // もう無い。
        } on FileSystemException catch (error, stack) {
          AppErrorReporter.record(error, stack);
        }
      }
    } finally {
      StorageInfoService().invalidate();
    }
  }

  /// 保存を消す。保存（.niapro）を消せなかったときは、一覧から外さずに
  /// 投げる（保存の画面は消せなかったことを知らせる）。以前は先に一覧から
  /// 外して知らせていたので、消せなかった保存が画面から消え、一覧も書かれず、
  /// 次の起動で戻った。
  Future<void> deleteNode(String projectId, String nodeId) async {
    await _deleteNodeFiles(projectId, nodeId);
    _nodesByProject[projectId]?.removeWhere((n) => n.id == nodeId);
    notifyListeners();
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
  ///
  /// 先に残す保存を新しいスロットへ入れてから、選ばなかった保存を消す。
  /// 消せなかった保存は、記録して退避に残す（ツリー方式へ戻すと出る）。
  /// 選ばなかった保存をすべて消せた（退避するときはいつも）true。以前は1つ
  /// 消せないと途中で投げ、先に消した保存が中身の無いまま一覧に残り、
  /// 残すと選んだ保存はどのスロットにも入らなかった。
  Future<bool> applyModeChange({
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
    var allDone = true;
    if (!archive) {
      // 完全削除：実データ（SaveTree/{nodeId}.niapro）も削除する
      for (final n in discard) {
        try {
          await _deleteNodeFiles(projectId, n.id);
        } catch (error, stack) {
          AppErrorReporter.record(error, stack);
          _archivedByProject.putIfAbsent(projectId, () => []).add(n);
          allDone = false;
        }
      }
    }
    notifyListeners();
    await _persist(projectId);
    return allDone;
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

/// 書いている途中の手動の保存（[SaveTreeService.beginSlotSave]）。
class SlotSave {
  SlotSave._(this._service, this.projectId, this.slotIndex, this.replacing);

  final SaveTreeService _service;
  final String projectId;

  /// 保存先のスロット（ツリー方式の保存は-1）。
  final int slotIndex;

  /// 押したときに見せていた、上書きを確かめた保存のID（空に見えたスロットは
  /// null）。
  final String? replacing;

  /// 書いている保存のID（書き始めてから）。
  String? nodeId;

  /// 書いている保存のコメント（書き始めてから）。
  String? comment;

  /// 保存が終わった（失敗・取りやめも）。何度呼んでもよい。
  void end() => _service._saving[projectId]?.remove(this);
}
