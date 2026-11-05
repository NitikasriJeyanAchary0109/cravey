import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notifications_state.dart';
import '../theme/app_theme.dart';

/// A bell with the number of unread notifications. Looks them up when it first appears; [onPressed] opens the screen and may act on what it returns.
class NotificationBell extends StatefulWidget {
  final VoidCallback onPressed;

  const NotificationBell({super.key, required this.onPressed});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationsState>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final unread = context.select<NotificationsState, int>((s) => s.unreadCount);
    return IconButton(
      key: const ValueKey('notification-bell'),
      tooltip: unread > 0 ? '$unread unread notifications' : 'Notifications',
      onPressed: widget.onPressed,
      icon: Badge(
        key: const ValueKey('notification-badge'),
        isLabelVisible: unread > 0,
        label: Text(unread > 9 ? '9+' : '$unread'),
        backgroundColor: AppTheme.chipOrange,
        child: const Icon(Icons.notifications_none_rounded, color: AppTheme.textDark, size: 22),
      ),
    );
  }
}
