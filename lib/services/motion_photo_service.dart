import 'package:flutter/services.dart';

/// 检测和提取各平台动图（iOS Live Photo / Android Motion Photo / GIF）的工具服务
class MotionPhotoService {
  static const _channel = MethodChannel('com.rephoto.rephoto/motion_photo');

  /// 检测指定照片是否为动图（Live Photo / Motion Photo / GIF）
  /// [photoId] photo_manager 中的 AssetEntity.id
  /// [isLivePhotoIOS] iOS 上 photo_manager 返回的 isLivePhoto 值
  static Future<bool> isMotionPhoto({
    required String photoId,
    required bool isLivePhotoIOS,
    String? mimeType,
  }) async {
    // iOS：photo_manager 可直接判断
    if (isLivePhotoIOS) return true;

    // GIF 直接通过 mimeType 判断
    if (mimeType?.toLowerCase() == 'image/gif') return true;

    // Android：通过平台通道查询
    try {
      final result = await _channel.invokeMethod<Map>('isMotionPhoto', {
        'ids': [photoId],
      });
      return result?[photoId] == true;
    } catch (_) {
      return false;
    }
  }

  /// 批量检测动图
  static Future<Map<String, bool>> batchCheck({
    required List<String> photoIds,
  }) async {
    if (photoIds.isEmpty) return {};
    try {
      // 用 scanMotionPhotos 直接返回命中的 ID 列表（比逐个 isMotionPhoto 快）
      final result = await _channel.invokeMethod<List>('scanMotionPhotos', {
        'ids': photoIds,
      });
      final set = result?.map((e) => e.toString()).toSet() ?? {};
      return {for (final id in photoIds) id: set.contains(id)};
    } catch (_) {
      return {};
    }
  }

  /// 诊断检测链路（用于排查问题）
  static Future<Map?> debugCheck(String photoId) async {
    try {
      return await _channel.invokeMethod<Map>('debugCheck', {
        'id': photoId,
      });
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// 提取动图的视频文件路径
  /// 返回可用于 video_player 的直接文件路径
  static Future<String?> extractMotionVideo(String photoId) async {
    try {
      return await _channel.invokeMethod<String>('extractMotionVideo', {
        'id': photoId,
      });
    } catch (_) {
      return null;
    }
  }
}
