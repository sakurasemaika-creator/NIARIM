import 'package:niarim/services/theme_service.dart';

import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../../../config/signal_colors.dart';
import '../../../engine/autofill_batch_runner.dart';
import '../../../engine/autofill_engine.dart' as autofill;
import '../../../engine/layer_keyframe_engine.dart';
import '../../../engine/tile_manager.dart' show frameLayerKey;
import '../../../engine/undo_manager.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/fit_or_hide_title.dart';
import '../../../widgets/menu_surface.dart';
import '../../../l10n/autofill_names.dart';
import '../../../l10n/creative_preset_labels.dart';
import '../../../models/layer.dart' as model;
import '../../../models/layer_keyframe.dart';
import '../../../services/autofill_preset_service.dart';
import '../../../services/frame_thumbnail_renderer.dart';
import '../../../services/project_service.dart';
import '../../../services/layer_clipboard_service.dart';
import '../../../services/tone_service.dart';
import '../../../widgets/first_that_fits.dart';
import '../../../widgets/blend_mode_preview.dart';
import '../../../widgets/confirm_delete.dart';
import '../../../widgets/keep_together_text.dart';
import '../../../widgets/autofill_preset_selection_sheet.dart';
import '../../../widgets/dispose_on_unmount.dart';
import '../../../widgets/name_entry_dialog.dart';
import '../../../widgets/first_use_tooltip.dart';
import '../../../widgets/labeled_slider.dart';
import '../../../widgets/layer_range_dialog.dart';
import '../../../widgets/list_ink_clip.dart';
import '../../../widgets/scrollable_sheet_body.dart';
import 'layer_keyframe_sheet.dart';
import '../../../services/layer_thumbnail_renderer.dart';
import 'panel_close_bar.dart';
import 'two_finger_vertical_swipe_detector.dart';
import '../../../config/font_fallback.dart';
import '../../../utils/blend_mode_label.dart';
import '../../../utils/duplicate_name.dart';
import '../../../config/accent_text_theme.dart';
import '../../../widgets/typing_dialog_inset.dart';

class LayerPanel extends StatefulWidget {
  final VoidCallback onClose;
  final String projectId;
  final String sceneId;
  final int frameIndex;
  // PC/DeXモードの常時ドッキング表示時はtrue。閉じるボタンを非表示にする。
  final bool dockedMode;
  // テキストレイヤーをタップした時の編集入口（既存テキストを
  // タップすると編集開始）。nullの場合はテキストレイヤーも通常選択のみ行う。
  final void Function(model.Layer layer)? onEditTextLayer;
  // 実際にペンストロークが書き込まれる対象レイヤーのID
  // （canvas_screen.dartの`_currentLayerId`）。パネル初回表示時、この
  // レイヤーの行を選択状態としてハイライトする。
  final String? currentLayerId;
  // レイヤー行をタップして選択を切り替えたときに呼ばれる（フォルダ行を
  // 除く）。呼び出し元でこの値を`_currentLayerId`へ反映することで、
  // 以降のペンストロークが選択したレイヤーへ書き込まれるようにする。
  final void Function(String layerId)? onLayerSelected;
  // ショートカット（Ctrl+A）からレイヤー全選択を起動するためのトークン。
  // 値が変化するたびに全選択を実行する（メッシュ変形の確定/キャンセル
  // トークンと同じ「値の変化そのものをイベントとして使う」方式）。
  final int selectAllToken;
  final Uint8List? selectionMask;

  const LayerPanel({
    super.key,
    required this.onClose,
    required this.projectId,
    required this.sceneId,
    required this.frameIndex,
    this.dockedMode = false,
    this.onEditTextLayer,
    this.currentLayerId,
    this.onLayerSelected,
    this.selectAllToken = 0,
    this.selectionMask,
  });

  @override
  State<LayerPanel> createState() => _LayerPanelState();
}

