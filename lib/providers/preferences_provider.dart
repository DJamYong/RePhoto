import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme_provider.dart';

/// 主页照片信息显示偏好
class PhotoDisplayPrefs {
  /// 是否显示拍摄日期
  final bool showDate;
  /// 是否显示照片年龄（拍摄于 X 年前）
  final bool showAge;

  const PhotoDisplayPrefs({
    this.showDate = true,
    this.showAge = false,
  });

  PhotoDisplayPrefs copyWith({
    bool? showDate,
    bool? showAge,
  }) {
    return PhotoDisplayPrefs(
      showDate: showDate ?? this.showDate,
      showAge: showAge ?? this.showAge,
    );
  }
}

/// 照片信息显示偏好 Notifier
class PhotoDisplayPrefsNotifier extends Notifier<PhotoDisplayPrefs> {
  static const _keyShowDate = 'photo_showDate';
  static const _keyShowAge = 'photo_showAge';

  @override
  PhotoDisplayPrefs build() {
    final prefs = ref.watch(sharedPrefsProvider);
    return PhotoDisplayPrefs(
      showDate: prefs.getBool(_keyShowDate) ?? true,
      showAge: prefs.getBool(_keyShowAge) ?? false,
    );
  }

  void setShowDate(bool value) {
    state = state.copyWith(showDate: value);
    ref.read(sharedPrefsProvider).setBool(_keyShowDate, value);
  }

  void setShowAge(bool value) {
    state = state.copyWith(showAge: value);
    ref.read(sharedPrefsProvider).setBool(_keyShowAge, value);
  }
}

/// 照片信息显示偏好 Provider
final photoDisplayPrefsProvider =
    NotifierProvider<PhotoDisplayPrefsNotifier, PhotoDisplayPrefs>(
        PhotoDisplayPrefsNotifier.new);
