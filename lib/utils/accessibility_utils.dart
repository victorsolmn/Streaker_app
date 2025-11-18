import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Utility class for accessibility enhancements
/// Provides helpers for screen reader support, semantic labels, and WCAG compliance
class AccessibilityUtils {
  /// Announce a message to screen readers without changing focus
  static void announce(BuildContext context, String message) {
    SemanticsService.announce(message, TextDirection.ltr);
  }

  /// Check if screen reader is enabled
  static bool isScreenReaderEnabled(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.accessibleNavigation;
  }

  /// Create semantic label for icon buttons (required for screen readers)
  static String iconButtonLabel(String action, {String? target}) {
    if (target != null) {
      return '$action $target';
    }
    return action;
  }

  /// Create semantic label for status indicators
  static String statusLabel(String item, bool isActive) {
    return '$item ${isActive ? "active" : "inactive"}';
  }

  /// Create semantic label for progress indicators
  static String progressLabel(int current, int total, {String? stepName}) {
    final base = 'Step $current of $total';
    return stepName != null ? '$base: $stepName' : base;
  }

  /// Create semantic label for numeric values with units
  static String valueWithUnit(num value, String unit, {String? label}) {
    final valueStr = '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)} $unit';
    return label != null ? '$label: $valueStr' : valueStr;
  }

  /// Create semantic label for dates
  static String dateLabel(DateTime date, {String? prefix}) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    final dateStr = '${months[date.month - 1]} ${date.day}, ${date.year}';
    return prefix != null ? '$prefix: $dateStr' : dateStr;
  }

  /// Check if color contrast meets WCAG AA standards (4.5:1 for normal text)
  static bool meetsContrastRequirement(Color foreground, Color background, {bool isLargeText = false}) {
    final ratio = calculateContrastRatio(foreground, background);
    final minRatio = isLargeText ? 3.0 : 4.5; // WCAG AA requirements
    return ratio >= minRatio;
  }

  /// Calculate contrast ratio between two colors (WCAG formula)
  static double calculateContrastRatio(Color color1, Color color2) {
    final luminance1 = _calculateRelativeLuminance(color1);
    final luminance2 = _calculateRelativeLuminance(color2);

    final lighter = luminance1 > luminance2 ? luminance1 : luminance2;
    final darker = luminance1 > luminance2 ? luminance2 : luminance1;

    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Calculate relative luminance (WCAG formula)
  static double _calculateRelativeLuminance(Color color) {
    final r = _adjustColorComponent(color.red / 255.0);
    final g = _adjustColorComponent(color.green / 255.0);
    final b = _adjustColorComponent(color.blue / 255.0);

    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Adjust color component for luminance calculation
  static double _adjustColorComponent(double component) {
    if (component <= 0.03928) {
      return component / 12.92;
    }
    return ((component + 0.055) / 1.055) * ((component + 0.055) / 1.055);
  }

  /// Get accessible text color (black or white) based on background
  static Color getAccessibleTextColor(Color background) {
    final luminance = _calculateRelativeLuminance(background);
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  /// Create ExcludeSemantics widget to hide decorative elements from screen readers
  static Widget hideFromScreenReader(Widget child) {
    return ExcludeSemantics(child: child);
  }

  /// Create MergeSemantics widget to combine child semantic labels
  static Widget mergeSemantics(Widget child) {
    return MergeSemantics(child: child);
  }

  /// Create custom semantic label for complex widgets
  static Widget customSemantics({
    required Widget child,
    required String label,
    String? hint,
    String? value,
    bool button = false,
    bool header = false,
    VoidCallback? onTap,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      value: value,
      button: button,
      header: header,
      onTap: onTap,
      child: child,
    );
  }

  /// Create live region for dynamic content (e.g., updating streak counts)
  static Widget liveRegion({
    required Widget child,
    required String label,
    LiveRegionPoliteness politeness = LiveRegionPoliteness.polite,
  }) {
    return Semantics(
      liveRegion: true,
      label: label,
      child: child,
    );
  }

  /// Announce success messages to screen readers
  static void announceSuccess(BuildContext context, String message) {
    announce(context, 'Success: $message');
  }

  /// Announce error messages to screen readers
  static void announceError(BuildContext context, String message) {
    announce(context, 'Error: $message');
  }

  /// Announce warning messages to screen readers
  static void announceWarning(BuildContext context, String message) {
    announce(context, 'Warning: $message');
  }

  /// Create semantic label for streaks
  static String streakLabel(int count, String type) {
    final plural = count == 1 ? '' : 's';
    return '$count day$plural $type streak';
  }

  /// Create semantic label for percentages
  static String percentageLabel(double percentage, String context) {
    return '$context: ${percentage.toStringAsFixed(0)} percent';
  }

  /// Create semantic label for toggles/switches
  static String toggleLabel(String item, bool isEnabled) {
    return '$item ${isEnabled ? "enabled" : "disabled"}';
  }

  /// Create semantic label for navigation items
  static String navigationLabel(String destination, {bool isCurrent = false}) {
    return isCurrent
        ? '$destination, currently selected'
        : 'Navigate to $destination';
  }

  /// Helper to wrap icon-only buttons with proper semantics
  static Widget accessibleIconButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
    double size = 24,
    String? tooltip,
  }) {
    return Semantics(
      label: label,
      button: true,
      enabled: true,
      child: IconButton(
        icon: Icon(icon, size: size),
        onPressed: onPressed,
        color: color,
        tooltip: tooltip ?? label,
      ),
    );
  }
}

/// Enum for live region politeness levels
enum LiveRegionPoliteness {
  polite,
  assertive,
}
