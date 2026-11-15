import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsBinding;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../../engine/export_engine.dart';
import '../../engine/niapro_serializer.dart';
import '../../l10n/app_localizations.dart';
import '../../models/home_list_filters.dart';
import '../../models/project.dart';
import '../../services/community_service.dart';
import '../../services/google_auth_service.dart';
import '../../services/api/community_api.dart';
import '../../services/font_service.dart';
import '../../services/export_share_service.dart';
import '../../services/project_service.dart';
import '../../services/local_file_trash_service.dart';
import '../../services/outgoing_share_library.dart';
import '../../services/settings_service.dart';
import '../../services/share_intent_service.dart';
import '../../services/shortcut_service.dart';
import '../../services/storage_info_service.dart';
import '../../services/work_folder_service.dart';
import '../../models/shortcut_binding.dart';
import '../../widgets/export_share_feedback.dart';
import '../../widgets/action_beside_or_below.dart';
import '../../widgets/ad_banner_mock_widget.dart';
import '../../widgets/app_toast_messenger.dart';
import '../../widgets/empty_state_placeholder.dart';
import '../../widgets/date_line_text.dart';
import '../../widgets/korean_words_text.dart';
import '../../widgets/sort_mode_control.dart';
import '../../widgets/project_trash_dialog.dart';
import '../../widgets/collection_action_controls.dart';
import '../../widgets/collection_tile_layout.dart';
import '../../widgets/home_collection_selection_scope.dart';
import '../../widgets/secondary_click_menu.dart';
import '../../widgets/share_project_file_action.dart';
import '../../widgets/mission_completion_dialog.dart';
import '../../widgets/moved_to_trash_snack_bar.dart';
import '../../widgets/name_entry_dialog.dart';
import '../../widgets/copy_name_text.dart';
import '../../widgets/keep_together_text.dart';
import '../../widgets/project_duplicated_snack_bar.dart';
import '../../widgets/typing_aware_shortcuts.dart';
import '../../widgets/fit_or_hide_title.dart';
import '../../widgets/menu_action_label.dart';
import 'widgets/project_list_widget.dart';
import 'widgets/shared_direction_switch.dart';
import 'widgets/folder_thumbnail.dart';
import 'widgets/project_thumbnail_dialog.dart';
import 'widgets/home_selection_toolbar.dart';
import 'widgets/home_drawer.dart';
import 'widgets/chip_focus_ring.dart';
import 'widgets/exported_work_card.dart';
import 'widgets/exported_work_thumbnail_dialog.dart';
import 'widgets/exported_work_preview_layout.dart';
import 'widgets/work_folder_move_sheet.dart';
import 'home_clipboard_policy.dart';
import '../../config/font_fallback.dart';
import '../../utils/line_break.dart';
import '../../utils/name_collation.dart';
import '../../widgets/projects_load_failure_notice.dart';
import '../../widgets/scrollable_sheet_body.dart';
import '../../utils/app_error_reporter.dart';
import '../../utils/duplicate_name.dart';
import '../../utils/file_size_label.dart';
import '../../utils/folder_persistence.dart';
import '../../utils/responsive_tile_defaults.dart';
import '../../utils/tolerant_preferences.dart';

/// 共有ファイルの名前を、すでにある共有ファイルと同じ名前に変えようとした。
class _ShareNameTaken implements Exception {
  const _ShareNameTaken();
}

class _ClipboardSourceMissing implements Exception {
  const _ClipboardSourceMissing();
}

/// ホームのコピー・切り取り・貼り付けの知らせの印（取り下げるときに、他の
/// 機能の知らせと見分ける）。知らせごとに別のキーになる。
/// [describesClipboard]はクリップボードの中身を伝える知らせ（コピー・
/// 切り取り。クリップボードを空にしたら閉じる）。
class _ClipboardNoticeKey extends UniqueKey {
  _ClipboardNoticeKey({required this.describesClipboard});

  final bool describesClipboard;

  /// 操作ボタン（「元に戻す」）が押されたか。押された知らせは知らせの側で
  /// 閉じるので、取り下げない（取り下げると、読み上げを使っているときは
  /// すぐ取り除かれ、続く知らせの側の「閉じる」が後ろで待っていた別の
  /// 知らせを閉じる）。
  final _PressedFlag actionPressed = _PressedFlag();
}

class _PressedFlag {
  bool value = false;
}

/// [messenger]に出ている・順番を待っているホームのコピー・切り取り・
/// 貼り付けの知らせを取り下げる（[describingOnly]ならクリップボードの中身を
/// 伝える知らせだけ）。他の機能の知らせには触れない。
void _withdrawClipboardNotices(
  ScaffoldMessengerState messenger, {
  bool describingOnly = false,
}) {
  if (messenger is! AppToastMessengerState) return;
  messenger.withdrawSnackBars((snackBar) {
    final key = snackBar.key;
    return key is _ClipboardNoticeKey &&
        !key.actionPressed.value &&
        (!describingOnly || key.describesClipboard);
  });
}

/// コピー・切り取り・貼り付けの知らせの文。貼り付けの結果は理由ごとに行が
/// 増える。知らせの上の空いている所（[ceiling]＝上のバー・貼り付けの欄の
/// 下端まで）に入る文はそのまま全部出し、入らないときだけ空いている所
/// いっぱいまでにして中でスクロールする（上のバーと貼り付けの欄は覆わない）。
/// 決まった高さで切ると、大きな文字では、空いている所があるのに件数の行が
/// 5秒で消える知らせの見えない所に隠れた。空いている所は描くたびに測り直す
/// （画面の大きさ・貼り付けの欄の有無が変わっても、その時の画面で決める）。
/// 韓国語は語の途中で折り返さない。
class _ClipboardNoticeText extends StatefulWidget {
  const _ClipboardNoticeText(this.message, {this.ceiling});

  final String message;

  /// 知らせを広げてよい上端（画面の座標）。分からないとき（ホームが別の
  /// 画面の下にある等）はnull。
  final double? Function()? ceiling;

  @override
  State<_ClipboardNoticeText> createState() => _ClipboardNoticeTextState();
}

class _ClipboardNoticeTextState extends State<_ClipboardNoticeText> {
  /// 知らせの上端と[_ClipboardNoticeText.ceiling]の間に空ける幅。
  static const double _gap = 8;

  /// 文の高さの上限（空いている所から決めたもの。まだ測っていなければnull）。
  double? _maxHeight;

  // 上限を測ったときの画面の大きさ・キーボード等で隠れる所。
  Size? _screen;
  EdgeInsets? _insets;

  @override
  void initState() {
    super.initState();
    _measureAfterFrame();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final screen = MediaQuery.sizeOf(context);
    final insets = MediaQuery.viewInsetsOf(context);
    if (screen != _screen || insets != _insets) {
      // 画面が変わったら、前の画面で測った上限を使わない（大きすぎる上限の
      // まま描くと、知らせが画面の上へはみ出す）。描いた後で測り直す。
      _screen = screen;
      _insets = insets;
      _maxHeight = null;
    }
  }

  // 描くたびに、描いた後で空いている所を測る（フレームを増やさない。
  // 上限が変わったときだけ描き直す）。
  void _measureAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _measure();
      _measureAfterFrame();
    });
  }

  void _measure() {
    final box = context.findRenderObject();
    final ceiling = widget.ceiling?.call();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    double? next;
    if (ceiling != null) {
      // 知らせは下端をそろえて置かれるので、文の下端は文の高さが変わっても
      // 動かない。文の上の余白（知らせの面の上端から文まで）も知らせに入る。
      final top = box.localToGlobal(Offset.zero).dy;
      final surfaceTop = _surface()?.localToGlobal(Offset.zero).dy ?? top;
      final room = top + box.size.height - ceiling - _gap - (top - surfaceTop);
      final line = _lineHeight;
      next = room > line ? room : line;
    }
    final current = _maxHeight;
    if (next == current) return;
    if (next != null && current != null && (next - current).abs() < 0.5) {
      return;
    }
    setState(() => _maxHeight = next);
  }

  /// 知らせの面（文を囲むSnackBarのMaterial）。
  RenderBox? _surface() {
    RenderBox? surface;
    context.visitAncestorElements((element) {
      if (element.widget is! Material) return true;
      final box = element.findRenderObject();
      if (box is RenderBox && box.attached && box.hasSize) surface = box;
      return false;
    });
    return surface;
  }

  /// 1行の高さ（空いている所がこれより狭くても、1行は見せる）。描くときの
  /// 書式・文字の大きさで測る。
  double _lineHeight = 0;

  void _measureLine(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: 'Ag', style: DefaultTextStyle.of(context).style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    _lineHeight = painter.height;
    painter.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _measureLine(context);
    final shown = keepKoreanWordsTogether(widget.message);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: _maxHeight ?? MediaQuery.sizeOf(context).height / 4,
      ),
      child: SingleChildScrollView(
        child: Text(shown, semanticsLabel: plainSemanticsLabel(shown)),
      ),
    );
  }
}

/// 1件の貼り付けの結果。
enum _PasteOutcome {
  pasted,

  /// 元の作品・フォルダが無い（ゴミ箱へ移した・消した）。クリップボードから
  /// 外す。
  missing,

  /// 切り取ったフォルダを自分自身やその中へは移せない。切り取ったまま残す。
  intoSelf,

  /// お気に入りの作品（またはそれを含むフォルダ）はゴミ箱へ移さない。
  favorite,

  /// 一部の変更だけが保存された（フォルダの中身を移している途中で保存
  /// できなかった等）。クリップボードに残す。
  partial,

  /// 保存できなかった等。クリップボードに残し、もう一度貼り付けられる。
  failed,
}

/// 貼り付けた件数と、貼り付けられなかった理由ごとの件数（所有者の判断6：
/// 件数の内訳を出し、正しく貼り付けられたかが分かるようにする）。
class _PasteTally {
  final Map<_PasteOutcome, int> _counts = {};

  int operator [](_PasteOutcome outcome) => _counts[outcome] ?? 0;

  void add(_PasteOutcome outcome) => _counts[outcome] = this[outcome] + 1;

  /// 1件を貼り付ける。[paste]は貼り付けたらtrue、元の作品・フォルダが
  /// 見つからなければfalseを返す。貼り付けられなくても止めずに数える。
  Future<_PasteOutcome> run(Future<bool> Function() paste) async {
    _PasteOutcome outcome;
    try {
      outcome = await paste() ? _PasteOutcome.pasted : _PasteOutcome.missing;
    } on _ClipboardSourceMissing {
      outcome = _PasteOutcome.missing;
    } on FavoriteProjectDeleteException {
      outcome = _PasteOutcome.favorite;
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
      outcome = failureOf(error);
    }
    add(outcome);
    return outcome;
  }

  /// 貼り付けられなかった[error]の理由（一部だけ保存できた・保存できない）。
  static _PasteOutcome failureOf(Object error) =>
      error is FolderSaveException && error.partiallySaved
      ? _PasteOutcome.partial
      : _PasteOutcome.failed;

  /// 結果の文：貼り付けた件数と、貼り付けられなかった理由ごとの件数を1行
  /// ずつ。1件も貼り付けられなかったときは、理由の行だけ。
  String message(AppLocalizations l10n) {
    final skipped = [
      if (this[_PasteOutcome.missing] > 0)
        l10n.homePasteSkippedMissing(this[_PasteOutcome.missing]),
      if (this[_PasteOutcome.intoSelf] > 0)
        l10n.homePasteSkippedIntoSelf(this[_PasteOutcome.intoSelf]),
      if (this[_PasteOutcome.favorite] > 0)
        l10n.homePasteSkippedFavorite(this[_PasteOutcome.favorite]),
      if (this[_PasteOutcome.partial] > 0)
        l10n.homePasteSkippedPartial(this[_PasteOutcome.partial]),
      if (this[_PasteOutcome.failed] > 0)
        l10n.homePasteSkippedFailed(this[_PasteOutcome.failed]),
    ];
    return [
      if (this[_PasteOutcome.pasted] > 0 || skipped.isEmpty)
        l10n.homePastedSnackbar(this[_PasteOutcome.pasted]),
      ...skipped,
    ].join('\n');
  }
}

/// 複製・貼り付けで作る作品・フォルダの名前を、画面の言語の「(コピー)」と
/// 番号で付ける。
CopyNamer _copyNamer(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return (name, taken) => numberedCopyName(l10n, name, taken);
}

