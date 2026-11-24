import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../config/font_fallback.dart';
import '../../widgets/app_tutorial.dart';
import '../../utils/name_collation.dart';
import '../../widgets/responsive.dart';
import '../../widgets/fit_or_hide_title.dart';
import '../../widgets/grouped_sheet.dart';
import '../../widgets/sheet_list_segment.dart';

/// ツールの項目は、キャンバスのツールバーのボタンと同じ印で出す（分類の
/// 印〔鉛筆〕だけでは17項目が同じに見え、どのボタンの説明か分からなかった）。
/// 値は[IconData]か、消しゴムの[FaIconData]。
const Map<String, Object> _topicIcons = {
  '基本操作': Icons.touch_app,
  'ペンツール': Icons.brush,
  '消しゴムツール': FontAwesomeIcons.eraser,
  'バケツツール': Icons.format_color_fill,
  '投げ縄塗り': Icons.gesture,
  'スポイトツール': Icons.colorize,
  '選択ツール': Icons.highlight_alt,
  '指ツール（歪みツール）': Icons.pan_tool_alt,
  '図形ツール': Icons.category,
  'テキストツール': Icons.text_fields,
  '早替えツール管理': Icons.loop,
  '早替えツール': Icons.loop,
  'スタンプツール': Icons.auto_fix_high_outlined,
  'ペンサブツール': Icons.brush_outlined,
  '選択範囲の変形': Icons.transform,
  'カラーピッカー': Icons.palette,
};

class HelpScreen extends StatefulWidget {
  // 各画面のヘルプボタンから「この画面に関連する項目」を指定して開いた
  // 場合のトピック名（_HelpEntry.topicKeyと一致させる）。該当項目を展開し、
  // 検索欄は別の項目を探せるよう空けておく。
  // topicKeyは表示言語に関わらず固定の日本語文字列（HelpButton(topic:)の
  // 呼び出し元と一致させるための内部識別子であり、翻訳対象外）。
  final String? initialTopic;
  const HelpScreen({super.key, this.initialTopic, this.embedded = false});

  final bool embedded;

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _resultsScroll = ScrollController(keepScrollOffset: false);
  String _searchQuery = '';

