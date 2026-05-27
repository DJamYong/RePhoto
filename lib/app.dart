import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/theme_provider.dart';
import 'pages/home_page.dart';

/// RePhoto App 根组件 — 暖色回忆风主题
class RePhotoApp extends ConsumerWidget {
  const RePhotoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'RePhoto',
      debugShowCheckedModeBanner: false,

      // 暖色回忆风 — 浅色主题
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD4A373),  // 暖杏色
          brightness: Brightness.light,
          primary: const Color(0xFFC08552),    // 暖棕
          secondary: const Color(0xFFE9C89A),  // 浅杏
          surface: const Color(0xFFFEF7EF),    // 米白
        ),
        scaffoldBackgroundColor: const Color(0xFFFDF6EC),  // 暖米背景
        appBarTheme: AppBarTheme(
          centerTitle: true,
          backgroundColor: const Color(0xFFFAF1E5),  // 暖米偏暖 — 比渐变顶部略深
          surfaceTintColor: const Color(0xFFD4A373).withValues(alpha: 0.10),
          elevation: 1,
          shadowColor: const Color(0xFF5C4033).withValues(alpha: 0.10),
          foregroundColor: const Color(0xFF5C4033),  // 深棕文字
        ),
      ),

      // 深色主题 — 暖色暗调
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD4A373),
          brightness: Brightness.dark,
          primary: const Color(0xFFE9C89A),
          surface: const Color(0xFF2C2420),    // 暖黑
        ),
        scaffoldBackgroundColor: const Color(0xFF1F1A17),
        appBarTheme: AppBarTheme(
          centerTitle: true,
          backgroundColor: const Color(0xFF362E28),  // 暖黑偏亮 — 比渐变顶部略浅
          surfaceTintColor: const Color(0xFFE9C89A).withValues(alpha: 0.08),
          elevation: 1,
          shadowColor: const Color(0xFF000000).withValues(alpha: 0.20),
        ),
      ),

      themeMode: themeMode,

      home: const HomePage(),
    );
  }
}
