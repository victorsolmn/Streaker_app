import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

/// Service for monitoring network connectivity status
/// Provides real-time connectivity checks and network status notifications
class ConnectivityService extends ChangeNotifier {
  bool _isConnected = true;
  bool _isCheckingConnection = false;
  Timer? _connectivityTimer;

  bool get isConnected => _isConnected;
  bool get isCheckingConnection => _isCheckingConnection;

  static final ConnectivityService _instance = ConnectivityService._internal();

  factory ConnectivityService() {
    return _instance;
  }

  ConnectivityService._internal() {
    _startPeriodicCheck();
  }

  /// Start periodic connectivity checks (every 30 seconds)
  void _startPeriodicCheck() {
    _connectivityTimer?.cancel();
    _connectivityTimer = Timer.periodic(Duration(seconds: 30), (_) {
      checkConnection();
    });
  }

  /// Manually check internet connectivity
  /// Returns true if connected, false otherwise
  Future<bool> checkConnection({bool notifyListeners = true}) async {
    if (_isCheckingConnection) {
      return _isConnected;
    }

    _isCheckingConnection = true;
    if (notifyListeners) {
      this.notifyListeners();
    }

    try {
      // Try to lookup Google's DNS server
      final result = await InternetAddress.lookup('google.com')
          .timeout(Duration(seconds: 5));

      _isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      _isConnected = false;
    } on TimeoutException catch (_) {
      _isConnected = false;
    } catch (e) {
      _isConnected = false;
    } finally {
      _isCheckingConnection = false;
      if (notifyListeners) {
        this.notifyListeners();
      }
    }

    return _isConnected;
  }

  /// Check connectivity with custom host
  Future<bool> checkConnectionToHost(String host) async {
    try {
      final result = await InternetAddress.lookup(host)
          .timeout(Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Display a snackbar when connection is lost
  void showNoConnectionSnackbar(BuildContext context) {
    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.signal_wifi_off, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No internet connection',
                  style: TextStyle(fontSize: 15),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'RETRY',
            textColor: Colors.white,
            onPressed: () async {
              final connected = await checkConnection();
              if (connected) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.wifi, color: Colors.white),
                        SizedBox(width: 12),
                        Text('Connected to internet'),
                      ],
                    ),
                    backgroundColor: Colors.green.shade700,
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ),
      );
    }
  }

  /// Wait for connection to be restored (with timeout)
  Future<bool> waitForConnection({
    Duration timeout = const Duration(seconds: 30),
    Duration checkInterval = const Duration(seconds: 2),
  }) async {
    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime) < timeout) {
      final connected = await checkConnection(notifyListeners: false);
      if (connected) {
        return true;
      }
      await Future.delayed(checkInterval);
    }

    return false;
  }

  /// Execute a function only if connected, otherwise show error
  Future<T?> executeIfConnected<T>({
    required BuildContext context,
    required Future<T> Function() action,
    String? errorMessage,
  }) async {
    final connected = await checkConnection();

    if (!connected) {
      showNoConnectionSnackbar(context);
      return null;
    }

    return await action();
  }

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    super.dispose();
  }
}

/// Widget that rebuilds when connectivity status changes
class ConnectivityBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, bool isConnected) builder;
  final ConnectivityService connectivityService;

  const ConnectivityBuilder({
    Key? key,
    required this.builder,
    ConnectivityService? connectivityService,
  })  : connectivityService = connectivityService ?? const ConnectivityService._internal(),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: connectivityService,
      builder: (context, _) {
        return builder(context, connectivityService.isConnected);
      },
    );
  }
}
