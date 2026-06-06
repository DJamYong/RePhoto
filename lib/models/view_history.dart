/// 浏览历史记录模型
class ViewHistory {
  final int? id;
  final String photoId;
  final DateTime viewedAt;
  final bool isCollision;

  const ViewHistory({
    this.id,
    required this.photoId,
    required this.viewedAt,
    this.isCollision = false,
  });

  factory ViewHistory.fromMap(Map<String, dynamic> map) {
    return ViewHistory(
      id: map['id'] as int,
      photoId: map['photo_id'] as String,
      viewedAt: DateTime.parse(map['viewed_at'] as String),
      isCollision: (map['is_collision'] as int?) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'photo_id': photoId,
      'viewed_at': viewedAt.toIso8601String(),
      'is_collision': isCollision ? 1 : 0,
    };
  }
}
