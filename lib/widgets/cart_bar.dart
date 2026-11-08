import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cart_state.dart';

/// A bar above the bottom navigation that appears once the cart has something in it, so checkout is one tap away from anywhere on the home screen.
class CartBar extends StatelessWidget {
  final VoidCallback onOpen;
  const CartBar({super.key, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartState>();
    final count = cart.totalItemCount;
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      key: const ValueKey('cart-bar'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Material(
        color: const Color(0xFF1F1A17),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Text('$count ${count == 1 ? 'item' : 'items'} · ₹${cart.subtotal.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600)),
                const Spacer(),
                const Text('View cart', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
