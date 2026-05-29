part of '../home_page.dart';

// ═══════════════════════════════════════
//  照片详情面板内容
// ═══════════════════════════════════════

class _DrawerContent extends StatelessWidget {
  final AssetEntity photo;
  final Uint8List? preloadedThumbnail;
  final File? preloadedFile;
  final Map<String, IfdTag>? preloadedExif;

  const _DrawerContent({
    required this.photo,
    this.preloadedThumbnail,
    this.preloadedFile,
    this.preloadedExif,
  });

  @override
  Widget build(BuildContext context) {
    final created = photo.createDateTime;
    final modified = photo.modifiedDateTime;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: colorScheme.primary),
                onPressed: () {
                  _SlidingPanelState? state =
                      context.findAncestorStateOfType<_SlidingPanelState>();
                  state?.close();
                },
              ),
              const SizedBox(width: 4),
              Text(
                '照片详情',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.primary,
                  decoration: TextDecoration.none,
                  decorationColor: Colors.transparent,
                  decorationThickness: 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: isDark
                          ? const Color(0xFF3D322C)
                          : const Color(0xFFF0E6D8),
                    ),
                    child: _PanelPhotoWidget(
                      photo: photo,
                      preloadedBytes: preloadedThumbnail,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.12),
                  ),
                ),
                color: isDark
                    ? const Color(0xFF3D322C)
                    : Colors.white.withValues(alpha: 0.85),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      _buildTile(Icons.badge_outlined, '照片 ID', photo.id, colorScheme),
                      _divider(colorScheme),
                      _buildTile(Icons.description_outlined, '文件名', photo.title ?? '未命名', colorScheme),
                      _divider(colorScheme),
                      _buildTile(Icons.image_outlined, '文件类型', _formatMimeType(photo.mimeType), colorScheme),
                      _divider(colorScheme),
                      _FileSizeTile(photo: photo, colorScheme: colorScheme, preloadedFile: preloadedFile),
                      _divider(colorScheme),
                      _buildTile(Icons.calendar_today, '拍摄时间', _formatDate(created), colorScheme),
                      if (modified != created) ...[
                        _divider(colorScheme),
                        _buildTile(Icons.update, '修改时间', _formatDate(modified), colorScheme),
                      ],
                      _divider(colorScheme),
                      _buildTile(Icons.aspect_ratio_outlined, '分辨率', '${photo.width} × ${photo.height}', colorScheme),
                      _divider(colorScheme),
                      _buildTile(Icons.category_outlined, '资源类型', _formatAssetType(photo.type), colorScheme),
                      _divider(colorScheme),
                      _buildTile(Icons.folder_outlined, '路径', photo.relativePath ?? '未知', colorScheme),
                      if (photo.type == AssetType.video && photo.duration > 0) ...[
                        _divider(colorScheme),
                        _buildTile(Icons.timer_outlined, '时长', _formatVideoDuration(Duration(seconds: photo.duration)), colorScheme),
                      ],
                      _divider(colorScheme),
                      _ExifTile(photo: photo, colorScheme: colorScheme, preloadedExif: preloadedExif, preloadedFile: preloadedFile),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTile(IconData icon, String label, String value, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: cs.primary.withValues(alpha: 0.7)),
          const SizedBox(width: 10),
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Divider(
        height: 1,
        color: cs.outlineVariant.withValues(alpha: 0.2),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }

  String _formatMimeType(String? mime) {
    if (mime == null) return '未知';
    switch (mime) {
      case 'image/jpeg': return 'JPEG 图片';
      case 'image/png': return 'PNG 图片';
      case 'image/gif': return 'GIF 动图';
      case 'image/heic': case 'image/heif': return 'HEIC 图片';
      case 'image/webp': return 'WebP 图片';
      case 'image/bmp': return 'BMP 位图';
      case 'video/mp4': return 'MP4 视频';
      case 'video/quicktime': return 'MOV 视频';
      default: return mime;
    }
  }

  String _formatAssetType(AssetType type) {
    switch (type) {
      case AssetType.image: return '图片';
      case AssetType.video: return '视频';
      case AssetType.audio: return '音频';
      case AssetType.other: return '其他';
    }
  }

  String _formatVideoDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) return '$hours时$minutes分$seconds秒';
    return '$minutes分$seconds秒';
  }
}

