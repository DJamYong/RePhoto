import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import '../providers/photo_provider.dart';

/// 首页 — 展示随机照片
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(photoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('RePhoto'),
        centerTitle: true,
      ),
      body: stateAsync.when(
        // 加载中：显示加载动画
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在翻开您的回忆...'),
            ],
          ),
        ),

        // 加载成功
        data: (state) {
          // 有错误信息（无权限 / 无照片）
          if (state.errorMessage != null) {
            return _buildErrorView(context, ref, state);
          }

          // 正常展示照片
          return _buildPhotoView(context, ref, state.photo!);
        },

        // 加载出错（非业务错误，而是 provider 抛出异常）
        error: (error, stack) => _buildErrorView(
          context,
          ref,
          RandomPhotoState(errorMessage: '加载失败：$error'),
        ),
      ),
    );
  }

  /// 错误/提示页面
  Widget _buildErrorView(
    BuildContext context,
    WidgetRef ref,
    RandomPhotoState state,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              state.hasPermission ? Icons.photo_album_outlined : Icons.folder_off_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 24),
            Text(
              state.errorMessage ?? '未知错误',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.tonalIcon(
              onPressed: () => ref.read(photoProvider.notifier).retryPermission(),
              icon: const Icon(Icons.refresh),
              label: Text(state.hasPermission ? '重试' : '授予权限'),
            ),
          ],
        ),
      ),
    );
  }

  /// 照片展示页面
  Widget _buildPhotoView(
    BuildContext context,
    WidgetRef ref,
    AssetEntity photo,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 照片区域 — 尽量撑满可用空间
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _PhotoWidget(photo: photo),
              ),
            ),

            const SizedBox(height: 24),

            // 刷新按钮 — 换一张随机照片
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: () => ref.read(photoProvider.notifier).refresh(),
                icon: const Icon(Icons.shuffle),
                label: const Text('换一张'),
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// 从 [AssetEntity] 异步加载缩略图并展示的组件
///
/// photo_manager 3.x 不再提供直接的 ImageProvider，
/// 需要通过 thumbnailDataWithSize 获取字节数据后用 Image.memory 渲染。
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
    // 照片变化时重新加载
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
      // 加载适合屏幕显示的缩略图（800x800 在手机上足够清晰）
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
    } catch (e) {
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
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError || _imageBytes == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image_outlined, size: 64),
            SizedBox(height: 8),
            Text('图片加载失败'),
          ],
        ),
      );
    }

    return Image.memory(
      _imageBytes!,
      fit: BoxFit.contain,
      // 渐入动画
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 300),
          child: child,
        );
      },
    );
  }
}
