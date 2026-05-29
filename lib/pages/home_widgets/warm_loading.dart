part of '../home_page.dart';

// ═══════════════════════════════════════
//  加载状态 — 暖色骨架屏
// ═══════════════════════════════════════

class _WarmLoading extends StatefulWidget {
  const _WarmLoading();

  @override
  State<_WarmLoading> createState() => _WarmLoadingState();
}

class _WarmLoadingState extends State<_WarmLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _pageBackground(context),
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: 0.4 + _controller.value * 0.6,
              child: child,
            );
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                ),
                child: Icon(
                  Icons.photo_camera_outlined,
                  size: 36,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '正在翻开您的回忆...',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════
//  错误状态
// ═══════════════════════════════════════

class _ErrorView extends StatelessWidget {
  final RandomPhotoState state;
  final WidgetRef ref;
  const _ErrorView({required this.state, required this.ref});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: _pageBackground(context),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                state.hasPermission
                    ? Icons.photo_album_outlined
                    : Icons.folder_off_outlined,
                size: 72,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                state.errorMessage ?? '未知错误',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => ref.read(photoProvider.notifier).retryPermission(),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  state.hasPermission ? '重 试' : '授 予 权 限',
                  style: const TextStyle(letterSpacing: 3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