class _LayerPanelState extends State<LayerPanel> {
  /// レイヤーパネル上部のショートカットボタン用スタイル。
  /// 既定の`TextButton`は最小高さ40dp・タップ判定48dpを確保するため、
  /// この段だけでレイヤー1行ぶん近い高さを取ってしまう。中身
  /// （アイコン14px＋11ptラベル）の実寸まで詰めて段を半分にする。
  static final ButtonStyle _shortcutButtonStyle = TextButton.styleFrom(
    minimumSize: Size.zero,
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  /// レイヤーパネル上部のショートカットボタン（新規レイヤー・新規フォルダ・
  /// 追加・画像読込）の段。
  ///
  /// 名前が全部1行に入る幅では、アイコンと名前のボタンを並べる。1つでも
  /// 入らない幅（狭いドック・大きな文字・名前の長い言語）では、どのボタンも
  /// アイコンだけにする（名前は長押し・ホバーの吹き出しと読み上げ。所有者の
  /// 判断3）。以前は4つをExpandedで等分して名前を1行で「…」と切っていて、
  /// 簡体字のドック200pxでは「新…」「导…」と1字しか読めなかった。文字は
  /// 縮めない・省略記号で切らない（`test/layer_panel_action_row_test.dart`・
  /// `test/canvas_pc_dock_labels_fit_test.dart`）。
  Widget _shortcutRow(
    List<({IconData icon, String label, VoidCallback onPressed})> items,
  ) {
    Widget button(
      ({IconData icon, String label, VoidCallback onPressed}) item, {
      required bool labelled,
    }) => Tooltip(
      message: item.label,
      // 名前つきのボタンは名前を読み上げる（吹き出しの文を重ねて読まない）。
      excludeFromSemantics: labelled,
      child: TextButton(
        // 追加の操作は中立の色（差し色は選んでいるレイヤーと主な操作のため）。
        style: (labelled ? _shortcutButtonStyle : _shortcutIconButtonStyle)
            .copyWith(
              foregroundColor: WidgetStatePropertyAll(
                Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        onPressed: item.onPressed,
        child: labelled
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, size: 13),
                  const SizedBox(width: 3),
                  Text(
                    item.label,
                    style: const TextStyle(fontSize: 10),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ],
              )
            : Icon(item.icon, size: 16),
      ),
    );
    return FirstThatFits(
      children: [
        for (final labelled in [true, false])
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final item in items) button(item, labelled: labelled),
            ],
          ),
      ],
    );
  }

  /// アイコンだけのショートカットボタン（押せる所を名前つきより少し広く）。
  static final ButtonStyle _shortcutIconButtonStyle = TextButton.styleFrom(
    minimumSize: Size.zero,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  int _selectedIndex = 0;
  String? _selectedFolderId;
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  model.LayerType? _selectionBaseType;
  bool _showSearch = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  // レイヤーサムネイル更新用（サムネイルはペンを離した瞬間に
  // 現在レイヤーのみ更新する。全レイヤー一括更新はしない）。
  // UndoManagerはストローク確定（push）・Undo・Redoのたびに必ず
  // notifyListeners()するため、これを「ペンが離れた（＝描画内容が変わり
  // 得た）」タイミングの検知に利用する。undoCountの値そのものは増減する
  // （Undo時は減る）が、値が変化したこと自体が「内容が変わった」ことの
  // 十分条件になる。
  int _lastUndoCount = -1;
  final Map<String, int> _thumbRevision = {};

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(LayerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.projectId != oldWidget.projectId ||
        widget.sceneId != oldWidget.sceneId ||
        widget.frameIndex != oldWidget.frameIndex) {
      _selectedFolderId = null;
      _selectedIndex = 0;
      _isSelectionMode = false;
      _selectedIds.clear();
      _selectionBaseType = null;
    }
    if (widget.selectAllToken != oldWidget.selectAllToken) {
      final allLayers = context.read<ProjectService>().layersOf(
        widget.projectId,
        widget.sceneId,
        widget.frameIndex,
      );
      final layers = _visibleLayers(allLayers);
      setState(() {
        _isSelectionMode = true;
        _selectionBaseType = null;
        _selectedIds
          ..clear()
          ..addAll(layers.map((l) => l.id));
      });
    }
  }

  List<model.Layer> _visibleLayers(List<model.Layer> layers) {
    // 選択レイヤー（LayerType.selection）は以前は「内部専用・パネル非表示」
    // だったが、眼鏡断層フィルター等のマスク編集用にユーザーへ常設表示・
    // 通常のレイヤーと同様に操作できるようにする方針へ変更したため、
    // ここでの除外はしない（通常合成からの除外はlayer_compositor.dartの
    // pixelLayerTypes側で引き続き行う）。
    final base = layers.toList();
    final visible = base
        .where((l) => !_isHiddenByCollapsedFolder(l, base))
        .toList();
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return visible;
    // 検索中は名前が一致するレイヤーと、その祖先フォルダ（階層表示を保つため）のみ表示する。
    final byId = {for (final l in base) l.id: l};
    bool isAncestorOfMatch(model.Layer folder) {
      return base.any((l) {
        if (!l.name.toLowerCase().contains(query)) return false;
        String? pid = l.parentFolderId;
        final visited = <String>{};
        while (pid != null && visited.add(pid)) {
          if (pid == folder.id) return true;
          pid = byId[pid]?.parentFolderId;
        }
        return false;
      });
    }

    return visible
        .where(
          (l) => l.name.toLowerCase().contains(query) || isAncestorOfMatch(l),
        )
        .toList();
  }

  /// フォルダの折りたたみ状態に基づき、祖先フォルダが折りたたまれている場合はtrue
  bool _isHiddenByCollapsedFolder(model.Layer layer, List<model.Layer> all) {
    final byId = {for (final l in all) l.id: l};
    String? pid = layer.parentFolderId;
    final visited = <String>{};
    while (pid != null && visited.add(pid)) {
      final parent = byId[pid];
      if (parent == null) break;
      if (!context.read<ProjectService>().isLayerFolderExpanded(
        widget.projectId,
        parent,
      )) {
        return true;
      }
      pid = parent.parentFolderId;
    }
    return false;
  }

  int _depthOf(model.Layer layer, List<model.Layer> all) {
    final byId = {for (final l in all) l.id: l};
    int depth = 0;
    String? pid = layer.parentFolderId;
    final visited = <String>{};
    while (pid != null && visited.add(pid)) {
      depth++;
      final parent = byId[pid];
      pid = parent?.parentFolderId;
    }
    return depth;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final projectService = context.watch<ProjectService>();
    final allLayers = projectService.layersOf(
      widget.projectId,
      widget.sceneId,
      widget.frameIndex,
    );
    final layers = _visibleLayers(allLayers);
    final canvasBackground =
        projectService.projects
            .where((project) => project.id == widget.projectId)
            .firstOrNull
            ?.backgroundColor ??
        0xFFFFFFFF;

    // The row and the canvas use the same layer ID, even after a reorder.
    if (widget.currentLayerId != null) {
      _selectedIndex = layers.indexWhere(
        (layer) => layer.id == widget.currentLayerId,
      );
    }

    // ストロークが確定した（＝ペンが離れた）タイミングを検知し、現在
    // 選択中のレイヤーのサムネイルだけを再生成対象とする。
    final undoCount = context.watch<UndoManager>().undoCount;
    if (_lastUndoCount != undoCount) {
      _lastUndoCount = undoCount;
      if (_selectedIndex >= 0 && _selectedIndex < layers.length) {
        final id = layers[_selectedIndex].id;
        _thumbRevision[id] = (_thumbRevision[id] ?? 0) + 1;
      }
    }

    final header = <Widget>[
      // ヘッダー：題・一括結合・ヘルプ・検索と、閉じる×を1行に置く（以前は
      // ×だけの行が題の上にあり、一覧が1行ぶん下がっていた。他の浮かぶ
      // パネルと同じ並び）。×の押せる所はパネルの右端まで。
      Container(
        padding: EdgeInsetsDirectional.fromSTEB(
          8,
          4,
          widget.dockedMode ? 8 : 0,
          4,
        ),
        child: Row(
          children: [
            // ドックを狭めたとき（下限200）でも右のボタンを押せるよう、
            // 見出しの方を省略する。
            // 入らない幅（大きな文字）では題を出さない（「レイ…」と切らない。
            // 画面名と同じ決まり）。
            if (!widget.dockedMode)
              Expanded(
                child: DefaultTextStyle.merge(
                  style: localizedHeadingStyle(
                    context,
                    const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  child: FitOrHideTitle(l10n.layerPanelTitle),
                ),
              ),
            // 表示中の全レイヤーをワンタップで結合する（複数選択モードを
            // 使わずに済む一括操作の一つ）。
            IconButton(
              icon: const Icon(Icons.merge_type, size: 18),
              onPressed: () => _mergeAllVisibleLayers(context, layers),
              tooltip: l10n.layerPanelMergeAllVisibleTooltip,
            ),
            IconButton(
              icon: const Icon(Icons.help_outline, size: 18),
              onPressed: () => _showHelp(context),
              tooltip: l10n.layerPanelHelpTooltip,
            ),
            IconButton(
              icon: Icon(
                _showSearch ? Icons.search_off : Icons.search,
                size: 18,
              ),
              onPressed: () {
                setState(() {
                  _showSearch = !_showSearch;
                  if (!_showSearch) {
                    _searchQuery = '';
                    _searchController.clear();
                  }
                });
                if (_showSearch) {
                  // The toolbar can move into the scroll view when the field
                  // opens. Focus the field once it is attached there.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _showSearch) _searchFocus.requestFocus();
                  });
                }
              },
              tooltip: l10n.creativePanelSearchTooltip,
            ),
            if (!widget.dockedMode)
              PanelCenterCloseBar(onClose: widget.onClose),
          ],
        ),
      ),
      if (_showSearch)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              hintText: l10n.layerPanelSearchHint,
              prefixIcon: const Icon(Icons.search, size: 16),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
      // 選択モードバー
      if (_isSelectionMode)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                onPressed: () => setState(() {
                  final base = _selectionBaseType;
                  if (base == null) return;
                  _selectedIds.addAll(
                    layers.where((l) => l.type == base).map((l) => l.id),
                  );
                }),
                child: Text(
                  l10n.layerPanelSelectAll,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _selectedIds.clear();
                  _isSelectionMode = false;
                  _selectionBaseType = null;
                }),
                child: Text(
                  l10n.layerPanelDeselectAll,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              Text(
                l10n.homeSelectionCount(_selectedIds.length),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      const Divider(height: 1),
      // 上部ショートカットボタン。
      // `TextButton.icon`は既定で高さ40dp・タップ判定48dpを確保し、
      // さらにアイコンとラベルの間に8dpの固定の隙間を入れる。4つ並べる
      // だけで段が約48dp（レイヤー1行ぶんに近い高さ）を占めるうえ、
      // パネル幅（約250dp）を4等分した約58dpからその隙間が引かれ、
      // 日本語ラベルが2文字も出ない。実寸に合わせて詰めた自前の
      // Rowにして、段の高さをおおよそ半分にしている。
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: _shortcutRow([
          (
            icon: Icons.add,
            label: l10n.layerPanelNewLayerButton,
            onPressed: () => _addLayer(
              context,
              model.LayerType.normal,
              (n) => l10n.layerPanelDefaultLayerName(n),
            ),
          ),
          (
            icon: Icons.folder,
            label: l10n.layerPanelNewFolderButton,
            onPressed: () => _addLayer(
              context,
              model.LayerType.folder,
              (n) => l10n.layerPanelDefaultFolderName(n),
            ),
          ),
          // 共通レイヤー・自動塗り線画・自動塗りレイヤー等の
          // その他種別を選ぶメニュー。新規レイヤーボタンとアイコンが
          // 被らないようlibrary_addを使用。
          (
            icon: Icons.library_add,
            label: l10n.layerPanelAddTooltip,
            onPressed: () => _showAddLayerMenu(context),
          ),
          (
            icon: Icons.photo,
            label: l10n.layerPanelImportImageButton,
            onPressed: () => _importImage(context),
          ),
        ]),
      ),
      const Divider(height: 1),
    ];
    final footer = <Widget>[
      // パネル下部の三点メニュー・ゴミ箱は各レイヤー右側へ移動したため削除した。
      // 「追加」ボタンも上部ショートカット行へ移動済み。削除・結合は
      // 各レイヤー行のボタンとヘッダーの「全レイヤー結合」ボタンへ
      // ワンタップ化したため、複数選択モードはグループ化専用として残す
      // （グループ化は性質上、複数レイヤーの選択が必要なため）。
      if (_isSelectionMode) ...[
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility, size: 18),
                onPressed: _selectedIds.isEmpty
                    ? null
                    : () => _setVisibilityForSelected(context, layers, true),
                tooltip: l10n.layerPanelShowSelectedTooltip,
              ),
              IconButton(
                icon: const Icon(Icons.visibility_off, size: 18),
                onPressed: _selectedIds.isEmpty
                    ? null
                    : () => _setVisibilityForSelected(context, layers, false),
                tooltip: l10n.layerPanelHideSelectedTooltip,
              ),
              IconButton(
                icon: const Icon(Icons.workspaces_outline, size: 18),
                onPressed: _selectedIds.length >= 2
                    ? () => _showCreateGroupDialog(context)
                    : null,
                tooltip: l10n.layerPanelGroupTooltip,
              ),
            ],
          ),
        ),
      ],
    ];

    // Container(color:)はColoredBoxとして描画されるため、内部のListTile
    // （選択中ハイライト・タップ時のインクスプラッシュ）が隠れてしまう
    // （「ListTile background color or ink splashes may be invisible」）。
    // Materialに替えることで、背景色を保ちつつ内部のリップル効果も
    // 正しく表示されるようにする。
    // 面の色は他のパネルとそろえる：ドックでは窓の面（colorScheme.surface、
    // PanelSurfaceのドックと同じ）、スマホの横のシートでは浮かぶパネルの
    // カードと同じメニューの背景色（以前はこのパネルだけ灰色の
    // surfaceContainerHighで、隣の窓・パネルと別の面に見えた）。中の文字は
    // ダイアログ・シートと同じメニューの面のテーマで描く。
    final theme = Theme.of(context);
    final surfaceColor = widget.dockedMode
        ? theme.colorScheme.surface
        : theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow;
    final panel = Material(
      color: surfaceColor,
      child: LayoutBuilder(
        builder: (context, limits) {
          // Short docks need the same scrollable area for the layer rows and
          // their controls. On a taller panel the controls can stay visible.
          final controlsHeight =
              (widget.dockedMode ? 150.0 : 190.0) +
              (_isSelectionMode ? 160.0 : 0) +
              (_showSearch ? 72.0 : 0);
          final scrollControls = limits.maxHeight < controlsHeight;
          return Column(
            children: [
              if (!scrollControls) ...header,
              // 選んだ行の背景を一覧の外（上のボタン）へはみ出させない
              // （末尾のclipListInk）。
              Expanded(
                child: ReorderableListView.builder(
                  // 選んだ行の塗りがパネルの端に接しないよう左右を少し空ける
                  // （ブラシ・トーン・スタンプの一覧と同じく、塗りの角が
                  // 面の中に収まる）。
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  header: scrollControls ? Column(children: header) : null,
                  footer: scrollControls && footer.isNotEmpty
                      ? Column(children: footer)
                      : null,
                  // 標準の自動ドラッグハンドル（PC/DeXモードなどマウス操作環境で
                  // 自動的に行の末尾へ付与される）は、ゴミ箱アイコンなど自前の
                  // 末尾アイコン群と重なって表示されてしまっていたため無効化し、
                  // 代わりに専用のハンドルアイコンを一番右に明示的に配置する。
                  buildDefaultDragHandles: false,
                  itemCount: layers.length,
                  onReorderItem: (oldIdx, newIdx) {
                    if (_searchQuery.trim().isNotEmpty) {
                      return; // 検索中はフィルタ表示のため並び替え不可
                    }
                    if (oldIdx == newIdx) return;
                    final source = layers[oldIdx];
                    final byId = {
                      for (final layer in allLayers) layer.id: layer,
                    };
                    final visited = <String>{};
                    model.Layer? target = layers[newIdx];
                    while (target != null &&
                        target.parentFolderId != source.parentFolderId &&
                        visited.add(target.id)) {
                      target = byId[target.parentFolderId];
                    }
                    if (target == null) return;
                    projectService.reorderLayerRelative(
                      projectId: widget.projectId,
                      sceneId: widget.sceneId,
                      frameIndex: widget.frameIndex,
                      layerId: source.id,
                      siblingId: target.id,
                      after: newIdx > oldIdx,
                    );
                  },
                  itemBuilder: (context, index) {
                    final layer = layers[index];
                    // The selected background identifies the drawing layer.
                    // A folder chosen for adding children has its own accent.
                    final isSelected = widget.currentLayerId == null
                        ? index == _selectedIndex
                        : layer.id == widget.currentLayerId;
                    final isChecked = _selectedIds.contains(layer.id);
                    final depth = _depthOf(layer, layers);
                    return TwoFingerVerticalSwipeDetector(
                      key: ValueKey(layer.id),
                      onSwipeUp: () => _copyLayerWithGesture(context, layer),
                      onSwipeDown: () =>
                          _pasteLayerBeforeWithGesture(context, layer),
                      child: ListTile(
                        key: ValueKey(layer.id),
                        selected: isSelected,
                        dense: true,
                        // レイヤーパネルは幅が約250dpしか無い。ListTileの既定
                        // （左右24dpずつの余白＋タイトル前16dpの隙間）のままだと、
                        // leading（目・種別・サムネイル）とtrailing（更新マーク・
                        // 三点・結合・ゴミ箱・ドラッグハンドル）に挟まれた
                        // レイヤー名の領域が30dpほどしか残らず、名前がほぼ
                        // 省略記号だけになってしまう。余白を詰めて名前へ回す。
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 6,
                        ),
                        horizontalTitleGap: 6,
                        minLeadingWidth: 0,
                        minVerticalPadding: 0,
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (depth > 0)
                              SizedBox(width: depth.clamp(0, 4) * 12.0),
                            if (layer.type == model.LayerType.folder)
                              Tooltip(
                                message: l10n.layerPanelToggleFolderTooltip,
                                child: GestureDetector(
                                  onTap: () {
                                    final projects = context
                                        .read<ProjectService>();
                                    projects.setLayerFolderExpanded(
                                      widget.projectId,
                                      layer,
                                      !projects.isLayerFolderExpanded(
                                        widget.projectId,
                                        layer,
                                      ),
                                    );
                                    setState(() {});
                                  },
                                  child: Icon(
                                    context
                                            .read<ProjectService>()
                                            .isLayerFolderExpanded(
                                              widget.projectId,
                                              layer,
                                            )
                                        ? Icons.expand_more
                                        : Icons.chevron_right,
                                    color: layer.id == _selectedFolderId
                                        ? AccentTextTheme.of(context)
                                        : null,
                                    size: 16,
                                  ),
                                ),
                              )
                            else if (depth > 0)
                              const SizedBox(width: 16),
                            if (_isSelectionMode)
                              Checkbox(
                                value: isChecked,
                                onChanged: layer.type == _selectionBaseType
                                    ? (_) => setState(() {
                                        if (isChecked) {
                                          _selectedIds.remove(layer.id);
                                          if (_selectedIds.isEmpty) {
                                            _isSelectionMode = false;
                                            _selectionBaseType = null;
                                          }
                                        } else {
                                          _selectedIds.add(layer.id);
                                        }
                                      })
                                    : null,
                              )
                            else
                              Tooltip(
                                message: layer.isVisible
                                    ? l10n.layerPanelHideLayerTooltip
                                    : l10n.layerPanelShowLayerTooltip,
                                child: GestureDetector(
                                  // 押せる所は印の周り（20×40）。以前は16pxの
                                  // 印だけで、押し損ねると行を選んでいた。
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => context
                                      .read<ProjectService>()
                                      .updateLayer(
                                        projectId: widget.projectId,
                                        sceneId: widget.sceneId,
                                        frameIndex: widget.frameIndex,
                                        layer: layer.copyWith(
                                          isVisible: !layer.isVisible,
                                        ),
                                      ),
                                  child: SizedBox(
                                    width: 20,
                                    height: 40,
                                    child: Align(
                                      alignment:
                                          AlignmentDirectional.centerStart,
                                      child: Icon(
                                        layer.isVisible
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (_isSelectionMode) const SizedBox(width: 4),
                            _layerTypeIcon(context, layer.type),
                            const SizedBox(width: 4),
                            GestureDetector(
                              key: ValueKey('layer-preview-tap-${layer.id}'),
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _openLayerFullscreenPreview(
                                layer,
                                canvasBackground,
                              ),
                              child: _LayerThumbnail(
                                // Visibility affects the canvas composition,
                                // never the layer's own thumbnail/preview.
                                key: ValueKey(
                                  '${widget.sceneId}:${widget.frameIndex}:${layer.id}:'
                                  '${_thumbRevision[layer.id] ?? 0}:$canvasBackground:'
                                  '${layer.opacity}',
                                ),
                                projectId: widget.projectId,
                                sceneId: widget.sceneId,
                                frameIndex: widget.frameIndex,
                                layerId: layer.id,
                                backgroundColor: canvasBackground,
                                layerOpacity: layer.opacity,
                              ),
                            ),
                          ],
                        ),
                        // ListTileのleading（目・種別アイコン・サムネイル）と
                        // trailing（更新マーク・三点・結合・ゴミ箱・ハンドル）で
                        // 幅を取られ、パネル幅約250dpだと名前に約50dpしか残らない。
                        // 折り返しを許すと日本語名が**1文字ずつ縦に積まれて**
                        // 行の高さが3倍になり読めなくなるため、必ず1行で省略する。
                        title: Text(
                          editingLayerLabel(l10n, layer),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: localizedHeadingStyle(
                            context,
                            const TextStyle(fontSize: 12),
                          ),
                        ),
                        subtitle: layer.type == model.LayerType.common
                            ? Text(
                                _rangeSummary(l10n, layer),
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: ThemeService.activeAccentText,
                                ),
                              )
                            : layer.hasClipping
                            ? Text(
                                l10n.layerPanelClippingBadge,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: AccentTextTheme.of(context),
                                ),
                              )
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 自動塗り更新マーク：初回使用時の吹き出し説明
                            if (layer.needsAutofillUpdate)
                              FirstUseTooltip(
                                tooltipKey: 'autofill_mark',
                                message: l10n.layerPanelAutofillMarkTooltip,
                                child: GestureDetector(
                                  onTap: () =>
                                      _showAutofillDialog(context, layer),
                                  onLongPress: () =>
                                      _showAutofillUpdateHelp(context),
                                  child: Icon(
                                    Icons.error,
                                    color:
                                        ThemeService.activeColorScheme.tertiary,
                                    size: 14,
                                  ),
                                ),
                              ),
                            if (layer.opacityLocked)
                              Icon(
                                Icons.opacity,
                                size: 14,
                                color: AccentTextTheme.of(context),
                              ),
                            if (layer.isLocked)
                              const Icon(Icons.lock, size: 14),
                            // 三点メニュー・ゴミ箱は各レイヤーの右側に配置する
                            // （対象レイヤーが常に明確になり、選択状態に依存しない）。
                            Tooltip(
                              message: MaterialLocalizations.of(
                                context,
                              ).showMenuTooltip,
                              child: GestureDetector(
                                key: ValueKey('canvasLayerMenu_${layer.id}'),
                                behavior: HitTestBehavior.opaque,
                                onTap: () =>
                                    _isTimelineMaterial(layer.type) ||
                                        layer.type == model.LayerType.common ||
                                        layer.type ==
                                            model.LayerType.autoFillLineart
                                    ? _showTimelineLayerMenu(context, layer)
                                    : _showLayerOptions(context, layer),
                                child: const _RowActionTarget(
                                  child: Icon(Icons.more_vert, size: 16),
                                ),
                              ),
                            ),
                            // 下のレイヤーとワンタップで結合（複数選択モードを使わずに
                            // 済む一括操作の一つ）。ゴミ箱アイコンのすぐ隣に置くことで
                            // 「レイヤーへの操作」としてまとまって見えるようにしている。
                            Tooltip(
                              message: l10n.layerPanelMergeDownTooltip,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _layerBelow(layer, layers) != null
                                    ? () => _mergeWithLayerBelow(
                                        context,
                                        layer,
                                        layers,
                                      )
                                    : null,
                                child: _RowActionTarget(
                                  child: Icon(
                                    Icons.merge_type,
                                    size: 16,
                                    color: _layerBelow(layer, layers) != null
                                        ? null
                                        : Theme.of(context).disabledColor,
                                  ),
                                ),
                              ),
                            ),
                            Tooltip(
                              message: l10n.commonDelete,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _canDeleteLayerRow(layer, layers)
                                    ? () => _deleteLayerRow(
                                        context,
                                        layer,
                                        layers,
                                      )
                                    : null,
                                child: _RowActionTarget(
                                  child: Icon(
                                    Icons.delete_outline,
                                    size: 16,
                                    color: _canDeleteLayerRow(layer, layers)
                                        ? IconTheme.of(context).color
                                        : Theme.of(context).disabledColor,
                                  ),
                                ),
                              ),
                            ),
                            // ドラッグハンドル（並び替え用）。ゴミ箱等の操作アイコンと
                            // 重ならないよう、常にこの位置に明示的に配置する。
                            ReorderableDragStartListener(
                              index: index,
                              child: const _RowActionTarget(
                                child: Icon(Icons.drag_handle, size: 16),
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          setState(() {
                            if (_isSelectionMode) {
                              if (layer.type != _selectionBaseType) return;
                              if (_selectedIds.contains(layer.id)) {
                                _selectedIds.remove(layer.id);
                                if (_selectedIds.isEmpty) {
                                  _isSelectionMode = false;
                                  _selectionBaseType = null;
                                }
                              } else {
                                _selectedIds.add(layer.id);
                              }
                            } else {
                              _selectedIndex = index;
                              _selectedFolderId =
                                  layer.type == model.LayerType.folder
                                  ? layer.id
                                  : null;
                            }
                          });
                          if (!_isSelectionMode &&
                              layer.type == model.LayerType.text &&
                              widget.onEditTextLayer != null) {
                            widget.onEditTextLayer!(layer);
                          }
                          // フォルダ行は描画対象になり得ないため、実際の描画先
                          // レイヤーの切り替え通知からは除外する（グループ化用の
                          // 見出し行としての選択ハイライトのみ）。
                          if (!_isSelectionMode &&
                              layer.type != model.LayerType.folder) {
                            widget.onLayerSelected?.call(layer.id);
                          }
                        },
                        onLongPress: () => setState(() {
                          if (!_isSelectionMode) {
                            _isSelectionMode = true;
                            _selectionBaseType = layer.type;
                            _selectedIds.add(layer.id);
                          }
                        }),
                      ),
                    );
                  },
                ).clipListInk(),
              ),
              if (!scrollControls) ...footer,
            ],
          );
        },
      ),
    );
    return widget.dockedMode ? panel : MenuSurface(child: panel);
  }

  Future<void> _copyLayerWithGesture(
    BuildContext context,
    model.Layer layer,
  ) async {
    final projectService = context.read<ProjectService>();
    final copied = await LayerClipboardService.instance.copy(
      projectService: projectService,
      projectId: widget.projectId,
      sceneId: widget.sceneId,
      frameIndex: widget.frameIndex,
      layerId: layer.id,
    );
    if (!mounted || !copied) return;
    final refreshed = _visibleLayers(
      projectService.layersOf(
        widget.projectId,
        widget.sceneId,
        widget.frameIndex,
      ),
    );
    final index = refreshed.indexWhere((item) => item.id == layer.id);
    if (index >= 0) setState(() => _selectedIndex = index);
  }

  void _pasteLayerBeforeWithGesture(BuildContext context, model.Layer target) {
    final projectService = context.read<ProjectService>();
    final pasted = LayerClipboardService.instance.pasteBefore(
      projectService: projectService,
      projectId: widget.projectId,
      targetSceneId: widget.sceneId,
      targetFrameIndex: widget.frameIndex,
      beforeLayerId: target.id,
    );
    if (pasted == null) return;
    final refreshed = _visibleLayers(
      projectService.layersOf(
        widget.projectId,
        widget.sceneId,
        widget.frameIndex,
      ),
    );
    final index = refreshed.indexWhere((item) => item.id == pasted.id);
    if (index >= 0) setState(() => _selectedIndex = index);
    if (pasted.type != model.LayerType.folder) {
      widget.onLayerSelected?.call(pasted.id);
    }
  }

  Widget _layerTypeIcon(BuildContext context, model.LayerType type) {
    return switch (type) {
      model.LayerType.autoFillLineart => Icon(
        Icons.edit,
        size: 12,
        color: ThemeService.activeColorScheme.tertiary,
      ),
      model.LayerType.autoFill => Icon(
        Icons.palette,
        size: 12,
        color: ThemeService.activeColorScheme.secondary,
      ),
      model.LayerType.common => Icon(
        Icons.link,
        size: 12,
        color: ThemeService.activeAccentText,
      ),
      model.LayerType.folder => Icon(
        Icons.folder,
        size: 12,
        color: ThemeService.activeColorScheme.tertiary,
      ),
      model.LayerType.text => Icon(
        Icons.text_fields,
        size: 12,
        color: ThemeService.activeColorScheme.secondary,
      ),
      model.LayerType.timelineImage => Icon(
        Icons.image,
        size: 12,
        color: ThemeService.activeColorScheme.secondary,
      ),
      model.LayerType.timelineVideo => Icon(
        Icons.videocam,
        size: 12,
        color: ThemeService.activeAccentText,
      ),
      model.LayerType.timelineText => Icon(
        Icons.title,
        size: 12,
        color: ThemeService.activeColorScheme.secondary,
      ),
      model.LayerType.watermark => Icon(
        Icons.branding_watermark,
        size: 12,
        color: ThemeService.activeColorScheme.secondary,
      ),
      // 選択レイヤーは他の種別と異なり、固定の意味色ではなく、ユーザーが
      // カスタマイズできるテーマの選択色を使う。
      model.LayerType.selection => Icon(
        Icons.highlight_alt,
        size: 12,
        color: Theme.of(context).colorScheme.secondary,
      ),
      _ => const SizedBox(width: 12),
    };
  }

  // 結合可能なレイヤー種別（共通レイヤー・フォルダ・タイムライン
  // 素材は結合不可）。
  static const _mergeableLayerTypesForPanel = {
    model.LayerType.normal,
    model.LayerType.autoFillLineart,
    model.LayerType.autoFill,
  };

  /// このレイヤーのすぐ下にある結合可能なレイヤーを探す（フラット表示上の
  /// 直後の要素。フォルダ・共通レイヤー等は対象外）。見つからなければnull。
  model.Layer? _layerBelow(model.Layer layer, List<model.Layer> layers) {
    if (!_mergeableLayerTypesForPanel.contains(layer.type)) return null;
    final idx = layers.indexWhere((l) => l.id == layer.id);
    if (idx < 0 || idx + 1 >= layers.length) return null;
    final below = layers[idx + 1];
    return below.parentFolderId == layer.parentFolderId &&
            _mergeableLayerTypesForPanel.contains(below.type)
        ? below
        : null;
  }

  /// このレイヤーとすぐ下のレイヤーをワンタップで結合する。
  Future<void> _mergeWithLayerBelow(
    BuildContext context,
    model.Layer layer,
    List<model.Layer> layers,
  ) async {
    final below = _layerBelow(layer, layers);
    if (below == null) return;
    await context.read<ProjectService>().mergeLayers(
      projectId: widget.projectId,
      sceneId: widget.sceneId,
      frameIndex: widget.frameIndex,
      layerIds: [layer.id, below.id],
    );
    if (!mounted) return;
    setState(() => _selectedIndex = 0);
  }

  /// 複数選択モードで選択中のレイヤーを一括で表示・非表示にする
  /// （タスク#147：複数選択時の全表示・全非表示ボタン）。
  void _setVisibilityForSelected(
    BuildContext context,
    List<model.Layer> layers,
    bool visible,
  ) {
    final projectService = context.read<ProjectService>();
    for (final layer in layers) {
      if (!_selectedIds.contains(layer.id) || layer.isVisible == visible) {
        continue;
      }
      projectService.updateLayer(
        projectId: widget.projectId,
        sceneId: widget.sceneId,
        frameIndex: widget.frameIndex,
        layer: layer.copyWith(isVisible: visible),
      );
    }
  }

  /// 表示中（isVisible）の結合可能なレイヤーを全てワンタップで結合する。
  Future<void> _mergeAllVisibleLayers(
    BuildContext context,
    List<model.Layer> layers,
  ) async {
    final ids = layers
        .where(
          (l) => l.isVisible && _mergeableLayerTypesForPanel.contains(l.type),
        )
        .map((l) => l.id)
        .toList();
    if (ids.length < 2) return;
    await context.read<ProjectService>().mergeLayers(
      projectId: widget.projectId,
      sceneId: widget.sceneId,
      frameIndex: widget.frameIndex,
      layerIds: ids,
    );
    if (!mounted) return;
    setState(() => _selectedIndex = 0);
  }

  /// 選択中の複数レイヤーをグループ化する（複数レイヤーを1つのキーフレームで
  /// まとめて動かす機能）。名前を入力後、すぐにグループのキーフレーム編集
  /// シートを開き、そのまま動きを設定できるようにする。
  void _showCreateGroupDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController(
      text: l10n.layerPanelGroupDefaultName,
    );
    showDialog(
      context: context,
      builder: (ctx) => DisposeOnUnmount(
        controller: nameCtrl,
        builder: (ctx) => AlertDialog(
          insetPadding: typingDialogInsetPadding(ctx),
          title: Text(l10n.layerPanelGroupTooltip),
          content: TextField(controller: nameCtrl, autofocus: true),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () {
                final ids = _selectedIds.toList();
                final name = nameCtrl.text.trim().isEmpty
                    ? l10n.layerPanelGroupDefaultName
                    : nameCtrl.text.trim();
                final group = context.read<ProjectService>().addLayerGroup(
                  widget.projectId,
                  widget.sceneId,
                  name,
                  ids,
                );
                Navigator.pop(ctx);
                setState(() {
                  _selectedIds.clear();
                  _isSelectionMode = false;
                  _selectionBaseType = null;
                });
                final tm = context.read<ProjectService>().tileManagerOf(
                  widget.projectId,
                );
                showLayerGroupKeyframeSheet(
                  context,
                  projects: context.read<ProjectService>(),
                  projectId: widget.projectId,
                  sceneId: widget.sceneId,
                  groupId: group.id,
                  groupName: group.name,
                  initialKeyframes: group.keyframes,
                  currentFrame: widget.frameIndex,
                  totalFrames:
                      context
                          .read<ProjectService>()
                          .sceneOf(widget.projectId, widget.sceneId)
                          ?.frames
                          .length ??
                      1,
                  canvasWidth: tm.canvasWidth,
                  canvasHeight: tm.canvasHeight,
                  onChanged: (kfs) =>
                      context.read<ProjectService>().updateLayerGroup(
                        widget.projectId,
                        widget.sceneId,
                        group.copyWith(keyframes: kfs),
                      ),
                );
              },
              child: Text(l10n.commonAdd),
            ),
          ],
        ),
      ),
    );
  }

  bool _isTimelineMaterial(model.LayerType type) =>
      type == model.LayerType.timelineImage ||
      type == model.LayerType.timelineVideo ||
      type == model.LayerType.timelineText ||
      type == model.LayerType.watermark;

  /// [layer]を各レイヤー行のゴミ箱アイコンから単体削除できるかどうか
  /// （最後の1枚の通常レイヤーは削除不可、という既存の制約を踏襲）。
  bool _canDeleteLayerRow(model.Layer layer, List<model.Layer> layers) {
    if (layer.type == model.LayerType.normal) {
      return layers.where((l) => l.type == model.LayerType.normal).length > 1;
    }
    return true;
  }

  /// 各レイヤー行のゴミ箱アイコンからの単体削除（三点メニュー・
  /// ゴミ箱は各レイヤーの右側に配置）。タイムライン素材は既存通り確認ダイアログ
  /// を経由し、共通レイヤーは表示範囲のトリミング（タスク#148）、
  /// それ以外は即時削除する。
  Future<void> _deleteLayerRow(
    BuildContext context,
    model.Layer layer,
    List<model.Layer> layers,
  ) async {
    if (_isTimelineMaterial(layer.type)) {
      _showTimelineDeleteConfirm(context, layer);
      return;
    }
    if (layer.type == model.LayerType.common) {
      await _deleteCommonLayerAtCurrentFrame(context, layer);
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    if (!await confirmDelete(
      context,
      message: l10n.layerPanelDeleteConfirmTitle(
        editingLayerLabel(l10n, layer),
      ),
    )) {
      return;
    }
    if (!context.mounted) return;
    context.read<ProjectService>().removeLayer(
      projectId: widget.projectId,
      sceneId: widget.sceneId,
      frameIndex: widget.frameIndex,
      layerId: layer.id,
    );
    setState(() {
      if (_selectedIndex >= layers.length - 1) {
        _selectedIndex = layers.length - 2;
      }
      if (_selectedIndex < 0) _selectedIndex = 0;
    });
  }

  /// 共通レイヤーの「このフレームだけ削除」（タスク#148）。共通レイヤーは
  /// 単一の連続した表示範囲（rangeStart〜rangeEnd）でしか表せないため、
  /// 現在表示中のフレームが範囲の端（先頭・末尾）ならその1フレーム分だけ
  /// 範囲を狭め、範囲が1フレームしかなければ通常通りレイヤー自体を削除する。
  /// 範囲の途中のフレームでは、連続区間を保てなくなるため「ここより前を
  /// 残す」「ここより後を残す」をユーザーに選ばせる。
  Future<void> _deleteCommonLayerAtCurrentFrame(
    BuildContext context,
    model.Layer layer,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final range = _effectiveCommonRange(layer);
    final current = widget.frameIndex;
    final projectService = context.read<ProjectService>();

    void applyRange(({int start, int end}) r) {
      projectService.updateLayer(
        projectId: widget.projectId,
        sceneId: widget.sceneId,
        frameIndex: widget.frameIndex,
        layer: layer.copyWith(
          rangeMode: model.LayerRangeMode.frameRange,
          rangeStart: r.start + 1,
          rangeEnd: r.end + 1,
          rangeSceneId: null,
        ),
      );
    }

    Future<void> deleteEntirely() async {
      if (!await confirmDelete(
        context,
        message: l10n.layerPanelDeleteConfirmTitle(
          editingLayerLabel(l10n, layer),
        ),
      )) {
        return;
      }
      if (!context.mounted) return;
      projectService.removeLayer(
        projectId: widget.projectId,
        sceneId: widget.sceneId,
        frameIndex: widget.frameIndex,
        layerId: layer.id,
      );
    }

    // このフレームが範囲外（通常はここへ来ないはずだが念のため）の場合も、
    // レイヤー自体を通常削除する。
    if (current < range.start || current > range.end) {
      await deleteEntirely();
      return;
    }

    final trimmed = model.trimCommonLayerRange(
      start: range.start,
      end: range.end,
      frameIndex: current,
    );
    // 範囲が1フレームのみ（trimCommonLayerRangeがnullを返す境界ケース）。
    if (range.start >= range.end) {
      await deleteEntirely();
      return;
    }
    if (trimmed != null) {
      // 先頭または末尾フレーム：一意に範囲が縮む。
      if (!await confirmDelete(
        context,
        message: l10n.layerPanelCommonRemoveFrame(layer.name),
      )) {
        return;
      }
      if (!context.mounted) return;
      applyRange(trimmed);
      return;
    }

    // 範囲の途中：連続区間を保てないため、どちらを残すか選ばせる。
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.layerPanelCommonDeleteMidDialogTitle(layer.name)),
        content: messageText(l10n.layerPanelCommonDeleteMidDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'keepBefore'),
            child: Text(l10n.layerPanelCommonDeleteKeepBeforeButton),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'keepAfter'),
            child: Text(l10n.layerPanelCommonDeleteKeepAfterButton),
          ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    final resolved = model.trimCommonLayerRange(
      start: range.start,
      end: range.end,
      frameIndex: current,
      keepBefore: choice == 'keepBefore',
    );
    if (resolved != null) applyRange(resolved);
  }

  void _showTimelineDeleteConfirm(BuildContext context, model.Layer layer) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          l10n.layerPanelDeleteConfirmTitle(editingLayerLabel(l10n, layer)),
        ),
        content: messageText(l10n.layerPanelDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: warningFilledButtonStyle(ctx),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ProjectService>().removeLayer(
                projectId: widget.projectId,
                sceneId: widget.sceneId,
                frameIndex: widget.frameIndex,
                layerId: layer.id,
              );
              setState(() => _selectedIndex = 0);
            },
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
  }

  /// 共通レイヤーの実際の表示範囲（現在のシーン内、0始まり）を計算する。
  /// timeline_screen.dartの_buildCommonLayerTrackと同じロジック
  /// （タスク#148：フレーム内削除での長さ変更のために、フレームパネル側
  /// でも同じ計算が必要になったため複製）。
  ({int start, int end}) _effectiveCommonRange(model.Layer layer) {
    final total = context.read<ProjectService>().frameCount(
      widget.projectId,
      widget.sceneId,
    );
    switch (layer.rangeMode) {
      case model.LayerRangeMode.allFrames:
      case model.LayerRangeMode.currentScene:
      case model.LayerRangeMode.sceneRange:
        return (start: 0, end: (total - 1).clamp(0, total - 1));
      case model.LayerRangeMode.frameRange:
        final start = ((layer.rangeStart ?? 1) - 1).clamp(0, total - 1);
        final end = ((layer.rangeEnd ?? start + 1) - 1).clamp(start, total - 1);
        return (start: start, end: end);
    }
  }

  /// 共通レイヤーの表示範囲を「リンクアイコン 名前（開始〜終了）」の形式で要約する
  String _rangeSummary(AppLocalizations l10n, model.Layer layer) {
    switch (layer.rangeMode) {
      case model.LayerRangeMode.allFrames:
        return l10n.layerPanelRangeAllFrames;
      case model.LayerRangeMode.currentScene:
        return l10n.layerPanelRangeCurrentScene;
      case model.LayerRangeMode.sceneRange:
        if (layer.rangeSceneId == null) {
          return l10n.layerPanelRangeSceneSpecified;
        }
        final scenes = context.read<ProjectService>().scenesOf(
          widget.projectId,
        );
        final scene = scenes
            .where((s) => s.id == layer.rangeSceneId)
            .firstOrNull;
        return scene != null
            ? scene.displayName
            : l10n.layerPanelRangeSceneSpecified;
      case model.LayerRangeMode.frameRange:
        final s = layer.rangeStart ?? 1;
        final e = layer.rangeEnd ?? s;
        return l10n.layerPanelRangeFrameSpan(s, e);
    }
  }

  void _showTimelineLayerMenu(BuildContext context, model.Layer layer) {
    final l10n = AppLocalizations.of(context)!;
    final isCommon = layer.type == model.LayerType.common;
    final isLineart = layer.type == model.LayerType.autoFillLineart;
    // 対応する線画レイヤーを持たない自動塗りレイヤー（線画レイヤーを
    // 削除した後に残った状態）かどうかを判定する。
    final allLayers = context.read<ProjectService>().layersOf(
      widget.projectId,
      widget.sceneId,
      widget.frameIndex,
    );
    final isOrphanedAutofill = isOrphanedAutofillLayer(allLayers, layer);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ScrollableSheetBody(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                editingLayerLabel(l10n, layer),
                style: localizedHeadingStyle(
                  context,
                  const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (!isLineart)
              ListTile(
                leading: const Icon(Icons.tune),
                title: Text(
                  isCommon
                      ? l10n.layerPanelMenuFrameRangeChange
                      : l10n.layerPanelMenuRangeChange,
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showRangeChangeDialog(context, layer);
                },
              ),
            if (isLineart)
              ListTile(
                leading: const Icon(Icons.category),
                title: Text(l10n.layerPanelMenuPartAssign),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPartAssignDialog(context, layer);
                },
              ),
            if (isLineart)
              ListTile(
                leading: const Icon(Icons.auto_fix_high),
                title: Text(l10n.layerPanelMenuRunAutofill),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAutofillDialog(context, layer, isLineartLayer: true);
                },
              ),
            // 線画レイヤーを削除して残った孤立した自動塗りレイヤー：
            // 領域再判定はできないため、不透明度ロック＋最新色での塗りつぶしのみ実行
            if (isOrphanedAutofill)
              ListTile(
                leading: const Icon(Icons.format_color_fill),
                title: Text(l10n.layerPanelMenuOrphanFill),
                subtitle: Text(
                  l10n.layerPanelMenuOrphanFillSubtitle,
                  style: const TextStyle(fontSize: 11),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _runOrphanedAutofill(context, layer);
                },
              ),
            if (!isCommon && !isLineart)
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: Text(l10n.layerPanelMenuReplaceMaterial),
                onTap: () {
                  Navigator.pop(ctx);
                  _replaceMaterial(context, layer);
                },
              ),
            if (isCommon)
              ListTile(
                leading: const Icon(Icons.copy),
                title: Text(l10n.themeDuplicateAction),
                onTap: () {
                  Navigator.pop(ctx);
                  final projects = context.read<ProjectService>();
                  final projectId = widget.projectId;
                  final home = projects.homeOf(projectId, layer.id);
                  final sceneId = home?.sceneId ?? widget.sceneId;
                  final frameIndex = home?.frameIndex ?? widget.frameIndex;
                  final name = numberedEditorCopyName(l10n, layer.name, {
                    for (final other in projects.layersOf(
                      projectId,
                      sceneId,
                      frameIndex,
                    ))
                      other.name,
                    for (final entry in projects.commonLayersOf(projectId))
                      entry.layer.name,
                  });
                  projects.editTimeline(projectId, 'Duplicate layer', () {
                    projects.duplicateLayer(
                      projectId: projectId,
                      sceneId: sceneId,
                      frameIndex: frameIndex,
                      layerId: layer.id,
                      nameOverride: name,
                    );
                  });
                },
              ),
            if (isCommon)
              ListTile(
                leading: const Icon(Icons.edit),
                title: Text(l10n.commonRename),
                onTap: () {
                  Navigator.pop(ctx);
                  _showRenameDialog(context, layer);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l10n.commonDelete),
              onTap: () {
                Navigator.pop(ctx);
                _showTimelineDeleteConfirm(context, layer);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 名前の変更：空白だけの名前は確定させず、前後の空白を除き、Enterでも
  /// 確定する（NameEntryDialog。以前は自前の欄で、空白だけの名前が通って
  /// 名前が消え、Enterでは何も起きなかった）。
  void _showRenameDialog(BuildContext context, model.Layer layer) {
    final l10n = AppLocalizations.of(context)!;
    final projects = context.read<ProjectService>();
    showDialog<void>(
      context: context,
      builder: (_) => NameEntryDialog(
        title: l10n.commonRename,
        confirmLabel: l10n.commonChange,
        cancelLabel: l10n.commonCancel,
        initialName: editingLayerLabel(l10n, layer),
        onSubmit: (name) async => projects.updateLayer(
          projectId: widget.projectId,
          sceneId: widget.sceneId,
          frameIndex: widget.frameIndex,
          layer: layer.copyWith(name: name),
        ),
      ),
    );
  }

  /// 表示範囲設定ダイアログ（共通レイヤー・タイムライン素材レイヤー）。
  /// 既存レイヤーの変更（[onConfirm]省略時はupdateLayerを直接呼ぶ）・新規作成時の
  /// 設定（[onConfirm]を渡すとその関数へ結果を渡すのみで自動更新しない）の両方に使う。
  void _showRangeChangeDialog(
    BuildContext context,
    model.Layer layer, {
    String? title,
    String? confirmLabel,
    void Function(
      model.LayerRangeMode mode,
      int start,
      int end,
      String? rangeSceneId,
    )?
    onConfirm,
  }) {
    final ps = context.read<ProjectService>();
    final homeSceneId =
        ps.homeOf(widget.projectId, layer.id)?.sceneId ?? widget.sceneId;
    showDialog<void>(
      context: context,
      builder: (_) => LayerRangeDialog(
        layer: layer,
        homeSceneId: homeSceneId,
        totalFrames: ps.frameCount(widget.projectId, homeSceneId),
        scenes: ps.scenesOf(widget.projectId),
        title: title,
        confirmLabel: confirmLabel,
        onConfirm:
            onConfirm ??
            (mode, start, end, rangeSceneId) {
              ps.updateLayer(
                projectId: widget.projectId,
                sceneId: widget.sceneId,
                frameIndex: widget.frameIndex,
                layer: layer.copyWith(
                  rangeMode: mode,
                  rangeStart: start,
                  rangeEnd: end,
                  rangeSceneId: rangeSceneId,
                ),
              );
            },
      ),
    );
  }

  void _showAddLayerMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ScrollableSheetBody(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.layers),
              title: Text(l10n.layerPanelMenuNormalLayer),
              onTap: () {
                Navigator.pop(ctx);
                _addLayer(
                  context,
                  model.LayerType.normal,
                  (n) => l10n.layerPanelDefaultLayerName(n),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.link, color: ThemeService.activeAccentText),
              title: Text(l10n.layerPanelMenuCommonLayer),
              onTap: () {
                Navigator.pop(ctx);
                _addCommonLayer(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: Text(l10n.creativePanelFolderButton),
              onTap: () {
                Navigator.pop(ctx);
                _addLayer(
                  context,
                  model.LayerType.folder,
                  (n) => l10n.layerPanelDefaultFolderName(n),
                );
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(
                Icons.edit,
                color: ThemeService.activeColorScheme.tertiary,
              ),
              title: Text(l10n.layerPanelMenuLineartLayer),
              onTap: () {
                Navigator.pop(ctx);
                _addLayer(
                  context,
                  model.LayerType.autoFillLineart,
                  (n) => l10n.layerPanelDefaultLineartName(n),
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.palette,
                color: ThemeService.activeColorScheme.secondary,
              ),
              title: Text(l10n.layerPanelMenuAutofillLayer),
              onTap: () {
                Navigator.pop(ctx);
                _addLayer(
                  context,
                  model.LayerType.autoFill,
                  (n) => l10n.layerPanelDefaultAutofillName(n),
                );
              },
            ),
            // 選択レイヤー（眼鏡断層フィルター等、範囲を指定してかけるフィルター用の
            // マスク専用レイヤー）。通常合成には含まれず、テーマの選択色で
            // 半透明タイントしてキャンバス上に重ねて表示する。
            ListTile(
              leading: Icon(
                Icons.highlight_alt,
                color: Theme.of(context).colorScheme.secondary,
              ),
              title: Text(l10n.layerPanelMenuSelectionLayer),
              onTap: () {
                Navigator.pop(ctx);
                _addLayer(
                  context,
                  model.LayerType.selection,
                  (n) => l10n.layerPanelDefaultSelectionName(n),
                );
              },
            ),
            // テキストレイヤーはテキストツールからキャンバスタップで自動生成するため追加しない
          ],
        ),
      ),
    );
  }

  /// 共通レイヤーの新規追加。追加前に表示範囲
  /// （共通レイヤー範囲）を設定するダイアログを表示してから作成する。
  void _addCommonLayer(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final layers = context.read<ProjectService>().layersOf(
      widget.projectId,
      widget.sceneId,
      widget.frameIndex,
    );
    final visible = _visibleLayers(layers);
    final placeholder = model.Layer(
      id: '',
      name: '',
      type: model.LayerType.common,
    );
    _showRangeChangeDialog(
      context,
      placeholder,
      title: l10n.layerPanelCommonRangeTitle,
      confirmLabel: l10n.commonCreate,
      onConfirm: (mode, start, end, rangeSceneId) {
        final ps = context.read<ProjectService>();
        final created = ps.editTimeline(
          widget.projectId,
          'Add common layer',
          () {
            final created = ps.addLayer(
              projectId: widget.projectId,
              sceneId: widget.sceneId,
              frameIndex: widget.frameIndex,
              type: model.LayerType.common,
              name: l10n.layerPanelDefaultCommonName(visible.length + 1),
            );
            ps.updateLayer(
              projectId: widget.projectId,
              sceneId: widget.sceneId,
              frameIndex: widget.frameIndex,
              layer: created.copyWith(
                rangeMode: mode,
                rangeStart: start,
                rangeEnd: end,
                rangeSceneId: rangeSceneId,
              ),
            );
            return created;
          },
          changesTiles: false,
        );
        setState(() => _selectedIndex = 0);
        widget.onLayerSelected?.call(created.id);
      },
    );
  }

  void _addLayer(
    BuildContext context,
    model.LayerType type,
    String Function(int n) nameBuilder,
  ) {
    final projects = context.read<ProjectService>();
    final layers = projects.layersOf(
      widget.projectId,
      widget.sceneId,
      widget.frameIndex,
    );
    final folder = layers
        .where((layer) => layer.id == _selectedFolderId)
        .firstOrNull;
    final created = projects.addLayer(
      projectId: widget.projectId,
      sceneId: widget.sceneId,
      frameIndex: widget.frameIndex,
      type: type,
      name: nameBuilder(layers.length + 1),
      parentFolderId: folder?.id,
    );
    if (folder != null && created.parentFolderId == folder.id) {
      projects.setLayerFolderExpanded(widget.projectId, folder, true);
    }
    final visible = _visibleLayers(
      projects.layersOf(widget.projectId, widget.sceneId, widget.frameIndex),
    );
    setState(() {
      _selectedIndex = visible.indexWhere((layer) => layer.id == created.id);
      _selectedFolderId = type == model.LayerType.folder ? created.id : null;
    });
    if (type != model.LayerType.folder) {
      widget.onLayerSelected?.call(created.id);
    }
  }

  List<model.Layer> _layerFolderChoices(model.Layer layer) {
    final all = context.read<ProjectService>().layersOf(
      widget.projectId,
      widget.sceneId,
      widget.frameIndex,
    );
    final byId = {for (final item in all) item.id: item};
    return all.where((candidate) {
      if (candidate.type != model.LayerType.folder ||
          candidate.id == layer.parentFolderId) {
        return false;
      }
      final visited = <String>{};
      String? parent = candidate.id;
      while (parent != null && visited.add(parent)) {
        if (parent == layer.id) return false;
        parent = byId[parent]?.parentFolderId;
      }
      return parent == null;
    }).toList();
  }

  Future<void> _showLayerFolderPicker(model.Layer layer) async {
    final l10n = AppLocalizations.of(context)!;
    final choices = _layerFolderChoices(layer);
    final selected = await showDialog<({String? folderId})>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.folderMoveToTitle),
        children: [
          if (layer.parentFolderId != null)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, (folderId: null)),
              child: Text(l10n.projectListFolderRootOption),
            ),
          for (final folder in choices)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, (folderId: folder.id)),
              child: Text(folder.name),
            ),
        ],
      ),
    );
    if (!mounted || selected == null) return;
    final projects = context.read<ProjectService>();
    if (!projects.moveLayerToFolder(
      projectId: widget.projectId,
      sceneId: widget.sceneId,
      frameIndex: widget.frameIndex,
      layerId: layer.id,
      folderId: selected.folderId,
    )) {
      return;
    }
    final target = choices
        .where((folder) => folder.id == selected.folderId)
        .firstOrNull;
    if (target != null) {
      projects.setLayerFolderExpanded(widget.projectId, target, true);
    }
    setState(() {});
  }

  /// [frameIndex]時点のキーフレーム値（拡大縮小・回転）を書き換えた
  /// キーフレーム一覧を返す。キーフレームが1つも無い、または1つだけの
  /// 状態であれば、単一のキーフレーム値がすべてのフレームへクランプ
  /// 適用される（[LayerKeyframeEngine.valueAt]）ため、この操作は事実上
  /// レイヤー（素材）全体への一括適用になる。既にアニメーション用の
  /// 複数キーフレームが打たれている場合は、現在フレーム位置の値だけを
  /// 書き換える（既存のキーフレーム編集シートと同じ挙動）。
  List<LayerKeyframe> _updateKeyframeAtCurrentFrame(
    List<LayerKeyframe> keyframes,
    int frameIndex,
    LayerKeyframe Function(LayerKeyframe base) modifier,
  ) {
    final base = LayerKeyframeEngine()
        .valueAt(keyframes, frameIndex)
        .copyWith(frameIndex: frameIndex);
    final updated = modifier(base);
    final list = [...keyframes];
    final idx = list.indexWhere((k) => k.frameIndex == frameIndex);
    if (idx >= 0) {
      list[idx] = updated;
    } else {
      list.add(updated);
    }
    return list;
  }

  /// レイヤー詳細設定（不透明度・ブレンドモード・ロック・クリッピング等）。
  /// パネル下部の共通ボタン（`_selectedIndex`使用）と、各レイヤー行の
  /// 三点メニュー（[layer]を直接指定）の両方から呼び出せる。
  void _showLayerOptions(BuildContext context, model.Layer layer) {
    final l10n = AppLocalizations.of(context)!;
    // The sheet edits the layer as it now is: each change builds on the
    // previous one (a scale change after an opacity change keeps the new
    // opacity), and the sliders show what was last set.
    var latest = layer;
    void update(model.Layer Function(model.Layer) updater) {
      latest = updater(latest);
      context.read<ProjectService>().updateLayer(
        projectId: widget.projectId,
        sceneId: widget.sceneId,
        frameIndex: widget.frameIndex,
        layer: latest,
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        // 行を押したときの色をスクロールの中に限る（シートの面へ描くと、
        // 半分隠れた行の色が下の余白〔ナビゲーションバーの下〕へはみ出す）。
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  editingLayerLabel(l10n, layer),
                  style: localizedHeadingStyle(
                    context,
                    const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              if (layer.parentFolderId != null ||
                  _layerFolderChoices(layer).isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.drive_file_move_outline),
                  title: Text(l10n.folderMoveToTitle),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showLayerFolderPicker(layer);
                  },
                ),
              // 不透明度スライダー
              StatefulBuilder(
                builder: (ctx, setS) => LabeledSlider(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  label: l10n.layerPanelOpacityLabel,
                  labelStyle: const TextStyle(fontSize: 13),
                  value: latest.opacity.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 100,
                  sliderLabel: '${latest.opacity}%',
                  valueText: '${latest.opacity}%',
                  onChanged: (v) {
                    setS(() {});
                    update((l) => l.copyWith(opacity: v.round()));
                  },
                ),
              ),
              // 拡大縮小・回転スライダー：不透明度と同様、レイヤー
              // （素材）全体へ一気に適用する操作として直接編集できる
              // ようにする（アニメーション用のキーフレームを個別に
              // 打ちたい場合は引き続きキーフレーム設定シートを使う）。
              StatefulBuilder(
                builder: (ctx, setS) {
                  final current = LayerKeyframeEngine()
                      .valueAt(latest.keyframes, widget.frameIndex)
                      .scale;
                  return LabeledSlider(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    label: l10n.layerKeyframeScaleLabel,
                    labelStyle: const TextStyle(fontSize: 13),
                    value: current,
                    min: 0.1,
                    max: 3.0,
                    divisions: 29,
                    sliderLabel: current.toStringAsFixed(2),
                    onChanged: (v) {
                      setS(() {});
                      update(
                        (l) => l.copyWith(
                          keyframes: _updateKeyframeAtCurrentFrame(
                            l.keyframes,
                            widget.frameIndex,
                            (base) => base.copyWith(scale: v),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              StatefulBuilder(
                builder: (ctx, setS) {
                  final current = LayerKeyframeEngine()
                      .valueAt(latest.keyframes, widget.frameIndex)
                      .rotation;
                  return LabeledSlider(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    label: l10n.layerKeyframeRotationLabel,
                    labelStyle: const TextStyle(fontSize: 13),
                    value: current,
                    min: -180,
                    max: 180,
                    divisions: 360,
                    sliderLabel: '${current.round()}°',
                    onChanged: (v) {
                      setS(() {});
                      update(
                        (l) => l.copyWith(
                          keyframes: _updateKeyframeAtCurrentFrame(
                            l.keyframes,
                            widget.frameIndex,
                            (base) => base.copyWith(rotation: v),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              // ブレンドモード
              ListTile(
                title: Text(l10n.autofillPartBlendModeLabel),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _blendModeName(l10n, layer.blendMode),
                      style: TextStyle(
                        fontSize: 12,
                        color: AccentTextTheme.of(context),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: AccentTextTheme.of(context),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showBlendModeDialog(context, latest, update);
                },
              ),
              SwitchListTile(
                title: Text(l10n.layerPanelLockLabel),
                value: latest.isLocked,
                onChanged: (v) {
                  update((l) => l.copyWith(isLocked: v));
                  Navigator.pop(ctx);
                },
              ),
              SwitchListTile(
                title: Text(l10n.layerPanelOpacityLockLabel),
                value: latest.opacityLocked,
                onChanged: (v) {
                  update((l) => l.copyWith(opacityLocked: v));
                  Navigator.pop(ctx);
                },
              ),
              SwitchListTile(
                title: Text(l10n.layerPanelClippingBadge),
                subtitle: Text(
                  l10n.layerPanelClippingDescription,
                  style: const TextStyle(fontSize: 11),
                ),
                value: latest.hasClipping,
                onChanged: (v) {
                  update((l) => l.copyWith(hasClipping: v));
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.animation_outlined),
                title: Text(l10n.layerPanelKeyframeLabel),
                trailing: layer.keyframes.isEmpty
                    ? null
                    : Icon(
                        Icons.diamond,
                        size: 14,
                        color: AccentTextTheme.of(context),
                      ),
                onTap: () {
                  Navigator.pop(ctx);
                  final tm = context.read<ProjectService>().tileManagerOf(
                    widget.projectId,
                  );
                  showLayerKeyframeSheet(
                    context,
                    layer: layer,
                    projects: context.read<ProjectService>(),
                    projectId: widget.projectId,
                    sceneId: widget.sceneId,
                    currentFrame: widget.frameIndex,
                    totalFrames:
                        context
                            .read<ProjectService>()
                            .sceneOf(widget.projectId, widget.sceneId)
                            ?.frames
                            .length ??
                        1,
                    canvasWidth: tm.canvasWidth,
                    canvasHeight: tm.canvasHeight,
                    onChanged: (kfs) =>
                        update((l) => l.copyWith(keyframes: kfs)),
                  );
                },
              ),
              Builder(
                builder: (context) {
                  final group = context
                      .read<ProjectService>()
                      .groupContainingLayer(
                        widget.projectId,
                        widget.sceneId,
                        layer.id,
                      );
                  if (group == null) return const SizedBox.shrink();
                  return ListTile(
                    leading: const Icon(Icons.workspaces_outline),
                    title: Text(
                      l10n.layerPanelGroupMembershipLabel(group.name),
                    ),
                    trailing: TextButton(
                      onPressed: () {
                        final ps = context.read<ProjectService>();
                        final remaining = group.memberLayerIds
                            .where((id) => id != layer.id)
                            .toList();
                        if (remaining.isEmpty) {
                          ps.removeLayerGroup(
                            widget.projectId,
                            widget.sceneId,
                            group.id,
                          );
                        } else {
                          ps.updateLayerGroup(
                            widget.projectId,
                            widget.sceneId,
                            group.copyWith(memberLayerIds: remaining),
                          );
                        }
                        Navigator.pop(ctx);
                      },
                      child: Text(l10n.layerPanelGroupLeaveAction),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      final tm = context.read<ProjectService>().tileManagerOf(
                        widget.projectId,
                      );
                      showLayerGroupKeyframeSheet(
                        context,
                        projects: context.read<ProjectService>(),
                        projectId: widget.projectId,
                        sceneId: widget.sceneId,
                        groupId: group.id,
                        groupName: group.name,
                        initialKeyframes: group.keyframes,
                        currentFrame: widget.frameIndex,
                        totalFrames:
                            context
                                .read<ProjectService>()
                                .sceneOf(widget.projectId, widget.sceneId)
                                ?.frames
                                .length ??
                            1,
                        canvasWidth: tm.canvasWidth,
                        canvasHeight: tm.canvasHeight,
                        onChanged: (kfs) =>
                            context.read<ProjectService>().updateLayerGroup(
                              widget.projectId,
                              widget.sceneId,
                              group.copyWith(keyframes: kfs),
                            ),
                      );
                    },
                  );
                },
              ),
              if (layer.type == model.LayerType.normal)
                ListTile(
                  leading: Icon(
                    Icons.link,
                    color: ThemeService.activeAccentText,
                  ),
                  title: Text(l10n.layerPanelConvertToCommonLabel),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showConvertToCommonDialog(context, layer);
                  },
                ),
              // 明度で透過：下描きレイヤーに誤って線画を描いてしまった時などに、
              // 白い部分ほど透明になるようレイヤーの不透明度を作り直す
              // 色を保つ「カラー」と、輝度だけで単純に
              // 透過させる「グレー」の2種類。画素の差分を履歴に残す。
              if (layer.type == model.LayerType.normal)
                ListTile(
                  leading: const Icon(Icons.opacity),
                  title: Text(l10n.layerPanelBrightnessToAlphaLabel),
                  subtitle: Text(
                    l10n.layerPanelBrightnessToAlphaHint,
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _applyBrightnessToAlpha(
                            context,
                            layer,
                            grayMode: false,
                          );
                        },
                        child: Text(
                          l10n.layerPanelBrightnessToAlphaColorButton,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _applyBrightnessToAlpha(
                            context,
                            layer,
                            grayMode: true,
                          );
                        },
                        child: Text(l10n.layerPanelBrightnessToAlphaGrayButton),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ).clipListInk(),
      ),
    );
  }

  /// 「明度で透過」を実行し、サムネイル・プレビューを更新する。
  Future<void> _applyBrightnessToAlpha(
    BuildContext context,
    model.Layer layer, {
    required bool grayMode,
  }) async {
    final projectService = context.read<ProjectService>();
    await projectService.applyBrightnessToAlpha(
      projectId: widget.projectId,
      sceneId: widget.sceneId,
      frameIndex: widget.frameIndex,
      layerId: layer.id,
      grayMode: grayMode,
      selection: widget.selectionMask,
    );
    if (!mounted) return;
    setState(
      () => _thumbRevision[layer.id] = (_thumbRevision[layer.id] ?? 0) + 1,
    );
  }

  /// 共通レイヤー化ダイアログ。「現在レイヤーを共通化」／
  /// 「表示中レイヤーを複製して全統合して共通化」の2択→表示範囲設定→変換実行。
  void _showConvertToCommonDialog(BuildContext context, model.Layer layer) {
    final l10n = AppLocalizations.of(context)!;
    int selected = 0;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(l10n.layerPanelConvertToCommonLabel),
          // 選択状態と変更通知はRadioGroupがまとめて持つ
          // （groupValue/onChangedはFlutter 3.32で非推奨）。
          content: RadioGroup<int>(
            groupValue: selected,
            onChanged: (v) => setS(() => selected = v!),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<int>(
                  title: Text(l10n.layerPanelConvertOption1Title),
                  subtitle: Text(
                    l10n.layerPanelConvertOption1Subtitle,
                    style: const TextStyle(fontSize: 11),
                  ),
                  value: 0,
                ),
                RadioListTile<int>(
                  title: Text(l10n.layerPanelConvertOption2Title),
                  subtitle: Text(
                    l10n.layerPanelConvertOption2Subtitle,
                    style: const TextStyle(fontSize: 11),
                  ),
                  value: 1,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                final placeholder = model.Layer(
                  id: '',
                  name: '',
                  type: model.LayerType.common,
                );
                _showRangeChangeDialog(
                  context,
                  placeholder,
                  title: l10n.layerPanelCommonRangeTitle,
                  confirmLabel: l10n.commonCreate,
                  onConfirm: (mode, start, end, rangeSceneId) {
                    final ps = context.read<ProjectService>();
                    if (selected == 0) {
                      ps.convertLayerToCommon(
                        projectId: widget.projectId,
                        sceneId: widget.sceneId,
                        frameIndex: widget.frameIndex,
                        layer: layer,
                        rangeMode: mode,
                        rangeStart: start,
                        rangeEnd: end,
                        rangeSceneId: rangeSceneId,
                      );
                    } else {
                      ps.addFlattenedCommonLayer(
                        projectId: widget.projectId,
                        sceneId: widget.sceneId,
                        frameIndex: widget.frameIndex,
                        rangeMode: mode,
                        rangeStart: start,
                        rangeEnd: end,
                        rangeSceneId: rangeSceneId,
                      );
                    }
                    setState(() => _selectedIndex = 0);
                  },
                );
              },
              child: Text(l10n.commonOk),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBlendModeDialog(
    BuildContext context,
    model.Layer layer,
    void Function(model.Layer Function(model.Layer)) update,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final projects = context.read<ProjectService>();
    final project = projects.projects
        .where((p) => p.id == widget.projectId)
        .firstOrNull;
    final exportWidth = project?.exportWidth ?? 0;
    final exportHeight = project?.exportHeight ?? 0;
    // Two columns of tiles, each mode's name above a large picture of its
    // look; the tapped mode shows on this frame above them.
    final mode = await showBlendModePicker(
      context,
      current: layer.blendMode,
      title: l10n.autofillPartBlendModeLabel,
      label: (mode) => _blendModeName(l10n, mode),
      preview: (mode, maxSize) => compositeFrameThumbnail(
        projects,
        projectId: widget.projectId,
        sceneId: widget.sceneId,
        frameIndex: widget.frameIndex,
        maxSize: maxSize,
        editLayers: (layers) => [
          for (final l in layers)
            l.id == layer.id ? l.copyWith(blendMode: mode) : l,
        ],
      ),
      previewBackground: project?.backgroundColor ?? 0xFFFFFFFF,
      previewAspectRatio: exportWidth > 0 && exportHeight > 0
          ? exportWidth / exportHeight
          : 16 / 9,
    );
    if (mode != null) update((l) => l.copyWith(blendMode: mode));
  }

  String _blendModeName(AppLocalizations l10n, model.LayerBlendMode mode) =>
      blendModeLabel(l10n, mode);

  void _showHelp(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        // popup-standard-close: タイトル行の右端へ寄せた閉じるボタン。
        // AlertDialogの`icon:`スロットへ入れると、Flutterが
        // タイトルを強制的に中央寄せにするため（dialog.dartの
        // `textAlign: icon == null ? TextAlign.start : TextAlign.center`）、
        // 他のダイアログと不揃いになる。タイトル行へ直接置くこと。
        title: Row(
          children: [
            Expanded(child: Text(l10n.layerPanelHelpDialogTitle)),
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.autofillPartBlendModeLabel,
                style: localizedHeadingStyle(
                  context,
                  const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(l10n.layerPanelHelpBlendModeBody),
              const SizedBox(height: 8),
              Text(
                l10n.layerPanelClippingBadge,
                style: localizedHeadingStyle(
                  context,
                  const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(l10n.layerPanelHelpClippingBody),
              const SizedBox(height: 8),
              Text(
                l10n.layerPanelCommonLayerLabel,
                style: localizedHeadingStyle(
                  context,
                  const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(l10n.layerPanelHelpCommonLayerBody),
            ],
          ),
        ),
      ),
    );
  }

  /// [layer] は警告アイコンが表示された自動塗りレイヤー、または三点メニューから起動した場合は
  /// 自動塗り用線画レイヤー（[isLineartLayer]=true）。実行対象の線画レイヤーを特定してから
  /// ダイアログを表示する。
  void _showAutofillDialog(
    BuildContext context,
    model.Layer layer, {
    bool isLineartLayer = false,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final projectService = context.read<ProjectService>();
    final allLayers = projectService.layersOf(
      widget.projectId,
      widget.sceneId,
      widget.frameIndex,
    );
    model.Layer? lineartLayer;
    if (isLineartLayer) {
      lineartLayer = layer;
    } else {
      final idx = allLayers.indexWhere((l) => l.id == layer.id);
      if (idx > 0 &&
          allLayers[idx - 1].type == model.LayerType.autoFillLineart) {
        lineartLayer = allLayers[idx - 1];
      }
    }
    if (lineartLayer == null) {
      // 線画レイヤーを削除して自動塗りレイヤーのみが残っている場合（
      // 「線画レイヤーなし・塗りレイヤーあり」の状態）は、参照する線画が無いため
      // 領域の再判定はできない。不透明度ロック＋最新色での塗りつぶしのみを行う。
      if (layer.type == model.LayerType.autoFill && layer.partId != null) {
        _runOrphanedAutofill(context, layer);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.layerPanelAutofillNoLineartSnackbar)),
      );
      return;
    }
    final resolvedLineart = lineartLayer;
    int selected = 0;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(l10n.layerPanelAutofillMethodTitle),
          // 選択状態と変更通知はRadioGroupがまとめて持つ
          // （groupValue/onChangedはFlutter 3.32で非推奨）。
          content: RadioGroup<int>(
            groupValue: selected,
            onChanged: (v) => setS(() => selected = v!),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.layerPanelAutofillNote1,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.layerPanelAutofillNote2,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                RadioListTile<int>(
                  title: Text(l10n.layerPanelAutofillSmartUpdateTitle),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.layerPanelAutofillSmartUpdateHint,
                        style: const TextStyle(fontSize: 11),
                      ),
                      Text(
                        l10n.layerPanelAutofillSmartUpdateNote,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                  value: 0,
                  dense: true,
                ),
                RadioListTile<int>(
                  title: Text(l10n.layerPanelAutofillRepaintTitle),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.layerPanelAutofillRepaintHint,
                        style: const TextStyle(fontSize: 11),
                      ),
                      Text(
                        l10n.layerPanelAutofillRepaintNote,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                  value: 1,
                  dense: true,
                ),
                RadioListTile<int>(
                  title: Text(l10n.layerPanelAutofillColorUpdateTitle),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.layerPanelAutofillColorUpdateHint,
                        style: const TextStyle(fontSize: 11),
                      ),
                      Text(
                        l10n.layerPanelAutofillColorUpdateNote,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                  value: 2,
                  dense: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _executeAutofill(context, resolvedLineart, switch (selected) {
                  1 => autofill.AutofillMode.repaint,
                  2 => autofill.AutofillMode.colorUpdate,
                  _ => autofill.AutofillMode.smartUpdate,
                });
              },
              child: Text(l10n.layerPanelExecuteButton),
            ),
          ],
        ),
      ),
    );
  }

  /// 自動塗りエンジンを実行し、結果を対象自動塗りレイヤーのタイルへ書き戻す
  /// 本処理自体はautofill_batch_runner.dart（タイムラインの
  /// 一括実行とも共通）に集約し、ここではUI固有のエラー案内のみ行う。
  Future<void> _executeAutofill(
    BuildContext context,
    model.Layer lineartLayer,
    autofill.AutofillMode mode,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    if (lineartLayer.partId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.layerPanelAutofillPartMissingSnackbar)),
      );
      return;
    }
    if (context.read<AutofillPresetService>().findPart(lineartLayer.partId!) ==
        null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.layerPanelAutofillPresetMissingSnackbar)),
      );
      return;
    }
    await runAutofillForLayer(
      projectService: context.read<ProjectService>(),
      presetService: context.read<AutofillPresetService>(),
      toneService: context.read<ToneService>(),
      projectId: widget.projectId,
      sceneId: widget.sceneId,
      frameIndex: widget.frameIndex,
      lineartLayer: lineartLayer,
      selection: widget.selectionMask,
      mode: mode,
    );
    if (mounted) setState(() {});
  }

  /// 対応する自動塗り用線画レイヤーが存在しない自動塗りレイヤー（線画レイヤーを
  /// 削除した後に残った状態）を処理する。
  /// 「線画レイヤーなし・塗りレイヤーあり」の行。参照する線画が無いため
  /// 領域の再判定はできず、不透明度ロック＋最新色での塗りつぶしのみを行う
  /// （モード選択の余地がないため確認ダイアログは出さず直接実行する）。
  Future<void> _runOrphanedAutofill(
    BuildContext context,
    model.Layer autofillLayer,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final projectService = context.read<ProjectService>();
    final presetService = context.read<AutofillPresetService>();
    final result = await runAutofillForOrphanedLayer(
      projectService: projectService,
      presetService: presetService,
      projectId: widget.projectId,
      sceneId: widget.sceneId,
      frameIndex: widget.frameIndex,
      autofillLayer: autofillLayer,
      selection: widget.selectionMask,
    );
    if (!context.mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == AutofillBatchResult.applied
              ? l10n.layerPanelOrphanFillSuccessSnackbar
              : l10n.layerPanelOrphanFillFailSnackbar,
        ),
      ),
    );
  }

  /// 自動塗り用線画レイヤーへプリセットパーツを割り当てるダイアログ（パーツID管理）。
  void _showPartAssignDialog(BuildContext context, model.Layer lineartLayer) {
    final l10n = AppLocalizations.of(context)!;
    final allPresets = context.read<AutofillPresetService>().presets;
    // プロジェクトごとに使用するプリセットが絞り込まれている場合は、その
    // プリセットのみを表示する（プリセットが増えるほど
    // パーツ割り当て時の一覧が長くなるため）。未設定（null）の場合は従来
    // 通りすべて表示する。
    final project = context
        .read<ProjectService>()
        .projects
        .where((p) => p.id == widget.projectId)
        .firstOrNull;
    final presets = enabledAutofillPresets(
      allPresets,
      project?.enabledAutofillPresetIds,
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: 400,
          child: presets.isEmpty
              ? Center(child: Text(l10n.autofillPresetEmpty))
              : ListView(
                  children: [
                    for (final preset in presets) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          preset.displayName(l10n),
                          style: localizedHeadingStyle(
                            context,
                            const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      for (final part in preset.parts)
                        ListTile(
                          dense: true,
                          leading: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Color(part.color),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: ThemeService
                                    .activeColorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                          title: Text(part.displayName(l10n)),
                          selected: lineartLayer.partId == part.id,
                          onTap: () {
                            context.read<ProjectService>().assignAutofillPart(
                              projectId: widget.projectId,
                              sceneId: widget.sceneId,
                              frameIndex: widget.frameIndex,
                              lineartLayerId: lineartLayer.id,
                              partId: part.id,
                              partName: part.name,
                            );
                            Navigator.pop(ctx);
                          },
                        ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  void _showAutofillUpdateHelp(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        // popup-standard-close: タイトル行の右端へ寄せた閉じるボタン。
        // AlertDialogの`icon:`スロットへ入れると、Flutterが
        // タイトルを強制的に中央寄せにするため（dialog.dartの
        // `textAlign: icon == null ? TextAlign.start : TextAlign.center`）、
        // 他のダイアログと不揃いになる。タイトル行へ直接置くこと。
        title: Row(
          children: [
            Expanded(child: Text(l10n.layerPanelAutofillUpdateHelpTitle)),
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        content: Text(l10n.layerPanelAutofillUpdateHelpBody),
      ),
    );
  }

  /// 画像を選択し、キャンバスサイズへアスペクト比維持で中央フィットさせて
  /// ラスタライズし、通常レイヤーとして追加する（画像読み込みは
  /// タイムライン素材ではなく描画レイヤーとして扱う）。
  /// レイヤーのピクセル内容を新しい画像で丸ごと差し替える（位置・トランスフォームは
  /// 維持したまま、キャンバス全体に収まるよう中央寄せ・アスペクト比維持で描き直す）。
  Future<void> _replaceMaterial(BuildContext context, model.Layer layer) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    final image = frame.image;
    if (!context.mounted) {
      image.dispose();
      return;
    }

    final projectService = context.read<ProjectService>();
    final tileManager = projectService.tileManagerOf(widget.projectId);
    final w = tileManager.canvasWidth;
    final h = tileManager.canvasHeight;

    final scale = math.min(w / image.width, h / image.height);
    final drawW = image.width * scale;
    final drawH = image.height * scale;
    final dx = (w - drawW) / 2;
    final dy = (h - drawH) / 2;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      ui.Rect.fromLTWH(dx, dy, drawW, drawH),
      ui.Paint(),
    );
    final picture = recorder.endRecording();
    final rendered = await picture.toImage(w, h);
    image.dispose();
    final byteData = await rendered.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    rendered.dispose();
    if (byteData == null || !context.mounted) return;

    projectService.replaceLayerPixels(
      projectId: widget.projectId,
      sceneId: widget.sceneId,
      frameIndex: widget.frameIndex,
      layerId: layer.id,
      pixels: byteData.buffer.asUint8List(),
      selection: widget.selectionMask,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.layerPanelReplaceMaterialSuccessSnackbar(layer.name),
        ),
      ),
    );
  }

  Future<void> _importImage(BuildContext context) async {
    final selection = widget.selectionMask;
    final l10n = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final path = file.path;
    if (path == null) return;
    final name = file.name.replaceAll(RegExp(r'\.[^.]+$'), '');

    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    final image = frame.image;
    if (!context.mounted) {
      image.dispose();
      return;
    }

    final projectService = context.read<ProjectService>();
    final tileManager = projectService.tileManagerOf(widget.projectId);
    final w = tileManager.canvasWidth;
    final h = tileManager.canvasHeight;

    final scale = math.min(w / image.width, h / image.height);
    final drawW = image.width * scale;
    final drawH = image.height * scale;
    final dx = (w - drawW) / 2;
    final dy = (h - drawH) / 2;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      ui.Rect.fromLTWH(dx, dy, drawW, drawH),
      ui.Paint(),
    );
    final picture = recorder.endRecording();
    final rendered = await picture.toImage(w, h);
    image.dispose();
    final byteData = await rendered.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    rendered.dispose();
    if (byteData == null || !context.mounted) return;

    if (!identical(
      tileManager,
      projectService.tileManagerOf(widget.projectId),
    )) {
      return;
    }
    projectService.editTimeline(widget.projectId, 'Import image layer', () {
      final layer = projectService.addLayer(
        projectId: widget.projectId,
        sceneId: widget.sceneId,
        frameIndex: widget.frameIndex,
        type: model.LayerType.normal,
        name: name,
      );
      tileManager.replaceLayerPixels(
        frameLayerKey(widget.sceneId, widget.frameIndex, layer.id),
        byteData.buffer.asUint8List(),
        selection: selection,
      );
      projectService.refreshDrawingHistory(widget.projectId);
    });
    setState(() => _selectedIndex = 0);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.layerPanelImportImageSuccessSnackbar(name))),
    );
  }

  void _openLayerFullscreenPreview(model.Layer layer, int backgroundColor) {
    showDialog<void>(
      context: context,
      useSafeArea: false,
      builder: (_) => Dialog.fullscreen(
        child: _LayerFullscreenPreview(
          projectId: widget.projectId,
          sceneId: widget.sceneId,
          frameIndex: widget.frameIndex,
          layerId: layer.id,
          layerName: layer.name,
          backgroundColor: backgroundColor,
          layerOpacity: layer.opacity,
        ),
      ),
    );
  }
}

