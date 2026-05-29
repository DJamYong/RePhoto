part of '../home_page.dart';

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
//  面板内嵌照片加载组件
// ═══════════════════════════════════════

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
