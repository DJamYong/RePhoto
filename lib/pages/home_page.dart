import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:exif/exif.dart';
import 'package:photo_manager/photo_manager.dart';
import '../providers/photo_provider.dart';
import '../providers/preferences_provider.dart';
import '../models/record.dart';
import '../services/record_service.dart';
import 'photo_fullscreen_page.dart';
import 'settings_page.dart';

/// 首页 — 暖色回忆风 · 拍立得照片展示
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(photoProvider);

    return _SlidingPanel(
      panelContentBuilder: (s) => _DrawerContent(
        photo: s.photo!,
        preloadedThumbnail: s.preloadedThumbnail,
        preloadedFile: s.preloadedFile,
        preloadedExif: s.preloadedExif,
      ),
      photoAsync: stateAsync,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              tooltip: '照片详情',
              onPressed: () {
                _SlidingPanel.openOf(context);
              },
            ),
          ),
          title: Text(
            'RePhoto',
            style: TextStyle(
              fontWeight: FontWeight.w300,
              letterSpacing: 4,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: '设置',
              onPressed: () => Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, anim1, anim2) => const SettingsPage(),
                  transitionsBuilder: (context, anim, secondaryAnim, child) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1.0, 0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: anim,
                        curve: Curves.easeOut,
                      )),
                      child: child,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        body: stateAsync.when(
          loading: () => const _WarmLoading(),
          data: (state) {
            if (state.errorMessage != null) {
              return _ErrorView(state: state, ref: ref);
            }
            return _PhotoAlbumView(photo: state.photo!, ref: ref);
          },
          error: (error, _) => _ErrorView(
            state: RandomPhotoState(errorMessage: '加载失败：$error'),
            ref: ref,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════
//  自定义滑出面板 — 手指实时跟随
// ═══════════════════════════════════════

/// 从左侧滑出的照片详情面板，支持手指拖拽实时跟随
class _SlidingPanel extends StatefulWidget {
  final Widget child;
  final AsyncValue<RandomPhotoState> photoAsync;
  final Widget Function(RandomPhotoState) panelContentBuilder;

  const _SlidingPanel({
    required this.child,
    required this.photoAsync,
    required this.panelContentBuilder,
  });

  /// 从子 widget 的 context 找到最近的 _SlidingPanel 并打开
  static void openOf(BuildContext context) {
    _SlidingPanelState? state =
        context.findAncestorStateOfType<_SlidingPanelState>();
    state?.open();
  }

  @override
  State<_SlidingPanel> createState() => _SlidingPanelState();
}

class _SlidingPanelState extends State<_SlidingPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final CurvedAnimation _curve;

  static const double _panelWidthRatio = 0.78;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _curve = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _curve.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  /// 打开面板
  void open() {
    if (_ctrl.isAnimating) _ctrl.stop();
    _ctrl.forward();
  }

  /// 关闭面板
  void close() {
    if (_ctrl.isAnimating) _ctrl.stop();
    _ctrl.reverse();
  }

  /// 切换面板
  void toggle() {
    if (_ctrl.value > 0.5) {
      close();
    } else {
      open();
    }
  }

  @override
  Widget build(BuildContext context) {
    final panelWidth = MediaQuery.of(context).size.width * _panelWidthRatio;

    return AnimatedBuilder(
        animation: _curve,
        builder: (context, child) {
          final progress = _ctrl.value;
          return Stack(
            children: [
              // 主内容 — 支持右滑打开详情面板
              Positioned.fill(
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    final delta = details.primaryDelta ?? 0;
                    final newValue =
                        (_ctrl.value + delta / panelWidth).clamp(0.0, 1.0);
                    _ctrl.value = newValue;
                  },
                  onHorizontalDragEnd: (details) {
                    if (_ctrl.value > 0.3 ||
                        (details.primaryVelocity ?? 0) > 300) {
                      open();
                    } else {
                      close();
                    }
                  },
                  child: child!,
                ),
              ),

              // 半透明遮罩
              if (progress > 0.005)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: close,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.35 * progress),
                    ),
                  ),
                ),

              // 滑出面板 — 支持左滑关闭
              Transform.translate(
                offset: Offset(-panelWidth * (1 - progress), 0),
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    final delta = details.primaryDelta ?? 0;
                    final newValue =
                        (_ctrl.value + delta / panelWidth).clamp(0.0, 1.0);
                    _ctrl.value = newValue;
                  },
                  onHorizontalDragEnd: (details) {
                    if (_ctrl.value > 0.3 &&
                        (details.primaryVelocity ?? 0) > -300) {
                      open();
                    } else {
                      close();
                    }
                  },
                  child: SizedBox(
                    width: panelWidth,
                    child: _PanelBody(
                      photoAsync: widget.photoAsync,
                      panelContentBuilder: widget.panelContentBuilder,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        child: widget.child,
      );
  }
}

