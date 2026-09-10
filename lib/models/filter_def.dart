import 'pixel_color_mode.dart';

enum FilterKind {
  gaussianBlur,
  lensBlur,
  animeStyle,
  outline,
  toneCurve,
  levels,
  sharpen,
  unsharpMask,
  vignette,
  noise,
  retroAnime,
  crt,
  monochrome,
  colorAdjust,
  threshold,
  fisheye,
  chromaticAberration,
  lensDistortion,
  pixelate,
  auroraHologram,
  backgroundBlend,
  inkPool,
  autoLineart,
  prism,
}

enum ToneCurvePreset { linear, brighten, darken, highContrast, lowContrast, invert }

enum AuroraHologramPreset { aurora, soapBubble, cyberNeon, pastelDream, sunsetGold, silverFoil }

/// Serializable drawing-filter definition.
class FilterDef {
  final String id;
  final String name;
  final FilterKind kind;
  final bool isFavorite;
  final double strength;
  final int colorLevels;
  final double edgeStrength;
  final int inputBlack;
  final int inputWhite;
  final int outputBlack;
  final int outputWhite;
  final ToneCurvePreset toneCurvePreset;
  final int outlineColor;
  final double outlineWidth;
  final int vignetteColor;
  final double caSaturation;
  final double caBrightness;
  final double caContrast;
  final int monochromeColor;
  final double thresholdValue;
  final double lensCenterOffsetX;
  final double lensCenterOffsetY;
  final PixelColorMode pixelColorMode;
  final List<int> pixelExplicitColors;
  final double hologramBrightness;
  final double hologramSaturation;
  final AuroraHologramPreset hologramPreset;
  final int bgBlendColor;
  final double bgBlendDirection;
  final double bgBlendLength;
  final double bgBlendBlur;
  final bool bgBlendAutoLight;
  final double bgBlendStrength;
  final double bgBlendLightStrength;
  final double bgBlendShadowStrength;
  final double bgBlendAmbientStrength;
  final double bgBlendReflectionStrength;
  final double bgBlendColorBleed;
  final double bgBlendSoftness;
  final double bgBlendSecondaryStrength;
  final double bgBlendMaterialProtection;
  final double bgBlendSamplingBand;
  final int bgBlendLightColor;
  final int bgBlendAmbientColor;
  final int bgBlendShadowColor;
  final int bgBlendReflectionColor;
  final bool bgBlendShowAnalysis;
  final int inkPoolColor;
  final double inkPoolRange;
  final double inkPoolCenterWidth;
  final double autoLineartRoughWidth;
  final double autoLineartOutputWidth;
  final double autoLineartTaperLength;
  final double autoLineartSmoothing;
  final int autoLineartColor;
  final double prismBlurPx;
  final double prismDirectionDegrees;

  const FilterDef({required this.id, required this.name, required this.kind, this.isFavorite=false, this.strength=8, this.colorLevels=6, this.edgeStrength=.4, this.inputBlack=0, this.inputWhite=255, this.outputBlack=0, this.outputWhite=255, this.toneCurvePreset=ToneCurvePreset.linear, this.outlineColor=0xFF000000, this.outlineWidth=6, this.vignetteColor=0xFF000000, this.caSaturation=0, this.caBrightness=0, this.caContrast=0, this.monochromeColor=0xFFFFFFFF, this.thresholdValue=128, this.lensCenterOffsetX=0, this.lensCenterOffsetY=0, this.pixelColorMode=PixelColorMode.count, this.pixelExplicitColors=const [0xFF000000], this.hologramBrightness=0, this.hologramSaturation=0, this.hologramPreset=AuroraHologramPreset.aurora, this.bgBlendColor=-1, this.bgBlendDirection=315, this.bgBlendLength=20, this.bgBlendBlur=6, this.bgBlendAutoLight=true, this.bgBlendStrength=70, this.bgBlendLightStrength=65, this.bgBlendShadowStrength=45, this.bgBlendAmbientStrength=18, this.bgBlendReflectionStrength=22, this.bgBlendColorBleed=35, this.bgBlendSoftness=55, this.bgBlendSecondaryStrength=35, this.bgBlendMaterialProtection=75, this.bgBlendSamplingBand=28, this.bgBlendLightColor=-1, this.bgBlendAmbientColor=-1, this.bgBlendShadowColor=-1, this.bgBlendReflectionColor=-1, this.bgBlendShowAnalysis=true, this.inkPoolColor=0xFF000000, this.inkPoolRange=12, this.inkPoolCenterWidth=6, this.autoLineartRoughWidth=12, this.autoLineartOutputWidth=2, this.autoLineartTaperLength=8, this.autoLineartSmoothing=5, this.autoLineartColor=0xFF000000, this.prismBlurPx=17, this.prismDirectionDegrees=90});

