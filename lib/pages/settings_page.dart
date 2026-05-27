import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../providers/preferences_provider.dart';

/// 设置页面 — 照片信息 / 主题 / 关于
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final photoPrefs = ref.watch(photoDisplayPrefsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ═══════════════════════════════════
          //  照片信息 — 控制主页卡片显示哪些元数据
          // ═══════════════════════════════════
          _SectionHeader(
            title: '照片信息',
            icon: Icons.photo_outlined,
            color: colorScheme.primary,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.calendar_today),
            title: const Text('显示拍摄日期'),
            subtitle: const Text('在照片卡片下方显示拍摄日期'),
            value: photoPrefs.showDate,
            activeTrackColor: colorScheme.primary.withValues(alpha: 0.5),
            activeThumbColor: colorScheme.primary,
            onChanged: (value) =>
                ref.read(photoDisplayPrefsProvider.notifier).setShowDate(value),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.text_fields),
            title: const Text('显示文件名'),
            subtitle: const Text('在照片卡片下方显示文件名'),
            value: photoPrefs.showTitle,
            activeTrackColor: colorScheme.primary.withValues(alpha: 0.5),
            activeThumbColor: colorScheme.primary,
            onChanged: (value) =>
                ref.read(photoDisplayPrefsProvider.notifier).setShowTitle(value),
          ),

          const Divider(indent: 16, endIndent: 16),

          // ═══════════════════════════════════
          //  主题
          // ═══════════════════════════════════
          _SectionHeader(
            title: '主题',
            icon: Icons.palette_outlined,
            color: colorScheme.primary,
          ),
          RadioListTile<ThemeMode>(
            title: const Text('跟随系统'),
            subtitle: const Text('自动切换浅色/深色主题'),
            value: ThemeMode.system,
            groupValue: themeMode,
            activeColor: colorScheme.primary,
            onChanged: (value) =>
                ref.read(themeModeProvider.notifier).set(value ?? ThemeMode.system),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('浅色模式'),
            subtitle: const Text('始终使用浅色主题'),
            value: ThemeMode.light,
            groupValue: themeMode,
            activeColor: colorScheme.primary,
            onChanged: (value) =>
                ref.read(themeModeProvider.notifier).set(value ?? ThemeMode.system),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('深色模式'),
            subtitle: const Text('始终使用深色主题'),
            value: ThemeMode.dark,
            groupValue: themeMode,
            activeColor: colorScheme.primary,
            onChanged: (value) =>
                ref.read(themeModeProvider.notifier).set(value ?? ThemeMode.system),
          ),

          const Divider(indent: 16, endIndent: 16),

          // ═══════════════════════════════════
          //  关于
          // ═══════════════════════════════════
          _SectionHeader(
            title: '关于',
            icon: Icons.favorite_outline,
            color: colorScheme.primary,
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('RePhoto'),
            subtitle: const Text('版本 1.0.0'),
          ),
          const ListTile(
            leading: Icon(Icons.description_outlined),
            title: Text('应用简介'),
            subtitle: Text('一款回忆照片展示应用，带您重温美好时光。'),
          ),
        ],
      ),
    );
  }
}

/// 分区标题组件
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
