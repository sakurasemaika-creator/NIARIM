import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../services/api/niarim_api_exception.dart';
import '../../services/community_service.dart';
import '../../services/google_auth_service.dart';
import '../../services/youtube_upload_service.dart';
import '../../services/youtube_thumbnail_service.dart';
import '../../services/post_completion_notification_service.dart';
import '../../l10n/community_work_metadata_labels.dart';
import '../../l10n/community_post_visibility_labels.dart';
import 'widgets/community_post_copy_button.dart';
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
  noYoutubeTitle,
  invalidYoutubeDescription,
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
  static const _pendingThumbnailPathKey =
      'community.pendingUpload.thumbnailPath';
  static const _pendingThumbnailAppliedKey =
      'community.pendingUpload.thumbnailApplied';
  static const _pendingScheduledPublishAtKey =
      'community.pendingUpload.scheduledPublishAt';
  static const _frameChannel = MethodChannel('com.niarim.niarim/video_frame');
  static const _pendingAccountIdKey = 'community.pendingUpload.googleAccountId';
  static const _pendingAccountEmailKey =
      'community.pendingUpload.googleAccountEmail';
  static const _pendingTitleKey = 'community.pendingUpload.title';
  static const _pendingYoutubeTitleKey = 'community.pendingUpload.youtubeTitle';
  static const _pendingDescriptionKey = 'community.pendingUpload.description';
  static const _pendingYoutubeDescriptionKey =
      'community.pendingUpload.youtubeDescription';
  static const _pendingYoutubePrivacyKey =
      'community.pendingUpload.youtubePrivacyStatus';
  static const _pendingIsShortKey = 'community.pendingUpload.isShort';
  static const _pendingPublishedKey =
      'community.pendingUpload.isNiarimPublished';
  static const _pendingAiImageVideoKey =
      'community.pendingUpload.containsGenerativeAiImageOrVideo';

  final _titleController = TextEditingController();
  final _youtubeTitleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _youtubeDescriptionController = TextEditingController();
  File? _videoFile;
  File? _thumbnailFile;
  bool _thumbnailApplied = false;
  DateTime? _scheduledPublishAt;
  String? _youtubeVideoId;
  String? _uploadAccountId;
  String? _uploadAccountEmail;
  bool _isShort = false;
  String _youtubePrivacyStatus = 'unlisted';
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
    _youtubeTitleController.dispose();
    _descriptionController.dispose();
    _youtubeDescriptionController.dispose();
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
          _youtubePrivacyStatus =
              prefs.readString(_pendingYoutubePrivacyKey) ?? 'unlisted';
          final thumbPath = prefs.readString(_pendingThumbnailPathKey);
          _thumbnailFile = thumbPath == null || thumbPath.isEmpty
              ? null
              : File(thumbPath);
          _thumbnailApplied =
              prefs.readBool(_pendingThumbnailAppliedKey) ?? false;
          final scheduled = prefs.readString(_pendingScheduledPublishAtKey);
          _scheduledPublishAt = scheduled == null
              ? null
              : DateTime.tryParse(scheduled);
          _isNiarimPublished = prefs.readBool(_pendingPublishedKey) ?? true;
          _containsGenerativeAiImageOrVideo =
              prefs.readBool(_pendingAiImageVideoKey) ?? false;
          _titleController.text = prefs.readString(_pendingTitleKey) ?? '';
          _youtubeTitleController.text =
              prefs.readString(_pendingYoutubeTitleKey) ??
              _titleController.text;
          _descriptionController.text =
              prefs.readString(_pendingDescriptionKey) ?? '';
          _youtubeDescriptionController.text =
              prefs.readString(_pendingYoutubeDescriptionKey) ?? '';
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
    await prefs.setString(_pendingThumbnailPathKey, _thumbnailFile?.path ?? '');
    await prefs.setBool(_pendingThumbnailAppliedKey, _thumbnailApplied);
    if (_scheduledPublishAt != null) {
      await prefs.setString(
        _pendingScheduledPublishAtKey,
        _scheduledPublishAt!.toUtc().toIso8601String(),
      );
    } else {
      await prefs.remove(_pendingScheduledPublishAtKey);
    }
    await prefs.setString(_pendingAccountIdKey, accountId);
    await prefs.setString(_pendingAccountEmailKey, accountEmail);
    await prefs.setString(_pendingTitleKey, title);
    await prefs.setString(
      _pendingYoutubeTitleKey,
      _youtubeTitleController.text.trim(),
    );
    await prefs.setString(
      _pendingDescriptionKey,
      _descriptionController.text.trim(),
    );
    await prefs.setString(
      _pendingYoutubeDescriptionKey,
      _youtubeDescriptionController.text.trim(),
    );
    await prefs.setBool(_pendingIsShortKey, _isShort);
    await prefs.setString(_pendingYoutubePrivacyKey, _youtubePrivacyStatus);
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
      prefs.remove(_pendingThumbnailPathKey),
      prefs.remove(_pendingThumbnailAppliedKey),
      prefs.remove(_pendingScheduledPublishAtKey),
      prefs.remove(_pendingAccountIdKey),
      prefs.remove(_pendingAccountEmailKey),
      prefs.remove(_pendingTitleKey),
      prefs.remove(_pendingYoutubeTitleKey),
      prefs.remove(_pendingDescriptionKey),
      prefs.remove(_pendingYoutubeDescriptionKey),
      prefs.remove(_pendingIsShortKey),
      prefs.remove(_pendingYoutubePrivacyKey),
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
      _thumbnailFile = null;
      _thumbnailApplied = false;
      _scheduledPublishAt = null;
      _titleController.clear();
      _youtubeTitleController.clear();
      _descriptionController.clear();
      _youtubeDescriptionController.clear();
      _isShort = false;
      _youtubePrivacyStatus = 'unlisted';
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
      final name = result!.files.single.name;
      final dot = name.lastIndexOf('.');
      final suggestedTitle = dot > 0 ? name.substring(0, dot) : name;
      if (_titleController.text.trim().isEmpty) {
        _titleController.text = suggestedTitle;
      }
      if (_youtubeTitleController.text.trim().isEmpty) {
        _youtubeTitleController.text = suggestedTitle;
      }
    });
  }

  Future<void> _storeThumbnail(File source) async {
    if (_busy || _thumbnailApplied) return;
    final lower = source.path.toLowerCase();
    if (!lower.endsWith('.png') &&
        !lower.endsWith('.jpg') &&
        !lower.endsWith('.jpeg')) {
      throw ArgumentError('PNGまたはJPEGの画像を指定してください');
    }
    final length = await source.length();
    if (length == 0 || length > 10 * 1024 * 1024) {
      throw ArgumentError('サムネイル画像は10MB以内にしてください');
    }
    final base = await getApplicationSupportDirectory();
    final directory = Directory('${base.path}/post_thumbnails');
    await directory.create(recursive: true);
    final ext = lower.endsWith('.png') ? '.png' : '.jpg';
    final copy = await source.copy(
      '${directory.path}/${DateTime.now().microsecondsSinceEpoch}$ext',
    );
    if (!mounted) return;
    setState(() {
      _thumbnailFile = copy;
      _thumbnailApplied = false;
    });
    if (_youtubeVideoId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingThumbnailPathKey, copy.path);
      await prefs.setBool(_pendingThumbnailAppliedKey, false);
    }
  }

  Future<void> _pickThumbnail() async {
    if (_busy || _thumbnailApplied) return;
    final choice = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
    );
    if (choice?.files.single.path case final String path) {
      try {
        await _storeThumbnail(File(path));
      } on Object catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('画像を選択できませんでした: $error')));
        }
      }
    }
  }

  Future<void> _pickVideoFrame() async {
    final video = _videoFile;
    if (video == null || _busy || _thumbnailApplied) return;
    try {
      final lengthMs = await _frameChannel.invokeMethod<int>(
        'getVideoDuration',
        {'path': video.path},
      );
      if (!mounted) return;
      if (lengthMs == null || lengthMs < 1) {
        throw StateError('動画の再生時間が取得できません');
      }
      final duration = lengthMs / 1000.0;
      var selectedSeconds = 0.0;
      final result = await showDialog<double>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, update) => AlertDialog(
            title: const Text('サムネイルにするフレームを選択'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${selectedSeconds.toStringAsFixed(1)} / '
                  '${duration.toStringAsFixed(1)} 秒',
                ),
                Slider(
                  key: const Key('communityPostFrameSlider'),
                  min: 0,
                  max: duration,
                  value: selectedSeconds.clamp(0.0, duration),
                  onChanged: (v) => update(() => selectedSeconds = v),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, selectedSeconds),
                child: const Text('このフレームを使う'),
              ),
            ],
          ),
        ),
      );
      if (result == null) return;
      final path = await _frameChannel.invokeMethod<String>('extractFrame', {
        'path': video.path,
        'timeMs': (result * 1000).round(),
      });
      if (path == null || path.isEmpty) {
        throw StateError('動画フレームを取得できません');
      }
      await _storeThumbnail(File(path));
    } on MissingPluginException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('この環境はフレーム抽出に非対応です。画像を選択してください。')),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('フレーム取得に失敗しました: $error')));
      }
    }
  }

  Future<void> _pickSchedule() async {
    if (_busy || _youtubeVideoId != null) return;
    final now = DateTime.now();
    final initial =
        _scheduledPublishAt?.toLocal() ?? now.add(const Duration(hours: 1));
    final day = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (!mounted || day == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted || time == null) return;
    final chosen = DateTime(
      day.year,
      day.month,
      day.day,
      time.hour,
      time.minute,
    );
    if (!chosen.isAfter(DateTime.now().add(const Duration(minutes: 2)))) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('現在時刻から2分以上先の日時を指定してください')));
      return;
    }
    setState(() {
      _youtubePrivacyStatus = 'scheduled';
      _scheduledPublishAt = chosen;
    });
  }

  Future<void> _finishRegistration(
    CommunityService community,
    String registeredVideoId, {
    bool recovered = false,
  }) async {
    // The POST /works response already confirmed success. Never let a
    // secondary feed refresh suppress the completion notification or turn
    // the successful registration into a misleading retryable failure.
    await _clearPendingUpload();
    await PostCompletionNotificationService.notifySuccess(
      workId: registeredVideoId,
      title: _titleController.text.trim(),
      scheduled: _scheduledPublishAt != null,
    );
    try {
      await community.refreshFromBackend();
    } on Object catch (error) {
      debugPrint('Community refresh after successful post failed: $error');
    }
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
    final youtubeTitle = _youtubeTitleController.text.trim();
    final description = _descriptionController.text.trim();
    final youtubeDescription = _youtubeDescriptionController.text.trim();
    if (_youtubeVideoId == null &&
        _youtubePrivacyStatus == 'scheduled' &&
        (_scheduledPublishAt == null ||
            !_scheduledPublishAt!.isAfter(
              DateTime.now().add(const Duration(minutes: 2)),
            ))) {
      setState(() => _error = StateError('有効な未来の公開日時を指定してください'));
      return;
    }
    if (_youtubeVideoId == null && file == null) {
      setState(() => _error = const _PostFailure(_PostFailureKind.noVideo));
      return;
    }
    if (title.isEmpty) {
      setState(() => _error = const _PostFailure(_PostFailureKind.noTitle));
      return;
    }
    if (youtubeTitle.isEmpty) {
      setState(
        () => _error = const _PostFailure(_PostFailureKind.noYoutubeTitle),
      );
      return;
    }
    if (utf8.encode(youtubeDescription).length > 5000 ||
        youtubeDescription.contains('<') ||
        youtubeDescription.contains('>')) {
      setState(
        () => _error = const _PostFailure(
          _PostFailureKind.invalidYoutubeDescription,
        ),
      );
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
        if (auth.account?.id != uploadAccountId) {
          throw _PostFailure.accountChanged(uploadAccountEmail);
        }
        community.setCurrentUserId(ownWorks.authorId);
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
            title: youtubeTitle,
            description: youtubeDescription,
            privacyStatus: _youtubePrivacyStatus == 'scheduled'
                ? 'private'
                : _youtubePrivacyStatus,
            scheduledPublishAt: _youtubePrivacyStatus == 'scheduled'
                ? _scheduledPublishAt
                : null,
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

      // Set the custom thumbnail before registering the NIARIM metadata.
      // The YouTube video ID is already durable: a failure here must not
      // re-upload the original movie on the next attempt.
      if (_thumbnailFile != null && !_thumbnailApplied) {
        final thumbnail = YoutubeThumbnailService();
        try {
          // YouTube can acknowledge an upload before Shorts have finished
          // processing. Wait for the owned video's processing status first;
          // otherwise thumbnails.set may succeed without being applied.
          if (_isShort) {
            await thumbnail.waitUntilProcessed(
              videoId: registeredVideoId,
              accessToken: youtubeToken,
            );
          }
          await thumbnail.setThumbnail(
            file: _thumbnailFile!,
            videoId: registeredVideoId,
            accessToken: youtubeToken,
          );
          _thumbnailApplied = true;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_pendingThumbnailAppliedKey, true);
        } finally {
          thumbnail.close();
        }
      }

      // 外部認証イベント等でアカウントが変わった場合、YouTube tokenと
      // NIARIM ID tokenを別アカウントで混在させずPOST前に止める。
      if (auth.account?.id != uploadAccountId) {
        throw _PostFailure.accountChanged(uploadAccountEmail);
      }

      final registeredWork = await api.createWork(
        youtubeVideoId: registeredVideoId,
        youtubeAccessToken: youtubeToken,
        title: title,
        description: description,
        isShort: _isShort,
        scheduledPublishAt: _youtubePrivacyStatus == 'scheduled'
            ? _scheduledPublishAt
            : null,
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
      _PostFailureKind.noYoutubeTitle => CommunityWorkMetadataLabels.of(
        context,
      ).youtubeTitleRequired,
      _PostFailureKind.invalidYoutubeDescription =>
        CommunityWorkMetadataLabels.of(context).youtubeDescriptionInvalid,
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

  void _showCopyError(CommunityFieldCopyError error, int maxLength) {
    if (!mounted) return;
    final labels = CommunityWorkMetadataLabels.of(context);
    final message = error == CommunityFieldCopyError.invalidYoutubeDescription
        ? labels.youtubeDescriptionInvalid
        : labels.copyTooLong(maxLength);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
                  key: const Key('communityPostTitle'),
                  controller: _titleController,
                  enabled: !_busy && retainedVideoId == null,
                  maxLength: 100,
                  decoration: InputDecoration(
                    labelText: l10n.communityPostTitleLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                CommunityPostCopyButton(
                  key: const Key('copyNiarimTitleToYoutube'),
                  source: _titleController,
                  destination: _youtubeTitleController,
                  enabled:
                      !_busy && !_restoringPending && retainedVideoId == null,
                  maxLength: 100,
                  label: CommunityWorkMetadataLabels.of(
                    context,
                  ).copyTitleToYoutube,
                  onError: _showCopyError,
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('communityPostYoutubeTitle'),
                  controller: _youtubeTitleController,
                  enabled: !_busy && retainedVideoId == null,
                  maxLength: 100,
                  decoration: InputDecoration(
                    labelText: CommunityWorkMetadataLabels.of(
                      context,
                    ).youtubeTitle,
                    border: const OutlineInputBorder(),
                  ),
                ),
                CommunityPostCopyButton(
                  key: const Key('copyYoutubeTitleToNiarim'),
                  source: _youtubeTitleController,
                  destination: _titleController,
                  enabled:
                      !_busy && !_restoringPending && retainedVideoId == null,
                  maxLength: 100,
                  label: CommunityWorkMetadataLabels.of(
                    context,
                  ).copyTitleToNiarim,
                  onError: _showCopyError,
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('communityPostDescription'),
                  controller: _descriptionController,
                  enabled: !_busy && retainedVideoId == null,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 2000,
                  decoration: InputDecoration(
                    labelText: CommunityWorkMetadataLabels.of(
                      context,
                    ).description,
                    hintText: CommunityWorkMetadataLabels.of(
                      context,
                    ).descriptionHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                CommunityPostCopyButton(
                  key: const Key('copyNiarimDescriptionToYoutube'),
                  source: _descriptionController,
                  destination: _youtubeDescriptionController,
                  enabled:
                      !_busy && !_restoringPending && retainedVideoId == null,
                  maxLength: 5000,
                  youtubeDescription: true,
                  label: CommunityWorkMetadataLabels.of(
                    context,
                  ).copyDescriptionToYoutube,
                  onError: _showCopyError,
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('communityPostYoutubeDescription'),
                  controller: _youtubeDescriptionController,
                  enabled: !_busy && retainedVideoId == null,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 5000,
                  decoration: InputDecoration(
                    labelText: CommunityWorkMetadataLabels.of(
                      context,
                    ).youtubeDescription,
                    hintText: CommunityWorkMetadataLabels.of(
                      context,
                    ).youtubeDescriptionHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                CommunityPostCopyButton(
                  key: const Key('copyYoutubeDescriptionToNiarim'),
                  source: _youtubeDescriptionController,
                  destination: _descriptionController,
                  enabled:
                      !_busy && !_restoringPending && retainedVideoId == null,
                  maxLength: 2000,
                  label: CommunityWorkMetadataLabels.of(
                    context,
                  ).copyDescriptionToNiarim,
                  onError: _showCopyError,
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
                const SizedBox(height: 12),
                Text('サムネイル', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                if (_thumbnailFile != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _thumbnailFile!,
                      key: const Key('communityPostThumbnailPreview'),
                      height: 155,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) =>
                          const Text('画像を読み込めません。画像を選び直してください。'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_thumbnailApplied) const Text('YouTubeへサムネイルを設定済み'),
                ] else
                  const Text('未指定の場合はYouTubeの自動サムネイルを使用します。'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('communityPostChooseThumbnail'),
                      onPressed: _busy || _thumbnailApplied
                          ? null
                          : _pickThumbnail,
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('画像を指定'),
                    ),
                    OutlinedButton.icon(
                      key: const Key('communityPostChooseVideoFrame'),
                      onPressed:
                          _busy || _videoFile == null || _thumbnailApplied
                          ? null
                          : _pickVideoFrame,
                      icon: const Icon(Icons.movie_filter_outlined),
                      label: const Text('動画のフレームを指定'),
                    ),
                    if (_thumbnailFile != null && !_thumbnailApplied)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() => _thumbnailFile = null),
                        child: const Text('自動サムネイルに戻す'),
                      ),
                  ],
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
                Builder(
                  builder: (context) {
                    final labels = CommunityPostVisibilityLabels.of(context);
                    final canChange = !_busy && retainedVideoId == null;
                    return RadioGroup<String>(
                      groupValue: _youtubePrivacyStatus,
                      onChanged: (value) {
                        if (canChange && value != null) {
                          setState(() => _youtubePrivacyStatus = value);
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            labels.heading,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 6),
                          RadioListTile<String>(
                            key: const Key('communityPostYouTubeUnlisted'),
                            contentPadding: EdgeInsets.zero,
                            value: 'unlisted',
                            enabled: canChange,
                            title: Text(labels.unlistedTitle),
                            subtitle: Text(labels.unlistedHelp),
                          ),
                          RadioListTile<String>(
                            key: const Key('communityPostYouTubePublic'),
                            contentPadding: EdgeInsets.zero,
                            value: 'public',
                            enabled: canChange,
                            title: Text(labels.publicTitle),
                            subtitle: Text(labels.publicHelp),
                          ),
                          RadioListTile<String>(
                            key: const Key('communityPostYouTubePrivate'),
                            contentPadding: EdgeInsets.zero,
                            value: 'private',
                            enabled: canChange,
                            title: const Text('非公開'),
                            subtitle: const Text('YouTubeにも作品広場にも一般公開されません。'),
                          ),
                          RadioListTile<String>(
                            key: const Key('communityPostYouTubeScheduled'),
                            contentPadding: EdgeInsets.zero,
                            value: 'scheduled',
                            enabled: canChange,
                            title: const Text('日時を指定して予約公開'),
                            subtitle: const Text(
                              '指定日時まではYouTubeで非公開。公開後に作品広場にも反映します。',
                            ),
                          ),
                          if (_youtubePrivacyStatus == 'scheduled')
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _scheduledPublishAt == null
                                        ? '公開日時が未設定です'
                                        : '公開予定: ${_scheduledPublishAt!.toLocal().year}/'
                                              '${_scheduledPublishAt!.toLocal().month.toString().padLeft(2, '0')}/'
                                              '${_scheduledPublishAt!.toLocal().day.toString().padLeft(2, '0')} '
                                              '${_scheduledPublishAt!.toLocal().hour.toString().padLeft(2, '0')}:'
                                              '${_scheduledPublishAt!.toLocal().minute.toString().padLeft(2, '0')}',
                                    key: const Key(
                                      'communityPostScheduleLabel',
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  OutlinedButton.icon(
                                    key: const Key(
                                      'communityPostChooseSchedule',
                                    ),
                                    onPressed: canChange ? _pickSchedule : null,
                                    icon: const Icon(Icons.schedule),
                                    label: Text(
                                      _scheduledPublishAt == null
                                          ? '予約日時を選択'
                                          : '予約日時を変更',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (_youtubePrivacyStatus == 'unlisted')
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                labels.unlistedDisclosure,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
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
