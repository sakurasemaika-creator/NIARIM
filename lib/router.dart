import 'package:go_router/go_router.dart';

import 'screens/splash/splash_screen.dart';
import 'screens/community/community_screen.dart';
import 'screens/community/community_work_detail_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/project/new_project_screen.dart';
import 'screens/project/project_detail_screen.dart';
import 'screens/canvas/canvas_screen.dart';
import 'screens/timeline/timeline_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/settings/gesture_settings_screen.dart';
import 'screens/settings/shortcut_settings_screen.dart';
import 'screens/settings/performance_settings_screen.dart';
import 'screens/settings/pen_settings_screen.dart';
import 'screens/settings/bucket_fill_settings_screen.dart';
import 'screens/settings/workspace_settings_screen.dart';
import 'screens/settings/transfer_screen.dart';
import 'screens/settings/theme_settings_screen.dart';
import 'screens/settings/watermark_settings_screen.dart';
import 'screens/export/export_screen.dart';
import 'screens/help/help_screen.dart';
import 'screens/tips/tips_screen.dart';
import 'screens/premium/premium_screen.dart';
import 'screens/autofill/autofill_preset_screen.dart';
import 'screens/save_tree/save_management_screen.dart';
import 'screens/materials/material_list_screen.dart';
import 'screens/settings/font_settings_screen.dart';
import 'screens/settings/license_screen.dart';
import 'screens/settings/privacy_policy_screen.dart';
import 'screens/settings/storage_screen.dart';
import 'widgets/ad_banner_mock_widget.dart';
import 'screens/settings/widget_settings_screen.dart';
import 'screens/settings/widget_artwork_picker_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const AdMockPageFrame(child: SplashScreen()),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const AdMockPageFrame(child: HomeScreen()),
    ),
    GoRoute(
      path: '/shared',
      builder: (context, state) => const AdMockPageFrame(child: SharedScreen()),
    ),
    GoRoute(
      path: '/trash',
      builder: (context, state) => const AdMockPageFrame(child: TrashScreen()),
    ),
    GoRoute(
      path: '/community',
      builder: (context, state) => AdMockPageFrame(
        child: CommunityScreen(initialTagFilter: state.extra as String?),
      ),
    ),
    GoRoute(
      path: '/community/work/:id',
      builder: (context, state) => AdMockPageFrame(
        child: CommunityWorkDetailScreen(workId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/new-project',
      builder: (context, state) =>
          const AdMockPageFrame(child: NewProjectScreen()),
    ),
    GoRoute(
      path: '/project/:id',
      builder: (context, state) => AdMockPageFrame(
        child: ProjectDetailScreen(projectId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/canvas/:id',
      builder: (context, state) => AdMockPageFrame(
        child: CanvasScreen(projectId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/timeline/:id',
      builder: (context, state) => AdMockPageFrame(
        child: TimelineScreen(projectId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/export/:id',
      builder: (context, state) => AdMockPageFrame(
        child: ExportScreen(projectId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) =>
          const AdMockPageFrame(child: SettingsScreen()),
    ),
    GoRoute(
      path: '/settings/gestures',
      builder: (context, state) =>
          const AdMockPageFrame(child: GestureSettingsScreen()),
    ),
    GoRoute(
      path: '/settings/shortcuts',
      builder: (context, state) =>
          const AdMockPageFrame(child: ShortcutSettingsScreen()),
    ),
    GoRoute(
      path: '/settings/performance',
      builder: (context, state) =>
          const AdMockPageFrame(child: PerformanceSettingsScreen()),
    ),
    GoRoute(
      path: '/settings/pen',
      builder: (context, state) =>
          const AdMockPageFrame(child: PenSettingsScreen()),
    ),
    GoRoute(
      path: '/settings/bucket',
      builder: (context, state) =>
          const AdMockPageFrame(child: BucketFillSettingsScreen()),
    ),
    GoRoute(
      path: '/settings/workspace',
      builder: (context, state) =>
          const AdMockPageFrame(child: WorkspaceSettingsScreen()),
    ),
    GoRoute(
      path: '/settings/transfer',
      builder: (context, state) =>
          const AdMockPageFrame(child: TransferScreen()),
    ),
    GoRoute(
      path: '/settings/widget',
      builder: (context, state) =>
          const AdMockPageFrame(child: WidgetSettingsScreen()),
    ),
    GoRoute(
      path: '/settings/widget/artwork',
      builder: (context, state) =>
          const AdMockPageFrame(child: WidgetArtworkPickerScreen()),
    ),
    GoRoute(
      path: '/settings/widget/artwork/:id',
      builder: (context, state) => AdMockPageFrame(
        child: WidgetArtworkFramePickerScreen(
          projectId: state.pathParameters['id']!,
        ),
      ),
    ),
    GoRoute(
      path: '/settings/theme',
      builder: (context, state) =>
          const AdMockPageFrame(child: ThemeSettingsScreen()),
    ),
    GoRoute(
      path: '/settings/watermark',
      builder: (context, state) =>
          const AdMockPageFrame(child: WatermarkSettingsScreen()),
    ),
    GoRoute(
      path: '/help',
      builder: (context, state) => AdMockPageFrame(
        child: HelpScreen(initialTopic: state.uri.queryParameters['topic']),
      ),
    ),
    GoRoute(
      path: '/tips',
      builder: (context, state) => const AdMockPageFrame(child: TipsScreen()),
    ),
    GoRoute(
      path: '/premium',
      builder: (context, state) =>
          const AdMockPageFrame(child: PremiumScreen()),
    ),
    GoRoute(
      path: '/autofill-presets',
      builder: (context, state) =>
          const AdMockPageFrame(child: AutofillPresetScreen()),
    ),
    GoRoute(
      path: '/save-tree/:id',
      builder: (context, state) => AdMockPageFrame(
        child: SaveManagementScreen(
          projectId: state.pathParameters['id']!,
          entryMode: parseSaveTreeEntryMode(state.uri.queryParameters['entry']),
        ),
      ),
    ),
    GoRoute(
      path: '/materials/:id',
      builder: (context, state) => AdMockPageFrame(
        child: MaterialListScreen(projectId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/settings/fonts',
      builder: (context, state) =>
          const AdMockPageFrame(child: FontSettingsScreen()),
    ),
    GoRoute(
      path: '/settings/license',
      builder: (context, state) =>
          const AdMockPageFrame(child: LicenseScreen()),
    ),
    GoRoute(
      path: '/settings/privacy-policy',
      builder: (context, state) =>
          const AdMockPageFrame(child: PrivacyPolicyScreen()),
    ),
    GoRoute(
      path: '/storage',
      builder: (context, state) =>
          const AdMockPageFrame(child: StorageScreen()),
    ),
  ],
);