/// 描画の表示/非表示に関係なく、このレイヤーだけを原寸データから
/// 読み込み、全画面でピンチ拡大・縮小とドラッグ移動を提供する。
class _LayerFullscreenPreview extends StatefulWidget {
  const _LayerFullscreenPreview({
    required this.projectId,
    required this.sceneId,
    required this.frameIndex,
    required this.layerId,
    required this.layerName,
    required this.backgroundColor,
    required this.layerOpacity,
  });

  final String projectId;
  final String sceneId;
  final int frameIndex;
  final String layerId;
  final String layerName;
  final int backgroundColor;
  final int layerOpacity;

  @override
  State<_LayerFullscreenPreview> createState() =>
      _LayerFullscreenPreviewState();
}

class _LayerFullscreenPreviewState extends State<_LayerFullscreenPreview> {
  ui.Image? _image;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final ps = context.read<ProjectService>();
      final key = ps.tileKeyFor(
        widget.projectId,
        widget.sceneId,
        widget.frameIndex,
        widget.layerId,
      );
      // Full resolution; do not scale up the 48px list thumbnail.
      final image = await ps
          .tileManagerOf(widget.projectId)
          .compositeLayerToImage(key);
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() => _image = image);
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.layerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const ValueKey('layer-preview-close'),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: image == null
                ? Center(
                    child: _loadError == null
                        ? const CircularProgressIndicator()
                        : Text(_loadError.toString()),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final iw = image.width.toDouble();
                      final ih = image.height.toDouble();
                      final fitScale = math.min(
                        constraints.maxWidth / iw,
                        constraints.maxHeight / ih,
                      );
                      return InteractiveViewer(
                        key: const ValueKey('layer-preview-interactive'),
                        constrained: false,
                        alignment: Alignment.center,
                        minScale: 0.25,
                        maxScale: 8,
                        boundaryMargin: const EdgeInsets.all(256),
                        panEnabled: true,
                        scaleEnabled: true,
                        child: SizedBox(
                          width: iw * fitScale,
                          height: ih * fitScale,
                          child: ColoredBox(
                            color: Color(widget.backgroundColor),
                            child: Opacity(
                              opacity: (widget.layerOpacity / 100).clamp(
                                0.0,
                                1.0,
                              ),
                              child: RawImage(image: image, fit: BoxFit.fill),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// レイヤー一覧の各行に表示するサムネイル。
///
/// `TileManager.compositeLayerToImage()`は合成結果を内部キャッシュして
/// おり、対象レイヤーのタイルに変更が無ければ再合成せずキャッシュ済み
/// 画像のclone()を返す。そのため呼び出し自体は軽量で、実際に重い
/// フル合成が走るのは対象レイヤーへ描画があった直後のみ。
///
/// 初回表示時に一度だけ生成しキャッシュする。以降の更新は
/// [_LayerPanelState]がストローク確定（UndoManagerのpush）を検知して
/// 現在選択中のレイヤーのみキーを変えて再生成させる仕組みに任せる
/// （「サムネイルはペンを離した瞬間に現在レイヤーのみ更新する」）。
class _LayerThumbnail extends StatefulWidget {
  final String projectId;
  final String sceneId;
  final int frameIndex;
  final String layerId;
  final int backgroundColor;
  final int layerOpacity;

  const _LayerThumbnail({
    super.key,
    required this.projectId,
    required this.sceneId,
    required this.frameIndex,
    required this.layerId,
    required this.backgroundColor,
    required this.layerOpacity,
  });

  @override
  State<_LayerThumbnail> createState() => _LayerThumbnailState();
}

class _LayerThumbnailState extends State<_LayerThumbnail> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    final ps = context.read<ProjectService>();
    final tileManager = ps.tileManagerOf(widget.projectId);
    final key = ps.tileKeyFor(
      widget.projectId,
      widget.sceneId,
      widget.frameIndex,
      widget.layerId,
    );
    // Render this layer's actual raster tiles over the PROJECT'S paper
    // colour. A transparent layer alone would otherwise look like the
    // palette's grey placeholder and fail to show the intended result.
    final full = await tileManager.compositeLayerToImage(key);
    ui.Image thumb;
    try {
      thumb = await renderLayerThumbnail(
        full,
        backgroundColor: widget.backgroundColor,
        opacity: widget.layerOpacity,
        size: 48,
      );
    } finally {
      full.dispose();
    }
    if (!mounted) {
      thumb.dispose();
      return;
    }
    final old = _image;
    setState(() => _image = thumb);
    old?.dispose();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return Container(
      width: 24,
      height: 24,
      color: Color(widget.backgroundColor),
      child: image == null ? null : RawImage(image: image, fit: BoxFit.contain),
    );
  }
}

/// レイヤーの行の右の操作（︙・結合・削除・並べ替え）の押せる所。
///
/// 印は16pxのまま、印の間の隙間（以前は8pxずつの空白）を押せる所に含めて
/// 22×40にする。並びの幅は以前（印16px＋隙間8px）と同じなので名前の欄は
/// 狭くならず、印と印の間を押しても何も起きない・行を選んでしまう、が無くなる。
class _RowActionTarget extends StatelessWidget {
  const _RowActionTarget({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 22, height: 40, child: Center(child: child));
}