/// [source]の複製を置くファイル：同じフォルダに、画面の言語の「(コピー)」と
/// 番号を付けた、まだ無い名前（拡張子はそのまま）。
Future<File> _copyFileDestination(AppLocalizations l10n, File source) async {
  final fileName = source.uri.pathSegments.last;
  final dot = fileName.lastIndexOf('.');
  final stem = dot > 0 ? fileName.substring(0, dot) : fileName;
  final extension = dot > 0 ? fileName.substring(dot) : '';
  final taken = <String>{};
  while (true) {
    final name = numberedCopyName(l10n, stem, taken);
    final destination = File('${source.parent.path}/$name$extension');
    if (!await destination.exists()) return destination;
    taken.add(name);
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // The menu opens from the right; the launch-screen back arrow sits at the
  // left of the fixed AppBar. The page-level project list has its own scroll.
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _missionDrawerRefreshToken = 0;
  String? _lastVisitRequest;
  void _maybeRecordLogin(String? ownerId, CommunityApi? api) {
    if (ownerId == null || api == null) return;
    // Local date merely suppresses redundant traffic. The server determines
    // the actual JST day and checks the visit transaction atomically.
    final day = DateTime.now()
        .toUtc()
        .add(const Duration(hours: 9))
        .toIso8601String()
        .substring(0, 10);
    final requestKey = '$ownerId/$day';
    if (_lastVisitRequest == requestKey) return;
    _lastVisitRequest = requestKey;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted ||
          context.read<GoogleAuthService>().account?.id != ownerId ||
          !identical(context.read<CommunityService>().api, api)) {
        return;
      }
      try {
        final visit = await api.visitLoginBonus();
        if (mounted &&
            (ModalRoute.of(context)?.isCurrent ?? false) &&
            context.read<GoogleAuthService>().account?.id == ownerId) {
          await showServerMissionCompletions(context, visit);
        }
      } catch (error) {
        debugPrint('Cumulative login visit could not be saved: $error');
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _maybeRecordLogin(
        context.read<GoogleAuthService>().account?.id,
        context.read<CommunityService>().api,
      );
    }
  }

  final _projectScrollController = ScrollController();
  late _HomeTabController _tabController;

  // 引き出し（画面の外へ出たかを見る）と、閉じた引き出しを1フレームだけ
  // 外している間（[_releaseClosedEndDrawer]）。
  final _endDrawerKey = GlobalKey(debugLabel: 'homeEndDrawer');
  bool _endDrawerReleased = false;

  /// 動きを減らす設定（端末の「アニメーションを削除」）で引き出しを閉じると、
  /// DrawerControllerは閉じる動き（AnimationController.fling）を速さ200倍の
  /// ばねで動かす。引き出しは1〜2フレームで画面の外へ出るが、ばねが落ち
  /// 着くまでの約0.4秒（24フレーム）は「閉じている途中」のままで、ホームの
  /// 上に透明な幕（閉じるためのGestureDetector・BlockSemantics）を残し、
  /// タブを押しても届かなかった。引き出しが画面の外へ出たフレームの後、
  /// 引き出しを1フレームだけ外してDrawerControllerを作り直す（閉じた状態で
  /// 作られ、幕を持たない）。指で引いている間は、画面の外へ出るまで待つ
  /// （途中で消さない）。設定がオフなら何もしない（閉じる動きの終わりで
  /// 幕も消える）。
  void _releaseClosedEndDrawer() {
    if (!SemanticsBinding.instance.disableAnimations) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _endDrawerReleased) return;
      if (_scaffoldKey.currentState?.isEndDrawerOpen ?? true) return;
      final drawer = _endDrawerKey.currentContext?.findRenderObject();
      // 閉じ終えたDrawerControllerは引き出しを作らない（幕も無い）。
      if (drawer is! RenderBox || !drawer.attached || !drawer.hasSize) return;
      final shown = (drawer.localToGlobal(Offset.zero) & drawer.size).intersect(
        Offset.zero & MediaQuery.sizeOf(context),
      );
      if (shown.width > 0.5 && shown.height > 0.5) {
        _releaseClosedEndDrawer();
        return;
      }
      setState(() => _endDrawerReleased = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _endDrawerReleased = false);
      });
    });
  }

  static const _projectViewModeKey = 'home.projectViewMode.v1';
  static const _worksViewModeKey = 'home.worksViewMode.v1';
  ProjectViewMode? _userViewMode;
  // Preserve the existing full-height list cover until a view size is chosen.
  ProjectViewMode? _worksViewMode;
  ProjectViewMode? _sharedViewMode;
  static const _sharedViewModeKey = 'home.sharedViewMode.v1';

  ProjectViewMode _defaultCollectionViewMode(BuildContext context) =>
      switch (tileScreenClassForWidth(MediaQuery.sizeOf(context).width)) {
        TileScreenClass.phone => ProjectViewMode.small,
        TileScreenClass.tablet => ProjectViewMode.medium,
        TileScreenClass.desktop => ProjectViewMode.large,
      };
  ProjectViewMode _effectiveWorksViewMode(BuildContext context) =>
      _worksViewMode ?? _defaultCollectionViewMode(context);
  ProjectViewMode _effectiveSharedViewMode(BuildContext context) =>
      _sharedViewMode ?? _defaultCollectionViewMode(context);

  Future<void> _selectSharedViewMode(ProjectViewMode mode) async {
    setState(() => _sharedViewMode = mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sharedViewModeKey, mode.name);
    } catch (error) {
      debugPrint('Shared tile preference could not be saved: $error');
    }
  }

  Future<void> _loadSharedViewMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_sharedViewModeKey);
      if (!mounted || stored == null) return;
      for (final mode in ProjectViewMode.values) {
        if (mode.name == stored) {
          setState(() => _sharedViewMode = mode);
          return;
        }
      }
    } catch (error) {
      debugPrint('Shared tile preference could not be restored: $error');
    }
  }

  Future<void> _selectWorksViewMode(ProjectViewMode mode) async {
    setState(() => _worksViewMode = mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_worksViewModeKey, mode.name);
    } catch (error) {
      debugPrint('Works tile preference could not be saved: $error');
    }
  }

  Future<void> _loadWorksViewMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_worksViewModeKey);
      if (!mounted || stored == null) return;
      for (final mode in ProjectViewMode.values) {
        if (mode.name == stored) {
          setState(() => _worksViewMode = mode);
          return;
        }
      }
    } catch (error) {
      debugPrint('Works tile preference could not be restored: $error');
    }
  }

  ProjectViewMode _effectiveViewMode(BuildContext context) =>
      _userViewMode ??
      switch (tileScreenClassForWidth(MediaQuery.sizeOf(context).width)) {
        TileScreenClass.phone => ProjectViewMode.small,
        TileScreenClass.tablet => ProjectViewMode.medium,
        TileScreenClass.desktop => ProjectViewMode.large,
      };

  // 一覧のスクロール位置を覚える区分に使う表示サイズ。表示サイズを選んで
  // いない間は、最初に決まったもののままにする：窓の幅が境（600px・1000px）を
  // またいで表示サイズが変わるたびに区分まで変えると、一覧が先頭へ戻る。
  ProjectViewMode? _autoViewModeAtOpen;

  ProjectViewMode _scrollMemoryViewMode(BuildContext context) =>
      _userViewMode ?? (_autoViewModeAtOpen ??= _effectiveViewMode(context));

  Future<void> _loadProjectViewMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.readString(_projectViewModeKey);
      if (!mounted || saved == null) return;
      for (final mode in ProjectViewMode.values) {
        if (mode.name == saved) {
          setState(() => _userViewMode = mode);
          return;
        }
      }
    } catch (error) {
      debugPrint('Project tile preference could not be restored: $error');
    }
  }

  Future<void> _selectProjectViewMode(ProjectViewMode mode) async {
    // いま出ている表示サイズを、開いたときの表示サイズの区分で覚えている
    // とき（窓の幅が境をまたいだ後）は、区分をその表示サイズへ替え、読んで
    // いた所を新しい区分へ引き継ぐ。並びは変わらないので一覧を動かさない。
    final positions = _projectScrollController.positions;
    final handOver =
        mode == _effectiveViewMode(context) &&
            mode != _scrollMemoryViewMode(context) &&
            positions.length == 1 &&
            positions.single.hasPixels
        ? positions.single.pixels
        : null;
    setState(() => _userViewMode = mode);
    if (handOver != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final positions = _projectScrollController.positions;
        if (!mounted || positions.length != 1) return;
        final position = positions.single;
        position.jumpTo(
          handOver.clamp(position.minScrollExtent, position.maxScrollExtent),
        );
      });
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_projectViewModeKey, mode.name);
    } catch (error) {
      debugPrint('Project tile preference could not be saved: $error');
    }
  }

  // 選んだ並び順と「お気に入りのみ」は起動し直しても引き継ぐ（作品一覧・
  // 共有・ゴミ箱と同じく設定に残す。設定の引き継ぎにも入る）。initState で
  // 設定から同期で戻すので、最初のフレームから選んだ並びで出る。
  ProjectSortMode _sortMode = ProjectSortMode.updatedDesc;
  SettingsService? _listFilterSettings;

  void _restoreProjectFilters() {
    final saved = _listFilterSettings!.homeListFilters(HomeList.projects);
    _sortMode = _savedSortMode(saved.sort);
    _showFavoritesOnly = saved.favoritesOnly;
  }

  // 設定の引き継ぎで読み込んだ並び順・絞り込みを、開いている一覧にも当てる
  // （絞り込みが変わったら、手で切り替えたときと同じく選ぶのを終える）。
  void _onListFiltersReloaded() {
    if (!mounted) return;
    final favouritesBefore = _showFavoritesOnly;
    setState(() {
      _restoreProjectFilters();
      if (_showFavoritesOnly != favouritesBefore) {
        _selectedIds.clear();
        _isSelectionMode = false;
      }
    });
  }

  void _rememberProjectSort() {
    _listFilterSettings?.updateHomeListFilters(
      HomeList.projects,
      sort: _sortMode.name,
    );
  }

  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  final Set<String> _visibleLibraryIds = {};
  // 複数選択モードの切り取り・コピー・貼り付け。フォルダ間の移動を手軽に
  // するための内部クリップボード（アプリを離れると保持しない、
  // セッション内のみのUI状態）。_clipboardIsCutがtrueなら切り取り（貼り付け
  // で移動し1回でクリップボードを空にする）、falseならコピー（貼り付けは
  // 複製し、繰り返し貼り付け可能）。フォルダは複製の実装を持たないため、
  // コピー時は選択にプロジェクトのみを含める（フォルダが混在していれば
  // コピー操作自体を無効化する）。
  final Set<String> _clipboardProjectIds = {};
  final Set<String> _clipboardFolderIds = {};
  HomePasteArea _clipboardSourceArea = HomePasteArea.projects;
  HomeClipboardEntry? _otherClipboard;
  bool _sharedOutgoing = false;
  bool _clipboardIsCut = false;
  bool _showFavoritesOnly = false;
  bool _isSearching = false;
  // false: project/folder name keyword search, true: project tag search.
  // The search bar toggle swaps these modes like a play/pause control.
  bool _searchByTag = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  // 画面全体のショートカット（全選択・コピー等）を受けるフォーカス。
  // 検索欄から抜けたら（Enter・閉じる・タブの切り替え）ここへ戻す。
  // Tabでは止まらない（以前は＋の浮かぶボタンと戻る矢印の間に、何も
  // 光らない止まり先が1つあった）。
  final _homeFocus = FocusNode(debugLabel: 'Home', skipTraversal: true);
  StreamSubscription<String>? _sharedFileSub;
  // 現在開いているフォルダ（フォルダは複数階層に対応・
  // パンくずリストで現在位置を表示）。nullはルート直下。
  String? _currentFolderId;
  // 新規追加系のFAB（＋ボタン）はプロジェクトタブ・作品一覧タブでのみ
  // 表示する（ブクマ済みタブに新規作成の導線があるのは不自然なため）。
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = _HomeTabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _currentTabIndex) {
        final wasSearching = _isSearching;
        final focusInPage = _focusIsInListArea();
        setState(() {
          _currentTabIndex = _tabController.index;
          _selectedIds.clear();
          _visibleLibraryIds.clear();
          _isSelectionMode = false;
          _resetProjectSearch();
        });
        if (wasSearching && _currentTabIndex != 0) {
          _homeFocus.requestFocus();
        } else if (focusInPage) {
          _focusSelectedTab();
        }
      }
    });
    _loadProjectViewMode();
    _listFilterSettings = context.read<SettingsService>()
      ..homeListFiltersReloaded.addListener(_onListFiltersReloaded);
    _restoreProjectFilters();
    _loadWorksViewMode();
    _loadSharedViewMode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstLaunch();
      _initShareIntentHandling();
    });
  }

  // 知らせの出し先（破棄の中では探せないので覚えておく）。
  ScaffoldMessengerState? _messenger;

  // ホームの上に別の画面を積むと動き出す、ホームの画面の後ろの動き。
  Animation<double>? _coveredBy;

  // タブの一覧（上のバー・貼り付けの欄・選択中の操作バーの下）。
  final GlobalKey _listAreaKey = GlobalKey();

  // タブの見出し（タブを替えたとき、前のタブの中身にあったフォーカスを移す先）。
  final GlobalKey _tabBarKey = GlobalKey(debugLabel: 'homeTabBar');

  /// キーボードのフォーカスがタブの中身（一覧・その見出し）にあるか。
  bool _focusIsInListArea() {
    final area = _listAreaKey.currentContext;
    final focused = FocusManager.instance.primaryFocus?.context;
    if (area == null || focused == null) return false;
    var found = false;
    focused.visitAncestorElements((element) {
      found = identical(element, area);
      return !found;
    });
    return found;
  }

  /// 選んだタブ（見出し）へフォーカスを移す。マウス・指でタブを替えると、
  /// フォーカスは前のタブの中身に残り（隠れたページは、フォーカスがある間
  /// 破棄されない）、次のTabで前のタブへスクロールして戻った。キーボードで
  /// タブを選んだときと同じく、次のTabで新しいタブの中身へ進む。
  void _focusSelectedTab() {
    final tabs = _tabBarKey.currentContext;
    if (tabs == null) return;
    final key = ValueKey('home_tab_${_tabController.index}');
    Element? tab;
    void visit(Element element) {
      if (tab != null) return;
      if (element.widget.key == key) {
        tab = element;
        return;
      }
      element.visitChildElements(visit);
    }

    tabs.visitChildElements(visit);
    final node = tab == null
        ? null
        : Focus.maybeOf(tab!, createDependency: false);
    (node ?? _homeFocus).requestFocus();
  }

  // 一覧の下に浮かぶボタンの並び（Tabで進んだ部品をこの上まで送り出す）。
  final GlobalKey _floatingActionsKey = GlobalKey(
    debugLabel: 'homeFloatingActions',
  );

  // プロジェクトの一覧の見出し（お気に入りの絞り込み・並び順・パンくず）。
  // 一覧は見る範囲（お気に入りだけ・フォルダ・検索）ごとに作り直してスクロール
  // 位置を覚えるが、見出しはこのキーで作り直さずに移す。作り直すと、
  // キーボードで押した「お気に入り」の絞り込みからフォーカスが外れて画面の
  // 根へ戻り、もう一度押して戻すのにTabを何度も押し直すことになった。
  final GlobalKey _projectListHeaderKey = GlobalKey(
    debugLabel: 'homeProjectListHeader',
  );

  // コピー・切り取り・貼り付けの知らせを広げてよい上端（画面の座標）：
  // タブの一覧の上端（上のバー・貼り付けの欄は覆わない）。ホームの上に別の
  // 画面を積んでいる間は、知らせはその画面に出るので分からない（null）。
  double? _noticeCeiling() {
    final covered = _coveredBy;
    if (!mounted || (covered != null && !covered.isDismissed)) return null;
    final box = _listAreaKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero).dy;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.maybeOf(context);
    final covered = ModalRoute.of(context)?.secondaryAnimation;
    if (!identical(covered, _coveredBy)) {
      _coveredBy?.removeStatusListener(_onCoveredChanged);
      _coveredBy = covered?..addStatusListener(_onCoveredChanged);
    }
  }

  // 別の画面（ヘルプ・キャンバス等）を上に積んだら、「貼り付けを押して
  // ください」というコピー・切り取りの知らせを閉じる（その画面には貼り付けが
  // 無い）。コピー・切り取りそのものは残り、戻れば貼り付けられる。メニュー・
  // ダイアログは画面の後ろの動きを動かさないので閉じない。
  void _onCoveredChanged(AnimationStatus status) {
    if (status == AnimationStatus.forward ||
        status == AnimationStatus.completed) {
      _closeClipboardNotice();
    }
  }

  @override
  void dispose() {
    // 履歴ごと置き換えてホームを離れたときも、コピー・切り取りの知らせを
    // 次の画面に残さない（クリップボードはホームと一緒に無くなる）。
    _coveredBy?.removeStatusListener(_onCoveredChanged);
    _closeClipboardNotice();
    WidgetsBinding.instance.removeObserver(this);
    _listFilterSettings?.homeListFiltersReloaded.removeListener(
      _onListFiltersReloaded,
    );
    _tabController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _homeFocus.dispose();
    _projectScrollController.dispose();
    _sharedFileSub?.cancel();
    super.dispose();
  }

  /// .niashare受信フロー：OSから共有ファイルを開いた場合の処理。
  void _initShareIntentHandling() {
    final service = context.read<ShareIntentService>();
    final initialUri = service.pendingInitialUri;
    if (initialUri != null) {
      service.pendingInitialUri = null;
      _handleSharedUri(initialUri);
    }
    _sharedFileSub = service.onFileReceived.listen(_handleSharedUri);
  }

  Future<void> _handleSharedUri(String uri) async {
    String localPath;
    if (uri.startsWith('file://')) {
      localPath = Uri.parse(uri).toFilePath();
    } else {
      final bytes = await context.read<ShareIntentService>().readUriBytes(uri);
      if (bytes == null) return;
      final tmpDir = await getTemporaryDirectory();
      final file = File(
        '${tmpDir.path}/shared_${DateTime.now().millisecondsSinceEpoch}.niashare',
      );
      await file.writeAsBytes(bytes);
      localPath = file.path;
    }
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.homeShareFileDialogTitle),
        content: Text(l10n.homeShareFileDialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    if (proceed != true) return;
    try {
      final data = await NiaproSerializer.loadShare(localPath);
      if (!mounted) return;
      final projectService = context.read<ProjectService>();
      final project = await projectService.importSharedProject(data);
      if (!mounted) return;
      // 同梱フォント（「フォントを含める」選択時）を取り込み登録する。
      final fontService = context.read<FontService>();
      final bundledFonts = NiaproSerializer.bundledFonts(data);
      for (final font in bundledFonts) {
        await fontService.importBundledFont(
          id: font.id,
          displayName: font.displayName,
          fileName: font.fileName,
          bytes: font.bytes,
        );
      }
      // 不足フォント検出（「不足フォントがあります。○○」を表示）：
      // プロジェクトが使用するユーザー追加フォントのうち、同梱もされておらず
      // 端末側にも存在しないものを警告する。
      if (!mounted) return;
      final usedFamilies = projectService.usedFontFamiliesOf(project.id);
      final installedFamilies = fontService.fonts
          .map(fontService.familyNameOf)
          .toSet();
      final missing = usedFamilies.where(
        (f) => f.startsWith('UserFont_') && !installedFamilies.contains(f),
      );
      if (missing.isNotEmpty) {
        final names = missing
            .map((f) => f.replaceFirst('UserFont_', ''))
            .join(l10n.commonListSeparator);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.homeMissingFontsSnackbar(names))),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.homeSharedImportedSnackbar)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.homeSharedImportFailedSnackbar(e.toString())),
        ),
      );
    }
  }

  void _checkFirstLaunch() {
    final settings = context.read<SettingsService>();
    if (!settings.isFirstLaunch) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          _FirstLaunchDialog(onDone: settings.markFirstLaunchDone),
    );
  }

  // 現在の並び替えが名前基準かどうか（項目自体はProjectSortMode
  // ［名前昇順/降順・更新日時昇順/降順］の4値のままだが、UI上は
  // 「項目（名前／更新日時）」と「昇順/降順」を別々の操作にする）。
  bool get _sortByName =>
      _sortMode == ProjectSortMode.nameAsc ||
      _sortMode == ProjectSortMode.nameDesc;
  bool get _sortAscending =>
      _sortMode == ProjectSortMode.nameAsc ||
      _sortMode == ProjectSortMode.updatedAsc;

  void _setSortByName(bool byName) {
    setState(() {
      _sortMode = byName
          ? (_sortAscending
                ? ProjectSortMode.nameAsc
                : ProjectSortMode.nameDesc)
          : (_sortAscending
                ? ProjectSortMode.updatedAsc
                : ProjectSortMode.updatedDesc);
    });
    _rememberProjectSort();
  }

  void _toggleSortDirection() {
    setState(() {
      _sortMode = switch (_sortMode) {
        ProjectSortMode.nameAsc => ProjectSortMode.nameDesc,
        ProjectSortMode.nameDesc => ProjectSortMode.nameAsc,
        ProjectSortMode.updatedAsc => ProjectSortMode.updatedDesc,
        ProjectSortMode.updatedDesc => ProjectSortMode.updatedAsc,
      };
    });
    _rememberProjectSort();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    _tabController.reduceMotion = MediaQuery.disableAnimationsOf(context);
    _maybeRecordLogin(
      context.watch<GoogleAuthService>().account?.id,
      context.read<CommunityService>().api,
    );

    // マウス/キーボード入力・左手デバイス：設定画面「ショートカット設定」
    // で割り当てたキーで、全選択・コピー・切り取り・貼り付けを
    // 行えるようにする。
    // 入力欄にフォーカスがある間は画面のショートカットを止める
    // （TypingAwareShortcuts）。入力を終えたら画面のフォーカスへ戻す。
    final content = TypingAwareShortcuts(
      bindings: _buildShortcutBindings(context),
      screenFocus: _homeFocus,
      child: Focus(
        focusNode: _homeFocus,
        autofocus: true,
        child: Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            // 狭い画面では題の左右の余白を詰める。戻る・表示サイズ・検索・
            // メニューのボタンで幅が残らず、題が「プロジ…」と切れていた。
            // 検索中は題の所に検索の種類のボタン・入力欄が来るので詰めない
            // （戻るボタンと4pxまで近づいた）。
            titleSpacing:
                !_isSearching && MediaQuery.sizeOf(context).width < 400
                ? 0
                : null,
            leading: IconButton(
              key: const Key('homeBackToSplashButton'),
              icon: const Icon(Icons.arrow_back),
              tooltip: l10n.homeBackToSplashTooltip,
              onPressed: () => context.go('/'),
            ),
            title: _isSearching
                ? Row(
                    children: [
                      if (_currentTabIndex == 0)
                        IconButton(
                          key: const Key('homeSearchTagToggle'),
                          icon: Icon(
                            _searchByTag ? Icons.search : Icons.sell_outlined,
                          ),
                          tooltip: _searchByTag
                              ? l10n.homeSearchHint
                              : l10n.projectDetailTagsQuickAction,
                          onPressed: () {
                            _changeProjectScope(
                              () => _searchByTag = !_searchByTag,
                            );
                            _searchFocus.requestFocus();
                          },
                        ),
                      Expanded(
                        child: CallbackShortcuts(
                          bindings: {_escapeOnce: _escapeInSearch},
                          child: TextField(
                            key: const Key('homeSearchInput'),
                            controller: _searchController,
                            focusNode: _searchFocus,
                            decoration: InputDecoration(
                              hintText: _currentTabIndex == 0 && _searchByTag
                                  ? l10n.projectDetailTagsQuickAction
                                  : l10n.homeSearchHint,
                              border: InputBorder.none,
                            ),
                            onChanged: (v) =>
                                _changeProjectScope(() => _searchQuery = v),
                            onEditingComplete: _homeFocus.requestFocus,
                            onTapOutside: (event) {
                              if (event.kind != PointerDeviceKind.touch &&
                                  _searchFocus.hasFocus) {
                                _homeFocus.requestFocus();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  )
                // 入らない幅では題を出さない（省略記号で切らない）。
                : FitOrHideTitle(switch (_currentTabIndex) {
                    1 => l10n.homeTabWorks,
                    2 => l10n.homeTabShared,
                    3 => l10n.homeTabTrash,
                    _ => l10n.homeTabProjects,
                  }),
            actions: [
              if (_isSearching)
                IconButton(
                  key: const Key('homeSearchCloseButton'),
                  icon: const Icon(Icons.close),
                  tooltip: l10n.commonClose,
                  onPressed: _closeProjectSearch,
                )
              else ...[
                if (_currentTabIndex <= 2)
                  // 開いているタブの今の表示サイズに印を付ける。
                  ProjectViewModeMenu(
                    key: const Key('homeCollectionViewModeMenu'),
                    value: switch (_currentTabIndex) {
                      1 => _effectiveWorksViewMode(context),
                      2 => _effectiveSharedViewMode(context),
                      _ => _effectiveViewMode(context),
                    },
                    onChanged: (mode) {
                      switch (_currentTabIndex) {
                        case 0:
                          _selectProjectViewMode(mode);
                        case 1:
                          _selectWorksViewMode(mode);
                        case 2:
                          _selectSharedViewMode(mode);
                      }
                    },
                  ),
                IconButton(
                  key: const Key('homeSearchButton'),
                  icon: const Icon(Icons.search),
                  tooltip: l10n.commonSearch,
                  onPressed: _openProjectSearch,
                ),
              ],
              IconButton(
                key: const Key('homeMenuButton'),
                icon: const Icon(Icons.menu),
                tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
                onPressed: () {
                  // Refresh server-owned mission status only when the drawer
                  // is opened, never with an endless polling timer.
                  setState(() => _missionDrawerRefreshToken++);
                  _scaffoldKey.currentState?.openEndDrawer();
                },
              ),
            ],
            // 標準のTabBarは項目名の文字数に関わらず均等4分割になるため、
            // 「プロジェクト」のように長い項目名が「共有」等の短い項目名と
            // 同じ幅しか確保できず、文字が見切れてしまっていた。各項目名の
            // 実際の描画幅を計測し、その比率でタブ幅を配分する独自実装へ
            // 差し替える（TabControllerは共通のまま、TabBarViewとの
            // スワイプ連動はそのまま維持される）。
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: KeyedSubtree(
                key: _tabBarKey,
                child: _HomeTabBar(
                  controller: _tabController,
                  currentIndex: _currentTabIndex,
                  labels: [
                    l10n.homeTabProjects,
                    l10n.homeTabWorks,
                    l10n.homeTabShared,
                    l10n.homeTabTrash,
                  ],
                ),
              ),
            ),
          ),
          endDrawer: _endDrawerReleased
              ? null
              : HomeDrawer(
                  key: _endDrawerKey,
                  refreshToken: _missionDrawerRefreshToken,
                ),
          // 引き出しの開閉で画面のショートカットを組み替える
          // （_buildShortcutBindings）。
          onEndDrawerChanged: (open) {
            if (mounted) setState(() {});
            if (!open) _releaseClosedEndDrawer();
          },
          body: Column(
            children: [
              if (!_isSelectionMode && _hasClipboard)
                HomeClipboardToolbar(
                  itemCount:
                      _clipboardProjectIds.length +
                      _clipboardFolderIds.length +
                      (_otherClipboard == null ? 0 : 1),
                  isCut: _clipboardIsCut,
                  isPasting: _pasting,
                  onPaste: _pasteClipboard,
                  onClear: _clearHomeClipboard,
                ),
              if (_isSelectionMode)
                HomeSelectionToolbar(
                  selectedCount: _selectedIds.length,
                  onSelectAll: _currentTabIndex == 0
                      ? _selectAllInCurrentFolder
                      : _selectAllLibrary,
                  onDeselectAll: _endProjectSelection,
                  onCut: _selectedIds.isEmpty
                      ? null
                      : (_currentTabIndex == 0
                            ? _cutSelected
                            : _currentTabIndex == 3 || _selectedIds.length != 1
                            ? null
                            : _cutSelectedLibrary),
                  onCopy: _selectedIds.isEmpty
                      ? null
                      : (_currentTabIndex == 0
                            ? _copySelected
                            : _selectedIds.length != 1
                            ? null
                            : _currentTabIndex == 3
                            ? _copySelectedTrash
                            : _copySelectedLibrary),
                  onTrash: _selectedIds.isEmpty
                      ? null
                      : (_currentTabIndex == 0
                            ? _deleteSelected
                            : _currentTabIndex == 3
                            ? _restoreSelectedTrash
                            : _trashSelectedLibrary),
                  primaryActionLabel: _currentTabIndex == 3
                      ? l10n.commonRestore
                      : null,
                  primaryActionIcon: _currentTabIndex == 3
                      ? Icons.restore
                      : Icons.delete,
                  // 作品一覧・共有・ゴミ箱は1件ずつ切り取り・コピーする。2件
                  // 以上選んだときは、押せない理由を伝える。ゴミ箱からは
                  // 切り取れないので、切り取りはいつも理由（戻すときは
                  // 「復元」）を伝える（以前は説明なしに押せなかった）。
                  cutUnavailableReason: _currentTabIndex == 3
                      ? l10n.homeTrashCutUnavailable(l10n.commonRestore)
                      : (_currentTabIndex == 1 || _currentTabIndex == 2) &&
                            _selectedIds.length > 1
                      ? l10n.homeSelectionOneAtATime
                      : null,
                  copyUnavailableReason:
                      _currentTabIndex != 0 && _selectedIds.length > 1
                      ? (_currentTabIndex == 3
                            ? l10n.homeTrashCopyOneAtATime
                            : l10n.homeSelectionOneAtATime)
                      : null,
                ),
              Expanded(
                child: HomeCollectionSelectionScope(
                  key: _listAreaKey,
                  active: _isSelectionMode,
                  selectedIds: Set<String>.of(_selectedIds),
                  onLongPress: _longPressLibraryEntry,
                  onToggle: _toggleLibraryEntry,
                  onVisibleIds: (ids) {
                    // TabBarView may prebuild adjacent off-screen tabs. Only
                    // the active collection can supply the Select All set.
                    final prefix = switch (_currentTabIndex) {
                      1 => 'work_',
                      2 => _sharedOutgoing ? 'outgoing_' : 'shared_',
                      3 => 'trash_',
                      _ => '',
                    };
                    if (prefix.isEmpty ||
                        (ids.isNotEmpty &&
                            ids.any((id) => !id.startsWith(prefix)))) {
                      return;
                    }
                    _visibleLibraryIds
                      ..clear()
                      ..addAll(ids);
                  },
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      ProjectListWidget(
                        scrollController: _projectScrollController,
                        header: Column(
                          key: _projectListHeaderKey,
                          children: [
                            // 保存先を読めなかったときは、空の一覧に見えて
                            // 作品が消えたと思わないよう知らせ、読み直せる
                            // ようにする。
                            if (context
                                .watch<ProjectService>()
                                .projectsLoadFailed)
                              ProjectsLoadFailureNotice(
                                key: const Key('homeProjectsLoadFailed'),
                                onRetry: () => context
                                    .read<ProjectService>()
                                    .retryLoadProjects(),
                                screenFocus: _homeFocus,
                              ),
                            _HomeCollectionSortHeader(
                              leading: ChipFocusRing(
                                builder: (context, focusSide) => FilterChip(
                                  side: focusSide,
                                  label: Text(
                                    l10n.homeFavoritesOnly,
                                    style: TextStyle(
                                      fontFamily: 'Kuramubon',
                                      fontFamilyFallback: kHeadingFontFallback,
                                      color: _showFavoritesOnly
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.onPrimary
                                          : null,
                                    ),
                                  ),
                                  selectedColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  checkmarkColor: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                  selected: _showFavoritesOnly,
                                  onSelected: (v) => _changeProjectScope(
                                    () => _showFavoritesOnly = v,
                                  ),
                                ),
                              ),
                              sortByName: _sortByName,
                              sortAscending: _sortAscending,
                              onSortByNameChanged: _setSortByName,
                              onToggleDirection: _toggleSortDirection,
                            ),
                            // フォルダ内移動時のパンくずリスト。言葉を入れて
                            // 探している間は全体から探すため出さない（検索を
                            // 開いただけで入力が空の間は、フォルダの中身を
                            // 出しているので残す）。
                            if (!_isSearching ||
                                !ProjectListWidget.searchesEverywhere(
                                  _searchQuery,
                                  searchByTag: _searchByTag,
                                ))
                              _buildBreadcrumb(),
                          ],
                        ),
                        // 読み込めなかった間は、上の知らせだけを出す（「プロ
                        // ジェクトがありません」とも、作成の案内とも言わない）。
                        hideEmptyState: context
                            .watch<ProjectService>()
                            .projectsLoadFailed,
                        // Keep bounded browsing scopes rather than every typed query.
                        key: PageStorageKey((
                          'home-projects',
                          _scrollMemoryViewMode(context),
                          _currentFolderId,
                          _showFavoritesOnly,
                          _isSearching,
                          _searchByTag,
                        )),
                        // 「共有」タブ（.niashareインポート由来）は別枠の
                        // 一覧のため、プロジェクトタブには表示しない。
                        projects: context
                            .watch<ProjectService>()
                            .projects
                            .where((p) => !p.isSharedImport)
                            .toList(),
                        viewMode: _effectiveViewMode(context),
                        sortMode: _sortMode,
                        isSelectionMode: _isSelectionMode,
                        selectedIds: _selectedIds,
                        cutIds: _clipboardIsCut
                            ? {..._clipboardProjectIds, ..._clipboardFolderIds}
                            : const {},
                        // 長押しモードへ入ると同時に、長押しした項目自体も
                        // 選択状態にする（複数選択モードに入っただけで
                        // 何も選ばれていない状態を避ける）。
                        onLongPress: (id) => setState(() {
                          _isSelectionMode = true;
                          _selectedIds.add(id);
                        }),
                        onSelectionChanged: (id) => setState(() {
                          if (_selectedIds.contains(id)) {
                            _selectedIds.remove(id);
                          } else {
                            _selectedIds.add(id);
                          }
                          // 手動でのタップ操作によって選択が0件になった場合も、
                          // 「全解除」ボタンを押した時と同様に複数選択モードを
                          // 自動終了する。
                          if (_selectedIds.isEmpty) {
                            _isSelectionMode = false;
                          }
                        }),
                        showFavoritesOnly: _showFavoritesOnly,
                        searchQuery: _searchQuery,
                        searchByTag: _searchByTag,
                        currentFolderId: _currentFolderId,
                        onOpenFolder: _openProjectFolder,
                        onClearSearch: _closeProjectSearch,
                        onShowAll: () => _changeProjectScope(
                          () => _showFavoritesOnly = false,
                        ),
                      ),
                      _WorksTab(
                        key: const PageStorageKey('home-works'),
                        viewMode: _effectiveWorksViewMode(context),
                        onViewModeChanged: _selectWorksViewMode,
                        searchQuery: _currentTabIndex == 1 && _isSearching
                            ? _searchQuery
                            : '',
                        onClearSearch: _closeProjectSearch,
                        onCopyEntry: _copyLibraryEntry,
                      ),
                      SharedScreen(
                        key: const PageStorageKey('home-shared'),
                        embedded: true,
                        screenFocus: _homeFocus,
                        initialOutgoing: _sharedOutgoing,
                        viewMode: _effectiveSharedViewMode(context),
                        onViewModeChanged: _selectSharedViewMode,
                        searchQuery: _currentTabIndex == 2 && _isSearching
                            ? _searchQuery
                            : '',
                        onClearSearch: _closeProjectSearch,
                        onDirectionChanged: (outgoing) => setState(() {
                          _sharedOutgoing = outgoing;
                          _selectedIds.clear();
                          _visibleLibraryIds.clear();
                          _isSelectionMode = false;
                        }),
                        onCopyEntry: _copyLibraryEntry,
                        onOutgoingRenamed: _followRenamedShare,
                      ),
                      TrashScreen(
                        key: const PageStorageKey('home-trash'),
                        embedded: true,
                        searchQuery: _currentTabIndex == 3 && _isSearching
                            ? _searchQuery
                            : '',
                        onClearSearch: _closeProjectSearch,
                        screenFocus: _homeFocus,
                        onCopyEntry: _copyLibraryEntry,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButton: _buildHomeActions(context, l10n),
        ),
      ),
    );
    // 戻る操作は常にここで受ける（canPop: false）。キャンバス・書き出しから
    // go('/home')で来たホームは履歴が1枚だけで、受けないとAndroid 16以降の
    // 予測型「戻る」ではOSが戻る操作をアプリへ渡さずにアプリを閉じる
    // （BackButtonListenerも呼ばれない）。ホームは作り直されないので、
    // canPopを組み立てたときの履歴から決めると古い値のまま残る。
    return BackButtonListener(
      onBackButtonPressed: () async => _handleLocalBack(),
      child: PopScope<Object?>(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop || _handleLocalBack()) return;
          // 何も開いていない、ほかの画面から積まれたホーム：前の画面へ戻る。
          if (mounted &&
              (ModalRoute.of(context)?.isCurrent ?? false) &&
              context.canPop()) {
            context.pop();
          }
        },
        child: FocusTraversalGroup(policy: _homeTraversal, child: content),
      ),
    );
  }

  late final _homeTraversal = _HomeTraversalPolicy(
    _listAreaKey,
    floatingActions: _floatingActionsKey,
  );

  // 選んでいる間は、どのタブでも「戻る」で選ぶのを終える（作品一覧・共有・
  // ゴミ箱でも長押しで選べる。以前はプロジェクトのタブだけを見ていて、ほかの
  // タブでは選んだまま起動画面へ戻った）。フォルダを上がるのはプロジェクトの
  // タブだけ。
  bool get _hasLocalBackScope =>
      _isSearching ||
      _isSelectionMode ||
      (_currentTabIndex == 0 && _currentFolderId != null);

  bool _handleLocalBack() {
    // A dialog or pushed page owns Back until it closes.
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return false;
    final scaffold = _scaffoldKey.currentState;
    if (scaffold?.isEndDrawerOpen ?? false) {
      scaffold!.closeEndDrawer();
      return true;
    }
    if (!_hasLocalBackScope) {
      // go('/home')で来たホーム（キャンバス・書き出しの後など）は履歴が
      // 1枚だけで、go_routerは戻れる画面が無いとアプリを閉じる。
      // 起動画面へ戻す。
      if (context.canPop()) return false;
      context.go('/');
      return true;
    }
    if (_isSelectionMode) {
      _endProjectSelection();
    } else if (_isSearching) {
      _closeProjectSearch();
    } else {
      final parent = context
          .read<ProjectService>()
          .folders
          .where((folder) => folder.id == _currentFolderId)
          .firstOrNull
          ?.parentFolderId;
      _changeProjectScope(() => _currentFolderId = parent);
    }
    return true;
  }

  void _longPressLibraryEntry(String id) => setState(() {
    _isSelectionMode = true;
    _selectedIds.add(id);
  });

  void _toggleLibraryEntry(String id) => setState(() {
    if (!_selectedIds.add(id)) _selectedIds.remove(id);
    _isSelectionMode = _selectedIds.isNotEmpty;
  });

  void _selectAllLibrary() => setState(() {
    _selectedIds.addAll(_visibleLibraryIds);
    _isSelectionMode = _selectedIds.isNotEmpty;
  });

  HomeClipboardEntry? _singleLibrarySelection({bool cut = false}) {
    if (_selectedIds.length != 1) return null;
    return _libraryEntry(_selectedIds.first, cut: cut);
  }

  /// 作品一覧・共有の選択のID[id]の項目（名前・元の場所）。無ければnull。
  HomeClipboardEntry? _libraryEntry(String id, {bool cut = false}) {
    final ps = context.read<ProjectService>();
    final ws = context.read<WorkFolderService>();
    if (id.startsWith('work_file:')) {
      final path = id.substring('work_file:'.length);
      return HomeClipboardEntry(
        source: HomePasteArea.works,
        id: path,
        name: File(path).uri.pathSegments.last,
        isCut: cut,
      );
    }
    if (id.startsWith('work_folder:')) {
      final folderId = id.substring('work_folder:'.length);
      final folder = ws.folders.where((f) => f.id == folderId).firstOrNull;
      if (folder == null) return null;
      return HomeClipboardEntry(
        source: HomePasteArea.works,
        id: folderId,
        name: folder.name,
        isFolder: true,
        isCut: cut,
      );
    }
    if (id.startsWith('shared_file:')) {
      final projectId = id.substring('shared_file:'.length);
      final project = ps.shared.where((p) => p.id == projectId).firstOrNull;
      if (project == null) return null;
      return HomeClipboardEntry(
        source: HomePasteArea.received,
        id: projectId,
        name: project.name,
        isCut: cut,
      );
    }
    if (id.startsWith('shared_folder:')) {
      final folderId = id.substring('shared_folder:'.length);
      final folder = ps.sharedFolders
          .where((f) => f.id == folderId)
          .firstOrNull;
      if (folder == null) return null;
      return HomeClipboardEntry(
        source: HomePasteArea.received,
        id: folderId,
        name: folder.name,
        isFolder: true,
        isCut: cut,
      );
    }
    if (id.startsWith('outgoing_file:')) {
      final path = id.substring('outgoing_file:'.length);
      final entry = ps.outgoingShares.where((e) => e.path == path).firstOrNull;
      if (entry == null) return null;
      return HomeClipboardEntry(
        source: HomePasteArea.outgoing,
        id: path,
        name: entry.name,
        isCut: cut,
      );
    }
    return null;
  }

  void _copySelectedLibrary() {
    final entry = _singleLibrarySelection();
    if (entry == null) return;
    _copyLibraryEntry(entry);
    _endProjectSelection();
  }

  Future<void> _copySelectedTrash() async {
    if (_selectedIds.length != 1) return;
    final id = _selectedIds.first;
    final ps = context.read<ProjectService>();
    HomeClipboardEntry? entry;
    if (id.startsWith('trash_project:')) {
      final projectId = id.substring('trash_project:'.length);
      final project = ps.trash.where((p) => p.id == projectId).firstOrNull;
      if (project != null) {
        entry = HomeClipboardEntry(
          source: HomePasteArea.trash,
          id: projectId,
          name: project.name,
          originalArea: project.isSharedImport
              ? HomePasteArea.received
              : HomePasteArea.projects,
        );
      }
    } else if (id.startsWith('trash_folder:')) {
      final folderId = id.substring('trash_folder:'.length);
      final folder = ps.trashedFolders
          .where((f) => f.folder.id == folderId)
          .firstOrNull;
      if (folder != null) {
        entry = HomeClipboardEntry(
          source: HomePasteArea.trash,
          id: folderId,
          name: folder.folder.name,
          isFolder: true,
          originalArea: folder.isShared
              ? HomePasteArea.received
              : HomePasteArea.projects,
        );
      }
    } else if (id.startsWith('trash_local:')) {
      final localId = id.substring('trash_local:'.length);
      final items = await LocalFileTrashService.list();
      final local = items.where((e) => e.id == localId).firstOrNull;
      if (local != null) {
        entry = HomeClipboardEntry(
          source: HomePasteArea.trash,
          id: local.id,
          name: local.fileName,
          isFolder: local.isFolder,
          originalArea: local.kind == LocalTrashKind.outgoingShare
              ? HomePasteArea.outgoing
              : HomePasteArea.works,
        );
      }
    }
    if (entry == null || !mounted) return;
    _copyLibraryEntry(entry);
    _endProjectSelection();
  }

  void _cutSelectedLibrary() {
    final entry = _singleLibrarySelection(cut: true);
    if (entry == null) return;
    _copyLibraryEntry(entry);
    _endProjectSelection();
  }

  Future<void> _trashSelectedLibrary() async {
    if (_selectedIds.isEmpty) return;
    final selected = _selectedIds.toList(growable: false);
    final l10n = AppLocalizations.of(context)!;
    final ps = context.read<ProjectService>();
    final ws = context.read<WorkFolderService>();
    // 受け取ったもののお気に入り（とそれを含むフォルダ）はゴミ箱へ移さない。
    // プロジェクトのタブの選択と同じく、黙って飛ばさずに理由を出す（以前は
    // 確認で数に入れたまま、お気に入りだけ黙って残していた）。
    bool favouriteFile(String id) =>
        id.startsWith('shared_file:') &&
        ps.shared.any(
          (p) => p.id == id.substring('shared_file:'.length) && p.isFavorite,
        );
    bool favouriteFolder(String id) =>
        id.startsWith('shared_folder:') &&
        ps.sharedFolders.any(
          (f) => f.id == id.substring('shared_folder:'.length) && f.isFavorite,
        );
    bool holdsFavourite(String id) =>
        id.startsWith('shared_folder:') &&
        ps.shared.any(
          (p) =>
              p.isFavorite &&
              p.sharedFolderId == id.substring('shared_folder:'.length),
        );
    if (selected.any((id) => favouriteFile(id) || favouriteFolder(id))) {
      showTrashRefusedSnackBar(
        ScaffoldMessenger.of(context),
        l10n.commonFavoriteDeleteBlocked,
      );
      return;
    }
    if (selected.any(holdsFavourite)) {
      showTrashRefusedSnackBar(
        ScaffoldMessenger.of(context),
        l10n.homeTrashFolderHoldsFavorite,
      );
      return;
    }
    // 作品・フォルダ・書き出したファイルを1件ずつ移す確認と同じ形（移す
    // ものの名前を出し、移せなかったときは中に理由を出して開いたまま）。
    final names = [
      for (final id in selected)
        if (_libraryEntry(id) case final entry?) entry.name,
    ];
    final messenger = ScaffoldMessenger.of(context);
    await showDialog<bool>(
      context: context,
      builder: (_) => ProjectTrashDialog(
        title: l10n.homeMoveToTrash,
        message: l10n.homeMoveToTrashConfirm(selected.length),
        confirmLabel: l10n.homeMoveToTrash,
        itemNames: names,
        onApply: () async {
          // 移したものは、途中で失敗しても作品と同じく知らせて戻せる。
          final moved = (
            projects: <String>[],
            folders: <String>[],
            files: <LocalTrashedFile>[],
          );
          try {
            await _moveLibraryToTrash(selected, ps, ws, moved);
          } catch (error, stackTrace) {
            AppErrorReporter.record(error, stackTrace);
            rethrow;
          } finally {
            StorageInfoService().invalidate();
            showMovedToTrashSnackBar(
              messenger,
              l10n,
              ps,
              moved.projects,
              folderIds: moved.folders,
              files: moved.files,
              workFolders: ws,
            );
          }
          if (mounted) _endProjectSelection();
        },
      ),
    );
  }

  /// 選んだ作品一覧・共有の項目（[selected]の選択のID）をゴミ箱へ移し、
  /// 移したものを[moved]に足す。
  Future<void> _moveLibraryToTrash(
    List<String> selected,
    ProjectService ps,
    WorkFolderService ws,
    ({
      List<String> projects,
      List<String> folders,
      List<LocalTrashedFile> files,
    })
    moved,
  ) async {
    for (final id in selected) {
      if (id.startsWith('work_file:')) {
        final path = id.substring('work_file:'.length);
        moved.files.add(
          await LocalFileTrashService.move(
            File(path),
            LocalTrashKind.exportedWork,
          ),
        );
      } else if (id.startsWith('work_folder:')) {
        final folderId = id.substring('work_folder:'.length);
        final folder = ws.folders.where((f) => f.id == folderId).firstOrNull;
        if (folder == null) continue;
        final exports = await ExportEngine.listExportedFiles(
          forceRefresh: true,
        );
        final files = exports
            .where(
              (file) => ws.folderIdOf(file.uri.pathSegments.last) == folderId,
            )
            .toList();
        moved.files.add(
          await LocalFileTrashService.moveWorkFolder(
            folderName: folder.name,
            files: files,
          ),
        );
        await ws.deleteFolder(folderId);
      } else if (id.startsWith('shared_file:')) {
        final projectId = id.substring('shared_file:'.length);
        if (ps.shared.any((p) => p.id == projectId)) {
          await ps.deleteProject(projectId);
          moved.projects.add(projectId);
        }
      } else if (id.startsWith('shared_folder:')) {
        final folderId = id.substring('shared_folder:'.length);
        if (ps.sharedFolders.any((f) => f.id == folderId) &&
            await ps.moveFolderToTrash(folderId, shared: true) != null) {
          moved.folders.add(folderId);
        }
      } else if (id.startsWith('outgoing_file:')) {
        moved.files.add(
          await LocalFileTrashService.move(
            File(id.substring('outgoing_file:'.length)),
            LocalTrashKind.outgoingShare,
          ),
        );
        await ps.refreshOutgoingShares();
      }
    }
  }

  Future<void> _restoreSelectedTrash() async {
    if (_selectedIds.isEmpty) return;
    final selected = _selectedIds.toList(growable: false);
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.commonRestore),
        content: countText(
          l10n.homeTrashRestoreSelectedConfirm(selected.length),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(l10n.commonRestore),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final ps = context.read<ProjectService>();
    final ws = context.read<WorkFolderService>();
    try {
      final local = await LocalFileTrashService.list();
      for (final id in selected) {
        if (id.startsWith('trash_project:')) {
          await ps.restoreProject(id.substring('trash_project:'.length));
        } else if (id.startsWith('trash_folder:')) {
          await ps.restoreTrashedFolder(id.substring('trash_folder:'.length));
        } else if (id.startsWith('trash_local:')) {
          final key = id.substring('trash_local:'.length);
          final entry = local.where((e) => e.id == key).firstOrNull;
          if (entry == null) continue;
          if (entry.isFolder) {
            await LocalFileTrashService.restoreWorkFolder(entry, ws);
          } else {
            await LocalFileTrashService.restore(entry);
          }
        }
      }
      StorageInfoService().invalidate();
      if (mounted) _endProjectSelection();
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.homeTrashOperationFailed)));
      }
    }
  }

  void _endProjectSelection() => setState(() {
    _selectedIds.clear();
    _isSelectionMode = false;
  });

  Widget _buildHomeAction({
    Key? key,
    required String heroTag,
    required String tooltip,
    required bool compact,
    required VoidCallback onPressed,
    required IconData icon,
  }) {
    return _HomeFloatingAction(
      fabKey: key,
      heroTag: heroTag,
      tooltip: tooltip,
      compact: compact,
      onPressed: onPressed,
      icon: icon,
    );
  }

  Widget _buildCreateWorkFolderAction(
    BuildContext context,
    AppLocalizations l10n, {
    required bool compact,
  }) => _buildHomeAction(
    heroTag: 'home-add-work-folder',
    tooltip: l10n.homeAddSheetNewFolder,
    compact: compact,
    onPressed: () => showCreateFolderNameDialog(
      context,
      (name) => context.read<WorkFolderService>().createFolder(name),
    ),
    icon: Icons.create_new_folder_outlined,
  );

  Widget? _buildHomeActions(BuildContext context, AppLocalizations l10n) {
    if (_isSelectionMode ||
        _currentTabIndex == 3 ||
        (_currentTabIndex == 2 && _sharedOutgoing)) {
      return null;
    }
    final compact = MediaQuery.sizeOf(context).height < 400;

    // The footer and the scrollable tab body have separate hit regions.
    final projects = _currentTabIndex == 0;
    final shared = _currentTabIndex == 2;
    // 一覧が空（空の表示・読み込めなかった知らせだけ）のときは、送る先が
    // 無いので「一番上へ」を出さない（押しても何も起きず、空の表示の案内に
    // 重なった）。作成の＋は右下に残す。
    final scrollToTop =
        projects &&
        _visibleProjectIds(context.watch<ProjectService>()).isNotEmpty;
    return SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(16, 0, 16, compact ? 8 : 16),
      child: Row(
        key: _floatingActionsKey,
        mainAxisAlignment: scrollToTop
            ? MainAxisAlignment.spaceBetween
            : MainAxisAlignment.end,
        children: [
          if (projects) ...[
            if (scrollToTop)
              _buildHomeAction(
                compact: compact,
                key: const Key('homeScrollToTopFab'),
                heroTag: 'home-scroll-to-top',
                tooltip: l10n.communityScrollToTop,
                onPressed: () {
                  if (!_projectScrollController.hasClients) return;
                  _projectScrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                  );
                },
                icon: Icons.arrow_upward,
              ),
            _buildHomeAction(
              compact: compact,
              heroTag: 'home-add-project',
              tooltip: l10n.commonAdd,
              onPressed: () => _showAddChoiceSheet(context),
              icon: Icons.add,
            ),
          ] else if (shared)
            _buildHomeAction(
              compact: compact,
              heroTag: 'shared-add-folder',
              tooltip: l10n.homeAddSheetNewFolder,
              onPressed: () => showCreateFolderNameDialog(
                context,
                (name) =>
                    context.read<ProjectService>().createSharedFolder(name),
              ),
              icon: Icons.create_new_folder_outlined,
            )
          else
            _buildCreateWorkFolderAction(context, l10n, compact: compact),
        ],
      ),
    );
  }

  /// FABタップ時：新規プロジェクトか新規フォルダかを選ばせる（
  /// フォルダとプロジェクトを同一一覧内で扱う設計のため、どちらも一覧の
  /// ＋ボタンから作成できる必要がある）。
  void _showAddChoiceSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ScrollableSheetBody(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.note_add_outlined),
              title: Text(l10n.homeAddSheetNewProject),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/new-project');
              },
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: Text(l10n.homeAddSheetNewFolder),
              onTap: () {
                Navigator.pop(ctx);
                // 現在開いているフォルダの直下に作成する（ルートに固定しない）。
                showCreateFolderNameDialog(context, (name) async {
                  await context.read<ProjectService>().createFolder(
                    name,
                    parentFolderId: _currentFolderId,
                  );
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _deleteSelected() {
    final l10n = AppLocalizations.of(context)!;
    final service = context.read<ProjectService>();
    final visibleIds = _visibleProjectIds(service);
    final folderIds = service.folders
        .where((f) => visibleIds.contains(f.id) && _selectedIds.contains(f.id))
        .map((f) => f.id)
        .toSet();
    // Selecting a parent and child must not move the same subtree twice.
    final rootFolderIds = folderIds
        .where(
          (id) => !folderIds.any(
            (ancestor) =>
                id != ancestor && service.isFolderDescendantOf(id, ancestor),
          ),
        )
        .toList();
    final coveredFolderIds = <String>{
      for (final id in rootFolderIds) ...service.folderSubtreeIds(id),
    };
    final directProjectIds = service.projects
        .where(
          (p) =>
              !p.isSharedImport &&
              visibleIds.contains(p.id) &&
              _selectedIds.contains(p.id) &&
              !coveredFolderIds.contains(p.folderId),
        )
        .map((p) => p.id)
        .toList();
    final count = rootFolderIds.length + directProjectIds.length;
    if (count == 0) return;
    // 選んだフォルダの下の階層のお気に入りのフォルダも見る。
    bool includesFavorite() =>
        service.folders.any(
          (f) => coveredFolderIds.contains(f.id) && f.isFavorite,
        ) ||
        service.projects.any(
          (p) =>
              p.isFavorite &&
              (directProjectIds.contains(p.id) ||
                  coveredFolderIds.contains(p.folderId)),
        );
    if (includesFavorite()) {
      // 選んだもの自身がお気に入りならその断り、選んだフォルダの中の作品
      // だけがお気に入りなら、中のお気に入りが理由だと言う。出ているゴミ箱の
      // 知らせの「元に戻す」等を閉じずに、後ろに並べる。
      final selectedFavorite =
          service.folders.any(
            (f) => rootFolderIds.contains(f.id) && f.isFavorite,
          ) ||
          service.projects.any(
            (p) => p.isFavorite && directProjectIds.contains(p.id),
          );
      showTrashRefusedSnackBar(
        ScaffoldMessenger.of(context),
        selectedFavorite
            ? l10n.commonFavoriteDeleteBlocked
            : l10n.homeTrashFolderHoldsFavorite,
      );
      return;
    }
    final projectCountInFolders = rootFolderIds.fold<int>(
      0,
      (count, id) => count + service.folderContentCounts(id).projects,
    );
    final subfolderCount = rootFolderIds.fold<int>(
      0,
      (count, id) => count + service.folderContentCounts(id).folders,
    );
    final names = [
      for (final id in directProjectIds)
        ...service.projects.where((p) => p.id == id).map((p) => p.name),
      for (final id in rootFolderIds)
        ...service.folders.where((f) => f.id == id).map((f) => f.name),
    ];
    final descendantText = projectCountInFolders + subfolderCount == 0
        ? ''
        : '\n${l10n.homeMoveToTrashFolderContents(l10n.homeFolderContents(projectCountInFolders, subfolderCount))}';
    // 読めていない作品は、どのフォルダの作品か分からず数えられない。
    // ゴミ箱の外にあるものは選んだフォルダの作品かもしれないので、読めた
    // ときにゴミ箱のフォルダへ入ることを伝える（ゴミ箱の中の作品だけが
    // 読めないときは、選んだフォルダとは関係が無いので何も足さない）。
    final unreadText =
        rootFolderIds.isNotEmpty && service.mayHoldUnreadWorksOutsideTrash
        ? '\n${l10n.homeMoveToTrashUnreadNote}'
        : '';
    showDialog<void>(
      context: context,
      builder: (_) => ProjectTrashDialog(
        title: l10n.homeMoveToTrash,
        message:
            l10n.homeMoveToTrashConfirm(count) + descendantText + unreadText,
        confirmLabel: l10n.homeMoveToTrash,
        itemNames: names,
        onApply: () async {
          // Recheck protection before changing anything, not just on dialog open.
          if (includesFavorite()) throw const FavoriteProjectDeleteException();
          for (final id in rootFolderIds) {
            await service.moveFolderToTrash(id);
          }
          for (final id in directProjectIds) {
            await service.deleteProject(id);
          }
          if (!mounted) return;
          setState(() {
            _selectedIds.removeAll({...rootFolderIds, ...directProjectIds});
            _isSelectionMode = _selectedIds.isNotEmpty;
          });
          // 作品のメニューから移したときと同じ知らせ（続けて移したときは
          // 前に移したものもまとめて戻せる。他の機能の知らせは閉じない）。
          showMovedToTrashSnackBar(
            ScaffoldMessenger.of(context),
            l10n,
            service,
            directProjectIds,
            folderIds: rootFolderIds,
          );
        },
      ),
    );
  }

  void _changeProjectScope(VoidCallback change) {
    setState(() {
      change();
      _selectedIds.clear();
      _isSelectionMode = false;
    });
    _listFilterSettings?.updateHomeListFilters(
      HomeList.projects,
      favoritesOnly: _showFavoritesOnly,
    );
  }

  void _resetProjectSearch() {
    _isSearching = false;
    _searchByTag = false;
    _searchQuery = '';
    _searchController.clear();
  }

  void _openProjectSearch() {
    _changeProjectScope(() => _isSearching = true);
    _searchFocus.requestFocus();
  }

  void _closeProjectSearch() {
    _homeFocus.requestFocus();
    _changeProjectScope(_resetProjectSearch);
  }

  // 検索中のEsc。検索の結果を選んでいる間は、まず選ぶのを終える（「戻る」と
  // 同じ順。以前は1回のEscで検索語・結果・選んだものがまとめて消えた）。
  void _escapeInSearch() =>
      _isSelectionMode ? _endProjectSelection() : _closeProjectSearch();

  void _openProjectFolder(String id) {
    if (_isSearching) _homeFocus.requestFocus();
    _changeProjectScope(() {
      _currentFolderId = id;
      // A search is global; close it to display the selected folder's contents.
      if (_isSearching) _resetProjectSearch();
    });
  }

  Set<String> _visibleProjectIds(ProjectService service) =>
      ProjectListWidget.visibleIds(
        source: service.projects.where((p) => !p.isSharedImport).toList(),
        allFolders: service.folders,
        currentFolderId: _currentFolderId,
        showFavoritesOnly: _showFavoritesOnly,
        searchQuery: _searchQuery,
        searchByTag: _searchByTag,
      );

  /// Select exactly the current list, including its query and favorite filter.
  /// Shared imports belong to their separate list. Ctrl+A uses the same scope.
  void _selectAllInCurrentFolder() {
    final ids = _visibleProjectIds(context.read<ProjectService>());
    setState(() {
      _isSelectionMode = ids.isNotEmpty;
      _selectedIds
        ..clear()
        ..addAll(ids);
    });
  }

  /// 検索・引き出しを閉じるEsc。押し続けたときの繰り返しには反応しない
  /// （引き出しを閉じた後の繰り返しで、検索まで閉じて検索語を消さない）。
  static const _escapeOnce = SingleActivator(
    LogicalKeyboardKey.escape,
    includeRepeats: false,
  );

  /// 設定画面「ショートカット設定」の割り当て一覧から、ホーム画面で
  /// 有効なキー割り当てのマップを組み立てる。ツール選択の割り当ては
  /// キャンバスモード専用の概念のためここでは無視する。
  Map<ShortcutActivator, VoidCallback> _buildShortcutBindings(
    BuildContext context,
  ) {
    final bindings = context.watch<ShortcutService>().bindings;
    // 引き出しが開いている間は、その後ろの一覧（押せない）を全選択・
    // 貼り付け等で操作しない。Escは引き出しだけを閉じる。
    if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
      return {_escapeOnce: () => _scaffoldKey.currentState?.closeEndDrawer()};
    }
    // 検索中は全選択・コピー等を効かせない（検索で隠れた作品を操作しない）。
    // Escは検索を閉じる（Enterで入力を終えた後も）。
    if (_isSearching) return {_escapeOnce: _escapeInSearch};
    // 作品一覧・共有・ゴミ箱のタブでは全選択・コピー等を効かせない。Escは
    // どのタブでも選ぶのを終える（以前はこれらのタブでEscが何もしなかった）。
    if (_currentTabIndex != 0) {
      return {if (_isSelectionMode) _escapeOnce: _endProjectSelection};
    }
    final result = <ShortcutActivator, VoidCallback>{};
    for (final b in bindings) {
      if (b.isToolAction) continue;
      switch (b.command) {
        case ShortcutCommand.selectAll:
          result[b.activator] = _selectAllInCurrentFolder;
        case ShortcutCommand.copy:
          result[b.activator] = () {
            if (_selectedIds.isNotEmpty) _copySelected();
          };
        case ShortcutCommand.cut:
          result[b.activator] = () {
            if (_selectedIds.isNotEmpty) _cutSelected();
          };
        case ShortcutCommand.paste:
          result[b.activator] = () {
            if (_hasClipboard) _pasteClipboard();
          };
        case ShortcutCommand.undo:
        case ShortcutCommand.redo:
        case ShortcutCommand.toggleLayerPanel:
        case ShortcutCommand.playPause:
        case ShortcutCommand.previousFrame:
        case ShortcutCommand.nextFrame:
        case null:
          // キャンバス・タイムライン専用の操作、または未割り当て。
          break;
      }
    }
    if (_isSelectionMode) {
      result[_escapeOnce] = _endProjectSelection;
    } else if (_clipboardIsCut) {
      result[_escapeOnce] = _cancelCutClipboard;
    }
    return result;
  }

  /// Clear the in-memory clipboard, including items copied from other tabs.
  /// The toolbar disappears on the same rebuild.
  void _clearHomeClipboard() {
    if (!mounted || _pasting) return;
    setState(() {
      _clipboardProjectIds.clear();
      _clipboardFolderIds.clear();
      _otherClipboard = null;
      _clipboardSourceArea = HomePasteArea.projects;
      _clipboardIsCut = false;
    });
    _closeClipboardNotice();
  }

  // 出ているコピー・切り取りの知らせ（閉じたら、閉じ始めたらnull）。
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _clipboardNotice;

  // クリップボードを空にした回数。順番を待っている間に空にされたコピー・
  // 切り取りの知らせは、出た所で自分を閉じる。
  int _clipboardClears = 0;

  // 空にしたクリップボードを伝えていたコピー・切り取りの知らせだけを閉じる。
  // 出ている知らせを種類を見ずに閉じると、後から出た別の知らせ（ゴミ箱へ
  // 移した知らせとその「元に戻す」等）や、後ろで待っていた知らせを閉じる。
  // ScaffoldFeatureController.closeは出ている知らせにしか使えない（どれで
  // 呼んでも出ている知らせを閉じる）ので、待っている知らせは出た所で閉じる。
  void _closeClipboardNotice() {
    _clipboardClears++;
    final notice = _clipboardNotice;
    _clipboardNotice = null;
    final messenger = _messenger;
    if (messenger is AppToastMessengerState) {
      // 出ている知らせも順番を待っている知らせも、印で見分けて自分の物だけを
      // 下げる。close()は使わない：読み上げ・「動きを減らす」の設定では、
      // 入れ替えで取り下げた知らせはその場で取り除かれ、閉じたことが
      // [_clipboardNotice]へ届く前にここへ来る（貼り付けの終わり）。その
      // close()は、次に出ていた別の知らせ（貼り付けの結果・他の機能の
      // 知らせ）を閉じた。
      if (messenger.mounted) {
        _withdrawClipboardNotices(messenger, describingOnly: true);
      }
    } else {
      notice?.close();
    }
  }

  void _cancelCutClipboard() {
    if (!_clipboardIsCut) return;
    _clearHomeClipboard();
  }

  /// [describesClipboard]（切り取りは常に）の知らせは、クリップボードを
  /// 空にしたら閉じる（[_closeClipboardNotice]）。貼り付けの結果は閉じない。
  void _showClipboardFeedback(
    String message, {
    bool allowUndoCut = false,
    bool describesClipboard = false,
  }) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    // 前のコピー・切り取り・貼り付けの知らせだけを取り下げて入れ替える。
    // 出ている・待っている他の機能の知らせ（ゴミ箱へ移した知らせとその
    // 「元に戻す」・保存の失敗の知らせ等）は消さず、その後ろに並ぶ
    // （切り取りをやめたときは、印で自分の知らせだけを閉じる）。
    _withdrawClipboardNotices(messenger);
    final tracked = describesClipboard || allowUndoCut;
    final noticeKey = _ClipboardNoticeKey(describesClipboard: tracked);
    final clears = _clipboardClears;
    // 閉じた、または閉じ始めた（二度閉じると、次に出た別の知らせを閉じる）。
    var closing = false;
    late final ScaffoldFeatureController<SnackBar, SnackBarClosedReason> notice;
    notice = messenger.showSnackBar(
      SnackBar(
        key: noticeKey,
        content: _ClipboardNoticeText(message, ceiling: _noticeCeiling),
        // 操作ボタンの付いたSnackBarは、既定では時間で消えず次の画面まで
        // 付いてくる。切り取りは貼り付けるまで続くが、知らせは5秒で消す。
        persist: false,
        duration: Duration(seconds: allowUndoCut ? 5 : 4),
        onVisible: !tracked
            ? null
            : () {
                if (closing) return;
                if (clears != _clipboardClears) {
                  // 順番を待っている間にクリップボードが空になった。
                  closing = true;
                  notice.close();
                } else {
                  _clipboardNotice = notice;
                }
              },
        action: allowUndoCut
            ? SnackBarAction(
                label: AppLocalizations.of(context)!.homeUndoAction,
                // 押された知らせは知らせの側で閉じる。ここでも閉じると、
                // 読み上げ（TalkBack）を使っているときは閉じた知らせがすぐ
                // 取り除かれるので、後ろで待っている別の知らせまで閉じる。
                onPressed: () {
                  closing = true;
                  noticeKey.actionPressed.value = true;
                  if (identical(_clipboardNotice, notice)) {
                    _clipboardNotice = null;
                  }
                  _cancelCutClipboard();
                },
              )
            : null,
      ),
    );
    if (tracked) {
      notice.closed.whenComplete(() {
        closing = true;
        if (identical(_clipboardNotice, notice)) _clipboardNotice = null;
      });
    }
  }

  /// 選択中のプロジェクト・フォルダを切り取り、内部クリップボードへ保持する。
  /// 貼り付け時は[moveToFolder]/[moveFolderTo]で移動し、1回貼り付けると
  /// クリップボードは空になる。
  void _cutSelected() {
    final service = context.read<ProjectService>();
    final visibleIds = _visibleProjectIds(service);
    final projectIds = service.projects.map((p) => p.id).toSet();
    final folderIds = service.folders.map((f) => f.id).toSet();
    setState(() {
      _clipboardProjectIds
        ..clear()
        ..addAll(
          _selectedIds.where(
            (id) => projectIds.contains(id) && visibleIds.contains(id),
          ),
        );
      _clipboardFolderIds
        ..clear()
        ..addAll(
          _selectedIds.where(
            (id) => folderIds.contains(id) && visibleIds.contains(id),
          ),
        );
      _clipboardSourceArea = HomePasteArea.projects;
      _otherClipboard = null;
      _clipboardIsCut = true;
      _selectedIds.clear();
      _isSelectionMode = false;
    });
    final count = _clipboardProjectIds.length + _clipboardFolderIds.length;
    if (count > 0 && mounted) {
      _showClipboardFeedback(
        AppLocalizations.of(context)!.homeCutSnackbar(count),
        allowUndoCut: true,
      );
    }
  }

  /// Project and folder copies preserve source references for repeated paste.
  void _copySelected() {
    final service = context.read<ProjectService>();
    final visibleIds = _visibleProjectIds(service);
    final projectIds = service.projects.map((p) => p.id).toSet();
    final folderIds = service.folders.map((f) => f.id).toSet();
    setState(() {
      _clipboardProjectIds
        ..clear()
        ..addAll(
          _selectedIds.where(
            (id) => projectIds.contains(id) && visibleIds.contains(id),
          ),
        );
      _clipboardFolderIds
        ..clear()
        ..addAll(
          _selectedIds.where(
            (id) => folderIds.contains(id) && visibleIds.contains(id),
          ),
        );
      _clipboardSourceArea = HomePasteArea.projects;
      _otherClipboard = null;
      _clipboardIsCut = false;
      _selectedIds.clear();
      _isSelectionMode = false;
    });
    final count = _clipboardProjectIds.length + _clipboardFolderIds.length;
    if (count > 0 && mounted) {
      _showClipboardFeedback(
        AppLocalizations.of(context)!.homeCopiedSnackbar(count),
        describesClipboard: true,
      );
    }
  }

  bool get _hasClipboard =>
      _clipboardProjectIds.isNotEmpty ||
      _clipboardFolderIds.isNotEmpty ||
      _otherClipboard != null;

  /// 作成した共有ファイルの名前を変えたら、コピーしたもの（クリップボード）
  /// も新しい名前のファイルにする（前の場所のままだと、貼り付けで「元が
  /// 見つからない」になった）。
  void _followRenamedShare(String oldPath, String newPath, String newName) {
    final entry = _otherClipboard;
    if (entry == null ||
        entry.source != HomePasteArea.outgoing ||
        entry.id != oldPath ||
        !mounted) {
      return;
    }
    setState(() {
      _otherClipboard = HomeClipboardEntry(
        source: entry.source,
        id: newPath,
        name: newName,
        isFolder: entry.isFolder,
        isCut: entry.isCut,
        originalArea: entry.originalArea,
      );
    });
  }

  void _copyLibraryEntry(HomeClipboardEntry entry) {
    setState(() {
      _clipboardProjectIds.clear();
      _clipboardFolderIds.clear();
      _clipboardSourceArea = entry.source;
      _clipboardIsCut = entry.isCut;
      _otherClipboard = entry;
    });
    if (mounted) {
      _showClipboardFeedback(
        AppLocalizations.of(context)!.homeCopiedSnackbar(1),
        describesClipboard: true,
      );
    }
  }

  HomePasteArea get _pasteDestination => switch (_currentTabIndex) {
    0 => HomePasteArea.projects,
    1 => HomePasteArea.works,
    2 => _sharedOutgoing ? HomePasteArea.outgoing : HomePasteArea.received,
    _ => HomePasteArea.trash,
  };

  Future<void> _explainPasteRestriction(
    String Function(AppLocalizations l10n) message,
  ) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('homePasteRestrictionDialog'),
        title: Text(l10n.homePasteRestrictionTitle),
        content: Text(message(l10n)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmPasteToTrash(
    List<String> names, {
    List<String> kept = const [],
  }) async {
    final days = context.read<SettingsService>().trashAutoDeleteDays;
    final l10n = AppLocalizations.of(context)!;
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            key: const Key('homePasteToTrashDialog'),
            title: Text(l10n.homeMoveToTrash),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 韓国語の語は、1行に入れば途中で折らない（ほかのゴミ箱へ
                  // 移す確認と同じ）。
                  messageText(l10n.homePasteToTrashQuestion),
                  for (final name in names)
                    copyNameText(l10n.commonBulletItem(name), name: name),
                  if (kept.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    messageText(l10n.homePasteToTrashKeepsFavorites),
                    for (final name in kept)
                      copyNameText(l10n.commonBulletItem(name), name: name),
                  ],
                  const SizedBox(height: 12),
                  countText(
                    days > 0
                        ? l10n.homeTrashAutoDeleteNotice(days)
                        : l10n.homeTrashAutoDeleteOffNotice,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                key: const Key('homePasteTrashConfirmButton'),
                onPressed: () => Navigator.pop(ctx, true),
                // ほかのゴミ箱へ移す確認と同じ、見出しと同じ動詞（以前は
                // 「移動」で、仏語は見出しが「Mettre à la corbeille」なのに
                // ボタンは「Déplacer」だった）。
                child: trashConfirmLabelText(l10n.homeMoveToTrash),
              ),
            ],
          ),
        ) ??
        false;
  }

  bool _pasting = false;

  // 貼り付けを押してから終わるまで（確認のダイアログ・書き出したファイルの
  // 読み込みを待っている間も）。_pastingは貼り付けを始めてから立つので、
  // その前にもう一度押すと2回貼り付けた（書き出したファイルのフォルダが
  // 2つできた）。
  bool _pasteRequested = false;
  Future<void> _pasteClipboard() async {
    if (_pasting || _pasteRequested || !_hasClipboard) return;
    _pasteRequested = true;
    try {
      await _pasteClipboardNow();
    } finally {
      _pasteRequested = false;
      // 貼り付けでクリップボードが空になったら（切り取りを貼り終えた・
      // ゴミ箱へ移した）、切り取りの印（Esc）と中身を伝える知らせも消す。
      if (mounted && !_hasClipboard) _clearHomeClipboard();
    }
  }

  Future<void> _pasteClipboardNow() async {
    if (_pasting || !_hasClipboard) return;
    if (_otherClipboard != null) {
      await _pasteLibraryEntry();
      return;
    }
    final service = context.read<ProjectService>();
    final folderIds = _clipboardFolderIds.toList();
    final projectIds = _clipboardProjectIds.toList();
    final target = _pasteDestination;
    final emptyFolders = folderIds.every(
      (id) => service.folderContentCounts(id).projects == 0,
    );
    final decision = HomePastePolicy.check(
      source: _clipboardSourceArea,
      destination: target,
      containsFiles: projectIds.isNotEmpty || !emptyFolders,
      containsFolders: folderIds.isNotEmpty,
    );
    if (decision != HomePasteDecision.allowed) {
      await _explainPasteRestriction((l) => l.homePasteCrossFormatBody);
      return;
    }
    if (target == HomePasteArea.outgoing) {
      await _explainPasteRestriction((l) => l.homePasteOutgoingNoFolders);
      return;
    }
    if (target != HomePasteArea.projects &&
        target != HomePasteArea.trash &&
        folderIds.any((id) => service.folderContentCounts(id).folders > 0)) {
      await _explainPasteRestriction((l) => l.homePasteNestedFolders);
      return;
    }
    if (target == HomePasteArea.trash) {
      // お気に入りの作品と、それを含むフォルダはゴミ箱へ移さない（貼り付けの
      // 結果で断る）。確かめるときに分けて出し、移すものが無ければ確かめない
      // （以前は後で断るお気に入りも、移すものと同じ並びに出していた）。
      // お気に入りのフォルダ自身も（メニュー・選んで移すときと同じく）移さない。
      // 下の階層のお気に入りのフォルダも（中身として移さない）。
      bool holdsFavorite(String folderId) {
        final subtree = service.folderSubtreeIds(folderId);
        return service.folders.any(
              (f) => subtree.contains(f.id) && f.isFavorite,
            ) ||
            service.projects.any(
              (p) => p.isFavorite && subtree.contains(p.folderId),
            );
      }

      final names = <String>[];
      final kept = <String>[];
      for (final id in projectIds) {
        for (final p in service.projects.where((p) => p.id == id)) {
          (p.isFavorite ? kept : names).add(p.name);
        }
      }
      for (final id in folderIds) {
        for (final f in service.folders.where((f) => f.id == id)) {
          (holdsFavorite(f.id) ? kept : names).add(f.name);
        }
      }
      if (names.isEmpty && kept.isEmpty) return;
      if (names.isNotEmpty &&
          (!await _confirmPasteToTrash(names, kept: kept) || !mounted)) {
        return;
      }
    }
    final l10n = AppLocalizations.of(context)!;
    final namer = _copyNamer(context);
    final workFolders = context.read<WorkFolderService>();
    final cut = _clipboardIsCut;
    // 貼り付けられない物があっても止めずに残りを貼り付け、件数を数える。
    // 元が無くなった物はクリップボードから外し（もう一度押しても同じ失敗を
    // 繰り返さない）、保存できなかった物・お気に入り・自分の中へ移せない
    // フォルダは残す（直してからもう一度貼り付けられる）。
    final tally = _PasteTally();
    bool leavesClipboard(_PasteOutcome outcome) =>
        outcome == _PasteOutcome.missing ||
        (outcome == _PasteOutcome.pasted &&
            (cut || target == HomePasteArea.trash));
    setState(() => _pasting = true);
    try {
      if (target == HomePasteArea.trash) {
        // Duplicate descendants can appear in the selection. Moving a
        // parent folder takes its descendants; rows that were there when the
        // paste began and are gone now went to the Trash with their folder.
        final present = {
          for (final p in service.projects) p.id,
          for (final f in service.folders) f.id,
        };
        for (final id in folderIds) {
          final outcome = await tally.run(
            () async =>
                await service.moveFolderToTrash(id) != null ||
                present.contains(id),
          );
          if (leavesClipboard(outcome)) _clipboardFolderIds.remove(id);
        }
        for (final id in projectIds) {
          final outcome = await tally.run(() async {
            if (!service.projects.any((p) => p.id == id)) {
              return present.contains(id);
            }
            await service.deleteProject(id);
            return true;
          });
          if (leavesClipboard(outcome)) _clipboardProjectIds.remove(id);
        }
      } else if (target == HomePasteArea.projects) {
        for (final id in projectIds) {
          final outcome = await tally.run(() async {
            if (cut) {
              if (!service.projects.any((project) => project.id == id)) {
                return false;
              }
              await service.moveToFolder(id, _currentFolderId);
              return true;
            }
            return service.duplicateProject(
              id,
              targetFolderId: _currentFolderId,
              useTargetFolder: true,
              namer: namer,
            );
          });
          if (leavesClipboard(outcome)) _clipboardProjectIds.remove(id);
        }
        for (final id in folderIds) {
          if (cut &&
              (id == _currentFolderId ||
                  service.isFolderDescendantOf(_currentFolderId ?? '', id))) {
            tally.add(_PasteOutcome.intoSelf);
            continue;
          }
          final outcome = await tally.run(() async {
            final source = service.folders.where((f) => f.id == id).firstOrNull;
            if (source == null) return false;
            if (cut) {
              await service.moveFolderTo(id, _currentFolderId);
              return true;
            }
            final result = await service.duplicateFolder(
              id,
              targetParentId: _currentFolderId,
              name: duplicateFolderName(
                l10n,
                source.name,
                parentId: _currentFolderId,
                folders: service.folders,
              ),
            );
            return result != null;
          });
          if (leavesClipboard(outcome)) _clipboardFolderIds.remove(id);
        }
      } else {
        // A format-neutral empty folder is created in the destination
        // collection. Removing a cut source occurs ONLY after that succeeds.
        for (final id in folderIds) {
          final outcome = await tally.run(() async {
            final folder = service.folders.where((f) => f.id == id).firstOrNull;
            if (folder == null) return false;
            if (target == HomePasteArea.works) {
              await workFolders.createFolder(folder.name);
            } else {
              await service.createSharedFolder(folder.name);
            }
            if (cut) await service.deleteFolder(id);
            return true;
          });
          if (leavesClipboard(outcome)) _clipboardFolderIds.remove(id);
        }
      }
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
      tally.add(_PasteOutcome.failed);
    } finally {
      if (mounted) {
        setState(() => _pasting = false);
        _showClipboardFeedback(tally.message(l10n));
      }
    }
  }

  /// An exported-work folder owns real video/image files, not project rows.
  /// Copy the bytes and only then write each new file's membership.
  Future<void> _copyWorkFolderWithContents(
    String sourceId,
    String sourceName,
    WorkFolderService workFolders,
    AppLocalizations l10n,
  ) async {
    if (!workFolders.folders.any((folder) => folder.id == sourceId)) {
      throw const _ClipboardSourceMissing();
    }
    final exported = await ExportEngine.listExportedFiles(forceRefresh: true);
    final members = exported
        .where(
          (file) =>
              workFolders.folderIdOf(file.uri.pathSegments.last) == sourceId,
        )
        .toList();
    final copiedFolder = await workFolders.createFolder(
      numberedCopyName(l10n, sourceName, {
        for (final folder in workFolders.folders) folder.name,
      }),
    );
    final copies = <File>[];
    try {
      for (final source in members) {
        final destination = await _copyFileDestination(l10n, source);
        final saved = await source.copy(destination.path);
        copies.add(saved);
        if (await saved.length() != await source.length()) {
          throw FileSystemException('Incomplete folder copy', source.path);
        }
        await workFolders.moveFileToFolder(
          saved.uri.pathSegments.last,
          copiedFolder.id,
        );
      }
      LocalFileTrashService.changes.value++;
      StorageInfoService().invalidate();
    } catch (_) {
      // If copying fails, preserve any completed files and folder so no
      // persistent metadata points at deleted data.
      LocalFileTrashService.changes.value++;
      rethrow;
    }
  }

  Future<void> _pasteLibraryEntry() async {
    final entry = _otherClipboard;
    if (entry == null || _pasting) return;
    final ps = context.read<ProjectService>();
    final ws = context.read<WorkFolderService>();
    final dest = _pasteDestination;
    // Persisted folder memberships can outlive an exported file that was
    // removed. The empty-folder exception is based on files that actually
    // exist in the Works list, not stale preference records.
    var workFolderHasFiles = false;
    if (entry.isFolder && entry.source == HomePasteArea.works) {
      try {
        final exports = await ExportEngine.listExportedFiles(
          forceRefresh: true,
        );
        workFolderHasFiles = exports.any(
          (file) => ws.folderIdOf(file.uri.pathSegments.last) == entry.id,
        );
      } catch (error, stackTrace) {
        AppErrorReporter.record(error, stackTrace);
        await _explainPasteRestriction((l) => l.homePasteFolderUnreadable);
        return;
      }
      if (!mounted) return;
    }
    final containsFiles =
        !entry.isFolder ||
        (entry.source == HomePasteArea.works && workFolderHasFiles) ||
        (entry.source == HomePasteArea.received &&
            ps.shared.any((p) => p.sharedFolderId == entry.id));
    final decision = HomePastePolicy.check(
      source: entry.source,
      destination: dest,
      originalArea: entry.originalArea,
      containsFiles: containsFiles,
      containsFolders: entry.isFolder,
    );
    if (decision != HomePasteDecision.allowed) {
      await _explainPasteRestriction((l) => l.homePasteCrossFormatBody);
      return;
    }
    if (entry.isFolder && dest == HomePasteArea.outgoing) {
      await _explainPasteRestriction((l) => l.homePasteOutgoingNoFolders);
      return;
    }
    if (dest == HomePasteArea.trash) {
      if (entry.isFolder &&
          entry.source != HomePasteArea.works &&
          entry.source != HomePasteArea.received) {
        await _explainPasteRestriction((l) => l.homePasteFolderNotTrashable);
        return;
      }
      if (!await _confirmPasteToTrash([entry.name]) || !mounted) return;
    }
    if (entry.source == HomePasteArea.trash) {
      final l10n = AppLocalizations.of(context)!;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          key: const Key('homePasteRestoreDialog'),
          title: Text(l10n.homeRestoreFromTrashTitle),
          content: copyNameText(
            '${l10n.homeRestoreFromTrashQuestion}\n'
            '${l10n.commonBulletItem(entry.name)}',
            name: entry.name,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              key: const Key('homePasteRestoreConfirmButton'),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.commonRestore),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    final l10n = AppLocalizations.of(context)!;
    final namer = _copyNamer(context);
    setState(() => _pasting = true);
    try {
      if (entry.source == HomePasteArea.trash) {
        if (entry.isFolder) {
          if (entry.originalArea == HomePasteArea.works) {
            final files = await LocalFileTrashService.list();
            final folder = files
                .where((f) => f.id == entry.id && f.isFolder)
                .firstOrNull;
            if (folder == null) throw const _ClipboardSourceMissing();
            await LocalFileTrashService.restoreWorkFolder(folder, ws);
            StorageInfoService().invalidate();
          } else {
            // 戻すフォルダが無い（ゴミ箱から消した）ときは何も起きない。
            if (!ps.trashedFolders.any((t) => t.folder.id == entry.id)) {
              throw const _ClipboardSourceMissing();
            }
            await ps.restoreTrashedFolder(entry.id);
          }
        } else if (entry.originalArea == HomePasteArea.projects ||
            entry.originalArea == HomePasteArea.received) {
          // 戻す作品が無い（ゴミ箱から消した）ときは何も起きない。
          if (!ps.trash.any((p) => p.id == entry.id)) {
            throw const _ClipboardSourceMissing();
          }
          await ps.restoreProject(entry.id);
        } else {
          final files = await LocalFileTrashService.list();
          final file = files.where((f) => f.id == entry.id).firstOrNull;
          if (file == null) throw const _ClipboardSourceMissing();
          await LocalFileTrashService.restore(file);
          StorageInfoService().invalidate();
          if (entry.originalArea == HomePasteArea.outgoing) {
            await ps.refreshOutgoingShares();
          }
        }
        _otherClipboard = null;
      } else if (dest == HomePasteArea.trash) {
        if (entry.isFolder && entry.source == HomePasteArea.received) {
          final moved = await ps.moveFolderToTrash(entry.id, shared: true);
          if (moved == null) throw const _ClipboardSourceMissing();
        } else if (entry.isFolder && entry.source == HomePasteArea.works) {
          if (!ws.folders.any((folder) => folder.id == entry.id)) {
            throw const _ClipboardSourceMissing();
          }
          final files = await ExportEngine.listExportedFiles(
            forceRefresh: true,
          );
          final members = files
              .where(
                (file) => ws.folderIdOf(file.uri.pathSegments.last) == entry.id,
              )
              .toList();
          await LocalFileTrashService.moveWorkFolder(
            folderName: entry.name,
            files: members,
          );
          // Delete membership only AFTER the archive is safely stored.
          await ws.deleteFolder(entry.id);
          StorageInfoService().invalidate();
        } else if (entry.source == HomePasteArea.received) {
          // 受け取った作品が無い（もうゴミ箱へ移した・消した）ときは何も
          // 起きない。
          if (!ps.shared.any((p) => p.id == entry.id)) {
            throw const _ClipboardSourceMissing();
          }
          await ps.deleteProject(entry.id);
        } else {
          if (!await File(entry.id).exists()) {
            throw const _ClipboardSourceMissing();
          }
          await LocalFileTrashService.move(
            File(entry.id),
            entry.source == HomePasteArea.works
                ? LocalTrashKind.exportedWork
                : LocalTrashKind.outgoingShare,
          );
          StorageInfoService().invalidate();
          if (entry.source == HomePasteArea.outgoing) {
            await ps.refreshOutgoingShares();
          }
        }
        _otherClipboard = null;
      } else if (entry.isFolder) {
        // 元のフォルダが無い（消した・ゴミ箱へ移した）ときは、同じ名前の
        // フォルダを作らない。
        final sourceExists = switch (entry.source) {
          HomePasteArea.works => ws.folders.any((f) => f.id == entry.id),
          HomePasteArea.received => ps.sharedFolders.any(
            (f) => f.id == entry.id,
          ),
          _ => true,
        };
        if (!sourceExists) throw const _ClipboardSourceMissing();
        if (dest == HomePasteArea.projects) {
          await ps.createFolder(entry.name, parentFolderId: _currentFolderId);
        } else if (dest == HomePasteArea.works) {
          if (entry.source == HomePasteArea.works) {
            await _copyWorkFolderWithContents(entry.id, entry.name, ws, l10n);
          } else {
            await ws.createFolder(entry.name);
          }
        } else if (dest == HomePasteArea.received) {
          if (entry.source == HomePasteArea.received) {
            await ps.duplicateSharedFolderWithContents(entry.id, namer: namer);
          } else {
            await ps.createSharedFolder(entry.name);
          }
        }
        if (entry.isCut) {
          if (entry.source == HomePasteArea.works) {
            await ws.deleteFolder(entry.id);
          } else if (entry.source == HomePasteArea.received) {
            await ps.deleteSharedFolder(entry.id);
          }
          _otherClipboard = null;
        }
      } else if (entry.source == HomePasteArea.received) {
        if (!await ps.duplicateProject(entry.id, namer: namer)) {
          throw const _ClipboardSourceMissing();
        }
      } else {
        final original = File(entry.id);
        if (!await original.exists()) throw const _ClipboardSourceMissing();
        final fileName = original.uri.pathSegments.last;
        final destFile = await _copyFileDestination(l10n, original);
        await original.copy(destFile.path);
        if (entry.source == HomePasteArea.outgoing) {
          await ps.refreshOutgoingShares();
        } else {
          final folder = ws.folderIdOf(fileName);
          if (folder != null) {
            await ws.moveFileToFolder(destFile.uri.pathSegments.last, folder);
          }
          LocalFileTrashService.changes.value++;
        }
      }
      if (mounted) {
        setState(() {});
        _showClipboardFeedback(l10n.homePastedSnackbar(1));
      }
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
      // 元が無くなった物はクリップボードから外す（もう一度押しても同じ
      // 失敗を繰り返さない）。
      if (error is _ClipboardSourceMissing) _otherClipboard = null;
      if (mounted) {
        _showClipboardFeedback(
          (_PasteTally()..add(
                error is _ClipboardSourceMissing
                    ? _PasteOutcome.missing
                    : error is FavoriteProjectDeleteException
                    ? _PasteOutcome.favorite
                    : _PasteTally.failureOf(error),
              ))
              .message(l10n),
        );
      }
    } finally {
      if (mounted) setState(() => _pasting = false);
    }
  }

  /// フォルダ階層のパンくずリスト。フォルダ内移動時に現在位置を表示する。
  /// ホームアイコンでルートへ、各フォルダ名でその階層へ移動。
  Widget _buildBreadcrumb() {
    if (_currentFolderId == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final foreground = Theme.of(context).colorScheme.onSurface;
    final folders = context.watch<ProjectService>().folders;
    final chain = <ProjectFolder>[];
    String? current = _currentFolderId;
    while (current != null) {
      final folder = folders.where((f) => f.id == current).firstOrNull;
      if (folder == null) break;
      chain.insert(0, folder);
      current = folder.parentFolderId;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            IconButton(
              tooltip: l10n.projectListFolderRootOption,
              onPressed: () =>
                  _changeProjectScope(() => _currentFolderId = null),
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              visualDensity: VisualDensity.standard,
              icon: const Icon(Icons.home, size: 18),
            ),
            for (final folder in chain) ...[
              const Icon(Icons.chevron_right, size: 16),
              TextButton(
                onPressed: () =>
                    _changeProjectScope(() => _currentFolderId = folder.id),
                style: TextButton.styleFrom(
                  foregroundColor: foreground,
                  minimumSize: const Size(48, 48),
                  visualDensity: VisualDensity.standard,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  folder.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'Kuramubon',
                    fontFamilyFallback: kHeadingFontFallback,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ホームの浮かぶボタン（「一番上へ」・＋・新しいフォルダ）。キーボードで
/// フォーカスしている間は、ボタンの外側に輪を描いて示す（フォーカスの
/// 見える化、WCAG 2.4.7）。テーマのフォーカスの印は塗りが少し暗くなる
/// だけ（既定の差し色で約1.15:1）で、どのボタンにいるか分からなかった。
/// 輪の色は、絞り込みのチップの輪（[ChipFocusRing]）と同じ地の上の文字の
/// 色で、ボタンの塗りとも地とも分かれる。マウス・指で操作しているとき
/// （[FocusHighlightMode.touch]）は出さない。
/// ホームのタブ。動きを減らす設定（端末の「アニメーションを削除」）では、
/// タブを替えると本文がその場で次のタブになる（TabBarViewは
/// [animationDuration]が0なら横に滑らせずにページを替え、TabBarは選んだ
/// タブを[animateTo]で選ぶ）。以前は設定を見ずに約300ms横に滑った。設定が
/// オフなら既定のまま。
class _HomeTabController extends TabController {
  _HomeTabController({required super.length, required super.vsync});

  /// 動きを減らす設定（組み立てのたびにホームが合わせる）。
  bool reduceMotion = false;

  @override
  Duration get animationDuration =>
      reduceMotion ? Duration.zero : super.animationDuration;

  @override
  void animateTo(int value, {Duration? duration, Curve curve = Curves.ease}) {
    super.animateTo(
      value,
      duration: duration ?? animationDuration,
      curve: curve,
    );
  }
}

class _HomeFloatingAction extends StatefulWidget {
  const _HomeFloatingAction({
    this.fabKey,
    required this.heroTag,
    required this.tooltip,
    required this.compact,
    required this.onPressed,
    required this.icon,
  });

  /// 浮かぶボタン（[FloatingActionButton]）そのものに付けるキー。
  final Key? fabKey;
  final String heroTag;
  final String tooltip;
  final bool compact;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  State<_HomeFloatingAction> createState() => _HomeFloatingActionState();
}

class _HomeFloatingActionState extends State<_HomeFloatingAction> {
  final _focusNode = FocusNode(debugLabel: 'homeFloatingAction');

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_changed);
    FocusManager.instance.addHighlightModeListener(_highlightModeChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_highlightModeChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _highlightModeChanged(FocusHighlightMode mode) => _changed();

  @override
  Widget build(BuildContext context) {
    final ring =
        _focusNode.hasPrimaryFocus &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    return FloatingActionButton(
      key: widget.fabKey,
      focusNode: _focusNode,
      heroTag: widget.heroTag,
      mini: widget.compact,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      tooltip: widget.tooltip,
      // ThemeService provides the common shape, colors and zero shadow.
      // 輪は縁の外側に描く（内側に描くと塗りとアイコンが縁の分だけ狭まる）。
      shape: ring
          ? CircleBorder(
              side: BorderSide(
                color: Theme.of(context).colorScheme.onSurface,
                width: 3,
                strokeAlign: BorderSide.strokeAlignOutside,
              ),
            )
          : null,
      onPressed: widget.onPressed,
      child: Icon(widget.icon),
    );
  }
}

/// Responsive four-tab navigation: icons on compact phones and centered
/// icon/label pairs once every translated label fits (same as Works Plaza).
/// ホームのTabの順番：上部バー（戻る・表示・検索・メニュー・タブ）→一覧
/// （先頭の絞り込み・並び順から行の順）→浮かぶボタン。
///
/// 読む順（ReadingOrderTraversalPolicy）は画面の位置だけで並べるので、一覧を
/// スクロールして上部バーの裏へ隠れた行がタブと同じ高さに並び、タブの間に
/// 見えない行が挟まった。一覧（[listArea]の中）の物はまとめて、一覧の上端の
/// 位置に置く。移った先は、上下どちらへ隠れていても一覧の見える所へ送り出す
/// （既定のTabは前へ進むとき下に隠れた物しか送り出さず、上へ隠れた行・並び順
/// の見出しへ進むと、上部バーの裏の何も見えない所が光った）。下へ送り出す
/// ときは、一覧の下に浮かぶボタン（[floatingActions]）の上まで送る（一覧の
/// 下端までしか送らないと、一番下の行の右の︙が＋の下に隠れた）。
class _HomeTraversalPolicy extends ReadingOrderTraversalPolicy {
  _HomeTraversalPolicy(this.listArea, {required GlobalKey floatingActions})
    : super(
        requestFocusCallback:
            (node, {alignmentPolicy, alignment, duration, curve}) =>
                _revealTraversedFocus(node, listArea, floatingActions),
      );

  final GlobalKey listArea;

  /// 浮かぶボタンの上に空ける間（一覧の下に浮かぶボタンの分として空けた
  /// 余白88＝ボタン56・画面の下の余白16・この間16と同じ）。
  static const double _floatingActionsGap = 16;

  @override
  Iterable<FocusNode> sortDescendants(
    Iterable<FocusNode> descendants,
    FocusNode currentNode,
  ) {
    final area = listArea.currentContext;
    final box = area?.findRenderObject();
    if (area == null || box is! RenderBox || !box.attached || !box.hasSize) {
      return super.sortDescendants(descendants, currentNode);
    }
    final inside = <FocusNode>[];
    final others = <FocusNode>[];
    for (final node in descendants) {
      var found = false;
      node.context?.visitAncestorElements((element) {
        found = identical(element, area);
        return !found;
      });
      (found ? inside : others).add(node);
    }
    if (inside.isEmpty) return super.sortDescendants(descendants, currentNode);
    // 一覧の物は一覧の物だけで、それ以外はそれ以外だけで読む順に並べる。
    // まとめて並べると、一覧の上に浮かぶボタン（「一番上へ」・＋）が同じ
    // 高さの行の並びに混ざり、その高さに入った行の︙だけが同じ行の星より先に
    // 並んだ。Tabで進んで一覧がスクロールするたびに並びが変わり、同じ︙に
    // 2回止まる・星を飛ばすことがあった。
    final list = super.sortDescendants(inside, currentNode);
    final rest = super.sortDescendants(others, currentNode).toList();
    final top = box.localToGlobal(Offset.zero).dy;
    // 上端が一覧より上の物（上部バー・タブ・操作バー、画面を包むノード）は
    // 一覧の前、浮かぶボタンは後。
    bool above(FocusNode node) => node.rect.top < top;
    return [
      ...rest.where(above),
      ...list,
      ...rest.where((node) => !above(node)),
    ];
  }

  static void _revealTraversedFocus(
    FocusNode node,
    GlobalKey listArea,
    GlobalKey floatingActions,
  ) {
    node.requestFocus();
    final context = node.context;
    if (context == null) return;
    _keepAboveFloatingActions(context, listArea, floatingActions);
    for (final policy in const [
      ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    ]) {
      Scrollable.ensureVisible(context, alignmentPolicy: policy);
    }
  }

  /// タブの一覧（[listArea]）の中の部品を、一覧の見える所のうち浮かぶ
  /// ボタンより上へ送り出す（入らないほど高い部品は上端をそろえる）。浮かぶ
  /// ボタンが無い（ゴミ箱のタブ・選んでいる間）ときは一覧の下端まで。続けて
  /// 呼ぶ[Scrollable.ensureVisible]は、もう見えているので縦には動かさない。
  /// 一覧の外（引き出し等）は浮かぶボタンの下に入らないので送らない。
  static void _keepAboveFloatingActions(
    BuildContext context,
    GlobalKey listArea,
    GlobalKey floatingActions,
  ) {
    final area = listArea.currentContext;
    var inList = false;
    context.visitAncestorElements((element) {
      inList = identical(element, area);
      return !inList;
    });
    if (!inList) return;
    final target = context.findRenderObject();
    final scrollable = Scrollable.maybeOf(context, axis: Axis.vertical);
    final view = scrollable?.context.findRenderObject();
    if (target is! RenderBox ||
        !target.attached ||
        !target.hasSize ||
        view is! RenderBox ||
        !view.attached ||
        !view.hasSize ||
        scrollable!.position.axisDirection != AxisDirection.down) {
      return;
    }
    final shown = view.localToGlobal(Offset.zero) & view.size;
    var bottom = shown.bottom;
    final actions = floatingActions.currentContext?.findRenderObject();
    if (actions is RenderBox && actions.attached && actions.hasSize) {
      final top = actions.localToGlobal(Offset.zero).dy - _floatingActionsGap;
      if (top < bottom) bottom = top;
    }
    final rect = target.localToGlobal(Offset.zero) & target.size;
    var delta = 0.0;
    if (rect.bottom > bottom) delta = rect.bottom - bottom;
    if (rect.top - delta < shown.top) delta = rect.top - shown.top;
    if (delta.abs() < 0.5) return;
    final position = scrollable.position;
    position.jumpTo(
      (position.pixels + delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
  }
}

class _HomeTabBar extends StatelessWidget {
  const _HomeTabBar({
    required this.controller,
    required this.currentIndex,
    required this.labels,
  });

  final TabController controller;
  final int currentIndex;
  final List<String> labels;

  static const _icons = <IconData>[
    Icons.movie_creation_outlined,
    Icons.video_library_outlined,
    Icons.share_outlined,
    Icons.delete_outline,
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = scheme.primary;
    final labelStyle = const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      fontFamily: 'Kuramubon',
      fontFamilyFallback: kHeadingFontFallback,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context);
        final cellWidth = constraints.maxWidth / labels.length;
        const iconWidth = 24.0;
        const gap = 8.0;
        const breathingRoom = 16.0;
        final showLabels = labels.every((label) {
          final painter = TextPainter(
            text: TextSpan(text: label, style: labelStyle),
            textDirection: Directionality.of(context),
            textScaler: textScale,
            locale: Localizations.localeOf(context),
            maxLines: 1,
          )..layout();
          final fits =
              iconWidth + gap + painter.width + breathingRoom <= cellWidth;
          painter.dispose();
          return fits;
        });
        return TabBar(
          controller: controller,
          isScrollable: false,
          labelPadding: EdgeInsets.zero,
          labelColor: selected,
          // タブはアプリバー（メニュー背景色）の上に描くので、選んでいない
          // タブはメニュー文字色から作る（本文の文字色から作ると、メニューが
          // 暗く本文の文字も暗いテーマで見えなくなる）。
          unselectedLabelColor:
              (Theme.of(context).appBarTheme.foregroundColor ??
                      scheme.onSurface)
                  .withValues(alpha: 0.7),
          labelStyle: labelStyle,
          unselectedLabelStyle: labelStyle,
          indicatorColor: selected,
          tabs: [
            for (var i = 0; i < labels.length; i++)
              Tab(
                height: 48,
                child: Semantics(
                  key: ValueKey('home_tab_$i'),
                  button: true,
                  selected: currentIndex == i,
                  label: labels[i],
                  child: Tooltip(
                    message: labels[i],
                    triggerMode: TooltipTriggerMode.longPress,
                    child: Center(
                      child: showLabels
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_icons[i], size: iconWidth),
                                const SizedBox(width: gap),
                                Flexible(
                                  child: Text(
                                    labels[i],
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.clip,
                                  ),
                                ),
                              ],
                            )
                          : Icon(_icons[i], size: iconWidth),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 作品一覧・共有・ゴミ箱の並び順・絞り込みを、タブを切り替えて戻っても、
/// アプリを起動し直しても覚えておく（所有者の判断：プロジェクトと同じく
/// 起動し直しても残す。設定の引き継ぎにも入る）。TabBarView は見えない
/// タブの中身を破棄するので、作るときに設定（[SettingsService]）から戻し、
/// 変わったらすぐ設定へ書く（破棄のときに書くと、アプリを閉じる・落ちる
/// ときに残らない）。並び順（名前／更新日時と向き）を変える操作もここに
/// まとめる。
mixin _RememberedListFilters<T extends StatefulWidget> on State<T> {
  /// 設定の中でこの一覧の並び順・絞り込みを覚える区分。
  HomeList get filtersList;

  /// 今の並び順・絞り込み（後から変えても影響しない写し）。
  HomeListFilters get filters;

  /// 覚えていた並び順・絞り込みを戻す（読めない・知らない名前は既定のまま）。
  void restoreFilters(HomeListFilters saved);

  /// この一覧の並び順（[ProjectSortMode]の4つ）。
  ProjectSortMode get _sortMode;
  set _sortMode(ProjectSortMode mode);

  SettingsService? _filterSettings;
  late HomeListFilters _rememberedFilters;

  @override
  void initState() {
    super.initState();
    _filterSettings = context.read<SettingsService?>();
    final saved = _filterSettings?.homeListFilters(filtersList);
    if (saved != null) restoreFilters(saved);
    _rememberedFilters = filters;
    _filterSettings?.homeListFiltersReloaded.addListener(_reloadFilters);
  }

  @override
  void dispose() {
    _filterSettings?.homeListFiltersReloaded.removeListener(_reloadFilters);
    super.dispose();
  }

  // 設定の引き継ぎで読み込んだ並び順・絞り込みを、開いている一覧にも当てる
  // （読み込んだ値なので書き戻さない）。
  void _reloadFilters() {
    final saved = _filterSettings?.homeListFilters(filtersList);
    if (saved == null || !mounted) return;
    restoreFilters(saved);
    _rememberedFilters = filters;
    super.setState(() {});
  }

  // 並び順・絞り込みを変える操作はどれも setState を通るので、ここで見て、
  // 変わった項目だけを設定へ書く。
  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    final before = _rememberedFilters;
    final now = filters;
    if (now == before) return;
    _rememberedFilters = now;
    _filterSettings?.updateHomeListFilters(
      filtersList,
      sort: now.sort == before.sort ? null : now.sort,
      favoritesOnly: now.favoritesOnly == before.favoritesOnly
          ? null
          : now.favoritesOnly,
      hiddenKinds: setEquals(now.hiddenKinds, before.hiddenKinds)
          ? null
          : now.hiddenKinds,
    );
  }

  // 現在の並び替えが名前基準かどうか（項目自体は4値のままだが、UI上は
  // 「項目（名前／更新日時）」と「昇順/降順」を別々の操作にする）。
  bool get _sortByName =>
      _sortMode == ProjectSortMode.nameAsc ||
      _sortMode == ProjectSortMode.nameDesc;
  bool get _sortAscending =>
      _sortMode == ProjectSortMode.nameAsc ||
      _sortMode == ProjectSortMode.updatedAsc;

  void _setSortByName(bool byName) => _chooseSort(
    byName
        ? (_sortAscending ? ProjectSortMode.nameAsc : ProjectSortMode.nameDesc)
        : (_sortAscending
              ? ProjectSortMode.updatedAsc
              : ProjectSortMode.updatedDesc),
  );

  void _toggleSortDirection() => _chooseSort(switch (_sortMode) {
    ProjectSortMode.nameAsc => ProjectSortMode.nameDesc,
    ProjectSortMode.nameDesc => ProjectSortMode.nameAsc,
    ProjectSortMode.updatedAsc => ProjectSortMode.updatedDesc,
    ProjectSortMode.updatedDesc => ProjectSortMode.updatedAsc,
  });

  /// [mode]をこの一覧の並び順にする。この一覧から開いたフォルダの中で
  /// 選んだときも（プロジェクトのフォルダと同じく、フォルダの中と外で同じ
  /// 並び順。戻ったときもその並びで出し、起動し直しても残る）。
  void _chooseSort(ProjectSortMode mode) {
    if (mounted) {
      setState(() => _sortMode = mode);
    } else {
      _filterSettings?.updateHomeListFilters(filtersList, sort: mode.name);
    }
  }
}

/// 保存した並び順の名前（[ProjectSortMode]）。読めない・知らない名前は
/// 既定の「更新日時」の新しい順。
ProjectSortMode _savedSortMode(String? name) =>
    ProjectSortMode.values.asNameMap()[name] ?? ProjectSortMode.updatedDesc;

/// 共有一覧。ホームタブと'/shared'直リンクで共用する。
class SharedScreen extends StatefulWidget {
  const SharedScreen({
    super.key,
    this.embedded = false,
    this.onDirectionChanged,
    this.onCopyEntry,
    this.onOutgoingRenamed,
    this.screenFocus,
    this.viewMode,
    this.onViewModeChanged,
    this.searchQuery = '',
    this.onClearSearch,
    this.initialOutgoing = false,
  });

  final bool embedded;

  /// 開いたときに「作成したもの」を出すか。ホームのタブは離れると作り
  /// 直されるので、ホームが覚えている選択を渡す（渡さないと、戻るたびに
  /// 「受け取ったもの」になり、ホームの覚えている貼り付け先と食い違う）。
  final bool initialOutgoing;
  final ProjectViewMode? viewMode;
  final ValueChanged<ProjectViewMode>? onViewModeChanged;
  final String searchQuery;

  /// 検索に当たるものが無いときの「検索をやめる」（ホームの検索を閉じる）。
  final VoidCallback? onClearSearch;
  final ValueChanged<bool>? onDirectionChanged;
  final ValueChanged<HomeClipboardEntry>? onCopyEntry;

  /// 「作成したもの」の名前を変えたとき（ホームのコピーしたものを新しい
  /// 名前のファイルにする）。
  final void Function(String oldPath, String newPath, String newName)?
  onOutgoingRenamed;

  /// ホームの画面のフォーカス（保存先を読めなかった知らせが消えたとき、
  /// フォーカスを戻す先）。
  final FocusNode? screenFocus;

  @override
  State<SharedScreen> createState() => _SharedScreenState();
}

class _SharedScreenState extends State<SharedScreen>
    with _RememberedListFilters<SharedScreen> {
  @override
  HomeList get filtersList => HomeList.shared;
  @override
  HomeListFilters get filters =>
      HomeListFilters(sort: _sortMode.name, favoritesOnly: _showFavoritesOnly);
  @override
  void restoreFilters(HomeListFilters saved) {
    _sortMode = _savedSortMode(saved.sort);
    _showFavoritesOnly = saved.favoritesOnly;
  }

  // Keep the received and locally exported snapshot collections distinct.
  late bool _showOutgoing = widget.initialOutgoing;
  ProjectViewMode? _standaloneViewMode;
  final _headerKey = GlobalKey(debugLabel: 'sharedListHeader');

  ProjectViewMode _effectiveViewMode(BuildContext context) =>
      widget.viewMode ??
      _standaloneViewMode ??
      switch (tileScreenClassForWidth(MediaQuery.sizeOf(context).width)) {
        TileScreenClass.phone => ProjectViewMode.small,
        TileScreenClass.tablet => ProjectViewMode.medium,
        TileScreenClass.desktop => ProjectViewMode.large,
      };

  void _selectViewMode(ProjectViewMode value) {
    if (widget.onViewModeChanged != null) {
      widget.onViewModeChanged!(value);
    } else {
      setState(() => _standaloneViewMode = value);
    }
  }

  @override
  void initState() {
    super.initState();
    LocalFileTrashService.changes.addListener(_refreshSavedShares);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshSavedShares();
    });
  }

  @override
  void dispose() {
    LocalFileTrashService.changes.removeListener(_refreshSavedShares);
    super.dispose();
  }

  void _refreshSavedShares() {
    if (mounted) context.read<ProjectService>().refreshOutgoingShares();
  }

  // プロジェクトタブと同じ並び替え基準・お気に入り絞り込みを、共有一覧にも
  // 同じ見た目・操作性で提供する。
  @override
  ProjectSortMode _sortMode = ProjectSortMode.updatedDesc;
  bool _showFavoritesOnly = false;

  /// 「お気に入りだけ」を外す（当たるものが無いときの「すべて表示」）。
  void _showAll() => setState(() => _showFavoritesOnly = false);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // 切り替え・並び順は一覧の先頭に置き、一覧と一緒にスクロールする
    // （プロジェクト・作品のタブと同じ）。上に固定していた頃は、低い画面
    // （横向き・分割画面）と大きな文字で一覧の場所が無くなってはみ出し、
    // 空の表示の文を画面に出せなかった。受け取ったもの⇔作成したもので
    // 一覧が替わっても、同じ切り替えのまま（フォーカス・状態を保つ）。
    final header = KeyedSubtree(
      key: _headerKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SharedDirectionSwitch(
            outgoing: _showOutgoing,
            onChanged: (outgoing) {
              setState(() => _showOutgoing = outgoing);
              widget.onDirectionChanged?.call(_showOutgoing);
            },
          ),
          _HomeCollectionSortHeader(
            sortByName: _sortByName,
            sortAscending: _sortAscending,
            onSortByNameChanged: _setSortByName,
            onToggleDirection: _toggleSortDirection,
            leading: ChipFocusRing(
              builder: (context, focusSide) => FilterChip(
                key: const Key('sharedFavoritesOnlyFilter'),
                side: focusSide,
                label: Text(
                  l10n.homeFavoritesOnly,
                  style: TextStyle(
                    fontFamily: 'Kuramubon',
                    fontFamilyFallback: kHeadingFontFallback,
                    color: _showFavoritesOnly
                        ? Theme.of(context).colorScheme.onPrimary
                        : null,
                  ),
                ),
                selectedColor: Theme.of(context).colorScheme.primary,
                checkmarkColor: Theme.of(context).colorScheme.onPrimary,
                selected: _showFavoritesOnly,
                onSelected: (v) => setState(() => _showFavoritesOnly = v),
              ),
            ),
          ),
        ],
      ),
    );
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(title: FitOrHideTitle(l10n.homeTabShared)),
      body: _showOutgoing
          ? _OutgoingSharesList(
              header: header,
              screenFocus: widget.screenFocus,
              onCopyEntry: widget.onCopyEntry,
              onRenamed: widget.onOutgoingRenamed,
              viewMode: _effectiveViewMode(context),
              sortMode: _sortMode,
              showFavoritesOnly: _showFavoritesOnly,
              searchQuery: widget.searchQuery,
              onClearSearch: widget.onClearSearch,
              onShowAll: _showAll,
            )
          : _SharedTab(
              header: header,
              viewMode: _effectiveViewMode(context),
              onViewModeChanged: _selectViewMode,
              sortMode: _sortMode,
              showFavoritesOnly: _showFavoritesOnly,
              searchQuery: widget.searchQuery,
              onClearSearch: widget.onClearSearch,
              onShowAll: _showAll,
              onCopyEntry: widget.onCopyEntry,
              screenFocus: widget.screenFocus,
            ),
      floatingActionButton: widget.embedded || _showOutgoing
          ? null
          : FloatingActionButton(
              heroTag: 'shared-add-folder',
              tooltip: l10n.homeAddSheetNewFolder,
              onPressed: () => showCreateFolderNameDialog(
                context,
                (name) =>
                    context.read<ProjectService>().createSharedFolder(name),
              ),
              child: const Icon(Icons.create_new_folder_outlined),
            ),
    );
  }
}

/// Trash supports four independent multi-select type filters.
enum TrashEntryKind {
  createdProject,
  receivedShare,
  createdShare,
  exportedWork,
}

String _trashKindLabel(BuildContext context, TrashEntryKind kind) {
  final l10n = AppLocalizations.of(context)!;
  return switch (kind) {
    TrashEntryKind.createdProject => l10n.homeTrashKindCreatedProject,
    TrashEntryKind.receivedShare => l10n.homeTrashKindReceivedShare,
    TrashEntryKind.createdShare => l10n.homeTrashKindCreatedShare,
    TrashEntryKind.exportedWork => l10n.homeTrashKindExportedWork,
  };
}

/// 作品一覧・共有の「自分が作成したもの」の行で出すファイルの大きさ
/// （表示の言語の書き方）。
String _homeFileSizeLabel(AppLocalizations l10n, int bytes) =>
    fileSizeLabel(l10n, bytes);

/// ゴミ箱一覧。ホームタブと'/trash'直リンクで共用する。
class TrashScreen extends StatefulWidget {
  const TrashScreen({
    super.key,
    this.embedded = false,
    this.onCopyEntry,
    this.screenFocus,
    this.searchQuery = '',
    this.onClearSearch,
  });

  final bool embedded;
  final String searchQuery;

  /// 検索に当たるものが無いときの「検索をやめる」（ホームの検索を閉じる）。
  final VoidCallback? onClearSearch;
  final ValueChanged<HomeClipboardEntry>? onCopyEntry;

  /// ホームの画面のフォーカス（保存先を読めなかった知らせが消えたとき、
  /// フォーカスを戻す先）。
  final FocusNode? screenFocus;

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen>
    with _RememberedListFilters<TrashScreen> {
  @override
  HomeList get filtersList => HomeList.trash;
  @override
  HomeListFilters get filters => HomeListFilters(
    sort: _sortMode.name,
    hiddenKinds: {
      for (final kind in TrashEntryKind.values)
        if (!_selectedKinds.contains(kind)) kind.name,
    },
  );
  @override
  void restoreFilters(HomeListFilters saved) {
    _sortMode = _savedSortMode(saved.sort);
    _selectedKinds
      ..clear()
      ..addAll([
        for (final kind in TrashEntryKind.values)
          if (!saved.hiddenKinds.contains(kind.name)) kind,
      ]);
  }

  // 共有一覧・プロジェクトタブと同じ並び替え基準を、同じ見た目・操作性で
  // 提供する（ゴミ箱にお気に入りの概念はないため絞り込みは対象外）。
  @override
  ProjectSortMode _sortMode = ProjectSortMode.updatedDesc;
  final Set<TrashEntryKind> _selectedKinds = {...TrashEntryKind.values};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(title: FitOrHideTitle(l10n.homeTabTrash)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 0,
                children: [
                  for (final kind in TrashEntryKind.values)
                    ChipFocusRing(
                      builder: (context, focusSide) => FilterChip(
                        key: ValueKey('trashKind_${kind.name}'),
                        side: focusSide,
                        label: Text(_trashKindLabel(context, kind)),
                        selected: _selectedKinds.contains(kind),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _selectedKinds.add(kind);
                          } else {
                            _selectedKinds.remove(kind);
                          }
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ),
          _HomeCollectionSortHeader(
            sortByName: _sortByName,
            sortAscending: _sortAscending,
            onSortByNameChanged: _setSortByName,
            onToggleDirection: _toggleSortDirection,
          ),
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: LocalFileTrashService.changes,
              builder: (context, version, _) => _TrashTab(
                key: ValueKey('trash-list-version-$version'),
                sortMode: _sortMode,
                selectedKinds: _selectedKinds,
                searchQuery: widget.searchQuery,
                onClearSearch: widget.onClearSearch,
                onShowAllKinds: () => setState(
                  () => _selectedKinds.addAll(TrashEntryKind.values),
                ),
                onCopyEntry: widget.onCopyEntry,
                screenFocus: widget.screenFocus,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Exact same sorting header geometry in Projects and Works (root/folders).
/// The shared SortModeControl is allowed the whole available trailing width,
/// so normal phones display the selected field label instead of only a clock.
class _HomeCollectionSortHeader extends StatelessWidget {
  const _HomeCollectionSortHeader({
    this.leading,
    required this.sortByName,
    required this.sortAscending,
    required this.onSortByNameChanged,
    required this.onToggleDirection,
  });

  final Widget? leading;
  final bool sortByName;
  final bool sortAscending;
  final ValueChanged<bool> onSortByNameChanged;
  final VoidCallback onToggleDirection;

  @override
  Widget build(BuildContext context) => Padding(
    key: const Key('homeCollectionSortHeader'),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 8)],
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: SortModeControl(
              sortByName: sortByName,
              sortAscending: sortAscending,
              onSortByNameChanged: onSortByNameChanged,
              onToggleDirection: onToggleDirection,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Library actions can wrap without taking space from the route title.
class _LibraryListControls extends StatelessWidget {
  const _LibraryListControls({required this.sort});

  final Widget sort;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: LayoutBuilder(
      builder: (context, constraints) => OverflowBar(
        alignment: MainAxisAlignment.end,
        overflowAlignment: OverflowBarAlignment.end,
        spacing: 8,
        overflowSpacing: 4,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth < 400 ? 96 : constraints.maxWidth,
            ),
            child: sort,
          ),
        ],
      ),
    ),
  );
}

/// [ProjectSortMode]に従って並び替えたリストを返す。共有一覧・ゴミ箱一覧
/// ・プロジェクト一覧のいずれでも同じ基準（名前／更新日時）で並び替える。
List<Project> _sortProjects(List<Project> projects, ProjectSortMode mode) {
  final list = List<Project>.from(projects);
  // 名前は人が読む順（数字は数として、大文字・小文字、全角・半角、
  // カタカナ・ひらがなの違いは区別しない）。
  final byName = nameComparator<Project>((p) => p.name);
  switch (mode) {
    case ProjectSortMode.nameAsc:
      list.sort(byName);
    case ProjectSortMode.nameDesc:
      list.sort((a, b) => byName(b, a));
    case ProjectSortMode.updatedAsc:
      list.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    case ProjectSortMode.updatedDesc:
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }
  return list;
}

class _SharedTab extends StatelessWidget {
  /// 一覧の先頭に出し、一覧と一緒にスクロールするもの（切り替え・並び順）。
  final Widget header;
  final ProjectViewMode viewMode;
  final ValueChanged<ProjectViewMode> onViewModeChanged;
  final ProjectSortMode sortMode;
  final bool showFavoritesOnly;
  final String searchQuery;
  final VoidCallback? onClearSearch;
  final VoidCallback? onShowAll;
  final ValueChanged<HomeClipboardEntry>? onCopyEntry;
  final FocusNode? screenFocus;

  const _SharedTab({
    required this.header,
    required this.viewMode,
    required this.onViewModeChanged,
    required this.sortMode,
    required this.showFavoritesOnly,
    required this.searchQuery,
    this.onClearSearch,
    this.onShowAll,
    this.onCopyEntry,
    this.screenFocus,
  });

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ProjectService>();
    final folders = service.sharedFolders;
    var shared = service.shared;
    if (showFavoritesOnly) {
      shared = shared.where((p) => p.isFavorite).toList();
    }
    // 大文字・小文字、全角・半角、カタカナ・ひらがなの違いを区別しない。
    final query = foldName(searchQuery).trim();
    if (query.isNotEmpty) {
      shared = shared.where((p) => nameMatches(p.name, query)).toList();
    }
    shared = _sortProjects(shared, sortMode);
    final visibleFolders = service.sharedFolders
        .where(
          (folder) =>
              (!showFavoritesOnly ||
                  folder.isFavorite ||
                  shared.any((p) => p.sharedFolderId == folder.id)) &&
              (query.isEmpty ||
                  nameMatches(folder.name, query) ||
                  shared.any((p) => p.sharedFolderId == folder.id)),
        )
        .toList();
    HomeCollectionSelectionScope.maybeOf(context)?.onVisibleIds({
      for (final folder in visibleFolders) 'shared_folder:${folder.id}',
      for (final project in shared)
        if (project.sharedFolderId == null ||
            !visibleFolders.any((f) => f.id == project.sharedFolderId))
          'shared_file:${project.id}',
    });
    final l10n = AppLocalizations.of(context)!;
    // 受け取ったものは保存先から読む。読めなかったときは知らせ、
    // 「共有プロジェクトがありません」とは言わない。
    final loadFailed = service.projectsLoadFailed;
    return _FolderableList<Project>(
      reserveForFloatingActions: true,
      allItems: shared,
      everyItem: service.shared,
      folders: visibleFolders,
      viewMode: viewMode,
      gridItemBuilder: (context, project) => _receivedShareProjectTile(
        context,
        project,
        onCopyEntry: onCopyEntry,
        grid: true,
      ),
      header: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          header,
          if (loadFailed)
            ProjectsLoadFailureNotice(
              key: const Key('sharedProjectsLoadFailed'),
              onRetry: service.retryLoadProjects,
              screenFocus: screenFocus,
            ),
        ],
      ),
      emptyState: loadFailed
          ? null
          : _filteredLibraryEmptyState(
                  context,
                  searchQuery: searchQuery,
                  favoritesOnly: showFavoritesOnly,
                  // 検索には当たるが、お気に入りで隠れているだけか。
                  hiddenByFavorites:
                      query.isNotEmpty &&
                      (service.shared.any((p) => nameMatches(p.name, query)) ||
                          service.sharedFolders.any(
                            (f) => nameMatches(f.name, query),
                          )),
                  searchHint: l10n.projectListNoMatchNameHint,
                  onClearSearch: onClearSearch,
                  onShowAll: onShowAll,
                ) ??
                EmptyStatePlaceholder(
                  icon: Icons.share_outlined,
                  title: l10n.homeSharedEmpty,
                  scrollable: false,
                ),
      folderIdOf: (p) => folders.any((f) => f.id == p.sharedFolderId)
          ? p.sharedFolderId
          : null,
      onEnterFolder: (folderId, folderName, itemsInFolder) =>
          Navigator.of(context).push(
            adMockMaterialPageRoute(
              builder: (_) => _SharedFolderScreen(
                folderId: folderId,
                folderName: folderName,
                viewMode: viewMode,
                onViewModeChanged: onViewModeChanged,
                sortMode: sortMode,
                showFavoritesOnly:
                    showFavoritesOnly &&
                    !service.sharedFolders.any(
                      (folder) => folder.id == folderId && folder.isFavorite,
                    ),
                searchQuery: nameMatches(folderName, query) ? '' : searchQuery,
                onCopyEntry: onCopyEntry,
              ),
            ),
          ),
      onToggleFolderFavorite: (folder) =>
          context.read<ProjectService>().toggleSharedFolderFavorite(folder.id),
      onRenameFolder: (id, name) =>
          context.read<ProjectService>().renameSharedFolder(id, name),
      onDeleteFolder: (id) async {
        final messenger = ScaffoldMessenger.of(context);
        final l10n = AppLocalizations.of(context)!;
        final projects = context.read<ProjectService>();
        if (await projects.moveFolderToTrash(id, shared: true) == null) return;
        // プロジェクトのフォルダと同じく、フォルダの名前で知らせて戻せる。
        showMovedToTrashSnackBar(
          messenger,
          l10n,
          projects,
          const [],
          folderIds: [id],
        );
      },
      onSetFolderThumbnail: (id, {required mode, sourceId, imagePath}) =>
          context.read<ProjectService>().setFolderThumbnail(
            id,
            mode: mode,
            sourceId: sourceId,
            imagePath: imagePath,
            shared: true,
          ),
      onCopyFolder: onCopyEntry == null
          ? null
          : (folder) => onCopyEntry!(
              HomeClipboardEntry(
                source: HomePasteArea.received,
                id: folder.id,
                name: folder.name,
                isFolder: true,
              ),
            ),
      itemBuilder: (context, project) => _receivedShareProjectTile(
        context,
        project,
        onCopyEntry: onCopyEntry,
        grid: false,
      ),
    );
  }
}

Widget _receivedShareProjectTile(
  BuildContext context,
  Project project, {
  required bool grid,
  ValueChanged<HomeClipboardEntry>? onCopyEntry,
}) {
  final l10n = AppLocalizations.of(context)!;
  final theme = Theme.of(context);
  final selection = HomeCollectionSelectionScope.maybeOf(context);
  final selectionId = 'shared_file:${project.id}';
  final selecting = selection?.active ?? false;
  final selectedTap = selecting
      ? () => selection!.onToggle(selectionId)
      : () => context.push('/project/${project.id}');
  final captionStyle = const TextStyle(
    fontFamily: 'Kuramubon',
    fontFamilyFallback: kHeadingFontFallback,
    height: kWrappedNameLineHeight,
  );
  Widget cover() {
    final thumbnailPath = project.thumbnailPath;
    if (thumbnailPath == null || thumbnailPath.isEmpty) {
      return ColoredBox(
        color: Color(project.backgroundColor),
        child: const Center(child: Icon(Icons.movie_creation_outlined)),
      );
    }
    return Image.file(
      File(thumbnailPath),
      fit: BoxFit.cover,
      cacheWidth: 320,
      errorBuilder: (context, error, stack) => ColoredBox(
        color: Color(project.backgroundColor),
        child: const Center(child: Icon(Icons.movie_creation_outlined)),
      ),
    );
  }

  void showFolderMove() {
    final service = context.read<ProjectService>();
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => WorkFolderMoveSheet(
        folders: service.sharedFolders,
        filename: project.name,
        onMove: (id) => service.moveToSharedFolder(project.id, id),
      ),
    );
  }

  final selectedLongPress = selection == null
      ? showFolderMove
      : () => selection.onLongPress(selectionId);
  if (grid) {
    return HomeCollectionSelectionSurface(
      selectionId: selectionId,
      child: collectionTileShadow(
        context,
        Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Colors.transparent, width: 2),
          ),
          child: InkWell(
            onTap: selectedTap,
            onLongPress: selectedLongPress,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      cover(),
                      if (!selecting)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: _sharedProjectActions(
                            context,
                            project,
                            onCopyEntry: onCopyEntry,
                            showFavorite: false,
                          ),
                        ),
                      if (!selecting)
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: _sharedProjectActions(
                            context,
                            project,
                            onCopyEntry: onCopyEntry,
                            showMenu: false,
                          ),
                        ),
                    ],
                  ),
                ),
                collectionTileCaption(context, project.name),
              ],
            ),
          ),
        ),
      ),
    );
  }
  return HomeCollectionSelectionSurface(
    selectionId: selectionId,
    grid: false,
    child: Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: theme.colorScheme.surfaceContainerLow,
      child: ListTile(
        leading: SizedBox(width: 56, height: 56, child: cover()),
        title: KoreanWordsText(
          project.name,
          copyMarks: copyMarkParts(project.name),
          keepJapaneseLineStarts: true,
          style: captionStyle,
        ),
        subtitle: DateLineText(
          '${l10n.homeProjectMeta(project.fps, project.durationSeconds)}\n'
          '${l10n.projectListUpdatedOn(project.updatedAt)}',
          when: project.updatedAt,
          localeName: l10n.localeName,
          keep: numberUnitParts(
            l10n.homeProjectMeta(project.fps, project.durationSeconds),
          ),
        ),
        onTap: selectedTap,
        onLongPress: selectedLongPress,
        trailing: selecting
            ? null
            : _sharedProjectActions(context, project, onCopyEntry: onCopyEntry),
      ),
    ),
  );
}

