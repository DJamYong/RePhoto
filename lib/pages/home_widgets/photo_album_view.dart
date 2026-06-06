part of '../home_page.dart';

// 心情 Emoji 映射表复用 widget/mood_selector.dart 中定义的 moodEmojiMap

class _PhotoAlbumView extends StatefulWidget {
  final AssetEntity photo;
  final WidgetRef ref;
  final RandomPhotoState state;
  const _PhotoAlbumView({required this.photo, required this.ref, required this.state});

  @override
  State<_PhotoAlbumView> createState() => _PhotoAlbumViewState();
}

class _PhotoAlbumViewState extends State<_PhotoAlbumView> {
  int _recordRefreshKey = 0;

  AssetEntity get photo => widget.photo;
  WidgetRef get ref => widget.ref;
  RandomPhotoState get state => widget.state;

  @override
  void didUpdateWidget(_PhotoAlbumView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 照片切换时强制刷新记录列表
    if (oldWidget.photo.id != widget.photo.id) {
      _recordRefreshKey++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: _pageBackground(context),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Text('✧ 今日回忆 ✧',
              style: TextStyle(fontSize: 16, color: cs.primary.withValues(alpha: 0.7), letterSpacing: 6),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: state.collision != null
                      ? _CollisionCard(
                          key: ValueKey('collision_${state.photo?.id}'),
                          collision: state.collision!,
                          selectedYear: state.selectedYear,
                          currentPhotoIndex: state.currentPhotoIndex,
                          onSelectYear: (y) => ref.read(photoProvider.notifier).selectCollisionYear(y),
                          onPhotoChanged: (i) => ref.read(photoProvider.notifier).selectCollisionPhoto(i),
                        )
                      : GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            PageRouteBuilder(
                              pageBuilder: (_, __, ___) => PhotoFullscreenPage(photo: photo),
                              transitionsBuilder: (_, __, ___, child) => child,
                              transitionDuration: Duration.zero,
                              reverseTransitionDuration: Duration.zero,
                            ),
                          ),
                          child: _PolaroidCard(photo: photo),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // 删除按钮
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 30),
              child: Center(
                child: SizedBox(width: 44, height: 44,
                  child: IconButton(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('确认删除'),
                          content: const Text('此操作将从设备相册中彻底移除该照片，无法撤销。'),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
                            TextButton(onPressed: () => Navigator.of(ctx).pop(true),
                              style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
                              child: const Text('删除')),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        final ok = await ref.read(photoProvider.notifier).deleteCurrentPhoto();
                        if (!ok && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('删除失败，请检查相册权限')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: '删除照片',
                    style: IconButton.styleFrom(foregroundColor: cs.error, backgroundColor: cs.error.withValues(alpha: 0.1), shape: const CircleBorder()),
                  ),
                ),
              ),
            ),
            // 记录按钮 + 全部记录
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
              child: FutureBuilder<List<Record>>(
                key: ValueKey('records_${photo.id}_$_recordRefreshKey'),
                future: RecordService.getByPhotoId(photo.id),
                builder: (context, snapshot) {
                  final records = snapshot.data ?? [];
                  return Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 44, height: 44,
                          child: IconButton(
                            onPressed: () => _showRecordDialog(context, photo, cs),
                            icon: const Icon(Icons.edit_note_outlined, size: 22),
                            tooltip: '添加记录',
                            style: IconButton.styleFrom(foregroundColor: cs.primary, backgroundColor: cs.primary.withValues(alpha: 0.1), shape: const CircleBorder()),
                          ),
                        ),
                        if (records.isNotEmpty) ...[
                          const SizedBox(width: 16),
                          SizedBox(width: 44, height: 44,
                            child: IconButton(
                              onPressed: () => _showRecordsListDialog(context, records, cs),
                              icon: const Icon(Icons.list_alt_outlined, size: 22),
                              tooltip: '全部记录 (${records.length})',
                              style: IconButton.styleFrom(foregroundColor: cs.primary, backgroundColor: cs.primary.withValues(alpha: 0.1), shape: const CircleBorder()),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            // 换一张 + 历史抽取
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 180, height: 48,
                    child: FilledButton.icon(
                      onPressed: () => ref.read(photoProvider.notifier).refresh(),
                      icon: const Icon(Icons.shuffle, size: 20),
                      label: const Text('换 一 张'),
                      style: FilledButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        textStyle: const TextStyle(fontSize: 15, letterSpacing: 3)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(width: 44, height: 44,
                    child: IconButton(
                      onPressed: () => _showHistoryDialog(context),
                      icon: const Icon(Icons.history, size: 22),
                      tooltip: '历史抽取',
                      style: IconButton.styleFrom(foregroundColor: cs.primary, backgroundColor: cs.primary.withValues(alpha: 0.1), shape: const CircleBorder()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 弹出记录表单（新增或编辑）
  Future<void> _showRecordDialog(BuildContext context, AssetEntity photo, ColorScheme cs, {Record? editRecord}) async {
    final isEditing = editRecord != null;
    final contentCtrl = TextEditingController(text: editRecord?.content ?? '');
    final formKey = GlobalKey<FormState>();
    int? selectedColor = editRecord?.color;
    String? selectedMood = editRecord?.mood;


    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => GestureDetector(
          onTap: () => FocusScope.of(ctx).unfocus(),
          child: AlertDialog(
            title: Row(children: [
              Icon(isEditing ? Icons.edit_outlined : Icons.edit_note_outlined, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Text(isEditing ? '编辑记录' : '新增记录', style: const TextStyle(fontSize: 17)),
            ]),
            content: SingleChildScrollView(
              child: Form(
              key: formKey,
              child: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(controller: contentCtrl,
                      decoration: const InputDecoration(labelText: '记录内容', hintText: '写下此刻的感受…', border: OutlineInputBorder(), alignLabelWithHint: true),
                      maxLines: 4, minLines: 3,
                      validator: (v) => (v == null || v.trim().isEmpty) ? '请输入记录内容' : null),
                    const SizedBox(height: 16),
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
                        final isSelected = selectedColor == c;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedColor = c),
                          child: Container(width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: c != null ? Color(c) : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(color: isSelected ? cs.primary : cs.outlineVariant.withValues(alpha: 0.3), width: isSelected ? 2.5 : 1.5),
                            ),
                            child: c == null
                                ? Icon(Icons.close, size: 14, color: cs.onSurfaceVariant.withValues(alpha: 0.4))
                                : (isSelected ? Icon(Icons.check, size: 16, color: Colors.white) : null),
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
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final now = DateTime.now();
                final moodValue = composeMood(selectedMood);
                final Record record;
                if (isEditing) {
                  record = Record(id: editRecord.id, photoId: editRecord.photoId,
                    content: contentCtrl.text.trim(),
                    mood: moodValue,
                    color: selectedColor, createdAt: editRecord.createdAt, updatedAt: DateTime.now());
                } else {
                  record = Record(photoId: photo.id,
                    content: contentCtrl.text.trim(),
                    mood: moodValue,
                    color: selectedColor, createdAt: now, updatedAt: now);
                }
                try {
                  if (isEditing) { await RecordService.update(record); }
                  else { await RecordService.create(record); }
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (mounted) {
                    setState(() => _recordRefreshKey++);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.check_circle, size: 18, color: cs.onPrimary),
                        const SizedBox(width: 8), const Text('记录已保存'),
                      ]),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.symmetric(horizontal: 60, vertical: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      backgroundColor: cs.primary,
                    ));
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('保存失败：$e')));
                  }
                }
              },
              child: const Text('保存'),
            ),
          ],
          ),
        ),
      ),
    );
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

  /// 弹出全部记录列表
  /// 弹出近24小时浏览记录列表
  void _showHistoryDialog(BuildContext context) async {
    final entries = ref.read(photoProvider.notifier).getRecentHistory();
    if (entries.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('暂无浏览记录'),
          duration: Duration(seconds: 2),
        ));
      }
      return;
    }

    if (!context.mounted) return;
    final cs = Theme.of(context).colorScheme;

    // 先弹窗，再异步加载缩略图
    showDialog(
      context: context,
      builder: (ctx) => _HistoryDialogContent(
        entries: entries,
        colorScheme: cs,
        onTap: (photoId, isCollision) {
          Navigator.of(ctx).pop();
          ref.read(photoProvider.notifier).loadByPhotoId(photoId, isCollision: isCollision);
        },
      ),
    );
  }

  void _showRecordsListDialog(BuildContext context, List<Record> records, ColorScheme cs) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Row(children: [
              Icon(Icons.list_alt_outlined, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Text('全部记录 (${records.length})', style: const TextStyle(fontSize: 17)),
            ]),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final record = records[index];
                  return RecordTileWidget(
                    record: record, colorScheme: cs,
                    onEdited: () async {
                      await _showRecordDialog(context, photo, cs, editRecord: record);
                      final updated = await RecordService.getByPhotoId(photo.id);
                      setDialogState(() { records..clear()..addAll(updated); });
                    },
                    onDeleted: () {
                      RecordService.delete(record.id!);
                      setDialogState(() { records.removeAt(index); });
                      setState(() => _recordRefreshKey++);
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('关闭')),
            ],
          );
        },
      ),
    );
  }
}

