/// Conservative route-level guard for Google-served display banners.
///
/// A banner is NOT a mandatory part of every route. The publisher content
/// must be the focus; pure navigation, billing, consent, settings, error,
/// empty-state and alert screens are not appropriate advertising inventory.
///
/// Further dynamic checks are required for network-driven feeds that may
/// have no content, or for full-screen media and overlays. This function is
/// a fail-closed baseline, not a guarantee of AdMob policy approval.
bool isBannerEligibleRoute(
  String path, {
  bool hasLocalContent = true,
}) {
  switch (path) {
    case '/home':
    case '/shared':
    case '/trash':
      return hasLocalContent;
    // The community list and player can be loading, filtered to zero
    // results, unavailable, muted or covered by a video overlay. Until
    // per-tab/per-player visible-content signals are implemented, do NOT
    // request production ads on those dynamic routes.
    case '/community':
    case '/tips':
    case '/help':
      return false;
    default:
      // Canvas/timeline are high-frequency pen/touch surfaces: do not place
      // clickable banners adjacent to continuous creative interaction.
      // Save tree and materials are control/gallery-first flows.
      return path.startsWith('/project/');
  }
}
