import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/marketplace_provider.dart';
import '../../models/product_model.dart';
import '../../models/premium_membership_model.dart';
import '../../utils/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// Marketplace Screen - Supplement Store Catalog
///
/// Features:
/// - Brand sidebar navigation
/// - Category chips for quick filtering
/// - Product catalog grid with pricing
/// - WhatsApp order integration
/// - Shopping cart functionality
class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({Key? key}) : super(key: key);

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _showStickyBanner = false;
  String _searchQuery = '';

  // Sample brands - in real app, fetch from database
  final List<Map<String, String>> _brands = [
    {'name': 'All Supplements', 'icon': '💊'},
    {'name': 'MuscleBlaze', 'icon': '💪'},
    {'name': 'Optimum Nutrition', 'icon': '⭐'},
    {'name': 'MyProtein', 'icon': '🏋️'},
    {'name': 'BSN', 'icon': '⚡'},
    {'name': 'Dymatize', 'icon': '🔥'},
  ];

  int _selectedBrandIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MarketplaceProvider>(context, listen: false).initialize();
    });

    _scrollController.addListener(() {
      final shouldShow = _scrollController.offset > 200;
      if (shouldShow != _showStickyBanner) {
        setState(() {
          _showStickyBanner = shouldShow;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackground : AppTheme.cardBackgroundLight,
      appBar: AppBar(
        backgroundColor: isDarkMode ? AppTheme.darkCardBackground : Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Supplement Store',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
          ),
        ),
        actions: [
          // Cart icon with badge
          Consumer<MarketplaceProvider>(
            builder: (context, provider, _) {
              return Stack(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.shopping_cart_outlined,
                      color: AppTheme.primaryAccent,
                    ),
                    onPressed: () {
                      // TODO: Navigate to cart screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Cart: ${provider.cartItemCount} items')),
                      );
                    },
                  ),
                  if (provider.cartItemCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.errorRed,
                          shape: BoxShape.circle,
                        ),
                        constraints: BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${provider.cartItemCount}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              await Provider.of<MarketplaceProvider>(context, listen: false).refresh();
            },
            color: AppTheme.primaryAccent,
            child: Consumer<MarketplaceProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading && provider.products.isEmpty) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryAccent,
                    ),
                  );
                }

                return CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    // Comparison Banner (shown at top)
                    SliverToBoxAdapter(
                      child: _buildComparisonBanner(provider, isDarkMode),
                    ),

                    // Category chips
                    SliverToBoxAdapter(
                      child: _buildCategoryChips(provider, isDarkMode),
                    ),

                    // Products grid
                    SliverPadding(
                      padding: EdgeInsets.all(16),
                      sliver: provider.filteredProducts.isEmpty
                          ? SliverToBoxAdapter(
                              child: _buildEmptyState(isDarkMode),
                            )
                          : SliverGrid(
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.7,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final product = provider.filteredProducts[index];
                                  return _buildProductCard(
                                    product,
                                    provider.isPremiumMember,
                                    isDarkMode,
                                    provider,
                                  );
                                },
                                childCount: provider.filteredProducts.length,
                              ),
                            ),
                    ),

                    // Bottom padding for sticky banner
                    SliverToBoxAdapter(
                      child: SizedBox(height: 80),
                    ),
                  ],
                );
              },
            ),
          ),

          // Sticky Premium Banner (shown when scrolled)
          if (_showStickyBanner)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Consumer<MarketplaceProvider>(
                builder: (context, provider, _) {
                  if (provider.isPremiumMember) return SizedBox.shrink();
                  return _buildStickyBanner(isDarkMode);
                },
              ),
            ),
        ],
      ),
    );
  }

  /// Comparison Banner - Shows regular vs premium pricing
  Widget _buildComparisonBanner(MarketplaceProvider provider, bool isDarkMode) {
    if (provider.isPremiumMember) {
      return _buildActiveMemberBanner(provider.activeMembership!, isDarkMode);
    }

    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFFF6B35).withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background pattern
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              Icons.local_fire_department,
              size: 120,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.workspace_premium, color: Colors.white, size: 28),
                    SizedBox(width: 8),
                    Text(
                      'Premium Membership',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text(
                  'Save 25% on every supplement purchase',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                SizedBox(height: 20),

                // Price comparison
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Regular Price',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '₹2,000',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 40,
                        width: 1,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Premium Price',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                                SizedBox(width: 4),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.successGreen,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '25% OFF',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Text(
                              '₹1,500',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.successGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16),

                ElevatedButton(
                  onPressed: () {
                    _showPremiumPlansDialog();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Color(0xFFFF6B35),
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: Size(double.infinity, 0),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Get Premium',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Active Member Banner
  Widget _buildActiveMemberBanner(PremiumMembership membership, bool isDarkMode) {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.successGreen, AppTheme.successGreen.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.verified, color: Colors.white, size: 32),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🎉 You\'re Premium!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Enjoying 25% off on all supplements',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                Text(
                  membership.getRenewalText(),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Sticky Banner - Shows at bottom when scrolled
  Widget _buildStickyBanner(bool isDarkMode) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Color(0xFFFF6B35),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Icon(Icons.workspace_premium, color: Colors.white, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Save 25% with Premium',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Starting at ₹250/month',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _showPremiumPlansDialog();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Color(0xFFFF6B35),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Upgrade',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Category chips for filtering
  Widget _buildCategoryChips(MarketplaceProvider provider, bool isDarkMode) {
    return Container(
      height: 50,
      margin: EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        itemCount: provider.categories.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            // "All" chip
            final isSelected = provider.selectedCategoryId == null;
            return Padding(
              padding: EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text('All'),
                selected: isSelected,
                onSelected: (selected) {
                  provider.clearCategoryFilter();
                },
                backgroundColor: isDarkMode ? AppTheme.darkCardBackground : Colors.white,
                selectedColor: AppTheme.primaryAccent.withOpacity(0.2),
                checkmarkColor: AppTheme.primaryAccent,
                labelStyle: TextStyle(
                  color: isSelected
                      ? AppTheme.primaryAccent
                      : (isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            );
          }

          final category = provider.categories[index - 1];
          final isSelected = provider.selectedCategoryId == category.id;

          return Padding(
            padding: EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(category.name),
              selected: isSelected,
              onSelected: (selected) {
                provider.setSelectedCategory(selected ? category.id : null);
              },
              backgroundColor: isDarkMode ? AppTheme.darkCardBackground : Colors.white,
              selectedColor: AppTheme.primaryAccent.withOpacity(0.2),
              checkmarkColor: AppTheme.primaryAccent,
              labelStyle: TextStyle(
                color: isSelected
                    ? AppTheme.primaryAccent
                    : (isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  /// Product card
  Widget _buildProductCard(
    Product product,
    bool isPremium,
    bool isDarkMode,
    MarketplaceProvider provider,
  ) {
    final price = isPremium ? product.premiumPrice : product.regularPrice;
    final showDiscount = isPremium && product.discount > 0;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkCardBackground : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // TODO: Show product details
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(product.name)),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product image placeholder
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: AppTheme.cardBackgroundLight,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Center(
                  child: Icon(
                    Icons.fitness_center,
                    size: 48,
                    color: AppTheme.primaryAccent.withOpacity(0.3),
                  ),
                ),
              ),

              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Brand
                      Text(
                        product.brand,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.primaryAccent,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),

                      // Product name
                      Text(
                        product.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      Spacer(),

                      // Price
                      Row(
                        children: [
                          Text(
                            '₹${price.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isPremium ? AppTheme.successGreen : AppTheme.primaryAccent,
                            ),
                          ),
                          if (showDiscount) ...[
                            SizedBox(width: 6),
                            Text(
                              '₹${product.regularPrice.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ],
                      ),

                      SizedBox(height: 8),

                      // Add to cart button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: product.inStock
                              ? () async {
                                  final success = await provider.addToCart(product.id);
                                  if (success && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Added to cart'),
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                  }
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryAccent,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            product.inStock ? 'Add to Cart' : 'Out of Stock',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Empty state
  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 64,
              color: AppTheme.textSecondary.withOpacity(0.5),
            ),
            SizedBox(height: 16),
            Text(
              'No products found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Check back soon for new supplements',
              style: TextStyle(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show premium plans dialog
  void _showPremiumPlansDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final plans = PremiumPlanConfig.getAllPlans();

        return Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDarkMode ? AppTheme.darkCardBackground : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choose Your Plan',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Save 25% on all supplement purchases',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                SizedBox(height: 24),

                ...plans.map((plan) => _buildPlanCard(plan, isDarkMode)).toList(),

                SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Maybe Later'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlanCard(PremiumPlanConfig plan, bool isDarkMode) {
    final isPopular = plan.planType == 'annual';

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isPopular ? AppTheme.primaryAccent : AppTheme.textSecondary.withOpacity(0.2),
          width: isPopular ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // TODO: Implement payment
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Selected: ${plan.name}')),
            );
          },
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            plan.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                            ),
                          ),
                          if (plan.savingsText.isNotEmpty) ...[
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.successGreen.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                plan.savingsText,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.successGreen,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        plan.getFormattedMonthlyPrice(),
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  plan.getFormattedTotalPrice(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
