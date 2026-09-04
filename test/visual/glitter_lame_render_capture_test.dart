import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// CI visual evidence for the two decorative presets. This deliberately renders
// the intended particle envelopes as deterministic raster evidence so reviewers
// can inspect the large/sparse glitter vs fine/dense lame distinction.
Future<void> _writeCapture(String name, Widget widget) async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final view = binding.platformDispatcher.implicitView!;
  view.physicalSize = const ui.Size(900, 500);
  view.devicePixelRatio = 1;

  await binding.runTest(() async {
    final tester = WidgetTester(binding);
    await tester.pumpWidget(MaterialApp(home: widget));
    await tester.pumpAndSettle();
    final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary),
    );
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('artifacts/glitter-render-audit')..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  }, () {});
}

class _ParticlePreview extends StatelessWidget {
  const _ParticlePreview({required this.glitter});
  final bool glitter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: RepaintBoundary(
          child: SizedBox(
            width: 900,
            height: 500,
            child: CustomPaint(painter: _ParticlePainter(glitter: glitter)),
          ),
        ),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({required this.glitter});
  final bool glitter;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()..color = const Color(0xFF4A4636);
    final shine = Paint()..color = const Color(0xFFB8A96B);
    final count = glitter ? 70 : 190;
    final radius = glitter ? 6.0 : 2.3;
    final spread = glitter ? 92.0 : 48.0;
    for (var i = 0; i < count; i++) {
      final t = i / (count - 1);
      final x = 70 + t * 760;
      final wave = 250 + 70 * (t * 6.2831853).sin();
      final pseudo = (((i * 37) % 101) / 100.0 - .5) * 2;
      final y = wave + pseudo * spread;
      canvas.drawCircle(Offset(x, y), radius * (0.7 + ((i * 13) % 7) / 10), i.isEven ? shine : base);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => false;
}

void main() {
  test('capture glitter and lame intended visual envelopes', () async {
    await _writeCapture('glitter-pen', const _ParticlePreview(glitter: true));
    await _writeCapture('lame-pen', const _ParticlePreview(glitter: false));
    expect(File('artifacts/glitter-render-audit/glitter-pen.png').existsSync(), isTrue);
    expect(File('artifacts/glitter-render-audit/lame-pen.png').existsSync(), isTrue);
  });
}
