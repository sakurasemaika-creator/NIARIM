import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/models/home_list_filters.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/widgets/sort_mode_control.dart';
import 'package:provider/provider.dart';

import 'helpers/home_keyboard_harness.dart';

/// 共有の受け取ったフォルダの中の画面にも、作品一覧のフォルダと同じ並び順の
/// 切り替え（名前／更新日時と向き）を出す。今の並び順は共有のタブの並び順
/// （設定に残る）で、フォルダの中で変えると共有のタブの並び順になり、戻った
/// タブにも当たる。7言語×320・360（文字1倍・2倍）とPC 1280。
///
/// 以前はフォルダの中は共有のタブの並び順で並ぶのに、どの並び順かが画面に
/// 出ず、変えることもできなかった（DISC154）。
void main() {
  const languages = ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant'];
  const names = ['Alpha', 'Bravo', 'Charlie'];

  for (final (label, size, scale, pc) in const [
    ('320', Size(320, 740), 1.0, false),
    ('360 x2', Size(360, 740), 2.0, false),
    ('PC 1280', Size(1280, 800), 1.0, true),
  ]) {
    for (final language in languages) {
      testWidgets('$language $label: the received folder shows and changes '
          'the Shared sort', (tester) async {
        final home = await HomeKeyboardHarness.open(
          tester,
          language: language,
          size: size,
          textScale: scale,
          prefs: {'force_pc_mode': pc ? 1 : 0},
        );
        final l10n = home.l10n;
        final projects = home.projects;
        final settings = tester
            .element(find.byType(HomeScreen))
            .read<SettingsService>();
        final problems = <String>[];

        Future<void> io([int rounds = 4]) async {
          for (var i = 0; i < rounds; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 30)),
            );
            await tester.pump(const Duration(milliseconds: 50));
          }
          await home.settle();
        }

        late String box;
        await tester.runAsync(() async {
          // 受け取った作品を古い順に Alpha・Bravo・Charlie。
          final ids = <String>[];
          for (final name in names) {
            final original = await projects.createProject(
              name: name,
              fps: 1,
              durationSeconds: 1,
              backgroundColor: 0xFFFFFFFF,
              exportWidth: 32,
              exportHeight: 32,
            );
            await projects.saveProject(original.id);
            final base = await NiaproSerializer.projectsBasePath();
            final data = await NiaproSerializer.load(
              '$base/${original.id}/${original.id}.niapro',
            );
            final imported = await projects.importSharedProject(data);
            await projects.saveProject(imported.id);
            await projects.deleteProject(original.id);
            ids.add(imported.id);
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }
          box = (await projects.createSharedFolder('Box')).id;
          for (final id in ids) {
            await projects.moveToSharedFolder(id, box);
          }
        });
        await io();

        /// 画面に並んだ名前の順（上から、同じ行は左から）。
        List<String> order() {
          final at = <String, Offset>{};
          for (final name in names) {
            final found = find.text(name);
            if (found.evaluate().isEmpty) continue;
            at[name] = tester.getTopLeft(found.first);
          }
          return at.keys.toList()..sort((a, b) {
            final dy = at[a]!.dy.compareTo(at[b]!.dy);
            return dy != 0 ? dy : at[a]!.dx.compareTo(at[b]!.dx);
          });
        }

        await tester.tap(find.byKey(const ValueKey('home_tab_2')));
        await io();
        final folder = find.byKey(ValueKey('collectionFolder_$box'));
        await tester.ensureVisible(folder);
        await tester.tap(folder);
        await io(6);

        // フォルダの中に並び順の切り替えがあり、共有のタブの並び順
        // （既定：更新日時の新しい順）を出す。
        final control = find.byType(SortModeControl);
        if (control.evaluate().isEmpty) {
          problems.add('no sort control in the received folder');
        } else {
          final rect = tester.getRect(control);
          if (rect.left < 0 || rect.right > size.width) {
            problems.add('sort control $rect leaves the screen');
          }
          for (final button in [
            find.descendant(of: control, matching: find.byType(IconButton)),
            find.descendant(
              of: control,
              matching: find.byWidgetPredicate((w) => w is PopupMenuButton),
            ),
          ]) {
            for (final e in button.evaluate()) {
              final bounds = tester.getRect(find.byWidget(e.widget));
              if (bounds.width < 48 || bounds.height < 48) {
                problems.add('sort button smaller than 48x48: $bounds');
              }
            }
          }
        }
        if (order().join(',') != 'Charlie,Bravo,Alpha') {
          problems.add('initial order ${order()}');
        }
        final shot = await home.shot();
        Directory('build/home-shared-folder-sort').createSync(recursive: true);
        File(
          'build/home-shared-folder-sort/${language}_${label.replaceAll(' ', '_')}.png',
        ).writeAsBytesSync(
          img.encodePng(
            img.Image.fromBytes(
              width: shot.width,
              height: shot.height,
              bytes: shot.rgba.buffer,
              numChannels: 4,
            ),
          ),
        );

        if (control.evaluate().isNotEmpty) {
          // 向きを変える：古い順になり、共有のタブの並び順として残る。
          final direction = find.descendant(
            of: control,
            matching: find.byIcon(Icons.arrow_downward),
          );
          if (direction.evaluate().isEmpty) {
            // 狭い幅ではメニューから選ぶ。
            await tester.tap(control);
            await home.settle();
            await tester.tap(find.text(l10n.homeSortDirectionDescTooltip).last);
          } else {
            await tester.tap(direction);
          }
          await io();
          if (order().join(',') != 'Alpha,Bravo,Charlie') {
            problems.add('order after the direction change ${order()}');
          }
          final saved = settings.homeListFilters(HomeList.shared).sort;
          if (saved != 'updatedAsc') {
            problems.add('Shared sort saved as $saved');
          }
        }

        // 戻った共有のタブも古い順（向きの印が上向き）。
        await tester.binding.handlePopRoute();
        await io();
        final tabControl = find.byType(SortModeControl);
        if (tabControl.evaluate().isNotEmpty &&
            find
                .descendant(
                  of: tabControl.first,
                  matching: find.byIcon(Icons.arrow_upward),
                )
                .evaluate()
                .isEmpty &&
            find
                .descendant(
                  of: tabControl.first,
                  matching: find.byIcon(Icons.arrow_downward),
                )
                .evaluate()
                .isNotEmpty) {
          problems.add('the Shared tab still sorts newest first');
        }

        expect(problems, isEmpty, reason: problems.join('\n'));
        expect(tester.takeException(), isNull);
        await home.close();
      });
    }
  }
}
