import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import '../providers/theme_provider.dart';
import '../providers/preferences_provider.dart';
import '../services/view_history_service.dart';
import '../services/record_service.dart';
import '../models/record.dart';
import '../widgets/record_tile_widget.dart';
import '../widgets/mood_selector.dart';

/// 设置页面 — 照片信息 / 主题 / 关于
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  int _versionTapCount = 0;
  bool _showHiddenButton = false;

  void _onVersionTap() {
    _versionTapCount++;
    if (_versionTapCount >= 10 && !_showHiddenButton) {
      setState(() => _showHiddenButton = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔓 已解锁全部记录入口'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
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
            onTap: _onVersionTap,
          ),
          const ListTile(
            leading: Icon(Icons.description_outlined),
            title: Text('应用简介'),
            subtitle: Text('一款回忆照片展示应用，带您重温美好时光。'),
          ),

          if (_showHiddenButton) ...[
            const Divider(indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => _showAllRecordsDialog(context, colorScheme),
                  icon: const Icon(Icons.list_alt_outlined),
                  label: const Text('全部记录'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                    side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 全部记录对话框（两个页面：照片列表 ↔ 记录详情，同一对话框内切换）
  void _showAllRecordsDialog(BuildContext context, ColorScheme cs) {
    showDialog(
      context: context,
      builder: (ctx) {
        String? currentPhotoId;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {

          Widget buildTitle() {
            if (currentPhotoId == null) {
              return Row(children: [
                Icon(Icons.list_alt_outlined, size: 20, color: cs.primary),
                const SizedBox(width: 8),
                const Text('全部记录', style: TextStyle(fontSize: 17)),
              ]);
            }
            return Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setDialogState(() => currentPhotoId = null),
              ),
              const SizedBox(width: 4),
              Text('记录详情', style: TextStyle(fontSize: 17, color: cs.primary)),
            ]);
          }

          Widget buildBody() {
            if (currentPhotoId == null) {
              // 照片列表
              return FutureBuilder<Map<String, int>>(
                future: RecordService.getPhotoRecordCounts(),
                builder: (context, snapshot) {
                  final data = snapshot.data;
                  if (data == null) {
                    return const SizedBox(width: 260, height: 200,
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                  }
                  if (data.isEmpty) {
                    return const SizedBox(width: 260, height: 100,
                        child: Center(child: Text('暂无记录')));
                  }
                  final entries = data.entries.toList();
                  return SizedBox(
                    width: double.maxFinite,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return _RecordPhotoTile(
                          photoId: entry.key,
                          recordCount: entry.value,
                          colorScheme: cs,
                          onTap: () => setDialogState(() => currentPhotoId = entry.key),
                        );
                      },
                    ),
                  );
                },
              );
            }
            // 记录列表
            return FutureBuilder<List<Record>>(
              future: RecordService.getByPhotoId(currentPhotoId!),
              builder: (context, snapshot) {
                final records = snapshot.data;
                if (records == null) {
                  return const SizedBox(width: 260, height: 150,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                }
                if (records.isEmpty) {
                  return const SizedBox(width: 260, height: 100,
                      child: Center(child: Text('暂无记录')));
                }
                return SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      final record = records[index];
                      return RecordTileWidget(
                        record: record,
                        colorScheme: cs,
                        onEdited: () async {
                          final updated = await _editRecordDialog(context, cs, record);
                          if (updated != null) {
                            records[index] = updated;
                            setDialogState(() {});
                          }
                        },
                        onDeleted: () {
                          RecordService.delete(record.id!);
                          setDialogState(() { records.removeAt(index); });
                        },
                      );
                    },
                  ),
                );
              },
            );
          }

          return PopScope(
            canPop: currentPhotoId == null,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && currentPhotoId != null) {
                setDialogState(() => currentPhotoId = null);
              }
            },
            child: AlertDialog(
            title: buildTitle(),
            content: SizedBox(width: double.maxFinite, child: buildBody()),
            actions: [
              TextButton(
                onPressed: () {
                  if (currentPhotoId != null) {
                    setDialogState(() => currentPhotoId = null);
                  } else {
                    Navigator.of(ctx).pop();
                  }
                },
                child: Text(currentPhotoId != null ? '返回' : '关闭'),
              ),
            ],
          ),
        );
      },
    );
  },
);
  }

  /// 编辑记录对话框
  Future<Record?> _editRecordDialog(BuildContext context, ColorScheme cs, Record record) async {
    final contentCtrl = TextEditingController(text: record.content);
    final formKey = GlobalKey<FormState>();
    int? selectedColor = record.color;
    String? selectedMood = _parseMoodLabel(record.mood);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(children: [
            Icon(Icons.edit_outlined, size: 20, color: cs.primary),
            const SizedBox(width: 8),
            const Text('编辑记录', style: TextStyle(fontSize: 17)),
          ]),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(controller: contentCtrl,
                  decoration: const InputDecoration(labelText: '记录内容', border: OutlineInputBorder()),
                  maxLines: 3, minLines: 2,
                  validator: (v) => (v == null || v.trim().isEmpty) ? '请输入记录内容' : null),
                const SizedBox(height: 12),
                MoodSelector(
                  selectedMood: selectedMood,
                  colorScheme: cs,
                  onTap: (RenderBox box) {
                    _showMoodOverlay(context, cs, box, selectedMood, (String? val) {
                      setDialogState(() => selectedMood = val);
                    });
                  },
                  onClear: () => setDialogState(() => selectedMood = null),
                ),
                const SizedBox(height: 16),
                Align(alignment: Alignment.centerLeft,
                  child: Text('标签颜色', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.7)))),
                const SizedBox(height: 8),
                Wrap(spacing: 10, runSpacing: 8,
                  children: RecordColors.all.map((c) {
                    final isSel = selectedColor == c;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = c),
                      child: Container(width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: c != null ? Color(c) : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(color: isSel ? cs.primary : cs.outlineVariant.withValues(alpha: 0.3), width: isSel ? 2.5 : 1.5),
                        ),
                        child: c == null
                            ? Icon(Icons.close, size: 14, color: cs.onSurfaceVariant.withValues(alpha: 0.4))
                            : (isSel ? Icon(Icons.check, size: 16, color: Colors.white) : null),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.of(ctx).pop(true);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final moodValue = composeMood(selectedMood);
      final updated = Record(
        id: record.id,
        photoId: record.photoId,
        content: contentCtrl.text.trim(),
        mood: moodValue,
        color: selectedColor,
        createdAt: record.createdAt,
        updatedAt: DateTime.now(),
      );
      await RecordService.update(updated);
      return updated;
    }
    return null;
  }

  /// 从存储的 mood 值（如 "😊 开心"）中提取标签文字（"开心"）
  String? _parseMoodLabel(String? mood) {
    if (mood == null) return null;
    // 已有 emoji + 文字格式 "😊 开心" → 提取 "开心"
    if (mood.contains(' ')) {
      final parts = mood.split(' ');
      if (parts.length >= 2) return parts.sublist(1).join(' ');
    }
    return mood;
  }

  /// 在心情选择器下方弹出覆盖面板
  void _showMoodOverlay(BuildContext context, ColorScheme cs, RenderBox anchor,
      String? current, void Function(String?) onSelected) {
    final overlay = Overlay.of(context);
    OverlayEntry? entry;
    final double left = 40;
    final double top = anchor.localToGlobal(Offset(0, anchor.size.height)).dy + 4;

    entry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => entry?.remove(),
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: left,
            top: top.clamp(0, MediaQuery.of(ctx).size.height - 240),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(14),
              shadowColor: Colors.black26,
              child: Container(
                width: MediaQuery.of(ctx).size.width - left * 2,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10, runSpacing: 10,
                  children: moodEmojiMap.entries.map((e) {
                    final isSel = current == e.value;
                    return GestureDetector(
                      onTap: () {
                        entry?.remove();
                        onSelected(isSel ? null : e.value);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel ? cs.primary.withValues(alpha: 0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSel ? cs.primary : cs.outlineVariant.withValues(alpha: 0.3),
                            width: isSel ? 1.5 : 1,
                          ),
                        ),
                        child: Text('${e.key} ${e.value}', style: TextStyle(fontSize: 15)),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(entry);
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

/// 全部记录列表中的照片条目（缩略图 + 记录数，可展开）
class _RecordPhotoTile extends StatelessWidget {
  final String photoId;
  final int recordCount;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _RecordPhotoTile({
    required this.photoId,
    required this.recordCount,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 缩略图
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 48, height: 48,
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                      child: _PhotoThumb(photoId: photoId),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(photoId,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        Text('$recordCount 条记录',
                            style: TextStyle(fontSize: 12, color: cs.primary)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      size: 20, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}



/// 异步加载照片缩略图
class _PhotoThumb extends StatelessWidget {
  final String photoId;
  const _PhotoThumb({required this.photoId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AssetEntity?>(
      future: AssetEntity.fromId(photoId),
      builder: (context, snapshot) {
        final entity = snapshot.data;
        if (entity == null) return const Icon(Icons.image_outlined, size: 24, color: Colors.grey);
        return FutureBuilder<Uint8List?>(
          future: entity.thumbnailDataWithSize(const ThumbnailSize(96, 96), quality: 70),
          builder: (context, snap) {
            final bytes = snap.data;
            if (bytes == null) return const Icon(Icons.image_outlined, size: 24, color: Colors.grey);
            return Image.memory(bytes, fit: BoxFit.cover);
          },
        );
      },
    );
  }
}
