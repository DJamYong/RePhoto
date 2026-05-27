import 'dart:math';
import 'package:photo_manager/photo_manager.dart';

/// 相册服务 — 封装相册权限请求与随机照片选取
class PhotoService {
  /// 请求相册读取权限
  /// 返回 true 表示已授权
  Future<bool> requestPermission() async {
    final result = await PhotoManager.requestPermissionExtend();
    // hasAccess 包含 authorized（完整授权）和 limited（部分授权，如 Android 选照片）
    return result.hasAccess;
  }

  /// 检查当前是否有相册权限
  Future<bool> hasPermission() async {
    final result = await PhotoManager.getPermissionState(
      requestOption: const PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: RequestType.image,
          mediaLocation: false,
        ),
      ),
    );
    return result.hasAccess;
  }

  /// 从相册中随机选取一张照片
  ///
  /// 返回 [AssetEntity]，可用于获取缩略图并在 Image widget 中展示。
  /// 如果相册为空或权限不足，返回 null。
  Future<AssetEntity?> getRandomPhoto() async {
    // 获取所有图片相册（包括"所有照片"这个虚拟相册）
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      hasAll: true,
    );

    if (albums.isEmpty) return null;

    // 优先使用"所有照片"相册，否则用第一个
    final allAlbum = albums.firstWhere(
      (album) => album.isAll,
      orElse: () => albums.first,
    );

    final totalCount = await allAlbum.assetCountAsync;
    if (totalCount == 0) return null;

    // 随机选一个索引，只获取那一张，避免加载整个相册
    final randomIndex = Random().nextInt(totalCount);
    final entities = await allAlbum.getAssetListRange(
      start: randomIndex,
      end: min(randomIndex + 1, totalCount),
    );

    if (entities.isEmpty) return null;
    return entities.first;
  }

  /// 获取相册中的照片总数（用于判断是否有照片可展示）
  Future<int> getPhotoCount() async {
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      hasAll: true,
    );
    if (albums.isEmpty) return 0;

    final allAlbum = albums.firstWhere(
      (album) => album.isAll,
      orElse: () => albums.first,
    );
    return allAlbum.assetCountAsync;
  }
}
