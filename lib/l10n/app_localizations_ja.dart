// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'NIARIM';

  @override
  String get homeTabProjects => 'プロジェクト';

  @override
  String get homeTabShared => '共有';

  @override
  String get homeTabTrash => 'ゴミ箱';

  @override
  String get homeTabWorks => '作品一覧';

  @override
  String get homeTabBookmarked => 'ブクマ済み';

  @override
  String get homeBookmarkedComingSoonTitle => '近日公開';

  @override
  String get homeBookmarkedComingSoonBody =>
      '「みんなのアニメを見る」機能の実装後、ブックマークした他ユーザーの公開作品をここに一覧表示できるようになります。';

  @override
  String get homeSearchHint => 'プロジェクト名で検索';

  @override
  String get homeBackToSplashTooltip => '起動画面に戻る';

  @override
  String get homeFavoritesOnly => 'お気に入り';

  @override
  String get homeAddSheetNewProject => '新規プロジェクト';

  @override
  String get homeAddSheetNewFolder => '新規フォルダ';

  @override
  String get homeSelectionAllSelect => '全選択';

  @override
  String get homeSelectionAllDeselect => '全解除';

  @override
  String get homeSelectionAddFavorite => 'お気に入りに登録';

  @override
  String get homeSelectionRemoveFavorite => 'お気に入りを解除';

  @override
  String homeSelectionCount(int count) {
    return '$count件選択中';
  }

  @override
  String get homeMoveToTrash => 'ゴミ箱へ移動';

  @override
  String homeMoveToTrashConfirm(int count) {
    return '$count件をゴミ箱へ移動しますか？';
  }

  @override
  String get commonMove => '移動';

  @override
  String get homeShareFileDialogTitle => '共有ファイル';

  @override
  String get homeShareFileDialogContent => 'この共有ファイルを複製して通常プロジェクトとして保存しますか？';

  @override
  String homeMissingFontsSnackbar(String names) {
    return '不足フォントがあります。$names';
  }

  @override
  String get homeSharedImportedSnackbar => 'プロジェクトタブへ追加しました';

  @override
  String homeSharedImportFailedSnackbar(String error) {
    return '共有ファイルの読み込みに失敗しました: $error';
  }

  @override
  String get homeViewModeLarge => '大';

  @override
  String get homeViewModeMedium => '中';

  @override
  String get homeViewModeSmall => '小';

  @override
  String get homeViewModeDetail => '詳細';

  @override
  String get homeSortNameAsc => '名前 ↑';

  @override
  String get homeSortNameDesc => '名前 ↓';

  @override
  String get homeSortUpdatedAsc => '更新日時 ↑';

  @override
  String get homeSortUpdatedDesc => '更新日時 ↓';

  @override
  String get homeSortFieldName => '名前';

  @override
  String get homeSortFieldUpdated => '更新日時';

  @override
  String get homeSortDirectionAscTooltip => '昇順（タップで降順に切り替え）';

  @override
  String get homeSortDirectionDescTooltip => '降順（タップで昇順に切り替え）';

  @override
  String get homeSharedEmpty => '共有プロジェクトがありません';

  @override
  String homeProjectMeta(int fps, int duration) {
    return '${fps}fps · $duration秒';
  }

  @override
  String get homeTrashEmpty => 'ゴミ箱は空です';

  @override
  String homeTrashDeletedOn(String date) {
    return '$date 削除';
  }

  @override
  String get homePermanentDelete => '完全削除';

  @override
  String get homePermanentDeleteConfirmTitle => '完全に削除しますか？';

  @override
  String get homePermanentDeleteConfirmBody => '元に戻すことはできません。';

  @override
  String get homeWorksEmpty => '書き出した作品がありません';

  @override
  String get homeWorksEmptyHint => 'キャンバスの書き出しから動画・GIFを作成すると\nここに表示されます';

  @override
  String get homeShareOpenWith => '共有・写真アプリ等で開く';

  @override
  String homeWorkDeleteConfirmTitle(String name) {
    return '$nameを削除しますか？';
  }

  @override
  String get homeWorkDeleteConfirmBody => '端末内の書き出しファイルが削除されます。元に戻すことはできません。';

  @override
  String get homePreviewFailed => 'プレビューを再生できません';

  @override
  String get homeFirstLaunchMessage => '手描きアニメーションを制作できます';

  @override
  String get homeFirstLaunchStart => 'はじめる';

  @override
  String get settingsScreenTitle => '設定';

  @override
  String get settingsBasicTitle => '基本';

  @override
  String get settingsBasicSubtitle => 'FPS・背景色・言語';

  @override
  String get settingsBasicSheetTitle => '基本設定';

  @override
  String get settingsDefaultFps => 'デフォルトFPS';

  @override
  String get settingsDefaultFpsSubtitle => '新規プロジェクト作成画面の初期値';

  @override
  String get settingsLanguage => '言語';

  @override
  String get settingsLanguageJapanese => '日本語';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageChinese => '简体中文';

  @override
  String get settingsLanguageKorean => '한국어';

  @override
  String get settingsLanguageTraditionalChinese => '繁體中文';

  @override
  String get settingsLanguageFrench => 'Français';

  @override
  String get settingsLanguageSpanish => 'Español';

  @override
  String get settingsSearchHint => '設定を検索...';

  @override
  String get settingsPerformanceTitle => 'パフォーマンス';

  @override
  String get settingsPerformanceSubtitle => '品質設定・Undo回数・ゴミ箱・動作の軽さ';

  @override
  String get settingsGestureTitle => 'ジェスチャー';

  @override
  String get settingsGestureSubtitle => '2本指タップ・長押し';

  @override
  String get settingsPenTitle => 'ペン入力';

  @override
  String get settingsPenSubtitle => '筆圧・傾き・ペンボタン';

  @override
  String get settingsWorkspaceTitle => 'ワークスペース';

  @override
  String get settingsWorkspaceSubtitle => 'ツールバー編集・パネル配置';

  @override
  String get settingsBucketTitle => 'バケツ塗り';

  @override
  String get settingsBucketSubtitle => '許容誤差・拡張・線の下まで潜る';

  @override
  String get settingsThemeTitle => 'テーマ・外観';

  @override
  String get settingsThemeSubtitle => 'テーマ設定・ワークスペース';

  @override
  String get settingsWatermarkTitle => 'ウォーターマーク';

  @override
  String get settingsWatermarkSubtitle => 'カスタムウォーターマーク';

  @override
  String get settingsTransferTitle => '引き継ぎ';

  @override
  String get settingsTransferSubtitle => '設定・素材・ブラシを他端末へ書き出し/読み込み';

  @override
  String get settingsFontTitle => 'フォント管理';

  @override
  String get settingsFontSubtitle => 'TTF/OTFの追加・検索・削除';

  @override
  String get settingsNoResults => '該当する設定項目が見つかりません';

  @override
  String get settingsTermsLicense => '利用規約・ライセンス';

  @override
  String get settingsDrawingAreaTitle => '描画領域初期値';

  @override
  String get settingsDrawingAreaHint => '新規プロジェクト作成時の初期値となります。';

  @override
  String get settingsDrawingAreaWiden => '描画領域を広くする';

  @override
  String get settingsDrawingAreaScale => '倍率';

  @override
  String settingsScaleValue(String scale) {
    return '$scale倍';
  }

  @override
  String get commonCancel => 'キャンセル';

  @override
  String get commonCreate => '作成';

  @override
  String get commonChange => '変更';

  @override
  String get commonDelete => '削除';

  @override
  String get confirmDeleteGenericBody => '本当に削除しますか？この操作は取り消せません。';

  @override
  String confirmDeleteNamedBody(String name) {
    return '「$name」を削除しますか？この操作は取り消せません。';
  }

  @override
  String get commonFavoriteDeleteBlocked =>
      'お気に入り登録中は削除できません。先にお気に入りを解除してください。';

  @override
  String get commonSave => '保存';

  @override
  String get commonRestore => '復元';

  @override
  String get commonClose => '閉じる';

  @override
  String get commonRename => '名前変更';

  @override
  String get commonCopy => 'コピー';

  @override
  String get commonCut => '切り取り';

  @override
  String get commonPaste => '貼り付け';

  @override
  String get commonDuplicate => '複製';

  @override
  String homePasteTooltip(int count) {
    return '$count件を貼り付け';
  }

  @override
  String get homePasteSnackbar => '貼り付けました';

  @override
  String get commonOk => 'OK';

  @override
  String get gestureSettingsTitle => 'ジェスチャー設定';

  @override
  String get gestureTwoFingerTap => '2本指タップ';

  @override
  String get gestureThreeFingerTap => '3本指タップ';

  @override
  String get gestureTwoFingerSwipe => '2本指スワイプ左右';

  @override
  String get gestureLongPress => '長押し';

  @override
  String get gestureHoldEyedropperSection => '長押しスポイト';

  @override
  String get gestureHoldEyedropperTitle => '長押しでスポイトを起動';

  @override
  String get gestureHoldEyedropperHint =>
      'ペン・消しゴムで描画中、指を動かさず一定時間押し続けると、その場の色を拾って現在色に反映します。';

  @override
  String get gestureHoldEyedropperDurationLabel => '保持時間';

  @override
  String gestureHoldEyedropperSecondsValue(String seconds) {
    return '$seconds秒';
  }

  @override
  String get gestureActionEyedropper => 'スポイト';

  @override
  String get gestureActionPanTool => '手のひらツール';

  @override
  String get gestureActionEraserToggle => '消しゴム切替';

  @override
  String get gestureActionBrushToggle => 'ブラシ切替';

  @override
  String get gestureActionFrameMove => 'フレーム移動';

  @override
  String get gestureActionNextTool => 'ツール早替え';

  @override
  String get gestureActionOnionSkinToggle => 'オニオンスキンON/OFF';

  @override
  String get gestureActionNone => '何もしない';

  @override
  String get homeDrawerAppTagline => '手描きアニメ制作アプリ';

  @override
  String get homeDrawerAutofillPreset => '自動塗り設定';

  @override
  String get homeDrawerSettings => '設定';

  @override
  String get homeDrawerHelp => 'ヘルプ';

  @override
  String get homeDrawerTips => '活用Tips';

  @override
  String get homeDrawerPremium => 'プレミアム';

  @override
  String get gestureActionNoneShort => 'なし';

  @override
  String get pressureTryDrawHint => 'この設定で試し書きできます（ペンの場合、実際の筆圧が反映されます）';

  @override
  String get pressureTryDrawClear => 'クリア';

  @override
  String get penSettingsTitle => 'ペン入力設定';

  @override
  String get penSettingsCurveSection => '筆圧カーブ';

  @override
  String get penSettingsCurveHint => '弱い設定ほど筆圧の立ち上がりが緩やかに、強い設定ほど鋭くなります。';

  @override
  String get penSettingsCurveWeak => '弱';

  @override
  String get penSettingsCurveNormal => '普通';

  @override
  String get penSettingsCurveStrong => '強';

  @override
  String get penSettingsCurveCustom => 'カスタム';

  @override
  String get penSettingsCustomGraphHint =>
      'グラフの空いている場所をタップすると点を追加（最大10個）、点をドラッグで移動、ダブルタップで削除できます（始点・終点は削除できません）。';

  @override
  String get penSettingsResetCurveButton => 'デフォルトにリセット';

  @override
  String get penSettingsPerBrushNote =>
      '※ 筆圧の「サイズ／不透明度に反映」設定はブラシごとの個別設定です（ブラシ設定パネルで変更）。';

  @override
  String get penSettingsButtonSection => 'ペンボタン設定';

  @override
  String get penSettingsButton1 => 'ボタン1';

  @override
  String get penSettingsButton2 => 'ボタン2';

  @override
  String get bucketSettingsTitle => 'バケツ塗り設定';

  @override
  String get bucketSettingsToleranceSection => '許容誤差';

  @override
  String get bucketSettingsToleranceHint =>
      'タップした位置の色からどこまでの色差を同じ領域とみなすかを調整します。値が大きいほど、色の境目がぼんやりしていても塗りが広がりやすくなります。';

  @override
  String get bucketSettingsExpandSection => '拡張';

  @override
  String get bucketSettingsExpandHint =>
      '塗った領域を境界の外側へ指定px分だけ広げ、線画とのわずかな隙間（塗り残し）をカバーします。';

  @override
  String get bucketSettingsUnderLineTitle => '線の下まで潜る';

  @override
  String get bucketSettingsUnderLineHint =>
      '拡張分を線画の上から塗りつぶさず、線の見た目を保ったまま背後へ塗り色を回り込ませます。線のアンチエイリアス部分に隙間が出にくくなります。';

  @override
  String get bucketSettingsUnderLineDisabledHint => '「拡張」が0pxの場合は効果がありません。';

  @override
  String fontCatalogSearchHint(int count) {
    return 'フォント名で検索...（全$count書体）';
  }

  @override
  String get fontCatalogAll => 'すべて';

  @override
  String get fontCatalogNoResults => '該当するフォントが見つかりません';

  @override
  String get rulerPanelTitle => '定規';

  @override
  String get rulerTypeLine => '直線定規';

  @override
  String get rulerTypeEllipse => '楕円定規';

  @override
  String get rulerTypeRadial => '集中線定規';

  @override
  String get rulerTypeOnePoint => '1点透視';

  @override
  String get rulerTypeTwoPoint => '2点透視';

  @override
  String get rulerTypeThreePoint => '3点透視';

  @override
  String get rulerDivisions => '分割数';

  @override
  String get transferScreenTitle => '引き継ぎ（.niatra）';

  @override
  String get transferInstructionHint => '他の端末へ引き継ぐ項目を選択してください。';

  @override
  String get transferItemSettings => '設定';

  @override
  String get transferItemMaterials => '素材';

  @override
  String get transferItemBrush => 'ブラシ';

  @override
  String get transferItemPresets => '自動塗り設定';

  @override
  String get transferItemTheme => 'テーマ';

  @override
  String get transferItemPalette => 'パレット（カラーピッカー・ドット絵専用）';

  @override
  String get transferProjectsSectionTitle => '制作中のプロジェクト（任意）';

  @override
  String get transferProjectsHint =>
      '必要なプロジェクトだけ選んで引き継ぎ内容に含められます。選択したプロジェクトは素材・フォントも含めて丸ごと引き継がれます。';

  @override
  String get transferProjectsEmpty => 'プロジェクトがありません。';

  @override
  String get transferImport => '読み込み';

  @override
  String get transferExport => '書き出し';

  @override
  String get transferExportSuccessSnackbar => '.niatraファイルを書き出しました';

  @override
  String transferExportFailedSnackbar(String error) {
    return '書き出しに失敗しました: $error';
  }

  @override
  String get transferImportSuccessSnackbar => '.niatraファイルを読み込みました';

  @override
  String transferImportFailedSnackbar(String error) {
    return '読み込みに失敗しました: $error';
  }

  @override
  String get folderManagementTitle => 'フォルダ管理';

  @override
  String get folderManagementCreateNew => '新規作成';

  @override
  String get folderManagementEmpty => 'フォルダはまだありません';

  @override
  String get folderNameLabel => 'フォルダ名';

  @override
  String get folderMoveToTitle => 'フォルダへ移動';

  @override
  String get folderNone => 'フォルダなし';

  @override
  String get creativeAssetNameLabel => '名前';

  @override
  String get commonAdd => '追加';

  @override
  String get commonSearch => '検索';

  @override
  String get autofillPresetSelectionTitle => '使用する自動塗り設定';

  @override
  String get autofillPresetSelectionHint =>
      'このプロジェクトで使う自動塗り設定だけを選ぶと、パーツ割り当て時に一覧が見やすくなります。';

  @override
  String autofillPresetSelectionPartCount(int count) {
    return '$countパーツ';
  }

  @override
  String get autofillPresetSelectionButton => '使用する自動塗り設定を選択';

  @override
  String get autofillPresetSelectionAllLabel => 'すべて使用';

  @override
  String autofillPresetSelectionCountLabel(int count) {
    return '$count件を使用';
  }

  @override
  String get commonEdit => '編集';

  @override
  String get commonFavoriteToggle => 'お気に入り登録/解除';

  @override
  String get commonIncrease => '増やす';

  @override
  String get commonDecrease => '減らす';

  @override
  String get commonPlay => '再生';

  @override
  String get commonPause => '一時停止';

  @override
  String get fontCatalogDownloadTooltip => 'フォントをダウンロード';

  @override
  String get timelineBackToCanvasTooltip => '保存してキャンバスに戻る';

  @override
  String get timelineBackToProjectListTooltip => 'プロジェクト一覧に戻る';

  @override
  String get timelineBackToProjectListDialogTitle => 'プロジェクト一覧に戻る';

  @override
  String get timelineBackToProjectListDialogBody => '変更を保存してから戻りますか？';

  @override
  String get timelineBackToProjectListSaveButton => '保存して戻る';

  @override
  String get timelineBackToProjectListDiscardButton => '保存せず戻る';

  @override
  String get timelineSkipToStart => '先頭フレームへ';

  @override
  String get timelineStepBack => '1フレーム戻る';

  @override
  String get timelineStepForward => '1フレーム進む';

  @override
  String get timelineSkipToEnd => '最終フレームへ';

  @override
  String get timelineLoopOnTooltip => 'ループ再生：ON（タップでOFFに）';

  @override
  String get timelineLoopOffTooltip => 'ループ再生：OFF（タップでONに）';

  @override
  String get quickToolPanelTitle => '早替えツール設定';

  @override
  String get quickToolEmpty => '登録されたツールがありません';

  @override
  String get quickToolAddCurrentBrush => '現在のブラシを追加';

  @override
  String get quickToolEraser => '消しゴム';

  @override
  String get quickToolEyedropper => 'スポイト';

  @override
  String get quickToolBucket => 'バケツ';

  @override
  String quickToolSizeDialogTitle(String brushName) {
    return '$brushNameのサイズ';
  }

  @override
  String get settingsShortcutTitle => 'ショートカット設定';

  @override
  String get settingsShortcutSubtitle => 'キーボード・左手デバイスにツールや操作を割り当て';

  @override
  String get shortcutSettingsTitle => 'ショートカット設定';

  @override
  String get shortcutSettingsHint =>
      'キーボードや左手デバイスのキーに、ツール（ブラシ・太さまで指定可）やUndo/Redoなどの操作を割り当てられます。キャンバス・タイムラインの両方で使えます。';

  @override
  String get shortcutEmpty => '登録されたショートカットがありません';

  @override
  String get shortcutCaptureTitle => 'キーを押してください';

  @override
  String get shortcutCaptureHint =>
      '設定したいキーの組み合わせを押してください（Ctrl・Shift・Altなどの修飾キーも同時に押せます）。Escで取り消します。';

  @override
  String shortcutChooseActionTitle(String combo) {
    return '$combo に何を割り当てますか？';
  }

  @override
  String get shortcutActionTypeTool => 'ツール選択';

  @override
  String get shortcutActionTypeCommand => '主要操作';

  @override
  String get shortcutCommandUndo => '取り消し（Undo）';

  @override
  String get shortcutCommandRedo => 'やり直し（Redo）';

  @override
  String get shortcutCommandToggleLayerPanel => 'レイヤーパネル切替（キャンバス）';

  @override
  String get shortcutCommandPlayPause => '再生／一時停止（タイムライン）';

  @override
  String get shortcutCommandPreviousFrame => '1フレーム戻る（タイムライン）';

  @override
  String get shortcutCommandNextFrame => '1フレーム進む（タイムライン）';

  @override
  String get shortcutCommandSelectAll => '全選択';

  @override
  String get shortcutCommandCopy => 'コピー';

  @override
  String get shortcutCommandCut => '切り取り';

  @override
  String get shortcutCommandPaste => '貼り付け';

  @override
  String get shortcutConflictTitle => 'すでに割り当てられています';

  @override
  String shortcutConflictBody(String combo, String existingLabel) {
    return '$combo には既に「$existingLabel」が割り当てられています。上書きしますか？';
  }

  @override
  String get shortcutConflictOverwrite => '上書き';

  @override
  String get materialListTitle => '素材管理';

  @override
  String materialRemoveUnused(int count) {
    return '未使用素材を削除 ($count)';
  }

  @override
  String get materialEmptyTitle => '素材がありません';

  @override
  String get materialEmptyHint => 'タイムラインから画像・動画・音声を追加すると\nここに一覧表示されます';

  @override
  String get materialUsedLabel => '使用中';

  @override
  String get materialUnusedLabel => '未使用';

  @override
  String get materialMissingLabel => '⚠ 不足';

  @override
  String get materialDeleteTooltipUsed => '使用中のため削除できません';

  @override
  String get materialRemoveOneConfirmTitle => '素材を削除しますか？';

  @override
  String get materialRemoveUnusedConfirmTitle => '未使用素材を一括削除しますか？';

  @override
  String get materialRemoveUnusedConfirmBody =>
      'プロジェクト内のどこからも参照されていない素材をまとめて削除します。この操作は元に戻せません。';

  @override
  String materialRemovedSnackbar(int count) {
    return '$count件の未使用素材を削除しました';
  }

  @override
  String get watermarkEmptyTitle => '登録されたウォーターマークがありません';

  @override
  String get watermarkEmptyHint => '右下の＋から画像または文字を登録してください';

  @override
  String get watermarkAddFromImage => '画像から追加';

  @override
  String get watermarkAddText => '文字を入力';

  @override
  String get watermarkAddedSnackbar => 'ウォーターマークを登録しました';

  @override
  String get watermarkTextDialogTitle => '文字ウォーターマークを追加';

  @override
  String get watermarkTextFieldLabel => '表示する文字';

  @override
  String get watermarkTextColorLabel => '文字色';

  @override
  String get watermarkTextColorTapHint => 'タップして色を選択';

  @override
  String get watermarkDropShadowLabel => 'ドロップシャドウ';

  @override
  String get watermarkShadowColorLabel => '影の色';

  @override
  String get watermarkShadowOffsetXLabel => '影の位置X';

  @override
  String get watermarkShadowOffsetYLabel => '影の位置Y';

  @override
  String get watermarkShadowBlurLabel => '影のぼかし';

  @override
  String get watermarkOutlineLabel => '縁取り';

  @override
  String get watermarkOutlineColorLabel => '縁の色';

  @override
  String get watermarkOutlineWidthLabel => '縁の太さ';

  @override
  String get premiumActiveLabel => 'プレミアム有効';

  @override
  String get premiumVsTitle => '無料版 vs プレミアム';

  @override
  String get premiumHeroTitle => 'プレミアムで、もっと自由な制作を';

  @override
  String get premiumHeroSubtitle =>
      '尺の上限なし・透かしなし・トーンカーブ／レベル補正など、制作の幅を広げる機能がすべて解放されます';

  @override
  String get premiumHeroHighlightDuration => '尺は最大2時間';

  @override
  String get premiumHeroHighlightWatermark => '透かしなし';

  @override
  String get premiumHeroHighlightGrading => 'トーンカーブ／\nレベル補正';

  @override
  String get premiumCampaignFreeNote =>
      '※ キャンペーン期間中は無料版でも上記プレミアム機能を全てご利用いただけます';

  @override
  String get premiumPlanSectionTitle => 'プラン';

  @override
  String get premiumStoreUnavailable => 'ストアに接続できません（実機・ストア審査環境以外では購入できません）';

  @override
  String get premiumYearlyTitle => '年額プラン（おすすめ）';

  @override
  String get premiumYearlyDescription => '実質2か月分無料';

  @override
  String get premiumYearlyPrice => '¥5,500/年';

  @override
  String get premiumYearlyOriginalPrice => '¥6,600';

  @override
  String get premiumYearlyPerMonthLabel => '月あたり¥458相当';

  @override
  String get premiumMonthlyTitle => '月額プラン';

  @override
  String get premiumRestorePurchases => '購入を復元';

  @override
  String get premiumRestoredSnackbar => '購入情報を復元しました（該当する購入がある場合）';

  @override
  String get premiumCampaignBannerTitle => 'リリース記念！有料会員限定機能解放キャンペーン';

  @override
  String get premiumCampaignBannerBody =>
      '期間中は無料版でも全てのプレミアム機能（尺2時間まで拡大・エンドロゴ編集・ウォーターマーク・トーンカーブ・レベル補正）を無料でご利用いただけます。';

  @override
  String premiumCampaignEndLabel(String date) {
    return '～$dateまで';
  }

  @override
  String get premiumComparisonFeature => '機能';

  @override
  String get premiumComparisonFree => '無料';

  @override
  String get premiumFeatureDrawing => 'アニメ制作・描画機能';

  @override
  String get premiumFeatureTimeline => 'タイムライン';

  @override
  String get premiumFeatureExport => '動画書き出し';

  @override
  String get premiumFeatureMaxDuration => '最大尺';

  @override
  String get premiumFeatureEndLogo => '公式エンドロゴ';

  @override
  String get premiumFeatureWatermark => 'ウォーターマーク';

  @override
  String get premiumFeatureToneCurve => 'トーンカーブ';

  @override
  String get premiumFeatureLevelCorrection => 'レベル補正';

  @override
  String get premiumFeatureAds => '広告';

  @override
  String get premiumFeatureCommunityUpload => 'みんなの作品への投稿数/日';

  @override
  String get premiumValueYes => 'あり';

  @override
  String get premiumValueNo => 'なし';

  @override
  String get premiumValueRemovable => '削除可';

  @override
  String get premiumValueDuration2Hours => '2時間';

  @override
  String get premiumValueDuration90Sec => '1.5分';

  @override
  String get premiumValueUploadFree => '1本';

  @override
  String get premiumValueUploadPremium => '3本';

  @override
  String get premiumPlanRecommendedBadge => 'おすすめ';

  @override
  String get premiumMonthlyPrice => '¥550/月';

  @override
  String get toolbarItemPen => 'Gペン';

  @override
  String get toolbarItemEraser => '消しゴム';

  @override
  String get toolbarItemBucket => 'バケツ';

  @override
  String get toolbarItemEyedropper => 'スポイト';

  @override
  String get toolbarItemFinger => '指';

  @override
  String get toolbarItemPan => '手のひら';

  @override
  String get toolbarItemSelect => '選択';

  @override
  String get toolbarItemTransform => '変形';

  @override
  String get toolbarItemText => 'テキスト';

  @override
  String get toolbarItemShape => '図形';

  @override
  String get workspaceScreenTitle => 'ワークスペース設定';

  @override
  String get workspaceToolbarEditSection => 'ツールバー編集';

  @override
  String get workspaceToolbarEditHint => '表示するツールをチェックボックスで選択し、ドラッグで並び替えできます。';

  @override
  String get workspaceToolbarPcOnlyHint => '横画面の時のみツールバーに表示されます';

  @override
  String get workspaceToolbarPanDisabledHint => 'スマホモードでは使用できません';

  @override
  String get workspaceResetToolbarDefault => 'デフォルトに戻す';

  @override
  String get workspacePanelLayoutSection => 'パネル配置';

  @override
  String get workspaceLeftHandedMode => '左利きモード';

  @override
  String get workspaceLeftHandedSubtitlePc => 'パネルを右側に配置';

  @override
  String get workspaceLeftHandedSubtitleMobile => 'PC/DeXモードでのみ設定できます';

  @override
  String get workspacePcModeSection => 'PCモード（DeX）';

  @override
  String get workspacePcModeHint =>
      '画面幅の広い環境では、パネルを常時表示するプロ向けの画面構成に自動で切り替わります。手動で固定したい場合はここで指定してください。';

  @override
  String get workspacePcModeAuto => '自動（画面幅で判定・推奨）';

  @override
  String get workspacePcModeAlwaysPc => '常にPCモード';

  @override
  String get workspacePcModeAlwaysMobile => '常にスマホモード';

  @override
  String get workspaceSaveSection => 'ワークスペース保存';

  @override
  String get workspaceSaveHint =>
      '左利きモード・PCモード・ツールバー・ツール早替え設定を名前を付けて保存し、後から呼び出せます。';

  @override
  String get workspaceSaveCurrentButton => '現在のワークスペースを保存';

  @override
  String get workspaceLoadButtonEmpty => 'ワークスペースを読み込み（未保存）';

  @override
  String get workspaceLoadButton => 'ワークスペースを読み込み';

  @override
  String get workspaceEmptyToolbar => '表示するツールがありません';

  @override
  String get workspaceSaveDialogTitle => 'ワークスペースを保存';

  @override
  String get workspaceSaveDialogLabel => '名前（例：アニメ用・線画用）';

  @override
  String get workspaceLoadRightHanded => '右利き';

  @override
  String get workspaceLoadLeftHanded => '左利き';

  @override
  String get helpScreenTitle => 'ヘルプ';

  @override
  String get helpSearchHint => '検索...';

  @override
  String get helpNoResults => '該当する項目が見つかりません';

  @override
  String get helpCategoryTool => 'ツール';

  @override
  String get helpCategoryLayer => 'レイヤー';

  @override
  String get helpCategoryAnimation => 'アニメーション';

  @override
  String get helpCategoryDrawing => '描画';

  @override
  String get helpCategoryBrush => 'ブラシ';

  @override
  String get helpCategoryPenInput => 'ペン入力';

  @override
  String get helpCategorySave => '保存';

  @override
  String get helpCategoryProjectManagement => 'プロジェクト管理';

  @override
  String get helpCategoryExport => '書き出し';

  @override
  String get helpCategoryPremium => 'プレミアム';

  @override
  String get helpCategorySettings => '設定';

  @override
  String get helpCategoryCommunity => 'コミュニティ';

  @override
  String get helpPenToolTitle => 'ペンツール';

  @override
  String get helpPenToolDesc =>
      'キャンバスに線を描くための基本ツールです。長押しでブラシの種類・太さ・色を変更できます（ダブルタップは簡易説明の表示）。板タブ・液晶タブレットの筆圧・傾きに対応しており、設定画面の「ペン入力」から筆圧カーブを調整すると筆圧の伝わり方（弱い力でどれだけ太さ・不透明度が変化するか）を細かくカスタマイズできます。ペンサブツールを切り替えると、同じペンツールからトーン貼り・スタンプ配置も行えます。';

  @override
  String get helpEraserToolTitle => '消しゴムツール';

  @override
  String get helpEraserToolDesc =>
      'ペンツールと対になる、描いた内容を消すためのツールです。ブラシと同様に太さ・不透明度を調整でき、フェードやストローク減衰などのブラシ設定も共通で反映されます。レイヤーの透明部分を「描き足す」のではなく既存の描画を「消す」処理を行うため、下のレイヤーが透けて見えるようになります。';

  @override
  String get helpBucketToolTitle => 'バケツツール';

  @override
  String get helpBucketToolDesc =>
      '囲まれた領域を一括で塗りつぶすツールです。線画で囲まれた範囲内をタップすると、その範囲全体が選択中の色（またはトーン）で塗られます。線画に隙間があると意図しない範囲まで塗り広がってしまうことがあるため、線画がきちんと閉じているか確認してから使うのがコツです。設定でベタ塗り／トーン塗りを切り替えられます。 詳細設定（許容誤差・拡張px・線の下まで潜る）は設定画面の「バケツ塗り」から調整できます。';

  @override
  String get helpLassoFillTitle => '投げ縄塗り';

  @override
  String get helpLassoFillDesc =>
      '囲みたい範囲を指でなぞって多角形の範囲を作り、その内側をまとめて塗るツールです。バケツツールと違い、線画が閉じていない部分があっても自分で囲む範囲を指定できるため、複雑な形や線が途切れている部分の塗りに向いています。';

  @override
  String get helpEyedropperToolTitle => 'スポイトツール';

  @override
  String get helpEyedropperToolDesc =>
      'タップした位置の色を拾って、描画色として選択するツールです。画面に実際に表示されている全レイヤーを合成した見た目の色を拾うため、複数レイヤーが重なっている部分でも「見た目通りの色」を正確に取得できます。';

  @override
  String get helpSelectToolTitle => '選択ツール';

  @override
  String get helpSelectToolDesc =>
      'キャンバスの一部分を範囲選択し、選択した範囲だけを移動・回転・拡大縮小できるツールです。長押しすると「矩形選択」「投げ縄選択（自由な形で囲む）」「自動選択（マジックワンド、似た色の範囲を自動でまとめて選択）」の3種類から選択方法を選べます。選択中は選択範囲を示す枠線がキャンバス上に表示され、選択を解除するまで全フレーム・全レイヤーで同じ範囲が固定表示されます。';

  @override
  String get helpFingerToolTitle => '指ツール（歪みツール）';

  @override
  String get helpFingerToolDesc =>
      '指でなぞった方向にピクセルを押し流すように歪ませる、液体絵の具を指でこすったような効果を作るツールです。細かい修正よりも、既に描いた線を有機的に歪ませて表情をつけたい時に使います。';

  @override
  String get helpShapeToolTitle => '図形ツール';

  @override
  String get helpShapeToolDesc =>
      '直線・四角形・円といった正確な図形をワンタップで描くためのツールです。ドラッグで始点から終点まで動かすとその場でプレビューされ、指を離すと確定します。フリーハンドでは描きにくい直線や正円が必要な時に便利です。';

  @override
  String get helpTextToolTitle => 'テキストツール';

  @override
  String get helpTextToolDesc =>
      'キャンバス上に文字を配置するツールです。フォント・サイズ・色・縦書き/横書きを選べます。縦書きでは半角英数字の自動回転・縦中横（数字を横向きのまま並べる表記）・ルビ（ふりがな）にも対応しています。配置したテキストは書き出し時にもピクセルとして焼き込まれます。 テキストツールで使えるフォントを追加・検索・削除できる画面です。初期同梱フォント以外の追加フリーフォントは、初期インストール容量を抑えるためここからオンデマンドでダウンロードする方式になっています。';

  @override
  String get helpQuickToolTitle => '早替えツール';

  @override
  String get helpQuickToolDesc =>
      'よく使うブラシ・ツールの組み合わせをあらかじめ登録しておき、ボタン一つで順番に切り替えられる機能です。キャンバス上の↺ボタンを長押しまたは上スワイプすると、登録・並べ替え・削除ができる管理ポップアップが開きます。ドラッグで並び順を変更できます。';

  @override
  String get helpLayerTitle => 'レイヤー';

  @override
  String get helpLayerDesc =>
      '1枚のキャンバスを複数の透明な「層」に分けて描画できる仕組みです。線画・色塗り・背景などを別々のレイヤーに分けて描くことで、後から色だけをやり直したり、線画を消さずに背景を差し替えたりできます。画面上では上に重なっているレイヤーほど手前に表示されます。各レイヤー行のアイコンからワンタップで削除・下のレイヤーとの結合ができ、レイヤーパネル上部のアイコンから表示中の全レイヤーを一括結合することもできます。';

  @override
  String get helpBlendModeTitle => 'ブレンドモード';

  @override
  String get helpBlendModeDesc =>
      'レイヤーの合成方法を変更する機能です。トーンやカラー効果をレイヤーとして重ねる時によく使われます。\n通常：そのまま重ねます。\n乗算：下のレイヤーと掛け合わせて暗くします。影・陰影づけの定番です。\nスクリーン：明るさを足し合わせて明るくします。光の表現に向きます。\nオーバーレイ：暗い部分はより暗く、明るい部分はより明るくしてコントラストを強めます。\n加算：色を単純に足し合わせます。光の効果線などに向きます。\n減算：色を差し引き、暗く沈んだ効果になります。\n比較（暗）：上下のレイヤーで暗い方の色を採用します。\n比較（明）：上下のレイヤーで明るい方の色を採用します。\n焼き込みカラー：下の色を暗く沈めながら濃く発色させます。\n覆い焼きカラー：下の色を明るく飛ばしながら発色させます。\nハードライト：オーバーレイより強くコントラストが付きます。\nソフトライト：オーバーレイより穏やかにコントラストが付きます。柔らかい陰影に向きます。\n差の絶対値：上下の色の差を表示します。色のズレ確認などに使えます。\n色相・彩度・カラー・輝度：それぞれ色相・彩度・色味・明るさだけを下のレイヤーへ反映します。';

  @override
  String get helpClippingTitle => 'クリッピング';

  @override
  String get helpClippingDesc =>
      '自分のすぐ下にあるレイヤーの、不透明なピクセルの範囲内にのみ描画されるようにする機能です。線画からはみ出さずに色を塗りたい時、線画レイヤーの上に色塗り用レイヤーを作ってクリッピングを有効にすると、線画の外側にうっかりはみ出して描いてしまう心配がなくなります。';

  @override
  String get helpCommonLayerTitle => '共通レイヤー';

  @override
  String get helpCommonLayerDesc =>
      '通常のレイヤーは1フレームごとに独立していますが、共通レイヤーは複数のフレーム・シーンで同じ内容を共有するレイヤーです。背景などフレームが変わっても動かさない要素を、フレームごとに描き直す手間なく一度描くだけで済ませられます。タイムライン上では専用のトラックとして表示されます。 通常レイヤーを共通レイヤー（複数フレームに同じ内容を表示し続けるレイヤー）へ変換できる機能です。表示中のレイヤーを複製して1枚に統合してから共通化することもできます。背景など毎フレーム同じ内容を使い回したい場合に、描き直す手間を省けます。';

  @override
  String get helpAutoFillTitle => '自動塗り';

  @override
  String get helpAutoFillDesc =>
      '自動塗り用線画レイヤーの下に自動塗りレイヤーを作り、あらかじめ作成した「自動塗り設定」（パーツごとの色・トーンの組み合わせ）に基づいて色を自動で塗る機能です。線画を描き終えた後に一括で色を塗れるため、同じキャラクターを何度も描く手描きアニメーションで色塗りの手間を大幅に減らせます。線画を描き直した場合はタイムライン・レイヤーパネルに更新マーク（❗）が表示され、自動塗りの再実行が必要なことを知らせます。 タイムライン画面の三点メニューから「自動塗り実行」を選ぶと、更新マーク（❗）が付いた自動塗りレイヤーをまとめて再計算できます。線画を描き直した後に1枚ずつレイヤーパネルで実行する手間を省けます。 自動塗り設定の各パーツには、線画の色をどう扱うかの設定（指定色・塗り色と同じ・色トレス）があります。色トレス（線画馴染ませ）を選ぶと、線画の色を塗り色に合わせてHSLシフトし、線が浮かずに馴染んだ仕上がりになります。 設定が増えてくると、パーツ割り当て時の一覧が長くなって選びにくくなります。プロジェクト設定（またはレイヤーパネルのパーツ割り当てダイアログ）から、このプロジェクトで使う設定だけに絞り込んでおくと、一覧がすっきりして選びやすくなります。';

  @override
  String get helpOnionSkinTitle => 'オニオンスキン';

  @override
  String get helpOnionSkinDesc =>
      '現在編集中のフレームの前後のフレームを半透明で重ねて表示し、動きの繋がりを確認しながら描けるようにする機能です。パフォーマンス設定で表示する枚数（前後何枚まで）や色・透明度を調整できます。';

  @override
  String get helpRulerTitle => '定規';

  @override
  String get helpRulerDesc =>
      '直線・円・楕円・パース定規（消失点を使った透視図法用の定規）など、フリーハンドでは描きにくい正確な線を補助するための機能です。配置した定規に沿ってペン先が自動でスナップするため、定規なしでは難しい奥行きのある構図も描きやすくなります。定規はハンドルを操作して移動・回転・サイズ変更ができます。';

  @override
  String get helpFadeTitle => 'フェード';

  @override
  String get helpFadeDesc =>
      'ブラシ設定の一つで、ストロークを描き進めるにつれて不透明度や太さが徐々に減少していく効果です。線の端をかすれさせたい時や、余韻を残すような描き味を作りたい時に使います。';

  @override
  String get helpStrokeDecayTitle => 'ストローク減衰';

  @override
  String get helpStrokeDecayDesc =>
      'フェードと似ていますが、こちらは「インクが減っていく」ような表現に近く、描き続けるほど色が薄くなったりかすれたりする効果です。筆やマーカーで描き続けた時のインク切れのような質感を再現します。';

  @override
  String get helpColorMixingTitle => '混色';

  @override
  String get helpColorMixingDesc =>
      'ブラシで塗る際、ブラシの直下にすでにある色と、これから塗ろうとしている選択色を混ぜ合わせながら描画する機能です。水彩や油彩のように、既存の色に新しい色をなじませたい時に使います。';

  @override
  String get helpPressureCurveTitle => '筆圧カーブ';

  @override
  String get helpPressureCurveDesc =>
      'ペン入力設定にある機能で、実際の筆圧の強さと、ブラシの太さ・不透明度への反映のされ方の関係をグラフで自由に調整できます。弱い筆圧でも太く出したい人、逆に強く押さないと太くならないようにしたい人など、手癖に合わせて描き心地を細かくカスタマイズできます。設定変更後はその場で試し書きしながら確認できます。';

  @override
  String get helpTimelineTitle => 'タイムライン';

  @override
  String get helpTimelineDesc =>
      'アニメーションの時間軸を管理する画面です。フレーム（静止画1コマ）を並べてパラパラ漫画のように再生することでアニメーションになります。画像・動画・音声などの素材トラック、共通レイヤートラック、カメラキーフレームも同じタイムライン上で管理します。';

  @override
  String get helpSceneTitle => 'シーン';

  @override
  String get helpSceneDesc =>
      '1つのプロジェクト（1本の動画）の中を、場面（カット）ごとに分割して管理する機能です。フォルダがプロジェクト単位の整理なのに対し、シーンは1本の動画の中の場面転換を表現するために使います。タイムラインのシーンタブでは、シーンの追加・複製・削除・名前変更・並び替えができます。複数選択モードにすると複数シーンをまとめて移動・複製・削除することも可能です。';

  @override
  String get helpCameraKeyframeTitle => 'カメラキーフレーム';

  @override
  String get helpCameraKeyframeDesc =>
      'タイムライン上の特定の位置にカメラの位置・拡大率・回転を記録しておく機能です。キーフレーム間は自動で滑らかに補間されるため、パン（横移動）やズームイン・ズームアウトのようなカメラワークを簡単に付けられます。';

  @override
  String get helpEffectFilterTitle => '演出フィルター';

  @override
  String get helpEffectFilterDesc =>
      'シーンやフレームに適用できる映像効果（ぼかし・色調補正・グロー・ピクセレート等）です。手描きの絵そのものを変えずに、演出として画面全体の見た目を調整したい時に使います。ピクセレートは配色方式（色を指定しない・色を指定する・色数を指定する・パレットから選ぶ）も選べます。 演出フィルターは複数重ねて適用でき、その適用順はタイムライン上での並び順に従います。フィルター一覧をドラッグで並び替えると、実際に画面へ反映される順序も変わります。 フィルムの粒状感のようなノイズをフレームごとに変化させながら適用する演出フィルターです。強度・量（ノイズが乗る密度）・粒の大きさをスライダーで調整できます。同じフレームに戻ると同じ粒状になるため、スクラブ中にちらつかず、再生すると粒が動いて見えます。 画面に降る雨を表現する演出フィルターです。降り方（本数）・速さ・粒の大きさ・風向きの角度をスライダーで調整できます。各雨粒はフレームが進むごとに一定の速度で降り続けるため、自然な雨の動きになります。';

  @override
  String get helpEndCardTitle => 'エンドカード';

  @override
  String get helpEndCardDesc =>
      '動画書き出し時、本編の終わりに自動で追加されるNIARIMロゴの短い動画（約5秒）です。無料版では非表示・削除ができませんが、プレミアム会員になると表示のON/OFF・長さ変更・差し替えができるようになります。';

  @override
  String get helpAutoSaveTitle => '自動保存';

  @override
  String get helpAutoSaveDesc =>
      'クラッシュやファイル破損が起きた時のための復元専用の保存です。描画などの変更があるたびに自動で保存され、最大3件まで古い順に上書きされます。手動保存（セーブスロット・セーブツリー）とは完全に別で管理されており、通常の保存の代わりにはなりません。アプリを異常終了した後の再起動時のみ、復元するかどうかを尋ねられます。';

  @override
  String get helpSaveSlotTitle => 'セーブスロット';

  @override
  String get helpSaveSlotDesc =>
      '決まった数の保存枠（スロット）に、自分で保存先を選びながら保存する方式です。スロット数は設定（低品質5件・中品質10件）で決まります。上書きしたい枠を毎回自分で選ぶため、「このタイミングの状態は残しておきたい」という管理がしやすい方式です。';

  @override
  String get helpSaveTreeTitle => 'セーブツリー';

  @override
  String get helpSaveTreeDesc =>
      '保存するたびに新しい保存地点が作られ、過去の保存地点から分岐して別の履歴を作れる（枝分かれする）保存方式です。件数の上限がなく、「あの時のバージョンに戻ってから別の展開を試したい」といった使い方に向いています。画面には保存地点が下から上へ伸びる樹形図として表示されます。';

  @override
  String get helpFolderTitle => 'フォルダ';

  @override
  String get helpFolderDesc =>
      'プロジェクト（作品）をグループ化して整理する機能です。複数階層に対応しているので、同じ作品の複数話数やシリーズ物をまとめて管理する使い方もできます（例：「作品名」フォルダの中に「第1話」「第2話」…とプロジェクトを並べる）。1つの動画の中で場面を分けて作りたい場合は、フォルダではなくキャンバス画面の「シーン」機能をご利用ください。';

  @override
  String get helpTrashTitle => 'ゴミ箱';

  @override
  String get helpTrashDesc =>
      '削除したプロジェクトが一時的に移動する場所です。完全に削除するまではここから元に戻せます。設定で自動削除までの日数（OFF/30日/60日/90日）を指定できます。';

  @override
  String get helpShareTitle => '共有（.niashare）';

  @override
  String get helpShareDesc =>
      'プロジェクトを他の人（または自分の他の端末）へ渡すための共有専用ファイル形式です。受け取った側がこのファイルを開くと、複製されて自分のプロジェクト一覧に追加されます。共有元の.niashare自体は変更されません。';

  @override
  String get helpTransferTitle => '引き継ぎ（.niatra）';

  @override
  String get helpTransferDesc =>
      '設定・素材・ブラシ・自動塗り設定・テーマ・パレット（カラーピッカー用・ドット絵専用）など、アプリ全体の環境を別の端末へまとめて引き継ぐための機能です。引き継ぐ項目はチェックボックスで個別に選べます。個別のプロジェクトを渡したい場合は「共有（.niashare）」を使います。';

  @override
  String get helpVideoExportTitle => '動画書き出し（MP4・WebM・GIF）';

  @override
  String get helpVideoExportDesc =>
      '作品を汎用的なMP4動画として書き出します。無料版は書き出せる長さに上限（90秒）があり、動画の最後にエンドカード（アプリロゴ）が自動で追加されます。 アルファチャンネル（背景の透明部分）を保持したまま書き出せる動画形式です。対応する再生環境でのみ透過再生されます。他のアプリの素材として重ねて使いたい場合などに向いています。 アニメーションGIFとして書き出します。自動でループ再生される形式のため、SNSへの投稿など気軽に共有したい場面に向いています。 互換性を重視したい場合はAVI（Motion JPEG）としても書き出せます。特許・ライセンス面で安全なコーデックを採用していますが、アルファチャンネル（透過）には対応せず、端末によってはアプリ内プレビューが利用できない場合があります（その場合も「共有」から外部プレイヤーで再生できます）。 無料会員はプロジェクトの長さに90秒までの上限があります（プレミアム会員は2時間）。フレーム追加・複製によって上限を超えそうな場合は、ボタンをタップした時点で注意ダイアログが表示され、実際に90秒を超えることはありません。';

  @override
  String get helpTransparentWebmTitle => '透過WebM';

  @override
  String get helpCommunityTitle => '作品広場';

  @override
  String get helpCommunityDesc =>
      'アニメ・イラスト作品をYouTube動画としてコミュニティに投稿し、他のユーザーの作品を閲覧できる機能です。「新着」「ランキング」「フォロー中」の3タブで一覧を切り替えられ、作品タイトルまたは投稿者名で検索できるほか、タグ検索モードに切り替えるとタグから作品を絞り込めます。タグは投稿者以外のユーザーも自由に追加・削除でき（投稿者がロックしたタグは投稿者本人にしか外せません）、タグをタップするだけでも同じタグの作品に絞り込めます。作品カードをタップするとドラッグ・リサイズできるフローティングプレビューウィンドウが開き、他の画面を操作しながら視聴を続けられます。「詳細へ」ボタンで作品の詳細画面（投稿者・投稿日・タグ編集・ブックマーク・リポストなど）を開けます。作者名の横の「フォロー」ボタンでフォローすると、「フォロー中」タブでその作者の投稿だけを新着順にまとめて追いかけられます。フォローされると画面右上のベルアイコンの通知一覧に届きます。自分のフォロー中/フォロワー一覧を全体公開するかどうかも設定でき（既定は非公開）、公開設定にしている他のユーザーの一覧も閲覧できます。他者の作品（自分の投稿を除く）は「リポスト」ボタンで再投稿でき、フォロー中の作者が誰かの作品をリポストすると、その作品も「投稿日時」と「リポスト日時」のうちより新しい方を基準に「フォロー中」タブへ混ざって表示されます（カードに「○○さんがリポスト」と表示）。ブックマークした作品はホーム画面の「ブクマ済み」タブにまとめて表示されるほか、投稿者別の作品一覧画面の「ブックマーク」タブでも確認できます。自分のブックマーク一覧はユーザー全体へ公開するかどうかを設定でき（既定は非公開）、公開設定にしている他のユーザーのブックマーク一覧も閲覧できます。不適切な作品は理由を添えて通報でき、送信後にはその投稿者をブロックするか選べます。縦長の動画は「縦画面モード」でTikTok風に連続再生して視聴できます。投稿できる本数には1日あたりの上限があり、無料会員は1日1本、プレミアム会員は1日3本までです。';

  @override
  String get helpWatermarkEntryTitle => 'ウォーターマーク';

  @override
  String get helpWatermarkEntryDesc =>
      '書き出した動画・画像に、自分の署名やロゴを透かしとして入れられるプレミアム限定機能です。位置・大きさ・不透明度を調整できます。タイムラインの共通レイヤートラックに配置したウォーターマークをタップすると、角度・大きさ・不透明度・表示範囲（ループ表示）をいつでも再編集できます。登録時だけでなく、実際にプロジェクト内で使うタイミングで細かく調整できます。';

  @override
  String get helpPremiumEntryTitle => 'プレミアム';

  @override
  String get helpPremiumEntryDesc =>
      'プレミアム会員になると、無料版で90秒までに制限されている動画の尺が最大2時間まで拡大され、動画の最後に自動追加されるエンドカード（アプリロゴ）を削除できます。広告も非表示になり、ウォーターマーク・トーンカーブ・レベル補正機能も利用できるようになります。';

  @override
  String get helpPerformanceSettingsTitle => 'パフォーマンス設定';

  @override
  String get helpPerformanceSettingsDesc =>
      '端末の性能に応じて、低品質・中品質・高品質のプリセットから選ぶか、各項目を個別に設定（カスタム）できます。保存方式・動作の軽さ・オニオンスキン・傾き検知に加えて、Undo回数やゴミ箱の自動削除などアプリの容量・動作の重さに影響する設定もここにまとまっています。';

  @override
  String get helpMaterialClipTitle => '素材クリップ（画像・動画・音声）';

  @override
  String get helpMaterialClipDesc =>
      'タイムラインの画像・動画・音声トラックに配置したクリップです。クリップ本体を長押しドラッグすると表示開始位置を移動でき、左右端のハンドルをドラッグすると使用範囲（長さ）を変更できます。タップすると開く詳細シートのコピーアイコンから複製、ゴミ箱アイコンから削除もできます。画像・動画は内部的にはレイヤーとして扱われており、音声はシーンに直接紐づくクリップとして管理されます。';

  @override
  String get helpGestureSettingsTitle => 'ジェスチャー設定';

  @override
  String get helpGestureSettingsDesc =>
      '2本指タップ・3本指タップ・2本指スワイプ・長押しに、Undo/Redo・フレーム移動・スポイトなどの操作を割り当てられる設定です。ペンボタン（対応スタイラス使用時）にも別途操作を割り当てられます。指を使わずワンタッチで頻用操作を呼び出したい場合に便利です。';

  @override
  String get helpBucketDetailSettingsTitle => 'バケツ塗り詳細設定';

  @override
  String get helpBucketDetailSettingsDesc =>
      '設定画面の「バケツ塗り」から、許容誤差（クリックした位置の色からどこまでの色差を同一領域とみなすか）・拡張px（塗った範囲を境界の外側へ広げて線画との隙間を埋める量）・線の下まで潜る（拡張分を線画の上から上書きせず、線の見た目を保ったまま背後へ塗り色を合成する）を調整できます。線画に細かい隙間がある場合や、塗り残しが気になる場合に調整すると仕上がりが安定します。';

  @override
  String get helpStampToolTitle => 'スタンプツール';

  @override
  String get helpStampToolDesc =>
      'あらかじめ登録した画像をブラシのようにキャンバスへ配置するツールです。効果線・背景パターン・小物などを毎回描き直さずに使い回せます。ピクセルモードをONにすると、貼り付けたスタンプをモザイク低解像度化＋色数削減でドット絵風に加工できます。 スタンプパネルでは配置するスタンプの回転角度・大きさを調整できます。同じスタンプでも向きやサイズを変えて配置すれば、単調にならず自然な効果線・小物の並びを作れます。';

  @override
  String get helpToneFillTitle => 'トーン塗り';

  @override
  String get helpToneFillDesc =>
      'バケツツールの設定でベタ塗りからトーン塗りへ切り替えると、選択した網点・ライン柄などのトーンパターンで塗りつぶせます。ピクセルモード専用の市松模様・格子柄トーンも用意されており、ドット絵の質感を活かした塗りができます。';

  @override
  String get helpPixelModeTitle => 'ピクセルモード';

  @override
  String get helpPixelModeDesc =>
      'ブラシ・フォント・スタンプのそれぞれに用意されている設定で、ONにするとアンチエイリアスを取り除き、くっきりとしたドット絵風の輪郭で描画されます。あえて古いゲームのような質感を出したい時や、低解像度感を演出したい時に使います。配色方式は「色を指定しない」「色を指定する」「色数を指定する」「パレットから選ぶ」の4種類から選べ、ドット絵専用パレットを使った配色もできます。';

  @override
  String get helpHomeScreenTitle => 'ホーム画面';

  @override
  String get helpHomeScreenDesc =>
      'アプリを起動して最初に表示される画面で、プロジェクト・共有・作品一覧・ゴミ箱の各タブを切り替えて閲覧できます。右上の検索アイコンからプロジェクト名で絞り込み検索もできます。プロジェクトタブでは新規プロジェクト作成とフォルダ作成を画面右下の＋ボタンから選べます。';

  @override
  String get helpNewProjectTitle => '新規プロジェクト作成';

  @override
  String get helpNewProjectDesc =>
      'キャンバスサイズ・fps・長さ（秒数。あとからタイムラインでのフレーム増減にも連動）・描画領域（書き出し範囲より広く描いておける設定）・使用する自動塗り設定などをまとめて指定してからプロジェクトを作成します。';

  @override
  String get helpThemeSettingsTitle => 'テーマ設定';

  @override
  String get helpThemeSettingsDesc =>
      'アプリ全体の配色をテーマ一覧から選んだり、差し色を自由にカスタマイズしたりできる画面です。見出し・項目名用フォントと説明文用フォントが分かれており、視認性を保ちながら着せ替えを楽しめます。';

  @override
  String get helpWorkspaceSettingsTitle => 'ワークスペース設定';

  @override
  String get helpWorkspaceSettingsDesc =>
      '左利きモード（ドッキングパネルを左右反転）、PC/DeXモードの手動切替、手のひらツールの表示条件などをまとめて設定できる画面です。使用端末や利き手に合わせて作業しやすいレイアウトに調整できます。';

  @override
  String get helpPenSettingsTitle => 'ペン設定';

  @override
  String get helpPenSettingsDesc =>
      '板タブ・液晶タブレットの筆圧カーブに加えて、ペン側面のボタン（対応スタイラス使用時）に消しゴム切替やスポイトなどの操作を割り当てられる設定画面です。';

  @override
  String get helpMaterialListTitle => '素材一覧';

  @override
  String get helpMaterialListDesc =>
      'プロジェクトで使用している画像・動画・音声素材をまとめて確認できる画面です。タイムラインへ配置した素材の元ファイルがここに集約されます。';

  @override
  String get helpFrameOperationsTitle => 'フレーム操作';

  @override
  String get helpFrameOperationsDesc =>
      'フレーム一覧では新規追加・複製・削除に加えて、複数選択モードで複数フレームをまとめて移動・複製・削除できます。保持セル数を増やすと同じフレームを複数コマ分表示させ続けられる（いわゆる「止め」）ので、動きの少ないカットで枚数を節約できます。';

  @override
  String get helpSceneOperationsTitle => 'シーン操作';

  @override
  String get helpSceneOperationsDesc =>
      'タイムラインのシーンタブでは、シーンの追加・複製・削除・名前変更・並び替えができます。複数選択モードにすると複数シーンをまとめて移動・複製・削除することも可能です。';

  @override
  String get helpQuickToolManagementTitle => '早替えツール管理';

  @override
  String get helpQuickToolManagementDesc =>
      'よく使うツールの組み合わせを登録し、タップひとつで順番に切り替えられる機能です。長押しまたは上スワイプで管理ポップアップを開き、登録内容や並び順を編集できます。';

  @override
  String get helpTransformSelectionTitle => '選択範囲の変形';

  @override
  String get helpTransformSelectionDesc =>
      '選択ツールで囲んだ範囲は、変形ツールで移動・回転・拡大縮小できます。誤って描いた部分の位置調整や、一部だけを拡大して強調したい時などに使います。 レイヤー全体を対象にしたい場合は、範囲選択を使わない「自由変形・メッシュ変形」（編集メニューから開く）を使うと、格子点を個別にドラッグしてより自由な変形ができます。';

  @override
  String get helpGradientAutofillTitle => 'グラデーション塗り（自動塗り設定）';

  @override
  String get helpGradientAutofillDesc =>
      '自動塗り設定の各パーツには単色だけでなくグラデーションも設定できます。ドラッグで移動できる対称ハンドルにより、直感的にグラデーションの範囲・角度を調整できます。 各パーツには「指定色で縁取り」も設定できます。チェックを入れると、塗り範囲の一番外側（線画に接する部分）に指定した色・太さのラインが引かれます。縁取り色はカラーピッカーで自由に選べ、太さはスライダー・±ボタン・数値タップでの直接入力のいずれでも調整できます。設定項目のすぐ上にプレビューが表示されるため、実際に自動塗りを実行する前に色と太さを確認できます。';

  @override
  String get helpColorPickerTitle => 'カラーピッカー';

  @override
  String get helpColorPickerDesc =>
      'HSVとRGBを1つの画面で切り替えながら色を選べるカラーピッカーです。パレット機能で使用中のカラーセットを保存・呼び出しできます。パレットはファイル書き出しやQRコードで他の端末と共有することもできます。';

  @override
  String get helpUndoSettingsTitle => 'Undo（元に戻す）回数設定';

  @override
  String get helpUndoSettingsDesc =>
      'パフォーマンス設定から、Undoで遡れる操作回数を調整できます。回数を増やすほど安心して試行錯誤できますが、メモリ使用量も増えるため、低スペック端末では回数を抑えると動作が軽くなります。';

  @override
  String get helpBrushFavoriteTitle => 'ブラシのお気に入り';

  @override
  String get helpBrushFavoriteDesc =>
      'ブラシ一覧の各ブラシにある星アイコンをタップすると、お気に入り登録・解除ができます（自動塗り設定・スタンプ・フォント・描画フィルターなど、アプリ内の他のお気に入り機能と同じ操作方法です）。一覧上部の星アイコンで、お気に入りのみ表示に絞り込むこともできます。誤って削除しないよう、お気に入り登録中のブラシは削除できません。';

  @override
  String get helpCustomBrushTitle => 'カスタムブラシ';

  @override
  String get helpCustomBrushDesc =>
      'ブラシ一覧でプリインストールのブラシを長押しして「複製」すると、それを元にした自分専用のカスタムブラシが作成されます。複製したブラシは太さ・不透明度・硬さ・回転・密度・散布・ぼかし半径などのパラメータを自由に編集でき、不要になれば削除もできます（プリインストールのブラシ自体は編集・削除できません）。フォルダで分類したり、星アイコンでお気に入り登録することもできます。';

  @override
  String get helpLayerFolderTitle => 'レイヤーフォルダ';

  @override
  String get helpLayerFolderDesc =>
      '複数のレイヤーをフォルダにまとめて整理できる機能です。パーツ数が多いイラストでもレイヤーパネルが見やすくなります。クリッピングはフォルダをまたいで適用できない仕様のため、クリッピングを使う場合は同じフォルダ内でまとめておくと安全です。';

  @override
  String get helpLayerMultiSelectTitle => 'レイヤーの複数選択・一括操作';

  @override
  String get helpLayerMultiSelectDesc =>
      'レイヤーパネルの選択モードを使うと、複数のレイヤーをチェックボックスでまとめて選び、結合や一括削除ができます。結合は通常・自動塗り用線画・自動塗りレイヤー同士でのみ可能です（共通レイヤー・フォルダ・タイムライン素材は結合対象外）。';

  @override
  String get helpDrawingAreaTitle => '描画領域';

  @override
  String get helpDrawingAreaDesc =>
      '書き出し範囲よりも広い範囲まで描いておける設定です。キャンバス上には書き出し範囲を示す赤枠が表示され、枠の外側にはみ出して描いた部分は書き出されませんが、パン・ズームなどのカメラワークで見せる範囲を後から調整する余地を残せます。新規プロジェクト作成時に倍率を設定します。';

  @override
  String get helpCanvasBackgroundTitle => 'キャンバスの背景色';

  @override
  String get helpCanvasBackgroundDesc =>
      'プロジェクトのキャンバス背景色を設定できます。透過書き出し（透過WebM）を使う場合は背景色は書き出しに影響しませんが、作業中の見やすさのために好みの色に変更できます。';

  @override
  String get helpProjectDetailTitle => 'プロジェクト詳細画面';

  @override
  String get helpProjectDetailDesc =>
      'プロジェクト名・サムネイル・お気に入り登録・使用する自動塗り設定の絞り込みなど、プロジェクト単位の設定をまとめて確認・編集できる画面です。セーブツリーへの入り口もここにあります。';

  @override
  String get helpWatermarkEditTitle => 'ウォーターマークの再編集';

  @override
  String get helpWatermarkEditDesc =>
      'タイムラインの共通レイヤートラックに配置したウォーターマークをタップすると、角度・大きさ・不透明度・表示範囲（ループ表示）をいつでも再編集できます。登録時だけでなく、実際にプロジェクト内で使うタイミングで細かく調整できます。';

  @override
  String get helpAudioClipTitle => '音声クリップの音量・フェード';

  @override
  String get helpAudioClipDesc =>
      'タイムラインに配置した音声クリップは、詳細シートから音量・フェードイン・フェードアウトの秒数を調整できます。効果音やBGMの音量バランスを整えたり、曲の始まり・終わりを滑らかにしたりできます。';

  @override
  String get helpPenSubToolTitle => 'ペンサブツール';

  @override
  String get helpPenSubToolDesc =>
      'ペンツールを長押しすると、通常の描画に加えてトーン貼り・スタンプ配置のサブツールへ切り替えられます。ツールをいちいち切り替えずに、同じペンから複数の作業を行き来できます。';

  @override
  String get helpTiltDetectionTitle => '傾き検知';

  @override
  String get helpTiltDetectionDesc =>
      '対応スタイラスの傾き情報を使って、筆先を寝かせたときに線を太く・薄くするなど、実際の筆記具に近い描き心地を再現する設定です。パフォーマンス設定からON/OFFを切り替えられます。';

  @override
  String get helpFontImportTitle => 'フォントの読み込み';

  @override
  String get helpFontImportDesc =>
      '端末内のフォントファイルを直接読み込んで使えるようにする機能です。設定画面のフォント管理「読み込み」タブから追加できます。配信されていない自作フォントや購入した商用フォントを使いたい場合に利用します。';

  @override
  String get helpExportScreenTitle => '書き出し画面';

  @override
  String get helpExportScreenDesc =>
      '動画・画像の書き出し中は進捗状況が表示され、途中でキャンセルすることもできます。書き出しにかかる時間は端末の性能によって変わります。';

  @override
  String get helpDrawingFilterTitle => '描画フィルター';

  @override
  String get helpDrawingFilterDesc =>
      '選択中のレイヤーに直接適用するフィルターです（演出フィルターがタイムライン全体・シーン単位に適用されるのに対し、描画フィルターはレイヤー単位）。ぼかし・シャープ・アンシャープマスク・トーンカーブ・レベル補正・周辺減光・ノイズ・レトロアニメ・ブラウン管・アニメ調・縁取り・ピクセレートなどが用意されています。縁取りは元のレイヤーを書き換えず、縁どった内容だけを新規レイヤーへ描画します。ピクセレートは配色方式（色を指定しない・色を指定する・色数を指定する・パレットから選ぶ）も選べます。';

  @override
  String get helpLayerKeyframeTitle => 'レイヤーキーフレーム（パーツ単位アニメーション）';

  @override
  String get helpLayerKeyframeDesc =>
      '各レイヤーの位置・拡大縮小・回転をフレームごとに指定し、キーフレーム間を自動で補間する機能です。カメラキーフレームが画面全体を動かすのに対し、こちらは個々のレイヤーだけを動かします。自動塗りの各パーツはそれぞれ独立したレイヤーとして生成されるため、パーツ単位でのアニメーション（腕だけ動かす、口だけ開閉させる等）にそのまま使えます。各キーフレームには「等速」「ゆっくり始まる」「ゆっくり終わる」「ゆっくり始まって終わる」「弾む」というイージング（次のキーフレームへのつなぎ方）を個別に設定でき、単調な等速移動だけでなく弾むような動きも表現できます。レイヤーパネルの三点メニュー「アニメーション（キーフレーム）」から設定します。レイヤーの絵自体は変わらず、表示位置だけが変わる非破壊な変形です。この機能はタイムラインの表示（プレビュー・書き出し）にのみ影響し、キャンバスモードでの実際の作画には影響しません。';

  @override
  String get helpLayerGroupTitle => 'レイヤーグループ（複数パーツをまとめて動かす）';

  @override
  String get helpLayerGroupDesc =>
      '複数のレイヤーをまとめて1つのキーフレームストリームで動かす機能です。例えば「腕」が肌・袖の2枚の自動塗りパーツで構成されている場合、この2枚をグループ化しておけば、1回のキーフレーム操作でまとめて動かせます。レイヤーパネルで複数選択（チェックボックス）した状態で下部バーの「グループ化」アイコンから作成します。グループの動きは各レイヤー自身のキーフレーム（設定されていれば）に重ねて適用されるため、グループ全体の動き＋個別レイヤーの微調整、という組み合わせも可能です。1つのレイヤーは同時に1つのグループにのみ所属できます。';

  @override
  String get tipsScreenTitle => '活用Tips';

  @override
  String get tipsSearchHint => 'Tipsを検索...';

  @override
  String get tipsCategoryVideo => '動画制作のコツ';

  @override
  String get tipsCategoryEfficiency => '制作を効率化するコツ';

  @override
  String get tipsCategoryDrawing => '作画をなめらかにするコツ';

  @override
  String get tipsCategoryEffects => '演出・仕上げのコツ';

  @override
  String get tipsCategoryExport => '書き出し・操作のコツ';

  @override
  String get tipsClipDuplicateTitle => 'タイムラインの素材は複製・移動・削除ができる';

  @override
  String get tipsClipDuplicateDesc =>
      '画像・動画・音声クリップをタップすると開く詳細シートのコピーアイコンから複製できます。同じ効果音を繰り返し使う、同じ画像を場面ごとに配置し直すといった編集が、長押しドラッグと複製ボタンだけで完結します。';

  @override
  String get tipsTextCaptionTitle => 'テキストツールで字幕を入れる';

  @override
  String get tipsTextCaptionDesc =>
      'テキストツールを使えば、字幕やコメントをフレームごとに配置できます。フォントをピクセルモードに切り替えると、レトロゲーム風の質感を演出することもできます。';

  @override
  String get tipsAutofillPresetTitle => '自動塗り設定はパーツごとに登録しておく';

  @override
  String get tipsAutofillPresetDesc =>
      '肌・髪・服などパーツごとに陰影込みで自動塗り設定を登録しておくと、線画を描くだけで色塗りの大部分を自動化できます。プロジェクトごとに使う設定だけを絞り込むこともできます。';

  @override
  String get tipsAutofillBaseCoatTitle => '自動塗りはパーツ分けせず下塗り用に使うだけでも便利';

  @override
  String get tipsAutofillBaseCoatDesc =>
      '自動塗りは本来パーツごとに色分けする機能ですが、丁寧に分けなくても、線画全体を1色で塗るだけの下塗りレイヤーとして使うだけで十分便利です。線の内側を一括で塗りつぶせるため、手動のバケツ塗りで起きがちな塗り残し（線の隙間から下の色が透けてしまうミス）を防げます。その上に手動で色を重ねれば、パーツ分けの手間をかけずに恩恵だけ得られます。';

  @override
  String get tipsBrushFavoriteTitle => 'ブラシはお気に入り登録で迷わず選べる';

  @override
  String get tipsBrushFavoriteDesc =>
      'よく使うブラシは一覧の星アイコンをタップしてお気に入り登録しておきましょう。一覧上部の星アイコンでお気に入りのみに絞り込めるので、探す手間が減ります。誤って削除しないよう、お気に入り登録中は削除できない仕組みになっています。';

  @override
  String get tipsPressureCurveTitle => '筆圧カーブを自分好みに調整する';

  @override
  String get tipsPressureCurveDesc =>
      '設定画面の筆圧カーブは最大10点の制御点を自由に打てます。強弱の付き方が合わないと感じたら、自分の筆圧の癖に合わせて調整してみましょう。';

  @override
  String get tipsExportFormatTitle => '用途に合わせて書き出し形式を選ぶ';

  @override
  String get tipsExportFormatDesc =>
      'SNSに気軽に投稿したいときはGIF書き出し、他の動画に重ねたい・背景を透かしたいときは透過WebM、通常の動画として使いたいときはMP4書き出しが向いています。用途ごとに使い分けると、ファイルサイズと画質のバランスを取りやすくなります。';

  @override
  String get tipsGestureShortcutTitle => 'ジェスチャーで頻用操作をワンタッチに';

  @override
  String get tipsGestureShortcutDesc =>
      '設定画面の「ジェスチャー」から、2本指タップ・3本指タップ・長押しなどにUndo/Redoやスポイトを割り当てられます。ツールを切り替えずに済むので、作画のテンポを崩さずに済みます。';

  @override
  String get tipsAudioRepeatTitle => '効果音はクリップ複製×フェードでリズムよく鳴らす';

  @override
  String get tipsAudioRepeatDesc =>
      '同じ効果音を繰り返し使いたい場合、クリップを複製してタイミングをずらして並べ、それぞれにフェードイン・アウトを設定すると、リズムに合った自然な効果音の連打が作れます。';

  @override
  String get tipsVerticalRubyTitle => '縦書き×ルビでタイトルロゴ風の演出';

  @override
  String get tipsVerticalRubyDesc =>
      'テキストツールの縦書きにルビを組み合わせると、和風のタイトルロゴやこだわりの見出し演出が作れます。半角英数字は自動で横向きに回転して並ぶので、記号や数字が混ざっても読みやすく仕上がります。';

  @override
  String get tipsBrushTrySaveTreeTitle => '新しいブラシ設定はセーブツリーで試す';

  @override
  String get tipsBrushTrySaveTreeDesc =>
      'ブラシの太さや安定化などを大きく変えて試したいときは、変更前にセーブツリーへ保存しておくと安心です。気に入らなければすぐに元の状態へ戻せるので、思い切った調整を試しやすくなります。';

  @override
  String get tipsEyedropperGestureTitle => '2本指タップにスポイトを割り当てて配色を崩さない';

  @override
  String get tipsEyedropperGestureDesc =>
      'ジェスチャー設定で2本指タップにスポイトを割り当てておくと、ツールを切り替えずに近くの色をすぐ拾えます。キャラクターの配色を保ったまま塗り進めたいときに便利です。';

  @override
  String get tipsRulerOnionTitle => 'パース定規×オニオンスキンで背景を使い回す';

  @override
  String get tipsRulerOnionDesc =>
      'パース定規で背景の奥行きを決めておき、オニオンスキンで前後フレームを透かして見ながらキャラクターだけを動かすと、背景を毎フレーム描き直さずに済みます。';

  @override
  String get tipsGradientTraceTitle => 'グラデーション自動塗り×色トレスで馴染ませる';

  @override
  String get tipsGradientTraceDesc =>
      '自動塗り設定でグラデーションを使う際、線画色設定を色トレス（線画馴染ませ）にしておくと、グラデーションの微妙な色の変化に合わせて線画の色も馴染み、境界が浮きにくくなります。';

  @override
  String get tipsGradientOutlineHairTitle => 'グラデーション×指定色縁取りで前髪に透明感を出す';

  @override
  String get tipsGradientOutlineHairDesc =>
      '自動塗り設定で前髪パーツを作り、塗り色をグラデーションにして髪色と透明色の2色を選びます。角度を90度に変更し、ぼかしの強さと色の切り替え位置をお好みに調整したら、「指定色で縁取り」をチェックして縁取り色を「最近使った色」から先ほどの前髪の色と同じものを選びます。前髪の下塗りパーツだけでなく影色パーツにも同じ手順を繰り返すと、毛先が透けるような透明感のある髪の毛になります。';

  @override
  String get tipsRainNoiseTitle => '雨フィルター×動くノイズでしっとりした空気感';

  @override
  String get tipsRainNoiseDesc =>
      '雨フィルターに弱めの動くノイズフィルターを重ねると、雨粒だけでなく空気中の粒子感も加わり、しっとりとした雨の日らしい質感を演出できます。';

  @override
  String get tipsPartKeyframeGroupTitle => 'パーツキーフレーム×グループ化でキャラを弾ませる';

  @override
  String get tipsPartKeyframeGroupDesc =>
      '自動塗りの各パーツにレイヤーキーフレームを付けて動かし、さらに関連パーツをグループ化してまとめて弾ませると、音楽に合わせて揺れるようなミニアニメーションを描き直しなしで作れます。';

  @override
  String get tipsLowSpecSettingsTitle => '低スペック端末はパフォーマンス設定とUndo回数を見直す';

  @override
  String get tipsLowSpecSettingsDesc =>
      '動作が重いと感じたら、パフォーマンス設定を「低品質」プリセットに切り替え、Undo回数も減らしてみましょう。メモリ使用量が減り、動作が軽くなることがあります。';

  @override
  String get tipsSeriesPresetFolderTitle => 'シリーズ物は自動塗り設定の絞り込み×フォルダ整理で管理する';

  @override
  String get tipsSeriesPresetFolderDesc =>
      '同じ作品の複数話数を作るときは、フォルダで話数ごとにプロジェクトをまとめ、各プロジェクトで使う自動塗り設定を絞り込んでおくと、キャラごとの配色を混同せず効率よく作業できます。';

  @override
  String get tipsPixelToneRetroTitle => 'スタンプのピクセルモード×トーン塗りでレトロ統一';

  @override
  String get tipsPixelToneRetroDesc =>
      'ピクセルモードのスタンプと、ピクセルモード専用の市松・格子柄トーンを組み合わせると、画面全体をドット絵風の質感で統一できます。レトロゲーム風の演出に向いています。';

  @override
  String get tipsMagicWandLassoTitle => 'マジックワンド選択×投げ縄塗りで塗り分け効率化';

  @override
  String get tipsMagicWandLassoDesc =>
      '選択ツールの自動選択（マジックワンド）でおおまかな範囲を一括選択し、はみ出た部分だけ投げ縄選択で調整すると、複雑な塗り分けも素早く行えます。';

  @override
  String get tipsCommonLayerFolderTitle => '共通レイヤー×フォルダで話数をまたいで使い回す';

  @override
  String get tipsCommonLayerFolderDesc =>
      'シリーズ物で毎話使うロゴやクレジット表記は、共通レイヤー化してフォルダにまとめておくと、新しい話数のプロジェクトへコピーする際も迷わず扱えます。';

  @override
  String get tipsStrokeDecayFadeTitle => 'ストローク減衰×フェードで毛筆表現';

  @override
  String get tipsStrokeDecayFadeDesc =>
      'ブラシ設定のストローク減衰とフェードを両方かけると、線の描き始め・終わりが自然に細くなり、毛筆やインクブラシのような抑揚のある線が描けます。';

  @override
  String get tipsColorMixingFadeTitle => '混色×フェードで絵の具のような混ざり';

  @override
  String get tipsColorMixingFadeDesc =>
      '混色を有効にしたブラシへフェードも組み合わせると、下の色と混ざりながら徐々に薄くなる、実際の絵の具に近い塗り心地になります。';

  @override
  String get tipsOutlineAnimeStyleTitle => '縁取り×アニメ調でセルアニメ風の仕上げ';

  @override
  String get tipsOutlineAnimeStyleDesc =>
      '描画フィルターの縁取りで輪郭線を新規レイヤーへ描き出し、アニメ調フィルターで色数を落とすと、セルアニメのようなくっきりした仕上げになります。';

  @override
  String get tipsLevelsToneCurveTitle => 'レベル補正×トーンカーブでグラフィック調に';

  @override
  String get tipsLevelsToneCurveDesc =>
      'レベル補正で明暗差を強めに調整してからトーンカーブで階調を作り込むと、写真的な階調から離れた、ポスターのようなグラフィック調の演出ができます。';

  @override
  String get tipsMosaicChromaticTitle => 'モザイク×色収差でブラウン管風の荒れた質感';

  @override
  String get tipsMosaicChromaticDesc =>
      'モザイクで解像度を落としてから色収差を重ねると、古いブラウン管テレビで見ているような荒れた質感を演出できます。ブラウン管フィルター単体とはひと味違う質感が作れます。';

  @override
  String get tipsEndCardWatermarkTitle => '自分の署名はウォーターマーク、エンドカードは別物';

  @override
  String get tipsEndCardWatermarkDesc =>
      '動画に自分の署名や透かしを入れたいときはウォーターマーク機能を使います。エンドカードは動画の最後に自動で表示されるアプリ側のロゴで、無料会員は変更できません。プレミアム会員なら非表示にしたり、自分の動画・画像に差し替えたりできます。エンドカードを使わず自分だけの締めくくりを作りたいときは、画像レイヤーの追加とフェードイン・アウトを組み合わせれば同じような演出を自作できます。';

  @override
  String get tipsVerticalPixelFontTitle => '実写動画×手描き作画で「実写×アニメ」を作る';

  @override
  String get tipsVerticalPixelFontDesc =>
      'イラストアプリと動画編集アプリを兼ねているからこそできる遊び方です。実写の動画クリップをタイムラインに配置し、その上のレイヤーへオニオンスキンを使いながら手描きで効果線やキャラクターを描き足せば、実写に手描きアニメが重なった「実写×アニメ」のミックスメディア動画が作れます。';

  @override
  String get tipsTimelineMarkerTitle => '音や口パクのタイミング合わせにはタイムスタンプ';

  @override
  String get tipsTimelineMarkerDesc =>
      'シーンは「開始〜終了フレームの範囲」を扱う機能ですが、タイムスタンプは「その一瞬」にコメントを付けてワンタップで移動できる機能です。「120フレーム目で効果音」「180フレーム目は口パク『あ』」のように、同じシーンの範囲内に複数のタイムスタンプを打っておけば、音と映像のタイミング合わせが格段にやりやすくなります。';

  @override
  String get tipsCommunityYoutubeTitle => '作品広場への投稿はYouTube経由です';

  @override
  String get tipsCommunityYoutubeDesc =>
      '作品広場に投稿すると、YouTubeを通じて作品が公開されます。NIARIMは動画ファイル本体を開発者のサーバーへ送信・収集・保存する機能を持っていません。YouTube側の公開設定を「限定公開」にすれば、YouTube上の一般公開一覧には表示されず、作品広場内だけに投稿された状態にできます。';

  @override
  String get tipsToolbarCustomizeTitle => 'ツールバーの並び替え・非表示で指の移動距離を減らす';

  @override
  String get tipsToolbarCustomizeDesc =>
      '設定画面のツールバー編集から、使わないツールを非表示にし、よく使うツールを指の届きやすい位置へ並び替えられます。表示項目を絞ってすっきりさせるだけで、ツールを探す時間や指の移動距離が減り、作画のテンポが上がります。';

  @override
  String get tipsAutofillBlendModeTitle => '自動塗りパーツのブレンドモードで陰影の質感を変える';

  @override
  String get tipsAutofillBlendModeDesc =>
      '自動塗り設定の各パーツにはブレンドモードを設定できます。陰影パーツを「乗算」ではなく「オーバーレイ」や「ソフトライト」にすると、光が透けるような柔らかい陰影になります。同じ色でも質感を変えられる、隠れた自由度の高さです。';

  @override
  String get tipsStampBlendModeTitle => 'スタンプ×ブレンドモードで光のエフェクト';

  @override
  String get tipsStampBlendModeDesc =>
      '配置したスタンプのレイヤーをブレンドモード「スクリーン」や「加算」にすると、光の効果線やキラキラしたエフェクトが背景に自然に馴染んで映えます。';

  @override
  String get tipsQuickToolPenSubTitle => '早替えツール×ペンサブツールで手を止めない作業導線';

  @override
  String get tipsQuickToolPenSubDesc =>
      'よく使うツールを早替えツールに登録しつつ、ペンの長押しでトーン貼り・スタンプへ切り替えられるペンサブツールも活用すると、画面を行き来する回数を減らして作業のテンポを保てます。';

  @override
  String get tipsAutofillToneReuseTitle => '自動塗りのトーン設定で線画差し替えだけで塗りを再現';

  @override
  String get tipsAutofillToneReuseDesc =>
      '自動塗り設定の各パーツを「トーンを使う」設定にしておくと、線画を描き直すたびにトーン込みの塗りを自動で再現できます。フレームごとにトーンを貼り直す手間を省けます。';

  @override
  String get tipsRadialVignetteTitle => '放射定規×周辺減光で集中線演出';

  @override
  String get tipsRadialVignetteDesc =>
      '放射定規で集中線を一気に描き、描画フィルターの周辺減光を重ねると、漫画のクライマックスのような迫力ある演出になります。';

  @override
  String get tipsClippingGradientTitle => 'クリッピング×グラデーションで陰影を描き直し可能に';

  @override
  String get tipsClippingGradientDesc =>
      'グラデーションレイヤーをキャラクターレイヤーへクリッピングしておくと、陰影の形をブラシで描き込まなくても、グラデーションの範囲・角度の変更だけで陰影を調整し直せます。';

  @override
  String get tipsToneCurveSepiaTitle => 'トーンカーブ×セピアでレトロ写真風';

  @override
  String get tipsToneCurveSepiaDesc =>
      '演出フィルターのトーンカーブで明暗のコントラストを整えてからセピアを重ねると、色あせた古い写真のような質感を演出できます。';

  @override
  String get tipsCameraLensBlurTitle => 'カメラキーフレーム×レンズぼかしでズームブラー演出';

  @override
  String get tipsCameraLensBlurDesc =>
      'カメラキーフレームでズームする瞬間に合わせてレンズぼかしの演出フィルターを一時的に強めに設定すると、実写のズームブラーのような迫力を演出できます。';

  @override
  String get tipsBlurVignetteBgTitle => 'ガウスぼかし×周辺減光で柔らかい背景ボケ';

  @override
  String get tipsBlurVignetteBgDesc =>
      '背景レイヤーだけにガウスぼかしと周辺減光の描画フィルターを重ねてかけると、主役のキャラクターが自然と目立つ、被写界深度のあるカメラ風の仕上がりになります。';

  @override
  String get tipsSepiaVignetteTitle => 'セピア×周辺減光でアンティーク写真風の動画に';

  @override
  String get tipsSepiaVignetteDesc =>
      '演出フィルターのセピアと描画フィルターの周辺減光を組み合わせると、四隅が暗く色あせたアンティーク写真のような雰囲気の動画に仕上げられます。';

  @override
  String get tipsVideoTrimReuseTitle => '動画クリップの使用範囲を変えて同じ素材を使い回す';

  @override
  String get tipsVideoTrimReuseDesc =>
      '同じ動画素材でも、クリップごとに使用開始・終了フレームを変えて配置すれば、別のカットとして使い回せます。素材を増やさずにバリエーションを作れます。';

  @override
  String get tipsSaveSlotAutoSaveTitle => 'セーブスロット×自動保存を使い分ける';

  @override
  String get tipsSaveSlotAutoSaveDesc =>
      '自動保存は常に最新状態を上書きしますが、セーブスロットは複数の状態を残しておけます。大きな節目でセーブスロットに保存し、それ以外の細かい変更は自動保存に任せると、必要な時点へ確実に戻れます。';

  @override
  String get tipsQuickToolSwipeTitle => '早替えツールは上スワイプで並び替えできる';

  @override
  String get tipsQuickToolSwipeDesc =>
      '早替えツールの登録内容を変えたいときは、長押しだけでなく上スワイプでも管理ポップアップを開けます。片手で操作しているときに素早く並び替えたい場合に便利です。';

  @override
  String get tipsDrawingAreaCameraTitle => '描画領域を広めに×カメラキーフレームで安全にパン・ズーム';

  @override
  String get tipsDrawingAreaCameraDesc =>
      '描画領域を書き出し範囲より広めに設定しておくと、カメラキーフレームでパン・ズームしても画面の端が切れる心配がありません。動きの大きい演出を入れる前に確認しておくと安心です。';

  @override
  String get tipsWebmCommonLayerTitle => '透過WebM×背景を共通レイヤーで分離管理';

  @override
  String get tipsWebmCommonLayerDesc =>
      '透過WebMとして書き出したキャラクターを別の動画編集ソフトで背景と合成する場合、背景を共通レイヤーで別管理しておくと、透過部分に不要な色が混ざらずきれいに抜けます。';

  @override
  String get tipsLeftHandedWorkspaceTitle => '左利きモード×ワークスペース設定で作業しやすく';

  @override
  String get tipsLeftHandedWorkspaceDesc =>
      '左利きの場合、ワークスペース設定の左利きモードをONにするとドッキングパネルが左右反転し、利き手側の画面がパネルで隠れにくくなります。';

  @override
  String get tipsTransferDeviceTitle => '引き継ぎファイルで別端末へ環境を移す';

  @override
  String get tipsTransferDeviceDesc =>
      '使う端末を変えても同じ環境で描き続けたいときは、引き継ぎ（.niatra）機能を使うと、設定・ブラシ・トーン・スタンプ・パレットなどの環境をまとめて移動できます。制作中のプロジェクトそのものを渡したい場合は「共有（.niashare）」を使います。';

  @override
  String get fontSettingsTabDownloaded => 'ダウンロード済み';

  @override
  String get fontSettingsTabSearch => '探してDL';

  @override
  String get fontSettingsTabImport => '読み込み';

  @override
  String get fontDownloadedSearchHint => 'フォント名で検索...';

  @override
  String get fontPixelModeTooltip => 'ピクセルモード（ドットフォント用。アンチエイリアスなしでくっきり表示）';

  @override
  String get fontEmptyTitle => 'フォントがありません';

  @override
  String get fontEmptyHint => '「探してDL」または「読み込み」タブから追加できます';

  @override
  String get fontRenameDialogTitle => 'フォント名を変更';

  @override
  String get fontImportTitle => '端末に保存済みのフォントを読み込む';

  @override
  String get fontImportFormats => '対応形式：TTF / OTF';

  @override
  String get fontSelectFileButton => 'ファイルを選択';

  @override
  String get fontUnsupportedSnackbar => 'このフォントは読み込めません。';

  @override
  String fontAddedSnackbar(String name) {
    return '「$name」を追加しました（ダウンロード済みタブに表示されます）';
  }

  @override
  String get fontCorruptedSnackbar => 'フォントが破損しています。';

  @override
  String get licenseScreenTitle => '利用規約・ライセンス';

  @override
  String get licenseSectionTerms => '利用規約';

  @override
  String get licenseSectionFonts => '使用フォントについて';

  @override
  String get licenseSectionOss => 'オープンソースソフトウェアライセンス';

  @override
  String get licenseOssListTitle => '使用ライブラリのライセンス一覧';

  @override
  String get licenseOssListSubtitle => '本アプリが使用するOSSパッケージのライセンスを表示します';

  @override
  String get licenseFfmpegNote =>
      'WebM・AVI書き出しにはFFmpeg（LGPL 3.0、ffmpeg_kit_flutter_new_video経由）を使用しています。改変版ソースコードの入手先：https://github.com/sk3llo/ffmpeg_kit_flutter\nMP4書き出しは端末内蔵のハードウェアエンコーダーを直接利用しており、FFmpegは使用していません。';

  @override
  String licenseFontCreditMeta(String author, String license) {
    return '作者：$author　ライセンス：$license';
  }

  @override
  String get toolbarPenTooltip => 'ペン（長押しでサブツール）';

  @override
  String get toolbarPenFirstUseTip => 'ペンを長押しすると、ブラシ・トーン・スタンプ・投げ縄塗りを切り替えられます。';

  @override
  String get toolbarBucketTooltip => 'バケツ（長押しでベタ/トーン切替）';

  @override
  String get toolbarBucketFirstUseTip => 'バケツを長押しすると、ベタ塗りとトーン塗りを切り替えられます。';

  @override
  String get toolbarSelectTooltip => '選択（長押しで種別変更）';

  @override
  String get toolbarShapeTooltip => '図形（タップで種別選択）';

  @override
  String get toolbarTextFirstUseTip => '文字を自由に配置できます。フォントや色、アウトラインも変更できます。';

  @override
  String get toolbarQuickToolFirstUseTip =>
      'タップで登録したツールを順番に切り替えられます。長押しまたは上にスワイプで登録内容を編集できます。';

  @override
  String get toolbarStampColorLockedSnackbar => 'スタンプは色情報を保持しているため色変更できません';

  @override
  String get toolbarBrushSettingsTooltip => 'ブラシ設定';

  @override
  String get toolbarLayerTooltip => 'レイヤー';

  @override
  String get toolbarQuickToolTooltip => 'ツール早替え（長押し/上スワイプで編集）';

  @override
  String get toolbarSaveTooltip => '保存（セーブツリー）';

  @override
  String get toolbarBucketFlatFill => 'ベタ塗り';

  @override
  String get toolbarBucketToneListLabel => 'トーン一覧';

  @override
  String get toolbarSelectRect => '矩形選択';

  @override
  String get toolbarSelectLasso => '投げ縄選択';

  @override
  String get toolbarSelectMagicWand => '自動選択（マジックワンド）';

  @override
  String get creativePanelFavoritesOnlyTooltip => 'お気に入りのみ表示';

  @override
  String get creativePanelSearchTooltip => '名前で検索';

  @override
  String get creativePanelFolderButton => 'フォルダ';

  @override
  String get creativePanelCreateButton => '自作';

  @override
  String get creativePanelImportButton => '読込';

  @override
  String get creativePanelFolderAllChip => '全て';

  @override
  String get creativePanelEditAction => '編集';

  @override
  String get toneTitle => 'トーン';

  @override
  String get toneEmpty => 'トーンがありません';

  @override
  String get toneSearchHint => 'トーン名で検索';

  @override
  String get toneEditTitle => 'トーンを編集';

  @override
  String get toneChangeTextureButton => 'テクスチャ画像を変更';

  @override
  String get toneCreateDialogTitle => '自作トーン';

  @override
  String toneImportFailedSnackbar(String error) {
    return 'トーンの読み込みに失敗しました: $error';
  }

  @override
  String toneExportFailedSnackbar(String error) {
    return 'トーンの書き出しに失敗しました: $error';
  }

  @override
  String get privacyPolicyScreenTitle => 'プライバシーポリシー';

  @override
  String get stampTitle => 'スタンプ';

  @override
  String get stampSearchHint => 'スタンプ名で検索';

  @override
  String get stampEmpty => 'スタンプがありません';

  @override
  String get stampCreateDialogTitle => '自作スタンプ';

  @override
  String stampImportFailedSnackbar(String error) {
    return 'スタンプの読み込みに失敗しました: $error';
  }

  @override
  String stampExportFailedSnackbar(String error) {
    return 'スタンプの書き出しに失敗しました: $error';
  }

  @override
  String get stampEditTitle => 'スタンプを編集';

  @override
  String get stampRotationLabel => '回転';

  @override
  String get stampPixelModeLabel => 'ピクセルモード';

  @override
  String get stampPixelModeHint => 'ドット絵風（モザイク＋色数削減）に加工して描画します';

  @override
  String get stampDensityLabel => '密度';

  @override
  String get stampScatterLabel => '散布';

  @override
  String get stampChangeImageButton => 'スタンプ画像を変更';

  @override
  String get themeSettingsTitle => 'テーマ・外観';

  @override
  String get themeColorCustomizeSection => 'カラーカスタマイズ';

  @override
  String get themeColorAccent => 'アクセントカラー';

  @override
  String get themeColorText => '文字色';

  @override
  String get themeColorPanelBg => 'パネル背景色';

  @override
  String get themeColorMenuBg => 'メニュー背景色';

  @override
  String get themeColorSelection => '選択色';

  @override
  String get themeColorUpdateMark => '更新マーク色';

  @override
  String get themePresetSection => 'テーマ一覧';

  @override
  String themePresetDuplicateName(String name) {
    return '$name (コピー)';
  }

  @override
  String get themeDuplicateAction => '複製';

  @override
  String get themeExportMenuItem => '書き出し (.niatheme)';

  @override
  String themeExportFailedSnackbar(String error) {
    return '書き出しに失敗しました: $error';
  }

  @override
  String get themeImportSuccessSnackbar => '.niathemeを読み込みました';

  @override
  String themeImportFailedSnackbar(String error) {
    return '読み込みに失敗しました: $error';
  }

  @override
  String get themeSaveAsNewButton => '現在の設定を新しいテーマとして保存';

  @override
  String get themeImportButton => '.niathemeを読み込む';

  @override
  String get themePresetNameDialogTitle => 'テーマ名';

  @override
  String get themeDefaultPresetName => 'マイテーマ';

  @override
  String get onionSkinTitle => 'オニオンスキン';

  @override
  String get onionSkinPrevFrame => '前フレーム';

  @override
  String get onionSkinNextFrame => '後フレーム';

  @override
  String get onionSkinFrameInterval => 'フレーム間隔';

  @override
  String get onionSkinFadeByDistance => '近いほど濃く表示';

  @override
  String get onionSkinColorPickerTitle => '色を選択';

  @override
  String get onionSkinOnFixed => 'ON（固定）';

  @override
  String get onionSkinFrameCount => '表示枚数';

  @override
  String onionSkinFrameCountFixed(int count) {
    return '$count枚（固定）';
  }

  @override
  String get onionSkinColorLabel => '色';

  @override
  String get onionSkinOpacityLabel => '透明度';

  @override
  String get exportScreenTitle => '書き出し';

  @override
  String get exportPresetSection => 'プリセット';

  @override
  String get exportPresetStandard => '標準';

  @override
  String get exportPresetHighQuality => '高画質';

  @override
  String get exportPresetCustom => 'カスタム';

  @override
  String get exportAdvancedSettings => '詳細設定';

  @override
  String get exportFpsLabel => 'FPS';

  @override
  String get exportFormatSection => '形式';

  @override
  String get exportFormatMp4 => 'MP4';

  @override
  String get exportFormatMp4Subtitle => '汎用動画形式';

  @override
  String get exportFormatGif => 'GIF';

  @override
  String get exportFormatGifSubtitle => 'アニメーションGIF';

  @override
  String get exportFormatWebmSubtitle => '透明背景動画';

  @override
  String get exportFormatAvi => 'AVI';

  @override
  String get exportFormatAviSubtitle => '互換性重視の動画形式（透過非対応）';

  @override
  String get exportStartButton => '書き出し開始';

  @override
  String get exportProjectNotFoundError => 'プロジェクトが見つかりません';

  @override
  String exportFailedError(String error) {
    return '書き出し失敗: $error';
  }

  @override
  String get exportInProgressTitle => '書き出し中';

  @override
  String get exportCancelledSnackbar => '書き出しをキャンセルしました';

  @override
  String get exportCancelHint => '最終処理中のため、完了後にキャンセルを反映します';

  @override
  String get exportOutdatedAutofillTitle => '自動塗りが最新ではありません';

  @override
  String get exportOutdatedAutofillBody => '更新されていない自動塗りレイヤーがあります。このまま書き出しますか？';

  @override
  String get exportContinueButton => '続行';

  @override
  String get exportDurationExceededTitle => '動画尺の上限を超えています';

  @override
  String exportDurationExceededBody(int max, int current) {
    return '無料版の最大動画尺は$max秒です。\n現在のプロジェクトは約$current秒あります。\nプレミアムにアップグレードすると最大2時間まで作成できるようになります。';
  }

  @override
  String get exportViewPremiumButton => 'プレミアムを見る';

  @override
  String get exportContinueAnywayButton => 'このまま続行';

  @override
  String get exportCompleteTitle => '書き出し完了';

  @override
  String exportCompleteFramesBody(int count) {
    return '$count フレームの書き出しが完了しました。';
  }

  @override
  String exportSaveLocationLabel(String fileName) {
    return '保存先：アプリ内（$fileName）';
  }

  @override
  String get exportSaveLocationHint =>
      '端末の「写真」アプリやファイルアプリで開くには、下の「共有」から保存先アプリを選んでください。';

  @override
  String get exportBackToProjectsButton => 'プロジェクト一覧へ戻る';

  @override
  String get exportBackToCanvasButton => 'キャンバスへ戻る';

  @override
  String get newProjectScreenTitle => '新規プロジェクト';

  @override
  String get newProjectDefaultName => '新規プロジェクト';

  @override
  String get newProjectNameLabel => 'プロジェクト名';

  @override
  String get newProjectSizeLabel => 'サイズ';

  @override
  String get newProjectPresetFullHd => 'Full HD (16:9・YouTube等横動画向け)';

  @override
  String get newProjectPresetHd => 'HD (16:9・軽量版)';

  @override
  String get newProjectPresetSquare => '1:1 スクエア (Twitter/Instagram投稿向け)';

  @override
  String get newProjectPresetVertical => '9:16 縦型 (YouTubeショート/リール・ストーリーズ向け)';

  @override
  String get newProjectPresetPortrait => '4:5 縦長 (Instagramフィード投稿向け)';

  @override
  String get newProjectPresetAnalog => '4:3 (アナログ放送比率)';

  @override
  String get newProjectCustomSize => 'カスタム';

  @override
  String get newProjectMaxEdgeHint => '長辺は最大1920pxまで指定できます';

  @override
  String get newProjectWidthLabel => '幅(px)';

  @override
  String get newProjectHeightLabel => '高さ(px)';

  @override
  String get newProjectWidthShort => '幅';

  @override
  String get newProjectHeightShort => '高さ';

  @override
  String get newProjectSizePresetManageButton => 'サイズ設定';

  @override
  String get newProjectSaveCustomSizeButton => 'このサイズを保存する';

  @override
  String get newProjectSaveCustomSizeDialogTitle => 'サイズ名を入力';

  @override
  String get newProjectSaveCustomSizeNameLabel => 'サイズ名';

  @override
  String get newProjectSaveCustomSizeSavedSnackbar => 'サイズを保存しました';

  @override
  String get canvasSizePresetManageScreenTitle => 'サイズ設定';

  @override
  String get canvasSizePresetEmpty => '保存されたサイズはありません';

  @override
  String get canvasSizePresetEmptyHint =>
      '新規プロジェクト画面でカスタムサイズを指定し、「このサイズを保存する」から追加できます';

  @override
  String get canvasSizePresetEditDialogTitle => 'サイズを編集';

  @override
  String canvasSizePresetDeleteConfirmTitle(String name) {
    return '「$name」を削除しますか？';
  }

  @override
  String get canvasSizePresetDuplicateSuffix => 'のコピー';

  @override
  String newProjectDurationLabel(String max) {
    return '長さ（最大$max）';
  }

  @override
  String newProjectDurationLabelWithPremiumHint(String max) {
    return '長さ（最大$max・プレミアムなら最大2時間）';
  }

  @override
  String newProjectDurationSeconds(int n) {
    return '$n秒';
  }

  @override
  String newProjectDurationHms(int h, int m, int s) {
    return '$h時間$m分$s秒';
  }

  @override
  String newProjectDurationHm(int h, int m) {
    return '$h時間$m分';
  }

  @override
  String newProjectDurationH(int h) {
    return '$h時間';
  }

  @override
  String newProjectDurationMs(int m, int s) {
    return '$m分$s秒';
  }

  @override
  String newProjectDurationM(int m) {
    return '$m分';
  }

  @override
  String get newProjectBackgroundColorLabel => '背景色';

  @override
  String get newProjectDrawingAreaTitle => '描画領域を広くする';

  @override
  String get newProjectDrawingAreaSubtitle => '書き出し範囲外にも描画できる領域を追加します';

  @override
  String get newProjectScaleLabel => '倍率';

  @override
  String newProjectScaleValue(String value) {
    return '$value倍';
  }

  @override
  String newProjectDrawableAreaInfo(String width, String scale, String result) {
    return '描画可能範囲: $width×$scale = $result';
  }

  @override
  String newProjectTotalFrames(int count) {
    return '総フレーム数: $count';
  }

  @override
  String newProjectExportSizeInfo(String size) {
    return '書き出しサイズ: $size';
  }

  @override
  String newProjectDrawingAreaInfo(String size) {
    return '描画領域: $size';
  }

  @override
  String get colorPickerTitle => '色選択';

  @override
  String get colorPickerOpacityLabel => '不透明度';

  @override
  String get colorPickerHexCopiedSnackbar => 'HEXをコピーしました';

  @override
  String get colorPickerRecentColorsLabel => '最近使った色';

  @override
  String get colorPickerRecentColorsEmpty => 'まだありません';

  @override
  String get colorPickerPaletteLabel => 'パレット';

  @override
  String get colorPickerNewPaletteTooltip => '新しいパレット';

  @override
  String get colorPickerManagePaletteTooltip => 'パレット管理';

  @override
  String get colorPickerPaletteEmptyHint => '色がまだありません。「＋」で現在の色を追加できます。';

  @override
  String get colorPickerPaletteLongPressHint => '長押しで削除できます';

  @override
  String get colorPickerAddCurrentColorButton => '現在の色をパレットに追加';

  @override
  String get colorPickerPaletteNameLabel => 'パレット名';

  @override
  String get colorPickerFavoriteAdd => 'お気に入り登録';

  @override
  String get colorPickerFavoriteRemove => 'お気に入り解除';

  @override
  String get penSubToolTabBrush => 'ブラシ';

  @override
  String get penSubToolTabTone => 'トーン';

  @override
  String get penSubToolTabStamp => 'スタンプ';

  @override
  String get penSubToolTabLassoFill => '投げ縄塗り';

  @override
  String get penSubToolToneTooltipMessage => 'トーンを選ぶと、バケツやペンでアミトーン柄を塗れます。';

  @override
  String get penSubToolStampTooltipMessage =>
      '決まった形のスタンプを配置できます。長押しで回転・密度などを設定できます。';

  @override
  String get penSubToolLassoTooltipMessage => '投げ縄で囲んだ範囲を一括で塗りつぶせます。';

  @override
  String get penSubToolManageTooltip => '管理';

  @override
  String penSubToolBrushSizeOpacity(int size, int opacity) {
    return '${size}px · $opacity%';
  }

  @override
  String get penSubToolStampRotationSubtitle => 'ストローク方向に合わせてランダムに回転';

  @override
  String get brushSearchHint => 'ブラシ名で検索';

  @override
  String get brushEmpty => 'ブラシがありません';

  @override
  String get brushCreateDialogTitle => '自作ブラシ';

  @override
  String brushImportFailedSnackbar(String error) {
    return 'ブラシの読み込みに失敗しました: $error';
  }

  @override
  String brushExportFailedSnackbar(String error) {
    return 'ブラシの書き出しに失敗しました: $error';
  }

  @override
  String get brushSettingsSizeLabel => 'サイズ';

  @override
  String get brushSettingsOpacityLabel => '不透明度';

  @override
  String get brushSettingsSpacingLabel => '間隔';

  @override
  String get brushSettingsBlurRadiusLabel => 'ぼかし半径';

  @override
  String get brushSettingsStabilizationTitle => '手ブレ補正';

  @override
  String get brushSettingsStabilizationStrengthLabel => '補正強度';

  @override
  String get brushSettingsPixelModeTitle => 'ピクセルモード';

  @override
  String get brushSettingsPressureModeTitle => '筆圧設定';

  @override
  String get brushSettingsPressureOff => '無効';

  @override
  String get brushSettingsPressureSize => 'サイズに反映';

  @override
  String get brushSettingsPressureOpacity => '不透明度に反映';

  @override
  String get brushSettingsPressureSizeAndOpacity => 'サイズ＋不透明度に反映';

  @override
  String get brushSettingsFadeModeTitle => 'フェード';

  @override
  String get brushSettingsFadeOff => 'OFF';

  @override
  String get brushSettingsFadeWeak => '弱';

  @override
  String get brushSettingsFadeMedium => '中';

  @override
  String get brushSettingsFadeStrong => '強';

  @override
  String get brushSettingsFadeCustom => 'カスタム';

  @override
  String get brushSettingsFadeStartValueLabel => '開始値(%)';

  @override
  String get brushSettingsFadeEndValueLabel => '終了値(%)';

  @override
  String get brushSettingsFadeDistanceLabel => '距離(px)';

  @override
  String get brushSettingsStrokeDecayTitle => 'ストローク減衰';

  @override
  String get brushSettingsStrokeDecaySubtitle => '描き続けるほど不透明度が下がる';

  @override
  String get brushSettingsMixingTitle => '混色';

  @override
  String get brushSettingsMixingOff => 'OFF';

  @override
  String get brushSettingsMixingSimple => '簡易混色';

  @override
  String get brushSettingsMixingBleed => 'にじみ';

  @override
  String get brushSettingsMixingRateLabel => '混色率';

  @override
  String get projectDetailNotFoundTitle => 'プロジェクト';

  @override
  String get projectDetailNotFoundBody => 'プロジェクトが見つかりません';

  @override
  String get projectDetailFirstFrameTooltip => '先頭フレーム';

  @override
  String get projectDetailPrevFrameTooltip => '1フレーム戻る';

  @override
  String get projectDetailPauseTooltip => '一時停止';

  @override
  String get projectDetailPlayTooltip => '再生';

  @override
  String get projectDetailNextFrameTooltip => '1フレーム進む';

  @override
  String get projectDetailLastFrameTooltip => '最終フレーム';

  @override
  String get projectDetailFullscreenTooltip => 'プレビューを全画面表示';

  @override
  String get projectDetailFullscreenCloseTooltip => '全画面プレビューを閉じる';

  @override
  String get projectDetailCollapsePreviewTooltip => 'プレビューを縮小表示';

  @override
  String get projectDetailExpandPreviewTooltip => 'プレビューを通常サイズに戻す';

  @override
  String get projectDetailStartEditButton => '編集開始';

  @override
  String get projectDetailTagsQuickAction => 'タグ';

  @override
  String get projectDetailShareQuickAction => '共有';

  @override
  String get projectDetailInfoSectionTitle => 'プロジェクト情報';

  @override
  String get projectDetailInfoExportSize => '書き出しサイズ';

  @override
  String get projectDetailInfoDrawingArea => '描画領域';

  @override
  String projectDetailInfoDrawingAreaValue(String size, String scale) {
    return '$size  ($scale)';
  }

  @override
  String get projectDetailInfoTotalFrames => '総フレーム数';

  @override
  String get projectDetailInfoWorkTime => '制作時間';

  @override
  String get projectDetailInfoLastSaved => '最終保存';

  @override
  String get projectDetailInfoSize => '容量';

  @override
  String get projectDetailSaveTreeButton => 'セーブツリー';

  @override
  String get projectDetailAddTagHint => 'タグを追加';

  @override
  String projectDetailNiashareFailedSnackbar(String error) {
    return '.niashareの作成に失敗しました: $error';
  }

  @override
  String get projectDetailTrashMenuItem => 'ゴミ箱へ移動';

  @override
  String get commonOff => 'OFF';

  @override
  String get perfSettingsScreenTitle => 'パフォーマンス設定';

  @override
  String get perfSettingsQualitySection => '品質設定';

  @override
  String get perfSettingsQualityLow => '低品質';

  @override
  String get perfSettingsQualityMedium => '中品質';

  @override
  String get perfSettingsQualityHigh => '高品質';

  @override
  String get perfSettingsQualityCustom => 'カスタム';

  @override
  String get perfSettingsQualityDescLow => '動作を軽くしたい端末向け（オニオン前後1枚・スロット5件）';

  @override
  String get perfSettingsQualityDescMedium => '標準的な端末向け（オニオン前後3枚・スロット10件）';

  @override
  String get perfSettingsQualityDescHigh => '快適な動作に余裕のある端末向け（オニオン前後5枚・ツリー方式）';

  @override
  String get perfSettingsQualityDescCustom => '各項目を個別設定';

  @override
  String get perfSettingsCapacitySection => '容量・動作に関わる設定';

  @override
  String get perfSettingsUndoLimitTitle => 'Undo回数';

  @override
  String get perfSettingsUndoLimitSubtitle => '多いほどメモリを消費する';

  @override
  String perfSettingsUndoLimitValue(int n) {
    return '$n回';
  }

  @override
  String get perfSettingsTrashAutoDeleteTitle => 'ゴミ箱の自動削除';

  @override
  String get perfSettingsTrashAutoDeleteSubtitle => '削除済みプロジェクトの保持期間';

  @override
  String perfSettingsTrashAutoDeleteValue(int n) {
    return '$n日';
  }

  @override
  String get perfSettingsCurrentSettingsSection => '現在の設定';

  @override
  String get perfSettingsTiltLabel => '傾き検知';

  @override
  String get perfSettingsOnionPrevLabel => 'オニオンスキン（前）';

  @override
  String get perfSettingsOnionNextLabel => 'オニオンスキン（後）';

  @override
  String perfSettingsOnionFrameCountValue(int n) {
    return '$n枚';
  }

  @override
  String get perfSettingsSaveModeLabel => '保存方式';

  @override
  String get perfSettingsSlotCountLabel => 'スロット数';

  @override
  String perfSettingsSlotCountValue(int n) {
    return '$n件';
  }

  @override
  String get perfSettingsResetButton => '初期値に戻す';

  @override
  String get perfSettingsCopyPresetButton => '現在のプリセットをコピー';

  @override
  String get perfSettingsTiltSwitchTitle => 'ペンの傾きをブラシに反映';

  @override
  String get perfSettingsShowPrevOnionTitle => '前フレームを表示';

  @override
  String get perfSettingsOnionCountPrevLabel => 'オニオンスキン枚数（前）';

  @override
  String get perfSettingsShowNextOnionTitle => '後フレームを表示';

  @override
  String get perfSettingsOnionCountNextLabel => 'オニオンスキン枚数（後）';

  @override
  String get perfSettingsSaveModeSlot => 'スロット方式';

  @override
  String get perfSettingsSaveModeTree => 'ツリー方式';

  @override
  String get perfSettingsResetDialogTitle => 'カスタム品質設定を初期値に戻しますか？';

  @override
  String perfSettingsResetDialogBody(String preset) {
    return '初期値は、初回起動時に端末性能から自動判定された「$preset」の設定になります。';
  }

  @override
  String get perfSettingsResetConfirmButton => '戻す';

  @override
  String get perfSettingsCopyPresetDialogTitle => 'コピーするプリセットを選択';

  @override
  String get perfSettingsCopyPresetDialogBody => 'カスタム設定へコピーするプリセットを選択してください。';

  @override
  String get perfSettingsCopyDescLow => '前後1枚表示・軽量動作';

  @override
  String get perfSettingsCopyDescMedium => '前後3枚表示・標準';

  @override
  String get perfSettingsCopyDescHigh => '前後5枚表示・高品質';

  @override
  String get filterPanelTitle => 'フィルター';

  @override
  String filterPanelTitleBulk(int count) {
    return 'フィルター（$countフレームへ一括適用）';
  }

  @override
  String get filterSearchHint => 'フィルター検索';

  @override
  String get filterNameGaussianBlur => 'ガウスぼかし';

  @override
  String get filterNameLensBlur => 'レンズぼかし';

  @override
  String get filterNameAnimeStyle => 'アニメ風加工';

  @override
  String get filterNameOutline => '縁取り';

  @override
  String get filterNameToneCurve => 'トーンカーブ';

  @override
  String get filterNameLevels => 'レベル補正';

  @override
  String get filterNameSharpen => 'シャープ';

  @override
  String get filterNameUnsharpMask => 'アンシャープマスク';

  @override
  String get filterSharpenStrength => 'シャープの強さ';

  @override
  String get filterUnsharpAmount => 'かかり具合';

  @override
  String get filterNameVignette => '周辺減光';

  @override
  String get filterVignetteStrength => '減光の強さ';

  @override
  String get filterVignetteColor => '減光色';

  @override
  String get filterNameNoise => 'フィルムグレイン';

  @override
  String get filterNoiseStrength => '粒子の強さ';

  @override
  String get filterNameRetroAnime => 'レトロアニメ';

  @override
  String get filterNameCrt => 'ブラウン管';

  @override
  String get filterRetroStrength => '強さ';

  @override
  String filterOutlineLayerNameSuffix(String name) {
    return '$name（縁取り）';
  }

  @override
  String get filterStrengthBlurRadius => '強さ（ぼかし半径）';

  @override
  String get filterColorLevels => '色数';

  @override
  String get filterEdgeStrength => 'エッジ強調';

  @override
  String get filterOutlineColor => '縁取り色';

  @override
  String get filterOutlineWidth => '縁取り線幅';

  @override
  String get filterToneCurveLinear => '標準';

  @override
  String get filterToneCurveBrighten => '明るく';

  @override
  String get filterToneCurveDarken => '暗く';

  @override
  String get filterToneCurveHighContrast => 'コントラスト強';

  @override
  String get filterToneCurveLowContrast => 'コントラスト弱';

  @override
  String get filterToneCurveInvert => '反転';

  @override
  String get filterLevelsInputBlack => '入力：黒';

  @override
  String get filterLevelsInputWhite => '入力：白';

  @override
  String get filterLevelsOutputBlack => '出力：黒';

  @override
  String get filterLevelsOutputWhite => '出力：白';

  @override
  String get filterApplyButton => '適用';

  @override
  String filterApplyBulkButton(int count) {
    return '$countフレームへ適用';
  }

  @override
  String get filterEmpty => 'フィルターがありません';

  @override
  String get filterApplyingTitle => 'フィルター適用中';

  @override
  String filterApplyingSubtitle(String name, int count) {
    return '$name　$countフレーム';
  }

  @override
  String get projectListNewFolderTitle => '新規フォルダ';

  @override
  String get projectListFolderHint => '同じ作品の複数話数やシリーズをまとめる場合にも使えます';

  @override
  String get projectListEmptyTitle => 'プロジェクトがありません';

  @override
  String get projectListEmptyHint => '＋ ボタンから新規作成';

  @override
  String get projectListOpenAction => '開く';

  @override
  String get projectListCreateShareAction => '.niashareを作成';

  @override
  String get projectListEditFolderAction => '名前・色を編集';

  @override
  String get projectListDeleteFolderConfirmTitle => 'フォルダを削除しますか？';

  @override
  String projectListDeleteFolderConfirmBody(String name) {
    return '「$name」を削除します。中のプロジェクト・子フォルダはルートへ戻ります。';
  }

  @override
  String get projectListFolderRootOption => 'フォルダなし（ルート）';

  @override
  String get projectListEditFolderTooltip => 'フォルダを編集';

  @override
  String get projectListCreateFolderAction => '新規フォルダを作成';

  @override
  String get projectListFolderColorLabel => 'フォルダ色';

  @override
  String get projectListMaterialIncludeTitle => '素材の同梱';

  @override
  String get projectListMaterialIncludeHint => '同梱しない場合、受信側で不足素材の警告が表示されます。';

  @override
  String get projectListMaterialImage => '画像';

  @override
  String get projectListMaterialVideo => '動画';

  @override
  String get projectListMaterialAudio => '音声';

  @override
  String get projectListIncludeFontsTitle => 'フォントを含める';

  @override
  String get projectListIncludeFontsSubtitle => '使用中のユーザー追加フォントを同梱します';

  @override
  String get blendModeNormal => '通常';

  @override
  String get blendModeMultiply => '乗算';

  @override
  String get blendModeScreen => 'スクリーン';

  @override
  String get blendModeOverlay => 'オーバーレイ';

  @override
  String get blendModeAddition => '加算';

  @override
  String get blendModeSubtract => '減算';

  @override
  String get blendModeDarken => '比較（暗）';

  @override
  String get blendModeLighten => '比較（明）';

  @override
  String get blendModeColorBurn => '焼き込みカラー';

  @override
  String get blendModeColorDodge => '覆い焼きカラー';

  @override
  String get blendModeHardLight => 'ハードライト';

  @override
  String get blendModeSoftLight => 'ソフトライト';

  @override
  String get blendModeDifference => '差の絶対値';

  @override
  String get blendModeHue => '色相';

  @override
  String get blendModeSaturation => '彩度';

  @override
  String get blendModeColor => 'カラー';

  @override
  String get blendModeLuminosity => '輝度';

  @override
  String get autofillLineColorModeSpecified => '指定色';

  @override
  String get autofillLineColorModeSameAsFill => '塗り色と同じ';

  @override
  String get autofillLineColorModeTraceAdjust => '色トレス・線画馴染ませ';

  @override
  String get autofillGradientTypeLinear => '直線';

  @override
  String get autofillGradientTypeRadialCenterOut => '放射：中央→外側';

  @override
  String get autofillGradientTypeRadialOutCenter => '放射：外側→中央';

  @override
  String get autofillPresetScreenTitle => '自動塗り設定';

  @override
  String get autofillPresetSearchHint => '設定を検索';

  @override
  String get autofillPresetEmptyFavorites => 'お気に入りの設定がありません';

  @override
  String get autofillPresetEmpty => '設定がありません';

  @override
  String get autofillPresetEmptyHint => '右下の＋から作成できます';

  @override
  String autofillPresetPartsCount(int count) {
    return '$countパーツ';
  }

  @override
  String get autofillPresetNewDialogTitle => '新規作成';

  @override
  String get autofillPresetNameLabel => '設定名';

  @override
  String get autofillPresetRenameDialogTitle => '設定名を変更';

  @override
  String autofillPresetDeleteConfirmTitle(String name) {
    return '「$name」を削除しますか？';
  }

  @override
  String get autofillFabImportOption => '読み込み';

  @override
  String get autofillPresetExportMenuItem => '書き出し (.niafill)';

  @override
  String autofillPresetImportSuccessSnackbar(int count) {
    return '$count件のプリセットを読み込みました';
  }

  @override
  String autofillPresetImportFailedSnackbar(String error) {
    return '読み込みに失敗しました: $error';
  }

  @override
  String autofillPresetExportFailedSnackbar(String error) {
    return '書き出しに失敗しました: $error';
  }

  @override
  String autofillPresetDuplicateName(String name) {
    return '$name (コピー)';
  }

  @override
  String get autofillPartSearchHint => 'パーツ名で検索';

  @override
  String autofillPartUnconfiguredBanner(int count, String names) {
    return '未設定のパーツが$count件あります：$names（トーン未選択）\nすべて設定するまでこの画面を閉じられません。';
  }

  @override
  String get autofillPartUnconfiguredDialogTitle => '未設定のパーツがあります';

  @override
  String get autofillPartUnconfiguredDialogBody => '保存する前に、以下のパーツを設定してください。';

  @override
  String autofillPartUnconfiguredItem(String name) {
    return '・$name：トーンが未選択です';
  }

  @override
  String get autofillPartUnconfiguredBackButton => '設定へ戻る';

  @override
  String get autofillPartEmpty => 'パーツがありません\n＋ボタンで追加してください';

  @override
  String get autofillPartToneUnselected => 'トーンが未選択です';

  @override
  String get autofillPartAddDialogTitle => 'パーツ追加';

  @override
  String get autofillPartNameLabel => 'パーツ名';

  @override
  String get autofillPartAddButton => '追加';

  @override
  String get autofillPartRenameDialogTitle => 'パーツ名変更';

  @override
  String autofillPartDetailDialogTitle(String name) {
    return '$nameの詳細設定';
  }

  @override
  String get autofillPartFillColorLabel => '塗り色';

  @override
  String get autofillPartSelectColorButton => '色を選択';

  @override
  String get autofillPartOutlineLabel => '指定色で縁取り';

  @override
  String autofillPartOutlineWidthLabel(int value) {
    return '縁取り太さ: ${value}px';
  }

  @override
  String get autofillPartResetLineColorButton => 'デフォルトに戻す';

  @override
  String get autofillThumbnailHint => 'サムネイル画像（参照イラスト等）を設定すると、そこからスポイトで色を拾えます。';

  @override
  String get autofillThumbnailSetButton => '画像を追加';

  @override
  String get autofillThumbnailChangeButton => '画像を変更';

  @override
  String get autofillEyedropperFromThumbnailButton => '画像からスポイト';

  @override
  String get autofillEyedropperDialogTitle => '画像から色を拾う';

  @override
  String get autofillEyedropperDialogHint => '画像をタップして色を選択してください';

  @override
  String get autofillEyedropperPickedLabel => '選択した色';

  @override
  String get autofillEyedropperImageLoadFailedSnackbar => '画像を読み込めませんでした';

  @override
  String get autofillThumbnailMenuItem => 'サムネイル画像設定';

  @override
  String get autofillThumbnailLoadButton => '画像読み込み';

  @override
  String get autofillThumbnailDeleteButton => 'サムネイル画像削除';

  @override
  String get autofillThumbnailDeleteConfirmTitle => 'サムネイル画像を削除しますか？';

  @override
  String get autofillThumbnailDeleteConfirmBody => '削除すると既定のパーツ色表示（最大4色）に戻ります。';

  @override
  String get autofillThumbnailCropDialogTitle => 'サムネイル画像を調整';

  @override
  String get autofillThumbnailCropDialogHint => 'ドラッグで位置調整、ピンチで拡大縮小、2本指で回転できます';

  @override
  String get autofillThumbnailCropLoadFailed => '画像を読み込めませんでした。別の画像でお試しください。';

  @override
  String get autofillThumbnailSetSnackbar => 'サムネイル画像を設定しました';

  @override
  String get autofillPartGradientSetButton => 'グラデーション設定';

  @override
  String get autofillPartGradientEditButton => 'グラデーション編集';

  @override
  String autofillPartFillOpacityLabel(int value) {
    return '不透明度（塗りレイヤー）: $value%';
  }

  @override
  String get autofillPartLineColorLabel => '線画色';

  @override
  String autofillPartTraceHueLabel(int value) {
    return '色相: $value';
  }

  @override
  String autofillPartTraceSaturationLabel(int value) {
    return '彩度: $value';
  }

  @override
  String autofillPartTraceLightnessLabel(int value) {
    return '明度: $value';
  }

  @override
  String autofillPartLineOpacityLabel(int value) {
    return '不透明度（線画レイヤー）: $value%';
  }

  @override
  String get autofillPartToneLabel => 'トーン';

  @override
  String get autofillPartUseToneCheckbox => 'トーンを使用';

  @override
  String get autofillPartBlendModeLabel => 'ブレンドモード';

  @override
  String get autofillPartApplyButton => '適用';

  @override
  String autofillPartGradientDialogTitle(String name) {
    return '$nameのグラデーション';
  }

  @override
  String get autofillPartGradientTypeLabel => '種類';

  @override
  String get autofillPartGradientTypeInfo =>
      '直線：指定した角度に沿って色が変化します。放射：中央→外側は中心から外側へ、外側→中央は逆に外側から中心へ色が変化します。';

  @override
  String get autofillPartGradientFeatherInfo =>
      '0%にすると隣り合う色の境界がくっきり分かれます。100%にすると隣の色の端まで完全になめらかに混ざります。';

  @override
  String get autofillLineColorModeTraceAdjustInfo =>
      '元の線の色を保ったまま、色相・彩度・明度をずらして少しだけ色味を変える機能です。線を単色で塗りつぶすのではなく、線画の濃淡を活かしたい場合に使います。';

  @override
  String autofillPartGradientAngleLabel(int value) {
    return '角度: $value°';
  }

  @override
  String get autofillPartGradientColorLabel => '色';

  @override
  String get autofillPartGradientAddColorButton => '色を追加';

  @override
  String get autofillPartGradientDeleteHint => '長押しで削除（2色未満にはできません）';

  @override
  String get autofillPartGradientRemoveButton => 'グラデーション解除';

  @override
  String autofillPartGradientFeatherLabel(int value) {
    return 'ぼかしの強さ: $value%';
  }

  @override
  String get autofillPartGradientDragHint => 'ドラッグ（右端のハンドル）で色の順番を入れ替えられます';

  @override
  String autofillPartGradientStopLabel(int value) {
    return '切り替え位置: $value%';
  }

  @override
  String get autofillPartGradientStopDragHint => '▲を左右にドラッグして色の切り替え位置を調整できます';

  @override
  String get saveTreeScreenTitleTree => 'セーブツリー';

  @override
  String get saveTreeScreenTitleSlot => 'セーブスロット';

  @override
  String get timelineExportMenuItem => '書き出し';

  @override
  String get timelineExportFrameMenuItem => 'フレームを画像で書き出す';

  @override
  String get timelineExportFrameDialogTitle => 'フレームを画像で書き出す';

  @override
  String get timelineExportFrameDialogMessage =>
      '現在表示中のフレーム1枚を静止画として保存します。形式を選んでください。';

  @override
  String get timelineExportFramePngOption => 'PNGで保存';

  @override
  String get timelineExportFrameJpegOption => 'JPEGで保存';

  @override
  String timelineExportFrameSuccessSnackbar(String fileName) {
    return '$fileName として保存しました（作品一覧タブから確認できます）';
  }

  @override
  String get timelineExportFrameErrorSnackbar => 'フレームの書き出しに失敗しました';

  @override
  String get timelineDurationChangeMenuItem => '長さ変更';

  @override
  String get timelineCanvasSizeChangeMenuItem => 'キャンバスサイズ変更';

  @override
  String get timelineDurationFramesLabel => 'フレーム数';

  @override
  String get timelineDurationSecondsLabel => '秒数';

  @override
  String get timelineDurationShrinkConfirmTitle => '本当に短くしますか？';

  @override
  String get timelineDurationShrinkConfirmBody =>
      'カットされる範囲のフレームには、描画内容やレイヤー追加などの変更が加えられています。この操作を行うと、それらのフレームは元に戻せなくなります。本当に削除してよいですか？';

  @override
  String get timelineCanvasSizeDragHint =>
      '枠内をドラッグして位置を、四隅をドラッグしてサイズを変更できます（元のサイズ付近でスナップします）';

  @override
  String get timelineCanvasSizeAngleLabel => '角度';

  @override
  String get saveTreeSaveAsChildHint => '選択中のノードの子として保存します。';

  @override
  String get saveTreeSaveAsRootHint => 'ルートノードとして保存します。';

  @override
  String get saveTreeCommentLabel => 'コメント（任意）';

  @override
  String get saveTreeCommentHint => '例：背景完成';

  @override
  String saveTreeSizeWarningSnackbar(String mb) {
    return 'セーブツリーの容量が大きくなっています（約${mb}MB）。不要な保存データの削除をおすすめします。';
  }

  @override
  String saveTreeSlotSaveDialogTitle(int n) {
    return 'スロット $n に保存';
  }

  @override
  String saveTreeSlotOverwriteWarning(String date) {
    return '既存データ（$date）を上書きします。';
  }

  @override
  String get saveTreeRestoreAction => '復元';

  @override
  String get saveTreeTimelineActionChoiceBody =>
      'このセーブへ「上書き保存」するか、「ここから作業を再開」するか選んでください。';

  @override
  String get saveTreeOverwriteAction => '上書きする';

  @override
  String get saveTreeOverwriteConfirmBody => 'このときのセーブデータは消えますがよろしいですか？';

  @override
  String get saveTreeResumeFromHereAction => 'ここから再開する';

  @override
  String get saveTreeResumeConfirmBody => 'セーブしていない場合は現在のデータが消えますがよろしいですか？';

  @override
  String get saveTreeProjectDetailResumeBody => 'このセーブデータから作業を再開しますか？';

  @override
  String get saveTreeLoadFailedSnackbar => '保存データの読み込みに失敗しました';

  @override
  String saveTreeRestoredSnackbar(String name) {
    return '$nameを復元しました';
  }

  @override
  String saveTreeSlotLabel(int n) {
    return 'スロット$n';
  }

  @override
  String saveTreeSlotFallbackName(int n) {
    return 'スロット $n';
  }

  @override
  String get saveTreeNoDataLabel => '保存データなし';

  @override
  String get saveTreeEmptyTitle => '保存データがありません';

  @override
  String get saveTreeEmptyHint => '上部の「保存」ボタンで最初のノードを作成できます';

  @override
  String get saveTreeNodeDefaultTitle => '保存';

  @override
  String get saveTreeNodeDefaultName => '保存データ';

  @override
  String get saveTreeChangeDataTitle => '保存データ変更';

  @override
  String saveTreeChangeDataTitleWithProject(String name) {
    return '保存データ変更（$name）';
  }

  @override
  String get saveTreeChangeExceedMessage =>
      '現在の保存データ数が\n新しい保存可能数を超えています。\n\n保持する保存データを選択してください。';

  @override
  String saveTreeKeepableCountLabel(int n) {
    return '保持できる保存数：$n件';
  }

  @override
  String saveTreeKeepLatestButton(int n) {
    return '最新$n件を保存';
  }

  @override
  String get saveTreeSelectDataButton => '保存データを選択';

  @override
  String saveTreeSelectedCountLabel(int selected, int limit) {
    return '選択中：$selected / $limit件';
  }

  @override
  String get saveTreeBackButton => '戻る';

  @override
  String get saveTreeNextButton => '次へ';

  @override
  String get saveTreeDiscardDialogTitle => '選択されなかった保存データ';

  @override
  String get saveTreeArchiveOptionTitle => 'アーカイブとして保持する（推奨）';

  @override
  String get saveTreeArchiveOptionSubtitle =>
      'セーブツリー方式へ戻したときに自動で復元されます。\nストレージ容量を使用します。';

  @override
  String get saveTreeDeleteOptionTitle => '完全に削除する';

  @override
  String saveTreeDeleteOptionSubtitle(int count) {
    return '選択されなかった$count件を完全に削除します。\nストレージ容量を節約できます。\n※削除したデータは元に戻せません。';
  }

  @override
  String get saveTreeApplyChangeButton => '変更する';

  @override
  String get canvasEditMenuAutofillPresets => '自動塗り設定';

  @override
  String get canvasEditMenuAutofillPresetsSubtitle => 'パーツごとの色・トーンの組み合わせを編集';

  @override
  String get canvasEditMenuBackgroundToggle => '背景切替';

  @override
  String get canvasEditMenuBackgroundCurrentColor => '現在：プロジェクト背景色（タップで透過へ）';

  @override
  String get canvasEditMenuBackgroundCurrentTransparent =>
      '現在：透過（タップでプロジェクト背景色へ）';

  @override
  String get canvasEditMenuOnionSkinSubtitle => '前後のフレームを薄く重ねて表示';

  @override
  String get canvasEditMenuFilterSubtitle => 'ぼかし・トーンカーブなどを適用';

  @override
  String get canvasEditMenuFrameMultiSelect => 'フレーム複数選択';

  @override
  String get canvasEditMenuFrameMultiSelectSubtitle => '大量処理（フィルター一括適用など）に使用';

  @override
  String get canvasEditMenuPressureCurve => '筆圧カーブ';

  @override
  String get canvasEditMenuPressureCurveSubtitle => 'ペン入力設定を開く（設定画面と共通）';

  @override
  String get canvasEditMenuMeshTransform => '自由変形・メッシュ変形';

  @override
  String get canvasEditMenuMeshTransformSubtitle => 'レイヤー全体を選択せずに変形する';

  @override
  String get meshTransformPanelTitle => '自由変形・メッシュ変形';

  @override
  String get meshTransformPanelHint =>
      '角や格子点を指でドラッグして動かせます（2本指で別々の点をつまむと回転・拡大縮小も可能）';

  @override
  String get meshTransformDensityLabel => '分割数';

  @override
  String get meshTransformRotateLabel => '回転';

  @override
  String get meshTransformScaleLabel => '拡大縮小';

  @override
  String get meshTransformApplyButton => '適用';

  @override
  String get canvasLassoEnclosedLabel => '囲って塗る';

  @override
  String get canvasInvertSelectionTooltip => '選択範囲を反転';

  @override
  String get canvasTapToEnterTextLabel => 'キャンバスをタップしてテキストを入力';

  @override
  String get canvasRulerFirstUseTip => '定規を使うとまっすぐな線や綺麗な図形が描けます。';

  @override
  String get canvasRulerTooltip => '定規';

  @override
  String get commonUndo => 'Undo';

  @override
  String get commonRedo => 'Redo';

  @override
  String get canvasSettingsMenuTooltip => '設定/編集';

  @override
  String canvasFrameSelectedCount(int selected, int total) {
    return '$selected / $total フレーム選択中';
  }

  @override
  String get canvasSelectAllButton => '全選択';

  @override
  String get canvasDeselectAllButton => '全解除';

  @override
  String get canvasApplyFilterButton => 'フィルター適用';

  @override
  String get canvasShapeOff => 'OFF（通常ブラシへ戻る）';

  @override
  String get canvasShapeLine => '線';

  @override
  String get canvasShapeRect => '四角形';

  @override
  String get canvasShapeCircle => '円';

  @override
  String get canvasMissingMaterialsSnackbar => '不足素材があります';

  @override
  String get canvasResearchButton => '再検索';

  @override
  String get canvasTextInputTitle => 'テキスト入力';

  @override
  String get canvasTextEditTitle => 'テキスト編集';

  @override
  String get canvasTextInputHint => 'テキストを入力してください';

  @override
  String get canvasTextFontLabel => 'フォント';

  @override
  String get canvasTextStandardFont => '標準フォント';

  @override
  String get canvasTextBold => '太字';

  @override
  String get canvasTextItalic => '斜体';

  @override
  String get canvasTextVertical => '縦書き';

  @override
  String get canvasTextHorizontal => '横書き';

  @override
  String get canvasTypesettingHelpTooltip => '組版・ルビについて';

  @override
  String get canvasTextLineHeight => '行間';

  @override
  String get canvasTextLetterSpacing => '文字間隔';

  @override
  String get canvasTextAlign => '揃え';

  @override
  String get canvasTextOutline => 'アウトライン';

  @override
  String get canvasOutlineWidthLabel => '太さ';

  @override
  String get canvasHelpRotationTitle => '半角英数字の回転（縦書きのみ）';

  @override
  String get canvasHelpRotationBody => '英字・記号は自動的に90°回転して表示されます。';

  @override
  String get canvasHelpTatechuyokoTitle => '縦中横（縦書きのみ）';

  @override
  String get canvasHelpTatechuyokoBody =>
      '半角数字が2桁連続すると、1文字分の高さに横並びで自動的に収まります（例：12）。';

  @override
  String get canvasHelpRubyTitle => 'ルビ（ふりがな）';

  @override
  String canvasHelpRubyBody(String example) {
    return '「$example」のように入力すると、基底文字の上（横書き）または右側（縦書き）に小さくふりがなが表示されます。縦書き・横書きどちらでも使えますが、ルビを含むテキストは横書きでの自動折り返しが効かなくなります（手動改行のみ対応）。';
  }

  @override
  String get layerPanelTitle => 'レイヤー';

  @override
  String get layerPanelHelpTooltip => 'ヘルプ';

  @override
  String get layerPanelSearchHint => 'レイヤー名で検索';

  @override
  String get layerPanelSelectAll => '全選択';

  @override
  String get layerPanelDeselectAll => '全解除';

  @override
  String get layerPanelNewLayerButton => '新規レイヤー';

  @override
  String get layerPanelNewFolderButton => '新規フォルダ';

  @override
  String get layerPanelImportImageButton => '画像読み込み';

  @override
  String layerPanelDefaultLayerName(int n) {
    return 'レイヤー$n';
  }

  @override
  String layerPanelDefaultFolderName(int n) {
    return 'フォルダ$n';
  }

  @override
  String layerPanelDefaultLineartName(int n) {
    return '線画$n';
  }

  @override
  String layerPanelDefaultAutofillName(int n) {
    return '自動塗り$n';
  }

  @override
  String layerPanelDefaultCommonName(int n) {
    return '共通$n';
  }

  @override
  String layerPanelDefaultSelectionName(int n) {
    return '選択$n';
  }

  @override
  String get layerPanelClippingBadge => 'クリッピング';

  @override
  String get layerPanelAddTooltip => '追加';

  @override
  String get layerPanelMergeTooltip => '結合';

  @override
  String get layerPanelSettingsTooltip => 'レイヤー設定';

  @override
  String get layerPanelAutofillMarkTooltip =>
      '線画が更新されました。タップすると自動塗りを最新の状態に更新できます。';

  @override
  String get layerPanelRangeAllFrames => '全フレーム';

  @override
  String get layerPanelRangeCurrentScene => '現在シーン';

  @override
  String get layerPanelRangeSceneSpecified => 'シーン指定';

  @override
  String layerPanelRangeFrameSpan(int start, int end) {
    return '$start〜$end';
  }

  @override
  String get layerPanelMenuFrameRangeChange => '表示フレーム範囲変更';

  @override
  String get layerPanelMenuRangeChange => '表示範囲変更';

  @override
  String get layerPanelMenuPartAssign => 'パーツ設定';

  @override
  String get layerPanelMenuRunAutofill => '自動塗り実行';

  @override
  String get layerPanelMenuOrphanFill => '最新の色で塗りつぶす';

  @override
  String get layerPanelMenuOrphanFillSubtitle =>
      '対応する線画レイヤーが見つからないため色更新のみ実行します';

  @override
  String get layerPanelMenuReplaceMaterial => '素材差し替え';

  @override
  String layerPanelDeleteConfirmTitle(String name) {
    return '$nameを削除しますか？';
  }

  @override
  String get layerPanelDeleteConfirmBody => 'この素材の表示範囲内のすべてのフレームから削除されます。';

  @override
  String layerPanelMultiDeleteConfirmTitle(int count) {
    return '選択中の$count件を削除しますか？';
  }

  @override
  String get layerPanelMultiDeleteConfirmBody =>
      'タイムライン素材の表示範囲内のすべてのフレームから削除されます。';

  @override
  String layerPanelCommonDeleteMidDialogTitle(String name) {
    return '$nameの表示範囲を変更しますか？';
  }

  @override
  String get layerPanelCommonDeleteMidDialogBody =>
      '共通レイヤーの表示範囲は連続した1区間でしか設定できないため、範囲の途中のフレームでは削除できません。代わりに、このフレームより前と後のどちらを残すか選んでください。';

  @override
  String get layerPanelCommonDeleteKeepBeforeButton => 'これより前を残す';

  @override
  String get layerPanelCommonDeleteKeepAfterButton => 'これより後を残す';

  @override
  String get layerPanelRangeDialogTitle => '表示範囲';

  @override
  String get layerPanelRangeStartFrameLabel => '開始フレーム';

  @override
  String get layerPanelRangeEndFrameLabel => '終了フレーム';

  @override
  String get layerPanelRangeTilde => '〜';

  @override
  String get layerPanelRangeUseCurrentButton => '現在範囲を使用';

  @override
  String get layerPanelRangeTargetSceneLabel => '対象シーン';

  @override
  String get layerPanelRangeFrameRangeLabel => 'フレーム範囲指定';

  @override
  String get layerPanelMenuNormalLayer => '通常レイヤー';

  @override
  String get layerPanelMenuCommonLayer => '共通レイヤー';

  @override
  String get layerPanelMenuLineartLayer => '自動塗り用線画レイヤー';

  @override
  String get layerPanelMenuAutofillLayer => '自動塗りレイヤー';

  @override
  String get layerPanelMenuSelectionLayer => '選択レイヤー';

  @override
  String get layerPanelOpacityLabel => '不透明度';

  @override
  String get layerPanelLockLabel => 'ロック';

  @override
  String get layerPanelOpacityLockLabel => '不透明度ロック';

  @override
  String get layerPanelClippingDescription => '下のレイヤーの不透明範囲内のみ描画';

  @override
  String get layerPanelConvertToCommonLabel => '共通レイヤーへ変更';

  @override
  String get layerPanelConvertOption1Title => '現在レイヤーを共通化';

  @override
  String get layerPanelConvertOption1Subtitle => 'このレイヤーのみを共通レイヤーとして設定します';

  @override
  String get layerPanelConvertOption2Title => '表示中レイヤーを複製して全統合して共通化';

  @override
  String get layerPanelConvertOption2Subtitle =>
      '表示中のすべてのレイヤーを統合した結果を共通レイヤーとして作成します';

  @override
  String get layerPanelCommonRangeTitle => '共通レイヤー範囲';

  @override
  String get layerPanelHelpDialogTitle => 'レイヤーについて';

  @override
  String get layerPanelHelpBlendModeBody =>
      'レイヤーの合成方法を変更します。乗算・スクリーン・オーバーレイなどがあります。';

  @override
  String get layerPanelHelpClippingBody =>
      '下のレイヤーの不透明ピクセル範囲内のみ描画します。描画範囲を制御したい場合はこちらを使用してください。';

  @override
  String get layerPanelCommonLayerLabel => '共通レイヤー';

  @override
  String get layerPanelHelpCommonLayerBody =>
      '複数のフレームで同じ内容を共有するレイヤーです。表示するフレーム範囲を設定できます。';

  @override
  String get layerPanelAutofillMethodTitle => '自動塗り方法';

  @override
  String get layerPanelAutofillNoLineartSnackbar => '対応する自動塗り用線画レイヤーが見つかりません。';

  @override
  String get layerPanelAutofillNote1 =>
      '※ プロジェクト内で自動塗りを初回実行する場合はどちらを選んでも問題ありません。';

  @override
  String get layerPanelAutofillNote2 =>
      '※ 自動塗りレイヤーが存在しない場合は、一から領域を判定して自動塗りします。';

  @override
  String get layerPanelAutofillRepaintTitle => '塗りなおし';

  @override
  String get layerPanelAutofillRepaintHint => '誤って自動塗りの形状を変えてしまった場合におすすめ';

  @override
  String get layerPanelAutofillRepaintNote =>
      '※ 一から領域を判定して塗りなおします。現在の自動塗りレイヤーの形状は破棄されます。';

  @override
  String get layerPanelAutofillColorUpdateTitle => '色更新';

  @override
  String get layerPanelAutofillColorUpdateHint => '自動塗りの形状を手動で調整した場合におすすめ';

  @override
  String get layerPanelAutofillColorUpdateNote =>
      '※ 不透明度ロックをして最新の色で塗りつぶします。現在の自動塗りレイヤーの形状は維持されます。';

  @override
  String get layerPanelExecuteButton => '実行';

  @override
  String get layerPanelAutofillPartMissingSnackbar =>
      'パーツが未設定です。「パーツ設定」から設定してください。';

  @override
  String get layerPanelAutofillPresetMissingSnackbar =>
      '対応する自動塗り設定のパーツが見つかりません。';

  @override
  String layerPanelAutofillLayerNameSuffix(String name) {
    return '$name（自動塗り）';
  }

  @override
  String get layerPanelOrphanFillSuccessSnackbar =>
      '対応する線画レイヤーが見つからないため、最新の色で塗りつぶしました。';

  @override
  String get layerPanelOrphanFillFailSnackbar =>
      'パーツが未設定、または塗り形状がないため処理できませんでした。';

  @override
  String get layerPanelAutofillUpdateHelpTitle => '自動塗り更新マーク';

  @override
  String get layerPanelAutofillUpdateHelpBody =>
      '現在の自動塗りは最新ではありません。タップすると更新できます。';

  @override
  String layerPanelReplaceMaterialSuccessSnackbar(String name) {
    return '素材を差し替えました: $name';
  }

  @override
  String layerPanelImportImageSuccessSnackbar(String name) {
    return '画像を読み込みました: $name';
  }

  @override
  String layerPanelCopySuffix(String name) {
    return '$nameのコピー';
  }

  @override
  String get timelineFullscreenPreviewCloseTooltip => '全画面プレビューを閉じる';

  @override
  String get timelineDefaultProjectName => 'プロジェクト名';

  @override
  String get timelineProjectSaveMenuItem => 'プロジェクト保存';

  @override
  String get timelinePreviewPlaceholder => 'プレビュー';

  @override
  String get timelinePreviewFullscreenTip =>
      'タップするとプレビューを全画面表示できます。仕上がりの確認に便利です。';

  @override
  String get timelinePreviewFullscreenTooltip => 'プレビューを全画面表示';

  @override
  String get timelineAddImageTooltip => '＋画像';

  @override
  String get timelineAddVideoTooltip => '＋動画';

  @override
  String get timelineAddAudioTooltip => '＋音源';

  @override
  String get timelineEffectFilterLabel => '演出フィルター';

  @override
  String get timelineAddCameraKfTooltip => 'カメラキーフレーム追加';

  @override
  String get timelineAddWatermarkTooltip => '＋ウォーターマーク';

  @override
  String get timelineWatermarkNotRegisteredTitle => 'ウォーターマーク未登録';

  @override
  String get timelineWatermarkNotRegisteredBody =>
      '設定画面の「ウォーターマーク」からあらかじめ画像または文字を登録してください。';

  @override
  String get timelineOpenSettingsButton => '設定を開く';

  @override
  String get timelineWatermarkSelectTitle => 'ウォーターマークを選択';

  @override
  String timelineWatermarkAddedSnackbar(String name) {
    return 'ウォーターマークを追加しました（全フレームに表示されます）: $name';
  }

  @override
  String get timelineWatermarkEditTitle => 'ウォーターマークを編集';

  @override
  String get timelineWatermarkAngleLabel => '角度';

  @override
  String get timelineWatermarkSizeLabel => '大きさ';

  @override
  String get timelineWatermarkOpacityLabel => '不透明度';

  @override
  String get timelineWatermarkLoopLabel => '常時表示（ループ表示）';

  @override
  String get timelineWatermarkLoopSubtitle => 'オフにすると現在のシーンのみに表示されます';

  @override
  String get timelineConfirmButton => '決定';

  @override
  String get timelineClipSelectDoneButton => '完了';

  @override
  String get timelineClipOverlapDialogTitle => '既存のクリップと重なります';

  @override
  String get timelineClipOverlapDialogBody =>
      '貼り付け先が既存のクリップと重なっています。どのように配置しますか？';

  @override
  String get timelineClipOverlapPlaceBefore => '前に配置する';

  @override
  String get timelineClipOverlapPlaceAfter => '後ろに配置する';

  @override
  String get timelineClipOverlapPlaceNewRow => '重ねて配置する（行を増やす）';

  @override
  String get timelineSceneRenameTitle => 'シーン名変更';

  @override
  String get timelineSceneDeleteMenuItem => 'シーン削除';

  @override
  String get timelineDurationLimitTitle => '長さの上限に達します';

  @override
  String get timelineDurationLimitBodyFree =>
      '無料会員は動画の長さが最大90秒までです。これ以上フレームを追加・複製すると90秒を超えてしまうため、実行できません。プレミアム会員になると最大2時間まで作成できます。';

  @override
  String get timelineDurationLimitBodyPremium =>
      'プレミアム会員の上限（最大2時間）を超えてしまうため、これ以上フレームを追加・複製できません。';

  @override
  String timelineSceneDeleteConfirmTitle(String name) {
    return '「$name」を削除しますか？';
  }

  @override
  String get timelineSceneDeleteConfirmBody =>
      'シーン内の全フレーム・共通レイヤー・動画素材・画像素材・ウォーターマークを含むすべてのデータが削除されます。';

  @override
  String timelineSceneMultiDeleteConfirmTitle(int count) {
    return '選択中の$count件のシーンを削除しますか？';
  }

  @override
  String get timelineAutofillUpdateHelpBody =>
      'このシーン・フレームには最新ではない自動塗りレイヤーが含まれています。レイヤーパネルで対象レイヤーをタップすると更新できます。';

  @override
  String get timelineFrameTrackLabel => 'フレーム';

  @override
  String get timelineTrackRowDeleteBlockedSnackbar =>
      'この行には素材があるため削除できません。先に素材を移動または削除してください。';

  @override
  String get timelineTrackRowRenameTitle => '行名を変更';

  @override
  String get timelineCameraTrackLabel => 'カメラ';

  @override
  String get timelineRangeSceneFixed => 'シーン固定';

  @override
  String get timelineEndCardCustomLabel => '差替済';

  @override
  String get timelineEndCardDefaultLogoLabel => 'NIARIMロゴ';

  @override
  String timelineEndCardStatusFormat(String label, int seconds) {
    return '$label・$seconds秒';
  }

  @override
  String get timelineEndCardHiddenLabel => '非表示';

  @override
  String get timelineEndCardVisibilityToggleTooltip => '表示ON/OFF';

  @override
  String get timelineEndCardLengthChangeTooltip => '長さ変更';

  @override
  String get timelineEndCardReplaceTooltip => '差し替え';

  @override
  String get timelineEndCardLengthDialogTitle => 'エンドカードの長さ';

  @override
  String get timelineEndCardTrackLabel => 'エンドカードトラック';

  @override
  String get timelineMarkerTrackLabel => 'タイムスタンプ';

  @override
  String timelineMarkerAddDialogTitle(int n) {
    return 'F$n にタイムスタンプを追加';
  }

  @override
  String timelineMarkerEditDialogTitle(int n) {
    return 'タイムスタンプ: F$n';
  }

  @override
  String get timelineMarkerCommentHint => 'コメント（例：ここで口パク「あ」）';

  @override
  String timelineSecondsLabel(int n) {
    return '$n秒';
  }

  @override
  String timelineAddClipDialogTitle(String trackName) {
    return '$trackNameクリップを追加';
  }

  @override
  String get timelineClipLabelFieldLabel => 'ラベル';

  @override
  String get timelineClipStartLabel => '開始:';

  @override
  String get timelineClipLengthLabel => '長さ:';

  @override
  String get timelineSaveSuccessSnackbar => 'プロジェクトを保存しました';

  @override
  String get timelineAutofillNote2 => '※ 自動塗りレイヤーのみ存在する場合は、一から領域を判定して自動塗りします。';

  @override
  String get timelineAutofillTargetLabel => '実行対象';

  @override
  String get timelineAutofillScopeCurrentFrame => '現在のフレームのみ';

  @override
  String get timelineAutofillScopeCurrentScene => 'シーン単位（現在のシーンの全フレーム）';

  @override
  String get timelineAutofillScopeAllScenes => '全フレーム（プロジェクト全体）';

  @override
  String get timelineAutofillProgressTitle => '自動塗り実行中';

  @override
  String timelineAutofillProgressSubtitle(int count) {
    return '$countフレーム';
  }

  @override
  String timelineAutofillCompleteSnackbar(int count) {
    return '自動塗りが完了しました（$count件処理）';
  }

  @override
  String get timelineEffectTypeFade => 'フェード';

  @override
  String get timelineEffectTypeGaussianBlur => 'ガウスぼかし';

  @override
  String get timelineEffectTypeLensBlur => 'レンズぼかし';

  @override
  String get timelineEffectTypeMosaic => 'モザイク';

  @override
  String get timelineEffectTypeChromaticAberration => '色収差';

  @override
  String get timelineEffectTypeNoise => 'ノイズ';

  @override
  String get timelineEffectTypeSepia => 'セピア';

  @override
  String get timelineEffectTypeAnimeStyle => 'アニメ調';

  @override
  String get timelineEffectTypeRetroAnime => 'レトロアニメ';

  @override
  String get timelineEffectTypeCrt => 'ブラウン管';

  @override
  String get timelineEffectTypeAnimatedNoise => '動くノイズ';

  @override
  String get timelineEffectTypeRain => '雨';

  @override
  String get timelineEffectFilterEmptyState => 'フィルターがありません\n＋追加ボタンで追加してください';

  @override
  String get timelineRangeStartLabel => '開始';

  @override
  String get timelineRangeEndLabel => '終了';

  @override
  String get timelineEffectSizeLabel => 'サイズ';

  @override
  String get timelineEffectStrengthLabel => '強度';

  @override
  String get timelineEffectAmountLabel => '量';

  @override
  String get timelineEffectGrainSizeLabel => '粒の大きさ';

  @override
  String get timelineEffectRainIntensityLabel => '降り方';

  @override
  String get timelineEffectRainSpeedLabel => '速さ';

  @override
  String get timelineEffectRainSizeLabel => '粒の大きさ';

  @override
  String get timelineEffectWindAngleLabel => '風向き';

  @override
  String get timelineColorLabel => '色';

  @override
  String get timelineColorBlack => '黒';

  @override
  String get timelineColorWhite => '白';

  @override
  String get timelineColorCustom => 'カスタム';

  @override
  String get timelineFadeColorDialogTitle => 'フェードカラー';

  @override
  String get timelineAddFilterDialogTitle => 'フィルターを追加';

  @override
  String get timelineClipVolumeLabel => '音量';

  @override
  String get timelineClipFadeInLabel => 'フェードイン';

  @override
  String get timelineClipFadeOutLabel => 'フェードアウト';

  @override
  String get timelineClipUseStartLabel => '使用開始F';

  @override
  String get timelineClipUseEndLabel => '使用終了F';

  @override
  String timelineCameraKfTitle(int n) {
    return 'カメラ KF: F$n';
  }

  @override
  String get timelineCameraMoveXLabel => 'X 移動';

  @override
  String get timelineCameraMoveYLabel => 'Y 移動';

  @override
  String get timelineCameraZoomLabel => 'ズーム';

  @override
  String get timelineCameraRotationLabel => '回転';

  @override
  String get layerPanelKeyframeLabel => 'アニメーション（キーフレーム）';

  @override
  String layerKeyframeSheetTitle(String name) {
    return '$name のキーフレーム';
  }

  @override
  String get layerKeyframeSheetDesc =>
      'このレイヤーの位置・拡大縮小・回転をフレームごとに指定し、キーフレーム間を自動で補間します。レイヤーの絵自体は変わりません。';

  @override
  String layerKeyframeAddAtCurrentFrame(int n) {
    return '現在のフレーム（F$n）に追加';
  }

  @override
  String get layerKeyframeEmpty => 'キーフレームがありません。上のボタンから追加してください。';

  @override
  String get layerKeyframeScaleShort => '倍率';

  @override
  String get layerKeyframeRotationShort => '回転';

  @override
  String layerKeyframeEditTitle(int n) {
    return 'キーフレーム: F$n';
  }

  @override
  String get layerKeyframeFrameLabel => 'フレーム';

  @override
  String get layerKeyframeScaleLabel => '拡大縮小';

  @override
  String get layerKeyframeRotationLabel => '回転';

  @override
  String get layerKeyframeEasingLabel => '次のキーフレームへのつなぎ方';

  @override
  String get layerKeyframeEasingLinear => '等速';

  @override
  String get layerKeyframeEasingEaseIn => 'ゆっくり始まる';

  @override
  String get layerKeyframeEasingEaseOut => 'ゆっくり終わる';

  @override
  String get layerKeyframeEasingEaseInOut => 'ゆっくり始まって終わる';

  @override
  String get layerKeyframeEasingBounceOut => '弾む';

  @override
  String get layerPanelGroupTooltip => 'グループ化';

  @override
  String get layerPanelShowSelectedTooltip => '選択中のレイヤーを全て表示';

  @override
  String get layerPanelHideSelectedTooltip => '選択中のレイヤーを全て非表示';

  @override
  String get layerPanelGroupDefaultName => '新規グループ';

  @override
  String layerPanelGroupMembershipLabel(String name) {
    return 'グループ: $name';
  }

  @override
  String get layerPanelGroupLeaveAction => '解除';

  @override
  String frameStripHoldDialogTitle(int n) {
    return 'F$n 保持セル数';
  }

  @override
  String get frameStripTimelineModeTooltip => 'タイムラインモード';

  @override
  String get frameStripFrameListModeLabel => 'フレーム一覧';

  @override
  String get frameStripTimelineModeLabel => 'タイムライン';

  @override
  String get progressDialogAdLoading => '広告読み込み中…';

  @override
  String get progressDialogTipLabel => 'ヒント';

  @override
  String get premiumBannerRegisterButton => 'プレミアムに登録';

  @override
  String get licenseTermsArt1Title => '第1条（適用）';

  @override
  String get licenseTermsArt1Body =>
      'この利用規約（以下「本規約」といいます。）は、本アプリ「NIARIM」（以下「本アプリ」といいます。）の利用条件を定めるものです。ユーザーは、本規約に同意の上、本アプリをご利用いただくものとします。本アプリを利用することにより、本規約に同意したものとみなします。';

  @override
  String get licenseTermsArt2Title => '第2条（利用資格・対応環境）';

  @override
  String get licenseTermsArt2Body =>
      '1. 本アプリの対応OSや推奨動作環境の詳細は、各配布ストアおよび本アプリ内の表示に従います。\n2. 本アプリは、多様な性能の端末でも快適にご利用いただけるよう工夫していますが、端末の性能・OSのバージョン・空き容量・設定その他の利用環境によっては、一部機能が制限される、または正常に動作しない場合があります。';

  @override
  String get licenseTermsArt3Title => '第3条（禁止事項）';

  @override
  String get licenseTermsArt3Body =>
      'ユーザーは本アプリの利用にあたり、以下の行為をしてはなりません。\n・法令または公序良俗に違反する行為\n・本アプリ、開発者または第三者の著作権・商標権その他の知的財産権、肖像権、プライバシーその他の権利または利益を侵害する行為\n・本アプリの逆コンパイル、逆アセンブル、リバースエンジニアリングその他解析を目的とする行為（法令上認められる場合を除く）\n・本アプリの不正な改造、複製または再配布\n・本アプリまたはその提供基盤に対する不正アクセス、過度な負荷その他、正常な提供を妨げる行為\n・その他、開発者が合理的な理由に基づき不適切と判断する行為';

  @override
  String get licenseTermsArt4Title => '第4条（作成コンテンツの権利）';

  @override
  String get licenseTermsArt4Body =>
      '1. ユーザーが本アプリを利用して作成したイラスト・アニメーション等のコンテンツ（プロジェクトデータ・書き出した画像・動画等を含みます。以下「作成コンテンツ」といいます。）に関する著作権その他の権利は、法令上認められる範囲において、当該コンテンツについて権利を有するユーザーまたは第三者に帰属します。\n2. 本アプリは、作成コンテンツを開発者のサーバーへ送信・収集・同期する機能を提供していません。プロジェクトデータは、原則としてユーザーの端末内にのみ保存されます。（ユーザーが自らの意思で作品広場機能を利用して作成コンテンツを投稿する場合の取扱いについては、第12条によります。）\n3. 無料版・プレミアム版のいずれを利用して作成した場合であっても、本アプリの利用料金やエディションを理由として、開発者が作成コンテンツの商用利用を制限することはありません。（無料版・プレミアム版の違いは、エンドカード表示や書き出し時間の上限等の機能面に限られます。）\n4. 前項にかかわらず、ユーザーが本アプリに追加したフォント・画像・素材等、第三者が権利を有するものについては、それぞれの利用条件（第5条）に従う必要があります。';

  @override
  String get licenseTermsArt5Title => '第5条（同梱フォント・追加素材について）';

  @override
  String get licenseTermsArt5Body =>
      '1. 本アプリに同梱されるフォントその他の素材は、本画面「使用フォントについて」に記載された各ライセンス条件に従い利用されています。\n2. ユーザーが本アプリに追加登録・読み込みしたフォント、画像、トーン、スタンプ等の素材の権利関係については、ユーザー自身の責任において、必要な権利または許諾を取得の上、適法にご利用ください。\n3. ユーザーによる第三者素材の利用に起因して第三者との間で紛争等が生じた場合、開発者は、法令上の責任を負う場合を除き、その責任を負いません。';

  @override
  String get licenseTermsArt6Title => '第6条（プレミアム機能・課金）';

  @override
  String get licenseTermsArt6Body =>
      '1. 本アプリには、無料でご利用いただける機能のほか、アプリ内課金（月額プラン、年額プランその他のプレミアムプラン）により利用可能となるプレミアム機能があります。\n2. プレミアム機能の価格、提供内容、購入方法その他の条件は、購入時点における本アプリ内または配布ストアの表示に従います。\n3. 購入後のキャンセル・返金その他決済に関する事項については、Google Playその他ご利用の決済プラットフォームの規定が適用されます。ただし、法令に別段の定めがある場合は、その定めに従います。\n4. 開発者は、法令の改正、技術上の必要性、本アプリの改善その他の合理的な理由により、プレミアム機能の内容を変更することがあります。重要な変更を行う場合は、可能な限り事前に本アプリ内その他適切な方法でお知らせします。';

  @override
  String get licenseTermsArt7Title => '第7条（広告表示）';

  @override
  String get licenseTermsArt7Body =>
      '1. 無料版では、第三者の広告配信サービスを通じた広告が表示される場合があります。\n2. 広告配信事業者による情報の取得・利用その他の取扱いについては、各広告配信事業者のプライバシーポリシーが適用されます。';

  @override
  String get licenseTermsArt8Title => '第8条（情報の取扱い）';

  @override
  String get licenseTermsArt8Body =>
      '1. 本アプリは、ユーザーが作成したイラスト・アニメーション等のコンテンツおよびプロジェクトデータを、開発者のサーバーへ送信・収集する機能を提供していません。これらは原則としてユーザーの端末内にのみ保存されており、開発者はこれらを自ら保存する機能を持たないため、開発者側での保存期間という概念自体がありません。\n2. 本アプリが組み込む第三者サービス（広告配信・アプリ内課金等）による情報の取得その他ユーザーの情報の取扱いについては、別途定める「プライバシーポリシー」の定めに従うものとします。\n3. 本アプリをアンインストールした場合、端末内に保存されたデータ（プロジェクト、設定、追加したフォント等）は削除されます。';

  @override
  String get licenseTermsArt9Title => '第9条（提供の停止・変更・終了）';

  @override
  String get licenseTermsArt9Body =>
      '1. 開発者は、本アプリの保守・更新・修正を行う場合、提供基盤に不具合が生じた場合その他やむを得ない事情がある場合、本アプリの全部または一部の提供を一時的に停止することがあります。\n2. 開発者は、必要に応じて本アプリの内容を変更し、または本アプリの提供を終了することがあります。\n3. 前2項の場合、緊急のときを除き、可能な限り事前に本アプリ内その他適切な方法で告知します。\n4. 本条に基づく変更・停止・終了によってユーザーに生じた損害について、開発者は、法令上の責任を負う場合を除き、責任を負いません。';

  @override
  String get licenseTermsArt10Title => '第10条（免責事項）';

  @override
  String get licenseTermsArt10Body =>
      '1. 開発者は、本アプリについて、事実上または法律上の瑕疵（安全性・信頼性・正確性・完全性・特定目的への適合性・バグや不具合がないこと等を含みます。）がないことを保証するものではありません。\n2. ユーザーは、本アプリを自己の責任においてご利用いただくものとします。端末の故障・誤操作・OSの更新その他の事情によりデータが失われる場合がありますので、作成中のデータについては、書き出し・共有機能等を利用した定期的なバックアップを推奨します。\n3. 本アプリの利用によってユーザーに生じた損害について、開発者は、法令上認められる範囲で責任を負いません。ただし、開発者に故意または重過失がある場合はこの限りではなく、その場合であっても、開発者が負う損害賠償責任は、通常生じうる直接損害に限り、ユーザーが本アプリに関し直近1年間に実際に支払った金額（無料でご利用の場合は0円）を上限とします。';

  @override
  String get licenseTermsArt11Title => '第11条（本規約の変更）';

  @override
  String get licenseTermsArt11Body =>
      '1. 開発者は、法令の改正、本アプリの内容の変更その他必要と判断した場合、本規約を変更することがあります。\n2. 本規約を変更する場合、変更内容および効力発生日を、本アプリ内その他適切な方法により、事前に周知します。\n3. 変更後の本規約は、法令上認められる範囲において、前項の効力発生日から適用されます。';

  @override
  String get licenseTermsArt12Title => '第12条（作品広場：コミュニティ投稿機能）';

  @override
  String get licenseTermsArt12Body =>
      '1. 本アプリは、ユーザーが作成したアニメーション作品を、ユーザー自身のGoogleアカウントを通じてYouTubeへ投稿し、「作品広場」上で公開・閲覧できる機能（以下「本コミュニティ機能」といいます。）を任意で提供します。作品の閲覧・作成自体は、本コミュニティ機能を利用しなくても行えます。\n2. 投稿された動画ファイル本体はYouTube上に保存され、開発者のサーバーには保存されません。一方、投稿作品の識別・表示に必要な情報（YouTube動画ID、タイトル、統計情報、通報情報等）、および投稿・通報・ブロック機能の利用にあたり発行されるNIARIM User ID（Googleアカウントとは別に本アプリ内部で発行する識別子）は、開発者のサーバーで管理します。\n3. 本コミュニティ機能のうち、作品の投稿、通報およびユーザーのブロックには、Googleアカウントによるログインが必要です。\n4. 投稿できる作品数には1日あたりの上限があります。（無料会員・プレミアム会員で上限が異なります。）当該上限は、運営上の都合により変更されることがあります。\n5. ユーザーは、他のユーザーが投稿した作品のうち、法令もしくは公序良俗に違反する、または第3条各号に該当するおそれがあると考えるものについて、本アプリ内の通報機能を通じて開発者に報告できます。開発者は、通報の内容を確認のうえ、合理的な理由に基づき当該作品の一覧からの非表示その他の必要な措置を講じることがあります。虚偽の通報または通報機能の濫用は禁止します。\n6. ユーザーが投稿を削除した場合、または本アプリにおけるGoogleアカウント連携を解除した場合、当該投稿に対応するYouTube動画が削除されることがあります。また、YouTube側で動画が非公開または削除された場合、当該作品は作品広場上でも表示されなくなります。\n7. 本コミュニティ機能の利用にあたっては、本規約に加えてYouTubeの利用規約およびコミュニティガイドラインが適用されます。';

  @override
  String get licenseTermsArt13Title => '第13条（準拠法・裁判管轄）';

  @override
  String get licenseTermsArt13Body =>
      '1. 本規約の解釈にあたっては、日本法を準拠法とします。\n2. 本アプリに関して紛争が生じた場合には、訴額に応じて開発者の所在地を管轄する地方裁判所または簡易裁判所を第一審の専属的合意管轄裁判所とします。';

  @override
  String get privacyPolicyArt1Title => '第1条（本ポリシーの位置づけ）';

  @override
  String get privacyPolicyArt1Body =>
      'このプライバシーポリシー（以下「本ポリシー」といいます。）は、本アプリ「NIARIM」（以下「本アプリ」といいます。）における情報の取扱いについて定めるものです。本アプリの利用条件全般については別途「利用規約・ライセンス」画面をご確認ください。';

  @override
  String get privacyPolicyArt2Title => '第2条（本アプリが取得しないデータ）';

  @override
  String get privacyPolicyArt2Body =>
      '本アプリは、ユーザーが作成したイラスト・アニメーション等のコンテンツ（プロジェクトデータ・書き出し画像・動画等を含みます。以下同じです。）を、開発者のサーバーへ送信・収集・保存する機能を提供していません。これらのデータは、原則としてユーザーの端末内にのみ保存されます。（クラウド同期機能は搭載していません。）開発者はこれらのコンテンツを自ら保存する機能を持たないため、開発者側での保存期間という概念自体がありません。端末内に保存されたデータは、本アプリの削除機能により随時削除できるほか、アプリをアンインストールした場合はプロジェクト・設定・追加したフォント等のデータも併せて削除されます。（ただし、ユーザーが自らの意思で作品広場機能を利用して作品を投稿する場合の情報の取扱いについては、第7条によります。）';

  @override
  String get privacyPolicyArt3Title => '第3条（第三者サービスによる情報の取得）';

  @override
  String get privacyPolicyArt3Body =>
      '本アプリは、以下の第三者サービスを組み込んでおり、それぞれのサービス提供者が、サービス提供に必要な範囲で情報を取得する場合があります。本アプリの開発者は、これらの情報を独自に取得・保存する機能を実装していません。（各サービスが取得した情報の管理は、それぞれのサービス提供者のプライバシーポリシーに従います。）\n\n【広告配信（Google AdMob）】\n無料版では、Google AdMobを通じて広告を配信しています。広告の配信、効果測定、不正防止等の目的で、広告識別子（Advertising ID）その他の端末情報が、Googleまたはその関連事業者によって取得・利用される場合があります。取得・利用の詳細は、Googleのプライバシーポリシー（https://policies.google.com/privacy）をご確認ください。端末の設定（Android設定アプリの「プライバシー」等）から、広告識別子のリセットや、パーソナライズ広告の無効化が可能です。欧州経済領域（EEA）・英国・スイスにお住まいの場合は、起動時等に表示される同意フォームで、広告のパーソナライズに関する同意設定を選択できます。設定はいつでも本画面下部の「広告の同意設定を変更」ボタンから変更できます。\n\n【アプリ内課金（Google Play Billing）】\nプレミアム機能の購入は、Google Playの決済システムを通じて行われます。クレジットカード番号等の決済情報は、開発者側が直接取得・保持することはありません。決済に関する情報の取扱いは、Google Playの規定に従います。\n\n【クラッシュ解析・利用状況分析】\n本アプリは、現時点でクラッシュ解析・利用状況分析を目的としたSDKを組み込んでいません。将来これらのサービスを導入する場合は、本ポリシーを更新し、本アプリ内で告知します。';

  @override
  String get privacyPolicyArt4Title => '第4条（Cookie等のトラッキング技術について）';

  @override
  String get privacyPolicyArt4Body =>
      '本アプリ自体はCookieを使用しませんが、第3条記載の広告配信サービス（Google AdMob）が、広告の配信・効果測定のために、これに類する識別技術（広告識別子等）を使用する場合があります。';

  @override
  String get privacyPolicyArt5Title => '第5条（お子様の個人情報について）';

  @override
  String get privacyPolicyArt5Body =>
      '本アプリは、13歳未満のお子様を主な対象として意図的に情報を収集するものではありません。保護者の方は、お子様が本アプリを利用する際、必要に応じて端末の設定からパーソナライズ広告の無効化等をご検討ください。';

  @override
  String get privacyPolicyArt6Title => '第6条（情報の越境移転について）';

  @override
  String get privacyPolicyArt6Body =>
      '第3条記載の第三者サービス（Google AdMob、Google Play Billing）は、Google社が世界各地で運用するサーバー上で処理される場合があります。これらの取扱いについては、各サービスのプライバシーポリシーが適用されます。';

  @override
  String get privacyPolicyArt7Title => '第7条（作品広場：コミュニティ投稿機能における情報の取扱い）';

  @override
  String get privacyPolicyArt7Body =>
      '1. 本アプリは、ユーザーが自らの意思で「作品広場」機能（利用規約第12条）を利用して作品を投稿する場合に限り、当該投稿に関する以下の情報を開発者のサーバーで管理します。\n・投稿作品を識別・表示するための情報（YouTube動画ID、タイトル、統計情報等）\n・投稿・通報・ブロック機能の利用にあたり発行するNIARIM User ID（Googleアカウントとは別に本アプリ内部で発行する識別子）\n・通報機能を利用した場合の通報内容および通報者のNIARIM User ID\n2. 投稿された動画ファイル本体はYouTube上に保存され、開発者のサーバーには保存されません。\n3. 前2項の情報は、本コミュニティ機能の提供（作品の一覧表示、通報への対応、投稿上限の管理等）の目的の範囲内でのみ利用します。\n4. 本コミュニティ機能を利用しない場合、本条に基づく情報の取扱いは発生しません。（第2条の原則どおり、開発者のサーバーへの送信は行われません。）';

  @override
  String get privacyPolicyArt8Title => '第8条（本ポリシーの変更）';

  @override
  String get privacyPolicyArt8Body =>
      '開発者は、法令の改正、本アプリの内容の変更その他必要と判断した場合、本ポリシーを変更することがあります。本ポリシーを変更する場合、変更内容および効力発生日を、本アプリ内その他適切な方法により、事前に周知します。';

  @override
  String get privacyPolicyArt9Title => '第9条（お問い合わせ）';

  @override
  String get privacyPolicyArt9Body =>
      '本ポリシーに関するお問い合わせは、下記の連絡先までご連絡ください。\n（開発者連絡先：未設定 ― 公開前にメールアドレス等の連絡先情報をご記入ください）';

  @override
  String get privacyPolicyAdConsentButton => '広告の同意設定を変更';

  @override
  String get tipsPcDexLayoutTitle => 'ワイド画面ではPCモード（DeX）の本格レイアウトに';

  @override
  String get tipsPcDexLayoutDesc =>
      'Chromebookやタブレット×キーボード、DeXなど画面の広い環境で使うと、ドッキングパネル方式の本格的なレイアウトへ自動で切り替わります。ワークスペース設定から常にPCモード・常にスマホモードへ手動で固定することもできるので、外部ディスプレイに接続して作業するときなどにも活用できます。';

  @override
  String get workspaceTimelineSection => 'タイムライン表示';

  @override
  String get workspaceTimelineHint =>
      '動画・音源トラックの1行あたりの高さを5段階で調整できます。指2本でのピンチイン・ピンチアウトでも、タイムライン上のフレーム幅を一時的に拡大縮小できます。';

  @override
  String get workspaceTimelineTrackHeightLabel => 'トラックの高さ';

  @override
  String get workspaceTimelinePreviewLabel => 'プレビュー';

  @override
  String get workspaceEndCardSection => 'エンドカード';

  @override
  String get workspaceEndCardHint =>
      'エンドカードは動画の最後に自動で表示されるアプリ側のロゴです。無料会員は操作できません。プレミアム会員限定で、ここをONにすると次にタイムラインを開いた時点から最初からエンドカードが非表示（削除済み）の状態になります。プレミアム権限が切れると、この設定は自動的にOFFへ戻ります。';

  @override
  String get workspaceEndCardDefaultHiddenTitle => 'エンドカードを最初から非表示にする（プレミアム限定）';

  @override
  String get tipsTransparentColorTitle => '透明色はただの消しゴムじゃない、ペンと同じ感覚で使える';

  @override
  String get tipsTransparentColorDesc =>
      '透明色を選ぶと、ブラシ・投げ縄・図形など好きなツールでそのまま「消す」ことができます。ブラシの筆圧や滑らかさをそのまま活かして輪郭だけ丸く削ったり、グラデーションブラシで境界をふわっと透明にぼかしたりと、消しゴムツールにはない繊細な表現が可能です。';

  @override
  String get tipsQuickToolVariantTitle => '早替えツールはツール違いだけでなくブラシ・サイズ違いも登録できる';

  @override
  String get tipsQuickToolVariantDesc =>
      '早替えツールには、ペン・消しゴムのようなツールの切り替えだけでなく、同じペンでもブラシの種類が違うものや、同じ消しゴムでもサイズ違いのものを別々に登録できます。よく使う組み合わせだけを厳選して並べておけば、細かい設定変更のたびにパネルを開き直す手間が減ります。';

  @override
  String get tipsCommonLayerLipSyncTitle => '共通レイヤーは背景だけでなく人物の容量削減にも使える';

  @override
  String get tipsCommonLayerLipSyncDesc =>
      '背景だけでなく、人物レイヤーそのものを共通レイヤー化するのも有効です。口や瞬きする瞳など、フレームごとに変化する部分だけを通常レイヤーとして重ね、体や髪など動かない部分は共通レイヤーにしておけば、口パクや瞬きのアニメーションでも容量を大きく削減できます。';

  @override
  String get tipsCommonLayerKeyframeTitle => '共通レイヤー×レイヤーキーフレームでも容量削減できる';

  @override
  String get tipsCommonLayerKeyframeDesc =>
      '共通レイヤーはレイヤーキーフレームで位置・拡大・回転を動かせます。フレームごとに描き直す代わりに、1枚の絵を共通レイヤー化してキーフレームで動かすだけで、容量を増やさずに簡単な動きを付けられます。';

  @override
  String get tipsTransferCustomizationTitle => '引き継ぎ機能で端末を変えてもいつもの使い心地のまま';

  @override
  String get tipsTransferCustomizationDesc =>
      '引き継ぎ（.niatra）機能では、ブラシ・テーマ・ツールバーの並び・パレットなどカスタマイズした設定をまとめて別端末へ移せます。機種変更や複数端末の使い分けをしても、毎回イチから設定し直す必要がありません。';

  @override
  String get tipsBlendModeUsageTitle => 'ブレンドモードは目的別に使い分けると効果的';

  @override
  String get tipsBlendModeUsageDesc =>
      '影をつけたい時は「乗算」、光や輝きを足したい時は「スクリーン」や「加算」、陰影に質感を出したい時は「オーバーレイ」や「ソフトライト」が向いています。同じ色でもブレンドモードを変えるだけで印象が大きく変わるので、まずは候補をいくつか切り替えて見比べてみるのがおすすめです。';

  @override
  String get timelineSaveFailedDialogTitle => '保存に失敗しました';

  @override
  String get timelineSaveFailedDialogBody => '保存に失敗しました。もう一度お試しください。';

  @override
  String get licenseSectionIcons => '使用アイコンについて';

  @override
  String get layerPanelMergeAllVisibleTooltip => '表示中の全レイヤーを結合';

  @override
  String get canvasBrushSliderToggleLabel => '詳細';

  @override
  String get helpMeshTransformTitle => '自由変形・メッシュ変形';

  @override
  String get helpMeshTransformDesc =>
      'キャンバス右上の編集・設定メニューから開ける、レイヤー全体を対象にした変形ツールです。範囲選択の変形と異なり選択範囲は不要で、角や格子点を指で個別にドラッグして自由な形に変形できます。コントロールパネルの分割数スライダーでメッシュを最大10×10まで細かくでき、2本の指で別々の点を同時につまめば回転・拡大縮小のような操作も直感的に行えます。';

  @override
  String get layerPanelBrightnessToAlphaLabel => '明度で透過';

  @override
  String get layerPanelBrightnessToAlphaHint =>
      '白い部分ほど透明にします。色はそのまま半透明になります（白背景が消えるのではなく、絵全体が薄くなるイメージ）。';

  @override
  String get layerPanelBrightnessToAlphaColorButton => 'カラー';

  @override
  String get layerPanelBrightnessToAlphaGrayButton => 'グレー';

  @override
  String get tipsRoughLayerRescueTitle => '下描きに線画を描いてしまった時は「明度で透過」で救出';

  @override
  String get tipsRoughLayerRescueDesc =>
      '下描きレイヤーに誤って線画を重ねて描いてしまっても、レイヤーを消さずに線画だけを取り出せます。①新しいレイヤーを追加し、ブレンドモードを「除算」にする。②スポイトで下描きの色を拾い、その除算レイヤー全体を塗りつぶす（下描きが薄くなります）。③除算レイヤーを複製すると、下描きが完全に消えます。④レイヤーパネルの「表示中の全レイヤーを結合」で1枚にまとめる。⑤結合したレイヤーの三点メニューから「明度で透過（グレー）」を選べば、白い部分が透明になり線画だけが残ります。';

  @override
  String get filterNameMonochrome => '単色化フィルター';

  @override
  String get timelineEffectTypeMonochrome => '単色化フィルター';

  @override
  String get filterNameColorAdjust => '色調調整';

  @override
  String get filterColorAdjustSaturationLabel => '彩度';

  @override
  String get filterColorAdjustBrightnessLabel => '明度';

  @override
  String get filterColorAdjustContrastLabel => 'コントラスト';

  @override
  String get canvasColorAdjustTitle => '色調調整';

  @override
  String get canvasColorAdjustAddToDrawFilter => '描画フィルターに追加する';

  @override
  String get canvasColorAdjustAddToEffectFilter => '演出フィルターに追加する';

  @override
  String get canvasColorAdjustMenuTitle => '色調調整';

  @override
  String get canvasEditMenuReferenceWindow => '資料ウィンドウ';

  @override
  String get canvasEditMenuReferenceWindowSubtitle => '三面図・資料画像をフローティング表示';

  @override
  String get referenceWindowTitle => '資料ウィンドウ';

  @override
  String get referenceWindowSelectImageButton => '画像を選択';

  @override
  String get workspaceDockPanelSection => 'PC版で既定で開くパネル';

  @override
  String get workspaceDockPanelHint =>
      'PC/DeXモードでは、チェックした複数のパネルを同時にドッキング表示できます（スマホ版は誤操作防止のため対象外）。';

  @override
  String get workspaceDockPanelBrush => 'ブラシ';

  @override
  String get workspaceDockPanelColorPicker => 'カラーピッカー';

  @override
  String get workspaceDockPanelLayer => 'レイヤー';

  @override
  String get workspaceDockPanelTone => 'トーン';

  @override
  String get workspaceDockPanelStamp => 'スタンプ';

  @override
  String get workspaceDockPanelPenSubTool => 'ペンサブツール';

  @override
  String get workspaceDockPanelOnionSkin => 'オニオンスキン';

  @override
  String get workspaceDockPanelRuler => '定規';

  @override
  String get workspaceDockPanelFilter => 'フィルター';

  @override
  String get workspaceDockPanelQuickTool => '早替えツール';

  @override
  String get workspaceDockPanelColorAdjust => '色調調整';

  @override
  String get workspaceDockPanelCanvasPreview => 'キャンバスプレビュー';

  @override
  String get workspacePcLayoutButton => 'PCレイアウト設定';

  @override
  String get pcWorkspaceLayoutScreenTitle => 'PCレイアウト設定';

  @override
  String get pcWorkspaceLayoutIntroHint =>
      'PCモード（横画面＋マウス・ペンタブ接続）でキャンバス画面を開いた際の、パネルの並び順・幅を調整できます。';

  @override
  String get pcWorkspaceLayoutToolOrderSection => 'ツールパネルの並び順';

  @override
  String get pcWorkspaceLayoutToolOrderHint =>
      'ブラシ・トーン・スタンプ等、複数同時に開いた際に積み重なる順番です。';

  @override
  String get pcWorkspaceLayoutRightOrderSection => 'レイヤー等パネルの並び順';

  @override
  String get pcWorkspaceLayoutRightOrderHint =>
      'カラーピッカー・レイヤー・キャンバスプレビューの積み重ね順です。';

  @override
  String get pcWorkspaceLayoutWidthSection => 'パネルの幅';

  @override
  String get pcWorkspaceLayoutToolWidthLabel => 'ツールパネル側の幅';

  @override
  String get pcWorkspaceLayoutRightWidthLabel => 'レイヤー等パネル側の幅';

  @override
  String get pcWorkspaceLayoutResetWidthButton => '幅をデフォルトに戻す';

  @override
  String get pcWorkspaceLayoutResetOrderButton => '並び順をデフォルトに戻す';

  @override
  String get canvasPreviewNavigatorTitle => 'キャンバスプレビュー';

  @override
  String get canvasEditMenuPreviewNavigator => 'キャンバスプレビュー';

  @override
  String get canvasEditMenuPreviewNavigatorSubtitle => '全体を縮小表示（ナビゲーター）';

  @override
  String get filterCustomMenuDuplicate => '複製';

  @override
  String get filterCustomMenuFavoriteBlockTitle => '削除できません';

  @override
  String get filterCustomMenuFavoriteBlockBody =>
      'お気に入り登録中のフィルターは削除できません。削除するにはお気に入り登録を解除してください。';

  @override
  String get filterNameThreshold => '二値化フィルター';

  @override
  String get filterMonochromeStrength => '単色化の強さ';

  @override
  String get filterMonochromeColorLabel => '単色化の色';

  @override
  String get filterThresholdLabel => '閾値';

  @override
  String get filterNameFisheye => '魚眼レンズフィルター';

  @override
  String get filterFisheyeStrength => '湾曲の強さ';

  @override
  String get filterNameChromaticAberration => '色収差フィルター';

  @override
  String get filterChromaticAberrationStrength => 'ずれの強さ';

  @override
  String get filterNameLensDistortion => '眼鏡断層フィルター';

  @override
  String get filterLensDistortionStrength => 'レンズの度数（負で凹レンズ、正で凸レンズ）';

  @override
  String get filterLensDistortionOffsetX => '中心位置の微調整（左右）';

  @override
  String get filterNamePixelate => 'ドット絵フィルター';

  @override
  String get filterNameAuroraHologram => 'オーロラホログラム';

  @override
  String get filterAuroraHologramStrength => 'フィルター強度';

  @override
  String get filterAuroraHologramBrightness => '明度';

  @override
  String get filterAuroraHologramSaturation => '彩度';

  @override
  String get filterAuroraHologramPresetAurora => 'オーロラ';

  @override
  String get filterAuroraHologramPresetSoapBubble => 'シャボン玉';

  @override
  String get filterAuroraHologramPresetCyberNeon => 'サイバーネオン';

  @override
  String get filterAuroraHologramPresetPastelDream => 'パステルドリーム';

  @override
  String get filterAuroraHologramPresetSunsetGold => 'サンセットゴールド';

  @override
  String get filterAuroraHologramPresetSilverFoil => 'シルバーホイル';

  @override
  String get filterNameBackgroundBlend => '背景馴染ませ';

  @override
  String get filterBackgroundBlendColorLabel => '馴染ませ色';

  @override
  String get filterBackgroundBlendAutoLabel => '自動検出中（タップで手動指定）';

  @override
  String get filterBackgroundBlendAutoReset => '自動に戻す';

  @override
  String get filterBackgroundBlendDirection => '影と光（連動）の向き';

  @override
  String get filterBackgroundBlendLength => '影と光（連動）の長さ';

  @override
  String get filterBackgroundBlendBlur => 'ぼかし具合';

  @override
  String get filterPixelateBlockSize => 'ブロックサイズ';

  @override
  String get filterLensDistortionOffsetY => '中心位置の微調整（上下）';

  @override
  String get filterLensDistortionNoMaskHint =>
      '選択レイヤーで塗った範囲にのみ適用されます。先にレイヤー一覧で「選択レイヤー」を追加し、レンズにしたい範囲（眼鏡のレンズ部分等）を塗ってください。';

  @override
  String get tipsStockingDenierTitle => 'ストッキング・タイツはデニール数でトーンの目の細かさが変わる';

  @override
  String get tipsStockingDenierDesc =>
      'トーン一覧に追加されたストッキング・タイツは、デニール数が低いものほど生地が薄いという設定に合わせて格子模様の間隔を詰めてあり、10デニールなど最も薄いものはあえて細かすぎるくらいの密度にしています（表示・書き出し解像度によってはモアレが出ることがあります）。デニール数が高いタイツほど間隔が広く不透明感のある見た目になるので、キャラクターの脚に合わせて使い分けてください。';

  @override
  String get tipsFisheyeChromaticTitle => '魚眼レンズ・色収差フィルターでレンズらしい歪み・にじみを演出';

  @override
  String get tipsFisheyeChromaticDesc =>
      '魚眼レンズフィルターは画面中心を膨らませ、周辺を圧縮することで広角・魚眼レンズで撮ったような湾曲を再現します。色収差フィルターはRGBチャンネルを少しずつずらすことで、安いレンズで撮影したときのような色のにじみを再現します。どちらも描画フィルター（レイヤーへ直接適用）・演出フィルター（タイムライン上で範囲指定して適用）の両方から使えます。';

  @override
  String get tipsLensDistortionTitle => '選択レイヤー＋眼鏡断層フィルターで、度入りレンズの歪みを再現';

  @override
  String get tipsLensDistortionDesc =>
      'レイヤー一覧に「選択レイヤー」を追加し、眼鏡のレンズ部分を通常の描画ツールで塗ると、その範囲だけに眼鏡断層フィルターの局所的な歪みをかけられます。度数スライダーは負の値で凹レンズ（近視）風に縮小、正の値で凸レンズ（遠視）風に拡大し、中心位置も微調整できます。両目分のレンズを同時に塗って一括で適用することも可能です。選択レイヤー自体は書き出し・最終的な絵には写り込みません。眼鏡以外にも、カメラのレンズ越しに景色を見ているような歪みを再現したいときにも使えます。背景など広い範囲を選択レイヤーで塗り、弱めの度数をかけるのがおすすめです。';

  @override
  String get tipsLineArtExtractionTitle => '色調補正・二値化・明度で透過を組み合わせて線画を抽出する';

  @override
  String get tipsLineArtExtractionDesc =>
      '色調補正でコントラストを強めて線を際立たせたあと、二値化フィルターで画像を白黒2色に分けると、線とそれ以外がはっきり分離します。二値化の閾値はスライダーで自由に調整でき、線の太さ・かすれ具合を好みに合わせられます。仕上げにレイヤーの三点メニューにある「明度で透過（グレー）」を使うと、白い部分（線以外）だけが透過し、線画だけを抽出できます。写真や下描きから線画だけを取り出したいときに便利です。';

  @override
  String get tipsLineColorUsageTitle => '線画色は用途で使い分けると仕上がりが変わる';

  @override
  String get tipsLineColorUsageDesc =>
      'パーツの輪郭線は色トレス・線画馴染ませを使うと、周りから浮かずに境界だけがはっきり伝わる線画になります。影やハイライトには塗り色と同じ指定色を使うと線画そのものが目立たなくなり、あえて別の指定色にすればそのアニメ特有の世界観・統一感を演出できます。';

  @override
  String get tipsBlushAutofillTitle => '頬の赤みも自動塗りでふんわり乗せられる';

  @override
  String get tipsBlushAutofillDesc =>
      '線画色を指定色にして透明色を選び、塗り色を放射：中央→外側にして頬の赤みと透明色の2色を指定すると、肌の上に頬の赤みだけをふわっと重ねられます。赤みの不透明度と色の切り替え位置を調整すると、境界がより馴染みやすくなります。';

  @override
  String get autofillPartResetTraceButton => 'デフォルトに戻す';

  @override
  String get premiumScreenTitle => 'プレミアム';

  @override
  String get premiumComparisonPremium => 'プレミアム';

  @override
  String premiumRegisteredDateLabel(String date) {
    return '登録日: $date';
  }

  @override
  String premiumNextRenewalDateLabel(String date) {
    return '次回更新日: $date';
  }

  @override
  String get workspaceApplyCurrentButton => '設定したワークスペースを適用';

  @override
  String get workspaceAppliedSnackbar => 'ワークスペース設定を反映しました';

  @override
  String get workspaceSaveAsButton => 'ワークスペースに名前を付けて保存・上書き保存';

  @override
  String get workspaceShareButton => 'ワークスペースを共有';

  @override
  String get workspaceShareSelectTitle => '共有するワークスペースを選択';

  @override
  String workspaceShareFailedSnackbar(String error) {
    return '共有に失敗しました: $error';
  }

  @override
  String get workspaceImportFromFileButton => '外部ファイルを読み込み';

  @override
  String workspaceImportFailedSnackbar(String error) {
    return '読み込みに失敗しました: $error';
  }

  @override
  String get workspaceNameRequiredError => '名前を保存してください';

  @override
  String get workspaceNoSavedPresets => '保存済みのワークスペースがありません';

  @override
  String get workspaceOverwriteSelectTitle => '上書きするワークスペースを選択';

  @override
  String get workspaceOverwriteConfirmTitle => '上書きの確認';

  @override
  String workspaceOverwriteConfirmBody(String name) {
    return '「$name」を現在の設定で上書きします。元の内容は削除されます。よろしいですか？';
  }

  @override
  String get workspaceOverwriteButton => '上書き保存';

  @override
  String get splashCommunityButtonTitle => '作品広場';

  @override
  String get splashCommunityButtonSubtitle => 'みんなの作品をみる';

  @override
  String get splashCreateButton => '作品をつくる';

  @override
  String get communityScreenTitle => '作品広場';

  @override
  String get communityTabNew => '新着';

  @override
  String get communityTabRanking => 'ランキング';

  @override
  String get communityTabFavoriteAuthors => 'フォロー中';

  @override
  String get communitySearchHint => '作品タイトル・投稿者名で検索';

  @override
  String get communityEmptyState => '作品がありません';

  @override
  String communitySearchNoResults(String query) {
    return '「$query」に一致する作品が見つかりませんでした';
  }

  @override
  String get communityTagSearchHint => 'タグ名で検索';

  @override
  String get communityTagSearchModeOnTooltip => 'タグ検索：ON（タップでタイトル・投稿者名検索に戻す）';

  @override
  String get communityTagSearchModeOffTooltip => 'タグ検索に切り替える';

  @override
  String get communityAddTagButton => 'タグを追加';

  @override
  String get communityAddTagDialogTitle => 'タグを追加';

  @override
  String get communityAddTagDialogHint => 'タグ名を入力';

  @override
  String get communityTagLockTooltip => 'タグをロック（投稿者のみ）';

  @override
  String get communityTagUnlockTooltip => 'タグのロックを解除（投稿者のみ）';

  @override
  String get communityRemoveTagTooltip => 'タグを削除';

  @override
  String get communityPostButton => '投稿する';

  @override
  String get communityPostComingSoonTitle => '投稿機能は準備中です';

  @override
  String get communityPostComingSoonBody => '動画投稿機能は現在準備中です。今後のアップデートをお楽しみに。';

  @override
  String get communityPostInfoTitle => '投稿はYouTube経由になります';

  @override
  String get communityPostInfoBody =>
      '作品広場に投稿すると、YouTubeを通じて作品が公開されます。NIARIMは作品本体（動画ファイル）を開発者のサーバーへ送信・収集・保存する機能を持っていません。投稿の際は、YouTube側の画面で動画をアップロードしていただく形になります。\n\nYouTube側の公開設定を「限定公開」にすると、YouTube上の一般公開一覧には表示されず、作品広場内だけに投稿された状態にすることができます。\n\n（動画投稿機能は現在準備中です。今後のアップデートをお楽しみに。）';

  @override
  String get communityRankingPeriodAllTime => '累計';

  @override
  String get communityRankingPeriodYearly => '年間';

  @override
  String get communityRankingPeriodMonthly => '月間';

  @override
  String get communityRankingPeriodWeekly => '週間';

  @override
  String get communityRankingPeriodDaily => 'デイリー';

  @override
  String get communityRankingSortViews => '再生数';

  @override
  String get communityRankingSortBookmarks => 'ブックマーク数';

  @override
  String get communityRankingSortAscendingTooltip => '昇順（少ない順）';

  @override
  String get communityRankingSortDescendingTooltip => '降順（多い順）';

  @override
  String communityWorkDetailPostedLabel(String date) {
    return '$dateに投稿';
  }

  @override
  String get communityWorkDetailViewOnYoutube => 'YouTubeで見る';

  @override
  String get communityWorkDetailViewOnYoutubeComingSoonSnackbar =>
      'YouTube連携機能は準備中です';

  @override
  String get communityWorkDetailBookmarkAdd => 'ブックマーク';

  @override
  String get communityWorkDetailBookmarkRemove => 'ブックマーク済み';

  @override
  String get communityWorkDetailReportButton => '通報';

  @override
  String get communityWorkDetailBlockButton => 'ブロック';

  @override
  String get communityVisibilityCardTitle => '作品広場での公開状態';

  @override
  String get communityVisibilityPublishedDesc =>
      '公開中：新着・ランキング・投稿者別作品一覧に表示されています。';

  @override
  String get communityVisibilityHiddenDesc =>
      '非公開中：新着・ランキング・投稿者別作品一覧から非表示です（YouTube側の公開設定とは独立した設定です）。';

  @override
  String get communityVisibilityHiddenNotice =>
      'この作品は投稿者により作品広場では非公開に設定されています。';

  @override
  String get communityVisibilityHiddenBadge => '非公開';

  @override
  String get communityWorkDetailTitle => '作品詳細';

  @override
  String get communityWorkNotFoundMessage => '作品が見つかりませんでした';

  @override
  String get communityFloatingPreviewDetailButton => '詳細へ';

  @override
  String get communityFloatingPreviewPlayTooltip => '再生';

  @override
  String get communityFloatingPreviewPauseTooltip => '一時停止';

  @override
  String get communityReportDialogTitle => '作品を通報';

  @override
  String get communityReportDialogBody => '通報理由を選択してください。';

  @override
  String get communityReportReasonInappropriate => '不適切な内容';

  @override
  String get communityReportReasonCopyright => '著作権侵害の疑い';

  @override
  String get communityReportReasonSpam => 'スパム・繰り返し投稿';

  @override
  String get communityReportReasonOther => 'その他';

  @override
  String get communityReportSubmitButton => '通報する';

  @override
  String get communityReportDetailLabel => '詳細';

  @override
  String get communityReportDetailHint => 'どのような点が問題か具体的に入力してください';

  @override
  String get communityReportDetailRequiredError => '詳細を入力してください';

  @override
  String get communityReportComingSoonSnackbar => '通報機能は準備中です。実際には送信されません。';

  @override
  String communityBlockConfirmTitle(String name) {
    return '「$name」をブロックしますか？';
  }

  @override
  String get communityBlockConfirmBody => 'ブロックすると、この作者の作品が一覧に表示されなくなります。';

  @override
  String get communityBlockComingSoonSnackbar => 'ブロック機能は準備中です。実際には反映されません。';

  @override
  String communityAuthorWorksCount(int count) {
    return '$count作品';
  }

  @override
  String communityAuthorFollowerCount(int count) {
    return 'フォロワー$count人';
  }

  @override
  String get communityFollowersPublicToggleTitle => 'フォロー中/フォロワー一覧を公開する';

  @override
  String get communityFollowersPublicToggleDesc =>
      'オンにすると、他のユーザーがこのページからあなたのフォロー中/フォロワー一覧を見られるようになります。既定は非公開です。';

  @override
  String get communityFollowersListTitle => 'フォロワー';

  @override
  String get communityFollowersListEmpty => 'フォロワーがいません';

  @override
  String communityFollowersListHiddenNote(int count) {
    return '他に$count人いますが、本人の設定により非表示です';
  }

  @override
  String communityAuthorFollowingCount(int count) {
    return 'フォロー中$count人';
  }

  @override
  String get communityFollowingListTitle => 'フォロー中';

  @override
  String get communityFollowingListEmpty => '誰もフォローしていません';

  @override
  String get communityFollowNotificationsTooltip => '通知';

  @override
  String get communityFollowNotificationsTitle => 'フォロー通知';

  @override
  String get communityFollowNotificationsEmpty => '通知はありません';

  @override
  String communityFollowNotificationBody(String name) {
    return '$nameさんにフォローされました';
  }

  @override
  String get communityNoWorksMessage => '作品がありません';

  @override
  String get communityFavoriteAuthorFollow => 'フォロー';

  @override
  String get communityFavoriteAuthorFollowing => 'フォロー中';

  @override
  String get communityFavoriteAuthorsEmptyTitle => 'お気に入り作者がいません';

  @override
  String get communityFavoriteAuthorsEmptyBody =>
      '気に入った投稿者のページで「フォロー」すると、ここにその人の新着作品が並びます。';

  @override
  String get communityRepostButton => 'リポスト';

  @override
  String get communityRepostedButton => 'リポスト済み';

  @override
  String communityRepostedByBadge(String name) {
    return '$nameさんがリポスト';
  }

  @override
  String get communityAuthorTabWorks => '作品';

  @override
  String get communityAuthorTabBookmarks => 'ブックマーク';

  @override
  String get communityBookmarksPublicToggleTitle => 'ブックマーク一覧を公開する';

  @override
  String get communityBookmarksPublicToggleDesc =>
      'オンにすると、他のユーザーがこのページからあなたのブックマーク一覧を見られるようになります。既定は非公開です。';

  @override
  String get communityBookmarksPrivateNotice => 'このユーザーはブックマーク一覧を非公開にしています。';

  @override
  String get communityBookmarksEmptyMessage => 'ブックマークした作品がありません';

  @override
  String get communityShortsBadge => '縦画面';

  @override
  String get communityVideoTypeFilterTooltip => '動画の種類を絞り込む';

  @override
  String get communityVideoTypeFilterAll => '総合';

  @override
  String get communityVideoTypeFilterShortOnly => '縦画面のみ';

  @override
  String get communityVideoTypeFilterLongOnly => '横画面のみ';

  @override
  String get communityShortsModeTooltip => '縦画面モードで見る';

  @override
  String get communityShortsModeEmptySnackbar => '縦画面の動画がありません';

  @override
  String get communityShortsModeExitTooltip => '縦画面モードを終了';

  @override
  String get pixelColorModeLabel => '配色方式';

  @override
  String get pixelColorModeNone => '色を指定しない';

  @override
  String get pixelColorModePalette => 'パレットから選ぶ';

  @override
  String get pixelColorModeExplicit => '色を指定する';

  @override
  String get pixelColorModeCount => '色数を指定する';

  @override
  String pixelColorLevelsLabel(int count) {
    return '色数: $count';
  }

  @override
  String get pixelColorChipDeleteTooltip => 'この色を削除';

  @override
  String get pixelColorChipAddButton => '色を追加';

  @override
  String get pixelArtPaletteNameRequiredError => 'パレット名を入力してください';

  @override
  String get pixelArtPaletteEditTitle => 'パレットを編集';

  @override
  String get pixelArtPaletteAddTitle => 'パレットを追加';

  @override
  String get pixelArtPaletteNameLabel => 'パレット名';

  @override
  String get pixelArtPalettePickerTitle => 'パレットから選ぶ';

  @override
  String get pixelArtPalettePickerEmpty => '保存済みのパレットがありません。「追加」から作成してください';

  @override
  String get pixelArtPalettePickerApplyButton => '適用';

  @override
  String get storageScreenTitle => '容量削減';

  @override
  String get storageDeviceChartTitle => '端末の容量';

  @override
  String get storageBreakdownChartTitle => 'NIARIMの内訳';

  @override
  String get storageActionsTitle => '整理する';

  @override
  String get storageCategoryNiarimTotal => 'NIARIM';

  @override
  String get storageCategoryOtherApps => 'その他';

  @override
  String get storageCategoryFree => '空き容量';

  @override
  String get storageCategoryMaterials => '素材';

  @override
  String get storageCategoryProjectData => 'プロジェクトデータ';

  @override
  String get storageCategoryExports => '書き出し済みファイル';

  @override
  String get storageCategoryCustomAssets => '自作ブラシ・トーン・スタンプ・フォント';

  @override
  String get storageCategoryCache => 'キャッシュ';

  @override
  String get storageCategoryTrash => 'ゴミ箱';

  @override
  String get storageClearCacheButton => 'キャッシュを削除';

  @override
  String get storageRemoveUnusedMaterialsButton => '未使用素材を一括削除（全プロジェクト）';

  @override
  String get storageEmptyTrashButton => 'ゴミ箱を空にする';

  @override
  String get storageOrganizeProjectsButton => 'プロジェクトを整理する';

  @override
  String get storageEraseAllButton => '全データを削除（初期化）';

  @override
  String storageClearCacheDoneSnackbar(String size) {
    return '$sizeのキャッシュを削除しました';
  }

  @override
  String get storageEraseAllConfirmTitle => '全データを削除しますか？';

  @override
  String get storageEraseAllConfirmBody =>
      'プロジェクト・素材・書き出し済みファイル・自作ブラシ/トーン/スタンプ/フォント・設定など、NIARIMの全データを完全に削除します。この操作は元に戻せません。削除後はアプリを再起動してください。';

  @override
  String get storageEraseAllDoneSnackbar => '全データを削除しました。アプリを再起動してください';

  @override
  String get homeDrawerStorage => '容量削減';

  @override
  String get helpStorageTitle => '容量削減';

  @override
  String get helpStorageDesc =>
      '端末容量に対するNIARIMの使用量と、NIARIM内部（プロジェクト・素材・書き出し済みファイル・自作ブラシ/トーン/スタンプ/フォント・キャッシュ・ゴミ箱）の内訳を円グラフで確認できます。キャッシュの削除・未使用素材の一括削除（全プロジェクト）・ゴミ箱を空にする・プロジェクトの整理・全データ削除（初期化）が行えます。';

  @override
  String get colorPickerImportPaletteTooltip => 'パレットを取り込む';

  @override
  String get colorPickerSharePaletteTooltip => '共有する';

  @override
  String get colorPickerShareViaFile => 'ファイルで共有';

  @override
  String colorPickerShareFailedSnackbar(String error) {
    return '共有に失敗しました: $error';
  }

  @override
  String get colorPickerShareViaQr => 'QRコードで共有';

  @override
  String get qrShareTooLargeHint => '色数が多いためQRコードでは共有できません（ファイル共有をご利用ください）';

  @override
  String get colorPickerImportViaFile => 'ファイルから選択';

  @override
  String colorPickerImportFailedSnackbar(String error) {
    return '読み込みに失敗しました: $error';
  }

  @override
  String get colorPickerImportViaQr => 'QRコードのテキストを貼り付け';

  @override
  String get qrImportFailedError => '読み込みに失敗しました。テキストが正しいか確認してください';

  @override
  String get qrImportHint =>
      '相手の端末で表示されたQRコードを標準カメラアプリ等で読み取り、コピーした文字列をここに貼り付けてください';

  @override
  String get qrImportFieldHint => '読み取った文字列を貼り付け';

  @override
  String get qrImportPasteButton => 'クリップボードから貼り付け';

  @override
  String get qrImportSubmitButton => '読み込む';

  @override
  String get qrShareHint =>
      '標準カメラアプリ等でこのQRコードを読み取ると、テキストをコピーできます。相手の端末で「取り込む」からQRコードのテキストを貼り付けてください。';

  @override
  String get qrShareCopiedSnackbar => 'テキストをコピーしました';

  @override
  String get qrShareCopyButton => 'テキストをコピー';

  @override
  String get toolbarItemBlur => 'ガウスぼかし';

  @override
  String get toolbarItemMosaic => 'モザイク';

  @override
  String get toolbarFingerSubtoolWarp => '歪み';

  @override
  String get brushSettingsEdgeJitterTitle => 'ふち滲み';

  @override
  String get brushSettingsEdgeJitterSubtitle => 'ふちをわずかにがたがたさせてインクの滲みを再現する';

  @override
  String get brushSettingsEdgeJitterStrengthLabel => '滲み強度';
}
