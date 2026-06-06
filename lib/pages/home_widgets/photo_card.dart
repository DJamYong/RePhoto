part of '../home_page.dart';

// ═══════════════════════════════════════
//  拍立得照片卡片
// ═══════════════════════════════════════

class _PolaroidCard extends ConsumerStatefulWidget {
  final AssetEntity photo;
  final VoidCallback? onTap;
  const _PolaroidCard({required this.photo, this.onTap});

  @override
  ConsumerState<_PolaroidCard> createState() => _PolaroidCardState();
}

class _PolaroidCardState extends ConsumerState<_PolaroidCard> {
  bool _isPressed = false;
  double _rotation = 0.0;

  // ── 手势回调 ──

  void _onTapDown(TapDownDetails d) => setState(() => _isPressed = true);

  void _onTapUp(TapUpDetails d) {
    setState(() => _isPressed = false);
    widget.onTap?.call();
  }

  void _onTapCancel() => setState(() => _isPressed = false);

  void _onLongPressStart(LongPressStartDetails d) {
    final rng = Random();
    setState(() => _rotation = (rng.nextDouble() - 0.5) * (pi / 90)); // ±1°
  }

  void _onLongPressEnd(LongPressEndDetails d) {
    setState(() => _rotation = 0.0);
  }

  // ── 构建 ──

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final prefs = ref.watch(photoDisplayPrefsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // 判断是否往年的同月同日（"此刻·彼时"）
    final now = DateTime.now();
    final taken = widget.photo.createDateTime;
    final isHistoricalMoment =
        taken.month == now.month && taken.day == now.day && taken.year != now.year;

    // 没有任何信息要显示时，省略底部区域
    final showBottom = prefs.showDate || prefs.showAge;

    return AnimatedScale(
      scale: _isPressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      child: AnimatedRotation(
        turns: _rotation / (2 * pi),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        child: GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          onLongPressStart: _onLongPressStart,
          onLongPressEnd: _onLongPressEnd,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              gradient: isDark
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF4A3F35),
                        Color(0xFF3D322C),
                        Color(0xFF342A24),
                      ],
                    )
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFFFEFB),
                        Color(0xFFF8F5F1),
                        Color(0xFFF2EDE7),
                      ],
                    ),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                // 远距离环境阴影 — 模拟照片与桌面之间的空间感
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.35)
                      : const Color(0xFF5C4033).withValues(alpha: 0.12),
                  blurRadius: 32,
                  offset: const Offset(0, 14),
                ),
                // 中距离阴影 — 卡片厚度
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.25)
                      : const Color(0xFF5C4033).withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
                // 近距离阴影 — 边缘清晰度
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.15)
                      : const Color(0xFF5C4033).withValues(alpha: 0.05),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
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
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.07),
                          width: 1,
                        ),
                      ),
                      child: Stack(
                        children: [
                          AspectRatio(
                            aspectRatio: 1,
                            child: _PhotoWidget(photo: widget.photo),
                          ),
                          // 暗角叠加 — 模拟镜头边缘减光 / 冲印质感
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    center: const Alignment(0, 0),
                                    radius: 0.75,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: isDark ? 0.25 : 0.15),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (isHistoricalMoment)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: colorScheme.primary
                                    .withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withValues(alpha: 0.15),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_awesome,
                                      size: 12,
                                      color: colorScheme.onPrimary),
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
                            _formatDate(taken),
                            style: TextStyle(
                              fontSize: 16,
                              color: colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.7),
                              letterSpacing: 2,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        if (prefs.showAge)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _formatPhotoAge(taken),
                              style: TextStyle(
                                fontSize: 15,
                                color: colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.5),
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
          ),
        ),
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

    if (totalDays == 0) return '记录于今天';
    if (totalDays < 30) return '记录于 $totalDays 天前';

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

    if (parts.isEmpty) return '记录于 $totalDays 天前';
    return '记录于 ${parts.join(' ')}前';
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

    return Hero(
      tag: 'photo_${widget.photo.id}',
      child: Image.memory(
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
      ),
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
    // 优先使用预加载数据（可能晚于 widget 创建到达）
    if (widget.preloadedBytes != null) {
      _imageBytes = widget.preloadedBytes;
    } else if (oldWidget.photo.id != widget.photo.id) {
      // 照片变了且没有预加载数据，启动 fallback
      _imageBytes = null;
      _loadImage();
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

// ═══════════════════════════════════════
//  时间对撞 — 年份分组堆叠卡片
// ═══════════════════════════════════════

class _CollisionCard extends StatefulWidget {
  final TimeCollision collision;
  final int selectedYear;
  final int currentPhotoIndex;
  final void Function(int year) onSelectYear;
  final void Function(int index) onPhotoChanged;

  const _CollisionCard({
    super.key,
    required this.collision,
    required this.selectedYear,
    required this.currentPhotoIndex,
    required this.onSelectYear,
    required this.onPhotoChanged,
  });

  @override
  State<_CollisionCard> createState() => _CollisionCardState();
}

/// 单年份照片堆组件（自管理滚动和分页）
class _YearPhotoStack extends StatefulWidget {
  final int year;
  final List<AssetEntity> photos;
  final int initialPage;
  final void Function(int index)? onPageChanged;
  const _YearPhotoStack({super.key, required this.year, required this.photos, this.initialPage = 0, this.onPageChanged});

  @override
  State<_YearPhotoStack> createState() => _YearPhotoStackState();
}

class _YearPhotoStackState extends State<_YearPhotoStack> {
  late PageController _ctrl;
  int _page = 0;

  /// 最多同时显示 7 个圆点（含省略号占位）
  static const int _maxVisibleDots = 7;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage;
    _ctrl = PageController(initialPage: widget.initialPage);
  }

  void _onPageChanged(int p) {
    if (p != _page && mounted) {
      setState(() => _page = p);
      widget.onPageChanged?.call(p);
    }
  }

  /// 生成折叠后需要显示的圆点索引列表，数量过多时用 -1 表示省略号
  List<int> _visibleDotIndices(int count) {
    if (count <= _maxVisibleDots) return List.generate(count, (i) => i);
    final result = <int>[];
    result.add(0); // 始终显示首点
    // 当前页 ±1 范围，确保不越界也不与首尾重叠
    final rangeStart = (_page - 1).clamp(1, count - 2);
    final rangeEnd = (_page + 1).clamp(1, count - 2);
    if (rangeStart > 1) result.add(-1); // 左省略号
    for (int i = rangeStart; i <= rangeEnd; i++) {
      result.add(i);
    }
    if (rangeEnd < count - 2) result.add(-1); // 右省略号
    result.add(count - 1); // 始终显示末点
    return result;
  }

  /// 构建折叠式分页圆点指示器，始终不超出 280px 宽度
  Widget _buildDotIndicator(BuildContext context, int count) {
    final cs = Theme.of(context).colorScheme;
    final indices = _visibleDotIndices(count);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: indices.map((i) {
        if (i == -1) {
          // 省略号占位（三个小点）
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: SizedBox(
              width: 12,
              height: 6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _DotPlaceholder(),
                  SizedBox(width: 2),
                  _DotPlaceholder(),
                  SizedBox(width: 2),
                  _DotPlaceholder(),
                ],
              ),
            ),
          );
        }
        final isActive = i == _page;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isActive ? 16 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isActive
                ? cs.primary
                : cs.onSurfaceVariant.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }).toList(),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final photos = widget.photos;
    final count = photos.length;

    return SizedBox(
      width: 320,
      height: 320,
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: isDark
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF4A3F35),
                          Color(0xFF3D322C),
                          Color(0xFF342A24),
                        ],
                      )
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFFFEFB),
                          Color(0xFFF8F5F1),
                          Color(0xFFF2EDE7),
                        ],
                      ),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: PageView(
                  controller: _ctrl,
                  onPageChanged: _onPageChanged,
                  children: photos.map((photo) => GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (_, a, b) => PhotoFullscreenPage(photo: photo),
                        transitionsBuilder: (_, animation, __, child) =>
                            FadeTransition(opacity: animation, child: child),
                        transitionDuration: const Duration(milliseconds: 200),
                        reverseTransitionDuration: const Duration(milliseconds: 200),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _PhotoWidget(photo: photo),
                              // 暗角叠加 — 模拟冲印质感
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: RadialGradient(
                                        center: const Alignment(0, 0),
                                        radius: 0.75,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.12),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )).toList(),
                ),
              ),
            ),
          ),
          if (count > 1)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _buildDotIndicator(context, count),
            ),
        ],
      ),
    );
  }
}

