import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/community_service.dart';
import '../../services/google_auth_service.dart';
import '../../services/youtube_upload_service.dart';
import '../../widgets/responsive.dart';

/// YouTubeへ動画を実アップロードし、返却されたvideoIdをそのままNIARIMの
/// workIdとしてPOST /worksへ登録する投稿画面。
///
/// 最重要の復旧ルールは「YouTubeアップロード成功後はvideoIdをStateへ保持し、
/// /works登録が失敗しても動画を再アップロードしない」こと。再試行時は保持済み
/// videoIdと新しく取得したOAuthアクセストークンでPOST /worksだけを再送する。
class CommunityPostScreen extends StatefulWidget {
  const CommunityPostScreen({super.key});

  @override
  State<CommunityPostScreen> createState() => _CommunityPostScreenState();
}

class _CommunityPostScreenState extends State<CommunityPostScreen> {
  final _titleController = TextEditingController();
  File? _videoFile;
  String? _youtubeVideoId;
  bool _isShort = false;
  bool _isNiarimPublished = true;
  bool _busy = false;
  double _progress = 0;
  String? _status;
  Object? _error;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
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
    if (_busy) return;
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

      var videoId = _youtubeVideoId;
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
          if (!mounted) return;
          // ここで即座に保持する。以降でPOST /worksが失敗しても消さない。
          setState(() {
            _youtubeVideoId = videoId;
            _progress = 1;
            _status = 'YouTubeアップロード完了。NIARIMへ登録しています…';
          });
        } finally {
          uploader.close();
        }
      }

      // closureをまたいだnullable変数の型昇格に依存せず、この先で使うIDを
      // 明示的に非nullへ固定する。以後POST/PATCH/完了通知のすべてがこの
      // 1つのIDだけを参照する。
      final registeredVideoId = videoId;
      if (registeredVideoId == null || registeredVideoId.isEmpty) {
        throw StateError('YouTube videoIdを取得できませんでした');
      }

      // 同じvideoIdをworkIdとして登録。初回のNIARIM公開状態もPOSTに含める
      // ことで「非公開で投稿」を選んだ作品がPATCHまで一瞬公開される競合を
      // 防ぐ。サーバー側は同一videoIdのPOSTを冪等に扱う。
      final registeredWork = await api.createWork(
        youtubeVideoId: registeredVideoId,
        youtubeAccessToken: youtubeToken,
        isShort: _isShort,
        isNiarimPublished: _isNiarimPublished,
      );

      // 初回POSTの応答を端末が受け取れず再試行した場合、既存Workが返る。
      // その間にユーザーが公開スイッチを変えていても希望状態へ収束させる。
      // IDは当然、YouTubeから返った同じvideoIdのまま。
      if (registeredWork.isNiarimPublished != _isNiarimPublished) {
        await api.updateWorkVisibility(
          registeredVideoId,
          isNiarimPublished: _isNiarimPublished,
        );
      }

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
    return Scaffold(
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
                    child: Row(
                      children: [
                        Icon(
                          Icons.cloud_done_outlined,
                          color: scheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'YouTubeアップロード済み\nvideoId: $retainedVideoId\n再試行しても動画は再アップロードしません。',
                            style: TextStyle(
                              color: scheme.onSecondaryContainer,
                            ),
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
                onPressed: _busy ? null : _submit,
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
    );
  }
}
