/// Product Models - Exactly matches Supabase schema
///
/// These models are 1:1 mappings with the marketplace tables

class ProductCategory {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? icon; // Material Icon name
  final int displayOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.icon,
    this.displayOrder = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    return ProductCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      displayOrder: json['display_order'] ?? 0,
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      if (description != null) 'description': description,
      if (icon != null) 'icon': icon,
      'display_order': displayOrder,
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}

class Product {
  final String id;
  final String? categoryId;
  final String name;
  final String brand;
  final String? description;
  final String? imageUrl;
  final double regularPrice;
  final double premiumPrice;
  final int discountPercentage;
  final int stockQuantity;
  final bool isFeatured;
  final bool isActive;
  final String? servingSize; // e.g., "30 servings", "1kg"
  final String? flavor; // e.g., "Chocolate", "Vanilla"
  final double rating; // out of 5.0
  final int reviewCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Computed properties
  double get discount => regularPrice - premiumPrice;
  double get discountActual => (discount / regularPrice) * 100;
  bool get inStock => stockQuantity > 0;

  Product({
    required this.id,
    this.categoryId,
    required this.name,
    required this.brand,
    this.description,
    this.imageUrl,
    required this.regularPrice,
    required this.premiumPrice,
    this.discountPercentage = 25,
    this.stockQuantity = 0,
    this.isFeatured = false,
    this.isActive = true,
    this.servingSize,
    this.flavor,
    this.rating = 0.0,
    this.reviewCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      categoryId: json['category_id'] as String?,
      name: json['name'] as String,
      brand: json['brand'] as String,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      regularPrice: (json['regular_price'] as num).toDouble(),
      premiumPrice: (json['premium_price'] as num).toDouble(),
      discountPercentage: json['discount_percentage'] ?? 25,
      stockQuantity: json['stock_quantity'] ?? 0,
      isFeatured: json['is_featured'] ?? false,
      isActive: json['is_active'] ?? true,
      servingSize: json['serving_size'] as String?,
      flavor: json['flavor'] as String?,
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : 0.0,
      reviewCount: json['review_count'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (categoryId != null) 'category_id': categoryId,
      'name': name,
      'brand': brand,
      if (description != null) 'description': description,
      if (imageUrl != null) 'image_url': imageUrl,
      'regular_price': regularPrice,
      'premium_price': premiumPrice,
      'discount_percentage': discountPercentage,
      'stock_quantity': stockQuantity,
      'is_featured': isFeatured,
      'is_active': isActive,
      if (servingSize != null) 'serving_size': servingSize,
      if (flavor != null) 'flavor': flavor,
      'rating': rating,
      'review_count': reviewCount,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Product copyWith({
    String? id,
    String? categoryId,
    String? name,
    String? brand,
    String? description,
    String? imageUrl,
    double? regularPrice,
    double? premiumPrice,
    int? discountPercentage,
    int? stockQuantity,
    bool? isFeatured,
    bool? isActive,
    String? servingSize,
    String? flavor,
    double? rating,
    int? reviewCount,
  }) {
    return Product(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      regularPrice: regularPrice ?? this.regularPrice,
      premiumPrice: premiumPrice ?? this.premiumPrice,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      isFeatured: isFeatured ?? this.isFeatured,
      isActive: isActive ?? this.isActive,
      servingSize: servingSize ?? this.servingSize,
      flavor: flavor ?? this.flavor,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

class CartItem {
  final String id;
  final String userId;
  final String productId;
  final int quantity;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined product data (when fetching with join)
  Product? product;

  CartItem({
    required this.id,
    required this.userId,
    required this.productId,
    this.quantity = 1,
    required this.createdAt,
    required this.updatedAt,
    this.product,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      productId: json['product_id'] as String,
      quantity: json['quantity'] ?? 1,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      product: json['products'] != null
          ? Product.fromJson(json['products'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'product_id': productId,
      'quantity': quantity,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  double getTotalPrice(bool isPremium) {
    if (product == null) return 0;
    final price = isPremium ? product!.premiumPrice : product!.regularPrice;
    return price * quantity;
  }
}
