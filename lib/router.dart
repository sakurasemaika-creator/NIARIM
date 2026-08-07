import 'package:go_router/go_router.dart';
import 'screens/home/home_screen.dart';
import 'screens/project/new_project_screen.dart';
import 'screens/project/project_detail_screen.dart';
import 'screens/canvas/canvas_screen.dart';
import 'screens/timeline/timeline_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/settings/gesture_settings_screen.dart';
import 'screens/settings/performance_settings_screen.dart';
import 'screens/settings/pen_settings_screen.dart';
import 'screens/settings/workspace_settings_screen.dart';
import 'screens/settings/transfer_screen.dart';
import 'screens/settings/theme_settings_screen.dart';
import 'screens/settings/watermark_settings_screen.dart';
import 'screens/export/export_screen.dart';
import 'screens/help/help_screen.dart';
import 'screens/premium/premium_screen.dart';
import 'screens/autofill/autofill_preset_screen.dart';
import 'screens/save_tree/save_tree_screen.dart';
import 'screens/materials/material_list_screen.dart';
import 'screens/settings/font_settings_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/new-project', builder: (context, state) => const NewProjectScreen()),
    GoRoute(
      path: '/project/:id',
      builder: (context, state) => ProjectDetailScreen(projectId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/canvas/:id',
      builder: (context, state) => CanvasScreen(projectId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/timeline/:id',
      builder: (context, state) => TimelineScreen(projectId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/export/:id',
      builder: (context, state) => ExportScreen(projectId: state.pathParameters['id']!),
    ),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    GoRoute(path: '/settings/gestures', builder: (context, state) => const GestureSettingsScreen()),
    GoRoute(path: '/settings/performance', builder: (context, state) => const PerformanceSettingsScreen()),
    GoRoute(path: '/settings/pen', builder: (context, state) => const PenSettingsScreen()),
    GoRoute(path: '/settings/workspace', builder: (context, state) => const WorkspaceSettingsScreen()),
    GoRoute(path: '/settings/transfer', builder: (context, state) => const TransferScreen()),
    GoRoute(path: '/settings/theme', builder: (context, state) => const ThemeSettingsScreen()),
    GoRoute(path: '/settings/watermark', builder: (context, state) => const WatermarkSettingsScreen()),
    GoRoute(path: '/help', builder: (context, state) => const HelpScreen()),
    GoRoute(path: '/premium', builder: (context, state) => const PremiumScreen()),
    GoRoute(path: '/autofill-presets', builder: (context, state) => const AutofillPresetScreen()),
    GoRoute(
      path: '/save-tree/:id',
      builder: (context, state) => SaveTreeScreen(projectId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/materials/:id',
      builder: (context, state) => MaterialListScreen(projectId: state.pathParameters['id']!),
    ),
    GoRoute(path: '/settings/fonts', builder: (context, state) => const FontSettingsScreen()),
  ],
);