  FilterDef copyWith({String? id,String? name,FilterKind? kind,bool? isFavorite,double? strength,int? colorLevels,double? edgeStrength,int? inputBlack,int? inputWhite,int? outputBlack,int? outputWhite,ToneCurvePreset? toneCurvePreset,int? outlineColor,double? outlineWidth,int? vignetteColor,double? caSaturation,double? caBrightness,double? caContrast,int? monochromeColor,double? thresholdValue,double? lensCenterOffsetX,double? lensCenterOffsetY,PixelColorMode? pixelColorMode,List<int>? pixelExplicitColors,double? hologramBrightness,double? hologramSaturation,AuroraHologramPreset? hologramPreset,int? bgBlendColor,double? bgBlendDirection,double? bgBlendLength,double? bgBlendBlur,bool? bgBlendAutoLight,double? bgBlendStrength,double? bgBlendLightStrength,double? bgBlendShadowStrength,double? bgBlendAmbientStrength,double? bgBlendReflectionStrength,double? bgBlendColorBleed,double? bgBlendSoftness,double? bgBlendSecondaryStrength,double? bgBlendMaterialProtection,double? bgBlendSamplingBand,int? bgBlendLightColor,int? bgBlendAmbientColor,int? bgBlendShadowColor,int? bgBlendReflectionColor,bool? bgBlendShowAnalysis,int? inkPoolColor,double? inkPoolRange,double? inkPoolCenterWidth,double? autoLineartRoughWidth,double? autoLineartOutputWidth,double? autoLineartTaperLength,double? autoLineartSmoothing,int? autoLineartColor,double? prismBlurPx,double? prismDirectionDegrees}) => FilterDef(id:id??this.id,name:name??this.name,kind:kind??this.kind,isFavorite:isFavorite??this.isFavorite,strength:strength??this.strength,colorLevels:colorLevels??this.colorLevels,edgeStrength:edgeStrength??this.edgeStrength,inputBlack:inputBlack??this.inputBlack,inputWhite:inputWhite??this.inputWhite,outputBlack:outputBlack??this.outputBlack,outputWhite:outputWhite??this.outputWhite,toneCurvePreset:toneCurvePreset??this.toneCurvePreset,outlineColor:outlineColor??this.outlineColor,outlineWidth:outlineWidth??this.outlineWidth,vignetteColor:vignetteColor??this.vignetteColor,caSaturation:caSaturation??this.caSaturation,caBrightness:caBrightness??this.caBrightness,caContrast:caContrast??this.caContrast,monochromeColor:monochromeColor??this.monochromeColor,thresholdValue:thresholdValue??this.thresholdValue,lensCenterOffsetX:lensCenterOffsetX??this.lensCenterOffsetX,lensCenterOffsetY:lensCenterOffsetY??this.lensCenterOffsetY,pixelColorMode:pixelColorMode??this.pixelColorMode,pixelExplicitColors:pixelExplicitColors??this.pixelExplicitColors,hologramBrightness:hologramBrightness??this.hologramBrightness,hologramSaturation:hologramSaturation??this.hologramSaturation,hologramPreset:hologramPreset??this.hologramPreset,bgBlendColor:bgBlendColor??this.bgBlendColor,bgBlendDirection:bgBlendDirection??this.bgBlendDirection,bgBlendLength:bgBlendLength??this.bgBlendLength,bgBlendBlur:bgBlendBlur??this.bgBlendBlur,bgBlendAutoLight:bgBlendAutoLight??this.bgBlendAutoLight,bgBlendStrength:bgBlendStrength??this.bgBlendStrength,bgBlendLightStrength:bgBlendLightStrength??this.bgBlendLightStrength,bgBlendShadowStrength:bgBlendShadowStrength??this.bgBlendShadowStrength,bgBlendAmbientStrength:bgBlendAmbientStrength??this.bgBlendAmbientStrength,bgBlendReflectionStrength:bgBlendReflectionStrength??this.bgBlendReflectionStrength,bgBlendColorBleed:bgBlendColorBleed??this.bgBlendColorBleed,bgBlendSoftness:bgBlendSoftness??this.bgBlendSoftness,bgBlendSecondaryStrength:bgBlendSecondaryStrength??this.bgBlendSecondaryStrength,bgBlendMaterialProtection:bgBlendMaterialProtection??this.bgBlendMaterialProtection,bgBlendSamplingBand:bgBlendSamplingBand??this.bgBlendSamplingBand,bgBlendLightColor:bgBlendLightColor??this.bgBlendLightColor,bgBlendAmbientColor:bgBlendAmbientColor??this.bgBlendAmbientColor,bgBlendShadowColor:bgBlendShadowColor??this.bgBlendShadowColor,bgBlendReflectionColor:bgBlendReflectionColor??this.bgBlendReflectionColor,bgBlendShowAnalysis:bgBlendShowAnalysis??this.bgBlendShowAnalysis,inkPoolColor:inkPoolColor??this.inkPoolColor,inkPoolRange:inkPoolRange??this.inkPoolRange,inkPoolCenterWidth:inkPoolCenterWidth??this.inkPoolCenterWidth,autoLineartRoughWidth:autoLineartRoughWidth??this.autoLineartRoughWidth,autoLineartOutputWidth:autoLineartOutputWidth??this.autoLineartOutputWidth,autoLineartTaperLength:autoLineartTaperLength??this.autoLineartTaperLength,autoLineartSmoothing:autoLineartSmoothing??this.autoLineartSmoothing,autoLineartColor:autoLineartColor??this.autoLineartColor,prismBlurPx:prismBlurPx??this.prismBlurPx,prismDirectionDegrees:prismDirectionDegrees??this.prismDirectionDegrees);