/// Received projects remain editable. Sharing one explicitly creates a new
/// saved .niashare snapshot, whereas outbound snapshots reuse existing bytes.
Widget _sharedProjectActions(
  BuildContext context,
  Project project, {
  ValueChanged<HomeClipboardEntry>? onCopyEntry,
  bool showFavorite = true,
  bool showMenu = true,
}) {
  final l10n = AppLocalizations.of(context)!;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (showFavorite)
        CollectionFavoriteButton(
          itemId: project.id,
          favorite: project.isFavorite,
          tooltip: project.isFavorite
              ? l10n.colorPickerFavoriteRemove
              : l10n.colorPickerFavoriteAdd,
          onPressed: () => runProjectAction(
            context,
            () => context.read<ProjectService>().toggleFavorite(project.id),
          ),
        ),
      if (showFavorite && showMenu) const SizedBox(width: 4),
      if (showMenu)
        CollectionActionFrame(
          key: Key('collectionMenu_${project.id}'),
          child: _receivedShareMenu(context, project, onCopyEntry: onCopyEntry),
        ),
    ],
  );
}

Widget _receivedShareMenu(
  BuildContext context,
  Project project, {
  ValueChanged<HomeClipboardEntry>? onCopyEntry,
}) {
  final l10n = AppLocalizations.of(context)!;
  final service = context.read<ProjectService>();
  return PopupMenuButton<String>(
    key: ValueKey('receivedShareMenu_${project.id}'),
    padding: EdgeInsets.zero,
    icon: const Icon(Icons.more_vert, size: CollectionActionFrame.glyphSize),
    tooltip: MaterialLocalizations.of(context).showMenuTooltip,
    onSelected: (action) async {
      switch (action) {
        case 'open':
          context.push('/canvas/${project.id}');
        case 'copyToClipboard':
          onCopyEntry?.call(
            HomeClipboardEntry(
              source: HomePasteArea.received,
              id: project.id,
              name: project.name,
            ),
          );
        case 'rename':
          // 作品の一覧・プロジェクト詳細の名前の変更と同じダイアログ（空白
          // だけの名前は確定させない・確定のボタンは「変更」・入力欄は
          // ダイアログが持って破棄する）。以前は自前のダイアログで、空白だけの
          // 名前は黙って閉じ、入力欄を閉じる動きの途中に破棄していた。
          await showDialog<void>(
            context: context,
            builder: (_) => NameEntryDialog(
              title: l10n.commonRename,
              confirmLabel: l10n.commonChange,
              cancelLabel: l10n.commonCancel,
              initialName: project.name,
              onSubmit: (name) async {
                if (name != project.name) {
                  await service.renameProject(project.id, name);
                }
              },
            ),
          );
        case 'thumbnail':
          if (context.mounted) {
            await showProjectThumbnailDialog(
              context,
              project: project,
              service: service,
            );
          }
        case 'duplicate':
          // 作品のメニューの「複製」と同じく、できた複製の名前を知らせる。
          if (context.mounted) {
            await duplicateProjectWithNotice(
              context,
              service,
              project.id,
              namer: _copyNamer(context),
            );
          }
        case 'share':
          if (context.mounted) {
            await createAndShareProjectNiashare(context, service, project);
          }
        case 'favorite':
          await runProjectAction(
            context,
            () => service.setFavorite(project.id, !project.isFavorite),
          );
        case 'move':
          if (context.mounted) {
            await showModalBottomSheet<void>(
              context: context,
              builder: (_) => WorkFolderMoveSheet(
                folders: service.sharedFolders,
                filename: project.name,
                onMove: (id) => service.moveToSharedFolder(project.id, id),
              ),
            );
          }
        case 'delete':
          if (project.isFavorite) {
            // 前の断りだけを取り下げて出す（続けて押しても積み重ならない）。
            if (context.mounted) {
              showTrashRefusedSnackBar(
                ScaffoldMessenger.of(context),
                l10n.commonFavoriteDeleteBlocked,
              );
            }
            return;
          }
          if (context.mounted) {
            // 移したら作品と同じく知らせ、その場で戻せるようにする。
            final messenger = ScaffoldMessenger.of(context);
            await showDialog<void>(
              context: context,
              builder: (_) => ProjectTrashDialog(
                title: l10n.homeMoveToTrash,
                message: l10n.homeMoveToTrashConfirm(1),
                confirmLabel: l10n.homeMoveToTrash,
                itemNames: [project.name],
                onApply: () async {
                  await service.deleteProject(project.id);
                  showMovedToTrashSnackBar(messenger, l10n, service, [
                    project.id,
                  ]);
                },
              ),
            );
          }
      }
    },
    itemBuilder: (_) => [
      PopupMenuItem(value: 'open', child: Text(l10n.projectListOpenAction)),
      PopupMenuItem(value: 'rename', child: Text(l10n.commonRename)),
      PopupMenuItem(value: 'duplicate', child: Text(l10n.themeDuplicateAction)),
      PopupMenuItem(
        value: 'thumbnail',
        child: Text(l10n.thumbnailChangeAction),
      ),
      PopupMenuItem(
        value: 'share',
        // この作品の共有ファイルの作成・共有が終わるまで、二度目は選べない。
        enabled: !ExportShareService.isRunning(niashareKey(project.id)),
        child: Text(l10n.projectListCreateShareAction),
      ),
      PopupMenuItem(
        value: 'favorite',
        child: Text(
          project.isFavorite
              ? l10n.colorPickerFavoriteRemove
              : l10n.colorPickerFavoriteAdd,
        ),
      ),
      PopupMenuItem(
        value: 'delete',
        // メニューの文字色のまま、印のアイコンと文で知らせる。
        child: MenuActionLabel(
          icon: Icons.delete_outline,
          label: l10n.projectDetailTrashMenuItem,
        ),
      ),
    ],
  );
}

