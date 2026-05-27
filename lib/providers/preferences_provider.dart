import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 主页照片信息显示偏好
class PhotoDisplayPrefs {
  /// 是否显示拍摄日期
  final bool showDate;
  /// 是否显示文件名
  final bool showTitle;

  const PhotoDisplayPrefs({
    this.showDate = true,
    this.showTitle = false,
  });

  PhotoDisplayPrefs copyWith({
    bool? showDate,
    bool? showTitle,
  }) {
    return PhotoDisplayPrefs(
      showDate: showDate ?? this.showDate,
      showTitle: showTitle ?? this.showTitle,
    );
  }
}

/// 照片信息显示偏好 Notifier
class PhotoDisplayPrefsNotifier extends Notifier<PhotoDisplayPrefs> {
  @override
  PhotoDisplayPrefs build() => const PhotoDisplayPrefs();

  void setShowDate(bool value) =>
      state = state.copyWith(showDate: value);
  void setShowTitle(bool value) =>
      state = state.copyWith(showTitle: value);
}

/// 照片信息显示偏好 Provider
final photoDisplayPrefsProvider =
    NotifierProvider<PhotoDisplayPrefsNotifier, PhotoDisplayPrefs>(
        PhotoDisplayPrefsNotifier.new);
