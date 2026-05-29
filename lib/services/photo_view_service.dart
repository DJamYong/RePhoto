import '../models/photo_view.dart';
import 'database_service.dart';

/// 照片浏览记录 DAO
class PhotoViewService {
  static const _table = 'photo_views';

  /// 获取某张照片的浏览记录，不存在则返回 null
  static Future<PhotoView?> getByPhotoId(String photoId) async {
    final rows = await DatabaseService.db.query(
      _table,
      where: 'photo_id = ?',
      whereArgs: [photoId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PhotoView.fromMap(rows.first);
  }

  /// 记录一次浏览：若已存在则 viewCount +1，否则新建
  static Future<void> recordView(String photoId) async {
    final now = DateTime.now();
    final existing = await getByPhotoId(photoId);

    if (existing != null) {
      await DatabaseService.db.rawUpdate(
        'UPDATE $_table SET view_count = view_count + 1, last_viewed_at = ? WHERE photo_id = ?',
        [now.toIso8601String(), photoId],
      );
    } else {
      await DatabaseService.db.insert(_table, {
        'photo_id': photoId,
        'view_count': 1,
        'first_viewed_at': now.toIso8601String(),
        'last_viewed_at': now.toIso8601String(),
      });
    }
  }

  /// 获取所有记录，按最后浏览时间倒序
  static Future<List<PhotoView>> getAll({int? limit}) async {
    final rows = await DatabaseService.db.query(
      _table,
      orderBy: 'last_viewed_at DESC',
      limit: limit,
    );
    return rows.map(PhotoView.fromMap).toList();
  }

  /// 删除指定照片的浏览记录
  static Future<int> delete(String photoId) async {
    return await DatabaseService.db.delete(
      _table,
      where: 'photo_id = ?',
      whereArgs: [photoId],
    );
  }
}
