/// 浏览历史记录模型
class ViewHistory {
  final int? id;
  final String photoId;
  final DateTime viewedAt;

  const ViewHistory({
    this.id,
    required this.photoId,
    required this.viewedAt,
  });

  factory ViewHistory.fromMap(Map<String, dynamic> map) {
    return ViewHistory(
      id: map['id'] as int,
      photoId: map['photo_id'] as String,
      viewedAt: DateTime.parse(map['viewed_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'photo_id': photoId,
      'viewed_at': viewedAt.toIso8601String(),
    };
  }
}
