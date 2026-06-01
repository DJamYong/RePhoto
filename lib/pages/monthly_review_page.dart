import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../services/review_service.dart';
import '../models/record.dart';

/// 月度回顾页面 — 全屏沉浸式 PageView
class MonthlyReviewPage extends StatefulWidget {
  final int year;
  final int month;
  final bool isAnnual;

  const MonthlyReviewPage({
    super.key,
    required this.year,
    required this.month,
    this.isAnnual = false,
  });

  @override
  State<MonthlyReviewPage> createState() => _MonthlyReviewPageState();
}

class _MonthlyReviewPageState extends State<MonthlyReviewPage> {
  late final PageController _pageCtrl;
  int _currentPage = 0;
  Map<String, int>? _overview;
  List<MapEntry<int, int>>? _dailyViews;
  Set<int>? _recordDays;
  List<MapEntry<String, int>>? _moods;
  List<MapEntry<String, int>>? _topPhotos;
  List<Record>? _records;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _pageCtrl.addListener(() {
      final p = _pageCtrl.page?.round() ?? 0;
      if (p != _currentPage) setState(() => _currentPage = p);
    });
    _loadData();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final y = widget.year, m = widget.month;
    final results = await Future.wait([
      ReviewService.getMonthlyOverview(y, m),
      ReviewService.getDailyViews(y, m),
      ReviewService.getRecordDays(y, m),
      ReviewService.getMoodDistribution(y, m),
      ReviewService.getTopPhotoIds(y, m),
      ReviewService.getAllRecordsInMonth(y, m),
    ]);
    if (mounted) {
      setState(() {
        _overview = results[0] as Map<String, int>;
        _dailyViews = results[1] as List<MapEntry<int, int>>;
        _recordDays = results[2] as Set<int>;
        _moods = results[3] as List<MapEntry<String, int>>;
        _topPhotos = results[4] as List<MapEntry<String, int>>;
        _records = results[5] as List<Record>;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : PageView(
              controller: _pageCtrl,
              scrollDirection: Axis.vertical,
              children: [
                _CoverPage(year: widget.year, month: widget.month, cs: cs),
                _OverviewPage(data: _overview!, cs: cs),
                _DailyChartPage(data: _dailyViews!, cs: cs),
                _CalendarPage(recordDays: _recordDays!, cs: cs),
                _MoodPage(data: _moods!, cs: cs),
                _PhotoGridPage(data: _topPhotos!, cs: cs),
                _TextPage(records: _records!, cs: cs),
              ],
            ),
          // 底部 1/3 区域手势翻页（优先于页面内滚动）
          if (!_loading)
            Positioned(
              bottom: 0, left: 0, right: 0,
              height: MediaQuery.of(context).size.height / 3,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity == null) return;
                  if (details.primaryVelocity! < -200 && _currentPage < 6) {
                    _pageCtrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                  } else if (details.primaryVelocity! > 200 && _currentPage > 0) {
                    _pageCtrl.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                  }
                },
                child: Container(color: Colors.transparent),
              ),
            ),
          // 关闭按钮
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: IconButton(
              icon: Icon(Icons.close, color: cs.onSurface.withValues(alpha: 0.6)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          // 上下翻页按钮（悬浮于页面之上，半透明不遮挡内容）
          if (!_loading)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 0, right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_currentPage > 0)
                    _NavButton(
                      icon: Icons.keyboard_arrow_up_rounded,
                      onTap: () => _pageCtrl.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      ),
                    ),
                  const SizedBox(width: 8),
                  if (_currentPage < 6)
                    _NavButton(
                      icon: Icons.keyboard_arrow_down_rounded,
                      onTap: () => _pageCtrl.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════
//  屏 1：封面
// ═══════════════════════════════════════

class _CoverPage extends StatelessWidget {
  final int year, month;
  final ColorScheme cs;
  const _CoverPage({required this.year, required this.month, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [cs.primary.withValues(alpha: 0.15), cs.surface],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 56),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$year 年 $month 月',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w300, color: cs.primary, letterSpacing: 4)),
            const SizedBox(height: 16),
            Text('你的回忆', style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
            const Spacer(),
            Icon(Icons.keyboard_arrow_down_rounded, size: 28, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
            const SizedBox(height: 24),
          ],
        ),
      ),
      ),
    );
  }
}

