import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:exif/exif.dart';
import 'package:photo_manager/photo_manager.dart';
import 'dart:math';
import '../services/photo_service.dart';
import '../services/view_history_service.dart';
import '../models/view_history.dart';
import '../models/time_collision.dart';
import 'preferences_provider.dart';
import 'theme_provider.dart';

/// 随机照片页面状态
class RandomPhotoState {
  final AssetEntity? photo;
  final bool isLoading;
  final String? errorMessage;
  final bool hasPermission;
  final TimeCollision? collision;
  final int selectedYear;
  final int currentPhotoIndex;
  final Uint8List? preloadedThumbnail;
  final File? preloadedFile;
  final Map<String, IfdTag>? preloadedExif;

  const RandomPhotoState({
    this.photo,
    this.isLoading = false,
    this.errorMessage,
    this.hasPermission = false,
    this.collision,
    this.selectedYear = 0,
    this.currentPhotoIndex = 0,
    this.preloadedThumbnail,
    this.preloadedFile,
    this.preloadedExif,
  });

  RandomPhotoState copyWith({
    AssetEntity? photo,
    bool? isLoading,
    String? errorMessage,
    bool? hasPermission,
    TimeCollision? collision,
    int? selectedYear,
    int? currentPhotoIndex,
    Uint8List? preloadedThumbnail,
    File? preloadedFile,
    Map<String, IfdTag>? preloadedExif,
    bool clearPreload = false,
  }) {
    return RandomPhotoState(
      photo: photo ?? this.photo,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      hasPermission: hasPermission ?? this.hasPermission,
      collision: collision ?? this.collision,
      selectedYear: selectedYear ?? this.selectedYear,
      currentPhotoIndex: currentPhotoIndex ?? this.currentPhotoIndex,
      preloadedThumbnail: clearPreload ? null : (preloadedThumbnail ?? this.preloadedThumbnail),
      preloadedFile: clearPreload ? null : (preloadedFile ?? this.preloadedFile),
      preloadedExif: clearPreload ? null : (preloadedExif ?? this.preloadedExif),
    );
  }
}

/// 照片 Provider — 管理权限请求和随机照片状态
class PhotoProvider extends AsyncNotifier<RandomPhotoState> {
  final _photoService = PhotoService();
  int _generation = 0;
  /// 会话级碰撞缓存 — photoId → TimeCollision，不查库
  final _collisionCache = <String, TimeCollision>{};
  /// 最近浏览队列（最多 10 张不重复照片，索引 0 = 最新）
  static const _recentQueueKey = 'recent_queue';
  final _recentQueue = <RecentEntry>[];

  /// 获取最近浏览历史（供弹窗使用）
  List<RecentEntry> getRecentHistory() => List.unmodifiable(_recentQueue);

  /// 从 SharedPreferences 恢复队列
  void _restoreRecentQueue() {
    final prefs = ref.read(sharedPrefsProvider);
    final raw = prefs.getString(_recentQueueKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List;
      _recentQueue.clear();
      for (final item in list) {
        final map = item as Map<String, dynamic>;
        _recentQueue.add(RecentEntry(
          map['photo_id'] as String,
          map['is_collision'] as bool,
          DateTime.parse(map['viewed_at'] as String),
        ));
      }
      // 后台预加载所有缩略图，弹窗打开时直接显示
      for (final entry in _recentQueue) {
        _cacheThumbnail(entry);
      }
    } catch (_) {}
  }

  /// 持久化队列到 SharedPreferences
  void _persistRecentQueue() {
    final prefs = ref.read(sharedPrefsProvider);
    final list = _recentQueue.map((e) => {
      'photo_id': e.photoId,
      'is_collision': e.isCollision,
      'viewed_at': e.viewedAt.toIso8601String(),
    }).toList();
    prefs.setString(_recentQueueKey, jsonEncode(list));
  }

