import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/utils/duplicate_name.dart';

Project _project(String name, {String? folderId, bool shared = false}) =>
    Project(
      id: name,
      name: name,
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      totalWorkSeconds: 0,
      folderId: folderId,
      isSharedImport: shared,
    );

/// 複製の名前は、複製先のフォルダに同じ名前の複製があれば番号を付ける。
void main() {
  final ja = lookupAppLocalizations(const Locale('ja'));

  test('the first copy has the plain name, later ones are numbered', () {
    String next(List<Project> projects) =>
        duplicateProjectName(ja, '作品1', folderId: null, projects: projects);

    final projects = [_project('作品1')];
    expect(next(projects), '作品1 (コピー)');
    projects.add(_project('作品1 (コピー)'));
    expect(next(projects), '作品1 (コピー 2)');
    projects.add(_project('作品1 (コピー 2)'));
    expect(next(projects), '作品1 (コピー 3)');
    // 間の番号が空いたら、そこを使う。
    projects.removeWhere((p) => p.name == '作品1 (コピー 2)');
    projects.add(_project('作品1 (コピー 3)'));
    expect(next(projects), '作品1 (コピー 2)');
  });

  test('only names in the destination folder count', () {
    final projects = [
      _project('作品1 (コピー)', folderId: 'other'),
      _project('作品1 (コピー)', shared: true),
    ];
    expect(
      duplicateProjectName(ja, '作品1', folderId: null, projects: projects),
      '作品1 (コピー)',
    );
    expect(
      duplicateProjectName(ja, '作品1', folderId: 'other', projects: projects),
      '作品1 (コピー 2)',
    );
  });

  test('every language numbers its own copy wording', () {
    for (final (code, plain, second) in [
      ('en', 'A (copy)', 'A (copy 2)'),
      ('es', 'A (copia)', 'A (copia 2)'),
      ('fr', 'A (copie)', 'A (copie 2)'),
      ('ko', 'A (사본)', 'A (사본 2)'),
      ('zh', 'A（副本）', 'A（副本 2）'),
    ]) {
      final l10n = lookupAppLocalizations(Locale(code));
      expect(
        duplicateProjectName(
          l10n,
          'A',
          folderId: null,
          projects: [_project(plain)],
        ),
        second,
        reason: code,
      );
    }
    final hant = lookupAppLocalizations(
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    );
    expect(
      duplicateProjectName(
        hant,
        'A',
        folderId: null,
        projects: [_project('A（副本）')],
      ),
      'A（副本 2）',
    );
  });
}