// ═══════════════════════════════════════
//  屏 2：总览数字
// ═══════════════════════════════════════

class _OverviewPage extends StatelessWidget {
  final Map<String, int> data;
  final ColorScheme cs;
  const _OverviewPage({required this.data, required this.cs});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('🖼️', '翻看照片', '${data['viewedPhotos']} 张'),
      ('✍️', '写过记录', '${data['recordedPhotos']} 张'),
      ('📝', '共写文字', '${data['totalChars']} 字'),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 56),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: items.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 40),
            child: Row(
              children: [
                Text(e.$1, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 16),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.$2, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                  Text(e.$3, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: cs.onSurface)),
                ]),
              ],
            ),
          )).toList(),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════
//  屏 3：每日翻看频率
// ═══════════════════════════════════════

class _DailyChartPage extends StatelessWidget {
  final List<MapEntry<int, int>> data;
  final ColorScheme cs;
  const _DailyChartPage({required this.data, required this.cs});

  @override
  Widget build(BuildContext context) {
    final total = data.fold(0, (s, e) => s + e.value);
    final maxVal = data.isEmpty ? 1 : data.map((e) => e.value).reduce(max);
    final bestDay = data.isEmpty ? null : data.reduce((a, b) => a.value > b.value ? a : b);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 56),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Text('📊 每日翻看频率', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: cs.onSurface)),
            const SizedBox(height: 8),
            Text('本月翻看 $total 次 · 覆盖 ${data.length} 天', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            if (bestDay != null) ...[
              const SizedBox(height: 4),
              Text('最活跃的一天：${bestDay.key} 号（${bestDay.value} 次）',
                  style: TextStyle(fontSize: 12, color: cs.primary.withValues(alpha: 0.8))),
            ],
            const SizedBox(height: 24),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // Y 轴标注
                    Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text('$maxVal', textAlign: TextAlign.right,
                              style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant.withValues(alpha: 0.5))),
                        ),
                        const Spacer(),
                        Text('0', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant.withValues(alpha: 0.5))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // 柱状图区域
                    Expanded(
                      child: CustomPaint(
                        painter: _BarChartPainter(data, maxVal, cs.primary, cs.surfaceContainerHighest.withValues(alpha: 0.3)),
                        child: Container(),
                      ),
                    ),
                    // X 轴日期标注（首/中/尾）
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('1', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant.withValues(alpha: 0.5))),
                        const Spacer(),
                        Text('15', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant.withValues(alpha: 0.5))),
                        const Spacer(),
                        Text('31', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant.withValues(alpha: 0.5))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<MapEntry<int, int>> data;
  final int maxVal;
  final Color barColor;
  final Color gridColor;
  _BarChartPainter(this.data, this.maxVal, this.barColor, this.gridColor);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final barW = size.width / 31;
    final chartH = size.height - 20;

    // 网格线
    final gridPaint = Paint()..color = gridColor;
    for (var i = 0; i <= 4; i++) {
      final y = size.height - 20 - (chartH / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 柱子
    final barPaint = Paint()..color = barColor.withValues(alpha: 0.75);
    for (final e in data) {
      final h = (e.value / maxVal) * chartH;
      final x = (e.key - 1) * barW + 2;
      final y = size.height - 20 - h;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, barW - 4, h), const Radius.circular(3)), barPaint);

      // 数值标注
      if (e.value > 0) {
        TextPainter tp = TextPainter(
          text: TextSpan(text: '${e.value}', style: TextStyle(color: barColor, fontSize: 9)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + (barW - 4 - tp.width) / 2, y - tp.height - 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ═══════════════════════════════════════
//  屏 4：记录日历热力图
// ═══════════════════════════════════════

class _CalendarPage extends StatelessWidget {
  final Set<int> recordDays;
  final ColorScheme cs;
  const _CalendarPage({required this.recordDays, required this.cs});

  @override
  Widget build(BuildContext context) {
    final streak = ReviewService.maxConsecutiveDays(recordDays);
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Text('📈 记录创作日历', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: cs.onSurface)),
          if (streak >= 3) ...[
            const SizedBox(height: 8),
            Text('连续写了 $streak 天 🔥', style: TextStyle(fontSize: 14, color: Colors.orange)),
          ],
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: 31,
              itemBuilder: (_, i) {
                final day = i + 1;
                final hasRecord = recordDays.contains(day);
                return Container(
                  decoration: BoxDecoration(
                    color: hasRecord ? cs.primary.withValues(alpha: 0.5) : cs.surfaceContainerHighest.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text('$day', style: TextStyle(fontSize: 12, color: hasRecord ? cs.onPrimary : cs.onSurfaceVariant)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 14, height: 14, decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 4),
              Text('无记录', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              const SizedBox(width: 16),
              Container(width: 14, height: 14, decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 4),
              Text('有记录', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════
//  屏 5：情绪分布
// ═══════════════════════════════════════

class _MoodPage extends StatelessWidget {
  final List<MapEntry<String, int>> data;
  final ColorScheme cs;
  const _MoodPage({required this.data, required this.cs});

  @override
  Widget build(BuildContext context) {
    final total = data.fold(0, (s, e) => s + e.value);
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Text('🎭 本月情绪光谱', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: cs.onSurface)),
          const SizedBox(height: 24),
          ...data.take(6).map((e) {
            final pct = total > 0 ? (e.value / total * 100).toStringAsFixed(0) : '0';
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 6),
              child: Row(
                children: [
                  SizedBox(width: 80, child: Text(e.key, style: TextStyle(fontSize: 13, color: cs.onSurface))),
                  Expanded(
                    child: Container(
                      height: 22,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: total > 0 ? e.value / total : 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(width: 36, child: Text('$pct%', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════
//  屏 6：精选照片网格
// ═══════════════════════════════════════

class _PhotoGridPage extends StatelessWidget {
  final List<MapEntry<String, int>> data;
  final ColorScheme cs;
  const _PhotoGridPage({required this.data, required this.cs});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Text('📸 本月合集', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: cs.onSurface)),
          const SizedBox(height: 16),
          Expanded(
            child: data.isEmpty
                ? Center(child: Text('暂无记录', style: TextStyle(color: cs.onSurfaceVariant)))
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6,
                    ),
                    itemCount: data.length,
                    itemBuilder: (_, i) => _PhotoThumb(photoId: data[i].key, label: '${data[i].value}条'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final String photoId;
  final String label;
  const _PhotoThumb({required this.photoId, required this.label});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AssetEntity?>(
      future: AssetEntity.fromId(photoId),
      builder: (_, snap) {
        if (snap.data == null) {
          return Container(
            decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.image_outlined, size: 24, color: Colors.grey),
          );
        }
        return FutureBuilder<Uint8List?>(
          future: snap.data!.thumbnailDataWithSize(const ThumbnailSize(200, 200), quality: 70),
          builder: (_, s) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (s.data != null) Image.memory(s.data!, fit: BoxFit.cover)
                  else Container(color: Colors.grey.withValues(alpha: 0.2)),
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      color: Colors.black45,
                      child: Text(label, textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════
//  屏 7：记录文字汇总
// ═══════════════════════════════════════

class _TextPage extends StatelessWidget {
  final List<Record> records;
  final ColorScheme cs;
  const _TextPage({required this.records, required this.cs});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Text('✍️ 文字碎片', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: cs.onSurface)),
          const SizedBox(height: 8),
          Text('共 ${records.length} 条记录', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          const SizedBox(height: 16),
          Expanded(
            child: records.isEmpty
                ? Center(child: Text('暂无记录', style: TextStyle(color: cs.onSurfaceVariant)))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: records.length,
                    separatorBuilder: (_, a) => const Divider(height: 1, indent: 0),
                    itemBuilder: (_, i) {
                      final r = records[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.content, maxLines: 3, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14, height: 1.5)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (r.mood != null) ...[
                                  Text(r.mood!, style: TextStyle(fontSize: 11, color: cs.primary.withValues(alpha: 0.7))),
                                  const SizedBox(width: 8),
                                ],
                                Text(_formatDate(r.createdAt),
                                    style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant.withValues(alpha: 0.5))),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) => '${dt.month}/${dt.day}';
}

/// 翻页导航按钮
class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.surface.withValues(alpha: 0.85),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 22, color: cs.primary.withValues(alpha: 0.8)),
        onPressed: onTap,
      ),
    );
  }
}
