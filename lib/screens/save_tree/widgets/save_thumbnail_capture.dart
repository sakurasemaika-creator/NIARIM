import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../../services/project_service.dart';

/// Even a newly created / completely empty animation has a visible thumbnail
/// at the moment of a manual save. Capture the actual project paper color
/// rather than showing the "missing image" icon for a successful snapshot.
Future<Uint8List?> captureEmptySaveThumbnail(
  ProjectService service,
  String projectId,
) async {
  final project = service.projects.where((p) => p.id == projectId).firstOrNull;
  const width = 200;
  const height = 112;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 200, 112),
    ui.Paint()
      ..color = ui.Color(project?.backgroundColor ?? 0xFFFFFFFF),
  );
  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(width, height);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}
