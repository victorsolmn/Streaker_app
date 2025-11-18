import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/marketplace_provider.dart';
import '../../models/product_model.dart';
import '../../utils/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  // Undo state
  CartItem? _lastRemovedItem;
  Timer? _undoTimer;
  final int _undoTimeoutSeconds = 5;

  @override
  void dispose() {
    _undoTimer?.cancel();
    super.dispose();
  }

  void _handleRemoveItem(CartItem item) {
    final provider = Provider.of<MarketplaceProvider>(context, listen: false);

    // Cancel any existing undo timer
    _undoTimer?.cancel();

    // Store the removed item
    setState(() {
      _lastRemovedItem = item;
    });

    // Remove the item from cart
    provider.removeFromCart(item.id);

    // Show undo snackbar
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.product?.name ?? 'Item'} removed from cart'),
        duration: Duration(seconds: _undoTimeoutSeconds),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'UNDO',
          textColor: AppTheme.primaryAccent,
          onPressed: () {
            _undoRemoval();
          },
        ),
      ),
    );

    // Start timer to clear undo data after timeout
    _undoTimer = Timer(Duration(seconds: _undoTimeoutSeconds), () {
      setState(() {
        _lastRemovedItem = null;
      });
    });
  }

  void _undoRemoval() {
    if (_lastRemovedItem == null) return;

    // Cancel the undo timer
    _undoTimer?.cancel();

    final provider = Provider.of<MarketplaceProvider>(context, listen: false);

    // Re-add the item to cart
    provider.addToCart(
      _lastRemovedItem!.productId,
      quantity: _lastRemovedItem!.quantity,
    );

    // Clear the undo state
    setState(() {
      _lastRemovedItem = null;
    });

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_lastRemovedItem!.product?.name ?? 'Item'} restored to cart'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.successGreen,
      ),
    );
  }

  Future<void> _sendWhatsAppOrder(BuildContext context, List<CartItem> cartItems, double total) async {
    final provider = Provider.of<MarketplaceProvider>(context, listen: false);

    // Build order message
    StringBuffer message = StringBuffer();
    message.writeln('Hi! I want to order the following items:\n');

    for (var item in cartItems) {
      if (item.product != null) {
        final price = provider.isPremiumMember
            ? item.product!.premiumPrice
            : item.product!.regularPrice;
        message.writeln('${item.quantity}x ${item.product!.brand} - ${item.product!.name}');
        message.writeln('Price: ₹${price.toStringAsFixed(0)} each');
        if (item.product!.flavor != null) {
          message.writeln('Flavor: ${item.product!.flavor}');
        }
        message.writeln('');
      }
    }

    message.writeln('Total Amount: ₹${total.toStringAsFixed(0)}');
    if (provider.isPremiumMember && provider.cartSavings > 0) {
      message.writeln('Premium Savings: ₹${provider.cartSavings.toStringAsFixed(0)}');
    }
    message.writeln('\nPlease confirm availability and delivery details.');

    final encodedMessage = Uri.encodeComponent(message.toString());
    const whatsappNumber = '919876543210'; // Replace with actual number
    final whatsappUrl = 'https://wa.me/$whatsappNumber?text=$encodedMessage';

    final uri = Uri.parse(whatsappUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackground : Colors.white,
      appBar: AppBar(
        title: const Text('Shopping Cart'),
        backgroundColor: isDarkMode ? AppTheme.darkCardBackground : Colors.white,
        elevation: 0,
      ),
      body: Consumer<MarketplaceProvider>(
        builder: (context, provider, _) {
          if (provider.cartItems.isEmpty) {
            return _buildEmptyCart(isDarkMode);
          }

          return Column(
            children: [
              // Cart Items List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.cartItems.length,
                  itemBuilder: (context, index) {
                    final cartItem = provider.cartItems[index];
                    return _buildCartItem(
                      context,
                      cartItem,
                      provider.isPremiumMember,
                      isDarkMode,
                    );
                  },
                ),
              ),

              // Order Summary Card
              _buildOrderSummary(
                context,
                provider,
                isDarkMode,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyCart(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 100,
            color: AppTheme.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add items to get started',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(
    BuildContext context,
    CartItem cartItem,
    bool isPremium,
    bool isDarkMode,
  ) {
    if (cartItem.product == null) return const SizedBox.shrink();

    final product = cartItem.product!;
    final price = isPremium ? product.premiumPrice : product.regularPrice;
    final itemTotal = price * cartItem.quantity;
    const int maxQuantity = 10; // P0 Fix #4: Max quantity limit

    return Dismissible(
      key: Key(cartItem.id),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        _handleRemoveItem(cartItem);
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.errorRed,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
          size: 28,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDarkMode ? AppTheme.darkCardBackground : AppTheme.cardBackgroundLight,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Product Image
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: AppTheme.cardBackgroundLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  Icons.fitness_center,
                  size: 30,
                  color: AppTheme.primaryAccent.withOpacity(0.5),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Product Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Remove button
                      IconButton(
                        onPressed: () => _handleRemoveItem(cartItem),
                        icon: const Icon(Icons.delete_outline),
                        color: AppTheme.errorRed,
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.brand,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${price.toStringAsFixed(0)} each',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryAccent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Quantity Controls
            Column(
              children: [
                // Quantity Selector
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppTheme.primaryAccent.withOpacity(0.3),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Decrease button
                      GestureDetector(
                        onTap: cartItem.quantity > 1 ? () {
                          final provider = Provider.of<MarketplaceProvider>(
                            context,
                            listen: false,
                          );
                          provider.updateCartQuantity(
                            cartItem.id,
                            cartItem.quantity - 1,
                          );
                        } : null,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.remove,
                            size: 16,
                            color: cartItem.quantity > 1
                              ? (isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary)
                              : AppTheme.textSecondary.withOpacity(0.5),
                          ),
                        ),
                      ),
                      // Quantity
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '${cartItem.quantity}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      // Increase button - P0 Fix #4: Enforce max quantity
                      GestureDetector(
                        onTap: cartItem.quantity < maxQuantity ? () {
                          final provider = Provider.of<MarketplaceProvider>(
                            context,
                            listen: false,
                          );
                          provider.updateCartQuantity(
                            cartItem.id,
                            cartItem.quantity + 1,
                          );
                        } : () {
                          // Show snackbar when limit reached
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Maximum quantity is $maxQuantity'),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.add,
                            size: 16,
                            color: cartItem.quantity < maxQuantity
                              ? AppTheme.primaryAccent
                              : AppTheme.textSecondary.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Item Total
                Text(
                  '₹${itemTotal.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary(
    BuildContext context,
    MarketplaceProvider provider,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkCardBackground : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Order Summary Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                  ),
                ),
                Text(
                  '${provider.cartItemCount} items',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Premium Savings (if applicable)
            if (provider.isPremiumMember && provider.cartSavings > 0)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.successGreen.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified,
                      color: AppTheme.successGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Premium Member Savings',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.successGreen,
                        ),
                      ),
                    ),
                    Text(
                      '₹${provider.cartSavings.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.successGreen,
                      ),
                    ),
                  ],
                ),
              ),

            // Total Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Amount',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                  ),
                ),
                Text(
                  '₹${provider.cartTotal.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // WhatsApp Order Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  _sendWhatsAppOrder(
                    context,
                    provider.cartItems,
                    provider.cartTotal,
                  );
                },
                icon: const Icon(Icons.chat, size: 20),
                label: const Text(
                  'Order via WhatsApp',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366), // WhatsApp green
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Clear Cart Button
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear Cart'),
                    content: const Text('Are you sure you want to remove all items?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          'Clear',
                          style: TextStyle(color: AppTheme.errorRed),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirm == true && context.mounted) {
                  await provider.clearCart();
                  Navigator.pop(context);
                }
              },
              child: const Text(
                'Clear Cart',
                style: TextStyle(
                  color: AppTheme.errorRed,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