/// 面板主体 — 根据 photoAsync 状态切换
class _PanelBody extends StatelessWidget {
  final AsyncValue<RandomPhotoState> photoAsync;
  final Widget Function(RandomPhotoState) panelContentBuilder;

  const _PanelBody({
    required this.photoAsync,
    required this.panelContentBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF2C2420), const Color(0xFF1F1A17)]
              : [const Color(0xFFFDF6EC), const Color(0xFFF5EAE0)],
        ),
      ),
      child: SafeArea(
        child: photoAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (_, _) => const Center(child: Text('加载失败')),
          data: (state) {
            if (state.photo == null) {
              return const Center(child: Text('暂无照片'));
            }
            return panelContentBuilder(state);
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════
//  加载状态 — 暖色骨架屏
// ═══════════════════════════════════════

class _WarmLoading extends StatefulWidget {
  const _WarmLoading();

  @override
  State<_WarmLoading> createState() => _WarmLoadingState();
}

class _WarmLoadingState extends State<_WarmLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _pageBackground(context),
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: 0.4 + _controller.value * 0.6,
              child: child,
            );
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                ),
                child: Icon(
                  Icons.photo_camera_outlined,
                  size: 36,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '正在翻开您的回忆...',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════
//  错误状态
// ═══════════════════════════════════════

class _ErrorView extends StatelessWidget {
  final RandomPhotoState state;
  final WidgetRef ref;
  const _ErrorView({required this.state, required this.ref});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: _pageBackground(context),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                state.hasPermission
                    ? Icons.photo_album_outlined
                    : Icons.folder_off_outlined,
                size: 72,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                state.errorMessage ?? '未知错误',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => ref.read(photoProvider.notifier).retryPermission(),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  state.hasPermission ? '重 试' : '授 予 权 限',
                  style: const TextStyle(letterSpacing: 3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════
//  照片相册视图 — 拍立得风格
// ═══════════════════════════════════════

class _PhotoAlbumView extends StatefulWidget {
  final AssetEntity photo;
  final WidgetRef ref;
  const _PhotoAlbumView({required this.photo, required this.ref});

  @override
  State<_PhotoAlbumView> createState() => _PhotoAlbumViewState();
}

class _PhotoAlbumViewState extends State<_PhotoAlbumView> {
  int _recordRefreshKey = 0;

  AssetEntity get photo => widget.photo;
  WidgetRef get ref => widget.ref;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: _pageBackground(context),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),

            // 装饰文字 — "今日回忆"
            Text(
              '✧ 今日回忆 ✧',
              style: TextStyle(
                fontSize: 14,
                color: cs.primary.withValues(alpha: 0.7),
                letterSpacing: 6,
              ),
            ),

            const SizedBox(height: 8),

            // 拍立得卡片区域
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, anim1, anim2) =>
                            PhotoFullscreenPage(photo: photo),
                        transitionsBuilder:
                            (context, anim, secondaryAnim, child) =>
                                FadeTransition(opacity: anim, child: child),
                        transitionDuration: const Duration(milliseconds: 250),
                      ),
                    ),
                    child: _PolaroidCard(photo: photo),
                  ),
                ),
              ),
            ),

            // 删除按钮（圆形，离换一张较远防误触）
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 50),
              child: Center(
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('确认删除'),
                          content: const Text('此操作将从设备相册中彻底移除该照片，无法撤销。'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('取消'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
                              child: const Text('删除'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        ref.read(photoProvider.notifier).deleteCurrentPhoto();
                      }
                    },
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: '删除照片',
                    style: IconButton.styleFrom(
                      foregroundColor: cs.error,
                      backgroundColor: cs.error.withValues(alpha: 0.1),
                      shape: const CircleBorder(),
                    ),
                  ),
                ),
              ),
            ),

            // 记录按钮 + 全部记录（如有）
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
              child: FutureBuilder<List<Record>>(
                key: ValueKey('records_$_recordRefreshKey'),
                future: RecordService.getByPhotoId(photo.id),
                builder: (context, snapshot) {
                  final records = snapshot.data ?? [];
                  return Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: IconButton(
                            onPressed: () => _showRecordDialog(context, photo, cs),
                            icon: const Icon(Icons.edit_note_outlined, size: 22),
                            tooltip: '添加记录',
                            style: IconButton.styleFrom(
                              foregroundColor: cs.primary,
                              backgroundColor: cs.primary.withValues(alpha: 0.1),
                              shape: const CircleBorder(),
                            ),
                          ),
                        ),
                        if (records.isNotEmpty) ...[
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: IconButton(
                              onPressed: () => _showRecordsListDialog(context, records, cs),
                              icon: const Icon(Icons.list_alt_outlined, size: 22),
                              tooltip: '全部记录 (${records.length})',
                              style: IconButton.styleFrom(
                                foregroundColor: cs.primary,
                                backgroundColor: cs.primary.withValues(alpha: 0.1),
                                shape: const CircleBorder(),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),

            // 底部按钮区
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
              child: SizedBox(
                width: 200,
                height: 48,
                child: FilledButton.icon(
                  onPressed: () => ref.read(photoProvider.notifier).refresh(),
                  icon: const Icon(Icons.shuffle, size: 20),
                  label: const Text('换 一 张'),
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 弹出记录表单（新增或编辑），返回时表单已关闭
  Future<void> _showRecordDialog(
      BuildContext context, AssetEntity photo, ColorScheme cs, {Record? editRecord}) async {
    final isEditing = editRecord != null;
    final contentCtrl = TextEditingController(text: editRecord?.content ?? '');
    final moodCtrl = TextEditingController(text: editRecord?.mood ?? '');
    final formKey = GlobalKey<FormState>();

    int? selectedColor = editRecord?.color;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(isEditing ? Icons.edit_outlined : Icons.edit_note_outlined,
                  size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Text(isEditing ? '编辑记录' : '新增记录',
                  style: const TextStyle(fontSize: 17)),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: contentCtrl,
                      decoration: const InputDecoration(
                        labelText: '记录内容',
                        hintText: '写下此刻的感受…',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 4,
                      minLines: 3,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '请输入记录内容' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: moodCtrl,
                      decoration: const InputDecoration(
                        labelText: '心情（可选）',
                        hintText: '例如：开心、😊、怀念…',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.mood_outlined),
                        counterText: '',
                      ),
                      maxLines: 1,
                      maxLength: 12,
                    ),
                    const SizedBox(height: 16),
                    // 颜色选择
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '标签颜色',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: RecordColors.all.map((c) {
                        final isSelected = selectedColor == c;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedColor = c),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: c != null ? Color(c) : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? cs.primary
                                    : cs.outlineVariant.withValues(alpha: 0.3),
                                width: isSelected ? 2.5 : 1.5,
                              ),
                              // 无色选项显示斜线示意
                            ),
                            child: c == null
                                ? Icon(Icons.close, size: 14,
                                    color: cs.onSurfaceVariant.withValues(alpha: 0.4))
                                : (isSelected
                                    ? Icon(Icons.check, size: 16, color: Colors.white)
                                    : null),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final now = DateTime.now();
              final Record record;
              if (isEditing) {
                final moodValue =
                    moodCtrl.text.trim().isEmpty ? null : moodCtrl.text.trim();
                record = Record(
                  id: editRecord.id,
                  photoId: editRecord.photoId,
                  content: contentCtrl.text.trim(),
                  mood: moodValue,
                  color: selectedColor,
                  createdAt: editRecord.createdAt,
                  updatedAt: DateTime.now(),
                );
              } else {
                record = Record(
                  photoId: photo.id,
                  content: contentCtrl.text.trim(),
                  mood: moodCtrl.text.trim().isEmpty ? null : moodCtrl.text.trim(),
                  color: selectedColor,
                  createdAt: now,
                  updatedAt: now,
                );
              }
              try {
                if (isEditing) {
                  await RecordService.update(record);
                } else {
                  await RecordService.create(record);
                }
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
                if (mounted) {
                  setState(() => _recordRefreshKey++);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 18, color: cs.onPrimary),
                          const SizedBox(width: 8),
                          const Text('记录已保存'),
                        ],
                      ),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.symmetric(horizontal: 60, vertical: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      backgroundColor: cs.primary,
                    ),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('保存失败：$e')),
                  );
                }
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
  }

  /// 弹出全部记录列表
  void _showRecordsListDialog(
      BuildContext context, List<Record> records, ColorScheme cs) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.list_alt_outlined, size: 20, color: cs.primary),
                const SizedBox(width: 8),
                Text('全部记录 (${records.length})',
                    style: const TextStyle(fontSize: 17)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final record = records[index];
                  return _RecordTile(
                    record: record,
                    colorScheme: cs,
                    onEdited: () async {
                      await _showRecordDialog(context, photo, cs, editRecord: record);
                      final updated = await RecordService.getByPhotoId(photo.id);
                      setDialogState(() {
                        records
                          ..clear()
                          ..addAll(updated);
                      });
                    },
                    onDeleted: () {
                      RecordService.delete(record.id!);
                      setDialogState(() {
                        records.removeAt(index);
                      });
                      setState(() => _recordRefreshKey++);
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('关闭'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 记录列表中的单条记录瓦片（可展开，长按弹出操作菜单）
class _RecordTile extends StatefulWidget {
  final Record record;
  final ColorScheme colorScheme;
  final VoidCallback? onDeleted;
  final VoidCallback? onEdited;

  const _RecordTile({
    required this.record,
    required this.colorScheme,
    this.onDeleted,
    this.onEdited,
  });

  @override
  State<_RecordTile> createState() => _RecordTileState();
}

class _RecordTileState extends State<_RecordTile> {
  bool _expanded = false;

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showPopupMenu() {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset offset = box.localToGlobal(Offset.zero);
    final double tileWidth = box.size.width;
    final double popupWidth = 180;

    // 计算弹出位置：气泡底部（含箭头尖）对齐条目上边缘
    final double left = offset.dx + (tileWidth - popupWidth) / 2;

    final overlay = Overlay.of(context);
    OverlayEntry? entry;

    entry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          // 透明遮罩，点击关闭
          Positioned.fill(
            child: GestureDetector(
              onTap: () => entry?.remove(),
              child: Container(color: Colors.transparent),
            ),
          ),
          // 气泡菜单（底部对齐条目顶部，自由向上生长）
          // 若上方空间不足（<160px）则显示在条目下方
          Positioned(
            left: left.clamp(8, MediaQuery.of(ctx).size.width - popupWidth - 8),
            bottom: offset.dy > 160
                ? MediaQuery.of(ctx).size.height - offset.dy - 2
                : null,
            top: offset.dy > 160 ? null : offset.dy + box.size.height + 4,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 气泡主体（带阴影和圆角）
                Material(
                  elevation: 8,
                  shadowColor: Colors.black26,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: popupWidth,
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 编辑
                        InkWell(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                          onTap: () {
                            entry?.remove();
                            widget.onEdited?.call();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 18,
                                    color: Theme.of(ctx).colorScheme.primary),
                                const SizedBox(width: 12),
                                Text('编辑记录',
                                    style: TextStyle(
                                        fontSize: 14, color: Theme.of(ctx).colorScheme.primary)),
                              ],
                            ),
                          ),
                        ),
                        Divider(height: 1,
                            color: Theme.of(ctx).colorScheme.outlineVariant.withValues(alpha: 0.3)),
                        // 删除
                        InkWell(
                          onTap: () {
                            entry?.remove();
                            _confirmDelete();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 18,
                                    color: Theme.of(ctx).colorScheme.error),
                                const SizedBox(width: 12),
                                Text('删除记录',
                                    style: TextStyle(
                                        fontSize: 14, color: Theme.of(ctx).colorScheme.error)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 箭头（在 Material 外部，不被圆角裁剪）
                Transform.translate(
                  offset: Offset(popupWidth / 2 - 6, 0),
                  child: CustomPaint(
                    size: const Size(12, 8),
                    painter: _ArrowPainter(
                      color: Theme.of(ctx).colorScheme.surface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    overlay.insert(entry);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      widget.onDeleted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final cs = widget.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _expanded = !_expanded),
        onLongPress: _showPopupMenu,
        child: AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState:
              _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    if (r.mood != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: r.color != null
                              ? Color(r.color!).withValues(alpha: 0.3)
                              : cs.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          r.mood!,
                          style: TextStyle(
                            fontSize: 12,
                            color: r.color != null
                                ? Color(r.color!).withValues(alpha: 0.9)
                                : cs.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(r.createdAt),
                  style: TextStyle(
                      fontSize: 11, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ),
          secondChild: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.content,
                  style: const TextStyle(fontSize: 14, height: 1.6),
                ),
                if (r.mood != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: r.color != null
                          ? Color(r.color!).withValues(alpha: 0.3)
                          : cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '心情：${r.mood}',
                      style: TextStyle(
                        fontSize: 12,
                        color: r.color != null
                            ? Color(r.color!).withValues(alpha: 0.9)
                            : cs.primary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  _formatDate(r.createdAt),
                  style: TextStyle(
                      fontSize: 11, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 根据当前主题返回页面背景装饰（浅色暖渐变 / 深色暗调）
BoxDecoration _pageBackground(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark
          ? [const Color(0xFF2C2420), const Color(0xFF1F1A17)]
          : [const Color(0xFFFDF6EC), const Color(0xFFF5EAE0)],
    ),
  );
}

/// 气泡箭头绘制（下三角，居中显示）
class _ArrowPainter extends CustomPainter {
  final Color color;
  static const double arrowWidth = 12;
  static const double arrowHeight = 8;

  const _ArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final centerX = size.width / 2;
    final startX = centerX - arrowWidth / 2;
    final endX = centerX + arrowWidth / 2;
    final path = Path()
      ..moveTo(startX, 0)
      ..lineTo(centerX, arrowHeight)
      ..lineTo(endX, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) => oldDelegate.color != color;
}

// ═══════════════════════════════════════
//  拍立得照片卡片
// ═══════════════════════════════════════

class _PolaroidCard extends ConsumerWidget {
  final AssetEntity photo;
  const _PolaroidCard({required this.photo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final prefs = ref.watch(photoDisplayPrefsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // 没有任何信息要显示时，省略底部区域
    final showBottom = prefs.showDate || prefs.showTitle;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3D322C) : Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : const Color(0xFF5C4033).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : const Color(0xFF5C4033).withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: AspectRatio(
                aspectRatio: 1,
                child: _PhotoWidget(photo: photo),
              ),
            ),
          ),
          if (showBottom)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (prefs.showDate)
                    Text(
                      _formatDate(photo.createDateTime),
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        letterSpacing: 2,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  if (prefs.showTitle && (photo.title?.isNotEmpty ?? false))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        photo.title!,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          letterSpacing: 1,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year} 年 ${date.month} 月 ${date.day} 日';
  }
}

// ═══════════════════════════════════════
//  照片加载组件
// ═══════════════════════════════════════

class _PhotoWidget extends StatefulWidget {
  final AssetEntity photo;
  const _PhotoWidget({required this.photo});

  @override
  State<_PhotoWidget> createState() => _PhotoWidgetState();
}

class _PhotoWidgetState extends State<_PhotoWidget> {
  Uint8List? _imageBytes;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(_PhotoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo.id != widget.photo.id) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _imageBytes = null;
    });

    try {
      final bytes = await widget.photo.thumbnailDataWithSize(
        const ThumbnailSize(800, 800),
        quality: 90,
      );
      if (mounted) {
        setState(() {
          _imageBytes = bytes;
          _isLoading = false;
          _hasError = bytes == null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
        color: isDark ? const Color(0xFF3D322C) : const Color(0xFFF0E6D8),
        child: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_hasError || _imageBytes == null) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
        color: isDark ? const Color(0xFF3D322C) : const Color(0xFFF0E6D8),
        child: Center(
          child: Icon(Icons.broken_image_outlined,
              color: Theme.of(context).colorScheme.primary),
        ),
      );
    }

    return Image.memory(
      _imageBytes!,
      fit: BoxFit.cover,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 400),
          child: child,
        );
      },
    );
  }
}

// ═══════════════════════════════════════
//  照片详情面板内容
// ═══════════════════════════════════════

class _DrawerContent extends StatelessWidget {
  final AssetEntity photo;
  final Uint8List? preloadedThumbnail;
  final File? preloadedFile;
  final Map<String, IfdTag>? preloadedExif;

  const _DrawerContent({
    required this.photo,
    this.preloadedThumbnail,
    this.preloadedFile,
    this.preloadedExif,
  });

  @override
  Widget build(BuildContext context) {
    final created = photo.createDateTime;
    final modified = photo.modifiedDateTime;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // ── 顶部标题栏 ──
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: colorScheme.primary),
                onPressed: () {
                  _SlidingPanelState? state =
                      context.findAncestorStateOfType<_SlidingPanelState>();
                  state?.close();
                },
              ),
              const SizedBox(width: 4),
              Text(
                '照片详情',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.primary,
                  decoration: TextDecoration.none,
                  decorationColor: Colors.transparent,
                  decorationThickness: 0,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // ── 可滚动内容 ──
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              // 照片缩略图
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: isDark
                          ? const Color(0xFF3D322C)
                          : const Color(0xFFF0E6D8),
                    ),
                    child: _PanelPhotoWidget(
                      photo: photo,
                      preloadedBytes: preloadedThumbnail,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 元数据卡片
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.12),
                  ),
                ),
                color: isDark
                    ? const Color(0xFF3D322C)
                    : Colors.white.withValues(alpha: 0.85),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      _buildTile(Icons.badge_outlined, '照片 ID', photo.id, colorScheme),
                      _divider(colorScheme),
                      _buildTile(Icons.description_outlined, '文件名', photo.title ?? '未命名', colorScheme),
                      _divider(colorScheme),
                      _buildTile(Icons.image_outlined, '文件类型', _formatMimeType(photo.mimeType), colorScheme),
                      _divider(colorScheme),
                      _FileSizeTile(
                        photo: photo,
                        colorScheme: colorScheme,
                        preloadedFile: preloadedFile,
                      ),
                      _divider(colorScheme),
                      _buildTile(Icons.calendar_today, '拍摄时间', _formatDate(created), colorScheme),
                      if (modified != created) ...[
                        _divider(colorScheme),
                        _buildTile(Icons.update, '修改时间', _formatDate(modified), colorScheme),
                      ],
                      _divider(colorScheme),
                      _buildTile(Icons.aspect_ratio_outlined, '分辨率', '${photo.width} × ${photo.height}', colorScheme),
                      _divider(colorScheme),
                      _buildTile(Icons.category_outlined, '资源类型', _formatAssetType(photo.type), colorScheme),
                      _divider(colorScheme),
                      _buildTile(Icons.folder_outlined, '路径', photo.relativePath ?? '未知', colorScheme),
                      if (photo.type == AssetType.video && photo.duration > 0) ...[
                        _divider(colorScheme),
                        _buildTile(Icons.timer_outlined, '时长', _formatVideoDuration(Duration(seconds: photo.duration)), colorScheme),
                      ],
                      _divider(colorScheme),
                      _ExifTile(
                        photo: photo,
                        colorScheme: colorScheme,
                        preloadedExif: preloadedExif,
                        preloadedFile: preloadedFile,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTile(IconData icon, String label, String value, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: cs.primary.withValues(alpha: 0.7)),
          const SizedBox(width: 10),
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Divider(
        height: 1,
        color: cs.outlineVariant.withValues(alpha: 0.2),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }

  String _formatMimeType(String? mime) {
    if (mime == null) return '未知';
    switch (mime) {
      case 'image/jpeg': return 'JPEG 图片';
      case 'image/png': return 'PNG 图片';
      case 'image/gif': return 'GIF 动图';
      case 'image/heic': case 'image/heif': return 'HEIC 图片';
      case 'image/webp': return 'WebP 图片';
      case 'image/bmp': return 'BMP 位图';
      case 'video/mp4': return 'MP4 视频';
      case 'video/quicktime': return 'MOV 视频';
      default: return mime;
    }
  }

  String _formatAssetType(AssetType type) {
    switch (type) {
      case AssetType.image: return '图片';
      case AssetType.video: return '视频';
      case AssetType.audio: return '音频';
      case AssetType.other: return '其他';
    }
  }

  String _formatVideoDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) return '$hours时$minutes分$seconds秒';
    return '$minutes分$seconds秒';
  }
}

/// 异步加载文件大小组件
class _FileSizeTile extends StatelessWidget {
  final AssetEntity photo;
  final ColorScheme colorScheme;
  final File? preloadedFile;

  const _FileSizeTile({
    required this.photo,
    required this.colorScheme,
    this.preloadedFile,
  });

  @override
  Widget build(BuildContext context) {
    // 预加载文件可用时直接使用，否则异步加载
    if (preloadedFile != null) {
      return _buildTile(preloadedFile!.lengthSync());
    }
    return FutureBuilder<File?>(
      future: photo.file,
      builder: (context, snapshot) {
        final fileBytes = (snapshot.connectionState == ConnectionState.done &&
                snapshot.data != null)
            ? snapshot.data!.lengthSync()
            : null;
        return _buildTile(fileBytes);
      },
    );
  }

  Widget _buildTile(int? fileBytes) {
    return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.storage_outlined,
                  size: 18, color: colorScheme.primary.withValues(alpha: 0.7)),
              const SizedBox(width: 10),
              SizedBox(
                width: 60,
                child: Text(
                  '文件大小',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  fileBytes != null
                      ? _formatBytes(fileBytes)
                      : '加载中…',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        );
    }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

/// 拍摄参数（EXIF）显示组件
class _ExifTile extends StatelessWidget {
  final AssetEntity photo;
  final ColorScheme colorScheme;
  final Map<String, IfdTag>? preloadedExif;
  final File? preloadedFile;

  const _ExifTile({
    required this.photo,
    required this.colorScheme,
    this.preloadedExif,
    this.preloadedFile,
  });

  /// 需要显示的拍摄参数字段及对应中文标签
  static const _exifFields = <String, String>{
    'Image Make': '相机品牌',
    'Image Model': '相机型号',
    'EXIF FNumber': '光圈',
    'EXIF ISOSpeedRatings': 'ISO',
    'EXIF ExposureTime': '快门速度',
    'EXIF FocalLength': '焦距',
    'EXIF ExposureBiasValue': '曝光补偿',
    'EXIF Flash': '闪光灯',
    'EXIF MeteringMode': '测光模式',
    'EXIF WhiteBalance': '白平衡',
    'Image Software': '软件',
  };

  @override
  Widget build(BuildContext context) {
    // 没有预加载数据时异步加载
    if (preloadedExif == null) {
      return FutureBuilder<Map<String, IfdTag>?>(
        future: _loadExif(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox.shrink();
          }
          final tags = snapshot.data;
          if (tags == null || tags.isEmpty) return const SizedBox.shrink();
          return _buildExifContent(tags);
        },
      );
    }
    return _buildExifContent(preloadedExif!);
  }

  /// 使用已准备好的 EXIF 数据构建内容
  Widget _buildExifContent(Map<String, IfdTag> tags) {
    // 过滤出有数据的拍摄参数字段
    final entries = _exifFields.entries.where((e) {
      final tag = tags[e.key];
      return tag != null && tag.printable.isNotEmpty;
    }).toList();

    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
          children: [
            // 小标题
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(
                children: [
                  Icon(Icons.camera_alt_outlined,
                      size: 16, color: colorScheme.primary.withValues(alpha: 0.6)),
                  const SizedBox(width: 6),
                  Text(
                    '拍摄参数',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            // 参数行
            ...entries.map((e) {
              final label = e.value;
              final value = _formatExifValue(e.key, tags[e.key]!.printable);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_iconForField(e.key),
                        size: 18, color: colorScheme.primary.withValues(alpha: 0.7)),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 60,
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
  }

  Future<Map<String, IfdTag>?> _loadExif() async {
    try {
      // 优先使用预加载文件，跳过 photo.file（最慢的步骤）
      final file = preloadedFile ?? await photo.file;
      if (file == null) return null;
      return await readExifFromFile(file);
    } catch (_) {
      return null;
    }
  }

  /// 格式化特定 EXIF 字段为友好文字
  String _formatExifValue(String key, String raw) {
    if (key == 'EXIF FNumber') {
      final parts = raw.split('/');
      if (parts.length == 2) {
        final num = double.tryParse(parts[0]);
        final den = double.tryParse(parts[1]);
        if (num != null && den != null && den > 0) {
          return 'f/${(num / den).toStringAsFixed(1)}';
        }
      }
      return raw;
    }
    if (key == 'EXIF FocalLength') {
      final parts = raw.split('/');
      if (parts.length == 2) {
        final num = double.tryParse(parts[0]);
        final den = double.tryParse(parts[1]);
        if (num != null && den != null && den > 0) {
          return '${(num / den).toStringAsFixed(1)}mm';
        }
      }
      return '${raw}mm';
    }
    if (key == 'EXIF ExposureBiasValue') {
      final parts = raw.split('/');
      if (parts.length == 2) {
        final num = double.tryParse(parts[0]);
        final den = double.tryParse(parts[1]);
        if (num != null && den != null && den > 0) {
          final val = num / den;
          if (val > 0) return '+${val.toStringAsFixed(1)} EV';
          return '${val.toStringAsFixed(1)} EV';
        }
      }
      return '$raw EV';
    }
    if (key == 'EXIF ISOSpeedRatings') return 'ISO $raw';
    if (key == 'EXIF Flash') {
      // 将 EXIF 闪光灯英文值转为中文
      const flashMap = <String, String>{
        'Flash did not fire': '未闪光',
        'No Flash': '未闪光',
        'Flash fired': '已闪光',
        'Flash fired, compulsory flash mode': '强制闪光',
        'Flash fired, auto mode': '自动闪光',
        'Flash fired, red-eye reduction': '防红眼闪光',
        'Flash fired, return light detected': '已闪光',
        'Flash fired, return light not detected': '已闪光',
        'No flash function': '无闪光功能',
        'Compulsory flash mode': '强制闪光',
      };
      if (flashMap.containsKey(raw)) return flashMap[raw]!;
      if (raw.contains('not fire')) return '未闪光';
      return raw;
    }
    if (key == 'EXIF MeteringMode') {
      // 将 EXIF 测光模式英文值转为中文
      const meterMap = <String, String>{
        'Unidentified': '未识别',
        'Average': '平均测光',
        'CenterWeightedAverage': '中央重点测光',
        'Spot': '点测光',
        'MultiSpot': '多点测光',
        'Pattern': '矩阵测光',
        'Partial': '局部测光',
        'other': '其他',
      };
      return meterMap[raw] ?? raw;
    }
    if (key == 'EXIF ExposureTime') {
      // 快门速度：EXIF 以分数存储，如 "1/60" 或 "30/1"
      final parts = raw.split('/');
      if (parts.length == 2) {
        final n = double.tryParse(parts[0]);
        final d = double.tryParse(parts[1]);
        if (n != null && d != null && d > 0) {
          if (n <= 0 || d <= 0) return '${raw}s';
          final seconds = n / d;
          if (seconds >= 1) {
            // ≥1 秒：整数显示 "30s"，小数显示 "1.5s"
            if (seconds == seconds.roundToDouble()) {
              return '${seconds.toInt()}s';
            }
            return '${seconds.toStringAsFixed(1)}s';
          }
          // <1 秒：转为常见分数形式 "1/125"
          final den = (1 / seconds).round();
          return '1/${den}s';
        }
      }
      return '${raw}s';
    }
    return raw;
  }

  /// 每个字段对应的图标
  IconData _iconForField(String key) {
    switch (key) {
      case 'Image Make':
      case 'Image Model':
        return Icons.videocam_outlined;
      case 'EXIF FNumber':
        return Icons.blur_on_outlined;
      case 'EXIF ISOSpeedRatings':
        return Icons.wb_sunny_outlined;
      case 'EXIF ExposureTime':
        return Icons.timer_outlined;
      case 'EXIF FocalLength':
        return Icons.straighten_outlined;
      case 'EXIF ExposureBiasValue':
        return Icons.tune_outlined;
      case 'EXIF Flash':
        return Icons.flash_on_outlined;
      case 'EXIF MeteringMode':
        return Icons.center_focus_strong_outlined;
      case 'EXIF WhiteBalance':
        return Icons.brightness_5_outlined;
      case 'Image Software':
        return Icons.code_outlined;
      default:
        return Icons.info_outline;
    }
  }
}

/// 面板内嵌照片加载组件
class _PanelPhotoWidget extends StatefulWidget {
  final AssetEntity photo;
  final Uint8List? preloadedBytes;

  const _PanelPhotoWidget({
    required this.photo,
    this.preloadedBytes,
  });

  @override
  State<_PanelPhotoWidget> createState() => _PanelPhotoWidgetState();
}

class _PanelPhotoWidgetState extends State<_PanelPhotoWidget> {
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _imageBytes = widget.preloadedBytes; // 直接使用预加载数据
    if (_imageBytes == null) _loadImage();
  }

  @override
  void didUpdateWidget(_PanelPhotoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo.id != widget.photo.id) {
      _imageBytes = widget.preloadedBytes; // 新照片的预加载数据
      if (_imageBytes == null) _loadImage();
    }
  }

  Future<void> _loadImage() async {
    final bytes = await widget.photo.thumbnailDataWithSize(
      const ThumbnailSize(320, 320),
      quality: 90,
    );
    if (mounted) setState(() => _imageBytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    if (_imageBytes == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return Image.memory(
      _imageBytes!,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const Center(
        child: Icon(Icons.broken_image_outlined, color: Colors.grey),
      ),
    );
  }
}
