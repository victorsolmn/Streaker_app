import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/marketplace_provider.dart';
import '../../models/product_model.dart';
import '../../models/premium_membership_model.dart';
import '../../utils/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'cart_screen.dart';

/// Marketplace Screen - Supplement Store Catalog
/// Layout: Sidebar (Brands) + Main Content (Search, Chips, Grid)
class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({Key? key}) : super(key: key);

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedBrandIndex = 0;

  // WhatsApp Business Number
  final String _whatsappNumber = '919876543210'; // Replace with actual number

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MarketplaceProvider>(context, listen: false).initialize();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addToCart(Product product) async {
    final provider = Provider.of<MarketplaceProvider>(context, listen: false);
    final success = await provider.addToCart(product.id);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product.name} added to cart'),
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'View Cart',
              textColor: AppTheme.primaryAccent,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CartScreen(),
                  ),
                );
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add item to cart'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackground : Colors.white,
      body: SafeArea(
        child: Row(
          children: [
            // Left Sidebar - Brands
            _buildBrandSidebar(isDarkMode, screenHeight),

            // Main Content Area
            Expanded(
              child: Column(
                children: [
                  // Header with back button and title
                  _buildHeader(isDarkMode),

                  // Search Bar
                  _buildSearchBar(isDarkMode),

                  // Category Chips
                  _buildCategoryChips(isDarkMode),

                  // Product Grid
                  Expanded(
                    child: _buildProductGrid(isDarkMode),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Brand Sidebar (Orange gradient - Streaker colors)
  Widget _buildBrandSidebar(bool isDarkMode, double screenHeight) {
    return Container(
      width: 100, // Reduced from 120 for better space
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.primaryAccent, // #FF6B1A
            AppTheme.primaryHover,  // #FF8C42
          ],
        ),
      ),
      child: Consumer<MarketplaceProvider>(
        builder: (context, provider, _) {
          // Get unique brands from products
          final brands = ['All Brands'];
          for (var product in provider.products) {
            if (!brands.contains(product.brand)) {
              brands.add(product.brand);
            }
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: brands.length,
            itemBuilder: (context, index) {
              final brand = brands[index];
              final isSelected = _selectedBrandIndex == index;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedBrandIndex = index;
                  });
                  // Filter by brand if needed
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      // Brand Icon/Image placeholder
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            index == 0 ? '💊' : brand.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              fontSize: index == 0 ? 20 : 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Brand Name
                      Text(
                        brand,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Header with logo and cart
  Widget _buildHeader(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkCardBackground : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDarkMode
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Back button
          GestureDetector(
            onTap: () {
              // Navigate back
            },
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.arrow_back,
                color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Logo
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.primaryAccent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Center(
              child: Text(
                '💪',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Title - Flexible to prevent overflow
          Expanded(
            child: Text(
              'Supplements',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Cart button with badge
          Consumer<MarketplaceProvider>(
            builder: (context, provider, _) {
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CartScreen(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 22,
                        color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                      ),
                      if (provider.cartItemCount > 0)
                        Positioned(
                          right: -6,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryAccent,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Center(
                              child: Text(
                                '${provider.cartItemCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Search Bar
  Widget _buildSearchBar(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
        decoration: InputDecoration(
          hintText: 'Search by Products',
          hintStyle: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: AppTheme.textSecondary,
            size: 20,
          ),
          filled: true,
          fillColor: isDarkMode
              ? AppTheme.darkCardBackground
              : AppTheme.cardBackgroundLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          isDense: true,
        ),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  // Category Chips (like Plants, Pots, Soil & More)
  Widget _buildCategoryChips(bool isDarkMode) {
    return Container(
      height: 45,
      margin: const EdgeInsets.only(bottom: 8),
      child: Consumer<MarketplaceProvider>(
        builder: (context, provider, _) {
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: provider.categories.length,
            itemBuilder: (context, index) {
              final category = provider.categories[index];
              final isSelected = provider.selectedCategoryId == category.id;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(category.name),
                  selected: isSelected,
                  onSelected: (selected) {
                    provider.setSelectedCategory(selected ? category.id : null);
                  },
                  backgroundColor: isDarkMode
                      ? AppTheme.darkCardBackground
                      : AppTheme.cardBackgroundLight,
                  selectedColor: _getCategoryColor(category.slug),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getCategoryColor(String slug) {
    switch (slug) {
      case 'protein':
        return AppTheme.accentFlameOrange; // Warm orange for protein
      case 'pre-workout':
        return AppTheme.accentFlameRed; // Energetic red for pre-workout
      case 'creatine':
        return AppTheme.secondaryDark; // Blue for creatine
      case 'post-workout':
        return AppTheme.accentGreen; // Green for post-workout recovery
      case 'combo-packs':
        return AppTheme.accentFlameYellow; // Yellow for combo packs
      default:
        return AppTheme.primaryAccent;
    }
  }

  // Product Grid
  Widget _buildProductGrid(bool isDarkMode) {
    return Consumer<MarketplaceProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.products.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        // Filter products by search and brand
        var products = provider.filteredProducts;

        if (_searchQuery.isNotEmpty) {
          products = products.where((p) =>
              p.name.toLowerCase().contains(_searchQuery) ||
              p.brand.toLowerCase().contains(_searchQuery)).toList();
        }

        if (products.isEmpty) {
          return _buildEmptyState(isDarkMode);
        }

        return RefreshIndicator(
          onRefresh: () => provider.refresh(),
          color: AppTheme.primaryAccent,
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.60, // Taller cards to prevent overflow
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return _buildProductCard(product, provider.isPremiumMember, isDarkMode);
            },
          ),
        );
      },
    );
  }

  // Product Card (matches reference design)
  Widget _buildProductCard(Product product, bool isPremium, bool isDarkMode) {
    final price = isPremium ? product.premiumPrice : product.regularPrice;
    final hasDiscount = isPremium && product.discount > 0;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkCardBackground : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image with "New In" badge
          Stack(
            children: [
              Container(
                height: 120, // Reduced height
                decoration: BoxDecoration(
                  color: AppTheme.cardBackgroundLight,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.fitness_center,
                    size: 50,
                    color: AppTheme.primaryAccent.withOpacity(0.3),
                  ),
                ),
              ),
              // New In badge (if product is featured)
              if (product.isFeatured)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.warningYellow,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'New In',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              // Add to Cart button (top right) - Streaker orange
              Positioned(
                bottom: 6,
                right: 6,
                child: Material(
                  color: AppTheme.primaryAccent,
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: product.inStock
                        ? () => _addToCart(product)
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'Add',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 2),
                          Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Product Details - Flexible layout
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Product Name
                  Text(
                    product.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? AppTheme.textPrimaryDark
                          : AppTheme.textPrimary,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Rating - Compact
                  if (product.reviewCount > 0)
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (i) => Icon(
                            i < product.rating.floor()
                                ? Icons.star
                                : Icons.star_border,
                            color: AppTheme.warningYellow,
                            size: 12,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '(${product.reviewCount})',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),

                  const Spacer(),

                  // Price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? AppTheme.textPrimaryDark
                              : AppTheme.textPrimary,
                        ),
                      ),
                      if (hasDiscount) ...[
                        const SizedBox(width: 4),
                        Text(
                          '₹${product.regularPrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondary,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Discount badge
                  if (hasDiscount)
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.errorRed,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        '-${product.discountPercentage}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Empty State
  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 80,
              color: AppTheme.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No products found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode
                    ? AppTheme.textPrimaryDark
                    : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
