import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../router.dart';
import '../../../services/community_preview_service.dart';
import '../../../services/community_service.dart';
import '../../../services/api/community_api.dart';
import 'community_playback_status_view.dart';
import '../../../widgets/ad_banner_mock_widget.dart';
import 'community_work_card.dart';

/// App-wide preview state survives navigation. The media area is currently a
/// placeholder; the controls only toggle its visual state. Playback integration
/// must separately satisfy the player, platform and IP requirements.
class CommunityFloatingPreview extends StatefulWidget {
  const CommunityFloatingPreview({super.key});

  @override
  State<CommunityFloatingPreview> createState() =>
      _CommunityFloatingPreviewState();
}

class _CommunityFloatingPreviewState extends State<CommunityFloatingPreview> {
  bool _isPlaying = true;
  CommunityPlaybackStatus _playbackStatus = CommunityPlaybackStatus.checking;
  String? _lastWorkId;
  bool? _showingPlayer;
  final _resizeFocusKey = GlobalKey();
  final _closeFocusKey = GlobalKey();
  final _playFocusKey = GlobalKey();
  final _detailsFocusKey = GlobalKey();
  final _playFocus = FocusNode(debugLabel: 'Community preview play');
  final _resizeFocus = FocusNode(debugLabel: 'Community preview resize');
  final _detailsFocus = FocusNode(debugLabel: 'Community preview details');
  final _closeFocus = FocusNode(debugLabel: 'Community preview close');

  Future<void> _checkPlayback(String workId) async {
    final status = await context.read<CommunityService>().playbackStatus(
      workId,
    );
    if (!mounted || _lastWorkId != workId) return;
    setState(() => _playbackStatus = status);
  }

  void _retryPlayback() {
    final workId = _lastWorkId;
    if (workId == null) return;
    setState(() => _playbackStatus = CommunityPlaybackStatus.checking);
    _checkPlayback(workId);
  }