  Map<String,dynamic> toJson()=>{'id':id,'name':name,'kind':kind.name,'isFavorite':isFavorite,'strength':strength,'colorLevels':colorLevels,'edgeStrength':edgeStrength,'inputBlack':inputBlack,'inputWhite':inputWhite,'outputBlack':outputBlack,'outputWhite':outputWhite,'toneCurvePreset':toneCurvePreset.name,'outlineColor':outlineColor,'outlineWidth':outlineWidth,'vignetteColor':vignetteColor,'caSaturation':caSaturation,'caBrightness':caBrightness,'caContrast':caContrast,'monochromeColor':monochromeColor,'thresholdValue':thresholdValue,'lensCenterOffsetX':lensCenterOffsetX,'lensCenterOffsetY':lensCenterOffsetY,'pixelColorMode':pixelColorMode.name,'pixelExplicitColors':pixelExplicitColors,'hologramBrightness':hologramBrightness,'hologramSaturation':hologramSaturation,'hologramPreset':hologramPreset.name,'bgBlendColor':bgBlendColor,'bgBlendDirection':bgBlendDirection,'bgBlendLength':bgBlendLength,'bgBlendBlur':bgBlendBlur,'bgBlendAutoLight':bgBlendAutoLight,'bgBlendStrength':bgBlendStrength,'bgBlendLightStrength':bgBlendLightStrength,'bgBlendShadowStrength':bgBlendShadowStrength,'bgBlendAmbientStrength':bgBlendAmbientStrength,'bgBlendReflectionStrength':bgBlendReflectionStrength,'bgBlendColorBleed':bgBlendColorBleed,'bgBlendSoftness':bgBlendSoftness,'bgBlendSecondaryStrength':bgBlendSecondaryStrength,'bgBlendMaterialProtection':bgBlendMaterialProtection,'bgBlendSamplingBand':bgBlendSamplingBand,'bgBlendLightColor':bgBlendLightColor,'bgBlendAmbientColor':bgBlendAmbientColor,'bgBlendShadowColor':bgBlendShadowColor,'bgBlendReflectionColor':bgBlendReflectionColor,'bgBlendShowAnalysis':bgBlendShowAnalysis,'inkPoolColor':inkPoolColor,'inkPoolRange':inkPoolRange,'inkPoolCenterWidth':inkPoolCenterWidth,'autoLineartRoughWidth':autoLineartRoughWidth,'autoLineartOutputWidth':autoLineartOutputWidth,'autoLineartTaperLength':autoLineartTaperLength,'autoLineartSmoothing':autoLineartSmoothing,'autoLineartColor':autoLineartColor,'prismBlurPx':prismBlurPx,'prismDirectionDegrees':prismDirectionDegrees};

