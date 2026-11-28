// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get brushFoldTriggerDepthRatio =>
      'Profondeur de courbe pour amorcer le pli (× largeur du trait)';

  @override
  String get homeTabProjects => 'Projets';

  @override
  String get homeTabShared => 'Partagés';

  @override
  String get homeTabTrash => 'Corbeille';

  @override
  String get homeTabWorks => 'Œuvres';

  @override
  String get homeTabBookmarked => 'Favoris';

  @override
  String get homeBookmarkedEmptyTitle => 'Aucune œuvre en favoris à afficher';

  @override
  String get homeBookmarkedEmptyBody =>
      'Ajoutez aux favoris les œuvres publiques qui vous plaisent sur la Place des œuvres pour les retrouver ici.';

  @override
  String get homeBookmarkedHiddenTitle => 'Vos favoris sont conservés';

  @override
  String get homeBookmarkedHiddenBody =>
      'Les filtres d’affichage ou le statut public des œuvres peuvent les masquer. Vérifiez les filtres sur la Place des œuvres.';

  @override
  String get homeBookmarkedLoading => 'Chargement de vos œuvres en favoris…';

  @override
  String get homeBookmarkedLoadFailed =>
      'Impossible de charger vos œuvres en favoris';

  @override
  String get homeBookmarkedLoadPrompt => 'Charger vos œuvres en favoris';

  @override
  String get homeBookmarkedSignInBody =>
      'Connectez votre compte Google sur la Place des œuvres pour charger vos œuvres en favoris.';

  @override
  String get homeSearchHint => 'Rechercher par nom de projet';

  @override
  String get homeSearchHintWorks => 'Rechercher par nom d’œuvre';

  @override
  String get homeSearchHintShared => 'Rechercher par nom de fichier partagé';

  @override
  String get homeSearchHintTrash => 'Rechercher dans la corbeille par nom';

  @override
  String get homeBackToSplashTooltip => 'Retour à l’écran de lancement';

  @override
  String get homeFavoritesOnly => 'Favoris';

  @override
  String get homeAddSheetNewProject => 'Nouveau projet';

  @override
  String get homeAddSheetNewFolder => 'Nouveau dossier';

  @override
  String get homeSelectionAllSelect => 'Tout sélectionner';

  @override
  String get homeSelectionAllDeselect => 'Tout désélectionner';

  @override
  String homeSelectionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sélectionnés',
      one: '$count sélectionné',
    );
    return '$_temp0';
  }

  @override
  String get homeMoveToTrash => 'Mettre à la corbeille';

  @override
  String homeMoveToTrashConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mettre $count éléments à la corbeille ?',
      one: 'Mettre $count élément à la corbeille ?',
    );
    return '$_temp0';
  }

  @override
  String get commonMove => 'Déplacer';

  @override
  String get homeShareFileDialogTitle => 'Fichier partagé';

  @override
  String homeSharedFileTooLarge(String size) {
    return 'Le fichier partagé est trop volumineux pour être ouvert. Cet appareil peut ouvrir des fichiers jusqu’à $size.';
  }

  @override
  String homeSharedFileNoSpace(String size) {
    return 'L’espace libre de l’appareil est insuffisant pour ouvrir le fichier partagé. Libérez au moins $size de plus, puis rouvrez-le.';
  }

  @override
  String get homeSharedFileUnreadable =>
      'Impossible d’ouvrir le fichier partagé. Enregistrez-le à nouveau, puis réessayez.';

  @override
  String get homeShareFileDialogContent =>
      'Dupliquer ce fichier partagé et l’enregistrer comme projet normal ?';

  @override
  String homeMissingFontsSnackbar(String names) {
    return 'Polices manquantes : $names';
  }

  @override
  String get homeSharedImportedSnackbar => 'Ajouté à l’onglet Projets';

  @override
  String homeSharedImportFailedSnackbar(String error) {
    return 'Échec du chargement du fichier partagé : $error';
  }

  @override
  String get homeViewModeLarge => 'Grand';

  @override
  String get homeViewModeMedium => 'Moyen';

  @override
  String get homeViewModeSmall => 'Petit';

  @override
  String get homeViewModeDetail => 'Détails';

  @override
  String get homeViewLayoutHeading => 'Disposition';

  @override
  String get homeViewLayoutTiles => 'Vignettes';

  @override
  String get homeViewSizeHeading => 'Taille';

  @override
  String get homeSortFieldName => 'Nom';

  @override
  String get homeSortFieldUpdated => 'Modifié';

  @override
  String get homeSortDirectionAscTooltip =>
      'Croissant (appuyez pour passer en décroissant)';

  @override
  String get homeSortDirectionDescTooltip =>
      'Décroissant (appuyez pour passer en croissant)';

  @override
  String get homeSharedEmpty => 'Aucun projet partagé';

  @override
  String homeProjectMeta(int fps, int duration) {
    return '$fps i/s · $duration s';
  }

  @override
  String get homeTrashLoadingFiles =>
      'Chargement des œuvres exportées et des fichiers partagés que vous avez créés…';

  @override
  String get homeTrashEmpty => 'La corbeille est vide';

  @override
  String homeTrashNoMatchTitle(String query) {
    return 'Rien dans la corbeille ne correspond à « $query »';
  }

  @override
  String get homeTrashNoKindTitle =>
      'La corbeille ne contient rien des types sélectionnés';

  @override
  String homeTrashNoKindMatchTitle(String query) {
    return 'Rien parmi les types sélectionnés ne correspond à « $query »';
  }

  @override
  String homeTrashDeletedOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Supprimé le $dateString';
  }

  @override
  String get homePermanentDelete => 'Supprimer';

  @override
  String get homePermanentDeleteConfirmTitle => 'Suppression définitive ?';

  @override
  String get homePermanentDeleteConfirmBody => 'Cette action est irréversible.';

  @override
  String get homeWorksEmpty => 'Aucune œuvre exportée pour le moment';

  @override
  String get homeWorksEmptyHint =>
      'Exportez une vidéo ou un GIF depuis la timeline pour le retrouver ici.';

  @override
  String get homeWorkFolderEmpty =>
      'Ce dossier ne contient aucune œuvre exportée';

  @override
  String get homeSharedFolderEmpty =>
      'Ce dossier ne contient aucun projet partagé';

  @override
  String homeDeleteFolderKeepContents(String name) {
    return '« $name » sera supprimé. Son contenu reviendra dans la liste principale et ne sera pas supprimé.';
  }

  @override
  String get homeShareOpenWith => 'Partager / Ouvrir avec…';

  @override
  String get homePreviewFailed => 'Impossible de lire l’aperçu';

  @override
  String get homeFirstLaunchMessage =>
      'Vous pouvez créer des animations dessinées à la main';

  @override
  String get homeFirstLaunchStart => 'Commencer';

  @override
  String get homeFirstLaunchSaveFailed =>
      'Impossible d’enregistrer que vous avez vu ce message de bienvenue. Appuyez sur « Commencer » pour réessayer.';

  @override
  String get settingsScreenTitle => 'Réglages';

  @override
  String get settingsBasicTitle => 'Général';

  @override
  String get settingsBasicSubtitle => 'Cadence (i/s), langue, zone de dessin';

  @override
  String get settingsBasicSheetTitle => 'Réglages généraux';

  @override
  String get settingsDefaultFps => 'Cadence par défaut (i/s)';

  @override
  String get settingsDefaultFpsSubtitle =>
      'Valeur initiale pour les nouveaux projets';

  @override
  String get settingsLanguage => 'Langue';

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
  String get settingsSearchHint => 'Rechercher dans les réglages...';

  @override
  String get settingsPerformanceTitle => 'Performances';

  @override
  String get settingsPerformanceSubtitle =>
      'Qualité, historique d’annulation, corbeille, performances';

  @override
  String get settingsGestureTitle => 'Gestes';

  @override
  String get settingsGestureSubtitle => 'Appui à deux doigts, appui long';

  @override
  String get settingsPenTitle => 'Saisie au stylet';

  @override
  String get settingsPenSubtitle => 'Pression, inclinaison, boutons du stylet';

  @override
  String get settingsWorkspaceTitle => 'Espace de travail';

  @override
  String get settingsWorkspaceSubtitle =>
      'Édition de la barre d’outils, disposition des panneaux';

  @override
  String get settingsBucketTitle => 'Pot de peinture';

  @override
  String get settingsBucketSubtitle => 'Tolérance, extension, sous les traits';

  @override
  String get settingsThemeTitle => 'Thème et apparence';

  @override
  String get settingsThemeSubtitle => 'Couleurs du thème, texte et fond';

  @override
  String get settingsWatermarkTitle => 'Filigrane';

  @override
  String get settingsWatermarkSubtitle => 'Filigrane personnalisé';

  @override
  String get settingsTransferTitle => 'Transfert';

  @override
  String get settingsTransferSubtitle =>
      'Exporter/importer réglages, matériaux et pinceaux vers un autre appareil';

  @override
  String get settingsStorageSubtitle =>
      'Voir ce qui occupe de l’espace, faire du tri ou tout effacer';

  @override
  String get settingsFontTitle => 'Gestion des polices';

  @override
  String get settingsFontSubtitle =>
      'Ajouter, rechercher et supprimer des polices TTF/OTF';

  @override
  String get settingsNoResults => 'Aucun réglage correspondant trouvé';

  @override
  String get settingsTermsLicense => 'Conditions d’utilisation et licences';

  @override
  String get settingsDrawingAreaTitle => 'Zone de dessin par défaut';

  @override
  String get settingsDrawingAreaHint =>
      'Utilisée comme valeur initiale à la création d’un nouveau projet.';

  @override
  String get settingsDrawingAreaWiden => 'Agrandir la zone de dessin';

  @override
  String get settingsDrawingAreaScale => 'Échelle';

  @override
  String settingsScaleValue(String scale) {
    return '$scale×';
  }

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonCreate => 'Créer';

  @override
  String get commonChange => 'Modifier';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get confirmDeleteGenericBody =>
      'Voulez-vous vraiment supprimer ceci ? Cette action est irréversible.';

  @override
  String confirmDeleteNamedBody(String name) {
    return 'Supprimer « $name » ? Cette action est irréversible.';
  }

  @override
  String get commonFavoriteDeleteBlocked =>
      'Impossible de supprimer un élément favori. Retirez-le d’abord des favoris.';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String commonSavedAsSnackbar(String name) {
    return 'Enregistré sous « $name »';
  }

  @override
  String get commonRestore => 'Restaurer';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonRename => 'Renommer';

  @override
  String get commonCopy => 'Copier';

  @override
  String get commonCut => 'Couper';

  @override
  String get commonPaste => 'Coller';

  @override
  String get commonDuplicate => 'Dupliquer';

  @override
  String commonLabelWithValue(String label, String value) {
    return '$label : $value';
  }

  @override
  String get commonOk => 'OK';

  @override
  String get gestureSettingsTitle => 'Réglages des gestes';

  @override
  String get gestureTwoFingerTap => 'Appui à deux doigts';

  @override
  String get gestureThreeFingerTap => 'Appui à trois doigts';

  @override
  String get gestureFourOrMoreFingerTap => 'Appui à quatre doigts ou plus';

  @override
  String get gestureTwoFingerSwipe => 'Balayage horizontal à deux doigts';

  @override
  String get gestureLongPress => 'Appui long';

  @override
  String get gestureHoldEyedropperSection => 'Pipette par appui long';

  @override
  String get gestureHoldEyedropperTitle => 'Activer la pipette par appui long';

  @override
  String get gestureHoldEyedropperHint =>
      'En dessinant avec la plume ou la gomme, maintenir le doigt immobile un instant prélève la couleur sous le doigt comme couleur actuelle.';

  @override
  String get gestureHoldEyedropperDurationLabel => 'Durée de maintien';

  @override
  String get gestureTouchSection => 'Gestes des doigts';

  @override
  String get gestureHoldEyedropperNeedsLongPress =>
      'Disponible lorsque « Appui long », ci-dessus, est réglé sur « Pipette ».';

  @override
  String get gestureHoldEyedropperUseLongPress =>
      'Régler l’appui long sur Pipette';

  @override
  String gestureHoldEyedropperSecondsValue(String seconds) {
    return '$seconds s';
  }

  @override
  String get gestureActionUndo => 'Annuler';

  @override
  String get gestureActionRedo => 'Rétablir';

  @override
  String get gestureActionEyedropper => 'Pipette';

  @override
  String get gestureActionPanTool => 'Outil main';

  @override
  String get gestureActionEraserToggle => 'Basculer la gomme';

  @override
  String get gestureActionBrushToggle => 'Basculer le pinceau';

  @override
  String get gestureActionFrameMove => 'Changer d’image';

  @override
  String get gestureActionNextTool => 'Changement rapide d’outil';

  @override
  String get gestureActionOnionSkinToggle =>
      'Activer/désactiver le papier calque';

  @override
  String get gestureActionNone => 'Ne rien faire';

  @override
  String get homeDrawerAppTagline =>
      'Application de création d’animation dessinée à la main';

  @override
  String get homeDrawerAutofillPreset => 'Réglages de remplissage auto';

  @override
  String get homeDrawerSettings => 'Réglages';

  @override
  String get gestureActionNoneShort => 'Aucune';

  @override
  String get pressureTryDrawHint =>
      'Vous pouvez essayer de dessiner avec ce réglage (avec un stylet, la pression réelle est prise en compte)';

  @override
  String get pressureTryDrawClear => 'Effacer';

  @override
  String get penSettingsStabilizationSection => 'Stabilisation';

  @override
  String get penSettingsStabilizationStrength => 'Intensité';

  @override
  String get penSettingsStabilizationHint =>
      'Atténue les petits tremblements de la pointe du stylet pour lisser les traits. Plus elle est forte, moins il reste de tremblements, mais le trait suit la pointe avec un léger retard. À 0, aucun lissage n’est appliqué. La même intensité s’applique à tous les pinceaux.';

  @override
  String get penSettingsTitle => 'Réglages de saisie au stylet';

  @override
  String get penSettingsPalmRejectionTitle => 'Rejet de la paume';

  @override
  String get penSettingsPalmRejectionHint =>
      'Évite les entrées accidentelles avec un seul doigt pendant l’utilisation d’un stylet. Les gestes à deux doigts ou plus restent disponibles.';

  @override
  String get penSettingsCurveSection => 'Courbe de pression';

  @override
  String get penSettingsCurveHint =>
      'Un réglage plus faible fait monter la pression progressivement ; un réglage plus fort la fait monter brusquement.';

  @override
  String get penSettingsCurveWeak => 'Faible';

  @override
  String get penSettingsCurveNormal => 'Normal';

  @override
  String get penSettingsCurveStrong => 'Fort';

  @override
  String get penSettingsCurveCustom => 'Personnalisé';

  @override
  String get penSettingsCustomGraphHint =>
      'Touchez un espace vide du graphique pour ajouter un point, faites glisser un point pour le déplacer, ou touchez-le deux fois pour le supprimer (les points de début et de fin ne peuvent pas être supprimés).';

  @override
  String get penSettingsGraphAxes =>
      'Horizontal : pression du stylet. Vertical : effet sur l’épaisseur et l’opacité.';

  @override
  String get penSettingsResetCurveButton => 'Réinitialiser';

  @override
  String get penSettingsPerBrushNote =>
      '* Le réglage « Appliquer à la taille/opacité » de la pression est propre à chaque pinceau (à modifier dans le panneau de réglages du pinceau).';

  @override
  String get penSettingsButtonSection => 'Réglages des boutons du stylet';

  @override
  String get penSettingsButton1 => 'Bouton 1';

  @override
  String get penSettingsButton2 => 'Bouton 2';

  @override
  String get bucketSettingsTitle => 'Réglages du pot de peinture';

  @override
  String get bucketSettingsToleranceSection => 'Tolérance de couleur';

  @override
  String get bucketSettingsToleranceHint =>
      'Ajuste l’écart de couleur toléré par rapport au pixel touché pour être considéré comme la même zone. Plus la valeur est élevée, plus le remplissage se propage facilement même sur des contours flous.';

  @override
  String get bucketSettingsExpandSection => 'Extension';

  @override
  String get bucketSettingsExpandHint =>
      'Étend la zone remplie vers l’extérieur du nombre de pixels indiqué, pour couvrir les petits interstices près du trait.';

  @override
  String get bucketSettingsUnderLineTitle => 'Passer sous les traits';

  @override
  String get bucketSettingsUnderLineHint =>
      'Au lieu de peindre par-dessus le trait, l’extension se fond derrière les pixels existants : l’apparence du trait est conservée tout en comblant les interstices de ses bords anticrénelés.';

  @override
  String get bucketSettingsUnderLineDisabledHint =>
      'Sans effet lorsque « Extension » est à 0 px.';

  @override
  String fontCatalogSearchHint(int count) {
    return 'Rechercher par nom de police... ($count polices)';
  }

  @override
  String get fontCatalogCategories => 'Catégories de polices';

  @override
  String get fontCatalogAll => 'Toutes';

  @override
  String get fontCatalogNoResults => 'Aucune police correspondante trouvée';

  @override
  String get rulerPanelTitle => 'Règle';

  @override
  String get rulerTypeLine => 'Règle droite';

  @override
  String get rulerTypeEllipse => 'Règle elliptique';

  @override
  String get rulerTypeRadial => 'Règle de lignes de vitesse';

  @override
  String get rulerTypeOnePoint => 'Perspective à un point';

  @override
  String get rulerTypeTwoPoint => 'Perspective à deux points';

  @override
  String get rulerTypeThreePoint => 'Perspective à trois points';

  @override
  String get rulerTypeFisheye => 'Perspective fish-eye';

  @override
  String get rulerSnap => 'Aimanter à la règle';

  @override
  String get rulerDivisions => 'Divisions';

  @override
  String get transferScreenTitle => 'Transfert (.niatra)';

  @override
  String get transferInstructionHint =>
      'Sélectionnez les éléments à transférer vers un autre appareil.';

  @override
  String get transferItemSettings => 'Réglages';

  @override
  String get transferItemMaterials => 'Matériaux';

  @override
  String get transferItemBrush => 'Pinceaux';

  @override
  String get transferItemPresets => 'Réglages de remplissage auto';

  @override
  String get transferItemTheme => 'Thème';

  @override
  String get transferItemPalette =>
      'Palettes (sélecteur de couleurs et pixel art)';

  @override
  String get transferProjectsSectionTitle => 'Projets en cours (facultatif)';

  @override
  String get transferProjectsHint =>
      'Sélectionnez uniquement les projets à inclure dans le transfert. Les projets sélectionnés sont transférés intégralement, y compris leurs matériaux et polices.';

  @override
  String get transferProjectsEmpty => 'Aucun projet pour le moment.';

  @override
  String get transferImport => 'Importer';

  @override
  String get transferExport => 'Exporter';

  @override
  String get transferExportSuccessSnackbar => 'Fichier .niatra exporté';

  @override
  String get transferImportSuccessSnackbar => 'Fichier .niatra importé';

  @override
  String transferImportAddedCopiesSnackbar(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Fichier .niatra importé. $count éléments étaient différents sur cet appareil : les versions de cet appareil ont été conservées et celles importées ont été ajoutées sous des noms comme « $name »',
      one:
          'Fichier .niatra importé. $count élément était différent sur cet appareil : la version de cet appareil a été conservée et celle importée a été ajoutée sous le nom « $name »',
    );
    return '$_temp0';
  }

  @override
  String transferImportShortcutsNotAddedSnackbar(
    int count,
    String name,
    String combo,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count raccourcis importés, dont « $name » ($combo), n’ont pas été ajoutés, car cet appareil utilise les mêmes touches pour d’autres actions. Pour les utiliser, ajoutez-les avec d’autres touches dans les réglages Raccourcis',
      one:
          '$count raccourci importé « $name » ($combo) n’a pas été ajouté, car cet appareil utilise les mêmes touches pour une autre action. Pour l’utiliser, ajoutez-le avec d’autres touches dans les réglages Raccourcis',
    );
    return '$_temp0';
  }

  @override
  String get folderManagementTitle => 'Gestion des dossiers';

  @override
  String get folderManagementCreateNew => 'Nouveau';

  @override
  String get folderManagementEmpty => 'Aucun dossier pour le moment';

  @override
  String get folderCreateFailed => 'Impossible de créer le dossier. Réessayez.';

  @override
  String get folderChangesSaveFailed =>
      'Impossible d’enregistrer les modifications du dossier. Réessayez.';

  @override
  String get folderChangesPartiallySaved =>
      'Seule une partie des modifications a été enregistrée. Vérifiez la liste et réessayez.';

  @override
  String get folderNameLabel => 'Nom du dossier';

  @override
  String get folderMoveToTitle => 'Déplacer vers un dossier';

  @override
  String folderMoveSheetSemanticsLabel(String name) {
    return 'Déplacer « $name » vers un dossier';
  }

  @override
  String folderColorOptionSemanticsLabel(String code) {
    return 'Couleur du dossier $code';
  }

  @override
  String colorPickerCurrentColorSemanticsLabel(String code) {
    return 'Couleur sélectionnée $code';
  }

  @override
  String get folderNone => 'Aucun dossier';

  @override
  String folderMovedIntoSnackbar(String folder) {
    return 'Déplacé dans « $folder »';
  }

  @override
  String get folderMovedOutSnackbar => 'Sorti du dossier';

  @override
  String creativeFolderDeleteBody(String name) {
    return 'Supprimer « $name » ? Son contenu sera déplacé vers « Aucun dossier ».';
  }

  @override
  String get creativeAssetNameLabel => 'Nom';

  @override
  String get commonAdd => 'Ajouter';

  @override
  String get commonSearch => 'Rechercher';

  @override
  String get autofillPresetSelectionTitle =>
      'Réglages de remplissage auto à utiliser';

  @override
  String get autofillPresetSelectionHint =>
      'Ne sélectionner que les réglages de remplissage automatique utilisés dans ce projet garde la liste d’attribution des parties plus courte et plus lisible.';

  @override
  String autofillPresetSelectionPartCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parties',
      one: '$count partie',
    );
    return '$_temp0';
  }

  @override
  String get autofillPresetSelectionButton =>
      'Sélectionner les réglages de remplissage auto à utiliser';

  @override
  String autofillPresetSelectionCountLabel(int count) {
    return 'Réglages de remplissage auto : $count sélectionné(s)';
  }

  @override
  String get commonEdit => 'Modifier';

  @override
  String get commonFavoriteToggle => 'Basculer favori';

  @override
  String get commonIncrease => 'Augmenter';

  @override
  String get commonDecrease => 'Diminuer';

  @override
  String get commonPlay => 'Lecture';

  @override
  String get commonPause => 'Pause';

  @override
  String get fontCatalogDownloadTooltip => 'Télécharger la police';

  @override
  String get timelineBackToCanvasTooltip => 'Enregistrer et revenir au canevas';

  @override
  String get timelineBackToProjectListTooltip =>
      'Retour à la liste des projets';

  @override
  String get timelineBackToProjectListDialogTitle =>
      'Retour à la liste des projets';

  @override
  String get timelineBackToProjectListDialogBody =>
      'Le projet est enregistré automatiquement. Faire aussi une sauvegarde manuelle avant de revenir ?';

  @override
  String get timelineBackToProjectListSaveButton => 'Enregistrer et revenir';

  @override
  String get timelineBackToProjectListDiscardButton =>
      'Revenir sans sauvegarde manuelle';

  @override
  String get timelineSkipToStart => 'Aller à la première image';

  @override
  String get timelineStepBack => 'Reculer d’une image';

  @override
  String get timelineStepForward => 'Avancer d’une image';

  @override
  String get timelineSkipToEnd => 'Aller à la dernière image';

  @override
  String get timelineLoopOnTooltip =>
      'Lecture en boucle : ACTIVÉE (touchez pour désactiver)';

  @override
  String get timelineLoopOffTooltip =>
      'Lecture en boucle : DÉSACTIVÉE (touchez pour activer)';

  @override
  String get quickToolPanelTitle => 'Réglages des outils rapides';

  @override
  String get quickToolBrushUnavailable => 'Pinceau indisponible';

  @override
  String get quickToolEmpty => 'Aucun outil enregistré';

  @override
  String get quickToolAddCurrentBrush => 'Ajouter le pinceau actuel';

  @override
  String get quickToolEraser => 'Gomme';

  @override
  String get quickToolEyedropper => 'Pipette';

  @override
  String get quickToolBucket => 'Pot de peinture';

  @override
  String quickToolSizeDialogTitle(String brushName) {
    return 'Taille de $brushName';
  }

  @override
  String get settingsShortcutTitle => 'Raccourcis';

  @override
  String get settingsShortcutSubtitle =>
      'Assignez des outils et actions au clavier ou à un périphérique main gauche';

  @override
  String get shortcutSettingsTitle => 'Raccourcis';

  @override
  String get shortcutSettingsHint =>
      'Assignez des touches du clavier ou d’un périphérique main gauche à des outils (jusqu’à un pinceau et une taille précis) ou à des actions comme Annuler/Rétablir. Fonctionne en mode Canevas et en mode Timeline.';

  @override
  String get shortcutEmpty => 'Aucun raccourci enregistré';

  @override
  String get shortcutResetButton => 'Rétablir les raccourcis par défaut';

  @override
  String get shortcutResetConfirmTitle =>
      'Rétablir les raccourcis par défaut ?';

  @override
  String get shortcutResetConfirmBody =>
      'Les raccourcis que vous avez ajoutés seront supprimés, et ceux que vous avez modifiés ou supprimés retrouveront leurs touches d’origine.';

  @override
  String get shortcutResetConfirmAction => 'Rétablir';

  @override
  String get shortcutResetDone => 'Raccourcis par défaut rétablis.';

  @override
  String get shortcutCaptureTitle => 'Appuyez sur une touche';

  @override
  String get shortcutCaptureHint =>
      'Appuyez sur la combinaison de touches à assigner (vous pouvez maintenir Ctrl/Maj/Alt, etc. en même temps). Appuyez sur Échap pour annuler.';

  @override
  String shortcutChooseActionTitle(String combo) {
    return 'Que doit faire $combo ?';
  }

  @override
  String get shortcutActionTypeTool => 'Choisir un outil';

  @override
  String get shortcutActionTypeCommand => 'Action principale';

  @override
  String get shortcutCommandUndo => 'Annuler';

  @override
  String get shortcutCommandRedo => 'Rétablir';

  @override
  String get shortcutCommandToggleLayerPanel =>
      'Basculer le panneau des calques (Canevas)';

  @override
  String get shortcutCommandPlayPause => 'Lecture/Pause (Timeline)';

  @override
  String get shortcutCommandPreviousFrame => 'Image précédente (Timeline)';

  @override
  String get shortcutCommandNextFrame => 'Image suivante (Timeline)';

  @override
  String get shortcutCommandSelectAll => 'Sélection totale';

  @override
  String get shortcutCommandCopy => 'Copier';

  @override
  String get shortcutCommandCut => 'Couper';

  @override
  String get shortcutCommandPaste => 'Coller';

  @override
  String get shortcutConflictTitle => 'Déjà assigné';

  @override
  String shortcutBindingName(String key, String action) {
    return '$key : $action';
  }

  @override
  String shortcutConflictBody(String combo, String existingLabel) {
    return '$combo est déjà assigné à « $existingLabel ». Voulez-vous l’écraser ?';
  }

  @override
  String get shortcutConflictOverwrite => 'Écraser';

  @override
  String get materialListTitle => 'Gestion des matériaux';

  @override
  String materialRemoveUnused(int count) {
    return 'Supprimer les inutilisés ($count)';
  }

  @override
  String get materialEmptyTitle => 'Aucun matériau';

  @override
  String get materialEmptyHint =>
      'Ajoutez des images, vidéos ou fichiers audio depuis la timeline et ils apparaîtront ici';

  @override
  String get materialUsedLabel => 'Utilisé';

  @override
  String get materialUnusedLabel => 'Inutilisé';

  @override
  String get materialMissingLabel => 'Manquant';

  @override
  String get materialDeleteTooltipUsed =>
      'Impossible de supprimer un élément utilisé';

  @override
  String get materialRemoveOneConfirmTitle => 'Supprimer ce matériau ?';

  @override
  String get materialRemoveUnusedConfirmTitle =>
      'Supprimer tous les matériaux inutilisés ?';

  @override
  String get materialRemoveUnusedConfirmBody =>
      'Cela supprimera tous les matériaux non référencés dans le projet. Cette action est irréversible.';

  @override
  String materialRemovedSnackbar(int count) {
    return '$count matériau(x) inutilisé(s) supprimé(s)';
  }

  @override
  String get watermarkEmptyTitle => 'Aucun filigrane pour le moment';

  @override
  String get watermarkEmptyHint =>
      'Appuyez sur le bouton + pour ajouter un filigrane image ou texte';

  @override
  String get watermarkAddFromImage => 'Ajouter depuis une image';

  @override
  String get watermarkAddText => 'Saisir du texte';

  @override
  String get watermarkImageImportFailed =>
      'Impossible de charger l’image. Choisissez-en une autre.';

  @override
  String get watermarkAddedSnackbar => 'Filigrane ajouté';

  @override
  String get watermarkTextDialogTitle => 'Ajouter un filigrane textuel';

  @override
  String get watermarkTextFieldLabel => 'Texte à afficher';

  @override
  String get watermarkTextColorLabel => 'Couleur du texte';

  @override
  String get watermarkTextColorTapHint => 'Touchez pour choisir une couleur';

  @override
  String get watermarkDropShadowLabel => 'Ombre portée';

  @override
  String get watermarkShadowColorLabel => 'Couleur de l’ombre';

  @override
  String get watermarkShadowOffsetXLabel => 'Décalage X de l’ombre';

  @override
  String get watermarkShadowOffsetYLabel => 'Décalage Y de l’ombre';

  @override
  String get watermarkShadowBlurLabel => 'Flou de l’ombre';

  @override
  String get watermarkOutlineLabel => 'Contour';

  @override
  String get watermarkOutlineColorLabel => 'Couleur du contour';

  @override
  String get watermarkOutlineWidthLabel => 'Épaisseur du contour';

  @override
  String get premiumActiveLabel => 'Premium actif';

  @override
  String get premiumVsTitle => 'Gratuit vs Premium';

  @override
  String get premiumHeroTitle => 'Plus de liberté avec Premium';

  @override
  String get premiumHeroHighlightDuration => 'Jusqu’à 2 heures';

  @override
  String get premiumHeroHighlightWatermark =>
      'Afficher ou masquer la marque de fin officielle';

  @override
  String get premiumHeroHighlightGrading => 'Courbe de tons /\nniveaux';

  @override
  String get premiumPlanSectionTitle => 'Formules';

  @override
  String get premiumCheckoutPending => 'Achat en cours sur Google Play.';

  @override
  String get premiumCheckoutStartFailed =>
      'Impossible d’ouvrir la page d’achat de Google Play. Sélectionnez à nouveau une formule.';

  @override
  String get premiumErrorSignInRequired =>
      'Pour acheter, connectez-vous avec votre compte Google et au serveur qui confirme les achats.';

  @override
  String get premiumErrorStoreUnavailable =>
      'Impossible de se connecter à Google Play. Vérifiez votre connexion et réessayez.';

  @override
  String get premiumErrorProductUnavailable =>
      'Impossible de charger les informations des formules. Veuillez réessayer plus tard.';

  @override
  String get premiumErrorVerifierUnavailable =>
      'Les achats ne peuvent pas commencer, car le serveur qui les confirme est indisponible. Veuillez réessayer plus tard.';

  @override
  String get premiumErrorNotConfirmed =>
      'Impossible de confirmer l’achat auprès du serveur. Utilisez « Restaurer les achats » pour vérifier à nouveau.';

  @override
  String get premiumErrorNoValidPurchase =>
      'Aucun achat Google Play valide n’a été trouvé.';

  @override
  String get premiumErrorVerificationFailed =>
      'Impossible de confirmer l’achat. Utilisez « Restaurer les achats » pour vérifier à nouveau.';

  @override
  String get premiumErrorPurchaseFailed =>
      'Impossible de finaliser l’achat. Veuillez réessayer.';

  @override
  String get premiumRestoreFailed =>
      'Impossible de restaurer les achats. Veuillez réessayer.';

  @override
  String get premiumStoreUnavailable =>
      'Impossible de charger les informations d’achat de la boutique. Vérifiez votre connexion et réessayez.';

  @override
  String get premiumYearlyTitle => 'Formule annuelle';

  @override
  String get premiumYearlyPrice => '5 500 ¥/an';

  @override
  String get premiumYearlyOriginalPrice => '6 600 ¥';

  @override
  String get premiumMonthlyTitle => 'Formule mensuelle';

  @override
  String get premiumRestorePurchases => 'Restaurer les achats';

  @override
  String get premiumRestoredSnackbar =>
      'Vos achats ont été restaurés (le cas échéant)';

  @override
  String get premiumComparisonFeature => 'Fonctionnalité';

  @override
  String get premiumComparisonFree => 'Gratuit';

  @override
  String get premiumFeatureDrawing => 'Dessin et animation';

  @override
  String get premiumFeatureTimeline => 'Timeline';

  @override
  String get premiumFeatureExport => 'Export vidéo';

  @override
  String get premiumDurationExportNote =>
      'L’export intégral d’un projet de plus de 90 secondes nécessite Premium ou l’avantage de durée étendue. Vous pouvez exporter les 90 premières secondes.';

  @override
  String get premiumFeatureMaxDuration => 'Durée max.';

  @override
  String get premiumFeatureEndLogo => 'Marque de fin officielle';

  @override
  String get premiumFeatureMakingEndLogo =>
      'Marque de fin officielle des vidéos du making-of';

  @override
  String get premiumFeatureGifCornerLogo => 'Logo NIARIM dans le coin des GIF';

  @override
  String get premiumFeatureWatermark =>
      'Ajouter et modifier votre propre filigrane';

  @override
  String get premiumFeatureToneCurve => 'Courbe de tons';

  @override
  String get premiumFeatureLevelCorrection => 'Correction des niveaux';

  @override
  String get premiumFeatureAds => 'Publicités';

  @override
  String get premiumFeatureCommunityUpload =>
      'Publications quotidiennes sur la Place des œuvres';

  @override
  String get premiumValueYes => 'Oui';

  @override
  String get premiumValueNo => 'Non';

  @override
  String get premiumValueRemovable => 'Supprimable';

  @override
  String get premiumValueDuration2Hours => '2 heures';

  @override
  String get premiumValueDuration90Sec => '1,5 min';

  @override
  String get premiumValueUploadFree => '1 œuvre';

  @override
  String get premiumValueUploadPremium => '3 œuvres';

  @override
  String get premiumPlanRecommendedBadge => 'Recommandé';

  @override
  String get premiumMonthlyPrice => '550 ¥/mois';

  @override
  String get toolbarItemPen => 'Plume';

  @override
  String get toolbarItemEraser => 'Gomme';

  @override
  String get toolbarItemBucket => 'Pot de peinture';

  @override
  String get toolbarItemEyedropper => 'Pipette';

  @override
  String get toolbarItemFinger => 'Doigt';

  @override
  String get toolbarItemPan => 'Main';

  @override
  String get toolbarItemSelect => 'Sélection';

  @override
  String get toolbarItemText => 'Texte';

  @override
  String get toolbarItemShape => 'Forme';

  @override
  String get workspaceScreenTitle => 'Réglages de l’espace de travail';

  @override
  String get workspaceToolbarEditSection => 'Édition de la barre d’outils';

  @override
  String get workspaceToolbarEditHint =>
      'Sélectionnez les outils à afficher avec les cases à cocher, et glissez-déposez pour les réorganiser.';

  @override
  String get workspaceToolbarPcOnlyHint =>
      'Affiché dans la barre d’outils uniquement en orientation paysage';

  @override
  String get workspaceToolbarPanDisabledHint =>
      'Indisponible en mode smartphone';

  @override
  String get workspaceResetToolbarDefault => 'Réinitialiser';

  @override
  String get workspacePanelLayoutSection => 'Disposition des panneaux';

  @override
  String get workspaceLeftHandedMode => 'Mode gaucher';

  @override
  String get workspaceLeftHandedSubtitlePc =>
      'Inverser les panneaux de gauche et de droite';

  @override
  String get workspaceLeftHandedSubtitleMobile =>
      'Disponible uniquement en mode PC/DeX';

  @override
  String get workspacePcModeSection => 'Mode PC (DeX)';

  @override
  String get workspacePcModeHint =>
      'Sur les écrans larges, l’application passe automatiquement à la disposition professionnelle avec les panneaux fixés en place. Réglez-le manuellement ici pour le forcer. Sur les écrans de moins de 600 px de large, la disposition du mode mobile est utilisée même si le mode PC est fixé.';

  @override
  String get workspacePcModeAuto =>
      'Automatique (selon la largeur de l’écran, recommandé)';

  @override
  String get workspacePcModeAlwaysPc => 'Toujours en mode PC';

  @override
  String get workspacePcModeAlwaysMobile => 'Toujours en mode mobile';

  @override
  String get workspaceSaveSection => 'Enregistrer l’espace de travail';

  @override
  String get workspaceSaveHint =>
      'Enregistrez vos réglages de mode gaucher, mode PC, barre d’outils et outils rapides sous un nom afin de pouvoir les recharger plus tard.';

  @override
  String get workspaceLoadButton => 'Charger un espace de travail';

  @override
  String workspaceLoadConfirmBody(String name) {
    return 'Le chargement de « $name » remplacera les réglages actuels de l’espace de travail. Vous pouvez les enregistrer d’abord.';
  }

  @override
  String get workspaceEmptyToolbar => 'Aucun outil à afficher';

  @override
  String get workspaceSaveDialogTitle => 'Enregistrer l’espace de travail';

  @override
  String get workspaceSaveDialogLabel =>
      'Nom (ex. : Animation, Dessin au trait)';

  @override
  String get workspaceLoadRightHanded => 'Droitier';

  @override
  String get workspaceLoadLeftHanded => 'Gaucher';

  @override
  String get helpScreenTitle => 'Aide';

  @override
  String get helpSearchHint => 'Rechercher...';

  @override
  String helpSearchResultCount(int count) {
    return 'Résultats ($count)';
  }

  @override
  String get helpNoResults => 'Aucun élément correspondant trouvé';

  @override
  String get helpCategoryTool => 'Outils';

  @override
  String get helpCategoryLayer => 'Calques';

  @override
  String get helpCategoryAnimation => 'Animation';

  @override
  String get helpCategoryDrawing => 'Dessin';

  @override
  String get helpCategoryBrush => 'Pinceau';

  @override
  String get helpCategoryPenInput => 'Saisie au stylet';

  @override
  String get helpCategorySave => 'Enregistrement';

  @override
  String get helpCategoryProjectManagement => 'Gestion de projet';

  @override
  String get helpCategoryExport => 'Export';

  @override
  String get helpCategoryPremium => 'Premium';

  @override
  String get helpCategorySettings => 'Réglages';

  @override
  String get helpCategoryCommunity => 'Communauté';

  @override
  String get helpPenToolTitle => 'Outil plume';

  @override
  String get helpPenToolDesc =>
      'L’outil de base pour dessiner des lignes sur le canevas. Un appui long permet de changer le type, la taille et la couleur du pinceau (un double appui affiche un résumé rapide). Il prend en charge la pression et l’inclinaison des tablettes/stylets, et ajuster la courbe de pression dans Réglages > Saisie au stylet permet de personnaliser finement la façon dont la pression influence la taille et l’opacité. En changeant de sous-outil de plume, vous pouvez appliquer des trames ou placer des tampons avec le même outil.';

  @override
  String get helpEraserToolTitle => 'Outil gomme';

  @override
  String get helpEraserToolDesc =>
      'L’équivalent de l’outil plume, utilisé pour effacer ce que vous avez dessiné. Comme un pinceau, vous pouvez ajuster sa taille et son opacité, et les réglages de pinceau comme le fondu et l’atténuation de trait s’y appliquent aussi. Plutôt que d’« ajouter » aux parties transparentes d’un calque, il « retire » le dessin existant, si bien que le calque en dessous devient visible à travers.';

  @override
  String get helpBucketToolTitle => 'Outil pot de peinture';

  @override
  String get helpBucketToolDesc =>
      'Remplit une zone fermée en une seule fois. Appuyez à l’intérieur d’une zone entourée par un trait et toute la zone est remplie avec la couleur (ou la trame) sélectionnée. S’il y a des espaces dans le trait, le remplissage peut déborder sur des zones non voulues ; assurez-vous donc que le trait est bien fermé avant de l’utiliser. Vous pouvez basculer entre remplissage uni et remplissage en trame dans les réglages. Les réglages détaillés (tolérance, extension en px, passer sous les traits) sont accessibles depuis « Pot de peinture » dans les réglages.';

  @override
  String get helpLassoFillTitle => 'Remplissage lasso';

  @override
  String get helpLassoFillDesc =>
      'Tracez avec votre doigt pour former une zone polygonale, puis remplissez l’intérieur en une seule fois. Contrairement au pot de peinture, vous pouvez définir la zone vous-même même là où le trait n’est pas fermé, ce qui le rend idéal pour les formes complexes ou les zones avec des lignes interrompues. Avec « Remplir la zone fermée » activé, toutes les zones fermées par des traits à l’intérieur du lasso sont remplies d’un coup, quel que soit leur nombre, comme avec le pot de peinture (l’espace entre le lasso et le dessin reste tel quel).';

  @override
  String get helpEyedropperToolTitle => 'Outil pipette';

  @override
  String get helpEyedropperToolDesc =>
      'Prélève la couleur à l’endroit où vous appuyez et la définit comme couleur de dessin. Il échantillonne le rendu composité de tous les calques tel qu’affiché à l’écran, ce qui permet de récupérer précisément la « couleur telle que vue » même là où plusieurs calques se superposent.';

  @override
  String get helpSelectToolTitle => 'Outil de sélection';

  @override
  String get helpSelectToolDesc =>
      'Sélectionne une partie du canevas afin de pouvoir déplacer, faire pivoter ou redimensionner uniquement cette zone. Un appui long permet de choisir parmi trois méthodes de sélection : « Sélection rectangulaire », « Sélection au lasso » (contour libre), ou « Sélection automatique » (baguette magique — regroupe automatiquement les zones de couleur similaire). Pendant une sélection, un contour marque la zone sélectionnée sur le canevas, et la même zone reste fixée sur toutes les images et tous les calques jusqu’à ce que vous désélectionniez. En sélection au lasso, activer « Magnétiser aux lignes » examine les zones que le dessin au trait découpe dans le canevas, comme le fait le pot de peinture, et ne sélectionne que les zones situées en majeure partie dans le lasso. Le bord de la sélection suit exactement le bord extérieur du dessin au trait : les traits qui entourent ces zones et ceux à l’intérieur sont sélectionnés avec elles (un trait qui continue hors du contour est coupé là où il le quitte). Les couleurs remplies comptent comme des zones à part entière, comme pour le pot de peinture : un calque avec des aplats et des traits se sélectionne lui aussi selon la forme du dessin. Les interruptions d’un trait jusqu’à la largeur de « Tolérance des espaces » sont considérées comme fermées. S’il n’y a pas de dessin au trait dans le lasso, le lasso est sélectionné tel que tracé. Les traits sont pris dans la référence de sélection (« Calque de travail uniquement » / « Tous les calques visibles »).';

  @override
  String get helpFingerToolTitle => 'Outil doigt (déformation)';

  @override
  String get helpFingerToolDesc =>
      'Déforme les pixels en les poussant dans la direction où vous faites glisser votre doigt, comme si vous étaliez de la peinture humide avec un doigt. Il sert moins aux corrections précises qu’à déformer de manière organique des lignes déjà dessinées pour leur donner plus d’expression.';

  @override
  String get helpShapeToolTitle => 'Outil forme';

  @override
  String get helpShapeToolDesc =>
      'Dessine des formes précises comme des lignes, des rectangles et des cercles en un seul geste. Faire glisser du point de départ au point d’arrivée affiche un aperçu en direct, et la forme est finalisée lorsque vous relâchez le doigt. Pratique lorsque vous avez besoin de lignes droites ou de cercles parfaits difficiles à réaliser à main levée.';

  @override
  String get helpTextToolTitle => 'Outil texte';

  @override
  String get helpTextToolDesc =>
      'Place du texte sur le canevas. Vous pouvez choisir la police, la taille, la couleur et le sens d’écriture vertical/horizontal. L’écriture verticale prend en charge la rotation automatique des caractères alphanumériques demi-chasse, le tate-chu-yoko (garder les nombres à l’horizontale dans un texte vertical) et le rubi (furigana). Le texte placé est également gravé en pixels lors de l’export. Avec l’outil texte, touchez un texte placé pour le modifier, ou faites-le glisser pour le déplacer. Un nouveau texte reprend la mise en forme du dernier texte validé. Un écran où vous pouvez ajouter, rechercher et supprimer des polices disponibles dans l’outil texte. Les polices gratuites supplémentaires au-delà de celles fournies par défaut sont téléchargées à la demande depuis ici, afin de réduire la taille d’installation initiale.';

  @override
  String get helpQuickToolTitle => 'Outil rapide';

  @override
  String get helpQuickToolDesc =>
      'Enregistrez des combinaisons de pinceaux et d’outils que vous utilisez souvent, et faites défiler entre elles d’une simple pression sur un bouton. Faites un appui long ou balayez vers le haut sur le bouton Outil rapide (flèches circulaires) du canevas pour ouvrir une fenêtre de gestion où ajouter, réorganiser et supprimer des entrées. Faites glisser pour changer leur ordre.';

  @override
  String get helpLayerTitle => 'Calques';

  @override
  String get helpLayerDesc =>
      'Un système qui permet de dessiner sur un même canevas réparti en plusieurs « calques » transparents. En dessinant l’encrage, la coloration et les arrière-plans sur des calques séparés, vous pouvez refaire uniquement la coloration plus tard ou changer l’arrière-plan sans effacer l’encrage. Les calques empilés plus haut apparaissent devant à l’écran. Chaque ligne de calque dispose de boutons en un geste pour le supprimer ou le fusionner avec le calque du dessous, et un bouton en haut du panneau des calques permet de fusionner tous les calques visibles à la fois.';

  @override
  String get helpBlendModeTitle => 'Mode de fusion';

  @override
  String get helpBlendModeDesc =>
      'Modifie la façon dont un calque se combine avec les calques en dessous. Souvent utilisé pour superposer des trames ou des effets de couleur.\nNormal : superpose tel quel.\nProduit : assombrit en multipliant avec le calque du dessous. Le choix classique pour les ombres.\nÉcran : éclaircit en ajoutant de la lumière. Bon pour les effets lumineux.\nIncrustation : assombrit les zones sombres et éclaircit les zones claires, augmentant le contraste.\nAddition (lueur) : additionne simplement les couleurs. Bon pour les traits de lumière.\nSoustraction : soustrait les couleurs, donnant un aspect sombre et étouffé.\nObscurcir : conserve la couleur la plus sombre entre les deux calques.\nÉclaircir : conserve la couleur la plus claire entre les deux calques.\nDensité couleur + : assombrit et sature la couleur du dessous.\nDensité couleur ‑ : éclaircit et sature la couleur du dessous.\nLumière crue : une version plus intense du contraste d’Incrustation.\nLumière tamisée : une version plus douce du contraste d’Incrustation. Bonne pour des ombrages doux.\nDifférence : affiche la différence entre les deux couleurs. Utile pour vérifier un décalage de couleur.\nTeinte / Saturation / Couleur / Luminosité : applique uniquement cette propriété (teinte, saturation, couleur ou luminosité) de ce calque sur celui du dessous.\nDensité linéaire + : additionne les deux couleurs puis retire la valeur de base pour assombrir fortement.\nDensité linéaire ‑ : additionne linéairement les deux couleurs pour éclaircir. Ce mode est distinct d’Addition (lueur) : lorsque le calque est semi-transparent, Addition (lueur) donne un résultat plus clair.\nLumière vive : alterne entre densité et éclaircissement selon la couleur supérieure pour un contraste très fort.\nLumière linéaire : augmente ou réduit linéairement la luminosité selon la couleur supérieure.\nLumière ponctuelle : remplace vers le côté sombre ou clair selon la couleur supérieure.\nMélange maximal : applique un seuil au résultat de Lumière vive pour une séparation très franche des couleurs.\nExclusion : effet d’inversion et de différence plus doux que Différence.\nDivision : divise la couleur inférieure par la couleur supérieure, utile pour éclaircir et accentuer les écarts de couleur.\nDans la liste des modes de fusion, chaque mode affiche un aperçu du rouge, du jaune, du bleu, du blanc et du noir posés sur des couleurs allant du sombre au clair (le bas de l’aperçu les montre semi-transparents).';

  @override
  String get helpClippingTitle => 'Écrêtage';

  @override
  String get helpClippingDesc =>
      'Restreint le dessin aux seuls pixels opaques du calque directement en dessous. Lorsque vous voulez colorer sans dépasser du trait, activer l’écrêtage sur un calque de coloriage placé au-dessus d’un calque de trait supprime le risque de dessiner accidentellement en dehors des lignes.';

  @override
  String get helpCommonLayerTitle => 'Calque commun';

  @override
  String get helpCommonLayerDesc =>
      'Les calques ordinaires sont indépendants par image, mais un calque commun partage le même contenu sur plusieurs images et scènes. Les éléments qui ne bougent pas d’une image à l’autre, comme les fonds, peuvent être dessinés une seule fois au lieu d’être redessinés à chaque image. Il apparaît comme une piste dédiée dans la timeline. Convertit un calque normal en calque commun (qui continue d’afficher le même contenu sur plusieurs images). Vous pouvez aussi dupliquer les calques actuellement visibles et fusionner les copies en un seul calque avant la conversion. Vous évite de redessiner un élément comme un arrière-plan qui reste identique à chaque image.';

  @override
  String get helpAutoFillTitle => 'Remplissage automatique';

  @override
  String get helpAutoFillDesc =>
      'Crée un calque de remplissage auto sous le calque de trait pour remplissage auto et le colore automatiquement selon un « réglage de remplissage automatique » préétabli (une combinaison de couleurs et de trames par partie). Comme vous pouvez tout colorer en une fois après avoir terminé le trait, cela réduit considérablement l’effort de coloriage dans une animation dessinée à la main où le même personnage est dessiné à répétition. Si vous redessinez le trait, une marque de mise à jour apparaît sur la timeline et le panneau de calques pour vous indiquer que le remplissage automatique doit être réappliqué. Choisir « Exécuter le remplissage automatique » dans le menu à trois points de l’écran timeline recalcule d’un coup tous les calques de remplissage automatique marqués de l’indicateur de mise à jour. Vous évite de le relancer calque par calque dans le panneau des calques après avoir retracé le trait. Chaque partie d’un réglage de remplissage automatique a un réglage pour la gestion de la couleur du trait — une couleur spécifiée, identique à la couleur de remplissage, ou trace de couleur. Choisir la trace de couleur décale la teinte du trait pour correspondre à la couleur de remplissage, afin que le trait ne ressorte pas et se fonde naturellement. À mesure que les réglages s’accumulent, la liste affichée lors de l’attribution des parties s’allonge et devient difficile à parcourir. Depuis les réglages du projet (ou la boîte de dialogue d’attribution des parties dans le panneau des calques), vous pouvez la limiter aux seuls réglages utilisés dans ce projet, gardant la liste claire et facile à choisir. En augmentant « Combler l’écart entre traits et aplat », l’aplat passe plus loin sous le bord adouci des traits et l’écart entre le trait et l’aplat, visible avec un contour ou une couleur de trait identique à l’aplat, se réduit.';

  @override
  String get helpOnionSkinTitle => 'Papier calque';

  @override
  String get helpOnionSkinDesc =>
      'Superpose en semi-transparence les images avant et après celle que vous éditez actuellement, afin que vous puissiez dessiner en vérifiant comment le mouvement s’enchaîne. Vous pouvez ajuster le nombre d’images affichées (avant et après) ainsi que leur couleur et leur opacité dans les réglages de performance.';

  @override
  String get helpRulerTitle => 'Règle';

  @override
  String get helpRulerDesc =>
      'Un guide pour dessiner des lignes précises difficiles à réaliser à main levée, y compris des règles droites, circulaires, elliptiques et de perspective (utilisant des points de fuite pour le dessin en perspective). La pointe du stylet s’aligne automatiquement sur la règle placée, rendant même les compositions avec une profondeur difficile plus faciles à dessiner que sans règle. Les règles peuvent être déplacées, pivotées et redimensionnées à l’aide de leurs poignées. La règle de perspective fish-eye est une perspective curviligne à cinq points : les lignes horizontales et verticales se courbent en arcs dans le cercle de l’objectif et les lignes de profondeur se rejoignent au centre. Chaque trait suit la ligne qui correspond à la direction dans laquelle vous commencez à dessiner ; faites glisser les poignées pour déplacer le centre, changer le rayon (le point à droite du cercle) et l’incliner (le point du haut).';

  @override
  String get helpFadeTitle => 'Fondu';

  @override
  String get helpFadeDesc =>
      'Une fonction de pinceau qui rend la couleur transparente vers le début et la fin du trait. Sur la distance choisie depuis le début, l’opacité monte progressivement de la valeur de début à 100 %, et sur la distance choisie avant la fin, elle descend progressivement de 100 % à la valeur de fin ; entre les deux, le trait est dessiné à l’opacité du pinceau. Vous pouvez estomper uniquement le début, uniquement la fin, ou les deux de façon asymétrique. L’épaisseur du trait ne change pas (pour l’affiner, utilisez l’Effilage). Le stylo de contour n’a pas de fondu.';

  @override
  String get helpTaperTitle => 'Effilage';

  @override
  String get helpTaperDesc =>
      'Une fonction de pinceau qui affine le trait vers le début et la fin. Sur la distance choisie depuis le début, l’épaisseur augmente progressivement de la valeur d’entrée à 100 %, et sur la distance choisie avant la fin, elle diminue progressivement de 100 % à la valeur de sortie ; entre les deux, le trait est dessiné à l’épaisseur du pinceau. La couleur et l’opacité ne changent pas. Même à la souris, sans pression du stylet, vous pouvez dessiner des traits qui s’affinent à l’entrée et à la sortie. Sur les pinceaux dont l’épaisseur suit la pression, il affine encore cette épaisseur ; avec le stylo de contour, il affine toute la forme, contour compris.';

  @override
  String get helpStrokeDecayTitle => 'Atténuation de trait';

  @override
  String get helpStrokeDecayDesc =>
      'Similaire au fondu, mais plus proche de l’effet d’un « encre qui s’épuise » — la couleur s’estompe ou devient irrégulière plus vous continuez à dessiner. Il reproduit la texture d’un pinceau ou d’un marqueur qui manque d’encre à mesure que vous l’utilisez.';

  @override
  String get helpColorMixingTitle => 'Mélange de couleurs';

  @override
  String get helpColorMixingDesc =>
      'En peignant avec un pinceau, mélange la couleur déjà présente sous le pinceau avec la couleur que vous êtes sur le point d’appliquer. Dans le mode de mélange des réglages du pinceau, choisissez Numérique pour peindre sans mélanger, Mélange façon huile pour mélanger comme de la peinture et étirer la couleur ramassée, ou Mélange façon aquarelle pour superposer des lavis de la couleur choisie. Avec le mélange façon aquarelle, la quantité d’eau change la transparence du lavis, la façon dont il se fond dans les couleurs du dessous et jusqu’où il se diffuse.';

  @override
  String get helpPressureCurveTitle => 'Courbe de pression';

  @override
  String get helpPressureCurveDesc =>
      'Une fonctionnalité des réglages de saisie au stylet qui permet d’ajuster librement, via un graphique, la relation entre la pression réelle du stylet et son effet sur la taille et l’opacité du pinceau. Que vous vouliez des lignes épaisses même avec une légère pression, ou l’inverse — nécessitant une pression ferme pour obtenir des lignes épaisses —, vous pouvez personnaliser finement la sensation pour l’adapter à vos habitudes. Vous pouvez essayer de dessiner directement pour vérifier l’effet après avoir modifié les réglages.';

  @override
  String get helpTimelineTitle => 'Timeline';

  @override
  String get helpTimelineDesc =>
      'L’écran de gestion de l’axe temporel de votre animation. Organiser des images (des images fixes individuelles) et les lire comme un folioscope crée l’animation. Les pistes de matériaux texte, image, vidéo et audio, les pistes de calques communs et les images clés de caméra sont toutes gérées sur la même timeline. Ce qui passe devant parmi les textes, les images, les vidéos et le dessin de l’image se règle dans « Ordre d’empilement », pour toute la scène ou pour une plage d’images. Vous pouvez aussi appuyer longuement sur un élément pour en sélectionner plusieurs et les déplacer ensemble.';

  @override
  String get helpPlaybackTitle => 'Lire l’animation';

  @override
  String get helpPlaybackDesc =>
      'Lisez l’animation dans la timeline pour vérifier le mouvement. Ouvrez la timeline avec son bouton en haut à droite du canevas, puis touchez le bouton Lecture de l’aperçu pour lancer la lecture ; touchez-le de nouveau pour la mettre en pause. L’aperçu de l’écran des détails du projet a aussi un bouton Lecture.\nPour l’enregistrer ou la partager en vidéo ou en GIF, utilisez « Exporter ».';

  @override
  String get helpSceneTitle => 'Scène';

  @override
  String get helpSceneDesc =>
      'Divise l’intérieur d’un projet (une vidéo) en scènes (plans) pour les gérer séparément. Alors que les dossiers organisent au niveau du projet, les scènes représentent des changements de scène au sein d’une même vidéo. Dans l’onglet des scènes de la timeline, vous pouvez ajouter, dupliquer, supprimer, renommer et réorganiser les scènes. Passer en mode de sélection multiple permet de déplacer, dupliquer ou supprimer plusieurs scènes à la fois.';

  @override
  String get helpCameraKeyframeTitle => 'Image clé de caméra';

  @override
  String get helpCameraKeyframeDesc =>
      'Enregistre la position, le niveau de zoom et la rotation de la caméra à un point précis de la timeline. Comme les valeurs sont automatiquement interpolées en douceur entre les images clés, vous pouvez facilement ajouter des mouvements de caméra tels que des panoramiques ou des zooms avant/arrière.';

  @override
  String get helpEffectFilterTitle => 'Filtre d’effet';

  @override
  String get helpEffectFilterDesc =>
      'Un effet visuel (flou, correction des couleurs, lueur, pixellisation, etc.) que vous pouvez appliquer à une scène ou une image. Utilisez-le lorsque vous voulez ajuster l’apparence globale de l’écran comme une touche de mise en scène, sans changer le dessin fait main lui-même. Parmi les filtres de dessin, Courbe de tons (un préréglage et son intensité), Niveaux, Netteté, Masque flou, Vignettage (couleur, étendue et densité) et Bord aquarelle existent aussi en filtres d’effet, pour appliquer le même effet à plusieurs images d’un coup. Le filtre pixel art permet aussi de choisir un mode de couleur (sans limite, couleurs spécifiées, nombre de couleurs spécifié, ou choix depuis une palette). Quand les couleurs sont limitées, les zones dont aucune couleur permise n’est proche sont faites de deux ou trois couleurs permises selon un motif régulier (tramage) qui reste en place d’une image à l’autre ; les contours restent nets. Le tramage peut être désactivé pour remplir chaque point de la couleur la plus proche. Plusieurs filtres d’effet peuvent être superposés, et ils s’appliquent dans l’ordre où ils apparaissent sur la timeline. Glisser pour réorganiser la liste des filtres change aussi l’ordre réellement appliqué à l’écran. Un filtre d’effet qui applique un bruit façon grain de pellicule, en le faisant changer image par image. Intensité, quantité (densité du bruit) et taille du grain se règlent avec des curseurs. Revenir à la même image reproduit le même grain (pas de scintillement en scrubbing), tandis que la lecture donne l’impression que le grain bouge. Un filtre d’effet qui fait tomber de la pluie à l’écran. Intensité (nombre de gouttes), vitesse, taille des gouttes et angle du vent se règlent avec des curseurs. Chaque goutte continue de tomber à une vitesse constante à mesure que l’image avance, pour un mouvement de pluie naturel.';

  @override
  String get helpEndCardTitle => 'Marque de fin';

  @override
  String get helpEndCardDesc =>
      'La marque de fin NIARIM de cinq secondes est ajoutée aux exports MP4, WebM et AVI, vidéos du making-of comprises. Les GIF reçoivent à la place l’icône et le nom de NIARIM en petit dans un coin. Vous pouvez les masquer par projet tant que l’avantage est actif. Le réglage est conservé après expiration.';

  @override
  String get helpAutoSaveTitle => 'Enregistrement automatique';

  @override
  String get helpAutoSaveDesc =>
      'NIARIM conserve jusqu’à 3 sauvegardes automatiques pendant le montage. Si le fichier du projet est endommagé, NIARIM le récupère automatiquement depuis la sauvegarde automatique lisible la plus récente. Dans la liste, passez des sauvegardes automatiques aux sauvegardes manuelles (emplacements ou arbre) pour choisir la version à charger.';

  @override
  String get saveDataManualTab => 'Sauvegardes manuelles';

  @override
  String get saveDataAutosavesEmpty =>
      'Ce projet n’a pas encore de sauvegarde automatique.';

  @override
  String projectAutosaveRecovered(String time) {
    return 'Le fichier du projet était endommagé ou introuvable. Il a été restauré depuis la sauvegarde automatique la plus récente ($time). Vous pouvez aussi choisir d’autres données enregistrées à charger.';
  }

  @override
  String get projectAutosaveRecoveredTitle =>
      'Impossible d’ouvrir le fichier du projet';

  @override
  String get projectAutosaveRecoveredContinue => 'Continuer avec cette version';

  @override
  String get autosaveRecoveryChooseData => 'Choisir les données à charger';

  @override
  String get helpSaveSlotTitle => 'Emplacement de sauvegarde';

  @override
  String get helpSaveSlotDesc =>
      'Une méthode d’enregistrement dans un nombre fixe d’emplacements de sauvegarde, où vous choisissez à chaque fois l’emplacement à utiliser. Le nombre d’emplacements est déterminé par les réglages (5 pour la qualité basse, 10 pour la qualité moyenne). Comme vous choisissez à chaque fois l’emplacement à écraser, c’est un moyen simple de gérer la conservation de l’état d’un moment particulier.';

  @override
  String get helpSaveTreeTitle => 'Arbre de sauvegarde';

  @override
  String get helpSaveTreeDesc =>
      'Une méthode d’enregistrement où un nouveau point de sauvegarde est créé à chaque fois que vous enregistrez, et vous pouvez créer une branche à partir d’un point de sauvegarde passé pour créer un historique différent. Il n’y a pas de limite au nombre d’enregistrements, ce qui le rend bien adapté à des cas d’usage comme « je veux revenir à cette version et essayer une direction différente ». À l’écran, les points de sauvegarde sont affichés sous forme d’un diagramme en arbre qui pousse du bas vers le haut.';

  @override
  String get helpFolderTitle => 'Dossier';

  @override
  String get helpFolderDesc =>
      'Une fonctionnalité pour regrouper et organiser vos projets (œuvres). Elle prend en charge plusieurs niveaux d’imbrication, vous pouvez donc aussi l’utiliser pour gérer ensemble plusieurs épisodes ou une série de la même œuvre (par exemple, en organisant les projets « Épisode 1 », « Épisode 2 », etc. dans un dossier nommé d’après l’œuvre). Si vous voulez diviser une seule vidéo en scènes distinctes, utilisez la fonctionnalité « Scène » de l’écran du canevas plutôt que des dossiers.';

  @override
  String get helpTrashTitle => 'Corbeille';

  @override
  String get helpTrashDesc =>
      'L’endroit où les projets supprimés sont temporairement déplacés. Vous pouvez les restaurer d’ici jusqu’à ce qu’ils soient définitivement supprimés. Vous pouvez définir le nombre de jours avant la suppression automatique (désactivée/30/60/90 jours) dans les réglages.';

  @override
  String get helpShareTitle => 'Partage (.niashare)';

  @override
  String get helpShareDesc =>
      'Un format de fichier dédié pour remettre un projet à quelqu’un d’autre (ou à un autre de vos appareils). Lorsque le destinataire ouvre ce fichier, il est dupliqué et ajouté à sa propre liste de projets. Le fichier .niashare d’origine lui-même n’est pas modifié.';

  @override
  String get helpTransferTitle => 'Transfert (.niatra)';

  @override
  String get helpTransferDesc =>
      'Une fonctionnalité permettant de transférer tout l’environnement de l’application — réglages, matériaux, pinceaux, réglages de remplissage automatique, thème, palettes (sélecteur de couleurs et pixel art), et plus — vers un autre appareil en une seule fois. Vous pouvez choisir les éléments individuels à transférer avec des cases à cocher, et inclure en option des projets en cours (les projets sélectionnés sont transférés en entier, avec leurs matériaux et polices). Si vous voulez seulement remettre un projet individuel, vous pouvez aussi utiliser « Partage (.niashare) ».';

  @override
  String get helpVideoExportTitle => 'Export vidéo (MP4, WebM, GIF, AVI)';

  @override
  String get helpVideoExportDesc =>
      'Exportez en MP4, WebM, GIF ou AVI. L’offre gratuite permet de prolonger un projet jusqu’à 90 secondes. L’export intégral d’un projet de plus de 90 secondes nécessite Premium ou l’avantage de durée étendue. Vous pouvez aussi exporter les 90 premières secondes. Changer la cadence d’export conserve la durée de lecture de l’œuvre. Avant l’export, vous pouvez vérifier la durée et la présence de la marque de fin. Les sons de la timeline et le son des matériaux vidéo sont inclus dans les fichiers MP4, WebM et AVI (le GIF n’a pas de son).';

  @override
  String get helpTransparentWebmTitle => 'WebM transparent';

  @override
  String get helpCommunityTitle => 'Place des œuvres';

  @override
  String get helpCommunityDesc =>
      'Publiez vos animations et illustrations dans la communauté sous forme de vidéos YouTube, et parcourez les œuvres des autres utilisateurs. Basculez entre les onglets « Nouveautés », « Classement », « Abonnements », « Recherche » et « Favoris ». Dans l’onglet « Recherche », effectuez une recherche par titre d’œuvre ou nom du créateur, ou passez en mode recherche par tag pour filtrer les œuvres par tag. N’importe quel utilisateur (pas seulement le créateur) peut ajouter ou retirer des tags, mais un tag verrouillé par le créateur ne peut être retiré que par lui. Sur l’écran de détails d’une œuvre, touchez un tag puis « Rechercher ce tag » pour trouver les œuvres portant le même tag.\nToucher une carte d’œuvre ouvre une fenêtre d’aperçu flottante déplaçable et redimensionnable, pour continuer à naviguer sur d’autres écrans pendant la lecture. Le bouton « Détails » ouvre l’écran de détails de l’œuvre (créateur, date de publication, modification des tags, mise en favori, repartage, etc.). Toucher le bouton « Suivre » à côté du nom d’un créateur l’ajoute à vos abonnements : l’onglet « Abonnements » regroupe alors, des plus récentes aux plus anciennes, uniquement les publications des créateurs que vous suivez. Vous seul pouvez consulter les listes des personnes que vous suivez, de vos abonnés et des œuvres que vous avez mises en favori. Les autres utilisateurs ne voient que le nombre d’abonnements et d’abonnés. Suivre une personne, mettre une œuvre en favori ou la repartager ne déclenche aucune notification individuelle à l’autre utilisateur concernant cette action. Vous pouvez repartager l’œuvre de n’importe qui d’autre (sauf la vôtre) avec le bouton « Repartager » ; lorsqu’un créateur que vous suivez repartage l’œuvre de quelqu’un d’autre, cette œuvre apparaît aussi dans votre onglet « Abonnements », triée selon la date la plus récente — sa date de publication d’origine ou sa date de repartage (la carte affiche « Repartagé par… »). Les œuvres mises en favori apparaissent regroupées dans l’onglet « Favoris » de la Place des œuvres, ainsi que dans l’onglet « Favoris » de votre propre page de créateur. Vous pouvez signaler des œuvres ou des comptes. Le masquage agit sur votre affichage seulement. Le blocage agit sur l’affichage des deux comptes lorsqu’ils sont connectés : chacun ne voit plus les publications de l’autre. Les vidéos verticales peuvent être visionnées en « mode vertical », qui les enchaîne comme un flux de vidéos courtes.\nLe nombre de publications par jour est limité : 1 par jour pour les membres gratuits, 3 par jour pour les membres Premium. Le bouton « Filtres d’affichage », au-dessus de la liste, permet de masquer les œuvres marquées « Contient des images ou vidéos générées par IA ». Le bouton « Paramètres de masquage » en haut à droite (l’icône d’œil barré) permet d’ajouter des mots masqués (comparés uniquement au titre de l’œuvre) et des tags masqués (comparés uniquement aux tags de la Place des œuvres), un par un avec « Ajouter ». Modifiez avec le crayon ou supprimez avec la corbeille ; aucune virgule ni # nécessaire. Ces filtres s’appliquent aux onglets « Nouveautés », « Classement » et « Abonnements » (repartages compris), au mode vertical, aux pages des créateurs, aux détails des œuvres et aux favoris. La mention « Contient des images ou vidéos générées par IA » est déclarée par l’auteur au moment de la publication, et lui seul peut la modifier ensuite (depuis « Mes publications » ou l’écran de détails de l’œuvre).';

  @override
  String get helpWatermarkEntryTitle => 'Filigrane';

  @override
  String get helpWatermarkEntryDesc =>
      'Ajoutez une signature ou un logo en texte ou en image. L’avantage est requis pour l’ajout et la modification. Les filigranes déjà placés restent exportables.';

  @override
  String get helpPremiumEntryTitle => 'Premium';

  @override
  String get helpPremiumEntryDesc =>
      'Tant que l’avantage de durée étendue est actif, vous pouvez créer et exporter jusqu’à deux heures. À l’expiration, le projet est conservé et ses 90 premières secondes peuvent être exportées avec les corrections de couleur et autres réglages appliqués. La marque de fin dépend de l’avantage actif au début de l’export.';

  @override
  String get helpPremiumExpiryTitle => 'À l’expiration des avantages';

  @override
  String get helpPremiumExpiryDesc =>
      'L’export intégral d’un projet de plus de 90 secondes nécessite Premium ou l’avantage de durée étendue. Vous pouvez exporter les 90 premières secondes. La limite de 90 secondes s’applique à l’ajout ou à la duplication d’images. Tant que l’historique est disponible, Annuler et Rétablir permettent de récupérer des images supprimées. Après expiration de l’avantage lié à la marque de fin, les nouvelles exportations MP4, WebM et AVI se terminent par cinq secondes de logo NIARIM. Les GIF et les fichiers déjà exportés sont préservés. Les conditions de départ s’appliquent jusqu’à la fin de l’exportation. Les filigranes posés, les corrections appliquées et les résultats des automatisations sont conservés. Un avantage actif est nécessaire pour relancer une automatisation enregistrée.';

  @override
  String get helpOpalRewardsTitle => 'Opales et bonus';

  @override
  String get helpOpalRewardsDesc =>
      'Gagnez des opales en accomplissant des missions et en regardant des publicités, puis échangez-les contre des avantages. Ouvrez le menu (trois traits) en haut à droite de l’accueil et choisissez « Opales et bonus ». Pour voir votre solde et gagner des opales, connectez-vous avec votre compte Google. Les abonnés Premium peuvent aussi cumuler des opales.\nDans l’onglet « Missions », récupérez les missions accomplies avec « Réclamer » ou « Tout réclamer ». Les « Bonus de connexion cumulés » donnent des opales chaque jour et des bonus selon le total de vos jours de connexion. Les « Missions de la semaine et du mois » s’accomplissent selon le nombre de jours où vous vous connectez dans la semaine ou le mois, et les « Missions de temps sur la Place des œuvres » comptent le temps passé avec la Place des œuvres ouverte, à l’heure du Japon (aucune lecture ni action requise). Il existe aussi des missions pour la publication d’œuvres, les favoris, les repartages, les abonnés et le classement des favoris.\nDans l’onglet « Voir des pubs pour des opales », regardez des publicités récompensées pour gagner des opales. Le nombre de publicités pouvant être lues dépend notamment de leur disponibilité. Dans l’onglet « Échanger des avantages », choisissez des avantages et une durée pour voir le total d’opales nécessaires, puis échangez-les avec « Échanger les opales ». Vous pouvez aussi choisir le « Pack complet d’avantages (comme l’abonnement Premium) ». Avant l’échange, « Vérifier les doublons et l’expiration » permet de vérifier les avantages qui se recoupent et les dates d’expiration. « Historique des opales », dans la zone du solde, montre les opales reçues et dépensées.\nDans la zone du solde des onglets « Voir des pubs pour des opales » et « Échanger des avantages », « Actualiser le solde » recharge votre solde. « Saisir un code promo » permet de saisir un code promo pour recevoir des opales (majuscules, minuscules, espaces et tirets sont ignorés). La « Boîte à cadeaux » permet de recevoir les cadeaux de l’équipe NIARIM.';

  @override
  String get helpPerformanceSettingsTitle => 'Réglages de performance';

  @override
  String get helpPerformanceSettingsDesc =>
      'Choisissez parmi les préréglages de qualité basse, moyenne ou haute selon les capacités de votre appareil, ou configurez chaque élément individuellement (personnalisé). En plus de la méthode d’enregistrement, des performances, du papier calque et de la détection d’inclinaison, les réglages qui affectent la taille de l’application et sa fluidité — comme la longueur de l’historique d’annulation et la suppression automatique de la corbeille — sont également regroupés ici.';

  @override
  String get helpMaterialClipTitle =>
      'Clips de matériaux (texte / image / vidéo / audio)';

  @override
  String get helpMaterialClipDesc =>
      'Clips placés sur les pistes texte, image, vidéo et audio de la timeline. Un appui long avec glisser sur le corps du clip déplace sa position de départ, et glisser les poignées à chaque extrémité change la portion utilisée. Les matériaux affichés en même temps sont placés automatiquement sur des pistes distinctes. Toucher un clip texte, image ou vidéo ouvre son panneau d’édition sous l’aperçu : le texte, la police, la couleur et le contour ; la position, l’échelle, la rotation sur les axes X/Y/Z et l’opacité (on peut aussi le faire glisser sur l’aperçu, et ajouter des images clés le fait bouger) ; son masque (rectangle ou ellipse, adouci, inversé) ; et la piste où il se trouve. On peut aussi le dupliquer ou le supprimer. Le volume et les fondus d’un clip audio se règlent dans sa fiche détaillée.';

  @override
  String get helpGestureSettingsTitle => 'Réglages des gestes';

  @override
  String get helpGestureSettingsDesc =>
      'Permet d’associer des actions — annuler/rétablir, changement d’image, pipette et plus — à un appui à deux doigts, un appui à trois doigts, un glissement à deux doigts ou un appui long. Les boutons du stylet (sur les modèles compatibles) peuvent aussi être associés séparément. Pratique pour lancer aussitôt les actions que vous utilisez souvent, sans ouvrir de menu.';

  @override
  String get helpBucketDetailSettingsTitle =>
      'Réglages détaillés du pot de peinture';

  @override
  String get helpBucketDetailSettingsDesc =>
      'Depuis la section « Pot de peinture » des réglages, vous pouvez ajuster la tolérance (quelle différence de couleur par rapport au pixel cliqué compte encore comme la même zone), l’extension en px (de combien la zone remplie dépasse la bordure pour combler les écarts du trait) et le remplissage sous le trait (compose le remplissage étendu derrière les pixels existants au lieu de peindre par-dessus le trait, préservant son apparence). Les ajuster aide quand le trait a de petits écarts ou que le remplissage semble incomplet.';

  @override
  String get helpStampToolTitle => 'Outil tampon';

  @override
  String get helpStampToolDesc =>
      'Place une image enregistrée sur le canevas comme un pinceau afin de réutiliser lignes de vitesse, motifs de fond et petits objets sans les redessiner. En mode pixel, les tampons utilisent le même traitement Pixel Art que le filtre pixel art, en conservant des bords de transparence nets pendant la pixellisation et la réduction des couleurs. Mosaïque est un effet distinct et n’est pas utilisé par le mode pixel du tampon. Le panneau permet aussi de régler la rotation et la taille.';

  @override
  String get helpToneFillTitle => 'Remplissage en trame';

  @override
  String get helpToneFillDesc =>
      'Passer le réglage de l’outil pot de peinture du remplissage uni au remplissage en trame permet de remplir avec une trame de demi-teintes ou de lignes choisie. Des trames en damier et en grille réservées au mode pixel sont aussi disponibles, pour des remplissages assortis à une texture pixel art. Idéal pour les volants, le tricot, les collants et autres motifs fins fastidieux à dessiner à la main. Vous pouvez aussi créer et ajouter vos propres trames personnalisées, ou les partager avec d’autres utilisateurs. La liste regroupe les trames de points, les lignes, les motifs textiles et les motifs pixel. Le nom des trames de dithering indique le grain, la taille de la matrice et la couverture.';

  @override
  String get helpPixelModeTitle => 'Mode pixel';

  @override
  String get helpPixelModeDesc =>
      'Un réglage disponible séparément sur les pinceaux, les polices et les tampons. L’activer supprime l’anticrénelage pour des contours nets façon pixel art. À utiliser pour un rendu volontairement rétro ou basse résolution. Vous pouvez choisir parmi quatre modes de couleur : sans limite de couleur, couleurs spécifiées, nombre de couleurs spécifié, ou choix depuis une palette, y compris une palette dédiée au pixel art.';

  @override
  String get helpHomeScreenTitle => 'Écran d’accueil';

  @override
  String get helpHomeScreenDesc =>
      'Le premier écran affiché au lancement de l’app, avec les onglets Projets, Partagés, Œuvres et Corbeille. L’icône de recherche en haut à droite permet de filtrer les projets par nom. Sur l’onglet Projets, le bouton flottant permet de choisir entre créer un nouveau projet ou un nouveau dossier.';

  @override
  String get helpNewProjectTitle => 'Nouveau projet';

  @override
  String get helpNewProjectDesc =>
      'Définissez la taille du canevas, la cadence (i/s), la durée (en secondes — ensuite maintenue synchronisée avec les changements d’images faits dans la timeline), la zone de dessin (permet de dessiner au-delà des limites d’export) et les réglages de remplissage automatique à utiliser, le tout avant de créer le projet.';

  @override
  String get helpThemeSettingsTitle => 'Réglages de thème';

  @override
  String get helpThemeSettingsDesc =>
      'Choisissez la palette de l’application dans la liste des thèmes. Personnalisez six couleurs de base ou utilisez les réglages avancés pour définir séparément la couleur du texte des menus, de la sélection et d’autres éléments. Les titres/libellés et le texte courant utilisent des polices distinctes, ce qui permet de changer l’apparence de l’app tout en gardant une bonne lisibilité.';

  @override
  String get helpWorkspaceSettingsTitle => 'Réglages de l’espace de travail';

  @override
  String get helpWorkspaceSettingsDesc =>
      'Regroupe des réglages comme le mode gaucher (inverse les panneaux ancrés), le basculement manuel du mode PC/DeX, et les conditions d’affichage de l’outil main. Ajustez la disposition selon votre appareil et votre main dominante.';

  @override
  String get helpPenSettingsTitle => 'Réglages du stylet';

  @override
  String get helpPenSettingsDesc =>
      'En plus de la courbe de pression pour tablettes et écrans à stylet, cet écran permet d’associer des actions — comme basculer la gomme ou la pipette — aux boutons latéraux d’un stylet compatible. Vous pouvez aussi y régler l’intensité de la stabilisation, qui s’applique de la même façon à tous les pinceaux.';

  @override
  String get helpMaterialListTitle => 'Liste des matériaux';

  @override
  String get helpMaterialListDesc =>
      'Un écran qui rassemble les images, vidéos et audios utilisés dans un projet. Il regroupe les fichiers source de tout ce qui est placé sur la timeline.';

  @override
  String get helpFrameOperationsTitle => 'Opérations sur les images';

  @override
  String get helpFrameOperationsDesc =>
      'Dans la liste des images, vous pouvez ajouter, dupliquer et supprimer des images, et en mode sélection multiple en déplacer, dupliquer ou supprimer plusieurs à la fois. Augmenter le nombre de maintien garde une même image affichée sur plusieurs cellules (un « maintien »), économisant du travail de dessin sur les plans avec peu de mouvement. Dans la liste des images du canevas, appuyez longuement sur une image pour la dupliquer, la supprimer ou changer ses images de maintien.';

  @override
  String get helpSceneOperationsTitle => 'Opérations sur les scènes';

  @override
  String get helpSceneOperationsDesc =>
      'L’onglet scènes de la timeline permet d’ajouter, dupliquer, supprimer, renommer et réorganiser les scènes. Le mode sélection multiple permet de déplacer, dupliquer ou supprimer plusieurs scènes à la fois.';

  @override
  String get helpQuickToolManagementTitle => 'Gestion des outils rapides';

  @override
  String get helpQuickToolManagementDesc =>
      'Enregistrez un ensemble d’outils fréquemment utilisés pour les faire défiler d’un seul appui. Ouvrez le popup de gestion par un appui long ou un glissement vers le haut pour modifier les outils enregistrés et leur ordre.';

  @override
  String get helpTransformSelectionTitle => 'Transformer une sélection';

  @override
  String get helpTransformSelectionDesc =>
      'Une zone délimitée avec l’outil de sélection se transforme en choisissant Déplacer, Redimensionner ou Pivoter dans les boutons en bas à gauche du canevas, puis en faisant glisser à l’intérieur de la sélection. Pratique pour repositionner une partie dessinée par erreur, ou pour agrandir une seule zone afin de la mettre en valeur. Le bouton Tout sélectionner de la même barre sélectionne tout le calque courant : vous pouvez donc déplacer, pivoter et redimensionner un calque entier de la même façon (l’ancien outil de transformation a été fusionné ici). Pour déformer plus librement en faisant glisser individuellement les points de la grille, utilisez Transf. libre ou Maillage sur la même barre.';

  @override
  String get helpGradientAutofillTitle =>
      'Remplissage en dégradé (réglages de remplissage automatique)';

  @override
  String get helpGradientAutofillDesc =>
      'Chaque partie d’un réglage de remplissage automatique peut utiliser un dégradé au lieu d’une couleur unie. Des poignées symétriques déplaçables par glisser permettent d’ajuster intuitivement l’étendue et l’angle du dégradé. Chaque partie peut aussi activer « Contour avec une couleur définie ». Une fois coché, un trait de la couleur et de l’épaisseur choisies est dessiné tout au bord extérieur de la zone remplie (juste contre le dessin au trait). La couleur du contour se choisit librement dans le sélecteur de couleur, et l’épaisseur s’ajuste via le curseur, les boutons ± ou en touchant le nombre pour le saisir directement. Un aperçu s’affiche juste au-dessus des réglages, permettant de vérifier la couleur et l’épaisseur avant d’exécuter le remplissage automatique.';

  @override
  String get helpColorPickerTitle => 'Sélecteur de couleur';

  @override
  String get helpColorPickerDesc =>
      'Un sélecteur de couleur qui permet de basculer entre HSV et RGB sur un seul écran. La fonction palette permet d’enregistrer et de rappeler l’ensemble de couleurs utilisé. Les palettes peuvent aussi être partagées avec d’autres appareils via l’export de fichier ou un code QR.';

  @override
  String get helpUndoSettingsTitle => 'Longueur de l’historique d’annulation';

  @override
  String get helpUndoSettingsDesc =>
      'Dans les réglages de performance, vous pouvez ajuster le nombre d’actions que l’annulation peut remonter. Un nombre plus élevé donne plus de liberté pour expérimenter, mais utilise aussi plus de mémoire — réduisez-le sur les appareils bas de gamme pour rester fluide.';

  @override
  String get helpBrushFavoriteTitle => 'Pinceaux favoris';

  @override
  String get helpBrushFavoriteDesc =>
      'Touchez l’icône étoile d’un pinceau dans la liste pour le mettre en favori ou l’en retirer (la même interaction que pour les favoris dans le reste de l’app — réglages de remplissage automatique, tampons, polices, filtres de dessin, etc.). L’icône étoile en haut de la liste permet aussi de filtrer pour n’afficher que les favoris. Un pinceau en favori ne peut pas être supprimé par erreur.';

  @override
  String get helpCustomBrushTitle => 'Pinceaux personnalisés';

  @override
  String get helpCustomBrushDesc =>
      'Appuyez longuement sur un pinceau préinstallé dans la liste et choisissez « Dupliquer » pour créer votre propre pinceau personnalisé à partir de celui-ci. Les pinceaux dupliqués peuvent être librement modifiés (épaisseur, opacité, dureté, rotation, densité, dispersion, rayon de flou, etc.) et supprimés lorsqu’ils ne sont plus utiles (les pinceaux préinstallés eux-mêmes ne peuvent être ni modifiés ni supprimés). L’épaisseur et l’opacité réglées avec les curseurs du canevas sont mémorisées pour chaque pinceau, y compris les pinceaux préinstallés, que vous pouvez rétablir à leurs valeurs par défaut depuis le menu du pinceau dans la liste. Vous pouvez aussi les classer dans des dossiers et les marquer comme favoris avec l’icône étoile.';

  @override
  String get helpLayerFolderTitle => 'Dossiers de calques';

  @override
  String get helpLayerFolderDesc =>
      'Permet d’organiser plusieurs calques dans un dossier. Garde le panneau des calques lisible même pour des illustrations avec beaucoup de parties. L’écrêtage ne peut pas traverser les limites d’un dossier, donc si vous l’utilisez, gardez les calques concernés dans le même dossier.';

  @override
  String get helpLayerMultiSelectTitle =>
      'Sélection multiple et actions groupées sur les calques';

  @override
  String get helpLayerMultiSelectDesc =>
      'Le mode de sélection du panneau des calques permet de cocher plusieurs calques à la fois pour les fusionner ou les supprimer en masse. La fusion ne fonctionne qu’entre calques normaux, de trait de remplissage automatique et de remplissage automatique (les calques communs, dossiers et matériaux de la timeline ne peuvent pas être fusionnés).';

  @override
  String get helpDrawingAreaTitle => 'Zone de dessin';

  @override
  String get helpDrawingAreaDesc =>
      'Permet de dessiner au-delà des limites d’export. Un cadre rouge sur le canevas marque la zone d’export — ce qui est dessiné en dehors n’est pas exporté, mais cela laisse de la marge pour ajuster plus tard ce qui est montré via des mouvements de caméra comme le panoramique et le zoom. Définissez l’échelle à la création d’un nouveau projet.';

  @override
  String get helpCanvasBackgroundTitle => 'Couleur de fond du canevas';

  @override
  String get helpCanvasBackgroundDesc =>
      'Permet de définir la couleur de fond du canevas du projet. Elle n’affecte pas les exports transparents (WebM transparent), mais vous pouvez la changer pour celle qui vous convient le mieux pour travailler.';

  @override
  String get helpProjectDetailTitle => 'Écran des détails du projet';

  @override
  String get helpProjectDetailDesc =>
      'Un écran pour consulter et modifier au même endroit les réglages propres au projet — nom, miniature, statut favori, et quels réglages de remplissage automatique sont activés. L’accès à l’arbre de sauvegarde se trouve aussi ici.';

  @override
  String get helpWatermarkEditTitle => 'Rééditer un filigrane';

  @override
  String get helpWatermarkEditDesc =>
      'Modifiez l’angle, la taille, l’opacité et la plage dans la piste des calques communs de la timeline. Même après la fin de l’avantage, les filigranes déjà placés restent dans les projets et les exports. Un avantage actif est requis pour modifier ces réglages.';

  @override
  String get helpAudioClipTitle => 'Volume';

  @override
  String get helpAudioClipDesc =>
      'Un clip audio placé sur la timeline peut avoir son volume et ses durées de fondu d’entrée et de sortie ajustés depuis sa fiche détaillée. Utile pour équilibrer le volume des effets sonores et de la musique, ou adoucir le début et la fin d’un morceau.';

  @override
  String get helpPenSubToolTitle => 'Plume';

  @override
  String get helpPenSubToolDesc =>
      'Un appui long sur l’outil plume le fait passer du dessin normal aux sous-outils de remplissage en trame ou de placement de tampon. Permet de passer d’une tâche à l’autre avec la même plume sans changer d’outil sans arrêt.';

  @override
  String get helpTiltDetectionTitle => 'Détection d’inclinaison';

  @override
  String get helpTiltDetectionDesc =>
      'Un réglage qui utilise les données d’inclinaison d’un stylet compatible pour épaissir ou affiner le trait quand vous couchez la pointe, reproduisant une sensation plus proche d’un vrai outil de dessin. Activez-le ou désactivez-le depuis les réglages de performance.';

  @override
  String get helpFontImportTitle => 'Import de polices';

  @override
  String get helpFontImportDesc =>
      'Permet de charger un fichier de police directement depuis le stockage de l’appareil. Ajoutez-le depuis l’onglet « Importer » de la gestion des polices, dans les réglages. Pratique pour utiliser une police personnalisée non distribuée, ou une police commerciale achetée.';

  @override
  String get helpExportScreenTitle => 'Écran d’export';

  @override
  String get helpExportScreenDesc =>
      'Dans « Préréglage », choisissez « Standard », « Haute qualité » ou « Personnalisé ». Le mode « Personnalisé » permet de régler les images par seconde (i/s). Affiche la progression pendant l’export d’une vidéo ou d’une image, et permet d’annuler en cours de route. Le temps nécessaire dépend des performances de l’appareil. Dans Œuvres, sur l’écran d’accueil, recherchez le fichier par le nom du projet. Choisissez Partager pour l’enregistrer dans une app photo ou l’ouvrir dans une autre application.';

  @override
  String get helpDrawingFilterTitle => 'Filtres de dessin';

  @override
  String get helpDrawingFilterDesc =>
      'Filtres appliqués directement au calque sélectionné (contrairement aux filtres d’effet, qui s’appliquent à toute la timeline ou à une scène, les filtres de dessin agissent par calque). Les 26 filtres inclus sont Flou gaussien, Flou d’objectif, Style anime, Courbe de tons, Niveaux, Contour, Netteté, Masque flou, Vignettage, Anime rétro, Tube cathodique, Seuil, Œil de poisson, Aberration chromatique, Distorsion de lentille, Pixel art, Changement de texture, Fondu d’arrière-plan, Accumulation d’encre, Encrage automatique, Prisme, Inverser les couleurs, Mosaïque, Bruit, Ombrage sphérique et Bord aquarelle. Bord aquarelle accumule la couleur uniquement sur les bords de ce qui est peint sur le calque de travail et les intensifie, comme une aquarelle sèche (à l’intérieur des bords, la peinture reste telle quelle. Avec « Aussi aux limites de couleur », les limites entre couleurs voisines reçoivent aussi un bord). Style anime réduit les couleurs et trace un trait de l’« Épaisseur de bordure » du côté le plus sombre de chaque limite où les couleurs voisines diffèrent d’au moins le « Seuil de différence de couleur » (les traits du dessin ne s’épaississent pas). Prisme peint chaque forme du calque avec les six couleurs de l’arc-en-ciel (rouge, vert, cyan, bleu, violet, rouge), la floute et passe le calque en mode Densité linéaire -. Dessinez d’abord sur leur propre calque de petites formes fines comme des feuilles, d’une couleur sombre : vous obtenez de doux reflets arc-en-ciel sur votre dessin (l’Intensité du flou se mesure comme un flou gaussien ordinaire). L’Ombrage sphérique applique une couleur de lumière à l’intérieur d’une lumière elliptique et une couleur d’ombre à l’extérieur, uniquement sur le dessin (la position et la taille de la lumière se règlent aussi en la faisant glisser sur le canevas). Contour ne réécrit pas le calque d’origine : il dessine seulement le résultat sur un nouveau calque. Distorsion de lentille applique une déformation localisée, comme à travers un verre de lunettes puissant, uniquement sur la zone peinte sur le canevas avec le « Pinceau » et le « Pot de peinture » du panneau (corrigée avec la « Gomme » ; elle part de la sélection ou du calque de sélection s’il y en a un). Lorsque le canevas comporte une sélection, les filtres de dessin ne s’appliquent qu’à l’intérieur. Pixel art permet aussi de choisir un mode de couleur (sans limite, couleurs définies, nombre de couleurs ou palette). Quand les couleurs sont limitées, les zones dont aucune couleur permise n’est proche sont faites de deux ou trois couleurs permises disposées selon un motif régulier (tramage) qui se rapproche davantage de l’original ; les contours restent nets. Avec un nombre de couleurs, celles-ci sont prises parmi ce qui compose la plus grande partie de l’image. Le tramage peut être désactivé pour remplir chaque point de la couleur la plus proche. Sa taille se règle par la taille des blocs (100 crans, de 1 à 100) ou par des curseurs de points en largeur et en hauteur (1 tout à gauche, la taille du canevas tout à droite) ; déplacer l’un déplace l’autre en gardant les proportions du dessin, et les deux réglages restent liés. Dans les deux cas, les points restent carrés, sans bord semi-transparent. L’Encrage automatique permet de modifier les points de contrôle vectoriels temporaires avant d’appliquer le filtre. Faites glisser un point pour déplacer uniquement ce point. Choisissez « Ajouter un point de contrôle » à côté d’Appliquer et touchez une ligne pour ajouter un point, ou choisissez « Supprimer un point de contrôle » et touchez un point pour le supprimer (sans aucun des deux choisi, toucher un point demande confirmation avant de le supprimer). La géométrie modifiée est utilisée directement dans le résultat appliqué, et le déplacement, l’ajout ou la suppression de points peuvent être annulés et rétablis un par un avec Annuler et Rétablir de l’éditeur de filtres. Sur la Courbe de tons, touchez une zone vide pour ajouter un point, faites glisser un point pour le déplacer et appuyez longuement dessus pour le supprimer ; les courbes R, G et B s’appliquent après la courbe RGB. Les Niveaux se règlent aussi séparément pour R, G et B, et le Gamma modifie les tons moyens. L’« Empiètement vers l’intérieur » du contour élargit le bord vers l’intérieur de la forme d’origine, et le nouveau calque du contour est placé juste sous le calque d’origine. L’aberration chromatique permet de répartir le décalage entre X (horizontal), Y (vertical) et Z (vers l’extérieur depuis le centre). Le centre et le rayon de l’œil de poisson se déplacent aussi sur le canevas, avec le + et la poignée du cercle. Vignettage assombrit doucement les quatre coins de tout le canevas (les zones transparentes non dessinées reçoivent aussi l’ombre). La « Portée » règle jusqu’où il s’étend des coins vers le centre, et l’« Intensité » à quel point les coins s’assombrissent. Distorsion de lentille fonctionne comme de vraies lunettes à forte correction : ce que l’on voit à travers le verre rétrécit uniformément vers son centre (valeurs négatives, pour la myopie) ou s’agrandit (valeurs positives, pour l’hypermétropie), et le contour se décale en marche au bord du verre. Accumulation d’encre ne se forme qu’à l’intérieur des angles où les traits se rejoignent à l’« Angle maximal » ou moins (à 90°, la valeur initiale, les angles aigus et droits : un V, le côté étroit d’un croisement, une jonction en T, un coin carré), jamais dans les angles plus ouverts : au point de rencontre elle a l’« Épaisseur centrale » depuis le bord du trait, puis s’affine en ligne droite jusqu’à disparaître en une pointe douce au bout de la « Plage » (même avec une grande « Épaisseur centrale », elle ne bombe jamais au-delà de la droite qui relie les extrémités des deux accumulations : au maximum, le milieu reste plat) ; si un trait s’arrête avant, l’accumulation le long de ce trait s’affine jusqu’à disparaître là où il s’arrête, si bien que chaque trait peut avoir sa propre longueur, et les deux accumulations se rejoignent tout de même au milieu de l’angle, aussi épaisses depuis l’un que depuis l’autre trait (celle du trait le plus long continue ensuite de s’affiner jusqu’au bout de la plage). Encrage automatique suit le milieu des traits du brouillon et les dessine fins. Les traits proches l’un de l’autre restent des traits distincts tant qu’un espace les sépare ; seules les petites taches de papier à l’intérieur d’un trait sont comblées. Là où deux traits se rejoignent, ils se rapprochent peu à peu comme dans le brouillon, au lieu de devenir un seul trait au milieu. Là où des traits se croisent ou se superposent, chacun continue comme dans le brouillon (il ne se plie pas vers le croisement et deux traits superposés ne se fondent pas en un seul). Les traits qui se croisent en biais continuent tout droit à travers le croisement, et ceux qui ne font que se toucher (comme le contour des cheveux tracé le long de la tête) restent des traits distincts, chacun de son côté. Les points, comme les yeux, restent des points pleins. Les branches plus courtes que l’« Épaisseur du brouillon » ne sont pas dessinées. « Effiler les extrémités » peut être activé ou désactivé ; désactivé, les traits gardent la même épaisseur jusqu’à leurs extrémités. Fondu d’arrière-plan superpose la lumière et l’ombre de l’arrière-plan avec le mode de fusion « Lumière crue » (la couleur de l’ombre n’est ni noire ni grise, mais celle des ombres de l’arrière-plan lui-même, assombrie). La couleur de l’environnement est superposée à tout le dessin en « Incrustation » pour en fixer la teinte générale, la lumière renvoyée par le sol et par les alentours s’ajoute en « Écran », et une lumière colorée intense comme un néon brille le long du contour en « Addition (lueur) ». « Accorder aux tons de l’arrière-plan » ramène dans sa plage les couleurs plus claires ou plus vives que l’arrière-plan, et donne aux tons sombres, moyens et clairs la dominante des tons de l’arrière-plan de même luminosité (le noir du trait ne change pas). « Intensité du flou » indique combien l’arrière-plan est flouté avant d’en prendre les couleurs.';

  @override
  String get helpLayerKeyframeTitle =>
      'Images clés de calque (animation par partie)';

  @override
  String get helpLayerKeyframeDesc =>
      'Définissez la position, l’échelle et la rotation de chaque calque par image ; les images clés sont interpolées automatiquement. Là où les images clés de caméra déplacent tout l’écran, celles-ci ne déplacent qu’un seul calque. Comme chaque partie du remplissage automatique est générée comme un calque distinct, cela fonctionne directement pour l’animation par partie — bouger seulement un bras, ouvrir et fermer seulement une bouche, etc. Chaque image clé peut aussi avoir son propre easing (uniforme, entrée douce, sortie douce, entrée et sortie douces, ou rebond) qui détermine comment elle se raccorde à l’image clé suivante, pour que le mouvement ne soit pas toujours à vitesse constante. Se configure depuis « Animation (images clés) » dans le menu à trois points de chaque calque, dans le panneau des calques. Le dessin du calque lui-même ne change pas : c’est une transformation non destructive de son emplacement d’affichage. Cela n’affecte que l’affichage de la timeline (aperçu / export) et n’a aucun effet sur le dessin réel en mode canevas.';

  @override
  String get helpLayerGroupTitle =>
      'Groupes de calques (déplacer plusieurs parties ensemble)';

  @override
  String get helpLayerGroupDesc =>
      'Déplace plusieurs calques ensemble avec un seul flux d’images clés. Par exemple, si un « bras » est composé de deux parties de remplissage automatique — peau et manche —, les grouper permet de déplacer les deux avec une seule opération d’image clé. Créez un groupe en sélectionnant plusieurs calques (cases à cocher) dans le panneau des calques puis en appuyant sur l’icône « Grouper » de la barre inférieure. Le mouvement du groupe se superpose aux images clés propres à chaque calque membre (si elles existent), ce qui permet de combiner le mouvement global du groupe avec des ajustements fins par calque. Un calque ne peut appartenir qu’à un seul groupe à la fois.';

  @override
  String get tipsScreenTitle => 'Astuces';

  @override
  String get tipsSearchHint => 'Rechercher une astuce...';

  @override
  String get tipsCategoryVideo => 'Astuces pour créer des vidéos';

  @override
  String get tipsCategoryEfficiency => 'Astuces pour travailler plus vite';

  @override
  String get tipsCategoryDrawing => 'Astuces pour un dessin plus fluide';

  @override
  String get tipsCategoryEffects => 'Astuces de style et de finition';

  @override
  String get tipsCategoryExport => 'Astuces d’export et de flux de travail';

  @override
  String get tipsClipDuplicateTitle =>
      'Les clips de la timeline peuvent être dupliqués, déplacés et supprimés';

  @override
  String get tipsClipDuplicateDesc =>
      'Touchez un clip image, vidéo ou audio pour ouvrir ses détails. Utilisez l’icône de copie pour le dupliquer et l’icône de suppression pour le retirer. Appuyez longuement sur un clip puis faites-le glisser pour déplacer son début. Pratique pour répéter un effet sonore ou placer la même image dans une autre scène.';

  @override
  String get tipsTextCaptionTitle =>
      'Ajoutez des sous-titres avec l’outil texte';

  @override
  String get tipsTextCaptionDesc =>
      'Utilisez l’outil texte pour placer des sous-titres ou des commentaires image par image. Passer la police en mode pixel peut aussi donner au texte un rendu rétro façon ancien jeu vidéo.';

  @override
  String get tipsAutofillPresetTitle =>
      'Enregistrez un réglage de remplissage automatique par partie';

  @override
  String get tipsAutofillPresetDesc =>
      'Enregistrer un réglage par partie (peau, cheveux, vêtements) avec ses ombres incluses automatise la majeure partie de la mise en couleur, dès que le trait est dessiné. Vous pouvez aussi limiter les réglages utilisés dans chaque projet.';

  @override
  String get tipsAutofillBaseCoatTitle =>
      'Le remplissage automatique fonctionne aussi comme une seule couche de base';

  @override
  String get tipsAutofillBaseCoatDesc =>
      'Le remplissage automatique sert normalement à colorer partie par partie, mais inutile de tout découper soigneusement : l’utiliser comme une seule couche de base d’une couleur unie sur tout le trait est déjà bien utile en soi. Il remplit tout l’intérieur du trait d’un coup, ce qui évite les oublis de remplissage (les interstices où la couleur du dessous transparaît) fréquents avec un remplissage manuel au pot de peinture. Peignez ensuite vos couleurs à la main par-dessus, et vous profitez du gain sans le travail de découpage par partie.';

  @override
  String get tipsAutofillManualPartColorTitle =>
      'Séparez les aplats provisoires à la main et gardez le trait réel sur un seul calque normal';

  @override
  String get tipsAutofillManualPartColorDesc =>
      'Cette méthode convient si vous souhaitez d’abord séparer les parties avec des couleurs provisoires bien visibles, puis les remplacer par les couleurs finales. Dessinez tout le trait réel sur un seul calque normal et placez-le au-dessus des calques de remplissage.\nAjoutez un « Calque de trait pour remplissage auto » pour chaque partie, puis utilisez « Attribuer une partie » dans son menu à trois points pour associer la partie. Dans cette méthode, ces calques servent uniquement de lien et peuvent rester vides : n’y dessinez pas le trait réel. Depuis le même menu, lancez une fois « Exécuter le remplissage automatique » pour créer le « Calque de remplissage auto » associé.\nSur chaque « Calque de remplissage auto », peignez manuellement une surface pleine avec une couleur provisoire bien visible. Remplissez la zone à recolorer au lieu d’en tracer uniquement le contour.\nUne fois les formes corrigées, ouvrez « Exécuter le remplissage automatique » dans le menu du « Calque de trait pour remplissage auto » correspondant, puis choisissez « Actualiser la couleur en conservant la forme ». Les formes peintes à la main sont conservées et les couleurs finales des « Réglages de remplissage auto » sont appliquées. Si vous voulez que l’application détecte et colore les parties directement à partir du trait en une seule opération, utilisez l’autre méthode : dessinez le trait réel sur les « Calques de trait pour remplissage auto ».';

  @override
  String get tipsBrushFavoriteTitle =>
      'Mettez vos pinceaux favoris en favori pour les retrouver sans chercher';

  @override
  String get tipsBrushFavoriteDesc =>
      'Touchez l’icône étoile des pinceaux que vous utilisez le plus pour les mettre en favori. L’icône étoile en haut de la liste permet de filtrer pour n’afficher que les favoris, réduisant le temps de recherche. Un pinceau en favori ne peut pas être supprimé par erreur.';

  @override
  String get tipsPressureCurveTitle =>
      'Ajustez la courbe de pression à votre main';

  @override
  String get tipsPressureCurveDesc =>
      'La courbe de pression dans les réglages permet de placer librement des points de contrôle. Si la réponse en intensité ne vous convient pas, ajustez-la selon vos propres habitudes de pression.';

  @override
  String get tipsExportFormatTitle =>
      'Choisissez le format d’export selon l’usage';

  @override
  String get tipsExportFormatDesc =>
      'Le GIF convient pour publier facilement sur les réseaux sociaux, le WebM transparent pour superposer sur une autre vidéo ou garder un fond transparent, et le MP4 pour un usage vidéo classique. Choisir selon l’usage facilite l’équilibre entre taille de fichier et qualité.';

  @override
  String get tipsGestureShortcutTitle =>
      'Associez un geste aux actions fréquentes';

  @override
  String get tipsGestureShortcutDesc =>
      'Depuis « Gestes » dans les réglages, vous pouvez associer annuler/rétablir ou la pipette à un appui à deux doigts, un appui à trois doigts ou un appui long. Comme vous n’avez pas à changer d’outil, cela ne casse pas le rythme du dessin.';

  @override
  String get tipsAudioRepeatTitle =>
      'Gardez vos bruitages en rythme avec des clips dupliqués + fondus';

  @override
  String get tipsAudioRepeatDesc =>
      'Pour réutiliser plusieurs fois le même bruitage, dupliquez le clip et alignez les copies à des moments décalés, en donnant à chacune son propre fondu d’entrée/sortie. Vous obtenez ainsi une répétition naturelle et rythmée de l’effet.';

  @override
  String get tipsVerticalRubyTitle =>
      'Texte vertical + furigana pour un look de logo de titre';

  @override
  String get tipsVerticalRubyDesc =>
      'Combiner l’écriture verticale avec les furigana dans l’outil texte donne un logo de titre à la japonaise ou un traitement de titre distinctif. Les alphanumériques demi-chasse pivotent automatiquement pour se placer sur le côté, restant lisibles même mélangés à des symboles ou des chiffres.';

  @override
  String get tipsBrushTrySaveTreeTitle =>
      'Testez de nouveaux réglages de pinceau via l’arbre de sauvegarde';

  @override
  String get tipsBrushTrySaveTreeDesc =>
      'Avant un gros changement d’épaisseur ou de stabilisation du pinceau, sauvegardez d’abord dans l’arbre de sauvegarde pour plus de sérénité. Si le résultat ne vous plaît pas, vous pouvez revenir directement à l’état précédent, ce qui facilite les essais audacieux.';

  @override
  String get tipsEyedropperGestureTitle =>
      'Associez la pipette à un appui à deux doigts pour garder une palette cohérente';

  @override
  String get tipsEyedropperGestureDesc =>
      'Associer la pipette à un appui à deux doigts dans les réglages de gestes permet de récupérer instantanément une couleur voisine sans changer d’outil. Pratique pour colorer en restant fidèle à la palette d’un personnage.';

  @override
  String get tipsRulerOnionTitle =>
      'Règle de perspective + papier calque pour réutiliser un fond';

  @override
  String get tipsRulerOnionDesc =>
      'Posez la profondeur d’un fond avec la règle de perspective, puis ne déplacez que le personnage en vérifiant les images voisines via le papier calque — plus besoin de redessiner le fond à chaque image.';

  @override
  String get tipsGradientTraceTitle =>
      'Remplissage automatique en dégradé + trace de couleur pour un fondu naturel';

  @override
  String get tipsGradientTraceDesc =>
      'En utilisant un dégradé dans un réglage de remplissage automatique, réglez le mode de couleur du trait sur trace de couleur pour que la couleur du trait suive les subtils changements du dégradé, évitant que la limite ne ressorte.';

  @override
  String get tipsGradientOutlineHairTitle =>
      'Dégradé × contour de couleur définie pour des cheveux translucides';

  @override
  String get tipsGradientOutlineHairDesc =>
      'Créez une partie « frange » dans votre réglage de remplissage automatique et réglez le remplissage sur un dégradé avec la couleur des cheveux et le transparent comme deux couleurs. Réglez l’angle sur 90°, ajustez l’intensité du flou et la position de transition des couleurs à votre goût, puis cochez « Contour avec une couleur définie » et choisissez la couleur du contour dans « Couleurs récemment utilisées », en sélectionnant la même couleur que celle utilisée pour la frange. Répétez les mêmes étapes pour la partie couleur d’ombre en plus de la partie de base, pour des cheveux à l’aspect translucide.';

  @override
  String get tipsRainNoiseTitle =>
      'Pluie + bruit animé pour une atmosphère humide';

  @override
  String get tipsRainNoiseDesc =>
      'Superposer un filtre de bruit animé léger sur le filtre de pluie ajoute une sensation de particules dans l’air en plus des gouttes elles-mêmes, pour une texture humide de jour de pluie.';

  @override
  String get tipsPartKeyframeGroupTitle =>
      'Faites rebondir un personnage avec images clés de partie + groupement';

  @override
  String get tipsPartKeyframeGroupDesc =>
      'Animez chaque partie de remplissage automatique avec des images clés de calque, puis groupez les parties liées pour les faire rebondir ensemble — vous pouvez créer une mini-animation qui se balance sur la musique sans rien redessiner.';

  @override
  String get tipsLowSpecSettingsTitle =>
      'Sur les appareils bas de gamme, revoyez les réglages de performance et l’historique d’annulation';

  @override
  String get tipsLowSpecSettingsDesc =>
      'Si ça semble lent, essayez de passer les réglages de performance au préréglage « basse qualité » et de réduire aussi la longueur de l’historique d’annulation. Cela réduit l’utilisation de la mémoire et peut rendre l’ensemble plus fluide.';

  @override
  String get tipsSeriesPresetFolderTitle =>
      'Gérez une série avec le filtrage des réglages de remplissage auto + l’organisation en dossiers';

  @override
  String get tipsSeriesPresetFolderDesc =>
      'Pour réaliser plusieurs épisodes d’une même œuvre, regroupez les projets par épisode dans un dossier, et limitez les réglages de remplissage automatique utilisés par chaque projet. Cela évite de mélanger la palette de chaque personnage et garde le travail efficace.';

  @override
  String get tipsPixelToneRetroTitle =>
      'Tampons en mode pixel + remplissage en trame pour un look rétro unifié';

  @override
  String get tipsPixelToneRetroDesc =>
      'Combiner des tampons en mode pixel avec les trames en damier et en grille réservées au mode pixel permet d’unifier tout l’écran avec une texture pixel art. Idéal pour un rendu jeu vidéo rétro.';

  @override
  String get tipsMagicWandLassoTitle =>
      'Baguette magique + remplissage au lasso pour séparer les couleurs plus vite';

  @override
  String get tipsMagicWandLassoDesc =>
      'Sélectionnez une large zone d’un coup avec la baguette magique de l’outil de sélection, puis ajustez seulement le débordement avec la sélection au lasso — même une séparation de couleurs complexe va vite ainsi.';

  @override
  String get tipsCommonLayerFolderTitle =>
      'Calques communs + dossiers pour réutiliser d’un épisode à l’autre';

  @override
  String get tipsCommonLayerFolderDesc =>
      'Pour un logo ou un générique utilisé à chaque épisode d’une série, transformez-le en calque commun et rangez-le dans un dossier — facile à gérer en le copiant vers le projet d’un nouvel épisode.';

  @override
  String get tipsStrokeDecayFadeTitle =>
      'Atténuation du trait + fondu pour un rendu pinceau calligraphique';

  @override
  String get tipsStrokeDecayFadeDesc =>
      'Dans les réglages du pinceau, le Fondu règle l’opacité et la distance au début et à la fin du trait, et l’Effilage (entrée et sortie) en règle l’épaisseur et la distance, chacun séparément. Combinez-les avec l’atténuation du trait pour estomper seulement le début, prolonger seulement une sortie fine ou rendre les deux extrémités asymétriques, comme avec un pinceau de calligraphie ou à encre.';

  @override
  String get tipsColorMixingFadeTitle =>
      'Mélange de couleurs + fondu pour un mélange façon peinture';

  @override
  String get tipsColorMixingFadeDesc =>
      'Ajouter un fondu à un pinceau avec le mélange de couleurs activé le fait se mélanger avec la couleur dessous tandis que le trait devient translucide vers son début et sa fin, bien plus proche du comportement de la vraie peinture.';

  @override
  String get tipsOutlineAnimeStyleTitle =>
      'Contour + style anime pour une finition animation cel';

  @override
  String get tipsOutlineAnimeStyleDesc =>
      'Dessinez le contour sur un nouveau calque avec le contour du filtre de dessin, puis réduisez le nombre de couleurs avec le filtre style anime, pour une finition nette façon animation cel.';

  @override
  String get tipsLevelsToneCurveTitle =>
      'Niveaux + courbe de tons pour un look de design graphique';

  @override
  String get tipsLevelsToneCurveDesc =>
      'Poussez fort le contraste avec les niveaux d’abord, puis sculptez la gradation avec la courbe de tons, pour un look graphique façon affiche qui s’éloigne de la tonalité photographique.';

  @override
  String get tipsMosaicChromaticTitle =>
      'Mosaïque + aberration chromatique pour une texture rêche façon tube cathodique';

  @override
  String get tipsMosaicChromaticDesc =>
      'Baissez la résolution avec la mosaïque puis superposez l’aberration chromatique, pour une texture rêche façon vieille télé à tube cathodique — une nuance différente du filtre tube cathodique seul.';

  @override
  String get tipsEndCardWatermarkTitle =>
      'Le filigrane, c’est votre signature ; la marque de fin, autre chose';

  @override
  String get tipsEndCardWatermarkDesc =>
      'Utilisez le filigrane pour ajouter votre propre signature ou marque à une vidéo. La marque de fin est le logo NIARIM ajouté à la fin des exports MP4, WebM et AVI. Avec Premium ou l’avantage de modification de la marque de fin, vous pouvez l’afficher ou la masquer pour chaque projet. Les GIF ne l’incluent pas et reçoivent à la place l’icône et le nom de NIARIM en petit dans un coin. Pour une conclusion personnalisée sans utiliser la marque de fin, vous pouvez recréer un effet similaire en ajoutant un calque image avec un fondu d’entrée/sortie.';

  @override
  String get tipsVerticalPixelFontTitle =>
      'Mélangez images réelles et dessin à la main pour un rendu « prise de vue réelle × anime »';

  @override
  String get tipsVerticalPixelFontDesc =>
      'Cette app étant à la fois une app d’illustration et un éditeur vidéo, voici une autre façon de vous amuser. Placez un clip vidéo réel sur la timeline, puis utilisez le papier calque sur un calque au-dessus pour dessiner à la main des traits de vitesse ou un personnage par-dessus les images — créant une vidéo mixte où une animation dessinée à la main se superpose à des prises de vue réelles.';

  @override
  String get tipsTimelineMarkerTitle =>
      'Utilisez les horodatages pour synchroniser le son et les mouvements de bouche';

  @override
  String get tipsTimelineMarkerDesc =>
      'Un horodatage ajoute une note à une image. Touchez son nom pour atteindre l’image et ouvrir le menu de modification ou de suppression. Le triangle au-dessus de l’image ouvre également la note.';

  @override
  String get tipsCommunityYoutubeTitle =>
      'Publier sur la Place des œuvres se fait via YouTube';

  @override
  String get tipsCommunityYoutubeDesc =>
      'Lorsque vous publiez sur la Place des œuvres, votre création est publiée via YouTube. NIARIM ne transmet, ne collecte ni ne stocke le fichier vidéo lui-même sur les serveurs du développeur. Si vous réglez la vidéo sur « Non répertoriée » côté YouTube, elle n’apparaîtra ni dans les résultats de recherche de YouTube ni dans la liste des vidéos de votre chaîne, mais restera visible depuis la Place des œuvres. Toutefois, toute personne qui connaît le lien peut regarder une vidéo non répertoriée.';

  @override
  String get tipsToolbarCustomizeTitle =>
      'Réorganisez ou masquez des outils de la barre pour réduire le trajet du doigt';

  @override
  String get tipsToolbarCustomizeDesc =>
      'Depuis l’édition de la barre d’outils dans les réglages, vous pouvez masquer les outils que vous n’utilisez jamais et réorganiser ceux que vous utilisez pour qu’ils soient à portée de doigt facile. Réduire la liste évite de chercher un outil et raccourcit le trajet du doigt, gardant votre rythme de dessin.';

  @override
  String get tipsAutofillBlendModeTitle =>
      'Changez la texture de l’ombrage avec le mode de fusion d’une partie de remplissage automatique';

  @override
  String get tipsAutofillBlendModeDesc =>
      'Chaque partie d’un réglage de remplissage automatique peut avoir son propre mode de fusion. Réglez une partie d’ombre sur « incrustation » ou « lumière tamisée » plutôt que « produit » pour un ombrage plus doux, comme traversé par la lumière. Une liberté cachée qui permet de changer la texture de l’ombrage sans changer la couleur.';

  @override
  String get tipsStampBlendModeTitle =>
      'Tampons + mode de fusion pour un effet de lumière';

  @override
  String get tipsStampBlendModeDesc =>
      'Régler le mode de fusion d’un calque de tampon placé sur « écran » ou « addition » fait que les traits de lumière ou effets scintillants se fondent naturellement dans le fond et ressortent vraiment.';

  @override
  String get tipsQuickToolPenSubTitle =>
      'Outil rapide + sous-outils de la plume pour un flux de travail sans interruption';

  @override
  String get tipsQuickToolPenSubDesc =>
      'Enregistrez vos outils les plus utilisés dans l’outil rapide, et profitez aussi des sous-outils de la plume (appui long sur la plume pour passer au remplissage en trame ou au placement de tampon) — vous réduirez les allers-retours entre panneaux et garderez votre rythme.';

  @override
  String get tipsAutofillToneReuseTitle =>
      'Réutilisez un remplissage en trame juste en retraçant le trait, grâce au réglage de trame du remplissage automatique';

  @override
  String get tipsAutofillToneReuseDesc =>
      'Régler chaque partie d’un réglage de remplissage automatique sur « utiliser une trame » reproduit automatiquement le remplissage en trame à chaque fois que vous retracez le trait — plus besoin de la réappliquer image par image.';

  @override
  String get tipsAutofillMisfillTitle =>
      'Comprendre le remplissage automatique réduit les erreurs';

  @override
  String get tipsAutofillMisfillDesc =>
      'Le remplissage automatique n’est pas une fonction d’IA générative : c’est une application du pot de peinture par calque. Ainsi, lorsqu’une même partie comporte un espace fermé par des traits — à l’intérieur de cheveux longs, par exemple —, cet espace est lui aussi rempli. Une bonne parade consiste à attribuer d’abord à chaque partie une couleur vive très saturée et à lancer une première passe. Les erreurs sautent aux yeux et le calque de remplissage automatique se corrige facilement à la main ; une fois corrigé, définissez les couleurs définitives et relancez le remplissage automatique pour l’écraser : les ratés diminuent nettement.';

  @override
  String get tipsHomeWidgetTitle =>
      'Garder une œuvre sous les yeux grâce à un widget d’écran d’accueil';

  @override
  String get tipsHomeWidgetDesc =>
      'Choisissez une œuvre depuis Réglages → Widgets de l’écran d’accueil, et une image de celle-ci s’affichera en image statique sur l’écran d’accueil du téléphone. L’écran « Choisir une œuvre » reprend le même tri, la même recherche et le même filtre des favoris que l’onglet des projets, et le sélecteur d’image propose les mêmes commandes de lecture et la même barre de progression que la timeline pour trouver l’image idéale. Ajoutez aussi les widgets « Créer une animation » et « Place des œuvres » pour accéder en un geste au dessin ou à la consultation des œuvres publiées depuis l’écran d’accueil.';

  @override
  String get tipsAutofillTransparentFixTitle =>
      'Effacez les débordements du remplissage automatique au pot de couleur transparente';

  @override
  String get tipsAutofillTransparentFixDesc =>
      'Quand le remplissage automatique déborde sur une zone que vous ne vouliez pas peindre, le pot de peinture avec la couleur de dessin réglée sur transparent est plus pratique que de repasser à la gomme. Le pot traite d’un coup toute la région délimitée par les traits : une seule pression efface proprement le seul débordement.';

  @override
  String get tipsRadialVignetteTitle =>
      'Règle de lignes de vitesse + vignettage pour un effet percutant';

  @override
  String get tipsRadialVignetteDesc =>
      'Avec la règle de lignes de vitesse, dessinez une rafale de lignes d’un seul coup, puis superposez le filtre de dessin vignettage pour un effet façon climax de manga.';

  @override
  String get tipsClippingGradientTitle =>
      'Écrêtage + dégradé pour garder l’ombrage modifiable';

  @override
  String get tipsClippingGradientDesc =>
      'Écrêtez un calque de dégradé sur un calque de personnage, et vous pourrez réajuster l’ombrage juste en changeant l’étendue et l’angle du dégradé — plus besoin de redessiner sa forme au pinceau.';

  @override
  String get tipsToneCurveSepiaTitle =>
      'Courbe de tons + sépia pour un rendu photo rétro';

  @override
  String get tipsToneCurveSepiaDesc =>
      'Ajustez le contraste clair/sombre avec le filtre d’effet courbe de tons, puis superposez le sépia, pour une texture façon vieille photo délavée.';

  @override
  String get tipsCameraLensBlurTitle =>
      'Images clés de caméra + flou d’objectif pour un effet de flou de zoom';

  @override
  String get tipsCameraLensBlurDesc =>
      'Synchroniser un filtre d’effet de flou d’objectif plus fort avec le moment où une image clé de caméra zoome donne le punch d’un flou de zoom en prise de vue réelle.';

  @override
  String get tipsBlurVignetteBgTitle =>
      'Flou gaussien + vignettage pour un bokeh d’arrière-plan doux';

  @override
  String get tipsBlurVignetteBgDesc =>
      'Appliquez les filtres de dessin flou gaussien et vignettage uniquement au calque d’arrière-plan, et votre personnage principal ressort naturellement, pour un rendu façon profondeur de champ de caméra.';

  @override
  String get tipsSepiaVignetteTitle =>
      'Sépia + vignettage pour une vidéo façon photo ancienne';

  @override
  String get tipsSepiaVignetteDesc =>
      'Combiner le filtre d’effet sépia avec le filtre de dessin vignettage donne à votre vidéo les coins assombris et l’aspect délavé d’une photo ancienne.';

  @override
  String get tipsVideoTrimReuseTitle =>
      'Réutilisez le même fichier vidéo en changeant la portion utilisée de chaque clip';

  @override
  String get tipsVideoTrimReuseDesc =>
      'Même le même fichier vidéo peut donner un plan différent à chaque fois en changeant son début/fin d’utilisation par clip. Apporte de la variété sans ajouter de nouveau matériau.';

  @override
  String get tipsSaveSlotAutoSaveTitle =>
      'Répartissez les emplacements de sauvegarde et la sauvegarde automatique';

  @override
  String get tipsSaveSlotAutoSaveDesc =>
      'NIARIM conserve jusqu’à 3 sauvegardes automatiques. Utilisez un emplacement de sauvegarde pour garder une version importante et la charger plus tard depuis la liste.';

  @override
  String get tipsQuickToolSwipeTitle =>
      'Glissez vers le haut sur l’outil rapide pour le réorganiser';

  @override
  String get tipsQuickToolSwipeDesc =>
      'Pour changer ce qui est enregistré dans l’outil rapide, vous pouvez ouvrir le popup de gestion par un glissement vers le haut, pas seulement par un appui long. Pratique pour réorganiser vite en utilisant une seule main.';

  @override
  String get tipsDrawingAreaCameraTitle =>
      'Zone de dessin plus large + images clés de caméra pour des panoramiques et zooms sûrs';

  @override
  String get tipsDrawingAreaCameraDesc =>
      'Définir la zone de dessin plus large que les limites d’export signifie qu’un panoramique ou un zoom avec des images clés de caméra ne risque pas de couper le bord de l’écran. À vérifier avant d’ajouter un grand mouvement de caméra.';

  @override
  String get tipsWebmCommonLayerTitle =>
      'WebM transparent + un calque commun pour séparer le fond';

  @override
  String get tipsWebmCommonLayerDesc =>
      'Si vous compositez un personnage exporté en WebM transparent sur un fond dans un autre logiciel vidéo, garder le fond sur son propre calque commun évite que des couleurs indésirables ne se glissent dans la zone transparente, pour un détourage plus propre.';

  @override
  String get tipsLeftHandedWorkspaceTitle =>
      'Mode gaucher + réglages de l’espace de travail pour une configuration plus confortable';

  @override
  String get tipsLeftHandedWorkspaceDesc =>
      'Si vous êtes gaucher, activer le mode gaucher dans les réglages de l’espace de travail inverse les panneaux ancrés, réduisant le risque qu’ils se retrouvent sous votre main de dessin.';

  @override
  String get tipsTransferDeviceTitle =>
      'Déplacez votre travail vers un autre appareil avec un fichier de transfert';

  @override
  String get tipsTransferDeviceDesc =>
      'Si vous voulez changer d’appareil tout en gardant le même environnement de dessin, la fonction de transfert (.niatra) déplace vos réglages, pinceaux, trames, tampons, palettes et plus, le tout ensemble. Pour remettre un projet en cours, utilisez plutôt « Partage (.niashare) ».';

  @override
  String get fontSettingsTabDownloaded => 'Téléchargées';

  @override
  String get fontSettingsTabSearch => 'Rechercher et télécharger';

  @override
  String get fontSettingsTabImport => 'Importer';

  @override
  String get fontDownloadedSearchHint => 'Rechercher par nom de police...';

  @override
  String get fontPixelModeTooltip =>
      'Mode pixel (pour polices en points. Affichage net sans anticrénelage)';

  @override
  String get fontEmptyTitle => 'Aucune police';

  @override
  String get fontEmptyHint =>
      'Ajoutez des polices depuis les onglets « Rechercher et télécharger » ou « Importer »';

  @override
  String fontDeleteUsageCounts(int projects, int watermarks) {
    return 'Projets et corbeille : $projects. Préréglages de filigrane : $watermarks.';
  }

  @override
  String get fontDeleteSavedUsageWarning =>
      'Après la suppression, le texte qui utilise cette police, y compris dans des sauvegardes antérieures, peut s’afficher avec une autre police.';

  @override
  String get fontRenameDialogTitle => 'Renommer la police';

  @override
  String get fontImportTitle =>
      'Importer une police enregistrée sur cet appareil';

  @override
  String get fontImportFormats => 'Formats pris en charge : TTF / OTF';

  @override
  String get fontSelectFileButton => 'Sélectionner un fichier';

  @override
  String get fontUnsupportedSnackbar => 'Cette police n’a pas pu être chargée.';

  @override
  String fontAddedSnackbar(String name) {
    return '« $name » ajoutée (visible dans l’onglet Téléchargées)';
  }

  @override
  String get fontCorruptedSnackbar => 'La police est corrompue.';

  @override
  String get licenseScreenTitle => 'Conditions et licences';

  @override
  String get licenseSectionTerms => 'Conditions d’utilisation';

  @override
  String get licenseCreditBody => 'Police du corps de texte par défaut';

  @override
  String get licenseCreditHeading => 'Titres, en-têtes et boutons';

  @override
  String get licenseCreditNumbers => 'Chiffres sur Android';

  @override
  String get licenseCreditCjkBody =>
      'Sous-ensembles inclus pour le corps de texte en chinois simplifié et traditionnel et les caractères coréens';

  @override
  String get licenseCreditCjkHeading =>
      'Sous-ensembles de remplacement pour les titres en coréen et en chinois';

  @override
  String get licenseCreditFallback =>
      'Remplacement des caractères absents de Kuramubon';

  @override
  String get licenseCreditTextTool => 'Police fournie avec l’outil Texte';

  @override
  String licenseCreditCatalog(String path) {
    return 'Téléchargez des polices pour l’outil Texte depuis $path.';
  }

  @override
  String get licenseCreditCatalogAuthor =>
      'Les créateurs de chaque police figurent sur sa page Google Fonts.';

  @override
  String get licenseCreditCatalogLicense =>
      'La licence de chaque police figure dans le catalogue.';

  @override
  String get licenseCreditIcons =>
      'Icônes des outils Gomme, Remplissage et Formes';

  @override
  String get licenseCreditIconLicense =>
      'Les icônes utilisent CC BY 4.0, la police utilise SIL Open Font License 1.1 et le paquet utilise la licence MIT.';

  @override
  String get licenseSectionFonts => 'Polices utilisées';

  @override
  String get licenseSectionOss => 'Licences des logiciels open source';

  @override
  String get licenseOssListTitle => 'Liste des licences des bibliothèques';

  @override
  String get licenseOssListSubtitle =>
      'Affiche les licences des paquets OSS utilisés par cette application';

  @override
  String get licenseFfmpegNote =>
      'Les exports WebM et AVI, ainsi que le mixage du son ajouté au MP4, utilisent FFmpeg (LGPL 3.0, via ffmpeg_kit_flutter_new_video). Source de la version modifiée : https://github.com/sk3llo/ffmpeg_kit_flutter\nLa vidéo MP4 et son son AAC sont créés par les encodeurs intégrés de l’appareil, et non par FFmpeg.';

  @override
  String licenseFontCreditMeta(String author, String license) {
    return 'Auteur : $author   Licence : $license';
  }

  @override
  String get toolbarPenTooltip => 'Plume (appui long pour les sous-outils)';

  @override
  String get toolbarPenFirstUseTip =>
      'Appuyez longuement sur la plume pour basculer entre pinceau, trame, tampon et remplissage au lasso.';

  @override
  String get toolbarBucketTooltip =>
      'Pot de peinture (appui long pour alterner remplissage uni/trame)';

  @override
  String get toolbarBucketFirstUseTip =>
      'Appuyez longuement sur le pot de peinture pour basculer entre remplissage uni et remplissage en trame.';

  @override
  String get toolbarSelectTooltip =>
      'Sélection (appui long pour changer de type)';

  @override
  String get toolbarShapeTooltip => 'Forme (appuyez pour choisir le type)';

  @override
  String get toolbarTextFirstUseTip =>
      'Placez du texte librement. Vous pouvez aussi changer la police, la couleur et le contour.';

  @override
  String get toolbarQuickToolFirstUseTip =>
      'Appuyez pour parcourir vos outils enregistrés dans l’ordre. Appui long ou balayage vers le haut pour modifier vos outils enregistrés.';

  @override
  String get firstUseTipOperationGuideTitle => 'Commandes de base';

  @override
  String get firstUseTipOperationGuideBody =>
      'Une simple pression sur une icône de la barre d’outils bascule vers cet outil. Appuyez longuement sur cette même icône, ou faites-la glisser vers le haut, pour ouvrir ses réglages détaillés (type de pinceau, mode de remplissage, mode de sélection, etc.). Appuyez deux fois sur une icône pour afficher une brève description de l’outil. Vous pouvez relire tout cela depuis le bouton « ? » en haut à droite de chaque écran.';

  @override
  String get helpBasicGestureTitle =>
      'Commandes de base (appui, appui long, balayage)';

  @override
  String get helpBasicGestureDesc =>
      'Une simple pression sur une icône de la barre d’outils bascule vers cet outil. Appuyez longuement sur cette icône, ou faites-la glisser vers le haut, pour ouvrir ses réglages détaillés. Derrière cet appui long ou ce balayage se trouvent : pinceau, trame, tampon ou remplissage au lasso pour la plume ; remplissage uni ou tramé pour le pot ; rectangle, lasso ou sélection automatique pour l’outil de sélection ; flou ou mosaïque pour l’outil doigt ; et la modification des outils enregistrés pour l’outil rapide. Un double appui sur une icône affiche une brève description en bas de l’écran.\nSur le canevas, pincez à deux doigts pour zoomer, faites glisser à deux doigts pour vous déplacer, touchez à deux doigts pour annuler et à trois doigts pour rétablir. Appuyez deux fois sur le bord gauche ou droit de l’écran pour passer à l’image précédente ou suivante.\nAvec une souris ou une tablette graphique, la molette zoome et le glissement avec le bouton central déplace la vue.';

  @override
  String get toolbarStampColorLockedSnackbar =>
      'Les tampons ont leur propre couleur, celle-ci ne peut donc pas être modifiée';

  @override
  String get toolbarBrushSettingsTooltip => 'Réglages du pinceau';

  @override
  String get toolbarLayerTooltip => 'Calques';

  @override
  String get toolbarQuickToolTooltip =>
      'Outil rapide (appui long/balayage vers le haut pour modifier)';

  @override
  String get toolbarSaveTooltip => 'Enregistrer (arbre de sauvegarde)';

  @override
  String get toolbarBucketFlatFill => 'Remplissage uni';

  @override
  String get toolbarBucketToneListLabel => 'Trames';

  @override
  String get toolbarSelectRect => 'Sélection rectangulaire';

  @override
  String get toolbarSelectLasso => 'Sélection au lasso';

  @override
  String get toolbarSelectMagicWand =>
      'Sélection automatique (baguette magique)';

  @override
  String get creativePanelFavoritesOnlyTooltip =>
      'Afficher uniquement les favoris';

  @override
  String get creativePanelSearchTooltip => 'Rechercher par nom';

  @override
  String get creativePanelSearchModeKeyword =>
      'Recherche par mot-clé (appuyez pour la recherche par étiquette)';

  @override
  String get creativePanelSearchModeTag =>
      'Recherche par étiquette (appuyez pour la recherche par mot-clé)';

  @override
  String get communitySearchModeKeywordLabel => 'Par mot-clé';

  @override
  String get communitySearchModeTagLabel => 'Par tag';

  @override
  String get creativePanelTagSearchHint => 'Rechercher par étiquette';

  @override
  String get creativePanelTagNoneYet =>
      'Aucune étiquette pour l’instant — ajoutez-en depuis l’écran d’édition';

  @override
  String get creativePanelTagsLabel => 'Étiquettes';

  @override
  String get creativePanelTagsHint =>
      'Séparez-les par des virgules ou des espaces';

  @override
  String get creativePanelTagClearFilter => 'Effacer le filtre par étiquette';

  @override
  String get widgetSettingsTitle => 'Widgets de l’écran d’accueil';

  @override
  String get widgetSettingsDescription =>
      'Placez trois widgets sur votre écran d’accueil : une image d’une œuvre de votre choix, « Créer une animation » et « Place des œuvres ». Ajoutez-les par un appui long sur l’écran d’accueil.';

  @override
  String get widgetSettingsSubtitle => 'Œuvre à afficher, couleur du widget';

  @override
  String get widgetArtworkSection => 'Œuvre à afficher';

  @override
  String get widgetArtworkPickButton => 'Choisir une œuvre';

  @override
  String get widgetSectionArtwork => 'Widget d’écran de démarrage';

  @override
  String get widgetSectionArtworkDesc =>
      'Affiche une image de l’œuvre que vous choisissez. Un appui ouvre NIARIM.';

  @override
  String get widgetSectionCreate => 'Widget de création';

  @override
  String get widgetSectionCreateDesc =>
      'Un appui ouvre l’écran « Nouveau projet ».';

  @override
  String get widgetSectionPlaza => 'Widget de la Place des œuvres';

  @override
  String get widgetSectionPlazaDesc => 'Un appui ouvre la Place des œuvres.';

  @override
  String get widgetArtworkNone => 'Aucune œuvre sélectionnée';

  @override
  String get widgetArtworkInTrash =>
      'L’œuvre choisie est dans la corbeille. Restaurez-la pour l’afficher de nouveau.';

  @override
  String widgetArtworkFrameNumberLabel(int n) {
    return 'Image $n';
  }

  @override
  String get widgetArtworkFramePickerHint =>
      'Touchez l’image que vous voulez afficher.';

  @override
  String get widgetArtworkFramePickerConfirmButton => 'Utiliser cette image';

  @override
  String get widgetArtworkNoFrames => 'Cette scène n’a pas encore d’images.';

  @override
  String get widgetColorFollowTheme => 'Suivre le thème de l’application';

  @override
  String get widgetColorCustom => 'Choisir une couleur';

  @override
  String get widgetColorBase => 'Couleur de fond';

  @override
  String get widgetColorForeground => 'Couleur du texte et des icônes';

  @override
  String get widgetNoProjects => 'Aucune œuvre pour l’instant';

  @override
  String get widgetNoProjectsHint =>
      'Une fois une œuvre créée, vous pourrez la choisir ici pour l’afficher dans le widget.';

  @override
  String get widgetArtworkShowNone => 'N’afficher aucune œuvre';

  @override
  String get assetTagLineArt => 'Trait';

  @override
  String get assetTagBasic => 'Basique';

  @override
  String get assetTagMainLine => 'Trait principal';

  @override
  String get assetTagPaint => 'Peinture';

  @override
  String get assetTagBlur => 'Flou';

  @override
  String get assetTagMixing => 'Mélange';

  @override
  String get assetTagAnalog => 'Analogique';

  @override
  String get assetTagDecoration => 'Décoration';

  @override
  String get assetTagRough => 'Brouillon';

  @override
  String get assetTagEffect => 'Effets';

  @override
  String get assetTagTaper => 'Attaque et sortie';

  @override
  String get assetTagPixelArt => 'Pixel art';

  @override
  String get assetTagHalftone => 'Trame';

  @override
  String get assetTagShadow => 'Ombre';

  @override
  String get assetTagLine => 'Lignes';

  @override
  String get assetTagGradient => 'Dégradé';

  @override
  String get assetTagTexture => 'Texture';

  @override
  String get assetTagClothing => 'Vêtements';

  @override
  String get assetTagMesh => 'Maille';

  @override
  String get assetTagBackground => 'Arrière-plan';

  @override
  String get assetTagPattern => 'Motif';

  @override
  String get assetTagShape => 'Formes';

  @override
  String get assetTagSymbol => 'Symboles';

  @override
  String get assetTagManga => 'Manga';

  @override
  String get creativePanelFolderButton => 'Dossier';

  @override
  String get creativePanelCreateButton => 'Nouveau';

  @override
  String get creativePanelImportButton => 'Importer';

  @override
  String get creativePanelFolderAllChip => 'Tous';

  @override
  String get creativePanelEditAction => 'Modifier';

  @override
  String get toneTitle => 'Trames';

  @override
  String get toneEmpty => 'Aucune trame';

  @override
  String get toneSearchHint => 'Rechercher par nom de trame';

  @override
  String get toneEditTitle => 'Modifier la trame';

  @override
  String get toneChangeTextureButton => 'Changer l’image de texture';

  @override
  String get toneCreateDialogTitle => 'Trame personnalisée';

  @override
  String toneImportFailedSnackbar(String error) {
    return 'Échec du chargement de la trame : $error';
  }

  @override
  String toneExportFailedSnackbar(String error) {
    return 'Échec de l’exportation de la trame : $error';
  }

  @override
  String get privacyPolicyScreenTitle => 'Politique de confidentialité';

  @override
  String get stampTitle => 'Tampons';

  @override
  String get stampSearchHint => 'Rechercher par nom de tampon';

  @override
  String get stampEmpty => 'Aucun tampon';

  @override
  String get stampCreateDialogTitle => 'Tampon personnalisé';

  @override
  String stampExportFailedSnackbar(String error) {
    return 'Échec de l’exportation du tampon : $error';
  }

  @override
  String get stampEditTitle => 'Modifier le tampon';

  @override
  String get stampRotationLabel => 'Rotation';

  @override
  String get stampPixelModeLabel => 'Mode pixel';

  @override
  String get stampPixelModeHint =>
      'Rendu façon pixel art (mosaïque + réduction des couleurs)';

  @override
  String get stampDensityLabel => 'Densité';

  @override
  String get stampScatterLabel => 'Dispersion';

  @override
  String get stampChangeImageButton => 'Changer l’image du tampon';

  @override
  String get themeSettingsTitle => 'Thème et apparence';

  @override
  String get themeColorCustomizeSection => 'Personnalisation des couleurs';

  @override
  String get themeColorAccent => 'Couleur d’accent';

  @override
  String get themeColorText => 'Couleur du texte courant';

  @override
  String get themeColorButtonText =>
      'Couleur du texte et des icônes sur fond coloré';

  @override
  String get themeAdvancedColors => 'Réglages avancés des couleurs';

  @override
  String get themeAdvancedColorsHint =>
      'Les couleurs identiques à une couleur de base évoluent avec celle-ci. Vous pouvez aussi les régler séparément.';

  @override
  String get themeColorMenuText =>
      'Couleur du texte des menus et de la barre supérieure';

  @override
  String get themeColorSelectionText =>
      'Couleur du texte et des icônes sélectionnés';

  @override
  String get themeColorPanelBg => 'Couleur de fond des panneaux';

  @override
  String get themeColorMenuBg => 'Couleur de fond des menus';

  @override
  String get themeColorSelection => 'Couleur de sélection';

  @override
  String get themeColorUpdateMark => 'Couleur de la marque de mise à jour';

  @override
  String get themeColorUpdateMarkHint =>
      'Utilisée pour les marques de mise à jour et pour les avis qui demandent votre attention.';

  @override
  String get themeColorWarning => 'Couleur d’avertissement';

  @override
  String get themeColorWarningHint =>
      'Utilisée pour les actions irréversibles, comme la suppression, et pour les avis lorsqu’un élément n’a pas pu être enregistré.';

  @override
  String get themeResetConfirmTitle => 'Réinitialiser les couleurs du thème ?';

  @override
  String get themeResetConfirmAction => 'Réinitialiser';

  @override
  String get themeUnreadableResetButton => 'Revenir aux couleurs par défaut';

  @override
  String get themeUnreadableResetDone =>
      'Le thème est revenu aux couleurs par défaut.';

  @override
  String get themePresetSection => 'Thèmes';

  @override
  String get themePresetInUseLabel => 'Utilisé';

  @override
  String themePresetDuplicateName(String name) {
    return '$name (copie)';
  }

  @override
  String get themeDuplicateAction => 'Dupliquer';

  @override
  String themeAdoptColorsSnackbar(String name) {
    return 'Les couleurs de « $name » ont été appliquées à vos couleurs actuelles. Les modifier ne changera pas le thème d’origine.';
  }

  @override
  String themeEditPresetSnackbar(String name) {
    return 'Vous modifiez maintenant « $name ». Les changements de personnalisation des couleurs y seront enregistrés.';
  }

  @override
  String get themeExportMenuItem => 'Exporter (.niatheme)';

  @override
  String themeExportFailedSnackbar(String error) {
    return 'Échec de l’exportation : $error';
  }

  @override
  String get themeImportSuccessSnackbar => 'Fichier .niatheme importé';

  @override
  String get themeImportInvalidFile =>
      'Ce fichier n’est pas un thème ou il est endommagé.';

  @override
  String get themeImportMissingColors =>
      'Des couleurs ou réglages obligatoires du thème sont manquants ou invalides.';

  @override
  String get themeImportLowContrast =>
      'Le thème importé manque de contraste. Il a été ajouté à la liste et vos couleurs actuelles restent actives.';

  @override
  String get themeImportReadFailed => 'Impossible de lire le fichier de thème.';

  @override
  String get themeSaveAsNewButton =>
      'Enregistrer les réglages actuels comme nouveau thème';

  @override
  String get themeImportButton => 'Importer un fichier .niatheme';

  @override
  String get themePresetNameDialogTitle => 'Nom du thème';

  @override
  String get themeDefaultPresetName => 'Mon thème';

  @override
  String get onionSkinTitle => 'Papier calque';

  @override
  String get onionSkinPrevFrame => 'Image précédente';

  @override
  String get onionSkinNextFrame => 'Image suivante';

  @override
  String get onionSkinFrameInterval => 'Intervalle d’images';

  @override
  String get onionSkinFadeByDistance => 'Plus foncé si proche';

  @override
  String get onionSkinColorPickerTitle => 'Choisir une couleur';

  @override
  String get onionSkinOnFixed => 'Activé (fixe)';

  @override
  String get onionSkinFrameCount => 'Nombre d’images';

  @override
  String onionSkinFrameCountFixed(int count) {
    return '$count image(s) (fixe)';
  }

  @override
  String get onionSkinColorLabel => 'Couleur';

  @override
  String get onionSkinOpacityLabel => 'Opacité';

  @override
  String get onionSkinMoreColors => 'Plus de couleurs';

  @override
  String get onionSkinFrameCountHint =>
      'Pour changer le nombre d’images, choisissez la qualité « Personnalisé » dans les paramètres Performances.';

  @override
  String get exportScreenTitle => 'Export';

  @override
  String get exportPresetSection => 'Préréglage';

  @override
  String get exportPresetStandard => 'Standard';

  @override
  String get exportPresetHighQuality => 'Haute qualité';

  @override
  String get exportPresetCustom => 'Personnalisé';

  @override
  String get exportAdvancedSettings => 'Réglages avancés';

  @override
  String get exportFpsLabel => 'i/s';

  @override
  String exportFpsDiffersNote(int source, int output) {
    return 'L’œuvre est à $source i/s. L’export à $output i/s garde sa durée en répétant ou en sautant des images (l’aperçu est lu à $source i/s).';
  }

  @override
  String exportUseWorkFps(int fps) {
    return 'Utiliser les $fps i/s de l’œuvre';
  }

  @override
  String exportPreviewAtFps(int fps) {
    return 'Voir l’aperçu à $fps i/s dans la timeline';
  }

  @override
  String get exportFormatSection => 'Format';

  @override
  String get exportRangeSection => 'Ce qu’il faut exporter';

  @override
  String get exportRangeAllScenes => 'Toutes les scènes';

  @override
  String exportRangeFrames(int start, int end) {
    return 'Images F$start–F$end';
  }

  @override
  String get exportSizeQualitySection => 'Taille et qualité';

  @override
  String get exportQualitySmall => 'Fichier plus léger';

  @override
  String get exportQualityHigh => 'Image plus nette';

  @override
  String get exportSequenceButton =>
      'Exporter toutes les images en fichiers numérotés (PNG)';

  @override
  String exportSequenceFolderName(String name) {
    return '$name (images)';
  }

  @override
  String exportSequenceDone(int count, String folder) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count images numérotées exportées',
      one: '$count image numérotée exportée',
    );
    return '$_temp0 (dans « $folder », dans Œuvres).';
  }

  @override
  String get exportFormatMp4 => 'MP4';

  @override
  String get exportFormatMp4Subtitle =>
      'Publier ou partager une vidéo terminée.';

  @override
  String get exportFormatGif => 'GIF';

  @override
  String get exportFormatGifSubtitle =>
      'Lire une courte animation en boucle, sans son.';

  @override
  String get exportFormatWebmSubtitle =>
      'Superposer une animation à une autre vidéo sur fond transparent.';

  @override
  String get exportFormatAvi => 'AVI';

  @override
  String get exportFormatAviSubtitle =>
      'Pour les logiciels de montage qui acceptent les AVI Motion JPEG. Le fond est opaque.';

  @override
  String get exportStartButton => 'Démarrer l’export';

  @override
  String get timelineHideEndCard => 'Masquer la marque de fin';

  @override
  String get timelineShowEndCard => 'Afficher la marque de fin';

  @override
  String get exportCurrentConditions => 'Exporter avec ces conditions';

  @override
  String get exportRetryBenefits => 'Revérifier les avantages';

  @override
  String get exportBenefitsUnavailable =>
      'Impossible de vérifier les avantages. Réessayez ou exportez avec les conditions affichées.';

  @override
  String get exportBenefitsChecking => 'Vérification des avantages…';

  @override
  String get exportFirst90Seconds => 'Exporter les 90 premières secondes';

  @override
  String get premiumBannerFullExportTitle => 'Exporter le projet en entier';

  @override
  String get premiumBannerEndCardBody =>
      'L’abonnement Premium ou l’avantage de modification de la marque de fin permet d’afficher ou de masquer la marque de fin officielle et le logo dans le coin des GIF. Les vidéos du making-of suivent le même réglage.';

  @override
  String get premiumBannerWatermarkBody =>
      'Ajoutez et modifiez votre propre filigrane avec l’abonnement Premium ou l’avantage Filigrane.';

  @override
  String get premiumBannerToneCurveBody =>
      'Pour ajuster la luminosité et les couleurs avec Courbe de tons dans les filtres de dessin et d’effet, l’abonnement Premium ou l’avantage Courbe de tons est nécessaire.';

  @override
  String get premiumBannerLevelsBody =>
      'Ajustez la plage tonale avec Niveaux dans les filtres de dessin et d’effet grâce à l’abonnement Premium ou à l’avantage correspondant.';

  @override
  String get premiumBannerAutomationBody =>
      'Créez, modifiez et exécutez des automatisations avec l’abonnement Premium ou l’avantage Automatisations.';

  @override
  String get premiumBannerMembershipDetails =>
      'En savoir plus sur l’abonnement Premium';

  @override
  String get premiumBannerBenefitDetails => 'En savoir plus sur les avantages';

  @override
  String get premiumPackHalfPrice =>
      'Pack complet à la moitié du total à l’unité';

  @override
  String get premiumPackPriceBasis =>
      'Comparaison avec l’échange de chaque avantage séparément pour la même durée.';

  @override
  String get exportKeepsPlaybackTime =>
      'Changer la cadence d’export conserve la durée de lecture.';

  @override
  String get exportLongProjectNote =>
      'L’export intégral d’un projet de plus de 90 secondes nécessite Premium ou l’avantage de durée étendue. Vous pouvez exporter les 90 premières secondes.';

  @override
  String exportOutputWithoutEndCard(String duration) {
    return 'Vidéo principale $duration (sans marque de fin)';
  }

  @override
  String exportOutputWithEndCard(String duration) {
    return 'Vidéo principale $duration + marque de fin NIARIM (5 secondes)';
  }

  @override
  String exportOutputWithCornerLogo(String duration) {
    return 'Vidéo principale $duration (logo NIARIM dans un coin)';
  }

  @override
  String get exportProjectNotFoundError => 'Projet introuvable';

  @override
  String exportFailedError(String error) {
    return 'Échec de l’export : $error';
  }

  @override
  String get exportInProgressTitle => 'Export en cours';

  @override
  String get exportGifEncoding => 'Encodage du GIF…';

  @override
  String get exportCancelledSnackbar => 'Export annulé';

  @override
  String get exportCancelHint =>
      'Finalisation en cours — l’annulation sera appliquée une fois terminée';

  @override
  String get exportOutdatedAutofillTitle =>
      'Le remplissage automatique n’est pas à jour';

  @override
  String get exportOutdatedAutofillBody =>
      'Certains calques de remplissage automatique n’ont pas été mis à jour. Exporter quand même ?';

  @override
  String get exportContinueButton => 'Continuer';

  @override
  String get exportCompleteTitle => 'Export terminé';

  @override
  String exportCompleteFramesBody(int count) {
    return '$count image(s) exportée(s).';
  }

  @override
  String exportSoundsLeftOut(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count sons n’ont pas pu être ajoutés à l’export (leurs fichiers de matériau sont absents ou illisibles). La vidéo a été exportée sans eux.',
      one:
          '$count son n’a pas pu être ajouté à l’export (son fichier de matériau est absent ou illisible). La vidéo a été exportée sans lui.',
    );
    return '$_temp0';
  }

  @override
  String exportVideosLeftOut(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count vidéos n’ont pas pu être affichées dans l’export (leurs fichiers de matériau sont absents ou illisibles). Rien n’a été dessiné à leur place.',
      one:
          '$count vidéo n’a pas pu être affichée dans l’export (son fichier de matériau est absent ou illisible). Rien n’a été dessiné à sa place.',
    );
    return '$_temp0';
  }

  @override
  String get exportSaveLocationHint =>
      'Dans Œuvres, sur l’écran d’accueil, recherchez le fichier par le nom du projet. Choisissez Partager pour l’enregistrer dans une app photo ou l’ouvrir dans une autre application.';

  @override
  String get exportOpenWorks => 'Ouvrir les œuvres';

  @override
  String get exportBackToProjectsButton => 'Retour aux projets';

  @override
  String get exportBackToTimelineButton => 'Retour à la timeline';

  @override
  String get exportAnotherButton => 'Exporter à nouveau';

  @override
  String get newProjectScreenTitle => 'Nouveau projet';

  @override
  String get newProjectDefaultName => 'Nouveau projet';

  @override
  String get newProjectNameLabel => 'Nom du projet';

  @override
  String get newProjectSizeLabel => 'Taille';

  @override
  String get newProjectPresetFullHd =>
      'Full HD (16:9 – pour YouTube et autres vidéos horizontales)';

  @override
  String get newProjectPresetHd => 'HD (16:9 – version légère)';

  @override
  String get newProjectPresetSquare => '1:1 Carré (pour Twitter/Instagram)';

  @override
  String get newProjectPresetVertical =>
      '9:16 Vertical (pour YouTube Shorts/Reels/Stories)';

  @override
  String get newProjectPresetPortrait =>
      '4:5 Portrait (pour les posts du fil Instagram)';

  @override
  String get newProjectPresetAnalog =>
      '4:3 (format de diffusion analogique classique)';

  @override
  String get newProjectCustomSize => 'Personnalisé';

  @override
  String get newProjectMaxEdgeHint =>
      'Le côté le plus long peut être défini jusqu’à 1920 px';

  @override
  String get newProjectWidthLabel => 'Largeur (px)';

  @override
  String get newProjectHeightLabel => 'Hauteur (px)';

  @override
  String get newProjectWidthShort => 'Largeur';

  @override
  String get newProjectHeightShort => 'Hauteur';

  @override
  String get newProjectSizePresetManageButton => 'Réglages de taille';

  @override
  String get newProjectSaveCustomSizeButton => 'Enregistrer cette taille';

  @override
  String get newProjectSaveCustomSizeDialogTitle =>
      'Saisissez un nom pour cette taille';

  @override
  String get newProjectSaveCustomSizeNameLabel => 'Nom de la taille';

  @override
  String get newProjectSaveCustomSizeSavedSnackbar => 'Taille enregistrée';

  @override
  String get canvasSizePresetManageScreenTitle => 'Réglages de taille';

  @override
  String get canvasSizePresetEmpty => 'Aucune taille enregistrée';

  @override
  String get canvasSizePresetEmptyHint =>
      'Indiquez une taille personnalisée dans l’écran de nouveau projet puis appuyez sur « Enregistrer cette taille » pour l’ajouter';

  @override
  String get canvasSizePresetEditDialogTitle => 'Modifier la taille';

  @override
  String newProjectDurationLabel(String max) {
    return 'Durée (max $max)';
  }

  @override
  String newProjectDurationLabelWithPremiumHint(String max) {
    return 'Durée (max $max ; jusqu’à 2 heures avec Premium)';
  }

  @override
  String newProjectDurationSeconds(int n) {
    return '$n s';
  }

  @override
  String get newProjectDurationUnit => 's';

  @override
  String newProjectDurationHms(int h, int m, int s) {
    return '$h h $m min $s s';
  }

  @override
  String newProjectDurationHm(int h, int m) {
    return '$h h $m min';
  }

  @override
  String newProjectDurationH(int h) {
    return '$h h';
  }

  @override
  String newProjectDurationMs(int m, int s) {
    return '$m min $s s';
  }

  @override
  String newProjectDurationM(int m) {
    return '$m min';
  }

  @override
  String get newProjectBackgroundColorLabel => 'Couleur de fond';

  @override
  String get newProjectDrawingAreaTitle => 'Agrandir la zone de dessin';

  @override
  String get newProjectDrawingAreaSubtitle =>
      'Ajoute une zone où dessiner en dehors du cadre d’exportation';

  @override
  String get newProjectScaleLabel => 'Échelle';

  @override
  String newProjectScaleValue(String value) {
    return '$value×';
  }

  @override
  String newProjectDrawableAreaInfo(String width, String scale, String result) {
    return 'Zone dessinable : $width×$scale = $result';
  }

  @override
  String newProjectTotalFrames(int count) {
    return 'Nombre total d’images : $count';
  }

  @override
  String newProjectExportSizeInfo(String size) {
    return 'Taille d’exportation : $size';
  }

  @override
  String newProjectDrawingAreaInfo(String size) {
    return 'Zone de dessin : $size';
  }

  @override
  String get colorPickerTitle => 'Sélection de couleur';

  @override
  String get colorPickerOpacityLabel => 'Opacité';

  @override
  String get colorPickerHexCopiedSnackbar => 'Code HEX copié';

  @override
  String get colorPickerRecentColorsLabel => 'Couleurs récentes';

  @override
  String get colorPickerRecentColorsEmpty => 'Aucune pour l’instant';

  @override
  String get colorPickerPaletteLabel => 'Palette';

  @override
  String get colorPickerNewPaletteTooltip => 'Nouvelle palette';

  @override
  String get colorPickerManagePaletteTooltip => 'Gérer la palette';

  @override
  String get colorPickerPaletteEmptyHint =>
      'Pas encore de couleurs. Appuyez sur « + » pour ajouter la couleur actuelle.';

  @override
  String get colorPickerPaletteLongPressHint => 'Appui long pour supprimer';

  @override
  String get colorPickerAddCurrentColorButton =>
      'Ajouter la couleur actuelle à la palette';

  @override
  String get colorPickerPaletteNameLabel => 'Nom de la palette';

  @override
  String get colorPickerFavoriteAdd => 'Ajouter aux favoris';

  @override
  String get colorPickerFavoriteRemove => 'Retirer des favoris';

  @override
  String get penSubToolTabBrush => 'Pinceau';

  @override
  String get penSubToolTabTone => 'Trame';

  @override
  String get penSubToolTabStamp => 'Tampon';

  @override
  String get penSubToolTabLassoFill => 'Remplissage au lasso';

  @override
  String get penSubToolToneTooltipMessage =>
      'Choisissez une trame pour peindre des motifs de trame avec le pot de peinture ou la plume.';

  @override
  String get penSubToolStampTooltipMessage =>
      'Placez des tampons de forme fixe. Appuyez longuement pour régler la rotation, la densité, etc.';

  @override
  String penSubToolBrushSizeOpacity(int size, int opacity) {
    return '${size}px · $opacity%';
  }

  @override
  String get brushSearchHint => 'Rechercher par nom de pinceau';

  @override
  String get brushEmpty => 'Aucun pinceau';

  @override
  String get brushCreateDialogTitle => 'Pinceau personnalisé';

  @override
  String brushExportFailedSnackbar(String error) {
    return 'Échec de l’exportation du pinceau : $error';
  }

  @override
  String get brushSettingsSizeLabel => 'Taille';

  @override
  String get brushSettingsOpacityLabel => 'Opacité';

  @override
  String get brushSettingsSpacingLabel => 'Espacement';

  @override
  String get brushSettingsBlurRadiusLabel => 'Rayon de flou';

  @override
  String get brushSettingsPixelModeTitle => 'Mode pixel';

  @override
  String get brushSettingsFadeModeTitle => 'Fondu';

  @override
  String get brushSettingsFadeOff => 'Désactivé';

  @override
  String get brushSettingsFadeWeak => 'Faible';

  @override
  String get brushSettingsFadeMedium => 'Moyen';

  @override
  String get brushSettingsFadeStrong => 'Fort';

  @override
  String get brushSettingsFadeCustom => 'Personnalisé';

  @override
  String get brushSettingsFadeStartValueLabel => 'Valeur de début (%)';

  @override
  String get brushSettingsFadeEndValueLabel => 'Valeur de fin (%)';

  @override
  String get brushSettingsFadeDistanceLabel => 'Distance (px)';

  @override
  String get brushSettingsTaperModeTitle => 'Effilage';

  @override
  String get brushSettingsTaperStartValueLabel => 'Épaisseur d’entrée (%)';

  @override
  String get brushSettingsTaperStartDistanceLabel => 'Distance d’entrée (px)';

  @override
  String get brushSettingsTaperEndValueLabel => 'Épaisseur de sortie (%)';

  @override
  String get brushSettingsTaperEndDistanceLabel => 'Distance de sortie (px)';

  @override
  String get brushSettingsStrokeDecayTitle => 'Atténuation du trait';

  @override
  String get brushSettingsStrokeDecaySubtitle =>
      'L’opacité diminue plus vous dessinez longtemps';

  @override
  String get brushSettingsMixingTitle => 'Mode de mélange';

  @override
  String get brushSettingsMixingOff => 'Numérique';

  @override
  String get brushSettingsMixingOil => 'Mélange façon huile';

  @override
  String get brushSettingsMixingWatercolor => 'Mélange façon aquarelle';

  @override
  String get brushSettingsMixingBrightnessCorrection =>
      'Correction de luminosité';

  @override
  String get brushSettingsMixingAmount => 'Degré de mélange';

  @override
  String get brushSettingsMixingStretch => 'Étirement de la couleur';

  @override
  String get brushSettingsMixingWater => 'Quantité d’eau';

  @override
  String get brushSettingsMixingPigment => 'Quantité de pigment';

  @override
  String get brushSettingsMixingBleed => 'Diffusion';

  @override
  String get brushSettingsMixingTexture => 'Texture';

  @override
  String get brushSettingsMixingSoftEdge => 'Bord doux';

  @override
  String get brushSettingsMixingOilHint =>
      'Se mélange aux couleurs du dessous comme de la peinture et étire la couleur ramassée le long du trait.';

  @override
  String get brushSettingsMixingWatercolorHint =>
      'Peint avec la couleur choisie. Sur une autre peinture, la couleur se superpose comme une peinture transparente et s’y mélange. Quand vous levez le stylet, le lavis sèche et se diffuse au-delà du pinceau. Plus d’eau le rend plus clair et plus transparent, le fait se fondre davantage dans les couleurs du dessous et l’étend plus loin. Moins d’eau donne un tracé net, qui se mélange peu et s’étend à peine. Pour que la couleur s’accumule sur le bord, appliquez le filtre de dessin « Bord aquarelle ».';

  @override
  String get projectDetailNotFoundTitle => 'Projet';

  @override
  String get projectDetailNotFoundBody => 'Projet introuvable';

  @override
  String get projectDetailFirstFrameTooltip => 'Première image';

  @override
  String get projectDetailPrevFrameTooltip => 'Reculer d’une image';

  @override
  String get projectDetailPauseTooltip => 'Pause';

  @override
  String get projectDetailPlayTooltip => 'Lecture';

  @override
  String get projectDetailNextFrameTooltip => 'Avancer d’une image';

  @override
  String get projectDetailLastFrameTooltip => 'Dernière image';

  @override
  String get projectDetailFullscreenTooltip =>
      'Afficher l’aperçu en plein écran';

  @override
  String get projectDetailFullscreenCloseTooltip =>
      'Fermer l’aperçu plein écran';

  @override
  String get projectDetailStartEditButton => 'Commencer l’édition';

  @override
  String get projectDetailTagsQuickAction => 'Étiquettes';

  @override
  String get projectDetailShareQuickAction => 'Partager';

  @override
  String get projectDetailFavoriteRegistered => 'Dans les favoris';

  @override
  String get projectDetailFavoriteUnregistered => 'Pas dans les favoris';

  @override
  String get projectDetailInfoSectionTitle => 'Infos du projet';

  @override
  String get projectDetailInfoExportSize => 'Taille d’exportation';

  @override
  String get projectDetailInfoDrawingArea => 'Zone de dessin';

  @override
  String projectDetailInfoDrawingAreaValue(String size, String scale) {
    return '$size  ($scale)';
  }

  @override
  String get projectDetailInfoTotalFrames => 'Nombre total d’images';

  @override
  String get projectDetailInfoWorkTime => 'Temps de travail';

  @override
  String get projectDetailInfoLastSaved => 'Dernier enregistrement';

  @override
  String get projectDetailInfoSize => 'Taille';

  @override
  String get projectDetailAddTagHint => 'Ajouter une étiquette';

  @override
  String projectDetailNiashareFailedSnackbar(String error) {
    return 'Échec de la création du .niashare : $error';
  }

  @override
  String projectNiashareSavedNotShared(String reason) {
    return 'Le fichier partagé a été créé et enregistré dans « Créés par moi », dans Partagés. $reason';
  }

  @override
  String get projectDetailTrashMenuItem => 'Mettre à la corbeille';

  @override
  String get commonOff => 'Désactivé';

  @override
  String get perfSettingsScreenTitle => 'Paramètres de performance';

  @override
  String get perfSettingsQualitySection => 'Paramètres de qualité';

  @override
  String get perfSettingsQualityLow => 'Faible';

  @override
  String get perfSettingsQualityMedium => 'Moyenne';

  @override
  String get perfSettingsQualityHigh => 'Élevée';

  @override
  String get perfSettingsQualityCustom => 'Personnalisé';

  @override
  String get perfSettingsQualityDescLow =>
      'Pour un appareil où vous voulez alléger les performances (1 image de papier calque de chaque côté, 5 emplacements de sauvegarde)';

  @override
  String get perfSettingsQualityDescMedium =>
      'Pour un appareil courant (3 images de papier calque de chaque côté, 10 emplacements de sauvegarde)';

  @override
  String get perfSettingsQualityDescHigh =>
      'Pour un appareil avec de la marge de performance (5 images de papier calque de chaque côté, sauvegardes en arborescence)';

  @override
  String get perfSettingsQualityDescCustom =>
      'Réglez chaque paramètre individuellement';

  @override
  String get perfSettingsCapacitySection =>
      'Paramètres liés au stockage et aux performances';

  @override
  String get perfSettingsUndoLimitTitle => 'Nombre d’annulations';

  @override
  String get perfSettingsUndoLimitSubtitle =>
      'Plus il est élevé, plus il consomme de mémoire';

  @override
  String perfSettingsUndoLimitValue(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n étapes',
      one: '$n étape',
    );
    return '$_temp0';
  }

  @override
  String get perfSettingsTrashAutoDeleteTitle =>
      'Suppression automatique de la corbeille';

  @override
  String get perfSettingsTrashAutoDeleteSubtitle =>
      'Durée de conservation des projets et des fichiers dans la corbeille';

  @override
  String perfSettingsTrashApplyConfirm(int count) {
    return 'Ce réglage supprime définitivement dès maintenant $count éléments arrivés à expiration dans la corbeille.';
  }

  @override
  String perfSettingsTrashApplied(int count) {
    return '$count éléments arrivés à expiration ont été supprimés définitivement de la corbeille.';
  }

  @override
  String homeTrashDaysUntilPermanentDelete(int days) {
    return 'Suppression automatique dans $days j';
  }

  @override
  String get perfSettingsTrashAutoDeleteOff => 'Désactivée';

  @override
  String perfSettingsTrashAutoDeleteValue(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n jours',
      one: '$n jour',
    );
    return '$_temp0';
  }

  @override
  String get perfSettingsCurrentSettingsSection => 'Paramètres actuels';

  @override
  String get perfSettingsTiltLabel => 'Détection de l’inclinaison';

  @override
  String get perfSettingsTiltOn => 'Activée';

  @override
  String get perfSettingsTiltOff => 'Désactivée';

  @override
  String get perfSettingsOnionPrevLabel => 'Papier calque (avant)';

  @override
  String get perfSettingsOnionNextLabel => 'Papier calque (après)';

  @override
  String perfSettingsOnionFrameCountValue(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n images',
      one: '$n image',
    );
    return '$_temp0';
  }

  @override
  String get perfSettingsSaveModeLabel => 'Mode de sauvegarde';

  @override
  String get perfSettingsSlotCountLabel => 'Nombre d’emplacements';

  @override
  String perfSettingsSlotCountValue(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n emplacements',
      one: '$n emplacement',
    );
    return '$_temp0';
  }

  @override
  String get perfSettingsResetButton => 'Réinitialiser aux valeurs par défaut';

  @override
  String get perfSettingsCopyPresetButton => 'Copier depuis un préréglage';

  @override
  String get perfSettingsTiltSwitchTitle =>
      'Appliquer l’inclinaison du stylet au pinceau';

  @override
  String get perfSettingsShowPrevOnionTitle => 'Afficher l’image précédente';

  @override
  String get perfSettingsOnionCountPrevLabel =>
      'Nombre d’images du papier calque (avant)';

  @override
  String get perfSettingsShowNextOnionTitle => 'Afficher l’image suivante';

  @override
  String get perfSettingsOnionCountNextLabel =>
      'Nombre d’images du papier calque (après)';

  @override
  String get perfSettingsSaveModeSlot => 'Par emplacements';

  @override
  String get perfSettingsSaveModeTree => 'Par arborescence';

  @override
  String get perfSettingsResetDialogTitle =>
      'Réinitialiser les paramètres de qualité personnalisés aux valeurs par défaut ?';

  @override
  String perfSettingsResetDialogBody(String preset) {
    return 'Les valeurs par défaut correspondent au réglage « $preset » déterminé automatiquement au premier lancement selon les performances de l’appareil.';
  }

  @override
  String get perfSettingsResetConfirmButton => 'Réinitialiser';

  @override
  String get perfSettingsCopyPresetDialogTitle =>
      'Choisir un préréglage à copier';

  @override
  String get perfSettingsCopyPresetDialogBody =>
      'Choisissez un préréglage à copier dans vos paramètres personnalisés.';

  @override
  String get perfSettingsCopyDescLow =>
      'Affiche 1 image de chaque côté · léger';

  @override
  String get perfSettingsCopyDescMedium =>
      'Affiche 3 images de chaque côté · standard';

  @override
  String get perfSettingsCopyDescHigh =>
      'Affiche 5 images de chaque côté · haute qualité';

  @override
  String get filterPanelTitle => 'Filtre';

  @override
  String filterPanelTitleBulk(int count) {
    return 'Filtre (appliqué à $count images)';
  }

  @override
  String get filterSearchHint => 'Rechercher un filtre';

  @override
  String get filterNameGaussianBlur => 'Flou gaussien';

  @override
  String get filterNameLensBlur => 'Flou d’objectif';

  @override
  String get filterNameAnimeStyle => 'Style anime';

  @override
  String get filterNameOutline => 'Contour';

  @override
  String get filterNameInvert => 'Inverser les couleurs';

  @override
  String get filterNameToneCurve => 'Courbe de tons';

  @override
  String get filterNameLevels => 'Niveaux';

  @override
  String get filterNameSharpen => 'Netteté';

  @override
  String get filterNameUnsharpMask => 'Masque flou';

  @override
  String get filterSharpenStrength => 'Force de netteté';

  @override
  String get filterUnsharpAmount => 'Intensité';

  @override
  String get filterNameVignette => 'Vignettage';

  @override
  String get filterVignetteRange => 'Portée';

  @override
  String get filterVignetteDensity => 'Intensité';

  @override
  String get filterVignetteHint =>
      'Portée : jusqu’où l’assombrissement s’étend des coins vers le centre. Intensité : à quel point les coins s’assombrissent.';

  @override
  String get filterVignetteColor => 'Couleur du vignettage';

  @override
  String get filterNameNoise => 'Grain de film';

  @override
  String get filterNoiseStrength => 'Intensité du grain';

  @override
  String get filterNameRetroAnime => 'Anime rétro';

  @override
  String get filterNameCrt => 'Tube cathodique';

  @override
  String get filterRetroStrength => 'Intensité';

  @override
  String get filterCrtScreenStrength => 'Lignes de balayage et phosphore';

  @override
  String get filterCrtAberration => 'Décalage des couleurs';

  @override
  String get filterCrtBleed => 'Bavure du faisceau';

  @override
  String filterOutlineLayerNameSuffix(String name) {
    return '$name (Contour)';
  }

  @override
  String get filterStrengthBlurRadius => 'Intensité (rayon de flou)';

  @override
  String get filterColorLevels => 'Nombre de couleurs';

  @override
  String get filterEdgeStrength => 'Intensité du trait';

  @override
  String get filterAnimeBorderWidth => 'Épaisseur de bordure';

  @override
  String get filterAnimeBorderThreshold => 'Seuil de différence de couleur';

  @override
  String get filterAnimeBorderHint =>
      'Un trait est tracé du côté le plus sombre de chaque limite où les couleurs diffèrent d’au moins ce seuil. Une épaisseur de 0 n’en trace aucun.';

  @override
  String get filterOutlineColor => 'Couleur du contour';

  @override
  String get filterOutlineWidth => 'Épaisseur du contour';

  @override
  String get filterOutlineErosion =>
      'Empiètement vers l’intérieur (0 = seulement hors du bord d’origine)';

  @override
  String get filterToneCurveLinear => 'Standard';

  @override
  String get filterToneCurveBrighten => 'Éclaircir';

  @override
  String get filterToneCurveDarken => 'Assombrir';

  @override
  String get filterToneCurveHighContrast => 'Contraste élevé';

  @override
  String get filterToneCurveLowContrast => 'Contraste faible';

  @override
  String get filterToneCurveInvert => 'Inverser';

  @override
  String get filterToneCurveHint =>
      'Touchez une zone vide de la courbe pour ajouter un point, faites glisser un point pour le déplacer et appuyez longuement sur un point (sauf les deux extrémités) pour le supprimer. R, G et B sont des courbes propres à chaque couleur, appliquées après la courbe RGB.';

  @override
  String get filterLevelsInputBlack => 'Entrée : Noir';

  @override
  String get filterLevelsInputWhite => 'Entrée : Blanc';

  @override
  String get filterLevelsGamma => 'Gamma';

  @override
  String get filterLevelsOutputBlack => 'Sortie : Noir';

  @override
  String get filterLevelsOutputWhite => 'Sortie : Blanc';

  @override
  String get filterLevelsHint =>
      'R, G et B règlent chaque couleur séparément, après les réglages RGB. Le gamma modifie les tons moyens (au-dessus de 1, plus clair ; en dessous, plus sombre).';

  @override
  String get filterApplyButton => 'Appliquer';

  @override
  String filterApplyBulkButton(int count) {
    return 'Appliquer à $count images';
  }

  @override
  String get filterEmpty => 'Aucun filtre';

  @override
  String get filterReorder => 'Réorganiser';

  @override
  String get filterReorderDone => 'Terminer la réorganisation';

  @override
  String get filterReorderReset => 'Revenir à l’ordre initial';

  @override
  String get filterReorderHint =>
      'Faites glisser la poignée à droite d’une ligne pour réorganiser.';

  @override
  String get filterApplyingTitle => 'Application du filtre';

  @override
  String filterApplyingSubtitle(String name, int count) {
    return '$name　$count images';
  }

  @override
  String get projectListNewFolderTitle => 'Nouveau dossier';

  @override
  String get projectListFolderHint =>
      'Vous pouvez aussi l’utiliser pour regrouper plusieurs épisodes ou une série d’une même œuvre';

  @override
  String get projectListEmptyTitle => 'Aucun projet';

  @override
  String get projectListEmptyHint => 'Appuyez sur + pour en créer un';

  @override
  String get projectListOpenAction => 'Ouvrir';

  @override
  String get projectListCreateShareAction => 'Créer un .niashare';

  @override
  String get projectListEditFolderAction => 'Modifier le nom et la couleur';

  @override
  String get projectListDeleteFolderConfirmTitle => 'Supprimer ce dossier ?';

  @override
  String get projectListFolderRootOption => 'Aucun dossier (racine)';

  @override
  String get projectListEditFolderTooltip => 'Modifier le dossier';

  @override
  String get projectListCreateFolderAction => 'Créer un nouveau dossier';

  @override
  String get projectListFolderColorLabel => 'Couleur du dossier';

  @override
  String get projectListMaterialIncludeTitle => 'Inclure les fichiers';

  @override
  String get projectListMaterialIncludeHint =>
      'Si non inclus, le destinataire verra un avertissement de fichiers manquants.';

  @override
  String get projectListMaterialImage => 'Images';

  @override
  String get projectListMaterialVideo => 'Vidéos';

  @override
  String get projectListMaterialAudio => 'Audio';

  @override
  String get projectListShareFontNamesHint =>
      'Seuls les noms des polices ajoutées utilisées dans ce projet sont partagés. Installez-les séparément sur l’appareil destinataire.';

  @override
  String get blendModeNormal => 'Normal';

  @override
  String get blendModeMultiply => 'Produit';

  @override
  String get blendModeScreen => 'Écran';

  @override
  String get blendModeOverlay => 'Incrustation';

  @override
  String get blendModeAddition => 'Addition (lueur)';

  @override
  String get blendModeSubtract => 'Soustraction';

  @override
  String get blendModeDarken => 'Obscurcir';

  @override
  String get blendModeLighten => 'Éclaircir';

  @override
  String get blendModeColorBurn => 'Densité couleur +';

  @override
  String get blendModeColorDodge => 'Densité couleur -';

  @override
  String get blendModeHardLight => 'Lumière crue';

  @override
  String get blendModeSoftLight => 'Lumière tamisée';

  @override
  String get blendModeDifference => 'Différence';

  @override
  String get blendModeHue => 'Teinte';

  @override
  String get blendModeSaturation => 'Saturation';

  @override
  String get blendModeColor => 'Couleur';

  @override
  String get blendModeLuminosity => 'Luminosité';

  @override
  String get blendModeLinearBurn => 'Densité linéaire +';

  @override
  String get blendModeLinearDodge => 'Densité linéaire -';

  @override
  String get blendModeVividLight => 'Lumière vive';

  @override
  String get blendModeLinearLight => 'Lumière linéaire';

  @override
  String get blendModePinLight => 'Lumière ponctuelle';

  @override
  String get blendModeHardMix => 'Mélange maximal';

  @override
  String get blendModeExclusion => 'Exclusion';

  @override
  String get blendModeDivide => 'Division';

  @override
  String get autofillLineColorModeSpecified => 'Couleur spécifiée';

  @override
  String get autofillLineColorModeSameAsFill => 'Identique au remplissage';

  @override
  String get autofillLineColorModeTraceAdjust =>
      'Trace de couleur / fondu avec le trait';

  @override
  String get autofillGradientTypeLinear => 'Linéaire';

  @override
  String get autofillGradientTypeRadialCenterOut =>
      'Radial : centre → extérieur';

  @override
  String get autofillGradientTypeRadialOutCenter =>
      'Radial : extérieur → centre';

  @override
  String get autofillSampleGray => 'Sous-couche grise';

  @override
  String get autofillSampleLead => 'Personnage principal';

  @override
  String get autofillSampleHeroine => 'Héroïne';

  @override
  String get autofillSamplePartUnderpaint => 'Sous-couche';

  @override
  String get autofillSamplePartHair => 'Cheveux';

  @override
  String get autofillSamplePartSkin => 'Peau';

  @override
  String get autofillSamplePartTop => 'Haut';

  @override
  String get autofillSamplePartBottom => 'Bas';

  @override
  String get autofillSamplePartShoes => 'Chaussures';

  @override
  String get autofillSamplePartRibbon => 'Ruban';

  @override
  String get autofillSamplePartEyeWhite => 'Blanc de l’œil';

  @override
  String get autofillSamplePartPupil => 'Pupille';

  @override
  String get autofillSamplePartIris => 'Iris';

  @override
  String get autofillSamplePartCatchlight => 'Reflet de l’œil';

  @override
  String autofillSamplePartShadow(String part, int number) {
    return '$part – ombre $number';
  }

  @override
  String autofillSamplePartHighlight(String part) {
    return '$part – reflet';
  }

  @override
  String get autofillPresetScreenTitle => 'Réglages de remplissage auto';

  @override
  String get autofillPresetSearchHint => 'Rechercher des réglages';

  @override
  String get autofillPresetEmptyFavorites => 'Aucun réglage favori';

  @override
  String get autofillPresetEmpty => 'Aucun réglage';

  @override
  String get autofillPresetEmptyHint =>
      'Appuyez sur + en bas à droite pour en créer un';

  @override
  String autofillPresetPartsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parties',
      one: '$count partie',
    );
    return '$_temp0';
  }

  @override
  String get autofillPresetNewDialogTitle => 'Nouveau';

  @override
  String get autofillPresetNameLabel => 'Nom du réglage';

  @override
  String get autofillPresetRenameDialogTitle => 'Renommer le réglage';

  @override
  String autofillPresetDeleteConfirmTitle(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get autofillFabImportOption => 'Importer';

  @override
  String get autofillPresetExportMenuItem => 'Exporter (.niafill)';

  @override
  String autofillPresetImportSuccessSnackbar(int count) {
    return '$count réglage(s) importé(s)';
  }

  @override
  String autofillPresetImportFailedSnackbar(String error) {
    return 'Échec de l’importation : $error';
  }

  @override
  String autofillPresetExportFailedSnackbar(String error) {
    return 'Échec de l’exportation : $error';
  }

  @override
  String autofillPresetDuplicateName(String name) {
    return '$name (copie)';
  }

  @override
  String get autofillPartSearchHint => 'Rechercher par nom de partie';

  @override
  String autofillPartUnconfiguredBanner(int count, String names) {
    return '$count partie(s) ne sont pas encore configurées : $names (aucune trame sélectionnée)';
  }

  @override
  String autofillDeleteUsage(int projects, int layers) {
    String _temp0 = intl.Intl.pluralLogic(
      projects,
      locale: localeName,
      other: '$projects projets',
      one: '$projects projet',
    );
    String _temp1 = intl.Intl.pluralLogic(
      layers,
      locale: localeName,
      other: '$layers calques de tracé',
      one: '$layers calque de tracé',
    );
    return 'Cela concerne $_temp0 et $_temp1. Affectez une autre partie avant de lancer le remplissage automatique sur ces calques.';
  }

  @override
  String get autofillPartEmpty =>
      'Aucune partie\nAppuyez sur + pour en ajouter une';

  @override
  String get autofillPartToneUnselected => 'Aucune trame sélectionnée';

  @override
  String get autofillPartAddDialogTitle => 'Ajouter une partie';

  @override
  String get autofillPartNameLabel => 'Nom de la partie';

  @override
  String get autofillPartAddButton => 'Ajouter';

  @override
  String get autofillPartRenameDialogTitle => 'Renommer la partie';

  @override
  String autofillPartDetailDialogTitle(String name) {
    return 'Détails de $name';
  }

  @override
  String get autofillPartFillColorLabel => 'Couleur de remplissage';

  @override
  String get autofillPartSelectColorButton => 'Choisir une couleur';

  @override
  String get autofillPartOutlineLabel => 'Contour avec une couleur définie';

  @override
  String autofillPartOutlineWidthLabel(int value) {
    return 'Épaisseur du contour : ${value}px';
  }

  @override
  String autofillPartLineGapLabel(int value) {
    return 'Combler l’écart entre traits et aplat : $value';
  }

  @override
  String get autofillPartLineGapHint =>
      'Plus la valeur est élevée, plus le remplissage passe sous le bord adouci des traits et plus l’écart entre le trait et l’aplat se réduit (utile quand un contour ou une couleur de trait identique à l’aplat rend l’écart visible).';

  @override
  String get autofillEyedropperFromThumbnailButton => 'Prélever depuis l’image';

  @override
  String get autofillEyedropperDialogTitle =>
      'Prélever une couleur depuis l’image';

  @override
  String get autofillEyedropperDialogHint =>
      'Touchez l’image pour choisir une couleur';

  @override
  String get autofillEyedropperPickedLabel => 'Couleur choisie';

  @override
  String get autofillEyedropperImageLoadFailedSnackbar =>
      'Impossible de charger l’image.';

  @override
  String get autofillThumbnailMenuItem => 'Définir l’image miniature';

  @override
  String get autofillThumbnailLoadButton => 'Charger une image';

  @override
  String get autofillThumbnailDeleteButton => 'Supprimer l’image miniature';

  @override
  String get autofillThumbnailDeleteConfirmTitle =>
      'Supprimer l’image miniature ?';

  @override
  String get autofillThumbnailDeleteConfirmBody =>
      'Cela revient à l’affichage des couleurs par défaut (jusqu’à 4 couleurs).';

  @override
  String get autofillThumbnailCropDialogTitle => 'Ajuster l’image miniature';

  @override
  String get autofillThumbnailCropDialogHint =>
      'Glissez pour déplacer, pincez pour zoomer, tournez à deux doigts pour pivoter';

  @override
  String get autofillThumbnailCropLoadFailed =>
      'Impossible de charger l’image. Essayez-en une autre.';

  @override
  String get autofillThumbnailSetSnackbar => 'Image miniature définie';

  @override
  String get autofillPartGradientSetButton => 'Définir le dégradé';

  @override
  String get autofillPartGradientEditButton => 'Modifier le dégradé';

  @override
  String autofillPartFillOpacityLabel(int value) {
    return 'Opacité (calque de remplissage) : $value%';
  }

  @override
  String get autofillPartLineColorLabel => 'Couleur du trait';

  @override
  String autofillPartTraceHueLabel(int value) {
    return 'Teinte : $value';
  }

  @override
  String autofillPartTraceSaturationLabel(int value) {
    return 'Saturation : $value';
  }

  @override
  String autofillPartTraceLightnessLabel(int value) {
    return 'Luminosité : $value';
  }

  @override
  String autofillPartLineOpacityLabel(int value) {
    return 'Opacité (calque de trait) : $value%';
  }

  @override
  String get autofillPartToneLabel => 'Trame';

  @override
  String get autofillPartUseToneCheckbox => 'Utiliser une trame';

  @override
  String get autofillPartBlendModeLabel => 'Mode de fusion';

  @override
  String get autofillPartApplyButton => 'Appliquer';

  @override
  String autofillPartGradientDialogTitle(String name) {
    return 'Dégradé de $name';
  }

  @override
  String get autofillPartGradientTypeLabel => 'Type';

  @override
  String get autofillPartGradientTypeInfo =>
      'Linéaire : la couleur change selon l’angle défini. Radial centre→extérieur : les couleurs changent du centre vers l’extérieur. Radial extérieur→centre : l’inverse.';

  @override
  String get autofillPartGradientFeatherInfo =>
      'À 0%, la limite entre les couleurs adjacentes est nette. À 100%, les couleurs se fondent complètement et en douceur jusqu’au bord de la couleur voisine.';

  @override
  String get autofillLineColorModeTraceAdjustInfo =>
      'Conserve la couleur d’origine du trait mais en décale légèrement la teinte, la saturation et la luminosité. À utiliser pour garder les nuances du dessin au trait plutôt que de le remplir d’une couleur unie.';

  @override
  String autofillPartGradientAngleLabel(int value) {
    return 'Angle : $value°';
  }

  @override
  String get autofillPartGradientColorLabel => 'Couleurs';

  @override
  String get autofillPartGradientAddColorButton => 'Ajouter une couleur';

  @override
  String get autofillPartGradientRemoveButton => 'Supprimer le dégradé';

  @override
  String autofillPartGradientFeatherLabel(int value) {
    return 'Intensité du flou : $value%';
  }

  @override
  String get autofillPartGradientDragHint =>
      'Faites glisser la poignée à droite pour réorganiser les couleurs';

  @override
  String autofillPartGradientStopLabel(int value) {
    return 'Position : $value%';
  }

  @override
  String get autofillPartGradientStopDragHint =>
      'Faites glisser les repères ▲ pour ajuster la position des couleurs. Le dégradé couvre toute la zone de remplissage de la partie.';

  @override
  String get saveTreeScreenTitleTree => 'Arbre de sauvegarde';

  @override
  String get saveTreeScreenTitleSlot => 'Emplacements de sauvegarde';

  @override
  String get timelineExportMenuItem => 'Exporter';

  @override
  String get timelineExportFrameMenuItem => 'Exporter l’image en PNG/JPEG';

  @override
  String get timelineExportFrameDialogTitle => 'Exporter l’image en PNG/JPEG';

  @override
  String get timelineExportFrameDialogMessage =>
      'Enregistre l’image actuellement affichée en tant qu’image fixe. Choisissez un format.';

  @override
  String get timelineExportFramePngOption => 'Enregistrer en PNG';

  @override
  String get timelineExportFrameJpegOption => 'Enregistrer en JPEG';

  @override
  String timelineExportFrameSuccessSnackbar(String fileName) {
    return 'Enregistré sous $fileName (consultable dans l’onglet Œuvres)';
  }

  @override
  String get timelineExportFrameErrorSnackbar =>
      'Échec de l’exportation de l’image';

  @override
  String get timelineDurationChangeMenuItem => 'Modifier la durée';

  @override
  String get timelineCanvasSizeChangeMenuItem =>
      'Modifier la taille du canevas';

  @override
  String get timelineDurationFramesLabel => 'Images';

  @override
  String get timelineDurationSecondsLabel => 'Secondes';

  @override
  String get timelineDurationShrinkConfirmTitle => 'Raccourcir quand même ?';

  @override
  String get timelineDurationShrinkConfirmBody =>
      'Raccourcir la scène supprimera les images hors de la nouvelle plage, ainsi que leurs dessins et calques. Les supprimer ?';

  @override
  String get timelineCanvasSizeDragHint =>
      'Faites glisser l’intérieur du cadre pour le déplacer, ou un coin pour le redimensionner (s’aligne près de la taille d’origine)';

  @override
  String get timelineCanvasSizeAngleLabel => 'Angle';

  @override
  String get saveTreeSaveAsChildHint =>
      'Sera enregistré à la suite de la sauvegarde sélectionnée.';

  @override
  String get saveTreeSaveAsRootHint =>
      'Sera enregistré en haut de l’arborescence, comme nouveau point de départ.';

  @override
  String get saveTreeCommentLabel => 'Note';

  @override
  String get saveTreeCommentHint => 'ex. : Arrière-plan terminé';

  @override
  String saveTreeSizeWarningSnackbar(String size) {
    return 'Votre arbre de sauvegardes devient volumineux (environ $size). Nous vous recommandons de supprimer les sauvegardes inutiles.';
  }

  @override
  String get saveTreeDeleteFailedSnackbar =>
      'Impossible de supprimer les données de sauvegarde';

  @override
  String get saveTreeMemoNotSavedSnackbar =>
      'Impossible d’enregistrer la note. Vérifiez l’espace disponible';

  @override
  String saveTreeSaveFailedSnackbar(String error) {
    return 'Échec de l’enregistrement. Vérifiez l’espace disponible et réessayez ($error)';
  }

  @override
  String get saveTreeSlotWriteTooltip => 'Enregistrer dans cet emplacement';

  @override
  String get saveTreeSlotLoadTooltip => 'Charger cet emplacement';

  @override
  String get saveTreeSlotDeleteTooltip => 'Supprimer cet emplacement';

  @override
  String saveTreeSlotSaveDialogTitle(int n) {
    return 'Enregistrer dans l’emplacement $n';
  }

  @override
  String saveTreeSlotOverwriteWarning(String date) {
    return 'Cela écrasera les données existantes ($date).';
  }

  @override
  String get saveTreeRestoreAction => 'Charger';

  @override
  String get saveTreeTimelineActionChoiceBody =>
      'Choisissez si vous voulez écraser cette sauvegarde avec le contenu actuel, ou reprendre le travail à partir d’ici.';

  @override
  String get saveTreeOverwriteAction => 'Écraser';

  @override
  String get saveTreeOverwriteConfirmBody =>
      'Cette sauvegarde sera remplacée par le projet actuel. Le contenu enregistré auparavant sera perdu. Voulez-vous continuer ?';

  @override
  String get saveTreeProjectDetailResumeBody =>
      'Reprendre le travail depuis cette sauvegarde ?\n\nLe travail actuel sera remplacé. Pour le conserver, sauvegardez-le d’abord manuellement.';

  @override
  String get saveTreeLoadFailedSnackbar =>
      'Échec du chargement des données de sauvegarde';

  @override
  String saveTreeRestoredSnackbar(String name) {
    return 'Données de sauvegarde chargées ($name)';
  }

  @override
  String saveTreeSlotLabel(int n) {
    return 'Emplacement $n';
  }

  @override
  String get saveTreeNoDataLabel => 'Aucune donnée de sauvegarde';

  @override
  String get saveTreeEmptyTitle => 'Aucune donnée de sauvegarde';

  @override
  String get saveTreeEmptyHint =>
      'Appuyez sur le bouton « Enregistrer » en haut pour créer le premier nœud';

  @override
  String get saveTreeNodeDefaultTitle => 'Sauvegarde';

  @override
  String saveTreeNodeDatedName(String date) {
    return 'Sauvegarde du $date';
  }

  @override
  String get saveTreeChangeDataTitle => 'Modifier les données de sauvegarde';

  @override
  String saveTreeChangeDataTitleWithProject(String name) {
    return 'Modifier les données de sauvegarde ($name)';
  }

  @override
  String get saveTreeChangeExceedMessage =>
      'Votre nombre actuel de sauvegardes dépasse\nla nouvelle limite.\n\nVeuillez choisir les sauvegardes à conserver.';

  @override
  String saveTreeKeepableCountLabel(int n) {
    return 'Sauvegardes conservables : $n';
  }

  @override
  String saveTreeKeepLatestButton(int n) {
    return 'Conserver les $n plus récentes';
  }

  @override
  String get saveTreeSelectDataButton => 'Choisir les données de sauvegarde';

  @override
  String saveTreeSelectedCountLabel(int selected, int limit) {
    return 'Sélectionné : $selected / $limit';
  }

  @override
  String get saveTreeBackButton => 'Retour';

  @override
  String get saveTreeNextButton => 'Suivant';

  @override
  String get saveTreeDiscardDialogTitle =>
      'Données de sauvegarde non sélectionnées';

  @override
  String get saveTreeArchiveOptionTitle =>
      'Conserver en tant qu’archive (recommandé)';

  @override
  String get saveTreeArchiveOptionSubtitle =>
      'Restauré automatiquement si vous revenez à la sauvegarde en arborescence.\nUtilise de l’espace de stockage.';

  @override
  String get saveTreeDeleteOptionTitle => 'Supprimer définitivement';

  @override
  String saveTreeDeleteOptionSubtitle(int count) {
    return 'Supprime définitivement les $count éléments non sélectionnés.\nLibère de l’espace de stockage.\nRemarque : les données supprimées ne peuvent pas être récupérées.';
  }

  @override
  String get saveTreeApplyChangeButton => 'Appliquer le changement';

  @override
  String get canvasEditMenuAutofillPresets => 'Réglages de remplissage auto';

  @override
  String get canvasEditMenuAutofillPresetsSubtitle =>
      'Modifier les combinaisons de couleur/trame de chaque partie';

  @override
  String get canvasEditMenuBackgroundToggle => 'Changer l’arrière-plan';

  @override
  String get canvasEditMenuBackgroundCurrentColor =>
      'Actuel : couleur de fond du projet (touchez pour passer en transparent)';

  @override
  String get canvasEditMenuBackgroundCurrentTransparent =>
      'Actuel : transparent (touchez pour passer à la couleur de fond du projet)';

  @override
  String get canvasEditMenuOnionSkinSubtitle =>
      'Superpose légèrement les images précédentes/suivantes';

  @override
  String get canvasEditMenuFilterSubtitle =>
      'Applique un flou, des courbes de tons, etc.';

  @override
  String get canvasEditMenuFrameMultiSelect => 'Sélection multiple d’images';

  @override
  String get canvasEditMenuFrameMultiSelectSubtitle =>
      'Pour les traitements par lot (ex. appliquer un filtre à plusieurs images)';

  @override
  String get canvasEditMenuPressureCurve =>
      'Courbe de pression et stabilisation';

  @override
  String get canvasEditMenuPressureCurveSubtitle =>
      'Ouvrir les réglages du stylet (partagés avec les réglages)';

  @override
  String get canvasEditMenuMeshTransform =>
      'Transformation libre / Déformation maillée';

  @override
  String get canvasEditMenuMeshTransformSubtitle =>
      'Transformer tout le calque sans sélection';

  @override
  String get meshTransformPanelTitle =>
      'Transformation libre / Déformation maillée';

  @override
  String get meshTransformPanelHint =>
      'Faites glisser les coins ou les points de la grille avec le doigt (pincez deux points différents avec deux doigts pour pivoter ou redimensionner)';

  @override
  String get meshTransformDensityLabel => 'Densité de grille';

  @override
  String get meshTransformRotateLabel => 'Rotation';

  @override
  String get meshTransformScaleLabel => 'Échelle';

  @override
  String get meshTransformApplyButton => 'Appliquer';

  @override
  String get canvasLassoEnclosedLabel => 'Remplir la zone fermée';

  @override
  String get canvasInvertSelectionTooltip => 'Inverser la sélection';

  @override
  String get canvasRulerFirstUseTip =>
      'La règle permet de tracer des lignes droites et des formes nettes.';

  @override
  String get canvasRulerTooltip => 'Règle';

  @override
  String get commonUndo => 'Annuler';

  @override
  String get commonRedo => 'Rétablir';

  @override
  String get canvasSettingsMenuTooltip => 'Paramètres/Édition';

  @override
  String canvasFrameSelectedCount(int selected, int total) {
    return '$selected / $total images sélectionnées';
  }

  @override
  String get canvasSelectAllButton => 'Tout sélectionner';

  @override
  String get canvasDeselectAllButton => 'Tout désélectionner';

  @override
  String get canvasSelectionFreeTransform => 'Transf. libre';

  @override
  String get canvasSelectionMeshTransform => 'Maillage';

  @override
  String get canvasSelectionRevertButton => 'Annuler';

  @override
  String get canvasSelectionRevertTooltip =>
      'Annuler la transformation et quitter la sélection';

  @override
  String get canvasSelectionApplyButton => 'Appliquer';

  @override
  String get canvasSelectionApplyTooltip =>
      'Conserver la transformation et quitter la sélection';

  @override
  String get canvasSelectionSliderMoveX => 'Déplacer X';

  @override
  String get canvasSelectionSliderMoveY => 'Déplacer Y';

  @override
  String get canvasSelectionSliderScale => 'Échelle';

  @override
  String get canvasSelectionSliderRotate => 'Rotation';

  @override
  String get canvasApplyFilterButton => 'Appliquer le filtre';

  @override
  String get canvasShapeOff => 'Désactivé (retour au pinceau normal)';

  @override
  String get canvasShapeLine => 'Ligne';

  @override
  String get canvasShapeRect => 'Rectangle';

  @override
  String get canvasShapeCircle => 'Cercle';

  @override
  String get canvasMissingMaterialsSnackbar =>
      'Certains fichiers sont manquants';

  @override
  String get canvasResearchButton => 'Rechercher à nouveau';

  @override
  String get canvasTextInputTitle => 'Saisir du texte';

  @override
  String get canvasTextEditTitle => 'Modifier le texte';

  @override
  String get canvasTextInputHint => 'Saisissez votre texte';

  @override
  String get canvasTextFontLabel => 'Police';

  @override
  String get canvasTextStandardFont => 'Police standard';

  @override
  String get canvasTextBold => 'Gras';

  @override
  String get canvasTextItalic => 'Italique';

  @override
  String get canvasTextVertical => 'Vertical';

  @override
  String get canvasTypesettingHelpTooltip =>
      'À propos de la composition et du furigana';

  @override
  String get canvasTextLineHeight => 'Interligne';

  @override
  String get canvasTextLetterSpacing => 'Espacement des lettres';

  @override
  String get canvasTextAlign => 'Alignement';

  @override
  String get canvasTextOutline => 'Contour';

  @override
  String get canvasOutlineWidthLabel => 'Épaisseur';

  @override
  String get canvasHelpRotationTitle =>
      'Rotation des caractères alphanumériques demi-chasse (vertical uniquement)';

  @override
  String get canvasHelpRotationBody =>
      'Les lettres et symboles sont automatiquement pivotés de 90° à l’affichage.';

  @override
  String get canvasHelpTatechuyokoTitle =>
      'Tate-chu-yoko (vertical uniquement)';

  @override
  String get canvasHelpTatechuyokoBody =>
      'Deux chiffres demi-chasse consécutifs se placent automatiquement côte à côte dans la hauteur d’un seul caractère (ex. : 12).';

  @override
  String get canvasHelpRubyTitle => 'Furigana (glose phonétique)';

  @override
  String canvasHelpRubyBody(String example) {
    return 'Saisir « $example » affiche une petite annotation de lecture au-dessus des caractères de base (en horizontal) ou à leur droite (en vertical). Cela fonctionne dans les deux sens, mais le texte contenant du furigana ne se retourne pas automatiquement à la ligne en mode horizontal (retours à la ligne manuels uniquement).';
  }

  @override
  String get layerPanelTitle => 'Calques';

  @override
  String get layerPanelHelpTooltip => 'Aide';

  @override
  String get layerPanelSearchHint => 'Rechercher par nom de calque';

  @override
  String get layerPanelSelectAll => 'Tout sélectionner';

  @override
  String get layerPanelDeselectAll => 'Tout désélectionner';

  @override
  String get layerPanelNewLayerButton => 'Calque normal';

  @override
  String get layerPanelNewFolderButton => 'Nouveau dossier';

  @override
  String get layerPanelImportImageButton => 'Importer une image';

  @override
  String get layerImportFit => 'Faire tenir toute l’image';

  @override
  String get layerImportFitDesc => 'Toute l’image tient sur le canevas.';

  @override
  String get layerImportFill => 'Remplir le canevas';

  @override
  String get layerImportFillDesc => 'Les parties hors du canevas sont coupées.';

  @override
  String get layerImportReplace => 'Remplacer le calque actuel';

  @override
  String get layerImportReplaceDesc =>
      'Place l’image sur le calque actuel au lieu d’un nouveau calque.';

  @override
  String layerPanelDefaultLayerName(int n) {
    return 'Calque $n';
  }

  @override
  String layerPanelDefaultFolderName(int n) {
    return 'Dossier$n';
  }

  @override
  String layerPanelDefaultLineartName(int n) {
    return 'Traits$n';
  }

  @override
  String layerPanelDefaultAutofillName(int n) {
    return 'RemplissageAuto$n';
  }

  @override
  String layerPanelDefaultCommonName(int n) {
    return 'Commun$n';
  }

  @override
  String layerPanelDefaultSelectionName(int n) {
    return 'Sélection$n';
  }

  @override
  String get layerPanelClippingBadge => 'Écrêtage';

  @override
  String get layerPanelAddTooltip => 'Autre calque';

  @override
  String get layerPanelAutofillMarkTooltip =>
      'Le dessin au trait a été mis à jour. Touchez pour actualiser le remplissage automatique.';

  @override
  String get layerPanelRangeAllFrames => 'Toutes les images';

  @override
  String get layerPanelRangeCurrentScene => 'Scène actuelle';

  @override
  String get layerPanelRangeSceneSpecified => 'Scène spécifiée';

  @override
  String layerPanelRangeFrameSpan(int start, int end) {
    return '$start–$end';
  }

  @override
  String get layerPanelMenuFrameRangeChange => 'Modifier la plage d’images';

  @override
  String get layerPanelMenuRangeChange => 'Modifier la plage d’affichage';

  @override
  String get layerPanelMenuPartAssign => 'Attribuer une partie';

  @override
  String get layerPanelMenuRunAutofill => 'Exécuter le remplissage automatique';

  @override
  String get layerPanelMenuOrphanFill =>
      'Remplir avec la couleur la plus récente';

  @override
  String get layerPanelMenuOrphanFillSubtitle =>
      'Aucun calque de trait correspondant trouvé, seule la couleur sera mise à jour';

  @override
  String get layerPanelMenuReplaceMaterial => 'Remplacer le matériau';

  @override
  String layerPanelDeleteConfirmTitle(String name) {
    return 'Supprimer $name ?';
  }

  @override
  String get layerPanelDeleteConfirmBody =>
      'Ce matériau sera supprimé de toutes les images de sa plage d’affichage.';

  @override
  String layerCommonDeleteThisFrameOnly(int n) {
    return 'Retirer de cette image (F$n) uniquement';
  }

  @override
  String get layerCommonDeleteThisFrameOnlyDesc =>
      'Les autres images le gardent.';

  @override
  String layerCommonDuplicateThisFrameOnly(int n) {
    return 'Dupliquer dans cette image (F$n) uniquement';
  }

  @override
  String get layerCommonDuplicateThisFrameOnlyDesc =>
      'Le copie dans cette image uniquement, comme calque normal.';

  @override
  String get layerPanelRangeDialogTitle => 'Plage d’affichage';

  @override
  String get layerPanelRangeStartFrameLabel => 'Image de début';

  @override
  String get layerPanelRangeEndFrameLabel => 'Image de fin';

  @override
  String get layerPanelRangeTilde => '–';

  @override
  String get layerPanelRangeUseCurrentButton =>
      'De la première à la dernière image';

  @override
  String layerPanelRangeNumberError(int count) {
    return 'Saisissez des images de début et de fin comprises entre 1 et $count.';
  }

  @override
  String get layerPanelRangeOrderError =>
      'L’image de fin doit être la même que l’image de début ou venir après.';

  @override
  String get layerPanelRangeTargetSceneLabel => 'Scène cible';

  @override
  String get layerPanelRangeFrameRangeLabel => 'Plage d’images spécifiée';

  @override
  String get layerPanelMenuNormalLayer => 'Calque normal';

  @override
  String get layerPanelMenuCommonLayer => 'Calque commun';

  @override
  String get layerPanelMenuLineartLayer =>
      'Calque de trait pour remplissage auto';

  @override
  String get layerPanelMenuAutofillLayer => 'Calque de remplissage auto';

  @override
  String get layerPanelMenuSelectionLayer => 'Calque de sélection';

  @override
  String get layerPanelOpacityLabel => 'Opacité';

  @override
  String get layerPanelLockLabel => 'Verrouiller';

  @override
  String get layerPanelOpacityLockLabel => 'Verrouiller l’opacité';

  @override
  String get canvasLayerLockedNotice =>
      'Ce calque est verrouillé : impossible de le modifier. Désactivez « Verrouiller » dans les réglages du calque.';

  @override
  String get canvasMaterialLayerNotice =>
      'Ce calque est un matériau de la timeline : impossible de le modifier sur le canevas. Modifiez le matériau dans la timeline et dessinez sur un autre calque.';

  @override
  String brushPanelDeleteConfirmTitle(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get brushPanelDeleteConfirmBody =>
      'Un pinceau supprimé ne peut pas être restauré.';

  @override
  String get brushPanelResetRememberedValues =>
      'Rétablir l’épaisseur et l’opacité par défaut';

  @override
  String numberInputRangeError(String min, String max) {
    return 'Saisissez un nombre entre $min et $max';
  }

  @override
  String get layerPanelClippingDescription =>
      'Dessiner uniquement dans la zone opaque du calque du dessous';

  @override
  String get layerPanelConvertToCommonLabel => 'Changer en calque commun';

  @override
  String get layerPanelConvertOption1Title => 'Rendre le calque actuel commun';

  @override
  String get layerPanelConvertOption1Subtitle =>
      'Définit uniquement ce calque comme calque commun';

  @override
  String get layerPanelConvertOption2Title =>
      'Fusionner les calques visibles en un calque commun';

  @override
  String get layerPanelConvertOption2Subtitle =>
      'Crée un calque commun à partir du résultat fusionné de tous les calques actuellement visibles';

  @override
  String get layerPanelCommonRangeTitle => 'Plage du calque commun';

  @override
  String get layerPanelHelpDialogTitle => 'À propos des calques';

  @override
  String get layerPanelHelpBlendModeBody =>
      'Modifie la façon dont le calque est composité : produit, écran, incrustation, etc. Touchez une vignette pour voir au-dessus l’image dans ce mode, puis touchez Appliquer pour le choisir.';

  @override
  String get layerPanelHelpClippingBody =>
      'Dessine uniquement dans la zone de pixels opaques du calque du dessous. Utilisez cette option pour contrôler la zone de dessin.';

  @override
  String get layerPanelCommonLayerLabel => 'Calque commun';

  @override
  String get layerPanelHelpCommonLayerBody =>
      'Un calque dont le contenu est partagé entre plusieurs images. Vous pouvez définir la plage d’images dans laquelle il apparaît.';

  @override
  String get layerPanelAutofillMethodTitle =>
      'Méthode de remplissage automatique';

  @override
  String get layerPanelAutofillNoLineartSnackbar =>
      'Aucun calque de trait pour remplissage automatique correspondant n’a été trouvé.';

  @override
  String get layerPanelAutofillNote1 =>
      'Remarque : lors du premier remplissage automatique, chaque méthode crée un nouveau remplissage à partir du trait.';

  @override
  String get layerPanelAutofillNote2 =>
      'Remarque : si aucun calque de remplissage automatique n’existe encore, la zone sera de toute façon déterminée à partir de zéro.';

  @override
  String get layerPanelAutofillSmartUpdateTitle =>
      'Actualiser uniquement la forme modifiée';

  @override
  String get layerPanelAutofillSmartUpdateHint =>
      'Recommandé en usage normal. Applique les changements du trait tout en préservant autant que possible les retouches manuelles existantes';

  @override
  String get layerPanelAutofillSmartUpdateNote =>
      'Remarque : les nouvelles zones sont remplies automatiquement, les couleurs des zones existantes qui se chevauchent sont conservées et les zones retirées du trait sont effacées.';

  @override
  String get layerPanelAutofillRepaintTitle =>
      'Actualiser la forme depuis le trait et remplir';

  @override
  String get layerPanelAutofillRepaintHint =>
      'À utiliser lorsque le remplissage doit suivre le trait de remplissage automatique actuel';

  @override
  String get layerPanelAutofillRepaintNote =>
      'Remarque : la zone est redétectée depuis le trait de remplissage automatique. La forme actuelle du remplissage sera remplacée.';

  @override
  String get layerPanelAutofillColorUpdateTitle =>
      'Actualiser la couleur en conservant la forme';

  @override
  String get layerPanelAutofillColorUpdateHint =>
      'À utiliser pour conserver une forme de remplissage automatique ajustée manuellement';

  @override
  String get layerPanelAutofillColorUpdateNote =>
      'Remarque : la zone opaque actuelle est gardée et reçoit la dernière couleur. Les ajustements manuels de forme sont conservés.';

  @override
  String get layerPanelExecuteButton => 'Exécuter';

  @override
  String get layerPanelAutofillPartMissingSnackbar =>
      'Aucune partie n’est attribuée. Attribuez-en une depuis « Attribuer une partie ».';

  @override
  String get layerPanelAutofillPresetMissingSnackbar =>
      'Aucune partie correspondante trouvée dans le réglage de remplissage automatique.';

  @override
  String get layerPanelOrphanFillSuccessSnackbar =>
      'Aucun calque de trait correspondant trouvé, rempli avec la couleur la plus récente à la place.';

  @override
  String get layerPanelOrphanFillFailSnackbar =>
      'Impossible de traiter : aucune partie n’est attribuée, ou il n’y a pas de forme à remplir.';

  @override
  String get layerPanelAutofillUpdateHelpTitle =>
      'Marque de mise à jour du remplissage auto';

  @override
  String get layerPanelAutofillUpdateHelpBody =>
      'Le remplissage automatique actuel n’est pas à jour. Touchez pour le mettre à jour.';

  @override
  String layerPanelReplaceMaterialSuccessSnackbar(String name) {
    return 'Matériau remplacé : $name';
  }

  @override
  String layerPanelImportImageSuccessSnackbar(String name) {
    return 'Image importée : $name';
  }

  @override
  String layerPanelCopySuffix(String name) {
    return 'Copie de $name';
  }

  @override
  String get timelineFullscreenPreviewCloseTooltip =>
      'Fermer l’aperçu plein écran';

  @override
  String get timelineDefaultProjectName => 'Nom du projet';

  @override
  String get timelinePreviewPlaceholder => 'Aperçu';

  @override
  String get timelinePreviewFullscreenTip =>
      'Touchez pour afficher l’aperçu en plein écran. Pratique pour vérifier le rendu final.';

  @override
  String get timelineSplitTooltip => 'Scinder';

  @override
  String get timelineSplitModeHint =>
      'Scinder les clips touchés à la position de lecture (tous si aucun)';

  @override
  String get timelineClipMoveTip =>
      'Appuyez longuement sur un clip et faites-le glisser sur le côté pour le déplacer. Touchez-le pour ouvrir ses réglages.';

  @override
  String get timelineVideoFrameUnavailable =>
      'Impossible d’afficher l’image de la vidéo';

  @override
  String get timelineFadeToColor => 'De l’image à la couleur (fondu sortant)';

  @override
  String get timelineFadeFromColor => 'De la couleur à l’image (fondu entrant)';

  @override
  String get timelinePreviewFullscreenTooltip =>
      'Afficher l’aperçu en plein écran';

  @override
  String get timelineAddVideoTooltip => '+ Vidéo';

  @override
  String get timelineAddAudioTooltip => '+ Audio';

  @override
  String get timelineEffectFilterLabel => 'Filtres d’effet';

  @override
  String get timelineAddCameraKfTooltip => 'Ajouter une image clé de caméra';

  @override
  String get timelineAddWatermarkTooltip => '+ Filigrane';

  @override
  String get timelineStackScopeRange => 'Plage d’images';

  @override
  String get timelineStackTargetLabel => 'Utiliser cet ordre pour';

  @override
  String get timelineStackTargetScenes => 'Choisir des scènes';

  @override
  String get timelineStackTargetAllFrames => 'Toutes les images';

  @override
  String get timelineStackScenesHint =>
      'Toutes les images des scènes choisies utilisent le même ordre. Réorganiser ici l’applique à toutes.';

  @override
  String get timelineStackAllFramesHint =>
      'Toutes les images de toutes les scènes utilisent le même ordre. Réorganiser ici l’applique à toutes les scènes.';

  @override
  String get timelineStackRangesTakePriority =>
      'Les images d’une plage gardent l’ordre de cette plage.';

  @override
  String timelineStackRangeLabel(int start, int end) {
    return 'F$start–F$end';
  }

  @override
  String timelineStackRangeAdd(int n) {
    return 'Ajouter une plage à F$n';
  }

  @override
  String get timelineStackRangeHint =>
      'Seules les images d’une plage utilisent l’ordre défini ici ; en dehors des plages, c’est l’ordre de toute la scène.';

  @override
  String get timelineStackRangeEmpty =>
      'Aucune plage pour l’instant. Utilisez le bouton ci-dessus pour en créer une à l’image actuelle.';

  @override
  String timelineStackRangeOrderHint(String range) {
    return 'Ordre d’empilement pour $range (plus haut = devant). Faites glisser la poignée ou utilisez les flèches pour réorganiser.';
  }

  @override
  String get timelineStackRangeDelete => 'Supprimer cette plage';

  @override
  String get timelineAddMaterialTooltip => 'Ajouter un matériau';

  @override
  String get timelineAddSceneTooltip => 'Ajouter une scène';

  @override
  String get timelineMaterialRowLabel => 'Piste';

  @override
  String get timelineMaterialNewRow => 'Nouvelle piste';

  @override
  String get timelineAddTextTooltip => '+ Texte';

  @override
  String get timelineAddImageTooltip => '+ Image';

  @override
  String get timelineStackOrderTitle => 'Ordre d’empilement';

  @override
  String get timelineMaterialText => 'Texte';

  @override
  String get timelineAddTextDialogTitle => 'Ajouter du texte';

  @override
  String get timelineEditSectionText => 'Texte';

  @override
  String get timelineEditSectionTransform => 'Position';

  @override
  String get timelineEditSectionMask => 'Masque';

  @override
  String get timelineEditSectionCrop => 'Recadrer';

  @override
  String get timelineCropHint =>
      'Rogne la partie visible depuis les bords de l’élément. Vous pouvez aussi faire glisser les coins et les bords du cadre sur l’aperçu. L’image ou la vidéo d’origine n’est pas modifiée.';

  @override
  String get timelineCropLeft => 'Rogner à gauche';

  @override
  String get timelineCropRight => 'Rogner à droite';

  @override
  String get timelineCropTop => 'Rogner en haut';

  @override
  String get timelineCropBottom => 'Rogner en bas';

  @override
  String get timelineCropReset => 'Réinitialiser le recadrage';

  @override
  String get timelineEditSectionRegion => 'Sélection';

  @override
  String get timelineRegionHint =>
      'Faites glisser sur l’aperçu pour entourer une partie, puis choisissez Déplacer/transformer, Dupliquer ou Supprimer. Une vidéo reçoit la même modification sur chaque image. L’image ou la vidéo d’origine n’est pas modifiée.';

  @override
  String get timelineRegionShapeFreehand => 'À main levée';

  @override
  String get timelineRegionNoSelection =>
      'Aucune partie n’est encore sélectionnée.';

  @override
  String get timelineRegionMove => 'Déplacer/transformer';

  @override
  String get timelineRegionSelectAll => 'Tout sélectionner';

  @override
  String get timelineRegionClearSelection => 'Désélectionner';

  @override
  String timelineRegionLimit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vous pouvez ajouter jusqu’à $count modifications de sélection.',
      one: 'Vous pouvez ajouter jusqu’à $count modification de sélection.',
    );
    return '$_temp0';
  }

  @override
  String get timelineRegionAdjustHint =>
      'Faites glisser sur l’aperçu pour le déplacer, un point d’angle pour le redimensionner, un point de côté pour l’étirer et le point du haut pour le faire pivoter. Deux doigts fonctionnent aussi.';

  @override
  String get timelineRegionScaleX => 'Échelle horizontale';

  @override
  String get timelineRegionScaleY => 'Échelle verticale';

  @override
  String get timelineRegionFlipHorizontal => 'Retourner horizontalement';

  @override
  String get timelineRegionFlipVertical => 'Retourner verticalement';

  @override
  String get timelineRegionResetTransform => 'Réinitialiser la position';

  @override
  String get timelineRegionDone => 'Terminé';

  @override
  String timelineRegionEditsTitle(int count) {
    return 'Modifications de sélection ($count)';
  }

  @override
  String timelineRegionEditNumbered(int number, String action) {
    return '$number. $action';
  }

  @override
  String get timelineRegionEditRemove => 'Retirer cette modification';

  @override
  String get timelineRegionRemoveAll =>
      'Retirer toutes les modifications de sélection';

  @override
  String get timelineEditSectionDuration => 'Durée';

  @override
  String get timelineDurationRangeTitle => 'Plage temporelle';

  @override
  String get timelineDurationRangeHint =>
      'La première et la dernière image occupées par le clip dans la timeline. Vous pouvez aussi les modifier en faisant glisser les bords du clip dans la timeline.';

  @override
  String get timelineDurationStartLabel => 'Image de début';

  @override
  String get timelineDurationEndLabel => 'Image de fin';

  @override
  String timelineDurationLength(int frames, String seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      frames,
      locale: localeName,
      other: 'Durée : $frames images ($seconds s)',
      one: 'Durée : $frames image ($seconds s)',
    );
    return '$_temp0';
  }

  @override
  String timelineDurationInvalid(int max) {
    return 'Saisissez un nombre entier de 1 à $max. Le début ne peut pas venir après la fin.';
  }

  @override
  String get timelineDurationOverlap =>
      'Non modifié : avec cette plage, le clip chevaucherait un autre clip de la même piste.';

  @override
  String get timelineDurationBeforeSource =>
      'Non modifié : le clip ne peut pas commencer avant le début de son audio.';

  @override
  String get timelineTransformRotationX => 'Rotation X';

  @override
  String get timelineTransformRotationY => 'Rotation Y';

  @override
  String get timelineTransformRotationZ => 'Rotation Z';

  @override
  String get timelineTransformReset => 'Réinitialiser la position';

  @override
  String timelineKeyframeAddHere(int n) {
    return 'Ajouter une image clé à F$n';
  }

  @override
  String timelineKeyframeRemoveHere(int n) {
    return 'Supprimer l’image clé de F$n';
  }

  @override
  String get timelineKeyframeWholeHint =>
      'La même position est utilisée partout. Pour l’animer, allez à une autre image et ajoutez une image clé.';

  @override
  String timelineKeyframeAnimHint(int count, int n) {
    return '$count images clés : les modifications sont enregistrées à F$n et les images intermédiaires sont calculées automatiquement.';
  }

  @override
  String get timelineGizmoHint =>
      'Faites glisser sur l’aperçu pour le déplacer, un point d’angle pour le redimensionner et le point du haut pour le faire pivoter. Deux doigts fonctionnent aussi.';

  @override
  String timelineMaterialOutOfRange(int start, int end) {
    return 'Non affiché à cette image (affiché de F$start à F$end)';
  }

  @override
  String get timelineMaskNone => 'Aucun';

  @override
  String get timelineMaskRectangle => 'Rectangle';

  @override
  String get timelineMaskEllipse => 'Ellipse';

  @override
  String get timelineMaskCenterX => 'Centre X';

  @override
  String get timelineMaskCenterY => 'Centre Y';

  @override
  String get timelineMaskWidth => 'Largeur';

  @override
  String get timelineMaskHeight => 'Hauteur';

  @override
  String get timelineMaskFeather => 'Contour progressif';

  @override
  String get timelineMaskInvert => 'Inverser (masquer l’intérieur)';

  @override
  String get timelineMaskHint =>
      'N’affiche que ce qui est à l’intérieur du masque. Inversez-le pour masquer l’intérieur.';

  @override
  String get timelineStackOrderHint =>
      'Les éléments en haut de la liste passent devant. Faites glisser la poignée ou utilisez les flèches pour réorganiser.';

  @override
  String get timelineStackScopeScene => 'Toute la scène actuelle';

  @override
  String get timelineStackFrameUnit => 'Image (dessin)';

  @override
  String get timelineStackResetScene => 'Revenir à l’ordre par défaut';

  @override
  String get timelineStackFrameMaskTitle => 'Masque de l’image (dessin)';

  @override
  String get timelineStackFrameMaskHint =>
      'Ne recadre que le dessin ; le texte, les images et la vidéo ne sont pas affectés. Le dessin n’est pas masqué pendant que vous dessinez sur le canevas.';

  @override
  String get timelineStackMoveUp => 'Avancer';

  @override
  String get timelineStackMoveDown => 'Reculer';

  @override
  String timelineStackSelectedCount(int count) {
    return '$count sélectionné(s)';
  }

  @override
  String get timelineStackBringToFront => 'Premier plan';

  @override
  String get timelineStackSendToBack => 'Arrière-plan';

  @override
  String get timelineStackDeselectAll => 'Tout désélectionner';

  @override
  String get timelineStackSelectAll => 'Tout sélectionner';

  @override
  String get timelineStackMultiSelectHint =>
      'Appuyez longuement sur un élément pour en sélectionner plusieurs. Les éléments sélectionnés se déplacent ensemble avec les flèches, en les faisant glisser ou avec les boutons ci-dessous.';

  @override
  String get timelineWatermarkNotRegisteredTitle =>
      'Aucun filigrane enregistré';

  @override
  String get timelineWatermarkNotRegisteredBody =>
      'Enregistrez d’abord une image ou un filigrane texte depuis « Filigrane » dans les réglages.';

  @override
  String get timelineOpenSettingsButton => 'Ouvrir les réglages';

  @override
  String get timelineWatermarkSelectTitle => 'Sélectionner un filigrane';

  @override
  String timelineWatermarkAddedSnackbar(String name) {
    return 'Filigrane ajouté (affiché sur toutes les images) : $name';
  }

  @override
  String get timelineWatermarkEditTitle => 'Modifier le filigrane';

  @override
  String get timelineWatermarkAngleLabel => 'Angle';

  @override
  String get timelineWatermarkSizeLabel => 'Taille';

  @override
  String get timelineWatermarkOpacityLabel => 'Opacité';

  @override
  String get timelineWatermarkLoopLabel => 'Toujours afficher (boucle)';

  @override
  String get timelineWatermarkLoopSubtitle =>
      'Si désactivé, affiché uniquement sur la scène actuelle';

  @override
  String get timelineConfirmButton => 'Valider';

  @override
  String get timelineClipSelectDoneButton => 'Terminé';

  @override
  String get timelineClipOverlapDialogTitle => 'Chevauche un clip existant';

  @override
  String get timelineClipOverlapDialogBody =>
      'L’emplacement du collage chevauche un clip existant. Comment souhaitez-vous le placer ?';

  @override
  String get timelineClipOverlapPlaceBefore => 'Placer avant';

  @override
  String get timelineClipOverlapPlaceAfter => 'Placer après';

  @override
  String get timelineClipOverlapPlaceNewRow =>
      'Superposer (ajouter une nouvelle ligne)';

  @override
  String get timelineSceneRenameTitle => 'Renommer la scène';

  @override
  String get timelineSceneDeleteMenuItem => 'Supprimer la scène';

  @override
  String get timelineDurationLimitTitle => 'Limite de durée atteinte';

  @override
  String get timelineDurationLimitBodyFree =>
      'L’offre gratuite permet de prolonger un projet jusqu’à 90 secondes. L’avantage de durée étendue porte cette limite à deux heures.';

  @override
  String get timelineDurationLimitBodyPremium =>
      'L’avantage de durée étendue permet de prolonger un projet jusqu’à deux heures.';

  @override
  String timelineSceneDeleteConfirmTitle(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get timelineSceneDeleteConfirmBody =>
      'Toutes les données de la scène seront supprimées : images, calques communs, matériaux texte, vidéo et image, et filigranes inclus.';

  @override
  String timelineSceneMultiDeleteConfirmTitle(int count) {
    return 'Supprimer les $count scènes sélectionnées ?';
  }

  @override
  String get timelineAutofillUpdateHelpBody =>
      'Cette scène/image contient un calque de remplissage automatique qui n’est pas à jour. Touchez le calque concerné dans le panneau des calques pour le mettre à jour.';

  @override
  String get timelineFrameTrackLabel => 'Image';

  @override
  String get timelineTrackRowRenameTitle => 'Renommer la ligne';

  @override
  String get timelineCameraTrackLabel => 'Caméra';

  @override
  String timelineTrackRowName(String kind, int number) {
    return '$kind $number';
  }

  @override
  String get timelineEndCardDefaultLogoLabel => 'Logo NIARIM';

  @override
  String get timelineEndCardHiddenLabel => 'Masqué';

  @override
  String get timelineEndCardTrackLabel => 'Piste de la marque de fin';

  @override
  String get timelineMarkerTrackLabel => 'Horodatages';

  @override
  String timelineMarkerAddDialogTitle(int n) {
    return 'Ajouter un horodatage à F$n';
  }

  @override
  String timelineMarkerEditDialogTitle(int n) {
    return 'Horodatage : F$n';
  }

  @override
  String get timelineMarkerCommentHint => 'Commentaire (ex. bouche « a » ici)';

  @override
  String timelineAddClipDialogTitle(String trackName) {
    return 'Ajouter un clip $trackName';
  }

  @override
  String get timelineClipLabelFieldLabel => 'Libellé';

  @override
  String get timelineClipStartLabel => 'Début :';

  @override
  String get timelineClipLengthLabel => 'Durée :';

  @override
  String get timelineAutofillNote2 =>
      'Remarque : si aucun calque de remplissage automatique n’existe encore, la zone sera de toute façon déterminée à partir de zéro.';

  @override
  String get timelineAutofillTargetLabel => 'Cible';

  @override
  String get timelineAutofillScopeCurrentFrame => 'Image actuelle uniquement';

  @override
  String get timelineAutofillScopeCurrentScene =>
      'Par scène (toutes les images de la scène actuelle)';

  @override
  String get timelineAutofillScopeAllScenes =>
      'Toutes les images (projet entier)';

  @override
  String get timelineAutofillProgressTitle =>
      'Remplissage automatique en cours';

  @override
  String timelineAutofillProgressSubtitle(int count) {
    return '$count images';
  }

  @override
  String timelineAutofillCompleteSnackbar(int count) {
    return 'Remplissage automatique terminé ($count traitées)';
  }

  @override
  String get timelineEffectTypeFade => 'Fondu';

  @override
  String get timelineEffectTypeGaussianBlur => 'Flou gaussien';

  @override
  String get timelineEffectTypeLensBlur => 'Flou d’objectif';

  @override
  String get timelineEffectTypeMosaic => 'Mosaïque';

  @override
  String get timelineEffectTypeChromaticAberration => 'Aberration chromatique';

  @override
  String get timelineEffectTypeNoise => 'Bruit';

  @override
  String get timelineEffectTypeSepia => 'Sépia';

  @override
  String get timelineEffectTypeAnimeStyle => 'Style anime';

  @override
  String get timelineEffectTypeRetroAnime => 'Anime rétro';

  @override
  String get timelineEffectTypeCrt => 'Tube cathodique';

  @override
  String get timelineEffectTypeAnimatedNoise => 'Bruit animé';

  @override
  String get timelineEffectTypeRain => 'Pluie';

  @override
  String get timelineEffectFilterEmptyState =>
      'Aucun filtre\nAppuyez sur + Ajouter pour en créer un';

  @override
  String get timelineRangeStartLabel => 'Début';

  @override
  String get timelineRangeEndLabel => 'Fin';

  @override
  String get timelineEffectSizeLabel => 'Taille';

  @override
  String get timelineEffectStrengthLabel => 'Intensité';

  @override
  String get timelineEffectAmountLabel => 'Quantité';

  @override
  String get timelineEffectGrainSizeLabel => 'Taille du grain';

  @override
  String get timelineEffectRainIntensityLabel => 'Intensité';

  @override
  String get timelineEffectRainSpeedLabel => 'Vitesse';

  @override
  String get timelineEffectRainSizeLabel => 'Taille des gouttes';

  @override
  String get timelineEffectWindAngleLabel => 'Angle du vent';

  @override
  String get timelineColorLabel => 'Couleur';

  @override
  String get timelineColorBlack => 'Noir';

  @override
  String get timelineColorWhite => 'Blanc';

  @override
  String get timelineColorCustom => 'Personnalisé';

  @override
  String get timelineFadeColorDialogTitle => 'Couleur de fondu';

  @override
  String get timelineAddFilterDialogTitle => 'Ajouter un filtre';

  @override
  String get timelineClipVolumeLabel => 'Volume';

  @override
  String get timelineClipFadeInLabel => 'Fondu d’entrée';

  @override
  String get timelineClipFadeOutLabel => 'Fondu de sortie';

  @override
  String get timelineClipUseStartLabel => 'Début utilisé F';

  @override
  String get timelineClipUseEndLabel => 'Fin utilisée F';

  @override
  String get timelineClipSpeedLabel => 'Vitesse';

  @override
  String get timelineClipSpeedInputLabel => 'Saisir la vitesse';

  @override
  String get timelineClipSpeedInputHint => '0,01–100';

  @override
  String get timelineClipSpeedInvalid =>
      'Saisissez un nombre entre 0,01 et 100';

  @override
  String get timelineClipSpeedOverlap =>
      'Non modifié : à cette vitesse, le clip chevaucherait un autre clip de la même piste.';

  @override
  String get timelineClipSpeedPastSceneEnd =>
      'Non modifié : à cette vitesse, le clip dépasserait la fin de la scène. Allongez d’abord la scène.';

  @override
  String get timelineClipSpeedKeyframeClash =>
      'Cette vitesse est impossible : deux images clés tomberaient sur la même image.';

  @override
  String timelineClipSpeedEndPreview(int before, int after) {
    return 'Image de fin : F$before → F$after';
  }

  @override
  String get timelineClipSpeedSoundNote =>
      'À vitesse élevée, le son devient difficile à suivre (l’aperçu et l’export sonnent pareil). Vous pouvez le couper si vous n’en avez pas besoin.';

  @override
  String get timelineClipSpeedMute => 'Couper le son';

  @override
  String get timelinePlaybackSkipNotice =>
      'La lecture n’arrive pas à suivre, des images sont sautées (l’export les contient toutes).';

  @override
  String timelinePreviewOutputFps(int output, int work) {
    return 'Lecture à $output i/s, comme l’export (l’œuvre est à $work i/s)';
  }

  @override
  String timelinePreviewWorkFps(int fps) {
    return 'Revenir aux $fps i/s de l’œuvre';
  }

  @override
  String get timelineCameraFrameAlreadyHasKeyframe =>
      'Cette image contient déjà une image clé de caméra.';

  @override
  String timelineCameraKfTitle(int n) {
    return 'Image clé caméra : F$n';
  }

  @override
  String get timelineCameraMoveXLabel => 'Déplacement X';

  @override
  String get timelineCameraMoveYLabel => 'Déplacement Y';

  @override
  String get timelineCameraZoomLabel => 'Zoom';

  @override
  String get timelineCameraRotationLabel => 'Rotation';

  @override
  String get layerPanelKeyframeLabel => 'Animation (images clés)';

  @override
  String layerKeyframeSheetTitle(String name) {
    return 'Images clés de $name';
  }

  @override
  String get layerKeyframeSheetDesc =>
      'Définissez la position, l’échelle et la rotation de ce calque par image ; les images clés sont interpolées automatiquement. Le dessin du calque lui-même ne change pas.';

  @override
  String layerKeyframeAddAtCurrentFrame(int n) {
    return 'Ajouter à l’image actuelle (F$n)';
  }

  @override
  String get layerKeyframeEmpty =>
      'Aucune image clé pour l’instant. Ajoutez-en une avec le bouton ci-dessus.';

  @override
  String get layerKeyframeScaleShort => 'Échelle';

  @override
  String get layerKeyframeRotationShort => 'Rot.';

  @override
  String layerKeyframeEditTitle(int n) {
    return 'Image clé : F$n';
  }

  @override
  String get layerKeyframeFrameLabel => 'Image';

  @override
  String get layerKeyframeScaleLabel => 'Échelle';

  @override
  String get layerKeyframeRotationLabel => 'Rotation';

  @override
  String layerTransformWholeHint(String menu) {
    return 'La même taille et le même angle s’appliquent à tout le calque. Pour l’animer, utilisez « $menu ».';
  }

  @override
  String get layerKeyframeEasingLabel => 'Transition vers l’image clé suivante';

  @override
  String get layerKeyframeEasingLinear => 'Uniforme';

  @override
  String get layerKeyframeEasingEaseIn => 'Entrée douce (démarre lentement)';

  @override
  String get layerKeyframeEasingEaseOut =>
      'Sortie douce (se termine lentement)';

  @override
  String get layerKeyframeEasingEaseInOut => 'Entrée et sortie douces';

  @override
  String get layerKeyframeEasingBounceOut => 'Rebond';

  @override
  String get layerPanelGroupTooltip => 'Grouper';

  @override
  String get layerPanelShowSelectedTooltip =>
      'Afficher tous les calques sélectionnés';

  @override
  String get layerPanelHideSelectedTooltip =>
      'Masquer tous les calques sélectionnés';

  @override
  String get layerPanelGroupDefaultName => 'Nouveau groupe';

  @override
  String layerPanelGroupMembershipLabel(String name) {
    return 'Groupe : $name';
  }

  @override
  String get layerPanelGroupLeaveAction => 'Quitter';

  @override
  String frameStripHoldDialogTitle(int n) {
    return 'F$n images de maintien';
  }

  @override
  String get frameStripHoldMenuItem => 'Images de maintien';

  @override
  String get frameStripTimelineModeLabel => 'Timeline';

  @override
  String get frameStripBulkAddTitle => 'Ajouter des images en lot';

  @override
  String get frameStripBulkAddUnit => 'images';

  @override
  String get progressDialogAdLoading => 'Chargement de la publicité…';

  @override
  String get adMockPlaceholderLabel =>
      'Bannière publicitaire (maquette d’essai d’emplacement)';

  @override
  String get adMediumRectangleMockPlaceholderLabel =>
      'Publicité rectangle moyen (maquette 300×250)';

  @override
  String get progressDialogTipLabel => 'Astuce';

  @override
  String get legalLastUpdated => 'Dernière mise à jour : 27 novembre 2026';

  @override
  String get legalConsentTitle =>
      'Conditions d’utilisation et politique de confidentialité';

  @override
  String get legalConsentBody =>
      'Avant d’acheter Premium, de vous connecter avec un compte Google ou de publier sur la Place des œuvres, veuillez accepter les conditions d’utilisation et la politique de confidentialité. La version acceptée ainsi que la date et l’heure sont enregistrées sur cet appareil.';

  @override
  String get legalConsentReadTerms => 'Lire les conditions d’utilisation';

  @override
  String get legalConsentReadPrivacy => 'Lire la politique de confidentialité';

  @override
  String get legalConsentAgree => 'Accepter et continuer';

  @override
  String get premiumAutoRenewNote =>
      'Les formules mensuelle et annuelle sont renouvelées automatiquement jusqu’à leur résiliation. Vous pouvez résilier à tout moment dans Google Play, sous « Paiements et abonnements ».';

  @override
  String get licenseTermsArt1Title => 'Article 1 (Application)';

  @override
  String get licenseTermsArt1Body =>
      'Les présentes conditions d’utilisation (les « Conditions ») définissent les conditions d’utilisation de l’application « NIARIM » (l’« Application »). L’utilisateur doit accepter les présentes Conditions avant d’utiliser l’Application. L’utilisation de l’Application vaut acceptation des présentes Conditions. Avant l’achat de fonctionnalités premium, la connexion avec un compte Google et la publication sur la Place des œuvres, l’Application demande à l’utilisateur d’accepter les présentes Conditions et la politique de confidentialité, et enregistre sur l’appareil la version acceptée ainsi que la date et l’heure.';

  @override
  String get licenseTermsArt2Title =>
      'Article 2 (Éligibilité à l’utilisation / environnement pris en charge)';

  @override
  String get licenseTermsArt2Body =>
      '1. Pour plus de détails sur les versions du système d’exploitation prises en charge et l’environnement d’exploitation recommandé de l’Application, veuillez vous référer à la boutique de distribution concernée et aux informations affichées dans l’Application.\n2. Nous nous efforçons de faire fonctionner l’Application confortablement sur des appareils de performances variées ; toutefois, selon les performances de l’appareil, la version du système d’exploitation, l’espace de stockage disponible, les paramètres et d’autres conditions d’utilisation, certaines fonctionnalités peuvent être limitées ou ne pas fonctionner correctement.\n3. Les mineurs doivent obtenir le consentement d’un parent ou d’un autre représentant légal avant d’utiliser l’Application, y compris ses fonctionnalités payantes.';

  @override
  String get licenseTermsArt3Title => 'Article 3 (Actes interdits)';

  @override
  String get licenseTermsArt3Body =>
      'Lors de l’utilisation de l’Application, l’utilisateur ne doit pas :\n・Commettre des actes contraires aux lois, règlements ou aux bonnes mœurs\n・Porter atteinte aux droits d’auteur, marques ou autres droits de propriété intellectuelle, au droit à l’image, à la vie privée ou à d’autres droits ou intérêts de l’Application, du développeur ou de tiers\n・Décompiler, désassembler, procéder à de l’ingénierie inverse ou toute autre analyse de l’Application (sauf dans les cas autorisés par la loi)\n・Modifier, dupliquer ou redistribuer l’Application sans autorisation\n・Accéder sans autorisation à l’Application ou à la plateforme qui la fournit, lui imposer une charge excessive ou entraver de toute autre manière son fonctionnement normal\n・Commettre tout autre acte que le développeur juge raisonnablement inapproprié';

  @override
  String get licenseTermsArt4Title => 'Article 4 (Droits sur le contenu créé)';

  @override
  String get licenseTermsArt4Body =>
      '1. Les droits d’auteur et autres droits relatifs aux illustrations, animations et autres contenus créés par l’utilisateur au moyen de l’Application (y compris les données de projet, les images et vidéos exportées, etc. ; ci-après le « Contenu créé ») appartiennent, dans la mesure permise par la loi, à l’utilisateur ou au tiers titulaire des droits sur ce contenu.\n2. L’Application ne fournit aucune fonction permettant de transmettre, collecter ou synchroniser le Contenu créé vers les serveurs du développeur. Les données de projet sont, en principe, stockées uniquement sur l’appareil de l’utilisateur (pour le traitement applicable lorsque l’utilisateur choisit de publier du Contenu créé au moyen de la fonction Place des œuvres, voir l’article 12).\n3. Que le Contenu créé ait été réalisé avec la version gratuite ou la version premium, le développeur ne restreindra pas son utilisation commerciale en raison des frais d’utilisation de l’Application ou de l’édition utilisée (les différences entre la version gratuite et la version premium se limitent à des aspects fonctionnels tels que l’affichage de la marque de fin ou la limite de durée d’exportation).\n4. Nonobstant le paragraphe précédent, les polices, images, matériaux et autres éléments ajoutés par l’utilisateur à l’Application et sur lesquels des tiers détiennent des droits restent soumis à leurs conditions d’utilisation respectives (article 5).';

  @override
  String get licenseTermsArt5Title =>
      'Article 5 (Polices intégrées et matériaux ajoutés)';

  @override
  String get licenseTermsArt5Body =>
      '1. Les polices et autres matériaux intégrés à l’Application sont utilisés conformément aux conditions de licence indiquées sur cet écran, sous « Polices utilisées ».\n2. En ce qui concerne les droits relatifs aux polices, images, trames, tampons et autres matériaux que l’utilisateur ajoute ou charge lui-même dans l’Application, celui-ci est responsable de l’obtention des droits ou autorisations nécessaires et de leur utilisation licite.\n3. En cas de litige avec un tiers résultant de l’utilisation par l’utilisateur de matériaux tiers, le développeur n’en assume aucune responsabilité, sauf dans les cas où la loi l’exige.';

  @override
  String get licenseTermsArt6Title =>
      'Article 6 (Fonctionnalités premium / facturation)';

  @override
  String get licenseTermsArt6Body =>
      '1. Outre les fonctionnalités disponibles gratuitement, l’Application propose des fonctionnalités premium accessibles via des achats intégrés (une formule mensuelle, une formule annuelle ou d’autres formules premium).\n2. Le prix, le contenu, le mode d’achat et les autres conditions des fonctionnalités premium sont ceux affichés dans l’Application ou sur la boutique de distribution au moment de l’achat.\n3. La formule mensuelle et la formule annuelle sont des abonnements. Sauf résiliation par l’utilisateur, l’abonnement est renouvelé automatiquement pour la même durée à la fin de chaque période, et le prix en vigueur au moment du renouvellement est facturé par l’intermédiaire de la boutique de distribution.\n4. L’abonnement peut être résilié à tout moment dans l’application Google Play, sous « Paiements et abonnements » > « Abonnements ». Après la résiliation, l’abonnement n’est plus renouvelé et les fonctionnalités premium restent disponibles jusqu’à la fin de la période déjà payée. La désinstallation de l’Application ne résilie pas l’abonnement.\n5. Les annulations, remboursements et autres questions relatives au paiement après achat sont régis par les règles de Google Play ou de la plateforme de paiement utilisée. Toutefois, lorsque la loi en dispose autrement, ces dispositions s’appliquent.\n6. Le développeur peut modifier le contenu des fonctionnalités premium pour des motifs raisonnables, tels qu’une évolution législative, une nécessité technique ou une amélioration de l’Application. Lorsqu’un changement important est apporté, il en informera au préalable, dans la mesure du raisonnablement possible, au sein de l’Application ou par tout autre moyen approprié.';

  @override
  String get licenseTermsArt7Title => 'Article 7 (Affichage publicitaire)';

  @override
  String get licenseTermsArt7Body =>
      '1. Dans la version gratuite, des publicités peuvent être affichées via des services publicitaires tiers.\n2. L’acquisition, l’utilisation et le traitement des informations par les prestataires publicitaires sont régis par la politique de confidentialité de chaque prestataire concerné.';

  @override
  String get licenseTermsArt8Title => 'Article 8 (Traitement des informations)';

  @override
  String get licenseTermsArt8Body =>
      '1. L’Application ne fournit aucune fonction permettant de transmettre ou de collecter vers les serveurs du développeur les illustrations, animations et autres contenus, ni les données de projet, créés par l’utilisateur. Ceux-ci sont, en principe, stockés uniquement sur l’appareil de l’utilisateur, et le développeur ne disposant d’aucune fonction lui permettant de stocker ce contenu par lui-même, la notion de durée de conservation du côté du développeur n’existe pas.\n2. Le traitement des informations de l’utilisateur — y compris les informations collectées par les services tiers intégrés à l’Application (tels que la diffusion publicitaire et les achats intégrés) — est régi par la Politique de confidentialité établie séparément.\n3. Si vous désinstallez l’Application, les données stockées sur votre appareil (projets, paramètres, polices ajoutées, etc.) seront supprimées.';

  @override
  String get licenseTermsArt9Title =>
      'Article 9 (Suspension, modification et cessation de la fourniture)';

  @override
  String get licenseTermsArt9Body =>
      '1. Le développeur peut suspendre temporairement la fourniture de tout ou partie de l’Application lors d’opérations de maintenance, de mise à jour ou de correction, en cas de dysfonctionnement de l’infrastructure de fourniture, ou pour toute autre raison indépendante de sa volonté.\n2. Le développeur peut modifier le contenu de l’Application ou mettre fin à sa fourniture selon les besoins.\n3. Dans les cas visés aux deux paragraphes précédents, le développeur donnera, sauf urgence, un préavis dans la mesure du possible, dans l’Application ou par tout autre moyen approprié.\n4. Sauf obligation légale contraire, le développeur n’assume aucune responsabilité pour les dommages subis par l’utilisateur du fait des modifications, suspensions ou cessations visées au présent article.';

  @override
  String get licenseTermsArt10Title =>
      'Article 10 (Clause de non-responsabilité)';

  @override
  String get licenseTermsArt10Body =>
      '1. Le développeur ne garantit pas l’absence de défauts factuels ou juridiques de l’Application (y compris en matière de sécurité, de fiabilité, d’exactitude, d’exhaustivité, d’adéquation à un usage particulier, ou d’absence de bugs ou de dysfonctionnements).\n2. L’utilisateur utilise l’Application sous sa propre responsabilité. Des données peuvent être perdues en raison d’une panne de l’appareil, d’une erreur de manipulation, d’une mise à jour du système d’exploitation ou d’autres circonstances ; il est donc recommandé d’effectuer des sauvegardes régulières des données en cours de création à l’aide des fonctions d’exportation et de partage, entre autres.\n3. Lorsqu’un dommage est causé à l’utilisateur par une faute intentionnelle ou une négligence grave du développeur, le développeur répare ce dommage.\n4. Lorsqu’un dommage est causé à l’utilisateur par une négligence légère du développeur (toute négligence autre qu’une négligence grave), le développeur ne répare que le dommage direct et ordinaire effectivement subi par l’utilisateur.';

  @override
  String get licenseTermsArt11Title =>
      'Article 11 (Modification des présentes Conditions)';

  @override
  String get licenseTermsArt11Body =>
      '1. Le développeur peut modifier les présentes Conditions en cas de changement de la législation applicable, de modification du contenu de l’Application ou pour toute autre raison qu’il juge nécessaire.\n2. En cas de modification des présentes Conditions, le développeur en communiquera au préalable le contenu et la date d’entrée en vigueur, dans l’Application ou par tout autre moyen approprié.\n3. Les Conditions modifiées s’appliqueront, dans la mesure permise par la loi, à compter de la date d’entrée en vigueur mentionnée au paragraphe précédent.';

  @override
  String get licenseTermsArt12Title =>
      'Article 12 (Place des œuvres : fonction de publication communautaire)';

  @override
  String get licenseTermsArt12Body =>
      '1. L’Application propose, à titre facultatif, une fonction permettant à l’utilisateur de publier sur YouTube, via son propre compte Google, les animations qu’il a créées, puis de les publier et de les consulter sur la « Place des œuvres » (la « Fonction Communautaire »). Il est possible de consulter et de créer des œuvres sans utiliser la Fonction Communautaire.\n2. Le fichier vidéo lui-même est stocké sur YouTube, et non sur les serveurs du développeur. En revanche, les informations nécessaires à l’identification et à l’affichage des œuvres publiées (identifiant de la vidéo YouTube, titre, statistiques, informations de signalement, etc.), ainsi que l’identifiant utilisateur NIARIM délivré lors de l’utilisation des fonctions de publication, de signalement et de blocage (un identifiant délivré au sein de l’Application, distinct du compte Google), sont gérés sur les serveurs du développeur.\n3. La publication d’œuvres, le signalement et le blocage d’autres utilisateurs dans le cadre de la Fonction Communautaire nécessitent une connexion via un compte Google.\n4. Le nombre d’œuvres pouvant être publiées est soumis à une limite quotidienne (différente entre les membres gratuits et les membres premium). Cette limite peut être modifiée pour des raisons d’exploitation.\n5. Si un utilisateur estime qu’une œuvre publiée par un autre utilisateur enfreint la loi ou les bonnes mœurs, ou pourrait relever de l’un des points de l’article 3, il peut la signaler au développeur via la fonction de signalement de l’Application. Après examen du signalement, le développeur pourra, pour un motif raisonnable, prendre les mesures nécessaires, telles que le retrait de l’œuvre des listes. Les signalements mensongers et l’usage abusif de la fonction de signalement sont interdits. Les œuvres faisant l’objet de plusieurs signalements ou susceptibles de constituer une infraction grave peuvent être masquées temporairement jusqu’à leur examen. Le développeur peut suspendre la publication sur la Place des œuvres pour les utilisateurs qui publient de manière répétée des contenus contraires aux présentes Conditions. Les contestations de ces mesures peuvent être adressées via le formulaire de contact ou par e-mail (support@miranima-studio.com).\n6. Même si un utilisateur supprime une publication ou dissocie son compte Google de l’Application, la vidéo YouTube correspondante n’est pas supprimée. Il appartient à l’utilisateur de supprimer la vidéo, ou d’effectuer toute autre opération similaire, directement sur YouTube. Par ailleurs, si la vidéo est rendue privée ou supprimée du côté de YouTube, l’œuvre cessera également d’être affichée sur la Place des œuvres.\n7. L’utilisation de la Fonction Communautaire est soumise, en plus des présentes Conditions, aux Conditions d’utilisation et aux Règles de la communauté de YouTube.\n8. Les utilisateurs peuvent s’abonner à d’autres utilisateurs et mettre en favori ou repartager les œuvres d’autres utilisateurs. Vous seul pouvez consulter les listes des personnes que vous suivez, de vos abonnés et des œuvres que vous avez mises en favori. Les autres utilisateurs ne voient que le nombre d’abonnements et d’abonnés. Suivre une personne, mettre une œuvre en favori ou la repartager ne déclenche aucune notification individuelle à l’autre utilisateur concernant cette action.\n9. Les tags attachés à une œuvre peuvent être ajoutés ou supprimés par des utilisateurs autres que l’auteur. L’auteur peut verrouiller les tags de sa propre œuvre afin d’en interdire la modification par d’autres utilisateurs. Les utilisateurs ne doivent pas ajouter de tags diffamatoires, de tags sans rapport avec le contenu de l’œuvre, ni de tags inappropriés de quelque autre nature. Le développeur peut supprimer les tags inappropriés.\n10. Le développeur affiche dans la liste des notifications de l’Application des avis sur l’envoi et la publication de vos œuvres, les objectifs de mission atteints et les événements similaires. Si votre appareil autorise les notifications, l’Application peut envoyer des notifications push. Vous pouvez les désactiver dans les paramètres de l’Application ou de l’appareil.\n11. Les utilisateurs ne doivent pas utiliser la Fonction Communautaire pour harceler d’autres utilisateurs, à des fins publicitaires ou de démarchage, ni pour tout autre objectif étranger à sa finalité (publier et consulter des œuvres). Le masquage change uniquement votre affichage. En cas de blocage, chacun des deux comptes, lorsqu’il est connecté à la Place des œuvres, ne voit plus les publications de l’autre. Dans les deux cas, aucune notification n’est envoyée à l’autre utilisateur.';

  @override
  String get licenseTermsArt13Title =>
      'Article 13 (Droit applicable / juridiction compétente)';

  @override
  String get licenseTermsArt13Body =>
      '1. Les présentes Conditions sont régies et interprétées conformément au droit japonais.\n2. En cas de litige relatif à l’Application, le tribunal de district ou le tribunal sommaire compétent pour le lieu d’établissement du développeur, selon le montant en litige, disposera d’une compétence exclusive convenue en tant que juridiction de première instance.';

  @override
  String get privacyPolicyArt1Title =>
      'Article 1 (Objet de la présente Politique)';

  @override
  String get privacyPolicyArt1Body =>
      'La présente politique de confidentialité (la « Politique ») décrit la manière dont les informations sont traitées dans l’application « NIARIM » (l’« Application »). Dans la présente Politique, le « développeur » désigne le fournisseur de l’Application. Sur demande adressée au point de contact de l’article 9, le développeur communique sans délai son nom et son adresse. Pour les conditions générales d’utilisation de l’Application, veuillez vous référer séparément à l’écran « Conditions et licences ».';

  @override
  String get privacyPolicyArt2Title =>
      'Article 2 (Données que l’Application ne collecte pas)';

  @override
  String get privacyPolicyArt2Body =>
      'L’Application ne fournit aucune fonction permettant de transmettre, collecter ou stocker sur les serveurs du développeur les illustrations, animations et autres contenus créés par l’utilisateur (y compris les données de projet, les images et vidéos exportées, etc. ; il en va de même ci-après). Ces données sont, en principe, stockées uniquement sur l’appareil de l’utilisateur (l’Application n’intègre pas de fonction de synchronisation en nuage). Le développeur ne disposant d’aucune fonction lui permettant de stocker ce contenu par lui-même, la notion de durée de conservation du côté du développeur n’existe pas. Les données stockées sur votre appareil peuvent être supprimées à tout moment via les fonctions de suppression de l’Application ; si vous désinstallez l’Application, les données stockées sur votre appareil — projets, paramètres, polices ajoutées, etc. — seront également supprimées (pour le traitement de l’information lorsque l’utilisateur choisit de se connecter avec un compte Google et d’utiliser la Place des œuvres, les opales ou la vérification des achats premium, voir l’article 7).';

  @override
  String get privacyPolicyArt2AiTrainingClause =>
      'Le développeur n’utilise pas les contenus créés ou publiés par les utilisateurs, les données de projet ni les autres données de création comme données d’entraînement pour des modèles d’IA générative ou d’autres modèles d’apprentissage automatique.';

  @override
  String get privacyPolicyArt3Title =>
      'Article 3 (Informations collectées par des services tiers)';

  @override
  String get privacyPolicyArt3Body =>
      'L’Application intègre les services tiers suivants, et chaque fournisseur de services peut collecter des informations dans la mesure nécessaire à la fourniture de son service respectif. Le développeur de l’Application n’a mis en place aucune fonction lui permettant d’acquérir ou de stocker ces informations de manière autonome (le traitement des informations collectées par chaque service est régi par la politique de confidentialité propre à ce prestataire).\n\n[Diffusion publicitaire (Google AdMob)]\nDans la version gratuite, les publicités sont diffusées via Google AdMob. À des fins de diffusion publicitaire, de mesure d’efficacité et de prévention de la fraude, l’identifiant publicitaire et d’autres informations sur l’appareil peuvent être collectés et utilisés par Google ou ses sociétés affiliées. Pour plus de détails sur la collecte et l’utilisation de ces informations, veuillez consulter la politique de confidentialité de Google (https://policies.google.com/privacy). Vous pouvez réinitialiser votre identifiant publicitaire ou désactiver les publicités personnalisées depuis les paramètres de votre appareil (par exemple, « Confidentialité » dans l’application Paramètres d’Android). Si vous résidez dans l’Espace économique européen (EEE), au Royaume-Uni ou en Suisse, vous pouvez choisir vos préférences de consentement relatives à la personnalisation des publicités via un formulaire de consentement affiché au lancement, et modifier ce choix à tout moment via le bouton « Modifier les préférences de consentement publicitaire » en bas de cet écran.\n\n[Achats intégrés (Google Play Billing)]\nLes achats des fonctionnalités premium sont effectués via le système de paiement de Google Play. Le développeur n’acquiert ni ne conserve directement les informations de paiement telles que les numéros de carte bancaire. Le traitement des informations relatives au paiement est régi par les règles de Google Play.\n\n[Connexion avec un compte Google (Google Sign-In)]\nL’Application se connecte avec un compte Google uniquement lorsque vous utilisez la Place des œuvres, les opales ou la vérification des achats premium. Lors de la connexion, Google transmet à l’Application des informations d’identification comprenant l’identifiant du compte, l’adresse e-mail et le nom affiché. Les serveurs du développeur n’utilisent ces informations que pour confirmer votre identité ainsi que pour émettre et faire correspondre votre NIARIM User ID (article 7), et ne conservent ni votre adresse e-mail ni votre nom affiché.\n\n[YouTube (services d’API YouTube)]\nLa Place des œuvres utilise les services d’API YouTube. Lorsque vous publiez une œuvre, l’Application utilise l’autorisation que vous accordez sur votre compte Google pour mettre en ligne la vidéo sur votre propre chaîne YouTube et pour obtenir le nom et l’icône de la chaîne. Les vidéos publiées sont traitées conformément aux conditions d’utilisation de YouTube (https://www.youtube.com/t/terms) et aux règles de confidentialité de Google (https://policies.google.com/privacy). Vous pouvez révoquer à tout moment l’accès de l’Application sur la page des paramètres de sécurité de Google (https://security.google.com/settings/security/permissions).\n\n[Notifications push (Firebase Cloud Messaging)]\nUniquement si vous activez les notifications de la Place des œuvres, Google (Firebase Cloud Messaging) émet un identifiant de notification pour votre appareil (jeton de l’appareil) afin de pouvoir distribuer les notifications.\n\n[Serveurs du développeur (Amazon Web Services)]\nLes serveurs du développeur utilisés pour la Place des œuvres, les opales et la vérification des achats premium fonctionnent sur le cloud fourni par Amazon Web Services, Inc. (région de Tokyo, Japon).\n\n[Analyse des plantages / analyse d’utilisation]\nL’Application n’intègre actuellement aucun SDK à des fins d’analyse des plantages ou d’analyse d’utilisation. Si de tels services venaient à être introduits à l’avenir, la présente Politique serait mise à jour et annoncée dans l’Application.\n\n[Téléchargement de polices supplémentaires (GitHub)]\nUne communication avec GitHub (GitHub, Inc.), qui distribue les fichiers de polices, n’a lieu que lorsque vous choisissez de télécharger une police supplémentaire depuis « Gestion des polices » dans l’écran des réglages. Elle n’a pas lieu au démarrage de l’application ni lors d’une utilisation normale. Seules les informations nécessaires à la requête (comme votre adresse IP et le fichier de police demandé) sont transmises ; aucune donnée de vos œuvres ni information permettant de vous identifier n’est transmise. Le traitement des informations obtenues est régi par la Déclaration de confidentialité de GitHub (https://docs.github.com/site-policy/privacy-policies/github-privacy-statement).';

  @override
  String get privacyPolicyArt4Title =>
      'Article 4 (Cookies et autres technologies de suivi)';

  @override
  String get privacyPolicyArt4Body =>
      'L’Application elle-même n’utilise pas de cookies, mais le service de diffusion publicitaire mentionné à l’article 3 (Google AdMob) peut utiliser des technologies d’identification similaires (telles que l’identifiant publicitaire) à des fins de diffusion publicitaire et de mesure d’efficacité.';

  @override
  String get privacyPolicyArt5Title =>
      'Article 5 (Informations personnelles des enfants)';

  @override
  String get privacyPolicyArt5Body =>
      'L’Application ne collecte pas intentionnellement d’informations en ciblant principalement les enfants de moins de 13 ans (ou, lorsque la législation du pays ou de la région où vous résidez fixe un âge plus élevé, les enfants n’ayant pas atteint cet âge ; par exemple, les enfants de moins de 14 ans en Corée du Sud). Les parents et tuteurs sont invités à envisager, si nécessaire, de désactiver les publicités personnalisées depuis les paramètres de l’appareil lorsque leurs enfants utilisent l’Application.';

  @override
  String get privacyPolicyArt6Title =>
      'Article 6 (Transferts transfrontaliers d’informations)';

  @override
  String get privacyPolicyArt6Body =>
      'Les fournisseurs des services suivants utilisés par l’Application sont des entreprises établies hors du Japon, et les informations peuvent être traitées sur des serveurs situés hors du Japon.\n・Google LLC (États-Unis) : Google AdMob, Google Play Billing, connexion avec un compte Google, YouTube, Firebase Cloud Messaging\n・Amazon Web Services, Inc. (États-Unis) : exploitation des serveurs du développeur (les serveurs se trouvent dans la région de Tokyo, au Japon)\n・GitHub, Inc. (États-Unis) : téléchargement de polices supplémentaires\n・Anthropic, PBC (États-Unis) : le contenu d’un signalement et les informations publiques de l’œuvre signalée (titre, description, tags, miniature et nom de l’auteur) peuvent être envoyés pour aider à l’examiner (aucune information permettant d’identifier l’auteur du signalement n’est envoyée)\n・Resend, Inc. (États-Unis) : envoi des e-mails d’alerte de signalement (contenu du signalement et informations publiques de l’œuvre) et envoi des demandes de contact\nLe régime de protection des informations personnelles des États-Unis peut être consulté dans l’« Enquête sur les régimes de protection des informations personnelles à l’étranger » publiée par la Commission japonaise de protection des informations personnelles. Chaque fournisseur traite les informations conformément à sa propre politique de confidentialité.';

  @override
  String get privacyPolicyArt7Title =>
      'Article 7 (Traitement de l’information dans la Place des œuvres, pour les opales et pour la vérification des achats premium)';

  @override
  String get privacyPolicyArt7Body =>
      '1. Uniquement lorsqu’un utilisateur choisit, de sa propre initiative, de se connecter avec un compte Google et d’utiliser la fonction « Place des œuvres » (article 12 des Conditions d’utilisation), les opales (bonus de connexion, missions et échanges contre des avantages) ou la vérification des achats premium, le développeur gère les informations suivantes sur ses serveurs :\n・Les informations nécessaires pour identifier et afficher une œuvre publiée (identifiant de la vidéo YouTube, titre, statistiques, date et heure de publication, tags, etc.)\n・Le NIARIM User ID émis pour un utilisateur connecté (un identifiant émis au sein de l’Application, distinct du compte Google)\n・Les informations publiques de la chaîne YouTube associée (nom de la chaîne et URL de l’image de l’icône de la chaîne). Elles sont copiées et conservées sur les serveurs du développeur afin d’afficher le nom et l’icône de l’auteur\n・Le contenu de tout signalement effectué au moyen de la fonction de signalement, ainsi que le NIARIM User ID de l’auteur du signalement\n・Historique des mesures prises contre les publications contraires aux Conditions (nombre d’œuvres masquées et suspension éventuelle de la publication)\n・Le NIARIM User ID de tout utilisateur que vous bloquez\n・Le NIARIM User ID de tout utilisateur que vous suivez, ainsi que vos nombres d’abonnements et d’abonnés\n・Les identifiants des œuvres que vous mettez en favori et la date et l’heure de chaque mise en favori\n・Les identifiants des œuvres que vous repartagez et la date et l’heure de chaque repartage\n・Les tags attachés à une œuvre (voir le paragraphe 4)\n・Si vous activez les notifications push, le jeton de votre appareil (un identifiant permettant de déterminer la destination de la notification ; utilisé uniquement pour envoyer des notifications)\n・Les informations permettant de vérifier les achats premium (l’identifiant du produit acheté, le jeton d’achat émis par Google Play, ainsi que le résultat de la vérification et la date d’expiration)\n・Le solde d’opales et l’historique de ses variations, les enregistrements des bonus de connexion et des missions accomplies et réclamées, et les enregistrements des échanges contre des avantages\n・Les enregistrements confirmant qu’une publicité avec récompense a été regardée jusqu’au bout (l’identifiant de transaction, le montant de la récompense ainsi que la date et l’heure de la confirmation envoyée par Google AdMob)\n2. Le fichier vidéo lui-même est stocké sur YouTube, et non sur les serveurs du développeur.\n3. Les informations décrites aux deux paragraphes précédents ne sont utilisées que pour fournir les fonctions du présent article (affichage des listes, des classements et des résultats de recherche, traitement des signalements, gestion des limites de publication, prise en compte des abonnements, favoris et repartages, envoi des notifications, vérification des achats premium, attribution et échange d’opales et prévention des attributions indues, etc.). Le développeur ne communique pas ces informations à des tiers à des fins publicitaires.\n4. Les tags peuvent être ajoutés ou supprimés par des utilisateurs autres que l’auteur (l’auteur peut verrouiller les tags de sa propre œuvre pour en interdire la modification). Les tags sont publics sur la Place des œuvres et l’identité de l’utilisateur ayant ajouté un tag n’est pas affichée.\n5. Vous seul pouvez consulter les listes des personnes que vous suivez, de vos abonnés et des œuvres que vous avez mises en favori. Les autres utilisateurs ne voient que le nombre d’abonnements et d’abonnés. Suivre une personne, mettre une œuvre en favori ou la repartager ne déclenche aucune notification individuelle à l’autre utilisateur concernant cette action.\n6. Si vous rendez privée ou supprimez une œuvre publiée, celle-ci n’apparaîtra plus dans les listes ni les classements de la Place des œuvres. Vous pouvez supprimer vous-même votre compte NIARIM (NIARIM User ID) sur la page de suppression, accessible depuis les réglages de l’application ou depuis la politique de confidentialité du site officiel, après avoir confirmé votre identité avec votre compte Google. La suppression du compte efface progressivement les publications de la Place des œuvres, les abonnements à d’autres utilisateurs, les favoris, les repartages, les blocages et les signalements qui y sont liés, le solde, l’historique et les avantages en opales, ainsi que les notifications et les jetons d’appareil, entre autres données ; elle est irréversible. Après la suppression, nous ne conservons que les éléments suivants : une empreinte (hash) de l’identifiant de votre compte Google pour refuser les anciennes connexions (2 heures), un code qui ne vous identifie pas pour confirmer la fin de la demande (24 heures), les reçus de récompenses publicitaires dont les informations d’identification ont été retirées, pour éviter les doubles récompenses (jusqu’à leur expiration prévue), et des enregistrements contenant uniquement les identifiants des œuvres supprimées afin qu’elles ne réapparaissent pas. Les données mises de côté lors d’incidents sont supprimées automatiquement sous 7 jours, et les journaux du serveur sous 1 mois. Les œuvres présentes sur votre appareil, les vidéos sur YouTube et les abonnements Google Play ne sont pas concernés par cette suppression ; gérez-les ou résiliez-les à l’endroit correspondant. Pour demander la suppression de tout autre enregistrement, veuillez nous contacter par le moyen décrit à l’article 9.\n7. Pour protéger les informations des paragraphes précédents, le développeur chiffre les communications avec ses serveurs et limite au nécessaire les personnes pouvant traiter les informations sur ses serveurs ainsi que leurs droits.\n8. Si un utilisateur n’utilise pas les fonctions du présent article, aucun traitement d’informations au titre du présent article n’a lieu. (Conformément au principe de l’article 2, rien n’est transmis aux serveurs du développeur.)';

  @override
  String get privacyPolicyArt8Title =>
      'Article 8 (Modifications de la présente Politique)';

  @override
  String get privacyPolicyArt8Body =>
      'Le développeur peut modifier la présente Politique en cas de changement de la législation applicable, de modification du contenu de l’Application ou pour toute autre raison qu’il juge nécessaire. En cas de modification de la présente Politique, le développeur en communiquera au préalable le contenu et la date d’entrée en vigueur, dans l’Application ou par tout autre moyen approprié.';

  @override
  String get privacyPolicyArt9Title =>
      'Article 9 (Demandes de communication, réclamations et contact)';

  @override
  String get privacyPolicyArt9Body =>
      '1. L’utilisateur peut demander, pour ses propres informations personnelles détenues par le développeur, la notification de la finalité d’utilisation, la communication, la rectification, l’ajout ou la suppression, la suspension de l’utilisation ou l’effacement, ainsi que la suspension de leur communication à des tiers. Veuillez vous adresser au point de contact ci-dessous. Après avoir vérifié votre identité, le développeur répond sans délai conformément à la loi. Aucuns frais ne sont demandés.\n2. Les réclamations et questions concernant la présente Politique et le traitement des informations personnelles sont également reçues au point de contact ci-dessous.\n3. Si vous résidez dans l’Espace économique européen (EEE), au Royaume-Uni ou dans certains États des États-Unis, vous pouvez exercer les droits que vous confère la loi de votre lieu de résidence (accès, rectification, effacement, limitation du traitement, portabilité, opposition, retrait du consentement, réclamation auprès d’une autorité de contrôle, etc.). Le développeur traite les informations de l’article 7 pour fournir les fonctions que vous demandez (exécution d’un contrat) et pour prévenir la fraude (intérêts légitimes). La personnalisation des publicités suit les paramètres que vous choisissez dans le formulaire de consentement décrit à l’article 3. Le développeur ne vend pas d’informations personnelles.\nPour toute question relative à la présente Politique, veuillez nous contacter aux coordonnées ci-dessous :\nsupport@miranima-studio.com';

  @override
  String get privacyPolicyAdConsentButton =>
      'Modifier les préférences de consentement publicitaire';

  @override
  String get tipsPcDexLayoutTitle =>
      'Sur grand écran, le mode PC (DeX) s’active tout seul';

  @override
  String get tipsPcDexLayoutDesc =>
      'Sur un Chromebook, une tablette avec clavier, Samsung DeX ou tout environnement à écran large, l’application bascule automatiquement vers une mise en page professionnelle à panneaux ancrés. Vous pouvez aussi forcer Toujours en mode PC ou Toujours en mode mobile depuis les paramètres d’espace de travail, utile lors d’une connexion à un écran externe.';

  @override
  String get workspaceTimelineSection => 'Affichage de la timeline';

  @override
  String get workspaceTimelineHint =>
      'Ajustez la hauteur de chaque ligne de piste vidéo/audio sur 5 niveaux. Vous pouvez aussi pincer avec deux doigts pour agrandir ou réduire temporairement la largeur des images de la timeline.';

  @override
  String get workspaceTimelineTrackHeightLabel => 'Hauteur de la piste';

  @override
  String get workspaceTimelinePreviewLabel => 'Aperçu';

  @override
  String get workspaceEndCardSection => 'Marque de fin';

  @override
  String get workspaceEndCardHint =>
      'Ce réglage par défaut s’applique aux projets sans réglage spécifique tant que l’avantage lié à la marque de fin est actif. Votre préférence est conservée après expiration. Le logo dans le coin des GIF suit le même réglage.';

  @override
  String get workspaceEndCardDefaultHiddenTitle =>
      'Masquer la marque de fin par défaut';

  @override
  String get tipsTransparentColorTitle =>
      'La transparence n’est pas qu’une gomme : utilisez-la à la plume comme une couleur';

  @override
  String get tipsTransparentColorDesc =>
      'En sélectionnant la transparence, vous pouvez effacer avec n’importe quel outil : pinceau, lasso, formes, à votre choix. Profitez de la pression et du lissage du pinceau pour arrondir précisément des contours, ou utilisez un pinceau dégradé pour fondre doucement un bord vers la transparence : des effets subtils que la gomme seule ne peut pas obtenir.';

  @override
  String get tipsQuickToolVariantTitle =>
      'L’outil rapide accepte des variantes de pinceau ou de taille, pas seulement des outils différents';

  @override
  String get tipsQuickToolVariantDesc =>
      'L’emplacement d’outil rapide ne se limite pas à alterner entre des outils comme la plume et la gomme : vous pouvez enregistrer la même plume avec un pinceau différent, ou la même gomme à une autre taille, comme entrées séparées. En ne gardant que les combinaisons que vous utilisez vraiment souvent, vous évitez de retourner sans cesse au panneau de réglages.';

  @override
  String get tipsCommonLayerLipSyncTitle =>
      'Les calques communs réduisent aussi la taille des personnages, pas seulement des arrière-plans';

  @override
  String get tipsCommonLayerLipSyncDesc =>
      'Pas seulement les arrière-plans : transformer le calque du personnage lui-même en calque commun fonctionne aussi bien. Ne gardez comme calques normaux que les parties qui changent d’une image à l’autre, comme la bouche ou les yeux qui clignent, et transformez le reste (corps, cheveux) en calque commun. Cela peut réduire considérablement la taille, même pour une animation de synchronisation labiale ou de clignement.';

  @override
  String get tipsCommonLayerKeyframeTitle =>
      'Calques communs et images clés de calque permettent aussi d’économiser de l’espace';

  @override
  String get tipsCommonLayerKeyframeDesc =>
      'Les calques communs peuvent être déplacés, redimensionnés et pivotés avec des images clés de calque. Plutôt que de redessiner chaque image, transformez un seul dessin en calque commun et animez-le avec des images clés : vous obtenez un mouvement simple sans augmenter la taille du fichier.';

  @override
  String get tipsTransferCustomizationTitle =>
      'Le transfert conserve votre configuration personnalisée sur n’importe quel appareil';

  @override
  String get tipsTransferCustomizationDesc =>
      'La fonction de transfert (.niatra) déplace vos réglages personnalisés — pinceaux, thème, disposition de la barre d’outils, palettes, etc. — le tout vers un autre appareil. Changez d’appareil ou travaillez sur plusieurs sans jamais devoir tout reconfigurer depuis zéro.';

  @override
  String get tipsBlendModeUsageTitle =>
      'Choisissez le mode de fusion selon l’effet recherché';

  @override
  String get tipsBlendModeUsageDesc =>
      'Utilisez « Produit » pour les ombres, « Écran » ou « Addition (lueur) » pour la lumière et les reflets, et « Incrustation » ou « Lumière tamisée » pour un ombrage avec un peu de texture. La même couleur peut paraître complètement différente selon le mode de fusion : n’hésitez pas à essayer plusieurs options et à comparer.';

  @override
  String get timelineSaveFailedDialogTitle => 'Échec de l’enregistrement';

  @override
  String get timelineSaveFailedDialogBody =>
      'L’enregistrement a échoué. Veuillez réessayer.';

  @override
  String get licenseSectionIcons => 'À propos des icônes utilisées';

  @override
  String get layerPanelMergeAllVisibleTooltip =>
      'Fusionner tous les calques visibles';

  @override
  String get canvasBrushSliderToggleLabel => 'Détails';

  @override
  String get helpMeshTransformTitle =>
      'Transformation libre / Déformation maillée';

  @override
  String get helpMeshTransformDesc =>
      'Un outil de transformation pour tout le calque, accessible depuis le menu « Paramètres/Édition » en haut à droite du canevas. Contrairement à la transformation d’une sélection, aucune sélection n’est nécessaire : faites glisser les coins ou des points de la grille individuellement avec le doigt pour un résultat libre. Le curseur de densité du panneau de contrôle peut subdiviser la grille jusqu’à 10×10, et pincer deux points différents avec deux doigts à la fois offre un moyen intuitif de pivoter ou redimensionner.';

  @override
  String get layerPanelBrightnessToAlphaLabel => 'Transparence par luminosité';

  @override
  String get layerPanelBrightnessToAlphaHint =>
      'Rend les zones claires plus transparentes. Les couleurs restent les mêmes mais deviennent translucides (toute l’image s’éclaircit, plutôt que le fond blanc ne disparaisse simplement).';

  @override
  String get layerPanelBrightnessToAlphaColorButton => 'Couleur';

  @override
  String get layerPanelBrightnessToAlphaGrayButton => 'Gris';

  @override
  String get tipsRoughLayerRescueTitle =>
      'Encrage dessiné sur le calque de brouillon ? Récupérez-le avec la fonction Transparence par luminosité';

  @override
  String get tipsRoughLayerRescueDesc =>
      'Même si vous avez dessiné l’encrage par erreur sur le calque de brouillon, vous pouvez récupérer uniquement l’encrage sans rien supprimer. 1) Ajoutez un nouveau calque et réglez son mode de fusion sur Diviser. 2) Prélevez la couleur du brouillon à la pipette et remplissez tout ce calque Diviser avec (le brouillon s’estompe). 3) Dupliquez le calque Diviser et le brouillon disparaît complètement. 4) Utilisez « Fusionner tous les calques visibles » dans le panneau des calques pour tout aplatir en un seul calque. 5) Depuis le menu à trois points de ce calque fusionné, choisissez « Transparence par luminosité (Gris) » : les zones blanches deviennent transparentes, ne laissant que l’encrage.';

  @override
  String get timelineEffectTypeMonochrome => 'Filtre monochrome';

  @override
  String get filterNameColorAdjust => 'Réglage des couleurs';

  @override
  String get filterColorAdjustSaturationLabel => 'Saturation';

  @override
  String get filterColorAdjustBrightnessLabel => 'Luminosité';

  @override
  String get filterColorAdjustContrastLabel => 'Contraste';

  @override
  String get canvasColorAdjustTitle => 'Réglage des couleurs';

  @override
  String get canvasColorAdjustAddToDrawFilter =>
      'Ajouter aux filtres de dessin';

  @override
  String get canvasColorAdjustAddToEffectFilter =>
      'Ajouter aux filtres d’effet';

  @override
  String canvasColorAdjustDrawFilterAdded(String name) {
    return '« $name » a été ajouté aux filtres de dessin.';
  }

  @override
  String canvasColorAdjustEffectFilterAdded(String name) {
    return '« $name » a été ajouté aux filtres d’effets de la timeline.';
  }

  @override
  String get canvasColorAdjustMenuTitle => 'Réglage des couleurs';

  @override
  String get canvasEditMenuReferenceWindow => 'Fenêtre de référence';

  @override
  String get canvasEditMenuGroupView => 'Affichage';

  @override
  String get canvasEditMenuGroupEdit => 'Édition';

  @override
  String get canvasEditMenuGroupAutomation => 'Automatisation et saisie';

  @override
  String get canvasEditMenuReferenceWindowSubtitle =>
      'Affiche une image de référence flottante';

  @override
  String get referenceWindowTitle => 'Fenêtre de référence';

  @override
  String get referenceWindowSelectImageButton => 'Choisir une image';

  @override
  String get workspaceDockPanelSection =>
      'Panneaux ouverts par défaut en mode PC';

  @override
  String get workspaceDockPanelHint =>
      'En mode PC/DeX, les panneaux cochés peuvent tous être ancrés et affichés en même temps (le mobile démarre toujours avec tous les panneaux masqués pour éviter les appuis accidentels).';

  @override
  String get workspaceDockPanelBrush => 'Pinceau';

  @override
  String get workspaceDockPanelColorPicker => 'Sélecteur de couleur';

  @override
  String get workspaceDockPanelLayer => 'Calques';

  @override
  String get workspaceDockPanelTone => 'Trame';

  @override
  String get workspaceDockPanelStamp => 'Tampon';

  @override
  String get workspaceDockPanelPenSubTool => 'Plume';

  @override
  String get workspaceDockPanelOnionSkin => 'Papier calque';

  @override
  String get workspaceDockPanelRuler => 'Règle';

  @override
  String get workspaceDockPanelFilter => 'Filtre';

  @override
  String get workspaceDockPanelQuickTool => 'Outil rapide';

  @override
  String get workspaceDockPanelColorAdjust => 'Réglage des couleurs';

  @override
  String get workspaceDockPanelCanvasPreview => 'Aperçu du canevas';

  @override
  String get workspacePcLayoutButton => 'Réglages de disposition PC';

  @override
  String get pcWorkspaceResizeGrip => 'Faites glisser pour redimensionner';

  @override
  String get pcWorkspaceLayoutScreenTitle => 'Réglages de disposition PC';

  @override
  String get pcWorkspaceLayoutIntroHint =>
      'Ajustez l’ordre et la largeur des panneaux lorsque l’écran de canevas s’ouvre en mode PC (paysage + souris/tablette graphique connectée).';

  @override
  String get pcWorkspaceLayoutToolOrderSection => 'Ordre des panneaux d’outils';

  @override
  String get pcWorkspaceLayoutRightOrderSection =>
      'Ordre du panneau de calques, etc.';

  @override
  String get pcWorkspaceLayoutResetWidthButton =>
      'Réinitialiser la largeur et la hauteur';

  @override
  String get pcWorkspaceLayoutResetOrderButton => 'Réinitialiser l’ordre';

  @override
  String get pcWorkspaceLayoutResetWorkspaceConfirmBody =>
      'L’ordre, les dimensions, l’état et le réglage de repli automatique, ainsi que les panneaux ouverts par défaut seront rétablis.';

  @override
  String get pcWorkspaceLayoutResetSizeConfirmBody =>
      'La largeur et la hauteur par défaut des panneaux seront rétablies.';

  @override
  String get pcWorkspaceLayoutResetOrderConfirmBody =>
      'L’ordre des panneaux par défaut sera rétabli.';

  @override
  String get canvasPreviewNavigatorTitle => 'Aperçu du canevas';

  @override
  String get canvasEditMenuPreviewNavigator => 'Aperçu du canevas';

  @override
  String get canvasEditMenuPreviewNavigatorSubtitle =>
      'Afficher une vue d’ensemble réduite (navigateur)';

  @override
  String get filterNamePrism => 'Prisme';

  @override
  String get filterNameThreshold => 'Seuil';

  @override
  String get filterMonochromeColorLabel => 'Couleur du monochrome';

  @override
  String get filterThresholdLabel => 'Seuil';

  @override
  String get filterNameFisheye => 'Œil de poisson';

  @override
  String get filterFisheyeStrength => 'Distorsion';

  @override
  String get filterNameChromaticAberration => 'Aberration chromatique';

  @override
  String get filterChromaticAberrationStrength => 'Intensité du décalage';

  @override
  String get filterNameLensDistortion => 'Distorsion de lentille';

  @override
  String get filterLensDistortionStrength =>
      'Intensité de la lentille (négatif = concave, positif = convexe)';

  @override
  String get filterLensDistortionOffsetX =>
      'Ajustement fin du centre (horizontal)';

  @override
  String get filterNamePixelate => 'Pixel art';

  @override
  String get filterNameAuroraHologram => 'Changement de texture';

  @override
  String get filterAuroraHologramStrength => 'Intensité';

  @override
  String get filterAuroraHologramBrightness => 'Luminosité';

  @override
  String get filterAuroraHologramSaturation => 'Saturation';

  @override
  String get filterHologramKeepLines => 'Conserver le trait';

  @override
  String get filterHologramKeepLinesHint =>
      'Les traits fins presque noirs (le dessin au trait du même calque) gardent leur couleur ; seules les surfaces reçoivent la texture.';

  @override
  String get filterAuroraHologramPresetSilverHologram => 'Hologramme aurore';

  @override
  String get filterAuroraHologramPresetSilverFoil => 'Argent platine';

  @override
  String get filterAuroraHologramPresetSampledGold => 'Or échantillonné';

  @override
  String get filterAuroraHologramPresetLuminousPearl => 'Perle lumineuse';

  @override
  String get filterAuroraHologramPresetAuroraPastel => 'Pastel aurore';

  @override
  String get filterAuroraHologramPresetDarkRainbow => 'Arc-en-ciel sombre';

  @override
  String get filterNameBackgroundBlend => 'Fondu d’arrière-plan';

  @override
  String get filterBackgroundBlendDirection => 'Direction ombre/lumière (liée)';

  @override
  String get filterBackgroundBlendLength => 'Longueur ombre/lumière (liée)';

  @override
  String get filterBackgroundBlendBlur => 'Intensité du flou';

  @override
  String get filterPixelateBlockSize => 'Taille des blocs';

  @override
  String get filterPixelateDither => 'Tramage';

  @override
  String get filterPixelateDitherHint =>
      'Là où aucune couleur n’est proche, dispose les couleurs permises selon un motif régulier pour s’en rapprocher';

  @override
  String get filterPixelateModeBlock => 'Taille des blocs';

  @override
  String get filterPixelateModeDots => 'Nombre de points';

  @override
  String get filterPixelateDotsWide => 'Points en largeur';

  @override
  String get filterPixelateDotsHigh => 'Points en hauteur';

  @override
  String filterPixelateDotsSummary(int wide, int high) {
    return '$wide × $high points';
  }

  @override
  String get filterLensDistortionOffsetY =>
      'Ajustement fin du centre (vertical)';

  @override
  String get filterLensDistortionNoMaskHint =>
      'Peignez sur le canevas, avec « Pinceau » ou « Pot de peinture », la zone à transformer en lentille (par exemple les verres de lunettes). S’il existe une sélection ou un calque de sélection, la zone part de celle-ci.';

  @override
  String get filterLensMaskTitle => 'Zone de la lentille';

  @override
  String get filterLensMaskPen => 'Pinceau';

  @override
  String get filterLensMaskEraser => 'Gomme';

  @override
  String get filterLensMaskBucket => 'Pot de peinture';

  @override
  String get filterLensMaskBrushSize => 'Taille du pinceau';

  @override
  String get filterLensMaskClear => 'Effacer la zone';

  @override
  String get filterSelectionOnlyHint =>
      'S’applique uniquement à l’intérieur de la sélection';

  @override
  String get tipsStockingDenierTitle =>
      'La finesse des trames bas/collants varie selon le denier';

  @override
  String get tipsStockingDenierDesc =>
      'Les nouvelles trames bas/collants de la liste ont un maillage plus serré pour les deniers faibles (tissu plus fin) ; la plus basse, 10 deniers, est volontairement assez fine pour produire du moiré selon la résolution d’affichage ou d’export. Les collants à denier élevé utilisent un espacement plus large pour un rendu plus opaque : choisissez celle qui convient aux jambes du personnage.';

  @override
  String get tipsFisheyeChromaticTitle =>
      'Utilisez les filtres œil de poisson et aberration chromatique pour une distorsion et un liseré façon objectif';

  @override
  String get tipsFisheyeChromaticDesc =>
      'Le filtre œil de poisson bombe le centre de l’image et comprime les bords, recréant la courbure d’une prise de vue grand angle ou fisheye. Le filtre d’aberration chromatique décale légèrement les canaux RVB pour recréer le liseré coloré typique d’un objectif bon marché. Les deux sont disponibles à la fois comme filtres de dessin (appliqués directement à un calque) et comme filtres d’effet (appliqués sur une plage de la timeline). Le centre du fisheye peut aussi être déplacé en faisant glisser le + sur le canevas.';

  @override
  String get tipsLensDistortionTitle =>
      'Recréez la distorsion vue à travers des lunettes avec le filtre de distorsion de lentille';

  @override
  String get tipsLensDistortionDesc =>
      'Choisissez le filtre de distorsion de lentille et peignez la zone de la lentille (par exemple les verres de lunettes) sur le canevas avec le « Pinceau » du panneau, ou touchez une zone entourée de traits avec le « Pot de peinture » : la déformation locale du filtre s’applique alors uniquement à cette zone. Ce qui déborde s’efface avec la « Gomme », et chaque tracé peut être annulé et rétabli un par un. S’il existe une sélection ou un calque de sélection, la zone part de celle-ci. Le curseur d’intensité rétrécit la zone comme une lentille concave pour les valeurs négatives et l’agrandit comme une lentille convexe pour les valeurs positives ; vous pouvez aussi ajuster finement la position du centre. Vous pouvez peindre les deux verres et appliquer l’effet aux deux en même temps. La zone peinte n’apparaît jamais dans les exports ni dans l’œuvre finale. Il est aussi pratique pour recréer l’aspect d’un paysage vu à travers l’objectif d’un appareil photo : peignez une large zone, comme l’arrière-plan, et appliquez une intensité légère.';

  @override
  String get tipsSphereShadingTitle =>
      'Donner du volume d’un coup avec l’Ombrage sphérique';

  @override
  String get tipsSphereShadingDesc =>
      'Le filtre Ombrage sphérique applique la couleur de lumière à l’intérieur d’une lumière elliptique et la couleur d’ombre à l’extérieur, uniquement sur le dessin. Déplacez et redimensionnez la lumière avec les curseurs ou en faisant glisser sur le canevas le + (position) et les poignées rondes (taille), puis adoucissez le bord avec Flou du bord pour un ombrage arrondi comme celui d’une sphère. Chaque couleur a son propre mode de fusion (par exemple Produit pour l’ombre et Écran pour la lumière) ; avec « Les deux en une fusion », un dégradé de la couleur d’ombre à la couleur de lumière s’applique avec un seul mode de fusion, comme Lumière crue. Une couleur peut être transparente : ce côté reste alors inchangé. S’il y a une sélection ou un calque de sélection peint, l’ombrage ne s’applique qu’à cet endroit.';

  @override
  String get tipsBackgroundBlendTitle =>
      'Intégrer un personnage dans un arrière-plan';

  @override
  String get tipsBackgroundBlendDesc =>
      'Pour qu’un personnage dessiné s’intègre naturellement à une photo ou une peinture d’arrière-plan, appliquez d’abord le filtre de dessin « Fondu d’arrière-plan » au calque du personnage. Il ramène vos couleurs dans la plage de luminosité et de saturation de l’arrière-plan et ajoute d’un coup sa couleur générale (Incrustation), la lumière et l’ombre dans la couleur de ses propres ombres (Lumière crue), la lumière renvoyée par le sol (Écran) et les lumières intenses comme un néon (Addition (lueur)). Pour aller plus loin, peignez d’abord les grandes ombres sur un calque Produit ou Lumière crue, puis ajoutez les reflets propres à chaque matière (verre, métal) et la lumière du contour sur des calques Écran ou Addition (lueur). Gardez la partie à mettre en valeur (le visage, par exemple) claire et vive, et assombrissez un peu les alentours avec Vignettage pour qu’elle ressorte. Terminez en ajustant la couleur générale avec Courbe de tons ou Niveaux.';

  @override
  String get tipsLineArtExtractionTitle =>
      'Extraire un dessin au trait en combinant réglage des couleurs, seuil et transparence par luminosité';

  @override
  String get tipsLineArtExtractionDesc =>
      'Augmentez le contraste avec le réglage des couleurs pour faire ressortir les traits, puis utilisez le filtre de seuil pour diviser l’image en noir et blanc purs : les traits se séparent nettement du reste. Le curseur de seuil permet d’ajuster librement l’épaisseur du trait et son aspect plus ou moins estompé. Enfin, utilisez « Transparence par luminosité (gris) » dans le menu à trois points du calque pour rendre transparentes les zones blanches (tout sauf les traits), ne laissant que le dessin au trait. Pratique pour extraire un dessin au trait propre à partir d’une photo ou d’une esquisse.';

  @override
  String get tipsLineColorUsageTitle =>
      'Choisir le mode de couleur du trait selon l’usage améliore le rendu';

  @override
  String get tipsLineColorUsageDesc =>
      'Pour garder le contour d’une partie lisible sans faire ressortir le trait, choisissez « Trace de couleur / fondu avec le trait » dans « Couleur du trait ». Pour les parties servant aux ombres ou aux lumières, choisissez « Identique au remplissage » : le trait reprend la couleur du remplissage au lieu de ressortir plus sombre. Choisissez « Couleur spécifiée » si vous souhaitez volontairement une autre couleur de trait.';

  @override
  String get tipsBlushAutofillTitle =>
      'Le remplissage auto gère même un rougissement doux';

  @override
  String get tipsBlushAutofillDesc =>
      'Réglez la couleur du trait sur une couleur spécifiée transparente, et le remplissage sur un dégradé Radial (centre→extérieur) avec le rose du rougissement et le transparent comme ses deux couleurs : cela ne dépose que le rougissement des joues, en douceur, sur la peau. Ajustez l’opacité du rougissement et la position du point de couleur pour un fondu encore plus naturel.';

  @override
  String get autofillPartResetTraceButton => 'Réinitialiser';

  @override
  String get premiumScreenTitle => 'Premium';

  @override
  String get premiumComparisonPremium => 'Premium';

  @override
  String premiumRegisteredDateLabel(String date) {
    return 'Inscription : $date';
  }

  @override
  String premiumNextRenewalDateLabel(String date) {
    return 'Prochain renouvellement : $date';
  }

  @override
  String get workspaceAppliedSnackbar =>
      'Les réglages de l’espace de travail ont été appliqués.';

  @override
  String get workspaceSaveAsButton =>
      'Enregistrer l’espace de travail sous... / Écraser';

  @override
  String get workspaceShareButton => 'Partager l’espace de travail';

  @override
  String get workspaceShareSelectTitle =>
      'Sélectionnez un espace de travail à partager';

  @override
  String workspaceShareFailedSnackbar(String error) {
    return 'Échec du partage : $error';
  }

  @override
  String get workspaceImportFromFileButton => 'Importer depuis un fichier';

  @override
  String workspaceImportFailedSnackbar(String error) {
    return 'Échec de l’importation : $error';
  }

  @override
  String get workspaceNameRequiredError => 'Veuillez saisir un nom.';

  @override
  String get workspaceOverwriteSelectTitle =>
      'Sélectionnez un espace de travail à écraser';

  @override
  String get workspaceOverwriteConfirmTitle => 'Confirmer l’écrasement';

  @override
  String workspaceOverwriteConfirmBody(String name) {
    return 'Ceci va écraser « $name » avec les réglages actuels. Son contenu précédent sera perdu. Continuer ?';
  }

  @override
  String get workspaceOverwriteButton => 'Écraser';

  @override
  String get splashCommunityButtonTitle => 'Place des œuvres';

  @override
  String get splashCommunityButtonSubtitle => 'Voir les œuvres publiées';

  @override
  String get splashCreateButton => 'Créer une animation';

  @override
  String get communitySampleBadge => 'Données fictives';

  @override
  String get communityScreenTitle => 'Place des œuvres';

  @override
  String get communityTabNew => 'Nouveautés';

  @override
  String get communityTabRanking => 'Classement';

  @override
  String get communityTabFavoriteAuthors => 'Abonnements';

  @override
  String get communitySearchHint => 'Rechercher par titre ou nom d’utilisateur';

  @override
  String get communityEmptyState => 'Aucune œuvre à afficher';

  @override
  String get communityFilterNoResults =>
      'Aucune œuvre ne correspond aux filtres';

  @override
  String get communityClearFilters => 'Effacer les filtres';

  @override
  String communitySearchNoResults(String query) {
    return 'Aucune œuvre ne correspond à « $query »';
  }

  @override
  String get communityTagSearchHint => 'Rechercher par tag';

  @override
  String get communityAddTagButton => 'Ajouter un tag';

  @override
  String get communityAddTagDialogTitle => 'Ajouter un tag';

  @override
  String get communityAddTagDialogHint => 'Saisissez un nom de tag';

  @override
  String get communityTagLockTooltip =>
      'Verrouiller ce tag (auteur uniquement)';

  @override
  String get communityTagUnlockTooltip =>
      'Déverrouiller ce tag (auteur uniquement)';

  @override
  String get communityRemoveTagTooltip => 'Supprimer ce tag';

  @override
  String get communityPostButton => 'Publier';

  @override
  String get communityRankingPeriodAllTime => 'Total';

  @override
  String get communityRankingPeriodYearly => 'Annuel';

  @override
  String get communityRankingPeriodMonthly => 'Mensuel';

  @override
  String get communityRankingPeriodWeekly => 'Hebdomadaire';

  @override
  String get communityRankingPeriodDaily => 'Quotidien';

  @override
  String get communityRankingSortBookmarks => 'Favoris';

  @override
  String get communityRankingSortAscendingTooltip =>
      'Croissant (du plus petit au plus grand)';

  @override
  String get communityRankingSortDescendingTooltip =>
      'Décroissant (du plus grand au plus petit)';

  @override
  String communityWorkDetailPostedLabel(String date) {
    return 'Publié le $date';
  }

  @override
  String get communityWorkDetailViewOnYoutube => 'Voir sur YouTube';

  @override
  String get communityWorkDetailBookmarkAdd => 'Ajouter aux favoris';

  @override
  String get communityWorkDetailBookmarkRemove => 'Dans les favoris';

  @override
  String get communityWorkDetailReportButton => 'Signaler';

  @override
  String get communityWorkDetailBlockButton => 'Bloquer';

  @override
  String get communityVisibilityCardTitle =>
      'Visibilité sur la Place des œuvres';

  @override
  String get communityVisibilityPublishedDesc =>
      'Visible : affiché dans Nouveautés, Classements et la liste des œuvres de cet auteur.';

  @override
  String get communityVisibilityHiddenDesc =>
      'Masqué : retiré de Nouveautés, Classements et la liste des œuvres de cet auteur (réglage indépendant de la visibilité côté YouTube).';

  @override
  String get communityVisibilityHiddenBadge => 'Masqué';

  @override
  String get communityWorkDetailTitle => 'Détails de l’œuvre';

  @override
  String get communityWorkHiddenByFilterMessage =>
      'Cette œuvre est masquée par vos filtres d’affichage';

  @override
  String get communityWorkHiddenByMuteMessage =>
      'Cette œuvre n’est pas affichée, car vous avez masqué ce créateur';

  @override
  String get communityEditFailed =>
      'Impossible d’enregistrer la modification. Vérifiez votre connexion et réessayez.';

  @override
  String get communityEditSignInRequired =>
      'Connectez-vous avec votre compte Google pour effectuer cette modification';

  @override
  String get communityFloatingPreviewDetailButton => 'Détails';

  @override
  String get communityFloatingPreviewPlayTooltip => 'Lecture';

  @override
  String get communityFloatingPreviewPauseTooltip => 'Pause';

  @override
  String get communityFloatingPreviewResizeTooltip => 'Redimensionner l’aperçu';

  @override
  String get communityFloatingPreviewMoveHint =>
      'Faites glisser pour déplacer l’aperçu, ou utilisez Alt + les flèches.';

  @override
  String get communityFloatingPreviewCompactHint =>
      'Ouvrez Détails pour voir cette œuvre.';

  @override
  String communityAuthorWorksCount(int count) {
    return '$count œuvres';
  }

  @override
  String communityAuthorFollowerCount(int count) {
    return '$count abonnés';
  }

  @override
  String communityAuthorFollowingCount(int count) {
    return '$count abonnements';
  }

  @override
  String get communityFollowNotificationsTooltip => 'Notifications';

  @override
  String get communityFollowNotificationsEmpty => 'Aucune notification';

  @override
  String get communityFollowNotificationsSignInRequired =>
      'Connectez-vous avec Google pour voir vos notifications de la Place des œuvres.';

  @override
  String get communityNoWorksMessage => 'Aucune œuvre';

  @override
  String get communityFavoriteAuthorFollow => 'Suivre';

  @override
  String get communityFavoriteAuthorFollowing => 'Abonné(e)';

  @override
  String get communityFavoriteAuthorsEmptyTitle => 'Aucun auteur suivi';

  @override
  String get communityFavoriteAuthorsEmptyBody =>
      'Suivez un créateur depuis sa page pour voir ses dernières œuvres ici.';

  @override
  String get communityRepostCount => 'Repartages';

  @override
  String get communityRepostButton => 'Repartager';

  @override
  String get communityRepostedButton => 'Repartagé';

  @override
  String communityRepostedByBadge(String name) {
    return 'Repartagé par $name';
  }

  @override
  String get communityAuthorSortPosted => 'Date de publication';

  @override
  String get communityAuthorTabWorks => 'Œuvres';

  @override
  String get communityAuthorTabBookmarks => 'Favoris';

  @override
  String get communityBookmarksHiddenMessage =>
      'Vos œuvres en favoris ne sont pas encore chargées ou ne sont plus publiques';

  @override
  String get communityBookmarksEmptyMessage => 'Aucune œuvre en favoris';

  @override
  String get communityShortsBadge => 'Vertical';

  @override
  String get communityLandscapeBadge => 'Horizontal';

  @override
  String get communityVideoTypeFilterTooltip => 'Filtrer par type de vidéo';

  @override
  String get communityVideoTypeFilterAll => 'Tous';

  @override
  String get communityVideoTypeFilterShortOnly => 'Vertical uniquement';

  @override
  String get communityVideoTypeFilterLongOnly => 'Horizontal uniquement';

  @override
  String get communityShortsModeTooltip => 'Regarder en mode vertical';

  @override
  String get communityShortsModeEmptySnackbar =>
      'Aucune vidéo verticale disponible';

  @override
  String get communityShortsModeExitTooltip => 'Quitter le mode vertical';

  @override
  String get pixelColorModeLabel => 'Mode de couleur';

  @override
  String get pixelColorModeNone => 'Ne pas limiter les couleurs';

  @override
  String get pixelColorModePalette => 'Choisir dans une palette';

  @override
  String get pixelColorModeExplicit => 'Spécifier les couleurs';

  @override
  String get pixelColorModeCount => 'Spécifier le nombre de couleurs';

  @override
  String pixelColorLevelsLabel(int count) {
    return 'Couleurs : $count';
  }

  @override
  String get pixelColorChipDeleteTooltip => 'Supprimer cette couleur';

  @override
  String get pixelColorChipAddButton => 'Ajouter une couleur';

  @override
  String get pixelArtPaletteNameRequiredError =>
      'Veuillez saisir un nom de palette';

  @override
  String get pixelArtPaletteEditTitle => 'Modifier la palette';

  @override
  String get pixelArtPaletteAddTitle => 'Ajouter une palette';

  @override
  String get pixelArtPaletteNameLabel => 'Nom de la palette';

  @override
  String get pixelArtPalettePickerTitle => 'Choisir une palette';

  @override
  String get pixelArtPalettePickerEmpty =>
      'Aucune palette enregistrée. Appuyez sur « Ajouter » pour en créer une.';

  @override
  String get pixelArtPalettePickerApplyButton => 'Appliquer';

  @override
  String get storageScreenTitle => 'Libérer de l’espace';

  @override
  String get storageDeviceChartTitle => 'Stockage de l’appareil';

  @override
  String get storageBreakdownChartTitle => 'Répartition NIARIM';

  @override
  String get storageActionsTitle => 'Organiser';

  @override
  String get storageCalculating => 'Calcul en cours…';

  @override
  String get storageBreakdownLoadFailed =>
      'Impossible de calculer la répartition';

  @override
  String get storageBreakdownIncomplete =>
      'Certaines données n’ont pas pu être lues ; les totaux peuvent être inférieurs à l’utilisation réelle';

  @override
  String get storageBreakdownEmpty =>
      'Aucune donnée pour l’instant. La répartition s’affichera ici quand vous créerez un projet.';

  @override
  String get storageDeviceSpaceUnavailable =>
      'Impossible de consulter le stockage de l’appareil';

  @override
  String get storageCategoryNiarimTotal => 'NIARIM';

  @override
  String get storageCategoryOtherApps => 'Autres';

  @override
  String get storageCategoryFree => 'Espace libre';

  @override
  String get storageCategoryMaterials => 'Matériaux';

  @override
  String get storageCategoryProjectData => 'Données du projet';

  @override
  String get storageCategoryExports => 'Fichiers exportés';

  @override
  String get storageCategoryCustomAssets =>
      'Pinceaux/trames/tampons/polices personnalisés';

  @override
  String get storageCategoryCache => 'Cache';

  @override
  String get storageCategoryTrash => 'Corbeille';

  @override
  String get storageClearCacheButton => 'Vider le cache';

  @override
  String get storageRemoveUnusedMaterialsButton =>
      'Supprimer les matériaux inutilisés (tous les projets)';

  @override
  String storageRemoveUnusedMaterialsConfirmBody(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count matériaux inutilisés',
      one: '$count matériau inutilisé',
    );
    return 'Supprimer $_temp0 ($size) ? Cette action est irréversible.';
  }

  @override
  String get storageNoUnusedMaterials => 'Aucun matériau inutilisé.';

  @override
  String get storageEmptyTrashButton => 'Vider la corbeille';

  @override
  String storageEmptyTrashKeptUnreadFolders(String retry) {
    return 'La corbeille n’a pas été vidée. Les dossiers contenant des projets impossibles à charger ne peuvent pas être supprimés tant qu’ils ne sont pas chargés. Appuyez sur « $retry » sur l’écran d’accueil pour les recharger.';
  }

  @override
  String get storageOrganizeProjectsButton => 'Organiser les projets';

  @override
  String get storageEraseAllButton =>
      'Effacer toutes les données (remise à zéro)';

  @override
  String storageClearCacheDoneSnackbar(String size) {
    return '$size de cache libérés';
  }

  @override
  String fileSizeBytes(String size) {
    return '$size o';
  }

  @override
  String fileSizeKilobytes(String size) {
    return '$size Ko';
  }

  @override
  String fileSizeMegabytes(String size) {
    return '$size Mo';
  }

  @override
  String fileSizeGigabytes(String size) {
    return '$size Go';
  }

  @override
  String fileSizeTerabytes(String size) {
    return '$size To';
  }

  @override
  String get storageEraseAllConfirmTitle => 'Effacer toutes les données ?';

  @override
  String get storageEraseAllConfirmBody =>
      'NIARIM revient à son état d’installation et redémarre depuis l’écran d’accueil. Action irréversible.';

  @override
  String get storageEraseAllErasedTitle => 'Ce qui est effacé';

  @override
  String get storageEraseAllErasedItems =>
      'Les projets et matériaux (corbeille, sauvegardes et enregistrement automatique compris)\nLes fichiers exportés\nVos pinceaux, trames, tampons, palettes, thèmes, polices et macros\nTous les paramètres (vous êtes aussi déconnecté de Google)';

  @override
  String get storageEraseAllKeptTitle => 'Ce qui est conservé';

  @override
  String get storageEraseAllKeptItems =>
      'Les opales, les missions et votre abonnement Premium (conservés avec votre compte Google ; reconnectez-vous avec le même compte pour les retrouver)\nLes œuvres publiées sur la Place des œuvres\nLes fichiers partagés avec d’autres applications et les anciens exports dans les dossiers partagés';

  @override
  String get storageEraseAllConfirmWord => 'SUPPRIMER';

  @override
  String storageEraseAllConfirmPrompt(String word) {
    return 'Pour confirmer, saisissez $word';
  }

  @override
  String get storageEraseAllInProgress => 'Effacement de toutes les données…';

  @override
  String get storageEraseAllDoneSnackbar =>
      'Toutes les données ont été effacées. Veuillez redémarrer l’application.';

  @override
  String get homeDrawerStorage => 'Libérer de l’espace';

  @override
  String get helpStorageTitle => 'Libérer de l’espace';

  @override
  String get helpStorageDesc =>
      'Consultez l’espace utilisé par NIARIM sur votre appareil, ainsi qu’une répartition de son contenu (projets, matériaux, fichiers exportés, pinceaux/trames/tampons/polices personnalisés, cache et corbeille) sous forme de graphiques circulaires. Vous pouvez vider le cache, supprimer les matériaux inutilisés dans tous les projets, vider la corbeille, organiser vos projets ou effacer toutes les données (remise à zéro).';

  @override
  String get helpWidgetSettingsTitle => 'Widgets de l’écran d’accueil';

  @override
  String get helpWidgetSettingsDesc =>
      'Réglages des trois types de widgets à placer sur l’écran d’accueil du téléphone : une image d’une œuvre, le widget « Créer une animation » et le widget « Place des œuvres ». Les widgets eux-mêmes s’ajoutent par appui long sur l’écran d’accueil, pas depuis l’application. « Choisir une œuvre » reprend le même tri, mode d’affichage, recherche et filtre des favoris que l’onglet des projets, puis permet de choisir l’image exacte à afficher dans un aperçu doté de commandes de lecture. Les widgets « Créer une animation » et « Place des œuvres » permettent de choisir si le fond suit le thème de l’application ou utilise une couleur définie par vous.';

  @override
  String get colorPickerImportPaletteTooltip => 'Importer une palette';

  @override
  String get colorPickerSharePaletteTooltip => 'Partager';

  @override
  String get colorPickerShareViaFile => 'Partager en tant que fichier';

  @override
  String colorPickerShareFailedSnackbar(String error) {
    return 'Échec du partage : $error';
  }

  @override
  String get colorPickerShareViaQr => 'Partager via un code QR';

  @override
  String get qrShareTooLargeHint =>
      'Les éléments avec images ou trop de données pour un QR doivent être partagés en fichiers.';

  @override
  String get colorPickerImportViaFile => 'Choisir un fichier';

  @override
  String colorPickerImportFailedSnackbar(String error) {
    return 'Échec de l’importation : $error';
  }

  @override
  String get colorPickerImportViaQr => 'Coller le texte du code QR';

  @override
  String get qrImportFailedError =>
      'Échec de l’importation. Vérifiez que le texte est correct.';

  @override
  String get qrImportHint =>
      'Scannez le code QR affiché sur l’autre appareil avec une application caméra standard, puis collez ici le texte copié.';

  @override
  String get qrImportFieldHint => 'Collez le texte scanné';

  @override
  String get qrImportPasteButton => 'Coller depuis le presse-papiers';

  @override
  String get qrImportSubmitButton => 'Importer';

  @override
  String get qrShareHint =>
      'Scannez ce code QR avec une application caméra standard pour copier le texte. Sur l’autre appareil, utilisez « Importer » pour coller le texte copié.';

  @override
  String get qrShareCopiedSnackbar => 'Texte copié';

  @override
  String get qrShareCopyButton => 'Copier le texte';

  @override
  String get toolbarItemBlur => 'Flou gaussien';

  @override
  String get toolbarItemMosaic => 'Mosaïque';

  @override
  String get toolbarFingerSubtoolWarp => 'Déformer';

  @override
  String get brushSettingsEdgeJitterTitle => 'Bavure de bord';

  @override
  String get filterNameInkPool => 'Accumulation d’encre';

  @override
  String get filterInkPoolColor => 'Couleur';

  @override
  String get filterInkPoolRange => 'Plage';

  @override
  String get filterInkPoolCenterWidth => 'Épaisseur centrale';

  @override
  String get filterInkPoolMaxAngle => 'Angle maximal';

  @override
  String get filterInkPoolMaxAngleHint =>
      'L’encre s’accumule dans les angles où les traits se rejoignent à cet angle ou moins (90° couvre les angles aigus et droits ; 180°, aussi les angles obtus).';

  @override
  String filterInkPoolLayerNameSuffix(String name) {
    return '$name (Accumulation d’encre)';
  }

  @override
  String get filterCanvasEyedropperTooltip =>
      'Choisir une couleur sur le canevas';

  @override
  String get filterInkPoolEyedropperHint =>
      'Touchez le canevas pour choisir la couleur de l’accumulation d’encre';

  @override
  String get filterOutlineEyedropperHint =>
      'Touchez le canevas pour choisir la couleur du contour';

  @override
  String get filterNameAutoLineart => 'Encrage automatique';

  @override
  String get filterAutoLineartRoughWidth => 'Épaisseur du brouillon';

  @override
  String get filterAutoLineartOutputWidth => 'Épaisseur du trait';

  @override
  String get filterAutoLineartTaperLength => 'Longueur de l’effilé';

  @override
  String get filterAutoLineartTaper => 'Effiler les extrémités';

  @override
  String get filterAutoLineartSmoothing => 'Lissage';

  @override
  String filterAutoLineartLayerNameSuffix(String name) {
    return '$name (Encrage automatique)';
  }

  @override
  String get customAutomationTitle => 'Macros';

  @override
  String get customAutomationAdd => 'Ajouter une automatisation';

  @override
  String get customAutomationNewTitle => 'Nouvelle automatisation';

  @override
  String get customAutomationNameLabel => 'Nom';

  @override
  String get customAutomationStartRecording => 'Démarrer l’enregistrement';

  @override
  String get customAutomationStopRecording => 'Arrêter l’enregistrement';

  @override
  String get customAutomationRunConfirmTitle =>
      'Exécuter cette automatisation ?';

  @override
  String get customAutomationCurrentFrame => 'Exécuter sur l’image actuelle';

  @override
  String get customAutomationAllFrames => 'Exécuter sur toutes les images';

  @override
  String get customAutomationYes => 'Oui';

  @override
  String get customAutomationNo => 'Non';

  @override
  String get customAutomationRenameTitle => 'Renommer';

  @override
  String get customAutomationDeleteTitle => 'Supprimer cette automatisation ?';

  @override
  String get customAutomationImport => 'Importer une automatisation';

  @override
  String get customAutomationExport => 'Partager / exporter';

  @override
  String get customAutomationRerecord => 'Réenregistrer';

  @override
  String get customAutomationImportInvalid =>
      'Impossible d’importer ce fichier';

  @override
  String get customAutomationEmpty => 'Aucune automatisation enregistrée';

  @override
  String customAutomationStepCount(int count) {
    return '$count étapes';
  }

  @override
  String get customAutomationStopConfirmTitle =>
      'Arrêter l’enregistrement de cette automatisation ?';

  @override
  String get customAutomationStopConfirmContinue => 'Continuer';

  @override
  String get customAutomationReviewHint =>
      'Réordonnez ou supprimez des étapes avant d’enregistrer';

  @override
  String get customAutomationNoRecordedSteps => 'Aucune action enregistrée';

  @override
  String get customAutomationCanvasStep => 'Action de canevas';

  @override
  String get customAutomationTimelineStep => 'Action de timeline';

  @override
  String get customAutomationBackToRecording => 'Revenir à l’enregistrement';

  @override
  String get customAutomationStopConfirmStop => 'Arrêter';

  @override
  String get filterNameVhsNoise => 'Bruit VHS';

  @override
  String get filterNameMosaic => 'Mosaïque';

  @override
  String get filterNameGenericNoise => 'Bruit';

  @override
  String get filterVhsNoiseStrength => 'Bruit';

  @override
  String get filterVhsScanlineStrength => 'Lignes de balayage';

  @override
  String get filterVhsColorBleed => 'Bavure des couleurs';

  @override
  String get filterVhsTracking => 'Suivi';

  @override
  String get timelineEffectTypeVhsNoise => 'Bruit VHS';

  @override
  String get customAutomationSpecifiedFrames =>
      'Exécuter sur les images spécifiées';

  @override
  String get customAutomationFrameFrom => 'Image de début';

  @override
  String get customAutomationFrameTo => 'Image de fin';

  @override
  String get customAutomationFrameRangeInvalid =>
      'Saisissez une plage d’images valide.';

  @override
  String get customAutomationRunAction => 'Exécuter';

  @override
  String get customAutomationFavoriteAction => 'Ajouter aux favoris';

  @override
  String get customAutomationUnfavoriteAction => 'Retirer des favoris';

  @override
  String get brushSettingsStrokeSection => 'Sensation du trait';

  @override
  String get brushSettingsEffectsSection => 'Contour, pliage et répétition';

  @override
  String get brushSettingsPressureOnSection => 'Pression activée';

  @override
  String get brushSettingsPressureOffSection => 'Pression désactivée';

  @override
  String get brushSettingsWeakPressureLabel => 'Faible';

  @override
  String get brushSettingsStrongPressureLabel => 'Forte';

  @override
  String get helpCustomAutomationTitle =>
      'Automatisations personnalisées (enregistrement d’actions)';

  @override
  String get helpCustomAutomationDesc =>
      'Enregistrez les actions prises en charge sur le canevas ou la timeline sous forme de séquence nommée à réexécuter. Ajoutez un élément depuis Automatisations pour lancer l’enregistrement, puis réordonnez ou supprimez des étapes dans l’écran de vérification avant de sauvegarder. Vous pouvez renommer, réenregistrer, supprimer, filtrer par favoris, exporter et importer les automatisations enregistrées sous forme de fichiers JSON. Pour une automatisation limitée au canevas et entièrement enregistrée dans une seule image, vous pouvez l’exécuter sur l’image actuelle, une plage précise ou toutes les images. Le choix de la plage n’apparaît pas pour les automatisations de timeline ni pour les enregistrements couvrant plusieurs images.';

  @override
  String get tipsOfficialAutomationPresetsTitle =>
      'Adaptez les macros officielles à votre dessin';

  @override
  String get tipsOfficialAutomationPresetsDesc =>
      '« Trait (numérique) » est un préréglage qui regroupe les étapes de l’encrage automatique jusqu’à l’accumulation d’encre.\nDans l’écran de vérification, vous pouvez réordonner ou supprimer des étapes ; en réenregistrant, vous pouvez ajouter des actions.\nExportez les réglages avant de les modifier : vous pourrez ainsi revenir à l’état d’origine en toute tranquillité.\n« Extraction du trait (analogique) » applique dans l’ordre réglage des couleurs → seuil → transparence par luminosité.\n« Trace de couleur du trait » reprend dans le trait les couleurs peintes en dessous, puis, par flou, duplication, fusion et réglage de la trace de couleur, fond chaque trait dans une teinte plus profonde que l’aplat voisin.';

  @override
  String get tipsTexturePrismVhsTitle =>
      'Essayez Texture, Prisme et VHS sur des calques dupliqués';

  @override
  String get tipsTexturePrismVhsDesc =>
      'Le filtre Changement de texture part d’une base au choix (Hologramme aurore, Or échantillonné, Argent platine, Perle lumineuse, Pastel aurore ou Arc-en-ciel sombre), puis permet d’ajuster la luminosité et la saturation. Prisme crée une bande lumineuse avec le flou et la direction de l’arc-en-ciel ; Bruit VHS combine bruit, saturation, luminosité et contraste pour évoquer une vieille cassette. Tester chaque effet sur un calque dupliqué facilite la comparaison ; ajoutez vos réglages préférés aux favoris pour les réutiliser rapidement.';

  @override
  String get customAutomationExecutionFailed =>
      'L’automatisation n’a pas pu se terminer. Vérifiez ses réglages et le calque cible.';

  @override
  String get brushLateralRepeat => 'Répétition latérale';

  @override
  String get brushLateralRepeatCount => 'Nombre de répétitions';

  @override
  String get brushLateralRepeatSpacing => 'Espacement latéral';

  @override
  String get brushOutline => 'Contour';

  @override
  String get brushOutlineWidth => 'Largeur du contour';

  @override
  String get brushOutlineColor => 'Couleur du contour';

  @override
  String get brushOutlineColorPicker => 'Sélecteur de couleur';

  @override
  String get brushOutlineEyedropper => 'Pipette';

  @override
  String get brushOutlineKeepOverlap => 'Conserver les chevauchements';

  @override
  String get brushOutlineKeepOverlapHelp =>
      'Activé : le contour est aussi tracé là où les traits se chevauchent. Désactivé : les traits qui se chevauchent fusionnent ; là où ils se chevauchent, ni contour ni ligne de pli ne sont tracés, et seul l’extérieur de la forme combinée est contourné.';

  @override
  String get brushOutlineAccent => 'Variation d’épaisseur';

  @override
  String get brushOutlineAccentWidth => 'Largeur du contour au sommet';

  @override
  String get brushOutlineAccentHelp =>
      'Épaissit le contour vers le sommet de chaque courbe du trait : il garde la largeur du contour là où la courbe commence et finit, et atteint progressivement cette largeur au sommet (la pression et l’attaque et sortie ne changent jamais la largeur du contour : c’est ainsi que le contour obtient sa propre variation). Appliqué quand vous levez le stylet.';

  @override
  String get brushFold => 'Mode pliage';

  @override
  String get brushFoldCurveStart => 'Début de la courbe de la ligne de pli';

  @override
  String get brushFoldLength => 'Longueur du pli';

  @override
  String get brushFoldMode => 'Type de pliage';

  @override
  String get brushFoldModeWaveTopView => 'Ondulation en plongée';

  @override
  String get brushFoldModeWaveLowAngle => 'Ondulation en contre-plongée';

  @override
  String get brushFoldModeCurlRight => 'Boucle à droite';

  @override
  String get brushFoldModeCurlLeft => 'Boucle à gauche';

  @override
  String get brushFoldModeCrescent => 'Boucle en croissant';

  @override
  String get helpBrushFoldTitle => 'Replis du pinceau';

  @override
  String get helpBrushFoldDesc =>
      'Activez Contour dans les réglages du pinceau pour utiliser le Mode pliage. Désactivé, le pinceau dessine exactement comme le stylo de contour normal. Activé, le trait du stylo de contour lui-même se plie et s’enroule selon la direction et les courbes du trait que vous dessinez ; il ne génère pas d’ondulations automatiquement. À chaque courbe, une ligne de pli part du bord intérieur, se courbe puis s’efface. Un trait qui continue de tourner dans le même sens reçoit une ligne de pli plus discrète tous les 270°. Il existe cinq types de pliage. Ondulation en plongée place devant la partie dessinée en premier, Ondulation en contre-plongée celle dessinée ensuite. Boucle à droite choisit l’avant et l’arrière comme si le trait s’enroulait vers la droite de son sens de dessin, Boucle à gauche vers la gauche ; ils suivent le trait, pas l’écran. Boucle en croissant suit les courbes en C que vous dessinez pour former des croissants enchaînés. Longueur du pli règle la longueur de la ligne de pli (elle suit la taille du pinceau), Angle du pli règle la force avec laquelle il suit la courbe du trait (à 50 %, il la suit naturellement) et Début de la courbe de la ligne de pli règle l’épaisseur apparente de la matière (à 0 %, elle se courbe dès son point de départ). Avec le stylo de contour, la pression et l’Effilage (entrée et sortie) ne modifient que la forme d’ensemble, contour compris ; le contour garde son épaisseur et la couleur ne pâlit jamais. Désactivez Conserver les chevauchements sous Contour pour fusionner les traits qui se chevauchent : leurs jonctions ne sont pas contournées et aucune ligne de pli n’est tracée là où ils se chevauchent ; seul l’extérieur de la forme combinée est contourné. Activez Variation d’épaisseur sous Contour pour épaissir le contour vers le sommet de chaque courbe : il garde la largeur du contour là où la courbe commence et finit, et atteint progressivement la Largeur du contour au sommet (appliqué quand vous levez le stylet).';

  @override
  String get tipsBrushFoldTitle =>
      'Choisir la partie d’une mèche qui passe devant';

  @override
  String get tipsBrushFoldDesc =>
      'Activez Contour et Mode pliage, puis essayez d’abord un trait en S léger avec les réglages par défaut. Choisissez Ondulation en plongée pour placer devant la partie dessinée en premier, ou Ondulation en contre-plongée pour celle dessinée ensuite. Pour montrer une mèche qui s’enroule, comparez Boucle à droite, qui s’enroule vers la droite du sens de dessin, et Boucle à gauche, qui s’enroule vers la gauche. Pour une série de courbes en C, utilisez Boucle en croissant afin de former des croissants enchaînés. Chaque type utilise les courbes que vous dessinez ; un trait droit ne devient pas une ondulation automatiquement. Si les lignes de pli sont trop courtes, augmentez Longueur du pli ; si elles ne se courbent pas assez, augmentez Angle du pli ; pour que les cheveux ou le ruban paraissent plus fins, augmentez Début de la courbe de la ligne de pli. Désactivez le Mode pliage pour revenir à un trait normal.';

  @override
  String get tipsFourPanelBrushTitle =>
      'Associez le pinceau quatre cases à la règle droite';

  @override
  String get tipsFourPanelBrushDesc =>
      'Le pinceau Manga quatre cases place des cadres carrés aux traits fins le long du tracé. La taille du pinceau règle à la fois la taille des cases et leur espacement. Activez la règle droite pour les aligner à l’horizontale ou à la verticale.';

  @override
  String get canvasSelectionReferenceWorkingLayer =>
      'Calque de travail uniquement';

  @override
  String get canvasSelectionReferenceVisibleLayers =>
      'Tous les calques visibles';

  @override
  String get brushTipSettingsTitle => 'Pointe et images';

  @override
  String get brushTipShapeLabel => 'Forme de la pointe';

  @override
  String get brushTipRound => 'Ronde';

  @override
  String get brushTipSquare => 'Carré creux';

  @override
  String get brushTipHexagon => 'Hexagone';

  @override
  String get brushTipChain => 'Maillon';

  @override
  String get brushTipBallChain => 'Chaîne à billes';

  @override
  String get brushTipRelativeSpacing => 'Espacement selon la taille';

  @override
  String get brushTipSpacingRatio => 'Espacement / taille';

  @override
  String get brushChainAspect => 'Proportions du maillon';

  @override
  String get brushChainThickness => 'Épaisseur du maillon';

  @override
  String get brushNibFlat => 'Pointe plate';

  @override
  String get brushNibAngle => 'Angle de la pointe';

  @override
  String get brushImagesAdd => 'Ajouter des images';

  @override
  String get brushImageInkLabel => 'Source d’encre de l’image';

  @override
  String get brushImageInkDark => 'Pixels sombres';

  @override
  String get brushImageInkLight => 'Pixels clairs';

  @override
  String get brushImageInkAlpha => 'Pixels opaques';

  @override
  String get brushImageInkHelp =>
      'Dessinez les zones choisies avec la couleur actuelle. Ajoutez plusieurs images pour changer de pointe entre les traits.';

  @override
  String get brushImageOrderLabel => 'Sélection des images';

  @override
  String get brushImageOrderRandom => 'Aléatoire';

  @override
  String get brushImageOrderSequential => 'Dans l’ordre';

  @override
  String get brushImageOrderRandomPerStamp => 'Aléatoire à chaque empreinte';

  @override
  String get brushImageMoveUp => 'Monter';

  @override
  String get brushImageMoveDown => 'Descendre';

  @override
  String get brushImageRemove => 'Retirer l’image';

  @override
  String get filterNoiseStyle => 'Type de bruit';

  @override
  String get filterNoiseColor => 'Bruit de couleur';

  @override
  String get filterNoiseSeed => 'Graine du motif';

  @override
  String get communityContentFilterTitle => 'Filtres d’affichage';

  @override
  String get communityNotificationSettingsTitle => 'Réglages des notifications';

  @override
  String get communityHideGenerativeAiImageVideo =>
      'Masquer les œuvres contenant des images ou vidéos générées par IA';

  @override
  String get communityMutedWords => 'Mots masqués du titre';

  @override
  String get communityMutedWordsHint =>
      'Masque les œuvres dont le titre contient ces mots (sans vérifier les auteurs ni les tags). Ajoutez et modifiez chaque mot séparément.';

  @override
  String get communityMutedTags => 'Tags masqués';

  @override
  String get communityMutedTagsHint =>
      'Masque les œuvres portant ces tags sur la Place des œuvres. Ajoutez chaque tag séparément, sans #.';

  @override
  String get communityMuteAddNew => 'Ajouter';

  @override
  String get communityScrollToTop => 'Retour en haut';

  @override
  String get communityPostPeriodTitle => 'Date de publication';

  @override
  String get communityDurationFilterTitle => 'Durée de la vidéo';

  @override
  String get communitySavedSearches => 'Recherches enregistrées';

  @override
  String get communitySignInPromptTitle => 'Se connecter avec Google';

  @override
  String get communitySignInPromptBody =>
      'Un compte Google lié est requis pour publier et gérer des œuvres, suivre des créateurs, mettre des œuvres en favori et signaler du contenu.';

  @override
  String get communitySignInPromptConnect => 'Associer un compte Google';

  @override
  String get communitySignInUnavailable =>
      'La connexion Google n’est pas disponible : impossible de lier le compte.';

  @override
  String get communitySaveSearch => 'Enregistrer la recherche';

  @override
  String get communitySavedSearchName => 'Nom de la recherche';

  @override
  String get communitySavedSearchLimit => '10 recherches enregistrées maximum';

  @override
  String get communitySavedSearchEmpty => 'Aucune recherche enregistrée';

  @override
  String get communityDurationAny => 'Toutes les durées';

  @override
  String get communityDurationUpTo => 'Jusqu’à N minutes (curseur)';

  @override
  String get communityDurationRange => 'Entre N et N minutes (saisie)';

  @override
  String communityDurationUpToMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes maximum',
      one: '$count minute maximum',
    );
    return '$_temp0';
  }

  @override
  String get communityDurationMinimum => 'Minutes min.';

  @override
  String get communityDurationMaximum => 'Minutes max.';

  @override
  String get communityTagExactMatch =>
      'Correspondance exacte (désactivé pour partielle)';

  @override
  String get communityMinimumViews => 'Vues';

  @override
  String get communityMinimumBookmarks => 'Favoris';

  @override
  String get communityPostPeriodAll => 'Toutes les dates';

  @override
  String get communityPostPeriodToday => 'Aujourd’hui';

  @override
  String get communityPostPeriodWeek => 'Cette semaine';

  @override
  String get communityPostPeriodMonth => 'Ce mois-ci';

  @override
  String get communityPostPeriodYear => 'Cette année';

  @override
  String get communityPostPeriodCustom => 'Période personnalisée';

  @override
  String get communityPostPeriodChooseRange => 'Choisir les dates';

  @override
  String get communityMutedAuthors => 'Créateurs masqués';

  @override
  String get communityMutedAuthorsEmpty => 'Aucun créateur masqué';

  @override
  String get communityUnmuteAuthor => 'Réafficher ce créateur';

  @override
  String get communityMyWorksManagementHeading => 'Gérer les œuvres';

  @override
  String get communityWorkTagsTitle => 'Tags de l’œuvre';

  @override
  String get communityWorkTagsHint =>
      'Ajoutez, modifiez ou supprimez des tags. Le verrouillage empêche les autres de les modifier. Déverrouillez avant toute modification ou suppression.';

  @override
  String get communityWorkEditTag => 'Modifier le tag';

  @override
  String get communityWorkTagChangeFailed => 'Impossible de modifier le tag';

  @override
  String get communityContainsGenerativeAiImageVideo =>
      'Contient des images ou vidéos générées par IA';

  @override
  String get communityContainsGenerativeAiImageVideoHelp =>
      'Activez cette option si une IA générative a servi à créer des images ou une vidéo de l’œuvre. Les logiciels de synthèse vocale ne sont pas concernés.';

  @override
  String get communityAiImageVideoUpdateFailed =>
      'Impossible de modifier « Contient des images ou vidéos générées par IA ». Vérifiez votre connexion et réessayez.';

  @override
  String get communityRetry => 'Réessayer';

  @override
  String get communityPlazaLoading => 'Chargement des œuvres…';

  @override
  String get communityPlazaLoadFailedTitle =>
      'Impossible de charger les œuvres';

  @override
  String get communityPlazaLoadFailedBody =>
      'Vérifiez la connexion et réessayez.';

  @override
  String get communityPlazaEmptyTitle => 'Pas encore d’œuvres';

  @override
  String get communityPlazaEmptyBody =>
      'Les animations créées avec NIARIM apparaîtront ici une fois publiées.';

  @override
  String get communityReloadTooltip => 'Actualiser';

  @override
  String get communityGoogleSignInNotConfigured =>
      'Aucun compte Google n’est associé';

  @override
  String get communityGoogleAccountBusy =>
      'Une autre opération sur le compte Google est en cours. Réessayez une fois qu’elle sera terminée.';

  @override
  String get communityMyWorksTitle => 'Mes publications';

  @override
  String get communityMyWorksViewAuthorPage => 'Voir ma page de créations';

  @override
  String get communityMyWorksAccountRequired =>
      'Connectez votre compte Google pour voir vos créations';

  @override
  String get communityMyWorksSettingsTitle => 'Paramètres de la création';

  @override
  String get communityMyWorksPublishInNiarim => 'Rendre visible dans NIARIM';

  @override
  String get communityMyWorksDeleteNiarim =>
      'Supprimer cette œuvre de la Place des œuvres NIARIM';

  @override
  String get communityMyWorksDeleteConfirmTitle => 'Supprimer cette création ?';

  @override
  String get communityMyWorksDeleteConfirmBody =>
      'Cette création sera supprimée définitivement de NIARIM. La vidéo YouTube sera conservée. Cette action est irréversible.';

  @override
  String get communityMyWorksOpenYoutubeStudio =>
      'Gérer la vidéo dans YouTube Studio';

  @override
  String get communityMyWorksYoutubeStudioHelp =>
      'Modifiez la visibilité et les réglages YouTube, ou supprimez la vidéo, dans YouTube Studio, indépendamment de NIARIM.';

  @override
  String get communityMyWorksYoutubeOpenFailed =>
      'Impossible d’ouvrir YouTube Studio';

  @override
  String get communityMyWorksDeletedTitle =>
      'Création retirée de la Place des œuvres';

  @override
  String get communityMyWorksDeletedYoutubeBody =>
      'La vidéo est toujours sur YouTube. Pour la supprimer aussi, supprimez-la dans YouTube Studio.';

  @override
  String get communityMyWorksDeletedOpenStudio => 'Ouvrir YouTube Studio';

  @override
  String communityMyWorksOperationFailed(String reason) {
    return 'Échec de l’opération : $reason';
  }

  @override
  String get communityMyWorksBulkPublish => 'Publier la sélection';

  @override
  String get communityMyWorksBulkHide => 'Masquer la sélection';

  @override
  String communityMyWorksBulkResult(int success, int failed) {
    return 'Modifiées : $success / Échecs : $failed';
  }

  @override
  String get communityMyWorksAccountNotConnected =>
      'Aucun compte Google connecté';

  @override
  String get communityMyWorksAddAccount => 'Associer un compte Google';

  @override
  String get communityMyWorksSwitchAccount =>
      'Changer ou ajouter un compte Google';

  @override
  String get communityMyWorksLoading => 'Chargement de vos publications…';

  @override
  String communityMyWorksLoadFailed(String reason) {
    return 'Impossible de charger vos publications. $reason';
  }

  @override
  String communityAccountSwitchFailed(String reason) {
    return 'Impossible de changer de compte Google. $reason';
  }

  @override
  String communitySignInFailed(String reason) {
    return 'Impossible de se connecter avec votre compte Google. $reason';
  }

  @override
  String get communityMyWorksDeletedCannotPublish =>
      'Une vidéo supprimée de YouTube ne peut plus être rendue visible sur la Place des œuvres';

  @override
  String get communityMyWorksStatusDeletedOnYoutube =>
      'Supprimé de YouTube • Ne peut plus être rendu visible';

  @override
  String get communityMyWorksStatusYoutubePrivate =>
      'Visible sur la Place des œuvres • Masqué temporairement, car la vidéo YouTube est privée';

  @override
  String get communityMyWorksStatusHiddenYoutubePrivate =>
      'Masqué sur la Place des œuvres • Également privé sur YouTube';

  @override
  String get communityVisibilityPublishedBadge => 'Visible';

  @override
  String communityYoutubeVideoIdLabel(String videoId) {
    return 'ID de la vidéo YouTube : $videoId';
  }

  @override
  String get communityPostTitleLabel => 'Titre';

  @override
  String get communityPostPickVideo => 'Choisir une vidéo';

  @override
  String get communityPostAsShort =>
      'Publier en tant que vidéo courte verticale';

  @override
  String get communityPostShowInPlaza => 'Afficher sur la Place des œuvres';

  @override
  String get communityPostShowInPlazaHelp =>
      'La vidéo est mise en ligne sur YouTube en « Non répertoriée ». Sa visibilité sur la Place des œuvres est gérée séparément.';

  @override
  String get communityPostUploadedHeading => 'Vidéo mise en ligne sur YouTube';

  @override
  String communityPostUploadedAccount(String email) {
    return 'Compte Google : $email';
  }

  @override
  String get communityPostNoReupload =>
      'Réessayer ne remettra pas la vidéo en ligne.';

  @override
  String get communityPostDiscardPending =>
      'Annuler l’enregistrement sur la Place des œuvres';

  @override
  String get communityPostDiscardPendingConfirm =>
      'La demande en attente et le formulaire seront effacés. Vous ne pourrez plus reprendre ici l’inscription de cette vidéo. La vidéo mise en ligne restera sur YouTube.';

  @override
  String get communityPostPendingDiscarded =>
      'L’enregistrement en attente sur la Place des œuvres a été abandonné. La vidéo sur YouTube n’a pas été supprimée.';

  @override
  String get communityPostYoutubeSyntheticQuestion =>
      'Cette vidéo contient-elle du contenu modifié ou synthétique réaliste à déclarer sur YouTube ?';

  @override
  String get communityPostYoutubeSyntheticHelp =>
      'Par exemple, montrer une personne réelle en train de faire quelque chose qu’elle n’a jamais fait ou représenter de façon réaliste un événement qui n’a jamais eu lieu.';

  @override
  String get communityPostYoutubeKidsQuestion =>
      'Audience sur YouTube : cette vidéo est-elle conçue pour les enfants ?';

  @override
  String get communityPostYoutubeKidsHelp =>
      'Sélectionnez Oui si les enfants font partie du public visé.';

  @override
  String get communityPostYoutubeDeclarationsRequired =>
      'Répondez aux deux questions de YouTube sur le contenu modifié ou synthétique et sur le public visé.';

  @override
  String get communityPostYoutubeDeclarationsStudio =>
      'Vous pouvez vérifier ou modifier la déclaration et le public de la vidéo mise en ligne dans YouTube Studio.';

  @override
  String get communityPostSubmitUpload =>
      'Mettre en ligne sur YouTube et publier';

  @override
  String get communityPostSubmitRetry =>
      'Réessayer l’enregistrement sur la Place des œuvres';

  @override
  String communityPostErrorLabel(String message) {
    return 'Erreur : $message';
  }

  @override
  String communityPostDoneSnackbar(String videoId) {
    return 'Publié (ID de la vidéo YouTube : $videoId)';
  }

  @override
  String communityPostRecoveredSnackbar(String videoId) {
    return 'Votre œuvre publiée a été récupérée (ID de la vidéo YouTube : $videoId)';
  }

  @override
  String get communityPostStatusPendingRestored =>
      'Une vidéo de votre dernière tentative est déjà sur YouTube. Vous pouvez réessayer uniquement l’enregistrement sur la Place des œuvres.';

  @override
  String get communityPostStatusPendingUnavailable =>
      'La vidéo YouTube en attente a été supprimée ou est introuvable : elle ne peut pas être récupérée. Choisissez une nouvelle vidéo.';

  @override
  String get communityPostStatusRecovered =>
      'Votre œuvre publiée a été récupérée';

  @override
  String get communityPostStatusCompleted => 'Publication terminée';

  @override
  String get communityPostStatusCheckingAccount =>
      'Vérification de votre compte Google…';

  @override
  String get communityPostStatusCheckingRegistration =>
      'Vérification de l’enregistrement sur la Place des œuvres…';

  @override
  String get communityPostStatusSyncingAiFlag =>
      'Synchronisation de « Contient des images ou vidéos générées par IA » pour l’œuvre publiée…';

  @override
  String get communityPostStatusSyncingVisibility =>
      'Synchronisation de la visibilité de l’œuvre publiée…';

  @override
  String get communityPostStatusUploading => 'Mise en ligne sur YouTube…';

  @override
  String get communityPostCancelUpload => 'Annuler l’envoi';

  @override
  String get communityPostKeepUploading => 'Poursuivre l’envoi';

  @override
  String get communityPostCancelUploadConfirm =>
      'Annuler l’envoi ? Les informations saisies resteront à l’écran.';

  @override
  String get communityPostStatusUploadCancelled =>
      'L’envoi a été annulé. S’il était presque terminé, vérifiez dans YouTube Studio si la vidéo y figure avant de réessayer.';

  @override
  String get communityPostStatusRegistering =>
      'Mise en ligne sur YouTube terminée. Enregistrement sur la Place des œuvres…';

  @override
  String get communityPostStatusUploadFailed => 'Échec de la mise en ligne';

  @override
  String get communityPostStatusRegistrationRetryable =>
      'La vidéo est enregistrée sur YouTube. Vous pouvez réessayer uniquement l’enregistrement sur la Place des œuvres.';

  @override
  String get communityPostStatusRegistrationClosed =>
      'Cette vidéo ne peut pas être enregistrée sur la Place des œuvres. Elle reste sur YouTube telle qu’elle a été mise en ligne. Annulez l’enregistrement pour choisir une nouvelle vidéo.';

  @override
  String get communityPostErrorNoVideo => 'Choisissez une vidéo à publier';

  @override
  String get communityPostErrorNoTitle => 'Saisissez un titre';

  @override
  String get communityPostErrorServerNotConfigured =>
      'Impossible de publier : le serveur de la Place des œuvres n’est pas configuré';

  @override
  String get communityPostErrorPendingVideoUnavailable =>
      'La vidéo YouTube est introuvable. L’enregistrement de cette vidéo sur la Place des œuvres ne peut pas être réessayé.';

  @override
  String communityPostErrorUploadedByAccount(String email) {
    return 'Cette vidéo a été mise en ligne avec $email. Passez à ce compte Google, puis réessayez l’enregistrement sur la Place des œuvres.';
  }

  @override
  String get communityPostErrorUploadedByAnotherAccount =>
      'Cette vidéo a été mise en ligne avec un autre compte Google. Passez à ce compte, puis réessayez l’enregistrement sur la Place des œuvres.';

  @override
  String communityPostErrorAccountChanged(String email) {
    return 'Votre compte Google a changé en cours de route. Revenez à $email, puis réessayez.';
  }

  @override
  String get communityPostErrorYoutubePermission =>
      'Impossible d’obtenir l’autorisation de publier sur YouTube';

  @override
  String get communityPostErrorNoVideoId =>
      'YouTube n’a pas renvoyé d’ID de vidéo';

  @override
  String get communityShortsEndBehaviorTooltip => 'Action à la fin de la vidéo';

  @override
  String get communityShortsEndBehaviorLoop => 'Répéter la même vidéo';

  @override
  String get communityShortsEndBehaviorAutoAdvance =>
      'Passer automatiquement à la vidéo suivante';

  @override
  String get communityErrorNetwork =>
      'Connexion impossible. Vérifiez votre connexion et réessayez.';

  @override
  String get communityErrorSignInRequired =>
      'Vous devez vous connecter avec votre compte Google. Reconnectez-vous, puis réessayez.';

  @override
  String get communityErrorForbidden =>
      'Vous n’avez pas l’autorisation d’effectuer cette action.';

  @override
  String get communityErrorNotFound =>
      'Élément introuvable. Il a peut-être été supprimé.';

  @override
  String get communityErrorRateLimited =>
      'Trop de requêtes. Patientez un instant, puis réessayez.';

  @override
  String get communityErrorServer =>
      'Un problème est survenu sur le serveur. Patientez un peu, puis réessayez.';

  @override
  String get communityErrorGeneric =>
      'Un problème est survenu. Veuillez réessayer.';

  @override
  String get fileFailureReasonAccess =>
      'Impossible de lire ou d’écrire le fichier';

  @override
  String get fileFailureReasonFormat =>
      'Le fichier a un autre format ou est endommagé';

  @override
  String get fileFailureReasonOther => 'Un problème inattendu est survenu';

  @override
  String communityErrorTagLimitExceeded(int max) {
    return 'Une œuvre peut avoir au maximum $max tags.';
  }

  @override
  String get communityErrorTagTooLong =>
      'Le tag est trop long. Raccourcissez-le, puis réessayez.';

  @override
  String get communityErrorTagUpdateConflict =>
      'Quelqu’un d’autre a modifié les tags en même temps. Veuillez réessayer.';

  @override
  String get communityErrorWorkChanged =>
      'L’œuvre a été modifiée entre-temps. Veuillez réessayer.';

  @override
  String get communityErrorVideoNotFound => 'La vidéo YouTube est introuvable.';

  @override
  String get communityErrorVideoAlreadyRegistered =>
      'Cette vidéo a déjà été enregistrée sur la Place des œuvres par un autre utilisateur.';

  @override
  String get communityErrorWorkDeleted =>
      'Cette vidéo a été supprimée de la Place des œuvres et ne peut pas être réenregistrée.';

  @override
  String get communityErrorVideoRegistrationConflict =>
      'Une autre demande enregistrait cette vidéo au même moment. Actualisez vos publications, puis réessayez.';

  @override
  String get communityErrorPostQuotaExceeded =>
      'Vous avez atteint la limite de publications du jour. Vous pourrez publier à nouveau après le changement de date.';

  @override
  String get communityErrorPostingSuspended =>
      'La publication sur la Place des œuvres est suspendue, car des contenus contraires aux conditions d’utilisation ont été publiés à plusieurs reprises. Pour contester cette décision, contactez-nous via le formulaire de contact ou par e-mail (support@miranima-studio.com).';

  @override
  String get communityErrorSignInCanceled => 'La connexion a été annulée.';

  @override
  String get communityErrorGoogleSignIn =>
      'La connexion avec Google n’a pas pu aboutir. Veuillez réessayer.';

  @override
  String get communityErrorYoutubeUpload =>
      'La mise en ligne sur YouTube a échoué. Vérifiez votre connexion et réessayez.';

  @override
  String get communityErrorVideoFile =>
      'Impossible de lire le fichier vidéo. Choisissez à nouveau la vidéo.';

  @override
  String get communityErrorUnsupported =>
      'Cette action n’est pas prise en charge sur cet appareil.';

  @override
  String get canvasLassoSnapToLines => 'Magnétiser aux lignes';

  @override
  String get canvasLassoGapTolerance => 'Tolérance des espaces';

  @override
  String get filterBackToList => 'Retour aux filtres';

  @override
  String get filterPanelCollapse => 'Réduire le panneau';

  @override
  String get filterPanelExpand => 'Agrandir le panneau';

  @override
  String get customAutomationShowAll => 'Tout afficher';

  @override
  String get customAutomationFavoritesOnly => 'Favoris uniquement';

  @override
  String get customAutomationBuiltinDraftToLineart => 'Trait (numérique)';

  @override
  String get customAutomationBuiltinAnalogLineart =>
      'Extraction du trait (analogique)';

  @override
  String get customAutomationBuiltinLineartColorTrace =>
      'Trace de couleur du trait';

  @override
  String customAutomationStepFrame(int frame) {
    return 'Aller à l’image $frame';
  }

  @override
  String get customAutomationStepAddFrame => 'Ajouter une image';

  @override
  String customAutomationStepBrushSize(String size) {
    return 'Taille du pinceau ${size}px';
  }

  @override
  String customAutomationStepBrushOpacity(int opacity) {
    return 'Opacité du pinceau $opacity%';
  }

  @override
  String customAutomationStepTool(String tool) {
    return 'Outil : $tool';
  }

  @override
  String customAutomationStepColor(String color) {
    return 'Couleur de dessin $color';
  }

  @override
  String customAutomationStepFilter(String name) {
    return 'Appliquer le filtre : $name';
  }

  @override
  String get customAutomationStepColorsBelowClipped =>
      'Écrêter au trait les couleurs du dessous';

  @override
  String get customAutomationStepDuplicateLayer => 'Dupliquer le calque';

  @override
  String get customAutomationStepMergeDown =>
      'Fusionner avec le calque inférieur';

  @override
  String get customAutomationStepColorTraceAdjust =>
      'Réglage de la trace de couleur';

  @override
  String get customAutomationStepVisibleComposite =>
      'Nouveau calque en haut à partir des calques visibles';

  @override
  String get brushFoldAngle => 'Angle du pli';

  @override
  String get brushFoldModeHelp =>
      'Choisissez comment le trait se plie le long de son tracé.';

  @override
  String get brushFoldLengthHelp =>
      'Règle la longueur du pli. Elle suit la taille du pinceau.';

  @override
  String get brushFoldAngleHelp =>
      'Règle avec quelle force le pli suit la courbe du trait. À 50 %, il la suit naturellement.';

  @override
  String get brushFoldDepartureAngle => 'Angle de départ de la ligne de pli';

  @override
  String get brushFoldDepartureAngleHelp =>
      'À 0°, la ligne suit la direction du contour. Les valeurs positives l’inclinent vers l’intérieur et les négatives vers l’extérieur.';

  @override
  String get brushFoldCurveStartHelp =>
      'Règle le début de la courbe de la ligne de pli. À 0 %, elle se courbe dès le départ. À 100 %, elle reste droite.';

  @override
  String get filterAutoLineartAddPointTooltip => 'Ajouter un point de contrôle';

  @override
  String get filterAutoLineartDeletePointTooltip =>
      'Supprimer un point de contrôle';

  @override
  String get filterAutoLineartDeletePointConfirm =>
      'Supprimer ce point de contrôle ?';

  @override
  String get filterPrismDescription =>
      'Colore la zone opaque du calque de référence en six bandes → flou gaussien → densité linéaire -';

  @override
  String get filterPrismBlurAmount => 'Intensité du flou';

  @override
  String get filterPrismColorDirection => 'Direction des couleurs';

  @override
  String get filterFisheyeRadius => 'Rayon';

  @override
  String get filterNameSphereShading => 'Ombrage sphérique';

  @override
  String get filterSphereModeSeparate => 'Ombre et lumière séparées';

  @override
  String get filterSphereModeCombined => 'Les deux en une fusion';

  @override
  String get filterSphereCombinedHint =>
      'Applique un dégradé de la couleur d’ombre à la couleur de lumière avec un seul mode de fusion. En Lumière crue, les couleurs plus sombres que le gris moyen assombrissent et les plus claires éclaircissent.';

  @override
  String get filterSphereShadowColor => 'Couleur d’ombre';

  @override
  String get filterSphereLightColor => 'Couleur de lumière';

  @override
  String get filterSphereShadowBlend => 'Mode de fusion de l’ombre';

  @override
  String get filterSphereLightBlend => 'Mode de fusion de la lumière';

  @override
  String get filterSphereBlend => 'Mode de fusion';

  @override
  String get filterSphereLightX => 'Position X de la lumière';

  @override
  String get filterSphereLightY => 'Position Y de la lumière';

  @override
  String get filterSphereLightWidth => 'Taille X de la lumière';

  @override
  String get filterSphereLightHeight => 'Taille Y de la lumière';

  @override
  String get filterSphereLightBlur => 'Flou côté lumière';

  @override
  String get filterSphereShadowBlur => 'Flou côté ombre';

  @override
  String get filterSphereCanvasHint =>
      'Faites glisser le + sur le canevas pour déplacer la lumière et les poignées rondes pour la redimensionner. L’ombre et la lumière ne s’appliquent qu’au dessin.';

  @override
  String get filterNameWatercolorBorder => 'Bord aquarelle';

  @override
  String get filterWatercolorBorderRange => 'Portée';

  @override
  String get filterWatercolorBorderBlur => 'Largeur du flou';

  @override
  String get filterWatercolorBorderDarken => 'Intensité du bord';

  @override
  String get filterWatercolorBorderColorEdges => 'Aussi aux limites de couleur';

  @override
  String get filterWatercolorBorderHint =>
      'La couleur s’accumule uniquement sur les bords des zones peintes et les intensifie, comme une aquarelle sèche, tandis que l’intérieur reste tel qu’il a été peint (dessiné directement sur le calque de travail). Portée : jusqu’où le bord s’intensifie vers l’intérieur. Intensité du bord : la quantité de couleur accumulée sur le bord. Largeur du flou : la douceur de la transition.';

  @override
  String get filterFisheyeCanvasHint =>
      'Faites glisser le + sur le canevas pour déplacer le centre et la poignée ronde du cercle pour changer le rayon.';

  @override
  String get filterCenterX => 'Centre X';

  @override
  String get filterCenterY => 'Centre Y';

  @override
  String get filterAxisX => 'Axe X';

  @override
  String get filterAxisY => 'Axe Y';

  @override
  String get filterAxisZ => 'Axe Z';

  @override
  String get filterBgBlendAutoLight =>
      'Détecter automatiquement la direction de la lumière';

  @override
  String get filterBgBlendStrength => 'Intensité d’intégration';

  @override
  String get filterBgBlendLightStrength => 'Intensité de la lumière principale';

  @override
  String get filterBgBlendShadowStrength => 'Intensité de l’ombre';

  @override
  String get filterBgBlendAmbient => 'Lumière ambiante';

  @override
  String get filterBgBlendBounce => 'Lumière réfléchie par le bas';

  @override
  String get filterBgBlendColorSpill => 'Débordement de couleur local';

  @override
  String get filterBgBlendSoftness => 'Douceur de la lumière';

  @override
  String get filterBgBlendSecondary => 'Lumière secondaire';

  @override
  String get filterBgBlendMaterialProtection => 'Protéger la matière';

  @override
  String get filterBgBlendToneMatch => 'Accorder aux tons de l’arrière-plan';

  @override
  String get filterBgBlendSamplingBand =>
      'Bande d’échantillonnage environnante';

  @override
  String get canvasAutofillCheckView =>
      'Affichage de vérification du remplissage auto';

  @override
  String get canvasAutofillCheckNormal => 'Normal';

  @override
  String get canvasAutofillCheckParts => 'Vérifier les parties';

  @override
  String get canvasAutofillCheckSilhouette => 'Vérifier la silhouette';

  @override
  String get canvasBackgroundColorChoices =>
      'Blanc / Transparent / Autre couleur';

  @override
  String get canvasBackgroundColorHiddenWhileTransparent =>
      'Tant que le canevas affiche la transparence, la couleur de fond n’y apparaît pas (les exports l’utilisent)';

  @override
  String get canvasBackgroundTransparent => 'Transparent';

  @override
  String get backgroundColorOther => 'Autre couleur';

  @override
  String get canvasTimelineModeTooltip => 'Mode timeline';

  @override
  String get startupFailedTitle => 'Impossible de démarrer NIARIM';

  @override
  String get startupFailedBody =>
      'Vos œuvres et réglages enregistrés sont intacts. Veuillez réessayer. Si le problème persiste, copiez les détails et envoyez-les-nous.';

  @override
  String get startupFailedRetry => 'Réessayer';

  @override
  String get startupFailedRetrying => 'Démarrage…';

  @override
  String get startupFailedCopyDetails => 'Copier les détails';

  @override
  String get startupFailedDetailsCopied => 'Détails copiés';

  @override
  String get startupFailedDetails => 'Détails';

  @override
  String get errorViewTitle =>
      'Une erreur s’est produite lors de l’affichage de cette partie';

  @override
  String get errorViewBody =>
      'Votre travail en cours est conservé. Revenez à l’écran précédent et réessayez. Nous envoyer le texte ci-dessous nous aidera à en trouver la cause.';

  @override
  String get homeWorksLoadFailed =>
      'Impossible de charger vos créations exportées';

  @override
  String get newProjectCreating => 'Création en cours…';

  @override
  String get newProjectCreateFailed =>
      'Impossible d’enregistrer le projet. Vérifiez l’espace de stockage et l’emplacement d’enregistrement, puis réessayez.';

  @override
  String get communityCreatorLabel => 'Créateur';

  @override
  String get communityThresholdAny => 'Aucune condition';

  @override
  String communityMinimumViewsOption(String count) {
    return 'Au moins $count vues';
  }

  @override
  String communityMinimumBookmarksOption(String count) {
    return 'Au moins $count favoris';
  }

  @override
  String get communityTileSize => 'Taille des œuvres';

  @override
  String get communityMutedWordsEmpty => 'Aucun mot-clé masqué';

  @override
  String get communityMutedTagsEmpty => 'Aucun tag masqué';

  @override
  String get communityMuteShort => 'Masquer';

  @override
  String get communityMuteConfirmTitle => 'Masquer ce créateur ?';

  @override
  String get communityMuteConfirmBody =>
      'Les œuvres de ce créateur ne seront plus affichées.';

  @override
  String get communityMuteConfirmAction => 'Masquer';

  @override
  String get communityUnmuteConfirmTitle => 'Réafficher ce créateur ?';

  @override
  String get communityUnmuteConfirmAction => 'Réafficher';

  @override
  String get communityMuteNo => 'Non';

  @override
  String get communityMuteDone => 'Créateur masqué';

  @override
  String get communityUnmuteDone => 'Créateur réaffiché';

  @override
  String communityFollowerMilestone(String count) {
    return 'Vous avez atteint $count abonnés';
  }

  @override
  String communityBookmarkMilestone(String title, String count) {
    return '« $title » a atteint $count favoris';
  }

  @override
  String get communitySearchHistory => 'Historique de recherche';

  @override
  String get communitySearchHistoryEmpty => 'Aucun historique';

  @override
  String get communityDeleteSavedSearchConfirm =>
      'Supprimer cette recherche enregistrée ?';

  @override
  String get communitySortLabel => 'Trier';

  @override
  String get homeTrashOperationFailed =>
      'L’opération n’a pas pu être terminée. Vérifiez votre stockage et réessayez.';

  @override
  String get homeTrashWorking => 'Traitement…';

  @override
  String get commonShowExplanation => 'Afficher l’explication';

  @override
  String get homeViewModeTooltip => 'Disposition et taille';

  @override
  String homeMovedToTrashSnackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments mis à la corbeille',
      one: '$count élément mis à la corbeille',
    );
    return '$_temp0';
  }

  @override
  String get homeUndoAction => 'Annuler';

  @override
  String homeTrashMoveUndone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments restaurés depuis la corbeille',
      one: '$count élément restauré depuis la corbeille',
    );
    return '$_temp0';
  }

  @override
  String homeCutSnackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count éléments coupés. Ouvrez la destination et touchez Coller dans la barre en bas de l’écran.',
      one:
          '$count élément coupé. Ouvrez la destination et touchez Coller dans la barre en bas de l’écran.',
    );
    return '$_temp0';
  }

  @override
  String homeCopiedSnackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count éléments copiés. Ouvrez l’emplacement voulu et touchez Coller dans la barre en bas de l’écran.',
      one:
          '$count élément copié. Ouvrez l’emplacement voulu et touchez Coller dans la barre en bas de l’écran.',
    );
    return '$_temp0';
  }

  @override
  String homePastedSnackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments collés.',
      one: '$count élément collé.',
    );
    return '$_temp0';
  }

  @override
  String homePasteUndoneToTrash(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Collage annulé. $count copies ont été mises à la corbeille.',
      one: 'Collage annulé. $count copie a été mise à la corbeille.',
    );
    return '$_temp0';
  }

  @override
  String homePasteUndoneMovedBack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Collage annulé. $count éléments ont été remis à leur place.',
      one: 'Collage annulé. $count élément a été remis à sa place.',
    );
    return '$_temp0';
  }

  @override
  String homePasteSkippedIntoSelf(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count dossiers ne peuvent pas être déplacés dans eux-mêmes ou leurs sous-dossiers ; ils restent coupés pour être collés ailleurs.',
      one:
          '$count dossier ne peut pas être déplacé dans lui-même ou ses sous-dossiers ; il reste coupé pour être collé ailleurs.',
    );
    return '$_temp0';
  }

  @override
  String homePasteSkippedMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count éléments n’ont pas pu être collés, car les originaux n’existent plus (mis à la corbeille ou supprimés).',
      one:
          '$count élément n’a pas pu être collé, car l’original n’existe plus (mis à la corbeille ou supprimé).',
    );
    return '$_temp0';
  }

  @override
  String homePasteSkippedFavorite(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count éléments sont des favoris (œuvres ou dossiers) ou des dossiers qui en contiennent, ils n’ont donc pas été mis à la corbeille. Retirez-les des favoris, puis collez à nouveau.',
      one:
          '$count élément est un favori (œuvre ou dossier) ou un dossier qui en contient, il n’a donc pas été mis à la corbeille. Retirez-le des favoris, puis collez à nouveau.',
    );
    return '$_temp0';
  }

  @override
  String get homePasteToTrashKeepsFavorites =>
      'Ces éléments sont des favoris (œuvres ou dossiers) ou des dossiers qui en contiennent, ils ne seront donc pas mis à la corbeille :';

  @override
  String get homeTrashFolderHoldsFavorite =>
      'Un dossier qui contient un favori (œuvre ou dossier) ne peut pas être mis à la corbeille. Retirez d’abord des favoris les éléments qu’il contient.';

  @override
  String homePasteSkippedFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count éléments n’ont pas pu être collés. Vérifiez votre stockage et réessayez.',
      one:
          '$count élément n’a pas pu être collé. Vérifiez votre stockage et réessayez.',
    );
    return '$_temp0';
  }

  @override
  String homePasteSkippedPartial(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count éléments n’ont été collés qu’en partie. Vérifiez la liste et réessayez.',
      one:
          '$count élément n’a été collé qu’en partie. Vérifiez la liste et réessayez.',
    );
    return '$_temp0';
  }

  @override
  String get homeCutPendingHint => 'Coupé, en attente de collage';

  @override
  String projectDuplicateName(String name) {
    return '$name (copie)';
  }

  @override
  String projectDuplicateNameNumbered(String name, int number) {
    return '$name (copie $number)';
  }

  @override
  String projectDuplicatedSnackbar(String name) {
    return 'Copie créée : $name';
  }

  @override
  String get homeSelectionOneAtATime =>
      'Dans cet onglet, les éléments se coupent ou se copient un par un. Sélectionnez-en un seul.';

  @override
  String homeTrashCutUnavailable(String restore) {
    return 'Les éléments de la corbeille ne peuvent pas être coupés. Pour remettre un élément à sa place, appuyez sur « $restore ».';
  }

  @override
  String get homeTrashCopyOneAtATime =>
      'Dans la corbeille, les éléments se copient un par un. Sélectionnez-en un seul.';

  @override
  String get homeShareFileNameTaken =>
      'Un fichier partagé porte déjà ce nom. Choisissez un autre nom.';

  @override
  String get homeShareFileRenameFailed =>
      'Impossible de renommer le fichier. Réessayez.';

  @override
  String get homeWorkFileNameTaken =>
      'Un fichier d’œuvre porte déjà ce nom. Choisissez un autre nom.';

  @override
  String get homeDrawerTutorial => 'Mode d’emploi';

  @override
  String get themeColorAccentText => 'Couleur du texte et des icônes d’accent';

  @override
  String get projectDetailNotFoundBackToList => 'Aller aux projets';

  @override
  String projectListNoMatchTitle(String query) {
    return 'Aucun résultat pour « $query »';
  }

  @override
  String get projectListNoMatchNameHint =>
      'Recherche dans les noms de tous les dossiers, sans distinguer majuscules et minuscules ni caractères pleine et demi-chasse.';

  @override
  String get projectListNoMatchTagHint =>
      'Recherche dans les étiquettes des œuvres de tous les dossiers.';

  @override
  String get projectListClearSearch => 'Effacer la recherche';

  @override
  String get projectListNoFavoritesTitle => 'Aucun favori ici';

  @override
  String get projectListNoFavoritesHint =>
      'Choisissez « Ajouter aux favoris » dans le menu d’une œuvre ou d’un dossier pour l’afficher ici.';

  @override
  String get projectListShowAll => 'Tout afficher';

  @override
  String get projectListEmptyFolderTitle => 'Ce dossier est vide';

  @override
  String projectListNoFavoriteMatchTitle(String query) {
    return 'Aucun favori ne correspond à « $query »';
  }

  @override
  String get projectListNoFavoritesInFolderTitle =>
      'Aucun favori dans ce dossier';

  @override
  String get projectListNoFavoritesOutsideFoldersTitle =>
      'Aucun favori hors des dossiers';

  @override
  String projectListUpdatedOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMd(
      localeName,
    ).add_jm();
    final String dateString = dateDateFormat.format(date);

    return 'Modifié le $dateString';
  }

  @override
  String projectListFolderCreatedOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMd(
      localeName,
    ).add_jm();
    final String dateString = dateDateFormat.format(date);

    return 'Créé le $dateString';
  }

  @override
  String projectListInFolder(String path) {
    return 'Dans $path';
  }

  @override
  String get homeProjectsLoadFailed => 'Impossible de charger vos projets';

  @override
  String get homeOutgoingSharesLoadFailed =>
      'Impossible de charger les fichiers partagés que vous avez créés';

  @override
  String get settingsErrorLogTitle => 'Journal des erreurs';

  @override
  String get settingsErrorLogSubtitle =>
      'Consultez et copiez les erreurs de l’application pour les joindre à un signalement';

  @override
  String get errorLogHint =>
      'Affiche jusqu’à 20 erreurs depuis l’ouverture de l’application, des plus récentes aux plus anciennes. Les adresses e-mail et les informations de connexion sont masquées.';

  @override
  String savedListUnreadableNotice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count éléments enregistrés n’ont pas pu être lus. Leurs données d’origine sont conservées et l’application essaiera de nouveau de les lire au prochain démarrage.',
      one:
          '$count élément enregistré n’a pas pu être lu. Ses données d’origine sont conservées et l’application essaiera de nouveau de le lire au prochain démarrage.',
    );
    return '$_temp0';
  }

  @override
  String get errorLogEmpty => 'Aucune erreur enregistrée';

  @override
  String get errorLogCopyAll => 'Tout copier';

  @override
  String get errorLogCopied => 'Journal des erreurs copié';

  @override
  String get errorLogClear => 'Effacer le journal';

  @override
  String get errorLogCleared => 'Journal des erreurs effacé';

  @override
  String get tutorialSkip => 'Passer';

  @override
  String get tutorialNext => 'Suivant';

  @override
  String tutorialPageIndicator(int current, int total) {
    return 'Page $current sur $total';
  }

  @override
  String get tutorialPage1Title => 'Bienvenue dans NIARIM';

  @override
  String get tutorialPage1Step1 => 'Dessinez sur une « image ».';

  @override
  String get tutorialPage1Step2 =>
      'Ajoutez d’autres images en déplaçant un peu le dessin à chaque fois.';

  @override
  String get tutorialPage1Step3 =>
      'Lues à la suite, elles forment une animation que vous pouvez exporter en vidéo.';

  @override
  String get tutorialPage2Title => 'Créez un projet';

  @override
  String get tutorialPage2Step1 =>
      'Sur l’écran d’accueil, touchez + en bas à droite.';

  @override
  String get tutorialPage2Step2 =>
      'Choisissez « Nouveau projet », réglez le nom et la taille, puis touchez « Créer ».';

  @override
  String get tutorialPage2Step3 =>
      'Vos projets s’affichent dans « Projets ». Touchez-en un, puis « Commencer l’édition » pour continuer à dessiner.';

  @override
  String get tutorialPage3Title => 'Dessinez sur le canevas';

  @override
  String get tutorialPage3Step1 =>
      'Choisissez un outil (plume, gomme, remplissage…) dans la barre d’outils du bas.';

  @override
  String get tutorialPage3Step2 =>
      'Touchez le cercle de couleur pour changer la couleur du dessin.';

  @override
  String get tutorialPage3Step3 =>
      'Les flèches en haut à gauche permettent d’annuler et de rétablir.';

  @override
  String get tutorialPage4Title => 'Ajoutez des images pour animer';

  @override
  String get tutorialPage4Step1 =>
      'La liste des images en bas indique l’image sur laquelle vous dessinez.';

  @override
  String get tutorialPage4Step2 =>
      'Touchez + pour ajouter l’image suivante et dessinez-la un peu déplacée.';

  @override
  String get tutorialPage4Step3 =>
      'Activez « Papier calque » dans les réglages en haut à droite pour voir l’image précédente en transparence.';

  @override
  String get tutorialPage5Title => 'Lisez et exportez';

  @override
  String get tutorialPage5Step1 =>
      'Ouvrez la timeline avec son bouton en haut à droite.';

  @override
  String get tutorialPage5Step2 =>
      'Touchez Lecture pour vérifier le mouvement.';

  @override
  String get tutorialPage5Step3 =>
      'Avec « Exporter », enregistrez-la ou partagez-la en vidéo ou en GIF.';

  @override
  String get tutorialPage6Title => 'En cas de besoin';

  @override
  String get tutorialPage6Step1 =>
      'Retrouvez les explications des fonctionnalités dans « Aide », sous « Mode d’emploi », depuis le menu en haut à droite de l’accueil.';

  @override
  String get tutorialPage6Step2 =>
      'Une courte explication s’affiche la première fois que vous utilisez une fonction.';

  @override
  String get tutorialPage6Step3 =>
      'Revoyez ce guide depuis le menu en haut à droite de l’accueil : « Mode d’emploi », puis « Voir le guide ».';

  @override
  String get helpTutorialSubtitle =>
      'Ouvrir le guide illustré de prise en main';

  @override
  String get settingsTipsResetTitle => 'Réafficher les explications';

  @override
  String get settingsTipsResetSubtitle =>
      'Réaffiche la courte explication de chaque fonction lors de sa prochaine utilisation';

  @override
  String get settingsTipsResetDone =>
      'Les explications réapparaîtront lors de la prochaine utilisation de chaque fonction';

  @override
  String get helpTutorialButton => 'Voir le guide';

  @override
  String get projectListTrashFolderConfirmTitle =>
      'Mettre le dossier à la corbeille ?';

  @override
  String homeFolderMovedToTrashSnackbar(String name) {
    return '« $name » mis à la corbeille';
  }

  @override
  String homeRestoredFromTrashSnackbar(String name) {
    return '« $name » restauré depuis la corbeille';
  }

  @override
  String homeMoveToTrashFolderContents(String contents) {
    return 'Le contenu des dossiers sera aussi déplacé : $contents.';
  }

  @override
  String get homeMoveToTrashUnreadNote =>
      'Les projets impossibles à charger qui se trouvent à l’intérieur rejoindront le dossier dans la corbeille une fois chargés.';

  @override
  String homeTrashFolderPermanentDeleteBody(String name) {
    return '« $name » sera supprimé définitivement. Cette action est irréversible.';
  }

  @override
  String homeFolderContents(int projects, int folders) {
    String _temp0 = intl.Intl.pluralLogic(
      folders,
      locale: localeName,
      other: ' et $folders dossiers',
      one: ' et 1 dossier',
      zero: '',
    );
    String _temp1 = intl.Intl.pluralLogic(
      folders,
      locale: localeName,
      other: ' et $folders dossiers',
      one: ' et 1 dossier',
      zero: '',
    );
    String _temp2 = intl.Intl.pluralLogic(
      folders,
      locale: localeName,
      other: '$folders dossiers',
      one: '1 dossier',
      zero: 'Vide',
    );
    String _temp3 = intl.Intl.pluralLogic(
      projects,
      locale: localeName,
      other: '$projects projets$_temp0',
      one: '1 projet$_temp1',
      zero: '$_temp2',
    );
    return '$_temp3';
  }

  @override
  String homeTrashFolderPermanentDeleteContents(String contents) {
    return 'Son contenu sera aussi supprimé : $contents.';
  }

  @override
  String newProjectNumberRangeError(int min, int max) {
    return 'Saisissez un nombre entre $min et $max';
  }

  @override
  String get pcViewFit => 'Ajuster à la fenêtre';

  @override
  String pcStatusFrame(int current, int total) {
    return 'Image $current/$total';
  }

  @override
  String pcStatusFps(int fps) {
    return '$fps i/s';
  }

  @override
  String get communityChannelRefreshButton =>
      'Actualiser le nom et l’icône YouTube (1 fois/jour)';

  @override
  String get communityChannelRefreshSuccess =>
      'Nom et icône YouTube mis à jour';

  @override
  String get communityChannelRefreshNoToken =>
      'Autorisation YouTube nécessaire';

  @override
  String get communityChannelRefreshUnavailable =>
      'Connectez-vous et connectez le serveur';

  @override
  String communityChannelRefreshFailed(String error) {
    return 'Impossible de mettre à jour les informations YouTube : $error';
  }

  @override
  String get communityPlazaMuteWork => 'Masquer cette œuvre';

  @override
  String get communityPlazaUnmuteWork => 'Réafficher cette œuvre';

  @override
  String get communityPlazaMutedPlaceholder => 'Cette œuvre est masquée';

  @override
  String get communityPlazaUnmuteQuestion =>
      'Toujours réafficher cette œuvre ?';

  @override
  String get communityPlazaUnmuteAlways => 'Toujours';

  @override
  String get communityPlazaUnmuteTemporary => 'Temporairement';

  @override
  String get communityPlazaMuteSettings => 'Paramètres de masquage';

  @override
  String get communityPlazaPartialHint => 'Si désactivé : recherche partielle';

  @override
  String get communityPlazaDeleteHistory =>
      'Supprimer cette recherche de l’historique ?';

  @override
  String get communityPlazaLocalData => 'Données locales de l’appareil';

  @override
  String get communityPlazaExactTitle => 'Rechercher une correspondance exacte';

  @override
  String get communityPlazaUnavailablePlaceholder =>
      'Cette œuvre a été supprimée ou rendue privée';

  @override
  String get communityPlazaSearchTab => 'Recherche';

  @override
  String get communityPlazaMutePrivacyNotice =>
      'Cette personne ne sera pas informée si vous la masquez.';

  @override
  String get communityPostVisibilityHeading => 'Visibilité sur YouTube';

  @override
  String get communityPostVisibilityUnlistedTitle =>
      'Publier pour NIARIM (non répertorié sur YouTube)';

  @override
  String get communityPostVisibilityUnlistedHelp =>
      'Visible dans NIARIM et éligible au classement des favoris.';

  @override
  String get communityPostVisibilityPublicTitle =>
      'Publier aussi sur YouTube (public)';

  @override
  String get communityPostVisibilityPublicHelp =>
      'Peut apparaître dans les recherches et recommandations YouTube et participer au classement des favoris NIARIM.';

  @override
  String get communityPostVisibilityUnlistedDisclosure =>
      'Attention : non répertorié ne signifie pas privé. Toute personne ayant le lien peut regarder et partager la vidéo hors de NIARIM.';

  @override
  String get communityRankingLayoutTitle => 'Affichage du classement';

  @override
  String get communityRankingLayoutHorizontal => 'Lignes compactes';

  @override
  String get communityRankingLayoutLargeThumbnail => 'Grandes miniatures';

  @override
  String communityRankingLayoutRankedPlace(int rank) {
    return 'Rang $rank';
  }

  @override
  String get communityRankingLayoutPeriodBookmarks => 'Favoris de la période';

  @override
  String get communityWorkMetadataTitle => 'Titre de l’œuvre';

  @override
  String get communityWorkMetadataDescription => 'Description';

  @override
  String get communityWorkMetadataDescriptionHint =>
      'À propos de l’œuvre (facultatif)';

  @override
  String get communityWorkMetadataEdit => 'Modifier le titre et la description';

  @override
  String get communityWorkMetadataSaved => 'Titre et description enregistrés';

  @override
  String get communityWorkMetadataInfo =>
      'Ces changements concernent NIARIM, pas YouTube.';

  @override
  String get communityWorkMetadataLoadFailed =>
      'Impossible de charger la description';

  @override
  String get communityWorkMetadataYoutubeDescription =>
      'Description YouTube (facultative)';

  @override
  String get communityWorkMetadataYoutubeDescriptionHint =>
      'Distincte de la description de votre œuvre dans NIARIM';

  @override
  String get communityWorkMetadataYoutubeDescriptionInvalid =>
      'La description YouTube doit faire au maximum 5 000 octets et ne pas contenir < ni >';

  @override
  String get communityWorkMetadataYoutubeTitle => 'Titre YouTube';

  @override
  String get communityWorkMetadataCopyTitleToYoutube =>
      'Copier vers le titre YouTube';

  @override
  String get communityWorkMetadataCopyTitleToNiarim =>
      'Copier vers le titre NIARIM';

  @override
  String get communityWorkMetadataCopyDescriptionToYoutube =>
      'Copier vers la description YouTube';

  @override
  String get communityWorkMetadataCopyDescriptionToNiarim =>
      'Copier vers la description NIARIM';

  @override
  String get communityWorkMetadataYoutubeTitleRequired =>
      'Saisissez un titre YouTube';

  @override
  String get communityWorkMetadataCopyConfirmTitle =>
      'Remplacer le contenu de destination ?';

  @override
  String get communityWorkMetadataCopyConfirmMessage =>
      'Le contenu actuel de la destination sera écrasé. Voulez-vous continuer ?';

  @override
  String get communityWorkMetadataCopyCancel => 'Annuler';

  @override
  String get communityWorkMetadataCopyConfirmAction => 'Copier et remplacer';

  @override
  String get communityYoutubeCommentHeading => 'Voir les commentaires YouTube';

  @override
  String get communityYoutubeCommentLoadMore => 'Afficher la suite';

  @override
  String get communityYoutubeCommentOpenYouTube => 'Voir la suite sur YouTube';

  @override
  String get communityYoutubeCommentNoComments => 'Aucun commentaire';

  @override
  String get communityYoutubeCommentUnavailable =>
      'Commentaires YouTube indisponibles';

  @override
  String get communityYoutubeCommentRetry => 'Réessayer';

  @override
  String communityYoutubeCommentReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count réponses',
      one: '$count réponse',
    );
    return '$_temp0';
  }

  @override
  String get communityYoutubeCommentAttribution =>
      'Les commentaires viennent de YouTube. Publication et réponse indisponibles.';

  @override
  String get creatorMissionTitle => 'Missions de création';

  @override
  String get creatorMissionGenericPublished => 'Publier une œuvre';

  @override
  String get creatorMissionDetailsTitle => 'Conditions';

  @override
  String get creatorMissionDetailsHint =>
      'Chaque mission peut être réclamée une fois par compte ou par œuvre.';

  @override
  String get creatorMissionNotAchieved => 'Non atteint';

  @override
  String get creatorMissionDetailsTooltip => 'Voir les détails';

  @override
  String get creatorMissionReviewing => 'En vérification';

  @override
  String get creatorMissionCoinReward => 'Récompenses';

  @override
  String get creatorMissionClaim => 'Réclamer';

  @override
  String get creatorMissionActivityTitle => 'Notifications';

  @override
  String get creatorMissionActivityObserved => 'Date de confirmation';

  @override
  String get creatorMissionActivityEmpty => 'Aucune réussite pour le moment';

  @override
  String get creatorMissionActivitySyncMore => 'Chercher d’autres réussites';

  @override
  String get creatorMissionActivityHistoryMore => 'Notifications précédentes';

  @override
  String get creatorMissionActivityError =>
      'Impossible de charger les notifications';

  @override
  String get creatorMissionActivitySignIn =>
      'Connectez-vous pour voir vos réussites';

  @override
  String get creatorMissionDetailsDraftCount =>
      'Le décompte des réussites sur plusieurs œuvres est provisoire. Le serveur le revérifie lorsque vous réclamez la récompense.';

  @override
  String get creatorMissionDetailsPerWorkRule =>
      'Une fois par œuvre. Chaque nouvelle œuvre peut être récompensée.';

  @override
  String get creatorMissionDetailsAccountRule => 'Une fois par compte.';

  @override
  String get creatorMissionDetailsTemplateRule =>
      'Lorsqu’une œuvre réussit, une ligne à son nom apparaît en haut. Ce modèle reste incomplet.';

  @override
  String get creatorMissionDetailsPending =>
      'Votre demande est en cours de vérification.';

  @override
  String get creatorMissionDetailsOffline =>
      'Le versement de cette récompense est suspendu pour le moment.';

  @override
  String get creatorMissionDrawerAttention =>
      'Missions accomplies non réclamées';

  @override
  String get creatorMissionAchieved => 'Objectif atteint';

  @override
  String get creatorMissionClaimReceived => 'Récompense reçue';

  @override
  String get creatorMissionHoldStarted =>
      'Votre demande est en cours de vérification.';

  @override
  String get creatorMissionClaimFailed =>
      'Vérification impossible. Actualisez puis réessayez.';

  @override
  String get creatorMissionWorkSection => 'Réussites par œuvre';

  @override
  String get creatorMissionWorkWarning =>
      'Seuls les objectifs atteints apparaissent. Une fois par œuvre et mission.';

  @override
  String get creatorMissionNoAchievements => 'Aucune réussite sur cette page.';

  @override
  String get creatorMissionLoadMore => 'Voir les 25 œuvres suivantes';

  @override
  String get creatorMissionWorkListError =>
      'Impossible de charger les réussites.';

  @override
  String get creatorMissionSubtitle =>
      'Gagnez des opales en créant et en atteignant des objectifs';

  @override
  String get creatorMissionPerWork => 'Une fois par œuvre';

  @override
  String get creatorMissionClaimed => 'Obtenu';

  @override
  String get creatorMissionPending => 'En vérification';

  @override
  String get creatorMissionNotClaimed => 'Non réclamé';

  @override
  String get creatorMissionUpcoming => 'En pause';

  @override
  String get creatorMissionTemplateClaim =>
      'À réclamer quand une œuvre est éligible';

  @override
  String get creatorMissionLogin =>
      'Connectez-vous avec Google pour voir vos missions.';

  @override
  String get creatorMissionOffline => 'Serveur de missions indisponible.';

  @override
  String get creatorMissionRetry => 'Actualiser';

  @override
  String get creatorMissionLoading => 'Chargement des missions…';

  @override
  String get creatorMissionLoadError => 'Impossible de charger les missions.';

  @override
  String get creatorMissionTimeWarning =>
      'Le temps de création est seulement indicatif et ne rapporte pas d’opales.';

  @override
  String get creatorMissionRankingWarning =>
      'Remarque : seul le classement des favoris NIARIM compte. Le nombre d’œuvres publiées, les favoris de votre œuvre, le rang et le pourcentage supérieur doivent TOUS être respectés. Ouvrez « Voir les détails » de chaque mission pour les règles exactes.';

  @override
  String get creatorMissionBudget =>
      'Chaque mission est récompensée une seule fois.';

  @override
  String get loginBonusTitle => 'Bonus de connexion cumulés';

  @override
  String get loginBonusDaily => 'Bonus du jour';

  @override
  String get loginBonusClaim => 'Réclamer';

  @override
  String get loginBonusClaimed => 'Réclamé';

  @override
  String get loginBonusNotYet => 'Non atteint';

  @override
  String get loginBonusMilestones => 'Bonus de palier';

  @override
  String get loginBonusUnknown => 'Indisponible';

  @override
  String get loginBonusUnavailable =>
      'Le versement des récompenses est suspendu pour le moment';

  @override
  String get loginBonusUtc =>
      'La journée change à minuit heure du Japon (JST). Les pauses ne réinitialisent rien.';

  @override
  String get loginBonusRetry => 'Actualiser';

  @override
  String get loginBonusFailed => 'Récompense non confirmée';

  @override
  String get loginBonusSuccess => 'Opales reçues';

  @override
  String get loginBonusVisitMissing => 'Vérification de connexion';

  @override
  String get rewardNavigationExchange => 'Échanger des avantages';

  @override
  String get rewardNavigationHub => 'Opales et bonus';

  @override
  String get rewardNavigationEarnTab => 'Voir des pubs pour des opales';

  @override
  String get rewardNavigationMissions => 'Missions';

  @override
  String get rewardNavigationEarn => 'Gagner des opales';

  @override
  String get rewardNavigationMembership => 'Statut d’adhésion';

  @override
  String get rewardNavigationMembershipDetail => 'Découvrir Premium';

  @override
  String get rewardNavigationMembershipFree => 'Membre gratuit';

  @override
  String get rewardNavigationMembershipMonthly => 'Premium mensuel';

  @override
  String get rewardNavigationMembershipYearly => 'Premium annuel';

  @override
  String get rewardNavigationMembershipPlay => 'Membre Premium';

  @override
  String get rewardNavigationMembershipCoin => 'Débloqué avec des opales';

  @override
  String get rewardNavigationMembershipBenefit => 'Avantages actifs';

  @override
  String get rewardNavigationMembershipNoBenefit => 'Aucun avantage actif';

  @override
  String get rewardNavigationMembershipUpsell =>
      'Comparez les offres Premium avant de vous abonner.';

  @override
  String rewardNavigationMembershipExpiresAt(DateTime expiry) {
    final intl.DateFormat expiryDateFormat = intl.DateFormat.yMMMd(
      localeName,
    ).add_jm();
    final String expiryString = expiryDateFormat.format(expiry);

    return 'Valable jusqu’au $expiryString';
  }

  @override
  String rewardNavigationMembershipCoinExpiresAt(DateTime expiry) {
    final intl.DateFormat expiryDateFormat = intl.DateFormat.yMMMd(
      localeName,
    ).add_jm();
    final String expiryString = expiryDateFormat.format(expiry);

    return 'Débloqué avec des opales · Valable jusqu’au $expiryString';
  }

  @override
  String get rewardNavigationMembershipUnavailable => 'Avantages indisponibles';

  @override
  String get rewardNavigationMembershipLogin =>
      'Connectez-vous pour voir les avantages';

  @override
  String get rewardNavigationPremiumCompare => 'Découvrir Premium';

  @override
  String get rewardNavigationPremiumJoin => 'Devenir membre Premium';

  @override
  String get rewardNavigationPremiumPlans => 'Choisir une offre';

  @override
  String get rewardNavigationEarnDescription =>
      'Regardez des publicités facultatives pour gagner des opales';

  @override
  String get rewardNavigationEarnUnavailable =>
      'Les publicités récompensées sont suspendues pour le moment';

  @override
  String get rewardUnlockTitle => 'Récompenses';

  @override
  String get rewardUnlockMissionTitle => 'Missions';

  @override
  String get rewardUnlockMissionSubtitle =>
      'Gagnez des opales en publiant et en atteignant vos objectifs';

  @override
  String get rewardUnlockLoading => 'Chargement du solde…';

  @override
  String get rewardUnlockPaused => 'Temps conservé (secondes)';

  @override
  String get rewardUnlockActiveUntil => 'Valable jusqu’au';

  @override
  String get rewardUnlockSubscriptionBenefit =>
      'Gagnez gratuitement des opales via des publicités facultatives, ou gagnez du temps avec Premium.';

  @override
  String get rewardUnlockActive => 'Avantages actifs';

  @override
  String get rewardUnlockActivePremium =>
      'Tous les avantages sont actifs via Premium';

  @override
  String get rewardUnlockDuration => 'Durée d’utilisation';

  @override
  String get rewardUnlockChooseDuration => 'Choisir la durée';

  @override
  String get rewardUnlockChooseBenefits => 'Choisir des avantages';

  @override
  String get rewardUnlockNotReady => 'Non disponible à l’échange';

  @override
  String get rewardUnlockTotal => 'Total des opales';

  @override
  String get rewardUnlockUnavailable =>
      'Choisissez des avantages pour voir le total d’opales nécessaires';

  @override
  String get rewardUnlockBalanceSignIn =>
      'Connectez-vous avec Google pour voir votre solde d’opales';

  @override
  String get rewardUnlockEarnSignIn =>
      'Connectez-vous avec Google pour gagner des opales';

  @override
  String get rewardUnlockBalanceLoadFailed =>
      'Impossible de charger votre solde d’opales';

  @override
  String get rewardUnlockRedeem => 'Échanger les opales';

  @override
  String get rewardUnlockWatchRewardedAd =>
      'Voir une publicité pour gagner des opales';

  @override
  String get rewardUnlockRewardPending =>
      'Vérification en attente. Les opales seront ajoutées après confirmation.';

  @override
  String get rewardUnlockRewardUnavailable =>
      'Impossible d’afficher la publicité. Réessayez plus tard.';

  @override
  String get rewardUnlockRewardClosedEarly =>
      'La publicité a été fermée avant la fin : aucune opale n’a été gagnée.';

  @override
  String get rewardUnlockRewardRefresh => 'Actualiser le solde';

  @override
  String get rewardUnlockCoinHistory => 'Historique des opales';

  @override
  String get rewardUnlockHistoryEmpty => 'Aucune transaction';

  @override
  String get rewardUnlockHistoryError => 'Impossible de charger l’historique';

  @override
  String get rewardUnlockHistoryMore => 'Afficher plus';

  @override
  String get rewardUnlockHistoryAd => 'Publicité récompensée';

  @override
  String get rewardUnlockHistoryMission => 'Mission';

  @override
  String get rewardUnlockHistoryRedemption => 'Échange d’opales';

  @override
  String get rewardUnlockHistoryOther => 'Autre transaction';

  @override
  String get rewardUnlockRewardQuotaReached =>
      'Limite quotidienne atteinte (UTC)';

  @override
  String get rewardUnlockRewardQuotaUncapped =>
      'Pas de plafond quotidien NIARIM';

  @override
  String get rewardUnlockRewardQuotaCaution =>
      'La disponibilité et les limites AdMob peuvent réduire les annonces.';

  @override
  String get rewardUnlockRedemptionSuccess =>
      'Échange réussi. La date d’expiration de vos avantages a été mise à jour sur le serveur.';

  @override
  String get rewardUnlockRedemptionUncertain =>
      'Échange non confirmé. Un nouvel essai vérifiera la même transaction.';

  @override
  String get rewardUnlockFreeOnly =>
      'Gagnez des opales avec des publicités facultatives';

  @override
  String get rewardUnlockSubscribe => 'Voir Premium mensuel / annuel';

  @override
  String get rewardUnlockBestValue => 'Meilleur rapport qualité-prix';

  @override
  String get rewardUnlockBestExplain =>
      'Retrouvez les mêmes fonctions que Premium réunies dans un pack, moins cher que l’échange de chaque avantage séparément';

  @override
  String get rewardUnlockEarning =>
      'Les abonnés Premium peuvent aussi cumuler des opales';

  @override
  String get rewardUnlockHour => 'Heures';

  @override
  String get rewardUnlockDay => 'Jours';

  @override
  String get rewardUnlockWeek => 'Semaines';

  @override
  String get rewardUnlockMonth => 'Mois';

  @override
  String get rewardUnlockEndCardEdit =>
      'Modifier / retirer la marque de fin et le logo des GIF (vidéos du making-of incluses)';

  @override
  String get rewardUnlockWatermark =>
      'Ajouter et modifier votre propre filigrane';

  @override
  String get rewardUnlockToneCurve => 'Courbe de tons';

  @override
  String get rewardUnlockLevelAdjustment => 'Niveaux';

  @override
  String get rewardUnlockUnlimitedDuration => 'Jusqu’à 2 heures';

  @override
  String get rewardUnlockCustomAutomation =>
      'Automatisations personnalisées (enregistrement d’actions)';

  @override
  String get rewardUnlockCommunityPostQuota =>
      'Publications sur la Place des œuvres : 3 par jour au lieu de 1';

  @override
  String get rewardUnlockProjectListAds =>
      'Sans publicité dans la liste des projets';

  @override
  String get rewardUnlockCanvasAds => 'Sans publicité sur le canevas';

  @override
  String get rewardUnlockTimelineAds => 'Sans publicité sur la timeline';

  @override
  String get rewardUnlockProcessingAds =>
      'Sans publicité pendant le traitement';

  @override
  String get rewardUnlockAllAds => 'Sans publicité';

  @override
  String get rewardUnlockFullPremium =>
      'Pack complet d’avantages (comme l’abonnement Premium)';

  @override
  String get rewardUnlockChoose => 'Sélectionner';

  @override
  String get sharedArchiveReceived => 'Reçus';

  @override
  String get sharedArchiveCreated => 'Créés';

  @override
  String get sharedArchiveShare => 'Partager';

  @override
  String get sharedArchiveEmpty =>
      'Vous n’avez encore créé aucun fichier partagé';

  @override
  String coinAmount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString opales',
      one: '$countString opale',
    );
    return '$_temp0';
  }

  @override
  String creatorMissionGenericRepost(int count) {
    return 'Une œuvre publiée atteint $count repartages';
  }

  @override
  String creatorMissionGenericBookmark(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count favoris',
      one: '$count favori',
    );
    return 'Une œuvre atteint $_temp0';
  }

  @override
  String creatorMissionNamedRepost(String title, int count) {
    return '$title atteint $count repartages';
  }

  @override
  String creatorMissionNamedBookmark(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count favoris',
      one: '$count favori',
    );
    return '$title atteint $_temp0';
  }

  @override
  String creatorMissionNamedPublished(String title) {
    return '$title est publiée';
  }

  @override
  String creatorMissionWorksGoal(int works, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count favoris',
      one: '$count favori',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count favoris',
      one: '$count favori',
    );
    String _temp2 = intl.Intl.pluralLogic(
      works,
      locale: localeName,
      other: '$works œuvres atteignent chacune $_temp0',
      one: '$works œuvre atteint $_temp1',
    );
    return '$_temp2';
  }

  @override
  String creatorMissionWorksPublished(int works) {
    String _temp0 = intl.Intl.pluralLogic(
      works,
      locale: localeName,
      other: '$works œuvres',
      one: '$works œuvre',
    );
    return 'Publier $_temp0';
  }

  @override
  String creatorMissionActivityPublished(String title) {
    return 'Vous avez publié $title';
  }

  @override
  String creatorMissionActivityFollowers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count abonnés',
      one: '$count abonné',
    );
    return 'Vous avez atteint $_temp0';
  }

  @override
  String creatorMissionActivityWorkReposts(String title, int count) {
    return '$title a atteint $count repartages';
  }

  @override
  String creatorMissionActivityWorkBookmarks(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count favoris',
      one: '$count favori',
    );
    return '$title a atteint $_temp0';
  }

  @override
  String creatorMissionActivityWorksBookmarks(int works, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count favoris',
      one: '$count favori',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count favoris',
      one: '$count favori',
    );
    String _temp2 = intl.Intl.pluralLogic(
      works,
      locale: localeName,
      other: 'Vos $works œuvres ont chacune atteint $_temp0',
      one: '$works œuvre publiée a atteint $_temp1',
    );
    return '$_temp2';
  }

  @override
  String creatorMissionActivityWorksPublished(int works) {
    String _temp0 = intl.Intl.pluralLogic(
      works,
      locale: localeName,
      other: '$works œuvres',
      one: '$works œuvre',
    );
    return 'Vous avez publié $_temp0';
  }

  @override
  String creatorMissionDetailsRepostProgress(int progress, int goal) {
    return 'Repartages actuels : $progress (requis : $goal)';
  }

  @override
  String creatorMissionDetailsWorkProgress(int progress, int goal) {
    return 'Favoris actuels : $progress (requis : $goal)';
  }

  @override
  String creatorMissionDetailsWorksProgress(int progress, int goal) {
    return 'Œuvres qualifiées : $progress (requises : $goal)';
  }

  @override
  String creatorMissionDetailsFollowersProgress(int progress, int goal) {
    return 'Abonnés actuels : $progress (requis : $goal)';
  }

  @override
  String creatorMissionTime(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours heures de création vérifiées',
      one: '$hours heure de création vérifiée',
    );
    return '$_temp0';
  }

  @override
  String creatorMissionFollowers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count abonnés',
      one: '$count abonné',
    );
    return '$_temp0';
  }

  @override
  String creatorMissionRank(int rank) {
    return 'Top $rank du classement des favoris';
  }

  @override
  String creatorMissionLocalTime(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours heures',
      one: '$hours heure',
    );
    return 'Temps de création local : $_temp0';
  }

  @override
  String creatorMissionCandidateMinutes(int minutes) {
    return 'Temps candidat enregistré : $minutes min (non vérifié)';
  }

  @override
  String get creatorMissionClaimAll => 'Tout réclamer';

  @override
  String creatorMissionClaimAllResult(int received, int failed) {
    String _temp0 = intl.Intl.pluralLogic(
      received,
      locale: localeName,
      other: '$received récompenses réclamées',
      one: '$received récompense réclamée',
    );
    String _temp1 = intl.Intl.pluralLogic(
      failed,
      locale: localeName,
      other: ' ; $failed n’ont pas pu être réclamées',
      one: ' ; $failed n’a pas pu être réclamée',
      zero: '',
    );
    return '$_temp0$_temp1';
  }

  @override
  String get creatorMissionClaimAllLoadFailed =>
      'Impossible de charger les récompenses à réclamer. Réessayez.';

  @override
  String get creatorMissionRankOne => '1re place du classement des favoris';

  @override
  String get creatorMissionDetailsRepostRule =>
      'Votre œuvre doit être publique sur NIARIM. Les repartages sont comptés pour chaque œuvre.';

  @override
  String get creatorMissionDetailsBookmarkRule =>
      'FAVORIS : Votre œuvre doit être la vôtre, encore publique sur NIARIM, et avoir suffisamment de favoris NIARIM. Chaque œuvre est évaluée séparément. Les œuvres privées ou supprimées ne comptent pas.';

  @override
  String get creatorMissionDetailsWorksRule =>
      'PLUSIEURS ŒUVRES : Vous devez publier sur NIARIM le nombre demandé d’œuvres, chacune ayant atteint le minimum de favoris. Un objectif de zéro favori concerne seulement la publication. Le serveur vérifie ces œuvres.';

  @override
  String get creatorMissionDetailsFollowerRule =>
      'ABONNÉS : Votre compte NIARIM doit actuellement atteindre le nombre indiqué selon les données du serveur, non les données envoyées par le téléphone.';

  @override
  String get creatorMissionDetailsTimeRule =>
      'TEMPS DE CRÉATION : Le temps de création est mesuré sur votre appareil et ne rapporte donc pas d’opales. Le temps affiché est indicatif.';

  @override
  String get creatorMissionDetailsClaimRule =>
      'RÉCLAMATION : Lorsque vous appuyez sur Réclamer, le serveur vérifie votre progression et crédite aussitôt la récompense si les conditions sont remplies. Chaque mission peut être réclamée une fois par compte ou par œuvre.';

  @override
  String creatorMissionRankDetailsRules(int percent, int rank) {
    return 'CALCUL : Votre œuvre doit être publiée sur NIARIM. Il faut au moins 100 œuvres publiques, assez de favoris sur votre œuvre, une place dans le top $rank et dans le top $percent %. Le seuil de rang est la partie entière de (nombre d’œuvres publiques × $percent %), au minimum 1, puis le rang le plus strict est retenu. Le comptage provient du serveur.';
  }

  @override
  String get creatorMissionRankDetailsHold =>
      'RÉCOMPENSES DE CLASSEMENT : Lorsque vous appuyez sur Réclamer, le serveur vérifie votre rang actuel et les conditions requises. Si elles sont remplies, la récompense est créditée aussitôt, une fois par rang et par œuvre.';

  @override
  String get creatorMissionRankSelectWork =>
      'Sélectionnez une œuvre pour vérifier si elle remplit les conditions de la récompense de classement';

  @override
  String get creatorMissionRankWorkNotPublic =>
      'Cette œuvre n’est pas publiée actuellement';

  @override
  String get creatorMissionRankCommunityNotMeasured =>
      'Le nombre d’œuvres publiées est en cours de calcul ; la réclamation sera possible une fois le calcul terminé';

  @override
  String creatorMissionRankCommunityWait(int count, int required) {
    return 'Pas assez d’œuvres publiées sur NIARIM : $count actuellement (minimum : $required)';
  }

  @override
  String creatorMissionRankBookmarkWait(int count, int required) {
    return 'Pas assez de favoris : $count actuellement (minimum : $required)';
  }

  @override
  String get creatorMissionRankNotRanked =>
      'Cette œuvre ne figure pas actuellement dans le top 50 du classement';

  @override
  String creatorMissionRankRankWait(int rank, int limit) {
    return 'Rang actuel : $rank ; requis : top $limit (le pourcentage supérieur s’applique aussi)';
  }

  @override
  String get creatorMissionRankQualified =>
      'Toutes les conditions sont remplies. Le serveur les vérifie lorsque vous réclamez la récompense.';

  @override
  String creatorMissionRankPoolCurrent(int count) {
    return 'Œuvres publiées sur NIARIM : $count';
  }

  @override
  String get creatorMissionRankPoolUnknown =>
      'Le nombre d’œuvres publiées est en cours de calcul. Revenez dans un instant.';

  @override
  String get creatorMissionRankCurrentUnknown =>
      'Cette œuvre n’est pas actuellement dans le top 50';

  @override
  String get creatorMissionEditTimeUnverified =>
      'Le temps de création est mesuré sur votre appareil et ne rapporte donc pas d’opales. Le temps affiché est indicatif.';

  @override
  String creatorMissionRankBookmarkCurrent(int count) {
    return 'Favoris de cette œuvre : $count';
  }

  @override
  String creatorMissionRankCurrentPlace(int rank) {
    return 'Rang actuel de cette œuvre : $rank';
  }

  @override
  String creatorMissionVerifiedMinutes(int minutes) {
    return 'Temps de création validé par l’horloge du serveur : $minutes min';
  }

  @override
  String creatorMissionRankingRequirements(int works, int bookmarks) {
    String _temp0 = intl.Intl.pluralLogic(
      works,
      locale: localeName,
      other: '$works œuvres publiées',
      one: '$works œuvre publiée',
    );
    String _temp1 = intl.Intl.pluralLogic(
      bookmarks,
      locale: localeName,
      other: '$bookmarks favoris',
      one: '$bookmarks favori',
    );
    return 'Conditions : au moins $_temp0 sur NIARIM et $_temp1 sur cette œuvre';
  }

  @override
  String creatorMissionRankingEffective(int rank) {
    return 'Rang requis avec le nombre actuel d’œuvres publiées : top $rank';
  }

  @override
  String loginBonusDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours',
      one: '$days jour',
    );
    return 'Total : $_temp0';
  }

  @override
  String loginBonusDailyCoins(int coins) {
    String _temp0 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: '$coins opales',
      one: '$coins opale',
    );
    return '$_temp0 par jour';
  }

  @override
  String loginBonusMilestone(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours',
      one: '$days jour',
    );
    return '$_temp0 de connexion';
  }

  @override
  String loginBonusActivityMilestone(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours',
      one: '$days jour',
    );
    return 'Vous avez atteint $_temp0 de connexion';
  }

  @override
  String rewardUnlockRewardQuotaRemaining(int count) {
    return 'Récompenses restantes : $count (UTC)';
  }

  @override
  String get rewardUnlockFixedPrice =>
      'Prix définitif (connectez-vous pour échanger)';

  @override
  String get missionCoinsReceived => 'Opales reçues';

  @override
  String get missionClaimFailed => 'Réclamation impossible';

  @override
  String get missionClaimUnconfirmed => 'Réclamation non confirmée';

  @override
  String get missionClaimed => 'Réclamé';

  @override
  String get missionComingSoon => 'En pause';

  @override
  String get missionClaim => 'Réclamer';

  @override
  String get missionNotYet => 'Non atteint';

  @override
  String get missionPeriodDaily => 'Quotidiennes';

  @override
  String get missionPeriodWeekly => 'Hebdomadaires';

  @override
  String get missionPeriodMonthly => 'Mensuelles';

  @override
  String get missionRefresh => 'Actualiser';

  @override
  String get missionPayoutPending =>
      'Le versement des opales est suspendu pour le moment.';

  @override
  String get recurringMissionsPayoutPending =>
      'Le versement des opales est suspendu pour le moment.';

  @override
  String missionDurationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count heures',
      one: '$count heure',
    );
    return '$_temp0';
  }

  @override
  String missionDurationMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '$count minute',
    );
    return '$_temp0';
  }

  @override
  String get plazaMissionsTitle => 'Missions de temps sur la Place des œuvres';

  @override
  String get plazaMissionsNote =>
      'Aucune lecture ni action requise. Le temps passé avec la Place des œuvres ouverte est compté à l’heure du Japon (JST).';

  @override
  String get plazaMissionsUnavailable =>
      'Missions de la Place des œuvres indisponibles';

  @override
  String plazaMissionGoal(String duration) {
    return 'Garder la Place des œuvres ouverte $duration au total';
  }

  @override
  String get recurringMissionsTitle => 'Missions de la semaine et du mois';

  @override
  String get recurringMissionsNote =>
      'Compté à l’heure du Japon ; les semaines commencent le lundi';

  @override
  String get recurringMissionsUnavailable =>
      'Missions de la semaine et du mois indisponibles';

  @override
  String recurringMissionProgress(int days, int goal) {
    String _temp0 = intl.Intl.pluralLogic(
      goal,
      locale: localeName,
      other: '$goal jours',
      one: '$goal jour',
    );
    return '$days / $_temp0';
  }

  @override
  String get missionDetailsTooltip => 'Voir les conditions de la mission';

  @override
  String get missionDetailsTitle => 'Conditions de la mission';

  @override
  String get missionDetailsClaimedThisPeriod =>
      'Récompense déjà réclamée pour cette période.';

  @override
  String get missionDetailsGoalCompleted => 'Objectif atteint.';

  @override
  String get missionDetailsGoalNotCompleted => 'Objectif pas encore atteint.';

  @override
  String get missionDetailsPayoutUnavailable =>
      'Le versement des opales est suspendu pour le moment.';

  @override
  String plazaMissionDetailsConditions(String period, String duration) {
    String _temp0 = intl.Intl.selectLogic(period, {
      'day': 'dans la même journée',
      'week': 'dans la même semaine',
      'other': 'dans le même mois',
    });
    return 'CONDITIONS : gardez la Place des œuvres de NIARIM ouverte au moins $duration au total $_temp0. Aucune lecture de vidéo ni action n’est nécessaire.';
  }

  @override
  String get plazaMissionDetailsMeasurement =>
      'Le temps est mesuré par des signaux périodiques authentifiés, datés par le serveur, et non par les secondes déclarées par l’appareil. Les longues coupures de connexion et le temps passé page fermée ne comptent pas.';

  @override
  String get plazaMissionDetailsPeriods =>
      'Les périodes suivent l’heure du Japon (JST) : les jours repartent à minuit, les semaines commencent le lundi et les mois le 1er.';

  @override
  String plazaMissionDetailsProgress(String progress, String goal) {
    return 'Temps d’ouverture actuel : $progress / $goal';
  }

  @override
  String plazaMissionDetailsClaim(int coins) {
    String _temp0 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: '$coins opales',
      one: '$coins opale',
    );
    return 'RÉCLAMATION : cet objectif rapporte $_temp0. Chaque mission se réclame une fois par période. Vous pourrez la réussir de nouveau à la période suivante, mais pas réclamer celle d’une période terminée.';
  }

  @override
  String recurringMissionGoalWeek(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours',
      one: '$days jour',
    );
    return 'Se connecter $_temp0 cette semaine';
  }

  @override
  String recurringMissionGoalMonth(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours',
      one: '$days jour',
    );
    return 'Se connecter $_temp0 ce mois-ci';
  }

  @override
  String recurringMissionDetailsConditionsWeek(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours distincts',
      one: '$days jour distinct',
    );
    return 'CONDITIONS : connectez-vous $_temp0 au cours d’une même semaine (du lundi au dimanche), à l’heure du Japon (JST). Les jours n’ont pas besoin d’être consécutifs ; plusieurs connexions le même jour comptent pour une. Le serveur vérifie les jours.';
  }

  @override
  String recurringMissionDetailsConditionsMonth(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours distincts',
      one: '$days jour distinct',
    );
    return 'CONDITIONS : connectez-vous $_temp0 au cours d’un même mois civil (du 1er au dernier jour), à l’heure du Japon (JST). Les jours n’ont pas besoin d’être consécutifs ; plusieurs connexions le même jour comptent pour une. Le serveur vérifie les jours.';
  }

  @override
  String recurringMissionDetailsProgress(int progress, int goal) {
    String _temp0 = intl.Intl.pluralLogic(
      goal,
      locale: localeName,
      other: '$goal jours',
      one: '$goal jour',
    );
    return 'Progression actuelle : $progress / $_temp0';
  }

  @override
  String recurringMissionDetailsClaim(int coins) {
    String _temp0 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: '$coins opales',
      one: '$coins opale',
    );
    return 'RÉCLAMATION : l’objectif atteint rapporte $_temp0. Chaque palier ne se réclame qu’une fois par période. La progression repart à zéro à chaque nouvelle semaine ou nouveau mois ; les récompenses d’une période passée ne peuvent plus être réclamées.';
  }

  @override
  String get missionCompletedTitle => 'Mission accomplie !';

  @override
  String get missionCompletedBody =>
      'Rendez-vous dans Missions pour réclamer votre récompense.';

  @override
  String get missionCompletedGoToMissions => 'Aller aux missions';

  @override
  String plazaMissionCompletedItem(String period, String goal) {
    String _temp0 = intl.Intl.selectLogic(period, {
      'day': 'Mission quotidienne',
      'week': 'Mission hebdomadaire',
      'other': 'Mission mensuelle',
    });
    return '$_temp0 : $goal';
  }

  @override
  String missionLoginWeek(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours',
      one: '$days jour',
    );
    return 'Se connecter $_temp0 cette semaine';
  }

  @override
  String missionLoginMonth(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours',
      one: '$days jour',
    );
    return 'Se connecter $_temp0 ce mois-ci';
  }

  @override
  String missionLoginTotal(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours',
      one: '$days jour',
    );
    return 'Se connecter $_temp0 au total';
  }

  @override
  String communityWorkMetadataCopyTooLong(int max) {
    return 'Copie impossible : limite de $max caractères dépassée';
  }

  @override
  String rewardDurationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count heures',
      one: '$count heure',
    );
    return '$_temp0';
  }

  @override
  String rewardDurationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '$count jour',
    );
    return '$_temp0';
  }

  @override
  String rewardDurationWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count semaines',
      one: '$count semaine',
    );
    return '$_temp0';
  }

  @override
  String rewardDurationMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mois',
    );
    return '$_temp0';
  }

  @override
  String get rewardUnlockReviewButton =>
      'Vérifier les doublons et l’expiration';

  @override
  String get rewardUnlockReviewTitle => 'Doublons et expiration des avantages';

  @override
  String rewardUnlockRedeemExtendNotice(DateTime expiry) {
    final intl.DateFormat expiryDateFormat = intl.DateFormat.yMMMd(
      localeName,
    ).add_jm();
    final String expiryString = expiryDateFormat.format(expiry);

    return 'Vous profitez déjà des avantages Premium. L’échange devrait les prolonger jusqu’au $expiryString. Continuer ?';
  }

  @override
  String rewardUnlockRedeemExpiryNotice(DateTime expiry) {
    final intl.DateFormat expiryDateFormat = intl.DateFormat.yMMMd(
      localeName,
    ).add_jm();
    final String expiryString = expiryDateFormat.format(expiry);

    return 'Expiration après l’échange (estimation) : $expiryString';
  }

  @override
  String rewardUnlockReviewPlayPremiumUntil(DateTime expiry) {
    final intl.DateFormat expiryDateFormat = intl.DateFormat.yMMMd(
      localeName,
    ).add_jm();
    final String expiryString = expiryDateFormat.format(expiry);

    return 'Vous êtes abonné Premium (jusqu’au $expiryString).';
  }

  @override
  String get rewardUnlockReviewPlayPremiumUnknown =>
      'Vous êtes abonné Premium. La date de fin de l’abonnement n’a pas pu être confirmée.';

  @override
  String rewardUnlockReviewCoinPremiumUntil(DateTime expiry) {
    final intl.DateFormat expiryDateFormat = intl.DateFormat.yMMMd(
      localeName,
    ).add_jm();
    final String expiryString = expiryDateFormat.format(expiry);

    return 'Vous profitez des avantages Premium (jusqu’au $expiryString).';
  }

  @override
  String rewardUnlockReviewFullIncludes(String bundle) {
    return '« $bundle », sélectionné, comprend déjà les autres avantages individuels. Les avantages en double ne sont pas activés deux fois : ils devraient être prolongés.';
  }

  @override
  String rewardUnlockReviewAdsOverlap(String bundle) {
    return 'Les avantages sans publicité sélectionnés font double emploi avec « $bundle ».';
  }

  @override
  String rewardUnlockReviewItem(String benefit, DateTime expiry) {
    final intl.DateFormat expiryDateFormat = intl.DateFormat.yMMMd(
      localeName,
    ).add_jm();
    final String expiryString = expiryDateFormat.format(expiry);

    return '$benefit : nouvelle expiration estimée au $expiryString';
  }

  @override
  String rewardUnlockReviewItemOverlap(String benefit, DateTime expiry) {
    final intl.DateFormat expiryDateFormat = intl.DateFormat.yMMMd(
      localeName,
    ).add_jm();
    final String expiryString = expiryDateFormat.format(expiry);

    return '$benefit : fait double emploi avec un avantage actif ou groupé. Nouvelle expiration estimée au $expiryString';
  }

  @override
  String rewardUnlockReviewFixedTotal(String coins) {
    return 'Total selon les prix unitaires définitifs : $coins. Le serveur confirme le devis officiel et l’expiration juste avant l’échange.';
  }

  @override
  String get homeTrashKindCreatedProject => 'Projet créé';

  @override
  String get homeTrashKindReceivedShare => 'Partagé avec vous';

  @override
  String get homeTrashKindCreatedShare => 'Partagé par vous';

  @override
  String get homeTrashKindExportedWork => 'Œuvre exportée';

  @override
  String get homeSharedReceivedFilter => 'Reçus';

  @override
  String get homeSharedCreatedFilter => 'Créés par moi';

  @override
  String get homePasteRestrictionTitle => 'Impossible de coller ici';

  @override
  String get homePasteCrossFormatBody =>
      'Impossible de coller dans un onglet ou une section d’un autre format. Collez les œuvres et les fichiers dans leur onglet ou leur section d’origine. Seuls les dossiers sans fichiers peuvent être collés ailleurs.';

  @override
  String get homePasteOutgoingNoFolders =>
      '« Créés par moi », dans Partagés, ne contient que des fichiers : impossible d’y coller des dossiers.';

  @override
  String get homePasteNestedFolders =>
      'Ce dossier contient des sous-dossiers. La destination n’accepte pas les dossiers imbriqués : le collage a été annulé pour préserver sa structure.';

  @override
  String get homePasteFolderUnreadable =>
      'Impossible de vérifier le contenu du dossier. Le collage a été annulé pour protéger vos données.';

  @override
  String get homePasteFolderNotTrashable =>
      'Ce type de dossier ne peut pas être mis à la corbeille.';

  @override
  String get homePasteToTrashQuestion =>
      'Mettre à la corbeille les œuvres et dossiers suivants ?';

  @override
  String homeTrashAutoDeleteNotice(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'Les éléments de la corbeille sont supprimés définitivement au bout de $days jours.',
      one:
          'Les éléments de la corbeille sont supprimés définitivement au bout de $days jour.',
    );
    return '$_temp0';
  }

  @override
  String get homeTrashAutoDeleteOffNotice =>
      'La suppression automatique de la corbeille est désactivée. Les éléments restent jusqu’à ce que vous les supprimiez.';

  @override
  String get homeRestoreFromTrashTitle => 'Restaurer depuis la corbeille';

  @override
  String get homeRestoreFromTrashQuestion =>
      'Restaurer depuis la corbeille les œuvres et dossiers suivants ?';

  @override
  String homeTrashRestoreSelectedConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Restaurer $count éléments ?',
      one: 'Restaurer $count élément ?',
    );
    return '$_temp0';
  }

  @override
  String commonBulletItem(String item) {
    return '• $item';
  }

  @override
  String get commonListSeparator => ', ';

  @override
  String get homeFolderMenuTooltip => 'Menu du dossier';

  @override
  String homeClipboardCutStatus(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments coupés',
      one: '$count élément coupé',
    );
    return '$_temp0';
  }

  @override
  String homeClipboardCopiedStatus(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments copiés',
      one: '$count élément copié',
    );
    return '$_temp0';
  }

  @override
  String get homeTrashPasteElsewhere =>
      'Ouvrez l’onglet d’origine et choisissez Coller pour restaurer l’élément.';

  @override
  String get homePasteRestoreOriginalQuestion =>
      'Restaurer cet élément à son emplacement d’origine ?';

  @override
  String get homePasteRestoredOriginalCollection =>
      'Élément restauré dans sa collection d’origine.';

  @override
  String get homeClipboardClear => 'Vider';

  @override
  String homeExportedWorkMetadata(DateTime date, String size) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMd(
      localeName,
    ).add_jm();
    final String dateString = dateDateFormat.format(date);

    return '$dateString · $size';
  }

  @override
  String homeWorkFolderContents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count œuvres',
      one: '1 œuvre',
      zero: 'Vide',
    );
    return '$_temp0';
  }

  @override
  String get thumbnailChangeAction => 'Changer la miniature';

  @override
  String get thumbnailDefaultLatestWork => 'Par défaut (œuvre la plus récente)';

  @override
  String get thumbnailHide => 'Ne pas afficher de miniature';

  @override
  String get thumbnailChooseWork => 'Choisir une œuvre pour la miniature';

  @override
  String get thumbnailChooseDeviceImage => 'Utiliser une image de l’appareil';

  @override
  String get thumbnailChooseWorkInFolder =>
      'Choisissez parmi les œuvres de ce dossier';

  @override
  String get thumbnailFolderNoWorks => 'Ce dossier ne contient aucune œuvre';

  @override
  String get thumbnailPickImage => 'Choisir un fichier image';

  @override
  String get thumbnailImageLoadFailed => 'Impossible de charger l’image';

  @override
  String get thumbnailPreviewFailed => 'Impossible d’afficher l’aperçu';

  @override
  String get thumbnailSaveFailed => 'Impossible d’enregistrer la miniature';

  @override
  String get thumbnailVideoInfoFailed =>
      'Impossible de lire les informations de la vidéo';

  @override
  String thumbnailCurrentFrame(int current, int total) {
    return 'Image actuelle : $current / $total';
  }

  @override
  String get thumbnailStillImageOneFrame =>
      'Une image fixe est traitée comme une animation d’une seule image.';

  @override
  String get thumbnailLastSavedFrame => 'Dernière image enregistrée';

  @override
  String get thumbnailSelectFrame => 'Choisir une image de l’animation';

  @override
  String get commonApply => 'Appliquer';

  @override
  String get commonShare => 'Partager';

  @override
  String get shareCardExportMenu => 'Exporter une carte de partage';

  @override
  String get shareCardCreatedTitle => 'Carte de partage créée';

  @override
  String get shareCardKeepOriginalNote =>
      'Enregistrez ou partagez le fichier PNG d’origine tel quel.';

  @override
  String get shareCardSaveToDevice => 'Enregistrer sur l’appareil';

  @override
  String get shareCardSaveDialogTitle => 'Enregistrer la carte de partage';

  @override
  String get shareCardSavedSnackbar => 'Carte de partage enregistrée';

  @override
  String shareCardSaveFailedSnackbar(String error) {
    return 'Impossible d’enregistrer la carte : $error';
  }

  @override
  String shareCardImportConfirmTitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'brush': 'Importer ce pinceau ?',
      'tone': 'Importer cette trame ?',
      'other': 'Importer ce tampon ?',
    });
    return '$_temp0';
  }

  @override
  String shareCardAddedSnackbar(String kind, String name) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'brush': 'Pinceau « $name » ajouté',
      'tone': 'Trame « $name » ajoutée',
      'other': 'Tampon « $name » ajouté',
    });
    return '$_temp0';
  }

  @override
  String shareCardWrongKind(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'brush':
          'Ceci est une carte de pinceau. Importez-la depuis la liste des pinceaux.',
      'tone':
          'Ceci est une carte de trame. Importez-la depuis la liste des trames.',
      'other':
          'Ceci est une carte de tampon. Importez-la depuis la liste des tampons.',
    });
    return '$_temp0';
  }

  @override
  String shareCardImportFailedSnackbar(String error) {
    return 'Impossible d’importer la carte : $error';
  }

  @override
  String get shareCardSampleHeading => 'Aperçu et images sources';

  @override
  String shareCardSourceImageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count images sources',
      one: '$count image source',
    );
    return '$_temp0';
  }

  @override
  String shareCardSourceImageCountFirst(int count, int shown) {
    return '$count images sources (les $shown premières sont affichées)';
  }

  @override
  String get shareCardBuiltInPattern =>
      'Motif intégré, généré à partir des réglages';

  @override
  String get shareCardNoSourceImages => 'Aucune image externe n’est utilisée';

  @override
  String get shareCardCompleteTitle => 'Carte de partage';

  @override
  String shareCardRestoreHint(String button) {
    return 'Choisissez cette image depuis « $button » dans NIARIM pour restaurer ses réglages et ses images.';
  }

  @override
  String get shareCardQrNote => 'Le code QR identifie cette carte';

  @override
  String get shareCardQrCannotRestore =>
      'Le code QR seul ne suffit pas à restaurer cet élément';

  @override
  String get communityUnfollowAction => 'Ne plus suivre';

  @override
  String get communityUnfollowedLabel => 'Vous ne suivez plus ce compte';

  @override
  String get communityFollowersTitle => 'Abonnés';

  @override
  String get communityFollowersEmpty => 'Aucun abonné pour le moment';

  @override
  String get communityFollowersLoadMore => 'Afficher plus';

  @override
  String get communityFollowingListEmpty => 'Vous ne suivez encore personne';

  @override
  String get communityRecentlyUnfollowedHeader => 'Désabonnements récents';

  @override
  String communityMyWorksStatusScheduled(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMd(
      localeName,
    ).add_jm();
    final String dateString = dateDateFormat.format(date);

    return 'Programmé • $dateString';
  }

  @override
  String communityMyWorksStatusScheduledHidden(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMd(
      localeName,
    ).add_jm();
    final String dateString = dateDateFormat.format(date);

    return 'Programmé • $dateString • Masqué sur la Place des œuvres';
  }

  @override
  String get communityMyWorksStatusSchedulePassed =>
      'Heure prévue dépassée • Vérification de la publication sur YouTube';

  @override
  String get communityWorkDetailYoutubeOpenFailed =>
      'Impossible d’ouvrir la vidéo sur YouTube';

  @override
  String get communityPlayerNotLinked => 'Aucune vidéo YouTube n’est associée';

  @override
  String get communityPlayerPlaybackFailed =>
      'Impossible de lire la vidéo YouTube';

  @override
  String communityPlayerTooSmall(int size) {
    return 'La lecture de la vidéo nécessite un espace d’au moins $size × $size px';
  }

  @override
  String get communityPlaybackDeletedTitle => 'Vidéo supprimée';

  @override
  String get communityPlaybackDeletedBody =>
      'Cette vidéo a été supprimée et ne peut plus être lue.';

  @override
  String get communityPlaybackPrivateTitle => 'Vidéo privée';

  @override
  String get communityPlaybackPrivateBody =>
      'Les paramètres de confidentialité empêchent sa lecture.';

  @override
  String get communityPlaybackUnavailableTitle => 'Vidéo indisponible';

  @override
  String get communityPlaybackUnavailableBody =>
      'Elle a peut-être été supprimée ou rendue privée. Son statut ne peut pas être confirmé.';

  @override
  String get communityPlaybackUnknownTitle => 'Vérification impossible';

  @override
  String get communityPlaybackUnknownBody =>
      'Un problème de connexion ou de service a empêché la vérification.';

  @override
  String get communityPlaybackCheckingTitle => 'Vérification en cours';

  @override
  String get communityPlaybackCheckingBody =>
      'Vérification de la disponibilité de la vidéo.';

  @override
  String get communityPlaybackRecheck => 'Réessayer';

  @override
  String get communityPostThumbnailHeading => 'Miniature';

  @override
  String get communityPostThumbnailUnreadable =>
      'Impossible de charger l’image. Choisissez-en une autre.';

  @override
  String get communityPostThumbnailApplied => 'Miniature définie sur YouTube';

  @override
  String get communityPostThumbnailAutoHint =>
      'Sans choix de votre part, la miniature automatique de YouTube sera utilisée.';

  @override
  String get communityPostThumbnailPickImage => 'Choisir une image';

  @override
  String get communityPostThumbnailPickFrame => 'Choisir une image de la vidéo';

  @override
  String get communityPostThumbnailUseAuto =>
      'Utiliser la miniature automatique';

  @override
  String get communityPostThumbnailWrongFormat =>
      'Choisissez une image PNG ou JPEG';

  @override
  String communityPostThumbnailTooLarge(int mb) {
    return 'L’image de la miniature ne doit pas dépasser $mb Mo';
  }

  @override
  String get communityPostThumbnailPickFailed =>
      'Impossible d’utiliser l’image. Choisissez une autre image.';

  @override
  String get communityPostFramePickerTitle =>
      'Choisissez une image pour la miniature';

  @override
  String communityPostFramePickerPosition(String current, String total) {
    return '$current / $total s';
  }

  @override
  String get communityPostFramePickerUse => 'Utiliser cette image';

  @override
  String get communityPostVideoLengthUnavailable =>
      'Impossible de lire la durée de la vidéo';

  @override
  String get communityPostFrameUnavailable =>
      'Impossible d’extraire l’image de la vidéo';

  @override
  String get communityPostFrameUnsupported =>
      'Impossible d’extraire des images de vidéos sur cet appareil. Choisissez plutôt une image.';

  @override
  String get communityPostFrameFailed =>
      'Impossible d’extraire l’image. Choisissez-en une autre ou réessayez.';

  @override
  String communityPostScheduleTooSoon(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other:
          'Choisissez une heure au moins $minutes minutes après l’heure actuelle',
      one:
          'Choisissez une heure au moins $minutes minute après l’heure actuelle',
    );
    return '$_temp0';
  }

  @override
  String get communityPostVisibilityPrivateTitle => 'Privé';

  @override
  String get communityPostVisibilityPrivateHelp =>
      'Ni visible publiquement sur YouTube ni sur la Place des œuvres.';

  @override
  String get communityPostVisibilityScheduledTitle =>
      'Programmer la publication';

  @override
  String get communityPostVisibilityScheduledHelp =>
      'Privé sur YouTube jusqu’à l’heure choisie, puis visible aussi sur la Place des œuvres.';

  @override
  String get communityPostScheduleUnset =>
      'Aucune heure de publication définie';

  @override
  String communityPostScheduleAt(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMd(
      localeName,
    ).add_jm();
    final String dateString = dateDateFormat.format(date);

    return 'Publication prévue : $dateString';
  }

  @override
  String get communityPostScheduleChoose => 'Choisir l’heure';

  @override
  String get communityPostScheduleChange => 'Modifier l’heure';

  @override
  String get fontDownloadNetworkError =>
      'Impossible de se connecter au réseau.';

  @override
  String get fontDownloadUnavailable =>
      'Impossible de télécharger cette police.';

  @override
  String get fontDownloadCorrupted => 'Le fichier de police est endommagé.';

  @override
  String get fontCategorySansSerif => 'Sans empattement';

  @override
  String get fontCategorySerif => 'Avec empattement';

  @override
  String get fontCategoryDisplay => 'Décorative';

  @override
  String get fontCategoryHandwriting => 'Manuscrite';

  @override
  String get fontCategoryMonospace => 'Chasse fixe';

  @override
  String fontCatalogEntrySubtitle(String category, String license) {
    return '$category · $license';
  }

  @override
  String get brushSettingsPaperGrain => 'Grain du papier';

  @override
  String get brushSettingsBristleStreaks => 'Traces de poils';

  @override
  String get brushSettingsDryBrush => 'Pinceau sec';

  @override
  String get colorPickerCurrentColorLabel => 'Couleur actuelle';

  @override
  String get helpShortcutSettingsDesc =>
      'Attribuez des touches du clavier ou d’un périphérique main gauche à des outils (jusqu’à un pinceau et une taille précis) ou à des actions comme annuler, rétablir, lire, avancer image par image, tout sélectionner, copier, couper et coller. Les raccourcis fonctionnent sur le canevas comme dans la timeline. Si une combinaison est déjà utilisée par une autre action, une confirmation vous est demandée avant de la remplacer.';

  @override
  String get themePreviewCardTitle => 'Aperçu des écrans';

  @override
  String get themePreviewCardSubtitle => 'Exemple de liste des projets';

  @override
  String themePreviewCardViewAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Touchez pour voir les $count écrans',
      one: 'Touchez pour voir $count écran',
    );
    return '$_temp0';
  }

  @override
  String get themePreviewCloseTooltip => 'Fermer l’aperçu';

  @override
  String get themePreviewSampleCaption => 'Aperçu des couleurs';

  @override
  String get themePreviewPreviousScreen => 'Écran précédent';

  @override
  String get themePreviewNextScreen => 'Écran suivant';

  @override
  String get themePreviewHideControls => 'Masquer les commandes';

  @override
  String get themePreviewShowControls => 'Afficher les commandes';

  @override
  String get themePreviewThumbnailSemantics =>
      'Miniature de la liste des projets avec le thème actuel';

  @override
  String get themePreviewScreenSplash => 'Écran de lancement';

  @override
  String get themePreviewScreenProjects => 'Liste des projets';

  @override
  String get themePreviewScreenProjectDetail => 'Détails du projet';

  @override
  String get themePreviewScreenCanvas => 'Mode canevas';

  @override
  String get themePreviewScreenTimeline => 'Mode timeline';

  @override
  String get themePreviewScreenExport => 'Export de l’œuvre';

  @override
  String get themePreviewScreenSaves => 'Gestion des sauvegardes';

  @override
  String get themePreviewScreenWorkDetail =>
      'Place des œuvres : détails de l’œuvre';

  @override
  String get themePreviewScreenPost => 'Place des œuvres : publier une œuvre';

  @override
  String get themePreviewScreenAuthor => 'Œuvres de l’auteur';

  @override
  String get themePreviewScreenNotifications => 'Notifications';

  @override
  String get themePreviewSampleProjectName => 'Ma première animation';

  @override
  String get themePreviewSampleWorkTitle1 => 'Une promesse après la pluie';

  @override
  String get themePreviewSampleWorkTitle2 => 'Aventure à l’aube';

  @override
  String get themePreviewSampleWorkTitle3 => 'La dernière mélodie';

  @override
  String get themePreviewSampleArtist => 'Artiste exemple';

  @override
  String get themePreviewSampleStudio => 'Atelier Asakaze';

  @override
  String get themePreviewSampleDescriptionLabel => 'Description';

  @override
  String get themePreviewSampleDescriptionHint => 'Ajoutez une description';

  @override
  String get workspaceToolbarSizeLabel => 'Taille des icônes d’outils';

  @override
  String get pcLayoutAutoFoldTitle =>
      'Replier automatiquement les fenêtres d’outils';

  @override
  String get pcLayoutAutoFoldHelp =>
      'Les fenêtres utilisées le moins récemment se replient temporairement, uniquement si les fenêtres ne tiennent toujours pas une fois réduites. La fenêtre en cours reste ouverte et les fenêtres repliées reviennent dès que la place le permet. Si l’option est désactivée, la colonne défile simplement.';

  @override
  String get pcLayoutResetWorkspace => 'Réinitialiser l’espace de travail';

  @override
  String get pcLayoutInstruction =>
      'Faites glisser le bord d’une fenêtre dans l’aperçu pour modifier sa largeur ou sa hauteur. Maintenez la poignée en haut à gauche pour la déplacer ou l’échanger avec une autre. Pincez pour zoomer.';

  @override
  String get brushNibWidthRatio =>
      'Largeur de la pointe par rapport à la hauteur';

  @override
  String get brushFoldEndTaper => 'Effilement de la pointe repliée';

  @override
  String get timelineSelectionScenes => 'Scènes';

  @override
  String get timelineSelectionClips => 'Clips multimédias';

  @override
  String get helpShowAllTopics => 'Afficher tous les sujets';

  @override
  String get transferExportFileFailed =>
      'Impossible de créer le fichier de transfert.';

  @override
  String get transferImportFileFailed =>
      'Impossible de lire le fichier de transfert.';

  @override
  String get transferImportInterrupted =>
      'L’importation a été interrompue. Les éléments déjà importés restent disponibles.';

  @override
  String get transferImportStepSettings => 'Réglages, thèmes et palettes';

  @override
  String get transferImportStepDeviceData =>
      'Préférences de l’appareil et éléments enregistrés';

  @override
  String get transferImportStepProjects => 'Projets';

  @override
  String get transferImportCompletedSteps => 'Étapes terminées';

  @override
  String get transferImportFailedStep =>
      'Étape interrompue (certains changements ont pu être appliqués)';

  @override
  String get transferImportPendingSteps => 'Étapes non démarrées';

  @override
  String get communityChannelRefreshRetry =>
      'Impossible d’actualiser les informations de la chaîne YouTube. Réessayez.';

  @override
  String get timelineAutofillBatchCancelled =>
      'Remplissage automatique annulé.';

  @override
  String timelineAutofillFailedFrames(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Le remplissage automatique a échoué pour $count images.',
      one: 'Le remplissage automatique a échoué pour $count image.',
    );
    return '$_temp0';
  }

  @override
  String get timelineAutofillFileError =>
      'Certaines données de fichier sont inaccessibles.';

  @override
  String get timelineAutofillProcessingError =>
      'Une erreur est survenue pendant le traitement du dessin.';

  @override
  String get timelineAutofillBatchFailed =>
      'Une erreur a interrompu le remplissage automatique.';

  @override
  String get pcBinEmpty => 'Aucun matériau pour l’instant';

  @override
  String pcBinSceneFrames(int count) {
    return '$count images';
  }

  @override
  String get pcInspectorHint =>
      'Sélectionnez un matériau dans la timeline pour régler ici sa position, sa taille, son opacité, etc.';

  @override
  String get pcPaneInspector => 'Détails';

  @override
  String get pcPaneProgram => 'Aperçu';

  @override
  String get pcTimelineZoomIn => 'Agrandir la timeline';

  @override
  String get pcTimelineZoomOut => 'Réduire la timeline';

  @override
  String get communityTagLockedMessage =>
      'Ce tag est verrouillé. Seul l’auteur de l’œuvre peut le modifier.';

  @override
  String get communityTagEditPrompt => 'Modifier ce tag ?';

  @override
  String get communityTagSearchAction => 'Rechercher ce tag';

  @override
  String get communityTagDeleteConfirm => 'Supprimer ce tag ?';

  @override
  String get communityTagLockAction => 'Verrouiller';

  @override
  String get communityTagUnlockAction => 'Déverrouiller';

  @override
  String get communityTagUnlockBeforeDelete =>
      'La personne qui a publié doit déverrouiller ce tag avant qu’il puisse être supprimé.';

  @override
  String get communityPreviewStart => 'Aller au début';

  @override
  String get communityPreviewEnd => 'Aller à la fin';

  @override
  String get communityPreviewBackward => 'Reculer de 5 secondes';

  @override
  String get communityPreviewForward => 'Avancer de 5 secondes';

  @override
  String get settingsSupportTitle => 'Aide et contact';

  @override
  String get settingsSupportEmailCopied => 'Adresse e-mail copiée';

  @override
  String get settingsGroupGeneral => 'Application';

  @override
  String get settingsGroupDrawing => 'Dessin et saisie';

  @override
  String get settingsGroupAppearance => 'Apparence et écran';

  @override
  String get settingsGroupDataSupport => 'Données et assistance';

  @override
  String get settingsSupportForm => 'Ouvrir le formulaire de contact';

  @override
  String get settingsSupportLinkFailed =>
      'Impossible d’ouvrir le formulaire de contact.';

  @override
  String get canvasToolbarToggleTooltip =>
      'Afficher ou masquer la barre d’outils';

  @override
  String get canvasFrameStripToggleTooltip =>
      'Afficher ou masquer la bande d’images';

  @override
  String get layerPanelToggleFolderTooltip =>
      'Développer ou replier le dossier';

  @override
  String get layerPanelShowLayerTooltip => 'Afficher le calque';

  @override
  String get layerPanelHideLayerTooltip => 'Masquer le calque';

  @override
  String get layerPanelMergeDownTooltip => 'Fusionner avec le calque inférieur';

  @override
  String get timelineAddTrackRowTooltip => 'Ajouter une ligne à la piste';

  @override
  String get timelineVideoTrackShowingFrames =>
      'Images de la vidéo affichées (touchez pour afficher la forme d’onde du son)';

  @override
  String get timelineVideoTrackShowingWaveform =>
      'Forme d’onde du son affichée (touchez pour afficher les images de la vidéo)';

  @override
  String get timelineVideoSoundFollowsSpeed => 'Lire le son à la même vitesse';

  @override
  String get timelineVideoSoundFollowsSpeedHint =>
      'Si cette option est désactivée, le son est lu à vitesse normale depuis le début du clip et seule l’image change de vitesse.';

  @override
  String get timelinePitchLabel => 'Hauteur (demi-tons)';

  @override
  String get timelinePitchHint =>
      'Changer la vitesse ne change pas la hauteur. Ici, vous pouvez monter ou baisser seulement la hauteur. Suivre la vitesse donne la hauteur qu’aurait une bande à cette vitesse.';

  @override
  String get timelinePitchMatchSpeed => 'Suivre la vitesse';

  @override
  String get timelinePitchReset => 'Hauteur d’origine';

  @override
  String get timelinePitchInputLabel => 'Saisir en demi-tons';

  @override
  String get timelinePitchInvalid =>
      'Saisissez un nombre de -24 à +24 (décimales possibles).';

  @override
  String get keyframeRetimeTitle => 'Vitesse des images clés';

  @override
  String get keyframeRetimeHint =>
      'Modifie l’espacement des clés de la plage choisie selon la vitesse. Leurs valeurs et leur lissage ne changent pas, et les clés hors de la plage ne bougent pas.';

  @override
  String get keyframeRetimeFrom => 'Première clé de la plage';

  @override
  String get keyframeRetimeTo => 'Dernière clé de la plage';

  @override
  String get keyframeRetimeClash =>
      'Avec cette vitesse, deux clés tomberaient sur la même image, une clé dépasserait une clé située après la plage ou sortirait de la fin de la scène.';

  @override
  String keyframeRetimePreview(String before, String after) {
    return 'Position des clés : $before → $after';
  }

  @override
  String get keyframePreviewGestureHint =>
      'Faites glisser l’aperçu pour déplacer. Pincez ou tournez avec deux doigts pour redimensionner ou faire pivoter.';

  @override
  String get settingsAccountDeletionTitle => 'Supprimer votre compte NIARIM';

  @override
  String get settingsAccountDeletionSubtitle =>
      'Continuer sur le site officiel';

  @override
  String get settingsAccountDeletionLinkFailed =>
      'Impossible d’ouvrir la page de suppression du compte.';

  @override
  String get settingsCommerceDisclosure =>
      'Mentions légales (loi sur les transactions commerciales spécifiées)';

  @override
  String get settingsCommerceDisclosureLinkFailed =>
      'Impossible d’ouvrir la page des mentions légales.';

  @override
  String get communitySampleReportUnavailable =>
      'Vous ne pouvez pas signaler les œuvres ni les créateurs de démonstration.';

  @override
  String get communityReportAuthor => 'Signaler ce compte';

  @override
  String get communityReportReason =>
      'Motif du signalement (visible uniquement par la modération)';

  @override
  String get communityReportSend => 'Envoyer le signalement';

  @override
  String get communityReportSent => 'Signalement envoyé à la modération';

  @override
  String get communityModerationSaved => 'Modifications enregistrées';

  @override
  String get communityModerationFailed =>
      'Impossible de terminer cette action. Réessayez plus tard.';

  @override
  String get communityBlockAuthor => 'Bloquer ce compte';

  @override
  String get communityUnblockAuthor => 'Débloquer ce compte';

  @override
  String get communityBlockPrivacyNotice =>
      'Une fois connectés, vous ne verrez plus vos publications respectives sur la Place des œuvres. Aucune notification ne sera envoyée.';

  @override
  String get communityBlockedUsers => 'Comptes bloqués';

  @override
  String get communityBlockedUsersEmpty => 'Vous n’avez bloqué aucun compte.';

  @override
  String get canvasViewActions => 'Affichage du canevas';

  @override
  String get canvasViewZoomIn => 'Agrandir';

  @override
  String get canvasViewZoomOut => 'Réduire';

  @override
  String get canvasViewActualPixels => 'Taille réelle';

  @override
  String get canvasViewRotateLeft => 'Tourner à gauche';

  @override
  String get canvasViewRotateRight => 'Tourner à droite';

  @override
  String get canvasViewResetRotation => 'Réinitialiser la rotation';

  @override
  String get projectDetailShowPlaybackControls =>
      'Afficher les commandes de lecture';

  @override
  String get projectDetailHidePlaybackControls =>
      'Masquer les commandes de lecture';

  @override
  String get filterSaveSettings => 'Enregistrer ces réglages';

  @override
  String get filterLoadSettings => 'Appliquer les réglages enregistrés';

  @override
  String get filterSettingsName => 'Nom des réglages';

  @override
  String get filterSettingsEmpty => 'Aucun réglage enregistré pour ce filtre.';

  @override
  String get filterSettingsSaved => 'Réglages du filtre enregistrés';

  @override
  String get makingRecordProject => 'Capturer le processus de ce projet';

  @override
  String get makingRecordProjectHint =>
      'Désactivé par défaut. Une fois activé, seules les parties modifiées sont enregistrées à chaque trait, annulation ou rétablissement. Utilise le stockage de l’appareil.';

  @override
  String get makingReadAloud => 'Synthèse vocale';

  @override
  String get makingSpeechText => 'Texte à lire';

  @override
  String get makingVoice => 'Voix';

  @override
  String get makingRate => 'Vitesse';

  @override
  String get makingPitch => 'Hauteur';

  @override
  String get makingSpeechNotice =>
      'La voix est générée par un moteur installé sur cet appareil. Vérifiez les conditions du moteur et des données vocales avant toute utilisation commerciale.';

  @override
  String get makingManageVoices => 'Ajouter ou gérer des voix';

  @override
  String get makingNoVoices =>
      'Aucune voix hors ligne. Installez des données vocales dans les paramètres Android.';

  @override
  String get makingGenerateAndAdd => 'Générer et ajouter';

  @override
  String get makingStartFrame => 'Image de début';

  @override
  String get makingPlay => 'Lire le making-of';

  @override
  String get makingTitle => 'Making-of';

  @override
  String get makingEmpty =>
      'Aucun historique de création. Activez l’enregistrement dans les détails du projet et continuez à créer.';

  @override
  String get makingEmptyRecordingOn =>
      'La capture est activée. Quand vous dessinez sur le canevas, le processus est capturé ici.';

  @override
  String get makingLoadFailed =>
      'Impossible de charger l’historique de création';

  @override
  String get makingStorageLimit =>
      'La limite de 2 Go est atteinte. L’enregistrement automatique est arrêté et l’historique existant est conservé.';

  @override
  String get makingExportLength => 'Durée de la vidéo';

  @override
  String makingExportLengthOriginal(String duration) {
    return 'Durée d’origine ($duration)';
  }

  @override
  String get makingFormatWebm => 'WebM';

  @override
  String get makingExportLabel => 'Exporter le making-of';

  @override
  String get makingExportComplete => 'Vidéo du making-of exportée.';

  @override
  String get makingExportFailed => 'Impossible d’exporter la vidéo.';

  @override
  String get makingDeleteHistory => 'Supprimer l’historique';

  @override
  String get makingDeleteHistoryConfirm =>
      'Supprimer tous les instantanés et l’historique de ce projet ? Cette action est irréversible.';

  @override
  String get makingDeleteFailed => 'Impossible de supprimer l’historique.';

  @override
  String get makingHistoryDeleted => 'Historique supprimé.';

  @override
  String makingFrameCounter(int current, int total) {
    return 'Instantané $current / $total';
  }

  @override
  String get makingSpeechFailed =>
      'La synthèse vocale a échoué. Vérifiez les données vocales.';

  @override
  String get opalGiftPresentBox => 'Boîte à cadeaux';

  @override
  String opalGiftUnclaimedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cadeaux à recevoir',
      one: '$count cadeau à recevoir',
    );
    return '$_temp0';
  }

  @override
  String get opalGiftPresentEmpty => 'Aucun cadeau à recevoir';

  @override
  String get opalGiftPresentEmptyHint =>
      'Les cadeaux de l’équipe NIARIM arrivent ici. Les cadeaux dont la date limite est passée ne sont pas affichés.';

  @override
  String get opalGiftClaim => 'Recevoir';

  @override
  String get opalGiftClaimed => 'Reçu';

  @override
  String opalGiftClaimUntil(DateTime deadline) {
    final intl.DateFormat deadlineDateFormat = intl.DateFormat.yMMMd(
      localeName,
    ).add_jm();
    final String deadlineString = deadlineDateFormat.format(deadline);

    return 'À recevoir jusqu’au $deadlineString';
  }

  @override
  String opalGiftReceived(String amount) {
    return 'Vous avez reçu $amount.';
  }

  @override
  String get opalGiftPresentExpired =>
      'La date limite de ce cadeau est passée.';

  @override
  String get opalGiftPresentEnded => 'Ce cadeau ne peut plus être reçu.';

  @override
  String get opalGiftLoadFailed => 'Impossible de charger vos cadeaux.';

  @override
  String get opalGiftReload => 'Réessayer';

  @override
  String get opalGiftClaimFailed =>
      'Réception impossible. Vérifiez votre connexion, puis réessayez.';

  @override
  String get opalGiftSignInRequired =>
      'Votre connexion Google a expiré. Reconnectez-vous.';

  @override
  String get opalCouponEnter => 'Saisir un code promo';

  @override
  String get opalCouponIntro =>
      'Saisissez un code promo partagé sur les réseaux sociaux ou ailleurs pour recevoir des opales.';

  @override
  String get opalCouponOfferTitle => 'Vous avez un code promo ?';

  @override
  String get opalCouponOfferBody =>
      'Saisissez votre code promo pour recevoir des opales. Vous pourrez aussi le saisir plus tard dans l’écran « Opales et bonus ».';

  @override
  String get opalCouponField => 'Code promo';

  @override
  String get opalCouponFieldHint => 'Exemple : ABCD-2345-EFGH';

  @override
  String get opalCouponFieldHelper =>
      'Majuscules, minuscules, espaces et tirets sont ignorés';

  @override
  String get opalCouponLater => 'Plus tard';

  @override
  String get opalCouponErrorFormat =>
      'Un code comporte de 4 à 32 lettres et chiffres. Vérifiez votre saisie.';

  @override
  String get opalCouponErrorNotFound =>
      'Ce code promo est introuvable. Vérifiez votre saisie.';

  @override
  String get opalCouponErrorEnded =>
      'La distribution de ce code promo est terminée.';

  @override
  String get opalCouponErrorExpired => 'Ce code promo a expiré.';

  @override
  String get opalCouponErrorNotYet =>
      'Ce code promo n’est pas encore utilisable. Saisissez-le une fois la distribution commencée.';

  @override
  String get opalCouponErrorLimit =>
      'Ce code promo a atteint son nombre maximal d’utilisations.';

  @override
  String get opalCouponErrorUsed => 'Ce compte a déjà utilisé ce code promo.';

  @override
  String get opalCouponErrorNewOnly =>
      'Ce code promo est réservé aux comptes créés récemment.';

  @override
  String get opalCouponErrorNotEligible =>
      'Ce compte ne peut pas utiliser ce code promo.';

  @override
  String get opalCouponErrorRateLimited =>
      'Trop de tentatives. Patientez environ une heure, puis réessayez.';

  @override
  String get rewardUnlockHistoryPresent => 'Cadeau';

  @override
  String get rewardUnlockHistoryCoupon => 'Code promo';
}
