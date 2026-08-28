import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'help_diagrams.dart';

class HelpScreen extends StatefulWidget {
  // 各画面のヘルプボタンから「この画面に関連する項目」を指定して開いた
  // 場合のトピック名（_HelpEntry.topicKeyと一致させる）。指定されると検索欄に
  // 自動入力され、該当項目が自動展開された状態で表示される。
  // topicKeyは表示言語に関わらず固定の日本語文字列（HelpButton(topic:)の
  // 呼び出し元と一致させるための内部識別子であり、翻訳対象外）。
  final String? initialTopic;
  const HelpScreen({super.key, this.initialTopic});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final topic = widget.initialTopic;
    if (topic != null && topic.isNotEmpty) {
      _searchQuery = topic;
      _searchController.text = topic;
    }
  }

  // ヘルプの説明文は、チュートリアル（初回タップ時に出る短い吹き出し）とは
  // 別の役割を持つ。チュートリアルは「今何をタップすればいいか」を一瞬で
  // 伝えるためのものだが、ここでは初めてこのアプリに触れる人でも読むだけで
  // その機能の意味・使いどころ・注意点まで理解できることを目指し、
  // あえて長文になっても詳しく説明する。
  //
  // topicKeyは各画面のHelpButton(topic: '...')呼び出しと一致させる必要が
  // あるため、表示言語に関わらず固定の日本語文字列のまま維持する
  // （翻訳対象は title/description/category のみ）。
  List<_HelpEntry> _buildEntries(AppLocalizations l10n) => [
        // ── 描画ツール ──────────────────────────────────────────
        _HelpEntry(topicKey: 'ペンツール', title: l10n.helpPenToolTitle, description: l10n.helpPenToolDesc, category: l10n.helpCategoryTool, diagram: const HelpDiagramSpec(HelpScreenTemplate.toolbarRow, 0)),
        _HelpEntry(topicKey: '消しゴムツール', title: l10n.helpEraserToolTitle, description: l10n.helpEraserToolDesc, category: l10n.helpCategoryTool, diagram: const HelpDiagramSpec(HelpScreenTemplate.toolbarRow, 1)),
        _HelpEntry(topicKey: 'バケツツール', title: l10n.helpBucketToolTitle, description: l10n.helpBucketToolDesc, category: l10n.helpCategoryTool, diagram: const HelpDiagramSpec(HelpScreenTemplate.toolbarRow, 2)),
        _HelpEntry(topicKey: '投げ縄塗り', title: l10n.helpLassoFillTitle, description: l10n.helpLassoFillDesc, category: l10n.helpCategoryTool, diagram: const HelpDiagramSpec(HelpScreenTemplate.toolbarRow, 2)),
        _HelpEntry(topicKey: 'スポイトツール', title: l10n.helpEyedropperToolTitle, description: l10n.helpEyedropperToolDesc, category: l10n.helpCategoryTool, diagram: const HelpDiagramSpec(HelpScreenTemplate.toolbarRow, 3)),
        _HelpEntry(topicKey: '選択ツール', title: l10n.helpSelectToolTitle, description: l10n.helpSelectToolDesc, category: l10n.helpCategoryTool, diagram: const HelpDiagramSpec(HelpScreenTemplate.toolbarRow, 4)),
        _HelpEntry(topicKey: '指ツール（歪みツール）', title: l10n.helpFingerToolTitle, description: l10n.helpFingerToolDesc, category: l10n.helpCategoryTool, diagram: const HelpDiagramSpec(HelpScreenTemplate.toolbarRow, 5)),
        _HelpEntry(topicKey: '図形ツール', title: l10n.helpShapeToolTitle, description: l10n.helpShapeToolDesc, category: l10n.helpCategoryTool, diagram: const HelpDiagramSpec(HelpScreenTemplate.toolbarRow, 6)),
        // フォント管理の説明は、独立項目にせずこちらへ統合済み。
        // font_settings_screen.dartのHelpButtonが'テキストツール'を参照する
        // よう合わせて変更済み。
        _HelpEntry(topicKey: 'テキストツール', title: l10n.helpTextToolTitle, description: l10n.helpTextToolDesc, category: l10n.helpCategoryTool, diagram: const HelpDiagramSpec(HelpScreenTemplate.toolbarRow, 6, icon: Icons.text_fields)),
        _HelpEntry(topicKey: '早替えツール', title: l10n.helpQuickToolTitle, description: l10n.helpQuickToolDesc, category: l10n.helpCategoryTool, diagram: const HelpDiagramSpec(HelpScreenTemplate.toolbarRow, 5, icon: Icons.restart_alt)),
        // スタンプの回転・拡大縮小の説明は、独立項目にせずこちらへ統合済み。
        _HelpEntry(topicKey: 'スタンプツール', title: l10n.helpStampToolTitle, description: l10n.helpStampToolDesc, category: l10n.helpCategoryTool, diagram: const HelpDiagramSpec(HelpScreenTemplate.floatingPanel, 1)),
        _HelpEntry(topicKey: 'ペンサブツール', title: l10n.helpPenSubToolTitle, description: l10n.helpPenSubToolDesc, category: l10n.helpCategoryTool, diagram: const HelpDiagramSpec(HelpScreenTemplate.floatingPanel, 1)),
        _HelpEntry(topicKey: '選択範囲の変形', title: l10n.helpTransformSelectionTitle, description: l10n.helpTransformSelectionDesc, category: l10n.helpCategoryTool, diagram: const HelpDiagramSpec(HelpScreenTemplate.toolbarRow, 4)),
        // 選択範囲の変形と対になる機能。
        _HelpEntry(topicKey: '自由変形・メッシュ変形', title: l10n.helpMeshTransformTitle, description: l10n.helpMeshTransformDesc, category: l10n.helpCategoryTool, diagram: const HelpDiagramSpec(HelpScreenTemplate.topBar, 3)),
        _HelpEntry(topicKey: 'カラーピッカー', title: l10n.helpColorPickerTitle, description: l10n.helpColorPickerDesc, category: l10n.helpCategoryTool, diagram: const HelpDiagramSpec(HelpScreenTemplate.floatingPanel, 3)),
        _HelpEntry(topicKey: 'ブラシのお気に入り', title: l10n.helpBrushFavoriteTitle, description: l10n.helpBrushFavoriteDesc, category: l10n.helpCategoryBrush, diagram: const HelpDiagramSpec(HelpScreenTemplate.floatingPanel, 1)),
        _HelpEntry(topicKey: 'カスタムブラシ', title: l10n.helpCustomBrushTitle, description: l10n.helpCustomBrushDesc, category: l10n.helpCategoryBrush, diagram: const HelpDiagramSpec(HelpScreenTemplate.floatingPanel, 1)),

        // ── レイヤー ────────────────────────────────────────────
        _HelpEntry(topicKey: 'レイヤー', title: l10n.helpLayerTitle, description: l10n.helpLayerDesc, category: l10n.helpCategoryLayer, diagram: const HelpDiagramSpec(HelpScreenTemplate.layerPanelList, 0)),
        _HelpEntry(topicKey: 'ブレンドモード', title: l10n.helpBlendModeTitle, description: l10n.helpBlendModeDesc, category: l10n.helpCategoryLayer, diagram: const HelpDiagramSpec(HelpScreenTemplate.layerPanelList, 1)),
        // layerPanelListの行アイコン配列は[通常レイヤー,フォルダ,共通レイヤー,
        // 自動塗り]の順（help_diagrams.dart _layerTypeIcons）。各項目の
        // スロット番号は実際のアイコンと一致させている。
        _HelpEntry(topicKey: 'クリッピング', title: l10n.helpClippingTitle, description: l10n.helpClippingDesc, category: l10n.helpCategoryLayer, diagram: const HelpDiagramSpec(HelpScreenTemplate.layerPanelList, 1, icon: Icons.content_cut)),
        // 「レイヤーの共通化」の説明は、独立項目にせずこちらへ統合済み。
        _HelpEntry(topicKey: '共通レイヤー', title: l10n.helpCommonLayerTitle, description: l10n.helpCommonLayerDesc, category: l10n.helpCategoryLayer, diagram: const HelpDiagramSpec(HelpScreenTemplate.layerPanelList, 2)),
        _HelpEntry(topicKey: 'レイヤーフォルダ', title: l10n.helpLayerFolderTitle, description: l10n.helpLayerFolderDesc, category: l10n.helpCategoryLayer, diagram: const HelpDiagramSpec(HelpScreenTemplate.layerPanelList, 0, icon: Icons.folder_outlined)),
        // 自動塗り実行・自動塗りの線画色設定・自動塗りプリセット絞り込みの説明は、
        // 独立項目にせずこちらへ統合済み。
        _HelpEntry(topicKey: '自動塗り', title: l10n.helpAutoFillTitle, description: l10n.helpAutoFillDesc, category: l10n.helpCategoryLayer, diagram: const HelpDiagramSpec(HelpScreenTemplate.layerPanelList, 3)),
        _HelpEntry(topicKey: 'グラデーション塗り', title: l10n.helpGradientAutofillTitle, description: l10n.helpGradientAutofillDesc, category: l10n.helpCategoryLayer, diagram: const HelpDiagramSpec(HelpScreenTemplate.layerPanelList, 3)),

        // ── 描画補助 ────────────────────────────────────────────
        _HelpEntry(topicKey: 'オニオンスキン', title: l10n.helpOnionSkinTitle, description: l10n.helpOnionSkinDesc, category: l10n.helpCategoryAnimation, diagram: const HelpDiagramSpec(HelpScreenTemplate.floatingPanel, 3)),
        _HelpEntry(topicKey: '定規', title: l10n.helpRulerTitle, description: l10n.helpRulerDesc, category: l10n.helpCategoryDrawing, diagram: const HelpDiagramSpec(HelpScreenTemplate.floatingPanel, 1)),
        _HelpEntry(topicKey: 'フェード', title: l10n.helpFadeTitle, description: l10n.helpFadeDesc, category: l10n.helpCategoryBrush, diagram: const HelpDiagramSpec(HelpScreenTemplate.floatingPanel, 3)),
        _HelpEntry(topicKey: 'ストローク減衰', title: l10n.helpStrokeDecayTitle, description: l10n.helpStrokeDecayDesc, category: l10n.helpCategoryBrush, diagram: const HelpDiagramSpec(HelpScreenTemplate.floatingPanel, 3)),
        _HelpEntry(topicKey: '混色', title: l10n.helpColorMixingTitle, description: l10n.helpColorMixingDesc, category: l10n.helpCategoryBrush, diagram: const HelpDiagramSpec(HelpScreenTemplate.floatingPanel, 3)),
        _HelpEntry(topicKey: '筆圧カーブ', title: l10n.helpPressureCurveTitle, description: l10n.helpPressureCurveDesc, category: l10n.helpCategoryPenInput, diagram: const HelpDiagramSpec(HelpScreenTemplate.floatingPanel, 3)),
        _HelpEntry(topicKey: 'トーン塗り', title: l10n.helpToneFillTitle, description: l10n.helpToneFillDesc, category: l10n.helpCategoryDrawing, diagram: const HelpDiagramSpec(HelpScreenTemplate.canvasArea, 0)),
        _HelpEntry(topicKey: 'ピクセルモード', title: l10n.helpPixelModeTitle, description: l10n.helpPixelModeDesc, category: l10n.helpCategoryDrawing, diagram: const HelpDiagramSpec(HelpScreenTemplate.canvasArea, 0)),
        // 関連する項目同士が近くに並ぶよう、「その他」にあった描画領域・
        // 背景色の説明をここへ移動。
        _HelpEntry(topicKey: '描画領域', title: l10n.helpDrawingAreaTitle, description: l10n.helpDrawingAreaDesc, category: l10n.helpCategoryDrawing, diagram: const HelpDiagramSpec(HelpScreenTemplate.canvasArea, 0)),
        _HelpEntry(topicKey: 'キャンバスの背景色', title: l10n.helpCanvasBackgroundTitle, description: l10n.helpCanvasBackgroundDesc, category: l10n.helpCategoryDrawing, diagram: const HelpDiagramSpec(HelpScreenTemplate.canvasArea, 0)),

        // ── タイムライン・アニメーション ──────────────────────────
        _HelpEntry(topicKey: 'タイムライン', title: l10n.helpTimelineTitle, description: l10n.helpTimelineDesc, category: l10n.helpCategoryAnimation, diagram: const HelpDiagramSpec(HelpScreenTemplate.timelineTrack, 2)),
        _HelpEntry(topicKey: 'シーン', title: l10n.helpSceneTitle, description: l10n.helpSceneDesc, category: l10n.helpCategoryAnimation, diagram: const HelpDiagramSpec(HelpScreenTemplate.timelineTrack, 0)),
        _HelpEntry(topicKey: 'フレーム操作', title: l10n.helpFrameOperationsTitle, description: l10n.helpFrameOperationsDesc, category: l10n.helpCategoryAnimation, diagram: const HelpDiagramSpec(HelpScreenTemplate.timelineTrack, 2)),
        _HelpEntry(topicKey: '素材クリップ', title: l10n.helpMaterialClipTitle, description: l10n.helpMaterialClipDesc, category: l10n.helpCategoryAnimation, diagram: const HelpDiagramSpec(HelpScreenTemplate.timelineTrack, 3)),
        _HelpEntry(topicKey: '素材一覧', title: l10n.helpMaterialListTitle, description: l10n.helpMaterialListDesc, category: l10n.helpCategoryAnimation, diagram: const HelpDiagramSpec(HelpScreenTemplate.cardGrid, 1, icon: Icons.perm_media_outlined)),
        _HelpEntry(topicKey: '音声クリップ', title: l10n.helpAudioClipTitle, description: l10n.helpAudioClipDesc, category: l10n.helpCategoryAnimation, diagram: const HelpDiagramSpec(HelpScreenTemplate.timelineTrack, 4, icon: Icons.audiotrack)),
        _HelpEntry(topicKey: 'カメラキーフレーム', title: l10n.helpCameraKeyframeTitle, description: l10n.helpCameraKeyframeDesc, category: l10n.helpCategoryAnimation, diagram: const HelpDiagramSpec(HelpScreenTemplate.timelineTrack, 1, icon: Icons.videocam)),
        // 演出フィルターの適用順・動くノイズフィルター・雨フィルターの説明は、
        // 独立項目にせずこちらへ統合済み（個々のフィルターを独立項目に
        // せず「演出フィルター」の親項目内へまとめる）。
        _HelpEntry(topicKey: '演出フィルター', title: l10n.helpEffectFilterTitle, description: l10n.helpEffectFilterDesc, category: l10n.helpCategoryAnimation, diagram: const HelpDiagramSpec(HelpScreenTemplate.timelineTrack, 1)),
        _HelpEntry(topicKey: '描画フィルター', title: l10n.helpDrawingFilterTitle, description: l10n.helpDrawingFilterDesc, category: l10n.helpCategoryDrawing, diagram: const HelpDiagramSpec(HelpScreenTemplate.floatingPanel, 1)),
        _HelpEntry(topicKey: 'レイヤーキーフレーム', title: l10n.helpLayerKeyframeTitle, description: l10n.helpLayerKeyframeDesc, category: l10n.helpCategoryAnimation, diagram: const HelpDiagramSpec(HelpScreenTemplate.timelineTrack, 1)),
        // layerPanelListのスロット2＝共通レイヤーアイコン（groups_outlined）が
        // 「グループ」の名前的にも近いため使う。
        _HelpEntry(topicKey: 'レイヤーグループ', title: l10n.helpLayerGroupTitle, description: l10n.helpLayerGroupDesc, category: l10n.helpCategoryAnimation, diagram: const HelpDiagramSpec(HelpScreenTemplate.layerPanelList, 2)),
        _HelpEntry(topicKey: 'EndCard（エンドロゴ）', title: l10n.helpEndCardTitle, description: l10n.helpEndCardDesc, category: l10n.helpCategoryExport, diagram: const HelpDiagramSpec(HelpScreenTemplate.timelineTrack, 4, icon: Icons.movie_filter_outlined)),

        // ── 保存・プロジェクト管理 ─────────────────────────────────
        _HelpEntry(topicKey: '自動保存', title: l10n.helpAutoSaveTitle, description: l10n.helpAutoSaveDesc, category: l10n.helpCategorySave, diagram: const HelpDiagramSpec(HelpScreenTemplate.saveList, 0)),
        // _saveIcons[2]=bookmark_borderの方が「スロットに留める」イメージに
        // 近いため、履歴アイコン（1、セーブツリー用）とは分けている。
        _HelpEntry(topicKey: 'セーブスロット', title: l10n.helpSaveSlotTitle, description: l10n.helpSaveSlotDesc, category: l10n.helpCategorySave, diagram: const HelpDiagramSpec(HelpScreenTemplate.saveList, 2)),
        _HelpEntry(topicKey: 'セーブツリー', title: l10n.helpSaveTreeTitle, description: l10n.helpSaveTreeDesc, category: l10n.helpCategorySave, diagram: const HelpDiagramSpec(HelpScreenTemplate.saveList, 1)),
        _HelpEntry(topicKey: 'フォルダ', title: l10n.helpFolderTitle, description: l10n.helpFolderDesc, category: l10n.helpCategoryProjectManagement, diagram: const HelpDiagramSpec(HelpScreenTemplate.cardGrid, 0, icon: Icons.folder)),
        _HelpEntry(topicKey: 'ゴミ箱', title: l10n.helpTrashTitle, description: l10n.helpTrashDesc, category: l10n.helpCategoryProjectManagement, diagram: const HelpDiagramSpec(HelpScreenTemplate.cardGrid, 1, icon: Icons.delete_outline)),
        _HelpEntry(topicKey: '共有（.niashare）', title: l10n.helpShareTitle, description: l10n.helpShareDesc, category: l10n.helpCategoryProjectManagement, diagram: const HelpDiagramSpec(HelpScreenTemplate.cardGrid, 2)),
        _HelpEntry(topicKey: '引き継ぎ（.niatra）', title: l10n.helpTransferTitle, description: l10n.helpTransferDesc, category: l10n.helpCategoryProjectManagement, diagram: const HelpDiagramSpec(HelpScreenTemplate.cardGrid, 3, icon: Icons.sync_alt)),

        // ── 書き出し ───────────────────────────────────────────
        // 透過WebM・GIF書き出し・無料会員の尺制限の説明は、独立項目にせず
        // こちらへ統合済み（書き出し関連のヘルプ項目をある程度
        // 1つにまとめる）。topicKeyはexport_screen.dartのHelpButtonが参照して
        // いるため変更していない（表示タイトルのみ範囲を広げた）。
        _HelpEntry(topicKey: '動画書き出し（MP4）', title: l10n.helpVideoExportTitle, description: l10n.helpVideoExportDesc, category: l10n.helpCategoryExport, diagram: const HelpDiagramSpec(HelpScreenTemplate.exportPicker, 0)),
        _HelpEntry(topicKey: '書き出し画面', title: l10n.helpExportScreenTitle, description: l10n.helpExportScreenDesc, category: l10n.helpCategoryExport, diagram: const HelpDiagramSpec(HelpScreenTemplate.exportPicker, 1)),

        // ── コミュニティ ──────────────────────────────────────────
        _HelpEntry(topicKey: 'みんなの作品を見る', title: l10n.helpCommunityTitle, description: l10n.helpCommunityDesc, category: l10n.helpCategoryCommunity, diagram: const HelpDiagramSpec(HelpScreenTemplate.cardGrid, 1, icon: Icons.people_outline)),

        // ── プレミアム ──────────────────────────────────────────
        _HelpEntry(topicKey: 'ウォーターマーク', title: l10n.helpWatermarkEntryTitle, description: l10n.helpWatermarkEntryDesc, category: l10n.helpCategoryPremium, diagram: const HelpDiagramSpec(HelpScreenTemplate.floatingPanel, 1)),
        _HelpEntry(topicKey: 'プレミアム', title: l10n.helpPremiumEntryTitle, description: l10n.helpPremiumEntryDesc, category: l10n.helpCategoryPremium, diagram: const HelpDiagramSpec(HelpScreenTemplate.cardGrid, 0, icon: Icons.workspace_premium_outlined)),

        // ── プロジェクト管理 ──────────────────────────────────────
        _HelpEntry(topicKey: 'ホーム画面', title: l10n.helpHomeScreenTitle, description: l10n.helpHomeScreenDesc, category: l10n.helpCategoryProjectManagement, diagram: const HelpDiagramSpec(HelpScreenTemplate.cardGrid, 0)),
        _HelpEntry(topicKey: '新規プロジェクト作成', title: l10n.helpNewProjectTitle, description: l10n.helpNewProjectDesc, category: l10n.helpCategoryProjectManagement, diagram: const HelpDiagramSpec(HelpScreenTemplate.cardGrid, 1, icon: Icons.add_circle_outline)),
        _HelpEntry(topicKey: 'プロジェクト詳細画面', title: l10n.helpProjectDetailTitle, description: l10n.helpProjectDetailDesc, category: l10n.helpCategoryProjectManagement, diagram: const HelpDiagramSpec(HelpScreenTemplate.cardGrid, 2, icon: Icons.info_outline)),

        // ── 設定画面 ────────────────────────────────────────────
        // 各種設定画面の説明を1箇所にまとめている。
        _HelpEntry(topicKey: 'テーマ設定', title: l10n.helpThemeSettingsTitle, description: l10n.helpThemeSettingsDesc, category: l10n.helpCategorySettings, diagram: const HelpDiagramSpec(HelpScreenTemplate.floatingPanel, 1)),
        _HelpEntry(topicKey: 'ワークスペース設定', title: l10n.helpWorkspaceSettingsTitle, description: l10n.helpWorkspaceSettingsDesc, category: l10n.helpCategorySettings, diagram: const HelpDiagramSpec(HelpScreenTemplate.floatingPanel, 1)),
        _HelpEntry(topicKey: 'ジェスチャー設定', title: l10n.helpGestureSettingsTitle, description: l10n.helpGestureSettingsDesc, category: l10n.helpCategorySettings, diagram: const HelpDiagramSpec(HelpScreenTemplate.floatingPanel, 1)),
        _HelpEntry(topicKey: 'ペン設定', title: l10n.helpPenSettingsTitle, description: l10n.helpPenSettingsDesc, category: l10n.helpCategoryPenInput, diagram: const HelpDiagramSpec(HelpScreenTemplate.floatingPanel, 3)),
        _HelpEntry(topicKey: '傾き検知', title: l10n.helpTiltDetectionTitle, description: l10n.helpTiltDetectionDesc, category: l10n.helpCategoryPenInput, diagram: const HelpDiagramSpec(HelpScreenTemplate.floatingPanel, 1)),
        _HelpEntry(topicKey: 'パフォーマンス設定', title: l10n.helpPerformanceSettingsTitle, description: l10n.helpPerformanceSettingsDesc, category: l10n.helpCategorySettings, diagram: const HelpDiagramSpec(HelpScreenTemplate.floatingPanel, 3)),
        _HelpEntry(topicKey: 'バケツ塗り詳細設定', title: l10n.helpBucketDetailSettingsTitle, description: l10n.helpBucketDetailSettingsDesc, category: l10n.helpCategorySettings, diagram: const HelpDiagramSpec(HelpScreenTemplate.floatingPanel, 3)),
        _HelpEntry(topicKey: 'Undo回数設定', title: l10n.helpUndoSettingsTitle, description: l10n.helpUndoSettingsDesc, category: l10n.helpCategorySettings, diagram: const HelpDiagramSpec(HelpScreenTemplate.floatingPanel, 3)),
        _HelpEntry(topicKey: 'フォントの読み込み', title: l10n.helpFontImportTitle, description: l10n.helpFontImportDesc, category: l10n.helpCategorySettings, diagram: const HelpDiagramSpec(HelpScreenTemplate.floatingPanel, 1)),
        _HelpEntry(topicKey: '容量削減', title: l10n.helpStorageTitle, description: l10n.helpStorageDesc, category: l10n.helpCategorySettings, diagram: const HelpDiagramSpec(HelpScreenTemplate.cardGrid, 0, icon: Icons.cleaning_services_outlined)),
      ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_HelpEntry> _filtered(List<_HelpEntry> entries) => _searchQuery.isEmpty
      ? entries
      : entries.where((e) => e.title.contains(_searchQuery) || e.description.contains(_searchQuery) || e.category.contains(_searchQuery)).toList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final entries = _buildEntries(l10n);
    final filtered = _filtered(entries);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.helpScreenTitle)),
      body: SafeArea(child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.helpSearchHint,
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(l10n.helpNoResults,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  )
                : ListView.builder(
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final entry = filtered[index];
                final scheme = Theme.of(context).colorScheme;
                // 各項目を独立したカードとして浮かせる。
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Material(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    elevation: 1,
                    shadowColor: Colors.black.withValues(alpha: 0.15),
                    clipBehavior: Clip.antiAlias,
                    child: ExpansionTile(
                      // 各画面のヘルプボタンから遷移した場合、該当項目を
                      // 自動展開して探す手間を省く。topicKeyはHelpButton(topic:)の
                      // 呼び出し元と一致させる固定の内部識別子（翻訳対象外）。
                      initiallyExpanded: widget.initialTopic != null && entry.topicKey == widget.initialTopic,
                      shape: const Border(),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [scheme.primary.withValues(alpha: 0.22), scheme.primary.withValues(alpha: 0.1)],
                          ),
                        ),
                        child: Icon(Icons.help_outline, color: scheme.primary, size: 18),
                      ),
                      // 項目名用フォント（くらむぼん）。
                      title: Text(entry.title, style: const TextStyle(fontFamily: 'Kuramubon', fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: Text(entry.category, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                      children: [
                        // 実画面の簡易図解は用いず、文章での説明のみとする。
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          // 説明テキスト用フォント（白光明朝。アプリ全体の
                          // 基本フォントを継承するため明示指定不要）。
                          child: Text(entry.description, style: const TextStyle(height: 1.5)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      )),
    );
  }
}

class _HelpEntry {
  /// HelpButton(topic:)の呼び出し元と一致させるための固定識別子
  /// （表示言語に関わらず日本語のまま、翻訳対象外）。
  final String topicKey;
  final String title;
  final String description;
  final String category;
  /// 実際の画面を再現した簡易図解。nullなら図解なし
  /// （どの画面のどこにあるかというより抽象的な概念を説明する項目は省略）。
  final HelpDiagramSpec? diagram;
  const _HelpEntry({
    required this.topicKey,
    required this.title,
    required this.description,
    required this.category,
    this.diagram,
  });
}
