import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../models/notifications_state.dart';
import '../theme/app_theme.dart';

/// "just now", "5 min ago", "3 h ago", "yesterday", "4 days ago", then the date.
String timeAgo(DateTime? time, DateTime now) {
  if (time == null) return '';
  final d = now.difference(time);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  if (d.inDays == 1) return 'yesterday';
  if (d.inDays < 7) return '${d.inDays} days ago';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${time.day} ${months[time.month - 1]}';
}

const String kWeeklyDigestType = 'WEEKLY_DIGEST';

/// The signed-in person's notifications, newest first. Tapping one marks it read; swiping or the bin deletes it. A weekly digest has an "Open Insights"
/// button: the screen then closes with the result `'insights'`, which the owner dashboard uses to switch to that tab.
class NotificationsScreen extends StatefulWidget {
  /// Replaceable so a test can fix the clock.
  final DateTime Function() now;

  const NotificationsScreen({super.key, this.now = DateTime.now});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationsState>().load();
    });
  }

  void _say(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _run(Future<String?> action) async {
    final error = await action;
    if (error != null && mounted) _say(error);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<NotificationsState>();
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textBrown)),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textBrown,
        elevation: 0.5,
        actions: [
          TextButton(
            key: const ValueKey('notifications-mark-all'),
            onPressed: state.unreadCount == 0 ? null : () => _run(state.markAllRead()),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: state.load, child: _body(state)),
    );
  }

  Widget _body(NotificationsState state) {
    if (state.loading && !state.loadedOnce) {
      return ListView(children: const [SizedBox(height: 160), Center(child: CircularProgressIndicator())]);
    }
    if (state.error != null && state.items.isEmpty) {
      return ListView(padding: const EdgeInsets.all(24), children: [
        const SizedBox(height: 80),
        Icon(Icons.cloud_off_rounded, size: 40, color: Colors.grey.shade500),
        const SizedBox(height: 12),
        Text(state.error!, key: const ValueKey('notifications-error'), textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        Center(child: TextButton(key: const ValueKey('notifications-retry'), onPressed: state.load, child: const Text('Try again'))),
      ]);
    }
    if (state.items.isEmpty) {
      return ListView(padding: const EdgeInsets.all(24), children: [
        const SizedBox(height: 80),
        Icon(Icons.notifications_none_rounded, size: 44, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Text('Nothing yet. Your weekly summary will show up here.',
            key: const ValueKey('notifications-empty'), textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700, fontSize: 15)),
      ]);
    }
    return ListView.builder(
      key: const ValueKey('notifications-list'),
      padding: const EdgeInsets.all(14),
      itemCount: state.items.length,
      itemBuilder: (context, i) {
        final n = state.items[i];
        return _NotificationCard(
          key: ValueKey('notification-${n.id}'),
          notification: n,
          now: widget.now(),
          onTap: () => _run(state.markRead(n)),
          onDelete: () => _run(state.remove(n)),
          onOpenInsights: () async {
            await state.markRead(n);
            if (context.mounted) Navigator.of(context).pop('insights');
          },
        );
      },
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onOpenInsights;

  const _NotificationCard({super.key, required this.notification, required this.now, required this.onTap, required this.onDelete, required this.onOpenInsights});

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final digest = n.type == kWeeklyDigestType;
    return Dismissible(
      key: ValueKey('dismiss-${n.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.only(right: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: n.isRead ? Colors.white : const Color(0xFFFFF3E8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: n.isRead ? Colors.grey.shade200 : AppTheme.chipOrange.withValues(alpha: 0.5)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: AppTheme.chipOrange.withValues(alpha: 0.14), shape: BoxShape.circle),
                child: Icon(digest ? Icons.insights_rounded : Icons.notifications_rounded, size: 20, color: AppTheme.chipOrange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(digest ? 'Weekly digest' : 'Notification', style: TextStyle(fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w800, color: AppTheme.textBrown))),
                    if (!n.isRead) Container(key: ValueKey('unread-dot-${n.id}'), width: 9, height: 9, decoration: const BoxDecoration(color: AppTheme.chipOrange, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                  ]),
                  const SizedBox(height: 4),
                  Text(n.message, style: const TextStyle(fontSize: 13.5, height: 1.35)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Text(timeAgo(n.timestamp, now), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const Spacer(),
                    if (digest) TextButton(key: ValueKey('notification-open-insights-${n.id}'), onPressed: onOpenInsights, child: const Text('Open Insights')),
                  ]),
                ]),
              ),
              IconButton(
                key: ValueKey('notification-delete-${n.id}'),
                tooltip: 'Delete',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close_rounded, size: 18, color: Colors.grey.shade500),
                onPressed: onDelete,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
