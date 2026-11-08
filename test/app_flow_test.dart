import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:tomatoo/main.dart';
import 'package:tomatoo/models/cart_state.dart';
import 'package:tomatoo/models/drop_state.dart';
import 'package:tomatoo/screens/admin_dashboard_screen.dart';
import 'package:tomatoo/screens/delivery_dashboard_screen.dart';
import 'package:tomatoo/screens/home_screen.dart';
import 'package:tomatoo/screens/restaurant_dashboard_screen.dart';
import 'package:tomatoo/services/api_client.dart';
import 'package:tomatoo/services/auth_service.dart';
import 'package:tomatoo/services/session_provider.dart';

/// The whole app, real screens and real providers ([appProviders]), with only the network replaced: Dio talks to this
/// in-memory backend, which answers from the JSON captured off a live backend (test/fixtures) and records every call.
class _Hold {
  final int id;
  String status = 'HELD'; // HELD | CONFIRMED | CANCELLED | EXPIRED, as on the server
  final DateTime expiresAt;
  int? orderId;
  _Hold(this.id, this.expiresAt);
}

class _Backend implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  String role = 'CUSTOMER';

  /// What GET /orders/{id} says while the app polls for the payment result.
  String polledPaymentStatus = 'PAID';

  /// For a drop order: the payment went through but the slot was lost meanwhile, so the order is CANCELLED and REFUNDED.
  bool polledRefunded = false;

  // ---- a one-drop server with its own clock. Nothing here reads the real time, so a test moves it with [advance].
  bool dropsEnabled = false;
  DateTime now = DateTime(2026, 11, 8, 12, 0, 0);
  final int totalSlots = 2;
  int reservedSlots = 0;
  final List<_Hold> holds = [];

  int get remainingSlots => totalSlots - reservedSlots;
  _Hold? get live => holds.where((h) => h.status == 'HELD').firstOrNull;

  /// Moves the server clock on and releases the holds that ran out, as the server's expiry job does.
  void advance(Duration d) {
    now = now.add(d);
    for (final h in holds) {
      if (h.status == 'HELD' && !h.expiresAt.isAfter(now)) {
        h.status = 'EXPIRED';
        reservedSlots--;
      }
    }
  }

  String _ts(DateTime d) => d.toIso8601String();

  Map<String, dynamic> _dropJson() => {
        ..._json('api_drop'),
        'startsAt': _ts(now.subtract(const Duration(minutes: 5))),
        'endsAt': _ts(now.add(const Duration(hours: 2))),
        'totalSlots': totalSlots,
        'remainingSlots': remainingSlots,
        'status': remainingSlots == 0 ? 'SOLD_OUT' : 'LIVE',
        'serverTime': _ts(now),
      };

  Map<String, dynamic> _holdJson(_Hold h) => {
        'reservationId': h.id,
        'dropId': 4,
        'status': h.status,
        'expiresAt': _ts(h.expiresAt),
        'orderId': h.orderId,
        'serverTime': _ts(now),
      };

  Map<String, dynamic> _json(String name) => jsonDecode(File('test/fixtures/$name.json').readAsStringSync()) as Map<String, dynamic>;

  bool called(String method, String path) => requests.any((r) => r.method == method && r.path == path);
  int count(String method, String path) => requests.where((r) => r.method == method && r.path == path).length;

  (int, Object?) _answer(RequestOptions o) {
    final key = '${o.method} ${o.path}';
    switch (key) {
      case 'POST /api/auth/demo-login':
        return (200, {'accessToken': 'token-$role', 'email': '${role.toLowerCase()}@cravey.com', 'name': 'Test $role', 'role': role, 'userId': 7});
      case 'GET /customer/profile':
        return (200, {'customerId': 7, 'name': 'Test CUSTOMER', 'email': 'customer@cravey.com', 'userId': 7});
      case 'GET /restaurants':
        return (200, [
          {'id': 1, 'name': 'Cravey Kitchen', 'address': '123 Cravey Way', 'rating': 4.6, 'open': true, 'deliveryTime': 25}
        ]);
      case 'GET /categories':
        return (200, [
          {'id': 1, 'name': 'Ramen'}
        ]);
      case 'GET /menu-items':
        return (200, [
          {'id': 11, 'name': 'Spicy Miso Ramen', 'description': 'Rich broth', 'price': 429, 'isVeg': false, 'category': {'id': 1, 'name': 'Ramen', 'restaurant': {'id': 1}}}
        ]);
      case 'GET /restaurants/1/menu':
        return (200, [
          {'categoryId': 1, 'categoryName': 'Ramen', 'items': [{'itemId': 11, 'name': 'Spicy Miso Ramen', 'description': 'Rich broth', 'price': 429, 'isVeg': false, 'isAvailable': true}]}
        ]);
      case 'GET /orders':
      case 'GET /coupon/active':
      case 'GET /search/trending':
        return (200, <dynamic>[]);
      case 'POST /cart':
        return (200, {'id': 5, 'customerId': 7, 'restaurantId': 1, 'totalAmount': 858});
      case 'POST /cart/add':
        return (200, {'id': 1, 'cartId': 5, 'itemId': 11, 'price': 429, 'quantity': 2});
      case 'POST /orders/checkout':
        if (o.queryParameters.containsKey('reservationId')) {
          final hold = holds.singleWhere((h) => h.id == o.queryParameters['reservationId']);
          hold.orderId = 1;
        }
        return (200, _json('api_order_pending'));
      case 'POST /payment/create':
        return (200, _json('api_payment_intent'));
      case 'GET /orders/1':
        if (polledRefunded) {
          for (final h in holds.where((h) => h.orderId == 1 && h.status == 'HELD')) {
            h.status = 'CANCELLED'; // the slot went to someone else; nothing is returned to stock
          }
          return (200, {..._json('api_order_refunded'), 'orderId': 1});
        }
        if (polledPaymentStatus == 'PAID') {
          for (final h in holds.where((h) => h.orderId == 1 && h.status == 'HELD')) {
            h.status = 'CONFIRMED';
          }
        }
        return (200, {..._json('api_order_paid'), 'paymentStatus': polledPaymentStatus});
      case 'GET /drops':
        return (200, dropsEnabled ? [_dropJson()] : <dynamic>[]);
      case 'GET /drops/waitlist/mine':
        return (200, <dynamic>[]);
      case 'GET /drops/reservations/mine':
        // the real query: CONFIRMED, or HELD and not yet expired
        return (200, [
          for (final h in holds)
            if (h.status == 'CONFIRMED' || (h.status == 'HELD' && h.expiresAt.isAfter(now))) _holdJson(h)
        ]);
      case 'POST /drops/4/reserve':
        final existing = live;
        if (existing != null) return (200, _holdJson(existing));
        if (remainingSlots == 0) return (409, _json('api_error_sold_out'));
        final hold = _Hold(holds.length + 1, now.add(const Duration(minutes: 10)));
        holds.add(hold);
        reservedSlots++;
        return (201, _holdJson(hold));
    }
    return (404, {'message': 'not mocked: $key'});
  }

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final (status, body) = _answer(options);
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

