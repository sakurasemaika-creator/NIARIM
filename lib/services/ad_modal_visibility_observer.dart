import 'package:flutter/widgets.dart';

/// Tracks modal dialogs/bottom sheets opened through the root navigator.
///
/// On release builds banners are suppressed while a modal obscures the
/// publisher content. This avoids serving ads on alert/confirmation-only
/// screens or leaving clickable banners behind dialogs.
/// Debug builds can still exercise both placements as Google TEST ads.
class AdModalVisibilityObserver extends NavigatorObserver {
  final ValueNotifier<bool> isModalVisible = ValueNotifier<bool>(false);
  final Set<Route<dynamic>> _modals = <Route<dynamic>>{};
  bool _updateScheduled = false;

  void _scheduleUpdate() {
    if (_updateScheduled) return;
    _updateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScheduled = false;
      isModalVisible.value = _modals.isNotEmpty;
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute<dynamic>) {
      _modals.add(route);
      _scheduleUpdate();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_modals.remove(route)) _scheduleUpdate();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_modals.remove(route)) _scheduleUpdate();
  }

  @override
  void didReplace({
    Route<dynamic>? newRoute,
    Route<dynamic>? oldRoute,
  }) {
    final had = oldRoute != null && _modals.remove(oldRoute);
    final added = newRoute != null && newRoute is PopupRoute<dynamic>
        ? _modals.add(newRoute)
        : false;
    if (had || added) _scheduleUpdate();
  }
}

/// Shared with GoRouter's root Navigator and the app-wide ad placement.
final adModalVisibilityObserver = AdModalVisibilityObserver();
