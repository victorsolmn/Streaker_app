import 'package:flutter/foundation.dart';
import '../models/product_model.dart';
import '../models/premium_membership_model.dart';
import '../services/supabase_service.dart';

class MarketplaceProvider with ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();

  // State
  List<ProductCategory> _categories = [];
  List<Product> _products = [];
  List<Product> _featuredProducts = [];
  List<CartItem> _cartItems = [];
  PremiumMembership? _activeMembership;
  String? _selectedCategoryId;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<ProductCategory> get categories => _categories;
  List<Product> get products => _products;
  List<Product> get featuredProducts => _featuredProducts;
  List<CartItem> get cartItems => _cartItems;
  PremiumMembership? get activeMembership => _activeMembership;
  String? get selectedCategoryId => _selectedCategoryId;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isPremiumMember => _activeMembership?.isActive ?? false;
  int get discountPercentage => _activeMembership?.discountPercentage ?? 0;

  // Cart summary
  int get cartItemCount => _cartItems.fold(0, (sum, item) => sum + item.quantity);

  double get cartTotal {
    double total = 0;
    for (var item in _cartItems) {
      if (item.product != null) {
        final price = isPremiumMember
            ? item.product!.premiumPrice
            : item.product!.regularPrice;
        total += price * item.quantity;
      }
    }
    return total;
  }

  double get cartSavings {
    if (!isPremiumMember) return 0;
    double savings = 0;
    for (var item in _cartItems) {
      if (item.product != null) {
        savings += (item.product!.regularPrice - item.product!.premiumPrice) * item.quantity;
      }
    }
    return savings;
  }

  // Filtered products by category
  List<Product> get filteredProducts {
    if (_selectedCategoryId == null) return _products;
    return _products.where((p) => p.categoryId == _selectedCategoryId).toList();
  }

  /// Initialize marketplace data
  Future<void> initialize() async {
    await Future.wait([
      fetchCategories(),
      fetchProducts(),
      fetchPremiumMembership(),
      fetchCart(),
    ]);
  }

  /// Fetch product categories
  Future<void> fetchCategories() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _supabaseService.client
          .from('product_categories')
          .select()
          .eq('is_active', true)
          .order('display_order');

      _categories = (response as List)
          .map((json) => ProductCategory.fromJson(json))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load categories: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint('Error fetching categories: $e');
    }
  }

  /// Fetch all products
  Future<void> fetchProducts() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _supabaseService.client
          .from('products')
          .select()
          .eq('is_active', true)
          .order('name');

      _products = (response as List)
          .map((json) => Product.fromJson(json))
          .toList();

      // Get featured products
      _featuredProducts = _products.where((p) => p.isFeatured).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load products: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint('Error fetching products: $e');
    }
  }

  /// Fetch user's premium membership
  Future<void> fetchPremiumMembership() async {
    try {
      final userId = _supabaseService.currentUser?.id;
      if (userId == null) return;

      final response = await _supabaseService.client
          .from('premium_memberships')
          .select()
          .eq('user_id', userId)
          .eq('status', 'active')
          .maybeSingle();

      if (response != null) {
        _activeMembership = PremiumMembership.fromJson(response);

        // Check if membership is expired
        if (_activeMembership!.isExpired) {
          _activeMembership = null;
        }
      } else {
        _activeMembership = null;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching premium membership: $e');
    }
  }

  /// Fetch user's cart
  Future<void> fetchCart() async {
    try {
      final userId = _supabaseService.currentUser?.id;
      if (userId == null) return;

      final response = await _supabaseService.client
          .from('shopping_cart')
          .select('*, products(*)')
          .eq('user_id', userId);

      _cartItems = (response as List)
          .map((json) => CartItem.fromJson(json))
          .toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching cart: $e');
    }
  }

  /// Add item to cart
  Future<bool> addToCart(String productId, {int quantity = 1}) async {
    try {
      final userId = _supabaseService.currentUser?.id;
      if (userId == null) {
        _error = 'Please login to add items to cart';
        notifyListeners();
        return false;
      }

      // Check if item already in cart
      final existingItem = _cartItems.firstWhere(
        (item) => item.productId == productId,
        orElse: () => CartItem(
          id: '',
          userId: userId,
          productId: productId,
          quantity: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      if (existingItem.id.isNotEmpty) {
        // Update quantity
        return await updateCartQuantity(existingItem.id, existingItem.quantity + quantity);
      } else {
        // Insert new item
        await _supabaseService.client.from('shopping_cart').insert({
          'user_id': userId,
          'product_id': productId,
          'quantity': quantity,
        });

        await fetchCart();
        return true;
      }
    } catch (e) {
      _error = 'Failed to add item to cart: $e';
      notifyListeners();
      debugPrint('Error adding to cart: $e');
      return false;
    }
  }

  /// Update cart item quantity
  Future<bool> updateCartQuantity(String cartItemId, int quantity) async {
    try {
      if (quantity <= 0) {
        return await removeFromCart(cartItemId);
      }

      await _supabaseService.client
          .from('shopping_cart')
          .update({'quantity': quantity})
          .eq('id', cartItemId);

      await fetchCart();
      return true;
    } catch (e) {
      _error = 'Failed to update quantity: $e';
      notifyListeners();
      debugPrint('Error updating cart quantity: $e');
      return false;
    }
  }

  /// Remove item from cart
  Future<bool> removeFromCart(String cartItemId) async {
    try {
      await _supabaseService.client
          .from('shopping_cart')
          .delete()
          .eq('id', cartItemId);

      await fetchCart();
      return true;
    } catch (e) {
      _error = 'Failed to remove item: $e';
      notifyListeners();
      debugPrint('Error removing from cart: $e');
      return false;
    }
  }

  /// Clear cart
  Future<bool> clearCart() async {
    try {
      final userId = _supabaseService.currentUser?.id;
      if (userId == null) return false;

      await _supabaseService.client
          .from('shopping_cart')
          .delete()
          .eq('user_id', userId);

      _cartItems.clear();
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to clear cart: $e';
      notifyListeners();
      debugPrint('Error clearing cart: $e');
      return false;
    }
  }

  /// Set selected category filter
  void setSelectedCategory(String? categoryId) {
    _selectedCategoryId = categoryId;
    notifyListeners();
  }

  /// Clear selected category filter
  void clearCategoryFilter() {
    _selectedCategoryId = null;
    notifyListeners();
  }

  /// Refresh all data
  Future<void> refresh() async {
    await initialize();
  }

  @override
  void dispose() {
    super.dispose();
  }
}
