import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ja'),
    Locale('ko'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];

  /// No description provided for @homeTabProjects.
  ///
  /// In ja, this message translates to:
  /// **'プロジェクト'**
  String get homeTabProjects;

  /// No description provided for @homeTabShared.
  ///
  /// In ja, this message translates to:
  /// **'共有'**
  String get homeTabShared;

  /// No description provided for @homeTabTrash.
  ///
  /// In ja, this message translates to:
  /// **'ゴミ箱'**
  String get homeTabTrash;

  /// No description provided for @homeTabWorks.
  ///
  /// In ja, this message translates to:
  /// **'作品一覧'**
  String get homeTabWorks;

  /// No description provided for @homeTabBookmarked.
  ///
  /// In ja, this message translates to:
  /// **'ブクマ済み'**
  String get homeTabBookmarked;

  /// No description provided for @homeBookmarkedComingSoonTitle.
  ///
  /// In ja, this message translates to:
  /// **'近日公開'**
  String get homeBookmarkedComingSoonTitle;

  /// No description provided for @homeBookmarkedComingSoonBody.
  ///
  /// In ja, this message translates to:
  /// **'「みんなのアニメを見る」機能の実装後、ブックマークした他ユーザーの公開作品をここに一覧表示できるようになります。'**
  String get homeBookmarkedComingSoonBody;

  /// No description provided for @homeSearchHint.
  ///
  /// In ja, this message translates to:
  /// **'プロジェクト名で検索'**
  String get homeSearchHint;

  /// No description provided for @homeBackToSplashTooltip.
  ///
  /// In ja, this message translates to:
  /// **'起動画面に戻る'**
  String get homeBackToSplashTooltip;

  /// No description provided for @homeFavoritesOnly.
  ///
  /// In ja, this message translates to:
  /// **'お気に入り'**
  String get homeFavoritesOnly;

  /// No description provided for @homeAddSheetNewProject.
  ///
  /// In ja, this message translates to:
  /// **'新規プロジェクト'**
  String get homeAddSheetNewProject;

  /// No description provided for @homeAddSheetNewFolder.
  ///
  /// In ja, this message translates to:
  /// **'新規フォルダ'**
  String get homeAddSheetNewFolder;

  /// No description provided for @homeSelectionAllSelect.
  ///
  /// In ja, this message translates to:
  /// **'全選択'**
  String get homeSelectionAllSelect;

  /// No description provided for @homeSelectionAllDeselect.
  ///
  /// In ja, this message translates to:
  /// **'全解除'**
  String get homeSelectionAllDeselect;

  /// No description provided for @homeSelectionAddFavorite.
  ///
  /// In ja, this message translates to:
  /// **'お気に入りに登録'**
  String get homeSelectionAddFavorite;

  /// No description provided for @homeSelectionRemoveFavorite.
  ///
  /// In ja, this message translates to:
  /// **'お気に入りを解除'**
  String get homeSelectionRemoveFavorite;

  /// No description provided for @homeSelectionCount.
  ///
  /// In ja, this message translates to:
  /// **'{count}件選択中'**
  String homeSelectionCount(int count);

  /// No description provided for @homeMoveToTrash.
  ///
  /// In ja, this message translates to:
  /// **'ゴミ箱へ移動'**
  String get homeMoveToTrash;

  /// No description provided for @homeMoveToTrashConfirm.
  ///
  /// In ja, this message translates to:
  /// **'{count}件をゴミ箱へ移動しますか？'**
  String homeMoveToTrashConfirm(int count);

  /// No description provided for @commonMove.
  ///
  /// In ja, this message translates to:
  /// **'移動'**
  String get commonMove;

  /// No description provided for @homeShareFileDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'共有ファイル'**
  String get homeShareFileDialogTitle;

  /// No description provided for @homeShareFileDialogContent.
  ///
  /// In ja, this message translates to:
  /// **'この共有ファイルを複製して通常プロジェクトとして保存しますか？'**
  String get homeShareFileDialogContent;

  /// No description provided for @homeMissingFontsSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'不足フォントがあります。{names}'**
  String homeMissingFontsSnackbar(String names);

  /// No description provided for @homeSharedImportedSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'プロジェクトタブへ追加しました'**
  String get homeSharedImportedSnackbar;

  /// No description provided for @homeSharedImportFailedSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'共有ファイルの読み込みに失敗しました: {error}'**
  String homeSharedImportFailedSnackbar(String error);

  /// No description provided for @homeViewModeLarge.
  ///
  /// In ja, this message translates to:
  /// **'大'**
  String get homeViewModeLarge;

  /// No description provided for @homeViewModeMedium.
  ///
  /// In ja, this message translates to:
  /// **'中'**
  String get homeViewModeMedium;

  /// No description provided for @homeViewModeSmall.
  ///
  /// In ja, this message translates to:
  /// **'小'**
  String get homeViewModeSmall;

  /// No description provided for @homeViewModeDetail.
  ///
  /// In ja, this message translates to:
  /// **'詳細'**
  String get homeViewModeDetail;

  /// No description provided for @homeSortFieldName.
  ///
  /// In ja, this message translates to:
  /// **'名前'**
  String get homeSortFieldName;

  /// No description provided for @homeSortFieldUpdated.
  ///
  /// In ja, this message translates to:
  /// **'更新日時'**
  String get homeSortFieldUpdated;

  /// No description provided for @homeSortDirectionAscTooltip.
  ///
  /// In ja, this message translates to:
  /// **'昇順（タップで降順に切り替え）'**
  String get homeSortDirectionAscTooltip;

  /// No description provided for @homeSortDirectionDescTooltip.
  ///
  /// In ja, this message translates to:
  /// **'降順（タップで昇順に切り替え）'**
  String get homeSortDirectionDescTooltip;

  /// No description provided for @homeSharedEmpty.
  ///
  /// In ja, this message translates to:
  /// **'共有プロジェクトがありません'**
  String get homeSharedEmpty;

  /// No description provided for @homeProjectMeta.
  ///
  /// In ja, this message translates to:
  /// **'{fps}fps · {duration}秒'**
  String homeProjectMeta(int fps, int duration);

  /// No description provided for @homeTrashEmpty.
  ///
  /// In ja, this message translates to:
  /// **'ゴミ箱は空です'**
  String get homeTrashEmpty;

  /// No description provided for @homeTrashDeletedOn.
  ///
  /// In ja, this message translates to:
  /// **'{date} 削除'**
  String homeTrashDeletedOn(String date);

  /// No description provided for @homePermanentDelete.
  ///
  /// In ja, this message translates to:
  /// **'完全削除'**
  String get homePermanentDelete;

  /// No description provided for @homePermanentDeleteConfirmTitle.
  ///
  /// In ja, this message translates to:
  /// **'完全に削除しますか？'**
  String get homePermanentDeleteConfirmTitle;

  /// No description provided for @homePermanentDeleteConfirmBody.
  ///
  /// In ja, this message translates to:
  /// **'元に戻すことはできません。'**
  String get homePermanentDeleteConfirmBody;

  /// No description provided for @homeWorksEmpty.
  ///
  /// In ja, this message translates to:
  /// **'書き出した作品がありません'**
  String get homeWorksEmpty;

  /// No description provided for @homeWorksEmptyHint.
  ///
  /// In ja, this message translates to:
  /// **'キャンバスの書き出しから動画・GIFを作成すると\nここに表示されます'**
  String get homeWorksEmptyHint;

  /// No description provided for @homeShareOpenWith.
  ///
  /// In ja, this message translates to:
  /// **'共有・写真アプリ等で開く'**
  String get homeShareOpenWith;

  /// No description provided for @homeWorkDeleteConfirmTitle.
  ///
  /// In ja, this message translates to:
  /// **'{name}を削除しますか？'**
  String homeWorkDeleteConfirmTitle(String name);

  /// No description provided for @homeWorkDeleteConfirmBody.
  ///
  /// In ja, this message translates to:
  /// **'端末内の書き出しファイルが削除されます。元に戻すことはできません。'**
  String get homeWorkDeleteConfirmBody;

  /// No description provided for @homePreviewFailed.
  ///
  /// In ja, this message translates to:
  /// **'プレビューを再生できません'**
  String get homePreviewFailed;

  /// No description provided for @homeFirstLaunchMessage.
  ///
  /// In ja, this message translates to:
  /// **'手描きアニメーションを制作できます'**
  String get homeFirstLaunchMessage;

  /// No description provided for @homeFirstLaunchStart.
  ///
  /// In ja, this message translates to:
  /// **'はじめる'**
  String get homeFirstLaunchStart;

  /// No description provided for @settingsScreenTitle.
  ///
  /// In ja, this message translates to:
  /// **'設定'**
  String get settingsScreenTitle;

  /// No description provided for @settingsBasicTitle.
  ///
  /// In ja, this message translates to:
  /// **'基本'**
  String get settingsBasicTitle;

  /// No description provided for @settingsBasicSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'FPS・背景色・言語'**
  String get settingsBasicSubtitle;

  /// No description provided for @settingsBasicSheetTitle.
  ///
  /// In ja, this message translates to:
  /// **'基本設定'**
  String get settingsBasicSheetTitle;

  /// No description provided for @settingsDefaultFps.
  ///
  /// In ja, this message translates to:
  /// **'デフォルトFPS'**
  String get settingsDefaultFps;

  /// No description provided for @settingsDefaultFpsSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'新規プロジェクト作成画面の初期値'**
  String get settingsDefaultFpsSubtitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In ja, this message translates to:
  /// **'言語'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageJapanese.
  ///
  /// In ja, this message translates to:
  /// **'日本語'**
  String get settingsLanguageJapanese;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In ja, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageChinese.
  ///
  /// In ja, this message translates to:
  /// **'简体中文'**
  String get settingsLanguageChinese;

  /// No description provided for @settingsLanguageKorean.
  ///
  /// In ja, this message translates to:
  /// **'한국어'**
  String get settingsLanguageKorean;

  /// No description provided for @settingsLanguageTraditionalChinese.
  ///
  /// In ja, this message translates to:
  /// **'繁體中文'**
  String get settingsLanguageTraditionalChinese;

  /// No description provided for @settingsLanguageFrench.
  ///
  /// In ja, this message translates to:
  /// **'Français'**
  String get settingsLanguageFrench;

  /// No description provided for @settingsLanguageSpanish.
  ///
  /// In ja, this message translates to:
  /// **'Español'**
  String get settingsLanguageSpanish;

  /// No description provided for @settingsSearchHint.
  ///
  /// In ja, this message translates to:
  /// **'設定を検索...'**
  String get settingsSearchHint;

  /// No description provided for @settingsPerformanceTitle.
  ///
  /// In ja, this message translates to:
  /// **'パフォーマンス'**
  String get settingsPerformanceTitle;

  /// No description provided for @settingsPerformanceSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'品質設定・Undo回数・ゴミ箱・動作の軽さ'**
  String get settingsPerformanceSubtitle;

  /// No description provided for @settingsGestureTitle.
  ///
  /// In ja, this message translates to:
  /// **'ジェスチャー'**
  String get settingsGestureTitle;

  /// No description provided for @settingsGestureSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'2本指タップ・長押し'**
  String get settingsGestureSubtitle;

  /// No description provided for @settingsPenTitle.
  ///
  /// In ja, this message translates to:
  /// **'ペン入力'**
  String get settingsPenTitle;

  /// No description provided for @settingsPenSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'筆圧・傾き・ペンボタン'**
  String get settingsPenSubtitle;

  /// No description provided for @settingsWorkspaceTitle.
  ///
  /// In ja, this message translates to:
  /// **'ワークスペース'**
  String get settingsWorkspaceTitle;

  /// No description provided for @settingsWorkspaceSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'ツールバー編集・パネル配置'**
  String get settingsWorkspaceSubtitle;

  /// No description provided for @settingsBucketTitle.
  ///
  /// In ja, this message translates to:
  /// **'バケツ塗り'**
  String get settingsBucketTitle;

  /// No description provided for @settingsBucketSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'許容誤差・拡張・線の下まで潜る'**
  String get settingsBucketSubtitle;

  /// No description provided for @settingsThemeTitle.
  ///
  /// In ja, this message translates to:
  /// **'テーマ・外観'**
  String get settingsThemeTitle;

  /// No description provided for @settingsThemeSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'テーマ設定・ワークスペース'**
  String get settingsThemeSubtitle;

  /// No description provided for @settingsWatermarkTitle.
  ///
  /// In ja, this message translates to:
  /// **'ウォーターマーク'**
  String get settingsWatermarkTitle;

  /// No description provided for @settingsWatermarkSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'カスタムウォーターマーク'**
  String get settingsWatermarkSubtitle;

  /// No description provided for @settingsTransferTitle.
  ///
  /// In ja, this message translates to:
  /// **'引き継ぎ'**
  String get settingsTransferTitle;

  /// No description provided for @settingsTransferSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'設定・素材・ブラシを他端末へ書き出し/読み込み'**
  String get settingsTransferSubtitle;

  /// No description provided for @settingsFontTitle.
  ///
  /// In ja, this message translates to:
  /// **'フォント管理'**
  String get settingsFontTitle;

  /// No description provided for @settingsFontSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'TTF/OTFの追加・検索・削除'**
  String get settingsFontSubtitle;

  /// No description provided for @settingsNoResults.
  ///
  /// In ja, this message translates to:
  /// **'該当する設定項目が見つかりません'**
  String get settingsNoResults;

  /// No description provided for @settingsTermsLicense.
  ///
  /// In ja, this message translates to:
  /// **'利用規約・ライセンス'**
  String get settingsTermsLicense;

  /// No description provided for @settingsDrawingAreaTitle.
  ///
  /// In ja, this message translates to:
  /// **'描画領域初期値'**
  String get settingsDrawingAreaTitle;

  /// No description provided for @settingsDrawingAreaHint.
  ///
  /// In ja, this message translates to:
  /// **'新規プロジェクト作成時の初期値となります。'**
  String get settingsDrawingAreaHint;

  /// No description provided for @settingsDrawingAreaWiden.
  ///
  /// In ja, this message translates to:
  /// **'描画領域を広くする'**
  String get settingsDrawingAreaWiden;

  /// No description provided for @settingsDrawingAreaScale.
  ///
  /// In ja, this message translates to:
  /// **'倍率'**
  String get settingsDrawingAreaScale;

  /// No description provided for @settingsScaleValue.
  ///
  /// In ja, this message translates to:
  /// **'{scale}倍'**
  String settingsScaleValue(String scale);

  /// No description provided for @commonCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get commonCancel;

  /// No description provided for @commonCreate.
  ///
  /// In ja, this message translates to:
  /// **'作成'**
  String get commonCreate;

  /// No description provided for @commonChange.
  ///
  /// In ja, this message translates to:
  /// **'変更'**
  String get commonChange;

  /// No description provided for @commonDelete.
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get commonDelete;

  /// No description provided for @confirmDeleteGenericBody.
  ///
  /// In ja, this message translates to:
  /// **'本当に削除しますか？この操作は取り消せません。'**
  String get confirmDeleteGenericBody;

  /// No description provided for @confirmDeleteNamedBody.
  ///
  /// In ja, this message translates to:
  /// **'「{name}」を削除しますか？この操作は取り消せません。'**
  String confirmDeleteNamedBody(String name);

  /// No description provided for @commonFavoriteDeleteBlocked.
  ///
  /// In ja, this message translates to:
  /// **'お気に入り登録中は削除できません。先にお気に入りを解除してください。'**
  String get commonFavoriteDeleteBlocked;

  /// No description provided for @commonSave.
  ///
  /// In ja, this message translates to:
  /// **'保存'**
  String get commonSave;

  /// No description provided for @commonRestore.
  ///
  /// In ja, this message translates to:
  /// **'復元'**
  String get commonRestore;

  /// No description provided for @commonClose.
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get commonClose;

  /// No description provided for @commonRename.
  ///
  /// In ja, this message translates to:
  /// **'名前変更'**
  String get commonRename;

  /// No description provided for @commonCopy.
  ///
  /// In ja, this message translates to:
  /// **'コピー'**
  String get commonCopy;

  /// No description provided for @commonCut.
  ///
  /// In ja, this message translates to:
  /// **'切り取り'**
  String get commonCut;

  /// No description provided for @commonPaste.
  ///
  /// In ja, this message translates to:
  /// **'貼り付け'**
  String get commonPaste;

  /// No description provided for @commonDuplicate.
  ///
  /// In ja, this message translates to:
  /// **'複製'**
  String get commonDuplicate;

  /// No description provided for @homePasteTooltip.
  ///
  /// In ja, this message translates to:
  /// **'{count}件を貼り付け'**
  String homePasteTooltip(int count);

  /// No description provided for @homePasteSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'貼り付けました'**
  String get homePasteSnackbar;

  /// No description provided for @commonOk.
  ///
  /// In ja, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @gestureSettingsTitle.
  ///
  /// In ja, this message translates to:
  /// **'ジェスチャー設定'**
  String get gestureSettingsTitle;

  /// No description provided for @gestureTwoFingerTap.
  ///
  /// In ja, this message translates to:
  /// **'2本指タップ'**
  String get gestureTwoFingerTap;

  /// No description provided for @gestureThreeFingerTap.
  ///
  /// In ja, this message translates to:
  /// **'3本指タップ'**
  String get gestureThreeFingerTap;

  /// No description provided for @gestureTwoFingerSwipe.
  ///
  /// In ja, this message translates to:
  /// **'2本指スワイプ左右'**
  String get gestureTwoFingerSwipe;

  /// No description provided for @gestureLongPress.
  ///
  /// In ja, this message translates to:
  /// **'長押し'**
  String get gestureLongPress;

  /// No description provided for @gestureHoldEyedropperSection.
  ///
  /// In ja, this message translates to:
  /// **'長押しスポイト'**
  String get gestureHoldEyedropperSection;

  /// No description provided for @gestureHoldEyedropperTitle.
  ///
  /// In ja, this message translates to:
  /// **'長押しでスポイトを起動'**
  String get gestureHoldEyedropperTitle;

  /// No description provided for @gestureHoldEyedropperHint.
  ///
  /// In ja, this message translates to:
  /// **'ペン・消しゴムで描画中、指を動かさず一定時間押し続けると、その場の色を拾って現在色に反映します。'**
  String get gestureHoldEyedropperHint;

  /// No description provided for @gestureHoldEyedropperDurationLabel.
  ///
  /// In ja, this message translates to:
  /// **'保持時間'**
  String get gestureHoldEyedropperDurationLabel;

  /// No description provided for @gestureHoldEyedropperSecondsValue.
  ///
  /// In ja, this message translates to:
  /// **'{seconds}秒'**
  String gestureHoldEyedropperSecondsValue(String seconds);

  /// No description provided for @gestureActionEyedropper.
  ///
  /// In ja, this message translates to:
  /// **'スポイト'**
  String get gestureActionEyedropper;

  /// No description provided for @gestureActionPanTool.
  ///
  /// In ja, this message translates to:
  /// **'手のひらツール'**
  String get gestureActionPanTool;

  /// No description provided for @gestureActionEraserToggle.
  ///
  /// In ja, this message translates to:
  /// **'消しゴム切替'**
  String get gestureActionEraserToggle;

  /// No description provided for @gestureActionBrushToggle.
  ///
  /// In ja, this message translates to:
  /// **'ブラシ切替'**
  String get gestureActionBrushToggle;

  /// No description provided for @gestureActionFrameMove.
  ///
  /// In ja, this message translates to:
  /// **'フレーム移動'**
  String get gestureActionFrameMove;

  /// No description provided for @gestureActionNextTool.
  ///
  /// In ja, this message translates to:
  /// **'ツール早替え'**
  String get gestureActionNextTool;

  /// No description provided for @gestureActionOnionSkinToggle.
  ///
  /// In ja, this message translates to:
  /// **'オニオンスキンON/OFF'**
  String get gestureActionOnionSkinToggle;

  /// No description provided for @gestureActionNone.
  ///
  /// In ja, this message translates to:
  /// **'何もしない'**
  String get gestureActionNone;

  /// No description provided for @homeDrawerAppTagline.
  ///
  /// In ja, this message translates to:
  /// **'手描きアニメ制作アプリ'**
  String get homeDrawerAppTagline;

  /// No description provided for @homeDrawerAutofillPreset.
  ///
  /// In ja, this message translates to:
  /// **'自動塗り設定'**
  String get homeDrawerAutofillPreset;

  /// No description provided for @homeDrawerSettings.
  ///
  /// In ja, this message translates to:
  /// **'設定'**
  String get homeDrawerSettings;

  /// No description provided for @homeDrawerHelp.
  ///
  /// In ja, this message translates to:
  /// **'ヘルプ'**
  String get homeDrawerHelp;

  /// No description provided for @homeDrawerTips.
  ///
  /// In ja, this message translates to:
  /// **'活用Tips'**
  String get homeDrawerTips;

  /// No description provided for @homeDrawerPremium.
  ///
  /// In ja, this message translates to:
  /// **'プレミアム'**
  String get homeDrawerPremium;

  /// No description provided for @gestureActionNoneShort.
  ///
  /// In ja, this message translates to:
  /// **'なし'**
  String get gestureActionNoneShort;

  /// No description provided for @pressureTryDrawHint.
  ///
  /// In ja, this message translates to:
  /// **'この設定で試し書きできます（ペンの場合、実際の筆圧が反映されます）'**
  String get pressureTryDrawHint;

  /// No description provided for @pressureTryDrawClear.
  ///
  /// In ja, this message translates to:
  /// **'クリア'**
  String get pressureTryDrawClear;

  /// No description provided for @penSettingsTitle.
  ///
  /// In ja, this message translates to:
  /// **'ペン入力設定'**
  String get penSettingsTitle;

  /// No description provided for @penSettingsCurveSection.
  ///
  /// In ja, this message translates to:
  /// **'筆圧カーブ'**
  String get penSettingsCurveSection;

  /// No description provided for @penSettingsCurveHint.
  ///
  /// In ja, this message translates to:
  /// **'弱い設定ほど筆圧の立ち上がりが緩やかに、強い設定ほど鋭くなります。'**
  String get penSettingsCurveHint;

  /// No description provided for @penSettingsCurveWeak.
  ///
  /// In ja, this message translates to:
  /// **'弱'**
  String get penSettingsCurveWeak;

  /// No description provided for @penSettingsCurveNormal.
  ///
  /// In ja, this message translates to:
  /// **'普通'**
  String get penSettingsCurveNormal;

  /// No description provided for @penSettingsCurveStrong.
  ///
  /// In ja, this message translates to:
  /// **'強'**
  String get penSettingsCurveStrong;

  /// No description provided for @penSettingsCurveCustom.
  ///
  /// In ja, this message translates to:
  /// **'カスタム'**
  String get penSettingsCurveCustom;

  /// No description provided for @penSettingsCustomGraphHint.
  ///
  /// In ja, this message translates to:
  /// **'グラフの空いている場所をタップすると点を追加（最大10個）、点をドラッグで移動、ダブルタップで削除できます（始点・終点は削除できません）。'**
  String get penSettingsCustomGraphHint;

  /// No description provided for @penSettingsResetCurveButton.
  ///
  /// In ja, this message translates to:
  /// **'デフォルトにリセット'**
  String get penSettingsResetCurveButton;

  /// No description provided for @penSettingsPerBrushNote.
  ///
  /// In ja, this message translates to:
  /// **'※ 筆圧の「サイズ／不透明度に反映」設定はブラシごとの個別設定です（ブラシ設定パネルで変更）。'**
  String get penSettingsPerBrushNote;

  /// No description provided for @penSettingsButtonSection.
  ///
  /// In ja, this message translates to:
  /// **'ペンボタン設定'**
  String get penSettingsButtonSection;

  /// No description provided for @penSettingsButton1.
  ///
  /// In ja, this message translates to:
  /// **'ボタン1'**
  String get penSettingsButton1;

  /// No description provided for @penSettingsButton2.
  ///
  /// In ja, this message translates to:
  /// **'ボタン2'**
  String get penSettingsButton2;

  /// No description provided for @bucketSettingsTitle.
  ///
  /// In ja, this message translates to:
  /// **'バケツ塗り設定'**
  String get bucketSettingsTitle;

  /// No description provided for @bucketSettingsToleranceSection.
  ///
  /// In ja, this message translates to:
  /// **'許容誤差'**
  String get bucketSettingsToleranceSection;

  /// No description provided for @bucketSettingsToleranceHint.
  ///
  /// In ja, this message translates to:
  /// **'タップした位置の色からどこまでの色差を同じ領域とみなすかを調整します。値が大きいほど、色の境目がぼんやりしていても塗りが広がりやすくなります。'**
  String get bucketSettingsToleranceHint;

  /// No description provided for @bucketSettingsExpandSection.
  ///
  /// In ja, this message translates to:
  /// **'拡張'**
  String get bucketSettingsExpandSection;

  /// No description provided for @bucketSettingsExpandHint.
  ///
  /// In ja, this message translates to:
  /// **'塗った領域を境界の外側へ指定px分だけ広げ、線画とのわずかな隙間（塗り残し）をカバーします。'**
  String get bucketSettingsExpandHint;

  /// No description provided for @bucketSettingsUnderLineTitle.
  ///
  /// In ja, this message translates to:
  /// **'線の下まで潜る'**
  String get bucketSettingsUnderLineTitle;

  /// No description provided for @bucketSettingsUnderLineHint.
  ///
  /// In ja, this message translates to:
  /// **'拡張分を線画の上から塗りつぶさず、線の見た目を保ったまま背後へ塗り色を回り込ませます。線のアンチエイリアス部分に隙間が出にくくなります。'**
  String get bucketSettingsUnderLineHint;

  /// No description provided for @bucketSettingsUnderLineDisabledHint.
  ///
  /// In ja, this message translates to:
  /// **'「拡張」が0pxの場合は効果がありません。'**
  String get bucketSettingsUnderLineDisabledHint;

  /// No description provided for @fontCatalogSearchHint.
  ///
  /// In ja, this message translates to:
  /// **'フォント名で検索...（全{count}書体）'**
  String fontCatalogSearchHint(int count);

  /// No description provided for @fontCatalogAll.
  ///
  /// In ja, this message translates to:
  /// **'すべて'**
  String get fontCatalogAll;

  /// No description provided for @fontCatalogNoResults.
  ///
  /// In ja, this message translates to:
  /// **'該当するフォントが見つかりません'**
  String get fontCatalogNoResults;

  /// No description provided for @rulerPanelTitle.
  ///
  /// In ja, this message translates to:
  /// **'定規'**
  String get rulerPanelTitle;

  /// No description provided for @rulerTypeLine.
  ///
  /// In ja, this message translates to:
  /// **'直線定規'**
  String get rulerTypeLine;

  /// No description provided for @rulerTypeEllipse.
  ///
  /// In ja, this message translates to:
  /// **'楕円定規'**
  String get rulerTypeEllipse;

  /// No description provided for @rulerTypeRadial.
  ///
  /// In ja, this message translates to:
  /// **'集中線定規'**
  String get rulerTypeRadial;

  /// No description provided for @rulerTypeOnePoint.
  ///
  /// In ja, this message translates to:
  /// **'1点透視'**
  String get rulerTypeOnePoint;

  /// No description provided for @rulerTypeTwoPoint.
  ///
  /// In ja, this message translates to:
  /// **'2点透視'**
  String get rulerTypeTwoPoint;

  /// No description provided for @rulerTypeThreePoint.
  ///
  /// In ja, this message translates to:
  /// **'3点透視'**
  String get rulerTypeThreePoint;

  /// No description provided for @rulerDivisions.
  ///
  /// In ja, this message translates to:
  /// **'分割数'**
  String get rulerDivisions;

  /// No description provided for @transferScreenTitle.
  ///
  /// In ja, this message translates to:
  /// **'引き継ぎ（.niatra）'**
  String get transferScreenTitle;

  /// No description provided for @transferInstructionHint.
  ///
  /// In ja, this message translates to:
  /// **'他の端末へ引き継ぐ項目を選択してください。'**
  String get transferInstructionHint;

  /// No description provided for @transferItemSettings.
  ///
  /// In ja, this message translates to:
  /// **'設定'**
  String get transferItemSettings;

  /// No description provided for @transferItemMaterials.
  ///
  /// In ja, this message translates to:
  /// **'素材'**
  String get transferItemMaterials;

  /// No description provided for @transferItemBrush.
  ///
  /// In ja, this message translates to:
  /// **'ブラシ'**
  String get transferItemBrush;

  /// No description provided for @transferItemPresets.
  ///
  /// In ja, this message translates to:
  /// **'自動塗り設定'**
  String get transferItemPresets;

  /// No description provided for @transferItemTheme.
  ///
  /// In ja, this message translates to:
  /// **'テーマ'**
  String get transferItemTheme;

  /// No description provided for @transferItemPalette.
  ///
  /// In ja, this message translates to:
  /// **'パレット（カラーピッカー・ドット絵専用）'**
  String get transferItemPalette;

  /// No description provided for @transferProjectsSectionTitle.
  ///
  /// In ja, this message translates to:
  /// **'制作中のプロジェクト（任意）'**
  String get transferProjectsSectionTitle;

  /// No description provided for @transferProjectsHint.
  ///
  /// In ja, this message translates to:
  /// **'必要なプロジェクトだけ選んで引き継ぎ内容に含められます。選択したプロジェクトは素材・フォントも含めて丸ごと引き継がれます。'**
  String get transferProjectsHint;

  /// No description provided for @transferProjectsEmpty.
  ///
  /// In ja, this message translates to:
  /// **'プロジェクトがありません。'**
  String get transferProjectsEmpty;

  /// No description provided for @transferImport.
  ///
  /// In ja, this message translates to:
  /// **'読み込み'**
  String get transferImport;

  /// No description provided for @transferExport.
  ///
  /// In ja, this message translates to:
  /// **'書き出し'**
  String get transferExport;

  /// No description provided for @transferExportSuccessSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'.niatraファイルを書き出しました'**
  String get transferExportSuccessSnackbar;

  /// No description provided for @transferExportFailedSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'書き出しに失敗しました: {error}'**
  String transferExportFailedSnackbar(String error);

  /// No description provided for @transferImportSuccessSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'.niatraファイルを読み込みました'**
  String get transferImportSuccessSnackbar;

  /// No description provided for @transferImportFailedSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'読み込みに失敗しました: {error}'**
  String transferImportFailedSnackbar(String error);

  /// No description provided for @folderManagementTitle.
  ///
  /// In ja, this message translates to:
  /// **'フォルダ管理'**
  String get folderManagementTitle;

  /// No description provided for @folderManagementCreateNew.
  ///
  /// In ja, this message translates to:
  /// **'新規作成'**
  String get folderManagementCreateNew;

  /// No description provided for @folderManagementEmpty.
  ///
  /// In ja, this message translates to:
  /// **'フォルダはまだありません'**
  String get folderManagementEmpty;

  /// No description provided for @folderNameLabel.
  ///
  /// In ja, this message translates to:
  /// **'フォルダ名'**
  String get folderNameLabel;

  /// No description provided for @folderMoveToTitle.
  ///
  /// In ja, this message translates to:
  /// **'フォルダへ移動'**
  String get folderMoveToTitle;

  /// No description provided for @folderNone.
  ///
  /// In ja, this message translates to:
  /// **'フォルダなし'**
  String get folderNone;

  /// No description provided for @creativeAssetNameLabel.
  ///
  /// In ja, this message translates to:
  /// **'名前'**
  String get creativeAssetNameLabel;

  /// No description provided for @commonAdd.
  ///
  /// In ja, this message translates to:
  /// **'追加'**
  String get commonAdd;

  /// No description provided for @commonSearch.
  ///
  /// In ja, this message translates to:
  /// **'検索'**
  String get commonSearch;

  /// No description provided for @autofillPresetSelectionTitle.
  ///
  /// In ja, this message translates to:
  /// **'使用する自動塗り設定'**
  String get autofillPresetSelectionTitle;

  /// No description provided for @autofillPresetSelectionHint.
  ///
  /// In ja, this message translates to:
  /// **'このプロジェクトで使う自動塗り設定だけを選ぶと、パーツ割り当て時に一覧が見やすくなります。'**
  String get autofillPresetSelectionHint;

  /// No description provided for @autofillPresetSelectionPartCount.
  ///
  /// In ja, this message translates to:
  /// **'{count}パーツ'**
  String autofillPresetSelectionPartCount(int count);

  /// No description provided for @autofillPresetSelectionButton.
  ///
  /// In ja, this message translates to:
  /// **'使用する自動塗り設定を選択'**
  String get autofillPresetSelectionButton;

  /// No description provided for @autofillPresetSelectionCountLabel.
  ///
  /// In ja, this message translates to:
  /// **'{count}件を使用'**
  String autofillPresetSelectionCountLabel(int count);

  /// No description provided for @commonEdit.
  ///
  /// In ja, this message translates to:
  /// **'編集'**
  String get commonEdit;

  /// No description provided for @commonFavoriteToggle.
  ///
  /// In ja, this message translates to:
  /// **'お気に入り登録/解除'**
  String get commonFavoriteToggle;

  /// No description provided for @commonIncrease.
  ///
  /// In ja, this message translates to:
  /// **'増やす'**
  String get commonIncrease;

  /// No description provided for @commonDecrease.
  ///
  /// In ja, this message translates to:
  /// **'減らす'**
  String get commonDecrease;

  /// No description provided for @commonPlay.
  ///
  /// In ja, this message translates to:
  /// **'再生'**
  String get commonPlay;

  /// No description provided for @commonPause.
  ///
  /// In ja, this message translates to:
  /// **'一時停止'**
  String get commonPause;

  /// No description provided for @fontCatalogDownloadTooltip.
  ///
  /// In ja, this message translates to:
  /// **'フォントをダウンロード'**
  String get fontCatalogDownloadTooltip;

  /// No description provided for @timelineBackToCanvasTooltip.
  ///
  /// In ja, this message translates to:
  /// **'保存してキャンバスに戻る'**
  String get timelineBackToCanvasTooltip;

  /// No description provided for @timelineBackToProjectListTooltip.
  ///
  /// In ja, this message translates to:
  /// **'プロジェクト一覧に戻る'**
  String get timelineBackToProjectListTooltip;

  /// No description provided for @timelineBackToProjectListDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'プロジェクト一覧に戻る'**
  String get timelineBackToProjectListDialogTitle;

  /// No description provided for @timelineBackToProjectListDialogBody.
  ///
  /// In ja, this message translates to:
  /// **'変更を保存してから戻りますか？'**
  String get timelineBackToProjectListDialogBody;

  /// No description provided for @timelineBackToProjectListSaveButton.
  ///
  /// In ja, this message translates to:
  /// **'保存して戻る'**
  String get timelineBackToProjectListSaveButton;

  /// No description provided for @timelineBackToProjectListDiscardButton.
  ///
  /// In ja, this message translates to:
  /// **'保存せず戻る'**
  String get timelineBackToProjectListDiscardButton;

  /// No description provided for @timelineSkipToStart.
  ///
  /// In ja, this message translates to:
  /// **'先頭フレームへ'**
  String get timelineSkipToStart;

  /// No description provided for @timelineStepBack.
  ///
  /// In ja, this message translates to:
  /// **'1フレーム戻る'**
  String get timelineStepBack;

  /// No description provided for @timelineStepForward.
  ///
  /// In ja, this message translates to:
  /// **'1フレーム進む'**
  String get timelineStepForward;

  /// No description provided for @timelineSkipToEnd.
  ///
  /// In ja, this message translates to:
  /// **'最終フレームへ'**
  String get timelineSkipToEnd;

  /// No description provided for @timelineLoopOnTooltip.
  ///
  /// In ja, this message translates to:
  /// **'ループ再生：ON（タップでOFFに）'**
  String get timelineLoopOnTooltip;

  /// No description provided for @timelineLoopOffTooltip.
  ///
  /// In ja, this message translates to:
  /// **'ループ再生：OFF（タップでONに）'**
  String get timelineLoopOffTooltip;

  /// No description provided for @quickToolPanelTitle.
  ///
  /// In ja, this message translates to:
  /// **'早替えツール設定'**
  String get quickToolPanelTitle;

  /// No description provided for @quickToolEmpty.
  ///
  /// In ja, this message translates to:
  /// **'登録されたツールがありません'**
  String get quickToolEmpty;

  /// No description provided for @quickToolAddCurrentBrush.
  ///
  /// In ja, this message translates to:
  /// **'現在のブラシを追加'**
  String get quickToolAddCurrentBrush;

  /// No description provided for @quickToolEraser.
  ///
  /// In ja, this message translates to:
  /// **'消しゴム'**
  String get quickToolEraser;

  /// No description provided for @quickToolEyedropper.
  ///
  /// In ja, this message translates to:
  /// **'スポイト'**
  String get quickToolEyedropper;

  /// No description provided for @quickToolBucket.
  ///
  /// In ja, this message translates to:
  /// **'バケツ'**
  String get quickToolBucket;

  /// No description provided for @quickToolSizeDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'{brushName}のサイズ'**
  String quickToolSizeDialogTitle(String brushName);

  /// No description provided for @settingsShortcutTitle.
  ///
  /// In ja, this message translates to:
  /// **'ショートカット設定'**
  String get settingsShortcutTitle;

  /// No description provided for @settingsShortcutSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'キーボード・左手デバイスにツールや操作を割り当て'**
  String get settingsShortcutSubtitle;

  /// No description provided for @shortcutSettingsTitle.
  ///
  /// In ja, this message translates to:
  /// **'ショートカット設定'**
  String get shortcutSettingsTitle;

  /// No description provided for @shortcutSettingsHint.
  ///
  /// In ja, this message translates to:
  /// **'キーボードや左手デバイスのキーに、ツール（ブラシ・太さまで指定可）やUndo/Redoなどの操作を割り当てられます。キャンバス・タイムラインの両方で使えます。'**
  String get shortcutSettingsHint;

  /// No description provided for @shortcutEmpty.
  ///
  /// In ja, this message translates to:
  /// **'登録されたショートカットがありません'**
  String get shortcutEmpty;

  /// No description provided for @shortcutCaptureTitle.
  ///
  /// In ja, this message translates to:
  /// **'キーを押してください'**
  String get shortcutCaptureTitle;

  /// No description provided for @shortcutCaptureHint.
  ///
  /// In ja, this message translates to:
  /// **'設定したいキーの組み合わせを押してください（Ctrl・Shift・Altなどの修飾キーも同時に押せます）。Escで取り消します。'**
  String get shortcutCaptureHint;

  /// No description provided for @shortcutChooseActionTitle.
  ///
  /// In ja, this message translates to:
  /// **'{combo} に何を割り当てますか？'**
  String shortcutChooseActionTitle(String combo);

  /// No description provided for @shortcutActionTypeTool.
  ///
  /// In ja, this message translates to:
  /// **'ツール選択'**
  String get shortcutActionTypeTool;

  /// No description provided for @shortcutActionTypeCommand.
  ///
  /// In ja, this message translates to:
  /// **'主要操作'**
  String get shortcutActionTypeCommand;

  /// No description provided for @shortcutCommandUndo.
  ///
  /// In ja, this message translates to:
  /// **'取り消し（Undo）'**
  String get shortcutCommandUndo;

  /// No description provided for @shortcutCommandRedo.
  ///
  /// In ja, this message translates to:
  /// **'やり直し（Redo）'**
  String get shortcutCommandRedo;

  /// No description provided for @shortcutCommandToggleLayerPanel.
  ///
  /// In ja, this message translates to:
  /// **'レイヤーパネル切替（キャンバス）'**
  String get shortcutCommandToggleLayerPanel;

  /// No description provided for @shortcutCommandPlayPause.
  ///
  /// In ja, this message translates to:
  /// **'再生／一時停止（タイムライン）'**
  String get shortcutCommandPlayPause;

  /// No description provided for @shortcutCommandPreviousFrame.
  ///
  /// In ja, this message translates to:
  /// **'1フレーム戻る（タイムライン）'**
  String get shortcutCommandPreviousFrame;

  /// No description provided for @shortcutCommandNextFrame.
  ///
  /// In ja, this message translates to:
  /// **'1フレーム進む（タイムライン）'**
  String get shortcutCommandNextFrame;

  /// No description provided for @shortcutCommandSelectAll.
  ///
  /// In ja, this message translates to:
  /// **'全選択'**
  String get shortcutCommandSelectAll;

  /// No description provided for @shortcutCommandCopy.
  ///
  /// In ja, this message translates to:
  /// **'コピー'**
  String get shortcutCommandCopy;

  /// No description provided for @shortcutCommandCut.
  ///
  /// In ja, this message translates to:
  /// **'切り取り'**
  String get shortcutCommandCut;

  /// No description provided for @shortcutCommandPaste.
  ///
  /// In ja, this message translates to:
  /// **'貼り付け'**
  String get shortcutCommandPaste;

  /// No description provided for @shortcutConflictTitle.
  ///
  /// In ja, this message translates to:
  /// **'すでに割り当てられています'**
  String get shortcutConflictTitle;

  /// No description provided for @shortcutConflictBody.
  ///
  /// In ja, this message translates to:
  /// **'{combo} には既に「{existingLabel}」が割り当てられています。上書きしますか？'**
  String shortcutConflictBody(String combo, String existingLabel);

  /// No description provided for @shortcutConflictOverwrite.
  ///
  /// In ja, this message translates to:
  /// **'上書き'**
  String get shortcutConflictOverwrite;

  /// No description provided for @materialListTitle.
  ///
  /// In ja, this message translates to:
  /// **'素材管理'**
  String get materialListTitle;

  /// No description provided for @materialRemoveUnused.
  ///
  /// In ja, this message translates to:
  /// **'未使用素材を削除 ({count})'**
  String materialRemoveUnused(int count);

  /// No description provided for @materialEmptyTitle.
  ///
  /// In ja, this message translates to:
  /// **'素材がありません'**
  String get materialEmptyTitle;

  /// No description provided for @materialEmptyHint.
  ///
  /// In ja, this message translates to:
  /// **'タイムラインから画像・動画・音声を追加すると\nここに一覧表示されます'**
  String get materialEmptyHint;

  /// No description provided for @materialUsedLabel.
  ///
  /// In ja, this message translates to:
  /// **'使用中'**
  String get materialUsedLabel;

  /// No description provided for @materialUnusedLabel.
  ///
  /// In ja, this message translates to:
  /// **'未使用'**
  String get materialUnusedLabel;

  /// No description provided for @materialMissingLabel.
  ///
  /// In ja, this message translates to:
  /// **'⚠ 不足'**
  String get materialMissingLabel;

  /// No description provided for @materialDeleteTooltipUsed.
  ///
  /// In ja, this message translates to:
  /// **'使用中のため削除できません'**
  String get materialDeleteTooltipUsed;

  /// No description provided for @materialRemoveOneConfirmTitle.
  ///
  /// In ja, this message translates to:
  /// **'素材を削除しますか？'**
  String get materialRemoveOneConfirmTitle;

  /// No description provided for @materialRemoveUnusedConfirmTitle.
  ///
  /// In ja, this message translates to:
  /// **'未使用素材を一括削除しますか？'**
  String get materialRemoveUnusedConfirmTitle;

  /// No description provided for @materialRemoveUnusedConfirmBody.
  ///
  /// In ja, this message translates to:
  /// **'プロジェクト内のどこからも参照されていない素材をまとめて削除します。この操作は元に戻せません。'**
  String get materialRemoveUnusedConfirmBody;

  /// No description provided for @materialRemovedSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'{count}件の未使用素材を削除しました'**
  String materialRemovedSnackbar(int count);

  /// No description provided for @watermarkEmptyTitle.
  ///
  /// In ja, this message translates to:
  /// **'登録されたウォーターマークがありません'**
  String get watermarkEmptyTitle;

  /// No description provided for @watermarkEmptyHint.
  ///
  /// In ja, this message translates to:
  /// **'右下の＋から画像または文字を登録してください'**
  String get watermarkEmptyHint;

  /// No description provided for @watermarkAddFromImage.
  ///
  /// In ja, this message translates to:
  /// **'画像から追加'**
  String get watermarkAddFromImage;

  /// No description provided for @watermarkAddText.
  ///
  /// In ja, this message translates to:
  /// **'文字を入力'**
  String get watermarkAddText;

  /// No description provided for @watermarkAddedSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'ウォーターマークを登録しました'**
  String get watermarkAddedSnackbar;

  /// No description provided for @watermarkTextDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'文字ウォーターマークを追加'**
  String get watermarkTextDialogTitle;

  /// No description provided for @watermarkTextFieldLabel.
  ///
  /// In ja, this message translates to:
  /// **'表示する文字'**
  String get watermarkTextFieldLabel;

  /// No description provided for @watermarkTextColorLabel.
  ///
  /// In ja, this message translates to:
  /// **'文字色'**
  String get watermarkTextColorLabel;

  /// No description provided for @watermarkTextColorTapHint.
  ///
  /// In ja, this message translates to:
  /// **'タップして色を選択'**
  String get watermarkTextColorTapHint;

  /// No description provided for @watermarkDropShadowLabel.
  ///
  /// In ja, this message translates to:
  /// **'ドロップシャドウ'**
  String get watermarkDropShadowLabel;

  /// No description provided for @watermarkShadowColorLabel.
  ///
  /// In ja, this message translates to:
  /// **'影の色'**
  String get watermarkShadowColorLabel;

  /// No description provided for @watermarkShadowOffsetXLabel.
  ///
  /// In ja, this message translates to:
  /// **'影の位置X'**
  String get watermarkShadowOffsetXLabel;

  /// No description provided for @watermarkShadowOffsetYLabel.
  ///
  /// In ja, this message translates to:
  /// **'影の位置Y'**
  String get watermarkShadowOffsetYLabel;

  /// No description provided for @watermarkShadowBlurLabel.
  ///
  /// In ja, this message translates to:
  /// **'影のぼかし'**
  String get watermarkShadowBlurLabel;

  /// No description provided for @watermarkOutlineLabel.
  ///
  /// In ja, this message translates to:
  /// **'縁取り'**
  String get watermarkOutlineLabel;

  /// No description provided for @watermarkOutlineColorLabel.
  ///
  /// In ja, this message translates to:
  /// **'縁の色'**
  String get watermarkOutlineColorLabel;

  /// No description provided for @watermarkOutlineWidthLabel.
  ///
  /// In ja, this message translates to:
  /// **'縁の太さ'**
  String get watermarkOutlineWidthLabel;

  /// No description provided for @premiumActiveLabel.
  ///
  /// In ja, this message translates to:
  /// **'プレミアム有効'**
  String get premiumActiveLabel;

  /// No description provided for @premiumVsTitle.
  ///
  /// In ja, this message translates to:
  /// **'無料版 vs プレミアム'**
  String get premiumVsTitle;

  /// No description provided for @premiumHeroTitle.
  ///
  /// In ja, this message translates to:
  /// **'プレミアムで、もっと自由な制作を'**
  String get premiumHeroTitle;

  /// No description provided for @premiumHeroSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'尺の上限なし・透かしなし・トーンカーブ／レベル補正など、制作の幅を広げる機能がすべて解放されます'**
  String get premiumHeroSubtitle;

  /// No description provided for @premiumHeroHighlightDuration.
  ///
  /// In ja, this message translates to:
  /// **'尺は最大2時間'**
  String get premiumHeroHighlightDuration;

  /// No description provided for @premiumHeroHighlightWatermark.
  ///
  /// In ja, this message translates to:
  /// **'透かしなし'**
  String get premiumHeroHighlightWatermark;

  /// No description provided for @premiumHeroHighlightGrading.
  ///
  /// In ja, this message translates to:
  /// **'トーンカーブ／\nレベル補正'**
  String get premiumHeroHighlightGrading;

  /// No description provided for @premiumCampaignFreeNote.
  ///
  /// In ja, this message translates to:
  /// **'※ キャンペーン期間中は無料版でも上記プレミアム機能を全てご利用いただけます'**
  String get premiumCampaignFreeNote;

  /// No description provided for @premiumPlanSectionTitle.
  ///
  /// In ja, this message translates to:
  /// **'プラン'**
  String get premiumPlanSectionTitle;

  /// No description provided for @premiumStoreUnavailable.
  ///
  /// In ja, this message translates to:
  /// **'ストアに接続できません（実機・ストア審査環境以外では購入できません）'**
  String get premiumStoreUnavailable;

  /// No description provided for @premiumYearlyTitle.
  ///
  /// In ja, this message translates to:
  /// **'年額プラン（おすすめ）'**
  String get premiumYearlyTitle;

  /// No description provided for @premiumYearlyDescription.
  ///
  /// In ja, this message translates to:
  /// **'実質2か月分無料'**
  String get premiumYearlyDescription;

  /// No description provided for @premiumYearlyPrice.
  ///
  /// In ja, this message translates to:
  /// **'¥5,500/年'**
  String get premiumYearlyPrice;

  /// No description provided for @premiumYearlyOriginalPrice.
  ///
  /// In ja, this message translates to:
  /// **'¥6,600'**
  String get premiumYearlyOriginalPrice;

  /// No description provided for @premiumYearlyPerMonthLabel.
  ///
  /// In ja, this message translates to:
  /// **'月あたり¥458相当'**
  String get premiumYearlyPerMonthLabel;

  /// No description provided for @premiumMonthlyTitle.
  ///
  /// In ja, this message translates to:
  /// **'月額プラン'**
  String get premiumMonthlyTitle;

  /// No description provided for @premiumRestorePurchases.
  ///
  /// In ja, this message translates to:
  /// **'購入を復元'**
  String get premiumRestorePurchases;

  /// No description provided for @premiumRestoredSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'購入情報を復元しました（該当する購入がある場合）'**
  String get premiumRestoredSnackbar;

  /// No description provided for @premiumCampaignBannerTitle.
  ///
  /// In ja, this message translates to:
  /// **'リリース記念！有料会員限定機能解放キャンペーン'**
  String get premiumCampaignBannerTitle;

  /// No description provided for @premiumCampaignBannerBody.
  ///
  /// In ja, this message translates to:
  /// **'期間中は無料版でも全てのプレミアム機能（尺2時間まで拡大・エンドロゴ編集・ウォーターマーク・トーンカーブ・レベル補正）を無料でご利用いただけます。'**
  String get premiumCampaignBannerBody;

  /// No description provided for @premiumCampaignEndLabel.
  ///
  /// In ja, this message translates to:
  /// **'～{date}まで'**
  String premiumCampaignEndLabel(String date);

  /// No description provided for @premiumComparisonFeature.
  ///
  /// In ja, this message translates to:
  /// **'機能'**
  String get premiumComparisonFeature;

  /// No description provided for @premiumComparisonFree.
  ///
  /// In ja, this message translates to:
  /// **'無料'**
  String get premiumComparisonFree;

  /// No description provided for @premiumFeatureDrawing.
  ///
  /// In ja, this message translates to:
  /// **'アニメ制作・描画機能'**
  String get premiumFeatureDrawing;

  /// No description provided for @premiumFeatureTimeline.
  ///
  /// In ja, this message translates to:
  /// **'タイムライン'**
  String get premiumFeatureTimeline;

  /// No description provided for @premiumFeatureExport.
  ///
  /// In ja, this message translates to:
  /// **'動画書き出し'**
  String get premiumFeatureExport;

  /// No description provided for @premiumFeatureMaxDuration.
  ///
  /// In ja, this message translates to:
  /// **'最大尺'**
  String get premiumFeatureMaxDuration;

  /// No description provided for @premiumFeatureEndLogo.
  ///
  /// In ja, this message translates to:
  /// **'公式エンドロゴ'**
  String get premiumFeatureEndLogo;

  /// No description provided for @premiumFeatureWatermark.
  ///
  /// In ja, this message translates to:
  /// **'ウォーターマーク'**
  String get premiumFeatureWatermark;

  /// No description provided for @premiumFeatureToneCurve.
  ///
  /// In ja, this message translates to:
  /// **'トーンカーブ'**
  String get premiumFeatureToneCurve;

  /// No description provided for @premiumFeatureLevelCorrection.
  ///
  /// In ja, this message translates to:
  /// **'レベル補正'**
  String get premiumFeatureLevelCorrection;

  /// No description provided for @premiumFeatureAds.
  ///
  /// In ja, this message translates to:
  /// **'広告'**
  String get premiumFeatureAds;

  /// No description provided for @premiumFeatureCommunityUpload.
  ///
  /// In ja, this message translates to:
  /// **'作品広場への投稿数/日'**
  String get premiumFeatureCommunityUpload;

  /// No description provided for @premiumValueYes.
  ///
  /// In ja, this message translates to:
  /// **'あり'**
  String get premiumValueYes;

  /// No description provided for @premiumValueNo.
  ///
  /// In ja, this message translates to:
  /// **'なし'**
  String get premiumValueNo;

  /// No description provided for @premiumValueRemovable.
  ///
  /// In ja, this message translates to:
  /// **'削除可'**
  String get premiumValueRemovable;

  /// No description provided for @premiumValueDuration2Hours.
  ///
  /// In ja, this message translates to:
  /// **'2時間'**
  String get premiumValueDuration2Hours;

  /// No description provided for @premiumValueDuration90Sec.
  ///
  /// In ja, this message translates to:
  /// **'1.5分'**
  String get premiumValueDuration90Sec;

  /// No description provided for @premiumValueUploadFree.
  ///
  /// In ja, this message translates to:
  /// **'1本'**
  String get premiumValueUploadFree;

  /// No description provided for @premiumValueUploadPremium.
  ///
  /// In ja, this message translates to:
  /// **'3本'**
  String get premiumValueUploadPremium;

  /// No description provided for @premiumPlanRecommendedBadge.
  ///
  /// In ja, this message translates to:
  /// **'おすすめ'**
  String get premiumPlanRecommendedBadge;

  /// No description provided for @premiumMonthlyPrice.
  ///
  /// In ja, this message translates to:
  /// **'¥550/月'**
  String get premiumMonthlyPrice;

  /// No description provided for @toolbarItemPen.
  ///
  /// In ja, this message translates to:
  /// **'Gペン'**
  String get toolbarItemPen;

  /// No description provided for @toolbarItemEraser.
  ///
  /// In ja, this message translates to:
  /// **'消しゴム'**
  String get toolbarItemEraser;

  /// No description provided for @toolbarItemBucket.
  ///
  /// In ja, this message translates to:
  /// **'バケツ'**
  String get toolbarItemBucket;

  /// No description provided for @toolbarItemEyedropper.
  ///
  /// In ja, this message translates to:
  /// **'スポイト'**
  String get toolbarItemEyedropper;

  /// No description provided for @toolbarItemFinger.
  ///
  /// In ja, this message translates to:
  /// **'指'**
  String get toolbarItemFinger;

  /// No description provided for @toolbarItemPan.
  ///
  /// In ja, this message translates to:
  /// **'手のひら'**
  String get toolbarItemPan;

  /// No description provided for @toolbarItemSelect.
  ///
  /// In ja, this message translates to:
  /// **'選択'**
  String get toolbarItemSelect;

  /// No description provided for @toolbarItemTransform.
  ///
  /// In ja, this message translates to:
  /// **'変形'**
  String get toolbarItemTransform;

  /// No description provided for @toolbarItemText.
  ///
  /// In ja, this message translates to:
  /// **'テキスト'**
  String get toolbarItemText;

  /// No description provided for @toolbarItemShape.
  ///
  /// In ja, this message translates to:
  /// **'図形'**
  String get toolbarItemShape;

  /// No description provided for @workspaceScreenTitle.
  ///
  /// In ja, this message translates to:
  /// **'ワークスペース設定'**
  String get workspaceScreenTitle;

  /// No description provided for @workspaceToolbarEditSection.
  ///
  /// In ja, this message translates to:
  /// **'ツールバー編集'**
  String get workspaceToolbarEditSection;

  /// No description provided for @workspaceToolbarEditHint.
  ///
  /// In ja, this message translates to:
  /// **'表示するツールをチェックボックスで選択し、ドラッグで並び替えできます。'**
  String get workspaceToolbarEditHint;

  /// No description provided for @workspaceToolbarPcOnlyHint.
  ///
  /// In ja, this message translates to:
  /// **'横画面の時のみツールバーに表示されます'**
  String get workspaceToolbarPcOnlyHint;

  /// No description provided for @workspaceToolbarPanDisabledHint.
  ///
  /// In ja, this message translates to:
  /// **'スマホモードでは使用できません'**
  String get workspaceToolbarPanDisabledHint;

  /// No description provided for @workspaceResetToolbarDefault.
  ///
  /// In ja, this message translates to:
  /// **'デフォルトに戻す'**
  String get workspaceResetToolbarDefault;

  /// No description provided for @workspacePanelLayoutSection.
  ///
  /// In ja, this message translates to:
  /// **'パネル配置'**
  String get workspacePanelLayoutSection;

  /// No description provided for @workspaceLeftHandedMode.
  ///
  /// In ja, this message translates to:
  /// **'左利きモード'**
  String get workspaceLeftHandedMode;

  /// No description provided for @workspaceLeftHandedSubtitlePc.
  ///
  /// In ja, this message translates to:
  /// **'パネルを右側に配置'**
  String get workspaceLeftHandedSubtitlePc;

  /// No description provided for @workspaceLeftHandedSubtitleMobile.
  ///
  /// In ja, this message translates to:
  /// **'PC/DeXモードでのみ設定できます'**
  String get workspaceLeftHandedSubtitleMobile;

  /// No description provided for @workspacePcModeSection.
  ///
  /// In ja, this message translates to:
  /// **'PCモード（DeX）'**
  String get workspacePcModeSection;

  /// No description provided for @workspacePcModeHint.
  ///
  /// In ja, this message translates to:
  /// **'画面幅の広い環境では、パネルを常時表示するプロ向けの画面構成に自動で切り替わります。手動で固定したい場合はここで指定してください。'**
  String get workspacePcModeHint;

  /// No description provided for @workspacePcModeAuto.
  ///
  /// In ja, this message translates to:
  /// **'自動（画面幅で判定・推奨）'**
  String get workspacePcModeAuto;

  /// No description provided for @workspacePcModeAlwaysPc.
  ///
  /// In ja, this message translates to:
  /// **'常にPCモード'**
  String get workspacePcModeAlwaysPc;

  /// No description provided for @workspacePcModeAlwaysMobile.
  ///
  /// In ja, this message translates to:
  /// **'常にスマホモード'**
  String get workspacePcModeAlwaysMobile;

  /// No description provided for @workspaceSaveSection.
  ///
  /// In ja, this message translates to:
  /// **'ワークスペース保存'**
  String get workspaceSaveSection;

  /// No description provided for @workspaceSaveHint.
  ///
  /// In ja, this message translates to:
  /// **'左利きモード・PCモード・ツールバー・ツール早替え設定を名前を付けて保存し、後から呼び出せます。'**
  String get workspaceSaveHint;

  /// No description provided for @workspaceLoadButton.
  ///
  /// In ja, this message translates to:
  /// **'ワークスペースを読み込み'**
  String get workspaceLoadButton;

  /// No description provided for @workspaceEmptyToolbar.
  ///
  /// In ja, this message translates to:
  /// **'表示するツールがありません'**
  String get workspaceEmptyToolbar;

  /// No description provided for @workspaceSaveDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'ワークスペースを保存'**
  String get workspaceSaveDialogTitle;

  /// No description provided for @workspaceSaveDialogLabel.
  ///
  /// In ja, this message translates to:
  /// **'名前（例：アニメ用・線画用）'**
  String get workspaceSaveDialogLabel;

  /// No description provided for @workspaceLoadRightHanded.
  ///
  /// In ja, this message translates to:
  /// **'右利き'**
  String get workspaceLoadRightHanded;

  /// No description provided for @workspaceLoadLeftHanded.
  ///
  /// In ja, this message translates to:
  /// **'左利き'**
  String get workspaceLoadLeftHanded;

  /// No description provided for @helpScreenTitle.
  ///
  /// In ja, this message translates to:
  /// **'ヘルプ'**
  String get helpScreenTitle;

  /// No description provided for @helpSearchHint.
  ///
  /// In ja, this message translates to:
  /// **'検索...'**
  String get helpSearchHint;

  /// No description provided for @helpNoResults.
  ///
  /// In ja, this message translates to:
  /// **'該当する項目が見つかりません'**
  String get helpNoResults;

  /// No description provided for @helpCategoryTool.
  ///
  /// In ja, this message translates to:
  /// **'ツール'**
  String get helpCategoryTool;

  /// No description provided for @helpCategoryLayer.
  ///
  /// In ja, this message translates to:
  /// **'レイヤー'**
  String get helpCategoryLayer;

  /// No description provided for @helpCategoryAnimation.
  ///
  /// In ja, this message translates to:
  /// **'アニメーション'**
  String get helpCategoryAnimation;

  /// No description provided for @helpCategoryDrawing.
  ///
  /// In ja, this message translates to:
  /// **'描画'**
  String get helpCategoryDrawing;

  /// No description provided for @helpCategoryBrush.
  ///
  /// In ja, this message translates to:
  /// **'ブラシ'**
  String get helpCategoryBrush;

  /// No description provided for @helpCategoryPenInput.
  ///
  /// In ja, this message translates to:
  /// **'ペン入力'**
  String get helpCategoryPenInput;

  /// No description provided for @helpCategorySave.
  ///
  /// In ja, this message translates to:
  /// **'保存'**
  String get helpCategorySave;

  /// No description provided for @helpCategoryProjectManagement.
  ///
  /// In ja, this message translates to:
  /// **'プロジェクト管理'**
  String get helpCategoryProjectManagement;

  /// No description provided for @helpCategoryExport.
  ///
  /// In ja, this message translates to:
  /// **'書き出し'**
  String get helpCategoryExport;

  /// No description provided for @helpCategoryPremium.
  ///
  /// In ja, this message translates to:
  /// **'プレミアム'**
  String get helpCategoryPremium;

  /// No description provided for @helpCategorySettings.
  ///
  /// In ja, this message translates to:
  /// **'設定'**
  String get helpCategorySettings;

  /// No description provided for @helpCategoryCommunity.
  ///
  /// In ja, this message translates to:
  /// **'コミュニティ'**
  String get helpCategoryCommunity;

  /// No description provided for @helpPenToolTitle.
  ///
  /// In ja, this message translates to:
  /// **'ペンツール'**
  String get helpPenToolTitle;

  /// No description provided for @helpPenToolDesc.
  ///
  /// In ja, this message translates to:
  /// **'キャンバスに線を描くための基本ツールです。長押しでブラシの種類・太さ・色を変更できます（ダブルタップは簡易説明の表示）。板タブ・液晶タブレットの筆圧・傾きに対応しており、設定画面の「ペン入力」から筆圧カーブを調整すると筆圧の伝わり方（弱い力でどれだけ太さ・不透明度が変化するか）を細かくカスタマイズできます。ペンサブツールを切り替えると、同じペンツールからトーン貼り・スタンプ配置も行えます。'**
  String get helpPenToolDesc;

  /// No description provided for @helpEraserToolTitle.
  ///
  /// In ja, this message translates to:
  /// **'消しゴムツール'**
  String get helpEraserToolTitle;

  /// No description provided for @helpEraserToolDesc.
  ///
  /// In ja, this message translates to:
  /// **'ペンツールと対になる、描いた内容を消すためのツールです。ブラシと同様に太さ・不透明度を調整でき、フェードやストローク減衰などのブラシ設定も共通で反映されます。レイヤーの透明部分を「描き足す」のではなく既存の描画を「消す」処理を行うため、下のレイヤーが透けて見えるようになります。'**
  String get helpEraserToolDesc;

  /// No description provided for @helpBucketToolTitle.
  ///
  /// In ja, this message translates to:
  /// **'バケツツール'**
  String get helpBucketToolTitle;

  /// No description provided for @helpBucketToolDesc.
  ///
  /// In ja, this message translates to:
  /// **'囲まれた領域を一括で塗りつぶすツールです。線画で囲まれた範囲内をタップすると、その範囲全体が選択中の色（またはトーン）で塗られます。線画に隙間があると意図しない範囲まで塗り広がってしまうことがあるため、線画がきちんと閉じているか確認してから使うのがコツです。設定でベタ塗り／トーン塗りを切り替えられます。 詳細設定（許容誤差・拡張px・線の下まで潜る）は設定画面の「バケツ塗り」から調整できます。'**
  String get helpBucketToolDesc;

  /// No description provided for @helpLassoFillTitle.
  ///
  /// In ja, this message translates to:
  /// **'投げ縄塗り'**
  String get helpLassoFillTitle;

  /// No description provided for @helpLassoFillDesc.
  ///
  /// In ja, this message translates to:
  /// **'囲みたい範囲を指でなぞって多角形の範囲を作り、その内側をまとめて塗るツールです。バケツツールと違い、線画が閉じていない部分があっても自分で囲む範囲を指定できるため、複雑な形や線が途切れている部分の塗りに向いています。'**
  String get helpLassoFillDesc;

  /// No description provided for @helpEyedropperToolTitle.
  ///
  /// In ja, this message translates to:
  /// **'スポイトツール'**
  String get helpEyedropperToolTitle;

  /// No description provided for @helpEyedropperToolDesc.
  ///
  /// In ja, this message translates to:
  /// **'タップした位置の色を拾って、描画色として選択するツールです。画面に実際に表示されている全レイヤーを合成した見た目の色を拾うため、複数レイヤーが重なっている部分でも「見た目通りの色」を正確に取得できます。'**
  String get helpEyedropperToolDesc;

  /// No description provided for @helpSelectToolTitle.
  ///
  /// In ja, this message translates to:
  /// **'選択ツール'**
  String get helpSelectToolTitle;

  /// No description provided for @helpSelectToolDesc.
  ///
  /// In ja, this message translates to:
  /// **'キャンバスの一部分を範囲選択し、選択した範囲だけを移動・回転・拡大縮小できるツールです。長押しすると「矩形選択」「投げ縄選択（自由な形で囲む）」「自動選択（マジックワンド、似た色の範囲を自動でまとめて選択）」の3種類から選択方法を選べます。選択中は選択範囲を示す枠線がキャンバス上に表示され、選択を解除するまで全フレーム・全レイヤーで同じ範囲が固定表示されます。'**
  String get helpSelectToolDesc;

  /// No description provided for @helpFingerToolTitle.
  ///
  /// In ja, this message translates to:
  /// **'指ツール（歪みツール）'**
  String get helpFingerToolTitle;

  /// No description provided for @helpFingerToolDesc.
  ///
  /// In ja, this message translates to:
  /// **'指でなぞった方向にピクセルを押し流すように歪ませる、液体絵の具を指でこすったような効果を作るツールです。細かい修正よりも、既に描いた線を有機的に歪ませて表情をつけたい時に使います。'**
  String get helpFingerToolDesc;

  /// No description provided for @helpShapeToolTitle.
  ///
  /// In ja, this message translates to:
  /// **'図形ツール'**
  String get helpShapeToolTitle;

  /// No description provided for @helpShapeToolDesc.
  ///
  /// In ja, this message translates to:
  /// **'直線・四角形・円といった正確な図形をワンタップで描くためのツールです。ドラッグで始点から終点まで動かすとその場でプレビューされ、指を離すと確定します。フリーハンドでは描きにくい直線や正円が必要な時に便利です。'**
  String get helpShapeToolDesc;

  /// No description provided for @helpTextToolTitle.
  ///
  /// In ja, this message translates to:
  /// **'テキストツール'**
  String get helpTextToolTitle;

  /// No description provided for @helpTextToolDesc.
  ///
  /// In ja, this message translates to:
  /// **'キャンバス上に文字を配置するツールです。フォント・サイズ・色・縦書き/横書きを選べます。縦書きでは半角英数字の自動回転・縦中横（数字を横向きのまま並べる表記）・ルビ（ふりがな）にも対応しています。配置したテキストは書き出し時にもピクセルとして焼き込まれます。 テキストツールで使えるフォントを追加・検索・削除できる画面です。初期同梱フォント以外の追加フリーフォントは、初期インストール容量を抑えるためここからオンデマンドでダウンロードする方式になっています。'**
  String get helpTextToolDesc;

  /// No description provided for @helpQuickToolTitle.
  ///
  /// In ja, this message translates to:
  /// **'早替えツール'**
  String get helpQuickToolTitle;

  /// No description provided for @helpQuickToolDesc.
  ///
  /// In ja, this message translates to:
  /// **'よく使うブラシ・ツールの組み合わせをあらかじめ登録しておき、ボタン一つで順番に切り替えられる機能です。キャンバス上の↺ボタンを長押しまたは上スワイプすると、登録・並べ替え・削除ができる管理ポップアップが開きます。ドラッグで並び順を変更できます。'**
  String get helpQuickToolDesc;

  /// No description provided for @helpLayerTitle.
  ///
  /// In ja, this message translates to:
  /// **'レイヤー'**
  String get helpLayerTitle;

  /// No description provided for @helpLayerDesc.
  ///
  /// In ja, this message translates to:
  /// **'1枚のキャンバスを複数の透明な「層」に分けて描画できる仕組みです。線画・色塗り・背景などを別々のレイヤーに分けて描くことで、後から色だけをやり直したり、線画を消さずに背景を差し替えたりできます。画面上では上に重なっているレイヤーほど手前に表示されます。各レイヤー行のアイコンからワンタップで削除・下のレイヤーとの結合ができ、レイヤーパネル上部のアイコンから表示中の全レイヤーを一括結合することもできます。'**
  String get helpLayerDesc;

  /// No description provided for @helpBlendModeTitle.
  ///
  /// In ja, this message translates to:
  /// **'ブレンドモード'**
  String get helpBlendModeTitle;

  /// No description provided for @helpBlendModeDesc.
  ///
  /// In ja, this message translates to:
  /// **'レイヤーの合成方法を変更する機能です。トーンやカラー効果をレイヤーとして重ねる時によく使われます。\n通常：そのまま重ねます。\n乗算：下のレイヤーと掛け合わせて暗くします。影・陰影づけの定番です。\nスクリーン：明るさを足し合わせて明るくします。光の表現に向きます。\nオーバーレイ：暗い部分はより暗く、明るい部分はより明るくしてコントラストを強めます。\n加算：色を単純に足し合わせます。光の効果線などに向きます。\n減算：色を差し引き、暗く沈んだ効果になります。\n比較（暗）：上下のレイヤーで暗い方の色を採用します。\n比較（明）：上下のレイヤーで明るい方の色を採用します。\n焼き込みカラー：下の色を暗く沈めながら濃く発色させます。\n覆い焼きカラー：下の色を明るく飛ばしながら発色させます。\nハードライト：オーバーレイより強くコントラストが付きます。\nソフトライト：オーバーレイより穏やかにコントラストが付きます。柔らかい陰影に向きます。\n差の絶対値：上下の色の差を表示します。色のズレ確認などに使えます。\n色相・彩度・カラー・輝度：それぞれ色相・彩度・色味・明るさだけを下のレイヤーへ反映します。'**
  String get helpBlendModeDesc;

  /// No description provided for @helpClippingTitle.
  ///
  /// In ja, this message translates to:
  /// **'クリッピング'**
  String get helpClippingTitle;

  /// No description provided for @helpClippingDesc.
  ///
  /// In ja, this message translates to:
  /// **'自分のすぐ下にあるレイヤーの、不透明なピクセルの範囲内にのみ描画されるようにする機能です。線画からはみ出さずに色を塗りたい時、線画レイヤーの上に色塗り用レイヤーを作ってクリッピングを有効にすると、線画の外側にうっかりはみ出して描いてしまう心配がなくなります。'**
  String get helpClippingDesc;

  /// No description provided for @helpCommonLayerTitle.
  ///
  /// In ja, this message translates to:
  /// **'共通レイヤー'**
  String get helpCommonLayerTitle;

  /// No description provided for @helpCommonLayerDesc.
  ///
  /// In ja, this message translates to:
  /// **'通常のレイヤーは1フレームごとに独立していますが、共通レイヤーは複数のフレーム・シーンで同じ内容を共有するレイヤーです。背景などフレームが変わっても動かさない要素を、フレームごとに描き直す手間なく一度描くだけで済ませられます。タイムライン上では専用のトラックとして表示されます。 通常レイヤーを共通レイヤー（複数フレームに同じ内容を表示し続けるレイヤー）へ変換できる機能です。表示中のレイヤーを複製して1枚に統合してから共通化することもできます。背景など毎フレーム同じ内容を使い回したい場合に、描き直す手間を省けます。'**
  String get helpCommonLayerDesc;

  /// No description provided for @helpAutoFillTitle.
  ///
  /// In ja, this message translates to:
  /// **'自動塗り'**
  String get helpAutoFillTitle;

  /// No description provided for @helpAutoFillDesc.
  ///
  /// In ja, this message translates to:
  /// **'自動塗り用線画レイヤーの下に自動塗りレイヤーを作り、あらかじめ作成した「自動塗り設定」（パーツごとの色・トーンの組み合わせ）に基づいて色を自動で塗る機能です。線画を描き終えた後に一括で色を塗れるため、同じキャラクターを何度も描く手描きアニメーションで色塗りの手間を大幅に減らせます。線画を描き直した場合はタイムライン・レイヤーパネルに更新マーク（❗）が表示され、自動塗りの再実行が必要なことを知らせます。 タイムライン画面の三点メニューから「自動塗り実行」を選ぶと、更新マーク（❗）が付いた自動塗りレイヤーをまとめて再計算できます。線画を描き直した後に1枚ずつレイヤーパネルで実行する手間を省けます。 自動塗り設定の各パーツには、線画の色をどう扱うかの設定（指定色・塗り色と同じ・色トレス）があります。色トレス（線画馴染ませ）を選ぶと、線画の色を塗り色に合わせてHSLシフトし、線が浮かずに馴染んだ仕上がりになります。 設定が増えてくると、パーツ割り当て時の一覧が長くなって選びにくくなります。プロジェクト設定（またはレイヤーパネルのパーツ割り当てダイアログ）から、このプロジェクトで使う設定だけに絞り込んでおくと、一覧がすっきりして選びやすくなります。'**
  String get helpAutoFillDesc;

  /// No description provided for @helpOnionSkinTitle.
  ///
  /// In ja, this message translates to:
  /// **'オニオンスキン'**
  String get helpOnionSkinTitle;

  /// No description provided for @helpOnionSkinDesc.
  ///
  /// In ja, this message translates to:
  /// **'現在編集中のフレームの前後のフレームを半透明で重ねて表示し、動きの繋がりを確認しながら描けるようにする機能です。パフォーマンス設定で表示する枚数（前後何枚まで）や色・透明度を調整できます。'**
  String get helpOnionSkinDesc;

  /// No description provided for @helpRulerTitle.
  ///
  /// In ja, this message translates to:
  /// **'定規'**
  String get helpRulerTitle;

  /// No description provided for @helpRulerDesc.
  ///
  /// In ja, this message translates to:
  /// **'直線・円・楕円・パース定規（消失点を使った透視図法用の定規）など、フリーハンドでは描きにくい正確な線を補助するための機能です。配置した定規に沿ってペン先が自動でスナップするため、定規なしでは難しい奥行きのある構図も描きやすくなります。定規はハンドルを操作して移動・回転・サイズ変更ができます。'**
  String get helpRulerDesc;

  /// No description provided for @helpFadeTitle.
  ///
  /// In ja, this message translates to:
  /// **'フェード'**
  String get helpFadeTitle;

  /// No description provided for @helpFadeDesc.
  ///
  /// In ja, this message translates to:
  /// **'ブラシ設定の一つで、ストロークを描き進めるにつれて不透明度や太さが徐々に減少していく効果です。線の端をかすれさせたい時や、余韻を残すような描き味を作りたい時に使います。'**
  String get helpFadeDesc;

  /// No description provided for @helpStrokeDecayTitle.
  ///
  /// In ja, this message translates to:
  /// **'ストローク減衰'**
  String get helpStrokeDecayTitle;

  /// No description provided for @helpStrokeDecayDesc.
  ///
  /// In ja, this message translates to:
  /// **'フェードと似ていますが、こちらは「インクが減っていく」ような表現に近く、描き続けるほど色が薄くなったりかすれたりする効果です。筆やマーカーで描き続けた時のインク切れのような質感を再現します。'**
  String get helpStrokeDecayDesc;

  /// No description provided for @helpColorMixingTitle.
  ///
  /// In ja, this message translates to:
  /// **'混色'**
  String get helpColorMixingTitle;

  /// No description provided for @helpColorMixingDesc.
  ///
  /// In ja, this message translates to:
  /// **'ブラシで塗る際、ブラシの直下にすでにある色と、これから塗ろうとしている選択色を混ぜ合わせながら描画する機能です。水彩や油彩のように、既存の色に新しい色をなじませたい時に使います。'**
  String get helpColorMixingDesc;

  /// No description provided for @helpPressureCurveTitle.
  ///
  /// In ja, this message translates to:
  /// **'筆圧カーブ'**
  String get helpPressureCurveTitle;

  /// No description provided for @helpPressureCurveDesc.
  ///
  /// In ja, this message translates to:
  /// **'ペン入力設定にある機能で、実際の筆圧の強さと、ブラシの太さ・不透明度への反映のされ方の関係をグラフで自由に調整できます。弱い筆圧でも太く出したい人、逆に強く押さないと太くならないようにしたい人など、手癖に合わせて描き心地を細かくカスタマイズできます。設定変更後はその場で試し書きしながら確認できます。'**
  String get helpPressureCurveDesc;

  /// No description provided for @helpTimelineTitle.
  ///
  /// In ja, this message translates to:
  /// **'タイムライン'**
  String get helpTimelineTitle;

  /// No description provided for @helpTimelineDesc.
  ///
  /// In ja, this message translates to:
  /// **'アニメーションの時間軸を管理する画面です。フレーム（静止画1コマ）を並べてパラパラ漫画のように再生することでアニメーションになります。画像・動画・音声などの素材トラック、共通レイヤートラック、カメラキーフレームも同じタイムライン上で管理します。'**
  String get helpTimelineDesc;

  /// No description provided for @helpSceneTitle.
  ///
  /// In ja, this message translates to:
  /// **'シーン'**
  String get helpSceneTitle;

  /// No description provided for @helpSceneDesc.
  ///
  /// In ja, this message translates to:
  /// **'1つのプロジェクト（1本の動画）の中を、場面（カット）ごとに分割して管理する機能です。フォルダがプロジェクト単位の整理なのに対し、シーンは1本の動画の中の場面転換を表現するために使います。タイムラインのシーンタブでは、シーンの追加・複製・削除・名前変更・並び替えができます。複数選択モードにすると複数シーンをまとめて移動・複製・削除することも可能です。'**
  String get helpSceneDesc;

  /// No description provided for @helpCameraKeyframeTitle.
  ///
  /// In ja, this message translates to:
  /// **'カメラキーフレーム'**
  String get helpCameraKeyframeTitle;

  /// No description provided for @helpCameraKeyframeDesc.
  ///
  /// In ja, this message translates to:
  /// **'タイムライン上の特定の位置にカメラの位置・拡大率・回転を記録しておく機能です。キーフレーム間は自動で滑らかに補間されるため、パン（横移動）やズームイン・ズームアウトのようなカメラワークを簡単に付けられます。'**
  String get helpCameraKeyframeDesc;

  /// No description provided for @helpEffectFilterTitle.
  ///
  /// In ja, this message translates to:
  /// **'演出フィルター'**
  String get helpEffectFilterTitle;

  /// No description provided for @helpEffectFilterDesc.
  ///
  /// In ja, this message translates to:
  /// **'シーンやフレームに適用できる映像効果（ぼかし・色調補正・グロー・ドット絵等）です。手描きの絵そのものを変えずに、演出として画面全体の見た目を調整したい時に使います。ドット絵は配色方式（色を指定しない・色を指定する・色数を指定する・パレットから選ぶ）も選べます。 演出フィルターは複数重ねて適用でき、その適用順はタイムライン上での並び順に従います。フィルター一覧をドラッグで並び替えると、実際に画面へ反映される順序も変わります。 フィルムの粒状感のようなノイズをフレームごとに変化させながら適用する演出フィルターです。強度・量（ノイズが乗る密度）・粒の大きさをスライダーで調整できます。同じフレームに戻ると同じ粒状になるため、スクラブ中にちらつかず、再生すると粒が動いて見えます。 画面に降る雨を表現する演出フィルターです。降り方（本数）・速さ・粒の大きさ・風向きの角度をスライダーで調整できます。各雨粒はフレームが進むごとに一定の速度で降り続けるため、自然な雨の動きになります。'**
  String get helpEffectFilterDesc;

  /// No description provided for @helpEndCardTitle.
  ///
  /// In ja, this message translates to:
  /// **'エンドカード'**
  String get helpEndCardTitle;

  /// No description provided for @helpEndCardDesc.
  ///
  /// In ja, this message translates to:
  /// **'動画書き出し時、本編の終わりに自動で追加されるNIARIMロゴの短い動画（約5秒）です。無料版では非表示・削除ができませんが、プレミアム会員になると表示のON/OFF・長さ変更・差し替えができるようになります。'**
  String get helpEndCardDesc;

  /// No description provided for @helpAutoSaveTitle.
  ///
  /// In ja, this message translates to:
  /// **'自動保存'**
  String get helpAutoSaveTitle;

  /// No description provided for @helpAutoSaveDesc.
  ///
  /// In ja, this message translates to:
  /// **'クラッシュやファイル破損が起きた時のための復元専用の保存です。描画などの変更があるたびに自動で保存され、最大3件まで古い順に上書きされます。手動保存（セーブスロット・セーブツリー）とは完全に別で管理されており、通常の保存の代わりにはなりません。アプリを異常終了した後の再起動時のみ、復元するかどうかを尋ねられます。'**
  String get helpAutoSaveDesc;

  /// No description provided for @helpSaveSlotTitle.
  ///
  /// In ja, this message translates to:
  /// **'セーブスロット'**
  String get helpSaveSlotTitle;

  /// No description provided for @helpSaveSlotDesc.
  ///
  /// In ja, this message translates to:
  /// **'決まった数の保存枠（スロット）に、自分で保存先を選びながら保存する方式です。スロット数は設定（低品質5件・中品質10件）で決まります。上書きしたい枠を毎回自分で選ぶため、「このタイミングの状態は残しておきたい」という管理がしやすい方式です。'**
  String get helpSaveSlotDesc;

  /// No description provided for @helpSaveTreeTitle.
  ///
  /// In ja, this message translates to:
  /// **'セーブツリー'**
  String get helpSaveTreeTitle;

  /// No description provided for @helpSaveTreeDesc.
  ///
  /// In ja, this message translates to:
  /// **'保存するたびに新しい保存地点が作られ、過去の保存地点から分岐して別の履歴を作れる（枝分かれする）保存方式です。件数の上限がなく、「あの時のバージョンに戻ってから別の展開を試したい」といった使い方に向いています。画面には保存地点が下から上へ伸びる樹形図として表示されます。'**
  String get helpSaveTreeDesc;

  /// No description provided for @helpFolderTitle.
  ///
  /// In ja, this message translates to:
  /// **'フォルダ'**
  String get helpFolderTitle;

  /// No description provided for @helpFolderDesc.
  ///
  /// In ja, this message translates to:
  /// **'プロジェクト（作品）をグループ化して整理する機能です。複数階層に対応しているので、同じ作品の複数話数やシリーズ物をまとめて管理する使い方もできます（例：「作品名」フォルダの中に「第1話」「第2話」…とプロジェクトを並べる）。1つの動画の中で場面を分けて作りたい場合は、フォルダではなくキャンバス画面の「シーン」機能をご利用ください。'**
  String get helpFolderDesc;

  /// No description provided for @helpTrashTitle.
  ///
  /// In ja, this message translates to:
  /// **'ゴミ箱'**
  String get helpTrashTitle;

  /// No description provided for @helpTrashDesc.
  ///
  /// In ja, this message translates to:
  /// **'削除したプロジェクトが一時的に移動する場所です。完全に削除するまではここから元に戻せます。設定で自動削除までの日数（OFF/30日/60日/90日）を指定できます。'**
  String get helpTrashDesc;

  /// No description provided for @helpShareTitle.
  ///
  /// In ja, this message translates to:
  /// **'共有（.niashare）'**
  String get helpShareTitle;

  /// No description provided for @helpShareDesc.
  ///
  /// In ja, this message translates to:
  /// **'プロジェクトを他の人（または自分の他の端末）へ渡すための共有専用ファイル形式です。受け取った側がこのファイルを開くと、複製されて自分のプロジェクト一覧に追加されます。共有元の.niashare自体は変更されません。'**
  String get helpShareDesc;

  /// No description provided for @helpTransferTitle.
  ///
  /// In ja, this message translates to:
  /// **'引き継ぎ（.niatra）'**
  String get helpTransferTitle;

  /// No description provided for @helpTransferDesc.
  ///
  /// In ja, this message translates to:
  /// **'設定・素材・ブラシ・自動塗り設定・テーマ・パレット（カラーピッカー・ドット絵専用）など、アプリ全体の環境を別の端末へまとめて引き継ぐための機能です。引き継ぐ項目はチェックボックスで個別に選べるほか、制作中のプロジェクトも任意で選んで含められます（選択したプロジェクトは素材・フォントも含めて丸ごと引き継がれます）。個別のプロジェクトだけを渡したい場合は「共有（.niashare）」も使えます。'**
  String get helpTransferDesc;

  /// No description provided for @helpVideoExportTitle.
  ///
  /// In ja, this message translates to:
  /// **'動画書き出し（MP4・WebM・GIF・AVI）'**
  String get helpVideoExportTitle;

  /// No description provided for @helpVideoExportDesc.
  ///
  /// In ja, this message translates to:
  /// **'作品を汎用的なMP4動画として書き出します。無料版は書き出せる長さに上限（90秒）があり、動画の最後にエンドカード（アプリロゴ）が自動で追加されます。 アルファチャンネル（背景の透明部分）を保持したまま書き出せる動画形式です。対応する再生環境でのみ透過再生されます。他のアプリの素材として重ねて使いたい場合などに向いています。 アニメーションGIFとして書き出します。自動でループ再生される形式のため、SNSへの投稿など気軽に共有したい場面に向いています。 互換性を重視したい場合はAVI（Motion JPEG）としても書き出せます。特許・ライセンス面で安全なコーデックを採用していますが、アルファチャンネル（透過）には対応せず、端末によってはアプリ内プレビューが利用できない場合があります（その場合も「共有」から外部プレイヤーで再生できます）。 無料会員はプロジェクトの長さに90秒までの上限があります（プレミアム会員は2時間）。フレーム追加・複製によって上限を超えそうな場合は、ボタンをタップした時点で注意ダイアログが表示され、実際に90秒を超えることはありません。'**
  String get helpVideoExportDesc;

  /// No description provided for @helpTransparentWebmTitle.
  ///
  /// In ja, this message translates to:
  /// **'透過WebM'**
  String get helpTransparentWebmTitle;

  /// No description provided for @helpCommunityTitle.
  ///
  /// In ja, this message translates to:
  /// **'作品広場'**
  String get helpCommunityTitle;

  /// No description provided for @helpCommunityDesc.
  ///
  /// In ja, this message translates to:
  /// **'アニメ・イラスト作品をYouTube動画としてコミュニティに投稿し、他のユーザーの作品を閲覧できる機能です。「新着」「ランキング」「フォロー中」の3タブで一覧を切り替えられ、作品タイトルまたは投稿者名で検索できるほか、タグ検索モードに切り替えるとタグから作品を絞り込めます。タグは投稿者以外のユーザーも自由に追加・削除でき（投稿者がロックしたタグは投稿者本人にしか外せません）、タグをタップするだけでも同じタグの作品に絞り込めます。作品カードをタップするとドラッグ・リサイズできるフローティングプレビューウィンドウが開き、他の画面を操作しながら視聴を続けられます。「詳細へ」ボタンで作品の詳細画面（投稿者・投稿日・タグ編集・ブックマーク・リポストなど）を開けます。作者名の横の「フォロー」ボタンでフォローすると、「フォロー中」タブでその作者の投稿だけを新着順にまとめて追いかけられます。フォローされると画面右上のベルアイコンの通知一覧に届きます。自分のフォロー中/フォロワー一覧を全体公開するかどうかも設定でき（既定は非公開）、公開設定にしている他のユーザーの一覧も閲覧できます。他者の作品（自分の投稿を除く）は「リポスト」ボタンで再投稿でき、フォロー中の作者が誰かの作品をリポストすると、その作品も「投稿日時」と「リポスト日時」のうちより新しい方を基準に「フォロー中」タブへ混ざって表示されます（カードに「○○さんがリポスト」と表示）。ブックマークした作品はホーム画面の「ブクマ済み」タブにまとめて表示されるほか、投稿者別の作品一覧画面の「ブックマーク」タブでも確認できます。自分のブックマーク一覧はユーザー全体へ公開するかどうかを設定でき（既定は非公開）、公開設定にしている他のユーザーのブックマーク一覧も閲覧できます。不適切な作品は理由を添えて通報でき、送信後にはその投稿者をブロックするか選べます。縦長の動画は「縦画面モード」でTikTok風に連続再生して視聴できます。投稿できる本数には1日あたりの上限があり、無料会員は1日1本、プレミアム会員は1日3本までです。'**
  String get helpCommunityDesc;

  /// No description provided for @helpWatermarkEntryTitle.
  ///
  /// In ja, this message translates to:
  /// **'ウォーターマーク'**
  String get helpWatermarkEntryTitle;

  /// No description provided for @helpWatermarkEntryDesc.
  ///
  /// In ja, this message translates to:
  /// **'書き出した動画・画像に、自分の署名やロゴを透かしとして入れられるプレミアム限定機能です。位置・大きさ・不透明度を調整できます。タイムラインの共通レイヤートラックに配置したウォーターマークをタップすると、角度・大きさ・不透明度・表示範囲（ループ表示）をいつでも再編集できます。登録時だけでなく、実際にプロジェクト内で使うタイミングで細かく調整できます。'**
  String get helpWatermarkEntryDesc;

  /// No description provided for @helpPremiumEntryTitle.
  ///
  /// In ja, this message translates to:
  /// **'プレミアム'**
  String get helpPremiumEntryTitle;

  /// No description provided for @helpPremiumEntryDesc.
  ///
  /// In ja, this message translates to:
  /// **'プレミアム会員になると、無料版で90秒までに制限されている動画の尺が最大2時間まで拡大され、動画の最後に自動追加されるエンドカード（アプリロゴ）を削除できます。広告も非表示になり、ウォーターマーク・トーンカーブ・レベル補正機能も利用できるようになります。'**
  String get helpPremiumEntryDesc;

  /// No description provided for @helpPerformanceSettingsTitle.
  ///
  /// In ja, this message translates to:
  /// **'パフォーマンス設定'**
  String get helpPerformanceSettingsTitle;

  /// No description provided for @helpPerformanceSettingsDesc.
  ///
  /// In ja, this message translates to:
  /// **'端末の性能に応じて、低品質・中品質・高品質のプリセットから選ぶか、各項目を個別に設定（カスタム）できます。保存方式・動作の軽さ・オニオンスキン・傾き検知に加えて、Undo回数やゴミ箱の自動削除などアプリの容量・動作の重さに影響する設定もここにまとまっています。'**
  String get helpPerformanceSettingsDesc;

  /// No description provided for @helpMaterialClipTitle.
  ///
  /// In ja, this message translates to:
  /// **'素材クリップ（画像・動画・音声）'**
  String get helpMaterialClipTitle;

  /// No description provided for @helpMaterialClipDesc.
  ///
  /// In ja, this message translates to:
  /// **'タイムラインの画像・動画・音声トラックに配置したクリップです。クリップ本体を長押しドラッグすると表示開始位置を移動でき、左右端のハンドルをドラッグすると使用範囲（長さ）を変更できます。タップすると開く詳細シートのコピーアイコンから複製、ゴミ箱アイコンから削除もできます。画像・動画は内部的にはレイヤーとして扱われており、音声はシーンに直接紐づくクリップとして管理されます。'**
  String get helpMaterialClipDesc;

  /// No description provided for @helpGestureSettingsTitle.
  ///
  /// In ja, this message translates to:
  /// **'ジェスチャー設定'**
  String get helpGestureSettingsTitle;

  /// No description provided for @helpGestureSettingsDesc.
  ///
  /// In ja, this message translates to:
  /// **'2本指タップ・3本指タップ・2本指スワイプ・長押しに、Undo/Redo・フレーム移動・スポイトなどの操作を割り当てられる設定です。ペンボタン（対応スタイラス使用時）にも別途操作を割り当てられます。指を使わずワンタッチで頻用操作を呼び出したい場合に便利です。'**
  String get helpGestureSettingsDesc;

  /// No description provided for @helpBucketDetailSettingsTitle.
  ///
  /// In ja, this message translates to:
  /// **'バケツ塗り詳細設定'**
  String get helpBucketDetailSettingsTitle;

  /// No description provided for @helpBucketDetailSettingsDesc.
  ///
  /// In ja, this message translates to:
  /// **'設定画面の「バケツ塗り」から、許容誤差（クリックした位置の色からどこまでの色差を同一領域とみなすか）・拡張px（塗った範囲を境界の外側へ広げて線画との隙間を埋める量）・線の下まで潜る（拡張分を線画の上から上書きせず、線の見た目を保ったまま背後へ塗り色を合成する）を調整できます。線画に細かい隙間がある場合や、塗り残しが気になる場合に調整すると仕上がりが安定します。'**
  String get helpBucketDetailSettingsDesc;

  /// No description provided for @helpStampToolTitle.
  ///
  /// In ja, this message translates to:
  /// **'スタンプツール'**
  String get helpStampToolTitle;

  /// No description provided for @helpStampToolDesc.
  ///
  /// In ja, this message translates to:
  /// **'あらかじめ登録した画像をブラシのようにキャンバスへ配置するツールです。効果線・背景パターン・小物などを毎回描き直さずに使い回せます。ピクセルモードをONにすると、貼り付けたスタンプをモザイク低解像度化＋色数削減でドット絵風に加工できます。 スタンプパネルでは配置するスタンプの回転角度・大きさを調整できます。同じスタンプでも向きやサイズを変えて配置すれば、単調にならず自然な効果線・小物の並びを作れます。'**
  String get helpStampToolDesc;

  /// No description provided for @helpToneFillTitle.
  ///
  /// In ja, this message translates to:
  /// **'トーン塗り'**
  String get helpToneFillTitle;

  /// No description provided for @helpToneFillDesc.
  ///
  /// In ja, this message translates to:
  /// **'バケツツールの設定でベタ塗りからトーン塗りへ切り替えると、選択した網点・ライン柄などのトーンパターンで塗りつぶせます。ピクセルモード専用の市松模様・格子柄トーンも用意されており、ドット絵の質感を活かした塗りができます。フリルやニット、タイツなど、手描きでは手間のかかる細かい柄も簡単に描けます。オリジナルのトーンを自作して追加したり、ほかの人と共有したりすることも可能です。'**
  String get helpToneFillDesc;

  /// No description provided for @helpPixelModeTitle.
  ///
  /// In ja, this message translates to:
  /// **'ピクセルモード'**
  String get helpPixelModeTitle;

  /// No description provided for @helpPixelModeDesc.
  ///
  /// In ja, this message translates to:
  /// **'ブラシ・フォント・スタンプのそれぞれに用意されている設定で、ONにするとアンチエイリアスを取り除き、くっきりとしたドット絵風の輪郭で描画されます。あえて古いゲームのような質感を出したい時や、低解像度感を演出したい時に使います。配色方式は「色を指定しない」「色を指定する」「色数を指定する」「パレットから選ぶ」の4種類から選べ、ドット絵専用パレットを使った配色もできます。'**
  String get helpPixelModeDesc;

  /// No description provided for @helpHomeScreenTitle.
  ///
  /// In ja, this message translates to:
  /// **'ホーム画面'**
  String get helpHomeScreenTitle;

  /// No description provided for @helpHomeScreenDesc.
  ///
  /// In ja, this message translates to:
  /// **'アプリを起動して最初に表示される画面で、プロジェクト・共有・作品一覧・ゴミ箱の各タブを切り替えて閲覧できます。右上の検索アイコンからプロジェクト名で絞り込み検索もできます。プロジェクトタブでは新規プロジェクト作成とフォルダ作成を画面右下の＋ボタンから選べます。'**
  String get helpHomeScreenDesc;

  /// No description provided for @helpNewProjectTitle.
  ///
  /// In ja, this message translates to:
  /// **'新規プロジェクト作成'**
  String get helpNewProjectTitle;

  /// No description provided for @helpNewProjectDesc.
  ///
  /// In ja, this message translates to:
  /// **'キャンバスサイズ・fps・長さ（秒数。あとからタイムラインでのフレーム増減にも連動）・描画領域（書き出し範囲より広く描いておける設定）・使用する自動塗り設定などをまとめて指定してからプロジェクトを作成します。'**
  String get helpNewProjectDesc;

  /// No description provided for @helpThemeSettingsTitle.
  ///
  /// In ja, this message translates to:
  /// **'テーマ設定'**
  String get helpThemeSettingsTitle;

  /// No description provided for @helpThemeSettingsDesc.
  ///
  /// In ja, this message translates to:
  /// **'アプリ全体の配色をテーマ一覧から選んだり、差し色を自由にカスタマイズしたりできる画面です。見出し・項目名用フォントと説明文用フォントが分かれており、視認性を保ちながら着せ替えを楽しめます。'**
  String get helpThemeSettingsDesc;

  /// No description provided for @helpWorkspaceSettingsTitle.
  ///
  /// In ja, this message translates to:
  /// **'ワークスペース設定'**
  String get helpWorkspaceSettingsTitle;

  /// No description provided for @helpWorkspaceSettingsDesc.
  ///
  /// In ja, this message translates to:
  /// **'左利きモード（ドッキングパネルを左右反転）、PC/DeXモードの手動切替、手のひらツールの表示条件などをまとめて設定できる画面です。使用端末や利き手に合わせて作業しやすいレイアウトに調整できます。'**
  String get helpWorkspaceSettingsDesc;

  /// No description provided for @helpPenSettingsTitle.
  ///
  /// In ja, this message translates to:
  /// **'ペン設定'**
  String get helpPenSettingsTitle;

  /// No description provided for @helpPenSettingsDesc.
  ///
  /// In ja, this message translates to:
  /// **'板タブ・液晶タブレットの筆圧カーブに加えて、ペン側面のボタン（対応スタイラス使用時）に消しゴム切替やスポイトなどの操作を割り当てられる設定画面です。'**
  String get helpPenSettingsDesc;

  /// No description provided for @helpMaterialListTitle.
  ///
  /// In ja, this message translates to:
  /// **'素材一覧'**
  String get helpMaterialListTitle;

  /// No description provided for @helpMaterialListDesc.
  ///
  /// In ja, this message translates to:
  /// **'プロジェクトで使用している画像・動画・音声素材をまとめて確認できる画面です。タイムラインへ配置した素材の元ファイルがここに集約されます。'**
  String get helpMaterialListDesc;

  /// No description provided for @helpFrameOperationsTitle.
  ///
  /// In ja, this message translates to:
  /// **'フレーム操作'**
  String get helpFrameOperationsTitle;

  /// No description provided for @helpFrameOperationsDesc.
  ///
  /// In ja, this message translates to:
  /// **'フレーム一覧では新規追加・複製・削除に加えて、複数選択モードで複数フレームをまとめて移動・複製・削除できます。保持セル数を増やすと同じフレームを複数コマ分表示させ続けられる（いわゆる「止め」）ので、動きの少ないカットで枚数を節約できます。'**
  String get helpFrameOperationsDesc;

  /// No description provided for @helpSceneOperationsTitle.
  ///
  /// In ja, this message translates to:
  /// **'シーン操作'**
  String get helpSceneOperationsTitle;

  /// No description provided for @helpSceneOperationsDesc.
  ///
  /// In ja, this message translates to:
  /// **'タイムラインのシーンタブでは、シーンの追加・複製・削除・名前変更・並び替えができます。複数選択モードにすると複数シーンをまとめて移動・複製・削除することも可能です。'**
  String get helpSceneOperationsDesc;

  /// No description provided for @helpQuickToolManagementTitle.
  ///
  /// In ja, this message translates to:
  /// **'早替えツール管理'**
  String get helpQuickToolManagementTitle;

  /// No description provided for @helpQuickToolManagementDesc.
  ///
  /// In ja, this message translates to:
  /// **'よく使うツールの組み合わせを登録し、タップひとつで順番に切り替えられる機能です。長押しまたは上スワイプで管理ポップアップを開き、登録内容や並び順を編集できます。'**
  String get helpQuickToolManagementDesc;

  /// No description provided for @helpTransformSelectionTitle.
  ///
  /// In ja, this message translates to:
  /// **'選択範囲の変形'**
  String get helpTransformSelectionTitle;

  /// No description provided for @helpTransformSelectionDesc.
  ///
  /// In ja, this message translates to:
  /// **'選択ツールで囲んだ範囲は、変形ツールで移動・回転・拡大縮小できます。誤って描いた部分の位置調整や、一部だけを拡大して強調したい時などに使います。 レイヤー全体を対象にしたい場合は、範囲選択を使わない「自由変形・メッシュ変形」（編集メニューから開く）を使うと、格子点を個別にドラッグしてより自由な変形ができます。'**
  String get helpTransformSelectionDesc;

  /// No description provided for @helpGradientAutofillTitle.
  ///
  /// In ja, this message translates to:
  /// **'グラデーション塗り（自動塗り設定）'**
  String get helpGradientAutofillTitle;

  /// No description provided for @helpGradientAutofillDesc.
  ///
  /// In ja, this message translates to:
  /// **'自動塗り設定の各パーツには単色だけでなくグラデーションも設定できます。ドラッグで移動できる対称ハンドルにより、直感的にグラデーションの範囲・角度を調整できます。 各パーツには「指定色で縁取り」も設定できます。チェックを入れると、塗り範囲の一番外側（線画に接する部分）に指定した色・太さのラインが引かれます。縁取り色はカラーピッカーで自由に選べ、太さはスライダー・±ボタン・数値タップでの直接入力のいずれでも調整できます。設定項目のすぐ上にプレビューが表示されるため、実際に自動塗りを実行する前に色と太さを確認できます。'**
  String get helpGradientAutofillDesc;

  /// No description provided for @helpColorPickerTitle.
  ///
  /// In ja, this message translates to:
  /// **'カラーピッカー'**
  String get helpColorPickerTitle;

  /// No description provided for @helpColorPickerDesc.
  ///
  /// In ja, this message translates to:
  /// **'HSVとRGBを1つの画面で切り替えながら色を選べるカラーピッカーです。パレット機能で使用中のカラーセットを保存・呼び出しできます。パレットはファイル書き出しやQRコードで他の端末と共有することもできます。'**
  String get helpColorPickerDesc;

  /// No description provided for @helpUndoSettingsTitle.
  ///
  /// In ja, this message translates to:
  /// **'Undo（元に戻す）回数設定'**
  String get helpUndoSettingsTitle;

  /// No description provided for @helpUndoSettingsDesc.
  ///
  /// In ja, this message translates to:
  /// **'パフォーマンス設定から、Undoで遡れる操作回数を調整できます。回数を増やすほど安心して試行錯誤できますが、メモリ使用量も増えるため、低スペック端末では回数を抑えると動作が軽くなります。'**
  String get helpUndoSettingsDesc;

  /// No description provided for @helpBrushFavoriteTitle.
  ///
  /// In ja, this message translates to:
  /// **'ブラシのお気に入り'**
  String get helpBrushFavoriteTitle;

  /// No description provided for @helpBrushFavoriteDesc.
  ///
  /// In ja, this message translates to:
  /// **'ブラシ一覧の各ブラシにある星アイコンをタップすると、お気に入り登録・解除ができます（自動塗り設定・スタンプ・フォント・描画フィルターなど、アプリ内の他のお気に入り機能と同じ操作方法です）。一覧上部の星アイコンで、お気に入りのみ表示に絞り込むこともできます。誤って削除しないよう、お気に入り登録中のブラシは削除できません。'**
  String get helpBrushFavoriteDesc;

  /// No description provided for @helpCustomBrushTitle.
  ///
  /// In ja, this message translates to:
  /// **'カスタムブラシ'**
  String get helpCustomBrushTitle;

  /// No description provided for @helpCustomBrushDesc.
  ///
  /// In ja, this message translates to:
  /// **'ブラシ一覧でプリインストールのブラシを長押しして「複製」すると、それを元にした自分専用のカスタムブラシが作成されます。複製したブラシは太さ・不透明度・硬さ・回転・密度・散布・ぼかし半径などのパラメータを自由に編集でき、不要になれば削除もできます（プリインストールのブラシ自体は編集・削除できません）。フォルダで分類したり、星アイコンでお気に入り登録することもできます。'**
  String get helpCustomBrushDesc;

  /// No description provided for @helpLayerFolderTitle.
  ///
  /// In ja, this message translates to:
  /// **'レイヤーフォルダ'**
  String get helpLayerFolderTitle;

  /// No description provided for @helpLayerFolderDesc.
  ///
  /// In ja, this message translates to:
  /// **'複数のレイヤーをフォルダにまとめて整理できる機能です。パーツ数が多いイラストでもレイヤーパネルが見やすくなります。クリッピングはフォルダをまたいで適用できない仕様のため、クリッピングを使う場合は同じフォルダ内でまとめておくと安全です。'**
  String get helpLayerFolderDesc;

  /// No description provided for @helpLayerMultiSelectTitle.
  ///
  /// In ja, this message translates to:
  /// **'レイヤーの複数選択・一括操作'**
  String get helpLayerMultiSelectTitle;

  /// No description provided for @helpLayerMultiSelectDesc.
  ///
  /// In ja, this message translates to:
  /// **'レイヤーパネルの選択モードを使うと、複数のレイヤーをチェックボックスでまとめて選び、結合や一括削除ができます。結合は通常・自動塗り用線画・自動塗りレイヤー同士でのみ可能です（共通レイヤー・フォルダ・タイムライン素材は結合対象外）。'**
  String get helpLayerMultiSelectDesc;

  /// No description provided for @helpDrawingAreaTitle.
  ///
  /// In ja, this message translates to:
  /// **'描画領域'**
  String get helpDrawingAreaTitle;

  /// No description provided for @helpDrawingAreaDesc.
  ///
  /// In ja, this message translates to:
  /// **'書き出し範囲よりも広い範囲まで描いておける設定です。キャンバス上には書き出し範囲を示す赤枠が表示され、枠の外側にはみ出して描いた部分は書き出されませんが、パン・ズームなどのカメラワークで見せる範囲を後から調整する余地を残せます。新規プロジェクト作成時に倍率を設定します。'**
  String get helpDrawingAreaDesc;

  /// No description provided for @helpCanvasBackgroundTitle.
  ///
  /// In ja, this message translates to:
  /// **'キャンバスの背景色'**
  String get helpCanvasBackgroundTitle;

  /// No description provided for @helpCanvasBackgroundDesc.
  ///
  /// In ja, this message translates to:
  /// **'プロジェクトのキャンバス背景色を設定できます。透過書き出し（透過WebM）を使う場合は背景色は書き出しに影響しませんが、作業中の見やすさのために好みの色に変更できます。'**
  String get helpCanvasBackgroundDesc;

  /// No description provided for @helpProjectDetailTitle.
  ///
  /// In ja, this message translates to:
  /// **'プロジェクト詳細画面'**
  String get helpProjectDetailTitle;

  /// No description provided for @helpProjectDetailDesc.
  ///
  /// In ja, this message translates to:
  /// **'プロジェクト名・サムネイル・お気に入り登録・使用する自動塗り設定の絞り込みなど、プロジェクト単位の設定をまとめて確認・編集できる画面です。セーブツリーへの入り口もここにあります。'**
  String get helpProjectDetailDesc;

  /// No description provided for @helpWatermarkEditTitle.
  ///
  /// In ja, this message translates to:
  /// **'ウォーターマークの再編集'**
  String get helpWatermarkEditTitle;

  /// No description provided for @helpWatermarkEditDesc.
  ///
  /// In ja, this message translates to:
  /// **'タイムラインの共通レイヤートラックに配置したウォーターマークをタップすると、角度・大きさ・不透明度・表示範囲（ループ表示）をいつでも再編集できます。登録時だけでなく、実際にプロジェクト内で使うタイミングで細かく調整できます。'**
  String get helpWatermarkEditDesc;

  /// No description provided for @helpAudioClipTitle.
  ///
  /// In ja, this message translates to:
  /// **'音声クリップの音量・フェード'**
  String get helpAudioClipTitle;

  /// No description provided for @helpAudioClipDesc.
  ///
  /// In ja, this message translates to:
  /// **'タイムラインに配置した音声クリップは、詳細シートから音量・フェードイン・フェードアウトの秒数を調整できます。効果音やBGMの音量バランスを整えたり、曲の始まり・終わりを滑らかにしたりできます。'**
  String get helpAudioClipDesc;

  /// No description provided for @helpPenSubToolTitle.
  ///
  /// In ja, this message translates to:
  /// **'ペンサブツール'**
  String get helpPenSubToolTitle;

  /// No description provided for @helpPenSubToolDesc.
  ///
  /// In ja, this message translates to:
  /// **'ペンツールを長押しすると、通常の描画に加えてトーン貼り・スタンプ配置のサブツールへ切り替えられます。ツールをいちいち切り替えずに、同じペンから複数の作業を行き来できます。'**
  String get helpPenSubToolDesc;

  /// No description provided for @helpTiltDetectionTitle.
  ///
  /// In ja, this message translates to:
  /// **'傾き検知'**
  String get helpTiltDetectionTitle;

  /// No description provided for @helpTiltDetectionDesc.
  ///
  /// In ja, this message translates to:
  /// **'対応スタイラスの傾き情報を使って、筆先を寝かせたときに線を太く・薄くするなど、実際の筆記具に近い描き心地を再現する設定です。パフォーマンス設定からON/OFFを切り替えられます。'**
  String get helpTiltDetectionDesc;

  /// No description provided for @helpFontImportTitle.
  ///
  /// In ja, this message translates to:
  /// **'フォントの読み込み'**
  String get helpFontImportTitle;

  /// No description provided for @helpFontImportDesc.
  ///
  /// In ja, this message translates to:
  /// **'端末内のフォントファイルを直接読み込んで使えるようにする機能です。設定画面のフォント管理「読み込み」タブから追加できます。配信されていない自作フォントや購入した商用フォントを使いたい場合に利用します。'**
  String get helpFontImportDesc;

  /// No description provided for @helpExportScreenTitle.
  ///
  /// In ja, this message translates to:
  /// **'書き出し画面'**
  String get helpExportScreenTitle;

  /// No description provided for @helpExportScreenDesc.
  ///
  /// In ja, this message translates to:
  /// **'動画・画像の書き出し中は進捗状況が表示され、途中でキャンセルすることもできます。書き出しにかかる時間は端末の性能によって変わります。'**
  String get helpExportScreenDesc;

  /// No description provided for @helpDrawingFilterTitle.
  ///
  /// In ja, this message translates to:
  /// **'描画フィルター'**
  String get helpDrawingFilterTitle;

  /// No description provided for @helpDrawingFilterDesc.
  ///
  /// In ja, this message translates to:
  /// **'選択中のレイヤーに直接適用するフィルターです（演出フィルターがタイムライン全体・シーン単位に適用されるのに対し、描画フィルターはレイヤー単位）。ぼかし・シャープ・アンシャープマスク・トーンカーブ・レベル補正・周辺減光・ノイズ・レトロアニメ・ブラウン管・アニメ調・縁取り・ドット絵・眼鏡断層フィルターなどが用意されています。縁取りは元のレイヤーを書き換えず、縁どった内容だけを新規レイヤーへ描画します。眼鏡断層フィルターは、選択レイヤーで塗った範囲だけに、度数の強い眼鏡レンズのような局所的な歪みをかけられます。ドット絵は配色方式（色を指定しない・色を指定する・色数を指定する・パレットから選ぶ）も選べます。'**
  String get helpDrawingFilterDesc;

  /// No description provided for @helpLayerKeyframeTitle.
  ///
  /// In ja, this message translates to:
  /// **'レイヤーキーフレーム（パーツ単位アニメーション）'**
  String get helpLayerKeyframeTitle;

  /// No description provided for @helpLayerKeyframeDesc.
  ///
  /// In ja, this message translates to:
  /// **'各レイヤーの位置・拡大縮小・回転をフレームごとに指定し、キーフレーム間を自動で補間する機能です。カメラキーフレームが画面全体を動かすのに対し、こちらは個々のレイヤーだけを動かします。自動塗りの各パーツはそれぞれ独立したレイヤーとして生成されるため、パーツ単位でのアニメーション（腕だけ動かす、口だけ開閉させる等）にそのまま使えます。各キーフレームには「等速」「ゆっくり始まる」「ゆっくり終わる」「ゆっくり始まって終わる」「弾む」というイージング（次のキーフレームへのつなぎ方）を個別に設定でき、単調な等速移動だけでなく弾むような動きも表現できます。レイヤーパネルの三点メニュー「アニメーション（キーフレーム）」から設定します。レイヤーの絵自体は変わらず、表示位置だけが変わる非破壊な変形です。この機能はタイムラインの表示（プレビュー・書き出し）にのみ影響し、キャンバスモードでの実際の作画には影響しません。'**
  String get helpLayerKeyframeDesc;

  /// No description provided for @helpLayerGroupTitle.
  ///
  /// In ja, this message translates to:
  /// **'レイヤーグループ（複数パーツをまとめて動かす）'**
  String get helpLayerGroupTitle;

  /// No description provided for @helpLayerGroupDesc.
  ///
  /// In ja, this message translates to:
  /// **'複数のレイヤーをまとめて1つのキーフレームストリームで動かす機能です。例えば「腕」が肌・袖の2枚の自動塗りパーツで構成されている場合、この2枚をグループ化しておけば、1回のキーフレーム操作でまとめて動かせます。レイヤーパネルで複数選択（チェックボックス）した状態で下部バーの「グループ化」アイコンから作成します。グループの動きは各レイヤー自身のキーフレーム（設定されていれば）に重ねて適用されるため、グループ全体の動き＋個別レイヤーの微調整、という組み合わせも可能です。1つのレイヤーは同時に1つのグループにのみ所属できます。'**
  String get helpLayerGroupDesc;

  /// No description provided for @tipsScreenTitle.
  ///
  /// In ja, this message translates to:
  /// **'活用Tips'**
  String get tipsScreenTitle;

  /// No description provided for @tipsSearchHint.
  ///
  /// In ja, this message translates to:
  /// **'Tipsを検索...'**
  String get tipsSearchHint;

  /// No description provided for @tipsCategoryVideo.
  ///
  /// In ja, this message translates to:
  /// **'動画制作のコツ'**
  String get tipsCategoryVideo;

  /// No description provided for @tipsCategoryEfficiency.
  ///
  /// In ja, this message translates to:
  /// **'制作を効率化するコツ'**
  String get tipsCategoryEfficiency;

  /// No description provided for @tipsCategoryDrawing.
  ///
  /// In ja, this message translates to:
  /// **'作画をなめらかにするコツ'**
  String get tipsCategoryDrawing;

  /// No description provided for @tipsCategoryEffects.
  ///
  /// In ja, this message translates to:
  /// **'演出・仕上げのコツ'**
  String get tipsCategoryEffects;

  /// No description provided for @tipsCategoryExport.
  ///
  /// In ja, this message translates to:
  /// **'書き出し・操作のコツ'**
  String get tipsCategoryExport;

  /// No description provided for @tipsClipDuplicateTitle.
  ///
  /// In ja, this message translates to:
  /// **'タイムラインの素材は複製・移動・削除ができる'**
  String get tipsClipDuplicateTitle;

  /// No description provided for @tipsClipDuplicateDesc.
  ///
  /// In ja, this message translates to:
  /// **'画像・動画・音声クリップをタップすると開く詳細シートのコピーアイコンから複製できます。同じ効果音を繰り返し使う、同じ画像を場面ごとに配置し直すといった編集が、長押しドラッグと複製ボタンだけで完結します。'**
  String get tipsClipDuplicateDesc;

  /// No description provided for @tipsTextCaptionTitle.
  ///
  /// In ja, this message translates to:
  /// **'テキストツールで字幕を入れる'**
  String get tipsTextCaptionTitle;

  /// No description provided for @tipsTextCaptionDesc.
  ///
  /// In ja, this message translates to:
  /// **'テキストツールを使えば、字幕やコメントをフレームごとに配置できます。フォントをピクセルモードに切り替えると、レトロゲーム風の質感を演出することもできます。'**
  String get tipsTextCaptionDesc;

  /// No description provided for @tipsAutofillPresetTitle.
  ///
  /// In ja, this message translates to:
  /// **'自動塗り設定はパーツごとに登録しておく'**
  String get tipsAutofillPresetTitle;

  /// No description provided for @tipsAutofillPresetDesc.
  ///
  /// In ja, this message translates to:
  /// **'肌・髪・服などパーツごとに陰影込みで自動塗り設定を登録しておくと、線画を描くだけで色塗りの大部分を自動化できます。プロジェクトごとに使う設定だけを絞り込むこともできます。'**
  String get tipsAutofillPresetDesc;

  /// No description provided for @tipsAutofillBaseCoatTitle.
  ///
  /// In ja, this message translates to:
  /// **'自動塗りはパーツ分けせず下塗り用に使うだけでも便利'**
  String get tipsAutofillBaseCoatTitle;

  /// No description provided for @tipsAutofillBaseCoatDesc.
  ///
  /// In ja, this message translates to:
  /// **'自動塗りは本来パーツごとに色分けする機能ですが、丁寧に分けなくても、線画全体を1色で塗るだけの下塗りレイヤーとして使うだけで十分便利です。線の内側を一括で塗りつぶせるため、手動のバケツ塗りで起きがちな塗り残し（線の隙間から下の色が透けてしまうミス）を防げます。その上に手動で色を重ねれば、パーツ分けの手間をかけずに恩恵だけ得られます。'**
  String get tipsAutofillBaseCoatDesc;

  /// No description provided for @tipsBrushFavoriteTitle.
  ///
  /// In ja, this message translates to:
  /// **'ブラシはお気に入り登録で迷わず選べる'**
  String get tipsBrushFavoriteTitle;

  /// No description provided for @tipsBrushFavoriteDesc.
  ///
  /// In ja, this message translates to:
  /// **'よく使うブラシは一覧の星アイコンをタップしてお気に入り登録しておきましょう。一覧上部の星アイコンでお気に入りのみに絞り込めるので、探す手間が減ります。誤って削除しないよう、お気に入り登録中は削除できない仕組みになっています。'**
  String get tipsBrushFavoriteDesc;

  /// No description provided for @tipsPressureCurveTitle.
  ///
  /// In ja, this message translates to:
  /// **'筆圧カーブを自分好みに調整する'**
  String get tipsPressureCurveTitle;

  /// No description provided for @tipsPressureCurveDesc.
  ///
  /// In ja, this message translates to:
  /// **'設定画面の筆圧カーブは最大10点の制御点を自由に打てます。強弱の付き方が合わないと感じたら、自分の筆圧の癖に合わせて調整してみましょう。'**
  String get tipsPressureCurveDesc;

  /// No description provided for @tipsExportFormatTitle.
  ///
  /// In ja, this message translates to:
  /// **'用途に合わせて書き出し形式を選ぶ'**
  String get tipsExportFormatTitle;

  /// No description provided for @tipsExportFormatDesc.
  ///
  /// In ja, this message translates to:
  /// **'SNSに気軽に投稿したいときはGIF書き出し、他の動画に重ねたい・背景を透かしたいときは透過WebM、通常の動画として使いたいときはMP4書き出しが向いています。用途ごとに使い分けると、ファイルサイズと画質のバランスを取りやすくなります。'**
  String get tipsExportFormatDesc;

  /// No description provided for @tipsGestureShortcutTitle.
  ///
  /// In ja, this message translates to:
  /// **'ジェスチャーで頻用操作をワンタッチに'**
  String get tipsGestureShortcutTitle;

  /// No description provided for @tipsGestureShortcutDesc.
  ///
  /// In ja, this message translates to:
  /// **'設定画面の「ジェスチャー」から、2本指タップ・3本指タップ・長押しなどにUndo/Redoやスポイトを割り当てられます。ツールを切り替えずに済むので、作画のテンポを崩さずに済みます。'**
  String get tipsGestureShortcutDesc;

  /// No description provided for @tipsAudioRepeatTitle.
  ///
  /// In ja, this message translates to:
  /// **'効果音はクリップ複製×フェードでリズムよく鳴らす'**
  String get tipsAudioRepeatTitle;

  /// No description provided for @tipsAudioRepeatDesc.
  ///
  /// In ja, this message translates to:
  /// **'同じ効果音を繰り返し使いたい場合、クリップを複製してタイミングをずらして並べ、それぞれにフェードイン・アウトを設定すると、リズムに合った自然な効果音の連打が作れます。'**
  String get tipsAudioRepeatDesc;

  /// No description provided for @tipsVerticalRubyTitle.
  ///
  /// In ja, this message translates to:
  /// **'縦書き×ルビでタイトルロゴ風の演出'**
  String get tipsVerticalRubyTitle;

  /// No description provided for @tipsVerticalRubyDesc.
  ///
  /// In ja, this message translates to:
  /// **'テキストツールの縦書きにルビを組み合わせると、和風のタイトルロゴやこだわりの見出し演出が作れます。半角英数字は自動で横向きに回転して並ぶので、記号や数字が混ざっても読みやすく仕上がります。'**
  String get tipsVerticalRubyDesc;

  /// No description provided for @tipsBrushTrySaveTreeTitle.
  ///
  /// In ja, this message translates to:
  /// **'新しいブラシ設定はセーブツリーで試す'**
  String get tipsBrushTrySaveTreeTitle;

  /// No description provided for @tipsBrushTrySaveTreeDesc.
  ///
  /// In ja, this message translates to:
  /// **'ブラシの太さや安定化などを大きく変えて試したいときは、変更前にセーブツリーへ保存しておくと安心です。気に入らなければすぐに元の状態へ戻せるので、思い切った調整を試しやすくなります。'**
  String get tipsBrushTrySaveTreeDesc;

  /// No description provided for @tipsEyedropperGestureTitle.
  ///
  /// In ja, this message translates to:
  /// **'2本指タップにスポイトを割り当てて配色を崩さない'**
  String get tipsEyedropperGestureTitle;

  /// No description provided for @tipsEyedropperGestureDesc.
  ///
  /// In ja, this message translates to:
  /// **'ジェスチャー設定で2本指タップにスポイトを割り当てておくと、ツールを切り替えずに近くの色をすぐ拾えます。キャラクターの配色を保ったまま塗り進めたいときに便利です。'**
  String get tipsEyedropperGestureDesc;

  /// No description provided for @tipsRulerOnionTitle.
  ///
  /// In ja, this message translates to:
  /// **'パース定規×オニオンスキンで背景を使い回す'**
  String get tipsRulerOnionTitle;

  /// No description provided for @tipsRulerOnionDesc.
  ///
  /// In ja, this message translates to:
  /// **'パース定規で背景の奥行きを決めておき、オニオンスキンで前後フレームを透かして見ながらキャラクターだけを動かすと、背景を毎フレーム描き直さずに済みます。'**
  String get tipsRulerOnionDesc;

  /// No description provided for @tipsGradientTraceTitle.
  ///
  /// In ja, this message translates to:
  /// **'グラデーション自動塗り×色トレスで馴染ませる'**
  String get tipsGradientTraceTitle;

  /// No description provided for @tipsGradientTraceDesc.
  ///
  /// In ja, this message translates to:
  /// **'自動塗り設定でグラデーションを使う際、線画色設定を色トレス（線画馴染ませ）にしておくと、グラデーションの微妙な色の変化に合わせて線画の色も馴染み、境界が浮きにくくなります。'**
  String get tipsGradientTraceDesc;

  /// No description provided for @tipsGradientOutlineHairTitle.
  ///
  /// In ja, this message translates to:
  /// **'グラデーション×指定色縁取りで前髪に透明感を出す'**
  String get tipsGradientOutlineHairTitle;

  /// No description provided for @tipsGradientOutlineHairDesc.
  ///
  /// In ja, this message translates to:
  /// **'自動塗り設定で前髪パーツを作り、塗り色をグラデーションにして髪色と透明色の2色を選びます。角度を90度に変更し、ぼかしの強さと色の切り替え位置をお好みに調整したら、「指定色で縁取り」をチェックして縁取り色を「最近使った色」から先ほどの前髪の色と同じものを選びます。前髪の下塗りパーツだけでなく影色パーツにも同じ手順を繰り返すと、毛先が透けるような透明感のある髪の毛になります。'**
  String get tipsGradientOutlineHairDesc;

  /// No description provided for @tipsRainNoiseTitle.
  ///
  /// In ja, this message translates to:
  /// **'雨フィルター×動くノイズでしっとりした空気感'**
  String get tipsRainNoiseTitle;

  /// No description provided for @tipsRainNoiseDesc.
  ///
  /// In ja, this message translates to:
  /// **'雨フィルターに弱めの動くノイズフィルターを重ねると、雨粒だけでなく空気中の粒子感も加わり、しっとりとした雨の日らしい質感を演出できます。'**
  String get tipsRainNoiseDesc;

  /// No description provided for @tipsPartKeyframeGroupTitle.
  ///
  /// In ja, this message translates to:
  /// **'パーツキーフレーム×グループ化でキャラを弾ませる'**
  String get tipsPartKeyframeGroupTitle;

  /// No description provided for @tipsPartKeyframeGroupDesc.
  ///
  /// In ja, this message translates to:
  /// **'自動塗りの各パーツにレイヤーキーフレームを付けて動かし、さらに関連パーツをグループ化してまとめて弾ませると、音楽に合わせて揺れるようなミニアニメーションを描き直しなしで作れます。'**
  String get tipsPartKeyframeGroupDesc;

  /// No description provided for @tipsLowSpecSettingsTitle.
  ///
  /// In ja, this message translates to:
  /// **'低スペック端末はパフォーマンス設定とUndo回数を見直す'**
  String get tipsLowSpecSettingsTitle;

  /// No description provided for @tipsLowSpecSettingsDesc.
  ///
  /// In ja, this message translates to:
  /// **'動作が重いと感じたら、パフォーマンス設定を「低品質」プリセットに切り替え、Undo回数も減らしてみましょう。メモリ使用量が減り、動作が軽くなることがあります。'**
  String get tipsLowSpecSettingsDesc;

  /// No description provided for @tipsSeriesPresetFolderTitle.
  ///
  /// In ja, this message translates to:
  /// **'シリーズ物は自動塗り設定の絞り込み×フォルダ整理で管理する'**
  String get tipsSeriesPresetFolderTitle;

  /// No description provided for @tipsSeriesPresetFolderDesc.
  ///
  /// In ja, this message translates to:
  /// **'同じ作品の複数話数を作るときは、フォルダで話数ごとにプロジェクトをまとめ、各プロジェクトで使う自動塗り設定を絞り込んでおくと、キャラごとの配色を混同せず効率よく作業できます。'**
  String get tipsSeriesPresetFolderDesc;

  /// No description provided for @tipsPixelToneRetroTitle.
  ///
  /// In ja, this message translates to:
  /// **'スタンプのピクセルモード×トーン塗りでレトロ統一'**
  String get tipsPixelToneRetroTitle;

  /// No description provided for @tipsPixelToneRetroDesc.
  ///
  /// In ja, this message translates to:
  /// **'ピクセルモードのスタンプと、ピクセルモード専用の市松・格子柄トーンを組み合わせると、画面全体をドット絵風の質感で統一できます。レトロゲーム風の演出に向いています。'**
  String get tipsPixelToneRetroDesc;

  /// No description provided for @tipsMagicWandLassoTitle.
  ///
  /// In ja, this message translates to:
  /// **'マジックワンド選択×投げ縄塗りで塗り分け効率化'**
  String get tipsMagicWandLassoTitle;

  /// No description provided for @tipsMagicWandLassoDesc.
  ///
  /// In ja, this message translates to:
  /// **'選択ツールの自動選択（マジックワンド）でおおまかな範囲を一括選択し、はみ出た部分だけ投げ縄選択で調整すると、複雑な塗り分けも素早く行えます。'**
  String get tipsMagicWandLassoDesc;

  /// No description provided for @tipsCommonLayerFolderTitle.
  ///
  /// In ja, this message translates to:
  /// **'共通レイヤー×フォルダで話数をまたいで使い回す'**
  String get tipsCommonLayerFolderTitle;

  /// No description provided for @tipsCommonLayerFolderDesc.
  ///
  /// In ja, this message translates to:
  /// **'シリーズ物で毎話使うロゴやクレジット表記は、共通レイヤー化してフォルダにまとめておくと、新しい話数のプロジェクトへコピーする際も迷わず扱えます。'**
  String get tipsCommonLayerFolderDesc;

  /// No description provided for @tipsStrokeDecayFadeTitle.
  ///
  /// In ja, this message translates to:
  /// **'ストローク減衰×フェードで毛筆表現'**
  String get tipsStrokeDecayFadeTitle;

  /// No description provided for @tipsStrokeDecayFadeDesc.
  ///
  /// In ja, this message translates to:
  /// **'ブラシ設定のストローク減衰とフェードを両方かけると、線の描き始め・終わりが自然に細くなり、毛筆やインクブラシのような抑揚のある線が描けます。'**
  String get tipsStrokeDecayFadeDesc;

  /// No description provided for @tipsColorMixingFadeTitle.
  ///
  /// In ja, this message translates to:
  /// **'混色×フェードで絵の具のような混ざり'**
  String get tipsColorMixingFadeTitle;

  /// No description provided for @tipsColorMixingFadeDesc.
  ///
  /// In ja, this message translates to:
  /// **'混色を有効にしたブラシへフェードも組み合わせると、下の色と混ざりながら徐々に薄くなる、実際の絵の具に近い塗り心地になります。'**
  String get tipsColorMixingFadeDesc;

  /// No description provided for @tipsOutlineAnimeStyleTitle.
  ///
  /// In ja, this message translates to:
  /// **'縁取り×アニメ調でセルアニメ風の仕上げ'**
  String get tipsOutlineAnimeStyleTitle;

  /// No description provided for @tipsOutlineAnimeStyleDesc.
  ///
  /// In ja, this message translates to:
  /// **'描画フィルターの縁取りで輪郭線を新規レイヤーへ描き出し、アニメ調フィルターで色数を落とすと、セルアニメのようなくっきりした仕上げになります。'**
  String get tipsOutlineAnimeStyleDesc;

  /// No description provided for @tipsLevelsToneCurveTitle.
  ///
  /// In ja, this message translates to:
  /// **'レベル補正×トーンカーブでグラフィック調に'**
  String get tipsLevelsToneCurveTitle;

  /// No description provided for @tipsLevelsToneCurveDesc.
  ///
  /// In ja, this message translates to:
  /// **'レベル補正で明暗差を強めに調整してからトーンカーブで階調を作り込むと、写真的な階調から離れた、ポスターのようなグラフィック調の演出ができます。'**
  String get tipsLevelsToneCurveDesc;

  /// No description provided for @tipsMosaicChromaticTitle.
  ///
  /// In ja, this message translates to:
  /// **'モザイク×色収差でブラウン管風の荒れた質感'**
  String get tipsMosaicChromaticTitle;

  /// No description provided for @tipsMosaicChromaticDesc.
  ///
  /// In ja, this message translates to:
  /// **'モザイクで解像度を落としてから色収差を重ねると、古いブラウン管テレビで見ているような荒れた質感を演出できます。ブラウン管フィルター単体とはひと味違う質感が作れます。'**
  String get tipsMosaicChromaticDesc;

  /// No description provided for @tipsEndCardWatermarkTitle.
  ///
  /// In ja, this message translates to:
  /// **'自分の署名はウォーターマーク、エンドカードは別物'**
  String get tipsEndCardWatermarkTitle;

  /// No description provided for @tipsEndCardWatermarkDesc.
  ///
  /// In ja, this message translates to:
  /// **'動画に自分の署名や透かしを入れたいときはウォーターマーク機能を使います。エンドカードは動画の最後に自動で表示されるアプリ側のロゴで、無料会員は変更できません。プレミアム会員なら非表示にしたり、自分の動画・画像に差し替えたりできます。エンドカードを使わず自分だけの締めくくりを作りたいときは、画像レイヤーの追加とフェードイン・アウトを組み合わせれば同じような演出を自作できます。'**
  String get tipsEndCardWatermarkDesc;

  /// No description provided for @tipsVerticalPixelFontTitle.
  ///
  /// In ja, this message translates to:
  /// **'実写動画×手描き作画で「実写×アニメ」を作る'**
  String get tipsVerticalPixelFontTitle;

  /// No description provided for @tipsVerticalPixelFontDesc.
  ///
  /// In ja, this message translates to:
  /// **'イラストアプリと動画編集アプリを兼ねているからこそできる遊び方です。実写の動画クリップをタイムラインに配置し、その上のレイヤーへオニオンスキンを使いながら手描きで効果線やキャラクターを描き足せば、実写に手描きアニメが重なった「実写×アニメ」のミックスメディア動画が作れます。'**
  String get tipsVerticalPixelFontDesc;

  /// No description provided for @tipsTimelineMarkerTitle.
  ///
  /// In ja, this message translates to:
  /// **'音や口パクのタイミング合わせにはタイムスタンプ'**
  String get tipsTimelineMarkerTitle;

  /// No description provided for @tipsTimelineMarkerDesc.
  ///
  /// In ja, this message translates to:
  /// **'シーンは「開始〜終了フレームの範囲」を扱う機能ですが、タイムスタンプは「その一瞬」にコメントを付けてワンタップで移動できる機能です。「120フレーム目で効果音」「180フレーム目は口パク『あ』」のように、同じシーンの範囲内に複数のタイムスタンプを打っておけば、音と映像のタイミング合わせが格段にやりやすくなります。'**
  String get tipsTimelineMarkerDesc;

  /// No description provided for @tipsCommunityYoutubeTitle.
  ///
  /// In ja, this message translates to:
  /// **'作品広場への投稿はYouTube経由です'**
  String get tipsCommunityYoutubeTitle;

  /// No description provided for @tipsCommunityYoutubeDesc.
  ///
  /// In ja, this message translates to:
  /// **'作品広場に投稿すると、YouTubeを通じて作品が公開されます。NIARIMは動画ファイル本体を開発者のサーバーへ送信・収集・保存する機能を持っていません。YouTube側の公開設定を「限定公開」にすれば、YouTube上の一般公開一覧には表示されず、作品広場内だけに投稿された状態にできます。'**
  String get tipsCommunityYoutubeDesc;

  /// No description provided for @tipsToolbarCustomizeTitle.
  ///
  /// In ja, this message translates to:
  /// **'ツールバーの並び替え・非表示で指の移動距離を減らす'**
  String get tipsToolbarCustomizeTitle;

  /// No description provided for @tipsToolbarCustomizeDesc.
  ///
  /// In ja, this message translates to:
  /// **'設定画面のツールバー編集から、使わないツールを非表示にし、よく使うツールを指の届きやすい位置へ並び替えられます。表示項目を絞ってすっきりさせるだけで、ツールを探す時間や指の移動距離が減り、作画のテンポが上がります。'**
  String get tipsToolbarCustomizeDesc;

  /// No description provided for @tipsAutofillBlendModeTitle.
  ///
  /// In ja, this message translates to:
  /// **'自動塗りパーツのブレンドモードで陰影の質感を変える'**
  String get tipsAutofillBlendModeTitle;

  /// No description provided for @tipsAutofillBlendModeDesc.
  ///
  /// In ja, this message translates to:
  /// **'自動塗り設定の各パーツにはブレンドモードを設定できます。陰影パーツを「乗算」ではなく「オーバーレイ」や「ソフトライト」にすると、光が透けるような柔らかい陰影になります。同じ色でも質感を変えられる、隠れた自由度の高さです。'**
  String get tipsAutofillBlendModeDesc;

  /// No description provided for @tipsStampBlendModeTitle.
  ///
  /// In ja, this message translates to:
  /// **'スタンプ×ブレンドモードで光のエフェクト'**
  String get tipsStampBlendModeTitle;

  /// No description provided for @tipsStampBlendModeDesc.
  ///
  /// In ja, this message translates to:
  /// **'配置したスタンプのレイヤーをブレンドモード「スクリーン」や「加算」にすると、光の効果線やキラキラしたエフェクトが背景に自然に馴染んで映えます。'**
  String get tipsStampBlendModeDesc;

  /// No description provided for @tipsQuickToolPenSubTitle.
  ///
  /// In ja, this message translates to:
  /// **'早替えツール×ペンサブツールで手を止めない作業導線'**
  String get tipsQuickToolPenSubTitle;

  /// No description provided for @tipsQuickToolPenSubDesc.
  ///
  /// In ja, this message translates to:
  /// **'よく使うツールを早替えツールに登録しつつ、ペンの長押しでトーン貼り・スタンプへ切り替えられるペンサブツールも活用すると、画面を行き来する回数を減らして作業のテンポを保てます。'**
  String get tipsQuickToolPenSubDesc;

  /// No description provided for @tipsAutofillToneReuseTitle.
  ///
  /// In ja, this message translates to:
  /// **'自動塗りのトーン設定で線画差し替えだけで塗りを再現'**
  String get tipsAutofillToneReuseTitle;

  /// No description provided for @tipsAutofillToneReuseDesc.
  ///
  /// In ja, this message translates to:
  /// **'自動塗り設定の各パーツを「トーンを使う」設定にしておくと、線画を描き直すたびにトーン込みの塗りを自動で再現できます。フレームごとにトーンを貼り直す手間を省けます。'**
  String get tipsAutofillToneReuseDesc;

  /// No description provided for @tipsAutofillMisfillTitle.
  ///
  /// In ja, this message translates to:
  /// **'自動塗りの仕組みを知ると塗りミスを減らせる'**
  String get tipsAutofillMisfillTitle;

  /// No description provided for @tipsAutofillMisfillDesc.
  ///
  /// In ja, this message translates to:
  /// **'自動塗りは生成AIを使った機能ではなく、レイヤーごとのバケツ塗りを応用したものです。そのため、長い髪のように同じパーツの中で線に囲まれた隙間ができていると、そこも一緒に塗りつぶされます。対策として、まずはパーツごとに彩度の高い目立つ色を割り当てて一度塗ってしまうのがおすすめです。塗り間違いがひと目で分かるので自動塗りレイヤーを手動で直しやすく、直したうえで本来の色に設定し直して上書きする形で自動塗りを再実行すれば、塗りミスをぐっと減らせます。'**
  String get tipsAutofillMisfillDesc;

  /// No description provided for @tipsAutofillTransparentFixTitle.
  ///
  /// In ja, this message translates to:
  /// **'自動塗りのはみ出しは透明色のバケツ塗りで消す'**
  String get tipsAutofillTransparentFixTitle;

  /// No description provided for @tipsAutofillTransparentFixDesc.
  ///
  /// In ja, this message translates to:
  /// **'自動塗りで本来塗られたくないところまで塗られてしまったときは、消しゴムでなぞるより、描画色に透明色を指定したうえでその範囲をバケツ塗りするのが簡単です。バケツ塗りは線で囲まれた領域をまとめて処理するので、はみ出した部分だけを一度のタップできれいに消せます。'**
  String get tipsAutofillTransparentFixDesc;

  /// No description provided for @tipsRadialVignetteTitle.
  ///
  /// In ja, this message translates to:
  /// **'放射定規×周辺減光で集中線演出'**
  String get tipsRadialVignetteTitle;

  /// No description provided for @tipsRadialVignetteDesc.
  ///
  /// In ja, this message translates to:
  /// **'放射定規で集中線を一気に描き、描画フィルターの周辺減光を重ねると、漫画のクライマックスのような迫力ある演出になります。'**
  String get tipsRadialVignetteDesc;

  /// No description provided for @tipsClippingGradientTitle.
  ///
  /// In ja, this message translates to:
  /// **'クリッピング×グラデーションで陰影を描き直し可能に'**
  String get tipsClippingGradientTitle;

  /// No description provided for @tipsClippingGradientDesc.
  ///
  /// In ja, this message translates to:
  /// **'グラデーションレイヤーをキャラクターレイヤーへクリッピングしておくと、陰影の形をブラシで描き込まなくても、グラデーションの範囲・角度の変更だけで陰影を調整し直せます。'**
  String get tipsClippingGradientDesc;

  /// No description provided for @tipsToneCurveSepiaTitle.
  ///
  /// In ja, this message translates to:
  /// **'トーンカーブ×セピアでレトロ写真風'**
  String get tipsToneCurveSepiaTitle;

  /// No description provided for @tipsToneCurveSepiaDesc.
  ///
  /// In ja, this message translates to:
  /// **'演出フィルターのトーンカーブで明暗のコントラストを整えてからセピアを重ねると、色あせた古い写真のような質感を演出できます。'**
  String get tipsToneCurveSepiaDesc;

  /// No description provided for @tipsCameraLensBlurTitle.
  ///
  /// In ja, this message translates to:
  /// **'カメラキーフレーム×レンズぼかしでズームブラー演出'**
  String get tipsCameraLensBlurTitle;

  /// No description provided for @tipsCameraLensBlurDesc.
  ///
  /// In ja, this message translates to:
  /// **'カメラキーフレームでズームする瞬間に合わせてレンズぼかしの演出フィルターを一時的に強めに設定すると、実写のズームブラーのような迫力を演出できます。'**
  String get tipsCameraLensBlurDesc;

  /// No description provided for @tipsBlurVignetteBgTitle.
  ///
  /// In ja, this message translates to:
  /// **'ガウスぼかし×周辺減光で柔らかい背景ボケ'**
  String get tipsBlurVignetteBgTitle;

  /// No description provided for @tipsBlurVignetteBgDesc.
  ///
  /// In ja, this message translates to:
  /// **'背景レイヤーだけにガウスぼかしと周辺減光の描画フィルターを重ねてかけると、主役のキャラクターが自然と目立つ、被写界深度のあるカメラ風の仕上がりになります。'**
  String get tipsBlurVignetteBgDesc;

  /// No description provided for @tipsSepiaVignetteTitle.
  ///
  /// In ja, this message translates to:
  /// **'セピア×周辺減光でアンティーク写真風の動画に'**
  String get tipsSepiaVignetteTitle;

  /// No description provided for @tipsSepiaVignetteDesc.
  ///
  /// In ja, this message translates to:
  /// **'演出フィルターのセピアと描画フィルターの周辺減光を組み合わせると、四隅が暗く色あせたアンティーク写真のような雰囲気の動画に仕上げられます。'**
  String get tipsSepiaVignetteDesc;

  /// No description provided for @tipsVideoTrimReuseTitle.
  ///
  /// In ja, this message translates to:
  /// **'動画クリップの使用範囲を変えて同じ素材を使い回す'**
  String get tipsVideoTrimReuseTitle;

  /// No description provided for @tipsVideoTrimReuseDesc.
  ///
  /// In ja, this message translates to:
  /// **'同じ動画素材でも、クリップごとに使用開始・終了フレームを変えて配置すれば、別のカットとして使い回せます。素材を増やさずにバリエーションを作れます。'**
  String get tipsVideoTrimReuseDesc;

  /// No description provided for @tipsSaveSlotAutoSaveTitle.
  ///
  /// In ja, this message translates to:
  /// **'セーブスロット×自動保存を使い分ける'**
  String get tipsSaveSlotAutoSaveTitle;

  /// No description provided for @tipsSaveSlotAutoSaveDesc.
  ///
  /// In ja, this message translates to:
  /// **'自動保存は常に最新状態を上書きしますが、セーブスロットは複数の状態を残しておけます。大きな節目でセーブスロットに保存し、それ以外の細かい変更は自動保存に任せると、必要な時点へ確実に戻れます。'**
  String get tipsSaveSlotAutoSaveDesc;

  /// No description provided for @tipsQuickToolSwipeTitle.
  ///
  /// In ja, this message translates to:
  /// **'早替えツールは上スワイプで並び替えできる'**
  String get tipsQuickToolSwipeTitle;

  /// No description provided for @tipsQuickToolSwipeDesc.
  ///
  /// In ja, this message translates to:
  /// **'早替えツールの登録内容を変えたいときは、長押しだけでなく上スワイプでも管理ポップアップを開けます。片手で操作しているときに素早く並び替えたい場合に便利です。'**
  String get tipsQuickToolSwipeDesc;

  /// No description provided for @tipsDrawingAreaCameraTitle.
  ///
  /// In ja, this message translates to:
  /// **'描画領域を広めに×カメラキーフレームで安全にパン・ズーム'**
  String get tipsDrawingAreaCameraTitle;

  /// No description provided for @tipsDrawingAreaCameraDesc.
  ///
  /// In ja, this message translates to:
  /// **'描画領域を書き出し範囲より広めに設定しておくと、カメラキーフレームでパン・ズームしても画面の端が切れる心配がありません。動きの大きい演出を入れる前に確認しておくと安心です。'**
  String get tipsDrawingAreaCameraDesc;

  /// No description provided for @tipsWebmCommonLayerTitle.
  ///
  /// In ja, this message translates to:
  /// **'透過WebM×背景を共通レイヤーで分離管理'**
  String get tipsWebmCommonLayerTitle;

  /// No description provided for @tipsWebmCommonLayerDesc.
  ///
  /// In ja, this message translates to:
  /// **'透過WebMとして書き出したキャラクターを別の動画編集ソフトで背景と合成する場合、背景を共通レイヤーで別管理しておくと、透過部分に不要な色が混ざらずきれいに抜けます。'**
  String get tipsWebmCommonLayerDesc;

  /// No description provided for @tipsLeftHandedWorkspaceTitle.
  ///
  /// In ja, this message translates to:
  /// **'左利きモード×ワークスペース設定で作業しやすく'**
  String get tipsLeftHandedWorkspaceTitle;

  /// No description provided for @tipsLeftHandedWorkspaceDesc.
  ///
  /// In ja, this message translates to:
  /// **'左利きの場合、ワークスペース設定の左利きモードをONにするとドッキングパネルが左右反転し、利き手側の画面がパネルで隠れにくくなります。'**
  String get tipsLeftHandedWorkspaceDesc;

  /// No description provided for @tipsTransferDeviceTitle.
  ///
  /// In ja, this message translates to:
  /// **'引き継ぎファイルで別端末へ環境を移す'**
  String get tipsTransferDeviceTitle;

  /// No description provided for @tipsTransferDeviceDesc.
  ///
  /// In ja, this message translates to:
  /// **'使う端末を変えても同じ環境で描き続けたいときは、引き継ぎ（.niatra）機能を使うと、設定・ブラシ・トーン・スタンプ・パレットなどの環境をまとめて移動できます。制作中のプロジェクトそのものを渡したい場合は「共有（.niashare）」を使います。'**
  String get tipsTransferDeviceDesc;

  /// No description provided for @fontSettingsTabDownloaded.
  ///
  /// In ja, this message translates to:
  /// **'ダウンロード済み'**
  String get fontSettingsTabDownloaded;

  /// No description provided for @fontSettingsTabSearch.
  ///
  /// In ja, this message translates to:
  /// **'探してDL'**
  String get fontSettingsTabSearch;

  /// No description provided for @fontSettingsTabImport.
  ///
  /// In ja, this message translates to:
  /// **'読み込み'**
  String get fontSettingsTabImport;

  /// No description provided for @fontDownloadedSearchHint.
  ///
  /// In ja, this message translates to:
  /// **'フォント名で検索...'**
  String get fontDownloadedSearchHint;

  /// No description provided for @fontPixelModeTooltip.
  ///
  /// In ja, this message translates to:
  /// **'ピクセルモード（ドットフォント用。アンチエイリアスなしでくっきり表示）'**
  String get fontPixelModeTooltip;

  /// No description provided for @fontEmptyTitle.
  ///
  /// In ja, this message translates to:
  /// **'フォントがありません'**
  String get fontEmptyTitle;

  /// No description provided for @fontEmptyHint.
  ///
  /// In ja, this message translates to:
  /// **'「探してDL」または「読み込み」タブから追加できます'**
  String get fontEmptyHint;

  /// No description provided for @fontRenameDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'フォント名を変更'**
  String get fontRenameDialogTitle;

  /// No description provided for @fontImportTitle.
  ///
  /// In ja, this message translates to:
  /// **'端末に保存済みのフォントを読み込む'**
  String get fontImportTitle;

  /// No description provided for @fontImportFormats.
  ///
  /// In ja, this message translates to:
  /// **'対応形式：TTF / OTF'**
  String get fontImportFormats;

  /// No description provided for @fontSelectFileButton.
  ///
  /// In ja, this message translates to:
  /// **'ファイルを選択'**
  String get fontSelectFileButton;

  /// No description provided for @fontUnsupportedSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'このフォントは読み込めません。'**
  String get fontUnsupportedSnackbar;

  /// No description provided for @fontAddedSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'「{name}」を追加しました（ダウンロード済みタブに表示されます）'**
  String fontAddedSnackbar(String name);

  /// No description provided for @fontCorruptedSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'フォントが破損しています。'**
  String get fontCorruptedSnackbar;

  /// No description provided for @licenseScreenTitle.
  ///
  /// In ja, this message translates to:
  /// **'利用規約・ライセンス'**
  String get licenseScreenTitle;

  /// No description provided for @licenseSectionTerms.
  ///
  /// In ja, this message translates to:
  /// **'利用規約'**
  String get licenseSectionTerms;

  /// No description provided for @licenseSectionFonts.
  ///
  /// In ja, this message translates to:
  /// **'使用フォントについて'**
  String get licenseSectionFonts;

  /// No description provided for @licenseSectionOss.
  ///
  /// In ja, this message translates to:
  /// **'オープンソースソフトウェアライセンス'**
  String get licenseSectionOss;

  /// No description provided for @licenseOssListTitle.
  ///
  /// In ja, this message translates to:
  /// **'使用ライブラリのライセンス一覧'**
  String get licenseOssListTitle;

  /// No description provided for @licenseOssListSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'本アプリが使用するOSSパッケージのライセンスを表示します'**
  String get licenseOssListSubtitle;

  /// No description provided for @licenseFfmpegNote.
  ///
  /// In ja, this message translates to:
  /// **'WebM・AVI書き出しにはFFmpeg（LGPL 3.0、ffmpeg_kit_flutter_new_video経由）を使用しています。改変版ソースコードの入手先：https://github.com/sk3llo/ffmpeg_kit_flutter\nMP4書き出しは端末内蔵のハードウェアエンコーダーを直接利用しており、FFmpegは使用していません。'**
  String get licenseFfmpegNote;

  /// No description provided for @licenseFontCreditMeta.
  ///
  /// In ja, this message translates to:
  /// **'作者：{author}　ライセンス：{license}'**
  String licenseFontCreditMeta(String author, String license);

  /// No description provided for @toolbarPenTooltip.
  ///
  /// In ja, this message translates to:
  /// **'ペン（長押しでサブツール）'**
  String get toolbarPenTooltip;

  /// No description provided for @toolbarPenFirstUseTip.
  ///
  /// In ja, this message translates to:
  /// **'ペンを長押しすると、ブラシ・トーン・スタンプ・投げ縄塗りを切り替えられます。'**
  String get toolbarPenFirstUseTip;

  /// No description provided for @toolbarBucketTooltip.
  ///
  /// In ja, this message translates to:
  /// **'バケツ（長押しでベタ/トーン切替）'**
  String get toolbarBucketTooltip;

  /// No description provided for @toolbarBucketFirstUseTip.
  ///
  /// In ja, this message translates to:
  /// **'バケツを長押しすると、ベタ塗りとトーン塗りを切り替えられます。'**
  String get toolbarBucketFirstUseTip;

  /// No description provided for @toolbarSelectTooltip.
  ///
  /// In ja, this message translates to:
  /// **'選択（長押しで種別変更）'**
  String get toolbarSelectTooltip;

  /// No description provided for @toolbarShapeTooltip.
  ///
  /// In ja, this message translates to:
  /// **'図形（タップで種別選択）'**
  String get toolbarShapeTooltip;

  /// No description provided for @toolbarTextFirstUseTip.
  ///
  /// In ja, this message translates to:
  /// **'文字を自由に配置できます。フォントや色、アウトラインも変更できます。'**
  String get toolbarTextFirstUseTip;

  /// No description provided for @toolbarQuickToolFirstUseTip.
  ///
  /// In ja, this message translates to:
  /// **'タップで登録したツールを順番に切り替えられます。長押しまたは上にスワイプで登録内容を編集できます。'**
  String get toolbarQuickToolFirstUseTip;

  /// Heading of the shared operation guide shown in every first-use tutorial card
  ///
  /// In ja, this message translates to:
  /// **'基本の操作'**
  String get firstUseTipOperationGuideTitle;

  /// Shared operation guide shown in every first-use tutorial card
  ///
  /// In ja, this message translates to:
  /// **'ツールバーのアイコンは、シングルタップでそのツールに切り替わります。同じアイコンを長押し、または上にスワイプすると、そのツールの詳細設定（ブラシの種類・塗り方・選択方法など）が開きます。アイコンをダブルタップすると、そのツールの短い説明が出ます。ここで閉じたあとも、各画面右上の「？」ボタンからヘルプで読み直せます。'**
  String get firstUseTipOperationGuideBody;

  /// Help entry title for basic tap / long-press / swipe controls
  ///
  /// In ja, this message translates to:
  /// **'基本の操作（タップ・長押し・スワイプ）'**
  String get helpBasicGestureTitle;

  /// Help entry body describing tap, long-press, swipe and canvas gestures
  ///
  /// In ja, this message translates to:
  /// **'ツールバーのアイコンはシングルタップでそのツールに切り替わります。同じアイコンを長押し、または上にスワイプすると詳細設定が開きます。ペンならブラシ・トーン・スタンプ・投げ縄塗りの切り替え、バケツならベタ塗りとトーン塗りの切り替え、選択ツールなら矩形・投げ縄・自動選択の切り替え、指ツールならぼかしとモザイクの切り替え、早替えツールなら登録内容の編集が、それぞれ長押し・上スワイプの先にあります。アイコンのダブルタップでは、そのツールの短い説明が画面下に出ます。\\nキャンバスでは、2本指でつまむと拡大縮小、2本指でなぞると移動、2本指のタップで元に戻す、3本指のタップでやり直しです。画面の左右の端をダブルタップすると、前後のフレームへ移動します。\\nマウスやペンタブレットを繋いでいる場合は、ホイールで拡大縮小、中ボタンのドラッグで移動できます。'**
  String get helpBasicGestureDesc;

  /// No description provided for @toolbarStampColorLockedSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'スタンプは色情報を保持しているため色変更できません'**
  String get toolbarStampColorLockedSnackbar;

  /// No description provided for @toolbarBrushSettingsTooltip.
  ///
  /// In ja, this message translates to:
  /// **'ブラシ設定'**
  String get toolbarBrushSettingsTooltip;

  /// No description provided for @toolbarLayerTooltip.
  ///
  /// In ja, this message translates to:
  /// **'レイヤー'**
  String get toolbarLayerTooltip;

  /// No description provided for @toolbarQuickToolTooltip.
  ///
  /// In ja, this message translates to:
  /// **'ツール早替え（長押し/上スワイプで編集）'**
  String get toolbarQuickToolTooltip;

  /// No description provided for @toolbarSaveTooltip.
  ///
  /// In ja, this message translates to:
  /// **'保存（セーブツリー）'**
  String get toolbarSaveTooltip;

  /// No description provided for @toolbarBucketFlatFill.
  ///
  /// In ja, this message translates to:
  /// **'ベタ塗り'**
  String get toolbarBucketFlatFill;

  /// No description provided for @toolbarBucketToneListLabel.
  ///
  /// In ja, this message translates to:
  /// **'トーン一覧'**
  String get toolbarBucketToneListLabel;

  /// No description provided for @toolbarSelectRect.
  ///
  /// In ja, this message translates to:
  /// **'矩形選択'**
  String get toolbarSelectRect;

  /// No description provided for @toolbarSelectLasso.
  ///
  /// In ja, this message translates to:
  /// **'投げ縄選択'**
  String get toolbarSelectLasso;

  /// No description provided for @toolbarSelectMagicWand.
  ///
  /// In ja, this message translates to:
  /// **'自動選択（マジックワンド）'**
  String get toolbarSelectMagicWand;

  /// No description provided for @creativePanelFavoritesOnlyTooltip.
  ///
  /// In ja, this message translates to:
  /// **'お気に入りのみ表示'**
  String get creativePanelFavoritesOnlyTooltip;

  /// No description provided for @creativePanelSearchTooltip.
  ///
  /// In ja, this message translates to:
  /// **'名前で検索'**
  String get creativePanelSearchTooltip;

  /// No description provided for @creativePanelSearchModeKeyword.
  ///
  /// In ja, this message translates to:
  /// **'キーワード検索中（タップでタグ検索へ）'**
  String get creativePanelSearchModeKeyword;

  /// No description provided for @creativePanelSearchModeTag.
  ///
  /// In ja, this message translates to:
  /// **'タグ検索中（タップでキーワード検索へ）'**
  String get creativePanelSearchModeTag;

  /// No description provided for @creativePanelTagSearchHint.
  ///
  /// In ja, this message translates to:
  /// **'タグで検索'**
  String get creativePanelTagSearchHint;

  /// No description provided for @creativePanelTagNoneYet.
  ///
  /// In ja, this message translates to:
  /// **'まだタグがありません。編集画面から付けられます'**
  String get creativePanelTagNoneYet;

  /// No description provided for @creativePanelTagsLabel.
  ///
  /// In ja, this message translates to:
  /// **'タグ'**
  String get creativePanelTagsLabel;

  /// No description provided for @creativePanelTagsHint.
  ///
  /// In ja, this message translates to:
  /// **'カンマか空白で区切って入力'**
  String get creativePanelTagsHint;

  /// No description provided for @creativePanelTagClearFilter.
  ///
  /// In ja, this message translates to:
  /// **'タグの絞り込みを解除'**
  String get creativePanelTagClearFilter;

  /// No description provided for @widgetSettingsTitle.
  ///
  /// In ja, this message translates to:
  /// **'ホーム画面ウィジェット'**
  String get widgetSettingsTitle;

  /// No description provided for @widgetSettingsDescription.
  ///
  /// In ja, this message translates to:
  /// **'スマホのホーム画面へ、好きな作品のフレーム1枚・「作品をつくる」・「作品広場」の3種類のウィジェットを置けます。ウィジェットの追加自体はホーム画面の長押しから行ってください。'**
  String get widgetSettingsDescription;

  /// No description provided for @widgetSettingsSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'表示する作品・ウィジェットの色'**
  String get widgetSettingsSubtitle;

  /// No description provided for @widgetArtworkSection.
  ///
  /// In ja, this message translates to:
  /// **'表示する作品'**
  String get widgetArtworkSection;

  /// No description provided for @widgetArtworkPickButton.
  ///
  /// In ja, this message translates to:
  /// **'作品を選ぶ'**
  String get widgetArtworkPickButton;

  /// No description provided for @widgetSectionArtwork.
  ///
  /// In ja, this message translates to:
  /// **'起動画面ウィジェット'**
  String get widgetSectionArtwork;

  /// No description provided for @widgetSectionArtworkDesc.
  ///
  /// In ja, this message translates to:
  /// **'選んだ作品のフレーム1枚を表示します。タップするとNIARIMが起動します。'**
  String get widgetSectionArtworkDesc;

  /// No description provided for @widgetSectionCreate.
  ///
  /// In ja, this message translates to:
  /// **'作品をつくるウィジェット'**
  String get widgetSectionCreate;

  /// No description provided for @widgetSectionCreateDesc.
  ///
  /// In ja, this message translates to:
  /// **'タップすると「作品をつくる」画面が開きます。'**
  String get widgetSectionCreateDesc;

  /// No description provided for @widgetSectionPlaza.
  ///
  /// In ja, this message translates to:
  /// **'作品広場ウィジェット'**
  String get widgetSectionPlaza;

  /// No description provided for @widgetSectionPlazaDesc.
  ///
  /// In ja, this message translates to:
  /// **'タップすると「作品広場」が開きます。'**
  String get widgetSectionPlazaDesc;

  /// No description provided for @widgetArtworkNone.
  ///
  /// In ja, this message translates to:
  /// **'作品を選んでいません'**
  String get widgetArtworkNone;

  /// No description provided for @widgetArtworkFrameNumberLabel.
  ///
  /// In ja, this message translates to:
  /// **'{n}枚目のフレーム'**
  String widgetArtworkFrameNumberLabel(int n);

  /// No description provided for @widgetArtworkFramePickerHint.
  ///
  /// In ja, this message translates to:
  /// **'表示したいフレームをタップして選んでください。'**
  String get widgetArtworkFramePickerHint;

  /// No description provided for @widgetArtworkNoFrames.
  ///
  /// In ja, this message translates to:
  /// **'このシーンにはまだフレームがありません。'**
  String get widgetArtworkNoFrames;

  /// No description provided for @widgetColorFollowTheme.
  ///
  /// In ja, this message translates to:
  /// **'アプリのテーマに合わせる'**
  String get widgetColorFollowTheme;

  /// No description provided for @widgetColorCustom.
  ///
  /// In ja, this message translates to:
  /// **'色を選ぶ'**
  String get widgetColorCustom;

  /// No description provided for @widgetNoProjects.
  ///
  /// In ja, this message translates to:
  /// **'まだ作品がありません。作品を作るとここで選べるようになります。'**
  String get widgetNoProjects;

  /// No description provided for @widgetSettingsNote.
  ///
  /// In ja, this message translates to:
  /// **'ホーム画面ウィジェットは動画を再生できないため、選んだ作品の1コマを静止画として表示します。'**
  String get widgetSettingsNote;

  /// No description provided for @assetTagLineArt.
  ///
  /// In ja, this message translates to:
  /// **'線画'**
  String get assetTagLineArt;

  /// No description provided for @assetTagBasic.
  ///
  /// In ja, this message translates to:
  /// **'基本'**
  String get assetTagBasic;

  /// No description provided for @assetTagMainLine.
  ///
  /// In ja, this message translates to:
  /// **'主線'**
  String get assetTagMainLine;

  /// No description provided for @assetTagPaint.
  ///
  /// In ja, this message translates to:
  /// **'塗り'**
  String get assetTagPaint;

  /// No description provided for @assetTagBlur.
  ///
  /// In ja, this message translates to:
  /// **'ぼかし'**
  String get assetTagBlur;

  /// No description provided for @assetTagMixing.
  ///
  /// In ja, this message translates to:
  /// **'混色'**
  String get assetTagMixing;

  /// No description provided for @assetTagAnalog.
  ///
  /// In ja, this message translates to:
  /// **'アナログ風'**
  String get assetTagAnalog;

  /// No description provided for @assetTagDecoration.
  ///
  /// In ja, this message translates to:
  /// **'装飾'**
  String get assetTagDecoration;

  /// No description provided for @assetTagRough.
  ///
  /// In ja, this message translates to:
  /// **'ラフ'**
  String get assetTagRough;

  /// No description provided for @assetTagEffect.
  ///
  /// In ja, this message translates to:
  /// **'効果'**
  String get assetTagEffect;

  /// No description provided for @assetTagTaper.
  ///
  /// In ja, this message translates to:
  /// **'入り抜き'**
  String get assetTagTaper;

  /// No description provided for @assetTagPixelArt.
  ///
  /// In ja, this message translates to:
  /// **'ドット絵'**
  String get assetTagPixelArt;

  /// No description provided for @assetTagHalftone.
  ///
  /// In ja, this message translates to:
  /// **'網点'**
  String get assetTagHalftone;

  /// No description provided for @assetTagShadow.
  ///
  /// In ja, this message translates to:
  /// **'影'**
  String get assetTagShadow;

  /// No description provided for @assetTagLine.
  ///
  /// In ja, this message translates to:
  /// **'線'**
  String get assetTagLine;

  /// No description provided for @assetTagGradient.
  ///
  /// In ja, this message translates to:
  /// **'グラデ'**
  String get assetTagGradient;

  /// No description provided for @assetTagTexture.
  ///
  /// In ja, this message translates to:
  /// **'質感'**
  String get assetTagTexture;

  /// No description provided for @assetTagClothing.
  ///
  /// In ja, this message translates to:
  /// **'服'**
  String get assetTagClothing;

  /// No description provided for @assetTagMesh.
  ///
  /// In ja, this message translates to:
  /// **'網目'**
  String get assetTagMesh;

  /// No description provided for @assetTagBackground.
  ///
  /// In ja, this message translates to:
  /// **'背景'**
  String get assetTagBackground;

  /// No description provided for @assetTagPattern.
  ///
  /// In ja, this message translates to:
  /// **'模様'**
  String get assetTagPattern;

  /// No description provided for @assetTagShape.
  ///
  /// In ja, this message translates to:
  /// **'図形'**
  String get assetTagShape;

  /// No description provided for @assetTagSymbol.
  ///
  /// In ja, this message translates to:
  /// **'記号'**
  String get assetTagSymbol;

  /// No description provided for @assetTagManga.
  ///
  /// In ja, this message translates to:
  /// **'マンガ'**
  String get assetTagManga;

  /// No description provided for @creativePanelFolderButton.
  ///
  /// In ja, this message translates to:
  /// **'フォルダ'**
  String get creativePanelFolderButton;

  /// No description provided for @creativePanelCreateButton.
  ///
  /// In ja, this message translates to:
  /// **'自作'**
  String get creativePanelCreateButton;

  /// No description provided for @creativePanelImportButton.
  ///
  /// In ja, this message translates to:
  /// **'読込'**
  String get creativePanelImportButton;

  /// No description provided for @creativePanelFolderAllChip.
  ///
  /// In ja, this message translates to:
  /// **'全て'**
  String get creativePanelFolderAllChip;

  /// No description provided for @creativePanelEditAction.
  ///
  /// In ja, this message translates to:
  /// **'編集'**
  String get creativePanelEditAction;

  /// No description provided for @toneTitle.
  ///
  /// In ja, this message translates to:
  /// **'トーン'**
  String get toneTitle;

  /// No description provided for @toneEmpty.
  ///
  /// In ja, this message translates to:
  /// **'トーンがありません'**
  String get toneEmpty;

  /// No description provided for @toneSearchHint.
  ///
  /// In ja, this message translates to:
  /// **'トーン名で検索'**
  String get toneSearchHint;

  /// No description provided for @toneEditTitle.
  ///
  /// In ja, this message translates to:
  /// **'トーンを編集'**
  String get toneEditTitle;

  /// No description provided for @toneChangeTextureButton.
  ///
  /// In ja, this message translates to:
  /// **'テクスチャ画像を変更'**
  String get toneChangeTextureButton;

  /// No description provided for @toneCreateDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'自作トーン'**
  String get toneCreateDialogTitle;

  /// No description provided for @toneImportFailedSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'トーンの読み込みに失敗しました: {error}'**
  String toneImportFailedSnackbar(String error);

  /// No description provided for @toneExportFailedSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'トーンの書き出しに失敗しました: {error}'**
  String toneExportFailedSnackbar(String error);

  /// No description provided for @privacyPolicyScreenTitle.
  ///
  /// In ja, this message translates to:
  /// **'プライバシーポリシー'**
  String get privacyPolicyScreenTitle;

  /// No description provided for @stampTitle.
  ///
  /// In ja, this message translates to:
  /// **'スタンプ'**
  String get stampTitle;

  /// No description provided for @stampSearchHint.
  ///
  /// In ja, this message translates to:
  /// **'スタンプ名で検索'**
  String get stampSearchHint;

  /// No description provided for @stampEmpty.
  ///
  /// In ja, this message translates to:
  /// **'スタンプがありません'**
  String get stampEmpty;

  /// No description provided for @stampCreateDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'自作スタンプ'**
  String get stampCreateDialogTitle;

  /// No description provided for @stampImportFailedSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'スタンプの読み込みに失敗しました: {error}'**
  String stampImportFailedSnackbar(String error);

  /// No description provided for @stampExportFailedSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'スタンプの書き出しに失敗しました: {error}'**
  String stampExportFailedSnackbar(String error);

  /// No description provided for @stampEditTitle.
  ///
  /// In ja, this message translates to:
  /// **'スタンプを編集'**
  String get stampEditTitle;

  /// No description provided for @stampRotationLabel.
  ///
  /// In ja, this message translates to:
  /// **'回転'**
  String get stampRotationLabel;

  /// No description provided for @stampPixelModeLabel.
  ///
  /// In ja, this message translates to:
  /// **'ピクセルモード'**
  String get stampPixelModeLabel;

  /// No description provided for @stampPixelModeHint.
  ///
  /// In ja, this message translates to:
  /// **'ドット絵風（モザイク＋色数削減）に加工して描画します'**
  String get stampPixelModeHint;

  /// No description provided for @stampDensityLabel.
  ///
  /// In ja, this message translates to:
  /// **'密度'**
  String get stampDensityLabel;

  /// No description provided for @stampScatterLabel.
  ///
  /// In ja, this message translates to:
  /// **'散布'**
  String get stampScatterLabel;

  /// No description provided for @stampChangeImageButton.
  ///
  /// In ja, this message translates to:
  /// **'スタンプ画像を変更'**
  String get stampChangeImageButton;

  /// No description provided for @themeSettingsTitle.
  ///
  /// In ja, this message translates to:
  /// **'テーマ・外観'**
  String get themeSettingsTitle;

  /// No description provided for @themeColorCustomizeSection.
  ///
  /// In ja, this message translates to:
  /// **'カラーカスタマイズ'**
  String get themeColorCustomizeSection;

  /// No description provided for @themeColorAccent.
  ///
  /// In ja, this message translates to:
  /// **'アクセントカラー'**
  String get themeColorAccent;

  /// No description provided for @themeColorText.
  ///
  /// In ja, this message translates to:
  /// **'文字色'**
  String get themeColorText;

  /// No description provided for @themeColorPanelBg.
  ///
  /// In ja, this message translates to:
  /// **'パネル背景色'**
  String get themeColorPanelBg;

  /// No description provided for @themeColorMenuBg.
  ///
  /// In ja, this message translates to:
  /// **'メニュー背景色'**
  String get themeColorMenuBg;

  /// No description provided for @themeColorSelection.
  ///
  /// In ja, this message translates to:
  /// **'選択色'**
  String get themeColorSelection;

  /// No description provided for @themeColorUpdateMark.
  ///
  /// In ja, this message translates to:
  /// **'更新マーク色'**
  String get themeColorUpdateMark;

  /// No description provided for @themePresetSection.
  ///
  /// In ja, this message translates to:
  /// **'テーマ一覧'**
  String get themePresetSection;

  /// No description provided for @themePresetDuplicateName.
  ///
  /// In ja, this message translates to:
  /// **'{name} (コピー)'**
  String themePresetDuplicateName(String name);

  /// No description provided for @themeDuplicateAction.
  ///
  /// In ja, this message translates to:
  /// **'複製'**
  String get themeDuplicateAction;

  /// No description provided for @themeExportMenuItem.
  ///
  /// In ja, this message translates to:
  /// **'書き出し (.niatheme)'**
  String get themeExportMenuItem;

  /// No description provided for @themeExportFailedSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'書き出しに失敗しました: {error}'**
  String themeExportFailedSnackbar(String error);

  /// No description provided for @themeImportSuccessSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'.niathemeを読み込みました'**
  String get themeImportSuccessSnackbar;

  /// No description provided for @themeImportFailedSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'読み込みに失敗しました: {error}'**
  String themeImportFailedSnackbar(String error);

  /// No description provided for @themeSaveAsNewButton.
  ///
  /// In ja, this message translates to:
  /// **'現在の設定を新しいテーマとして保存'**
  String get themeSaveAsNewButton;

  /// No description provided for @themeImportButton.
  ///
  /// In ja, this message translates to:
  /// **'.niathemeを読み込む'**
  String get themeImportButton;

  /// No description provided for @themePresetNameDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'テーマ名'**
  String get themePresetNameDialogTitle;

  /// No description provided for @themeDefaultPresetName.
  ///
  /// In ja, this message translates to:
  /// **'マイテーマ'**
  String get themeDefaultPresetName;

  /// No description provided for @onionSkinTitle.
  ///
  /// In ja, this message translates to:
  /// **'オニオンスキン'**
  String get onionSkinTitle;

  /// No description provided for @onionSkinPrevFrame.
  ///
  /// In ja, this message translates to:
  /// **'前フレーム'**
  String get onionSkinPrevFrame;

  /// No description provided for @onionSkinNextFrame.
  ///
  /// In ja, this message translates to:
  /// **'後フレーム'**
  String get onionSkinNextFrame;

  /// No description provided for @onionSkinFrameInterval.
  ///
  /// In ja, this message translates to:
  /// **'フレーム間隔'**
  String get onionSkinFrameInterval;

  /// No description provided for @onionSkinFadeByDistance.
  ///
  /// In ja, this message translates to:
  /// **'近いほど濃く表示'**
  String get onionSkinFadeByDistance;

  /// No description provided for @onionSkinColorPickerTitle.
  ///
  /// In ja, this message translates to:
  /// **'色を選択'**
  String get onionSkinColorPickerTitle;

  /// No description provided for @onionSkinOnFixed.
  ///
  /// In ja, this message translates to:
  /// **'ON（固定）'**
  String get onionSkinOnFixed;

  /// No description provided for @onionSkinFrameCount.
  ///
  /// In ja, this message translates to:
  /// **'表示枚数'**
  String get onionSkinFrameCount;

  /// No description provided for @onionSkinFrameCountFixed.
  ///
  /// In ja, this message translates to:
  /// **'{count}枚（固定）'**
  String onionSkinFrameCountFixed(int count);

  /// No description provided for @onionSkinColorLabel.
  ///
  /// In ja, this message translates to:
  /// **'色'**
  String get onionSkinColorLabel;

  /// No description provided for @onionSkinOpacityLabel.
  ///
  /// In ja, this message translates to:
  /// **'透明度'**
  String get onionSkinOpacityLabel;

  /// No description provided for @exportScreenTitle.
  ///
  /// In ja, this message translates to:
  /// **'書き出し'**
  String get exportScreenTitle;

  /// No description provided for @exportPresetSection.
  ///
  /// In ja, this message translates to:
  /// **'プリセット'**
  String get exportPresetSection;

  /// No description provided for @exportPresetStandard.
  ///
  /// In ja, this message translates to:
  /// **'標準'**
  String get exportPresetStandard;

  /// No description provided for @exportPresetHighQuality.
  ///
  /// In ja, this message translates to:
  /// **'高画質'**
  String get exportPresetHighQuality;

  /// No description provided for @exportPresetCustom.
  ///
  /// In ja, this message translates to:
  /// **'カスタム'**
  String get exportPresetCustom;

  /// No description provided for @exportAdvancedSettings.
  ///
  /// In ja, this message translates to:
  /// **'詳細設定'**
  String get exportAdvancedSettings;

  /// No description provided for @exportFpsLabel.
  ///
  /// In ja, this message translates to:
  /// **'FPS'**
  String get exportFpsLabel;

  /// No description provided for @exportFormatSection.
  ///
  /// In ja, this message translates to:
  /// **'形式'**
  String get exportFormatSection;

  /// No description provided for @exportFormatMp4.
  ///
  /// In ja, this message translates to:
  /// **'MP4'**
  String get exportFormatMp4;

  /// No description provided for @exportFormatMp4Subtitle.
  ///
  /// In ja, this message translates to:
  /// **'汎用動画形式'**
  String get exportFormatMp4Subtitle;

  /// No description provided for @exportFormatGif.
  ///
  /// In ja, this message translates to:
  /// **'GIF'**
  String get exportFormatGif;

  /// No description provided for @exportFormatGifSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'アニメーションGIF'**
  String get exportFormatGifSubtitle;

  /// No description provided for @exportFormatWebmSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'透明背景動画'**
  String get exportFormatWebmSubtitle;

  /// No description provided for @exportFormatAvi.
  ///
  /// In ja, this message translates to:
  /// **'AVI'**
  String get exportFormatAvi;

  /// No description provided for @exportFormatAviSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'互換性重視の動画形式（透過非対応）'**
  String get exportFormatAviSubtitle;

  /// No description provided for @exportStartButton.
  ///
  /// In ja, this message translates to:
  /// **'書き出し開始'**
  String get exportStartButton;

  /// No description provided for @exportProjectNotFoundError.
  ///
  /// In ja, this message translates to:
  /// **'プロジェクトが見つかりません'**
  String get exportProjectNotFoundError;

  /// No description provided for @exportFailedError.
  ///
  /// In ja, this message translates to:
  /// **'書き出し失敗: {error}'**
  String exportFailedError(String error);

  /// No description provided for @exportInProgressTitle.
  ///
  /// In ja, this message translates to:
  /// **'書き出し中'**
  String get exportInProgressTitle;

  /// No description provided for @exportCancelledSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'書き出しをキャンセルしました'**
  String get exportCancelledSnackbar;

  /// No description provided for @exportCancelHint.
  ///
  /// In ja, this message translates to:
  /// **'最終処理中のため、完了後にキャンセルを反映します'**
  String get exportCancelHint;

  /// No description provided for @exportOutdatedAutofillTitle.
  ///
  /// In ja, this message translates to:
  /// **'自動塗りが最新ではありません'**
  String get exportOutdatedAutofillTitle;

  /// No description provided for @exportOutdatedAutofillBody.
  ///
  /// In ja, this message translates to:
  /// **'更新されていない自動塗りレイヤーがあります。このまま書き出しますか？'**
  String get exportOutdatedAutofillBody;

  /// No description provided for @exportContinueButton.
  ///
  /// In ja, this message translates to:
  /// **'続行'**
  String get exportContinueButton;

  /// No description provided for @exportDurationExceededTitle.
  ///
  /// In ja, this message translates to:
  /// **'動画尺の上限を超えています'**
  String get exportDurationExceededTitle;

  /// No description provided for @exportDurationExceededBody.
  ///
  /// In ja, this message translates to:
  /// **'無料版の最大動画尺は{max}秒です。\n現在のプロジェクトは約{current}秒あります。\nプレミアムにアップグレードすると最大2時間まで作成できるようになります。'**
  String exportDurationExceededBody(int max, int current);

  /// No description provided for @exportViewPremiumButton.
  ///
  /// In ja, this message translates to:
  /// **'プレミアムを見る'**
  String get exportViewPremiumButton;

  /// No description provided for @exportContinueAnywayButton.
  ///
  /// In ja, this message translates to:
  /// **'このまま続行'**
  String get exportContinueAnywayButton;

  /// No description provided for @exportCompleteTitle.
  ///
  /// In ja, this message translates to:
  /// **'書き出し完了'**
  String get exportCompleteTitle;

  /// No description provided for @exportCompleteFramesBody.
  ///
  /// In ja, this message translates to:
  /// **'{count} フレームの書き出しが完了しました。'**
  String exportCompleteFramesBody(int count);

  /// No description provided for @exportSaveLocationLabel.
  ///
  /// In ja, this message translates to:
  /// **'保存先：アプリ内（{fileName}）'**
  String exportSaveLocationLabel(String fileName);

  /// No description provided for @exportSaveLocationHint.
  ///
  /// In ja, this message translates to:
  /// **'端末の「写真」アプリやファイルアプリで開くには、下の「共有」から保存先アプリを選んでください。'**
  String get exportSaveLocationHint;

  /// No description provided for @exportBackToProjectsButton.
  ///
  /// In ja, this message translates to:
  /// **'プロジェクト一覧へ戻る'**
  String get exportBackToProjectsButton;

  /// No description provided for @exportBackToCanvasButton.
  ///
  /// In ja, this message translates to:
  /// **'キャンバスへ戻る'**
  String get exportBackToCanvasButton;

  /// No description provided for @newProjectScreenTitle.
  ///
  /// In ja, this message translates to:
  /// **'新規プロジェクト'**
  String get newProjectScreenTitle;

  /// No description provided for @newProjectDefaultName.
  ///
  /// In ja, this message translates to:
  /// **'新規プロジェクト'**
  String get newProjectDefaultName;

  /// No description provided for @newProjectNameLabel.
  ///
  /// In ja, this message translates to:
  /// **'プロジェクト名'**
  String get newProjectNameLabel;

  /// No description provided for @newProjectSizeLabel.
  ///
  /// In ja, this message translates to:
  /// **'サイズ'**
  String get newProjectSizeLabel;

  /// No description provided for @newProjectPresetFullHd.
  ///
  /// In ja, this message translates to:
  /// **'Full HD (16:9・YouTube等横動画向け)'**
  String get newProjectPresetFullHd;

  /// No description provided for @newProjectPresetHd.
  ///
  /// In ja, this message translates to:
  /// **'HD (16:9・軽量版)'**
  String get newProjectPresetHd;

  /// No description provided for @newProjectPresetSquare.
  ///
  /// In ja, this message translates to:
  /// **'1:1 スクエア (Twitter/Instagram投稿向け)'**
  String get newProjectPresetSquare;

  /// No description provided for @newProjectPresetVertical.
  ///
  /// In ja, this message translates to:
  /// **'9:16 縦型 (YouTubeショート/リール・ストーリーズ向け)'**
  String get newProjectPresetVertical;

  /// No description provided for @newProjectPresetPortrait.
  ///
  /// In ja, this message translates to:
  /// **'4:5 縦長 (Instagramフィード投稿向け)'**
  String get newProjectPresetPortrait;

  /// No description provided for @newProjectPresetAnalog.
  ///
  /// In ja, this message translates to:
  /// **'4:3 (アナログ放送比率)'**
  String get newProjectPresetAnalog;

  /// No description provided for @newProjectCustomSize.
  ///
  /// In ja, this message translates to:
  /// **'カスタム'**
  String get newProjectCustomSize;

  /// No description provided for @newProjectMaxEdgeHint.
  ///
  /// In ja, this message translates to:
  /// **'長辺は最大1920pxまで指定できます'**
  String get newProjectMaxEdgeHint;

  /// No description provided for @newProjectWidthLabel.
  ///
  /// In ja, this message translates to:
  /// **'幅(px)'**
  String get newProjectWidthLabel;

  /// No description provided for @newProjectHeightLabel.
  ///
  /// In ja, this message translates to:
  /// **'高さ(px)'**
  String get newProjectHeightLabel;

  /// No description provided for @newProjectWidthShort.
  ///
  /// In ja, this message translates to:
  /// **'幅'**
  String get newProjectWidthShort;

  /// No description provided for @newProjectHeightShort.
  ///
  /// In ja, this message translates to:
  /// **'高さ'**
  String get newProjectHeightShort;

  /// No description provided for @newProjectSizePresetManageButton.
  ///
  /// In ja, this message translates to:
  /// **'サイズ設定'**
  String get newProjectSizePresetManageButton;

  /// No description provided for @newProjectSaveCustomSizeButton.
  ///
  /// In ja, this message translates to:
  /// **'このサイズを保存する'**
  String get newProjectSaveCustomSizeButton;

  /// No description provided for @newProjectSaveCustomSizeDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'サイズ名を入力'**
  String get newProjectSaveCustomSizeDialogTitle;

  /// No description provided for @newProjectSaveCustomSizeNameLabel.
  ///
  /// In ja, this message translates to:
  /// **'サイズ名'**
  String get newProjectSaveCustomSizeNameLabel;

  /// No description provided for @newProjectSaveCustomSizeSavedSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'サイズを保存しました'**
  String get newProjectSaveCustomSizeSavedSnackbar;

  /// No description provided for @canvasSizePresetManageScreenTitle.
  ///
  /// In ja, this message translates to:
  /// **'サイズ設定'**
  String get canvasSizePresetManageScreenTitle;

  /// No description provided for @canvasSizePresetEmpty.
  ///
  /// In ja, this message translates to:
  /// **'保存されたサイズはありません'**
  String get canvasSizePresetEmpty;

  /// No description provided for @canvasSizePresetEmptyHint.
  ///
  /// In ja, this message translates to:
  /// **'新規プロジェクト画面でカスタムサイズを指定し、「このサイズを保存する」から追加できます'**
  String get canvasSizePresetEmptyHint;

  /// No description provided for @canvasSizePresetEditDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'サイズを編集'**
  String get canvasSizePresetEditDialogTitle;

  /// No description provided for @canvasSizePresetDuplicateSuffix.
  ///
  /// In ja, this message translates to:
  /// **'のコピー'**
  String get canvasSizePresetDuplicateSuffix;

  /// No description provided for @newProjectDurationLabel.
  ///
  /// In ja, this message translates to:
  /// **'長さ（最大{max}）'**
  String newProjectDurationLabel(String max);

  /// No description provided for @newProjectDurationLabelWithPremiumHint.
  ///
  /// In ja, this message translates to:
  /// **'長さ（最大{max}・プレミアムなら最大2時間）'**
  String newProjectDurationLabelWithPremiumHint(String max);

  /// No description provided for @newProjectDurationSeconds.
  ///
  /// In ja, this message translates to:
  /// **'{n}秒'**
  String newProjectDurationSeconds(int n);

  /// No description provided for @newProjectDurationHms.
  ///
  /// In ja, this message translates to:
  /// **'{h}時間{m}分{s}秒'**
  String newProjectDurationHms(int h, int m, int s);

  /// No description provided for @newProjectDurationHm.
  ///
  /// In ja, this message translates to:
  /// **'{h}時間{m}分'**
  String newProjectDurationHm(int h, int m);

  /// No description provided for @newProjectDurationH.
  ///
  /// In ja, this message translates to:
  /// **'{h}時間'**
  String newProjectDurationH(int h);

  /// No description provided for @newProjectDurationMs.
  ///
  /// In ja, this message translates to:
  /// **'{m}分{s}秒'**
  String newProjectDurationMs(int m, int s);

  /// No description provided for @newProjectDurationM.
  ///
  /// In ja, this message translates to:
  /// **'{m}分'**
  String newProjectDurationM(int m);

  /// No description provided for @newProjectBackgroundColorLabel.
  ///
  /// In ja, this message translates to:
  /// **'背景色'**
  String get newProjectBackgroundColorLabel;

  /// No description provided for @newProjectDrawingAreaTitle.
  ///
  /// In ja, this message translates to:
  /// **'描画領域を広くする'**
  String get newProjectDrawingAreaTitle;

  /// No description provided for @newProjectDrawingAreaSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'書き出し範囲外にも描画できる領域を追加します'**
  String get newProjectDrawingAreaSubtitle;

  /// No description provided for @newProjectScaleLabel.
  ///
  /// In ja, this message translates to:
  /// **'倍率'**
  String get newProjectScaleLabel;

  /// No description provided for @newProjectScaleValue.
  ///
  /// In ja, this message translates to:
  /// **'{value}倍'**
  String newProjectScaleValue(String value);

  /// No description provided for @newProjectDrawableAreaInfo.
  ///
  /// In ja, this message translates to:
  /// **'描画可能範囲: {width}×{scale} = {result}'**
  String newProjectDrawableAreaInfo(String width, String scale, String result);

  /// No description provided for @newProjectTotalFrames.
  ///
  /// In ja, this message translates to:
  /// **'総フレーム数: {count}'**
  String newProjectTotalFrames(int count);

  /// No description provided for @newProjectExportSizeInfo.
  ///
  /// In ja, this message translates to:
  /// **'書き出しサイズ: {size}'**
  String newProjectExportSizeInfo(String size);

  /// No description provided for @newProjectDrawingAreaInfo.
  ///
  /// In ja, this message translates to:
  /// **'描画領域: {size}'**
  String newProjectDrawingAreaInfo(String size);

  /// No description provided for @colorPickerTitle.
  ///
  /// In ja, this message translates to:
  /// **'色選択'**
  String get colorPickerTitle;

  /// No description provided for @colorPickerOpacityLabel.
  ///
  /// In ja, this message translates to:
  /// **'不透明度'**
  String get colorPickerOpacityLabel;

  /// No description provided for @colorPickerHexCopiedSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'HEXをコピーしました'**
  String get colorPickerHexCopiedSnackbar;

  /// No description provided for @colorPickerRecentColorsLabel.
  ///
  /// In ja, this message translates to:
  /// **'最近使った色'**
  String get colorPickerRecentColorsLabel;

  /// No description provided for @colorPickerRecentColorsEmpty.
  ///
  /// In ja, this message translates to:
  /// **'まだありません'**
  String get colorPickerRecentColorsEmpty;

  /// No description provided for @colorPickerPaletteLabel.
  ///
  /// In ja, this message translates to:
  /// **'パレット'**
  String get colorPickerPaletteLabel;

  /// No description provided for @colorPickerNewPaletteTooltip.
  ///
  /// In ja, this message translates to:
  /// **'新しいパレット'**
  String get colorPickerNewPaletteTooltip;

  /// No description provided for @colorPickerManagePaletteTooltip.
  ///
  /// In ja, this message translates to:
  /// **'パレット管理'**
  String get colorPickerManagePaletteTooltip;

  /// No description provided for @colorPickerPaletteEmptyHint.
  ///
  /// In ja, this message translates to:
  /// **'色がまだありません。「＋」で現在の色を追加できます。'**
  String get colorPickerPaletteEmptyHint;

  /// No description provided for @colorPickerPaletteLongPressHint.
  ///
  /// In ja, this message translates to:
  /// **'長押しで削除できます'**
  String get colorPickerPaletteLongPressHint;

  /// No description provided for @colorPickerAddCurrentColorButton.
  ///
  /// In ja, this message translates to:
  /// **'現在の色をパレットに追加'**
  String get colorPickerAddCurrentColorButton;

  /// No description provided for @colorPickerPaletteNameLabel.
  ///
  /// In ja, this message translates to:
  /// **'パレット名'**
  String get colorPickerPaletteNameLabel;

  /// No description provided for @colorPickerFavoriteAdd.
  ///
  /// In ja, this message translates to:
  /// **'お気に入り登録'**
  String get colorPickerFavoriteAdd;

  /// No description provided for @colorPickerFavoriteRemove.
  ///
  /// In ja, this message translates to:
  /// **'お気に入り解除'**
  String get colorPickerFavoriteRemove;

  /// No description provided for @penSubToolTabBrush.
  ///
  /// In ja, this message translates to:
  /// **'ブラシ'**
  String get penSubToolTabBrush;

  /// No description provided for @penSubToolTabTone.
  ///
  /// In ja, this message translates to:
  /// **'トーン'**
  String get penSubToolTabTone;

  /// No description provided for @penSubToolTabStamp.
  ///
  /// In ja, this message translates to:
  /// **'スタンプ'**
  String get penSubToolTabStamp;

  /// No description provided for @penSubToolTabLassoFill.
  ///
  /// In ja, this message translates to:
  /// **'投げ縄塗り'**
  String get penSubToolTabLassoFill;

  /// No description provided for @penSubToolToneTooltipMessage.
  ///
  /// In ja, this message translates to:
  /// **'トーンを選ぶと、バケツやペンでアミトーン柄を塗れます。'**
  String get penSubToolToneTooltipMessage;

  /// No description provided for @penSubToolStampTooltipMessage.
  ///
  /// In ja, this message translates to:
  /// **'決まった形のスタンプを配置できます。長押しで回転・密度などを設定できます。'**
  String get penSubToolStampTooltipMessage;

  /// No description provided for @penSubToolManageTooltip.
  ///
  /// In ja, this message translates to:
  /// **'管理'**
  String get penSubToolManageTooltip;

  /// No description provided for @penSubToolBrushSizeOpacity.
  ///
  /// In ja, this message translates to:
  /// **'{size}px · {opacity}%'**
  String penSubToolBrushSizeOpacity(int size, int opacity);

  /// No description provided for @penSubToolStampRotationSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'ストローク方向に合わせてランダムに回転'**
  String get penSubToolStampRotationSubtitle;

  /// No description provided for @brushSearchHint.
  ///
  /// In ja, this message translates to:
  /// **'ブラシ名で検索'**
  String get brushSearchHint;

  /// No description provided for @brushEmpty.
  ///
  /// In ja, this message translates to:
  /// **'ブラシがありません'**
  String get brushEmpty;

  /// No description provided for @brushCreateDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'自作ブラシ'**
  String get brushCreateDialogTitle;

  /// No description provided for @brushImportFailedSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'ブラシの読み込みに失敗しました: {error}'**
  String brushImportFailedSnackbar(String error);

  /// No description provided for @brushExportFailedSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'ブラシの書き出しに失敗しました: {error}'**
  String brushExportFailedSnackbar(String error);

  /// No description provided for @brushSettingsSizeLabel.
  ///
  /// In ja, this message translates to:
  /// **'サイズ'**
  String get brushSettingsSizeLabel;

  /// No description provided for @brushSettingsOpacityLabel.
  ///
  /// In ja, this message translates to:
  /// **'不透明度'**
  String get brushSettingsOpacityLabel;

  /// No description provided for @brushSettingsSpacingLabel.
  ///
  /// In ja, this message translates to:
  /// **'間隔'**
  String get brushSettingsSpacingLabel;

  /// No description provided for @brushSettingsBlurRadiusLabel.
  ///
  /// In ja, this message translates to:
  /// **'ぼかし半径'**
  String get brushSettingsBlurRadiusLabel;

  /// No description provided for @brushSettingsStabilizationTitle.
  ///
  /// In ja, this message translates to:
  /// **'手ブレ補正'**
  String get brushSettingsStabilizationTitle;

  /// No description provided for @brushSettingsStabilizationStrengthLabel.
  ///
  /// In ja, this message translates to:
  /// **'補正強度'**
  String get brushSettingsStabilizationStrengthLabel;

  /// No description provided for @brushSettingsPixelModeTitle.
  ///
  /// In ja, this message translates to:
  /// **'ピクセルモード'**
  String get brushSettingsPixelModeTitle;

  /// No description provided for @brushSettingsPressureModeTitle.
  ///
  /// In ja, this message translates to:
  /// **'筆圧設定'**
  String get brushSettingsPressureModeTitle;

  /// No description provided for @brushSettingsPressureOff.
  ///
  /// In ja, this message translates to:
  /// **'無効'**
  String get brushSettingsPressureOff;

  /// No description provided for @brushSettingsPressureSize.
  ///
  /// In ja, this message translates to:
  /// **'サイズに反映'**
  String get brushSettingsPressureSize;

  /// No description provided for @brushSettingsPressureOpacity.
  ///
  /// In ja, this message translates to:
  /// **'不透明度に反映'**
  String get brushSettingsPressureOpacity;

  /// No description provided for @brushSettingsPressureSizeAndOpacity.
  ///
  /// In ja, this message translates to:
  /// **'サイズ＋不透明度に反映'**
  String get brushSettingsPressureSizeAndOpacity;

  /// No description provided for @brushSettingsFadeModeTitle.
  ///
  /// In ja, this message translates to:
  /// **'フェード'**
  String get brushSettingsFadeModeTitle;

  /// No description provided for @brushSettingsFadeOff.
  ///
  /// In ja, this message translates to:
  /// **'OFF'**
  String get brushSettingsFadeOff;

  /// No description provided for @brushSettingsFadeWeak.
  ///
  /// In ja, this message translates to:
  /// **'弱'**
  String get brushSettingsFadeWeak;

  /// No description provided for @brushSettingsFadeMedium.
  ///
  /// In ja, this message translates to:
  /// **'中'**
  String get brushSettingsFadeMedium;

  /// No description provided for @brushSettingsFadeStrong.
  ///
  /// In ja, this message translates to:
  /// **'強'**
  String get brushSettingsFadeStrong;

  /// No description provided for @brushSettingsFadeCustom.
  ///
  /// In ja, this message translates to:
  /// **'カスタム'**
  String get brushSettingsFadeCustom;

  /// No description provided for @brushSettingsFadeStartValueLabel.
  ///
  /// In ja, this message translates to:
  /// **'開始値(%)'**
  String get brushSettingsFadeStartValueLabel;

  /// No description provided for @brushSettingsFadeEndValueLabel.
  ///
  /// In ja, this message translates to:
  /// **'終了値(%)'**
  String get brushSettingsFadeEndValueLabel;

  /// No description provided for @brushSettingsFadeDistanceLabel.
  ///
  /// In ja, this message translates to:
  /// **'距離(px)'**
  String get brushSettingsFadeDistanceLabel;

  /// No description provided for @brushSettingsStrokeDecayTitle.
  ///
  /// In ja, this message translates to:
  /// **'ストローク減衰'**
  String get brushSettingsStrokeDecayTitle;

  /// No description provided for @brushSettingsStrokeDecaySubtitle.
  ///
  /// In ja, this message translates to:
  /// **'描き続けるほど不透明度が下がる'**
  String get brushSettingsStrokeDecaySubtitle;

  /// No description provided for @brushSettingsMixingTitle.
  ///
  /// In ja, this message translates to:
  /// **'混色'**
  String get brushSettingsMixingTitle;

  /// No description provided for @brushSettingsMixingOff.
  ///
  /// In ja, this message translates to:
  /// **'OFF'**
  String get brushSettingsMixingOff;

  /// No description provided for @brushSettingsMixingSimple.
  ///
  /// In ja, this message translates to:
  /// **'簡易混色'**
  String get brushSettingsMixingSimple;

  /// No description provided for @brushSettingsMixingBleed.
  ///
  /// In ja, this message translates to:
  /// **'にじみ'**
  String get brushSettingsMixingBleed;

  /// No description provided for @brushSettingsMixingRateLabel.
  ///
  /// In ja, this message translates to:
  /// **'混色率'**
  String get brushSettingsMixingRateLabel;

  /// No description provided for @projectDetailNotFoundTitle.
  ///
  /// In ja, this message translates to:
  /// **'プロジェクト'**
  String get projectDetailNotFoundTitle;

  /// No description provided for @projectDetailNotFoundBody.
  ///
  /// In ja, this message translates to:
  /// **'プロジェクトが見つかりません'**
  String get projectDetailNotFoundBody;

  /// No description provided for @projectDetailFirstFrameTooltip.
  ///
  /// In ja, this message translates to:
  /// **'先頭フレーム'**
  String get projectDetailFirstFrameTooltip;

  /// No description provided for @projectDetailPrevFrameTooltip.
  ///
  /// In ja, this message translates to:
  /// **'1フレーム戻る'**
  String get projectDetailPrevFrameTooltip;

  /// No description provided for @projectDetailPauseTooltip.
  ///
  /// In ja, this message translates to:
  /// **'一時停止'**
  String get projectDetailPauseTooltip;

  /// No description provided for @projectDetailPlayTooltip.
  ///
  /// In ja, this message translates to:
  /// **'再生'**
  String get projectDetailPlayTooltip;

  /// No description provided for @projectDetailNextFrameTooltip.
  ///
  /// In ja, this message translates to:
  /// **'1フレーム進む'**
  String get projectDetailNextFrameTooltip;

  /// No description provided for @projectDetailLastFrameTooltip.
  ///
  /// In ja, this message translates to:
  /// **'最終フレーム'**
  String get projectDetailLastFrameTooltip;

  /// No description provided for @projectDetailFullscreenTooltip.
  ///
  /// In ja, this message translates to:
  /// **'プレビューを全画面表示'**
  String get projectDetailFullscreenTooltip;

  /// No description provided for @projectDetailFullscreenCloseTooltip.
  ///
  /// In ja, this message translates to:
  /// **'全画面プレビューを閉じる'**
  String get projectDetailFullscreenCloseTooltip;

  /// No description provided for @projectDetailStartEditButton.
  ///
  /// In ja, this message translates to:
  /// **'編集開始'**
  String get projectDetailStartEditButton;

  /// No description provided for @projectDetailTagsQuickAction.
  ///
  /// In ja, this message translates to:
  /// **'タグ'**
  String get projectDetailTagsQuickAction;

  /// No description provided for @projectDetailShareQuickAction.
  ///
  /// In ja, this message translates to:
  /// **'共有'**
  String get projectDetailShareQuickAction;

  /// No description provided for @projectDetailInfoSectionTitle.
  ///
  /// In ja, this message translates to:
  /// **'プロジェクト情報'**
  String get projectDetailInfoSectionTitle;

  /// No description provided for @projectDetailInfoExportSize.
  ///
  /// In ja, this message translates to:
  /// **'書き出しサイズ'**
  String get projectDetailInfoExportSize;

  /// No description provided for @projectDetailInfoDrawingArea.
  ///
  /// In ja, this message translates to:
  /// **'描画領域'**
  String get projectDetailInfoDrawingArea;

  /// No description provided for @projectDetailInfoDrawingAreaValue.
  ///
  /// In ja, this message translates to:
  /// **'{size}  ({scale})'**
  String projectDetailInfoDrawingAreaValue(String size, String scale);

  /// No description provided for @projectDetailInfoTotalFrames.
  ///
  /// In ja, this message translates to:
  /// **'総フレーム数'**
  String get projectDetailInfoTotalFrames;

  /// No description provided for @projectDetailInfoWorkTime.
  ///
  /// In ja, this message translates to:
  /// **'制作時間'**
  String get projectDetailInfoWorkTime;

  /// No description provided for @projectDetailInfoLastSaved.
  ///
  /// In ja, this message translates to:
  /// **'最終保存'**
  String get projectDetailInfoLastSaved;

  /// No description provided for @projectDetailInfoSize.
  ///
  /// In ja, this message translates to:
  /// **'容量'**
  String get projectDetailInfoSize;

  /// No description provided for @projectDetailAddTagHint.
  ///
  /// In ja, this message translates to:
  /// **'タグを追加'**
  String get projectDetailAddTagHint;

  /// No description provided for @projectDetailNiashareFailedSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'.niashareの作成に失敗しました: {error}'**
  String projectDetailNiashareFailedSnackbar(String error);

  /// No description provided for @projectDetailTrashMenuItem.
  ///
  /// In ja, this message translates to:
  /// **'ゴミ箱へ移動'**
  String get projectDetailTrashMenuItem;

  /// No description provided for @commonOff.
  ///
  /// In ja, this message translates to:
  /// **'OFF'**
  String get commonOff;

  /// No description provided for @perfSettingsScreenTitle.
  ///
  /// In ja, this message translates to:
  /// **'パフォーマンス設定'**
  String get perfSettingsScreenTitle;

  /// No description provided for @perfSettingsQualitySection.
  ///
  /// In ja, this message translates to:
  /// **'品質設定'**
  String get perfSettingsQualitySection;

  /// No description provided for @perfSettingsQualityLow.
  ///
  /// In ja, this message translates to:
  /// **'低品質'**
  String get perfSettingsQualityLow;

  /// No description provided for @perfSettingsQualityMedium.
  ///
  /// In ja, this message translates to:
  /// **'中品質'**
  String get perfSettingsQualityMedium;

  /// No description provided for @perfSettingsQualityHigh.
  ///
  /// In ja, this message translates to:
  /// **'高品質'**
  String get perfSettingsQualityHigh;

  /// No description provided for @perfSettingsQualityCustom.
  ///
  /// In ja, this message translates to:
  /// **'カスタム'**
  String get perfSettingsQualityCustom;

  /// No description provided for @perfSettingsQualityDescLow.
  ///
  /// In ja, this message translates to:
  /// **'動作を軽くしたい端末向け（オニオン前後1枚・スロット5件）'**
  String get perfSettingsQualityDescLow;

  /// No description provided for @perfSettingsQualityDescMedium.
  ///
  /// In ja, this message translates to:
  /// **'標準的な端末向け（オニオン前後3枚・スロット10件）'**
  String get perfSettingsQualityDescMedium;

  /// No description provided for @perfSettingsQualityDescHigh.
  ///
  /// In ja, this message translates to:
  /// **'快適な動作に余裕のある端末向け（オニオン前後5枚・ツリー方式）'**
  String get perfSettingsQualityDescHigh;

  /// No description provided for @perfSettingsQualityDescCustom.
  ///
  /// In ja, this message translates to:
  /// **'各項目を個別設定'**
  String get perfSettingsQualityDescCustom;

  /// No description provided for @perfSettingsCapacitySection.
  ///
  /// In ja, this message translates to:
  /// **'容量・動作に関わる設定'**
  String get perfSettingsCapacitySection;

  /// No description provided for @perfSettingsUndoLimitTitle.
  ///
  /// In ja, this message translates to:
  /// **'Undo回数'**
  String get perfSettingsUndoLimitTitle;

  /// No description provided for @perfSettingsUndoLimitSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'多いほどメモリを消費する'**
  String get perfSettingsUndoLimitSubtitle;

  /// No description provided for @perfSettingsUndoLimitValue.
  ///
  /// In ja, this message translates to:
  /// **'{n}回'**
  String perfSettingsUndoLimitValue(int n);

  /// No description provided for @perfSettingsTrashAutoDeleteTitle.
  ///
  /// In ja, this message translates to:
  /// **'ゴミ箱の自動削除'**
  String get perfSettingsTrashAutoDeleteTitle;

  /// No description provided for @perfSettingsTrashAutoDeleteSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'削除済みプロジェクトの保持期間'**
  String get perfSettingsTrashAutoDeleteSubtitle;

  /// No description provided for @perfSettingsTrashAutoDeleteValue.
  ///
  /// In ja, this message translates to:
  /// **'{n}日'**
  String perfSettingsTrashAutoDeleteValue(int n);

  /// No description provided for @perfSettingsCurrentSettingsSection.
  ///
  /// In ja, this message translates to:
  /// **'現在の設定'**
  String get perfSettingsCurrentSettingsSection;

  /// No description provided for @perfSettingsTiltLabel.
  ///
  /// In ja, this message translates to:
  /// **'傾き検知'**
  String get perfSettingsTiltLabel;

  /// No description provided for @perfSettingsOnionPrevLabel.
  ///
  /// In ja, this message translates to:
  /// **'オニオンスキン（前）'**
  String get perfSettingsOnionPrevLabel;

  /// No description provided for @perfSettingsOnionNextLabel.
  ///
  /// In ja, this message translates to:
  /// **'オニオンスキン（後）'**
  String get perfSettingsOnionNextLabel;

  /// No description provided for @perfSettingsOnionFrameCountValue.
  ///
  /// In ja, this message translates to:
  /// **'{n}枚'**
  String perfSettingsOnionFrameCountValue(int n);

  /// No description provided for @perfSettingsSaveModeLabel.
  ///
  /// In ja, this message translates to:
  /// **'保存方式'**
  String get perfSettingsSaveModeLabel;

  /// No description provided for @perfSettingsSlotCountLabel.
  ///
  /// In ja, this message translates to:
  /// **'スロット数'**
  String get perfSettingsSlotCountLabel;

  /// No description provided for @perfSettingsSlotCountValue.
  ///
  /// In ja, this message translates to:
  /// **'{n}件'**
  String perfSettingsSlotCountValue(int n);

  /// No description provided for @perfSettingsResetButton.
  ///
  /// In ja, this message translates to:
  /// **'初期値に戻す'**
  String get perfSettingsResetButton;

  /// No description provided for @perfSettingsCopyPresetButton.
  ///
  /// In ja, this message translates to:
  /// **'現在のプリセットをコピー'**
  String get perfSettingsCopyPresetButton;

  /// No description provided for @perfSettingsTiltSwitchTitle.
  ///
  /// In ja, this message translates to:
  /// **'ペンの傾きをブラシに反映'**
  String get perfSettingsTiltSwitchTitle;

  /// No description provided for @perfSettingsShowPrevOnionTitle.
  ///
  /// In ja, this message translates to:
  /// **'前フレームを表示'**
  String get perfSettingsShowPrevOnionTitle;

  /// No description provided for @perfSettingsOnionCountPrevLabel.
  ///
  /// In ja, this message translates to:
  /// **'オニオンスキン枚数（前）'**
  String get perfSettingsOnionCountPrevLabel;

  /// No description provided for @perfSettingsShowNextOnionTitle.
  ///
  /// In ja, this message translates to:
  /// **'後フレームを表示'**
  String get perfSettingsShowNextOnionTitle;

  /// No description provided for @perfSettingsOnionCountNextLabel.
  ///
  /// In ja, this message translates to:
  /// **'オニオンスキン枚数（後）'**
  String get perfSettingsOnionCountNextLabel;

  /// No description provided for @perfSettingsSaveModeSlot.
  ///
  /// In ja, this message translates to:
  /// **'スロット方式'**
  String get perfSettingsSaveModeSlot;

  /// No description provided for @perfSettingsSaveModeTree.
  ///
  /// In ja, this message translates to:
  /// **'ツリー方式'**
  String get perfSettingsSaveModeTree;

  /// No description provided for @perfSettingsResetDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'カスタム品質設定を初期値に戻しますか？'**
  String get perfSettingsResetDialogTitle;

  /// No description provided for @perfSettingsResetDialogBody.
  ///
  /// In ja, this message translates to:
  /// **'初期値は、初回起動時に端末性能から自動判定された「{preset}」の設定になります。'**
  String perfSettingsResetDialogBody(String preset);

  /// No description provided for @perfSettingsResetConfirmButton.
  ///
  /// In ja, this message translates to:
  /// **'戻す'**
  String get perfSettingsResetConfirmButton;

  /// No description provided for @perfSettingsCopyPresetDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'コピーするプリセットを選択'**
  String get perfSettingsCopyPresetDialogTitle;

  /// No description provided for @perfSettingsCopyPresetDialogBody.
  ///
  /// In ja, this message translates to:
  /// **'カスタム設定へコピーするプリセットを選択してください。'**
  String get perfSettingsCopyPresetDialogBody;

  /// No description provided for @perfSettingsCopyDescLow.
  ///
  /// In ja, this message translates to:
  /// **'前後1枚表示・軽量動作'**
  String get perfSettingsCopyDescLow;

  /// No description provided for @perfSettingsCopyDescMedium.
  ///
  /// In ja, this message translates to:
  /// **'前後3枚表示・標準'**
  String get perfSettingsCopyDescMedium;

  /// No description provided for @perfSettingsCopyDescHigh.
  ///
  /// In ja, this message translates to:
  /// **'前後5枚表示・高品質'**
  String get perfSettingsCopyDescHigh;

  /// No description provided for @filterPanelTitle.
  ///
  /// In ja, this message translates to:
  /// **'フィルター'**
  String get filterPanelTitle;

  /// No description provided for @filterPanelTitleBulk.
  ///
  /// In ja, this message translates to:
  /// **'フィルター（{count}フレームへ一括適用）'**
  String filterPanelTitleBulk(int count);

  /// No description provided for @filterSearchHint.
  ///
  /// In ja, this message translates to:
  /// **'フィルター検索'**
  String get filterSearchHint;

  /// No description provided for @filterNameGaussianBlur.
  ///
  /// In ja, this message translates to:
  /// **'ガウスぼかし'**
  String get filterNameGaussianBlur;

  /// No description provided for @filterNameLensBlur.
  ///
  /// In ja, this message translates to:
  /// **'レンズぼかし'**
  String get filterNameLensBlur;

  /// No description provided for @filterNameAnimeStyle.
  ///
  /// In ja, this message translates to:
  /// **'アニメ風加工'**
  String get filterNameAnimeStyle;

  /// No description provided for @filterNameOutline.
  ///
  /// In ja, this message translates to:
  /// **'縁取り'**
  String get filterNameOutline;

  /// No description provided for @filterNameToneCurve.
  ///
  /// In ja, this message translates to:
  /// **'トーンカーブ'**
  String get filterNameToneCurve;

  /// No description provided for @filterNameLevels.
  ///
  /// In ja, this message translates to:
  /// **'レベル補正'**
  String get filterNameLevels;

  /// No description provided for @filterNameSharpen.
  ///
  /// In ja, this message translates to:
  /// **'シャープ'**
  String get filterNameSharpen;

  /// No description provided for @filterNameUnsharpMask.
  ///
  /// In ja, this message translates to:
  /// **'アンシャープマスク'**
  String get filterNameUnsharpMask;

  /// No description provided for @filterSharpenStrength.
  ///
  /// In ja, this message translates to:
  /// **'シャープの強さ'**
  String get filterSharpenStrength;

  /// No description provided for @filterUnsharpAmount.
  ///
  /// In ja, this message translates to:
  /// **'かかり具合'**
  String get filterUnsharpAmount;

  /// No description provided for @filterNameVignette.
  ///
  /// In ja, this message translates to:
  /// **'周辺減光'**
  String get filterNameVignette;

  /// No description provided for @filterVignetteStrength.
  ///
  /// In ja, this message translates to:
  /// **'減光の強さ'**
  String get filterVignetteStrength;

  /// No description provided for @filterVignetteColor.
  ///
  /// In ja, this message translates to:
  /// **'減光色'**
  String get filterVignetteColor;

  /// No description provided for @filterNameNoise.
  ///
  /// In ja, this message translates to:
  /// **'フィルムグレイン'**
  String get filterNameNoise;

  /// No description provided for @filterNoiseStrength.
  ///
  /// In ja, this message translates to:
  /// **'粒子の強さ'**
  String get filterNoiseStrength;

  /// No description provided for @filterNameRetroAnime.
  ///
  /// In ja, this message translates to:
  /// **'レトロアニメ'**
  String get filterNameRetroAnime;

  /// No description provided for @filterNameCrt.
  ///
  /// In ja, this message translates to:
  /// **'ブラウン管'**
  String get filterNameCrt;

  /// No description provided for @filterRetroStrength.
  ///
  /// In ja, this message translates to:
  /// **'強さ'**
  String get filterRetroStrength;

  /// No description provided for @filterOutlineLayerNameSuffix.
  ///
  /// In ja, this message translates to:
  /// **'{name}（縁取り）'**
  String filterOutlineLayerNameSuffix(String name);

  /// No description provided for @filterStrengthBlurRadius.
  ///
  /// In ja, this message translates to:
  /// **'強さ（ぼかし半径）'**
  String get filterStrengthBlurRadius;

  /// No description provided for @filterColorLevels.
  ///
  /// In ja, this message translates to:
  /// **'色数'**
  String get filterColorLevels;

  /// No description provided for @filterEdgeStrength.
  ///
  /// In ja, this message translates to:
  /// **'エッジ強調'**
  String get filterEdgeStrength;

  /// No description provided for @filterOutlineColor.
  ///
  /// In ja, this message translates to:
  /// **'縁取り色'**
  String get filterOutlineColor;

  /// No description provided for @filterOutlineWidth.
  ///
  /// In ja, this message translates to:
  /// **'縁取り線幅'**
  String get filterOutlineWidth;

  /// No description provided for @filterToneCurveLinear.
  ///
  /// In ja, this message translates to:
  /// **'標準'**
  String get filterToneCurveLinear;

  /// No description provided for @filterToneCurveBrighten.
  ///
  /// In ja, this message translates to:
  /// **'明るく'**
  String get filterToneCurveBrighten;

  /// No description provided for @filterToneCurveDarken.
  ///
  /// In ja, this message translates to:
  /// **'暗く'**
  String get filterToneCurveDarken;

  /// No description provided for @filterToneCurveHighContrast.
  ///
  /// In ja, this message translates to:
  /// **'コントラスト強'**
  String get filterToneCurveHighContrast;

  /// No description provided for @filterToneCurveLowContrast.
  ///
  /// In ja, this message translates to:
  /// **'コントラスト弱'**
  String get filterToneCurveLowContrast;

  /// No description provided for @filterToneCurveInvert.
  ///
  /// In ja, this message translates to:
  /// **'反転'**
  String get filterToneCurveInvert;

  /// No description provided for @filterLevelsInputBlack.
  ///
  /// In ja, this message translates to:
  /// **'入力：黒'**
  String get filterLevelsInputBlack;

  /// No description provided for @filterLevelsInputWhite.
  ///
  /// In ja, this message translates to:
  /// **'入力：白'**
  String get filterLevelsInputWhite;

  /// No description provided for @filterLevelsOutputBlack.
  ///
  /// In ja, this message translates to:
  /// **'出力：黒'**
  String get filterLevelsOutputBlack;

  /// No description provided for @filterLevelsOutputWhite.
  ///
  /// In ja, this message translates to:
  /// **'出力：白'**
  String get filterLevelsOutputWhite;

  /// No description provided for @filterApplyButton.
  ///
  /// In ja, this message translates to:
  /// **'適用'**
  String get filterApplyButton;

  /// No description provided for @filterApplyBulkButton.
  ///
  /// In ja, this message translates to:
  /// **'{count}フレームへ適用'**
  String filterApplyBulkButton(int count);

  /// No description provided for @filterEmpty.
  ///
  /// In ja, this message translates to:
  /// **'フィルターがありません'**
  String get filterEmpty;

  /// No description provided for @filterApplyingTitle.
  ///
  /// In ja, this message translates to:
  /// **'フィルター適用中'**
  String get filterApplyingTitle;

  /// No description provided for @filterApplyingSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'{name}　{count}フレーム'**
  String filterApplyingSubtitle(String name, int count);

  /// No description provided for @projectListNewFolderTitle.
  ///
  /// In ja, this message translates to:
  /// **'新規フォルダ'**
  String get projectListNewFolderTitle;

  /// No description provided for @projectListFolderHint.
  ///
  /// In ja, this message translates to:
  /// **'同じ作品の複数話数やシリーズをまとめる場合にも使えます'**
  String get projectListFolderHint;

  /// No description provided for @projectListEmptyTitle.
  ///
  /// In ja, this message translates to:
  /// **'プロジェクトがありません'**
  String get projectListEmptyTitle;

  /// No description provided for @projectListEmptyHint.
  ///
  /// In ja, this message translates to:
  /// **'＋ ボタンから新規作成'**
  String get projectListEmptyHint;

  /// No description provided for @projectListOpenAction.
  ///
  /// In ja, this message translates to:
  /// **'開く'**
  String get projectListOpenAction;

  /// No description provided for @projectListCreateShareAction.
  ///
  /// In ja, this message translates to:
  /// **'.niashareを作成'**
  String get projectListCreateShareAction;

  /// No description provided for @projectListEditFolderAction.
  ///
  /// In ja, this message translates to:
  /// **'名前・色を編集'**
  String get projectListEditFolderAction;

  /// No description provided for @projectListDeleteFolderConfirmTitle.
  ///
  /// In ja, this message translates to:
  /// **'フォルダを削除しますか？'**
  String get projectListDeleteFolderConfirmTitle;

  /// No description provided for @projectListDeleteFolderConfirmBody.
  ///
  /// In ja, this message translates to:
  /// **'「{name}」を削除します。中のプロジェクト・子フォルダはルートへ戻ります。'**
  String projectListDeleteFolderConfirmBody(String name);

  /// No description provided for @projectListFolderRootOption.
  ///
  /// In ja, this message translates to:
  /// **'フォルダなし（ルート）'**
  String get projectListFolderRootOption;

  /// No description provided for @projectListEditFolderTooltip.
  ///
  /// In ja, this message translates to:
  /// **'フォルダを編集'**
  String get projectListEditFolderTooltip;

  /// No description provided for @projectListCreateFolderAction.
  ///
  /// In ja, this message translates to:
  /// **'新規フォルダを作成'**
  String get projectListCreateFolderAction;

  /// No description provided for @projectListFolderColorLabel.
  ///
  /// In ja, this message translates to:
  /// **'フォルダ色'**
  String get projectListFolderColorLabel;

  /// No description provided for @projectListMaterialIncludeTitle.
  ///
  /// In ja, this message translates to:
  /// **'素材の同梱'**
  String get projectListMaterialIncludeTitle;

  /// No description provided for @projectListMaterialIncludeHint.
  ///
  /// In ja, this message translates to:
  /// **'同梱しない場合、受信側で不足素材の警告が表示されます。'**
  String get projectListMaterialIncludeHint;

  /// No description provided for @projectListMaterialImage.
  ///
  /// In ja, this message translates to:
  /// **'画像'**
  String get projectListMaterialImage;

  /// No description provided for @projectListMaterialVideo.
  ///
  /// In ja, this message translates to:
  /// **'動画'**
  String get projectListMaterialVideo;

  /// No description provided for @projectListMaterialAudio.
  ///
  /// In ja, this message translates to:
  /// **'音声'**
  String get projectListMaterialAudio;

  /// No description provided for @projectListIncludeFontsTitle.
  ///
  /// In ja, this message translates to:
  /// **'フォントを含める'**
  String get projectListIncludeFontsTitle;

  /// No description provided for @projectListIncludeFontsSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'使用中のユーザー追加フォントを同梱します'**
  String get projectListIncludeFontsSubtitle;

  /// No description provided for @blendModeNormal.
  ///
  /// In ja, this message translates to:
  /// **'通常'**
  String get blendModeNormal;

  /// No description provided for @blendModeMultiply.
  ///
  /// In ja, this message translates to:
  /// **'乗算'**
  String get blendModeMultiply;

  /// No description provided for @blendModeScreen.
  ///
  /// In ja, this message translates to:
  /// **'スクリーン'**
  String get blendModeScreen;

  /// No description provided for @blendModeOverlay.
  ///
  /// In ja, this message translates to:
  /// **'オーバーレイ'**
  String get blendModeOverlay;

  /// No description provided for @blendModeAddition.
  ///
  /// In ja, this message translates to:
  /// **'加算'**
  String get blendModeAddition;

  /// No description provided for @blendModeSubtract.
  ///
  /// In ja, this message translates to:
  /// **'減算'**
  String get blendModeSubtract;

  /// No description provided for @blendModeDarken.
  ///
  /// In ja, this message translates to:
  /// **'比較（暗）'**
  String get blendModeDarken;

  /// No description provided for @blendModeLighten.
  ///
  /// In ja, this message translates to:
  /// **'比較（明）'**
  String get blendModeLighten;

  /// No description provided for @blendModeColorBurn.
  ///
  /// In ja, this message translates to:
  /// **'焼き込みカラー'**
  String get blendModeColorBurn;

  /// No description provided for @blendModeColorDodge.
  ///
  /// In ja, this message translates to:
  /// **'覆い焼きカラー'**
  String get blendModeColorDodge;

  /// No description provided for @blendModeHardLight.
  ///
  /// In ja, this message translates to:
  /// **'ハードライト'**
  String get blendModeHardLight;

  /// No description provided for @blendModeSoftLight.
  ///
  /// In ja, this message translates to:
  /// **'ソフトライト'**
  String get blendModeSoftLight;

  /// No description provided for @blendModeDifference.
  ///
  /// In ja, this message translates to:
  /// **'差の絶対値'**
  String get blendModeDifference;

  /// No description provided for @blendModeHue.
  ///
  /// In ja, this message translates to:
  /// **'色相'**
  String get blendModeHue;

  /// No description provided for @blendModeSaturation.
  ///
  /// In ja, this message translates to:
  /// **'彩度'**
  String get blendModeSaturation;

  /// No description provided for @blendModeColor.
  ///
  /// In ja, this message translates to:
  /// **'カラー'**
  String get blendModeColor;

  /// No description provided for @blendModeLuminosity.
  ///
  /// In ja, this message translates to:
  /// **'輝度'**
  String get blendModeLuminosity;

  /// No description provided for @autofillLineColorModeSpecified.
  ///
  /// In ja, this message translates to:
  /// **'指定色'**
  String get autofillLineColorModeSpecified;

  /// No description provided for @autofillLineColorModeSameAsFill.
  ///
  /// In ja, this message translates to:
  /// **'塗り色と同じ'**
  String get autofillLineColorModeSameAsFill;

  /// No description provided for @autofillLineColorModeTraceAdjust.
  ///
  /// In ja, this message translates to:
  /// **'色トレス・線画馴染ませ'**
  String get autofillLineColorModeTraceAdjust;

  /// No description provided for @autofillGradientTypeLinear.
  ///
  /// In ja, this message translates to:
  /// **'直線'**
  String get autofillGradientTypeLinear;

  /// No description provided for @autofillGradientTypeRadialCenterOut.
  ///
  /// In ja, this message translates to:
  /// **'放射：中央→外側'**
  String get autofillGradientTypeRadialCenterOut;

  /// No description provided for @autofillGradientTypeRadialOutCenter.
  ///
  /// In ja, this message translates to:
  /// **'放射：外側→中央'**
  String get autofillGradientTypeRadialOutCenter;

  /// No description provided for @autofillPresetScreenTitle.
  ///
  /// In ja, this message translates to:
  /// **'自動塗り設定'**
  String get autofillPresetScreenTitle;

  /// No description provided for @autofillPresetSearchHint.
  ///
  /// In ja, this message translates to:
  /// **'設定を検索'**
  String get autofillPresetSearchHint;

  /// No description provided for @autofillPresetEmptyFavorites.
  ///
  /// In ja, this message translates to:
  /// **'お気に入りの設定がありません'**
  String get autofillPresetEmptyFavorites;

  /// No description provided for @autofillPresetEmpty.
  ///
  /// In ja, this message translates to:
  /// **'設定がありません'**
  String get autofillPresetEmpty;

  /// No description provided for @autofillPresetEmptyHint.
  ///
  /// In ja, this message translates to:
  /// **'右下の＋から作成できます'**
  String get autofillPresetEmptyHint;

  /// No description provided for @autofillPresetPartsCount.
  ///
  /// In ja, this message translates to:
  /// **'{count}パーツ'**
  String autofillPresetPartsCount(int count);

  /// No description provided for @autofillPresetNewDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'新規作成'**
  String get autofillPresetNewDialogTitle;

  /// No description provided for @autofillPresetNameLabel.
  ///
  /// In ja, this message translates to:
  /// **'設定名'**
  String get autofillPresetNameLabel;

  /// No description provided for @autofillPresetRenameDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'設定名を変更'**
  String get autofillPresetRenameDialogTitle;

  /// No description provided for @autofillPresetDeleteConfirmTitle.
  ///
  /// In ja, this message translates to:
  /// **'「{name}」を削除しますか？'**
  String autofillPresetDeleteConfirmTitle(String name);

  /// No description provided for @autofillFabImportOption.
  ///
  /// In ja, this message translates to:
  /// **'読み込み'**
  String get autofillFabImportOption;

  /// No description provided for @autofillPresetExportMenuItem.
  ///
  /// In ja, this message translates to:
  /// **'書き出し (.niafill)'**
  String get autofillPresetExportMenuItem;

  /// No description provided for @autofillPresetImportSuccessSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'{count}件のプリセットを読み込みました'**
  String autofillPresetImportSuccessSnackbar(int count);

  /// No description provided for @autofillPresetImportFailedSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'読み込みに失敗しました: {error}'**
  String autofillPresetImportFailedSnackbar(String error);

  /// No description provided for @autofillPresetExportFailedSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'書き出しに失敗しました: {error}'**
  String autofillPresetExportFailedSnackbar(String error);

  /// No description provided for @autofillPresetDuplicateName.
  ///
  /// In ja, this message translates to:
  /// **'{name} (コピー)'**
  String autofillPresetDuplicateName(String name);

  /// No description provided for @autofillPartSearchHint.
  ///
  /// In ja, this message translates to:
  /// **'パーツ名で検索'**
  String get autofillPartSearchHint;

  /// No description provided for @autofillPartUnconfiguredBanner.
  ///
  /// In ja, this message translates to:
  /// **'未設定のパーツが{count}件あります：{names}（トーン未選択）\nすべて設定するまでこの画面を閉じられません。'**
  String autofillPartUnconfiguredBanner(int count, String names);

  /// No description provided for @autofillPartUnconfiguredDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'未設定のパーツがあります'**
  String get autofillPartUnconfiguredDialogTitle;

  /// No description provided for @autofillPartUnconfiguredDialogBody.
  ///
  /// In ja, this message translates to:
  /// **'保存する前に、以下のパーツを設定してください。'**
  String get autofillPartUnconfiguredDialogBody;

  /// No description provided for @autofillPartUnconfiguredItem.
  ///
  /// In ja, this message translates to:
  /// **'・{name}：トーンが未選択です'**
  String autofillPartUnconfiguredItem(String name);

  /// No description provided for @autofillPartUnconfiguredBackButton.
  ///
  /// In ja, this message translates to:
  /// **'設定へ戻る'**
  String get autofillPartUnconfiguredBackButton;

  /// No description provided for @autofillPartEmpty.
  ///
  /// In ja, this message translates to:
  /// **'パーツがありません\n＋ボタンで追加してください'**
  String get autofillPartEmpty;

  /// No description provided for @autofillPartToneUnselected.
  ///
  /// In ja, this message translates to:
  /// **'トーンが未選択です'**
  String get autofillPartToneUnselected;

  /// No description provided for @autofillPartAddDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'パーツ追加'**
  String get autofillPartAddDialogTitle;

  /// No description provided for @autofillPartNameLabel.
  ///
  /// In ja, this message translates to:
  /// **'パーツ名'**
  String get autofillPartNameLabel;

  /// No description provided for @autofillPartAddButton.
  ///
  /// In ja, this message translates to:
  /// **'追加'**
  String get autofillPartAddButton;

  /// No description provided for @autofillPartRenameDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'パーツ名変更'**
  String get autofillPartRenameDialogTitle;

  /// No description provided for @autofillPartDetailDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'{name}の詳細設定'**
  String autofillPartDetailDialogTitle(String name);

  /// No description provided for @autofillPartFillColorLabel.
  ///
  /// In ja, this message translates to:
  /// **'塗り色'**
  String get autofillPartFillColorLabel;

  /// No description provided for @autofillPartSelectColorButton.
  ///
  /// In ja, this message translates to:
  /// **'色を選択'**
  String get autofillPartSelectColorButton;

  /// No description provided for @autofillPartOutlineLabel.
  ///
  /// In ja, this message translates to:
  /// **'指定色で縁取り'**
  String get autofillPartOutlineLabel;

  /// No description provided for @autofillPartOutlineWidthLabel.
  ///
  /// In ja, this message translates to:
  /// **'縁取り太さ: {value}px'**
  String autofillPartOutlineWidthLabel(int value);

  /// No description provided for @autofillEyedropperFromThumbnailButton.
  ///
  /// In ja, this message translates to:
  /// **'画像からスポイト'**
  String get autofillEyedropperFromThumbnailButton;

  /// No description provided for @autofillEyedropperDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'画像から色を拾う'**
  String get autofillEyedropperDialogTitle;

  /// No description provided for @autofillEyedropperDialogHint.
  ///
  /// In ja, this message translates to:
  /// **'画像をタップして色を選択してください'**
  String get autofillEyedropperDialogHint;

  /// No description provided for @autofillEyedropperPickedLabel.
  ///
  /// In ja, this message translates to:
  /// **'選択した色'**
  String get autofillEyedropperPickedLabel;

  /// No description provided for @autofillEyedropperImageLoadFailedSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'画像を読み込めませんでした'**
  String get autofillEyedropperImageLoadFailedSnackbar;

  /// No description provided for @autofillThumbnailMenuItem.
  ///
  /// In ja, this message translates to:
  /// **'サムネイル画像設定'**
  String get autofillThumbnailMenuItem;

  /// No description provided for @autofillThumbnailLoadButton.
  ///
  /// In ja, this message translates to:
  /// **'画像読み込み'**
  String get autofillThumbnailLoadButton;

  /// No description provided for @autofillThumbnailDeleteButton.
  ///
  /// In ja, this message translates to:
  /// **'サムネイル画像削除'**
  String get autofillThumbnailDeleteButton;

  /// No description provided for @autofillThumbnailDeleteConfirmTitle.
  ///
  /// In ja, this message translates to:
  /// **'サムネイル画像を削除しますか？'**
  String get autofillThumbnailDeleteConfirmTitle;

  /// No description provided for @autofillThumbnailDeleteConfirmBody.
  ///
  /// In ja, this message translates to:
  /// **'削除すると既定のパーツ色表示（最大4色）に戻ります。'**
  String get autofillThumbnailDeleteConfirmBody;

  /// No description provided for @autofillThumbnailCropDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'サムネイル画像を調整'**
  String get autofillThumbnailCropDialogTitle;

  /// No description provided for @autofillThumbnailCropDialogHint.
  ///
  /// In ja, this message translates to:
  /// **'ドラッグで位置調整、ピンチで拡大縮小、2本指で回転できます'**
  String get autofillThumbnailCropDialogHint;

  /// No description provided for @autofillThumbnailCropLoadFailed.
  ///
  /// In ja, this message translates to:
  /// **'画像を読み込めませんでした。別の画像でお試しください。'**
  String get autofillThumbnailCropLoadFailed;

  /// No description provided for @autofillThumbnailSetSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'サムネイル画像を設定しました'**
  String get autofillThumbnailSetSnackbar;

  /// No description provided for @autofillPartGradientSetButton.
  ///
  /// In ja, this message translates to:
  /// **'グラデーション設定'**
  String get autofillPartGradientSetButton;

  /// No description provided for @autofillPartGradientEditButton.
  ///
  /// In ja, this message translates to:
  /// **'グラデーション編集'**
  String get autofillPartGradientEditButton;

  /// No description provided for @autofillPartFillOpacityLabel.
  ///
  /// In ja, this message translates to:
  /// **'不透明度（塗りレイヤー）: {value}%'**
  String autofillPartFillOpacityLabel(int value);

  /// No description provided for @autofillPartLineColorLabel.
  ///
  /// In ja, this message translates to:
  /// **'線画色'**
  String get autofillPartLineColorLabel;

  /// No description provided for @autofillPartTraceHueLabel.
  ///
  /// In ja, this message translates to:
  /// **'色相: {value}'**
  String autofillPartTraceHueLabel(int value);

  /// No description provided for @autofillPartTraceSaturationLabel.
  ///
  /// In ja, this message translates to:
  /// **'彩度: {value}'**
  String autofillPartTraceSaturationLabel(int value);

  /// No description provided for @autofillPartTraceLightnessLabel.
  ///
  /// In ja, this message translates to:
  /// **'明度: {value}'**
  String autofillPartTraceLightnessLabel(int value);

  /// No description provided for @autofillPartLineOpacityLabel.
  ///
  /// In ja, this message translates to:
  /// **'不透明度（線画レイヤー）: {value}%'**
  String autofillPartLineOpacityLabel(int value);

  /// No description provided for @autofillPartToneLabel.
  ///
  /// In ja, this message translates to:
  /// **'トーン'**
  String get autofillPartToneLabel;

  /// No description provided for @autofillPartUseToneCheckbox.
  ///
  /// In ja, this message translates to:
  /// **'トーンを使用'**
  String get autofillPartUseToneCheckbox;

  /// No description provided for @autofillPartBlendModeLabel.
  ///
  /// In ja, this message translates to:
  /// **'ブレンドモード'**
  String get autofillPartBlendModeLabel;

  /// No description provided for @autofillPartApplyButton.
  ///
  /// In ja, this message translates to:
  /// **'適用'**
  String get autofillPartApplyButton;

  /// No description provided for @autofillPartGradientDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'{name}のグラデーション'**
  String autofillPartGradientDialogTitle(String name);

  /// No description provided for @autofillPartGradientTypeLabel.
  ///
  /// In ja, this message translates to:
  /// **'種類'**
  String get autofillPartGradientTypeLabel;

  /// No description provided for @autofillPartGradientTypeInfo.
  ///
  /// In ja, this message translates to:
  /// **'直線：指定した角度に沿って色が変化します。放射：中央→外側は中心から外側へ、外側→中央は逆に外側から中心へ色が変化します。'**
  String get autofillPartGradientTypeInfo;

  /// No description provided for @autofillPartGradientFeatherInfo.
  ///
  /// In ja, this message translates to:
  /// **'0%にすると隣り合う色の境界がくっきり分かれます。100%にすると隣の色の端まで完全になめらかに混ざります。'**
  String get autofillPartGradientFeatherInfo;

  /// No description provided for @autofillLineColorModeTraceAdjustInfo.
  ///
  /// In ja, this message translates to:
  /// **'元の線の色を保ったまま、色相・彩度・明度をずらして少しだけ色味を変える機能です。線を単色で塗りつぶすのではなく、線画の濃淡を活かしたい場合に使います。'**
  String get autofillLineColorModeTraceAdjustInfo;

  /// No description provided for @autofillPartGradientAngleLabel.
  ///
  /// In ja, this message translates to:
  /// **'角度: {value}°'**
  String autofillPartGradientAngleLabel(int value);

  /// No description provided for @autofillPartGradientColorLabel.
  ///
  /// In ja, this message translates to:
  /// **'色'**
  String get autofillPartGradientColorLabel;

  /// No description provided for @autofillPartGradientAddColorButton.
  ///
  /// In ja, this message translates to:
  /// **'色を追加'**
  String get autofillPartGradientAddColorButton;

  /// No description provided for @autofillPartGradientRemoveButton.
  ///
  /// In ja, this message translates to:
  /// **'グラデーション解除'**
  String get autofillPartGradientRemoveButton;

  /// No description provided for @autofillPartGradientFeatherLabel.
  ///
  /// In ja, this message translates to:
  /// **'ぼかしの強さ: {value}%'**
  String autofillPartGradientFeatherLabel(int value);

  /// No description provided for @autofillPartGradientDragHint.
  ///
  /// In ja, this message translates to:
  /// **'ドラッグ（右端のハンドル）で色の順番を入れ替えられます'**
  String get autofillPartGradientDragHint;

  /// No description provided for @autofillPartGradientStopLabel.
  ///
  /// In ja, this message translates to:
  /// **'切り替え位置: {value}%'**
  String autofillPartGradientStopLabel(int value);

  /// No description provided for @autofillPartGradientStopDragHint.
  ///
  /// In ja, this message translates to:
  /// **'▲を左右にドラッグして色の切り替え位置を調整できます'**
  String get autofillPartGradientStopDragHint;

  /// No description provided for @saveTreeScreenTitleTree.
  ///
  /// In ja, this message translates to:
  /// **'セーブツリー'**
  String get saveTreeScreenTitleTree;

  /// No description provided for @saveTreeScreenTitleSlot.
  ///
  /// In ja, this message translates to:
  /// **'セーブスロット'**
  String get saveTreeScreenTitleSlot;

  /// No description provided for @timelineExportMenuItem.
  ///
  /// In ja, this message translates to:
  /// **'書き出し'**
  String get timelineExportMenuItem;

  /// No description provided for @timelineExportFrameMenuItem.
  ///
  /// In ja, this message translates to:
  /// **'フレームを画像で書き出す'**
  String get timelineExportFrameMenuItem;

  /// No description provided for @timelineExportFrameDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'フレームを画像で書き出す'**
  String get timelineExportFrameDialogTitle;

  /// No description provided for @timelineExportFrameDialogMessage.
  ///
  /// In ja, this message translates to:
  /// **'現在表示中のフレーム1枚を静止画として保存します。形式を選んでください。'**
  String get timelineExportFrameDialogMessage;

  /// No description provided for @timelineExportFramePngOption.
  ///
  /// In ja, this message translates to:
  /// **'PNGで保存'**
  String get timelineExportFramePngOption;

  /// No description provided for @timelineExportFrameJpegOption.
  ///
  /// In ja, this message translates to:
  /// **'JPEGで保存'**
  String get timelineExportFrameJpegOption;

  /// No description provided for @timelineExportFrameSuccessSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'{fileName} として保存しました（作品一覧タブから確認できます）'**
  String timelineExportFrameSuccessSnackbar(String fileName);

  /// No description provided for @timelineExportFrameErrorSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'フレームの書き出しに失敗しました'**
  String get timelineExportFrameErrorSnackbar;

  /// No description provided for @timelineDurationChangeMenuItem.
  ///
  /// In ja, this message translates to:
  /// **'長さ変更'**
  String get timelineDurationChangeMenuItem;

  /// No description provided for @timelineCanvasSizeChangeMenuItem.
  ///
  /// In ja, this message translates to:
  /// **'キャンバスサイズ変更'**
  String get timelineCanvasSizeChangeMenuItem;

  /// No description provided for @timelineDurationFramesLabel.
  ///
  /// In ja, this message translates to:
  /// **'フレーム数'**
  String get timelineDurationFramesLabel;

  /// No description provided for @timelineDurationSecondsLabel.
  ///
  /// In ja, this message translates to:
  /// **'秒数'**
  String get timelineDurationSecondsLabel;

  /// No description provided for @timelineDurationShrinkConfirmTitle.
  ///
  /// In ja, this message translates to:
  /// **'本当に短くしますか？'**
  String get timelineDurationShrinkConfirmTitle;

  /// No description provided for @timelineDurationShrinkConfirmBody.
  ///
  /// In ja, this message translates to:
  /// **'カットされる範囲のフレームには、描画内容やレイヤー追加などの変更が加えられています。この操作を行うと、それらのフレームは元に戻せなくなります。本当に削除してよいですか？'**
  String get timelineDurationShrinkConfirmBody;

  /// No description provided for @timelineCanvasSizeDragHint.
  ///
  /// In ja, this message translates to:
  /// **'枠内をドラッグして位置を、四隅をドラッグしてサイズを変更できます（元のサイズ付近でスナップします）'**
  String get timelineCanvasSizeDragHint;

  /// No description provided for @timelineCanvasSizeAngleLabel.
  ///
  /// In ja, this message translates to:
  /// **'角度'**
  String get timelineCanvasSizeAngleLabel;

  /// No description provided for @saveTreeSaveAsChildHint.
  ///
  /// In ja, this message translates to:
  /// **'選択中のノードの子として保存します。'**
  String get saveTreeSaveAsChildHint;

  /// No description provided for @saveTreeSaveAsRootHint.
  ///
  /// In ja, this message translates to:
  /// **'ルートノードとして保存します。'**
  String get saveTreeSaveAsRootHint;

  /// No description provided for @saveTreeCommentLabel.
  ///
  /// In ja, this message translates to:
  /// **'コメント（任意）'**
  String get saveTreeCommentLabel;

  /// No description provided for @saveTreeCommentHint.
  ///
  /// In ja, this message translates to:
  /// **'例：背景完成'**
  String get saveTreeCommentHint;

  /// No description provided for @saveTreeSizeWarningSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'セーブツリーの容量が大きくなっています（約{mb}MB）。不要な保存データの削除をおすすめします。'**
  String saveTreeSizeWarningSnackbar(String mb);

  /// No description provided for @saveTreeSaveFailedSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'保存に失敗しました。空き容量などを確認してもう一度お試しください（{error}）'**
  String saveTreeSaveFailedSnackbar(String error);

  /// No description provided for @saveTreeSlotSaveDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'スロット {n} に保存'**
  String saveTreeSlotSaveDialogTitle(int n);

  /// No description provided for @saveTreeSlotOverwriteWarning.
  ///
  /// In ja, this message translates to:
  /// **'既存データ（{date}）を上書きします。'**
  String saveTreeSlotOverwriteWarning(String date);

  /// No description provided for @saveTreeRestoreAction.
  ///
  /// In ja, this message translates to:
  /// **'復元'**
  String get saveTreeRestoreAction;

  /// No description provided for @saveTreeTimelineActionChoiceBody.
  ///
  /// In ja, this message translates to:
  /// **'このセーブへ「上書き保存」するか、「ここから作業を再開」するか選んでください。'**
  String get saveTreeTimelineActionChoiceBody;

  /// No description provided for @saveTreeOverwriteAction.
  ///
  /// In ja, this message translates to:
  /// **'上書きする'**
  String get saveTreeOverwriteAction;

  /// No description provided for @saveTreeOverwriteConfirmBody.
  ///
  /// In ja, this message translates to:
  /// **'このときのセーブデータは消えますがよろしいですか？'**
  String get saveTreeOverwriteConfirmBody;

  /// No description provided for @saveTreeResumeFromHereAction.
  ///
  /// In ja, this message translates to:
  /// **'ここから再開する'**
  String get saveTreeResumeFromHereAction;

  /// No description provided for @saveTreeResumeConfirmBody.
  ///
  /// In ja, this message translates to:
  /// **'セーブしていない場合は現在のデータが消えますがよろしいですか？'**
  String get saveTreeResumeConfirmBody;

  /// No description provided for @saveTreeProjectDetailResumeBody.
  ///
  /// In ja, this message translates to:
  /// **'このセーブデータから作業を再開しますか？'**
  String get saveTreeProjectDetailResumeBody;

  /// No description provided for @saveTreeLoadFailedSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'保存データの読み込みに失敗しました'**
  String get saveTreeLoadFailedSnackbar;

  /// No description provided for @saveTreeRestoredSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'{name}を復元しました'**
  String saveTreeRestoredSnackbar(String name);

  /// No description provided for @saveTreeSlotLabel.
  ///
  /// In ja, this message translates to:
  /// **'スロット{n}'**
  String saveTreeSlotLabel(int n);

  /// No description provided for @saveTreeSlotFallbackName.
  ///
  /// In ja, this message translates to:
  /// **'スロット {n}'**
  String saveTreeSlotFallbackName(int n);

  /// No description provided for @saveTreeNoDataLabel.
  ///
  /// In ja, this message translates to:
  /// **'保存データなし'**
  String get saveTreeNoDataLabel;

  /// No description provided for @saveTreeEmptyTitle.
  ///
  /// In ja, this message translates to:
  /// **'保存データがありません'**
  String get saveTreeEmptyTitle;

  /// No description provided for @saveTreeEmptyHint.
  ///
  /// In ja, this message translates to:
  /// **'上部の「保存」ボタンで最初のノードを作成できます'**
  String get saveTreeEmptyHint;

  /// No description provided for @saveTreeNodeDefaultTitle.
  ///
  /// In ja, this message translates to:
  /// **'保存'**
  String get saveTreeNodeDefaultTitle;

  /// No description provided for @saveTreeNodeDefaultName.
  ///
  /// In ja, this message translates to:
  /// **'保存データ'**
  String get saveTreeNodeDefaultName;

  /// No description provided for @saveTreeChangeDataTitle.
  ///
  /// In ja, this message translates to:
  /// **'保存データ変更'**
  String get saveTreeChangeDataTitle;

  /// No description provided for @saveTreeChangeDataTitleWithProject.
  ///
  /// In ja, this message translates to:
  /// **'保存データ変更（{name}）'**
  String saveTreeChangeDataTitleWithProject(String name);

  /// No description provided for @saveTreeChangeExceedMessage.
  ///
  /// In ja, this message translates to:
  /// **'現在の保存データ数が\n新しい保存可能数を超えています。\n\n保持する保存データを選択してください。'**
  String get saveTreeChangeExceedMessage;

  /// No description provided for @saveTreeKeepableCountLabel.
  ///
  /// In ja, this message translates to:
  /// **'保持できる保存数：{n}件'**
  String saveTreeKeepableCountLabel(int n);

  /// No description provided for @saveTreeKeepLatestButton.
  ///
  /// In ja, this message translates to:
  /// **'最新{n}件を保存'**
  String saveTreeKeepLatestButton(int n);

  /// No description provided for @saveTreeSelectDataButton.
  ///
  /// In ja, this message translates to:
  /// **'保存データを選択'**
  String get saveTreeSelectDataButton;

  /// No description provided for @saveTreeSelectedCountLabel.
  ///
  /// In ja, this message translates to:
  /// **'選択中：{selected} / {limit}件'**
  String saveTreeSelectedCountLabel(int selected, int limit);

  /// No description provided for @saveTreeBackButton.
  ///
  /// In ja, this message translates to:
  /// **'戻る'**
  String get saveTreeBackButton;

  /// No description provided for @saveTreeNextButton.
  ///
  /// In ja, this message translates to:
  /// **'次へ'**
  String get saveTreeNextButton;

  /// No description provided for @saveTreeDiscardDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'選択されなかった保存データ'**
  String get saveTreeDiscardDialogTitle;

  /// No description provided for @saveTreeArchiveOptionTitle.
  ///
  /// In ja, this message translates to:
  /// **'アーカイブとして保持する（推奨）'**
  String get saveTreeArchiveOptionTitle;

  /// No description provided for @saveTreeArchiveOptionSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'セーブツリー方式へ戻したときに自動で復元されます。\nストレージ容量を使用します。'**
  String get saveTreeArchiveOptionSubtitle;

  /// No description provided for @saveTreeDeleteOptionTitle.
  ///
  /// In ja, this message translates to:
  /// **'完全に削除する'**
  String get saveTreeDeleteOptionTitle;

  /// No description provided for @saveTreeDeleteOptionSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'選択されなかった{count}件を完全に削除します。\nストレージ容量を節約できます。\n※削除したデータは元に戻せません。'**
  String saveTreeDeleteOptionSubtitle(int count);

  /// No description provided for @saveTreeApplyChangeButton.
  ///
  /// In ja, this message translates to:
  /// **'変更する'**
  String get saveTreeApplyChangeButton;

  /// No description provided for @canvasEditMenuAutofillPresets.
  ///
  /// In ja, this message translates to:
  /// **'自動塗り設定'**
  String get canvasEditMenuAutofillPresets;

  /// No description provided for @canvasEditMenuAutofillPresetsSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'パーツごとの色・トーンの組み合わせを編集'**
  String get canvasEditMenuAutofillPresetsSubtitle;

  /// No description provided for @canvasEditMenuBackgroundToggle.
  ///
  /// In ja, this message translates to:
  /// **'背景切替'**
  String get canvasEditMenuBackgroundToggle;

  /// No description provided for @canvasEditMenuBackgroundCurrentColor.
  ///
  /// In ja, this message translates to:
  /// **'現在：プロジェクト背景色（タップで透過へ）'**
  String get canvasEditMenuBackgroundCurrentColor;

  /// No description provided for @canvasEditMenuBackgroundCurrentTransparent.
  ///
  /// In ja, this message translates to:
  /// **'現在：透過（タップでプロジェクト背景色へ）'**
  String get canvasEditMenuBackgroundCurrentTransparent;

  /// No description provided for @canvasEditMenuOnionSkinSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'前後のフレームを薄く重ねて表示'**
  String get canvasEditMenuOnionSkinSubtitle;

  /// No description provided for @canvasEditMenuFilterSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'ぼかし・トーンカーブなどを適用'**
  String get canvasEditMenuFilterSubtitle;

  /// No description provided for @canvasEditMenuFrameMultiSelect.
  ///
  /// In ja, this message translates to:
  /// **'フレーム複数選択'**
  String get canvasEditMenuFrameMultiSelect;

  /// No description provided for @canvasEditMenuFrameMultiSelectSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'大量処理（フィルター一括適用など）に使用'**
  String get canvasEditMenuFrameMultiSelectSubtitle;

  /// No description provided for @canvasEditMenuPressureCurve.
  ///
  /// In ja, this message translates to:
  /// **'筆圧カーブ'**
  String get canvasEditMenuPressureCurve;

  /// No description provided for @canvasEditMenuPressureCurveSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'ペン入力設定を開く（設定画面と共通）'**
  String get canvasEditMenuPressureCurveSubtitle;

  /// No description provided for @canvasEditMenuMeshTransform.
  ///
  /// In ja, this message translates to:
  /// **'自由変形・メッシュ変形'**
  String get canvasEditMenuMeshTransform;

  /// No description provided for @canvasEditMenuMeshTransformSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'レイヤー全体を選択せずに変形する'**
  String get canvasEditMenuMeshTransformSubtitle;

  /// No description provided for @meshTransformPanelTitle.
  ///
  /// In ja, this message translates to:
  /// **'自由変形・メッシュ変形'**
  String get meshTransformPanelTitle;

  /// No description provided for @meshTransformPanelHint.
  ///
  /// In ja, this message translates to:
  /// **'角や格子点を指でドラッグして動かせます（2本指で別々の点をつまむと回転・拡大縮小も可能）'**
  String get meshTransformPanelHint;

  /// No description provided for @meshTransformDensityLabel.
  ///
  /// In ja, this message translates to:
  /// **'分割数'**
  String get meshTransformDensityLabel;

  /// No description provided for @meshTransformRotateLabel.
  ///
  /// In ja, this message translates to:
  /// **'回転'**
  String get meshTransformRotateLabel;

  /// No description provided for @meshTransformScaleLabel.
  ///
  /// In ja, this message translates to:
  /// **'拡大縮小'**
  String get meshTransformScaleLabel;

  /// No description provided for @meshTransformApplyButton.
  ///
  /// In ja, this message translates to:
  /// **'適用'**
  String get meshTransformApplyButton;

  /// No description provided for @canvasLassoEnclosedLabel.
  ///
  /// In ja, this message translates to:
  /// **'囲って塗る'**
  String get canvasLassoEnclosedLabel;

  /// No description provided for @canvasInvertSelectionTooltip.
  ///
  /// In ja, this message translates to:
  /// **'選択範囲を反転'**
  String get canvasInvertSelectionTooltip;

  /// No description provided for @canvasTapToEnterTextLabel.
  ///
  /// In ja, this message translates to:
  /// **'キャンバスをタップしてテキストを入力'**
  String get canvasTapToEnterTextLabel;

  /// No description provided for @canvasRulerFirstUseTip.
  ///
  /// In ja, this message translates to:
  /// **'定規を使うとまっすぐな線や綺麗な図形が描けます。'**
  String get canvasRulerFirstUseTip;

  /// No description provided for @canvasRulerTooltip.
  ///
  /// In ja, this message translates to:
  /// **'定規'**
  String get canvasRulerTooltip;

  /// No description provided for @commonUndo.
  ///
  /// In ja, this message translates to:
  /// **'Undo'**
  String get commonUndo;

  /// No description provided for @commonRedo.
  ///
  /// In ja, this message translates to:
  /// **'Redo'**
  String get commonRedo;

  /// No description provided for @canvasSettingsMenuTooltip.
  ///
  /// In ja, this message translates to:
  /// **'設定/編集'**
  String get canvasSettingsMenuTooltip;

  /// No description provided for @canvasFrameSelectedCount.
  ///
  /// In ja, this message translates to:
  /// **'{selected} / {total} フレーム選択中'**
  String canvasFrameSelectedCount(int selected, int total);

  /// No description provided for @canvasSelectAllButton.
  ///
  /// In ja, this message translates to:
  /// **'全選択'**
  String get canvasSelectAllButton;

  /// No description provided for @canvasDeselectAllButton.
  ///
  /// In ja, this message translates to:
  /// **'全解除'**
  String get canvasDeselectAllButton;

  /// No description provided for @canvasApplyFilterButton.
  ///
  /// In ja, this message translates to:
  /// **'フィルター適用'**
  String get canvasApplyFilterButton;

  /// No description provided for @canvasShapeOff.
  ///
  /// In ja, this message translates to:
  /// **'OFF（通常ブラシへ戻る）'**
  String get canvasShapeOff;

  /// No description provided for @canvasShapeLine.
  ///
  /// In ja, this message translates to:
  /// **'線'**
  String get canvasShapeLine;

  /// No description provided for @canvasShapeRect.
  ///
  /// In ja, this message translates to:
  /// **'四角形'**
  String get canvasShapeRect;

  /// No description provided for @canvasShapeCircle.
  ///
  /// In ja, this message translates to:
  /// **'円'**
  String get canvasShapeCircle;

  /// No description provided for @canvasMissingMaterialsSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'不足素材があります'**
  String get canvasMissingMaterialsSnackbar;

  /// No description provided for @canvasResearchButton.
  ///
  /// In ja, this message translates to:
  /// **'再検索'**
  String get canvasResearchButton;

  /// No description provided for @canvasTextInputTitle.
  ///
  /// In ja, this message translates to:
  /// **'テキスト入力'**
  String get canvasTextInputTitle;

  /// No description provided for @canvasTextEditTitle.
  ///
  /// In ja, this message translates to:
  /// **'テキスト編集'**
  String get canvasTextEditTitle;

  /// No description provided for @canvasTextInputHint.
  ///
  /// In ja, this message translates to:
  /// **'テキストを入力してください'**
  String get canvasTextInputHint;

  /// No description provided for @canvasTextFontLabel.
  ///
  /// In ja, this message translates to:
  /// **'フォント'**
  String get canvasTextFontLabel;

  /// No description provided for @canvasTextStandardFont.
  ///
  /// In ja, this message translates to:
  /// **'標準フォント'**
  String get canvasTextStandardFont;

  /// No description provided for @canvasTextBold.
  ///
  /// In ja, this message translates to:
  /// **'太字'**
  String get canvasTextBold;

  /// No description provided for @canvasTextItalic.
  ///
  /// In ja, this message translates to:
  /// **'斜体'**
  String get canvasTextItalic;

  /// No description provided for @canvasTextVertical.
  ///
  /// In ja, this message translates to:
  /// **'縦書き'**
  String get canvasTextVertical;

  /// No description provided for @canvasTextHorizontal.
  ///
  /// In ja, this message translates to:
  /// **'横書き'**
  String get canvasTextHorizontal;

  /// No description provided for @canvasTypesettingHelpTooltip.
  ///
  /// In ja, this message translates to:
  /// **'組版・ルビについて'**
  String get canvasTypesettingHelpTooltip;

  /// No description provided for @canvasTextLineHeight.
  ///
  /// In ja, this message translates to:
  /// **'行間'**
  String get canvasTextLineHeight;

  /// No description provided for @canvasTextLetterSpacing.
  ///
  /// In ja, this message translates to:
  /// **'文字間隔'**
  String get canvasTextLetterSpacing;

  /// No description provided for @canvasTextAlign.
  ///
  /// In ja, this message translates to:
  /// **'揃え'**
  String get canvasTextAlign;

  /// No description provided for @canvasTextOutline.
  ///
  /// In ja, this message translates to:
  /// **'アウトライン'**
  String get canvasTextOutline;

  /// No description provided for @canvasOutlineWidthLabel.
  ///
  /// In ja, this message translates to:
  /// **'太さ'**
  String get canvasOutlineWidthLabel;

  /// No description provided for @canvasHelpRotationTitle.
  ///
  /// In ja, this message translates to:
  /// **'半角英数字の回転（縦書きのみ）'**
  String get canvasHelpRotationTitle;

  /// No description provided for @canvasHelpRotationBody.
  ///
  /// In ja, this message translates to:
  /// **'英字・記号は自動的に90°回転して表示されます。'**
  String get canvasHelpRotationBody;

  /// No description provided for @canvasHelpTatechuyokoTitle.
  ///
  /// In ja, this message translates to:
  /// **'縦中横（縦書きのみ）'**
  String get canvasHelpTatechuyokoTitle;

  /// No description provided for @canvasHelpTatechuyokoBody.
  ///
  /// In ja, this message translates to:
  /// **'半角数字が2桁連続すると、1文字分の高さに横並びで自動的に収まります（例：12）。'**
  String get canvasHelpTatechuyokoBody;

  /// No description provided for @canvasHelpRubyTitle.
  ///
  /// In ja, this message translates to:
  /// **'ルビ（ふりがな）'**
  String get canvasHelpRubyTitle;

  /// No description provided for @canvasHelpRubyBody.
  ///
  /// In ja, this message translates to:
  /// **'「{example}」のように入力すると、基底文字の上（横書き）または右側（縦書き）に小さくふりがなが表示されます。縦書き・横書きどちらでも使えますが、ルビを含むテキストは横書きでの自動折り返しが効かなくなります（手動改行のみ対応）。'**
  String canvasHelpRubyBody(String example);

  /// No description provided for @layerPanelTitle.
  ///
  /// In ja, this message translates to:
  /// **'レイヤー'**
  String get layerPanelTitle;

  /// No description provided for @layerPanelHelpTooltip.
  ///
  /// In ja, this message translates to:
  /// **'ヘルプ'**
  String get layerPanelHelpTooltip;

  /// No description provided for @layerPanelSearchHint.
  ///
  /// In ja, this message translates to:
  /// **'レイヤー名で検索'**
  String get layerPanelSearchHint;

  /// No description provided for @layerPanelSelectAll.
  ///
  /// In ja, this message translates to:
  /// **'全選択'**
  String get layerPanelSelectAll;

  /// No description provided for @layerPanelDeselectAll.
  ///
  /// In ja, this message translates to:
  /// **'全解除'**
  String get layerPanelDeselectAll;

  /// No description provided for @layerPanelNewLayerButton.
  ///
  /// In ja, this message translates to:
  /// **'新規レイヤー'**
  String get layerPanelNewLayerButton;

  /// No description provided for @layerPanelNewFolderButton.
  ///
  /// In ja, this message translates to:
  /// **'新規フォルダ'**
  String get layerPanelNewFolderButton;

  /// No description provided for @layerPanelImportImageButton.
  ///
  /// In ja, this message translates to:
  /// **'画像読み込み'**
  String get layerPanelImportImageButton;

  /// No description provided for @layerPanelDefaultLayerName.
  ///
  /// In ja, this message translates to:
  /// **'レイヤー{n}'**
  String layerPanelDefaultLayerName(int n);

  /// No description provided for @layerPanelDefaultFolderName.
  ///
  /// In ja, this message translates to:
  /// **'フォルダ{n}'**
  String layerPanelDefaultFolderName(int n);

  /// No description provided for @layerPanelDefaultLineartName.
  ///
  /// In ja, this message translates to:
  /// **'線画{n}'**
  String layerPanelDefaultLineartName(int n);

  /// No description provided for @layerPanelDefaultAutofillName.
  ///
  /// In ja, this message translates to:
  /// **'自動塗り{n}'**
  String layerPanelDefaultAutofillName(int n);

  /// No description provided for @layerPanelDefaultCommonName.
  ///
  /// In ja, this message translates to:
  /// **'共通{n}'**
  String layerPanelDefaultCommonName(int n);

  /// No description provided for @layerPanelDefaultSelectionName.
  ///
  /// In ja, this message translates to:
  /// **'選択{n}'**
  String layerPanelDefaultSelectionName(int n);

  /// No description provided for @layerPanelClippingBadge.
  ///
  /// In ja, this message translates to:
  /// **'クリッピング'**
  String get layerPanelClippingBadge;

  /// No description provided for @layerPanelAddTooltip.
  ///
  /// In ja, this message translates to:
  /// **'追加'**
  String get layerPanelAddTooltip;

  /// No description provided for @layerPanelAutofillMarkTooltip.
  ///
  /// In ja, this message translates to:
  /// **'線画が更新されました。タップすると自動塗りを最新の状態に更新できます。'**
  String get layerPanelAutofillMarkTooltip;

  /// No description provided for @layerPanelRangeAllFrames.
  ///
  /// In ja, this message translates to:
  /// **'全フレーム'**
  String get layerPanelRangeAllFrames;

  /// No description provided for @layerPanelRangeCurrentScene.
  ///
  /// In ja, this message translates to:
  /// **'現在シーン'**
  String get layerPanelRangeCurrentScene;

  /// No description provided for @layerPanelRangeSceneSpecified.
  ///
  /// In ja, this message translates to:
  /// **'シーン指定'**
  String get layerPanelRangeSceneSpecified;

  /// No description provided for @layerPanelRangeFrameSpan.
  ///
  /// In ja, this message translates to:
  /// **'{start}〜{end}'**
  String layerPanelRangeFrameSpan(int start, int end);

  /// No description provided for @layerPanelMenuFrameRangeChange.
  ///
  /// In ja, this message translates to:
  /// **'表示フレーム範囲変更'**
  String get layerPanelMenuFrameRangeChange;

  /// No description provided for @layerPanelMenuRangeChange.
  ///
  /// In ja, this message translates to:
  /// **'表示範囲変更'**
  String get layerPanelMenuRangeChange;

  /// No description provided for @layerPanelMenuPartAssign.
  ///
  /// In ja, this message translates to:
  /// **'パーツ設定'**
  String get layerPanelMenuPartAssign;

  /// No description provided for @layerPanelMenuRunAutofill.
  ///
  /// In ja, this message translates to:
  /// **'自動塗り実行'**
  String get layerPanelMenuRunAutofill;

  /// No description provided for @layerPanelMenuOrphanFill.
  ///
  /// In ja, this message translates to:
  /// **'最新の色で塗りつぶす'**
  String get layerPanelMenuOrphanFill;

  /// No description provided for @layerPanelMenuOrphanFillSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'対応する線画レイヤーが見つからないため色更新のみ実行します'**
  String get layerPanelMenuOrphanFillSubtitle;

  /// No description provided for @layerPanelMenuReplaceMaterial.
  ///
  /// In ja, this message translates to:
  /// **'素材差し替え'**
  String get layerPanelMenuReplaceMaterial;

  /// No description provided for @layerPanelDeleteConfirmTitle.
  ///
  /// In ja, this message translates to:
  /// **'{name}を削除しますか？'**
  String layerPanelDeleteConfirmTitle(String name);

  /// No description provided for @layerPanelDeleteConfirmBody.
  ///
  /// In ja, this message translates to:
  /// **'この素材の表示範囲内のすべてのフレームから削除されます。'**
  String get layerPanelDeleteConfirmBody;

  /// No description provided for @layerPanelCommonDeleteMidDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'{name}の表示範囲を変更しますか？'**
  String layerPanelCommonDeleteMidDialogTitle(String name);

  /// No description provided for @layerPanelCommonDeleteMidDialogBody.
  ///
  /// In ja, this message translates to:
  /// **'共通レイヤーの表示範囲は連続した1区間でしか設定できないため、範囲の途中のフレームでは削除できません。代わりに、このフレームより前と後のどちらを残すか選んでください。'**
  String get layerPanelCommonDeleteMidDialogBody;

  /// No description provided for @layerPanelCommonDeleteKeepBeforeButton.
  ///
  /// In ja, this message translates to:
  /// **'これより前を残す'**
  String get layerPanelCommonDeleteKeepBeforeButton;

  /// No description provided for @layerPanelCommonDeleteKeepAfterButton.
  ///
  /// In ja, this message translates to:
  /// **'これより後を残す'**
  String get layerPanelCommonDeleteKeepAfterButton;

  /// No description provided for @layerPanelRangeDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'表示範囲'**
  String get layerPanelRangeDialogTitle;

  /// No description provided for @layerPanelRangeStartFrameLabel.
  ///
  /// In ja, this message translates to:
  /// **'開始フレーム'**
  String get layerPanelRangeStartFrameLabel;

  /// No description provided for @layerPanelRangeEndFrameLabel.
  ///
  /// In ja, this message translates to:
  /// **'終了フレーム'**
  String get layerPanelRangeEndFrameLabel;

  /// No description provided for @layerPanelRangeTilde.
  ///
  /// In ja, this message translates to:
  /// **'〜'**
  String get layerPanelRangeTilde;

  /// No description provided for @layerPanelRangeUseCurrentButton.
  ///
  /// In ja, this message translates to:
  /// **'現在範囲を使用'**
  String get layerPanelRangeUseCurrentButton;

  /// No description provided for @layerPanelRangeTargetSceneLabel.
  ///
  /// In ja, this message translates to:
  /// **'対象シーン'**
  String get layerPanelRangeTargetSceneLabel;

  /// No description provided for @layerPanelRangeFrameRangeLabel.
  ///
  /// In ja, this message translates to:
  /// **'フレーム範囲指定'**
  String get layerPanelRangeFrameRangeLabel;

  /// No description provided for @layerPanelMenuNormalLayer.
  ///
  /// In ja, this message translates to:
  /// **'通常レイヤー'**
  String get layerPanelMenuNormalLayer;

  /// No description provided for @layerPanelMenuCommonLayer.
  ///
  /// In ja, this message translates to:
  /// **'共通レイヤー'**
  String get layerPanelMenuCommonLayer;

  /// No description provided for @layerPanelMenuLineartLayer.
  ///
  /// In ja, this message translates to:
  /// **'自動塗り用線画レイヤー'**
  String get layerPanelMenuLineartLayer;

  /// No description provided for @layerPanelMenuAutofillLayer.
  ///
  /// In ja, this message translates to:
  /// **'自動塗りレイヤー'**
  String get layerPanelMenuAutofillLayer;

  /// No description provided for @layerPanelMenuSelectionLayer.
  ///
  /// In ja, this message translates to:
  /// **'選択レイヤー'**
  String get layerPanelMenuSelectionLayer;

  /// No description provided for @layerPanelOpacityLabel.
  ///
  /// In ja, this message translates to:
  /// **'不透明度'**
  String get layerPanelOpacityLabel;

  /// No description provided for @layerPanelLockLabel.
  ///
  /// In ja, this message translates to:
  /// **'ロック'**
  String get layerPanelLockLabel;

  /// No description provided for @layerPanelOpacityLockLabel.
  ///
  /// In ja, this message translates to:
  /// **'不透明度ロック'**
  String get layerPanelOpacityLockLabel;

  /// No description provided for @layerPanelClippingDescription.
  ///
  /// In ja, this message translates to:
  /// **'下のレイヤーの不透明範囲内のみ描画'**
  String get layerPanelClippingDescription;

  /// No description provided for @layerPanelConvertToCommonLabel.
  ///
  /// In ja, this message translates to:
  /// **'共通レイヤーへ変更'**
  String get layerPanelConvertToCommonLabel;

  /// No description provided for @layerPanelConvertOption1Title.
  ///
  /// In ja, this message translates to:
  /// **'現在レイヤーを共通化'**
  String get layerPanelConvertOption1Title;

  /// No description provided for @layerPanelConvertOption1Subtitle.
  ///
  /// In ja, this message translates to:
  /// **'このレイヤーのみを共通レイヤーとして設定します'**
  String get layerPanelConvertOption1Subtitle;

  /// No description provided for @layerPanelConvertOption2Title.
  ///
  /// In ja, this message translates to:
  /// **'表示中レイヤーを複製して全統合して共通化'**
  String get layerPanelConvertOption2Title;

  /// No description provided for @layerPanelConvertOption2Subtitle.
  ///
  /// In ja, this message translates to:
  /// **'表示中のすべてのレイヤーを統合した結果を共通レイヤーとして作成します'**
  String get layerPanelConvertOption2Subtitle;

  /// No description provided for @layerPanelCommonRangeTitle.
  ///
  /// In ja, this message translates to:
  /// **'共通レイヤー範囲'**
  String get layerPanelCommonRangeTitle;

  /// No description provided for @layerPanelHelpDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'レイヤーについて'**
  String get layerPanelHelpDialogTitle;

  /// No description provided for @layerPanelHelpBlendModeBody.
  ///
  /// In ja, this message translates to:
  /// **'レイヤーの合成方法を変更します。乗算・スクリーン・オーバーレイなどがあります。'**
  String get layerPanelHelpBlendModeBody;

  /// No description provided for @layerPanelHelpClippingBody.
  ///
  /// In ja, this message translates to:
  /// **'下のレイヤーの不透明ピクセル範囲内のみ描画します。描画範囲を制御したい場合はこちらを使用してください。'**
  String get layerPanelHelpClippingBody;

  /// No description provided for @layerPanelCommonLayerLabel.
  ///
  /// In ja, this message translates to:
  /// **'共通レイヤー'**
  String get layerPanelCommonLayerLabel;

  /// No description provided for @layerPanelHelpCommonLayerBody.
  ///
  /// In ja, this message translates to:
  /// **'複数のフレームで同じ内容を共有するレイヤーです。表示するフレーム範囲を設定できます。'**
  String get layerPanelHelpCommonLayerBody;

  /// No description provided for @layerPanelAutofillMethodTitle.
  ///
  /// In ja, this message translates to:
  /// **'自動塗り方法'**
  String get layerPanelAutofillMethodTitle;

  /// No description provided for @layerPanelAutofillNoLineartSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'対応する自動塗り用線画レイヤーが見つかりません。'**
  String get layerPanelAutofillNoLineartSnackbar;

  /// No description provided for @layerPanelAutofillNote1.
  ///
  /// In ja, this message translates to:
  /// **'※ プロジェクト内で自動塗りを初回実行する場合はどちらを選んでも問題ありません。'**
  String get layerPanelAutofillNote1;

  /// No description provided for @layerPanelAutofillNote2.
  ///
  /// In ja, this message translates to:
  /// **'※ 自動塗りレイヤーが存在しない場合は、一から領域を判定して自動塗りします。'**
  String get layerPanelAutofillNote2;

  /// No description provided for @layerPanelAutofillRepaintTitle.
  ///
  /// In ja, this message translates to:
  /// **'塗りなおし'**
  String get layerPanelAutofillRepaintTitle;

  /// No description provided for @layerPanelAutofillRepaintHint.
  ///
  /// In ja, this message translates to:
  /// **'誤って自動塗りの形状を変えてしまった場合におすすめ'**
  String get layerPanelAutofillRepaintHint;

  /// No description provided for @layerPanelAutofillRepaintNote.
  ///
  /// In ja, this message translates to:
  /// **'※ 一から領域を判定して塗りなおします。現在の自動塗りレイヤーの形状は破棄されます。'**
  String get layerPanelAutofillRepaintNote;

  /// No description provided for @layerPanelAutofillColorUpdateTitle.
  ///
  /// In ja, this message translates to:
  /// **'色更新'**
  String get layerPanelAutofillColorUpdateTitle;

  /// No description provided for @layerPanelAutofillColorUpdateHint.
  ///
  /// In ja, this message translates to:
  /// **'自動塗りの形状を手動で調整した場合におすすめ'**
  String get layerPanelAutofillColorUpdateHint;

  /// No description provided for @layerPanelAutofillColorUpdateNote.
  ///
  /// In ja, this message translates to:
  /// **'※ 不透明度ロックをして最新の色で塗りつぶします。現在の自動塗りレイヤーの形状は維持されます。'**
  String get layerPanelAutofillColorUpdateNote;

  /// No description provided for @layerPanelExecuteButton.
  ///
  /// In ja, this message translates to:
  /// **'実行'**
  String get layerPanelExecuteButton;

  /// No description provided for @layerPanelAutofillPartMissingSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'パーツが未設定です。「パーツ設定」から設定してください。'**
  String get layerPanelAutofillPartMissingSnackbar;

  /// No description provided for @layerPanelAutofillPresetMissingSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'対応する自動塗り設定のパーツが見つかりません。'**
  String get layerPanelAutofillPresetMissingSnackbar;

  /// No description provided for @layerPanelOrphanFillSuccessSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'対応する線画レイヤーが見つからないため、最新の色で塗りつぶしました。'**
  String get layerPanelOrphanFillSuccessSnackbar;

  /// No description provided for @layerPanelOrphanFillFailSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'パーツが未設定、または塗り形状がないため処理できませんでした。'**
  String get layerPanelOrphanFillFailSnackbar;

  /// No description provided for @layerPanelAutofillUpdateHelpTitle.
  ///
  /// In ja, this message translates to:
  /// **'自動塗り更新マーク'**
  String get layerPanelAutofillUpdateHelpTitle;

  /// No description provided for @layerPanelAutofillUpdateHelpBody.
  ///
  /// In ja, this message translates to:
  /// **'現在の自動塗りは最新ではありません。タップすると更新できます。'**
  String get layerPanelAutofillUpdateHelpBody;

  /// No description provided for @layerPanelReplaceMaterialSuccessSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'素材を差し替えました: {name}'**
  String layerPanelReplaceMaterialSuccessSnackbar(String name);

  /// No description provided for @layerPanelImportImageSuccessSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'画像を読み込みました: {name}'**
  String layerPanelImportImageSuccessSnackbar(String name);

  /// No description provided for @layerPanelCopySuffix.
  ///
  /// In ja, this message translates to:
  /// **'{name}のコピー'**
  String layerPanelCopySuffix(String name);

  /// No description provided for @timelineFullscreenPreviewCloseTooltip.
  ///
  /// In ja, this message translates to:
  /// **'全画面プレビューを閉じる'**
  String get timelineFullscreenPreviewCloseTooltip;

  /// No description provided for @timelineDefaultProjectName.
  ///
  /// In ja, this message translates to:
  /// **'プロジェクト名'**
  String get timelineDefaultProjectName;

  /// No description provided for @timelinePreviewPlaceholder.
  ///
  /// In ja, this message translates to:
  /// **'プレビュー'**
  String get timelinePreviewPlaceholder;

  /// No description provided for @timelinePreviewFullscreenTip.
  ///
  /// In ja, this message translates to:
  /// **'タップするとプレビューを全画面表示できます。仕上がりの確認に便利です。'**
  String get timelinePreviewFullscreenTip;

  /// No description provided for @timelinePreviewFullscreenTooltip.
  ///
  /// In ja, this message translates to:
  /// **'プレビューを全画面表示'**
  String get timelinePreviewFullscreenTooltip;

  /// No description provided for @timelineAddVideoTooltip.
  ///
  /// In ja, this message translates to:
  /// **'＋動画'**
  String get timelineAddVideoTooltip;

  /// No description provided for @timelineAddAudioTooltip.
  ///
  /// In ja, this message translates to:
  /// **'＋音源'**
  String get timelineAddAudioTooltip;

  /// No description provided for @timelineEffectFilterLabel.
  ///
  /// In ja, this message translates to:
  /// **'演出フィルター'**
  String get timelineEffectFilterLabel;

  /// No description provided for @timelineAddCameraKfTooltip.
  ///
  /// In ja, this message translates to:
  /// **'カメラキーフレーム追加'**
  String get timelineAddCameraKfTooltip;

  /// No description provided for @timelineAddWatermarkTooltip.
  ///
  /// In ja, this message translates to:
  /// **'＋ウォーターマーク'**
  String get timelineAddWatermarkTooltip;

  /// No description provided for @timelineWatermarkNotRegisteredTitle.
  ///
  /// In ja, this message translates to:
  /// **'ウォーターマーク未登録'**
  String get timelineWatermarkNotRegisteredTitle;

  /// No description provided for @timelineWatermarkNotRegisteredBody.
  ///
  /// In ja, this message translates to:
  /// **'設定画面の「ウォーターマーク」からあらかじめ画像または文字を登録してください。'**
  String get timelineWatermarkNotRegisteredBody;

  /// No description provided for @timelineOpenSettingsButton.
  ///
  /// In ja, this message translates to:
  /// **'設定を開く'**
  String get timelineOpenSettingsButton;

  /// No description provided for @timelineWatermarkSelectTitle.
  ///
  /// In ja, this message translates to:
  /// **'ウォーターマークを選択'**
  String get timelineWatermarkSelectTitle;

  /// No description provided for @timelineWatermarkAddedSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'ウォーターマークを追加しました（全フレームに表示されます）: {name}'**
  String timelineWatermarkAddedSnackbar(String name);

  /// No description provided for @timelineWatermarkEditTitle.
  ///
  /// In ja, this message translates to:
  /// **'ウォーターマークを編集'**
  String get timelineWatermarkEditTitle;

  /// No description provided for @timelineWatermarkAngleLabel.
  ///
  /// In ja, this message translates to:
  /// **'角度'**
  String get timelineWatermarkAngleLabel;

  /// No description provided for @timelineWatermarkSizeLabel.
  ///
  /// In ja, this message translates to:
  /// **'大きさ'**
  String get timelineWatermarkSizeLabel;

  /// No description provided for @timelineWatermarkOpacityLabel.
  ///
  /// In ja, this message translates to:
  /// **'不透明度'**
  String get timelineWatermarkOpacityLabel;

  /// No description provided for @timelineWatermarkLoopLabel.
  ///
  /// In ja, this message translates to:
  /// **'常時表示（ループ表示）'**
  String get timelineWatermarkLoopLabel;

  /// No description provided for @timelineWatermarkLoopSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'オフにすると現在のシーンのみに表示されます'**
  String get timelineWatermarkLoopSubtitle;

  /// No description provided for @timelineConfirmButton.
  ///
  /// In ja, this message translates to:
  /// **'決定'**
  String get timelineConfirmButton;

  /// No description provided for @timelineClipSelectDoneButton.
  ///
  /// In ja, this message translates to:
  /// **'完了'**
  String get timelineClipSelectDoneButton;

  /// No description provided for @timelineClipOverlapDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'既存のクリップと重なります'**
  String get timelineClipOverlapDialogTitle;

  /// No description provided for @timelineClipOverlapDialogBody.
  ///
  /// In ja, this message translates to:
  /// **'貼り付け先が既存のクリップと重なっています。どのように配置しますか？'**
  String get timelineClipOverlapDialogBody;

  /// No description provided for @timelineClipOverlapPlaceBefore.
  ///
  /// In ja, this message translates to:
  /// **'前に配置する'**
  String get timelineClipOverlapPlaceBefore;

  /// No description provided for @timelineClipOverlapPlaceAfter.
  ///
  /// In ja, this message translates to:
  /// **'後ろに配置する'**
  String get timelineClipOverlapPlaceAfter;

  /// No description provided for @timelineClipOverlapPlaceNewRow.
  ///
  /// In ja, this message translates to:
  /// **'重ねて配置する（行を増やす）'**
  String get timelineClipOverlapPlaceNewRow;

  /// No description provided for @timelineSceneRenameTitle.
  ///
  /// In ja, this message translates to:
  /// **'シーン名変更'**
  String get timelineSceneRenameTitle;

  /// No description provided for @timelineSceneDeleteMenuItem.
  ///
  /// In ja, this message translates to:
  /// **'シーン削除'**
  String get timelineSceneDeleteMenuItem;

  /// No description provided for @timelineDurationLimitTitle.
  ///
  /// In ja, this message translates to:
  /// **'長さの上限に達します'**
  String get timelineDurationLimitTitle;

  /// No description provided for @timelineDurationLimitBodyFree.
  ///
  /// In ja, this message translates to:
  /// **'無料会員は動画の長さが最大90秒までです。これ以上フレームを追加・複製すると90秒を超えてしまうため、実行できません。プレミアム会員になると最大2時間まで作成できます。'**
  String get timelineDurationLimitBodyFree;

  /// No description provided for @timelineDurationLimitBodyPremium.
  ///
  /// In ja, this message translates to:
  /// **'プレミアム会員の上限（最大2時間）を超えてしまうため、これ以上フレームを追加・複製できません。'**
  String get timelineDurationLimitBodyPremium;

  /// No description provided for @timelineSceneDeleteConfirmTitle.
  ///
  /// In ja, this message translates to:
  /// **'「{name}」を削除しますか？'**
  String timelineSceneDeleteConfirmTitle(String name);

  /// No description provided for @timelineSceneDeleteConfirmBody.
  ///
  /// In ja, this message translates to:
  /// **'シーン内の全フレーム・共通レイヤー・動画素材・画像素材・ウォーターマークを含むすべてのデータが削除されます。'**
  String get timelineSceneDeleteConfirmBody;

  /// No description provided for @timelineSceneMultiDeleteConfirmTitle.
  ///
  /// In ja, this message translates to:
  /// **'選択中の{count}件のシーンを削除しますか？'**
  String timelineSceneMultiDeleteConfirmTitle(int count);

  /// No description provided for @timelineAutofillUpdateHelpBody.
  ///
  /// In ja, this message translates to:
  /// **'このシーン・フレームには最新ではない自動塗りレイヤーが含まれています。レイヤーパネルで対象レイヤーをタップすると更新できます。'**
  String get timelineAutofillUpdateHelpBody;

  /// No description provided for @timelineFrameTrackLabel.
  ///
  /// In ja, this message translates to:
  /// **'フレーム'**
  String get timelineFrameTrackLabel;

  /// No description provided for @timelineTrackRowRenameTitle.
  ///
  /// In ja, this message translates to:
  /// **'行名を変更'**
  String get timelineTrackRowRenameTitle;

  /// No description provided for @timelineCameraTrackLabel.
  ///
  /// In ja, this message translates to:
  /// **'カメラ'**
  String get timelineCameraTrackLabel;

  /// No description provided for @timelineRangeSceneFixed.
  ///
  /// In ja, this message translates to:
  /// **'シーン固定'**
  String get timelineRangeSceneFixed;

  /// No description provided for @timelineEndCardDefaultLogoLabel.
  ///
  /// In ja, this message translates to:
  /// **'NIARIMロゴ'**
  String get timelineEndCardDefaultLogoLabel;

  /// No description provided for @timelineEndCardHiddenLabel.
  ///
  /// In ja, this message translates to:
  /// **'非表示'**
  String get timelineEndCardHiddenLabel;

  /// No description provided for @timelineEndCardTrackLabel.
  ///
  /// In ja, this message translates to:
  /// **'エンドカードトラック'**
  String get timelineEndCardTrackLabel;

  /// No description provided for @timelineMarkerTrackLabel.
  ///
  /// In ja, this message translates to:
  /// **'タイムスタンプ'**
  String get timelineMarkerTrackLabel;

  /// No description provided for @timelineMarkerAddDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'F{n} にタイムスタンプを追加'**
  String timelineMarkerAddDialogTitle(int n);

  /// No description provided for @timelineMarkerEditDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'タイムスタンプ: F{n}'**
  String timelineMarkerEditDialogTitle(int n);

  /// No description provided for @timelineMarkerCommentHint.
  ///
  /// In ja, this message translates to:
  /// **'コメント（例：ここで口パク「あ」）'**
  String get timelineMarkerCommentHint;

  /// No description provided for @timelineAddClipDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'{trackName}クリップを追加'**
  String timelineAddClipDialogTitle(String trackName);

  /// No description provided for @timelineClipLabelFieldLabel.
  ///
  /// In ja, this message translates to:
  /// **'ラベル'**
  String get timelineClipLabelFieldLabel;

  /// No description provided for @timelineClipStartLabel.
  ///
  /// In ja, this message translates to:
  /// **'開始:'**
  String get timelineClipStartLabel;

  /// No description provided for @timelineClipLengthLabel.
  ///
  /// In ja, this message translates to:
  /// **'長さ:'**
  String get timelineClipLengthLabel;

  /// No description provided for @timelineAutofillNote2.
  ///
  /// In ja, this message translates to:
  /// **'※ 自動塗りレイヤーのみ存在する場合は、一から領域を判定して自動塗りします。'**
  String get timelineAutofillNote2;

  /// No description provided for @timelineAutofillTargetLabel.
  ///
  /// In ja, this message translates to:
  /// **'実行対象'**
  String get timelineAutofillTargetLabel;

  /// No description provided for @timelineAutofillScopeCurrentFrame.
  ///
  /// In ja, this message translates to:
  /// **'現在のフレームのみ'**
  String get timelineAutofillScopeCurrentFrame;

  /// No description provided for @timelineAutofillScopeCurrentScene.
  ///
  /// In ja, this message translates to:
  /// **'シーン単位（現在のシーンの全フレーム）'**
  String get timelineAutofillScopeCurrentScene;

  /// No description provided for @timelineAutofillScopeAllScenes.
  ///
  /// In ja, this message translates to:
  /// **'全フレーム（プロジェクト全体）'**
  String get timelineAutofillScopeAllScenes;

  /// No description provided for @timelineAutofillProgressTitle.
  ///
  /// In ja, this message translates to:
  /// **'自動塗り実行中'**
  String get timelineAutofillProgressTitle;

  /// No description provided for @timelineAutofillProgressSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'{count}フレーム'**
  String timelineAutofillProgressSubtitle(int count);

  /// No description provided for @timelineAutofillCompleteSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'自動塗りが完了しました（{count}件処理）'**
  String timelineAutofillCompleteSnackbar(int count);

  /// No description provided for @timelineEffectTypeFade.
  ///
  /// In ja, this message translates to:
  /// **'フェード'**
  String get timelineEffectTypeFade;

  /// No description provided for @timelineEffectTypeGaussianBlur.
  ///
  /// In ja, this message translates to:
  /// **'ガウスぼかし'**
  String get timelineEffectTypeGaussianBlur;

  /// No description provided for @timelineEffectTypeLensBlur.
  ///
  /// In ja, this message translates to:
  /// **'レンズぼかし'**
  String get timelineEffectTypeLensBlur;

  /// No description provided for @timelineEffectTypeMosaic.
  ///
  /// In ja, this message translates to:
  /// **'モザイク'**
  String get timelineEffectTypeMosaic;

  /// No description provided for @timelineEffectTypeChromaticAberration.
  ///
  /// In ja, this message translates to:
  /// **'色収差'**
  String get timelineEffectTypeChromaticAberration;

  /// No description provided for @timelineEffectTypeNoise.
  ///
  /// In ja, this message translates to:
  /// **'ノイズ'**
  String get timelineEffectTypeNoise;

  /// No description provided for @timelineEffectTypeSepia.
  ///
  /// In ja, this message translates to:
  /// **'セピア'**
  String get timelineEffectTypeSepia;

  /// No description provided for @timelineEffectTypeAnimeStyle.
  ///
  /// In ja, this message translates to:
  /// **'アニメ調'**
  String get timelineEffectTypeAnimeStyle;

  /// No description provided for @timelineEffectTypeRetroAnime.
  ///
  /// In ja, this message translates to:
  /// **'レトロアニメ'**
  String get timelineEffectTypeRetroAnime;

  /// No description provided for @timelineEffectTypeCrt.
  ///
  /// In ja, this message translates to:
  /// **'ブラウン管'**
  String get timelineEffectTypeCrt;

  /// No description provided for @timelineEffectTypeAnimatedNoise.
  ///
  /// In ja, this message translates to:
  /// **'動くノイズ'**
  String get timelineEffectTypeAnimatedNoise;

  /// No description provided for @timelineEffectTypeRain.
  ///
  /// In ja, this message translates to:
  /// **'雨'**
  String get timelineEffectTypeRain;

  /// No description provided for @timelineEffectFilterEmptyState.
  ///
  /// In ja, this message translates to:
  /// **'フィルターがありません\n＋追加ボタンで追加してください'**
  String get timelineEffectFilterEmptyState;

  /// No description provided for @timelineRangeStartLabel.
  ///
  /// In ja, this message translates to:
  /// **'開始'**
  String get timelineRangeStartLabel;

  /// No description provided for @timelineRangeEndLabel.
  ///
  /// In ja, this message translates to:
  /// **'終了'**
  String get timelineRangeEndLabel;

  /// No description provided for @timelineEffectSizeLabel.
  ///
  /// In ja, this message translates to:
  /// **'サイズ'**
  String get timelineEffectSizeLabel;

  /// No description provided for @timelineEffectStrengthLabel.
  ///
  /// In ja, this message translates to:
  /// **'強度'**
  String get timelineEffectStrengthLabel;

  /// No description provided for @timelineEffectAmountLabel.
  ///
  /// In ja, this message translates to:
  /// **'量'**
  String get timelineEffectAmountLabel;

  /// No description provided for @timelineEffectGrainSizeLabel.
  ///
  /// In ja, this message translates to:
  /// **'粒の大きさ'**
  String get timelineEffectGrainSizeLabel;

  /// No description provided for @timelineEffectRainIntensityLabel.
  ///
  /// In ja, this message translates to:
  /// **'降り方'**
  String get timelineEffectRainIntensityLabel;

  /// No description provided for @timelineEffectRainSpeedLabel.
  ///
  /// In ja, this message translates to:
  /// **'速さ'**
  String get timelineEffectRainSpeedLabel;

  /// No description provided for @timelineEffectRainSizeLabel.
  ///
  /// In ja, this message translates to:
  /// **'粒の大きさ'**
  String get timelineEffectRainSizeLabel;

  /// No description provided for @timelineEffectWindAngleLabel.
  ///
  /// In ja, this message translates to:
  /// **'風向き'**
  String get timelineEffectWindAngleLabel;

  /// No description provided for @timelineColorLabel.
  ///
  /// In ja, this message translates to:
  /// **'色'**
  String get timelineColorLabel;

  /// No description provided for @timelineColorBlack.
  ///
  /// In ja, this message translates to:
  /// **'黒'**
  String get timelineColorBlack;

  /// No description provided for @timelineColorWhite.
  ///
  /// In ja, this message translates to:
  /// **'白'**
  String get timelineColorWhite;

  /// No description provided for @timelineColorCustom.
  ///
  /// In ja, this message translates to:
  /// **'カスタム'**
  String get timelineColorCustom;

  /// No description provided for @timelineFadeColorDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'フェードカラー'**
  String get timelineFadeColorDialogTitle;

  /// No description provided for @timelineAddFilterDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'フィルターを追加'**
  String get timelineAddFilterDialogTitle;

  /// No description provided for @timelineClipVolumeLabel.
  ///
  /// In ja, this message translates to:
  /// **'音量'**
  String get timelineClipVolumeLabel;

  /// No description provided for @timelineClipFadeInLabel.
  ///
  /// In ja, this message translates to:
  /// **'フェードイン'**
  String get timelineClipFadeInLabel;

  /// No description provided for @timelineClipFadeOutLabel.
  ///
  /// In ja, this message translates to:
  /// **'フェードアウト'**
  String get timelineClipFadeOutLabel;

  /// No description provided for @timelineClipUseStartLabel.
  ///
  /// In ja, this message translates to:
  /// **'使用開始F'**
  String get timelineClipUseStartLabel;

  /// No description provided for @timelineClipUseEndLabel.
  ///
  /// In ja, this message translates to:
  /// **'使用終了F'**
  String get timelineClipUseEndLabel;

  /// No description provided for @timelineCameraKfTitle.
  ///
  /// In ja, this message translates to:
  /// **'カメラ KF: F{n}'**
  String timelineCameraKfTitle(int n);

  /// No description provided for @timelineCameraMoveXLabel.
  ///
  /// In ja, this message translates to:
  /// **'X 移動'**
  String get timelineCameraMoveXLabel;

  /// No description provided for @timelineCameraMoveYLabel.
  ///
  /// In ja, this message translates to:
  /// **'Y 移動'**
  String get timelineCameraMoveYLabel;

  /// No description provided for @timelineCameraZoomLabel.
  ///
  /// In ja, this message translates to:
  /// **'ズーム'**
  String get timelineCameraZoomLabel;

  /// No description provided for @timelineCameraRotationLabel.
  ///
  /// In ja, this message translates to:
  /// **'回転'**
  String get timelineCameraRotationLabel;

  /// No description provided for @layerPanelKeyframeLabel.
  ///
  /// In ja, this message translates to:
  /// **'アニメーション（キーフレーム）'**
  String get layerPanelKeyframeLabel;

  /// No description provided for @layerKeyframeSheetTitle.
  ///
  /// In ja, this message translates to:
  /// **'{name} のキーフレーム'**
  String layerKeyframeSheetTitle(String name);

  /// No description provided for @layerKeyframeSheetDesc.
  ///
  /// In ja, this message translates to:
  /// **'このレイヤーの位置・拡大縮小・回転をフレームごとに指定し、キーフレーム間を自動で補間します。レイヤーの絵自体は変わりません。'**
  String get layerKeyframeSheetDesc;

  /// No description provided for @layerKeyframeAddAtCurrentFrame.
  ///
  /// In ja, this message translates to:
  /// **'現在のフレーム（F{n}）に追加'**
  String layerKeyframeAddAtCurrentFrame(int n);

  /// No description provided for @layerKeyframeEmpty.
  ///
  /// In ja, this message translates to:
  /// **'キーフレームがありません。上のボタンから追加してください。'**
  String get layerKeyframeEmpty;

  /// No description provided for @layerKeyframeScaleShort.
  ///
  /// In ja, this message translates to:
  /// **'倍率'**
  String get layerKeyframeScaleShort;

  /// No description provided for @layerKeyframeRotationShort.
  ///
  /// In ja, this message translates to:
  /// **'回転'**
  String get layerKeyframeRotationShort;

  /// No description provided for @layerKeyframeEditTitle.
  ///
  /// In ja, this message translates to:
  /// **'キーフレーム: F{n}'**
  String layerKeyframeEditTitle(int n);

  /// No description provided for @layerKeyframeFrameLabel.
  ///
  /// In ja, this message translates to:
  /// **'フレーム'**
  String get layerKeyframeFrameLabel;

  /// No description provided for @layerKeyframeScaleLabel.
  ///
  /// In ja, this message translates to:
  /// **'拡大縮小'**
  String get layerKeyframeScaleLabel;

  /// No description provided for @layerKeyframeRotationLabel.
  ///
  /// In ja, this message translates to:
  /// **'回転'**
  String get layerKeyframeRotationLabel;

  /// No description provided for @layerKeyframeEasingLabel.
  ///
  /// In ja, this message translates to:
  /// **'次のキーフレームへのつなぎ方'**
  String get layerKeyframeEasingLabel;

  /// No description provided for @layerKeyframeEasingLinear.
  ///
  /// In ja, this message translates to:
  /// **'等速'**
  String get layerKeyframeEasingLinear;

  /// No description provided for @layerKeyframeEasingEaseIn.
  ///
  /// In ja, this message translates to:
  /// **'ゆっくり始まる'**
  String get layerKeyframeEasingEaseIn;

  /// No description provided for @layerKeyframeEasingEaseOut.
  ///
  /// In ja, this message translates to:
  /// **'ゆっくり終わる'**
  String get layerKeyframeEasingEaseOut;

  /// No description provided for @layerKeyframeEasingEaseInOut.
  ///
  /// In ja, this message translates to:
  /// **'ゆっくり始まって終わる'**
  String get layerKeyframeEasingEaseInOut;

  /// No description provided for @layerKeyframeEasingBounceOut.
  ///
  /// In ja, this message translates to:
  /// **'弾む'**
  String get layerKeyframeEasingBounceOut;

  /// No description provided for @layerPanelGroupTooltip.
  ///
  /// In ja, this message translates to:
  /// **'グループ化'**
  String get layerPanelGroupTooltip;

  /// No description provided for @layerPanelShowSelectedTooltip.
  ///
  /// In ja, this message translates to:
  /// **'選択中のレイヤーを全て表示'**
  String get layerPanelShowSelectedTooltip;

  /// No description provided for @layerPanelHideSelectedTooltip.
  ///
  /// In ja, this message translates to:
  /// **'選択中のレイヤーを全て非表示'**
  String get layerPanelHideSelectedTooltip;

  /// No description provided for @layerPanelGroupDefaultName.
  ///
  /// In ja, this message translates to:
  /// **'新規グループ'**
  String get layerPanelGroupDefaultName;

  /// No description provided for @layerPanelGroupMembershipLabel.
  ///
  /// In ja, this message translates to:
  /// **'グループ: {name}'**
  String layerPanelGroupMembershipLabel(String name);

  /// No description provided for @layerPanelGroupLeaveAction.
  ///
  /// In ja, this message translates to:
  /// **'解除'**
  String get layerPanelGroupLeaveAction;

  /// No description provided for @frameStripHoldDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'F{n} 保持セル数'**
  String frameStripHoldDialogTitle(int n);

  /// No description provided for @frameStripFrameListModeLabel.
  ///
  /// In ja, this message translates to:
  /// **'フレーム一覧'**
  String get frameStripFrameListModeLabel;

  /// No description provided for @frameStripTimelineModeLabel.
  ///
  /// In ja, this message translates to:
  /// **'タイムライン'**
  String get frameStripTimelineModeLabel;

  /// No description provided for @progressDialogAdLoading.
  ///
  /// In ja, this message translates to:
  /// **'広告読み込み中…'**
  String get progressDialogAdLoading;

  /// No description provided for @adMockPlaceholderLabel.
  ///
  /// In ja, this message translates to:
  /// **'広告バナー（配置検討用モック）'**
  String get adMockPlaceholderLabel;

  /// No description provided for @adMediumRectangleMockPlaceholderLabel.
  ///
  /// In ja, this message translates to:
  /// **'中型レクタングル広告（300×250・配置検討用モック）'**
  String get adMediumRectangleMockPlaceholderLabel;

  /// No description provided for @progressDialogTipLabel.
  ///
  /// In ja, this message translates to:
  /// **'ヒント'**
  String get progressDialogTipLabel;

  /// No description provided for @premiumBannerRegisterButton.
  ///
  /// In ja, this message translates to:
  /// **'プレミアムに登録'**
  String get premiumBannerRegisterButton;

  /// No description provided for @licenseTermsArt1Title.
  ///
  /// In ja, this message translates to:
  /// **'第1条（適用）'**
  String get licenseTermsArt1Title;

  /// No description provided for @licenseTermsArt1Body.
  ///
  /// In ja, this message translates to:
  /// **'この利用規約（以下「本規約」といいます。）は、本アプリ「NIARIM」（以下「本アプリ」といいます。）の利用条件を定めるものです。ユーザーは、本規約に同意の上、本アプリをご利用いただくものとします。本アプリを利用することにより、本規約に同意したものとみなします。'**
  String get licenseTermsArt1Body;

  /// No description provided for @licenseTermsArt2Title.
  ///
  /// In ja, this message translates to:
  /// **'第2条（利用資格・対応環境）'**
  String get licenseTermsArt2Title;

  /// No description provided for @licenseTermsArt2Body.
  ///
  /// In ja, this message translates to:
  /// **'1. 本アプリの対応OSや推奨動作環境の詳細は、各配布ストアおよび本アプリ内の表示に従います。\n2. 本アプリは、多様な性能の端末でも快適にご利用いただけるよう工夫していますが、端末の性能・OSのバージョン・空き容量・設定その他の利用環境によっては、一部機能が制限される、または正常に動作しない場合があります。'**
  String get licenseTermsArt2Body;

  /// No description provided for @licenseTermsArt3Title.
  ///
  /// In ja, this message translates to:
  /// **'第3条（禁止事項）'**
  String get licenseTermsArt3Title;

  /// No description provided for @licenseTermsArt3Body.
  ///
  /// In ja, this message translates to:
  /// **'ユーザーは本アプリの利用にあたり、以下の行為をしてはなりません。\n・法令または公序良俗に違反する行為\n・本アプリ、開発者または第三者の著作権・商標権その他の知的財産権、肖像権、プライバシーその他の権利または利益を侵害する行為\n・本アプリの逆コンパイル、逆アセンブル、リバースエンジニアリングその他解析を目的とする行為（法令上認められる場合を除く）\n・本アプリの不正な改造、複製または再配布\n・本アプリまたはその提供基盤に対する不正アクセス、過度な負荷その他、正常な提供を妨げる行為\n・その他、開発者が合理的な理由に基づき不適切と判断する行為'**
  String get licenseTermsArt3Body;

  /// No description provided for @licenseTermsArt4Title.
  ///
  /// In ja, this message translates to:
  /// **'第4条（作成コンテンツの権利）'**
  String get licenseTermsArt4Title;

  /// No description provided for @licenseTermsArt4Body.
  ///
  /// In ja, this message translates to:
  /// **'1. ユーザーが本アプリを利用して作成したイラスト・アニメーション等のコンテンツ（プロジェクトデータ・書き出した画像・動画等を含みます。以下「作成コンテンツ」といいます。）に関する著作権その他の権利は、法令上認められる範囲において、当該コンテンツについて権利を有するユーザーまたは第三者に帰属します。\n2. 本アプリは、作成コンテンツを開発者のサーバーへ送信・収集・同期する機能を提供していません。プロジェクトデータは、原則としてユーザーの端末内にのみ保存されます。（ユーザーが自らの意思で作品広場機能を利用して作成コンテンツを投稿する場合の取扱いについては、第12条によります。）\n3. 無料版・プレミアム版のいずれを利用して作成した場合であっても、本アプリの利用料金やエディションを理由として、開発者が作成コンテンツの商用利用を制限することはありません。（無料版・プレミアム版の違いは、エンドカード表示や書き出し時間の上限等の機能面に限られます。）\n4. 前項にかかわらず、ユーザーが本アプリに追加したフォント・画像・素材等、第三者が権利を有するものについては、それぞれの利用条件（第5条）に従う必要があります。'**
  String get licenseTermsArt4Body;

  /// No description provided for @licenseTermsArt5Title.
  ///
  /// In ja, this message translates to:
  /// **'第5条（同梱フォント・追加素材について）'**
  String get licenseTermsArt5Title;

  /// No description provided for @licenseTermsArt5Body.
  ///
  /// In ja, this message translates to:
  /// **'1. 本アプリに同梱されるフォントその他の素材は、本画面「使用フォントについて」に記載された各ライセンス条件に従い利用されています。\n2. ユーザーが本アプリに追加登録・読み込みしたフォント、画像、トーン、スタンプ等の素材の権利関係については、ユーザー自身の責任において、必要な権利または許諾を取得の上、適法にご利用ください。\n3. ユーザーによる第三者素材の利用に起因して第三者との間で紛争等が生じた場合、開発者は、法令上の責任を負う場合を除き、その責任を負いません。'**
  String get licenseTermsArt5Body;

  /// No description provided for @licenseTermsArt6Title.
  ///
  /// In ja, this message translates to:
  /// **'第6条（プレミアム機能・課金）'**
  String get licenseTermsArt6Title;

  /// No description provided for @licenseTermsArt6Body.
  ///
  /// In ja, this message translates to:
  /// **'1. 本アプリには、無料でご利用いただける機能のほか、アプリ内課金（月額プラン、年額プランその他のプレミアムプラン）により利用可能となるプレミアム機能があります。\n2. プレミアム機能の価格、提供内容、購入方法その他の条件は、購入時点における本アプリ内または配布ストアの表示に従います。\n3. 購入後のキャンセル・返金その他決済に関する事項については、Google Playその他ご利用の決済プラットフォームの規定が適用されます。ただし、法令に別段の定めがある場合は、その定めに従います。\n4. 開発者は、法令の改正、技術上の必要性、本アプリの改善その他の合理的な理由により、プレミアム機能の内容を変更することがあります。重要な変更を行う場合は、可能な限り事前に本アプリ内その他適切な方法でお知らせします。'**
  String get licenseTermsArt6Body;

  /// No description provided for @licenseTermsArt7Title.
  ///
  /// In ja, this message translates to:
  /// **'第7条（広告表示）'**
  String get licenseTermsArt7Title;

  /// No description provided for @licenseTermsArt7Body.
  ///
  /// In ja, this message translates to:
  /// **'1. 無料版では、第三者の広告配信サービスを通じた広告が表示される場合があります。\n2. 広告配信事業者による情報の取得・利用その他の取扱いについては、各広告配信事業者のプライバシーポリシーが適用されます。'**
  String get licenseTermsArt7Body;

  /// No description provided for @licenseTermsArt8Title.
  ///
  /// In ja, this message translates to:
  /// **'第8条（情報の取扱い）'**
  String get licenseTermsArt8Title;

  /// No description provided for @licenseTermsArt8Body.
  ///
  /// In ja, this message translates to:
  /// **'1. 本アプリは、ユーザーが作成したイラスト・アニメーション等のコンテンツおよびプロジェクトデータを、開発者のサーバーへ送信・収集する機能を提供していません。これらは原則としてユーザーの端末内にのみ保存されており、開発者はこれらを自ら保存する機能を持たないため、開発者側での保存期間という概念自体がありません。\n2. 本アプリが組み込む第三者サービス（広告配信・アプリ内課金等）による情報の取得その他ユーザーの情報の取扱いについては、別途定める「プライバシーポリシー」の定めに従うものとします。\n3. 本アプリをアンインストールした場合、端末内に保存されたデータ（プロジェクト、設定、追加したフォント等）は削除されます。'**
  String get licenseTermsArt8Body;

  /// No description provided for @licenseTermsArt9Title.
  ///
  /// In ja, this message translates to:
  /// **'第9条（提供の停止・変更・終了）'**
  String get licenseTermsArt9Title;

  /// No description provided for @licenseTermsArt9Body.
  ///
  /// In ja, this message translates to:
  /// **'1. 開発者は、本アプリの保守・更新・修正を行う場合、提供基盤に不具合が生じた場合その他やむを得ない事情がある場合、本アプリの全部または一部の提供を一時的に停止することがあります。\n2. 開発者は、必要に応じて本アプリの内容を変更し、または本アプリの提供を終了することがあります。\n3. 前2項の場合、緊急のときを除き、可能な限り事前に本アプリ内その他適切な方法で告知します。\n4. 本条に基づく変更・停止・終了によってユーザーに生じた損害について、開発者は、法令上の責任を負う場合を除き、責任を負いません。'**
  String get licenseTermsArt9Body;

  /// No description provided for @licenseTermsArt10Title.
  ///
  /// In ja, this message translates to:
  /// **'第10条（免責事項）'**
  String get licenseTermsArt10Title;

  /// No description provided for @licenseTermsArt10Body.
  ///
  /// In ja, this message translates to:
  /// **'1. 開発者は、本アプリについて、事実上または法律上の瑕疵（安全性・信頼性・正確性・完全性・特定目的への適合性・バグや不具合がないこと等を含みます。）がないことを保証するものではありません。\n2. ユーザーは、本アプリを自己の責任においてご利用いただくものとします。端末の故障・誤操作・OSの更新その他の事情によりデータが失われる場合がありますので、作成中のデータについては、書き出し・共有機能等を利用した定期的なバックアップを推奨します。\n3. 本アプリの利用によってユーザーに生じた損害について、開発者は、法令上認められる範囲で責任を負いません。ただし、開発者に故意または重過失がある場合はこの限りではなく、その場合であっても、開発者が負う損害賠償責任は、通常生じうる直接損害に限り、ユーザーが本アプリに関し直近1年間に実際に支払った金額（無料でご利用の場合は0円）を上限とします。'**
  String get licenseTermsArt10Body;

  /// No description provided for @licenseTermsArt11Title.
  ///
  /// In ja, this message translates to:
  /// **'第11条（本規約の変更）'**
  String get licenseTermsArt11Title;

  /// No description provided for @licenseTermsArt11Body.
  ///
  /// In ja, this message translates to:
  /// **'1. 開発者は、法令の改正、本アプリの内容の変更その他必要と判断した場合、本規約を変更することがあります。\n2. 本規約を変更する場合、変更内容および効力発生日を、本アプリ内その他適切な方法により、事前に周知します。\n3. 変更後の本規約は、法令上認められる範囲において、前項の効力発生日から適用されます。'**
  String get licenseTermsArt11Body;

  /// No description provided for @licenseTermsArt12Title.
  ///
  /// In ja, this message translates to:
  /// **'第12条（作品広場：コミュニティ投稿機能）'**
  String get licenseTermsArt12Title;

  /// No description provided for @licenseTermsArt12Body.
  ///
  /// In ja, this message translates to:
  /// **'1. 本アプリは、ユーザーが作成したアニメーション作品を、ユーザー自身のGoogleアカウントを通じてYouTubeへ投稿し、「作品広場」上で公開・閲覧できる機能（以下「本コミュニティ機能」といいます。）を任意で提供します。作品の閲覧・作成自体は、本コミュニティ機能を利用しなくても行えます。\n2. 投稿された動画ファイル本体はYouTube上に保存され、開発者のサーバーには保存されません。一方、投稿作品の識別・表示に必要な情報（YouTube動画ID、タイトル、統計情報、通報情報等）、および投稿・通報・ブロック機能の利用にあたり発行されるNIARIM User ID（Googleアカウントとは別に本アプリ内部で発行する識別子）は、開発者のサーバーで管理します。\n3. 本コミュニティ機能のうち、作品の投稿、通報およびユーザーのブロックには、Googleアカウントによるログインが必要です。\n4. 投稿できる作品数には1日あたりの上限があります。（無料会員・プレミアム会員で上限が異なります。）当該上限は、運営上の都合により変更されることがあります。\n5. ユーザーは、他のユーザーが投稿した作品のうち、法令もしくは公序良俗に違反する、または第3条各号に該当するおそれがあると考えるものについて、本アプリ内の通報機能を通じて開発者に報告できます。開発者は、通報の内容を確認のうえ、合理的な理由に基づき当該作品の一覧からの非表示その他の必要な措置を講じることがあります。虚偽の通報または通報機能の濫用は禁止します。\n6. ユーザーが投稿を削除した場合、または本アプリにおけるGoogleアカウント連携を解除した場合、当該投稿に対応するYouTube動画が削除されることがあります。また、YouTube側で動画が非公開または削除された場合、当該作品は作品広場上でも表示されなくなります。\n7. 本コミュニティ機能の利用にあたっては、本規約に加えてYouTubeの利用規約およびコミュニティガイドラインが適用されます。\n8. ユーザーは、他のユーザーをフォローし、他のユーザーの作品をブックマークまたはリポストできます。フォロー中／フォロワーの一覧およびブックマークした作品の一覧は既定で非公開であり、公開するかどうかはユーザーが本アプリ内で選択できます。フォロー数・フォロワー数は公開設定にかかわらず表示されます。\n9. 作品に付けるタグは、投稿者以外のユーザーも追加・削除できます。投稿者は、自分の作品のタグをロックして他のユーザーによる編集を禁止できます。ユーザーは、他人を誹謗中傷するタグ、作品の内容と無関係なタグその他不適切なタグを付けてはなりません。開発者は、不適切なタグを削除することがあります。\n10. 開発者は、フォローされた場合等に本アプリ内の通知一覧へ通知を表示します。ユーザーが端末の通知を許可した場合は、プッシュ通知が送信されることがあります。通知は本アプリの設定または端末の設定から無効にできます。\n11. ユーザーは、本コミュニティ機能を、他のユーザーへの嫌がらせ、宣伝・勧誘、その他本来の目的（作品の公開と閲覧）から外れる目的で利用してはなりません。ブロック機能を利用した場合、ブロックした相手の作品は自分の一覧に表示されなくなります。'**
  String get licenseTermsArt12Body;

  /// No description provided for @licenseTermsArt13Title.
  ///
  /// In ja, this message translates to:
  /// **'第13条（準拠法・裁判管轄）'**
  String get licenseTermsArt13Title;

  /// No description provided for @licenseTermsArt13Body.
  ///
  /// In ja, this message translates to:
  /// **'1. 本規約の解釈にあたっては、日本法を準拠法とします。\n2. 本アプリに関して紛争が生じた場合には、訴額に応じて開発者の所在地を管轄する地方裁判所または簡易裁判所を第一審の専属的合意管轄裁判所とします。'**
  String get licenseTermsArt13Body;

  /// No description provided for @privacyPolicyArt1Title.
  ///
  /// In ja, this message translates to:
  /// **'第1条（本ポリシーの位置づけ）'**
  String get privacyPolicyArt1Title;

  /// No description provided for @privacyPolicyArt1Body.
  ///
  /// In ja, this message translates to:
  /// **'このプライバシーポリシー（以下「本ポリシー」といいます。）は、本アプリ「NIARIM」（以下「本アプリ」といいます。）における情報の取扱いについて定めるものです。本アプリの利用条件全般については別途「利用規約・ライセンス」画面をご確認ください。'**
  String get privacyPolicyArt1Body;

  /// No description provided for @privacyPolicyArt2Title.
  ///
  /// In ja, this message translates to:
  /// **'第2条（本アプリが取得しないデータ）'**
  String get privacyPolicyArt2Title;

  /// No description provided for @privacyPolicyArt2Body.
  ///
  /// In ja, this message translates to:
  /// **'本アプリは、ユーザーが作成したイラスト・アニメーション等のコンテンツ（プロジェクトデータ・書き出し画像・動画等を含みます。以下同じです。）を、開発者のサーバーへ送信・収集・保存する機能を提供していません。これらのデータは、原則としてユーザーの端末内にのみ保存されます。（クラウド同期機能は搭載していません。）開発者はこれらのコンテンツを自ら保存する機能を持たないため、開発者側での保存期間という概念自体がありません。端末内に保存されたデータは、本アプリの削除機能により随時削除できるほか、アプリをアンインストールした場合はプロジェクト・設定・追加したフォント等のデータも併せて削除されます。（ただし、ユーザーが自らの意思で作品広場機能を利用して作品を投稿する場合の情報の取扱いについては、第7条によります。）'**
  String get privacyPolicyArt2Body;

  /// No description provided for @privacyPolicyArt3Title.
  ///
  /// In ja, this message translates to:
  /// **'第3条（第三者サービスによる情報の取得）'**
  String get privacyPolicyArt3Title;

  /// No description provided for @privacyPolicyArt3Body.
  ///
  /// In ja, this message translates to:
  /// **'本アプリは、以下の第三者サービスを組み込んでおり、それぞれのサービス提供者が、サービス提供に必要な範囲で情報を取得する場合があります。本アプリの開発者は、これらの情報を独自に取得・保存する機能を実装していません。（各サービスが取得した情報の管理は、それぞれのサービス提供者のプライバシーポリシーに従います。）\n\n【広告配信（Google AdMob）】\n無料版では、Google AdMobを通じて広告を配信しています。広告の配信、効果測定、不正防止等の目的で、広告識別子（Advertising ID）その他の端末情報が、Googleまたはその関連事業者によって取得・利用される場合があります。取得・利用の詳細は、Googleのプライバシーポリシー（https://policies.google.com/privacy）をご確認ください。端末の設定（Android設定アプリの「プライバシー」等）から、広告識別子のリセットや、パーソナライズ広告の無効化が可能です。欧州経済領域（EEA）・英国・スイスにお住まいの場合は、起動時等に表示される同意フォームで、広告のパーソナライズに関する同意設定を選択できます。設定はいつでも本画面下部の「広告の同意設定を変更」ボタンから変更できます。\n\n【アプリ内課金（Google Play Billing）】\nプレミアム機能の購入は、Google Playの決済システムを通じて行われます。クレジットカード番号等の決済情報は、開発者側が直接取得・保持することはありません。決済に関する情報の取扱いは、Google Playの規定に従います。\n\n【追加フォントのダウンロード（GitHub）】\n設定画面の「フォント管理」から追加フォントをダウンロードする操作を行った場合に限り、フォントの配布元であるGitHub（GitHub, Inc.）のサーバーへ通信が発生します。この通信はお客様がダウンロードを選択したときにのみ行われ、アプリの起動時や通常の利用では発生しません。送信されるのは通信に必要な情報（IPアドレス、取得するフォントファイルの指定等）のみで、作品データやお客様を特定する情報を送信することはありません。取得された情報の取扱いは、GitHubのプライバシーポリシー（https://docs.github.com/site-policy/privacy-policies/github-privacy-statement）に従います。\n\n【クラッシュ解析・利用状況分析】\n本アプリは、現時点でクラッシュ解析・利用状況分析を目的としたSDKを組み込んでいません。将来これらのサービスを導入する場合は、本ポリシーを更新し、本アプリ内で告知します。'**
  String get privacyPolicyArt3Body;

  /// No description provided for @privacyPolicyArt4Title.
  ///
  /// In ja, this message translates to:
  /// **'第4条（Cookie等のトラッキング技術について）'**
  String get privacyPolicyArt4Title;

  /// No description provided for @privacyPolicyArt4Body.
  ///
  /// In ja, this message translates to:
  /// **'本アプリ自体はCookieを使用しませんが、第3条記載の広告配信サービス（Google AdMob）が、広告の配信・効果測定のために、これに類する識別技術（広告識別子等）を使用する場合があります。'**
  String get privacyPolicyArt4Body;

  /// No description provided for @privacyPolicyArt5Title.
  ///
  /// In ja, this message translates to:
  /// **'第5条（お子様の個人情報について）'**
  String get privacyPolicyArt5Title;

  /// No description provided for @privacyPolicyArt5Body.
  ///
  /// In ja, this message translates to:
  /// **'本アプリは、13歳未満のお子様を主な対象として意図的に情報を収集するものではありません。保護者の方は、お子様が本アプリを利用する際、必要に応じて端末の設定からパーソナライズ広告の無効化等をご検討ください。'**
  String get privacyPolicyArt5Body;

  /// No description provided for @privacyPolicyArt6Title.
  ///
  /// In ja, this message translates to:
  /// **'第6条（情報の越境移転について）'**
  String get privacyPolicyArt6Title;

  /// No description provided for @privacyPolicyArt6Body.
  ///
  /// In ja, this message translates to:
  /// **'第3条記載の第三者サービス（Google AdMob、Google Play Billing）は、Google社が世界各地で運用するサーバー上で処理される場合があります。これらの取扱いについては、各サービスのプライバシーポリシーが適用されます。'**
  String get privacyPolicyArt6Body;

  /// No description provided for @privacyPolicyArt7Title.
  ///
  /// In ja, this message translates to:
  /// **'第7条（作品広場：コミュニティ投稿機能における情報の取扱い）'**
  String get privacyPolicyArt7Title;

  /// No description provided for @privacyPolicyArt7Body.
  ///
  /// In ja, this message translates to:
  /// **'1. 本アプリは、ユーザーが自らの意思で「作品広場」機能（利用規約第12条）を利用する場合に限り、以下の情報を開発者のサーバーで管理します。\n・投稿作品を識別・表示するための情報（YouTube動画ID、タイトル、統計情報、投稿日時、タグ等）\n・投稿・通報・ブロック・フォロー・ブックマーク等の機能の利用にあたり発行するNIARIM User ID（Googleアカウントとは別に本アプリ内部で発行する識別子）\n・連携したYouTubeチャンネルの公開情報（チャンネル名、チャンネルアイコンの画像URL）。これは投稿者名・アイコンの表示に用いるため、開発者のサーバーに複製して保持します\n・通報機能を利用した場合の通報内容および通報者のNIARIM User ID\n・ブロックした相手のNIARIM User ID\n・フォローした相手のNIARIM User ID、およびフォロー数・フォロワー数\n・ブックマークした作品のIDおよびブックマークした日時\n・リポストした作品のIDおよびリポストした日時\n・作品に付けられたタグ（第4項参照）\n・プッシュ通知を有効にした場合の端末トークン（通知の宛先を特定するために端末が発行する識別子。通知の送信のみに用います）\n2. 投稿された動画ファイル本体はYouTube上に保存され、開発者のサーバーには保存されません。\n3. 前2項の情報は、本コミュニティ機能の提供（作品の一覧表示・ランキング・検索、通報への対応、投稿上限の管理、フォロー・ブックマーク・リポストの反映、通知の送信等）の目的の範囲内でのみ利用します。開発者はこれらの情報を広告配信の目的で第三者へ提供しません。\n4. タグは、投稿者以外のユーザーも追加・削除できます（投稿者は自分の作品のタグをロックして編集を禁止できます）。タグは作品広場上で公開され、誰が付けたかは表示されません。\n5. 次の情報は既定で非公開であり、ユーザーが本アプリ内で公開設定へ切り替えた場合に限り他のユーザーへ表示されます。\n・ブックマークした作品の一覧\n・フォロー中／フォロワーの一覧\nなお、フォロー数・フォロワー数（人数）は公開設定にかかわらず常に表示されます。\n6. 投稿作品を非公開にする、または削除した場合、当該作品は作品広場の一覧・ランキングから表示されなくなります。開発者のサーバー上の記録の削除を希望する場合は、第9条の窓口へご連絡ください。\n7. 本コミュニティ機能を利用しない場合、本条に基づく情報の取扱いは発生しません。（第2条の原則どおり、開発者のサーバーへの送信は行われません。）'**
  String get privacyPolicyArt7Body;

  /// No description provided for @privacyPolicyArt8Title.
  ///
  /// In ja, this message translates to:
  /// **'第8条（本ポリシーの変更）'**
  String get privacyPolicyArt8Title;

  /// No description provided for @privacyPolicyArt8Body.
  ///
  /// In ja, this message translates to:
  /// **'開発者は、法令の改正、本アプリの内容の変更その他必要と判断した場合、本ポリシーを変更することがあります。本ポリシーを変更する場合、変更内容および効力発生日を、本アプリ内その他適切な方法により、事前に周知します。'**
  String get privacyPolicyArt8Body;

  /// No description provided for @privacyPolicyArt9Title.
  ///
  /// In ja, this message translates to:
  /// **'第9条（お問い合わせ）'**
  String get privacyPolicyArt9Title;

  /// No description provided for @privacyPolicyArt9Body.
  ///
  /// In ja, this message translates to:
  /// **'本ポリシーに関するお問い合わせは、下記の連絡先までご連絡ください。\n（開発者連絡先：未設定 ― 公開前にメールアドレス等の連絡先情報をご記入ください）'**
  String get privacyPolicyArt9Body;

  /// No description provided for @privacyPolicyAdConsentButton.
  ///
  /// In ja, this message translates to:
  /// **'広告の同意設定を変更'**
  String get privacyPolicyAdConsentButton;

  /// No description provided for @tipsPcDexLayoutTitle.
  ///
  /// In ja, this message translates to:
  /// **'ワイド画面ではPCモード（DeX）の本格レイアウトに'**
  String get tipsPcDexLayoutTitle;

  /// No description provided for @tipsPcDexLayoutDesc.
  ///
  /// In ja, this message translates to:
  /// **'Chromebookやタブレット×キーボード、DeXなど画面の広い環境で使うと、ドッキングパネル方式の本格的なレイアウトへ自動で切り替わります。ワークスペース設定から常にPCモード・常にスマホモードへ手動で固定することもできるので、外部ディスプレイに接続して作業するときなどにも活用できます。'**
  String get tipsPcDexLayoutDesc;

  /// No description provided for @workspaceTimelineSection.
  ///
  /// In ja, this message translates to:
  /// **'タイムライン表示'**
  String get workspaceTimelineSection;

  /// No description provided for @workspaceTimelineHint.
  ///
  /// In ja, this message translates to:
  /// **'動画・音源トラックの1行あたりの高さを5段階で調整できます。指2本でのピンチイン・ピンチアウトでも、タイムライン上のフレーム幅を一時的に拡大縮小できます。'**
  String get workspaceTimelineHint;

  /// No description provided for @workspaceTimelineTrackHeightLabel.
  ///
  /// In ja, this message translates to:
  /// **'トラックの高さ'**
  String get workspaceTimelineTrackHeightLabel;

  /// No description provided for @workspaceTimelinePreviewLabel.
  ///
  /// In ja, this message translates to:
  /// **'プレビュー'**
  String get workspaceTimelinePreviewLabel;

  /// No description provided for @workspaceEndCardSection.
  ///
  /// In ja, this message translates to:
  /// **'エンドカード'**
  String get workspaceEndCardSection;

  /// No description provided for @workspaceEndCardHint.
  ///
  /// In ja, this message translates to:
  /// **'エンドカードは動画の最後に自動で表示されるアプリ側のロゴです。無料会員は操作できません。プレミアム会員限定で、ここをONにすると次にタイムラインを開いた時点から最初からエンドカードが非表示（削除済み）の状態になります。プレミアム権限が切れると、この設定は自動的にOFFへ戻ります。'**
  String get workspaceEndCardHint;

  /// No description provided for @workspaceEndCardDefaultHiddenTitle.
  ///
  /// In ja, this message translates to:
  /// **'エンドカードを最初から非表示にする（プレミアム限定）'**
  String get workspaceEndCardDefaultHiddenTitle;

  /// No description provided for @tipsTransparentColorTitle.
  ///
  /// In ja, this message translates to:
  /// **'透明色はただの消しゴムじゃない、ペンと同じ感覚で使える'**
  String get tipsTransparentColorTitle;

  /// No description provided for @tipsTransparentColorDesc.
  ///
  /// In ja, this message translates to:
  /// **'透明色を選ぶと、ブラシ・投げ縄・図形など好きなツールでそのまま「消す」ことができます。ブラシの筆圧や滑らかさをそのまま活かして輪郭だけ丸く削ったり、グラデーションブラシで境界をふわっと透明にぼかしたりと、消しゴムツールにはない繊細な表現が可能です。'**
  String get tipsTransparentColorDesc;

  /// No description provided for @tipsQuickToolVariantTitle.
  ///
  /// In ja, this message translates to:
  /// **'早替えツールはツール違いだけでなくブラシ・サイズ違いも登録できる'**
  String get tipsQuickToolVariantTitle;

  /// No description provided for @tipsQuickToolVariantDesc.
  ///
  /// In ja, this message translates to:
  /// **'早替えツールには、ペン・消しゴムのようなツールの切り替えだけでなく、同じペンでもブラシの種類が違うものや、同じ消しゴムでもサイズ違いのものを別々に登録できます。よく使う組み合わせだけを厳選して並べておけば、細かい設定変更のたびにパネルを開き直す手間が減ります。'**
  String get tipsQuickToolVariantDesc;

  /// No description provided for @tipsCommonLayerLipSyncTitle.
  ///
  /// In ja, this message translates to:
  /// **'共通レイヤーは背景だけでなく人物の容量削減にも使える'**
  String get tipsCommonLayerLipSyncTitle;

  /// No description provided for @tipsCommonLayerLipSyncDesc.
  ///
  /// In ja, this message translates to:
  /// **'背景だけでなく、人物レイヤーそのものを共通レイヤー化するのも有効です。口や瞬きする瞳など、フレームごとに変化する部分だけを通常レイヤーとして重ね、体や髪など動かない部分は共通レイヤーにしておけば、口パクや瞬きのアニメーションでも容量を大きく削減できます。'**
  String get tipsCommonLayerLipSyncDesc;

  /// No description provided for @tipsCommonLayerKeyframeTitle.
  ///
  /// In ja, this message translates to:
  /// **'共通レイヤー×レイヤーキーフレームでも容量削減できる'**
  String get tipsCommonLayerKeyframeTitle;

  /// No description provided for @tipsCommonLayerKeyframeDesc.
  ///
  /// In ja, this message translates to:
  /// **'共通レイヤーはレイヤーキーフレームで位置・拡大・回転を動かせます。フレームごとに描き直す代わりに、1枚の絵を共通レイヤー化してキーフレームで動かすだけで、容量を増やさずに簡単な動きを付けられます。'**
  String get tipsCommonLayerKeyframeDesc;

  /// No description provided for @tipsTransferCustomizationTitle.
  ///
  /// In ja, this message translates to:
  /// **'引き継ぎ機能で端末を変えてもいつもの使い心地のまま'**
  String get tipsTransferCustomizationTitle;

  /// No description provided for @tipsTransferCustomizationDesc.
  ///
  /// In ja, this message translates to:
  /// **'引き継ぎ（.niatra）機能では、ブラシ・テーマ・ツールバーの並び・パレットなどカスタマイズした設定をまとめて別端末へ移せます。機種変更や複数端末の使い分けをしても、毎回イチから設定し直す必要がありません。'**
  String get tipsTransferCustomizationDesc;

  /// No description provided for @tipsBlendModeUsageTitle.
  ///
  /// In ja, this message translates to:
  /// **'ブレンドモードは目的別に使い分けると効果的'**
  String get tipsBlendModeUsageTitle;

  /// No description provided for @tipsBlendModeUsageDesc.
  ///
  /// In ja, this message translates to:
  /// **'影をつけたい時は「乗算」、光や輝きを足したい時は「スクリーン」や「加算」、陰影に質感を出したい時は「オーバーレイ」や「ソフトライト」が向いています。同じ色でもブレンドモードを変えるだけで印象が大きく変わるので、まずは候補をいくつか切り替えて見比べてみるのがおすすめです。'**
  String get tipsBlendModeUsageDesc;

  /// No description provided for @timelineSaveFailedDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'保存に失敗しました'**
  String get timelineSaveFailedDialogTitle;

  /// No description provided for @timelineSaveFailedDialogBody.
  ///
  /// In ja, this message translates to:
  /// **'保存に失敗しました。もう一度お試しください。'**
  String get timelineSaveFailedDialogBody;

  /// No description provided for @licenseSectionIcons.
  ///
  /// In ja, this message translates to:
  /// **'使用アイコンについて'**
  String get licenseSectionIcons;

  /// No description provided for @layerPanelMergeAllVisibleTooltip.
  ///
  /// In ja, this message translates to:
  /// **'表示中の全レイヤーを結合'**
  String get layerPanelMergeAllVisibleTooltip;

  /// No description provided for @canvasBrushSliderToggleLabel.
  ///
  /// In ja, this message translates to:
  /// **'詳細'**
  String get canvasBrushSliderToggleLabel;

  /// No description provided for @helpMeshTransformTitle.
  ///
  /// In ja, this message translates to:
  /// **'自由変形・メッシュ変形'**
  String get helpMeshTransformTitle;

  /// No description provided for @helpMeshTransformDesc.
  ///
  /// In ja, this message translates to:
  /// **'キャンバス右上の編集・設定メニューから開ける、レイヤー全体を対象にした変形ツールです。範囲選択の変形と異なり選択範囲は不要で、角や格子点を指で個別にドラッグして自由な形に変形できます。コントロールパネルの分割数スライダーでメッシュを最大10×10まで細かくでき、2本の指で別々の点を同時につまめば回転・拡大縮小のような操作も直感的に行えます。'**
  String get helpMeshTransformDesc;

  /// No description provided for @layerPanelBrightnessToAlphaLabel.
  ///
  /// In ja, this message translates to:
  /// **'明度で透過'**
  String get layerPanelBrightnessToAlphaLabel;

  /// No description provided for @layerPanelBrightnessToAlphaHint.
  ///
  /// In ja, this message translates to:
  /// **'白い部分ほど透明にします。色はそのまま半透明になります（白背景が消えるのではなく、絵全体が薄くなるイメージ）。'**
  String get layerPanelBrightnessToAlphaHint;

  /// No description provided for @layerPanelBrightnessToAlphaColorButton.
  ///
  /// In ja, this message translates to:
  /// **'カラー'**
  String get layerPanelBrightnessToAlphaColorButton;

  /// No description provided for @layerPanelBrightnessToAlphaGrayButton.
  ///
  /// In ja, this message translates to:
  /// **'グレー'**
  String get layerPanelBrightnessToAlphaGrayButton;

  /// No description provided for @tipsRoughLayerRescueTitle.
  ///
  /// In ja, this message translates to:
  /// **'下描きに線画を描いてしまった時は「明度で透過」で救出'**
  String get tipsRoughLayerRescueTitle;

  /// No description provided for @tipsRoughLayerRescueDesc.
  ///
  /// In ja, this message translates to:
  /// **'下描きレイヤーに誤って線画を重ねて描いてしまっても、レイヤーを消さずに線画だけを取り出せます。①新しいレイヤーを追加し、ブレンドモードを「除算」にする。②スポイトで下描きの色を拾い、その除算レイヤー全体を塗りつぶす（下描きが薄くなります）。③除算レイヤーを複製すると、下描きが完全に消えます。④レイヤーパネルの「表示中の全レイヤーを結合」で1枚にまとめる。⑤結合したレイヤーの三点メニューから「明度で透過（グレー）」を選べば、白い部分が透明になり線画だけが残ります。'**
  String get tipsRoughLayerRescueDesc;

  /// No description provided for @filterNameMonochrome.
  ///
  /// In ja, this message translates to:
  /// **'単色化フィルター'**
  String get filterNameMonochrome;

  /// No description provided for @timelineEffectTypeMonochrome.
  ///
  /// In ja, this message translates to:
  /// **'単色化フィルター'**
  String get timelineEffectTypeMonochrome;

  /// No description provided for @filterNameColorAdjust.
  ///
  /// In ja, this message translates to:
  /// **'色調調整'**
  String get filterNameColorAdjust;

  /// No description provided for @filterColorAdjustSaturationLabel.
  ///
  /// In ja, this message translates to:
  /// **'彩度'**
  String get filterColorAdjustSaturationLabel;

  /// No description provided for @filterColorAdjustBrightnessLabel.
  ///
  /// In ja, this message translates to:
  /// **'明度'**
  String get filterColorAdjustBrightnessLabel;

  /// No description provided for @filterColorAdjustContrastLabel.
  ///
  /// In ja, this message translates to:
  /// **'コントラスト'**
  String get filterColorAdjustContrastLabel;

  /// No description provided for @canvasColorAdjustTitle.
  ///
  /// In ja, this message translates to:
  /// **'色調調整'**
  String get canvasColorAdjustTitle;

  /// No description provided for @canvasColorAdjustAddToDrawFilter.
  ///
  /// In ja, this message translates to:
  /// **'描画フィルターに追加する'**
  String get canvasColorAdjustAddToDrawFilter;

  /// No description provided for @canvasColorAdjustAddToEffectFilter.
  ///
  /// In ja, this message translates to:
  /// **'演出フィルターに追加する'**
  String get canvasColorAdjustAddToEffectFilter;

  /// No description provided for @canvasColorAdjustMenuTitle.
  ///
  /// In ja, this message translates to:
  /// **'色調調整'**
  String get canvasColorAdjustMenuTitle;

  /// No description provided for @canvasEditMenuReferenceWindow.
  ///
  /// In ja, this message translates to:
  /// **'資料ウィンドウ'**
  String get canvasEditMenuReferenceWindow;

  /// No description provided for @canvasEditMenuReferenceWindowSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'三面図・資料画像をフローティング表示'**
  String get canvasEditMenuReferenceWindowSubtitle;

  /// No description provided for @referenceWindowTitle.
  ///
  /// In ja, this message translates to:
  /// **'資料ウィンドウ'**
  String get referenceWindowTitle;

  /// No description provided for @referenceWindowSelectImageButton.
  ///
  /// In ja, this message translates to:
  /// **'画像を選択'**
  String get referenceWindowSelectImageButton;

  /// No description provided for @workspaceDockPanelSection.
  ///
  /// In ja, this message translates to:
  /// **'PC版で既定で開くパネル'**
  String get workspaceDockPanelSection;

  /// No description provided for @workspaceDockPanelHint.
  ///
  /// In ja, this message translates to:
  /// **'PC/DeXモードでは、チェックした複数のパネルを同時にドッキング表示できます（スマホ版は誤操作防止のため対象外）。'**
  String get workspaceDockPanelHint;

  /// No description provided for @workspaceDockPanelBrush.
  ///
  /// In ja, this message translates to:
  /// **'ブラシ'**
  String get workspaceDockPanelBrush;

  /// No description provided for @workspaceDockPanelColorPicker.
  ///
  /// In ja, this message translates to:
  /// **'カラーピッカー'**
  String get workspaceDockPanelColorPicker;

  /// No description provided for @workspaceDockPanelLayer.
  ///
  /// In ja, this message translates to:
  /// **'レイヤー'**
  String get workspaceDockPanelLayer;

  /// No description provided for @workspaceDockPanelTone.
  ///
  /// In ja, this message translates to:
  /// **'トーン'**
  String get workspaceDockPanelTone;

  /// No description provided for @workspaceDockPanelStamp.
  ///
  /// In ja, this message translates to:
  /// **'スタンプ'**
  String get workspaceDockPanelStamp;

  /// No description provided for @workspaceDockPanelPenSubTool.
  ///
  /// In ja, this message translates to:
  /// **'ペンサブツール'**
  String get workspaceDockPanelPenSubTool;

  /// No description provided for @workspaceDockPanelOnionSkin.
  ///
  /// In ja, this message translates to:
  /// **'オニオンスキン'**
  String get workspaceDockPanelOnionSkin;

  /// No description provided for @workspaceDockPanelRuler.
  ///
  /// In ja, this message translates to:
  /// **'定規'**
  String get workspaceDockPanelRuler;

  /// No description provided for @workspaceDockPanelFilter.
  ///
  /// In ja, this message translates to:
  /// **'フィルター'**
  String get workspaceDockPanelFilter;

  /// No description provided for @workspaceDockPanelQuickTool.
  ///
  /// In ja, this message translates to:
  /// **'早替えツール'**
  String get workspaceDockPanelQuickTool;

  /// No description provided for @workspaceDockPanelColorAdjust.
  ///
  /// In ja, this message translates to:
  /// **'色調調整'**
  String get workspaceDockPanelColorAdjust;

  /// No description provided for @workspaceDockPanelCanvasPreview.
  ///
  /// In ja, this message translates to:
  /// **'キャンバスプレビュー'**
  String get workspaceDockPanelCanvasPreview;

  /// No description provided for @workspacePcLayoutButton.
  ///
  /// In ja, this message translates to:
  /// **'PCレイアウト設定'**
  String get workspacePcLayoutButton;

  /// No description provided for @pcWorkspaceLayoutScreenTitle.
  ///
  /// In ja, this message translates to:
  /// **'PCレイアウト設定'**
  String get pcWorkspaceLayoutScreenTitle;

  /// No description provided for @pcWorkspaceLayoutIntroHint.
  ///
  /// In ja, this message translates to:
  /// **'PCモード（横画面＋マウス・ペンタブ接続）でキャンバス画面を開いた際の、パネルの並び順・幅を調整できます。'**
  String get pcWorkspaceLayoutIntroHint;

  /// No description provided for @pcWorkspaceLayoutToolOrderSection.
  ///
  /// In ja, this message translates to:
  /// **'ツールパネルの並び順'**
  String get pcWorkspaceLayoutToolOrderSection;

  /// No description provided for @pcWorkspaceLayoutToolOrderHint.
  ///
  /// In ja, this message translates to:
  /// **'ブラシ・トーン・スタンプ等、複数同時に開いた際に積み重なる順番です。'**
  String get pcWorkspaceLayoutToolOrderHint;

  /// No description provided for @pcWorkspaceLayoutRightOrderSection.
  ///
  /// In ja, this message translates to:
  /// **'レイヤー等パネルの並び順'**
  String get pcWorkspaceLayoutRightOrderSection;

  /// No description provided for @pcWorkspaceLayoutRightOrderHint.
  ///
  /// In ja, this message translates to:
  /// **'カラーピッカー・レイヤー・キャンバスプレビューの積み重ね順です。'**
  String get pcWorkspaceLayoutRightOrderHint;

  /// No description provided for @pcWorkspaceLayoutWidthSection.
  ///
  /// In ja, this message translates to:
  /// **'パネルの幅'**
  String get pcWorkspaceLayoutWidthSection;

  /// No description provided for @pcWorkspaceLayoutToolWidthLabel.
  ///
  /// In ja, this message translates to:
  /// **'ツールパネル側の幅'**
  String get pcWorkspaceLayoutToolWidthLabel;

  /// No description provided for @pcWorkspaceLayoutRightWidthLabel.
  ///
  /// In ja, this message translates to:
  /// **'レイヤー等パネル側の幅'**
  String get pcWorkspaceLayoutRightWidthLabel;

  /// No description provided for @pcWorkspaceLayoutResetWidthButton.
  ///
  /// In ja, this message translates to:
  /// **'幅をデフォルトに戻す'**
  String get pcWorkspaceLayoutResetWidthButton;

  /// No description provided for @pcWorkspaceLayoutResetOrderButton.
  ///
  /// In ja, this message translates to:
  /// **'並び順をデフォルトに戻す'**
  String get pcWorkspaceLayoutResetOrderButton;

  /// No description provided for @canvasPreviewNavigatorTitle.
  ///
  /// In ja, this message translates to:
  /// **'キャンバスプレビュー'**
  String get canvasPreviewNavigatorTitle;

  /// No description provided for @canvasEditMenuPreviewNavigator.
  ///
  /// In ja, this message translates to:
  /// **'キャンバスプレビュー'**
  String get canvasEditMenuPreviewNavigator;

  /// No description provided for @canvasEditMenuPreviewNavigatorSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'全体を縮小表示（ナビゲーター）'**
  String get canvasEditMenuPreviewNavigatorSubtitle;

  /// No description provided for @filterCustomMenuDuplicate.
  ///
  /// In ja, this message translates to:
  /// **'複製'**
  String get filterCustomMenuDuplicate;

  /// No description provided for @filterCustomMenuFavoriteBlockTitle.
  ///
  /// In ja, this message translates to:
  /// **'削除できません'**
  String get filterCustomMenuFavoriteBlockTitle;

  /// No description provided for @filterCustomMenuFavoriteBlockBody.
  ///
  /// In ja, this message translates to:
  /// **'お気に入り登録中のフィルターは削除できません。削除するにはお気に入り登録を解除してください。'**
  String get filterCustomMenuFavoriteBlockBody;

  /// No description provided for @filterNameThreshold.
  ///
  /// In ja, this message translates to:
  /// **'二値化フィルター'**
  String get filterNameThreshold;

  /// No description provided for @filterMonochromeStrength.
  ///
  /// In ja, this message translates to:
  /// **'単色化の強さ'**
  String get filterMonochromeStrength;

  /// No description provided for @filterMonochromeColorLabel.
  ///
  /// In ja, this message translates to:
  /// **'単色化の色'**
  String get filterMonochromeColorLabel;

  /// No description provided for @filterThresholdLabel.
  ///
  /// In ja, this message translates to:
  /// **'閾値'**
  String get filterThresholdLabel;

  /// No description provided for @filterNameFisheye.
  ///
  /// In ja, this message translates to:
  /// **'魚眼レンズフィルター'**
  String get filterNameFisheye;

  /// No description provided for @filterFisheyeStrength.
  ///
  /// In ja, this message translates to:
  /// **'湾曲の強さ'**
  String get filterFisheyeStrength;

  /// No description provided for @filterNameChromaticAberration.
  ///
  /// In ja, this message translates to:
  /// **'色収差フィルター'**
  String get filterNameChromaticAberration;

  /// No description provided for @filterChromaticAberrationStrength.
  ///
  /// In ja, this message translates to:
  /// **'ずれの強さ'**
  String get filterChromaticAberrationStrength;

  /// No description provided for @filterNameLensDistortion.
  ///
  /// In ja, this message translates to:
  /// **'眼鏡断層フィルター'**
  String get filterNameLensDistortion;

  /// No description provided for @filterLensDistortionStrength.
  ///
  /// In ja, this message translates to:
  /// **'レンズの度数（負で凹レンズ、正で凸レンズ）'**
  String get filterLensDistortionStrength;

  /// No description provided for @filterLensDistortionOffsetX.
  ///
  /// In ja, this message translates to:
  /// **'中心位置の微調整（左右）'**
  String get filterLensDistortionOffsetX;

  /// No description provided for @filterNamePixelate.
  ///
  /// In ja, this message translates to:
  /// **'ドット絵フィルター'**
  String get filterNamePixelate;

  /// No description provided for @filterNameAuroraHologram.
  ///
  /// In ja, this message translates to:
  /// **'オーロラホログラム'**
  String get filterNameAuroraHologram;

  /// No description provided for @filterAuroraHologramStrength.
  ///
  /// In ja, this message translates to:
  /// **'フィルター強度'**
  String get filterAuroraHologramStrength;

  /// No description provided for @filterAuroraHologramBrightness.
  ///
  /// In ja, this message translates to:
  /// **'明度'**
  String get filterAuroraHologramBrightness;

  /// No description provided for @filterAuroraHologramSaturation.
  ///
  /// In ja, this message translates to:
  /// **'彩度'**
  String get filterAuroraHologramSaturation;

  /// No description provided for @filterAuroraHologramPresetAurora.
  ///
  /// In ja, this message translates to:
  /// **'オーロラ'**
  String get filterAuroraHologramPresetAurora;

  /// No description provided for @filterAuroraHologramPresetSoapBubble.
  ///
  /// In ja, this message translates to:
  /// **'シャボン玉'**
  String get filterAuroraHologramPresetSoapBubble;

  /// No description provided for @filterAuroraHologramPresetCyberNeon.
  ///
  /// In ja, this message translates to:
  /// **'サイバーネオン'**
  String get filterAuroraHologramPresetCyberNeon;

  /// No description provided for @filterAuroraHologramPresetPastelDream.
  ///
  /// In ja, this message translates to:
  /// **'パステルドリーム'**
  String get filterAuroraHologramPresetPastelDream;

  /// No description provided for @filterAuroraHologramPresetSunsetGold.
  ///
  /// In ja, this message translates to:
  /// **'サンセットゴールド'**
  String get filterAuroraHologramPresetSunsetGold;

  /// No description provided for @filterAuroraHologramPresetSilverFoil.
  ///
  /// In ja, this message translates to:
  /// **'シルバーホイル'**
  String get filterAuroraHologramPresetSilverFoil;

  /// No description provided for @filterNameBackgroundBlend.
  ///
  /// In ja, this message translates to:
  /// **'背景馴染ませ'**
  String get filterNameBackgroundBlend;

  /// No description provided for @filterBackgroundBlendColorLabel.
  ///
  /// In ja, this message translates to:
  /// **'馴染ませ色'**
  String get filterBackgroundBlendColorLabel;

  /// No description provided for @filterBackgroundBlendAutoLabel.
  ///
  /// In ja, this message translates to:
  /// **'自動検出中（タップで手動指定）'**
  String get filterBackgroundBlendAutoLabel;

  /// No description provided for @filterBackgroundBlendAutoReset.
  ///
  /// In ja, this message translates to:
  /// **'自動に戻す'**
  String get filterBackgroundBlendAutoReset;

  /// No description provided for @filterBackgroundBlendDirection.
  ///
  /// In ja, this message translates to:
  /// **'影と光（連動）の向き'**
  String get filterBackgroundBlendDirection;

  /// No description provided for @filterBackgroundBlendLength.
  ///
  /// In ja, this message translates to:
  /// **'影と光（連動）の長さ'**
  String get filterBackgroundBlendLength;

  /// No description provided for @filterBackgroundBlendBlur.
  ///
  /// In ja, this message translates to:
  /// **'ぼかし具合'**
  String get filterBackgroundBlendBlur;

  /// No description provided for @filterPixelateBlockSize.
  ///
  /// In ja, this message translates to:
  /// **'ブロックサイズ'**
  String get filterPixelateBlockSize;

  /// No description provided for @filterLensDistortionOffsetY.
  ///
  /// In ja, this message translates to:
  /// **'中心位置の微調整（上下）'**
  String get filterLensDistortionOffsetY;

  /// No description provided for @filterLensDistortionNoMaskHint.
  ///
  /// In ja, this message translates to:
  /// **'選択レイヤーで塗った範囲にのみ適用されます。先にレイヤー一覧で「選択レイヤー」を追加し、レンズにしたい範囲（眼鏡のレンズ部分等）を塗ってください。'**
  String get filterLensDistortionNoMaskHint;

  /// No description provided for @tipsStockingDenierTitle.
  ///
  /// In ja, this message translates to:
  /// **'ストッキング・タイツはデニール数でトーンの目の細かさが変わる'**
  String get tipsStockingDenierTitle;

  /// No description provided for @tipsStockingDenierDesc.
  ///
  /// In ja, this message translates to:
  /// **'トーン一覧に追加されたストッキング・タイツは、デニール数が低いものほど生地が薄いという設定に合わせて格子模様の間隔を詰めてあり、10デニールなど最も薄いものはあえて細かすぎるくらいの密度にしています（表示・書き出し解像度によってはモアレが出ることがあります）。デニール数が高いタイツほど間隔が広く不透明感のある見た目になるので、キャラクターの脚に合わせて使い分けてください。'**
  String get tipsStockingDenierDesc;

  /// No description provided for @tipsFisheyeChromaticTitle.
  ///
  /// In ja, this message translates to:
  /// **'魚眼レンズ・色収差フィルターでレンズらしい歪み・にじみを演出'**
  String get tipsFisheyeChromaticTitle;

  /// No description provided for @tipsFisheyeChromaticDesc.
  ///
  /// In ja, this message translates to:
  /// **'魚眼レンズフィルターは画面中心を膨らませ、周辺を圧縮することで広角・魚眼レンズで撮ったような湾曲を再現します。色収差フィルターはRGBチャンネルを少しずつずらすことで、安いレンズで撮影したときのような色のにじみを再現します。どちらも描画フィルター（レイヤーへ直接適用）・演出フィルター（タイムライン上で範囲指定して適用）の両方から使えます。'**
  String get tipsFisheyeChromaticDesc;

  /// No description provided for @tipsLensDistortionTitle.
  ///
  /// In ja, this message translates to:
  /// **'選択レイヤー＋眼鏡断層フィルターで、度入りレンズの歪みを再現'**
  String get tipsLensDistortionTitle;

  /// No description provided for @tipsLensDistortionDesc.
  ///
  /// In ja, this message translates to:
  /// **'レイヤー一覧に「選択レイヤー」を追加し、眼鏡のレンズ部分を通常の描画ツールで塗ると、その範囲だけに眼鏡断層フィルターの局所的な歪みをかけられます。度数スライダーは負の値で凹レンズ（近視）風に縮小、正の値で凸レンズ（遠視）風に拡大し、中心位置も微調整できます。両目分のレンズを同時に塗って一括で適用することも可能です。選択レイヤー自体は書き出し・最終的な絵には写り込みません。眼鏡以外にも、カメラのレンズ越しに景色を見ているような歪みを再現したいときにも使えます。背景など広い範囲を選択レイヤーで塗り、弱めの度数をかけるのがおすすめです。'**
  String get tipsLensDistortionDesc;

  /// No description provided for @tipsLineArtExtractionTitle.
  ///
  /// In ja, this message translates to:
  /// **'色調補正・二値化・明度で透過を組み合わせて線画を抽出する'**
  String get tipsLineArtExtractionTitle;

  /// No description provided for @tipsLineArtExtractionDesc.
  ///
  /// In ja, this message translates to:
  /// **'色調補正でコントラストを強めて線を際立たせたあと、二値化フィルターで画像を白黒2色に分けると、線とそれ以外がはっきり分離します。二値化の閾値はスライダーで自由に調整でき、線の太さ・かすれ具合を好みに合わせられます。仕上げにレイヤーの三点メニューにある「明度で透過（グレー）」を使うと、白い部分（線以外）だけが透過し、線画だけを抽出できます。写真や下描きから線画だけを取り出したいときに便利です。'**
  String get tipsLineArtExtractionDesc;

  /// No description provided for @tipsLineColorUsageTitle.
  ///
  /// In ja, this message translates to:
  /// **'線画色は用途で使い分けると仕上がりが変わる'**
  String get tipsLineColorUsageTitle;

  /// No description provided for @tipsLineColorUsageDesc.
  ///
  /// In ja, this message translates to:
  /// **'パーツの輪郭線は色トレス・線画馴染ませを使うと、周りから浮かずに境界だけがはっきり伝わる線画になります。影やハイライトには塗り色と同じ指定色を使うと線画そのものが目立たなくなり、あえて別の指定色にすればそのアニメ特有の世界観・統一感を演出できます。'**
  String get tipsLineColorUsageDesc;

  /// No description provided for @tipsBlushAutofillTitle.
  ///
  /// In ja, this message translates to:
  /// **'頬の赤みも自動塗りでふんわり乗せられる'**
  String get tipsBlushAutofillTitle;

  /// No description provided for @tipsBlushAutofillDesc.
  ///
  /// In ja, this message translates to:
  /// **'線画色を指定色にして透明色を選び、塗り色を放射：中央→外側にして頬の赤みと透明色の2色を指定すると、肌の上に頬の赤みだけをふわっと重ねられます。赤みの不透明度と色の切り替え位置を調整すると、境界がより馴染みやすくなります。'**
  String get tipsBlushAutofillDesc;

  /// No description provided for @autofillPartResetTraceButton.
  ///
  /// In ja, this message translates to:
  /// **'デフォルトに戻す'**
  String get autofillPartResetTraceButton;

  /// No description provided for @premiumScreenTitle.
  ///
  /// In ja, this message translates to:
  /// **'プレミアム'**
  String get premiumScreenTitle;

  /// No description provided for @premiumComparisonPremium.
  ///
  /// In ja, this message translates to:
  /// **'プレミアム'**
  String get premiumComparisonPremium;

  /// No description provided for @premiumRegisteredDateLabel.
  ///
  /// In ja, this message translates to:
  /// **'登録日: {date}'**
  String premiumRegisteredDateLabel(String date);

  /// No description provided for @premiumNextRenewalDateLabel.
  ///
  /// In ja, this message translates to:
  /// **'次回更新日: {date}'**
  String premiumNextRenewalDateLabel(String date);

  /// No description provided for @workspaceApplyCurrentButton.
  ///
  /// In ja, this message translates to:
  /// **'設定したワークスペースを適用'**
  String get workspaceApplyCurrentButton;

  /// No description provided for @workspaceAppliedSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'ワークスペース設定を反映しました'**
  String get workspaceAppliedSnackbar;

  /// No description provided for @workspaceSaveAsButton.
  ///
  /// In ja, this message translates to:
  /// **'ワークスペースに名前を付けて保存・上書き保存'**
  String get workspaceSaveAsButton;

  /// No description provided for @workspaceShareButton.
  ///
  /// In ja, this message translates to:
  /// **'ワークスペースを共有'**
  String get workspaceShareButton;

  /// No description provided for @workspaceShareSelectTitle.
  ///
  /// In ja, this message translates to:
  /// **'共有するワークスペースを選択'**
  String get workspaceShareSelectTitle;

  /// No description provided for @workspaceShareFailedSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'共有に失敗しました: {error}'**
  String workspaceShareFailedSnackbar(String error);

  /// No description provided for @workspaceImportFromFileButton.
  ///
  /// In ja, this message translates to:
  /// **'外部ファイルを読み込み'**
  String get workspaceImportFromFileButton;

  /// No description provided for @workspaceImportFailedSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'読み込みに失敗しました: {error}'**
  String workspaceImportFailedSnackbar(String error);

  /// No description provided for @workspaceNameRequiredError.
  ///
  /// In ja, this message translates to:
  /// **'名前を保存してください'**
  String get workspaceNameRequiredError;

  /// No description provided for @workspaceNoSavedPresets.
  ///
  /// In ja, this message translates to:
  /// **'保存済みのワークスペースがありません'**
  String get workspaceNoSavedPresets;

  /// No description provided for @workspaceOverwriteSelectTitle.
  ///
  /// In ja, this message translates to:
  /// **'上書きするワークスペースを選択'**
  String get workspaceOverwriteSelectTitle;

  /// No description provided for @workspaceOverwriteConfirmTitle.
  ///
  /// In ja, this message translates to:
  /// **'上書きの確認'**
  String get workspaceOverwriteConfirmTitle;

  /// No description provided for @workspaceOverwriteConfirmBody.
  ///
  /// In ja, this message translates to:
  /// **'「{name}」を現在の設定で上書きします。元の内容は削除されます。よろしいですか？'**
  String workspaceOverwriteConfirmBody(String name);

  /// No description provided for @workspaceOverwriteButton.
  ///
  /// In ja, this message translates to:
  /// **'上書き保存'**
  String get workspaceOverwriteButton;

  /// No description provided for @splashCommunityButtonTitle.
  ///
  /// In ja, this message translates to:
  /// **'作品広場'**
  String get splashCommunityButtonTitle;

  /// No description provided for @splashCommunityButtonSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'投稿作品をみる'**
  String get splashCommunityButtonSubtitle;

  /// No description provided for @splashCreateButton.
  ///
  /// In ja, this message translates to:
  /// **'作品をつくる'**
  String get splashCreateButton;

  /// No description provided for @communityScreenTitle.
  ///
  /// In ja, this message translates to:
  /// **'作品広場'**
  String get communityScreenTitle;

  /// No description provided for @communityTabNew.
  ///
  /// In ja, this message translates to:
  /// **'新着'**
  String get communityTabNew;

  /// No description provided for @communityTabRanking.
  ///
  /// In ja, this message translates to:
  /// **'ランキング'**
  String get communityTabRanking;

  /// No description provided for @communityTabFavoriteAuthors.
  ///
  /// In ja, this message translates to:
  /// **'フォロー中'**
  String get communityTabFavoriteAuthors;

  /// No description provided for @communitySearchHint.
  ///
  /// In ja, this message translates to:
  /// **'作品タイトル・投稿者名で検索'**
  String get communitySearchHint;

  /// No description provided for @communityEmptyState.
  ///
  /// In ja, this message translates to:
  /// **'作品がありません'**
  String get communityEmptyState;

  /// No description provided for @communitySearchNoResults.
  ///
  /// In ja, this message translates to:
  /// **'「{query}」に一致する作品が見つかりませんでした'**
  String communitySearchNoResults(String query);

  /// No description provided for @communityTagSearchHint.
  ///
  /// In ja, this message translates to:
  /// **'タグ名で検索'**
  String get communityTagSearchHint;

  /// No description provided for @communityTagSearchModeOnTooltip.
  ///
  /// In ja, this message translates to:
  /// **'タグ検索：ON（タップでタイトル・投稿者名検索に戻す）'**
  String get communityTagSearchModeOnTooltip;

  /// No description provided for @communityTagSearchModeOffTooltip.
  ///
  /// In ja, this message translates to:
  /// **'タグ検索に切り替える'**
  String get communityTagSearchModeOffTooltip;

  /// No description provided for @communityAddTagButton.
  ///
  /// In ja, this message translates to:
  /// **'タグを追加'**
  String get communityAddTagButton;

  /// No description provided for @communityAddTagDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'タグを追加'**
  String get communityAddTagDialogTitle;

  /// No description provided for @communityAddTagDialogHint.
  ///
  /// In ja, this message translates to:
  /// **'タグ名を入力'**
  String get communityAddTagDialogHint;

  /// No description provided for @communityTagLockTooltip.
  ///
  /// In ja, this message translates to:
  /// **'タグをロック（投稿者のみ）'**
  String get communityTagLockTooltip;

  /// No description provided for @communityTagUnlockTooltip.
  ///
  /// In ja, this message translates to:
  /// **'タグのロックを解除（投稿者のみ）'**
  String get communityTagUnlockTooltip;

  /// No description provided for @communityRemoveTagTooltip.
  ///
  /// In ja, this message translates to:
  /// **'タグを削除'**
  String get communityRemoveTagTooltip;

  /// No description provided for @communityPostButton.
  ///
  /// In ja, this message translates to:
  /// **'投稿する'**
  String get communityPostButton;

  /// No description provided for @communityPostComingSoonTitle.
  ///
  /// In ja, this message translates to:
  /// **'投稿機能は準備中です'**
  String get communityPostComingSoonTitle;

  /// No description provided for @communityPostComingSoonBody.
  ///
  /// In ja, this message translates to:
  /// **'動画投稿機能は現在準備中です。今後のアップデートをお楽しみに。'**
  String get communityPostComingSoonBody;

  /// No description provided for @communityPostInfoTitle.
  ///
  /// In ja, this message translates to:
  /// **'投稿はYouTube経由になります'**
  String get communityPostInfoTitle;

  /// No description provided for @communityPostInfoBody.
  ///
  /// In ja, this message translates to:
  /// **'作品広場に投稿すると、YouTubeを通じて作品が公開されます。NIARIMは作品本体（動画ファイル）を開発者のサーバーへ送信・収集・保存する機能を持っていません。投稿の際は、YouTube側の画面で動画をアップロードしていただく形になります。\n\nYouTube側の公開設定を「限定公開」にすると、YouTube上の一般公開一覧には表示されず、作品広場内だけに投稿された状態にすることができます。\n\n（動画投稿機能は現在準備中です。今後のアップデートをお楽しみに。）'**
  String get communityPostInfoBody;

  /// No description provided for @communityRankingPeriodAllTime.
  ///
  /// In ja, this message translates to:
  /// **'累計'**
  String get communityRankingPeriodAllTime;

  /// No description provided for @communityRankingPeriodYearly.
  ///
  /// In ja, this message translates to:
  /// **'年間'**
  String get communityRankingPeriodYearly;

  /// No description provided for @communityRankingPeriodMonthly.
  ///
  /// In ja, this message translates to:
  /// **'月間'**
  String get communityRankingPeriodMonthly;

  /// No description provided for @communityRankingPeriodWeekly.
  ///
  /// In ja, this message translates to:
  /// **'週間'**
  String get communityRankingPeriodWeekly;

  /// No description provided for @communityRankingPeriodDaily.
  ///
  /// In ja, this message translates to:
  /// **'デイリー'**
  String get communityRankingPeriodDaily;

  /// No description provided for @communityRankingSortViews.
  ///
  /// In ja, this message translates to:
  /// **'再生数'**
  String get communityRankingSortViews;

  /// No description provided for @communityRankingSortBookmarks.
  ///
  /// In ja, this message translates to:
  /// **'ブックマーク数'**
  String get communityRankingSortBookmarks;

  /// No description provided for @communityRankingSortAscendingTooltip.
  ///
  /// In ja, this message translates to:
  /// **'昇順（少ない順）'**
  String get communityRankingSortAscendingTooltip;

  /// No description provided for @communityRankingSortDescendingTooltip.
  ///
  /// In ja, this message translates to:
  /// **'降順（多い順）'**
  String get communityRankingSortDescendingTooltip;

  /// No description provided for @communityWorkDetailPostedLabel.
  ///
  /// In ja, this message translates to:
  /// **'{date}に投稿'**
  String communityWorkDetailPostedLabel(String date);

  /// No description provided for @communityWorkDetailViewOnYoutube.
  ///
  /// In ja, this message translates to:
  /// **'YouTubeで見る'**
  String get communityWorkDetailViewOnYoutube;

  /// No description provided for @communityWorkDetailViewOnYoutubeComingSoonSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'YouTube連携機能は準備中です'**
  String get communityWorkDetailViewOnYoutubeComingSoonSnackbar;

  /// No description provided for @communityWorkDetailBookmarkAdd.
  ///
  /// In ja, this message translates to:
  /// **'ブックマーク'**
  String get communityWorkDetailBookmarkAdd;

  /// No description provided for @communityWorkDetailBookmarkRemove.
  ///
  /// In ja, this message translates to:
  /// **'ブックマーク済み'**
  String get communityWorkDetailBookmarkRemove;

  /// No description provided for @communityWorkDetailReportButton.
  ///
  /// In ja, this message translates to:
  /// **'通報'**
  String get communityWorkDetailReportButton;

  /// No description provided for @communityWorkDetailBlockButton.
  ///
  /// In ja, this message translates to:
  /// **'ブロック'**
  String get communityWorkDetailBlockButton;

  /// No description provided for @communityVisibilityCardTitle.
  ///
  /// In ja, this message translates to:
  /// **'作品広場での公開状態'**
  String get communityVisibilityCardTitle;

  /// No description provided for @communityVisibilityPublishedDesc.
  ///
  /// In ja, this message translates to:
  /// **'公開中：新着・ランキング・投稿者別作品一覧に表示されています。'**
  String get communityVisibilityPublishedDesc;

  /// No description provided for @communityVisibilityHiddenDesc.
  ///
  /// In ja, this message translates to:
  /// **'非公開中：新着・ランキング・投稿者別作品一覧から非表示です（YouTube側の公開設定とは独立した設定です）。'**
  String get communityVisibilityHiddenDesc;

  /// No description provided for @communityVisibilityHiddenNotice.
  ///
  /// In ja, this message translates to:
  /// **'この作品は投稿者により作品広場では非公開に設定されています。'**
  String get communityVisibilityHiddenNotice;

  /// No description provided for @communityVisibilityHiddenBadge.
  ///
  /// In ja, this message translates to:
  /// **'非公開'**
  String get communityVisibilityHiddenBadge;

  /// No description provided for @communityWorkDetailTitle.
  ///
  /// In ja, this message translates to:
  /// **'作品詳細'**
  String get communityWorkDetailTitle;

  /// No description provided for @communityWorkNotFoundMessage.
  ///
  /// In ja, this message translates to:
  /// **'作品が見つかりませんでした'**
  String get communityWorkNotFoundMessage;

  /// No description provided for @communityFloatingPreviewDetailButton.
  ///
  /// In ja, this message translates to:
  /// **'詳細へ'**
  String get communityFloatingPreviewDetailButton;

  /// No description provided for @communityFloatingPreviewPlayTooltip.
  ///
  /// In ja, this message translates to:
  /// **'再生'**
  String get communityFloatingPreviewPlayTooltip;

  /// No description provided for @communityFloatingPreviewPauseTooltip.
  ///
  /// In ja, this message translates to:
  /// **'一時停止'**
  String get communityFloatingPreviewPauseTooltip;

  /// No description provided for @communityReportDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'作品を通報'**
  String get communityReportDialogTitle;

  /// No description provided for @communityReportDialogBody.
  ///
  /// In ja, this message translates to:
  /// **'通報理由を選択してください。'**
  String get communityReportDialogBody;

  /// No description provided for @communityReportReasonInappropriate.
  ///
  /// In ja, this message translates to:
  /// **'不適切な内容'**
  String get communityReportReasonInappropriate;

  /// No description provided for @communityReportReasonCopyright.
  ///
  /// In ja, this message translates to:
  /// **'著作権侵害の疑い'**
  String get communityReportReasonCopyright;

  /// No description provided for @communityReportReasonSpam.
  ///
  /// In ja, this message translates to:
  /// **'スパム・繰り返し投稿'**
  String get communityReportReasonSpam;

  /// No description provided for @communityReportReasonOther.
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get communityReportReasonOther;

  /// No description provided for @communityReportSubmitButton.
  ///
  /// In ja, this message translates to:
  /// **'通報する'**
  String get communityReportSubmitButton;

  /// No description provided for @communityReportDetailLabel.
  ///
  /// In ja, this message translates to:
  /// **'詳細'**
  String get communityReportDetailLabel;

  /// No description provided for @communityReportDetailHint.
  ///
  /// In ja, this message translates to:
  /// **'どのような点が問題か具体的に入力してください'**
  String get communityReportDetailHint;

  /// No description provided for @communityReportDetailRequiredError.
  ///
  /// In ja, this message translates to:
  /// **'詳細を入力してください'**
  String get communityReportDetailRequiredError;

  /// No description provided for @communityReportComingSoonSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'通報機能は準備中です。実際には送信されません。'**
  String get communityReportComingSoonSnackbar;

  /// No description provided for @communityBlockConfirmTitle.
  ///
  /// In ja, this message translates to:
  /// **'「{name}」をブロックしますか？'**
  String communityBlockConfirmTitle(String name);

  /// No description provided for @communityBlockConfirmBody.
  ///
  /// In ja, this message translates to:
  /// **'ブロックすると、この作者の作品が一覧に表示されなくなります。'**
  String get communityBlockConfirmBody;

  /// No description provided for @communityBlockComingSoonSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'ブロック機能は準備中です。実際には反映されません。'**
  String get communityBlockComingSoonSnackbar;

  /// No description provided for @communityAuthorWorksCount.
  ///
  /// In ja, this message translates to:
  /// **'{count}作品'**
  String communityAuthorWorksCount(int count);

  /// No description provided for @communityAuthorFollowerCount.
  ///
  /// In ja, this message translates to:
  /// **'フォロワー{count}人'**
  String communityAuthorFollowerCount(int count);

  /// No description provided for @communityFollowersPublicToggleTitle.
  ///
  /// In ja, this message translates to:
  /// **'フォロー中/フォロワー一覧を公開する'**
  String get communityFollowersPublicToggleTitle;

  /// No description provided for @communityFollowersPublicToggleDesc.
  ///
  /// In ja, this message translates to:
  /// **'オンにすると、他のユーザーがこのページからあなたのフォロー中/フォロワー一覧を見られるようになります。既定は非公開です。'**
  String get communityFollowersPublicToggleDesc;

  /// No description provided for @communityFollowersListTitle.
  ///
  /// In ja, this message translates to:
  /// **'フォロワー'**
  String get communityFollowersListTitle;

  /// No description provided for @communityFollowersListEmpty.
  ///
  /// In ja, this message translates to:
  /// **'フォロワーがいません'**
  String get communityFollowersListEmpty;

  /// No description provided for @communityFollowersListHiddenNote.
  ///
  /// In ja, this message translates to:
  /// **'他に{count}人いますが、本人の設定により非表示です'**
  String communityFollowersListHiddenNote(int count);

  /// No description provided for @communityAuthorFollowingCount.
  ///
  /// In ja, this message translates to:
  /// **'フォロー中{count}人'**
  String communityAuthorFollowingCount(int count);

  /// No description provided for @communityFollowingListTitle.
  ///
  /// In ja, this message translates to:
  /// **'フォロー中'**
  String get communityFollowingListTitle;

  /// No description provided for @communityFollowingListEmpty.
  ///
  /// In ja, this message translates to:
  /// **'誰もフォローしていません'**
  String get communityFollowingListEmpty;

  /// No description provided for @communityFollowNotificationsTooltip.
  ///
  /// In ja, this message translates to:
  /// **'通知'**
  String get communityFollowNotificationsTooltip;

  /// No description provided for @communityFollowNotificationsTitle.
  ///
  /// In ja, this message translates to:
  /// **'フォロー通知'**
  String get communityFollowNotificationsTitle;

  /// No description provided for @communityFollowNotificationsEmpty.
  ///
  /// In ja, this message translates to:
  /// **'通知はありません'**
  String get communityFollowNotificationsEmpty;

  /// No description provided for @communityFollowNotificationBody.
  ///
  /// In ja, this message translates to:
  /// **'{name}さんにフォローされました'**
  String communityFollowNotificationBody(String name);

  /// No description provided for @communityNoWorksMessage.
  ///
  /// In ja, this message translates to:
  /// **'作品がありません'**
  String get communityNoWorksMessage;

  /// No description provided for @communityFavoriteAuthorFollow.
  ///
  /// In ja, this message translates to:
  /// **'フォロー'**
  String get communityFavoriteAuthorFollow;

  /// No description provided for @communityFavoriteAuthorFollowing.
  ///
  /// In ja, this message translates to:
  /// **'フォロー中'**
  String get communityFavoriteAuthorFollowing;

  /// No description provided for @communityFavoriteAuthorsEmptyTitle.
  ///
  /// In ja, this message translates to:
  /// **'お気に入り作者がいません'**
  String get communityFavoriteAuthorsEmptyTitle;

  /// No description provided for @communityFavoriteAuthorsEmptyBody.
  ///
  /// In ja, this message translates to:
  /// **'気に入った投稿者のページで「フォロー」すると、ここにその人の新着作品が並びます。'**
  String get communityFavoriteAuthorsEmptyBody;

  /// No description provided for @communityRepostButton.
  ///
  /// In ja, this message translates to:
  /// **'リポスト'**
  String get communityRepostButton;

  /// No description provided for @communityRepostedButton.
  ///
  /// In ja, this message translates to:
  /// **'リポスト済み'**
  String get communityRepostedButton;

  /// No description provided for @communityRepostedByBadge.
  ///
  /// In ja, this message translates to:
  /// **'{name}さんがリポスト'**
  String communityRepostedByBadge(String name);

  /// No description provided for @communityAuthorTabWorks.
  ///
  /// In ja, this message translates to:
  /// **'作品'**
  String get communityAuthorTabWorks;

  /// No description provided for @communityAuthorTabBookmarks.
  ///
  /// In ja, this message translates to:
  /// **'ブックマーク'**
  String get communityAuthorTabBookmarks;

  /// No description provided for @communityBookmarksPublicToggleTitle.
  ///
  /// In ja, this message translates to:
  /// **'ブックマーク一覧を公開する'**
  String get communityBookmarksPublicToggleTitle;

  /// No description provided for @communityBookmarksPublicToggleDesc.
  ///
  /// In ja, this message translates to:
  /// **'オンにすると、他のユーザーがこのページからあなたのブックマーク一覧を見られるようになります。既定は非公開です。'**
  String get communityBookmarksPublicToggleDesc;

  /// No description provided for @communityBookmarksPrivateNotice.
  ///
  /// In ja, this message translates to:
  /// **'このユーザーはブックマーク一覧を非公開にしています。'**
  String get communityBookmarksPrivateNotice;

  /// No description provided for @communityBookmarksEmptyMessage.
  ///
  /// In ja, this message translates to:
  /// **'ブックマークした作品がありません'**
  String get communityBookmarksEmptyMessage;

  /// No description provided for @communityShortsBadge.
  ///
  /// In ja, this message translates to:
  /// **'縦画面'**
  String get communityShortsBadge;

  /// No description provided for @communityVideoTypeFilterTooltip.
  ///
  /// In ja, this message translates to:
  /// **'動画の種類を絞り込む'**
  String get communityVideoTypeFilterTooltip;

  /// No description provided for @communityVideoTypeFilterAll.
  ///
  /// In ja, this message translates to:
  /// **'総合'**
  String get communityVideoTypeFilterAll;

  /// No description provided for @communityVideoTypeFilterShortOnly.
  ///
  /// In ja, this message translates to:
  /// **'縦画面のみ'**
  String get communityVideoTypeFilterShortOnly;

  /// No description provided for @communityVideoTypeFilterLongOnly.
  ///
  /// In ja, this message translates to:
  /// **'横画面のみ'**
  String get communityVideoTypeFilterLongOnly;

  /// No description provided for @communityShortsModeTooltip.
  ///
  /// In ja, this message translates to:
  /// **'縦画面モードで見る'**
  String get communityShortsModeTooltip;

  /// No description provided for @communityShortsModeEmptySnackbar.
  ///
  /// In ja, this message translates to:
  /// **'縦画面の動画がありません'**
  String get communityShortsModeEmptySnackbar;

  /// No description provided for @communityShortsModeExitTooltip.
  ///
  /// In ja, this message translates to:
  /// **'縦画面モードを終了'**
  String get communityShortsModeExitTooltip;

  /// No description provided for @pixelColorModeLabel.
  ///
  /// In ja, this message translates to:
  /// **'配色方式'**
  String get pixelColorModeLabel;

  /// No description provided for @pixelColorModeNone.
  ///
  /// In ja, this message translates to:
  /// **'色を指定しない'**
  String get pixelColorModeNone;

  /// No description provided for @pixelColorModePalette.
  ///
  /// In ja, this message translates to:
  /// **'パレットから選ぶ'**
  String get pixelColorModePalette;

  /// No description provided for @pixelColorModeExplicit.
  ///
  /// In ja, this message translates to:
  /// **'色を指定する'**
  String get pixelColorModeExplicit;

  /// No description provided for @pixelColorModeCount.
  ///
  /// In ja, this message translates to:
  /// **'色数を指定する'**
  String get pixelColorModeCount;

  /// No description provided for @pixelColorLevelsLabel.
  ///
  /// In ja, this message translates to:
  /// **'色数: {count}'**
  String pixelColorLevelsLabel(int count);

  /// No description provided for @pixelColorChipDeleteTooltip.
  ///
  /// In ja, this message translates to:
  /// **'この色を削除'**
  String get pixelColorChipDeleteTooltip;

  /// No description provided for @pixelColorChipAddButton.
  ///
  /// In ja, this message translates to:
  /// **'色を追加'**
  String get pixelColorChipAddButton;

  /// No description provided for @pixelArtPaletteNameRequiredError.
  ///
  /// In ja, this message translates to:
  /// **'パレット名を入力してください'**
  String get pixelArtPaletteNameRequiredError;

  /// No description provided for @pixelArtPaletteEditTitle.
  ///
  /// In ja, this message translates to:
  /// **'パレットを編集'**
  String get pixelArtPaletteEditTitle;

  /// No description provided for @pixelArtPaletteAddTitle.
  ///
  /// In ja, this message translates to:
  /// **'パレットを追加'**
  String get pixelArtPaletteAddTitle;

  /// No description provided for @pixelArtPaletteNameLabel.
  ///
  /// In ja, this message translates to:
  /// **'パレット名'**
  String get pixelArtPaletteNameLabel;

  /// No description provided for @pixelArtPalettePickerTitle.
  ///
  /// In ja, this message translates to:
  /// **'パレットから選ぶ'**
  String get pixelArtPalettePickerTitle;

  /// No description provided for @pixelArtPalettePickerEmpty.
  ///
  /// In ja, this message translates to:
  /// **'保存済みのパレットがありません。「追加」から作成してください'**
  String get pixelArtPalettePickerEmpty;

  /// No description provided for @pixelArtPalettePickerApplyButton.
  ///
  /// In ja, this message translates to:
  /// **'適用'**
  String get pixelArtPalettePickerApplyButton;

  /// No description provided for @storageScreenTitle.
  ///
  /// In ja, this message translates to:
  /// **'容量削減'**
  String get storageScreenTitle;

  /// No description provided for @storageDeviceChartTitle.
  ///
  /// In ja, this message translates to:
  /// **'端末の容量'**
  String get storageDeviceChartTitle;

  /// No description provided for @storageBreakdownChartTitle.
  ///
  /// In ja, this message translates to:
  /// **'NIARIMの内訳'**
  String get storageBreakdownChartTitle;

  /// No description provided for @storageActionsTitle.
  ///
  /// In ja, this message translates to:
  /// **'整理する'**
  String get storageActionsTitle;

  /// No description provided for @storageCategoryNiarimTotal.
  ///
  /// In ja, this message translates to:
  /// **'NIARIM'**
  String get storageCategoryNiarimTotal;

  /// No description provided for @storageCategoryOtherApps.
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get storageCategoryOtherApps;

  /// No description provided for @storageCategoryFree.
  ///
  /// In ja, this message translates to:
  /// **'空き容量'**
  String get storageCategoryFree;

  /// No description provided for @storageCategoryMaterials.
  ///
  /// In ja, this message translates to:
  /// **'素材'**
  String get storageCategoryMaterials;

  /// No description provided for @storageCategoryProjectData.
  ///
  /// In ja, this message translates to:
  /// **'プロジェクトデータ'**
  String get storageCategoryProjectData;

  /// No description provided for @storageCategoryExports.
  ///
  /// In ja, this message translates to:
  /// **'書き出し済みファイル'**
  String get storageCategoryExports;

  /// No description provided for @storageCategoryCustomAssets.
  ///
  /// In ja, this message translates to:
  /// **'自作ブラシ・トーン・スタンプ・フォント'**
  String get storageCategoryCustomAssets;

  /// No description provided for @storageCategoryCache.
  ///
  /// In ja, this message translates to:
  /// **'キャッシュ'**
  String get storageCategoryCache;

  /// No description provided for @storageCategoryTrash.
  ///
  /// In ja, this message translates to:
  /// **'ゴミ箱'**
  String get storageCategoryTrash;

  /// No description provided for @storageClearCacheButton.
  ///
  /// In ja, this message translates to:
  /// **'キャッシュを削除'**
  String get storageClearCacheButton;

  /// No description provided for @storageRemoveUnusedMaterialsButton.
  ///
  /// In ja, this message translates to:
  /// **'未使用素材を一括削除（全プロジェクト）'**
  String get storageRemoveUnusedMaterialsButton;

  /// No description provided for @storageEmptyTrashButton.
  ///
  /// In ja, this message translates to:
  /// **'ゴミ箱を空にする'**
  String get storageEmptyTrashButton;

  /// No description provided for @storageOrganizeProjectsButton.
  ///
  /// In ja, this message translates to:
  /// **'プロジェクトを整理する'**
  String get storageOrganizeProjectsButton;

  /// No description provided for @storageEraseAllButton.
  ///
  /// In ja, this message translates to:
  /// **'全データを削除（初期化）'**
  String get storageEraseAllButton;

  /// No description provided for @storageClearCacheDoneSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'{size}のキャッシュを削除しました'**
  String storageClearCacheDoneSnackbar(String size);

  /// No description provided for @storageEraseAllConfirmTitle.
  ///
  /// In ja, this message translates to:
  /// **'全データを削除しますか？'**
  String get storageEraseAllConfirmTitle;

  /// No description provided for @storageEraseAllConfirmBody.
  ///
  /// In ja, this message translates to:
  /// **'プロジェクト・素材・書き出し済みファイル・自作ブラシ/トーン/スタンプ/フォント・設定など、NIARIMの全データを完全に削除します。この操作は元に戻せません。削除後はアプリを再起動してください。'**
  String get storageEraseAllConfirmBody;

  /// No description provided for @storageEraseAllDoneSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'全データを削除しました。アプリを再起動してください'**
  String get storageEraseAllDoneSnackbar;

  /// No description provided for @homeDrawerStorage.
  ///
  /// In ja, this message translates to:
  /// **'容量削減'**
  String get homeDrawerStorage;

  /// No description provided for @helpStorageTitle.
  ///
  /// In ja, this message translates to:
  /// **'容量削減'**
  String get helpStorageTitle;

  /// No description provided for @helpStorageDesc.
  ///
  /// In ja, this message translates to:
  /// **'端末容量に対するNIARIMの使用量と、NIARIM内部（プロジェクト・素材・書き出し済みファイル・自作ブラシ/トーン/スタンプ/フォント・キャッシュ・ゴミ箱）の内訳を円グラフで確認できます。キャッシュの削除・未使用素材の一括削除（全プロジェクト）・ゴミ箱を空にする・プロジェクトの整理・全データ削除（初期化）が行えます。'**
  String get helpStorageDesc;

  /// No description provided for @colorPickerImportPaletteTooltip.
  ///
  /// In ja, this message translates to:
  /// **'パレットを取り込む'**
  String get colorPickerImportPaletteTooltip;

  /// No description provided for @colorPickerSharePaletteTooltip.
  ///
  /// In ja, this message translates to:
  /// **'共有する'**
  String get colorPickerSharePaletteTooltip;

  /// No description provided for @colorPickerShareViaFile.
  ///
  /// In ja, this message translates to:
  /// **'ファイルで共有'**
  String get colorPickerShareViaFile;

  /// No description provided for @colorPickerShareFailedSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'共有に失敗しました: {error}'**
  String colorPickerShareFailedSnackbar(String error);

  /// No description provided for @colorPickerShareViaQr.
  ///
  /// In ja, this message translates to:
  /// **'QRコードで共有'**
  String get colorPickerShareViaQr;

  /// No description provided for @qrShareTooLargeHint.
  ///
  /// In ja, this message translates to:
  /// **'色数が多いためQRコードでは共有できません（ファイル共有をご利用ください）'**
  String get qrShareTooLargeHint;

  /// No description provided for @colorPickerImportViaFile.
  ///
  /// In ja, this message translates to:
  /// **'ファイルから選択'**
  String get colorPickerImportViaFile;

  /// No description provided for @colorPickerImportFailedSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'読み込みに失敗しました: {error}'**
  String colorPickerImportFailedSnackbar(String error);

  /// No description provided for @colorPickerImportViaQr.
  ///
  /// In ja, this message translates to:
  /// **'QRコードのテキストを貼り付け'**
  String get colorPickerImportViaQr;

  /// No description provided for @qrImportFailedError.
  ///
  /// In ja, this message translates to:
  /// **'読み込みに失敗しました。テキストが正しいか確認してください'**
  String get qrImportFailedError;

  /// No description provided for @qrImportHint.
  ///
  /// In ja, this message translates to:
  /// **'相手の端末で表示されたQRコードを標準カメラアプリ等で読み取り、コピーした文字列をここに貼り付けてください'**
  String get qrImportHint;

  /// No description provided for @qrImportFieldHint.
  ///
  /// In ja, this message translates to:
  /// **'読み取った文字列を貼り付け'**
  String get qrImportFieldHint;

  /// No description provided for @qrImportPasteButton.
  ///
  /// In ja, this message translates to:
  /// **'クリップボードから貼り付け'**
  String get qrImportPasteButton;

  /// No description provided for @qrImportSubmitButton.
  ///
  /// In ja, this message translates to:
  /// **'読み込む'**
  String get qrImportSubmitButton;

  /// No description provided for @qrShareHint.
  ///
  /// In ja, this message translates to:
  /// **'標準カメラアプリ等でこのQRコードを読み取ると、テキストをコピーできます。相手の端末で「取り込む」からQRコードのテキストを貼り付けてください。'**
  String get qrShareHint;

  /// No description provided for @qrShareCopiedSnackbar.
  ///
  /// In ja, this message translates to:
  /// **'テキストをコピーしました'**
  String get qrShareCopiedSnackbar;

  /// No description provided for @qrShareCopyButton.
  ///
  /// In ja, this message translates to:
  /// **'テキストをコピー'**
  String get qrShareCopyButton;

  /// No description provided for @toolbarItemBlur.
  ///
  /// In ja, this message translates to:
  /// **'ガウスぼかし'**
  String get toolbarItemBlur;

  /// No description provided for @toolbarItemMosaic.
  ///
  /// In ja, this message translates to:
  /// **'モザイク'**
  String get toolbarItemMosaic;

  /// No description provided for @toolbarFingerSubtoolWarp.
  ///
  /// In ja, this message translates to:
  /// **'歪み'**
  String get toolbarFingerSubtoolWarp;

  /// No description provided for @brushSettingsEdgeJitterTitle.
  ///
  /// In ja, this message translates to:
  /// **'ふち滲み'**
  String get brushSettingsEdgeJitterTitle;

  /// No description provided for @brushSettingsEdgeJitterSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'ふちをわずかにがたがたさせてインクの滲みを再現する'**
  String get brushSettingsEdgeJitterSubtitle;

  /// No description provided for @brushSettingsEdgeJitterStrengthLabel.
  ///
  /// In ja, this message translates to:
  /// **'滲み強度'**
  String get brushSettingsEdgeJitterStrengthLabel;

  /// No description provided for @filterNameInkPool.
  ///
  /// In ja, this message translates to:
  /// **'墨溜まり'**
  String get filterNameInkPool;

  /// No description provided for @filterInkPoolColor.
  ///
  /// In ja, this message translates to:
  /// **'色'**
  String get filterInkPoolColor;

  /// No description provided for @filterInkPoolRange.
  ///
  /// In ja, this message translates to:
  /// **'範囲'**
  String get filterInkPoolRange;

  /// No description provided for @filterInkPoolCenterWidth.
  ///
  /// In ja, this message translates to:
  /// **'中央の太さ'**
  String get filterInkPoolCenterWidth;

  /// No description provided for @filterInkPoolLayerNameSuffix.
  ///
  /// In ja, this message translates to:
  /// **'{name} 墨溜まり'**
  String filterInkPoolLayerNameSuffix(String name);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'en',
    'es',
    'fr',
    'ja',
    'ko',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
