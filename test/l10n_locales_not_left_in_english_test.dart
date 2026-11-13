// スペイン語・フランス語・韓国語・簡体字・繁体字のARBに、英語のまま残った
// 文が無いことの見張り。
//
// ホームの文をARBへ移したとき、訳を入れ忘れて英語の文をそのまま置くと、
// 画面の部品を走査する見張り（かな・漢字・ハングルの直書き）では見つからない。
// 英語と同じ綴りでよいのは、言語の自称・形式名・単位・アプリ名・
// プランの名前と、その言語でも同じ綴りの語（下の許可リスト）だけ。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// どの言語でも英語と同じ綴りでよいもの（キー → 理由）。
const _sameEverywhere = {
  'settingsLanguageEnglish': '言語の自称',
  'settingsLanguageFrench': '言語の自称',
  'settingsLanguageSpanish': '言語の自称',
  'exportFormatMp4': 'ファイル形式の名前',
  'exportFormatGif': 'ファイル形式の名前',
  'exportFormatAvi': 'ファイル形式の名前',
  'penSubToolBrushSizeOpacity': '単位（px・%）だけ',
  'brushSettingsFadeOff': 'どの言語のUIでも「OFF」と書く',
  'commonOff': 'どの言語のUIでも「OFF」と書く',
  'storageCategoryNiarimTotal': 'アプリ名',
  'helpCategoryPremium': 'プランの名前（Premium）',
  'premiumScreenTitle': 'プランの名前（Premium）',
  'premiumComparisonPremium': 'プランの名前（Premium）',
};

/// 言語ごとに、英語と同じ綴りでよいもの（その言語でも同じ綴りの語・単位）。
const _sameInLocale = <String, Set<String>>{
  'es': {
    'assetTagManga',
    'assetTagPixelArt',
    'blendModeColor',
    'blendModeNormal',
    'brushSettingsMixingOff',
    'canvasAutofillCheckNormal',
    'canvasTextHorizontal',
    'canvasTextVertical',
    'communityMuteNo',
    'communityPostErrorLabel',
    'communityTabRanking',
    'communityVisibilityPublishedBadge',
    'customAutomationNo',
    'exportFpsLabel',
    'filterInkPoolColor',
    'filterLevelsGamma',
    'helpPremiumEntryTitle',
    'homeProjectMeta',
    'layerPanelBrightnessToAlphaColorButton',
    'onionSkinColorLabel',
    'pcStatusFps',
    'penSettingsCurveNormal',
    'premiumValueNo',
    'projectListMaterialAudio',
    'timelineAddAudioTooltip',
    'timelineCameraZoomLabel',
    'timelineColorLabel',
    'timelineEffectTypeSepia',
  },
  'fr': {
    'assetTagManga',
    'assetTagPixelArt',
    'assetTagTexture',
    'autofillPartGradientTypeLabel',
    'blendModeExclusion',
    'blendModeNormal',
    'blendModeSaturation',
    'brushSettingsFadeDistanceLabel',
    'brushSettingsMixingTexture',
    'canvasAutofillCheckNormal',
    'canvasShapeRect',
    'canvasTextHorizontal',
    'canvasTextVertical',
    'colorPickerPaletteLabel',
    'commonOk',
    'commonPause',
    'communityFloatingPreviewPauseTooltip',
    'communityFollowNotificationsTooltip',

    'communityVisibilityPublishedBadge',
    'creatorMissionActivityTitle',
    'exportFormatSection',
    'exportPresetStandard',
    'exportScreenTitle',
    'filterAuroraHologramSaturation',
    'filterColorAdjustSaturationLabel',
    'filterLevelsGamma',
    'filterToneCurveLinear',
    'frameStripTimelineModeLabel',
    'helpAudioClipTitle',
    'helpCategoryAnimation',
    'helpCategoryExport',
    'helpPremiumEntryTitle',
    'layerKeyframeRotationLabel',
    'licenseTermsArt1Title',
    'missionDurationMinutes',
    'penSettingsCurveNormal',
    'privacyPolicyArt9Title',
    'projectDetailPauseTooltip',
    'projectListMaterialAudio',
    'projectListMaterialImage',
    'rewardNavigationMissions',
    'rewardUnlockHistoryMission',
    'rewardUnlockMissionTitle',
    'rulerDivisions',
    'stampRotationLabel',
    'storageCategoryCache',
    // テーマの見本の投稿欄の見出し（仏語でも Description）。
    'themePreviewSampleDescriptionLabel',
    'timelineAddAudioTooltip',
    'timelineAddImageTooltip',
    'timelineCameraRotationLabel',
    'timelineCameraZoomLabel',
    'timelineCanvasSizeAngleLabel',
    'timelineClipVolumeLabel',
    'timelineEditSectionTransform',
    'timelineMaskEllipse',
    'timelineMaskRectangle',
    'timelineWatermarkAngleLabel',
  },
  // FPS は単位。Premium はプランの名前。
  'ko': {'exportFpsLabel', 'pcStatusFps'},
  'zh': {'exportFpsLabel', 'pcStatusFps', 'helpPremiumEntryTitle'},
  'zh_Hant': {'exportFpsLabel', 'pcStatusFps', 'helpPremiumEntryTitle'},
};

Map<String, String> _values(String locale) {
  final data =
      json.decode(File('lib/l10n/app_$locale.arb').readAsStringSync())
          as Map<String, dynamic>;
  return {
    for (final MapEntry(:key, :value) in data.entries)
      if (!key.startsWith('@') && value is String) key: value,
  };
}

/// 画面のコード（lib）で使っているキー。使っていないキーは画面に出ないので
/// 見ない（ここで名前を挙げると、未使用のキーの見張りから隠れてしまう）。
Set<String> _keysUsedInLib() {
  final words = <String>{};
  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    if (f.path.contains('lib/l10n/app_localizations')) continue;
    words.addAll(
      RegExp(
        r'[A-Za-z_][A-Za-z0-9_]*',
      ).allMatches(f.readAsStringSync()).map((m) => m.group(0)!),
    );
  }
  return words;
}

/// 置き換えの部分（{name}・{count, plural, …}の外側）を除いて英字の語が残るか。
bool _hasLatinWord(String value) => RegExp(
  '[A-Za-z]{2,}',
).hasMatch(value.replaceAll(RegExp(r'\{[^{}]*\}'), ''));

void main() {
  final en = _values('en');
  final used = _keysUsedInLib();

  for (final MapEntry(key: locale, value: allowed) in _sameInLocale.entries) {
    test('$locale のARBに英語のまま残った文が無い', () {
      final offenders = [
        for (final MapEntry(:key, :value) in _values(locale).entries)
          if (used.contains(key) &&
              value == en[key] &&
              _hasLatinWord(value) &&
              !_sameEverywhere.containsKey(key) &&
              !allowed.contains(key))
            '$key: $value',
      ];
      expect(
        offenders,
        isEmpty,
        reason:
            '$locale の訳を手で入れる（その言語でも同じ綴りの語なら許可リストへ）:\n'
            '${offenders.join('\n')}',
      );
    });

    test('$locale の許可リストのキーは今も英語と同じ（違えば外す）', () {
      final values = _values(locale);
      for (final key in [..._sameEverywhere.keys, ...allowed]) {
        expect(values[key], en[key], reason: '$locale $key は英語と違うので許可リストから外す');
      }
    });
  }
}
