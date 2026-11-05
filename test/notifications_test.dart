import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tomatoo/models/models.dart';
import 'package:tomatoo/models/notifications_state.dart';
import 'package:tomatoo/repositories/notification_repository.dart';
import 'package:tomatoo/screens/notifications_screen.dart';
import 'package:tomatoo/services/api_client.dart';
import 'package:tomatoo/widgets/notification_bell.dart';

class _FakeRepo implements NotificationRepository {
  List<NotificationModel> items = [];
  Object? failWith;
  final calls = <String>[];
  int loads = 0;

  @override
  Future<List<NotificationModel>> mine() async {
    loads++;
    if (failWith != null) throw failWith!;
    return items;
  }

  @override
  Future<void> markRead(int id) async {
    calls.add('read $id');
    if (failWith != null) throw failWith!;
  }

  @override
  Future<void> markAllRead() async {
    calls.add('read-all');
    if (failWith != null) throw failWith!;
  }

  @override
  Future<void> remove(int id) async {
    calls.add('remove $id');
    if (failWith != null) throw failWith!;
  }
}

final DateTime _now = DateTime(2026, 11, 5, 12, 0);

NotificationModel _n(int id, {String type = 'WEEKLY_DIGEST', bool read = false, Duration ago = const Duration(hours: 3), String? message}) =>
    NotificationModel(id: id, message: message ?? 'Your week on Cravey: 2 new suggestions. Open Insights for details.', type: type, isRead: read, timestamp: _now.subtract(ago));

