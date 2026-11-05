import 'package:flutter/foundation.dart';
import '../repositories/notification_repository.dart';
import '../services/api_client.dart';
import 'models.dart';

/// The signed-in person's notifications and how many are unread (the bell's badge). Marking and deleting show at once and are put back if the server says no.
class NotificationsState extends ChangeNotifier {
  NotificationsState({required NotificationRepository repository, this.identity}) : _repo = repository;

  final NotificationRepository _repo;

  /// Who is signed in (an email, or null). When it changes, the previous person's notifications are dropped before anything is shown.
  final String? Function()? identity;
  String? _loadedFor;

  List<NotificationModel> _items = const [];
  bool _loading = false;
  bool _loadedOnce = false;
  String? _error;
  bool _disposed = false;

  List<NotificationModel> get items => _items;
  bool get loading => _loading;
  bool get loadedOnce => _loadedOnce;
  String? get error => _error;
  int get unreadCount => _items.where((n) => !n.isRead).length;

  Future<void> load() async {
    if (_loading) return;
    final who = identity?.call();
    if (who != _loadedFor) {
      _items = const [];
      _loadedFor = who;
      _loadedOnce = false;
    }
    _loading = true;
    _error = null;
    _notify();
    try {
      _items = await _repo.mine();
      _loadedOnce = true;
    } catch (e) {
      // a signed-out visitor or a server that is down: the badge simply shows nothing
      _error = e is ApiException ? e.message : 'Could not load notifications.';
    } finally {
      _loading = false;
      _notify();
    }
  }

  /// Forgets everything, for sign-out.
  void clear() {
    _items = const [];
    _loadedOnce = false;
    _error = null;
    _notify();
  }

  Future<String?> markRead(NotificationModel n) async {
    if (n.id == null || n.isRead) return null;
    final before = _items;
    _items = [for (final x in _items) x.id == n.id ? x.copyWith(isRead: true) : x];
    _notify();
    return _try(() => _repo.markRead(n.id!), before, 'Could not mark it as read.');
  }

  Future<String?> markAllRead() async {
    if (unreadCount == 0) return null;
    final before = _items;
    _items = [for (final x in _items) x.copyWith(isRead: true)];
    _notify();
    return _try(_repo.markAllRead, before, 'Could not mark them all as read.');
  }

  Future<String?> remove(NotificationModel n) async {
    if (n.id == null) return null;
    final before = _items;
    _items = _items.where((x) => x.id != n.id).toList();
    _notify();
    return _try(() => _repo.remove(n.id!), before, 'Could not delete it.');
  }

  Future<String?> _try(Future<void> Function() call, List<NotificationModel> before, String fallback) async {
    try {
      await call();
      return null;
    } catch (e) {
      _items = before;
      _notify();
      return e is ApiException ? e.message : fallback;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