  @override
  Future<RandomPhotoState> build() async {
    // 从持久化存储恢复最近浏览队列
    _restoreRecentQueue();
    // 初始加载：请求权限并获取一张随机照片
    final initialState = await _loadRandomPhoto();
    // 首张照片也需要后台预加载详情，使用 Future 延迟到 state 被框架设置之后执行
    Future(() {
      final photo = initialState.collision?.currentPhoto ?? initialState.photo;
      if (photo != null) _preloadCurrentPhoto(photo);
    });
    return initialState;
  }

  /// 核心逻辑：请求权限 → 随机选照片
  Future<RandomPhotoState> _loadRandomPhoto() async {
    // 1. 请求权限
    final granted = await _photoService.requestPermission();
    if (!granted) {
      return const RandomPhotoState(
        hasPermission: false,
        errorMessage: '需要相册权限才能展示您的照片',
      );
    }

    // 2. 加权随机选取一张照片（近30天看得越少权重越高）
    final recentViews = await ViewHistoryService.getRecentViewCounts();
    var photo = await _photoService.getWeightedRandomPhoto(recentViews);
    if (photo == null) {
      return const RandomPhotoState(
        hasPermission: true,
        errorMessage: '相册中没有找到照片',
      );
    }

    // 时间对撞检测 — 先确认有匹配照片，再按设定概率决定是否展示
    TimeCollision? collision;
    if (photo != null) {
      final collisionPrefs = ref.read(collisionPrefsProvider);
      if (collisionPrefs.enabled) {
        final groups = await _photoService.findSameDayPhotos(photo);
        if (groups.length >= 2 &&
            Random().nextDouble() < collisionPrefs.probability) {
          final years = groups.keys.toList()..sort();
          final newestYear = years.last;
          collision = TimeCollision(groups: groups, selectedYear: newestYear);
          // photo 切到碰撞卡片实际展示的第一张，详情面板才能匹配
          photo = collision.currentPhoto;
        }
      }
    }

    // 记录浏览历史（碰撞检测之后，明确知晓是否碰撞）
    try {
      await ViewHistoryService.create(ViewHistory(
        photoId: photo.id,
        viewedAt: DateTime.now(),
        isCollision: collision != null,
      ));
    } catch (_) {}
    // 碰撞数据缓存到内存，供历史抽取使用
    if (collision != null) {
      _collisionCache[collision.currentPhoto.id] = collision;
    }
    _addToRecentQueue(photo.id, collision != null);

    return RandomPhotoState(
      photo: photo,
      hasPermission: true,
      collision: collision,
      selectedYear: collision?.selectedYear ?? 0,
    );
  }

  /// 强制加载一张具有时间对撞数据的照片（测试用）
  Future<void> loadCollisionPhoto() async {
    final granted = await _photoService.requestPermission();
    if (!granted) return;

    final gen = ++_generation;
    // 遍历缓存找到有同月同日匹配的照片
    final collision = await _photoService.findAnyCollision();
    if (collision == null) {
      state = AsyncData(RandomPhotoState(
        hasPermission: true,
        errorMessage: '没有找到适合时间对撞的照片',
      ));
      return;
    }

    final state2 = RandomPhotoState(
      photo: collision.currentPhoto,
      hasPermission: true,
      collision: collision,
      selectedYear: collision.selectedYear,
    );
    state = AsyncData(state2);

    // 预加载
    final photo = collision.currentPhoto;
    Uint8List? thumb;
    try { thumb = await photo.thumbnailDataWithSize(const ThumbnailSize(320, 320), quality: 90); } catch (_) {}
    if (gen != _generation) return;
    File? file;
    try { file = await photo.file; } catch (_) {}
    if (gen != _generation) return;
    Map<String, IfdTag>? exif;
    if (file != null) { try { exif = await readExifFromFile(file); } catch (_) {} }
    if (gen != _generation) return;
    state = AsyncData(state2.copyWith(preloadedThumbnail: thumb, preloadedFile: file, preloadedExif: exif));
  }