/// 异步加载文件大小组件
class _FileSizeTile extends StatelessWidget {
  final AssetEntity photo;
  final ColorScheme colorScheme;
  final File? preloadedFile;

  const _FileSizeTile({
    required this.photo,
    required this.colorScheme,
    this.preloadedFile,
  });

  @override
  Widget build(BuildContext context) {
    if (preloadedFile != null) {
      return _buildTile(preloadedFile!.lengthSync());
    }
    return FutureBuilder<File?>(
      future: photo.file,
      builder: (context, snapshot) {
        final fileBytes = (snapshot.connectionState == ConnectionState.done &&
                snapshot.data != null)
            ? snapshot.data!.lengthSync()
            : null;
        return _buildTile(fileBytes);
      },
    );
  }

  Widget _buildTile(int? fileBytes) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.storage_outlined, size: 18, color: colorScheme.primary.withValues(alpha: 0.7)),
          const SizedBox(width: 10),
          SizedBox(
            width: 60,
            child: Text('文件大小', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7))),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              fileBytes != null ? _formatBytes(fileBytes) : '加载中…',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

/// 拍摄参数（EXIF）显示组件
class _ExifTile extends StatelessWidget {
  final AssetEntity photo;
  final ColorScheme colorScheme;
  final Map<String, IfdTag>? preloadedExif;
  final File? preloadedFile;

  const _ExifTile({
    required this.photo,
    required this.colorScheme,
    this.preloadedExif,
    this.preloadedFile,
  });

  static const _exifFields = <String, String>{
    'Image Make': '相机品牌', 'Image Model': '相机型号',
    'EXIF FNumber': '光圈', 'EXIF ISOSpeedRatings': 'ISO',
    'EXIF ExposureTime': '快门速度', 'EXIF FocalLength': '焦距',
    'EXIF ExposureBiasValue': '曝光补偿', 'EXIF Flash': '闪光灯',
    'EXIF MeteringMode': '测光模式', 'EXIF WhiteBalance': '白平衡',
    'Image Software': '软件',
  };

  @override
  Widget build(BuildContext context) {
    if (preloadedExif == null) {
      return FutureBuilder<Map<String, IfdTag>?>(
        future: _loadExif(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const SizedBox.shrink();
          final tags = snapshot.data;
          if (tags == null || tags.isEmpty) return const SizedBox.shrink();
          return _buildExifContent(tags);
        },
      );
    }
    return _buildExifContent(preloadedExif!);
  }

