import '../models/models.dart';

/// What the notifications screen needs from /api/notifications: only the signed-in person's own.
abstract class NotificationRepository {
  /// Newest first.
  Future<List<NotificationModel>> mine();

  Future<void> markRead(int id);

  Future<void> markAllRead();

  Future<void> remove(int id);
}
