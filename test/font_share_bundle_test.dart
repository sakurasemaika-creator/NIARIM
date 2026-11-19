import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/services/font_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  const license = 'Copyright Font Authors\n\nFamily-specific license.';
  late Directory sandbox;
  late ProjectService projects;
  late FontService fonts;
  late Uint8List fixture;

  setUp(() async {
    sandbox = Directory.systemTemp.createTempSync('niarim_font_share_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, (_) async => sandbox.path);
    SharedPreferences.setMockInitialValues({});
    projects = ProjectService();
    fonts = FontService();
    await projects.init();
    await fonts.init();
    fixture = await File('assets/fonts/NotoSerifKRSubset.ttf').readAsBytes();
  });

  tearDown(() async {
    projects.dispose();
    fonts.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, null);
    await sandbox.delete(recursive: true);
  });

  Future<String> workUsing(String family) async {
    final project = await projects.createProject(
      name: 'Font share',
      fps: 1,
      durationSeconds: 1,
      backgroundColor: 0,
      exportWidth: 64,
      exportHeight: 48,
    );
    final sceneId = projects.scenesOf(project.id).first.id;
    final layer = projects.addTextLayer(
      projectId: project.id,
      sceneId: sceneId,
      frameIndex: 0,
      text: 'Text in a font',
      position: Offset.zero,
    );
    projects.updateLayer(
      projectId: project.id,
      sceneId: sceneId,
      frameIndex: 0,
      layer: layer.copyWith(
        textObject: layer.textObject!.copyWith(fontFamily: family),
      ),
    );
    await projects.saveProject(project.id);
    return project.id;
  }

  test(
    'a catalog font and its license survive share, import, and restart',
    () async {
      final entry = fonts.catalog.firstWhere(
        (font) => font.id == 'dlfont_abeezee',
      );
      final source = Uri.parse(entry.sourceUrl);
      final requested = <Uri>[];
      await http.runWithClient(
        () => fonts.downloadCatalogFont(entry),
        () => MockClient((request) async {
          requested.add(request.url);
          if (request.url == source) return http.Response.bytes(fixture, 200);
          return http.Response(license, 200);
        }),
      );
      expect(requested, [source, source.resolve('OFL.txt')]);

      final font = fonts.fonts.single;
      final id = await workUsing(fonts.familyNameOf(font));
      final bundle = await buildFontShareBundle(projects, fonts, id);
      final archive = await NiaproSerializer.saveShare(
        project: projects.projects.single,
        scenes: projects.scenesOf(id),
        tileManager: projects.tileManagerOf(id),
        outputDir: sandbox.path,
        fontFiles: bundle.files,
        fontsManifest: bundle.manifest,
      );
      final data = await NiaproSerializer.loadShare(archive.path);
      expect(data.fontFiles.keys, [
        font.fileName,
        '${font.fileName}.license.txt',
      ]);
      final bundled = NiaproSerializer.bundledFonts(data).single;
      expect(bundled.bytes, fixture);
      expect(bundled.licenseNotice, contains(entry.sourceUrl));
      expect(bundled.licenseNotice, endsWith(license));

      await fonts.removeFont(font.id);
      await fonts.importBundledFont(
        id: bundled.id,
        displayName: bundled.displayName,
        fileName: bundled.fileName,
        bytes: bundled.bytes,
        licenseNotice: bundled.licenseNotice,
      );
      final restarted = FontService();
      addTearDown(restarted.dispose);
      await restarted.init();
      final reshared = await buildFontShareBundle(projects, restarted, id);
      expect(reshared.files, bundle.files);
    },
  );

  test(
    'an old catalog font needs matching bytes and a license to be shared',
    () async {
      final entry = fonts.catalog.firstWhere(
        (font) => font.id == 'dlfont_abeezee',
      );
      await fonts.importBundledFont(
        id: entry.id,
        displayName: entry.displayName,
        fileName: entry.fileName,
        bytes: fixture,
      );
      final font = fonts.fonts.single;
      final id = await workUsing(fonts.familyNameOf(font));
      final source = Uri.parse(entry.sourceUrl);
      await http.runWithClient(
        () => expectLater(
          buildFontShareBundle(projects, fonts, id),
          throwsA(isA<CatalogFontNoticeException>()),
        ),
        () => MockClient((_) async => http.Response('changed font file', 200)),
      );
      final personalTransfer = await buildFontShareBundle(
        projects,
        fonts,
        id,
        forSharing: false,
      );
      expect(personalTransfer.files.keys, [font.fileName]);
      final bundle = await http.runWithClient(
        () => buildFontShareBundle(projects, fonts, id),
        () => MockClient((request) async {
          if (request.url == source) return http.Response.bytes(fixture, 200);
          return http.Response(license, 200);
        }),
      );
      expect(
        utf8.decode(bundle.files['${font.fileName}.license.txt']!),
        endsWith(license),
      );
      expect(fonts.fonts.single.licenseNotice, isNotNull);
    },
  );

  test(
    'public sharing writes names, and legacy forwarding removes font files',
    () async {
      final source = File('${sandbox.path}/manual.ttf');
      await source.writeAsBytes(fixture);
      final font = (await fonts.addFont(source.path, 'Manual font'))!;
      final id = await workUsing(fonts.familyNameOf(font));
      final project = projects.projects.single;
      final names = {font.id: font.displayName};

      final fresh = await projects.createOutgoingShare(
        project: project,
        fontsManifest: projectFontNamesManifest(projects, fonts, id),
      );
      final freshData = await NiaproSerializer.loadShare(fresh.path);
      expect(freshData.fontFiles, isEmpty);
      expect(NiaproSerializer.fontNames(freshData.fontsManifest), names);
      expect(await NiaproSerializer.withoutBundledFontFiles(fresh), isNull);

      final personal = await buildFontShareBundle(
        projects,
        fonts,
        id,
        forSharing: false,
      );
      final legacy = await NiaproSerializer.saveShare(
        project: project,
        scenes: projects.scenesOf(id),
        tileManager: projects.tileManagerOf(id),
        outputDir: sandbox.path,
        materialFiles: {
          'sample.wav': Uint8List.fromList([1, 2, 3]),
        },
        fontFiles: personal.files,
        fontsManifest: personal.manifest,
      );
      final original = await legacy.readAsBytes();
      final sanitized = await NiaproSerializer.withoutBundledFontFiles(legacy);
      final forwarded = NiaproSerializer.loadFromBytes(sanitized!);
      expect(forwarded.fontFiles, isEmpty);
      expect(NiaproSerializer.bundledFonts(forwarded), isEmpty);
      expect(NiaproSerializer.fontNames(forwarded.fontsManifest), names);
      expect(forwarded.project.name, project.name);
      expect(forwarded.materialFiles['sample.wav'], [1, 2, 3]);
      expect(await legacy.readAsBytes(), original);
    },
  );

  test('a user-imported font does not get an invented license', () async {
    final source = File('${sandbox.path}/manual.ttf');
    await source.writeAsBytes(fixture);
    final font = (await fonts.addFont(source.path, 'Manual font'))!;
    final id = await workUsing(fonts.familyNameOf(font));
    final bundle = await buildFontShareBundle(projects, fonts, id);
    expect(bundle.files.keys, [font.fileName]);
    expect(bundle.files[font.fileName], fixture);
  });
}
