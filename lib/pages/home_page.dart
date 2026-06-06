import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:exif/exif.dart';
import 'package:photo_manager/photo_manager.dart';
import '../providers/photo_provider.dart';
import '../providers/preferences_provider.dart';
import '../providers/theme_provider.dart';
import '../models/record.dart';
import '../models/time_collision.dart';
import '../services/record_service.dart';
import '../services/database_service.dart';
import '../services/photo_service.dart';
import '../widgets/record_tile_widget.dart';
import '../widgets/mood_selector.dart';
import 'monthly_review_page.dart';
import 'annual_review_page.dart';
import 'photo_fullscreen_page.dart';
import 'settings_page.dart';

part 'home_widgets/warm_loading.dart';
part 'home_widgets/photo_card.dart';
part 'home_widgets/detail_panel.dart';
part 'home_widgets/photo_album_view.dart';

bool _reviewChecked = false;

/// 检查并弹出月度回顾
Future<void> _checkMonthlyReview(BuildContext context, WidgetRef ref) async {
  final prefs = ref.read(sharedPrefsProvider);
  final now = DateTime.now();
  final key = 'lastReviewShownMonth';

  // 只在每月 1 号检查
  if (now.day != 1) return;

  final lastShown = prefs.getString(key);
  final thisMonth = '${now.year}-${now.month}';
  if (lastShown == thisMonth) return;

  await prefs.setString(key, thisMonth);
  final prevMonth = now.month == 1 ? 12 : now.month - 1;
  final prevYear = now.month == 1 ? now.year - 1 : now.year;

  if (context.mounted) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MonthlyReviewPage(year: prevYear, month: prevMonth),
      ),
    );
  }
}

/// 弹出回顾选择器
void _showReviewPicker(BuildContext context) {
  final now = DateTime.now();
  final years = List.generate(now.year - 2023, (i) => now.year - i); // 从 2024 到今年
  showDialog(
    context: context,
    builder: (ctx) {
      int selectedYear = now.year;
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
        return AlertDialog(
          title: Row(children: [
            Icon(Icons.bar_chart_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: selectedYear,
              underline: const SizedBox(),
              icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface),
              dropdownColor: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              elevation: 4,
              items: years.map((y) => DropdownMenuItem(
                value: y,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('$y 年', style: TextStyle(fontSize: 15)),
                ),
              )).toList(),
              onChanged: (v) => setDialogState(() { selectedYear = v!; }),
            ),
          ]),
          content: SizedBox(
            width: double.maxFinite,
            child: FutureBuilder<List<MapEntry<int, bool>>>(
              future: _getAvailableMonths(selectedYear),
              builder: (context, snapshot) {
                final months = snapshot.data ?? [];
                if (months.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('暂无数据')),
                  );
                }
                return ListView(
                  shrinkWrap: true,
                  children: [
                    // 年度报告入口 (仅过往年份有数据时显示)
                    if (selectedYear < now.year && months.where((m) => m.value).isNotEmpty)
                      _ReviewEntry(
                        icon: Icons.auto_awesome,
                        title: '$selectedYear 年度报告',
                        subtitle: '回顾这一年的回忆',
                        onTap: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AnnualReviewPage(year: selectedYear),
                            ),
                          );
                        },
                      ),
                    ...months.where((m) => m.value).map((m) => _ReviewEntry(
                      icon: Icons.calendar_month_outlined,
                      title: '$selectedYear 年 ${m.key} 月',
                      subtitle: '查看月度回忆',
                      onTap: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MonthlyReviewPage(year: selectedYear, month: m.key),
                          ),
                        );
                      },
                    )),
                    if (months.where((m) => m.value).isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('该年份暂无回顾数据')),
                      ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('关闭')),
          ],
        );
      },
    );
  },
);
}

/// 查询指定年份中有记录的月份
Future<List<MapEntry<int, bool>>> _getAvailableMonths(int year) async {
  final start = DateTime(year, 1, 1);
  final end = DateTime(year + 1, 1, 1);
  final rows = await DatabaseService.db.rawQuery('''
    SELECT DISTINCT CAST(strftime('%m', created_at) AS INTEGER) AS month
    FROM records
    WHERE created_at >= ? AND created_at < ?
    ORDER BY month DESC
  ''', [start.toIso8601String(), end.toIso8601String()]);
  // 同时查询浏览历史中有数据的月份
  final viewRows = await DatabaseService.db.rawQuery('''
    SELECT DISTINCT CAST(strftime('%m', viewed_at) AS INTEGER) AS month
    FROM view_history
    WHERE viewed_at >= ? AND viewed_at < ?
    ORDER BY month DESC
  ''', [start.toIso8601String(), end.toIso8601String()]);
  final hasRecord = rows.map((r) => r['month'] as int).toSet();
  final hasView = viewRows.map((r) => r['month'] as int).toSet();
  final hasData = hasRecord.union(hasView);
  final allMonths = List.generate(12, (i) => 12 - i);
  return allMonths.map((m) => MapEntry(m, hasData.contains(m))).toList();
}

/// 首页 — 暖色回忆风 · 拍立得照片展示
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(photoProvider);

    // 每月首次启动时检查回顾（只触发一次）
    ref.listen(photoProvider, (_, next) {
      if (next.hasValue && !_reviewChecked) {
        _reviewChecked = true;
        _checkMonthlyReview(context, ref);
      }
    });

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
            style: const TextStyle(
              fontFamily: 'DancingScript',
              fontWeight: FontWeight.w500,
            ).copyWith(color: Theme.of(context).colorScheme.primary),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.bar_chart_outlined),
              tooltip: '回顾',
              onPressed: () => _showReviewPicker(context),
            ),
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
            return _PhotoAlbumView(photo: state.photo!, ref: ref, state: state);
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
                      key: ValueKey('panel_${widget.photoAsync.value?.photo?.id}'),
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
    super.key,
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

/// 回顾选择器中的条目
class _ReviewEntry extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ReviewEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        dense: true,
        leading: Icon(icon, size: 20, color: cs.primary),
        title: Text(title, style: const TextStyle(fontSize: 14)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        trailing: Icon(Icons.chevron_right, size: 18, color: cs.onSurfaceVariant),
        onTap: onTap,
      ),
    );
  }
}
