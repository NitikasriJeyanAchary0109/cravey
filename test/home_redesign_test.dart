import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tomatoo/models/cart_state.dart';
import 'package:tomatoo/models/dish_search_state.dart';
import 'package:tomatoo/models/models.dart';
import 'package:tomatoo/models/order_again_state.dart';
import 'package:tomatoo/repositories/order_repository.dart';
import 'package:tomatoo/theme/app_theme.dart';
import 'package:tomatoo/widgets/cart_bar.dart';
import 'package:tomatoo/widgets/home_header.dart';
import 'package:tomatoo/widgets/order_again_row.dart';

import 'fakes/fake_dish_search.dart';

class _Orders implements OrderRepository {
  List<OrderResponseDTO> orders = [];
  Object? failWith;
  int calls = 0;

  @override
  Future<List<OrderResponseDTO>> getMyOrders() async {
    calls++;
    if (failWith != null) throw failWith!;
    return orders;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

OrderResponseDTO _order(int id, String date, List<(int, String, double)> items, {int restaurant = 7, String restaurantName = 'Casa Fuego', String status = 'DELIVERED'}) => OrderResponseDTO(
      orderId: id,
      totalAmount: 0,
      status: status,
      orderDate: date,
      restaurantId: restaurant,
      restaurantName: restaurantName,
      items: [for (final i in items) OrderItemDTO(itemId: i.$1, name: i.$2, price: i.$3, quantity: 1)],
    );

void main() {
  group('greetingFor', () {
    test('by the hour, with the first name only', () {
      expect(greetingFor(DateTime(2026, 11, 7, 8), 'Nitika Sri'), 'Good morning, Nitika');
      expect(greetingFor(DateTime(2026, 11, 7, 13), 'Nitika'), 'Good afternoon, Nitika');
      expect(greetingFor(DateTime(2026, 11, 7, 21), '  Nitika  Sri '), 'Good evening, Nitika');
      expect(greetingFor(DateTime(2026, 11, 7, 21), null), 'Good evening');
      expect(greetingFor(DateTime(2026, 11, 7, 21), '  '), 'Good evening');
    });
  });

  group('OrderAgainState.pick', () {
    test('newest order first, each dish once, cancelled orders ignored', () {
      final orders = [
        _order(1, '2026-10-01T12:00:00', [(1, 'Margherita', 300), (2, 'Tiramisu', 180)], restaurant: 3, restaurantName: 'Bella Napoli'),
        _order(3, '2026-10-20T12:00:00', [(5, 'Birria tacos', 250), (1, 'Margherita', 300)]),
        _order(2, '2026-10-10T12:00:00', [(9, 'Cancelled thing', 99)], status: 'CANCELLED'),
      ];
      final out = OrderAgainState.pick(orders, 8);
      expect(out.map((d) => d.name), ['Birria tacos', 'Margherita', 'Tiramisu']);
      expect(out[1].restaurantId, 7, reason: 'the most recent order of the dish decides the restaurant');
      expect(out.any((d) => d.name == 'Cancelled thing'), isFalse);
    });

    test('caps the list, and skips dishes with no id or name and orders with no restaurant', () {
      final many = _order(1, '2026-10-01T12:00:00', [for (var i = 1; i <= 12; i++) (i, 'Dish $i', 100)]);
      expect(OrderAgainState.pick([many], 8), hasLength(8));
      final odd = OrderResponseDTO(orderId: 2, totalAmount: 0, status: 'DELIVERED', restaurantId: 7, items: [OrderItemDTO(itemId: null, name: 'No id'), OrderItemDTO(itemId: 4, name: '')]);
      expect(OrderAgainState.pick([odd], 8), isEmpty);
      expect(OrderAgainState.pick([OrderResponseDTO(totalAmount: 0, items: [OrderItemDTO(itemId: 1, name: 'x')])], 8), isEmpty);
    });

    test('with no usable dates the higher order id counts as newer', () {
      final out = OrderAgainState.pick([_order(1, 'nope', [(1, 'Old', 1)]), _order(2, 'nope', [(2, 'New', 1)])], 8);
      expect(out.map((d) => d.name), ['New', 'Old']);
    });
  });

  group('OrderAgainState', () {
    test('loads for a signed-in customer, and stays empty for a visitor or on failure', () async {
      final repo = _Orders()..orders = [_order(1, '2026-10-01T12:00:00', [(1, 'Margherita', 300)])];
      var signedIn = true;
      final state = OrderAgainState(repository: repo, isLoggedIn: () => signedIn);
      addTearDown(state.dispose);
      await state.load();
      expect(state.dishes, hasLength(1));
      signedIn = false;
      await state.load();
      expect(state.dishes, isEmpty, reason: 'a visitor has no past orders');
      expect(repo.calls, 1, reason: 'and nothing is asked of the server');
      signedIn = true;
      repo.failWith = Exception('down');
      await state.load();
      expect(state.dishes, isEmpty);
    });
  });

  group('OrderAgainRow and CartBar', () {
    late _Orders repo;
    late OrderAgainState again;
    late CartState cart;

    setUp(() {
      repo = _Orders()..orders = [_order(1, '2026-10-01T12:00:00', [(1, 'Margherita', 300), (5, 'Birria tacos', 250)], restaurant: 7)];
      again = OrderAgainState(repository: repo, isLoggedIn: () => true);
      cart = CartState();
    });

    tearDown(() {
      again.dispose();
      cart.dispose();
    });

    Future<DishSearchState> show(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final search = DishSearchState(repository: FakeDishSearchRepository());
      addTearDown(search.dispose);
      await again.load();
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: again),
          ChangeNotifierProvider.value(value: cart),
          ChangeNotifierProvider.value(value: search),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ListView(children: const [OrderAgainRow()]),
            bottomNavigationBar: Builder(builder: (context) => CartBar(onOpen: () {})),
          ),
        ),
      ));
      await tester.pump();
      return search;
    }

    testWidgets('lists past dishes with one-tap reorder and shows the price', (tester) async {
      await show(tester);
      expect(find.text('Order again'), findsOneWidget);
      expect(find.byKey(const ValueKey('reorder-1')), findsOneWidget);
      expect(find.text('Reorder  ·  ₹300'), findsOneWidget);
      expect(find.byKey(const ValueKey('cart-bar')), findsNothing, reason: 'nothing in the cart yet');
    });

    testWidgets('tapping Reorder puts the dish in the cart and the cart bar appears', (tester) async {
      await show(tester);
      await tester.tap(find.byKey(const ValueKey('reorder-add-1')));
      await tester.pump();
      expect(cart.totalItemCount, 1);
      expect(find.text('In cart · 1'), findsOneWidget);
      expect(find.byKey(const ValueKey('cart-bar')), findsOneWidget);
      expect(find.text('1 item · ₹300'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reorder-add-1')));
      await tester.pump();
      expect(find.text('2 items · ₹600'), findsOneWidget);
    });

    testWidgets('hidden while the customer is searching', (tester) async {
      final search = await show(tester);
      search.onQueryChanged('pizza');
      await tester.pump();
      expect(find.byKey(const ValueKey('order-again')), findsNothing);
      await tester.pump(const Duration(seconds: 1)); // lets the search's debounce timer finish
    });

    testWidgets('a customer with no past orders sees no row at all', (tester) async {
      repo.orders = [];
      await show(tester);
      expect(find.byKey(const ValueKey('order-again')), findsNothing);
    });
  });

  group('the palette meets the contrast floor', () {
    double lum(Color c) {
      double f(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
      return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
    }

    double ratio(Color a, Color b) {
      final la = lum(a), lb = lum(b);
      return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
    }

    test('text and buttons are readable (WCAG AA, 4.5:1)', () {
      expect(ratio(Colors.white, AppTheme.primaryColor), greaterThanOrEqualTo(4.5), reason: 'button label');
      expect(ratio(AppTheme.textDark, AppTheme.scaffoldBackground), greaterThanOrEqualTo(7));
      expect(ratio(AppTheme.textLight, AppTheme.scaffoldBackground), greaterThanOrEqualTo(4.5), reason: 'secondary text');
      expect(ratio(AppTheme.textLightest, AppTheme.scaffoldBackground), greaterThanOrEqualTo(4.5), reason: 'hints');
      expect(ratio(AppTheme.primaryColor, AppTheme.scaffoldBackground), greaterThanOrEqualTo(4.5), reason: 'links');
      expect(ratio(AppTheme.freshGreen, Colors.white), greaterThanOrEqualTo(4.5), reason: 'vegetarian label');
    });
  });
}
