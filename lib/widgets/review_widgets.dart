import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../pages/photo_fullscreen_page.dart';

/// 翻页导航按钮
class NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const NavButton({super.key, required this.icon, required this.onTap});

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

/// 照片缩略图（可点击全屏查看）
class ReviewPhotoThumb extends StatelessWidget {
  final String photoId;
  final String label;
  const ReviewPhotoThumb({super.key, required this.photoId, required this.label});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AssetEntity?>(
      future: AssetEntity.fromId(photoId),
      builder: (_, snap) {
        final entity = snap.data;
        if (entity == null) {
          return Container(
            decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.image_outlined, size: 24, color: Colors.grey),
          );
        }
        return GestureDetector(
          onTap: () => Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => PhotoFullscreenPage(photo: entity),
              transitionsBuilder: (_, animation, __, child) =>
                  FadeTransition(opacity: animation, child: child),
              transitionDuration: const Duration(milliseconds: 200),
              reverseTransitionDuration: const Duration(milliseconds: 200),
            ),
          ),
          child: FutureBuilder<Uint8List?>(
            future: entity.thumbnailDataWithSize(const ThumbnailSize(200, 200), quality: 70),
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
          ),
        );
      },
    );
  }
}

/// 总结页统计行
class SummaryRow extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  const SummaryRow({super.key, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        const SizedBox(width: 8),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface)),
      ],
    );
  }
}

/// 标签颜色行
class ColorRow extends StatelessWidget {
  final int color;
  final ColorScheme cs;
  const ColorRow({super.key, required this.color, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('🎨', style: TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Text('最常用标签颜色', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        const SizedBox(width: 10),
        Container(width: 24, height: 24,
          decoration: BoxDecoration(color: Color(color), shape: BoxShape.circle),
        ),
      ],
    );
  }
}
