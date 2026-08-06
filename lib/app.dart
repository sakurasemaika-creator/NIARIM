import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'router.dart';
import 'services/theme_service.dart';

class MiranimaApp extends StatelessWidget {
  const MiranimaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    // OSのbrightnessをThemeServiceに注入（BaseTheme.system対応）
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    themeService.updateSystemBrightness(platformBrightness);
    return MaterialApp.router(
      title: 'MIRANIMA',
      debugShowCheckedModeBanner: false,
      theme: themeService.themeData,
      routerConfig: appRouter,
    );
  }
}
