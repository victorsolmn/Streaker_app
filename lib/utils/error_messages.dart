/// Centralized repository of user-friendly error messages
/// All messages are written in plain language to help users understand and resolve issues
class ErrorMessages {
  // Network errors
  static const String noInternetConnection =
      'No internet connection. Please check your WiFi or mobile data and try again.';

  static const String requestTimeout =
      'Request timed out. Please check your connection and try again.';

  static const String serverUnreachable =
      'Unable to reach server. Please try again later.';

  static const String weakNetwork =
      'Weak network detected. This may take longer than usual.';

  // Authentication errors
  static const String authenticationExpired =
      'Your session has expired. Please sign in again.';

  static const String sessionExpired =
      'Your session has expired. Please sign in to continue.';

  static const String invalidCredentials =
      'Invalid email or password. Please try again.';

  static const String otpInvalid =
      'Invalid verification code. Please check your email and try again.';

  static const String otpExpired =
      'Verification code has expired. Please request a new one.';

  static const String tooManyAttempts =
      'Too many attempts. Please try again in 10 minutes.';

  static const String otpDailyLimit =
      'Maximum 5 verification codes per day. Please try again tomorrow.';

  // Data validation errors
  static const String invalidDataFormat =
      'Invalid data format. Please contact support if this continues.';

  static const String duplicateEntry =
      'This entry already exists. Please modify and try again.';

  static const String invalidEmail =
      'Please enter a valid email address.';

  static const String invalidPhoneNumber =
      'Please enter a valid phone number.';

  // Permission errors
  static const String cameraPermissionDenied =
      'Camera access is required to scan food. Please enable it in Settings → Privacy → Camera.';

  static const String storagePermissionDenied =
      'Storage access is required. Please enable it in your device settings.';

  static const String healthPermissionDenied =
      'Health data access is required. Please grant permission in Settings.';

  // Feature-specific errors
  static const String foodScanFailed =
      'Unable to analyze this meal. Please try taking another photo or enter nutrition manually.';

  static const String nutritionDataNotFound =
      'No nutrition data found for this date. Start logging meals to build your streak!';

  static const String profileUpdateFailed =
      'Unable to save profile changes. Your previous information is still intact. Please try again.';

  static const String weightEntryFailed =
      'Unable to save weight entry. Please try again.';

  static const String cartUpdateFailed =
      'Unable to update cart. Please try again.';

  static const String whatsappNotInstalled =
      'WhatsApp is not installed on your device. Please install it to place orders.';

  static const String quantityLimitReached =
      'Maximum 10 items per product. For bulk orders, please contact support.';

  // Generic errors
  static const String genericError =
      'Something went wrong. Please try again or contact support.';

  static const String unknownError =
      'An unexpected error occurred. Our team has been notified.';

  static const String maintenanceMode =
      'The app is currently undergoing maintenance. Please check back in a few minutes.';

  // Success messages (for context)
  static const String profileUpdateSuccess =
      'Profile updated successfully! 🎉';

  static const String mealAddedSuccess =
      'Added your meal to nutrition log! 🍎';

  static const String cartItemAdded =
      'Item added to cart';

  static const String cartItemRemoved =
      'Item removed from cart';

  static const String undoAvailable =
      'Tap UNDO to restore';
}
