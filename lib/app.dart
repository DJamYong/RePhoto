import 'package:flutter/material.dart';
import 'pages/home_page.dart';

/// RePhoto App 根组件
class RePhotoApp extends StatelessWidget {
  const RePhotoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RePhoto',
      debugShowCheckedModeBanner: false,

      // Material 3 主题
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.light,
      ),

      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.dark,
      ),

      themeMode: ThemeMode.system,

      home: const HomePage(),
    );
  }
}