/// A saved .niashare is a frozen file, so its file-specific menu
/// intentionally omits canvas editing and folder operations.
Future<void> _outgoingShareAction(
  BuildContext context,
  SavedOutgoingShare entry,
  String action, {
  _OutgoingShareRenamed? onRenamed,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final service = context.read<ProjectService>();
  final file = File(entry.path);
  try {
    switch (action) {
      case 'share':
        await shareSavedNiashare(context, entry.path);
      case 'rename':
        // 作品・フォルダと同じ名前の入力（空白だけの名前は確定させない・
        // 失敗したら中に理由を出して開いたまま・入力欄はダイアログが持つ）。
        // 以前は空の名前を黙って無視し、同じ名前があると閉じてから後ろに
        // 別の失敗の文を出した。
        await showDialog<void>(
          context: context,
          builder: (_) => NameEntryDialog(
            title: l10n.commonRename,
            confirmLabel: l10n.commonChange,
            cancelLabel: l10n.commonCancel,
            initialName: entry.name,
            failureText: (error) => error is _ShareNameTaken
                ? l10n.homeShareFileNameTaken
                : l10n.homeShareFileRenameFailed,
            onSubmit: (value) async {
              final name = value.replaceAll(RegExp(r'[\\/]'), '_');
              if (name == entry.name) return;
              if (name == '.' || name == '..') {
                throw FileSystemException('Invalid share filename', name);
              }
              final target = File('${file.parent.path}/$name.niashare');
              if (await target.exists()) throw const _ShareNameTaken();
              // お気に入り・コピーしたものも新しい名前のファイルへ移す。
              await service.renameOutgoingShare(entry.path, target.path);
              onRenamed?.call(entry.path, target.path, name);
            },
          ),
        );
      case 'duplicate':
        // 作品・書き出したファイルの複製と同じく、画面の言語の「(コピー)」と
        // 番号を付け（拡張子はそのまま）、できた複製の名前を知らせる。以前は
        // どの言語でも「名前 (1).niashare」だった。
        final messenger = ScaffoldMessenger.of(context);
        final target = await _copyFileDestination(l10n, file);
        await file.copy(target.path);
        await service.refreshOutgoingShares();
        final copyName = target.uri.pathSegments.last;
        showProjectDuplicatedSnackBar(
          messenger,
          l10n,
          copyName.endsWith('.niashare')
              ? copyName.substring(0, copyName.length - '.niashare'.length)
              : copyName,
        );
      case 'delete':
        // 作品・フォルダ・書き出したファイルと同じ確認（名前を出し、移せ
        // なかったときはダイアログの中に理由を出して開いたまま）。以前は
        // 名前の無い別のダイアログで、失敗は後ろの知らせだった。
        // 移したら作品と同じく知らせ、その場で戻せるようにする。
        final messenger = ScaffoldMessenger.of(context);
        final moved = await showDialog<bool>(
          context: context,
          builder: (_) => ProjectTrashDialog(
            title: l10n.homeMoveToTrash,
            message: l10n.homeMoveToTrashConfirm(1),
            confirmLabel: l10n.homeMoveToTrash,
            itemNames: [entry.name],
            onApply: () async {
              final LocalTrashedFile trashed;
              try {
                trashed = await LocalFileTrashService.move(
                  file,
                  LocalTrashKind.outgoingShare,
                );
              } catch (error, stackTrace) {
                AppErrorReporter.record(error, stackTrace);
                rethrow;
              }
              StorageInfoService().invalidate();
              showMovedToTrashSnackBar(
                messenger,
                l10n,
                service,
                const [],
                files: [trashed],
              );
            },
          ),
        );
        if (moved != true) return;
        await service.refreshOutgoingShares();
    }
  } catch (error, stackTrace) {
    AppErrorReporter.record(error, stackTrace);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.homeTrashOperationFailed)));
    }
  }
}

