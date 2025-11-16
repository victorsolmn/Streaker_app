/// Premium Membership Model - Exactly matches Supabase schema

class PremiumMembership {
  final String id;
  final String userId;
  final String planType; // monthly, quarterly, annual
  final String status; // active, cancelled, expired, trial
  final DateTime startDate;
  final DateTime endDate;
  final DateTime? trialEndDate;
  final double pricePaid;
  final int discountPercentage;
  final bool autoRenew;
  final String? paymentMethod;
  final String? razorpaySubscriptionId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Computed properties
  bool get isActive => status == 'active' && endDate.isAfter(DateTime.now());
  bool get isTrial => status == 'trial';
  bool get isExpired => endDate.isBefore(DateTime.now());
  int get daysRemaining => endDate.difference(DateTime.now()).inDays;

  // Plan type helpers
  bool get isMonthly => planType == 'monthly';
  bool get isQuarterly => planType == 'quarterly';
  bool get isAnnual => planType == 'annual';

  PremiumMembership({
    required this.id,
    required this.userId,
    required this.planType,
    required this.status,
    required this.startDate,
    required this.endDate,
    this.trialEndDate,
    required this.pricePaid,
    this.discountPercentage = 25,
    this.autoRenew = true,
    this.paymentMethod,
    this.razorpaySubscriptionId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PremiumMembership.fromJson(Map<String, dynamic> json) {
    return PremiumMembership(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      planType: json['plan_type'] as String,
      status: json['status'] as String,
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      trialEndDate: json['trial_end_date'] != null
          ? DateTime.parse(json['trial_end_date'])
          : null,
      pricePaid: (json['price_paid'] as num).toDouble(),
      discountPercentage: json['discount_percentage'] ?? 25,
      autoRenew: json['auto_renew'] ?? true,
      paymentMethod: json['payment_method'] as String?,
      razorpaySubscriptionId: json['razorpay_subscription_id'] as String?,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'plan_type': planType,
      'status': status,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      if (trialEndDate != null) 'trial_end_date': trialEndDate!.toIso8601String(),
      'price_paid': pricePaid,
      'discount_percentage': discountPercentage,
      'auto_renew': autoRenew,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (razorpaySubscriptionId != null)
        'razorpay_subscription_id': razorpaySubscriptionId,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  PremiumMembership copyWith({
    String? id,
    String? userId,
    String? planType,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? trialEndDate,
    double? pricePaid,
    int? discountPercentage,
    bool? autoRenew,
    String? paymentMethod,
    String? razorpaySubscriptionId,
  }) {
    return PremiumMembership(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      planType: planType ?? this.planType,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      trialEndDate: trialEndDate ?? this.trialEndDate,
      pricePaid: pricePaid ?? this.pricePaid,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      autoRenew: autoRenew ?? this.autoRenew,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      razorpaySubscriptionId:
          razorpaySubscriptionId ?? this.razorpaySubscriptionId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Get formatted plan type name
  String getPlanName() {
    switch (planType) {
      case 'monthly':
        return 'Monthly Plan';
      case 'quarterly':
        return 'Quarterly Plan';
      case 'annual':
        return 'Annual Plan';
      default:
        return 'Premium Plan';
    }
  }

  /// Get formatted price display
  String getFormattedPrice() {
    return '₹${pricePaid.toStringAsFixed(0)}';
  }

  /// Get savings percentage
  String getSavingsText() {
    if (isMonthly) return '';
    if (isQuarterly) return 'Save 11%';
    if (isAnnual) return 'Save 16%';
    return '';
  }

  /// Get renewal date text
  String getRenewalText() {
    if (isExpired) return 'Expired';
    if (daysRemaining <= 0) return 'Expires today';
    if (daysRemaining == 1) return 'Renews tomorrow';
    if (daysRemaining <= 7) return 'Renews in $daysRemaining days';
    return 'Renews on ${_formatDate(endDate)}';
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

/// Premium Plan Configuration
class PremiumPlanConfig {
  final String planType;
  final String name;
  final double monthlyPrice;
  final double totalPrice;
  final int discountPercentage;
  final String savingsText;
  final List<String> features;

  PremiumPlanConfig({
    required this.planType,
    required this.name,
    required this.monthlyPrice,
    required this.totalPrice,
    this.discountPercentage = 25,
    this.savingsText = '',
    required this.features,
  });

  static List<PremiumPlanConfig> getAllPlans() {
    return [
      PremiumPlanConfig(
        planType: 'monthly',
        name: 'Monthly',
        monthlyPrice: 299,
        totalPrice: 299,
        discountPercentage: 25,
        savingsText: '',
        features: [
          '25% off on all supplements',
          'Priority customer support',
          'Exclusive workout plans',
          'Cancel anytime',
        ],
      ),
      PremiumPlanConfig(
        planType: 'quarterly',
        name: 'Quarterly',
        monthlyPrice: 266,
        totalPrice: 799,
        discountPercentage: 25,
        savingsText: 'Save 11%',
        features: [
          '25% off on all supplements',
          'Priority customer support',
          'Exclusive workout plans',
          'Best value for 3 months',
        ],
      ),
      PremiumPlanConfig(
        planType: 'annual',
        name: 'Annual',
        monthlyPrice: 250,
        totalPrice: 2999,
        discountPercentage: 25,
        savingsText: 'Save 16% - Most Popular!',
        features: [
          '25% off on all supplements',
          'Priority customer support',
          'Exclusive workout plans',
          'Maximum savings',
        ],
      ),
    ];
  }

  static PremiumPlanConfig? getPlan(String planType) {
    try {
      return getAllPlans().firstWhere((plan) => plan.planType == planType);
    } catch (e) {
      return null;
    }
  }

  String getFormattedMonthlyPrice() {
    return '₹${monthlyPrice.toStringAsFixed(0)}/mo';
  }

  String getFormattedTotalPrice() {
    return '₹${totalPrice.toStringAsFixed(0)}';
  }
}
