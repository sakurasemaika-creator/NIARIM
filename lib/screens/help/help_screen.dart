import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

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
        _HelpEntry(topicKey: 'ペンツール', title: l10n.helpPenToolTitle, description: l10n.helpPenToolDesc, category: l10n.helpCategoryTool),
        _HelpEntry(topicKey: '消しゴムツール', title: l10n.helpEraserToolTitle, description: l10n.helpEraserToolDesc, category: l10n.helpCategoryTool),
        _HelpEntry(topicKey: 'バケツツール', title: l10n.helpBucketToolTitle, description: l10n.helpBucketToolDesc, category: l10n.helpCategoryTool),
        _HelpEntry(topicKey: '投げ縄塗り', title: l10n.helpLassoFillTitle, description: l10n.helpLassoFillDesc, category: l10n.helpCategoryTool),
        _HelpEntry(topicKey: 'スポイトツール', title: l10n.helpEyedropperToolTitle, description: l10n.helpEyedropperToolDesc, category: l10n.helpCategoryTool),
        _HelpEntry(topicKey: '選択ツール', title: l10n.helpSelectToolTitle, description: l10n.helpSelectToolDesc, category: l10n.helpCategoryTool),
        _HelpEntry(topicKey: '指ツール（歪みツール）', title: l10n.helpFingerToolTitle, description: l10n.helpFingerToolDesc, category: l10n.helpCategoryTool),
        _HelpEntry(topicKey: '図形ツール', title: l10n.helpShapeToolTitle, description: l10n.helpShapeToolDesc, category: l10n.helpCategoryTool),
        _HelpEntry(topicKey: 'テキストツール', title: l10n.helpTextToolTitle, description: l10n.helpTextToolDesc, category: l10n.helpCategoryTool),
        _HelpEntry(topicKey: '早替えツール', title: l10n.helpQuickToolTitle, description: l10n.helpQuickToolDesc, category: l10n.helpCategoryTool),
        _HelpEntry(topicKey: 'スタンプツール', title: l10n.helpStampToolTitle, description: l10n.helpStampToolDesc, category: l10n.helpCategoryTool),
        _HelpEntry(topicKey: '早替えツール管理', title: l10n.helpQuickToolManagementTitle, description: l10n.helpQuickToolManagementDesc, category: l10n.helpCategoryTool),
        _HelpEntry(topicKey: '選択範囲の変形', title: l10n.helpTransformSelectionTitle, description: l10n.helpTransformSelectionDesc, category: l10n.helpCategoryTool),
        _HelpEntry(topicKey: 'カラーピッカー', title: l10n.helpColorPickerTitle, description: l10n.helpColorPickerDesc, category: l10n.helpCategoryTool),

        // ── レイヤー ────────────────────────────────────────────
        _HelpEntry(topicKey: 'レイヤー', title: l10n.helpLayerTitle, description: l10n.helpLayerDesc, category: l10n.helpCategoryLayer),
        _HelpEntry(topicKey: 'ブレンドモード', title: l10n.helpBlendModeTitle, description: l10n.helpBlendModeDesc, category: l10n.helpCategoryLayer),
        _HelpEntry(topicKey: 'クリッピング', title: l10n.helpClippingTitle, description: l10n.helpClippingDesc, category: l10n.helpCategoryLayer),
        _HelpEntry(topicKey: '共通レイヤー', title: l10n.helpCommonLayerTitle, description: l10n.helpCommonLayerDesc, category: l10n.helpCategoryLayer),
        _HelpEntry(topicKey: '自動塗り', title: l10n.helpAutoFillTitle, description: l10n.helpAutoFillDesc, category: l10n.helpCategoryLayer),
        _HelpEntry(topicKey: 'グラデーション塗り', title: l10n.helpGradientAutofillTitle, description: l10n.helpGradientAutofillDesc, category: l10n.helpCategoryLayer),

        // ── 描画補助 ────────────────────────────────────────────
        _HelpEntry(topicKey: 'オニオンスキン', title: l10n.helpOnionSkinTitle, description: l10n.helpOnionSkinDesc, category: l10n.helpCategoryAnimation),
        _HelpEntry(topicKey: '定規', title: l10n.helpRulerTitle, description: l10n.helpRulerDesc, category: l10n.helpCategoryDrawing),
        _HelpEntry(topicKey: 'フェード', title: l10n.helpFadeTitle, description: l10n.helpFadeDesc, category: l10n.helpCategoryBrush),
        _HelpEntry(topicKey: 'ストローク減衰', title: l10n.helpStrokeDecayTitle, description: l10n.helpStrokeDecayDesc, category: l10n.helpCategoryBrush),
        _HelpEntry(topicKey: '混色', title: l10n.helpColorMixingTitle, description: l10n.helpColorMixingDesc, category: l10n.helpCategoryBrush),
        _HelpEntry(topicKey: '筆圧カーブ', title: l10n.helpPressureCurveTitle, description: l10n.helpPressureCurveDesc, category: l10n.helpCategoryPenInput),
        _HelpEntry(topicKey: 'トーン塗り', title: l10n.helpToneFillTitle, description: l10n.helpToneFillDesc, category: l10n.helpCategoryDrawing),
        _HelpEntry(topicKey: 'ピクセルモード', title: l10n.helpPixelModeTitle, description: l10n.helpPixelModeDesc, category: l10n.helpCategoryDrawing),

        // ── タイムライン・アニメーション ──────────────────────────
        _HelpEntry(topicKey: 'タイムライン', title: l10n.helpTimelineTitle, description: l10n.helpTimelineDesc, category: l10n.helpCategoryAnimation),
        _HelpEntry(topicKey: 'シーン', title: l10n.helpSceneTitle, description: l10n.helpSceneDesc, category: l10n.helpCategoryAnimation),
        _HelpEntry(topicKey: 'シーン操作', title: l10n.helpSceneOperationsTitle, description: l10n.helpSceneOperationsDesc, category: l10n.helpCategoryAnimation),
        _HelpEntry(topicKey: 'フレーム操作', title: l10n.helpFrameOperationsTitle, description: l10n.helpFrameOperationsDesc, category: l10n.helpCategoryAnimation),
        _HelpEntry(topicKey: '素材クリップ', title: l10n.helpMaterialClipTitle, description: l10n.helpMaterialClipDesc, category: l10n.helpCategoryAnimation),
        _HelpEntry(topicKey: '素材一覧', title: l10n.helpMaterialListTitle, description: l10n.helpMaterialListDesc, category: l10n.helpCategoryAnimation),
        _HelpEntry(topicKey: 'カメラキーフレーム', title: l10n.helpCameraKeyframeTitle, description: l10n.helpCameraKeyframeDesc, category: l10n.helpCategoryAnimation),
        _HelpEntry(topicKey: '演出フィルター', title: l10n.helpEffectFilterTitle, description: l10n.helpEffectFilterDesc, category: l10n.helpCategoryAnimation),
        _HelpEntry(topicKey: '描画フィルター', title: l10n.helpDrawingFilterTitle, description: l10n.helpDrawingFilterDesc, category: l10n.helpCategoryDrawing),
        _HelpEntry(topicKey: 'レイヤーキーフレーム', title: l10n.helpLayerKeyframeTitle, description: l10n.helpLayerKeyframeDesc, category: l10n.helpCategoryAnimation),
        _HelpEntry(topicKey: 'レイヤーグループ', title: l10n.helpLayerGroupTitle, description: l10n.helpLayerGroupDesc, category: l10n.helpCategoryAnimation),
        _HelpEntry(topicKey: 'EndCard（エンドロゴ）', title: l10n.helpEndCardTitle, description: l10n.helpEndCardDesc, category: l10n.helpCategoryExport),

        // ── 保存・プロジェクト管理 ─────────────────────────────────
        _HelpEntry(topicKey: '自動保存', title: l10n.helpAutoSaveTitle, description: l10n.helpAutoSaveDesc, category: l10n.helpCategorySave),
        _HelpEntry(topicKey: 'セーブスロット', title: l10n.helpSaveSlotTitle, description: l10n.helpSaveSlotDesc, category: l10n.helpCategorySave),
        _HelpEntry(topicKey: 'セーブツリー', title: l10n.helpSaveTreeTitle, description: l10n.helpSaveTreeDesc, category: l10n.helpCategorySave),
        _HelpEntry(topicKey: 'フォルダ', title: l10n.helpFolderTitle, description: l10n.helpFolderDesc, category: l10n.helpCategoryProjectManagement),
        _HelpEntry(topicKey: 'ゴミ箱', title: l10n.helpTrashTitle, description: l10n.helpTrashDesc, category: l10n.helpCategoryProjectManagement),
        _HelpEntry(topicKey: '共有（.niashare）', title: l10n.helpShareTitle, description: l10n.helpShareDesc, category: l10n.helpCategoryProjectManagement),
        _HelpEntry(topicKey: '引き継ぎ（.niatra）', title: l10n.helpTransferTitle, description: l10n.helpTransferDesc, category: l10n.helpCategoryProjectManagement),

        // ── 書き出し ───────────────────────────────────────────
        _HelpEntry(topicKey: '動画書き出し（MP4）', title: l10n.helpVideoExportTitle, description: l10n.helpVideoExportDesc, category: l10n.helpCategoryExport),
        _HelpEntry(topicKey: '透過WebM', title: l10n.helpTransparentWebmTitle, description: l10n.helpTransparentWebmDesc, category: l10n.helpCategoryExport),
        _HelpEntry(topicKey: 'GIF書き出し', title: l10n.helpGifExportTitle, description: l10n.helpGifExportDesc, category: l10n.helpCategoryExport),

        // ── その他 ────────────────────────────────────────────
        _HelpEntry(topicKey: 'ウォーターマーク', title: l10n.helpWatermarkEntryTitle, description: l10n.helpWatermarkEntryDesc, category: l10n.helpCategoryPremium),
        _HelpEntry(topicKey: 'プレミアム', title: l10n.helpPremiumEntryTitle, description: l10n.helpPremiumEntryDesc, category: l10n.helpCategoryPremium),
        _HelpEntry(topicKey: 'フォント管理', title: l10n.helpFontManagementTitle, description: l10n.helpFontManagementDesc, category: l10n.helpCategorySettings),
        _HelpEntry(topicKey: 'パフォーマンス設定', title: l10n.helpPerformanceSettingsTitle, description: l10n.helpPerformanceSettingsDesc, category: l10n.helpCategorySettings),
        _HelpEntry(topicKey: 'ジェスチャー設定', title: l10n.helpGestureSettingsTitle, description: l10n.helpGestureSettingsDesc, category: l10n.helpCategorySettings),
        _HelpEntry(topicKey: 'バケツ塗り詳細設定', title: l10n.helpBucketDetailSettingsTitle, description: l10n.helpBucketDetailSettingsDesc, category: l10n.helpCategorySettings),
        _HelpEntry(topicKey: 'ホーム画面', title: l10n.helpHomeScreenTitle, description: l10n.helpHomeScreenDesc, category: l10n.helpCategoryProjectManagement),
        _HelpEntry(topicKey: '新規プロジェクト作成', title: l10n.helpNewProjectTitle, description: l10n.helpNewProjectDesc, category: l10n.helpCategoryProjectManagement),
        _HelpEntry(topicKey: 'テーマ設定', title: l10n.helpThemeSettingsTitle, description: l10n.helpThemeSettingsDesc, category: l10n.helpCategorySettings),
        _HelpEntry(topicKey: 'ワークスペース設定', title: l10n.helpWorkspaceSettingsTitle, description: l10n.helpWorkspaceSettingsDesc, category: l10n.helpCategorySettings),
        _HelpEntry(topicKey: 'ペン設定', title: l10n.helpPenSettingsTitle, description: l10n.helpPenSettingsDesc, category: l10n.helpCategoryPenInput),
        _HelpEntry(topicKey: 'Undo回数設定', title: l10n.helpUndoSettingsTitle, description: l10n.helpUndoSettingsDesc, category: l10n.helpCategorySettings),
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
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(hintText: l10n.helpSearchHint, prefixIcon: const Icon(Icons.search), border: const OutlineInputBorder(), isDense: true),
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
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final entry = filtered[index];
                return ExpansionTile(
                  // 各画面のヘルプボタンから遷移した場合、該当項目を
                  // 自動展開して探す手間を省く。topicKeyはHelpButton(topic:)の
                  // 呼び出し元と一致させる固定の内部識別子（翻訳対象外）。
                  initiallyExpanded: widget.initialTopic != null && entry.topicKey == widget.initialTopic,
                  leading: Icon(Icons.help_outline, color: Theme.of(context).colorScheme.primary, size: 20),
                  // 項目名用フォント（仕様書24：くらむぼん。以前は説明文と
                  // 逆になっており、項目名が白光明朝・説明文がくらむぼんに
                  // なっていた不具合を修正）。
                  title: Text(entry.title, style: const TextStyle(fontFamily: 'Kuramubon', fontWeight: FontWeight.w600)),
                  subtitle: Text(entry.category,
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      // 説明テキスト用フォント（仕様書24：白光明朝。アプリ全体の
                      // 基本フォントを継承するため明示指定不要）。
                      child: Text(entry.description),
                    ),
                  ],
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
  const _HelpEntry({required this.topicKey, required this.title, required this.description, required this.category});
}