/// 作成した共有ファイルの名前を変えたとき（前の場所・新しい場所・新しい名前）。
typedef _OutgoingShareRenamed =
    void Function(String oldPath, String newPath, String newName);

class _OutgoingSharesList extends StatelessWidget {
  const _OutgoingSharesList({
    required this.header,
    this.screenFocus,
    this.onCopyEntry,
    this.onRenamed,
    required this.viewMode,
    required this.sortMode,
    required this.showFavoritesOnly,
    required this.searchQuery,
    this.onClearSearch,
    this.onShowAll,
  });
  final ValueChanged<HomeClipboardEntry>? onCopyEntry;
  final VoidCallback? onClearSearch;
  final VoidCallback? onShowAll;
  final _OutgoingShareRenamed? onRenamed;
  final ProjectViewMode viewMode;
  final ProjectSortMode sortMode;
  final bool showFavoritesOnly;
  final String searchQuery;

  /// 一覧の先頭に出し、一覧と一緒にスクロールするもの（切り替え・並び順）。
  final Widget header;

  /// ホームの画面のフォーカス（読めなかった知らせが消えたとき、フォーカスを
  /// 戻す先）。
  final FocusNode? screenFocus;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ProjectService>();
    // 作成した共有ファイルの置き場所を読めなかったときは知らせ、「まだ
    // ありません」とは言わない（受け取ったもの・ゴミ箱と同じ）。
    final loadFailed = service.outgoingSharesLoadFailed;
    final top = loadFailed
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              header,
              ProjectsLoadFailureNotice(
                key: const Key('outgoingSharesLoadFailed'),
                message: AppLocalizations.of(
                  context,
                )!.homeOutgoingSharesLoadFailed,
                onRetry: () async {
                  if (service.projectsLoadFailed) {
                    await service.retryLoadProjects();
                  }
                  await service.refreshOutgoingShares();
                },
                screenFocus: screenFocus,
              ),
            ],
          )
        : header;
    final query = foldName(searchQuery).trim();
    final saved = service.outgoingShares
        .where(
          (entry) =>
              (!showFavoritesOnly ||
                  service.isOutgoingShareFavorite(entry.path)) &&
              (query.isEmpty || nameMatches(entry.name, query)),
        )
        .toList();
    final byName = nameComparator<SavedOutgoingShare>((entry) => entry.name);
    saved.sort((a, b) {
      final n = switch (sortMode) {
        ProjectSortMode.nameAsc => byName(a, b),
        ProjectSortMode.nameDesc => byName(b, a),
        ProjectSortMode.updatedAsc => a.updatedAt.compareTo(b.updatedAt),
        ProjectSortMode.updatedDesc => b.updatedAt.compareTo(a.updatedAt),
      };
      return n == 0 ? a.path.compareTo(b.path) : n;
    });
    HomeCollectionSelectionScope.maybeOf(
      context,
    )?.onVisibleIds({for (final entry in saved) 'outgoing_file:${entry.path}'});
    if (saved.isEmpty) {
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: top),
          if (!loadFailed)
            SliverFillRemaining(
              hasScrollBody: false,
              child:
                  _filteredLibraryEmptyState(
                    context,
                    searchQuery: searchQuery,
                    favoritesOnly: showFavoritesOnly,
                    hiddenByFavorites:
                        query.isNotEmpty &&
                        service.outgoingShares.any(
                          (entry) => nameMatches(entry.name, query),
                        ),
                    onClearSearch: onClearSearch,
                    onShowAll: onShowAll,
                  ) ??
                  EmptyStatePlaceholder(
                    icon: Icons.file_present_outlined,
                    title: _shareCollectionEmptyText(context),
                    scrollable: false,
                  ),
            ),
        ],
      );
    }
    Widget card(BuildContext context, SavedOutgoingShare entry, bool grid) {
      final l10n = AppLocalizations.of(context)!;
      final scheme = Theme.of(context).colorScheme;
      final isFavorite = service.isOutgoingShareFavorite(entry.path);
      final selection = HomeCollectionSelectionScope.maybeOf(context);
      final selectionId = 'outgoing_file:${entry.path}';
      final selecting = selection?.active ?? false;
      final onTap = selecting
          ? () => selection!.onToggle(selectionId)
          : () => shareSavedNiashare(context, entry.path);
      final onLongPress = selection == null
          ? null
          : () => selection.onLongPress(selectionId);
      // 作品一覧の行と同じ、その言語の日時と大きさの書き方。
      final subtitle = l10n.homeExportedWorkMetadata(
        entry.updatedAt,
        _homeFileSizeLabel(l10n, entry.sizeBytes),
      );
      final favoriteAction = CollectionFavoriteButton(
        itemId: entry.path,
        favorite: isFavorite,
        tooltip: isFavorite
            ? l10n.colorPickerFavoriteRemove
            : l10n.colorPickerFavoriteAdd,
        onPressed: () => runProjectAction(
          context,
          () => service.toggleOutgoingShareFavorite(entry.path),
        ),
      );
      final menuAction = CollectionActionFrame(
        key: Key('collectionMenu_${entry.path}'),
        child: PopupMenuButton<String>(
          key: ValueKey('outgoingShareMenu_${entry.path}'),
          padding: EdgeInsets.zero,
          icon: const Icon(
            Icons.more_vert,
            size: CollectionActionFrame.glyphSize,
          ),
          onSelected: (action) {
            if (action == 'copyToClipboard') {
              onCopyEntry?.call(
                HomeClipboardEntry(
                  source: HomePasteArea.outgoing,
                  id: entry.path,
                  name: entry.name,
                ),
              );
            } else {
              _outgoingShareAction(
                context,
                entry,
                action,
                onRenamed: onRenamed,
              );
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'share',
              child: Text(l10n.projectDetailShareQuickAction),
            ),
            PopupMenuItem(value: 'rename', child: Text(l10n.commonRename)),
            PopupMenuItem(
              value: 'duplicate',
              child: Text(l10n.themeDuplicateAction),
            ),
            PopupMenuItem(
              value: 'delete',
              child: MenuActionLabel(
                icon: Icons.delete_outline,
                label: l10n.projectDetailTrashMenuItem,
              ),
            ),
          ],
        ),
      );
      final actions = Row(
        mainAxisSize: MainAxisSize.min,
        children: [favoriteAction, const SizedBox(width: 4), menuAction],
      );
      if (grid) {
        return HomeCollectionSelectionSurface(
          selectionId: selectionId,
          child: collectionTileShadow(
            context,
            Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Colors.transparent, width: 2),
              ),
              child: InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(
                            color: scheme.surfaceContainerHighest,
                            child: const Center(
                              child: Icon(
                                Icons.insert_drive_file_outlined,
                                size: 52,
                              ),
                            ),
                          ),
                          if (!selecting)
                            Positioned(top: 4, right: 4, child: menuAction),
                          if (!selecting)
                            Positioned(
                              bottom: 4,
                              left: 4,
                              child: favoriteAction,
                            ),
                        ],
                      ),
                    ),
                    collectionTileCaption(context, entry.name),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      return HomeCollectionSelectionSurface(
        selectionId: selectionId,
        grid: false,
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: scheme.surfaceContainerLow,
          child: ListTile(
            leading: const Icon(Icons.insert_drive_file_outlined, size: 36),
            title: KoreanWordsText(
              entry.name,
              breakAtFileSeparators: true,
              copyMarks: copyMarkParts(entry.name),
              keepJapaneseLineStarts: true,
              style: const TextStyle(
                fontFamily: 'Kuramubon',
                fontFamilyFallback: kHeadingFontFallback,
                height: kWrappedNameLineHeight,
              ),
            ),
            subtitle: Text(subtitle),
            onTap: onTap,
            onLongPress: onLongPress,
            trailing: selecting ? null : actions,
          ),
        ),
      );
    }

    if (viewMode != ProjectViewMode.detail) {
      return CustomScrollView(
        key: ValueKey(('outgoing-niashares', viewMode)),
        slivers: [
          SliverToBoxAdapter(child: top),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 100),
            sliver: SliverGrid.builder(
              gridDelegate: _worksGridDelegate(context, viewMode),
              itemCount: saved.length,
              itemBuilder: (context, i) => card(context, saved[i], true),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      key: const PageStorageKey('outgoing-niashares'),
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: saved.length + 1,
      itemBuilder: (context, i) =>
          i == 0 ? top : card(context, saved[i - 1], false),
    );
  }
}