void main() {
  group('NotificationModel', () {
    test('reads the server response, with the time as ISO text or milliseconds', () {
      final iso = NotificationModel.fromJson({'id': 4, 'message': 'hi', 'type': 'T', 'isRead': true, 'timestamp': '2026-11-05T06:30:00.000+00:00'});
      expect(iso.isRead, isTrue);
      expect(iso.timestamp!.toUtc(), DateTime.utc(2026, 11, 5, 6, 30));
      final ms = NotificationModel.fromJson({'id': 5, 'message': 'x', 'timestamp': 1793000000000});
      expect(ms.timestamp!.millisecondsSinceEpoch, 1793000000000);
      expect(NotificationModel.fromJson({'id': 6, 'message': 'x', 'read': true}).isRead, isTrue, reason: 'older responses called it read');
      expect(NotificationModel.fromJson({'id': 7, 'message': 'x'}).isRead, isFalse);
      expect(NotificationModel.fromJson({'id': 8, 'message': 'x', 'timestamp': 'not a time'}).timestamp, isNull);
    });
  });

  group('timeAgo', () {
    test('says it the way people do', () {
      expect(timeAgo(null, _now), '');
      expect(timeAgo(_now.subtract(const Duration(seconds: 20)), _now), 'just now');
      expect(timeAgo(_now.subtract(const Duration(minutes: 5)), _now), '5 min ago');
      expect(timeAgo(_now.subtract(const Duration(hours: 3)), _now), '3 h ago');
      expect(timeAgo(_now.subtract(const Duration(hours: 30)), _now), 'yesterday');
      expect(timeAgo(_now.subtract(const Duration(days: 4)), _now), '4 days ago');
      expect(timeAgo(DateTime(2026, 10, 1), _now), '1 Oct');
    });
  });

  group('NotificationsState', () {
    late _FakeRepo repo;
    late NotificationsState state;
    String? who;

    setUp(() {
      repo = _FakeRepo()..items = [_n(1), _n(2, read: true), _n(3)];
      who = 'a@x.test';
      state = NotificationsState(repository: repo, identity: () => who);
    });

    tearDown(() => state.dispose());

    test('loads and counts the unread', () async {
      await state.load();
      expect(state.items, hasLength(3));
      expect(state.unreadCount, 2);
      expect(state.loadedOnce, isTrue);
    });

    test('marking one read shows at once and goes to the server once', () async {
      await state.load();
      final err = await state.markRead(state.items.first);
      expect(err, isNull);
      expect(state.unreadCount, 1);
      expect(repo.calls, ['read 1']);
      await state.markRead(state.items[1]); // already read: nothing to send
      expect(repo.calls, ['read 1']);
    });

    test('a refused change is put back with a message', () async {
      await state.load();
      repo.failWith = ApiException('Not yours', statusCode: 403);
      expect(await state.markRead(state.items.first), 'Not yours');
      expect(state.unreadCount, 2, reason: 'back to how it was');
      expect(await state.remove(state.items.first), 'Not yours');
      expect(state.items, hasLength(3));
      expect(await state.markAllRead(), 'Not yours');
      expect(state.unreadCount, 2);
    });

    test('mark all and delete', () async {
      await state.load();
      expect(await state.markAllRead(), isNull);
      expect(state.unreadCount, 0);
      expect(repo.calls, ['read-all']);
      expect(await state.markAllRead(), isNull);
      expect(repo.calls, ['read-all'], reason: 'nothing unread, nothing sent');
      await state.remove(state.items.first);
      expect(state.items.map((n) => n.id), [2, 3]);
      expect(repo.calls.last, 'remove 1');
    });

    test('a failed load keeps the screen from lying and can be retried', () async {
      repo.failWith = ApiException('Please sign in.', statusCode: 401);
      await state.load();
      expect(state.error, 'Please sign in.');
      expect(state.items, isEmpty);
      repo.failWith = null;
      await state.load();
      expect(state.error, isNull);
      expect(state.items, hasLength(3));
    });

    test('someone else signing in never sees the last person\'s notifications', () async {
      await state.load();
      expect(state.items, hasLength(3));
      who = 'b@x.test';
      repo.items = [_n(9, message: 'for B')];
      repo.failWith = ApiException('down', statusCode: 500);
      await state.load();
      expect(state.items, isEmpty, reason: 'dropped before the new load, and the load failed');
      repo.failWith = null;
      await state.load();
      expect(state.items.single.message, 'for B');
    });
  });

  group('NotificationsScreen', () {
    late _FakeRepo repo;
    late NotificationsState state;
    String? popped;

    setUp(() {
      repo = _FakeRepo()..items = [_n(1), _n(2, type: 'OTHER', read: true, ago: const Duration(days: 2), message: 'Something else')];
      state = NotificationsState(repository: repo);
      popped = null;
    });

    tearDown(() => state.dispose());

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async => popped = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => NotificationsScreen(now: () => _now))),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('lists them newest first with time, unread dot and a digest title', (tester) async {
      await open(tester);
      expect(find.byKey(const ValueKey('notifications-list')), findsOneWidget);
      expect(find.text('Weekly digest'), findsOneWidget);
      expect(find.text('Notification'), findsOneWidget);
      expect(find.text('3 h ago'), findsOneWidget);
      expect(find.text('2 days ago'), findsOneWidget);
      expect(find.byKey(const ValueKey('unread-dot-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('unread-dot-2')), findsNothing, reason: 'already read');
      expect(find.byKey(const ValueKey('notification-open-insights-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('notification-open-insights-2')), findsNothing, reason: 'only a digest points to Insights');
    });

    testWidgets('tapping one marks it read', (tester) async {
      await open(tester);
      await tester.tap(find.text('3 h ago'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['read 1']);
      expect(find.byKey(const ValueKey('unread-dot-1')), findsNothing);
    });

    testWidgets('"Mark all read" works and is off when nothing is unread', (tester) async {
      await open(tester);
      final button = find.byKey(const ValueKey('notifications-mark-all'));
      expect(tester.widget<TextButton>(button).onPressed, isNotNull);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(repo.calls, ['read-all']);
      expect(tester.widget<TextButton>(button).onPressed, isNull);
    });

    testWidgets('the bin deletes one', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('notification-delete-1')));
      await tester.pumpAndSettle();
      expect(repo.calls, ['remove 1']);
      expect(find.byKey(const ValueKey('notification-1')), findsNothing);
      expect(find.byKey(const ValueKey('notification-2')), findsOneWidget);
    });

    testWidgets('a refused delete comes back with the reason', (tester) async {
      await open(tester);
      repo.failWith = ApiException('This is not your notification.', statusCode: 403);
      await tester.tap(find.byKey(const ValueKey('notification-delete-1')));
      await tester.pumpAndSettle();
      expect(find.text('This is not your notification.'), findsOneWidget);
      expect(find.byKey(const ValueKey('notification-1')), findsOneWidget, reason: 'put back');
    });

    testWidgets('"Open Insights" marks it read and closes with the answer the dashboard acts on', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('notification-open-insights-1')));
      await tester.pumpAndSettle();
      expect(repo.calls, ['read 1']);
      expect(popped, 'insights');
      expect(find.byType(NotificationsScreen), findsNothing);
    });

    testWidgets('says so when there is nothing yet', (tester) async {
      repo.items = [];
      await open(tester);
      expect(find.byKey(const ValueKey('notifications-empty')), findsOneWidget);
      expect(tester.widget<TextButton>(find.byKey(const ValueKey('notifications-mark-all'))).onPressed, isNull);
    });

    testWidgets('an error offers to try again', (tester) async {
      repo.failWith = ApiException('Could not reach the server', statusCode: 500);
      await open(tester);
      expect(find.byKey(const ValueKey('notifications-error')), findsOneWidget);
      expect(find.text('Could not reach the server'), findsOneWidget);
      repo.failWith = null;
      await tester.tap(find.byKey(const ValueKey('notifications-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('notifications-error')), findsNothing);
      expect(find.byKey(const ValueKey('notifications-list')), findsOneWidget);
    });
  });

  group('NotificationBell', () {
    Future<NotificationsState> show(WidgetTester tester, int unread, {VoidCallback? onPressed}) async {
      final repo = _FakeRepo()..items = [for (var i = 0; i < unread; i++) _n(i + 1)];
      final state = NotificationsState(repository: repo);
      addTearDown(state.dispose);
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(home: Scaffold(body: NotificationBell(onPressed: onPressed ?? () {}))),
      ));
      await tester.pumpAndSettle();
      return state;
    }

    testWidgets('shows how many are unread, and nothing when none are', (tester) async {
      await show(tester, 0);
      expect(tester.widget<Badge>(find.byKey(const ValueKey('notification-badge'))).isLabelVisible, isFalse);
    });

    testWidgets('a count, and 9+ for many', (tester) async {
      await show(tester, 3);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('9+ for ten or more', (tester) async {
      await show(tester, 12);
      expect(find.text('9+'), findsOneWidget);
    });

    testWidgets('pressing it opens the screen', (tester) async {
      var pressed = 0;
      await show(tester, 1, onPressed: () => pressed++);
      await tester.tap(find.byKey(const ValueKey('notification-bell')));
      expect(pressed, 1);
    });
  });
}