  @override
  void dispose() {
    _playFocus.dispose();
    _resizeFocus.dispose();
    _detailsFocus.dispose();
    _closeFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<CommunityPreviewService>();
    final opened = service.work;
    if (opened == null) {
      _lastWorkId = null;
      _showingPlayer = null;
      return const SizedBox.shrink();
    }
    if (_lastWorkId != opened.id) {
      _lastWorkId = opened.id;
      _isPlaying = true;
      _showingPlayer = null;
      _playbackStatus = CommunityPlaybackStatus.checking;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _lastWorkId == opened.id) _checkPlayback(opened.id);
      });
    }
    final community = context.watch<CommunityService>();
    final work = community.byId(opened.id) ?? opened;
    if (!community.isOwnWork(work) &&
        !work.isUnavailable &&
        work.isNiarimPublished &&
        !community.isDiscoverableForViewer(work)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (service.work?.id == opened.id) service.close();
      });
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final barColor = theme.cardTheme.color ?? theme.colorScheme.surface;
    final controlColor =
        theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;
    final media = MediaQuery.of(context);
    final leftLimit = media.padding.left;
    final topLimit = media.padding.top + kPersistentHorizontalAdMockExtent;
    final availableWidth = math.max(
      0.0,
      media.size.width - leftLimit - media.padding.right,
    );
    final availableHeight = math.max(
      0.0,
      media.size.height -
          topLimit -
          math.max(media.padding.bottom, media.viewInsets.bottom),
    );
    if (availableWidth == 0 || availableHeight == 0) {
      return const SizedBox.shrink();
    }
    final width = math.min(service.width, availableWidth);
    const labelStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.bold);
    final detailStyle =
        theme.textTheme.labelLarge?.merge(labelStyle) ?? labelStyle;
    final text = TextPainter(
      text: TextSpan(
        text: l10n.communityFloatingPreviewDetailButton,
        style: detailStyle,
      ),
      textScaler: media.textScaler,
      locale: Localizations.localeOf(context),
      textDirection: Directionality.of(context),
    )..layout(maxWidth: math.max(1, width - 40));
    final detailsWidth = math.max(64.0, text.width + 24);
    final detailsHeight = math.max(48.0, text.height + 24);
    final playerHeight = CommunityPreviewService.playerHeightFor(width);
    // Reserve every control outside the media rectangle, including the resize
    // handle. Never overlay a handle on top of Details or the player.
    final playerSplitRows = width < detailsWidth + 3 * 48 + 3 * 8 + 16;
    final playerControlsHeight = playerSplitRows
        ? 48 + detailsHeight
        : detailsHeight;
    final showPlayer =
        width >= CommunityPreviewService.minWidth &&
        playerHeight + playerControlsHeight <= availableHeight;
    final splitRows = showPlayer
        ? playerSplitRows
        : width < detailsWidth + 48 + 16;
    final controlsHeight = splitRows ? 48 + detailsHeight : detailsHeight;
    if (_showingPlayer != showPlayer) {
      final shouldFocus =
          _showingPlayer == null ||
          [
            _playFocus,
            _resizeFocus,
            _detailsFocus,
            _closeFocus,
          ].any((node) => node.hasFocus);
      _showingPlayer = showPlayer;
      // Keep focus when resize replaces a focused player with its fallback.
      // A field or dialog outside this preview retains its own focus.
      if (shouldFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              service.work?.id == work.id &&
              _showingPlayer == showPlayer) {
            final target = showPlayer ? _playFocus : _detailsFocus;
            target.requestFocus();
            if (!showPlayer && target.context != null) {
              Scrollable.ensureVisible(target.context!, alignment: 1);
            }
          }
        });
      }
    }
    final hint = TextPainter(
      text: TextSpan(
        text: l10n.communityFloatingPreviewCompactHint,
        style: theme.textTheme.bodySmall,
      ),
      textScaler: media.textScaler,
      locale: Localizations.localeOf(context),
      textDirection: Directionality.of(context),
    )..layout(maxWidth: math.max(1, width - 24));
    final height = math.min(
      availableHeight,
      controlsHeight + (showPlayer ? playerHeight : hint.height + 24),
    );
    text.dispose();
    hint.dispose();
    Offset boundedPosition(Offset value) => Offset(
      value.dx.clamp(leftLimit, leftLimit + availableWidth - width),
      value.dy.clamp(topLimit, topLimit + availableHeight - height),
    );
    final position = boundedPosition(service.position);
    double currentWidth() => math.min(service.width, availableWidth);

    void resize(double next) =>
        service.updateWidth(next, availableWidth: availableWidth);
    void cycleWidth() => resize(
      currentWidth() >=
              math.min(availableWidth, CommunityPreviewService.maxWidth) - .1
          ? CommunityPreviewService.minWidth
          : currentWidth() + 80,
    );
    void details() {
      service.close();
      appRouter.push('/community/work/${work.id}');
    }

    final resizeControl = Focus(
      key: _resizeFocusKey,
      canRequestFocus: false,
      onKeyEvent: (_, event) {
        if (HardwareKeyboard.instance.isAltPressed) {
          return KeyEventResult.ignored;
        }
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.arrowDown) {
          resize(currentWidth() - 24);
        } else if (key == LogicalKeyboardKey.arrowRight ||
            key == LogicalKeyboardKey.arrowUp) {
          resize(currentWidth() + 24);
        } else if (key == LogicalKeyboardKey.home) {
          resize(CommunityPreviewService.minWidth);
        } else if (key == LogicalKeyboardKey.end) {
          resize(availableWidth);
        } else {
          return KeyEventResult.ignored;
        }
        return KeyEventResult.handled;
      },
      child: Semantics(
        value: '${width.round()} px',
        increasedValue:
            '${(width + 24).clamp(CommunityPreviewService.minWidth, math.max(CommunityPreviewService.minWidth, math.min(availableWidth, CommunityPreviewService.maxWidth))).round()} px',
        decreasedValue:
            '${(width - 24).clamp(CommunityPreviewService.minWidth, CommunityPreviewService.maxWidth).round()} px',
        onIncrease:
            width < math.min(availableWidth, CommunityPreviewService.maxWidth)
            ? () => resize(currentWidth() + 24)
            : null,
        onDecrease: width > CommunityPreviewService.minWidth
            ? () => resize(currentWidth() - 24)
            : null,
        child: GestureDetector(
          onHorizontalDragStart: (_) {
            _resizeFocus.requestFocus();
            resize(width);
          },
          onHorizontalDragUpdate: (event) =>
              resize(service.width + event.delta.dx),
          child: IconButton(
            key: const Key('communityPreviewResize'),
            focusNode: _resizeFocus,
            tooltip: l10n.communityFloatingPreviewResizeTooltip,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            visualDensity: VisualDensity.standard,
            icon: Icon(Icons.open_in_full, color: controlColor),
            onPressed: () {
              _resizeFocus.requestFocus();
              cycleWidth();
            },
          ),
        ),
      ),
    );
    final close = KeyedSubtree(
      key: _closeFocusKey,
      child: IconButton(
        key: const Key('communityPreviewClose'),
        focusNode: _closeFocus,
        tooltip: l10n.commonClose,
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        visualDensity: VisualDensity.standard,
        icon: Icon(Icons.close, color: controlColor),
        onPressed: service.close,
      ),
    );
    final play = KeyedSubtree(
      key: _playFocusKey,
      child: IconButton(
        key: const Key('communityPreviewPlay'),
        focusNode: _playFocus,
        tooltip: _isPlaying
            ? l10n.communityFloatingPreviewPauseTooltip
            : l10n.communityFloatingPreviewPlayTooltip,
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        visualDensity: VisualDensity.standard,
        icon: Icon(
          _isPlaying ? Icons.pause : Icons.play_arrow,
          color: controlColor,
        ),
        onPressed: () {
          _playFocus.requestFocus();
          setState(() => _isPlaying = !_isPlaying);
        },
      ),
    );
    final detailButton = KeyedSubtree(
      key: _detailsFocusKey,
      child: TextButton(
        key: const Key('communityPreviewDetails'),
        focusNode: _detailsFocus,
        style: TextButton.styleFrom(
          foregroundColor: controlColor,
          textStyle: detailStyle,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.standard,
        ),
        onPressed: details,
        child: Text(l10n.communityFloatingPreviewDetailButton),
      ),
    );
    final controls = Container(
      key: const Key('communityPreviewControls'),
      color: barColor,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: splitRows
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (showPlayer &&
                        _playbackStatus == CommunityPlaybackStatus.available)
                      play,
                    close,
                    if (showPlayer) resizeControl,
                  ],
                ),
                detailButton,
              ],
            )
          : SizedBox(
              height: detailsHeight,
              child: Row(
                children: [
                  if (showPlayer &&
                      _playbackStatus == CommunityPlaybackStatus.available)
                    play,
                  close,
                  Expanded(child: detailButton),
                  if (showPlayer) resizeControl,
                ],
              ),
            ),
    );

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: SizedBox(
        width: width,
        height: height,
        // This surface lives outside the router's Navigator. A local overlay
        // supplies real hover/long-press tooltips without depending on a route.
        child: Overlay.wrap(
          clipBehavior: Clip.none,
          child: FocusTraversalGroup(
            policy: WidgetOrderTraversalPolicy(),
            child: Focus(
              canRequestFocus: false,
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                  return KeyEventResult.ignored;
                }
                final key = event.logicalKey;
                if (key == LogicalKeyboardKey.escape) {
                  service.close();
                  return KeyEventResult.handled;
                }
                if (!HardwareKeyboard.instance.isAltPressed) {
                  return KeyEventResult.ignored;
                }
                final delta = switch (key) {
                  LogicalKeyboardKey.arrowLeft => const Offset(-16, 0),
                  LogicalKeyboardKey.arrowRight => const Offset(16, 0),
                  LogicalKeyboardKey.arrowUp => const Offset(0, -16),
                  LogicalKeyboardKey.arrowDown => const Offset(0, 16),
                  _ => Offset.zero,
                };
                if (delta == Offset.zero) return KeyEventResult.ignored;
                service.updatePosition(
                  boundedPosition(boundedPosition(service.position) + delta),
                );
                return KeyEventResult.handled;
              },
              child: Material(
                key: const Key('communityPreviewSurface'),
                // Avoid the heavy, almost black elevation shadow shown
                // as an outline around the floating preview.
                elevation: 0,
                color: barColor,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) => service.updatePosition(position),
                  onPanUpdate: (event) => service.updatePosition(
                    boundedPosition(service.position + event.delta),
                  ),
                  child: SingleChildScrollView(
                    physics: showPlayer
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showPlayer)
                          Semantics(
                            hint: l10n.communityFloatingPreviewMoveHint,
                            child: SizedBox(
                              key: const Key('communityPreviewPlayer'),
                              height: playerHeight,
                              child:
                                  _playbackStatus !=
                                      CommunityPlaybackStatus.available
                                  ? CommunityPlaybackStatusView(
                                      status: _playbackStatus,
                                      onRetry: _retryPlayback,
                                    )
                                  : DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: communityThumbnailGradient(
                                            theme.colorScheme,
                                            work.thumbnailColorIndex,
                                          ),
                                        ),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          _isPlaying
                                              ? Icons.play_circle_fill_rounded
                                              : Icons
                                                    .pause_circle_filled_rounded,
                                          color: controlColor,
                                          size: 40,
                                        ),
                                      ),
                                    ),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              l10n.communityFloatingPreviewCompactHint,
                              key: const Key('communityPreviewCompactHint'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: controlColor,
                              ),
                            ),
                          ),
                        controls,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
