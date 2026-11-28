import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/community/community_error_text.dart';
import 'package:niarim/screens/community/community_post_screen.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/api/niarim_api_exception.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/youtube_upload_service.dart';
import 'package:niarim/widgets/legal_consent.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/pump_real_async.dart';

/// The day's post limit used to be checked only by POST /works, after the
/// video was already on YouTube: a second post the same day left the video
/// there and offered "Retry" for a registration that could never succeed
/// (found by walking the app against a local copy of the backend,
/// 2026-11-28). The app now asks GET /me/post-quota before uploading, and a
/// refusal that arrives after an upload closes the registration instead. A
/// video refused because it was not uploaded moments before (the server's
/// check against reusing old videos) said "no permission" and was offered for
/// retry too; it closes the registration the same way.
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
    PlatformFile(name: 'film.mp4', path: file.path, size: file.lengthSync()),
  ]);
}

class _Account implements GoogleSignInAccount {
  @override
  String get id => 'poster';

  @override
  String get email => 'poster@example.invalid';

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
  }) async => 'upload-token';

  @override
  Future<String?> youtubeReadAccessToken({
    bool promptIfNecessary = false,
  }) async => 'read-token';
}

const _videoId = 'abcdefghijk';
const _pendingVideoIdKey = 'community.pendingUpload.videoId';

http.Response _json(int status, Map<String, Object?> body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// One posting attempt against fake NIARIM and YouTube servers.
class _Harness {
  _Harness({required this.quota, required this.register});

  /// The answer to GET /me/post-quota.
  final http.Response Function() quota;

  /// The answer to POST /works.
  final http.Response Function() register;

  final niarimCalls = <String>[];
  final youtubeCalls = <String>[];

  late final community = CommunityService(
    api: CommunityApi(
      NiarimApiClient(
        baseUrl: 'https://niarim.invalid',
        maxGetRetries: 0,
        tokenProvider: () async => 'id-token',
        httpClient: MockClient((request) async {
          niarimCalls.add('${request.method} ${request.url.path}');
          return switch (request.url.path) {
            '/me/post-quota' => quota(),
            '/me/works' => _json(200, {'authorId': 'Nposter', 'works': []}),
            '/works' => register(),
            _ => _json(404, {'error': 'no route'}),
          };
        }),
      ),
    ),
  );

  YoutubeUploadService uploader() => YoutubeUploadService(
    httpClient: MockClient((request) async {
      youtubeCalls.add(request.method);
      if (request.method == 'POST') {
        return http.Response(
          '',
          200,
          headers: {'location': 'https://upload.invalid/session'},
        );
      }
      return http.Response('{"id":"$_videoId"}', 200);
    }),
  );

  Widget app() => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => SettingsService()),
      ChangeNotifierProvider<GoogleAuthService>(create: (_) => _Auth()),
      ChangeNotifierProvider.value(value: community),
    ],
    child: MaterialApp(
      locale: const Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: CommunityPostScreen(createUploader: uploader),
    ),
  );
}

final _l10n = lookupAppLocalizations(const Locale('ja'));
final _submit = find.byKey(const Key('communityPostSubmitButton'));
final _discardClosed = find.byKey(
  const Key('communityPostDiscardClosedButton'),
);

Future<void> _open(WidgetTester tester, _Harness harness) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(480, 1500);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(harness.app());
  await pumpRealAsync(tester, const Duration(milliseconds: 100));
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pump();
  await tester.tap(finder.hitTestable());
  await tester.pump();
}

