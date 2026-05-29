/// 照片浏览记录模型
class PhotoView {
  final String photoId;
  final int viewCount;
  final DateTime firstViewedAt;
  final DateTime lastViewedAt;

  const PhotoView({
    required this.photoId,
    this.viewCount = 0,
    required this.firstViewedAt,
    required this.lastViewedAt,
  });

  /// 从数据库行记录构造
  factory PhotoView.fromMap(Map<String, dynamic> map) {
    return PhotoView(
      photoId: map['photo_id'] as String,
      viewCount: map['view_count'] as int,
      firstViewedAt: DateTime.parse(map['first_viewed_at'] as String),
      lastViewedAt: DateTime.parse(map['last_viewed_at'] as String),
    );
  }

  /// 转为数据库行记录
  Map<String, dynamic> toMap() {
    return {
      'photo_id': photoId,
      'view_count': viewCount,
      'first_viewed_at': firstViewedAt.toIso8601String(),
      'last_viewed_at': lastViewedAt.toIso8601String(),
    };
  }

  /// 复制并增加浏览次数
  PhotoView incrementView() {
    return PhotoView(
      photoId: photoId,
      viewCount: viewCount + 1,
      firstViewedAt: firstViewedAt,
      lastViewedAt: DateTime.now(),
    );
  }
}