class _CollisionCardState extends State<_CollisionCard> {

  Widget _buildPhotoStack(int year) {
    final isCurrentYear = year == widget.selectedYear;
    final photos = widget.collision.groups[year]!;
    return _YearPhotoStack(
      key: ValueKey('stack_${year}_${photos.length}_${isCurrentYear ? widget.currentPhotoIndex : 0}'),
      year: year,
      photos: photos,
      initialPage: isCurrentYear ? widget.currentPhotoIndex : 0,
      onPageChanged: widget.onPhotoChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final years = widget.collision.years;
    final currentYear = widget.selectedYear;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPhotoStack(currentYear),
        const SizedBox(height: 16),
        // 年份切换按钮
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: years.map((year) {
            final isSelected = year == currentYear;
            return GestureDetector(
              onTap: () => widget.onSelectYear(year),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? cs.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? cs.primary : cs.outlineVariant.withValues(alpha: 0.3),
                  ),
                  boxShadow: isSelected ? [
                    BoxShadow(color: cs.primary.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2)),
                  ] : null,
                ),
                child: Text('$year', style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? cs.onPrimary : cs.onSurface,
                )),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        // 当前年份信息
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Column(
            key: ValueKey('${currentYear}_${widget.currentPhotoIndex}'),
            children: [
              Text(
                _buildCurrentDate(),
                style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    letterSpacing: 2, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 4),
              Text(
                '共 ${widget.collision.groups[currentYear]!.length} 张',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 获取当前查看照片的日期字符串
  String _buildCurrentDate() {
    final currentYear = widget.selectedYear;
    final photos = widget.collision.groups[currentYear]!;
    final idx = widget.currentPhotoIndex.clamp(0, photos.length - 1);
    return _formatDate(photos[idx].createDateTime);
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
}

/// 省略号中的小圆点占位（用于折叠式分页指示器）
class _DotPlaceholder extends StatelessWidget {
  const _DotPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      height: 2,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
        shape: BoxShape.circle,
      ),
    );
  }
}


