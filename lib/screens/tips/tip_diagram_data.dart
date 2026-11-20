import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/creative_preset_labels.dart';

enum TipDiagramKind {
  timeline,
  settings,
  toolbar,
  text,
  canvas,
  fade,
  vertical,
  layers,
  range,
  export,
  media,
  devices,
  color,
  save,
  savedVersions,
  curve,
  filter,
  fineGrid,
  mediumGrid,
  wideGrid,
}

typedef TipDiagramStep = (TipDiagramKind kind, IconData icon, String label);

enum TipTopic {
  clipDuplicate,
  textCaption,
  audioRepeat,
  verticalRuby,
  endCardWatermark,
  verticalPixelFont,
  stampBlendMode,
  videoTrimReuse,
  timelineMarker,
  communityYoutube,
  autofillPreset,
  officialAutomationPresets,
  autofillBaseCoat,
  autofillManualPartColor,
  brushFavorite,
  brushTrySaveTree,
  eyedropperGesture,
  magicWandLasso,
  commonLayerFolder,
  quickToolPenSub,
  quickToolVariant,
  autofillToneReuse,
  autofillMisfill,
  homeWidget,
  autofillTransparentFix,
  saveSlotAutoSave,
  quickToolSwipe,
  toolbarCustomize,
  pcDexLayout,
  commonLayerLipSync,
  commonLayerKeyframe,
  transparentColor,
  pressureCurve,
  rulerOnion,
  fourPanelBrush,
  gradientTrace,
  gradientOutlineHair,
  brushFold,
  strokeDecayFade,
  colorMixingFade,
  radialVignette,
  clippingGradient,
  drawingAreaCamera,
  autofillBlendMode,
  roughLayerRescue,
  lineArtExtraction,
  lineColorUsage,
  blushAutofill,
  stockingDenier,
  rainNoise,
  texturePrismVhs,
  partKeyframeGroup,
  outlineAnimeStyle,
  levelsToneCurve,
  toneCurveSepia,
  cameraLensBlur,
  webmCommonLayer,
  leftHandedWorkspace,
  blendModeUsage,
  fisheyeChromatic,
  lensDistortion,
  sphereShading,
  backgroundBlend,
  exportFormat,
  gestureShortcut,
  lowSpecSettings,
  seriesPresetFolder,
  mosaicChromatic,
  pixelToneRetro,
  blurVignetteBg,
  sepiaVignette,
  transferDevice,
  transferCustomization;

  bool get isComparison => switch (this) {
    endCardWatermark ||
    saveSlotAutoSave ||
    lineColorUsage ||
    stockingDenier ||
    texturePrismVhs ||
    blendModeUsage ||
    fisheyeChromatic ||
    exportFormat => true,
    _ => false,
  };

  // The auto-fill walkthrough has one illustration per translated paragraph.
  bool get illustrateByParagraph => this == autofillManualPartColor;