  /// 按照片ID加载指定照片（历史抽取用）
  /// [isCollision] 为 true 时从内存缓存取碰撞数据，不查库
  Future<void> loadByPhotoId(String photoId, {bool isCollision = false}) async {
    var photo = await _photoService.getPhotoById(photoId);
    if (photo == null) return;

    // 从内存缓存取碰撞数据（_collisionCache，session 级）
    TimeCollision? collision;
    if (isCollision) {
      collision = _collisionCache[photoId];
      if (collision != null) photo = collision.currentPhoto;
    }

    // 记录浏览历史
    try {
      await ViewHistoryService.create(ViewHistory(
        photoId: photo.id,
        viewedAt: DateTime.now(),
        isCollision: collision != null,
      ));
    } catch (_) {}

    _addToRecentQueue(photo.id, collision != null);

    state = AsyncData(RandomPhotoState(
      photo: photo,
      hasPermission: true,
      collision: collision,
      selectedYear: collision?.selectedYear ?? 0,
    ));
    _preloadCurrentPhoto(photo);
  }

  /// 更新最近浏览队列（判重 + 保持最多 10 条），后台加载缩略图到缓存
  void _addToRecentQueue(String photoId, bool isCollision) {
    _recentQueue.removeWhere((e) => e.photoId == photoId);
    final entry = RecentEntry(photoId, isCollision, DateTime.now());
    _recentQueue.insert(0, entry);
    if (_recentQueue.length > 10) _recentQueue.removeLast();
    // 持久化到磁盘，重启后保留
    _persistRecentQueue();
    // 异步加载缩略图到内存，供历史弹窗直接使用
    _cacheThumbnail(entry);
  }

  Future<void> _cacheThumbnail(RecentEntry entry) async {
    final entity = await _photoService.getPhotoById(entry.photoId);
    if (entity == null) return;
    final thumb = await entity.thumbnailDataWithSize(
      const ThumbnailSize(120, 120), quality: 85,
    );
    entry.thumbnail = thumb;
  }

  /// 切换到对撞模式中的指定年份
  void selectCollisionYear(int year) {
    final current = state.asData?.value;
    if (current?.collision == null) return;
    final photos = current!.collision!.groups[year];
    final newPhoto = photos?.isNotEmpty == true ? photos!.first : current.photo;
    state = AsyncData(current.copyWith(
      selectedYear: year,
      currentPhotoIndex: 0,
      photo: newPhoto,
      collision: current.collision!.copyWith(selectedYear: year),
    ));
    // 后台预加载当前照片的详情（缩略图、文件、EXIF），供详情面板使用
    if (newPhoto != null) _preloadCurrentPhoto(newPhoto);
  }

  /// 切换到对撞模式中当前年份的指定照片
  void selectCollisionPhoto(int index) {
    final current = state.asData?.value;
    if (current?.collision == null) return;
    final photos = current!.collision!.groups[current.selectedYear];
    if (photos == null || index >= photos.length) return;
    state = AsyncData(current.copyWith(
      currentPhotoIndex: index,
      photo: photos[index],
    ));
    // 后台预加载当前照片的详情（缩略图、文件、EXIF），供详情面板使用
    _preloadCurrentPhoto(photos[index]);
  }

