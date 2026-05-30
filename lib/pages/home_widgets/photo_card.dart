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

    // 判断是否往年的同月同日（"此刻·彼时"）
    final now = DateTime.now();
    final taken = photo.createDateTime;
    final isHistoricalMoment = taken.month == now.month && taken.day == now.day && taken.year != now.year;

    // 没有任何信息要显示时，省略底部区域
    final showBottom = prefs.showDate || prefs.showAge;

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
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: _PhotoWidget(photo: photo),
                  ),
                  if (isHistoricalMoment)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome, size: 12, color: colorScheme.onPrimary),
                            const SizedBox(width: 4),
                            Text(
                              '此刻·彼时',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onPrimary,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
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
                  if (prefs.showAge)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _formatPhotoAge(photo.createDateTime),
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          letterSpacing: 1,
                        ),
                        textAlign: TextAlign.center,
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

  /// 格式化照片年龄
  ///
  /// - < 1 个月：显示 "X 天前"
  /// - 整月：显示 "X 个月前"
  /// - 多月 + 余天：显示 "X 个月 Y 天前"
  /// - >= 1 年：显示 "X 年 Y 个月 Z 天前"（无余数时不显示天）
  String _formatPhotoAge(DateTime taken) {
    final now = DateTime.now();
    final totalDays = now.difference(taken).inDays;

    if (totalDays == 0) return '拍摄于今天';
    if (totalDays < 30) return '拍摄于 $totalDays 天前';

    // 精确计算年月日差
    var years = now.year - taken.year;
    var months = now.month - taken.month;
    var days = now.day - taken.day;

    if (days < 0) {
      months--;
      // 取上个月的最后一天
      final prevMonthEnd = DateTime(now.year, now.month, 0);
      days += prevMonthEnd.day;
    }
    if (months < 0) {
      years--;
      months += 12;
    }

    final parts = <String>[];
    if (years > 0) parts.add('$years 年');
    if (months > 0) parts.add('$months 个月');
    // if (days > 0) parts.add('$days 天');

    if (parts.isEmpty) return '拍摄于 $totalDays 天前';
    return '拍摄于 ${parts.join(' ')}前';
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
