import 'dart:math';
import 'package:photo_manager/photo_manager.dart';
import '../models/time_collision.dart';
import 'motion_photo_service.dart';

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

  /// 按ID从缓存中查找照片
  Future<AssetEntity?> getPhotoById(String id) async {
    if (_cachedPhotos == null) {
      final allAlbum = await _getAllAlbum();
      if (allAlbum == null) return null;
      _cachedCount = await allAlbum.assetCountAsync;
      if (_cachedCount == 0) return null;
      _cachedPhotos = await allAlbum.getAssetListRange(start: 0, end: _cachedCount!);
    }
    for (final photo in _cachedPhotos!) {
      if (photo.id == id) return photo;
    }
    return null;
  }

  /// 查找与指定照片同月同日的其他年份照片，按年份分组
  Future<Map<int, List<AssetEntity>>> findSameDayPhotos(AssetEntity currentPhoto) async {
    final dt = currentPhoto.createDateTime;
    final month = dt.month;
    final day = dt.day;

    // 确保缓存已加载
    if (_cachedPhotos == null) {
      final allAlbum = await _getAllAlbum();
      if (allAlbum == null) return {};
      _cachedCount = await allAlbum.assetCountAsync;
      if (_cachedCount == 0) return {};
      _cachedPhotos = await allAlbum.getAssetListRange(start: 0, end: _cachedCount!);
    }

    final result = <int, List<AssetEntity>>{};
    for (final photo in _cachedPhotos!) {
      final t = photo.createDateTime;
      if (t.month == month && t.day == day) {
        result.putIfAbsent(t.year, () => []).add(photo);
      }
    }
    return result;
  }

  /// 获取时间对撞诊断数据（按月+日分组，仅返回有多个年份的日期）
  Future<Map<String, Map<int, int>>> getCollisionDiagnostic() async {
    if (_cachedPhotos == null) {
      final allAlbum = await _getAllAlbum();
      if (allAlbum == null) return {};
      _cachedCount = await allAlbum.assetCountAsync;
      if (_cachedCount == 0) return {};
      _cachedPhotos = await allAlbum.getAssetListRange(start: 0, end: _cachedCount!);
    }

    final groups = <String, Map<int, int>>{};
    for (final photo in _cachedPhotos!) {
      final dt = photo.createDateTime;
      final key = '${dt.month}月${dt.day}日';
      groups.putIfAbsent(key, () => {});
      groups[key]![dt.year] = (groups[key]![dt.year] ?? 0) + 1;
    }

    groups.removeWhere((_, years) => years.length < 2);
    return groups;
  }

  /// 查找任意一张能触发时间对撞的照片（测试用）
  Future<TimeCollision?> findAnyCollision() async {
    if (_cachedPhotos == null) {
      final allAlbum = await _getAllAlbum();
      if (allAlbum == null) return null;
      _cachedCount = await allAlbum.assetCountAsync;
      if (_cachedCount == 0) return null;
      _cachedPhotos = await allAlbum.getAssetListRange(start: 0, end: _cachedCount!);
    }

    // 按月+日分组，取第一个有多个年份的
    final groups = <String, Map<int, List<AssetEntity>>>{};
    for (final photo in _cachedPhotos!) {
      final dt = photo.createDateTime;
      final key = '${dt.month}-${dt.day}';
      groups.putIfAbsent(key, () => {});
      groups[key]!.putIfAbsent(dt.year, () => []).add(photo);
    }

    final candidates = groups.entries.where((e) => e.value.length >= 2).toList();
    if (candidates.isEmpty) return null;
    // 随机选一组对撞数据
    final pick = candidates[Random().nextInt(candidates.length)];
    final years = pick.value.keys.toList()..sort();
    final newestYear = years.last;
    return TimeCollision(groups: pick.value, selectedYear: newestYear);
  }

  /// 查找一张能触发"此刻·彼时"的照片（今天月日但不同年份）（测试用）
  Future<AssetEntity?> findHistoricalMomentPhoto() async {
    if (_cachedPhotos == null) {
      final allAlbum = await _getAllAlbum();
      if (allAlbum == null) return null;
      _cachedCount = await allAlbum.assetCountAsync;
      if (_cachedCount == 0) return null;
      _cachedPhotos = await allAlbum.getAssetListRange(start: 0, end: _cachedCount!);
    }

    final now = DateTime.now();
    final candidates = _cachedPhotos!.where((p) {
      final t = p.createDateTime;
      return t.month == now.month && t.day == now.day && t.year != now.year;
    }).toList();

    if (candidates.isEmpty) return null;
    return candidates[Random().nextInt(candidates.length)];
  }

  /// 查找一张随机 Live Photo（用于测试）
  Future<AssetEntity?> findLivePhoto() async {
    if (_cachedPhotos == null) {
      final allAlbum = await _getAllAlbum();
      if (allAlbum == null) return null;
      _cachedCount = await allAlbum.assetCountAsync;
      if (_cachedCount == 0) return null;
      _cachedPhotos = await allAlbum.getAssetListRange(start: 0, end: _cachedCount!);
    }

    // 1) 本地条件：iOS Live Photo + GIF
    final localCandidates = _cachedPhotos!.where((p) {
      if (p.isLivePhoto) return true;
      final mime = p.mimeType?.toLowerCase() ?? '';
      if (mime == 'image/gif') return true;
      return false;
    }).toList();
    if (localCandidates.isNotEmpty) {
      return localCandidates[Random().nextInt(localCandidates.length)];
    }

    // 2) Android：随机抽最多 500 张批量检测（不再读文件，极快）
    final rng = Random();
    final indices = List.generate(_cachedPhotos!.length, (i) => i)..shuffle(rng);
    final sampleSize = min(500, _cachedPhotos!.length);
    final batchIds = indices.take(sampleSize).map((i) => _cachedPhotos![i].id).toList();
    final result = await MotionPhotoService.batchCheck(photoIds: batchIds);
    for (final entry in result.entries) {
      if (entry.value) {
        return _cachedPhotos!.firstWhere(
          (p) => p.id == entry.key,
          orElse: () => throw StateError('unreachable'),
        );
      }
    }

    return null;
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
