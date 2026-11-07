/// Route policy for a persistently anchored, separated AdMob banner.
///
/// A creative canvas is user content, and an always-on banner is NOT banned
/// merely because a drawing tool is active. Google recommends preventing
/// accidental clicks by reserving a dedicated non-overlapping region and
/// separating ads from stylus/touch controls.
///
/// Deny empty/list-loading screens and menu/consent/paywall/legal-only
/// surfaces. Other content routes use the common top slot, not a floating
/// banner. This policy is a layout risk reduction, not AdMob approval.
bool isBannerEligibleRoute(
  String path, {
  bool hasLocalContent = true,
}) {
  if (path == '/home' ||
      path == '/shared' ||
      path == '/trash' ||
      path == '/community' ||
      path.startsWith('/community/work/')) {
    // Those screens may be empty or waiting for remote content.
    return hasLocalContent;
  }

  // Persistent, content-bearing editor / viewer / documentation surfaces.
  if (path.startsWith('/project/') ||
      path.startsWith('/canvas/') ||
      path.startsWith('/timeline/') ||
      path.startsWith('/materials/') ||
      path.startsWith('/save-tree/')) {
    return true;
  }

  switch (path) {
    case '/tips':
    case '/help':
    case '/settings/license':
    case '/settings/privacy-policy':
      // These are scrollable, substantive reference documents, not merely
      // navigation or action screens. A separate top ad is permissible
      // in principle; still subject to Google publisher review.
      return true;
    // Forms/menus without independent content, purchase flows, legal,
    // diagnostics and action-only screens intentionally remain ad-free.
    default:
      return false;
  }
}
