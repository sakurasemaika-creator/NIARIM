import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// The only YouTube media surface used by Community. Video files are never
/// downloaded or played outside the official YouTube IFrame player.
/// Parents must validate NIARIM + YouTube visibility before mounting this.
class CommunityYoutubePlayer extends StatefulWidget {
  const CommunityYoutubePlayer({
    super.key,
    required this.videoId,
    required this.playing,
    this.active = true,
    this.onEnded,
  });

  final String videoId;
  final bool playing;
  final bool active;
  /// Allows Shorts to either replay the current video or advance a page.
  final void Function(VoidCallback replay)? onEnded;

  static final RegExp videoIdPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');
  static bool isValidVideoId(String id) => videoIdPattern.hasMatch(id);

  /// Flutter widget tests substitute a non-platform media surface. Production
  /// does not assign this hook and always uses the real YouTube player.
  @visibleForTesting
  static Widget Function(BuildContext, String, bool)? debugPlayerBuilder;

  @override
  State<CommunityYoutubePlayer> createState() => _CommunityYoutubePlayerState();
}

class _CommunityYoutubePlayerState extends State<CommunityYoutubePlayer> {
  YoutubePlayerController? _controller;
  StreamSubscription<YoutubePlayerValue>? _events;
  bool _endedReported = false;
  bool _playerFailed = false;

  @override
  void initState() {
    super.initState();
    _create();
  }

  void _create() {
    if (!CommunityYoutubePlayer.isValidVideoId(widget.videoId) ||
        CommunityYoutubePlayer.debugPlayerBuilder != null) return;
    final controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: widget.playing && widget.active,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        playsInline: true,
        privacyEnhancedMode: true,
      ),
    );
    _controller = controller;
    _playerFailed = false;
    _endedReported = false;
    _events = controller.listen((value) {
      if (!mounted) return;
      if (value.hasError && !_playerFailed) {
        setState(() => _playerFailed = true);
      }
      if (value.playerState == PlayerState.playing) _endedReported = false;
      if (value.playerState == PlayerState.ended && !_endedReported) {
        _endedReported = true;
        widget.onEnded?.call(() {
          if (mounted && widget.active) {
            unawaited(controller.loadVideoById(videoId: widget.videoId));
          }
        });
      }
    });
  }

  void _disposeController() {
    final old = _controller;
    _controller = null;
    final subscription = _events;
    _events = null;
    if (subscription != null) unawaited(subscription.cancel());
    if (old != null) unawaited(old.close());
  }

  Future<void> _applyPlayback() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      if (widget.active && widget.playing) {
        await controller.playVideo();
      } else {
        await controller.pauseVideo();
      }
    } catch (_) {
      if (mounted && !_playerFailed) setState(() => _playerFailed = true);
    }
  }

  @override
  void didUpdateWidget(covariant CommunityYoutubePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      _disposeController();
      _create();
      return;
    }
    if (oldWidget.playing != widget.playing ||
        oldWidget.active != widget.active) {
      unawaited(_applyPlayback());
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!CommunityYoutubePlayer.isValidVideoId(widget.videoId)) {
      return const Center(child: Text('YouTube動画が連携されていません'));
    }
    final debugBuilder = CommunityYoutubePlayer.debugPlayerBuilder;
    if (debugBuilder != null) {
      return debugBuilder(
        context,
        widget.videoId,
        widget.active && widget.playing,
      );
    }
    if (_playerFailed) {
      return const Center(child: Text('YouTube動画を再生できませんでした'));
    }
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, box) {
        // YouTube's own minimum embedded player viewport is 200 x 200.
        if (box.maxWidth < 200 || box.maxHeight < 200) {
          return const Center(child: Text('動画再生には200px以上の表示領域が必要です'));
        }
        return YoutubePlayer(
          controller: controller,
          aspectRatio: box.maxWidth / box.maxHeight,
          enableFullScreenOnVerticalDrag: false,
          backgroundColor: Colors.black,
        );
      },
    );
  }
}