  factory FilterDef.fromJson(Map<String,dynamic> j)=>FilterDef(id:j['id'] as String,name:j['name'] as String,kind:FilterKind.values.firstWhere((e)=>e.name==j['kind'],orElse:()=>FilterKind.gaussianBlur),isFavorite:j['isFavorite'] as bool? ?? false,strength:(j['strength'] as num?)?.toDouble()??8,colorLevels:j['colorLevels'] as int? ??6,edgeStrength:(j['edgeStrength'] as num?)?.toDouble()??.4,inputBlack:j['inputBlack'] as int? ??0,inputWhite:j['inputWhite'] as int? ??255,outputBlack:j['outputBlack'] as int? ??0,outputWhite:j['outputWhite'] as int? ??255,toneCurvePreset:ToneCurvePreset.values.firstWhere((e)=>e.name==j['toneCurvePreset'],orElse:()=>ToneCurvePreset.linear),outlineColor:j['outlineColor'] as int? ??0xFF000000,outlineWidth:(j['outlineWidth'] as num?)?.toDouble()??6,vignetteColor:j['vignetteColor'] as int? ??0xFF000000,caSaturation:(j['caSaturation'] as num?)?.toDouble()??0,caBrightness:(j['caBrightness'] as num?)?.toDouble()??0,caContrast:(j['caContrast'] as num?)?.toDouble()??0,monochromeColor:j['monochromeColor'] as int? ??0xFFFFFFFF,thresholdValue:(j['thresholdValue'] as num?)?.toDouble()??128,lensCenterOffsetX:(j['lensCenterOffsetX'] as num?)?.toDouble()??0,lensCenterOffsetY:(j['lensCenterOffsetY'] as num?)?.toDouble()??0,pixelColorMode:PixelColorMode.values.firstWhere((e)=>e.name==j['pixelColorMode'],orElse:()=>PixelColorMode.count),pixelExplicitColors:(j['pixelExplicitColors'] as List<dynamic>?)?.map((e)=>e as int).toList()??const [0xFF000000],hologramBrightness:(j['hologramBrightness'] as num?)?.toDouble()??0,hologramSaturation:(j['hologramSaturation'] as num?)?.toDouble()??0,hologramPreset:AuroraHologramPreset.values.firstWhere((e)=>e.name==j['hologramPreset'],orElse:()=>AuroraHologramPreset.aurora),bgBlendColor:j['bgBlendColor'] as int? ??-1,bgBlendDirection:(j['bgBlendDirection'] as num?)?.toDouble()??315,bgBlendLength:(j['bgBlendLength'] as num?)?.toDouble()??20,bgBlendBlur:(j['bgBlendBlur'] as num?)?.toDouble()??6,bgBlendAutoLight:j['bgBlendAutoLight'] as bool? ??true,bgBlendStrength:(j['bgBlendStrength'] as num?)?.toDouble()??70,bgBlendLightStrength:(j['bgBlendLightStrength'] as num?)?.toDouble()??65,bgBlendShadowStrength:(j['bgBlendShadowStrength'] as num?)?.toDouble()??45,bgBlendAmbientStrength:(j['bgBlendAmbientStrength'] as num?)?.toDouble()??18,bgBlendReflectionStrength:(j['bgBlendReflectionStrength'] as num?)?.toDouble()??22,bgBlendColorBleed:(j['bgBlendColorBleed'] as num?)?.toDouble()??35,bgBlendSoftness:(j['bgBlendSoftness'] as num?)?.toDouble()??55,bgBlendSecondaryStrength:(j['bgBlendSecondaryStrength'] as num?)?.toDouble()??35,bgBlendMaterialProtection:(j['bgBlendMaterialProtection'] as num?)?.toDouble()??75,bgBlendSamplingBand:(j['bgBlendSamplingBand'] as num?)?.toDouble()??28,bgBlendLightColor:j['bgBlendLightColor'] as int? ??-1,bgBlendAmbientColor:j['bgBlendAmbientColor'] as int? ??-1,bgBlendShadowColor:j['bgBlendShadowColor'] as int? ??-1,bgBlendReflectionColor:j['bgBlendReflectionColor'] as int? ??-1,bgBlendShowAnalysis:j['bgBlendShowAnalysis'] as bool? ??true,inkPoolColor:j['inkPoolColor'] as int? ??0xFF000000,inkPoolRange:(j['inkPoolRange'] as num?)?.toDouble()??12,inkPoolCenterWidth:(j['inkPoolCenterWidth'] as num?)?.toDouble()??6,autoLineartRoughWidth:(j['autoLineartRoughWidth'] as num?)?.toDouble()??12,autoLineartOutputWidth:(j['autoLineartOutputWidth'] as num?)?.toDouble()??2,autoLineartTaperLength:(j['autoLineartTaperLength'] as num?)?.toDouble()??8,autoLineartSmoothing:(j['autoLineartSmoothing'] as num?)?.toDouble()??5,autoLineartColor:j['autoLineartColor'] as int? ??0xFF000000,prismBlurPx:(j['prismBlurPx'] as num?)?.toDouble()??17,prismDirectionDegrees:(j['prismDirectionDegrees'] as num?)?.toDouble()??90);
}
