// 起動画面は、ホームの一覧が使うのと同じ大きさ・同じキーで作品のサムネイルを
// 先に読む（詳細の行は行の絵の大きさで、元の大きさでは読まない）。ホームを
// 開いた最初のフレームから絵が出ていることも確かめる。
import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';

import 'helpers/home_app_harness.dart';

void main() {
  Future<void> real(WidgetTester tester, [int times = 6]) async {
    for (var i = 0; i < times; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Finder listImages() => find.descendant(
    of: find.byType(ProjectListWidget),
    matching: find.byType(Image),
  );

  for (final mode in ['small', 'detail']) {
    testWidgets('$mode：起動画面が一覧と同じ画像を読み、ホームの最初のフレームから絵が出る', (tester) async {
      const ratio = 2.75;
      final h = HomeAppHarness.prepare(
        tester,
        preferences: {homeProjectViewModeKey: mode},
      );
      final service = await h.open(
        seed: (s) async {
          for (var i = 0; i < 12; i++) {
            final p = await HomeAppHarness.work(s, '作品$i');
            await s.generateAndSaveThumbnail(p.id, force: true);
          }
        },
      );
      tester.view.devicePixelRatio = ratio;
      tester.view.physicalSize = const Size(390 * ratio, 844 * ratio);
      await real(tester);
      final viewMode = homeProjectViewModeFor(mode, 390);
      // 一覧の絵の画像は、起動画面が読むものと同じ。
      final images = listImages().evaluate().toList();
      expect(images, isNotEmpty);
      for (final element in images) {
        final image = (element.widget as Image).image;
        final path = switch (image) {
          ResizeImage(imageProvider: FileImage(:final file)) => file.path,
          FileImage(:final file) => file.path,
          _ => fail('unexpected image $image'),
        };
        expect(
          image,
          projectListThumbnailImage(
            path,
            viewMode: viewMode,
            screenWidth: 390,
            devicePixelRatio: ratio,
          ),
        );
      }

      // 画像を忘れてから起動画面を出し、先読みを待ってホームへ戻る。
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
      appRouter.go('/');
      for (var i = 0; i < 10; i++) {
        await real(tester, 1);
      }
      final cache = PaintingBinding.instance.imageCache;
      for (final project in service.projects) {
        final path = project.thumbnailPath!;
        final wanted = projectListThumbnailImage(
          path,
          viewMode: viewMode,
          screenWidth: 390,
          devicePixelRatio: ratio,
        );
        final key = await tester.runAsync(
          () => wanted.obtainKey(ImageConfiguration.empty),
        );
        expect(cache.containsKey(key!), isTrue, reason: path);
        if (viewMode.isDetail) {
          // 元の大きさの絵は読まない（一覧は使わない）。
          expect(cache.containsKey(FileImage(File(path))), isFalse);
        }
      }

      appRouter.go('/home');
      await tester.pump();
      await tester.pump();
      final shown = [
        for (final e
            in find
                .descendant(
                  of: find.byType(ProjectListWidget),
                  matching: find.byType(RawImage),
                )
                .evaluate())
          (e.renderObject! as RenderImage).image != null,
      ];
      expect(shown, isNotEmpty);
      expect(shown, everyElement(isTrue), reason: '絵が後から出てくる');
      await h.close();
    });
  }
}
