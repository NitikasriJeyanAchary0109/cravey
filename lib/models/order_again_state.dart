import 'package:flutter/foundation.dart';
import '../repositories/order_repository.dart';
import 'models.dart';

/// A dish the customer has ordered before, with what the cart needs to order it again.
class ReorderDish {
  final int itemId;
  final String name;
  final double price;
  final String? imageUrl;
  final int restaurantId;
  final String restaurantName;

  const ReorderDish({required this.itemId, required this.name, required this.price, this.imageUrl, required this.restaurantId, required this.restaurantName});
}

/// "Order again": the dishes this customer ordered most recently, newest first, each once. A cancelled order does not count, and neither does a dish the
/// order did not record an id for. A failure just leaves the row empty, because it is a shortcut and never the only way to order.
class OrderAgainState extends ChangeNotifier {
  OrderAgainState({required OrderRepository repository, required bool Function() isLoggedIn, this.max = 8})
      : _repo = repository,
        _isLoggedIn = isLoggedIn;

  final OrderRepository _repo;
  final bool Function() _isLoggedIn;
  final int max;

  List<ReorderDish> _dishes = const [];
  bool _loading = false;
  bool _disposed = false;

  List<ReorderDish> get dishes => _dishes;
  bool get loading => _loading;

  Future<void> load() async {
    if (_loading) return;
    if (!_isLoggedIn()) {
      _set(const []);
      return;
    }
    _loading = true;
    _notify();
    try {
      _set(pick(await _repo.getMyOrders(), max));
    } catch (_) {
      _set(const []);
    } finally {
      _loading = false;
      _notify();
    }
  }

  /// Forgets everything, for sign-out.
  void clear() => _set(const []);

  void _set(List<ReorderDish> d) {
    _dishes = d;
    _notify();
  }

  /// The most recent distinct dishes of these orders, newest order first.
  static List<ReorderDish> pick(List<OrderResponseDTO> orders, int max) {
    final sorted = [...orders]..sort((a, b) {
        final ta = DateTime.tryParse(a.orderDate ?? '');
        final tb = DateTime.tryParse(b.orderDate ?? '');
        if (ta != null && tb != null) return tb.compareTo(ta);
        return (b.orderId ?? 0).compareTo(a.orderId ?? 0);
      });
    final seen = <int>{};
    final out = <ReorderDish>[];
    for (final o in sorted) {
      if ((o.status ?? '').toUpperCase() == 'CANCELLED' || o.restaurantId == null) continue;
      for (final i in o.items) {
        final id = i.itemId;
        if (id == null || i.name == null || i.name!.isEmpty || !seen.add(id)) continue;
        out.add(ReorderDish(
          itemId: id,
          name: i.name!,
          price: i.price ?? 0,
          imageUrl: i.imageUrl,
          restaurantId: o.restaurantId!,
          restaurantName: o.restaurantName ?? 'Restaurant',
        ));
        if (out.length >= max) return out;
      }
    }
    return out;
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
