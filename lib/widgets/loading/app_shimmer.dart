import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Centralized shimmer/skeleton loader library for the Streaker app.
/// All widgets here are pure UI — no data fetching, no business logic.
class AppShimmer {
  AppShimmer._();

  static Color shimmerBase(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE0E0E0);
  }

  static Color shimmerHighlight(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF3A3A3C) : const Color(0xFFF5F5F5);
  }

  /// Wraps [child] in a branded shimmer effect.
  static Widget wrap({required BuildContext context, required Widget child}) {
    return Shimmer.fromColors(
      baseColor: shimmerBase(context),
      highlightColor: shimmerHighlight(context),
      child: child,
    );
  }

  /// A simple rounded rectangle shimmer block.
  static Widget box({
    double width = double.infinity,
    required double height,
    double radius = 12,
    EdgeInsets? margin,
  }) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  /// A circle shimmer block (for avatars).
  static Widget circle({required double size, EdgeInsets? margin}) {
    return Container(
      width: size,
      height: size,
      margin: margin,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HOME SCREEN SHIMMERS
// ─────────────────────────────────────────────

/// Skeleton for the 3-column top strip on the Home screen
class HomeTopSectionShimmer extends StatelessWidget {
  const HomeTopSectionShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer.wrap(
      context: context,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(child: AppShimmer.box(height: 90, radius: 16)),
            const SizedBox(width: 12),
            AppShimmer.circle(size: 110),
            const SizedBox(width: 12),
            Expanded(child: AppShimmer.box(height: 90, radius: 16)),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for the 2×2 metrics grid on the Home screen
class HomeMetricsShimmer extends StatelessWidget {
  const HomeMetricsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer.wrap(
      context: context,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _metricCard()),
                const SizedBox(width: 12),
                Expanded(child: _metricCard()),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _metricCard()),
                const SizedBox(width: 12),
                Expanded(child: _metricCard()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricCard() {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppShimmer.box(width: 18, height: 18, radius: 4),
              const SizedBox(width: 8),
              AppShimmer.box(width: 60, height: 12, radius: 6),
            ],
          ),
          const Spacer(),
          AppShimmer.box(width: 80, height: 16, radius: 6),
          const SizedBox(height: 6),
          AppShimmer.box(height: 6, radius: 3),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// NUTRITION SCREEN SHIMMERS
// ─────────────────────────────────────────────

/// Skeleton for 3 nutrition entry cards
class NutritionListShimmer extends StatelessWidget {
  const NutritionListShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer.wrap(
      context: context,
      child: Column(
        children: List.generate(3, (_) => _nutritionCard()),
      ),
    );
  }

  Widget _nutritionCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          AppShimmer.box(width: 48, height: 48, radius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppShimmer.box(width: 140, height: 14, radius: 7),
                const SizedBox(height: 8),
                Row(
                  children: [
                    AppShimmer.box(width: 50, height: 10, radius: 5),
                    const SizedBox(width: 8),
                    AppShimmer.box(width: 50, height: 10, radius: 5),
                    const SizedBox(width: 8),
                    AppShimmer.box(width: 50, height: 10, radius: 5),
                  ],
                ),
              ],
            ),
          ),
          AppShimmer.box(width: 50, height: 28, radius: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PROFILE SCREEN SHIMMERS
// ─────────────────────────────────────────────

/// Skeleton for the profile screen header
class ProfileHeaderShimmer extends StatelessWidget {
  const ProfileHeaderShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer.wrap(
      context: context,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            AppShimmer.circle(size: 90),
            const SizedBox(height: 12),
            AppShimmer.box(width: 140, height: 16, radius: 8),
            const SizedBox(height: 8),
            AppShimmer.box(width: 100, height: 12, radius: 6),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// WEIGHT CHART SHIMMER
// ─────────────────────────────────────────────

/// Skeleton for the weight progress chart
class WeightChartShimmer extends StatelessWidget {
  const WeightChartShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer.wrap(
      context: context,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppShimmer.box(width: 120, height: 14, radius: 7),
            const SizedBox(height: 12),
            AppShimmer.box(height: 180, radius: 16),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: AppShimmer.box(height: 48, radius: 12)),
                const SizedBox(width: 12),
                Expanded(child: AppShimmer.box(height: 48, radius: 12)),
                const SizedBox(width: 12),
                Expanded(child: AppShimmer.box(height: 48, radius: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
