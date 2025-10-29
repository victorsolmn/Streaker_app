import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../utils/app_theme.dart';

/// E-commerce Screen with In-App Browser
///
/// Features:
/// - Full WebView integration for seamless shopping experience
/// - Progress indicator during page loads
/// - Pull-to-refresh functionality
/// - Error handling with retry capability
/// - Back/Forward navigation buttons
/// - Share functionality
/// - External browser option
///
/// Recommended URLs to use:
/// - Your Shopify store
/// - Amazon storefront
/// - Custom product catalog
/// - Affiliate links
class EcommerceScreen extends StatefulWidget {
  final String initialUrl;
  final String? title;

  const EcommerceScreen({
    Key? key,
    this.initialUrl = 'https://www.amazon.in/b?node=4951860031', // Fitness products by default
    this.title,
  }) : super(key: key);

  @override
  State<EcommerceScreen> createState() => _EcommerceScreenState();
}

class _EcommerceScreenState extends State<EcommerceScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String _currentUrl = '';
  String _pageTitle = '';
  bool _canGoBack = false;
  bool _canGoForward = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _isLoading = progress < 100;
              });
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
                _currentUrl = url;
              });
            }
          },
          onPageFinished: (String url) async {
            if (mounted) {
              // Get page title
              final title = await _controller.getTitle();
              final canGoBack = await _controller.canGoBack();
              final canGoForward = await _controller.canGoForward();

              setState(() {
                _isLoading = false;
                _pageTitle = title ?? '';
                _canGoBack = canGoBack;
                _canGoForward = canGoForward;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _hasError = true;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  Future<void> _reload() async {
    setState(() {
      _hasError = false;
    });
    await _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDarkMode ? AppTheme.darkCardBackground : Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title ?? 'Shop',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
              ),
            ),
            if (_pageTitle.isNotEmpty && _pageTitle != (widget.title ?? 'Shop'))
              Text(
                _pageTitle,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          // Back button
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              color: _canGoBack ? AppTheme.primaryAccent : AppTheme.textSecondary.withOpacity(0.3),
              size: 20,
            ),
            onPressed: _canGoBack
                ? () => _controller.goBack()
                : null,
            tooltip: 'Go Back',
          ),
          // Forward button
          IconButton(
            icon: Icon(
              Icons.arrow_forward_ios,
              color: _canGoForward ? AppTheme.primaryAccent : AppTheme.textSecondary.withOpacity(0.3),
              size: 20,
            ),
            onPressed: _canGoForward
                ? () => _controller.goForward()
                : null,
            tooltip: 'Go Forward',
          ),
          // Reload button
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: AppTheme.primaryAccent,
            ),
            onPressed: _reload,
            tooltip: 'Reload',
          ),
          // More options
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
            ),
            onSelected: (value) async {
              switch (value) {
                case 'home':
                  await _controller.loadRequest(Uri.parse(widget.initialUrl));
                  break;
                case 'share':
                  // TODO: Implement share functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Share: $_currentUrl')),
                  );
                  break;
                case 'external':
                  // TODO: Open in external browser
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Open in browser: $_currentUrl')),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'home',
                child: Row(
                  children: [
                    Icon(Icons.home, size: 20, color: AppTheme.textSecondary),
                    SizedBox(width: 12),
                    Text('Go to Home'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, size: 20, color: AppTheme.textSecondary),
                    SizedBox(width: 12),
                    Text('Share'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'external',
                child: Row(
                  children: [
                    Icon(Icons.open_in_new, size: 20, color: AppTheme.textSecondary),
                    SizedBox(width: 12),
                    Text('Open in Browser'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // WebView
          if (!_hasError)
            RefreshIndicator(
              onRefresh: _reload,
              color: AppTheme.primaryAccent,
              child: WebViewWidget(controller: _controller),
            ),

          // Error state
          if (_hasError)
            Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppTheme.errorRed.withOpacity(0.5),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Failed to load page',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Please check your internet connection and try again',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _reload,
                      icon: Icon(Icons.refresh),
                      label: Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryAccent,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Loading indicator
          if (_isLoading && !_hasError)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryAccent),
                minHeight: 3,
              ),
            ),
        ],
      ),
    );
  }
}
