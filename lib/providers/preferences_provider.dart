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

/// 时间对撞偏好
class CollisionPrefs {
  final bool enabled;
  final double probability; // 0.0 ~ 1.0

  const CollisionPrefs({
    this.enabled = false,
    this.probability = 0.03,
  });

  CollisionPrefs copyWith({
    bool? enabled,
    double? probability,
  }) {
    return CollisionPrefs(
      enabled: enabled ?? this.enabled,
      probability: probability ?? this.probability,
    );
  }
}

class CollisionPrefsNotifier extends Notifier<CollisionPrefs> {
  static const _keyEnabled = 'collision_enabled';
  static const _keyProbability = 'collision_probability';

  @override
  CollisionPrefs build() {
    final prefs = ref.watch(sharedPrefsProvider);
    return CollisionPrefs(
      enabled: prefs.getBool(_keyEnabled) ?? false,
      probability: prefs.getDouble(_keyProbability) ?? 0.03,
    );
  }

  void setEnabled(bool value) {
    state = state.copyWith(enabled: value);
    ref.read(sharedPrefsProvider).setBool(_keyEnabled, value);
  }

  void setProbability(double value) {
    state = state.copyWith(probability: value);
    ref.read(sharedPrefsProvider).setDouble(_keyProbability, value);
  }
}

final collisionPrefsProvider =
    NotifierProvider<CollisionPrefsNotifier, CollisionPrefs>(
        CollisionPrefsNotifier.new);