String _shareCollectionEmptyText(BuildContext context) =>
    AppLocalizations.of(context)!.sharedArchiveEmpty;

/// 当たるものが無いときの「検索をやめる」（プロジェクトのタブと同じ）。
Widget? _clearSearchButton(AppLocalizations l10n, VoidCallback? onPressed) =>
    onPressed == null
    ? null
    : OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.close),
        label: Text(l10n.projectListClearSearch),
      );

/// 作品一覧・共有のタブで、検索・「お気に入り」の絞り込みに当たるものが
/// 無いときの表示（プロジェクトのタブと同じ文と、絞り込みを外すボタン）。
/// 絞り込んでいなければnull（その一覧が空のときの文を出す）。
/// [hiddenByFavorites]は、検索には当たるがお気に入りで隠れているだけのとき。
Widget? _filteredLibraryEmptyState(
  BuildContext context, {
  required String searchQuery,
  required bool favoritesOnly,
  required bool hiddenByFavorites,
  String? searchHint,
  VoidCallback? onClearSearch,
  VoidCallback? onShowAll,
}) {
  final l10n = AppLocalizations.of(context)!;
  final query = searchQuery.trim();
  if (query.isNotEmpty && !(favoritesOnly && hiddenByFavorites)) {
    return EmptyStatePlaceholder(
      icon: Icons.search_off,
      title: l10n.projectListNoMatchTitle(query),
      hint: searchHint,
      scrollable: false,
      action: _clearSearchButton(l10n, onClearSearch),
    );
  }
  if (!favoritesOnly) return null;
  return EmptyStatePlaceholder(
    icon: Icons.star_border,
    title: query.isNotEmpty
        ? l10n.projectListNoFavoriteMatchTitle(query)
        : l10n.projectListNoFavoritesTitle,
    scrollable: false,
    action: onShowAll == null
        ? null
        : OutlinedButton(
            onPressed: onShowAll,
            child: Text(l10n.projectListShowAll),
          ),
  );
}

/// 共有タブのフォルダ内表示（共有タブへのフォルダ新規追加機能）。
class _SharedFolderScreen extends StatefulWidget {
  final String folderId;
  final String folderName;
  final ProjectViewMode viewMode;
  final ValueChanged<ProjectViewMode> onViewModeChanged;

  /// 共有の一覧の並び順（「お気に入りのみ」と同じく、フォルダの中にも
  /// 当てる）。
  final ProjectSortMode sortMode;
  final bool showFavoritesOnly;
  final String searchQuery;
  final ValueChanged<HomeClipboardEntry>? onCopyEntry;

  const _SharedFolderScreen({
    required this.folderId,
    required this.folderName,
    required this.viewMode,
    required this.onViewModeChanged,
    required this.sortMode,
    required this.showFavoritesOnly,
    required this.searchQuery,
    this.onCopyEntry,
  });
  @override
  State<_SharedFolderScreen> createState() => _SharedFolderScreenState();
}

class _SharedFolderScreenState extends State<_SharedFolderScreen> {
  late ProjectViewMode _viewMode;

  @override
  void initState() {
    super.initState();
    _viewMode = widget.viewMode;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final query = foldName(widget.searchQuery).trim();
    final items = _sortProjects(
      context
          .watch<ProjectService>()
          .shared
          .where(
            (p) =>
                p.sharedFolderId == widget.folderId &&
                (!widget.showFavoritesOnly || p.isFavorite) &&
                (query.isEmpty || nameMatches(p.name, query)),
          )
          .toList(),
      widget.sortMode,
    );
    Widget card(BuildContext ctx, int i, bool grid) =>
        _receivedShareProjectTile(
          ctx,
          items[i],
          grid: grid,
          onCopyEntry: widget.onCopyEntry,
        );
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folderName),
        actions: [
          PopupMenuButton<ProjectViewMode>(
            key: const Key('sharedFolderViewModeMenu'),
            icon: const Icon(Icons.view_module),
            tooltip: l10n.homeViewModeTooltip,
            onSelected: (mode) {
              setState(() => _viewMode = mode);
              widget.onViewModeChanged(mode);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: ProjectViewMode.large,
                child: Text(l10n.homeViewModeLarge),
              ),
              PopupMenuItem(
                value: ProjectViewMode.medium,
                child: Text(l10n.homeViewModeMedium),
              ),
              PopupMenuItem(
                value: ProjectViewMode.small,
                child: Text(l10n.homeViewModeSmall),
              ),
              PopupMenuItem(
                value: ProjectViewMode.detail,
                child: Text(l10n.homeViewModeDetail),
              ),
            ],
          ),
        ],
      ),
      body: items.isEmpty
          ? EmptyStatePlaceholder(
              icon: Icons.folder_open_outlined,
              title: l10n.homeSharedFolderEmpty,
            )
          : _viewMode != ProjectViewMode.detail
          ? GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: _worksGridDelegate(context, _viewMode),
              itemCount: items.length,
              itemBuilder: (ctx, i) => card(ctx, i, true),
            )
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (ctx, i) => card(ctx, i, false),
            ),
    );
  }
}

/// フォルダ一覧＋直下アイテム一覧を表示する共通ウィジェット（共有タブ・
/// 作品一覧タブで共用）。フォルダは常にルート直下の1階層のみ（ネスト非対応）。
class _FolderableList<T> extends StatelessWidget {
  final ValueChanged<ProjectFolder>? onCopyFolder;
  final ValueChanged<ProjectFolder>? onToggleFolderFavorite;
  final List<T> allItems;

  /// 絞り込み（お気に入りだけ・検索）の前の全部の項目。フォルダをゴミ箱へ
  /// 移す確認で中身を数え、お気に入りを探すのに使う（絞り込んだ一覧で
  /// 数えると、見えていない中身を数えない）。省けば[allItems]。
  final List<T>? everyItem;
  final List<ProjectFolder> folders;
  final String? Function(T) folderIdOf;
  final void Function(String folderId, String folderName, List<T> itemsInFolder)
  onEnterFolder;
  final Future<void> Function(String id, String name) onRenameFolder;
  final Future<void> Function(String id) onDeleteFolder;
  final Future<void> Function(
    String id, {
    required String mode,
    String? sourceId,
    String? imagePath,
  })?
  onSetFolderThumbnail;
  final Widget Function(BuildContext, T) itemBuilder;
  final Widget Function(BuildContext, T)? gridItemBuilder;
  final ProjectViewMode? viewMode;
  final Widget? emptyState;
  final bool reserveForFloatingActions;

  /// 一覧の先頭（フォルダより上）に出し、一覧と一緒にスクロールするもの。
  final Widget? header;

  const _FolderableList({
    super.key,
    required this.allItems,
    this.everyItem,
    required this.folders,
    required this.folderIdOf,
    required this.onEnterFolder,
    required this.onRenameFolder,
    required this.onDeleteFolder,
    this.onSetFolderThumbnail,
    required this.itemBuilder,
    this.gridItemBuilder,
    this.viewMode,
    this.emptyState,
    this.reserveForFloatingActions = false,
    this.onCopyFolder,
    this.onToggleFolderFavorite,
    this.header,
  });

  @override
  Widget build(BuildContext context) {
    final rootItems = allItems.where((e) => folderIdOf(e) == null).toList();
    // フォルダごとの件数を1回の走査で数える。フォルダの数だけallItemsを
    // whereで舐め直すと、作品数×フォルダ数の走査が毎buildで走っていた。
    final countByFolder = <String, int>{};
    for (final e in allItems) {
      final id = folderIdOf(e);
      if (id != null) countByFolder[id] = (countByFolder[id] ?? 0) + 1;
    }
    final hasHeader = folders.isNotEmpty;
    final lead = header == null ? 0 : 1;
    // 作品の行は表示されるぶんだけ作る。ListView(children:)だと、実際に
    // 描画されるのは画面内の行だけでも、全作品ぶんのカード（サムネイルの
    // Image.fileを含む）のウィジェットが毎buildで作られて捨てられる。
    return LayoutBuilder(
      builder: (context, constraints) {
        // A collection is empty only when it has neither root files
        // nor folders. A folder containing no files is still an entry.
        if (rootItems.isEmpty && !hasHeader && emptyState != null) {
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (header != null) SliverToBoxAdapter(child: header!),
              if (hasHeader) ...[
                SliverToBoxAdapter(child: _folderChips(context, countByFolder)),
                const SliverToBoxAdapter(child: Divider(height: 1)),
              ],
              // 下に浮くボタンの分の余白は、空の表示の中に取る（残りの高さを
              // 埋めるだけで、中身の方が高いときだけスクロールする）。外に
              // 足すと、何も無いのにその分スクロールでき、画面いっぱいに
              // 近いスクロールバーのつまみが出ていた。
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: reserveForFloatingActions
                        ? 88 + MediaQuery.paddingOf(context).bottom
                        : 0,
                  ),
                  child: emptyState!,
                ),
              ),
            ],
          );
        }
        if (gridItemBuilder != null &&
            viewMode != null &&
            viewMode != ProjectViewMode.detail) {
          return CustomScrollView(
            slivers: [
              if (header != null) SliverToBoxAdapter(child: header!),
              SliverPadding(
                padding: const EdgeInsets.all(8),
                sliver: SliverGrid.builder(
                  gridDelegate: _worksGridDelegate(context, viewMode!),
                  itemCount: folders.length + rootItems.length,
                  itemBuilder: (context, index) => index < folders.length
                      ? _folderGridTile(
                          context,
                          folders[index],
                          countByFolder[folders[index].id] ?? 0,
                        )
                      : gridItemBuilder!(
                          context,
                          rootItems[index - folders.length],
                        ),
                ),
              ),
              if (reserveForFloatingActions)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 88 + MediaQuery.paddingOf(context).bottom,
                  ),
                ),
            ],
          );
        }
        return ListView.builder(
          // Leave 48px for the action, 8px inner padding and 4px card margin.
          padding: EdgeInsets.only(
            bottom: reserveForFloatingActions
                ? (constraints.maxHeight - 60).clamp(0.0, 88.0).toDouble() +
                      MediaQuery.paddingOf(context).bottom
                : 0,
          ),
          itemCount: lead + rootItems.length + (hasHeader ? 2 : 0),
          itemBuilder: (context, position) {
            if (position < lead) return header!;
            final index = position - lead;
            if (hasHeader && index == 0) {
              return _folderChips(context, countByFolder);
            }
            if (hasHeader && index == 1) return const Divider(height: 1);
            return itemBuilder(context, rootItems[index - (hasHeader ? 2 : 0)]);
          },
        );
      },
    );
  }

  List<FolderThumbnailChoice> _folderCoverChoices(String folderId) {
    final result = <FolderThumbnailChoice>[];
    for (final entry in allItems) {
      if (folderIdOf(entry) != folderId) continue;
      if (entry is Project) {
        final path = entry.thumbnailPath;
        if (path != null && path.isNotEmpty) {
          result.add(
            FolderThumbnailChoice(
              id: entry.id,
              name: entry.name,
              imagePath: path,
              updatedAt: entry.updatedAt,
            ),
          );
        }
      } else if (entry is File) {
        final file = entry;
        final extension = file.path.split('.').last.toLowerCase();
        // Still images display directly. Exported videos get a cached
        // first-frame poster through FolderCoverMedia on Android.
        if (!const {
          'png',
          'jpg',
          'jpeg',
          'gif',
          'webp',
          'bmp',
          'mp4',
          'mov',
          'webm',
          'mkv',
          'avi',
        }.contains(extension)) {
          continue;
        }
        try {
          result.add(
            FolderThumbnailChoice(
              id: file.path,
              name: file.uri.pathSegments.last,
              imagePath: file.path,
              updatedAt: file.lastModifiedSync(),
            ),
          );
        } on FileSystemException {
          // A file removed outside the app must not crash the folder list.
        }
      }
    }
    return result;
  }

  Widget _folderActions(
    BuildContext context,
    ProjectFolder folder, {
    bool showFavorite = true,
    bool showMenu = true,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showFavorite && onToggleFolderFavorite != null) ...[
          CollectionFavoriteButton(
            itemId: folder.id,
            favorite: folder.isFavorite,
            tooltip: folder.isFavorite
                ? l10n.colorPickerFavoriteRemove
                : l10n.colorPickerFavoriteAdd,
            onPressed: () => onToggleFolderFavorite!(folder),
          ),
          if (showMenu) const SizedBox(width: 4),
        ],
        if (showMenu)
          CollectionActionFrame(
            child: IconButton(
              key: ValueKey('collectionFolderMenu_${folder.id}'),
              // ほかのカードの「⋮」（PopupMenuButton）と同じメニューの文字色。
              icon: Icon(
                Icons.more_vert,
                size: CollectionActionFrame.glyphSize,
                color: Theme.of(context).popupMenuTheme.iconColor,
              ),
              tooltip: AppLocalizations.of(context)!.homeFolderMenuTooltip,
              padding: EdgeInsets.zero,
              onPressed: () => _showFolderMenu(context, folder),
            ),
          ),
      ],
    );
  }

  Widget _folderGridTile(
    BuildContext context,
    ProjectFolder folder,
    int count,
  ) {
    final selection = HomeCollectionSelectionScope.maybeOf(context);
    final selectionId = T == File
        ? 'work_folder:${folder.id}'
        : 'shared_folder:${folder.id}';
    final selecting = selection?.active ?? false;
    return HomeCollectionSelectionSurface(
      selectionId: selectionId,
      onSecondaryClick: (at) => _showFolderMenuAt(context, folder, at),
      child: collectionTileShadow(
        context,
        Card(
          key: ValueKey('collectionFolder_${folder.id}'),
          margin: EdgeInsets.zero,
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Colors.transparent, width: 2),
          ),
          child: InkWell(
            onTap: selecting
                ? () => selection!.onToggle(selectionId)
                : () => onEnterFolder(
                    folder.id,
                    folder.name,
                    allItems.where((e) => folderIdOf(e) == folder.id).toList(),
                  ),
            onLongPress: selection == null
                ? () => _showFolderMenu(context, folder)
                : () => selection.onLongPress(selectionId),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FolderThumbnail(
                        folder: folder,
                        choices: _folderCoverChoices(folder.id),
                      ),
                      if (!selecting)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: _folderActions(
                            context,
                            folder,
                            showFavorite: false,
                          ),
                        ),
                      if (!selecting && onToggleFolderFavorite != null)
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: _folderActions(
                            context,
                            folder,
                            showMenu: false,
                          ),
                        ),
                    ],
                  ),
                ),
                collectionTileCaption(context, folder.name),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Folder entries use the same full-width, roughly 80dp ListTile as files,
  /// rather than small 48dp chips. Their cover is drawn inside the folder.
  Widget _folderChips(BuildContext context, Map<String, int> countByFolder) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        for (final folder in folders)
          HomeCollectionSelectionSurface(
            selectionId: T == File
                ? 'work_folder:${folder.id}'
                : 'shared_folder:${folder.id}',
            grid: false,
            onSecondaryClick: (at) => _showFolderMenuAt(context, folder, at),
            child: Card(
              key: ValueKey('collectionFolder_${folder.id}'),
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: ListTile(
                minVerticalPadding: 8,
                leading: SizedBox(
                  width: 56,
                  height: 56,
                  child: FolderThumbnail(
                    folder: folder,
                    choices: _folderCoverChoices(folder.id),
                  ),
                ),
                title: copyNameText(folder.name, name: folder.name),
                // 作品のフォルダは書き出した作品の数、共有のフォルダは
                // プロジェクトのフォルダと同じ書き方（中は1階層だけ）。
                subtitle: Text(
                  T == File
                      ? l10n.homeWorkFolderContents(
                          countByFolder[folder.id] ?? 0,
                        )
                      : l10n.homeFolderContents(
                          countByFolder[folder.id] ?? 0,
                          0,
                        ),
                ),
                trailing:
                    HomeCollectionSelectionScope.maybeOf(context)?.active ==
                        true
                    ? null
                    : _folderActions(context, folder),
                onTap: () {
                  final selection = HomeCollectionSelectionScope.maybeOf(
                    context,
                  );
                  final id = T == File
                      ? 'work_folder:${folder.id}'
                      : 'shared_folder:${folder.id}';
                  if (selection?.active == true) {
                    selection!.onToggle(id);
                  } else {
                    onEnterFolder(
                      folder.id,
                      folder.name,
                      allItems
                          .where((e) => folderIdOf(e) == folder.id)
                          .toList(),
                    );
                  }
                },
                onLongPress: () {
                  final selection = HomeCollectionSelectionScope.maybeOf(
                    context,
                  );
                  final id = T == File
                      ? 'work_folder:${folder.id}'
                      : 'shared_folder:${folder.id}';
                  if (selection == null) {
                    _showFolderMenu(context, folder);
                  } else {
                    selection.onLongPress(id);
                  }
                },
              ),
            ),
          ),
      ],
    );
  }

  void _showFolderMenu(BuildContext context, ProjectFolder folder) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onSetFolderThumbnail != null)
              ListTile(
                key: const Key('collectionFolderThumbnailMenuItem'),
                leading: const Icon(Icons.image_outlined),
                title: Text(
                  AppLocalizations.of(context)!.thumbnailChangeAction,
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  showFolderThumbnailDialog(
                    context,
                    folder: folder,
                    choices: _folderCoverChoices(folder.id),
                    onSave: ({required mode, sourceId, imagePath}) =>
                        onSetFolderThumbnail!(
                          folder.id,
                          mode: mode,
                          sourceId: sourceId,
                          imagePath: imagePath,
                        ),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.commonRename),
              onTap: () {
                Navigator.pop(ctx);
                showRenameFolderNameDialog(
                  context,
                  folder.name,
                  (name) => onRenameFolder(folder.id, name),
                );
              },
            ),
            // ほかの行と同じ色（メニューの文字色と差し色のアイコン）のまま、
            // 印のアイコンと文で知らせる。
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l10n.homeMoveToTrash),
              onTap: () {
                Navigator.pop(ctx);
                _confirmFolderTrash(context, folder);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 右クリック（マウスの副ボタン）では、︙のシート（[_showFolderMenu]）と
  /// 同じ項目を押した所に出し、選んだ項目はシートと同じダイアログを開く
  /// （シートは画面の下から出るので、上の方の行を右クリックすると押した所から
  /// 離れて出ていた）。プロジェクトのタブのフォルダと同じ出し方。
  Future<void> _showFolderMenuAt(
    BuildContext context,
    ProjectFolder folder,
    Offset globalPosition,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final action =
        await SecondaryClickMenu.showItemsAt<String>(context, globalPosition, [
          if (onSetFolderThumbnail != null)
            PopupMenuItem(
              value: 'thumbnail',
              child: Text(l10n.thumbnailChangeAction),
            ),
          PopupMenuItem(value: 'rename', child: Text(l10n.commonRename)),
          PopupMenuItem(
            value: 'delete',
            child: MenuActionLabel(
              icon: Icons.delete_outline,
              label: l10n.homeMoveToTrash,
            ),
          ),
        ]);
    if (action == null || !context.mounted) return;
    switch (action) {
      case 'thumbnail':
        showFolderThumbnailDialog(
          context,
          folder: folder,
          choices: _folderCoverChoices(folder.id),
          onSave: ({required mode, sourceId, imagePath}) =>
              onSetFolderThumbnail!(
                folder.id,
                mode: mode,
                sourceId: sourceId,
                imagePath: imagePath,
              ),
        );
      case 'rename':
        showRenameFolderNameDialog(
          context,
          folder.name,
          (name) => onRenameFolder(folder.id, name),
        );
      case 'delete':
        _confirmFolderTrash(context, folder);
    }
  }

  /// フォルダをゴミ箱へ移す確認。プロジェクトのフォルダ・作品・書き出した
  /// ファイルと同じ形（名前と中身の数を出し、「ゴミ箱へ移動」は差し色、移せな
  /// かったときは中に理由を出して開いたまま）。以前は名前の無い別の
  /// ダイアログで、ボタンが危険の赤だった。
  void _confirmFolderTrash(BuildContext context, ProjectFolder folder) {
    final l10n = AppLocalizations.of(context)!;
    // 受け取ったもののお気に入りのフォルダ・お気に入りを含むフォルダは
    // 移さない（プロジェクトのフォルダのメニューと同じく、開く前に断る）。
    final inside = [
      for (final item in everyItem ?? allItems)
        if (folderIdOf(item) == folder.id) item,
    ];
    if (T == Project) {
      final holdsFavorite = inside.any((e) => (e as Project).isFavorite);
      if (folder.isFavorite || holdsFavorite) {
        showTrashRefusedSnackBar(
          ScaffoldMessenger.of(context),
          folder.isFavorite
              ? l10n.commonFavoriteDeleteBlocked
              : l10n.homeTrashFolderHoldsFavorite,
        );
        return;
      }
    }
    final count = inside.length;
    final contents = count == 0
        ? ''
        : '\n${l10n.homeMoveToTrashFolderContents(T == File ? l10n.homeWorkFolderContents(count) : l10n.homeFolderContents(count, 0))}';
    showDialog<void>(
      context: context,
      builder: (_) => ProjectTrashDialog(
        title: l10n.homeMoveToTrash,
        message: l10n.homeMoveToTrashConfirm(1) + contents,
        confirmLabel: l10n.homeMoveToTrash,
        itemNames: [folder.name],
        onApply: () => onDeleteFolder(folder.id),
      ),
    );
  }
}

