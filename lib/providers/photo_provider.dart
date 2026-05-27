import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import '../services/photo_service.dart';

/// 随机照片页面状态
class RandomPhotoState {
  final AssetEntity? photo;
  final bool isLoading;
  final String? errorMessage;
  final bool hasPermission;

  const RandomPhotoState({
    this.photo,
    this.isLoading = false,
    this.errorMessage,
    this.hasPermission = false,
  });

  RandomPhotoState copyWith({
    AssetEntity? photo,
    bool? isLoading,
    String? errorMessage,
    bool? hasPermission,
  }) {
    return RandomPhotoState(
      photo: photo ?? this.photo,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      hasPermission: hasPermission ?? this.hasPermission,
    );
  }
}

/// 照片 Provider — 管理权限请求和随机照片状态
class PhotoProvider extends AsyncNotifier<RandomPhotoState> {
  final _photoService = PhotoService();

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

    // 2. 随机选取一张照片
    final photo = await _photoService.getRandomPhoto();
    if (photo == null) {
      return const RandomPhotoState(
        hasPermission: true,
        errorMessage: '相册中没有找到照片',
      );
    }

    return RandomPhotoState(
      photo: photo,
      hasPermission: true,
    );
  }

  /// 刷新：重新随机选取一张照片
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _loadRandomPhoto());
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