  /// 后台预加载指定照片的详情信息（缩略图、文件、EXIF）
  /// 完成后再更新 state，供详情面板 _DrawerContent 直接使用
  Future<void> _preloadCurrentPhoto(AssetEntity photo) async {
    final gen = ++_generation;
    final stateValue = state.asData?.value;
    if (stateValue == null) return;

    // 各自独立加载，互不影响 — 单个失败不影响其他
    Uint8List? thumb;
    try {
      thumb = await photo.thumbnailDataWithSize(
        const ThumbnailSize(320, 320), quality: 90,
      );
    } catch (_) {}

    if (gen != _generation) return;

    File? file;
    try {
      file = await photo.file;
    } catch (_) {}

    if (gen != _generation) return;

    Map<String, IfdTag>? exif;
    try {
      // iOS: originBytes 比 photo.file 更可靠（HEIC 兼容）
      final bytes = await photo.originBytes;
      if (bytes != null) {
        exif = await readExifFromBytes(bytes);
      }
    } catch (_) {}
    if (exif == null && file != null) {
      try {
        exif = await readExifFromFile(file);
      } catch (_) {}
    }

    if (gen != _generation) return;

    final current = state.asData?.value;
    // 确保预加载的照片仍是当前显示的照片（避免与删除/切换操作竞态）
    if (current == null || current.photo?.id != photo.id) return;

    state = AsyncData(current.copyWith(
      preloadedThumbnail: thumb,
      preloadedFile: file,
      preloadedExif: exif,
    ));
  }

  /// 刷新：重新随机选取一张照片
  ///
  /// 不设置 AsyncLoading，保持当前照片可见直到新照片就绪，
  /// 避免闪烁 loading 转圈。换图后立即后台预加载详情信息。
  Future<void> refresh() async {
    final next = await _loadRandomPhoto();
    state = AsyncData(next);
    final photo = next.collision?.currentPhoto ?? next.photo;
    if (photo != null) _preloadCurrentPhoto(photo);
  }

  /// 删除当前照片，刷新到下一张
  Future<bool> deleteCurrentPhoto() async {
    final stateValue = state.asData?.value;
    final current = stateValue?.photo;
    if (current == null) return false;

    final success = await _photoService.deletePhoto(current);
    if (!success) return false;

    // 时间对撞模式：从分组中移除照片，不直接重抽
    if (stateValue?.collision != null) {
      final collision = stateValue!.collision!;
      final groups = Map<int, List<AssetEntity>>.from(collision.groups);
      // 使用 stateValue.selectedYear 而非 collision.selectedYear，
      // 因为 selectCollisionYear 会更新前者但可能未同步后者
      final currentYear = stateValue.selectedYear;

      // 找到已删除照片在列表中的位置
      final oldPhotos = groups[currentYear]!;
      final deletedIdx = oldPhotos.indexWhere((p) => p.id == current.id);

      // 从当前年份中移除已删除的照片
      final updatedPhotos = oldPhotos.where((p) => p.id != current.id).toList();
      if (updatedPhotos.isEmpty) {
        groups.remove(currentYear);
      } else {
        groups[currentYear] = updatedPhotos;
      }

      if (groups.isEmpty) {
        refresh();
      } else {
        final newYear = groups.containsKey(currentYear) ? currentYear : groups.keys.first;
        final photos = groups[newYear]!;
        final nextIdx = newYear == currentYear ? deletedIdx.clamp(0, photos.length - 1) : 0;
        final nextPhoto = photos[nextIdx];
        state = AsyncData(stateValue.copyWith(
          collision: TimeCollision(groups: groups, selectedYear: newYear),
          selectedYear: newYear,
          currentPhotoIndex: nextIdx,
          photo: nextPhoto,
        ));
        // 删除后自动切换到下一张，也需要预加载新照片的详情
        _preloadCurrentPhoto(nextPhoto);
      }
      return true;
    }

    // 普通模式：删除后重抽
    refresh();
    return success;
  }

  /// 重新请求权限（用户从设置返回后调用）
  Future<void> retryPermission() async {
    state = const AsyncLoading();
    state = AsyncData(await _loadRandomPhoto());
  }
}

/// 对外暴露的 Provider
final photoProvider = AsyncNotifierProvider<PhotoProvider, RandomPhotoState>(
  PhotoProvider.new,
);

/// 最近浏览队列条目
class RecentEntry {
  final String photoId;
  final bool isCollision;
  final DateTime viewedAt;
  Uint8List? thumbnail;

  RecentEntry(this.photoId, this.isCollision, this.viewedAt);
}
