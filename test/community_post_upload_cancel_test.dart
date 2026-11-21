import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/community/community_post_screen.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/youtube_upload_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/pump_real_async.dart';

class _VideoPicker extends FilePicker {
  _VideoPicker(this.file);

  final File file;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    @Deprecated('unused') bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => FilePickerResult([
    PlatformFile(name: 'test.mp4', path: file.path, size: file.lengthSync()),
  ]);
}

class _Account implements GoogleSignInAccount {
  @override
  String get id => 'test-account';

  @override
  String get email => 'account@example.invalid';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends GoogleAuthService {
  @override
  final GoogleSignInAccount account = _Account();

  @override
  bool get isConfigured => true;

  @override
  Future<String?> youtubeUploadAccessToken({
    bool promptIfNecessary = false,
  }) async => 'test-token';

  @override
  Future<String?> youtubeReadAccessToken({
    bool promptIfNecessary = false,
  }) async => 'read-only-token';
}

File _sampleVideo() {
  final directory = Directory.systemTemp.createTempSync('upload_cancel_');
  addTearDown(() => directory.deleteSync(recursive: true));
  return File('${directory.path}/test.mp4')..writeAsBytesSync([0, 1]);
}

void main() {
  test('cancellation interrupts retry delay without probing', () async {
    final file = _sampleVideo();
    final retryResponse = Completer<void>();
    final methods = <String>[];
    final uploader = YoutubeUploadService(
      httpClient: MockClient((request) async {
        methods.add(request.method);
        if (request.method == 'POST') {
          return http.Response(
            '',
            200,
            headers: {'location': 'https://example.invalid/upload'},
          );
        }
        retryResponse.complete();
        return http.Response('', 503, headers: {'retry-after': '120'});
      }),
    );
    addTearDown(uploader.close);
    final cancellation = YoutubeUploadCancellation();
    final result = expectLater(
      uploader.uploadVideo(
        file: file,
        accessToken: 'test-token',
        title: 'My film',
        containsSyntheticMedia: false,
        selfDeclaredMadeForKids: false,
        cancellation: cancellation,
      ),
      throwsA(isA<YoutubeUploadCancelled>()),
    );
    await retryResponse.future;
    await Future<void>.delayed(Duration.zero);
    cancellation.cancel();
    await result.timeout(const Duration(seconds: 3));
    expect(methods, ['POST', 'PUT']);
  });

  for (final synthetic in [true, false]) {
    for (final kids in [true, false]) {
      test(
        'one upload sets synthetic=$synthetic and madeForKids=$kids',
        () async {
          final requests = <String>[];
          final publishAt = DateTime.now().toUtc().add(const Duration(days: 1));
          final uploader = YoutubeUploadService(
            httpClient: MockClient((request) async {
              requests.add(request.method);
              if (request.method == 'POST') {
                expect(request.url.queryParameters['part'], 'snippet,status');
                expect(jsonDecode(request.body)['status'], {
                  'privacyStatus': 'private',
                  'publishAt': publishAt.toIso8601String(),
                  'containsSyntheticMedia': synthetic,
                  'selfDeclaredMadeForKids': kids,
                });
                return http.Response(
                  '',
                  200,
                  headers: {'location': 'https://example.invalid/upload'},
                );
              }
              return http.Response('{"id":"test-video"}', 200);
            }),
          );
          addTearDown(uploader.close);
          final result = await uploader.uploadVideo(
            file: _sampleVideo(),
            accessToken: 'test-token',
            title: 'My film',
            containsSyntheticMedia: synthetic,
            selfDeclaredMadeForKids: kids,
            scheduledPublishAt: publishAt,
          );
          expect(result.videoId, 'test-video');
          expect(requests, ['POST', 'PUT']);
        },
      );
    }
  }

  for (final completedBeforeCancel in [false, true]) {
    testWidgets(
      completedBeforeCancel
          ? 'cancel from back preserves a video completed during confirmation'
          : 'cancel from the toolbar aborts an in-flight request',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(480, 1500);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        SharedPreferences.setMockInitialValues({});
        FilePicker.platform = _VideoPicker(_sampleVideo());

        final registrations = <Map<String, dynamic>>[];
        final community = CommunityService(
          api: CommunityApi(
            NiarimApiClient(
              baseUrl: 'https://example.invalid',
              httpClient: MockClient((request) async {
                if (request.url.path == '/me/works') {
                  return http.Response('{"authorId":"owner","works":[]}', 200);
                }
                registrations.add(
                  jsonDecode(request.body) as Map<String, dynamic>,
                );
                return http.Response('{}', 500);
              }),
              maxGetRetries: 0,
              tokenProvider: () async => 'test-token',
            ),
          ),
        );
        final success = Completer<http.StreamedResponse>();
        var uploadStarted = false;
        var requests = 0;
        var abortTriggered = false;
        final client = MockClient.streaming((request, body) async {
          requests++;
          if (request.method == 'POST') {
            final data = jsonDecode(await body.bytesToString());
            expect(data['status'], {
              'privacyStatus': 'unlisted',
              'containsSyntheticMedia': completedBeforeCancel,
              'selfDeclaredMadeForKids': !completedBeforeCancel,
            });
            return http.StreamedResponse(
              const Stream.empty(),
              200,
              headers: {'location': 'https://example.invalid/upload'},
            );
          }
          final upload = request as http.AbortableRequest;
          uploadStarted = true;
          return Future.any([
            success.future,
            upload.abortTrigger!.then<http.StreamedResponse>((_) {
              abortTriggered = true;
              throw http.RequestAbortedException(upload.url);
            }),
          ]);
        });

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => SettingsService()),
              ChangeNotifierProvider<GoogleAuthService>(create: (_) => _Auth()),
              ChangeNotifierProvider(create: (_) => community),
            ],
            child: MaterialApp(
              locale: const Locale('ja'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CommunityPostScreen(
                          createUploader: () =>
                              YoutubeUploadService(httpClient: client),
                        ),
                      ),
                    ),
                    child: const Text('Open post'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open post'));
        await tester.pumpAndSettle();
        final l10n = lookupAppLocalizations(const Locale('ja'));
        for (final field in [
          'communityPostTitle',
          'communityPostYoutubeTitle',
        ]) {
          await tester.enterText(find.byKey(Key(field)), 'My film');
        }

        Future<void> tapVisible(Finder finder) async {
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pump();
          await Scrollable.ensureVisible(
            tester.element(finder),
            alignment: 0.5,
          );
          await tester.pump();
          await tester.tap(finder.hitTestable());
          await tester.pump();
        }

        final submit = find.byKey(const Key('communityPostSubmitButton'));
        await tapVisible(find.text(l10n.communityPostPickVideo));
        Finder answer(String group, bool yes) => find.descendant(
          of: find.byKey(Key(group)),
          matching: find.widgetWithText(
            RadioListTile<bool>,
            yes ? l10n.customAutomationYes : l10n.customAutomationNo,
          ),
        );
        final missing = find.text(
          l10n.communityPostErrorLabel(
            l10n.communityPostYoutubeDeclarationsRequired,
          ),
        );
        await tapVisible(submit);
        expect(missing, findsOneWidget);
        expect(requests, 0);
        await tapVisible(
          answer('communityYoutubeSyntheticMedia', completedBeforeCancel),
        );
        await tapVisible(submit);
        expect(missing, findsOneWidget);
        expect(requests, 0);
        await tapVisible(
          answer('communityYoutubeMadeForKids', !completedBeforeCancel),
        );
        expect(missing, findsNothing);
        if (!completedBeforeCancel) {
          await tapVisible(
            find.widgetWithText(
              SwitchListTile,
              l10n.communityContainsGenerativeAiImageVideo,
            ),
          );
        }
        await tapVisible(submit);
        final agree = find.text(l10n.communityPostingTermsAgree);
        for (var i = 0; agree.evaluate().isEmpty && i < 30; i++) {
          await pumpRealAsync(tester, const Duration(milliseconds: 40));
        }
        await tester.pump(const Duration(milliseconds: 400));
        expect(requests, 0);
        expect(agree.hitTestable(), findsOneWidget);
        await tester.tap(agree);
        await tester.pump();
        for (var i = 0; !uploadStarted && i < 30; i++) {
          await pumpRealAsync(tester, const Duration(milliseconds: 40));
        }
        expect(uploadStarted, isTrue);

        final cancel = find.byKey(const Key('communityPostCancelUpload'));
        expect(cancel.hitTestable(), findsOneWidget);
        if (completedBeforeCancel) {
          await tester.binding.handlePopRoute();
          await tester.pump(const Duration(milliseconds: 400));
          expect(
            find.text(l10n.communityPostCancelUploadConfirm),
            findsOneWidget,
          );
          await tester.tap(find.text(l10n.communityPostKeepUploading));
          await tester.pump(const Duration(milliseconds: 400));
          expect(abortTriggered, isFalse);

          await tester.tap(find.byType(BackButton));
          await tester.pump(const Duration(milliseconds: 400));
          expect(
            find.text(l10n.communityPostCancelUploadConfirm),
            findsOneWidget,
          );
          success.complete(
            http.StreamedResponse(
              Stream.value('{"id":"test-video"}'.codeUnits),
              200,
            ),
          );
          await pumpRealAsync(tester, const Duration(milliseconds: 300));
          expect(registrations, isEmpty);
          await tester.tap(
            find.widgetWithText(FilledButton, l10n.communityPostCancelUpload),
          );
        } else {
          await tester.tap(cancel);
        }
        for (var i = 0; cancel.evaluate().isNotEmpty && i < 30; i++) {
          await pumpRealAsync(tester, const Duration(milliseconds: 40));
        }
        expect(cancel, findsNothing);
        await tester.pumpAndSettle();
        final prefs = await SharedPreferences.getInstance();
        expect(abortTriggered, isTrue);
        expect(requests, 2);
        expect(registrations, isEmpty);
        expect(
          prefs.getString('community.pendingUpload.videoId'),
          completedBeforeCancel ? 'test-video' : isNull,
        );
        expect(
          find.text(
            completedBeforeCancel
                ? l10n.communityPostStatusRegistrationRetryable
                : l10n.communityPostStatusUploadCancelled,
          ),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('communityPostTitle')))
              .controller!
              .text,
          'My film',
        );
        expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
        if (completedBeforeCancel) {
          await tapVisible(submit);
          await tester.pumpAndSettle();
          // A server error retries POST /works once with the same payload.
          expect(registrations, hasLength(2));
          expect(registrations.first, registrations.last);
          expect(registrations.first['youtubeVideoId'], 'test-video');
          expect(registrations.first['youtubeAccessToken'], 'read-only-token');
          expect(
            registrations.first['containsGenerativeAiImageOrVideo'],
            isFalse,
          );
          expect(requests, 2);
          expect(missing, findsNothing);
          expect(
            prefs.getString('community.pendingUpload.videoId'),
            'test-video',
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
