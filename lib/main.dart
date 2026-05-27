import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    // ProviderScope 包裹整个应用，使 Riverpod 状态全局可用
    const ProviderScope(
      child: RePhotoApp(),
    ),
  );
}
