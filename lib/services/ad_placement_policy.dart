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
    case '/community':
    case '/tips':
    case '/help':
      return true;
    default:
      return path.startsWith('/community/work/') ||
          path.startsWith('/project/') ||
          path.startsWith('/canvas/') ||
          path.startsWith('/timeline/') ||
          path.startsWith('/save-tree/') ||
          path.startsWith('/materials/');
  }
}
