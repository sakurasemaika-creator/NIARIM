import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../../l10n/app_localizations.dart';
import '../../../widgets/stepped_slider.dart';

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
    this.validatePlayback,
    this.onPlayingChanged,
    this.detailPreviewHeight,
    this.detailDurationSeconds = 0,
  });

  final String videoId;
  final bool playing;
  final bool active;
  final double? detailPreviewHeight;
  final int detailDurationSeconds;

  /// Allows Shorts to either replay the current video or advance a page.
  final void Function(VoidCallback replay)? onEnded;

  /// On each native IFrame play/resume, recheck the server-side visibility.
  /// Rejecting pauses the player and allows the parent to unmount it.
  final Future<bool> Function()? validatePlayback;

  /// Syncs the host play/pause button with YouTube's native controls.
  final ValueChanged<bool>? onPlayingChanged;

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
  StreamSubscription<YoutubeVideoState>? _progressEvents;
  double _position = 0;
  double? _dragPosition;
  double _videoDuration = 0;
  bool _nativePlaying = false;
  bool _endedReported = false;
  bool _playerFailed = false;
  bool _verifyingPlayback = false;
  PlayerState _lastNativeState = PlayerState.unknown;

  @override
  void initState() {
    super.initState();
    _create();
  }

  void _create() {
    if (!CommunityYoutubePlayer.isValidVideoId(widget.videoId) ||
        CommunityYoutubePlayer.debugPlayerBuilder != null) {
      return;
    }
    final controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: widget.playing && widget.active,
      params: const YoutubePlayerParams(
        // YouTube requires a recognizable WebView document origin / Referer.
        // Match android/app/build.gradle.kts applicationId to prevent Error 153.
        origin: 'https://com.niarim.niarim',
        showControls: true,
        showFullscreenButton: true,
        playsInline: true,
        privacyEnhancedMode: true,
      ),
    );
    _controller = controller;
    _playerFailed = false;
    _endedReported = false;
    _lastNativeState = PlayerState.unknown;
    _position = 0;
    _dragPosition = null;
    _videoDuration = 0;
    _nativePlaying = false;
    if (widget.detailPreviewHeight != null) {
      _progressEvents = controller.videoStateStream.listen((state) {
        if (!mounted || !identical(controller, _controller)) return;
        final position = state.position.inMilliseconds / 1000;
        if ((position - _position).abs() >= .025) {
          setState(() => _position = position);
        }
      });
    }
    _events = controller.listen((value) {
      if (!mounted) return;
      if (widget.detailPreviewHeight != null) {
        final duration = value.metaData.duration.inMilliseconds / 1000;
        final playing =
            value.playerState == PlayerState.playing ||
            (value.playerState == PlayerState.buffering && _nativePlaying);
        if (duration != _videoDuration || playing != _nativePlaying) {
          setState(() {
            _videoDuration = duration;
            _nativePlaying = playing;
          });
        }
      }
      if (value.hasError && !_playerFailed) {
        setState(() => _playerFailed = true);
      }
      if (value.playerState != _lastNativeState) {
        if (value.playerState == PlayerState.playing) {
          _endedReported = false;
          widget.onPlayingChanged?.call(true);
          if (widget.validatePlayback != null && !_verifyingPlayback) {
            unawaited(_recheckNativePlay(controller));
          }
        } else if (value.playerState == PlayerState.paused ||
            value.playerState == PlayerState.ended) {
          widget.onPlayingChanged?.call(false);
        }
        _lastNativeState = value.playerState;
      }
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

  Future<void> _recheckNativePlay(YoutubePlayerController controller) async {
    if (_verifyingPlayback) return;
    _verifyingPlayback = true;
    bool allowed = false;
    try {
      allowed = await widget.validatePlayback?.call() ?? true;
    } catch (_) {
      allowed = false;
    } finally {
      _verifyingPlayback = false;
    }
    if (!allowed && mounted && identical(_controller, controller)) {
      try {
        await controller.pauseVideo();
      } catch (_) {
        // The owning view will fail closed and unmount the player.
      }
    }
  }

  void _disposeController() {
    final old = _controller;
    _controller = null;
    final subscription = _events;
    _events = null;
    if (subscription != null) unawaited(subscription.cancel());
    final progress = _progressEvents;
    _progressEvents = null;
    if (progress != null) unawaited(progress.cancel());
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
    if (widget.detailPreviewHeight case final height?) {
      return _buildDetailPreview(context, height);
    }
    return _buildPlayerSurface(context);
  }

  Widget _buildDetailPreview(BuildContext context, double height) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final controller = _controller;
    final available = controller != null && !_playerFailed;
    final duration = _videoDuration > 0
        ? _videoDuration
        : widget.detailDurationSeconds.clamp(0, double.infinity).toDouble();
    final position = (_dragPosition ?? _position).clamp(0.0, duration);
    const step = 5.0;

    Future<void> seek(double seconds) async {
      if (controller == null || duration <= 0) return;
      try {
        await controller.seekTo(
          seconds: seconds.clamp(0.0, duration),
          allowSeekAhead: true,
        );
      } catch (_) {
        if (mounted && identical(controller, _controller)) {
          setState(() => _playerFailed = true);
        }
      }
    }

    Widget control(IconData icon, String tooltip, VoidCallback? onPressed) =>
        IconButton(
          icon: Icon(icon),
          tooltip: tooltip,
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 48),
        );
    Widget cell(Widget child) => Expanded(child: Center(child: child));
    Widget time(double seconds) => FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        '${seconds.toStringAsFixed(1)}s',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: height,
            child: ColoredBox(
              color: scheme.surfaceContainerHighest,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: height * (16 / 9)),
                  child: _buildPlayerSurface(context),
                ),
              ),
            ),
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: SteppedSlider(
            key: const Key('communityDetailSeekBar'),
            value: position,
            min: 0,
            max: duration > 0 ? duration : 1,
            showSteppers: false,
            onChanged: available && duration > 0
                ? (value) => setState(() => _dragPosition = value)
                : null,
            onChangeEnd: (value) async {
              await seek(value);
              if (mounted && identical(controller, _controller)) {
                setState(() {
                  _position = value;
                  _dragPosition = null;
                });
              }
            },
          ),
        ),
        Row(
          children: [
            cell(time(position)),
            cell(
              control(
                Icons.skip_previous,
                l10n.communityPreviewStart,
                available ? () => seek(0) : null,
              ),
            ),
            cell(
              control(
                Icons.fast_rewind,
                l10n.communityPreviewBackward,
                available ? () => seek(position - step) : null,
              ),
            ),
            cell(
              control(
                _nativePlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_fill,
                _nativePlaying
                    ? l10n.projectDetailPauseTooltip
                    : l10n.projectDetailPlayTooltip,
                available
                    ? () {
                        if (_nativePlaying) {
                          unawaited(controller.pauseVideo());
                        } else {
                          unawaited(controller.playVideo());
                        }
                      }
                    : null,
              ),
            ),
            cell(
              control(
                Icons.fast_forward,
                l10n.communityPreviewForward,
                available ? () => seek(position + step) : null,
              ),
            ),
            cell(
              control(
                Icons.skip_next,
                l10n.communityPreviewEnd,
                available ? () => seek(duration) : null,
              ),
            ),
            cell(time(duration)),
          ],
        ),
      ],
    );
  }

  Widget _buildPlayerSurface(BuildContext context) {
    if (!CommunityYoutubePlayer.isValidVideoId(widget.videoId)) {
      return Center(
        child: Text(AppLocalizations.of(context)!.communityPlayerNotLinked),
      );
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
      return Center(
        child: Text(
          AppLocalizations.of(context)!.communityPlayerPlaybackFailed,
        ),
      );
    }
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, box) {
        // YouTube's own minimum embedded player viewport is 200 x 200.
        if (box.maxWidth < 200 || box.maxHeight < 200) {
          return Center(
            child: Text(
              AppLocalizations.of(context)!.communityPlayerTooSmall(200),
            ),
          );
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
