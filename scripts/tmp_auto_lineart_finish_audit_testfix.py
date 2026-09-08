from pathlib import Path

p = Path('test/auto_lineart_control_overlay_test.dart')
s = p.read_text()
if "second pointer cancels a control drag instead of moving it" in s:
    raise SystemExit(0)
insert = r'''

  testWidgets('second pointer cancels a control drag instead of moving it', (
    tester,
  ) async {
    final graph = AutoLineartGraph(
      width: 100,
      height: 100,
      paths: const [
        AutoLineartPath(
          points: [AutoLineartPoint(25, 50), AutoLineartPoint(75, 50)],
          startIsJunction: false,
          endIsJunction: false,
          persistence: 1,
        ),
      ],
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 100, 100),
      Paint()..color = Colors.white,
    );
    final image = await recorder.endRecording().toImage(100, 100);
    addTearDown(image.dispose);
    final moves = <AutoLineartPoint>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 200,
            height: 200,
            child: AutoLineartControlOverlay(
              image: image,
              graph: graph,
              onPointMoved: (_, _, point) => moves.add(point),
            ),
          ),
        ),
      ),
    );
    final box = tester.getRect(find.byType(AutoLineartControlOverlay));
    final first = await tester.startGesture(
      Offset(box.left + 50, box.top + 100),
      pointer: 1,
    );
    final second = await tester.startGesture(
      Offset(box.left + 160, box.top + 160),
      pointer: 2,
    );
    await first.moveBy(const Offset(30, -20));
    await tester.pump();
    await second.up();
    await first.up();
    expect(moves, isEmpty);
  });
'''
idx = s.rfind('\n}')
if idx < 0:
    raise SystemExit('main closing brace not found')
p.write_text(s[:idx] + insert + s[idx:])
