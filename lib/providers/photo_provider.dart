import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:exif/exif.dart';
import 'package:photo_manager/photo_manager.dart';
import '../services/photo_service.dart';
import '../services/view_history_service.dart';
import '../models/view_history.dart';

/// 随机照片页面状态
class RandomPhotoState {
  final AssetEntity? photo;
  final bool isLoading;
  final String? errorMessage;
  final bool hasPermission;
  final Uint8List? preloadedThumbnail;
  final File? preloadedFile;
  final Map<String, IfdTag>? preloadedExif;

  const RandomPhotoState({
    this.photo,
    this.isLoading = false,
    this.errorMessage,
    this.hasPermission = false,
    this.preloadedThumbnail,
    this.preloadedFile,
    this.preloadedExif,
  });

  RandomPhotoState copyWith({
    AssetEntity? photo,
    bool? isLoading,
    String? errorMessage,
    bool? hasPermission,
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

  @override
  Future<RandomPhotoState> build() async {
    // 初始加载：请求权限并获取一张随机照片
    return _loadRandomPhoto();
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
    final photo = await _photoService.getWeightedRandomPhoto(recentViews);
    if (photo == null) {
      return const RandomPhotoState(
        hasPermission: true,
        errorMessage: '相册中没有找到照片',
      );
    }

    // 记录浏览历史
    try {
      await ViewHistoryService.create(ViewHistory(
        photoId: photo.id,
        viewedAt: DateTime.now(),
      ));
    } catch (_) {}

    return RandomPhotoState(
      photo: photo,
      hasPermission: true,
    );
  }

  /// 刷新：重新随机选取一张照片
  ///
  /// 不设置 AsyncLoading，保持当前照片可见直到新照片就绪，
  /// 避免闪烁 loading 转圈。换图后立即后台预加载详情信息。
  Future<void> refresh() async {
    final gen = ++_generation;
    final next = await _loadRandomPhoto();
    state = AsyncData(next);

    // 后台预加载缩略图、文件、EXIF，供详情面板直接使用
    final photo = next.photo;
    if (photo != null) {
      try {
        final thumbFuture = photo.thumbnailDataWithSize(
          const ThumbnailSize(320, 320),
          quality: 90,
        );
        final fileFuture = photo.file;
        final results = await Future.wait([thumbFuture, fileFuture]);

        // 预加载期间如果有新的 refresh，丢弃旧结果
        if (gen != _generation) return;

        final thumb = results[0] as Uint8List?;
        final file = results[1] as File?;

        // 有文件后再读取 EXIF
        Map<String, IfdTag>? exif;
        if (file != null) {
          try {
            exif = await readExifFromFile(file);
          } catch (_) {}
        }

        if (gen != _generation) return;

        state = AsyncData(next.copyWith(
          preloadedThumbnail: thumb,
          preloadedFile: file,
          preloadedExif: exif,
        ));
      } catch (_) {
        // 预加载失败不影响主界面，详情面板会自行加载
      }
    }
  }

  /// 删除当前照片，刷新到下一张
  Future<bool> deleteCurrentPhoto() async {
    final current = state.asData?.value.photo;
    if (current == null) return false;

    final success = await _photoService.deletePhoto(current);
    if (success) {
      // 删除成功后跳到下一张
      refresh();
    }
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
