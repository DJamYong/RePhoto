import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:exif/exif.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/photo_provider.dart';
import '../providers/preferences_provider.dart';
import '../models/record.dart';
import '../services/record_service.dart';
import '../widgets/record_tile_widget.dart';
import '../widgets/mood_selector.dart';
import 'photo_fullscreen_page.dart';
import 'settings_page.dart';

part 'home_widgets/warm_loading.dart';
part 'home_widgets/photo_card.dart';
part 'home_widgets/detail_panel.dart';
part 'home_widgets/photo_album_view.dart';

/// 首页 — 暖色回忆风 · 拍立得照片展示
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(photoProvider);

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
            style: GoogleFonts.dancingScript(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          actions: [
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
            return _PhotoAlbumView(photo: state.photo!, ref: ref);
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



