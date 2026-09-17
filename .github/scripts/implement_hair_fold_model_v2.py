from pathlib import Path

p = Path('lib/models/brush.dart')
s = p.read_text(encoding='utf-8')

def once(old: str, new: str) -> None:
    global s
    if new in s:
        return
    if old not in s:
        raise SystemExit(f'anchor missing: {old[:80]!r}')
    s = s.replace(old, new, 1)

once(
"""  final bool foldEnabled;
  final double foldTriggerAngle;
  final double yBranchAngle;
""",
"""  final bool foldEnabled;
  final double foldTriggerAngle;
  final double foldCurveStartRatio;
  final double foldDepthRatio;
  final double foldLengthRatio;
  final double foldEndTaperRatio;
  final bool foldWaveEnabled;
  final double foldWaveEndRatio;
  final double foldWaveTriggerAngle;
  // Legacy Y fields remain readable during the pre-release transition. They
  // are no longer the current fold-shape controls.
  final double yBranchAngle;
""")

once(
"""    this.foldEnabled = false,
    this.foldTriggerAngle = 90.0,
    this.yBranchAngle = 45.0,
""",
"""    this.foldEnabled = false,
    this.foldTriggerAngle = 90.0,
    this.foldCurveStartRatio = 0.25,
    this.foldDepthRatio = 0.55,
    this.foldLengthRatio = 0.8,
    this.foldEndTaperRatio = 0.35,
    this.foldWaveEnabled = false,
    this.foldWaveEndRatio = 0.0,
    this.foldWaveTriggerAngle = 45.0,
    this.yBranchAngle = 45.0,
""")

once(
"""  static int clampLateralRepeatCount(int value) => value.clamp(1, 10).toInt();

  Brush copyWith({
""",
"""  static int clampLateralRepeatCount(int value) => value.clamp(1, 10).toInt();

  static double clampFoldRatio(double value, double fallback) =>
      value.isFinite ? value.clamp(0.0, 1.0).toDouble() : fallback;

  static double clampFoldAngle(double value, double fallback) =>
      value.isFinite ? value.clamp(1.0, 180.0).toDouble() : fallback;

  Brush copyWith({
""")

once(
"""    bool? foldEnabled,
    double? foldTriggerAngle,
    double? yBranchAngle,
""",
"""    bool? foldEnabled,
    double? foldTriggerAngle,
    double? foldCurveStartRatio,
    double? foldDepthRatio,
    double? foldLengthRatio,
    double? foldEndTaperRatio,
    bool? foldWaveEnabled,
    double? foldWaveEndRatio,
    double? foldWaveTriggerAngle,
    double? yBranchAngle,
""")

once(
"""      foldEnabled: foldEnabled ?? this.foldEnabled,
      foldTriggerAngle: foldTriggerAngle ?? this.foldTriggerAngle,
      yBranchAngle: yBranchAngle ?? this.yBranchAngle,
""",
"""      foldEnabled: foldEnabled ?? this.foldEnabled,
      foldTriggerAngle: foldTriggerAngle ?? this.foldTriggerAngle,
      foldCurveStartRatio: clampFoldRatio(
        foldCurveStartRatio ?? this.foldCurveStartRatio,
        0.25,
      ),
      foldDepthRatio: clampFoldRatio(
        foldDepthRatio ?? this.foldDepthRatio,
        0.55,
      ),
      foldLengthRatio: clampFoldRatio(
        foldLengthRatio ?? this.foldLengthRatio,
        0.8,
      ),
      foldEndTaperRatio: clampFoldRatio(
        foldEndTaperRatio ?? this.foldEndTaperRatio,
        0.35,
      ),
      foldWaveEnabled: foldWaveEnabled ?? this.foldWaveEnabled,
      foldWaveEndRatio: clampFoldRatio(
        foldWaveEndRatio ?? this.foldWaveEndRatio,
        0.0,
      ),
      foldWaveTriggerAngle: clampFoldAngle(
        foldWaveTriggerAngle ?? this.foldWaveTriggerAngle,
        45.0,
      ),
      yBranchAngle: yBranchAngle ?? this.yBranchAngle,
""")

once(
"""    'foldEnabled': foldEnabled,
    'foldTriggerAngle': foldTriggerAngle,
    'yBranchAngle': yBranchAngle,
""",
"""    'foldEnabled': foldEnabled,
    'foldTriggerAngle': foldTriggerAngle,
    'foldCurveStartRatio': clampFoldRatio(foldCurveStartRatio, 0.25),
    'foldDepthRatio': clampFoldRatio(foldDepthRatio, 0.55),
    'foldLengthRatio': clampFoldRatio(foldLengthRatio, 0.8),
    'foldEndTaperRatio': clampFoldRatio(foldEndTaperRatio, 0.35),
    'foldWaveEnabled': foldWaveEnabled,
    'foldWaveEndRatio': clampFoldRatio(foldWaveEndRatio, 0.0),
    'foldWaveTriggerAngle': clampFoldAngle(foldWaveTriggerAngle, 45.0),
    'yBranchAngle': yBranchAngle,
""")

once(
"""    foldEnabled: j['foldEnabled'] as bool? ?? false,
    foldTriggerAngle: (j['foldTriggerAngle'] as num?)?.toDouble() ?? 90.0,
    yBranchAngle: (j['yBranchAngle'] as num?)?.toDouble() ?? 45.0,
""",
"""    foldEnabled: j['foldEnabled'] as bool? ?? false,
    foldTriggerAngle: (j['foldTriggerAngle'] as num?)?.toDouble() ?? 90.0,
    foldCurveStartRatio: clampFoldRatio(
      (j['foldCurveStartRatio'] as num?)?.toDouble() ?? 0.25,
      0.25,
    ),
    foldDepthRatio: clampFoldRatio(
      (j['foldDepthRatio'] as num?)?.toDouble() ?? 0.55,
      0.55,
    ),
    foldLengthRatio: clampFoldRatio(
      (j['foldLengthRatio'] as num?)?.toDouble() ?? 0.8,
      0.8,
    ),
    foldEndTaperRatio: clampFoldRatio(
      (j['foldEndTaperRatio'] as num?)?.toDouble() ?? 0.35,
      0.35,
    ),
    foldWaveEnabled: j['foldWaveEnabled'] as bool? ?? false,
    foldWaveEndRatio: clampFoldRatio(
      (j['foldWaveEndRatio'] as num?)?.toDouble() ?? 0.0,
      0.0,
    ),
    foldWaveTriggerAngle: clampFoldAngle(
      (j['foldWaveTriggerAngle'] as num?)?.toDouble() ?? 45.0,
      45.0,
    ),
    yBranchAngle: (j['yBranchAngle'] as num?)?.toDouble() ?? 45.0,
""")

p.write_text(s, encoding='utf-8', newline='\n')
