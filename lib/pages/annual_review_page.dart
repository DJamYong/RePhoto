import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../services/review_service.dart';
import '../models/record.dart';
import '../widgets/review_widgets.dart';
import 'photo_fullscreen_page.dart';

/// 年度回顾页面 — 全屏沉浸式 PageView
class AnnualReviewPage extends StatefulWidget {
  final int year;

  const AnnualReviewPage({super.key, required this.year});

  @override
  State<AnnualReviewPage> createState() => _AnnualReviewPageState();
}

class _AnnualReviewPageState extends State<AnnualReviewPage> {
  late final PageController _pageCtrl;
  int _currentPage = 0;
  Map<String, int>? _overview;
  List<MapEntry<int, int>>? _monthlyViews;
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
    final y = widget.year;
    // 聚合全年数据
    final futures = <Future>[];
    for (var m = 1; m <= 12; m++) {
      futures.add(ReviewService.getDailyViews(y, m));
      futures.add(ReviewService.getRecordDays(y, m));
    }
    final monthResults = await Future.wait(futures);

    // 手动计算全年总览
    int totalViewed = 0, totalRecorded = 0, totalChars = 0;
    for (var m = 1; m <= 12; m++) {
      final ov = await ReviewService.getMonthlyOverview(y, m);
      totalViewed += ov['viewedPhotos']!;
      totalRecorded += ov['recordedPhotos']!;
      totalChars += ov['totalChars']!;
    }

    // 月度翻看数
    final views = <MapEntry<int, int>>[];
    for (var m = 0; m < 12; m++) {
      final daily = monthResults[m * 2] as List<MapEntry<int, int>>;
      views.add(MapEntry(m + 1, daily.fold(0, (s, e) => s + e.value)));
    }

    // 全年情绪
    final allMoods = <MapEntry<String, int>>[];
    for (var m = 1; m <= 12; m++) {
      final moods = await ReviewService.getMoodDistribution(y, m);
      for (final mood in moods) {
        final idx = allMoods.indexWhere((e) => e.key == mood.key);
        if (idx >= 0) {
          allMoods[idx] = MapEntry(mood.key, allMoods[idx].value + mood.value);
        } else {
          allMoods.add(mood);
        }
      }
    }
    allMoods.sort((a, b) => b.value.compareTo(a.value));

    // 全年精选照片
    final allPhotos = <String, int>{};
    for (var m = 1; m <= 12; m++) {
      final photos = await ReviewService.getTopPhotoIds(y, m, limit: 5);
      for (final p in photos) {
        allPhotos[p.key] = (allPhotos[p.key] ?? 0) + p.value;
      }
    }
    final sortedPhotos = allPhotos.entries.map((e) => MapEntry(e.key, e.value)).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 全年记录
    final allRecords = <Record>[];
    for (var m = 1; m <= 12; m++) {
      allRecords.addAll(await ReviewService.getAllRecordsInMonth(y, m));
    }
    allRecords.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (mounted) {
      setState(() {
        _overview = {'viewedPhotos': totalViewed, 'recordedPhotos': totalRecorded, 'totalChars': totalChars};
        _monthlyViews = views;
        _moods = allMoods;
        _topPhotos = sortedPhotos.take(12).toList();
        _records = allRecords;
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
                    _AnnualCover(year: widget.year, cs: cs),
                    _AnnualOverview(data: _overview!, cs: cs),
                    _MonthlyChartPage(data: _monthlyViews!, cs: cs),
                    _AnnualMoodPage(data: _moods!, cs: cs),
                    _PhotoGridPage(data: _topPhotos!, cs: cs),
                    _TextPage(records: _records!, moods: _moods!, cs: cs),
                  ],
                ),
          // 底部 1/3 区域手势翻页
          if (!_loading)
            Positioned(
              bottom: 0, left: 0, right: 0,
              height: MediaQuery.of(context).size.height / 3,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity == null) return;
                  if (details.primaryVelocity! < -200 && _currentPage < 5) {
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
          // 翻页按钮
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
                        duration: const Duration(milliseconds: 300), curve: Curves.easeOut,
                      ),
                    ),
                  if (_currentPage > 0 && _currentPage < 5) const SizedBox(width: 8),
                  if (_currentPage < 5)
                    NavButton(
                      icon: Icons.keyboard_arrow_down_rounded,
                      onTap: () => _pageCtrl.nextPage(
                        duration: const Duration(milliseconds: 300), curve: Curves.easeOut,
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

class _AnnualCover extends StatelessWidget {
  final int year;
  final ColorScheme cs;
  const _AnnualCover({required this.year, required this.cs});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? cs.surface : const Color(0xFFFDF6EC);
    return Stack(
      children: [
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
                  Center(
                    child: Container(
                      width: 240,
                      padding: const EdgeInsets.only(top: 24, bottom: 28),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 8)),
                          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text('年度报告', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                                color: cs.primary.withValues(alpha: 0.6), letterSpacing: 3)),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(5, (i) => Container(
                                width: 8, height: 14,
                                margin: EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: cs.onSurfaceVariant.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              )),
                            ),
                          ),
                          Text('$year', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w200,
                              color: cs.onSurface, letterSpacing: 8)),
                          const SizedBox(height: 8),
                          Text('年度回忆', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w300,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.5), letterSpacing: 6)),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
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
//  屏 2：总览
// ═══════════════════════════════════════

