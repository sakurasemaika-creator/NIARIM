import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';

/// メイキング・読み上げの画面の文言（ARBの`making…`のキー）。
abstract final class MakingStrings {
  static AppLocalizations _l(BuildContext context) =>
      AppLocalizations.of(context)!;

  static String recordProject(BuildContext context) =>
      _l(context).makingRecordProject;

  static String recordProjectHint(BuildContext context) =>
      _l(context).makingRecordProjectHint;

  static String readAloud(BuildContext context) => _l(context).makingReadAloud;

  static String speechText(BuildContext context) =>
      _l(context).makingSpeechText;

  static String voice(BuildContext context) => _l(context).makingVoice;

  static String rate(BuildContext context) => _l(context).makingRate;

  static String pitch(BuildContext context) => _l(context).makingPitch;

  static String speechNotice(BuildContext context) =>
      _l(context).makingSpeechNotice;

  static String manageVoices(BuildContext context) =>
      _l(context).makingManageVoices;

  static String noVoices(BuildContext context) => _l(context).makingNoVoices;

  static String generateAndAdd(BuildContext context) =>
      _l(context).makingGenerateAndAdd;

  static String startFrame(BuildContext context) =>
      _l(context).makingStartFrame;

  static String playMaking(BuildContext context) => _l(context).makingPlay;

  static String makingTitle(BuildContext context) => _l(context).makingTitle;

  static String makingEmpty(BuildContext context) => _l(context).makingEmpty;
  static String loadFailed(BuildContext context) =>
      _l(context).makingLoadFailed;

  static String storageLimit(BuildContext context) =>
      _l(context).makingStorageLimit;

  static String formatWebm(BuildContext context) =>
      _l(context).makingFormatWebm;

  static String exportLabel(BuildContext context) =>
      _l(context).makingExportLabel;

  static String exportComplete(BuildContext context) =>
      _l(context).makingExportComplete;

  static String exportFailed(BuildContext context) =>
      _l(context).makingExportFailed;

  static String deleteHistory(BuildContext context) =>
      _l(context).makingDeleteHistory;

  static String deleteHistoryConfirm(BuildContext context) =>
      _l(context).makingDeleteHistoryConfirm;

  static String deleteFailed(BuildContext context) =>
      _l(context).makingDeleteFailed;

  static String historyDeleted(BuildContext context) =>
      _l(context).makingHistoryDeleted;

  static String frameCounter(BuildContext context, int current, int total) =>
      _l(context).makingFrameCounter(current, total);

  static String speechFailed(BuildContext context) =>
      _l(context).makingSpeechFailed;
}
