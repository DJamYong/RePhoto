part of '../home_page.dart';

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

    final double left = offset.dx + (tileWidth - popupWidth) / 2;

    final overlay = Overlay.of(context);
    OverlayEntry? entry;

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
            left: left.clamp(8, MediaQuery.of(ctx).size.width - popupWidth - 8),
            bottom: offset.dy > 160
                ? MediaQuery.of(ctx).size.height - offset.dy - 2
                : null,
            top: offset.dy > 160 ? null : offset.dy + box.size.height + 4,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
