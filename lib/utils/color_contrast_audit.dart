import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'accessibility_utils.dart';

/// Color Contrast Audit Report
/// Checks all color combinations against WCAG AA/AAA standards
class ColorContrastAudit {
  static const double wcagAANormal = 4.5;
  static const double wcagAALarge = 3.0;
  static const double wcagAAANormal = 7.0;
  static const double wcagAAALarge = 4.5;

  /// Run complete audit and return results
  static Map<String, ContrastResult> runAudit() {
    final results = <String, ContrastResult>{};

    // Light Theme Audits
    results['Light: Primary text on white'] = _checkContrast(
      AppTheme.textPrimary,
      AppTheme.backgroundWhite,
      'Primary text on white background',
    );

    results['Light: Secondary text on white'] = _checkContrast(
      AppTheme.textSecondary,
      AppTheme.backgroundWhite,
      'Secondary text on white background',
    );

    results['Light: Primary accent on white'] = _checkContrast(
      AppTheme.primaryAccent,
      AppTheme.backgroundWhite,
      'Primary accent (orange) on white',
    );

    results['Light: White on primary accent'] = _checkContrast(
      Colors.white,
      AppTheme.primaryAccent,
      'White text on primary accent button',
    );

    results['Light: Secondary on white'] = _checkContrast(
      AppTheme.secondaryLight,
      AppTheme.backgroundWhite,
      'Secondary blue on white',
    );

    results['Light: Success on white'] = _checkContrast(
      AppTheme.successGreen,
      AppTheme.backgroundWhite,
      'Success green on white',
    );

    results['Light: Error on white'] = _checkContrast(
      AppTheme.errorRed,
      AppTheme.backgroundWhite,
      'Error red on white',
    );

    results['Light: Warning on white'] = _checkContrast(
      AppTheme.warningYellow,
      AppTheme.backgroundWhite,
      'Warning yellow on white',
    );

    // Dark Theme Audits
    results['Dark: Primary text on dark'] = _checkContrast(
      AppTheme.textPrimaryDark,
      AppTheme.darkBackground,
      'White text on dark background',
    );

    results['Dark: Secondary text on dark'] = _checkContrast(
      AppTheme.textSecondaryDark,
      AppTheme.darkBackground,
      'Gray text on dark background',
    );

    results['Dark: Primary accent on dark'] = _checkContrast(
      AppTheme.primaryAccent,
      AppTheme.darkBackground,
      'Primary accent on dark',
    );

    results['Dark: White on card'] = _checkContrast(
      Colors.white,
      AppTheme.darkCardBackground,
      'White text on dark card',
    );

    results['Dark: Success on dark'] = _checkContrast(
      AppTheme.successGreen,
      AppTheme.darkBackground,
      'Success green on dark',
    );

    results['Dark: Error on dark'] = _checkContrast(
      AppTheme.errorRed,
      AppTheme.darkBackground,
      'Error red on dark',
    );

    // Card/Surface combinations
    results['Light: Text on card'] = _checkContrast(
      AppTheme.textPrimary,
      AppTheme.cardBackgroundLight,
      'Primary text on light card',
    );

    results['Dark: Text on card'] = _checkContrast(
      AppTheme.textPrimaryDark,
      AppTheme.darkCardBackground,
      'White text on dark card',
    );

    return results;
  }

  static ContrastResult _checkContrast(
    Color foreground,
    Color background,
    String description,
  ) {
    final ratio = AccessibilityUtils.calculateContrastRatio(
      foreground,
      background,
    );

    return ContrastResult(
      foreground: foreground,
      background: background,
      ratio: ratio,
      description: description,
      passesAANormal: ratio >= wcagAANormal,
      passesAALarge: ratio >= wcagAALarge,
      passesAAANormal: ratio >= wcagAAANormal,
      passesAAALarge: ratio >= wcagAAALarge,
    );
  }

  /// Print audit report to console
  static void printAuditReport() {
    final results = runAudit();
    print('=== COLOR CONTRAST AUDIT REPORT ===\n');

    int totalChecks = results.length;
    int passingAA = 0;
    int passingAAA = 0;

    results.forEach((key, result) {
      print('${result.description}:');
      print('  Ratio: ${result.ratio.toStringAsFixed(2)}:1');
      print('  WCAG AA Normal (4.5:1): ${result.passesAANormal ? "✅ PASS" : "❌ FAIL"}');
      print('  WCAG AA Large (3.0:1): ${result.passesAALarge ? "✅ PASS" : "❌ FAIL"}');
      print('  WCAG AAA Normal (7.0:1): ${result.passesAAANormal ? "✅ PASS" : "❌ FAIL"}');
      print('  WCAG AAA Large (4.5:1): ${result.passesAAALarge ? "✅ PASS" : "❌ FAIL"}');
      print('');

      if (result.passesAANormal) passingAA++;
      if (result.passesAAANormal) passingAAA++;
    });

    print('=== SUMMARY ===');
    print('Total checks: $totalChecks');
    print('Passing WCAG AA: $passingAA/$totalChecks (${(passingAA / totalChecks * 100).toStringAsFixed(1)}%)');
    print('Passing WCAG AAA: $passingAAA/$totalChecks (${(passingAAA / totalChecks * 100).toStringAsFixed(1)}%)');
  }

  /// Get fixes for failing combinations
  static List<ContrastFix> getSuggestedFixes() {
    final results = runAudit();
    final fixes = <ContrastFix>[];

    results.forEach((key, result) {
      if (!result.passesAANormal) {
        fixes.add(ContrastFix(
          issue: result.description,
          currentRatio: result.ratio,
          requiredRatio: wcagAANormal,
          suggestion: _getSuggestion(result),
        ));
      }
    });

    return fixes;
  }

  static String _getSuggestion(ContrastResult result) {
    if (result.ratio < wcagAANormal) {
      return 'Increase contrast by darkening foreground or lightening background';
    }
    return 'Contrast is acceptable';
  }
}

class ContrastResult {
  final Color foreground;
  final Color background;
  final double ratio;
  final String description;
  final bool passesAANormal;
  final bool passesAALarge;
  final bool passesAAANormal;
  final bool passesAAALarge;

  ContrastResult({
    required this.foreground,
    required this.background,
    required this.ratio,
    required this.description,
    required this.passesAANormal,
    required this.passesAALarge,
    required this.passesAAANormal,
    required this.passesAAALarge,
  });
}

class ContrastFix {
  final String issue;
  final double currentRatio;
  final double requiredRatio;
  final String suggestion;

  ContrastFix({
    required this.issue,
    required this.currentRatio,
    required this.requiredRatio,
    required this.suggestion,
  });

  @override
  String toString() {
    return 'Issue: $issue\n'
        'Current: ${currentRatio.toStringAsFixed(2)}:1\n'
        'Required: ${requiredRatio.toStringAsFixed(2)}:1\n'
        'Fix: $suggestion\n';
  }
}
