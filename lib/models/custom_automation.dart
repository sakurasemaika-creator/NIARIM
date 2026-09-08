import 'dart:convert';

enum CustomAutomationSurface { canvas, timeline }

enum CustomAutomationExecutionScope { currentFrame, allFrames }

class CustomAutomationStep {
  final String id;
  final CustomAutomationSurface surface;
  final String command;
  final Map<String, Object?> args;
  final bool changesFrame;
  final bool changesScene;
  final String label;

  const CustomAutomationStep({
    required this.id,
    required this.surface,
    required this.command,
    required this.label,
    this.args = const {},
    this.changesFrame = false,
    this.changesScene = false,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'surface': surface.name,
    'command': command,
    'label': label,
    'args': args,
    'changesFrame': changesFrame,
    'changesScene': changesScene,
  };

  factory CustomAutomationStep.fromJson(Map<String, Object?> json) {
    final surfaceName = json['surface'] as String?;
    return CustomAutomationStep(
      id: json['id'] as String? ?? '',
      surface: CustomAutomationSurface.values.firstWhere(
        (value) => value.name == surfaceName,
        orElse: () => CustomAutomationSurface.canvas,
      ),
      command: json['command'] as String? ?? '',
      label: json['label'] as String? ?? '',
      args: (json['args'] as Map?)?.cast<String, Object?>() ?? const {},
      changesFrame: json['changesFrame'] as bool? ?? false,
      changesScene: json['changesScene'] as bool? ?? false,
    );
  }
}

class CustomAutomation {
  static const currentFormatVersion = 1;

  final String id;
  final String name;
  final List<CustomAutomationStep> steps;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CustomAutomation({
    required this.id,
    required this.name,
    required this.steps,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isCanvasOnly =>
      steps.isNotEmpty &&
      steps.every((step) => step.surface == CustomAutomationSurface.canvas);

  bool get staysInSingleFrame =>
      steps.every((step) => !step.changesFrame && !step.changesScene);

  bool get supportsFrameScopeChoice => isCanvasOnly && staysInSingleFrame;

  CustomAutomation copyWith({
    String? name,
    List<CustomAutomationStep>? steps,
    DateTime? updatedAt,
  }) => CustomAutomation(
    id: id,
    name: name ?? this.name,
    steps: steps ?? this.steps,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toJson() => {
    'format': 'niarim-custom-automation',
    'version': currentFormatVersion,
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'steps': steps.map((step) => step.toJson()).toList(),
  };

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory CustomAutomation.fromJson(Map<String, Object?> json) {
    if (json['format'] != 'niarim-custom-automation') {
      throw const FormatException('Unsupported automation format');
    }
    final version = json['version'] as int? ?? 0;
    if (version < 1 || version > currentFormatVersion) {
      throw FormatException('Unsupported automation version: $version');
    }
    final rawSteps = json['steps'] as List? ?? const [];
    return CustomAutomation(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      steps: rawSteps
          .whereType<Map>()
          .map((step) => CustomAutomationStep.fromJson(step.cast<String, Object?>()))
          .toList(),
    );
  }

  factory CustomAutomation.fromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Automation root must be an object');
    }
    return CustomAutomation.fromJson(decoded.cast<String, Object?>());
  }
}