/// 历史抽取列表项 — 异步加载缩略图
class _HistoryTile extends StatefulWidget {
  final RecentEntry entry;
  final VoidCallback onTap;
  final PhotoService? photoService;

  const _HistoryTile({
    required this.entry,
    required this.onTap,
    this.photoService,
  });

  @override
  State<_HistoryTile> createState() => _HistoryTileState();
}

class _HistoryTileState extends State<_HistoryTile> {
  Uint8List? _thumb;
  bool _loading = true;

  RecentEntry get _entry => widget.entry;

  @override
  void initState() {
    super.initState();
    if (_entry.thumbnail != null) {
      _thumb = _entry.thumbnail;
      _loading = false;
    } else {
      _loadThumb();
    }
  }

  Future<void> _loadThumb() async {
    final service = widget.photoService ?? PhotoService();
    final entity = await service.getPhotoById(_entry.photoId);
    if (entity != null && mounted) {
      final thumb = await entity.thumbnailDataWithSize(
        const ThumbnailSize(120, 120), quality: 85,
      );
      if (mounted) setState(() { _thumb = thumb; _loading = false; });
    } else if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final timeStr = _formatTime(_entry.viewedAt);

    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(width: 48, height: 48,
          child: _loading
              ? Center(child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary)))
              : (_thumb != null
                  ? Image.memory(_thumb!, fit: BoxFit.cover)
                  : Icon(Icons.broken_image_outlined, color: cs.onSurfaceVariant)),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_entry.isCollision) ...[const SizedBox(width: 4), Icon(Icons.swap_horiz, size: 14, color: cs.primary)],
          const SizedBox(width: 4),
          Text(timeStr, style: TextStyle(fontSize: 14, color: cs.onSurface)),
        ],
      ),
      trailing: Icon(Icons.chevron_right, size: 18, color: cs.onSurfaceVariant),
      onTap: widget.onTap,
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

/// 历史抽取弹窗内容 — 先弹窗，后异步加载缩略图
class _HistoryDialogContent extends StatefulWidget {
  final List<RecentEntry> entries;
  final ColorScheme colorScheme;
  final void Function(String photoId, bool isCollision) onTap;

  const _HistoryDialogContent({
    required this.entries,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  State<_HistoryDialogContent> createState() => _HistoryDialogContentState();
}

class _HistoryDialogContentState extends State<_HistoryDialogContent> {
  final _photoService = PhotoService();

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    return AlertDialog(
      title: Row(children: [
        Icon(Icons.history, size: 20, color: cs.primary),
        const SizedBox(width: 8),
        Text('历史抽取 (${widget.entries.length})', style: const TextStyle(fontSize: 17)),
      ]),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: min(widget.entries.length, 10),
          itemBuilder: (context, index) {
            final e = widget.entries[index];
            return _HistoryTile(
              entry: e,
              photoService: _photoService,
              onTap: () => widget.onTap(e.photoId, e.isCollision),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('关闭')),
      ],
    );
  }
}


