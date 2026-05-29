import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'providers/theme_provider.dart';
import 'services/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化持久化存储
  final prefs = await SharedPreferences.getInstance();
  await DatabaseService.initialize();

  runApp(
    ProviderScope(
      // 注入 SharedPreferences 实例，供各 Notifier 使用
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
      child: const RePhotoApp(),
    ),
  );
}
