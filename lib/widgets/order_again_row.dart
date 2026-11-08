import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cart_state.dart';
import '../models/dish_search_state.dart';
import '../models/food_item.dart';
import '../models/order_again_state.dart';
import '../theme/app_theme.dart';

FoodItem foodItemFromReorder(ReorderDish d) => FoodItem(
      id: 'api_${d.itemId}',
      name: d.name,
      description: '',
      price: d.price,
      imageUrl: d.imageUrl ?? '',
      category: '',
      rating: 4.5,
      backendItemId: d.itemId,
    );

/// The same cart identity the home screen and search results give a restaurant, so a reordered dish is the same cart line as when added from its menu.
Restaurant restaurantFromReorder(ReorderDish d) => Restaurant(
      id: 'api_${d.restaurantId}',
      name: d.restaurantName,
      imageUrl: '',
      rating: 4.5,
      deliveryTime: '30 min',
      deliveryFee: 29.0,
      cuisineTags: const [],
      menu: const [],
      backendId: d.restaurantId,
    );

/// "Order again": the dishes this customer ordered most recently, one tap each. Hidden while searching, and when there is nothing to show.
class OrderAgainRow extends StatelessWidget {
  const OrderAgainRow({super.key});

  @override
  Widget build(BuildContext context) {
    final searching = context.watch<DishSearchState>().active;
    final dishes = context.watch<OrderAgainState>().dishes;
    if (searching || dishes.isEmpty) return const SizedBox.shrink();

    return Padding(
      key: const ValueKey('order-again'),
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Order again', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
          const SizedBox(height: 10),
          SizedBox(
            height: 196,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: dishes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _ReorderCard(dish: dishes[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReorderCard extends StatelessWidget {
  final ReorderDish dish;
  const _ReorderCard({required this.dish});

  @override
  Widget build(BuildContext context) {
    final item = foodItemFromReorder(dish);
    final cart = context.watch<CartState>();
    final qty = cart.getItemQuantity(item);
    return Container(
      key: ValueKey('reorder-${dish.itemId}'),
      width: 148,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 78,
            width: double.infinity,
            child: (dish.imageUrl == null || dish.imageUrl!.isEmpty)
                ? _placeholder()
                : Image.network(dish.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder()),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dish.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
                Text(dish.restaurantName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppTheme.textLight)),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: SizedBox(
              width: double.infinity,
              height: 32,
              child: ElevatedButton(
                key: ValueKey('reorder-add-${dish.itemId}'),
                style: ElevatedButton.styleFrom(padding: EdgeInsets.zero, textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                onPressed: () => _add(context, cart),
                child: Text(qty == 0 ? 'Reorder  ·  ₹${dish.price.toStringAsFixed(0)}' : 'In cart · $qty'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(color: AppTheme.primaryLight.withValues(alpha: 0.5), child: const Center(child: Icon(Icons.restaurant_rounded, color: AppTheme.primaryColor, size: 28)));

  void _add(BuildContext context, CartState cart) {
    final restaurant = restaurantFromReorder(dish);
    final startsNewCart = cart.items.isNotEmpty && cart.activeRestaurant != null && cart.activeRestaurant!.id != restaurant.id;
    cart.addItem(foodItemFromReorder(dish), restaurant);
    if (startsNewCart) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Started a new cart with ${restaurant.name}. A cart holds one restaurant at a time.')));
    }
  }
}
