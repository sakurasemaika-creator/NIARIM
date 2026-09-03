// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get homeTabProjects => '项目';

  @override
  String get homeTabShared => '共享';

  @override
  String get homeTabTrash => '回收站';

  @override
  String get homeTabWorks => '作品列表';

  @override
  String get homeTabBookmarked => '已收藏';

  @override
  String get homeBookmarkedComingSoonTitle => '敬请期待';

  @override
  String get homeBookmarkedComingSoonBody =>
      '「查看大家的动画」功能上线后，你收藏的其他用户公开作品会显示在这里。';

  @override
  String get homeSearchHint => '按项目名称搜索';

  @override
  String get homeBackToSplashTooltip => '返回启动画面';

  @override
  String get homeFavoritesOnly => '收藏';

  @override
  String get homeAddSheetNewProject => '新建项目';

  @override
  String get homeAddSheetNewFolder => '新建文件夹';

  @override
  String get homeSelectionAllSelect => '全选';

  @override
  String get homeSelectionAllDeselect => '取消全选';

  @override
  String get homeSelectionAddFavorite => '加入收藏';

  @override
  String get homeSelectionRemoveFavorite => '取消收藏';

  @override
  String homeSelectionCount(int count) {
    return '已选择$count项';
  }

  @override
  String get homeMoveToTrash => '移至回收站';

  @override
  String homeMoveToTrashConfirm(int count) {
    return '要将$count项移至回收站吗？';
  }

  @override
  String get commonMove => '移动';

  @override
  String get homeShareFileDialogTitle => '共享文件';

  @override
  String get homeShareFileDialogContent => '要复制此共享文件并另存为普通项目吗？';

  @override
  String homeMissingFontsSnackbar(String names) {
    return '缺少字体：$names';
  }

  @override
  String get homeSharedImportedSnackbar => '已添加到项目标签页';

  @override
  String homeSharedImportFailedSnackbar(String error) {
    return '读取共享文件失败：$error';
  }

  @override
  String get homeViewModeLarge => '大';

  @override
  String get homeViewModeMedium => '中';

  @override
  String get homeViewModeSmall => '小';

  @override
  String get homeViewModeDetail => '详情';

  @override
  String get homeSortFieldName => '名称';

  @override
  String get homeSortFieldUpdated => '更新时间';

  @override
  String get homeSortDirectionAscTooltip => '升序（点击切换为降序）';

  @override
  String get homeSortDirectionDescTooltip => '降序（点击切换为升序）';

  @override
  String get homeSharedEmpty => '没有共享项目';

  @override
  String homeProjectMeta(int fps, int duration) {
    return '${fps}fps · $duration秒';
  }

  @override
  String get homeTrashEmpty => '回收站是空的';

  @override
  String homeTrashDeletedOn(String date) {
    return '$date 删除';
  }

  @override
  String get homePermanentDelete => '彻底删除';

  @override
  String get homePermanentDeleteConfirmTitle => '确定要彻底删除吗？';

  @override
  String get homePermanentDeleteConfirmBody => '此操作无法撤销。';

  @override
  String get homeWorksEmpty => '还没有导出的作品';

  @override
  String get homeWorksEmptyHint => '从画布导出视频或GIF后，\n将显示在这里';

  @override
  String get homeShareOpenWith => '分享・用照片应用等打开';

  @override
  String homeWorkDeleteConfirmTitle(String name) {
    return '要删除$name吗？';
  }

  @override
  String get homeWorkDeleteConfirmBody => '设备中的导出文件将被删除，此操作无法撤销。';

  @override
  String get homePreviewFailed => '无法播放预览';

  @override
  String get homeFirstLaunchMessage => '您可以制作手绘动画';

  @override
  String get homeFirstLaunchStart => '开始使用';

  @override
  String get settingsScreenTitle => '设置';

  @override
  String get settingsBasicTitle => '基本';

  @override
  String get settingsBasicSubtitle => 'FPS・背景色・语言';

  @override
  String get settingsBasicSheetTitle => '基本设置';

  @override
  String get settingsDefaultFps => '默认FPS';

  @override
  String get settingsDefaultFpsSubtitle => '新建项目界面的初始值';

  @override
  String get settingsLanguage => '语言';

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
  String get settingsSearchHint => '搜索设置...';

  @override
  String get settingsPerformanceTitle => '性能';

  @override
  String get settingsPerformanceSubtitle => '画质设置・撤销次数・回收站・运行速度';

  @override
  String get settingsGestureTitle => '手势';

  @override
  String get settingsGestureSubtitle => '双指点按・长按';

  @override
  String get settingsPenTitle => '笔输入';

  @override
  String get settingsPenSubtitle => '笔压・倾斜・笔按钮';

  @override
  String get settingsWorkspaceTitle => '工作区';

  @override
  String get settingsWorkspaceSubtitle => '工具栏编辑・面板布局';

  @override
  String get settingsBucketTitle => '油漆桶填充';

  @override
  String get settingsBucketSubtitle => '容差・扩展・潜入线稿下方';

  @override
  String get settingsThemeTitle => '主题・外观';

  @override
  String get settingsThemeSubtitle => '主题设置・工作区';

  @override
  String get settingsWatermarkTitle => '水印';

  @override
  String get settingsWatermarkSubtitle => '自定义水印';

  @override
  String get settingsTransferTitle => '数据迁移';

  @override
  String get settingsTransferSubtitle => '将设置・素材・画笔导出/导入到其他设备';

  @override
  String get settingsFontTitle => '字体管理';

  @override
  String get settingsFontSubtitle => '添加・搜索・删除TTF/OTF字体';

  @override
  String get settingsNoResults => '未找到相关设置项';

  @override
  String get settingsTermsLicense => '使用条款・许可';

  @override
  String get settingsDrawingAreaTitle => '绘图区域初始值';

  @override
  String get settingsDrawingAreaHint => '将作为新建项目时的初始值。';

  @override
  String get settingsDrawingAreaWiden => '扩大绘图区域';

  @override
  String get settingsDrawingAreaScale => '倍率';

  @override
  String settingsScaleValue(String scale) {
    return '$scale倍';
  }

  @override
  String get commonCancel => '取消';

  @override
  String get commonCreate => '创建';

  @override
  String get commonChange => '更改';

  @override
  String get commonDelete => '删除';

  @override
  String get confirmDeleteGenericBody => '确定要删除吗？此操作无法撤销。';

  @override
  String confirmDeleteNamedBody(String name) {
    return '要删除「$name」吗？此操作无法撤销。';
  }

  @override
  String get commonFavoriteDeleteBlocked => '已收藏的项目无法删除，请先取消收藏。';

  @override
  String get commonSave => '保存';

  @override
  String get commonRestore => '恢复';

  @override
  String get commonClose => '关闭';

  @override
  String get commonRename => '重命名';

  @override
  String get commonCopy => '复制';

  @override
  String get commonCut => '剪切';

  @override
  String get commonPaste => '粘贴';

  @override
  String get commonDuplicate => '复制';

  @override
  String homePasteTooltip(int count) {
    return '粘贴$count项';
  }

  @override
  String get homePasteSnackbar => '已粘贴';

  @override
  String get commonOk => '确定';

  @override
  String get gestureSettingsTitle => '手势设置';

  @override
  String get gestureTwoFingerTap => '双指点按';

  @override
  String get gestureThreeFingerTap => '三指点按';

  @override
  String get gestureTwoFingerSwipe => '双指左右滑动';

  @override
  String get gestureLongPress => '长按';

  @override
  String get gestureHoldEyedropperSection => '长按取色';

  @override
  String get gestureHoldEyedropperTitle => '长按启动取色';

  @override
  String get gestureHoldEyedropperHint =>
      '使用画笔或橡皮擦绘图时，手指不动按住一段时间即可拾取该处颜色并设为当前颜色。';

  @override
  String get gestureHoldEyedropperDurationLabel => '保持时长';

  @override
  String gestureHoldEyedropperSecondsValue(String seconds) {
    return '$seconds秒';
  }

  @override
  String get gestureActionEyedropper => '吸管';

  @override
  String get gestureActionPanTool => '抓手工具';

  @override
  String get gestureActionEraserToggle => '切换橡皮擦';

  @override
  String get gestureActionBrushToggle => '切换画笔';

  @override
  String get gestureActionFrameMove => '切换帧';

  @override
  String get gestureActionNextTool => '快速切换工具';

  @override
  String get gestureActionOnionSkinToggle => '洋葱皮开/关';

  @override
  String get gestureActionNone => '不执行任何操作';

  @override
  String get homeDrawerAppTagline => '手绘动画制作应用';

  @override
  String get homeDrawerAutofillPreset => '自动上色设置';

  @override
  String get homeDrawerSettings => '设置';

  @override
  String get homeDrawerHelp => '帮助';

  @override
  String get homeDrawerTips => '使用技巧';

  @override
  String get homeDrawerPremium => 'Premium';

  @override
  String get gestureActionNoneShort => '无';

  @override
  String get pressureTryDrawHint => '可以用此设置试写（使用触控笔时会反映实际笔压）';

  @override
  String get pressureTryDrawClear => '清除';

  @override
  String get penSettingsTitle => '笔输入设置';

  @override
  String get penSettingsCurveSection => '笔压曲线';

  @override
  String get penSettingsCurveHint => '设置越弱，笔压的起始越平缓；设置越强，起始越陡峭。';

  @override
  String get penSettingsCurveWeak => '弱';

  @override
  String get penSettingsCurveNormal => '普通';

  @override
  String get penSettingsCurveStrong => '强';

  @override
  String get penSettingsCurveCustom => '自定义';

  @override
  String get penSettingsCustomGraphHint =>
      '点击图表空白处添加控制点（最多10个），拖动控制点移动，双击可删除（起点和终点无法删除）。';

  @override
  String get penSettingsResetCurveButton => '恢复默认';

  @override
  String get penSettingsPerBrushNote =>
      '※笔压的“反映到大小/不透明度”设置是各画笔单独设置的（在画笔设置面板中更改）。';

  @override
  String get penSettingsButtonSection => '笔按钮设置';

  @override
  String get penSettingsButton1 => '按钮1';

  @override
  String get penSettingsButton2 => '按钮2';

  @override
  String get bucketSettingsTitle => '油漆桶填充设置';

  @override
  String get bucketSettingsToleranceSection => '容差';

  @override
  String get bucketSettingsToleranceHint =>
      '调整与点击位置颜色的差异在多大范围内仍被视为同一区域。数值越大，即使颜色边界模糊也更容易扩散填充。';

  @override
  String get bucketSettingsExpandSection => '扩展';

  @override
  String get bucketSettingsExpandHint => '将填充区域向外扩展指定像素数，用于覆盖与线稿之间的细小缝隙（漏填部分）。';

  @override
  String get bucketSettingsUnderLineTitle => '潜入线稿下方';

  @override
  String get bucketSettingsUnderLineHint =>
      '扩展部分不会直接覆盖线稿，而是在保持线条外观的同时，将填充色绘制到现有像素的背后，减少线条抗锯齿边缘处出现的缝隙。';

  @override
  String get bucketSettingsUnderLineDisabledHint => '当「扩展」为0px时无效果。';

  @override
  String fontCatalogSearchHint(int count) {
    return '按字体名称搜索...（共$count种字体）';
  }

  @override
  String get fontCatalogAll => '全部';

  @override
  String get fontCatalogNoResults => '未找到匹配的字体';

  @override
  String get rulerPanelTitle => '标尺';

  @override
  String get rulerTypeLine => '直线标尺';

  @override
  String get rulerTypeEllipse => '椭圆标尺';

  @override
  String get rulerTypeRadial => '集中线标尺';

  @override
  String get rulerTypeOnePoint => '一点透视';

  @override
  String get rulerTypeTwoPoint => '两点透视';

  @override
  String get rulerTypeThreePoint => '三点透视';

  @override
  String get rulerDivisions => '分割数';

  @override
  String get transferScreenTitle => '数据迁移（.niatra）';

  @override
  String get transferInstructionHint => '请选择要迁移到其他设备的项目。';

  @override
  String get transferItemSettings => '设置';

  @override
  String get transferItemMaterials => '素材';

  @override
  String get transferItemBrush => '画笔';

  @override
  String get transferItemPresets => '自动上色设置';

  @override
  String get transferItemTheme => '主题';

  @override
  String get transferItemPalette => '调色板（取色器・像素画专用）';

  @override
  String get transferProjectsSectionTitle => '制作中的项目（可选）';

  @override
  String get transferProjectsHint => '只需选择要包含在迁移内容中的项目。所选项目将连同素材和字体一起完整迁移。';

  @override
  String get transferProjectsEmpty => '暂无项目。';

  @override
  String get transferImport => '导入';

  @override
  String get transferExport => '导出';

  @override
  String get transferExportSuccessSnackbar => '已导出.niatra文件';

  @override
  String transferExportFailedSnackbar(String error) {
    return '导出失败：$error';
  }

  @override
  String get transferImportSuccessSnackbar => '已导入.niatra文件';

  @override
  String transferImportFailedSnackbar(String error) {
    return '导入失败：$error';
  }

  @override
  String get folderManagementTitle => '文件夹管理';

  @override
  String get folderManagementCreateNew => '新建';

  @override
  String get folderManagementEmpty => '还没有文件夹';

  @override
  String get folderNameLabel => '文件夹名称';

  @override
  String get folderMoveToTitle => '移至文件夹';

  @override
  String get folderNone => '无文件夹';

  @override
  String get creativeAssetNameLabel => '名称';

  @override
  String get commonAdd => '添加';

  @override
  String get commonSearch => '搜索';

  @override
  String get autofillPresetSelectionTitle => '要使用的自动上色设置';

  @override
  String get autofillPresetSelectionHint =>
      '只选择本项目中使用的自动上色设置，可以让分配部位时的列表更简洁、更易于查看。';

  @override
  String autofillPresetSelectionPartCount(int count) {
    return '$count个部件';
  }

  @override
  String get autofillPresetSelectionButton => '选择要使用的自动上色设置';

  @override
  String autofillPresetSelectionCountLabel(int count) {
    return '已选$count个';
  }

  @override
  String get commonEdit => '编辑';

  @override
  String get commonFavoriteToggle => '切换收藏';

  @override
  String get commonIncrease => '增加';

  @override
  String get commonDecrease => '减少';

  @override
  String get commonPlay => '播放';

  @override
  String get commonPause => '暂停';

  @override
  String get fontCatalogDownloadTooltip => '下载字体';

  @override
  String get timelineBackToCanvasTooltip => '保存并返回画布';

  @override
  String get timelineBackToProjectListTooltip => '返回项目列表';

  @override
  String get timelineBackToProjectListDialogTitle => '返回项目列表';

  @override
  String get timelineBackToProjectListDialogBody => '要先保存更改再返回吗？';

  @override
  String get timelineBackToProjectListSaveButton => '保存并返回';

  @override
  String get timelineBackToProjectListDiscardButton => '不保存直接返回';

  @override
  String get timelineSkipToStart => '跳到第一帧';

  @override
  String get timelineStepBack => '后退一帧';

  @override
  String get timelineStepForward => '前进一帧';

  @override
  String get timelineSkipToEnd => '跳到最后一帧';

  @override
  String get timelineLoopOnTooltip => '循环播放：开启（点击关闭）';

  @override
  String get timelineLoopOffTooltip => '循环播放：关闭（点击开启）';

  @override
  String get quickToolPanelTitle => '快捷工具设置';

  @override
  String get quickToolEmpty => '暂无已添加的工具';

  @override
  String get quickToolAddCurrentBrush => '添加当前画笔';

  @override
  String get quickToolEraser => '橡皮擦';

  @override
  String get quickToolEyedropper => '吸管';

  @override
  String get quickToolBucket => '填充桶';

  @override
  String quickToolSizeDialogTitle(String brushName) {
    return '$brushName的大小';
  }

  @override
  String get settingsShortcutTitle => '快捷键设置';

  @override
  String get settingsShortcutSubtitle => '为键盘・左手设备分配工具和操作';

  @override
  String get shortcutSettingsTitle => '快捷键设置';

  @override
  String get shortcutSettingsHint =>
      '可以为键盘或左手设备的按键分配工具（可细到具体画笔和粗细）或撤销/重做等操作。画布模式、时间轴模式均可使用。';

  @override
  String get shortcutEmpty => '尚未注册任何快捷键';

  @override
  String get shortcutCaptureTitle => '请按下按键';

  @override
  String get shortcutCaptureHint =>
      '请按下想要设置的按键组合（可同时按住Ctrl・Shift・Alt等辅助键）。按Esc取消。';

  @override
  String shortcutChooseActionTitle(String combo) {
    return '要为$combo分配什么？';
  }

  @override
  String get shortcutActionTypeTool => '选择工具';

  @override
  String get shortcutActionTypeCommand => '主要操作';

  @override
  String get shortcutCommandUndo => '撤销';

  @override
  String get shortcutCommandRedo => '重做';

  @override
  String get shortcutCommandToggleLayerPanel => '切换图层面板（画布）';

  @override
  String get shortcutCommandPlayPause => '播放/暂停（时间轴）';

  @override
  String get shortcutCommandPreviousFrame => '后退1帧（时间轴）';

  @override
  String get shortcutCommandNextFrame => '前进1帧（时间轴）';

  @override
  String get shortcutCommandSelectAll => '全选';

  @override
  String get shortcutCommandCopy => '复制';

  @override
  String get shortcutCommandCut => '剪切';

  @override
  String get shortcutCommandPaste => '粘贴';

  @override
  String get shortcutConflictTitle => '该按键已被分配';

  @override
  String shortcutConflictBody(String combo, String existingLabel) {
    return '$combo已经分配给了「$existingLabel」。要覆盖吗？';
  }

  @override
  String get shortcutConflictOverwrite => '覆盖';

  @override
  String get materialListTitle => '素材管理';

  @override
  String materialRemoveUnused(int count) {
    return '删除未使用素材（$count）';
  }

  @override
  String get materialEmptyTitle => '没有素材';

  @override
  String get materialEmptyHint => '从时间轴添加图片・视频・音频后，\n将显示在这里';

  @override
  String get materialUsedLabel => '使用中';

  @override
  String get materialUnusedLabel => '未使用';

  @override
  String get materialMissingLabel => '⚠ 缺失';

  @override
  String get materialDeleteTooltipUsed => '使用中，无法删除';

  @override
  String get materialRemoveOneConfirmTitle => '要删除该素材吗？';

  @override
  String get materialRemoveUnusedConfirmTitle => '要批量删除未使用的素材吗？';

  @override
  String get materialRemoveUnusedConfirmBody => '将删除项目中未被任何地方引用的全部素材。此操作无法撤销。';

  @override
  String materialRemovedSnackbar(int count) {
    return '已删除$count个未使用素材';
  }

  @override
  String get watermarkEmptyTitle => '还没有已注册的水印';

  @override
  String get watermarkEmptyHint => '点击右下角的+号添加图片或文字水印';

  @override
  String get watermarkAddFromImage => '从图片添加';

  @override
  String get watermarkAddText => '输入文字';

  @override
  String get watermarkAddedSnackbar => '已添加水印';

  @override
  String get watermarkTextDialogTitle => '添加文字水印';

  @override
  String get watermarkTextFieldLabel => '要显示的文字';

  @override
  String get watermarkTextColorLabel => '文字颜色';

  @override
  String get watermarkTextColorTapHint => '点击选择颜色';

  @override
  String get watermarkDropShadowLabel => '投影';

  @override
  String get watermarkShadowColorLabel => '阴影颜色';

  @override
  String get watermarkShadowOffsetXLabel => '阴影位置X';

  @override
  String get watermarkShadowOffsetYLabel => '阴影位置Y';

  @override
  String get watermarkShadowBlurLabel => '阴影模糊';

  @override
  String get watermarkOutlineLabel => '描边';

  @override
  String get watermarkOutlineColorLabel => '描边颜色';

  @override
  String get watermarkOutlineWidthLabel => '描边粗细';

  @override
  String get premiumActiveLabel => 'Premium已开通';

  @override
  String get premiumVsTitle => '免费版 vs 高级版';

  @override
  String get premiumHeroTitle => '开通高级版，创作更自由';

  @override
  String get premiumHeroSubtitle => '无时长上限、无水印、色调曲线／色阶校正等功能全部解锁';

  @override
  String get premiumHeroHighlightDuration => '时长最长2小时';

  @override
  String get premiumHeroHighlightWatermark => '无水印';

  @override
  String get premiumHeroHighlightGrading => '色调曲线 /\n色阶调整';

  @override
  String get premiumCampaignFreeNote => '※ 活动期间，免费版也可使用以上全部高级功能';

  @override
  String get premiumPlanSectionTitle => '套餐';

  @override
  String get premiumStoreUnavailable => '无法连接到商店（仅可在真机或商店审核环境中购买）';

  @override
  String get premiumYearlyTitle => '年付套餐（推荐）';

  @override
  String get premiumYearlyDescription => '相当于2个月免费';

  @override
  String get premiumYearlyPrice => '¥5,500/年';

  @override
  String get premiumYearlyOriginalPrice => '¥6,600';

  @override
  String get premiumYearlyPerMonthLabel => '折合每月¥458';

  @override
  String get premiumMonthlyTitle => '月付套餐';

  @override
  String get premiumRestorePurchases => '恢复购买';

  @override
  String get premiumRestoredSnackbar => '已恢复购买信息（如有对应购买记录）';

  @override
  String get premiumCampaignBannerTitle => '上线纪念！付费会员专属功能限时开放活动';

  @override
  String get premiumCampaignBannerBody =>
      '活动期间，免费版也可免费使用全部高级功能（时长最长2小时・片尾标志编辑・水印・色调曲线・色阶校正）。';

  @override
  String premiumCampaignEndLabel(String date) {
    return '至$date';
  }

  @override
  String get premiumComparisonFeature => '功能';

  @override
  String get premiumComparisonFree => '免费';

  @override
  String get premiumFeatureDrawing => '动画制作・绘图功能';

  @override
  String get premiumFeatureTimeline => '时间轴';

  @override
  String get premiumFeatureExport => '视频导出';

  @override
  String get premiumFeatureMaxDuration => '最大时长';

  @override
  String get premiumFeatureEndLogo => '官方片尾标志';

  @override
  String get premiumFeatureWatermark => '水印';

  @override
  String get premiumFeatureToneCurve => '色调曲线';

  @override
  String get premiumFeatureLevelCorrection => '色阶校正';

  @override
  String get premiumFeatureAds => '广告';

  @override
  String get premiumFeatureCommunityUpload => '作品广场每日投稿数';

  @override
  String get premiumValueYes => '有';

  @override
  String get premiumValueNo => '无';

  @override
  String get premiumValueRemovable => '可删除';

  @override
  String get premiumValueDuration2Hours => '2小时';

  @override
  String get premiumValueDuration90Sec => '1.5分钟';

  @override
  String get premiumValueUploadFree => '1个';

  @override
  String get premiumValueUploadPremium => '3个';

  @override
  String get premiumPlanRecommendedBadge => '推荐';

  @override
  String get premiumMonthlyPrice => '¥550/月';

  @override
  String get toolbarItemPen => 'G笔';

  @override
  String get toolbarItemEraser => '橡皮擦';

  @override
  String get toolbarItemBucket => '填充桶';

  @override
  String get toolbarItemEyedropper => '吸管';

  @override
  String get toolbarItemFinger => '手指';

  @override
  String get toolbarItemPan => '手掌';

  @override
  String get toolbarItemSelect => '选择';

  @override
  String get toolbarItemTransform => '变形';

  @override
  String get toolbarItemText => '文字';

  @override
  String get toolbarItemShape => '图形';

  @override
  String get workspaceScreenTitle => '工作区设置';

  @override
  String get workspaceToolbarEditSection => '工具栏编辑';

  @override
  String get workspaceToolbarEditHint => '通过复选框选择要显示的工具，并可拖动调整顺序。';

  @override
  String get workspaceToolbarPcOnlyHint => '仅在横屏时显示于工具栏';

  @override
  String get workspaceToolbarPanDisabledHint => '手机模式下无法使用';

  @override
  String get workspaceResetToolbarDefault => '恢复默认';

  @override
  String get workspacePanelLayoutSection => '面板布局';

  @override
  String get workspaceLeftHandedMode => '左手模式';

  @override
  String get workspaceLeftHandedSubtitlePc => '将面板放置在右侧';

  @override
  String get workspaceLeftHandedSubtitleMobile => '仅可在PC/DeX模式下设置';

  @override
  String get workspacePcModeSection => 'PC模式（DeX）';

  @override
  String get workspacePcModeHint => '在宽屏环境下会自动切换为面板固定排列的专业布局。如需手动固定，请在此处指定。';

  @override
  String get workspacePcModeAuto => '自动（按屏幕宽度判断・推荐）';

  @override
  String get workspacePcModeAlwaysPc => '始终使用PC模式';

  @override
  String get workspacePcModeAlwaysMobile => '始终使用手机模式';

  @override
  String get workspaceSaveSection => '保存工作区';

  @override
  String get workspaceSaveHint => '可将左手模式・PC模式・工具栏・快捷工具设置命名保存，之后随时调用。';

  @override
  String get workspaceLoadButton => '加载工作区';

  @override
  String get workspaceEmptyToolbar => '没有要显示的工具';

  @override
  String get workspaceSaveDialogTitle => '保存工作区';

  @override
  String get workspaceSaveDialogLabel => '名称（例：动画用・线稿用）';

  @override
  String get workspaceLoadRightHanded => '右手';

  @override
  String get workspaceLoadLeftHanded => '左手';

  @override
  String get helpScreenTitle => '帮助';

  @override
  String get helpSearchHint => '搜索...';

  @override
  String get helpNoResults => '未找到相关项目';

  @override
  String get helpCategoryTool => '工具';

  @override
  String get helpCategoryLayer => '图层';

  @override
  String get helpCategoryAnimation => '动画';

  @override
  String get helpCategoryDrawing => '绘图';

  @override
  String get helpCategoryBrush => '画笔';

  @override
  String get helpCategoryPenInput => '笔输入';

  @override
  String get helpCategorySave => '保存';

  @override
  String get helpCategoryProjectManagement => '项目管理';

  @override
  String get helpCategoryExport => '导出';

  @override
  String get helpCategoryPremium => 'Premium';

  @override
  String get helpCategorySettings => '设置';

  @override
  String get helpCategoryCommunity => '社区';

  @override
  String get helpPenToolTitle => '笔工具';

  @override
  String get helpPenToolDesc =>
      '在画布上绘制线条的基本工具。长按可更改画笔种类・粗细・颜色（双击显示简要说明）。支持数位板/液晶数位板的笔压与倾斜，在设置画面的“笔输入”中调整笔压曲线，可以细致自定义笔压的传达方式（轻压时粗细/不透明度会变化多少）。切换笔的子工具后，还能用同一支笔工具进行贴网点・放置图章。';

  @override
  String get helpEraserToolTitle => '橡皮擦工具';

  @override
  String get helpEraserToolDesc =>
      '与笔工具相对，用于擦除已绘制的内容。与画笔一样可以调整粗细与不透明度，淡出、笔画衰减等画笔设置也同样适用。它进行的是“擦除”已有绘制内容的处理，而不是在图层的透明部分“添加”内容，因此下方图层会透出显示。';

  @override
  String get helpBucketToolTitle => '填充桶工具';

  @override
  String get helpBucketToolDesc =>
      '一次性填充被包围的区域。在线稿所围成的区域内点击，整个区域就会被填充为当前选择的颜色（或网点）。如果线稿有缝隙，颜色可能会扩散到意料之外的范围，因此使用前请确认线稿是否已完全闭合。可以在设置中切换纯色填充/网点填充。 详细设置（容差・扩展px・潜入线稿下方）可以在设置画面的「油漆桶填充」中调整。';

  @override
  String get helpLassoFillTitle => '套索填充';

  @override
  String get helpLassoFillDesc =>
      '用手指沿想要包围的范围描画出多边形区域，然后一次性填充其内部的工具。与填充桶不同，即使线稿有未闭合的部分，也可以自行指定要包围的范围，因此适合形状复杂或线条中断处的填色。';

  @override
  String get helpEyedropperToolTitle => '吸管工具';

  @override
  String get helpEyedropperToolDesc =>
      '拾取点击位置的颜色并将其设为绘图色的工具。它拾取的是画面上实际显示的全部图层合成后的颜色，因此即使在多个图层重叠的部分，也能准确获取“肉眼所见的颜色”。';

  @override
  String get helpSelectToolTitle => '选择工具';

  @override
  String get helpSelectToolDesc =>
      '选取画布的一部分区域，仅对所选区域进行移动・旋转・缩放的工具。长按可以从“矩形选择”“套索选择（自由形状包围）”“自动选择（魔术棒，自动合并相近颜色的区域）”三种选择方式中选择。选择中会在画布上显示表示所选范围的边框，在取消选择之前，所有帧・所有图层都会固定显示相同的范围。';

  @override
  String get helpFingerToolTitle => '手指工具（扭曲工具）';

  @override
  String get helpFingerToolDesc =>
      '沿手指划动的方向推挤像素使其扭曲，营造出用手指涂抹湿颜料般的效果。相较于精细修正，更常用于将已画好的线条进行有机的扭曲以增添表现力。';

  @override
  String get helpShapeToolTitle => '图形工具';

  @override
  String get helpShapeToolDesc =>
      '一键绘制直线・矩形・圆形等精确图形的工具。从起点拖动到终点时会即时预览，松开手指即可确定。在难以徒手绘制直线或正圆时非常方便。';

  @override
  String get helpTextToolTitle => '文字工具';

  @override
  String get helpTextToolDesc =>
      '在画布上放置文字的工具。可选择字体・大小・颜色・竖排/横排。竖排时还支持半角字母数字的自动旋转・纵中横（数字保持横向排列的表记）・注音标注（类似日语振假名的读音标注）。放置的文字在导出时也会作为像素烧录进画面。 可添加・搜索・删除文字工具可用字体的画面。除初始内置字体外的其他免费字体，为控制初始安装容量，需从此处按需下载。';

  @override
  String get helpQuickToolTitle => '快捷工具';

  @override
  String get helpQuickToolDesc =>
      '预先登记常用的画笔・工具组合，只需点击一个按钮即可依次切换。长按或向上滑动画布上的↺按钮，即可打开可以添加、排序、删除的管理弹窗。可通过拖动改变顺序。';

  @override
  String get helpLayerTitle => '图层';

  @override
  String get helpLayerDesc =>
      '将一块画布分成多个透明「图层」来绘制的机制。将线稿、上色、背景等分别绘制在不同图层上，之后可以只重做上色，或在不擦除线稿的情况下更换背景。画面中，叠得越靠上的图层显示在越靠前的位置。每个图层行的图标可一键删除或与下方图层合并，图层面板顶部的图标还可以一次性合并所有可见图层。';

  @override
  String get helpBlendModeTitle => '混合模式';

  @override
  String get helpBlendModeDesc =>
      '用于更改图层与下方图层的合成方式，常用于叠加网点或颜色效果的图层。\n正常：直接叠加。\n正片叠底：与下方图层相乘后变暗，是阴影表现的经典手法。\n滤色：叠加亮度后变亮，适合表现光效。\n叠加：暗部更暗、亮部更亮，增强对比度。\n线性减淡（添加）：直接相加颜色，适合光效线条等。\n减去：相减颜色，呈现暗沉的效果。\n变暗：取上下两图层中较暗的颜色。\n变亮：取上下两图层中较亮的颜色。\n颜色加深：使下方颜色变暗并加深发色。\n颜色减淡：使下方颜色变亮并加深发色。\n强光：比叠加更强烈的对比效果。\n柔光：比叠加更柔和的对比效果，适合柔和的阴影。\n差值：显示上下两色的差异，可用于检查颜色偏差等。\n色相、饱和度、颜色、明度：分别仅将该图层的色相、饱和度、色彩或明度反映到下方图层。';

  @override
  String get helpClippingTitle => '剪贴蒙版';

  @override
  String get helpClippingDesc =>
      '使绘制内容仅限于紧邻下方图层的不透明像素范围内的功能。当想要在不超出线稿的范围内上色时，在线稿图层上方新建上色图层并启用剪贴蒙版，就不必担心不小心画到线稿外面。';

  @override
  String get helpCommonLayerTitle => '公共图层';

  @override
  String get helpCommonLayerDesc =>
      '普通图层按每一帧独立存在，而公共图层则是在多个帧・场景中共享同一内容的图层。像背景这样不随帧变化而移动的元素，无需每帧重新绘制，只需画一次即可。在时间轴上会以专用轨道的形式显示。 可以把普通图层转换为共同图层（在多个帧中持续显示相同内容的图层）的功能。也可以先把当前显示的图层合并为一张，再进行共同化。想反复使用背景等每帧内容相同的部分时，可以省去重新绘制的麻烦。';

  @override
  String get helpAutoFillTitle => '自动上色';

  @override
  String get helpAutoFillDesc =>
      '在自动上色专用线稿图层下方创建自动上色图层，并根据预先制作的「自动上色设置」（各部位的颜色、网点组合）自动进行上色的功能。由于可以在画完线稿后一次性上色，能大幅减少需要反复绘制同一角色的手绘动画中的上色工作量。重新绘制线稿后，时间轴和图层面板会显示更新标记（❗），提示需要重新执行自动上色。在时间轴画面的三点菜单中选择「执行自动上色」，即可一次性重新计算所有带有更新标记（❗）的自动上色图层，省去重新绘制线稿后逐个图层在图层面板中执行的麻烦。自动上色设置的每个部位都有关于如何处理线稿颜色的设置（指定颜色、与填充色相同、色彩描边）。选择色彩描边（贴合线稿）后，线稿颜色会按HSL偏移以匹配填充色，使线条不显突兀、自然融合。设置越积越多，分配部位时显示的列表就会变长、难以浏览。可以在项目设置（或图层面板的部位分配对话框）中，将列表筛选为只显示本项目使用的设置，让列表更简洁、更易于挑选。';

  @override
  String get helpOnionSkinTitle => '洋葱皮';

  @override
  String get helpOnionSkinDesc =>
      '将当前编辑帧前后的帧以半透明方式叠加显示，使你可以一边确认动作的连贯性一边绘制的功能。可以在性能设置中调整显示的帧数（前后各显示几帧）以及颜色・透明度。';

  @override
  String get helpRulerTitle => '标尺';

  @override
  String get helpRulerDesc =>
      '直线・圆・椭圆・透视标尺（使用消失点的透视图法专用标尺）等，用于辅助绘制徒手难以画出的精确线条的功能。放置的标尺会使笔尖自动吸附，即使是没有标尺就难以绘制的具有纵深感的构图也会更容易画出。标尺可以通过操作控制柄进行移动・旋转・调整大小。';

  @override
  String get helpFadeTitle => '淡出';

  @override
  String get helpFadeDesc =>
      '画笔设置之一，随着笔画的持续绘制，不透明度或粗细会逐渐减少的效果。用于想让线条末端产生渐隐感，或想营造带有余韵的笔触时。';

  @override
  String get helpStrokeDecayTitle => '笔画衰减';

  @override
  String get helpStrokeDecayDesc =>
      '与淡出类似，但更接近“墨水逐渐用尽”的表现，绘制得越久颜色越淡或越干涩的效果。可再现毛笔或马克笔持续书写时墨水耗尽般的质感。';

  @override
  String get helpColorMixingTitle => '混色';

  @override
  String get helpColorMixingDesc =>
      '使用画笔上色时，将画笔正下方已有的颜色与即将涂上的选定颜色混合后再绘制的功能。适合想让新颜色与已有颜色自然融合时使用，如水彩或油画般的效果。';

  @override
  String get helpPressureCurveTitle => '笔压曲线';

  @override
  String get helpPressureCurveDesc =>
      '笔输入设置中的功能，可通过图表自由调整实际笔压强度与画笔粗细・不透明度反映方式之间的关系。无论是希望轻压也能画出粗线的人，还是相反希望必须用力按压才会变粗的人，都能根据自己的用笔习惯细致自定义画感。更改设置后可当场试写确认效果。';

  @override
  String get helpTimelineTitle => '时间轴';

  @override
  String get helpTimelineDesc =>
      '管理动画时间轴的画面。将帧（单张静止图像）排列并像翻页动画一样播放，就形成了动画。图片・视频・音频等素材轨道、公共图层轨道、摄像机关键帧也都在同一条时间轴上管理。';

  @override
  String get helpSceneTitle => '场景';

  @override
  String get helpSceneDesc =>
      '将一个项目（一段视频）内部按场景（分镜）划分管理的功能。文件夹是以项目为单位进行整理，而场景则用于表现一段视频内部的场景转换。在时间轴的场景标签中可以新增、复制、删除、重命名、重新排序场景。切换到多选模式后，还可以一次性移动、复制或删除多个场景。';

  @override
  String get helpCameraKeyframeTitle => '摄像机关键帧';

  @override
  String get helpCameraKeyframeDesc =>
      '在时间轴上的特定位置记录摄像机的位置・缩放比例・旋转角度的功能。关键帧之间会自动平滑插值，因此可以轻松添加平移（横向移动）或拉近拉远等镜头运动。';

  @override
  String get helpEffectFilterTitle => '演出滤镜';

  @override
  String get helpEffectFilterDesc =>
      '可应用于场景或帧的画面效果（模糊・色调校正・辉光・像素化等）。在不改变手绘画面本身的前提下，作为演出手段调整整个画面观感时使用。像素化也可以选择配色方式（不指定颜色・指定颜色・指定颜色数・从调色板选择）。 演出滤镜可以叠加应用多个，其应用顺序依照时间轴上的排列顺序。拖动滤镜列表重新排序后，实际反映到画面上的顺序也会随之改变。 一种演出滤镜，会逐帧改变类似胶片颗粒感的噪点。可以用滑块调整强度、数量（噪点出现的密度）和颗粒大小。回到同一帧时噪点形态相同（拖动时不会闪烁），播放时颗粒则会呈现出跳动的效果。 用来表现画面中降雨的演出滤镜。可以用滑块调整降雨强度（雨滴数量）、速度、雨滴大小和风向角度。每滴雨都会随着帧数推进以恒定速度持续下落，呈现自然的降雨效果。';

  @override
  String get helpEndCardTitle => 'EndCard（片尾标志）';

  @override
  String get helpEndCardDesc =>
      '导出视频时，会在正片结尾自动添加的NIARIM标志短片（约5秒）。免费版无法隐藏或删除，但成为Premium会员后可以开关显示・更改时长・进行替换。';

  @override
  String get helpAutoSaveTitle => '自动保存';

  @override
  String get helpAutoSaveDesc =>
      '专用于崩溃或文件损坏时恢复的保存。每次绘图等发生变更时都会自动保存，最多保留3份，按从旧到新的顺序覆盖。它与手动保存（存档槽・存档树）完全分开管理，不能替代常规保存。仅在应用异常退出后重新启动时，才会询问是否要恢复。';

  @override
  String get helpSaveSlotTitle => '存档槽';

  @override
  String get helpSaveSlotDesc =>
      '在固定数量的存档位（槽）中，由自己选择保存位置进行保存的方式。槽位数量由设置决定（低画质5个・中画质10个）。由于每次都需要自己选择要覆盖的槽位，适合“想保留这个时间点的状态”这类管理方式。';

  @override
  String get helpSaveTreeTitle => '存档树';

  @override
  String get helpSaveTreeDesc =>
      '每次保存都会创建一个新的存档点，并可以从过去的存档点分支出另一段历史（分叉）的保存方式。没有数量上限，适合“想回到那个版本后再尝试另一种展开”这类用法。画面上存档点会以从下往上生长的树状图形式显示。';

  @override
  String get helpFolderTitle => '文件夹';

  @override
  String get helpFolderDesc =>
      '将项目（作品）分组整理的功能。支持多层级结构，因此也可以用来统一管理同一作品的多个话数或系列作品（例如：在“作品名”文件夹中依次排列“第1话”“第2话”……等项目）。如果想在一部动画内划分场景，请使用画布画面中的“场景”功能，而不是文件夹。';

  @override
  String get helpTrashTitle => '回收站';

  @override
  String get helpTrashDesc =>
      '已删除项目暂时移动到的地方。在被彻底删除之前，都可以从这里恢复。可以在设置中指定自动删除的天数（关闭/30天/60天/90天）。';

  @override
  String get helpShareTitle => '共享（.niashare）';

  @override
  String get helpShareDesc =>
      '用于将项目传递给他人（或自己的其他设备）的专用共享文件格式。接收方打开此文件后，会复制并添加到自己的项目列表中。共享源的.niashare文件本身不会被更改。';

  @override
  String get helpTransferTitle => '数据迁移（.niatra）';

  @override
  String get helpTransferDesc =>
      '将设置、素材、笔刷、自动上色设置、主题、调色板（取色器・像素画专用）等整个应用环境一次性转移到其他设备的功能。可以通过复选框单独选择要转移的项目。如果想传递单个项目，请改用「共享（.niashare）」。';

  @override
  String get helpVideoExportTitle => '视频导出（MP4・WebM・GIF）';

  @override
  String get helpVideoExportDesc =>
      '将作品导出为通用MP4视频。免费版可导出的时长有上限（90秒），且会在视频结尾自动添加片尾卡（应用Logo）。 可在保留Alpha通道（背景透明部分）的情况下导出的视频格式。仅在支持的播放环境中才能透明播放。适合作为素材叠加到其他应用中使用。 导出为动图GIF。由于会自动循环播放，适合在社交媒体上轻松分享的场景。 如果更看重兼容性，也可以导出为AVI（Motion JPEG）。所采用的编码器在专利和授权方面较为安全，但不支持Alpha通道（透明），部分设备上应用内预览可能无法使用（此时仍可通过「分享」用外部播放器播放）。 免费会员的项目长度上限为90秒（付费会员为2小时）。如果新增或复制帧会超过上限，在点击按钮的瞬间就会显示提示对话框，因此实际上不会超过90秒。';

  @override
  String get helpTransparentWebmTitle => '透明WebM';

  @override
  String get helpCommunityTitle => '作品广场';

  @override
  String get helpCommunityDesc =>
      '可以将动画・插画作品以YouTube视频的形式发布到社区，并浏览其他用户的作品。可以切换「最新」「排行榜」「关注」三个标签页，也可以按作品标题或投稿者名称搜索。切换到标签搜索模式后可按标签筛选作品，标签不仅投稿者本人，其他用户也可以自由添加或删除（投稿者锁定的标签只能由投稿者本人解锁），点击标签即可筛选出相同标签的作品。点击作品卡片会打开可拖动、可调整大小的悬浮预览窗口，可以在继续操作其他画面的同时观看。点击「查看详情」按钮可打开作品详情画面（投稿者、发布日期、标签编辑、收藏、转发等）。点击投稿者名称旁的「关注」按钮即可将其加入关注列表，「关注」标签页会按时间顺序汇总显示该作者的作品。有人关注你时，会显示在画面右上角铃铛图标的通知列表中。你可以分别设置自己的关注列表/粉丝列表是否对所有用户公开（默认非公开），也可以查看已公开的其他用户的列表。除自己发布的作品外，都可以用「转发」按钮转发；当关注的作者转发了他人的作品时，该作品也会以「发布日期」和「转发日期」中较新的一方为基准，混入「关注」标签页中显示（卡片上会显示「○○转发了」）。收藏的作品会汇总显示在主页的「已收藏」标签页中，也可以在投稿者作品列表画面的「收藏」标签页中查看。可以设置自己的收藏列表是否对其他用户公开（默认不公开），也可以查看已设为公开的其他用户的收藏列表。对不当作品可以附上理由进行举报，举报提交后会询问你是否要屏蔽该投稿者。竖屏视频可以在「竖屏模式」中连续播放观看。每日可发布的作品数量有上限，免费会员每天1个，高级会员每天3个。';

  @override
  String get helpWatermarkEntryTitle => '水印';

  @override
  String get helpWatermarkEntryDesc =>
      '可以在导出的视频・图片上加入自己签名或Logo作为水印的高级会员专属功能。可以调整位置、大小、不透明度。点击时间轴共通图层轨道上放置的水印，随时都能重新编辑其角度、大小、不透明度、显示范围（循环显示）——不仅是首次设置时，在项目中实际使用时也能随时细致调整。';

  @override
  String get helpPremiumEntryTitle => 'Premium';

  @override
  String get helpPremiumEntryDesc =>
      '成为高级会员后，免费版限制的90秒视频时长将延长至最长2小时，并可移除每个视频结尾自动添加的片尾卡（应用Logo）。同时广告也会隐藏，还可使用水印、色调曲线、色阶校正功能。';

  @override
  String get helpPerformanceSettingsTitle => '性能设置';

  @override
  String get helpPerformanceSettingsDesc =>
      '可根据设备性能从低画质・中画质・高画质预设中选择，也可逐项单独设置（自定义）。除保存方式・运行速度・洋葱皮・倾斜检测外，撤销次数、回收站自动删除等影响应用容量与运行负载的设置也都集中在这里。';

  @override
  String get helpMaterialClipTitle => '素材片段（图片・视频・音频）';

  @override
  String get helpMaterialClipDesc =>
      '放置在时间轴图片、视频、音频轨道上的片段。长按拖动片段本身可移动其起始位置，拖动两端的手柄可改变使用范围（长度）。点击片段会打开详情面板，其中的复制图标用于复制、垃圾桶图标用于删除。图片・视频在内部作为图层处理，音频则作为直接挂在场景上的片段管理。';

  @override
  String get helpGestureSettingsTitle => '手势设置';

  @override
  String get helpGestureSettingsDesc =>
      '可以将撤销/重做、跳转帧、取色等操作分配给双指点击、三指点击、双指滑动或长按。数位笔按键（在支持的触控笔上）也可以单独分配操作。想不切换工具就用一个动作触发常用操作时很方便。';

  @override
  String get helpBucketDetailSettingsTitle => '填充工具详细设置';

  @override
  String get helpBucketDetailSettingsDesc =>
      '在设置画面的“填充工具”中可以调整容差（点击位置的颜色相差多少仍视为同一区域）、扩展px（填充区域向边界外扩展多少以填补线稿的缝隙）以及潜入线条下方（不覆盖线稿本身，而是把扩展部分合成到已有像素的背后，从而保持线条外观不变）。当线稿有细小缝隙或填色感觉不完整时，调整这些设置能让效果更稳定。';

  @override
  String get helpStampToolTitle => '印章工具';

  @override
  String get helpStampToolDesc =>
      '把预先登记的图片像笔刷一样放置到画布上。特效线、背景图案、小物件等无需每次重画即可反复使用。开启像素模式后，贴上的印章会通过马赛克降分辨率＋减少色数处理成像素画风格。 在印章面板中可以调整所放置印章的旋转角度和大小。即使是同一个印章，改变方向和大小放置，也能让特效线、小物件的排列不显得单调而更自然。';

  @override
  String get helpToneFillTitle => '网点上色';

  @override
  String get helpToneFillDesc =>
      '在填充工具的设置中把纯色填充切换为网点填充，就能用选中的网点、线条等网点图案进行填充。还提供像素模式专用的方格纹、格子纹网点，可以做出符合像素画质感的上色效果。';

  @override
  String get helpPixelModeTitle => '像素模式';

  @override
  String get helpPixelModeDesc =>
      '笔刷、字体、印章各自都提供的设置，开启后会去除抗锯齿，呈现清晰的像素画风轮廓。想特意做出老游戏般的质感，或想营造低分辨率效果时使用。配色方式可从「不指定颜色」「指定颜色」「指定颜色数」「从调色板选择」4种中选择，也可以使用像素画专用调色板。';

  @override
  String get helpHomeScreenTitle => '主页';

  @override
  String get helpHomeScreenDesc =>
      '启动应用后最先显示的画面，可在项目、共享、作品列表、回收站各标签间切换查看。右上角的搜索图标可按项目名称筛选。在项目标签页中，可通过悬浮按钮选择新建项目或新建文件夹。';

  @override
  String get helpNewProjectTitle => '新建项目';

  @override
  String get helpNewProjectDesc =>
      '在创建项目前，统一设定画布尺寸、fps、时长（以秒为单位，之后会与时间轴上的帧数增减联动）、绘制区域（可以在导出范围之外多画一些的设置）、要使用的自动上色设置等。';

  @override
  String get helpThemeSettingsTitle => '主题设置';

  @override
  String get helpThemeSettingsDesc =>
      '可以从主题列表中选择应用整体的配色，也可以自由自定义强调色。标题・项目名称用字体与说明文字用字体是分开的，能在保持可读性的同时享受换装乐趣。';

  @override
  String get helpWorkspaceSettingsTitle => '工作区设置';

  @override
  String get helpWorkspaceSettingsDesc =>
      '汇集了左手模式（左右翻转停靠面板）、手动切换电脑/DeX模式、手掌工具显示条件等设置的画面。可以根据所用设备和惯用手调整成更方便操作的布局。';

  @override
  String get helpPenSettingsTitle => '画笔设置';

  @override
  String get helpPenSettingsDesc =>
      '除了数位板・数位屏的压感曲线外，这个设置画面还能把切换橡皮擦、取色器等操作分配给支持的触控笔侧面按键。';

  @override
  String get helpMaterialListTitle => '素材列表';

  @override
  String get helpMaterialListDesc =>
      '可以统一查看项目中使用的图片、视频、音频素材的画面。放置在时间轴上的素材的原始文件都汇集在这里。';

  @override
  String get helpFrameOperationsTitle => '帧操作';

  @override
  String get helpFrameOperationsDesc =>
      '在帧列表中，除了新增、复制、删除之外，还可以在多选模式下一次性移动、复制、删除多个帧。增加保留格数可以让同一帧持续显示多个格子（即所谓的“停格”），从而在动作较少的镜头中节省作画张数。';

  @override
  String get helpSceneOperationsTitle => '场景操作';

  @override
  String get helpSceneOperationsDesc =>
      '在时间轴的场景标签页中，可以新增、复制、删除、重命名、重新排序场景。切换到多选模式后，还可以一次性移动、复制、删除多个场景。';

  @override
  String get helpQuickToolManagementTitle => '快捷工具管理';

  @override
  String get helpQuickToolManagementDesc =>
      '登记一组常用工具组合，只需一次点击即可依次切换。长按或向上滑动可打开管理弹窗，编辑已登记的内容和顺序。';

  @override
  String get helpTransformSelectionTitle => '变换选区';

  @override
  String get helpTransformSelectionDesc =>
      '用选择工具圈出的区域，可以用变换工具进行移动、旋转、缩放。适合用来调整误画部分的位置，或只放大强调某一部分。 如果想变形整个图层，可以使用无需选区的「自由变形・网格变形」（从编辑菜单打开），可以单独拖动各个网格点做出更自由的变形。';

  @override
  String get helpGradientAutofillTitle => '渐变上色（自动上色设置）';

  @override
  String get helpGradientAutofillDesc =>
      '自动上色设置的每个部位不仅可以使用单色，还可以设置渐变。可拖动的对称控制点让你直观地调整渐变的范围和角度。每个部件还可以设置「用指定颜色描边」。勾选后，会在填色范围的最外侧（紧贴线稿的部分）画出指定颜色和粗细的线条。描边颜色可通过取色器自由选择，粗细可通过滑块、±按钮或点击数字直接输入来调整。设置项上方会显示预览，可以在实际执行自动上色之前确认颜色和粗细。';

  @override
  String get helpColorPickerTitle => '取色器';

  @override
  String get helpColorPickerDesc =>
      '可在同一画面中切换HSV与RGB来选色的取色器。调色板功能可保存、调用正在使用的配色组合。调色板也可以通过文件导出或二维码与其他设备共享。';

  @override
  String get helpUndoSettingsTitle => '撤销次数设置';

  @override
  String get helpUndoSettingsDesc =>
      '在性能设置中可以调整撤销能回溯的操作次数。次数越多越能放心地反复尝试，但也会占用更多内存；在低性能设备上减少次数可以让运行更轻快。';

  @override
  String get helpBrushFavoriteTitle => '笔刷收藏';

  @override
  String get helpBrushFavoriteDesc =>
      '点击笔刷列表中笔刷上的星形图标即可添加或取消收藏（与应用内其他收藏功能——自动上色设置、图章、字体、绘图滤镜等——操作方式相同）。列表顶部的星形图标还可以筛选为仅显示收藏项目。已收藏的笔刷不会被误删。';

  @override
  String get helpCustomBrushTitle => '自定义笔刷';

  @override
  String get helpCustomBrushDesc =>
      '在笔刷列表中长按预装笔刷并选择「复制」，即可基于它创建专属自定义笔刷。复制后的笔刷可以自由编辑粗细、不透明度、硬度、旋转、密度、散布、模糊半径等参数，不需要时也可以删除（预装笔刷本身无法编辑或删除）。还可以用文件夹分类，或用星标图标收藏。';

  @override
  String get helpLayerFolderTitle => '图层文件夹';

  @override
  String get helpLayerFolderDesc =>
      '可以把多个图层整理到文件夹中的功能。即使是部位较多的插画，也能让图层面板保持清晰易看。剪裁无法跨文件夹套用，如果要使用剪裁，建议把相关图层放在同一个文件夹内。';

  @override
  String get helpLayerMultiSelectTitle => '图层多选・批量操作';

  @override
  String get helpLayerMultiSelectDesc =>
      '使用图层面板的选择模式，可以用勾选框一次选中多个图层进行合并或批量删除。合并只能在普通图层、自动上色用线稿、自动上色图层之间进行（共同图层、文件夹、时间轴素材不能合并）。';

  @override
  String get helpDrawingAreaTitle => '作画区域';

  @override
  String get helpDrawingAreaDesc =>
      '可以在比导出范围更大的区域内作画的设置。画布上会显示表示导出范围的红色边框，画到边框外的部分不会被导出，但可以为之后用推拉镜头等运镜方式调整所展示的范围留出余地。在新建项目时设置放大倍率。';

  @override
  String get helpCanvasBackgroundTitle => '画布背景色';

  @override
  String get helpCanvasBackgroundDesc =>
      '可以设置项目画布的背景色。使用透明导出（透明WebM）时背景色不会影响导出结果，但可以改成自己喜欢的颜色，方便作画时查看。';

  @override
  String get helpProjectDetailTitle => '项目详情画面';

  @override
  String get helpProjectDetailDesc =>
      '可以在一个画面中集中查看、编辑项目名称、缩略图、收藏状态、要启用的自动上色设置筛选等项目相关设置。存档树的入口也在这里。';

  @override
  String get helpWatermarkEditTitle => '重新编辑水印';

  @override
  String get helpWatermarkEditDesc =>
      '点击放置在时间轴共同图层轨道上的水印，随时可以重新编辑其角度、大小、不透明度、显示范围（循环显示）。不仅在登记时，在项目中实际使用时也能随时细致调整。';

  @override
  String get helpAudioClipTitle => '音频片段的音量・淡入淡出';

  @override
  String get helpAudioClipDesc =>
      '放置在时间轴上的音频片段，可以在详情面板中调整音量、淡入、淡出的秒数。可用来调整音效和背景音乐的音量平衡，或让曲子的开头、结尾更加顺滑。';

  @override
  String get helpPenSubToolTitle => '画笔子工具';

  @override
  String get helpPenSubToolDesc =>
      '长按画笔工具，可以从普通绘图切换到网点填充或印章放置等子工具。无需每次切换工具，就能用同一支笔在多种作业之间来回操作。';

  @override
  String get helpTiltDetectionTitle => '倾斜检测';

  @override
  String get helpTiltDetectionDesc =>
      '利用支持的触控笔的倾斜信息，在笔尖倾斜放倒时让线条变粗或变淡，重现更接近实际画具的书写手感的设置。可以在性能设置中开关。';

  @override
  String get helpFontImportTitle => '字体读取';

  @override
  String get helpFontImportDesc =>
      '可以直接读取设备内的字体文件来使用的功能。可在设置画面字体管理的「读取」标签页中添加。想使用未公开发布的自制字体或已购买的商用字体时可以使用此功能。';

  @override
  String get helpExportScreenTitle => '导出画面';

  @override
  String get helpExportScreenDesc => '导出视频、图片期间会显示进度，也可以中途取消。所需时间会因设备性能而异。';

  @override
  String get helpDrawingFilterTitle => '绘图滤镜';

  @override
  String get helpDrawingFilterDesc =>
      '直接应用于所选图层的滤镜（与应用于整条时间轴或整个场景的演出滤镜不同，绘图滤镜按图层生效）。包含模糊、锐化、USM锐化、色调曲线、色阶、暗角、噪点、复古动画、显像管、动画风、描边、像素化等。描边不会改写原图层，只会把描边后的结果绘制到一个新图层上。像素化也可以选择配色方式（不指定颜色・指定颜色・指定颜色数・从调色板选择）。';

  @override
  String get helpLayerKeyframeTitle => '图层关键帧（分部件动画）';

  @override
  String get helpLayerKeyframeDesc =>
      '按帧设置每个图层的位置・缩放・旋转，关键帧之间会自动插值。摄像机关键帧移动的是整个画面，而这个功能只移动单个图层。由于自动上色的每个部件都会生成为独立的图层，因此可以直接用它来做分部件动画（只动一只手臂、只让嘴巴开合等）。每个关键帧还可以单独设置「匀速」「缓入」「缓出」「缓入缓出」「弹跳」这类缓动（与下一个关键帧的衔接方式），不仅限于单调的匀速移动，还能表现出弹跳般的动作。在图层面板的三点菜单「动画（关键帧）」中设置。图层本身的画面内容不会改变，只是显示位置发生变化的非破坏性变形。此功能只影响时间轴的显示（预览・导出），不会影响画布模式下的实际作画。';

  @override
  String get helpLayerGroupTitle => '图层分组（把多个部件一起移动）';

  @override
  String get helpLayerGroupDesc =>
      '用同一组关键帧把多个图层一起移动的功能。例如「手臂」由皮肤、袖子两个自动上色部件组成时，把这两个图层分到同一组后，只需一次关键帧操作就能让它们一起移动。在图层面板中多选（勾选框）图层，再点击底部工具栏的「分组」图标即可创建。分组的运动会叠加在每个成员图层自身的关键帧（如果设置了的话）之上，因此可以把分组整体的运动和单个图层的微调结合起来使用。一个图层同一时间只能属于一个分组。';

  @override
  String get tipsScreenTitle => '使用技巧';

  @override
  String get tipsSearchHint => '搜索技巧...';

  @override
  String get tipsCategoryVideo => '视频制作技巧';

  @override
  String get tipsCategoryEfficiency => '提高制作效率的技巧';

  @override
  String get tipsCategoryDrawing => '让作画更流畅的技巧';

  @override
  String get tipsCategoryEffects => '演出与收尾的技巧';

  @override
  String get tipsCategoryExport => '导出与操作技巧';

  @override
  String get tipsClipDuplicateTitle => '时间轴上的素材也能复制、移动、删除';

  @override
  String get tipsClipDuplicateDesc =>
      '点击图片、视频或音频素材可打开详情面板，点击其中的复制图标即可复制该素材。反复使用同一段音效，或把同一张图片重新摆放到不同场景，只需长按拖动加上一次复制按钮就能完成。';

  @override
  String get tipsTextCaptionTitle => '用文字工具添加字幕';

  @override
  String get tipsTextCaptionDesc =>
      '使用文字工具可以逐帧放置字幕或注释文字。将字体切换为像素模式，还能为文字营造出复古游戏般的质感。';

  @override
  String get tipsAutofillPresetTitle => '按部位预先登记自动上色设置';

  @override
  String get tipsAutofillPresetDesc =>
      '按皮肤、头发、衣服等部位预先登记好含阴影的自动上色设置，只需画好线稿就能自动完成大部分上色。也可以按项目筛选要使用的设置。';

  @override
  String get tipsAutofillBaseCoatTitle => '自动上色也可以只当作一张单色底色图层来用';

  @override
  String get tipsAutofillBaseCoatDesc =>
      '自动上色本来是用来按部位分别上色的功能，但不必细致地划分部位，只要用一个单色设置把整张线稿当作一张底色图层来涂，也已经很方便了。它能一次性把线内全部涂满，可以防止手动用油漆桶涂色时常见的漏涂（线条缝隙露出下层颜色的失误）。之后再在上面手动叠加颜色，就能不花分部位的功夫，也能获得自动上色的好处。';

  @override
  String get tipsBrushFavoriteTitle => '把常用笔刷加入收藏，切换时不用再找';

  @override
  String get tipsBrushFavoriteDesc =>
      '把常用的笔刷点击列表中的星形图标加入收藏。列表顶部的星形图标可以筛选为只显示收藏，减少查找的麻烦。收藏中的笔刷无法被误删。';

  @override
  String get tipsPressureCurveTitle => '把压感曲线调整成适合自己的手感';

  @override
  String get tipsPressureCurveDesc =>
      '设置画面中的压感曲线最多可以自由添加10个控制点。如果觉得力度反馈不太合适，可以按照自己的下笔习惯来调整。';

  @override
  String get tipsExportFormatTitle => '根据用途选择导出格式';

  @override
  String get tipsExportFormatDesc =>
      '想轻松发到社交平台时用GIF导出，想叠加到其他视频上或保留透明背景时用透明WebM，想作为普通视频使用时用MP4导出。按用途区分使用，更容易在文件大小和画质之间取得平衡。';

  @override
  String get tipsGestureShortcutTitle => '用手势把常用操作变成一触即达';

  @override
  String get tipsGestureShortcutDesc =>
      '在设置画面的“手势”中，可以把撤销/重做或取色器分配给双指点击、三指点击或长按。不用切换工具，就不会打乱作画的节奏。';

  @override
  String get tipsAudioRepeatTitle => '用复制片段×淡入淡出让音效更有节奏感';

  @override
  String get tipsAudioRepeatDesc =>
      '想反复使用同一段音效时，复制片段并错开时间排列，再分别设置淡入淡出，就能做出有节奏感的自然音效连击。';

  @override
  String get tipsVerticalRubyTitle => '直书×注音打造标题Logo风效果';

  @override
  String get tipsVerticalRubyDesc =>
      '在文字工具中把直书和注音（振假名）组合使用，可以做出和风标题Logo或有个性的标题效果。半角英数字会自动横向旋转排列，即使混入符号或数字也能保持易读。';

  @override
  String get tipsBrushTrySaveTreeTitle => '新的笔刷设置先用保存树试试看';

  @override
  String get tipsBrushTrySaveTreeDesc =>
      '想大幅改动笔刷粗细或稳定化等设置时，改动前先保存到保存树会更安心。如果效果不满意，可以立刻回到之前的状态，更容易大胆尝试各种调整。';

  @override
  String get tipsEyedropperGestureTitle => '把取色器绑定到双指点击，保持配色不跑偏';

  @override
  String get tipsEyedropperGestureDesc =>
      '在手势设置中把取色器分配给双指点击，就能不切换工具、立即吸取附近的颜色。想保持角色配色统一地继续上色时很方便。';

  @override
  String get tipsRulerOnionTitle => '透视尺×洋葱皮，重复利用背景';

  @override
  String get tipsRulerOnionDesc =>
      '先用透视尺定好背景的纵深，再一边用洋葱皮透视前后帧，一边只移动角色，就不用每一帧都重新画背景了。';

  @override
  String get tipsGradientTraceTitle => '渐变自动上色×色彩描摹，让色彩更自然融合';

  @override
  String get tipsGradientTraceDesc =>
      '在自动上色设置中使用渐变时，将线稿颜色设置为色彩描边（贴合线稿），线稿颜色就会随渐变的细微色彩变化而变化，使边界不易显得突兀。';

  @override
  String get tipsGradientOutlineHairTitle => '渐变×指定颜色描边，让刘海呈现透明感';

  @override
  String get tipsGradientOutlineHairDesc =>
      '在自动上色设置中创建刘海部件，将填充色设为渐变，选择发色和透明色这两种颜色。将角度改为90度，按喜好调整羽化强度和颜色切换位置后，勾选「用指定颜色描边」，并从「最近使用的颜色」中选择与刚才刘海相同的颜色作为描边色。不仅刘海的底色部件，阴影色部件也重复同样的步骤，就能做出发梢透亮的透明感头发。';

  @override
  String get tipsRainNoiseTitle => '下雨×动态噪点，营造湿润的空气感';

  @override
  String get tipsRainNoiseDesc =>
      '在下雨滤镜上叠加较弱的动态噪点滤镜，除了雨滴本身，还能加上空气中的颗粒感，营造出湿润的雨天质感。';

  @override
  String get tipsPartKeyframeGroupTitle => '部件关键帧×分组，让角色一起跳动';

  @override
  String get tipsPartKeyframeGroupDesc =>
      '给自动上色的各个部件加上图层关键帧使其运动，再把相关部件分组让它们一起跳动，无需重新绘制就能做出随音乐摇摆的迷你动画。';

  @override
  String get tipsLowSpecSettingsTitle => '低性能设备请重新检查性能设置和撤销次数';

  @override
  String get tipsLowSpecSettingsDesc =>
      '如果感觉运行卡顿，可以把性能设置切换为「低画质」预设，同时减少撤销次数。这样能降低内存占用，有时能让运行更轻快。';

  @override
  String get tipsSeriesPresetFolderTitle => '系列作品用自动上色设置筛选×文件夹整理来管理';

  @override
  String get tipsSeriesPresetFolderDesc =>
      '制作同一作品的多集时，用文件夹按集数归类项目，并为每个项目筛选要使用的自动上色设置，这样就不会混淆各角色的配色，工作效率也更高。';

  @override
  String get tipsPixelToneRetroTitle => '印章像素模式×网点上色，统一复古感';

  @override
  String get tipsPixelToneRetroDesc =>
      '把像素模式的印章和像素模式专用的方格纹、格子纹网点组合使用，可以让整个画面统一呈现像素画质感。适合复古游戏风的演出。';

  @override
  String get tipsMagicWandLassoTitle => '魔术棒选取×套索上色，提高分色效率';

  @override
  String get tipsMagicWandLassoDesc =>
      '先用选择工具的自动选取（魔术棒）一次性选中大致范围，再用套索选取只调整超出的部分，即使是复杂的分色也能快速完成。';

  @override
  String get tipsCommonLayerFolderTitle => '共同图层×文件夹，跨集数重复使用';

  @override
  String get tipsCommonLayerFolderDesc =>
      '系列作品中每集都会用到的Logo或字幕，做成共同图层后整理进文件夹，复制到新一集的项目时也能轻松处理。';

  @override
  String get tipsStrokeDecayFadeTitle => '笔触衰减×淡出，做出毛笔般的表现';

  @override
  String get tipsStrokeDecayFadeDesc =>
      '同时启用笔刷设置中的笔触衰减和淡出，线条的起笔、收笔会自然变细，画出如毛笔或墨水笔般富有轻重变化的线条。';

  @override
  String get tipsColorMixingFadeTitle => '混色×淡出，做出类似颜料的融合感';

  @override
  String get tipsColorMixingFadeDesc =>
      '在开启混色的笔刷上再加上淡出，会与底色融合的同时逐渐变淡，更接近真实颜料的上色手感。';

  @override
  String get tipsOutlineAnimeStyleTitle => '描边×动画风，做出赛璐璐动画质感';

  @override
  String get tipsOutlineAnimeStyleDesc =>
      '用绘图滤镜的描边把轮廓线画到新图层上，再用动画风滤镜减少色数，就能做出赛璐璐动画般清晰利落的效果。';

  @override
  String get tipsLevelsToneCurveTitle => '色阶×色调曲线，打造平面设计风格';

  @override
  String get tipsLevelsToneCurveDesc =>
      '先用色阶把明暗对比调得较强，再用色调曲线细致调整层次，可以做出脱离照片式层次感、类似海报的平面设计风格。';

  @override
  String get tipsMosaicChromaticTitle => '马赛克×色差，营造老式显像管的粗糙质感';

  @override
  String get tipsMosaicChromaticDesc =>
      '先用马赛克降低分辨率，再叠加色差效果，能营造出像在看老式显像管电视般的粗糙质感，与单独使用显像管滤镜的效果又有所不同。';

  @override
  String get tipsEndCardWatermarkTitle => '水印是你的签名，片尾卡是另一回事';

  @override
  String get tipsEndCardWatermarkDesc =>
      '想在视频中加入自己的签名或标记时，请使用水印功能。片尾卡是应用自动显示在每个视频结尾的自带Logo，免费会员无法更改；高级会员可以隐藏它，或替换成自己的视频、图片。如果不想使用片尾卡而想自制专属的结尾效果，只需添加图片图层并配合淡入淡出，就能自行还原类似的效果。';

  @override
  String get tipsVerticalPixelFontTitle => '实拍视频×手绘作画，打造「实拍×动画」';

  @override
  String get tipsVerticalPixelFontDesc =>
      '正因为这款应用兼具插画App和视频剪辑App的双重身份，才能玩出这种手法。把实拍视频片段放到时间轴上，在其上方图层用洋葱皮一边参考一边手绘特效线或角色，就能做出实拍画面叠加手绘动画的「实拍×动画」混合媒体视频。';

  @override
  String get tipsTimelineMarkerTitle => '对齐声音与口型的时间点，交给时间戳';

  @override
  String get tipsTimelineMarkerDesc =>
      '场景处理的是「开始～结束帧的范围」，而时间戳则是为「那一瞬间」加上备注、并可一键跳转的功能。像「第120帧配音效」「第180帧对口型『啊』」这样，在同一个场景范围内打上多个时间戳，就能大幅提升声音与画面对齐的效率。';

  @override
  String get tipsCommunityYoutubeTitle => '投稿到作品广场需要通过YouTube';

  @override
  String get tipsCommunityYoutubeDesc =>
      '投稿到作品广场后，作品将通过YouTube公开。NIARIM不具备将视频文件本体发送、收集或保存到开发者服务器的功能。如果在YouTube一侧将视频设置为“不公开列出”，该视频就不会出现在YouTube的公开列表中，只会显示在作品广场内。';

  @override
  String get tipsToolbarCustomizeTitle => '重新排列・隐藏工具栏，缩短手指移动距离';

  @override
  String get tipsToolbarCustomizeDesc =>
      '在设置画面的工具栏编辑中，可以隐藏不用的工具，把常用工具排到手指容易点到的位置。只是精简显示项目、让界面更清爽，就能减少寻找工具的时间和手指移动距离，提升作画节奏。';

  @override
  String get tipsAutofillBlendModeTitle => '用自动上色部位的混合模式改变阴影质感';

  @override
  String get tipsAutofillBlendModeDesc =>
      '自动上色设置的每个部位都可以设置混合模式。将阴影部位设为「叠加」或「柔光」而不是「正片叠底」，可以做出仿佛透光般的柔和阴影。即使颜色相同，也能改变质感，这是一个隐藏的自由度。';

  @override
  String get tipsStampBlendModeTitle => '印章×混合模式，做出发光特效';

  @override
  String get tipsStampBlendModeDesc =>
      '把放置的印章图层的混合模式设为「滤色」或「相加」，光效线条或闪亮特效就能自然融入背景，显得更加突出。';

  @override
  String get tipsQuickToolPenSubTitle => '快捷工具×画笔子工具，打造不间断的作业流程';

  @override
  String get tipsQuickToolPenSubDesc =>
      '把常用工具登记到快捷工具，同时善用长按画笔即可切换到网点填充、印章放置的子工具，就能减少画面间的来回切换，保持作业节奏。';

  @override
  String get tipsAutofillToneReuseTitle => '利用自动上色的网点设置，只需重画线稿就能重现上色';

  @override
  String get tipsAutofillToneReuseDesc =>
      '将自动上色设置的每个部位设为「使用网点」，每次重新绘制线稿时都能自动重现含网点的上色效果，省去逐帧重新贴网点的麻烦。';

  @override
  String get tipsAutofillMisfillTitle => '了解自动上色的原理就能减少涂错';

  @override
  String get tipsAutofillMisfillDesc =>
      '自动上色并非使用生成式AI的功能，而是逐图层油漆桶填充的应用。因此，当同一个部位内部存在被线条围住的空隙（例如长发内侧）时，那里也会一起被填满。建议的对策是：先为每个部位指定一个高饱和度的醒目颜色填一遍。这样涂错的地方一眼就能看出来，便于手动修正自动上色图层；修正之后再设回原本的颜色，以覆盖的方式重新执行自动上色，涂错就会大幅减少。';

  @override
  String get tipsAutofillTransparentFixTitle => '自动上色溢出的部分用透明色油漆桶擦掉';

  @override
  String get tipsAutofillTransparentFixDesc =>
      '当自动上色填到了不该填的地方时，比起用橡皮反复擦，把绘图色设为透明色再对该范围使用油漆桶更为简便。油漆桶会一次性处理被线条围住的整个区域，因此轻点一下就能干净地只清除溢出的部分。';

  @override
  String get tipsRadialVignetteTitle => '放射尺×暗角，营造集中线效果';

  @override
  String get tipsRadialVignetteDesc =>
      '用放射尺一口气画出集中线，再叠加绘图滤镜的暗角效果，就能做出如漫画高潮般有魄力的演出。';

  @override
  String get tipsClippingGradientTitle => '剪裁×渐变，让阴影可以随时重画';

  @override
  String get tipsClippingGradientDesc =>
      '把渐变图层剪裁到角色图层上，之后只需改变渐变的范围和角度就能重新调整阴影，不必用笔刷重新描绘阴影形状。';

  @override
  String get tipsToneCurveSepiaTitle => '色调曲线×怀旧棕，营造复古照片感';

  @override
  String get tipsToneCurveSepiaDesc =>
      '先用演出滤镜的色调曲线调整明暗对比，再叠加怀旧棕滤镜，就能营造出仿佛褪色老照片般的质感。';

  @override
  String get tipsCameraLensBlurTitle => '摄像机关键帧×镜头模糊，做出变焦拉伸效果';

  @override
  String get tipsCameraLensBlurDesc =>
      '在摄像机关键帧推近的瞬间，临时把镜头模糊演出滤镜调强，就能演绎出如实拍变焦拉伸般的魄力。';

  @override
  String get tipsBlurVignetteBgTitle => '高斯模糊×暗角，做出柔和的背景虚化';

  @override
  String get tipsBlurVignetteBgDesc =>
      '只对背景图层叠加高斯模糊和暗角绘图滤镜，主角就会自然地更加突出，呈现出具有景深感的镜头效果。';

  @override
  String get tipsSepiaVignetteTitle => '怀旧棕×暗角，打造复古老照片风视频';

  @override
  String get tipsSepiaVignetteDesc =>
      '把演出滤镜的怀旧棕与绘图滤镜的暗角组合使用，能让视频呈现出四角发暗、色彩褪去的复古老照片氛围。';

  @override
  String get tipsVideoTrimReuseTitle => '改变视频片段的使用范围，重复利用同一素材';

  @override
  String get tipsVideoTrimReuseDesc =>
      '即使是同一个视频素材，只要为每个片段设置不同的使用开始・结束帧，就能当作不同的镜头重复使用。不用增加素材也能做出变化。';

  @override
  String get tipsSaveSlotAutoSaveTitle => '区分使用存档槽和自动保存';

  @override
  String get tipsSaveSlotAutoSaveDesc =>
      '自动保存总是覆盖为最新状态，而存档槽可以保留多个状态。在重要节点保存到存档槽，其余的细微改动就交给自动保存，这样就能可靠地回到需要的时间点。';

  @override
  String get tipsQuickToolSwipeTitle => '快捷工具可以用上滑手势重新排序';

  @override
  String get tipsQuickToolSwipeDesc =>
      '想更改快捷工具的登记内容时，除了长按，也可以用向上滑动打开管理弹窗。单手操作时想快速重新排序会很方便。';

  @override
  String get tipsDrawingAreaCameraTitle => '作画区域留宽×摄像机关键帧，安全地推拉与平移';

  @override
  String get tipsDrawingAreaCameraDesc =>
      '把作画区域设置得比导出范围更宽，就不用担心用摄像机关键帧做平移、缩放时画面边缘被裁切。在加入较大幅度的运镜之前先确认一下会比较放心。';

  @override
  String get tipsWebmCommonLayerTitle => '透明WebM×用共同图层分开管理背景';

  @override
  String get tipsWebmCommonLayerDesc =>
      '如果打算把导出为透明WebM的角色，在其他视频剪辑软件中与背景合成，把背景用共同图层单独管理，可以避免多余颜色混进透明部分，让抠像效果更干净。';

  @override
  String get tipsLeftHandedWorkspaceTitle => '左手模式×工作区设置，让操作更顺手';

  @override
  String get tipsLeftHandedWorkspaceDesc =>
      '如果是左撇子，打开工作区设置中的左手模式后，停靠面板会左右翻转，慣用手一侧的画面就不容易被面板遮住。';

  @override
  String get tipsTransferDeviceTitle => '用转移文件把制作内容搬到其他设备';

  @override
  String get tipsTransferDeviceDesc =>
      '想换设备也保持相同环境继续绘制时，使用转移（.niatra）功能，可以把设置、笔刷、色调、印章、调色板等环境一起搬过去。如果想传递正在制作的项目本身，请改用「共享（.niashare）」。';

  @override
  String get fontSettingsTabDownloaded => '已下载';

  @override
  String get fontSettingsTabSearch => '搜索下载';

  @override
  String get fontSettingsTabImport => '导入';

  @override
  String get fontDownloadedSearchHint => '按字体名称搜索...';

  @override
  String get fontPixelModeTooltip => '像素模式（适用于点阵字体，无抗锯齿清晰显示）';

  @override
  String get fontEmptyTitle => '没有字体';

  @override
  String get fontEmptyHint => '可从「搜索下载」或「导入」标签页添加';

  @override
  String get fontRenameDialogTitle => '更改字体名称';

  @override
  String get fontImportTitle => '导入设备中已保存的字体';

  @override
  String get fontImportFormats => '支持格式：TTF / OTF';

  @override
  String get fontSelectFileButton => '选择文件';

  @override
  String get fontUnsupportedSnackbar => '无法读取该字体。';

  @override
  String fontAddedSnackbar(String name) {
    return '已添加“$name”（显示在已下载标签页）';
  }

  @override
  String get fontCorruptedSnackbar => '字体已损坏。';

  @override
  String get licenseScreenTitle => '使用条款・许可';

  @override
  String get licenseSectionTerms => '使用条款';

  @override
  String get licenseSectionFonts => '关于所用字体';

  @override
  String get licenseSectionOss => '开源软件许可';

  @override
  String get licenseOssListTitle => '所用库的许可列表';

  @override
  String get licenseOssListSubtitle => '显示本应用所使用的OSS软件包的许可信息';

  @override
  String get licenseFfmpegNote =>
      'WebM、AVI导出使用了FFmpeg（LGPL 3.0，通过ffmpeg_kit_flutter_new_video调用）。修改版源代码获取地址：https://github.com/sk3llo/ffmpeg_kit_flutter\nMP4导出直接使用设备内置的硬件编码器，未使用FFmpeg。';

  @override
  String licenseFontCreditMeta(String author, String license) {
    return '作者：$author　许可：$license';
  }

  @override
  String get toolbarPenTooltip => '笔（长按打开子工具）';

  @override
  String get toolbarPenFirstUseTip => '长按笔工具，可切换画笔・网点・图章・套索填色。';

  @override
  String get toolbarBucketTooltip => '填充桶（长按切换纯色/网点填充）';

  @override
  String get toolbarBucketFirstUseTip => '长按填充桶，可在纯色填充和网点填充之间切换。';

  @override
  String get toolbarSelectTooltip => '选择（长按变更类型）';

  @override
  String get toolbarShapeTooltip => '图形（点击选择种类）';

  @override
  String get toolbarTextFirstUseTip => '可自由放置文字，也能更改字体、颜色和描边。';

  @override
  String get toolbarQuickToolFirstUseTip => '点击可依次切换已注册的工具。长按或向上滑动可编辑已注册的内容。';

  @override
  String get firstUseTipOperationGuideTitle => '基本操作';

  @override
  String get firstUseTipOperationGuideBody =>
      '单击工具栏图标即可切换到该工具。长按同一图标或向上滑动，可打开该工具的详细设置（笔刷种类、填充方式、选择方式等）。双击图标会显示该工具的简短说明。关闭之后，也可以从各画面右上角的「?」按钮在帮助中重新阅读。';

  @override
  String get helpBasicGestureTitle => '基本操作（点击・长按・上滑）';

  @override
  String get helpBasicGestureDesc =>
      '单击工具栏图标即可切换到该工具。长按同一图标或向上滑动，可打开详细设置。钢笔可切换笔刷・网点・图章・套索填充，油漆桶可切换纯色填充与网点填充，选择工具可切换矩形・套索・自动选择，手指工具可切换模糊与马赛克，快速切换工具可编辑已登记的内容，这些都在长按或上滑之后。双击图标时，画面下方会显示该工具的简短说明。\\n在画布上，双指捏合可缩放，双指拖动可平移，双指点击撤销，三指点击重做。双击画面左右边缘可移动到前后一帧。\\n连接鼠标或数位板时，可用滚轮缩放、按住中键拖动平移。';

  @override
  String get toolbarStampColorLockedSnackbar => '图章保留了自身的颜色信息，因此无法更改颜色';

  @override
  String get toolbarBrushSettingsTooltip => '画笔设置';

  @override
  String get toolbarLayerTooltip => '图层';

  @override
  String get toolbarQuickToolTooltip => '快捷工具（长按/向上滑动可编辑）';

  @override
  String get toolbarSaveTooltip => '保存（存档树）';

  @override
  String get toolbarBucketFlatFill => '纯色填充';

  @override
  String get toolbarBucketToneListLabel => '网点列表';

  @override
  String get toolbarSelectRect => '矩形选择';

  @override
  String get toolbarSelectLasso => '套索选择';

  @override
  String get toolbarSelectMagicWand => '自动选择（魔术棒）';

  @override
  String get creativePanelFavoritesOnlyTooltip => '仅显示收藏';

  @override
  String get creativePanelSearchTooltip => '按名称搜索';

  @override
  String get creativePanelSearchModeKeyword => '正在按关键词搜索（点按切换到标签搜索）';

  @override
  String get creativePanelSearchModeTag => '正在按标签搜索（点按切换到关键词搜索）';

  @override
  String get creativePanelTagSearchHint => '按标签搜索';

  @override
  String get creativePanelTagNoneYet => '还没有标签，可在编辑界面添加';

  @override
  String get creativePanelTagsLabel => '标签';

  @override
  String get creativePanelTagsHint => '用逗号或空格分隔输入';

  @override
  String get creativePanelTagClearFilter => '清除标签筛选';

  @override
  String get widgetSettingsTitle => '主屏幕小组件';

  @override
  String get widgetSettingsDescription =>
      '可在手机主屏幕放置三种小组件：所选作品的一帧画面、「创作作品」和「作品广场」。添加小组件请长按主屏幕。';

  @override
  String get widgetSettingsSubtitle => '要显示的作品、小组件颜色';

  @override
  String get widgetArtworkSection => '要显示的作品';

  @override
  String get widgetSectionArtwork => '启动页小组件';

  @override
  String get widgetSectionArtworkDesc => '显示所选作品的一帧画面。点按即可打开 NIARIM。';

  @override
  String get widgetSectionCreate => '创作作品小组件';

  @override
  String get widgetSectionCreateDesc => '点按即可打开“创作作品”页面。';

  @override
  String get widgetSectionPlaza => '作品广场小组件';

  @override
  String get widgetSectionPlazaDesc => '点按即可打开“作品广场”。';

  @override
  String get widgetArtworkNone => '尚未选择作品';

  @override
  String get widgetColorFollowTheme => '跟随应用主题';

  @override
  String get widgetColorCustom => '选择颜色';

  @override
  String get widgetNoProjects => '还没有作品。创作后即可在这里选择。';

  @override
  String get widgetSettingsNote => '主屏幕小组件无法播放视频，因此以静止图像显示所选作品的一帧。';

  @override
  String get assetTagLineArt => '线稿';

  @override
  String get assetTagBasic => '基础';

  @override
  String get assetTagMainLine => '主线';

  @override
  String get assetTagPaint => '上色';

  @override
  String get assetTagBlur => '模糊';

  @override
  String get assetTagMixing => '混色';

  @override
  String get assetTagAnalog => '仿手绘';

  @override
  String get assetTagDecoration => '装饰';

  @override
  String get assetTagRough => '草稿';

  @override
  String get assetTagEffect => '效果';

  @override
  String get assetTagTaper => '起收笔';

  @override
  String get assetTagPixelArt => '像素画';

  @override
  String get assetTagHalftone => '网点';

  @override
  String get assetTagShadow => '阴影';

  @override
  String get assetTagLine => '线条';

  @override
  String get assetTagGradient => '渐变';

  @override
  String get assetTagTexture => '质感';

  @override
  String get assetTagClothing => '服装';

  @override
  String get assetTagMesh => '网眼';

  @override
  String get assetTagBackground => '背景';

  @override
  String get assetTagPattern => '图案';

  @override
  String get assetTagShape => '图形';

  @override
  String get assetTagSymbol => '符号';

  @override
  String get assetTagManga => '漫画';

  @override
  String get creativePanelFolderButton => '文件夹';

  @override
  String get creativePanelCreateButton => '自制';

  @override
  String get creativePanelImportButton => '导入';

  @override
  String get creativePanelFolderAllChip => '全部';

  @override
  String get creativePanelEditAction => '编辑';

  @override
  String get toneTitle => '网点';

  @override
  String get toneEmpty => '没有网点';

  @override
  String get toneSearchHint => '按网点名称搜索';

  @override
  String get toneEditTitle => '编辑网点';

  @override
  String get toneChangeTextureButton => '更改纹理图片';

  @override
  String get toneCreateDialogTitle => '自制网点';

  @override
  String toneImportFailedSnackbar(String error) {
    return '网点读取失败：$error';
  }

  @override
  String toneExportFailedSnackbar(String error) {
    return '网点导出失败：$error';
  }

  @override
  String get privacyPolicyScreenTitle => '隐私政策';

  @override
  String get stampTitle => '图章';

  @override
  String get stampSearchHint => '按图章名称搜索';

  @override
  String get stampEmpty => '没有图章';

  @override
  String get stampCreateDialogTitle => '自制图章';

  @override
  String stampImportFailedSnackbar(String error) {
    return '图章读取失败：$error';
  }

  @override
  String stampExportFailedSnackbar(String error) {
    return '图章导出失败：$error';
  }

  @override
  String get stampEditTitle => '编辑图章';

  @override
  String get stampRotationLabel => '旋转';

  @override
  String get stampPixelModeLabel => '像素模式';

  @override
  String get stampPixelModeHint => '以像素画风格（马赛克＋减少颜色数）绘制';

  @override
  String get stampDensityLabel => '密度';

  @override
  String get stampScatterLabel => '散布';

  @override
  String get stampChangeImageButton => '更改图章图片';

  @override
  String get themeSettingsTitle => '主题・外观';

  @override
  String get themeColorCustomizeSection => '颜色自定义';

  @override
  String get themeColorAccent => '强调色';

  @override
  String get themeColorText => '文字颜色';

  @override
  String get themeColorPanelBg => '面板背景色';

  @override
  String get themeColorMenuBg => '菜单背景色';

  @override
  String get themeColorSelection => '选中色';

  @override
  String get themeColorUpdateMark => '更新标记颜色';

  @override
  String get themePresetSection => '主题列表';

  @override
  String themePresetDuplicateName(String name) {
    return '$name（副本）';
  }

  @override
  String get themeDuplicateAction => '复制';

  @override
  String get themeExportMenuItem => '导出 (.niatheme)';

  @override
  String themeExportFailedSnackbar(String error) {
    return '导出失败：$error';
  }

  @override
  String get themeImportSuccessSnackbar => '已导入.niatheme文件';

  @override
  String themeImportFailedSnackbar(String error) {
    return '导入失败：$error';
  }

  @override
  String get themeSaveAsNewButton => '将当前设置保存为新主题';

  @override
  String get themeImportButton => '导入.niatheme';

  @override
  String get themePresetNameDialogTitle => '主题名称';

  @override
  String get themeDefaultPresetName => '我的主题';

  @override
  String get onionSkinTitle => '洋葱皮';

  @override
  String get onionSkinPrevFrame => '前一帧';

  @override
  String get onionSkinNextFrame => '后一帧';

  @override
  String get onionSkinFrameInterval => '帧间隔';

  @override
  String get onionSkinFadeByDistance => '越近越深';

  @override
  String get onionSkinColorPickerTitle => '选择颜色';

  @override
  String get onionSkinOnFixed => '开启（固定）';

  @override
  String get onionSkinFrameCount => '显示帧数';

  @override
  String onionSkinFrameCountFixed(int count) {
    return '$count帧（固定）';
  }

  @override
  String get onionSkinColorLabel => '颜色';

  @override
  String get onionSkinOpacityLabel => '不透明度';

  @override
  String get exportScreenTitle => '导出';

  @override
  String get exportPresetSection => '预设';

  @override
  String get exportPresetStandard => '标准';

  @override
  String get exportPresetHighQuality => '高画质';

  @override
  String get exportPresetCustom => '自定义';

  @override
  String get exportAdvancedSettings => '详细设置';

  @override
  String get exportFpsLabel => 'FPS';

  @override
  String get exportFormatSection => '格式';

  @override
  String get exportFormatMp4 => 'MP4';

  @override
  String get exportFormatMp4Subtitle => '通用视频格式';

  @override
  String get exportFormatGif => 'GIF';

  @override
  String get exportFormatGifSubtitle => '动态GIF';

  @override
  String get exportFormatWebmSubtitle => '透明背景视频';

  @override
  String get exportFormatAvi => 'AVI';

  @override
  String get exportFormatAviSubtitle => '兼容性优先的视频格式（不支持透明）';

  @override
  String get exportStartButton => '开始导出';

  @override
  String get exportProjectNotFoundError => '未找到项目';

  @override
  String exportFailedError(String error) {
    return '导出失败：$error';
  }

  @override
  String get exportInProgressTitle => '正在导出';

  @override
  String get exportCancelledSnackbar => '已取消导出';

  @override
  String get exportCancelHint => '正在进行最终处理，完成后将反映取消操作';

  @override
  String get exportOutdatedAutofillTitle => '自动上色不是最新状态';

  @override
  String get exportOutdatedAutofillBody => '存在尚未更新的自动上色图层。要直接导出吗？';

  @override
  String get exportContinueButton => '继续';

  @override
  String get exportDurationExceededTitle => '超出视频时长上限';

  @override
  String exportDurationExceededBody(int max, int current) {
    return '免费版的最大视频时长为$max秒。\n当前项目约为$current秒。\n升级到Premium后最长可达2小时。';
  }

  @override
  String get exportViewPremiumButton => '查看Premium';

  @override
  String get exportContinueAnywayButton => '仍要继续';

  @override
  String get exportCompleteTitle => '导出完成';

  @override
  String exportCompleteFramesBody(int count) {
    return '已完成$count帧的导出。';
  }

  @override
  String exportSaveLocationLabel(String fileName) {
    return '保存位置：应用内（$fileName）';
  }

  @override
  String get exportSaveLocationHint =>
      '如需在设备的「照片」应用或文件管理器中打开，请从下方的「分享」中选择要保存到的应用。';

  @override
  String get exportBackToProjectsButton => '返回项目列表';

  @override
  String get exportBackToCanvasButton => '返回画布';

  @override
  String get newProjectScreenTitle => '新建项目';

  @override
  String get newProjectDefaultName => '新建项目';

  @override
  String get newProjectNameLabel => '项目名称';

  @override
  String get newProjectSizeLabel => '尺寸';

  @override
  String get newProjectPresetFullHd => 'Full HD（16:9・适合YouTube等横版视频）';

  @override
  String get newProjectPresetHd => 'HD（16:9・轻量版）';

  @override
  String get newProjectPresetSquare => '1:1 正方形（适合Twitter/Instagram发布）';

  @override
  String get newProjectPresetVertical =>
      '9:16 竖版（适合YouTube Shorts/Reels/Stories）';

  @override
  String get newProjectPresetPortrait => '4:5 竖长（适合Instagram信息流发布）';

  @override
  String get newProjectPresetAnalog => '4:3（模拟广播比例）';

  @override
  String get newProjectCustomSize => '自定义';

  @override
  String get newProjectMaxEdgeHint => '长边最大可设置为1920px';

  @override
  String get newProjectWidthLabel => '宽度(px)';

  @override
  String get newProjectHeightLabel => '高度(px)';

  @override
  String get newProjectWidthShort => '宽';

  @override
  String get newProjectHeightShort => '高';

  @override
  String get newProjectSizePresetManageButton => '尺寸设置';

  @override
  String get newProjectSaveCustomSizeButton => '保存此尺寸';

  @override
  String get newProjectSaveCustomSizeDialogTitle => '请输入此尺寸的名称';

  @override
  String get newProjectSaveCustomSizeNameLabel => '尺寸名称';

  @override
  String get newProjectSaveCustomSizeSavedSnackbar => '已保存尺寸';

  @override
  String get canvasSizePresetManageScreenTitle => '尺寸设置';

  @override
  String get canvasSizePresetEmpty => '尚无已保存的尺寸';

  @override
  String get canvasSizePresetEmptyHint => '在新建项目画面指定自定义尺寸后，点击「保存此尺寸」即可添加';

  @override
  String get canvasSizePresetEditDialogTitle => '编辑尺寸';

  @override
  String get canvasSizePresetDuplicateSuffix => '副本';

  @override
  String newProjectDurationLabel(String max) {
    return '时长（最大$max）';
  }

  @override
  String newProjectDurationLabelWithPremiumHint(String max) {
    return '时长（最大$max，升级Premium可达最长2小时）';
  }

  @override
  String newProjectDurationSeconds(int n) {
    return '$n秒';
  }

  @override
  String newProjectDurationHms(int h, int m, int s) {
    return '$h小时$m分$s秒';
  }

  @override
  String newProjectDurationHm(int h, int m) {
    return '$h小时$m分';
  }

  @override
  String newProjectDurationH(int h) {
    return '$h小时';
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
  String get newProjectDrawingAreaTitle => '扩大绘图区域';

  @override
  String get newProjectDrawingAreaSubtitle => '添加可在导出范围外绘制的区域';

  @override
  String get newProjectScaleLabel => '倍率';

  @override
  String newProjectScaleValue(String value) {
    return '$value倍';
  }

  @override
  String newProjectDrawableAreaInfo(String width, String scale, String result) {
    return '可绘制范围：$width×$scale = $result';
  }

  @override
  String newProjectTotalFrames(int count) {
    return '总帧数：$count';
  }

  @override
  String newProjectExportSizeInfo(String size) {
    return '导出尺寸：$size';
  }

  @override
  String newProjectDrawingAreaInfo(String size) {
    return '绘图区域：$size';
  }

  @override
  String get colorPickerTitle => '选择颜色';

  @override
  String get colorPickerOpacityLabel => '不透明度';

  @override
  String get colorPickerHexCopiedSnackbar => '已复制HEX值';

  @override
  String get colorPickerRecentColorsLabel => '最近使用的颜色';

  @override
  String get colorPickerRecentColorsEmpty => '暂无记录';

  @override
  String get colorPickerPaletteLabel => '调色盘';

  @override
  String get colorPickerNewPaletteTooltip => '新建调色盘';

  @override
  String get colorPickerManagePaletteTooltip => '调色盘管理';

  @override
  String get colorPickerPaletteEmptyHint => '还没有颜色。点击「＋」可添加当前颜色。';

  @override
  String get colorPickerPaletteLongPressHint => '长按可删除';

  @override
  String get colorPickerAddCurrentColorButton => '将当前颜色添加到调色盘';

  @override
  String get colorPickerPaletteNameLabel => '调色盘名称';

  @override
  String get colorPickerFavoriteAdd => '加入收藏';

  @override
  String get colorPickerFavoriteRemove => '取消收藏';

  @override
  String get penSubToolTabBrush => '画笔';

  @override
  String get penSubToolTabTone => '网点';

  @override
  String get penSubToolTabStamp => '图章';

  @override
  String get penSubToolTabLassoFill => '套索填色';

  @override
  String get penSubToolToneTooltipMessage => '选择网点后，可以用填色桶或画笔涂上网点纹理。';

  @override
  String get penSubToolStampTooltipMessage => '可以放置固定形状的图章。长按可设置旋转、密度等。';

  @override
  String get penSubToolManageTooltip => '管理';

  @override
  String penSubToolBrushSizeOpacity(int size, int opacity) {
    return '${size}px · $opacity%';
  }

  @override
  String get penSubToolStampRotationSubtitle => '根据笔画方向随机旋转';

  @override
  String get brushSearchHint => '按画笔名称搜索';

  @override
  String get brushEmpty => '没有画笔';

  @override
  String get brushCreateDialogTitle => '自制画笔';

  @override
  String brushImportFailedSnackbar(String error) {
    return '画笔读取失败：$error';
  }

  @override
  String brushExportFailedSnackbar(String error) {
    return '画笔导出失败：$error';
  }

  @override
  String get brushSettingsSizeLabel => '大小';

  @override
  String get brushSettingsOpacityLabel => '不透明度';

  @override
  String get brushSettingsSpacingLabel => '间距';

  @override
  String get brushSettingsBlurRadiusLabel => '模糊半径';

  @override
  String get brushSettingsStabilizationTitle => '防抖';

  @override
  String get brushSettingsStabilizationStrengthLabel => '防抖强度';

  @override
  String get brushSettingsPixelModeTitle => '像素模式';

  @override
  String get brushSettingsPressureModeTitle => '笔压设置';

  @override
  String get brushSettingsPressureOff => '无效';

  @override
  String get brushSettingsPressureSize => '反映到大小';

  @override
  String get brushSettingsPressureOpacity => '反映到不透明度';

  @override
  String get brushSettingsPressureSizeAndOpacity => '反映到大小＋不透明度';

  @override
  String get brushSettingsFadeModeTitle => '淡出';

  @override
  String get brushSettingsFadeOff => 'OFF';

  @override
  String get brushSettingsFadeWeak => '弱';

  @override
  String get brushSettingsFadeMedium => '中';

  @override
  String get brushSettingsFadeStrong => '强';

  @override
  String get brushSettingsFadeCustom => '自定义';

  @override
  String get brushSettingsFadeStartValueLabel => '起始值(%)';

  @override
  String get brushSettingsFadeEndValueLabel => '结束值(%)';

  @override
  String get brushSettingsFadeDistanceLabel => '距离(px)';

  @override
  String get brushSettingsStrokeDecayTitle => '笔画衰减';

  @override
  String get brushSettingsStrokeDecaySubtitle => '持续绘制不透明度会降低';

  @override
  String get brushSettingsMixingTitle => '混色';

  @override
  String get brushSettingsMixingOff => 'OFF';

  @override
  String get brushSettingsMixingSimple => '简易混色';

  @override
  String get brushSettingsMixingBleed => '晕染';

  @override
  String get brushSettingsMixingRateLabel => '混色率';

  @override
  String get projectDetailNotFoundTitle => '项目';

  @override
  String get projectDetailNotFoundBody => '找不到项目';

  @override
  String get projectDetailFirstFrameTooltip => '第一帧';

  @override
  String get projectDetailPrevFrameTooltip => '后退1帧';

  @override
  String get projectDetailPauseTooltip => '暂停';

  @override
  String get projectDetailPlayTooltip => '播放';

  @override
  String get projectDetailNextFrameTooltip => '前进1帧';

  @override
  String get projectDetailLastFrameTooltip => '最后一帧';

  @override
  String get projectDetailFullscreenTooltip => '全屏显示预览';

  @override
  String get projectDetailFullscreenCloseTooltip => '关闭全屏预览';

  @override
  String get projectDetailStartEditButton => '开始编辑';

  @override
  String get projectDetailTagsQuickAction => '标签';

  @override
  String get projectDetailShareQuickAction => '分享';

  @override
  String get projectDetailInfoSectionTitle => '项目信息';

  @override
  String get projectDetailInfoExportSize => '导出尺寸';

  @override
  String get projectDetailInfoDrawingArea => '绘图区域';

  @override
  String projectDetailInfoDrawingAreaValue(String size, String scale) {
    return '$size  ($scale)';
  }

  @override
  String get projectDetailInfoTotalFrames => '总帧数';

  @override
  String get projectDetailInfoWorkTime => '制作时间';

  @override
  String get projectDetailInfoLastSaved => '最近保存';

  @override
  String get projectDetailInfoSize => '容量';

  @override
  String get projectDetailAddTagHint => '添加标签';

  @override
  String projectDetailNiashareFailedSnackbar(String error) {
    return '.niashare创建失败：$error';
  }

  @override
  String get projectDetailTrashMenuItem => '移到回收站';

  @override
  String get commonOff => 'OFF';

  @override
  String get perfSettingsScreenTitle => '性能设置';

  @override
  String get perfSettingsQualitySection => '画质设置';

  @override
  String get perfSettingsQualityLow => '低画质';

  @override
  String get perfSettingsQualityMedium => '中画质';

  @override
  String get perfSettingsQualityHigh => '高画质';

  @override
  String get perfSettingsQualityCustom => '自定义';

  @override
  String get perfSettingsQualityDescLow => '适合想要更轻量运行的设备（前后各1张洋葱皮・5个存储槽）';

  @override
  String get perfSettingsQualityDescMedium => '适合一般设备（前后各3张洋葱皮・10个存储槽）';

  @override
  String get perfSettingsQualityDescHigh => '适合性能有余裕的设备（前后各5张洋葱皮・树状存档）';

  @override
  String get perfSettingsQualityDescCustom => '分别设置各项目';

  @override
  String get perfSettingsCapacitySection => '容量与运行相关设置';

  @override
  String get perfSettingsUndoLimitTitle => '撤销次数';

  @override
  String get perfSettingsUndoLimitSubtitle => '次数越多越消耗内存';

  @override
  String perfSettingsUndoLimitValue(int n) {
    return '$n次';
  }

  @override
  String get perfSettingsTrashAutoDeleteTitle => '回收站自动删除';

  @override
  String get perfSettingsTrashAutoDeleteSubtitle => '已删除项目的保留期限';

  @override
  String perfSettingsTrashAutoDeleteValue(int n) {
    return '$n天';
  }

  @override
  String get perfSettingsCurrentSettingsSection => '当前设置';

  @override
  String get perfSettingsTiltLabel => '倾斜检测';

  @override
  String get perfSettingsOnionPrevLabel => '洋葱皮（前）';

  @override
  String get perfSettingsOnionNextLabel => '洋葱皮（后）';

  @override
  String perfSettingsOnionFrameCountValue(int n) {
    return '$n张';
  }

  @override
  String get perfSettingsSaveModeLabel => '存档方式';

  @override
  String get perfSettingsSlotCountLabel => '存储槽数量';

  @override
  String perfSettingsSlotCountValue(int n) {
    return '$n个';
  }

  @override
  String get perfSettingsResetButton => '恢复初始值';

  @override
  String get perfSettingsCopyPresetButton => '复制当前预设';

  @override
  String get perfSettingsTiltSwitchTitle => '将笔的倾斜反映到画笔';

  @override
  String get perfSettingsShowPrevOnionTitle => '显示前一帧';

  @override
  String get perfSettingsOnionCountPrevLabel => '洋葱皮张数（前）';

  @override
  String get perfSettingsShowNextOnionTitle => '显示后一帧';

  @override
  String get perfSettingsOnionCountNextLabel => '洋葱皮张数（后）';

  @override
  String get perfSettingsSaveModeSlot => '存储槽方式';

  @override
  String get perfSettingsSaveModeTree => '树状方式';

  @override
  String get perfSettingsResetDialogTitle => '要将自定义画质设置恢复为初始值吗？';

  @override
  String perfSettingsResetDialogBody(String preset) {
    return '初始值将恢复为首次启动时根据设备性能自动判定的「$preset」设置。';
  }

  @override
  String get perfSettingsResetConfirmButton => '恢复';

  @override
  String get perfSettingsCopyPresetDialogTitle => '选择要复制的预设';

  @override
  String get perfSettingsCopyPresetDialogBody => '请选择要复制到自定义设置的预设。';

  @override
  String get perfSettingsCopyDescLow => '前后各显示1张・轻量运行';

  @override
  String get perfSettingsCopyDescMedium => '前后各显示3张・标准';

  @override
  String get perfSettingsCopyDescHigh => '前后各显示5张・高画质';

  @override
  String get filterPanelTitle => '滤镜';

  @override
  String filterPanelTitleBulk(int count) {
    return '滤镜（批量应用到$count帧）';
  }

  @override
  String get filterSearchHint => '搜索滤镜';

  @override
  String get filterNameGaussianBlur => '高斯模糊';

  @override
  String get filterNameLensBlur => '镜头模糊';

  @override
  String get filterNameAnimeStyle => '动漫风格';

  @override
  String get filterNameOutline => '描边';

  @override
  String get filterNameToneCurve => '色调曲线';

  @override
  String get filterNameLevels => '色阶';

  @override
  String get filterNameSharpen => '锐化';

  @override
  String get filterNameUnsharpMask => 'USM锐化';

  @override
  String get filterSharpenStrength => '锐化强度';

  @override
  String get filterUnsharpAmount => '强度';

  @override
  String get filterNameVignette => '暗角';

  @override
  String get filterVignetteStrength => '暗角强度';

  @override
  String get filterVignetteColor => '暗角颜色';

  @override
  String get filterNameNoise => '胶片颗粒';

  @override
  String get filterNoiseStrength => '颗粒强度';

  @override
  String get filterNameRetroAnime => '复古动漫';

  @override
  String get filterNameCrt => '老电视';

  @override
  String get filterRetroStrength => '强度';

  @override
  String filterOutlineLayerNameSuffix(String name) {
    return '$name（描边）';
  }

  @override
  String get filterStrengthBlurRadius => '强度（模糊半径）';

  @override
  String get filterColorLevels => '颜色数';

  @override
  String get filterEdgeStrength => '边缘强调';

  @override
  String get filterOutlineColor => '描边颜色';

  @override
  String get filterOutlineWidth => '描边宽度';

  @override
  String get filterToneCurveLinear => '标准';

  @override
  String get filterToneCurveBrighten => '变亮';

  @override
  String get filterToneCurveDarken => '变暗';

  @override
  String get filterToneCurveHighContrast => '高对比度';

  @override
  String get filterToneCurveLowContrast => '低对比度';

  @override
  String get filterToneCurveInvert => '反转';

  @override
  String get filterLevelsInputBlack => '输入：黑';

  @override
  String get filterLevelsInputWhite => '输入：白';

  @override
  String get filterLevelsOutputBlack => '输出：黑';

  @override
  String get filterLevelsOutputWhite => '输出：白';

  @override
  String get filterApplyButton => '应用';

  @override
  String filterApplyBulkButton(int count) {
    return '应用到$count帧';
  }

  @override
  String get filterEmpty => '没有滤镜';

  @override
  String get filterApplyingTitle => '正在应用滤镜';

  @override
  String filterApplyingSubtitle(String name, int count) {
    return '$name　$count帧';
  }

  @override
  String get projectListNewFolderTitle => '新建文件夹';

  @override
  String get projectListFolderHint => '也可用于整理同一作品的多话内容或系列作品';

  @override
  String get projectListEmptyTitle => '没有项目';

  @override
  String get projectListEmptyHint => '点击「＋」新建';

  @override
  String get projectListOpenAction => '打开';

  @override
  String get projectListCreateShareAction => '创建.niashare';

  @override
  String get projectListEditFolderAction => '编辑名称与颜色';

  @override
  String get projectListDeleteFolderConfirmTitle => '要删除此文件夹吗？';

  @override
  String projectListDeleteFolderConfirmBody(String name) {
    return '将删除「$name」。其中的项目・子文件夹将移至根目录。';
  }

  @override
  String get projectListFolderRootOption => '无文件夹（根目录）';

  @override
  String get projectListEditFolderTooltip => '编辑文件夹';

  @override
  String get projectListCreateFolderAction => '新建文件夹';

  @override
  String get projectListFolderColorLabel => '文件夹颜色';

  @override
  String get projectListMaterialIncludeTitle => '包含素材';

  @override
  String get projectListMaterialIncludeHint => '若不包含，接收方将看到缺少素材的警告。';

  @override
  String get projectListMaterialImage => '图片';

  @override
  String get projectListMaterialVideo => '视频';

  @override
  String get projectListMaterialAudio => '音频';

  @override
  String get projectListIncludeFontsTitle => '包含字体';

  @override
  String get projectListIncludeFontsSubtitle => '包含正在使用的用户添加字体';

  @override
  String get blendModeNormal => '正常';

  @override
  String get blendModeMultiply => '正片叠底';

  @override
  String get blendModeScreen => '滤色';

  @override
  String get blendModeOverlay => '叠加';

  @override
  String get blendModeAddition => '添加';

  @override
  String get blendModeSubtract => '减去';

  @override
  String get blendModeDarken => '变暗';

  @override
  String get blendModeLighten => '变亮';

  @override
  String get blendModeColorBurn => '颜色加深';

  @override
  String get blendModeColorDodge => '颜色减淡';

  @override
  String get blendModeHardLight => '强光';

  @override
  String get blendModeSoftLight => '柔光';

  @override
  String get blendModeDifference => '差值';

  @override
  String get blendModeHue => '色相';

  @override
  String get blendModeSaturation => '饱和度';

  @override
  String get blendModeColor => '颜色';

  @override
  String get blendModeLuminosity => '明度';

  @override
  String get autofillLineColorModeSpecified => '指定颜色';

  @override
  String get autofillLineColorModeSameAsFill => '与填色相同';

  @override
  String get autofillLineColorModeTraceAdjust => '颜色描线・与线稿融合';

  @override
  String get autofillGradientTypeLinear => '直线';

  @override
  String get autofillGradientTypeRadialCenterOut => '放射：中央→外侧';

  @override
  String get autofillGradientTypeRadialOutCenter => '放射：外侧→中央';

  @override
  String get autofillPresetScreenTitle => '自动上色设置';

  @override
  String get autofillPresetSearchHint => '搜索设置';

  @override
  String get autofillPresetEmptyFavorites => '没有收藏的设置';

  @override
  String get autofillPresetEmpty => '没有设置';

  @override
  String get autofillPresetEmptyHint => '点击右下角的「＋」创建';

  @override
  String autofillPresetPartsCount(int count) {
    return '$count个部件';
  }

  @override
  String get autofillPresetNewDialogTitle => '新建';

  @override
  String get autofillPresetNameLabel => '设置名称';

  @override
  String get autofillPresetRenameDialogTitle => '重命名设置';

  @override
  String autofillPresetDeleteConfirmTitle(String name) {
    return '要删除「$name」吗？';
  }

  @override
  String get autofillFabImportOption => '导入';

  @override
  String get autofillPresetExportMenuItem => '导出 (.niafill)';

  @override
  String autofillPresetImportSuccessSnackbar(int count) {
    return '已导入$count个预设';
  }

  @override
  String autofillPresetImportFailedSnackbar(String error) {
    return '导入失败：$error';
  }

  @override
  String autofillPresetExportFailedSnackbar(String error) {
    return '导出失败：$error';
  }

  @override
  String autofillPresetDuplicateName(String name) {
    return '$name（副本）';
  }

  @override
  String get autofillPartSearchHint => '按部件名称搜索';

  @override
  String autofillPartUnconfiguredBanner(int count, String names) {
    return '有$count个部件尚未设置：$names（未选择网点）\n全部设置完成前无法关闭此画面。';
  }

  @override
  String get autofillPartUnconfiguredDialogTitle => '有尚未设置的部件';

  @override
  String get autofillPartUnconfiguredDialogBody => '保存前请先设置以下部件。';

  @override
  String autofillPartUnconfiguredItem(String name) {
    return '・$name：未选择网点';
  }

  @override
  String get autofillPartUnconfiguredBackButton => '返回设置';

  @override
  String get autofillPartEmpty => '没有部件\n请点击＋按钮添加';

  @override
  String get autofillPartToneUnselected => '未选择网点';

  @override
  String get autofillPartAddDialogTitle => '添加部件';

  @override
  String get autofillPartNameLabel => '部件名称';

  @override
  String get autofillPartAddButton => '添加';

  @override
  String get autofillPartRenameDialogTitle => '重命名部件';

  @override
  String autofillPartDetailDialogTitle(String name) {
    return '$name的详细设置';
  }

  @override
  String get autofillPartFillColorLabel => '填充颜色';

  @override
  String get autofillPartSelectColorButton => '选择颜色';

  @override
  String get autofillPartOutlineLabel => '用指定颜色描边';

  @override
  String autofillPartOutlineWidthLabel(int value) {
    return '描边粗细：${value}px';
  }

  @override
  String get autofillEyedropperFromThumbnailButton => '从图片取色';

  @override
  String get autofillEyedropperDialogTitle => '从图片中拾取颜色';

  @override
  String get autofillEyedropperDialogHint => '点击图片以选择颜色';

  @override
  String get autofillEyedropperPickedLabel => '已选颜色';

  @override
  String get autofillEyedropperImageLoadFailedSnackbar => '无法加载图片。';

  @override
  String get autofillThumbnailMenuItem => '设置缩略图';

  @override
  String get autofillThumbnailLoadButton => '载入图片';

  @override
  String get autofillThumbnailDeleteButton => '删除缩略图';

  @override
  String get autofillThumbnailDeleteConfirmTitle => '要删除缩略图吗？';

  @override
  String get autofillThumbnailDeleteConfirmBody => '删除后将恢复为默认的部件颜色显示（最多4色）。';

  @override
  String get autofillThumbnailCropDialogTitle => '调整缩略图';

  @override
  String get autofillThumbnailCropDialogHint => '拖动调整位置，双指缩放，双指旋转';

  @override
  String get autofillThumbnailCropLoadFailed => '无法加载图片，请尝试其他图片。';

  @override
  String get autofillThumbnailSetSnackbar => '已设置缩略图';

  @override
  String get autofillPartGradientSetButton => '设置渐变';

  @override
  String get autofillPartGradientEditButton => '编辑渐变';

  @override
  String autofillPartFillOpacityLabel(int value) {
    return '不透明度（填色图层）：$value%';
  }

  @override
  String get autofillPartLineColorLabel => '线稿颜色';

  @override
  String autofillPartTraceHueLabel(int value) {
    return '色相：$value';
  }

  @override
  String autofillPartTraceSaturationLabel(int value) {
    return '饱和度：$value';
  }

  @override
  String autofillPartTraceLightnessLabel(int value) {
    return '明度：$value';
  }

  @override
  String autofillPartLineOpacityLabel(int value) {
    return '不透明度（线稿图层）：$value%';
  }

  @override
  String get autofillPartToneLabel => '网点';

  @override
  String get autofillPartUseToneCheckbox => '使用网点';

  @override
  String get autofillPartBlendModeLabel => '混合模式';

  @override
  String get autofillPartApplyButton => '应用';

  @override
  String autofillPartGradientDialogTitle(String name) {
    return '$name的渐变';
  }

  @override
  String get autofillPartGradientTypeLabel => '种类';

  @override
  String get autofillPartGradientTypeInfo =>
      '线性：颜色沿指定角度渐变。放射：中心→外侧从中心向外变化，外侧→中心则相反。';

  @override
  String get autofillPartGradientFeatherInfo =>
      '设为0%时相邻颜色的边界会清晰分明。设为100%时会与相邻颜色的边缘完全平滑混合。';

  @override
  String get autofillLineColorModeTraceAdjustInfo =>
      '保留原本的线条颜色，只微调色相、饱和度、明度。想保留线稿的浓淡而不是用单色填满线条时使用此功能。';

  @override
  String autofillPartGradientAngleLabel(int value) {
    return '角度：$value°';
  }

  @override
  String get autofillPartGradientColorLabel => '颜色';

  @override
  String get autofillPartGradientAddColorButton => '添加颜色';

  @override
  String get autofillPartGradientRemoveButton => '解除渐变';

  @override
  String autofillPartGradientFeatherLabel(int value) {
    return '模糊强度: $value%';
  }

  @override
  String get autofillPartGradientDragHint => '拖动右侧的手柄可调整颜色顺序';

  @override
  String autofillPartGradientStopLabel(int value) {
    return '切换位置: $value%';
  }

  @override
  String get autofillPartGradientStopDragHint => '左右拖动▲标记可调整各颜色的位置';

  @override
  String get saveTreeScreenTitleTree => '存档树';

  @override
  String get saveTreeScreenTitleSlot => '存档槽';

  @override
  String get timelineExportMenuItem => '导出';

  @override
  String get timelineExportFrameMenuItem => '将当前帧导出为图片';

  @override
  String get timelineExportFrameDialogTitle => '将当前帧导出为图片';

  @override
  String get timelineExportFrameDialogMessage => '将当前显示的这一帧保存为静态图片。请选择格式。';

  @override
  String get timelineExportFramePngOption => '保存为PNG';

  @override
  String get timelineExportFrameJpegOption => '保存为JPEG';

  @override
  String timelineExportFrameSuccessSnackbar(String fileName) {
    return '已保存为$fileName（可在作品一览标签页中查看）';
  }

  @override
  String get timelineExportFrameErrorSnackbar => '帧导出失败';

  @override
  String get timelineDurationChangeMenuItem => '更改长度';

  @override
  String get timelineCanvasSizeChangeMenuItem => '更改画布尺寸';

  @override
  String get timelineDurationFramesLabel => '帧数';

  @override
  String get timelineDurationSecondsLabel => '秒数';

  @override
  String get timelineDurationShrinkConfirmTitle => '确定要缩短吗？';

  @override
  String get timelineDurationShrinkConfirmBody =>
      '将被裁掉的范围内的帧中，含有绘制内容或新增图层等更改。继续操作后，这些帧将无法恢复。确定要删除吗？';

  @override
  String get timelineCanvasSizeDragHint => '拖动框内可移动位置，拖动四角可调整大小（在接近原始尺寸时会自动吸附）';

  @override
  String get timelineCanvasSizeAngleLabel => '角度';

  @override
  String get saveTreeSaveAsChildHint => '将保存为所选节点的子节点。';

  @override
  String get saveTreeSaveAsRootHint => '将保存为根节点。';

  @override
  String get saveTreeCommentLabel => '备注（可选）';

  @override
  String get saveTreeCommentHint => '例：背景完成';

  @override
  String saveTreeSizeWarningSnackbar(String mb) {
    return '存档树的容量正在变大（约${mb}MB）。建议删除不需要的存档数据。';
  }

  @override
  String saveTreeSaveFailedSnackbar(String error) {
    return '保存失败。请检查剩余存储空间后重试（$error）';
  }

  @override
  String saveTreeSlotSaveDialogTitle(int n) {
    return '保存到存储槽 $n';
  }

  @override
  String saveTreeSlotOverwriteWarning(String date) {
    return '将覆盖现有数据（$date）。';
  }

  @override
  String get saveTreeRestoreAction => '还原';

  @override
  String get saveTreeTimelineActionChoiceBody =>
      '请选择是用当前内容「覆盖保存」这个存档，还是「从此处继续作业」。';

  @override
  String get saveTreeOverwriteAction => '覆盖保存';

  @override
  String get saveTreeOverwriteConfirmBody => '该时间点的存档数据将会消失，确定吗？';

  @override
  String get saveTreeResumeFromHereAction => '从此处继续';

  @override
  String get saveTreeResumeConfirmBody => '尚未保存的当前数据将会消失，确定吗？';

  @override
  String get saveTreeProjectDetailResumeBody => '要从这个存档继续作业吗？';

  @override
  String get saveTreeLoadFailedSnackbar => '存档数据读取失败';

  @override
  String saveTreeRestoredSnackbar(String name) {
    return '已还原$name';
  }

  @override
  String saveTreeSlotLabel(int n) {
    return '存储槽$n';
  }

  @override
  String saveTreeSlotFallbackName(int n) {
    return '存储槽 $n';
  }

  @override
  String get saveTreeNoDataLabel => '没有存档数据';

  @override
  String get saveTreeEmptyTitle => '没有存档数据';

  @override
  String get saveTreeEmptyHint => '点击上方的「保存」按钮即可创建第一个节点';

  @override
  String get saveTreeNodeDefaultTitle => '存档';

  @override
  String get saveTreeNodeDefaultName => '存档数据';

  @override
  String get saveTreeChangeDataTitle => '更改存档数据';

  @override
  String saveTreeChangeDataTitleWithProject(String name) {
    return '更改存档数据（$name）';
  }

  @override
  String get saveTreeChangeExceedMessage =>
      '当前的存档数量已\n超过新的可存档数量上限。\n\n请选择要保留的存档数据。';

  @override
  String saveTreeKeepableCountLabel(int n) {
    return '可保留的存档数：$n个';
  }

  @override
  String saveTreeKeepLatestButton(int n) {
    return '保留最新$n个';
  }

  @override
  String get saveTreeSelectDataButton => '选择存档数据';

  @override
  String saveTreeSelectedCountLabel(int selected, int limit) {
    return '已选择：$selected / $limit个';
  }

  @override
  String get saveTreeBackButton => '返回';

  @override
  String get saveTreeNextButton => '下一步';

  @override
  String get saveTreeDiscardDialogTitle => '未选择的存档数据';

  @override
  String get saveTreeArchiveOptionTitle => '作为存档保留（推荐）';

  @override
  String get saveTreeArchiveOptionSubtitle => '切换回存档树方式时会自动还原。\n会占用存储空间。';

  @override
  String get saveTreeDeleteOptionTitle => '彻底删除';

  @override
  String saveTreeDeleteOptionSubtitle(int count) {
    return '将彻底删除未选择的$count个数据。\n可节省存储空间。\n※删除后的数据无法恢复。';
  }

  @override
  String get saveTreeApplyChangeButton => '应用更改';

  @override
  String get canvasEditMenuAutofillPresets => '自动上色设置';

  @override
  String get canvasEditMenuAutofillPresetsSubtitle => '编辑各部位的颜色・网点组合';

  @override
  String get canvasEditMenuBackgroundToggle => '切换背景';

  @override
  String get canvasEditMenuBackgroundCurrentColor => '当前：项目背景色（点击切换为透明）';

  @override
  String get canvasEditMenuBackgroundCurrentTransparent => '当前：透明（点击切换为项目背景色）';

  @override
  String get canvasEditMenuOnionSkinSubtitle => '以淡淡的方式叠加显示前后帧';

  @override
  String get canvasEditMenuFilterSubtitle => '应用模糊、色调曲线等效果';

  @override
  String get canvasEditMenuFrameMultiSelect => '多选帧';

  @override
  String get canvasEditMenuFrameMultiSelectSubtitle => '用于批量处理（如批量应用滤镜等）';

  @override
  String get canvasEditMenuPressureCurve => '笔压曲线';

  @override
  String get canvasEditMenuPressureCurveSubtitle => '打开钢笔输入设置（与设置画面共用）';

  @override
  String get canvasEditMenuMeshTransform => '自由变形・网格变形';

  @override
  String get canvasEditMenuMeshTransformSubtitle => '无需选区即可变形整个图层';

  @override
  String get meshTransformPanelTitle => '自由变形・网格变形';

  @override
  String get meshTransformPanelHint => '用手指拖动角点或网格点（双指同时拖动不同的点即可旋转、缩放）';

  @override
  String get meshTransformDensityLabel => '网格密度';

  @override
  String get meshTransformRotateLabel => '旋转';

  @override
  String get meshTransformScaleLabel => '缩放';

  @override
  String get meshTransformApplyButton => '应用';

  @override
  String get canvasLassoEnclosedLabel => '填充封闭区域';

  @override
  String get canvasInvertSelectionTooltip => '反转选区';

  @override
  String get canvasTapToEnterTextLabel => '点击画布输入文字';

  @override
  String get canvasRulerFirstUseTip => '使用尺子可以画出笔直的线条和整齐的图形。';

  @override
  String get canvasRulerTooltip => '尺子';

  @override
  String get commonUndo => '撤销';

  @override
  String get commonRedo => '重做';

  @override
  String get canvasSettingsMenuTooltip => '设置/编辑';

  @override
  String canvasFrameSelectedCount(int selected, int total) {
    return '已选择 $selected / $total 帧';
  }

  @override
  String get canvasSelectAllButton => '全选';

  @override
  String get canvasDeselectAllButton => '取消全选';

  @override
  String get canvasApplyFilterButton => '应用滤镜';

  @override
  String get canvasShapeOff => 'OFF（返回普通画笔）';

  @override
  String get canvasShapeLine => '线条';

  @override
  String get canvasShapeRect => '矩形';

  @override
  String get canvasShapeCircle => '圆形';

  @override
  String get canvasMissingMaterialsSnackbar => '有缺失的素材';

  @override
  String get canvasResearchButton => '重新搜索';

  @override
  String get canvasTextInputTitle => '输入文字';

  @override
  String get canvasTextEditTitle => '编辑文字';

  @override
  String get canvasTextInputHint => '请输入文字';

  @override
  String get canvasTextFontLabel => '字体';

  @override
  String get canvasTextStandardFont => '标准字体';

  @override
  String get canvasTextBold => '粗体';

  @override
  String get canvasTextItalic => '斜体';

  @override
  String get canvasTextVertical => '竖排';

  @override
  String get canvasTextHorizontal => '横排';

  @override
  String get canvasTypesettingHelpTooltip => '关于排版与注音';

  @override
  String get canvasTextLineHeight => '行距';

  @override
  String get canvasTextLetterSpacing => '字间距';

  @override
  String get canvasTextAlign => '对齐';

  @override
  String get canvasTextOutline => '描边';

  @override
  String get canvasOutlineWidthLabel => '粗细';

  @override
  String get canvasHelpRotationTitle => '半角英数字旋转（仅限竖排）';

  @override
  String get canvasHelpRotationBody => '英文字母和符号会自动旋转90°显示。';

  @override
  String get canvasHelpTatechuyokoTitle => '纵中横（仅限竖排）';

  @override
  String get canvasHelpTatechuyokoBody =>
      '连续2位半角数字会自动以横向排列的方式收纳在一个字符的高度内（例：12）。';

  @override
  String get canvasHelpRubyTitle => '注音标注（类似日语振假名的读音标注）';

  @override
  String canvasHelpRubyBody(String example) {
    return '输入类似「$example」的格式，会在基底文字上方（横排时）或右侧（竖排时）显示小号的读音标注。竖排、横排均可使用，但含有注音标注的文字在横排时将无法自动换行（仅支持手动换行）。';
  }

  @override
  String get layerPanelTitle => '图层';

  @override
  String get layerPanelHelpTooltip => '帮助';

  @override
  String get layerPanelSearchHint => '按图层名称搜索';

  @override
  String get layerPanelSelectAll => '全选';

  @override
  String get layerPanelDeselectAll => '取消全选';

  @override
  String get layerPanelNewLayerButton => '新建图层';

  @override
  String get layerPanelNewFolderButton => '新建文件夹';

  @override
  String get layerPanelImportImageButton => '导入图片';

  @override
  String layerPanelDefaultLayerName(int n) {
    return '图层$n';
  }

  @override
  String layerPanelDefaultFolderName(int n) {
    return '文件夹$n';
  }

  @override
  String layerPanelDefaultLineartName(int n) {
    return '线稿$n';
  }

  @override
  String layerPanelDefaultAutofillName(int n) {
    return '自动上色$n';
  }

  @override
  String layerPanelDefaultCommonName(int n) {
    return '公共$n';
  }

  @override
  String layerPanelDefaultSelectionName(int n) {
    return '选择$n';
  }

  @override
  String get layerPanelClippingBadge => '裁剪';

  @override
  String get layerPanelAddTooltip => '添加';

  @override
  String get layerPanelAutofillMarkTooltip => '线稿已更新。点按可将自动上色更新为最新状态。';

  @override
  String get layerPanelRangeAllFrames => '全部帧';

  @override
  String get layerPanelRangeCurrentScene => '当前场景';

  @override
  String get layerPanelRangeSceneSpecified => '指定场景';

  @override
  String layerPanelRangeFrameSpan(int start, int end) {
    return '$start〜$end';
  }

  @override
  String get layerPanelMenuFrameRangeChange => '更改显示帧范围';

  @override
  String get layerPanelMenuRangeChange => '更改显示范围';

  @override
  String get layerPanelMenuPartAssign => '部件设置';

  @override
  String get layerPanelMenuRunAutofill => '执行自动上色';

  @override
  String get layerPanelMenuOrphanFill => '用最新颜色填充';

  @override
  String get layerPanelMenuOrphanFillSubtitle => '未找到对应的线稿图层，因此仅执行颜色更新';

  @override
  String get layerPanelMenuReplaceMaterial => '替换素材';

  @override
  String layerPanelDeleteConfirmTitle(String name) {
    return '要删除$name吗？';
  }

  @override
  String get layerPanelDeleteConfirmBody => '将从该素材显示范围内的所有帧中删除。';

  @override
  String layerPanelCommonDeleteMidDialogTitle(String name) {
    return '要更改「$name」的显示范围吗？';
  }

  @override
  String get layerPanelCommonDeleteMidDialogBody =>
      '共用图层的显示范围只能设置为一个连续区间，因此无法在范围中间的某一帧删除。请选择要保留此帧之前还是之后的部分。';

  @override
  String get layerPanelCommonDeleteKeepBeforeButton => '保留此帧之前';

  @override
  String get layerPanelCommonDeleteKeepAfterButton => '保留此帧之后';

  @override
  String get layerPanelRangeDialogTitle => '显示范围';

  @override
  String get layerPanelRangeStartFrameLabel => '起始帧';

  @override
  String get layerPanelRangeEndFrameLabel => '结束帧';

  @override
  String get layerPanelRangeTilde => '〜';

  @override
  String get layerPanelRangeUseCurrentButton => '使用当前范围';

  @override
  String get layerPanelRangeTargetSceneLabel => '目标场景';

  @override
  String get layerPanelRangeFrameRangeLabel => '指定帧范围';

  @override
  String get layerPanelMenuNormalLayer => '普通图层';

  @override
  String get layerPanelMenuCommonLayer => '公共图层';

  @override
  String get layerPanelMenuLineartLayer => '自动上色用线稿图层';

  @override
  String get layerPanelMenuAutofillLayer => '自动上色图层';

  @override
  String get layerPanelMenuSelectionLayer => '选择图层';

  @override
  String get layerPanelOpacityLabel => '不透明度';

  @override
  String get layerPanelLockLabel => '锁定';

  @override
  String get layerPanelOpacityLockLabel => '锁定不透明度';

  @override
  String get layerPanelClippingDescription => '仅在下方图层的不透明范围内绘制';

  @override
  String get layerPanelConvertToCommonLabel => '更改为公共图层';

  @override
  String get layerPanelConvertOption1Title => '将当前图层设为公共图层';

  @override
  String get layerPanelConvertOption1Subtitle => '仅将此图层设置为公共图层';

  @override
  String get layerPanelConvertOption2Title => '合并显示中的图层后设为公共图层';

  @override
  String get layerPanelConvertOption2Subtitle => '将当前显示中的所有图层合并后的结果创建为公共图层';

  @override
  String get layerPanelCommonRangeTitle => '公共图层范围';

  @override
  String get layerPanelHelpDialogTitle => '关于图层';

  @override
  String get layerPanelHelpBlendModeBody => '更改图层的合成方式，包括正片叠底、滤色、叠加等。';

  @override
  String get layerPanelHelpClippingBody => '仅在下方图层的不透明像素范围内绘制。需要控制绘制范围时请使用此功能。';

  @override
  String get layerPanelCommonLayerLabel => '公共图层';

  @override
  String get layerPanelHelpCommonLayerBody => '在多个帧之间共享相同内容的图层。可以设置显示的帧范围。';

  @override
  String get layerPanelAutofillMethodTitle => '自动上色方式';

  @override
  String get layerPanelAutofillNoLineartSnackbar => '未找到对应的自动上色用线稿图层。';

  @override
  String get layerPanelAutofillNote1 => '※ 若为项目内首次执行自动上色，选择哪一项都没有问题。';

  @override
  String get layerPanelAutofillNote2 => '※ 若不存在自动上色图层，无论选择哪一项都将从头判定区域进行自动上色。';

  @override
  String get layerPanelAutofillRepaintTitle => '重新上色';

  @override
  String get layerPanelAutofillRepaintHint => '误改了自动上色的形状时推荐使用';

  @override
  String get layerPanelAutofillRepaintNote => '※ 将从头判定区域重新上色。当前自动上色图层的形状将被丢弃。';

  @override
  String get layerPanelAutofillColorUpdateTitle => '颜色更新';

  @override
  String get layerPanelAutofillColorUpdateHint => '手动调整过自动上色形状时推荐使用';

  @override
  String get layerPanelAutofillColorUpdateNote =>
      '※ 将锁定不透明度并用最新颜色填充。当前自动上色图层的形状将保持不变。';

  @override
  String get layerPanelExecuteButton => '执行';

  @override
  String get layerPanelAutofillPartMissingSnackbar => '尚未设置部件。请通过「部件设置」进行设置。';

  @override
  String get layerPanelAutofillPresetMissingSnackbar => '在自动上色设置中找不到对应的部位。';

  @override
  String get layerPanelOrphanFillSuccessSnackbar => '未找到对应的线稿图层，已改为用最新颜色填充。';

  @override
  String get layerPanelOrphanFillFailSnackbar => '未设置部件，或没有填充形状，因此无法处理。';

  @override
  String get layerPanelAutofillUpdateHelpTitle => '自动上色更新标记';

  @override
  String get layerPanelAutofillUpdateHelpBody => '当前的自动上色不是最新状态。点按即可更新。';

  @override
  String layerPanelReplaceMaterialSuccessSnackbar(String name) {
    return '已替换素材：$name';
  }

  @override
  String layerPanelImportImageSuccessSnackbar(String name) {
    return '已导入图片：$name';
  }

  @override
  String layerPanelCopySuffix(String name) {
    return '$name的副本';
  }

  @override
  String get timelineFullscreenPreviewCloseTooltip => '关闭全屏预览';

  @override
  String get timelineDefaultProjectName => '项目名称';

  @override
  String get timelinePreviewPlaceholder => '预览';

  @override
  String get timelinePreviewFullscreenTip => '点击可全屏显示预览，便于确认成品效果。';

  @override
  String get timelinePreviewFullscreenTooltip => '全屏显示预览';

  @override
  String get timelineAddVideoTooltip => '＋视频';

  @override
  String get timelineAddAudioTooltip => '＋音源';

  @override
  String get timelineEffectFilterLabel => '演出滤镜';

  @override
  String get timelineAddCameraKfTooltip => '添加相机关键帧';

  @override
  String get timelineAddWatermarkTooltip => '＋水印';

  @override
  String get timelineWatermarkNotRegisteredTitle => '尚未注册水印';

  @override
  String get timelineWatermarkNotRegisteredBody => '请先在设置画面的「水印」中注册图片或文字。';

  @override
  String get timelineOpenSettingsButton => '打开设置';

  @override
  String get timelineWatermarkSelectTitle => '选择水印';

  @override
  String timelineWatermarkAddedSnackbar(String name) {
    return '已添加水印（将显示在全部帧中）：$name';
  }

  @override
  String get timelineWatermarkEditTitle => '编辑水印';

  @override
  String get timelineWatermarkAngleLabel => '角度';

  @override
  String get timelineWatermarkSizeLabel => '大小';

  @override
  String get timelineWatermarkOpacityLabel => '不透明度';

  @override
  String get timelineWatermarkLoopLabel => '始终显示（循环显示）';

  @override
  String get timelineWatermarkLoopSubtitle => '关闭后仅在当前场景中显示';

  @override
  String get timelineConfirmButton => '确定';

  @override
  String get timelineClipSelectDoneButton => '完成';

  @override
  String get timelineClipOverlapDialogTitle => '与现有片段重叠';

  @override
  String get timelineClipOverlapDialogBody => '粘贴位置与现有片段重叠，要如何放置？';

  @override
  String get timelineClipOverlapPlaceBefore => '放在前面';

  @override
  String get timelineClipOverlapPlaceAfter => '放在后面';

  @override
  String get timelineClipOverlapPlaceNewRow => '重叠放置（新增一行）';

  @override
  String get timelineSceneRenameTitle => '场景改名';

  @override
  String get timelineSceneDeleteMenuItem => '删除场景';

  @override
  String get timelineDurationLimitTitle => '已达到长度上限';

  @override
  String get timelineDurationLimitBodyFree =>
      '免费会员的视频长度最长为90秒。继续添加或复制帧会超过90秒，因此无法执行。升级为高级会员后最长可制作2小时。';

  @override
  String get timelineDurationLimitBodyPremium =>
      '这会超过高级会员的上限（最长2小时），因此无法继续添加或复制帧。';

  @override
  String timelineSceneDeleteConfirmTitle(String name) {
    return '要删除「$name」吗？';
  }

  @override
  String get timelineSceneDeleteConfirmBody =>
      '场景内的全部帧、公共图层、视频素材、图片素材、水印等全部数据都将被删除。';

  @override
  String timelineSceneMultiDeleteConfirmTitle(int count) {
    return '要删除已选中的$count个场景吗？';
  }

  @override
  String get timelineAutofillUpdateHelpBody =>
      '该场景/帧中包含并非最新状态的自动上色图层。在图层面板中点按目标图层即可更新。';

  @override
  String get timelineFrameTrackLabel => '帧';

  @override
  String get timelineTrackRowRenameTitle => '重命名行';

  @override
  String get timelineCameraTrackLabel => '相机';

  @override
  String get timelineRangeSceneFixed => '固定场景';

  @override
  String get timelineEndCardDefaultLogoLabel => 'NIARIM标志';

  @override
  String get timelineEndCardHiddenLabel => '隐藏';

  @override
  String get timelineEndCardTrackLabel => '片尾卡轨道';

  @override
  String get timelineMarkerTrackLabel => '时间戳';

  @override
  String timelineMarkerAddDialogTitle(int n) {
    return '在F$n添加时间戳';
  }

  @override
  String timelineMarkerEditDialogTitle(int n) {
    return '时间戳：F$n';
  }

  @override
  String get timelineMarkerCommentHint => '备注（例：这里对口型「啊」）';

  @override
  String timelineAddClipDialogTitle(String trackName) {
    return '添加$trackName片段';
  }

  @override
  String get timelineClipLabelFieldLabel => '标签';

  @override
  String get timelineClipStartLabel => '开始：';

  @override
  String get timelineClipLengthLabel => '长度：';

  @override
  String get timelineAutofillNote2 =>
      '※ 若仅存在自动上色图层（无线稿），无论选择哪一项都将从头判定区域进行自动上色。';

  @override
  String get timelineAutofillTargetLabel => '执行对象';

  @override
  String get timelineAutofillScopeCurrentFrame => '仅当前帧';

  @override
  String get timelineAutofillScopeCurrentScene => '以场景为单位（当前场景的全部帧）';

  @override
  String get timelineAutofillScopeAllScenes => '全部帧（整个项目）';

  @override
  String get timelineAutofillProgressTitle => '正在执行自动上色';

  @override
  String timelineAutofillProgressSubtitle(int count) {
    return '$count帧';
  }

  @override
  String timelineAutofillCompleteSnackbar(int count) {
    return '自动上色已完成（处理了$count项）';
  }

  @override
  String get timelineEffectTypeFade => '淡入淡出';

  @override
  String get timelineEffectTypeGaussianBlur => '高斯模糊';

  @override
  String get timelineEffectTypeLensBlur => '镜头模糊';

  @override
  String get timelineEffectTypeMosaic => '马赛克';

  @override
  String get timelineEffectTypeChromaticAberration => '色差';

  @override
  String get timelineEffectTypeNoise => '噪点';

  @override
  String get timelineEffectTypeSepia => '怀旧棕褐';

  @override
  String get timelineEffectTypeAnimeStyle => '动漫风';

  @override
  String get timelineEffectTypeRetroAnime => '复古动漫';

  @override
  String get timelineEffectTypeCrt => '老电视';

  @override
  String get timelineEffectTypeAnimatedNoise => '动态噪点';

  @override
  String get timelineEffectTypeRain => '下雨';

  @override
  String get timelineEffectFilterEmptyState => '没有滤镜\n请点击＋添加按钮进行添加';

  @override
  String get timelineRangeStartLabel => '开始';

  @override
  String get timelineRangeEndLabel => '结束';

  @override
  String get timelineEffectSizeLabel => '大小';

  @override
  String get timelineEffectStrengthLabel => '强度';

  @override
  String get timelineEffectAmountLabel => '数量';

  @override
  String get timelineEffectGrainSizeLabel => '颗粒大小';

  @override
  String get timelineEffectRainIntensityLabel => '降雨强度';

  @override
  String get timelineEffectRainSpeedLabel => '速度';

  @override
  String get timelineEffectRainSizeLabel => '雨滴大小';

  @override
  String get timelineEffectWindAngleLabel => '风向角度';

  @override
  String get timelineColorLabel => '颜色';

  @override
  String get timelineColorBlack => '黑';

  @override
  String get timelineColorWhite => '白';

  @override
  String get timelineColorCustom => '自定义';

  @override
  String get timelineFadeColorDialogTitle => '淡入淡出颜色';

  @override
  String get timelineAddFilterDialogTitle => '添加滤镜';

  @override
  String get timelineClipVolumeLabel => '音量';

  @override
  String get timelineClipFadeInLabel => '淡入';

  @override
  String get timelineClipFadeOutLabel => '淡出';

  @override
  String get timelineClipUseStartLabel => '使用起始帧';

  @override
  String get timelineClipUseEndLabel => '使用结束帧';

  @override
  String timelineCameraKfTitle(int n) {
    return '相机关键帧：F$n';
  }

  @override
  String get timelineCameraMoveXLabel => 'X 移动';

  @override
  String get timelineCameraMoveYLabel => 'Y 移动';

  @override
  String get timelineCameraZoomLabel => '缩放';

  @override
  String get timelineCameraRotationLabel => '旋转';

  @override
  String get layerPanelKeyframeLabel => '动画（关键帧）';

  @override
  String layerKeyframeSheetTitle(String name) {
    return '$name 的关键帧';
  }

  @override
  String get layerKeyframeSheetDesc =>
      '按帧设置该图层的位置・缩放・旋转，关键帧之间会自动插值。图层本身的画面内容不会改变。';

  @override
  String layerKeyframeAddAtCurrentFrame(int n) {
    return '在当前帧（F$n）添加';
  }

  @override
  String get layerKeyframeEmpty => '还没有关键帧，请用上方按钮添加。';

  @override
  String get layerKeyframeScaleShort => '缩放';

  @override
  String get layerKeyframeRotationShort => '旋转';

  @override
  String layerKeyframeEditTitle(int n) {
    return '关键帧：F$n';
  }

  @override
  String get layerKeyframeFrameLabel => '帧';

  @override
  String get layerKeyframeScaleLabel => '缩放';

  @override
  String get layerKeyframeRotationLabel => '旋转';

  @override
  String get layerKeyframeEasingLabel => '过渡到下一关键帧的方式';

  @override
  String get layerKeyframeEasingLinear => '匀速';

  @override
  String get layerKeyframeEasingEaseIn => '缓入（开始慢）';

  @override
  String get layerKeyframeEasingEaseOut => '缓出（结束慢）';

  @override
  String get layerKeyframeEasingEaseInOut => '缓入缓出';

  @override
  String get layerKeyframeEasingBounceOut => '弹跳';

  @override
  String get layerPanelGroupTooltip => '分组';

  @override
  String get layerPanelShowSelectedTooltip => '显示所有选中的图层';

  @override
  String get layerPanelHideSelectedTooltip => '隐藏所有选中的图层';

  @override
  String get layerPanelGroupDefaultName => '新建分组';

  @override
  String layerPanelGroupMembershipLabel(String name) {
    return '分组：$name';
  }

  @override
  String get layerPanelGroupLeaveAction => '解除';

  @override
  String frameStripHoldDialogTitle(int n) {
    return 'F$n 保持格数';
  }

  @override
  String get frameStripFrameListModeLabel => '帧列表';

  @override
  String get frameStripTimelineModeLabel => '时间轴';

  @override
  String get progressDialogAdLoading => '广告加载中…';

  @override
  String get adMockPlaceholderLabel => '广告横幅（用于位置试验的模型）';

  @override
  String get adMediumRectangleMockPlaceholderLabel => '中矩形广告（300×250 位置测试模型）';

  @override
  String get progressDialogTipLabel => '提示';

  @override
  String get premiumBannerRegisterButton => '升级Premium';

  @override
  String get licenseTermsArt1Title => '第1条（适用）';

  @override
  String get licenseTermsArt1Body =>
      '本使用条款（以下称「本条款」）规定了本应用「NIARIM」（以下称「本应用」）的使用条件。用户须在同意本条款的前提下使用本应用。使用本应用即视为已同意本条款。';

  @override
  String get licenseTermsArt2Title => '第2条（使用资格・适用环境）';

  @override
  String get licenseTermsArt2Body =>
      '1. 有关支持的操作系统及推荐运行环境的详细信息，请以各分发商店及本应用内的显示内容为准。\n2. 本应用力求在各种性能的设备上都能流畅使用，但根据设备性能、操作系统版本、剩余存储空间、设置等使用环境的不同，部分功能可能受到限制或无法正常运作。';

  @override
  String get licenseTermsArt3Title => '第3条（禁止事项）';

  @override
  String get licenseTermsArt3Body =>
      '用户在使用本应用时，不得实施以下行为：\n・违反法令或公序良俗的行为\n・侵害本应用、开发者或第三方的著作权、商标权等知识产权、肖像权、隐私权或其他权利或利益的行为\n・以反编译、反汇编、逆向工程或其他解析为目的的行为（法令允许的情况除外）\n・对本应用进行未经授权的改造、复制或再分发\n・对本应用或其提供基础设施进行未经授权的访问、施加过度负荷等妨碍其正常提供的行为\n・其他开发者基于合理理由判断为不当的行为';

  @override
  String get licenseTermsArt4Title => '第4条（创作内容的权利）';

  @override
  String get licenseTermsArt4Body =>
      '1. 用户使用本应用制作的插画、动画等内容（包括项目数据、导出的图片、视频等，以下称「创作内容」）所涉及的著作权及其他权利，在法令允许的范围内，归属于对该内容享有权利的用户或第三方。\n2. 本应用未提供将创作内容发送、收集或同步至开发者服务器的功能。项目数据原则上仅保存在用户设备内（用户自行选择使用作品广场功能发布创作内容时的处理方式，参见第12条）。\n3. 无论使用免费版还是高级版制作，开发者均不会以本应用的使用费用或版本为由限制创作内容的商业使用（免费版与高级版的区别仅限于片尾卡显示、导出时长上限等功能方面）。\n4. 尽管有前项规定，用户添加至本应用中的字体、图片、素材等由第三方享有权利的内容，仍需遵守第5条规定的各自使用条件。';

  @override
  String get licenseTermsArt5Title => '第5条（内置字体・追加素材相关规定）';

  @override
  String get licenseTermsArt5Body =>
      '1. 本应用内置的字体及其他素材，均依照本画面「关于使用字体」中所记载的各许可条款进行使用。\n2. 关于用户自行添加注册或读取至本应用中的字体、图片、色调、印章等素材的权利关系，应由用户自行负责，在取得必要权利或许可的前提下合法使用。\n3. 因用户使用第三方素材而与第三方产生纠纷的，除法令另有规定应承担责任的情形外，开发者不承担责任。';

  @override
  String get licenseTermsArt6Title => '第6条（高级功能・付费）';

  @override
  String get licenseTermsArt6Body =>
      '1. 本应用除可免费使用的功能外，还提供通过应用内购买（月度方案、年度方案及其他高级方案）方可使用的高级功能。\n2. 高级功能的价格、提供内容、购买方式及其他条件，以购买时本应用内或分发商店的显示内容为准。\n3. 购买后的取消、退款及其他与结算相关的事项，适用Google Play或用户所使用的结算平台的规定；但法令另有规定的，从其规定。\n4. 开发者可能基于法令修订、技术上的必要性、本应用的改进等合理事由变更高级功能的内容。进行重大变更时，将在合理可行的范围内，通过本应用内或其他适当方式事先告知。';

  @override
  String get licenseTermsArt7Title => '第7条（广告展示）';

  @override
  String get licenseTermsArt7Body =>
      '1. 免费版中，可能通过第三方广告投放服务展示广告。\n2. 广告投放商对信息的获取、使用及其他处理，适用各广告投放商各自的隐私政策。';

  @override
  String get licenseTermsArt8Title => '第8条（信息处理）';

  @override
  String get licenseTermsArt8Body =>
      '1. 本应用未提供将用户制作的插画、动画等内容及项目数据发送或收集至开发者服务器的功能。这些数据原则上仅保存在用户设备内；由于开发者自身不具备保存此类内容的功能，因此开发者一方不存在所谓的保存期限概念。\n2. 本应用内置的第三方服务（广告投放、应用内购买等）所获取的信息及其他用户信息的处理，依照另行制定的《隐私政策》办理。\n3. 卸载本应用后，保存在设备内的数据（项目、设置、已添加的字体等）将被删除。';

  @override
  String get licenseTermsArt9Title => '第9条（提供的中止・变更・终止）';

  @override
  String get licenseTermsArt9Body =>
      '1. 开发者在对本应用进行维护、更新、修正时，或提供基础设施发生故障时，或存在其他不可避免的情形时，可能暂时中止本应用全部或部分功能的提供。\n2. 开发者可根据需要变更本应用的内容，或终止本应用的提供。\n3. 前两项情形，除紧急情况外，开发者将尽可能在本应用内或以其他适当方式事先公告。\n4. 因本条所述变更、中止、终止而给用户造成的损害，除法令另有规定应承担责任的情形外，开发者不承担责任。';

  @override
  String get licenseTermsArt10Title => '第10条（免责事项）';

  @override
  String get licenseTermsArt10Body =>
      '1. 开发者不保证本应用不存在事实上或法律上的瑕疵（包括安全性、可靠性、准确性、完整性、对特定目的的适用性、无错误或故障等）。\n2. 用户应自行负责使用本应用。由于设备故障、误操作、操作系统更新等原因，数据可能会丢失，因此建议用户利用导出、分享等功能对制作中的数据进行定期备份。\n3. 在法令允许的范围内，开发者对因使用本应用而给用户造成的损害不承担责任。但开发者存在故意或重大过失的情形除外；即便在该情形下，开发者所承担的损害赔偿责任也仅限于通常发生的直接损害，且以用户在最近一年内就本应用实际支付的金额为上限（免费使用的情况下为0日元）。';

  @override
  String get licenseTermsArt11Title => '第11条（本条款的变更）';

  @override
  String get licenseTermsArt11Body =>
      '1. 因法令修订、本应用内容变更或其他开发者认为必要的情形，开发者可能变更本条款。\n2. 变更本条款时，开发者将事先通过本应用内或其他适当方式，公告变更内容及生效日期。\n3. 变更后的本条款，在法令允许的范围内，自前项所述生效日期起适用。';

  @override
  String get licenseTermsArt12Title => '第12条（作品广场：社区发布功能）';

  @override
  String get licenseTermsArt12Body =>
      '1. 本应用可选择性地提供以下功能：用户可通过自己的Google账号，将自己制作的动画作品发布至YouTube，并在「作品广场」上公开、浏览（以下称「本社区功能」）。即使不使用本社区功能，用户也可以浏览和制作作品。\n2. 已发布的视频文件本身保存在YouTube上，不会保存在开发者的服务器上。另一方面，用于识别、显示已发布作品所需的信息（YouTube视频ID、标题、统计信息、举报信息等），以及用户使用发布、举报、屏蔽功能时颁发的NIARIM User ID（与Google账号不同、由本应用内部颁发的识别码），由开发者的服务器管理。\n3. 本社区功能中的作品发布、举报以及屏蔽其他用户，均需通过Google账号登录。\n4. 可发布的作品数量设有每日上限（免费会员与高级会员的上限不同）。该上限可能因运营原因而变更。\n5. 若用户认为其他用户发布的作品违反法令或公序良俗，或可能符合第3条各项所述情形，可通过本应用内的举报功能向开发者举报。开发者在确认举报内容后，可基于合理理由，对相关作品采取从列表中隐藏等必要措施。禁止进行虚假举报或滥用举报功能。\n6. 用户删除发布内容，或解除本应用与Google账号的关联时，对应的YouTube视频可能会被删除。此外，若视频在YouTube一方被设为非公开或被删除，该作品也将不再在作品广场上显示。\n7. 使用本社区功能时，除本条款外，还需遵守YouTube的服务条款及社区准则。\n8. 用户可以关注其他用户，并可收藏或转发其他用户的作品。关注中／粉丝列表以及已收藏作品的列表默认不公开，是否公开由用户在本应用内选择。关注数与粉丝数无论该设置如何均会显示。\n9. 作品上的标签也可由发布者以外的用户添加或删除。发布者可锁定自己作品的标签，以禁止其他用户编辑。用户不得添加诽谤他人的标签、与作品内容无关的标签或其他不当标签。开发者可能删除不当标签。\n10. 开发者会在被关注等情况下于本应用内的通知列表中显示通知。用户在设备上允许通知的情况下，可能会发送推送通知。通知可从本应用的设置或设备的设置中停用。\n11. 用户不得将本社区功能用于骚扰其他用户、宣传・招揽或其他偏离其本来目的（作品的公开与浏览）的目的。使用拉黑功能后，被拉黑对象的作品将不再显示在自己的列表中。';

  @override
  String get licenseTermsArt13Title => '第13条（准据法・裁判管辖）';

  @override
  String get licenseTermsArt13Body =>
      '1. 本条款的解释以日本法为准据法。\n2. 若因本应用产生纠纷，根据诉讼标的额，以管辖开发者所在地的地方法院或简易法院作为第一审的专属合意管辖法院。';

  @override
  String get privacyPolicyArt1Title => '第1条（本政策的定位）';

  @override
  String get privacyPolicyArt1Body =>
      '本隐私政策（以下称「本政策」）规定了本应用「NIARIM」（以下称「本应用」）中信息的处理方式。有关本应用使用条件的整体内容，请另行参阅「使用条款・许可」画面。';

  @override
  String get privacyPolicyArt2Title => '第2条（本应用不会获取的数据）';

  @override
  String get privacyPolicyArt2Body =>
      '本应用未提供将用户制作的插画、动画等内容（包括项目数据、导出的图片、视频等，以下同）发送、收集或保存至开发者服务器的功能。这些数据原则上仅保存在用户设备内（本应用未搭载云同步功能）。由于开发者自身不具备保存此类内容的功能，因此开发者一方不存在所谓的保存期限概念。设备内保存的数据可随时通过本应用的删除功能予以删除；卸载本应用后，保存在设备内的项目、设置、已添加字体等数据也将一并删除（用户自行选择使用作品广场功能发布作品时的信息处理方式，参见第7条）。';

  @override
  String get privacyPolicyArt3Title => '第3条（第三方服务获取的信息）';

  @override
  String get privacyPolicyArt3Body =>
      '本应用内置以下第三方服务，各服务提供商可能在提供各自服务所需的范围内获取信息。本应用的开发者未实现独立获取或保存这些信息的功能（各服务所获取信息的管理，依照该服务提供商各自的隐私政策办理）。\n\n【广告投放（Google AdMob）】\n免费版通过Google AdMob投放广告。出于广告投放、效果测量、防止不正当行为等目的，Google或其关联公司可能会获取并使用广告标识符（Advertising ID）等设备信息。有关获取及使用的详情，请参阅Google隐私政策（https://policies.google.com/privacy）。用户可通过设备设置（如Android设置应用中的「隐私」等）重置广告标识符或停用个性化广告。若您位于欧洲经济区（EEA）、英国或瑞士，可在启动时显示的同意表单中选择广告个性化相关的同意设置，并可随时通过本画面下方的「变更广告同意设置」按钮进行修改。\n\n【应用内购买（Google Play Billing）】\n高级功能的购买通过Google Play的结算系统进行。开发者不会直接获取或保存信用卡号等结算信息。结算相关信息的处理依照Google Play的规定。\n\n【下载附加字体（GitHub）】\n仅当您在设置界面的「字体管理」中选择下载附加字体时，才会与字体文件的分发方 GitHub（GitHub, Inc.）的服务器进行通信。该通信仅在您选择下载时发生，应用启动时或正常使用过程中不会发生。发送的仅为通信所必需的信息（IP 地址、所请求的字体文件等），不会发送作品数据或可识别您身份的信息。所获取信息的处理遵循 GitHub 的隐私声明（https://docs.github.com/site-policy/privacy-policies/github-privacy-statement）。\n\n【崩溃分析・使用情况分析】\n本应用目前未内置以崩溃分析、使用情况分析为目的的SDK。今后如引入此类服务，将更新本政策并在本应用内进行公告。';

  @override
  String get privacyPolicyArt4Title => '第4条（关于Cookie等跟踪技术）';

  @override
  String get privacyPolicyArt4Body =>
      '本应用本身不使用Cookie，但第3条所述的广告投放服务（Google AdMob）可能会出于广告投放、效果测量的目的，使用与之类似的识别技术（如广告标识符等）。';

  @override
  String get privacyPolicyArt5Title => '第5条（关于儿童个人信息）';

  @override
  String get privacyPolicyArt5Body =>
      '本应用并非以未满13岁的儿童为主要对象而有意收集信息。建议家长在孩子使用本应用时，根据需要通过设备设置停用个性化广告等。';

  @override
  String get privacyPolicyArt6Title => '第6条（关于信息的跨境转移）';

  @override
  String get privacyPolicyArt6Body =>
      '第3条所述的第三方服务（Google AdMob、Google Play Billing）可能在Google公司于全球各地运营的服务器上进行处理。相关处理适用各服务各自的隐私政策。';

  @override
  String get privacyPolicyArt7Title => '第7条（作品广场：社区发布功能中的信息处理）';

  @override
  String get privacyPolicyArt7Body =>
      '1. 仅当用户出于自身意愿使用「作品广场」功能（用户协议第12条）时，本应用才会在开发者的服务器上管理以下信息。\n・用于识别和展示已发布作品的信息（YouTube 视频 ID、标题、统计信息、发布时间、标签等）\n・使用发布、举报、拉黑、关注、收藏等功能时发放的 NIARIM User ID（与 Google 账号分开、在本应用内部发放的标识符）\n・已关联 YouTube 频道的公开信息（频道名称、频道图标的图片 URL）。为展示发布者名称与图标，会复制并保存在开发者的服务器上\n・使用举报功能时的举报内容以及举报者的 NIARIM User ID\n・所拉黑对象的 NIARIM User ID\n・所关注对象的 NIARIM User ID，以及关注数与粉丝数\n・已收藏作品的 ID 及收藏时间\n・已转发作品的 ID 及转发时间\n・作品上的标签（参见第4款）\n・启用推送通知时的设备令牌（设备为确定通知送达对象而发放的标识符，仅用于发送通知）\n2. 已发布的视频文件本身保存在 YouTube 上，不保存在开发者的服务器上。\n3. 前两款所述信息仅在提供本社区功能所需的范围内使用（作品列表展示、排行、搜索、举报处理、发布上限管理、关注・收藏・转发的体现、通知发送等）。开发者不会为广告投放目的向第三方提供这些信息。\n4. 标签也可由发布者以外的用户添加或删除（发布者可锁定自己作品的标签以禁止编辑）。标签在作品广场上公开，且不显示由谁添加。\n5. 以下信息默认不公开，仅当用户在本应用内切换为公开设置时才会向其他用户展示。\n・已收藏作品的列表\n・关注中／粉丝列表\n其中，关注数与粉丝数（人数）无论公开设置如何均始终显示。\n6. 将已发布作品设为不公开或删除后，该作品将不再显示在作品广场的列表与排行中。如希望删除开发者服务器上的记录，请通过第9条的联系方式与我们联系。\n7. 不使用本社区功能时，不会发生本条所述的信息处理。（依照第2条的原则，不会向开发者的服务器发送任何内容。）';

  @override
  String get privacyPolicyArt8Title => '第8条（本政策的变更）';

  @override
  String get privacyPolicyArt8Body =>
      '因法令修订、本应用内容变更或其他开发者认为必要的情形，开发者可能变更本政策。变更本政策时，开发者将事先通过本应用内或其他适当方式，公告变更内容及生效日期。';

  @override
  String get privacyPolicyArt9Title => '第9条（咨询）';

  @override
  String get privacyPolicyArt9Body =>
      '有关本政策的咨询，请通过以下联系方式与我们联系。\n（开发者联系方式：尚未设定 —— 请在公开前填写电子邮件地址等联系方式信息）';

  @override
  String get privacyPolicyAdConsentButton => '变更广告同意设置';

  @override
  String get tipsPcDexLayoutTitle => '宽屏环境会自动切换为PC模式（DeX）的专业布局';

  @override
  String get tipsPcDexLayoutDesc =>
      '在Chromebook、外接键盘的平板、三星DeX等宽屏环境下使用时，应用会自动切换为停靠面板式的专业布局。也可以在工作区设置中手动固定为始终PC模式或始终手机模式，连接外接显示器工作时同样好用。';

  @override
  String get workspaceTimelineSection => '时间轴显示';

  @override
  String get workspaceTimelineHint =>
      '可以将视频、音频轨道每行的高度分5档调整。用两指捏合手势也能临时放大或缩小时间轴上的帧宽度。';

  @override
  String get workspaceTimelineTrackHeightLabel => '轨道高度';

  @override
  String get workspaceTimelinePreviewLabel => '预览';

  @override
  String get workspaceEndCardSection => '片尾卡';

  @override
  String get workspaceEndCardHint =>
      '片尾卡是应用自动显示在每个视频结尾的自带Logo，免费会员无法操作。仅限高级会员：开启后，下次打开时间轴时片尾卡会默认隐藏（已删除）。高级会员资格到期后，此设置会自动恢复为关闭。';

  @override
  String get workspaceEndCardDefaultHiddenTitle => '默认隐藏片尾卡（仅限高级会员）';

  @override
  String get tipsTransparentColorTitle => '透明色不只是橡皮擦，可以像画笔一样使用';

  @override
  String get tipsTransparentColorDesc =>
      '选择透明色后，可以用画笔、套索、图形等任意喜欢的工具直接擦除。既能利用画笔的笔压和平滑度精细地修圆轮廓，也能用渐变笔刷让边界柔和地渐变为透明，这些都是普通橡皮擦工具做不到的细腻表现。';

  @override
  String get tipsQuickToolVariantTitle => '快捷工具不仅能登记不同工具，也能登记不同笔刷、不同粗细';

  @override
  String get tipsQuickToolVariantDesc =>
      '快捷工具槽位不仅限于在钢笔、橡皮擦等不同工具间切换，还可以将同一支钢笔但不同笔刷、或同一个橡皮擦但不同粗细分别登记为独立项目。只精选常用的组合排列好，就能减少每次都要重新打开设置面板调整细节的麻烦。';

  @override
  String get tipsCommonLayerLipSyncTitle => '共通图层不仅能用于背景，也能给人物省容量';

  @override
  String get tipsCommonLayerLipSyncDesc =>
      '不只是背景，将人物图层本身设为共通图层也很有效。只把嘴部、眨眼的眼睛等每帧都会变化的部分保留为普通图层叠加，身体、头发等不动的部分设为共通图层，即使是对口型或眨眼动画，也能大幅削减容量。';

  @override
  String get tipsCommonLayerKeyframeTitle => '共通图层与图层关键帧同样能节省容量';

  @override
  String get tipsCommonLayerKeyframeDesc =>
      '共通图层可以通过图层关键帧移动位置、缩放、旋转。不必逐帧重新绘制，只需将一张图设为共通图层并用关键帧让它动起来，就能在不增加容量的前提下加入简单的动作。';

  @override
  String get tipsTransferCustomizationTitle => '迁移功能让你换设备也能保持一贯的使用体验';

  @override
  String get tipsTransferCustomizationDesc =>
      '迁移（.niatra）功能可以把笔刷、主题、工具栏排列、调色板等个性化设置一起转移到其他设备。无论是换机还是多设备协同使用，都无需每次从头重新设置。';

  @override
  String get tipsBlendModeUsageTitle => '根据目的区分使用混合模式会更有效果';

  @override
  String get tipsBlendModeUsageDesc =>
      '想加阴影时用正片叠底，想增添光效或光泽时用滤色或线性减淡（添加），想让阴影更有质感时用叠加或柔光较为合适。即使是同一种颜色，仅改变混合模式印象也会大不相同，建议先切换几个候选项对比看看效果。';

  @override
  String get timelineSaveFailedDialogTitle => '保存失败';

  @override
  String get timelineSaveFailedDialogBody => '保存失败，请重试。';

  @override
  String get licenseSectionIcons => '关于所使用的图标';

  @override
  String get layerPanelMergeAllVisibleTooltip => '合并所有可见图层';

  @override
  String get canvasBrushSliderToggleLabel => '详细';

  @override
  String get helpMeshTransformTitle => '自由变形・网格变形';

  @override
  String get helpMeshTransformDesc =>
      '从画布右上角的编辑/设置菜单打开的、以整个图层为对象的变形工具。与选区变形不同，不需要选区，可以用手指单独拖动角点或网格点做出自由的变形。控制面板的分割数滑块最多可将网格细分为10×10，用两根手指同时捏住不同的点，即可直观地进行旋转、缩放操作。';

  @override
  String get layerPanelBrightnessToAlphaLabel => '按明度透明化';

  @override
  String get layerPanelBrightnessToAlphaHint =>
      '越亮的部分会变得越透明。颜色保持不变但会变成半透明（不是白色背景直接消失，而是整张图都变淡）。';

  @override
  String get layerPanelBrightnessToAlphaColorButton => '彩色';

  @override
  String get layerPanelBrightnessToAlphaGrayButton => '灰色';

  @override
  String get tipsRoughLayerRescueTitle => '不小心把线稿画在了草图图层上？用「按明度透明化」抢救';

  @override
  String get tipsRoughLayerRescueDesc =>
      '即使不小心把线稿画在了草图图层上，也能在不删除任何内容的情况下把线稿单独取出来。①新建一个图层，将其混合模式设为「除法」。②用取色器吸取草图的颜色，将整个除法图层填满该颜色（草图会变淡）。③复制该除法图层，草图会完全消失。④在图层面板中使用「合并所有可见图层」将其合并为一层。⑤在合并后图层的三点菜单中选择「按明度透明化（灰色）」，白色部分就会变透明，只留下线稿。';

  @override
  String get filterNameMonochrome => '单色化滤镜';

  @override
  String get timelineEffectTypeMonochrome => '单色化滤镜';

  @override
  String get filterNameColorAdjust => '色调调整';

  @override
  String get filterColorAdjustSaturationLabel => '饱和度';

  @override
  String get filterColorAdjustBrightnessLabel => '明度';

  @override
  String get filterColorAdjustContrastLabel => '对比度';

  @override
  String get canvasColorAdjustTitle => '色调调整';

  @override
  String get canvasColorAdjustAddToDrawFilter => '添加到绘图滤镜';

  @override
  String get canvasColorAdjustAddToEffectFilter => '添加到演出滤镜';

  @override
  String get canvasColorAdjustMenuTitle => '色调调整';

  @override
  String get canvasEditMenuReferenceWindow => '参考窗口';

  @override
  String get canvasEditMenuReferenceWindowSubtitle => '悬浮显示参考图片';

  @override
  String get referenceWindowTitle => '参考窗口';

  @override
  String get referenceWindowSelectImageButton => '选择图片';

  @override
  String get workspaceDockPanelSection => 'PC版默认打开的面板';

  @override
  String get workspaceDockPanelHint =>
      '在PC/DeX模式下，选中的多个面板可以同时展开固定显示（手机版为避免误触总是以全部隐藏开始）。';

  @override
  String get workspaceDockPanelBrush => '画笔';

  @override
  String get workspaceDockPanelColorPicker => '取色器';

  @override
  String get workspaceDockPanelLayer => '图层';

  @override
  String get workspaceDockPanelTone => '色调';

  @override
  String get workspaceDockPanelStamp => '貼纸';

  @override
  String get workspaceDockPanelPenSubTool => '笔子子工具';

  @override
  String get workspaceDockPanelOnionSkin => '洋葱红';

  @override
  String get workspaceDockPanelRuler => '尺规';

  @override
  String get workspaceDockPanelFilter => '滤镜';

  @override
  String get workspaceDockPanelQuickTool => '快捷工具';

  @override
  String get workspaceDockPanelColorAdjust => '色调调整';

  @override
  String get workspaceDockPanelCanvasPreview => '画布预览';

  @override
  String get workspacePcLayoutButton => 'PC布局设置';

  @override
  String get pcWorkspaceLayoutScreenTitle => 'PC布局设置';

  @override
  String get pcWorkspaceLayoutIntroHint =>
      '可调整以PC模式（横屏+连接鼠标/数位板）打开画布画面时，面板的排列顺序和宽度。';

  @override
  String get pcWorkspaceLayoutToolOrderSection => '工具面板顺序';

  @override
  String get pcWorkspaceLayoutToolOrderHint => '同时打开画笔、色调、图章等多个面板时的堆叠顺序。';

  @override
  String get pcWorkspaceLayoutRightOrderSection => '图层等面板顺序';

  @override
  String get pcWorkspaceLayoutRightOrderHint => '取色器、图层面板、画布预览的堆叠顺序。';

  @override
  String get pcWorkspaceLayoutWidthSection => '面板宽度';

  @override
  String get pcWorkspaceLayoutToolWidthLabel => '工具面板一侧宽度';

  @override
  String get pcWorkspaceLayoutRightWidthLabel => '图层面板一侧宽度';

  @override
  String get pcWorkspaceLayoutResetWidthButton => '将宽度恢复为默认值';

  @override
  String get pcWorkspaceLayoutResetOrderButton => '将顺序恢复为默认值';

  @override
  String get canvasPreviewNavigatorTitle => '画布预览';

  @override
  String get canvasEditMenuPreviewNavigator => '画布预览';

  @override
  String get canvasEditMenuPreviewNavigatorSubtitle => '显示缩小的整体览（导航器）';

  @override
  String get filterCustomMenuDuplicate => '复制';

  @override
  String get filterCustomMenuFavoriteBlockTitle => '无法删除';

  @override
  String get filterCustomMenuFavoriteBlockBody =>
      '该滤镜已收藏为常用，无法删除。请先取消收藏，再进行删除。';

  @override
  String get filterNameThreshold => '二值化滤镜';

  @override
  String get filterMonochromeStrength => '单色化强度';

  @override
  String get filterMonochromeColorLabel => '单色化颜色';

  @override
  String get filterThresholdLabel => '阈值';

  @override
  String get filterNameFisheye => '鱼眼镜头滤镜';

  @override
  String get filterFisheyeStrength => '弯曲强度';

  @override
  String get filterNameChromaticAberration => '色差滤镜';

  @override
  String get filterChromaticAberrationStrength => '偏移强度';

  @override
  String get filterNameLensDistortion => '眼镜断层滤镜';

  @override
  String get filterLensDistortionStrength => '镜片度数（负值为凹透镜，正值为凸透镜）';

  @override
  String get filterLensDistortionOffsetX => '中心位置微调（左右）';

  @override
  String get filterNamePixelate => '像素画滤镜';

  @override
  String get filterNameAuroraHologram => '极光全息';

  @override
  String get filterAuroraHologramStrength => '强度';

  @override
  String get filterAuroraHologramBrightness => '明度';

  @override
  String get filterAuroraHologramSaturation => '饱和度';

  @override
  String get filterAuroraHologramPresetAurora => '极光';

  @override
  String get filterAuroraHologramPresetSoapBubble => '肥皂泡';

  @override
  String get filterAuroraHologramPresetCyberNeon => '赛博霓虹';

  @override
  String get filterAuroraHologramPresetPastelDream => '粉彩梦境';

  @override
  String get filterAuroraHologramPresetSunsetGold => '日落金';

  @override
  String get filterAuroraHologramPresetSilverFoil => '银箔';

  @override
  String get filterNameBackgroundBlend => '背景融入';

  @override
  String get filterBackgroundBlendColorLabel => '融入色';

  @override
  String get filterBackgroundBlendAutoLabel => '自动检测中（点按可手动指定）';

  @override
  String get filterBackgroundBlendAutoReset => '恢复自动';

  @override
  String get filterBackgroundBlendDirection => '阴影与光（联动）的方向';

  @override
  String get filterBackgroundBlendLength => '阴影与光（联动）的长度';

  @override
  String get filterBackgroundBlendBlur => '模糊程度';

  @override
  String get filterPixelateBlockSize => '色块大小';

  @override
  String get filterLensDistortionOffsetY => '中心位置微调（上下）';

  @override
  String get filterLensDistortionNoMaskHint =>
      '仅应用于在选择图层上涂抹的范围。请先在图层列表中添加「选择图层」，并涂抹想要变成镜片的范围（如眼镜镜片部分）。';

  @override
  String get tipsStockingDenierTitle => '丝袜・连裤袜的网眼粗细会随旦数变化';

  @override
  String get tipsStockingDenierDesc =>
      '新增的丝袜・连裤袜色调按照旦数越低（布料越薄）网格间距越密的设定制作，其中最低的10旦特意做得非常细密，根据显示或导出分辨率的不同甚至可能出现摩尔纹。旦数越高的连裤袜间距越宽、显得更不透明，请根据角色的腿部选用合适的一款。';

  @override
  String get tipsFisheyeChromaticTitle => '用鱼眼镜头・色差滤镜营造镜头般的畸变与色边';

  @override
  String get tipsFisheyeChromaticDesc =>
      '鱼眼镜头滤镜会让画面中心膨胀、边缘压缩，重现广角・鱼眼镜头拍摄般的弯曲效果。色差滤镜会让RGB通道略微错开，重现廉价镜头拍摄时常见的彩色边缘。两者都可以作为绘图滤镜（直接应用于图层）和演出滤镜（在时间轴上指定范围应用）使用。';

  @override
  String get tipsLensDistortionTitle => '用选择图层＋眼镜断层滤镜再现度数镜片的光学畸变';

  @override
  String get tipsLensDistortionDesc =>
      '在图层列表中添加「选择图层」，用普通绘图工具涂抹眼镜的镜片部分，即可只对该涂抹范围应用眼镜断层滤镜的局部畸变。度数滑块在负值时呈凹透镜（近视）般缩小，在正值时呈凸透镜（远视）般放大，中心位置也可微调。也可以同时涂抹两片镜片并一次性应用效果。选择图层本身不会出现在导出结果或最终画面中。除了眼镜之外，也可以用来再现透过相机镜头看风景般的畸变效果，建议用选择图层涂抹背景等较大范围，并使用较弱的度数。';

  @override
  String get tipsLineArtExtractionTitle => '组合色调调整・二值化・明度转透明来提取线稿';

  @override
  String get tipsLineArtExtractionDesc =>
      '先用色调调整提高对比度，让线条更突出，再用二值化滤镜把图像分成纯黑白两色，线条就会和其余部分清晰分离。二值化的阈值可以用滑块自由调整，按喜好控制线条的粗细和虚实程度。最后，在图层的三点菜单中使用「明度转透明（灰色）」，让白色部分（线条以外）变为透明，就只剩下线稿了。想从照片或草稿中单独提取线稿时非常实用。';

  @override
  String get tipsLineColorUsageTitle => '根据用途分开使用线稿颜色，效果会更好';

  @override
  String get tipsLineColorUsageDesc =>
      '部件的轮廓线使用颜色描边·线稿融合后，不会与画面脏离，但边界仍然清晰。阴影和高光使用与填色相同的指定色，可以让线稿本身不引人注目；而故意使用不同的指定色，则能营造出该作品独有的世界观与统一感。';

  @override
  String get tipsBlushAutofillTitle => '脸颇的红晖也能用自动填色柔和地上色';

  @override
  String get tipsBlushAutofillDesc =>
      '将线稿色设为透明的指定色，填色设为放射：中心→外侧，并指定脸红色与透明色这两种颜色，就能在皮肤上只叠加脸颇的红晖。调整红晖的不透明度和颜色切换位置，可以让边界更自然地融合。';

  @override
  String get autofillPartResetTraceButton => '恢复默认';

  @override
  String get premiumScreenTitle => 'Premium';

  @override
  String get premiumComparisonPremium => 'Premium';

  @override
  String premiumRegisteredDateLabel(String date) {
    return '注册日期：$date';
  }

  @override
  String premiumNextRenewalDateLabel(String date) {
    return '下次续订日期：$date';
  }

  @override
  String get workspaceApplyCurrentButton => '应用已设置的工作区';

  @override
  String get workspaceAppliedSnackbar => '已应用工作区设置。';

  @override
  String get workspaceSaveAsButton => '将工作区命名保存・覆盖保存';

  @override
  String get workspaceShareButton => '共享工作区';

  @override
  String get workspaceShareSelectTitle => '选择要共享的工作区';

  @override
  String workspaceShareFailedSnackbar(String error) {
    return '共享失败：$error';
  }

  @override
  String get workspaceImportFromFileButton => '从外部文件导入';

  @override
  String workspaceImportFailedSnackbar(String error) {
    return '导入失败：$error';
  }

  @override
  String get workspaceNameRequiredError => '请输入名称。';

  @override
  String get workspaceNoSavedPresets => '还没有已保存的工作区。';

  @override
  String get workspaceOverwriteSelectTitle => '选择要覆盖的工作区';

  @override
  String get workspaceOverwriteConfirmTitle => '确认覆盖';

  @override
  String workspaceOverwriteConfirmBody(String name) {
    return '将用当前设置覆盖「$name」，原有内容将被删除。是否继续？';
  }

  @override
  String get workspaceOverwriteButton => '覆盖保存';

  @override
  String get splashCommunityButtonTitle => 'NIARIM 作品广场';

  @override
  String get splashCommunityButtonSubtitle => '浏览投稿作品';

  @override
  String get splashCreateButton => '制作动画';

  @override
  String get communityScreenTitle => '作品广场';

  @override
  String get communityTabNew => '最新';

  @override
  String get communityTabRanking => '排行榜';

  @override
  String get communityTabFavoriteAuthors => '关注';

  @override
  String get communitySearchHint => '按作品标题、投稿者名搜索';

  @override
  String get communityEmptyState => '暂无作品';

  @override
  String communitySearchNoResults(String query) {
    return '未找到与「$query」匹配的作品';
  }

  @override
  String get communityTagSearchHint => '按标签搜索';

  @override
  String get communityTagSearchModeOnTooltip => '标签搜索：开启（点击可恢复标题・投稿者名搜索）';

  @override
  String get communityTagSearchModeOffTooltip => '切换到标签搜索';

  @override
  String get communityAddTagButton => '添加标签';

  @override
  String get communityAddTagDialogTitle => '添加标签';

  @override
  String get communityAddTagDialogHint => '请输入标签名称';

  @override
  String get communityTagLockTooltip => '锁定该标签（仅限投稿者）';

  @override
  String get communityTagUnlockTooltip => '解除该标签锁定（仅限投稿者）';

  @override
  String get communityRemoveTagTooltip => '删除该标签';

  @override
  String get communityPostButton => '发布';

  @override
  String get communityPostComingSoonTitle => '发布功能正在开发中';

  @override
  String get communityPostComingSoonBody => '视频发布功能目前仍在开发中，敬请期待后续更新。';

  @override
  String get communityPostInfoTitle => '发布将通过YouTube进行';

  @override
  String get communityPostInfoBody =>
      '投稿到作品广场后，作品将通过YouTube公开。NIARIM不具备将作品本体（视频文件）发送、收集或保存到开发者服务器的功能，发布时需要在YouTube的界面上传视频。\n\n如果在YouTube一侧将视频设置为“不公开列出”，该视频就不会出现在YouTube的公开列表中，只会显示在作品广场内。\n\n（视频发布功能目前仍在开发中，敬请期待后续更新。）';

  @override
  String get communityRankingPeriodAllTime => '累计';

  @override
  String get communityRankingPeriodYearly => '年度';

  @override
  String get communityRankingPeriodMonthly => '月度';

  @override
  String get communityRankingPeriodWeekly => '每周';

  @override
  String get communityRankingPeriodDaily => '每日';

  @override
  String get communityRankingSortViews => '播放量';

  @override
  String get communityRankingSortBookmarks => '收藏数';

  @override
  String get communityRankingSortAscendingTooltip => '升序（从少到多）';

  @override
  String get communityRankingSortDescendingTooltip => '降序（从多到少）';

  @override
  String communityWorkDetailPostedLabel(String date) {
    return '发布于$date';
  }

  @override
  String get communityWorkDetailViewOnYoutube => '在YouTube上观看';

  @override
  String get communityWorkDetailViewOnYoutubeComingSoonSnackbar =>
      'YouTube联动功能正在开发中';

  @override
  String get communityWorkDetailBookmarkAdd => '收藏';

  @override
  String get communityWorkDetailBookmarkRemove => '已收藏';

  @override
  String get communityWorkDetailReportButton => '举报';

  @override
  String get communityWorkDetailBlockButton => '屏蔽';

  @override
  String get communityVisibilityCardTitle => '在作品广场的公开状态';

  @override
  String get communityVisibilityPublishedDesc => '公开中：显示在新着、排行榜和该投稿者的作品列表中。';

  @override
  String get communityVisibilityHiddenDesc =>
      '非公开中：已从新着、排行榜和该投稿者的作品列表中隐藏（这是独立于YouTube端公开设置的设置）。';

  @override
  String get communityVisibilityHiddenNotice => '投稿者已将此作品在作品广场设为非公开。';

  @override
  String get communityVisibilityHiddenBadge => '非公开';

  @override
  String get communityWorkDetailTitle => '作品详情';

  @override
  String get communityWorkNotFoundMessage => '未找到该作品';

  @override
  String get communityFloatingPreviewDetailButton => '详情';

  @override
  String get communityFloatingPreviewPlayTooltip => '播放';

  @override
  String get communityFloatingPreviewPauseTooltip => '暂停';

  @override
  String get communityReportDialogTitle => '举报此作品';

  @override
  String get communityReportDialogBody => '请选择举报原因。';

  @override
  String get communityReportReasonInappropriate => '内容不当';

  @override
  String get communityReportReasonCopyright => '疑似侵犯版权';

  @override
  String get communityReportReasonSpam => '垃圾内容・重复发布';

  @override
  String get communityReportReasonOther => '其他';

  @override
  String get communityReportSubmitButton => '提交举报';

  @override
  String get communityReportDetailLabel => '详细说明';

  @override
  String get communityReportDetailHint => '请具体说明存在什么问题';

  @override
  String get communityReportDetailRequiredError => '请输入详细说明';

  @override
  String get communityReportComingSoonSnackbar => '举报功能正在开发中，实际上不会发送。';

  @override
  String communityBlockConfirmTitle(String name) {
    return '要屏蔽“$name”吗？';
  }

  @override
  String get communityBlockConfirmBody => '屏蔽后，该作者的作品将不会出现在你的列表中。';

  @override
  String get communityBlockComingSoonSnackbar => '屏蔽功能正在开发中，实际上不会生效。';

  @override
  String communityAuthorWorksCount(int count) {
    return '$count件作品';
  }

  @override
  String communityAuthorFollowerCount(int count) {
    return '$count位粉丝';
  }

  @override
  String get communityFollowersPublicToggleTitle => '公开关注/粉丝列表';

  @override
  String get communityFollowersPublicToggleDesc =>
      '开启后，其他用户可以在此页面看到你的关注列表和粉丝列表。默认不公开。';

  @override
  String get communityFollowersListTitle => '粉丝';

  @override
  String get communityFollowersListEmpty => '暂无粉丝';

  @override
  String communityFollowersListHiddenNote(int count) {
    return '另有$count人因本人隐私设置未显示';
  }

  @override
  String communityAuthorFollowingCount(int count) {
    return '关注$count人';
  }

  @override
  String get communityFollowingListTitle => '关注中';

  @override
  String get communityFollowingListEmpty => '暂未关注任何人';

  @override
  String get communityFollowNotificationsTooltip => '通知';

  @override
  String get communityFollowNotificationsTitle => '关注通知';

  @override
  String get communityFollowNotificationsEmpty => '暂无通知';

  @override
  String communityFollowNotificationBody(String name) {
    return '$name关注了你';
  }

  @override
  String get communityNoWorksMessage => '暂无作品';

  @override
  String get communityFavoriteAuthorFollow => '关注';

  @override
  String get communityFavoriteAuthorFollowing => '已关注';

  @override
  String get communityFavoriteAuthorsEmptyTitle => '暂无关注的作者';

  @override
  String get communityFavoriteAuthorsEmptyBody =>
      '在喜欢的作者页面点击「关注」，即可在此查看该作者的最新作品。';

  @override
  String get communityRepostButton => '转发';

  @override
  String get communityRepostedButton => '已转发';

  @override
  String communityRepostedByBadge(String name) {
    return '$name转发了';
  }

  @override
  String get communityAuthorTabWorks => '作品';

  @override
  String get communityAuthorTabBookmarks => '收藏';

  @override
  String get communityBookmarksPublicToggleTitle => '公开收藏列表';

  @override
  String get communityBookmarksPublicToggleDesc =>
      '开启后，其他用户可以在此页面看到你的收藏列表。默认不公开。';

  @override
  String get communityBookmarksPrivateNotice => '该用户已将收藏列表设为不公开。';

  @override
  String get communityBookmarksEmptyMessage => '暂无收藏的作品';

  @override
  String get communityShortsBadge => '竖屏';

  @override
  String get communityVideoTypeFilterTooltip => '按视频类型筛选';

  @override
  String get communityVideoTypeFilterAll => '综合';

  @override
  String get communityVideoTypeFilterShortOnly => '仅竖屏';

  @override
  String get communityVideoTypeFilterLongOnly => '仅横屏';

  @override
  String get communityShortsModeTooltip => '以竖屏模式观看';

  @override
  String get communityShortsModeEmptySnackbar => '没有竖屏视频';

  @override
  String get communityShortsModeExitTooltip => '退出竖屏模式';

  @override
  String get pixelColorModeLabel => '配色方式';

  @override
  String get pixelColorModeNone => '不限制颜色';

  @override
  String get pixelColorModePalette => '从调色板选择';

  @override
  String get pixelColorModeExplicit => '指定颜色';

  @override
  String get pixelColorModeCount => '指定颜色数';

  @override
  String pixelColorLevelsLabel(int count) {
    return '颜色数：$count';
  }

  @override
  String get pixelColorChipDeleteTooltip => '删除该颜色';

  @override
  String get pixelColorChipAddButton => '添加颜色';

  @override
  String get pixelArtPaletteNameRequiredError => '请输入调色板名称';

  @override
  String get pixelArtPaletteEditTitle => '编辑调色板';

  @override
  String get pixelArtPaletteAddTitle => '添加调色板';

  @override
  String get pixelArtPaletteNameLabel => '调色板名称';

  @override
  String get pixelArtPalettePickerTitle => '选择调色板';

  @override
  String get pixelArtPalettePickerEmpty => '还没有已保存的调色板。点击“添加”创建一个。';

  @override
  String get pixelArtPalettePickerApplyButton => '应用';

  @override
  String get storageScreenTitle => '释放空间';

  @override
  String get storageDeviceChartTitle => '设备存储空间';

  @override
  String get storageBreakdownChartTitle => 'NIARIM 明细';

  @override
  String get storageActionsTitle => '整理';

  @override
  String get storageCategoryNiarimTotal => 'NIARIM';

  @override
  String get storageCategoryOtherApps => '其他';

  @override
  String get storageCategoryFree => '剩余空间';

  @override
  String get storageCategoryMaterials => '素材';

  @override
  String get storageCategoryProjectData => '项目数据';

  @override
  String get storageCategoryExports => '已导出文件';

  @override
  String get storageCategoryCustomAssets => '自制画笔/网点/图章/字体';

  @override
  String get storageCategoryCache => '缓存';

  @override
  String get storageCategoryTrash => '回收站';

  @override
  String get storageClearCacheButton => '清除缓存';

  @override
  String get storageRemoveUnusedMaterialsButton => '批量删除未使用素材（所有项目）';

  @override
  String get storageEmptyTrashButton => '清空回收站';

  @override
  String get storageOrganizeProjectsButton => '整理项目';

  @override
  String get storageEraseAllButton => '删除全部数据（初始化）';

  @override
  String storageClearCacheDoneSnackbar(String size) {
    return '已清除 $size 缓存';
  }

  @override
  String get storageEraseAllConfirmTitle => '要删除全部数据吗？';

  @override
  String get storageEraseAllConfirmBody =>
      '这将永久删除NIARIM的全部数据——项目、素材、已导出文件、自制画笔/网点/图章/字体及设置。此操作无法撤销。删除后请重启应用。';

  @override
  String get storageEraseAllDoneSnackbar => '已删除全部数据，请重启应用。';

  @override
  String get homeDrawerStorage => '释放空间';

  @override
  String get helpStorageTitle => '释放空间';

  @override
  String get helpStorageDesc =>
      '以饼图查看NIARIM在设备上占用的容量，以及NIARIM内部（项目、素材、已导出文件、自制画笔/网点/图章/字体、缓存、回收站）的详细占比。可以清除缓存、批量删除所有项目中的未使用素材、清空回收站、整理项目，或删除全部数据（初始化）。';

  @override
  String get colorPickerImportPaletteTooltip => '导入调色板';

  @override
  String get colorPickerSharePaletteTooltip => '分享';

  @override
  String get colorPickerShareViaFile => '以文件分享';

  @override
  String colorPickerShareFailedSnackbar(String error) {
    return '分享失败：$error';
  }

  @override
  String get colorPickerShareViaQr => '以二维码分享';

  @override
  String get qrShareTooLargeHint => '颜色过多，无法以二维码分享（请使用文件分享）';

  @override
  String get colorPickerImportViaFile => '从文件选择';

  @override
  String colorPickerImportFailedSnackbar(String error) {
    return '导入失败：$error';
  }

  @override
  String get colorPickerImportViaQr => '粘贴二维码文本';

  @override
  String get qrImportFailedError => '导入失败，请确认文本是否正确。';

  @override
  String get qrImportHint => '请用标准相机应用扫描对方设备上显示的二维码，然后将复制的文本粘贴到此处。';

  @override
  String get qrImportFieldHint => '粘贴扫描到的文本';

  @override
  String get qrImportPasteButton => '从剪贴板粘贴';

  @override
  String get qrImportSubmitButton => '导入';

  @override
  String get qrShareHint => '用标准相机应用扫描此二维码即可复制文本。请在对方设备上使用“导入”粘贴复制的文本。';

  @override
  String get qrShareCopiedSnackbar => '已复制文本';

  @override
  String get qrShareCopyButton => '复制文本';

  @override
  String get toolbarItemBlur => '高斯模糊';

  @override
  String get toolbarItemMosaic => '马赛克';

  @override
  String get toolbarFingerSubtoolWarp => '弯曲';

  @override
  String get brushSettingsEdgeJitterTitle => '边缘渗漏';

  @override
  String get brushSettingsEdgeJitterSubtitle => '轻微粗糙化边缘，模拟墨水渗漏效果';

  @override
  String get brushSettingsEdgeJitterStrengthLabel => '渗漏强度';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get homeTabProjects => '專案';

  @override
  String get homeTabShared => '共享';

  @override
  String get homeTabTrash => '垃圾桶';

  @override
  String get homeTabWorks => '作品列表';

  @override
  String get homeTabBookmarked => '已收藏';

  @override
  String get homeBookmarkedComingSoonTitle => '敬請期待';

  @override
  String get homeBookmarkedComingSoonBody =>
      '「觀看大家的動畫」功能上線後，您收藏的其他使用者公開作品會顯示在這裡。';

  @override
  String get homeSearchHint => '依專案名稱搜尋';

  @override
  String get homeBackToSplashTooltip => '返回啟動畫面';

  @override
  String get homeFavoritesOnly => '我的最愛';

  @override
  String get homeAddSheetNewProject => '新增專案';

  @override
  String get homeAddSheetNewFolder => '新增資料夾';

  @override
  String get homeSelectionAllSelect => '全選';

  @override
  String get homeSelectionAllDeselect => '取消全選';

  @override
  String get homeSelectionAddFavorite => '加入收藏';

  @override
  String get homeSelectionRemoveFavorite => '取消收藏';

  @override
  String homeSelectionCount(int count) {
    return '已選擇$count項';
  }

  @override
  String get homeMoveToTrash => '移至垃圾桶';

  @override
  String homeMoveToTrashConfirm(int count) {
    return '要將$count項移至垃圾桶嗎？';
  }

  @override
  String get commonMove => '移動';

  @override
  String get homeShareFileDialogTitle => '共享檔案';

  @override
  String get homeShareFileDialogContent => '要複製這個共享檔案並另存為一般專案嗎？';

  @override
  String homeMissingFontsSnackbar(String names) {
    return '缺少字型：$names';
  }

  @override
  String get homeSharedImportedSnackbar => '已新增至專案分頁';

  @override
  String homeSharedImportFailedSnackbar(String error) {
    return '讀取共享檔案失敗：$error';
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
  String get homeSortFieldName => '名稱';

  @override
  String get homeSortFieldUpdated => '更新時間';

  @override
  String get homeSortDirectionAscTooltip => '遞增（點一下切換為遞減）';

  @override
  String get homeSortDirectionDescTooltip => '遞減（點一下切換為遞增）';

  @override
  String get homeSharedEmpty => '沒有共享的專案';

  @override
  String homeProjectMeta(int fps, int duration) {
    return '${fps}fps · $duration秒';
  }

  @override
  String get homeTrashEmpty => '垃圾桶是空的';

  @override
  String homeTrashDeletedOn(String date) {
    return '$date 已刪除';
  }

  @override
  String get homePermanentDelete => '永久刪除';

  @override
  String get homePermanentDeleteConfirmTitle => '確定要永久刪除嗎？';

  @override
  String get homePermanentDeleteConfirmBody => '此操作無法復原。';

  @override
  String get homeWorksEmpty => '還沒有匯出的作品';

  @override
  String get homeWorksEmptyHint => '從畫布匯出影片或GIF後，\n將顯示在這裡';

  @override
  String get homeShareOpenWith => '分享・用相片App等開啟';

  @override
  String homeWorkDeleteConfirmTitle(String name) {
    return '要刪除$name嗎？';
  }

  @override
  String get homeWorkDeleteConfirmBody => '裝置中的匯出檔案將被刪除，此操作無法復原。';

  @override
  String get homePreviewFailed => '無法播放預覽';

  @override
  String get homeFirstLaunchMessage => '您可以製作手繪動畫';

  @override
  String get homeFirstLaunchStart => '開始使用';

  @override
  String get settingsScreenTitle => '設定';

  @override
  String get settingsBasicTitle => '基本';

  @override
  String get settingsBasicSubtitle => 'FPS・背景色・語言';

  @override
  String get settingsBasicSheetTitle => '基本設定';

  @override
  String get settingsDefaultFps => '預設FPS';

  @override
  String get settingsDefaultFpsSubtitle => '新增專案畫面的初始值';

  @override
  String get settingsLanguage => '語言';

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
  String get settingsSearchHint => '搜尋設定...';

  @override
  String get settingsPerformanceTitle => '效能';

  @override
  String get settingsPerformanceSubtitle => '畫質設定・復原次數・垃圾桶・運作速度';

  @override
  String get settingsGestureTitle => '手勢';

  @override
  String get settingsGestureSubtitle => '雙指點按・長按';

  @override
  String get settingsPenTitle => '筆輸入';

  @override
  String get settingsPenSubtitle => '筆壓・傾斜・筆按鈕';

  @override
  String get settingsWorkspaceTitle => '工作區';

  @override
  String get settingsWorkspaceSubtitle => '工具列編輯・面板配置';

  @override
  String get settingsBucketTitle => '油漆桶填色';

  @override
  String get settingsBucketSubtitle => '容差・擴張・潛入線稿下方';

  @override
  String get settingsThemeTitle => '主題・外觀';

  @override
  String get settingsThemeSubtitle => '主題設定・工作區';

  @override
  String get settingsWatermarkTitle => '浮水印';

  @override
  String get settingsWatermarkSubtitle => '自訂浮水印';

  @override
  String get settingsTransferTitle => '資料轉移';

  @override
  String get settingsTransferSubtitle => '將設定・素材・筆刷匯出/匯入到其他裝置';

  @override
  String get settingsFontTitle => '字型管理';

  @override
  String get settingsFontSubtitle => '新增・搜尋・刪除TTF/OTF字型';

  @override
  String get settingsNoResults => '找不到相關設定項目';

  @override
  String get settingsTermsLicense => '使用條款・授權';

  @override
  String get settingsDrawingAreaTitle => '繪圖區域初始值';

  @override
  String get settingsDrawingAreaHint => '將作為新增專案時的初始值。';

  @override
  String get settingsDrawingAreaWiden => '擴大繪圖區域';

  @override
  String get settingsDrawingAreaScale => '倍率';

  @override
  String settingsScaleValue(String scale) {
    return '$scale倍';
  }

  @override
  String get commonCancel => '取消';

  @override
  String get commonCreate => '建立';

  @override
  String get commonChange => '變更';

  @override
  String get commonDelete => '刪除';

  @override
  String get confirmDeleteGenericBody => '確定要刪除嗎？此操作無法復原。';

  @override
  String confirmDeleteNamedBody(String name) {
    return '要刪除「$name」嗎？此操作無法復原。';
  }

  @override
  String get commonFavoriteDeleteBlocked => '已收藏的項目無法刪除，請先取消收藏。';

  @override
  String get commonSave => '儲存';

  @override
  String get commonRestore => '復原';

  @override
  String get commonClose => '關閉';

  @override
  String get commonRename => '重新命名';

  @override
  String get commonCopy => '複製';

  @override
  String get commonCut => '剪下';

  @override
  String get commonPaste => '貼上';

  @override
  String get commonDuplicate => '複製';

  @override
  String homePasteTooltip(int count) {
    return '貼上$count項';
  }

  @override
  String get homePasteSnackbar => '已貼上';

  @override
  String get commonOk => '確定';

  @override
  String get gestureSettingsTitle => '手勢設定';

  @override
  String get gestureTwoFingerTap => '雙指點按';

  @override
  String get gestureThreeFingerTap => '三指點按';

  @override
  String get gestureTwoFingerSwipe => '雙指左右滑動';

  @override
  String get gestureLongPress => '長按';

  @override
  String get gestureHoldEyedropperSection => '長按取色';

  @override
  String get gestureHoldEyedropperTitle => '長按啟動取色';

  @override
  String get gestureHoldEyedropperHint =>
      '使用畫筆或橡皮擦繪圖時，手指不動按住一段時間即可拾取該處顏色並設為目前顏色。';

  @override
  String get gestureHoldEyedropperDurationLabel => '保持時長';

  @override
  String gestureHoldEyedropperSecondsValue(String seconds) {
    return '$seconds秒';
  }

  @override
  String get gestureActionEyedropper => '滴管';

  @override
  String get gestureActionPanTool => '手形工具';

  @override
  String get gestureActionEraserToggle => '切換橡皮擦';

  @override
  String get gestureActionBrushToggle => '切換筆刷';

  @override
  String get gestureActionFrameMove => '切換影格';

  @override
  String get gestureActionNextTool => '快速切換工具';

  @override
  String get gestureActionOnionSkinToggle => '洋蔥皮開/關';

  @override
  String get gestureActionNone => '不執行任何動作';

  @override
  String get homeDrawerAppTagline => '手繪動畫製作App';

  @override
  String get homeDrawerAutofillPreset => '自動上色設定';

  @override
  String get homeDrawerSettings => '設定';

  @override
  String get homeDrawerHelp => '說明';

  @override
  String get homeDrawerTips => '使用技巧';

  @override
  String get homeDrawerPremium => 'Premium';

  @override
  String get gestureActionNoneShort => '無';

  @override
  String get pressureTryDrawHint => '可以用此設定試畫看看（使用觸控筆時會反映實際筆壓）';

  @override
  String get pressureTryDrawClear => '清除';

  @override
  String get penSettingsTitle => '筆輸入設定';

  @override
  String get penSettingsCurveSection => '筆壓曲線';

  @override
  String get penSettingsCurveHint => '設定越弱，筆壓的起始越平緩；設定越強，起始越陡峭。';

  @override
  String get penSettingsCurveWeak => '弱';

  @override
  String get penSettingsCurveNormal => '普通';

  @override
  String get penSettingsCurveStrong => '強';

  @override
  String get penSettingsCurveCustom => '自訂';

  @override
  String get penSettingsCustomGraphHint =>
      '點擊圖表空白處新增控制點（最多10個），拖曳控制點移動，雙擊可刪除（起點和終點無法刪除）。';

  @override
  String get penSettingsResetCurveButton => '重設為預設值';

  @override
  String get penSettingsPerBrushNote =>
      '※筆壓「反映到大小/不透明度」的設定為各筆刷個別設定（於筆刷設定面板中變更）。';

  @override
  String get penSettingsButtonSection => '筆按鈕設定';

  @override
  String get penSettingsButton1 => '按鈕1';

  @override
  String get penSettingsButton2 => '按鈕2';

  @override
  String get bucketSettingsTitle => '油漆桶填色設定';

  @override
  String get bucketSettingsToleranceSection => '容差';

  @override
  String get bucketSettingsToleranceHint =>
      '調整與點擊位置顏色的差異在多大範圍內仍視為同一區域。數值越大，即使顏色邊界模糊也更容易擴散填色。';

  @override
  String get bucketSettingsExpandSection => '擴張';

  @override
  String get bucketSettingsExpandHint => '將填色區域向外擴張指定像素數，用於覆蓋與線稿之間的細小縫隙（漏填部分）。';

  @override
  String get bucketSettingsUnderLineTitle => '潛入線稿下方';

  @override
  String get bucketSettingsUnderLineHint =>
      '擴張部分不會直接覆蓋線稿，而是在保持線條外觀的同時，將填色繪製到現有像素的背後，減少線條反鋸齒邊緣處出現的縫隙。';

  @override
  String get bucketSettingsUnderLineDisabledHint => '當「擴張」為0px時無效果。';

  @override
  String fontCatalogSearchHint(int count) {
    return '以字型名稱搜尋...（共$count種字型）';
  }

  @override
  String get fontCatalogAll => '全部';

  @override
  String get fontCatalogNoResults => '找不到相符的字型';

  @override
  String get rulerPanelTitle => '尺規';

  @override
  String get rulerTypeLine => '直線尺';

  @override
  String get rulerTypeEllipse => '橢圓尺';

  @override
  String get rulerTypeRadial => '集中線尺';

  @override
  String get rulerTypeOnePoint => '一點透視';

  @override
  String get rulerTypeTwoPoint => '兩點透視';

  @override
  String get rulerTypeThreePoint => '三點透視';

  @override
  String get rulerDivisions => '分割數';

  @override
  String get transferScreenTitle => '資料轉移（.niatra）';

  @override
  String get transferInstructionHint => '請選擇要轉移到其他裝置的項目。';

  @override
  String get transferItemSettings => '設定';

  @override
  String get transferItemMaterials => '素材';

  @override
  String get transferItemBrush => '筆刷';

  @override
  String get transferItemPresets => '自動上色設定';

  @override
  String get transferItemTheme => '主題';

  @override
  String get transferItemPalette => '調色盤（取色器・像素畫專用）';

  @override
  String get transferProjectsSectionTitle => '製作中的專案（可選）';

  @override
  String get transferProjectsHint => '只需選擇要包含在轉移內容中的專案。所選專案將連同素材與字型一起完整轉移。';

  @override
  String get transferProjectsEmpty => '尚無專案。';

  @override
  String get transferImport => '匯入';

  @override
  String get transferExport => '匯出';

  @override
  String get transferExportSuccessSnackbar => '已匯出.niatra檔案';

  @override
  String transferExportFailedSnackbar(String error) {
    return '匯出失敗：$error';
  }

  @override
  String get transferImportSuccessSnackbar => '已匯入.niatra檔案';

  @override
  String transferImportFailedSnackbar(String error) {
    return '匯入失敗：$error';
  }

  @override
  String get folderManagementTitle => '資料夾管理';

  @override
  String get folderManagementCreateNew => '新增';

  @override
  String get folderManagementEmpty => '還沒有資料夾';

  @override
  String get folderNameLabel => '資料夾名稱';

  @override
  String get folderMoveToTitle => '移至資料夾';

  @override
  String get folderNone => '無資料夾';

  @override
  String get creativeAssetNameLabel => '名稱';

  @override
  String get commonAdd => '新增';

  @override
  String get commonSearch => '搜尋';

  @override
  String get autofillPresetSelectionTitle => '要使用的自動上色設定';

  @override
  String get autofillPresetSelectionHint =>
      '只選擇本專案中使用的自動上色設定，可以讓分配部位時的清單更簡潔、更易於檢視。';

  @override
  String autofillPresetSelectionPartCount(int count) {
    return '$count個部件';
  }

  @override
  String get autofillPresetSelectionButton => '選擇要使用的自動上色設定';

  @override
  String autofillPresetSelectionCountLabel(int count) {
    return '已選$count個';
  }

  @override
  String get commonEdit => '編輯';

  @override
  String get commonFavoriteToggle => '切換我的最愛';

  @override
  String get commonIncrease => '增加';

  @override
  String get commonDecrease => '減少';

  @override
  String get commonPlay => '播放';

  @override
  String get commonPause => '暫停';

  @override
  String get fontCatalogDownloadTooltip => '下載字型';

  @override
  String get timelineBackToCanvasTooltip => '儲存並返回畫布';

  @override
  String get timelineBackToProjectListTooltip => '返回專案列表';

  @override
  String get timelineBackToProjectListDialogTitle => '返回專案列表';

  @override
  String get timelineBackToProjectListDialogBody => '要先儲存變更再返回嗎？';

  @override
  String get timelineBackToProjectListSaveButton => '儲存並返回';

  @override
  String get timelineBackToProjectListDiscardButton => '不儲存直接返回';

  @override
  String get timelineSkipToStart => '跳到第一幀';

  @override
  String get timelineStepBack => '後退一幀';

  @override
  String get timelineStepForward => '前進一幀';

  @override
  String get timelineSkipToEnd => '跳到最後一幀';

  @override
  String get timelineLoopOnTooltip => '循環播放：開啟（點一下關閉）';

  @override
  String get timelineLoopOffTooltip => '循環播放：關閉（點一下開啟）';

  @override
  String get quickToolPanelTitle => '快速切換工具設定';

  @override
  String get quickToolEmpty => '尚未登錄任何工具';

  @override
  String get quickToolAddCurrentBrush => '新增目前的筆刷';

  @override
  String get quickToolEraser => '橡皮擦';

  @override
  String get quickToolEyedropper => '滴管';

  @override
  String get quickToolBucket => '油漆桶';

  @override
  String quickToolSizeDialogTitle(String brushName) {
    return '$brushName的大小';
  }

  @override
  String get settingsShortcutTitle => '快捷鍵設定';

  @override
  String get settingsShortcutSubtitle => '為鍵盤・左手裝置分配工具與操作';

  @override
  String get shortcutSettingsTitle => '快捷鍵設定';

  @override
  String get shortcutSettingsHint =>
      '可以為鍵盤或左手裝置的按鍵分配工具（可細到具體畫筆和粗細）或復原/取消復原等操作。畫布模式、時間軸模式皆可使用。';

  @override
  String get shortcutEmpty => '尚未註冊任何快捷鍵';

  @override
  String get shortcutCaptureTitle => '請按下按鍵';

  @override
  String get shortcutCaptureHint =>
      '請按下想要設定的按鍵組合（可同時按住Ctrl・Shift・Alt等輔助鍵）。按Esc取消。';

  @override
  String shortcutChooseActionTitle(String combo) {
    return '要為$combo分配什麼？';
  }

  @override
  String get shortcutActionTypeTool => '選擇工具';

  @override
  String get shortcutActionTypeCommand => '主要操作';

  @override
  String get shortcutCommandUndo => '復原';

  @override
  String get shortcutCommandRedo => '取消復原';

  @override
  String get shortcutCommandToggleLayerPanel => '切換圖層面板（畫布）';

  @override
  String get shortcutCommandPlayPause => '播放/暫停（時間軸）';

  @override
  String get shortcutCommandPreviousFrame => '後退1畫格（時間軸）';

  @override
  String get shortcutCommandNextFrame => '前進1畫格（時間軸）';

  @override
  String get shortcutCommandSelectAll => '全選';

  @override
  String get shortcutCommandCopy => '複製';

  @override
  String get shortcutCommandCut => '剪下';

  @override
  String get shortcutCommandPaste => '貼上';

  @override
  String get shortcutConflictTitle => '該按鍵已被分配';

  @override
  String shortcutConflictBody(String combo, String existingLabel) {
    return '$combo已經分配給了「$existingLabel」。要覆蓋嗎？';
  }

  @override
  String get shortcutConflictOverwrite => '覆蓋';

  @override
  String get materialListTitle => '素材管理';

  @override
  String materialRemoveUnused(int count) {
    return '刪除未使用素材（$count）';
  }

  @override
  String get materialEmptyTitle => '沒有素材';

  @override
  String get materialEmptyHint => '從時間軸新增圖片・影片・音訊後，\n將顯示在這裡';

  @override
  String get materialUsedLabel => '使用中';

  @override
  String get materialUnusedLabel => '未使用';

  @override
  String get materialMissingLabel => '⚠ 缺少';

  @override
  String get materialDeleteTooltipUsed => '使用中，無法刪除';

  @override
  String get materialRemoveOneConfirmTitle => '要刪除該素材嗎？';

  @override
  String get materialRemoveUnusedConfirmTitle => '要批次刪除未使用的素材嗎？';

  @override
  String get materialRemoveUnusedConfirmBody => '將刪除專案中未被任何地方參照的全部素材。此操作無法復原。';

  @override
  String materialRemovedSnackbar(int count) {
    return '已刪除$count個未使用素材';
  }

  @override
  String get watermarkEmptyTitle => '還沒有登錄的浮水印';

  @override
  String get watermarkEmptyHint => '點擊右下角的+新增圖片或文字浮水印';

  @override
  String get watermarkAddFromImage => '從圖片新增';

  @override
  String get watermarkAddText => '輸入文字';

  @override
  String get watermarkAddedSnackbar => '已新增浮水印';

  @override
  String get watermarkTextDialogTitle => '新增文字浮水印';

  @override
  String get watermarkTextFieldLabel => '要顯示的文字';

  @override
  String get watermarkTextColorLabel => '文字顏色';

  @override
  String get watermarkTextColorTapHint => '點擊選擇顏色';

  @override
  String get watermarkDropShadowLabel => '投影';

  @override
  String get watermarkShadowColorLabel => '陰影顏色';

  @override
  String get watermarkShadowOffsetXLabel => '陰影位置X';

  @override
  String get watermarkShadowOffsetYLabel => '陰影位置Y';

  @override
  String get watermarkShadowBlurLabel => '陰影模糊';

  @override
  String get watermarkOutlineLabel => '描邊';

  @override
  String get watermarkOutlineColorLabel => '描邊顏色';

  @override
  String get watermarkOutlineWidthLabel => '描邊粗細';

  @override
  String get premiumActiveLabel => 'Premium已啟用';

  @override
  String get premiumVsTitle => '免費版 vs 付費版';

  @override
  String get premiumHeroTitle => '開通進階版，創作更自由';

  @override
  String get premiumHeroSubtitle => '無時長上限、無浮水印、色調曲線／色階校正等功能全部解鎖';

  @override
  String get premiumHeroHighlightDuration => '時長最長2小時';

  @override
  String get premiumHeroHighlightWatermark => '無水印';

  @override
  String get premiumHeroHighlightGrading => '色調曲線 /\n階調調整';

  @override
  String get premiumCampaignFreeNote => '※ 活動期間，免費版也可使用以上全部付費功能';

  @override
  String get premiumPlanSectionTitle => '方案';

  @override
  String get premiumStoreUnavailable => '無法連接到商店（僅可於實機或商店審核環境中購買）';

  @override
  String get premiumYearlyTitle => '年繳方案（推薦）';

  @override
  String get premiumYearlyDescription => '相當於2個月免費';

  @override
  String get premiumYearlyPrice => '¥5,500/年';

  @override
  String get premiumYearlyOriginalPrice => '¥6,600';

  @override
  String get premiumYearlyPerMonthLabel => '折合每月¥458';

  @override
  String get premiumMonthlyTitle => '月繳方案';

  @override
  String get premiumRestorePurchases => '恢復購買';

  @override
  String get premiumRestoredSnackbar => '已恢復購買資訊（如有對應的購買紀錄）';

  @override
  String get premiumCampaignBannerTitle => '上線紀念！付費會員限定功能開放活動';

  @override
  String get premiumCampaignBannerBody =>
      '活動期間，免費版也可免費使用全部付費功能（長度最長2小時・片尾標誌編輯・浮水印・色調曲線・色階校正）。';

  @override
  String premiumCampaignEndLabel(String date) {
    return '至$date止';
  }

  @override
  String get premiumComparisonFeature => '功能';

  @override
  String get premiumComparisonFree => '免費';

  @override
  String get premiumFeatureDrawing => '動畫製作・繪圖功能';

  @override
  String get premiumFeatureTimeline => '時間軸';

  @override
  String get premiumFeatureExport => '影片匯出';

  @override
  String get premiumFeatureMaxDuration => '最長長度';

  @override
  String get premiumFeatureEndLogo => '官方片尾標誌';

  @override
  String get premiumFeatureWatermark => '浮水印';

  @override
  String get premiumFeatureToneCurve => '色調曲線';

  @override
  String get premiumFeatureLevelCorrection => '色階校正';

  @override
  String get premiumFeatureAds => '廣告';

  @override
  String get premiumFeatureCommunityUpload => '作品廣場每日投稿數';

  @override
  String get premiumValueYes => '有';

  @override
  String get premiumValueNo => '無';

  @override
  String get premiumValueRemovable => '可刪除';

  @override
  String get premiumValueDuration2Hours => '2小時';

  @override
  String get premiumValueDuration90Sec => '1.5分鐘';

  @override
  String get premiumValueUploadFree => '1個';

  @override
  String get premiumValueUploadPremium => '3個';

  @override
  String get premiumPlanRecommendedBadge => '推薦';

  @override
  String get premiumMonthlyPrice => '¥550/月';

  @override
  String get toolbarItemPen => 'G筆';

  @override
  String get toolbarItemEraser => '橡皮擦';

  @override
  String get toolbarItemBucket => '油漆桶';

  @override
  String get toolbarItemEyedropper => '滴管';

  @override
  String get toolbarItemFinger => '手指';

  @override
  String get toolbarItemPan => '手掌';

  @override
  String get toolbarItemSelect => '選取';

  @override
  String get toolbarItemTransform => '變形';

  @override
  String get toolbarItemText => '文字';

  @override
  String get toolbarItemShape => '圖形';

  @override
  String get workspaceScreenTitle => '工作區設定';

  @override
  String get workspaceToolbarEditSection => '工具列編輯';

  @override
  String get workspaceToolbarEditHint => '以核取方塊選擇要顯示的工具，並可拖曳調整順序。';

  @override
  String get workspaceToolbarPcOnlyHint => '僅在橫屏時顯示於工具列';

  @override
  String get workspaceToolbarPanDisabledHint => '手機模式下無法使用';

  @override
  String get workspaceResetToolbarDefault => '回復預設';

  @override
  String get workspacePanelLayoutSection => '面板配置';

  @override
  String get workspaceLeftHandedMode => '左手模式';

  @override
  String get workspaceLeftHandedSubtitlePc => '將面板置於右側';

  @override
  String get workspaceLeftHandedSubtitleMobile => '僅可於PC/DeX模式下設定';

  @override
  String get workspacePcModeSection => 'PC模式（DeX）';

  @override
  String get workspacePcModeHint => '在寬螢幕環境下會自動切換為面板固定排列的專業版面配置。若要手動固定，請於此處指定。';

  @override
  String get workspacePcModeAuto => '自動（依螢幕寬度判斷・建議）';

  @override
  String get workspacePcModeAlwaysPc => '永遠使用PC模式';

  @override
  String get workspacePcModeAlwaysMobile => '永遠使用手機模式';

  @override
  String get workspaceSaveSection => '儲存工作區';

  @override
  String get workspaceSaveHint => '可將左手模式・PC模式・工具列・快速切換工具設定命名儲存，之後隨時叫出。';

  @override
  String get workspaceLoadButton => '載入工作區';

  @override
  String get workspaceEmptyToolbar => '沒有要顯示的工具';

  @override
  String get workspaceSaveDialogTitle => '儲存工作區';

  @override
  String get workspaceSaveDialogLabel => '名稱（例：動畫用・線稿用）';

  @override
  String get workspaceLoadRightHanded => '右手';

  @override
  String get workspaceLoadLeftHanded => '左手';

  @override
  String get helpScreenTitle => '說明';

  @override
  String get helpSearchHint => '搜尋...';

  @override
  String get helpNoResults => '找不到相符的項目';

  @override
  String get helpCategoryTool => '工具';

  @override
  String get helpCategoryLayer => '圖層';

  @override
  String get helpCategoryAnimation => '動畫';

  @override
  String get helpCategoryDrawing => '繪圖';

  @override
  String get helpCategoryBrush => '筆刷';

  @override
  String get helpCategoryPenInput => '筆輸入';

  @override
  String get helpCategorySave => '儲存';

  @override
  String get helpCategoryProjectManagement => '專案管理';

  @override
  String get helpCategoryExport => '匯出';

  @override
  String get helpCategoryPremium => 'Premium';

  @override
  String get helpCategorySettings => '設定';

  @override
  String get helpCategoryCommunity => '社群';

  @override
  String get helpPenToolTitle => '筆工具';

  @override
  String get helpPenToolDesc =>
      '在畫布上繪製線條的基本工具。長按可變更筆刷種類・粗細・顏色（雙擊顯示簡易說明）。支援數位板/液晶數位板的筆壓與傾斜，於設定畫面的「筆輸入」中調整筆壓曲線，可細緻自訂筆壓的反映方式（輕壓時粗細/不透明度會有多少變化）。切換筆的子工具後，還能以同一支筆工具進行貼網點・放置印章。';

  @override
  String get helpEraserToolTitle => '橡皮擦工具';

  @override
  String get helpEraserToolDesc =>
      '與筆工具相對，用來擦除已繪製的內容。與筆刷一樣可以調整粗細與不透明度，淡出、筆畫衰減等筆刷設定也同樣適用。它進行的是「擦除」既有繪製內容，而不是在圖層的透明部分「加畫」，因此下方圖層會透出顯示。';

  @override
  String get helpBucketToolTitle => '油漆桶工具';

  @override
  String get helpBucketToolDesc =>
      '一次性填滿被包圍的區域。在線稿所圍成的區域內點擊，整個區域就會被填滿為目前選擇的顏色（或網點）。若線稿有縫隙，顏色可能會擴散到意料之外的範圍，因此使用前請確認線稿是否已完全封閉。可在設定中切換純色填滿/網點填滿。 詳細設定（容差・擴張px・潛入線稿下方）可在設定畫面的「油漆桶填色」中調整。';

  @override
  String get helpLassoFillTitle => '套索填色';

  @override
  String get helpLassoFillDesc =>
      '用手指沿想要包圍的範圍畫出多邊形區域，然後一次性填滿其內部的工具。與油漆桶不同，即使線稿有未封閉的部分，也可以自行指定要包圍的範圍，因此適合形狀複雜或線條中斷處的上色。';

  @override
  String get helpEyedropperToolTitle => '滴管工具';

  @override
  String get helpEyedropperToolDesc =>
      '擷取點擊位置的顏色並將其設為繪圖色的工具。它擷取的是畫面上實際顯示的所有圖層合成後的顏色，因此即使在多個圖層重疊的部分，也能準確取得「肉眼所見的顏色」。';

  @override
  String get helpSelectToolTitle => '選取工具';

  @override
  String get helpSelectToolDesc =>
      '選取畫布的一部分範圍，僅對所選範圍進行移動・旋轉・縮放的工具。長按可以從「矩形選取」「套索選取（自由形狀包圍）」「自動選取（魔術棒，自動合併相近顏色的範圍）」三種選取方式中選擇。選取中會在畫布上顯示表示所選範圍的框線，在取消選取之前，所有影格・所有圖層都會固定顯示相同的範圍。';

  @override
  String get helpFingerToolTitle => '手指工具（扭曲工具）';

  @override
  String get helpFingerToolDesc =>
      '沿手指劃動的方向推擠像素使其扭曲，營造出用手指塗抹濕顏料般的效果。相較於精細修正，更常用於將已畫好的線條進行有機的扭曲以增添表現力。';

  @override
  String get helpShapeToolTitle => '圖形工具';

  @override
  String get helpShapeToolDesc =>
      '一鍵繪製直線・矩形・圓形等精確圖形的工具。從起點拖曳到終點時會即時預覽，放開手指即可確定。在難以徒手畫出直線或正圓時非常方便。';

  @override
  String get helpTextToolTitle => '文字工具';

  @override
  String get helpTextToolDesc =>
      '在畫布上放置文字的工具。可選擇字型・大小・顏色・直排/橫排。直排時還支援半形英數字的自動旋轉・縱中橫（數字保持橫向排列的表記）・注音標示（類似日文振假名的讀音標示）。放置的文字在匯出時也會作為像素燒錄進畫面。 可新增・搜尋・刪除文字工具可用字型的畫面。除初始內建字型外的其他免費字型，為控制初始安裝容量，需從此處按需下載。';

  @override
  String get helpQuickToolTitle => '快速切換工具';

  @override
  String get helpQuickToolDesc =>
      '預先登記常用的畫筆・工具組合，只需點擊一個按鈕即可依序切換。長按或向上滑動畫布上的↺按鈕，即可開啟可以新增、排序、刪除的管理彈窗。可透過拖曳改變順序。';

  @override
  String get helpLayerTitle => '圖層';

  @override
  String get helpLayerDesc =>
      '將一塊畫布分成多個透明「圖層」來繪製的機制。將線稿、上色、背景等分別繪製在不同圖層上，之後可以只重做上色，或在不擦除線稿的情況下更換背景。畫面中，疊得越靠上的圖層顯示在越靠前的位置。每個圖層行的圖示可一鍵刪除或與下方圖層合併，圖層面板頂部的圖示還可以一次性合併所有可見圖層。';

  @override
  String get helpBlendModeTitle => '混合模式';

  @override
  String get helpBlendModeDesc =>
      '用於變更圖層與下方圖層的合成方式，常用於疊加網點或顏色效果的圖層。\n正常：直接疊加。\n色彩增值：與下方圖層相乘後變暗，是陰影表現的經典手法。\n濾色：疊加亮度後變亮，適合表現光效。\n覆蓋：暗部更暗、亮部更亮，增強對比度。\n線性加亮（增加）：直接相加顏色，適合光效線條等。\n差異化減去：相減顏色，呈現暗沉的效果。\n變暗：取上下兩圖層中較暗的顏色。\n變亮：取上下兩圖層中較亮的顏色。\n顏色加深：使下方顏色變暗並加深發色。\n顏色減淡：使下方顏色變亮並加深發色。\n實光：比覆蓋更強烈的對比效果。\n柔光：比覆蓋更柔和的對比效果，適合柔和的陰影。\n差異化：顯示上下兩色的差異，可用於檢查顏色偏差等。\n色相、飽和度、顏色、明度：分別僅將該圖層的色相、飽和度、色彩或明度反映到下方圖層。';

  @override
  String get helpClippingTitle => '剪裁遮罩';

  @override
  String get helpClippingDesc =>
      '使繪製內容僅限於緊鄰下方圖層的不透明像素範圍內的功能。當想要在不超出線稿的範圍內上色時，於線稿圖層上方新增上色圖層並啟用剪裁遮罩，就不必擔心不小心畫到線稿外面。';

  @override
  String get helpCommonLayerTitle => '共用圖層';

  @override
  String get helpCommonLayerDesc =>
      '一般圖層依每個影格獨立存在，而共用圖層則是在多個影格・場景中共享同一內容的圖層。像背景這類不隨影格變化而移動的元素，無需每格重新繪製，只需畫一次即可。在時間軸上會以專用軌道的形式顯示。 可以把一般圖層轉換為共用圖層（在多個影格中持續顯示相同內容的圖層）的功能。也可以先把目前顯示的圖層合併為一張，再進行共用化。想反覆使用背景等每影格內容相同的部分時，可以省去重新繪製的麻煩。';

  @override
  String get helpAutoFillTitle => '自動上色';

  @override
  String get helpAutoFillDesc =>
      '在自動上色專用線稿圖層下方建立自動上色圖層，並依據預先製作的「自動上色設定」（各部位的顏色、網點組合）自動進行上色的功能。由於可以在畫完線稿後一次性上色，能大幅減少需要反覆繪製同一角色的手繪動畫中的上色工作量。重新繪製線稿後，時間軸和圖層面板會顯示更新標記（❗），提示需要重新執行自動上色。在時間軸畫面的三點選單中選擇「執行自動上色」，即可一次性重新計算所有帶有更新標記（❗）的自動上色圖層，省去重新繪製線稿後逐個圖層在圖層面板中執行的麻煩。自動上色設定的每個部位都有關於如何處理線稿顏色的設定（指定顏色、與填充色相同、色彩描邊）。選擇色彩描邊（貼合線稿）後，線稿顏色會按HSL偏移以符合填充色，使線條不顯突兀、自然融合。設定越積越多，分配部位時顯示的清單就會變長、難以瀏覽。可以在專案設定（或圖層面板的部位分配對話框）中，將清單篩選為只顯示本專案使用的設定，讓清單更簡潔、更易於挑選。';

  @override
  String get helpOnionSkinTitle => '洋蔥皮';

  @override
  String get helpOnionSkinDesc =>
      '將目前編輯影格前後的影格以半透明方式疊加顯示，讓你可以一邊確認動作的連貫性一邊繪製的功能。可以在效能設定中調整顯示的影格數（前後各顯示幾張）以及顏色・透明度。';

  @override
  String get helpRulerTitle => '尺規';

  @override
  String get helpRulerDesc =>
      '直線・圓・橢圓・透視尺規（使用消失點的透視圖法專用尺規）等，用於輔助繪製徒手難以畫出的精確線條的功能。放置的尺規會使筆尖自動吸附，即使是沒有尺規就難以繪製的具有縱深感的構圖也會更容易畫出。尺規可以透過操作控制點進行移動・旋轉・調整大小。';

  @override
  String get helpFadeTitle => '淡出';

  @override
  String get helpFadeDesc =>
      '筆刷設定之一，隨著筆畫持續繪製，不透明度或粗細會逐漸減少的效果。用於想讓線條末端產生漸隱感，或想營造帶有餘韻的筆觸時。';

  @override
  String get helpStrokeDecayTitle => '筆畫衰減';

  @override
  String get helpStrokeDecayDesc =>
      '與淡出類似，但更接近「墨水逐漸用盡」的表現，繪製越久顏色越淡或越乾澀的效果。可重現毛筆或麥克筆持續書寫時墨水耗盡般的質感。';

  @override
  String get helpColorMixingTitle => '混色';

  @override
  String get helpColorMixingDesc =>
      '使用筆刷上色時，將筆刷正下方已有的顏色與即將塗上的選定顏色混合後再繪製的功能。適合想讓新顏色與既有顏色自然融合時使用，如水彩或油畫般的效果。';

  @override
  String get helpPressureCurveTitle => '筆壓曲線';

  @override
  String get helpPressureCurveDesc =>
      '筆輸入設定中的功能，可透過圖表自由調整實際筆壓強度與筆刷粗細・不透明度反映方式之間的關係。無論是希望輕壓也能畫出粗線的人，還是相反希望必須用力按壓才會變粗的人，都能依自己的用筆習慣細緻自訂畫感。變更設定後可當場試畫確認效果。';

  @override
  String get helpTimelineTitle => '時間軸';

  @override
  String get helpTimelineDesc =>
      '管理動畫時間軸的畫面。將影格（單張靜止影像）排列並像翻頁動畫一樣播放，就形成了動畫。圖片・影片・音訊等素材軌道、共用圖層軌道、攝影機關鍵影格也都在同一條時間軸上管理。';

  @override
  String get helpSceneTitle => '場景';

  @override
  String get helpSceneDesc =>
      '將一個專案（一段影片）內部按場景（分鏡）劃分管理的功能。資料夾是以專案為單位進行整理，而場景則用於表現一段影片內部的場景轉換。在時間軸的場景標籤中可以新增、複製、刪除、重新命名、重新排序場景。切換到多選模式後，還可以一次性移動、複製或刪除多個場景。';

  @override
  String get helpCameraKeyframeTitle => '攝影機關鍵影格';

  @override
  String get helpCameraKeyframeDesc =>
      '在時間軸上的特定位置記錄攝影機的位置・縮放比例・旋轉角度的功能。關鍵影格之間會自動平滑內插，因此可以輕鬆加入平移（橫向移動）或拉近拉遠等鏡頭運動。';

  @override
  String get helpEffectFilterTitle => '演出濾鏡';

  @override
  String get helpEffectFilterDesc =>
      '可套用於場景或影格的畫面效果（模糊・色調校正・光暈・像素化等）。在不改變手繪畫面本身的前提下，作為演出手段調整整個畫面觀感時使用。像素化也可以選擇配色方式（不指定顏色・指定顏色・指定顏色數・從調色盤選擇）。 演出濾鏡可以疊加套用多個，其套用順序依照時間軸上的排列順序。拖曳濾鏡清單重新排序後，實際反映到畫面上的順序也會隨之改變。 一種演出濾鏡，會逐影格改變類似膠片顆粒感的雜訊。可以用滑桿調整強度、數量（雜訊出現的密度）和顆粒大小。回到同一影格時雜訊形態相同（拖曳時不會閃爍），播放時顆粒則會呈現出跳動的效果。 用來表現畫面中降雨的演出濾鏡。可以用滑桿調整降雨強度（雨滴數量）、速度、雨滴大小和風向角度。每滴雨都會隨著影格數推進以固定速度持續落下，呈現自然的降雨效果。';

  @override
  String get helpEndCardTitle => 'EndCard（片尾標誌）';

  @override
  String get helpEndCardDesc =>
      '匯出影片時，會在正片結尾自動加入的NIARIM標誌短片（約5秒）。免費版無法隱藏或刪除，但成為Premium會員後可以開關顯示・變更長度・進行替換。';

  @override
  String get helpAutoSaveTitle => '自動儲存';

  @override
  String get helpAutoSaveDesc =>
      '專用於當機或檔案損毀時復原的儲存。每次繪圖等發生變更時都會自動儲存，最多保留3份，依由舊到新的順序覆寫。它與手動儲存（儲存槽・儲存樹）完全分開管理，不能取代一般儲存。僅在App異常結束後重新啟動時，才會詢問是否要復原。';

  @override
  String get helpSaveSlotTitle => '儲存槽';

  @override
  String get helpSaveSlotDesc =>
      '在固定數量的儲存位（槽）中，由自己選擇儲存位置進行儲存的方式。槽位數量由設定決定（低畫質5個・中畫質10個）。由於每次都需要自己選擇要覆寫的槽位，適合「想保留這個時間點的狀態」這類管理方式。';

  @override
  String get helpSaveTreeTitle => '儲存樹';

  @override
  String get helpSaveTreeDesc =>
      '每次儲存都會建立一個新的儲存點，並可以從過去的儲存點分支出另一段歷史（分叉）的儲存方式。沒有數量上限，適合「想回到那個版本後再嘗試另一種發展」這類用法。畫面上儲存點會以從下往上生長的樹狀圖形式顯示。';

  @override
  String get helpFolderTitle => '資料夾';

  @override
  String get helpFolderDesc =>
      '將專案（作品）分組整理的功能。支援多層級結構，因此也可以用來統一管理同一作品的多個話數或系列作品（例如：在「作品名」資料夾中依序排列「第1話」「第2話」……等專案）。若想在一部動畫內劃分場景，請使用畫布畫面中的「場景」功能，而不是資料夾。';

  @override
  String get helpTrashTitle => '垃圾桶';

  @override
  String get helpTrashDesc =>
      '已刪除專案暫時移動到的地方。在被永久刪除之前，都可以從這裡復原。可以在設定中指定自動刪除的天數（關閉/30天/60天/90天）。';

  @override
  String get helpShareTitle => '共享（.niashare）';

  @override
  String get helpShareDesc =>
      '用於將專案傳遞給他人（或自己的其他裝置）的專用共享檔案格式。接收方開啟此檔案後，會複製並新增到自己的專案列表中。共享來源的.niashare檔案本身不會被變更。';

  @override
  String get helpTransferTitle => '資料轉移（.niatra）';

  @override
  String get helpTransferDesc =>
      '將設定、素材、筆刷、自動上色設定、主題、調色盤（取色器・像素畫專用）等整個應用程式環境一次性轉移到其他裝置的功能。可以透過核取方塊個別選擇要轉移的項目。如果想傳遞單一專案，請改用「共用（.niashare）」。';

  @override
  String get helpVideoExportTitle => '影片匯出（MP4・WebM・GIF）';

  @override
  String get helpVideoExportDesc =>
      '將作品匯出為通用MP4影片。免費版可匯出的長度有上限（90秒），且會在影片結尾自動加入片尾卡（應用程式Logo）。 可在保留Alpha色版（背景透明部分）的情況下匯出的影片格式。僅在支援的播放環境中才能透明播放。適合作為素材疊加到其他App中使用。 匯出為動畫GIF。由於會自動循環播放，適合在社群媒體上輕鬆分享的場景。 如果更重視相容性，也可以匯出為AVI（Motion JPEG）。所採用的編碼器在專利與授權方面較為安全，但不支援Alpha色版（透明），部分裝置上App內預覽可能無法使用（此時仍可透過「分享」用外部播放器播放）。 免費會員的專案長度上限為90秒（付費會員為2小時）。如果新增或複製影格會超過上限，在點擊按鈕的瞬間就會顯示提示對話框，因此實際上不會超過90秒。';

  @override
  String get helpTransparentWebmTitle => '透明WebM';

  @override
  String get helpCommunityTitle => '作品廣場';

  @override
  String get helpCommunityDesc =>
      '可以將動畫・插畫作品以YouTube影片的形式發佈到社群，並瀏覽其他使用者的作品。可以切換「最新」「排行榜」「追蹤」三個分頁，也可以依作品標題或投稿者名稱搜尋。切換到標籤搜尋模式後可依標籤篩選作品，標籤不僅投稿者本人，其他使用者也可以自由新增或刪除（投稿者鎖定的標籤只能由投稿者本人解鎖），點擊標籤即可篩選出相同標籤的作品。點擊作品卡片會開啟可拖曳、可調整大小的浮動預覽視窗，可以在繼續操作其他畫面的同時觀看。點擊「查看詳情」按鈕可開啟作品詳情畫面（投稿者、發佈日期、標籤編輯、收藏、轉發等）。點擊投稿者名稱旁的「追蹤」按鈕即可將其加入追蹤清單，「追蹤」分頁會依時間順序彙整顯示該作者的作品。有人追蹤你時，會顯示在畫面右上角鈴鐺圖示的通知清單中。你可以分別設定自己的追蹤清單/粉絲清單是否對所有使用者公開（預設為非公開），也可以查看已公開的其他使用者的清單。除自己發佈的作品外，都可以用「轉發」按鈕轉發；當追蹤的作者轉發了他人的作品時，該作品也會以「發佈日期」和「轉發日期」中較新的一方為基準，混入「追蹤」分頁中顯示（卡片上會顯示「○○轉發了」）。收藏的作品會彙整顯示在主畫面的「已收藏」分頁中，也可以在投稿者作品清單畫面的「收藏」分頁中查看。可以設定自己的收藏清單是否對其他使用者公開（預設不公開），也可以查看已設為公開的其他使用者的收藏清單。對不當作品可以附上理由進行檢舉，檢舉送出後會詢問你是否要封鎖該投稿者。直向影片可以在「直向模式」中連續播放觀看。每日可發佈的作品數量有上限，免費會員每天1個，進階會員每天3個。';

  @override
  String get helpWatermarkEntryTitle => '浮水印';

  @override
  String get helpWatermarkEntryDesc =>
      '可以在匯出的影片・圖片上加入自己簽名或Logo作為浮水印的進階會員專屬功能。可以調整位置、大小、不透明度。點擊時間軸共用圖層軌道上放置的浮水印，隨時都能重新編輯其角度、大小、不透明度、顯示範圍（循環顯示）——不僅是首次設定時，在專案中實際使用時也能隨時細緻調整。';

  @override
  String get helpPremiumEntryTitle => 'Premium';

  @override
  String get helpPremiumEntryDesc =>
      '成為進階會員後，免費版限制的90秒影片長度將延長至最長2小時，並可移除每支影片結尾自動加入的片尾卡（應用程式Logo）。同時廣告也會隱藏，還可使用浮水印、色調曲線、色階校正功能。';

  @override
  String get helpPerformanceSettingsTitle => '效能設定';

  @override
  String get helpPerformanceSettingsDesc =>
      '可依裝置效能從低畫質・中畫質・高畫質預設中選擇，也可逐項單獨設定（自訂）。除儲存方式・運作速度・洋蔥皮・傾斜偵測外，復原次數、垃圾桶自動刪除等影響App容量與運作負擔的設定也都集中在這裡。';

  @override
  String get helpMaterialClipTitle => '素材片段（圖片・影片・音訊）';

  @override
  String get helpMaterialClipDesc =>
      '放置在時間軸圖片、影片、音訊軌道上的片段。長按拖曳片段本身可移動其起始位置，拖曳兩端的把手可改變使用範圍（長度）。點擊片段會開啟詳細面板，其中的複製圖示用於複製、垃圾桶圖示用於刪除。圖片・影片在內部作為圖層處理，音訊則作為直接掛在場景上的片段管理。';

  @override
  String get helpGestureSettingsTitle => '手勢設定';

  @override
  String get helpGestureSettingsDesc =>
      '可以將復原/重做、跳至影格、取色器等操作指派給雙指點擊、三指點擊、雙指滑動或長按。觸控筆按鍵（在支援的觸控筆上）也可以單獨指派操作。想不切換工具就用一個動作觸發常用操作時很方便。';

  @override
  String get helpBucketDetailSettingsTitle => '填色工具詳細設定';

  @override
  String get helpBucketDetailSettingsDesc =>
      '在設定畫面的「填色工具」中可以調整容許誤差（點擊位置的顏色相差多少仍視為同一區域）、擴充px（填色區域向邊界外擴展多少以填補線稿的縫隙）以及潛入線條下方（不覆蓋線稿本身，而是把擴充部分合成到既有像素的背後，藉此保持線條外觀不變）。當線稿有細小縫隙或填色感覺不完整時，調整這些設定能讓效果更穩定。';

  @override
  String get helpStampToolTitle => '印章工具';

  @override
  String get helpStampToolDesc =>
      '把預先登記的圖片像筆刷一樣放置到畫布上。特效線、背景圖案、小物件等不用每次重畫就能反覆使用。開啟像素模式後，貼上的印章會透過馬賽克降解析度＋減少色數處理成像素畫風格。 在印章面板中可以調整所放置印章的旋轉角度和大小。即使是同一個印章，改變方向和大小放置，也能讓特效線、小物件的排列不顯得單調而更自然。';

  @override
  String get helpToneFillTitle => '網點上色';

  @override
  String get helpToneFillDesc =>
      '在填色工具的設定中把純色填滿切換為網點填滿，就能用選中的網點、線條等網點圖案進行填滿。還提供像素模式專用的方格紋、格子紋網點，可以做出符合像素畫質感的上色效果。';

  @override
  String get helpPixelModeTitle => '像素模式';

  @override
  String get helpPixelModeDesc =>
      '筆刷、字型、印章各自都提供的設定，開啟後會去除反鋸齒，呈現清晰的像素畫風輪廓。想刻意做出老遊戲般的質感，或想營造低解析度效果時使用。配色方式可從「不指定顏色」「指定顏色」「指定顏色數」「從調色盤選擇」4種中選擇，也可以使用像素畫專用調色盤。';

  @override
  String get helpHomeScreenTitle => '首頁';

  @override
  String get helpHomeScreenDesc =>
      '啟動App後最先顯示的畫面，可在專案、共用、作品清單、垃圾桶各標籤間切換檢視。右上角的搜尋圖示可依專案名稱篩選。在專案標籤頁中，可透過懸浮按鈕選擇新增專案或新增資料夾。';

  @override
  String get helpNewProjectTitle => '新增專案';

  @override
  String get helpNewProjectDesc =>
      '在建立專案前，統一設定畫布尺寸、fps、長度（以秒為單位，之後會與時間軸上的影格增減連動）、繪製區域（可以在匯出範圍之外多畫一些的設定）、要使用的自動上色設定等。';

  @override
  String get helpThemeSettingsTitle => '主題設定';

  @override
  String get helpThemeSettingsDesc =>
      '可以從主題清單中選擇App整體的配色，也可以自由自訂強調色。標題・項目名稱用字型與說明文字用字型是分開的，能在保持可讀性的同時享受換裝樂趣。';

  @override
  String get helpWorkspaceSettingsTitle => '工作區設定';

  @override
  String get helpWorkspaceSettingsDesc =>
      '彙集了左手模式（左右翻轉停靠面板）、手動切換電腦/DeX模式、手掌工具顯示條件等設定的畫面。可以依所用裝置和慣用手調整成更方便操作的版面。';

  @override
  String get helpPenSettingsTitle => '畫筆設定';

  @override
  String get helpPenSettingsDesc =>
      '除了數位板・數位螢幕的筆壓曲線外，這個設定畫面還能把切換橡皮擦、取色器等操作指派給支援的觸控筆側邊按鍵。';

  @override
  String get helpMaterialListTitle => '素材清單';

  @override
  String get helpMaterialListDesc =>
      '可以統一檢視專案中使用的圖片、影片、音訊素材的畫面。放置在時間軸上的素材的原始檔案都彙集在這裡。';

  @override
  String get helpFrameOperationsTitle => '影格操作';

  @override
  String get helpFrameOperationsDesc =>
      '在影格清單中，除了新增、複製、刪除之外，還可以在多選模式下一次移動、複製、刪除多個影格。增加保留格數可以讓同一影格持續顯示多個格子（即所謂的「停格」），從而在動作較少的鏡頭中節省作畫張數。';

  @override
  String get helpSceneOperationsTitle => '場景操作';

  @override
  String get helpSceneOperationsDesc =>
      '在時間軸的場景標籤頁中，可以新增、複製、刪除、重新命名、重新排序場景。切換到多選模式後，還可以一次移動、複製、刪除多個場景。';

  @override
  String get helpQuickToolManagementTitle => '快捷工具管理';

  @override
  String get helpQuickToolManagementDesc =>
      '登記一組常用工具組合，只需點一下即可依序切換。長按或向上滑動可開啟管理彈出視窗，編輯已登記的內容和順序。';

  @override
  String get helpTransformSelectionTitle => '變形選取範圍';

  @override
  String get helpTransformSelectionDesc =>
      '用選取工具圈出的範圍，可以用變形工具進行移動、旋轉、縮放。適合用來調整誤畫部分的位置，或只放大強調某一部分。 若想變形整個圖層，可以使用不需選取範圍的「自由變形・網格變形」（從編輯選單開啟），能單獨拖曳各個網格點做出更自由的變形。';

  @override
  String get helpGradientAutofillTitle => '漸層上色（自動上色設定）';

  @override
  String get helpGradientAutofillDesc =>
      '自動上色設定的每個部位不僅可以使用單色，還可以設定漸層。可拖曳的對稱控制點讓你直覺地調整漸層的範圍和角度。每個部件還可以設定「用指定顏色描邊」。勾選後，會在填色範圍的最外側（緊貼線稿的部分）畫出指定顏色和粗細的線條。描邊顏色可透過取色器自由選擇，粗細可透過滑桿、±按鈕或點擊數字直接輸入來調整。設定項上方會顯示預覽，可以在實際執行自動上色之前確認顏色和粗細。';

  @override
  String get helpColorPickerTitle => '取色器';

  @override
  String get helpColorPickerDesc =>
      '可在同一畫面中切換HSV與RGB來選色的取色器。調色盤功能可儲存、叫出正在使用的配色組合。調色盤也可以透過檔案匯出或QR code與其他裝置共享。';

  @override
  String get helpUndoSettingsTitle => '復原次數設定';

  @override
  String get helpUndoSettingsDesc =>
      '在效能設定中可以調整復原能回溯的操作次數。次數越多越能放心地反覆嘗試，但也會佔用更多記憶體；在低效能裝置上減少次數可以讓運作更輕快。';

  @override
  String get helpBrushFavoriteTitle => '筆刷收藏';

  @override
  String get helpBrushFavoriteDesc =>
      '點擊筆刷清單中筆刷上的星形圖示即可加入或取消收藏（與應用程式內其他收藏功能——自動上色設定、圖章、字型、繪圖濾鏡等——操作方式相同）。清單頂部的星形圖示還可以篩選為僅顯示收藏項目。已收藏的筆刷不會被誤刪。';

  @override
  String get helpCustomBrushTitle => '自訂筆刷';

  @override
  String get helpCustomBrushDesc =>
      '在筆刷清單中長按預裝筆刷並選擇「複製」，即可基於它建立專屬自訂筆刷。複製後的筆刷可以自由編輯粗細、不透明度、硬度、旋轉、密度、散佈、模糊半徑等參數，不需要時也可以刪除（預裝筆刷本身無法編輯或刪除）。還可以用資料夾分類，或用星標圖示收藏。';

  @override
  String get helpLayerFolderTitle => '圖層資料夾';

  @override
  String get helpLayerFolderDesc =>
      '可以把多個圖層整理到資料夾中的功能。即使是部件較多的插畫，也能讓圖層面板保持清晰易看。剪裁無法跨資料夾套用，如果要使用剪裁，建議把相關圖層放在同一個資料夾內。';

  @override
  String get helpLayerMultiSelectTitle => '圖層多選・批次操作';

  @override
  String get helpLayerMultiSelectDesc =>
      '使用圖層面板的選取模式，可以用勾選框一次選取多個圖層進行合併或批次刪除。合併只能在一般圖層、自動上色用線稿、自動上色圖層之間進行（共用圖層、資料夾、時間軸素材不能合併）。';

  @override
  String get helpDrawingAreaTitle => '作畫區域';

  @override
  String get helpDrawingAreaDesc =>
      '可以在比匯出範圍更大的區域內作畫的設定。畫布上會顯示表示匯出範圍的紅色邊框，畫到邊框外的部分不會被匯出，但可以為之後用推拉鏡頭等運鏡方式調整所展示的範圍留出餘地。在新增專案時設定放大倍率。';

  @override
  String get helpCanvasBackgroundTitle => '畫布背景色';

  @override
  String get helpCanvasBackgroundDesc =>
      '可以設定專案畫布的背景色。使用透明匯出（透明WebM）時背景色不會影響匯出結果，但可以改成自己喜歡的顏色，方便作畫時檢視。';

  @override
  String get helpProjectDetailTitle => '專案詳情畫面';

  @override
  String get helpProjectDetailDesc =>
      '可以在一個畫面中集中檢視、編輯專案名稱、縮圖、收藏狀態、要啟用的自動上色設定篩選等專案相關設定。存檔樹的入口也在這裡。';

  @override
  String get helpWatermarkEditTitle => '重新編輯浮水印';

  @override
  String get helpWatermarkEditDesc =>
      '點擊放置在時間軸共用圖層軌道上的浮水印，隨時可以重新編輯其角度、大小、不透明度、顯示範圍（循環顯示）。不僅在登記時，在專案中實際使用時也能隨時細部調整。';

  @override
  String get helpAudioClipTitle => '音訊片段的音量・淡入淡出';

  @override
  String get helpAudioClipDesc =>
      '放置在時間軸上的音訊片段，可以在詳細面板中調整音量、淡入、淡出的秒數。可用來調整音效和配樂的音量平衡，或讓曲子的開頭、結尾更加順暢。';

  @override
  String get helpPenSubToolTitle => '畫筆子工具';

  @override
  String get helpPenSubToolDesc =>
      '長按畫筆工具，可以從一般繪圖切換到網點填色或印章放置等子工具。不用每次切換工具，就能用同一支筆在多種作業之間來回操作。';

  @override
  String get helpTiltDetectionTitle => '傾斜偵測';

  @override
  String get helpTiltDetectionDesc =>
      '利用支援的觸控筆的傾斜資訊，在筆尖傾斜放倒時讓線條變粗或變淡，重現更接近實際畫具的書寫手感的設定。可以在效能設定中開關。';

  @override
  String get helpFontImportTitle => '字型讀取';

  @override
  String get helpFontImportDesc =>
      '可以直接讀取裝置內的字型檔案來使用的功能。可在設定畫面字型管理的「讀取」標籤頁中新增。想使用未公開發布的自製字型或已購買的商用字型時可以使用此功能。';

  @override
  String get helpExportScreenTitle => '匯出畫面';

  @override
  String get helpExportScreenDesc => '匯出影片、圖片期間會顯示進度，也可以中途取消。所需時間會依裝置效能而異。';

  @override
  String get helpDrawingFilterTitle => '繪圖濾鏡';

  @override
  String get helpDrawingFilterDesc =>
      '直接套用於所選圖層的濾鏡（與套用於整條時間軸或整個場景的演出濾鏡不同，繪圖濾鏡按圖層生效）。包含模糊、銳化、USM銳化、色調曲線、色階、暗角、雜訊、復古動畫、映像管、動畫風、外框、像素化等。外框不會改寫原圖層，只會把外框後的結果繪製到一個新圖層上。像素化也可以選擇配色方式（不指定顏色・指定顏色・指定顏色數・從調色盤選擇）。';

  @override
  String get helpLayerKeyframeTitle => '圖層關鍵影格（分部件動畫）';

  @override
  String get helpLayerKeyframeDesc =>
      '依影格設定每個圖層的位置・縮放・旋轉，關鍵影格之間會自動內插。攝影機關鍵影格移動的是整個畫面，而這個功能只移動單一圖層。由於自動上色的每個部件都會生成為獨立的圖層，因此可以直接用它來做分部件動畫（只動一隻手臂、只讓嘴巴開合等）。每個關鍵影格還可以單獨設定「等速」「緩入」「緩出」「緩入緩出」「彈跳」這類緩動（與下一個關鍵影格的銜接方式），不僅限於單調的等速移動，還能表現出彈跳般的動作。在圖層面板的三點選單「動畫（關鍵影格）」中設定。圖層本身的畫面內容不會改變，只是顯示位置改變的非破壞性變形。這個功能只影響時間軸的顯示（預覽・匯出），不會影響畫布模式下的實際作畫。';

  @override
  String get helpLayerGroupTitle => '圖層群組（把多個部件一起移動）';

  @override
  String get helpLayerGroupDesc =>
      '用同一組關鍵影格把多個圖層一起移動的功能。例如「手臂」由皮膚、袖子兩個自動上色部件組成時，把這兩個圖層分到同一群組後，只需一次關鍵影格操作就能讓它們一起移動。在圖層面板中多選（勾選框）圖層，再點擊底部工具列的「群組化」圖示即可建立。群組的運動會疊加在每個成員圖層自身的關鍵影格（如果設定了的話）之上，因此可以把群組整體的運動和單一圖層的微調結合起來使用。一個圖層同時只能屬於一個群組。';

  @override
  String get tipsScreenTitle => '使用技巧';

  @override
  String get tipsSearchHint => '搜尋技巧...';

  @override
  String get tipsCategoryVideo => '影片製作技巧';

  @override
  String get tipsCategoryEfficiency => '提高製作效率的技巧';

  @override
  String get tipsCategoryDrawing => '讓作畫更流暢的技巧';

  @override
  String get tipsCategoryEffects => '演出與收尾的技巧';

  @override
  String get tipsCategoryExport => '匯出與操作技巧';

  @override
  String get tipsClipDuplicateTitle => '時間軸上的素材也能複製、移動、刪除';

  @override
  String get tipsClipDuplicateDesc =>
      '點擊圖片、影片或音訊素材可開啟詳細面板，點擊其中的複製圖示即可複製該素材。反覆使用同一段音效，或把同一張圖片重新放到不同場景，只需長按拖曳加上一次複製按鈕就能完成。';

  @override
  String get tipsTextCaptionTitle => '用文字工具加入字幕';

  @override
  String get tipsTextCaptionDesc =>
      '使用文字工具可以逐格放入字幕或註解文字。將字型切換為像素模式，還能為文字營造出復古遊戲般的質感。';

  @override
  String get tipsAutofillPresetTitle => '按部位預先登記自動上色設定';

  @override
  String get tipsAutofillPresetDesc =>
      '按皮膚、頭髮、衣服等部位預先登記好含陰影的自動上色設定，只需畫好線稿就能自動完成大部分上色。也可以按專案篩選要使用的設定。';

  @override
  String get tipsAutofillBaseCoatTitle => '自動上色也可以只當作一張單色底色圖層來用';

  @override
  String get tipsAutofillBaseCoatDesc =>
      '自動上色本來是用來按部位分別上色的功能，但不必細緻地劃分部位，只要用一個單色設定把整張線稿當作一張底色圖層來塗，也已經很方便了。它能一次性把線內全部塗滿，可以防止手動用油漆桶塗色時常見的漏塗（線條縫隙露出下層顏色的失誤）。之後再在上面手動疊加顏色，就能不花分部位的功夫，也能獲得自動上色的好處。';

  @override
  String get tipsBrushFavoriteTitle => '把常用筆刷加入我的最愛，切換時不用再找';

  @override
  String get tipsBrushFavoriteDesc =>
      '把常用的筆刷點擊清單中的星形圖示加入收藏。清單頂端的星形圖示可以篩選為只顯示收藏，減少尋找的麻煩。收藏中的筆刷無法被誤刪。';

  @override
  String get tipsPressureCurveTitle => '把筆壓曲線調整成適合自己的手感';

  @override
  String get tipsPressureCurveDesc =>
      '設定畫面中的筆壓曲線最多可以自由加入10個控制點。如果覺得力道反應不太合適，可以依自己的下筆習慣來調整。';

  @override
  String get tipsExportFormatTitle => '依用途選擇匯出格式';

  @override
  String get tipsExportFormatDesc =>
      '想輕鬆發到社群平台時用GIF匯出，想疊加到其他影片上或保留透明背景時用透明WebM，想作為一般影片使用時用MP4匯出。依用途區分使用，更容易在檔案大小與畫質之間取得平衡。';

  @override
  String get tipsGestureShortcutTitle => '用手勢把常用操作變成一觸即達';

  @override
  String get tipsGestureShortcutDesc =>
      '在設定畫面的「手勢」中，可以把復原/重做或取色器指派給雙指點擊、三指點擊或長按。不用切換工具，就不會打亂作畫的節奏。';

  @override
  String get tipsAudioRepeatTitle => '用複製片段×淡入淡出讓音效更有節奏感';

  @override
  String get tipsAudioRepeatDesc =>
      '想反覆使用同一段音效時，複製片段並錯開時間排列，再分別設定淡入淡出，就能做出有節奏感的自然音效連擊。';

  @override
  String get tipsVerticalRubyTitle => '直書×注音打造標題Logo風效果';

  @override
  String get tipsVerticalRubyDesc =>
      '在文字工具中把直書和注音（furigana）組合使用，可以做出和風標題Logo或有個性的標題效果。半形英數字會自動橫向旋轉排列，即使混入符號或數字也能保持易讀。';

  @override
  String get tipsBrushTrySaveTreeTitle => '新的筆刷設定先用儲存樹試試看';

  @override
  String get tipsBrushTrySaveTreeDesc =>
      '想大幅改動筆刷粗細或穩定化等設定時，改動前先儲存到儲存樹會更安心。如果效果不滿意，可以立刻回到之前的狀態，更容易大膽嘗試各種調整。';

  @override
  String get tipsEyedropperGestureTitle => '把取色器綁定到雙指點擊，保持配色不跑掉';

  @override
  String get tipsEyedropperGestureDesc =>
      '在手勢設定中把取色器指派給雙指點擊，就能不切換工具、立即吸取附近的顏色。想保持角色配色統一地繼續上色時很方便。';

  @override
  String get tipsRulerOnionTitle => '透視尺×洋蔥皮，重複利用背景';

  @override
  String get tipsRulerOnionDesc =>
      '先用透視尺定好背景的縱深，再一邊用洋蔥皮透視前後影格，一邊只移動角色，就不用每一影格都重新畫背景了。';

  @override
  String get tipsGradientTraceTitle => '漸層自動上色×色彩描摹，讓色彩更自然融合';

  @override
  String get tipsGradientTraceDesc =>
      '在自動上色設定中使用漸層時，將線稿顏色設定為色彩描邊（貼合線稿），線稿顏色就會隨漸層的細微色彩變化而變化，使邊界不易顯得突兀。';

  @override
  String get tipsGradientOutlineHairTitle => '漸層×指定顏色描邊，讓瀏海呈現透明感';

  @override
  String get tipsGradientOutlineHairDesc =>
      '在自動上色設定中建立瀏海部件，將填色設為漸層，選擇髮色和透明色這兩種顏色。將角度改為90度，依喜好調整羽化強度和顏色切換位置後，勾選「用指定顏色描邊」，並從「最近使用的顏色」中選擇與剛才瀏海相同的顏色作為描邊色。不僅瀏海的底色部件，陰影色部件也重複同樣的步驟，就能做出髮梢透亮的透明感頭髮。';

  @override
  String get tipsRainNoiseTitle => '下雨×動態雜訊，營造濕潤的空氣感';

  @override
  String get tipsRainNoiseDesc =>
      '在下雨濾鏡上疊加較弱的動態雜訊濾鏡，除了雨滴本身，還能加上空氣中的顆粒感，營造出濕潤的雨天質感。';

  @override
  String get tipsPartKeyframeGroupTitle => '部件關鍵影格×分組，讓角色一起跳動';

  @override
  String get tipsPartKeyframeGroupDesc =>
      '給自動上色的各個部件加上圖層關鍵影格使其運動，再把相關部件分組讓它們一起跳動，不用重新繪製就能做出隨音樂搖擺的迷你動畫。';

  @override
  String get tipsLowSpecSettingsTitle => '低效能裝置請重新檢查效能設定和復原次數';

  @override
  String get tipsLowSpecSettingsDesc =>
      '如果感覺運作卡頓，可以把效能設定切換為「低畫質」預設，同時減少復原次數。這樣能降低記憶體佔用，有時能讓運作更輕快。';

  @override
  String get tipsSeriesPresetFolderTitle => '系列作品用自動上色設定篩選×資料夾整理來管理';

  @override
  String get tipsSeriesPresetFolderDesc =>
      '製作同一作品的多集時，用資料夾按集數歸類專案，並為每個專案篩選要使用的自動上色設定，這樣就不會混淆各角色的配色，工作效率也更高。';

  @override
  String get tipsPixelToneRetroTitle => '印章像素模式×網點上色，統一復古感';

  @override
  String get tipsPixelToneRetroDesc =>
      '把像素模式的印章和像素模式專用的方格紋、格子紋網點組合使用，可以讓整個畫面統一呈現像素畫質感。適合復古遊戲風的演出。';

  @override
  String get tipsMagicWandLassoTitle => '魔術棒選取×套索上色，提高分色效率';

  @override
  String get tipsMagicWandLassoDesc =>
      '先用選取工具的自動選取（魔術棒）一次選中大致範圍，再用套索選取只調整超出的部分，即使是複雜的分色也能快速完成。';

  @override
  String get tipsCommonLayerFolderTitle => '共用圖層×資料夾，跨集數重複使用';

  @override
  String get tipsCommonLayerFolderDesc =>
      '系列作品中每集都會用到的Logo或字幕，做成共用圖層後整理進資料夾，複製到新一集的專案時也能輕鬆處理。';

  @override
  String get tipsStrokeDecayFadeTitle => '筆觸衰減×淡出，做出毛筆般的表現';

  @override
  String get tipsStrokeDecayFadeDesc =>
      '同時啟用筆刷設定中的筆觸衰減和淡出，線條的起筆、收筆會自然變細，畫出如毛筆或墨水筆般富有輕重變化的線條。';

  @override
  String get tipsColorMixingFadeTitle => '混色×淡出，做出類似顏料的融合感';

  @override
  String get tipsColorMixingFadeDesc =>
      '在開啟混色的筆刷上再加上淡出，會與底色融合的同時逐漸變淡，更接近真實顏料的上色手感。';

  @override
  String get tipsOutlineAnimeStyleTitle => '外框×動畫風，做出賽璐璐動畫質感';

  @override
  String get tipsOutlineAnimeStyleDesc =>
      '用繪圖濾鏡的外框把輪廓線畫到新圖層上，再用動畫風濾鏡減少色數，就能做出賽璐璐動畫般清晰俐落的效果。';

  @override
  String get tipsLevelsToneCurveTitle => '色階×色調曲線，打造平面設計風格';

  @override
  String get tipsLevelsToneCurveDesc =>
      '先用色階把明暗對比調得較強，再用色調曲線細緻調整層次，可以做出脫離照片式層次感、類似海報的平面設計風格。';

  @override
  String get tipsMosaicChromaticTitle => '馬賽克×色差，營造老式映像管的粗糙質感';

  @override
  String get tipsMosaicChromaticDesc =>
      '先用馬賽克降低解析度，再疊加色差效果，能營造出像在看老式映像管電視般的粗糙質感，與單獨使用映像管濾鏡的效果又有所不同。';

  @override
  String get tipsEndCardWatermarkTitle => '浮水印是你的簽名，片尾卡是另一回事';

  @override
  String get tipsEndCardWatermarkDesc =>
      '想在影片中加入自己的簽名或標記時，請使用浮水印功能。片尾卡是應用程式自動顯示在每支影片結尾的自帶Logo，免費會員無法更改；進階會員可以隱藏它，或替換成自己的影片、圖片。如果不想使用片尾卡而想自製專屬的結尾效果，只要新增圖片圖層並搭配淡入淡出，就能自行還原類似的效果。';

  @override
  String get tipsVerticalPixelFontTitle => '實拍影片×手繪作畫，打造「實拍×動畫」';

  @override
  String get tipsVerticalPixelFontDesc =>
      '正因為這款App兼具插畫App和影片剪輯App的雙重身分，才能玩出這種手法。把實拍影片片段放到時間軸上，在其上方圖層用洋蔥皮一邊參考一邊手繪特效線或角色，就能做出實拍畫面疊加手繪動畫的「實拍×動畫」混合媒體影片。';

  @override
  String get tipsTimelineMarkerTitle => '對齊聲音與嘴形的時間點，交給時間戳記';

  @override
  String get tipsTimelineMarkerDesc =>
      '場景處理的是「開始～結束影格的範圍」，而時間戳記則是為「那一瞬間」加上備註、並可一鍵跳轉的功能。像「第120格配音效」「第180格對嘴形『啊』」這樣，在同一個場景範圍內打上多個時間戳記，就能大幅提升聲音與畫面對齊的效率。';

  @override
  String get tipsCommunityYoutubeTitle => '投稿到作品廣場需要透過YouTube';

  @override
  String get tipsCommunityYoutubeDesc =>
      '投稿到作品廣場後，作品將透過YouTube公開。NIARIM不具備將影片檔案本體傳送、蒐集或保存到開發者伺服器的功能。若在YouTube端將影片設定為「非公開條列」，該影片就不會出現在YouTube的公開清單中，僅會顯示於作品廣場內。';

  @override
  String get tipsToolbarCustomizeTitle => '重新排列・隱藏工具列，縮短手指移動距離';

  @override
  String get tipsToolbarCustomizeDesc =>
      '在設定畫面的工具列編輯中，可以隱藏不用的工具，把常用工具排到手指容易點到的位置。只是精簡顯示項目、讓介面更清爽，就能減少尋找工具的時間和手指移動距離，提升作畫節奏。';

  @override
  String get tipsAutofillBlendModeTitle => '用自動上色部位的混合模式改變陰影質感';

  @override
  String get tipsAutofillBlendModeDesc =>
      '自動上色設定的每個部位都可以設定混合模式。將陰影部位設為「疊加」或「柔光」而不是「色彩增值」，可以做出彷彿透光般的柔和陰影。即使顏色相同，也能改變質感，這是一個隱藏的自由度。';

  @override
  String get tipsStampBlendModeTitle => '印章×混合模式，做出發光特效';

  @override
  String get tipsStampBlendModeDesc =>
      '把放置的印章圖層的混合模式設為「濾色」或「相加」，光效線條或閃亮特效就能自然融入背景，顯得更加突出。';

  @override
  String get tipsQuickToolPenSubTitle => '快捷工具×畫筆子工具，打造不間斷的作業流程';

  @override
  String get tipsQuickToolPenSubDesc =>
      '把常用工具登記到快捷工具，同時善用長按畫筆即可切換到網點填色、印章放置的子工具，就能減少畫面間的來回切換，保持作業節奏。';

  @override
  String get tipsAutofillToneReuseTitle => '利用自動上色的網點設定，只需重畫線稿就能重現上色';

  @override
  String get tipsAutofillToneReuseDesc =>
      '將自動上色設定的每個部位設為「使用網點」，每次重新繪製線稿時都能自動重現含網點的上色效果，省去逐格重新貼網點的麻煩。';

  @override
  String get tipsAutofillMisfillTitle => '了解自動上色的原理就能減少塗錯';

  @override
  String get tipsAutofillMisfillDesc =>
      '自動上色並非使用生成式AI的功能，而是逐圖層油漆桶填色的應用。因此，當同一個部位內部存在被線條圍住的空隙（例如長髮內側）時，那裡也會一起被填滿。建議的對策是：先為每個部位指定一個高飽和度的醒目顏色填一遍。這樣塗錯的地方一眼就能看出來，便於手動修正自動上色圖層；修正之後再設回原本的顏色，以覆蓋的方式重新執行自動上色，塗錯就會大幅減少。';

  @override
  String get tipsAutofillTransparentFixTitle => '自動上色溢出的部分用透明色油漆桶擦掉';

  @override
  String get tipsAutofillTransparentFixDesc =>
      '當自動上色填到了不該填的地方時，比起用橡皮反覆擦，把繪圖色設為透明色再對該範圍使用油漆桶更為簡便。油漆桶會一次性處理被線條圍住的整個區域，因此輕點一下就能乾淨地只清除溢出的部分。';

  @override
  String get tipsRadialVignetteTitle => '放射尺×暗角，營造集中線效果';

  @override
  String get tipsRadialVignetteDesc =>
      '用放射尺一口氣畫出集中線，再疊加繪圖濾鏡的暗角效果，就能做出如漫畫高潮般有魄力的演出。';

  @override
  String get tipsClippingGradientTitle => '剪裁×漸層，讓陰影可以隨時重畫';

  @override
  String get tipsClippingGradientDesc =>
      '把漸層圖層剪裁到角色圖層上，之後只需改變漸層的範圍和角度就能重新調整陰影，不必用筆刷重新描繪陰影形狀。';

  @override
  String get tipsToneCurveSepiaTitle => '色調曲線×懷舊棕，營造復古照片感';

  @override
  String get tipsToneCurveSepiaDesc =>
      '先用演出濾鏡的色調曲線調整明暗對比，再疊加懷舊棕濾鏡，就能營造出彷彿褪色老照片般的質感。';

  @override
  String get tipsCameraLensBlurTitle => '攝影機關鍵影格×鏡頭模糊，做出變焦拉伸效果';

  @override
  String get tipsCameraLensBlurDesc =>
      '在攝影機關鍵影格推近的瞬間，臨時把鏡頭模糊演出濾鏡調強，就能演繹出如實拍變焦拉伸般的魄力。';

  @override
  String get tipsBlurVignetteBgTitle => '高斯模糊×暗角，做出柔和的背景虛化';

  @override
  String get tipsBlurVignetteBgDesc =>
      '只對背景圖層疊加高斯模糊和暗角繪圖濾鏡，主角就會自然地更加突出，呈現出具有景深感的鏡頭效果。';

  @override
  String get tipsSepiaVignetteTitle => '懷舊棕×暗角，打造復古老照片風影片';

  @override
  String get tipsSepiaVignetteDesc =>
      '把演出濾鏡的懷舊棕與繪圖濾鏡的暗角組合使用，能讓影片呈現出四角發暗、色彩褪去的復古老照片氛圍。';

  @override
  String get tipsVideoTrimReuseTitle => '改變影片片段的使用範圍，重複利用同一素材';

  @override
  String get tipsVideoTrimReuseDesc =>
      '即使是同一個影片素材，只要為每個片段設定不同的使用開始・結束影格，就能當作不同的鏡頭重複使用。不用增加素材也能做出變化。';

  @override
  String get tipsSaveSlotAutoSaveTitle => '區分使用存檔槽和自動儲存';

  @override
  String get tipsSaveSlotAutoSaveDesc =>
      '自動儲存總是覆蓋為最新狀態，而存檔槽可以保留多個狀態。在重要節點儲存到存檔槽，其餘的細微改動就交給自動儲存，這樣就能可靠地回到需要的時間點。';

  @override
  String get tipsQuickToolSwipeTitle => '快捷工具可以用上滑手勢重新排序';

  @override
  String get tipsQuickToolSwipeDesc =>
      '想更改快捷工具的登記內容時，除了長按，也可以用向上滑動開啟管理彈出視窗。單手操作時想快速重新排序會很方便。';

  @override
  String get tipsDrawingAreaCameraTitle => '作畫區域留寬×攝影機關鍵影格，安全地推拉與平移';

  @override
  String get tipsDrawingAreaCameraDesc =>
      '把作畫區域設定得比匯出範圍更寬，就不用擔心用攝影機關鍵影格做平移、縮放時畫面邊緣被裁切。在加入較大幅度的運鏡之前先確認一下會比較放心。';

  @override
  String get tipsWebmCommonLayerTitle => '透明WebM×用共用圖層分開管理背景';

  @override
  String get tipsWebmCommonLayerDesc =>
      '如果打算把匯出為透明WebM的角色，在其他影片剪輯軟體中與背景合成，把背景用共用圖層單獨管理，可以避免多餘顏色混進透明部分，讓去背效果更乾淨。';

  @override
  String get tipsLeftHandedWorkspaceTitle => '左手模式×工作區設定，讓操作更順手';

  @override
  String get tipsLeftHandedWorkspaceDesc =>
      '如果是左撇子，打開工作區設定中的左手模式後，停靠面板會左右翻轉，慣用手一側的畫面就不容易被面板遮住。';

  @override
  String get tipsTransferDeviceTitle => '用轉移檔案把製作內容搬到其他裝置';

  @override
  String get tipsTransferDeviceDesc =>
      '想換裝置也保持相同環境繼續繪製時，使用轉移（.niatra）功能，可以把設定、筆刷、色調、印章、調色盤等環境一起搬過去。如果想傳遞正在製作的專案本身，請改用「共用（.niashare）」。';

  @override
  String get fontSettingsTabDownloaded => '已下載';

  @override
  String get fontSettingsTabSearch => '搜尋下載';

  @override
  String get fontSettingsTabImport => '匯入';

  @override
  String get fontDownloadedSearchHint => '以字型名稱搜尋...';

  @override
  String get fontPixelModeTooltip => '像素模式（適用於點陣字型，無抗鋸齒清晰顯示）';

  @override
  String get fontEmptyTitle => '沒有字型';

  @override
  String get fontEmptyHint => '可從「搜尋下載」或「匯入」分頁新增';

  @override
  String get fontRenameDialogTitle => '變更字型名稱';

  @override
  String get fontImportTitle => '匯入裝置中已儲存的字型';

  @override
  String get fontImportFormats => '支援格式：TTF / OTF';

  @override
  String get fontSelectFileButton => '選擇檔案';

  @override
  String get fontUnsupportedSnackbar => '無法讀取此字型。';

  @override
  String fontAddedSnackbar(String name) {
    return '已新增「$name」（顯示在已下載分頁）';
  }

  @override
  String get fontCorruptedSnackbar => '字型已損毀。';

  @override
  String get licenseScreenTitle => '使用條款・授權';

  @override
  String get licenseSectionTerms => '使用條款';

  @override
  String get licenseSectionFonts => '關於使用的字型';

  @override
  String get licenseSectionOss => '開放原始碼軟體授權';

  @override
  String get licenseOssListTitle => '使用函式庫的授權清單';

  @override
  String get licenseOssListSubtitle => '顯示本App使用的OSS套件授權資訊';

  @override
  String get licenseFfmpegNote =>
      'WebM、AVI匯出使用了FFmpeg（LGPL 3.0，透過ffmpeg_kit_flutter_new_video呼叫）。修改版原始碼取得處：https://github.com/sk3llo/ffmpeg_kit_flutter\nMP4匯出直接使用裝置內建的硬體編碼器，未使用FFmpeg。';

  @override
  String licenseFontCreditMeta(String author, String license) {
    return '作者：$author　授權：$license';
  }

  @override
  String get toolbarPenTooltip => '筆（長按開啟子工具）';

  @override
  String get toolbarPenFirstUseTip => '長按筆工具，可切換筆刷・網點・印章・套索填色。';

  @override
  String get toolbarBucketTooltip => '油漆桶（長按切換純色/網點填滿）';

  @override
  String get toolbarBucketFirstUseTip => '長按油漆桶，可在純色填滿和網點填滿之間切換。';

  @override
  String get toolbarSelectTooltip => '選取（長按變更類型）';

  @override
  String get toolbarShapeTooltip => '圖形（點擊選擇種類）';

  @override
  String get toolbarTextFirstUseTip => '可自由放置文字，也能變更字型、顏色和外框線。';

  @override
  String get toolbarQuickToolFirstUseTip => '點擊可依序切換已登錄的工具。長按或向上滑動可編輯已登錄的內容。';

  @override
  String get firstUseTipOperationGuideTitle => '基本操作';

  @override
  String get firstUseTipOperationGuideBody =>
      '單擊工具列圖示即可切換到該工具。長按同一圖示或向上滑動，可開啟該工具的詳細設定（筆刷種類、填色方式、選取方式等）。雙擊圖示會顯示該工具的簡短說明。關閉之後，也可以從各畫面右上角的「?」按鈕在說明中重新閱讀。';

  @override
  String get helpBasicGestureTitle => '基本操作（點擊・長按・上滑）';

  @override
  String get helpBasicGestureDesc =>
      '單擊工具列圖示即可切換到該工具。長按同一圖示或向上滑動，可開啟詳細設定。鋼筆可切換筆刷・網點・印章・套索填色，油漆桶可切換純色填色與網點填色，選取工具可切換矩形・套索・自動選取，手指工具可切換模糊與馬賽克，快速切換工具可編輯已登記的內容，這些都在長按或上滑之後。雙擊圖示時，畫面下方會顯示該工具的簡短說明。\\n在畫布上，雙指捏合可縮放，雙指拖曳可平移，雙指點擊復原，三指點擊重做。雙擊畫面左右邊緣可移動到前後一格。\\n連接滑鼠或繪圖板時，可用滾輪縮放、按住中鍵拖曳平移。';

  @override
  String get toolbarStampColorLockedSnackbar => '印章保留了自身的顏色資訊，因此無法變更顏色';

  @override
  String get toolbarBrushSettingsTooltip => '筆刷設定';

  @override
  String get toolbarLayerTooltip => '圖層';

  @override
  String get toolbarQuickToolTooltip => '快速切換工具（長按/向上滑動可編輯）';

  @override
  String get toolbarSaveTooltip => '儲存（儲存樹）';

  @override
  String get toolbarBucketFlatFill => '純色填滿';

  @override
  String get toolbarBucketToneListLabel => '網點清單';

  @override
  String get toolbarSelectRect => '矩形選取';

  @override
  String get toolbarSelectLasso => '套索選取';

  @override
  String get toolbarSelectMagicWand => '自動選取（魔術棒）';

  @override
  String get creativePanelFavoritesOnlyTooltip => '僅顯示我的最愛';

  @override
  String get creativePanelSearchTooltip => '依名稱搜尋';

  @override
  String get creativePanelSearchModeKeyword => '正在依關鍵字搜尋（點按切換為標籤搜尋）';

  @override
  String get creativePanelSearchModeTag => '正在依標籤搜尋（點按切換為關鍵字搜尋）';

  @override
  String get creativePanelTagSearchHint => '依標籤搜尋';

  @override
  String get creativePanelTagNoneYet => '尚未有標籤，可在編輯畫面新增';

  @override
  String get creativePanelTagsLabel => '標籤';

  @override
  String get creativePanelTagsHint => '以逗號或空格分隔輸入';

  @override
  String get creativePanelTagClearFilter => '清除標籤篩選';

  @override
  String get widgetSettingsTitle => '主畫面小工具';

  @override
  String get widgetSettingsDescription =>
      '可在手機主畫面放置三種小工具：所選作品的一格畫面、「創作作品」與「作品廣場」。新增小工具請長按主畫面。';

  @override
  String get widgetSettingsSubtitle => '要顯示的作品、小工具顏色';

  @override
  String get widgetArtworkSection => '要顯示的作品';

  @override
  String get widgetSectionArtwork => '啟動頁小工具';

  @override
  String get widgetSectionArtworkDesc => '顯示所選作品的一格畫面。點按即可開啟 NIARIM。';

  @override
  String get widgetSectionCreate => '創作作品小工具';

  @override
  String get widgetSectionCreateDesc => '點按即可開啟「創作作品」頁面。';

  @override
  String get widgetSectionPlaza => '作品廣場小工具';

  @override
  String get widgetSectionPlazaDesc => '點按即可開啟「作品廣場」。';

  @override
  String get widgetArtworkNone => '尚未選擇作品';

  @override
  String get widgetColorFollowTheme => '跟隨應用程式主題';

  @override
  String get widgetColorCustom => '選擇顏色';

  @override
  String get widgetNoProjects => '還沒有作品。創作後即可在這裡選擇。';

  @override
  String get widgetSettingsNote => '主畫面小工具無法播放影片，因此以靜止影像顯示所選作品的一格畫面。';

  @override
  String get assetTagLineArt => '線稿';

  @override
  String get assetTagBasic => '基本';

  @override
  String get assetTagMainLine => '主線';

  @override
  String get assetTagPaint => '上色';

  @override
  String get assetTagBlur => '模糊';

  @override
  String get assetTagMixing => '混色';

  @override
  String get assetTagAnalog => '仿手繪';

  @override
  String get assetTagDecoration => '裝飾';

  @override
  String get assetTagRough => '草稿';

  @override
  String get assetTagEffect => '效果';

  @override
  String get assetTagTaper => '起收筆';

  @override
  String get assetTagPixelArt => '像素畫';

  @override
  String get assetTagHalftone => '網點';

  @override
  String get assetTagShadow => '陰影';

  @override
  String get assetTagLine => '線條';

  @override
  String get assetTagGradient => '漸層';

  @override
  String get assetTagTexture => '質感';

  @override
  String get assetTagClothing => '服裝';

  @override
  String get assetTagMesh => '網眼';

  @override
  String get assetTagBackground => '背景';

  @override
  String get assetTagPattern => '圖案';

  @override
  String get assetTagShape => '圖形';

  @override
  String get assetTagSymbol => '符號';

  @override
  String get assetTagManga => '漫畫';

  @override
  String get creativePanelFolderButton => '資料夾';

  @override
  String get creativePanelCreateButton => '自製';

  @override
  String get creativePanelImportButton => '匯入';

  @override
  String get creativePanelFolderAllChip => '全部';

  @override
  String get creativePanelEditAction => '編輯';

  @override
  String get toneTitle => '網點';

  @override
  String get toneEmpty => '沒有網點';

  @override
  String get toneSearchHint => '以網點名稱搜尋';

  @override
  String get toneEditTitle => '編輯網點';

  @override
  String get toneChangeTextureButton => '變更材質圖片';

  @override
  String get toneCreateDialogTitle => '自製網點';

  @override
  String toneImportFailedSnackbar(String error) {
    return '網點讀取失敗：$error';
  }

  @override
  String toneExportFailedSnackbar(String error) {
    return '網點匯出失敗：$error';
  }

  @override
  String get privacyPolicyScreenTitle => '隱私權政策';

  @override
  String get stampTitle => '印章';

  @override
  String get stampSearchHint => '以印章名稱搜尋';

  @override
  String get stampEmpty => '沒有印章';

  @override
  String get stampCreateDialogTitle => '自製印章';

  @override
  String stampImportFailedSnackbar(String error) {
    return '印章讀取失敗：$error';
  }

  @override
  String stampExportFailedSnackbar(String error) {
    return '印章匯出失敗：$error';
  }

  @override
  String get stampEditTitle => '編輯印章';

  @override
  String get stampRotationLabel => '旋轉';

  @override
  String get stampPixelModeLabel => '像素模式';

  @override
  String get stampPixelModeHint => '以像素畫風格（馬賽克＋減少顏色數）繪製';

  @override
  String get stampDensityLabel => '密度';

  @override
  String get stampScatterLabel => '散布';

  @override
  String get stampChangeImageButton => '變更印章圖片';

  @override
  String get themeSettingsTitle => '主題・外觀';

  @override
  String get themeColorCustomizeSection => '顏色自訂';

  @override
  String get themeColorAccent => '強調色';

  @override
  String get themeColorText => '文字顏色';

  @override
  String get themeColorPanelBg => '面板背景色';

  @override
  String get themeColorMenuBg => '選單背景色';

  @override
  String get themeColorSelection => '選取色';

  @override
  String get themeColorUpdateMark => '更新標記顏色';

  @override
  String get themePresetSection => '主題清單';

  @override
  String themePresetDuplicateName(String name) {
    return '$name（副本）';
  }

  @override
  String get themeDuplicateAction => '複製';

  @override
  String get themeExportMenuItem => '匯出 (.niatheme)';

  @override
  String themeExportFailedSnackbar(String error) {
    return '匯出失敗：$error';
  }

  @override
  String get themeImportSuccessSnackbar => '已匯入.niatheme檔案';

  @override
  String themeImportFailedSnackbar(String error) {
    return '匯入失敗：$error';
  }

  @override
  String get themeSaveAsNewButton => '將目前設定儲存為新主題';

  @override
  String get themeImportButton => '匯入.niatheme';

  @override
  String get themePresetNameDialogTitle => '主題名稱';

  @override
  String get themeDefaultPresetName => '我的主題';

  @override
  String get onionSkinTitle => '洋蔥皮';

  @override
  String get onionSkinPrevFrame => '前一影格';

  @override
  String get onionSkinNextFrame => '後一影格';

  @override
  String get onionSkinFrameInterval => '影格間隔';

  @override
  String get onionSkinFadeByDistance => '越近越深';

  @override
  String get onionSkinColorPickerTitle => '選擇顏色';

  @override
  String get onionSkinOnFixed => '開啟（固定）';

  @override
  String get onionSkinFrameCount => '顯示張數';

  @override
  String onionSkinFrameCountFixed(int count) {
    return '$count張（固定）';
  }

  @override
  String get onionSkinColorLabel => '顏色';

  @override
  String get onionSkinOpacityLabel => '不透明度';

  @override
  String get exportScreenTitle => '匯出';

  @override
  String get exportPresetSection => '預設';

  @override
  String get exportPresetStandard => '標準';

  @override
  String get exportPresetHighQuality => '高畫質';

  @override
  String get exportPresetCustom => '自訂';

  @override
  String get exportAdvancedSettings => '詳細設定';

  @override
  String get exportFpsLabel => 'FPS';

  @override
  String get exportFormatSection => '格式';

  @override
  String get exportFormatMp4 => 'MP4';

  @override
  String get exportFormatMp4Subtitle => '通用影片格式';

  @override
  String get exportFormatGif => 'GIF';

  @override
  String get exportFormatGifSubtitle => '動態GIF';

  @override
  String get exportFormatWebmSubtitle => '透明背景影片';

  @override
  String get exportFormatAvi => 'AVI';

  @override
  String get exportFormatAviSubtitle => '相容性優先的影片格式（不支援透明）';

  @override
  String get exportStartButton => '開始匯出';

  @override
  String get exportProjectNotFoundError => '找不到專案';

  @override
  String exportFailedError(String error) {
    return '匯出失敗：$error';
  }

  @override
  String get exportInProgressTitle => '匯出中';

  @override
  String get exportCancelledSnackbar => '已取消匯出';

  @override
  String get exportCancelHint => '正在進行最終處理，完成後將反映取消操作';

  @override
  String get exportOutdatedAutofillTitle => '自動上色不是最新狀態';

  @override
  String get exportOutdatedAutofillBody => '有尚未更新的自動上色圖層。要直接匯出嗎？';

  @override
  String get exportContinueButton => '繼續';

  @override
  String get exportDurationExceededTitle => '超出影片長度上限';

  @override
  String exportDurationExceededBody(int max, int current) {
    return '免費版的最長影片長度為$max秒。\n目前專案約為$current秒。\n升級為Premium後最長可達2小時。';
  }

  @override
  String get exportViewPremiumButton => '查看Premium';

  @override
  String get exportContinueAnywayButton => '仍要繼續';

  @override
  String get exportCompleteTitle => '匯出完成';

  @override
  String exportCompleteFramesBody(int count) {
    return '已完成$count影格的匯出。';
  }

  @override
  String exportSaveLocationLabel(String fileName) {
    return '儲存位置：App內（$fileName）';
  }

  @override
  String get exportSaveLocationHint =>
      '若要在裝置的「相片」App或檔案App中開啟，請從下方的「分享」選擇要儲存到的App。';

  @override
  String get exportBackToProjectsButton => '返回專案列表';

  @override
  String get exportBackToCanvasButton => '返回畫布';

  @override
  String get newProjectScreenTitle => '新增專案';

  @override
  String get newProjectDefaultName => '新增專案';

  @override
  String get newProjectNameLabel => '專案名稱';

  @override
  String get newProjectSizeLabel => '尺寸';

  @override
  String get newProjectPresetFullHd => 'Full HD（16:9・適合YouTube等橫式影片）';

  @override
  String get newProjectPresetHd => 'HD（16:9・輕量版）';

  @override
  String get newProjectPresetSquare => '1:1 正方形（適合Twitter/Instagram發佈）';

  @override
  String get newProjectPresetVertical => '9:16 直式（適合YouTube Shorts/Reels/限時動態）';

  @override
  String get newProjectPresetPortrait => '4:5 直長（適合Instagram動態消息發佈）';

  @override
  String get newProjectPresetAnalog => '4:3（類比廣播比例）';

  @override
  String get newProjectCustomSize => '自訂';

  @override
  String get newProjectMaxEdgeHint => '長邊最大可設定為1920px';

  @override
  String get newProjectWidthLabel => '寬度(px)';

  @override
  String get newProjectHeightLabel => '高度(px)';

  @override
  String get newProjectWidthShort => '寬';

  @override
  String get newProjectHeightShort => '高';

  @override
  String get newProjectSizePresetManageButton => '尺寸設定';

  @override
  String get newProjectSaveCustomSizeButton => '儲存此尺寸';

  @override
  String get newProjectSaveCustomSizeDialogTitle => '請輸入此尺寸的名稱';

  @override
  String get newProjectSaveCustomSizeNameLabel => '尺寸名稱';

  @override
  String get newProjectSaveCustomSizeSavedSnackbar => '已儲存尺寸';

  @override
  String get canvasSizePresetManageScreenTitle => '尺寸設定';

  @override
  String get canvasSizePresetEmpty => '尚無已儲存的尺寸';

  @override
  String get canvasSizePresetEmptyHint => '在新增專案畫面指定自訂尺寸後，點選「儲存此尺寸」即可新增';

  @override
  String get canvasSizePresetEditDialogTitle => '編輯尺寸';

  @override
  String get canvasSizePresetDuplicateSuffix => '副本';

  @override
  String newProjectDurationLabel(String max) {
    return '時長（最大$max）';
  }

  @override
  String newProjectDurationLabelWithPremiumHint(String max) {
    return '時長（最大$max，升級Premium可達最長2小時）';
  }

  @override
  String newProjectDurationSeconds(int n) {
    return '$n秒';
  }

  @override
  String newProjectDurationHms(int h, int m, int s) {
    return '$h小時$m分$s秒';
  }

  @override
  String newProjectDurationHm(int h, int m) {
    return '$h小時$m分';
  }

  @override
  String newProjectDurationH(int h) {
    return '$h小時';
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
  String get newProjectDrawingAreaTitle => '擴大繪圖區域';

  @override
  String get newProjectDrawingAreaSubtitle => '新增可在匯出範圍外繪製的區域';

  @override
  String get newProjectScaleLabel => '倍率';

  @override
  String newProjectScaleValue(String value) {
    return '$value倍';
  }

  @override
  String newProjectDrawableAreaInfo(String width, String scale, String result) {
    return '可繪製範圍：$width×$scale = $result';
  }

  @override
  String newProjectTotalFrames(int count) {
    return '總影格數：$count';
  }

  @override
  String newProjectExportSizeInfo(String size) {
    return '匯出尺寸：$size';
  }

  @override
  String newProjectDrawingAreaInfo(String size) {
    return '繪圖區域：$size';
  }

  @override
  String get colorPickerTitle => '選擇顏色';

  @override
  String get colorPickerOpacityLabel => '不透明度';

  @override
  String get colorPickerHexCopiedSnackbar => '已複製HEX值';

  @override
  String get colorPickerRecentColorsLabel => '最近使用的顏色';

  @override
  String get colorPickerRecentColorsEmpty => '尚無記錄';

  @override
  String get colorPickerPaletteLabel => '調色盤';

  @override
  String get colorPickerNewPaletteTooltip => '新增調色盤';

  @override
  String get colorPickerManagePaletteTooltip => '調色盤管理';

  @override
  String get colorPickerPaletteEmptyHint => '還沒有顏色。點擊「＋」可新增目前的顏色。';

  @override
  String get colorPickerPaletteLongPressHint => '長按可刪除';

  @override
  String get colorPickerAddCurrentColorButton => '將目前的顏色新增到調色盤';

  @override
  String get colorPickerPaletteNameLabel => '調色盤名稱';

  @override
  String get colorPickerFavoriteAdd => '加入最愛';

  @override
  String get colorPickerFavoriteRemove => '取消最愛';

  @override
  String get penSubToolTabBrush => '筆刷';

  @override
  String get penSubToolTabTone => '網點';

  @override
  String get penSubToolTabStamp => '印章';

  @override
  String get penSubToolTabLassoFill => '套索填色';

  @override
  String get penSubToolToneTooltipMessage => '選擇網點後，可以用填色桶或筆刷塗上網點紋理。';

  @override
  String get penSubToolStampTooltipMessage => '可以放置固定形狀的印章。長按可設定旋轉、密度等。';

  @override
  String get penSubToolManageTooltip => '管理';

  @override
  String penSubToolBrushSizeOpacity(int size, int opacity) {
    return '${size}px · $opacity%';
  }

  @override
  String get penSubToolStampRotationSubtitle => '依筆畫方向隨機旋轉';

  @override
  String get brushSearchHint => '以筆刷名稱搜尋';

  @override
  String get brushEmpty => '沒有筆刷';

  @override
  String get brushCreateDialogTitle => '自製筆刷';

  @override
  String brushImportFailedSnackbar(String error) {
    return '筆刷讀取失敗：$error';
  }

  @override
  String brushExportFailedSnackbar(String error) {
    return '筆刷匯出失敗：$error';
  }

  @override
  String get brushSettingsSizeLabel => '大小';

  @override
  String get brushSettingsOpacityLabel => '不透明度';

  @override
  String get brushSettingsSpacingLabel => '間距';

  @override
  String get brushSettingsBlurRadiusLabel => '模糊半徑';

  @override
  String get brushSettingsStabilizationTitle => '防手震';

  @override
  String get brushSettingsStabilizationStrengthLabel => '防手震強度';

  @override
  String get brushSettingsPixelModeTitle => '像素模式';

  @override
  String get brushSettingsPressureModeTitle => '筆壓設定';

  @override
  String get brushSettingsPressureOff => '無效';

  @override
  String get brushSettingsPressureSize => '套用到大小';

  @override
  String get brushSettingsPressureOpacity => '套用到不透明度';

  @override
  String get brushSettingsPressureSizeAndOpacity => '套用到大小＋不透明度';

  @override
  String get brushSettingsFadeModeTitle => '淡出';

  @override
  String get brushSettingsFadeOff => 'OFF';

  @override
  String get brushSettingsFadeWeak => '弱';

  @override
  String get brushSettingsFadeMedium => '中';

  @override
  String get brushSettingsFadeStrong => '強';

  @override
  String get brushSettingsFadeCustom => '自訂';

  @override
  String get brushSettingsFadeStartValueLabel => '起始值(%)';

  @override
  String get brushSettingsFadeEndValueLabel => '結束值(%)';

  @override
  String get brushSettingsFadeDistanceLabel => '距離(px)';

  @override
  String get brushSettingsStrokeDecayTitle => '筆畫衰減';

  @override
  String get brushSettingsStrokeDecaySubtitle => '持續繪製不透明度會降低';

  @override
  String get brushSettingsMixingTitle => '混色';

  @override
  String get brushSettingsMixingOff => 'OFF';

  @override
  String get brushSettingsMixingSimple => '簡易混色';

  @override
  String get brushSettingsMixingBleed => '暈染';

  @override
  String get brushSettingsMixingRateLabel => '混色率';

  @override
  String get projectDetailNotFoundTitle => '專案';

  @override
  String get projectDetailNotFoundBody => '找不到專案';

  @override
  String get projectDetailFirstFrameTooltip => '第一格';

  @override
  String get projectDetailPrevFrameTooltip => '後退1格';

  @override
  String get projectDetailPauseTooltip => '暫停';

  @override
  String get projectDetailPlayTooltip => '播放';

  @override
  String get projectDetailNextFrameTooltip => '前進1格';

  @override
  String get projectDetailLastFrameTooltip => '最後一格';

  @override
  String get projectDetailFullscreenTooltip => '全螢幕顯示預覽';

  @override
  String get projectDetailFullscreenCloseTooltip => '關閉全螢幕預覽';

  @override
  String get projectDetailStartEditButton => '開始編輯';

  @override
  String get projectDetailTagsQuickAction => '標籤';

  @override
  String get projectDetailShareQuickAction => '分享';

  @override
  String get projectDetailInfoSectionTitle => '專案資訊';

  @override
  String get projectDetailInfoExportSize => '匯出尺寸';

  @override
  String get projectDetailInfoDrawingArea => '繪圖區域';

  @override
  String projectDetailInfoDrawingAreaValue(String size, String scale) {
    return '$size  ($scale)';
  }

  @override
  String get projectDetailInfoTotalFrames => '總影格數';

  @override
  String get projectDetailInfoWorkTime => '製作時間';

  @override
  String get projectDetailInfoLastSaved => '最近儲存';

  @override
  String get projectDetailInfoSize => '容量';

  @override
  String get projectDetailAddTagHint => '新增標籤';

  @override
  String projectDetailNiashareFailedSnackbar(String error) {
    return '.niashare建立失敗：$error';
  }

  @override
  String get projectDetailTrashMenuItem => '移到垃圾桶';

  @override
  String get commonOff => 'OFF';

  @override
  String get perfSettingsScreenTitle => '效能設定';

  @override
  String get perfSettingsQualitySection => '畫質設定';

  @override
  String get perfSettingsQualityLow => '低畫質';

  @override
  String get perfSettingsQualityMedium => '中畫質';

  @override
  String get perfSettingsQualityHigh => '高畫質';

  @override
  String get perfSettingsQualityCustom => '自訂';

  @override
  String get perfSettingsQualityDescLow => '適合想要更輕量運作的裝置（前後各1張洋蔥皮・5個儲存槽）';

  @override
  String get perfSettingsQualityDescMedium => '適合一般裝置（前後各3張洋蔥皮・10個儲存槽）';

  @override
  String get perfSettingsQualityDescHigh => '適合效能較充裕的裝置（前後各5張洋蔥皮・樹狀存檔）';

  @override
  String get perfSettingsQualityDescCustom => '個別設定各項目';

  @override
  String get perfSettingsCapacitySection => '容量與運作相關設定';

  @override
  String get perfSettingsUndoLimitTitle => '復原次數';

  @override
  String get perfSettingsUndoLimitSubtitle => '次數越多越耗費記憶體';

  @override
  String perfSettingsUndoLimitValue(int n) {
    return '$n次';
  }

  @override
  String get perfSettingsTrashAutoDeleteTitle => '垃圾桶自動刪除';

  @override
  String get perfSettingsTrashAutoDeleteSubtitle => '已刪除專案的保留期限';

  @override
  String perfSettingsTrashAutoDeleteValue(int n) {
    return '$n天';
  }

  @override
  String get perfSettingsCurrentSettingsSection => '目前設定';

  @override
  String get perfSettingsTiltLabel => '傾斜偵測';

  @override
  String get perfSettingsOnionPrevLabel => '洋蔥皮（前）';

  @override
  String get perfSettingsOnionNextLabel => '洋蔥皮（後）';

  @override
  String perfSettingsOnionFrameCountValue(int n) {
    return '$n張';
  }

  @override
  String get perfSettingsSaveModeLabel => '存檔方式';

  @override
  String get perfSettingsSlotCountLabel => '儲存槽數量';

  @override
  String perfSettingsSlotCountValue(int n) {
    return '$n個';
  }

  @override
  String get perfSettingsResetButton => '恢復初始值';

  @override
  String get perfSettingsCopyPresetButton => '複製目前的預設';

  @override
  String get perfSettingsTiltSwitchTitle => '將筆的傾斜套用到筆刷';

  @override
  String get perfSettingsShowPrevOnionTitle => '顯示前一格';

  @override
  String get perfSettingsOnionCountPrevLabel => '洋蔥皮張數（前）';

  @override
  String get perfSettingsShowNextOnionTitle => '顯示後一格';

  @override
  String get perfSettingsOnionCountNextLabel => '洋蔥皮張數（後）';

  @override
  String get perfSettingsSaveModeSlot => '儲存槽方式';

  @override
  String get perfSettingsSaveModeTree => '樹狀方式';

  @override
  String get perfSettingsResetDialogTitle => '要將自訂畫質設定恢復為初始值嗎？';

  @override
  String perfSettingsResetDialogBody(String preset) {
    return '初始值將恢復為首次啟動時依裝置效能自動判定的「$preset」設定。';
  }

  @override
  String get perfSettingsResetConfirmButton => '恢復';

  @override
  String get perfSettingsCopyPresetDialogTitle => '選擇要複製的預設';

  @override
  String get perfSettingsCopyPresetDialogBody => '請選擇要複製到自訂設定的預設。';

  @override
  String get perfSettingsCopyDescLow => '前後各顯示1張・輕量運作';

  @override
  String get perfSettingsCopyDescMedium => '前後各顯示3張・標準';

  @override
  String get perfSettingsCopyDescHigh => '前後各顯示5張・高畫質';

  @override
  String get filterPanelTitle => '濾鏡';

  @override
  String filterPanelTitleBulk(int count) {
    return '濾鏡（批次套用到$count格）';
  }

  @override
  String get filterSearchHint => '搜尋濾鏡';

  @override
  String get filterNameGaussianBlur => '高斯模糊';

  @override
  String get filterNameLensBlur => '鏡頭模糊';

  @override
  String get filterNameAnimeStyle => '動漫風格';

  @override
  String get filterNameOutline => '描邊';

  @override
  String get filterNameToneCurve => '色調曲線';

  @override
  String get filterNameLevels => '色階';

  @override
  String get filterNameSharpen => '銳化';

  @override
  String get filterNameUnsharpMask => 'USM銳化';

  @override
  String get filterSharpenStrength => '銳化強度';

  @override
  String get filterUnsharpAmount => '強度';

  @override
  String get filterNameVignette => '暗角';

  @override
  String get filterVignetteStrength => '暗角強度';

  @override
  String get filterVignetteColor => '暗角顏色';

  @override
  String get filterNameNoise => '膠片顆粒';

  @override
  String get filterNoiseStrength => '顆粒強度';

  @override
  String get filterNameRetroAnime => '復古動漫';

  @override
  String get filterNameCrt => '老電視';

  @override
  String get filterRetroStrength => '強度';

  @override
  String filterOutlineLayerNameSuffix(String name) {
    return '$name（描邊）';
  }

  @override
  String get filterStrengthBlurRadius => '強度（模糊半徑）';

  @override
  String get filterColorLevels => '顏色數';

  @override
  String get filterEdgeStrength => '邊緣強調';

  @override
  String get filterOutlineColor => '描邊顏色';

  @override
  String get filterOutlineWidth => '描邊寬度';

  @override
  String get filterToneCurveLinear => '標準';

  @override
  String get filterToneCurveBrighten => '變亮';

  @override
  String get filterToneCurveDarken => '變暗';

  @override
  String get filterToneCurveHighContrast => '高對比度';

  @override
  String get filterToneCurveLowContrast => '低對比度';

  @override
  String get filterToneCurveInvert => '反轉';

  @override
  String get filterLevelsInputBlack => '輸入：黑';

  @override
  String get filterLevelsInputWhite => '輸入：白';

  @override
  String get filterLevelsOutputBlack => '輸出：黑';

  @override
  String get filterLevelsOutputWhite => '輸出：白';

  @override
  String get filterApplyButton => '套用';

  @override
  String filterApplyBulkButton(int count) {
    return '套用到$count格';
  }

  @override
  String get filterEmpty => '沒有濾鏡';

  @override
  String get filterApplyingTitle => '套用濾鏡中';

  @override
  String filterApplyingSubtitle(String name, int count) {
    return '$name　$count格';
  }

  @override
  String get projectListNewFolderTitle => '新增資料夾';

  @override
  String get projectListFolderHint => '也可用來整理同一作品的多話內容或系列作品';

  @override
  String get projectListEmptyTitle => '沒有專案';

  @override
  String get projectListEmptyHint => '點擊「＋」新增';

  @override
  String get projectListOpenAction => '開啟';

  @override
  String get projectListCreateShareAction => '建立.niashare';

  @override
  String get projectListEditFolderAction => '編輯名稱與顏色';

  @override
  String get projectListDeleteFolderConfirmTitle => '要刪除這個資料夾嗎？';

  @override
  String projectListDeleteFolderConfirmBody(String name) {
    return '將刪除「$name」。其中的專案・子資料夾將移至根目錄。';
  }

  @override
  String get projectListFolderRootOption => '無資料夾（根目錄）';

  @override
  String get projectListEditFolderTooltip => '編輯資料夾';

  @override
  String get projectListCreateFolderAction => '新增資料夾';

  @override
  String get projectListFolderColorLabel => '資料夾顏色';

  @override
  String get projectListMaterialIncludeTitle => '包含素材';

  @override
  String get projectListMaterialIncludeHint => '若不包含，接收方將看到缺少素材的警告。';

  @override
  String get projectListMaterialImage => '圖片';

  @override
  String get projectListMaterialVideo => '影片';

  @override
  String get projectListMaterialAudio => '音訊';

  @override
  String get projectListIncludeFontsTitle => '包含字型';

  @override
  String get projectListIncludeFontsSubtitle => '包含目前使用中的使用者新增字型';

  @override
  String get blendModeNormal => '正常';

  @override
  String get blendModeMultiply => '色彩增值';

  @override
  String get blendModeScreen => '濾色';

  @override
  String get blendModeOverlay => '覆蓋';

  @override
  String get blendModeAddition => '添加';

  @override
  String get blendModeSubtract => '減去';

  @override
  String get blendModeDarken => '變暗';

  @override
  String get blendModeLighten => '變亮';

  @override
  String get blendModeColorBurn => '顏色加深';

  @override
  String get blendModeColorDodge => '顏色減淡';

  @override
  String get blendModeHardLight => '實光';

  @override
  String get blendModeSoftLight => '柔光';

  @override
  String get blendModeDifference => '差異';

  @override
  String get blendModeHue => '色相';

  @override
  String get blendModeSaturation => '飽和度';

  @override
  String get blendModeColor => '顏色';

  @override
  String get blendModeLuminosity => '明度';

  @override
  String get autofillLineColorModeSpecified => '指定顏色';

  @override
  String get autofillLineColorModeSameAsFill => '與填色相同';

  @override
  String get autofillLineColorModeTraceAdjust => '顏色描線・與線稿融合';

  @override
  String get autofillGradientTypeLinear => '直線';

  @override
  String get autofillGradientTypeRadialCenterOut => '放射：中央→外側';

  @override
  String get autofillGradientTypeRadialOutCenter => '放射：外側→中央';

  @override
  String get autofillPresetScreenTitle => '自動上色設定';

  @override
  String get autofillPresetSearchHint => '搜尋設定';

  @override
  String get autofillPresetEmptyFavorites => '沒有收藏的設定';

  @override
  String get autofillPresetEmpty => '沒有設定';

  @override
  String get autofillPresetEmptyHint => '點擊右下角的「＋」建立';

  @override
  String autofillPresetPartsCount(int count) {
    return '$count個部件';
  }

  @override
  String get autofillPresetNewDialogTitle => '新增';

  @override
  String get autofillPresetNameLabel => '設定名稱';

  @override
  String get autofillPresetRenameDialogTitle => '重新命名設定';

  @override
  String autofillPresetDeleteConfirmTitle(String name) {
    return '要刪除「$name」嗎？';
  }

  @override
  String get autofillFabImportOption => '匯入';

  @override
  String get autofillPresetExportMenuItem => '匯出 (.niafill)';

  @override
  String autofillPresetImportSuccessSnackbar(int count) {
    return '已匯入$count個預設';
  }

  @override
  String autofillPresetImportFailedSnackbar(String error) {
    return '匯入失敗：$error';
  }

  @override
  String autofillPresetExportFailedSnackbar(String error) {
    return '匯出失敗：$error';
  }

  @override
  String autofillPresetDuplicateName(String name) {
    return '$name（副本）';
  }

  @override
  String get autofillPartSearchHint => '以部件名稱搜尋';

  @override
  String autofillPartUnconfiguredBanner(int count, String names) {
    return '有$count個部件尚未設定：$names（未選擇網點）\n全部設定完成前無法關閉此畫面。';
  }

  @override
  String get autofillPartUnconfiguredDialogTitle => '有尚未設定的部件';

  @override
  String get autofillPartUnconfiguredDialogBody => '儲存前請先設定以下部件。';

  @override
  String autofillPartUnconfiguredItem(String name) {
    return '・$name：未選擇網點';
  }

  @override
  String get autofillPartUnconfiguredBackButton => '返回設定';

  @override
  String get autofillPartEmpty => '沒有部件\n請點擊＋按鈕新增';

  @override
  String get autofillPartToneUnselected => '未選擇網點';

  @override
  String get autofillPartAddDialogTitle => '新增部件';

  @override
  String get autofillPartNameLabel => '部件名稱';

  @override
  String get autofillPartAddButton => '新增';

  @override
  String get autofillPartRenameDialogTitle => '重新命名部件';

  @override
  String autofillPartDetailDialogTitle(String name) {
    return '$name的詳細設定';
  }

  @override
  String get autofillPartFillColorLabel => '填色';

  @override
  String get autofillPartSelectColorButton => '選擇顏色';

  @override
  String get autofillPartOutlineLabel => '用指定顏色描邊';

  @override
  String autofillPartOutlineWidthLabel(int value) {
    return '描邊粗細：${value}px';
  }

  @override
  String get autofillEyedropperFromThumbnailButton => '從圖片取色';

  @override
  String get autofillEyedropperDialogTitle => '從圖片中拾取顏色';

  @override
  String get autofillEyedropperDialogHint => '點擊圖片以選擇顏色';

  @override
  String get autofillEyedropperPickedLabel => '已選顏色';

  @override
  String get autofillEyedropperImageLoadFailedSnackbar => '無法載入圖片。';

  @override
  String get autofillThumbnailMenuItem => '設定縮圖';

  @override
  String get autofillThumbnailLoadButton => '載入圖片';

  @override
  String get autofillThumbnailDeleteButton => '刪除縮圖';

  @override
  String get autofillThumbnailDeleteConfirmTitle => '要刪除縮圖嗎？';

  @override
  String get autofillThumbnailDeleteConfirmBody => '刪除後將恢復為預設的部件顏色顯示（最多4色）。';

  @override
  String get autofillThumbnailCropDialogTitle => '調整縮圖';

  @override
  String get autofillThumbnailCropDialogHint => '拖曳調整位置，雙指縮放，雙指旋轉';

  @override
  String get autofillThumbnailCropLoadFailed => '無法載入圖片，請嘗試其他圖片。';

  @override
  String get autofillThumbnailSetSnackbar => '已設定縮圖';

  @override
  String get autofillPartGradientSetButton => '設定漸層';

  @override
  String get autofillPartGradientEditButton => '編輯漸層';

  @override
  String autofillPartFillOpacityLabel(int value) {
    return '不透明度（填色圖層）：$value%';
  }

  @override
  String get autofillPartLineColorLabel => '線稿顏色';

  @override
  String autofillPartTraceHueLabel(int value) {
    return '色相：$value';
  }

  @override
  String autofillPartTraceSaturationLabel(int value) {
    return '飽和度：$value';
  }

  @override
  String autofillPartTraceLightnessLabel(int value) {
    return '明度：$value';
  }

  @override
  String autofillPartLineOpacityLabel(int value) {
    return '不透明度（線稿圖層）：$value%';
  }

  @override
  String get autofillPartToneLabel => '網點';

  @override
  String get autofillPartUseToneCheckbox => '使用網點';

  @override
  String get autofillPartBlendModeLabel => '混合模式';

  @override
  String get autofillPartApplyButton => '套用';

  @override
  String autofillPartGradientDialogTitle(String name) {
    return '$name的漸層';
  }

  @override
  String get autofillPartGradientTypeLabel => '種類';

  @override
  String get autofillPartGradientTypeInfo =>
      '線性：顏色沿指定角度漸變。放射：中心→外側從中心向外變化，外側→中心則相反。';

  @override
  String get autofillPartGradientFeatherInfo =>
      '設為0%時相鄰顏色的邊界會清晰分明。設為100%時會與相鄰顏色的邊緣完全平滑混合。';

  @override
  String get autofillLineColorModeTraceAdjustInfo =>
      '保留原本的線條顏色，只微調色相、飽和度、明度。想保留線稿的濃淡而不是用單色填滿線條時使用此功能。';

  @override
  String autofillPartGradientAngleLabel(int value) {
    return '角度：$value°';
  }

  @override
  String get autofillPartGradientColorLabel => '顏色';

  @override
  String get autofillPartGradientAddColorButton => '新增顏色';

  @override
  String get autofillPartGradientRemoveButton => '解除漸層';

  @override
  String autofillPartGradientFeatherLabel(int value) {
    return '模糊強度: $value%';
  }

  @override
  String get autofillPartGradientDragHint => '拖曳右側的把手可調整顏色順序';

  @override
  String autofillPartGradientStopLabel(int value) {
    return '切換位置: $value%';
  }

  @override
  String get autofillPartGradientStopDragHint => '左右拖曳▲標記可調整各顏色的位置';

  @override
  String get saveTreeScreenTitleTree => '存檔樹';

  @override
  String get saveTreeScreenTitleSlot => '存檔槽';

  @override
  String get timelineExportMenuItem => '匯出';

  @override
  String get timelineExportFrameMenuItem => '將目前影格匯出為圖片';

  @override
  String get timelineExportFrameDialogTitle => '將目前影格匯出為圖片';

  @override
  String get timelineExportFrameDialogMessage => '將目前顯示的這一影格儲存為靜態圖片。請選擇格式。';

  @override
  String get timelineExportFramePngOption => '儲存為PNG';

  @override
  String get timelineExportFrameJpegOption => '儲存為JPEG';

  @override
  String timelineExportFrameSuccessSnackbar(String fileName) {
    return '已儲存為$fileName（可於作品一覽分頁中確認）';
  }

  @override
  String get timelineExportFrameErrorSnackbar => '影格匯出失敗';

  @override
  String get timelineDurationChangeMenuItem => '變更長度';

  @override
  String get timelineCanvasSizeChangeMenuItem => '變更畫布尺寸';

  @override
  String get timelineDurationFramesLabel => '影格數';

  @override
  String get timelineDurationSecondsLabel => '秒數';

  @override
  String get timelineDurationShrinkConfirmTitle => '確定要縮短嗎？';

  @override
  String get timelineDurationShrinkConfirmBody =>
      '將被裁掉範圍內的影格中，含有繪製內容或新增圖層等變更。繼續操作後，這些影格將無法復原。確定要刪除嗎？';

  @override
  String get timelineCanvasSizeDragHint => '拖曳框內可移動位置，拖曳四角可調整大小（接近原始尺寸時會自動吸附）';

  @override
  String get timelineCanvasSizeAngleLabel => '角度';

  @override
  String get saveTreeSaveAsChildHint => '將儲存為所選節點的子節點。';

  @override
  String get saveTreeSaveAsRootHint => '將儲存為根節點。';

  @override
  String get saveTreeCommentLabel => '備註（選填）';

  @override
  String get saveTreeCommentHint => '例：背景完成';

  @override
  String saveTreeSizeWarningSnackbar(String mb) {
    return '存檔樹的容量正在變大（約${mb}MB）。建議刪除不需要的存檔資料。';
  }

  @override
  String saveTreeSaveFailedSnackbar(String error) {
    return '儲存失敗。請確認剩餘儲存空間後再試一次（$error）';
  }

  @override
  String saveTreeSlotSaveDialogTitle(int n) {
    return '儲存到儲存槽 $n';
  }

  @override
  String saveTreeSlotOverwriteWarning(String date) {
    return '將覆蓋現有資料（$date）。';
  }

  @override
  String get saveTreeRestoreAction => '還原';

  @override
  String get saveTreeTimelineActionChoiceBody =>
      '請選擇是用目前內容「覆蓋儲存」這個存檔，還是「從此處繼續作業」。';

  @override
  String get saveTreeOverwriteAction => '覆蓋儲存';

  @override
  String get saveTreeOverwriteConfirmBody => '該時間點的存檔資料將會消失，確定嗎？';

  @override
  String get saveTreeResumeFromHereAction => '從此處繼續';

  @override
  String get saveTreeResumeConfirmBody => '尚未儲存的目前資料將會消失，確定嗎？';

  @override
  String get saveTreeProjectDetailResumeBody => '要從這個存檔繼續作業嗎？';

  @override
  String get saveTreeLoadFailedSnackbar => '存檔資料讀取失敗';

  @override
  String saveTreeRestoredSnackbar(String name) {
    return '已還原$name';
  }

  @override
  String saveTreeSlotLabel(int n) {
    return '儲存槽$n';
  }

  @override
  String saveTreeSlotFallbackName(int n) {
    return '儲存槽 $n';
  }

  @override
  String get saveTreeNoDataLabel => '沒有存檔資料';

  @override
  String get saveTreeEmptyTitle => '沒有存檔資料';

  @override
  String get saveTreeEmptyHint => '點擊上方的「保存」按鈕即可建立第一個節點';

  @override
  String get saveTreeNodeDefaultTitle => '存檔';

  @override
  String get saveTreeNodeDefaultName => '存檔資料';

  @override
  String get saveTreeChangeDataTitle => '變更存檔資料';

  @override
  String saveTreeChangeDataTitleWithProject(String name) {
    return '變更存檔資料（$name）';
  }

  @override
  String get saveTreeChangeExceedMessage =>
      '目前的存檔數量已\n超過新的可存檔數量上限。\n\n請選擇要保留的存檔資料。';

  @override
  String saveTreeKeepableCountLabel(int n) {
    return '可保留的存檔數：$n個';
  }

  @override
  String saveTreeKeepLatestButton(int n) {
    return '保留最新$n個';
  }

  @override
  String get saveTreeSelectDataButton => '選擇存檔資料';

  @override
  String saveTreeSelectedCountLabel(int selected, int limit) {
    return '已選擇：$selected / $limit個';
  }

  @override
  String get saveTreeBackButton => '返回';

  @override
  String get saveTreeNextButton => '下一步';

  @override
  String get saveTreeDiscardDialogTitle => '未選擇的存檔資料';

  @override
  String get saveTreeArchiveOptionTitle => '保留為封存（建議）';

  @override
  String get saveTreeArchiveOptionSubtitle => '切換回存檔樹方式時會自動還原。\n會佔用儲存空間。';

  @override
  String get saveTreeDeleteOptionTitle => '徹底刪除';

  @override
  String saveTreeDeleteOptionSubtitle(int count) {
    return '將徹底刪除未選擇的$count個資料。\n可節省儲存空間。\n※刪除後的資料無法復原。';
  }

  @override
  String get saveTreeApplyChangeButton => '套用變更';

  @override
  String get canvasEditMenuAutofillPresets => '自動上色設定';

  @override
  String get canvasEditMenuAutofillPresetsSubtitle => '編輯各部位的顏色・網點組合';

  @override
  String get canvasEditMenuBackgroundToggle => '切換背景';

  @override
  String get canvasEditMenuBackgroundCurrentColor => '目前：專案背景色（點擊切換為透明）';

  @override
  String get canvasEditMenuBackgroundCurrentTransparent => '目前：透明（點擊切換為專案背景色）';

  @override
  String get canvasEditMenuOnionSkinSubtitle => '以淡淡的方式疊加顯示前後格';

  @override
  String get canvasEditMenuFilterSubtitle => '套用模糊、色調曲線等效果';

  @override
  String get canvasEditMenuFrameMultiSelect => '多選影格';

  @override
  String get canvasEditMenuFrameMultiSelectSubtitle => '用於批次處理（如批次套用濾鏡等）';

  @override
  String get canvasEditMenuPressureCurve => '筆壓曲線';

  @override
  String get canvasEditMenuPressureCurveSubtitle => '開啟畫筆輸入設定（與設定畫面共用）';

  @override
  String get canvasEditMenuMeshTransform => '自由變形・網格變形';

  @override
  String get canvasEditMenuMeshTransformSubtitle => '無需選取範圍即可變形整個圖層';

  @override
  String get meshTransformPanelTitle => '自由變形・網格變形';

  @override
  String get meshTransformPanelHint => '用手指拖曳角點或網格點（雙指同時拖曳不同的點即可旋轉、縮放）';

  @override
  String get meshTransformDensityLabel => '網格密度';

  @override
  String get meshTransformRotateLabel => '旋轉';

  @override
  String get meshTransformScaleLabel => '縮放';

  @override
  String get meshTransformApplyButton => '套用';

  @override
  String get canvasLassoEnclosedLabel => '填滿封閉區域';

  @override
  String get canvasInvertSelectionTooltip => '反轉選取範圍';

  @override
  String get canvasTapToEnterTextLabel => '點擊畫布輸入文字';

  @override
  String get canvasRulerFirstUseTip => '使用尺規可以畫出筆直的線條和整齊的圖形。';

  @override
  String get canvasRulerTooltip => '尺規';

  @override
  String get commonUndo => '復原';

  @override
  String get commonRedo => '取消復原';

  @override
  String get canvasSettingsMenuTooltip => '設定/編輯';

  @override
  String canvasFrameSelectedCount(int selected, int total) {
    return '已選擇 $selected / $total 格';
  }

  @override
  String get canvasSelectAllButton => '全選';

  @override
  String get canvasDeselectAllButton => '取消全選';

  @override
  String get canvasApplyFilterButton => '套用濾鏡';

  @override
  String get canvasShapeOff => 'OFF（返回一般筆刷）';

  @override
  String get canvasShapeLine => '線條';

  @override
  String get canvasShapeRect => '矩形';

  @override
  String get canvasShapeCircle => '圓形';

  @override
  String get canvasMissingMaterialsSnackbar => '有缺少的素材';

  @override
  String get canvasResearchButton => '重新搜尋';

  @override
  String get canvasTextInputTitle => '輸入文字';

  @override
  String get canvasTextEditTitle => '編輯文字';

  @override
  String get canvasTextInputHint => '請輸入文字';

  @override
  String get canvasTextFontLabel => '字型';

  @override
  String get canvasTextStandardFont => '標準字型';

  @override
  String get canvasTextBold => '粗體';

  @override
  String get canvasTextItalic => '斜體';

  @override
  String get canvasTextVertical => '直排';

  @override
  String get canvasTextHorizontal => '橫排';

  @override
  String get canvasTypesettingHelpTooltip => '關於排版與注音';

  @override
  String get canvasTextLineHeight => '行距';

  @override
  String get canvasTextLetterSpacing => '字距';

  @override
  String get canvasTextAlign => '對齊';

  @override
  String get canvasTextOutline => '外框';

  @override
  String get canvasOutlineWidthLabel => '粗細';

  @override
  String get canvasHelpRotationTitle => '半形英數字旋轉（僅限直排）';

  @override
  String get canvasHelpRotationBody => '英文字母和符號會自動旋轉90°顯示。';

  @override
  String get canvasHelpTatechuyokoTitle => '縱中橫（僅限直排）';

  @override
  String get canvasHelpTatechuyokoBody =>
      '連續2位半形數字會自動以橫向排列的方式收納在一個字元的高度內（例：12）。';

  @override
  String get canvasHelpRubyTitle => '注音標示（類似日文振假名的讀音標示）';

  @override
  String canvasHelpRubyBody(String example) {
    return '輸入類似「$example」的格式，會在基底文字上方（橫排時）或右側（直排時）顯示小號的讀音標示。直排、橫排皆可使用，但含有注音標示的文字在橫排時將無法自動換行（僅支援手動換行）。';
  }

  @override
  String get layerPanelTitle => '圖層';

  @override
  String get layerPanelHelpTooltip => '說明';

  @override
  String get layerPanelSearchHint => '依圖層名稱搜尋';

  @override
  String get layerPanelSelectAll => '全選';

  @override
  String get layerPanelDeselectAll => '取消全選';

  @override
  String get layerPanelNewLayerButton => '新增圖層';

  @override
  String get layerPanelNewFolderButton => '新增資料夾';

  @override
  String get layerPanelImportImageButton => '匯入圖片';

  @override
  String layerPanelDefaultLayerName(int n) {
    return '圖層$n';
  }

  @override
  String layerPanelDefaultFolderName(int n) {
    return '資料夾$n';
  }

  @override
  String layerPanelDefaultLineartName(int n) {
    return '線稿$n';
  }

  @override
  String layerPanelDefaultAutofillName(int n) {
    return '自動上色$n';
  }

  @override
  String layerPanelDefaultCommonName(int n) {
    return '共用$n';
  }

  @override
  String layerPanelDefaultSelectionName(int n) {
    return '選取$n';
  }

  @override
  String get layerPanelClippingBadge => '剪裁';

  @override
  String get layerPanelAddTooltip => '新增';

  @override
  String get layerPanelAutofillMarkTooltip => '線稿已更新。點一下即可將自動上色更新為最新狀態。';

  @override
  String get layerPanelRangeAllFrames => '全部影格';

  @override
  String get layerPanelRangeCurrentScene => '目前場景';

  @override
  String get layerPanelRangeSceneSpecified => '指定場景';

  @override
  String layerPanelRangeFrameSpan(int start, int end) {
    return '$start〜$end';
  }

  @override
  String get layerPanelMenuFrameRangeChange => '變更顯示影格範圍';

  @override
  String get layerPanelMenuRangeChange => '變更顯示範圍';

  @override
  String get layerPanelMenuPartAssign => '部件設定';

  @override
  String get layerPanelMenuRunAutofill => '執行自動上色';

  @override
  String get layerPanelMenuOrphanFill => '以最新顏色填色';

  @override
  String get layerPanelMenuOrphanFillSubtitle => '找不到對應的線稿圖層，因此僅執行顏色更新';

  @override
  String get layerPanelMenuReplaceMaterial => '替換素材';

  @override
  String layerPanelDeleteConfirmTitle(String name) {
    return '要刪除$name嗎？';
  }

  @override
  String get layerPanelDeleteConfirmBody => '將從此素材顯示範圍內的所有影格中刪除。';

  @override
  String layerPanelCommonDeleteMidDialogTitle(String name) {
    return '要變更「$name」的顯示範圍嗎？';
  }

  @override
  String get layerPanelCommonDeleteMidDialogBody =>
      '共用圖層的顯示範圍只能設定為一個連續區間，因此無法在範圍中間的某一影格刪除。請選擇要保留此影格之前還是之後的部分。';

  @override
  String get layerPanelCommonDeleteKeepBeforeButton => '保留此影格之前';

  @override
  String get layerPanelCommonDeleteKeepAfterButton => '保留此影格之後';

  @override
  String get layerPanelRangeDialogTitle => '顯示範圍';

  @override
  String get layerPanelRangeStartFrameLabel => '起始影格';

  @override
  String get layerPanelRangeEndFrameLabel => '結束影格';

  @override
  String get layerPanelRangeTilde => '〜';

  @override
  String get layerPanelRangeUseCurrentButton => '使用目前範圍';

  @override
  String get layerPanelRangeTargetSceneLabel => '目標場景';

  @override
  String get layerPanelRangeFrameRangeLabel => '指定影格範圍';

  @override
  String get layerPanelMenuNormalLayer => '一般圖層';

  @override
  String get layerPanelMenuCommonLayer => '共用圖層';

  @override
  String get layerPanelMenuLineartLayer => '自動上色用線稿圖層';

  @override
  String get layerPanelMenuAutofillLayer => '自動上色圖層';

  @override
  String get layerPanelMenuSelectionLayer => '選取圖層';

  @override
  String get layerPanelOpacityLabel => '不透明度';

  @override
  String get layerPanelLockLabel => '鎖定';

  @override
  String get layerPanelOpacityLockLabel => '鎖定不透明度';

  @override
  String get layerPanelClippingDescription => '僅在下方圖層的不透明範圍內繪製';

  @override
  String get layerPanelConvertToCommonLabel => '變更為共用圖層';

  @override
  String get layerPanelConvertOption1Title => '將目前圖層設為共用圖層';

  @override
  String get layerPanelConvertOption1Subtitle => '僅將此圖層設定為共用圖層';

  @override
  String get layerPanelConvertOption2Title => '合併顯示中的圖層後設為共用圖層';

  @override
  String get layerPanelConvertOption2Subtitle => '將目前顯示中所有圖層合併的結果建立為共用圖層';

  @override
  String get layerPanelCommonRangeTitle => '共用圖層範圍';

  @override
  String get layerPanelHelpDialogTitle => '關於圖層';

  @override
  String get layerPanelHelpBlendModeBody => '變更圖層的合成方式，包括色彩增值、濾色、覆蓋等。';

  @override
  String get layerPanelHelpClippingBody => '僅在下方圖層的不透明像素範圍內繪製。需要控制繪製範圍時請使用此功能。';

  @override
  String get layerPanelCommonLayerLabel => '共用圖層';

  @override
  String get layerPanelHelpCommonLayerBody => '在多個影格之間共用相同內容的圖層。可設定顯示的影格範圍。';

  @override
  String get layerPanelAutofillMethodTitle => '自動上色方式';

  @override
  String get layerPanelAutofillNoLineartSnackbar => '找不到對應的自動上色用線稿圖層。';

  @override
  String get layerPanelAutofillNote1 => '※ 若為專案內首次執行自動上色，選擇哪一項都沒有問題。';

  @override
  String get layerPanelAutofillNote2 => '※ 若不存在自動上色圖層，無論選擇哪一項都會從頭判定區域進行自動上色。';

  @override
  String get layerPanelAutofillRepaintTitle => '重新上色';

  @override
  String get layerPanelAutofillRepaintHint => '不慎改變了自動上色形狀時推薦使用';

  @override
  String get layerPanelAutofillRepaintNote => '※ 將從頭判定區域重新上色。目前自動上色圖層的形狀將被捨棄。';

  @override
  String get layerPanelAutofillColorUpdateTitle => '顏色更新';

  @override
  String get layerPanelAutofillColorUpdateHint => '手動調整過自動上色形狀時推薦使用';

  @override
  String get layerPanelAutofillColorUpdateNote =>
      '※ 將鎖定不透明度並以最新顏色填色。目前自動上色圖層的形狀將維持不變。';

  @override
  String get layerPanelExecuteButton => '執行';

  @override
  String get layerPanelAutofillPartMissingSnackbar => '尚未設定部件。請透過「部件設定」進行設定。';

  @override
  String get layerPanelAutofillPresetMissingSnackbar => '在自動上色設定中找不到對應的部位。';

  @override
  String get layerPanelOrphanFillSuccessSnackbar => '找不到對應的線稿圖層，已改為以最新顏色填色。';

  @override
  String get layerPanelOrphanFillFailSnackbar => '未設定部件，或沒有填色形狀，因此無法處理。';

  @override
  String get layerPanelAutofillUpdateHelpTitle => '自動上色更新標記';

  @override
  String get layerPanelAutofillUpdateHelpBody => '目前的自動上色並非最新狀態。點一下即可更新。';

  @override
  String layerPanelReplaceMaterialSuccessSnackbar(String name) {
    return '已替換素材：$name';
  }

  @override
  String layerPanelImportImageSuccessSnackbar(String name) {
    return '已匯入圖片：$name';
  }

  @override
  String layerPanelCopySuffix(String name) {
    return '$name的副本';
  }

  @override
  String get timelineFullscreenPreviewCloseTooltip => '關閉全螢幕預覽';

  @override
  String get timelineDefaultProjectName => '專案名稱';

  @override
  String get timelinePreviewPlaceholder => '預覽';

  @override
  String get timelinePreviewFullscreenTip => '點一下即可全螢幕顯示預覽，方便確認成品效果。';

  @override
  String get timelinePreviewFullscreenTooltip => '全螢幕顯示預覽';

  @override
  String get timelineAddVideoTooltip => '＋影片';

  @override
  String get timelineAddAudioTooltip => '＋音源';

  @override
  String get timelineEffectFilterLabel => '演出濾鏡';

  @override
  String get timelineAddCameraKfTooltip => '新增相機關鍵影格';

  @override
  String get timelineAddWatermarkTooltip => '＋浮水印';

  @override
  String get timelineWatermarkNotRegisteredTitle => '尚未註冊浮水印';

  @override
  String get timelineWatermarkNotRegisteredBody => '請先在設定畫面的「浮水印」中註冊圖片或文字。';

  @override
  String get timelineOpenSettingsButton => '開啟設定';

  @override
  String get timelineWatermarkSelectTitle => '選擇浮水印';

  @override
  String timelineWatermarkAddedSnackbar(String name) {
    return '已新增浮水印（將顯示於全部影格）：$name';
  }

  @override
  String get timelineWatermarkEditTitle => '編輯浮水印';

  @override
  String get timelineWatermarkAngleLabel => '角度';

  @override
  String get timelineWatermarkSizeLabel => '大小';

  @override
  String get timelineWatermarkOpacityLabel => '不透明度';

  @override
  String get timelineWatermarkLoopLabel => '永遠顯示（循環顯示）';

  @override
  String get timelineWatermarkLoopSubtitle => '關閉後僅顯示於目前場景';

  @override
  String get timelineConfirmButton => '確定';

  @override
  String get timelineClipSelectDoneButton => '完成';

  @override
  String get timelineClipOverlapDialogTitle => '與現有片段重疊';

  @override
  String get timelineClipOverlapDialogBody => '貼上位置與現有片段重疊，要如何放置？';

  @override
  String get timelineClipOverlapPlaceBefore => '放在前面';

  @override
  String get timelineClipOverlapPlaceAfter => '放在後面';

  @override
  String get timelineClipOverlapPlaceNewRow => '重疊放置（新增一行）';

  @override
  String get timelineSceneRenameTitle => '場景改名';

  @override
  String get timelineSceneDeleteMenuItem => '刪除場景';

  @override
  String get timelineDurationLimitTitle => '已達到長度上限';

  @override
  String get timelineDurationLimitBodyFree =>
      '免費會員的影片長度最長為90秒。繼續新增或複製畫格會超過90秒，因此無法執行。升級為進階會員後最長可製作2小時。';

  @override
  String get timelineDurationLimitBodyPremium =>
      '這會超過進階會員的上限（最長2小時），因此無法繼續新增或複製畫格。';

  @override
  String timelineSceneDeleteConfirmTitle(String name) {
    return '要刪除「$name」嗎？';
  }

  @override
  String get timelineSceneDeleteConfirmBody =>
      '場景內的全部影格、共用圖層、影片素材、圖片素材、浮水印等全部資料都將被刪除。';

  @override
  String timelineSceneMultiDeleteConfirmTitle(int count) {
    return '要刪除已選取的$count個場景嗎？';
  }

  @override
  String get timelineAutofillUpdateHelpBody =>
      '此場景／影格中包含並非最新狀態的自動上色圖層。在圖層面板中點一下目標圖層即可更新。';

  @override
  String get timelineFrameTrackLabel => '影格';

  @override
  String get timelineTrackRowRenameTitle => '重新命名行';

  @override
  String get timelineCameraTrackLabel => '相機';

  @override
  String get timelineRangeSceneFixed => '固定場景';

  @override
  String get timelineEndCardDefaultLogoLabel => 'NIARIM標誌';

  @override
  String get timelineEndCardHiddenLabel => '隱藏';

  @override
  String get timelineEndCardTrackLabel => '片尾卡軌道';

  @override
  String get timelineMarkerTrackLabel => '時間戳記';

  @override
  String timelineMarkerAddDialogTitle(int n) {
    return '在F$n加入時間戳記';
  }

  @override
  String timelineMarkerEditDialogTitle(int n) {
    return '時間戳記：F$n';
  }

  @override
  String get timelineMarkerCommentHint => '備註（例：這裡對嘴形「啊」）';

  @override
  String timelineAddClipDialogTitle(String trackName) {
    return '新增$trackName片段';
  }

  @override
  String get timelineClipLabelFieldLabel => '標籤';

  @override
  String get timelineClipStartLabel => '開始：';

  @override
  String get timelineClipLengthLabel => '長度：';

  @override
  String get timelineAutofillNote2 =>
      '※ 若僅存在自動上色圖層（無線稿），無論選擇哪一項都會從頭判定區域進行自動上色。';

  @override
  String get timelineAutofillTargetLabel => '執行對象';

  @override
  String get timelineAutofillScopeCurrentFrame => '僅目前影格';

  @override
  String get timelineAutofillScopeCurrentScene => '以場景為單位（目前場景的全部影格）';

  @override
  String get timelineAutofillScopeAllScenes => '全部影格（整個專案）';

  @override
  String get timelineAutofillProgressTitle => '正在執行自動上色';

  @override
  String timelineAutofillProgressSubtitle(int count) {
    return '$count影格';
  }

  @override
  String timelineAutofillCompleteSnackbar(int count) {
    return '自動上色已完成（處理了$count項）';
  }

  @override
  String get timelineEffectTypeFade => '淡入淡出';

  @override
  String get timelineEffectTypeGaussianBlur => '高斯模糊';

  @override
  String get timelineEffectTypeLensBlur => '鏡頭模糊';

  @override
  String get timelineEffectTypeMosaic => '馬賽克';

  @override
  String get timelineEffectTypeChromaticAberration => '色差';

  @override
  String get timelineEffectTypeNoise => '雜訊';

  @override
  String get timelineEffectTypeSepia => '懷舊棕褐';

  @override
  String get timelineEffectTypeAnimeStyle => '動漫風';

  @override
  String get timelineEffectTypeRetroAnime => '復古動漫';

  @override
  String get timelineEffectTypeCrt => '老電視';

  @override
  String get timelineEffectTypeAnimatedNoise => '動態雜訊';

  @override
  String get timelineEffectTypeRain => '下雨';

  @override
  String get timelineEffectFilterEmptyState => '沒有濾鏡\n請點選＋新增按鈕來新增';

  @override
  String get timelineRangeStartLabel => '開始';

  @override
  String get timelineRangeEndLabel => '結束';

  @override
  String get timelineEffectSizeLabel => '大小';

  @override
  String get timelineEffectStrengthLabel => '強度';

  @override
  String get timelineEffectAmountLabel => '數量';

  @override
  String get timelineEffectGrainSizeLabel => '顆粒大小';

  @override
  String get timelineEffectRainIntensityLabel => '降雨強度';

  @override
  String get timelineEffectRainSpeedLabel => '速度';

  @override
  String get timelineEffectRainSizeLabel => '雨滴大小';

  @override
  String get timelineEffectWindAngleLabel => '風向角度';

  @override
  String get timelineColorLabel => '顏色';

  @override
  String get timelineColorBlack => '黑';

  @override
  String get timelineColorWhite => '白';

  @override
  String get timelineColorCustom => '自訂';

  @override
  String get timelineFadeColorDialogTitle => '淡入淡出顏色';

  @override
  String get timelineAddFilterDialogTitle => '新增濾鏡';

  @override
  String get timelineClipVolumeLabel => '音量';

  @override
  String get timelineClipFadeInLabel => '淡入';

  @override
  String get timelineClipFadeOutLabel => '淡出';

  @override
  String get timelineClipUseStartLabel => '使用起始影格';

  @override
  String get timelineClipUseEndLabel => '使用結束影格';

  @override
  String timelineCameraKfTitle(int n) {
    return '相機關鍵影格：F$n';
  }

  @override
  String get timelineCameraMoveXLabel => 'X 移動';

  @override
  String get timelineCameraMoveYLabel => 'Y 移動';

  @override
  String get timelineCameraZoomLabel => '縮放';

  @override
  String get timelineCameraRotationLabel => '旋轉';

  @override
  String get layerPanelKeyframeLabel => '動畫（關鍵影格）';

  @override
  String layerKeyframeSheetTitle(String name) {
    return '$name 的關鍵影格';
  }

  @override
  String get layerKeyframeSheetDesc =>
      '依影格設定此圖層的位置・縮放・旋轉，關鍵影格之間會自動內插。圖層本身的畫面內容不會改變。';

  @override
  String layerKeyframeAddAtCurrentFrame(int n) {
    return '在目前影格（F$n）加入';
  }

  @override
  String get layerKeyframeEmpty => '還沒有關鍵影格，請用上方按鈕加入。';

  @override
  String get layerKeyframeScaleShort => '縮放';

  @override
  String get layerKeyframeRotationShort => '旋轉';

  @override
  String layerKeyframeEditTitle(int n) {
    return '關鍵影格：F$n';
  }

  @override
  String get layerKeyframeFrameLabel => '影格';

  @override
  String get layerKeyframeScaleLabel => '縮放';

  @override
  String get layerKeyframeRotationLabel => '旋轉';

  @override
  String get layerKeyframeEasingLabel => '過渡到下一關鍵影格的方式';

  @override
  String get layerKeyframeEasingLinear => '等速';

  @override
  String get layerKeyframeEasingEaseIn => '緩入（開始慢）';

  @override
  String get layerKeyframeEasingEaseOut => '緩出（結束慢）';

  @override
  String get layerKeyframeEasingEaseInOut => '緩入緩出';

  @override
  String get layerKeyframeEasingBounceOut => '彈跳';

  @override
  String get layerPanelGroupTooltip => '群組化';

  @override
  String get layerPanelShowSelectedTooltip => '顯示所有選取的圖層';

  @override
  String get layerPanelHideSelectedTooltip => '隱藏所有選取的圖層';

  @override
  String get layerPanelGroupDefaultName => '新增群組';

  @override
  String layerPanelGroupMembershipLabel(String name) {
    return '群組：$name';
  }

  @override
  String get layerPanelGroupLeaveAction => '解除';

  @override
  String frameStripHoldDialogTitle(int n) {
    return 'F$n 保持格數';
  }

  @override
  String get frameStripFrameListModeLabel => '影格清單';

  @override
  String get frameStripTimelineModeLabel => '時間軸';

  @override
  String get progressDialogAdLoading => '廣告載入中…';

  @override
  String get adMockPlaceholderLabel => '廣告橫幅（用於版位試驗的模型）';

  @override
  String get adMediumRectangleMockPlaceholderLabel => '中型矩形廣告（300×250 版位測試模型）';

  @override
  String get progressDialogTipLabel => '提示';

  @override
  String get premiumBannerRegisterButton => '升級Premium';

  @override
  String get licenseTermsArt1Title => '第1條（適用範圍）';

  @override
  String get licenseTermsArt1Body =>
      '本使用條款（以下稱「本條款」）規定了本應用程式「NIARIM」（以下稱「本應用程式」）的使用條件。使用者應於同意本條款後方可使用本應用程式。使用本應用程式即視為已同意本條款。';

  @override
  String get licenseTermsArt2Title => '第2條（使用資格・適用環境）';

  @override
  String get licenseTermsArt2Body =>
      '1. 關於支援的作業系統版本及建議操作環境的詳細資訊，請依各發布商店及本應用程式內之顯示內容為準。\n2. 本應用程式力求於各種效能之裝置皆能順暢使用，惟依裝置效能、作業系統版本、可用儲存空間、設定等使用環境之不同，部分功能可能受限或無法正常運作。';

  @override
  String get licenseTermsArt3Title => '第3條（禁止事項）';

  @override
  String get licenseTermsArt3Body =>
      '使用者於使用本應用程式時，不得為下列行為：\n・違反法令或公序良俗之行為\n・侵害本應用程式、開發者或第三方之著作權、商標權等智慧財產權、肖像權、隱私權或其他權利或利益之行為\n・以反編譯、反組譯、逆向工程或其他解析為目的之行為（法令允許之情形除外）\n・對本應用程式進行未經授權之改造、重製或再散布\n・對本應用程式或其提供基礎設施進行未經授權之存取、施加過度負荷等妨礙其正常提供之行為\n・其他開發者基於合理理由判斷為不當之行為';

  @override
  String get licenseTermsArt4Title => '第4條（創作內容之權利）';

  @override
  String get licenseTermsArt4Body =>
      '1. 使用者利用本應用程式製作之插畫、動畫等內容（包括專案資料、匯出之圖片、影片等，以下稱「創作內容」）所涉及之著作權及其他權利，於法令允許之範圍內，歸屬於就該內容享有權利之使用者或第三方。\n2. 本應用程式未提供將創作內容傳送、蒐集或同步至開發者伺服器之功能。專案資料原則上僅保存於使用者裝置內（使用者自行選擇利用作品廣場功能發布創作內容時之處理方式，請參見第12條）。\n3. 無論使用免費版或進階版製作，開發者均不會以本應用程式之使用費用或版本為由限制創作內容之商業使用（免費版與進階版之差異僅限於片尾卡顯示、匯出時長上限等功能面向）。\n4. 縱有前項規定，使用者新增至本應用程式中之字型、圖片、素材等由第三方享有權利之內容，仍應遵守第5條所定各自之使用條件。';

  @override
  String get licenseTermsArt5Title => '第5條（內建字型・新增素材相關規定）';

  @override
  String get licenseTermsArt5Body =>
      '1. 本應用程式內建之字型及其他素材，均依照本畫面「關於使用字型」所載各授權條款使用。\n2. 關於使用者自行新增登錄或載入本應用程式之字型、圖片、色調、印章等素材之權利關係，應由使用者自行負責，於取得必要權利或授權之前提下合法使用。\n3. 因使用者利用第三方素材而與第三方發生紛爭者，除法令另有規定應負責任之情形外，開發者不負任何責任。';

  @override
  String get licenseTermsArt6Title => '第6條（進階功能・付費）';

  @override
  String get licenseTermsArt6Body =>
      '1. 本應用程式除可免費使用之功能外，另提供透過應用程式內購買（月繳方案、年繳方案及其他進階方案）方可使用之進階功能。\n2. 進階功能之價格、提供內容、購買方式及其他條件，以購買當下本應用程式內或發布商店之顯示內容為準。\n3. 購買後之取消、退款及其他與付款相關之事項，適用Google Play或使用者所使用付款平台之規定；但法令另有規定者，從其規定。\n4. 開發者得基於法令修訂、技術上之必要性、本應用程式之改善等合理事由變更進階功能之內容。進行重大變更時，將於合理可行範圍內，透過本應用程式內或其他適當方式事先告知。';

  @override
  String get licenseTermsArt7Title => '第7條（廣告顯示）';

  @override
  String get licenseTermsArt7Body =>
      '1. 免費版中，可能透過第三方廣告投放服務顯示廣告。\n2. 廣告投放業者對資訊之取得、使用及其他處理，適用各廣告投放業者各自之隱私權政策。';

  @override
  String get licenseTermsArt8Title => '第8條（資訊之處理）';

  @override
  String get licenseTermsArt8Body =>
      '1. 本應用程式未提供將使用者製作之插畫、動畫等內容及專案資料傳送或蒐集至開發者伺服器之功能。此等資料原則上僅保存於使用者裝置內；由於開發者本身不具備保存此類內容之功能，因此開發者端不存在所謂之保存期間概念。\n2. 本應用程式內建之第三方服務（廣告投放、應用程式內購買等）所取得之資訊及其他使用者資訊之處理，依另行訂定之《隱私權政策》辦理。\n3. 解除安裝本應用程式後，保存於裝置內之資料（專案、設定、已新增字型等）將被刪除。';

  @override
  String get licenseTermsArt9Title => '第9條（提供之中止・變更・終止）';

  @override
  String get licenseTermsArt9Body =>
      '1. 開發者於對本應用程式進行維護、更新、修正時，或提供基礎設施發生故障時，或有其他不得已之情形時，得暫時中止本應用程式全部或部分之提供。\n2. 開發者得視需要變更本應用程式之內容，或終止本應用程式之提供。\n3. 前二項情形，除緊急情況外，開發者將盡可能於本應用程式內或以其他適當方式事先公告。\n4. 因本條所定變更、中止、終止而致使用者受有損害者，除法令另有規定應負責任之情形外，開發者不負任何責任。';

  @override
  String get licenseTermsArt10Title => '第10條（免責事項）';

  @override
  String get licenseTermsArt10Body =>
      '1. 開發者不保證本應用程式無事實上或法律上之瑕疵（包括安全性、可靠性、正確性、完整性、對特定目的之適用性、無錯誤或故障等）。\n2. 使用者應自負其責使用本應用程式。因裝置故障、誤操作、作業系統更新等因素，資料可能遺失，故建議使用者利用匯出、分享等功能，就製作中之資料定期進行備份。\n3. 於法令允許之範圍內，開發者對因使用本應用程式而致使用者受有之損害不負責任。惟開發者具故意或重大過失者不在此限；縱屬該情形，開發者所負損害賠償責任亦僅限於通常發生之直接損害，且以使用者於最近一年內就本應用程式實際支付之金額為上限（免費使用之情形為新臺幣0元）。';

  @override
  String get licenseTermsArt11Title => '第11條（本條款之變更）';

  @override
  String get licenseTermsArt11Body =>
      '1. 因法令修正、本應用程式內容變更或其他開發者認有必要之情形，開發者得變更本條款。\n2. 變更本條款時，開發者將事先透過本應用程式內或其他適當方式，公告變更內容及生效日期。\n3. 變更後之本條款，於法令允許之範圍內，自前項所定生效日期起適用。';

  @override
  String get licenseTermsArt12Title => '第12條（作品廣場：社群發布功能）';

  @override
  String get licenseTermsArt12Body =>
      '1. 本應用程式可選擇性地提供以下功能：使用者可透過自己的Google帳號，將自己製作之動畫作品發布至YouTube，並於「作品廣場」上公開、瀏覽（以下稱「本社群功能」）。縱使不使用本社群功能，使用者仍可瀏覽及製作作品。\n2. 已發布之影片檔案本身保存於YouTube上，不會保存於開發者之伺服器上。另一方面，用於識別、顯示已發布作品所需之資訊（YouTube影片ID、標題、統計資訊、檢舉資訊等），以及使用者利用發布、檢舉、封鎖功能時核發之NIARIM User ID（與Google帳號不同、由本應用程式內部核發之識別碼），由開發者之伺服器管理。\n3. 本社群功能中之作品發布、檢舉以及封鎖其他使用者，均須透過Google帳號登入。\n4. 可發布之作品數量設有每日上限（免費會員與進階會員之上限不同）。該上限可能因營運原因而變更。\n5. 若使用者認為其他使用者發布之作品違反法令或公序良俗，或可能符合第3條各款所述情形，得透過本應用程式內之檢舉功能向開發者檢舉。開發者於確認檢舉內容後，得基於合理理由，對相關作品採取自列表中隱藏等必要措施。禁止進行虛偽檢舉或濫用檢舉功能。\n6. 使用者刪除發布內容，或解除本應用程式與Google帳號之連結時，對應之YouTube影片可能會被刪除。此外，若影片於YouTube端被設為非公開或遭刪除，該作品亦將不再於作品廣場上顯示。\n7. 使用本社群功能時，除本條款外，亦應遵守YouTube之服務條款及社群規範。\n8. 使用者得追蹤其他使用者，並得收藏或轉發其他使用者之作品。追蹤中／粉絲清單以及已收藏作品之清單預設為不公開，是否公開由使用者於本應用程式內選擇。追蹤數與粉絲數不論該設定為何均會顯示。\n9. 作品上之標籤亦得由發布者以外之使用者新增或刪除。發布者得鎖定自身作品之標籤，以禁止其他使用者編輯。使用者不得新增誹謗他人之標籤、與作品內容無關之標籤或其他不當標籤。開發者得刪除不當標籤。\n10. 開發者將於遭追蹤等情形時，於本應用程式內之通知清單中顯示通知。使用者於裝置上允許通知之情形下，可能傳送推播通知。通知得自本應用程式之設定或裝置之設定予以停用。\n11. 使用者不得將本社群功能用於騷擾其他使用者、宣傳・招攬或其他偏離其本來目的（作品之公開與瀏覽）之目的。使用封鎖功能後，遭封鎖對象之作品將不再顯示於自身之清單中。';

  @override
  String get licenseTermsArt13Title => '第13條（準據法・管轄法院）';

  @override
  String get licenseTermsArt13Body =>
      '1. 本條款之解釋以日本法為準據法。\n2. 因本應用程式發生紛爭時，依訴訟標的額，以管轄開發者所在地之地方法院或簡易法院為第一審之專屬合意管轄法院。';

  @override
  String get privacyPolicyArt1Title => '第1條（本政策之定位）';

  @override
  String get privacyPolicyArt1Body =>
      '本隱私權政策（以下稱「本政策」）規定本應用程式「NIARIM」（以下稱「本應用程式」）就資訊之處理方式。關於本應用程式使用條件之整體內容，請另行參閱「使用條款・授權」畫面。';

  @override
  String get privacyPolicyArt2Title => '第2條（本應用程式不蒐集之資料）';

  @override
  String get privacyPolicyArt2Body =>
      '本應用程式未提供將使用者製作之插畫、動畫等內容（包括專案資料、匯出之圖片、影片等，以下同）傳送、蒐集或保存至開發者伺服器之功能。此等資料原則上僅保存於使用者裝置內（本應用程式未搭載雲端同步功能）。由於開發者本身不具備保存此類內容之功能，因此開發者端不存在所謂之保存期間概念。裝置內保存之資料，可隨時透過本應用程式之刪除功能予以刪除；解除安裝本應用程式後，保存於裝置內之專案、設定、已新增字型等資料亦將一併刪除（使用者自行選擇利用作品廣場功能發布作品時之資訊處理方式，請參見第7條）。';

  @override
  String get privacyPolicyArt3Title => '第3條（第三方服務所取得之資訊）';

  @override
  String get privacyPolicyArt3Body =>
      '本應用程式內建下列第三方服務，各服務提供者得於提供各自服務所需之範圍內取得資訊。本應用程式之開發者並未實作獨立取得或保存此等資訊之功能（各服務所取得資訊之管理，依各該服務提供者之隱私權政策辦理）。\n\n【廣告投放（Google AdMob）】\n免費版透過Google AdMob投放廣告。基於廣告投放、成效衡量、防止不當行為等目的，Google或其關係企業可能取得並使用廣告識別碼（Advertising ID）等裝置資訊。關於取得及使用之詳情，請參閱Google隱私權政策（https://policies.google.com/privacy）。使用者可透過裝置設定（如Android設定應用程式之「隱私權」等）重設廣告識別碼或停用個人化廣告。若您位於歐洲經濟區（EEA）、英國或瑞士，可於啟動時顯示之同意表單中選擇廣告個人化相關之同意設定，亦可隨時透過本畫面下方之「變更廣告同意設定」按鈕進行修改。\n\n【應用程式內購買（Google Play Billing）】\n進階功能之購買透過Google Play之付款系統進行。開發者不會直接取得或保存信用卡卡號等付款資訊。付款相關資訊之處理依Google Play之規定辦理。\n\n【下載附加字型（GitHub）】\n僅當您在設定畫面的「字型管理」中選擇下載附加字型時，才會與字型檔案的散布方 GitHub（GitHub, Inc.）的伺服器進行通訊。該通訊僅在您選擇下載時發生，應用程式啟動時或正常使用過程中不會發生。傳送的僅為通訊所必需的資訊（IP 位址、所請求的字型檔案等），不會傳送作品資料或可識別您身分的資訊。所取得資訊的處理遵循 GitHub 的隱私權聲明（https://docs.github.com/site-policy/privacy-policies/github-privacy-statement）。\n\n【當機分析・使用狀況分析】\n本應用程式目前未內建以當機分析、使用狀況分析為目的之SDK。日後如導入此類服務，將更新本政策並於本應用程式內公告。';

  @override
  String get privacyPolicyArt4Title => '第4條（關於Cookie等追蹤技術）';

  @override
  String get privacyPolicyArt4Body =>
      '本應用程式本身不使用Cookie，惟第3條所述廣告投放服務（Google AdMob）可能基於廣告投放、成效衡量之目的，使用與之類似之識別技術（如廣告識別碼等）。';

  @override
  String get privacyPolicyArt5Title => '第5條（關於兒童個人資料）';

  @override
  String get privacyPolicyArt5Body =>
      '本應用程式並非以未滿13歲之兒童為主要對象而刻意蒐集資訊。建議家長於子女使用本應用程式時，視需要透過裝置設定停用個人化廣告等。';

  @override
  String get privacyPolicyArt6Title => '第6條（關於資訊之跨境傳輸）';

  @override
  String get privacyPolicyArt6Body =>
      '第3條所述第三方服務（Google AdMob、Google Play Billing）可能於Google公司在全球各地營運之伺服器上進行處理。相關處理適用各服務各自之隱私權政策。';

  @override
  String get privacyPolicyArt7Title => '第7條（作品廣場：社群發布功能中之資訊處理）';

  @override
  String get privacyPolicyArt7Body =>
      '1. 僅當使用者出於自身意願使用「作品廣場」功能（使用者條款第12條）時，本應用程式才會於開發者之伺服器上管理下列資訊。\n・用以識別及顯示已發布作品之資訊（YouTube 影片 ID、標題、統計資訊、發布時間、標籤等）\n・使用發布、檢舉、封鎖、追蹤、收藏等功能時所核發之 NIARIM User ID（與 Google 帳戶分開、於本應用程式內部核發之識別碼）\n・已連結 YouTube 頻道之公開資訊（頻道名稱、頻道圖示之圖片 URL）。為顯示發布者名稱與圖示，將複製並保存於開發者之伺服器\n・使用檢舉功能時之檢舉內容以及檢舉者之 NIARIM User ID\n・所封鎖對象之 NIARIM User ID\n・所追蹤對象之 NIARIM User ID，以及追蹤數與粉絲數\n・已收藏作品之 ID 及收藏時間\n・已轉發作品之 ID 及轉發時間\n・作品上之標籤（參見第4項）\n・啟用推播通知時之裝置權杖（裝置為確定通知送達對象所核發之識別碼，僅用於傳送通知）\n2. 已發布之影片檔案本身保存於 YouTube 上，不保存於開發者之伺服器。\n3. 前二項所述資訊僅於提供本社群功能所需之範圍內使用（作品清單顯示、排行、搜尋、檢舉處理、發布上限管理、追蹤・收藏・轉發之反映、通知傳送等）。開發者不會為廣告投放之目的向第三方提供此等資訊。\n4. 標籤亦得由發布者以外之使用者新增或刪除（發布者得鎖定自身作品之標籤以禁止編輯）。標籤於作品廣場上公開，且不顯示係由何人新增。\n5. 下列資訊預設為不公開，僅當使用者於本應用程式內切換為公開設定時，方會向其他使用者顯示。\n・已收藏作品之清單\n・追蹤中／粉絲清單\n其中，追蹤數與粉絲數（人數）不論公開設定為何均始終顯示。\n6. 將已發布作品設為不公開或予以刪除後，該作品將不再顯示於作品廣場之清單與排行中。如欲刪除開發者伺服器上之紀錄，請透過第9條之聯絡方式與我們聯繫。\n7. 未使用本社群功能時，不會發生本條所述之資訊處理。（依第2條之原則，不會向開發者之伺服器傳送任何內容。）';

  @override
  String get privacyPolicyArt8Title => '第8條（本政策之變更）';

  @override
  String get privacyPolicyArt8Body =>
      '因法令修正、本應用程式內容變更或其他開發者認有必要之情形，開發者得變更本政策。變更本政策時，開發者將事先透過本應用程式內或其他適當方式，公告變更內容及生效日期。';

  @override
  String get privacyPolicyArt9Title => '第9條（聯絡方式）';

  @override
  String get privacyPolicyArt9Body =>
      '有關本政策之相關詢問，請透過下列聯絡方式與我們聯繫。\n（開發者聯絡方式：尚未設定 —— 請於公開前填寫電子郵件地址等聯絡資訊）';

  @override
  String get privacyPolicyAdConsentButton => '變更廣告同意設定';

  @override
  String get tipsPcDexLayoutTitle => '寬螢幕環境會自動切換為PC模式（DeX）的專業版面';

  @override
  String get tipsPcDexLayoutDesc =>
      '在Chromebook、外接鍵盤的平板、三星DeX等寬螢幕環境下使用時，應用程式會自動切換為停靠面板式的專業版面。也可以在工作區設定中手動固定為永遠PC模式或永遠手機模式，連接外接螢幕工作時同樣好用。';

  @override
  String get workspaceTimelineSection => '時間軸顯示';

  @override
  String get workspaceTimelineHint =>
      '可將影片、音源軌道每行的高度分5個等級調整。用兩指捏合手勢也能暫時放大或縮小時間軸上的畫格寬度。';

  @override
  String get workspaceTimelineTrackHeightLabel => '軌道高度';

  @override
  String get workspaceTimelinePreviewLabel => '預覽';

  @override
  String get workspaceEndCardSection => '片尾卡';

  @override
  String get workspaceEndCardHint =>
      '片尾卡是應用程式自動顯示在每支影片結尾的自帶Logo，免費會員無法操作。僅限進階會員：開啟後，下次開啟時間軸時片尾卡會預設隱藏（已刪除）。進階會員資格到期後，此設定會自動恢復為關閉。';

  @override
  String get workspaceEndCardDefaultHiddenTitle => '預設隱藏片尾卡（僅限進階會員）';

  @override
  String get tipsTransparentColorTitle => '透明色不只是橡皮擦，可以像畫筆一樣使用';

  @override
  String get tipsTransparentColorDesc =>
      '選擇透明色後，可以用畫筆、套索、圖形等任意喜歡的工具直接擦除。既能利用畫筆的筆壓和平滑度精細地修圓輪廓，也能用漸層筆刷讓邊界柔和地漸變為透明，這些都是一般橡皮擦工具做不到的細膩表現。';

  @override
  String get tipsQuickToolVariantTitle => '快捷工具不僅能登記不同工具，也能登記不同筆刷、不同粗細';

  @override
  String get tipsQuickToolVariantDesc =>
      '快捷工具槽位不僅限於在鋼筆、橡皮擦等不同工具間切換，還可以將同一支鋼筆但不同筆刷、或同一個橡皮擦但不同粗細分別登記為獨立項目。只精選常用的組合排列好，就能減少每次都要重新開啟設定面板調整細節的麻煩。';

  @override
  String get tipsCommonLayerLipSyncTitle => '共用圖層不僅能用於背景，也能幫人物省容量';

  @override
  String get tipsCommonLayerLipSyncDesc =>
      '不只是背景，將人物圖層本身設為共用圖層也很有效。只把嘴部、眨眼的眼睛等每格都會變化的部分保留為一般圖層疊加，身體、頭髮等不動的部分設為共用圖層，即使是對嘴型或眨眼動畫，也能大幅削減容量。';

  @override
  String get tipsCommonLayerKeyframeTitle => '共用圖層與圖層關鍵影格同樣能節省容量';

  @override
  String get tipsCommonLayerKeyframeDesc =>
      '共用圖層可以透過圖層關鍵影格移動位置、縮放、旋轉。不必逐格重新繪製，只需將一張圖設為共用圖層並用關鍵影格讓它動起來，就能在不增加容量的前提下加入簡單的動作。';

  @override
  String get tipsTransferCustomizationTitle => '轉移功能讓你換裝置也能保持一貫的使用體驗';

  @override
  String get tipsTransferCustomizationDesc =>
      '轉移（.niatra）功能可以把筆刷、主題、工具列排列、調色盤等個人化設定一起轉移到其他裝置。無論是換機還是多裝置協同使用，都無需每次從頭重新設定。';

  @override
  String get tipsBlendModeUsageTitle => '依目的區分使用混合模式會更有效果';

  @override
  String get tipsBlendModeUsageDesc =>
      '想加陰影時用色彩增值，想增添光效或光澤時用濾色或線性加亮（增加），想讓陰影更有質感時用覆蓋或柔光較為合適。即使是同一種顏色，僅改變混合模式印象也會大不相同，建議先切換幾個候選項對比看看效果。';

  @override
  String get timelineSaveFailedDialogTitle => '儲存失敗';

  @override
  String get timelineSaveFailedDialogBody => '儲存失敗，請重試。';

  @override
  String get licenseSectionIcons => '關於所使用的圖示';

  @override
  String get layerPanelMergeAllVisibleTooltip => '合併所有可見圖層';

  @override
  String get canvasBrushSliderToggleLabel => '詳細';

  @override
  String get helpMeshTransformTitle => '自由變形・網格變形';

  @override
  String get helpMeshTransformDesc =>
      '從畫布右上角的編輯/設定選單開啟的、以整個圖層為對象的變形工具。與選取範圍變形不同，不需要選取範圍，可以用手指單獨拖曳角點或網格點做出自由的變形。控制面板的分割數滑桿最多可將網格細分為10×10，用兩根手指同時捏住不同的點，即可直覺地進行旋轉、縮放操作。';

  @override
  String get layerPanelBrightnessToAlphaLabel => '依明度透明化';

  @override
  String get layerPanelBrightnessToAlphaHint =>
      '越亮的部分會變得越透明。顏色維持不變但會變成半透明（不是白色背景直接消失，而是整張圖都變淡）。';

  @override
  String get layerPanelBrightnessToAlphaColorButton => '彩色';

  @override
  String get layerPanelBrightnessToAlphaGrayButton => '灰色';

  @override
  String get tipsRoughLayerRescueTitle => '不小心把線稿畫在草圖圖層上？用「依明度透明化」搶救';

  @override
  String get tipsRoughLayerRescueDesc =>
      '即使不小心把線稿畫在了草圖圖層上，也能在不刪除任何內容的情況下把線稿單獨取出來。①新增一個圖層，將其混合模式設為「除法」。②用滴管吸取草圖的顏色，將整個除法圖層填滿該顏色（草圖會變淡）。③複製該除法圖層，草圖會完全消失。④在圖層面板中使用「合併所有可見圖層」將其合併為一層。⑤在合併後圖層的三點選單中選擇「依明度透明化（灰色）」，白色部分就會變透明，只留下線稿。';

  @override
  String get filterNameMonochrome => '單色化濾鏡';

  @override
  String get timelineEffectTypeMonochrome => '單色化濾鏡';

  @override
  String get filterNameColorAdjust => '色調調整';

  @override
  String get filterColorAdjustSaturationLabel => '飽和度';

  @override
  String get filterColorAdjustBrightnessLabel => '明度';

  @override
  String get filterColorAdjustContrastLabel => '對比度';

  @override
  String get canvasColorAdjustTitle => '色調調整';

  @override
  String get canvasColorAdjustAddToDrawFilter => '新增至繪圖濾鏡';

  @override
  String get canvasColorAdjustAddToEffectFilter => '新增至演出濾鏡';

  @override
  String get canvasColorAdjustMenuTitle => '色調調整';

  @override
  String get canvasEditMenuReferenceWindow => '參考視窗';

  @override
  String get canvasEditMenuReferenceWindowSubtitle => '浮窗顯示參考圖片';

  @override
  String get referenceWindowTitle => '參考視窗';

  @override
  String get referenceWindowSelectImageButton => '選擇圖片';

  @override
  String get workspaceDockPanelSection => 'PC版預設開啟的面板';

  @override
  String get workspaceDockPanelHint =>
      '在PC/DeX模式下，選中的多個面板可以同時展開固定顯示（手機版為避免誤觸總是以全部隱藏開始）。';

  @override
  String get workspaceDockPanelBrush => '畫筆';

  @override
  String get workspaceDockPanelColorPicker => '取色器';

  @override
  String get workspaceDockPanelLayer => '圖層';

  @override
  String get workspaceDockPanelTone => '色調';

  @override
  String get workspaceDockPanelStamp => '貼紙';

  @override
  String get workspaceDockPanelPenSubTool => '筆子子工具';

  @override
  String get workspaceDockPanelOnionSkin => '洋葱紅';

  @override
  String get workspaceDockPanelRuler => '尺規';

  @override
  String get workspaceDockPanelFilter => '濾鏡';

  @override
  String get workspaceDockPanelQuickTool => '快捷工具';

  @override
  String get workspaceDockPanelColorAdjust => '色調調整';

  @override
  String get workspaceDockPanelCanvasPreview => '畫布預覽';

  @override
  String get workspacePcLayoutButton => 'PC版面設定';

  @override
  String get pcWorkspaceLayoutScreenTitle => 'PC版面設定';

  @override
  String get pcWorkspaceLayoutIntroHint =>
      '可調整以PC模式（橫向畫面＋連接滑鼠／繪圖板）開啟畫布畫面時，面板的排列順序與寬度。';

  @override
  String get pcWorkspaceLayoutToolOrderSection => '工具面板順序';

  @override
  String get pcWorkspaceLayoutToolOrderHint => '同時開啟畫筆、色調、印章等多個面板時的堆疊順序。';

  @override
  String get pcWorkspaceLayoutRightOrderSection => '圖層等面板順序';

  @override
  String get pcWorkspaceLayoutRightOrderHint => '顏色選擇器、圖層面板、畫布預覽的堆疊順序。';

  @override
  String get pcWorkspaceLayoutWidthSection => '面板寬度';

  @override
  String get pcWorkspaceLayoutToolWidthLabel => '工具面板側寬度';

  @override
  String get pcWorkspaceLayoutRightWidthLabel => '圖層面板側寬度';

  @override
  String get pcWorkspaceLayoutResetWidthButton => '將寬度重設為預設值';

  @override
  String get pcWorkspaceLayoutResetOrderButton => '將順序重設為預設值';

  @override
  String get canvasPreviewNavigatorTitle => '畫布預覽';

  @override
  String get canvasEditMenuPreviewNavigator => '畫布預覽';

  @override
  String get canvasEditMenuPreviewNavigatorSubtitle => '顯示縮小的整體概覽（導航器）';

  @override
  String get filterCustomMenuDuplicate => '複製';

  @override
  String get filterCustomMenuFavoriteBlockTitle => '無法刪除';

  @override
  String get filterCustomMenuFavoriteBlockBody =>
      '該濾鏡已收藏為常用，無法刪除。請先取消收藏，再進行刪除。';

  @override
  String get filterNameThreshold => '二值化濾鏡';

  @override
  String get filterMonochromeStrength => '單色化強度';

  @override
  String get filterMonochromeColorLabel => '單色化顏色';

  @override
  String get filterThresholdLabel => '閾值';

  @override
  String get filterNameFisheye => '魚眼鏡頭濾鏡';

  @override
  String get filterFisheyeStrength => '彎曲強度';

  @override
  String get filterNameChromaticAberration => '色差濾鏡';

  @override
  String get filterChromaticAberrationStrength => '偏移強度';

  @override
  String get filterNameLensDistortion => '眼鏡斷層濾鏡';

  @override
  String get filterLensDistortionStrength => '鏡片度數（負值為凹透鏡，正值為凸透鏡）';

  @override
  String get filterLensDistortionOffsetX => '中心位置微調（左右）';

  @override
  String get filterNamePixelate => '像素畫濾鏡';

  @override
  String get filterNameAuroraHologram => '極光全息';

  @override
  String get filterAuroraHologramStrength => '強度';

  @override
  String get filterAuroraHologramBrightness => '明度';

  @override
  String get filterAuroraHologramSaturation => '飽和度';

  @override
  String get filterAuroraHologramPresetAurora => '極光';

  @override
  String get filterAuroraHologramPresetSoapBubble => '肥皂泡';

  @override
  String get filterAuroraHologramPresetCyberNeon => '賽博霓虹';

  @override
  String get filterAuroraHologramPresetPastelDream => '粉彩夢境';

  @override
  String get filterAuroraHologramPresetSunsetGold => '日落金';

  @override
  String get filterAuroraHologramPresetSilverFoil => '銀箔';

  @override
  String get filterNameBackgroundBlend => '背景融入';

  @override
  String get filterBackgroundBlendColorLabel => '融入色';

  @override
  String get filterBackgroundBlendAutoLabel => '自動偵測中（點按可手動指定）';

  @override
  String get filterBackgroundBlendAutoReset => '恢復自動';

  @override
  String get filterBackgroundBlendDirection => '陰影與光（連動）的方向';

  @override
  String get filterBackgroundBlendLength => '陰影與光（連動）的長度';

  @override
  String get filterBackgroundBlendBlur => '模糊程度';

  @override
  String get filterPixelateBlockSize => '色塊大小';

  @override
  String get filterLensDistortionOffsetY => '中心位置微調（上下）';

  @override
  String get filterLensDistortionNoMaskHint =>
      '僅套用於在選取圖層上塗抹的範圍。請先在圖層清單中新增「選取圖層」，並塗抹想要變成鏡片的範圍（如眼鏡鏡片部分）。';

  @override
  String get tipsStockingDenierTitle => '絲襪・褲襪的網眼粗細會隨丹數變化';

  @override
  String get tipsStockingDenierDesc =>
      '新增的絲襪・褲襪色調依照丹數越低（布料越薄）網格間距越密的設定製作，其中最低的10丹刻意做得非常細密，依顯示或匯出解析度不同甚至可能出現摩爾紋。丹數越高的褲襪間距越寬、看起來更不透明，請依角色的腿部選用合適的一款。';

  @override
  String get tipsFisheyeChromaticTitle => '用魚眼鏡頭・色差濾鏡營造鏡頭般的變形與色邊';

  @override
  String get tipsFisheyeChromaticDesc =>
      '魚眼鏡頭濾鏡會讓畫面中心膨脹、邊緣壓縮，重現廣角・魚眼鏡頭拍攝般的彎曲效果。色差濾鏡會讓RGB色版略微錯開，重現廉價鏡頭拍攝時常見的彩色邊緣。兩者都可作為繪圖濾鏡（直接套用於圖層）與演出濾鏡（在時間軸上指定範圍套用）使用。';

  @override
  String get tipsLensDistortionTitle => '用選取圖層＋眼鏡斷層濾鏡重現度數鏡片的光學畸變';

  @override
  String get tipsLensDistortionDesc =>
      '在圖層清單中新增「選取圖層」，用一般繪圖工具塗抹眼鏡的鏡片部分，即可僅對該塗抹範圍套用眼鏡斷層濾鏡的局部畸變。度數滑桿在負值時呈凹透鏡（近視）般縮小，在正值時呈凸透鏡（遠視）般放大，中心位置也可微調。也可以同時塗抹兩片鏡片並一次套用效果。選取圖層本身不會出現在匯出結果或最終畫面中。除了眼鏡之外，也可以用來重現透過相機鏡頭看風景般的畸變效果，建議用選取圖層塗抹背景等較大範圍，並套用較弱的度數。';

  @override
  String get tipsLineArtExtractionTitle => '組合色調調整・二值化・明度轉透明來擷取線稿';

  @override
  String get tipsLineArtExtractionDesc =>
      '先用色調調整提高對比度，讓線條更突出，再用二值化濾鏡把影像分成純黑白兩色，線條就會與其餘部分清楚分離。二值化的閾值可以用滑桿自由調整，依喜好控制線條的粗細與虛實程度。最後，在圖層的三點選單中使用「明度轉透明（灰階）」，讓白色部分（線條以外）變成透明，就只剩下線稿了。想從照片或草稿中單獨擷取線稿時非常實用。';

  @override
  String get tipsLineColorUsageTitle => '依用途分開使用線稿顏色，成果會更好';

  @override
  String get tipsLineColorUsageDesc =>
      '部件的輪廓線使用顏色描邊·線稿融合後，不會與畫面離體，但邊界仍然清晰。陽影和高光使用與填色相同的指定色，可讓線稿本身不引人注目；而故意使用不同的指定色，則能營造出該作品独有的世界觀與統一感。';

  @override
  String get tipsBlushAutofillTitle => '臉頸的紅晖也能用自動填色柔和地上色';

  @override
  String get tipsBlushAutofillDesc =>
      '將線稿色設為透明的指定色，填色設為放射：中心→外側，並指定臉紅色與透明色這兩種顏色，就能在皮膩上只疊加臉頸的紅晖。調整紅晖的不透明度與顏色切換位置，可讓邊界更自然地融合。';

  @override
  String get autofillPartResetTraceButton => '恢復預設';

  @override
  String get premiumScreenTitle => 'Premium';

  @override
  String get premiumComparisonPremium => 'Premium';

  @override
  String premiumRegisteredDateLabel(String date) {
    return '註冊日期：$date';
  }

  @override
  String premiumNextRenewalDateLabel(String date) {
    return '下次續訂日期：$date';
  }

  @override
  String get workspaceApplyCurrentButton => '套用已設定的工作區';

  @override
  String get workspaceAppliedSnackbar => '已套用工作區設定。';

  @override
  String get workspaceSaveAsButton => '將工作區命名儲存・覆蓋儲存';

  @override
  String get workspaceShareButton => '共用工作區';

  @override
  String get workspaceShareSelectTitle => '選擇要共用的工作區';

  @override
  String workspaceShareFailedSnackbar(String error) {
    return '共用失敗：$error';
  }

  @override
  String get workspaceImportFromFileButton => '從外部檔案匯入';

  @override
  String workspaceImportFailedSnackbar(String error) {
    return '匯入失敗：$error';
  }

  @override
  String get workspaceNameRequiredError => '請輸入名稱。';

  @override
  String get workspaceNoSavedPresets => '目前沒有已儲存的工作區。';

  @override
  String get workspaceOverwriteSelectTitle => '選擇要覆蓋的工作區';

  @override
  String get workspaceOverwriteConfirmTitle => '確認覆蓋';

  @override
  String workspaceOverwriteConfirmBody(String name) {
    return '將用目前設定覆蓋「$name」，原有內容將被刪除。是否繼續？';
  }

  @override
  String get workspaceOverwriteButton => '覆蓋儲存';

  @override
  String get splashCommunityButtonTitle => 'NIARIM 作品廣場';

  @override
  String get splashCommunityButtonSubtitle => '瀏覽投稿作品';

  @override
  String get splashCreateButton => '製作動畫';

  @override
  String get communityScreenTitle => '作品廣場';

  @override
  String get communityTabNew => '最新';

  @override
  String get communityTabRanking => '排行榜';

  @override
  String get communityTabFavoriteAuthors => '追蹤';

  @override
  String get communitySearchHint => '依作品標題、投稿者名稱搜尋';

  @override
  String get communityEmptyState => '目前沒有作品';

  @override
  String communitySearchNoResults(String query) {
    return '找不到符合「$query」的作品';
  }

  @override
  String get communityTagSearchHint => '依標籤搜尋';

  @override
  String get communityTagSearchModeOnTooltip => '標籤搜尋：開啟（點一下可恢復標題・投稿者名稱搜尋）';

  @override
  String get communityTagSearchModeOffTooltip => '切換為標籤搜尋';

  @override
  String get communityAddTagButton => '新增標籤';

  @override
  String get communityAddTagDialogTitle => '新增標籤';

  @override
  String get communityAddTagDialogHint => '請輸入標籤名稱';

  @override
  String get communityTagLockTooltip => '鎖定此標籤（僅限投稿者）';

  @override
  String get communityTagUnlockTooltip => '解除此標籤鎖定（僅限投稿者）';

  @override
  String get communityRemoveTagTooltip => '刪除此標籤';

  @override
  String get communityPostButton => '發佈';

  @override
  String get communityPostComingSoonTitle => '發佈功能正在開發中';

  @override
  String get communityPostComingSoonBody => '影片發佈功能目前仍在開發中，敬請期待後續更新。';

  @override
  String get communityPostInfoTitle => '發佈將透過YouTube進行';

  @override
  String get communityPostInfoBody =>
      '投稿到作品廣場後，作品將透過YouTube公開。NIARIM不具備將作品本體（影片檔案）傳送、蒐集或保存到開發者伺服器的功能，發佈時需要在YouTube的畫面上傳影片。\n\n若在YouTube端將影片設定為「非公開條列」，該影片就不會出現在YouTube的公開清單中，僅會顯示於作品廣場內。\n\n（影片發佈功能目前仍在開發中，敬請期待後續更新。）';

  @override
  String get communityRankingPeriodAllTime => '累計';

  @override
  String get communityRankingPeriodYearly => '年度';

  @override
  String get communityRankingPeriodMonthly => '月度';

  @override
  String get communityRankingPeriodWeekly => '每週';

  @override
  String get communityRankingPeriodDaily => '每日';

  @override
  String get communityRankingSortViews => '觀看次數';

  @override
  String get communityRankingSortBookmarks => '收藏數';

  @override
  String get communityRankingSortAscendingTooltip => '遞增（由少到多）';

  @override
  String get communityRankingSortDescendingTooltip => '遞減（由多到少）';

  @override
  String communityWorkDetailPostedLabel(String date) {
    return '發佈於$date';
  }

  @override
  String get communityWorkDetailViewOnYoutube => '在YouTube上觀看';

  @override
  String get communityWorkDetailViewOnYoutubeComingSoonSnackbar =>
      'YouTube連動功能正在開發中';

  @override
  String get communityWorkDetailBookmarkAdd => '收藏';

  @override
  String get communityWorkDetailBookmarkRemove => '已收藏';

  @override
  String get communityWorkDetailReportButton => '檢舉';

  @override
  String get communityWorkDetailBlockButton => '封鎖';

  @override
  String get communityVisibilityCardTitle => '在作品廣場的公開狀態';

  @override
  String get communityVisibilityPublishedDesc => '公開中：顯示在新作、排行榜和該投稿者的作品清單中。';

  @override
  String get communityVisibilityHiddenDesc =>
      '非公開中：已從新作、排行榜和該投稿者的作品清單中隱藏（這是獨立於YouTube端公開設定的設定）。';

  @override
  String get communityVisibilityHiddenNotice => '投稿者已將此作品在作品廣場設為非公開。';

  @override
  String get communityVisibilityHiddenBadge => '非公開';

  @override
  String get communityWorkDetailTitle => '作品詳情';

  @override
  String get communityWorkNotFoundMessage => '找不到該作品';

  @override
  String get communityFloatingPreviewDetailButton => '詳情';

  @override
  String get communityFloatingPreviewPlayTooltip => '播放';

  @override
  String get communityFloatingPreviewPauseTooltip => '暫停';

  @override
  String get communityReportDialogTitle => '檢舉此作品';

  @override
  String get communityReportDialogBody => '請選擇檢舉原因。';

  @override
  String get communityReportReasonInappropriate => '內容不當';

  @override
  String get communityReportReasonCopyright => '疑似侵犯著作權';

  @override
  String get communityReportReasonSpam => '垃圾內容・重複發佈';

  @override
  String get communityReportReasonOther => '其他';

  @override
  String get communityReportSubmitButton => '提交檢舉';

  @override
  String get communityReportDetailLabel => '詳細說明';

  @override
  String get communityReportDetailHint => '請具體說明有什麼問題';

  @override
  String get communityReportDetailRequiredError => '請輸入詳細說明';

  @override
  String get communityReportComingSoonSnackbar => '檢舉功能正在開發中，實際上不會送出。';

  @override
  String communityBlockConfirmTitle(String name) {
    return '要封鎖「$name」嗎？';
  }

  @override
  String get communityBlockConfirmBody => '封鎖後，該作者的作品將不會出現在你的清單中。';

  @override
  String get communityBlockComingSoonSnackbar => '封鎖功能正在開發中，實際上不會生效。';

  @override
  String communityAuthorWorksCount(int count) {
    return '$count件作品';
  }

  @override
  String communityAuthorFollowerCount(int count) {
    return '$count位粉絲';
  }

  @override
  String get communityFollowersPublicToggleTitle => '公開追蹤中/粉絲清單';

  @override
  String get communityFollowersPublicToggleDesc =>
      '開啟後，其他使用者可以在此頁面看到你的追蹤中清單和粉絲清單。預設不公開。';

  @override
  String get communityFollowersListTitle => '粉絲';

  @override
  String get communityFollowersListEmpty => '尚無粉絲';

  @override
  String communityFollowersListHiddenNote(int count) {
    return '另有$count人因本人隱私設定未顯示';
  }

  @override
  String communityAuthorFollowingCount(int count) {
    return '追蹤中$count人';
  }

  @override
  String get communityFollowingListTitle => '追蹤中';

  @override
  String get communityFollowingListEmpty => '尚未追蹤任何人';

  @override
  String get communityFollowNotificationsTooltip => '通知';

  @override
  String get communityFollowNotificationsTitle => '追蹤通知';

  @override
  String get communityFollowNotificationsEmpty => '尚無通知';

  @override
  String communityFollowNotificationBody(String name) {
    return '$name追蹤了你';
  }

  @override
  String get communityNoWorksMessage => '尚無作品';

  @override
  String get communityFavoriteAuthorFollow => '追蹤';

  @override
  String get communityFavoriteAuthorFollowing => '追蹤中';

  @override
  String get communityFavoriteAuthorsEmptyTitle => '尚無追蹤的作者';

  @override
  String get communityFavoriteAuthorsEmptyBody =>
      '在喜歡的作者頁面點選「追蹤」，即可在此查看該作者的最新作品。';

  @override
  String get communityRepostButton => '轉發';

  @override
  String get communityRepostedButton => '已轉發';

  @override
  String communityRepostedByBadge(String name) {
    return '$name轉發了';
  }

  @override
  String get communityAuthorTabWorks => '作品';

  @override
  String get communityAuthorTabBookmarks => '收藏';

  @override
  String get communityBookmarksPublicToggleTitle => '公開收藏清單';

  @override
  String get communityBookmarksPublicToggleDesc =>
      '開啟後，其他使用者可以在此頁面看到你的收藏清單。預設不公開。';

  @override
  String get communityBookmarksPrivateNotice => '該使用者已將收藏清單設為不公開。';

  @override
  String get communityBookmarksEmptyMessage => '尚無收藏的作品';

  @override
  String get communityShortsBadge => '直向';

  @override
  String get communityVideoTypeFilterTooltip => '依影片類型篩選';

  @override
  String get communityVideoTypeFilterAll => '綜合';

  @override
  String get communityVideoTypeFilterShortOnly => '僅直向';

  @override
  String get communityVideoTypeFilterLongOnly => '僅橫向';

  @override
  String get communityShortsModeTooltip => '以直向模式觀看';

  @override
  String get communityShortsModeEmptySnackbar => '沒有直向影片';

  @override
  String get communityShortsModeExitTooltip => '結束直向模式';

  @override
  String get pixelColorModeLabel => '配色方式';

  @override
  String get pixelColorModeNone => '不限制顏色';

  @override
  String get pixelColorModePalette => '從調色盤選擇';

  @override
  String get pixelColorModeExplicit => '指定顏色';

  @override
  String get pixelColorModeCount => '指定顏色數';

  @override
  String pixelColorLevelsLabel(int count) {
    return '顏色數：$count';
  }

  @override
  String get pixelColorChipDeleteTooltip => '刪除此顏色';

  @override
  String get pixelColorChipAddButton => '新增顏色';

  @override
  String get pixelArtPaletteNameRequiredError => '請輸入調色盤名稱';

  @override
  String get pixelArtPaletteEditTitle => '編輯調色盤';

  @override
  String get pixelArtPaletteAddTitle => '新增調色盤';

  @override
  String get pixelArtPaletteNameLabel => '調色盤名稱';

  @override
  String get pixelArtPalettePickerTitle => '選擇調色盤';

  @override
  String get pixelArtPalettePickerEmpty => '尚無已儲存的調色盤，點擊「新增」建立一個。';

  @override
  String get pixelArtPalettePickerApplyButton => '套用';

  @override
  String get storageScreenTitle => '釋放空間';

  @override
  String get storageDeviceChartTitle => '裝置儲存空間';

  @override
  String get storageBreakdownChartTitle => 'NIARIM 明細';

  @override
  String get storageActionsTitle => '整理';

  @override
  String get storageCategoryNiarimTotal => 'NIARIM';

  @override
  String get storageCategoryOtherApps => '其他';

  @override
  String get storageCategoryFree => '剩餘空間';

  @override
  String get storageCategoryMaterials => '素材';

  @override
  String get storageCategoryProjectData => '專案資料';

  @override
  String get storageCategoryExports => '已匯出檔案';

  @override
  String get storageCategoryCustomAssets => '自製筆刷/網點/圖章/字型';

  @override
  String get storageCategoryCache => '快取';

  @override
  String get storageCategoryTrash => '垃圾桶';

  @override
  String get storageClearCacheButton => '清除快取';

  @override
  String get storageRemoveUnusedMaterialsButton => '批次刪除未使用素材（所有專案）';

  @override
  String get storageEmptyTrashButton => '清空垃圾桶';

  @override
  String get storageOrganizeProjectsButton => '整理專案';

  @override
  String get storageEraseAllButton => '刪除全部資料（初始化）';

  @override
  String storageClearCacheDoneSnackbar(String size) {
    return '已清除 $size 快取';
  }

  @override
  String get storageEraseAllConfirmTitle => '要刪除全部資料嗎？';

  @override
  String get storageEraseAllConfirmBody =>
      '這將永久刪除NIARIM的全部資料——專案、素材、已匯出檔案、自製筆刷/網點/圖章/字型及設定。此操作無法復原。刪除後請重新啟動應用程式。';

  @override
  String get storageEraseAllDoneSnackbar => '已刪除全部資料，請重新啟動應用程式。';

  @override
  String get homeDrawerStorage => '釋放空間';

  @override
  String get helpStorageTitle => '釋放空間';

  @override
  String get helpStorageDesc =>
      '以圓餅圖查看NIARIM在裝置上占用的容量，以及NIARIM內部（專案、素材、已匯出檔案、自製筆刷/網點/圖章/字型、快取、垃圾桶）的詳細佔比。可以清除快取、批次刪除所有專案中的未使用素材、清空垃圾桶、整理專案，或刪除全部資料（初始化）。';

  @override
  String get colorPickerImportPaletteTooltip => '匯入調色盤';

  @override
  String get colorPickerSharePaletteTooltip => '分享';

  @override
  String get colorPickerShareViaFile => '以檔案分享';

  @override
  String colorPickerShareFailedSnackbar(String error) {
    return '分享失敗：$error';
  }

  @override
  String get colorPickerShareViaQr => '以QR碼分享';

  @override
  String get qrShareTooLargeHint => '顏色過多，無法以QR碼分享（請使用檔案分享）';

  @override
  String get colorPickerImportViaFile => '從檔案選擇';

  @override
  String colorPickerImportFailedSnackbar(String error) {
    return '匯入失敗：$error';
  }

  @override
  String get colorPickerImportViaQr => '貼上QR碼文字';

  @override
  String get qrImportFailedError => '匯入失敗，請確認文字是否正確。';

  @override
  String get qrImportHint => '請用標準相機應用程式掃描對方裝置上顯示的QR碼，然後將複製的文字貼到這裡。';

  @override
  String get qrImportFieldHint => '貼上掃描到的文字';

  @override
  String get qrImportPasteButton => '從剪貼簿貼上';

  @override
  String get qrImportSubmitButton => '匯入';

  @override
  String get qrShareHint => '用標準相機應用程式掃描此QR碼即可複製文字。請在對方裝置上使用「匯入」貼上複製的文字。';

  @override
  String get qrShareCopiedSnackbar => '已複製文字';

  @override
  String get qrShareCopyButton => '複製文字';

  @override
  String get toolbarItemBlur => '高斯模糊';

  @override
  String get toolbarItemMosaic => '馬賽克';

  @override
  String get toolbarFingerSubtoolWarp => '彎曲';

  @override
  String get brushSettingsEdgeJitterTitle => '邊緣漸漫';

  @override
  String get brushSettingsEdgeJitterSubtitle => '輕微粗糙化邊緣，模擬墨水漸漫效果';

  @override
  String get brushSettingsEdgeJitterStrengthLabel => '漸漫強度';
}