  /// The screen's own topic, shown alone until something is typed. It is an
  /// internal Japanese key, so it is not put in the search box.
  String? _topic;
  bool _topicChecked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final topic = widget.initialTopic;
    if (_topicChecked || topic == null || topic.isEmpty) return;
    _topicChecked = true;
    final l10n = AppLocalizations.of(context)!;
    if (_buildEntries(l10n).any((e) => e.topicKey == topic)) {
      _topic = topic;
    } else {
      // Not one of the topics: search for it as typed.
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
    // ── 基本操作 ────────────────────────────────────────────
    // 個々のツールの説明より前に、ツールバーの操作体系そのもの
    // （タップで切り替え／長押し・上スワイプで詳細設定）を置く。
    // ここが分かっていないと個別の説明も効かないため、一覧の先頭に
    // 固定し、初回チュートリアルからも同じ内容へ辿り着けるようにする。
    _HelpEntry(
      topicKey: '基本操作',
      title: l10n.helpBasicGestureTitle,
      description: l10n.helpBasicGestureDesc,
      category: l10n.helpCategoryTool,
    ),
    // ── 描画ツール ──────────────────────────────────────────
    _HelpEntry(
      topicKey: 'ペンツール',
      title: l10n.helpPenToolTitle,
      description: l10n.helpPenToolDesc,
      category: l10n.helpCategoryTool,
    ),
    _HelpEntry(
      topicKey: '消しゴムツール',
      title: l10n.helpEraserToolTitle,
      description: l10n.helpEraserToolDesc,
      category: l10n.helpCategoryTool,
    ),
    _HelpEntry(
      topicKey: 'バケツツール',
      title: l10n.helpBucketToolTitle,
      description: l10n.helpBucketToolDesc,
      category: l10n.helpCategoryTool,
    ),
    _HelpEntry(
      topicKey: '投げ縄塗り',
      title: l10n.helpLassoFillTitle,
      description: l10n.helpLassoFillDesc,
      category: l10n.helpCategoryTool,
    ),
    _HelpEntry(
      topicKey: 'スポイトツール',
      title: l10n.helpEyedropperToolTitle,
      description: l10n.helpEyedropperToolDesc,
      category: l10n.helpCategoryTool,
    ),
    _HelpEntry(
      topicKey: '選択ツール',
      title: l10n.helpSelectToolTitle,
      description: l10n.helpSelectToolDesc,
      category: l10n.helpCategoryTool,
    ),
    _HelpEntry(
      topicKey: '指ツール（歪みツール）',
      title: l10n.helpFingerToolTitle,
      description: l10n.helpFingerToolDesc,
      category: l10n.helpCategoryTool,
    ),
    _HelpEntry(
      topicKey: '図形ツール',
      title: l10n.helpShapeToolTitle,
      description: l10n.helpShapeToolDesc,
      category: l10n.helpCategoryTool,
    ),
    // フォント管理の説明は、独立項目にせずこちらへ統合済み。
    // font_settings_screen.dartのHelpButtonが'テキストツール'を参照する
    // よう合わせて変更済み。
    _HelpEntry(
      topicKey: 'テキストツール',
      title: l10n.helpTextToolTitle,
      description: l10n.helpTextToolDesc,
      category: l10n.helpCategoryTool,
    ),
    _HelpEntry(
      topicKey: '早替えツール管理',
      title: l10n.helpQuickToolManagementTitle,
      description: l10n.helpQuickToolManagementDesc,
      category: l10n.helpCategoryTool,
    ),
    _HelpEntry(
      topicKey: '早替えツール',
      title: l10n.helpQuickToolTitle,
      description: l10n.helpQuickToolDesc,
      category: l10n.helpCategoryTool,
    ),
    // スタンプの回転・拡大縮小の説明は、独立項目にせずこちらへ統合済み。
    _HelpEntry(
      topicKey: 'スタンプツール',
      title: l10n.helpStampToolTitle,
      description: l10n.helpStampToolDesc,
      category: l10n.helpCategoryTool,
    ),
    _HelpEntry(
      topicKey: 'ペンサブツール',
      title: l10n.helpPenSubToolTitle,
      description: l10n.helpPenSubToolDesc,
      category: l10n.helpCategoryTool,
    ),
    _HelpEntry(
      topicKey: '選択範囲の変形',
      title: l10n.helpTransformSelectionTitle,
      description: l10n.helpTransformSelectionDesc,
      category: l10n.helpCategoryTool,
    ),
    // 選択範囲の変形と対になる機能。
    _HelpEntry(
      topicKey: '自由変形・メッシュ変形',
      title: l10n.helpMeshTransformTitle,
      description: l10n.helpMeshTransformDesc,
      category: l10n.helpCategoryTool,
    ),
    _HelpEntry(
      topicKey: 'カラーピッカー',
      title: l10n.helpColorPickerTitle,
      description: l10n.helpColorPickerDesc,
      category: l10n.helpCategoryTool,
    ),
    _HelpEntry(
      topicKey: 'ブラシのお気に入り',
      title: l10n.helpBrushFavoriteTitle,
      description: l10n.helpBrushFavoriteDesc,
      category: l10n.helpCategoryBrush,
    ),
    _HelpEntry(
      topicKey: 'カスタムブラシ',
      title: l10n.helpCustomBrushTitle,
      description: l10n.helpCustomBrushDesc,
      category: l10n.helpCategoryBrush,
    ),
    _HelpEntry(
      topicKey: '折り返し',
      title: l10n.helpBrushFoldTitle,
      description: l10n.helpBrushFoldDesc,
      category: l10n.helpCategoryBrush,
    ),

    // ── レイヤー ────────────────────────────────────────────
    _HelpEntry(
      topicKey: 'レイヤー',
      title: l10n.helpLayerTitle,
      description: l10n.helpLayerDesc,
      category: l10n.helpCategoryLayer,
    ),
    _HelpEntry(
      topicKey: 'ブレンドモード',
      title: l10n.helpBlendModeTitle,
      description: l10n.helpBlendModeDesc,
      category: l10n.helpCategoryLayer,
    ),
    _HelpEntry(
      topicKey: 'クリッピング',
      title: l10n.helpClippingTitle,
      description: l10n.helpClippingDesc,
      category: l10n.helpCategoryLayer,
    ),
    // 「レイヤーの共通化」の説明は、独立項目にせずこちらへ統合済み。
    _HelpEntry(
      topicKey: '共通レイヤー',
      title: l10n.helpCommonLayerTitle,
      description: l10n.helpCommonLayerDesc,
      category: l10n.helpCategoryLayer,
    ),
    _HelpEntry(
      topicKey: 'レイヤーの複数選択・一括操作',
      title: l10n.helpLayerMultiSelectTitle,
      description: l10n.helpLayerMultiSelectDesc,
      category: l10n.helpCategoryLayer,
    ),
    _HelpEntry(
      topicKey: 'レイヤーフォルダ',
      title: l10n.helpLayerFolderTitle,
      description: l10n.helpLayerFolderDesc,
      category: l10n.helpCategoryLayer,
    ),
    // 自動塗り実行・自動塗りの線画色設定・自動塗りプリセット絞り込みの説明は、
    // 独立項目にせずこちらへ統合済み。
    _HelpEntry(
      topicKey: '自動塗り',
      title: l10n.helpAutoFillTitle,
      description: l10n.helpAutoFillDesc,
      category: l10n.helpCategoryLayer,
    ),
    _HelpEntry(
      topicKey: 'グラデーション塗り',
      title: l10n.helpGradientAutofillTitle,
      description: l10n.helpGradientAutofillDesc,
      category: l10n.helpCategoryLayer,
    ),

    // ── 描画補助 ────────────────────────────────────────────
    _HelpEntry(
      topicKey: 'シーン操作',
      title: l10n.helpSceneOperationsTitle,
      description: l10n.helpSceneOperationsDesc,
      category: l10n.helpCategoryAnimation,
    ),
    _HelpEntry(
      topicKey: 'オニオンスキン',
      title: l10n.helpOnionSkinTitle,
      description: l10n.helpOnionSkinDesc,
      category: l10n.helpCategoryAnimation,
    ),
    _HelpEntry(
      topicKey: '定規',
      title: l10n.helpRulerTitle,
      description: l10n.helpRulerDesc,
      category: l10n.helpCategoryDrawing,
    ),
    _HelpEntry(
      topicKey: 'フェード',
      title: l10n.helpFadeTitle,
      description: l10n.helpFadeDesc,
      category: l10n.helpCategoryBrush,
    ),
    _HelpEntry(
      topicKey: 'ストローク減衰',
      title: l10n.helpStrokeDecayTitle,
      description: l10n.helpStrokeDecayDesc,
      category: l10n.helpCategoryBrush,
    ),
    _HelpEntry(
      topicKey: '混色',
      title: l10n.helpColorMixingTitle,
      description: l10n.helpColorMixingDesc,
      category: l10n.helpCategoryBrush,
    ),
    _HelpEntry(
      topicKey: '筆圧カーブ',
      title: l10n.helpPressureCurveTitle,
      description: l10n.helpPressureCurveDesc,
      category: l10n.helpCategoryPenInput,
    ),
    _HelpEntry(
      topicKey: 'トーン塗り',
      title: l10n.helpToneFillTitle,
      description: l10n.helpToneFillDesc,
      category: l10n.helpCategoryDrawing,
    ),
    _HelpEntry(
      topicKey: 'ピクセルモード',
      title: l10n.helpPixelModeTitle,
      description: l10n.helpPixelModeDesc,
      category: l10n.helpCategoryDrawing,
    ),
    // 関連する項目同士が近くに並ぶよう、「その他」にあった描画領域・
    // 背景色の説明をここへ移動。
    _HelpEntry(
      topicKey: '描画領域',
      title: l10n.helpDrawingAreaTitle,
      description: l10n.helpDrawingAreaDesc,
      category: l10n.helpCategoryDrawing,
    ),
    _HelpEntry(
      topicKey: 'キャンバスの背景色',
      title: l10n.helpCanvasBackgroundTitle,
      description: l10n.helpCanvasBackgroundDesc,
      category: l10n.helpCategoryDrawing,
    ),

    // ── タイムライン・アニメーション ──────────────────────────
    _HelpEntry(
      topicKey: 'タイムライン',
      title: l10n.helpTimelineTitle,
      description: l10n.helpTimelineDesc,
      category: l10n.helpCategoryAnimation,
    ),
    _HelpEntry(
      topicKey: 'シーン',
      title: l10n.helpSceneTitle,
      description: l10n.helpSceneDesc,
      category: l10n.helpCategoryAnimation,
    ),
    _HelpEntry(
      topicKey: 'フレーム操作',
      title: l10n.helpFrameOperationsTitle,
      description: l10n.helpFrameOperationsDesc,
      category: l10n.helpCategoryAnimation,
    ),
    _HelpEntry(
      topicKey: '素材クリップ',
      title: l10n.helpMaterialClipTitle,
      description: l10n.helpMaterialClipDesc,
      category: l10n.helpCategoryAnimation,
    ),
    _HelpEntry(
      topicKey: '素材一覧',
      title: l10n.helpMaterialListTitle,
      description: l10n.helpMaterialListDesc,
      category: l10n.helpCategoryAnimation,
    ),
    _HelpEntry(
      topicKey: '音声クリップ',
      title: l10n.helpAudioClipTitle,
      description: l10n.helpAudioClipDesc,
      category: l10n.helpCategoryAnimation,
    ),
    _HelpEntry(
      topicKey: 'カメラキーフレーム',
      title: l10n.helpCameraKeyframeTitle,
      description: l10n.helpCameraKeyframeDesc,
      category: l10n.helpCategoryAnimation,
    ),
    // 演出フィルターの適用順・動くノイズフィルター・雨フィルターの説明は、
    // 独立項目にせずこちらへ統合済み（個々のフィルターを独立項目に
    // せず「演出フィルター」の親項目内へまとめる）。
    _HelpEntry(
      topicKey: '演出フィルター',
      title: l10n.helpEffectFilterTitle,
      description: l10n.helpEffectFilterDesc,
      category: l10n.helpCategoryAnimation,
    ),
    _HelpEntry(
      topicKey: '描画フィルター',
      title: l10n.helpDrawingFilterTitle,
      description: l10n.helpDrawingFilterDesc,
      category: l10n.helpCategoryDrawing,
    ),
    _HelpEntry(
      topicKey: '自動操作',
      title: l10n.helpCustomAutomationTitle,
      description: l10n.helpCustomAutomationDesc,
      category: l10n.helpCategoryTool,
    ),
    _HelpEntry(
      topicKey: 'レイヤーキーフレーム',
      title: l10n.helpLayerKeyframeTitle,
      description: l10n.helpLayerKeyframeDesc,
      category: l10n.helpCategoryAnimation,
    ),
    // layerPanelListのスロット2＝共通レイヤーアイコン（groups_outlined）が
    // 「グループ」の名前的にも近いため使う。
    _HelpEntry(
      topicKey: 'レイヤーグループ',
      title: l10n.helpLayerGroupTitle,
      description: l10n.helpLayerGroupDesc,
      category: l10n.helpCategoryAnimation,
    ),
    _HelpEntry(
      topicKey: 'EndCard（エンドロゴ）',
      title: l10n.helpEndCardTitle,
      description: l10n.helpEndCardDesc,
      category: l10n.helpCategoryExport,
    ),

    // ── 保存・プロジェクト管理 ─────────────────────────────────
    _HelpEntry(
      topicKey: '自動保存',
      title: l10n.helpAutoSaveTitle,
      description: l10n.helpAutoSaveDesc,
      category: l10n.helpCategorySave,
    ),
    // _saveIcons[2]=bookmark_borderの方が「スロットに留める」イメージに
    // 近いため、履歴アイコン（1、セーブツリー用）とは分けている。
    _HelpEntry(
      topicKey: 'セーブスロット',
      title: l10n.helpSaveSlotTitle,
      description: l10n.helpSaveSlotDesc,
      category: l10n.helpCategorySave,
    ),
    _HelpEntry(
      topicKey: 'セーブツリー',
      title: l10n.helpSaveTreeTitle,
      description: l10n.helpSaveTreeDesc,
      category: l10n.helpCategorySave,
    ),
    _HelpEntry(
      topicKey: 'フォルダ',
      title: l10n.helpFolderTitle,
      description: l10n.helpFolderDesc,
      category: l10n.helpCategoryProjectManagement,
    ),
    _HelpEntry(
      topicKey: 'ゴミ箱',
      title: l10n.helpTrashTitle,
      description: l10n.helpTrashDesc,
      category: l10n.helpCategoryProjectManagement,
    ),
    _HelpEntry(
      topicKey: '共有（.niashare）',
      title: l10n.helpShareTitle,
      description: l10n.helpShareDesc,
      category: l10n.helpCategoryProjectManagement,
    ),
    _HelpEntry(
      topicKey: '引き継ぎ（.niatra）',
      title: l10n.helpTransferTitle,
      description: l10n.helpTransferDesc,
      category: l10n.helpCategoryProjectManagement,
    ),

    // ── 書き出し ───────────────────────────────────────────
    // 透過WebM・GIF書き出し・無料会員の尺制限の説明は、独立項目にせず
    // こちらへ統合済み（書き出し関連のヘルプ項目をある程度
    // 1つにまとめる）。topicKeyはexport_screen.dartのHelpButtonが参照して
    // いるため変更していない（表示タイトルのみ範囲を広げた）。
    _HelpEntry(
      topicKey: '動画書き出し（MP4）',
      title: l10n.helpVideoExportTitle,
      description: l10n.helpVideoExportDesc,
      category: l10n.helpCategoryExport,
    ),
    _HelpEntry(
      topicKey: '書き出し画面',
      title: l10n.helpExportScreenTitle,
      description: l10n.helpExportScreenDesc,
      category: l10n.helpCategoryExport,
    ),

    // ── コミュニティ ──────────────────────────────────────────
    _HelpEntry(
      topicKey: '作品広場',
      title: l10n.helpCommunityTitle,
      description: l10n.helpCommunityDesc,
      category: l10n.helpCategoryCommunity,
    ),

    // ── プレミアム ──────────────────────────────────────────
    _HelpEntry(
      topicKey: 'ウォーターマークの再編集',
      title: l10n.helpWatermarkEditTitle,
      description: l10n.helpWatermarkEditDesc,
      category: l10n.helpCategoryPremium,
    ),
    _HelpEntry(
      topicKey: 'ウォーターマーク',
      title: l10n.helpWatermarkEntryTitle,
      description: l10n.helpWatermarkEntryDesc,
      category: l10n.helpCategoryPremium,
    ),
    _HelpEntry(
      topicKey: 'プレミアム',
      title: l10n.helpPremiumEntryTitle,
      description: l10n.helpPremiumEntryDesc,
      category: l10n.helpCategoryPremium,
    ),
    _HelpEntry(
      topicKey: '特典の期限が切れたら',
      title: l10n.helpPremiumExpiryTitle,
      description: l10n.helpPremiumExpiryDesc,
      category: l10n.helpCategoryPremium,
    ),

    // ── プロジェクト管理 ──────────────────────────────────────
    _HelpEntry(
      topicKey: 'ホーム画面',
      title: l10n.helpHomeScreenTitle,
      description: l10n.helpHomeScreenDesc,
      category: l10n.helpCategoryProjectManagement,
    ),
    _HelpEntry(
      topicKey: '新規プロジェクト作成',
      title: l10n.helpNewProjectTitle,
      description: l10n.helpNewProjectDesc,
      category: l10n.helpCategoryProjectManagement,
    ),
    _HelpEntry(
      topicKey: 'プロジェクト詳細画面',
      title: l10n.helpProjectDetailTitle,
      description: l10n.helpProjectDetailDesc,
      category: l10n.helpCategoryProjectManagement,
    ),

    // ── 設定画面 ────────────────────────────────────────────
    // 各種設定画面の説明を1箇所にまとめている。
    _HelpEntry(
      topicKey: 'テーマ設定',
      title: l10n.helpThemeSettingsTitle,
      description: l10n.helpThemeSettingsDesc,
      category: l10n.helpCategorySettings,
    ),
    _HelpEntry(
      topicKey: 'ワークスペース設定',
      title: l10n.helpWorkspaceSettingsTitle,
      description: l10n.helpWorkspaceSettingsDesc,
      category: l10n.helpCategorySettings,
    ),
    _HelpEntry(
      topicKey: 'ショートカット設定',
      title: l10n.shortcutSettingsTitle,
      description: l10n.helpShortcutSettingsDesc,
      category: l10n.helpCategorySettings,
    ),
    _HelpEntry(
      topicKey: 'ジェスチャー設定',
      title: l10n.helpGestureSettingsTitle,
      description: l10n.helpGestureSettingsDesc,
      category: l10n.helpCategorySettings,
    ),
    _HelpEntry(
      topicKey: 'ペン設定',
      title: l10n.helpPenSettingsTitle,
      description: l10n.helpPenSettingsDesc,
      category: l10n.helpCategoryPenInput,
    ),
    _HelpEntry(
      topicKey: '傾き検知',
      title: l10n.helpTiltDetectionTitle,
      description: l10n.helpTiltDetectionDesc,
      category: l10n.helpCategoryPenInput,
    ),
    _HelpEntry(
      topicKey: 'パフォーマンス設定',
      title: l10n.helpPerformanceSettingsTitle,
      description: l10n.helpPerformanceSettingsDesc,
      category: l10n.helpCategorySettings,
    ),
    _HelpEntry(
      topicKey: 'バケツ塗り詳細設定',
      title: l10n.helpBucketDetailSettingsTitle,
      description: l10n.helpBucketDetailSettingsDesc,
      category: l10n.helpCategorySettings,
    ),
    _HelpEntry(
      topicKey: 'Undo回数設定',
      title: l10n.helpUndoSettingsTitle,
      description: l10n.helpUndoSettingsDesc,
      category: l10n.helpCategorySettings,
    ),
    _HelpEntry(
      topicKey: 'フォントの読み込み',
      title: l10n.helpFontImportTitle,
      description: l10n.helpFontImportDesc,
      category: l10n.helpCategorySettings,
    ),
    _HelpEntry(
      topicKey: '容量削減',
      title: l10n.helpStorageTitle,
      description: l10n.helpStorageDesc,
      category: l10n.helpCategorySettings,
    ),
    _HelpEntry(
      topicKey: 'ホーム画面ウィジェット',
      title: l10n.helpWidgetSettingsTitle,
      description: l10n.helpWidgetSettingsDesc,
      category: l10n.helpCategorySettings,
    ),
  ];

