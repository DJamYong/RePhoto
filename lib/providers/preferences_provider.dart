import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme_provider.dart';

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
  static const _keyShowDate = 'photo_showDate';
  static const _keyShowTitle = 'photo_showTitle';

  @override
  PhotoDisplayPrefs build() {
    final prefs = ref.watch(sharedPrefsProvider);
    return PhotoDisplayPrefs(
      showDate: prefs.getBool(_keyShowDate) ?? true,
      showTitle: prefs.getBool(_keyShowTitle) ?? false,
    );
  }

  void setShowDate(bool value) {
    state = state.copyWith(showDate: value);
    ref.read(sharedPrefsProvider).setBool(_keyShowDate, value);
  }

  void setShowTitle(bool value) {
    state = state.copyWith(showTitle: value);
    ref.read(sharedPrefsProvider).setBool(_keyShowTitle, value);
  }
}

/// 照片信息显示偏好 Provider
final photoDisplayPrefsProvider =
    NotifierProvider<PhotoDisplayPrefsNotifier, PhotoDisplayPrefs>(
        PhotoDisplayPrefsNotifier.new);
