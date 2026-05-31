part of '../home_page.dart';

// 心情 Emoji 映射表复用 widget/mood_selector.dart 中定义的 moodEmojiMap

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
            Text('✧ 今日回忆 ✧',
              style: TextStyle(fontSize: 16, color: cs.primary.withValues(alpha: 0.7), letterSpacing: 6),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, anim1, anim2) => PhotoFullscreenPage(photo: photo),
                        transitionsBuilder: (context, anim, secondaryAnim, child) => FadeTransition(opacity: anim, child: child),
                        transitionDuration: const Duration(milliseconds: 250),
                      ),
                    ),
                    child: _PolaroidCard(photo: photo),
                  ),
                ),
              ),
            ),
            // 删除按钮
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 50),
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
                      if (confirmed == true) ref.read(photoProvider.notifier).deleteCurrentPhoto();
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
            // 换一张
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
              child: SizedBox(width: 200, height: 48,
                child: FilledButton.icon(
                  onPressed: () => ref.read(photoProvider.notifier).refresh(),
                  icon: const Icon(Icons.shuffle, size: 20),
                  label: const Text('换 一 张'),
                  style: FilledButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    textStyle: const TextStyle(fontSize: 15, letterSpacing: 3)),
                ),
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
        builder: (ctx, setDialogState) => AlertDialog(
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


