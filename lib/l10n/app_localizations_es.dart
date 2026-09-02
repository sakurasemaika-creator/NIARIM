// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'NIARIM';

  @override
  String get homeTabProjects => 'Proyectos';

  @override
  String get homeTabShared => 'Compartidos';

  @override
  String get homeTabTrash => 'Papelera';

  @override
  String get homeTabWorks => 'Obras';

  @override
  String get homeTabBookmarked => 'Guardados';

  @override
  String get homeBookmarkedComingSoonTitle => 'Próximamente';

  @override
  String get homeBookmarkedComingSoonBody =>
      'Cuando esté disponible la función «Ver las animaciones de todos», aquí aparecerán las obras de otros usuarios que hayas guardado.';

  @override
  String get homeSearchHint => 'Buscar por nombre de proyecto';

  @override
  String get homeBackToSplashTooltip => 'Volver a la pantalla de inicio';

  @override
  String get homeFavoritesOnly => 'Favoritos';

  @override
  String get homeAddSheetNewProject => 'Nuevo proyecto';

  @override
  String get homeAddSheetNewFolder => 'Nueva carpeta';

  @override
  String get homeSelectionAllSelect => 'Seleccionar todo';

  @override
  String get homeSelectionAllDeselect => 'Deseleccionar todo';

  @override
  String get homeSelectionAddFavorite => 'Añadir a favoritos';

  @override
  String get homeSelectionRemoveFavorite => 'Quitar de favoritos';

  @override
  String homeSelectionCount(int count) {
    return '$count seleccionado(s)';
  }

  @override
  String get homeMoveToTrash => 'Mover a la papelera';

  @override
  String homeMoveToTrashConfirm(int count) {
    return '¿Mover $count elemento(s) a la papelera?';
  }

  @override
  String get commonMove => 'Mover';

  @override
  String get homeShareFileDialogTitle => 'Archivo compartido';

  @override
  String get homeShareFileDialogContent =>
      '¿Duplicar este archivo compartido y guardarlo como un proyecto normal?';

  @override
  String homeMissingFontsSnackbar(String names) {
    return 'Faltan fuentes: $names';
  }

  @override
  String get homeSharedImportedSnackbar => 'Añadido a la pestaña Proyectos';

  @override
  String homeSharedImportFailedSnackbar(String error) {
    return 'Error al cargar el archivo compartido: $error';
  }

  @override
  String get homeViewModeLarge => 'Grande';

  @override
  String get homeViewModeMedium => 'Mediano';

  @override
  String get homeViewModeSmall => 'Pequeño';

  @override
  String get homeViewModeDetail => 'Detalle';

  @override
  String get homeSortNameAsc => 'Nombre ↑';

  @override
  String get homeSortNameDesc => 'Nombre ↓';

  @override
  String get homeSortUpdatedAsc => 'Actualizado ↑';

  @override
  String get homeSortUpdatedDesc => 'Actualizado ↓';

  @override
  String get homeSortFieldName => 'Nombre';

  @override
  String get homeSortFieldUpdated => 'Actualizado';

  @override
  String get homeSortDirectionAscTooltip =>
      'Ascendente (toca para cambiar a descendente)';

  @override
  String get homeSortDirectionDescTooltip =>
      'Descendente (toca para cambiar a ascendente)';

  @override
  String get homeSharedEmpty => 'No hay proyectos compartidos';

  @override
  String homeProjectMeta(int fps, int duration) {
    return '${fps}fps · ${duration}s';
  }

  @override
  String get homeTrashEmpty => 'La papelera está vacía';

  @override
  String homeTrashDeletedOn(String date) {
    return 'Eliminado el $date';
  }

  @override
  String get homePermanentDelete => 'Eliminar permanentemente';

  @override
  String get homePermanentDeleteConfirmTitle => '¿Eliminar permanentemente?';

  @override
  String get homePermanentDeleteConfirmBody =>
      'Esta acción no se puede deshacer.';

  @override
  String get homeWorksEmpty => 'Aún no hay obras exportadas';

  @override
  String get homeWorksEmptyHint =>
      'Exporta un vídeo o GIF desde el lienzo y aparecerá aquí';

  @override
  String get homeShareOpenWith => 'Compartir / Abrir en Fotos';

  @override
  String homeWorkDeleteConfirmTitle(String name) {
    return '¿Eliminar $name?';
  }

  @override
  String get homeWorkDeleteConfirmBody =>
      'Se eliminará el archivo exportado de este dispositivo. Esta acción no se puede deshacer.';

  @override
  String get homePreviewFailed => 'No se puede reproducir la vista previa';

  @override
  String get homeFirstLaunchMessage =>
      'Puedes crear animaciones dibujadas a mano';

  @override
  String get homeFirstLaunchStart => 'Comenzar';

  @override
  String get settingsScreenTitle => 'Ajustes';

  @override
  String get settingsBasicTitle => 'General';

  @override
  String get settingsBasicSubtitle => 'FPS, color de fondo, idioma';

  @override
  String get settingsBasicSheetTitle => 'Ajustes generales';

  @override
  String get settingsDefaultFps => 'FPS predeterminados';

  @override
  String get settingsDefaultFpsSubtitle =>
      'Valor inicial para nuevos proyectos';

  @override
  String get settingsLanguage => 'Idioma';

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
  String get settingsSearchHint => 'Buscar en ajustes...';

  @override
  String get settingsPerformanceTitle => 'Rendimiento';

  @override
  String get settingsPerformanceSubtitle =>
      'Calidad, historial de deshacer, papelera, rendimiento';

  @override
  String get settingsGestureTitle => 'Gestos';

  @override
  String get settingsGestureSubtitle => 'Toque con dos dedos, pulsación larga';

  @override
  String get settingsPenTitle => 'Entrada de lápiz';

  @override
  String get settingsPenSubtitle => 'Presión, inclinación, botones del lápiz';

  @override
  String get settingsWorkspaceTitle => 'Espacio de trabajo';

  @override
  String get settingsWorkspaceSubtitle =>
      'Edición de la barra de herramientas, disposición de paneles';

  @override
  String get settingsBucketTitle => 'Cubo de pintura';

  @override
  String get settingsBucketSubtitle => 'Tolerancia, expansión, bajo las líneas';

  @override
  String get settingsThemeTitle => 'Tema y apariencia';

  @override
  String get settingsThemeSubtitle => 'Ajustes de tema, espacio de trabajo';

  @override
  String get settingsWatermarkTitle => 'Marca de agua';

  @override
  String get settingsWatermarkSubtitle => 'Marca de agua personalizada';

  @override
  String get settingsTransferTitle => 'Transferencia';

  @override
  String get settingsTransferSubtitle =>
      'Exportar/importar ajustes, materiales y pinceles a otro dispositivo';

  @override
  String get settingsFontTitle => 'Gestión de fuentes';

  @override
  String get settingsFontSubtitle =>
      'Añadir, buscar y eliminar fuentes TTF/OTF';

  @override
  String get settingsNoResults => 'No se encontraron ajustes coincidentes';

  @override
  String get settingsTermsLicense => 'Términos y licencias';

  @override
  String get settingsDrawingAreaTitle => 'Área de dibujo predeterminada';

  @override
  String get settingsDrawingAreaHint =>
      'Se usa como valor inicial al crear un nuevo proyecto.';

  @override
  String get settingsDrawingAreaWiden => 'Ampliar área de dibujo';

  @override
  String get settingsDrawingAreaScale => 'Escala';

  @override
  String settingsScaleValue(String scale) {
    return '×$scale';
  }

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonCreate => 'Crear';

  @override
  String get commonChange => 'Cambiar';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get confirmDeleteGenericBody =>
      '¿Seguro que quieres eliminar esto? Esta acción no se puede deshacer.';

  @override
  String confirmDeleteNamedBody(String name) {
    return '¿Eliminar «$name»? Esta acción no se puede deshacer.';
  }

  @override
  String get commonFavoriteDeleteBlocked =>
      'No se puede eliminar un elemento favorito. Quítalo primero de favoritos.';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonRestore => 'Restaurar';

  @override
  String get commonClose => 'Cerrar';

  @override
  String get commonRename => 'Renombrar';

  @override
  String get commonCopy => 'Copiar';

  @override
  String get commonCut => 'Cortar';

  @override
  String get commonPaste => 'Pegar';

  @override
  String get commonDuplicate => 'Duplicar';

  @override
  String homePasteTooltip(int count) {
    return 'Pegar $count elemento(s)';
  }

  @override
  String get homePasteSnackbar => 'Pegado';

  @override
  String get commonOk => 'Aceptar';

  @override
  String get gestureSettingsTitle => 'Ajustes de gestos';

  @override
  String get gestureTwoFingerTap => 'Toque con dos dedos';

  @override
  String get gestureThreeFingerTap => 'Toque con tres dedos';

  @override
  String get gestureTwoFingerSwipe => 'Deslizar horizontalmente con dos dedos';

  @override
  String get gestureLongPress => 'Pulsación larga';

  @override
  String get gestureHoldEyedropperSection => 'Cuentagotas al mantener pulsado';

  @override
  String get gestureHoldEyedropperTitle =>
      'Activar el cuentagotas al mantener pulsado';

  @override
  String get gestureHoldEyedropperHint =>
      'Mientras dibujas con el lápiz o la goma, mantener el dedo quieto un momento toma el color de esa posición como color actual.';

  @override
  String get gestureHoldEyedropperDurationLabel => 'Duración de espera';

  @override
  String gestureHoldEyedropperSecondsValue(String seconds) {
    return '$seconds s';
  }

  @override
  String get gestureActionEyedropper => 'Cuentagotas';

  @override
  String get gestureActionPanTool => 'Herramienta de mano';

  @override
  String get gestureActionEraserToggle => 'Alternar goma de borrar';

  @override
  String get gestureActionBrushToggle => 'Alternar pincel';

  @override
  String get gestureActionFrameMove => 'Cambiar de fotograma';

  @override
  String get gestureActionNextTool => 'Cambio rápido de herramienta';

  @override
  String get gestureActionOnionSkinToggle => 'Activar/desactivar papel cebolla';

  @override
  String get gestureActionNone => 'No hacer nada';

  @override
  String get homeDrawerAppTagline =>
      'App de creación de animación dibujada a mano';

  @override
  String get homeDrawerAutofillPreset => 'Ajustes de relleno automático';

  @override
  String get homeDrawerSettings => 'Ajustes';

  @override
  String get homeDrawerHelp => 'Ayuda';

  @override
  String get homeDrawerTips => 'Consejos';

  @override
  String get homeDrawerPremium => 'Premium';

  @override
  String get gestureActionNoneShort => 'Ninguna';

  @override
  String get pressureTryDrawHint =>
      'Puedes probar a dibujar con este ajuste (con un lápiz óptico se refleja la presión real)';

  @override
  String get pressureTryDrawClear => 'Borrar';

  @override
  String get penSettingsTitle => 'Ajustes de entrada de lápiz';

  @override
  String get penSettingsCurveSection => 'Curva de presión';

  @override
  String get penSettingsCurveHint =>
      'Un ajuste más débil hace que la presión aumente gradualmente; uno más fuerte hace que aumente de forma pronunciada.';

  @override
  String get penSettingsCurveWeak => 'Débil';

  @override
  String get penSettingsCurveNormal => 'Normal';

  @override
  String get penSettingsCurveStrong => 'Fuerte';

  @override
  String get penSettingsCurveCustom => 'Personalizada';

  @override
  String get penSettingsCustomGraphHint =>
      'Toca un espacio vacío del gráfico para añadir un punto (hasta 10), arrastra un punto para moverlo o tócalo dos veces para eliminarlo (los puntos de inicio y fin no se pueden eliminar).';

  @override
  String get penSettingsResetCurveButton =>
      'Restablecer valores predeterminados';

  @override
  String get penSettingsPerBrushNote =>
      '* El ajuste de presión \"Aplicar al tamaño/opacidad\" es específico de cada pincel (cámbialo en el panel de ajustes del pincel).';

  @override
  String get penSettingsButtonSection => 'Ajustes de botones del lápiz';

  @override
  String get penSettingsButton1 => 'Botón 1';

  @override
  String get penSettingsButton2 => 'Botón 2';

  @override
  String get bucketSettingsTitle => 'Ajustes del cubo de pintura';

  @override
  String get bucketSettingsToleranceSection => 'Tolerancia';

  @override
  String get bucketSettingsToleranceHint =>
      'Ajusta cuánta diferencia de color respecto al píxel tocado se sigue considerando la misma área. Cuanto mayor sea el valor, más se extiende el relleno incluso con bordes de color difusos.';

  @override
  String get bucketSettingsExpandSection => 'Expansión';

  @override
  String get bucketSettingsExpandHint =>
      'Expande el área rellenada hacia fuera el número de píxeles indicado, para cubrir pequeños huecos cerca del dibujo de líneas.';

  @override
  String get bucketSettingsUnderLineTitle => 'Pasar por debajo de las líneas';

  @override
  String get bucketSettingsUnderLineHint =>
      'En vez de pintar sobre el dibujo de líneas, la expansión se combina detrás de los píxeles existentes: la línea conserva su aspecto mientras se cierran los huecos en sus bordes suavizados.';

  @override
  String get bucketSettingsUnderLineDisabledHint =>
      'No tiene efecto cuando «Expansión» es 0 px.';

  @override
  String fontCatalogSearchHint(int count) {
    return 'Buscar por nombre de fuente... ($count fuentes)';
  }

  @override
  String get fontCatalogAll => 'Todas';

  @override
  String get fontCatalogNoResults => 'No se encontraron fuentes coincidentes';

  @override
  String get rulerPanelTitle => 'Regla';

  @override
  String get rulerTypeLine => 'Regla recta';

  @override
  String get rulerTypeEllipse => 'Regla elíptica';

  @override
  String get rulerTypeRadial => 'Regla de líneas radiales';

  @override
  String get rulerTypeOnePoint => 'Perspectiva de un punto';

  @override
  String get rulerTypeTwoPoint => 'Perspectiva de dos puntos';

  @override
  String get rulerTypeThreePoint => 'Perspectiva de tres puntos';

  @override
  String get rulerDivisions => 'Divisiones';

  @override
  String get transferScreenTitle => 'Transferencia (.niatra)';

  @override
  String get transferInstructionHint =>
      'Selecciona los elementos que quieres transferir a otro dispositivo.';

  @override
  String get transferItemSettings => 'Ajustes';

  @override
  String get transferItemMaterials => 'Materiales';

  @override
  String get transferItemBrush => 'Pinceles';

  @override
  String get transferItemPresets => 'Ajustes de relleno automático';

  @override
  String get transferItemTheme => 'Tema';

  @override
  String get transferItemPalette =>
      'Paletas (selector de color y arte de píxeles)';

  @override
  String get transferProjectsSectionTitle => 'Proyectos en curso (opcional)';

  @override
  String get transferProjectsHint =>
      'Selecciona solo los proyectos que quieras incluir en la transferencia. Los proyectos seleccionados se transfieren por completo, incluidos sus materiales y fuentes.';

  @override
  String get transferProjectsEmpty => 'Aún no hay proyectos.';

  @override
  String get transferImport => 'Importar';

  @override
  String get transferExport => 'Exportar';

  @override
  String get transferExportSuccessSnackbar => 'Archivo .niatra exportado';

  @override
  String transferExportFailedSnackbar(String error) {
    return 'Error al exportar: $error';
  }

  @override
  String get transferImportSuccessSnackbar => 'Archivo .niatra importado';

  @override
  String transferImportFailedSnackbar(String error) {
    return 'Error al importar: $error';
  }

  @override
  String get folderManagementTitle => 'Gestión de carpetas';

  @override
  String get folderManagementCreateNew => 'Nueva';

  @override
  String get folderManagementEmpty => 'Aún no hay carpetas';

  @override
  String get folderNameLabel => 'Nombre de la carpeta';

  @override
  String get folderMoveToTitle => 'Mover a carpeta';

  @override
  String get folderNone => 'Sin carpeta';

  @override
  String get creativeAssetNameLabel => 'Nombre';

  @override
  String get commonAdd => 'Añadir';

  @override
  String get commonSearch => 'Buscar';

  @override
  String get autofillPresetSelectionTitle =>
      'Ajustes de relleno automático a usar';

  @override
  String get autofillPresetSelectionHint =>
      'Elegir solo los ajustes de relleno automático usados en este proyecto mantiene la lista de asignación de partes más corta y fácil de revisar.';

  @override
  String autofillPresetSelectionPartCount(int count) {
    return '$count partes';
  }

  @override
  String get autofillPresetSelectionButton =>
      'Seleccionar ajustes de relleno automático a usar';

  @override
  String get autofillPresetSelectionAllLabel => 'Usar todos';

  @override
  String autofillPresetSelectionCountLabel(int count) {
    return '$count seleccionados';
  }

  @override
  String get commonEdit => 'Editar';

  @override
  String get commonFavoriteToggle => 'Alternar favorito';

  @override
  String get commonIncrease => 'Aumentar';

  @override
  String get commonDecrease => 'Disminuir';

  @override
  String get commonPlay => 'Reproducir';

  @override
  String get commonPause => 'Pausar';

  @override
  String get fontCatalogDownloadTooltip => 'Descargar fuente';

  @override
  String get timelineBackToCanvasTooltip => 'Guardar y volver al lienzo';

  @override
  String get timelineBackToProjectListTooltip =>
      'Volver a la lista de proyectos';

  @override
  String get timelineBackToProjectListDialogTitle =>
      'Volver a la lista de proyectos';

  @override
  String get timelineBackToProjectListDialogBody =>
      '¿Guardar los cambios antes de volver?';

  @override
  String get timelineBackToProjectListSaveButton => 'Guardar y volver';

  @override
  String get timelineBackToProjectListDiscardButton => 'Volver sin guardar';

  @override
  String get timelineSkipToStart => 'Ir al primer fotograma';

  @override
  String get timelineStepBack => 'Retroceder un fotograma';

  @override
  String get timelineStepForward => 'Avanzar un fotograma';

  @override
  String get timelineSkipToEnd => 'Ir al último fotograma';

  @override
  String get timelineLoopOnTooltip =>
      'Reproducción en bucle: ACTIVADA (toca para desactivar)';

  @override
  String get timelineLoopOffTooltip =>
      'Reproducción en bucle: DESACTIVADA (toca para activar)';

  @override
  String get quickToolPanelTitle => 'Ajustes de herramientas rápidas';

  @override
  String get quickToolEmpty => 'No hay herramientas registradas';

  @override
  String get quickToolAddCurrentBrush => 'Añadir pincel actual';

  @override
  String get quickToolEraser => 'Goma de borrar';

  @override
  String get quickToolEyedropper => 'Cuentagotas';

  @override
  String get quickToolBucket => 'Cubo de pintura';

  @override
  String quickToolSizeDialogTitle(String brushName) {
    return 'Tamaño de $brushName';
  }

  @override
  String get settingsShortcutTitle => 'Atajos';

  @override
  String get settingsShortcutSubtitle =>
      'Asigna herramientas y acciones al teclado o dispositivo de mano izquierda';

  @override
  String get shortcutSettingsTitle => 'Atajos';

  @override
  String get shortcutSettingsHint =>
      'Asigna teclas del teclado o de un dispositivo de mano izquierda a herramientas (hasta un pincel y tamaño concretos) o a acciones como Deshacer/Rehacer. Funciona tanto en el modo Lienzo como en el modo Línea de tiempo.';

  @override
  String get shortcutEmpty => 'No hay atajos registrados';

  @override
  String get shortcutCaptureTitle => 'Pulsa una tecla';

  @override
  String get shortcutCaptureHint =>
      'Pulsa la combinación de teclas que quieras asignar (puedes mantener Ctrl/Shift/Alt, etc. a la vez). Pulsa Esc para cancelar.';

  @override
  String shortcutChooseActionTitle(String combo) {
    return '¿Qué debe hacer $combo?';
  }

  @override
  String get shortcutActionTypeTool => 'Elegir una herramienta';

  @override
  String get shortcutActionTypeCommand => 'Acción principal';

  @override
  String get shortcutCommandUndo => 'Deshacer';

  @override
  String get shortcutCommandRedo => 'Rehacer';

  @override
  String get shortcutCommandToggleLayerPanel =>
      'Alternar panel de capas (Lienzo)';

  @override
  String get shortcutCommandPlayPause => 'Reproducir/Pausar (Línea de tiempo)';

  @override
  String get shortcutCommandPreviousFrame =>
      'Fotograma anterior (Línea de tiempo)';

  @override
  String get shortcutCommandNextFrame =>
      'Fotograma siguiente (Línea de tiempo)';

  @override
  String get shortcutCommandSelectAll => 'Seleccionar todo';

  @override
  String get shortcutCommandCopy => 'Copiar';

  @override
  String get shortcutCommandCut => 'Cortar';

  @override
  String get shortcutCommandPaste => 'Pegar';

  @override
  String get shortcutConflictTitle => 'Ya está asignado';

  @override
  String shortcutConflictBody(String combo, String existingLabel) {
    return '$combo ya está asignado a \"$existingLabel\". ¿Deseas sobrescribirlo?';
  }

  @override
  String get shortcutConflictOverwrite => 'Sobrescribir';

  @override
  String get materialListTitle => 'Gestión de materiales';

  @override
  String materialRemoveUnused(int count) {
    return 'Eliminar no usados ($count)';
  }

  @override
  String get materialEmptyTitle => 'No hay materiales';

  @override
  String get materialEmptyHint =>
      'Añade imágenes, vídeos o audio desde la línea de tiempo y aparecerán aquí';

  @override
  String get materialUsedLabel => 'En uso';

  @override
  String get materialUnusedLabel => 'Sin usar';

  @override
  String get materialMissingLabel => '⚠ Falta';

  @override
  String get materialDeleteTooltipUsed =>
      'No se puede eliminar mientras esté en uso';

  @override
  String get materialRemoveOneConfirmTitle => '¿Eliminar este material?';

  @override
  String get materialRemoveUnusedConfirmTitle =>
      '¿Eliminar todos los materiales sin usar?';

  @override
  String get materialRemoveUnusedConfirmBody =>
      'Esto eliminará todos los materiales que no estén referenciados en ninguna parte del proyecto. Esta acción no se puede deshacer.';

  @override
  String materialRemovedSnackbar(int count) {
    return 'Se eliminaron $count material(es) sin usar';
  }

  @override
  String get watermarkEmptyTitle => 'Aún no hay marcas de agua';

  @override
  String get watermarkEmptyHint =>
      'Toca el botón + para añadir una marca de agua de imagen o texto';

  @override
  String get watermarkAddFromImage => 'Añadir desde imagen';

  @override
  String get watermarkAddText => 'Introducir texto';

  @override
  String get watermarkAddedSnackbar => 'Marca de agua añadida';

  @override
  String get watermarkTextDialogTitle => 'Añadir marca de agua de texto';

  @override
  String get watermarkTextFieldLabel => 'Texto a mostrar';

  @override
  String get watermarkTextColorLabel => 'Color del texto';

  @override
  String get watermarkTextColorTapHint => 'Toca para elegir un color';

  @override
  String get watermarkDropShadowLabel => 'Sombra paralela';

  @override
  String get watermarkShadowColorLabel => 'Color de sombra';

  @override
  String get watermarkShadowOffsetXLabel => 'Desplazamiento X de sombra';

  @override
  String get watermarkShadowOffsetYLabel => 'Desplazamiento Y de sombra';

  @override
  String get watermarkShadowBlurLabel => 'Desenfoque de sombra';

  @override
  String get watermarkOutlineLabel => 'Contorno';

  @override
  String get watermarkOutlineColorLabel => 'Color de contorno';

  @override
  String get watermarkOutlineWidthLabel => 'Grosor de contorno';

  @override
  String get premiumActiveLabel => 'Premium activo';

  @override
  String get premiumVsTitle => 'Gratis vs Premium';

  @override
  String get premiumHeroTitle => 'Más libertad con Premium';

  @override
  String get premiumHeroSubtitle =>
      'Sin límite de duración, sin marca de agua, curva de tonos y corrección de niveles, y mucho más: todo queda desbloqueado.';

  @override
  String get premiumHeroHighlightDuration => 'Hasta 2 horas';

  @override
  String get premiumHeroHighlightWatermark => 'Sin marca de agua';

  @override
  String get premiumHeroHighlightGrading => 'Curva de tonos /\nniveles';

  @override
  String get premiumCampaignFreeNote =>
      '* Durante la campaña, todas las funciones Premium anteriores son gratuitas para todos';

  @override
  String get premiumPlanSectionTitle => 'Planes';

  @override
  String get premiumStoreUnavailable =>
      'No se puede conectar con la tienda (las compras solo están disponibles en un dispositivo real o en el entorno de revisión de la tienda)';

  @override
  String get premiumYearlyTitle => 'Plan anual (recomendado)';

  @override
  String get premiumYearlyDescription => 'Equivale a 2 meses gratis';

  @override
  String get premiumYearlyPrice => '¥5.500/año';

  @override
  String get premiumYearlyOriginalPrice => '¥6.600';

  @override
  String get premiumYearlyPerMonthLabel => 'Equivale a ¥458/mes';

  @override
  String get premiumMonthlyTitle => 'Plan mensual';

  @override
  String get premiumRestorePurchases => 'Restaurar compras';

  @override
  String get premiumRestoredSnackbar =>
      'Se restauraron tus compras (si las había)';

  @override
  String get premiumCampaignBannerTitle =>
      '¡Campaña de lanzamiento! Funciones Premium desbloqueadas para todos';

  @override
  String get premiumCampaignBannerBody =>
      'Durante la campaña, todas las funciones Premium (duración de hasta 2 horas, edición del logotipo final, marca de agua, curva de tonos, corrección de niveles) son gratuitas, incluso en el plan gratuito.';

  @override
  String premiumCampaignEndLabel(String date) {
    return 'Hasta el $date';
  }

  @override
  String get premiumComparisonFeature => 'Función';

  @override
  String get premiumComparisonFree => 'Gratis';

  @override
  String get premiumFeatureDrawing => 'Dibujo y animación';

  @override
  String get premiumFeatureTimeline => 'Línea de tiempo';

  @override
  String get premiumFeatureExport => 'Exportación de vídeo';

  @override
  String get premiumFeatureMaxDuration => 'Duración máx.';

  @override
  String get premiumFeatureEndLogo => 'Logotipo final oficial';

  @override
  String get premiumFeatureWatermark => 'Marca de agua';

  @override
  String get premiumFeatureToneCurve => 'Curva de tonos';

  @override
  String get premiumFeatureLevelCorrection => 'Corrección de niveles';

  @override
  String get premiumFeatureAds => 'Anuncios';

  @override
  String get premiumFeatureCommunityUpload =>
      'Publicaciones diarias en la comunidad';

  @override
  String get premiumValueYes => 'Sí';

  @override
  String get premiumValueNo => 'No';

  @override
  String get premiumValueRemovable => 'Se puede quitar';

  @override
  String get premiumValueDuration2Hours => '2 horas';

  @override
  String get premiumValueDuration90Sec => '1,5 min';

  @override
  String get premiumValueUploadFree => '1 obra';

  @override
  String get premiumValueUploadPremium => '3 obras';

  @override
  String get premiumPlanRecommendedBadge => 'Recomendado';

  @override
  String get premiumMonthlyPrice => '¥550/mes';

  @override
  String get toolbarItemPen => 'Pluma G';

  @override
  String get toolbarItemEraser => 'Goma de borrar';

  @override
  String get toolbarItemBucket => 'Cubo de pintura';

  @override
  String get toolbarItemEyedropper => 'Cuentagotas';

  @override
  String get toolbarItemFinger => 'Dedo';

  @override
  String get toolbarItemPan => 'Mano';

  @override
  String get toolbarItemSelect => 'Selección';

  @override
  String get toolbarItemTransform => 'Transformar';

  @override
  String get toolbarItemText => 'Texto';

  @override
  String get toolbarItemShape => 'Forma';

  @override
  String get workspaceScreenTitle => 'Ajustes del espacio de trabajo';

  @override
  String get workspaceToolbarEditSection =>
      'Edición de la barra de herramientas';

  @override
  String get workspaceToolbarEditHint =>
      'Selecciona qué herramientas mostrar con las casillas y arrastra para reordenarlas.';

  @override
  String get workspaceToolbarPcOnlyHint =>
      'Solo se muestra en la barra de herramientas en orientación horizontal';

  @override
  String get workspaceToolbarPanDisabledHint =>
      'No disponible en modo smartphone';

  @override
  String get workspaceResetToolbarDefault =>
      'Restablecer valores predeterminados';

  @override
  String get workspacePanelLayoutSection => 'Disposición de paneles';

  @override
  String get workspaceLeftHandedMode => 'Modo zurdo';

  @override
  String get workspaceLeftHandedSubtitlePc => 'Colocar paneles a la derecha';

  @override
  String get workspaceLeftHandedSubtitleMobile =>
      'Solo disponible en modo PC/DeX';

  @override
  String get workspacePcModeSection => 'Modo PC (DeX)';

  @override
  String get workspacePcModeHint =>
      'En pantallas anchas, la aplicación cambia automáticamente a la disposición profesional con los paneles fijos. Configúralo manualmente aquí si quieres forzarlo.';

  @override
  String get workspacePcModeAuto =>
      'Automático (según el ancho de pantalla, recomendado)';

  @override
  String get workspacePcModeAlwaysPc => 'Siempre modo PC';

  @override
  String get workspacePcModeAlwaysMobile => 'Siempre modo móvil';

  @override
  String get workspaceSaveSection => 'Guardar espacio de trabajo';

  @override
  String get workspaceSaveHint =>
      'Guarda tus ajustes de modo zurdo, modo PC, barra de herramientas y herramientas rápidas con un nombre para poder cargarlos más tarde.';

  @override
  String get workspaceSaveCurrentButton => 'Guardar espacio de trabajo actual';

  @override
  String get workspaceLoadButtonEmpty =>
      'Cargar espacio de trabajo (ninguno guardado)';

  @override
  String get workspaceLoadButton => 'Cargar espacio de trabajo';

  @override
  String get workspaceEmptyToolbar => 'No hay herramientas para mostrar';

  @override
  String get workspaceSaveDialogTitle => 'Guardar espacio de trabajo';

  @override
  String get workspaceSaveDialogLabel =>
      'Nombre (p. ej., Animación, Dibujo lineal)';

  @override
  String get workspaceLoadRightHanded => 'Diestro';

  @override
  String get workspaceLoadLeftHanded => 'Zurdo';

  @override
  String get helpScreenTitle => 'Ayuda';

  @override
  String get helpSearchHint => 'Buscar...';

  @override
  String get helpNoResults => 'No se encontraron elementos coincidentes';

  @override
  String get helpCategoryTool => 'Herramientas';

  @override
  String get helpCategoryLayer => 'Capas';

  @override
  String get helpCategoryAnimation => 'Animación';

  @override
  String get helpCategoryDrawing => 'Dibujo';

  @override
  String get helpCategoryBrush => 'Pincel';

  @override
  String get helpCategoryPenInput => 'Entrada de lápiz';

  @override
  String get helpCategorySave => 'Guardado';

  @override
  String get helpCategoryProjectManagement => 'Gestión de proyectos';

  @override
  String get helpCategoryExport => 'Exportación';

  @override
  String get helpCategoryPremium => 'Premium';

  @override
  String get helpCategorySettings => 'Ajustes';

  @override
  String get helpCategoryCommunity => 'Comunidad';

  @override
  String get helpPenToolTitle => 'Herramienta de pluma';

  @override
  String get helpPenToolDesc =>
      'La herramienta básica para dibujar líneas en el lienzo. Mantén pulsado para cambiar el tipo, tamaño y color del pincel (un doble toque muestra un resumen rápido). Es compatible con la presión y la inclinación de tabletas/lápices ópticos, y ajustar la curva de presión en Ajustes > Entrada de lápiz permite personalizar con precisión cómo la presión afecta al tamaño y la opacidad. Al cambiar de subherramienta de pluma, puedes aplicar tramas o colocar sellos con la misma herramienta.';

  @override
  String get helpEraserToolTitle => 'Herramienta goma de borrar';

  @override
  String get helpEraserToolDesc =>
      'La contraparte de la herramienta de pluma, usada para borrar lo que has dibujado. Al igual que un pincel, puedes ajustar su tamaño y opacidad, y los ajustes de pincel como el desvanecido y la atenuación de trazo también se aplican. En lugar de \"añadir\" a las partes transparentes de una capa, \"elimina\" el dibujo existente, por lo que la capa de abajo se vuelve visible a través de ella.';

  @override
  String get helpBucketToolTitle => 'Herramienta cubo de pintura';

  @override
  String get helpBucketToolDesc =>
      'Rellena un área cerrada de una sola vez. Toca dentro de un área rodeada por líneas y toda el área se rellena con el color (o trama) seleccionado. Si hay huecos en las líneas, el relleno puede extenderse a áreas no deseadas, así que asegúrate de que las líneas estén bien cerradas antes de usarlo. Puedes alternar entre relleno plano y relleno de trama en los ajustes. Los ajustes detallados (tolerancia, expansión en px, pasar por debajo de las líneas) se pueden configurar desde «Cubo de pintura» en los ajustes.';

  @override
  String get helpLassoFillTitle => 'Relleno de lazo';

  @override
  String get helpLassoFillDesc =>
      'Traza con el dedo para formar un área poligonal y luego rellena el interior de una sola vez. A diferencia del cubo de pintura, puedes definir el área tú mismo incluso donde las líneas no estén cerradas, lo que lo hace ideal para formas complejas o áreas con líneas interrumpidas.';

  @override
  String get helpEyedropperToolTitle => 'Herramienta cuentagotas';

  @override
  String get helpEyedropperToolDesc =>
      'Toma el color en la posición tocada y lo establece como color de dibujo. Muestrea el aspecto compuesto de todas las capas tal como se muestra en la pantalla, por lo que capta con precisión el \"color tal como se ve\" incluso donde se superponen varias capas.';

  @override
  String get helpSelectToolTitle => 'Herramienta de selección';

  @override
  String get helpSelectToolDesc =>
      'Selecciona parte del lienzo para poder mover, rotar o escalar solo esa área. Mantén pulsado para elegir entre tres métodos de selección: \"Selección rectangular\", \"Selección de lazo\" (contorno libre), o \"Selección automática\" (varita mágica: agrupa automáticamente áreas de color similar). Mientras hay una selección activa, un contorno marca el área seleccionada en el lienzo, y la misma área permanece fija en todos los fotogramas y capas hasta que la deselecciones.';

  @override
  String get helpFingerToolTitle => 'Herramienta de dedo (distorsión)';

  @override
  String get helpFingerToolDesc =>
      'Distorsiona los píxeles empujándolos en la dirección en la que arrastras el dedo, como si untaras pintura húmeda con un dedo. Se usa menos para correcciones precisas y más cuando quieres distorsionar orgánicamente líneas ya dibujadas para darles más expresión.';

  @override
  String get helpShapeToolTitle => 'Herramienta de forma';

  @override
  String get helpShapeToolDesc =>
      'Dibuja formas precisas como líneas, rectángulos y círculos con un solo gesto. Arrastrar desde el punto inicial hasta el punto final muestra una vista previa en vivo, y se finaliza al levantar el dedo. Útil cuando necesitas líneas rectas o círculos perfectos difíciles de dibujar a mano alzada.';

  @override
  String get helpTextToolTitle => 'Herramienta de texto';

  @override
  String get helpTextToolDesc =>
      'Coloca texto en el lienzo. Puedes elegir la fuente, el tamaño, el color y la dirección de escritura vertical/horizontal. La escritura vertical admite la rotación automática de caracteres alfanuméricos de medio ancho, el tate-chu-yoko (mantener los números en horizontal dentro de texto vertical) y el rubi (furigana). El texto colocado también se graba como píxeles al exportar. Una pantalla donde puedes añadir, buscar y eliminar fuentes disponibles en la herramienta de texto. Las fuentes gratuitas adicionales más allá de las incluidas por defecto se descargan bajo demanda desde aquí, para mantener reducido el tamaño de instalación inicial.';

  @override
  String get helpQuickToolTitle => 'Herramienta rápida';

  @override
  String get helpQuickToolDesc =>
      'Registra combinaciones de pinceles y herramientas que uses a menudo, y alterna entre ellas con un solo toque de botón. Mantén pulsado o desliza hacia arriba el botón ↺ del lienzo para abrir un panel de gestión donde añadir, reordenar y eliminar entradas. Arrastra para cambiar su orden.';

  @override
  String get helpLayerTitle => 'Capas';

  @override
  String get helpLayerDesc =>
      'Un sistema que te permite dibujar en un mismo lienzo repartido en varias \"capas\" transparentes. Al dibujar el lineart, el coloreado y los fondos en capas separadas, puedes rehacer solo el color más tarde o cambiar el fondo sin borrar el lineart. Las capas apiladas más arriba aparecen delante en pantalla. Cada fila de capa tiene botones de un toque para eliminarla o combinarla con la capa de abajo, y un botón en la parte superior del panel de capas permite combinar todas las capas visibles a la vez.';

  @override
  String get helpBlendModeTitle => 'Modo de fusión';

  @override
  String get helpBlendModeDesc =>
      'Cambia como se combina una capa con las capas de debajo. Se usa a menudo al superponer tramas o efectos de color.\nNormal: superpone tal cual.\nMultiplicar: oscurece multiplicando con la capa inferior. La opcion clasica para sombras.\nTrama: aclara sumando luz. Bueno para efectos de brillo.\nSuperponer: oscurece las zonas oscuras y aclara las claras, aumentando el contraste.\nSumar: suma los colores directamente. Bueno para destellos de luz.\nRestar: resta colores, dando un aspecto oscuro y apagado.\nOscurecer: conserva el color mas oscuro entre ambas capas.\nAclarar: conserva el color mas claro entre ambas capas.\nSubexposicion de color: oscurece y satura el color inferior.\nSobreexposicion de color: aclara y satura el color inferior.\nLuz fuerte: una version mas intensa del contraste de Superponer.\nLuz suave: una version mas suave del contraste de Superponer. Buena para sombreados suaves.\nDiferencia: muestra la diferencia entre los dos colores. Util para comprobar desajustes de color.\nMatiz / Saturacion / Color / Luminosidad: aplica solo esa propiedad (matiz, saturacion, color o brillo) de esta capa sobre la de abajo.';

  @override
  String get helpClippingTitle => 'Recorte';

  @override
  String get helpClippingDesc =>
      'Restringe el dibujo únicamente a los píxeles opacos de la capa situada justo debajo. Cuando quieras colorear sin salirte de las líneas, activar el recorte en una capa de coloreado colocada sobre una capa de líneas elimina el riesgo de dibujar accidentalmente fuera de las líneas.';

  @override
  String get helpCommonLayerTitle => 'Capa común';

  @override
  String get helpCommonLayerDesc =>
      'Las capas normales son independientes por fotograma, pero una capa común comparte el mismo contenido en varios fotogramas y escenas. Los elementos que no se mueven entre fotogramas, como los fondos, se pueden dibujar una sola vez en lugar de volver a dibujarlos en cada fotograma. Se muestra como una pista dedicada en la línea de tiempo. Convierte una capa normal en una capa común (que sigue mostrando el mismo contenido en varios fotogramas). También puedes fusionar las capas visibles en una sola antes de convertirla. Te ahorra volver a dibujar algo como un fondo que se mantiene igual en cada fotograma.';

  @override
  String get helpAutoFillTitle => 'Coloreado automático';

  @override
  String get helpAutoFillDesc =>
      'Crea una capa de coloreado automático debajo de la capa de líneas para coloreado automático y la colorea automáticamente según un \"ajuste de coloreado automático\" ya creado (una combinación de colores y tramas por parte). Como puedes colorear todo de una vez después de terminar las líneas, reduce enormemente el esfuerzo de coloreado en animación dibujada a mano donde se dibuja repetidamente el mismo personaje. Si vuelves a dibujar las líneas, aparece una marca de actualización (❗) en la línea de tiempo y el panel de capas para indicarte que hay que volver a aplicar el coloreado automático. Elegir \"Ejecutar relleno automático\" en el menú de tres puntos de la pantalla de línea de tiempo recalcula de una vez todas las capas de relleno automático marcadas con el indicador de actualización (❗). Te ahorra ejecutarlo capa por capa en el panel de capas tras volver a dibujar la línea. Cada parte de un ajuste de relleno automático tiene un ajuste sobre cómo tratar el color de la línea: un color especificado, igual al color de relleno, o calco de color. Elegir calco de color desplaza el HSL del color de línea para que coincida con el de relleno, de modo que la línea no destaque y se integre de forma natural. A medida que se acumulan ajustes, la lista mostrada al asignar partes se alarga y cuesta más recorrerla. Desde los ajustes del proyecto (o el diálogo de asignación de partes en el panel de capas) puedes limitarla a solo los ajustes usados en este proyecto, manteniendo la lista ordenada y fácil de elegir.';

  @override
  String get helpOnionSkinTitle => 'Papel cebolla';

  @override
  String get helpOnionSkinDesc =>
      'Superpone en semitransparencia los fotogramas anterior y posterior al que estás editando, para que puedas dibujar mientras compruebas cómo se conecta el movimiento. Puedes ajustar cuántos fotogramas se muestran (antes y después) y su color y opacidad en los ajustes de rendimiento.';

  @override
  String get helpRulerTitle => 'Regla';

  @override
  String get helpRulerDesc =>
      'Una guía para dibujar líneas precisas difíciles de lograr a mano alzada, incluidas reglas rectas, circulares, elípticas y de perspectiva (que usan puntos de fuga para el dibujo en perspectiva). La punta del lápiz se ajusta automáticamente a la regla colocada, facilitando incluso composiciones con profundidad difícil de dibujar sin regla. Las reglas se pueden mover, rotar y redimensionar usando sus controladores.';

  @override
  String get helpFadeTitle => 'Desvanecido';

  @override
  String get helpFadeDesc =>
      'Un ajuste de pincel donde la opacidad y el grosor disminuyen gradualmente a medida que continúas un trazo. Úsalo cuando quieras que el final de una línea se desvanezca, o para crear una sensación de dibujo con un efecto persistente.';

  @override
  String get helpStrokeDecayTitle => 'Atenuación de trazo';

  @override
  String get helpStrokeDecayDesc =>
      'Similar al desvanecido, pero más cercano al efecto de \"la tinta se agota\": el color se desvanece o se vuelve irregular cuanto más sigues dibujando. Reproduce la textura de un pincel o rotulador quedándose sin tinta a medida que lo usas.';

  @override
  String get helpColorMixingTitle => 'Mezcla de colores';

  @override
  String get helpColorMixingDesc =>
      'Al pintar con un pincel, mezcla el color que ya hay justo debajo del pincel con el color que estás a punto de aplicar. Úsalo cuando quieras que los colores nuevos se mezclen con los existentes, como en acuarela u óleo.';

  @override
  String get helpPressureCurveTitle => 'Curva de presión';

  @override
  String get helpPressureCurveDesc =>
      'Una función en los ajustes de entrada de lápiz que permite ajustar libremente, mediante un gráfico, la relación entre la presión real del lápiz y cómo afecta al tamaño y la opacidad del pincel. Ya sea que quieras líneas gruesas incluso con poca presión, o lo contrario —necesitando presión firme para obtener líneas gruesas—, puedes personalizar finamente la sensación para adaptarla a tus hábitos. Puedes probar a dibujar en el momento para comprobar el efecto tras cambiar los ajustes.';

  @override
  String get helpTimelineTitle => 'Línea de tiempo';

  @override
  String get helpTimelineDesc =>
      'La pantalla para gestionar el eje temporal de tu animación. Organizar fotogramas (imágenes fijas individuales) y reproducirlos como un flipbook crea la animación. Las pistas de material de imagen, vídeo y audio, las pistas de capas comunes y los fotogramas clave de cámara se gestionan todos en la misma línea de tiempo.';

  @override
  String get helpSceneTitle => 'Escena';

  @override
  String get helpSceneDesc =>
      'Divide el interior de un proyecto (un vídeo) en escenas (cortes) para gestionarlas por separado. Mientras que las carpetas organizan a nivel de proyecto, las escenas representan cambios de escena dentro de un mismo vídeo. En la pestaña de escenas de la línea de tiempo puedes añadir, duplicar, eliminar, renombrar y reordenar escenas. Al cambiar al modo de selección múltiple puedes mover, duplicar o eliminar varias escenas a la vez.';

  @override
  String get helpCameraKeyframeTitle => 'Fotograma clave de cámara';

  @override
  String get helpCameraKeyframeDesc =>
      'Registra la posición, el nivel de zoom y la rotación de la cámara en un punto específico de la línea de tiempo. Como los valores se interpolan automáticamente de forma suave entre fotogramas clave, puedes añadir fácilmente movimientos de cámara como paneos o zoom in/out.';

  @override
  String get helpEffectFilterTitle => 'Filtro de efecto';

  @override
  String get helpEffectFilterDesc =>
      'Un efecto visual (desenfoque, corrección de color, resplandor, pixelado, etc.) que puedes aplicar a una escena o fotograma. Úsalo cuando quieras ajustar el aspecto general de la pantalla como un toque de dirección, sin cambiar el dibujo hecho a mano en sí. El pixelado también permite elegir un modo de color (sin límite, especificar colores, especificar el número de colores o elegir desde una paleta). Se pueden apilar varios filtros de efecto, y se aplican en el orden en que aparecen en la línea de tiempo. Arrastrar para reordenar la lista de filtros también cambia el orden en que se aplican realmente en pantalla. Un filtro de efecto que aplica un ruido tipo grano de película, cambiándolo fotograma a fotograma. La intensidad, la cantidad (densidad del ruido) y el tamaño del grano se pueden ajustar con controles deslizantes. Volver al mismo fotograma reproduce el mismo grano (sin parpadeo al desplazarte), mientras que al reproducir el grano parece moverse. Un filtro de efecto que muestra lluvia cayendo por la pantalla. La intensidad (número de gotas), la velocidad, el tamaño de gota y el ángulo del viento se pueden ajustar con controles deslizantes. Cada gota sigue cayendo a velocidad constante conforme avanza el fotograma, dando un movimiento de lluvia natural.';

  @override
  String get helpEndCardTitle => 'EndCard (logotipo final)';

  @override
  String get helpEndCardDesc =>
      'Un vídeo corto (unos 5 segundos) con el logotipo de NIARIM, añadido automáticamente al final del contenido principal al exportar un vídeo. La versión gratuita no puede ocultarlo ni eliminarlo, pero los miembros Premium pueden activarlo/desactivarlo, cambiar su duración o reemplazarlo.';

  @override
  String get helpAutoSaveTitle => 'Guardado automático';

  @override
  String get helpAutoSaveDesc =>
      'Un guardado dedicado a la recuperación en caso de fallo o corrupción de archivo. Se guarda automáticamente cada vez que hay un cambio, como dibujar, y sobrescribe el más antiguo de un máximo de 3 guardados. Se gestiona de forma completamente separada de los guardados manuales (ranuras de guardado y árbol de guardado) y no sustituye al guardado habitual. Solo se te pregunta si quieres restaurarlo al reiniciar la aplicación tras un cierre anómalo.';

  @override
  String get helpSaveSlotTitle => 'Ranura de guardado';

  @override
  String get helpSaveSlotDesc =>
      'Un método de guardado en un número fijo de ranuras, donde eliges qué ranura usar cada vez. El número de ranuras lo determinan los ajustes (5 para calidad baja, 10 para calidad media). Como eliges qué ranura sobrescribir cada vez, es una forma sencilla de gestionar la conservación del estado de un momento concreto.';

  @override
  String get helpSaveTreeTitle => 'Árbol de guardado';

  @override
  String get helpSaveTreeDesc =>
      'Un método de guardado en el que se crea un nuevo punto de guardado cada vez que guardas, y puedes ramificar desde un punto de guardado pasado para crear un historial diferente. No hay límite en el número de guardados, lo que lo hace muy adecuado para casos como \"quiero volver a esa versión y probar un desarrollo diferente\". En la pantalla, los puntos de guardado se muestran como un diagrama de árbol que crece de abajo hacia arriba.';

  @override
  String get helpFolderTitle => 'Carpeta';

  @override
  String get helpFolderDesc =>
      'Una función para agrupar y organizar tus proyectos (obras). Admite varios niveles de anidación, por lo que también puedes usarla para gestionar juntos varios episodios o una serie de la misma obra (por ejemplo, organizando los proyectos \"Episodio 1\", \"Episodio 2\", etc. dentro de una carpeta con el nombre de la obra). Si quieres dividir un solo vídeo en escenas separadas, usa la función \"Escena\" de la pantalla del lienzo en lugar de carpetas.';

  @override
  String get helpTrashTitle => 'Papelera';

  @override
  String get helpTrashDesc =>
      'El lugar donde se mueven temporalmente los proyectos eliminados. Puedes restaurarlos desde aquí hasta que se eliminen permanentemente. Puedes establecer el número de días hasta la eliminación automática (desactivado/30/60/90 días) en los ajustes.';

  @override
  String get helpShareTitle => 'Compartir (.niashare)';

  @override
  String get helpShareDesc =>
      'Un formato de archivo dedicado para entregar un proyecto a otra persona (o a otro dispositivo tuyo). Cuando el destinatario abre este archivo, se duplica y se añade a su propia lista de proyectos. El archivo .niashare original en sí no se modifica.';

  @override
  String get helpTransferTitle => 'Transferencia (.niatra)';

  @override
  String get helpTransferDesc =>
      'Una función para transferir todo el entorno de la aplicación —ajustes, materiales, pinceles, ajustes de relleno automático, tema, paletas (selector de color y arte de píxeles) y más— a otro dispositivo de una sola vez. Puedes elegir elementos individuales para transferir con casillas de verificación. Si quieres entregar un proyecto individual, usa \"Compartir (.niashare)\" en su lugar.';

  @override
  String get helpVideoExportTitle => 'Exportación de vídeo (MP4, WebM, GIF)';

  @override
  String get helpVideoExportDesc =>
      'Exporta tu obra como un video MP4 estandar. La version gratuita tiene un limite de duracion (90 segundos) y anade automaticamente una tarjeta final (logotipo de la app) al final del video. Un formato de vídeo que se puede exportar conservando el canal alfa (las partes transparentes del fondo). La reproducción transparente solo funciona en entornos de reproducción compatibles. Ideal para superponer como material en otras aplicaciones. Exporta como GIF animado. Como se reproduce en bucle automaticamente, es ideal para compartir de forma casual en redes sociales. Si la compatibilidad es lo más importante, también puedes exportar como AVI (Motion JPEG). Usa un códec elegido por ser seguro en cuanto a patentes y licencias, pero no admite canal alfa (transparencia), y la vista previa dentro de la app puede no funcionar en todos los dispositivos (aun así puedes reproducirlo con un reproductor externo mediante Compartir). Las cuentas gratuitas tienen un límite de 90 segundos de duración de proyecto (las cuentas Premium tienen 2 horas). Si añadir o duplicar fotogramas te haría superar el límite, aparece un aviso justo al tocar el botón, así que nunca llegas a superar los 90 segundos.';

  @override
  String get helpTransparentWebmTitle => 'WebM transparente';

  @override
  String get helpCommunityTitle => 'Plaza de Obras';

  @override
  String get helpCommunityDesc =>
      'Publica tus animaciones e ilustraciones en la comunidad como vídeos de YouTube y explora las obras de otros usuarios. Cambia entre las pestañas «Nuevas», «Ranking» y «Siguiendo», y busca por título de la obra o nombre del creador. Cambia al modo de búsqueda por etiquetas para filtrar obras por etiqueta: cualquier usuario (no solo el creador) puede añadir o quitar etiquetas, aunque las etiquetas bloqueadas por el creador solo él puede quitarlas, y tocar una etiqueta filtra al instante las obras con la misma etiqueta. Al tocar una tarjeta de obra se abre una ventana de vista previa flotante que se puede arrastrar y redimensionar, para seguir explorando otras pantallas mientras se reproduce. El botón «Ver detalles» abre la pantalla de detalles de la obra (creador, fecha de publicación, edición de etiquetas, marcador, republicación y más). Toca el botón «Seguir» junto al nombre de un creador para añadirlo a tus seguidos: la pestaña «Siguiendo» reúne entonces solo las publicaciones de ese creador, ordenadas por fecha. Cuando alguien te sigue, aparece en la lista de notificaciones bajo el icono de la campana en la parte superior de la pantalla. Puedes elegir si tus listas de seguidos/seguidores son visibles para otros usuarios (privadas por defecto), y puedes ver las listas de otros usuarios si las han hecho públicas. Puedes republicar la obra de cualquier otra persona (excepto la tuya propia) con el botón «Republicar»; cuando un creador al que sigues republica la obra de otra persona, esa obra también aparece en tu pestaña «Siguiendo», ordenada según lo que sea más reciente —su fecha de publicación original o su fecha de republicación— (la tarjeta muestra «Republicado por…»). Las obras marcadas aparecen juntas en la pestaña «Guardadas» de la pantalla de inicio, y también en la pestaña «Marcadores» de la pantalla de obras de un creador. Puedes elegir si tu propia lista de marcadores es visible para otros usuarios (privada de forma predeterminada), y puedes ver las listas de marcadores de otros usuarios si las han hecho públicas. Puedes denunciar una obra indicando un motivo, y tras enviarla se te preguntará si quieres bloquear a ese creador. Los vídeos verticales se pueden ver en «modo vertical», que los reproduce uno tras otro como un feed de vídeos cortos. Hay un límite diario de publicaciones: 1 al día para miembros gratuitos y 3 al día para miembros Premium.';

  @override
  String get helpWatermarkEntryTitle => 'Marca de agua';

  @override
  String get helpWatermarkEntryDesc =>
      'Una función exclusiva de la versión premium que te permite añadir tu propia firma o logotipo como marca de agua en los vídeos e imágenes exportados. Puedes ajustar su posición, tamaño y opacidad. Toca la marca de agua colocada en la pista de capa común de la línea de tiempo para reeditar en cualquier momento su ángulo, tamaño, opacidad y rango visible (bucle), no solo al registrarla, sino cada vez que la uses en un proyecto.';

  @override
  String get helpPremiumEntryTitle => 'Premium';

  @override
  String get helpPremiumEntryDesc =>
      'La membresia premium amplia hasta 2 horas el limite de 90 segundos de duracion de video de la version gratuita y te permite quitar la tarjeta final (logotipo de la app) que se anade automaticamente al final de cada video. Tambien se ocultan los anuncios y obtienes acceso a la marca de agua, la curva de tonos y la correccion de niveles.';

  @override
  String get helpPerformanceSettingsTitle => 'Ajustes de rendimiento';

  @override
  String get helpPerformanceSettingsDesc =>
      'Elige entre los preajustes de calidad baja, media o alta según la capacidad de tu dispositivo, o configura cada elemento individualmente (personalizado). Además del método de guardado, el rendimiento, el papel cebolla y la detección de inclinación, aquí también se agrupan los ajustes que afectan al tamaño de la aplicación y a su fluidez, como la longitud del historial de deshacer y la eliminación automática de la papelera.';

  @override
  String get helpMaterialClipTitle =>
      'Clips de material (imagen / vídeo / audio)';

  @override
  String get helpMaterialClipDesc =>
      'Clips colocados en las pistas de imagen, vídeo y audio de la línea de tiempo. Mantén pulsado y arrastra el cuerpo del clip para mover su posición de inicio, o arrastra las asas de los extremos para cambiar cuánto se usa. Toca un clip para abrir su hoja de detalles, donde el icono de copia lo duplica y el icono de papelera lo elimina. Los clips de imagen y vídeo se gestionan internamente como capas, mientras que los de audio se gestionan como clips vinculados directamente a la escena.';

  @override
  String get helpGestureSettingsTitle => 'Ajustes de gestos';

  @override
  String get helpGestureSettingsDesc =>
      'Permite asignar acciones —deshacer/rehacer, mover fotograma, cuentagotas y más— a un toque con dos dedos, un toque con tres dedos, un deslizamiento con dos dedos o una pulsación larga. Los botones del lápiz (en lápices compatibles) también se pueden asignar por separado. Útil para activar acciones frecuentes con un solo toque sin cambiar de herramienta.';

  @override
  String get helpBucketDetailSettingsTitle =>
      'Ajustes detallados de relleno con cubo';

  @override
  String get helpBucketDetailSettingsDesc =>
      'Desde la sección \"Relleno con cubo\" de los ajustes puedes ajustar la tolerancia (cuánta diferencia de color respecto al píxel pulsado sigue contando como la misma zona), la expansión en px (cuánto se extiende el área rellenada más allá del borde para cubrir huecos en la línea) y rellenar bajo la línea (compone el relleno expandido detrás de los píxeles existentes en lugar de pintar sobre la línea, manteniendo su aspecto intacto). Ajustarlos ayuda cuando la línea tiene pequeños huecos o el relleno queda incompleto.';

  @override
  String get helpStampToolTitle => 'Herramienta de sello';

  @override
  String get helpStampToolDesc =>
      'Coloca una imagen previamente registrada en el lienzo como un pincel. Reutiliza líneas de efecto, patrones de fondo y objetos pequeños sin volver a dibujarlos cada vez. Con el modo píxel activado, las imágenes selladas se procesan con reducción de resolución tipo mosaico y menos colores, para un aspecto pixel art. El panel de sellos permite ajustar el ángulo de rotación y el tamaño del sello que colocas. Variar la dirección y el tamaño del mismo sello evita que las líneas de efecto y los objetos pequeños se vean monótonos.';

  @override
  String get helpToneFillTitle => 'Relleno con tramas';

  @override
  String get helpToneFillDesc =>
      'Cambiar el ajuste de la herramienta de cubo de relleno sólido a relleno con tramas permite rellenar con una trama de semitonos o líneas elegida. También hay tramas de damero y cuadrícula exclusivas del modo píxel, para rellenos que combinan con una textura pixel art.';

  @override
  String get helpPixelModeTitle => 'Modo píxel';

  @override
  String get helpPixelModeDesc =>
      'Un ajuste disponible por separado en pinceles, fuentes y sellos. Al activarlo se elimina el suavizado, dando bordes nítidos al estilo pixel art. Úsalo cuando quieras un aire deliberadamente retro o de baja resolución. Puedes elegir entre cuatro modos de color: sin límite de color, especificar colores, especificar el número de colores o elegir desde una paleta, incluida una paleta específica para pixel art.';

  @override
  String get helpHomeScreenTitle => 'Pantalla de inicio';

  @override
  String get helpHomeScreenDesc =>
      'La primera pantalla que se muestra al abrir la app, con las pestañas Proyectos, Compartidos, Obras y Papelera. El icono de búsqueda arriba a la derecha permite filtrar proyectos por nombre. En la pestaña Proyectos, el botón flotante permite elegir entre crear un nuevo proyecto o una nueva carpeta.';

  @override
  String get helpNewProjectTitle => 'Nuevo proyecto';

  @override
  String get helpNewProjectDesc =>
      'Configura el tamaño del lienzo, los fps, la duración (en segundos; luego se mantiene sincronizada con los cambios de fotogramas hechos en la línea de tiempo), el área de dibujo (permite dibujar más allá de los límites de exportación) y qué ajustes de relleno automático usar, todo antes de crear el proyecto.';

  @override
  String get helpThemeSettingsTitle => 'Ajustes de tema';

  @override
  String get helpThemeSettingsDesc =>
      'Elige la paleta de colores general de la app de la lista de temas, o personaliza libremente el color de acento. Los títulos/etiquetas y el texto de cuerpo usan fuentes distintas, así que puedes cambiar el aspecto de la app manteniendo la legibilidad.';

  @override
  String get helpWorkspaceSettingsTitle => 'Ajustes del espacio de trabajo';

  @override
  String get helpWorkspaceSettingsDesc =>
      'Reúne ajustes como el modo zurdo (invierte los paneles acoplados), el cambio manual entre modo PC/DeX y cuándo se muestra la herramienta de mano. Ajusta el diseño según tu dispositivo y tu mano dominante.';

  @override
  String get helpPenSettingsTitle => 'Ajustes del lápiz';

  @override
  String get helpPenSettingsDesc =>
      'Junto con la curva de presión para tabletas y pantallas con lápiz, esta pantalla permite asignar acciones —como alternar el borrador o el cuentagotas— a los botones laterales de un lápiz compatible.';

  @override
  String get helpMaterialListTitle => 'Lista de materiales';

  @override
  String get helpMaterialListDesc =>
      'Una pantalla que reúne las imágenes, vídeos y audios usados en un proyecto. Recopila los archivos de origen de todo lo colocado en la línea de tiempo.';

  @override
  String get helpFrameOperationsTitle => 'Operaciones con fotogramas';

  @override
  String get helpFrameOperationsDesc =>
      'En la lista de fotogramas puedes añadir, duplicar y eliminar fotogramas, y en modo de selección múltiple mover, duplicar o eliminar varios a la vez. Aumentar el número de retención mantiene un mismo fotograma mostrado durante varias celdas (una \"retención\"), ahorrando trabajo de dibujo en planos con poco movimiento.';

  @override
  String get helpSceneOperationsTitle => 'Operaciones con escenas';

  @override
  String get helpSceneOperationsDesc =>
      'La pestaña de escenas de la línea de tiempo permite añadir, duplicar, eliminar, renombrar y reordenar escenas. El modo de selección múltiple permite mover, duplicar o eliminar varias escenas a la vez.';

  @override
  String get helpQuickToolManagementTitle => 'Gestión de herramientas rápidas';

  @override
  String get helpQuickToolManagementDesc =>
      'Registra un conjunto de herramientas usadas con frecuencia para alternar entre ellas con un solo toque. Abre el popup de gestión con una pulsación larga o un deslizamiento hacia arriba para editar las herramientas registradas y su orden.';

  @override
  String get helpTransformSelectionTitle => 'Transformar una selección';

  @override
  String get helpTransformSelectionDesc =>
      'Una zona delimitada con la herramienta de selección se puede mover, rotar y escalar con la herramienta de transformación. Útil para reposicionar una parte dibujada por error, o para ampliar solo una zona para destacarla. Si quieres transformar toda la capa, usa Transformación libre / Deformación de malla (se abre desde el menú de edición): no necesita selección y permite arrastrar cada punto de la cuadrícula individualmente para un resultado más libre.';

  @override
  String get helpGradientAutofillTitle =>
      'Relleno degradado (ajustes de relleno automático)';

  @override
  String get helpGradientAutofillDesc =>
      'Cada parte de un ajuste de relleno automático puede usar un degradado en lugar de un color sólido. Los tiradores simétricos que puedes arrastrar permiten ajustar de forma intuitiva el alcance y el ángulo del degradado. Cada parte también puede activar «Contorno con color especificado». Al marcarlo, se dibuja una línea del color y grosor elegidos justo en el borde más exterior del área rellenada (pegada al dibujo lineal). El color del contorno se puede elegir libremente con el selector de color, y el grosor se puede ajustar con el deslizador, los botones ± o tocando el número para escribirlo directamente. Justo encima de los ajustes aparece una vista previa, para poder comprobar el color y el grosor antes de ejecutar el relleno automático.';

  @override
  String get helpColorPickerTitle => 'Selector de color';

  @override
  String get helpColorPickerDesc =>
      'Un selector de color que te permite alternar entre HSV y RGB en una sola pantalla. La funcion de paleta te permite guardar y recuperar el conjunto de colores que estas usando. Las paletas también se pueden compartir con otros dispositivos mediante exportación de archivo o código QR.';

  @override
  String get helpUndoSettingsTitle => 'Longitud del historial de deshacer';

  @override
  String get helpUndoSettingsDesc =>
      'En los ajustes de rendimiento puedes ajustar cuántas acciones puede retroceder deshacer. Un número mayor da más libertad para experimentar, pero también usa más memoria; redúcelo en dispositivos de gama baja para que todo vaya más fluido.';

  @override
  String get helpBrushFavoriteTitle => 'Pinceles favoritos';

  @override
  String get helpBrushFavoriteDesc =>
      'Toca el icono de estrella de un pincel en la lista para marcarlo o desmarcarlo como favorito (la misma interacción que se usa para los favoritos en el resto de la app: ajustes de relleno automático, sellos, fuentes, filtros de dibujo, etc.). El icono de estrella en la parte superior de la lista también permite filtrar para mostrar solo los favoritos. Un pincel favorito no puede eliminarse por error.';

  @override
  String get helpCustomBrushTitle => 'Pinceles personalizados';

  @override
  String get helpCustomBrushDesc =>
      'Mantén pulsado un pincel preinstalado en la lista y elige «Duplicar» para crear tu propio pincel personalizado basado en él. Los pinceles duplicados se pueden editar libremente (grosor, opacidad, dureza, rotación, densidad, dispersión, radio de desenfoque y más) y eliminar cuando ya no los necesites (los pinceles preinstalados no se pueden editar ni eliminar). También puedes organizarlos en carpetas y marcarlos como favoritos con el icono de estrella.';

  @override
  String get helpLayerFolderTitle => 'Carpetas de capas';

  @override
  String get helpLayerFolderDesc =>
      'Permite organizar varias capas en una carpeta. Mantiene el panel de capas manejable incluso en ilustraciones con muchas partes. El recorte no puede cruzar los límites de las carpetas, así que si lo usas, mantén las capas relevantes en la misma carpeta.';

  @override
  String get helpLayerMultiSelectTitle =>
      'Selección múltiple y acciones masivas de capas';

  @override
  String get helpLayerMultiSelectDesc =>
      'El modo de selección del panel de capas permite marcar varias capas a la vez para fusionarlas o eliminarlas en bloque. La fusión solo funciona entre capas normales, de línea de relleno automático y de relleno automático (las capas comunes, carpetas y materiales de línea de tiempo no se pueden fusionar).';

  @override
  String get helpDrawingAreaTitle => 'Área de dibujo';

  @override
  String get helpDrawingAreaDesc =>
      'Permite dibujar más allá de los límites de exportación. Un marco rojo en el lienzo señala el área de exportación: lo dibujado fuera de él no se exporta, pero deja margen para ajustar después qué se muestra con movimientos de cámara como paneo y zoom. Define la escala al crear un nuevo proyecto.';

  @override
  String get helpCanvasBackgroundTitle => 'Color de fondo del lienzo';

  @override
  String get helpCanvasBackgroundDesc =>
      'Permite definir el color de fondo del lienzo del proyecto. No afecta a las exportaciones transparentes (WebM transparente), pero puedes cambiarlo al color que te resulte más cómodo para trabajar.';

  @override
  String get helpProjectDetailTitle => 'Pantalla de detalles del proyecto';

  @override
  String get helpProjectDetailDesc =>
      'Una pantalla para consultar y editar en un solo lugar los ajustes de cada proyecto: nombre, miniatura, estado de favorito y qué ajustes de relleno automático están activados. El acceso al árbol de guardado también está aquí.';

  @override
  String get helpWatermarkEditTitle => 'Reeditar una marca de agua';

  @override
  String get helpWatermarkEditDesc =>
      'Tocar una marca de agua colocada en la pista de capa común de la línea de tiempo permite reeditar en cualquier momento su ángulo, tamaño, opacidad y rango de visualización (bucle). Puedes ajustarla con precisión no solo al registrarla, sino siempre que la estés usando en un proyecto.';

  @override
  String get helpAudioClipTitle => 'Volumen y fundidos de clips de audio';

  @override
  String get helpAudioClipDesc =>
      'Un clip de audio colocado en la línea de tiempo puede tener su volumen y las duraciones de fundido de entrada y salida ajustados desde su hoja de detalles. Úsalo para equilibrar el volumen de efectos de sonido y música, o suavizar el inicio y el final de una pista.';

  @override
  String get helpPenSubToolTitle => 'Subherramientas del lápiz';

  @override
  String get helpPenSubToolDesc =>
      'Mantener pulsada la herramienta lápiz la cambia del dibujo normal a las subherramientas de relleno con tramas o colocación de sellos. Permite alternar entre varias tareas con el mismo lápiz sin cambiar de herramienta constantemente.';

  @override
  String get helpTiltDetectionTitle => 'Detección de inclinación';

  @override
  String get helpTiltDetectionDesc =>
      'Un ajuste que usa los datos de inclinación de un lápiz compatible para engrosar o afinar la línea al tumbar la punta, recreando una sensación más cercana a una herramienta de dibujo real. Actívalo o desactívalo desde los ajustes de rendimiento.';

  @override
  String get helpFontImportTitle => 'Importar fuentes';

  @override
  String get helpFontImportDesc =>
      'Permite cargar un archivo de fuente directamente desde el almacenamiento del dispositivo. Añádela desde la pestaña \"Importar\" en la gestión de fuentes, en ajustes. Útil cuando quieres usar una fuente personalizada que no se distribuye en ningún sitio, o una fuente comercial que has comprado.';

  @override
  String get helpExportScreenTitle => 'Pantalla de exportación';

  @override
  String get helpExportScreenDesc =>
      'Muestra el progreso al exportar un vídeo o una imagen, y permite cancelar a mitad de camino. El tiempo que tarda depende del rendimiento del dispositivo.';

  @override
  String get helpDrawingFilterTitle => 'Filtros de dibujo';

  @override
  String get helpDrawingFilterDesc =>
      'Filtros aplicados directamente a la capa seleccionada (a diferencia de los filtros de efecto, que se aplican a toda la línea de tiempo o a una escena, los filtros de dibujo actúan por capa). Incluyen desenfoque, nitidez, máscara de enfoque, curva de tonos, niveles, viñeteado, ruido, anime retro, TRC, estilo anime, contorno y pixelado. El contorno no reescribe la capa original: dibuja solo el resultado contorneado en una capa nueva. El pixelado también permite elegir un modo de color (sin límite, especificar colores, especificar el número de colores o elegir desde una paleta).';

  @override
  String get helpLayerKeyframeTitle =>
      'Fotogramas clave de capa (animación por partes)';

  @override
  String get helpLayerKeyframeDesc =>
      'Define la posición, escala y rotación de cada capa por fotograma; los fotogramas clave se interpolan automáticamente. Mientras los fotogramas clave de cámara mueven toda la pantalla, esto mueve una sola capa. Como cada parte del relleno automático se genera como una capa independiente, esto funciona directamente para animar por partes: mover solo un brazo, abrir y cerrar solo una boca, etc. Cada fotograma clave también puede tener su propia interpolación (uniforme, entrada suave, salida suave, entrada y salida suaves, o rebote) que controla cómo se conecta con el siguiente fotograma clave, de modo que el movimiento no tiene por qué ser siempre a velocidad constante. Se configura desde \"Animación (fotogramas clave)\" en el menú de tres puntos de cada capa, en el panel de capas. El dibujo de la capa en sí no cambia: es una transformación no destructiva de dónde se muestra. Esto solo afecta a la visualización de la línea de tiempo (vista previa / exportación) y no afecta al dibujo real en el modo lienzo.';

  @override
  String get helpLayerGroupTitle =>
      'Grupos de capas (mover varias partes juntas)';

  @override
  String get helpLayerGroupDesc =>
      'Mueve varias capas juntas con un único flujo de fotogramas clave. Por ejemplo, si un \"brazo\" está formado por dos partes de relleno automático —piel y manga—, agruparlas permite mover ambas con una sola operación de fotograma clave. Crea un grupo seleccionando varias capas (casillas) en el panel de capas y tocando el icono \"Agrupar\" en la barra inferior. El movimiento del grupo se superpone a los fotogramas clave propios de cada capa miembro (si los tiene), por lo que puedes combinar el movimiento general del grupo con ajustes finos por capa. Una capa solo puede pertenecer a un grupo a la vez.';

  @override
  String get tipsScreenTitle => 'Consejos';

  @override
  String get tipsSearchHint => 'Buscar consejos...';

  @override
  String get tipsCategoryVideo => 'Consejos para crear vídeos';

  @override
  String get tipsCategoryEfficiency => 'Consejos para trabajar más rápido';

  @override
  String get tipsCategoryDrawing => 'Consejos para dibujar con más fluidez';

  @override
  String get tipsCategoryEffects => 'Consejos de estilo y acabado';

  @override
  String get tipsCategoryExport => 'Consejos de exportación y flujo de trabajo';

  @override
  String get tipsClipDuplicateTitle =>
      'Los clips de la línea de tiempo se pueden duplicar, mover y eliminar';

  @override
  String get tipsClipDuplicateDesc =>
      'Toca un clip de imagen, vídeo o audio para abrir su hoja de detalles y usa el icono de copia para duplicarlo. Reutilizar el mismo efecto de sonido o reubicar la misma imagen en varias escenas solo requiere una pulsación larga y arrastrar, y un toque en el botón de duplicar.';

  @override
  String get tipsTextCaptionTitle =>
      'Añade subtítulos con la herramienta de texto';

  @override
  String get tipsTextCaptionDesc =>
      'Usa la herramienta de texto para colocar subtítulos o comentarios fotograma a fotograma. Cambiar la fuente al modo píxel también puede darle al texto un aire retro de videojuego antiguo.';

  @override
  String get tipsAutofillPresetTitle =>
      'Registra un ajuste de relleno automático por parte';

  @override
  String get tipsAutofillPresetDesc =>
      'Registrar un ajuste por parte (piel, pelo, ropa) con sus sombras incluidas automatiza gran parte del coloreado con solo dibujar la línea. También puedes limitar qué ajustes se usan en cada proyecto.';

  @override
  String get tipsAutofillBaseCoatTitle =>
      'El relleno automático también sirve como una sola capa de base';

  @override
  String get tipsAutofillBaseCoatDesc =>
      'El relleno automático está pensado para colorear parte por parte, pero no hace falta dividirlo todo con cuidado: usarlo como una única capa de base de un solo color sobre toda la línea ya es muy útil por sí solo. Rellena todo el interior de las líneas de una vez, lo que evita los huecos sin pintar (donde se transparenta el color de abajo) que suelen pasar al rellenar a mano con el cubo. Luego pinta los colores a mano encima, y obtienes el beneficio sin el trabajo de separar partes.';

  @override
  String get tipsBrushFavoriteTitle =>
      'Marca tus pinceles favoritos para cambiarlos sin buscar';

  @override
  String get tipsBrushFavoriteDesc =>
      'Toca el icono de estrella de los pinceles que más usas para marcarlos como favoritos. El icono de estrella en la parte superior de la lista permite filtrar solo los favoritos, reduciendo el tiempo de búsqueda. Los pinceles favoritos no se pueden eliminar por error.';

  @override
  String get tipsPressureCurveTitle =>
      'Ajusta la curva de presión a tu propia mano';

  @override
  String get tipsPressureCurveDesc =>
      'La curva de presión en ajustes te permite colocar libremente hasta 10 puntos de control. Si la respuesta de fuerza no te convence, ajústala a tus propios hábitos de presión.';

  @override
  String get tipsExportFormatTitle =>
      'Elige el formato de exportación según el uso';

  @override
  String get tipsExportFormatDesc =>
      'GIF es ideal para publicar rápido en redes sociales; WebM transparente sirve para superponer sobre otro vídeo o mantener el fondo transparente; MP4 es para usarlo como vídeo normal. Elegir según el caso de uso facilita equilibrar tamaño de archivo y calidad.';

  @override
  String get tipsGestureShortcutTitle =>
      'Asigna un gesto a las acciones frecuentes';

  @override
  String get tipsGestureShortcutDesc =>
      'Desde \"Gestos\" en los ajustes puedes asignar deshacer/rehacer o el cuentagotas a un toque con dos dedos, un toque con tres dedos o una pulsación larga. Al no tener que cambiar de herramienta, no rompes el ritmo del dibujo.';

  @override
  String get tipsAudioRepeatTitle =>
      'Mantén los efectos de sonido a ritmo duplicando clips y usando fundidos';

  @override
  String get tipsAudioRepeatDesc =>
      'Para reutilizar el mismo efecto de sonido varias veces, duplica el clip y coloca las copias con tiempos escalonados, dando a cada una su propio fundido de entrada/salida. Así consigues una repetición natural y rítmica del efecto.';

  @override
  String get tipsVerticalRubyTitle =>
      'Texto vertical + furigana para un look de logo de título';

  @override
  String get tipsVerticalRubyDesc =>
      'Combinar escritura vertical con furigana en la herramienta de texto da un logo de título de estilo japonés o un tratamiento de titular distintivo. Los alfanuméricos de medio ancho rotan automáticamente para quedar de lado, manteniéndose legibles incluso mezclados con símbolos o números.';

  @override
  String get tipsBrushTrySaveTreeTitle =>
      'Prueba nuevos ajustes de pincel con el árbol de guardado';

  @override
  String get tipsBrushTrySaveTreeDesc =>
      'Antes de hacer un cambio grande en el grosor o la estabilización del pincel, guarda primero en el árbol de guardado para mayor tranquilidad. Si no te gusta el resultado, puedes volver directamente al estado anterior, facilitando probar ajustes atrevidos.';

  @override
  String get tipsEyedropperGestureTitle =>
      'Asigna el cuentagotas a un toque con dos dedos para mantener tu paleta coherente';

  @override
  String get tipsEyedropperGestureDesc =>
      'Asignar el cuentagotas a un toque con dos dedos en los ajustes de gestos te permite tomar un color cercano al instante sin cambiar de herramienta. Útil para colorear manteniendo fiel la paleta de un personaje.';

  @override
  String get tipsRulerOnionTitle =>
      'Regla de perspectiva + papel cebolla para reutilizar un fondo';

  @override
  String get tipsRulerOnionDesc =>
      'Define la profundidad de un fondo con la regla de perspectiva, y luego mueve solo al personaje mientras compruebas los fotogramas vecinos con el papel cebolla; no hace falta redibujar el fondo en cada fotograma.';

  @override
  String get tipsGradientTraceTitle =>
      'Relleno automático degradado + calco de color para una mezcla natural';

  @override
  String get tipsGradientTraceDesc =>
      'Al usar un degradado en un ajuste de relleno automático, pon el modo de color de línea en calco de color para que el color de la línea siga los sutiles cambios de color del degradado, evitando que el borde destaque.';

  @override
  String get tipsGradientOutlineHairTitle =>
      'Degradado × contorno de color especificado para pelo translúcido';

  @override
  String get tipsGradientOutlineHairDesc =>
      'Crea una parte de flequillo en tu ajuste de relleno automático y pon el relleno en degradado con el color del pelo y transparente como los dos colores. Ajusta el ángulo a 90°, la intensidad del difuminado y la posición de cambio de color a tu gusto, activa «Contorno con color especificado» y elige el color del contorno en «Colores usados recientemente», seleccionando el mismo color que acabas de usar para el flequillo. Repite los mismos pasos también en la parte de sombra del pelo, además de la parte base, para lograr un cabello con sensación translúcida.';

  @override
  String get tipsRainNoiseTitle =>
      'Lluvia + ruido animado para una atmósfera húmeda';

  @override
  String get tipsRainNoiseDesc =>
      'Superponer un filtro de ruido animado suave sobre el filtro de lluvia añade una sensación de partículas en el aire además de las propias gotas de lluvia, para una textura húmeda de día lluvioso.';

  @override
  String get tipsPartKeyframeGroupTitle =>
      'Haz rebotar a un personaje con fotogramas clave de parte + agrupación';

  @override
  String get tipsPartKeyframeGroupDesc =>
      'Anima cada parte de relleno automático con fotogramas clave de capa, y luego agrupa las partes relacionadas para hacerlas rebotar juntas: puedes crear una minianimación que se mece con la música sin volver a dibujar nada.';

  @override
  String get tipsLowSpecSettingsTitle =>
      'En dispositivos de gama baja, revisa los ajustes de rendimiento y el historial de deshacer';

  @override
  String get tipsLowSpecSettingsDesc =>
      'Si notas que va lento, prueba a cambiar los ajustes de rendimiento al preset de \"baja calidad\" y reduce también la longitud del historial de deshacer. Eso reduce el uso de memoria y puede hacer que todo vaya más fluido.';

  @override
  String get tipsSeriesPresetFolderTitle =>
      'Gestiona una serie con filtrado de ajustes de relleno automático + organización en carpetas';

  @override
  String get tipsSeriesPresetFolderDesc =>
      'Al hacer varios episodios de la misma obra, agrupa los proyectos por episodio en una carpeta, y limita qué ajustes de relleno automático usa cada proyecto. Así evitas mezclar la paleta de cada personaje y mantienes el trabajo eficiente.';

  @override
  String get tipsPixelToneRetroTitle =>
      'Sellos en modo píxel + relleno con tramas para un look retro unificado';

  @override
  String get tipsPixelToneRetroDesc =>
      'Combinar sellos en modo píxel con las tramas de damero y cuadrícula exclusivas del modo píxel permite unificar toda la pantalla con una textura pixel art. Genial para un aire de videojuego retro.';

  @override
  String get tipsMagicWandLassoTitle =>
      'Varita mágica + relleno por lazo para separar colores más rápido';

  @override
  String get tipsMagicWandLassoDesc =>
      'Selecciona una zona amplia de golpe con la varita mágica de la herramienta de selección, y luego ajusta solo lo que sobra con la selección por lazo; así hasta la separación de colores más compleja va rápido.';

  @override
  String get tipsCommonLayerFolderTitle =>
      'Capas comunes + carpetas para reutilizar entre episodios';

  @override
  String get tipsCommonLayerFolderDesc =>
      'Para un logo o los créditos usados en todos los episodios de una serie, conviértelo en capa común y mantenlo organizado en una carpeta; así es fácil de manejar al copiarlo al proyecto de un episodio nuevo.';

  @override
  String get tipsStrokeDecayFadeTitle =>
      'Decaimiento de trazo + desvanecimiento para un aire de pincel caligráfico';

  @override
  String get tipsStrokeDecayFadeDesc =>
      'Combinar decaimiento de trazo y desvanecimiento en los ajustes del pincel afina de forma natural el inicio y el final de un trazo, dando a las líneas esa variación expresiva de grosor propia de un pincel de caligrafía o tinta.';

  @override
  String get tipsColorMixingFadeTitle =>
      'Mezcla de color + desvanecimiento para un mezclado tipo pintura';

  @override
  String get tipsColorMixingFadeDesc =>
      'Añadir desvanecimiento a un pincel con mezcla de color activada hace que se mezcle con el color de debajo mientras se va aclarando gradualmente, mucho más parecido a cómo se comporta la pintura real.';

  @override
  String get tipsOutlineAnimeStyleTitle =>
      'Contorno + estilo anime para un acabado de animación cel';

  @override
  String get tipsOutlineAnimeStyleDesc =>
      'Dibuja el contorno en una capa nueva con el contorno del filtro de dibujo, y luego reduce el número de colores con el filtro de estilo anime, para un acabado nítido tipo animación cel.';

  @override
  String get tipsLevelsToneCurveTitle =>
      'Niveles + curva de tonos para un look de diseño gráfico';

  @override
  String get tipsLevelsToneCurveDesc =>
      'Sube mucho el contraste con niveles primero, y luego esculpe la gradación con la curva de tonos, para un look gráfico tipo cartel que se aleja de la tonalidad fotográfica.';

  @override
  String get tipsMosaicChromaticTitle =>
      'Mosaico + aberración cromática para una textura tosca de tubo de rayos catódicos';

  @override
  String get tipsMosaicChromaticDesc =>
      'Baja la resolución con el mosaico y luego superpón aberración cromática, para una textura tosca como ver una vieja tele de tubo de rayos catódicos; un matiz distinto al filtro CRT por sí solo.';

  @override
  String get tipsEndCardWatermarkTitle =>
      'La marca de agua es tu firma; la tarjeta final es otra cosa';

  @override
  String get tipsEndCardWatermarkDesc =>
      'Usa la función de marca de agua cuando quieras añadir tu propia firma o marca a un vídeo. La tarjeta final es el logotipo propio de la app que aparece automáticamente al final de cada vídeo; los miembros gratuitos no pueden cambiarlo. Los miembros premium pueden ocultarlo o sustituirlo por su propio vídeo o imagen. Si quieres un cierre personalizado sin usar la tarjeta final, puedes recrear un efecto similar añadiendo una capa de imagen con entrada/salida de fundido.';

  @override
  String get tipsVerticalPixelFontTitle =>
      'Mezcla metraje real con dibujo a mano para \"acción real × anime\"';

  @override
  String get tipsVerticalPixelFontDesc =>
      'Un truco solo posible porque esta app es a la vez una app de ilustración y un editor de vídeo. Coloca un clip de vídeo real en la línea de tiempo, y luego usa el papel cebolla en una capa encima para dibujar a mano líneas de velocidad o un personaje sobre el metraje, creando un vídeo mixto donde la animación dibujada a mano se superpone a la acción real.';

  @override
  String get tipsTimelineMarkerTitle =>
      'Usa marcas de tiempo para sincronizar sonido y bocas';

  @override
  String get tipsTimelineMarkerDesc =>
      'Las escenas manejan un rango —un fotograma de inicio y de fin—, mientras que las marcas de tiempo señalan un instante concreto con un comentario al que puedes saltar de un toque. Colocar varias marcas de tiempo dentro de la misma escena —\"efecto de sonido en el fotograma 120\", \"boca \'a\' en el fotograma 180\"— hace que sincronizar el sonido con la imagen sea muchísimo más fácil.';

  @override
  String get tipsCommunityYoutubeTitle =>
      'Publicar en la Plaza de Obras se hace a través de YouTube';

  @override
  String get tipsCommunityYoutubeDesc =>
      'Al publicar en la Plaza de Obras, tu obra se publica a través de YouTube. NIARIM no transmite, recopila ni almacena el propio archivo de vídeo en los servidores del desarrollador. Si configuras el vídeo como \"No listado\" en YouTube, no aparecerá en los listados públicos de YouTube y solo se publicará dentro de la Plaza de Obras.';

  @override
  String get tipsToolbarCustomizeTitle =>
      'Reordena u oculta herramientas de la barra para reducir el recorrido del dedo';

  @override
  String get tipsToolbarCustomizeDesc =>
      'Desde la edición de la barra de herramientas en ajustes, puedes ocultar las herramientas que nunca usas y reordenar las que sí usas para que queden donde tu dedo llega fácilmente. Recortar la lista evita que busques una herramienta y acorta el recorrido del dedo, dando ritmo a tu dibujo.';

  @override
  String get tipsAutofillBlendModeTitle =>
      'Cambia la textura del sombreado con el modo de fusión de una parte de relleno automático';

  @override
  String get tipsAutofillBlendModeDesc =>
      'Cada parte de un ajuste de relleno automático puede tener su propio modo de fusión. Pon una parte de sombra en \"superponer\" o \"luz suave\" en lugar de \"multiplicar\" para un sombreado más suave, como si la luz lo atravesara. Una libertad oculta que permite cambiar la textura del sombreado sin cambiar el color.';

  @override
  String get tipsStampBlendModeTitle =>
      'Sellos + modo de fusión para un efecto de luz';

  @override
  String get tipsStampBlendModeDesc =>
      'Ajustar el modo de fusión de una capa de sello colocada a \"pantalla\" o \"suma\" hace que las líneas de brillo o los destellos se integren de forma natural en el fondo y realmente destaquen.';

  @override
  String get tipsQuickToolPenSubTitle =>
      'Herramienta rápida + subherramientas del lápiz para un flujo de trabajo sin pausas';

  @override
  String get tipsQuickToolPenSubDesc =>
      'Registra tus herramientas más usadas en la herramienta rápida, y aprovecha también las subherramientas del lápiz (mantén pulsado el lápiz para cambiar a relleno con tramas o colocación de sellos): reducirás cuánto saltas entre paneles y mantendrás el ritmo.';

  @override
  String get tipsAutofillToneReuseTitle =>
      'Reutiliza un relleno con tramas solo con redibujar la línea, gracias al ajuste de tramas del relleno automático';

  @override
  String get tipsAutofillToneReuseDesc =>
      'Configurar cada parte de un ajuste de relleno automático como \"usar trama\" reproduce el relleno con tramas automáticamente cada vez que redibujas la línea, sin necesidad de volver a aplicar la trama fotograma a fotograma.';

  @override
  String get tipsRadialVignetteTitle =>
      'Regla radial + viñeteado para un impacto de líneas de velocidad';

  @override
  String get tipsRadialVignetteDesc =>
      'Dibuja una ráfaga de líneas de velocidad de golpe con la regla radial, y luego superpón el filtro de dibujo de viñeteado para un golpe de efecto tipo clímax de manga.';

  @override
  String get tipsClippingGradientTitle =>
      'Recorte + degradado para poder reeditar el sombreado';

  @override
  String get tipsClippingGradientDesc =>
      'Recorta una capa de degradado sobre una capa de personaje, y podrás reajustar el sombreado solo cambiando el alcance y el ángulo del degradado, sin necesidad de redibujar su forma con un pincel.';

  @override
  String get tipsToneCurveSepiaTitle =>
      'Curva de tonos + sepia para un aire de foto retro';

  @override
  String get tipsToneCurveSepiaDesc =>
      'Ajusta el contraste de luces y sombras con el filtro de efecto curva de tonos, y luego superpón sepia, para una textura como de fotografía antigua desvaída.';

  @override
  String get tipsCameraLensBlurTitle =>
      'Fotogramas clave de cámara + desenfoque de lente para un efecto de zoom blur';

  @override
  String get tipsCameraLensBlurDesc =>
      'Sincronizar un filtro de efecto de desenfoque de lente más intenso con el momento en que un fotograma clave de cámara hace zoom le da la fuerza de un zoom blur de imagen real.';

  @override
  String get tipsBlurVignetteBgTitle =>
      'Desenfoque gaussiano + viñeteado para un bokeh de fondo suave';

  @override
  String get tipsBlurVignetteBgDesc =>
      'Aplica los filtros de dibujo de desenfoque gaussiano y viñeteado solo a la capa de fondo, y tu personaje principal destacará de forma natural, dando un acabado tipo profundidad de campo de cámara.';

  @override
  String get tipsSepiaVignetteTitle =>
      'Sepia + viñeteado para un vídeo estilo foto antigua';

  @override
  String get tipsSepiaVignetteDesc =>
      'Combinar el filtro de efecto sepia con el filtro de dibujo de viñeteado da a tu vídeo las esquinas oscurecidas y el aspecto desvaído de una fotografía antigua.';

  @override
  String get tipsVideoTrimReuseTitle =>
      'Reutiliza el mismo archivo de vídeo cambiando el recorte de cada clip';

  @override
  String get tipsVideoTrimReuseDesc =>
      'Incluso el mismo archivo de vídeo puede colocarse como un plano distinto cada vez cambiando su recorte de inicio/fin por clip. Aporta variedad sin añadir más material fuente.';

  @override
  String get tipsSaveSlotAutoSaveTitle =>
      'Usa las ranuras de guardado y el guardado automático para cosas distintas';

  @override
  String get tipsSaveSlotAutoSaveDesc =>
      'El guardado automático siempre sobrescribe con el último estado, mientras que las ranuras de guardado pueden conservar varios estados a la vez. Guarda en una ranura en un hito importante y deja los cambios pequeños al guardado automático, así podrás volver con fiabilidad al punto que necesites.';

  @override
  String get tipsQuickToolSwipeTitle =>
      'Desliza hacia arriba en la herramienta rápida para reordenarla';

  @override
  String get tipsQuickToolSwipeDesc =>
      'Para cambiar lo que hay registrado en la herramienta rápida, puedes abrir el popup de gestión con un deslizamiento hacia arriba, no solo con una pulsación larga. Útil para reordenar rápido mientras operas con una sola mano.';

  @override
  String get tipsDrawingAreaCameraTitle =>
      'Área de dibujo más amplia + fotogramas clave de cámara para paneos y zooms seguros';

  @override
  String get tipsDrawingAreaCameraDesc =>
      'Definir el área de dibujo más amplia que los límites de exportación significa que paneos o zooms con fotogramas clave de cámara no arriesgan cortar el borde de la pantalla. Vale la pena comprobarlo antes de añadir un gran movimiento de cámara.';

  @override
  String get tipsWebmCommonLayerTitle =>
      'WebM transparente + una capa común para mantener el fondo separado';

  @override
  String get tipsWebmCommonLayerDesc =>
      'Si vas a componer un personaje exportado como WebM transparente sobre un fondo en otro software de vídeo, mantener el fondo en su propia capa común evita que colores no deseados se filtren en la zona transparente, para un recorte más limpio.';

  @override
  String get tipsLeftHandedWorkspaceTitle =>
      'Modo zurdo + ajustes del espacio de trabajo para una configuración más cómoda';

  @override
  String get tipsLeftHandedWorkspaceDesc =>
      'Si eres zurdo, activar el modo zurdo en los ajustes del espacio de trabajo invierte los paneles acoplados, reduciendo la probabilidad de que queden bajo tu mano de dibujo.';

  @override
  String get tipsTransferDeviceTitle =>
      'Traslada tu trabajo a otro dispositivo con un archivo de traspaso';

  @override
  String get tipsTransferDeviceDesc =>
      'Si quieres cambiar de dispositivo y seguir dibujando en el mismo entorno, la función de traspaso (.niatra) mueve tus ajustes, pinceles, tramas, sellos, paletas y más, todo junto. Para entregar un proyecto en el que estás trabajando, usa \"Compartir (.niashare)\" en su lugar.';

  @override
  String get fontSettingsTabDownloaded => 'Descargadas';

  @override
  String get fontSettingsTabSearch => 'Buscar y descargar';

  @override
  String get fontSettingsTabImport => 'Importar';

  @override
  String get fontDownloadedSearchHint => 'Buscar por nombre de fuente...';

  @override
  String get fontPixelModeTooltip =>
      'Modo píxel (para fuentes de puntos. Se muestra nítido sin suavizado)';

  @override
  String get fontEmptyTitle => 'No hay fuentes';

  @override
  String get fontEmptyHint =>
      'Añade fuentes desde las pestañas \"Buscar y descargar\" o \"Importar\"';

  @override
  String get fontRenameDialogTitle => 'Renombrar fuente';

  @override
  String get fontImportTitle =>
      'Importar una fuente guardada en este dispositivo';

  @override
  String get fontImportFormats => 'Formatos compatibles: TTF / OTF';

  @override
  String get fontSelectFileButton => 'Seleccionar archivo';

  @override
  String get fontUnsupportedSnackbar => 'No se pudo cargar esta fuente.';

  @override
  String fontAddedSnackbar(String name) {
    return 'Se añadió \"$name\" (visible en la pestaña Descargadas)';
  }

  @override
  String get fontCorruptedSnackbar => 'La fuente está dañada.';

  @override
  String get licenseScreenTitle => 'Términos y licencias';

  @override
  String get licenseSectionTerms => 'Términos de uso';

  @override
  String get licenseSectionFonts => 'Fuentes utilizadas';

  @override
  String get licenseSectionOss => 'Licencias de software de código abierto';

  @override
  String get licenseOssListTitle => 'Lista de licencias de bibliotecas';

  @override
  String get licenseOssListSubtitle =>
      'Muestra las licencias de los paquetes OSS que usa esta aplicación';

  @override
  String get licenseFfmpegNote =>
      'Las exportaciones WebM y AVI usan FFmpeg (LGPL 3.0, a través de ffmpeg_kit_flutter_new_video). Origen del código fuente modificado: https://github.com/sk3llo/ffmpeg_kit_flutter\nLa exportación MP4 usa directamente el codificador de hardware integrado del dispositivo y no utiliza FFmpeg.';

  @override
  String licenseFontCreditMeta(String author, String license) {
    return 'Autor: $author   Licencia: $license';
  }

  @override
  String get toolbarPenTooltip => 'Pluma (mantén pulsado para subherramientas)';

  @override
  String get toolbarPenFirstUseTip =>
      'Mantén pulsada la pluma para alternar entre pincel, trama, sello y relleno de lazo.';

  @override
  String get toolbarBucketTooltip =>
      'Cubo de pintura (mantén pulsado para cambiar el relleno)';

  @override
  String get toolbarBucketFirstUseTip =>
      'Mantén pulsado el cubo de pintura para alternar entre relleno plano y relleno de trama.';

  @override
  String get toolbarSelectTooltip =>
      'Selección (mantén pulsado para cambiar el tipo)';

  @override
  String get toolbarShapeTooltip => 'Forma (toca para elegir el tipo)';

  @override
  String get toolbarTextFirstUseTip =>
      'Coloca texto libremente. También puedes cambiar la fuente, el color y el contorno.';

  @override
  String get toolbarQuickToolFirstUseTip =>
      'Toca para recorrer tus herramientas registradas en orden. Mantén pulsado o desliza hacia arriba para editar tus herramientas registradas.';

  @override
  String get toolbarStampColorLockedSnackbar =>
      'Los sellos conservan su propio color, por lo que no se puede cambiar';

  @override
  String get toolbarBrushSettingsTooltip => 'Ajustes del pincel';

  @override
  String get toolbarLayerTooltip => 'Capas';

  @override
  String get toolbarQuickToolTooltip =>
      'Herramienta rápida (mantén pulsado/desliza hacia arriba para editar)';

  @override
  String get toolbarSaveTooltip => 'Guardar (árbol de guardado)';

  @override
  String get toolbarBucketFlatFill => 'Relleno plano';

  @override
  String get toolbarBucketToneListLabel => 'Tramas';

  @override
  String get toolbarSelectRect => 'Selección rectangular';

  @override
  String get toolbarSelectLasso => 'Selección de lazo';

  @override
  String get toolbarSelectMagicWand => 'Selección automática (varita mágica)';

  @override
  String get creativePanelFavoritesOnlyTooltip => 'Mostrar solo favoritos';

  @override
  String get creativePanelSearchTooltip => 'Buscar por nombre';

  @override
  String get creativePanelFolderButton => 'Carpeta';

  @override
  String get creativePanelCreateButton => 'Crear';

  @override
  String get creativePanelImportButton => 'Importar';

  @override
  String get creativePanelFolderAllChip => 'Todas';

  @override
  String get creativePanelEditAction => 'Editar';

  @override
  String get toneTitle => 'Tramas';

  @override
  String get toneEmpty => 'No hay tramas';

  @override
  String get toneSearchHint => 'Buscar por nombre de trama';

  @override
  String get toneEditTitle => 'Editar trama';

  @override
  String get toneChangeTextureButton => 'Cambiar imagen de textura';

  @override
  String get toneCreateDialogTitle => 'Trama personalizada';

  @override
  String toneImportFailedSnackbar(String error) {
    return 'Error al cargar la trama: $error';
  }

  @override
  String toneExportFailedSnackbar(String error) {
    return 'Error al exportar la trama: $error';
  }

  @override
  String get privacyPolicyScreenTitle => 'Política de privacidad';

  @override
  String get stampTitle => 'Sellos';

  @override
  String get stampSearchHint => 'Buscar por nombre de sello';

  @override
  String get stampEmpty => 'No hay sellos';

  @override
  String get stampCreateDialogTitle => 'Sello personalizado';

  @override
  String stampImportFailedSnackbar(String error) {
    return 'Error al cargar el sello: $error';
  }

  @override
  String stampExportFailedSnackbar(String error) {
    return 'Error al exportar el sello: $error';
  }

  @override
  String get stampEditTitle => 'Editar sello';

  @override
  String get stampRotationLabel => 'Rotación';

  @override
  String get stampPixelModeLabel => 'Modo píxel';

  @override
  String get stampPixelModeHint =>
      'Se dibuja con estilo pixel art (mosaico + menos colores)';

  @override
  String get stampDensityLabel => 'Densidad';

  @override
  String get stampScatterLabel => 'Dispersión';

  @override
  String get stampChangeImageButton => 'Cambiar imagen del sello';

  @override
  String get themeSettingsTitle => 'Tema y apariencia';

  @override
  String get themeColorCustomizeSection => 'Personalización de colores';

  @override
  String get themeColorAccent => 'Color de acento';

  @override
  String get themeColorText => 'Color del texto';

  @override
  String get themeColorPanelBg => 'Color de fondo del panel';

  @override
  String get themeColorMenuBg => 'Color de fondo del menú';

  @override
  String get themeColorSelection => 'Color de selección';

  @override
  String get themeColorUpdateMark => 'Color de la marca de actualización';

  @override
  String get themePresetSection => 'Temas';

  @override
  String themePresetDuplicateName(String name) {
    return '$name (copia)';
  }

  @override
  String get themeDuplicateAction => 'Duplicar';

  @override
  String get themeExportMenuItem => 'Exportar (.niatheme)';

  @override
  String themeExportFailedSnackbar(String error) {
    return 'Error al exportar: $error';
  }

  @override
  String get themeImportSuccessSnackbar => 'Archivo .niatheme importado';

  @override
  String themeImportFailedSnackbar(String error) {
    return 'Error al importar: $error';
  }

  @override
  String get themeSaveAsNewButton => 'Guardar ajustes actuales como nuevo tema';

  @override
  String get themeImportButton => 'Importar .niatheme';

  @override
  String get themePresetNameDialogTitle => 'Nombre del tema';

  @override
  String get themeDefaultPresetName => 'Mi tema';

  @override
  String get onionSkinTitle => 'Papel cebolla';

  @override
  String get onionSkinPrevFrame => 'Fotograma anterior';

  @override
  String get onionSkinNextFrame => 'Fotograma siguiente';

  @override
  String get onionSkinFrameInterval => 'Intervalo de fotogramas';

  @override
  String get onionSkinFadeByDistance => 'Más oscuro cuanto más cerca';

  @override
  String get onionSkinColorPickerTitle => 'Elegir un color';

  @override
  String get onionSkinOnFixed => 'Activado (fijo)';

  @override
  String get onionSkinFrameCount => 'Número de fotogramas';

  @override
  String onionSkinFrameCountFixed(int count) {
    return '$count fotograma(s) (fijo)';
  }

  @override
  String get onionSkinColorLabel => 'Color';

  @override
  String get onionSkinOpacityLabel => 'Opacidad';

  @override
  String get exportScreenTitle => 'Exportar';

  @override
  String get exportPresetSection => 'Preajuste';

  @override
  String get exportPresetStandard => 'Estándar';

  @override
  String get exportPresetHighQuality => 'Alta calidad';

  @override
  String get exportPresetCustom => 'Personalizado';

  @override
  String get exportAdvancedSettings => 'Ajustes avanzados';

  @override
  String get exportFpsLabel => 'FPS';

  @override
  String get exportFormatSection => 'Formato';

  @override
  String get exportFormatMp4 => 'MP4';

  @override
  String get exportFormatMp4Subtitle => 'Formato de vídeo de uso general';

  @override
  String get exportFormatGif => 'GIF';

  @override
  String get exportFormatGifSubtitle => 'GIF animado';

  @override
  String get exportFormatWebmSubtitle => 'Vídeo con fondo transparente';

  @override
  String get exportFormatAvi => 'AVI';

  @override
  String get exportFormatAviSubtitle =>
      'Formato de vídeo compatible con versiones antiguas (sin transparencia)';

  @override
  String get exportStartButton => 'Iniciar exportación';

  @override
  String get exportProjectNotFoundError => 'No se encontró el proyecto';

  @override
  String exportFailedError(String error) {
    return 'Error al exportar: $error';
  }

  @override
  String get exportInProgressTitle => 'Exportando';

  @override
  String get exportCancelledSnackbar => 'Exportación cancelada';

  @override
  String get exportCancelHint =>
      'Finalizando el proceso; la cancelación se aplicará al terminar';

  @override
  String get exportOutdatedAutofillTitle =>
      'El coloreado automático no está actualizado';

  @override
  String get exportOutdatedAutofillBody =>
      'Hay capas de coloreado automático sin actualizar. ¿Exportar de todos modos?';

  @override
  String get exportContinueButton => 'Continuar';

  @override
  String get exportDurationExceededTitle => 'Se superó la duración máxima';

  @override
  String exportDurationExceededBody(int max, int current) {
    return 'La duración máxima de la versión gratuita es de $max segundos.\nEl proyecto actual dura aproximadamente $current segundos.\nActualizar a Premium amplía este límite hasta 2 horas.';
  }

  @override
  String get exportViewPremiumButton => 'Ver Premium';

  @override
  String get exportContinueAnywayButton => 'Continuar de todos modos';

  @override
  String get exportCompleteTitle => 'Exportación completa';

  @override
  String exportCompleteFramesBody(int count) {
    return 'Se exportaron $count fotograma(s).';
  }

  @override
  String exportSaveLocationLabel(String fileName) {
    return 'Guardado en: almacenamiento de la app ($fileName)';
  }

  @override
  String get exportSaveLocationHint =>
      'Para abrirlo en la app de Fotos o el gestor de archivos de tu dispositivo, usa \"Compartir\" a continuación para elegir dónde guardarlo.';

  @override
  String get exportBackToProjectsButton => 'Volver a proyectos';

  @override
  String get exportBackToCanvasButton => 'Volver al lienzo';

  @override
  String get newProjectScreenTitle => 'Nuevo proyecto';

  @override
  String get newProjectDefaultName => 'Nuevo proyecto';

  @override
  String get newProjectNameLabel => 'Nombre del proyecto';

  @override
  String get newProjectSizeLabel => 'Tamaño';

  @override
  String get newProjectPresetFullHd =>
      'Full HD (16:9, para YouTube y otros vídeos horizontales)';

  @override
  String get newProjectPresetHd => 'HD (16:9, versión ligera)';

  @override
  String get newProjectPresetSquare =>
      '1:1 Cuadrado (para publicaciones de Twitter/Instagram)';

  @override
  String get newProjectPresetVertical =>
      '9:16 Vertical (para YouTube Shorts/Reels/Historias)';

  @override
  String get newProjectPresetPortrait =>
      '4:5 Retrato (para publicaciones del feed de Instagram)';

  @override
  String get newProjectPresetAnalog =>
      '4:3 (relación de aspecto de emisión analógica clásica)';

  @override
  String get newProjectCustomSize => 'Personalizado';

  @override
  String get newProjectMaxEdgeHint =>
      'El lado más largo se puede definir hasta 1920 px';

  @override
  String get newProjectWidthLabel => 'Ancho (px)';

  @override
  String get newProjectHeightLabel => 'Alto (px)';

  @override
  String get newProjectWidthShort => 'Ancho';

  @override
  String get newProjectHeightShort => 'Alto';

  @override
  String get newProjectSizePresetManageButton => 'Ajustes de tamaño';

  @override
  String get newProjectSaveCustomSizeButton => 'Guardar este tamaño';

  @override
  String get newProjectSaveCustomSizeDialogTitle =>
      'Introduce un nombre para este tamaño';

  @override
  String get newProjectSaveCustomSizeNameLabel => 'Nombre del tamaño';

  @override
  String get newProjectSaveCustomSizeSavedSnackbar => 'Tamaño guardado';

  @override
  String get canvasSizePresetManageScreenTitle => 'Ajustes de tamaño';

  @override
  String get canvasSizePresetEmpty => 'Todavía no hay tamaños guardados';

  @override
  String get canvasSizePresetEmptyHint =>
      'Especifica un tamaño personalizado en la pantalla de nuevo proyecto y toca «Guardar este tamaño» para añadirlo';

  @override
  String get canvasSizePresetEditDialogTitle => 'Editar tamaño';

  @override
  String canvasSizePresetDeleteConfirmTitle(String name) {
    return '¿Eliminar «$name»?';
  }

  @override
  String get canvasSizePresetDuplicateSuffix => 'copia';

  @override
  String newProjectDurationLabel(String max) {
    return 'Duración (máx. $max)';
  }

  @override
  String newProjectDurationLabelWithPremiumHint(String max) {
    return 'Duración (máx. $max; hasta 2 horas con Premium)';
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
  String get newProjectBackgroundColorLabel => 'Color de fondo';

  @override
  String get newProjectDrawingAreaTitle => 'Ampliar el área de dibujo';

  @override
  String get newProjectDrawingAreaSubtitle =>
      'Añade una zona en la que dibujar fuera del marco de exportación';

  @override
  String get newProjectScaleLabel => 'Escala';

  @override
  String newProjectScaleValue(String value) {
    return '$value×';
  }

  @override
  String newProjectDrawableAreaInfo(String width, String scale, String result) {
    return 'Área dibujable: $width×$scale = $result';
  }

  @override
  String newProjectTotalFrames(int count) {
    return 'Total de fotogramas: $count';
  }

  @override
  String newProjectExportSizeInfo(String size) {
    return 'Tamaño de exportación: $size';
  }

  @override
  String newProjectDrawingAreaInfo(String size) {
    return 'Área de dibujo: $size';
  }

  @override
  String get colorPickerTitle => 'Selección de color';

  @override
  String get colorPickerOpacityLabel => 'Opacidad';

  @override
  String get colorPickerHexCopiedSnackbar => 'Código HEX copiado';

  @override
  String get colorPickerRecentColorsLabel => 'Colores recientes';

  @override
  String get colorPickerRecentColorsEmpty => 'Todavía no hay ninguno';

  @override
  String get colorPickerPaletteLabel => 'Paleta';

  @override
  String get colorPickerNewPaletteTooltip => 'Nueva paleta';

  @override
  String get colorPickerManagePaletteTooltip => 'Gestionar paleta';

  @override
  String get colorPickerPaletteEmptyHint =>
      'Aún no hay colores. Toca «+» para añadir el color actual.';

  @override
  String get colorPickerPaletteLongPressHint => 'Mantén pulsado para eliminar';

  @override
  String get colorPickerAddCurrentColorButton =>
      'Añadir el color actual a la paleta';

  @override
  String get colorPickerPaletteNameLabel => 'Nombre de la paleta';

  @override
  String get colorPickerFavoriteAdd => 'Añadir a favoritos';

  @override
  String get colorPickerFavoriteRemove => 'Quitar de favoritos';

  @override
  String get penSubToolTabBrush => 'Pincel';

  @override
  String get penSubToolTabTone => 'Trama';

  @override
  String get penSubToolTabStamp => 'Sello';

  @override
  String get penSubToolTabLassoFill => 'Relleno con lazo';

  @override
  String get penSubToolToneTooltipMessage =>
      'Elige una trama para pintar patrones de trama con el bote de pintura o el lápiz.';

  @override
  String get penSubToolStampTooltipMessage =>
      'Coloca sellos de forma fija. Mantén pulsado para ajustar la rotación, la densidad y más.';

  @override
  String get penSubToolLassoTooltipMessage =>
      'Rellena de una vez el área rodeada por el lazo.';

  @override
  String get penSubToolManageTooltip => 'Gestionar';

  @override
  String penSubToolBrushSizeOpacity(int size, int opacity) {
    return '${size}px · $opacity%';
  }

  @override
  String get penSubToolStampRotationSubtitle =>
      'Rotación aleatoria según la dirección del trazo';

  @override
  String get brushSearchHint => 'Buscar por nombre de pincel';

  @override
  String get brushEmpty => 'No hay pinceles';

  @override
  String get brushCreateDialogTitle => 'Pincel personalizado';

  @override
  String brushImportFailedSnackbar(String error) {
    return 'Error al cargar el pincel: $error';
  }

  @override
  String brushExportFailedSnackbar(String error) {
    return 'Error al exportar el pincel: $error';
  }

  @override
  String get brushSettingsSizeLabel => 'Tamaño';

  @override
  String get brushSettingsOpacityLabel => 'Opacidad';

  @override
  String get brushSettingsSpacingLabel => 'Espaciado';

  @override
  String get brushSettingsBlurRadiusLabel => 'Radio de desenfoque';

  @override
  String get brushSettingsStabilizationTitle => 'Estabilización del trazo';

  @override
  String get brushSettingsStabilizationStrengthLabel =>
      'Intensidad de estabilización';

  @override
  String get brushSettingsPixelModeTitle => 'Modo píxel';

  @override
  String get brushSettingsPressureModeTitle => 'Sensibilidad a la presión';

  @override
  String get brushSettingsPressureOff => 'Desactivado';

  @override
  String get brushSettingsPressureSize => 'Afecta al tamaño';

  @override
  String get brushSettingsPressureOpacity => 'Afecta a la opacidad';

  @override
  String get brushSettingsPressureSizeAndOpacity =>
      'Afecta al tamaño y la opacidad';

  @override
  String get brushSettingsFadeModeTitle => 'Desvanecido';

  @override
  String get brushSettingsFadeOff => 'OFF';

  @override
  String get brushSettingsFadeWeak => 'Débil';

  @override
  String get brushSettingsFadeMedium => 'Medio';

  @override
  String get brushSettingsFadeStrong => 'Fuerte';

  @override
  String get brushSettingsFadeCustom => 'Personalizado';

  @override
  String get brushSettingsFadeStartValueLabel => 'Valor inicial (%)';

  @override
  String get brushSettingsFadeEndValueLabel => 'Valor final (%)';

  @override
  String get brushSettingsFadeDistanceLabel => 'Distancia (px)';

  @override
  String get brushSettingsStrokeDecayTitle => 'Atenuación del trazo';

  @override
  String get brushSettingsStrokeDecaySubtitle =>
      'La opacidad disminuye cuanto más tiempo dibujas';

  @override
  String get brushSettingsMixingTitle => 'Mezcla de color';

  @override
  String get brushSettingsMixingOff => 'OFF';

  @override
  String get brushSettingsMixingSimple => 'Mezcla simple';

  @override
  String get brushSettingsMixingBleed => 'Sangrado';

  @override
  String get brushSettingsMixingRateLabel => 'Tasa de mezcla';

  @override
  String get projectDetailNotFoundTitle => 'Proyecto';

  @override
  String get projectDetailNotFoundBody => 'No se encontró el proyecto';

  @override
  String get projectDetailFirstFrameTooltip => 'Primer fotograma';

  @override
  String get projectDetailPrevFrameTooltip => 'Retroceder 1 fotograma';

  @override
  String get projectDetailPauseTooltip => 'Pausar';

  @override
  String get projectDetailPlayTooltip => 'Reproducir';

  @override
  String get projectDetailNextFrameTooltip => 'Avanzar 1 fotograma';

  @override
  String get projectDetailLastFrameTooltip => 'Último fotograma';

  @override
  String get projectDetailFullscreenTooltip =>
      'Mostrar vista previa a pantalla completa';

  @override
  String get projectDetailFullscreenCloseTooltip =>
      'Cerrar vista previa a pantalla completa';

  @override
  String get projectDetailCollapsePreviewTooltip => 'Reducir vista previa';

  @override
  String get projectDetailExpandPreviewTooltip =>
      'Restaurar tamaño de vista previa';

  @override
  String get projectDetailStartEditButton => 'Empezar a editar';

  @override
  String get projectDetailTagsQuickAction => 'Etiquetas';

  @override
  String get projectDetailShareQuickAction => 'Compartir';

  @override
  String get projectDetailInfoSectionTitle => 'Información del proyecto';

  @override
  String get projectDetailInfoExportSize => 'Tamaño de exportación';

  @override
  String get projectDetailInfoDrawingArea => 'Área de dibujo';

  @override
  String projectDetailInfoDrawingAreaValue(String size, String scale) {
    return '$size  ($scale)';
  }

  @override
  String get projectDetailInfoTotalFrames => 'Total de fotogramas';

  @override
  String get projectDetailInfoWorkTime => 'Tiempo de trabajo';

  @override
  String get projectDetailInfoLastSaved => 'Último guardado';

  @override
  String get projectDetailInfoSize => 'Tamaño';

  @override
  String get projectDetailSaveTreeButton => 'Árbol de guardado';

  @override
  String get projectDetailAddTagHint => 'Añadir etiqueta';

  @override
  String projectDetailNiashareFailedSnackbar(String error) {
    return 'Error al crear el .niashare: $error';
  }

  @override
  String get projectDetailTrashMenuItem => 'Mover a la papelera';

  @override
  String get commonOff => 'OFF';

  @override
  String get perfSettingsScreenTitle => 'Ajustes de rendimiento';

  @override
  String get perfSettingsQualitySection => 'Ajustes de calidad';

  @override
  String get perfSettingsQualityLow => 'Baja';

  @override
  String get perfSettingsQualityMedium => 'Media';

  @override
  String get perfSettingsQualityHigh => 'Alta';

  @override
  String get perfSettingsQualityCustom => 'Personalizada';

  @override
  String get perfSettingsQualityDescLow =>
      'Para un dispositivo en el que quieras aligerar el rendimiento (1 fotograma de papel cebolla en cada dirección, 5 ranuras de guardado)';

  @override
  String get perfSettingsQualityDescMedium =>
      'Para un dispositivo habitual (3 fotogramas de papel cebolla en cada dirección, 10 ranuras de guardado)';

  @override
  String get perfSettingsQualityDescHigh =>
      'Para un dispositivo con margen de rendimiento (5 fotogramas de papel cebolla en cada dirección, guardado en árbol)';

  @override
  String get perfSettingsQualityDescCustom =>
      'Configura cada elemento por separado';

  @override
  String get perfSettingsCapacitySection =>
      'Ajustes de almacenamiento y rendimiento';

  @override
  String get perfSettingsUndoLimitTitle => 'Pasos de deshacer';

  @override
  String get perfSettingsUndoLimitSubtitle =>
      'Cuantos más haya, más memoria se consume';

  @override
  String perfSettingsUndoLimitValue(int n) {
    return '$n pasos';
  }

  @override
  String get perfSettingsTrashAutoDeleteTitle =>
      'Eliminación automática de la papelera';

  @override
  String get perfSettingsTrashAutoDeleteSubtitle =>
      'Periodo de retención de proyectos eliminados';

  @override
  String perfSettingsTrashAutoDeleteValue(int n) {
    return '$n días';
  }

  @override
  String get perfSettingsCurrentSettingsSection => 'Ajustes actuales';

  @override
  String get perfSettingsTiltLabel => 'Detección de inclinación';

  @override
  String get perfSettingsOnionPrevLabel => 'Papel cebolla (anterior)';

  @override
  String get perfSettingsOnionNextLabel => 'Papel cebolla (siguiente)';

  @override
  String perfSettingsOnionFrameCountValue(int n) {
    return '$n fotogramas';
  }

  @override
  String get perfSettingsSaveModeLabel => 'Modo de guardado';

  @override
  String get perfSettingsSlotCountLabel => 'Número de ranuras';

  @override
  String perfSettingsSlotCountValue(int n) {
    return '$n ranuras';
  }

  @override
  String get perfSettingsResetButton => 'Restablecer valores predeterminados';

  @override
  String get perfSettingsCopyPresetButton => 'Copiar preajuste actual';

  @override
  String get perfSettingsTiltSwitchTitle =>
      'Aplicar la inclinación del lápiz al pincel';

  @override
  String get perfSettingsShowPrevOnionTitle => 'Mostrar fotograma anterior';

  @override
  String get perfSettingsOnionCountPrevLabel =>
      'Número de fotogramas de papel cebolla (anterior)';

  @override
  String get perfSettingsShowNextOnionTitle => 'Mostrar fotograma siguiente';

  @override
  String get perfSettingsOnionCountNextLabel =>
      'Número de fotogramas de papel cebolla (siguiente)';

  @override
  String get perfSettingsSaveModeSlot => 'Por ranuras';

  @override
  String get perfSettingsSaveModeTree => 'Por árbol';

  @override
  String get perfSettingsResetDialogTitle =>
      '¿Restablecer los ajustes de calidad personalizados a los valores predeterminados?';

  @override
  String perfSettingsResetDialogBody(String preset) {
    return 'El valor predeterminado corresponde al ajuste \"$preset\" que se determinó automáticamente según el rendimiento del dispositivo en el primer inicio.';
  }

  @override
  String get perfSettingsResetConfirmButton => 'Restablecer';

  @override
  String get perfSettingsCopyPresetDialogTitle =>
      'Elige un preajuste para copiar';

  @override
  String get perfSettingsCopyPresetDialogBody =>
      'Elige un preajuste para copiar en tus ajustes personalizados.';

  @override
  String get perfSettingsCopyDescLow =>
      'Muestra 1 fotograma en cada dirección · ligero';

  @override
  String get perfSettingsCopyDescMedium =>
      'Muestra 3 fotogramas en cada dirección · estándar';

  @override
  String get perfSettingsCopyDescHigh =>
      'Muestra 5 fotogramas en cada dirección · alta calidad';

  @override
  String get filterPanelTitle => 'Filtro';

  @override
  String filterPanelTitleBulk(int count) {
    return 'Filtro (aplicando a $count fotogramas)';
  }

  @override
  String get filterSearchHint => 'Buscar filtros';

  @override
  String get filterNameGaussianBlur => 'Desenfoque gaussiano';

  @override
  String get filterNameLensBlur => 'Desenfoque de lente';

  @override
  String get filterNameAnimeStyle => 'Estilo anime';

  @override
  String get filterNameOutline => 'Contorno';

  @override
  String get filterNameToneCurve => 'Curva de tonos';

  @override
  String get filterNameLevels => 'Niveles';

  @override
  String get filterNameSharpen => 'Enfoque';

  @override
  String get filterNameUnsharpMask => 'Máscara de enfoque';

  @override
  String get filterSharpenStrength => 'Intensidad de enfoque';

  @override
  String get filterUnsharpAmount => 'Intensidad';

  @override
  String get filterNameVignette => 'Viñeta';

  @override
  String get filterVignetteStrength => 'Intensidad de viñeta';

  @override
  String get filterVignetteColor => 'Color de viñeta';

  @override
  String get filterNameNoise => 'Grano de película';

  @override
  String get filterNoiseStrength => 'Intensidad del grano';

  @override
  String get filterNameRetroAnime => 'Anime retro';

  @override
  String get filterNameCrt => 'Tubo de rayos catódicos';

  @override
  String get filterRetroStrength => 'Intensidad';

  @override
  String filterOutlineLayerNameSuffix(String name) {
    return '$name (Contorno)';
  }

  @override
  String get filterStrengthBlurRadius => 'Intensidad (radio de desenfoque)';

  @override
  String get filterColorLevels => 'Número de colores';

  @override
  String get filterEdgeStrength => 'Realce de bordes';

  @override
  String get filterOutlineColor => 'Color del contorno';

  @override
  String get filterOutlineWidth => 'Grosor del contorno';

  @override
  String get filterToneCurveLinear => 'Estándar';

  @override
  String get filterToneCurveBrighten => 'Aclarar';

  @override
  String get filterToneCurveDarken => 'Oscurecer';

  @override
  String get filterToneCurveHighContrast => 'Contraste alto';

  @override
  String get filterToneCurveLowContrast => 'Contraste bajo';

  @override
  String get filterToneCurveInvert => 'Invertir';

  @override
  String get filterLevelsInputBlack => 'Entrada: Negro';

  @override
  String get filterLevelsInputWhite => 'Entrada: Blanco';

  @override
  String get filterLevelsOutputBlack => 'Salida: Negro';

  @override
  String get filterLevelsOutputWhite => 'Salida: Blanco';

  @override
  String get filterApplyButton => 'Aplicar';

  @override
  String filterApplyBulkButton(int count) {
    return 'Aplicar a $count fotogramas';
  }

  @override
  String get filterEmpty => 'No hay filtros';

  @override
  String get filterApplyingTitle => 'Aplicando filtro';

  @override
  String filterApplyingSubtitle(String name, int count) {
    return '$name　$count fotogramas';
  }

  @override
  String get projectListNewFolderTitle => 'Nueva carpeta';

  @override
  String get projectListFolderHint =>
      'También puedes usarlo para agrupar varios episodios o una serie de la misma obra';

  @override
  String get projectListEmptyTitle => 'No hay proyectos';

  @override
  String get projectListEmptyHint => 'Toca + para crear uno nuevo';

  @override
  String get projectListOpenAction => 'Abrir';

  @override
  String get projectListCreateShareAction => 'Crear .niashare';

  @override
  String get projectListEditFolderAction => 'Editar nombre y color';

  @override
  String get projectListDeleteFolderConfirmTitle => '¿Eliminar esta carpeta?';

  @override
  String projectListDeleteFolderConfirmBody(String name) {
    return 'Se eliminará \"$name\". Los proyectos y subcarpetas que contiene se moverán a la raíz.';
  }

  @override
  String get projectListFolderRootOption => 'Sin carpeta (raíz)';

  @override
  String get projectListEditFolderTooltip => 'Editar carpeta';

  @override
  String get projectListCreateFolderAction => 'Crear nueva carpeta';

  @override
  String get projectListFolderColorLabel => 'Color de la carpeta';

  @override
  String get projectListMaterialIncludeTitle => 'Incluir materiales';

  @override
  String get projectListMaterialIncludeHint =>
      'Si no se incluyen, el destinatario verá una advertencia de materiales faltantes.';

  @override
  String get projectListMaterialImage => 'Imágenes';

  @override
  String get projectListMaterialVideo => 'Vídeos';

  @override
  String get projectListMaterialAudio => 'Audio';

  @override
  String get projectListIncludeFontsTitle => 'Incluir fuentes';

  @override
  String get projectListIncludeFontsSubtitle =>
      'Incluye las fuentes añadidas por el usuario que están en uso';

  @override
  String get blendModeNormal => 'Normal';

  @override
  String get blendModeMultiply => 'Multiplicar';

  @override
  String get blendModeScreen => 'Trama';

  @override
  String get blendModeOverlay => 'Superponer';

  @override
  String get blendModeAddition => 'Suma';

  @override
  String get blendModeSubtract => 'Resta';

  @override
  String get blendModeDarken => 'Oscurecer';

  @override
  String get blendModeLighten => 'Aclarar';

  @override
  String get blendModeColorBurn => 'Subexponer color';

  @override
  String get blendModeColorDodge => 'Sobreexponer color';

  @override
  String get blendModeHardLight => 'Luz fuerte';

  @override
  String get blendModeSoftLight => 'Luz suave';

  @override
  String get blendModeDifference => 'Diferencia';

  @override
  String get blendModeHue => 'Tono';

  @override
  String get blendModeSaturation => 'Saturación';

  @override
  String get blendModeColor => 'Color';

  @override
  String get blendModeLuminosity => 'Luminosidad';

  @override
  String get autofillLineColorModeSpecified => 'Color especificado';

  @override
  String get autofillLineColorModeSameAsFill => 'Igual que el relleno';

  @override
  String get autofillLineColorModeTraceAdjust =>
      'Trazado de color / mezcla con el trazo';

  @override
  String get autofillGradientTypeLinear => 'Lineal';

  @override
  String get autofillGradientTypeRadialCenterOut => 'Radial: centro → exterior';

  @override
  String get autofillGradientTypeRadialOutCenter => 'Radial: exterior → centro';

  @override
  String get autofillPresetScreenTitle => 'Ajustes de relleno automático';

  @override
  String get autofillPresetSearchHint => 'Buscar ajustes';

  @override
  String get autofillPresetEmptyFavorites => 'No hay ajustes favoritos';

  @override
  String get autofillPresetEmpty => 'No hay ajustes';

  @override
  String get autofillPresetEmptyHint =>
      'Toca + en la parte inferior derecha para crear uno';

  @override
  String autofillPresetPartsCount(int count) {
    return '$count partes';
  }

  @override
  String get autofillPresetNewDialogTitle => 'Nuevo';

  @override
  String get autofillPresetNameLabel => 'Nombre del ajuste';

  @override
  String get autofillPresetRenameDialogTitle => 'Renombrar ajuste';

  @override
  String autofillPresetDeleteConfirmTitle(String name) {
    return '¿Eliminar \"$name\"?';
  }

  @override
  String get autofillFabImportOption => 'Importar';

  @override
  String get autofillPresetExportMenuItem => 'Exportar (.niafill)';

  @override
  String autofillPresetImportSuccessSnackbar(int count) {
    return 'Se importaron $count ajuste(s)';
  }

  @override
  String autofillPresetImportFailedSnackbar(String error) {
    return 'Error al importar: $error';
  }

  @override
  String autofillPresetExportFailedSnackbar(String error) {
    return 'Error al exportar: $error';
  }

  @override
  String autofillPresetDuplicateName(String name) {
    return '$name (copia)';
  }

  @override
  String get autofillPartSearchHint => 'Buscar por nombre de parte';

  @override
  String autofillPartUnconfiguredBanner(int count, String names) {
    return 'Hay $count parte(s) sin configurar: $names (sin trama seleccionada)\nNo puedes cerrar esta pantalla hasta que todo esté configurado.';
  }

  @override
  String get autofillPartUnconfiguredDialogTitle => 'Hay partes sin configurar';

  @override
  String get autofillPartUnconfiguredDialogBody =>
      'Configura las siguientes partes antes de guardar.';

  @override
  String autofillPartUnconfiguredItem(String name) {
    return '• $name: sin trama seleccionada';
  }

  @override
  String get autofillPartUnconfiguredBackButton => 'Volver a la configuración';

  @override
  String get autofillPartEmpty => 'No hay partes\nToca + para añadir una';

  @override
  String get autofillPartToneUnselected => 'Sin trama seleccionada';

  @override
  String get autofillPartAddDialogTitle => 'Añadir parte';

  @override
  String get autofillPartNameLabel => 'Nombre de la parte';

  @override
  String get autofillPartAddButton => 'Añadir';

  @override
  String get autofillPartRenameDialogTitle => 'Renombrar parte';

  @override
  String autofillPartDetailDialogTitle(String name) {
    return 'Detalles de $name';
  }

  @override
  String get autofillPartFillColorLabel => 'Color de relleno';

  @override
  String get autofillPartSelectColorButton => 'Elegir color';

  @override
  String get autofillPartOutlineLabel => 'Contorno con color especificado';

  @override
  String autofillPartOutlineWidthLabel(int value) {
    return 'Grosor del contorno: ${value}px';
  }

  @override
  String get autofillPartResetLineColorButton => 'Restablecer';

  @override
  String get autofillThumbnailHint =>
      'Configura una imagen en miniatura (p. ej. una ilustración de referencia) para extraer colores de ella con el cuentagotas.';

  @override
  String get autofillThumbnailSetButton => 'Añadir imagen';

  @override
  String get autofillThumbnailChangeButton => 'Cambiar imagen';

  @override
  String get autofillEyedropperFromThumbnailButton => 'Extraer de la imagen';

  @override
  String get autofillEyedropperDialogTitle => 'Extraer un color de la imagen';

  @override
  String get autofillEyedropperDialogHint =>
      'Toca la imagen para elegir un color';

  @override
  String get autofillEyedropperPickedLabel => 'Color elegido';

  @override
  String get autofillEyedropperImageLoadFailedSnackbar =>
      'No se pudo cargar la imagen.';

  @override
  String get autofillThumbnailMenuItem => 'Configurar imagen en miniatura';

  @override
  String get autofillThumbnailLoadButton => 'Cargar imagen';

  @override
  String get autofillThumbnailDeleteButton => 'Eliminar imagen en miniatura';

  @override
  String get autofillThumbnailDeleteConfirmTitle =>
      '¿Eliminar la imagen en miniatura?';

  @override
  String get autofillThumbnailDeleteConfirmBody =>
      'Esto restaura la visualización de colores predeterminada (hasta 4 colores).';

  @override
  String get autofillThumbnailCropDialogTitle =>
      'Ajustar la imagen en miniatura';

  @override
  String get autofillThumbnailCropDialogHint =>
      'Arrastra para mover, pellizca para hacer zoom, gira con dos dedos para rotar';

  @override
  String get autofillThumbnailCropLoadFailed =>
      'No se pudo cargar la imagen. Prueba con otra.';

  @override
  String get autofillThumbnailSetSnackbar => 'Imagen en miniatura configurada';

  @override
  String get autofillPartGradientSetButton => 'Configurar degradado';

  @override
  String get autofillPartGradientEditButton => 'Editar degradado';

  @override
  String autofillPartFillOpacityLabel(int value) {
    return 'Opacidad (capa de relleno): $value%';
  }

  @override
  String get autofillPartLineColorLabel => 'Color del trazo';

  @override
  String autofillPartTraceHueLabel(int value) {
    return 'Tono: $value';
  }

  @override
  String autofillPartTraceSaturationLabel(int value) {
    return 'Saturación: $value';
  }

  @override
  String autofillPartTraceLightnessLabel(int value) {
    return 'Luminosidad: $value';
  }

  @override
  String autofillPartLineOpacityLabel(int value) {
    return 'Opacidad (capa de trazo): $value%';
  }

  @override
  String get autofillPartToneLabel => 'Trama';

  @override
  String get autofillPartUseToneCheckbox => 'Usar trama';

  @override
  String get autofillPartBlendModeLabel => 'Modo de fusión';

  @override
  String get autofillPartApplyButton => 'Aplicar';

  @override
  String autofillPartGradientDialogTitle(String name) {
    return 'Degradado de $name';
  }

  @override
  String get autofillPartGradientTypeLabel => 'Tipo';

  @override
  String get autofillPartGradientTypeInfo =>
      'Lineal: el color cambia siguiendo el ángulo indicado. Radial centro→exterior: los colores cambian desde el centro hacia afuera. Radial exterior→centro: al revés.';

  @override
  String get autofillPartGradientFeatherInfo =>
      'Con 0%, el límite entre colores vecinos es nítido. Con 100%, los colores se mezclan por completo y suavemente hasta el borde del color vecino.';

  @override
  String get autofillLineColorModeTraceAdjustInfo =>
      'Mantiene el color original de la línea pero ajusta ligeramente su tono, saturación y luminosidad. Úsalo cuando quieras conservar los matices del dibujo lineal en vez de rellenar las líneas con un color plano.';

  @override
  String autofillPartGradientAngleLabel(int value) {
    return 'Ángulo: $value°';
  }

  @override
  String get autofillPartGradientColorLabel => 'Colores';

  @override
  String get autofillPartGradientAddColorButton => 'Añadir color';

  @override
  String get autofillPartGradientDeleteHint =>
      'Mantén pulsado para eliminar (mínimo 2 colores)';

  @override
  String get autofillPartGradientRemoveButton => 'Quitar degradado';

  @override
  String autofillPartGradientFeatherLabel(int value) {
    return 'Intensidad del desenfoque: $value%';
  }

  @override
  String get autofillPartGradientDragHint =>
      'Arrastra el tirador de la derecha para reordenar los colores';

  @override
  String autofillPartGradientStopLabel(int value) {
    return 'Posición: $value%';
  }

  @override
  String get autofillPartGradientStopDragHint =>
      'Arrastra los marcadores ▲ hacia los lados para ajustar la posición de cada color';

  @override
  String get saveTreeScreenTitleTree => 'Árbol de guardado';

  @override
  String get saveTreeScreenTitleSlot => 'Ranuras de guardado';

  @override
  String get timelineExportMenuItem => 'Exportar';

  @override
  String get timelineExportFrameMenuItem => 'Exportar fotograma como imagen';

  @override
  String get timelineExportFrameDialogTitle => 'Exportar fotograma como imagen';

  @override
  String get timelineExportFrameDialogMessage =>
      'Guarda el fotograma actualmente mostrado como imagen fija. Elige un formato.';

  @override
  String get timelineExportFramePngOption => 'Guardar como PNG';

  @override
  String get timelineExportFrameJpegOption => 'Guardar como JPEG';

  @override
  String timelineExportFrameSuccessSnackbar(String fileName) {
    return 'Guardado como $fileName (disponible en la pestaña de trabajos exportados)';
  }

  @override
  String get timelineExportFrameErrorSnackbar =>
      'No se pudo exportar el fotograma';

  @override
  String get timelineDurationChangeMenuItem => 'Cambiar duración';

  @override
  String get timelineCanvasSizeChangeMenuItem => 'Cambiar tamaño de lienzo';

  @override
  String get timelineDurationFramesLabel => 'Fotogramas';

  @override
  String get timelineDurationSecondsLabel => 'Segundos';

  @override
  String get timelineDurationShrinkConfirmTitle => '¿Acortar de todos modos?';

  @override
  String get timelineDurationShrinkConfirmBody =>
      'Los fotogramas que se recortarán contienen cambios, como contenido dibujado o capas añadidas. Si continúas, esos fotogramas no se podrán recuperar. ¿Seguro que quieres eliminarlos?';

  @override
  String get timelineCanvasSizeDragHint =>
      'Arrastra dentro del marco para moverlo, o arrastra una esquina para cambiar el tamaño (se ajusta cerca del tamaño original)';

  @override
  String get timelineCanvasSizeAngleLabel => 'Ángulo';

  @override
  String get saveTreeSaveAsChildHint =>
      'Se guardará como elemento secundario del nodo seleccionado.';

  @override
  String get saveTreeSaveAsRootHint => 'Se guardará como nodo raíz.';

  @override
  String get saveTreeCommentLabel => 'Comentario (opcional)';

  @override
  String get saveTreeCommentHint => 'ej.: Fondo terminado';

  @override
  String saveTreeSizeWarningSnackbar(String mb) {
    return 'El árbol de guardado está ocupando mucho espacio (unos $mb MB). Te recomendamos eliminar los guardados que ya no necesites.';
  }

  @override
  String saveTreeSaveFailedSnackbar(String error) {
    return 'Error al guardar. Comprueba el espacio libre e inténtalo de nuevo ($error)';
  }

  @override
  String saveTreeSlotSaveDialogTitle(int n) {
    return 'Guardar en la ranura $n';
  }

  @override
  String saveTreeSlotOverwriteWarning(String date) {
    return 'Esto sobrescribirá los datos existentes ($date).';
  }

  @override
  String get saveTreeRestoreAction => 'Restaurar';

  @override
  String get saveTreeTimelineActionChoiceBody =>
      'Elige si quieres sobrescribir esta partida guardada con el contenido actual, o reanudar el trabajo desde aquí.';

  @override
  String get saveTreeOverwriteAction => 'Sobrescribir';

  @override
  String get saveTreeOverwriteConfirmBody =>
      'Se perderán los datos guardados en ese momento. ¿Continuar?';

  @override
  String get saveTreeResumeFromHereAction => 'Reanudar desde aquí';

  @override
  String get saveTreeResumeConfirmBody =>
      'Se perderán los cambios que no hayas guardado. ¿Continuar?';

  @override
  String get saveTreeProjectDetailResumeBody =>
      '¿Reanudar el trabajo desde esta partida guardada?';

  @override
  String get saveTreeLoadFailedSnackbar =>
      'No se pudieron cargar los datos guardados';

  @override
  String saveTreeRestoredSnackbar(String name) {
    return 'Se restauró $name';
  }

  @override
  String saveTreeSlotLabel(int n) {
    return 'Ranura $n';
  }

  @override
  String saveTreeSlotFallbackName(int n) {
    return 'Ranura $n';
  }

  @override
  String get saveTreeNoDataLabel => 'Sin datos guardados';

  @override
  String get saveTreeEmptyTitle => 'No hay datos guardados';

  @override
  String get saveTreeEmptyHint =>
      'Toca el botón \"Guardar\" de arriba para crear el primer nodo';

  @override
  String get saveTreeNodeDefaultTitle => 'Guardado';

  @override
  String get saveTreeNodeDefaultName => 'Datos guardados';

  @override
  String get saveTreeChangeDataTitle => 'Cambiar datos guardados';

  @override
  String saveTreeChangeDataTitleWithProject(String name) {
    return 'Cambiar datos guardados ($name)';
  }

  @override
  String get saveTreeChangeExceedMessage =>
      'El número actual de guardados supera\nel nuevo límite de guardado.\n\nElige qué guardados conservar.';

  @override
  String saveTreeKeepableCountLabel(int n) {
    return 'Guardados que puedes conservar: $n';
  }

  @override
  String saveTreeKeepLatestButton(int n) {
    return 'Conservar los $n más recientes';
  }

  @override
  String get saveTreeSelectDataButton => 'Elegir datos guardados';

  @override
  String saveTreeSelectedCountLabel(int selected, int limit) {
    return 'Seleccionados: $selected / $limit';
  }

  @override
  String get saveTreeBackButton => 'Atrás';

  @override
  String get saveTreeNextButton => 'Siguiente';

  @override
  String get saveTreeDiscardDialogTitle => 'Datos guardados no seleccionados';

  @override
  String get saveTreeArchiveOptionTitle =>
      'Conservar como archivo (recomendado)';

  @override
  String get saveTreeArchiveOptionSubtitle =>
      'Se restaura automáticamente si vuelves al guardado en árbol.\nUsa espacio de almacenamiento.';

  @override
  String get saveTreeDeleteOptionTitle => 'Eliminar permanentemente';

  @override
  String saveTreeDeleteOptionSubtitle(int count) {
    return 'Elimina permanentemente los $count elementos no seleccionados.\nLibera espacio de almacenamiento.\n※ Los datos eliminados no se pueden recuperar.';
  }

  @override
  String get saveTreeApplyChangeButton => 'Aplicar cambio';

  @override
  String get canvasEditMenuAutofillPresets => 'Ajustes de coloreado automático';

  @override
  String get canvasEditMenuAutofillPresetsSubtitle =>
      'Edita las combinaciones de color/tono de cada parte';

  @override
  String get canvasEditMenuBackgroundToggle => 'Cambiar fondo';

  @override
  String get canvasEditMenuBackgroundCurrentColor =>
      'Actual: color de fondo del proyecto (toca para pasar a transparente)';

  @override
  String get canvasEditMenuBackgroundCurrentTransparent =>
      'Actual: transparente (toca para pasar al color de fondo del proyecto)';

  @override
  String get canvasEditMenuOnionSkinSubtitle =>
      'Superpone tenuemente los fotogramas anterior/siguiente';

  @override
  String get canvasEditMenuFilterSubtitle =>
      'Aplica desenfoque, curvas de tono y más';

  @override
  String get canvasEditMenuFrameMultiSelect =>
      'Selección múltiple de fotogramas';

  @override
  String get canvasEditMenuFrameMultiSelectSubtitle =>
      'Para procesos por lotes (p. ej., aplicar un filtro a varios fotogramas)';

  @override
  String get canvasEditMenuPressureCurve => 'Curva de presión';

  @override
  String get canvasEditMenuPressureCurveSubtitle =>
      'Abrir los ajustes de entrada del lápiz (compartidos con Ajustes)';

  @override
  String get canvasEditMenuMeshTransform =>
      'Transformación libre / Deformación de malla';

  @override
  String get canvasEditMenuMeshTransformSubtitle =>
      'Transforma toda la capa sin seleccionar';

  @override
  String get meshTransformPanelTitle =>
      'Transformación libre / Deformación de malla';

  @override
  String get meshTransformPanelHint =>
      'Arrastra las esquinas o los puntos de la cuadrícula con el dedo (pellizca dos puntos distintos con dos dedos para rotar o escalar)';

  @override
  String get meshTransformDensityLabel => 'Densidad de cuadrícula';

  @override
  String get meshTransformRotateLabel => 'Rotación';

  @override
  String get meshTransformScaleLabel => 'Escala';

  @override
  String get meshTransformApplyButton => 'Aplicar';

  @override
  String get canvasLassoEnclosedLabel => 'Rellenar área cerrada';

  @override
  String get canvasInvertSelectionTooltip => 'Invertir selección';

  @override
  String get canvasTapToEnterTextLabel =>
      'Toca el lienzo para introducir texto';

  @override
  String get canvasRulerFirstUseTip =>
      'La regla te permite dibujar líneas rectas y formas limpias.';

  @override
  String get canvasRulerTooltip => 'Regla';

  @override
  String get commonUndo => 'Deshacer';

  @override
  String get commonRedo => 'Rehacer';

  @override
  String get canvasSettingsMenuTooltip => 'Ajustes/Editar';

  @override
  String canvasFrameSelectedCount(int selected, int total) {
    return '$selected / $total fotogramas seleccionados';
  }

  @override
  String get canvasSelectAllButton => 'Seleccionar todo';

  @override
  String get canvasDeselectAllButton => 'Deseleccionar todo';

  @override
  String get canvasApplyFilterButton => 'Aplicar filtro';

  @override
  String get canvasShapeOff => 'Desactivado (volver al pincel normal)';

  @override
  String get canvasShapeLine => 'Línea';

  @override
  String get canvasShapeRect => 'Rectángulo';

  @override
  String get canvasShapeCircle => 'Círculo';

  @override
  String get canvasMissingMaterialsSnackbar => 'Faltan algunos materiales';

  @override
  String get canvasResearchButton => 'Buscar de nuevo';

  @override
  String get canvasTextInputTitle => 'Introducir texto';

  @override
  String get canvasTextEditTitle => 'Editar texto';

  @override
  String get canvasTextInputHint => 'Introduce tu texto';

  @override
  String get canvasTextFontLabel => 'Fuente';

  @override
  String get canvasTextStandardFont => 'Fuente estándar';

  @override
  String get canvasTextBold => 'Negrita';

  @override
  String get canvasTextItalic => 'Cursiva';

  @override
  String get canvasTextVertical => 'Vertical';

  @override
  String get canvasTextHorizontal => 'Horizontal';

  @override
  String get canvasTypesettingHelpTooltip =>
      'Sobre la composición tipográfica y el furigana';

  @override
  String get canvasTextLineHeight => 'Interlineado';

  @override
  String get canvasTextLetterSpacing => 'Espaciado de letras';

  @override
  String get canvasTextAlign => 'Alineación';

  @override
  String get canvasTextOutline => 'Contorno';

  @override
  String get canvasOutlineWidthLabel => 'Grosor';

  @override
  String get canvasHelpRotationTitle =>
      'Rotación de caracteres alfanuméricos de medio ancho (solo vertical)';

  @override
  String get canvasHelpRotationBody =>
      'Las letras y los símbolos se giran automáticamente 90° al mostrarse.';

  @override
  String get canvasHelpTatechuyokoTitle => 'Tate-chu-yoko (solo vertical)';

  @override
  String get canvasHelpTatechuyokoBody =>
      'Dos dígitos de medio ancho consecutivos se colocan automáticamente uno junto al otro dentro de la altura de un solo carácter (p. ej., 12).';

  @override
  String get canvasHelpRubyTitle => 'Furigana (glosa fonética)';

  @override
  String canvasHelpRubyBody(String example) {
    return 'Al escribir algo como «$example» se muestra una pequeña anotación de lectura encima de los caracteres base (en horizontal) o a su derecha (en vertical). Funciona en ambos sentidos, pero el texto que contiene furigana no se ajustará automáticamente de línea en modo horizontal (solo saltos de línea manuales).';
  }

  @override
  String get layerPanelTitle => 'Capas';

  @override
  String get layerPanelHelpTooltip => 'Ayuda';

  @override
  String get layerPanelSearchHint => 'Buscar por nombre de capa';

  @override
  String get layerPanelSelectAll => 'Seleccionar todo';

  @override
  String get layerPanelDeselectAll => 'Deseleccionar todo';

  @override
  String get layerPanelNewLayerButton => 'Nueva capa';

  @override
  String get layerPanelNewFolderButton => 'Nueva carpeta';

  @override
  String get layerPanelImportImageButton => 'Importar imagen';

  @override
  String layerPanelDefaultLayerName(int n) {
    return 'Capa$n';
  }

  @override
  String layerPanelDefaultFolderName(int n) {
    return 'Carpeta$n';
  }

  @override
  String layerPanelDefaultLineartName(int n) {
    return 'Línea$n';
  }

  @override
  String layerPanelDefaultAutofillName(int n) {
    return 'RelleAuto$n';
  }

  @override
  String layerPanelDefaultCommonName(int n) {
    return 'Común$n';
  }

  @override
  String layerPanelDefaultSelectionName(int n) {
    return 'Selección$n';
  }

  @override
  String get layerPanelClippingBadge => 'Recorte';

  @override
  String get layerPanelAddTooltip => 'Añadir';

  @override
  String get layerPanelMergeTooltip => 'Combinar';

  @override
  String get layerPanelSettingsTooltip => 'Ajustes de capa';

  @override
  String get layerPanelAutofillMarkTooltip =>
      'El dibujo de líneas se actualizó. Toca para poner al día el relleno automático.';

  @override
  String get layerPanelRangeAllFrames => 'Todos los fotogramas';

  @override
  String get layerPanelRangeCurrentScene => 'Escena actual';

  @override
  String get layerPanelRangeSceneSpecified => 'Escena específica';

  @override
  String layerPanelRangeFrameSpan(int start, int end) {
    return '$start–$end';
  }

  @override
  String get layerPanelMenuFrameRangeChange => 'Cambiar rango de fotogramas';

  @override
  String get layerPanelMenuRangeChange => 'Cambiar rango de visualización';

  @override
  String get layerPanelMenuPartAssign => 'Asignar parte';

  @override
  String get layerPanelMenuRunAutofill => 'Ejecutar relleno automático';

  @override
  String get layerPanelMenuOrphanFill => 'Rellenar con el color más reciente';

  @override
  String get layerPanelMenuOrphanFillSubtitle =>
      'No se encontró una capa de líneas correspondiente, así que solo se actualizará el color';

  @override
  String get layerPanelMenuReplaceMaterial => 'Reemplazar material';

  @override
  String layerPanelDeleteConfirmTitle(String name) {
    return '¿Eliminar $name?';
  }

  @override
  String get layerPanelDeleteConfirmBody =>
      'Este material se eliminará de todos los fotogramas dentro de su rango de visualización.';

  @override
  String layerPanelMultiDeleteConfirmTitle(int count) {
    return '¿Eliminar los $count elementos seleccionados?';
  }

  @override
  String get layerPanelMultiDeleteConfirmBody =>
      'Los materiales de la línea de tiempo se eliminarán de todos los fotogramas dentro de su rango de visualización.';

  @override
  String layerPanelCommonDeleteMidDialogTitle(String name) {
    return '¿Cambiar el rango de visualización de $name?';
  }

  @override
  String get layerPanelCommonDeleteMidDialogBody =>
      'El rango de visualización de una capa compartida solo puede ser un único intervalo continuo, por lo que no se puede eliminar desde un fotograma intermedio de ese rango. Elige si quieres conservar la parte anterior o posterior a este fotograma.';

  @override
  String get layerPanelCommonDeleteKeepBeforeButton => 'Conservar lo anterior';

  @override
  String get layerPanelCommonDeleteKeepAfterButton => 'Conservar lo posterior';

  @override
  String get layerPanelRangeDialogTitle => 'Rango de visualización';

  @override
  String get layerPanelRangeStartFrameLabel => 'Fotograma inicial';

  @override
  String get layerPanelRangeEndFrameLabel => 'Fotograma final';

  @override
  String get layerPanelRangeTilde => '–';

  @override
  String get layerPanelRangeUseCurrentButton => 'Usar rango actual';

  @override
  String get layerPanelRangeTargetSceneLabel => 'Escena objetivo';

  @override
  String get layerPanelRangeFrameRangeLabel => 'Rango de fotogramas específico';

  @override
  String get layerPanelMenuNormalLayer => 'Capa normal';

  @override
  String get layerPanelMenuCommonLayer => 'Capa común';

  @override
  String get layerPanelMenuLineartLayer =>
      'Capa de líneas para relleno automático';

  @override
  String get layerPanelMenuAutofillLayer => 'Capa de relleno automático';

  @override
  String get layerPanelMenuSelectionLayer => 'Capa de selección';

  @override
  String get layerPanelOpacityLabel => 'Opacidad';

  @override
  String get layerPanelLockLabel => 'Bloquear';

  @override
  String get layerPanelOpacityLockLabel => 'Bloquear opacidad';

  @override
  String get layerPanelClippingDescription =>
      'Dibujar solo dentro del área opaca de la capa inferior';

  @override
  String get layerPanelConvertToCommonLabel => 'Cambiar a capa común';

  @override
  String get layerPanelConvertOption1Title => 'Hacer común la capa actual';

  @override
  String get layerPanelConvertOption1Subtitle =>
      'Establece solo esta capa como capa común';

  @override
  String get layerPanelConvertOption2Title =>
      'Combinar las capas visibles en una capa común';

  @override
  String get layerPanelConvertOption2Subtitle =>
      'Crea una capa común a partir del resultado combinado de todas las capas actualmente visibles';

  @override
  String get layerPanelCommonRangeTitle => 'Rango de la capa común';

  @override
  String get layerPanelHelpDialogTitle => 'Acerca de las capas';

  @override
  String get layerPanelHelpBlendModeBody =>
      'Cambia cómo se compone la capa: multiplicar, trama, superposición, etc.';

  @override
  String get layerPanelHelpClippingBody =>
      'Dibuja solo dentro del área de píxeles opacos de la capa inferior. Úsalo para controlar el área de dibujo.';

  @override
  String get layerPanelCommonLayerLabel => 'Capa común';

  @override
  String get layerPanelHelpCommonLayerBody =>
      'Una capa cuyo contenido se comparte entre varios fotogramas. Puedes definir el rango de fotogramas en el que aparece.';

  @override
  String get layerPanelAutofillMethodTitle => 'Método de relleno automático';

  @override
  String get layerPanelAutofillNoLineartSnackbar =>
      'No se encontró una capa de líneas para relleno automático correspondiente.';

  @override
  String get layerPanelAutofillNote1 =>
      '✳ Cualquiera de las opciones está bien la primera vez que ejecutas el relleno automático en este proyecto.';

  @override
  String get layerPanelAutofillNote2 =>
      '✳ Si aún no existe una capa de relleno automático, el área se determinará desde cero de todos modos.';

  @override
  String get layerPanelAutofillRepaintTitle => 'Repintar';

  @override
  String get layerPanelAutofillRepaintHint =>
      'Recomendado si la forma del relleno automático se modificó por accidente';

  @override
  String get layerPanelAutofillRepaintNote =>
      '✳ Determina el área desde cero y la repinta. Se descartará la forma actual de la capa de relleno automático.';

  @override
  String get layerPanelAutofillColorUpdateTitle => 'Actualizar color';

  @override
  String get layerPanelAutofillColorUpdateHint =>
      'Recomendado si la forma del relleno automático se ajustó manualmente';

  @override
  String get layerPanelAutofillColorUpdateNote =>
      '✳ Bloquea la opacidad y rellena con el color más reciente. Se conserva la forma actual de la capa de relleno automático.';

  @override
  String get layerPanelExecuteButton => 'Ejecutar';

  @override
  String get layerPanelAutofillPartMissingSnackbar =>
      'No hay ninguna parte asignada. Asigna una desde «Asignar parte».';

  @override
  String get layerPanelAutofillPresetMissingSnackbar =>
      'No se encontró una parte correspondiente en el ajuste de relleno automático.';

  @override
  String layerPanelAutofillLayerNameSuffix(String name) {
    return '$name (relleno automático)';
  }

  @override
  String get layerPanelOrphanFillSuccessSnackbar =>
      'No se encontró una capa de líneas correspondiente, así que se rellenó con el color más reciente.';

  @override
  String get layerPanelOrphanFillFailSnackbar =>
      'No se pudo procesar: no hay ninguna parte asignada, o no hay una forma que rellenar.';

  @override
  String get layerPanelAutofillUpdateHelpTitle =>
      'Marca de actualización del relleno automático';

  @override
  String get layerPanelAutofillUpdateHelpBody =>
      'El relleno automático actual no está actualizado. Toca para actualizarlo.';

  @override
  String layerPanelReplaceMaterialSuccessSnackbar(String name) {
    return 'Material reemplazado: $name';
  }

  @override
  String layerPanelImportImageSuccessSnackbar(String name) {
    return 'Imagen importada: $name';
  }

  @override
  String layerPanelCopySuffix(String name) {
    return 'Copia de $name';
  }

  @override
  String get timelineFullscreenPreviewCloseTooltip =>
      'Cerrar la vista previa a pantalla completa';

  @override
  String get timelineDefaultProjectName => 'Nombre del proyecto';

  @override
  String get timelineProjectSaveMenuItem => 'Guardar proyecto';

  @override
  String get timelinePreviewPlaceholder => 'Vista previa';

  @override
  String get timelinePreviewFullscreenTip =>
      'Toca para ver la vista previa a pantalla completa. Útil para comprobar el resultado final.';

  @override
  String get timelinePreviewFullscreenTooltip =>
      'Ver la vista previa a pantalla completa';

  @override
  String get timelineAddImageTooltip => '+ Imagen';

  @override
  String get timelineAddVideoTooltip => '+ Vídeo';

  @override
  String get timelineAddAudioTooltip => '+ Audio';

  @override
  String get timelineEffectFilterLabel => 'Filtros de efecto';

  @override
  String get timelineAddCameraKfTooltip => 'Añadir fotograma clave de cámara';

  @override
  String get timelineAddWatermarkTooltip => '+ Marca de agua';

  @override
  String get timelineWatermarkNotRegisteredTitle =>
      'No hay ninguna marca de agua registrada';

  @override
  String get timelineWatermarkNotRegisteredBody =>
      'Registra primero una imagen o una marca de agua de texto en «Marca de agua» dentro de Ajustes.';

  @override
  String get timelineOpenSettingsButton => 'Abrir ajustes';

  @override
  String get timelineWatermarkSelectTitle => 'Selecciona una marca de agua';

  @override
  String timelineWatermarkAddedSnackbar(String name) {
    return 'Marca de agua añadida (se muestra en todos los fotogramas): $name';
  }

  @override
  String get timelineWatermarkEditTitle => 'Editar marca de agua';

  @override
  String get timelineWatermarkAngleLabel => 'Ángulo';

  @override
  String get timelineWatermarkSizeLabel => 'Tamaño';

  @override
  String get timelineWatermarkOpacityLabel => 'Opacidad';

  @override
  String get timelineWatermarkLoopLabel => 'Mostrar siempre (bucle)';

  @override
  String get timelineWatermarkLoopSubtitle =>
      'Si está desactivado, solo se muestra en la escena actual';

  @override
  String get timelineConfirmButton => 'Confirmar';

  @override
  String get timelineClipSelectDoneButton => 'Listo';

  @override
  String get timelineClipOverlapDialogTitle =>
      'Se superpone con un clip existente';

  @override
  String get timelineClipOverlapDialogBody =>
      'El destino de pegado se superpone con un clip existente. ¿Cómo quieres colocarlo?';

  @override
  String get timelineClipOverlapPlaceBefore => 'Colocar antes';

  @override
  String get timelineClipOverlapPlaceAfter => 'Colocar después';

  @override
  String get timelineClipOverlapPlaceNewRow =>
      'Superponer (añadir una fila nueva)';

  @override
  String get timelineSceneRenameTitle => 'Cambiar nombre de la escena';

  @override
  String get timelineSceneDeleteMenuItem => 'Eliminar escena';

  @override
  String get timelineDurationLimitTitle => 'Se alcanzó el límite de duración';

  @override
  String get timelineDurationLimitBodyFree =>
      'Los miembros gratuitos están limitados a 90 segundos de vídeo. Añadir o duplicar más fotogramas superaría ese límite, por lo que no se puede realizar la acción. Actualiza a Premium para llegar hasta 2 horas.';

  @override
  String get timelineDurationLimitBodyPremium =>
      'Esto superaría el límite Premium (hasta 2 horas), por lo que no se pueden añadir ni duplicar más fotogramas.';

  @override
  String timelineSceneDeleteConfirmTitle(String name) {
    return '¿Eliminar «$name»?';
  }

  @override
  String get timelineSceneDeleteConfirmBody =>
      'Se eliminarán todos los datos de la escena, incluidos cada fotograma, las capas comunes, los materiales de vídeo, los materiales de imagen y las marcas de agua.';

  @override
  String timelineSceneMultiDeleteConfirmTitle(int count) {
    return '¿Eliminar las $count escenas seleccionadas?';
  }

  @override
  String get timelineAutofillUpdateHelpBody =>
      'Esta escena/fotograma contiene una capa de relleno automático que no está actualizada. Toca la capa en el panel de capas para actualizarla.';

  @override
  String get timelineFrameTrackLabel => 'Fotograma';

  @override
  String get timelineTrackRowDeleteBlockedSnackbar =>
      'Esta fila todavía tiene clips y no se puede eliminar. Muévelos o elimínalos primero.';

  @override
  String get timelineTrackRowRenameTitle => 'Renombrar fila';

  @override
  String get timelineCameraTrackLabel => 'Cámara';

  @override
  String get timelineRangeSceneFixed => 'Escena fija';

  @override
  String get timelineEndCardCustomLabel => 'Reemplazado';

  @override
  String get timelineEndCardDefaultLogoLabel => 'Logo de NIARIM';

  @override
  String timelineEndCardStatusFormat(String label, int seconds) {
    return '$label · $seconds s';
  }

  @override
  String get timelineEndCardHiddenLabel => 'Oculto';

  @override
  String get timelineEndCardVisibilityToggleTooltip => 'Mostrar/ocultar';

  @override
  String get timelineEndCardLengthChangeTooltip => 'Cambiar duración';

  @override
  String get timelineEndCardReplaceTooltip => 'Reemplazar';

  @override
  String get timelineEndCardLengthDialogTitle => 'Duración de la tarjeta final';

  @override
  String get timelineEndCardTrackLabel => 'Pista de tarjeta final';

  @override
  String get timelineMarkerTrackLabel => 'Marcas de tiempo';

  @override
  String timelineMarkerAddDialogTitle(int n) {
    return 'Añadir marca de tiempo en F$n';
  }

  @override
  String timelineMarkerEditDialogTitle(int n) {
    return 'Marca de tiempo: F$n';
  }

  @override
  String get timelineMarkerCommentHint =>
      'Comentario (p. ej., boca \"a\" aquí)';

  @override
  String timelineSecondsLabel(int n) {
    return '$n s';
  }

  @override
  String timelineAddClipDialogTitle(String trackName) {
    return 'Añadir clip de $trackName';
  }

  @override
  String get timelineClipLabelFieldLabel => 'Etiqueta';

  @override
  String get timelineClipStartLabel => 'Inicio:';

  @override
  String get timelineClipLengthLabel => 'Duración:';

  @override
  String get timelineSaveSuccessSnackbar => 'Proyecto guardado';

  @override
  String get timelineAutofillNote2 =>
      '✳ Si solo existe una capa de relleno automático (sin dibujo de líneas), el área se determinará desde cero de todos modos.';

  @override
  String get timelineAutofillTargetLabel => 'Objetivo';

  @override
  String get timelineAutofillScopeCurrentFrame => 'Solo el fotograma actual';

  @override
  String get timelineAutofillScopeCurrentScene =>
      'Por escena (todos los fotogramas de la escena actual)';

  @override
  String get timelineAutofillScopeAllScenes =>
      'Todos los fotogramas (todo el proyecto)';

  @override
  String get timelineAutofillProgressTitle => 'Ejecutando relleno automático';

  @override
  String timelineAutofillProgressSubtitle(int count) {
    return '$count fotogramas';
  }

  @override
  String timelineAutofillCompleteSnackbar(int count) {
    return 'Relleno automático completado ($count procesados)';
  }

  @override
  String get timelineEffectTypeFade => 'Desvanecimiento';

  @override
  String get timelineEffectTypeGaussianBlur => 'Desenfoque gaussiano';

  @override
  String get timelineEffectTypeLensBlur => 'Desenfoque de lente';

  @override
  String get timelineEffectTypeMosaic => 'Mosaico';

  @override
  String get timelineEffectTypeChromaticAberration => 'Aberración cromática';

  @override
  String get timelineEffectTypeNoise => 'Ruido';

  @override
  String get timelineEffectTypeSepia => 'Sepia';

  @override
  String get timelineEffectTypeAnimeStyle => 'Estilo anime';

  @override
  String get timelineEffectTypeRetroAnime => 'Anime retro';

  @override
  String get timelineEffectTypeCrt => 'Tubo de rayos catódicos';

  @override
  String get timelineEffectTypeAnimatedNoise => 'Ruido animado';

  @override
  String get timelineEffectTypeRain => 'Lluvia';

  @override
  String get timelineEffectFilterEmptyState =>
      'No hay filtros\nToca + Añadir para crear uno';

  @override
  String get timelineRangeStartLabel => 'Inicio';

  @override
  String get timelineRangeEndLabel => 'Fin';

  @override
  String get timelineEffectSizeLabel => 'Tamaño';

  @override
  String get timelineEffectStrengthLabel => 'Intensidad';

  @override
  String get timelineEffectAmountLabel => 'Cantidad';

  @override
  String get timelineEffectGrainSizeLabel => 'Tamaño del grano';

  @override
  String get timelineEffectRainIntensityLabel => 'Intensidad';

  @override
  String get timelineEffectRainSpeedLabel => 'Velocidad';

  @override
  String get timelineEffectRainSizeLabel => 'Tamaño de gota';

  @override
  String get timelineEffectWindAngleLabel => 'Ángulo del viento';

  @override
  String get timelineColorLabel => 'Color';

  @override
  String get timelineColorBlack => 'Negro';

  @override
  String get timelineColorWhite => 'Blanco';

  @override
  String get timelineColorCustom => 'Personalizado';

  @override
  String get timelineFadeColorDialogTitle => 'Color del desvanecimiento';

  @override
  String get timelineAddFilterDialogTitle => 'Añadir filtro';

  @override
  String get timelineClipVolumeLabel => 'Volumen';

  @override
  String get timelineClipFadeInLabel => 'Entrada gradual';

  @override
  String get timelineClipFadeOutLabel => 'Salida gradual';

  @override
  String get timelineClipUseStartLabel => 'Inicio de uso F';

  @override
  String get timelineClipUseEndLabel => 'Fin de uso F';

  @override
  String timelineCameraKfTitle(int n) {
    return 'Fotograma clave de cámara: F$n';
  }

  @override
  String get timelineCameraMoveXLabel => 'Movimiento X';

  @override
  String get timelineCameraMoveYLabel => 'Movimiento Y';

  @override
  String get timelineCameraZoomLabel => 'Zoom';

  @override
  String get timelineCameraRotationLabel => 'Rotación';

  @override
  String get layerPanelKeyframeLabel => 'Animación (fotogramas clave)';

  @override
  String layerKeyframeSheetTitle(String name) {
    return 'Fotogramas clave de $name';
  }

  @override
  String get layerKeyframeSheetDesc =>
      'Define la posición, escala y rotación de esta capa por fotograma; los fotogramas clave se interpolan automáticamente. El dibujo de la capa en sí no cambia.';

  @override
  String layerKeyframeAddAtCurrentFrame(int n) {
    return 'Añadir en el fotograma actual (F$n)';
  }

  @override
  String get layerKeyframeEmpty =>
      'Aún no hay fotogramas clave. Añade uno con el botón de arriba.';

  @override
  String get layerKeyframeScaleShort => 'Escala';

  @override
  String get layerKeyframeRotationShort => 'Rot.';

  @override
  String layerKeyframeEditTitle(int n) {
    return 'Fotograma clave: F$n';
  }

  @override
  String get layerKeyframeFrameLabel => 'Fotograma';

  @override
  String get layerKeyframeScaleLabel => 'Escala';

  @override
  String get layerKeyframeRotationLabel => 'Rotación';

  @override
  String get layerKeyframeEasingLabel =>
      'Transición al siguiente fotograma clave';

  @override
  String get layerKeyframeEasingLinear => 'Uniforme';

  @override
  String get layerKeyframeEasingEaseIn => 'Entrada suave (empieza lento)';

  @override
  String get layerKeyframeEasingEaseOut => 'Salida suave (termina lento)';

  @override
  String get layerKeyframeEasingEaseInOut => 'Entrada y salida suaves';

  @override
  String get layerKeyframeEasingBounceOut => 'Rebote';

  @override
  String get layerPanelGroupTooltip => 'Agrupar';

  @override
  String get layerPanelShowSelectedTooltip =>
      'Mostrar todas las capas seleccionadas';

  @override
  String get layerPanelHideSelectedTooltip =>
      'Ocultar todas las capas seleccionadas';

  @override
  String get layerPanelGroupDefaultName => 'Nuevo grupo';

  @override
  String layerPanelGroupMembershipLabel(String name) {
    return 'Grupo: $name';
  }

  @override
  String get layerPanelGroupLeaveAction => 'Salir';

  @override
  String frameStripHoldDialogTitle(int n) {
    return 'F$n fotogramas de espera';
  }

  @override
  String get frameStripTimelineModeTooltip => 'Modo línea de tiempo';

  @override
  String get frameStripFrameListModeLabel => 'Fotogramas';

  @override
  String get frameStripTimelineModeLabel => 'Línea de tiempo';

  @override
  String get progressDialogAdLoading => 'Cargando anuncio…';

  @override
  String get adMockPlaceholderLabel =>
      'Banner publicitario (maqueta de prueba de ubicación)';

  @override
  String get progressDialogTipLabel => 'Consejo';

  @override
  String get premiumBannerRegisterButton => 'Pasar a Premium';

  @override
  String get licenseTermsArt1Title => 'Artículo 1 (Aplicación)';

  @override
  String get licenseTermsArt1Body =>
      'Estos Términos de Servicio (los «Términos») establecen las condiciones de uso de la aplicación «NIARIM» (la «Aplicación»). El usuario deberá aceptar estos Términos antes de utilizar la Aplicación. El uso de la Aplicación implica la aceptación de estos Términos.';

  @override
  String get licenseTermsArt2Title =>
      'Artículo 2 (Requisitos de uso / entorno compatible)';

  @override
  String get licenseTermsArt2Body =>
      '1. Para más información sobre las versiones de sistema operativo compatibles y el entorno operativo recomendado de la Aplicación, consulte la tienda de distribución correspondiente y la información mostrada dentro de la Aplicación.\n2. Procuramos que la Aplicación funcione de forma fluida en dispositivos de muy diversas prestaciones; no obstante, según el rendimiento del dispositivo, la versión del sistema operativo, el espacio de almacenamiento disponible, la configuración y otras condiciones de uso, algunas funciones pueden verse limitadas o no funcionar correctamente.';

  @override
  String get licenseTermsArt3Title => 'Artículo 3 (Actos prohibidos)';

  @override
  String get licenseTermsArt3Body =>
      'Al utilizar la Aplicación, el usuario no podrá:\n・Realizar actos contrarios a la ley o al orden público\n・Vulnerar los derechos de autor, marcas u otros derechos de propiedad intelectual, el derecho a la propia imagen, la privacidad u otros derechos o intereses de la Aplicación, del desarrollador o de terceros\n・Descompilar, desensamblar, aplicar ingeniería inversa o realizar cualquier otro análisis de la Aplicación (salvo en los casos permitidos por la ley)\n・Modificar, duplicar o redistribuir la Aplicación sin autorización\n・Acceder sin autorización a la Aplicación o a la infraestructura que la sustenta, imponerle una carga excesiva o interferir de cualquier otro modo en su funcionamiento normal\n・Realizar cualquier otro acto que el desarrollador considere razonablemente inapropiado';

  @override
  String get licenseTermsArt4Title =>
      'Artículo 4 (Derechos sobre el contenido creado)';

  @override
  String get licenseTermsArt4Body =>
      '1. Los derechos de autor y demás derechos relativos a las ilustraciones, animaciones y demás contenidos que el usuario cree mediante la Aplicación (incluidos los datos de proyecto, las imágenes y vídeos exportados, etc.; en adelante, el «Contenido creado») corresponden, en la medida permitida por la ley, al usuario o al tercero titular de los derechos sobre dicho contenido.\n2. La Aplicación no ofrece ninguna función para transmitir, recopilar o sincronizar el Contenido creado con los servidores del desarrollador. Los datos de proyecto se almacenan, en principio, únicamente en el dispositivo del usuario (en cuanto al tratamiento aplicable cuando el usuario, por decisión propia, publica Contenido creado mediante la función de la Plaza de Obras, véase el artículo 12).\n3. Con independencia de si el Contenido creado se elaboró con la versión gratuita o con la versión premium, el desarrollador no restringirá su uso comercial en función de la tarifa de uso de la Aplicación o de la edición utilizada (las diferencias entre la versión gratuita y la premium se limitan a aspectos funcionales como la visualización de la tarjeta final o el límite de duración de exportación).\n4. No obstante lo dispuesto en el párrafo anterior, las fuentes, imágenes, materiales y demás elementos que el usuario añada a la Aplicación y sobre los que terceros posean derechos quedarán sujetos a sus respectivas condiciones de uso (artículo 5).';

  @override
  String get licenseTermsArt5Title =>
      'Artículo 5 (Fuentes incluidas y materiales añadidos)';

  @override
  String get licenseTermsArt5Body =>
      '1. Las fuentes y demás materiales incluidos en la Aplicación se utilizan conforme a las condiciones de licencia indicadas en esta pantalla, en «Acerca de las fuentes utilizadas».\n2. En cuanto a los derechos relativos a las fuentes, imágenes, tonos, sellos y demás materiales que el propio usuario registre o cargue en la Aplicación, este será responsable de obtener los derechos o permisos necesarios y de utilizarlos de forma lícita.\n3. Si surgiera una disputa con un tercero derivada del uso por parte del usuario de materiales de terceros, el desarrollador no asumirá responsabilidad alguna al respecto, salvo en los casos en que la ley así lo exija.';

  @override
  String get licenseTermsArt6Title =>
      'Artículo 6 (Funciones premium / facturación)';

  @override
  String get licenseTermsArt6Body =>
      '1. Además de las funciones disponibles de forma gratuita, la Aplicación ofrece funciones premium que pueden utilizarse mediante compras dentro de la aplicación (un plan mensual, un plan anual u otros planes premium).\n2. El precio, el contenido, el método de compra y demás condiciones de las funciones premium serán los que se muestren dentro de la Aplicación o en la tienda de distribución en el momento de la compra.\n3. Las cancelaciones, reembolsos y demás cuestiones relativas al pago posteriores a la compra se rigen por las normas de Google Play o de la plataforma de pago que utilice. No obstante, cuando la ley disponga lo contrario, se aplicará dicha disposición.\n4. El desarrollador podrá modificar el contenido de las funciones premium por motivos razonables, como cambios legislativos, necesidades técnicas o mejoras de la Aplicación. Cuando se realice un cambio significativo, se lo notificará con antelación, en la medida de lo razonablemente posible, dentro de la Aplicación o por otro medio adecuado.';

  @override
  String get licenseTermsArt7Title => 'Artículo 7 (Publicidad)';

  @override
  String get licenseTermsArt7Body =>
      '1. En la versión gratuita, pueden mostrarse anuncios a través de servicios publicitarios de terceros.\n2. La obtención, el uso y demás tratamientos de la información por parte de los proveedores de publicidad se rigen por la política de privacidad de cada proveedor correspondiente.';

  @override
  String get licenseTermsArt8Title =>
      'Artículo 8 (Tratamiento de la información)';

  @override
  String get licenseTermsArt8Body =>
      '1. La Aplicación no ofrece ninguna función para transmitir o recopilar en los servidores del desarrollador las ilustraciones, animaciones y demás contenidos, ni los datos de proyecto, creados por el usuario. Estos se almacenan, en principio, únicamente en el dispositivo del usuario, y dado que el desarrollador no dispone de ninguna función para almacenar estos contenidos por su cuenta, no existe el concepto de un plazo de conservación por parte del desarrollador.\n2. El tratamiento de la información del usuario —incluida la información recopilada por los servicios de terceros integrados en la Aplicación (como la publicidad y las compras dentro de la aplicación)— se rige por la Política de Privacidad establecida por separado.\n3. Si desinstala la Aplicación, se eliminarán los datos almacenados en su dispositivo (proyectos, ajustes, fuentes añadidas, etc.).';

  @override
  String get licenseTermsArt9Title =>
      'Artículo 9 (Suspensión, modificación y finalización del servicio)';

  @override
  String get licenseTermsArt9Body =>
      '1. El desarrollador podrá suspender temporalmente la prestación total o parcial de la Aplicación al realizar tareas de mantenimiento, actualización o corrección, en caso de fallos en la infraestructura de prestación del servicio o por otras circunstancias inevitables.\n2. El desarrollador podrá modificar el contenido de la Aplicación o poner fin a su prestación cuando lo considere necesario.\n3. En los casos previstos en los dos párrafos anteriores, el desarrollador lo comunicará con antelación, en la medida de lo posible, dentro de la Aplicación o por otros medios adecuados, salvo en casos urgentes.\n4. Salvo que la ley exija lo contrario, el desarrollador no asumirá responsabilidad alguna por los daños que el usuario sufra como consecuencia de las modificaciones, suspensiones o finalizaciones previstas en este artículo.';

  @override
  String get licenseTermsArt10Title =>
      'Artículo 10 (Exención de responsabilidad)';

  @override
  String get licenseTermsArt10Body =>
      '1. El desarrollador no garantiza que la Aplicación esté libre de defectos de hecho o de derecho (incluidos aspectos de seguridad, fiabilidad, exactitud, integridad, idoneidad para un fin concreto, o ausencia de errores o fallos).\n2. El usuario utilizará la Aplicación bajo su propia responsabilidad. Los datos pueden perderse debido a averías del dispositivo, errores de manejo, actualizaciones del sistema operativo u otras circunstancias, por lo que se recomienda realizar copias de seguridad periódicas del trabajo en curso mediante las funciones de exportación y de compartir, entre otras.\n3. En la medida permitida por la ley, el desarrollador no asumirá responsabilidad alguna por los daños que el usuario sufra como consecuencia del uso de la Aplicación. Esta limitación no se aplicará, sin embargo, en caso de dolo o negligencia grave por parte del desarrollador; incluso en ese caso, la responsabilidad del desarrollador por daños y perjuicios se limitará a los daños directos habituales, hasta el importe efectivamente abonado por el usuario en relación con la Aplicación durante el año anterior (0 yenes si se utilizó de forma gratuita).';

  @override
  String get licenseTermsArt11Title =>
      'Artículo 11 (Modificación de estos Términos)';

  @override
  String get licenseTermsArt11Body =>
      '1. El desarrollador podrá modificar estos Términos en caso de cambios en la legislación aplicable, cambios en el contenido de la Aplicación u otras circunstancias que considere necesarias.\n2. Al modificar estos Términos, el desarrollador comunicará con antelación el contenido de la modificación y su fecha de entrada en vigor, dentro de la Aplicación o por otros medios adecuados.\n3. Los Términos modificados se aplicarán, en la medida permitida por la ley, a partir de la fecha de entrada en vigor mencionada en el párrafo anterior.';

  @override
  String get licenseTermsArt12Title =>
      'Artículo 12 (Plaza de Obras: función de publicación comunitaria)';

  @override
  String get licenseTermsArt12Body =>
      '1. La Aplicación ofrece de forma opcional una función que permite al usuario publicar, a través de su propia cuenta de Google, las animaciones que ha creado en YouTube, y publicarlas y consultarlas en la «Plaza de Obras» (en adelante, la «Función Comunitaria»). Es posible ver y crear obras sin utilizar la Función Comunitaria.\n2. El archivo de vídeo en sí se almacena en YouTube, no en los servidores del desarrollador. En cambio, la información necesaria para identificar y mostrar las obras publicadas (ID del vídeo de YouTube, título, estadísticas, información de denuncias, etc.), así como el ID de usuario de NIARIM emitido para el uso de las funciones de publicación, denuncia y bloqueo (un identificador emitido dentro de la Aplicación, distinto de la cuenta de Google), se gestionan en los servidores del desarrollador.\n3. Para publicar obras, denunciar y bloquear a otros usuarios dentro de la Función Comunitaria es necesario haber iniciado sesión con una cuenta de Google.\n4. Existe un límite diario en el número de obras que se pueden publicar (el límite difiere entre los miembros gratuitos y los miembros premium). Dicho límite puede modificarse por razones operativas.\n5. Si un usuario considera que una obra publicada por otro usuario infringe la ley o el orden público, o puede estar comprendida en alguno de los supuestos del artículo 3, puede denunciarla al desarrollador a través de la función de denuncia de la Aplicación. Tras revisar el contenido de la denuncia, el desarrollador podrá adoptar, por razones justificadas, las medidas necesarias, como ocultar dicha obra de los listados. Quedan prohibidas las denuncias falsas y el uso abusivo de la función de denuncia.\n6. Si el usuario elimina una publicación, o desvincula su cuenta de Google de la Aplicación, el vídeo de YouTube correspondiente podrá eliminarse. Asimismo, si el vídeo se hace privado o se elimina en YouTube, la obra dejará también de mostrarse en la Plaza de Obras.\n7. El uso de la Función Comunitaria está sujeto, además de a estos Términos, a las Condiciones del Servicio y las Normas de la Comunidad de YouTube.\n8. Los usuarios pueden seguir a otros usuarios y marcar o republicar obras de otros usuarios. Tus listas de seguidos y seguidores y la lista de obras que has marcado son privadas de forma predeterminada; hacerlas públicas es una elección tuya dentro de la Aplicación. Tu número de seguidos y de seguidores se muestra con independencia de ese ajuste.\n9. Las etiquetas asociadas a una obra pueden ser añadidas o eliminadas por usuarios distintos del autor. El autor puede bloquear las etiquetas de su propia obra para impedir su edición por otros usuarios. Los usuarios no deben añadir etiquetas que difamen a terceros, etiquetas ajenas al contenido de la obra ni etiquetas inapropiadas de cualquier otro tipo. El desarrollador podrá eliminar las etiquetas inapropiadas.\n10. El desarrollador muestra notificaciones en la lista de notificaciones de la Aplicación, por ejemplo cuando alguien te sigue. Si has permitido las notificaciones en tu dispositivo, podrán enviarse notificaciones push. Las notificaciones pueden desactivarse desde los ajustes de la Aplicación o desde los ajustes de tu dispositivo.\n11. Los usuarios no deben utilizar la Función Comunitaria para acosar a otros usuarios, para publicidad o captación, ni para ningún otro fin ajeno a su finalidad prevista (publicar y ver obras). Si utilizas la función de bloqueo, las obras del usuario bloqueado dejarán de aparecer en tus listados.';

  @override
  String get licenseTermsArt13Title =>
      'Artículo 13 (Ley aplicable / jurisdicción)';

  @override
  String get licenseTermsArt13Body =>
      '1. Estos Términos se regirán e interpretarán conforme a las leyes de Japón.\n2. En caso de que surja una disputa relacionada con la Aplicación, el tribunal de distrito o el tribunal sumario que tenga jurisdicción sobre el lugar de establecimiento del desarrollador, según la cuantía del litigio, tendrá jurisdicción exclusiva convenida como tribunal de primera instancia.';

  @override
  String get privacyPolicyArt1Title =>
      'Artículo 1 (Finalidad de esta Política)';

  @override
  String get privacyPolicyArt1Body =>
      'Esta política de privacidad (la «Política») describe el tratamiento de la información en la aplicación «NIARIM» (la «Aplicación»). Para conocer las condiciones generales de uso de la Aplicación, consulte por separado la pantalla «Términos de servicio / Licencia».';

  @override
  String get privacyPolicyArt2Title =>
      'Artículo 2 (Datos que la Aplicación no recopila)';

  @override
  String get privacyPolicyArt2Body =>
      'La Aplicación no ofrece ninguna función para transmitir, recopilar o almacenar en los servidores del desarrollador las ilustraciones, animaciones y demás contenidos creados por el usuario (incluidos los datos de proyecto, las imágenes y vídeos exportados, etc.; en lo sucesivo, lo mismo). Estos datos se almacenan, en principio, únicamente en el dispositivo del usuario (la Aplicación no incorpora una función de sincronización en la nube). Dado que el desarrollador no dispone de ninguna función para almacenar estos contenidos por su cuenta, no existe el concepto de un plazo de conservación por parte del desarrollador. Los datos almacenados en su dispositivo pueden eliminarse en cualquier momento mediante las funciones de eliminación de la Aplicación y, si desinstala la Aplicación, también se eliminarán los datos almacenados en su dispositivo, incluidos proyectos, ajustes y fuentes añadidas (en cuanto al tratamiento de la información cuando el usuario, por decisión propia, publica una obra mediante la función de la Plaza de Obras, véase el artículo 7).';

  @override
  String get privacyPolicyArt3Title =>
      'Artículo 3 (Información recopilada por servicios de terceros)';

  @override
  String get privacyPolicyArt3Body =>
      'La Aplicación incorpora los siguientes servicios de terceros, y cada proveedor de servicios puede recopilar información en la medida necesaria para prestar su respectivo servicio. El desarrollador de la Aplicación no ha implementado ninguna función para obtener o almacenar esta información por su cuenta (el tratamiento de la información recopilada por cada servicio se rige por la política de privacidad de ese proveedor).\n\n[Publicidad (Google AdMob)]\nEn la versión gratuita, los anuncios se distribuyen a través de Google AdMob. Con fines de distribución de anuncios, medición de eficacia y prevención de fraudes, Google o sus empresas afiliadas pueden recopilar y utilizar el identificador de publicidad y otra información del dispositivo. Para más detalles sobre la recopilación y el uso de esta información, consulte la Política de Privacidad de Google (https://policies.google.com/privacy). Puede restablecer su identificador de publicidad o desactivar los anuncios personalizados desde la configuración de su dispositivo (por ejemplo, «Privacidad» en la aplicación Ajustes de Android). Si se encuentra en el Espacio Económico Europeo (EEE), el Reino Unido o Suiza, podrá elegir sus preferencias de consentimiento para la personalización de anuncios mediante un formulario de consentimiento que se muestra al iniciar la aplicación, y podrá modificar esta elección en cualquier momento mediante el botón «Cambiar la configuración de consentimiento de anuncios» en la parte inferior de esta pantalla.\n\n[Compras dentro de la aplicación (Google Play Billing)]\nLas compras de funciones premium se realizan a través del sistema de pago de Google Play. El desarrollador no obtiene ni conserva directamente información de pago como números de tarjeta de crédito. El tratamiento de la información relacionada con los pagos se rige por las normas de Google Play.\n\n[Descarga de fuentes adicionales (GitHub)]\nLa comunicación con GitHub (GitHub, Inc.), distribuidor de los archivos de fuentes, solo se produce cuando eliges descargar una fuente adicional desde «Gestión de fuentes» en la pantalla de ajustes. No se produce al iniciar la aplicación ni durante el uso normal. Solo se envía la información necesaria para la solicitud (como tu dirección IP y qué archivo de fuente se solicita); no se envían datos de tus obras ni información que te identifique. El tratamiento de la información obtenida se rige por la Declaración de privacidad de GitHub (https://docs.github.com/site-policy/privacy-policies/github-privacy-statement).\n\n[Análisis de fallos / análisis de uso]\nLa Aplicación no incorpora actualmente ningún SDK con fines de análisis de fallos o de uso. Si en el futuro se introdujeran estos servicios, esta Política se actualizará y se anunciará dentro de la Aplicación.';

  @override
  String get privacyPolicyArt4Title =>
      'Artículo 4 (Cookies y otras tecnologías de seguimiento)';

  @override
  String get privacyPolicyArt4Body =>
      'La propia Aplicación no utiliza cookies, pero el servicio de publicidad mencionado en el artículo 3 (Google AdMob) puede utilizar tecnologías de identificación similares (como el identificador de publicidad) con fines de distribución de anuncios y medición de eficacia.';

  @override
  String get privacyPolicyArt5Title =>
      'Artículo 5 (Información personal de menores)';

  @override
  String get privacyPolicyArt5Body =>
      'La Aplicación no está diseñada para recopilar intencionadamente información dirigida principalmente a menores de 13 años. Se recomienda a los padres y tutores que, cuando sea necesario, consideren desactivar los anuncios personalizados desde la configuración del dispositivo cuando sus hijos utilicen la Aplicación.';

  @override
  String get privacyPolicyArt6Title =>
      'Artículo 6 (Transferencia internacional de información)';

  @override
  String get privacyPolicyArt6Body =>
      'Los servicios de terceros mencionados en el artículo 3 (Google AdMob, Google Play Billing) pueden procesar datos en servidores que Google opera en distintas partes del mundo. El tratamiento de estos datos se rige por la política de privacidad de cada servicio correspondiente.';

  @override
  String get privacyPolicyArt7Title =>
      'Artículo 7 (Tratamiento de la información en la Plaza de Obras: función de publicación comunitaria)';

  @override
  String get privacyPolicyArt7Body =>
      '1. Únicamente cuando un usuario decide, por su propia voluntad, utilizar la función «la Plaza de Obras» (artículo 12 de los Términos de Servicio), el desarrollador gestiona la siguiente información en sus servidores:\n・Información necesaria para identificar y mostrar una obra publicada (ID del vídeo de YouTube, título, estadísticas, fecha y hora de publicación, etiquetas, etc.)\n・El NIARIM User ID emitido para el uso de funciones como publicar, denunciar, bloquear, seguir y marcar (un identificador emitido dentro de la Aplicación, distinto de la cuenta de Google)\n・Información pública del canal de YouTube vinculado (nombre del canal y URL de la imagen del icono del canal). Se copia y conserva en los servidores del desarrollador para mostrar el nombre y el icono del autor\n・El contenido de cualquier denuncia enviada mediante la función de denuncia y el NIARIM User ID del denunciante\n・El NIARIM User ID de cualquier usuario que bloquees\n・El NIARIM User ID de cualquier usuario que sigas, así como tu número de seguidos y de seguidores\n・Los ID de las obras que marcas y la fecha y hora de cada marcador\n・Los ID de las obras que republicas y la fecha y hora de cada republicación\n・Las etiquetas asociadas a una obra (véase el apartado 4)\n・Si activas las notificaciones push, el token de tu dispositivo (un identificador emitido por tu dispositivo para determinar el destino de la notificación; se utiliza únicamente para enviar notificaciones)\n2. El archivo de vídeo en sí se almacena en YouTube, no en los servidores del desarrollador.\n3. La información descrita en los dos apartados anteriores se utiliza únicamente para prestar la Función Comunitaria (mostrar listados, clasificaciones y resultados de búsqueda, atender denuncias, gestionar los límites de publicación, reflejar seguimientos, marcadores y republicaciones, enviar notificaciones, etc.). El desarrollador no facilita esta información a terceros con fines publicitarios.\n4. Las etiquetas pueden ser añadidas o eliminadas por usuarios distintos del autor (el autor puede bloquear las etiquetas de su propia obra para impedir su edición). Las etiquetas son públicas en la Plaza de Obras y no se muestra qué usuario añadió cada una.\n5. La siguiente información es privada de forma predeterminada y solo se muestra a otros usuarios si la cambias a pública dentro de la Aplicación:\n・La lista de obras que has marcado\n・Tus listas de seguidos y seguidores\nEl número de seguidos y de seguidores (las cifras en sí) se muestra siempre, con independencia de este ajuste.\n6. Si haces privada o eliminas una obra publicada, esa obra dejará de aparecer en los listados y clasificaciones de la Plaza de Obras. Si deseas que se eliminen los registros de los servidores del desarrollador, ponte en contacto con nosotros por la vía descrita en el artículo 9.\n7. Si un usuario no utiliza la Función Comunitaria, no se produce ningún tratamiento de información conforme a este artículo. (Conforme al principio del artículo 2, no se transmite nada a los servidores del desarrollador.)';

  @override
  String get privacyPolicyArt8Title =>
      'Artículo 8 (Modificaciones de esta Política)';

  @override
  String get privacyPolicyArt8Body =>
      'El desarrollador podrá modificar esta Política en caso de cambios en la legislación aplicable, cambios en el contenido de la Aplicación u otras circunstancias que considere necesarias. Al modificar esta Política, el desarrollador comunicará con antelación el contenido de la modificación y su fecha de entrada en vigor, dentro de la Aplicación o por otros medios adecuados.';

  @override
  String get privacyPolicyArt9Title => 'Artículo 9 (Contacto)';

  @override
  String get privacyPolicyArt9Body =>
      'Si tiene alguna consulta sobre esta Política, póngase en contacto con nosotros a través de los siguientes datos.\n(Contacto del desarrollador: aún no definido; complete una dirección de correo electrónico u otros datos de contacto antes de la publicación).';

  @override
  String get privacyPolicyAdConsentButton =>
      'Cambiar la configuración de consentimiento de anuncios';

  @override
  String get tipsPcDexLayoutTitle =>
      'En pantallas anchas, cambia automáticamente al modo PC (DeX)';

  @override
  String get tipsPcDexLayoutDesc =>
      'En un Chromebook, una tablet con teclado, Samsung DeX o cualquier entorno de pantalla ancha, la app cambia automáticamente a un diseño profesional con paneles acoplados. También puedes forzar Siempre modo PC o Siempre modo móvil desde los ajustes de espacio de trabajo, útil al conectar una pantalla externa.';

  @override
  String get workspaceTimelineSection => 'Visualización de la línea de tiempo';

  @override
  String get workspaceTimelineHint =>
      'Ajusta la altura de cada fila de pista de vídeo/audio en 5 niveles. También puedes usar el pellizco (pinch) para ampliar o reducir temporalmente el ancho de los fotogramas en la línea de tiempo.';

  @override
  String get workspaceTimelineTrackHeightLabel => 'Altura de la pista';

  @override
  String get workspaceTimelinePreviewLabel => 'Vista previa';

  @override
  String get workspaceEndCardSection => 'Tarjeta final';

  @override
  String get workspaceEndCardHint =>
      'La tarjeta final es el logotipo propio de la app que aparece automáticamente al final de cada vídeo. Los miembros gratuitos no pueden cambiar esto. Solo para miembros premium: al activarlo, la tarjeta final aparecerá oculta (eliminada) desde el principio la próxima vez que abras la línea de tiempo. Este ajuste vuelve a desactivarse automáticamente si tu suscripción premium caduca.';

  @override
  String get workspaceEndCardDefaultHiddenTitle =>
      'Ocultar la tarjeta final de forma predeterminada (solo Premium)';

  @override
  String get tipsTransparentColorTitle =>
      'El color transparente no es solo una goma, usalo como un color de pincel mas';

  @override
  String get tipsTransparentColorDesc =>
      'Al seleccionar transparente puedes borrar con cualquier herramienta: pincel, lazo, formas, lo que prefieras. Aprovecha la presion y el suavizado del pincel para redondear bordes con precision, o usa un pincel degradado para difuminar un borde suavemente hacia la transparencia, efectos sutiles que la goma sola no puede lograr.';

  @override
  String get tipsQuickToolVariantTitle =>
      'La herramienta rapida admite variantes de pincel o tamano, no solo herramientas distintas';

  @override
  String get tipsQuickToolVariantDesc =>
      'La ranura de herramienta rapida no se limita a alternar entre herramientas como lapiz y goma: puedes registrar el mismo lapiz con un pincel distinto, o la misma goma con otro tamano, como entradas separadas. Seleccionando solo las combinaciones que realmente usas a menudo, evitas volver constantemente al panel de ajustes.';

  @override
  String get tipsCommonLayerLipSyncTitle =>
      'Las capas comunes tambien reducen el tamano de los personajes, no solo de los fondos';

  @override
  String get tipsCommonLayerLipSyncDesc =>
      'No solo los fondos: convertir la propia capa del personaje en una capa comun tambien funciona bien. Manten como capas normales solo las partes que cambian de fotograma a fotograma, como la boca o los ojos al parpadear, y convierte el resto (cuerpo, pelo) en una capa comun. Esto puede reducir drasticamente el tamano incluso en animaciones de sincronizacion labial o parpadeo.';

  @override
  String get tipsCommonLayerKeyframeTitle =>
      'Capas comunes mas fotogramas clave de capa tambien ahorran espacio';

  @override
  String get tipsCommonLayerKeyframeDesc =>
      'Las capas comunes se pueden mover, escalar y rotar con fotogramas clave de capa. En lugar de redibujar cada fotograma, convierte un unico dibujo en una capa comun y animalo con fotogramas clave: obtienes movimiento simple sin aumentar el tamano del archivo.';

  @override
  String get tipsTransferCustomizationTitle =>
      'La transferencia conserva tu configuracion personalizada en cualquier dispositivo';

  @override
  String get tipsTransferCustomizationDesc =>
      'La funcion de transferencia (.niatra) traslada tus ajustes personalizados —pinceles, tema, disposicion de la barra de herramientas, paletas y mas— todo junto a otro dispositivo. Cambia de dispositivo o trabaja en varios sin tener que configurarlo todo desde cero cada vez.';

  @override
  String get tipsBlendModeUsageTitle =>
      'Elige el modo de fusion segun lo que busques';

  @override
  String get tipsBlendModeUsageDesc =>
      'Usa Multiplicar para sombras, Trama o Sumar para luz y brillo, y Superponer o Luz suave cuando quieras un sombreado con algo de textura. El mismo color puede verse completamente distinto segun el modo de fusion, asi que merece la pena probar varias opciones y compararlas.';

  @override
  String get timelineSaveFailedDialogTitle => 'Error al guardar';

  @override
  String get timelineSaveFailedDialogBody =>
      'No se pudo guardar. Por favor, inténtalo de nuevo.';

  @override
  String get licenseSectionIcons => 'Acerca de los iconos utilizados';

  @override
  String get layerPanelMergeAllVisibleTooltip =>
      'Combinar todas las capas visibles';

  @override
  String get canvasBrushSliderToggleLabel => 'Detalles';

  @override
  String get helpMeshTransformTitle =>
      'Transformación libre / Deformación de malla';

  @override
  String get helpMeshTransformDesc =>
      'Una herramienta de transformación para toda la capa, que se abre desde el menú de edición/ajustes en la esquina superior derecha del lienzo. A diferencia de transformar una selección, no hace falta seleccionar nada: arrastra las esquinas o puntos individuales de la cuadrícula con el dedo para un resultado libre. El control deslizante de densidad del panel puede subdividir la malla hasta 10×10, y pellizcar dos puntos distintos con dos dedos a la vez ofrece una forma intuitiva de rotar o escalar.';

  @override
  String get layerPanelBrightnessToAlphaLabel => 'Transparencia por brillo';

  @override
  String get layerPanelBrightnessToAlphaHint =>
      'Hace que las zonas más claras sean más transparentes. Los colores se mantienen, pero se vuelven translúcidos (toda la imagen se aclara, en lugar de que el fondo blanco simplemente desaparezca).';

  @override
  String get layerPanelBrightnessToAlphaColorButton => 'Color';

  @override
  String get layerPanelBrightnessToAlphaGrayButton => 'Gris';

  @override
  String get tipsRoughLayerRescueTitle =>
      '¿Dibujaste el lineart sobre tu boceto? Rescátalo con \"Transparencia por brillo\"';

  @override
  String get tipsRoughLayerRescueDesc =>
      'Aunque hayas dibujado el lineart por accidente encima de la capa de boceto, puedes recuperar solo el lineart sin borrar nada. 1) Añade una nueva capa y pon su modo de fusión en Dividir. 2) Toma el color del boceto con el cuentagotas y rellena toda esa capa Dividir con él (esto desvanece el boceto). 3) Duplica la capa Dividir y el boceto desaparece por completo. 4) Usa \"Combinar todas las capas visibles\" en el panel de capas para aplanar todo en una sola capa. 5) Desde el menú de tres puntos de esa capa combinada, elige \"Transparencia por brillo (Gris)\": las zonas blancas se vuelven transparentes y solo queda el lineart.';

  @override
  String get filterNameMonochrome => 'Filtro monocromo';

  @override
  String get timelineEffectTypeMonochrome => 'Filtro monocromo';

  @override
  String get filterNameColorAdjust => 'Ajuste de color';

  @override
  String get filterColorAdjustSaturationLabel => 'Saturación';

  @override
  String get filterColorAdjustBrightnessLabel => 'Brillo';

  @override
  String get filterColorAdjustContrastLabel => 'Contraste';

  @override
  String get canvasColorAdjustTitle => 'Ajuste de color';

  @override
  String get canvasColorAdjustAddToDrawFilter => 'Añadir a filtros de dibujo';

  @override
  String get canvasColorAdjustAddToEffectFilter => 'Añadir a filtros de efecto';

  @override
  String get canvasColorAdjustMenuTitle => 'Ajuste de color';

  @override
  String get canvasEditMenuReferenceWindow => 'Ventana de referencia';

  @override
  String get canvasEditMenuReferenceWindowSubtitle =>
      'Muestra una imagen de referencia flotante';

  @override
  String get referenceWindowTitle => 'Ventana de referencia';

  @override
  String get referenceWindowSelectImageButton => 'Elegir imagen';

  @override
  String get workspaceDockPanelSection => 'Paneles abiertos por defecto (PC)';

  @override
  String get workspaceDockPanelHint =>
      'En modo PC/DeX, los paneles marcados pueden anclarse y mostrarse todos a la vez (el móvil siempre empieza con todos ocultos para evitar toques accidentales).';

  @override
  String get workspaceDockPanelBrush => 'Pincel';

  @override
  String get workspaceDockPanelColorPicker => 'Selector de color';

  @override
  String get workspaceDockPanelLayer => 'Capas';

  @override
  String get workspaceDockPanelTone => 'Tono';

  @override
  String get workspaceDockPanelStamp => 'Sello';

  @override
  String get workspaceDockPanelPenSubTool => 'Subherramienta de lápiz';

  @override
  String get workspaceDockPanelOnionSkin => 'Papel cebolla';

  @override
  String get workspaceDockPanelRuler => 'Regla';

  @override
  String get workspaceDockPanelFilter => 'Filtro';

  @override
  String get workspaceDockPanelQuickTool => 'Herramienta rápida';

  @override
  String get workspaceDockPanelColorAdjust => 'Ajuste de color';

  @override
  String get workspaceDockPanelCanvasPreview => 'Vista previa del lienzo';

  @override
  String get workspacePcLayoutButton => 'Ajustes de diseño para PC';

  @override
  String get pcWorkspaceLayoutScreenTitle => 'Ajustes de diseño para PC';

  @override
  String get pcWorkspaceLayoutIntroHint =>
      'Ajusta el orden y el ancho de los paneles cuando la pantalla de lienzo se abre en modo PC (horizontal + ratón/tableta gráfica conectados).';

  @override
  String get pcWorkspaceLayoutToolOrderSection =>
      'Orden de los paneles de herramientas';

  @override
  String get pcWorkspaceLayoutToolOrderHint =>
      'El orden de apilado usado cuando hay varios paneles abiertos a la vez (pincel, tono, sello, etc.).';

  @override
  String get pcWorkspaceLayoutRightOrderSection =>
      'Orden del panel de capas, etc.';

  @override
  String get pcWorkspaceLayoutRightOrderHint =>
      'El orden de apilado del selector de color, el panel de capas y la vista previa del lienzo.';

  @override
  String get pcWorkspaceLayoutWidthSection => 'Ancho de los paneles';

  @override
  String get pcWorkspaceLayoutToolWidthLabel =>
      'Ancho del lado del panel de herramientas';

  @override
  String get pcWorkspaceLayoutRightWidthLabel =>
      'Ancho del lado del panel de capas';

  @override
  String get pcWorkspaceLayoutResetWidthButton =>
      'Restablecer ancho predeterminado';

  @override
  String get pcWorkspaceLayoutResetOrderButton =>
      'Restablecer orden predeterminado';

  @override
  String get canvasPreviewNavigatorTitle => 'Vista previa del lienzo';

  @override
  String get canvasEditMenuPreviewNavigator => 'Vista previa del lienzo';

  @override
  String get canvasEditMenuPreviewNavigatorSubtitle =>
      'Muestra una vista general reducida (navegador)';

  @override
  String get filterCustomMenuDuplicate => 'Duplicar';

  @override
  String get filterCustomMenuFavoriteBlockTitle => 'No se puede eliminar';

  @override
  String get filterCustomMenuFavoriteBlockBody =>
      'Este filtro está marcado como favorito y no se puede eliminar. Quita el favorito primero y luego elimínalo.';

  @override
  String get filterNameThreshold => 'Filtro de umbral';

  @override
  String get filterMonochromeStrength => 'Intensidad del monocromo';

  @override
  String get filterMonochromeColorLabel => 'Color del monocromo';

  @override
  String get filterThresholdLabel => 'Umbral';

  @override
  String get filterNameFisheye => 'Filtro de ojo de pez';

  @override
  String get filterFisheyeStrength => 'Intensidad de curvatura';

  @override
  String get filterNameChromaticAberration => 'Filtro de aberración cromática';

  @override
  String get filterChromaticAberrationStrength =>
      'Intensidad del desplazamiento';

  @override
  String get filterNameLensDistortion => 'Filtro de distorsión de lente';

  @override
  String get filterLensDistortionStrength =>
      'Potencia de la lente (negativo = cóncava, positivo = convexa)';

  @override
  String get filterLensDistortionOffsetX =>
      'Ajuste fino del centro (horizontal)';

  @override
  String get filterNamePixelate => 'Filtro de pixelado';

  @override
  String get filterNameAuroraHologram => 'Holograma Aurora';

  @override
  String get filterAuroraHologramStrength => 'Intensidad';

  @override
  String get filterAuroraHologramBrightness => 'Brillo';

  @override
  String get filterAuroraHologramSaturation => 'Saturación';

  @override
  String get filterAuroraHologramPresetAurora => 'Aurora';

  @override
  String get filterAuroraHologramPresetSoapBubble => 'Pompa de jabón';

  @override
  String get filterAuroraHologramPresetCyberNeon => 'Neón cibernético';

  @override
  String get filterAuroraHologramPresetPastelDream => 'Sueño pastel';

  @override
  String get filterAuroraHologramPresetSunsetGold => 'Oro del atardecer';

  @override
  String get filterAuroraHologramPresetSilverFoil => 'Papel plateado';

  @override
  String get filterNameBackgroundBlend => 'Mimetismo de fondo';

  @override
  String get filterBackgroundBlendColorLabel => 'Color de mimetismo';

  @override
  String get filterBackgroundBlendAutoLabel =>
      'Detección automática (toca para ajustar)';

  @override
  String get filterBackgroundBlendAutoReset => 'Volver a automático';

  @override
  String get filterBackgroundBlendDirection =>
      'Dirección de sombra/luz (vinculada)';

  @override
  String get filterBackgroundBlendLength =>
      'Longitud de sombra/luz (vinculada)';

  @override
  String get filterBackgroundBlendBlur => 'Intensidad de desenfoque';

  @override
  String get filterPixelateBlockSize => 'Tamaño de bloque';

  @override
  String get filterLensDistortionOffsetY => 'Ajuste fino del centro (vertical)';

  @override
  String get filterLensDistortionNoMaskHint =>
      'Solo se aplica a las áreas pintadas en una capa de selección. Primero añada una «Capa de selección» en la lista de capas y pinte el área que desea convertir en lente (por ejemplo, los cristales de unas gafas).';

  @override
  String get tipsStockingDenierTitle =>
      'Las medias y pantis varían en finura de malla según el denier';

  @override
  String get tipsStockingDenierDesc =>
      'Las nuevas tramas de medias/pantis en la lista tienen una malla más apretada cuanto menor es el denier (tela más fina); la más baja, 10 denier, es deliberadamente tan fina que puede producir muaré según la resolución de pantalla o exportación. Los pantis de mayor denier usan un espaciado más amplio para un aspecto más opaco, así que elige el que combine con las piernas del personaje.';

  @override
  String get tipsFisheyeChromaticTitle =>
      'Usa los filtros de ojo de pez y aberración cromática para una distorsión y franjas tipo lente';

  @override
  String get tipsFisheyeChromaticDesc =>
      'El filtro de ojo de pez abomba el centro del encuadre y comprime los bordes, recreando la curvatura de una toma con lente gran angular o de ojo de pez. El filtro de aberración cromática desplaza ligeramente los canales RGB para recrear las franjas de color de una lente barata. Ambos están disponibles como filtros de dibujo (aplicados directamente a una capa) y como filtros de efecto (aplicados a un rango en la línea de tiempo).';

  @override
  String get tipsLensDistortionTitle =>
      'Recrea la distorsión de lentes graduados con una capa de selección y el filtro de distorsión de lente';

  @override
  String get tipsLensDistortionDesc =>
      'Añada una «Capa de selección» a la lista de capas y pinte el área de las lentes de unas gafas con cualquier herramienta de dibujo normal; el filtro de distorsión de lente aplicará entonces su deformación local solo a esa área pintada. El control de potencia reduce el área en dirección cóncava (miopía) con valores negativos y la amplía en dirección convexa (hipermetropía) con valores positivos, y también puede ajustar la posición del centro. Puede pintar ambas lentes a la vez y aplicar el efecto a las dos juntas. La capa de selección en sí nunca aparece en las exportaciones ni en la obra final. También resulta útil para recrear el aspecto de un paisaje visto a través del objetivo de una cámara: pinte una zona amplia, como el fondo, con una capa de selección y aplique una potencia suave.';

  @override
  String get tipsLineArtExtractionTitle =>
      'Extrae el dibujo lineal combinando ajuste de color, umbral y transparencia por brillo';

  @override
  String get tipsLineArtExtractionDesc =>
      'Aumenta el contraste con el ajuste de color para que las líneas destaquen, y luego usa el filtro de umbral para dividir la imagen en blanco y negro puros: las líneas se separan claramente del resto. El control deslizante de umbral te permite ajustar el grosor de la línea y lo tenue o marcada que se ve. Por último, usa \"Transparencia por brillo (gris)\" desde el menú de tres puntos de la capa para volver transparentes las zonas blancas (todo excepto las líneas), dejando solo el dibujo lineal. Útil para extraer un dibujo lineal limpio a partir de una foto o un boceto.';

  @override
  String get tipsLineColorUsageTitle =>
      'Elige el modo de color de línea según el uso para un mejor acabado';

  @override
  String get tipsLineColorUsageDesc =>
      'Para el contorno de una parte, Trazado de color / Fusión de línea mantiene el borde legible sin que flote sobre el dibujo. Para sombras y luces, igualar el color de línea al de relleno hace que la línea desaparezca. Y un color especificado deliberadamente distinto puede darle a una serie su propio estilo.';

  @override
  String get tipsBlushAutofillTitle =>
      'Hasta el rubor suave se puede rellenar automáticamente';

  @override
  String get tipsBlushAutofillDesc =>
      'Pon el color de línea en un color especificado transparente, y el relleno en un degradado Radial (centro→exterior) con el rosa del rubor y transparente como sus dos colores: así se coloca solo el rubor de las mejillas suavemente sobre la piel. Ajusta la opacidad del rubor y la posición del punto de color para que se integre aún mejor.';

  @override
  String get autofillPartResetTraceButton => 'Restablecer';

  @override
  String get premiumScreenTitle => 'Premium';

  @override
  String get premiumComparisonPremium => 'Premium';

  @override
  String premiumRegisteredDateLabel(String date) {
    return 'Registrado: $date';
  }

  @override
  String premiumNextRenewalDateLabel(String date) {
    return 'Próxima renovación: $date';
  }

  @override
  String get workspaceApplyCurrentButton =>
      'Aplicar espacio de trabajo configurado';

  @override
  String get workspaceAppliedSnackbar =>
      'Se aplicaron los ajustes del espacio de trabajo.';

  @override
  String get workspaceSaveAsButton =>
      'Guardar espacio de trabajo con nombre / Sobrescribir';

  @override
  String get workspaceShareButton => 'Compartir espacio de trabajo';

  @override
  String get workspaceShareSelectTitle =>
      'Selecciona un espacio de trabajo para compartir';

  @override
  String workspaceShareFailedSnackbar(String error) {
    return 'Error al compartir: $error';
  }

  @override
  String get workspaceImportFromFileButton => 'Importar desde archivo';

  @override
  String workspaceImportFailedSnackbar(String error) {
    return 'Error al importar: $error';
  }

  @override
  String get workspaceNameRequiredError => 'Introduce un nombre.';

  @override
  String get workspaceNoSavedPresets =>
      'Todavía no hay espacios de trabajo guardados.';

  @override
  String get workspaceOverwriteSelectTitle =>
      'Selecciona un espacio de trabajo para sobrescribir';

  @override
  String get workspaceOverwriteConfirmTitle => 'Confirmar sobrescritura';

  @override
  String workspaceOverwriteConfirmBody(String name) {
    return 'Esto sobrescribirá \"$name\" con los ajustes actuales. Se perderá su contenido anterior. ¿Continuar?';
  }

  @override
  String get workspaceOverwriteButton => 'Sobrescribir';

  @override
  String get splashCommunityButtonTitle => 'Plaza de Obras';

  @override
  String get splashCommunityButtonSubtitle => 'Ver las obras de todos';

  @override
  String get splashCreateButton => 'Crear una animación';

  @override
  String get communityScreenTitle => 'Plaza de Obras';

  @override
  String get communityTabNew => 'Novedades';

  @override
  String get communityTabRanking => 'Ranking';

  @override
  String get communityTabFavoriteAuthors => 'Siguiendo';

  @override
  String get communitySearchHint => 'Buscar por título o nombre de usuario';

  @override
  String get communityEmptyState => 'No hay obras para mostrar';

  @override
  String communitySearchNoResults(String query) {
    return 'No se encontraron obras que coincidan con «$query»';
  }

  @override
  String get communityTagSearchHint => 'Buscar por etiqueta';

  @override
  String get communityTagSearchModeOnTooltip =>
      'Búsqueda por etiqueta: ACTIVADA (toca para volver a buscar por título/usuario)';

  @override
  String get communityTagSearchModeOffTooltip =>
      'Cambiar a búsqueda por etiqueta';

  @override
  String get communityAddTagButton => 'Añadir etiqueta';

  @override
  String get communityAddTagDialogTitle => 'Añadir etiqueta';

  @override
  String get communityAddTagDialogHint => 'Introduce un nombre de etiqueta';

  @override
  String get communityTagLockTooltip =>
      'Bloquear esta etiqueta (solo el autor)';

  @override
  String get communityTagUnlockTooltip =>
      'Desbloquear esta etiqueta (solo el autor)';

  @override
  String get communityRemoveTagTooltip => 'Eliminar esta etiqueta';

  @override
  String get communityPostButton => 'Publicar';

  @override
  String get communityPostComingSoonTitle =>
      'La publicación estará disponible próximamente';

  @override
  String get communityPostComingSoonBody =>
      'La función de publicación de vídeos todavía está en desarrollo. Estate atento a futuras actualizaciones.';

  @override
  String get communityPostInfoTitle =>
      'La publicación se realiza a través de YouTube';

  @override
  String get communityPostInfoBody =>
      'Al publicar en la Plaza de Obras, tu obra se publica a través de YouTube. NIARIM no transmite, recopila ni almacena el propio archivo de vídeo en los servidores del desarrollador: publicar significa subir el vídeo desde la propia pantalla de YouTube.\n\nSi configuras el vídeo como \"No listado\" en YouTube, no aparecerá en los listados públicos de YouTube y solo se publicará dentro de la Plaza de Obras.\n\n(La función de publicación de vídeos todavía está en desarrollo. Estate atento a futuras actualizaciones.)';

  @override
  String get communityRankingPeriodAllTime => 'Total';

  @override
  String get communityRankingPeriodYearly => 'Anual';

  @override
  String get communityRankingPeriodMonthly => 'Mensual';

  @override
  String get communityRankingPeriodWeekly => 'Semanal';

  @override
  String get communityRankingPeriodDaily => 'Diario';

  @override
  String get communityRankingSortViews => 'Reproducciones';

  @override
  String get communityRankingSortBookmarks => 'Marcadores';

  @override
  String get communityRankingSortAscendingTooltip =>
      'Ascendente (menor primero)';

  @override
  String get communityRankingSortDescendingTooltip =>
      'Descendente (mayor primero)';

  @override
  String communityWorkDetailPostedLabel(String date) {
    return 'Publicado el $date';
  }

  @override
  String get communityWorkDetailViewOnYoutube => 'Ver en YouTube';

  @override
  String get communityWorkDetailViewOnYoutubeComingSoonSnackbar =>
      'La integración con YouTube estará disponible próximamente';

  @override
  String get communityWorkDetailBookmarkAdd => 'Marcar';

  @override
  String get communityWorkDetailBookmarkRemove => 'Marcado';

  @override
  String get communityWorkDetailReportButton => 'Denunciar';

  @override
  String get communityWorkDetailBlockButton => 'Bloquear';

  @override
  String get communityVisibilityCardTitle => 'Visibilidad en la Plaza de Obras';

  @override
  String get communityVisibilityPublishedDesc =>
      'Visible: aparece en Novedades, Rankings y la lista de obras de este autor.';

  @override
  String get communityVisibilityHiddenDesc =>
      'Oculto: se elimina de Novedades, Rankings y la lista de obras de este autor (es un ajuste independiente de la visibilidad en YouTube).';

  @override
  String get communityVisibilityHiddenNotice =>
      'El autor ha ocultado esta obra en la Plaza de Obras.';

  @override
  String get communityVisibilityHiddenBadge => 'Oculto';

  @override
  String get communityWorkDetailTitle => 'Detalles de la obra';

  @override
  String get communityWorkNotFoundMessage => 'No se pudo encontrar esta obra';

  @override
  String get communityFloatingPreviewDetailButton => 'Detalles';

  @override
  String get communityFloatingPreviewPlayTooltip => 'Reproducir';

  @override
  String get communityFloatingPreviewPauseTooltip => 'Pausar';

  @override
  String get communityReportDialogTitle => 'Denunciar esta obra';

  @override
  String get communityReportDialogBody =>
      'Selecciona un motivo para la denuncia.';

  @override
  String get communityReportReasonInappropriate => 'Contenido inapropiado';

  @override
  String get communityReportReasonCopyright =>
      'Posible infracción de derechos de autor';

  @override
  String get communityReportReasonSpam => 'Spam o publicaciones repetidas';

  @override
  String get communityReportReasonOther => 'Otro';

  @override
  String get communityReportSubmitButton => 'Enviar denuncia';

  @override
  String get communityReportDetailLabel => 'Detalles';

  @override
  String get communityReportDetailHint =>
      'Describe específicamente cuál es el problema';

  @override
  String get communityReportDetailRequiredError => 'Introduce los detalles';

  @override
  String get communityReportComingSoonSnackbar =>
      'La función de denuncia estará disponible próximamente. No se ha enviado nada.';

  @override
  String communityBlockConfirmTitle(String name) {
    return '¿Bloquear a «$name»?';
  }

  @override
  String get communityBlockConfirmBody =>
      'Al bloquear, las obras de este creador dejarán de aparecer en tus listas.';

  @override
  String get communityBlockComingSoonSnackbar =>
      'La función de bloqueo estará disponible próximamente. No se ha aplicado nada.';

  @override
  String communityAuthorWorksCount(int count) {
    return '$count obras';
  }

  @override
  String communityAuthorFollowerCount(int count) {
    return '$count seguidores';
  }

  @override
  String get communityFollowersPublicToggleTitle =>
      'Hacer públicas las listas de seguidos/seguidores';

  @override
  String get communityFollowersPublicToggleDesc =>
      'Si está activado, otros usuarios podrán ver sus listas de seguidos y seguidores desde esta página. Son privadas de forma predeterminada.';

  @override
  String get communityFollowersListTitle => 'Seguidores';

  @override
  String get communityFollowersListEmpty => 'Todavía no hay seguidores';

  @override
  String communityFollowersListHiddenNote(int count) {
    return '$count más no se muestran, ocultos por su propia configuración de privacidad';
  }

  @override
  String communityAuthorFollowingCount(int count) {
    return 'Siguiendo a $count';
  }

  @override
  String get communityFollowingListTitle => 'Siguiendo';

  @override
  String get communityFollowingListEmpty => 'Todavía no sigue a nadie';

  @override
  String get communityFollowNotificationsTooltip => 'Notificaciones';

  @override
  String get communityFollowNotificationsTitle =>
      'Notificaciones de seguidores';

  @override
  String get communityFollowNotificationsEmpty => 'No hay notificaciones';

  @override
  String communityFollowNotificationBody(String name) {
    return '$name te ha seguido';
  }

  @override
  String get communityNoWorksMessage => 'No hay obras';

  @override
  String get communityFavoriteAuthorFollow => 'Seguir';

  @override
  String get communityFavoriteAuthorFollowing => 'Siguiendo';

  @override
  String get communityFavoriteAuthorsEmptyTitle =>
      'Aún no sigues a ningún autor';

  @override
  String get communityFavoriteAuthorsEmptyBody =>
      'Sigue a un creador desde su página para ver aquí sus últimas obras.';

  @override
  String get communityRepostButton => 'Republicar';

  @override
  String get communityRepostedButton => 'Republicado';

  @override
  String communityRepostedByBadge(String name) {
    return 'Republicado por $name';
  }

  @override
  String get communityAuthorTabWorks => 'Obras';

  @override
  String get communityAuthorTabBookmarks => 'Marcadores';

  @override
  String get communityBookmarksPublicToggleTitle =>
      'Hacer pública la lista de marcadores';

  @override
  String get communityBookmarksPublicToggleDesc =>
      'Si está activado, otros usuarios podrán ver su lista de marcadores desde esta página. Es privada de forma predeterminada.';

  @override
  String get communityBookmarksPrivateNotice =>
      'Este usuario ha configurado su lista de marcadores como privada.';

  @override
  String get communityBookmarksEmptyMessage => 'No hay obras marcadas';

  @override
  String get communityShortsBadge => 'Vertical';

  @override
  String get communityVideoTypeFilterTooltip => 'Filtrar por tipo de vídeo';

  @override
  String get communityVideoTypeFilterAll => 'Todos';

  @override
  String get communityVideoTypeFilterShortOnly => 'Solo vertical';

  @override
  String get communityVideoTypeFilterLongOnly => 'Solo horizontal';

  @override
  String get communityShortsModeTooltip => 'Ver en modo vertical';

  @override
  String get communityShortsModeEmptySnackbar =>
      'No hay vídeos verticales disponibles';

  @override
  String get communityShortsModeExitTooltip => 'Salir del modo vertical';

  @override
  String get pixelColorModeLabel => 'Modo de color';

  @override
  String get pixelColorModeNone => 'No limitar colores';

  @override
  String get pixelColorModePalette => 'Elegir de una paleta';

  @override
  String get pixelColorModeExplicit => 'Especificar colores';

  @override
  String get pixelColorModeCount => 'Especificar número de colores';

  @override
  String pixelColorLevelsLabel(int count) {
    return 'Colores: $count';
  }

  @override
  String get pixelColorChipDeleteTooltip => 'Eliminar este color';

  @override
  String get pixelColorChipAddButton => 'Añadir color';

  @override
  String get pixelArtPaletteNameRequiredError =>
      'Introduce un nombre de paleta';

  @override
  String get pixelArtPaletteEditTitle => 'Editar paleta';

  @override
  String get pixelArtPaletteAddTitle => 'Añadir paleta';

  @override
  String get pixelArtPaletteNameLabel => 'Nombre de la paleta';

  @override
  String get pixelArtPalettePickerTitle => 'Elegir paleta';

  @override
  String get pixelArtPalettePickerEmpty =>
      'Aún no hay paletas guardadas. Toca «Añadir» para crear una.';

  @override
  String get pixelArtPalettePickerApplyButton => 'Aplicar';

  @override
  String get storageScreenTitle => 'Liberar espacio';

  @override
  String get storageDeviceChartTitle => 'Almacenamiento del dispositivo';

  @override
  String get storageBreakdownChartTitle => 'Desglose de NIARIM';

  @override
  String get storageActionsTitle => 'Organizar';

  @override
  String get storageCategoryNiarimTotal => 'NIARIM';

  @override
  String get storageCategoryOtherApps => 'Otros';

  @override
  String get storageCategoryFree => 'Espacio libre';

  @override
  String get storageCategoryMaterials => 'Materiales';

  @override
  String get storageCategoryProjectData => 'Datos del proyecto';

  @override
  String get storageCategoryExports => 'Archivos exportados';

  @override
  String get storageCategoryCustomAssets =>
      'Pinceles/tonos/sellos/fuentes personalizados';

  @override
  String get storageCategoryCache => 'Caché';

  @override
  String get storageCategoryTrash => 'Papelera';

  @override
  String get storageClearCacheButton => 'Borrar caché';

  @override
  String get storageRemoveUnusedMaterialsButton =>
      'Eliminar materiales sin usar (todos los proyectos)';

  @override
  String get storageEmptyTrashButton => 'Vaciar papelera';

  @override
  String get storageOrganizeProjectsButton => 'Organizar proyectos';

  @override
  String get storageEraseAllButton => 'Borrar todos los datos (restablecer)';

  @override
  String storageClearCacheDoneSnackbar(String size) {
    return 'Se liberaron $size de caché';
  }

  @override
  String get storageEraseAllConfirmTitle => '¿Borrar todos los datos?';

  @override
  String get storageEraseAllConfirmBody =>
      'Esto elimina permanentemente todos los datos de NIARIM: proyectos, materiales, archivos exportados, pinceles/tonos/sellos/fuentes personalizados y ajustes. No se puede deshacer. Reinicia la app después.';

  @override
  String get storageEraseAllDoneSnackbar =>
      'Se borraron todos los datos. Reinicia la app.';

  @override
  String get homeDrawerStorage => 'Liberar espacio';

  @override
  String get helpStorageTitle => 'Liberar espacio';

  @override
  String get helpStorageDesc =>
      'Consulta cuánto espacio usa NIARIM en tu dispositivo y un desglose de su contenido interno (proyectos, materiales, archivos exportados, pinceles/tonos/sellos/fuentes personalizados, caché y papelera) en gráficos circulares. Puedes borrar la caché, eliminar materiales sin usar en todos los proyectos, vaciar la papelera, organizar proyectos o borrar todos los datos (restablecer).';

  @override
  String get colorPickerImportPaletteTooltip => 'Importar paleta';

  @override
  String get colorPickerSharePaletteTooltip => 'Compartir';

  @override
  String get colorPickerShareViaFile => 'Compartir como archivo';

  @override
  String colorPickerShareFailedSnackbar(String error) {
    return 'Error al compartir: $error';
  }

  @override
  String get colorPickerShareViaQr => 'Compartir como código QR';

  @override
  String get qrShareTooLargeHint =>
      'Demasiados colores para compartir como código QR (usa el archivo compartido)';

  @override
  String get colorPickerImportViaFile => 'Elegir un archivo';

  @override
  String colorPickerImportFailedSnackbar(String error) {
    return 'Error al importar: $error';
  }

  @override
  String get colorPickerImportViaQr => 'Pegar texto de código QR';

  @override
  String get qrImportFailedError =>
      'No se pudo importar. Comprueba que el texto sea correcto.';

  @override
  String get qrImportHint =>
      'Escanea el código QR mostrado en el otro dispositivo con una app de cámara estándar y pega aquí el texto copiado.';

  @override
  String get qrImportFieldHint => 'Pega el texto escaneado';

  @override
  String get qrImportPasteButton => 'Pegar desde el portapapeles';

  @override
  String get qrImportSubmitButton => 'Importar';

  @override
  String get qrShareHint =>
      'Escanea este código QR con una app de cámara estándar para copiar el texto. En el otro dispositivo, usa «Importar» para pegar el texto copiado.';

  @override
  String get qrShareCopiedSnackbar => 'Texto copiado';

  @override
  String get qrShareCopyButton => 'Copiar texto';

  @override
  String get toolbarItemBlur => 'Desenfoque gaussiano';

  @override
  String get toolbarItemMosaic => 'Mosaico';

  @override
  String get toolbarFingerSubtoolWarp => 'Deformar';

  @override
  String get brushSettingsEdgeJitterTitle => 'Sangrado de borde';

  @override
  String get brushSettingsEdgeJitterSubtitle =>
      'Rugosidad leve en el borde para imitar el sangrado de tinta';

  @override
  String get brushSettingsEdgeJitterStrengthLabel => 'Intensidad';
}
