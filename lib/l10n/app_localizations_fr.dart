// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get homeTabProjects => 'Projets';

  @override
  String get homeTabShared => 'Partagés';

  @override
  String get homeTabTrash => 'Corbeille';

  @override
  String get homeTabWorks => 'Œuvres';

  @override
  String get homeTabBookmarked => 'Enregistrées';

  @override
  String get homeBookmarkedComingSoonTitle => 'Bientôt disponible';

  @override
  String get homeBookmarkedComingSoonBody =>
      'Une fois la fonctionnalité « Voir les animations de tous » disponible, les œuvres d\'autres utilisateurs que vous avez enregistrées apparaîtront ici.';

  @override
  String get homeSearchHint => 'Rechercher par nom de projet';

  @override
  String get homeBackToSplashTooltip => 'Retour à l\'écran de lancement';

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
  String get homeSelectionAddFavorite => 'Ajouter aux favoris';

  @override
  String get homeSelectionRemoveFavorite => 'Retirer des favoris';

  @override
  String homeSelectionCount(int count) {
    return '$count sélectionné(s)';
  }

  @override
  String get homeMoveToTrash => 'Mettre à la corbeille';

  @override
  String homeMoveToTrashConfirm(int count) {
    return 'Mettre $count élément(s) à la corbeille ?';
  }

  @override
  String get commonMove => 'Déplacer';

  @override
  String get homeShareFileDialogTitle => 'Fichier partagé';

  @override
  String get homeShareFileDialogContent =>
      'Dupliquer ce fichier partagé et l\'enregistrer comme projet normal ?';

  @override
  String homeMissingFontsSnackbar(String names) {
    return 'Polices manquantes : $names';
  }

  @override
  String get homeSharedImportedSnackbar => 'Ajouté à l\'onglet Projets';

  @override
  String homeSharedImportFailedSnackbar(String error) {
    return 'Échec du chargement du fichier partagé : $error';
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
  String get homeSortFieldName => 'Nom';

  @override
  String get homeSortFieldUpdated => 'Mis à jour';

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
    return '${fps}ips · ${duration}s';
  }

  @override
  String get homeTrashEmpty => 'La corbeille est vide';

  @override
  String homeTrashDeletedOn(String date) {
    return 'Supprimé le $date';
  }

  @override
  String get homePermanentDelete => 'Supprimer définitivement';

  @override
  String get homePermanentDeleteConfirmTitle => 'Supprimer définitivement ?';

  @override
  String get homePermanentDeleteConfirmBody => 'Cette action est irréversible.';

  @override
  String get homeWorksEmpty => 'Aucune œuvre exportée pour le moment';

  @override
  String get homeWorksEmptyHint =>
      'Exportez une vidéo ou un GIF depuis le canevas et il apparaîtra ici';

  @override
  String get homeShareOpenWith => 'Partager / Ouvrir dans Photos';

  @override
  String homeWorkDeleteConfirmTitle(String name) {
    return 'Supprimer $name ?';
  }

  @override
  String get homeWorkDeleteConfirmBody =>
      'Le fichier exporté sur cet appareil sera supprimé. Cette action est irréversible.';

  @override
  String get homePreviewFailed => 'Impossible de lire l\'aperçu';

  @override
  String get homeFirstLaunchMessage =>
      'Vous pouvez créer des animations dessinées à la main';

  @override
  String get homeFirstLaunchStart => 'Commencer';

  @override
  String get settingsScreenTitle => 'Réglages';

  @override
  String get settingsBasicTitle => 'Général';

  @override
  String get settingsBasicSubtitle => 'FPS, couleur de fond, langue';

  @override
  String get settingsBasicSheetTitle => 'Réglages généraux';

  @override
  String get settingsDefaultFps => 'FPS par défaut';

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
      'Qualité, historique d\'annulation, corbeille, performances';

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
      'Édition de la barre d\'outils, disposition des panneaux';

  @override
  String get settingsBucketTitle => 'Pot de peinture';

  @override
  String get settingsBucketSubtitle => 'Tolérance, extension, sous les traits';

  @override
  String get settingsThemeTitle => 'Thème et apparence';

  @override
  String get settingsThemeSubtitle => 'Réglages de thème, espace de travail';

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
  String get settingsFontTitle => 'Gestion des polices';

  @override
  String get settingsFontSubtitle =>
      'Ajouter, rechercher et supprimer des polices TTF/OTF';

  @override
  String get settingsNoResults => 'Aucun réglage correspondant trouvé';

  @override
  String get settingsTermsLicense => 'Conditions d\'utilisation et licences';

  @override
  String get settingsDrawingAreaTitle => 'Zone de dessin par défaut';

  @override
  String get settingsDrawingAreaHint =>
      'Utilisée comme valeur initiale à la création d\'un nouveau projet.';

  @override
  String get settingsDrawingAreaWiden => 'Élargir la zone de dessin';

  @override
  String get settingsDrawingAreaScale => 'Échelle';

  @override
  String settingsScaleValue(String scale) {
    return '×$scale';
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
      'Voulez-vous vraiment supprimer ceci ? Cette action est irréversible.';

  @override
  String confirmDeleteNamedBody(String name) {
    return 'Supprimer « $name » ? Cette action est irréversible.';
  }

  @override
  String get commonFavoriteDeleteBlocked =>
      'Impossible de supprimer un élément favori. Retirez-le d\'abord des favoris.';

  @override
  String get commonSave => 'Enregistrer';

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
  String homePasteTooltip(int count) {
    return 'Coller $count élément(s)';
  }

  @override
  String get homePasteSnackbar => 'Collé';

  @override
  String get commonOk => 'OK';

  @override
  String get gestureSettingsTitle => 'Réglages des gestes';

  @override
  String get gestureTwoFingerTap => 'Appui à deux doigts';

  @override
  String get gestureThreeFingerTap => 'Appui à trois doigts';

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
      'En dessinant avec le stylo ou la gomme, maintenir le doigt immobile un instant prélève la couleur sous le doigt comme couleur actuelle.';

  @override
  String get gestureHoldEyedropperDurationLabel => 'Durée de maintien';

  @override
  String gestureHoldEyedropperSecondsValue(String seconds) {
    return '$seconds s';
  }

  @override
  String get gestureActionEyedropper => 'Pipette';

  @override
  String get gestureActionPanTool => 'Outil main';

  @override
  String get gestureActionEraserToggle => 'Basculer la gomme';

  @override
  String get gestureActionBrushToggle => 'Basculer le pinceau';

  @override
  String get gestureActionFrameMove => 'Changer d\'image';

  @override
  String get gestureActionNextTool => 'Changement rapide d\'outil';

  @override
  String get gestureActionOnionSkinToggle =>
      'Activer/désactiver le papier calque';

  @override
  String get gestureActionNone => 'Ne rien faire';

  @override
  String get homeDrawerAppTagline =>
      'Application de création d\'animation dessinée à la main';

  @override
  String get homeDrawerAutofillPreset => 'Réglages de remplissage auto';

  @override
  String get homeDrawerSettings => 'Réglages';

  @override
  String get homeDrawerHelp => 'Aide';

  @override
  String get homeDrawerTips => 'Astuces';

  @override
  String get homeDrawerPremium => 'Premium';

  @override
  String get gestureActionNoneShort => 'Aucune';

  @override
  String get pressureTryDrawHint =>
      'Vous pouvez essayer de dessiner avec ce réglage (avec un stylet, la pression réelle est prise en compte)';

  @override
  String get pressureTryDrawClear => 'Effacer';

  @override
  String get penSettingsTitle => 'Réglages de saisie au stylet';

  @override
  String get penSettingsCurveSection => 'Courbe de pression';

  @override
  String get penSettingsCurveHint =>
      'Un réglage plus faible fait monter la pression progressivement ; un réglage plus fort la fait monter brusquement.';

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
      'Touchez un espace vide du graphique pour ajouter un point (jusqu\'à 10), faites glisser un point pour le déplacer, ou touchez-le deux fois pour le supprimer (les points de début et de fin ne peuvent pas être supprimés).';

  @override
  String get penSettingsResetCurveButton => 'Réinitialiser';

  @override
  String get penSettingsPerBrushNote =>
      '* Le réglage « Appliquer à la taille/opacité » de la pression est propre à chaque pinceau (à modifier dans le panneau de réglages du pinceau).';

  @override
  String get penSettingsButtonSection => 'Réglages des boutons du stylet';

  @override
  String get penSettingsButton1 => 'Bouton 1';

  @override
  String get penSettingsButton2 => 'Bouton 2';

  @override
  String get bucketSettingsTitle => 'Réglages du pot de peinture';

  @override
  String get bucketSettingsToleranceSection => 'Tolérance';

  @override
  String get bucketSettingsToleranceHint =>
      'Ajuste l\'écart de couleur toléré par rapport au pixel touché pour être considéré comme la même zone. Plus la valeur est élevée, plus le remplissage se propage facilement même sur des contours flous.';

  @override
  String get bucketSettingsExpandSection => 'Extension';

  @override
  String get bucketSettingsExpandHint =>
      'Étend la zone remplie vers l\'extérieur du nombre de pixels indiqué, pour couvrir les petits interstices près du trait.';

  @override
  String get bucketSettingsUnderLineTitle => 'Passer sous les traits';

  @override
  String get bucketSettingsUnderLineHint =>
      'Au lieu de peindre par-dessus le trait, l\'extension se fond derrière les pixels existants : l\'apparence du trait est conservée tout en comblant les interstices de ses bords anticrénelés.';

  @override
  String get bucketSettingsUnderLineDisabledHint =>
      'Sans effet lorsque « Extension » est à 0 px.';

  @override
  String fontCatalogSearchHint(int count) {
    return 'Rechercher par nom de police... ($count polices)';
  }

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
  String transferExportFailedSnackbar(String error) {
    return 'Échec de l\'exportation : $error';
  }

  @override
  String get transferImportSuccessSnackbar => 'Fichier .niatra importé';

  @override
  String transferImportFailedSnackbar(String error) {
    return 'Échec de l\'importation : $error';
  }

  @override
  String get folderManagementTitle => 'Gestion des dossiers';

  @override
  String get folderManagementCreateNew => 'Nouveau';

  @override
  String get folderManagementEmpty => 'Aucun dossier pour le moment';

  @override
  String get folderNameLabel => 'Nom du dossier';

  @override
  String get folderMoveToTitle => 'Déplacer vers un dossier';

  @override
  String get folderNone => 'Aucun dossier';

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
    return '$count parties';
  }

  @override
  String get autofillPresetSelectionButton =>
      'Sélectionner les réglages de remplissage auto à utiliser';

  @override
  String autofillPresetSelectionCountLabel(int count) {
    return '$count sélectionné(s)';
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
      'Enregistrer les modifications avant de revenir ?';

  @override
  String get timelineBackToProjectListSaveButton => 'Enregistrer et revenir';

  @override
  String get timelineBackToProjectListDiscardButton =>
      'Revenir sans enregistrer';

  @override
  String get timelineSkipToStart => 'Aller à la première image';

  @override
  String get timelineStepBack => 'Reculer d\'une image';

  @override
  String get timelineStepForward => 'Avancer d\'une image';

  @override
  String get timelineSkipToEnd => 'Aller à la dernière image';

  @override
  String get timelineLoopOnTooltip =>
      'Lecture en boucle : ACTIVÉE (touchez pour désactiver)';

  @override
  String get timelineLoopOffTooltip =>
      'Lecture en boucle : DÉSACTIVÉE (touchez pour activer)';

  @override
  String get quickToolPanelTitle => 'Réglages des outils rapides';

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
      'Assignez des touches du clavier ou d\'un périphérique main gauche à des outils (jusqu\'à un pinceau et une taille précis) ou à des actions comme Annuler/Rétablir. Fonctionne en mode Canevas et en mode Chronologie.';

  @override
  String get shortcutEmpty => 'Aucun raccourci enregistré';

  @override
  String get shortcutCaptureTitle => 'Appuyez sur une touche';

  @override
  String get shortcutCaptureHint =>
      'Appuyez sur la combinaison de touches à assigner (vous pouvez maintenir Ctrl/Maj/Alt, etc. en même temps). Appuyez sur Échap pour annuler.';

  @override
  String shortcutChooseActionTitle(String combo) {
    return 'Que doit faire $combo ?';
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
  String get shortcutCommandPlayPause => 'Lecture/Pause (Chronologie)';

  @override
  String get shortcutCommandPreviousFrame => 'Image précédente (Chronologie)';

  @override
  String get shortcutCommandNextFrame => 'Image suivante (Chronologie)';

  @override
  String get shortcutCommandSelectAll => 'Tout sélectionner';

  @override
  String get shortcutCommandCopy => 'Copier';

  @override
  String get shortcutCommandCut => 'Couper';

  @override
  String get shortcutCommandPaste => 'Coller';

  @override
  String get shortcutConflictTitle => 'Déjà assigné';

  @override
  String shortcutConflictBody(String combo, String existingLabel) {
    return '$combo est déjà assigné à « $existingLabel ». Voulez-vous l\'écraser ?';
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
      'Ajoutez des images, vidéos ou fichiers audio depuis la chronologie et ils apparaîtront ici';

  @override
  String get materialUsedLabel => 'Utilisé';

  @override
  String get materialUnusedLabel => 'Inutilisé';

  @override
  String get materialMissingLabel => '⚠ Manquant';

  @override
  String get materialDeleteTooltipUsed =>
      'Impossible de supprimer un élément utilisé';

  @override
  String get materialRemoveOneConfirmTitle => 'Supprimer ce matériau ?';

  @override
  String get materialRemoveUnusedConfirmTitle =>
      'Supprimer tous les matériaux inutilisés ?';

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
  String get watermarkShadowColorLabel => 'Couleur de l\'ombre';

  @override
  String get watermarkShadowOffsetXLabel => 'Décalage X de l\'ombre';

  @override
  String get watermarkShadowOffsetYLabel => 'Décalage Y de l\'ombre';

  @override
  String get watermarkShadowBlurLabel => 'Flou de l\'ombre';

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
  String get premiumHeroSubtitle =>
      'Sans limite de durée, sans filigrane, courbe de tons et correction des niveaux, et bien plus : tout est débloqué.';

  @override
  String get premiumHeroHighlightDuration => 'Jusqu\'à 2 heures';

  @override
  String get premiumHeroHighlightWatermark => 'Sans filigrane';

  @override
  String get premiumHeroHighlightGrading => 'Courbe de tons /\nniveaux';

  @override
  String get premiumCampaignFreeNote =>
      '* Pendant la campagne, toutes les fonctionnalités Premium ci-dessus sont gratuites pour tout le monde';

  @override
  String get premiumPlanSectionTitle => 'Formules';

  @override
  String get premiumStoreUnavailable =>
      'Impossible de se connecter à la boutique (les achats ne sont possibles que sur un appareil réel ou dans un environnement de révision de la boutique)';

  @override
  String get premiumYearlyTitle => 'Formule annuelle (recommandée)';

  @override
  String get premiumYearlyDescription => 'Équivalent à 2 mois gratuits';

  @override
  String get premiumYearlyPrice => '5 500 ¥/an';

  @override
  String get premiumYearlyOriginalPrice => '6 600 ¥';

  @override
  String get premiumYearlyPerMonthLabel => 'Soit 458 ¥/mois';

  @override
  String get premiumMonthlyTitle => 'Formule mensuelle';

  @override
  String get premiumRestorePurchases => 'Restaurer les achats';

  @override
  String get premiumRestoredSnackbar =>
      'Vos achats ont été restaurés (le cas échéant)';

  @override
  String get premiumCampaignBannerTitle =>
      'Campagne de lancement ! Fonctionnalités Premium débloquées pour tous';

  @override
  String get premiumCampaignBannerBody =>
      'Pendant la campagne, toutes les fonctionnalités Premium (durée jusqu\'à 2 heures, édition du logo de fin, filigrane, courbe de tons, correction des niveaux) sont gratuites, même dans la formule gratuite.';

  @override
  String premiumCampaignEndLabel(String date) {
    return 'Jusqu\'au $date';
  }

  @override
  String get premiumComparisonFeature => 'Fonctionnalité';

  @override
  String get premiumComparisonFree => 'Gratuit';

  @override
  String get premiumFeatureDrawing => 'Dessin et animation';

  @override
  String get premiumFeatureTimeline => 'Chronologie';

  @override
  String get premiumFeatureExport => 'Export vidéo';

  @override
  String get premiumFeatureMaxDuration => 'Durée max.';

  @override
  String get premiumFeatureEndLogo => 'Logo de fin officiel';

  @override
  String get premiumFeatureWatermark => 'Filigrane';

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
  String get premiumValueRemovable => 'Amovible';

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
  String get toolbarItemPen => 'Plume G';

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
  String get toolbarItemTransform => 'Transformation';

  @override
  String get toolbarItemText => 'Texte';

  @override
  String get toolbarItemShape => 'Forme';

  @override
  String get workspaceScreenTitle => 'Réglages de l\'espace de travail';

  @override
  String get workspaceToolbarEditSection => 'Édition de la barre d\'outils';

  @override
  String get workspaceToolbarEditHint =>
      'Sélectionnez les outils à afficher avec les cases à cocher, et glissez-déposez pour les réorganiser.';

  @override
  String get workspaceToolbarPcOnlyHint =>
      'Affiché dans la barre d\'outils uniquement en orientation paysage';

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
  String get workspaceLeftHandedSubtitlePc => 'Placer les panneaux à droite';

  @override
  String get workspaceLeftHandedSubtitleMobile =>
      'Disponible uniquement en mode PC/DeX';

  @override
  String get workspacePcModeSection => 'Mode PC (DeX)';

  @override
  String get workspacePcModeHint =>
      'Sur les écrans larges, l\'application passe automatiquement à la disposition professionnelle avec les panneaux fixés en place. Réglez-le manuellement ici pour le forcer.';

  @override
  String get workspacePcModeAuto =>
      'Automatique (selon la largeur de l\'écran, recommandé)';

  @override
  String get workspacePcModeAlwaysPc => 'Toujours en mode PC';

  @override
  String get workspacePcModeAlwaysMobile => 'Toujours en mode mobile';

  @override
  String get workspaceSaveSection => 'Enregistrer l\'espace de travail';

  @override
  String get workspaceSaveHint =>
      'Enregistrez vos réglages de mode gaucher, mode PC, barre d\'outils et outils rapides sous un nom afin de pouvoir les recharger plus tard.';

  @override
  String get workspaceLoadButton => 'Charger un espace de travail';

  @override
  String get workspaceEmptyToolbar => 'Aucun outil à afficher';

  @override
  String get workspaceSaveDialogTitle => 'Enregistrer l\'espace de travail';

  @override
  String get workspaceSaveDialogLabel =>
      'Nom (ex. : Animation, Dessin au trait)';

  @override
  String get workspaceLoadRightHanded => 'Droitier';

  @override
  String get workspaceLoadLeftHanded => 'Gaucher';

  @override
  String get helpScreenTitle => 'Aide';

  @override
  String get helpSearchHint => 'Rechercher...';

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
      'L\'outil de base pour dessiner des lignes sur le canevas. Un appui long permet de changer le type, la taille et la couleur du pinceau (un double appui affiche un résumé rapide). Il prend en charge la pression et l\'inclinaison des tablettes/stylets, et ajuster la courbe de pression dans Réglages > Saisie au stylet permet de personnaliser finement la façon dont la pression influence la taille et l\'opacité. En changeant de sous-outil de plume, vous pouvez appliquer des trames ou placer des tampons avec le même outil.';

  @override
  String get helpEraserToolTitle => 'Outil gomme';

  @override
  String get helpEraserToolDesc =>
      'L\'équivalent de l\'outil plume, utilisé pour effacer ce que vous avez dessiné. Comme un pinceau, vous pouvez ajuster sa taille et son opacité, et les réglages de pinceau comme le fondu et l\'atténuation de trait s\'y appliquent aussi. Plutôt que d\'« ajouter » aux parties transparentes d\'un calque, il « retire » le dessin existant, si bien que le calque en dessous devient visible à travers.';

  @override
  String get helpBucketToolTitle => 'Outil pot de peinture';

  @override
  String get helpBucketToolDesc =>
      'Remplit une zone fermée en une seule fois. Appuyez à l\'intérieur d\'une zone entourée par un trait et toute la zone est remplie avec la couleur (ou la trame) sélectionnée. S\'il y a des espaces dans le trait, le remplissage peut déborder sur des zones non voulues ; assurez-vous donc que le trait est bien fermé avant de l\'utiliser. Vous pouvez basculer entre remplissage uni et remplissage en trame dans les réglages. Les réglages détaillés (tolérance, extension en px, passer sous les traits) sont accessibles depuis « Pot de peinture » dans les réglages.';

  @override
  String get helpLassoFillTitle => 'Remplissage lasso';

  @override
  String get helpLassoFillDesc =>
      'Tracez avec votre doigt pour former une zone polygonale, puis remplissez l\'intérieur en une seule fois. Contrairement au pot de peinture, vous pouvez définir la zone vous-même même là où le trait n\'est pas fermé, ce qui le rend idéal pour les formes complexes ou les zones avec des lignes interrompues.';

  @override
  String get helpEyedropperToolTitle => 'Outil pipette';

  @override
  String get helpEyedropperToolDesc =>
      'Prélève la couleur à l\'endroit où vous appuyez et la définit comme couleur de dessin. Il échantillonne le rendu composité de tous les calques tel qu\'affiché à l\'écran, ce qui permet de récupérer précisément la « couleur telle que vue » même là où plusieurs calques se superposent.';

  @override
  String get helpSelectToolTitle => 'Outil de sélection';

  @override
  String get helpSelectToolDesc =>
      'Sélectionne une partie du canevas afin de pouvoir déplacer, faire pivoter ou redimensionner uniquement cette zone. Un appui long permet de choisir parmi trois méthodes de sélection : « Sélection rectangulaire », « Sélection au lasso » (contour libre), ou « Sélection automatique » (baguette magique — regroupe automatiquement les zones de couleur similaire). Pendant une sélection, un contour marque la zone sélectionnée sur le canevas, et la même zone reste fixée sur toutes les images et tous les calques jusqu\'à ce que vous désélectionniez.';

  @override
  String get helpFingerToolTitle => 'Outil doigt (déformation)';

  @override
  String get helpFingerToolDesc =>
      'Déforme les pixels en les poussant dans la direction où vous faites glisser votre doigt, comme si vous étaliez de la peinture humide avec un doigt. Il sert moins aux corrections précises qu\'à déformer de manière organique des lignes déjà dessinées pour leur donner plus d\'expression.';

  @override
  String get helpShapeToolTitle => 'Outil forme';

  @override
  String get helpShapeToolDesc =>
      'Dessine des formes précises comme des lignes, des rectangles et des cercles en un seul geste. Faire glisser du point de départ au point d\'arrivée affiche un aperçu en direct, et la forme est finalisée lorsque vous relâchez le doigt. Pratique lorsque vous avez besoin de lignes droites ou de cercles parfaits difficiles à réaliser à main levée.';

  @override
  String get helpTextToolTitle => 'Outil texte';

  @override
  String get helpTextToolDesc =>
      'Place du texte sur le canevas. Vous pouvez choisir la police, la taille, la couleur et le sens d\'écriture vertical/horizontal. L\'écriture verticale prend en charge la rotation automatique des caractères alphanumériques demi-chasse, le tate-chu-yoko (garder les nombres à l\'horizontale dans un texte vertical) et le rubi (furigana). Le texte placé est également gravé en pixels lors de l\'export. Un écran où vous pouvez ajouter, rechercher et supprimer des polices disponibles dans l\'outil texte. Les polices gratuites supplémentaires au-delà de celles fournies par défaut sont téléchargées à la demande depuis ici, afin de réduire la taille d\'installation initiale.';

  @override
  String get helpQuickToolTitle => 'Outil rapide';

  @override
  String get helpQuickToolDesc =>
      'Enregistrez des combinaisons de pinceaux et d\'outils que vous utilisez souvent, et faites défiler entre elles d\'une simple pression sur un bouton. Faites un appui long ou balayez vers le haut sur le bouton ↺ du canevas pour ouvrir une fenêtre de gestion où ajouter, réorganiser et supprimer des entrées. Faites glisser pour changer leur ordre.';

  @override
  String get helpLayerTitle => 'Calques';

  @override
  String get helpLayerDesc =>
      'Un système qui permet de dessiner sur un même canevas réparti en plusieurs « calques » transparents. En dessinant l\'encrage, la coloration et les arrière-plans sur des calques séparés, vous pouvez refaire uniquement la coloration plus tard ou changer l\'arrière-plan sans effacer l\'encrage. Les calques empilés plus haut apparaissent devant à l\'écran. Chaque ligne de calque dispose de boutons en un geste pour le supprimer ou le fusionner avec le calque du dessous, et un bouton en haut du panneau des calques permet de fusionner tous les calques visibles à la fois.';

  @override
  String get helpBlendModeTitle => 'Mode de fusion';

  @override
  String get helpBlendModeDesc =>
      'Modifie la facon dont un calque se combine avec les calques en dessous. Souvent utilise pour superposer des trames ou des effets de couleur.\nNormal : superpose tel quel.\nProduit : assombrit en multipliant avec le calque du dessous. Le choix classique pour les ombres.\nSuperposition (Ecran) : eclaircit en ajoutant de la lumiere. Bon pour les effets lumineux.\nIncrustation : assombrit les zones sombres et eclaircit les zones claires, augmentant le contraste.\nAddition : additionne simplement les couleurs. Bon pour les traits de lumiere.\nSoustraction : soustrait les couleurs, donnant un aspect sombre et etouffe.\nAssombrir : conserve la couleur la plus sombre entre les deux calques.\nEclaircir : conserve la couleur la plus claire entre les deux calques.\nDensite couleur -: assombrit et sature la couleur du dessous.\nDensite couleur +: eclaircit et sature la couleur du dessous.\nLumiere crue : une version plus intense du contraste d\'Incrustation.\nLumiere douce : une version plus douce du contraste d\'Incrustation. Bonne pour des ombrages doux.\nDifference : affiche la difference entre les deux couleurs. Utile pour verifier un decalage de couleur.\nTeinte / Saturation / Couleur / Luminosite : applique uniquement cette propriete (teinte, saturation, couleur ou luminosite) de ce calque sur celui du dessous.';

  @override
  String get helpClippingTitle => 'Écrêtage';

  @override
  String get helpClippingDesc =>
      'Restreint le dessin aux seuls pixels opaques du calque directement en dessous. Lorsque vous voulez colorer sans dépasser du trait, activer l\'écrêtage sur un calque de coloriage placé au-dessus d\'un calque de trait supprime le risque de dessiner accidentellement en dehors des lignes.';

  @override
  String get helpCommonLayerTitle => 'Calque commun';

  @override
  String get helpCommonLayerDesc =>
      'Les calques ordinaires sont indépendants par image, mais un calque commun partage le même contenu sur plusieurs images et scènes. Les éléments qui ne bougent pas d\'une image à l\'autre, comme les fonds, peuvent être dessinés une seule fois au lieu d\'être redessinés à chaque image. Il apparaît comme une piste dédiée dans la chronologie. Convertit un calque normal en calque commun (qui continue d\'afficher le même contenu sur plusieurs images). Vous pouvez aussi fusionner les calques actuellement visibles en un seul avant la conversion. Vous évite de redessiner un élément comme un arrière-plan qui reste identique à chaque image.';

  @override
  String get helpAutoFillTitle => 'Coloriage automatique';

  @override
  String get helpAutoFillDesc =>
      'Crée un calque de coloriage automatique sous le calque de trait pour coloriage automatique et le colore automatiquement selon un « réglage de coloriage automatique » préétabli (une combinaison de couleurs et de trames par partie). Comme vous pouvez tout colorer en une fois après avoir terminé le trait, cela réduit considérablement l’effort de coloriage dans une animation dessinée à la main où le même personnage est dessiné à répétition. Si vous redessinez le trait, une marque de mise à jour (❗) apparaît sur la chronologie et le panneau de calques pour vous indiquer que le coloriage automatique doit être réappliqué. Choisir « Exécuter le remplissage automatique » dans le menu à trois points de l’écran timeline recalcule d’un coup tous les calques de remplissage automatique marqués de l’indicateur de mise à jour (❗). Vous évite de le relancer calque par calque dans le panneau des calques après avoir retracé le trait. Chaque partie d’un réglage de remplissage automatique a un réglage pour la gestion de la couleur du trait — une couleur spécifiée, identique à la couleur de remplissage, ou calque de couleur. Choisir le calque de couleur décale la teinte du trait pour correspondre à la couleur de remplissage, afin que le trait ne ressorte pas et se fonde naturellement. À mesure que les réglages s’accumulent, la liste affichée lors de l’attribution des parties s’allonge et devient difficile à parcourir. Depuis les réglages du projet (ou la boîte de dialogue d’attribution des parties dans le panneau des calques), vous pouvez la limiter aux seuls réglages utilisés dans ce projet, gardant la liste claire et facile à choisir.';

  @override
  String get helpOnionSkinTitle => 'Papier calque';

  @override
  String get helpOnionSkinDesc =>
      'Superpose en semi-transparence les images avant et après celle que vous éditez actuellement, afin que vous puissiez dessiner en vérifiant comment le mouvement s\'enchaîne. Vous pouvez ajuster le nombre d\'images affichées (avant et après) ainsi que leur couleur et leur opacité dans les réglages de performance.';

  @override
  String get helpRulerTitle => 'Règle';

  @override
  String get helpRulerDesc =>
      'Un guide pour dessiner des lignes précises difficiles à réaliser à main levée, y compris des règles droites, circulaires, elliptiques et de perspective (utilisant des points de fuite pour le dessin en perspective). La pointe du stylet s\'aligne automatiquement sur la règle placée, rendant même les compositions avec une profondeur difficile plus faciles à dessiner que sans règle. Les règles peuvent être déplacées, pivotées et redimensionnées à l\'aide de leurs poignées.';

  @override
  String get helpFadeTitle => 'Fondu';

  @override
  String get helpFadeDesc =>
      'Un réglage de pinceau où l\'opacité et l\'épaisseur diminuent progressivement à mesure que vous continuez un trait. Utilisez-le lorsque vous voulez que la fin d\'une ligne s\'estompe, ou pour créer une sensation de dessin avec un effet persistant.';

  @override
  String get helpStrokeDecayTitle => 'Atténuation de trait';

  @override
  String get helpStrokeDecayDesc =>
      'Similaire au fondu, mais plus proche de l\'effet d\'un « encre qui s\'épuise » — la couleur s\'estompe ou devient irrégulière plus vous continuez à dessiner. Il reproduit la texture d\'un pinceau ou d\'un marqueur qui manque d\'encre à mesure que vous l\'utilisez.';

  @override
  String get helpColorMixingTitle => 'Mélange de couleurs';

  @override
  String get helpColorMixingDesc =>
      'En peignant avec un pinceau, mélange la couleur déjà présente sous le pinceau avec la couleur que vous êtes sur le point d\'appliquer. Utilisez-le lorsque vous voulez que de nouvelles couleurs se fondent dans les couleurs existantes, comme à l\'aquarelle ou à l\'huile.';

  @override
  String get helpPressureCurveTitle => 'Courbe de pression';

  @override
  String get helpPressureCurveDesc =>
      'Une fonctionnalité des réglages de saisie au stylet qui permet d\'ajuster librement, via un graphique, la relation entre la pression réelle du stylet et son effet sur la taille et l\'opacité du pinceau. Que vous vouliez des lignes épaisses même avec une légère pression, ou l\'inverse — nécessitant une pression ferme pour obtenir des lignes épaisses —, vous pouvez personnaliser finement la sensation pour l\'adapter à vos habitudes. Vous pouvez essayer de dessiner directement pour vérifier l\'effet après avoir modifié les réglages.';

  @override
  String get helpTimelineTitle => 'Chronologie';

  @override
  String get helpTimelineDesc =>
      'L\'écran de gestion de l\'axe temporel de votre animation. Organiser des images (des images fixes individuelles) et les lire comme un folioscope crée l\'animation. Les pistes de matériaux image, vidéo et audio, les pistes de calques communs et les images clés de caméra sont tous gérés sur la même chronologie.';

  @override
  String get helpSceneTitle => 'Scène';

  @override
  String get helpSceneDesc =>
      'Divise l\'intérieur d\'un projet (une vidéo) en scènes (plans) pour les gérer séparément. Alors que les dossiers organisent au niveau du projet, les scènes représentent des changements de scène au sein d\'une même vidéo. Dans l\'onglet des scènes de la timeline, vous pouvez ajouter, dupliquer, supprimer, renommer et réorganiser les scènes. Passer en mode de sélection multiple permet de déplacer, dupliquer ou supprimer plusieurs scènes à la fois.';

  @override
  String get helpCameraKeyframeTitle => 'Image clé de caméra';

  @override
  String get helpCameraKeyframeDesc =>
      'Enregistre la position, le niveau de zoom et la rotation de la caméra à un point précis de la chronologie. Comme les valeurs sont automatiquement interpolées en douceur entre les images clés, vous pouvez facilement ajouter des mouvements de caméra tels que des panoramiques ou des zooms avant/arrière.';

  @override
  String get helpEffectFilterTitle => 'Filtre d\'effet';

  @override
  String get helpEffectFilterDesc =>
      'Un effet visuel (flou, correction des couleurs, lueur, pixellisation, etc.) que vous pouvez appliquer à une scène ou une image. Utilisez-le lorsque vous voulez ajuster l\'apparence globale de l\'écran comme une touche de mise en scène, sans changer le dessin fait main lui-même. La pixellisation permet aussi de choisir un mode de couleur (sans limite, couleurs spécifiées, nombre de couleurs spécifié, ou choix depuis une palette). Plusieurs filtres d\'effet peuvent être superposés, et ils s\'appliquent dans l\'ordre où ils apparaissent sur la timeline. Glisser pour réorganiser la liste des filtres change aussi l\'ordre réellement appliqué à l\'écran. Un filtre d\'effet qui applique un bruit façon grain de pellicule, en le faisant changer image par image. Intensité, quantité (densité du bruit) et taille du grain se règlent avec des curseurs. Revenir à la même image reproduit le même grain (pas de scintillement en scrubbing), tandis que la lecture donne l\'impression que le grain bouge. Un filtre d\'effet qui fait tomber de la pluie à l\'écran. Intensité (nombre de gouttes), vitesse, taille des gouttes et angle du vent se règlent avec des curseurs. Chaque goutte continue de tomber à une vitesse constante à mesure que l\'image avance, pour un mouvement de pluie naturel.';

  @override
  String get helpEndCardTitle => 'EndCard (logo de fin)';

  @override
  String get helpEndCardDesc =>
      'Une courte vidéo (environ 5 secondes) avec le logo NIARIM, ajoutée automatiquement à la fin du contenu principal lors de l\'export d\'une vidéo. La version gratuite ne peut pas le masquer ni le supprimer, mais les membres Premium peuvent l\'activer/le désactiver, changer sa durée ou le remplacer.';

  @override
  String get helpAutoSaveTitle => 'Enregistrement automatique';

  @override
  String get helpAutoSaveDesc =>
      'Un enregistrement dédié à la récupération en cas de plantage ou de corruption de fichier. Il s\'enregistre automatiquement à chaque modification, comme le dessin, et écrase le plus ancien des 3 enregistrements maximum. Il est géré complètement séparément des enregistrements manuels (emplacements de sauvegarde et arbre de sauvegarde) et ne remplace pas l\'enregistrement habituel. On ne vous demande de le restaurer que lors du redémarrage de l\'application après une fermeture anormale.';

  @override
  String get helpSaveSlotTitle => 'Emplacement de sauvegarde';

  @override
  String get helpSaveSlotDesc =>
      'Une méthode d\'enregistrement dans un nombre fixe d\'emplacements de sauvegarde, où vous choisissez à chaque fois l\'emplacement à utiliser. Le nombre d\'emplacements est déterminé par les réglages (5 pour la qualité basse, 10 pour la qualité moyenne). Comme vous choisissez à chaque fois l\'emplacement à écraser, c\'est un moyen simple de gérer la conservation de l\'état d\'un moment particulier.';

  @override
  String get helpSaveTreeTitle => 'Arbre de sauvegarde';

  @override
  String get helpSaveTreeDesc =>
      'Une méthode d\'enregistrement où un nouveau point de sauvegarde est créé à chaque fois que vous enregistrez, et vous pouvez créer une branche à partir d\'un point de sauvegarde passé pour créer un historique différent. Il n\'y a pas de limite au nombre d\'enregistrements, ce qui le rend bien adapté à des cas d\'usage comme « je veux revenir à cette version et essayer une direction différente ». À l\'écran, les points de sauvegarde sont affichés sous forme d\'un diagramme en arbre qui pousse du bas vers le haut.';

  @override
  String get helpFolderTitle => 'Dossier';

  @override
  String get helpFolderDesc =>
      'Une fonctionnalité pour regrouper et organiser vos projets (œuvres). Elle prend en charge plusieurs niveaux d\'imbrication, vous pouvez donc aussi l\'utiliser pour gérer ensemble plusieurs épisodes ou une série de la même œuvre (par exemple, en organisant les projets « Épisode 1 », « Épisode 2 », etc. dans un dossier nommé d\'après l\'œuvre). Si vous voulez diviser une seule vidéo en scènes distinctes, utilisez la fonctionnalité « Scène » de l\'écran du canevas plutôt que des dossiers.';

  @override
  String get helpTrashTitle => 'Corbeille';

  @override
  String get helpTrashDesc =>
      'L\'endroit où les projets supprimés sont temporairement déplacés. Vous pouvez les restaurer d\'ici jusqu\'à ce qu\'ils soient définitivement supprimés. Vous pouvez définir le nombre de jours avant la suppression automatique (désactivé/30/60/90 jours) dans les réglages.';

  @override
  String get helpShareTitle => 'Partage (.niashare)';

  @override
  String get helpShareDesc =>
      'Un format de fichier dédié pour remettre un projet à quelqu\'un d\'autre (ou à un autre appareil de vous-même). Lorsque le destinataire ouvre ce fichier, il est dupliqué et ajouté à sa propre liste de projets. Le fichier .niashare d\'origine lui-même n\'est pas modifié.';

  @override
  String get helpTransferTitle => 'Transfert (.niatra)';

  @override
  String get helpTransferDesc =>
      'Une fonctionnalité permettant de transférer tout l’environnement de l’application — réglages, matériaux, pinceaux, réglages de remplissage automatique, thème, palettes (sélecteur de couleurs et pixel art), et plus — vers un autre appareil en une seule fois. Vous pouvez choisir les éléments individuels à transférer avec des cases à cocher. Si vous voulez remettre un projet individuel, utilisez plutôt « Partage (.niashare) ».';

  @override
  String get helpVideoExportTitle => 'Export vidéo (MP4, WebM, GIF)';

  @override
  String get helpVideoExportDesc =>
      'Exporte votre oeuvre au format video MP4 standard. La version gratuite a une limite de duree (90 secondes) et ajoute automatiquement une carte de fin (logo de l\'application) a la fin de la video. Un format vidéo qui peut être exporté en conservant le canal alpha (les parties transparentes du fond). La lecture transparente ne fonctionne que dans les environnements de lecture compatibles. Idéal pour superposer comme matériau dans d\'autres applications. Exporte au format GIF anime. Comme il boucle automatiquement, il convient bien au partage decontracte sur les reseaux sociaux. Si la compatibilité prime, vous pouvez aussi exporter au format AVI (Motion JPEG). Il utilise un codec choisi pour sa sécurité en matière de brevets et de licences, mais ne prend pas en charge le canal alpha (transparence), et l\'aperçu dans l\'application peut ne pas fonctionner sur tous les appareils (vous pouvez tout de même le lire via un lecteur externe depuis Partager). Les comptes gratuits sont limités à 90 secondes de durée de projet (les comptes Premium ont 2 heures). Si ajouter ou dupliquer des images vous ferait dépasser la limite, une alerte apparaît dès que vous appuyez sur le bouton, donc vous ne dépassez jamais réellement 90 secondes.';

  @override
  String get helpTransparentWebmTitle => 'WebM transparent';

  @override
  String get helpCommunityTitle => 'Place des œuvres';

  @override
  String get helpCommunityDesc =>
      'Publiez vos animations et illustrations dans la communauté sous forme de vidéos YouTube, et parcourez les œuvres des autres utilisateurs. Basculez entre les onglets « Nouveautés », « Classement » et « Abonnements », et effectuez une recherche par titre d’œuvre ou nom du créateur. Passez en mode recherche par tag pour filtrer les œuvres par tag : n’importe quel utilisateur (pas seulement le créateur) peut ajouter ou retirer des tags, mais un tag verrouillé par le créateur ne peut être retiré que par lui, et toucher un tag filtre instantanément les œuvres correspondantes. Toucher une carte d’œuvre ouvre une fenêtre d’aperçu flottante déplaçable et redimensionnable, pour continuer à naviguer sur d’autres écrans pendant la lecture. Le bouton « Voir les détails » ouvre l’écran de détails de l’œuvre (créateur, date de publication, modification des tags, mise en favori, republication, etc.). Toucher le bouton « Suivre » à côté du nom d’un créateur l’ajoute à vos abonnements : l’onglet « Abonnements » regroupe alors uniquement les publications de ce créateur, triées par date. Lorsque quelqu’un vous suit, cela apparaît dans la liste de notifications sous l’icône de cloche en haut de l’écran. Vous pouvez choisir si vos listes d’abonnements/abonnés sont visibles par les autres utilisateurs (privées par défaut), et consulter les listes des autres utilisateurs si elles sont publiques. Vous pouvez repartager l’œuvre de n’importe qui d’autre (sauf la vôtre) avec le bouton « Repartager » ; lorsqu’un créateur que vous suivez repartage l’œuvre de quelqu’un d’autre, cette œuvre apparaît aussi dans votre onglet « Abonnements », triée selon la date la plus récente — sa date de publication d’origine ou sa date de republication (la carte affiche « Repartagé par… »). Les œuvres mises en favori apparaissent regroupées dans l’onglet « Favoris » de l’écran d’accueil, ainsi que dans l’onglet « Favoris » de l’écran des œuvres d’un créateur. Vous pouvez choisir si votre propre liste de favoris est visible par les autres utilisateurs (privée par défaut), et consulter la liste de favoris des autres utilisateurs si elle est rendue publique. Vous pouvez signaler une œuvre en indiquant un motif, et après l’envoi, il vous sera demandé si vous souhaitez bloquer ce créateur. Les vidéos verticales peuvent être visionnées en « mode vertical », qui les enchaîne comme un flux de vidéos courtes. Le nombre de publications par jour est limité : 1 par jour pour les membres gratuits, 3 par jour pour les membres Premium.';

  @override
  String get helpWatermarkEntryTitle => 'Filigrane';

  @override
  String get helpWatermarkEntryDesc =>
      'Une fonctionnalité réservée aux membres premium qui permet d\'ajouter votre propre signature ou logo en filigrane sur les vidéos et images exportées. Vous pouvez ajuster sa position, sa taille et son opacité. Touchez le filigrane placé sur la piste de calque commun de la timeline pour modifier à tout moment son angle, sa taille, son opacité et sa plage d\'affichage (bouclage) — pas seulement lors de son enregistrement, mais chaque fois que vous l\'utilisez dans un projet.';

  @override
  String get helpPremiumEntryTitle => 'Premium';

  @override
  String get helpPremiumEntryDesc =>
      'L\'abonnement premium porte a 2 heures maximum la limite de 90 secondes de la version gratuite et permet de retirer la carte de fin (logo de l\'application) ajoutee automatiquement a la fin de chaque video. Les publicites sont egalement masquees, et vous accedez au filigrane, a la courbe de tons et a la correction des niveaux.';

  @override
  String get helpPerformanceSettingsTitle => 'Réglages de performance';

  @override
  String get helpPerformanceSettingsDesc =>
      'Choisissez parmi les préréglages de qualité basse, moyenne ou haute selon les capacités de votre appareil, ou configurez chaque élément individuellement (personnalisé). En plus de la méthode d\'enregistrement, des performances, du papier calque et de la détection d\'inclinaison, les réglages qui affectent la taille de l\'application et sa fluidité — comme la longueur de l\'historique d\'annulation et la suppression automatique de la corbeille — sont également regroupés ici.';

  @override
  String get helpMaterialClipTitle =>
      'Clips de matériel (image / vidéo / audio)';

  @override
  String get helpMaterialClipDesc =>
      'Clips placés sur les pistes image, vidéo et audio de la timeline. Un appui long avec glisser sur le corps du clip déplace sa position de départ, et glisser les poignées à chaque extrémité change la portion utilisée. Toucher un clip ouvre sa fiche détaillée, où l\'icône de copie le duplique et l\'icône de corbeille le supprime. Les clips image et vidéo sont gérés en interne comme des calques, tandis que l\'audio est géré comme un clip rattaché directement à la scène.';

  @override
  String get helpGestureSettingsTitle => 'Réglages des gestes';

  @override
  String get helpGestureSettingsDesc =>
      'Permet d\'associer des actions — annuler/rétablir, déplacement de fotogramme, pipette et plus — à un appui à deux doigts, un appui à trois doigts, un glissement à deux doigts ou un appui long. Les boutons du stylet (sur les modèles compatibles) peuvent aussi être associés séparément. Pratique pour déclencher des actions fréquentes d\'un seul geste sans changer d\'outil.';

  @override
  String get helpBucketDetailSettingsTitle =>
      'Réglages détaillés du seau de peinture';

  @override
  String get helpBucketDetailSettingsDesc =>
      'Depuis la section « Seau de peinture » des réglages, vous pouvez ajuster la tolérance (quelle différence de couleur par rapport au pixel cliqué compte encore comme la même zone), l\'extension en px (de combien la zone remplie dépasse la bordure pour combler les écarts du trait) et le remplissage sous le trait (compose le remplissage étendu derrière les pixels existants au lieu de peindre par-dessus le trait, préservant son apparence). Les ajuster aide quand le trait a de petits écarts ou que le remplissage semble incomplet.';

  @override
  String get helpStampToolTitle => 'Outil tampon';

  @override
  String get helpStampToolDesc =>
      'Place une image préenregistrée sur le canevas comme un pinceau. Réutilisez traits de vitesse, motifs de fond et petits objets sans les redessiner à chaque fois. Avec le mode pixel activé, les images tamponnées sont traitées avec un sous-échantillonnage en mosaïque et une réduction des couleurs, pour un rendu pixel art. Le panneau des tampons permet d\'ajuster l\'angle de rotation et la taille du tampon placé. Varier l\'orientation et la taille d\'un même tampon évite que les traits de vitesse et petits objets paraissent monotones.';

  @override
  String get helpToneFillTitle => 'Remplissage en trame';

  @override
  String get helpToneFillDesc =>
      'Passer le réglage de l\'outil seau du remplissage uni au remplissage en trame permet de remplir avec une trame de demi-teintes ou de lignes choisie. Des trames en damier et en grille réservées au mode pixel sont aussi disponibles, pour des remplissages assortis à une texture pixel art.';

  @override
  String get helpPixelModeTitle => 'Mode pixel';

  @override
  String get helpPixelModeDesc =>
      'Un réglage disponible séparément sur les pinceaux, les polices et les tampons. L\'activer supprime l\'anticrénelage pour des contours nets façon pixel art. À utiliser pour un rendu volontairement rétro ou basse résolution. Vous pouvez choisir parmi quatre modes de couleur : sans limite de couleur, couleurs spécifiées, nombre de couleurs spécifié, ou choix depuis une palette, y compris une palette dédiée au pixel art.';

  @override
  String get helpHomeScreenTitle => 'Écran d\'accueil';

  @override
  String get helpHomeScreenDesc =>
      'Le premier écran affiché au lancement de l\'app, avec les onglets Projets, Partagés, Œuvres et Corbeille. L\'icône de recherche en haut à droite permet de filtrer les projets par nom. Sur l\'onglet Projets, le bouton flottant permet de choisir entre créer un nouveau projet ou un nouveau dossier.';

  @override
  String get helpNewProjectTitle => 'Nouveau projet';

  @override
  String get helpNewProjectDesc =>
      'Définissez la taille du canevas, les fps, la durée (en secondes — ensuite maintenue synchronisée avec les changements d’images faits dans la timeline), la zone de dessin (permet de dessiner au-delà des limites d’export) et les réglages de remplissage automatique à utiliser, le tout avant de créer le projet.';

  @override
  String get helpThemeSettingsTitle => 'Réglages de thème';

  @override
  String get helpThemeSettingsDesc =>
      'Choisissez la palette de couleurs globale de l\'app dans la liste des thèmes, ou personnalisez librement la couleur d\'accent. Les titres/libellés et le texte courant utilisent des polices distinctes, ce qui permet de changer l\'apparence de l\'app tout en gardant une bonne lisibilité.';

  @override
  String get helpWorkspaceSettingsTitle => 'Réglages de l\'espace de travail';

  @override
  String get helpWorkspaceSettingsDesc =>
      'Regroupe des réglages comme le mode gaucher (inverse les panneaux ancrés), le basculement manuel du mode PC/DeX, et les conditions d\'affichage de l\'outil main. Ajustez la disposition selon votre appareil et votre main dominante.';

  @override
  String get helpPenSettingsTitle => 'Réglages du stylet';

  @override
  String get helpPenSettingsDesc =>
      'En plus de la courbe de pression pour tablettes et écrans à stylet, cet écran permet d\'associer des actions — comme basculer la gomme ou la pipette — aux boutons latéraux d\'un stylet compatible.';

  @override
  String get helpMaterialListTitle => 'Liste des matériels';

  @override
  String get helpMaterialListDesc =>
      'Un écran qui rassemble les images, vidéos et audios utilisés dans un projet. Il regroupe les fichiers source de tout ce qui est placé sur la timeline.';

  @override
  String get helpFrameOperationsTitle => 'Opérations sur les fotogrammes';

  @override
  String get helpFrameOperationsDesc =>
      'Dans la liste des fotogrammes, vous pouvez ajouter, dupliquer et supprimer des fotogrammes, et en mode sélection multiple en déplacer, dupliquer ou supprimer plusieurs à la fois. Augmenter le nombre de maintien garde un même fotogramme affiché sur plusieurs cellules (un « maintien »), économisant du travail de dessin sur les plans avec peu de mouvement.';

  @override
  String get helpSceneOperationsTitle => 'Opérations sur les scènes';

  @override
  String get helpSceneOperationsDesc =>
      'L\'onglet scènes de la timeline permet d\'ajouter, dupliquer, supprimer, renommer et réorganiser les scènes. Le mode sélection multiple permet de déplacer, dupliquer ou supprimer plusieurs scènes à la fois.';

  @override
  String get helpQuickToolManagementTitle => 'Gestion des outils rapides';

  @override
  String get helpQuickToolManagementDesc =>
      'Enregistrez un ensemble d\'outils fréquemment utilisés pour les faire défiler d\'un seul appui. Ouvrez le popup de gestion par un appui long ou un glissement vers le haut pour modifier les outils enregistrés et leur ordre.';

  @override
  String get helpTransformSelectionTitle => 'Transformer une sélection';

  @override
  String get helpTransformSelectionDesc =>
      'Une zone délimitée avec l\'outil de sélection peut être déplacée, pivotée et redimensionnée avec l\'outil de transformation. Pratique pour repositionner une partie dessinée par erreur, ou pour agrandir une seule zone afin de la mettre en valeur. Pour transformer tout le calque, utilisez la Transformation libre / Déformation maillée (accessible depuis le menu d\'édition) qui ne nécessite pas de sélection et permet de faire glisser individuellement les points de la grille pour un résultat plus libre.';

  @override
  String get helpGradientAutofillTitle =>
      'Remplissage en dégradé (réglages de remplissage automatique)';

  @override
  String get helpGradientAutofillDesc =>
      'Chaque partie d’un réglage de remplissage automatique peut utiliser un dégradé au lieu d’une couleur unie. Des poignées symétriques déplaçables par glisser permettent d’ajuster intuitivement l’étendue et l’angle du dégradé. Chaque partie peut aussi activer « Contour avec une couleur définie ». Une fois coché, un trait de la couleur et de l’épaisseur choisies est dessiné tout au bord extérieur de la zone remplie (juste contre le dessin au trait). La couleur du contour se choisit librement dans le sélecteur de couleur, et l’épaisseur s’ajuste via le curseur, les boutons ± ou en touchant le nombre pour le saisir directement. Un aperçu s’affiche juste au-dessus des réglages, permettant de vérifier la couleur et l’épaisseur avant d’exécuter le remplissage automatique.';

  @override
  String get helpColorPickerTitle => 'Sélecteur de couleur';

  @override
  String get helpColorPickerDesc =>
      'Un selecteur de couleur qui permet de basculer entre HSV et RGB sur un seul ecran. La fonction palette permet d\'enregistrer et de rappeler l\'ensemble de couleurs utilise. Les palettes peuvent aussi être partagées avec d\'autres appareils via l\'export de fichier ou un code QR.';

  @override
  String get helpUndoSettingsTitle => 'Longueur de l\'historique d\'annulation';

  @override
  String get helpUndoSettingsDesc =>
      'Dans les réglages de performance, vous pouvez ajuster le nombre d\'actions que l\'annulation peut remonter. Un nombre plus élevé donne plus de liberté pour expérimenter, mais utilise aussi plus de mémoire — réduisez-le sur les appareils bas de gamme pour rester fluide.';

  @override
  String get helpBrushFavoriteTitle => 'Pinceaux favoris';

  @override
  String get helpBrushFavoriteDesc =>
      'Touchez l’icône étoile d’un pinceau dans la liste pour le mettre en favori ou l’en retirer (la même interaction que pour les favoris dans le reste de l’app — réglages de remplissage automatique, tampons, polices, filtres de dessin, etc.). L’icône étoile en haut de la liste permet aussi de filtrer pour n’afficher que les favoris. Un pinceau en favori ne peut pas être supprimé par erreur.';

  @override
  String get helpCustomBrushTitle => 'Pinceaux personnalisés';

  @override
  String get helpCustomBrushDesc =>
      'Appuyez longuement sur un pinceau préinstallé dans la liste et choisissez « Dupliquer » pour créer votre propre pinceau personnalisé à partir de celui-ci. Les pinceaux dupliqués peuvent être librement modifiés (épaisseur, opacité, dureté, rotation, densité, dispersion, rayon de flou, etc.) et supprimés lorsqu’ils ne sont plus utiles (les pinceaux préinstallés eux-mêmes ne peuvent être ni modifiés ni supprimés). Vous pouvez aussi les classer dans des dossiers et les marquer comme favoris avec l’icône étoile.';

  @override
  String get helpLayerFolderTitle => 'Dossiers de calques';

  @override
  String get helpLayerFolderDesc =>
      'Permet d\'organiser plusieurs calques dans un dossier. Garde le panneau des calques lisible même pour des illustrations avec beaucoup de parties. Le détourage ne peut pas traverser les limites d\'un dossier, donc si vous l\'utilisez, gardez les calques concernés dans le même dossier.';

  @override
  String get helpLayerMultiSelectTitle =>
      'Sélection multiple et actions groupées sur les calques';

  @override
  String get helpLayerMultiSelectDesc =>
      'Le mode de sélection du panneau des calques permet de cocher plusieurs calques à la fois pour les fusionner ou les supprimer en masse. La fusion ne fonctionne qu\'entre calques normaux, de trait de remplissage automatique et de remplissage automatique (les calques communs, dossiers et matériels de timeline ne peuvent pas être fusionnés).';

  @override
  String get helpDrawingAreaTitle => 'Zone de dessin';

  @override
  String get helpDrawingAreaDesc =>
      'Permet de dessiner au-delà des limites d\'export. Un cadre rouge sur le canevas marque la zone d\'export — ce qui est dessiné en dehors n\'est pas exporté, mais cela laisse de la marge pour ajuster plus tard ce qui est montré via des mouvements de caméra comme le panoramique et le zoom. Définissez l\'échelle à la création d\'un nouveau projet.';

  @override
  String get helpCanvasBackgroundTitle => 'Couleur de fond du canevas';

  @override
  String get helpCanvasBackgroundDesc =>
      'Permet de définir la couleur de fond du canevas du projet. Elle n\'affecte pas les exports transparents (WebM transparent), mais vous pouvez la changer pour celle qui vous convient le mieux pour travailler.';

  @override
  String get helpProjectDetailTitle => 'Écran des détails du projet';

  @override
  String get helpProjectDetailDesc =>
      'Un écran pour consulter et modifier au même endroit les réglages propres au projet — nom, miniature, statut favori, et quels réglages de remplissage automatique sont activés. L’accès à l’arbre de sauvegarde se trouve aussi ici.';

  @override
  String get helpWatermarkEditTitle => 'Rééditer un filigrane';

  @override
  String get helpWatermarkEditDesc =>
      'Toucher un filigrane placé sur la piste de calque commun de la timeline permet de rééditer à tout moment son angle, sa taille, son opacité et sa plage d\'affichage (boucle). Vous pouvez l\'ajuster finement non seulement à l\'enregistrement, mais chaque fois que vous l\'utilisez réellement dans un projet.';

  @override
  String get helpAudioClipTitle => 'Volume et fondus des clips audio';

  @override
  String get helpAudioClipDesc =>
      'Un clip audio placé sur la timeline peut avoir son volume et ses durées de fondu d\'entrée et de sortie ajustés depuis sa fiche détaillée. Utile pour équilibrer le volume des effets sonores et de la musique, ou adoucir le début et la fin d\'un morceau.';

  @override
  String get helpPenSubToolTitle => 'Sous-outils du stylet';

  @override
  String get helpPenSubToolDesc =>
      'Un appui long sur l\'outil stylet le fait passer du dessin normal aux sous-outils de remplissage en trame ou de placement de tampon. Permet de passer d\'une tâche à l\'autre avec le même stylet sans changer d\'outil sans arrêt.';

  @override
  String get helpTiltDetectionTitle => 'Détection d\'inclinaison';

  @override
  String get helpTiltDetectionDesc =>
      'Un réglage qui utilise les données d\'inclinaison d\'un stylet compatible pour épaissir ou affiner le trait quand vous couchez la pointe, reproduisant une sensation plus proche d\'un vrai outil de dessin. Activez-le ou désactivez-le depuis les réglages de performance.';

  @override
  String get helpFontImportTitle => 'Import de polices';

  @override
  String get helpFontImportDesc =>
      'Permet de charger un fichier de police directement depuis le stockage de l\'appareil. Ajoutez-le depuis l\'onglet « Importer » de la gestion des polices, dans les réglages. Pratique pour utiliser une police personnalisée non distribuée, ou une police commerciale achetée.';

  @override
  String get helpExportScreenTitle => 'Écran d\'export';

  @override
  String get helpExportScreenDesc =>
      'Affiche la progression pendant l\'export d\'une vidéo ou d\'une image, et permet d\'annuler en cours de route. Le temps nécessaire dépend des performances de l\'appareil.';

  @override
  String get helpDrawingFilterTitle => 'Filtres de dessin';

  @override
  String get helpDrawingFilterDesc =>
      'Filtres appliqués directement au calque sélectionné (contrairement aux filtres d\'effet, qui s\'appliquent à toute la timeline ou à une scène, les filtres de dessin agissent par calque). Comprend flou, netteté, masque flou, courbe de tons, niveaux, vignettage, bruit, anime rétro, tube cathodique, style anime, contour et pixellisation. Le contour ne réécrit pas le calque d\'origine : il dessine seulement le résultat contourné sur un nouveau calque. La pixellisation permet aussi de choisir un mode de couleur (sans limite, couleurs spécifiées, nombre de couleurs spécifié, ou choix depuis une palette).';

  @override
  String get helpLayerKeyframeTitle =>
      'Images clés de calque (animation par partie)';

  @override
  String get helpLayerKeyframeDesc =>
      'Définissez la position, l\'échelle et la rotation de chaque calque par image ; les images clés sont interpolées automatiquement. Là où les images clés de caméra déplacent tout l\'écran, celles-ci ne déplacent qu\'un seul calque. Comme chaque partie du remplissage automatique est générée comme un calque distinct, cela fonctionne directement pour l\'animation par partie — bouger seulement un bras, ouvrir et fermer seulement une bouche, etc. Chaque image clé peut aussi avoir son propre easing (uniforme, entrée douce, sortie douce, entrée et sortie douces, ou rebond) qui détermine comment elle se raccorde à l\'image clé suivante, pour que le mouvement ne soit pas toujours à vitesse constante. Se configure depuis « Animation (images clés) » dans le menu à trois points de chaque calque, dans le panneau des calques. Le dessin du calque lui-même ne change pas : c\'est une transformation non destructive de son emplacement d\'affichage. Cela n\'affecte que l\'affichage de la timeline (aperçu / export) et n\'a aucun effet sur le dessin réel en mode canevas.';

  @override
  String get helpLayerGroupTitle =>
      'Groupes de calques (déplacer plusieurs parties ensemble)';

  @override
  String get helpLayerGroupDesc =>
      'Déplace plusieurs calques ensemble avec un seul flux d\'images clés. Par exemple, si un « bras » est composé de deux parties de remplissage automatique — peau et manche —, les grouper permet de déplacer les deux avec une seule opération d\'image clé. Créez un groupe en sélectionnant plusieurs calques (cases à cocher) dans le panneau des calques puis en appuyant sur l\'icône « Grouper » de la barre inférieure. Le mouvement du groupe se superpose aux images clés propres à chaque calque membre (si elles existent), ce qui permet de combiner le mouvement global du groupe avec des ajustements fins par calque. Un calque ne peut appartenir qu\'à un seul groupe à la fois.';

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
  String get tipsCategoryExport => 'Astuces d\'export et de flux de travail';

  @override
  String get tipsClipDuplicateTitle =>
      'Les clips de la timeline peuvent être dupliqués, déplacés et supprimés';

  @override
  String get tipsClipDuplicateDesc =>
      'Touchez un clip image, vidéo ou audio pour ouvrir sa fiche détaillée, puis utilisez l\'icône de copie pour le dupliquer. Réutiliser le même effet sonore ou replacer la même image dans plusieurs scènes ne demande qu\'un glisser en appui long et un appui sur le bouton de duplication.';

  @override
  String get tipsTextCaptionTitle =>
      'Ajoutez des sous-titres avec l\'outil texte';

  @override
  String get tipsTextCaptionDesc =>
      'Utilisez l\'outil texte pour placer des sous-titres ou des commentaires image par image. Passer la police en mode pixel peut aussi donner au texte un rendu rétro façon ancien jeu vidéo.';

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
      'Le remplissage automatique sert normalement à colorer partie par partie, mais inutile de tout découper soigneusement : l\'utiliser comme une seule couche de base d\'une couleur unie sur tout le trait est déjà bien utile en soi. Il remplit tout l\'intérieur du trait d\'un coup, ce qui évite les oublis de remplissage (les interstices où la couleur du dessous transparaît) fréquents avec le seau manuel. Peignez ensuite vos couleurs à la main par-dessus, et vous profitez du gain sans le travail de découpage par partie.';

  @override
  String get tipsBrushFavoriteTitle =>
      'Mettez vos pinceaux favoris en favori pour les retrouver sans chercher';

  @override
  String get tipsBrushFavoriteDesc =>
      'Touchez l\'icône étoile des pinceaux que vous utilisez le plus pour les mettre en favori. L\'icône étoile en haut de la liste permet de filtrer pour n\'afficher que les favoris, réduisant le temps de recherche. Un pinceau en favori ne peut pas être supprimé par erreur.';

  @override
  String get tipsPressureCurveTitle =>
      'Ajustez la courbe de pression à votre main';

  @override
  String get tipsPressureCurveDesc =>
      'La courbe de pression dans les réglages permet de placer librement jusqu\'à 10 points de contrôle. Si la réponse en intensité ne vous convient pas, ajustez-la selon vos propres habitudes de pression.';

  @override
  String get tipsExportFormatTitle =>
      'Choisissez le format d\'export selon l\'usage';

  @override
  String get tipsExportFormatDesc =>
      'Le GIF convient pour publier facilement sur les réseaux sociaux, le WebM transparent pour superposer sur une autre vidéo ou garder un fond transparent, et le MP4 pour un usage vidéo classique. Choisir selon l\'usage facilite l\'équilibre entre taille de fichier et qualité.';

  @override
  String get tipsGestureShortcutTitle =>
      'Associez un geste aux actions fréquentes';

  @override
  String get tipsGestureShortcutDesc =>
      'Depuis « Gestes » dans les réglages, vous pouvez associer annuler/rétablir ou la pipette à un appui à deux doigts, un appui à trois doigts ou un appui long. Comme vous n\'avez pas à changer d\'outil, cela ne casse pas le rythme du dessin.';

  @override
  String get tipsAudioRepeatTitle =>
      'Gardez vos bruitages en rythme avec des clips dupliqués + fondus';

  @override
  String get tipsAudioRepeatDesc =>
      'Pour réutiliser plusieurs fois le même bruitage, dupliquez le clip et alignez les copies à des moments décalés, en donnant à chacune son propre fondu d\'entrée/sortie. Vous obtenez ainsi une répétition naturelle et rythmée de l\'effet.';

  @override
  String get tipsVerticalRubyTitle =>
      'Texte vertical + furigana pour un look de logo de titre';

  @override
  String get tipsVerticalRubyDesc =>
      'Combiner l\'écriture verticale avec les furigana dans l\'outil texte donne un logo de titre à la japonaise ou un traitement de titre distinctif. Les alphanumériques demi-chasse pivotent automatiquement pour se placer sur le côté, restant lisibles même mélangés à des symboles ou des chiffres.';

  @override
  String get tipsBrushTrySaveTreeTitle =>
      'Testez de nouveaux réglages de pinceau via l\'arbre de sauvegarde';

  @override
  String get tipsBrushTrySaveTreeDesc =>
      'Avant un gros changement d\'épaisseur ou de stabilisation du pinceau, sauvegardez d\'abord dans l\'arbre de sauvegarde pour plus de sérénité. Si le résultat ne vous plaît pas, vous pouvez revenir directement à l\'état précédent, ce qui facilite les essais audacieux.';

  @override
  String get tipsEyedropperGestureTitle =>
      'Associez la pipette à un appui à deux doigts pour garder une palette cohérente';

  @override
  String get tipsEyedropperGestureDesc =>
      'Associer la pipette à un appui à deux doigts dans les réglages de gestes permet de récupérer instantanément une couleur voisine sans changer d\'outil. Pratique pour colorer en restant fidèle à la palette d\'un personnage.';

  @override
  String get tipsRulerOnionTitle =>
      'Règle de perspective + papier calque pour réutiliser un fond';

  @override
  String get tipsRulerOnionDesc =>
      'Posez la profondeur d\'un fond avec la règle de perspective, puis ne déplacez que le personnage en vérifiant les images voisines via le papier calque — plus besoin de redessiner le fond à chaque image.';

  @override
  String get tipsGradientTraceTitle =>
      'Remplissage automatique en dégradé + calque de couleur pour un fondu naturel';

  @override
  String get tipsGradientTraceDesc =>
      'En utilisant un dégradé dans un réglage de remplissage automatique, réglez le mode de couleur du trait sur calque de couleur pour que la couleur du trait suive les subtils changements du dégradé, évitant que la limite ne ressorte.';

  @override
  String get tipsGradientOutlineHairTitle =>
      'Dégradé × contour de couleur définie pour des cheveux translucides';

  @override
  String get tipsGradientOutlineHairDesc =>
      'Créez une partie « frange » dans votre réglage de remplissage automatique et réglez le remplissage sur un dégradé avec la couleur des cheveux et le transparent comme deux couleurs. Réglez l’angle sur 90°, ajustez l’intensité du flou et la position de transition des couleurs à votre goût, puis cochez « Contour avec une couleur définie » et choisissez la couleur du contour dans « Couleurs récemment utilisées », en sélectionnant la même couleur que celle utilisée pour la frange. Répétez les mêmes étapes pour la partie couleur d’ombre en plus de la partie de base, pour des cheveux à l’aspect translucide.';

  @override
  String get tipsRainNoiseTitle =>
      'Pluie + bruit animé pour une atmosphère humide';

  @override
  String get tipsRainNoiseDesc =>
      'Superposer un filtre de bruit animé léger sur le filtre de pluie ajoute une sensation de particules dans l\'air en plus des gouttes elles-mêmes, pour une texture humide de jour de pluie.';

  @override
  String get tipsPartKeyframeGroupTitle =>
      'Faites rebondir un personnage avec images clés de partie + groupement';

  @override
  String get tipsPartKeyframeGroupDesc =>
      'Animez chaque partie de remplissage automatique avec des images clés de calque, puis groupez les parties liées pour les faire rebondir ensemble — vous pouvez créer une mini-animation qui se balance sur la musique sans rien redessiner.';

  @override
  String get tipsLowSpecSettingsTitle =>
      'Sur les appareils bas de gamme, revoyez les réglages de performance et l\'historique d\'annulation';

  @override
  String get tipsLowSpecSettingsDesc =>
      'Si ça semble lent, essayez de passer les réglages de performance au préréglage « basse qualité » et de réduire aussi la longueur de l\'historique d\'annulation. Cela réduit l\'utilisation de la mémoire et peut rendre l\'ensemble plus fluide.';

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
      'Combiner des tampons en mode pixel avec les trames en damier et en grille réservées au mode pixel permet d\'unifier tout l\'écran avec une texture pixel art. Idéal pour un rendu jeu vidéo rétro.';

  @override
  String get tipsMagicWandLassoTitle =>
      'Baguette magique + remplissage au lasso pour séparer les couleurs plus vite';

  @override
  String get tipsMagicWandLassoDesc =>
      'Sélectionnez une large zone d\'un coup avec la baguette magique de l\'outil de sélection, puis ajustez seulement le débordement avec la sélection au lasso — même une séparation de couleurs complexe va vite ainsi.';

  @override
  String get tipsCommonLayerFolderTitle =>
      'Calques communs + dossiers pour réutiliser d\'un épisode à l\'autre';

  @override
  String get tipsCommonLayerFolderDesc =>
      'Pour un logo ou un générique utilisé à chaque épisode d\'une série, transformez-le en calque commun et rangez-le dans un dossier — facile à gérer en le copiant vers le projet d\'un nouvel épisode.';

  @override
  String get tipsStrokeDecayFadeTitle =>
      'Dégradé de trait + fondu pour un rendu pinceau calligraphique';

  @override
  String get tipsStrokeDecayFadeDesc =>
      'Combiner dégradé de trait et fondu dans les réglages du pinceau affine naturellement le début et la fin d\'un trait, donnant aux lignes cette variation expressive d\'épaisseur propre à un pinceau calligraphique ou à l\'encre.';

  @override
  String get tipsColorMixingFadeTitle =>
      'Mélange de couleurs + fondu pour un mélange façon peinture';

  @override
  String get tipsColorMixingFadeDesc =>
      'Ajouter un fondu à un pinceau avec le mélange de couleurs activé le fait se mélanger avec la couleur dessous tout en s\'éclaircissant progressivement, bien plus proche du comportement de la vraie peinture.';

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
      'Poussez fort le contraste avec les niveaux d\'abord, puis sculptez la gradation avec la courbe de tons, pour un look graphique façon affiche qui s\'éloigne de la tonalité photographique.';

  @override
  String get tipsMosaicChromaticTitle =>
      'Mosaïque + aberration chromatique pour une texture rêche façon tube cathodique';

  @override
  String get tipsMosaicChromaticDesc =>
      'Baissez la résolution avec la mosaïque puis superposez l\'aberration chromatique, pour une texture rêche façon vieille télé à tube cathodique — une nuance différente du filtre tube cathodique seul.';

  @override
  String get tipsEndCardWatermarkTitle =>
      'Le filigrane, c\'est votre signature ; la carte de fin, autre chose';

  @override
  String get tipsEndCardWatermarkDesc =>
      'Utilisez le filigrane pour ajouter votre propre signature ou marque à une vidéo. La carte de fin est le logo de l\'application affiché automatiquement à la fin de chaque vidéo ; les membres gratuits ne peuvent pas la modifier. Les membres premium peuvent la masquer ou la remplacer par leur propre vidéo ou image. Pour une conclusion personnalisée sans utiliser la carte de fin, vous pouvez recréer un effet similaire en ajoutant un calque image avec un fondu d\'entrée/sortie.';

  @override
  String get tipsVerticalPixelFontTitle =>
      'Mélangez images réelles et dessin à la main pour du « prise de vue réelle × anime »';

  @override
  String get tipsVerticalPixelFontDesc =>
      'Une astuce possible uniquement parce que cette app est à la fois une app d\'illustration et un éditeur vidéo. Placez un clip vidéo réel sur la timeline, puis utilisez le papier calque sur un calque au-dessus pour dessiner à la main des traits de vitesse ou un personnage par-dessus les images — créant une vidéo mixte où une animation dessinée à la main se superpose à des prises de vue réelles.';

  @override
  String get tipsTimelineMarkerTitle =>
      'Utilisez les horodatages pour synchroniser le son et les mouvements de bouche';

  @override
  String get tipsTimelineMarkerDesc =>
      'Les scènes gèrent une plage — une image de début et de fin —, tandis que les horodatages marquent un instant précis avec un commentaire vers lequel sauter d\'un seul geste. Placer plusieurs horodatages dans la même scène — « effet sonore à l\'image 120 », « bouche « a » à l\'image 180 » — rend la synchronisation du son et de l\'image bien plus facile.';

  @override
  String get tipsCommunityYoutubeTitle =>
      'Publier sur la Place des œuvres se fait via YouTube';

  @override
  String get tipsCommunityYoutubeDesc =>
      'Lorsque vous publiez sur la Place des œuvres, votre création est publiée via YouTube. NIARIM ne transmet, ne collecte ni ne stocke le fichier vidéo lui-même sur les serveurs du développeur. Si vous réglez la vidéo sur « Non répertoriée » côté YouTube, elle n\'apparaîtra pas dans les listes publiques de YouTube et ne sera publiée que sur la Place des œuvres.';

  @override
  String get tipsToolbarCustomizeTitle =>
      'Réorganisez ou masquez des outils de la barre pour réduire le trajet du doigt';

  @override
  String get tipsToolbarCustomizeDesc =>
      'Depuis l\'édition de la barre d\'outils dans les réglages, vous pouvez masquer les outils que vous n\'utilisez jamais et réorganiser ceux que vous utilisez pour qu\'ils soient à portée de doigt facile. Réduire la liste évite de chercher un outil et raccourcit le trajet du doigt, gardant votre rythme de dessin.';

  @override
  String get tipsAutofillBlendModeTitle =>
      'Changez la texture de l\'ombrage avec le mode de fusion d\'une partie de remplissage automatique';

  @override
  String get tipsAutofillBlendModeDesc =>
      'Chaque partie d’un réglage de remplissage automatique peut avoir son propre mode de fusion. Réglez une partie d’ombre sur « incrustation » ou « lumière tamisée » plutôt que « produit » pour un ombrage plus doux, comme traversé par la lumière. Une liberté cachée qui permet de changer la texture de l’ombrage sans changer la couleur.';

  @override
  String get tipsStampBlendModeTitle =>
      'Tampons + mode de fusion pour un effet de lumière';

  @override
  String get tipsStampBlendModeDesc =>
      'Régler le mode de fusion d\'un calque de tampon placé sur « écran » ou « addition » fait que les traits de lumière ou effets scintillants se fondent naturellement dans le fond et ressortent vraiment.';

  @override
  String get tipsQuickToolPenSubTitle =>
      'Outil rapide + sous-outils du stylet pour un flux de travail sans interruption';

  @override
  String get tipsQuickToolPenSubDesc =>
      'Enregistrez vos outils les plus utilisés dans l\'outil rapide, et profitez aussi des sous-outils du stylet (appui long sur le stylet pour passer au remplissage en trame ou au placement de tampon) — vous réduirez les allers-retours entre panneaux et garderez votre rythme.';

  @override
  String get tipsAutofillToneReuseTitle =>
      'Réutilisez un remplissage en trame juste en retraçant le trait, grâce au réglage de trame du remplissage automatique';

  @override
  String get tipsAutofillToneReuseDesc =>
      'Régler chaque partie d’un réglage de remplissage automatique sur « utiliser une trame » reproduit automatiquement le remplissage en trame à chaque fois que vous retracez le trait — plus besoin de la réappliquer image par image.';

  @override
  String get tipsRadialVignetteTitle =>
      'Règle radiale + vignettage pour un impact de lignes de vitesse';

  @override
  String get tipsRadialVignetteDesc =>
      'Dessinez une rafale de lignes de vitesse d\'un coup avec la règle radiale, puis superposez le filtre de dessin vignettage pour un effet façon climax de manga.';

  @override
  String get tipsClippingGradientTitle =>
      'Détourage + dégradé pour garder l\'ombrage modifiable';

  @override
  String get tipsClippingGradientDesc =>
      'Détourez un calque de dégradé sur un calque de personnage, et vous pourrez réajuster l\'ombrage juste en changeant l\'étendue et l\'angle du dégradé — plus besoin de redessiner sa forme au pinceau.';

  @override
  String get tipsToneCurveSepiaTitle =>
      'Courbe de tons + sépia pour un rendu photo rétro';

  @override
  String get tipsToneCurveSepiaDesc =>
      'Ajustez le contraste clair/sombre avec le filtre d\'effet courbe de tons, puis superposez le sépia, pour une texture façon vieille photo délavée.';

  @override
  String get tipsCameraLensBlurTitle =>
      'Images clés de caméra + flou d\'objectif pour un effet de flou de zoom';

  @override
  String get tipsCameraLensBlurDesc =>
      'Synchroniser un filtre d\'effet de flou d\'objectif plus fort avec le moment où une image clé de caméra zoome donne le punch d\'un flou de zoom en prise de vue réelle.';

  @override
  String get tipsBlurVignetteBgTitle =>
      'Flou gaussien + vignettage pour un bokeh d\'arrière-plan doux';

  @override
  String get tipsBlurVignetteBgDesc =>
      'Appliquez les filtres de dessin flou gaussien et vignettage uniquement au calque d\'arrière-plan, et votre personnage principal ressort naturellement, pour un rendu façon profondeur de champ de caméra.';

  @override
  String get tipsSepiaVignetteTitle =>
      'Sépia + vignettage pour une vidéo façon photo ancienne';

  @override
  String get tipsSepiaVignetteDesc =>
      'Combiner le filtre d\'effet sépia avec le filtre de dessin vignettage donne à votre vidéo les coins assombris et l\'aspect délavé d\'une photo ancienne.';

  @override
  String get tipsVideoTrimReuseTitle =>
      'Réutilisez le même fichier vidéo en changeant la portion utilisée de chaque clip';

  @override
  String get tipsVideoTrimReuseDesc =>
      'Même le même fichier vidéo peut donner un plan différent à chaque fois en changeant son début/fin d\'utilisation par clip. Apporte de la variété sans ajouter de nouveau matériel source.';

  @override
  String get tipsSaveSlotAutoSaveTitle =>
      'Répartissez les emplacements de sauvegarde et la sauvegarde automatique';

  @override
  String get tipsSaveSlotAutoSaveDesc =>
      'La sauvegarde automatique écrase toujours avec le dernier état, tandis que les emplacements de sauvegarde peuvent conserver plusieurs états à la fois. Sauvegardez sur un emplacement à une étape importante et laissez les petits changements à la sauvegarde automatique, pour pouvoir revenir de façon fiable au point voulu.';

  @override
  String get tipsQuickToolSwipeTitle =>
      'Glissez vers le haut sur l\'outil rapide pour le réorganiser';

  @override
  String get tipsQuickToolSwipeDesc =>
      'Pour changer ce qui est enregistré dans l\'outil rapide, vous pouvez ouvrir le popup de gestion par un glissement vers le haut, pas seulement par un appui long. Pratique pour réorganiser vite en utilisant une seule main.';

  @override
  String get tipsDrawingAreaCameraTitle =>
      'Zone de dessin plus large + images clés de caméra pour des panoramiques et zooms sûrs';

  @override
  String get tipsDrawingAreaCameraDesc =>
      'Définir la zone de dessin plus large que les limites d\'export signifie qu\'un panoramique ou un zoom avec des images clés de caméra ne risque pas de couper le bord de l\'écran. À vérifier avant d\'ajouter un grand mouvement de caméra.';

  @override
  String get tipsWebmCommonLayerTitle =>
      'WebM transparent + un calque commun pour séparer le fond';

  @override
  String get tipsWebmCommonLayerDesc =>
      'Si vous compositez un personnage exporté en WebM transparent sur un fond dans un autre logiciel vidéo, garder le fond sur son propre calque commun évite que des couleurs indésirables ne se glissent dans la zone transparente, pour un détourage plus propre.';

  @override
  String get tipsLeftHandedWorkspaceTitle =>
      'Mode gaucher + réglages de l\'espace de travail pour une configuration plus confortable';

  @override
  String get tipsLeftHandedWorkspaceDesc =>
      'Si vous êtes gaucher, activer le mode gaucher dans les réglages de l\'espace de travail inverse les panneaux ancrés, réduisant le risque qu\'ils se retrouvent sous votre main de dessin.';

  @override
  String get tipsTransferDeviceTitle =>
      'Déplacez votre travail vers un autre appareil avec un fichier de transfert';

  @override
  String get tipsTransferDeviceDesc =>
      'Si vous voulez changer d\'appareil tout en gardant le même environnement de dessin, la fonction de transfert (.niatra) déplace vos réglages, pinceaux, trames, tampons, palettes et plus, le tout ensemble. Pour remettre un projet en cours, utilisez plutôt « Partage (.niashare) ».';

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
      'Ajoutez des polices depuis les onglets « Rechercher et télécharger » ou « Importer »';

  @override
  String get fontRenameDialogTitle => 'Renommer la police';

  @override
  String get fontImportTitle =>
      'Importer une police enregistrée sur cet appareil';

  @override
  String get fontImportFormats => 'Formats pris en charge : TTF / OTF';

  @override
  String get fontSelectFileButton => 'Sélectionner un fichier';

  @override
  String get fontUnsupportedSnackbar =>
      'Cette police n\'a pas pu être chargée.';

  @override
  String fontAddedSnackbar(String name) {
    return '« $name » ajoutée (visible dans l\'onglet Téléchargées)';
  }

  @override
  String get fontCorruptedSnackbar => 'La police est corrompue.';

  @override
  String get licenseScreenTitle => 'Conditions et licences';

  @override
  String get licenseSectionTerms => 'Conditions d\'utilisation';

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
      'Les exports WebM et AVI utilisent FFmpeg (LGPL 3.0, via ffmpeg_kit_flutter_new_video). Source de la version modifiée : https://github.com/sk3llo/ffmpeg_kit_flutter\nL\'export MP4 utilise directement l\'encodeur matériel intégré de l\'appareil et n\'utilise pas FFmpeg.';

  @override
  String licenseFontCreditMeta(String author, String license) {
    return 'Auteur : $author   Licence : $license';
  }

  @override
  String get toolbarPenTooltip => 'Plume (appui long pour les sous-outils)';

  @override
  String get toolbarPenFirstUseTip =>
      'Appuyez longuement sur la plume pour basculer entre pinceau, trame, tampon et remplissage au lasso.';

  @override
  String get toolbarBucketTooltip =>
      'Pot de peinture (appui long pour changer de remplissage)';

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
      'Appuyez pour parcourir vos outils enregistrés dans l\'ordre. Appui long ou balayage vers le haut pour modifier vos outils enregistrés.';

  @override
  String get firstUseTipOperationGuideTitle => 'Commandes de base';

  @override
  String get firstUseTipOperationGuideBody =>
      'Une simple pression sur une icône de la barre d’outils bascule vers cet outil. Appuyez longuement sur cette même icône, ou faites-la glisser vers le haut, pour ouvrir ses réglages détaillés (type de pinceau, mode de remplissage, mode de sélection, etc.). Appuyez deux fois sur une icône pour afficher une brève description de l’outil. Vous pouvez relire tout cela depuis le bouton « ? » en haut à droite de chaque écran.';

  @override
  String get helpBasicGestureTitle =>
      'Commandes de base (appui, appui long, balayage)';

  @override
  String get helpBasicGestureDesc =>
      'Une simple pression sur une icône de la barre d’outils bascule vers cet outil. Appuyez longuement sur cette icône, ou faites-la glisser vers le haut, pour ouvrir ses réglages détaillés. Derrière cet appui long ou ce balayage se trouvent : pinceau, trame, tampon ou remplissage au lasso pour le stylo ; remplissage uni ou tramé pour le pot ; rectangle, lasso ou sélection automatique pour l’outil de sélection ; flou ou mosaïque pour l’outil doigt ; et la liste des outils enregistrés pour le changement rapide. Un double appui sur une icône affiche une brève description en bas de l’écran.\\nSur le canevas, pincez à deux doigts pour zoomer, faites glisser à deux doigts pour vous déplacer, touchez à deux doigts pour annuler et à trois doigts pour rétablir. Appuyez deux fois sur le bord gauche ou droit de l’écran pour passer à l’image précédente ou suivante.\\nAvec une souris ou une tablette graphique, la molette zoome et le glissement avec le bouton central déplace la vue.';

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
  String get creativePanelFolderButton => 'Dossier';

  @override
  String get creativePanelCreateButton => 'Créer';

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
  String get toneChangeTextureButton => 'Changer l\'image de texture';

  @override
  String get toneCreateDialogTitle => 'Trame personnalisée';

  @override
  String toneImportFailedSnackbar(String error) {
    return 'Échec du chargement de la trame : $error';
  }

  @override
  String toneExportFailedSnackbar(String error) {
    return 'Échec de l\'exportation de la trame : $error';
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
  String stampImportFailedSnackbar(String error) {
    return 'Échec du chargement du tampon : $error';
  }

  @override
  String stampExportFailedSnackbar(String error) {
    return 'Échec de l\'exportation du tampon : $error';
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
  String get stampChangeImageButton => 'Changer l\'image du tampon';

  @override
  String get themeSettingsTitle => 'Thème et apparence';

  @override
  String get themeColorCustomizeSection => 'Personnalisation des couleurs';

  @override
  String get themeColorAccent => 'Couleur d\'accent';

  @override
  String get themeColorText => 'Couleur du texte';

  @override
  String get themeColorPanelBg => 'Couleur de fond des panneaux';

  @override
  String get themeColorMenuBg => 'Couleur de fond des menus';

  @override
  String get themeColorSelection => 'Couleur de sélection';

  @override
  String get themeColorUpdateMark => 'Couleur de la marque de mise à jour';

  @override
  String get themePresetSection => 'Thèmes';

  @override
  String themePresetDuplicateName(String name) {
    return '$name (copie)';
  }

  @override
  String get themeDuplicateAction => 'Dupliquer';

  @override
  String get themeExportMenuItem => 'Exporter (.niatheme)';

  @override
  String themeExportFailedSnackbar(String error) {
    return 'Échec de l\'exportation : $error';
  }

  @override
  String get themeImportSuccessSnackbar => 'Fichier .niatheme importé';

  @override
  String themeImportFailedSnackbar(String error) {
    return 'Échec de l\'importation : $error';
  }

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
  String get onionSkinFrameInterval => 'Intervalle d\'images';

  @override
  String get onionSkinFadeByDistance => 'Plus foncé si proche';

  @override
  String get onionSkinColorPickerTitle => 'Choisir une couleur';

  @override
  String get onionSkinOnFixed => 'Activé (fixe)';

  @override
  String get onionSkinFrameCount => 'Nombre d\'images';

  @override
  String onionSkinFrameCountFixed(int count) {
    return '$count image(s) (fixe)';
  }

  @override
  String get onionSkinColorLabel => 'Couleur';

  @override
  String get onionSkinOpacityLabel => 'Opacité';

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
  String get exportFpsLabel => 'IPS';

  @override
  String get exportFormatSection => 'Format';

  @override
  String get exportFormatMp4 => 'MP4';

  @override
  String get exportFormatMp4Subtitle => 'Format vidéo universel';

  @override
  String get exportFormatGif => 'GIF';

  @override
  String get exportFormatGifSubtitle => 'GIF animé';

  @override
  String get exportFormatWebmSubtitle => 'Vidéo à fond transparent';

  @override
  String get exportFormatAvi => 'AVI';

  @override
  String get exportFormatAviSubtitle =>
      'Format vidéo à compatibilité étendue (sans transparence)';

  @override
  String get exportStartButton => 'Démarrer l\'export';

  @override
  String get exportProjectNotFoundError => 'Projet introuvable';

  @override
  String exportFailedError(String error) {
    return 'Échec de l\'export : $error';
  }

  @override
  String get exportInProgressTitle => 'Export en cours';

  @override
  String get exportCancelledSnackbar => 'Export annulé';

  @override
  String get exportCancelHint =>
      'Finalisation en cours — l\'annulation sera appliquée une fois terminée';

  @override
  String get exportOutdatedAutofillTitle =>
      'Le coloriage automatique n\'est pas à jour';

  @override
  String get exportOutdatedAutofillBody =>
      'Certains calques de coloriage automatique n\'ont pas été mis à jour. Exporter quand même ?';

  @override
  String get exportContinueButton => 'Continuer';

  @override
  String get exportDurationExceededTitle => 'Durée maximale dépassée';

  @override
  String exportDurationExceededBody(int max, int current) {
    return 'La durée maximale de la version gratuite est de $max secondes.\nLe projet actuel dure environ $current secondes.\nPasser à Premium porte cette limite à 2 heures maximum.';
  }

  @override
  String get exportViewPremiumButton => 'Voir Premium';

  @override
  String get exportContinueAnywayButton => 'Continuer quand même';

  @override
  String get exportCompleteTitle => 'Export terminé';

  @override
  String exportCompleteFramesBody(int count) {
    return '$count image(s) exportée(s).';
  }

  @override
  String exportSaveLocationLabel(String fileName) {
    return 'Enregistré dans : stockage de l\'application ($fileName)';
  }

  @override
  String get exportSaveLocationHint =>
      'Pour l\'ouvrir dans l\'application Photos ou le gestionnaire de fichiers de votre appareil, utilisez « Partager » ci-dessous pour choisir où l\'enregistrer.';

  @override
  String get exportBackToProjectsButton => 'Retour aux projets';

  @override
  String get exportBackToCanvasButton => 'Retour au canevas';

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
      'Le côté le plus long peut être défini jusqu\'à 1920 px';

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
      'Indiquez une taille personnalisée dans l\'écran de nouveau projet puis appuyez sur « Enregistrer cette taille » pour l\'ajouter';

  @override
  String get canvasSizePresetEditDialogTitle => 'Modifier la taille';

  @override
  String get canvasSizePresetDuplicateSuffix => 'copie';

  @override
  String newProjectDurationLabel(String max) {
    return 'Durée (max $max)';
  }

  @override
  String newProjectDurationLabelWithPremiumHint(String max) {
    return 'Durée (max $max ; jusqu\'à 2 heures avec Premium)';
  }

  @override
  String newProjectDurationSeconds(int n) {
    return '$n s';
  }

  @override
  String newProjectDurationHms(int h, int m, int s) {
    return '$h h $m min $s s';
  }

  @override
  String newProjectDurationHm(int h, int m) {
    return '$h h $m min';
  }

  @override
  String newProjectDurationH(int h) {
    return '$h h';
  }

  @override
  String newProjectDurationMs(int m, int s) {
    return '$m min $s s';
  }

  @override
  String newProjectDurationM(int m) {
    return '$m min';
  }

  @override
  String get newProjectBackgroundColorLabel => 'Couleur de fond';

  @override
  String get newProjectDrawingAreaTitle => 'Agrandir la zone de dessin';

  @override
  String get newProjectDrawingAreaSubtitle =>
      'Ajoute une zone où dessiner en dehors du cadre d\'exportation';

  @override
  String get newProjectScaleLabel => 'Échelle';

  @override
  String newProjectScaleValue(String value) {
    return '$value×';
  }

  @override
  String newProjectDrawableAreaInfo(String width, String scale, String result) {
    return 'Zone dessinable : $width×$scale = $result';
  }

  @override
  String newProjectTotalFrames(int count) {
    return 'Nombre total d\'images : $count';
  }

  @override
  String newProjectExportSizeInfo(String size) {
    return 'Taille d\'exportation : $size';
  }

  @override
  String newProjectDrawingAreaInfo(String size) {
    return 'Zone de dessin : $size';
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
  String get colorPickerRecentColorsEmpty => 'Aucune pour l\'instant';

  @override
  String get colorPickerPaletteLabel => 'Palette';

  @override
  String get colorPickerNewPaletteTooltip => 'Nouvelle palette';

  @override
  String get colorPickerManagePaletteTooltip => 'Gérer la palette';

  @override
  String get colorPickerPaletteEmptyHint =>
      'Pas encore de couleurs. Appuyez sur « + » pour ajouter la couleur actuelle.';

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
      'Choisissez une trame pour peindre des motifs de trame avec le pot de peinture ou le stylo.';

  @override
  String get penSubToolStampTooltipMessage =>
      'Placez des tampons de forme fixe. Appuyez longuement pour régler la rotation, la densité, etc.';

  @override
  String get penSubToolManageTooltip => 'Gérer';

  @override
  String penSubToolBrushSizeOpacity(int size, int opacity) {
    return '${size}px · $opacity%';
  }

  @override
  String get penSubToolStampRotationSubtitle =>
      'Rotation aléatoire selon la direction du trait';

  @override
  String get brushSearchHint => 'Rechercher par nom de pinceau';

  @override
  String get brushEmpty => 'Aucun pinceau';

  @override
  String get brushCreateDialogTitle => 'Pinceau personnalisé';

  @override
  String brushImportFailedSnackbar(String error) {
    return 'Échec du chargement du pinceau : $error';
  }

  @override
  String brushExportFailedSnackbar(String error) {
    return 'Échec de l\'exportation du pinceau : $error';
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
  String get brushSettingsStabilizationTitle => 'Stabilisation du trait';

  @override
  String get brushSettingsStabilizationStrengthLabel =>
      'Intensité de la stabilisation';

  @override
  String get brushSettingsPixelModeTitle => 'Mode pixel';

  @override
  String get brushSettingsPressureModeTitle => 'Sensibilité à la pression';

  @override
  String get brushSettingsPressureOff => 'Désactivé';

  @override
  String get brushSettingsPressureSize => 'Affecte la taille';

  @override
  String get brushSettingsPressureOpacity => 'Affecte l\'opacité';

  @override
  String get brushSettingsPressureSizeAndOpacity =>
      'Affecte la taille + l\'opacité';

  @override
  String get brushSettingsFadeModeTitle => 'Fondu';

  @override
  String get brushSettingsFadeOff => 'OFF';

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
  String get brushSettingsStrokeDecayTitle => 'Atténuation du trait';

  @override
  String get brushSettingsStrokeDecaySubtitle =>
      'L\'opacité diminue plus vous dessinez longtemps';

  @override
  String get brushSettingsMixingTitle => 'Mélange des couleurs';

  @override
  String get brushSettingsMixingOff => 'OFF';

  @override
  String get brushSettingsMixingSimple => 'Mélange simple';

  @override
  String get brushSettingsMixingBleed => 'Effet de bavure';

  @override
  String get brushSettingsMixingRateLabel => 'Taux de mélange';

  @override
  String get projectDetailNotFoundTitle => 'Projet';

  @override
  String get projectDetailNotFoundBody => 'Projet introuvable';

  @override
  String get projectDetailFirstFrameTooltip => 'Première image';

  @override
  String get projectDetailPrevFrameTooltip => 'Reculer d\'une image';

  @override
  String get projectDetailPauseTooltip => 'Pause';

  @override
  String get projectDetailPlayTooltip => 'Lecture';

  @override
  String get projectDetailNextFrameTooltip => 'Avancer d\'une image';

  @override
  String get projectDetailLastFrameTooltip => 'Dernière image';

  @override
  String get projectDetailFullscreenTooltip =>
      'Afficher l\'aperçu en plein écran';

  @override
  String get projectDetailFullscreenCloseTooltip =>
      'Fermer l\'aperçu plein écran';

  @override
  String get projectDetailStartEditButton => 'Commencer l\'édition';

  @override
  String get projectDetailTagsQuickAction => 'Étiquettes';

  @override
  String get projectDetailShareQuickAction => 'Partager';

  @override
  String get projectDetailInfoSectionTitle => 'Infos du projet';

  @override
  String get projectDetailInfoExportSize => 'Taille d\'exportation';

  @override
  String get projectDetailInfoDrawingArea => 'Zone de dessin';

  @override
  String projectDetailInfoDrawingAreaValue(String size, String scale) {
    return '$size  ($scale)';
  }

  @override
  String get projectDetailInfoTotalFrames => 'Nombre total d\'images';

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
    return 'Échec de la création du .niashare : $error';
  }

  @override
  String get projectDetailTrashMenuItem => 'Déplacer vers la corbeille';

  @override
  String get commonOff => 'OFF';

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
  String get perfSettingsUndoLimitTitle => 'Nombre d\'annulations';

  @override
  String get perfSettingsUndoLimitSubtitle =>
      'Plus il est élevé, plus il consomme de mémoire';

  @override
  String perfSettingsUndoLimitValue(int n) {
    return '$n étapes';
  }

  @override
  String get perfSettingsTrashAutoDeleteTitle =>
      'Suppression automatique de la corbeille';

  @override
  String get perfSettingsTrashAutoDeleteSubtitle =>
      'Durée de conservation des projets supprimés';

  @override
  String perfSettingsTrashAutoDeleteValue(int n) {
    return '$n jours';
  }

  @override
  String get perfSettingsCurrentSettingsSection => 'Paramètres actuels';

  @override
  String get perfSettingsTiltLabel => 'Détection de l\'inclinaison';

  @override
  String get perfSettingsOnionPrevLabel => 'Papier calque (avant)';

  @override
  String get perfSettingsOnionNextLabel => 'Papier calque (après)';

  @override
  String perfSettingsOnionFrameCountValue(int n) {
    return '$n images';
  }

  @override
  String get perfSettingsSaveModeLabel => 'Mode de sauvegarde';

  @override
  String get perfSettingsSlotCountLabel => 'Nombre d\'emplacements';

  @override
  String perfSettingsSlotCountValue(int n) {
    return '$n emplacements';
  }

  @override
  String get perfSettingsResetButton => 'Réinitialiser aux valeurs par défaut';

  @override
  String get perfSettingsCopyPresetButton => 'Copier le préréglage actuel';

  @override
  String get perfSettingsTiltSwitchTitle =>
      'Appliquer l\'inclinaison du stylet au pinceau';

  @override
  String get perfSettingsShowPrevOnionTitle => 'Afficher l\'image précédente';

  @override
  String get perfSettingsOnionCountPrevLabel =>
      'Nombre d\'images de calque (avant)';

  @override
  String get perfSettingsShowNextOnionTitle => 'Afficher l\'image suivante';

  @override
  String get perfSettingsOnionCountNextLabel =>
      'Nombre d\'images de calque (après)';

  @override
  String get perfSettingsSaveModeSlot => 'Par emplacements';

  @override
  String get perfSettingsSaveModeTree => 'Par arborescence';

  @override
  String get perfSettingsResetDialogTitle =>
      'Réinitialiser les paramètres de qualité personnalisés aux valeurs par défaut ?';

  @override
  String perfSettingsResetDialogBody(String preset) {
    return 'Les valeurs par défaut correspondent au réglage « $preset » déterminé automatiquement au premier lancement selon les performances de l\'appareil.';
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
  String get filterNameLensBlur => 'Flou d\'objectif';

  @override
  String get filterNameAnimeStyle => 'Style anime';

  @override
  String get filterNameOutline => 'Contour';

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
  String get filterVignetteStrength => 'Intensité du vignettage';

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
  String filterOutlineLayerNameSuffix(String name) {
    return '$name (Contour)';
  }

  @override
  String get filterStrengthBlurRadius => 'Intensité (rayon de flou)';

  @override
  String get filterColorLevels => 'Nombre de couleurs';

  @override
  String get filterEdgeStrength => 'Accentuation des contours';

  @override
  String get filterOutlineColor => 'Couleur du contour';

  @override
  String get filterOutlineWidth => 'Épaisseur du contour';

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
  String get filterLevelsInputBlack => 'Entrée : Noir';

  @override
  String get filterLevelsInputWhite => 'Entrée : Blanc';

  @override
  String get filterLevelsOutputBlack => 'Sortie : Noir';

  @override
  String get filterLevelsOutputWhite => 'Sortie : Blanc';

  @override
  String get filterApplyButton => 'Appliquer';

  @override
  String filterApplyBulkButton(int count) {
    return 'Appliquer à $count images';
  }

  @override
  String get filterEmpty => 'Aucun filtre';

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
      'Vous pouvez aussi l\'utiliser pour regrouper plusieurs épisodes ou une série d\'une même œuvre';

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
  String get projectListDeleteFolderConfirmTitle => 'Supprimer ce dossier ?';

  @override
  String projectListDeleteFolderConfirmBody(String name) {
    return '« $name » sera supprimé. Les projets et sous-dossiers qu\'il contient seront déplacés à la racine.';
  }

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
  String get projectListIncludeFontsTitle => 'Inclure les polices';

  @override
  String get projectListIncludeFontsSubtitle =>
      'Inclut les polices ajoutées par l\'utilisateur actuellement utilisées';

  @override
  String get blendModeNormal => 'Normal';

  @override
  String get blendModeMultiply => 'Produit';

  @override
  String get blendModeScreen => 'Écran';

  @override
  String get blendModeOverlay => 'Incrustation';

  @override
  String get blendModeAddition => 'Addition';

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
      'Radial : centre → extérieur';

  @override
  String get autofillGradientTypeRadialOutCenter =>
      'Radial : extérieur → centre';

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
    return '$count parties';
  }

  @override
  String get autofillPresetNewDialogTitle => 'Nouveau';

  @override
  String get autofillPresetNameLabel => 'Nom du réglage';

  @override
  String get autofillPresetRenameDialogTitle => 'Renommer le réglage';

  @override
  String autofillPresetDeleteConfirmTitle(String name) {
    return 'Supprimer « $name » ?';
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
    return 'Échec de l\'importation : $error';
  }

  @override
  String autofillPresetExportFailedSnackbar(String error) {
    return 'Échec de l\'exportation : $error';
  }

  @override
  String autofillPresetDuplicateName(String name) {
    return '$name (copie)';
  }

  @override
  String get autofillPartSearchHint => 'Rechercher par nom de partie';

  @override
  String autofillPartUnconfiguredBanner(int count, String names) {
    return '$count partie(s) ne sont pas encore configurées : $names (aucune trame sélectionnée)\nVous ne pouvez pas fermer cet écran tant que tout n\'est pas configuré.';
  }

  @override
  String get autofillPartUnconfiguredDialogTitle =>
      'Il y a des parties non configurées';

  @override
  String get autofillPartUnconfiguredDialogBody =>
      'Veuillez configurer les parties suivantes avant d\'enregistrer.';

  @override
  String autofillPartUnconfiguredItem(String name) {
    return '• $name : aucune trame sélectionnée';
  }

  @override
  String get autofillPartUnconfiguredBackButton => 'Retour à la configuration';

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
    return 'Épaisseur du contour : ${value}px';
  }

  @override
  String get autofillEyedropperFromThumbnailButton =>
      'Prélever depuis l\'image';

  @override
  String get autofillEyedropperDialogTitle =>
      'Prélever une couleur depuis l\'image';

  @override
  String get autofillEyedropperDialogHint =>
      'Touchez l\'image pour choisir une couleur';

  @override
  String get autofillEyedropperPickedLabel => 'Couleur choisie';

  @override
  String get autofillEyedropperImageLoadFailedSnackbar =>
      'Impossible de charger l’image.';

  @override
  String get autofillThumbnailMenuItem => 'Définir l\'image miniature';

  @override
  String get autofillThumbnailLoadButton => 'Charger une image';

  @override
  String get autofillThumbnailDeleteButton => 'Supprimer l\'image miniature';

  @override
  String get autofillThumbnailDeleteConfirmTitle =>
      'Supprimer l\'image miniature ?';

  @override
  String get autofillThumbnailDeleteConfirmBody =>
      'Cela revient à l\'affichage des couleurs par défaut (jusqu\'à 4 couleurs).';

  @override
  String get autofillThumbnailCropDialogTitle => 'Ajuster l\'image miniature';

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
    return 'Opacité (calque de remplissage) : $value%';
  }

  @override
  String get autofillPartLineColorLabel => 'Couleur du trait';

  @override
  String autofillPartTraceHueLabel(int value) {
    return 'Teinte : $value';
  }

  @override
  String autofillPartTraceSaturationLabel(int value) {
    return 'Saturation : $value';
  }

  @override
  String autofillPartTraceLightnessLabel(int value) {
    return 'Luminosité : $value';
  }

  @override
  String autofillPartLineOpacityLabel(int value) {
    return 'Opacité (calque de trait) : $value%';
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
      'Linéaire : la couleur change selon l\'angle défini. Radial centre→extérieur : les couleurs changent du centre vers l\'extérieur. Radial extérieur→centre : l\'inverse.';

  @override
  String get autofillPartGradientFeatherInfo =>
      'À 0%, la limite entre les couleurs adjacentes est nette. À 100%, les couleurs se fondent complètement et en douceur jusqu\'au bord de la couleur voisine.';

  @override
  String get autofillLineColorModeTraceAdjustInfo =>
      'Conserve la couleur d\'origine du trait mais en décale légèrement la teinte, la saturation et la luminosité. À utiliser pour garder les nuances du dessin au trait plutôt que de le remplir d\'une couleur unie.';

  @override
  String autofillPartGradientAngleLabel(int value) {
    return 'Angle : $value°';
  }

  @override
  String get autofillPartGradientColorLabel => 'Couleurs';

  @override
  String get autofillPartGradientAddColorButton => 'Ajouter une couleur';

  @override
  String get autofillPartGradientRemoveButton => 'Supprimer le dégradé';

  @override
  String autofillPartGradientFeatherLabel(int value) {
    return 'Intensité du flou : $value%';
  }

  @override
  String get autofillPartGradientDragHint =>
      'Faites glisser la poignée à droite pour réorganiser les couleurs';

  @override
  String autofillPartGradientStopLabel(int value) {
    return 'Position : $value%';
  }

  @override
  String get autofillPartGradientStopDragHint =>
      'Faites glisser les repères ▲ pour ajuster la position de chaque couleur';

  @override
  String get saveTreeScreenTitleTree => 'Arbre de sauvegarde';

  @override
  String get saveTreeScreenTitleSlot => 'Emplacements de sauvegarde';

  @override
  String get timelineExportMenuItem => 'Exporter';

  @override
  String get timelineExportFrameMenuItem =>
      'Exporter l\'image en tant qu\'image';

  @override
  String get timelineExportFrameDialogTitle =>
      'Exporter l\'image en tant qu\'image';

  @override
  String get timelineExportFrameDialogMessage =>
      'Enregistre l\'image actuellement affichée en tant qu\'image fixe. Choisissez un format.';

  @override
  String get timelineExportFramePngOption => 'Enregistrer en PNG';

  @override
  String get timelineExportFrameJpegOption => 'Enregistrer en JPEG';

  @override
  String timelineExportFrameSuccessSnackbar(String fileName) {
    return 'Enregistré sous $fileName (consultable dans l\'onglet des créations)';
  }

  @override
  String get timelineExportFrameErrorSnackbar =>
      'Échec de l\'exportation de l\'image';

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
  String get timelineDurationShrinkConfirmTitle => 'Raccourcir quand même ?';

  @override
  String get timelineDurationShrinkConfirmBody =>
      'Les images qui seront supprimées contiennent des modifications (dessin, calques ajoutés, etc.). Si vous continuez, ces images ne pourront pas être récupérées. Voulez-vous vraiment les supprimer ?';

  @override
  String get timelineCanvasSizeDragHint =>
      'Faites glisser l\'intérieur du cadre pour le déplacer, ou un coin pour le redimensionner (s\'aligne près de la taille d\'origine)';

  @override
  String get timelineCanvasSizeAngleLabel => 'Angle';

  @override
  String get saveTreeSaveAsChildHint =>
      'Sera enregistré comme enfant du nœud sélectionné.';

  @override
  String get saveTreeSaveAsRootHint => 'Sera enregistré comme nœud racine.';

  @override
  String get saveTreeCommentLabel => 'Commentaire (facultatif)';

  @override
  String get saveTreeCommentHint => 'ex. : Arrière-plan terminé';

  @override
  String saveTreeSizeWarningSnackbar(String mb) {
    return 'Votre arbre de sauvegardes devient volumineux (environ $mb Mo). Nous vous recommandons de supprimer les sauvegardes inutiles.';
  }

  @override
  String saveTreeSaveFailedSnackbar(String error) {
    return 'Échec de l\'enregistrement. Vérifiez l\'espace disponible et réessayez ($error)';
  }

  @override
  String saveTreeSlotSaveDialogTitle(int n) {
    return 'Enregistrer dans l\'emplacement $n';
  }

  @override
  String saveTreeSlotOverwriteWarning(String date) {
    return 'Cela écrasera les données existantes ($date).';
  }

  @override
  String get saveTreeRestoreAction => 'Restaurer';

  @override
  String get saveTreeTimelineActionChoiceBody =>
      'Choisissez si vous voulez écraser cette sauvegarde avec le contenu actuel, ou reprendre le travail à partir d\'ici.';

  @override
  String get saveTreeOverwriteAction => 'Écraser';

  @override
  String get saveTreeOverwriteConfirmBody =>
      'Les données enregistrées à ce moment-là seront perdues. Voulez-vous continuer ?';

  @override
  String get saveTreeResumeFromHereAction => 'Reprendre à partir d\'ici';

  @override
  String get saveTreeResumeConfirmBody =>
      'Toute modification non enregistrée sera perdue. Voulez-vous continuer ?';

  @override
  String get saveTreeProjectDetailResumeBody =>
      'Reprendre le travail à partir de cette sauvegarde ?';

  @override
  String get saveTreeLoadFailedSnackbar =>
      'Échec du chargement des données de sauvegarde';

  @override
  String saveTreeRestoredSnackbar(String name) {
    return '$name restauré';
  }

  @override
  String saveTreeSlotLabel(int n) {
    return 'Emplacement $n';
  }

  @override
  String saveTreeSlotFallbackName(int n) {
    return 'Emplacement $n';
  }

  @override
  String get saveTreeNoDataLabel => 'Aucune donnée de sauvegarde';

  @override
  String get saveTreeEmptyTitle => 'Aucune donnée de sauvegarde';

  @override
  String get saveTreeEmptyHint =>
      'Appuyez sur le bouton « Enregistrer » en haut pour créer le premier nœud';

  @override
  String get saveTreeNodeDefaultTitle => 'Sauvegarde';

  @override
  String get saveTreeNodeDefaultName => 'Données de sauvegarde';

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
    return 'Sauvegardes conservables : $n';
  }

  @override
  String saveTreeKeepLatestButton(int n) {
    return 'Conserver les $n plus récentes';
  }

  @override
  String get saveTreeSelectDataButton => 'Choisir les données de sauvegarde';

  @override
  String saveTreeSelectedCountLabel(int selected, int limit) {
    return 'Sélectionné : $selected / $limit';
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
      'Conserver en tant qu\'archive (recommandé)';

  @override
  String get saveTreeArchiveOptionSubtitle =>
      'Restauré automatiquement si vous revenez à la sauvegarde en arborescence.\nUtilise de l\'espace de stockage.';

  @override
  String get saveTreeDeleteOptionTitle => 'Supprimer définitivement';

  @override
  String saveTreeDeleteOptionSubtitle(int count) {
    return 'Supprime définitivement les $count éléments non sélectionnés.\nLibère de l\'espace de stockage.\n※ Les données supprimées ne peuvent pas être récupérées.';
  }

  @override
  String get saveTreeApplyChangeButton => 'Appliquer le changement';

  @override
  String get canvasEditMenuAutofillPresets =>
      'Réglages de coloriage automatique';

  @override
  String get canvasEditMenuAutofillPresetsSubtitle =>
      'Modifier les combinaisons de couleur/teinte de chaque partie';

  @override
  String get canvasEditMenuBackgroundToggle => 'Changer l\'arrière-plan';

  @override
  String get canvasEditMenuBackgroundCurrentColor =>
      'Actuel : couleur de fond du projet (touchez pour passer en transparent)';

  @override
  String get canvasEditMenuBackgroundCurrentTransparent =>
      'Actuel : transparent (touchez pour passer à la couleur de fond du projet)';

  @override
  String get canvasEditMenuOnionSkinSubtitle =>
      'Superpose légèrement les images précédentes/suivantes';

  @override
  String get canvasEditMenuFilterSubtitle =>
      'Applique un flou, des courbes de tons, etc.';

  @override
  String get canvasEditMenuFrameMultiSelect => 'Sélection multiple d\'images';

  @override
  String get canvasEditMenuFrameMultiSelectSubtitle =>
      'Pour les traitements par lot (ex. appliquer un filtre à plusieurs images)';

  @override
  String get canvasEditMenuPressureCurve => 'Courbe de pression';

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
  String get canvasTapToEnterTextLabel =>
      'Touchez le canevas pour saisir du texte';

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
  String get canvasTextHorizontal => 'Horizontal';

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
      'Les lettres et symboles sont automatiquement pivotés de 90° à l\'affichage.';

  @override
  String get canvasHelpTatechuyokoTitle =>
      'Tate-chu-yoko (vertical uniquement)';

  @override
  String get canvasHelpTatechuyokoBody =>
      'Deux chiffres demi-chasse consécutifs se placent automatiquement côte à côte dans la hauteur d\'un seul caractère (ex. : 12).';

  @override
  String get canvasHelpRubyTitle => 'Furigana (glose phonétique)';

  @override
  String canvasHelpRubyBody(String example) {
    return 'Saisir « $example » affiche une petite annotation de lecture au-dessus des caractères de base (en horizontal) ou à leur droite (en vertical). Cela fonctionne dans les deux sens, mais le texte contenant du furigana ne se retourne pas automatiquement à la ligne en mode horizontal (retours à la ligne manuels uniquement).';
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
  String get layerPanelNewLayerButton => 'Nouveau calque';

  @override
  String get layerPanelNewFolderButton => 'Nouveau dossier';

  @override
  String get layerPanelImportImageButton => 'Importer une image';

  @override
  String layerPanelDefaultLayerName(int n) {
    return 'Calque$n';
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
  String get layerPanelAddTooltip => 'Ajouter';

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
  String get layerPanelMenuFrameRangeChange => 'Modifier la plage d\'images';

  @override
  String get layerPanelMenuRangeChange => 'Modifier la plage d\'affichage';

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
    return 'Supprimer $name ?';
  }

  @override
  String get layerPanelDeleteConfirmBody =>
      'Ce matériau sera supprimé de toutes les images de sa plage d\'affichage.';

  @override
  String layerPanelCommonDeleteMidDialogTitle(String name) {
    return 'Modifier la plage d\'affichage de $name ?';
  }

  @override
  String get layerPanelCommonDeleteMidDialogBody =>
      'La plage d\'affichage d\'un calque partagé ne peut être qu\'une seule plage continue, elle ne peut donc pas être supprimée depuis une image au milieu de cette plage. Choisissez plutôt de conserver la partie avant ou après cette image.';

  @override
  String get layerPanelCommonDeleteKeepBeforeButton =>
      'Conserver avant cette image';

  @override
  String get layerPanelCommonDeleteKeepAfterButton =>
      'Conserver après cette image';

  @override
  String get layerPanelRangeDialogTitle => 'Plage d\'affichage';

  @override
  String get layerPanelRangeStartFrameLabel => 'Image de début';

  @override
  String get layerPanelRangeEndFrameLabel => 'Image de fin';

  @override
  String get layerPanelRangeTilde => '–';

  @override
  String get layerPanelRangeUseCurrentButton => 'Utiliser la plage actuelle';

  @override
  String get layerPanelRangeTargetSceneLabel => 'Scène cible';

  @override
  String get layerPanelRangeFrameRangeLabel => 'Plage d\'images spécifiée';

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
  String get layerPanelOpacityLockLabel => 'Verrouiller l\'opacité';

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
      'Modifie la façon dont le calque est composité : produit, filtre, incrustation, etc.';

  @override
  String get layerPanelHelpClippingBody =>
      'Dessine uniquement dans la zone de pixels opaques du calque du dessous. Utilisez cette option pour contrôler la zone de dessin.';

  @override
  String get layerPanelCommonLayerLabel => 'Calque commun';

  @override
  String get layerPanelHelpCommonLayerBody =>
      'Un calque dont le contenu est partagé entre plusieurs images. Vous pouvez définir la plage d\'images dans laquelle il apparaît.';

  @override
  String get layerPanelAutofillMethodTitle =>
      'Méthode de remplissage automatique';

  @override
  String get layerPanelAutofillNoLineartSnackbar =>
      'Aucun calque de trait pour remplissage automatique correspondant n\'a été trouvé.';

  @override
  String get layerPanelAutofillNote1 =>
      '✳ N\'importe quelle option convient la première fois que vous exécutez le remplissage automatique dans ce projet.';

  @override
  String get layerPanelAutofillNote2 =>
      '✳ Si aucun calque de remplissage automatique n\'existe encore, la zone sera de toute façon déterminée à partir de zéro.';

  @override
  String get layerPanelAutofillRepaintTitle => 'Repeindre';

  @override
  String get layerPanelAutofillRepaintHint =>
      'Recommandé si la forme du remplissage automatique a été modifiée par erreur';

  @override
  String get layerPanelAutofillRepaintNote =>
      '✳ Détermine la zone à partir de zéro et la repeint. La forme actuelle du calque de remplissage automatique sera abandonnée.';

  @override
  String get layerPanelAutofillColorUpdateTitle => 'Mettre à jour la couleur';

  @override
  String get layerPanelAutofillColorUpdateHint =>
      'Recommandé si la forme du remplissage automatique a été ajustée manuellement';

  @override
  String get layerPanelAutofillColorUpdateNote =>
      '✳ Verrouille l\'opacité et remplit avec la couleur la plus récente. La forme actuelle du calque de remplissage automatique est conservée.';

  @override
  String get layerPanelExecuteButton => 'Exécuter';

  @override
  String get layerPanelAutofillPartMissingSnackbar =>
      'Aucune partie n\'est attribuée. Attribuez-en une depuis « Attribuer une partie ».';

  @override
  String get layerPanelAutofillPresetMissingSnackbar =>
      'Aucune partie correspondante trouvée dans le réglage de remplissage automatique.';

  @override
  String get layerPanelOrphanFillSuccessSnackbar =>
      'Aucun calque de trait correspondant trouvé, rempli avec la couleur la plus récente à la place.';

  @override
  String get layerPanelOrphanFillFailSnackbar =>
      'Impossible de traiter : aucune partie n\'est attribuée, ou il n\'y a pas de forme à remplir.';

  @override
  String get layerPanelAutofillUpdateHelpTitle =>
      'Marque de mise à jour du remplissage auto';

  @override
  String get layerPanelAutofillUpdateHelpBody =>
      'Le remplissage automatique actuel n\'est pas à jour. Touchez pour le mettre à jour.';

  @override
  String layerPanelReplaceMaterialSuccessSnackbar(String name) {
    return 'Matériau remplacé : $name';
  }

  @override
  String layerPanelImportImageSuccessSnackbar(String name) {
    return 'Image importée : $name';
  }

  @override
  String layerPanelCopySuffix(String name) {
    return 'Copie de $name';
  }

  @override
  String get timelineFullscreenPreviewCloseTooltip =>
      'Fermer l\'aperçu plein écran';

  @override
  String get timelineDefaultProjectName => 'Nom du projet';

  @override
  String get timelinePreviewPlaceholder => 'Aperçu';

  @override
  String get timelinePreviewFullscreenTip =>
      'Touchez pour afficher l\'aperçu en plein écran. Pratique pour vérifier le rendu final.';

  @override
  String get timelinePreviewFullscreenTooltip =>
      'Afficher l\'aperçu en plein écran';

  @override
  String get timelineAddVideoTooltip => '+ Vidéo';

  @override
  String get timelineAddAudioTooltip => '+ Audio';

  @override
  String get timelineEffectFilterLabel => 'Filtres d\'effet';

  @override
  String get timelineAddCameraKfTooltip => 'Ajouter une image clé de caméra';

  @override
  String get timelineAddWatermarkTooltip => '+ Filigrane';

  @override
  String get timelineWatermarkNotRegisteredTitle =>
      'Aucun filigrane enregistré';

  @override
  String get timelineWatermarkNotRegisteredBody =>
      'Enregistrez d\'abord une image ou un filigrane texte depuis « Filigrane » dans les réglages.';

  @override
  String get timelineOpenSettingsButton => 'Ouvrir les réglages';

  @override
  String get timelineWatermarkSelectTitle => 'Sélectionner un filigrane';

  @override
  String timelineWatermarkAddedSnackbar(String name) {
    return 'Filigrane ajouté (affiché sur toutes les images) : $name';
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
      'L\'emplacement du collage chevauche un clip existant. Comment souhaitez-vous le placer ?';

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
      'Les membres gratuits sont limités à 90 secondes de vidéo. Ajouter ou dupliquer davantage d\'images dépasserait cette limite, l\'action est donc impossible. Passez à Premium pour aller jusqu\'à 2 heures.';

  @override
  String get timelineDurationLimitBodyPremium =>
      'Cela dépasserait la limite Premium (jusqu\'à 2 heures), il n\'est donc plus possible d\'ajouter ou de dupliquer des images.';

  @override
  String timelineSceneDeleteConfirmTitle(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get timelineSceneDeleteConfirmBody =>
      'Toutes les données de la scène seront supprimées : images, calques communs, matériaux vidéo, matériaux image et filigranes inclus.';

  @override
  String timelineSceneMultiDeleteConfirmTitle(int count) {
    return 'Supprimer les $count scènes sélectionnées ?';
  }

  @override
  String get timelineAutofillUpdateHelpBody =>
      'Cette scène/image contient un calque de remplissage automatique qui n\'est pas à jour. Touchez le calque concerné dans le panneau des calques pour le mettre à jour.';

  @override
  String get timelineFrameTrackLabel => 'Image';

  @override
  String get timelineTrackRowRenameTitle => 'Renommer la ligne';

  @override
  String get timelineCameraTrackLabel => 'Caméra';

  @override
  String get timelineRangeSceneFixed => 'Scène fixe';

  @override
  String get timelineEndCardDefaultLogoLabel => 'Logo NIARIM';

  @override
  String get timelineEndCardHiddenLabel => 'Masqué';

  @override
  String get timelineEndCardTrackLabel => 'Piste de la carte de fin';

  @override
  String get timelineMarkerTrackLabel => 'Horodatages';

  @override
  String timelineMarkerAddDialogTitle(int n) {
    return 'Ajouter un horodatage à F$n';
  }

  @override
  String timelineMarkerEditDialogTitle(int n) {
    return 'Horodatage : F$n';
  }

  @override
  String get timelineMarkerCommentHint => 'Commentaire (ex. bouche « a » ici)';

  @override
  String timelineAddClipDialogTitle(String trackName) {
    return 'Ajouter un clip $trackName';
  }

  @override
  String get timelineClipLabelFieldLabel => 'Libellé';

  @override
  String get timelineClipStartLabel => 'Début :';

  @override
  String get timelineClipLengthLabel => 'Durée :';

  @override
  String get timelineAutofillNote2 =>
      '✳ S\'il n\'existe qu\'un calque de remplissage automatique (sans dessin au trait), la zone sera de toute façon déterminée à partir de zéro.';

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
  String get timelineEffectTypeLensBlur => 'Flou d\'objectif';

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
  String get timelineClipFadeInLabel => 'Fondu d\'entrée';

  @override
  String get timelineClipFadeOutLabel => 'Fondu de sortie';

  @override
  String get timelineClipUseStartLabel => 'Début utilisé F';

  @override
  String get timelineClipUseEndLabel => 'Fin utilisée F';

  @override
  String timelineCameraKfTitle(int n) {
    return 'Image clé caméra : F$n';
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
      'Définissez la position, l\'échelle et la rotation de ce calque par image ; les images clés sont interpolées automatiquement. Le dessin du calque lui-même ne change pas.';

  @override
  String layerKeyframeAddAtCurrentFrame(int n) {
    return 'Ajouter à l\'image actuelle (F$n)';
  }

  @override
  String get layerKeyframeEmpty =>
      'Aucune image clé pour l\'instant. Ajoutez-en une avec le bouton ci-dessus.';

  @override
  String get layerKeyframeScaleShort => 'Échelle';

  @override
  String get layerKeyframeRotationShort => 'Rot.';

  @override
  String layerKeyframeEditTitle(int n) {
    return 'Image clé : F$n';
  }

  @override
  String get layerKeyframeFrameLabel => 'Image';

  @override
  String get layerKeyframeScaleLabel => 'Échelle';

  @override
  String get layerKeyframeRotationLabel => 'Rotation';

  @override
  String get layerKeyframeEasingLabel =>
      'Transition vers l\'image clé suivante';

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
    return 'Groupe : $name';
  }

  @override
  String get layerPanelGroupLeaveAction => 'Quitter';

  @override
  String frameStripHoldDialogTitle(int n) {
    return 'F$n images de maintien';
  }

  @override
  String get frameStripFrameListModeLabel => 'Images';

  @override
  String get frameStripTimelineModeLabel => 'Timeline';

  @override
  String get progressDialogAdLoading => 'Chargement de la publicité…';

  @override
  String get adMockPlaceholderLabel =>
      'Bannière publicitaire (maquette d\'essai d\'emplacement)';

  @override
  String get progressDialogTipLabel => 'Astuce';

  @override
  String get premiumBannerRegisterButton => 'Passer à Premium';

  @override
  String get licenseTermsArt1Title => 'Article 1 (Application)';

  @override
  String get licenseTermsArt1Body =>
      'Les présentes conditions d\'utilisation (les « Conditions ») définissent les conditions d\'utilisation de l\'application « NIARIM » (l\'« Application »). L\'utilisateur doit accepter les présentes Conditions avant d\'utiliser l\'Application. L\'utilisation de l\'Application vaut acceptation des présentes Conditions.';

  @override
  String get licenseTermsArt2Title =>
      'Article 2 (Éligibilité à l\'utilisation / environnement pris en charge)';

  @override
  String get licenseTermsArt2Body =>
      '1. Pour plus de détails sur les versions du système d\'exploitation prises en charge et l\'environnement d\'exploitation recommandé de l\'Application, veuillez vous référer à la boutique de distribution concernée et aux informations affichées dans l\'Application.\n2. Nous nous efforçons de faire fonctionner l\'Application confortablement sur des appareils de performances variées ; toutefois, selon les performances de l\'appareil, la version du système d\'exploitation, l\'espace de stockage disponible, les paramètres et d\'autres conditions d\'utilisation, certaines fonctionnalités peuvent être limitées ou ne pas fonctionner correctement.';

  @override
  String get licenseTermsArt3Title => 'Article 3 (Actes interdits)';

  @override
  String get licenseTermsArt3Body =>
      'Lors de l\'utilisation de l\'Application, l\'utilisateur ne doit pas :\n・Commettre des actes contraires aux lois, règlements ou aux bonnes mœurs\n・Porter atteinte aux droits d\'auteur, marques ou autres droits de propriété intellectuelle, au droit à l\'image, à la vie privée ou à d\'autres droits ou intérêts de l\'Application, du développeur ou de tiers\n・Décompiler, désassembler, procéder à de l\'ingénierie inverse ou toute autre analyse de l\'Application (sauf dans les cas autorisés par la loi)\n・Modifier, dupliquer ou redistribuer l\'Application sans autorisation\n・Accéder sans autorisation à l\'Application ou à la plateforme qui la fournit, lui imposer une charge excessive ou entraver de toute autre manière son fonctionnement normal\n・Commettre tout autre acte que le développeur juge raisonnablement inapproprié';

  @override
  String get licenseTermsArt4Title => 'Article 4 (Droits sur le contenu créé)';

  @override
  String get licenseTermsArt4Body =>
      '1. Les droits d\'auteur et autres droits relatifs aux illustrations, animations et autres contenus créés par l\'utilisateur au moyen de l\'Application (y compris les données de projet, les images et vidéos exportées, etc. ; ci-après le « Contenu créé ») appartiennent, dans la mesure permise par la loi, à l\'utilisateur ou au tiers titulaire des droits sur ce contenu.\n2. L\'Application ne fournit aucune fonction permettant de transmettre, collecter ou synchroniser le Contenu créé vers les serveurs du développeur. Les données de projet sont, en principe, stockées uniquement sur l\'appareil de l\'utilisateur (pour le traitement applicable lorsque l\'utilisateur choisit de publier du Contenu créé au moyen de la fonction Place des œuvres, voir l\'article 12).\n3. Que le Contenu créé ait été réalisé avec la version gratuite ou la version premium, le développeur ne restreindra pas son utilisation commerciale en raison des frais d\'utilisation de l\'Application ou de l\'édition utilisée (les différences entre la version gratuite et la version premium se limitent à des aspects fonctionnels tels que l\'affichage de la carte de fin ou la limite de durée d\'exportation).\n4. Nonobstant le paragraphe précédent, les polices, images, matériaux et autres éléments ajoutés par l\'utilisateur à l\'Application et sur lesquels des tiers détiennent des droits restent soumis à leurs conditions d\'utilisation respectives (article 5).';

  @override
  String get licenseTermsArt5Title =>
      'Article 5 (Polices intégrées et matériaux ajoutés)';

  @override
  String get licenseTermsArt5Body =>
      '1. Les polices et autres matériaux intégrés à l\'Application sont utilisés conformément aux conditions de licence indiquées sur cet écran, sous « À propos des polices utilisées ».\n2. En ce qui concerne les droits relatifs aux polices, images, tons, tampons et autres matériaux que l\'utilisateur ajoute ou charge lui-même dans l\'Application, celui-ci est responsable de l\'obtention des droits ou autorisations nécessaires et de leur utilisation licite.\n3. En cas de litige avec un tiers résultant de l\'utilisation par l\'utilisateur de matériaux tiers, le développeur n\'en assume aucune responsabilité, sauf dans les cas où la loi l\'exige.';

  @override
  String get licenseTermsArt6Title =>
      'Article 6 (Fonctionnalités premium / facturation)';

  @override
  String get licenseTermsArt6Body =>
      '1. Outre les fonctionnalités disponibles gratuitement, l\'Application propose des fonctionnalités premium accessibles via des achats intégrés (une formule mensuelle, une formule annuelle ou d\'autres formules premium).\n2. Le prix, le contenu, le mode d\'achat et les autres conditions des fonctionnalités premium sont ceux affichés dans l\'Application ou sur la boutique de distribution au moment de l\'achat.\n3. Les annulations, remboursements et autres questions relatives au paiement après achat sont régis par les règles de Google Play ou de la plateforme de paiement utilisée. Toutefois, lorsque la loi en dispose autrement, ces dispositions s\'appliquent.\n4. Le développeur peut modifier le contenu des fonctionnalités premium pour des motifs raisonnables, tels qu\'une évolution législative, une nécessité technique ou une amélioration de l\'Application. Lorsqu\'un changement important est apporté, il en informera au préalable, dans la mesure du raisonnablement possible, au sein de l\'Application ou par tout autre moyen approprié.';

  @override
  String get licenseTermsArt7Title => 'Article 7 (Affichage publicitaire)';

  @override
  String get licenseTermsArt7Body =>
      '1. Dans la version gratuite, des publicités peuvent être affichées via des services publicitaires tiers.\n2. L\'acquisition, l\'utilisation et le traitement des informations par les prestataires publicitaires sont régis par la politique de confidentialité de chaque prestataire concerné.';

  @override
  String get licenseTermsArt8Title => 'Article 8 (Traitement des informations)';

  @override
  String get licenseTermsArt8Body =>
      '1. L\'Application ne fournit aucune fonction permettant de transmettre ou de collecter vers les serveurs du développeur les illustrations, animations et autres contenus, ni les données de projet, créés par l\'utilisateur. Ceux-ci sont, en principe, stockés uniquement sur l\'appareil de l\'utilisateur, et le développeur ne disposant d\'aucune fonction lui permettant de stocker ce contenu par lui-même, la notion de durée de conservation du côté du développeur n\'existe pas.\n2. Le traitement des informations de l\'utilisateur — y compris les informations collectées par les services tiers intégrés à l\'Application (tels que la diffusion publicitaire et les achats intégrés) — est régi par la Politique de confidentialité établie séparément.\n3. Si vous désinstallez l\'Application, les données stockées sur votre appareil (projets, paramètres, polices ajoutées, etc.) seront supprimées.';

  @override
  String get licenseTermsArt9Title =>
      'Article 9 (Suspension, modification et cessation de la fourniture)';

  @override
  String get licenseTermsArt9Body =>
      '1. Le développeur peut suspendre temporairement la fourniture de tout ou partie de l\'Application lors d\'opérations de maintenance, de mise à jour ou de correction, en cas de dysfonctionnement de l\'infrastructure de fourniture, ou pour toute autre raison indépendante de sa volonté.\n2. Le développeur peut modifier le contenu de l\'Application ou mettre fin à sa fourniture selon les besoins.\n3. Dans les cas visés aux deux paragraphes précédents, le développeur donnera, sauf urgence, un préavis dans la mesure du possible, dans l\'Application ou par tout autre moyen approprié.\n4. Sauf obligation légale contraire, le développeur n\'assume aucune responsabilité pour les dommages subis par l\'utilisateur du fait des modifications, suspensions ou cessations visées au présent article.';

  @override
  String get licenseTermsArt10Title =>
      'Article 10 (Clause de non-responsabilité)';

  @override
  String get licenseTermsArt10Body =>
      '1. Le développeur ne garantit pas l\'absence de défauts factuels ou juridiques de l\'Application (y compris en matière de sécurité, de fiabilité, d\'exactitude, d\'exhaustivité, d\'adéquation à un usage particulier, ou d\'absence de bugs ou de dysfonctionnements).\n2. L\'utilisateur utilise l\'Application sous sa propre responsabilité. Des données peuvent être perdues en raison d\'une panne de l\'appareil, d\'une erreur de manipulation, d\'une mise à jour du système d\'exploitation ou d\'autres circonstances ; il est donc recommandé d\'effectuer des sauvegardes régulières des données en cours de création à l\'aide des fonctions d\'exportation et de partage, entre autres.\n3. Dans la mesure permise par la loi, le développeur n\'assume aucune responsabilité pour les dommages subis par l\'utilisateur du fait de l\'utilisation de l\'Application. Cette limitation ne s\'applique toutefois pas en cas de faute intentionnelle ou de négligence grave du développeur ; même dans ce cas, la responsabilité du développeur en matière de dommages-intérêts est limitée aux dommages directs ordinaires, dans la limite du montant effectivement payé par l\'utilisateur au titre de l\'Application au cours de l\'année précédente (soit 0 yen en cas d\'utilisation gratuite).';

  @override
  String get licenseTermsArt11Title =>
      'Article 11 (Modification des présentes Conditions)';

  @override
  String get licenseTermsArt11Body =>
      '1. Le développeur peut modifier les présentes Conditions en cas de changement de la législation applicable, de modification du contenu de l\'Application ou pour toute autre raison qu\'il juge nécessaire.\n2. En cas de modification des présentes Conditions, le développeur en communiquera au préalable le contenu et la date d\'entrée en vigueur, dans l\'Application ou par tout autre moyen approprié.\n3. Les Conditions modifiées s\'appliqueront, dans la mesure permise par la loi, à compter de la date d\'entrée en vigueur mentionnée au paragraphe précédent.';

  @override
  String get licenseTermsArt12Title =>
      'Article 12 (Place des œuvres : fonction de publication communautaire)';

  @override
  String get licenseTermsArt12Body =>
      '1. L\'Application propose, à titre facultatif, une fonction permettant à l\'utilisateur de publier, via son propre compte Google, les animations qu\'il a créées sur YouTube, puis de les publier et de les consulter sur la « Place des œuvres » (la « Fonction Communautaire »). Il est possible de consulter et de créer des œuvres sans utiliser la Fonction Communautaire.\n2. Le fichier vidéo lui-même est stocké sur YouTube, et non sur les serveurs du développeur. En revanche, les informations nécessaires à l\'identification et à l\'affichage des œuvres publiées (identifiant de la vidéo YouTube, titre, statistiques, informations de signalement, etc.), ainsi que l\'identifiant utilisateur NIARIM délivré lors de l\'utilisation des fonctions de publication, de signalement et de blocage (un identifiant délivré au sein de l\'Application, distinct du compte Google), sont gérés sur les serveurs du développeur.\n3. La publication d\'œuvres, le signalement et le blocage d\'autres utilisateurs dans le cadre de la Fonction Communautaire nécessitent une connexion via un compte Google.\n4. Le nombre d\'œuvres pouvant être publiées est soumis à une limite quotidienne (différente entre les membres gratuits et les membres premium). Cette limite peut être modifiée pour des raisons d\'exploitation.\n5. Si un utilisateur estime qu\'une œuvre publiée par un autre utilisateur enfreint la loi ou les bonnes mœurs, ou pourrait relever de l\'un des points de l\'article 3, il peut la signaler au développeur via la fonction de signalement de l\'Application. Après examen du signalement, le développeur pourra, pour un motif raisonnable, prendre les mesures nécessaires, telles que le retrait de l\'œuvre des listes. Les signalements mensongers et l\'usage abusif de la fonction de signalement sont interdits.\n6. Si un utilisateur supprime une publication, ou dissocie son compte Google de l\'Application, la vidéo YouTube correspondante pourra être supprimée. De même, si la vidéo est rendue privée ou supprimée du côté de YouTube, l\'œuvre cessera également d\'être affichée sur la Place des œuvres.\n7. L\'utilisation de la Fonction Communautaire est soumise, en plus des présentes Conditions, aux Conditions d\'utilisation et aux Règles de la communauté de YouTube.\n8. Les utilisateurs peuvent s\'abonner à d\'autres utilisateurs et mettre en favori ou repartager les œuvres d\'autres utilisateurs. Vos listes d\'abonnements / d\'abonnés et la liste des œuvres que vous avez mises en favori sont privées par défaut ; leur publication relève de votre choix au sein de l\'Application. Vos nombres d\'abonnements et d\'abonnés sont affichés indépendamment de ce réglage.\n9. Les tags attachés à une œuvre peuvent être ajoutés ou supprimés par des utilisateurs autres que l\'auteur. L\'auteur peut verrouiller les tags de sa propre œuvre afin d\'en interdire la modification par d\'autres utilisateurs. Les utilisateurs ne doivent pas ajouter de tags diffamatoires, de tags sans rapport avec le contenu de l\'œuvre, ni de tags inappropriés de quelque autre nature. Le développeur peut supprimer les tags inappropriés.\n10. Le développeur affiche des notifications dans la liste des notifications de l\'Application, par exemple lorsque quelqu\'un s\'abonne à vous. Si vous avez autorisé les notifications sur votre appareil, des notifications push peuvent être envoyées. Les notifications peuvent être désactivées depuis les réglages de l\'Application ou depuis les réglages de votre appareil.\n11. Les utilisateurs ne doivent pas utiliser la Fonction Communautaire pour harceler d\'autres utilisateurs, à des fins publicitaires ou de démarchage, ni pour tout autre objectif étranger à sa finalité (publier et consulter des œuvres). Si vous utilisez la fonction de blocage, les œuvres de l\'utilisateur bloqué n\'apparaîtront plus dans vos listes.';

  @override
  String get licenseTermsArt13Title =>
      'Article 13 (Droit applicable / juridiction compétente)';

  @override
  String get licenseTermsArt13Body =>
      '1. Les présentes Conditions sont régies et interprétées conformément au droit japonais.\n2. En cas de litige relatif à l\'Application, le tribunal de district ou le tribunal sommaire compétent pour le lieu d\'établissement du développeur, selon le montant en litige, disposera d\'une compétence exclusive convenue en tant que juridiction de première instance.';

  @override
  String get privacyPolicyArt1Title =>
      'Article 1 (Objet de la présente Politique)';

  @override
  String get privacyPolicyArt1Body =>
      'La présente politique de confidentialité (la « Politique ») décrit la manière dont les informations sont traitées dans l\'application « NIARIM » (l\'« Application »). Pour les conditions générales d\'utilisation de l\'Application, veuillez vous référer séparément à l\'écran « Conditions d\'utilisation / Licence ».';

  @override
  String get privacyPolicyArt2Title =>
      'Article 2 (Données que l\'Application ne collecte pas)';

  @override
  String get privacyPolicyArt2Body =>
      'L\'Application ne fournit aucune fonction permettant de transmettre, collecter ou stocker sur les serveurs du développeur les illustrations, animations et autres contenus créés par l\'utilisateur (y compris les données de projet, les images et vidéos exportées, etc. ; il en va de même ci-après). Ces données sont, en principe, stockées uniquement sur l\'appareil de l\'utilisateur (l\'Application n\'intègre pas de fonction de synchronisation en nuage). Le développeur ne disposant d\'aucune fonction lui permettant de stocker ce contenu par lui-même, la notion de durée de conservation du côté du développeur n\'existe pas. Les données stockées sur votre appareil peuvent être supprimées à tout moment via les fonctions de suppression de l\'Application ; si vous désinstallez l\'Application, les données stockées sur votre appareil — projets, paramètres, polices ajoutées, etc. — seront également supprimées (pour le traitement de l\'information lorsque l\'utilisateur choisit de publier une œuvre au moyen de la fonction Place des œuvres, voir l\'article 7).';

  @override
  String get privacyPolicyArt3Title =>
      'Article 3 (Informations collectées par des services tiers)';

  @override
  String get privacyPolicyArt3Body =>
      'L\'Application intègre les services tiers suivants, et chaque fournisseur de services peut collecter des informations dans la mesure nécessaire à la fourniture de son service respectif. Le développeur de l\'Application n\'a mis en place aucune fonction lui permettant d\'acquérir ou de stocker ces informations de manière autonome (le traitement des informations collectées par chaque service est régi par la politique de confidentialité propre à ce prestataire).\n\n[Diffusion publicitaire (Google AdMob)]\nDans la version gratuite, les publicités sont diffusées via Google AdMob. À des fins de diffusion publicitaire, de mesure d\'efficacité et de prévention de la fraude, l\'identifiant publicitaire et d\'autres informations sur l\'appareil peuvent être collectés et utilisés par Google ou ses sociétés affiliées. Pour plus de détails sur la collecte et l\'utilisation de ces informations, veuillez consulter la politique de confidentialité de Google (https://policies.google.com/privacy). Vous pouvez réinitialiser votre identifiant publicitaire ou désactiver les publicités personnalisées depuis les paramètres de votre appareil (par exemple, « Confidentialité » dans l\'application Paramètres d\'Android). Si vous résidez dans l\'Espace économique européen (EEE), au Royaume-Uni ou en Suisse, vous pouvez choisir vos préférences de consentement relatives à la personnalisation des publicités via un formulaire de consentement affiché au lancement, et modifier ce choix à tout moment via le bouton « Modifier les préférences de consentement publicitaire » en bas de cet écran.\n\n[Achats intégrés (Google Play Billing)]\nLes achats des fonctionnalités premium sont effectués via le système de paiement de Google Play. Le développeur n\'acquiert ni ne conserve directement les informations de paiement telles que les numéros de carte bancaire. Le traitement des informations relatives au paiement est régi par les règles de Google Play.\n\n[Analyse des plantages / analyse d\'utilisation]\nL\'Application n\'intègre actuellement aucun SDK à des fins d\'analyse des plantages ou d\'analyse d\'utilisation. Si de tels services venaient à être introduits à l\'avenir, la présente Politique serait mise à jour et annoncée dans l\'Application.\n\n[Téléchargement de polices supplémentaires (GitHub)]\nUne communication avec GitHub (GitHub, Inc.), qui distribue les fichiers de polices, n\'a lieu que lorsque vous choisissez de télécharger une police supplémentaire depuis « Gestion des polices » dans l\'écran des réglages. Elle n\'a pas lieu au démarrage de l\'application ni lors d\'une utilisation normale. Seules les informations nécessaires à la requête (comme votre adresse IP et le fichier de police demandé) sont transmises ; aucune donnée de vos œuvres ni information permettant de vous identifier n\'est transmise. Le traitement des informations obtenues est régi par la Déclaration de confidentialité de GitHub (https://docs.github.com/site-policy/privacy-policies/github-privacy-statement).';

  @override
  String get privacyPolicyArt4Title =>
      'Article 4 (Cookies et autres technologies de suivi)';

  @override
  String get privacyPolicyArt4Body =>
      'L\'Application elle-même n\'utilise pas de cookies, mais le service de diffusion publicitaire mentionné à l\'article 3 (Google AdMob) peut utiliser des technologies d\'identification similaires (telles que l\'identifiant publicitaire) à des fins de diffusion publicitaire et de mesure d\'efficacité.';

  @override
  String get privacyPolicyArt5Title =>
      'Article 5 (Informations personnelles des enfants)';

  @override
  String get privacyPolicyArt5Body =>
      'L\'Application n\'est pas conçue pour collecter intentionnellement des informations principalement destinées aux enfants de moins de 13 ans. Les parents et tuteurs sont invités à envisager, si nécessaire, de désactiver les publicités personnalisées depuis les paramètres de l\'appareil lorsque leurs enfants utilisent l\'Application.';

  @override
  String get privacyPolicyArt6Title =>
      'Article 6 (Transferts transfrontaliers d\'informations)';

  @override
  String get privacyPolicyArt6Body =>
      'Les services tiers mentionnés à l\'article 3 (Google AdMob, Google Play Billing) peuvent traiter des données sur des serveurs exploités par Google dans divers pays du monde. Le traitement de ces données est régi par la politique de confidentialité de chaque service concerné.';

  @override
  String get privacyPolicyArt7Title =>
      'Article 7 (Traitement de l\'information dans la Place des œuvres : fonction de publication communautaire)';

  @override
  String get privacyPolicyArt7Body =>
      '1. Uniquement lorsqu\'un utilisateur choisit, de sa propre initiative, d\'utiliser la fonction « la Place des Œuvres » (article 12 des Conditions d\'utilisation), le développeur gère les informations suivantes sur ses serveurs :\n・Les informations nécessaires pour identifier et afficher une œuvre publiée (identifiant de la vidéo YouTube, titre, statistiques, date et heure de publication, tags, etc.)\n・Le NIARIM User ID émis pour l\'utilisation de fonctions telles que la publication, le signalement, le blocage, l\'abonnement et les favoris (un identifiant émis au sein de l\'Application, distinct du compte Google)\n・Les informations publiques de la chaîne YouTube associée (nom de la chaîne et URL de l\'image de l\'icône de la chaîne). Elles sont copiées et conservées sur les serveurs du développeur afin d\'afficher le nom et l\'icône de l\'auteur\n・Le contenu de tout signalement effectué au moyen de la fonction de signalement, ainsi que le NIARIM User ID de l\'auteur du signalement\n・Le NIARIM User ID de tout utilisateur que vous bloquez\n・Le NIARIM User ID de tout utilisateur que vous suivez, ainsi que vos nombres d\'abonnements et d\'abonnés\n・Les identifiants des œuvres que vous mettez en favori et la date et l\'heure de chaque mise en favori\n・Les identifiants des œuvres que vous repartagez et la date et l\'heure de chaque repartage\n・Les tags attachés à une œuvre (voir le paragraphe 4)\n・Si vous activez les notifications push, le jeton de votre appareil (un identifiant émis par votre appareil pour déterminer la destination de la notification ; utilisé uniquement pour envoyer des notifications)\n2. Le fichier vidéo lui-même est stocké sur YouTube, et non sur les serveurs du développeur.\n3. Les informations décrites aux deux paragraphes précédents ne sont utilisées que pour fournir la Fonction Communautaire (affichage des listes, des classements et des résultats de recherche, traitement des signalements, gestion des limites de publication, prise en compte des abonnements, favoris et repartages, envoi des notifications, etc.). Le développeur ne communique pas ces informations à des tiers à des fins publicitaires.\n4. Les tags peuvent être ajoutés ou supprimés par des utilisateurs autres que l\'auteur (l\'auteur peut verrouiller les tags de sa propre œuvre pour en interdire la modification). Les tags sont publics sur la Place des Œuvres et l\'identité de l\'utilisateur ayant ajouté un tag n\'est pas affichée.\n5. Les informations suivantes sont privées par défaut et ne sont montrées aux autres utilisateurs que si vous les rendez publiques dans l\'Application :\n・La liste des œuvres que vous avez mises en favori\n・Vos listes d\'abonnements / d\'abonnés\nVos nombres d\'abonnements et d\'abonnés (les chiffres eux-mêmes) sont toujours affichés, indépendamment de ce réglage.\n6. Si vous rendez privée ou supprimez une œuvre publiée, celle-ci n\'apparaîtra plus dans les listes ni les classements de la Place des Œuvres. Si vous souhaitez la suppression des enregistrements présents sur les serveurs du développeur, veuillez nous contacter par le moyen décrit à l\'article 9.\n7. Si un utilisateur n\'utilise pas la Fonction Communautaire, aucun traitement d\'informations au titre du présent article n\'a lieu. (Conformément au principe de l\'article 2, rien n\'est transmis aux serveurs du développeur.)';

  @override
  String get privacyPolicyArt8Title =>
      'Article 8 (Modifications de la présente Politique)';

  @override
  String get privacyPolicyArt8Body =>
      'Le développeur peut modifier la présente Politique en cas de changement de la législation applicable, de modification du contenu de l\'Application ou pour toute autre raison qu\'il juge nécessaire. En cas de modification de la présente Politique, le développeur en communiquera au préalable le contenu et la date d\'entrée en vigueur, dans l\'Application ou par tout autre moyen approprié.';

  @override
  String get privacyPolicyArt9Title => 'Article 9 (Contact)';

  @override
  String get privacyPolicyArt9Body =>
      'Pour toute question relative à la présente Politique, veuillez nous contacter aux coordonnées ci-dessous.\n(Coordonnées du développeur : non définies — veuillez indiquer une adresse e-mail ou d\'autres coordonnées avant la publication.)';

  @override
  String get privacyPolicyAdConsentButton =>
      'Modifier les préférences de consentement publicitaire';

  @override
  String get tipsPcDexLayoutTitle =>
      'Sur grand écran, bascule automatiquement en mode PC (DeX)';

  @override
  String get tipsPcDexLayoutDesc =>
      'Sur un Chromebook, une tablette avec clavier, Samsung DeX ou tout environnement à écran large, l\'application bascule automatiquement vers une mise en page professionnelle à panneaux ancrés. Vous pouvez aussi forcer Toujours en mode PC ou Toujours en mode mobile depuis les paramètres d\'espace de travail, utile lors d\'une connexion à un écran externe.';

  @override
  String get workspaceTimelineSection => 'Affichage de la chronologie';

  @override
  String get workspaceTimelineHint =>
      'Ajustez la hauteur de chaque ligne de piste vidéo/audio sur 5 niveaux. Vous pouvez aussi pincer avec deux doigts pour zoomer temporairement sur la largeur des images de la chronologie.';

  @override
  String get workspaceTimelineTrackHeightLabel => 'Hauteur de la piste';

  @override
  String get workspaceTimelinePreviewLabel => 'Aperçu';

  @override
  String get workspaceEndCardSection => 'Carte de fin';

  @override
  String get workspaceEndCardHint =>
      'La carte de fin est le logo de l\'application affiché automatiquement à la fin de chaque vidéo. Les membres gratuits ne peuvent pas la modifier. Réservé aux membres premium : activer cette option masquera (supprimera) automatiquement la carte de fin dès la prochaine ouverture de la timeline. Ce réglage repasse automatiquement sur OFF si votre abonnement premium expire.';

  @override
  String get workspaceEndCardDefaultHiddenTitle =>
      'Masquer la carte de fin par défaut (Premium uniquement)';

  @override
  String get tipsTransparentColorTitle =>
      'La transparence n\'est pas qu\'une gomme : utilisez-la comme une couleur de stylo';

  @override
  String get tipsTransparentColorDesc =>
      'En selectionnant la transparence, vous pouvez effacer avec n\'importe quel outil : pinceau, lasso, formes, a votre choix. Profitez de la pression et du lissage du pinceau pour arrondir precisement des contours, ou utilisez un pinceau degrade pour fondre doucement un bord vers la transparence : des effets subtils que la gomme seule ne peut pas obtenir.';

  @override
  String get tipsQuickToolVariantTitle =>
      'L\'outil rapide accepte des variantes de pinceau ou de taille, pas seulement des outils differents';

  @override
  String get tipsQuickToolVariantDesc =>
      'L\'emplacement d\'outil rapide ne se limite pas a alterner entre des outils comme le stylo et la gomme : vous pouvez enregistrer le meme stylo avec un pinceau different, ou la meme gomme a une autre taille, comme entrees separees. En ne gardant que les combinaisons que vous utilisez vraiment souvent, vous evitez de retourner sans cesse au panneau de reglages.';

  @override
  String get tipsCommonLayerLipSyncTitle =>
      'Les calques communs reduisent aussi la taille des personnages, pas seulement des arriere-plans';

  @override
  String get tipsCommonLayerLipSyncDesc =>
      'Pas seulement les arriere-plans : transformer le calque du personnage lui-meme en calque commun fonctionne aussi bien. Ne gardez comme calques normaux que les parties qui changent d\'une image a l\'autre, comme la bouche ou les yeux qui clignent, et transformez le reste (corps, cheveux) en calque commun. Cela peut reduire considerablement la taille meme pour une animation de synchronisation labiale ou de clignement.';

  @override
  String get tipsCommonLayerKeyframeTitle =>
      'Calques communs et images cles de calque permettent aussi d\'economiser de l\'espace';

  @override
  String get tipsCommonLayerKeyframeDesc =>
      'Les calques communs peuvent etre deplaces, redimensionnes et pivotes avec des images cles de calque. Plutot que de redessiner chaque image, transformez un seul dessin en calque commun et animez-le avec des images cles : vous obtenez un mouvement simple sans augmenter la taille du fichier.';

  @override
  String get tipsTransferCustomizationTitle =>
      'Le transfert conserve votre configuration personnalisee sur n\'importe quel appareil';

  @override
  String get tipsTransferCustomizationDesc =>
      'La fonction de transfert (.niatra) deplace vos reglages personnalises — pinceaux, theme, disposition de la barre d\'outils, palettes, etc. — le tout vers un autre appareil. Changez d\'appareil ou travaillez sur plusieurs sans jamais devoir tout reconfigurer depuis zero.';

  @override
  String get tipsBlendModeUsageTitle =>
      'Choisissez le mode de fusion selon l\'effet recherche';

  @override
  String get tipsBlendModeUsageDesc =>
      'Utilisez Produit pour les ombres, Ecran ou Addition pour la lumiere et les reflets, et Incrustation ou Lumiere douce pour un ombrage avec un peu de texture. La meme couleur peut paraitre completement differente selon le mode de fusion : n\'hesitez pas a essayer plusieurs options et a comparer.';

  @override
  String get timelineSaveFailedDialogTitle => 'Échec de l\'enregistrement';

  @override
  String get timelineSaveFailedDialogBody =>
      'L\'enregistrement a échoué. Veuillez réessayer.';

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
      'Un outil de transformation pour tout le calque, accessible depuis le menu édition/réglages en haut à droite du canevas. Contrairement à la transformation d\'une sélection, aucune sélection n\'est nécessaire : faites glisser les coins ou des points de la grille individuellement avec le doigt pour un résultat libre. Le curseur de densité du panneau de contrôle peut subdiviser la grille jusqu\'à 10×10, et pincer deux points différents avec deux doigts à la fois offre un moyen intuitif de pivoter ou redimensionner.';

  @override
  String get layerPanelBrightnessToAlphaLabel => 'Transparence par luminosité';

  @override
  String get layerPanelBrightnessToAlphaHint =>
      'Rend les zones claires plus transparentes. Les couleurs restent les mêmes mais deviennent translucides (toute l\'image s\'éclaircit, plutôt que le fond blanc ne disparaisse simplement).';

  @override
  String get layerPanelBrightnessToAlphaColorButton => 'Couleur';

  @override
  String get layerPanelBrightnessToAlphaGrayButton => 'Gris';

  @override
  String get tipsRoughLayerRescueTitle =>
      'Encrage dessiné sur le calque de brouillon ? Récupérez-le avec « Transparence par luminosité »';

  @override
  String get tipsRoughLayerRescueDesc =>
      'Même si vous avez dessiné l\'encrage par erreur sur le calque de brouillon, vous pouvez récupérer uniquement l\'encrage sans rien supprimer. 1) Ajoutez un nouveau calque et réglez son mode de fusion sur Diviser. 2) Prélevez la couleur du brouillon à la pipette et remplissez tout ce calque Diviser avec (le brouillon s\'estompe). 3) Dupliquez le calque Diviser et le brouillon disparaît complètement. 4) Utilisez « Fusionner tous les calques visibles » dans le panneau des calques pour tout aplatir en un seul calque. 5) Depuis le menu à trois points de ce calque fusionné, choisissez « Transparence par luminosité (Gris) » : les zones blanches deviennent transparentes, ne laissant que l\'encrage.';

  @override
  String get filterNameMonochrome => 'Filtre monochrome';

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
      'Ajouter aux filtres d\'effet';

  @override
  String get canvasColorAdjustMenuTitle => 'Réglage des couleurs';

  @override
  String get canvasEditMenuReferenceWindow => 'Fenêtre de référence';

  @override
  String get canvasEditMenuReferenceWindowSubtitle =>
      'Affiche une image de référence flottante';

  @override
  String get referenceWindowTitle => 'Fenêtre de référence';

  @override
  String get referenceWindowSelectImageButton => 'Choisir une image';

  @override
  String get workspaceDockPanelSection => 'Panneaux ouverts par défaut (PC)';

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
  String get workspaceDockPanelTone => 'Ton';

  @override
  String get workspaceDockPanelStamp => 'Tampon';

  @override
  String get workspaceDockPanelPenSubTool => 'Sous-outil crayon';

  @override
  String get workspaceDockPanelOnionSkin => 'Pelure d’oignon';

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
  String get pcWorkspaceLayoutScreenTitle => 'Réglages de disposition PC';

  @override
  String get pcWorkspaceLayoutIntroHint =>
      'Ajustez l\'ordre et la largeur des panneaux lorsque l\'écran de canevas s\'ouvre en mode PC (paysage + souris/tablette graphique connectée).';

  @override
  String get pcWorkspaceLayoutToolOrderSection =>
      'Ordre des panneaux d\'outils';

  @override
  String get pcWorkspaceLayoutToolOrderHint =>
      'L\'ordre d\'empilement utilisé quand plusieurs panneaux (pinceau, ton, tampon, etc.) sont ouverts en même temps.';

  @override
  String get pcWorkspaceLayoutRightOrderSection =>
      'Ordre du panneau de calques, etc.';

  @override
  String get pcWorkspaceLayoutRightOrderHint =>
      'L\'ordre d\'empilement du sélecteur de couleur, du panneau de calques et de l\'aperçu du canevas.';

  @override
  String get pcWorkspaceLayoutWidthSection => 'Largeur des panneaux';

  @override
  String get pcWorkspaceLayoutToolWidthLabel =>
      'Largeur côté panneau d\'outils';

  @override
  String get pcWorkspaceLayoutRightWidthLabel =>
      'Largeur côté panneau de calques';

  @override
  String get pcWorkspaceLayoutResetWidthButton => 'Réinitialiser la largeur';

  @override
  String get pcWorkspaceLayoutResetOrderButton => 'Réinitialiser l\'ordre';

  @override
  String get canvasPreviewNavigatorTitle => 'Aperçu du canevas';

  @override
  String get canvasEditMenuPreviewNavigator => 'Aperçu du canevas';

  @override
  String get canvasEditMenuPreviewNavigatorSubtitle =>
      'Afficher une vue d’ensemble réduite (navigateur)';

  @override
  String get filterCustomMenuDuplicate => 'Dupliquer';

  @override
  String get filterCustomMenuFavoriteBlockTitle => 'Suppression impossible';

  @override
  String get filterCustomMenuFavoriteBlockBody =>
      'Ce filtre est en favori et ne peut pas être supprimé. Retirez-le des favoris avant de le supprimer.';

  @override
  String get filterNameThreshold => 'Filtre de seuil';

  @override
  String get filterMonochromeStrength => 'Intensité du monochrome';

  @override
  String get filterMonochromeColorLabel => 'Couleur du monochrome';

  @override
  String get filterThresholdLabel => 'Seuil';

  @override
  String get filterNameFisheye => 'Filtre œil de poisson';

  @override
  String get filterFisheyeStrength => 'Intensité de la courbure';

  @override
  String get filterNameChromaticAberration =>
      'Filtre d\'aberration chromatique';

  @override
  String get filterChromaticAberrationStrength => 'Intensité du décalage';

  @override
  String get filterNameLensDistortion => 'Filtre de distorsion de lentille';

  @override
  String get filterLensDistortionStrength =>
      'Puissance de la lentille (négatif = concave, positif = convexe)';

  @override
  String get filterLensDistortionOffsetX =>
      'Ajustement fin du centre (horizontal)';

  @override
  String get filterNamePixelate => 'Filtre pixellisation';

  @override
  String get filterNameAuroraHologram => 'Hologramme Aurore';

  @override
  String get filterAuroraHologramStrength => 'Intensité';

  @override
  String get filterAuroraHologramBrightness => 'Luminosité';

  @override
  String get filterAuroraHologramSaturation => 'Saturation';

  @override
  String get filterAuroraHologramPresetAurora => 'Aurore';

  @override
  String get filterAuroraHologramPresetSoapBubble => 'Bulle de savon';

  @override
  String get filterAuroraHologramPresetCyberNeon => 'Néon cyber';

  @override
  String get filterAuroraHologramPresetPastelDream => 'Rêve pastel';

  @override
  String get filterAuroraHologramPresetSunsetGold => 'Or du couchant';

  @override
  String get filterAuroraHologramPresetSilverFoil => 'Feuille argentée';

  @override
  String get filterNameBackgroundBlend => 'Fondu d\'arrière-plan';

  @override
  String get filterBackgroundBlendColorLabel => 'Couleur de fondu';

  @override
  String get filterBackgroundBlendAutoLabel =>
      'Détection automatique (touchez pour ajuster)';

  @override
  String get filterBackgroundBlendAutoReset => 'Revenir à l\'automatique';

  @override
  String get filterBackgroundBlendDirection => 'Direction ombre/lumière (liée)';

  @override
  String get filterBackgroundBlendLength => 'Longueur ombre/lumière (liée)';

  @override
  String get filterBackgroundBlendBlur => 'Intensité du flou';

  @override
  String get filterPixelateBlockSize => 'Taille des blocs';

  @override
  String get filterLensDistortionOffsetY =>
      'Ajustement fin du centre (vertical)';

  @override
  String get filterLensDistortionNoMaskHint =>
      'S\'applique uniquement aux zones peintes sur un calque de sélection. Ajoutez d\'abord un « Calque de sélection » dans la liste des calques, puis peignez la zone que vous souhaitez transformer en lentille (par exemple les verres de lunettes).';

  @override
  String get tipsStockingDenierTitle =>
      'La finesse des trames bas/collants varie selon le denier';

  @override
  String get tipsStockingDenierDesc =>
      'Les nouvelles trames bas/collants de la liste ont un maillage plus serré pour les deniers faibles (tissu plus fin) ; la plus basse, 10 deniers, est volontairement assez fine pour produire du moiré selon la résolution d\'affichage ou d\'export. Les collants à denier élevé utilisent un espacement plus large pour un rendu plus opaque : choisissez celle qui convient aux jambes du personnage.';

  @override
  String get tipsFisheyeChromaticTitle =>
      'Utilisez les filtres œil de poisson et aberration chromatique pour une distorsion et un liseré façon objectif';

  @override
  String get tipsFisheyeChromaticDesc =>
      'Le filtre œil de poisson bombe le centre de l\'image et comprime les bords, recréant la courbure d\'une prise de vue grand angle ou fisheye. Le filtre d\'aberration chromatique décale légèrement les canaux RVB pour recréer le liseré coloré typique d\'un objectif bon marché. Les deux sont disponibles à la fois comme filtres de dessin (appliqués directement à un calque) et comme filtres d\'effet (appliqués sur une plage de la timeline).';

  @override
  String get tipsLensDistortionTitle =>
      'Recréez la distorsion des verres correcteurs avec un calque de sélection et le filtre de distorsion de lentille';

  @override
  String get tipsLensDistortionDesc =>
      'Ajoutez un « Calque de sélection » à la liste des calques et peignez la zone des verres de lunettes avec n\'importe quel outil de dessin habituel : la déformation locale du filtre de distorsion de lentille s\'applique alors uniquement à cette zone peinte. Le curseur de puissance rétrécit la zone dans un sens concave (myopie) pour les valeurs négatives et l\'agrandit dans un sens convexe (hypermétropie) pour les valeurs positives ; vous pouvez aussi ajuster finement la position du centre. Vous pouvez peindre les deux verres à la fois et appliquer l\'effet aux deux en même temps. Le calque de sélection lui-même n\'apparaît jamais dans les exports ni dans l\'œuvre finale. Il est aussi pratique pour recréer l\'aspect d\'un paysage vu à travers l\'objectif d\'un appareil photo : peignez une large zone, comme l\'arrière-plan, avec un calque de sélection et appliquez une puissance légère.';

  @override
  String get tipsLineArtExtractionTitle =>
      'Extraire un dessin au trait en combinant réglage des couleurs, seuil et transparence par luminosité';

  @override
  String get tipsLineArtExtractionDesc =>
      'Augmentez le contraste avec le réglage des couleurs pour faire ressortir les traits, puis utilisez le filtre de seuil pour diviser l\'image en noir et blanc purs : les traits se séparent nettement du reste. Le curseur de seuil permet d\'ajuster librement l\'épaisseur du trait et son aspect plus ou moins estompé. Enfin, utilisez « Transparence par luminosité (gris) » dans le menu à trois points du calque pour rendre transparentes les zones blanches (tout sauf les traits), ne laissant que le dessin au trait. Pratique pour extraire un dessin au trait propre à partir d\'une photo ou d\'une esquisse.';

  @override
  String get tipsLineColorUsageTitle =>
      'Choisir le mode de couleur du trait selon l’usage améliore le rendu';

  @override
  String get tipsLineColorUsageDesc =>
      'Pour le contour d’une partie, Tracé couleur / Fusion du trait garde le bord lisible sans qu’il flotte sur le dessin. Pour les ombres et les lumières, aligner la couleur du trait sur celle du remplissage fait disparaître le trait lui-même. Et une couleur spécifiée volontairement différente peut donner à une série son identité propre.';

  @override
  String get tipsBlushAutofillTitle =>
      'Même un rougissement doux peut être rempli automatiquement';

  @override
  String get tipsBlushAutofillDesc =>
      'Réglez la couleur du trait sur une couleur spécifiée transparente, et le remplissage sur un dégradé Radial (centre→extérieur) avec le rose du rougissement et le transparent comme ses deux couleurs : cela ne dépose que le rougissement des joues, en douceur, sur la peau. Ajustez l’opacité du rougissement et la position du point de couleur pour un fondu encore plus naturel.';

  @override
  String get autofillPartResetTraceButton => 'Réinitialiser';

  @override
  String get premiumScreenTitle => 'Premium';

  @override
  String get premiumComparisonPremium => 'Premium';

  @override
  String premiumRegisteredDateLabel(String date) {
    return 'Inscription : $date';
  }

  @override
  String premiumNextRenewalDateLabel(String date) {
    return 'Prochain renouvellement : $date';
  }

  @override
  String get workspaceApplyCurrentButton =>
      'Appliquer l\'espace de travail configuré';

  @override
  String get workspaceAppliedSnackbar =>
      'Les réglages de l\'espace de travail ont été appliqués.';

  @override
  String get workspaceSaveAsButton =>
      'Enregistrer l\'espace de travail sous... / Écraser';

  @override
  String get workspaceShareButton => 'Partager l\'espace de travail';

  @override
  String get workspaceShareSelectTitle =>
      'Sélectionnez un espace de travail à partager';

  @override
  String workspaceShareFailedSnackbar(String error) {
    return 'Échec du partage : $error';
  }

  @override
  String get workspaceImportFromFileButton => 'Importer depuis un fichier';

  @override
  String workspaceImportFailedSnackbar(String error) {
    return 'Échec de l\'importation : $error';
  }

  @override
  String get workspaceNameRequiredError => 'Veuillez saisir un nom.';

  @override
  String get workspaceNoSavedPresets =>
      'Aucun espace de travail enregistré pour l\'instant.';

  @override
  String get workspaceOverwriteSelectTitle =>
      'Sélectionnez un espace de travail à écraser';

  @override
  String get workspaceOverwriteConfirmTitle => 'Confirmer l\'écrasement';

  @override
  String workspaceOverwriteConfirmBody(String name) {
    return 'Ceci va écraser « $name » avec les réglages actuels. Son contenu précédent sera perdu. Continuer ?';
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
  String get communityScreenTitle => 'Place des œuvres';

  @override
  String get communityTabNew => 'Nouveautés';

  @override
  String get communityTabRanking => 'Classement';

  @override
  String get communityTabFavoriteAuthors => 'Abonnements';

  @override
  String get communitySearchHint =>
      'Rechercher par titre ou nom d\'utilisateur';

  @override
  String get communityEmptyState => 'Aucune œuvre à afficher';

  @override
  String communitySearchNoResults(String query) {
    return 'Aucune œuvre ne correspond à « $query »';
  }

  @override
  String get communityTagSearchHint => 'Rechercher par tag';

  @override
  String get communityTagSearchModeOnTooltip =>
      'Recherche par tag : ACTIVÉE (touchez pour revenir à la recherche par titre/nom d\'utilisateur)';

  @override
  String get communityTagSearchModeOffTooltip =>
      'Passer à la recherche par tag';

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
  String get communityPostComingSoonTitle => 'La publication arrive bientôt';

  @override
  String get communityPostComingSoonBody =>
      'La fonctionnalité de publication de vidéos est encore en cours de développement. Restez à l\'écoute des prochaines mises à jour.';

  @override
  String get communityPostInfoTitle => 'La publication se fait via YouTube';

  @override
  String get communityPostInfoBody =>
      'Lorsque vous publiez sur la Place des œuvres, votre création est publiée via YouTube. NIARIM ne transmet, ne collecte ni ne stocke le fichier vidéo lui-même sur les serveurs du développeur : publier signifie envoyer la vidéo depuis l\'écran de YouTube.\n\nSi vous réglez la vidéo sur « Non répertoriée » côté YouTube, elle n\'apparaîtra pas dans les listes publiques de YouTube et ne sera publiée que sur la Place des œuvres.\n\n(La fonctionnalité de publication de vidéos est encore en cours de développement. Restez à l\'écoute des prochaines mises à jour.)';

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
  String get communityRankingSortViews => 'Vues';

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
  String get communityWorkDetailViewOnYoutubeComingSoonSnackbar =>
      'L\'intégration YouTube arrive bientôt';

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
      'Visible : affiché dans Nouveautés, Classements et la liste des œuvres de cet auteur.';

  @override
  String get communityVisibilityHiddenDesc =>
      'Masqué : retiré de Nouveautés, Classements et la liste des œuvres de cet auteur (réglage indépendant de la visibilité côté YouTube).';

  @override
  String get communityVisibilityHiddenNotice =>
      'Le créateur a masqué cette œuvre sur la Place des œuvres.';

  @override
  String get communityVisibilityHiddenBadge => 'Masqué';

  @override
  String get communityWorkDetailTitle => 'Détails de l\'œuvre';

  @override
  String get communityWorkNotFoundMessage => 'Cette œuvre est introuvable';

  @override
  String get communityFloatingPreviewDetailButton => 'Détails';

  @override
  String get communityFloatingPreviewPlayTooltip => 'Lecture';

  @override
  String get communityFloatingPreviewPauseTooltip => 'Pause';

  @override
  String get communityReportDialogTitle => 'Signaler cette œuvre';

  @override
  String get communityReportDialogBody =>
      'Veuillez choisir un motif de signalement.';

  @override
  String get communityReportReasonInappropriate => 'Contenu inapproprié';

  @override
  String get communityReportReasonCopyright =>
      'Suspicion d\'atteinte aux droits d\'auteur';

  @override
  String get communityReportReasonSpam => 'Spam ou publications répétées';

  @override
  String get communityReportReasonOther => 'Autre';

  @override
  String get communityReportSubmitButton => 'Envoyer le signalement';

  @override
  String get communityReportDetailLabel => 'Détails';

  @override
  String get communityReportDetailHint => 'Décrivez précisément le problème';

  @override
  String get communityReportDetailRequiredError =>
      'Veuillez saisir des détails';

  @override
  String get communityReportComingSoonSnackbar =>
      'Le signalement arrive bientôt. Rien n\'a réellement été envoyé.';

  @override
  String communityBlockConfirmTitle(String name) {
    return 'Bloquer « $name » ?';
  }

  @override
  String get communityBlockConfirmBody =>
      'Le blocage masque les œuvres de ce créateur dans vos listes.';

  @override
  String get communityBlockComingSoonSnackbar =>
      'Le blocage arrive bientôt. Rien n\'a réellement été appliqué.';

  @override
  String communityAuthorWorksCount(int count) {
    return '$count œuvres';
  }

  @override
  String communityAuthorFollowerCount(int count) {
    return '$count abonnés';
  }

  @override
  String get communityFollowersPublicToggleTitle =>
      'Rendre les listes d\'abonnements/abonnés publiques';

  @override
  String get communityFollowersPublicToggleDesc =>
      'Si activé, les autres utilisateurs pourront voir vos listes d\'abonnements et d\'abonnés depuis cette page. Privées par défaut.';

  @override
  String get communityFollowersListTitle => 'Abonnés';

  @override
  String get communityFollowersListEmpty => 'Aucun abonné pour le moment';

  @override
  String communityFollowersListHiddenNote(int count) {
    return '$count de plus non affichés, masqués par leurs propres paramètres de confidentialité';
  }

  @override
  String communityAuthorFollowingCount(int count) {
    return '$count abonnements';
  }

  @override
  String get communityFollowingListTitle => 'Abonnements';

  @override
  String get communityFollowingListEmpty => 'Ne suit personne pour le moment';

  @override
  String get communityFollowNotificationsTooltip => 'Notifications';

  @override
  String get communityFollowNotificationsTitle => 'Notifications d\'abonnement';

  @override
  String get communityFollowNotificationsEmpty => 'Aucune notification';

  @override
  String communityFollowNotificationBody(String name) {
    return '$name vous suit désormais';
  }

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
  String get communityRepostButton => 'Repartager';

  @override
  String get communityRepostedButton => 'Repartagé';

  @override
  String communityRepostedByBadge(String name) {
    return 'Repartagé par $name';
  }

  @override
  String get communityAuthorTabWorks => 'Œuvres';

  @override
  String get communityAuthorTabBookmarks => 'Favoris';

  @override
  String get communityBookmarksPublicToggleTitle =>
      'Rendre la liste de favoris publique';

  @override
  String get communityBookmarksPublicToggleDesc =>
      'Si activé, les autres utilisateurs pourront voir votre liste de favoris depuis cette page. Privée par défaut.';

  @override
  String get communityBookmarksPrivateNotice =>
      'Cet utilisateur a défini sa liste de favoris comme privée.';

  @override
  String get communityBookmarksEmptyMessage => 'Aucune œuvre en favoris';

  @override
  String get communityShortsBadge => 'Vertical';

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
    return 'Couleurs : $count';
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
      'Aucune palette enregistrée. Appuyez sur « Ajouter » pour en créer une.';

  @override
  String get pixelArtPalettePickerApplyButton => 'Appliquer';

  @override
  String get storageScreenTitle => 'Libérer de l\'espace';

  @override
  String get storageDeviceChartTitle => 'Stockage de l\'appareil';

  @override
  String get storageBreakdownChartTitle => 'Répartition NIARIM';

  @override
  String get storageActionsTitle => 'Organiser';

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
      'Brosses/tons/tampons/polices personnalisés';

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
  String get storageEmptyTrashButton => 'Vider la corbeille';

  @override
  String get storageOrganizeProjectsButton => 'Organiser les projets';

  @override
  String get storageEraseAllButton =>
      'Effacer toutes les données (réinitialiser)';

  @override
  String storageClearCacheDoneSnackbar(String size) {
    return '$size de cache libérés';
  }

  @override
  String get storageEraseAllConfirmTitle => 'Effacer toutes les données ?';

  @override
  String get storageEraseAllConfirmBody =>
      'Ceci supprime définitivement toutes les données de NIARIM : projets, matériaux, fichiers exportés, brosses/tons/tampons/polices personnalisés et paramètres. Action irréversible. Redémarrez l\'application ensuite.';

  @override
  String get storageEraseAllDoneSnackbar =>
      'Toutes les données ont été effacées. Veuillez redémarrer l\'application.';

  @override
  String get homeDrawerStorage => 'Libérer de l\'espace';

  @override
  String get helpStorageTitle => 'Libérer de l\'espace';

  @override
  String get helpStorageDesc =>
      'Consultez l\'espace utilisé par NIARIM sur votre appareil, ainsi qu\'une répartition de son contenu (projets, matériaux, fichiers exportés, brosses/tons/tampons/polices personnalisés, cache et corbeille) sous forme de graphiques circulaires. Vous pouvez vider le cache, supprimer les matériaux inutilisés dans tous les projets, vider la corbeille, organiser vos projets ou effacer toutes les données (réinitialiser).';

  @override
  String get colorPickerImportPaletteTooltip => 'Importer une palette';

  @override
  String get colorPickerSharePaletteTooltip => 'Partager';

  @override
  String get colorPickerShareViaFile => 'Partager en tant que fichier';

  @override
  String colorPickerShareFailedSnackbar(String error) {
    return 'Échec du partage : $error';
  }

  @override
  String get colorPickerShareViaQr => 'Partager via un code QR';

  @override
  String get qrShareTooLargeHint =>
      'Trop de couleurs pour partager via un code QR (utilisez le partage de fichier)';

  @override
  String get colorPickerImportViaFile => 'Choisir un fichier';

  @override
  String colorPickerImportFailedSnackbar(String error) {
    return 'Échec de l\'importation : $error';
  }

  @override
  String get colorPickerImportViaQr => 'Coller le texte du code QR';

  @override
  String get qrImportFailedError =>
      'Échec de l\'importation. Vérifiez que le texte est correct.';

  @override
  String get qrImportHint =>
      'Scannez le code QR affiché sur l\'autre appareil avec une application caméra standard, puis collez ici le texte copié.';

  @override
  String get qrImportFieldHint => 'Collez le texte scanné';

  @override
  String get qrImportPasteButton => 'Coller depuis le presse-papiers';

  @override
  String get qrImportSubmitButton => 'Importer';

  @override
  String get qrShareHint =>
      'Scannez ce code QR avec une application caméra standard pour copier le texte. Sur l\'autre appareil, utilisez « Importer » pour coller le texte copié.';

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
  String get brushSettingsEdgeJitterSubtitle =>
      'Rend le bord légèrement irrégulier pour imiter le bavage de l\'encre';

  @override
  String get brushSettingsEdgeJitterStrengthLabel => 'Intensité';
}
