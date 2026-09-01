// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'NIARIM';

  @override
  String get homeTabProjects => '프로젝트';

  @override
  String get homeTabShared => '공유';

  @override
  String get homeTabTrash => '휴지통';

  @override
  String get homeTabWorks => '작품 목록';

  @override
  String get homeTabBookmarked => '북마크됨';

  @override
  String get homeBookmarkedComingSoonTitle => '준비 중입니다';

  @override
  String get homeBookmarkedComingSoonBody =>
      '\"모두의 애니메이션 보기\" 기능이 구현되면, 다른 사용자의 공개 작품 중 북마크한 작품이 여기에 표시됩니다.';

  @override
  String get homeSearchHint => '프로젝트 이름으로 검색';

  @override
  String get homeBackToSplashTooltip => '시작 화면으로 돌아가기';

  @override
  String get homeFavoritesOnly => '즐겨찾기';

  @override
  String get homeAddSheetNewProject => '새 프로젝트';

  @override
  String get homeAddSheetNewFolder => '새 폴더';

  @override
  String get homeSelectionAllSelect => '전체 선택';

  @override
  String get homeSelectionAllDeselect => '전체 선택 해제';

  @override
  String get homeSelectionAddFavorite => '즐겨찾기에 추가';

  @override
  String get homeSelectionRemoveFavorite => '즐겨찾기 해제';

  @override
  String homeSelectionCount(int count) {
    return '$count개 선택됨';
  }

  @override
  String get homeMoveToTrash => '휴지통으로 이동';

  @override
  String homeMoveToTrashConfirm(int count) {
    return '$count개 항목을 휴지통으로 이동하시겠습니까?';
  }

  @override
  String get commonMove => '이동';

  @override
  String get homeShareFileDialogTitle => '공유 파일';

  @override
  String get homeShareFileDialogContent => '이 공유 파일을 복제하여 일반 프로젝트로 저장하시겠습니까?';

  @override
  String homeMissingFontsSnackbar(String names) {
    return '누락된 폰트가 있습니다: $names';
  }

  @override
  String get homeSharedImportedSnackbar => '프로젝트 탭에 추가되었습니다';

  @override
  String homeSharedImportFailedSnackbar(String error) {
    return '공유 파일을 불러오지 못했습니다: $error';
  }

  @override
  String get homeViewModeLarge => '크게';

  @override
  String get homeViewModeMedium => '보통';

  @override
  String get homeViewModeSmall => '작게';

  @override
  String get homeViewModeDetail => '상세';

  @override
  String get homeSortNameAsc => '이름 ↑';

  @override
  String get homeSortNameDesc => '이름 ↓';

  @override
  String get homeSortUpdatedAsc => '수정일 ↑';

  @override
  String get homeSortUpdatedDesc => '수정일 ↓';

  @override
  String get homeSortFieldName => '이름';

  @override
  String get homeSortFieldUpdated => '수정일';

  @override
  String get homeSortDirectionAscTooltip => '오름차순（탭하면 내림차순으로 전환）';

  @override
  String get homeSortDirectionDescTooltip => '내림차순（탭하면 오름차순으로 전환）';

  @override
  String get homeSharedEmpty => '공유된 프로젝트가 없습니다';

  @override
  String homeProjectMeta(int fps, int duration) {
    return '${fps}fps · $duration초';
  }

  @override
  String get homeTrashEmpty => '휴지통이 비어 있습니다';

  @override
  String homeTrashDeletedOn(String date) {
    return '$date 삭제됨';
  }

  @override
  String get homePermanentDelete => '완전 삭제';

  @override
  String get homePermanentDeleteConfirmTitle => '완전히 삭제하시겠습니까?';

  @override
  String get homePermanentDeleteConfirmBody => '이 작업은 되돌릴 수 없습니다.';

  @override
  String get homeWorksEmpty => '내보낸 작품이 없습니다';

  @override
  String get homeWorksEmptyHint => '캔버스에서 동영상이나 GIF를 내보내면\n여기에 표시됩니다';

  @override
  String get homeShareOpenWith => '공유・사진 앱 등으로 열기';

  @override
  String homeWorkDeleteConfirmTitle(String name) {
    return '$name을(를) 삭제하시겠습니까?';
  }

  @override
  String get homeWorkDeleteConfirmBody => '기기에 저장된 내보내기 파일이 삭제됩니다. 되돌릴 수 없습니다.';

  @override
  String get homePreviewFailed => '미리보기를 재생할 수 없습니다';

  @override
  String get homeFirstLaunchMessage => '손그림 애니메이션을 제작할 수 있습니다';

  @override
  String get homeFirstLaunchStart => '시작하기';

  @override
  String get settingsScreenTitle => '설정';

  @override
  String get settingsBasicTitle => '기본';

  @override
  String get settingsBasicSubtitle => 'FPS・배경색・언어';

  @override
  String get settingsBasicSheetTitle => '기본 설정';

  @override
  String get settingsDefaultFps => '기본 FPS';

  @override
  String get settingsDefaultFpsSubtitle => '새 프로젝트 만들기 화면의 초기값';

  @override
  String get settingsLanguage => '언어';

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
  String get settingsSearchHint => '설정 검색...';

  @override
  String get settingsPerformanceTitle => '성능';

  @override
  String get settingsPerformanceSubtitle => '품질 설정・실행 취소 횟수・휴지통・동작 속도';

  @override
  String get settingsGestureTitle => '제스처';

  @override
  String get settingsGestureSubtitle => '두 손가락 탭・길게 누르기';

  @override
  String get settingsPenTitle => '펜 입력';

  @override
  String get settingsPenSubtitle => '필압・기울기・펜 버튼';

  @override
  String get settingsWorkspaceTitle => '작업 공간';

  @override
  String get settingsWorkspaceSubtitle => '도구 모음 편집・패널 배치';

  @override
  String get settingsBucketTitle => '페인트 통 채우기';

  @override
  String get settingsBucketSubtitle => '허용 오차・확장・선 아래로 파고들기';

  @override
  String get settingsThemeTitle => '테마・외관';

  @override
  String get settingsThemeSubtitle => '테마 설정・작업 공간';

  @override
  String get settingsWatermarkTitle => '워터마크';

  @override
  String get settingsWatermarkSubtitle => '커스텀 워터마크';

  @override
  String get settingsTransferTitle => '데이터 이전';

  @override
  String get settingsTransferSubtitle => '설정・소재・브러시를 다른 기기로 내보내기/가져오기';

  @override
  String get settingsFontTitle => '폰트 관리';

  @override
  String get settingsFontSubtitle => 'TTF/OTF 추가・검색・삭제';

  @override
  String get settingsNoResults => '해당하는 설정 항목을 찾을 수 없습니다';

  @override
  String get settingsTermsLicense => '이용약관・라이선스';

  @override
  String get settingsDrawingAreaTitle => '그리기 영역 초기값';

  @override
  String get settingsDrawingAreaHint => '새 프로젝트를 만들 때의 초기값으로 사용됩니다.';

  @override
  String get settingsDrawingAreaWiden => '그리기 영역 넓히기';

  @override
  String get settingsDrawingAreaScale => '배율';

  @override
  String settingsScaleValue(String scale) {
    return '$scale배';
  }

  @override
  String get commonCancel => '취소';

  @override
  String get commonCreate => '만들기';

  @override
  String get commonChange => '변경';

  @override
  String get commonDelete => '삭제';

  @override
  String get confirmDeleteGenericBody => '정말 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.';

  @override
  String confirmDeleteNamedBody(String name) {
    return '\"$name\"을(를) 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.';
  }

  @override
  String get commonFavoriteDeleteBlocked =>
      '즐겨찾기로 등록된 항목은 삭제할 수 없습니다. 먼저 즐겨찾기를 해제해 주세요.';

  @override
  String get commonSave => '저장';

  @override
  String get commonRestore => '복원';

  @override
  String get commonClose => '닫기';

  @override
  String get commonRename => '이름 변경';

  @override
  String get commonCopy => '복사';

  @override
  String get commonCut => '잘라내기';

  @override
  String get commonPaste => '붙여넣기';

  @override
  String get commonDuplicate => '복제';

  @override
  String homePasteTooltip(int count) {
    return '$count건 붙여넣기';
  }

  @override
  String get homePasteSnackbar => '붙여넣었습니다';

  @override
  String get commonOk => '확인';

  @override
  String get gestureSettingsTitle => '제스처 설정';

  @override
  String get gestureTwoFingerTap => '두 손가락 탭';

  @override
  String get gestureThreeFingerTap => '세 손가락 탭';

  @override
  String get gestureTwoFingerSwipe => '두 손가락 좌우 스와이프';

  @override
  String get gestureLongPress => '길게 누르기';

  @override
  String get gestureHoldEyedropperSection => '길게 눌러 색상 추출';

  @override
  String get gestureHoldEyedropperTitle => '길게 눌러 스포이트 실행';

  @override
  String get gestureHoldEyedropperHint =>
      '펜이나 지우개로 그리는 동안 손가락을 움직이지 않고 잠시 누르고 있으면 그 위치의 색상을 현재 색상으로 가져옵니다.';

  @override
  String get gestureHoldEyedropperDurationLabel => '유지 시간';

  @override
  String gestureHoldEyedropperSecondsValue(String seconds) {
    return '$seconds초';
  }

  @override
  String get gestureActionEyedropper => '스포이드';

  @override
  String get gestureActionPanTool => '손 도구';

  @override
  String get gestureActionEraserToggle => '지우개 전환';

  @override
  String get gestureActionBrushToggle => '브러시 전환';

  @override
  String get gestureActionFrameMove => '프레임 이동';

  @override
  String get gestureActionNextTool => '도구 빠른 전환';

  @override
  String get gestureActionOnionSkinToggle => '어니언 스킨 켜기/끄기';

  @override
  String get gestureActionNone => '아무 작업 안 함';

  @override
  String get homeDrawerAppTagline => '손그림 애니메이션 제작 앱';

  @override
  String get homeDrawerAutofillPreset => '자동 채색 설정';

  @override
  String get homeDrawerSettings => '설정';

  @override
  String get homeDrawerHelp => '도움말';

  @override
  String get homeDrawerTips => '활용 팁';

  @override
  String get homeDrawerPremium => 'Premium';

  @override
  String get gestureActionNoneShort => '없음';

  @override
  String get pressureTryDrawHint =>
      '이 설정으로 시험 삼아 그려볼 수 있습니다（펜의 경우 실제 필압이 반영됩니다）';

  @override
  String get pressureTryDrawClear => '지우기';

  @override
  String get penSettingsTitle => '펜 입력 설정';

  @override
  String get penSettingsCurveSection => '필압 곡선';

  @override
  String get penSettingsCurveHint =>
      '약하게 설정할수록 필압의 상승이 완만해지고, 강하게 설정할수록 급격해집니다.';

  @override
  String get penSettingsCurveWeak => '약함';

  @override
  String get penSettingsCurveNormal => '보통';

  @override
  String get penSettingsCurveStrong => '강함';

  @override
  String get penSettingsCurveCustom => '사용자 지정';

  @override
  String get penSettingsCustomGraphHint =>
      '그래프의 빈 곳을 탭하면 점을 추가하고(최대 10개), 점을 드래그하면 이동, 더블 탭하면 삭제할 수 있습니다(시작점과 끝점은 삭제할 수 없습니다).';

  @override
  String get penSettingsResetCurveButton => '기본값으로 재설정';

  @override
  String get penSettingsPerBrushNote =>
      '※ 필압의 \"크기/불투명도에 반영\" 설정은 브러시별 개별 설정입니다（브러시 설정 패널에서 변경）.';

  @override
  String get penSettingsButtonSection => '펜 버튼 설정';

  @override
  String get penSettingsButton1 => '버튼 1';

  @override
  String get penSettingsButton2 => '버튼 2';

  @override
  String get bucketSettingsTitle => '페인트 통 채우기 설정';

  @override
  String get bucketSettingsToleranceSection => '허용 오차';

  @override
  String get bucketSettingsToleranceHint =>
      '탭한 위치의 색상과 얼마나 차이가 나도 같은 영역으로 볼지 조정합니다. 값이 클수록 색 경계가 흐릿해도 채우기가 더 넓게 퍼집니다.';

  @override
  String get bucketSettingsExpandSection => '확장';

  @override
  String get bucketSettingsExpandHint =>
      '채운 영역을 경계 바깥으로 지정한 px만큼 넓혀, 선화와의 미세한 틈(칠 누락)을 덮습니다.';

  @override
  String get bucketSettingsUnderLineTitle => '선 아래로 파고들기';

  @override
  String get bucketSettingsUnderLineHint =>
      '확장된 부분을 선화 위에 그대로 덮지 않고, 선의 모습은 유지한 채 기존 픽셀 뒤쪽으로 채우기 색을 밀어 넣습니다. 선의 안티에일리어싱 부분에 틈이 잘 생기지 않습니다.';

  @override
  String get bucketSettingsUnderLineDisabledHint => '\"확장\"이 0px이면 효과가 없습니다.';

  @override
  String fontCatalogSearchHint(int count) {
    return '폰트 이름으로 검색...（총 $count종）';
  }

  @override
  String get fontCatalogAll => '전체';

  @override
  String get fontCatalogNoResults => '해당하는 폰트를 찾을 수 없습니다';

  @override
  String get rulerPanelTitle => '자';

  @override
  String get rulerTypeLine => '직선자';

  @override
  String get rulerTypeEllipse => '타원자';

  @override
  String get rulerTypeRadial => '집중선자';

  @override
  String get rulerTypeOnePoint => '1점 투시';

  @override
  String get rulerTypeTwoPoint => '2점 투시';

  @override
  String get rulerTypeThreePoint => '3점 투시';

  @override
  String get rulerDivisions => '분할 수';

  @override
  String get transferScreenTitle => '데이터 이전（.niatra）';

  @override
  String get transferInstructionHint => '다른 기기로 이전할 항목을 선택하세요.';

  @override
  String get transferItemSettings => '설정';

  @override
  String get transferItemMaterials => '소재';

  @override
  String get transferItemBrush => '브러시';

  @override
  String get transferItemPresets => '자동 채색 설정';

  @override
  String get transferItemTheme => '테마';

  @override
  String get transferItemPalette => '팔레트(색상 선택기·픽셀 아트 전용)';

  @override
  String get transferProjectsSectionTitle => '제작 중인 프로젝트(선택 사항)';

  @override
  String get transferProjectsHint =>
      '인계 내용에 포함할 프로젝트만 선택할 수 있습니다. 선택한 프로젝트는 소재·폰트를 포함해 통째로 인계됩니다.';

  @override
  String get transferProjectsEmpty => '프로젝트가 없습니다.';

  @override
  String get transferImport => '가져오기';

  @override
  String get transferExport => '내보내기';

  @override
  String get transferExportSuccessSnackbar => '.niatra 파일을 내보냈습니다';

  @override
  String transferExportFailedSnackbar(String error) {
    return '내보내기에 실패했습니다: $error';
  }

  @override
  String get transferImportSuccessSnackbar => '.niatra 파일을 가져왔습니다';

  @override
  String transferImportFailedSnackbar(String error) {
    return '가져오기에 실패했습니다: $error';
  }

  @override
  String get folderManagementTitle => '폴더 관리';

  @override
  String get folderManagementCreateNew => '새로 만들기';

  @override
  String get folderManagementEmpty => '아직 폴더가 없습니다';

  @override
  String get folderNameLabel => '폴더 이름';

  @override
  String get folderMoveToTitle => '폴더로 이동';

  @override
  String get folderNone => '폴더 없음';

  @override
  String get creativeAssetNameLabel => '이름';

  @override
  String get commonAdd => '추가';

  @override
  String get commonSearch => '검색';

  @override
  String get autofillPresetSelectionTitle => '사용할 자동 채색 설정';

  @override
  String get autofillPresetSelectionHint =>
      '이 프로젝트에서 사용하는 자동 채색 설정만 선택하면, 부위 할당 시 목록을 더 쉽게 볼 수 있습니다.';

  @override
  String autofillPresetSelectionPartCount(int count) {
    return '$count개 부위';
  }

  @override
  String get autofillPresetSelectionButton => '사용할 자동 채색 설정 선택';

  @override
  String get autofillPresetSelectionAllLabel => '전체 사용';

  @override
  String autofillPresetSelectionCountLabel(int count) {
    return '$count개 선택됨';
  }

  @override
  String get commonEdit => '편집';

  @override
  String get commonFavoriteToggle => '즐겨찾기 전환';

  @override
  String get commonIncrease => '늘리기';

  @override
  String get commonDecrease => '줄이기';

  @override
  String get commonPlay => '재생';

  @override
  String get commonPause => '일시정지';

  @override
  String get fontCatalogDownloadTooltip => '폰트 다운로드';

  @override
  String get timelineBackToCanvasTooltip => '저장하고 캔버스로 돌아가기';

  @override
  String get timelineBackToProjectListTooltip => '프로젝트 목록으로 돌아가기';

  @override
  String get timelineBackToProjectListDialogTitle => '프로젝트 목록으로 돌아가기';

  @override
  String get timelineBackToProjectListDialogBody => '변경 사항을 저장하고 돌아갈까요?';

  @override
  String get timelineBackToProjectListSaveButton => '저장하고 돌아가기';

  @override
  String get timelineBackToProjectListDiscardButton => '저장하지 않고 돌아가기';

  @override
  String get timelineSkipToStart => '첫 프레임으로 이동';

  @override
  String get timelineStepBack => '한 프레임 뒤로';

  @override
  String get timelineStepForward => '한 프레임 앞으로';

  @override
  String get timelineSkipToEnd => '마지막 프레임으로 이동';

  @override
  String get timelineLoopOnTooltip => '반복 재생: 켜짐 (탭하면 끄기)';

  @override
  String get timelineLoopOffTooltip => '반복 재생: 꺼짐 (탭하면 켜기)';

  @override
  String get quickToolPanelTitle => '빠른 도구 설정';

  @override
  String get quickToolEmpty => '등록된 도구가 없습니다';

  @override
  String get quickToolAddCurrentBrush => '현재 브러시 추가';

  @override
  String get quickToolEraser => '지우개';

  @override
  String get quickToolEyedropper => '스포이드';

  @override
  String get quickToolBucket => '페인트통';

  @override
  String quickToolSizeDialogTitle(String brushName) {
    return '$brushName 크기';
  }

  @override
  String get settingsShortcutTitle => '단축키 설정';

  @override
  String get settingsShortcutSubtitle => '키보드・왼손 장치에 도구와 동작을 할당';

  @override
  String get shortcutSettingsTitle => '단축키 설정';

  @override
  String get shortcutSettingsHint =>
      '키보드나 왼손 장치의 키에 도구(브러시・굵기까지 지정 가능)나 실행 취소/다시 실행 같은 동작을 할당할 수 있습니다. 캔버스・타임라인 양쪽에서 사용할 수 있습니다.';

  @override
  String get shortcutEmpty => '등록된 단축키가 없습니다';

  @override
  String get shortcutCaptureTitle => '키를 눌러주세요';

  @override
  String get shortcutCaptureHint =>
      '설정하고 싶은 키 조합을 눌러주세요（Ctrl・Shift・Alt 등의 보조키도 함께 누를 수 있습니다）. Esc로 취소합니다.';

  @override
  String shortcutChooseActionTitle(String combo) {
    return '$combo에 무엇을 할당하시겠습니까?';
  }

  @override
  String get shortcutActionTypeTool => '도구 선택';

  @override
  String get shortcutActionTypeCommand => '주요 동작';

  @override
  String get shortcutCommandUndo => '실행 취소';

  @override
  String get shortcutCommandRedo => '다시 실행';

  @override
  String get shortcutCommandToggleLayerPanel => '레이어 패널 전환（캔버스）';

  @override
  String get shortcutCommandPlayPause => '재생/일시정지（타임라인）';

  @override
  String get shortcutCommandPreviousFrame => '1프레임 뒤로（타임라인）';

  @override
  String get shortcutCommandNextFrame => '1프레임 앞으로（타임라인）';

  @override
  String get shortcutCommandSelectAll => '전체 선택';

  @override
  String get shortcutCommandCopy => '복사';

  @override
  String get shortcutCommandCut => '잘라내기';

  @override
  String get shortcutCommandPaste => '붙여넣기';

  @override
  String get shortcutConflictTitle => '이미 할당되어 있습니다';

  @override
  String shortcutConflictBody(String combo, String existingLabel) {
    return '$combo에는 이미 「$existingLabel」이(가) 할당되어 있습니다. 덮어쓰시겠습니까?';
  }

  @override
  String get shortcutConflictOverwrite => '덮어쓰기';

  @override
  String get materialListTitle => '소재 관리';

  @override
  String materialRemoveUnused(int count) {
    return '미사용 소재 삭제 ($count)';
  }

  @override
  String get materialEmptyTitle => '소재가 없습니다';

  @override
  String get materialEmptyHint => '타임라인에서 이미지・동영상・오디오를 추가하면\n여기에 표시됩니다';

  @override
  String get materialUsedLabel => '사용 중';

  @override
  String get materialUnusedLabel => '미사용';

  @override
  String get materialMissingLabel => '⚠ 누락';

  @override
  String get materialDeleteTooltipUsed => '사용 중이라 삭제할 수 없습니다';

  @override
  String get materialRemoveOneConfirmTitle => '소재를 삭제하시겠습니까?';

  @override
  String get materialRemoveUnusedConfirmTitle => '미사용 소재를 일괄 삭제하시겠습니까?';

  @override
  String get materialRemoveUnusedConfirmBody =>
      '프로젝트 내 어디에서도 참조되지 않는 소재를 모두 삭제합니다. 이 작업은 되돌릴 수 없습니다.';

  @override
  String materialRemovedSnackbar(int count) {
    return '미사용 소재 $count개를 삭제했습니다';
  }

  @override
  String get watermarkEmptyTitle => '등록된 워터마크가 없습니다';

  @override
  String get watermarkEmptyHint => '오른쪽 아래의 +에서 이미지 또는 문자를 등록하세요';

  @override
  String get watermarkAddFromImage => '이미지에서 추가';

  @override
  String get watermarkAddText => '문자 입력';

  @override
  String get watermarkAddedSnackbar => '워터마크를 등록했습니다';

  @override
  String get watermarkTextDialogTitle => '문자 워터마크 추가';

  @override
  String get watermarkTextFieldLabel => '표시할 문자';

  @override
  String get watermarkTextColorLabel => '글자 색';

  @override
  String get watermarkTextColorTapHint => '탭하여 색상 선택';

  @override
  String get watermarkDropShadowLabel => '그림자';

  @override
  String get watermarkShadowColorLabel => '그림자 색상';

  @override
  String get watermarkShadowOffsetXLabel => '그림자 위치 X';

  @override
  String get watermarkShadowOffsetYLabel => '그림자 위치 Y';

  @override
  String get watermarkShadowBlurLabel => '그림자 흐림';

  @override
  String get watermarkOutlineLabel => '테두리';

  @override
  String get watermarkOutlineColorLabel => '테두리 색상';

  @override
  String get watermarkOutlineWidthLabel => '테두리 두께';

  @override
  String get premiumActiveLabel => 'Premium 활성화됨';

  @override
  String get premiumVsTitle => '무료판 vs 프리미엄';

  @override
  String get premiumHeroTitle => '프리미엄으로 더 자유롭게';

  @override
  String get premiumHeroSubtitle =>
      '길이 제한 없음・워터마크 없음・톤 커브／레벨 보정 등 제작의 폭을 넓히는 기능이 모두 해제됩니다';

  @override
  String get premiumHeroHighlightDuration => '길이 최대 2시간';

  @override
  String get premiumHeroHighlightWatermark => '워터마크 없음';

  @override
  String get premiumHeroHighlightGrading => '톤 커브 /\n레벨 보정';

  @override
  String get premiumCampaignFreeNote =>
      '※ 캠페인 기간 중에는 무료판에서도 위 프리미엄 기능을 모두 이용하실 수 있습니다';

  @override
  String get premiumPlanSectionTitle => '플랜';

  @override
  String get premiumStoreUnavailable =>
      '스토어에 연결할 수 없습니다（실제 기기・스토어 심사 환경 이외에서는 구매할 수 없습니다）';

  @override
  String get premiumYearlyTitle => '연간 플랜（추천）';

  @override
  String get premiumYearlyDescription => '실질적으로 2개월 무료';

  @override
  String get premiumYearlyPrice => '¥5,500/년';

  @override
  String get premiumYearlyOriginalPrice => '¥6,600';

  @override
  String get premiumYearlyPerMonthLabel => '월 환산 ¥458';

  @override
  String get premiumMonthlyTitle => '월간 플랜';

  @override
  String get premiumRestorePurchases => '구매 복원';

  @override
  String get premiumRestoredSnackbar => '구매 정보를 복원했습니다（해당하는 구매가 있는 경우）';

  @override
  String get premiumCampaignBannerTitle => '출시 기념! 유료 회원 전용 기능 개방 캠페인';

  @override
  String get premiumCampaignBannerBody =>
      '기간 중에는 무료판에서도 모든 프리미엄 기능（길이 최대 2시간・엔드 로고 편집・워터마크・톤 커브・레벨 보정）을 무료로 이용하실 수 있습니다.';

  @override
  String premiumCampaignEndLabel(String date) {
    return '$date까지';
  }

  @override
  String get premiumComparisonFeature => '기능';

  @override
  String get premiumComparisonFree => '무료';

  @override
  String get premiumFeatureDrawing => '애니메이션 제작・드로잉 기능';

  @override
  String get premiumFeatureTimeline => '타임라인';

  @override
  String get premiumFeatureExport => '동영상 내보내기';

  @override
  String get premiumFeatureMaxDuration => '최대 길이';

  @override
  String get premiumFeatureEndLogo => '공식 엔드 로고';

  @override
  String get premiumFeatureWatermark => '워터마크';

  @override
  String get premiumFeatureToneCurve => '톤 커브';

  @override
  String get premiumFeatureLevelCorrection => '레벨 보정';

  @override
  String get premiumFeatureAds => '광고';

  @override
  String get premiumFeatureCommunityUpload => '하루 커뮤니티 게시 수';

  @override
  String get premiumValueYes => '있음';

  @override
  String get premiumValueNo => '없음';

  @override
  String get premiumValueRemovable => '삭제 가능';

  @override
  String get premiumValueDuration2Hours => '2시간';

  @override
  String get premiumValueDuration90Sec => '1.5분';

  @override
  String get premiumValueUploadFree => '1개';

  @override
  String get premiumValueUploadPremium => '3개';

  @override
  String get premiumPlanRecommendedBadge => '추천';

  @override
  String get premiumMonthlyPrice => '¥550/월';

  @override
  String get toolbarItemPen => 'G펜';

  @override
  String get toolbarItemEraser => '지우개';

  @override
  String get toolbarItemBucket => '페인트통';

  @override
  String get toolbarItemEyedropper => '스포이드';

  @override
  String get toolbarItemFinger => '손가락';

  @override
  String get toolbarItemPan => '손바닥';

  @override
  String get toolbarItemSelect => '선택';

  @override
  String get toolbarItemTransform => '변형';

  @override
  String get toolbarItemText => '텍스트';

  @override
  String get toolbarItemShape => '도형';

  @override
  String get workspaceScreenTitle => '작업 공간 설정';

  @override
  String get workspaceToolbarEditSection => '도구 모음 편집';

  @override
  String get workspaceToolbarEditHint =>
      '체크박스로 표시할 도구를 선택하고, 드래그하여 순서를 바꿀 수 있습니다.';

  @override
  String get workspaceToolbarPcOnlyHint => '가로 화면일 때만 도구 모음에 표시됩니다';

  @override
  String get workspaceToolbarPanDisabledHint => '스마트폰 모드에서는 사용할 수 없습니다';

  @override
  String get workspaceResetToolbarDefault => '기본값으로 되돌리기';

  @override
  String get workspacePanelLayoutSection => '패널 배치';

  @override
  String get workspaceLeftHandedMode => '왼손잡이 모드';

  @override
  String get workspaceLeftHandedSubtitlePc => '패널을 오른쪽에 배치';

  @override
  String get workspaceLeftHandedSubtitleMobile => 'PC/DeX 모드에서만 설정할 수 있습니다';

  @override
  String get workspacePcModeSection => 'PC 모드（DeX）';

  @override
  String get workspacePcModeHint =>
      '화면 폭이 넓은 환경에서는 패널이 고정 배치되는 전문가용 화면 구성으로 자동 전환됩니다. 수동으로 고정하려면 여기서 지정하세요.';

  @override
  String get workspacePcModeAuto => '자동（화면 폭으로 판단・권장）';

  @override
  String get workspacePcModeAlwaysPc => '항상 PC 모드';

  @override
  String get workspacePcModeAlwaysMobile => '항상 모바일 모드';

  @override
  String get workspaceSaveSection => '작업 공간 저장';

  @override
  String get workspaceSaveHint =>
      '왼손잡이 모드・PC 모드・도구 모음・빠른 도구 설정을 이름을 붙여 저장하고, 나중에 불러올 수 있습니다.';

  @override
  String get workspaceSaveCurrentButton => '현재 작업 공간 저장';

  @override
  String get workspaceLoadButtonEmpty => '작업 공간 불러오기（저장된 항목 없음）';

  @override
  String get workspaceLoadButton => '작업 공간 불러오기';

  @override
  String get workspaceEmptyToolbar => '표시할 도구가 없습니다';

  @override
  String get workspaceSaveDialogTitle => '작업 공간 저장';

  @override
  String get workspaceSaveDialogLabel => '이름（예: 애니메이션용・선화용）';

  @override
  String get workspaceLoadRightHanded => '오른손잡이';

  @override
  String get workspaceLoadLeftHanded => '왼손잡이';

  @override
  String get helpScreenTitle => '도움말';

  @override
  String get helpSearchHint => '검색...';

  @override
  String get helpNoResults => '해당하는 항목을 찾을 수 없습니다';

  @override
  String get helpCategoryTool => '도구';

  @override
  String get helpCategoryLayer => '레이어';

  @override
  String get helpCategoryAnimation => '애니메이션';

  @override
  String get helpCategoryDrawing => '그리기';

  @override
  String get helpCategoryBrush => '브러시';

  @override
  String get helpCategoryPenInput => '펜 입력';

  @override
  String get helpCategorySave => '저장';

  @override
  String get helpCategoryProjectManagement => '프로젝트 관리';

  @override
  String get helpCategoryExport => '내보내기';

  @override
  String get helpCategoryPremium => 'Premium';

  @override
  String get helpCategorySettings => '설정';

  @override
  String get helpCategoryCommunity => '커뮤니티';

  @override
  String get helpPenToolTitle => '펜 도구';

  @override
  String get helpPenToolDesc =>
      '캔버스에 선을 그리는 기본 도구입니다. 길게 누르면 브러시 종류・굵기・색을 변경할 수 있습니다（더블탭은 간단 설명 표시）. 펜 태블릿・액정 태블릿의 필압・기울기를 지원하며, 설정 화면의 「펜 입력」에서 필압 곡선을 조정하면 필압이 반영되는 방식（약한 힘으로 굵기・불투명도가 얼마나 변하는지）을 세밀하게 커스터마이즈할 수 있습니다. 펜 서브 도구를 전환하면 같은 펜 도구로 톤 붙이기・스탬프 배치도 할 수 있습니다.';

  @override
  String get helpEraserToolTitle => '지우개 도구';

  @override
  String get helpEraserToolDesc =>
      '펜 도구와 짝을 이루는, 그린 내용을 지우기 위한 도구입니다. 브러시와 마찬가지로 굵기・불투명도를 조정할 수 있고, 페이드나 스트로크 감쇠 등의 브러시 설정도 공통으로 반영됩니다. 레이어의 투명한 부분에 「덧그리는」 것이 아니라 기존 그림을 「지우는」 처리를 하므로, 아래 레이어가 비쳐 보이게 됩니다.';

  @override
  String get helpBucketToolTitle => '페인트통 도구';

  @override
  String get helpBucketToolDesc =>
      '둘러싸인 영역을 한 번에 채우는 도구입니다. 선화로 둘러싸인 범위 안을 탭하면 그 범위 전체가 선택 중인 색（또는 톤）으로 채워집니다. 선화에 틈이 있으면 의도치 않은 범위까지 채워질 수 있으므로, 선화가 제대로 닫혀 있는지 확인한 후 사용하는 것이 요령입니다. 설정에서 단색 채우기/톤 채우기를 전환할 수 있습니다. 상세 설정(허용 오차・확장 px・선 아래로 파고들기)은 설정 화면의 \"페인트 통 채우기\"에서 조정할 수 있습니다.';

  @override
  String get helpLassoFillTitle => '올가미 채우기';

  @override
  String get helpLassoFillDesc =>
      '둘러싸고 싶은 범위를 손가락으로 따라 그려 다각형 영역을 만들고, 그 안쪽을 한꺼번에 채우는 도구입니다. 페인트통 도구와 달리 선화가 닫혀 있지 않은 부분이 있어도 직접 둘러쌀 범위를 지정할 수 있어, 복잡한 형태나 선이 끊긴 부분을 채우는 데 적합합니다.';

  @override
  String get helpEyedropperToolTitle => '스포이드 도구';

  @override
  String get helpEyedropperToolDesc =>
      '탭한 위치의 색을 추출하여 그리기 색으로 선택하는 도구입니다. 화면에 실제로 표시되는 모든 레이어를 합성한 색을 추출하므로, 여러 레이어가 겹쳐 있는 부분에서도 「보이는 그대로의 색」을 정확하게 가져올 수 있습니다.';

  @override
  String get helpSelectToolTitle => '선택 도구';

  @override
  String get helpSelectToolDesc =>
      '캔버스의 일부를 범위 선택하여, 선택한 범위만 이동・회전・확대축소할 수 있는 도구입니다. 길게 누르면 「사각형 선택」「올가미 선택（자유로운 형태로 둘러싸기）」「자동 선택（매직 완드, 비슷한 색상의 범위를 자동으로 묶어 선택）」의 3가지 선택 방법 중에서 고를 수 있습니다. 선택 중에는 선택 범위를 나타내는 테두리가 캔버스 위에 표시되며, 선택을 해제할 때까지 모든 프레임・모든 레이어에서 같은 범위가 고정 표시됩니다.';

  @override
  String get helpFingerToolTitle => '손가락 도구（왜곡 도구）';

  @override
  String get helpFingerToolDesc =>
      '손가락으로 문지른 방향으로 픽셀을 밀어내듯 왜곡시켜, 손가락으로 젖은 물감을 문지른 듯한 효과를 만드는 도구입니다. 세밀한 수정보다는 이미 그린 선을 유기적으로 왜곡시켜 표정을 더하고 싶을 때 사용합니다.';

  @override
  String get helpShapeToolTitle => '도형 도구';

  @override
  String get helpShapeToolDesc =>
      '직선・사각형・원 같은 정확한 도형을 한 번의 동작으로 그리는 도구입니다. 드래그로 시작점에서 끝점까지 움직이면 그 자리에서 미리보기가 표시되고, 손을 떼면 확정됩니다. 프리핸드로는 그리기 어려운 직선이나 정원이 필요할 때 편리합니다.';

  @override
  String get helpTextToolTitle => '텍스트 도구';

  @override
  String get helpTextToolDesc =>
      '캔버스 위에 문자를 배치하는 도구입니다. 글꼴・크기・색・세로쓰기/가로쓰기를 선택할 수 있습니다. 세로쓰기에서는 반각 영숫자의 자동 회전・다테추요코（숫자를 가로 방향 그대로 나열하는 표기）・루비（후리가나）에도 대응합니다. 배치한 텍스트는 내보내기 시에도 픽셀로 구워집니다. 텍스트 도구에서 사용할 폰트를 추가・검색・삭제할 수 있는 화면입니다. 기본 내장 폰트 외의 추가 무료 폰트는, 초기 설치 용량을 줄이기 위해 이곳에서 필요할 때 다운로드하는 방식으로 되어 있습니다.';

  @override
  String get helpQuickToolTitle => '빠른 도구';

  @override
  String get helpQuickToolDesc =>
      '자주 쓰는 브러시・도구 조합을 미리 등록해두고 버튼 하나로 순서대로 전환할 수 있는 기능입니다. 캔버스의 ↺ 버튼을 길게 누르거나 위로 스와이프하면 등록・순서 변경・삭제가 가능한 관리 팝업이 열립니다. 드래그로 순서를 바꿀 수 있습니다.';

  @override
  String get helpLayerTitle => '레이어';

  @override
  String get helpLayerDesc =>
      '하나의 캔버스를 여러 개의 투명한 「층」으로 나누어 그릴 수 있는 구조입니다. 선화・채색・배경 등을 각각 다른 레이어에 나누어 그리면, 나중에 색만 다시 칠하거나 선화를 지우지 않고 배경만 교체할 수 있습니다. 화면상에서는 위에 겹쳐진 레이어일수록 앞쪽에 표시됩니다. 각 레이어 행의 아이콘에서 원탭으로 삭제・아래 레이어와의 결합을 할 수 있으며, 레이어 패널 상단 아이콘에서 표시 중인 모든 레이어를 한꺼번에 결합할 수도 있습니다.';

  @override
  String get helpBlendModeTitle => '블렌드 모드';

  @override
  String get helpBlendModeDesc =>
      '레이어의 합성 방법을 바꾸는 기능입니다. 톤이나 색상 효과를 레이어로 겹칠 때 자주 사용됩니다.\n표준: 그대로 겹칩니다.\n곱하기: 아래 레이어와 곱해 어둡게 합니다. 그림자, 음영 표현의 정석입니다.\n스크린: 밝기를 더해 밝게 합니다. 빛 표현에 적합합니다.\n오버레이: 어두운 부분은 더 어둡게, 밝은 부분은 더 밝게 해 대비를 강조합니다.\n더하기: 색을 단순히 더합니다. 빛 효과선 등에 적합합니다.\n빼기: 색을 뺀 값으로, 어둡게 가라앉은 효과가 됩니다.\n어둡게 비교: 위아래 레이어 중 어두운 쪽 색을 채택합니다.\n밝게 비교: 위아래 레이어 중 밝은 쪽 색을 채택합니다.\n색상 번: 아래 색을 어둡게 가라앉히며 진하게 발색시킵니다.\n색상 닷지: 아래 색을 밝게 날리며 발색시킵니다.\n하드 라이트: 오버레이보다 강하게 대비가 붙습니다.\n소프트 라이트: 오버레이보다 부드럽게 대비가 붙습니다. 부드러운 음영에 적합합니다.\n차이: 위아래 색의 차이를 표시합니다. 색상 어긋남 확인 등에 씁니다.\n색조, 채도, 색상, 광도: 각각 색조, 채도, 색감, 밝기만을 아래 레이어에 반영합니다.';

  @override
  String get helpClippingTitle => '클리핑';

  @override
  String get helpClippingDesc =>
      '바로 아래에 있는 레이어의 불투명한 픽셀 범위 안에만 그려지도록 하는 기능입니다. 선화를 벗어나지 않게 채색하고 싶을 때, 선화 레이어 위에 채색용 레이어를 만들고 클리핑을 활성화하면 선화 바깥으로 실수로 삐져나가 그릴 걱정이 없어집니다.';

  @override
  String get helpCommonLayerTitle => '공통 레이어';

  @override
  String get helpCommonLayerDesc =>
      '일반 레이어는 프레임마다 독립되어 있지만, 공통 레이어는 여러 프레임・씬에서 같은 내용을 공유하는 레이어입니다. 배경처럼 프레임이 바뀌어도 움직이지 않는 요소를 프레임마다 다시 그릴 필요 없이 한 번만 그리면 됩니다. 타임라인에서는 전용 트랙으로 표시됩니다. 일반 레이어를 공통 레이어（여러 프레임에 같은 내용을 계속 표시하는 레이어）로 변환할 수 있는 기능입니다. 표시 중인 레이어를 복제해 한 장으로 통합한 뒤 공통화할 수도 있습니다. 배경처럼 매 프레임 같은 내용을 재사용하고 싶을 때 다시 그리는 수고를 줄일 수 있습니다.';

  @override
  String get helpAutoFillTitle => '자동 채색';

  @override
  String get helpAutoFillDesc =>
      '자동 채색용 선화 레이어 아래에 자동 채색 레이어를 만들고, 미리 만들어 둔 「자동 채색 설정」（부위별 색・톤 조합）을 바탕으로 색을 자동으로 채우는 기능입니다. 선화를 다 그린 후 한 번에 채색할 수 있어, 같은 캐릭터를 여러 번 그리는 손그림 애니메이션에서 채색 작업을 크게 줄일 수 있습니다. 선화를 다시 그리면 타임라인・레이어 패널에 업데이트 표시（❗）가 나타나 자동 채색을 다시 실행해야 함을 알려줍니다. 타임라인 화면의 점 3개 메뉴에서 「자동 채색 실행」을 선택하면, 업데이트 표시（❗）가 붙은 자동 채색 레이어를 한꺼번에 다시 계산할 수 있습니다. 선화를 다시 그린 뒤 레이어 패널에서 한 장씩 실행하는 수고를 덜 수 있습니다. 자동 채색 설정의 각 부위에는 선화 색을 어떻게 처리할지에 대한 설정（지정 색・채색 색과 동일・색 트레이스）이 있습니다. 색 트레이스（선화 어우러짐）를 선택하면 선화 색을 채색 색에 맞춰 HSL 이동시켜, 선이 튀지 않고 자연스럽게 어우러집니다. 설정이 늘어나면 부위 할당 시 목록이 길어져 고르기 어려워집니다. 프로젝트 설정（또는 레이어 패널의 부위 할당 대화 상자）에서 이 프로젝트에서 사용하는 설정만 필터링해두면 목록이 깔끔해져 고르기 쉬워집니다.';

  @override
  String get helpOnionSkinTitle => '어니언 스킨';

  @override
  String get helpOnionSkinDesc =>
      '현재 편집 중인 프레임의 앞뒤 프레임을 반투명하게 겹쳐 표시하여, 움직임의 흐름을 확인하며 그릴 수 있게 하는 기능입니다. 성능 설정에서 표시할 매수（앞뒤로 몇 장까지）나 색・투명도를 조정할 수 있습니다.';

  @override
  String get helpRulerTitle => '자';

  @override
  String get helpRulerDesc =>
      '직선・원・타원・투시자（소실점을 이용한 투시도법용 자） 등, 프리핸드로는 그리기 어려운 정확한 선을 보조하는 기능입니다. 배치한 자를 따라 펜 끝이 자동으로 스냅되므로, 자가 없으면 어려운 원근감 있는 구도도 그리기 쉬워집니다. 자는 핸들을 조작하여 이동・회전・크기 변경을 할 수 있습니다.';

  @override
  String get helpFadeTitle => '페이드';

  @override
  String get helpFadeDesc =>
      '브러시 설정 중 하나로, 스트로크를 그려나갈수록 불투명도나 굵기가 점점 줄어드는 효과입니다. 선의 끝을 흐릿하게 하고 싶을 때나, 여운이 남는 듯한 화풍을 만들고 싶을 때 사용합니다.';

  @override
  String get helpStrokeDecayTitle => '스트로크 감쇠';

  @override
  String get helpStrokeDecayDesc =>
      '페이드와 비슷하지만, 이쪽은 「잉크가 줄어드는」 듯한 표현에 가까워, 계속 그릴수록 색이 옅어지거나 흐려지는 효과입니다. 붓이나 마커로 계속 그렸을 때 잉크가 떨어지는 듯한 질감을 재현합니다.';

  @override
  String get helpColorMixingTitle => '혼색';

  @override
  String get helpColorMixingDesc =>
      '브러시로 칠할 때, 브러시 바로 아래에 이미 있는 색과 지금 칠하려는 선택 색을 섞으면서 그리는 기능입니다. 수채화나 유화처럼 기존 색에 새로운 색을 자연스럽게 섞고 싶을 때 사용합니다.';

  @override
  String get helpPressureCurveTitle => '필압 곡선';

  @override
  String get helpPressureCurveDesc =>
      '펜 입력 설정에 있는 기능으로, 실제 필압의 세기와 브러시의 굵기・불투명도에 반영되는 방식의 관계를 그래프로 자유롭게 조정할 수 있습니다. 약한 필압에서도 굵게 나오길 원하는 사람, 반대로 강하게 눌러야만 굵어지길 원하는 사람 등, 필기 습관에 맞춰 그리는 느낌을 세밀하게 커스터마이즈할 수 있습니다. 설정 변경 후에는 그 자리에서 시험 삼아 그려보며 확인할 수 있습니다.';

  @override
  String get helpTimelineTitle => '타임라인';

  @override
  String get helpTimelineDesc =>
      '애니메이션의 시간축을 관리하는 화면입니다. 프레임（정지 화면 1컷）을 나열하여 플립북처럼 재생하면 애니메이션이 됩니다. 이미지・동영상・오디오 등의 소재 트랙, 공통 레이어 트랙, 카메라 키프레임도 같은 타임라인에서 관리합니다.';

  @override
  String get helpSceneTitle => '씬';

  @override
  String get helpSceneDesc =>
      '하나의 프로젝트（동영상 한 편） 안을 장면（컷）별로 나누어 관리하는 기능입니다. 폴더가 프로젝트 단위의 정리라면, 신은 한 편의 동영상 안에서 장면 전환을 표현하는 데 사용합니다. 타임라인의 신 탭에서는 신 추가・복제・삭제・이름 변경・순서 변경이 가능합니다. 다중 선택 모드로 전환하면 여러 신을 한 번에 이동・복제・삭제할 수도 있습니다.';

  @override
  String get helpCameraKeyframeTitle => '카메라 키프레임';

  @override
  String get helpCameraKeyframeDesc =>
      '타임라인 상의 특정 위치에 카메라의 위치・확대율・회전을 기록해 두는 기능입니다. 키프레임 사이는 자동으로 부드럽게 보간되므로, 팬（좌우 이동）이나 줌인・줌아웃 같은 카메라 워크를 쉽게 넣을 수 있습니다.';

  @override
  String get helpEffectFilterTitle => '연출 필터';

  @override
  String get helpEffectFilterDesc =>
      '씬이나 프레임에 적용할 수 있는 영상 효과（블러・색조 보정・글로우・픽셀화 등）입니다. 손그림 자체는 바꾸지 않고, 연출로서 화면 전체의 느낌을 조정하고 싶을 때 사용합니다. 픽셀화는 배색 방식（색을 지정하지 않음・색을 지정함・색 수를 지정함・팔레트에서 선택）도 고를 수 있습니다. 연출 필터는 여러 개를 겹쳐서 적용할 수 있으며, 그 적용 순서는 타임라인상의 배열 순서를 따릅니다. 필터 목록을 드래그로 재배열하면 실제로 화면에 반영되는 순서도 바뀝니다. 필름의 입자감 같은 노이즈를 프레임마다 변화시키며 적용하는 연출 필터입니다. 강도・양（노이즈가 올라가는 밀도）・입자 크기를 슬라이더로 조정할 수 있습니다. 같은 프레임으로 돌아오면 같은 입자 모양이 되므로 스크러빙 중에는 깜빡이지 않고, 재생하면 입자가 움직이는 것처럼 보입니다. 화면에 내리는 비를 표현하는 연출 필터입니다. 내리는 정도（빗방울 수）・속도・빗방울 크기・바람 방향 각도를 슬라이더로 조정할 수 있습니다. 각 빗방울은 프레임이 진행될수록 일정한 속도로 계속 내리므로 자연스러운 비의 움직임이 됩니다.';

  @override
  String get helpEndCardTitle => 'EndCard（엔드 로고）';

  @override
  String get helpEndCardDesc =>
      '동영상 내보내기 시, 본편이 끝난 후 자동으로 추가되는 NIARIM 로고의 짧은 영상（약 5초）입니다. 무료판에서는 숨기거나 삭제할 수 없지만, 프리미엄 회원이 되면 표시 ON/OFF・길이 변경・교체가 가능해집니다.';

  @override
  String get helpAutoSaveTitle => '자동 저장';

  @override
  String get helpAutoSaveDesc =>
      '충돌이나 파일 손상이 발생했을 때를 위한 복원 전용 저장입니다. 그리기 등의 변경이 있을 때마다 자동으로 저장되며, 최대 3개까지 오래된 순서로 덮어씌워집니다. 수동 저장（세이브 슬롯・세이브 트리）과는 완전히 별도로 관리되며, 일반 저장을 대체하지는 않습니다. 앱이 비정상 종료된 후 재시작할 때만 복원할지 묻습니다.';

  @override
  String get helpSaveSlotTitle => '세이브 슬롯';

  @override
  String get helpSaveSlotDesc =>
      '정해진 수의 저장 칸（슬롯）에, 직접 저장 위치를 선택하며 저장하는 방식입니다. 슬롯 수는 설정（저품질 5개・중품질 10개）으로 정해집니다. 덮어쓸 칸을 매번 직접 선택하므로, 「이 시점의 상태는 남겨두고 싶다」는 관리가 쉬운 방식입니다.';

  @override
  String get helpSaveTreeTitle => '세이브 트리';

  @override
  String get helpSaveTreeDesc =>
      '저장할 때마다 새로운 저장 지점이 만들어지고, 과거의 저장 지점에서 분기하여 다른 히스토리를 만들 수 있는（가지가 나뉘는） 저장 방식입니다. 개수 제한이 없어, 「그때 그 버전으로 돌아가서 다른 전개를 시도해 보고 싶다」는 사용법에 적합합니다. 화면에는 저장 지점이 아래에서 위로 뻗어나가는 나무 모양 도표로 표시됩니다.';

  @override
  String get helpFolderTitle => '폴더';

  @override
  String get helpFolderDesc =>
      '프로젝트（작품）를 그룹화하여 정리하는 기능입니다. 여러 계층을 지원하므로, 같은 작품의 여러 화차나 시리즈물을 함께 관리하는 용도로도 사용할 수 있습니다（예: 「작품명」 폴더 안에 「제1화」「제2화」…처럼 프로젝트를 나열）. 하나의 동영상 안에서 장면을 나누어 만들고 싶을 때는 폴더가 아니라 캔버스 화면의 「씬」 기능을 이용해 주세요.';

  @override
  String get helpTrashTitle => '휴지통';

  @override
  String get helpTrashDesc =>
      '삭제한 프로젝트가 임시로 이동하는 곳입니다. 완전히 삭제되기 전까지는 여기서 복원할 수 있습니다. 설정에서 자동 삭제까지의 일수（끔/30일/60일/90일）를 지정할 수 있습니다.';

  @override
  String get helpShareTitle => '공유（.niashare）';

  @override
  String get helpShareDesc =>
      '프로젝트를 다른 사람（또는 자신의 다른 기기）에게 전달하기 위한 공유 전용 파일 형식입니다. 받은 쪽이 이 파일을 열면 복제되어 자신의 프로젝트 목록에 추가됩니다. 공유 원본인 .niashare 파일 자체는 변경되지 않습니다.';

  @override
  String get helpTransferTitle => '데이터 이전（.niatra）';

  @override
  String get helpTransferDesc =>
      '설정・소재・브러시・자동 채색 설정・테마・팔레트(색상 선택기·픽셀 아트 전용) 등 앱 전체 환경을 다른 기기로 한꺼번에 이전하는 기능입니다. 이전할 항목은 체크박스로 개별 선택할 수 있습니다. 개별 프로젝트를 전달하고 싶을 때는 「공유（.niashare）」를 사용하세요.';

  @override
  String get helpVideoExportTitle => '동영상 내보내기（MP4・WebM・GIF）';

  @override
  String get helpVideoExportDesc =>
      '작품을 범용 MP4 동영상으로 내보냅니다. 무료 버전은 내보낼 수 있는 길이에 제한(90초)이 있으며, 동영상 끝에 엔드카드(앱 로고)가 자동으로 추가됩니다. 알파 채널（배경의 투명 부분）을 유지한 채 내보낼 수 있는 동영상 형식입니다. 지원하는 재생 환경에서만 투명하게 재생됩니다. 다른 앱의 소재로 겹쳐서 사용하고 싶을 때 적합합니다. 애니메이션 GIF로 내보냅니다. 자동으로 반복 재생되는 형식이라 SNS 공유 등 가볍게 공유하고 싶을 때 적합합니다. 호환성을 중시한다면 AVI（Motion JPEG）로도 내보낼 수 있습니다. 특허・라이선스 면에서 안전한 코덱을 채택했지만 알파 채널（투명）은 지원하지 않으며, 기기에 따라 앱 내 미리보기가 되지 않을 수 있습니다（그 경우에도 「공유」에서 외부 플레이어로 재생할 수 있습니다）. 무료 회원은 프로젝트 길이에 90초까지의 상한이 있습니다（프리미엄 회원은 2시간）. 프레임 추가・복제로 상한을 넘어설 것 같으면 버튼을 탭한 순간 주의 대화상자가 표시되어, 실제로 90초를 넘지 않도록 되어 있습니다.';

  @override
  String get helpTransparentWebmTitle => '투명 WebM';

  @override
  String get helpCommunityTitle => '작품 광장';

  @override
  String get helpCommunityDesc =>
      '애니메이션・일러스트 작품을 YouTube 동영상으로 커뮤니티에 게시하고, 다른 사용자의 작품을 둘러볼 수 있는 기능입니다. 「신작」・「랭킹」・「팔로잉」 탭을 전환할 수 있으며, 작품 제목 또는 게시자 이름으로 검색할 수 있습니다. 태그 검색 모드로 전환하면 태그로 작품을 좁혀볼 수 있으며, 태그는 게시자 외의 사용자도 자유롭게 추가・삭제할 수 있습니다（게시자가 잠근 태그는 게시자 본인만 해제할 수 있습니다）. 태그를 탭하기만 해도 같은 태그의 작품으로 좁혀집니다. 작품 카드를 탭하면 드래그・크기 조절이 가능한 플로팅 미리보기 창이 열려 다른 화면을 조작하면서도 계속 시청할 수 있습니다. 「상세보기」 버튼으로 작품의 상세 화면（게시자・게시일・태그 편집・북마크・리포스트 등）을 열 수 있습니다. 게시자 이름 옆의 「팔로우」 버튼을 누르면 팔로우가 되어, 「팔로잉」 탭에서 그 작가의 게시물만 최신순으로 모아 볼 수 있습니다. 누군가 나를 팔로우하면 화면 오른쪽 위 종 모양 아이콘의 알림 목록에 표시됩니다. 자신의 팔로잉/팔로워 목록을 다른 사용자에게 공개할지 여부를 설정할 수 있으며（기본값은 비공개）, 공개로 설정한 다른 사용자의 목록도 볼 수 있습니다. 다른 사람의 작품（자신의 게시물은 제외）은 「리포스트」 버튼으로 재게시할 수 있으며, 팔로우 중인 작가가 누군가의 작품을 리포스트하면 그 작품도 「게시일」과 「리포스트한 날짜」 중 더 최근인 쪽을 기준으로 「팔로잉」 탭에 섞여 표시됩니다（카드에 「○○님이 리포스트함」이라고 표시）. 북마크한 작품은 홈 화면의 「북마크됨」 탭에 모아서 표시되며, 게시자별 작품 목록 화면의 「북마크」 탭에서도 확인할 수 있습니다. 자신의 북마크 목록을 다른 사용자에게 공개할지 여부를 설정할 수 있으며（기본값은 비공개）, 공개로 설정한 다른 사용자의 북마크 목록도 볼 수 있습니다. 부적절한 작품은 사유를 첨부해 신고할 수 있으며, 신고 후에는 해당 게시자를 차단할지 선택할 수 있습니다. 세로로 긴 동영상은 「세로 화면 모드」에서 연속 재생으로 시청할 수 있습니다. 하루에 게시할 수 있는 작품 수에는 상한이 있으며, 무료 회원은 하루 1개, 프리미엄 회원은 하루 3개까지입니다.';

  @override
  String get helpWatermarkEntryTitle => '워터마크';

  @override
  String get helpWatermarkEntryDesc =>
      '내보낸 동영상・이미지에 자신의 서명이나 로고를 워터마크로 넣을 수 있는 프리미엄 전용 기능입니다. 위치・크기・불투명도를 조정할 수 있습니다. 타임라인의 공통 레이어 트랙에 배치한 워터마크를 탭하면 각도・크기・불투명도・표시 범위（루프 표시）를 언제든지 다시 편집할 수 있습니다. 등록할 때뿐 아니라 실제로 프로젝트에서 사용할 때도 세세하게 조정할 수 있습니다.';

  @override
  String get helpPremiumEntryTitle => '프리미엄';

  @override
  String get helpPremiumEntryDesc =>
      '프리미엄 회원이 되면 무료 버전에서 90초로 제한된 동영상 길이가 최대 2시간까지 늘어나고, 모든 동영상 끝에 자동 추가되는 엔드카드(앱 로고)를 삭제할 수 있습니다. 광고도 숨겨지며, 워터마크, 톤 커브, 레벨 보정 기능도 사용할 수 있게 됩니다.';

  @override
  String get helpPerformanceSettingsTitle => '성능 설정';

  @override
  String get helpPerformanceSettingsDesc =>
      '기기 성능에 따라 저품질・중품질・고품질 프리셋 중에서 선택하거나, 각 항목을 개별로 설정（커스텀）할 수 있습니다. 저장 방식・동작 속도・어니언 스킨・기울기 감지 외에도, 실행 취소 횟수나 휴지통 자동 삭제 등 앱의 용량・동작 부담에 영향을 주는 설정도 여기에 모여 있습니다.';

  @override
  String get helpMaterialClipTitle => '소재 클립（이미지・동영상・오디오）';

  @override
  String get helpMaterialClipDesc =>
      '타임라인의 이미지・동영상・오디오 트랙에 배치한 클립입니다. 클립 본체를 길게 눌러 드래그하면 표시 시작 위치를 옮길 수 있고, 좌우 끝의 손잡이를 드래그하면 사용 범위（길이）를 바꿀 수 있습니다. 클립을 탭하면 열리는 상세 시트의 복사 아이콘으로 복제, 휴지통 아이콘으로 삭제도 가능합니다. 이미지・동영상은 내부적으로 레이어로 취급되며, 오디오는 장면에 직접 연결된 클립으로 관리됩니다.';

  @override
  String get helpGestureSettingsTitle => '제스처 설정';

  @override
  String get helpGestureSettingsDesc =>
      '두 손가락 탭・세 손가락 탭・두 손가락 스와이프・길게 누르기에 실행 취소/다시 실행・프레임 이동・스포이트 등의 동작을 할당할 수 있는 설정입니다. 펜 버튼（지원 스타일러스 사용 시）에도 별도로 동작을 할당할 수 있습니다. 도구를 바꾸지 않고 자주 쓰는 동작을 한 번에 불러오고 싶을 때 편리합니다.';

  @override
  String get helpBucketDetailSettingsTitle => '버킷 채우기 세부 설정';

  @override
  String get helpBucketDetailSettingsDesc =>
      '설정 화면의 「버킷 채우기」에서 허용 오차（클릭한 위치의 색에서 어디까지의 색 차이를 같은 영역으로 볼지）・확장 px（채운 영역을 경계 바깥쪽으로 넓혀 선화와의 틈을 메우는 정도）・선 아래까지 파고들기（확장분을 선화 위에 덮어쓰지 않고, 선의 모양은 유지한 채 뒤쪽으로 채우기 색을 합성）를 조정할 수 있습니다. 선화에 작은 틈이 있거나 덜 칠해진 부분이 신경 쓰일 때 조정하면 마무리가 안정됩니다.';

  @override
  String get helpStampToolTitle => '스탬프 도구';

  @override
  String get helpStampToolDesc =>
      '미리 등록해 둔 이미지를 브러시처럼 캔버스에 배치하는 도구입니다. 효과선・배경 패턴・소품 등을 매번 다시 그리지 않고 재사용할 수 있습니다. 픽셀 모드를 켜면 붙인 스탬프를 모자이크 저해상도화＋색상 수 감소로 도트 그림풍으로 가공할 수 있습니다. 스탬프 패널에서는 배치할 스탬프의 회전 각도・크기를 조정할 수 있습니다. 같은 스탬프라도 방향과 크기를 바꿔가며 배치하면 단조롭지 않은 자연스러운 효과선・소품 배열을 만들 수 있습니다.';

  @override
  String get helpToneFillTitle => '톤 채색';

  @override
  String get helpToneFillDesc =>
      '버킷 도구 설정에서 단색 채우기를 톤 채우기로 바꾸면 선택한 망점・선 무늬 등의 톤 패턴으로 채울 수 있습니다. 픽셀 모드 전용 체크무늬・격자무늬 톤도 준비되어 있어, 도트 그림 질감을 살린 채색이 가능합니다.';

  @override
  String get helpPixelModeTitle => '픽셀 모드';

  @override
  String get helpPixelModeDesc =>
      '브러시・폰트・스탬프 각각에 준비된 설정으로, 켜면 안티에일리어싱을 제거해 또렷한 도트 그림풍 윤곽으로 그려집니다. 일부러 옛날 게임 같은 질감을 내고 싶을 때나 저해상도 느낌을 연출하고 싶을 때 사용합니다. 색상 모드는 「색을 지정하지 않음」「색을 지정함」「색 수를 지정함」「팔레트에서 선택」의 4가지 중에서 고를 수 있으며, 도트 그림 전용 팔레트도 사용할 수 있습니다.';

  @override
  String get helpHomeScreenTitle => '홈 화면';

  @override
  String get helpHomeScreenDesc =>
      '앱을 실행하면 처음 표시되는 화면으로, 프로젝트・공유・작품 목록・휴지통 각 탭을 전환하며 볼 수 있습니다. 오른쪽 위 검색 아이콘으로 프로젝트 이름으로 좁혀 검색할 수도 있습니다. 프로젝트 탭에서는 화면 오른쪽 아래의 ＋ 버튼으로 새 프로젝트 만들기와 새 폴더 만들기를 선택할 수 있습니다.';

  @override
  String get helpNewProjectTitle => '새 프로젝트 만들기';

  @override
  String get helpNewProjectDesc =>
      '캔버스 크기・fps・길이（초 단위. 이후 타임라인에서의 프레임 증감과도 연동）・그리기 영역（내보내기 범위보다 넓게 그려둘 수 있는 설정）・사용할 자동 채색 설정 등을 한꺼번에 지정한 뒤 프로젝트를 만듭니다.';

  @override
  String get helpThemeSettingsTitle => '테마 설정';

  @override
  String get helpThemeSettingsDesc =>
      '앱 전체의 색상 배합을 테마 목록에서 고르거나, 포인트 컬러를 자유롭게 커스터마이즈할 수 있는 화면입니다. 제목・항목명용 폰트와 설명문용 폰트가 나뉘어 있어, 가독성을 유지하면서 꾸미기를 즐길 수 있습니다.';

  @override
  String get helpWorkspaceSettingsTitle => '워크스페이스 설정';

  @override
  String get helpWorkspaceSettingsDesc =>
      '왼손잡이 모드（도킹 패널 좌우 반전）, PC/DeX 모드 수동 전환, 손바닥 도구 표시 조건 등을 한꺼번에 설정할 수 있는 화면입니다. 사용하는 기기와 주로 쓰는 손에 맞춰 작업하기 쉬운 레이아웃으로 조정할 수 있습니다.';

  @override
  String get helpPenSettingsTitle => '펜 설정';

  @override
  String get helpPenSettingsDesc =>
      '타블렛・액정 타블렛의 필압 곡선과 더불어, 펜 옆면 버튼（지원 스타일러스 사용 시）에 지우개 전환이나 스포이트 등의 동작을 할당할 수 있는 설정 화면입니다.';

  @override
  String get helpMaterialListTitle => '소재 목록';

  @override
  String get helpMaterialListDesc =>
      '프로젝트에서 사용 중인 이미지・동영상・오디오 소재를 한꺼번에 확인할 수 있는 화면입니다. 타임라인에 배치한 소재의 원본 파일이 여기에 모입니다.';

  @override
  String get helpFrameOperationsTitle => '프레임 조작';

  @override
  String get helpFrameOperationsDesc =>
      '프레임 목록에서는 새로 추가・복제・삭제할 수 있고, 다중 선택 모드에서는 여러 프레임을 한꺼번에 이동・복제・삭제할 수 있습니다. 보유 셀 수를 늘리면 같은 프레임을 여러 칸에 걸쳐 계속 표시할 수 있어（이른바 「멈춤」）, 움직임이 적은 컷에서 매수를 절약할 수 있습니다.';

  @override
  String get helpSceneOperationsTitle => '장면 조작';

  @override
  String get helpSceneOperationsDesc =>
      '타임라인의 장면 탭에서는 장면 추가・복제・삭제・이름 변경・순서 바꾸기를 할 수 있습니다. 다중 선택 모드로 하면 여러 장면을 한꺼번에 이동・복제・삭제하는 것도 가능합니다.';

  @override
  String get helpQuickToolManagementTitle => '빠른 도구 관리';

  @override
  String get helpQuickToolManagementDesc =>
      '자주 쓰는 도구 조합을 등록해두고 탭 한 번으로 순서대로 전환할 수 있는 기능입니다. 길게 누르거나 위로 스와이프하면 관리 팝업이 열려 등록 내용과 순서를 편집할 수 있습니다.';

  @override
  String get helpTransformSelectionTitle => '선택 범위 변형';

  @override
  String get helpTransformSelectionDesc =>
      '선택 도구로 감싼 범위는 변형 도구로 이동・회전・확대축소할 수 있습니다. 실수로 그린 부분의 위치를 조정하거나, 일부만 확대해 강조하고 싶을 때 사용합니다. 레이어 전체를 변형하고 싶다면 선택 범위가 필요 없는 「자유 변형・메시 변형」（편집 메뉴에서 열기）을 사용하면, 격자점을 개별적으로 드래그해 더 자유로운 변형을 할 수 있습니다.';

  @override
  String get helpGradientAutofillTitle => '그라데이션 채색（자동 채색 설정）';

  @override
  String get helpGradientAutofillDesc =>
      '자동 채색 설정의 각 부위에는 단색뿐 아니라 그라데이션도 설정할 수 있습니다. 드래그로 이동할 수 있는 대칭 핸들로 그라데이션의 범위・각도를 직관적으로 조정할 수 있습니다. 각 부위에는 「지정 색상으로 테두리」도 설정할 수 있습니다. 체크하면 채색 범위의 가장 바깥쪽（선화와 맞닿는 부분）에 지정한 색상・두께의 선이 그려집니다. 테두리 색은 컬러 피커로 자유롭게 선택할 수 있고, 두께는 슬라이더・±버튼・숫자 직접 입력 중 어느 방법으로도 조정할 수 있습니다. 설정 항목 바로 위에 미리보기가 표시되어, 실제로 자동 채색을 실행하기 전에 색상과 두께를 확인할 수 있습니다.';

  @override
  String get helpColorPickerTitle => '컬러 피커';

  @override
  String get helpColorPickerDesc =>
      'HSV와 RGB를 한 화면에서 전환하며 색을 고를 수 있는 컬러 피커입니다. 팔레트 기능으로 사용 중인 색상 세트를 저장하고 불러올 수 있습니다. 팔레트는 파일 내보내기나 QR 코드로 다른 기기와 공유할 수도 있습니다.';

  @override
  String get helpUndoSettingsTitle => '실행 취소 횟수 설정';

  @override
  String get helpUndoSettingsDesc =>
      '성능 설정에서 실행 취소로 되돌릴 수 있는 동작 횟수를 조정할 수 있습니다. 횟수를 늘릴수록 안심하고 시행착오를 할 수 있지만 메모리 사용량도 늘어나므로, 저사양 기기에서는 횟수를 줄이면 동작이 가벼워집니다.';

  @override
  String get helpBrushFavoriteTitle => '브러시 즐겨찾기';

  @override
  String get helpBrushFavoriteDesc =>
      '브러시 목록에서 브러시의 별 아이콘을 탭하면 즐겨찾기 등록・해제를 할 수 있습니다（자동 채색 설정・스탬프・폰트・그리기 필터 등 앱 내 다른 즐겨찾기 기능과 같은 조작 방법입니다）. 목록 위쪽의 별 아이콘으로 즐겨찾기만 표시하도록 필터링할 수도 있습니다. 실수로 삭제되지 않도록 즐겨찾기로 등록된 브러시는 삭제할 수 없습니다.';

  @override
  String get helpCustomBrushTitle => '커스텀 브러시';

  @override
  String get helpCustomBrushDesc =>
      '브러시 목록에서 미리 설치된 브러시를 길게 눌러 「복제」를 선택하면 이를 바탕으로 나만의 커스텀 브러시가 만들어집니다. 복제한 브러시는 굵기・불투명도・경도・회전・밀도・분산・흐림 반경 등의 파라미터를 자유롭게 편집할 수 있으며, 필요 없어지면 삭제할 수도 있습니다（미리 설치된 브러시 자체는 편집・삭제할 수 없습니다）. 폴더로 분류하거나 별 아이콘으로 즐겨찾기 등록도 할 수 있습니다.';

  @override
  String get helpLayerFolderTitle => '레이어 폴더';

  @override
  String get helpLayerFolderDesc =>
      '여러 레이어를 폴더로 정리할 수 있는 기능입니다. 파츠 수가 많은 일러스트에서도 레이어 패널을 보기 쉽게 유지할 수 있습니다. 클리핑은 폴더를 넘어서 적용할 수 없으므로, 클리핑을 사용할 경우 같은 폴더 안에 모아두면 안전합니다.';

  @override
  String get helpLayerMultiSelectTitle => '레이어 다중 선택・일괄 조작';

  @override
  String get helpLayerMultiSelectDesc =>
      '레이어 패널의 선택 모드를 사용하면 여러 레이어를 체크박스로 한꺼번에 선택해 병합하거나 일괄 삭제할 수 있습니다. 병합은 일반・자동 채색용 선화・자동 채색 레이어끼리만 가능합니다（공통 레이어・폴더・타임라인 소재는 병합 대상 아님）.';

  @override
  String get helpDrawingAreaTitle => '작화 영역';

  @override
  String get helpDrawingAreaDesc =>
      '내보내기 범위보다 넓은 범위까지 그려둘 수 있는 설정입니다. 캔버스 위에는 내보내기 범위를 나타내는 빨간 테두리가 표시되며, 테두리 밖으로 삐져나온 부분은 내보내지지 않지만, 팬・줌 같은 카메라 워크로 보여줄 범위를 나중에 조정할 여지를 남길 수 있습니다. 새 프로젝트 만들기 시 배율을 설정합니다.';

  @override
  String get helpCanvasBackgroundTitle => '캔버스 배경색';

  @override
  String get helpCanvasBackgroundDesc =>
      '프로젝트의 캔버스 배경색을 설정할 수 있습니다. 투명 내보내기（투명 WebM）를 사용할 경우 배경색은 내보내기에 영향을 주지 않지만, 작업 중 보기 편하도록 원하는 색으로 바꿀 수 있습니다.';

  @override
  String get helpProjectDetailTitle => '프로젝트 상세 화면';

  @override
  String get helpProjectDetailDesc =>
      '프로젝트 이름・썸네일・즐겨찾기 등록・사용할 자동 채색 설정의 필터링 등 프로젝트별 설정을 한곳에서 확인・편집할 수 있는 화면입니다. 세이브 트리로 가는 입구도 여기에 있습니다.';

  @override
  String get helpWatermarkEditTitle => '워터마크 재편집';

  @override
  String get helpWatermarkEditDesc =>
      '타임라인의 공통 레이어 트랙에 배치한 워터마크를 탭하면 각도・크기・불투명도・표시 범위（루프 표시）를 언제든지 다시 편집할 수 있습니다. 등록할 때뿐 아니라 실제로 프로젝트 안에서 사용할 때 세밀하게 조정할 수 있습니다.';

  @override
  String get helpAudioClipTitle => '오디오 클립 음량・페이드';

  @override
  String get helpAudioClipDesc =>
      '타임라인에 배치한 오디오 클립은 상세 시트에서 음량・페이드인・페이드아웃 시간을 조정할 수 있습니다. 효과음이나 배경음악의 음량 균형을 맞추거나, 곡의 시작・끝을 부드럽게 만들 수 있습니다.';

  @override
  String get helpPenSubToolTitle => '펜 서브 도구';

  @override
  String get helpPenSubToolDesc =>
      '펜 도구를 길게 누르면 일반 그리기 외에 톤 붙이기・스탬프 배치 서브 도구로 전환할 수 있습니다. 도구를 일일이 바꾸지 않고도 같은 펜으로 여러 작업을 오갈 수 있습니다.';

  @override
  String get helpTiltDetectionTitle => '기울기 감지';

  @override
  String get helpTiltDetectionDesc =>
      '지원 스타일러스의 기울기 정보를 사용해, 펜촉을 눕혔을 때 선을 굵게・얇게 하는 등 실제 필기구에 가까운 필기감을 재현하는 설정입니다. 성능 설정에서 켜고 끌 수 있습니다.';

  @override
  String get helpFontImportTitle => '폰트 가져오기';

  @override
  String get helpFontImportDesc =>
      '기기 내의 폰트 파일을 직접 불러와 사용할 수 있게 하는 기능입니다. 설정 화면의 폰트 관리 「가져오기」 탭에서 추가할 수 있습니다. 배포되지 않은 자작 폰트나 구매한 상업용 폰트를 사용하고 싶을 때 이용합니다.';

  @override
  String get helpExportScreenTitle => '내보내기 화면';

  @override
  String get helpExportScreenDesc =>
      '동영상・이미지를 내보내는 동안 진행 상황이 표시되며, 도중에 취소할 수도 있습니다. 내보내기에 걸리는 시간은 기기 성능에 따라 달라집니다.';

  @override
  String get helpDrawingFilterTitle => '그리기 필터';

  @override
  String get helpDrawingFilterDesc =>
      '선택 중인 레이어에 직접 적용하는 필터입니다（연출 필터가 타임라인 전체・장면 단위로 적용되는 것과 달리, 그리기 필터는 레이어 단위입니다）. 흐림・샤프・언샤프 마스크・톤 커브・레벨 보정・비네트・노이즈・레트로 애니메이션・브라운관・애니메이션풍・윤곽선・픽셀화 등이 준비되어 있습니다. 윤곽선은 원본 레이어를 다시 쓰지 않고, 윤곽선을 두른 내용만 새 레이어에 그립니다. 픽셀화는 배색 방식(색을 지정하지 않음・색을 지정함・색 수를 지정함・팔레트에서 선택)도 고를 수 있습니다.';

  @override
  String get helpLayerKeyframeTitle => '레이어 키프레임（파츠 단위 애니메이션）';

  @override
  String get helpLayerKeyframeDesc =>
      '각 레이어의 위치・확대축소・회전을 프레임마다 지정하면 키프레임 사이가 자동으로 보간되는 기능입니다. 카메라 키프레임이 화면 전체를 움직이는 것과 달리, 이것은 개별 레이어만 움직입니다. 자동 채색의 각 파츠는 각각 독립된 레이어로 생성되므로, 파츠 단위 애니메이션（팔만 움직이기, 입만 여닫기 등）에 그대로 사용할 수 있습니다. 각 키프레임에는 「등속」「천천히 시작」「천천히 종료」「천천히 시작하고 종료」「튕김」이라는 이징（다음 키프레임으로의 연결 방식）을 개별적으로 설정할 수 있어, 단조로운 등속 이동뿐 아니라 튕기는 듯한 움직임도 표현할 수 있습니다. 레이어 패널의 점 3개 메뉴 「애니메이션（키프레임）」에서 설정합니다. 레이어의 그림 자체는 바뀌지 않고 표시 위치만 바뀌는 비파괴적인 변형입니다. 이 기능은 타임라인의 표시（미리보기・내보내기）에만 영향을 주며, 캔버스 모드에서의 실제 작화에는 영향을 주지 않습니다.';

  @override
  String get helpLayerGroupTitle => '레이어 그룹（여러 파츠를 한꺼번에 움직이기）';

  @override
  String get helpLayerGroupDesc =>
      '여러 레이어를 하나의 키프레임 흐름으로 한꺼번에 움직이는 기능입니다. 예를 들어 「팔」이 피부・소매 2장의 자동 채색 파츠로 이루어져 있다면, 이 2장을 그룹화해두면 한 번의 키프레임 조작으로 함께 움직일 수 있습니다. 레이어 패널에서 여러 개를 선택（체크박스）한 상태로 하단 바의 「그룹화」 아이콘에서 만듭니다. 그룹의 움직임은 각 레이어 자체의 키프레임（설정되어 있다면）에 겹쳐서 적용되므로, 그룹 전체의 움직임과 개별 레이어의 미세 조정을 함께 사용할 수도 있습니다. 하나의 레이어는 동시에 하나의 그룹에만 속할 수 있습니다.';

  @override
  String get tipsScreenTitle => '활용 팁';

  @override
  String get tipsSearchHint => '팁 검색...';

  @override
  String get tipsCategoryVideo => '영상 제작 팁';

  @override
  String get tipsCategoryEfficiency => '제작을 빠르게 하는 팁';

  @override
  String get tipsCategoryDrawing => '작화를 부드럽게 하는 팁';

  @override
  String get tipsCategoryEffects => '연출·마무리 팁';

  @override
  String get tipsCategoryExport => '내보내기·조작 팁';

  @override
  String get tipsClipDuplicateTitle => '타임라인 소재도 복제·이동·삭제할 수 있어요';

  @override
  String get tipsClipDuplicateDesc =>
      '이미지·동영상·오디오 클립을 탭하면 열리는 상세 시트의 복사 아이콘으로 복제할 수 있습니다. 같은 효과음을 반복해서 쓰거나 같은 이미지를 장면마다 다시 배치하는 작업도 길게 눌러 드래그하고 복제 버튼을 누르는 것만으로 끝납니다.';

  @override
  String get tipsTextCaptionTitle => '텍스트 도구로 자막 넣기';

  @override
  String get tipsTextCaptionDesc =>
      '텍스트 도구를 사용하면 자막이나 코멘트를 프레임마다 배치할 수 있습니다. 폰트를 픽셀 모드로 바꾸면 레트로 게임 같은 질감을 연출할 수도 있습니다.';

  @override
  String get tipsAutofillPresetTitle => '자동 채색 설정은 부위별로 등록해두기';

  @override
  String get tipsAutofillPresetDesc =>
      '피부・머리카락・옷 등 부위별로 음영까지 포함해 자동 채색 설정을 등록해두면, 선화만 그려도 채색 대부분을 자동화할 수 있습니다. 프로젝트마다 사용하는 설정만 필터링할 수도 있습니다.';

  @override
  String get tipsAutofillBaseCoatTitle => '자동 채색은 부위 나누지 않고 밑칠 레이어로만 써도 편리해요';

  @override
  String get tipsAutofillBaseCoatDesc =>
      '자동 채색은 원래 부위별로 색을 나누기 위한 기능이지만, 꼼꼼히 나누지 않아도 선화 전체를 한 가지 색으로 칠하는 밑칠 레이어로만 사용해도 충분히 편리합니다. 선 안쪽을 한 번에 채울 수 있어서, 수동으로 페인트 통을 사용할 때 자주 생기는 칠 빠짐(선 틈으로 아래 색이 비치는 실수)을 막을 수 있습니다. 그 위에 손으로 색을 덧칠하면, 부위를 나누는 수고 없이 이점만 얻을 수 있습니다.';

  @override
  String get tipsBrushFavoriteTitle => '브러시는 즐겨찾기로 등록해두면 헤매지 않고 고를 수 있어요';

  @override
  String get tipsBrushFavoriteDesc =>
      '자주 쓰는 브러시는 목록의 별 아이콘을 탭해 즐겨찾기로 등록해두세요. 목록 상단의 별 아이콘으로 즐겨찾기만 좁혀볼 수 있어 찾는 수고가 줄어듭니다. 실수로 지우지 않도록 즐겨찾기 중인 브러시는 삭제할 수 없게 되어 있습니다.';

  @override
  String get tipsPressureCurveTitle => '필압 곡선을 내 취향에 맞게 조정하기';

  @override
  String get tipsPressureCurveDesc =>
      '설정 화면의 필압 곡선은 최대 10개의 제어점을 자유롭게 찍을 수 있습니다. 강약이 맞지 않는다고 느껴진다면 자신의 필압 습관에 맞춰 조정해 보세요.';

  @override
  String get tipsExportFormatTitle => '용도에 맞춰 내보내기 형식을 고르기';

  @override
  String get tipsExportFormatDesc =>
      'SNS에 가볍게 올리고 싶을 때는 GIF 내보내기, 다른 영상에 겹치거나 배경을 투명하게 하고 싶을 때는 투명 WebM, 일반 동영상으로 쓰고 싶을 때는 MP4 내보내기가 알맞습니다. 용도별로 나눠 쓰면 파일 크기와 화질의 균형을 맞추기 쉬워집니다.';

  @override
  String get tipsGestureShortcutTitle => '제스처로 자주 쓰는 동작을 한 번에';

  @override
  String get tipsGestureShortcutDesc =>
      '설정 화면의 「제스처」에서 두 손가락 탭・세 손가락 탭・길게 누르기 등에 실행 취소/다시 실행이나 스포이트를 할당할 수 있습니다. 도구를 바꾸지 않아도 되므로 작화의 리듬이 끊기지 않습니다.';

  @override
  String get tipsAudioRepeatTitle => '효과음은 클립 복제×페이드로 리듬감 있게';

  @override
  String get tipsAudioRepeatDesc =>
      '같은 효과음을 반복해서 쓰고 싶을 때는 클립을 복제해 타이밍을 조금씩 어긋나게 배치하고, 각각에 페이드인・아웃을 설정하면 리듬감 있는 자연스러운 효과음 연타를 만들 수 있습니다.';

  @override
  String get tipsVerticalRubyTitle => '세로쓰기×루비로 타이틀 로고풍 연출';

  @override
  String get tipsVerticalRubyDesc =>
      '텍스트 도구의 세로쓰기에 루비（후리가나）를 조합하면 일본풍 타이틀 로고나 개성 있는 제목 연출을 만들 수 있습니다. 반각 영숫자는 자동으로 가로 방향으로 회전해 배열되므로 기호나 숫자가 섞여도 읽기 쉽게 완성됩니다.';

  @override
  String get tipsBrushTrySaveTreeTitle => '새 브러시 설정은 세이브 트리에서 시험해보기';

  @override
  String get tipsBrushTrySaveTreeDesc =>
      '브러시의 굵기나 안정화 등을 크게 바꿔 시험해보고 싶을 때는 변경 전에 세이브 트리에 저장해두면 안심입니다. 마음에 들지 않으면 바로 이전 상태로 되돌릴 수 있어 과감한 조정을 시도하기 쉬워집니다.';

  @override
  String get tipsEyedropperGestureTitle => '두 손가락 탭에 스포이트를 할당해 배색을 무너뜨리지 않기';

  @override
  String get tipsEyedropperGestureDesc =>
      '제스처 설정에서 두 손가락 탭에 스포이트를 할당해두면 도구를 바꾸지 않고도 근처 색을 바로 뽑을 수 있습니다. 캐릭터의 배색을 유지한 채 채색을 이어가고 싶을 때 편리합니다.';

  @override
  String get tipsRulerOnionTitle => '투시 자×어니언 스킨으로 배경을 재사용하기';

  @override
  String get tipsRulerOnionDesc =>
      '투시 자로 배경의 깊이를 정해두고, 어니언 스킨으로 앞뒤 프레임을 비쳐 보면서 캐릭터만 움직이면 배경을 매 프레임 다시 그리지 않아도 됩니다.';

  @override
  String get tipsGradientTraceTitle => '그라데이션 자동 채색×색 트레이싱으로 자연스럽게';

  @override
  String get tipsGradientTraceDesc =>
      '자동 채색 설정에서 그라데이션을 사용할 때, 선화 색상 설정을 색 트레이스（선화 어우러짐）로 해두면 그라데이션의 미묘한 색 변화에 맞춰 선화 색도 자연스럽게 어우러져 경계가 도드라지지 않습니다.';

  @override
  String get tipsGradientOutlineHairTitle => '그라데이션×지정 색상 테두리로 앞머리에 투명감 주기';

  @override
  String get tipsGradientOutlineHairDesc =>
      '자동 채색 설정에서 앞머리 부위를 만들고, 채우기 색을 그라데이션으로 설정한 뒤 머리색과 투명색 2가지를 선택합니다. 각도를 90도로 바꾸고 흐림 강도와 색 전환 위치를 취향대로 조정한 다음, 「지정 색상으로 테두리」를 체크하고 테두리 색을 「최근 사용한 색」에서 방금 사용한 앞머리 색과 같은 색으로 선택합니다. 앞머리 밑칠 부위뿐 아니라 그림자색 부위에도 같은 방법을 반복하면, 머리끝이 비쳐 보이는 듯한 투명감 있는 머리카락을 표현할 수 있습니다.';

  @override
  String get tipsRainNoiseTitle => '비×움직이는 노이즈로 촉촉한 공기감';

  @override
  String get tipsRainNoiseDesc =>
      '비 필터에 약한 움직이는 노이즈 필터를 겹치면 빗방울뿐 아니라 공기 중의 입자감도 더해져 촉촉한 비 오는 날다운 질감을 연출할 수 있습니다.';

  @override
  String get tipsPartKeyframeGroupTitle => '파츠 키프레임×그룹화로 캐릭터를 통통 튀게';

  @override
  String get tipsPartKeyframeGroupDesc =>
      '자동 채색의 각 파츠에 레이어 키프레임을 붙여 움직이고, 관련 파츠를 그룹화해 함께 튀어오르게 하면, 다시 그리지 않고도 음악에 맞춰 흔들리는 미니 애니메이션을 만들 수 있습니다.';

  @override
  String get tipsLowSpecSettingsTitle => '저사양 기기는 성능 설정과 실행 취소 횟수를 재점검하기';

  @override
  String get tipsLowSpecSettingsDesc =>
      '동작이 무겁다고 느껴지면 성능 설정을 「저품질」 프리셋으로 바꾸고 실행 취소 횟수도 줄여보세요. 메모리 사용량이 줄어 동작이 가벼워질 수 있습니다.';

  @override
  String get tipsSeriesPresetFolderTitle => '시리즈물은 자동 채색 설정 필터링×폴더 정리로 관리하기';

  @override
  String get tipsSeriesPresetFolderDesc =>
      '같은 작품의 여러 화를 만들 때는 폴더로 화별로 프로젝트를 묶고, 각 프로젝트에서 사용하는 자동 채색 설정을 필터링해두면 캐릭터별 배색을 혼동하지 않고 효율적으로 작업할 수 있습니다.';

  @override
  String get tipsPixelToneRetroTitle => '스탬프 픽셀 모드×톤 채색으로 레트로 통일감';

  @override
  String get tipsPixelToneRetroDesc =>
      '픽셀 모드 스탬프와 픽셀 모드 전용 체크무늬・격자무늬 톤을 조합하면 화면 전체를 도트 그림풍 질감으로 통일할 수 있습니다. 레트로 게임풍 연출에 어울립니다.';

  @override
  String get tipsMagicWandLassoTitle => '매직완드 선택×올가미 채색으로 채색 분리 효율화';

  @override
  String get tipsMagicWandLassoDesc =>
      '선택 도구의 자동 선택（매직완드）으로 대략적인 범위를 한꺼번에 선택하고, 삐져나온 부분만 올가미 선택으로 조정하면 복잡한 색 분리도 빠르게 할 수 있습니다.';

  @override
  String get tipsCommonLayerFolderTitle => '공통 레이어×폴더로 회차를 넘나들며 재사용하기';

  @override
  String get tipsCommonLayerFolderDesc =>
      '시리즈물에서 매회 사용하는 로고나 크레딧 표기는 공통 레이어로 만들어 폴더에 정리해두면, 새 회차 프로젝트로 복사할 때도 헤매지 않고 다룰 수 있습니다.';

  @override
  String get tipsStrokeDecayFadeTitle => '스트로크 감쇠×페이드로 붓 표현';

  @override
  String get tipsStrokeDecayFadeDesc =>
      '브러시 설정의 스트로크 감쇠와 페이드를 함께 걸면 선의 시작・끝이 자연스럽게 가늘어져, 붓이나 잉크 브러시 같은 강약이 있는 선을 그릴 수 있습니다.';

  @override
  String get tipsColorMixingFadeTitle => '혼색×페이드로 물감 같은 섞임';

  @override
  String get tipsColorMixingFadeDesc =>
      '혼색을 켠 브러시에 페이드도 함께 조합하면, 아래 색과 섞이면서 서서히 옅어지는 실제 물감에 가까운 채색감을 얻을 수 있습니다.';

  @override
  String get tipsOutlineAnimeStyleTitle => '윤곽선×애니메이션풍으로 셀 애니메이션풍 마무리';

  @override
  String get tipsOutlineAnimeStyleDesc =>
      '그리기 필터의 윤곽선으로 외곽선을 새 레이어에 그려내고, 애니메이션풍 필터로 색상 수를 줄이면 셀 애니메이션 같은 또렷한 마무리가 됩니다.';

  @override
  String get tipsLevelsToneCurveTitle => '레벨 보정×톤 커브로 그래픽풍으로';

  @override
  String get tipsLevelsToneCurveDesc =>
      '레벨 보정으로 명암 차를 강하게 조정한 뒤 톤 커브로 계조를 다듬으면, 사진적인 계조에서 벗어난 포스터 같은 그래픽풍 연출을 할 수 있습니다.';

  @override
  String get tipsMosaicChromaticTitle => '모자이크×색수차로 브라운관풍의 거친 질감';

  @override
  String get tipsMosaicChromaticDesc =>
      '모자이크로 해상도를 낮춘 뒤 색수차를 겹치면, 오래된 브라운관 TV로 보는 듯한 거친 질감을 연출할 수 있습니다. 브라운관 필터 단독과는 또 다른 질감을 만들 수 있습니다.';

  @override
  String get tipsEndCardWatermarkTitle => '워터마크는 나의 서명, 엔드카드는 별개';

  @override
  String get tipsEndCardWatermarkDesc =>
      '동영상에 자신의 서명이나 마크를 넣고 싶을 때는 워터마크 기능을 사용하세요. 엔드카드는 모든 동영상 끝에 자동으로 표시되는 앱 자체 로고로, 무료 회원은 변경할 수 없습니다. 프리미엄 회원은 숨기거나 자신의 동영상・이미지로 교체할 수 있습니다. 엔드카드를 사용하지 않고 나만의 마무리를 만들고 싶다면, 이미지 레이어 추가와 페이드 인/아웃을 조합해 비슷한 연출을 직접 만들 수 있습니다.';

  @override
  String get tipsVerticalPixelFontTitle => '실사 영상×손그림으로 「실사×애니메이션」 만들기';

  @override
  String get tipsVerticalPixelFontDesc =>
      '일러스트 앱과 영상 편집 앱을 겸하고 있기에 가능한 놀이법입니다. 실사 동영상 클립을 타임라인에 배치하고, 그 위 레이어에 어니언 스킨을 사용하면서 손으로 효과선이나 캐릭터를 그려 넣으면, 실사에 손그림 애니메이션이 겹쳐진 「실사×애니메이션」 믹스 미디어 영상을 만들 수 있습니다.';

  @override
  String get tipsTimelineMarkerTitle => '소리와 입모양 타이밍 맞추기는 타임스탬프로';

  @override
  String get tipsTimelineMarkerDesc =>
      '장면은 「시작~끝 프레임의 범위」를 다루는 기능이지만, 타임스탬프는 「그 한순간」에 코멘트를 붙여 한 번의 탭으로 이동할 수 있는 기능입니다. 「120프레임째에 효과음」「180프레임째는 입모양 『아』」처럼, 같은 장면의 범위 안에 여러 타임스탬프를 찍어두면 소리와 영상의 타이밍 맞추기가 훨씬 쉬워집니다.';

  @override
  String get tipsCommunityYoutubeTitle => '작품 광장 게시는 YouTube를 통해 이루어집니다';

  @override
  String get tipsCommunityYoutubeDesc =>
      '작품 광장에 게시하면 YouTube를 통해 작품이 공개됩니다. NIARIM은 동영상 파일 본체를 개발자의 서버로 전송・수집・저장하는 기능을 가지고 있지 않습니다. YouTube 측 공개 설정을 「일부 공개」로 설정하면, YouTube의 일반 공개 목록에는 표시되지 않고 작품 광장 내에만 게시된 상태로 만들 수 있습니다.';

  @override
  String get tipsToolbarCustomizeTitle => '툴바 재배열・숨기기로 손가락 이동 거리 줄이기';

  @override
  String get tipsToolbarCustomizeDesc =>
      '설정 화면의 툴바 편집에서 사용하지 않는 도구를 숨기고, 자주 쓰는 도구를 손가락이 닿기 쉬운 위치로 재배열할 수 있습니다. 표시 항목을 줄여 깔끔하게 하는 것만으로 도구를 찾는 시간과 손가락 이동 거리가 줄어 작화 리듬이 좋아집니다.';

  @override
  String get tipsAutofillBlendModeTitle => '자동 채색 파츠의 블렌드 모드로 음영 질감 바꾸기';

  @override
  String get tipsAutofillBlendModeDesc =>
      '자동 채색 설정의 각 부위에는 블렌드 모드를 설정할 수 있습니다. 음영 부위를 「곱하기」 대신 「오버레이」나 「소프트 라이트」로 하면 빛이 비치는 듯한 부드러운 음영이 됩니다. 같은 색이라도 질감을 바꿀 수 있는 숨겨진 자유도입니다.';

  @override
  String get tipsStampBlendModeTitle => '스탬프×블렌드 모드로 빛나는 이펙트';

  @override
  String get tipsStampBlendModeDesc =>
      '배치한 스탬프 레이어의 블렌드 모드를 「스크린」이나 「가산」으로 하면, 빛 효과선이나 반짝이는 이펙트가 배경에 자연스럽게 어우러져 돋보입니다.';

  @override
  String get tipsQuickToolPenSubTitle => '빠른 도구×펜 서브 도구로 멈추지 않는 작업 흐름';

  @override
  String get tipsQuickToolPenSubDesc =>
      '자주 쓰는 도구를 빠른 도구에 등록해두고, 펜을 길게 눌러 톤 붙이기・스탬프로 전환할 수 있는 펜 서브 도구도 활용하면, 화면을 오가는 횟수를 줄여 작업 리듬을 유지할 수 있습니다.';

  @override
  String get tipsAutofillToneReuseTitle => '자동 채색의 톤 설정으로 선화만 다시 그려도 채색을 재현';

  @override
  String get tipsAutofillToneReuseDesc =>
      '자동 채색 설정의 각 부위를 「톤 사용」으로 설정해두면, 선화를 다시 그릴 때마다 톤이 포함된 채색을 자동으로 재현할 수 있습니다. 프레임마다 톤을 다시 붙이는 수고를 줄일 수 있습니다.';

  @override
  String get tipsRadialVignetteTitle => '방사형 자×비네트로 집중선 연출';

  @override
  String get tipsRadialVignetteDesc =>
      '방사형 자로 집중선을 한 번에 그리고, 그리기 필터의 비네트를 겹치면 만화의 클라이맥스 같은 박력 있는 연출이 됩니다.';

  @override
  String get tipsClippingGradientTitle => '클리핑×그라데이션으로 음영을 다시 그릴 수 있게';

  @override
  String get tipsClippingGradientDesc =>
      '그라데이션 레이어를 캐릭터 레이어에 클리핑해두면, 브러시로 음영 형태를 그려 넣지 않아도 그라데이션의 범위・각도 변경만으로 음영을 다시 조정할 수 있습니다.';

  @override
  String get tipsToneCurveSepiaTitle => '톤 커브×세피아로 레트로 사진풍';

  @override
  String get tipsToneCurveSepiaDesc =>
      '연출 필터의 톤 커브로 명암 대비를 정돈한 뒤 세피아를 겹치면, 색이 바랜 오래된 사진 같은 질감을 연출할 수 있습니다.';

  @override
  String get tipsCameraLensBlurTitle => '카메라 키프레임×렌즈 블러로 줌 블러 연출';

  @override
  String get tipsCameraLensBlurDesc =>
      '카메라 키프레임이 줌인하는 순간에 맞춰 렌즈 블러 연출 필터를 일시적으로 강하게 설정하면, 실사 줌 블러 같은 박력을 연출할 수 있습니다.';

  @override
  String get tipsBlurVignetteBgTitle => '가우시안 블러×비네트로 부드러운 배경 보케';

  @override
  String get tipsBlurVignetteBgDesc =>
      '배경 레이어에만 가우시안 블러와 비네트 그리기 필터를 겹쳐 걸면, 주인공 캐릭터가 자연스럽게 돋보이는 심도감 있는 카메라풍 마무리가 됩니다.';

  @override
  String get tipsSepiaVignetteTitle => '세피아×비네트로 앤티크 사진풍 영상으로';

  @override
  String get tipsSepiaVignetteDesc =>
      '연출 필터의 세피아와 그리기 필터의 비네트를 조합하면, 네 귀퉁이가 어둡고 색이 바랜 앤티크 사진 같은 분위기의 영상으로 완성할 수 있습니다.';

  @override
  String get tipsVideoTrimReuseTitle => '동영상 클립의 사용 범위를 바꿔 같은 소재를 재사용하기';

  @override
  String get tipsVideoTrimReuseDesc =>
      '같은 동영상 소재라도 클립마다 사용 시작・종료 프레임을 바꿔 배치하면 다른 컷으로 재사용할 수 있습니다. 소재를 늘리지 않고도 변화를 줄 수 있습니다.';

  @override
  String get tipsSaveSlotAutoSaveTitle => '세이브 슬롯×자동 저장을 나눠서 쓰기';

  @override
  String get tipsSaveSlotAutoSaveDesc =>
      '자동 저장은 항상 최신 상태를 덮어쓰지만, 세이브 슬롯은 여러 상태를 남겨둘 수 있습니다. 중요한 시점에는 세이브 슬롯에 저장하고, 그 외 자잘한 변경은 자동 저장에 맡기면 필요한 시점으로 확실하게 되돌아갈 수 있습니다.';

  @override
  String get tipsQuickToolSwipeTitle => '빠른 도구는 위로 스와이프해서 재배열할 수 있어요';

  @override
  String get tipsQuickToolSwipeDesc =>
      '빠른 도구의 등록 내용을 바꾸고 싶을 때는 길게 누르기뿐 아니라 위로 스와이프해도 관리 팝업을 열 수 있습니다. 한 손으로 조작할 때 빠르게 재배열하고 싶을 때 편리합니다.';

  @override
  String get tipsDrawingAreaCameraTitle => '작화 영역을 넓게×카메라 키프레임으로 안전하게 팬・줌';

  @override
  String get tipsDrawingAreaCameraDesc =>
      '작화 영역을 내보내기 범위보다 넓게 설정해두면, 카메라 키프레임으로 팬・줌을 해도 화면 끝이 잘릴 걱정이 없습니다. 움직임이 큰 연출을 넣기 전에 확인해두면 안심입니다.';

  @override
  String get tipsWebmCommonLayerTitle => '투명 WebM×배경을 공통 레이어로 분리 관리';

  @override
  String get tipsWebmCommonLayerDesc =>
      '투명 WebM으로 내보낸 캐릭터를 다른 영상 편집 소프트웨어에서 배경과 합성할 경우, 배경을 공통 레이어로 따로 관리해두면 투명 부분에 불필요한 색이 섞이지 않고 깔끔하게 빠집니다.';

  @override
  String get tipsLeftHandedWorkspaceTitle => '왼손잡이 모드×워크스페이스 설정으로 작업하기 편하게';

  @override
  String get tipsLeftHandedWorkspaceDesc =>
      '왼손잡이라면 워크스페이스 설정의 왼손잡이 모드를 켜면 도킹 패널이 좌우 반전되어, 주로 쓰는 손 쪽 화면이 패널에 가려지기 어려워집니다.';

  @override
  String get tipsTransferDeviceTitle => '인계 파일로 다른 기기로 작업을 옮기기';

  @override
  String get tipsTransferDeviceDesc =>
      '기기를 바꿔도 같은 환경에서 계속 그리고 싶을 때는 인계（.niatra）기능을 사용하면 설정・브러시・톤・스탬프・팔레트 등의 환경을 한꺼번에 옮길 수 있습니다. 작업 중인 프로젝트 자체를 전달하고 싶을 때는 「공유（.niashare）」를 사용하세요.';

  @override
  String get fontSettingsTabDownloaded => '다운로드됨';

  @override
  String get fontSettingsTabSearch => '찾아서 다운로드';

  @override
  String get fontSettingsTabImport => '불러오기';

  @override
  String get fontDownloadedSearchHint => '폰트 이름으로 검색...';

  @override
  String get fontPixelModeTooltip => '픽셀 모드(도트 폰트용. 안티에일리어싱 없이 선명하게 표시)';

  @override
  String get fontEmptyTitle => '폰트가 없습니다';

  @override
  String get fontEmptyHint => '「찾아서 다운로드」또는「불러오기」탭에서 추가할 수 있습니다';

  @override
  String get fontRenameDialogTitle => '폰트 이름 변경';

  @override
  String get fontImportTitle => '기기에 저장된 폰트 불러오기';

  @override
  String get fontImportFormats => '지원 형식: TTF / OTF';

  @override
  String get fontSelectFileButton => '파일 선택';

  @override
  String get fontUnsupportedSnackbar => '이 폰트는 불러올 수 없습니다.';

  @override
  String fontAddedSnackbar(String name) {
    return '「$name」을(를) 추가했습니다（다운로드됨 탭에 표시됩니다）';
  }

  @override
  String get fontCorruptedSnackbar => '폰트가 손상되었습니다.';

  @override
  String get licenseScreenTitle => '이용약관・라이선스';

  @override
  String get licenseSectionTerms => '이용약관';

  @override
  String get licenseSectionFonts => '사용 폰트에 대하여';

  @override
  String get licenseSectionOss => '오픈소스 소프트웨어 라이선스';

  @override
  String get licenseOssListTitle => '사용 라이브러리 라이선스 목록';

  @override
  String get licenseOssListSubtitle => '본 앱이 사용하는 OSS 패키지의 라이선스를 표시합니다';

  @override
  String get licenseFfmpegNote =>
      'WebM・AVI 내보내기에는 FFmpeg（LGPL 3.0, ffmpeg_kit_flutter_new_video 경유）를 사용하고 있습니다. 수정판 소스 코드 입수처: https://github.com/sk3llo/ffmpeg_kit_flutter\nMP4 내보내기는 기기 내장 하드웨어 인코더를 직접 사용하며, FFmpeg는 사용하지 않습니다.';

  @override
  String licenseFontCreditMeta(String author, String license) {
    return '작성자: $author   라이선스: $license';
  }

  @override
  String get toolbarPenTooltip => '펜（길게 눌러 서브 도구）';

  @override
  String get toolbarPenFirstUseTip =>
      '펜을 길게 누르면 브러시・톤・스탬프・올가미 채우기를 전환할 수 있습니다.';

  @override
  String get toolbarBucketTooltip => '페인트통（길게 눌러 단색/톤 전환）';

  @override
  String get toolbarBucketFirstUseTip =>
      '페인트통을 길게 누르면 단색 채우기와 톤 채우기를 전환할 수 있습니다.';

  @override
  String get toolbarSelectTooltip => '선택（길게 눌러 종류 변경）';

  @override
  String get toolbarShapeTooltip => '도형（탭하여 종류 선택）';

  @override
  String get toolbarTextFirstUseTip =>
      '문자를 자유롭게 배치할 수 있습니다. 글꼴・색・테두리도 변경할 수 있습니다.';

  @override
  String get toolbarQuickToolFirstUseTip =>
      '탭하면 등록한 도구를 순서대로 전환할 수 있습니다. 길게 누르거나 위로 스와이프하면 등록 내용을 편집할 수 있습니다.';

  @override
  String get toolbarStampColorLockedSnackbar =>
      '스탬프는 색상 정보를 유지하고 있어 색을 변경할 수 없습니다';

  @override
  String get toolbarBrushSettingsTooltip => '브러시 설정';

  @override
  String get toolbarLayerTooltip => '레이어';

  @override
  String get toolbarQuickToolTooltip => '빠른 도구（길게 누르기/위로 스와이프로 편집）';

  @override
  String get toolbarSaveTooltip => '저장（세이브 트리）';

  @override
  String get toolbarBucketFlatFill => '단색 채우기';

  @override
  String get toolbarBucketToneListLabel => '톤 목록';

  @override
  String get toolbarSelectRect => '사각형 선택';

  @override
  String get toolbarSelectLasso => '올가미 선택';

  @override
  String get toolbarSelectMagicWand => '자동 선택（매직 완드）';

  @override
  String get creativePanelFavoritesOnlyTooltip => '즐겨찾기만 표시';

  @override
  String get creativePanelSearchTooltip => '이름으로 검색';

  @override
  String get creativePanelFolderButton => '폴더';

  @override
  String get creativePanelCreateButton => '직접 제작';

  @override
  String get creativePanelImportButton => '불러오기';

  @override
  String get creativePanelFolderAllChip => '전체';

  @override
  String get creativePanelEditAction => '편집';

  @override
  String get toneTitle => '톤';

  @override
  String get toneEmpty => '톤이 없습니다';

  @override
  String get toneSearchHint => '톤 이름으로 검색';

  @override
  String get toneEditTitle => '톤 편집';

  @override
  String get toneChangeTextureButton => '텍스처 이미지 변경';

  @override
  String get toneCreateDialogTitle => '직접 제작한 톤';

  @override
  String toneImportFailedSnackbar(String error) {
    return '톤을 불러오지 못했습니다: $error';
  }

  @override
  String toneExportFailedSnackbar(String error) {
    return '톤 내보내기에 실패했습니다: $error';
  }

  @override
  String get privacyPolicyScreenTitle => '개인정보처리방침';

  @override
  String get stampTitle => '스탬프';

  @override
  String get stampSearchHint => '스탬프 이름으로 검색';

  @override
  String get stampEmpty => '스탬프가 없습니다';

  @override
  String get stampCreateDialogTitle => '직접 제작한 스탬프';

  @override
  String stampImportFailedSnackbar(String error) {
    return '스탬프를 불러오지 못했습니다: $error';
  }

  @override
  String stampExportFailedSnackbar(String error) {
    return '스탬프 내보내기에 실패했습니다: $error';
  }

  @override
  String get stampEditTitle => '스탬프 편집';

  @override
  String get stampRotationLabel => '회전';

  @override
  String get stampPixelModeLabel => '픽셀 모드';

  @override
  String get stampPixelModeHint => '픽셀 아트 스타일(모자이크+색상 수 감소)로 렌더링합니다';

  @override
  String get stampDensityLabel => '밀도';

  @override
  String get stampScatterLabel => '분산';

  @override
  String get stampChangeImageButton => '스탬프 이미지 변경';

  @override
  String get themeSettingsTitle => '테마・외관';

  @override
  String get themeColorCustomizeSection => '색상 커스터마이즈';

  @override
  String get themeColorAccent => '강조 색상';

  @override
  String get themeColorText => '글자 색';

  @override
  String get themeColorPanelBg => '패널 배경색';

  @override
  String get themeColorMenuBg => '메뉴 배경색';

  @override
  String get themeColorSelection => '선택 색상';

  @override
  String get themeColorUpdateMark => '업데이트 표시 색상';

  @override
  String get themePresetSection => '테마 목록';

  @override
  String themePresetDuplicateName(String name) {
    return '$name（사본）';
  }

  @override
  String get themeDuplicateAction => '복제';

  @override
  String get themeExportMenuItem => '내보내기 (.niatheme)';

  @override
  String themeExportFailedSnackbar(String error) {
    return '내보내기에 실패했습니다: $error';
  }

  @override
  String get themeImportSuccessSnackbar => '.niatheme 파일을 불러왔습니다';

  @override
  String themeImportFailedSnackbar(String error) {
    return '불러오기에 실패했습니다: $error';
  }

  @override
  String get themeSaveAsNewButton => '현재 설정을 새 테마로 저장';

  @override
  String get themeImportButton => '.niatheme 불러오기';

  @override
  String get themePresetNameDialogTitle => '테마 이름';

  @override
  String get themeDefaultPresetName => '내 테마';

  @override
  String get onionSkinTitle => '어니언 스킨';

  @override
  String get onionSkinPrevFrame => '이전 프레임';

  @override
  String get onionSkinNextFrame => '다음 프레임';

  @override
  String get onionSkinFrameInterval => '프레임 간격';

  @override
  String get onionSkinFadeByDistance => '가까울수록 진하게 표시';

  @override
  String get onionSkinColorPickerTitle => '색상 선택';

  @override
  String get onionSkinOnFixed => 'ON（고정）';

  @override
  String get onionSkinFrameCount => '표시 매수';

  @override
  String onionSkinFrameCountFixed(int count) {
    return '$count장（고정）';
  }

  @override
  String get onionSkinColorLabel => '색상';

  @override
  String get onionSkinOpacityLabel => '불투명도';

  @override
  String get exportScreenTitle => '내보내기';

  @override
  String get exportPresetSection => '프리셋';

  @override
  String get exportPresetStandard => '표준';

  @override
  String get exportPresetHighQuality => '고화질';

  @override
  String get exportPresetCustom => '커스텀';

  @override
  String get exportAdvancedSettings => '상세 설정';

  @override
  String get exportFpsLabel => 'FPS';

  @override
  String get exportFormatSection => '형식';

  @override
  String get exportFormatMp4 => 'MP4';

  @override
  String get exportFormatMp4Subtitle => '범용 동영상 형식';

  @override
  String get exportFormatGif => 'GIF';

  @override
  String get exportFormatGifSubtitle => '애니메이션 GIF';

  @override
  String get exportFormatWebmSubtitle => '투명 배경 동영상';

  @override
  String get exportFormatAvi => 'AVI';

  @override
  String get exportFormatAviSubtitle => '호환성 중심의 동영상 형식(투명도 미지원)';

  @override
  String get exportStartButton => '내보내기 시작';

  @override
  String get exportProjectNotFoundError => '프로젝트를 찾을 수 없습니다';

  @override
  String exportFailedError(String error) {
    return '내보내기 실패: $error';
  }

  @override
  String get exportInProgressTitle => '내보내는 중';

  @override
  String get exportCancelledSnackbar => '내보내기를 취소했습니다';

  @override
  String get exportCancelHint => '최종 처리 중이므로 완료 후 취소가 반영됩니다';

  @override
  String get exportOutdatedAutofillTitle => '자동 채색이 최신 상태가 아닙니다';

  @override
  String get exportOutdatedAutofillBody =>
      '업데이트되지 않은 자동 채색 레이어가 있습니다. 이대로 내보내시겠습니까?';

  @override
  String get exportContinueButton => '계속';

  @override
  String get exportDurationExceededTitle => '동영상 길이 상한을 초과했습니다';

  @override
  String exportDurationExceededBody(int max, int current) {
    return '무료판의 최대 동영상 길이는 $max초입니다.\n현재 프로젝트는 약 $current초입니다.\nPremium으로 업그레이드하면 길이 제한이 최대 2시간까지 늘어납니다.';
  }

  @override
  String get exportViewPremiumButton => 'Premium 보기';

  @override
  String get exportContinueAnywayButton => '그대로 계속';

  @override
  String get exportCompleteTitle => '내보내기 완료';

  @override
  String exportCompleteFramesBody(int count) {
    return '$count개 프레임의 내보내기가 완료되었습니다.';
  }

  @override
  String exportSaveLocationLabel(String fileName) {
    return '저장 위치: 앱 내부（$fileName）';
  }

  @override
  String get exportSaveLocationHint =>
      '기기의 「사진」 앱이나 파일 앱에서 열려면 아래의 「공유」에서 저장할 앱을 선택하세요.';

  @override
  String get exportBackToProjectsButton => '프로젝트 목록으로 돌아가기';

  @override
  String get exportBackToCanvasButton => '캔버스로 돌아가기';

  @override
  String get newProjectScreenTitle => '새 프로젝트';

  @override
  String get newProjectDefaultName => '새 프로젝트';

  @override
  String get newProjectNameLabel => '프로젝트 이름';

  @override
  String get newProjectSizeLabel => '크기';

  @override
  String get newProjectPresetFullHd => 'Full HD (16:9・유튜브 등 가로 영상용)';

  @override
  String get newProjectPresetHd => 'HD (16:9・경량판)';

  @override
  String get newProjectPresetSquare => '1:1 정사각형 (트위터/인스타그램 게시물용)';

  @override
  String get newProjectPresetVertical => '9:16 세로형 (유튜브 쇼츠/릴스・스토리용)';

  @override
  String get newProjectPresetPortrait => '4:5 세로형 (인스타그램 피드 게시물용)';

  @override
  String get newProjectPresetAnalog => '4:3 (아날로그 방송 비율)';

  @override
  String get newProjectCustomSize => '사용자 지정';

  @override
  String get newProjectMaxEdgeHint => '긴 변은 최대 1920px까지 설정할 수 있습니다';

  @override
  String get newProjectWidthLabel => '너비(px)';

  @override
  String get newProjectHeightLabel => '높이(px)';

  @override
  String get newProjectWidthShort => '너비';

  @override
  String get newProjectHeightShort => '높이';

  @override
  String get newProjectSizePresetManageButton => '크기 설정';

  @override
  String get newProjectSaveCustomSizeButton => '이 크기 저장하기';

  @override
  String get newProjectSaveCustomSizeDialogTitle => '크기 이름을 입력하세요';

  @override
  String get newProjectSaveCustomSizeNameLabel => '크기 이름';

  @override
  String get newProjectSaveCustomSizeSavedSnackbar => '크기를 저장했습니다';

  @override
  String get canvasSizePresetManageScreenTitle => '크기 설정';

  @override
  String get canvasSizePresetEmpty => '저장된 크기가 없습니다';

  @override
  String get canvasSizePresetEmptyHint =>
      '새 프로젝트 화면에서 사용자 지정 크기를 지정하고 「이 크기 저장하기」로 추가할 수 있습니다';

  @override
  String get canvasSizePresetEditDialogTitle => '크기 편집';

  @override
  String canvasSizePresetDeleteConfirmTitle(String name) {
    return '「$name」을(를) 삭제할까요?';
  }

  @override
  String get canvasSizePresetDuplicateSuffix => '사본';

  @override
  String newProjectDurationLabel(String max) {
    return '길이(최대 $max)';
  }

  @override
  String newProjectDurationLabelWithPremiumHint(String max) {
    return '길이(최대 $max, Premium 이용 시 최대 2시간)';
  }

  @override
  String newProjectDurationSeconds(int n) {
    return '$n초';
  }

  @override
  String newProjectDurationHms(int h, int m, int s) {
    return '$h시간 $m분 $s초';
  }

  @override
  String newProjectDurationHm(int h, int m) {
    return '$h시간 $m분';
  }

  @override
  String newProjectDurationH(int h) {
    return '$h시간';
  }

  @override
  String newProjectDurationMs(int m, int s) {
    return '$m분 $s초';
  }

  @override
  String newProjectDurationM(int m) {
    return '$m분';
  }

  @override
  String get newProjectBackgroundColorLabel => '배경색';

  @override
  String get newProjectDrawingAreaTitle => '그리기 영역 넓히기';

  @override
  String get newProjectDrawingAreaSubtitle => '내보내기 범위 밖에도 그릴 수 있는 영역을 추가합니다';

  @override
  String get newProjectScaleLabel => '배율';

  @override
  String newProjectScaleValue(String value) {
    return '$value배';
  }

  @override
  String newProjectDrawableAreaInfo(String width, String scale, String result) {
    return '그릴 수 있는 범위: $width×$scale = $result';
  }

  @override
  String newProjectTotalFrames(int count) {
    return '총 프레임 수: $count';
  }

  @override
  String newProjectExportSizeInfo(String size) {
    return '내보내기 크기: $size';
  }

  @override
  String newProjectDrawingAreaInfo(String size) {
    return '그리기 영역: $size';
  }

  @override
  String get colorPickerTitle => '색상 선택';

  @override
  String get colorPickerOpacityLabel => '불투명도';

  @override
  String get colorPickerHexCopiedSnackbar => 'HEX 값을 복사했습니다';

  @override
  String get colorPickerRecentColorsLabel => '최근 사용한 색상';

  @override
  String get colorPickerRecentColorsEmpty => '아직 없습니다';

  @override
  String get colorPickerPaletteLabel => '팔레트';

  @override
  String get colorPickerNewPaletteTooltip => '새 팔레트';

  @override
  String get colorPickerManagePaletteTooltip => '팔레트 관리';

  @override
  String get colorPickerPaletteEmptyHint =>
      '아직 색상이 없습니다. 「＋」를 눌러 현재 색상을 추가할 수 있습니다.';

  @override
  String get colorPickerPaletteLongPressHint => '길게 눌러 삭제할 수 있습니다';

  @override
  String get colorPickerAddCurrentColorButton => '현재 색상을 팔레트에 추가';

  @override
  String get colorPickerPaletteNameLabel => '팔레트 이름';

  @override
  String get colorPickerFavoriteAdd => '즐겨찾기 등록';

  @override
  String get colorPickerFavoriteRemove => '즐겨찾기 해제';

  @override
  String get penSubToolTabBrush => '브러시';

  @override
  String get penSubToolTabTone => '톤';

  @override
  String get penSubToolTabStamp => '스탬프';

  @override
  String get penSubToolTabLassoFill => '올가미 채우기';

  @override
  String get penSubToolToneTooltipMessage =>
      '톤을 선택하면 페인트통이나 펜으로 스크린톤 무늬를 칠할 수 있습니다.';

  @override
  String get penSubToolStampTooltipMessage =>
      '정해진 모양의 스탬프를 배치할 수 있습니다. 길게 누르면 회전・밀도 등을 설정할 수 있습니다.';

  @override
  String get penSubToolLassoTooltipMessage => '올가미로 둘러싼 범위를 한 번에 채울 수 있습니다.';

  @override
  String get penSubToolManageTooltip => '관리';

  @override
  String penSubToolBrushSizeOpacity(int size, int opacity) {
    return '${size}px · $opacity%';
  }

  @override
  String get penSubToolStampRotationSubtitle => '획 방향에 맞춰 무작위로 회전';

  @override
  String get brushSearchHint => '브러시 이름으로 검색';

  @override
  String get brushEmpty => '브러시가 없습니다';

  @override
  String get brushCreateDialogTitle => '커스텀 브러시';

  @override
  String brushImportFailedSnackbar(String error) {
    return '브러시 불러오기에 실패했습니다: $error';
  }

  @override
  String brushExportFailedSnackbar(String error) {
    return '브러시 내보내기에 실패했습니다: $error';
  }

  @override
  String get brushSettingsSizeLabel => '크기';

  @override
  String get brushSettingsOpacityLabel => '불투명도';

  @override
  String get brushSettingsSpacingLabel => '간격';

  @override
  String get brushSettingsBlurRadiusLabel => '흐림 반경';

  @override
  String get brushSettingsStabilizationTitle => '손떨림 보정';

  @override
  String get brushSettingsStabilizationStrengthLabel => '보정 강도';

  @override
  String get brushSettingsPixelModeTitle => '픽셀 모드';

  @override
  String get brushSettingsPressureModeTitle => '필압 설정';

  @override
  String get brushSettingsPressureOff => '사용 안 함';

  @override
  String get brushSettingsPressureSize => '크기에 반영';

  @override
  String get brushSettingsPressureOpacity => '불투명도에 반영';

  @override
  String get brushSettingsPressureSizeAndOpacity => '크기＋불투명도에 반영';

  @override
  String get brushSettingsFadeModeTitle => '페이드';

  @override
  String get brushSettingsFadeOff => 'OFF';

  @override
  String get brushSettingsFadeWeak => '약';

  @override
  String get brushSettingsFadeMedium => '중';

  @override
  String get brushSettingsFadeStrong => '강';

  @override
  String get brushSettingsFadeCustom => '사용자 지정';

  @override
  String get brushSettingsFadeStartValueLabel => '시작값(%)';

  @override
  String get brushSettingsFadeEndValueLabel => '종료값(%)';

  @override
  String get brushSettingsFadeDistanceLabel => '거리(px)';

  @override
  String get brushSettingsStrokeDecayTitle => '스트로크 감쇠';

  @override
  String get brushSettingsStrokeDecaySubtitle => '계속 그릴수록 불투명도가 낮아집니다';

  @override
  String get brushSettingsMixingTitle => '혼색';

  @override
  String get brushSettingsMixingOff => 'OFF';

  @override
  String get brushSettingsMixingSimple => '간이 혼색';

  @override
  String get brushSettingsMixingBleed => '번짐';

  @override
  String get brushSettingsMixingRateLabel => '혼색 비율';

  @override
  String get projectDetailNotFoundTitle => '프로젝트';

  @override
  String get projectDetailNotFoundBody => '프로젝트를 찾을 수 없습니다';

  @override
  String get projectDetailFirstFrameTooltip => '첫 프레임';

  @override
  String get projectDetailPrevFrameTooltip => '1프레임 뒤로';

  @override
  String get projectDetailPauseTooltip => '일시정지';

  @override
  String get projectDetailPlayTooltip => '재생';

  @override
  String get projectDetailNextFrameTooltip => '1프레임 앞으로';

  @override
  String get projectDetailLastFrameTooltip => '마지막 프레임';

  @override
  String get projectDetailFullscreenTooltip => '미리보기 전체 화면으로 표시';

  @override
  String get projectDetailFullscreenCloseTooltip => '전체 화면 미리보기 닫기';

  @override
  String get projectDetailCollapsePreviewTooltip => '미리보기 축소';

  @override
  String get projectDetailExpandPreviewTooltip => '미리보기 원래 크기로';

  @override
  String get projectDetailStartEditButton => '편집 시작';

  @override
  String get projectDetailTagsQuickAction => '태그';

  @override
  String get projectDetailShareQuickAction => '공유';

  @override
  String get projectDetailInfoSectionTitle => '프로젝트 정보';

  @override
  String get projectDetailInfoExportSize => '내보내기 크기';

  @override
  String get projectDetailInfoDrawingArea => '그리기 영역';

  @override
  String projectDetailInfoDrawingAreaValue(String size, String scale) {
    return '$size  ($scale)';
  }

  @override
  String get projectDetailInfoTotalFrames => '총 프레임 수';

  @override
  String get projectDetailInfoWorkTime => '제작 시간';

  @override
  String get projectDetailInfoLastSaved => '마지막 저장';

  @override
  String get projectDetailInfoSize => '용량';

  @override
  String get projectDetailSaveTreeButton => '세이브 트리';

  @override
  String get projectDetailAddTagHint => '태그 추가';

  @override
  String projectDetailNiashareFailedSnackbar(String error) {
    return '.niashare 생성에 실패했습니다: $error';
  }

  @override
  String get projectDetailTrashMenuItem => '휴지통으로 이동';

  @override
  String get commonOff => 'OFF';

  @override
  String get perfSettingsScreenTitle => '성능 설정';

  @override
  String get perfSettingsQualitySection => '화질 설정';

  @override
  String get perfSettingsQualityLow => '낮음';

  @override
  String get perfSettingsQualityMedium => '중간';

  @override
  String get perfSettingsQualityHigh => '높음';

  @override
  String get perfSettingsQualityCustom => '사용자 지정';

  @override
  String get perfSettingsQualityDescLow =>
      '동작을 가볍게 하고 싶은 기기용(어니언 스킨 앞뒤 각 1장・슬롯 5개)';

  @override
  String get perfSettingsQualityDescMedium => '일반적인 기기용(어니언 스킨 앞뒤 각 3장・슬롯 10개)';

  @override
  String get perfSettingsQualityDescHigh =>
      '성능에 여유가 있는 기기용(어니언 스킨 앞뒤 각 5장・트리 방식)';

  @override
  String get perfSettingsQualityDescCustom => '항목별로 개별 설정';

  @override
  String get perfSettingsCapacitySection => '용량・동작 관련 설정';

  @override
  String get perfSettingsUndoLimitTitle => '실행 취소 횟수';

  @override
  String get perfSettingsUndoLimitSubtitle => '많을수록 메모리를 더 사용합니다';

  @override
  String perfSettingsUndoLimitValue(int n) {
    return '$n회';
  }

  @override
  String get perfSettingsTrashAutoDeleteTitle => '휴지통 자동 삭제';

  @override
  String get perfSettingsTrashAutoDeleteSubtitle => '삭제된 프로젝트의 보관 기간';

  @override
  String perfSettingsTrashAutoDeleteValue(int n) {
    return '$n일';
  }

  @override
  String get perfSettingsCurrentSettingsSection => '현재 설정';

  @override
  String get perfSettingsTiltLabel => '기울기 감지';

  @override
  String get perfSettingsOnionPrevLabel => '어니언 스킨(앞)';

  @override
  String get perfSettingsOnionNextLabel => '어니언 스킨(뒤)';

  @override
  String perfSettingsOnionFrameCountValue(int n) {
    return '$n장';
  }

  @override
  String get perfSettingsSaveModeLabel => '저장 방식';

  @override
  String get perfSettingsSlotCountLabel => '슬롯 수';

  @override
  String perfSettingsSlotCountValue(int n) {
    return '$n개';
  }

  @override
  String get perfSettingsResetButton => '기본값으로 되돌리기';

  @override
  String get perfSettingsCopyPresetButton => '현재 프리셋 복사';

  @override
  String get perfSettingsTiltSwitchTitle => '펜 기울기를 브러시에 반영';

  @override
  String get perfSettingsShowPrevOnionTitle => '이전 프레임 표시';

  @override
  String get perfSettingsOnionCountPrevLabel => '어니언 스킨 매수(앞)';

  @override
  String get perfSettingsShowNextOnionTitle => '다음 프레임 표시';

  @override
  String get perfSettingsOnionCountNextLabel => '어니언 스킨 매수(뒤)';

  @override
  String get perfSettingsSaveModeSlot => '슬롯 방식';

  @override
  String get perfSettingsSaveModeTree => '트리 방식';

  @override
  String get perfSettingsResetDialogTitle => '사용자 지정 화질 설정을 기본값으로 되돌리시겠습니까?';

  @override
  String perfSettingsResetDialogBody(String preset) {
    return '기본값은 처음 실행 시 기기 성능에 따라 자동으로 판정된 「$preset」 설정입니다.';
  }

  @override
  String get perfSettingsResetConfirmButton => '되돌리기';

  @override
  String get perfSettingsCopyPresetDialogTitle => '복사할 프리셋 선택';

  @override
  String get perfSettingsCopyPresetDialogBody => '사용자 지정 설정으로 복사할 프리셋을 선택하세요.';

  @override
  String get perfSettingsCopyDescLow => '앞뒤 1장 표시・경량 동작';

  @override
  String get perfSettingsCopyDescMedium => '앞뒤 3장 표시・표준';

  @override
  String get perfSettingsCopyDescHigh => '앞뒤 5장 표시・고화질';

  @override
  String get filterPanelTitle => '필터';

  @override
  String filterPanelTitleBulk(int count) {
    return '필터($count프레임에 일괄 적용)';
  }

  @override
  String get filterSearchHint => '필터 검색';

  @override
  String get filterNameGaussianBlur => '가우시안 흐림';

  @override
  String get filterNameLensBlur => '렌즈 흐림';

  @override
  String get filterNameAnimeStyle => '애니메 스타일';

  @override
  String get filterNameOutline => '테두리';

  @override
  String get filterNameToneCurve => '톤 커브';

  @override
  String get filterNameLevels => '레벨 보정';

  @override
  String get filterNameSharpen => '선명하게';

  @override
  String get filterNameUnsharpMask => '언샤프 마스크';

  @override
  String get filterSharpenStrength => '선명도 강도';

  @override
  String get filterUnsharpAmount => '적용 강도';

  @override
  String get filterNameVignette => '비네트';

  @override
  String get filterVignetteStrength => '비네트 강도';

  @override
  String get filterVignetteColor => '비네트 색상';

  @override
  String get filterNameNoise => '필름 그레인';

  @override
  String get filterNoiseStrength => '입자 강도';

  @override
  String get filterNameRetroAnime => '레트로 애니메';

  @override
  String get filterNameCrt => '브라운관';

  @override
  String get filterRetroStrength => '강도';

  @override
  String filterOutlineLayerNameSuffix(String name) {
    return '$name(테두리)';
  }

  @override
  String get filterStrengthBlurRadius => '강도(흐림 반경)';

  @override
  String get filterColorLevels => '색상 수';

  @override
  String get filterEdgeStrength => '엣지 강조';

  @override
  String get filterOutlineColor => '테두리 색상';

  @override
  String get filterOutlineWidth => '테두리 두께';

  @override
  String get filterToneCurveLinear => '표준';

  @override
  String get filterToneCurveBrighten => '밝게';

  @override
  String get filterToneCurveDarken => '어둡게';

  @override
  String get filterToneCurveHighContrast => '고대비';

  @override
  String get filterToneCurveLowContrast => '저대비';

  @override
  String get filterToneCurveInvert => '반전';

  @override
  String get filterLevelsInputBlack => '입력: 검정';

  @override
  String get filterLevelsInputWhite => '입력: 흰색';

  @override
  String get filterLevelsOutputBlack => '출력: 검정';

  @override
  String get filterLevelsOutputWhite => '출력: 흰색';

  @override
  String get filterApplyButton => '적용';

  @override
  String filterApplyBulkButton(int count) {
    return '$count프레임에 적용';
  }

  @override
  String get filterEmpty => '필터가 없습니다';

  @override
  String get filterApplyingTitle => '필터 적용 중';

  @override
  String filterApplyingSubtitle(String name, int count) {
    return '$name　$count프레임';
  }

  @override
  String get projectListNewFolderTitle => '새 폴더';

  @override
  String get projectListFolderHint => '같은 작품의 여러 화나 시리즈를 정리하는 용도로도 사용할 수 있습니다';

  @override
  String get projectListEmptyTitle => '프로젝트가 없습니다';

  @override
  String get projectListEmptyHint => '＋ 버튼으로 새로 만들기';

  @override
  String get projectListOpenAction => '열기';

  @override
  String get projectListCreateShareAction => '.niashare 만들기';

  @override
  String get projectListEditFolderAction => '이름・색상 편집';

  @override
  String get projectListDeleteFolderConfirmTitle => '이 폴더를 삭제하시겠습니까?';

  @override
  String projectListDeleteFolderConfirmBody(String name) {
    return '「$name」을(를) 삭제합니다. 안에 있던 프로젝트・하위 폴더는 루트로 이동합니다.';
  }

  @override
  String get projectListFolderRootOption => '폴더 없음(루트)';

  @override
  String get projectListEditFolderTooltip => '폴더 편집';

  @override
  String get projectListCreateFolderAction => '새 폴더 만들기';

  @override
  String get projectListFolderColorLabel => '폴더 색상';

  @override
  String get projectListMaterialIncludeTitle => '소재 포함';

  @override
  String get projectListMaterialIncludeHint =>
      '포함하지 않으면 받는 쪽에서 소재 부족 경고가 표시됩니다.';

  @override
  String get projectListMaterialImage => '이미지';

  @override
  String get projectListMaterialVideo => '동영상';

  @override
  String get projectListMaterialAudio => '오디오';

  @override
  String get projectListIncludeFontsTitle => '폰트 포함';

  @override
  String get projectListIncludeFontsSubtitle => '사용 중인 사용자 추가 폰트를 포함합니다';

  @override
  String get blendModeNormal => '표준';

  @override
  String get blendModeMultiply => '곱하기';

  @override
  String get blendModeScreen => '스크린';

  @override
  String get blendModeOverlay => '오버레이';

  @override
  String get blendModeAddition => '추가';

  @override
  String get blendModeSubtract => '빼기';

  @override
  String get blendModeDarken => '어둡게 하기';

  @override
  String get blendModeLighten => '밝게 하기';

  @override
  String get blendModeColorBurn => '색상 번';

  @override
  String get blendModeColorDodge => '색상 닷지';

  @override
  String get blendModeHardLight => '하드 라이트';

  @override
  String get blendModeSoftLight => '소프트 라이트';

  @override
  String get blendModeDifference => '차이';

  @override
  String get blendModeHue => '색조';

  @override
  String get blendModeSaturation => '채도';

  @override
  String get blendModeColor => '색상';

  @override
  String get blendModeLuminosity => '광도';

  @override
  String get autofillLineColorModeSpecified => '지정 색상';

  @override
  String get autofillLineColorModeSameAsFill => '채우기 색상과 동일';

  @override
  String get autofillLineColorModeTraceAdjust => '색 트레이스・선화와 조화';

  @override
  String get autofillGradientTypeLinear => '직선';

  @override
  String get autofillGradientTypeRadialCenterOut => '방사형: 중앙→바깥쪽';

  @override
  String get autofillGradientTypeRadialOutCenter => '방사형: 바깥쪽→중앙';

  @override
  String get autofillPresetScreenTitle => '자동 채색 설정';

  @override
  String get autofillPresetSearchHint => '설정 검색';

  @override
  String get autofillPresetEmptyFavorites => '즐겨찾기한 설정이 없습니다';

  @override
  String get autofillPresetEmpty => '설정이 없습니다';

  @override
  String get autofillPresetEmptyHint => '오른쪽 아래의 ＋로 만들 수 있습니다';

  @override
  String autofillPresetPartsCount(int count) {
    return '$count개 부위';
  }

  @override
  String get autofillPresetNewDialogTitle => '새로 만들기';

  @override
  String get autofillPresetNameLabel => '설정 이름';

  @override
  String get autofillPresetRenameDialogTitle => '설정 이름 변경';

  @override
  String autofillPresetDeleteConfirmTitle(String name) {
    return '「$name」을(를) 삭제하시겠습니까?';
  }

  @override
  String get autofillFabImportOption => '가져오기';

  @override
  String get autofillPresetExportMenuItem => '내보내기 (.niafill)';

  @override
  String autofillPresetImportSuccessSnackbar(int count) {
    return '$count개의 설정을 가져왔습니다';
  }

  @override
  String autofillPresetImportFailedSnackbar(String error) {
    return '가져오기에 실패했습니다: $error';
  }

  @override
  String autofillPresetExportFailedSnackbar(String error) {
    return '내보내기에 실패했습니다: $error';
  }

  @override
  String autofillPresetDuplicateName(String name) {
    return '$name (사본)';
  }

  @override
  String get autofillPartSearchHint => '부위 이름으로 검색';

  @override
  String autofillPartUnconfiguredBanner(int count, String names) {
    return '설정되지 않은 부위가 $count개 있습니다: $names(톤 미선택)\n모두 설정할 때까지 이 화면을 닫을 수 없습니다.';
  }

  @override
  String get autofillPartUnconfiguredDialogTitle => '설정되지 않은 부위가 있습니다';

  @override
  String get autofillPartUnconfiguredDialogBody => '저장하기 전에 다음 부위를 설정해 주세요.';

  @override
  String autofillPartUnconfiguredItem(String name) {
    return '・$name: 톤이 선택되지 않았습니다';
  }

  @override
  String get autofillPartUnconfiguredBackButton => '설정으로 돌아가기';

  @override
  String get autofillPartEmpty => '부위가 없습니다\n＋ 버튼으로 추가해 주세요';

  @override
  String get autofillPartToneUnselected => '톤이 선택되지 않았습니다';

  @override
  String get autofillPartAddDialogTitle => '부위 추가';

  @override
  String get autofillPartNameLabel => '부위 이름';

  @override
  String get autofillPartAddButton => '추가';

  @override
  String get autofillPartRenameDialogTitle => '부위 이름 변경';

  @override
  String autofillPartDetailDialogTitle(String name) {
    return '$name 상세 설정';
  }

  @override
  String get autofillPartFillColorLabel => '채우기 색상';

  @override
  String get autofillPartSelectColorButton => '색상 선택';

  @override
  String get autofillPartOutlineLabel => '지정 색상으로 테두리';

  @override
  String autofillPartOutlineWidthLabel(int value) {
    return '테두리 두께: ${value}px';
  }

  @override
  String get autofillPartResetLineColorButton => '기본값으로 되돌리기';

  @override
  String get autofillThumbnailHint =>
      '썸네일 이미지(참고 일러스트 등)를 설정하면 스포이드로 색을 추출할 수 있습니다.';

  @override
  String get autofillThumbnailSetButton => '이미지 추가';

  @override
  String get autofillThumbnailChangeButton => '이미지 변경';

  @override
  String get autofillEyedropperFromThumbnailButton => '이미지에서 추출';

  @override
  String get autofillEyedropperDialogTitle => '이미지에서 색상 추출';

  @override
  String get autofillEyedropperDialogHint => '이미지를 탭하여 색상을 선택하세요';

  @override
  String get autofillEyedropperPickedLabel => '선택한 색상';

  @override
  String get autofillEyedropperImageLoadFailedSnackbar => '이미지를 불러올 수 없었습니다.';

  @override
  String get autofillThumbnailMenuItem => '썸네일 이미지 설정';

  @override
  String get autofillThumbnailLoadButton => '이미지 불러오기';

  @override
  String get autofillThumbnailDeleteButton => '썸네일 이미지 삭제';

  @override
  String get autofillThumbnailDeleteConfirmTitle => '썸네일 이미지를 삭제하시겠습니까?';

  @override
  String get autofillThumbnailDeleteConfirmBody =>
      '삭제하면 기본 파츠 색상 표시(최대 4색)로 돌아갑니다.';

  @override
  String get autofillThumbnailCropDialogTitle => '썸네일 이미지 조정';

  @override
  String get autofillThumbnailCropDialogHint =>
      '드래그로 위치 조정, 핀치로 확대/축소, 두 손가락으로 회전할 수 있습니다';

  @override
  String get autofillThumbnailCropLoadFailed =>
      '이미지를 불러올 수 없업니다. 다른 이미지를 샜도해 주세요.';

  @override
  String get autofillThumbnailSetSnackbar => '썸네일 이미지를 설정했습니다';

  @override
  String get autofillPartGradientSetButton => '그라데이션 설정';

  @override
  String get autofillPartGradientEditButton => '그라데이션 편집';

  @override
  String autofillPartFillOpacityLabel(int value) {
    return '불투명도(채우기 레이어): $value%';
  }

  @override
  String get autofillPartLineColorLabel => '선화 색상';

  @override
  String autofillPartTraceHueLabel(int value) {
    return '색조: $value';
  }

  @override
  String autofillPartTraceSaturationLabel(int value) {
    return '채도: $value';
  }

  @override
  String autofillPartTraceLightnessLabel(int value) {
    return '명도: $value';
  }

  @override
  String autofillPartLineOpacityLabel(int value) {
    return '불투명도(선화 레이어): $value%';
  }

  @override
  String get autofillPartToneLabel => '톤';

  @override
  String get autofillPartUseToneCheckbox => '톤 사용';

  @override
  String get autofillPartBlendModeLabel => '블렌드 모드';

  @override
  String get autofillPartApplyButton => '적용';

  @override
  String autofillPartGradientDialogTitle(String name) {
    return '$name 그라데이션';
  }

  @override
  String get autofillPartGradientTypeLabel => '종류';

  @override
  String get autofillPartGradientTypeInfo =>
      '직선: 지정한 각도를 따라 색이 변합니다. 방사형(중앙→외곽): 중심에서 바깥쪽으로, 방사형(외곽→중앙): 바깥쪽에서 중심으로 색이 변합니다.';

  @override
  String get autofillPartGradientFeatherInfo =>
      '0%로 설정하면 인접한 색의 경계가 뚜렷해집니다. 100%로 설정하면 옆 색상의 끝까지 완전히 부드럽게 섞입니다.';

  @override
  String get autofillLineColorModeTraceAdjustInfo =>
      '원래 선 색상을 유지한 채 색상・채도・명도만 살짝 조정합니다. 선을 단색으로 채우지 않고 선화의 농담을 살리고 싶을 때 사용합니다.';

  @override
  String autofillPartGradientAngleLabel(int value) {
    return '각도: $value°';
  }

  @override
  String get autofillPartGradientColorLabel => '색상';

  @override
  String get autofillPartGradientAddColorButton => '색상 추가';

  @override
  String get autofillPartGradientDeleteHint => '길게 눌러 삭제(색상은 최소 2개 필요)';

  @override
  String get autofillPartGradientRemoveButton => '그라데이션 해제';

  @override
  String autofillPartGradientFeatherLabel(int value) {
    return '흐림 강도: $value%';
  }

  @override
  String get autofillPartGradientDragHint => '오른쪽 핸들을 드래그하여 색상 순서를 바꿀 수 있습니다';

  @override
  String autofillPartGradientStopLabel(int value) {
    return '전환 위치: $value%';
  }

  @override
  String get autofillPartGradientStopDragHint =>
      '▲ 표시를 좌우로 드래그하여 각 색상의 위치를 조정할 수 있습니다';

  @override
  String get saveTreeScreenTitleTree => '세이브 트리';

  @override
  String get saveTreeScreenTitleSlot => '세이브 슬롯';

  @override
  String get timelineExportMenuItem => '내보내기';

  @override
  String get timelineExportFrameMenuItem => '프레임을 이미지로 내보내기';

  @override
  String get timelineExportFrameDialogTitle => '프레임을 이미지로 내보내기';

  @override
  String get timelineExportFrameDialogMessage =>
      '현재 표시 중인 프레임 1장을 정지 이미지로 저장합니다. 형식을 선택해 주세요.';

  @override
  String get timelineExportFramePngOption => 'PNG로 저장';

  @override
  String get timelineExportFrameJpegOption => 'JPEG로 저장';

  @override
  String timelineExportFrameSuccessSnackbar(String fileName) {
    return '$fileName(으)로 저장했습니다（작품 목록 탭에서 확인할 수 있습니다）';
  }

  @override
  String get timelineExportFrameErrorSnackbar => '프레임 내보내기에 실패했습니다';

  @override
  String get timelineDurationChangeMenuItem => '길이 변경';

  @override
  String get timelineCanvasSizeChangeMenuItem => '캔버스 크기 변경';

  @override
  String get timelineDurationFramesLabel => '프레임 수';

  @override
  String get timelineDurationSecondsLabel => '초수';

  @override
  String get timelineDurationShrinkConfirmTitle => '그래도 줄일까요?';

  @override
  String get timelineDurationShrinkConfirmBody =>
      '잘려나갈 범위의 프레임에는 그림 내용이나 레이어 추가 등의 변경 사항이 있습니다. 계속 진행하면 해당 프레임은 복구할 수 없습니다. 정말로 삭제하시겠습니까?';

  @override
  String get timelineCanvasSizeDragHint =>
      '테두리 안쪽을 드래그하면 위치를, 모서리를 드래그하면 크기를 바꿀 수 있습니다(원래 크기 근처에서 스냅됩니다)';

  @override
  String get timelineCanvasSizeAngleLabel => '각도';

  @override
  String get saveTreeSaveAsChildHint => '선택 중인 노드의 하위 항목으로 저장합니다.';

  @override
  String get saveTreeSaveAsRootHint => '루트 노드로 저장합니다.';

  @override
  String get saveTreeCommentLabel => '코멘트(선택 사항)';

  @override
  String get saveTreeCommentHint => '예: 배경 완성';

  @override
  String saveTreeSizeWarningSnackbar(String mb) {
    return '세이브 트리의 용량이 커지고 있습니다(약 ${mb}MB). 불필요한 저장 데이터를 삭제하는 것을 권장합니다.';
  }

  @override
  String saveTreeSlotSaveDialogTitle(int n) {
    return '슬롯 $n에 저장';
  }

  @override
  String saveTreeSlotOverwriteWarning(String date) {
    return '기존 데이터($date)를 덮어씁니다.';
  }

  @override
  String get saveTreeRestoreAction => '복원';

  @override
  String get saveTreeTimelineActionChoiceBody =>
      '이 세이브를 현재 내용으로 「덮어쓰기」할지, 「여기서부터 다시 시작」할지 선택하세요.';

  @override
  String get saveTreeOverwriteAction => '덮어쓰기';

  @override
  String get saveTreeOverwriteConfirmBody => '그 시점의 세이브 데이터가 사라집니다. 계속하시겠습니까?';

  @override
  String get saveTreeResumeFromHereAction => '여기서부터 다시 시작';

  @override
  String get saveTreeResumeConfirmBody => '저장하지 않은 현재 데이터가 사라집니다. 계속하시겠습니까?';

  @override
  String get saveTreeProjectDetailResumeBody => '이 세이브 데이터에서 작업을 다시 시작하시겠습니까?';

  @override
  String get saveTreeLoadFailedSnackbar => '저장 데이터를 불러오지 못했습니다';

  @override
  String saveTreeRestoredSnackbar(String name) {
    return '$name을(를) 복원했습니다';
  }

  @override
  String saveTreeSlotLabel(int n) {
    return '슬롯$n';
  }

  @override
  String saveTreeSlotFallbackName(int n) {
    return '슬롯 $n';
  }

  @override
  String get saveTreeNoDataLabel => '저장 데이터 없음';

  @override
  String get saveTreeEmptyTitle => '저장 데이터가 없습니다';

  @override
  String get saveTreeEmptyHint => '상단의 「저장」 버튼으로 첫 번째 노드를 만들 수 있습니다';

  @override
  String get saveTreeNodeDefaultTitle => '저장';

  @override
  String get saveTreeNodeDefaultName => '저장 데이터';

  @override
  String get saveTreeChangeDataTitle => '저장 데이터 변경';

  @override
  String saveTreeChangeDataTitleWithProject(String name) {
    return '저장 데이터 변경($name)';
  }

  @override
  String get saveTreeChangeExceedMessage =>
      '현재 저장 데이터 수가\n새 저장 가능 수를 초과했습니다.\n\n유지할 저장 데이터를 선택해 주세요.';

  @override
  String saveTreeKeepableCountLabel(int n) {
    return '유지 가능한 저장 수: $n개';
  }

  @override
  String saveTreeKeepLatestButton(int n) {
    return '최신 $n개 저장';
  }

  @override
  String get saveTreeSelectDataButton => '저장 데이터 선택';

  @override
  String saveTreeSelectedCountLabel(int selected, int limit) {
    return '선택됨: $selected / $limit개';
  }

  @override
  String get saveTreeBackButton => '뒤로';

  @override
  String get saveTreeNextButton => '다음';

  @override
  String get saveTreeDiscardDialogTitle => '선택되지 않은 저장 데이터';

  @override
  String get saveTreeArchiveOptionTitle => '보관용으로 유지(권장)';

  @override
  String get saveTreeArchiveOptionSubtitle =>
      '세이브 트리 방식으로 되돌리면 자동으로 복원됩니다.\n저장 공간을 사용합니다.';

  @override
  String get saveTreeDeleteOptionTitle => '완전히 삭제';

  @override
  String saveTreeDeleteOptionSubtitle(int count) {
    return '선택되지 않은 $count개를 완전히 삭제합니다.\n저장 공간을 절약할 수 있습니다.\n※삭제한 데이터는 되돌릴 수 없습니다.';
  }

  @override
  String get saveTreeApplyChangeButton => '변경 적용';

  @override
  String get canvasEditMenuAutofillPresets => '자동 채색 설정';

  @override
  String get canvasEditMenuAutofillPresetsSubtitle => '부위별 색・톤 조합을 편집';

  @override
  String get canvasEditMenuBackgroundToggle => '배경 전환';

  @override
  String get canvasEditMenuBackgroundCurrentColor => '현재: 프로젝트 배경색(탭하면 투명으로)';

  @override
  String get canvasEditMenuBackgroundCurrentTransparent =>
      '현재: 투명(탭하면 프로젝트 배경색으로)';

  @override
  String get canvasEditMenuOnionSkinSubtitle => '앞뒤 프레임을 흐리게 겹쳐서 표시';

  @override
  String get canvasEditMenuFilterSubtitle => '흐림, 톤 커브 등을 적용';

  @override
  String get canvasEditMenuFrameMultiSelect => '프레임 다중 선택';

  @override
  String get canvasEditMenuFrameMultiSelectSubtitle => '대량 처리(필터 일괄 적용 등)에 사용';

  @override
  String get canvasEditMenuPressureCurve => '필압 곡선';

  @override
  String get canvasEditMenuPressureCurveSubtitle => '펜 입력 설정 열기(설정 화면과 공용)';

  @override
  String get canvasEditMenuMeshTransform => '자유 변형・메시 변형';

  @override
  String get canvasEditMenuMeshTransformSubtitle => '선택 없이 레이어 전체를 변형합니다';

  @override
  String get meshTransformPanelTitle => '자유 변형・메시 변형';

  @override
  String get meshTransformPanelHint =>
      '손가락으로 모서리나 격자점을 드래그하세요(두 손가락으로 각각 다른 점을 잡으면 회전·확대축소도 가능)';

  @override
  String get meshTransformDensityLabel => '분할 수';

  @override
  String get meshTransformRotateLabel => '회전';

  @override
  String get meshTransformScaleLabel => '확대축소';

  @override
  String get meshTransformApplyButton => '적용';

  @override
  String get canvasLassoEnclosedLabel => '둘러싸서 채우기';

  @override
  String get canvasInvertSelectionTooltip => '선택 영역 반전';

  @override
  String get canvasTapToEnterTextLabel => '캔버스를 탭하여 텍스트 입력';

  @override
  String get canvasRulerFirstUseTip => '자를 사용하면 곧은 선이나 깔끔한 도형을 그릴 수 있습니다.';

  @override
  String get canvasRulerTooltip => '자';

  @override
  String get commonUndo => '실행 취소';

  @override
  String get commonRedo => '다시 실행';

  @override
  String get canvasSettingsMenuTooltip => '설정/편집';

  @override
  String canvasFrameSelectedCount(int selected, int total) {
    return '$selected / $total 프레임 선택됨';
  }

  @override
  String get canvasSelectAllButton => '전체 선택';

  @override
  String get canvasDeselectAllButton => '전체 해제';

  @override
  String get canvasApplyFilterButton => '필터 적용';

  @override
  String get canvasShapeOff => 'OFF(일반 브러시로 돌아가기)';

  @override
  String get canvasShapeLine => '선';

  @override
  String get canvasShapeRect => '사각형';

  @override
  String get canvasShapeCircle => '원';

  @override
  String get canvasMissingMaterialsSnackbar => '소재가 부족합니다';

  @override
  String get canvasResearchButton => '다시 검색';

  @override
  String get canvasTextInputTitle => '텍스트 입력';

  @override
  String get canvasTextEditTitle => '텍스트 편집';

  @override
  String get canvasTextInputHint => '텍스트를 입력하세요';

  @override
  String get canvasTextFontLabel => '폰트';

  @override
  String get canvasTextStandardFont => '표준 폰트';

  @override
  String get canvasTextBold => '굵게';

  @override
  String get canvasTextItalic => '기울임꼴';

  @override
  String get canvasTextVertical => '세로쓰기';

  @override
  String get canvasTextHorizontal => '가로쓰기';

  @override
  String get canvasTypesettingHelpTooltip => '조판・루비에 대하여';

  @override
  String get canvasTextLineHeight => '줄 간격';

  @override
  String get canvasTextLetterSpacing => '자간';

  @override
  String get canvasTextAlign => '정렬';

  @override
  String get canvasTextOutline => '테두리';

  @override
  String get canvasOutlineWidthLabel => '굵기';

  @override
  String get canvasHelpRotationTitle => '반각 영숫자 회전(세로쓰기 전용)';

  @override
  String get canvasHelpRotationBody => '영문자・기호는 자동으로 90° 회전하여 표시됩니다.';

  @override
  String get canvasHelpTatechuyokoTitle => '다테추요코(세로쓰기 전용)';

  @override
  String get canvasHelpTatechuyokoBody =>
      '반각 숫자가 2자리 연속되면 한 글자 높이에 가로로 나란히 자동으로 들어갑니다(예: 12).';

  @override
  String get canvasHelpRubyTitle => '루비(후리가나)';

  @override
  String canvasHelpRubyBody(String example) {
    return '「$example」와 같이 입력하면 바탕 문자 위(가로쓰기)나 오른쪽(세로쓰기)에 작은 읽는 법이 표시됩니다. 세로쓰기・가로쓰기 모두 사용할 수 있지만, 루비가 포함된 텍스트는 가로쓰기에서 자동 줄바꿈이 되지 않습니다(수동 줄바꿈만 지원).';
  }

  @override
  String get layerPanelTitle => '레이어';

  @override
  String get layerPanelHelpTooltip => '도움말';

  @override
  String get layerPanelSearchHint => '레이어 이름으로 검색';

  @override
  String get layerPanelSelectAll => '전체 선택';

  @override
  String get layerPanelDeselectAll => '전체 해제';

  @override
  String get layerPanelNewLayerButton => '새 레이어';

  @override
  String get layerPanelNewFolderButton => '새 폴더';

  @override
  String get layerPanelImportImageButton => '이미지 불러오기';

  @override
  String layerPanelDefaultLayerName(int n) {
    return '레이어$n';
  }

  @override
  String layerPanelDefaultFolderName(int n) {
    return '폴더$n';
  }

  @override
  String layerPanelDefaultLineartName(int n) {
    return '선화$n';
  }

  @override
  String layerPanelDefaultAutofillName(int n) {
    return '자동 채색$n';
  }

  @override
  String layerPanelDefaultCommonName(int n) {
    return '공통$n';
  }

  @override
  String layerPanelDefaultSelectionName(int n) {
    return '선택$n';
  }

  @override
  String get layerPanelClippingBadge => '클리핑';

  @override
  String get layerPanelAddTooltip => '추가';

  @override
  String get layerPanelMergeTooltip => '결합';

  @override
  String get layerPanelSettingsTooltip => '레이어 설정';

  @override
  String get layerPanelAutofillMarkTooltip =>
      '선화가 업데이트되었습니다. 탭하면 자동 채색을 최신 상태로 업데이트할 수 있습니다.';

  @override
  String get layerPanelRangeAllFrames => '전체 프레임';

  @override
  String get layerPanelRangeCurrentScene => '현재 씬';

  @override
  String get layerPanelRangeSceneSpecified => '씬 지정';

  @override
  String layerPanelRangeFrameSpan(int start, int end) {
    return '$start〜$end';
  }

  @override
  String get layerPanelMenuFrameRangeChange => '표시 프레임 범위 변경';

  @override
  String get layerPanelMenuRangeChange => '표시 범위 변경';

  @override
  String get layerPanelMenuPartAssign => '파츠 설정';

  @override
  String get layerPanelMenuRunAutofill => '자동 채색 실행';

  @override
  String get layerPanelMenuOrphanFill => '최신 색으로 채우기';

  @override
  String get layerPanelMenuOrphanFillSubtitle =>
      '대응하는 선화 레이어를 찾을 수 없어 색 업데이트만 실행합니다';

  @override
  String get layerPanelMenuReplaceMaterial => '소재 교체';

  @override
  String layerPanelDeleteConfirmTitle(String name) {
    return '$name을(를) 삭제하시겠습니까?';
  }

  @override
  String get layerPanelDeleteConfirmBody => '이 소재의 표시 범위 내 모든 프레임에서 삭제됩니다.';

  @override
  String layerPanelMultiDeleteConfirmTitle(int count) {
    return '선택한 $count개 항목을 삭제하시겠습니까?';
  }

  @override
  String get layerPanelMultiDeleteConfirmBody =>
      '타임라인 소재의 표시 범위 내 모든 프레임에서 삭제됩니다.';

  @override
  String layerPanelCommonDeleteMidDialogTitle(String name) {
    return '$name의 표시 범위를 변경하시겠습니까?';
  }

  @override
  String get layerPanelCommonDeleteMidDialogBody =>
      '공통 레이어의 표시 범위는 연속된 1개 구간으로만 설정할 수 있어, 범위 도중의 프레임에서는 삭제할 수 없습니다. 대신 이 프레임을 기준으로 이전과 이후 중 어느 쪽을 남길지 선택해 주세요.';

  @override
  String get layerPanelCommonDeleteKeepBeforeButton => '이전을 남기기';

  @override
  String get layerPanelCommonDeleteKeepAfterButton => '이후를 남기기';

  @override
  String get layerPanelRangeDialogTitle => '표시 범위';

  @override
  String get layerPanelRangeStartFrameLabel => '시작 프레임';

  @override
  String get layerPanelRangeEndFrameLabel => '종료 프레임';

  @override
  String get layerPanelRangeTilde => '〜';

  @override
  String get layerPanelRangeUseCurrentButton => '현재 범위 사용';

  @override
  String get layerPanelRangeTargetSceneLabel => '대상 씬';

  @override
  String get layerPanelRangeFrameRangeLabel => '프레임 범위 지정';

  @override
  String get layerPanelMenuNormalLayer => '일반 레이어';

  @override
  String get layerPanelMenuCommonLayer => '공통 레이어';

  @override
  String get layerPanelMenuLineartLayer => '자동 채색용 선화 레이어';

  @override
  String get layerPanelMenuAutofillLayer => '자동 채색 레이어';

  @override
  String get layerPanelMenuSelectionLayer => '선택 레이어';

  @override
  String get layerPanelOpacityLabel => '불투명도';

  @override
  String get layerPanelLockLabel => '잠금';

  @override
  String get layerPanelOpacityLockLabel => '불투명도 잠금';

  @override
  String get layerPanelClippingDescription => '아래 레이어의 불투명 범위 내에만 그리기';

  @override
  String get layerPanelConvertToCommonLabel => '공통 레이어로 변경';

  @override
  String get layerPanelConvertOption1Title => '현재 레이어를 공통화';

  @override
  String get layerPanelConvertOption1Subtitle => '이 레이어만 공통 레이어로 설정합니다';

  @override
  String get layerPanelConvertOption2Title => '표시 중인 레이어를 병합해 공통화';

  @override
  String get layerPanelConvertOption2Subtitle =>
      '현재 표시 중인 모든 레이어를 통합한 결과를 공통 레이어로 만듭니다';

  @override
  String get layerPanelCommonRangeTitle => '공통 레이어 범위';

  @override
  String get layerPanelHelpDialogTitle => '레이어에 대하여';

  @override
  String get layerPanelHelpBlendModeBody =>
      '레이어의 합성 방식을 변경합니다. 곱하기・스크린・오버레이 등이 있습니다.';

  @override
  String get layerPanelHelpClippingBody =>
      '아래 레이어의 불투명 픽셀 범위 내에만 그립니다. 그리기 범위를 제어하고 싶을 때 사용하세요.';

  @override
  String get layerPanelCommonLayerLabel => '공통 레이어';

  @override
  String get layerPanelHelpCommonLayerBody =>
      '여러 프레임에서 같은 내용을 공유하는 레이어입니다. 표시할 프레임 범위를 설정할 수 있습니다.';

  @override
  String get layerPanelAutofillMethodTitle => '자동 채색 방법';

  @override
  String get layerPanelAutofillNoLineartSnackbar =>
      '대응하는 자동 채색용 선화 레이어를 찾을 수 없습니다.';

  @override
  String get layerPanelAutofillNote1 =>
      '※ 프로젝트에서 처음으로 자동 채색을 실행하는 경우 어느 쪽을 선택해도 문제없습니다.';

  @override
  String get layerPanelAutofillNote2 =>
      '※ 자동 채색 레이어가 없는 경우 어느 쪽을 선택해도 영역을 처음부터 판정해 자동 채색합니다.';

  @override
  String get layerPanelAutofillRepaintTitle => '다시 채색';

  @override
  String get layerPanelAutofillRepaintHint => '실수로 자동 채색 모양을 바꿔버린 경우 추천';

  @override
  String get layerPanelAutofillRepaintNote =>
      '※ 영역을 처음부터 판정해 다시 채색합니다. 현재 자동 채색 레이어의 모양은 폐기됩니다.';

  @override
  String get layerPanelAutofillColorUpdateTitle => '색 업데이트';

  @override
  String get layerPanelAutofillColorUpdateHint => '자동 채색 모양을 수동으로 조정한 경우 추천';

  @override
  String get layerPanelAutofillColorUpdateNote =>
      '※ 불투명도를 잠그고 최신 색으로 채웁니다. 현재 자동 채색 레이어의 모양은 유지됩니다.';

  @override
  String get layerPanelExecuteButton => '실행';

  @override
  String get layerPanelAutofillPartMissingSnackbar =>
      '파츠가 설정되지 않았습니다.「파츠 설정」에서 설정해 주세요.';

  @override
  String get layerPanelAutofillPresetMissingSnackbar =>
      '자동 채색 설정에서 대응하는 부위를 찾을 수 없습니다.';

  @override
  String layerPanelAutofillLayerNameSuffix(String name) {
    return '$name（자동 채색）';
  }

  @override
  String get layerPanelOrphanFillSuccessSnackbar =>
      '대응하는 선화 레이어를 찾을 수 없어 최신 색으로 채웠습니다.';

  @override
  String get layerPanelOrphanFillFailSnackbar =>
      '파츠가 설정되지 않았거나 채울 모양이 없어 처리할 수 없었습니다.';

  @override
  String get layerPanelAutofillUpdateHelpTitle => '자동 채색 업데이트 표시';

  @override
  String get layerPanelAutofillUpdateHelpBody =>
      '현재 자동 채색이 최신 상태가 아닙니다. 탭하면 업데이트할 수 있습니다.';

  @override
  String layerPanelReplaceMaterialSuccessSnackbar(String name) {
    return '소재를 교체했습니다: $name';
  }

  @override
  String layerPanelImportImageSuccessSnackbar(String name) {
    return '이미지를 불러왔습니다: $name';
  }

  @override
  String layerPanelCopySuffix(String name) {
    return '$name 사본';
  }

  @override
  String get timelineFullscreenPreviewCloseTooltip => '전체 화면 미리보기 닫기';

  @override
  String get timelineDefaultProjectName => '프로젝트 이름';

  @override
  String get timelineProjectSaveMenuItem => '프로젝트 저장';

  @override
  String get timelinePreviewPlaceholder => '미리보기';

  @override
  String get timelinePreviewFullscreenTip =>
      '탭하면 미리보기를 전체 화면으로 볼 수 있습니다. 완성도 확인에 편리합니다.';

  @override
  String get timelinePreviewFullscreenTooltip => '미리보기 전체 화면으로 보기';

  @override
  String get timelineAddImageTooltip => '＋이미지';

  @override
  String get timelineAddVideoTooltip => '＋동영상';

  @override
  String get timelineAddAudioTooltip => '＋음원';

  @override
  String get timelineEffectFilterLabel => '연출 필터';

  @override
  String get timelineAddCameraKfTooltip => '카메라 키프레임 추가';

  @override
  String get timelineAddWatermarkTooltip => '＋워터마크';

  @override
  String get timelineWatermarkNotRegisteredTitle => '등록된 워터마크 없음';

  @override
  String get timelineWatermarkNotRegisteredBody =>
      '설정 화면의 「워터마크」에서 미리 이미지 또는 텍스트를 등록해 주세요.';

  @override
  String get timelineOpenSettingsButton => '설정 열기';

  @override
  String get timelineWatermarkSelectTitle => '워터마크 선택';

  @override
  String timelineWatermarkAddedSnackbar(String name) {
    return '워터마크를 추가했습니다（모든 프레임에 표시됩니다）: $name';
  }

  @override
  String get timelineWatermarkEditTitle => '워터마크 편집';

  @override
  String get timelineWatermarkAngleLabel => '각도';

  @override
  String get timelineWatermarkSizeLabel => '크기';

  @override
  String get timelineWatermarkOpacityLabel => '불투명도';

  @override
  String get timelineWatermarkLoopLabel => '항상 표시（반복 표시）';

  @override
  String get timelineWatermarkLoopSubtitle => '끄면 현재 장면에서만 표시됩니다';

  @override
  String get timelineConfirmButton => '확정';

  @override
  String get timelineClipSelectDoneButton => '완료';

  @override
  String get timelineClipOverlapDialogTitle => '기존 클립과 겹칩니다';

  @override
  String get timelineClipOverlapDialogBody =>
      '붙여넣을 위치가 기존 클립과 겹칩니다. 어떻게 배치할까요?';

  @override
  String get timelineClipOverlapPlaceBefore => '앞에 배치';

  @override
  String get timelineClipOverlapPlaceAfter => '뒤에 배치';

  @override
  String get timelineClipOverlapPlaceNewRow => '겹치게 배치（행 추가）';

  @override
  String get timelineSceneRenameTitle => '씬 이름 변경';

  @override
  String get timelineSceneDeleteMenuItem => '씬 삭제';

  @override
  String get timelineDurationLimitTitle => '길이 상한에 도달합니다';

  @override
  String get timelineDurationLimitBodyFree =>
      '무료 회원은 동영상 길이가 최대 90초까지입니다. 프레임을 더 추가하거나 복제하면 90초를 초과하게 되어 실행할 수 없습니다. 프리미엄 회원이 되면 최대 2시간까지 제작할 수 있습니다.';

  @override
  String get timelineDurationLimitBodyPremium =>
      '프리미엄 회원 상한(최대 2시간)을 초과하게 되어 더 이상 프레임을 추가하거나 복제할 수 없습니다.';

  @override
  String timelineSceneDeleteConfirmTitle(String name) {
    return '「$name」을(를) 삭제하시겠습니까?';
  }

  @override
  String get timelineSceneDeleteConfirmBody =>
      '씬 내의 모든 프레임・공통 레이어・동영상 소재・이미지 소재・워터마크를 포함한 모든 데이터가 삭제됩니다.';

  @override
  String timelineSceneMultiDeleteConfirmTitle(int count) {
    return '선택한 $count개의 씬을 삭제하시겠습니까?';
  }

  @override
  String get timelineAutofillUpdateHelpBody =>
      '이 씬・프레임에는 최신이 아닌 자동 채색 레이어가 포함되어 있습니다. 레이어 패널에서 대상 레이어를 탭하면 업데이트할 수 있습니다.';

  @override
  String get timelineFrameTrackLabel => '프레임';

  @override
  String get timelineTrackRowDeleteBlockedSnackbar =>
      '이 행에는 소재가 있어 삭제할 수 없습니다. 먼저 소재를 이동하거나 삭제하세요.';

  @override
  String get timelineTrackRowRenameTitle => '행 이름 변경';

  @override
  String get timelineCameraTrackLabel => '카메라';

  @override
  String get timelineRangeSceneFixed => '씬 고정';

  @override
  String get timelineEndCardCustomLabel => '교체됨';

  @override
  String get timelineEndCardDefaultLogoLabel => 'NIARIM 로고';

  @override
  String timelineEndCardStatusFormat(String label, int seconds) {
    return '$label・$seconds초';
  }

  @override
  String get timelineEndCardHiddenLabel => '숨김';

  @override
  String get timelineEndCardVisibilityToggleTooltip => '표시 켜기/끄기';

  @override
  String get timelineEndCardLengthChangeTooltip => '길이 변경';

  @override
  String get timelineEndCardReplaceTooltip => '교체';

  @override
  String get timelineEndCardLengthDialogTitle => '엔드카드 길이';

  @override
  String get timelineEndCardTrackLabel => '엔드카드 트랙';

  @override
  String get timelineMarkerTrackLabel => '타임스탬프';

  @override
  String timelineMarkerAddDialogTitle(int n) {
    return 'F$n에 타임스탬프 추가';
  }

  @override
  String timelineMarkerEditDialogTitle(int n) {
    return '타임스탬프: F$n';
  }

  @override
  String get timelineMarkerCommentHint => '코멘트（예: 여기서 입모양 「아」）';

  @override
  String timelineSecondsLabel(int n) {
    return '$n초';
  }

  @override
  String timelineAddClipDialogTitle(String trackName) {
    return '$trackName 클립 추가';
  }

  @override
  String get timelineClipLabelFieldLabel => '라벨';

  @override
  String get timelineClipStartLabel => '시작:';

  @override
  String get timelineClipLengthLabel => '길이:';

  @override
  String get timelineSaveSuccessSnackbar => '프로젝트를 저장했습니다';

  @override
  String get timelineAutofillNote2 =>
      '※ 자동 채색 레이어만 존재하는 경우（선화 없음）어느 쪽을 선택해도 영역을 처음부터 판정해 자동 채색합니다.';

  @override
  String get timelineAutofillTargetLabel => '실행 대상';

  @override
  String get timelineAutofillScopeCurrentFrame => '현재 프레임만';

  @override
  String get timelineAutofillScopeCurrentScene => '씬 단위（현재 씬의 전체 프레임）';

  @override
  String get timelineAutofillScopeAllScenes => '전체 프레임（프로젝트 전체）';

  @override
  String get timelineAutofillProgressTitle => '자동 채색 실행 중';

  @override
  String timelineAutofillProgressSubtitle(int count) {
    return '$count프레임';
  }

  @override
  String timelineAutofillCompleteSnackbar(int count) {
    return '자동 채색이 완료되었습니다（$count건 처리）';
  }

  @override
  String get timelineEffectTypeFade => '페이드';

  @override
  String get timelineEffectTypeGaussianBlur => '가우시안 블러';

  @override
  String get timelineEffectTypeLensBlur => '렌즈 블러';

  @override
  String get timelineEffectTypeMosaic => '모자이크';

  @override
  String get timelineEffectTypeChromaticAberration => '색수차';

  @override
  String get timelineEffectTypeNoise => '노이즈';

  @override
  String get timelineEffectTypeSepia => '세피아';

  @override
  String get timelineEffectTypeAnimeStyle => '애니메 스타일';

  @override
  String get timelineEffectTypeRetroAnime => '레트로 애니메';

  @override
  String get timelineEffectTypeCrt => '브라운관';

  @override
  String get timelineEffectTypeAnimatedNoise => '움직이는 노이즈';

  @override
  String get timelineEffectTypeRain => '비';

  @override
  String get timelineEffectFilterEmptyState => '필터가 없습니다\n＋추가 버튼으로 추가해 주세요';

  @override
  String get timelineRangeStartLabel => '시작';

  @override
  String get timelineRangeEndLabel => '종료';

  @override
  String get timelineEffectSizeLabel => '크기';

  @override
  String get timelineEffectStrengthLabel => '강도';

  @override
  String get timelineEffectAmountLabel => '양';

  @override
  String get timelineEffectGrainSizeLabel => '입자 크기';

  @override
  String get timelineEffectRainIntensityLabel => '강수량';

  @override
  String get timelineEffectRainSpeedLabel => '속도';

  @override
  String get timelineEffectRainSizeLabel => '빗방울 크기';

  @override
  String get timelineEffectWindAngleLabel => '바람 방향';

  @override
  String get timelineColorLabel => '색상';

  @override
  String get timelineColorBlack => '검정';

  @override
  String get timelineColorWhite => '흰색';

  @override
  String get timelineColorCustom => '커스텀';

  @override
  String get timelineFadeColorDialogTitle => '페이드 색상';

  @override
  String get timelineAddFilterDialogTitle => '필터 추가';

  @override
  String get timelineClipVolumeLabel => '음량';

  @override
  String get timelineClipFadeInLabel => '페이드 인';

  @override
  String get timelineClipFadeOutLabel => '페이드 아웃';

  @override
  String get timelineClipUseStartLabel => '사용 시작F';

  @override
  String get timelineClipUseEndLabel => '사용 종료F';

  @override
  String timelineCameraKfTitle(int n) {
    return '카메라 KF: F$n';
  }

  @override
  String get timelineCameraMoveXLabel => 'X 이동';

  @override
  String get timelineCameraMoveYLabel => 'Y 이동';

  @override
  String get timelineCameraZoomLabel => '줌';

  @override
  String get timelineCameraRotationLabel => '회전';

  @override
  String get layerPanelKeyframeLabel => '애니메이션（키프레임）';

  @override
  String layerKeyframeSheetTitle(String name) {
    return '$name의 키프레임';
  }

  @override
  String get layerKeyframeSheetDesc =>
      '이 레이어의 위치・확대축소・회전을 프레임마다 지정하면 키프레임 사이가 자동으로 보간됩니다. 레이어의 그림 자체는 바뀌지 않습니다.';

  @override
  String layerKeyframeAddAtCurrentFrame(int n) {
    return '현재 프레임（F$n）에 추가';
  }

  @override
  String get layerKeyframeEmpty => '키프레임이 없습니다. 위 버튼으로 추가하세요.';

  @override
  String get layerKeyframeScaleShort => '배율';

  @override
  String get layerKeyframeRotationShort => '회전';

  @override
  String layerKeyframeEditTitle(int n) {
    return '키프레임: F$n';
  }

  @override
  String get layerKeyframeFrameLabel => '프레임';

  @override
  String get layerKeyframeScaleLabel => '확대축소';

  @override
  String get layerKeyframeRotationLabel => '회전';

  @override
  String get layerKeyframeEasingLabel => '다음 키프레임으로 이어지는 방식';

  @override
  String get layerKeyframeEasingLinear => '등속';

  @override
  String get layerKeyframeEasingEaseIn => '천천히 시작';

  @override
  String get layerKeyframeEasingEaseOut => '천천히 종료';

  @override
  String get layerKeyframeEasingEaseInOut => '천천히 시작하고 종료';

  @override
  String get layerKeyframeEasingBounceOut => '튕김';

  @override
  String get layerPanelGroupTooltip => '그룹화';

  @override
  String get layerPanelShowSelectedTooltip => '선택한 레이어를 모두 표시';

  @override
  String get layerPanelHideSelectedTooltip => '선택한 레이어를 모두 숨기기';

  @override
  String get layerPanelGroupDefaultName => '새 그룹';

  @override
  String layerPanelGroupMembershipLabel(String name) {
    return '그룹: $name';
  }

  @override
  String get layerPanelGroupLeaveAction => '해제';

  @override
  String frameStripHoldDialogTitle(int n) {
    return 'F$n 유지 셀 수';
  }

  @override
  String get frameStripTimelineModeTooltip => '타임라인 모드';

  @override
  String get frameStripFrameListModeLabel => '프레임 목록';

  @override
  String get frameStripTimelineModeLabel => '타임라인';

  @override
  String get progressDialogAdLoading => '광고 불러오는 중…';

  @override
  String get progressDialogTipLabel => '팁';

  @override
  String get premiumBannerRegisterButton => 'Premium에 가입';

  @override
  String get licenseTermsArt1Title => '제1조（적용）';

  @override
  String get licenseTermsArt1Body =>
      '본 이용약관（이하「본 약관」이라 합니다）은 본 앱「NIARIM」（이하「본 앱」이라 합니다）의 이용 조건을 정하는 것입니다. 사용자는 본 약관에 동의한 후 본 앱을 이용하는 것으로 합니다. 본 앱을 이용함으로써 본 약관에 동의한 것으로 간주합니다.';

  @override
  String get licenseTermsArt2Title => '제2조（이용 자격・지원 환경）';

  @override
  String get licenseTermsArt2Body =>
      '1. 지원 OS 및 권장 운영 환경의 상세 내용은 각 배포 스토어 및 본 앱 내 표시에 따릅니다.\n2. 본 앱은 다양한 성능의 단말기에서도 쾌적하게 이용하실 수 있도록 노력하고 있으나, 단말기의 성능・OS 버전・여유 용량・설정 등 이용 환경에 따라 일부 기능이 제한되거나 정상적으로 작동하지 않을 수 있습니다.';

  @override
  String get licenseTermsArt3Title => '제3조（금지 사항）';

  @override
  String get licenseTermsArt3Body =>
      '사용자는 본 앱 이용 시 다음 행위를 해서는 안 됩니다.\n・법령 또는 공서양속에 위반하는 행위\n・본 앱, 개발자 또는 제3자의 저작권・상표권 등 지적재산권, 초상권, 프라이버시 기타 권리 또는 이익을 침해하는 행위\n・본 앱의 디컴파일, 디스어셈블, 리버스 엔지니어링 기타 해석을 목적으로 하는 행위（법령상 인정되는 경우는 제외）\n・본 앱의 부정한 개조, 복제 또는 재배포\n・본 앱 또는 그 제공 기반에 대한 부정 접속, 과도한 부하 기타 정상적인 제공을 방해하는 행위\n・기타 개발자가 합리적인 이유에 근거하여 부적절하다고 판단하는 행위';

  @override
  String get licenseTermsArt4Title => '제4조（제작 콘텐츠의 권리）';

  @override
  String get licenseTermsArt4Body =>
      '1. 사용자가 본 앱을 이용하여 제작한 일러스트・애니메이션 등의 콘텐츠（프로젝트 데이터・내보낸 이미지・동영상 등을 포함합니다. 이하「제작 콘텐츠」라 합니다）에 관한 저작권 기타 권리는, 법령상 인정되는 범위 내에서 해당 콘텐츠에 대해 권리를 가진 사용자 또는 제3자에게 귀속됩니다.\n2. 본 앱은 제작 콘텐츠를 개발자의 서버로 전송・수집・동기화하는 기능을 제공하지 않습니다. 프로젝트 데이터는 원칙적으로 사용자의 단말기 내에만 저장됩니다（사용자가 스스로의 의사로 작품 광장 기능을 이용하여 제작 콘텐츠를 게시하는 경우의 취급에 대해서는 제12조에 따릅니다）.\n3. 무료판・프리미엄판 중 어느 것을 이용하여 제작한 경우라도, 본 앱의 이용 요금이나 에디션을 이유로 개발자가 제작 콘텐츠의 상업적 이용을 제한하는 일은 없습니다（무료판・프리미엄판의 차이는 엔드카드 표시나 내보내기 시간 상한 등 기능 면에 한정됩니다）.\n4. 전항에도 불구하고, 사용자가 본 앱에 추가한 폰트・이미지・소재 등 제3자가 권리를 가진 것에 대해서는 각각의 이용 조건（제5조）에 따라야 합니다.';

  @override
  String get licenseTermsArt5Title => '제5조（내장 폰트・추가 소재에 관하여）';

  @override
  String get licenseTermsArt5Body =>
      '1. 본 앱에 내장된 폰트 기타 소재는 본 화면「사용 폰트에 관하여」에 기재된 각 라이선스 조건에 따라 이용되고 있습니다.\n2. 사용자가 본 앱에 추가 등록・불러오기한 폰트, 이미지, 톤, 스탬프 등 소재의 권리 관계에 대해서는 사용자 본인의 책임하에 필요한 권리 또는 허락을 취득한 후 적법하게 이용해 주십시오.\n3. 사용자의 제3자 소재 이용에 기인하여 제3자와의 사이에 분쟁 등이 발생한 경우, 개발자는 법령상 책임을 지는 경우를 제외하고 그 책임을 지지 않습니다.';

  @override
  String get licenseTermsArt6Title => '제6조（프리미엄 기능・결제）';

  @override
  String get licenseTermsArt6Body =>
      '1. 본 앱에는 무료로 이용할 수 있는 기능 외에, 앱 내 결제（월간 플랜, 연간 플랜 기타 프리미엄 플랜）를 통해 이용 가능한 프리미엄 기능이 있습니다.\n2. 프리미엄 기능의 가격, 제공 내용, 구매 방법 기타 조건은 구매 시점의 본 앱 내 또는 배포 스토어의 표시에 따릅니다.\n3. 구매 후 취소・환불 기타 결제에 관한 사항에는 Google Play 기타 이용하시는 결제 플랫폼의 규정이 적용됩니다. 다만, 법령에 별도의 정함이 있는 경우에는 그 정함에 따릅니다.\n4. 개발자는 법령 개정, 기술상의 필요성, 본 앱의 개선 기타 합리적인 사유에 의해 프리미엄 기능의 내용을 변경할 수 있습니다. 중요한 변경을 하는 경우에는 가능한 한 사전에 본 앱 내 기타 적절한 방법으로 안내합니다.';

  @override
  String get licenseTermsArt7Title => '제7조（광고 표시）';

  @override
  String get licenseTermsArt7Body =>
      '1. 무료판에서는 제3자 광고 배포 서비스를 통한 광고가 표시될 수 있습니다.\n2. 광고 배포 사업자에 의한 정보의 취득・이용 기타 취급에 대해서는 각 광고 배포 사업자의 개인정보처리방침이 적용됩니다.';

  @override
  String get licenseTermsArt8Title => '제8조（정보의 취급）';

  @override
  String get licenseTermsArt8Body =>
      '1. 본 앱은 사용자가 제작한 일러스트・애니메이션 등의 콘텐츠 및 프로젝트 데이터를 개발자의 서버로 전송・수집하는 기능을 제공하지 않습니다. 이들은 원칙적으로 사용자의 단말기 내에만 저장되며, 개발자는 이를 스스로 저장하는 기능을 가지고 있지 않으므로 개발자 측에서의 보관 기간이라는 개념 자체가 존재하지 않습니다.\n2. 본 앱이 포함하는 제3자 서비스（광고 배포・앱 내 결제 등）에 의한 정보 취득 기타 사용자 정보의 취급에 관해서는 별도로 정하는「개인정보처리방침」의 규정에 따릅니다.\n3. 본 앱을 삭제（언인스톨）한 경우, 단말기 내에 저장된 데이터（프로젝트, 설정, 추가한 폰트 등）는 삭제됩니다.';

  @override
  String get licenseTermsArt9Title => '제9조（제공의 중지・변경・종료）';

  @override
  String get licenseTermsArt9Body =>
      '1. 개발자는 본 앱의 유지보수・업데이트・수정을 실시하는 경우, 제공 기반에 장애가 발생한 경우 기타 부득이한 사정이 있는 경우, 본 앱의 전부 또는 일부의 제공을 일시적으로 중지할 수 있습니다.\n2. 개발자는 필요에 따라 본 앱의 내용을 변경하거나 본 앱의 제공을 종료할 수 있습니다.\n3. 전 2항의 경우, 긴급한 경우를 제외하고 가능한 한 사전에 본 앱 내 기타 적절한 방법으로 고지합니다.\n4. 본 조에 근거한 변경・중지・종료로 인해 사용자에게 발생한 손해에 대해, 개발자는 법령상 책임을 지는 경우를 제외하고 책임을 지지 않습니다.';

  @override
  String get licenseTermsArt10Title => '제10조（면책 사항）';

  @override
  String get licenseTermsArt10Body =>
      '1. 개발자는 본 앱에 대해 사실상 또는 법률상의 하자（안전성・신뢰성・정확성・완전성・특정 목적에의 적합성・버그나 결함이 없음 등을 포함합니다）가 없음을 보증하지 않습니다.\n2. 사용자는 본 앱을 자기 책임하에 이용하는 것으로 합니다. 단말기 고장・오조작・OS 업데이트 기타 사정으로 데이터가 소실될 수 있으므로, 제작 중인 데이터에 대해서는 내보내기・공유 기능 등을 이용한 정기적인 백업을 권장합니다.\n3. 본 앱의 이용으로 인해 사용자에게 발생한 손해에 대해, 개발자는 법령상 인정되는 범위에서 책임을 지지 않습니다. 다만 개발자에게 고의 또는 중대한 과실이 있는 경우는 그러하지 아니하며, 그 경우에도 개발자가 지는 손해배상 책임은 통상 발생할 수 있는 직접 손해에 한하며, 사용자가 본 앱에 관해 직전 1년간 실제로 지불한 금액（무료로 이용한 경우는 0원）을 상한으로 합니다.';

  @override
  String get licenseTermsArt11Title => '제11조（본 약관의 변경）';

  @override
  String get licenseTermsArt11Body =>
      '1. 개발자는 법령 개정, 본 앱 내용의 변경 기타 필요하다고 판단한 경우, 본 약관을 변경할 수 있습니다.\n2. 본 약관을 변경하는 경우, 변경 내용 및 효력 발생일을 본 앱 내 기타 적절한 방법으로 사전에 고지합니다.\n3. 변경 후의 본 약관은 법령상 인정되는 범위 내에서 전항의 효력 발생일부터 적용됩니다.';

  @override
  String get licenseTermsArt12Title => '제12조（작품 광장：커뮤니티 게시 기능）';

  @override
  String get licenseTermsArt12Body =>
      '1. 본 앱은 사용자가 제작한 애니메이션 작품을 사용자 본인의 Google 계정을 통해 YouTube에 게시하고, 「작품 광장」에서 공개・열람할 수 있는 기능（이하「본 커뮤니티 기능」이라 합니다）을 임의로 제공합니다. 작품의 열람・제작 자체는 본 커뮤니티 기능을 이용하지 않아도 가능합니다.\n2. 게시된 동영상 파일 자체는 YouTube상에 저장되며, 개발자의 서버에는 저장되지 않습니다. 한편 게시 작품의 식별・표시에 필요한 정보（YouTube 동영상 ID, 제목, 통계 정보, 신고 정보 등）및 게시・신고・차단 기능 이용 시 발급되는 NIARIM User ID（Google 계정과는 별도로 본 앱 내부에서 발급하는 식별자）는 개발자의 서버에서 관리합니다.\n3. 본 커뮤니티 기능 중 작품 게시, 신고 및 사용자 차단에는 Google 계정을 통한 로그인이 필요합니다.\n4. 게시할 수 있는 작품 수에는 1일당 상한이 있습니다（무료 회원・프리미엄 회원에 따라 상한이 다릅니다）. 해당 상한은 운영상의 사정에 따라 변경될 수 있습니다.\n5. 사용자는 다른 사용자가 게시한 작품 중 법령 또는 공서양속에 위반하거나 제3조 각호에 해당할 우려가 있다고 판단되는 작품에 대해, 본 앱 내 신고 기능을 통해 개발자에게 신고할 수 있습니다. 개발자는 신고 내용을 확인한 후, 합리적인 이유에 근거하여 해당 작품을 목록에서 비공개 처리하는 등 필요한 조치를 취할 수 있습니다. 허위 신고 또는 신고 기능의 남용은 금지됩니다.\n6. 사용자가 게시물을 삭제하거나 본 앱에서 Google 계정 연동을 해제한 경우, 해당 게시물에 대응하는 YouTube 동영상이 삭제될 수 있습니다. 또한 YouTube 측에서 동영상이 비공개 또는 삭제된 경우, 해당 작품은 작품 광장에서도 표시되지 않게 됩니다.\n7. 본 커뮤니티 기능의 이용에는 본 약관에 더하여 YouTube의 이용약관 및 커뮤니티 가이드라인이 적용됩니다.';

  @override
  String get licenseTermsArt13Title => '제13조（준거법・재판관할）';

  @override
  String get licenseTermsArt13Body =>
      '1. 본 약관의 해석에 있어서는 일본법을 준거법으로 합니다.\n2. 본 앱에 관하여 분쟁이 발생한 경우에는, 소송가액에 따라 개발자의 소재지를 관할하는 지방재판소 또는 간이재판소를 제1심의 전속적 합의관할 법원으로 합니다.';

  @override
  String get privacyPolicyArt1Title => '제1조（본 정책의 위치）';

  @override
  String get privacyPolicyArt1Body =>
      '본 개인정보처리방침（이하「본 방침」이라 합니다）은 본 앱「NIARIM」（이하「본 앱」이라 합니다）에서의 정보 취급에 대해 정하는 것입니다. 본 앱의 전반적인 이용 조건에 대해서는 별도로「이용약관・라이선스」화면을 확인해 주십시오.';

  @override
  String get privacyPolicyArt2Title => '제2조（본 앱이 취득하지 않는 데이터）';

  @override
  String get privacyPolicyArt2Body =>
      '본 앱은 사용자가 제작한 일러스트・애니메이션 등의 콘텐츠（프로젝트 데이터・내보낸 이미지・동영상 등을 포함합니다. 이하 동일합니다）를 개발자의 서버로 전송・수집・저장하는 기능을 제공하지 않습니다. 이들 데이터는 원칙적으로 사용자의 단말기 내에만 저장됩니다（클라우드 동기화 기능은 탑재되어 있지 않습니다）. 개발자는 이러한 콘텐츠를 스스로 저장하는 기능을 가지고 있지 않으므로, 개발자 측에서의 보관 기간이라는 개념 자체가 존재하지 않습니다. 단말기 내에 저장된 데이터는 본 앱의 삭제 기능을 통해 언제든지 삭제할 수 있으며, 앱을 삭제（언인스톨）한 경우에는 프로젝트・설정・추가한 폰트 등의 데이터도 함께 삭제됩니다（사용자가 스스로의 의사로 작품 광장 기능을 이용하여 작품을 게시하는 경우의 정보 취급에 대해서는 제7조에 따릅니다）.';

  @override
  String get privacyPolicyArt3Title => '제3조（제3자 서비스에 의한 정보 취득）';

  @override
  String get privacyPolicyArt3Body =>
      '본 앱은 다음의 제3자 서비스를 포함하고 있으며, 각 서비스 제공자가 서비스 제공에 필요한 범위 내에서 정보를 취득할 수 있습니다. 본 앱의 개발자는 이러한 정보를 독자적으로 취득・보관하는 기능을 구현하고 있지 않습니다（각 서비스가 취득한 정보의 관리는 해당 서비스 제공자의 개인정보처리방침에 따릅니다）.\n\n【광고 배포（Google AdMob）】\n무료판에서는 Google AdMob을 통해 광고를 배포하고 있습니다. 광고 배포, 효과 측정, 부정 방지 등의 목적으로 광고 식별자（Advertising ID） 기타 단말기 정보가 Google 또는 그 관계사에 의해 취득・이용될 수 있습니다. 취득・이용의 상세 내용은 Google 개인정보처리방침（https://policies.google.com/privacy）을 확인해 주십시오. 단말기 설정（Android 설정 앱의「개인정보 보호」등）에서 광고 식별자 재설정이나 맞춤형 광고 비활성화가 가능합니다. 유럽경제지역（EEA）・영국・스위스에 거주 중이신 경우, 실행 시 등에 표시되는 동의 양식에서 광고 맞춤화에 관한 동의 설정을 선택할 수 있습니다. 설정은 언제든지 본 화면 하단의「광고 동의 설정 변경」버튼에서 변경할 수 있습니다.\n\n【앱 내 결제（Google Play Billing）】\n프리미엄 기능의 구매는 Google Play의 결제 시스템을 통해 이루어집니다. 신용카드 번호 등의 결제 정보는 개발자 측이 직접 취득・보유하는 일은 없습니다. 결제에 관한 정보의 취급은 Google Play의 규정에 따릅니다.\n\n【크래시 분석・이용 현황 분석】\n본 앱은 현시점에서 크래시 분석・이용 현황 분석을 목적으로 한 SDK를 포함하고 있지 않습니다. 향후 이러한 서비스를 도입할 경우, 본 방침을 갱신하고 본 앱 내에서 고지합니다.';

  @override
  String get privacyPolicyArt4Title => '제4조（쿠키 등 추적 기술에 관하여）';

  @override
  String get privacyPolicyArt4Body =>
      '본 앱 자체는 쿠키를 사용하지 않지만, 제3조에 기재된 광고 배포 서비스（Google AdMob）가 광고 배포・효과 측정을 위해 이와 유사한 식별 기술（광고 식별자 등）을 사용할 수 있습니다.';

  @override
  String get privacyPolicyArt5Title => '제5조（아동의 개인정보에 관하여）';

  @override
  String get privacyPolicyArt5Body =>
      '본 앱은 만 13세 미만의 아동을 주된 대상으로 하여 의도적으로 정보를 수집하는 것이 아닙니다. 보호자께서는 자녀가 본 앱을 이용할 때 필요에 따라 단말기 설정에서 맞춤형 광고 비활성화 등을 검토해 주시기 바랍니다.';

  @override
  String get privacyPolicyArt6Title => '제6조（정보의 국외 이전에 관하여）';

  @override
  String get privacyPolicyArt6Body =>
      '제3조에 기재된 제3자 서비스（Google AdMob, Google Play Billing）는 Google사가 전 세계에서 운용하는 서버상에서 처리될 수 있습니다. 이러한 취급에 대해서는 각 서비스의 개인정보처리방침이 적용됩니다.';

  @override
  String get privacyPolicyArt7Title => '제7조（작품 광장：커뮤니티 게시 기능에서의 정보 취급）';

  @override
  String get privacyPolicyArt7Body =>
      '1. 본 앱은 사용자가 스스로의 의사로「작품 광장」기능（이용약관 제12조）을 이용하여 작품을 게시하는 경우에 한하여, 해당 게시에 관한 다음 정보를 개발자의 서버에서 관리합니다.\n・게시 작품을 식별・표시하기 위한 정보（YouTube 동영상 ID, 제목, 통계 정보 등）\n・게시・신고・차단 기능 이용 시 발급되는 NIARIM User ID（Google 계정과는 별도로 본 앱 내부에서 발급하는 식별자）\n・신고 기능을 이용한 경우의 신고 내용 및 신고자의 NIARIM User ID\n2. 게시된 동영상 파일 자체는 YouTube상에 저장되며, 개발자의 서버에는 저장되지 않습니다.\n3. 전 2항의 정보는 본 커뮤니티 기능의 제공（작품 목록 표시, 신고 대응, 게시 상한 관리 등）목적 범위 내에서만 이용합니다.\n4. 본 커뮤니티 기능을 이용하지 않는 경우, 본 조에 따른 정보 취급은 발생하지 않습니다（제2조의 원칙대로 개발자의 서버로 전송되지 않습니다）.';

  @override
  String get privacyPolicyArt8Title => '제8조（본 방침의 변경）';

  @override
  String get privacyPolicyArt8Body =>
      '개발자는 법령 개정, 본 앱 내용의 변경 기타 필요하다고 판단한 경우, 본 방침을 변경할 수 있습니다. 본 방침을 변경하는 경우, 변경 내용 및 효력 발생일을 본 앱 내 기타 적절한 방법으로 사전에 고지합니다.';

  @override
  String get privacyPolicyArt9Title => '제9조（문의）';

  @override
  String get privacyPolicyArt9Body =>
      '본 방침에 관한 문의는 아래 연락처로 연락해 주십시오.\n（개발자 연락처: 미설정 ― 공개 전 이메일 주소 등 연락처 정보를 기입해 주십시오）';

  @override
  String get privacyPolicyAdConsentButton => '광고 동의 설정 변경';

  @override
  String get tipsPcDexLayoutTitle => '넓은 화면에서는 PC 모드(DeX)의 본격 레이아웃으로';

  @override
  String get tipsPcDexLayoutDesc =>
      'Chromebook이나 키보드를 연결한 태블릿, DeX 등 화면이 넓은 환경에서 사용하면 도킹 패널 방식의 전문적인 레이아웃으로 자동 전환됩니다. 워크스페이스 설정에서 항상 PC 모드・항상 모바일 모드로 수동 고정할 수도 있어, 외부 디스플레이에 연결해 작업할 때도 유용합니다.';

  @override
  String get workspaceTimelineSection => '타임라인 표시';

  @override
  String get workspaceTimelineHint =>
      '동영상・음원 트랙의 한 줄 높이를 5단계로 조절할 수 있습니다. 두 손가락으로 핀치인・핀치아웃하면 타임라인의 프레임 폭도 일시적으로 확대・축소할 수 있습니다.';

  @override
  String get workspaceTimelineTrackHeightLabel => '트랙 높이';

  @override
  String get workspaceTimelinePreviewLabel => '미리보기';

  @override
  String get workspaceEndCardSection => '엔드카드';

  @override
  String get workspaceEndCardHint =>
      '엔드카드는 모든 동영상 끝에 자동으로 표시되는 앱 자체 로고입니다. 무료 회원은 조작할 수 없습니다. 프리미엄 회원 전용: 이 항목을 켜면 다음에 타임라인을 열 때부터 엔드카드가 처음부터 숨김(삭제) 상태로 시작됩니다. 프리미엄 권한이 만료되면 이 설정은 자동으로 꺼집니다.';

  @override
  String get workspaceEndCardDefaultHiddenTitle => '엔드카드를 기본적으로 숨기기（프리미엄 전용）';

  @override
  String get tipsTransparentColorTitle => '투명색은 단순한 지우개가 아니라 펜처럼 쓸 수 있다';

  @override
  String get tipsTransparentColorDesc =>
      '투명색을 선택하면 브러시, 올가미, 도형 등 원하는 도구로 그대로 지울 수 있습니다. 브러시의 필압과 매끄러움을 그대로 살려 윤곽만 둥글게 깎거나, 그라데이션 브러시로 경계를 부드럽게 투명으로 흐릴 수 있는 등 지우개 도구에는 없는 섬세한 표현이 가능합니다.';

  @override
  String get tipsQuickToolVariantTitle =>
      '빠른 도구는 도구 종류뿐 아니라 브러시, 크기 차이도 등록할 수 있다';

  @override
  String get tipsQuickToolVariantDesc =>
      '빠른 도구에는 펜, 지우개 같은 도구 전환뿐 아니라, 같은 펜이라도 브러시 종류가 다른 것, 같은 지우개라도 크기가 다른 것을 각각 따로 등록할 수 있습니다. 자주 쓰는 조합만 엄선해 배치해두면 세세한 설정 변경 때마다 패널을 다시 여는 수고가 줄어듭니다.';

  @override
  String get tipsCommonLayerLipSyncTitle =>
      '공통 레이어는 배경뿐 아니라 인물의 용량 절감에도 쓸 수 있다';

  @override
  String get tipsCommonLayerLipSyncDesc =>
      '배경뿐 아니라 인물 레이어 자체를 공통 레이어로 만드는 것도 효과적입니다. 입이나 깜빡이는 눈동자처럼 프레임마다 바뀌는 부분만 일반 레이어로 겹치고, 몸이나 머리카락처럼 움직이지 않는 부분은 공통 레이어로 해두면 입 모양 맞추기나 눈 깜빡임 애니메이션에서도 용량을 크게 줄일 수 있습니다.';

  @override
  String get tipsCommonLayerKeyframeTitle => '공통 레이어와 레이어 키프레임으로도 용량을 절감할 수 있다';

  @override
  String get tipsCommonLayerKeyframeDesc =>
      '공통 레이어는 레이어 키프레임으로 위치, 확대, 회전을 움직일 수 있습니다. 프레임마다 다시 그리는 대신, 그림 한 장을 공통 레이어로 만들어 키프레임으로 움직이기만 해도 용량을 늘리지 않고 간단한 움직임을 줄 수 있습니다.';

  @override
  String get tipsTransferCustomizationTitle => '이관 기능으로 기기를 바꿔도 늘 쓰던 그대로';

  @override
  String get tipsTransferCustomizationDesc =>
      '인계(.niatra) 기능은 브러시, 테마, 툴바 배치, 팔레트 등 커스터마이즈한 설정을 한꺼번에 다른 기기로 옮길 수 있습니다. 기기를 바꾸거나 여러 기기를 오가며 써도 매번 처음부터 다시 설정할 필요가 없습니다.';

  @override
  String get tipsBlendModeUsageTitle => '블렌드 모드는 목적에 따라 구분해 쓰면 효과적';

  @override
  String get tipsBlendModeUsageDesc =>
      '그림자를 넣고 싶을 때는 곱하기, 빛이나 광채를 더하고 싶을 때는 스크린이나 더하기, 음영에 질감을 내고 싶을 때는 오버레이나 소프트 라이트가 적합합니다. 같은 색이라도 블렌드 모드만 바꾸면 인상이 크게 달라지므로, 우선 몇 가지 후보를 바꿔가며 비교해 보는 것을 추천합니다.';

  @override
  String get timelineSaveFailedDialogTitle => '저장 실패';

  @override
  String get timelineSaveFailedDialogBody => '저장에 실패했습니다. 다시 시도해 주세요.';

  @override
  String get licenseSectionIcons => '사용 아이콘 안내';

  @override
  String get layerPanelMergeAllVisibleTooltip => '표시 중인 모든 레이어 결합';

  @override
  String get canvasBrushSliderToggleLabel => '상세';

  @override
  String get helpMeshTransformTitle => '자유 변형・메시 변형';

  @override
  String get helpMeshTransformDesc =>
      '캔버스 오른쪽 위의 편집/설정 메뉴에서 열 수 있는, 레이어 전체를 대상으로 하는 변형 도구입니다. 선택 범위 변형과 달리 선택 범위가 필요 없으며, 모서리나 격자점을 손가락으로 개별적으로 드래그해 자유로운 형태로 변형할 수 있습니다. 컨트롤 패널의 분할 수 슬라이더로 메시를 최대 10×10까지 세밀하게 나눌 수 있고, 두 손가락으로 각각 다른 점을 동시에 잡으면 회전・확대축소 같은 조작도 직관적으로 할 수 있습니다.';

  @override
  String get layerPanelBrightnessToAlphaLabel => '명도로 투명화';

  @override
  String get layerPanelBrightnessToAlphaHint =>
      '밝은 부분일수록 투명하게 만듭니다. 색은 그대로 유지된 채 반투명해집니다（흰 배경이 사라지는 것이 아니라 그림 전체가 옅어지는 이미지）.';

  @override
  String get layerPanelBrightnessToAlphaColorButton => '컬러';

  @override
  String get layerPanelBrightnessToAlphaGrayButton => '그레이';

  @override
  String get tipsRoughLayerRescueTitle => '러프 레이어에 선화를 그려버렸다면 「명도로 투명화」로 구출';

  @override
  String get tipsRoughLayerRescueDesc =>
      '러프 스케치 레이어 위에 실수로 선화를 그려버려도, 아무것도 지우지 않고 선화만 꺼낼 수 있습니다. ①새 레이어를 추가하고 블렌드 모드를 「나누기」로 설정. ②스포이드로 러프의 색을 추출해 그 나누기 레이어 전체를 채운다（러프가 옅어집니다）. ③나누기 레이어를 복제하면 러프가 완전히 사라집니다. ④레이어 패널의 「표시 중인 모든 레이어 결합」으로 한 장으로 합친다. ⑤합친 레이어의 세 점 메뉴에서 「명도로 투명화（그레이）」를 선택하면 흰 부분이 투명해지고 선화만 남습니다.';

  @override
  String get filterNameMonochrome => '단색화 필터';

  @override
  String get timelineEffectTypeMonochrome => '단색화 필터';

  @override
  String get filterNameColorAdjust => '색조 조정';

  @override
  String get filterColorAdjustSaturationLabel => '채도';

  @override
  String get filterColorAdjustBrightnessLabel => '명도';

  @override
  String get filterColorAdjustContrastLabel => '대비';

  @override
  String get canvasColorAdjustTitle => '색조 조정';

  @override
  String get canvasColorAdjustAddToDrawFilter => '그리기 필터에 추가';

  @override
  String get canvasColorAdjustAddToEffectFilter => '연출 필터에 추가';

  @override
  String get canvasColorAdjustMenuTitle => '색조 조정';

  @override
  String get canvasEditMenuReferenceWindow => '참고 창';

  @override
  String get canvasEditMenuReferenceWindowSubtitle => '참고 이미지를 항상 띄워서 표시';

  @override
  String get referenceWindowTitle => '참고 창';

  @override
  String get referenceWindowSelectImageButton => '이미지 선택';

  @override
  String get workspaceDockPanelSection => 'PC에서 기본으로 열릴 패널';

  @override
  String get workspaceDockPanelHint =>
      'PC/DeX 모드에서는 체크한 여러 패널을 동시에 고정 표시할 수 있습니다(모바일은 오작동 방지를 위해 항상 모든 패널이 숨겨진 상태로 시작).';

  @override
  String get workspaceDockPanelBrush => '브러쉬';

  @override
  String get workspaceDockPanelColorPicker => '컬러 피커';

  @override
  String get workspaceDockPanelLayer => '레이어';

  @override
  String get workspaceDockPanelTone => '톤';

  @override
  String get workspaceDockPanelStamp => '스탬프';

  @override
  String get workspaceDockPanelPenSubTool => '펜 보조 도구';

  @override
  String get workspaceDockPanelOnionSkin => '양파 스타일';

  @override
  String get workspaceDockPanelRuler => '자';

  @override
  String get workspaceDockPanelFilter => '필터';

  @override
  String get workspaceDockPanelQuickTool => '빠른교체 도구';

  @override
  String get workspaceDockPanelColorAdjust => '색상 조정';

  @override
  String get workspaceDockPanelCanvasPreview => '캔버스 미리보기';

  @override
  String get workspacePcLayoutButton => 'PC 레이아웃 설정';

  @override
  String get pcWorkspaceLayoutScreenTitle => 'PC 레이아웃 설정';

  @override
  String get pcWorkspaceLayoutIntroHint =>
      'PC 모드(가로 화면 + 마우스·펜타블릿 연결)로 캔버스 화면을 열었을 때의 패널 순서와 너비를 조정할 수 있습니다.';

  @override
  String get pcWorkspaceLayoutToolOrderSection => '도구 패널 순서';

  @override
  String get pcWorkspaceLayoutToolOrderHint =>
      '브러시·톤·스탬프 등을 동시에 열었을 때 쌓이는 순서입니다.';

  @override
  String get pcWorkspaceLayoutRightOrderSection => '레이어 등 패널 순서';

  @override
  String get pcWorkspaceLayoutRightOrderHint =>
      '색상 선택기·레이어·캔버스 미리보기의 쌓이는 순서입니다.';

  @override
  String get pcWorkspaceLayoutWidthSection => '패널 너비';

  @override
  String get pcWorkspaceLayoutToolWidthLabel => '도구 패널 쪽 너비';

  @override
  String get pcWorkspaceLayoutRightWidthLabel => '레이어 패널 쪽 너비';

  @override
  String get pcWorkspaceLayoutResetWidthButton => '너비를 기본값으로 되돌리기';

  @override
  String get pcWorkspaceLayoutResetOrderButton => '순서를 기본값으로 되돌리기';

  @override
  String get canvasPreviewNavigatorTitle => '캔버스 미리보기';

  @override
  String get canvasEditMenuPreviewNavigator => '캔버스 미리보기';

  @override
  String get canvasEditMenuPreviewNavigatorSubtitle => '전체를 축소 표시(내비게이터)';

  @override
  String get filterCustomMenuDuplicate => '복제';

  @override
  String get filterCustomMenuFavoriteBlockTitle => '삭제할 수 없습니다';

  @override
  String get filterCustomMenuFavoriteBlockBody =>
      '즐겨찾기로 등록된 필터는 삭제할 수 없습니다. 먼저 즐겨찾기를 해제한 후 삭제해 주세요.';

  @override
  String get filterNameThreshold => '이진화 필터';

  @override
  String get filterMonochromeStrength => '단색화 강도';

  @override
  String get filterMonochromeColorLabel => '단색화 색상';

  @override
  String get filterThresholdLabel => '임계값';

  @override
  String get filterNameFisheye => '어안 렌즈 필터';

  @override
  String get filterFisheyeStrength => '왜곡 강도';

  @override
  String get filterNameChromaticAberration => '색수차 필터';

  @override
  String get filterChromaticAberrationStrength => '어긋남 강도';

  @override
  String get filterNameLensDistortion => '안경 렌즈 왜곡 필터';

  @override
  String get filterLensDistortionStrength => '렌즈 도수（음수＝오목렌즈, 양수＝볼록렌즈）';

  @override
  String get filterLensDistortionOffsetX => '중심 위치 미세 조정（좌우）';

  @override
  String get filterNamePixelate => '도트 그림 필터';

  @override
  String get filterNameAuroraHologram => '오로라 홀로그램';

  @override
  String get filterAuroraHologramStrength => '강도';

  @override
  String get filterAuroraHologramBrightness => '명도';

  @override
  String get filterAuroraHologramSaturation => '채도';

  @override
  String get filterAuroraHologramPresetAurora => '오로라';

  @override
  String get filterAuroraHologramPresetSoapBubble => '비눗방울';

  @override
  String get filterAuroraHologramPresetCyberNeon => '사이버 네온';

  @override
  String get filterAuroraHologramPresetPastelDream => '파스텔 드림';

  @override
  String get filterAuroraHologramPresetSunsetGold => '선셋 골드';

  @override
  String get filterAuroraHologramPresetSilverFoil => '실버 포일';

  @override
  String get filterNameBackgroundBlend => '배경 어우러짐';

  @override
  String get filterBackgroundBlendColorLabel => '어우러짐 색상';

  @override
  String get filterBackgroundBlendAutoLabel => '자동 감지 중(탭하여 수동 지정)';

  @override
  String get filterBackgroundBlendAutoReset => '자동으로 되돌리기';

  @override
  String get filterBackgroundBlendDirection => '그림자·빛(연동)의 방향';

  @override
  String get filterBackgroundBlendLength => '그림자·빛(연동)의 길이';

  @override
  String get filterBackgroundBlendBlur => '흐림 정도';

  @override
  String get filterPixelateBlockSize => '블록 크기';

  @override
  String get filterLensDistortionOffsetY => '중심 위치 미세 조정（상하）';

  @override
  String get filterLensDistortionNoMaskHint =>
      '선택 레이어에 칠한 범위에만 적용됩니다. 먼저 레이어 목록에서「선택 레이어」를 추가하고, 렌즈로 만들고 싶은 범위（안경 렌즈 부분 등）를 칠해 주세요.';

  @override
  String get tipsStockingDenierTitle => '스타킹・타이츠는 데니어 수에 따라 그물눈의 세밀함이 달라집니다';

  @override
  String get tipsStockingDenierDesc =>
      '새로 추가된 스타킹・타이츠 톤은 데니어 수가 낮을수록（천이 얇을수록）격자 간격을 좁게 설정했으며, 가장 낮은 10데니어는 표시・출력 해상도에 따라 무아레가 생길 정도로 일부러 세밀하게 만들었습니다. 데니어 수가 높은 타이츠는 간격이 넓어 더 불투명한 느낌을 주므로, 캐릭터의 다리에 맞게 구분해서 사용하세요.';

  @override
  String get tipsFisheyeChromaticTitle => '어안 렌즈・색수차 필터로 렌즈 특유의 왜곡과 번짐을 연출';

  @override
  String get tipsFisheyeChromaticDesc =>
      '어안 렌즈 필터는 화면 중심을 부풀리고 주변을 압축하여 광각・어안 렌즈로 촬영한 듯한 만곡을 재현합니다. 색수차 필터는 RGB 채널을 조금씩 어긋나게 하여 저가 렌즈로 촬영했을 때와 같은 색번짐을 재현합니다. 두 필터 모두 그리기 필터（레이어에 직접 적용）와 연출 필터（타임라인에서 구간을 지정하여 적용） 양쪽에서 사용할 수 있습니다.';

  @override
  String get tipsLensDistortionTitle => '선택 레이어＋안경 렌즈 왜곡 필터로 도수 렌즈의 왜곡을 재현';

  @override
  String get tipsLensDistortionDesc =>
      '레이어 목록에「선택 레이어」를 추가하고, 안경의 렌즈 부분을 일반 그리기 도구로 칠하면 그 범위에만 안경 렌즈 왜곡 필터의 국소적인 왜곡을 적용할 수 있습니다. 도수 슬라이더는 음수 값에서는 오목렌즈（근시）풍으로 축소되고, 양수 값에서는 볼록렌즈（원시）풍으로 확대되며, 중심 위치도 미세 조정할 수 있습니다. 양쪽 렌즈를 동시에 칠해서 한꺼번에 적용하는 것도 가능합니다. 선택 레이어 자체는 내보내기・최종 그림에는 나타나지 않습니다. 안경 외에도 카메라 렌즈 너머로 풍경을 보는 듯한 왜곡을 재현하고 싶을 때도 사용할 수 있습니다. 배경 등 넓은 범위를 선택 레이어로 칠하고 약한 도수를 적용하는 것을 추천합니다.';

  @override
  String get tipsLineArtExtractionTitle => '색조 보정・이진화・명도로 투과를 조합해 선화를 추출하기';

  @override
  String get tipsLineArtExtractionDesc =>
      '색조 보정으로 대비를 높여 선을 도드라지게 한 뒤, 이진화 필터로 이미지를 흑백 2색으로 나누면 선과 그 외 부분이 뚜렷하게 분리됩니다. 이진화의 임계값은 슬라이더로 자유롭게 조정할 수 있어 선의 굵기・흐릿한 정도를 취향에 맞게 조절할 수 있습니다. 마지막으로 레이어의 점 3개 메뉴에 있는 「명도로 투과（그레이）」를 사용하면 흰 부분（선 이외）만 투과되어 선화만 추출할 수 있습니다. 사진이나 밑그림에서 선화만 뽑아내고 싶을 때 유용합니다.';

  @override
  String get tipsLineColorUsageTitle => '선화색은 용도에 따라 구분해 쓰면 완성도가 달라집니다';

  @override
  String get tipsLineColorUsageDesc =>
      '파츠의 윤곽선은 컬러 트레이스·선화 어울림을 쓰면 그림에서 뜨지 않으면서 경계만 분명하게 전달되는 선화가 됩니다. 그림자나 하이라이트는 채움색과 같은 지정색을 쓰면 선화 자체가 눈에 띄지 않게 되고, 일부러 다른 지정색을 쓰면 그 애니메이션만의 세계관·통일감을 연출할 수 있습니다.';

  @override
  String get tipsBlushAutofillTitle => '봼기조차 자동채색으로 부드럽게 올릴 수 있습니다';

  @override
  String get tipsBlushAutofillDesc =>
      '선화색을 지정색으로 하여 투명색을 선택하고, 채움색을 방사형: 중앙→외부로 하여 봼 봉색과 투명색 두 가지를 지정하면, 피부 위에 봼기만 부드럽게 올릴 수 있습니다. 봉색의 불투명도와 색 전환 위치를 조절하면 경계가 더 자연스럽게 어울립니다.';

  @override
  String get autofillPartResetTraceButton => '기본값으로 되돌리기';

  @override
  String get premiumScreenTitle => 'Premium';

  @override
  String get premiumComparisonPremium => 'Premium';

  @override
  String premiumRegisteredDateLabel(String date) {
    return '등록일: $date';
  }

  @override
  String premiumNextRenewalDateLabel(String date) {
    return '다음 갱신일: $date';
  }

  @override
  String get workspaceApplyCurrentButton => '설정한 워크스페이스 적용';

  @override
  String get workspaceAppliedSnackbar => '워크스페이스 설정을 반영했습니다.';

  @override
  String get workspaceSaveAsButton => '워크스페이스 이름을 지정해 저장・덮어쓰기';

  @override
  String get workspaceShareButton => '워크스페이스 공유';

  @override
  String get workspaceShareSelectTitle => '공유할 워크스페이스 선택';

  @override
  String workspaceShareFailedSnackbar(String error) {
    return '공유에 실패했습니다: $error';
  }

  @override
  String get workspaceImportFromFileButton => '외부 파일 불러오기';

  @override
  String workspaceImportFailedSnackbar(String error) {
    return '불러오기에 실패했습니다: $error';
  }

  @override
  String get workspaceNameRequiredError => '이름을 입력해 주세요.';

  @override
  String get workspaceNoSavedPresets => '저장된 워크스페이스가 없습니다.';

  @override
  String get workspaceOverwriteSelectTitle => '덮어쓸 워크스페이스 선택';

  @override
  String get workspaceOverwriteConfirmTitle => '덮어쓰기 확인';

  @override
  String workspaceOverwriteConfirmBody(String name) {
    return '「$name」을(를) 현재 설정으로 덮어씁니다. 기존 내용은 삭제됩니다. 계속하시겠습니까？';
  }

  @override
  String get workspaceOverwriteButton => '덮어쓰기';

  @override
  String get splashCommunityButtonTitle => 'NIARIM 갤러리';

  @override
  String get splashCommunityButtonSubtitle => '모두의 작품 보기';

  @override
  String get splashCreateButton => '애니메이션 만들기';

  @override
  String get communityScreenTitle => '작품 광장';

  @override
  String get communityTabNew => '신착';

  @override
  String get communityTabRanking => '랭킹';

  @override
  String get communityTabFavoriteAuthors => '팔로잉';

  @override
  String get communitySearchHint => '작품 제목・투고자 이름으로 검색';

  @override
  String get communityEmptyState => '표시할 작품이 없습니다';

  @override
  String communitySearchNoResults(String query) {
    return '「$query」에 해당하는 작품을 찾을 수 없습니다';
  }

  @override
  String get communityTagSearchHint => '태그명으로 검색';

  @override
  String get communityTagSearchModeOnTooltip =>
      '태그 검색: 켜짐 (탭하면 제목・투고자명 검색으로 돌아감)';

  @override
  String get communityTagSearchModeOffTooltip => '태그 검색으로 전환';

  @override
  String get communityAddTagButton => '태그 추가';

  @override
  String get communityAddTagDialogTitle => '태그 추가';

  @override
  String get communityAddTagDialogHint => '태그명을 입력하세요';

  @override
  String get communityTagLockTooltip => '태그 잠금(투고자 전용)';

  @override
  String get communityTagUnlockTooltip => '태그 잠금 해제(투고자 전용)';

  @override
  String get communityRemoveTagTooltip => '태그 삭제';

  @override
  String get communityPostButton => '게시하기';

  @override
  String get communityPostComingSoonTitle => '게시 기능은 준비 중입니다';

  @override
  String get communityPostComingSoonBody =>
      '동영상 게시 기능은 아직 개발 중입니다. 다음 업데이트를 기대해 주세요.';

  @override
  String get communityPostInfoTitle => '게시는 YouTube를 통해 이루어집니다';

  @override
  String get communityPostInfoBody =>
      '작품 광장에 게시하면 YouTube를 통해 작품이 공개됩니다. NIARIM은 작품 본체（동영상 파일）를 개발자의 서버로 전송・수집・저장하는 기능을 가지고 있지 않습니다. 게시할 때는 YouTube 화면에서 직접 동영상을 업로드하시게 됩니다.\n\nYouTube 측 공개 설정을 「일부 공개」로 설정하면, YouTube의 일반 공개 목록에는 표시되지 않고 작품 광장 내에만 게시된 상태로 만들 수 있습니다.\n\n（동영상 게시 기능은 아직 개발 중입니다. 다음 업데이트를 기대해 주세요.）';

  @override
  String get communityRankingPeriodAllTime => '누적';

  @override
  String get communityRankingPeriodYearly => '연간';

  @override
  String get communityRankingPeriodMonthly => '월간';

  @override
  String get communityRankingPeriodWeekly => '주간';

  @override
  String get communityRankingPeriodDaily => '일간';

  @override
  String get communityRankingSortViews => '조회수';

  @override
  String get communityRankingSortBookmarks => '북마크 수';

  @override
  String get communityRankingSortAscendingTooltip => '오름차순（적은 순）';

  @override
  String get communityRankingSortDescendingTooltip => '내림차순（많은 순）';

  @override
  String communityWorkDetailPostedLabel(String date) {
    return '$date에 게시';
  }

  @override
  String get communityWorkDetailViewOnYoutube => 'YouTube에서 보기';

  @override
  String get communityWorkDetailViewOnYoutubeComingSoonSnackbar =>
      'YouTube 연동 기능은 준비 중입니다';

  @override
  String get communityWorkDetailBookmarkAdd => '북마크';

  @override
  String get communityWorkDetailBookmarkRemove => '북마크됨';

  @override
  String get communityWorkDetailReportButton => '신고';

  @override
  String get communityWorkDetailBlockButton => '차단';

  @override
  String get communityVisibilityCardTitle => '작품 광장에서의 공개 상태';

  @override
  String get communityVisibilityPublishedDesc =>
      '공개 중: 신착・랭킹・이 투고자의 작품 목록에 표시됩니다.';

  @override
  String get communityVisibilityHiddenDesc =>
      '비공개 중: 신착・랭킹・이 투고자의 작품 목록에서 숨겨집니다（YouTube 측 공개 설정과는 독립된 설정입니다）.';

  @override
  String get communityVisibilityHiddenNotice =>
      '투고자가 이 작품을 작품 광장에서 비공개로 설정했습니다.';

  @override
  String get communityVisibilityHiddenBadge => '비공개';

  @override
  String get communityWorkDetailTitle => '작품 상세';

  @override
  String get communityWorkNotFoundMessage => '작품을 찾을 수 없습니다';

  @override
  String get communityFloatingPreviewDetailButton => '상세보기';

  @override
  String get communityFloatingPreviewPlayTooltip => '재생';

  @override
  String get communityFloatingPreviewPauseTooltip => '일시정지';

  @override
  String get communityReportDialogTitle => '작품 신고';

  @override
  String get communityReportDialogBody => '신고 사유를 선택해 주세요.';

  @override
  String get communityReportReasonInappropriate => '부적절한 내용';

  @override
  String get communityReportReasonCopyright => '저작권 침해 의심';

  @override
  String get communityReportReasonSpam => '스팸・반복 게시';

  @override
  String get communityReportReasonOther => '기타';

  @override
  String get communityReportSubmitButton => '신고하기';

  @override
  String get communityReportDetailLabel => '상세 내용';

  @override
  String get communityReportDetailHint => '구체적으로 어떤 점이 문제인지 입력해 주세요';

  @override
  String get communityReportDetailRequiredError => '상세 내용을 입력해 주세요';

  @override
  String get communityReportComingSoonSnackbar =>
      '신고 기능은 준비 중입니다. 실제로 전송되지 않습니다.';

  @override
  String communityBlockConfirmTitle(String name) {
    return '「$name」님을 차단할까요?';
  }

  @override
  String get communityBlockConfirmBody => '차단하면 이 작성자의 작품이 목록에 표시되지 않습니다.';

  @override
  String get communityBlockComingSoonSnackbar =>
      '차단 기능은 준비 중입니다. 실제로 반영되지 않습니다.';

  @override
  String communityAuthorWorksCount(int count) {
    return '작품 $count개';
  }

  @override
  String communityAuthorFollowerCount(int count) {
    return '팔로워 $count명';
  }

  @override
  String get communityFollowersPublicToggleTitle => '팔로잉/팔로워 목록 공개하기';

  @override
  String get communityFollowersPublicToggleDesc =>
      '켜면 다른 사용자가 이 페이지에서 회원님의 팔로잉 및 팔로워 목록을 볼 수 있습니다. 기본값은 비공개입니다.';

  @override
  String get communityFollowersListTitle => '팔로워';

  @override
  String get communityFollowersListEmpty => '팔로워가 없습니다';

  @override
  String communityFollowersListHiddenNote(int count) {
    return '$count명이 더 있지만, 본인 설정에 따라 표시되지 않습니다';
  }

  @override
  String communityAuthorFollowingCount(int count) {
    return '팔로잉 $count명';
  }

  @override
  String get communityFollowingListTitle => '팔로잉';

  @override
  String get communityFollowingListEmpty => '팔로우한 사람이 없습니다';

  @override
  String get communityFollowNotificationsTooltip => '알림';

  @override
  String get communityFollowNotificationsTitle => '팔로우 알림';

  @override
  String get communityFollowNotificationsEmpty => '알림이 없습니다';

  @override
  String communityFollowNotificationBody(String name) {
    return '$name님이 회원님을 팔로우했습니다';
  }

  @override
  String get communityNoWorksMessage => '작품이 없습니다';

  @override
  String get communityFavoriteAuthorFollow => '팔로우';

  @override
  String get communityFavoriteAuthorFollowing => '팔로잉';

  @override
  String get communityFavoriteAuthorsEmptyTitle => '팔로우한 작가가 없습니다';

  @override
  String get communityFavoriteAuthorsEmptyBody =>
      '마음에 드는 작가의 페이지에서 「팔로우」하면 이곳에 그 사람의 신작이 표시됩니다.';

  @override
  String get communityRepostButton => '리포스트';

  @override
  String get communityRepostedButton => '리포스트함';

  @override
  String communityRepostedByBadge(String name) {
    return '$name님이 리포스트함';
  }

  @override
  String get communityAuthorTabWorks => '작품';

  @override
  String get communityAuthorTabBookmarks => '북마크';

  @override
  String get communityBookmarksPublicToggleTitle => '북마크 목록 공개하기';

  @override
  String get communityBookmarksPublicToggleDesc =>
      '켜면 다른 사용자가 이 페이지에서 회원님의 북마크 목록을 볼 수 있습니다. 기본값은 비공개입니다.';

  @override
  String get communityBookmarksPrivateNotice => '이 사용자는 북마크 목록을 비공개로 설정했습니다.';

  @override
  String get communityBookmarksEmptyMessage => '북마크한 작품이 없습니다';

  @override
  String get communityShortsBadge => '세로 화면';

  @override
  String get communityVideoTypeFilterTooltip => '동영상 종류로 좁혀보기';

  @override
  String get communityVideoTypeFilterAll => '종합';

  @override
  String get communityVideoTypeFilterShortOnly => '세로 화면만';

  @override
  String get communityVideoTypeFilterLongOnly => '가로 화면만';

  @override
  String get communityShortsModeTooltip => '세로 화면 모드로 보기';

  @override
  String get communityShortsModeEmptySnackbar => '세로 화면 동영상이 없습니다';

  @override
  String get communityShortsModeExitTooltip => '세로 화면 모드 종료';

  @override
  String get pixelColorModeLabel => '배색 방식';

  @override
  String get pixelColorModeNone => '색상 제한 없음';

  @override
  String get pixelColorModePalette => '팔레트에서 선택';

  @override
  String get pixelColorModeExplicit => '색상 지정';

  @override
  String get pixelColorModeCount => '색상 수 지정';

  @override
  String pixelColorLevelsLabel(int count) {
    return '색상 수: $count';
  }

  @override
  String get pixelColorChipDeleteTooltip => '이 색상 삭제';

  @override
  String get pixelColorChipAddButton => '색상 추가';

  @override
  String get pixelArtPaletteNameRequiredError => '팔레트 이름을 입력하세요';

  @override
  String get pixelArtPaletteEditTitle => '팔레트 편집';

  @override
  String get pixelArtPaletteAddTitle => '팔레트 추가';

  @override
  String get pixelArtPaletteNameLabel => '팔레트 이름';

  @override
  String get pixelArtPalettePickerTitle => '팔레트 선택';

  @override
  String get pixelArtPalettePickerEmpty =>
      '저장된 팔레트가 없습니다. \\\"추가\\\"를 눌러 만들어 보세요.';

  @override
  String get pixelArtPalettePickerApplyButton => '적용';

  @override
  String get storageScreenTitle => '용량 확보';

  @override
  String get storageDeviceChartTitle => '기기 저장공간';

  @override
  String get storageBreakdownChartTitle => 'NIARIM 세부 내역';

  @override
  String get storageActionsTitle => '정리하기';

  @override
  String get storageCategoryNiarimTotal => 'NIARIM';

  @override
  String get storageCategoryOtherApps => '기타';

  @override
  String get storageCategoryFree => '여유 공간';

  @override
  String get storageCategoryMaterials => '소재';

  @override
  String get storageCategoryProjectData => '프로젝트 데이터';

  @override
  String get storageCategoryExports => '내보낸 파일';

  @override
  String get storageCategoryCustomAssets => '커스텀 브러시/톤/스탬프/폰트';

  @override
  String get storageCategoryCache => '캐시';

  @override
  String get storageCategoryTrash => '휴지통';

  @override
  String get storageClearCacheButton => '캐시 삭제';

  @override
  String get storageRemoveUnusedMaterialsButton => '미사용 소재 일괄 삭제(모든 프로젝트)';

  @override
  String get storageEmptyTrashButton => '휴지통 비우기';

  @override
  String get storageOrganizeProjectsButton => '프로젝트 정리하기';

  @override
  String get storageEraseAllButton => '모든 데이터 삭제(초기화)';

  @override
  String storageClearCacheDoneSnackbar(String size) {
    return '캐시 $size를 삭제했습니다';
  }

  @override
  String get storageEraseAllConfirmTitle => '모든 데이터를 삭제할까요?';

  @override
  String get storageEraseAllConfirmBody =>
      '프로젝트, 소재, 내보낸 파일, 커스텀 브러시/톤/스탬프/폰트, 설정 등 NIARIM의 모든 데이터를 영구적으로 삭제합니다. 이 작업은 되돌릴 수 없습니다. 삭제 후 앱을 다시 시작해 주세요.';

  @override
  String get storageEraseAllDoneSnackbar => '모든 데이터를 삭제했습니다. 앱을 다시 시작해 주세요.';

  @override
  String get homeDrawerStorage => '용량 확보';

  @override
  String get helpStorageTitle => '용량 확보';

  @override
  String get helpStorageDesc =>
      '기기에서 NIARIM이 사용하는 용량과, NIARIM 내부(프로젝트, 소재, 내보낸 파일, 커스텀 브러시/톤/스탬프/폰트, 캐시, 휴지통)의 세부 내역을 원 그래프로 확인할 수 있습니다. 캐시 삭제, 모든 프로젝트의 미사용 소재 일괄 삭제, 휴지통 비우기, 프로젝트 정리, 모든 데이터 삭제(초기화)를 수행할 수 있습니다.';

  @override
  String get colorPickerImportPaletteTooltip => '팔레트 가져오기';

  @override
  String get colorPickerSharePaletteTooltip => '공유';

  @override
  String get colorPickerShareViaFile => '파일로 공유';

  @override
  String colorPickerShareFailedSnackbar(String error) {
    return '공유에 실패했습니다: $error';
  }

  @override
  String get colorPickerShareViaQr => 'QR 코드로 공유';

  @override
  String get qrShareTooLargeHint =>
      '색상이 너무 많아 QR 코드로 공유할 수 없습니다(파일 공유를 이용해 주세요)';

  @override
  String get colorPickerImportViaFile => '파일에서 선택';

  @override
  String colorPickerImportFailedSnackbar(String error) {
    return '가져오기에 실패했습니다: $error';
  }

  @override
  String get colorPickerImportViaQr => 'QR 코드 텍스트 붙여넣기';

  @override
  String get qrImportFailedError => '가져오기에 실패했습니다. 텍스트가 올바른지 확인해 주세요.';

  @override
  String get qrImportHint =>
      '상대방 기기에 표시된 QR 코드를 기본 카메라 앱 등으로 스캔한 후, 복사한 텍스트를 여기에 붙여넣어 주세요.';

  @override
  String get qrImportFieldHint => '스캔한 텍스트를 붙여넣기';

  @override
  String get qrImportPasteButton => '클립보드에서 붙여넣기';

  @override
  String get qrImportSubmitButton => '가져오기';

  @override
  String get qrShareHint =>
      '기본 카메라 앱 등으로 이 QR 코드를 스캔하면 텍스트를 복사할 수 있습니다. 상대방 기기에서 \"가져오기\"로 복사한 텍스트를 붙여넣어 주세요.';

  @override
  String get qrShareCopiedSnackbar => '텍스트를 복사했습니다';

  @override
  String get qrShareCopyButton => '텍스트 복사';

  @override
  String get toolbarItemBlur => '가우시안 흐리기';

  @override
  String get toolbarItemMosaic => '모자이크';

  @override
  String get toolbarFingerSubtoolWarp => '우그리기';

  @override
  String get brushSettingsEdgeJitterTitle => '가장자리 번짐';

  @override
  String get brushSettingsEdgeJitterSubtitle => '가장자리를 약간 거칠게 하여 잉크 번짐을 재현';

  @override
  String get brushSettingsEdgeJitterStrengthLabel => '번짐 강도';
}
