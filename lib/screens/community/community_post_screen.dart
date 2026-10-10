import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../../services/api/niarim_api_exception.dart';
import '../../services/community_service.dart';
import '../../services/google_auth_service.dart';
import '../../services/youtube_upload_service.dart';
import '../../widgets/responsive.dart';
import 'community_error_text.dart';
import '../../utils/tolerant_preferences.dart';

/// Where posting stands, shown under the form.
enum _PostStatus {
  pendingRestored,
  pendingVideoUnavailable,
  recovered,
  completed,
  checkingAccount,
  checkingRegistration,
  syncingAiFlag,
  syncingVisibility,
  uploading,
  registering,
  uploadFailed,
  registrationRetryable,
}

enum _PostFailureKind {
  noVideo,
  noTitle,
  googleNotConfigured,
  serverNotConfigured,
  googleAccountBusy,
  pendingVideoUnavailable,
  uploadedByOtherAccount,
  accountChanged,
  youtubePermissionDenied,
  noVideoId,
}

/// A posting failure this screen detects itself; [email] names the Google
/// account involved, when there is one.
class _PostFailure implements Exception {
  const _PostFailure(this.kind) : email = null;

  /// The pending video belongs to another account ([email], when known).
  const _PostFailure.uploadedByOtherAccount(this.email)
    : kind = _PostFailureKind.uploadedByOtherAccount;

  /// The signed-in account changed midway; [email] is the one to go back to.
  const _PostFailure.accountChanged(String this.email)
    : kind = _PostFailureKind.accountChanged;

  final _PostFailureKind kind;
  final String? email;

  @override
  String toString() => '_PostFailure($kind)';
}

/// YouTubeへ動画を実アップロードし、返却されたvideoIdをNIARIMのworkIdとして
/// 登録する。YouTubeアップロード成功後はvideoIdとアップロード元Google
/// アカウントを永続保持し、NIARIM登録失敗・画面終了・アプリ終了後も動画を
/// 再アップロードせずPOST /worksだけを再試行する。
class CommunityPostScreen extends StatefulWidget {
  const CommunityPostScreen({super.key});

  @override
  State<CommunityPostScreen> createState() => _CommunityPostScreenState();
}

class _CommunityPostScreenState extends State<CommunityPostScreen> {
  static const _pendingVideoIdKey = 'community.pendingUpload.videoId';
  static const _pendingAccountIdKey = 'community.pendingUpload.googleAccountId';
  static const _pendingAccountEmailKey =
      'community.pendingUpload.googleAccountEmail';
  static const _pendingTitleKey = 'community.pendingUpload.title';
  static const _pendingIsShortKey = 'community.pendingUpload.isShort';
  static const _pendingPublishedKey =
      'community.pendingUpload.isNiarimPublished';
  static const _pendingAiImageVideoKey =
      'community.pendingUpload.containsGenerativeAiImageOrVideo';