  Widget _buildExifContent(Map<String, IfdTag> tags) {
    final entries = _exifFields.entries.where((e) {
      final tag = tags[e.key];
      return tag != null && tag.printable.isNotEmpty;
    }).toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Row(
            children: [
              Icon(Icons.camera_alt_outlined, size: 16, color: colorScheme.primary.withValues(alpha: 0.6)),
              const SizedBox(width: 6),
              Text('拍摄参数', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.primary.withValues(alpha: 0.7))),
            ],
          ),
        ),
        ...entries.map((e) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_iconForField(e.key), size: 18, color: colorScheme.primary.withValues(alpha: 0.7)),
                const SizedBox(width: 10),
                SizedBox(width: 60, child: Text(e.value, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7)))),
                const SizedBox(width: 6),
                Expanded(child: Text(_formatExifValue(e.key, tags[e.key]!.printable), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colorScheme.onSurface))),
              ],
            ),
          );
        }),
      ],
    );
  }

  Future<Map<String, IfdTag>?> _loadExif() async {
    try {
      final file = preloadedFile ?? await photo.file;
      if (file == null) return null;
      return await readExifFromFile(file);
    } catch (_) {
      return null;
    }
  }

  String _formatExifValue(String key, String raw) {
    if (key == 'EXIF FNumber') {
      final parts = raw.split('/');
      if (parts.length == 2) {
        final n = double.tryParse(parts[0]);
        final d = double.tryParse(parts[1]);
        if (n != null && d != null && d > 0) return 'f/${(n / d).toStringAsFixed(1)}';
      }
      return raw;
    }
    if (key == 'EXIF FocalLength') {
      final parts = raw.split('/');
      if (parts.length == 2) {
        final n = double.tryParse(parts[0]);
        final d = double.tryParse(parts[1]);
        if (n != null && d != null && d > 0) return '${(n / d).toStringAsFixed(1)}mm';
      }
      return '${raw}mm';
    }
    if (key == 'EXIF ExposureBiasValue') {
      final parts = raw.split('/');
      if (parts.length == 2) {
        final n = double.tryParse(parts[0]);
        final d = double.tryParse(parts[1]);
        if (n != null && d != null && d > 0) {
          final val = n / d;
          return val > 0 ? '+${val.toStringAsFixed(1)} EV' : '${val.toStringAsFixed(1)} EV';
        }
      }
      return '$raw EV';
    }
    if (key == 'EXIF ISOSpeedRatings') return 'ISO $raw';
    if (key == 'EXIF Flash') {
      const flashMap = <String, String>{
        'Flash did not fire': '未闪光', 'No Flash': '未闪光',
        'Flash fired': '已闪光', 'Flash fired, compulsory flash mode': '强制闪光',
        'Flash fired, auto mode': '自动闪光', 'Flash fired, red-eye reduction': '防红眼闪光',
        'Flash fired, return light detected': '已闪光', 'Flash fired, return light not detected': '已闪光',
        'No flash function': '无闪光功能', 'Compulsory flash mode': '强制闪光',
      };
      if (flashMap.containsKey(raw)) return flashMap[raw]!;
      if (raw.contains('not fire')) return '未闪光';
      return raw;
    }
    if (key == 'EXIF MeteringMode') {
      const meterMap = <String, String>{
        'Unidentified': '未识别', 'Average': '平均测光',
        'CenterWeightedAverage': '中央重点测光', 'Spot': '点测光',
        'MultiSpot': '多点测光', 'Pattern': '矩阵测光',
        'Partial': '局部测光', 'other': '其他',
      };
      return meterMap[raw] ?? raw;
    }
    if (key == 'EXIF ExposureTime') {
      final parts = raw.split('/');
      if (parts.length == 2) {
        final n = double.tryParse(parts[0]);
        final d = double.tryParse(parts[1]);
        if (n != null && d != null && d > 0) {
          if (n <= 0 || d <= 0) return '${raw}s';
          final seconds = n / d;
          if (seconds >= 1) {
            if (seconds == seconds.roundToDouble()) return '${seconds.toInt()}s';
            return '${seconds.toStringAsFixed(1)}s';
          }
          return '1/${(1 / seconds).round()}s';
        }
      }
      return '${raw}s';
    }
    return raw;
  }

  IconData _iconForField(String key) {
    switch (key) {
      case 'Image Make': case 'Image Model': return Icons.videocam_outlined;
      case 'EXIF FNumber': return Icons.blur_on_outlined;
      case 'EXIF ISOSpeedRatings': return Icons.wb_sunny_outlined;
      case 'EXIF ExposureTime': return Icons.timer_outlined;
      case 'EXIF FocalLength': return Icons.straighten_outlined;
      case 'EXIF ExposureBiasValue': return Icons.tune_outlined;
      case 'EXIF Flash': return Icons.flash_on_outlined;
      case 'EXIF MeteringMode': return Icons.center_focus_strong_outlined;
      case 'EXIF WhiteBalance': return Icons.brightness_5_outlined;
      case 'Image Software': return Icons.code_outlined;
      default: return Icons.info_outline;
    }
  }
}