/// Lets screens load and animate. Not pumpAndSettle: a loading spinner somewhere on screen never settles.
Future<void> settle(WidgetTester tester, {int steps = 30}) async {
  for (var i = 0; i < steps; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Two things in a flutter_test run are not findings about the app, and nothing else is swallowed:
///  * google_fonts tries to fetch Nunito Sans, which a test cannot (it throws from an unawaited call);
///  * flutter_test draws every glyph as a full-width square, so a Row that fits in the real font reports an overflow here;
///  * restaurant and dish photos are network images, which a test cannot load.
bool _testEnvironmentNoise(Object error) {
  final text = '${error.runtimeType} $error';
  return text.contains('allowRuntimeFetching') ||
      text.contains('Failed to load font') ||
      text.contains('overflowed') ||
      text.contains('NetworkImageLoadException'); // photos cannot be fetched in a test
}

/// A widget test whose body runs in a zone that drops that noise.
void appTest(String description, Future<void> Function(WidgetTester tester) body) {
  testWidgets(description, (tester) async {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (_testEnvironmentNoise(details.exception)) return;
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);

    final finished = Completer<void>();
    runZonedGuarded(() async {
      try {
        await body(tester);
        finished.complete();
      } catch (e, st) {
        if (!finished.isCompleted) finished.completeError(e, st);
      }
    }, (error, stack) {
      if (_testEnvironmentNoise(error)) return;
      if (!finished.isCompleted) finished.completeError(error, stack);
    });
    await finished.future;
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Backend backend;
  late HttpClientAdapter dioBefore, rawBefore;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false; // never download fonts in a test
  });

  setUp(() {
    backend = _Backend();
    dioBefore = ApiClient.instance.dio.httpClientAdapter;
    rawBefore = ApiClient.instance.rawDio.httpClientAdapter;
    ApiClient.instance.dio.httpClientAdapter = backend;
    ApiClient.instance.rawDio.httpClientAdapter = backend;
    AuthService.instance.setTokensForTesting(accessToken: null, refreshToken: null);
  });

  tearDown(() {
    ApiClient.instance.dio.httpClientAdapter = dioBefore;
    ApiClient.instance.rawDio.httpClientAdapter = rawBefore;
    AuthService.instance.setTokensForTesting(accessToken: null, refreshToken: null);
  });

  /// Signs in through the app's own demo sign-in (so the session, the token and the role come from the code under test),
  /// mounts the real app tree and lets the splash screen send the user where their role belongs.
  Future<SessionProvider> openAppSignedInAs(WidgetTester tester, String role, {DateTime Function()? clock}) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    backend.role = role;
    final session = SessionProvider();
    await tester.runAsync(() => session.loginAsDemo(role));
    AuthService.instance.setTokensForTesting(accessToken: 'token-$role', refreshToken: 'refresh-$role');
    await tester.pumpWidget(MultiProvider(providers: appProviders(session, clock: clock), child: const MyApp()));
    await tester.pump(const Duration(milliseconds: 3000)); // splash timer
    await settle(tester);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox()); // dispose the tree so the order-tracking timer is cancelled
    });
    return session;
  }

  group('role isolation', () {
    appTest('a customer lands on the customer home and never touches owner, admin or delivery endpoints', (tester) async {
      await openAppSignedInAs(tester, 'CUSTOMER');
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(RestaurantDashboardScreen), findsNothing);
      expect(find.byType(AdminDashboardScreen), findsNothing);
      expect(find.byType(DeliveryDashboardScreen), findsNothing);
      final forbidden = backend.requests.where((r) => r.path.startsWith('/admin') || r.path.startsWith('/owner') || r.path.startsWith('/delivery'));
      expect(forbidden, isEmpty, reason: 'customer screens called ${forbidden.map((r) => r.path).toList()}');
    });

    for (final c in const [
      ('OWNER', RestaurantDashboardScreen),
      ('DELIVERY', DeliveryDashboardScreen),
      ('ADMIN', AdminDashboardScreen),
    ]) {
      appTest('${c.$1} lands on its own dashboard, not on the customer home', (tester) async {
        await openAppSignedInAs(tester, c.$1);
        expect(find.byType(c.$2), findsOneWidget);
        expect(find.byType(HomeScreen), findsNothing);
        expect(backend.called('POST', '/orders/checkout'), isFalse);
      });
    }

    test('every role maps to exactly one landing route and unknown roles fall back to the customer home', () {
      expect(SessionProvider.routeForRole('CUSTOMER'), '/home');
      expect(SessionProvider.routeForRole('OWNER'), '/restaurant-dashboard');
      expect(SessionProvider.routeForRole('DELIVERY'), '/delivery-dashboard');
      expect(SessionProvider.routeForRole('ADMIN'), '/admin-dashboard');
      expect(SessionProvider.routeForRole(null), '/home');
      expect(SessionProvider.routeForRole('SOMETHING_ELSE'), '/home');
    });
  });

  group('customer journey: browse, cart, checkout, pay', () {
    /// Home -> restaurant -> two Spicy Miso Ramen -> cart. Returns with the cart screen open.
    Future<void> fillCartWithTwoRamen(WidgetTester tester) async {
      await openAppSignedInAs(tester, 'CUSTOMER');
      expect(find.text('Cravey Kitchen'), findsWidgets, reason: 'the restaurant from GET /restaurants is listed');

      await tester.tap(find.text('Cravey Kitchen').first);
      await settle(tester);
      expect(find.text('Spicy Miso Ramen'), findsOneWidget, reason: 'the menu from GET /restaurants/1/menu is shown');

      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pump();
      final cart = tester.element(find.byType(Scaffold).first).read<CartState>();
      expect(cart.totalItemCount, 2);
      expect(cart.subtotal, 858);

      await tester.tap(find.text('Cart').last);
      await settle(tester);
      expect(find.text('Your Cart'), findsOneWidget);
    }

    Future<void> tapPlaceOrder(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Place Order'));
      await tester.pump();
      await tester.tap(find.text('Place Order'));
    }

    Future<void> proceedToCheckout(WidgetTester tester) async {
      await tester.tap(find.text('Proceed to Checkout'));
      await settle(tester);
      expect(find.text('Checkout'), findsWidgets);
      expect(find.text('Place Order'), findsOneWidget);
    }

    appTest('browse, add two dishes, check out and pay: one order, one payment intent, the cart is emptied, tracking opens', (tester) async {
      await fillCartWithTwoRamen(tester);
      await proceedToCheckout(tester);

      // the app synced the cart first, and the order is made from exactly that cart
      expect(backend.count('POST', '/cart'), 1);
      await tapPlaceOrder(tester);
      await settle(tester, steps: 60);

      final checkout = backend.requests.singleWhere((r) => r.method == 'POST' && r.path == '/orders/checkout');
      expect(checkout.queryParameters, {'restaurantId': 1, 'cartId': 5, 'customerId': 7});
      expect(backend.count('POST', '/payment/create'), 1);
      expect(backend.requests.firstWhere((r) => r.path == '/payment/create').queryParameters, {'orderId': 1});
      expect(backend.called('GET', '/orders/1'), isTrue, reason: 'the app asks the server whether the payment went through');

      expect(find.text('Payment Failed'), findsNothing);
      final cart = tester.element(find.byType(Scaffold).first).read<CartState>();
      expect(cart.items, isEmpty);
      expect(cart.lastCreatedOrder?.orderId, 1);
      expect(find.text('Place Order'), findsNothing, reason: 'left the checkout screen for order tracking');
    });

    appTest('a payment the server reports as FAILED shows the failure and keeps the customer on checkout', (tester) async {
      backend.polledPaymentStatus = 'FAILED';
      await fillCartWithTwoRamen(tester);
      await proceedToCheckout(tester);

      await tapPlaceOrder(tester);
      await settle(tester, steps: 60);

      expect(find.text('Payment Failed'), findsOneWidget);
      expect(find.text('Place Order'), findsOneWidget, reason: 'still on checkout');
      await tester.tap(find.text('OK'));
      await settle(tester, steps: 5);
      expect(find.text('Payment Failed'), findsNothing);
    });

    appTest('tapping Place Order twice quickly creates one order, not two', (tester) async {
      await fillCartWithTwoRamen(tester);
      await proceedToCheckout(tester);

      await tapPlaceOrder(tester);
      await tester.pump(); // the first tap is now in flight
      final again = find.textContaining('Placing Order');
      if (again.evaluate().isNotEmpty) await tester.tap(again.first, warnIfMissed: false);
      await tester.tap(find.byType(ElevatedButton).last, warnIfMissed: false);
      await settle(tester, steps: 60);

      expect(backend.count('POST', '/orders/checkout'), 1);
      expect(backend.count('POST', '/payment/create'), 1);
    });
  });

  group('drop flow: reserve, hold countdown, expiry, refund, restart', () {
    setUp(() => backend.dropsEnabled = true);

    /// A phone whose clock is off from the server's by [skew]. It still ticks in step with the server, which is all a clock does.
    DateTime Function() phoneClock(Duration skew) => () => backend.now.add(skew);

    /// Lets [total] of server time pass in small steps, so the countdown, the poll timer and the expiry job all get their turn.
    Future<void> elapse(WidgetTester tester, Duration total, {Duration step = const Duration(seconds: 2)}) async {
      var left = total;
      while (left > Duration.zero) {
        final d = left < step ? left : step;
        backend.advance(d);
        await tester.pump(d);
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
        left -= d;
      }
    }

    DropState dropState(WidgetTester tester) => tester.element(find.byType(Scaffold).first).read<DropState>();

    /// What the hold banner's countdown currently says.
    String countdown(WidgetTester tester, {int reservationId = 1}) => tester
        .widget<Text>(find.descendant(of: find.byKey(ValueKey('hold-countdown-$reservationId')), matching: find.byType(Text)))
        .data!;

    /// Home -> the drop -> Reserve a slot. Ends on the drop checkout screen, with the hold ticking.
    Future<void> reserveTheDrop(WidgetTester tester, {Duration skew = Duration.zero}) async {
      await openAppSignedInAs(tester, 'CUSTOMER', clock: phoneClock(skew));
      await tester.ensureVisible(find.text('E2E Wagyu Drop'));
      await tester.pump();
      await tester.tap(find.text('E2E Wagyu Drop'));
      await settle(tester);
      expect(find.text('2 of 2 slots left'), findsOneWidget);
      await tester.tap(find.text('Reserve a slot'));
      await settle(tester);
      expect(find.text('Drop checkout'), findsOneWidget, reason: 'a successful reserve opens checkout');
      expect(backend.count('POST', '/drops/4/reserve'), 1);
    }

    for (final skew in const [Duration(hours: 2), Duration(hours: -3)]) {
      appTest('the hold counts down on the server clock and expires on it, with the phone ${skew.isNegative ? 'behind' : 'ahead'} by ${skew.inHours.abs()}h', (tester) async {
        await reserveTheDrop(tester, skew: skew);

        // whatever the phone thinks, ten minutes were granted and ten minutes are shown
        expect(countdown(tester), '10:00');
        expect(dropState(tester).dropById(4)!.remainingSlots, 1, reason: 'the held slot is out of stock');

        await elapse(tester, const Duration(minutes: 3, seconds: 30));
        expect(countdown(tester), '06:30');
        expect(find.text('Pay ₹24.50'), findsOneWidget);

        await elapse(tester, const Duration(minutes: 6, seconds: 26));
        expect(countdown(tester), '00:04');
        expect(find.text('Pay ₹24.50'), findsOneWidget, reason: 'four seconds of hold are still a hold');

        await elapse(tester, const Duration(seconds: 4));
        await settle(tester, steps: 5);
        expect(find.text('This hold has expired'), findsOneWidget, reason: 'the hold ran out on the server');
        expect(find.text('Pay ₹24.50'), findsNothing);
        expect(backend.holds.single.status, 'EXPIRED');

        // and the slot is back for the next person
        await tester.tap(find.text('Back to drop'));
        await settle(tester);
        expect(find.text('2 of 2 slots left'), findsOneWidget, reason: 'stock went back up');
        expect(find.text('Reserve a slot'), findsOneWidget);
        expect(find.byKey(const ValueKey('hold-banner')), findsNothing);
        expect(dropState(tester).dropById(4)!.remainingSlots, 2);
      });
    }

    appTest('paid, but the slot was lost meanwhile: the order is CANCELLED and REFUNDED and the customer is told so', (tester) async {
      await reserveTheDrop(tester);
      backend.polledRefunded = true;

      await tester.ensureVisible(find.text('Pay ₹24.50'));
      await tester.pump();
      await tester.tap(find.text('Pay ₹24.50'));
      await settle(tester, steps: 60);

      expect(backend.count('POST', '/orders/checkout'), 1);
      expect(backend.requests.firstWhere((r) => r.path == '/orders/checkout').queryParameters, {'reservationId': 1});
      expect(backend.count('POST', '/payment/create'), 1);
      expect(find.text('Payment not completed'), findsOneWidget);
      expect(find.text('Sorry, this drop sold out before your payment completed. Your payment will be refunded automatically.'), findsOneWidget);
      expect(find.text('Payment successful! Your slot is secured.'), findsNothing, reason: 'a refunded order is never shown as a success');

      await tester.tap(find.text('OK'));
      await settle(tester, steps: 5);
      expect(find.text('Payment not completed'), findsNothing);
      expect(find.text('Place Order'), findsNothing);
      expect(backend.holds.single.status, 'CANCELLED');
      expect(find.text('Sold out, payment refunded'), findsOneWidget);
      expect(find.text('This drop sold out before your payment completed. Your payment is being refunded to your original payment method.'), findsOneWidget);
      expect(find.text('This hold has expired'), findsNothing, reason: 'a refunded customer was not late, the drop sold out');
    });

    appTest('killing the app mid-hold and opening it again restores the hold, with the time that is really left', (tester) async {
      await reserveTheDrop(tester, skew: const Duration(hours: 2));
      await elapse(tester, const Duration(minutes: 3));
      expect(countdown(tester), '07:00');

      // the app is killed: nothing of the old DropState survives
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      final before = backend.requests.length;

      // a cold start, on a phone whose clock is now somewhere else entirely
      await openAppSignedInAs(tester, 'CUSTOMER', clock: phoneClock(const Duration(minutes: -45)));
      final afterRestart = backend.requests.skip(before);
      expect(afterRestart.any((r) => r.method == 'GET' && r.path == '/drops/reservations/mine'), isTrue, reason: 'the hold comes from the server');
      expect(afterRestart.any((r) => r.method == 'POST' && r.path == '/drops/4/reserve'), isFalse, reason: 'it was restored, not taken again');
      expect(backend.holds, hasLength(1));

      expect(find.byKey(const ValueKey('hold-banner')), findsOneWidget);
      expect(countdown(tester), '07:00');
      expect(dropState(tester).activeHold?.reservationId, 1);

      // and the restored hold is still payable
      await elapse(tester, const Duration(minutes: 1));
      expect(countdown(tester), '06:00');
      await tester.ensureVisible(find.text('Checkout'));
      await tester.pump();
      await tester.tap(find.text('Checkout'));
      await settle(tester);
      expect(find.text('Drop checkout'), findsOneWidget);
      expect(find.text('Pay ₹24.50'), findsOneWidget);
    });
  });
}
