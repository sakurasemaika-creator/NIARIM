// 複製の番号は、どこから複製しても複製先のフォルダに並ぶ作品で数える
// （`duplicateProjectName`の決まり）。
//
// 以前はホームの貼り付け・カードのメニューの複製だけ全部の作品で数え、作品
// 詳細の複製はフォルダの中で数えたので、同じ作品を同じフォルダへ複製しても
// 「(コピー 2)」と「(コピー)」に分かれた（実際に使ってみて発見）。
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/utils/duplicate_name.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory temp;
  final ja = lookupAppLocalizations(const Locale('ja'));
  String namer(String name, Set<String> taken) =>
      numberedCopyName(ja, name, taken);

  setUp(() {
    temp = Directory.systemTemp.createTempSync('niarim-copy-number-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => temp.path);
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  Future<Project> work(ProjectService service, String name, {String? folder}) =>
      service.createProject(
        name: name,
        fps: 2,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 32,
        exportHeight: 32,
        folderId: folder,
      );

  Project newest(ProjectService service) => service.projects.last;

  test(
    'copies are numbered among the works of the folder they go to',
    () async {
      final service = ProjectService();
      addTearDown(service.dispose);
      final folder = await service.createFolder('課題');
      final apple = await work(service, 'apple');

      // 一番上のフォルダへの複製（作品のメニュー・作品詳細の複製）。
      await service.duplicateProject(apple.id, namer: namer);
      expect(newest(service).name, 'apple (コピー)');
      expect(newest(service).folderId, isNull);

      // ほかのフォルダへの貼り付けは、そのフォルダの中で数える。一番上の
      // 「apple (コピー)」は数えない。作品詳細の複製（そのフォルダの中で
      // 数える `duplicateProjectName`）と同じ名前になる。
      await service.duplicateProject(
        apple.id,
        targetFolderId: folder.id,
        useTargetFolder: true,
        namer: namer,
      );
      expect(newest(service).name, 'apple (コピー)');
      expect(newest(service).folderId, folder.id);
      expect(
        duplicateProjectName(
          ja,
          'apple',
          folderId: null,
          projects: service.projects.where((p) => p.id != newest(service).id),
        ),
        'apple (コピー 2)',
        reason: '一番上にはもう「apple (コピー)」がある',
      );

      // 同じフォルダへもう一度貼り付けると番号が付く。
      await service.duplicateProject(
        apple.id,
        targetFolderId: folder.id,
        useTargetFolder: true,
        namer: namer,
      );
      expect(newest(service).name, 'apple (コピー 2)');

      // フォルダの中の作品を作品詳細で複製したとき（同じフォルダへ）も、
      // フォルダの中で数える。
      final inFolder = service.projects.firstWhere(
        (p) => p.folderId == folder.id && p.name == 'apple (コピー)',
      );
      await service.duplicateProject(inFolder.id, namer: namer);
      expect(newest(service).name, 'apple (コピー 3)');
      expect(newest(service).folderId, folder.id);
      expect(
        newest(service).name,
        duplicateProjectName(
          ja,
          inFolder.name,
          folderId: folder.id,
          projects: service.projects.where((p) => p.id != newest(service).id),
        ),
      );
      await service.settleWrites();
    },
  );
}
