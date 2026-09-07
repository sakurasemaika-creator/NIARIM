import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/community_service.dart';
import '../../services/google_auth_service.dart';
import '../../services/youtube_upload_service.dart';
import '../../widgets/responsive.dart';

/// YouTubeへ動画を実アップロードし、返却されたvideoIdをそのままNIARIMの
/// workIdとしてPOST /worksへ登録する投稿画面。
///
/// 最重要の復旧ルールは「YouTubeアップロード成功後はvideoIdを永続保持し、
/// /works登録が失敗したり画面・アプリが終了しても動画を再アップロードしない」
/// こと。再試行時は保持済みvideoIdと、アップロード時と同じGoogleアカウントの
/// OAuthアクセストークンでPOST /worksだけを再送する。
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
    await Future.wait<void>([
      prefs.remove(_pendingVideoIdKey),
      prefs.remove(_pendingAccountIdKey),
      prefs.remove(_pendingAccountEmailKey),
      prefs.remove(_pendingTitleKey),
      prefs.remove(_pendingIsShortKey),
      prefs.remove(_pendingPublishedKey),
    ]);
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
          : 'NIARIMへの登録を再試行しています…';
    });

    try {
      // YouTube用OAuth tokenは登録再試行時にも取り直す。videoIdだけは保持し、
      // tokenの期限切れを理由に動画そのものを再アップロードしない。
      final youtubeToken = await auth.youtubeUploadAccessToken(
        promptIfNecessary: true,
      );
      if (youtubeToken == null || youtubeToken.isEmpty) {
        throw StateError('YouTubeへの投稿権限を取得できませんでした');
      }

      final postingAccount = auth.account;
      if (postingAccount == null) {
        throw StateError('Googleアカウントを確認できませんでした');
      }

      // 保留中videoIdは「アップロードしたGoogleアカウント」に固定する。
      // 別アカウントでPOST /worksを試すと、YouTube所有権検証とNIARIM認証の
      // 組み合わせが崩れるため、ネットワークへ送る前に止める。
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
            // 作品広場で再生可能にしつつ、YouTubeチャンネルの通常公開一覧へ
            // 勝手に露出させないため初期値は限定公開。NIARIM側の公開状態は
            // POST /worksで同時に確定させ、非公開指定の一瞬の露出も作らない。
            privacyStatus: 'unlisted',
            onProgress: (sent, total) {
              if (!mounted || total <= 0) return;
              setState(() => _progress = sent / total);
            },
          );
          videoId = result.videoId;
          uploadAccountId = postingAccount.id;
          uploadAccountEmail = postingAccount.email;

          // State更新より先に永続化する。アップロード完了直後にOSから終了されても
          // 次回起動時に同じvideoIdだけを使ってNIARIM登録を再開できる。
          await _persistPendingUpload(
            videoId: videoId,
            accountId: uploadAccountId,
            accountEmail: uploadAccountEmail,
            title: title,
          );
          if (!mounted) return;
          setState(() {
            _youtubeVideoId = videoId;
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
      if (registeredVideoId == null || registeredVideoId.isEmpty) {
        throw StateError('YouTube videoIdを取得できませんでした');
      }

      // アップロード中に外部のGoogle認証イベント等でアカウントが変わった場合は、
      // YouTube tokenとNIARIM ID tokenを別アカウントで混在させずここで止める。
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

      // POST/PATCHが完了した時点でのみ保留情報を消す。以後は自分の投稿一覧から
      // 同じvideoIdを使って公開状態を管理できる。
      await _clearPendingUpload();

      // 新着一覧の再取得は失敗しても投稿そのものの成功を取り消さない。
      await community.refreshFromBackend();
      if (!mounted) return;
      setState(() => _status = '投稿が完了しました');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('投稿しました（videoId: $registeredVideoId）')),
      );
      Navigator.of(context).pop(registeredVideoId);
    } catch (error) {
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
                      : (value) => setState(() => _isNiarimPublished = value),
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
