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
import 'screens/save_tree/save_tree_screen.dart';
import 'screens/materials/material_list_screen.dart';
import 'screens/settings/font_settings_screen.dart';
import 'screens/settings/license_screen.dart';
import 'screens/settings/privacy_policy_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/shared', builder: (context, state) => const SharedScreen()),
    GoRoute(path: '/trash', builder: (context, state) => const TrashScreen()),
    GoRoute(
      path: '/community',
      builder: (context, state) =>
          CommunityScreen(initialTagFilter: state.extra as String?),
    ),
    GoRoute(
      path: '/community/work/:id',
      builder: (context, state) =>
          CommunityWorkDetailScreen(workId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/new-project',
      builder: (context, state) => const NewProjectScreen(),
    ),
    GoRoute(
      path: '/project/:id',
      builder: (context, state) =>
          ProjectDetailScreen(projectId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/canvas/:id',
      builder: (context, state) =>
          CanvasScreen(projectId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/timeline/:id',
      builder: (context, state) =>
          TimelineScreen(projectId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/export/:id',
      builder: (context, state) =>
          ExportScreen(projectId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/settings/gestures',
      builder: (context, state) => const GestureSettingsScreen(),
    ),
    GoRoute(
      path: '/settings/shortcuts',
      builder: (context, state) => const ShortcutSettingsScreen(),
    ),
    GoRoute(
      path: '/settings/performance',
      builder: (context, state) => const PerformanceSettingsScreen(),
    ),
    GoRoute(
      path: '/settings/pen',
      builder: (context, state) => const PenSettingsScreen(),
    ),
    GoRoute(
      path: '/settings/bucket',
      builder: (context, state) => const BucketFillSettingsScreen(),
    ),
    GoRoute(
      path: '/settings/workspace',
      builder: (context, state) => const WorkspaceSettingsScreen(),
    ),
    GoRoute(
      path: '/settings/transfer',
      builder: (context, state) => const TransferScreen(),
    ),
    GoRoute(
      path: '/settings/theme',
      builder: (context, state) => const ThemeSettingsScreen(),
    ),
    GoRoute(
      path: '/settings/watermark',
      builder: (context, state) => const WatermarkSettingsScreen(),
    ),
    GoRoute(
      path: '/help',
      builder: (context, state) =>
          HelpScreen(initialTopic: state.uri.queryParameters['topic']),
    ),
    GoRoute(path: '/tips', builder: (context, state) => const TipsScreen()),
    GoRoute(
      path: '/premium',
      builder: (context, state) => const PremiumScreen(),
    ),
    GoRoute(
      path: '/autofill-presets',
      builder: (context, state) => const AutofillPresetScreen(),
    ),
    GoRoute(
      path: '/save-tree/:id',
      builder: (context, state) => SaveTreeScreen(
        projectId: state.pathParameters['id']!,
        entryMode: parseSaveTreeEntryMode(state.uri.queryParameters['entry']),
      ),
    ),
    GoRoute(
      path: '/materials/:id',
      builder: (context, state) =>
          MaterialListScreen(projectId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/settings/fonts',
      builder: (context, state) => const FontSettingsScreen(),
    ),
    GoRoute(
      path: '/settings/license',
      builder: (context, state) => const LicenseScreen(),
    ),
    GoRoute(
      path: '/settings/privacy-policy',
      builder: (context, state) => const PrivacyPolicyScreen(),
    ),
  ],
);
