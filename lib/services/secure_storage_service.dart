import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for secure storage of sensitive data like API keys
/// Uses platform-specific secure storage:
/// - iOS: Keychain
/// - Android: EncryptedSharedPreferences/KeyStore
class SecureStorageService {
  // Singleton pattern
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  // Storage keys
  static const String _grokApiKeyKey = 'grok_api_key';
  static const String _grokApiEnabledKey = 'grok_api_enabled';

  // Platform-specific secure storage with options
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // Cache to avoid frequent reads from secure storage
  String? _cachedGrokApiKey;
  bool? _cachedGrokApiEnabled;

  /// Initialize API keys securely
  /// This should be called once during app startup
  Future<void> initializeApiKeys({
    required String grokApiKey,
    bool enableGrokApi = true,
  }) async {
    try {
      await _storage.write(key: _grokApiKeyKey, value: grokApiKey);
      await _storage.write(key: _grokApiEnabledKey, value: enableGrokApi.toString());

      // Update cache
      _cachedGrokApiKey = grokApiKey;
      _cachedGrokApiEnabled = enableGrokApi;
    } catch (e) {
      throw Exception('Failed to initialize API keys: $e');
    }
  }

  /// Get GROK API key from secure storage
  Future<String?> getGrokApiKey() async {
    if (_cachedGrokApiKey != null) {
      return _cachedGrokApiKey;
    }

    try {
      final key = await _storage.read(key: _grokApiKeyKey);
      _cachedGrokApiKey = key;
      return key;
    } catch (e) {
      throw Exception('Failed to retrieve GROK API key: $e');
    }
  }

  /// Check if GROK API is enabled
  Future<bool> isGrokApiEnabled() async {
    if (_cachedGrokApiEnabled != null) {
      return _cachedGrokApiEnabled!;
    }

    try {
      final enabled = await _storage.read(key: _grokApiEnabledKey);
      _cachedGrokApiEnabled = enabled == 'true';
      return _cachedGrokApiEnabled!;
    } catch (e) {
      return false; // Default to false if can't read
    }
  }

  /// Enable/disable GROK API
  Future<void> setGrokApiEnabled(bool enabled) async {
    try {
      await _storage.write(key: _grokApiEnabledKey, value: enabled.toString());
      _cachedGrokApiEnabled = enabled;
    } catch (e) {
      throw Exception('Failed to set GROK API enabled state: $e');
    }
  }

  /// Delete all stored API keys (useful for logout or reset)
  Future<void> deleteAllApiKeys() async {
    try {
      await _storage.delete(key: _grokApiKeyKey);
      await _storage.delete(key: _grokApiEnabledKey);

      // Clear cache
      _cachedGrokApiKey = null;
      _cachedGrokApiEnabled = null;
    } catch (e) {
      throw Exception('Failed to delete API keys: $e');
    }
  }

  /// Check if API keys are initialized
  Future<bool> hasApiKeys() async {
    try {
      final grokKey = await _storage.read(key: _grokApiKeyKey);
      return grokKey != null && grokKey.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Clear cache (useful for testing or when keys are updated externally)
  void clearCache() {
    _cachedGrokApiKey = null;
    _cachedGrokApiEnabled = null;
  }
}