  final _titleController = TextEditingController();
  File? _videoFile;
  String? _youtubeVideoId;
  String? _uploadAccountId;
  String? _uploadAccountEmail;
  bool _isShort = false;
  bool _isNiarimPublished = true;
  bool _containsGenerativeAiImageOrVideo = false;
  bool _busy = false;
  bool _restoringPending = true;
  double _progress = 0;
  _PostStatus? _status;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _restorePendingUpload();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _restorePendingUpload() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final videoId = prefs.readString(_pendingVideoIdKey);
      if (!mounted) return;
      if (videoId != null && videoId.isNotEmpty) {
        setState(() {
          _youtubeVideoId = videoId;
          _uploadAccountId = prefs.readString(_pendingAccountIdKey);
          _uploadAccountEmail = prefs.readString(_pendingAccountEmailKey);
          _isShort = prefs.readBool(_pendingIsShortKey) ?? false;
          _isNiarimPublished = prefs.readBool(_pendingPublishedKey) ?? true;
          _containsGenerativeAiImageOrVideo =
              prefs.readBool(_pendingAiImageVideoKey) ?? false;
          _titleController.text = prefs.readString(_pendingTitleKey) ?? '';
          _status = _PostStatus.pendingRestored;
        });
      }
    } finally {
      if (mounted) setState(() => _restoringPending = false);
    }
  }

  Future<void> _persistPendingUpload({
    required String videoId,
    required String accountId,
    required String accountEmail,
    required String title,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingVideoIdKey, videoId);
    await prefs.setString(_pendingAccountIdKey, accountId);
    await prefs.setString(_pendingAccountEmailKey, accountEmail);
    await prefs.setString(_pendingTitleKey, title);
    await prefs.setBool(_pendingIsShortKey, _isShort);
    await prefs.setBool(_pendingPublishedKey, _isNiarimPublished);
    await prefs.setBool(
      _pendingAiImageVideoKey,
      _containsGenerativeAiImageOrVideo,
    );
  }

  Future<void> _clearPendingUpload() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait<bool>([
      prefs.remove(_pendingVideoIdKey),
      prefs.remove(_pendingAccountIdKey),
      prefs.remove(_pendingAccountEmailKey),
      prefs.remove(_pendingTitleKey),
      prefs.remove(_pendingIsShortKey),
      prefs.remove(_pendingPublishedKey),
      prefs.remove(_pendingAiImageVideoKey),
    ]);
  }

  /// 保留中のvideoIdがYouTubeから削除済み／取得不能と確定した場合は、
  /// 「再試行可能」状態を永続化したままにしない。タイトル等の入力値は画面に
  /// 残し、新しい動画を選び直せる状態へ戻す。
  Future<void> _markPendingVideoUnavailable() async {
    await _clearPendingUpload();
    if (!mounted) return;
    setState(() {
      _youtubeVideoId = null;
      _uploadAccountId = null;
      _uploadAccountEmail = null;
      _videoFile = null;
      _progress = 0;
      _status = _PostStatus.pendingVideoUnavailable;
      _error = const _PostFailure(_PostFailureKind.pendingVideoUnavailable);
    });
  }

  Future<void> _discardPendingUpload() async {
    if (_busy) return;
    await _clearPendingUpload();
    if (!mounted) return;
    setState(() {
      _youtubeVideoId = null;
      _uploadAccountId = null;
      _uploadAccountEmail = null;
      _videoFile = null;
      _titleController.clear();
      _isShort = false;
      _isNiarimPublished = true;
      _containsGenerativeAiImageOrVideo = false;
      _status = null;
      _error = null;
      _progress = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.communityPostPendingDiscarded,
        ),
      ),
    );
  }

  Future<void> _pickVideo() async {
    if (_busy || _youtubeVideoId != null) return;
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    final path = result?.files.single.path;
    if (path == null || path.isEmpty) return;
    setState(() {
      _videoFile = File(path);
      _error = null;
      if (_titleController.text.trim().isEmpty) {
        final name = result!.files.single.name;
        final dot = name.lastIndexOf('.');
        _titleController.text = dot > 0 ? name.substring(0, dot) : name;
      }
    });
  }

  Future<void> _finishRegistration(
    CommunityService community,
    String registeredVideoId, {
    bool recovered = false,
  }) async {
    await _clearPendingUpload();
    await community.refreshFromBackend();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    setState(
      () => _status = recovered ? _PostStatus.recovered : _PostStatus.completed,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          recovered
              ? l10n.communityPostRecoveredSnackbar(registeredVideoId)
              : l10n.communityPostDoneSnackbar(registeredVideoId),
        ),
      ),
    );
    Navigator.of(context).pop(registeredVideoId);
  }

  Future<void> _submit() async {
    if (_busy || _restoringPending) return;
    final file = _videoFile;
    final title = _titleController.text.trim();
    if (_youtubeVideoId == null && file == null) {
      setState(() => _error = const _PostFailure(_PostFailureKind.noVideo));
      return;
    }
    if (title.isEmpty) {
      setState(() => _error = const _PostFailure(_PostFailureKind.noTitle));
      return;
    }

    final auth = context.read<GoogleAuthService>();
    final community = context.read<CommunityService>();
    final api = community.api;
    if (!auth.isConfigured) {
      setState(
        () => _error = const _PostFailure(_PostFailureKind.googleNotConfigured),
      );
      return;
    }
    if (api == null) {
      setState(
        () => _error = const _PostFailure(_PostFailureKind.serverNotConfigured),
      );
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _status = _youtubeVideoId == null
          ? _PostStatus.checkingAccount
          : _PostStatus.checkingRegistration;
    });

    try {
      var postingAccount = auth.account;
      postingAccount ??= await auth.signInInteractively();

      final retainedAccountId = _uploadAccountId;
      if (_youtubeVideoId != null &&
          retainedAccountId != null &&
          retainedAccountId.isNotEmpty &&
          retainedAccountId != postingAccount.id) {
        throw _PostFailure.uploadedByOtherAccount(_uploadAccountEmail);
      }

      var videoId = _youtubeVideoId;
      var uploadAccountId = _uploadAccountId ?? postingAccount.id;
      var uploadAccountEmail = _uploadAccountEmail ?? postingAccount.email;

      // YouTubeアップロード後にPOST /worksが成功したものの、その成功応答を
      // 受け取る前にアプリが終了したケースを先に復旧する。ここではYouTubeの
      // upload scopeを要求しないので、既に登録済みなら不要な再認可を出さない。
      if (videoId != null) {
        final ownWorks = await api.myWorks();
        community.setCurrentUserId(ownWorks.authorId);
        if (auth.account?.id != uploadAccountId) {
          throw _PostFailure.accountChanged(uploadAccountEmail);
        }
        for (final work in ownWorks.works) {
          if (work.workId != videoId) continue;
          // 既にNIARIM登録済みでも、同期バッチがYouTube削除を検知している
          // 場合は復旧扱いにしない。削除済み動画は公開状態をPATCHしても
          // 復活しないため、保留情報を破棄して新しい動画の選択へ戻す。
          if (work.youtubePrivacyStatus == 'deleted') {
            await _markPendingVideoUnavailable();
            return;
          }
          if (work.containsGenerativeAiImageOrVideo !=
              _containsGenerativeAiImageOrVideo) {
            setState(() => _status = _PostStatus.syncingAiFlag);
            await api.updateWorkAiImageVideoDisclosure(
              videoId,
              containsGenerativeAiImageOrVideo:
                  _containsGenerativeAiImageOrVideo,
            );
          }
          if (work.isNiarimPublished != _isNiarimPublished) {
            setState(() => _status = _PostStatus.syncingVisibility);
            await api.updateWorkVisibility(
              videoId,
              isNiarimPublished: _isNiarimPublished,
            );
          }
          await _finishRegistration(community, videoId, recovered: true);
          return;
        }
      }

      // ここへ来るのは新規YouTubeアップロード、またはYouTubeには存在するが
      // NIARIM未登録の保留投稿だけ。初めてここでyoutube.upload scopeを要求する。
      final youtubeToken = await auth.youtubeUploadAccessToken(
        promptIfNecessary: true,
      );
      if (youtubeToken == null || youtubeToken.isEmpty) {
        throw const _PostFailure(_PostFailureKind.youtubePermissionDenied);
      }
      if (auth.account?.id != uploadAccountId) {
        throw _PostFailure.accountChanged(uploadAccountEmail);
      }

      if (videoId == null) {
        if (!mounted) return;
        setState(() {
          _status = _PostStatus.uploading;
          _progress = 0;
        });
        final uploader = YoutubeUploadService();
        try {
          final result = await uploader.uploadVideo(
            file: file!,
            accessToken: youtubeToken,
            title: title,
            privacyStatus: 'unlisted',
            onProgress: (sent, total) {
              if (!mounted || total <= 0) return;
              setState(() => _progress = sent / total);
            },
          );
          videoId = result.videoId;
          uploadAccountId = postingAccount.id;
          uploadAccountEmail = postingAccount.email;

          // Stateより先に永続化し、アップロード完了直後の強制終了でも
          // 同じvideoIdからNIARIM登録だけを復旧できるようにする。
          await _persistPendingUpload(
            videoId: result.videoId,
            accountId: uploadAccountId,
            accountEmail: uploadAccountEmail,
            title: title,
          );
          if (!mounted) return;
          setState(() {
            _youtubeVideoId = result.videoId;
            _uploadAccountId = uploadAccountId;
            _uploadAccountEmail = uploadAccountEmail;
            _progress = 1;
            _status = _PostStatus.registering;
          });
        } finally {
          uploader.close();
        }
      }

      final registeredVideoId = videoId;
      if (registeredVideoId.isEmpty) {
        throw const _PostFailure(_PostFailureKind.noVideoId);
      }

      // 外部認証イベント等でアカウントが変わった場合、YouTube tokenと
      // NIARIM ID tokenを別アカウントで混在させずPOST前に止める。
      if (auth.account?.id != uploadAccountId) {
        throw _PostFailure.accountChanged(uploadAccountEmail);
      }

      final registeredWork = await api.createWork(
        youtubeVideoId: registeredVideoId,
        youtubeAccessToken: youtubeToken,
        isShort: _isShort,
        isNiarimPublished: _isNiarimPublished,
        containsGenerativeAiImageOrVideo: _containsGenerativeAiImageOrVideo,
      );

      // POST /works is idempotent: a work registered by an earlier attempt
      // comes back with its stored settings, not the ones chosen now.
      final syncAi =
          registeredWork.containsGenerativeAiImageOrVideo !=
          _containsGenerativeAiImageOrVideo;
      final syncVisibility =
          registeredWork.isNiarimPublished != _isNiarimPublished;
      if ((syncAi || syncVisibility) && auth.account?.id != uploadAccountId) {
        throw _PostFailure.accountChanged(uploadAccountEmail);
      }
      if (syncAi) {
        await api.updateWorkAiImageVideoDisclosure(
          registeredVideoId,
          containsGenerativeAiImageOrVideo: _containsGenerativeAiImageOrVideo,
        );
      }
      if (syncVisibility) {
        await api.updateWorkVisibility(
          registeredVideoId,
          isNiarimPublished: _isNiarimPublished,
        );
      }

      await _finishRegistration(community, registeredVideoId);
    } catch (error) {
      // 未登録の保留動画がYouTubeから消されている場合、バックエンドは
      // VIDEO_NOT_FOUNDを返す。この状態は時間や再認証では直らないため、
      // 「再試行できます」と表示し続けず、保留情報を破棄して終了する。
      if (error is NiarimApiException && error.code == 'VIDEO_NOT_FOUND') {
        await _markPendingVideoUnavailable();
        return;
      }
      debugPrint('Community post failed: $error');
      // A Google operation already running (e.g. an account switch started
      // elsewhere) refuses this one; say so instead of a generic failure.
      final failure = error is! _PostFailure && auth.authOperationInProgress
          ? const _PostFailure(_PostFailureKind.googleAccountBusy)
          : error;
      if (!mounted) return;
      setState(() {
        _error = failure;
        _status = _youtubeVideoId == null
            ? _PostStatus.uploadFailed
            : _PostStatus.registrationRetryable;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _statusText(AppLocalizations l10n, _PostStatus status) =>
      switch (status) {
        _PostStatus.pendingRestored => l10n.communityPostStatusPendingRestored,
        _PostStatus.pendingVideoUnavailable =>
          l10n.communityPostStatusPendingUnavailable,
        _PostStatus.recovered => l10n.communityPostStatusRecovered,
        _PostStatus.completed => l10n.communityPostStatusCompleted,
        _PostStatus.checkingAccount => l10n.communityPostStatusCheckingAccount,
        _PostStatus.checkingRegistration =>
          l10n.communityPostStatusCheckingRegistration,
        _PostStatus.syncingAiFlag => l10n.communityPostStatusSyncingAiFlag,
        _PostStatus.syncingVisibility =>
          l10n.communityPostStatusSyncingVisibility,
        _PostStatus.uploading => l10n.communityPostStatusUploading,
        _PostStatus.registering => l10n.communityPostStatusRegistering,
        _PostStatus.uploadFailed => l10n.communityPostStatusUploadFailed,
        _PostStatus.registrationRetryable =>
          l10n.communityPostStatusRegistrationRetryable,
      };

  String _errorText(AppLocalizations l10n, Object error) {
    if (error is! _PostFailure) return communityErrorText(l10n, error);
    return switch (error.kind) {
      _PostFailureKind.noVideo => l10n.communityPostErrorNoVideo,
      _PostFailureKind.noTitle => l10n.communityPostErrorNoTitle,
      _PostFailureKind.googleNotConfigured =>
        l10n.communityGoogleSignInNotConfigured,
      _PostFailureKind.serverNotConfigured =>
        l10n.communityPostErrorServerNotConfigured,
      _PostFailureKind.googleAccountBusy => l10n.communityGoogleAccountBusy,
      _PostFailureKind.pendingVideoUnavailable =>
        l10n.communityPostErrorPendingVideoUnavailable,
      _PostFailureKind.uploadedByOtherAccount => switch (error.email) {
        final email? => l10n.communityPostErrorUploadedByAccount(email),
        null => l10n.communityPostErrorUploadedByAnotherAccount,
      },
      _PostFailureKind.accountChanged => l10n.communityPostErrorAccountChanged(
        error.email!,
      ),
      _PostFailureKind.youtubePermissionDenied =>
        l10n.communityPostErrorYoutubePermission,
      _PostFailureKind.noVideoId => l10n.communityPostErrorNoVideoId,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final retainedVideoId = _youtubeVideoId;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.communityPostButton)),
        body: desktopCentered(
          context,
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _titleController,
                  enabled: !_busy && retainedVideoId == null,
                  maxLength: 100,
                  decoration: InputDecoration(
                    labelText: l10n.communityPostTitleLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy || retainedVideoId != null
                      ? null
                      : _pickVideo,
                  icon: const Icon(Icons.video_file_outlined),
                  label: Text(
                    _videoFile == null
                        ? l10n.communityPostPickVideo
                        : _videoFile!.path.split(Platform.pathSeparator).last,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isShort,
                  onChanged: _busy || retainedVideoId != null
                      ? null
                      : (value) => setState(() => _isShort = value),
                  title: Text(l10n.communityPostAsShort),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _containsGenerativeAiImageOrVideo,
                  onChanged: _busy
                      ? null
                      : (value) async {
                          setState(
                            () => _containsGenerativeAiImageOrVideo = value,
                          );
                          if (retainedVideoId != null) {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool(_pendingAiImageVideoKey, value);
                          }
                        },
                  title: Text(l10n.communityContainsGenerativeAiImageVideo),
                  subtitle: Text(
                    l10n.communityContainsGenerativeAiImageVideoHelp,
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isNiarimPublished,
                  onChanged: _busy
                      ? null
                      : (value) async {
                          setState(() => _isNiarimPublished = value);
                          if (retainedVideoId != null) {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool(_pendingPublishedKey, value);
                          }
                        },
                  title: Text(l10n.communityPostShowInPlaza),
                  subtitle: Text(l10n.communityPostShowInPlazaHelp),
                ),
                if (retainedVideoId != null) ...[
                  const SizedBox(height: 8),
                  Card(
                    color: scheme.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.cloud_done_outlined,
                                color: scheme.onSecondaryContainer,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  [
                                    l10n.communityPostUploadedHeading,
                                    l10n.communityYoutubeVideoIdLabel(
                                      retainedVideoId,
                                    ),
                                    if (_uploadAccountEmail case final email?)
                                      l10n.communityPostUploadedAccount(email),
                                    l10n.communityPostNoReupload,
                                  ].join('\n'),
                                  style: TextStyle(
                                    color: scheme.onSecondaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _busy ? null : _discardPendingUpload,
                              child: Text(l10n.communityPostDiscardPending),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_busy && retainedVideoId == null) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                  ),
                ],
                if (_restoringPending) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
                if (_status != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _statusText(l10n, _status!),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.communityPostErrorLabel(_errorText(l10n, _error!)),
                    style: TextStyle(color: scheme.error),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: const Key('communityPostSubmitButton'),
                  onPressed: _busy || _restoringPending ? null : _submit,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          retainedVideoId == null
                              ? Icons.cloud_upload_outlined
                              : Icons.refresh,
                        ),
                  label: Text(
                    retainedVideoId == null
                        ? l10n.communityPostSubmitUpload
                        : l10n.communityPostSubmitRetry,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