  @override
  void dispose() {
    _resultsScroll.dispose();
    _searchFocus.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _updateSearch(String value) {
    if (_resultsScroll.hasClients && _resultsScroll.offset != 0) {
      _resultsScroll.jumpTo(0);
    }
    setState(() {
      _searchQuery = value;
      _topic = null;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _updateSearch('');
    _searchFocus.requestFocus();
  }

  List<_HelpEntry> _filtered(List<_HelpEntry> entries, String query) {
    if (query.isEmpty) {
      return _topic == null
          ? entries
          : entries.where((e) => e.topicKey == _topic).toList();
    }
    final terms = query.split(RegExp(r'\s+'));
    final exact = <_HelpEntry>[];
    final titles = <_HelpEntry>[];
    final categories = <_HelpEntry>[];
    final descriptions = <_HelpEntry>[];
    for (final entry in entries) {
      final title = foldName(entry.title);
      if (title == query || entry.topicKey == _searchQuery.trim()) {
        exact.add(entry);
      } else if (terms.every(title.contains)) {
        titles.add(entry);
      } else {
        final heading = '$title ${foldName(entry.category)}';
        if (terms.every(heading.contains)) {
          categories.add(entry);
        } else if (terms.every(
          '$heading ${foldName(entry.description)}'.contains,
        )) {
          descriptions.add(entry);
        }
      }
    }
    return [...exact, ...titles, ...categories, ...descriptions];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context)!;
    final searchLabelStyle = TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final categoryIcons = {
      l10n.helpCategoryTool: Icons.edit,
      l10n.helpCategoryBrush: Icons.brush,
      l10n.helpCategoryPenInput: Icons.tune,
      l10n.helpCategoryDrawing: Icons.straighten,
      l10n.helpCategoryLayer: Icons.layers,
      l10n.helpCategoryAnimation: Icons.movie_filter,
      l10n.helpCategorySave: Icons.save_outlined,
      l10n.helpCategoryProjectManagement: Icons.folder,
      l10n.helpCategoryExport: Icons.file_download,
      l10n.helpCategoryCommunity: Icons.image,
      l10n.helpCategoryPremium: Icons.star,
      l10n.helpCategorySettings: Icons.settings,
    };
    final entries = _buildEntries(l10n);
    final query = foldName(_searchQuery).trim();
    final filtered = _filtered(entries, query);
    // 何も探していないときは、一覧の先頭から使い方（図つきの数ページ）を
    // 開ける。
    final showTutorial = query.isEmpty && _topic == null;
    final showHeader = showTutorial || query.isNotEmpty;
    // 一覧は分類ごとの1枚の面にし、分類の名前は面の上に置く（以前は項目
    // ごとに影のついたカードと差し色の四角の印、行ごとに分類の名前）。
    // 探しているときは関連の高い順のまま1枚の面に並べ、分類の名前は行の
    // 2行目に出す。
    final rows = <_HelpRow>[];
    if (query.isNotEmpty) {
      for (var i = 0; i < filtered.length; i++) {
        rows.add(
          _HelpRow.entry(
            filtered[i],
            first: i == 0,
            last: i == filtered.length - 1,
            showCategory: true,
          ),
        );
      }
    } else {
      for (var i = 0; i < filtered.length; i++) {
        final entry = filtered[i];
        final first = i == 0 || filtered[i - 1].category != entry.category;
        final last =
            i == filtered.length - 1 ||
            filtered[i + 1].category != entry.category;
        if (first) rows.add(_HelpRow.header(entry.category));
        rows.add(_HelpRow.entry(entry, first: first, last: last));
      }
    }
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(title: FitOrHideTitle(l10n.helpScreenTitle)),
      body: desktopCentered(
        context,
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Focus(
                canRequestFocus: false,
                onKeyEvent: (_, event) {
                  final composing = _searchController.value.composing;
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.escape &&
                      _searchQuery.isNotEmpty &&
                      (!composing.isValid || composing.isCollapsed)) {
                    _clearSearch();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  textInputAction: TextInputAction.search,
                  // 画面の色で塗る欄なので、打った字・ヒント・アイコンは本文の
                  // 文字色（テーマの入力欄はメニューの色で塗りメニューの文字色）。
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.helpSearchHint,
                    labelStyle: searchLabelStyle,
                    floatingLabelStyle: searchLabelStyle,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            tooltip: l10n.projectListClearSearch,
                            onPressed: _clearSearch,
                            icon: const Icon(Icons.clear),
                          ),
                    prefixIconColor: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant,
                    filled: true,
                    // 検索欄も面と同じ色・細い縁（面の色は2種類だけ）。
                    fillColor:
                        Theme.of(context).cardTheme.color ??
                        Theme.of(context).colorScheme.surface,
                    border: _searchBorder(context),
                    enabledBorder: _searchBorder(context),
                    isDense: true,
                  ),
                  onChanged: _updateSearch,
                ),
              ),
            ),
            if (_topic != null && _searchQuery.isEmpty)
              TextButton(
                onPressed: () => setState(() => _topic = null),
                child: Text(l10n.helpShowAllTopics),
              ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          l10n.helpNoResults,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _resultsScroll,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.only(top: 4, bottom: 12),
                      itemCount: rows.length + (showHeader ? 1 : 0),
                      itemBuilder: (context, index) {
                        final scheme = Theme.of(context).colorScheme;
                        if (showHeader) {
                          if (index == 0) {
                            if (showTutorial) return const _TutorialEntry();
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                              child: Semantics(
                                liveRegion: true,
                                child: Text(
                                  l10n.helpSearchResultCount(filtered.length),
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                            );
                          }
                          index--;
                        }
                        final row = rows[index];
                        final header = row.header;
                        if (header != null) {
                          return Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                              32,
                              index == 0 && !showHeader ? 8 : 20,
                              32,
                              8,
                            ),
                            child: Semantics(
                              header: true,
                              child: Text(
                                header,
                                style: localizedHeadingStyle(
                                  context,
                                  TextStyle(
                                    fontSize: 13,
                                    height: 1.35,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        final entry = row.entry!;
                        return Padding(
                          key: ValueKey(entry.topicKey),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: SheetListSegment(
                            first: row.first,
                            last: row.last,
                            dividerIndent: 16 + 24 + 16,
                            child: ExpansionTile(
                              expandedAlignment:
                                  AlignmentDirectional.centerStart,
                              expandedCrossAxisAlignment:
                                  CrossAxisAlignment.start,
                              // 各画面のヘルプボタンから遷移した場合、該当項目を
                              // 自動展開して探す手間を省く。topicKeyはHelpButton(topic:)の
                              // 呼び出し元と一致させる固定の内部識別子（翻訳対象外）。
                              initiallyExpanded: entry.topicKey == _topic,
                              onExpansionChanged: (expanded) {
                                if (expanded && _searchFocus.hasFocus) {
                                  _searchFocus.unfocus();
                                }
                              },
                              shape: const Border(),
                              collapsedShape: const Border(),
                              // 印は補助の文字色（差し色の四角の台に載せない）。
                              leading: SizedBox.square(
                                dimension: 24,
                                child: Center(
                                  child: switch (_topicIcons[entry.topicKey]) {
                                    final FaIconData fa => FaIcon(
                                      fa,
                                      color: scheme.onSurfaceVariant,
                                      size: 18,
                                    ),
                                    final IconData icon => Icon(
                                      icon,
                                      color: scheme.onSurfaceVariant,
                                      size: 22,
                                    ),
                                    _ => Icon(
                                      categoryIcons[entry.category] ??
                                          Icons.help_outline,
                                      color: scheme.onSurfaceVariant,
                                      size: 22,
                                    ),
                                  },
                                ),
                              ),
                              // 項目名用フォント（くらむぼん）。
                              title: Text(
                                entry.title,
                                style: localizedHeadingStyle(
                                  context,
                                  const TextStyle(fontSize: 15, height: 1.3),
                                ),
                              ),
                              subtitle: row.showCategory
                                  ? Text(
                                      entry.category,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    )
                                  : null,
                              children: [
                                // 実画面の簡易図解は用いず、文章での説明のみとする。
                                // 説明は名前と同じ位置から書き始める。
                                Padding(
                                  padding: const EdgeInsetsDirectional.fromSTEB(
                                    56,
                                    0,
                                    16,
                                    16,
                                  ),
                                  // 説明テキスト用フォント（白光明朝。アプリ全体の
                                  // 基本フォントを継承するため明示指定不要）。
                                  child: Text(
                                    entry.description,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorialEntry extends StatelessWidget {
  const _TutorialEntry();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // 使い方（図つきの数ページ）は分類の一覧の前に1行だけの面で置く。
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: GroupedSheet(
        children: [
          SheetRow(
            key: const Key('helpTutorialButton'),
            icon: Icons.school_outlined,
            title: l10n.helpTutorialButton,
            subtitle: l10n.helpTutorialSubtitle,
            onTap: () => AppTutorial.show(context),
          ),
        ],
      ),
    );
  }
}

/// ヘルプの一覧の1行：分類の名前（面の上）か、項目（面の行）。
class _HelpRow {
  const _HelpRow.header(String this.header)
    : entry = null,
      first = false,
      last = false,
      showCategory = false;

  const _HelpRow.entry(
    _HelpEntry this.entry, {
    required this.first,
    required this.last,
    this.showCategory = false,
  }) : header = null;

  final String? header;
  final _HelpEntry? entry;
  final bool first;
  final bool last;
  final bool showCategory;
}

class _HelpEntry {
  /// HelpButton(topic:)の呼び出し元と一致させるための固定識別子
  /// （表示言語に関わらず日本語のまま、翻訳対象外）。
  final String topicKey;
  final String title;
  final String description;
  final String category;

  const _HelpEntry({
    required this.topicKey,
    required this.title,
    required this.description,
    required this.category,
  });
}

/// 検索欄の枠（面と同じ細い縁）。
InputBorder _searchBorder(BuildContext context) {
  final theme = Theme.of(context);
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(
      color:
          theme.dividerTheme.color ??
          theme.colorScheme.outlineVariant.withValues(alpha: .6),
    ),
  );
}