class _TrashTab extends StatefulWidget {
  const _TrashTab({
    super.key,
    required this.sortMode,
    required this.selectedKinds,
    this.searchQuery = '',
    this.onClearSearch,
    this.onShowAllKinds,
    this.onCopyEntry,
    this.screenFocus,
  });

  final ProjectSortMode sortMode;
  final Set<TrashEntryKind> selectedKinds;
  final String searchQuery;

  /// 検索に当たるものが無いときの「検索をやめる」。
  final VoidCallback? onClearSearch;

  /// 種類の絞り込みで隠れているときの「すべて表示」（すべての種類を選ぶ）。
  final VoidCallback? onShowAllKinds;
  final ValueChanged<HomeClipboardEntry>? onCopyEntry;
  final FocusNode? screenFocus;

  @override
  State<_TrashTab> createState() => _TrashTabState();
}

class _TrashTabState extends State<_TrashTab> {
  final _pending = <String>{};
  final _restoring = <String>{};
  late Future<List<LocalTrashedFile>> _localFiles;

  @override
  void initState() {
    super.initState();
    _localFiles = LocalFileTrashService.list();
    LocalFileTrashService.changes.addListener(_reloadLocal);
  }

  @override
  void dispose() {
    LocalFileTrashService.changes.removeListener(_reloadLocal);
    super.dispose();
  }

  void _reloadLocal() {
    if (!mounted) return;
    // setState must return void: assignment of a Future in an expression body
    // returns that Future and throws during every file-Trash notification.
    setState(() {
      _localFiles = LocalFileTrashService.list();
    });
  }

  String _deletedLabel(DateTime? deleted, AppLocalizations l10n) {
    if (deleted == null) return '';
    return l10n.homeTrashDeletedOn(deleted);
  }

  Future<bool> _confirmRestoreFromTrash(String name) async {
    if (!mounted) return false;
    final l10n = AppLocalizations.of(context)!;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            key: const Key('homeTrashRestoreConfirmation'),
            title: Text(l10n.homeRestoreFromTrashTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 韓国語の語は、1行に入れば途中で折らない。
                messageText(l10n.homeRestoreFromTrashQuestion),
                const SizedBox(height: 8),
                copyNameText(l10n.commonBulletItem(name), name: name),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                key: const Key('homeTrashRestoreConfirmButton'),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(l10n.commonRestore),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _restoreProject(String id) async {
    if (_pending.contains(id)) return;
    final service = context.read<ProjectService>();
    final project = service.trash.where((p) => p.id == id).firstOrNull;
    if (project == null ||
        !await _confirmRestoreFromTrash(project.name) ||
        !mounted) {
      return;
    }
    setState(() {
      _pending.add(id);
      _restoring.add(id);
    });
    try {
      await runProjectTrashAction(context, () => service.restoreProject(id));
    } finally {
      if (mounted) {
        setState(() {
          _pending.remove(id);
          _restoring.remove(id);
        });
      }
    }
  }

  Future<void> _restoreLocal(LocalTrashedFile entry) async {
    if (_pending.contains(entry.id) ||
        !await _confirmRestoreFromTrash(entry.fileName) ||
        !mounted) {
      return;
    }
    setState(() => _pending.add(entry.id));
    try {
      if (entry.isFolder) {
        await LocalFileTrashService.restoreWorkFolder(
          entry,
          context.read<WorkFolderService>(),
        );
      } else {
        await LocalFileTrashService.restore(entry);
      }
      // The exported-work list maintains a cached storage listing.
      StorageInfoService().invalidate();
      if (entry.kind == LocalTrashKind.outgoingShare && mounted) {
        await context.read<ProjectService>().refreshOutgoingShares();
      }
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.homeTrashOperationFailed,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _pending.remove(entry.id));
    }
  }

  Future<void> _restoreFolder(String id) async {
    if (_pending.contains(id)) return;
    final service = context.read<ProjectService>();
    final folder = service.trashedFolders
        .where((record) => record.folder.id == id)
        .firstOrNull;
    if (folder == null ||
        !await _confirmRestoreFromTrash(folder.folder.name) ||
        !mounted) {
      return;
    }
    setState(() => _pending.add(id));
    try {
      await runProjectTrashAction(
        context,
        () => service.restoreTrashedFolder(id),
      );
    } finally {
      if (mounted) setState(() => _pending.remove(id));
    }
  }

  Future<void> _permanentDeleteFolder(String id) async {
    if (_pending.contains(id)) return;
    final service = context.read<ProjectService>();
    final record = service.trashedFolders
        .where((item) => item.folder.id == id)
        .firstOrNull;
    if (record == null) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _pending.add(id));
    try {
      await showDialog<bool>(
        context: context,
        builder: (_) => ProjectTrashDialog(
          title: l10n.homePermanentDeleteConfirmTitle,
          message: l10n.homePermanentDeleteConfirmBody,
          // ゴミ箱のカードのボタンと同じ言葉（「完全削除」）。
          confirmLabel: l10n.homePermanentDelete,
          itemNames: [record.folder.name],
          onApply: () => service.permanentDeleteTrashedFolder(id),
        ),
      );
    } finally {
      if (mounted) setState(() => _pending.remove(id));
    }
  }

