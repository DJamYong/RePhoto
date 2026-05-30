import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../providers/preferences_provider.dart';
import '../services/view_history_service.dart';
import '../services/record_service.dart';

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
          //  回顾统计
          // ═══════════════════════════════════
          _SectionHeader(
            title: '回顾统计',
            icon: Icons.bar_chart_outlined,
            color: colorScheme.primary,
          ),
          FutureBuilder<_Stats>(
            future: _loadStats(),
            builder: (context, snapshot) {
              final stats = snapshot.data;
              if (stats == null) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text('加载中…', style: TextStyle(fontSize: 14)),
                );
              }
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.15)),
                  ),
                  color: colorScheme.surface.withValues(alpha: 0.5),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                    child: Row(
                      children: [
                        Expanded(child: _StatItem(icon: Icons.visibility_outlined, value: '${stats.todayViews}', label: '今日已看', cs: colorScheme)),
                        _StatDivider(cs: colorScheme),
                        Expanded(child: _StatItem(icon: Icons.history_outlined, value: '${stats.totalViews}', label: '累计看过', cs: colorScheme)),
                        _StatDivider(cs: colorScheme),
                        Expanded(child: _StatItem(icon: Icons.edit_note_outlined, value: '${stats.recordPhotos}', label: '写过记录', cs: colorScheme)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          const Divider(indent: 16, endIndent: 16),

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
            secondary: const Icon(Icons.schedule_outlined),
            title: const Text('照片年龄'),
            subtitle: const Text('显示拍摄距离今天多久时间'),
            value: photoPrefs.showAge,
            activeTrackColor: colorScheme.primary.withValues(alpha: 0.5),
            activeThumbColor: colorScheme.primary,
            onChanged: (value) =>
                ref.read(photoDisplayPrefsProvider.notifier).setShowAge(value),
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

/// 统计数据容器
class _Stats {
  final int todayViews;
  final int totalViews;
  final int recordPhotos;
  const _Stats(this.todayViews, this.totalViews, this.recordPhotos);
}

/// 异步加载统计
Future<_Stats> _loadStats() async {
  final today = DateTime.now();
  final todayStart = DateTime(today.year, today.month, today.day);

  final todayViews = await ViewHistoryService.countSince(todayStart);
  final totalViews = await ViewHistoryService.count();
  final recordPhotos = await RecordService.countDistinctPhotos();
  return _Stats(todayViews, totalViews, recordPhotos);
}

/// 统计卡片项（数字 + 标签，垂直排列）
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final ColorScheme cs;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: cs.primary.withValues(alpha: 0.7)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: cs.onSurface)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
      ],
    );
  }
}

/// 统计卡片分隔线
class _StatDivider extends StatelessWidget {
  final ColorScheme cs;
  const _StatDivider({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: cs.outlineVariant.withValues(alpha: 0.15),
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