/// Fills the form and presses "Upload to YouTube and post".
Future<void> _post(WidgetTester tester) async {
  final directory = Directory.systemTemp.createTempSync('post_quota_');
  addTearDown(() => directory.deleteSync(recursive: true));
  final file = File('${directory.path}/film.mp4')..writeAsBytesSync([0, 1]);
  FilePicker.platform = _VideoPicker(file);
  for (final field in ['communityPostTitle', 'communityPostYoutubeTitle']) {
    await tester.enterText(find.byKey(Key(field)), 'My film');
  }
  await _tapVisible(tester, find.text(_l10n.communityPostPickVideo));
  for (final group in [
    'communityYoutubeSyntheticMedia',
    'communityYoutubeMadeForKids',
  ]) {
    await _tapVisible(
      tester,
      find.descendant(
        of: find.byKey(Key(group)),
        matching: find.widgetWithText(
          RadioListTile<bool>,
          _l10n.customAutomationNo,
        ),
      ),
    );
  }
  await _tapVisible(tester, _submit);
  await pumpRealAsync(tester, const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
}

Finder _errorText(String message) =>
    find.text(_l10n.communityPostErrorLabel(message));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      kLegalConsentVersionKey: kLegalDocumentsVersion,
    });
  });

  testWidgets('no post left today: nothing is uploaded to YouTube', (
    tester,
  ) async {
    final harness = _Harness(
      quota: () => _json(200, {'limit': 1, 'used': 1, 'remaining': 0}),
      register: () => fail('POST /works must not be called'),
    );
    await _open(tester, harness);
    await _post(tester);

    expect(harness.niarimCalls, ['GET /me/post-quota']);
    expect(harness.youtubeCalls, isEmpty);
    expect(_errorText(_l10n.communityErrorPostQuotaExceeded), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_pendingVideoIdKey), isNull);
    expect(tester.widget<FilledButton>(_submit).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a suspended account is told so before any upload', (
    tester,
  ) async {
    final harness = _Harness(
      quota: () =>
          _json(403, {'error': '投稿を停止しています', 'code': 'POSTING_SUSPENDED'}),
      register: () => fail('POST /works must not be called'),
    );
    await _open(tester, harness);
    await _post(tester);

    expect(harness.youtubeCalls, isEmpty);
    expect(_errorText(_l10n.communityErrorPostingSuspended), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a server without the question still lets POST /works decide', (
    tester,
  ) async {
    final harness = _Harness(
      quota: () => _json(404, {'error': 'no route'}),
      register: () => _json(201, {
        'work': {
          'workId': _videoId,
          'authorId': 'Nposter',
          'title': 'My film',
          'containsGenerativeAiImageOrVideo': false,
          'isNiarimPublished': true,
        },
      }),
    );
    await _open(tester, harness);
    await _post(tester);

    expect(harness.youtubeCalls, ['POST', 'PUT']);
    expect(harness.niarimCalls, contains('POST /works'));
  });

  // Refusals no retry of the same video gets past: the day's limit reached
  // while the video was uploading (another device posted first), and a video
  // no longer just uploaded (the server checks it was uploaded moments ago).
  final closingRefusals = {
    'POST_QUOTA_EXCEEDED': (409, _l10n.communityErrorPostQuotaExceeded),
    'VIDEO_NOT_RECENT': (403, _l10n.communityErrorVideoNotRecent),
  };
  for (final MapEntry(key: code, value: (status, message))
      in closingRefusals.entries) {
    testWidgets('$code after the upload closes the registration, '
        'and cancelling it is the only way on', (tester) async {
      final harness = _Harness(
        quota: () => _json(200, {'limit': 1, 'used': 0, 'remaining': 1}),
        register: () => _json(status, {'error': '登録できません', 'code': code}),
      );
      await _open(tester, harness);
      await _post(tester);

      expect(harness.youtubeCalls, ['POST', 'PUT']);
      expect(
        harness.niarimCalls.where((call) => call == 'POST /works'),
        hasLength(1),
      );
      expect(
        find.text(_l10n.communityPostStatusRegistrationClosed),
        findsOneWidget,
      );
      expect(_errorText(message), findsOneWidget);
      // No retry: the bar's only button cancels the registration, and the
      // card no longer promises a retry without a re-upload.
      expect(_submit, findsNothing);
      expect(find.text(_l10n.communityPostSubmitRetry), findsNothing);
      expect(find.textContaining(_l10n.communityPostNoReupload), findsNothing);
      expect(_discardClosed.hitTestable(), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_pendingVideoIdKey), _videoId);

      // Opened again later, the screen is in the same state.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(harness.app());
      await pumpRealAsync(tester, const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(
        find.text(_l10n.communityPostStatusRegistrationClosed),
        findsOneWidget,
      );
      expect(_submit, findsNothing);

      await tester.tap(_discardClosed);
      await tester.pumpAndSettle();
      expect(find.text(_l10n.communityPostDiscardPendingConfirm), findsOne);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(
            FilledButton,
            _l10n.communityPostDiscardPending,
          ),
        ),
      );
      await pumpRealAsync(tester, const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(prefs.getString(_pendingVideoIdKey), isNull);
      expect(prefs.getString('community.pendingUpload.closedReason'), isNull);
      expect(_discardClosed, findsNothing);
      expect(tester.widget<FilledButton>(_submit).onPressed, isNotNull);
      expect(find.text(_l10n.communityPostSubmitUpload), findsOneWidget);
      expect(
        harness.niarimCalls.where((call) => call == 'POST /works'),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    });
  }

  // The age refusal has a message of its own in every language, instead of
  // "You don't have permission to do this" for a 403.
  for (final locale in AppLocalizations.supportedLocales) {
    test('VIDEO_NOT_RECENT is explained (${locale.toLanguageTag()})', () {
      final l10n = lookupAppLocalizations(locale);
      const error = NiarimApiException(
        403,
        '投稿直後の動画ではないため登録できません',
        code: 'VIDEO_NOT_RECENT',
      );
      expect(
        communityErrorText(l10n, error),
        l10n.communityErrorVideoNotRecent,
      );
      expect(
        l10n.communityErrorVideoNotRecent,
        isNot(l10n.communityErrorForbidden),
      );
    });
  }
}