  Widget _folderRow(TrashedFolder record, AppLocalizations l10n) {
    final id = record.folder.id;
    final projectNames = [
      for (final projectId in record.projectIds)
        ...context
            .read<ProjectService>()
            .trash
            .where((project) => project.id == projectId)
            .map((project) => project.name),
    ];
    // 読めていない作品を含むフォルダは、読めるまで「完全削除」を押せなく
    // する（フォルダの記録だけが消えると、中の作品は読めた後に1件ずつの
    // 行に出る）。「復元」は押せる（読めていない作品は、読めたときに
    // フォルダの中に出る）。中身は、読めた作品の名前だけや「中身なし」では
    // なく、記録にある件数で出し、押せない理由も行の中に出す（一覧の
    // 先頭の知らせは、スクロールすると見えない）。
    final unread = context.read<ProjectService>().trashedFolderHasUnreadWorks(
      record,
    );
    final recorded = l10n.homeFolderContents(
      record.projectIds.length,
      record.subfolders.length,
    );
    // 移したときに読めていなかった作品が、読めたときに入るかもしれない間は、
    // 記録の件数（読めた作品だけ）を出さない（「中身なし」や少ない件数に
    // なった）。読み込めていないことだけを出す。
    final mayGain =
        unread &&
        context.read<ProjectService>().trashedFolderMayGainWorks(record);
    final subtitle = mayGain
        ? l10n.homeProjectsLoadFailed
        : unread
        ? '$recorded\n${l10n.homeProjectsLoadFailed}'
        : projectNames.isNotEmpty
        ? projectNames.join(l10n.commonListSeparator)
        : l10n.homeFolderContents(0, record.subfolders.length);
    // 1行目は作品・ファイルの行と同じく、ゴミ箱へ移した日。種類の名前
    // （「作成したプロジェクト」「受け取った共有ファイル」）は付けない
    // （フォルダを1つの作品・ファイルと言ってしまう。種類は絞り込みの
    // チップで分ける）。
    final heading = _deletedLabel(record.deletedAt, l10n);
    // 中の作品の名前が複製の名前なら、その印（「(コピー 12)」）も途中で
    // 折り返さない。
    final detailKeep = {
      for (final name in projectNames) ...copyMarkParts(name),
    }.toList();
    return _trashCard(
      selectionId: 'trash_folder:$id',
      detailsKey: ValueKey('trashedFolder_$id'),
      leading: const Icon(Icons.folder_delete_outlined, size: 36),
      title: record.folder.name,
      subtitle: heading,
      detail: subtitle,
      detailKeep: detailKeep,
      // 名前を並べないときの2行目は件数（「プロジェクト2件・フォルダ1件」）。
      detailIsCount: unread || projectNames.isEmpty,
      subtitleDate: record.deletedAt,
      actions: [
        if (widget.onCopyEntry != null)
          TextButton(
            key: ValueKey('trashCopyFolder_$id'),
            onPressed: () => widget.onCopyEntry!(
              HomeClipboardEntry(
                source: HomePasteArea.trash,
                id: id,
                name: record.folder.name,
                isFolder: true,
                originalArea: record.isShared
                    ? HomePasteArea.received
                    : HomePasteArea.projects,
              ),
            ),
            child: Text(l10n.commonCopy),
          ),
        TextButton(
          key: ValueKey('trashedFolderRestore_$id'),
          onPressed: _pending.contains(id) ? null : () => _restoreFolder(id),
          child: Text(l10n.commonRestore),
        ),
        TextButton(
          key: ValueKey('trashedFolderDelete_$id'),
          onPressed: unread || _pending.contains(id)
              ? null
              : () => _permanentDeleteFolder(id),
          // 押せない間は、押せないボタンの色で出す（色を付けたままだと
          // 押せるように見える）。
          child: Text(
            l10n.homePermanentDelete,
            // 名前の下に回して2行に折れても、行ごとに右端へそろえる（折れた
            // 文字は段落の幅いっぱいを取り、左に寄って描かれた）。
            textAlign: TextAlign.end,
            textWidthBasis: TextWidthBasis.longestLine,
            style: unread
                ? null
                : TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteLocal(LocalTrashedFile entry) async {
    if (_pending.contains(entry.id)) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _pending.add(entry.id));
    try {
      // 作品・フォルダの完全削除と同じ確認（名前を出し、消せなかったときは
      // 中に理由を出して開いたまま）。以前は名前の無い別のダイアログで、
      // 消せなかったことは後ろの知らせだった。
      await showDialog<bool>(
        context: context,
        builder: (_) => ProjectTrashDialog(
          title: l10n.homePermanentDeleteConfirmTitle,
          message: l10n.homePermanentDeleteConfirmBody,
          // ゴミ箱のカードのボタンと同じ言葉（「完全削除」）。
          confirmLabel: l10n.homePermanentDelete,
          itemNames: [entry.fileName],
          onApply: () async {
            try {
              await LocalFileTrashService.deleteForever(entry);
            } catch (error, stackTrace) {
              AppErrorReporter.record(error, stackTrace);
              rethrow;
            }
            StorageInfoService().invalidate();
          },
        ),
      );
    } finally {
      if (mounted) setState(() => _pending.remove(entry.id));
    }
  }

  Future<void> _confirmPermanentDelete(Project project) async {
    if (_pending.contains(project.id)) return;
    final l10n = AppLocalizations.of(context)!;
    final service = context.read<ProjectService>();
    setState(() => _pending.add(project.id));
    try {
      await showDialog<bool>(
        context: context,
        builder: (_) => ProjectTrashDialog(
          title: l10n.homePermanentDeleteConfirmTitle,
          message: l10n.homePermanentDeleteConfirmBody,
          // ゴミ箱のカードのボタンと同じ言葉（「完全削除」）。
          confirmLabel: l10n.homePermanentDelete,
          itemNames: [project.name],
          onApply: () => service.permanentDelete(project.id),
        ),
      );
    } finally {
      if (mounted) setState(() => _pending.remove(project.id));
    }
  }

  Widget _projectRow(
    Project project,
    TrashEntryKind kind,
    AppLocalizations l10n,
  ) {
    final deleted = context.read<ProjectService>().deletedAtOf(project.id);
    final meta = l10n.homeProjectMeta(project.fps, project.durationSeconds);
    final deletedLabel = _deletedLabel(deleted, l10n);
    final subtitle = [
      _trashKindLabel(context, kind),
      if (deletedLabel.isNotEmpty) deletedLabel,
      meta,
    ].join(' · ');
    final actions = <Widget>[
      if (widget.onCopyEntry != null)
        TextButton(
          key: ValueKey('trashCopyProject_${project.id}'),
          onPressed: () => widget.onCopyEntry!(
            HomeClipboardEntry(
              source: HomePasteArea.trash,
              id: project.id,
              name: project.name,
              originalArea: project.isSharedImport
                  ? HomePasteArea.received
                  : HomePasteArea.projects,
            ),
          ),
          child: Text(l10n.commonCopy),
        ),
      TextButton(
        key: ValueKey('trash-restore-${project.id}'),
        onPressed: _pending.contains(project.id)
            ? null
            : () => _restoreProject(project.id),
        child: Text(
          _restoring.contains(project.id)
              ? l10n.homeTrashWorking
              : l10n.commonRestore,
        ),
      ),
      TextButton(
        key: ValueKey('trash-delete-${project.id}'),
        onPressed: _pending.contains(project.id)
            ? null
            : () => _confirmPermanentDelete(project),
        child: Text(
          l10n.homePermanentDelete,
          // 2行に折れても、行ごとに右端へそろえる（フォルダのカードと同じ）。
          textAlign: TextAlign.end,
          textWidthBasis: TextWidthBasis.longestLine,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    ];
    return _trashCard(
      selectionId: 'trash_project:${project.id}',
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Color(project.backgroundColor),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      title: project.name,
      subtitle: subtitle,
      subtitleDate: deleted,
      actions: actions,
    );
  }

  Widget _fileRow(
    LocalTrashedFile entry,
    TrashEntryKind kind,
    AppLocalizations l10n,
  ) {
    final actions = <Widget>[
      if (widget.onCopyEntry != null)
        TextButton(
          key: ValueKey('trashCopyLocal_${entry.id}'),
          onPressed: () => widget.onCopyEntry!(
            HomeClipboardEntry(
              source: HomePasteArea.trash,
              id: entry.id,
              name: entry.fileName,
              isFolder: entry.isFolder,
              originalArea: entry.kind == LocalTrashKind.outgoingShare
                  ? HomePasteArea.outgoing
                  : HomePasteArea.works,
            ),
          ),
          child: Text(l10n.commonCopy),
        ),
      TextButton(
        key: ValueKey('trash-restore-local-${entry.id}'),
        onPressed: _pending.contains(entry.id)
            ? null
            : () => _restoreLocal(entry),
        child: Text(l10n.commonRestore),
      ),
      TextButton(
        key: ValueKey('trash-delete-local-${entry.id}'),
        onPressed: _pending.contains(entry.id)
            ? null
            : () => _deleteLocal(entry),
        child: Text(
          l10n.homePermanentDelete,
          // 2行に折れても、行ごとに右端へそろえる（フォルダのカードと同じ）。
          textAlign: TextAlign.end,
          textWidthBasis: TextWidthBasis.longestLine,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    ];
    return _trashCard(
      selectionId: 'trash_local:${entry.id}',
      leading: Icon(
        entry.isFolder
            ? Icons.folder_delete_outlined
            : kind == TrashEntryKind.createdShare
            ? Icons.file_present_outlined
            : Icons.video_library_outlined,
        size: 36,
      ),
      title: entry.fileName,
      subtitle: [
        _trashKindLabel(context, kind),
        _deletedLabel(entry.deletedAt, l10n),
      ].join(' · '),
      subtitleDate: entry.deletedAt,
      actions: actions,
    );
  }

  Widget _trashCard({
    required String selectionId,
    required Widget leading,
    required String title,
    required String subtitle,
    required List<Widget> actions,
    String? detail,
    List<String> detailKeep = const [],
    bool detailIsCount = false,
    Key? detailsKey,
    DateTime? subtitleDate,
  }) {
    final selection = HomeCollectionSelectionScope.maybeOf(context);
    final selecting = selection?.active ?? false;
    final details = ListTile(
      key: detailsKey,
      leading: leading,
      // 韓国語の名前・2行目は語の途中で、日付は日付の途中で行を変えない
      // （「삭제 / 됨」「2026. 11. / 14.」と切れた）。日付の中に空白がある
      // （行を変えうる）のは韓国語の書き方だけなので、ほかの言語の2行目は
      // 普通の文のまま。複製の名前の印（「(コピー 2)」）は印の途中で
      // 行を変えない。
      title: KoreanWordsText(
        title,
        // ファイル名は区切りの記号の前で折り返す（「.m / p4」と切らない）。
        breakAtFileSeparators: true,
        copyMarks: copyMarkParts(title),
        keepJapaneseLineStarts: true,
        style: const TextStyle(
          fontFamily: 'Kuramubon',
          fontFamilyFallback: kHeadingFontFallback,
          height: kWrappedNameLineHeight,
        ),
      ),
      // 狭い幅・大きな文字でも、移した日・数と単位（「10秒」）の途中で
      // 折り返さない（「12fps · 10 / 秒」と切れていた）。韓国語の2行目は
      // 語の途中でも折り返さない。
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!containsHangul(subtitle))
            KeepTogetherText(
              subtitle,
              keep: [
                if (subtitleDate != null)
                  DateFormat.yMd(
                    AppLocalizations.of(context)!.localeName,
                  ).format(subtitleDate),
              ],
            )
          else if (subtitleDate == null)
            KoreanWordsText(subtitle)
          else
            DateLineText(
              subtitle,
              when: subtitleDate,
              localeName: AppLocalizations.of(context)!.localeName,
            ),
          // フォルダの中身（作品の名前・件数）は次の行に。中の作品の複製の
          // 名前の印（[detailKeep]）は途中で折り返さない。件数は数と単位の
          // 間で折り返さない（文字2倍のja 360pxで「…フォルダ1 / 件」、en
          // 320pxで「…and 1 / folder」と切れた。韓国語は語ごとにつなぐ）。
          if (detail != null)
            detailIsCount && !containsHangul(detail)
                ? countText(detail)
                : KoreanWordsText(detail, copyMarks: detailKeep),
        ],
      ),
    );
    // カードを押す・長押しする所とマウスを載せた色は、カード全体（ボタンの
    // 行も含む）。名前の行（ListTile）だけに付けていた頃は、ボタンの行の
    // 空いた所に載せても色が付かず、カードの上半分だけが反応した。
    Widget surface(Widget child) => InkWell(
      onTap: selecting ? () => selection!.onToggle(selectionId) : null,
      onLongPress: selection == null
          ? null
          : () => selection.onLongPress(selectionId),
      child: child,
    );
    // ボタンの上の長押し（ゆっくり押す・マウスで押し続ける）は、カードの
    // 長押し（選択）にせず、そのボタンを押したことにする。カードが取ると、
    // ボタンが消えて押した操作も行われなかった。押せないボタンの上では何も
    // しない（ボタンの長押しはカードの長押しより先に受ける）。
    final ownActions = [
      for (final action in actions)
        GestureDetector(
          excludeFromSemantics: true,
          onLongPress: action is ButtonStyleButton
              ? action.onPressed ?? () {}
              : () {},
          child: action,
        ),
    ];
    return HomeCollectionSelectionSurface(
      selectionId: selectionId,
      grid: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScaler = MediaQuery.textScalerOf(context);
          final compact = constraints.maxWidth < 600 * textScaler.scale(1);
          // 名前の右に並べるときに名前の行（ListTile）に残す幅：先頭の絵
          // （48）と余白（16＋16＋24）に、名前の文字15字分。
          final nameFont = Theme.of(context).textTheme.titleMedium?.fontSize;
          final besideMinTile =
              16 + 48 + 16 + 24 + textScaler.scale(nameFont ?? 16) * 15;
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            clipBehavior: Clip.antiAlias,
            child: surface(
              // 広いカードは名前の右・上下の真ん中に、狭いカードは名前の下の
              // 右端に並べる（所有者の判断1。作品・フォルダ・ファイルの
              // カードで同じ）。広いカードでも、右に並べると名前の欄が名前の
              // 文字15字分より狭くなるときは下に回す（600×倍率を少し超えた
              // 幅で、名前が数十pxの欄に押し込まれ「clip_001.m | p4」の
              // ように折れた）。名前の長さでは決めないので、同じ一覧の
              // カードは同じ並べ方になる。
              ActionBesideOrBelow(
                text: details,
                action: selecting
                    ? const SizedBox.shrink()
                    : OverflowBar(
                        // 1行に入らず縦に並ぶときも右端にそろえる。
                        overflowAlignment: OverflowBarAlignment.end,
                        spacing: 8,
                        overflowSpacing: 4,
                        children: ownActions,
                      ),
                gap: 0,
                spacing: 0,
                minTextWidth: compact ? double.infinity : besideMinTile,
                besideActionPadding: selecting
                    ? EdgeInsets.zero
                    : const EdgeInsetsDirectional.only(end: 8),
                belowActionPadding: selecting
                    ? EdgeInsets.zero
                    : const EdgeInsets.fromLTRB(12, 0, 12, 8),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = context.watch<ProjectService>();
    return FutureBuilder<List<LocalTrashedFile>>(
      future: _localFiles,
      builder: (context, snapshot) {
        final rows =
            <
              ({
                TrashEntryKind kind,
                Project? project,
                TrashedFolder? folder,
                LocalTrashedFile? local,
                DateTime deletedAt,
                String name,
              })
            >[];
        for (final project in service.trash) {
          // Folder contents are represented by their parent folder row.
          if (service.trashedFolderOf(project.id) != null) continue;
          final kind = project.isSharedImport
              ? TrashEntryKind.receivedShare
              : TrashEntryKind.createdProject;
          rows.add((
            kind: kind,
            project: project,
            folder: null,
            local: null,
            deletedAt:
                service.deletedAtOf(project.id) ??
                DateTime.fromMillisecondsSinceEpoch(0),
            name: project.name,
          ));
        }
        for (final folder in service.trashedFolders) {
          final kind = folder.isShared
              ? TrashEntryKind.receivedShare
              : TrashEntryKind.createdProject;
          rows.add((
            kind: kind,
            project: null,
            folder: folder,
            local: null,
            deletedAt: folder.deletedAt,
            name: folder.folder.name,
          ));
        }
        for (final local in snapshot.data ?? <LocalTrashedFile>[]) {
          final kind = local.kind == LocalTrashKind.outgoingShare
              ? TrashEntryKind.createdShare
              : TrashEntryKind.exportedWork;
          rows.add((
            kind: kind,
            project: null,
            folder: null,
            local: local,
            deletedAt: local.deletedAt,
            name: local.fileName,
          ));
        }
        final query = foldName(widget.searchQuery).trim();
        if (query.isNotEmpty) {
          rows.removeWhere(
            (row) =>
                !nameMatches(row.name, query) &&
                !nameMatches(_trashKindLabel(context, row.kind), query),
          );
        }
        // 選んでいない種類に、探したもの（探していなければ何か）があるか。
        final hiddenByKinds = rows.any(
          (row) => !widget.selectedKinds.contains(row.kind),
        );
        rows.removeWhere((row) => !widget.selectedKinds.contains(row.kind));
        final byName = nameComparator<String>((name) => name);
        rows.sort(
          (a, b) => switch (widget.sortMode) {
            ProjectSortMode.nameAsc => byName(a.name, b.name),
            ProjectSortMode.nameDesc => byName(b.name, a.name),
            ProjectSortMode.updatedAsc => a.deletedAt.compareTo(b.deletedAt),
            ProjectSortMode.updatedDesc => b.deletedAt.compareTo(a.deletedAt),
          },
        );
        HomeCollectionSelectionScope.maybeOf(context)?.onVisibleIds({
          for (final row in rows)
            if (row.project != null)
              'trash_project:${row.project!.id}'
            else if (row.folder != null)
              'trash_folder:${row.folder!.folder.id}'
            else
              'trash_local:${row.local!.id}',
        });
        // ゴミ箱の作品は保存先から読む。読めなかったときは知らせを先頭に
        // 出し、「ゴミ箱は空です」とは言わない（作品が消えたように見える）。
        final loadFailed = service.projectsLoadFailed;
        final lead = loadFailed ? 1 : 0;
        if (snapshot.connectionState != ConnectionState.done &&
            rows.isEmpty &&
            !loadFailed) {
          return const Center(child: CircularProgressIndicator());
        }
        // 書き出した作品・作成した共有ファイルの控えをまだ読んでいる間は、
        // 読めた行（作品）は出したまま、一覧の先頭に読み込み中の印を出す
        // （控えが多いと数十秒かかり、作品の行だけを全部のように出していた）。
        final loadingFiles =
            snapshot.connectionState != ConnectionState.done &&
            (widget.selectedKinds.contains(TrashEntryKind.createdShare) ||
                widget.selectedKinds.contains(TrashEntryKind.exportedWork));
        if (rows.isEmpty && !loadFailed) {
          // 種類の絞り込み・検索で隠れているだけのときは「ゴミ箱は空です」と
          // 言わず、外すボタンを出す（プロジェクトのタブと同じ）。
          final shownQuery = widget.searchQuery.trim();
          if (hiddenByKinds) {
            return EmptyStatePlaceholder(
              icon: Icons.filter_alt_off,
              title: shownQuery.isEmpty
                  ? l10n.homeTrashNoKindTitle
                  : l10n.homeTrashNoKindMatchTitle(shownQuery),
              action: widget.onShowAllKinds == null
                  ? null
                  : OutlinedButton(
                      onPressed: widget.onShowAllKinds,
                      child: Text(l10n.projectListShowAll),
                    ),
            );
          }
          if (query.isNotEmpty) {
            return EmptyStatePlaceholder(
              icon: Icons.search_off,
              title: l10n.homeTrashNoMatchTitle(shownQuery),
              action: _clearSearchButton(l10n, widget.onClearSearch),
            );
          }
          return EmptyStatePlaceholder(
            icon: Icons.delete_outline,
            title: l10n.homeTrashEmpty,
          );
        }
        final loadingRow = loadingFiles ? 1 : 0;
        return ListView.builder(
          itemCount: lead + loadingRow + rows.length,
          padding: const EdgeInsets.only(bottom: 100),
          itemBuilder: (context, position) {
            if (position < lead) {
              return ProjectsLoadFailureNotice(
                key: const Key('trashProjectsLoadFailed'),
                onRetry: service.retryLoadProjects,
                screenFocus: widget.screenFocus,
              );
            }
            if (position < lead + loadingRow) {
              return _TrashFilesLoading(text: l10n.homeTrashLoadingFiles);
            }
            final row = rows[position - lead - loadingRow];
            if (row.project != null) {
              return _projectRow(row.project!, row.kind, l10n);
            }
            if (row.folder != null) {
              return _folderRow(row.folder!, l10n);
            }
            return _fileRow(row.local!, row.kind, l10n);
          },
        );
      },
    );
  }
}

/// ゴミ箱の一覧の先頭に出す、控え（書き出した作品・作成した共有ファイル）を
/// 読み込み中の印。回る印にはしない：控えの読み込みは数が多いと数十秒かかり、
/// その間ずっと画面を描き直し続ける（読み込みの邪魔をし、「落ち着くまで
/// 待つ」テストも終わらなくなる）。砂時計の印と文で、まだ読んでいることを
/// 伝える。
class _TrashFilesLoading extends StatelessWidget {
  const _TrashFilesLoading({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      key: const Key('trashFilesLoading'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Icon(Icons.hourglass_top, size: 16, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reuse the Projects collection's four sort modes for exported media.
/// The source files are never renamed or modified by a view preference.
List<File> _sortExportedFiles(List<File> files, ProjectSortMode mode) {
  // 更新日時はファイルごとに1回だけ読む。読み直す前の一覧に、ゴミ箱へ
  // 移した直後のファイル・アプリの外で消えたファイルが残っていても止まらない
  // （以前は無いファイルの日時を読んで、作品一覧のタブの組み立てが例外に
  // なった）。読めない（もう無い）ファイルは、書き出したファイルの一覧・
  // フォルダの表紙の候補と同じく一覧に出さない（1970年の日時・-1 Bの、
  // 開けも移せもしないカードが残った）。
  final modified = <String, DateTime>{};
  final sorted = <File>[];
  for (final file in files) {
    try {
      modified[file.path] = file.lastModifiedSync();
      sorted.add(file);
    } on FileSystemException {
      // もう無い（アプリの外で消えた・ゴミ箱へ移した直後）。
    }
  }
  final byName = nameComparator<File>((file) => file.uri.pathSegments.last);
  DateTime modifiedOf(File file) => modified[file.path]!;
  int compare(File a, File b) {
    switch (mode) {
      case ProjectSortMode.nameAsc:
        return byName(a, b);
      case ProjectSortMode.nameDesc:
        return byName(b, a);
      case ProjectSortMode.updatedAsc:
        return modifiedOf(a).compareTo(modifiedOf(b));
      case ProjectSortMode.updatedDesc:
        return modifiedOf(b).compareTo(modifiedOf(a));
    }
  }

  sorted.sort((a, b) {
    final order = compare(a, b);
    return order == 0 ? a.path.compareTo(b.path) : order;
  });
  return sorted;
}

/// Sort the exported-work folders within their folder section as well.
/// WorkFolderService has creation dates (no separate update timestamp).
List<ProjectFolder> _sortWorkFolders(
  List<ProjectFolder> folders,
  ProjectSortMode mode,
) {
  final sorted = List<ProjectFolder>.of(folders);
  final byName = nameComparator<ProjectFolder>((folder) => folder.name);
  sorted.sort((a, b) {
    final order = switch (mode) {
      ProjectSortMode.nameAsc => byName(a, b),
      ProjectSortMode.nameDesc => byName(b, a),
      ProjectSortMode.updatedAsc => a.createdAt.compareTo(b.createdAt),
      ProjectSortMode.updatedDesc => b.createdAt.compareTo(a.createdAt),
    };
    return order == 0 ? a.id.compareTo(b.id) : order;
  });
  return sorted;
}

/// Reuse the exact Projects 16:12 grid and minimum caption allowance.
SliverGridDelegate _worksGridDelegate(
  BuildContext context,
  ProjectViewMode mode,
) {
  final extent = switch (mode) {
    ProjectViewMode.small => 130.0,
    ProjectViewMode.medium => 170.0,
    ProjectViewMode.large => 240.0,
    ProjectViewMode.detail => 240.0,
  };
  return collectionTileGridDelegate(context, extent);
}

class _WorksTab extends StatefulWidget {
  const _WorksTab({
    super.key,
    required this.viewMode,
    required this.onViewModeChanged,
    this.searchQuery = '',
    this.onClearSearch,
    this.onCopyEntry,
  });
  final ProjectViewMode viewMode;
  final ValueChanged<ProjectViewMode> onViewModeChanged;
  final String searchQuery;

  /// 検索に当たるものが無いときの「検索をやめる」（ホームの検索を閉じる）。
  final VoidCallback? onClearSearch;
  final ValueChanged<HomeClipboardEntry>? onCopyEntry;

  @override
  State<_WorksTab> createState() => _WorksTabState();
}

class _WorksTabState extends State<_WorksTab>
    with _RememberedListFilters<_WorksTab> {
  @override
  HomeList get filtersList => HomeList.works;
  @override
  HomeListFilters get filters =>
      HomeListFilters(sort: _sortMode.name, favoritesOnly: _showFavoritesOnly);
  @override
  void restoreFilters(HomeListFilters saved) {
    _sortMode = _savedSortMode(saved.sort);
    _showFavoritesOnly = saved.favoritesOnly;
  }

  static const _favoritePathsKey = 'home.works.favoritePaths.v1';
  final Set<String> _favoritePaths = {};
  bool _showFavoritesOnly = false;
  late Future<List<File>> _future;
  @override
  ProjectSortMode _sortMode = ProjectSortMode.updatedDesc;

  Future<void> _loadFavoritePaths() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_favoritePathsKey) ?? const <String>[];
      if (mounted) {
        setState(() {
          _favoritePaths
            ..clear()
            ..addAll(stored);
        });
      }
    } catch (error) {
      debugPrint('Works favorites could not be loaded: $error');
    }
  }

  Future<void> _toggleFavorite(String path) async {
    setState(() {
      if (!_favoritePaths.add(path)) _favoritePaths.remove(path);
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _favoritePathsKey,
        _favoritePaths.toList()..sort(),
      );
    } catch (error) {
      debugPrint('Works favorites could not be saved: $error');
    }
  }

  @override
  void initState() {
    super.initState();
    _future = ExportEngine.listExportedFiles();
    _loadFavoritePaths();
    LocalFileTrashService.changes.addListener(_onLocalFilesChanged);
  }

  @override
  void dispose() {
    LocalFileTrashService.changes.removeListener(_onLocalFilesChanged);
    super.dispose();
  }

  void _onLocalFilesChanged() {
    if (mounted) _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _future = ExportEngine.listExportedFiles(forceRefresh: true);
    });
    try {
      await _future;
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<List<File>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _WorksLoadFailure(onRetry: _reload);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final query = foldName(widget.searchQuery).trim();
        final files = _sortExportedFiles(
          snapshot.data!
              .where(
                (file) =>
                    (!_showFavoritesOnly ||
                        _favoritePaths.contains(file.path)) &&
                    (query.isEmpty ||
                        nameMatches(file.uri.pathSegments.last, query)),
              )
              .toList(),
          _sortMode,
        );
        final workFolders = context.watch<WorkFolderService>();
        final folders = _sortWorkFolders(
          workFolders.folders
              .where(
                (folder) =>
                    (!_showFavoritesOnly ||
                        folder.isFavorite ||
                        files.any(
                          (f) =>
                              workFolders.folderIdOf(f.uri.pathSegments.last) ==
                              folder.id,
                        )) &&
                    (query.isEmpty ||
                        nameMatches(folder.name, query) ||
                        files.any(
                          (f) =>
                              workFolders.folderIdOf(f.uri.pathSegments.last) ==
                              folder.id,
                        )),
              )
              .toList(),
          _sortMode,
        );
        HomeCollectionSelectionScope.maybeOf(context)?.onVisibleIds({
          for (final folder in folders) 'work_folder:${folder.id}',
          for (final file in files)
            if (workFolders.folderIdOf(file.uri.pathSegments.last) == null)
              'work_file:${file.path}',
        });
        Widget buildWork(BuildContext context, File file, bool grid) =>
            _WorkListItem(
              key: ValueKey(file.path),
              file: file,
              gridTile: grid,
              isFavorite: _favoritePaths.contains(file.path),
              onToggleFavorite: () => _toggleFavorite(file.path),
              onDeleted: _reload,
              onCopy: widget.onCopyEntry == null
                  ? null
                  : () => widget.onCopyEntry!(
                      HomeClipboardEntry(
                        source: HomePasteArea.works,
                        id: file.path,
                        name: file.uri.pathSegments.last,
                      ),
                    ),
            );
        return RefreshIndicator(
          onRefresh: _reload,
          child: _FolderableList<File>(
            key: ValueKey(('works-list', widget.viewMode)),
            header: _HomeCollectionSortHeader(
              leading: ChipFocusRing(
                builder: (context, focusSide) => FilterChip(
                  key: const Key('worksFavoritesOnlyFilter'),
                  side: focusSide,
                  label: Text(
                    l10n.homeFavoritesOnly,
                    style: TextStyle(
                      fontFamily: 'Kuramubon',
                      fontFamilyFallback: kHeadingFontFallback,
                      color: _showFavoritesOnly
                          ? Theme.of(context).colorScheme.onPrimary
                          : null,
                    ),
                  ),
                  selectedColor: Theme.of(context).colorScheme.primary,
                  checkmarkColor: Theme.of(context).colorScheme.onPrimary,
                  selected: _showFavoritesOnly,
                  onSelected: (value) =>
                      setState(() => _showFavoritesOnly = value),
                ),
              ),
              sortByName: _sortByName,
              sortAscending: _sortAscending,
              onSortByNameChanged: _setSortByName,
              onToggleDirection: _toggleSortDirection,
            ),
            viewMode: widget.viewMode,
            gridItemBuilder: (context, file) => buildWork(context, file, true),
            emptyState: files.isEmpty && folders.isEmpty
                ? _filteredLibraryEmptyState(
                        context,
                        searchQuery: widget.searchQuery,
                        favoritesOnly: _showFavoritesOnly,
                        // 検索には当たるが、お気に入りで隠れているだけか。
                        hiddenByFavorites:
                            query.isNotEmpty &&
                            (snapshot.data!.any(
                                  (file) => nameMatches(
                                    file.uri.pathSegments.last,
                                    query,
                                  ),
                                ) ||
                                workFolders.folders.any(
                                  (folder) => nameMatches(folder.name, query),
                                )),
                        searchHint: l10n.projectListNoMatchNameHint,
                        onClearSearch: widget.onClearSearch,
                        onShowAll: () =>
                            setState(() => _showFavoritesOnly = false),
                      ) ??
                      EmptyStatePlaceholder(
                        icon: Icons.video_library_outlined,
                        title: l10n.homeWorksEmpty,
                        hint: l10n.homeWorksEmptyHint,
                        scrollable: false,
                      )
                : null,
            allItems: files,
            everyItem: snapshot.data!,
            folders: folders,
            folderIdOf: (f) =>
                workFolders.folderIdOf(f.path.split(RegExp(r'[\\/]')).last),
            onEnterFolder: (folderId, folderName, itemsInFolder) =>
                Navigator.of(context).push(
                  adMockMaterialPageRoute(
                    builder: (_) => _WorksFolderScreen(
                      folderId: folderId,
                      folderName: folderName,
                      viewMode: widget.viewMode,
                      initialSortMode: _sortMode,
                      onSortModeChanged: _chooseSort,
                      searchQuery: nameMatches(folderName, query)
                          ? ''
                          : widget.searchQuery,
                      favoritesOnly:
                          _showFavoritesOnly &&
                          !workFolders.folders.any(
                            (folder) =>
                                folder.id == folderId && folder.isFavorite,
                          ),
                      favoritePaths: _favoritePaths,
                      onToggleFavorite: _toggleFavorite,
                      onViewModeChanged: widget.onViewModeChanged,
                      onDeleted: _reload,
                      onCopyEntry: widget.onCopyEntry,
                    ),
                  ),
                ),
            onToggleFolderFavorite: (folder) =>
                workFolders.toggleFolderFavorite(folder.id),
            onRenameFolder: (id, name) => workFolders.renameFolder(id, name),
            onDeleteFolder: (id) async {
              final folder = workFolders.folders
                  .where((f) => f.id == id)
                  .firstOrNull;
              if (folder == null) return;
              final messenger = ScaffoldMessenger.of(context);
              final projects = context.read<ProjectService>();
              final l10n = AppLocalizations.of(context)!;
              final exports = await ExportEngine.listExportedFiles(
                forceRefresh: true,
              );
              final members = exports
                  .where(
                    (file) =>
                        workFolders.folderIdOf(file.uri.pathSegments.last) ==
                        id,
                  )
                  .toList();
              final entry = await LocalFileTrashService.moveWorkFolder(
                folderName: folder.name,
                files: members,
              );
              await workFolders.deleteFolder(id);
              StorageInfoService().invalidate();
              // 作品のフォルダと同じく、フォルダの名前で知らせて戻せる。
              showMovedToTrashSnackBar(
                messenger,
                l10n,
                projects,
                const [],
                files: [entry],
                workFolders: workFolders,
              );
            },
            onSetFolderThumbnail: (id, {required mode, sourceId, imagePath}) =>
                workFolders.setFolderThumbnail(
                  id,
                  mode: mode,
                  sourceId: sourceId,
                  imagePath: imagePath,
                ),
            onCopyFolder: widget.onCopyEntry == null
                ? null
                : (folder) => widget.onCopyEntry!(
                    HomeClipboardEntry(
                      source: HomePasteArea.works,
                      id: folder.id,
                      name: folder.name,
                      isFolder: true,
                    ),
                  ),
            reserveForFloatingActions: true,
            itemBuilder: (context, file) => buildWork(context, file, false),
          ),
        );
      },
    );
  }
}

class _WorksLoadFailure extends StatelessWidget {
  const _WorksLoadFailure({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // ほかのタブ（プロジェクト・共有・ゴミ箱）と同じ、一覧の上の知らせと
    // 「再試行」。以前は中央の大きな印と塗りのボタンで、同じ「読めなかった」
    // がタブによって違う見た目だった（韓国語の文も語の途中で折れた）。
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        ProjectsLoadFailureNotice(
          message: l10n.homeWorksLoadFailed,
          onRetry: onRetry,
        ),
      ],
    );
  }
}

/// 作品一覧タブのフォルダ内表示。
class _WorksFolderScreen extends StatefulWidget {
  final String folderId;
  final String folderName;
  final VoidCallback onDeleted;
  final ValueChanged<HomeClipboardEntry>? onCopyEntry;
  final ProjectViewMode viewMode;
  final ProjectSortMode initialSortMode;

  /// フォルダの中で選んだ並び順（作品一覧の並び順にする。プロジェクトの
  /// フォルダと同じく、フォルダの中と外で同じ並び順）。
  final ValueChanged<ProjectSortMode> onSortModeChanged;
  final ValueChanged<ProjectViewMode> onViewModeChanged;
  final String searchQuery;
  final bool favoritesOnly;
  final Set<String> favoritePaths;
  final ValueChanged<String> onToggleFavorite;
  const _WorksFolderScreen({
    required this.folderId,
    required this.folderName,
    required this.viewMode,
    required this.initialSortMode,
    required this.onSortModeChanged,
    required this.searchQuery,
    required this.favoritesOnly,
    required this.favoritePaths,
    required this.onToggleFavorite,
    required this.onViewModeChanged,
    required this.onDeleted,
    this.onCopyEntry,
  });

  @override
  State<_WorksFolderScreen> createState() => _WorksFolderScreenState();
}

class _WorksFolderScreenState extends State<_WorksFolderScreen> {
  late Future<List<File>> _future;
  late ProjectViewMode _viewMode;
  late ProjectSortMode _sortMode;

  @override
  void initState() {
    super.initState();
    _viewMode = widget.viewMode;
    _sortMode = widget.initialSortMode;
    _future = ExportEngine.listExportedFiles();
  }

  bool get _sortByName =>
      _sortMode == ProjectSortMode.nameAsc ||
      _sortMode == ProjectSortMode.nameDesc;
  bool get _sortAscending =>
      _sortMode == ProjectSortMode.nameAsc ||
      _sortMode == ProjectSortMode.updatedAsc;
  void _setSortByName(bool byName) => _chooseSort(
    byName
        ? (_sortAscending ? ProjectSortMode.nameAsc : ProjectSortMode.nameDesc)
        : (_sortAscending
              ? ProjectSortMode.updatedAsc
              : ProjectSortMode.updatedDesc),
  );
  void _toggleSortDirection() => _chooseSort(switch (_sortMode) {
    ProjectSortMode.nameAsc => ProjectSortMode.nameDesc,
    ProjectSortMode.nameDesc => ProjectSortMode.nameAsc,
    ProjectSortMode.updatedAsc => ProjectSortMode.updatedDesc,
    ProjectSortMode.updatedDesc => ProjectSortMode.updatedAsc,
  });

  // 作品一覧の並び順にする（覚えて、戻ったときもその並びで出す）。
  void _chooseSort(ProjectSortMode mode) {
    setState(() => _sortMode = mode);
    widget.onSortModeChanged(mode);
  }

  void _selectViewMode(ProjectViewMode mode) {
    setState(() => _viewMode = mode);
    widget.onViewModeChanged(mode);
  }

  Future<void> _reload() async {
    setState(() {
      _future = ExportEngine.listExportedFiles(forceRefresh: true);
    });
    try {
      await _future;
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
    }
    widget.onDeleted();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final workFolders = context.watch<WorkFolderService>();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folderName),
        actions: [
          PopupMenuButton<ProjectViewMode>(
            key: const Key('worksFolderViewModeMenu'),
            icon: const Icon(Icons.view_module),
            tooltip: l10n.homeViewModeTooltip,
            onSelected: _selectViewMode,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: ProjectViewMode.large,
                child: Text(l10n.homeViewModeLarge),
              ),
              PopupMenuItem(
                value: ProjectViewMode.medium,
                child: Text(l10n.homeViewModeMedium),
              ),
              PopupMenuItem(
                value: ProjectViewMode.small,
                child: Text(l10n.homeViewModeSmall),
              ),
              PopupMenuItem(
                value: ProjectViewMode.detail,
                child: Text(l10n.homeViewModeDetail),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _LibraryListControls(
            sort: SortModeControl(
              sortByName: _sortByName,
              sortAscending: _sortAscending,
              onSortByNameChanged: _setSortByName,
              onToggleDirection: _toggleSortDirection,
            ),
          ),
          Expanded(
            child: FutureBuilder<List<File>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _WorksLoadFailure(onRetry: _reload);
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = _sortExportedFiles(
                  snapshot.data!
                      .where(
                        (f) =>
                            workFolders.folderIdOf(
                                  f.path.split(RegExp(r'[\\/]')).last,
                                ) ==
                                widget.folderId &&
                            (!widget.favoritesOnly ||
                                widget.favoritePaths.contains(f.path)) &&
                            (widget.searchQuery.trim().isEmpty ||
                                nameMatches(
                                  f.uri.pathSegments.last,
                                  foldName(widget.searchQuery).trim(),
                                )),
                      )
                      .toList(),
                  _sortMode,
                );
                if (items.isEmpty) {
                  return EmptyStatePlaceholder(
                    icon: Icons.folder_open_outlined,
                    title: l10n.homeWorkFolderEmpty,
                  );
                }
                Widget item(BuildContext context, int index, bool grid) {
                  final file = items[index];
                  return _WorkListItem(
                    key: ValueKey(file.path),
                    file: file,
                    gridTile: grid,
                    isFavorite: widget.favoritePaths.contains(file.path),
                    onToggleFavorite: () => widget.onToggleFavorite(file.path),
                    onCopy: widget.onCopyEntry == null
                        ? null
                        : () => widget.onCopyEntry!(
                            HomeClipboardEntry(
                              source: HomePasteArea.works,
                              id: file.path,
                              name: file.uri.pathSegments.last,
                            ),
                          ),
                    onDeleted: _reload,
                  );
                }

                if (_viewMode != ProjectViewMode.detail) {
                  return GridView.builder(
                    key: ValueKey(('works-folder-grid', _viewMode)),
                    padding: const EdgeInsets.all(8),
                    gridDelegate: _worksGridDelegate(context, _viewMode),
                    itemCount: items.length,
                    itemBuilder: (context, index) => item(context, index, true),
                  );
                }
                return ListView.builder(
                  key: const ValueKey('works-folder-detail'),
                  itemCount: items.length,
                  itemBuilder: (context, index) => item(context, index, false),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkListItem extends StatefulWidget {
  final File file;
  final VoidCallback onDeleted;
  final VoidCallback? onCopy;
  final bool gridTile;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;
  const _WorkListItem({
    super.key,
    required this.file,
    required this.onDeleted,
    this.onCopy,
    this.gridTile = false,
    this.isFavorite = false,
    this.onToggleFavorite,
  });

  @override
  State<_WorkListItem> createState() => _WorkListItemState();
}

class _WorkListItemState extends State<_WorkListItem> {
  File get file => widget.file;
  bool _sharing = false;
  Object? _shareError;
  Future<Map<String, dynamic>>? _coverSetting;

  @override
  void initState() {
    super.initState();
    _coverSetting = ExportedWorkCoverStore.ensureCached(widget.file);
  }

  @override
  void didUpdateWidget(covariant _WorkListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _coverSetting = ExportedWorkCoverStore.ensureCached(widget.file);
    }
  }

  void _refreshCover() {
    if (mounted) {
      setState(() {
        _coverSetting = ExportedWorkCoverStore.ensureCached(widget.file);
      });
    }
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() {
      _sharing = true;
      _shareError = null;
    });
    try {
      await ExportShareService.share(file, origin: exportShareOrigin(context));
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
      if (mounted) setState(() => _shareError = error);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  bool isOriginalImageFile(File f) => const {
    'png',
    'jpg',
    'jpeg',
    'gif',
    'bmp',
    'webp',
  }.contains(f.path.split('.').last.toLowerCase());

  String get _extension => file.path.split('.').last.toLowerCase();

  IconData get _icon {
    switch (_extension) {
      case 'gif':
        return Icons.gif_box_outlined;
      case 'png':
      case 'jpg':
      case 'jpeg':
        return Icons.image_outlined;
      case 'webm':
        return Icons.movie_filter_outlined;
      default:
        return Icons.movie_outlined;
    }
  }

  String _formatSize(int bytes) =>
      _homeFileSizeLabel(AppLocalizations.of(context)!, bytes);

  @override
  Widget build(BuildContext context) {
    final stat = file.statSync();
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<Map<String, dynamic>>(
      future: _coverSetting,
      builder: (context, cover) {
        final setting = cover.data ?? const <String, dynamic>{};
        final path = setting['imagePath'];
        return ExportedWorkCard(
          gridTile: widget.gridTile,
          selectionId: 'work_file:${file.path}',
          isFavorite: widget.isFavorite,
          onToggleFavorite: widget.onToggleFavorite,
          thumbnailPath: path is String && path.isNotEmpty ? path : null,
          // Avoid decoding the original video twice while its compact cover
          // is generated in the queued cache service.
          originalMediaPath:
              const {
                'mp4',
                'm4v',
                'mov',
                'webm',
                'mkv',
                'avi',
                '3gp',
              }.contains(file.path.split('.').last.toLowerCase())
              ? null
              : file.path,
          thumbnailHidden: setting['mode'] == 'none',
          onChangeThumbnail: () => showExportedWorkThumbnailDialog(
            context,
            file: file,
            onApplied: _refreshCover,
          ),
          name: file.path.split(RegExp(r'[\\/]')).last,
          metadata: l10n.homeExportedWorkMetadata(
            stat.modified,
            _formatSize(stat.size),
          ),
          icon: _icon,
          moveLabel: l10n.folderMoveToTitle,
          shareLabel: l10n.homeShareOpenWith,
          deleteLabel: l10n.homeMoveToTrash,
          onOpen: _sharing ? null : () => _openPreview(context),
          onMove: () => _showMoveToFolderSheet(context),
          onCopy: widget.onCopy,
          onShare: _sharing ? null : _share,
          onDelete: _sharing ? null : () => _confirmDelete(context),
          shareBusy: _sharing,
          shareError: _shareError == null
              ? null
              : exportShareFailureText(l10n, _shareError!),
        );
      },
    );
  }

  void _showMoveToFolderSheet(BuildContext context) {
    final service = context.read<WorkFolderService>();
    final fileName = file.path.split(RegExp(r'[\\/]')).last;
    showModalBottomSheet(
      context: context,
      builder: (_) => WorkFolderMoveSheet(
        filename: fileName,
        folders: service.folders,
        onMove: (folderId) => service.moveFileToFolder(fileName, folderId),
      ),
    );
  }

  void _openPreview(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 720),
        child: _WorkPreview(file: file),
      ),
    );
  }

  /// 作品・フォルダと同じ確認（名前を出し、「ゴミ箱へ移動」は差し色。移せなかった
  /// ときはダイアログの中に理由を出し、開いたまま）。以前は名前が無く、
  /// 「移動」が危険な操作の赤だった。
  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    // 移したら作品と同じく知らせ、その場で戻せるようにする（以前は何も
    // 出なかった）。カードは移すと一覧から消えるので、出し先は先に取る。
    final messenger = ScaffoldMessenger.of(context);
    final projects = context.read<ProjectService>();
    final workFolders = context.read<WorkFolderService>();
    final moved = await showDialog<bool>(
      context: context,
      builder: (_) => ProjectTrashDialog(
        title: l10n.homeMoveToTrash,
        message: l10n.homeMoveToTrashConfirm(1),
        confirmLabel: l10n.homeMoveToTrash,
        itemNames: [file.path.split(RegExp(r'[\\/]')).last],
        onApply: () async {
          final LocalTrashedFile entry;
          try {
            entry = await LocalFileTrashService.move(
              file,
              LocalTrashKind.exportedWork,
            );
          } catch (error, stackTrace) {
            AppErrorReporter.record(error, stackTrace);
            rethrow;
          }
          StorageInfoService().invalidate();
          showMovedToTrashSnackBar(
            messenger,
            l10n,
            projects,
            const [],
            files: [entry],
            workFolders: workFolders,
          );
        },
      ),
    );
    if (moved == true && mounted) widget.onDeleted();
  }
}

/// アプリ内プレビュー：MP4/WebMはVideoPlayerController（timeline_screen.dart
/// で既に実績のある仕組み）、GIF/PNG/JPEGはFlutter標準のImage/FileImage（アニメーション
/// GIFを自動再生する）を用いる。いずれも新規ネイティブ依存なし。
class _WorkPreview extends StatefulWidget {
  final File file;
  const _WorkPreview({required this.file});

  @override
  State<_WorkPreview> createState() => _WorkPreviewState();
}

class _WorkPreviewState extends State<_WorkPreview> {
  VideoPlayerController? _controller;
  bool _isImage = false;
  bool _failed = false;
  bool _sharing = false;
  Object? _shareError;
  FileImage? _imageProvider;
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;
  double? _imageAspectRatio;
  bool _imageDimensionsResolved = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() {
      _sharing = true;
      _shareError = null;
    });
    try {
      await ExportShareService.share(
        widget.file,
        origin: exportShareOrigin(context),
      );
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
      if (mounted) setState(() => _shareError = error);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    final path = widget.file.path.toLowerCase();
    _isImage = ['.gif', '.png', '.jpg', '.jpeg'].any(path.endsWith);
    if (_isImage) {
      _imageProvider = FileImage(widget.file);
    } else {
      _controller = VideoPlayerController.file(widget.file)
        ..initialize()
            .then((_) {
              if (!mounted) return;
              setState(() {});
              _controller?.play();
              _controller?.setLooping(true);
            })
            .catchError((_) {
              if (mounted) setState(() => _failed = true);
            });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isImage || _imageDimensionsResolved || _imageListener != null) return;
    // Share the Image widget's cached stream and release our first-frame clone.
    _imageStream = _imageProvider!.resolve(
      createLocalImageConfiguration(context),
    );
    _imageListener = ImageStreamListener(
      (info, synchronousCall) {
        final ratio = info.image.width / info.image.height;
        info.dispose();
        _imageDimensionsResolved = true;
        _stopImageSizeListener();
        if (!mounted) return;
        if (synchronousCall) {
          _imageAspectRatio = ratio;
        } else {
          setState(() => _imageAspectRatio = ratio);
        }
      },
      onError: (error, stackTrace) {
        _imageDimensionsResolved = true;
        _stopImageSizeListener();
      },
    );
    _imageStream!.addListener(_imageListener!);
  }

  void _stopImageSizeListener() {
    final stream = _imageStream;
    final listener = _imageListener;
    _imageStream = null;
    _imageListener = null;
    if (stream != null && listener != null) stream.removeListener(listener);
  }

  @override
  void dispose() {
    _stopImageSizeListener();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Widget content;
    if (_isImage) {
      content = Image(
        image: _imageProvider!,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Center(
          child: Text(l10n.homePreviewFailed, textAlign: TextAlign.center),
        ),
      );
    } else if (_failed) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.homePreviewFailed, textAlign: TextAlign.center),
        ),
      );
    } else if (_controller != null && _controller!.value.isInitialized) {
      content = Center(
        child: AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: GestureDetector(
            onTap: () => setState(() {
              _controller!.value.isPlaying
                  ? _controller!.pause()
                  : _controller!.play();
            }),
            child: VideoPlayer(_controller!),
          ),
        ),
      );
    } else {
      content = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }
    return ExportedWorkPreviewLayout(
      content: content,
      contentAspectRatio: _isImage
          ? _imageAspectRatio ?? 16 / 9
          : _controller?.value.isInitialized == true
          ? _controller!.value.aspectRatio
          : 16 / 9,
      shareLabel: l10n.homeShareOpenWith,
      closeLabel: l10n.commonClose,
      onShare: _sharing ? null : _share,
      shareBusy: _sharing,
      shareError: _shareError == null
          ? null
          : exportShareFailureText(l10n, _shareError!),
      onClose: () => Navigator.pop(context),
    );
  }
}

enum ProjectViewMode { large, medium, small, detail }

enum ProjectSortMode { nameAsc, nameDesc, updatedAsc, updatedDesc }

// ─── 初回起動ポップアップ ─────────────────────────────────────────────────
// 初回起動時は「手描きアニメーションを制作できます」の
// ポップアップのみを表示する（複数ページのチュートリアルは表示しない）。

class _FirstLaunchDialog extends StatefulWidget {
  final Future<void> Function() onDone;
  const _FirstLaunchDialog({required this.onDone});

  @override
  State<_FirstLaunchDialog> createState() => _FirstLaunchDialogState();
}

class _FirstLaunchDialogState extends State<_FirstLaunchDialog> {
  bool _saving = false;
  bool _failed = false;
  // 開いたらキーボードのEnterで「はじめる」を押せるようにする。
  final _startFocus = FocusNode(debugLabel: 'firstLaunchStart');

  @override
  void dispose() {
    _startFocus.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await widget.onDone();
      if (mounted) Navigator.of(context).pop();
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
        // 保存を待つ間は押せないボタンからフォーカスが外れている。押せる
        // ように戻ってから、Enterでやり直せるようフォーカスを戻す。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _startFocus.requestFocus();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope<Object?>(
      canPop: false,
      child: AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        constraints: const BoxConstraints(minWidth: 280, maxWidth: 560),
        scrollable: true,
        // スクロールした文を案内の角丸の形で切り取る（既定の Clip.none
        // では、文字の大きいときに余白が縮み、四隅の丸みの外に文の端が
        // 出うる）。
        clipBehavior: Clip.antiAlias,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 韓国語は語の途中で折り返さない。描く文にだけ語結合子を入れ、
            // 読み上げには元の文を渡す。
            Text.rich(
              TextSpan(
                text: keepKoreanWordsTogether(l10n.homeFirstLaunchMessage),
                semanticsLabel: l10n.homeFirstLaunchMessage,
              ),
            ),
            if (_saving) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_failed) ...[
              const SizedBox(height: 12),
              // 色ではなく先頭の印と文で知らせ、読み上げへも伝える
              // （文字の色はダイアログの文字色）。韓国語は語の途中で
              // 折り返さない（押すボタンの名前が2行に割れないように）。
              // 日本語・中国語も、押すボタンの名前は引用符ごと1行に保つ。
              ExportShareNotice(
                message: keepKoreanWordsTogether(
                  keepPhraseTogether(
                    l10n.homeFirstLaunchSaveFailed,
                    l10n.homeFirstLaunchStart,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          // 「はじめる」ボタンの文字はくらむぼんを明示指定する
          // （通常のボタン文字は白光明朝のため、ここだけ差し替える）。
          FilledButton(
            focusNode: _startFocus,
            autofocus: true,
            onPressed: _saving ? null : _complete,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: Text(
              l10n.homeFirstLaunchStart,
              style: const TextStyle(
                fontFamily: 'Kuramubon',
                fontFamilyFallback: kHeadingFontFallback,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
