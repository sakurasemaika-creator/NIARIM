import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api/niarim_api_exception.dart';
import '../../services/community_service.dart';
import '../../services/google_auth_service.dart';
import '../../services/youtube_upload_service.dart';
import '../../widgets/responsive.dart';

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
  static const _pendingAccountEmailKey = 'community.pendingUpload.googleAccountEmail';
  static const _pendingTitleKey = 'community.pendingUpload.title';
  static const _pendingIsShortKey = 'community.pendingUpload.isShort';
  static const _pendingPublishedKey = 'community.pendingUpload.isNiarimPublished';

  final _titleController = TextEditingController();
  File? _videoFile;
  String? _youtubeVideoId;
  String? _uploadAccountId;
  String? _uploadAccountEmail;
  bool _isShort = false;
  bool _isNiarimPublished = true;
  bool _busy = false;
  bool _restoringPending = true;
  double _progress = 0;
  String? _status;
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
      final videoId = prefs.getString(_pendingVideoIdKey);
      if (!mounted) return;
      if (videoId != null && videoId.isNotEmpty) {
        setState(() {
          _youtubeVideoId = videoId;
          _uploadAccountId = prefs.getString(_pendingAccountIdKey);
          _uploadAccountEmail = prefs.getString(_pendingAccountEmailKey);
          _isShort = prefs.getBool(_pendingIsShortKey) ?? false;
          _isNiarimPublished = prefs.getBool(_pendingPublishedKey) ?? true;
          _titleController.text = prefs.getString(_pendingTitleKey) ?? '';
          _status = '前回YouTubeへアップロード済みの動画があります。NIARIM登録だけ再試行できます';
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
      _status = '保留中のYouTube動画は削除済み、または見つからないため復旧できません。新しい動画を選択してください';
      _error = 'YouTube動画が見つかりません。このvideoIdのNIARIM登録は再試行できません';
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
      _status = null;
      _error = null;
      _progress = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('保留中のNIARIM登録情報を破棄しました。YouTube動画自体は削除していません。')),
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
    setState(() => _status = recovered ? '投稿済みの作品を復旧しました' : '投稿が完了しました');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          recovered
              ? '投稿済みの作品を復旧しました（videoId: $registeredVideoId）'
              : '投稿しました（videoId: $registeredVideoId）',
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
      setState(() => _error = '投稿する動画を選択してください');
      return;
    }
    if (title.isEmpty) {
      setState(() => _error = 'タイトルを入力してください');
      return;
    }

    final auth = context.read<GoogleAuthService>();
    final community = context.read<CommunityService>();
    final api = community.api;
    if (!auth.isConfigured) {
      setState(() => _error = 'Google認証が設定されていません');
      return;
    }
    if (api == null) {
      setState(() => _error = 'NIARIM APIの接続先が設定されていません');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _status = _youtubeVideoId == null
          ? 'Googleアカウントを確認しています…'
          : 'NIARIMへの登録状況を確認しています…';
    });

    try {
      var postingAccount = auth.account;
      postingAccount ??= await auth.signInInteractively();

      final retainedAccountId = _uploadAccountId;
      if (_youtubeVideoId != null &&
          retainedAccountId != null &&
          retainedAccountId.isNotEmpty &&
          retainedAccountId != postingAccount.id) {
        throw StateError(
          'この動画は${_uploadAccountEmail ?? '別のGoogleアカウント'}でアップロード済みです。'
          'そのアカウントへ切り替えてからNIARIM登録を再試行してください',
        );
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
          throw StateError(
            '登録状況の確認中にGoogleアカウントが変更されました。$uploadAccountEmailへ戻して再試行してください',
          );
        }
        for (final work in ownWorks) {
          if (work.workId != videoId) continue;
          // 既にNIARIM登録済みでも、同期バッチがYouTube削除を検知している
          // 場合は復旧扱いにしない。削除済み動画は公開状態をPATCHしても
          // 復活しないため、保留情報を破棄して新しい動画の選択へ戻す。
          if (work.youtubePrivacyStatus == 'deleted') {
            await _markPendingVideoUnavailable();
            return;
          }
          if (work.isNiarimPublished != _isNiarimPublished) {
            setState(() => _status = '投稿済み作品の公開状態を同期しています…');
            await api.updateWorkVisibility(
              videoId,
              isNiarimPublished: _isNiarimPublished,
            );
          }
          await _finishRegistration(
            community,
            videoId,
            recovered: true,
          );
          return;
        }
      }

      // ここへ来るのは新規YouTubeアップロード、またはYouTubeには存在するが
      // NIARIM未登録の保留投稿だけ。初めてここでyoutube.upload scopeを要求する。
      final youtubeToken = await auth.youtubeUploadAccessToken(
        promptIfNecessary: true,
      );
      if (youtubeToken == null || youtubeToken.isEmpty) {
        throw StateError('YouTubeへの投稿権限を取得できませんでした');
      }
      if (auth.account?.id != uploadAccountId) {
        throw StateError(
          'YouTube投稿権限の確認中にGoogleアカウントが変更されました。$uploadAccountEmailへ戻して再試行してください',
        );
      }

      if (videoId == null) {
        if (!mounted) return;
        setState(() {
          _status = 'YouTubeへアップロードしています…';
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
            _status = 'YouTubeアップロード完了。NIARIMへ登録しています…';
          });
        } finally {
          uploader.close();
        }
      }

      final registeredVideoId = videoId;
      if (registeredVideoId.isEmpty) {
        throw StateError('YouTube videoIdを取得できませんでした');
      }

      // 外部認証イベント等でアカウントが変わった場合、YouTube tokenと
      // NIARIM ID tokenを別アカウントで混在させずPOST前に止める。
      if (auth.account?.id != uploadAccountId) {
        throw StateError(
          '投稿中にGoogleアカウントが変更されました。$uploadAccountEmailへ戻してNIARIM登録を再試行してください',
        );
      }

      final registeredWork = await api.createWork(
        youtubeVideoId: registeredVideoId,
        youtubeAccessToken: youtubeToken,
        isShort: _isShort,
        isNiarimPublished: _isNiarimPublished,
      );

      if (registeredWork.isNiarimPublished != _isNiarimPublished) {
        if (auth.account?.id != uploadAccountId) {
          throw StateError('公開状態の更新前にGoogleアカウントが変更されました');
        }
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
      if (!mounted) return;
      setState(() {
        _error = error;
        _status = _youtubeVideoId == null
            ? 'アップロードに失敗しました'
            : 'YouTube動画は保存済みです。NIARIM登録だけ再試行できます';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final retainedVideoId = _youtubeVideoId;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('投稿する')),
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
                  decoration: const InputDecoration(
                    labelText: 'タイトル',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy || retainedVideoId != null ? null : _pickVideo,
                  icon: const Icon(Icons.video_file_outlined),
                  label: Text(
                    _videoFile == null
                        ? '動画を選択'
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
                  title: const Text('縦画面ショートとして投稿'),
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
                  title: const Text('作品広場で公開'),
                  subtitle: const Text(
                    'YouTube側は限定公開でアップロードし、NIARIM側の公開状態を別に管理します',
                  ),
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
                                  'YouTubeアップロード済み\nvideoId: $retainedVideoId'
                                  '${_uploadAccountEmail == null ? '' : '\nGoogle: $_uploadAccountEmail'}\n'
                                  '再試行しても動画は再アップロードしません。',
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
                              child: const Text('NIARIM登録をやめる'),
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
                    _status!,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'エラー: $_error',
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
                        ? 'YouTubeへアップロードして投稿'
                        : 'NIARIM登録を再試行',
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
