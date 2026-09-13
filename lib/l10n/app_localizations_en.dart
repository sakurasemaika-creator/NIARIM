// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get homeTabProjects => 'Projects';

  @override
  String get homeTabShared => 'Shared';

  @override
  String get homeTabTrash => 'Trash';

  @override
  String get homeTabWorks => 'Works';

  @override
  String get homeTabBookmarked => 'Bookmarked';

  @override
  String get homeBookmarkedComingSoonTitle => 'Coming soon';

  @override
  String get homeBookmarkedComingSoonBody =>
      'Once the \"Watch everyone\'s animations\" feature is available, works you\'ve bookmarked from other users will be listed here.';

  @override
  String get homeSearchHint => 'Search by project name';

  @override
  String get homeBackToSplashTooltip => 'Back to launch screen';

  @override
  String get homeFavoritesOnly => 'Favorites';

  @override
  String get homeAddSheetNewProject => 'New Project';

  @override
  String get homeAddSheetNewFolder => 'New Folder';

  @override
  String get homeSelectionAllSelect => 'Select All';

  @override
  String get homeSelectionAllDeselect => 'Deselect All';

  @override
  String get homeSelectionAddFavorite => 'Add to favorites';

  @override
  String get homeSelectionRemoveFavorite => 'Remove from favorites';

  @override
  String homeSelectionCount(int count) {
    return '$count selected';
  }

  @override
  String get homeMoveToTrash => 'Move to Trash';

  @override
  String homeMoveToTrashConfirm(int count) {
    return 'Move $count item(s) to trash?';
  }

  @override
  String get commonMove => 'Move';

  @override
  String get homeShareFileDialogTitle => 'Shared File';

  @override
  String get homeShareFileDialogContent =>
      'Duplicate this shared file and save it as a regular project?';

  @override
  String homeMissingFontsSnackbar(String names) {
    return 'Missing fonts: $names';
  }

  @override
  String get homeSharedImportedSnackbar => 'Added to the Projects tab';

  @override
  String homeSharedImportFailedSnackbar(String error) {
    return 'Failed to load the shared file: $error';
  }

  @override
  String get homeViewModeLarge => 'Large';

  @override
  String get homeViewModeMedium => 'Medium';

  @override
  String get homeViewModeSmall => 'Small';

  @override
  String get homeViewModeDetail => 'Detail';

  @override
  String get homeSortFieldName => 'Name';

  @override
  String get homeSortFieldUpdated => 'Updated';

  @override
  String get homeSortDirectionAscTooltip =>
      'Ascending (tap to switch to descending)';

  @override
  String get homeSortDirectionDescTooltip =>
      'Descending (tap to switch to ascending)';

  @override
  String get homeSharedEmpty => 'No shared projects';

  @override
  String homeProjectMeta(int fps, int duration) {
    return '${fps}fps · ${duration}s';
  }

  @override
  String get homeTrashEmpty => 'Trash is empty';

  @override
  String homeTrashDeletedOn(String date) {
    return 'Deleted $date';
  }

  @override
  String get homePermanentDelete => 'Delete Permanently';

  @override
  String get homePermanentDeleteConfirmTitle => 'Delete permanently?';

  @override
  String get homePermanentDeleteConfirmBody => 'This cannot be undone.';

  @override
  String get homeWorksEmpty => 'No exported works yet';

  @override
  String get homeWorksEmptyHint =>
      'Export a video or GIF from the canvas and it will appear here';

  @override
  String get homeShareOpenWith => 'Share / Open in Photos';

  @override
  String homeWorkDeleteConfirmTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get homeWorkDeleteConfirmBody =>
      'The exported file on this device will be deleted. This cannot be undone.';

  @override
  String get homePreviewFailed => 'Unable to play preview';

  @override
  String get homeFirstLaunchMessage => 'You can create hand-drawn animations';

  @override
  String get homeFirstLaunchStart => 'Get Started';

  @override
  String get settingsScreenTitle => 'Settings';

  @override
  String get settingsBasicTitle => 'Basic';

  @override
  String get settingsBasicSubtitle => 'FPS, background color, language';

  @override
  String get settingsBasicSheetTitle => 'Basic Settings';

  @override
  String get settingsDefaultFps => 'Default FPS';

  @override
  String get settingsDefaultFpsSubtitle => 'Initial value for new projects';

  @override
  String get settingsLanguage => 'Language';

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
  String get settingsSearchHint => 'Search settings...';

  @override
  String get settingsPerformanceTitle => 'Performance';

  @override
  String get settingsPerformanceSubtitle =>
      'Quality settings, undo history, trash, performance';

  @override
  String get settingsGestureTitle => 'Gestures';

  @override
  String get settingsGestureSubtitle => 'Two-finger tap, long press';

  @override
  String get settingsPenTitle => 'Pen Input';

  @override
  String get settingsPenSubtitle => 'Pressure, tilt, pen buttons';

  @override
  String get settingsWorkspaceTitle => 'Workspace';

  @override
  String get settingsWorkspaceSubtitle => 'Toolbar editing, panel layout';

  @override
  String get settingsBucketTitle => 'Bucket Fill';

  @override
  String get settingsBucketSubtitle => 'Tolerance, expand, fill under lines';

  @override
  String get settingsThemeTitle => 'Theme & Appearance';

  @override
  String get settingsThemeSubtitle => 'Theme colors, text and background';

  @override
  String get settingsWatermarkTitle => 'Watermark';

  @override
  String get settingsWatermarkSubtitle => 'Custom watermark';

  @override
  String get settingsTransferTitle => 'Transfer';

  @override
  String get settingsTransferSubtitle =>
      'Export/import settings, materials, and brushes to another device';

  @override
  String get settingsFontTitle => 'Font Management';

  @override
  String get settingsFontSubtitle => 'Add, search, and remove TTF/OTF fonts';

  @override
  String get settingsNoResults => 'No matching settings found';

  @override
  String get settingsTermsLicense => 'Terms & Licenses';

  @override
  String get settingsDrawingAreaTitle => 'Default Drawing Area';

  @override
  String get settingsDrawingAreaHint =>
      'Used as the initial value when creating a new project.';

  @override
  String get settingsDrawingAreaWiden => 'Widen drawing area';

  @override
  String get settingsDrawingAreaScale => 'Scale';

  @override
  String settingsScaleValue(String scale) {
    return '$scale×';
  }

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonCreate => 'Create';

  @override
  String get commonChange => 'Change';

  @override
  String get commonDelete => 'Delete';

  @override
  String get confirmDeleteGenericBody =>
      'Are you sure you want to delete this? This can\'t be undone.';

  @override
  String confirmDeleteNamedBody(String name) {
    return 'Delete \"$name\"? This can\'t be undone.';
  }

  @override
  String get commonFavoriteDeleteBlocked =>
      'Can\'t delete a favorited item. Remove it from favorites first.';

  @override
  String get commonSave => 'Save';

  @override
  String get commonRestore => 'Restore';

  @override
  String get commonClose => 'Close';

  @override
  String get commonRename => 'Rename';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonCut => 'Cut';

  @override
  String get commonPaste => 'Paste';

  @override
  String get commonDuplicate => 'Duplicate';

  @override
  String homePasteTooltip(int count) {
    return 'Paste $count item(s)';
  }

  @override
  String get homePasteSnackbar => 'Pasted';

  @override
  String get commonOk => 'OK';

  @override
  String get gestureSettingsTitle => 'Gesture Settings';

  @override
  String get gestureTwoFingerTap => 'Two-Finger Tap';

  @override
  String get gestureThreeFingerTap => 'Three-Finger Tap';

  @override
  String get gestureFourOrMoreFingerTap => 'Four-or-more-finger tap';

  @override
  String get gestureTwoFingerSwipe => 'Two-Finger Swipe Left/Right';

  @override
  String get gestureLongPress => 'Long Press';

  @override
  String get gestureHoldEyedropperSection => 'Hold to sample color';

  @override
  String get gestureHoldEyedropperTitle => 'Sample color on hold';

  @override
  String get gestureHoldEyedropperHint =>
      'While drawing with the pen or eraser, holding still for a moment picks up the color under your finger as the current color.';

  @override
  String get gestureHoldEyedropperDurationLabel => 'Hold duration';

  @override
  String gestureHoldEyedropperSecondsValue(String seconds) {
    return '${seconds}s';
  }

  @override
  String get gestureActionUndo => 'Undo';

  @override
  String get gestureActionRedo => 'Redo';

  @override
  String get gestureActionEyedropper => 'Eyedropper';

  @override
  String get gestureActionPanTool => 'Pan Tool';

  @override
  String get gestureActionEraserToggle => 'Toggle Eraser';

  @override
  String get gestureActionBrushToggle => 'Toggle Brush';

  @override
  String get gestureActionFrameMove => 'Move Frame';

  @override
  String get gestureActionNextTool => 'Quick Tool Switch';

  @override
  String get gestureActionOnionSkinToggle => 'Onion Skin On/Off';

  @override
  String get gestureActionNone => 'Do Nothing';

  @override
  String get homeDrawerAppTagline => 'Hand-drawn animation app';

  @override
  String get homeDrawerAutofillPreset => 'Autofill Settings';

  @override
  String get homeDrawerSettings => 'Settings';

  @override
  String get homeDrawerHelp => 'Help';

  @override
  String get homeDrawerTips => 'Tips';

  @override
  String get homeDrawerPremium => 'Premium';

  @override
  String get gestureActionNoneShort => 'None';

  @override
  String get pressureTryDrawHint =>
      'Try drawing with this setting (with a stylus, actual pressure is reflected)';

  @override
  String get pressureTryDrawClear => 'Clear';

  @override
  String get penSettingsTitle => 'Pen Input Settings';

  @override
  String get penSettingsPalmRejectionSection => 'Palm Rejection';

  @override
  String get penSettingsPalmRejectionTitle => 'Palm rejection';

  @override
  String get penSettingsPalmRejectionHint =>
      'Prevents accidental input from single-finger touches while using a stylus. Gestures with two or more fingers remain available.';

  @override
  String get penSettingsCurveSection => 'Pressure Curve';

  @override
  String get penSettingsCurveHint =>
      'A weaker setting ramps up gradually with pressure; a stronger setting ramps up sharply.';

  @override
  String get penSettingsCurveWeak => 'Weak';

  @override
  String get penSettingsCurveNormal => 'Normal';

  @override
  String get penSettingsCurveStrong => 'Strong';

  @override
  String get penSettingsCurveCustom => 'Custom';

  @override
  String get penSettingsCustomGraphHint =>
      'Tap an empty spot on the graph to add a point (up to 10), drag a point to move it, or double-tap a point to remove it (the start and end points can\'t be removed).';

  @override
  String get penSettingsResetCurveButton => 'Reset to default';

  @override
  String get penSettingsPerBrushNote =>
      '* The \"Apply to size/opacity\" pressure setting is per-brush (change it in the brush settings panel).';

  @override
  String get penSettingsButtonSection => 'Pen Button Settings';

  @override
  String get penSettingsButton1 => 'Button 1';

  @override
  String get penSettingsButton2 => 'Button 2';

  @override
  String get bucketSettingsTitle => 'Bucket Fill Settings';

  @override
  String get bucketSettingsToleranceSection => 'Tolerance';

  @override
  String get bucketSettingsToleranceHint =>
      'Adjusts how much color difference from the tapped pixel is still treated as the same area. Higher values let fills spread further across blurry color boundaries.';

  @override
  String get bucketSettingsExpandSection => 'Expand';

  @override
  String get bucketSettingsExpandHint =>
      'Expands the filled area outward by the given number of pixels, covering small gaps left near the line art.';

  @override
  String get bucketSettingsUnderLineTitle => 'Fill under lines';

  @override
  String get bucketSettingsUnderLineHint =>
      'Instead of painting over the line art directly, the expanded fill blends in behind existing pixels, keeping the line\'s appearance while closing gaps in its anti-aliased edges.';

  @override
  String get bucketSettingsUnderLineDisabledHint =>
      'Has no effect while \"Expand\" is 0px.';

  @override
  String fontCatalogSearchHint(int count) {
    return 'Search by font name... ($count fonts)';
  }

  @override
  String get fontCatalogAll => 'All';

  @override
  String get fontCatalogNoResults => 'No matching fonts found';

  @override
  String get rulerPanelTitle => 'Ruler';

  @override
  String get rulerTypeLine => 'Straight Ruler';

  @override
  String get rulerTypeEllipse => 'Ellipse Ruler';

  @override
  String get rulerTypeRadial => 'Radial Ruler';

  @override
  String get rulerTypeOnePoint => 'One-Point Perspective';

  @override
  String get rulerTypeTwoPoint => 'Two-Point Perspective';

  @override
  String get rulerTypeThreePoint => 'Three-Point Perspective';

  @override
  String get rulerDivisions => 'Divisions';

  @override
  String get transferScreenTitle => 'Transfer (.niatra)';

  @override
  String get transferInstructionHint =>
      'Select the items to transfer to another device.';

  @override
  String get transferItemSettings => 'Settings';

  @override
  String get transferItemMaterials => 'Materials';

  @override
  String get transferItemBrush => 'Brushes';

  @override
  String get transferItemPresets => 'Autofill Settings';

  @override
  String get transferItemTheme => 'Theme';

  @override
  String get transferItemPalette => 'Palettes (color picker & pixel art)';

  @override
  String get transferProjectsSectionTitle => 'Projects in progress (optional)';

  @override
  String get transferProjectsHint =>
      'Select only the projects you need to include in the transfer. Selected projects are transferred in full, including their materials and fonts.';

  @override
  String get transferProjectsEmpty => 'No projects yet.';

  @override
  String get transferImport => 'Import';

  @override
  String get transferExport => 'Export';

  @override
  String get transferExportSuccessSnackbar => 'Exported the .niatra file';

  @override
  String transferExportFailedSnackbar(String error) {
    return 'Export failed: $error';
  }

  @override
  String get transferImportSuccessSnackbar => 'Imported the .niatra file';

  @override
  String transferImportFailedSnackbar(String error) {
    return 'Import failed: $error';
  }

  @override
  String get folderManagementTitle => 'Folder Management';

  @override
  String get folderManagementCreateNew => 'New';

  @override
  String get folderManagementEmpty => 'No folders yet';

  @override
  String get folderNameLabel => 'Folder Name';

  @override
  String get folderMoveToTitle => 'Move to Folder';

  @override
  String get folderNone => 'No Folder';

  @override
  String get creativeAssetNameLabel => 'Name';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonSearch => 'Search';

  @override
  String get autofillPresetSelectionTitle => 'Autofill settings to use';

  @override
  String get autofillPresetSelectionHint =>
      'Choosing only the autofill settings used in this project keeps the part-assignment list shorter and easier to browse.';

  @override
  String autofillPresetSelectionPartCount(int count) {
    return '$count parts';
  }

  @override
  String get autofillPresetSelectionButton => 'Select autofill settings to use';

  @override
  String autofillPresetSelectionCountLabel(int count) {
    return '$count selected';
  }

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonFavoriteToggle => 'Toggle favorite';

  @override
  String get commonIncrease => 'Increase';

  @override
  String get commonDecrease => 'Decrease';

  @override
  String get commonPlay => 'Play';

  @override
  String get commonPause => 'Pause';

  @override
  String get fontCatalogDownloadTooltip => 'Download font';

  @override
  String get timelineBackToCanvasTooltip => 'Save and return to canvas';

  @override
  String get timelineBackToProjectListTooltip => 'Back to project list';

  @override
  String get timelineBackToProjectListDialogTitle => 'Back to project list';

  @override
  String get timelineBackToProjectListDialogBody =>
      'Save your changes before going back?';

  @override
  String get timelineBackToProjectListSaveButton => 'Save and go back';

  @override
  String get timelineBackToProjectListDiscardButton => 'Go back without saving';

  @override
  String get timelineSkipToStart => 'Skip to first frame';

  @override
  String get timelineStepBack => 'Step back one frame';

  @override
  String get timelineStepForward => 'Step forward one frame';

  @override
  String get timelineSkipToEnd => 'Skip to last frame';

  @override
  String get timelineLoopOnTooltip => 'Loop playback: ON (tap to turn off)';

  @override
  String get timelineLoopOffTooltip => 'Loop playback: OFF (tap to turn on)';

  @override
  String get quickToolPanelTitle => 'Quick Tool Settings';

  @override
  String get quickToolEmpty => 'No tools added yet';

  @override
  String get quickToolAddCurrentBrush => 'Add Current Brush';

  @override
  String get quickToolEraser => 'Eraser';

  @override
  String get quickToolEyedropper => 'Eyedropper';

  @override
  String get quickToolBucket => 'Bucket';

  @override
  String quickToolSizeDialogTitle(String brushName) {
    return '$brushName Size';
  }

  @override
  String get settingsShortcutTitle => 'Shortcuts';

  @override
  String get settingsShortcutSubtitle =>
      'Assign tools and actions to keyboard/left-hand devices';

  @override
  String get shortcutSettingsTitle => 'Shortcuts';

  @override
  String get shortcutSettingsHint =>
      'Assign keyboard or left-hand device keys to tools (down to a specific brush and size) or actions like Undo/Redo. Works in both Canvas and Timeline mode.';

  @override
  String get shortcutEmpty => 'No shortcuts registered';

  @override
  String get shortcutCaptureTitle => 'Press a key';

  @override
  String get shortcutCaptureHint =>
      'Press the key combination you want to assign (you can hold Ctrl/Shift/Alt etc. at the same time). Press Esc to cancel.';

  @override
  String shortcutChooseActionTitle(String combo) {
    return 'What should $combo do?';
  }

  @override
  String get shortcutActionTypeTool => 'Select a tool';

  @override
  String get shortcutActionTypeCommand => 'Main action';

  @override
  String get shortcutCommandUndo => 'Undo';

  @override
  String get shortcutCommandRedo => 'Redo';

  @override
  String get shortcutCommandToggleLayerPanel => 'Toggle layer panel (Canvas)';

  @override
  String get shortcutCommandPlayPause => 'Play/Pause (Timeline)';

  @override
  String get shortcutCommandPreviousFrame => 'Previous frame (Timeline)';

  @override
  String get shortcutCommandNextFrame => 'Next frame (Timeline)';

  @override
  String get shortcutCommandSelectAll => 'Select All';

  @override
  String get shortcutCommandCopy => 'Copy';

  @override
  String get shortcutCommandCut => 'Cut';

  @override
  String get shortcutCommandPaste => 'Paste';

  @override
  String get shortcutConflictTitle => 'Already assigned';

  @override
  String shortcutConflictBody(String combo, String existingLabel) {
    return '$combo is already assigned to \"$existingLabel\". Overwrite it?';
  }

  @override
  String get shortcutConflictOverwrite => 'Overwrite';

  @override
  String get materialListTitle => 'Materials';

  @override
  String materialRemoveUnused(int count) {
    return 'Remove Unused ($count)';
  }

  @override
  String get materialEmptyTitle => 'No materials';

  @override
  String get materialEmptyHint =>
      'Add images, videos, or audio from the timeline and they will appear here';

  @override
  String get materialUsedLabel => 'In use';

  @override
  String get materialUnusedLabel => 'Unused';

  @override
  String get materialMissingLabel => 'Missing';

  @override
  String get materialDeleteTooltipUsed => 'Cannot delete while in use';

  @override
  String get materialRemoveOneConfirmTitle => 'Delete this material?';

  @override
  String get materialRemoveUnusedConfirmTitle => 'Delete all unused materials?';

  @override
  String get materialRemoveUnusedConfirmBody =>
      'This will delete all materials not referenced anywhere in the project. This cannot be undone.';

  @override
  String materialRemovedSnackbar(int count) {
    return 'Removed $count unused material(s)';
  }

  @override
  String get watermarkEmptyTitle => 'No watermarks yet';

  @override
  String get watermarkEmptyHint =>
      'Tap the + button to add an image or text watermark';

  @override
  String get watermarkAddFromImage => 'Add from Image';

  @override
  String get watermarkAddText => 'Enter Text';

  @override
  String get watermarkAddedSnackbar => 'Watermark added';

  @override
  String get watermarkTextDialogTitle => 'Add Text Watermark';

  @override
  String get watermarkTextFieldLabel => 'Text to display';

  @override
  String get watermarkTextColorLabel => 'Text Color';

  @override
  String get watermarkTextColorTapHint => 'Tap to choose a color';

  @override
  String get watermarkDropShadowLabel => 'Drop shadow';

  @override
  String get watermarkShadowColorLabel => 'Shadow color';

  @override
  String get watermarkShadowOffsetXLabel => 'Shadow offset X';

  @override
  String get watermarkShadowOffsetYLabel => 'Shadow offset Y';

  @override
  String get watermarkShadowBlurLabel => 'Shadow blur';

  @override
  String get watermarkOutlineLabel => 'Outline';

  @override
  String get watermarkOutlineColorLabel => 'Outline color';

  @override
  String get watermarkOutlineWidthLabel => 'Outline width';

  @override
  String get premiumActiveLabel => 'Premium Active';

  @override
  String get premiumVsTitle => 'Free vs Premium';

  @override
  String get premiumHeroTitle => 'Unlock more freedom with Premium';

  @override
  String get premiumHeroSubtitle =>
      'No duration limit, no watermark, tone curve and level correction, and more — everything opens up.';

  @override
  String get premiumHeroHighlightDuration => 'Up to 2 hours';

  @override
  String get premiumHeroHighlightWatermark => 'No watermark';

  @override
  String get premiumHeroHighlightGrading => 'Tone curve /\nlevels';

  @override
  String get premiumCampaignFreeNote =>
      '* During the campaign, all Premium features above are free for everyone';

  @override
  String get premiumPlanSectionTitle => 'Plans';

  @override
  String get premiumStoreUnavailable =>
      'Unable to connect to the store (purchases are only available on a real device or store review environment)';

  @override
  String get premiumYearlyTitle => 'Yearly Plan (Recommended)';

  @override
  String get premiumYearlyDescription => 'Equivalent to 2 months free';

  @override
  String get premiumYearlyPrice => '¥5,500/year';

  @override
  String get premiumYearlyOriginalPrice => '¥6,600';

  @override
  String get premiumYearlyPerMonthLabel => 'Equivalent to ¥458/month';

  @override
  String get premiumMonthlyTitle => 'Monthly Plan';

  @override
  String get premiumRestorePurchases => 'Restore Purchases';

  @override
  String get premiumRestoredSnackbar =>
      'Restored your purchases (if any were found)';

  @override
  String get premiumCampaignBannerTitle =>
      'Launch Campaign! Premium features unlocked for everyone';

  @override
  String get premiumCampaignBannerBody =>
      'During the campaign, all Premium features (duration up to 2 hours, end-logo editing, watermark, tone curve, level correction) are free, even on the free plan.';

  @override
  String premiumCampaignEndLabel(String date) {
    return 'Until $date';
  }

  @override
  String get premiumComparisonFeature => 'Feature';

  @override
  String get premiumComparisonFree => 'Free';

  @override
  String get premiumFeatureDrawing => 'Drawing & Animation';

  @override
  String get premiumFeatureTimeline => 'Timeline';

  @override
  String get premiumFeatureExport => 'Video Export';

  @override
  String get premiumFeatureMaxDuration => 'Max Duration';

  @override
  String get premiumFeatureEndLogo => 'Official End Logo';

  @override
  String get premiumFeatureWatermark => 'Watermark';

  @override
  String get premiumFeatureToneCurve => 'Tone Curve';

  @override
  String get premiumFeatureLevelCorrection => 'Level Correction';

  @override
  String get premiumFeatureAds => 'Ads';

  @override
  String get premiumFeatureCommunityUpload => 'Work Plaza uploads per day';

  @override
  String get premiumValueYes => 'Yes';

  @override
  String get premiumValueNo => 'No';

  @override
  String get premiumValueRemovable => 'Removable';

  @override
  String get premiumValueDuration2Hours => '2 hours';

  @override
  String get premiumValueDuration90Sec => '1.5 min';

  @override
  String get premiumValueUploadFree => '1 work';

  @override
  String get premiumValueUploadPremium => '3 works';

  @override
  String get premiumPlanRecommendedBadge => 'Recommended';

  @override
  String get premiumMonthlyPrice => '¥550/month';

  @override
  String get toolbarItemPen => 'G-Pen';

  @override
  String get toolbarItemEraser => 'Eraser';

  @override
  String get toolbarItemBucket => 'Bucket';

  @override
  String get toolbarItemEyedropper => 'Eyedropper';

  @override
  String get toolbarItemFinger => 'Finger';

  @override
  String get toolbarItemPan => 'Hand';

  @override
  String get toolbarItemSelect => 'Select';

  @override
  String get toolbarItemText => 'Text';

  @override
  String get toolbarItemShape => 'Shape';

  @override
  String get workspaceScreenTitle => 'Workspace Settings';

  @override
  String get workspaceToolbarEditSection => 'Toolbar Editing';

  @override
  String get workspaceToolbarEditHint =>
      'Select which tools to show with the checkboxes, and drag to reorder them.';

  @override
  String get workspaceToolbarPcOnlyHint =>
      'Only shown in the toolbar in landscape orientation';

  @override
  String get workspaceToolbarPanDisabledHint =>
      'Not available in smartphone mode';

  @override
  String get workspaceResetToolbarDefault => 'Reset to Default';

  @override
  String get workspacePanelLayoutSection => 'Panel Layout';

  @override
  String get workspaceLeftHandedMode => 'Left-Handed Mode';

  @override
  String get workspaceLeftHandedSubtitlePc => 'Place panels on the right';

  @override
  String get workspaceLeftHandedSubtitleMobile =>
      'Only available in PC/DeX mode';

  @override
  String get workspacePcModeSection => 'PC Mode (DeX)';

  @override
  String get workspacePcModeHint =>
      'On wide screens the app switches automatically to the pro layout with panels docked in place. Set it manually here if you want to force it.';

  @override
  String get workspacePcModeAuto =>
      'Automatic (based on screen width, recommended)';

  @override
  String get workspacePcModeAlwaysPc => 'Always PC Mode';

  @override
  String get workspacePcModeAlwaysMobile => 'Always Mobile Mode';

  @override
  String get workspaceSaveSection => 'Save Workspace';

  @override
  String get workspaceSaveHint =>
      'Save your left-handed mode, PC mode, toolbar, and quick tool settings under a name so you can load them again later.';

  @override
  String get workspaceLoadButton => 'Load Workspace';

  @override
  String get workspaceEmptyToolbar => 'No tools to display';

  @override
  String get workspaceSaveDialogTitle => 'Save Workspace';

  @override
  String get workspaceSaveDialogLabel => 'Name (e.g. Animation, Line Art)';

  @override
  String get workspaceLoadRightHanded => 'Right-Handed';

  @override
  String get workspaceLoadLeftHanded => 'Left-Handed';

  @override
  String get helpScreenTitle => 'Help';

  @override
  String get helpSearchHint => 'Search...';

  @override
  String get helpNoResults => 'No matching items found';

  @override
  String get helpCategoryTool => 'Tools';

  @override
  String get helpCategoryLayer => 'Layers';

  @override
  String get helpCategoryAnimation => 'Animation';

  @override
  String get helpCategoryDrawing => 'Drawing';

  @override
  String get helpCategoryBrush => 'Brush';

  @override
  String get helpCategoryPenInput => 'Pen Input';

  @override
  String get helpCategorySave => 'Save';

  @override
  String get helpCategoryProjectManagement => 'Project Management';

  @override
  String get helpCategoryExport => 'Export';

  @override
  String get helpCategoryPremium => 'Premium';

  @override
  String get helpCategorySettings => 'Settings';

  @override
  String get helpCategoryCommunity => 'Community';

  @override
  String get helpPenToolTitle => 'Pen Tool';

  @override
  String get helpPenToolDesc =>
      'The basic tool for drawing lines on the canvas. Long-press to change the brush type, size, and color (double-tap shows a quick summary). It supports pressure and tilt from stylus/tablet devices, and adjusting the pressure curve under Settings > Pen Input lets you finely customize how pressure translates into size and opacity changes. Switching pen sub-tools lets you apply screentones or place stamps from the same pen tool.';

  @override
  String get helpEraserToolTitle => 'Eraser Tool';

  @override
  String get helpEraserToolDesc =>
      'The counterpart to the pen tool, used to erase what you\'ve drawn. Like a brush, you can adjust its size and opacity, and brush settings such as fade and stroke decay apply to it as well. Rather than \"adding\" to the transparent parts of a layer, it \"removes\" existing drawing, so the layer below becomes visible through it.';

  @override
  String get helpBucketToolTitle => 'Bucket Tool';

  @override
  String get helpBucketToolDesc =>
      'Fills an enclosed area all at once. Tap inside an area enclosed by line art and the whole area is filled with the selected color (or screentone). If there are gaps in the line art, the fill can spread into unintended areas, so it helps to make sure the line art is properly closed before using it. You can switch between flat fill and screentone fill in the settings. Detailed settings (tolerance, expand px, fill under lines) can be adjusted from the \"Bucket Fill\" section in Settings.';

  @override
  String get helpLassoFillTitle => 'Lasso Fill';

  @override
  String get helpLassoFillDesc =>
      'Trace with your finger to form a polygonal area, then fill the inside all at once. Unlike the bucket tool, you can define the area yourself even where the line art isn\'t closed, making it well suited for complex shapes or areas with gaps in the lines.';

  @override
  String get helpEyedropperToolTitle => 'Eyedropper Tool';

  @override
  String get helpEyedropperToolDesc =>
      'Picks up the color at the tapped position and sets it as the drawing color. It samples the composited look of all layers as actually displayed on screen, so it accurately picks up the \"color as seen\" even where multiple layers overlap.';

  @override
  String get helpSelectToolTitle => 'Select Tool';

  @override
  String get helpSelectToolDesc =>
      'Selects part of the canvas so you can move, rotate, or scale just that area. Long-press to choose from three selection methods: \"Rectangle Select,\" \"Lasso Select\" (freeform enclosure), or \"Auto Select\" (magic wand — automatically groups areas of similar color). While a selection is active, an outline marks the selected area on the canvas, and the same area stays fixed across all frames and layers until you deselect.';

  @override
  String get helpFingerToolTitle => 'Finger Tool (Warp Tool)';

  @override
  String get helpFingerToolDesc =>
      'Warps pixels by pushing them in the direction you drag your finger, like smearing wet paint with a finger. It\'s used less for fine corrections and more when you want to organically warp lines you\'ve already drawn to give them more expression.';

  @override
  String get helpShapeToolTitle => 'Shape Tool';

  @override
  String get helpShapeToolDesc =>
      'Draws precise shapes such as lines, rectangles, and circles with a single gesture. Dragging from the start point to the end point previews the shape live, and it\'s finalized when you lift your finger. Handy when you need straight lines or perfect circles that are hard to draw freehand.';

  @override
  String get helpTextToolTitle => 'Text Tool';

  @override
  String get helpTextToolDesc =>
      'Places text on the canvas. You can choose the font, size, color, and vertical/horizontal writing direction. Vertical writing supports automatic rotation of half-width alphanumerics, tate-chu-yoko (keeping numbers horizontal within vertical text), and ruby (furigana). Placed text is baked in as pixels when exported as well. A screen where you can add, search, and remove fonts available in the text tool. Additional free fonts beyond the bundled defaults are downloaded on demand from here, in order to keep the initial install size down.';

  @override
  String get helpQuickToolTitle => 'Quick Tool';

  @override
  String get helpQuickToolDesc =>
      'Register combinations of brushes and tools you use often, and cycle through them with a single button tap. Long-press or swipe up on the ↺ button on the canvas to open a management popup where you can add, reorder, and remove entries. Drag to change their order.';

  @override
  String get helpLayerTitle => 'Layers';

  @override
  String get helpLayerDesc =>
      'A system that lets you draw on a single canvas across multiple transparent “layers.” By drawing line art, coloring, and backgrounds on separate layers, you can redo just the coloring later or swap out the background without erasing the line art. Layers stacked higher appear in front on screen. Each layer row has one-tap buttons to delete it or merge it with the layer below, and a button at the top of the layer panel lets you merge all visible layers at once.';

  @override
  String get helpBlendModeTitle => 'Blend Mode';

  @override
  String get helpBlendModeDesc =>
      'Changes how a layer is composited with the layers below it. Often used when layering screentones or color effects.\nNormal: Layers as-is.\nMultiply: Darkens by multiplying with the layer below. The standard choice for shadows.\nScreen: Brightens by adding light. Good for glow effects.\nOverlay: Darkens dark areas and brightens light areas, increasing contrast.\nAddition: Simply adds colors together. Good for light streak effects.\nSubtract: Subtracts colors, producing a dark, sunken look.\nDarken: Keeps whichever color is darker between the two layers.\nLighten: Keeps whichever color is lighter between the two layers.\nColor Burn: Darkens and saturates the color below.\nColor Dodge: Brightens and saturates the color below.\nHard Light: A stronger version of Overlay contrast.\nSoft Light: A gentler version of Overlay contrast. Good for soft shading.\nDifference: Shows the difference between the two colors. Useful for checking color misalignment.\nHue / Saturation / Color / Luminosity: Applies only that one property (hue, saturation, color, or brightness) from this layer onto the one below.';

  @override
  String get helpClippingTitle => 'Clipping';

  @override
  String get helpClippingDesc =>
      'Restricts drawing to only the opaque pixels of the layer directly below. When you want to color without going outside the line art, enabling clipping on a coloring layer placed above a line art layer removes the risk of accidentally drawing outside the lines.';

  @override
  String get helpCommonLayerTitle => 'Common Layer';

  @override
  String get helpCommonLayerDesc =>
      'Ordinary layers are independent per frame, but a common layer shares the same content across multiple frames and scenes. Elements that don\'t move between frames, like backgrounds, can be drawn once instead of redrawn for every frame. It\'s shown as a dedicated track on the timeline. Converts a normal layer into a common layer (one that keeps showing the same content across multiple frames). You can also merge the currently visible layers into one before converting. Saves you redrawing something like a background that stays the same every frame.';

  @override
  String get helpAutoFillTitle => 'Auto Fill';

  @override
  String get helpAutoFillDesc =>
      'Creates an auto-fill layer beneath the auto-fill line art layer and automatically colors it based on a pre-made \"autofill setting\" (a combination of colors and screentones per part). Since you can color everything at once after finishing the line art, it greatly reduces coloring effort in hand-drawn animation where the same character is drawn repeatedly. If you redraw the line art, an update mark appears on the timeline and layer panel to let you know the auto-fill needs to be reapplied. Choosing \"Run autofill\" from the timeline screen’s three-dot menu recalculates every autofill layer flagged with the update mark at once. Saves you from running it one layer at a time in the layer panel after redrawing lineart. Each part in an autofill setting has a setting for how to handle the lineart color — a specified color, matching the fill color, or color tracing. Choosing color tracing shifts the lineart color’s HSL to match the fill color, so the line doesn’t stand out and blends in naturally. As settings pile up, the list shown when assigning parts gets long and harder to browse. From project settings (or the part-assignment dialog in the layer panel), you can narrow it down to only the settings used in this project, keeping the list tidy and easy to pick from.';

  @override
  String get helpOnionSkinTitle => 'Onion Skin';

  @override
  String get helpOnionSkinDesc =>
      'Overlays the frames before and after the one you\'re currently editing at partial transparency, so you can draw while checking how the motion connects. You can adjust how many frames are shown (before and after) and their color and opacity in the performance settings.';

  @override
  String get helpRulerTitle => 'Ruler';

  @override
  String get helpRulerDesc =>
      'A guide for drawing precise lines that are hard to achieve freehand, including straight, circle, ellipse, and perspective rulers (using vanishing points for perspective drawing). The pen tip automatically snaps to the placed ruler, making even compositions with challenging depth easier to draw than without a ruler. Rulers can be moved, rotated, and resized using their handles.';

  @override
  String get helpFadeTitle => 'Fade';

  @override
  String get helpFadeDesc =>
      'A brush setting where opacity and thickness gradually decrease as you draw a stroke further. Use it when you want the end of a line to trail off, or to create a drawing feel with a lingering effect.';

  @override
  String get helpStrokeDecayTitle => 'Stroke Decay';

  @override
  String get helpStrokeDecayDesc =>
      'Similar to fade, but closer to the effect of \"ink running out\" — the color fades or gets patchy the longer you keep drawing. It reproduces the texture of a brush or marker running dry as you keep using it.';

  @override
  String get helpColorMixingTitle => 'Color Mixing';

  @override
  String get helpColorMixingDesc =>
      'While painting with a brush, blends the color already under the brush with the color you\'re about to apply. Use it when you want new colors to blend into existing ones, like watercolor or oil paint.';

  @override
  String get helpPressureCurveTitle => 'Pressure Curve';

  @override
  String get helpPressureCurveDesc =>
      'A feature in the pen input settings that lets you freely adjust, via a graph, the relationship between actual pen pressure and how it affects brush size and opacity. Whether you want thick lines even with light pressure, or the opposite — needing firm pressure to get thick lines — you can finely customize the feel to match your habits. You can try drawing right there to check the effect after changing the settings.';

  @override
  String get helpTimelineTitle => 'Timeline';

  @override
  String get helpTimelineDesc =>
      'The screen for managing the time axis of your animation. Arranging frames (individual still images) and playing them back like a flipbook creates the animation. Image, video, and audio material tracks, common layer tracks, and camera keyframes are all managed on the same timeline.';

  @override
  String get helpSceneTitle => 'Scene';

  @override
  String get helpSceneDesc =>
      'Splits the inside of a single project (one video) into scenes (cuts) to manage them separately. While folders organize things at the project level, scenes represent scene changes within a single video. In the timeline’s scene tab you can add, duplicate, delete, rename, and reorder scenes. Switching to multi-select mode lets you move, duplicate, or delete multiple scenes at once.';

  @override
  String get helpCameraKeyframeTitle => 'Camera Keyframe';

  @override
  String get helpCameraKeyframeDesc =>
      'Records the camera\'s position, zoom level, and rotation at a specific point on the timeline. Since the values are automatically interpolated smoothly between keyframes, you can easily add camera work such as panning or zooming in/out.';

  @override
  String get helpEffectFilterTitle => 'Effect Filter';

  @override
  String get helpEffectFilterDesc =>
      'A visual effect (blur, color correction, glow, pixel art, etc.) you can apply to a scene or frame. Use it when you want to adjust the overall look of the screen as a directorial touch, without changing the hand-drawn artwork itself. Pixel art also lets you choose a color mode (no limit, specify colors, specify color count, or choose from a palette). Multiple effect filters can be stacked, and they\'re applied in the order they appear on the timeline. Dragging to reorder the filter list also changes the order they\'re actually applied on screen. An effect filter that applies film-grain-like noise, changing it frame by frame. Strength, amount (how dense the noise is), and grain size can all be adjusted with sliders. Returning to the same frame reproduces the same grain (no flicker while scrubbing), while playback makes the grain appear to move. An effect filter that renders rain falling across the screen. Intensity (drop count), speed, drop size, and wind angle can all be adjusted with sliders. Each drop keeps falling at a steady speed as the frame advances, giving natural-looking rain motion.';

  @override
  String get helpEndCardTitle => 'End Card (End Logo)';

  @override
  String get helpEndCardDesc =>
      'A short video (about 5 seconds) with the NIARIM logo, automatically added to the end of the main content when exporting a video. The free version cannot hide or remove it, but Premium members can turn it on/off, change its length, or replace it.';

  @override
  String get helpAutoSaveTitle => 'Auto Save';

  @override
  String get helpAutoSaveDesc =>
      'A save dedicated to recovery in case of a crash or file corruption. It saves automatically every time there\'s a change, such as drawing, and overwrites the oldest of up to 3 saves. It\'s managed completely separately from manual saves (save slots and the save tree) and is not a substitute for regular saving. You\'re only asked whether to restore it when relaunching the app after an abnormal exit.';

  @override
  String get helpSaveSlotTitle => 'Save Slot';

  @override
  String get helpSaveSlotDesc =>
      'A method of saving into a fixed number of save slots, where you choose which slot to save to each time. The number of slots is determined by the settings (5 for low quality, 10 for medium quality). Since you choose which slot to overwrite every time, it\'s an easy way to manage keeping a particular moment\'s state.';

  @override
  String get helpSaveTreeTitle => 'Save Tree';

  @override
  String get helpSaveTreeDesc =>
      'A save method where a new save point is created every time you save, and you can branch off from a past save point to create a different history. There\'s no limit on the number of saves, making it well suited for use cases like \"I want to go back to that version and try a different direction.\" On screen, save points are shown as a tree diagram growing from bottom to top.';

  @override
  String get helpFolderTitle => 'Folder';

  @override
  String get helpFolderDesc =>
      'A feature for grouping and organizing your projects (works). It supports multiple levels of nesting, so you can also use it to manage multiple episodes or a series of the same work together (for example, arranging projects for \"Episode 1,\" \"Episode 2,\" and so on inside a folder named after the work). If you want to divide a single video into separate scenes, use the \"Scene\" feature on the canvas screen instead of folders.';

  @override
  String get helpTrashTitle => 'Trash';

  @override
  String get helpTrashDesc =>
      'The place where deleted projects are temporarily moved. You can restore them from here until they\'re permanently deleted. You can set the number of days until automatic deletion (Off/30/60/90 days) in the settings.';

  @override
  String get helpShareTitle => 'Share (.niashare)';

  @override
  String get helpShareDesc =>
      'A dedicated file format for handing a project to someone else (or to another device of your own). When the recipient opens this file, it\'s duplicated and added to their own project list. The original .niashare file itself is not changed.';

  @override
  String get helpTransferTitle => 'Transfer (.niatra)';

  @override
  String get helpTransferDesc =>
      'A feature for transferring your entire app environment — settings, materials, brushes, autofill settings, theme, palettes (color picker and pixel-art), and more — to another device all at once. You can choose individual items to transfer with checkboxes, and optionally include in-progress projects too (selected projects are transferred whole, including their materials and fonts). If you just want to hand over a single project, you can also use \"Share (.niashare)\".';

  @override
  String get helpVideoExportTitle => 'Video Export (MP4, WebM, GIF, AVI)';

  @override
  String get helpVideoExportDesc =>
      'Exports your work as a standard MP4 video. The free version has a length limit (90 seconds) and automatically adds an end card (app logo) at the end of the video. A video format that can be exported while keeping the alpha channel (the transparent parts of the background). Transparent playback only works in compatible playback environments. Good for layering as material in other apps. Exports as an animated GIF. Since it loops automatically, it works well for casual sharing on social media. If compatibility matters most, you can also export as AVI (Motion JPEG). It uses a codec chosen to be safe on patents and licensing, but it doesn\'t support the alpha channel (transparency), and in-app preview may not work on every device (you can still play it in an external player via Share in that case). Free accounts are capped at a 90-second project length (Premium accounts get 2 hours). If adding or duplicating frames would push you past the limit, a warning dialog appears the moment you tap the button, so you never actually go over 90 seconds.';

  @override
  String get helpTransparentWebmTitle => 'Transparent WebM';

  @override
  String get helpCommunityTitle => 'Work Plaza';

  @override
  String get helpCommunityDesc =>
      'Post your animations and illustrations to the community as YouTube videos, and browse works by other users. Switch between the “New”, “Ranking”, and “Following” tabs, and search by work title or creator name. Switch to tag search mode to filter works by tag — anyone (not just the creator) can add or remove tags, though a tag the creator has locked can only be removed by the creator, and tapping a tag instantly filters to matching works. Tapping a work card opens a draggable, resizable floating preview window, so you can keep browsing other screens while it plays. The “View Details” button opens the work\'s detail screen (creator, post date, tag editing, bookmarking, reposting, and more). Tap the “Follow” button next to a creator\'s name to follow them — the “Following” tab then gathers just that creator\'s posts in chronological order. When someone follows you, it shows up in the notification list under the bell icon at the top of the screen. You can choose whether your own following/followers lists are visible to other users (private by default), and view other users\' lists if they\'ve made theirs public. You can repost anyone else\'s work (except your own) with the “Repost” button; when a creator you follow reposts someone else\'s work, that work also appears in your “Following” tab, sorted by whichever is more recent — its original post date or its repost date (the card shows “Reposted by …”). Bookmarked works appear together under the “Bookmarked” tab on the Home screen, and also under the “Bookmarks” tab on a creator\'s work list screen. You can choose whether your own bookmark list is visible to other users (private by default), and you can view other users\' bookmark lists if they\'ve made theirs public. You can report a work with a reason, and after submitting you\'ll be asked whether to block that creator. Portrait videos can be watched in “Portrait mode”, which plays them back-to-back like a short-form video feed. There is a daily limit on how many works you can post: 1 per day for free members, 3 per day for Premium members.';

  @override
  String get helpWatermarkEntryTitle => 'Watermark';

  @override
  String get helpWatermarkEntryDesc =>
      'A premium-only feature that lets you add your own signature or logo as a watermark on exported videos and images. You can adjust its position, size, and opacity. Tap the watermark placed on the common-layer track in the timeline to re-edit its angle, size, opacity, and visible range (looping) at any time — not just when you first register it, but whenever you use it in a project.';

  @override
  String get helpPremiumEntryTitle => 'Premium';

  @override
  String get helpPremiumEntryDesc =>
      'Premium membership extends the 90-second video length limit of the free version up to 2 hours and lets you remove the end card (app logo) automatically added at the end of every video. Ads are also hidden, and you gain access to the watermark, tone curve, and level correction features.';

  @override
  String get helpPerformanceSettingsTitle => 'Performance Settings';

  @override
  String get helpPerformanceSettingsDesc =>
      'Choose from low, medium, or high quality presets based on your device\'s capability, or configure each item individually (custom). In addition to save method, performance, onion skin, and tilt detection, settings that affect app size and how heavy it runs — such as undo history length and automatic trash deletion — are also gathered here.';

  @override
  String get helpMaterialClipTitle => 'Material clips (image / video / audio)';

  @override
  String get helpMaterialClipDesc =>
      'Clips placed on the timeline\'s image, video, and audio tracks. Long-press-drag a clip\'s body to move its start position, or drag the handles at either end to change how much of it is used. Tap a clip to open its detail sheet, where the copy icon duplicates it and the trash icon deletes it. Image and video clips are internally handled as layers, while audio clips are managed as clips attached directly to the scene.';

  @override
  String get helpGestureSettingsTitle => 'Gesture settings';

  @override
  String get helpGestureSettingsDesc =>
      'Lets you assign actions — undo/redo, frame move, eyedropper, and more — to a two-finger tap, three-finger tap, two-finger swipe, or long press. Pen buttons (on supported styluses) can also be assigned separately. Handy for triggering frequent actions with one touch instead of switching tools.';

  @override
  String get helpBucketDetailSettingsTitle => 'Bucket fill detail settings';

  @override
  String get helpBucketDetailSettingsDesc =>
      'From the \"Bucket Fill\" section in settings, you can adjust tolerance (how much color difference from the clicked pixel still counts as the same region), expand px (how far the filled area extends past the boundary to cover gaps in the lineart), and fill under line (composites the expanded fill behind existing pixels instead of painting over the lineart, keeping the line\'s look intact). Adjusting these helps when the lineart has small gaps or fills feel incomplete.';

  @override
  String get helpStampToolTitle => 'Stamp tool';

  @override
  String get helpStampToolDesc =>
      'Places a pre-registered image onto the canvas like a brush. Reuse speed lines, background patterns, and small props without redrawing them each time. With pixel mode on, stamped images are processed with mosaic downsampling plus color reduction for a pixel-art look. The stamp panel lets you adjust the rotation angle and size of the stamp you\'re placing. Varying the direction and size of the same stamp keeps speed lines and small props from looking monotonous.';

  @override
  String get helpToneFillTitle => 'Screentone fill';

  @override
  String get helpToneFillDesc =>
      'Switching the bucket tool\'s setting from solid fill to screentone fill lets you fill with a chosen halftone or line-pattern screentone. Pixel-mode-only checker and grid patterns are also available, for fills that fit a pixel-art texture. Great for frills, knitwear, tights, and other fine patterns that are tedious to draw by hand. You can also create and add your own custom screentones, or share them with other users.';

  @override
  String get helpPixelModeTitle => 'Pixel mode';

  @override
  String get helpPixelModeDesc =>
      'A setting available on brushes, fonts, and stamps individually. Turning it on strips anti-aliasing for crisp, pixel-art-style edges. Use it when you want a deliberately old-game feel or a low-resolution look. You can choose from four color modes — no color limit, specify colors, specify color count, or choose from a palette — including a dedicated pixel-art palette.';

  @override
  String get helpHomeScreenTitle => 'Home screen';

  @override
  String get helpHomeScreenDesc =>
      'The first screen shown when you launch the app, with Projects, Shared, Works, and Trash tabs. The search icon at the top right lets you filter projects by name. On the Projects tab, the + button in the bottom right lets you choose between creating a new project or a new folder.';

  @override
  String get helpNewProjectTitle => 'New project';

  @override
  String get helpNewProjectDesc =>
      'Set canvas size, fps, duration (in seconds — later kept in sync with frame changes made in the timeline), drawing area (lets you draw beyond the export bounds), and which autofill settings to use, all before creating the project.';

  @override
  String get helpThemeSettingsTitle => 'Theme settings';

  @override
  String get helpThemeSettingsDesc =>
      'Choose the app\'s overall color scheme from the theme list, or freely customize the accent color. Headings/labels and body text use separate fonts, so you can enjoy re-skinning the app while keeping it readable.';

  @override
  String get helpWorkspaceSettingsTitle => 'Workspace settings';

  @override
  String get helpWorkspaceSettingsDesc =>
      'Gathers settings such as left-handed mode (mirrors the docked panels), manually switching PC/DeX mode, and when the pan tool is shown. Adjust the layout to suit your device and dominant hand.';

  @override
  String get helpPenSettingsTitle => 'Pen settings';

  @override
  String get helpPenSettingsDesc =>
      'Along with the pressure curve for tablets and pen displays, this screen lets you assign actions — such as toggling the eraser or the eyedropper — to the side buttons of a supported stylus.';

  @override
  String get helpMaterialListTitle => 'Materials list';

  @override
  String get helpMaterialListDesc =>
      'A screen that gathers the image, video, and audio materials used in a project. It collects the source files for anything placed on the timeline.';

  @override
  String get helpFrameOperationsTitle => 'Frame operations';

  @override
  String get helpFrameOperationsDesc =>
      'In the frame list, you can add, duplicate, and delete frames, and in multi-select mode move, duplicate, or delete several frames at once. Increasing the hold count keeps a single frame displayed across several cells (a \"hold\"), saving you drawing time on cuts with little motion.';

  @override
  String get helpSceneOperationsTitle => 'Scene operations';

  @override
  String get helpSceneOperationsDesc =>
      'The timeline\'s scene tab lets you add, duplicate, delete, rename, and reorder scenes. Multi-select mode lets you move, duplicate, or delete several scenes at once.';

  @override
  String get helpQuickToolManagementTitle => 'Quick tool management';

  @override
  String get helpQuickToolManagementDesc =>
      'Register a set of frequently used tools to cycle through with a single tap. Open the management popup with a long press or an upward swipe to edit the registered tools and their order.';

  @override
  String get helpTransformSelectionTitle => 'Transforming a selection';

  @override
  String get helpTransformSelectionDesc =>
      'A region enclosed with the select tool can be transformed by picking Move, Scale, or Rotate from the buttons at the bottom left of the canvas and then dragging inside the selection. Handy for repositioning a mistakenly drawn part, or enlarging just one area to emphasize it. Tapping Select All on the same bar selects the entire current layer, so you can move, rotate, and scale a whole layer the same way (the separate Transform tool has been merged into this). To warp more freely by dragging individual grid points, use Free transform or Mesh warp on the same bar.';

  @override
  String get helpGradientAutofillTitle => 'Gradient fill (autofill settings)';

  @override
  String get helpGradientAutofillDesc =>
      'Each part in an autofill setting can use a gradient instead of a solid color. Symmetric handles you can drag let you intuitively adjust the gradient’s extent and angle. Each part can also enable \"Outline with specified color\". When checked, a line of the chosen color and width is drawn around the very outer edge of the filled area (right up against the lineart). The outline color can be freely chosen from the color picker, and the width can be adjusted via the slider, the ± buttons, or by tapping the number to type it directly. A preview appears just above the settings, so you can check the color and width before actually running autofill.';

  @override
  String get helpColorPickerTitle => 'Color picker';

  @override
  String get helpColorPickerDesc =>
      'A color picker that lets you switch between HSV and RGB on one screen. The palette feature lets you save and recall the color set you are using. Palettes can also be shared with other devices via file export or QR code.';

  @override
  String get helpUndoSettingsTitle => 'Undo history length';

  @override
  String get helpUndoSettingsDesc =>
      'In performance settings, you can adjust how many actions undo can step back through. A larger number gives you more freedom to experiment, but also uses more memory — lower it on low-spec devices to keep things running smoothly.';

  @override
  String get helpBrushFavoriteTitle => 'Favorite brushes';

  @override
  String get helpBrushFavoriteDesc =>
      'Tap the star icon on a brush in the brush list to favorite or unfavorite it (the same interaction used for favorites throughout the app — autofill settings, stamps, fonts, draw filters, and more). The star icon at the top of the list also lets you filter down to favorites only. Favorited brushes can’t be deleted by accident.';

  @override
  String get helpCustomBrushTitle => 'Custom Brushes';

  @override
  String get helpCustomBrushDesc =>
      'Long-press a pre-installed brush in the brush list and choose “Duplicate” to create your own custom brush based on it. Duplicated brushes can be freely edited — thickness, opacity, hardness, rotation, density, scatter, blur radius, and more — and deleted once you no longer need them (the pre-installed brushes themselves can’t be edited or deleted). You can also sort them into folders and mark favorites with the star icon.';

  @override
  String get helpLayerFolderTitle => 'Layer folders';

  @override
  String get helpLayerFolderDesc =>
      'Lets you organize several layers into a folder. Keeps the layer panel manageable even in illustrations with many parts. Clipping can\'t cross folder boundaries, so if you use clipping, keep the relevant layers in the same folder.';

  @override
  String get helpLayerMultiSelectTitle =>
      'Multi-selecting and bulk layer actions';

  @override
  String get helpLayerMultiSelectDesc =>
      'Selection mode in the layer panel lets you check off several layers at once to merge or bulk-delete them. Merging only works between normal, autofill-lineart, and autofill layers (common layers, folders, and timeline materials can\'t be merged).';

  @override
  String get helpDrawingAreaTitle => 'Drawing area';

  @override
  String get helpDrawingAreaDesc =>
      'Lets you draw beyond the export bounds. A red frame on the canvas marks the export area — anything drawn outside it isn\'t exported, but it leaves room to adjust what\'s shown later with camera moves like panning and zooming. Set the scale when creating a new project.';

  @override
  String get helpCanvasBackgroundTitle => 'Canvas background color';

  @override
  String get helpCanvasBackgroundDesc =>
      'Lets you set the project\'s canvas background color. It has no effect on transparent exports (transparent WebM), but you can change it to whatever\'s easiest to work against.';

  @override
  String get helpProjectDetailTitle => 'Project details screen';

  @override
  String get helpProjectDetailDesc =>
      'A screen for checking and editing per-project settings all in one place — name, thumbnail, favorite status, and which autofill settings are enabled. The entry point to the save tree is also here.';

  @override
  String get helpWatermarkEditTitle => 'Re-editing a watermark';

  @override
  String get helpWatermarkEditDesc =>
      'Tapping a watermark placed on the timeline\'s common-layer track lets you re-edit its angle, size, opacity, and display range (loop) at any time. You can fine-tune it not just when registering it, but whenever you\'re actually using it in a project.';

  @override
  String get helpAudioClipTitle => 'Audio clip volume and fades';

  @override
  String get helpAudioClipDesc =>
      'An audio clip placed on the timeline can have its volume, fade-in, and fade-out durations adjusted from its detail sheet. Use it to balance sound effect and BGM volume, or smooth out a track\'s start and end.';

  @override
  String get helpPenSubToolTitle => 'Pen sub-tools';

  @override
  String get helpPenSubToolDesc =>
      'Long-pressing the pen tool switches it from regular drawing to the screentone-fill or stamp-placement sub-tools. Lets you move between several tasks from the same pen without constantly switching tools.';

  @override
  String get helpTiltDetectionTitle => 'Tilt detection';

  @override
  String get helpTiltDetectionDesc =>
      'A setting that uses tilt data from a supported stylus to thicken or thin the line as you lay the pen tip down, recreating a feel closer to a real drawing tool. Toggle it on/off from performance settings.';

  @override
  String get helpFontImportTitle => 'Font import';

  @override
  String get helpFontImportDesc =>
      'Lets you load a font file straight from your device\'s storage. Add it from the \"Import\" tab in font management, in settings. Handy when you want to use a custom-made font that isn\'t distributed anywhere, or a commercial font you\'ve purchased.';

  @override
  String get helpExportScreenTitle => 'Export screen';

  @override
  String get helpExportScreenDesc =>
      'Shows progress while exporting a video or image, and lets you cancel partway through. How long it takes depends on your device\'s performance.';

  @override
  String get helpDrawingFilterTitle => 'Draw filters';

  @override
  String get helpDrawingFilterDesc =>
      'Filters applied directly to the selected layer (as opposed to effect filters, which apply across the whole timeline or a scene, draw filters work per layer). Includes blur, sharpen, unsharp mask, tone curve, levels, vignette, noise, retro anime, CRT, anime style, outline, pixel art, and a lens-distortion filter. Outline doesn\'t rewrite the original layer — it draws just the outlined result onto a new layer. The lens-distortion filter applies a localized warp, like looking through a strong eyeglass lens, only to the area painted on the selection layer. Pixel art also lets you choose a color mode (no limit, specify colors, specify color count, or choose from a palette).';

  @override
  String get helpLayerKeyframeTitle => 'Layer keyframes (per-part animation)';

  @override
  String get helpLayerKeyframeDesc =>
      'Set each layer\'s position, scale, and rotation per frame, with the keyframes interpolated automatically. Where camera keyframes move the whole screen, this moves an individual layer only. Since each autofill part is generated as its own separate layer, this works directly for per-part animation — moving just an arm, opening and closing just a mouth, and so on. Each keyframe can also be given its own easing — Linear, Ease in, Ease out, Ease in and out, or Bounce — controlling how it transitions into the next keyframe, so motion doesn\'t have to stay at a flat, constant speed. Set it up from the \"Animation (keyframes)\" entry in each layer\'s three-dot menu in the layer panel. The layer\'s artwork itself doesn\'t change — it\'s a non-destructive transform of where it\'s displayed. This only affects the timeline\'s display (preview / export) and has no effect on actual drawing in canvas mode.';

  @override
  String get helpLayerGroupTitle =>
      'Layer groups (moving multiple parts together)';

  @override
  String get helpLayerGroupDesc =>
      'Moves several layers together with a single keyframe stream. For example, if an \"arm\" is made up of two autofill parts — skin and sleeve — grouping them lets you move both with one keyframe operation. Create a group by multi-selecting layers (checkboxes) in the layer panel and tapping the \"Group\" icon in the bottom bar. A group\'s motion is layered on top of each member layer\'s own keyframes (if set), so you can combine the group\'s overall movement with per-layer fine adjustments. A layer can belong to only one group at a time.';

  @override
  String get tipsScreenTitle => 'Tips';

  @override
  String get tipsSearchHint => 'Search tips...';

  @override
  String get tipsCategoryVideo => 'Video-making tips';

  @override
  String get tipsCategoryEfficiency => 'Tips to work faster';

  @override
  String get tipsCategoryDrawing => 'Tips for smoother drawing';

  @override
  String get tipsCategoryEffects => 'Tips for styling and polish';

  @override
  String get tipsCategoryExport => 'Export & workflow tips';

  @override
  String get tipsClipDuplicateTitle =>
      'Timeline clips can be duplicated, moved, and deleted';

  @override
  String get tipsClipDuplicateDesc =>
      'Tap an image, video, or audio clip to open its detail sheet, then use the copy icon to duplicate it. Reusing the same sound effect or repositioning the same image across scenes only takes a long-press drag and a tap of the duplicate button.';

  @override
  String get tipsTextCaptionTitle => 'Add captions with the text tool';

  @override
  String get tipsTextCaptionDesc =>
      'Use the text tool to place captions or comments frame by frame. Switching the font to pixel mode can also give the text a retro, old-game look.';

  @override
  String get tipsAutofillPresetTitle =>
      'Register an autofill setting for each part';

  @override
  String get tipsAutofillPresetDesc =>
      'Registering a setting per part — skin, hair, clothes — with shading included lets you automate most of the coloring just by drawing the lineart. You can also narrow down which settings are used in each project.';

  @override
  String get tipsAutofillBaseCoatTitle =>
      'Autofill works fine as a single base-coat layer too';

  @override
  String get tipsAutofillBaseCoatDesc =>
      'Autofill is meant for coloring part by part, but you don\'t have to divide everything carefully — using it as a single, one-color base-coat layer over the whole lineart is plenty useful on its own. It fills everything inside the lines in one pass, which prevents the missed spots (gaps where the background shows through) that often happen with manual bucket fill. Paint your colors by hand on top of that, and you get the benefit without the part-splitting work.';

  @override
  String get tipsBrushFavoriteTitle =>
      'Favorite your go-to brushes to switch without hunting';

  @override
  String get tipsBrushFavoriteDesc =>
      'Tap the star icon on the brushes you use most to favorite them. The star icon at the top of the list lets you filter down to favorites only, cutting down on how long it takes to find one. Favorited brushes can\'t be deleted by accident.';

  @override
  String get tipsPressureCurveTitle =>
      'Tune the pressure curve to match your hand';

  @override
  String get tipsPressureCurveDesc =>
      'The pressure curve in settings lets you place up to 10 control points freely. If the strength response doesn\'t feel right, adjust it to match your own pressure habits.';

  @override
  String get tipsExportFormatTitle =>
      'Pick the export format that fits your purpose';

  @override
  String get tipsExportFormatDesc =>
      'GIF export is great for casual posting to social media, transparent WebM is for layering over other video or keeping the background transparent, and MP4 is for a regular video file. Choosing per use case makes it easier to balance file size against quality.';

  @override
  String get tipsGestureShortcutTitle => 'Bind frequent actions to a gesture';

  @override
  String get tipsGestureShortcutDesc =>
      'From \"Gestures\" in settings, you can assign undo/redo or the eyedropper to a two-finger tap, three-finger tap, or long press. Since you don\'t have to switch tools, it keeps your drawing rhythm from breaking.';

  @override
  String get tipsAudioRepeatTitle =>
      'Keep sound effects on rhythm with duplicated clips + fades';

  @override
  String get tipsAudioRepeatDesc =>
      'To reuse the same sound effect repeatedly, duplicate the clip and line up copies at offset timings, giving each one its own fade-in/fade-out. That produces a natural, rhythmic repeat of the effect.';

  @override
  String get tipsVerticalRubyTitle =>
      'Vertical text + ruby for a title-logo look';

  @override
  String get tipsVerticalRubyDesc =>
      'Combining vertical writing with ruby (furigana) in the text tool gives you a Japanese-style title logo or a distinctive heading treatment. Half-width alphanumerics automatically rotate to sit sideways, so it stays readable even mixed with symbols or numbers.';

  @override
  String get tipsBrushTrySaveTreeTitle =>
      'Try new brush settings via the save tree';

  @override
  String get tipsBrushTrySaveTreeDesc =>
      'Before making a big change to brush thickness or stabilization, save to the save tree first for peace of mind. If you don\'t like the result, you can jump straight back to the previous state, making it easier to try bold adjustments.';

  @override
  String get tipsEyedropperGestureTitle =>
      'Bind the eyedropper to a two-finger tap to keep your palette consistent';

  @override
  String get tipsEyedropperGestureDesc =>
      'Assigning the eyedropper to a two-finger tap in gesture settings lets you grab a nearby color instantly without switching tools. Handy for coloring while staying true to a character\'s palette.';

  @override
  String get tipsRulerOnionTitle =>
      'Perspective ruler + onion skin to reuse a background';

  @override
  String get tipsRulerOnionDesc =>
      'Lay out a background\'s depth with the perspective ruler, then move just the character while checking neighboring frames through onion skin — no need to redraw the background every frame.';

  @override
  String get tipsGradientTraceTitle =>
      'Gradient autofill + color tracing for a natural blend';

  @override
  String get tipsGradientTraceDesc =>
      'When using a gradient in an autofill setting, set the lineart color mode to color tracing so the line’s color shifts along with the gradient’s subtle color changes, keeping the boundary from standing out.';

  @override
  String get tipsGradientOutlineHairTitle =>
      'Gradient × specified-color outline for translucent hair';

  @override
  String get tipsGradientOutlineHairDesc =>
      'Create a front-hair part in your autofill setting and set the fill to a gradient with your hair color and transparent as the two colors. Set the angle to 90°, adjust the feather strength and color-switch position to taste, then check \"Outline with specified color\" and pick the outline color from Recently Used Colors, choosing the same color you just used for the hair. Repeat the same steps for the shadow-color part as well as the base hair part for hair with a translucent, see-through feel.';

  @override
  String get tipsRainNoiseTitle =>
      'Rain + animated noise for a damp atmosphere';

  @override
  String get tipsRainNoiseDesc =>
      'Layering a light animated noise filter over the rain filter adds a sense of particles in the air on top of the raindrops themselves, for a damp, rainy-day texture.';

  @override
  String get tipsPartKeyframeGroupTitle =>
      'Bounce a character with part keyframes + grouping';

  @override
  String get tipsPartKeyframeGroupDesc =>
      'Animate each autofill part with layer keyframes, then group the related parts to bounce them together — you can create a mini animation that sways to music without redrawing a thing.';

  @override
  String get tipsLowSpecSettingsTitle =>
      'On low-spec devices, revisit performance settings and undo history';

  @override
  String get tipsLowSpecSettingsDesc =>
      'If things feel heavy, try switching performance settings to the \"low quality\" preset and lowering the undo history length too. That reduces memory use and can make things run more smoothly.';

  @override
  String get tipsSeriesPresetFolderTitle =>
      'Manage a series with autofill-setting filtering + folder organization';

  @override
  String get tipsSeriesPresetFolderDesc =>
      'When making multiple episodes of the same work, group the projects by episode in a folder, and narrow down which autofill settings each project uses. That keeps each character’s palette from getting mixed up and keeps work efficient.';

  @override
  String get tipsPixelToneRetroTitle =>
      'Pixel-mode stamps + screentone fill for a unified retro look';

  @override
  String get tipsPixelToneRetroDesc =>
      'Combining pixel-mode stamps with the checker and grid screentones exclusive to pixel mode lets you unify the whole screen with a pixel-art texture. Great for a retro-game feel.';

  @override
  String get tipsMagicWandLassoTitle =>
      'Magic wand + lasso fill for faster color separation';

  @override
  String get tipsMagicWandLassoDesc =>
      'Select a broad area at once with the select tool\'s magic wand, then fine-tune just the overflow with lasso selection — even complex color separation goes fast this way.';

  @override
  String get tipsCommonLayerFolderTitle =>
      'Common layers + folders to reuse across episodes';

  @override
  String get tipsCommonLayerFolderDesc =>
      'For a logo or credit text used in every episode of a series, turn it into a common layer and keep it organized in a folder — makes it easy to handle when copying it into a new episode\'s project.';

  @override
  String get tipsStrokeDecayFadeTitle =>
      'Stroke decay + fade for a brush-pen feel';

  @override
  String get tipsStrokeDecayFadeDesc =>
      'Combining stroke decay and fade in brush settings tapers the start and end of a stroke naturally, giving lines the kind of expressive thick-thin variation you get from a calligraphy or ink brush.';

  @override
  String get tipsColorMixingFadeTitle =>
      'Color mixing + fade for a paint-like blend';

  @override
  String get tipsColorMixingFadeDesc =>
      'Adding fade to a brush that has color mixing enabled makes it blend with the color underneath while gradually thinning out — much closer to how real paint behaves.';

  @override
  String get tipsOutlineAnimeStyleTitle =>
      'Outline + anime style for a cel-animation finish';

  @override
  String get tipsOutlineAnimeStyleDesc =>
      'Draw the outline onto a new layer with the draw filter\'s outline, then reduce the color count with the anime-style filter, for a crisp, cel-animation-like finish.';

  @override
  String get tipsLevelsToneCurveTitle =>
      'Levels + tone curve for a graphic-design look';

  @override
  String get tipsLevelsToneCurveDesc =>
      'Push the contrast hard with levels first, then sculpt the gradation with the tone curve, for a poster-like graphic look that departs from photographic tonality.';

  @override
  String get tipsMosaicChromaticTitle =>
      'Mosaic + chromatic aberration for a rough CRT texture';

  @override
  String get tipsMosaicChromaticDesc =>
      'Lower the resolution with mosaic, then layer chromatic aberration on top, for a rough texture like watching an old CRT TV — a different flavor from the CRT filter on its own.';

  @override
  String get tipsEndCardWatermarkTitle =>
      'Watermark is for your signature, End Card is separate';

  @override
  String get tipsEndCardWatermarkDesc =>
      'Use the watermark feature when you want to add your own signature or mark to a video. The end card is the app\'s own logo shown automatically at the end of every video; free members can\'t change it. Premium members can hide it or replace it with their own video or image. If you want a custom closing without using the end card, you can recreate a similar effect yourself by adding an image layer with a fade in/out.';

  @override
  String get tipsVerticalPixelFontTitle =>
      'Mix live-action footage with hand-drawn art for \"live-action × anime\"';

  @override
  String get tipsVerticalPixelFontDesc =>
      'A trick only possible because this app is both an illustration app and a video editor at once. Place a live-action video clip on the timeline, then use onion skin on a layer above it to hand-draw speed lines or a character over the footage — creating a mixed-media video where hand-drawn animation overlays live action.';

  @override
  String get tipsTimelineMarkerTitle =>
      'Use timestamps to line up sound and mouth flaps';

  @override
  String get tipsTimelineMarkerDesc =>
      'Scenes handle a range — a start and end frame — while timestamps mark a single instant with a comment you can jump to in one tap. Placing several timestamps inside the same scene — \"sound effect at frame 120,\" \"mouth flap \'ah\' at frame 180\" — makes lining up sound with the picture dramatically easier.';

  @override
  String get tipsCommunityYoutubeTitle =>
      'Posting to the Work Plaza goes through YouTube';

  @override
  String get tipsCommunityYoutubeDesc =>
      'When you post to the Work Plaza, your work is published through YouTube. NIARIM does not transmit, collect, or store the video file itself on the developer\'s servers. If you set the video to \"Unlisted\" on the YouTube side, it won\'t appear in YouTube\'s public listings and will only be posted within the Work Plaza.';

  @override
  String get tipsToolbarCustomizeTitle =>
      'Reorder or hide toolbar tools to cut down finger travel';

  @override
  String get tipsToolbarCustomizeDesc =>
      'From toolbar editing in settings, you can hide tools you never use and reorder the ones you do to sit somewhere your finger reaches easily. Trimming the list down keeps you from hunting for a tool and shortens finger travel, picking up your drawing rhythm.';

  @override
  String get tipsAutofillBlendModeTitle =>
      'Change shading texture with an autofill part\'s blend mode';

  @override
  String get tipsAutofillBlendModeDesc =>
      'Each part in an autofill setting can have its own blend mode. Set a shadow part to \"overlay\" or \"soft light\" instead of \"multiply\" for softer shading that feels like light passing through — a hidden degree of freedom that lets you change the texture of shading without changing the color.';

  @override
  String get tipsStampBlendModeTitle =>
      'Stamps + blend mode for a light effect';

  @override
  String get tipsStampBlendModeDesc =>
      'Setting a placed stamp layer\'s blend mode to \"screen\" or \"addition\" makes glow lines or sparkle effects blend naturally into the background and really stand out.';

  @override
  String get tipsQuickToolPenSubTitle =>
      'Quick tool + pen sub-tools for a workflow that never stops';

  @override
  String get tipsQuickToolPenSubDesc =>
      'Register your most-used tools to the quick tool, and also make use of the pen sub-tools (long-press the pen to switch to screentone fill or stamp placement) — you\'ll cut down how often you jump between panels and keep your rhythm going.';

  @override
  String get tipsAutofillToneReuseTitle =>
      'Reuse a screentone fill just by redrawing the lineart, via autofill\'s screentone setting';

  @override
  String get tipsAutofillToneReuseDesc =>
      'Setting each part in an autofill setting to \"use screentone\" reproduces the screentone fill automatically every time you redraw the lineart — no need to reapply the screentone frame by frame.';

  @override
  String get tipsAutofillMisfillTitle =>
      'Knowing how autofill works cuts down on fill mistakes';

  @override
  String get tipsAutofillMisfillDesc =>
      'Autofill is not a generative-AI feature — it is an application of per-layer bucket fill. So when a single part has a gap enclosed by lines, such as inside long hair, that gap gets filled too. A good countermeasure is to first assign each part a bright, highly saturated colour and run one pass. Mistakes stand out immediately, making the autofill layer easy to correct by hand; once you have fixed it, set the real colours and run autofill again to overwrite, and misfills drop sharply.';

  @override
  String get tipsHomeWidgetTitle =>
      'Keep a work in view with a home screen widget';

  @override
  String get tipsHomeWidgetDesc =>
      'Pick a work from Settings → Home screen widgets, and a single frame from it appears as a static image on your phone\'s home screen. The \"Choose a work\" screen shares the same sort, search, and favorites filter as the project list tab, and the frame picker gives you the same playback and seek controls as the timeline so you can find just the right frame. Add the New work and Plaza widgets alongside it for one-tap access to drawing and browsing posted works from your home screen.';

  @override
  String get tipsAutofillTransparentFixTitle =>
      'Erase autofill overflow with a transparent-colour bucket fill';

  @override
  String get tipsAutofillTransparentFixDesc =>
      'When autofill spills into an area you did not want filled, a bucket fill with the drawing colour set to transparent is easier than scrubbing with the eraser. Bucket fill processes a whole line-enclosed region at once, so a single tap wipes out just the overflow cleanly.';

  @override
  String get tipsRadialVignetteTitle =>
      'Radial ruler + vignette for speed-line impact';

  @override
  String get tipsRadialVignetteDesc =>
      'Draw a burst of speed lines all at once with the radial ruler, then layer the vignette draw filter on top for a manga-climax kind of punch.';

  @override
  String get tipsClippingGradientTitle =>
      'Clipping + gradient to keep shading re-editable';

  @override
  String get tipsClippingGradientDesc =>
      'Clip a gradient layer onto a character layer, and you can re-adjust the shading just by changing the gradient\'s extent and angle — no need to redraw its shape with a brush.';

  @override
  String get tipsToneCurveSepiaTitle =>
      'Tone curve + sepia for a retro-photo feel';

  @override
  String get tipsToneCurveSepiaDesc =>
      'Adjust the light/dark contrast with the tone curve effect filter, then layer sepia on top, for a texture like a faded old photograph.';

  @override
  String get tipsCameraLensBlurTitle =>
      'Camera keyframes + lens blur for a zoom-blur effect';

  @override
  String get tipsCameraLensBlurDesc =>
      'Timing a stronger lens blur effect filter to the moment a camera keyframe zooms in gives it the punch of a live-action zoom blur.';

  @override
  String get tipsBlurVignetteBgTitle =>
      'Gaussian blur + vignette for a soft background bokeh';

  @override
  String get tipsBlurVignetteBgDesc =>
      'Layer the Gaussian blur and vignette draw filters onto just the background layer, and your main character naturally stands out, giving a camera-like depth-of-field finish.';

  @override
  String get tipsSepiaVignetteTitle =>
      'Sepia + vignette for an antique-photo video';

  @override
  String get tipsSepiaVignetteDesc =>
      'Combining the sepia effect filter with the vignette draw filter gives your video the darkened corners and faded look of an antique photograph.';

  @override
  String get tipsVideoTrimReuseTitle =>
      'Reuse the same video file by changing each clip\'s trim range';

  @override
  String get tipsVideoTrimReuseDesc =>
      'Even the same video file can be placed as a different-feeling cut each time by changing its start/end trim per clip. Gives you variety without adding more source material.';

  @override
  String get tipsSaveSlotAutoSaveTitle =>
      'Use save slots and autosave for different jobs';

  @override
  String get tipsSaveSlotAutoSaveDesc =>
      'Autosave always overwrites with the latest state, while save slots can hold several states at once. Save to a slot at a major milestone and leave the small changes to autosave, so you can reliably get back to the point you need.';

  @override
  String get tipsQuickToolSwipeTitle =>
      'Swipe up on the quick tool to reorder it';

  @override
  String get tipsQuickToolSwipeDesc =>
      'To change what\'s registered in the quick tool, you can open the management popup with an upward swipe, not just a long press. Handy for reordering fast while operating one-handed.';

  @override
  String get tipsDrawingAreaCameraTitle =>
      'A wider drawing area + camera keyframes for safe panning and zooming';

  @override
  String get tipsDrawingAreaCameraDesc =>
      'Setting the drawing area wider than the export bounds means panning or zooming with camera keyframes won\'t risk cutting off the edge of the screen. Worth checking before adding a big camera move.';

  @override
  String get tipsWebmCommonLayerTitle =>
      'Transparent WebM + a common layer to keep the background separate';

  @override
  String get tipsWebmCommonLayerDesc =>
      'If you\'re compositing a character exported as transparent WebM over a background in other video software, keeping the background on its own common layer avoids unwanted color bleeding into the transparent area, for a cleaner cutout.';

  @override
  String get tipsLeftHandedWorkspaceTitle =>
      'Left-handed mode + workspace settings for an easier setup';

  @override
  String get tipsLeftHandedWorkspaceDesc =>
      'If you\'re left-handed, turning on left-handed mode in workspace settings mirrors the docked panels, so they\'re less likely to sit under your drawing hand.';

  @override
  String get tipsTransferDeviceTitle =>
      'Move your work to another device with a transfer file';

  @override
  String get tipsTransferDeviceDesc =>
      'If you want to switch devices and keep drawing in the same environment, the transfer (.niatra) feature moves your settings, brushes, screentones, stamps, palettes, and more all together. To hand over a project you\'re working on, use \"Share (.niashare)\" instead.';

  @override
  String get fontSettingsTabDownloaded => 'Downloaded';

  @override
  String get fontSettingsTabSearch => 'Find & Download';

  @override
  String get fontSettingsTabImport => 'Import';

  @override
  String get fontDownloadedSearchHint => 'Search by font name...';

  @override
  String get fontPixelModeTooltip =>
      'Pixel mode (for dot fonts. Renders crisply without anti-aliasing)';

  @override
  String get fontEmptyTitle => 'No fonts';

  @override
  String get fontEmptyHint =>
      'Add fonts from the \"Find & Download\" or \"Import\" tabs';

  @override
  String get fontRenameDialogTitle => 'Rename Font';

  @override
  String get fontImportTitle => 'Import a font saved on this device';

  @override
  String get fontImportFormats => 'Supported formats: TTF / OTF';

  @override
  String get fontSelectFileButton => 'Select File';

  @override
  String get fontUnsupportedSnackbar => 'This font could not be loaded.';

  @override
  String fontAddedSnackbar(String name) {
    return 'Added \"$name\" (shown in the Downloaded tab)';
  }

  @override
  String get fontCorruptedSnackbar => 'The font is corrupted.';

  @override
  String get licenseScreenTitle => 'Terms & Licenses';

  @override
  String get licenseSectionTerms => 'Terms of Service';

  @override
  String get licenseSectionFonts => 'Fonts Used';

  @override
  String get licenseSectionOss => 'Open Source Software Licenses';

  @override
  String get licenseOssListTitle => 'List of Library Licenses';

  @override
  String get licenseOssListSubtitle =>
      'Shows the licenses of the OSS packages used by this app';

  @override
  String get licenseFfmpegNote =>
      'WebM and AVI export use FFmpeg (LGPL 3.0, via ffmpeg_kit_flutter_new_video). Source for the modified version: https://github.com/sk3llo/ffmpeg_kit_flutter\nMP4 export uses the device\'s built-in hardware encoder directly and does not use FFmpeg.';

  @override
  String licenseFontCreditMeta(String author, String license) {
    return 'Author: $author   License: $license';
  }

  @override
  String get toolbarPenTooltip => 'Pen (long-press for sub-tools)';

  @override
  String get toolbarPenFirstUseTip =>
      'Long-press the pen to switch between brush, screentone, stamp, and lasso fill.';

  @override
  String get toolbarBucketTooltip =>
      'Bucket (long-press to switch flat/screentone fill)';

  @override
  String get toolbarBucketFirstUseTip =>
      'Long-press the bucket to switch between flat fill and screentone fill.';

  @override
  String get toolbarSelectTooltip => 'Select (long-press to change type)';

  @override
  String get toolbarShapeTooltip => 'Shape (tap to choose type)';

  @override
  String get toolbarTextFirstUseTip =>
      'Freely place text. You can also change the font, color, and outline.';

  @override
  String get toolbarQuickToolFirstUseTip =>
      'Tap to cycle through your registered tools in order. Long-press or swipe up to edit your registered tools.';

  @override
  String get firstUseTipOperationGuideTitle => 'Basic controls';

  @override
  String get firstUseTipOperationGuideBody =>
      'A single tap on a toolbar icon switches to that tool. Long-press the same icon, or swipe up on it, to open that tool’s detailed settings (brush type, fill mode, selection mode and so on). Double-tap an icon for a short description of the tool. You can read all of this again from the \"?\" button in the top right of each screen.';

  @override
  String get helpBasicGestureTitle => 'Basic controls (tap, long-press, swipe)';

  @override
  String get helpBasicGestureDesc =>
      'A single tap on a toolbar icon switches to that tool. Long-press the same icon, or swipe up on it, to open its detailed settings. Behind that long-press or swipe you will find: brush / screentone / stamp / lasso fill for the pen, solid vs. screentone for the bucket, rectangle / lasso / magic wand for the selection tool, blur vs. mosaic for the finger tool, and the registered tool list for the quick-swap tool. Double-tapping an icon shows a short description at the bottom of the screen.\\nOn the canvas, pinch with two fingers to zoom, drag with two fingers to pan, tap with two fingers to undo and with three fingers to redo. Double-tap the left or right edge of the screen to move to the previous or next frame.\\nWith a mouse or pen tablet connected, the wheel zooms and dragging with the middle button pans.';

  @override
  String get toolbarStampColorLockedSnackbar =>
      'Stamps carry their own color, so the color can\'t be changed';

  @override
  String get toolbarBrushSettingsTooltip => 'Brush Settings';

  @override
  String get toolbarLayerTooltip => 'Layers';

  @override
  String get toolbarQuickToolTooltip =>
      'Quick Tool (long-press/swipe up to edit)';

  @override
  String get toolbarSaveTooltip => 'Save (Save Tree)';

  @override
  String get toolbarBucketFlatFill => 'Flat Fill';

  @override
  String get toolbarBucketToneListLabel => 'Screentones';

  @override
  String get toolbarSelectRect => 'Rectangle Select';

  @override
  String get toolbarSelectLasso => 'Lasso Select';

  @override
  String get toolbarSelectMagicWand => 'Auto Select (Magic Wand)';

  @override
  String get creativePanelFavoritesOnlyTooltip => 'Show Favorites Only';

  @override
  String get creativePanelSearchTooltip => 'Search by Name';

  @override
  String get creativePanelSearchModeKeyword =>
      'Searching by keyword (tap for tag search)';

  @override
  String get creativePanelSearchModeTag =>
      'Searching by tag (tap for keyword search)';

  @override
  String get creativePanelTagSearchHint => 'Search by tag';

  @override
  String get creativePanelTagNoneYet =>
      'No tags yet — add them from the edit screen';

  @override
  String get creativePanelTagsLabel => 'Tags';

  @override
  String get creativePanelTagsHint => 'Separate with commas or spaces';

  @override
  String get creativePanelTagClearFilter => 'Clear tag filter';

  @override
  String get widgetSettingsTitle => 'Home screen widgets';

  @override
  String get widgetSettingsDescription =>
      'Place three widgets on your home screen: a single frame from a work you choose, “New work”, and “Plaza”. Add them by long-pressing your home screen.';

  @override
  String get widgetSettingsSubtitle => 'Work to display, widget colour';

  @override
  String get widgetArtworkSection => 'Work to display';

  @override
  String get widgetArtworkPickButton => 'Choose a work';

  @override
  String get widgetSectionArtwork => 'Launch screen widget';

  @override
  String get widgetSectionArtworkDesc =>
      'Shows one frame from the work you pick. Tapping it opens NIARIM.';

  @override
  String get widgetSectionCreate => 'New work widget';

  @override
  String get widgetSectionCreateDesc =>
      'Tapping it opens the “New work” screen.';

  @override
  String get widgetSectionPlaza => 'Plaza widget';

  @override
  String get widgetSectionPlazaDesc => 'Tapping it opens the Plaza.';

  @override
  String get widgetArtworkNone => 'No work selected';

  @override
  String widgetArtworkFrameNumberLabel(int n) {
    return 'Frame $n';
  }

  @override
  String get widgetArtworkFramePickerHint =>
      'Tap the frame you want to display.';

  @override
  String get widgetArtworkFramePickerConfirmButton => 'Use this frame';

  @override
  String get widgetArtworkNoFrames => 'This scene doesn’t have any frames yet.';

  @override
  String get widgetColorFollowTheme => 'Match the app theme';

  @override
  String get widgetColorCustom => 'Pick a colour';

  @override
  String get widgetColorBase => 'Background color';

  @override
  String get widgetColorForeground => 'Text and icon color';

  @override
  String get widgetNoProjects =>
      'No works yet. Once you create one, you can choose it here.';

  @override
  String get widgetSettingsNote =>
      'Home screen widgets cannot play video, so a single frame of the chosen work is shown as a still image.';

  @override
  String get assetTagLineArt => 'Line art';

  @override
  String get assetTagBasic => 'Basic';

  @override
  String get assetTagMainLine => 'Main line';

  @override
  String get assetTagPaint => 'Painting';

  @override
  String get assetTagBlur => 'Blur';

  @override
  String get assetTagMixing => 'Blending';

  @override
  String get assetTagAnalog => 'Analog';

  @override
  String get assetTagDecoration => 'Decoration';

  @override
  String get assetTagRough => 'Rough';

  @override
  String get assetTagEffect => 'Effects';

  @override
  String get assetTagTaper => 'Taper';

  @override
  String get assetTagPixelArt => 'Pixel art';

  @override
  String get assetTagHalftone => 'Halftone';

  @override
  String get assetTagShadow => 'Shadow';

  @override
  String get assetTagLine => 'Lines';

  @override
  String get assetTagGradient => 'Gradient';

  @override
  String get assetTagTexture => 'Texture';

  @override
  String get assetTagClothing => 'Clothing';

  @override
  String get assetTagMesh => 'Mesh';

  @override
  String get assetTagBackground => 'Background';

  @override
  String get assetTagPattern => 'Pattern';

  @override
  String get assetTagShape => 'Shapes';

  @override
  String get assetTagSymbol => 'Symbols';

  @override
  String get assetTagManga => 'Manga';

  @override
  String get creativePanelFolderButton => 'Folder';

  @override
  String get creativePanelCreateButton => 'Create';

  @override
  String get creativePanelImportButton => 'Import';

  @override
  String get creativePanelFolderAllChip => 'All';

  @override
  String get creativePanelEditAction => 'Edit';

  @override
  String get toneTitle => 'Screentones';

  @override
  String get toneEmpty => 'No screentones';

  @override
  String get toneSearchHint => 'Search by screentone name';

  @override
  String get toneEditTitle => 'Edit Screentone';

  @override
  String get toneChangeTextureButton => 'Change Texture Image';

  @override
  String get toneCreateDialogTitle => 'Custom Screentone';

  @override
  String toneImportFailedSnackbar(String error) {
    return 'Failed to load the screentone: $error';
  }

  @override
  String toneExportFailedSnackbar(String error) {
    return 'Failed to export the screentone: $error';
  }

  @override
  String get privacyPolicyScreenTitle => 'Privacy Policy';

  @override
  String get stampTitle => 'Stamps';

  @override
  String get stampSearchHint => 'Search by stamp name';

  @override
  String get stampEmpty => 'No stamps';

  @override
  String get stampCreateDialogTitle => 'Custom Stamp';

  @override
  String stampImportFailedSnackbar(String error) {
    return 'Failed to load the stamp: $error';
  }

  @override
  String stampExportFailedSnackbar(String error) {
    return 'Failed to export the stamp: $error';
  }

  @override
  String get stampEditTitle => 'Edit Stamp';

  @override
  String get stampRotationLabel => 'Rotation';

  @override
  String get stampPixelModeLabel => 'Pixel mode';

  @override
  String get stampPixelModeHint =>
      'Renders as pixel art (mosaic + reduced colors)';

  @override
  String get stampDensityLabel => 'Density';

  @override
  String get stampScatterLabel => 'Scatter';

  @override
  String get stampChangeImageButton => 'Change Stamp Image';

  @override
  String get themeSettingsTitle => 'Theme & Appearance';

  @override
  String get themeColorCustomizeSection => 'Color Customization';

  @override
  String get themeColorAccent => 'Accent Color';

  @override
  String get themeColorText => 'Text Color';

  @override
  String get themeColorPanelBg => 'Panel Background Color';

  @override
  String get themeColorMenuBg => 'Menu Background Color';

  @override
  String get themeColorSelection => 'Selection Color';

  @override
  String get themeColorUpdateMark => 'Update Mark Color';

  @override
  String get themeContrastErrorTitle => 'Text would be unreadable';

  @override
  String get themeContrastErrorBody =>
      'The text color and the background color are too close, so text would be almost invisible. The settings screen itself would become unreadable and you could not undo it, so this combination cannot be saved. Please change the brightness of one of them.';

  @override
  String get themeUnreadableResetButton => 'Reset theme';

  @override
  String get themeUnreadableResetDone =>
      'The theme has been reset to the default colors.';

  @override
  String get themePresetSection => 'Themes';

  @override
  String themePresetDuplicateName(String name) {
    return '$name (Copy)';
  }

  @override
  String get themeDuplicateAction => 'Duplicate';

  @override
  String themeAdoptColorsSnackbar(String name) {
    return 'Applied the colors of “$name” to your current colors. Editing them will not change the original theme.';
  }

  @override
  String themeEditPresetSnackbar(String name) {
    return 'Now editing “$name”. Changes in Color customization are saved to this theme.';
  }

  @override
  String get themeExportMenuItem => 'Export (.niatheme)';

  @override
  String themeExportFailedSnackbar(String error) {
    return 'Export failed: $error';
  }

  @override
  String get themeImportSuccessSnackbar => 'Imported the .niatheme file';

  @override
  String themeImportFailedSnackbar(String error) {
    return 'Import failed: $error';
  }

  @override
  String get themeSaveAsNewButton => 'Save Current Settings as New Theme';

  @override
  String get themeImportButton => 'Import .niatheme';

  @override
  String get themePresetNameDialogTitle => 'Theme Name';

  @override
  String get themeDefaultPresetName => 'My Theme';

  @override
  String get onionSkinTitle => 'Onion Skin';

  @override
  String get onionSkinPrevFrame => 'Previous Frame';

  @override
  String get onionSkinNextFrame => 'Next Frame';

  @override
  String get onionSkinFrameInterval => 'Frame Interval';

  @override
  String get onionSkinFadeByDistance => 'Darker When Closer';

  @override
  String get onionSkinColorPickerTitle => 'Choose a Color';

  @override
  String get onionSkinOnFixed => 'ON (Fixed)';

  @override
  String get onionSkinFrameCount => 'Frame Count';

  @override
  String onionSkinFrameCountFixed(int count) {
    return '$count frame(s) (Fixed)';
  }

  @override
  String get onionSkinColorLabel => 'Color';

  @override
  String get onionSkinOpacityLabel => 'Opacity';

  @override
  String get exportScreenTitle => 'Export';

  @override
  String get exportPresetSection => 'Preset';

  @override
  String get exportPresetStandard => 'Standard';

  @override
  String get exportPresetHighQuality => 'High Quality';

  @override
  String get exportPresetCustom => 'Custom';

  @override
  String get exportAdvancedSettings => 'Advanced Settings';

  @override
  String get exportFpsLabel => 'FPS';

  @override
  String get exportFormatSection => 'Format';

  @override
  String get exportFormatMp4 => 'MP4';

  @override
  String get exportFormatMp4Subtitle => 'General-purpose video format';

  @override
  String get exportFormatGif => 'GIF';

  @override
  String get exportFormatGifSubtitle => 'Animated GIF';

  @override
  String get exportFormatWebmSubtitle => 'Transparent background video';

  @override
  String get exportFormatAvi => 'AVI';

  @override
  String get exportFormatAviSubtitle =>
      'Legacy-compatible video format (no transparency)';

  @override
  String get exportStartButton => 'Start Export';

  @override
  String get exportProjectNotFoundError => 'Project not found';

  @override
  String exportFailedError(String error) {
    return 'Export failed: $error';
  }

  @override
  String get exportInProgressTitle => 'Exporting';

  @override
  String get exportCancelledSnackbar => 'Export cancelled';

  @override
  String get exportCancelHint =>
      'Finishing the final step — cancellation will apply once it\'s done';

  @override
  String get exportOutdatedAutofillTitle => 'Auto-fill is not up to date';

  @override
  String get exportOutdatedAutofillBody =>
      'Some auto-fill layers haven\'t been updated. Export anyway?';

  @override
  String get exportContinueButton => 'Continue';

  @override
  String get exportDurationExceededTitle => 'Exceeds the maximum duration';

  @override
  String exportDurationExceededBody(int max, int current) {
    return 'The maximum duration for the free version is $max seconds.\nThe current project is about $current seconds.\nUpgrading to Premium raises this limit to up to 2 hours.';
  }

  @override
  String get exportViewPremiumButton => 'View Premium';

  @override
  String get exportContinueAnywayButton => 'Continue Anyway';

  @override
  String get exportCompleteTitle => 'Export Complete';

  @override
  String exportCompleteFramesBody(int count) {
    return 'Exported $count frame(s).';
  }

  @override
  String exportSaveLocationLabel(String fileName) {
    return 'Saved to: In-app storage ($fileName)';
  }

  @override
  String get exportSaveLocationHint =>
      'To open it in your device\'s Photos app or file manager, use \"Share\" below to choose where to save it.';

  @override
  String get exportBackToProjectsButton => 'Back to Projects';

  @override
  String get exportBackToCanvasButton => 'Back to Canvas';

  @override
  String get newProjectScreenTitle => 'New Project';

  @override
  String get newProjectDefaultName => 'New Project';

  @override
  String get newProjectNameLabel => 'Project name';

  @override
  String get newProjectSizeLabel => 'Size';

  @override
  String get newProjectPresetFullHd =>
      'Full HD (16:9 – for YouTube and other landscape videos)';

  @override
  String get newProjectPresetHd => 'HD (16:9 – lightweight)';

  @override
  String get newProjectPresetSquare =>
      '1:1 Square (for Twitter/Instagram posts)';

  @override
  String get newProjectPresetVertical =>
      '9:16 Vertical (for YouTube Shorts/Reels/Stories)';

  @override
  String get newProjectPresetPortrait =>
      '4:5 Portrait (for Instagram feed posts)';

  @override
  String get newProjectPresetAnalog => '4:3 (classic broadcast ratio)';

  @override
  String get newProjectCustomSize => 'Custom';

  @override
  String get newProjectMaxEdgeHint => 'The longer side can be set up to 1920px';

  @override
  String get newProjectWidthLabel => 'Width (px)';

  @override
  String get newProjectHeightLabel => 'Height (px)';

  @override
  String get newProjectWidthShort => 'Width';

  @override
  String get newProjectHeightShort => 'Height';

  @override
  String get newProjectSizePresetManageButton => 'Size settings';

  @override
  String get newProjectSaveCustomSizeButton => 'Save this size';

  @override
  String get newProjectSaveCustomSizeDialogTitle =>
      'Enter a name for this size';

  @override
  String get newProjectSaveCustomSizeNameLabel => 'Size name';

  @override
  String get newProjectSaveCustomSizeSavedSnackbar => 'Size saved';

  @override
  String get canvasSizePresetManageScreenTitle => 'Size settings';

  @override
  String get canvasSizePresetEmpty => 'No saved sizes yet';

  @override
  String get canvasSizePresetEmptyHint =>
      'Specify a custom size on the new project screen and tap \"Save this size\" to add one';

  @override
  String get canvasSizePresetEditDialogTitle => 'Edit size';

  @override
  String get canvasSizePresetDuplicateSuffix => 'copy';

  @override
  String newProjectDurationLabel(String max) {
    return 'Length (max $max)';
  }

  @override
  String newProjectDurationLabelWithPremiumHint(String max) {
    return 'Length (max $max; up to 2 hours with Premium)';
  }

  @override
  String newProjectDurationSeconds(int n) {
    return '${n}s';
  }

  @override
  String newProjectDurationHms(int h, int m, int s) {
    return '${h}h ${m}m ${s}s';
  }

  @override
  String newProjectDurationHm(int h, int m) {
    return '${h}h ${m}m';
  }

  @override
  String newProjectDurationH(int h) {
    return '${h}h';
  }

  @override
  String newProjectDurationMs(int m, int s) {
    return '${m}m ${s}s';
  }

  @override
  String newProjectDurationM(int m) {
    return '${m}m';
  }

  @override
  String get newProjectBackgroundColorLabel => 'Background color';

  @override
  String get newProjectDrawingAreaTitle => 'Expand drawing area';

  @override
  String get newProjectDrawingAreaSubtitle =>
      'Adds space you can draw on outside the export frame';

  @override
  String get newProjectScaleLabel => 'Scale';

  @override
  String newProjectScaleValue(String value) {
    return '$value×';
  }

  @override
  String newProjectDrawableAreaInfo(String width, String scale, String result) {
    return 'Drawable area: $width×$scale = $result';
  }

  @override
  String newProjectTotalFrames(int count) {
    return 'Total frames: $count';
  }

  @override
  String newProjectExportSizeInfo(String size) {
    return 'Export size: $size';
  }

  @override
  String newProjectDrawingAreaInfo(String size) {
    return 'Drawing area: $size';
  }

  @override
  String get colorPickerTitle => 'Color picker';

  @override
  String get colorPickerOpacityLabel => 'Opacity';

  @override
  String get colorPickerHexCopiedSnackbar => 'Copied HEX code';

  @override
  String get colorPickerRecentColorsLabel => 'Recent colors';

  @override
  String get colorPickerRecentColorsEmpty => 'None yet';

  @override
  String get colorPickerPaletteLabel => 'Palette';

  @override
  String get colorPickerNewPaletteTooltip => 'New palette';

  @override
  String get colorPickerManagePaletteTooltip => 'Manage palette';

  @override
  String get colorPickerPaletteEmptyHint =>
      'No colors yet. Tap \"+\" to add the current color.';

  @override
  String get colorPickerPaletteLongPressHint => 'Long-press to remove';

  @override
  String get colorPickerAddCurrentColorButton => 'Add current color to palette';

  @override
  String get colorPickerPaletteNameLabel => 'Palette name';

  @override
  String get colorPickerFavoriteAdd => 'Add to favorites';

  @override
  String get colorPickerFavoriteRemove => 'Remove from favorites';

  @override
  String get penSubToolTabBrush => 'Brush';

  @override
  String get penSubToolTabTone => 'Screentone';

  @override
  String get penSubToolTabStamp => 'Stamp';

  @override
  String get penSubToolTabLassoFill => 'Lasso fill';

  @override
  String get penSubToolToneTooltipMessage =>
      'Choose a screentone to paint screentone patterns with the bucket or pen.';

  @override
  String get penSubToolStampTooltipMessage =>
      'Place stamps of a fixed shape. Long-press to set rotation, density, and more.';

  @override
  String get penSubToolManageTooltip => 'Manage';

  @override
  String penSubToolBrushSizeOpacity(int size, int opacity) {
    return '${size}px · $opacity%';
  }

  @override
  String get penSubToolStampRotationSubtitle =>
      'Randomly rotate to match the stroke direction';

  @override
  String get brushSearchHint => 'Search by brush name';

  @override
  String get brushEmpty => 'No brushes';

  @override
  String get brushCreateDialogTitle => 'Custom brush';

  @override
  String brushImportFailedSnackbar(String error) {
    return 'Failed to load brush: $error';
  }

  @override
  String brushExportFailedSnackbar(String error) {
    return 'Failed to export brush: $error';
  }

  @override
  String get brushSettingsSizeLabel => 'Size';

  @override
  String get brushSettingsOpacityLabel => 'Opacity';

  @override
  String get brushSettingsSpacingLabel => 'Spacing';

  @override
  String get brushSettingsBlurRadiusLabel => 'Blur radius';

  @override
  String get brushSettingsStabilizationTitle => 'Stroke stabilization';

  @override
  String get brushSettingsStabilizationStrengthLabel =>
      'Stabilization strength';

  @override
  String get brushSettingsPixelModeTitle => 'Pixel mode';

  @override
  String get brushSettingsPressureModeTitle => 'Pressure sensitivity';

  @override
  String get brushSettingsPressureOff => 'Off';

  @override
  String get brushSettingsPressureSize => 'Affects size';

  @override
  String get brushSettingsPressureOpacity => 'Affects opacity';

  @override
  String get brushSettingsPressureSizeAndOpacity => 'Affects size + opacity';

  @override
  String get brushSettingsFadeModeTitle => 'Fade';

  @override
  String get brushSettingsFadeOff => 'OFF';

  @override
  String get brushSettingsFadeWeak => 'Weak';

  @override
  String get brushSettingsFadeMedium => 'Medium';

  @override
  String get brushSettingsFadeStrong => 'Strong';

  @override
  String get brushSettingsFadeCustom => 'Custom';

  @override
  String get brushSettingsFadeStartValueLabel => 'Start value (%)';

  @override
  String get brushSettingsFadeEndValueLabel => 'End value (%)';

  @override
  String get brushSettingsFadeDistanceLabel => 'Distance (px)';

  @override
  String get brushSettingsStrokeDecayTitle => 'Stroke decay';

  @override
  String get brushSettingsStrokeDecaySubtitle =>
      'Opacity decreases the longer you keep drawing';

  @override
  String get brushSettingsMixingTitle => 'Color mixing';

  @override
  String get brushSettingsMixingOff => 'OFF';

  @override
  String get brushSettingsMixingSimple => 'Simple mixing';

  @override
  String get brushSettingsMixingBleed => 'Bleed';

  @override
  String get brushSettingsMixingRateLabel => 'Mixing rate';

  @override
  String get projectDetailNotFoundTitle => 'Project';

  @override
  String get projectDetailNotFoundBody => 'Project not found';

  @override
  String get projectDetailFirstFrameTooltip => 'First frame';

  @override
  String get projectDetailPrevFrameTooltip => 'Back 1 frame';

  @override
  String get projectDetailPauseTooltip => 'Pause';

  @override
  String get projectDetailPlayTooltip => 'Play';

  @override
  String get projectDetailNextFrameTooltip => 'Forward 1 frame';

  @override
  String get projectDetailLastFrameTooltip => 'Last frame';

  @override
  String get projectDetailFullscreenTooltip => 'Show preview fullscreen';

  @override
  String get projectDetailFullscreenCloseTooltip => 'Close fullscreen preview';

  @override
  String get projectDetailStartEditButton => 'Start editing';

  @override
  String get projectDetailTagsQuickAction => 'Tags';

  @override
  String get projectDetailShareQuickAction => 'Share';

  @override
  String get projectDetailInfoSectionTitle => 'Project info';

  @override
  String get projectDetailInfoExportSize => 'Export size';

  @override
  String get projectDetailInfoDrawingArea => 'Drawing area';

  @override
  String projectDetailInfoDrawingAreaValue(String size, String scale) {
    return '$size  ($scale)';
  }

  @override
  String get projectDetailInfoTotalFrames => 'Total frames';

  @override
  String get projectDetailInfoWorkTime => 'Work time';

  @override
  String get projectDetailInfoLastSaved => 'Last saved';

  @override
  String get projectDetailInfoSize => 'Size';

  @override
  String get projectDetailAddTagHint => 'Add a tag';

  @override
  String projectDetailNiashareFailedSnackbar(String error) {
    return 'Failed to create .niashare: $error';
  }

  @override
  String get projectDetailTrashMenuItem => 'Move to trash';

  @override
  String get commonOff => 'OFF';

  @override
  String get perfSettingsScreenTitle => 'Performance Settings';

  @override
  String get perfSettingsQualitySection => 'Quality settings';

  @override
  String get perfSettingsQualityLow => 'Low';

  @override
  String get perfSettingsQualityMedium => 'Medium';

  @override
  String get perfSettingsQualityHigh => 'High';

  @override
  String get perfSettingsQualityCustom => 'Custom';

  @override
  String get perfSettingsQualityDescLow =>
      'For devices where you want lighter performance (1 onion skin frame each way, 5 save slots)';

  @override
  String get perfSettingsQualityDescMedium =>
      'For a typical device (3 onion skin frames each way, 10 save slots)';

  @override
  String get perfSettingsQualityDescHigh =>
      'For a device with performance to spare (5 onion skin frames each way, tree-based saves)';

  @override
  String get perfSettingsQualityDescCustom => 'Set each item individually';

  @override
  String get perfSettingsCapacitySection => 'Storage & performance settings';

  @override
  String get perfSettingsUndoLimitTitle => 'Undo steps';

  @override
  String get perfSettingsUndoLimitSubtitle => 'More steps use more memory';

  @override
  String perfSettingsUndoLimitValue(int n) {
    return '$n steps';
  }

  @override
  String get perfSettingsTrashAutoDeleteTitle => 'Auto-delete trash';

  @override
  String get perfSettingsTrashAutoDeleteSubtitle =>
      'Retention period for deleted projects';

  @override
  String perfSettingsTrashAutoDeleteValue(int n) {
    return '$n days';
  }

  @override
  String get perfSettingsCurrentSettingsSection => 'Current settings';

  @override
  String get perfSettingsTiltLabel => 'Tilt detection';

  @override
  String get perfSettingsOnionPrevLabel => 'Onion skin (previous)';

  @override
  String get perfSettingsOnionNextLabel => 'Onion skin (next)';

  @override
  String perfSettingsOnionFrameCountValue(int n) {
    return '$n frames';
  }

  @override
  String get perfSettingsSaveModeLabel => 'Save mode';

  @override
  String get perfSettingsSlotCountLabel => 'Slot count';

  @override
  String perfSettingsSlotCountValue(int n) {
    return '$n slots';
  }

  @override
  String get perfSettingsResetButton => 'Reset to default';

  @override
  String get perfSettingsCopyPresetButton => 'Copy current preset';

  @override
  String get perfSettingsTiltSwitchTitle => 'Apply pen tilt to brush';

  @override
  String get perfSettingsShowPrevOnionTitle => 'Show previous frame';

  @override
  String get perfSettingsOnionCountPrevLabel =>
      'Onion skin frame count (previous)';

  @override
  String get perfSettingsShowNextOnionTitle => 'Show next frame';

  @override
  String get perfSettingsOnionCountNextLabel => 'Onion skin frame count (next)';

  @override
  String get perfSettingsSaveModeSlot => 'Slot-based';

  @override
  String get perfSettingsSaveModeTree => 'Tree-based';

  @override
  String get perfSettingsResetDialogTitle =>
      'Reset custom quality settings to default?';

  @override
  String perfSettingsResetDialogBody(String preset) {
    return 'The default restores the \"$preset\" settings that were automatically chosen from your device\'s performance at first launch.';
  }

  @override
  String get perfSettingsResetConfirmButton => 'Reset';

  @override
  String get perfSettingsCopyPresetDialogTitle => 'Choose a preset to copy';

  @override
  String get perfSettingsCopyPresetDialogBody =>
      'Choose a preset to copy into your custom settings.';

  @override
  String get perfSettingsCopyDescLow => 'Shows 1 frame each way · lightweight';

  @override
  String get perfSettingsCopyDescMedium => 'Shows 3 frames each way · standard';

  @override
  String get perfSettingsCopyDescHigh =>
      'Shows 5 frames each way · high quality';

  @override
  String get filterPanelTitle => 'Filter';

  @override
  String filterPanelTitleBulk(int count) {
    return 'Filter (applying to $count frames)';
  }

  @override
  String get filterSearchHint => 'Search filters';

  @override
  String get filterNameGaussianBlur => 'Gaussian Blur';

  @override
  String get filterNameLensBlur => 'Lens Blur';

  @override
  String get filterNameAnimeStyle => 'Anime Style';

  @override
  String get filterNameOutline => 'Outline';

  @override
  String get filterNameToneCurve => 'Tone Curve';

  @override
  String get filterNameLevels => 'Levels';

  @override
  String get filterNameSharpen => 'Sharpen';

  @override
  String get filterNameUnsharpMask => 'Unsharp Mask';

  @override
  String get filterSharpenStrength => 'Sharpen strength';

  @override
  String get filterUnsharpAmount => 'Amount';

  @override
  String get filterNameVignette => 'Vignette';

  @override
  String get filterVignetteStrength => 'Vignette strength';

  @override
  String get filterVignetteColor => 'Vignette color';

  @override
  String get filterNameNoise => 'Film Grain';

  @override
  String get filterNoiseStrength => 'Grain strength';

  @override
  String get filterNameRetroAnime => 'Retro Anime';

  @override
  String get filterNameCrt => 'CRT';

  @override
  String get filterRetroStrength => 'Strength';

  @override
  String filterOutlineLayerNameSuffix(String name) {
    return '$name (Outline)';
  }

  @override
  String get filterStrengthBlurRadius => 'Strength (blur radius)';

  @override
  String get filterColorLevels => 'Color levels';

  @override
  String get filterEdgeStrength => 'Edge strength';

  @override
  String get filterOutlineColor => 'Outline color';

  @override
  String get filterOutlineWidth => 'Outline width';

  @override
  String get filterToneCurveLinear => 'Standard';

  @override
  String get filterToneCurveBrighten => 'Brighten';

  @override
  String get filterToneCurveDarken => 'Darken';

  @override
  String get filterToneCurveHighContrast => 'High contrast';

  @override
  String get filterToneCurveLowContrast => 'Low contrast';

  @override
  String get filterToneCurveInvert => 'Invert';

  @override
  String get filterLevelsInputBlack => 'Input: Black';

  @override
  String get filterLevelsInputWhite => 'Input: White';

  @override
  String get filterLevelsOutputBlack => 'Output: Black';

  @override
  String get filterLevelsOutputWhite => 'Output: White';

  @override
  String get filterApplyButton => 'Apply';

  @override
  String filterApplyBulkButton(int count) {
    return 'Apply to $count frames';
  }

  @override
  String get filterEmpty => 'No filters';

  @override
  String get filterApplyingTitle => 'Applying filter';

  @override
  String filterApplyingSubtitle(String name, int count) {
    return '$name　$count frames';
  }

  @override
  String get projectListNewFolderTitle => 'New folder';

  @override
  String get projectListFolderHint =>
      'You can also use this to group multiple episodes or a series of the same work';

  @override
  String get projectListEmptyTitle => 'No projects';

  @override
  String get projectListEmptyHint => 'Tap + to create a new one';

  @override
  String get projectListOpenAction => 'Open';

  @override
  String get projectListCreateShareAction => 'Create .niashare';

  @override
  String get projectListEditFolderAction => 'Edit name & color';

  @override
  String get projectListDeleteFolderConfirmTitle => 'Delete this folder?';

  @override
  String projectListDeleteFolderConfirmBody(String name) {
    return '\"$name\" will be deleted. Projects and subfolders inside it will move to the root.';
  }

  @override
  String get projectListFolderRootOption => 'No folder (root)';

  @override
  String get projectListEditFolderTooltip => 'Edit folder';

  @override
  String get projectListCreateFolderAction => 'Create new folder';

  @override
  String get projectListFolderColorLabel => 'Folder color';

  @override
  String get projectListMaterialIncludeTitle => 'Include materials';

  @override
  String get projectListMaterialIncludeHint =>
      'If not included, the recipient will see a warning about missing materials.';

  @override
  String get projectListMaterialImage => 'Images';

  @override
  String get projectListMaterialVideo => 'Videos';

  @override
  String get projectListMaterialAudio => 'Audio';

  @override
  String get projectListIncludeFontsTitle => 'Include fonts';

  @override
  String get projectListIncludeFontsSubtitle =>
      'Includes user-added fonts currently in use';

  @override
  String get blendModeNormal => 'Normal';

  @override
  String get blendModeMultiply => 'Multiply';

  @override
  String get blendModeScreen => 'Screen';

  @override
  String get blendModeOverlay => 'Overlay';

  @override
  String get blendModeAddition => 'Addition';

  @override
  String get blendModeSubtract => 'Subtract';

  @override
  String get blendModeDarken => 'Darken';

  @override
  String get blendModeLighten => 'Lighten';

  @override
  String get blendModeColorBurn => 'Color Burn';

  @override
  String get blendModeColorDodge => 'Color Dodge';

  @override
  String get blendModeHardLight => 'Hard Light';

  @override
  String get blendModeSoftLight => 'Soft Light';

  @override
  String get blendModeDifference => 'Difference';

  @override
  String get blendModeHue => 'Hue';

  @override
  String get blendModeSaturation => 'Saturation';

  @override
  String get blendModeColor => 'Color';

  @override
  String get blendModeLuminosity => 'Luminosity';

  @override
  String get autofillLineColorModeSpecified => 'Specified color';

  @override
  String get autofillLineColorModeSameAsFill => 'Same as fill';

  @override
  String get autofillLineColorModeTraceAdjust =>
      'Color trace / blend with lines';

  @override
  String get autofillGradientTypeLinear => 'Linear';

  @override
  String get autofillGradientTypeRadialCenterOut => 'Radial: center → outward';

  @override
  String get autofillGradientTypeRadialOutCenter => 'Radial: outward → center';

  @override
  String get autofillPresetScreenTitle => 'Autofill Settings';

  @override
  String get autofillPresetSearchHint => 'Search settings';

  @override
  String get autofillPresetEmptyFavorites => 'No favorite settings';

  @override
  String get autofillPresetEmpty => 'No settings yet';

  @override
  String get autofillPresetEmptyHint =>
      'Tap + in the bottom right to create one';

  @override
  String autofillPresetPartsCount(int count) {
    return '$count parts';
  }

  @override
  String get autofillPresetNewDialogTitle => 'New';

  @override
  String get autofillPresetNameLabel => 'Setting name';

  @override
  String get autofillPresetRenameDialogTitle => 'Rename setting';

  @override
  String autofillPresetDeleteConfirmTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get autofillFabImportOption => 'Import';

  @override
  String get autofillPresetExportMenuItem => 'Export (.niafill)';

  @override
  String autofillPresetImportSuccessSnackbar(int count) {
    return 'Imported $count preset(s)';
  }

  @override
  String autofillPresetImportFailedSnackbar(String error) {
    return 'Import failed: $error';
  }

  @override
  String autofillPresetExportFailedSnackbar(String error) {
    return 'Export failed: $error';
  }

  @override
  String autofillPresetDuplicateName(String name) {
    return '$name (Copy)';
  }

  @override
  String get autofillPartSearchHint => 'Search by part name';

  @override
  String autofillPartUnconfiguredBanner(int count, String names) {
    return '$count part(s) are not yet set up: $names (no screentone selected)\nYou can\'t close this screen until all are set up.';
  }

  @override
  String get autofillPartUnconfiguredDialogTitle =>
      'There are unconfigured parts';

  @override
  String get autofillPartUnconfiguredDialogBody =>
      'Please set up the following parts before saving.';

  @override
  String autofillPartUnconfiguredItem(String name) {
    return '• $name: No screentone selected';
  }

  @override
  String get autofillPartUnconfiguredBackButton => 'Back to setup';

  @override
  String get autofillPartEmpty => 'No parts\nTap + to add one';

  @override
  String get autofillPartToneUnselected => 'No screentone selected';

  @override
  String get autofillPartAddDialogTitle => 'Add part';

  @override
  String get autofillPartNameLabel => 'Part name';

  @override
  String get autofillPartAddButton => 'Add';

  @override
  String get autofillPartRenameDialogTitle => 'Rename part';

  @override
  String autofillPartDetailDialogTitle(String name) {
    return '$name details';
  }

  @override
  String get autofillPartFillColorLabel => 'Fill color';

  @override
  String get autofillPartSelectColorButton => 'Choose color';

  @override
  String get autofillPartOutlineLabel => 'Outline with specified color';

  @override
  String autofillPartOutlineWidthLabel(int value) {
    return 'Outline width: ${value}px';
  }

  @override
  String get autofillEyedropperFromThumbnailButton => 'Pick from image';

  @override
  String get autofillEyedropperDialogTitle => 'Pick a color from the image';

  @override
  String get autofillEyedropperDialogHint => 'Tap the image to pick a color';

  @override
  String get autofillEyedropperPickedLabel => 'Picked color';

  @override
  String get autofillEyedropperImageLoadFailedSnackbar =>
      'Couldn’t load the image.';

  @override
  String get autofillThumbnailMenuItem => 'Set thumbnail image';

  @override
  String get autofillThumbnailLoadButton => 'Load image';

  @override
  String get autofillThumbnailDeleteButton => 'Delete thumbnail image';

  @override
  String get autofillThumbnailDeleteConfirmTitle =>
      'Delete the thumbnail image?';

  @override
  String get autofillThumbnailDeleteConfirmBody =>
      'This reverts to the default part-color display (up to 4 colors).';

  @override
  String get autofillThumbnailCropDialogTitle => 'Adjust the thumbnail image';

  @override
  String get autofillThumbnailCropDialogHint =>
      'Drag to move, pinch to zoom, twist with two fingers to rotate';

  @override
  String get autofillThumbnailCropLoadFailed =>
      'Couldn’t load the image. Please try a different one.';

  @override
  String get autofillThumbnailSetSnackbar => 'Thumbnail image set';

  @override
  String get autofillPartGradientSetButton => 'Set gradient';

  @override
  String get autofillPartGradientEditButton => 'Edit gradient';

  @override
  String autofillPartFillOpacityLabel(int value) {
    return 'Opacity (fill layer): $value%';
  }

  @override
  String get autofillPartLineColorLabel => 'Line color';

  @override
  String autofillPartTraceHueLabel(int value) {
    return 'Hue: $value';
  }

  @override
  String autofillPartTraceSaturationLabel(int value) {
    return 'Saturation: $value';
  }

  @override
  String autofillPartTraceLightnessLabel(int value) {
    return 'Lightness: $value';
  }

  @override
  String autofillPartLineOpacityLabel(int value) {
    return 'Opacity (line layer): $value%';
  }

  @override
  String get autofillPartToneLabel => 'Screentone';

  @override
  String get autofillPartUseToneCheckbox => 'Use screentone';

  @override
  String get autofillPartBlendModeLabel => 'Blend mode';

  @override
  String get autofillPartApplyButton => 'Apply';

  @override
  String autofillPartGradientDialogTitle(String name) {
    return '$name gradient';
  }

  @override
  String get autofillPartGradientTypeLabel => 'Type';

  @override
  String get autofillPartGradientTypeInfo =>
      'Linear: the color changes along the angle you set. Radial center→out: colors change from the center outward. Radial out→center: colors change from the outside inward.';

  @override
  String get autofillPartGradientFeatherInfo =>
      'At 0%, the boundary between adjacent colors is sharp. At 100%, colors blend completely and smoothly all the way to the edge of the next color.';

  @override
  String get autofillLineColorModeTraceAdjustInfo =>
      'Keeps the original line color but shifts its hue, saturation, and lightness slightly. Use this when you want to keep the line art\'s shading instead of filling lines with a flat color.';

  @override
  String autofillPartGradientAngleLabel(int value) {
    return 'Angle: $value°';
  }

  @override
  String get autofillPartGradientColorLabel => 'Colors';

  @override
  String get autofillPartGradientAddColorButton => 'Add color';

  @override
  String get autofillPartGradientRemoveButton => 'Remove gradient';

  @override
  String autofillPartGradientFeatherLabel(int value) {
    return 'Blur strength: $value%';
  }

  @override
  String get autofillPartGradientDragHint =>
      'Drag the handle on the right to reorder colors';

  @override
  String autofillPartGradientStopLabel(int value) {
    return 'Position: $value%';
  }

  @override
  String get autofillPartGradientStopDragHint =>
      'Drag the ▲ markers left or right to adjust each color\'s position';

  @override
  String get saveTreeScreenTitleTree => 'Save Tree';

  @override
  String get saveTreeScreenTitleSlot => 'Save Slots';

  @override
  String get timelineExportMenuItem => 'Export';

  @override
  String get timelineExportFrameMenuItem => 'Export frame as image';

  @override
  String get timelineExportFrameDialogTitle => 'Export frame as image';

  @override
  String get timelineExportFrameDialogMessage =>
      'Save the currently displayed frame as a still image. Choose a format.';

  @override
  String get timelineExportFramePngOption => 'Save as PNG';

  @override
  String get timelineExportFrameJpegOption => 'Save as JPEG';

  @override
  String timelineExportFrameSuccessSnackbar(String fileName) {
    return 'Saved as $fileName (you can find it in the Exports tab)';
  }

  @override
  String get timelineExportFrameErrorSnackbar => 'Failed to export the frame';

  @override
  String get timelineDurationChangeMenuItem => 'Change duration';

  @override
  String get timelineCanvasSizeChangeMenuItem => 'Change canvas size';

  @override
  String get timelineDurationFramesLabel => 'Frames';

  @override
  String get timelineDurationSecondsLabel => 'Seconds';

  @override
  String get timelineDurationShrinkConfirmTitle => 'Shorten anyway?';

  @override
  String get timelineDurationShrinkConfirmBody =>
      'The frames that will be cut contain changes such as drawn content or added layers. If you continue, those frames cannot be recovered. Are you sure you want to delete them?';

  @override
  String get timelineCanvasSizeDragHint =>
      'Drag inside the frame to move it, or drag a corner to resize it (snaps near the original size)';

  @override
  String get timelineCanvasSizeAngleLabel => 'Angle';

  @override
  String get saveTreeSaveAsChildHint =>
      'This will save as a child of the selected node.';

  @override
  String get saveTreeSaveAsRootHint => 'This will save as a root node.';

  @override
  String get saveTreeCommentLabel => 'Comment (optional)';

  @override
  String get saveTreeCommentHint => 'e.g. Background done';

  @override
  String saveTreeSizeWarningSnackbar(String mb) {
    return 'Your save tree is getting large (about ${mb}MB). We recommend deleting saves you no longer need.';
  }

  @override
  String saveTreeSaveFailedSnackbar(String error) {
    return 'Save failed. Check your free storage and try again ($error)';
  }

  @override
  String get saveTreeSlotWriteTooltip => 'Save to this slot';

  @override
  String get saveTreeSlotLoadTooltip => 'Load from this slot';

  @override
  String get saveTreeSlotDeleteTooltip => 'Delete this slot';

  @override
  String saveTreeSlotSaveDialogTitle(int n) {
    return 'Save to slot $n';
  }

  @override
  String saveTreeSlotOverwriteWarning(String date) {
    return 'This will overwrite the existing data ($date).';
  }

  @override
  String get saveTreeRestoreAction => 'Restore';

  @override
  String get saveTreeTimelineActionChoiceBody =>
      'Choose whether to overwrite this save with the current content, or resume work from here.';

  @override
  String get saveTreeOverwriteAction => 'Overwrite';

  @override
  String get saveTreeOverwriteConfirmBody =>
      'The data saved at that point will be lost. Are you sure?';

  @override
  String get saveTreeResumeFromHereAction => 'Resume from here';

  @override
  String get saveTreeResumeConfirmBody =>
      'Any changes you haven\'t saved will be lost. Are you sure?';

  @override
  String get saveTreeProjectDetailResumeBody => 'Resume work from this save?';

  @override
  String get saveTreeLoadFailedSnackbar => 'Failed to load the save data';

  @override
  String saveTreeRestoredSnackbar(String name) {
    return 'Restored $name';
  }

  @override
  String saveTreeSlotLabel(int n) {
    return 'Slot $n';
  }

  @override
  String saveTreeSlotFallbackName(int n) {
    return 'Slot $n';
  }

  @override
  String get saveTreeNoDataLabel => 'No save data';

  @override
  String get saveTreeEmptyTitle => 'No save data';

  @override
  String get saveTreeEmptyHint =>
      'Tap the \"Save\" button at the top to create the first node';

  @override
  String get saveTreeNodeDefaultTitle => 'Save';

  @override
  String get saveTreeNodeDefaultName => 'Save data';

  @override
  String get saveTreeChangeDataTitle => 'Change Save Data';

  @override
  String saveTreeChangeDataTitleWithProject(String name) {
    return 'Change Save Data ($name)';
  }

  @override
  String get saveTreeChangeExceedMessage =>
      'Your current save count exceeds\nthe new save limit.\n\nPlease choose which saves to keep.';

  @override
  String saveTreeKeepableCountLabel(int n) {
    return 'Saves you can keep: $n';
  }

  @override
  String saveTreeKeepLatestButton(int n) {
    return 'Keep the latest $n';
  }

  @override
  String get saveTreeSelectDataButton => 'Choose save data';

  @override
  String saveTreeSelectedCountLabel(int selected, int limit) {
    return 'Selected: $selected / $limit';
  }

  @override
  String get saveTreeBackButton => 'Back';

  @override
  String get saveTreeNextButton => 'Next';

  @override
  String get saveTreeDiscardDialogTitle => 'Unselected save data';

  @override
  String get saveTreeArchiveOptionTitle => 'Keep as archive (recommended)';

  @override
  String get saveTreeArchiveOptionSubtitle =>
      'Automatically restored if you switch back to tree-based saving.\nUses storage space.';

  @override
  String get saveTreeDeleteOptionTitle => 'Delete permanently';

  @override
  String saveTreeDeleteOptionSubtitle(int count) {
    return 'Permanently deletes the $count unselected item(s).\nFrees up storage space.\n※ Deleted data cannot be recovered.';
  }

  @override
  String get saveTreeApplyChangeButton => 'Apply change';

  @override
  String get canvasEditMenuAutofillPresets => 'Autofill settings';

  @override
  String get canvasEditMenuAutofillPresetsSubtitle =>
      'Edit the color/screentone combinations for each part';

  @override
  String get canvasEditMenuBackgroundToggle => 'Switch background';

  @override
  String get canvasEditMenuBackgroundCurrentColor =>
      'Current: project background color (tap for transparent)';

  @override
  String get canvasEditMenuBackgroundCurrentTransparent =>
      'Current: transparent (tap for project background color)';

  @override
  String get canvasEditMenuOnionSkinSubtitle =>
      'Overlay faint previous/next frames';

  @override
  String get canvasEditMenuFilterSubtitle =>
      'Apply blur, tone curves, and more';

  @override
  String get canvasEditMenuFrameMultiSelect => 'Select multiple frames';

  @override
  String get canvasEditMenuFrameMultiSelectSubtitle =>
      'For bulk operations (e.g. applying a filter to many frames)';

  @override
  String get canvasEditMenuPressureCurve => 'Pressure Curve';

  @override
  String get canvasEditMenuPressureCurveSubtitle =>
      'Open pen input settings (shared with Settings)';

  @override
  String get canvasEditMenuMeshTransform => 'Free Transform / Mesh Warp';

  @override
  String get canvasEditMenuMeshTransformSubtitle =>
      'Transform the whole layer without selecting';

  @override
  String get meshTransformPanelTitle => 'Free Transform / Mesh Warp';

  @override
  String get meshTransformPanelHint =>
      'Drag corners or grid points with your finger (pinch two different points with two fingers to rotate or scale)';

  @override
  String get meshTransformDensityLabel => 'Grid density';

  @override
  String get meshTransformRotateLabel => 'Rotate';

  @override
  String get meshTransformScaleLabel => 'Scale';

  @override
  String get meshTransformApplyButton => 'Apply';

  @override
  String get canvasLassoEnclosedLabel => 'Fill enclosed area';

  @override
  String get canvasInvertSelectionTooltip => 'Invert selection';

  @override
  String get canvasTapToEnterTextLabel => 'Tap the canvas to enter text';

  @override
  String get canvasRulerFirstUseTip =>
      'Use the ruler to draw straight lines and clean shapes.';

  @override
  String get canvasRulerTooltip => 'Ruler';

  @override
  String get commonUndo => 'Undo';

  @override
  String get commonRedo => 'Redo';

  @override
  String get canvasSettingsMenuTooltip => 'Settings/Edit';

  @override
  String canvasFrameSelectedCount(int selected, int total) {
    return '$selected / $total frames selected';
  }

  @override
  String get canvasSelectAllButton => 'Select all';

  @override
  String get canvasDeselectAllButton => 'Deselect all';

  @override
  String get canvasSelectionFreeTransform => 'Free transform';

  @override
  String get canvasSelectionMeshTransform => 'Mesh warp';

  @override
  String get canvasSelectionRevertButton => 'Cancel';

  @override
  String get canvasSelectionRevertTooltip =>
      'Discard the transform and leave the select tool';

  @override
  String get canvasSelectionApplyButton => 'Apply';

  @override
  String get canvasSelectionApplyTooltip =>
      'Keep the transform and leave the select tool';

  @override
  String get canvasSelectionSliderMoveX => 'Move X';

  @override
  String get canvasSelectionSliderMoveY => 'Move Y';

  @override
  String get canvasSelectionSliderScale => 'Scale';

  @override
  String get canvasSelectionSliderRotate => 'Rotate';

  @override
  String get canvasApplyFilterButton => 'Apply filter';

  @override
  String get canvasShapeOff => 'Off (back to normal brush)';

  @override
  String get canvasShapeLine => 'Line';

  @override
  String get canvasShapeRect => 'Rectangle';

  @override
  String get canvasShapeCircle => 'Circle';

  @override
  String get canvasMissingMaterialsSnackbar => 'Some materials are missing';

  @override
  String get canvasResearchButton => 'Search again';

  @override
  String get canvasTextInputTitle => 'Enter Text';

  @override
  String get canvasTextEditTitle => 'Edit Text';

  @override
  String get canvasTextInputHint => 'Enter your text';

  @override
  String get canvasTextFontLabel => 'Font';

  @override
  String get canvasTextStandardFont => 'Standard font';

  @override
  String get canvasTextBold => 'Bold';

  @override
  String get canvasTextItalic => 'Italic';

  @override
  String get canvasTextVertical => 'Vertical';

  @override
  String get canvasTextHorizontal => 'Horizontal';

  @override
  String get canvasTypesettingHelpTooltip => 'About typesetting & ruby text';

  @override
  String get canvasTextLineHeight => 'Line height';

  @override
  String get canvasTextLetterSpacing => 'Letter spacing';

  @override
  String get canvasTextAlign => 'Align';

  @override
  String get canvasTextOutline => 'Outline';

  @override
  String get canvasOutlineWidthLabel => 'Width';

  @override
  String get canvasHelpRotationTitle =>
      'Half-width alphanumeric rotation (vertical only)';

  @override
  String get canvasHelpRotationBody =>
      'Letters and symbols are automatically rotated 90° when displayed.';

  @override
  String get canvasHelpTatechuyokoTitle => 'Tate-chu-yoko (vertical only)';

  @override
  String get canvasHelpTatechuyokoBody =>
      'Two consecutive half-width digits automatically fit side by side within the height of one character (e.g. 12).';

  @override
  String get canvasHelpRubyTitle => 'Ruby text (furigana)';

  @override
  String canvasHelpRubyBody(String example) {
    return 'Typing something like \"$example\" shows small reading annotations above the base characters (in horizontal text) or to their right (in vertical text). It works in both directions, but text containing ruby text won\'t auto-wrap in horizontal mode (manual line breaks only).';
  }

  @override
  String get layerPanelTitle => 'Layers';

  @override
  String get layerPanelHelpTooltip => 'Help';

  @override
  String get layerPanelSearchHint => 'Search by layer name';

  @override
  String get layerPanelSelectAll => 'Select all';

  @override
  String get layerPanelDeselectAll => 'Deselect all';

  @override
  String get layerPanelNewLayerButton => 'Normal layer';

  @override
  String get layerPanelNewFolderButton => 'New folder';

  @override
  String get layerPanelImportImageButton => 'Import image';

  @override
  String layerPanelDefaultLayerName(int n) {
    return 'Layer$n';
  }

  @override
  String layerPanelDefaultFolderName(int n) {
    return 'Folder$n';
  }

  @override
  String layerPanelDefaultLineartName(int n) {
    return 'Lineart$n';
  }

  @override
  String layerPanelDefaultAutofillName(int n) {
    return 'AutoFill$n';
  }

  @override
  String layerPanelDefaultCommonName(int n) {
    return 'Common$n';
  }

  @override
  String layerPanelDefaultSelectionName(int n) {
    return 'Selection$n';
  }

  @override
  String get layerPanelClippingBadge => 'Clipping';

  @override
  String get layerPanelAddTooltip => 'Add other';

  @override
  String get layerPanelAutofillMarkTooltip =>
      'The lineart was updated. Tap to bring the auto-fill up to date.';

  @override
  String get layerPanelRangeAllFrames => 'All frames';

  @override
  String get layerPanelRangeCurrentScene => 'Current scene';

  @override
  String get layerPanelRangeSceneSpecified => 'Specific scene';

  @override
  String layerPanelRangeFrameSpan(int start, int end) {
    return '$start–$end';
  }

  @override
  String get layerPanelMenuFrameRangeChange => 'Change frame range';

  @override
  String get layerPanelMenuRangeChange => 'Change display range';

  @override
  String get layerPanelMenuPartAssign => 'Assign part';

  @override
  String get layerPanelMenuRunAutofill => 'Run auto-fill';

  @override
  String get layerPanelMenuOrphanFill => 'Fill with the latest color';

  @override
  String get layerPanelMenuOrphanFillSubtitle =>
      'No matching lineart layer was found, so only the color will be updated';

  @override
  String get layerPanelMenuReplaceMaterial => 'Replace material';

  @override
  String layerPanelDeleteConfirmTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get layerPanelDeleteConfirmBody =>
      'This material will be removed from every frame within its display range.';

  @override
  String layerPanelCommonDeleteMidDialogTitle(String name) {
    return 'Change the display range of $name?';
  }

  @override
  String get layerPanelCommonDeleteMidDialogBody =>
      'A shared layer\'s display range can only be a single continuous span, so it can\'t be deleted from a frame in the middle of that range. Choose whether to keep the part before or after this frame instead.';

  @override
  String get layerPanelCommonDeleteKeepBeforeButton => 'Keep before this frame';

  @override
  String get layerPanelCommonDeleteKeepAfterButton => 'Keep after this frame';

  @override
  String get layerPanelRangeDialogTitle => 'Display range';

  @override
  String get layerPanelRangeStartFrameLabel => 'Start frame';

  @override
  String get layerPanelRangeEndFrameLabel => 'End frame';

  @override
  String get layerPanelRangeTilde => '–';

  @override
  String get layerPanelRangeUseCurrentButton => 'Use current range';

  @override
  String get layerPanelRangeTargetSceneLabel => 'Target scene';

  @override
  String get layerPanelRangeFrameRangeLabel => 'Specific frame range';

  @override
  String get layerPanelMenuNormalLayer => 'Normal layer';

  @override
  String get layerPanelMenuCommonLayer => 'Common layer';

  @override
  String get layerPanelMenuLineartLayer => 'Auto-fill lineart layer';

  @override
  String get layerPanelMenuAutofillLayer => 'Auto-fill layer';

  @override
  String get layerPanelMenuSelectionLayer => 'Selection layer';

  @override
  String get layerPanelOpacityLabel => 'Opacity';

  @override
  String get layerPanelLockLabel => 'Lock';

  @override
  String get layerPanelOpacityLockLabel => 'Lock opacity';

  @override
  String get layerPanelClippingDescription =>
      'Draw only within the opaque area of the layer below';

  @override
  String get layerPanelConvertToCommonLabel => 'Change to common layer';

  @override
  String get layerPanelConvertOption1Title => 'Make the current layer common';

  @override
  String get layerPanelConvertOption1Subtitle =>
      'Sets only this layer as a common layer';

  @override
  String get layerPanelConvertOption2Title =>
      'Merge the visible layers into a common layer';

  @override
  String get layerPanelConvertOption2Subtitle =>
      'Creates a common layer from the merged result of all currently visible layers';

  @override
  String get layerPanelCommonRangeTitle => 'Common layer range';

  @override
  String get layerPanelHelpDialogTitle => 'About layers';

  @override
  String get layerPanelHelpBlendModeBody =>
      'Changes how the layer is composited, such as Multiply, Screen, or Overlay.';

  @override
  String get layerPanelHelpClippingBody =>
      'Draws only within the opaque pixel area of the layer below. Use this to control the drawing area.';

  @override
  String get layerPanelCommonLayerLabel => 'Common layer';

  @override
  String get layerPanelHelpCommonLayerBody =>
      'A layer whose content is shared across multiple frames. You can set which frame range it appears in.';

  @override
  String get layerPanelAutofillMethodTitle => 'Auto-fill method';

  @override
  String get layerPanelAutofillNoLineartSnackbar =>
      'No matching auto-fill lineart layer was found.';

  @override
  String get layerPanelAutofillNote1 =>
      '✳ Either option is fine the first time you run auto-fill in this project.';

  @override
  String get layerPanelAutofillNote2 =>
      '✳ If no auto-fill layer exists yet, the area will be judged from scratch either way.';

  @override
  String get layerPanelAutofillRepaintTitle => 'Repaint';

  @override
  String get layerPanelAutofillRepaintHint =>
      'Recommended if the auto-fill shape was accidentally changed';

  @override
  String get layerPanelAutofillRepaintNote =>
      '✳ Judges the area from scratch and repaints it. The current auto-fill layer\'s shape will be discarded.';

  @override
  String get layerPanelAutofillColorUpdateTitle => 'Update color';

  @override
  String get layerPanelAutofillColorUpdateHint =>
      'Recommended if the auto-fill shape was adjusted manually';

  @override
  String get layerPanelAutofillColorUpdateNote =>
      '✳ Locks opacity and fills with the latest color. The current auto-fill layer\'s shape is kept.';

  @override
  String get layerPanelExecuteButton => 'Run';

  @override
  String get layerPanelAutofillPartMissingSnackbar =>
      'No part is assigned. Assign one from “Assign part”.';

  @override
  String get layerPanelAutofillPresetMissingSnackbar =>
      'No matching part was found in the autofill setting.';

  @override
  String get layerPanelOrphanFillSuccessSnackbar =>
      'No matching lineart layer was found, so it was filled with the latest color instead.';

  @override
  String get layerPanelOrphanFillFailSnackbar =>
      'Couldn\'t process this: no part is assigned, or there\'s no fill shape.';

  @override
  String get layerPanelAutofillUpdateHelpTitle => 'Auto-fill update mark';

  @override
  String get layerPanelAutofillUpdateHelpBody =>
      'The current auto-fill is out of date. Tap it to update.';

  @override
  String layerPanelReplaceMaterialSuccessSnackbar(String name) {
    return 'Material replaced: $name';
  }

  @override
  String layerPanelImportImageSuccessSnackbar(String name) {
    return 'Image imported: $name';
  }

  @override
  String layerPanelCopySuffix(String name) {
    return '$name copy';
  }

  @override
  String get timelineFullscreenPreviewCloseTooltip =>
      'Close fullscreen preview';

  @override
  String get timelineDefaultProjectName => 'Project name';

  @override
  String get timelinePreviewPlaceholder => 'Preview';

  @override
  String get timelinePreviewFullscreenTip =>
      'Tap to show the preview fullscreen. Handy for checking the finished result.';

  @override
  String get timelinePreviewFullscreenTooltip => 'Show preview fullscreen';

  @override
  String get timelineAddVideoTooltip => '+ Video';

  @override
  String get timelineAddAudioTooltip => '+ Audio';

  @override
  String get timelineEffectFilterLabel => 'Effect filters';

  @override
  String get timelineAddCameraKfTooltip => 'Add camera keyframe';

  @override
  String get timelineAddWatermarkTooltip => '+ Watermark';

  @override
  String get timelineWatermarkNotRegisteredTitle => 'No watermark registered';

  @override
  String get timelineWatermarkNotRegisteredBody =>
      'Register an image or text watermark in advance from \"Watermark\" in Settings.';

  @override
  String get timelineOpenSettingsButton => 'Open settings';

  @override
  String get timelineWatermarkSelectTitle => 'Select a watermark';

  @override
  String timelineWatermarkAddedSnackbar(String name) {
    return 'Watermark added (shown on every frame): $name';
  }

  @override
  String get timelineWatermarkEditTitle => 'Edit watermark';

  @override
  String get timelineWatermarkAngleLabel => 'Angle';

  @override
  String get timelineWatermarkSizeLabel => 'Size';

  @override
  String get timelineWatermarkOpacityLabel => 'Opacity';

  @override
  String get timelineWatermarkLoopLabel => 'Always show (loop)';

  @override
  String get timelineWatermarkLoopSubtitle =>
      'When off, shown only on the current scene';

  @override
  String get timelineConfirmButton => 'Confirm';

  @override
  String get timelineClipSelectDoneButton => 'Done';

  @override
  String get timelineClipOverlapDialogTitle => 'Overlaps an existing clip';

  @override
  String get timelineClipOverlapDialogBody =>
      'The paste target overlaps an existing clip. How would you like to place it?';

  @override
  String get timelineClipOverlapPlaceBefore => 'Place before';

  @override
  String get timelineClipOverlapPlaceAfter => 'Place after';

  @override
  String get timelineClipOverlapPlaceNewRow => 'Overlap it (add a new row)';

  @override
  String get timelineSceneRenameTitle => 'Rename scene';

  @override
  String get timelineSceneDeleteMenuItem => 'Delete scene';

  @override
  String get timelineDurationLimitTitle => 'Length limit reached';

  @override
  String get timelineDurationLimitBodyFree =>
      'Free members are limited to 90 seconds of video. Adding or duplicating more frames would exceed this limit, so the action can\'t be completed. Upgrade to Premium for up to 2 hours.';

  @override
  String get timelineDurationLimitBodyPremium =>
      'This would exceed the Premium limit (up to 2 hours), so no more frames can be added or duplicated.';

  @override
  String timelineSceneDeleteConfirmTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get timelineSceneDeleteConfirmBody =>
      'All data in the scene will be deleted, including every frame, common layers, video materials, image materials, and watermarks.';

  @override
  String timelineSceneMultiDeleteConfirmTitle(int count) {
    return 'Delete the $count selected scenes?';
  }

  @override
  String get timelineAutofillUpdateHelpBody =>
      'This scene/frame contains an auto-fill layer that isn\'t up to date. Tap the layer in the layer panel to update it.';

  @override
  String get timelineFrameTrackLabel => 'Frame';

  @override
  String get timelineTrackRowRenameTitle => 'Rename row';

  @override
  String get timelineCameraTrackLabel => 'Camera';

  @override
  String get timelineRangeSceneFixed => 'Fixed scene';

  @override
  String get timelineEndCardDefaultLogoLabel => 'NIARIM logo';

  @override
  String get timelineEndCardHiddenLabel => 'Hidden';

  @override
  String get timelineEndCardTrackLabel => 'End Card Track';

  @override
  String get timelineMarkerTrackLabel => 'Timestamps';

  @override
  String timelineMarkerAddDialogTitle(int n) {
    return 'Add timestamp at F$n';
  }

  @override
  String timelineMarkerEditDialogTitle(int n) {
    return 'Timestamp: F$n';
  }

  @override
  String get timelineMarkerCommentHint =>
      'Comment (e.g. mouth flap \"ah\" here)';

  @override
  String timelineAddClipDialogTitle(String trackName) {
    return 'Add $trackName clip';
  }

  @override
  String get timelineClipLabelFieldLabel => 'Label';

  @override
  String get timelineClipStartLabel => 'Start:';

  @override
  String get timelineClipLengthLabel => 'Length:';

  @override
  String get timelineAutofillNote2 =>
      '✳ If only an auto-fill layer exists (with no lineart), the area will be judged from scratch either way.';

  @override
  String get timelineAutofillTargetLabel => 'Target';

  @override
  String get timelineAutofillScopeCurrentFrame => 'Current frame only';

  @override
  String get timelineAutofillScopeCurrentScene =>
      'Current scene (all frames in this scene)';

  @override
  String get timelineAutofillScopeAllScenes => 'All frames (entire project)';

  @override
  String get timelineAutofillProgressTitle => 'Running auto-fill';

  @override
  String timelineAutofillProgressSubtitle(int count) {
    return '$count frames';
  }

  @override
  String timelineAutofillCompleteSnackbar(int count) {
    return 'Auto-fill complete ($count processed)';
  }

  @override
  String get timelineEffectTypeFade => 'Fade';

  @override
  String get timelineEffectTypeGaussianBlur => 'Gaussian blur';

  @override
  String get timelineEffectTypeLensBlur => 'Lens blur';

  @override
  String get timelineEffectTypeMosaic => 'Mosaic';

  @override
  String get timelineEffectTypeChromaticAberration => 'Chromatic aberration';

  @override
  String get timelineEffectTypeNoise => 'Noise';

  @override
  String get timelineEffectTypeSepia => 'Sepia';

  @override
  String get timelineEffectTypeAnimeStyle => 'Anime Style';

  @override
  String get timelineEffectTypeRetroAnime => 'Retro Anime';

  @override
  String get timelineEffectTypeCrt => 'CRT';

  @override
  String get timelineEffectTypeAnimatedNoise => 'Animated Noise';

  @override
  String get timelineEffectTypeRain => 'Rain';

  @override
  String get timelineEffectFilterEmptyState =>
      'No filters yet\nTap + Add to add one';

  @override
  String get timelineRangeStartLabel => 'Start';

  @override
  String get timelineRangeEndLabel => 'End';

  @override
  String get timelineEffectSizeLabel => 'Size';

  @override
  String get timelineEffectStrengthLabel => 'Strength';

  @override
  String get timelineEffectAmountLabel => 'Amount';

  @override
  String get timelineEffectGrainSizeLabel => 'Grain size';

  @override
  String get timelineEffectRainIntensityLabel => 'Intensity';

  @override
  String get timelineEffectRainSpeedLabel => 'Speed';

  @override
  String get timelineEffectRainSizeLabel => 'Drop size';

  @override
  String get timelineEffectWindAngleLabel => 'Wind angle';

  @override
  String get timelineColorLabel => 'Color';

  @override
  String get timelineColorBlack => 'Black';

  @override
  String get timelineColorWhite => 'White';

  @override
  String get timelineColorCustom => 'Custom';

  @override
  String get timelineFadeColorDialogTitle => 'Fade color';

  @override
  String get timelineAddFilterDialogTitle => 'Add filter';

  @override
  String get timelineClipVolumeLabel => 'Volume';

  @override
  String get timelineClipFadeInLabel => 'Fade in';

  @override
  String get timelineClipFadeOutLabel => 'Fade out';

  @override
  String get timelineClipUseStartLabel => 'Trim start F';

  @override
  String get timelineClipUseEndLabel => 'Trim end F';

  @override
  String timelineCameraKfTitle(int n) {
    return 'Camera KF: F$n';
  }

  @override
  String get timelineCameraMoveXLabel => 'X move';

  @override
  String get timelineCameraMoveYLabel => 'Y move';

  @override
  String get timelineCameraZoomLabel => 'Zoom';

  @override
  String get timelineCameraRotationLabel => 'Rotation';

  @override
  String get layerPanelKeyframeLabel => 'Animation (keyframes)';

  @override
  String layerKeyframeSheetTitle(String name) {
    return 'Keyframes for $name';
  }

  @override
  String get layerKeyframeSheetDesc =>
      'Set this layer\'s position, scale, and rotation per frame; the keyframes are interpolated automatically. The layer\'s artwork itself doesn\'t change.';

  @override
  String layerKeyframeAddAtCurrentFrame(int n) {
    return 'Add at current frame (F$n)';
  }

  @override
  String get layerKeyframeEmpty =>
      'No keyframes yet. Add one with the button above.';

  @override
  String get layerKeyframeScaleShort => 'Scale';

  @override
  String get layerKeyframeRotationShort => 'Rot';

  @override
  String layerKeyframeEditTitle(int n) {
    return 'Keyframe: F$n';
  }

  @override
  String get layerKeyframeFrameLabel => 'Frame';

  @override
  String get layerKeyframeScaleLabel => 'Scale';

  @override
  String get layerKeyframeRotationLabel => 'Rotation';

  @override
  String get layerKeyframeEasingLabel => 'Transition to next keyframe';

  @override
  String get layerKeyframeEasingLinear => 'Linear';

  @override
  String get layerKeyframeEasingEaseIn => 'Ease in (starts slow)';

  @override
  String get layerKeyframeEasingEaseOut => 'Ease out (ends slow)';

  @override
  String get layerKeyframeEasingEaseInOut => 'Ease in and out';

  @override
  String get layerKeyframeEasingBounceOut => 'Bounce';

  @override
  String get layerPanelGroupTooltip => 'Group';

  @override
  String get layerPanelShowSelectedTooltip => 'Show all selected layers';

  @override
  String get layerPanelHideSelectedTooltip => 'Hide all selected layers';

  @override
  String get layerPanelGroupDefaultName => 'New Group';

  @override
  String layerPanelGroupMembershipLabel(String name) {
    return 'Group: $name';
  }

  @override
  String get layerPanelGroupLeaveAction => 'Leave';

  @override
  String frameStripHoldDialogTitle(int n) {
    return 'F$n hold cells';
  }

  @override
  String get frameStripFrameListModeLabel => 'Frames';

  @override
  String get frameStripTimelineModeLabel => 'Timeline';

  @override
  String get progressDialogAdLoading => 'Loading ad…';

  @override
  String get adMockPlaceholderLabel => 'Ad banner (placement trial mock)';

  @override
  String get adMediumRectangleMockPlaceholderLabel =>
      'Medium rectangle ad (300×250 placement mock)';

  @override
  String get progressDialogTipLabel => 'Tip';

  @override
  String get premiumBannerRegisterButton => 'Upgrade to Premium';

  @override
  String get licenseTermsArt1Title => 'Article 1 (Application)';

  @override
  String get licenseTermsArt1Body =>
      'These Terms of Service (the \"Terms\") set forth the conditions of use for the app \"NIARIM\" (the \"App\"). By using the App, you agree to these Terms. Use of the App constitutes agreement to these Terms.';

  @override
  String get licenseTermsArt2Title =>
      'Article 2 (Eligibility to Use / Supported Environment)';

  @override
  String get licenseTermsArt2Body =>
      '1. For details on the App\'s supported OS versions and recommended operating environments, please refer to the relevant distribution store and the information displayed within the App.\n2. The App aims to run comfortably on devices with a wide range of performance levels; however, depending on your device\'s performance, OS version, available storage, settings, and other conditions of use, some features may be limited or may not function correctly.\n3. Minors must obtain the consent of a parent or other legal guardian before using the App, including its paid features.';

  @override
  String get licenseTermsArt3Title => 'Article 3 (Prohibited Acts)';

  @override
  String get licenseTermsArt3Body =>
      'When using the App, users must not engage in any of the following acts:\n・Acts that violate laws, regulations, or public order and morals\n・Acts that infringe the copyrights, trademark rights, or other intellectual property rights, portrait rights, privacy, or other rights or interests of the App, the developer, or third parties\n・Decompiling, disassembling, reverse engineering, or otherwise analyzing the App (except where permitted by law)\n・Unauthorized modification, duplication, or redistribution of the App\n・Unauthorized access to the App or the platform on which it is provided, imposing excessive load, or otherwise interfering with its normal operation\n・Any other act that the developer reasonably determines to be inappropriate';

  @override
  String get licenseTermsArt4Title => 'Article 4 (Rights to Created Content)';

  @override
  String get licenseTermsArt4Body =>
      '1. Copyright and other rights relating to illustrations, animations, and other content created by users using the App (including project data, exported images, videos, etc.; hereinafter \"Created Content\") belong, to the extent permitted by law, to the user or third party who holds rights in such content.\n2. The App does not provide any function to transmit, collect, or synchronize Created Content to the developer\'s servers. Project data is, in principle, stored only on the user\'s device (see Article 12 for the handling that applies when a user chooses to post Created Content using the Work Plaza feature).\n3. Regardless of whether the free version or the premium version is used to create it, the developer will not restrict commercial use of Created Content based on the App\'s usage fee or edition (the differences between the free and premium versions are limited to functional aspects such as the display of the end card and the upper limit on export time).\n4. Notwithstanding the preceding paragraph, fonts, images, materials, and other items that users add to the App and for which third parties hold rights are subject to the respective terms of use described in Article 5.';

  @override
  String get licenseTermsArt5Title =>
      'Article 5 (Bundled Fonts and Added Materials)';

  @override
  String get licenseTermsArt5Body =>
      '1. The fonts and other materials bundled with the App are used in accordance with the license terms listed on this screen under \"About Fonts Used.\"\n2. Regarding the rights relating to fonts, images, screentones, stamps, and other materials that a user has additionally registered or loaded into the App, the user is responsible for obtaining any necessary rights or permissions and using them lawfully.\n3. If a dispute arises with a third party arising from a user\'s use of third-party materials, the developer bears no responsibility for it, except where legally required to do so.';

  @override
  String get licenseTermsArt6Title => 'Article 6 (Premium Features / Billing)';

  @override
  String get licenseTermsArt6Body =>
      '1. In addition to features available free of charge, the App offers premium features that become available through in-app purchases (a monthly plan, an annual plan, or other premium plans).\n2. The price, content, purchase method, and other conditions of the premium features are as displayed within the App or on the distribution store at the time of purchase.\n3. Cancellations, refunds, and other matters relating to payment after purchase are governed by the rules of Google Play or the payment platform you use. However, where the law provides otherwise, such provisions shall apply.\n4. The developer may change the content of the premium features for reasonable grounds, such as changes in law, technical necessity, or improvements to the App. Where a significant change is made, the developer will provide advance notice within the App or by other appropriate means whenever reasonably possible.';

  @override
  String get licenseTermsArt7Title => 'Article 7 (Advertising)';

  @override
  String get licenseTermsArt7Body =>
      '1. In the free version, advertisements may be displayed through third-party advertising delivery services.\n2. The acquisition, use, and other handling of information by advertising providers is governed by the privacy policy of each respective advertising provider.';

  @override
  String get licenseTermsArt8Title => 'Article 8 (Handling of Information)';

  @override
  String get licenseTermsArt8Body =>
      '1. The App does not provide any function to transmit or collect to the developer\'s servers the illustrations, animations, and other content, or project data, created by users. These are, in principle, stored only on the user\'s device, and because the developer has no function to store this content on its own, there is no concept of a retention period on the developer\'s side.\n2. The handling of user information — including information collected by third-party services incorporated into the App (such as advertising delivery and in-app purchases) — is governed by the separately established Privacy Policy.\n3. If you uninstall the App, data stored on your device (projects, settings, added fonts, etc.) will be deleted.';

  @override
  String get licenseTermsArt9Title =>
      'Article 9 (Suspension, Modification, and Termination of Provision)';

  @override
  String get licenseTermsArt9Body =>
      '1. The developer may temporarily suspend the provision of all or part of the App when performing maintenance, updates, or corrections to the App, when a failure occurs in the provision infrastructure, or for other unavoidable reasons.\n2. The developer may change the content of the App or terminate its provision as necessary.\n3. In the cases described in the preceding two paragraphs, the developer will give notice in advance, where possible, within the App or by other appropriate means, except in urgent cases.\n4. Except where required by law, the developer bears no responsibility for any damage incurred by users as a result of changes, suspension, or termination under this Article.';

  @override
  String get licenseTermsArt10Title => 'Article 10 (Disclaimer)';

  @override
  String get licenseTermsArt10Body =>
      '1. The developer does not warrant that the App is free of factual or legal defects (including safety, reliability, accuracy, completeness, fitness for a particular purpose, and the absence of bugs or malfunctions).\n2. Users shall use the App at their own responsibility. Data may be lost due to device malfunction, misoperation, OS updates, or other circumstances; users are therefore recommended to make regular backups of work in progress using the export and share functions, among others.\n3. Except to the extent permitted by law, the developer bears no responsibility for damage incurred by users as a result of using the App. However, this does not apply where the developer is guilty of willful misconduct or gross negligence, and even in that case, the developer\'s liability for damages is limited to ordinary direct damages, up to the amount actually paid by the user in connection with the App during the preceding one year (or JPY 0 if used free of charge).';

  @override
  String get licenseTermsArt11Title => 'Article 11 (Amendment of These Terms)';

  @override
  String get licenseTermsArt11Body =>
      '1. The developer may amend these Terms in the event of a change in applicable laws, a change in the content of the App, or other circumstances the developer deems necessary.\n2. When amending these Terms, the developer will give advance notice of the content of the amendment and its effective date, within the App or by other appropriate means.\n3. The amended Terms will apply from the effective date referred to in the preceding paragraph, to the extent permitted by law.';

  @override
  String get licenseTermsArt12Title =>
      'Article 12 (Work Plaza: Community Posting Feature)';

  @override
  String get licenseTermsArt12Body =>
      '1. The App optionally provides a feature that lets users post animation works they have created, via their own Google account, to YouTube, and publish and browse them on \"the Work Plaza\" (the \"Community Feature\"). Browsing and creating works is possible without using the Community Feature.\n2. The video files themselves are stored on YouTube, not on the developer\'s servers. However, the information needed to identify and display posted works (YouTube video ID, title, statistics, report information, etc.) and the NIARIM User ID issued for use of the posting, reporting, and blocking features (an identifier issued within the App, separate from the Google account) are managed on the developer\'s servers.\n3. Posting works, reporting, and blocking other users under the Community Feature require the user to be signed in with a Google account.\n4. There is a daily limit on the number of works that can be posted (the limit differs between free members and Premium members). This limit may be changed for operational reasons.\n5. If a user believes another user\'s posted work violates the law or public order and morals, or may fall under any item of Article 3, the user may report it to the developer through the App\'s reporting feature. After reviewing a report, the developer may take necessary measures, such as hiding the work from listings, for reasonable cause. False reports and abuse of the reporting feature are prohibited.\n6. If a user deletes a post, or disconnects their Google account from the App, the corresponding YouTube video may be deleted. If a video is made private or deleted on YouTube\'s side, the work will also stop being displayed on the Work Plaza.\n7. Use of the Community Feature is subject to YouTube\'s Terms of Service and Community Guidelines, in addition to these Terms.\n8. Users may follow other users and may bookmark or repost other users\' works. Your following / follower lists and the list of works you have bookmarked are private by default; whether to make them public is your choice within the App. Your following and follower counts are displayed regardless of that setting.\n9. Tags attached to a work may be added or removed by users other than the poster. A poster may lock the tags on their own work to prohibit editing by other users. Users must not attach tags that defame others, tags unrelated to the content of the work, or otherwise inappropriate tags. The developer may remove inappropriate tags.\n10. The developer displays notifications in the App\'s notification list, for example when you are followed. If you have permitted notifications on your device, push notifications may be sent. Notifications can be disabled from the App\'s settings or from your device settings.\n11. Users must not use the Community Feature to harass other users, for advertising or solicitation, or for any other purpose outside its intended purpose (publishing and viewing works). If you use the blocking feature, works by the user you blocked will no longer appear in your listings.';

  @override
  String get licenseTermsArt13Title =>
      'Article 13 (Governing Law / Jurisdiction)';

  @override
  String get licenseTermsArt13Body =>
      '1. These Terms shall be governed by and construed in accordance with the laws of Japan.\n2. In the event a dispute arises in connection with the App, the district court or summary court having jurisdiction over the developer\'s place of business, depending on the amount in dispute, shall have exclusive agreed jurisdiction as the court of first instance.';

  @override
  String get privacyPolicyArt1Title => 'Article 1 (Purpose of This Policy)';

  @override
  String get privacyPolicyArt1Body =>
      'This Privacy Policy (the \"Policy\") sets out how information is handled in the app \"NIARIM\" (the \"App\"). For the general terms of use of the App, please refer separately to the \"Terms of Service / License\" screen.';

  @override
  String get privacyPolicyArt2Title =>
      'Article 2 (Data the App Does Not Collect)';

  @override
  String get privacyPolicyArt2Body =>
      'The App does not provide any function to transmit, collect, or store on the developer\'s servers the illustrations, animations, and other content created by users (including project data, exported images, videos, etc.; the same applies hereinafter). This data is, in principle, stored only on the user\'s device (the App does not include a cloud sync feature). Because the developer has no function to store this content on its own, there is no concept of a retention period on the developer\'s side. Data stored on your device can be deleted at any time using the App\'s deletion features, and if you uninstall the App, data stored on your device — including projects, settings, and added fonts — will also be deleted (for the handling of information when a user chooses to post a work using the Work Plaza feature, see Article 7).';

  @override
  String get privacyPolicyArt3Title =>
      'Article 3 (Information Collected by Third-Party Services)';

  @override
  String get privacyPolicyArt3Body =>
      'The App incorporates the following third-party services, and each service provider may collect information to the extent necessary to provide its respective service. The developer of the App has not implemented any function to independently acquire or store this information (the handling of information collected by each service is governed by that service provider\'s own privacy policy).\n\n[Advertising Delivery (Google AdMob)]\nIn the free version, advertisements are delivered through Google AdMob. For purposes such as ad delivery, effectiveness measurement, and fraud prevention, the Advertising ID and other device information may be collected and used by Google or its affiliated companies. For details on the collection and use of this information, please refer to Google\'s Privacy Policy (https://policies.google.com/privacy). You can reset your Advertising ID or disable personalized ads from your device settings (e.g., \"Privacy\" in the Android Settings app). If you are located in the European Economic Area (EEA), the United Kingdom, or Switzerland, you can choose your ad personalization consent settings via a consent form shown at launch, and change this choice at any time using the \"Manage ad consent settings\" button at the bottom of this screen.\n\n[In-App Purchases (Google Play Billing)]\nPurchases of premium features are made through Google Play\'s payment system. The developer does not directly acquire or hold payment information such as credit card numbers. The handling of payment-related information is governed by Google Play\'s rules.\n\n[Downloading Additional Fonts (GitHub)]\nCommunication with GitHub (GitHub, Inc.), the distributor of the font files, occurs only when you choose to download an additional font from \"Font Management\" in the settings screen. It does not occur when the app starts or during normal use. Only information required for the request (such as your IP address and which font file is requested) is sent; no artwork data or information identifying you is sent. Handling of the information obtained is governed by the GitHub Privacy Statement (https://docs.github.com/site-policy/privacy-policies/github-privacy-statement).\n\n[Crash Analytics / Usage Analytics]\nThe App does not currently incorporate any SDK for crash analytics or usage analytics. If such services are introduced in the future, this Policy will be updated and announced within the App.';

  @override
  String get privacyPolicyArt4Title =>
      'Article 4 (Cookies and Other Tracking Technologies)';

  @override
  String get privacyPolicyArt4Body =>
      'The App itself does not use cookies, but the advertising delivery service referred to in Article 3 (Google AdMob) may use similar identification technologies (such as the Advertising ID) for ad delivery and effectiveness measurement.';

  @override
  String get privacyPolicyArt5Title =>
      'Article 5 (Children\'s Personal Information)';

  @override
  String get privacyPolicyArt5Body =>
      'The App is not intentionally designed to collect information primarily targeting children under the age of 13. Parents and guardians should consider disabling personalized ads from their device settings as needed when their children use the App.';

  @override
  String get privacyPolicyArt6Title =>
      'Article 6 (Cross-Border Transfer of Information)';

  @override
  String get privacyPolicyArt6Body =>
      'The third-party services referred to in Article 3 (Google AdMob, Google Play Billing) may process data on servers operated by Google in various locations around the world. The handling of such data is governed by the privacy policy of each respective service.';

  @override
  String get privacyPolicyArt7Title =>
      'Article 7 (Handling of Information in the Work Plaza: Community Posting Feature)';

  @override
  String get privacyPolicyArt7Body =>
      '1. Only when a user chooses, of their own accord, to use the \"the Work Plaza\" feature (Article 12 of the Terms of Service), the developer manages the following information on its servers:\n・Information needed to identify and display a posted work (YouTube video ID, title, statistics, posting date and time, tags, etc.)\n・The NIARIM User ID issued for use of features such as posting, reporting, blocking, following, and bookmarking (an identifier issued within the App, separate from the Google account)\n・Public information about the linked YouTube channel (channel name and channel icon image URL). This is copied to and retained on the developer\'s servers in order to display the poster\'s name and icon\n・The content of any report submitted using the reporting feature, and the reporting user\'s NIARIM User ID\n・The NIARIM User ID of any user you block\n・The NIARIM User ID of any user you follow, and your following and follower counts\n・The IDs of works you bookmark and the date and time of each bookmark\n・The IDs of works you repost and the date and time of each repost\n・Tags attached to a work (see paragraph 4)\n・If you enable push notifications, your device token (an identifier issued by your device to identify the destination of a notification; used solely to send notifications)\n2. The video file itself is stored on YouTube, not on the developer\'s servers.\n3. The information described in the preceding two paragraphs is used only for the purposes of providing the Community Feature (displaying listings, rankings and search results, responding to reports, managing posting limits, reflecting follows, bookmarks and reposts, sending notifications, etc.). The developer does not provide this information to third parties for advertising purposes.\n4. Tags may be added or removed by users other than the poster (a poster may lock the tags on their own work to prohibit editing). Tags are public on the Work Plaza, and the identity of the user who added a tag is not displayed.\n5. The following information is private by default and is shown to other users only if you switch it to public within the App:\n・The list of works you have bookmarked\n・Your following / follower lists\nYour following and follower counts (the numbers themselves) are always displayed regardless of this setting.\n6. If you make a posted work private or delete it, that work will no longer appear in the Work Plaza listings or rankings. If you wish to have the records on the developer\'s servers deleted, please contact us using the channel described in Article 9.\n7. If a user does not use the Community Feature, no handling of information under this Article occurs. (In line with the principle in Article 2, nothing is transmitted to the developer\'s servers.)';

  @override
  String get privacyPolicyArt8Title => 'Article 8 (Changes to This Policy)';

  @override
  String get privacyPolicyArt8Body =>
      'The developer may change this Policy in the event of a change in applicable laws, a change in the content of the App, or other circumstances the developer deems necessary. When changing this Policy, the developer will give advance notice of the content of the change and its effective date, within the App or by other appropriate means.';

  @override
  String get privacyPolicyArt9Title => 'Article 9 (Contact)';

  @override
  String get privacyPolicyArt9Body =>
      'If you have any inquiries regarding this Policy, please contact us using the information below.\n(Developer contact: Not yet set — please fill in an email address or other contact information before publishing.)';

  @override
  String get privacyPolicyAdConsentButton => 'Manage ad consent settings';

  @override
  String get tipsPcDexLayoutTitle =>
      'Wide screens auto-switch to the full PC Mode (DeX) layout';

  @override
  String get tipsPcDexLayoutDesc =>
      'On a Chromebook, a tablet with a keyboard, Samsung DeX, or any wide-screen setup, the app automatically switches to a professional docked-panel layout. You can also force Always PC Mode or Always Mobile Mode from Workspace Settings, which is handy when connecting to an external display.';

  @override
  String get workspaceTimelineSection => 'Timeline display';

  @override
  String get workspaceTimelineHint =>
      'Adjust the height of each video/audio track row in 5 steps. You can also pinch to temporarily zoom the frame width on the timeline.';

  @override
  String get workspaceTimelineTrackHeightLabel => 'Track height';

  @override
  String get workspaceTimelinePreviewLabel => 'Preview';

  @override
  String get workspaceEndCardSection => 'End Card';

  @override
  String get workspaceEndCardHint =>
      'The end card is the app\'s own logo shown automatically at the end of every video. Free members can\'t change this. Premium members only: turning this on makes the end card start out hidden (removed) the next time you open the timeline. This setting automatically turns back off if your premium subscription lapses.';

  @override
  String get workspaceEndCardDefaultHiddenTitle =>
      'Hide the end card by default (Premium only)';

  @override
  String get tipsTransparentColorTitle =>
      'Transparent is not just an eraser, use it like a regular pen color';

  @override
  String get tipsTransparentColorDesc =>
      'Selecting transparent lets you erase with any tool: brush, lasso, shapes, whatever you like. Use your brush pressure and smoothing to round off edges precisely, or use a gradient brush to fade an edge softly into transparency, subtle effects the eraser tool alone cannot achieve.';

  @override
  String get tipsQuickToolVariantTitle =>
      'The quick-tool slot can hold brush or size variants, not just different tools';

  @override
  String get tipsQuickToolVariantDesc =>
      'The quick-tool slot is not limited to switching between tools like pen and eraser, you can register the same pen with a different brush, or the same eraser at a different size, as separate entries. Curating just the combinations you actually use often means fewer trips back to the settings panel.';

  @override
  String get tipsCommonLayerLipSyncTitle =>
      'Common layers cut file size for characters too, not just backgrounds';

  @override
  String get tipsCommonLayerLipSyncDesc =>
      'It is not just backgrounds, turning a character layer itself into a common layer works well too. Keep only the parts that change frame to frame, like the mouth or blinking eyes, as regular layers, and make the rest (body, hair) a common layer. This can shrink file size dramatically even for lip-sync or blinking animation.';

  @override
  String get tipsCommonLayerKeyframeTitle =>
      'Common layers plus layer keyframes also save space';

  @override
  String get tipsCommonLayerKeyframeDesc =>
      'Common layers can be moved, scaled, and rotated with layer keyframes. Instead of redrawing each frame, turn a single drawing into a common layer and animate it with keyframes, you get simple motion without growing your file size.';

  @override
  String get tipsTransferCustomizationTitle =>
      'Transfer keeps your personalized setup on any device';

  @override
  String get tipsTransferCustomizationDesc =>
      'The transfer (.niatra) feature carries over your customized settings — brushes, theme, toolbar layout, palettes, and more — all together to another device. Switch devices or work across several, and you never have to set everything up from scratch again.';

  @override
  String get tipsBlendModeUsageTitle =>
      'Pick a blend mode based on what you are going for';

  @override
  String get tipsBlendModeUsageDesc =>
      'Use Multiply for shadows, Screen or Addition for light and glow, and Overlay or Soft Light when you want shading with a bit of texture. The same color can look completely different depending on the blend mode, so it is worth flipping through a few candidates and comparing.';

  @override
  String get timelineSaveFailedDialogTitle => 'Save Failed';

  @override
  String get timelineSaveFailedDialogBody =>
      'Failed to save. Please try again.';

  @override
  String get licenseSectionIcons => 'About the Icons Used';

  @override
  String get layerPanelMergeAllVisibleTooltip => 'Merge all visible layers';

  @override
  String get canvasBrushSliderToggleLabel => 'Details';

  @override
  String get helpMeshTransformTitle => 'Free Transform / Mesh Warp';

  @override
  String get helpMeshTransformDesc =>
      'A transform tool for the whole layer, opened from the edit/settings menu in the top-right of the canvas. Unlike transforming a selection, no selection is needed — drag corners or individual grid points with your finger for a freeform result. The control panel\'s density slider can subdivide the mesh up to 10×10, and pinching two different points with two fingers at once gives an intuitive way to rotate or scale.';

  @override
  String get layerPanelBrightnessToAlphaLabel => 'Transparency from Brightness';

  @override
  String get layerPanelBrightnessToAlphaHint =>
      'Makes lighter areas more transparent. Colors stay the same but become translucent (the whole picture gets lighter, rather than the white background simply disappearing).';

  @override
  String get layerPanelBrightnessToAlphaColorButton => 'Color';

  @override
  String get layerPanelBrightnessToAlphaGrayButton => 'Gray';

  @override
  String get tipsRoughLayerRescueTitle =>
      'Drew line art on your rough sketch layer? Rescue it with \"Transparency from Brightness\"';

  @override
  String get tipsRoughLayerRescueDesc =>
      'Even if you accidentally drew your line art on top of your rough sketch layer, you can pull the line art back out without deleting anything. 1) Add a new layer and set its blend mode to Divide. 2) Pick up the sketch\'s color with the eyedropper and fill that whole Divide layer with it (this fades the sketch). 3) Duplicate the Divide layer and the sketch disappears completely. 4) Use \"Merge all visible layers\" in the layer panel to flatten everything into one layer. 5) From that merged layer\'s three-dot menu, choose \"Transparency from Brightness (Gray)\" — the white areas become transparent, leaving just the line art.';

  @override
  String get filterNameMonochrome => 'Monochrome Filter';

  @override
  String get timelineEffectTypeMonochrome => 'Monochrome Filter';

  @override
  String get filterNameColorAdjust => 'Color Adjust';

  @override
  String get filterColorAdjustSaturationLabel => 'Saturation';

  @override
  String get filterColorAdjustBrightnessLabel => 'Brightness';

  @override
  String get filterColorAdjustContrastLabel => 'Contrast';

  @override
  String get canvasColorAdjustTitle => 'Color Adjust';

  @override
  String get canvasColorAdjustAddToDrawFilter => 'Add to draw filters';

  @override
  String get canvasColorAdjustAddToEffectFilter => 'Add to effect filters';

  @override
  String get canvasColorAdjustMenuTitle => 'Color Adjust';

  @override
  String get canvasEditMenuReferenceWindow => 'Reference Window';

  @override
  String get canvasEditMenuReferenceWindowSubtitle =>
      'Keep a reference image floating on top';

  @override
  String get referenceWindowTitle => 'Reference Window';

  @override
  String get referenceWindowSelectImageButton => 'Choose Image';

  @override
  String get workspaceDockPanelSection => 'Panels open by default (PC)';

  @override
  String get workspaceDockPanelHint =>
      'In PC/DeX mode, checked panels can all be docked and shown at once (mobile always starts with all panels hidden to avoid accidental taps).';

  @override
  String get workspaceDockPanelBrush => 'Brush';

  @override
  String get workspaceDockPanelColorPicker => 'Color Picker';

  @override
  String get workspaceDockPanelLayer => 'Layers';

  @override
  String get workspaceDockPanelTone => 'Screentone';

  @override
  String get workspaceDockPanelStamp => 'Stamp';

  @override
  String get workspaceDockPanelPenSubTool => 'Pen Sub-tool';

  @override
  String get workspaceDockPanelOnionSkin => 'Onion Skin';

  @override
  String get workspaceDockPanelRuler => 'Ruler';

  @override
  String get workspaceDockPanelFilter => 'Filter';

  @override
  String get workspaceDockPanelQuickTool => 'Quick Tool';

  @override
  String get workspaceDockPanelColorAdjust => 'Color Adjustment';

  @override
  String get workspaceDockPanelCanvasPreview => 'Canvas Preview';

  @override
  String get workspacePcLayoutButton => 'PC layout settings';

  @override
  String get pcWorkspaceLayoutScreenTitle => 'PC layout settings';

  @override
  String get pcWorkspaceLayoutIntroHint =>
      'Adjust the order and width of panels when the canvas screen opens in PC mode (landscape + mouse/pen tablet connected).';

  @override
  String get pcWorkspaceLayoutToolOrderSection => 'Tool panel order';

  @override
  String get pcWorkspaceLayoutToolOrderHint =>
      'The stacking order used when multiple panels (brush, screentone, stamp, etc.) are open at once.';

  @override
  String get pcWorkspaceLayoutRightOrderSection => 'Layer panel etc. order';

  @override
  String get pcWorkspaceLayoutRightOrderHint =>
      'The stacking order of the color picker, layer panel, and canvas preview.';

  @override
  String get pcWorkspaceLayoutWidthSection => 'Panel width';

  @override
  String get pcWorkspaceLayoutToolWidthLabel => 'Tool panel side width';

  @override
  String get pcWorkspaceLayoutRightWidthLabel => 'Layer panel side width';

  @override
  String get pcWorkspaceLayoutResetWidthButton => 'Reset width to default';

  @override
  String get pcWorkspaceLayoutResetOrderButton => 'Reset order to default';

  @override
  String get canvasPreviewNavigatorTitle => 'Canvas Preview';

  @override
  String get canvasEditMenuPreviewNavigator => 'Canvas Preview';

  @override
  String get canvasEditMenuPreviewNavigatorSubtitle =>
      'Show a scaled-down overview (navigator)';

  @override
  String get filterNamePrism => 'Prism';

  @override
  String get filterNameThreshold => 'Threshold Filter';

  @override
  String get filterMonochromeStrength => 'Monochrome strength';

  @override
  String get filterMonochromeColorLabel => 'Monochrome color';

  @override
  String get filterThresholdLabel => 'Threshold';

  @override
  String get filterNameFisheye => 'Fisheye Filter';

  @override
  String get filterFisheyeStrength => 'Curvature strength';

  @override
  String get filterNameChromaticAberration => 'Chromatic Aberration Filter';

  @override
  String get filterChromaticAberrationStrength => 'Shift strength';

  @override
  String get filterNameLensDistortion => 'Lens Distortion Filter';

  @override
  String get filterLensDistortionStrength =>
      'Lens power (negative = concave, positive = convex)';

  @override
  String get filterLensDistortionOffsetX => 'Center fine-tune (horizontal)';

  @override
  String get filterNamePixelate => 'Pixelate Filter';

  @override
  String get filterNameAuroraHologram => 'Aurora Hologram';

  @override
  String get filterAuroraHologramStrength => 'Strength';

  @override
  String get filterAuroraHologramBrightness => 'Brightness';

  @override
  String get filterAuroraHologramSaturation => 'Saturation';

  @override
  String get filterAuroraHologramPresetAurora => 'Aurora';

  @override
  String get filterAuroraHologramPresetSoapBubble => 'Soap Bubble';

  @override
  String get filterAuroraHologramPresetCyberNeon => 'Cyber Neon';

  @override
  String get filterAuroraHologramPresetPastelDream => 'Pastel Dream';

  @override
  String get filterAuroraHologramPresetSunsetGold => 'Sunset Gold';

  @override
  String get filterAuroraHologramPresetSilverFoil => 'Silver Foil';

  @override
  String get filterNameBackgroundBlend => 'Background Blend';

  @override
  String get filterBackgroundBlendDirection =>
      'Shadow/light direction (linked)';

  @override
  String get filterBackgroundBlendLength => 'Shadow/light length (linked)';

  @override
  String get filterBackgroundBlendBlur => 'Blur amount';

  @override
  String get filterPixelateBlockSize => 'Block size';

  @override
  String get filterLensDistortionOffsetY => 'Center fine-tune (vertical)';

  @override
  String get filterLensDistortionNoMaskHint =>
      'Only applies to areas painted on a Selection layer. First add a \"Selection layer\" in the layer list and paint the area you want to turn into a lens (e.g. the lenses of a pair of glasses).';

  @override
  String get tipsStockingDenierTitle =>
      'Stocking/tights screentones vary in mesh fineness by denier';

  @override
  String get tipsStockingDenierDesc =>
      'The new stocking/tights screentones in the screentone list have tighter mesh spacing for lower denier values (thinner fabric) — the lowest, 10 denier, is deliberately fine enough that it can produce moiré depending on display or export resolution. Higher denier tights use wider spacing for a more opaque look, so pick the one that matches the character\'s legs.';

  @override
  String get tipsFisheyeChromaticTitle =>
      'Use the fisheye and chromatic aberration filters for a lens-like distortion and fringing';

  @override
  String get tipsFisheyeChromaticDesc =>
      'The fisheye filter bulges the center of the frame and compresses the edges, recreating the curvature of a wide-angle or fisheye lens shot. The chromatic aberration filter shifts the RGB channels slightly to recreate the color fringing you\'d get from a cheap lens. Both are available as drawing filters (applied directly to a layer) and as effect filters (applied to a range on the timeline).';

  @override
  String get tipsLensDistortionTitle =>
      'Recreate the distortion of prescription lenses with a Selection layer + Lens Distortion filter';

  @override
  String get tipsLensDistortionDesc =>
      'Add a \"Selection layer\" to the layer list and paint the lens area of a pair of glasses with any normal drawing tool — the Lens Distortion filter\'s local warp then applies only to that painted area. The power slider shrinks the area in a concave (myopia) direction for negative values and magnifies it in a convex (hyperopia) direction for positive values, and you can also fine-tune the center position. You can paint both lenses at once and apply the effect to both together. The Selection layer itself never appears in exports or the final artwork. It\'s also handy for reproducing the look of scenery seen through a camera lens — try painting a wide area, such as the background, with a Selection layer and using a mild power value.';

  @override
  String get tipsLineArtExtractionTitle =>
      'Extract line art by combining color adjust, threshold, and brightness-to-alpha';

  @override
  String get tipsLineArtExtractionDesc =>
      'Boost contrast with color adjust to make the lines stand out, then use the threshold filter to split the image into pure black and white — the lines separate cleanly from everything else. The threshold slider lets you fine-tune the line thickness and how faint or bold it looks. Finally, use \"Brightness to alpha (gray)\" from the layer\'s three-dot menu to make the white areas (everything but the lines) transparent, leaving just the line art. Handy for pulling clean line art out of a photo or rough sketch.';

  @override
  String get tipsLineColorUsageTitle =>
      'Pick line-color mode by purpose for a better finish';

  @override
  String get tipsLineColorUsageDesc =>
      'For a part’s outline, Color Trace / Line Blend keeps the edge readable without it floating off the art. For shadows and highlights, matching the line color to the fill color makes the line itself disappear. And a deliberately distinct specified color can give a series its own signature look.';

  @override
  String get tipsBlushAutofillTitle => 'Even soft blush can be auto-filled';

  @override
  String get tipsBlushAutofillDesc =>
      'Set the line color to a specified, transparent color, and set the fill to a Radial (center→outer) gradient with the blush pink and transparent as its two colors — that layers just the cheek blush softly onto the skin. Adjust the blush’s opacity and its color-stop position to blend it in even more naturally.';

  @override
  String get autofillPartResetTraceButton => 'Reset to default';

  @override
  String get premiumScreenTitle => 'Premium';

  @override
  String get premiumComparisonPremium => 'Premium';

  @override
  String premiumRegisteredDateLabel(String date) {
    return 'Registered: $date';
  }

  @override
  String premiumNextRenewalDateLabel(String date) {
    return 'Next renewal: $date';
  }

  @override
  String get workspaceApplyCurrentButton => 'Apply Configured Workspace';

  @override
  String get workspaceAppliedSnackbar => 'Workspace settings applied.';

  @override
  String get workspaceSaveAsButton => 'Save Workspace As / Overwrite';

  @override
  String get workspaceShareButton => 'Share Workspace';

  @override
  String get workspaceShareSelectTitle => 'Select a workspace to share';

  @override
  String workspaceShareFailedSnackbar(String error) {
    return 'Failed to share: $error';
  }

  @override
  String get workspaceImportFromFileButton => 'Import from file';

  @override
  String workspaceImportFailedSnackbar(String error) {
    return 'Failed to import: $error';
  }

  @override
  String get workspaceNameRequiredError => 'Please enter a name.';

  @override
  String get workspaceNoSavedPresets => 'No saved workspaces yet.';

  @override
  String get workspaceOverwriteSelectTitle => 'Select a workspace to overwrite';

  @override
  String get workspaceOverwriteConfirmTitle => 'Confirm overwrite';

  @override
  String workspaceOverwriteConfirmBody(String name) {
    return 'This will overwrite \"$name\" with the current settings. Its previous contents will be lost. Continue?';
  }

  @override
  String get workspaceOverwriteButton => 'Overwrite';

  @override
  String get splashCommunityButtonTitle => 'Work Plaza';

  @override
  String get splashCommunityButtonSubtitle => 'Browse posted works';

  @override
  String get splashCreateButton => 'Create an Animation';

  @override
  String get communityScreenTitle => 'Work Plaza';

  @override
  String get communityTabNew => 'New';

  @override
  String get communityTabRanking => 'Ranking';

  @override
  String get communityTabFavoriteAuthors => 'Following';

  @override
  String get communitySearchHint => 'Search by title or username';

  @override
  String get communityEmptyState => 'No works to show';

  @override
  String communitySearchNoResults(String query) {
    return 'No works matched \"$query\"';
  }

  @override
  String get communityTagSearchHint => 'Search by tag';

  @override
  String get communityAddTagButton => 'Add tag';

  @override
  String get communityAddTagDialogTitle => 'Add tag';

  @override
  String get communityAddTagDialogHint => 'Enter a tag name';

  @override
  String get communityTagLockTooltip => 'Lock this tag (author only)';

  @override
  String get communityTagUnlockTooltip => 'Unlock this tag (author only)';

  @override
  String get communityRemoveTagTooltip => 'Remove this tag';

  @override
  String get communityPostButton => 'Post';

  @override
  String get communityRankingPeriodAllTime => 'All-time';

  @override
  String get communityRankingPeriodYearly => 'Yearly';

  @override
  String get communityRankingPeriodMonthly => 'Monthly';

  @override
  String get communityRankingPeriodWeekly => 'Weekly';

  @override
  String get communityRankingPeriodDaily => 'Daily';

  @override
  String get communityRankingSortViews => 'Views';

  @override
  String get communityRankingSortBookmarks => 'Bookmarks';

  @override
  String get communityRankingSortAscendingTooltip => 'Ascending (lowest first)';

  @override
  String get communityRankingSortDescendingTooltip =>
      'Descending (highest first)';

  @override
  String communityWorkDetailPostedLabel(String date) {
    return 'Posted $date';
  }

  @override
  String get communityWorkDetailViewOnYoutube => 'Watch on YouTube';

  @override
  String get communityWorkDetailViewOnYoutubeComingSoonSnackbar =>
      'YouTube integration is coming soon';

  @override
  String get communityWorkDetailBookmarkAdd => 'Bookmark';

  @override
  String get communityWorkDetailBookmarkRemove => 'Bookmarked';

  @override
  String get communityWorkDetailReportButton => 'Report';

  @override
  String get communityWorkDetailBlockButton => 'Block';

  @override
  String get communityVisibilityCardTitle => 'Visibility in the Work Plaza';

  @override
  String get communityVisibilityPublishedDesc =>
      'Visible: shown in New Arrivals, Rankings, and this author\'s work list.';

  @override
  String get communityVisibilityHiddenDesc =>
      'Hidden: removed from New Arrivals, Rankings, and this author\'s work list (independent of the YouTube-side visibility setting).';

  @override
  String get communityVisibilityHiddenNotice =>
      'The creator has hidden this work in the Work Plaza.';

  @override
  String get communityVisibilityHiddenBadge => 'Hidden';

  @override
  String get communityWorkDetailTitle => 'Work Details';

  @override
  String get communityWorkNotFoundMessage => 'This work could not be found';

  @override
  String get communityFloatingPreviewDetailButton => 'Details';

  @override
  String get communityFloatingPreviewPlayTooltip => 'Play';

  @override
  String get communityFloatingPreviewPauseTooltip => 'Pause';

  @override
  String get communityReportDialogTitle => 'Report this work';

  @override
  String get communityReportDialogBody =>
      'Please choose a reason for reporting.';

  @override
  String get communityReportReasonInappropriate => 'Inappropriate content';

  @override
  String get communityReportReasonCopyright =>
      'Suspected copyright infringement';

  @override
  String get communityReportReasonSpam => 'Spam or repeated posting';

  @override
  String get communityReportReasonOther => 'Other';

  @override
  String get communityReportSubmitButton => 'Submit report';

  @override
  String get communityReportDetailLabel => 'Details';

  @override
  String get communityReportDetailHint =>
      'Describe specifically what the problem is';

  @override
  String get communityReportDetailRequiredError => 'Please enter details';

  @override
  String get communityReportComingSoonSnackbar =>
      'Reporting is coming soon. Nothing was actually sent.';

  @override
  String communityBlockConfirmTitle(String name) {
    return 'Block \"$name\"?';
  }

  @override
  String get communityBlockConfirmBody =>
      'Blocking hides this creator\'s works from your lists.';

  @override
  String get communityBlockComingSoonSnackbar =>
      'Blocking is coming soon. Nothing was actually applied.';

  @override
  String communityAuthorWorksCount(int count) {
    return '$count works';
  }

  @override
  String communityAuthorFollowerCount(int count) {
    return '$count followers';
  }

  @override
  String get communityFollowersPublicToggleTitle =>
      'Make following/follower lists public';

  @override
  String get communityFollowersPublicToggleDesc =>
      'When on, other users can see your following and follower lists from this page. Private by default.';

  @override
  String get communityFollowersListTitle => 'Followers';

  @override
  String get communityFollowersListEmpty => 'No followers yet';

  @override
  String communityFollowersListHiddenNote(int count) {
    return '$count more not shown, hidden by their own privacy setting';
  }

  @override
  String communityAuthorFollowingCount(int count) {
    return '$count following';
  }

  @override
  String get communityFollowingListTitle => 'Following';

  @override
  String get communityFollowingListEmpty => 'Not following anyone yet';

  @override
  String get communityFollowNotificationsTooltip => 'Notifications';

  @override
  String get communityFollowNotificationsTitle => 'Follow notifications';

  @override
  String get communityFollowNotificationsEmpty => 'No notifications';

  @override
  String communityFollowNotificationBody(String name) {
    return '$name followed you';
  }

  @override
  String get communityNoWorksMessage => 'No works';

  @override
  String get communityFavoriteAuthorFollow => 'Follow';

  @override
  String get communityFavoriteAuthorFollowing => 'Following';

  @override
  String get communityFavoriteAuthorsEmptyTitle => 'No favorite authors yet';

  @override
  String get communityFavoriteAuthorsEmptyBody =>
      'Follow a creator from their page to see their latest works here.';

  @override
  String get communityRepostButton => 'Repost';

  @override
  String get communityRepostedButton => 'Reposted';

  @override
  String communityRepostedByBadge(String name) {
    return 'Reposted by $name';
  }

  @override
  String get communityAuthorTabWorks => 'Works';

  @override
  String get communityAuthorTabBookmarks => 'Bookmarks';

  @override
  String get communityBookmarksPublicToggleTitle =>
      'Make bookmarks list public';

  @override
  String get communityBookmarksPublicToggleDesc =>
      'When on, other users can see your bookmark list from this page. Private by default.';

  @override
  String get communityBookmarksPrivateNotice =>
      'This user has set their bookmark list to private.';

  @override
  String get communityBookmarksEmptyMessage => 'No bookmarked works';

  @override
  String get communityShortsBadge => 'Portrait';

  @override
  String get communityVideoTypeFilterTooltip => 'Filter by video type';

  @override
  String get communityVideoTypeFilterAll => 'All';

  @override
  String get communityVideoTypeFilterShortOnly => 'Portrait only';

  @override
  String get communityVideoTypeFilterLongOnly => 'Landscape only';

  @override
  String get communityShortsModeTooltip => 'Watch in portrait mode';

  @override
  String get communityShortsModeEmptySnackbar => 'No portrait videos available';

  @override
  String get communityShortsModeExitTooltip => 'Exit portrait mode';

  @override
  String get pixelColorModeLabel => 'Color mode';

  @override
  String get pixelColorModeNone => 'Don\'t limit colors';

  @override
  String get pixelColorModePalette => 'Choose from palette';

  @override
  String get pixelColorModeExplicit => 'Specify colors';

  @override
  String get pixelColorModeCount => 'Specify color count';

  @override
  String pixelColorLevelsLabel(int count) {
    return 'Colors: $count';
  }

  @override
  String get pixelColorChipDeleteTooltip => 'Remove this color';

  @override
  String get pixelColorChipAddButton => 'Add color';

  @override
  String get pixelArtPaletteNameRequiredError => 'Please enter a palette name';

  @override
  String get pixelArtPaletteEditTitle => 'Edit palette';

  @override
  String get pixelArtPaletteAddTitle => 'Add palette';

  @override
  String get pixelArtPaletteNameLabel => 'Palette name';

  @override
  String get pixelArtPalettePickerTitle => 'Choose a palette';

  @override
  String get pixelArtPalettePickerEmpty =>
      'No saved palettes yet. Tap \\\"Add\\\" to create one.';

  @override
  String get pixelArtPalettePickerApplyButton => 'Apply';

  @override
  String get storageScreenTitle => 'Free up space';

  @override
  String get storageDeviceChartTitle => 'Device storage';

  @override
  String get storageBreakdownChartTitle => 'NIARIM breakdown';

  @override
  String get storageActionsTitle => 'Clean up';

  @override
  String get storageCategoryNiarimTotal => 'NIARIM';

  @override
  String get storageCategoryOtherApps => 'Other';

  @override
  String get storageCategoryFree => 'Free space';

  @override
  String get storageCategoryMaterials => 'Materials';

  @override
  String get storageCategoryProjectData => 'Project data';

  @override
  String get storageCategoryExports => 'Exported files';

  @override
  String get storageCategoryCustomAssets =>
      'Custom brushes/screentones/stamps/fonts';

  @override
  String get storageCategoryCache => 'Cache';

  @override
  String get storageCategoryTrash => 'Trash';

  @override
  String get storageClearCacheButton => 'Clear cache';

  @override
  String get storageRemoveUnusedMaterialsButton =>
      'Remove unused materials (all projects)';

  @override
  String get storageEmptyTrashButton => 'Empty trash';

  @override
  String get storageOrganizeProjectsButton => 'Organize projects';

  @override
  String get storageEraseAllButton => 'Erase all data (reset)';

  @override
  String storageClearCacheDoneSnackbar(String size) {
    return 'Cleared $size of cache';
  }

  @override
  String get storageEraseAllConfirmTitle => 'Erase all data?';

  @override
  String get storageEraseAllConfirmBody =>
      'This permanently deletes all NIARIM data — projects, materials, exported files, custom brushes/screentones/stamps/fonts, and settings. This cannot be undone. Restart the app afterward.';

  @override
  String get storageEraseAllDoneSnackbar =>
      'All data erased. Please restart the app.';

  @override
  String get homeDrawerStorage => 'Free up space';

  @override
  String get helpStorageTitle => 'Free up space';

  @override
  String get helpStorageDesc =>
      'See how much storage NIARIM is using on your device, and a breakdown of what\'s inside NIARIM (projects, materials, exported files, custom brushes/screentones/stamps/fonts, cache, and trash) as pie charts. Clear the cache, bulk-remove unused materials across all projects, empty the trash, organize projects, or erase all data (reset).';

  @override
  String get helpWidgetSettingsTitle => 'Home screen widgets';

  @override
  String get helpWidgetSettingsDesc =>
      'Settings for the three widget types you can place on your phone\'s home screen: a single frame from a work (launch screen), the New work widget, and the Plaza widget. Widgets themselves are added by long-pressing the home screen, not from inside the app. \"Choose a work\" uses the same sort, display mode, search, and favorites filter as the project list tab, then lets you pick the exact frame to show in a preview with playback controls. The New work and Plaza widgets let you choose whether the background follows the app theme or uses a color you set.';

  @override
  String get colorPickerImportPaletteTooltip => 'Import palette';

  @override
  String get colorPickerSharePaletteTooltip => 'Share';

  @override
  String get colorPickerShareViaFile => 'Share as file';

  @override
  String colorPickerShareFailedSnackbar(String error) {
    return 'Failed to share: $error';
  }

  @override
  String get colorPickerShareViaQr => 'Share as QR code';

  @override
  String get qrShareTooLargeHint =>
      'Too many colors to share as a QR code (use file sharing instead)';

  @override
  String get colorPickerImportViaFile => 'Choose a file';

  @override
  String colorPickerImportFailedSnackbar(String error) {
    return 'Failed to import: $error';
  }

  @override
  String get colorPickerImportViaQr => 'Paste QR code text';

  @override
  String get qrImportFailedError =>
      'Failed to import. Please check that the text is correct.';

  @override
  String get qrImportHint =>
      'Scan the QR code shown on the other device with a standard camera app, then paste the copied text here.';

  @override
  String get qrImportFieldHint => 'Paste the scanned text';

  @override
  String get qrImportPasteButton => 'Paste from clipboard';

  @override
  String get qrImportSubmitButton => 'Import';

  @override
  String get qrShareHint =>
      'Scan this QR code with a standard camera app to copy the text. On the other device, use \"Import\" to paste the copied text.';

  @override
  String get qrShareCopiedSnackbar => 'Text copied';

  @override
  String get qrShareCopyButton => 'Copy text';

  @override
  String get toolbarItemBlur => 'Gaussian blur';

  @override
  String get toolbarItemMosaic => 'Mosaic';

  @override
  String get toolbarFingerSubtoolWarp => 'Warp';

  @override
  String get brushSettingsEdgeJitterTitle => 'Edge jitter';

  @override
  String get brushSettingsEdgeJitterSubtitle =>
      'Slightly roughens the edge to mimic ink bleeding';

  @override
  String get brushSettingsEdgeJitterStrengthLabel => 'Jitter strength';

  @override
  String get filterNameInkPool => 'Ink Pooling';

  @override
  String get filterInkPoolColor => 'Color';

  @override
  String get filterInkPoolRange => 'Range';

  @override
  String get filterInkPoolCenterWidth => 'Center width';

  @override
  String filterInkPoolLayerNameSuffix(String name) {
    return '$name Ink Pooling';
  }

  @override
  String get filterCanvasEyedropperTooltip => 'Pick color from canvas';

  @override
  String get filterInkPoolEyedropperHint =>
      'Tap the canvas to choose the ink pooling color';

  @override
  String get filterOutlineEyedropperHint =>
      'Tap the canvas to choose the outline color';

  @override
  String get filterNameAutoLineart => 'Auto line art';

  @override
  String get filterAutoLineartRoughWidth => 'Rough line width';

  @override
  String get filterAutoLineartOutputWidth => 'Line art width';

  @override
  String get filterAutoLineartTaperLength => 'Taper length';

  @override
  String get filterAutoLineartSmoothing => 'Smoothing';

  @override
  String filterAutoLineartLayerNameSuffix(String name) {
    return '$name Auto line art';
  }

  @override
  String get customAutomationTitle => 'Automations';

  @override
  String get customAutomationAdd => 'Add automation';

  @override
  String get customAutomationNewTitle => 'New automation';

  @override
  String get customAutomationNameLabel => 'Name';

  @override
  String get customAutomationStartRecording => 'Start recording';

  @override
  String get customAutomationStopRecording => 'Stop recording';

  @override
  String get customAutomationRunConfirmTitle => 'Run this automation?';

  @override
  String get customAutomationCurrentFrame => 'Run on the current frame';

  @override
  String get customAutomationAllFrames => 'Run on all frames';

  @override
  String get customAutomationYes => 'Yes';

  @override
  String get customAutomationNo => 'No';

  @override
  String get customAutomationRenameTitle => 'Rename';

  @override
  String get customAutomationDeleteTitle => 'Delete this automation?';

  @override
  String get customAutomationImport => 'Import automation';

  @override
  String get customAutomationExport => 'Share / export automation';

  @override
  String get customAutomationRerecord => 'Re-record';

  @override
  String get customAutomationImportInvalid =>
      'This automation file cannot be imported';

  @override
  String get customAutomationEmpty => 'No recorded automations';

  @override
  String customAutomationStepCount(int count) {
    return '$count steps';
  }

  @override
  String get customAutomationReturnToRecording => 'Return to recording';

  @override
  String get customAutomationStopConfirmTitle =>
      'Stop registering this automation?';

  @override
  String get customAutomationStopConfirmContinue => 'Continue';

  @override
  String get customAutomationReviewHint =>
      'Reorder or delete steps before saving';

  @override
  String get customAutomationNoRecordedSteps => 'No actions were recorded';

  @override
  String get customAutomationCanvasStep => 'Canvas action';

  @override
  String get customAutomationTimelineStep => 'Timeline action';

  @override
  String get customAutomationBackToRecording => 'Back to recording';

  @override
  String get customAutomationStopConfirmStop => 'Stop';

  @override
  String get filterNameVhsNoise => 'VHS Noise';

  @override
  String get filterVhsNoiseStrength => 'Noise';

  @override
  String get filterVhsScanlineStrength => 'Scanlines';

  @override
  String get filterVhsColorBleed => 'Color bleed';

  @override
  String get filterVhsTracking => 'Tracking';

  @override
  String get timelineEffectTypeVhsNoise => 'VHS Noise';

  @override
  String get customAutomationSpecifiedFrames => 'Run on specified frames';

  @override
  String get customAutomationFrameFrom => 'From frame';

  @override
  String get customAutomationFrameTo => 'To frame';

  @override
  String get customAutomationFrameRangeInvalid => 'Enter a valid frame range.';
}