  List<TipDiagramStep> steps(AppLocalizations l10n, int page) {
    if (illustrateByParagraph && page > 0) {
      return switch (page) {
        1 => [
          (
            TipDiagramKind.layers,
            Icons.add_box_outlined,
            l10n.layerPanelMenuLineartLayer,
          ),
          (TipDiagramKind.settings, Icons.tune, l10n.layerPanelMenuPartAssign),
          (
            TipDiagramKind.settings,
            Icons.play_arrow,
            l10n.layerPanelMenuRunAutofill,
          ),
        ],
        2 => [
          (
            TipDiagramKind.layers,
            Icons.layers_outlined,
            l10n.layerPanelMenuAutofillLayer,
          ),
          (
            TipDiagramKind.color,
            Icons.palette_outlined,
            l10n.autofillPartSelectColorButton,
          ),
          (TipDiagramKind.canvas, Icons.brush_outlined, l10n.transferItemBrush),
        ],
        _ => [
          (
            TipDiagramKind.layers,
            Icons.more_horiz,
            l10n.layerPanelMenuLineartLayer,
          ),
          (
            TipDiagramKind.settings,
            Icons.play_arrow,
            l10n.layerPanelMenuRunAutofill,
          ),
          (
            TipDiagramKind.color,
            Icons.sync,
            l10n.layerPanelAutofillColorUpdateTitle,
          ),
        ],
      };
    }
    return switch (this) {
      clipDuplicate => [
        (
          TipDiagramKind.timeline,
          Icons.movie_outlined,
          l10n.projectListMaterialVideo,
        ),
        (TipDiagramKind.settings, Icons.content_copy, l10n.commonDuplicate),
        (TipDiagramKind.timeline, Icons.open_with, l10n.commonMove),
      ],
      textCaption => [
        (TipDiagramKind.toolbar, Icons.text_fields, l10n.toolbarItemText),
        (TipDiagramKind.text, Icons.edit_outlined, l10n.canvasTextInputTitle),
        (
          TipDiagramKind.canvas,
          Icons.subtitles_outlined,
          l10n.timelinePreviewPlaceholder,
        ),
      ],
      audioRepeat => [
        (TipDiagramKind.timeline, Icons.content_copy, l10n.commonDuplicate),
        (TipDiagramKind.timeline, Icons.open_with, l10n.commonMove),
        (
          TipDiagramKind.fade,
          Icons.graphic_eq,
          '${l10n.timelineClipFadeInLabel} / ${l10n.timelineClipFadeOutLabel}',
        ),
      ],
      verticalRuby => [
        (TipDiagramKind.toolbar, Icons.text_fields, l10n.toolbarItemText),
        (
          TipDiagramKind.vertical,
          Icons.view_column_outlined,
          l10n.canvasTextVertical,
        ),
        (
          TipDiagramKind.vertical,
          Icons.format_size,
          _controlName(l10n.canvasHelpRubyTitle),
        ),
      ],
      endCardWatermark => [
        (
          TipDiagramKind.canvas,
          Icons.branding_watermark_outlined,
          l10n.settingsWatermarkTitle,
        ),
        (TipDiagramKind.timeline, Icons.flag_outlined, l10n.helpEndCardTitle),
        (
          TipDiagramKind.layers,
          Icons.image_outlined,
          '${l10n.projectListMaterialImage} / ${l10n.helpFadeTitle}',
        ),
      ],
      verticalPixelFont => [
        (
          TipDiagramKind.timeline,
          Icons.movie_outlined,
          l10n.projectListMaterialVideo,
        ),
        (
          TipDiagramKind.layers,
          Icons.layers_outlined,
          l10n.workspaceDockPanelOnionSkin,
        ),
        (TipDiagramKind.canvas, Icons.draw_outlined, l10n.toolbarItemPen),
      ],
      stampBlendMode => [
        (TipDiagramKind.toolbar, Icons.auto_awesome, l10n.stampTitle),
        (TipDiagramKind.layers, Icons.gradient, l10n.helpBlendModeTitle),
        (
          TipDiagramKind.canvas,
          Icons.wb_sunny_outlined,
          '${l10n.blendModeScreen} / ${l10n.blendModeAddition}',
        ),
      ],
      videoTrimReuse => [
        (
          TipDiagramKind.timeline,
          Icons.movie_outlined,
          l10n.projectListMaterialVideo,
        ),
        (TipDiagramKind.timeline, Icons.content_copy, l10n.commonDuplicate),
        (
          TipDiagramKind.range,
          Icons.content_cut,
          '${l10n.timelineClipUseStartLabel} / ${l10n.timelineClipUseEndLabel}',
        ),
      ],
      timelineMarker => [
        (
          TipDiagramKind.timeline,
          Icons.flag_outlined,
          l10n.timelineMarkerTrackLabel,
        ),
        (TipDiagramKind.settings, Icons.edit_note, l10n.commonEdit),
        (TipDiagramKind.range, Icons.play_arrow, l10n.timelineFrameTrackLabel),
      ],
      communityYoutube => [
        (
          TipDiagramKind.export,
          Icons.video_file_outlined,
          l10n.exportScreenTitle,
        ),
        (TipDiagramKind.media, Icons.play_circle_outline, 'YouTube'),
        (TipDiagramKind.devices, Icons.public, l10n.helpCommunityTitle),
      ],
      autofillPreset => [
        (TipDiagramKind.settings, Icons.tune, l10n.homeDrawerAutofillPreset),
        (
          TipDiagramKind.layers,
          Icons.add_box_outlined,
          l10n.autofillPartAddDialogTitle,
        ),
        (
          TipDiagramKind.color,
          Icons.format_paint,
          l10n.autofillPartFillColorLabel,
        ),
      ],
      officialAutomationPresets => [
        (TipDiagramKind.export, Icons.upload_file, l10n.customAutomationExport),
        (
          TipDiagramKind.settings,
          Icons.edit_note,
          l10n.customAutomationRerecord,
        ),
        (TipDiagramKind.settings, Icons.swap_vert, l10n.commonMove),
      ],
      autofillBaseCoat => [
        (TipDiagramKind.layers, Icons.edit_outlined, l10n.assetTagLineArt),
        (
          TipDiagramKind.canvas,
          Icons.format_color_fill,
          l10n.helpAutoFillTitle,
        ),
        (
          TipDiagramKind.layers,
          Icons.brush_outlined,
          l10n.autofillPartFillColorLabel,
        ),
      ],
      autofillManualPartColor => [
        (
          TipDiagramKind.layers,
          Icons.edit_outlined,
          l10n.layerPanelMenuNormalLayer,
        ),
        (TipDiagramKind.canvas, Icons.draw_outlined, l10n.assetTagLineArt),
        (
          TipDiagramKind.layers,
          Icons.layers_outlined,
          l10n.layerPanelMenuAutofillLayer,
        ),
      ],
      brushFavorite => [
        (TipDiagramKind.settings, Icons.brush_outlined, l10n.transferItemBrush),
        (TipDiagramKind.toolbar, Icons.star_border, l10n.commonFavoriteToggle),
        (
          TipDiagramKind.settings,
          Icons.filter_list,
          l10n.creativePanelFavoritesOnlyTooltip,
        ),
      ],
      brushTrySaveTree => [
        (
          TipDiagramKind.save,
          Icons.save_outlined,
          l10n.saveTreeScreenTitleTree,
        ),
        (TipDiagramKind.settings, Icons.tune, l10n.transferItemBrush),
        (
          TipDiagramKind.savedVersions,
          Icons.restore,
          l10n.saveTreeRestoreAction,
        ),
      ],
      eyedropperGesture => [
        (TipDiagramKind.settings, Icons.touch_app, l10n.settingsGestureTitle),
        (TipDiagramKind.toolbar, Icons.touch_app, l10n.gestureTwoFingerTap),
        (TipDiagramKind.color, Icons.colorize, l10n.gestureActionEyedropper),
      ],
      magicWandLasso => [
        (
          TipDiagramKind.toolbar,
          Icons.auto_fix_high,
          l10n.toolbarSelectMagicWand,
        ),
        (TipDiagramKind.canvas, Icons.gesture, l10n.toolbarSelectLasso),
        (
          TipDiagramKind.canvas,
          Icons.format_color_fill,
          l10n.helpLassoFillTitle,
        ),
      ],
      commonLayerFolder => [
        (
          TipDiagramKind.layers,
          Icons.layers_outlined,
          l10n.helpCommonLayerTitle,
        ),
        (TipDiagramKind.layers, Icons.folder_outlined, l10n.helpFolderTitle),
        (TipDiagramKind.devices, Icons.content_copy, l10n.commonDuplicate),
      ],
      quickToolPenSub => [
        (TipDiagramKind.toolbar, Icons.bolt, l10n.helpQuickToolTitle),
        (
          TipDiagramKind.toolbar,
          Icons.touch_app,
          '${l10n.toolbarItemPen} / ${l10n.gestureLongPress}',
        ),
        (
          TipDiagramKind.toolbar,
          Icons.auto_awesome,
          '${l10n.stampTitle} / ${l10n.toneTitle}',
        ),
      ],
      quickToolVariant => [
        (TipDiagramKind.toolbar, Icons.bolt, l10n.helpQuickToolTitle),
        (TipDiagramKind.settings, Icons.brush_outlined, l10n.transferItemBrush),
        (TipDiagramKind.settings, Icons.line_weight, l10n.homeViewSizeHeading),
      ],
      autofillToneReuse => [
        (TipDiagramKind.settings, Icons.tune, l10n.homeDrawerAutofillPreset),
        (TipDiagramKind.color, Icons.grain, l10n.autofillPartUseToneCheckbox),
        (TipDiagramKind.layers, Icons.format_paint, l10n.helpAutoFillTitle),
      ],
      autofillMisfill => [
        (
          TipDiagramKind.color,
          Icons.palette_outlined,
          l10n.autofillPartSelectColorButton,
        ),
        (
          TipDiagramKind.layers,
          Icons.brush_outlined,
          l10n.layerPanelMenuAutofillLayer,
        ),
        (
          TipDiagramKind.settings,
          Icons.sync,
          l10n.layerPanelAutofillColorUpdateTitle,
        ),
      ],
      homeWidget => [
        (
          TipDiagramKind.settings,
          Icons.widgets_outlined,
          l10n.widgetSettingsTitle,
        ),
        (
          TipDiagramKind.range,
          Icons.image_outlined,
          l10n.timelineFrameTrackLabel,
        ),
        (TipDiagramKind.devices, Icons.home_outlined, l10n.widgetSettingsTitle),
      ],
      autofillTransparentFix => [
        (
          TipDiagramKind.layers,
          Icons.layers_outlined,
          l10n.layerPanelMenuAutofillLayer,
        ),
        (
          TipDiagramKind.color,
          Icons.check_box_outline_blank,
          l10n.canvasBackgroundTransparent,
        ),
        (TipDiagramKind.canvas, Icons.format_color_fill, l10n.quickToolBucket),
      ],
      saveSlotAutoSave => [
        (TipDiagramKind.save, Icons.save_outlined, l10n.saveDataManualTab),
        (TipDiagramKind.savedVersions, Icons.history, l10n.helpAutoSaveTitle),
        (
          TipDiagramKind.savedVersions,
          Icons.menu_book_outlined,
          l10n.saveTreeRestoreAction,
        ),
      ],
      quickToolSwipe => [
        (TipDiagramKind.toolbar, Icons.bolt, l10n.helpQuickToolTitle),
        (TipDiagramKind.toolbar, Icons.swipe_up, l10n.commonEdit),
        (TipDiagramKind.settings, Icons.swap_vert, l10n.commonMove),
      ],
      toolbarCustomize => [
        (TipDiagramKind.settings, Icons.tune, l10n.workspaceToolbarEditSection),
        (
          TipDiagramKind.toolbar,
          Icons.visibility_off_outlined,
          l10n.timelineEndCardHiddenLabel,
        ),
        (TipDiagramKind.toolbar, Icons.swap_vert, l10n.commonMove),
      ],
      pcDexLayout => [
        (
          TipDiagramKind.devices,
          Icons.desktop_windows_outlined,
          l10n.workspacePcModeSection,
        ),
        (
          TipDiagramKind.settings,
          Icons.aspect_ratio,
          _controlName(l10n.workspacePcModeAuto),
        ),
        (TipDiagramKind.devices, Icons.web_asset, l10n.workspacePcModeAlwaysPc),
      ],
      commonLayerLipSync => [
        (
          TipDiagramKind.layers,
          Icons.layers_outlined,
          l10n.helpCommonLayerTitle,
        ),
        (TipDiagramKind.layers, Icons.draw_outlined, l10n.helpCategoryLayer),
        (
          TipDiagramKind.timeline,
          Icons.face_outlined,
          l10n.timelineFrameTrackLabel,
        ),
      ],
      commonLayerKeyframe => [
        (
          TipDiagramKind.layers,
          Icons.layers_outlined,
          l10n.helpCommonLayerTitle,
        ),
        (
          TipDiagramKind.timeline,
          Icons.diamond_outlined,
          l10n.layerPanelKeyframeLabel,
        ),
        (
          TipDiagramKind.canvas,
          Icons.open_with,
          '${l10n.layerKeyframeRotationShort} / ${l10n.layerKeyframeScaleShort}',
        ),
      ],
      transparentColor => [
        (
          TipDiagramKind.color,
          Icons.check_box_outline_blank,
          l10n.canvasBackgroundTransparent,
        ),
        (TipDiagramKind.toolbar, Icons.brush_outlined, l10n.transferItemBrush),
        (TipDiagramKind.canvas, Icons.gesture, l10n.helpLassoFillTitle),
      ],
      pressureCurve => [
        (TipDiagramKind.settings, Icons.edit_outlined, l10n.settingsPenTitle),
        (TipDiagramKind.curve, Icons.show_chart, l10n.penSettingsCurveSection),
        (TipDiagramKind.curve, Icons.tune, l10n.penSettingsCurveCustom),
      ],
      rulerOnion => [
        (TipDiagramKind.canvas, Icons.straighten, l10n.rulerTypeOnePoint),
        (
          TipDiagramKind.layers,
          Icons.layers_outlined,
          l10n.workspaceDockPanelOnionSkin,
        ),
        (
          TipDiagramKind.timeline,
          Icons.open_with,
          l10n.timelineFrameTrackLabel,
        ),
      ],
      fourPanelBrush => [
        (
          TipDiagramKind.toolbar,
          Icons.brush_outlined,
          creativePresetLabel(l10n, '四コマ漫画', builtIn: true),
        ),
        (TipDiagramKind.toolbar, Icons.straighten, l10n.rulerTypeLine),
        (TipDiagramKind.canvas, Icons.grid_view, l10n.homeViewSizeHeading),
      ],
      gradientTrace => [
        (TipDiagramKind.settings, Icons.tune, l10n.homeDrawerAutofillPreset),
        (
          TipDiagramKind.color,
          Icons.gradient,
          l10n.autofillPartGradientSetButton,
        ),
        (
          TipDiagramKind.layers,
          Icons.border_color,
          l10n.autofillLineColorModeTraceAdjust,
        ),
      ],
      gradientOutlineHair => [
        (
          TipDiagramKind.color,
          Icons.gradient,
          '${l10n.autofillPartGradientSetButton} / ${l10n.canvasBackgroundTransparent}',
        ),
        (
          TipDiagramKind.settings,
          Icons.rotate_right,
          l10n.autofillPartGradientAngleLabel(90),
        ),
        (
          TipDiagramKind.layers,
          Icons.border_outer,
          l10n.autofillPartOutlineLabel,
        ),
      ],
      brushFold => [
        (TipDiagramKind.settings, Icons.layers_outlined, l10n.brushFold),
        (TipDiagramKind.canvas, Icons.gesture, l10n.brushFoldModeWaveTopView),
        (
          TipDiagramKind.settings,
          Icons.tune,
          '${l10n.brushFoldLength} / ${l10n.brushFoldAngle}',
        ),
      ],
      strokeDecayFade => [
        (TipDiagramKind.settings, Icons.brush_outlined, l10n.transferItemBrush),
        (TipDiagramKind.fade, Icons.graphic_eq, l10n.helpFadeTitle),
        (TipDiagramKind.curve, Icons.show_chart, l10n.helpStrokeDecayTitle),
      ],
      colorMixingFade => [
        (
          TipDiagramKind.color,
          Icons.palette_outlined,
          l10n.helpColorMixingTitle,
        ),
        (TipDiagramKind.fade, Icons.graphic_eq, l10n.helpFadeTitle),
        (TipDiagramKind.canvas, Icons.brush_outlined, l10n.transferItemBrush),
      ],
      radialVignette => [
        (TipDiagramKind.toolbar, Icons.straighten, l10n.rulerTypeRadial),
        (TipDiagramKind.canvas, Icons.flare, l10n.rulerTypeRadial),
        (
          TipDiagramKind.filter,
          Icons.brightness_4_outlined,
          l10n.filterNameVignette,
        ),
      ],
      clippingGradient => [
        (TipDiagramKind.layers, Icons.layers_outlined, l10n.helpClippingTitle),
        (
          TipDiagramKind.color,
          Icons.gradient,
          l10n.autofillPartGradientSetButton,
        ),
        (
          TipDiagramKind.settings,
          Icons.rotate_right,
          l10n.autofillPartGradientEditButton,
        ),
      ],
      drawingAreaCamera => [
        (
          TipDiagramKind.canvas,
          Icons.crop_free,
          l10n.newProjectDrawingAreaTitle,
        ),
        (
          TipDiagramKind.timeline,
          Icons.diamond_outlined,
          l10n.helpCameraKeyframeTitle,
        ),
        (TipDiagramKind.canvas, Icons.zoom_in, l10n.timelineCameraZoomLabel),
      ],
      autofillBlendMode => [
        (TipDiagramKind.settings, Icons.tune, l10n.homeDrawerAutofillPreset),
        (
          TipDiagramKind.layers,
          Icons.gradient,
          l10n.autofillPartBlendModeLabel,
        ),
        (
          TipDiagramKind.canvas,
          Icons.brightness_4_outlined,
          '${l10n.blendModeOverlay} / ${l10n.blendModeSoftLight}',
        ),
      ],
      roughLayerRescue => [
        (TipDiagramKind.layers, Icons.edit_outlined, l10n.assetTagLineArt),
        (TipDiagramKind.layers, Icons.content_copy, l10n.commonDuplicate),
        (
          TipDiagramKind.color,
          Icons.check_box_outline_blank,
          l10n.layerPanelBrightnessToAlphaLabel,
        ),
      ],
      lineArtExtraction => [
        (TipDiagramKind.filter, Icons.tune, l10n.filterNameColorAdjust),
        (TipDiagramKind.filter, Icons.contrast, l10n.filterNameThreshold),
        (
          TipDiagramKind.color,
          Icons.check_box_outline_blank,
          l10n.layerPanelBrightnessToAlphaLabel,
        ),
      ],
      lineColorUsage => [
        (
          TipDiagramKind.layers,
          Icons.border_color,
          l10n.autofillLineColorModeTraceAdjust,
        ),
        (
          TipDiagramKind.color,
          Icons.format_color_fill,
          l10n.autofillLineColorModeSameAsFill,
        ),
        (
          TipDiagramKind.color,
          Icons.colorize,
          l10n.autofillLineColorModeSpecified,
        ),
      ],
      blushAutofill => [
        (
          TipDiagramKind.color,
          Icons.check_box_outline_blank,
          l10n.canvasBackgroundTransparent,
        ),
        (
          TipDiagramKind.color,
          Icons.gradient,
          l10n.autofillGradientTypeRadialCenterOut,
        ),
        (
          TipDiagramKind.settings,
          Icons.opacity,
          l10n.brushSettingsOpacityLabel,
        ),
      ],
      stockingDenier => [
        (TipDiagramKind.fineGrid, Icons.grid_on, '10D'),
        (TipDiagramKind.mediumGrid, Icons.grid_on, '40D'),
        (TipDiagramKind.wideGrid, Icons.grid_on, '80D'),
      ],
      rainNoise => [
        (
          TipDiagramKind.filter,
          Icons.water_drop_outlined,
          l10n.timelineEffectTypeRain,
        ),
        (
          TipDiagramKind.filter,
          Icons.grain,
          l10n.timelineEffectTypeAnimatedNoise,
        ),
        (TipDiagramKind.settings, Icons.tune, l10n.timelineEffectStrengthLabel),
      ],
      texturePrismVhs => [
        (
          TipDiagramKind.filter,
          Icons.auto_awesome,
          l10n.filterNameAuroraHologram,
        ),
        (TipDiagramKind.color, Icons.gradient, l10n.filterNamePrism),
        (
          TipDiagramKind.media,
          Icons.videocam_outlined,
          l10n.filterNameVhsNoise,
        ),
      ],
      partKeyframeGroup => [
        (
          TipDiagramKind.layers,
          Icons.layers_outlined,
          l10n.layerPanelMenuAutofillLayer,
        ),
        (
          TipDiagramKind.timeline,
          Icons.diamond_outlined,
          l10n.layerPanelKeyframeLabel,
        ),
        (
          TipDiagramKind.layers,
          Icons.group_work_outlined,
          l10n.layerPanelGroupTooltip,
        ),
      ],
      outlineAnimeStyle => [
        (TipDiagramKind.filter, Icons.border_outer, l10n.filterNameOutline),
        (TipDiagramKind.layers, Icons.add_box_outlined, l10n.helpCategoryLayer),
        (
          TipDiagramKind.filter,
          Icons.palette_outlined,
          l10n.filterNameAnimeStyle,
        ),
      ],
      levelsToneCurve => [
        (TipDiagramKind.curve, Icons.tune, l10n.filterNameLevels),
        (TipDiagramKind.curve, Icons.show_chart, l10n.filterNameToneCurve),
        (
          TipDiagramKind.canvas,
          Icons.visibility_outlined,
          l10n.timelinePreviewPlaceholder,
        ),
      ],
      toneCurveSepia => [
        (TipDiagramKind.curve, Icons.show_chart, l10n.filterNameToneCurve),
        (
          TipDiagramKind.filter,
          Icons.photo_filter,
          l10n.timelineEffectTypeSepia,
        ),
        (
          TipDiagramKind.canvas,
          Icons.visibility_outlined,
          l10n.timelinePreviewPlaceholder,
        ),
      ],
      cameraLensBlur => [
        (
          TipDiagramKind.timeline,
          Icons.diamond_outlined,
          l10n.helpCameraKeyframeTitle,
        ),
        (TipDiagramKind.canvas, Icons.zoom_in, l10n.timelineCameraZoomLabel),
        (TipDiagramKind.filter, Icons.blur_on, l10n.filterNameLensBlur),
      ],
      webmCommonLayer => [
        (
          TipDiagramKind.layers,
          Icons.layers_outlined,
          l10n.helpCommonLayerTitle,
        ),
        (
          TipDiagramKind.layers,
          Icons.visibility_off_outlined,
          l10n.assetTagBackground,
        ),
        (TipDiagramKind.export, Icons.video_file_outlined, 'WebM'),
      ],
      leftHandedWorkspace => [
        (TipDiagramKind.settings, Icons.tune, l10n.settingsWorkspaceTitle),
        (
          TipDiagramKind.settings,
          Icons.touch_app,
          l10n.workspaceLeftHandedMode,
        ),
        (
          TipDiagramKind.devices,
          Icons.web_asset,
          l10n.workspaceLeftHandedSubtitlePc,
        ),
      ],
      blendModeUsage => [
        (
          TipDiagramKind.layers,
          Icons.brightness_4_outlined,
          l10n.blendModeMultiply,
        ),
        (
          TipDiagramKind.layers,
          Icons.wb_sunny_outlined,
          '${l10n.blendModeScreen} / ${l10n.blendModeAddition}',
        ),
        (
          TipDiagramKind.layers,
          Icons.gradient,
          '${l10n.blendModeOverlay} / ${l10n.blendModeSoftLight}',
        ),
      ],
      fisheyeChromatic => [
        (TipDiagramKind.canvas, Icons.add, l10n.filterNameFisheye),
        (
          TipDiagramKind.color,
          Icons.color_lens_outlined,
          l10n.filterNameChromaticAberration,
        ),
        (
          TipDiagramKind.timeline,
          Icons.filter_alt_outlined,
          l10n.filterPanelTitle,
        ),
      ],
      lensDistortion => [
        (
          TipDiagramKind.filter,
          Icons.visibility_outlined,
          l10n.filterNameLensDistortion,
        ),
        (
          TipDiagramKind.canvas,
          Icons.brush_outlined,
          '${l10n.filterLensMaskPen} / ${l10n.filterLensMaskBucket}',
        ),
        (TipDiagramKind.curve, Icons.tune, l10n.timelineEffectStrengthLabel),
      ],
      sphereShading => [
        (TipDiagramKind.canvas, Icons.add, l10n.filterNameSphereShading),
        (TipDiagramKind.canvas, Icons.open_with, l10n.filterSphereLightWidth),
        (TipDiagramKind.color, Icons.gradient, l10n.filterSphereLightBlur),
      ],
      backgroundBlend => [
        (TipDiagramKind.layers, Icons.layers_outlined, l10n.helpCategoryLayer),
        (TipDiagramKind.filter, Icons.tune, l10n.filterNameBackgroundBlend),
        (TipDiagramKind.curve, Icons.show_chart, l10n.filterNameToneCurve),
      ],
      exportFormat => [
        (TipDiagramKind.export, Icons.gif_box_outlined, l10n.exportFormatGif),
        (TipDiagramKind.export, Icons.video_file_outlined, 'WebM'),
        (TipDiagramKind.export, Icons.movie_outlined, l10n.exportFormatMp4),
      ],
      gestureShortcut => [
        (TipDiagramKind.settings, Icons.touch_app, l10n.settingsGestureTitle),
        (TipDiagramKind.toolbar, Icons.touch_app, l10n.gestureTwoFingerTap),
        (
          TipDiagramKind.toolbar,
          Icons.undo,
          '${l10n.gestureActionUndo} / ${l10n.gestureActionEyedropper}',
        ),
      ],
      lowSpecSettings => [
        (TipDiagramKind.settings, Icons.tune, l10n.settingsPerformanceTitle),
        (TipDiagramKind.settings, Icons.speed, l10n.perfSettingsQualityLow),
        (TipDiagramKind.settings, Icons.undo, l10n.perfSettingsUndoLimitTitle),
      ],
      seriesPresetFolder => [
        (TipDiagramKind.layers, Icons.folder_outlined, l10n.helpFolderTitle),
        (
          TipDiagramKind.savedVersions,
          Icons.folder_open,
          l10n.themePreviewScreenProjects,
        ),
        (
          TipDiagramKind.settings,
          Icons.filter_list,
          l10n.homeDrawerAutofillPreset,
        ),
      ],
      mosaicChromatic => [
        (TipDiagramKind.filter, Icons.grid_on, l10n.filterNameMosaic),
        (
          TipDiagramKind.color,
          Icons.color_lens_outlined,
          l10n.filterNameChromaticAberration,
        ),
        (TipDiagramKind.media, Icons.live_tv, l10n.timelinePreviewPlaceholder),
      ],
      pixelToneRetro => [
        (
          TipDiagramKind.canvas,
          Icons.grid_view,
          '${l10n.assetTagPixelArt} / ${l10n.stampTitle}',
        ),
        (TipDiagramKind.color, Icons.grid_on, l10n.toneTitle),
        (
          TipDiagramKind.canvas,
          Icons.visibility_outlined,
          l10n.timelinePreviewPlaceholder,
        ),
      ],
      blurVignetteBg => [
        (TipDiagramKind.layers, Icons.layers_outlined, l10n.assetTagBackground),
        (TipDiagramKind.filter, Icons.blur_on, l10n.filterNameGaussianBlur),
        (
          TipDiagramKind.filter,
          Icons.brightness_4_outlined,
          l10n.filterNameVignette,
        ),
      ],
      sepiaVignette => [
        (
          TipDiagramKind.filter,
          Icons.photo_filter,
          l10n.timelineEffectTypeSepia,
        ),
        (
          TipDiagramKind.filter,
          Icons.brightness_4_outlined,
          l10n.filterNameVignette,
        ),
        (
          TipDiagramKind.timeline,
          Icons.play_arrow,
          l10n.timelinePreviewPlaceholder,
        ),
      ],
      transferDevice => [
        (TipDiagramKind.settings, Icons.tune, l10n.transferScreenTitle),
        (TipDiagramKind.export, Icons.upload_file, l10n.transferExport),
        (TipDiagramKind.devices, Icons.download, l10n.transferImport),
      ],
      transferCustomization => [
        (
          TipDiagramKind.settings,
          Icons.brush_outlined,
          '${l10n.transferItemBrush} / ${l10n.helpQuickToolTitle}',
        ),
        (TipDiagramKind.export, Icons.upload_file, l10n.transferScreenTitle),
        (TipDiagramKind.devices, Icons.download, l10n.transferImport),
      ],
    };
  }
}

// Use the control name in compact diagrams; its explanation is in the body.
String _controlName(String label) => label.split(RegExp(r"\s*[(（]")).first;
