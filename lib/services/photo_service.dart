import 'dart:math';
import 'package:photo_manager/photo_manager.dart';

/// 相册服务 — 封装相册权限请求与随机照片选取
class PhotoService {
  /// 全量照片缓存（session 级，应用重启后失效）
  List<AssetEntity>? _cachedPhotos;
  int? _cachedCount;

  /// 刷新照片缓存（删除照片后调用）
  void invalidateCache() {
    _cachedPhotos = null;
    _cachedCount = null;
  }
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

  /// 获取所有照片所在的相册
  Future<AssetPathEntity?> _getAllAlbum() async {
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      hasAll: true,
    );
    if (albums.isEmpty) return null;
    return albums.firstWhere(
      (album) => album.isAll,
      orElse: () => albums.first,
    );
  }

  /// 从相册中随机选取一张照片
  ///
  /// 返回 [AssetEntity]，可用于获取缩略图并在 Image widget 中展示。
  /// 如果相册为空或权限不足，返回 null。
  Future<AssetEntity?> getRandomPhoto() async {
    final allAlbum = await _getAllAlbum();
    if (allAlbum == null) return null;

    final totalCount = await allAlbum.assetCountAsync;
    if (totalCount == 0) return null;

    final randomIndex = Random().nextInt(totalCount);
    final entities = await allAlbum.getAssetListRange(
      start: randomIndex,
      end: min(randomIndex + 1, totalCount),
    );

    if (entities.isEmpty) return null;
    return entities.first;
  }

  /// 加权随机选取一张照片
  ///
  /// [recentViewCounts] 是近30天各照片被抽到的次数 Map<photoId, count>，
  /// 权重以近30天最高浏览次数为基准动态计算：
  /// weightBase = maxCount + 1，weight = max(1, weightBase - count)。
  /// 0次浏览的照片获得最高权重，被看最多的照片权重为1（仍有概率被抽到）。
  Future<AssetEntity?> getWeightedRandomPhoto(
      Map<String, int> recentViewCounts) async {
    // 有缓存且数量未变时直接使用，否则重新加载
    if (_cachedPhotos == null || _cachedCount == null) {
      final allAlbum = await _getAllAlbum();
      if (allAlbum == null) return null;

      _cachedCount = await allAlbum.assetCountAsync;
      if (_cachedCount == 0) return null;

      _cachedPhotos = await allAlbum.getAssetListRange(
        start: 0,
        end: _cachedCount!,
      );
    }

    final allPhotos = _cachedPhotos!;
    if (allPhotos.isEmpty) return null;

    // 以近30天最高浏览次数为基准动态计算权重
    final maxCount = recentViewCounts.values.isEmpty
        ? 0
        : recentViewCounts.values.reduce(max);
    final weightBase = maxCount + 1;

    // 从往年的同月同日照片中随机挑一张，权重提升5倍
    final now = DateTime.now();
    String? boostedPhotoId;
    final sameDayPhotos = allPhotos.where((p) {
      final t = p.createDateTime;
      return t.month == now.month && t.day == now.day && t.year != now.year;
    }).toList();
    if (sameDayPhotos.isNotEmpty) {
      boostedPhotoId = sameDayPhotos[Random().nextInt(sameDayPhotos.length)].id;
    }

    // 计算权重并构建加权池
    final weights = <int>[];
    var totalWeight = 0;
    for (final photo in allPhotos) {
      final recentCount = recentViewCounts[photo.id] ?? 0;
      var weight = max(1, weightBase - recentCount);
      if (photo.id == boostedPhotoId) {
        weight *= 5;
      }
      weights.add(weight);
      totalWeight += weight;
    }

    // 加权随机选择
    var r = Random().nextInt(totalWeight);
    for (var i = 0; i < allPhotos.length; i++) {
      r -= weights[i];
      if (r < 0) return allPhotos[i];
    }

    return allPhotos.last;
  }

  /// 删除指定照片（从设备相册中彻底移除）
  Future<bool> deletePhoto(AssetEntity photo) async {
    try {
      final result = await PhotoManager.editor.deleteWithIds([photo.id]);
      final success = result.isNotEmpty;
      if (success) invalidateCache();
      return success;
    } catch (_) {
      return false;
    }
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