class _AnnualOverview extends StatelessWidget {
  final Map<String, int> data;
  final ColorScheme cs;
  const _AnnualOverview({required this.data, required this.cs});

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
//  屏 3：月度翻看柱状图
// ═══════════════════════════════════════

class _MonthlyChartPage extends StatelessWidget {
  final List<MapEntry<int, int>> data;
  final ColorScheme cs;
  const _MonthlyChartPage({required this.data, required this.cs});

  @override
  Widget build(BuildContext context) {
    final total = data.fold(0, (s, e) => s + e.value);
    final maxVal = data.isEmpty ? 1 : data.map((e) => e.value).reduce(max);
    final bestMonth = data.isEmpty ? null : data.reduce((a, b) => a.value > b.value ? a : b);
    const cnMonths = ['一月', '二月', '三月', '四月', '五月', '六月', '七月', '八月', '九月', '十月', '十一月', '十二月'];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 56),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Text('📊 月度翻看趋势', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: cs.onSurface)),
            const SizedBox(height: 8),
            Text('全年翻看 $total 次', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            if (bestMonth != null) ...[
              const SizedBox(height: 4),
              Text('最活跃月份：${cnMonths[bestMonth.key - 1]}（${bestMonth.value} 次）',
                  style: TextStyle(fontSize: 12, color: cs.primary.withValues(alpha: 0.8))),
            ],
            const SizedBox(height: 24),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        SizedBox(width: 28, child: Text('$maxVal', textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant.withValues(alpha: 0.5)))),
                        const Spacer(),
                        Text('0', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant.withValues(alpha: 0.5))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: CustomPaint(
                        painter: _ChartPainter(data, maxVal, cs.primary, cs.surfaceContainerHighest.withValues(alpha: 0.3)),
                        child: Container(),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('1月', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant.withValues(alpha: 0.5))),
                        const Spacer(),
                        Text('6月', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant.withValues(alpha: 0.5))),
                        const Spacer(),
                        Text('12月', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant.withValues(alpha: 0.5))),
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

class _ChartPainter extends CustomPainter {
  final List<MapEntry<int, int>> data;
  final int maxVal;
  final Color barColor;
  final Color gridColor;
  _ChartPainter(this.data, this.maxVal, this.barColor, this.gridColor);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final barW = size.width / 12;
    final labelPad = 14.0;
    final chartH = size.height - 20 - labelPad;
    final gridPaint = Paint()..color = gridColor;
    for (var i = 0; i <= 4; i++) {
      final y = size.height - 20 - (chartH / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final barPaint = Paint()..color = barColor.withValues(alpha: 0.75);
    for (final e in data) {
      final h = (e.value / maxVal) * chartH;
      final x = (e.key - 1) * barW + 4;
      final y = size.height - 20 - h;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, barW - 8, h), const Radius.circular(3)), barPaint);
      if (e.value > 0) {
        final tp = TextPainter(
          text: TextSpan(text: '${e.value}', style: TextStyle(color: barColor, fontSize: 9)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + (barW - 8 - tp.width) / 2, y - tp.height - 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ═══════════════════════════════════════
//  屏 4：情绪分布
// ═══════════════════════════════════════

class _AnnualMoodPage extends StatelessWidget {
  final List<MapEntry<String, int>> data;
  final ColorScheme cs;
  const _AnnualMoodPage({required this.data, required this.cs});

  @override
  Widget build(BuildContext context) {
    final total = data.fold(0, (s, e) => s + e.value);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 56),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Text('🎭 全年情绪光谱', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: cs.onSurface)),
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
                        decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(11)),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: total > 0 ? e.value / total : 0,
                          child: Container(
                            decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(11)),
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
      ),
    );
  }
}

// ═══════════════════════════════════════
//  屏 5：精选照片
// ═══════════════════════════════════════

class _PhotoGridPage extends StatelessWidget {
  final List<MapEntry<String, int>> data;
  final ColorScheme cs;
  const _PhotoGridPage({required this.data, required this.cs});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 56),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Text('📸 全年精选', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: cs.onSurface)),
            const SizedBox(height: 16),
            Expanded(
              child: data.isEmpty
                  ? Center(child: Text('暂无记录', style: TextStyle(color: cs.onSurfaceVariant)))
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6,
                      ),
                      itemCount: min(data.length, 12),
                      itemBuilder: (_, i) => ReviewPhotoThumb(photoId: data[i].key, label: '${data[i].value}条'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════
//  屏 6：全年总结
// ═══════════════════════════════════════

class _TextPage extends StatelessWidget {
  final List<Record> records;
  final List<MapEntry<String, int>> moods;
  final ColorScheme cs;
  const _TextPage({required this.records, required this.moods, required this.cs});

  @override
  Widget build(BuildContext context) {
    final longest = records.isEmpty
        ? null
        : records.reduce((a, b) => a.content.length >= b.content.length ? a : b);
    final topMood = moods.isEmpty ? null : moods.first.key;
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
              Text('✨ 全年总结', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: cs.onSurface)),
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
                  child: Text(longest.content,
                      style: TextStyle(fontSize: 14, height: 1.6, color: cs.onSurface)),
                ),
              ],
            ],
            if (records.isEmpty)
              Text('今年还没有记录', style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }
}


