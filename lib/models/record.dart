/// 记录预设颜色列表（ARGB 整数值）
class RecordColors {
  static const int? none = null;
  static const int red    = 0xFFE74C3C;
  static const int orange = 0xFFF39C12;
  static const int yellow = 0xFFFFD93D;
  static const int green  = 0xFF6BCB77;
  static const int teal   = 0xFF4ECDC4;
  static const int blue   = 0xFF5B86E5;
  static const int purple = 0xFFA55EEA;
  static const int grey   = 0xFFB0BEC5;

  static const List<int?> all = [
    none,
    red,
    orange,
    yellow,
    green,
    teal,
    blue,
    purple,
    grey,
  ];
}

/// 照片记录模型（日记 / 备注）
class Record {
  final int? id;
  final String photoId;
  final String content;
  final String? mood;
  final int? color; // ARGB 颜色值
  final DateTime createdAt;
  final DateTime updatedAt;

  const Record({
    this.id,
    required this.photoId,
    required this.content,
    this.mood,
    this.color,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 从数据库行记录构造
  factory Record.fromMap(Map<String, dynamic> map) {
    return Record(
      id: map['id'] as int,
      photoId: map['photo_id'] as String,
      content: map['content'] as String,
      mood: map['mood'] as String?,
      color: map['color'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// 转为数据库行记录（不含自增 id）
  Map<String, dynamic> toMap() {
    return {
      'photo_id': photoId,
      'content': content,
      'mood': mood,
      'color': color,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// 更新内容（更新时间自动刷新）
  Record copyWith({
    String? content,
    String? mood,
    int? color,
  }) {
    return Record(
      id: id,
      photoId: photoId,
      content: content ?? this.content,
      mood: mood ?? this.mood,
      color: color ?? this.color,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
