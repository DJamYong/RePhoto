import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../services/review_service.dart';
import '../models/record.dart';
import '../widgets/review_widgets.dart';
import 'photo_fullscreen_page.dart';

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
                _TextPage(records: _records!, moods: _moods!, cs: cs),
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
                    NavButton(
                      icon: Icons.keyboard_arrow_up_rounded,
                      onTap: () => _pageCtrl.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      ),
                    ),
                  const SizedBox(width: 8),
                  if (_currentPage < 6)
                    NavButton(
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
    final mn = month >= 1 && month <= 12
        ? ['', '一月', '二月', '三月', '四月', '五月', '六月', '七月', '八月', '九月', '十月', '十一月', '十二月'][month]
        : '$month月';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? cs.surface : const Color(0xFFFDF6EC);
    return Stack(
      children: [
        // 背景装饰圆
        Positioned(top: -60, right: -40,
          child: Container(width: 200, height: 200,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: cs.primary.withValues(alpha: 0.06)),
          ),
        ),
        Positioned(bottom: 80, left: -50,
          child: Container(width: 150, height: 150,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: cs.primary.withValues(alpha: 0.04)),
          ),
        ),
        Positioned(top: 200, left: 30,
          child: Container(width: 60, height: 60,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: cs.primary.withValues(alpha: 0.05)),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [bgColor, bgColor],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 56),
              child: Column(
                children: [
                  const Spacer(),
                  // 纸质日历卡片
                  Center(
                    child: Container(
                      width: 220,
                      padding: const EdgeInsets.only(top: 20, bottom: 24),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 日历头部文字
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text('你的月份回顾', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                                color: cs.primary.withValues(alpha: 0.6), letterSpacing: 3)),
                          ),
                          // 装订环
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(5, (i) => Container(
                                width: 8, height: 14,
                                margin: EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: cs.onSurfaceVariant.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              )),
                            ),
                          ),
                          // 月份
                          Text(mn, style: TextStyle(fontSize: 36, fontWeight: FontWeight.w300,
                              color: cs.onSurface, letterSpacing: 10)),
                          const SizedBox(height: 8),
                          // 年份
                          Text('$year', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w300,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.5), letterSpacing: 6)),
                          const SizedBox(height: 16),
                          // 月份进度条（12 个月份，每行 6 个，已过月份点亮）
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [0, 6].map((start) => Padding(
                                padding: start > 0 ? const EdgeInsets.only(top: 6) : EdgeInsets.zero,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: List.generate(6, (j) {
                                    final i = start + j;
                                    return Container(
                                      width: 16, height: 16,
                                      decoration: BoxDecoration(
                                        color: i < month
                                            ? cs.primary.withValues(alpha: 0.25)
                                            : cs.surfaceContainerHighest.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    );
                                  }),
                                ),
                              )).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Spacer(),
                  // 底部提示
                  Column(
                    children: [
                      Icon(Icons.keyboard_arrow_down_rounded, size: 24,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.2)),
                      const SizedBox(height: 4),
                      Text('滑动浏览', style: TextStyle(fontSize: 11,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.2), letterSpacing: 2)),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ],
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
                    itemBuilder: (_, i) => ReviewPhotoThumb(photoId: data[i].key, label: '${data[i].value}条'),
                  ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════
//  屏 7：本月总结
// ═══════════════════════════════════════

class _TextPage extends StatelessWidget {
  final List<Record> records;
  final List<MapEntry<String, int>> moods;
  final ColorScheme cs;
  const _TextPage({required this.records, required this.moods, required this.cs});

  @override
  Widget build(BuildContext context) {
    // 最长的一条记录
    final longest = records.isEmpty
        ? null
        : records.reduce((a, b) => a.content.length >= b.content.length ? a : b);
    // 最常表达的情绪
    final topMood = moods.isEmpty ? null : moods.first.key;
    // 最常用的标签颜色
    final colorCounts = <int?, int>{};
    for (final r in records) {
      if (r.color != null) colorCounts[r.color] = (colorCounts[r.color] ?? 0) + 1;
    }
    final topColor = colorCounts.entries.isEmpty
        ? null
        : colorCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 56),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 40),
              Text('✨ 本月总结', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: cs.onSurface)),
              const SizedBox(height: 32),
              if (records.isNotEmpty) ...[
                SummaryRow(icon: '✍️', label: '写下的记录', value: '${records.length} 条'),
                const SizedBox(height: 16),
                if (topMood != null)
                  SummaryRow(icon: '🎭', label: '最常表达', value: topMood),
                if (topColor != null) ...[
                  const SizedBox(height: 16),
                  ColorRow(color: topColor, cs: cs),
                ],
                const SizedBox(height: 32),
                if (longest != null) ...[
                  Text('记得最长的一条记录', style: TextStyle(fontSize: 12,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5), letterSpacing: 2)),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      longest.content,
                      style: TextStyle(fontSize: 14, height: 1.6, color: cs.onSurface),
                    ),
                  ),
                ],
              ],
              if (records.isEmpty)
                Text('这个月还没有记录', style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }
}


