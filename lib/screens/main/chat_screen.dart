import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../../providers/supabase_user_provider.dart';
import '../../providers/nutrition_provider.dart';
import '../../providers/workout_provider.dart';
import '../../services/grok_service.dart';
import '../../services/chat_session_service.dart';
import '../../services/user_context_builder.dart';
import '../../services/workout_parser.dart';
import '../../models/chat_session.dart';
import '../../models/workout_template.dart';
import '../../utils/app_theme.dart';
import '../../widgets/interactive_workout_card.dart';
import '../workout/active_workout_screen.dart';
import 'dart:async';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatSessionService _sessionService = ChatSessionService();
  final GrokService _grokService = GrokService();

  bool _isTyping = false;
  bool _showWelcomeScreen = true;
  bool _showHistoryPanel = false;
  List<ChatSession> _chatHistory = [];
  List<ChatMessage> _messages = []; // Local state for messages
  Timer? _sessionTimer;
  List<String> _currentSuggestions = [];

  // Quick workout prompts - 2-word labels with detailed prompts and unique icons
  final List<Map<String, dynamic>> _quickWorkoutPrompts = [
    {
      'label': 'Quick Burn',
      'prompt': 'Generate a 15-minute high-intensity workout I can do right now without any equipment',
      'icon': Icons.local_fire_department, // Fire icon for Quick Burn
    },
    {
      'label': 'Strength Focus',
      'prompt': 'Create a comprehensive strength training workout targeting major muscle groups with proper form instructions',
      'icon': Icons.fitness_center, // Dumbbell icon for Strength
    },
    {
      'label': 'Cardio Blast',
      'prompt': 'Design an effective cardio-focused workout to boost my endurance and burn calories',
      'icon': Icons.directions_run, // Running icon for Cardio
    },
    {
      'label': 'Core Power',
      'prompt': 'Give me an effective core and abs workout routine with exercises that target all core muscles',
      'icon': Icons.self_improvement, // Meditation/core icon
    },
    {
      'label': 'Full Body',
      'prompt': 'Create a complete full-body workout routine for today that hits all major muscle groups',
      'icon': Icons.accessibility_new, // Full body icon
    },
    {
      'label': 'Recovery Day',
      'prompt': 'Suggest a light recovery workout with stretching, mobility exercises, and foam rolling guidance',
      'icon': Icons.spa, // Spa/relaxation icon for Recovery
    },
    {
      'label': 'Upper Body',
      'prompt': 'Generate an upper body workout focusing on arms, chest, shoulders, and back with detailed exercise instructions',
      'icon': Icons.sports_martial_arts, // Upper body strength icon
    },
    {
      'label': 'Leg Day',
      'prompt': 'Create an intense leg and glute workout routine with progressive exercises for strength building',
      'icon': Icons.downhill_skiing, // Leg/skiing icon for Leg Day
    },
  ];

  // Animation controllers
  late AnimationController _historyAnimationController;
  late Animation<double> _historyAnimation;

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _setupAnimations();
    _startSessionTimer();
  }

  void _setupAnimations() {
    _historyAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _historyAnimation = CurvedAnimation(
      parent: _historyAnimationController,
      curve: Curves.easeInOut,
    );
  }

  void _startSessionTimer() {
    // Auto-save session every 5 minutes if active
    _sessionTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_sessionService.hasActiveSession && _sessionService.currentMessages.isNotEmpty) {
        _autoSaveSession();
      }
    });
  }

  Future<void> _autoSaveSession() async {
    // This is a placeholder for auto-save functionality
    // In production, you might want to save drafts or partial sessions
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _historyAnimationController.dispose();
    _sessionTimer?.cancel();

    // End session if still active
    if (_sessionService.hasActiveSession) {
      _sessionService.endSession();
    }
    super.dispose();
  }

  void _initializeChat() async {
    final userProvider = Provider.of<SupabaseUserProvider>(context, listen: false);
    if (userProvider.userProfile != null) {
      await _loadChatHistory();
      // Sync messages from service if any exist
      if (mounted) {
        setState(() {
          _messages = List.from(_sessionService.currentMessages);
        });
      }
    }
  }

  Future<void> _loadChatHistory() async {
    final userProvider = Provider.of<SupabaseUserProvider>(context, listen: false);
    final userId = userProvider.currentUser?.id;
    if (userId != null) {
      final history = await _sessionService.getUserChatHistory(userId);
      if (mounted) {
        setState(() {
          _chatHistory = history;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toggleHistoryPanel() {
    if (!mounted) return;
    setState(() {
      _showHistoryPanel = !_showHistoryPanel;
      if (_showHistoryPanel) {
        _historyAnimationController.forward();
        _loadChatHistory(); // Refresh history when opened
      } else {
        _historyAnimationController.reverse();
      }
    });
  }

  Future<void> _startNewChat() async {
    final userProvider = Provider.of<SupabaseUserProvider>(context, listen: false);
    final userId = userProvider.currentUser?.id;
    if (userId == null) return;

    // End current session if exists
    if (_sessionService.hasActiveSession) {
      await _sessionService.endSession();
    }

    // Start new session
    await _sessionService.startNewSession(userId);

    if (mounted) {
      setState(() {
        _showWelcomeScreen = false;
        _showHistoryPanel = false;
        _messages = []; // Clear messages for new session
      });
    }
  }

  Future<void> _sendMessage([String? presetMessage]) async {
    final messageText = presetMessage ?? _messageController.text.trim();
    if (messageText.isEmpty) return;

    final userProvider = Provider.of<SupabaseUserProvider>(context, listen: false);
    final userId = userProvider.currentUser?.id;
    if (userId == null) return;

    // Start session if not already started
    if (!_sessionService.hasActiveSession) {
      await _sessionService.startNewSession(userId);
    }

    // Hide welcome screen when first message is sent
    if (_showWelcomeScreen && mounted) {
      setState(() {
        _showWelcomeScreen = false;
      });
    }

    // Add user message
    final userMessage = ChatMessage(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      message: messageText,
      isUser: true,
      timestamp: DateTime.now(),
    );

    _sessionService.addMessage(userMessage);

    if (mounted) {
      setState(() {
        _messages.add(userMessage); // Update local state
        _isTyping = true;
        _currentSuggestions.clear(); // Clear suggestions when user sends message
      });
    }

    _messageController.clear();
    _scrollToBottom();

    // Generate AI response
    final aiResponse = await _generateAIResponse(messageText);

    final aiMessage = ChatMessage(
      id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
      message: aiResponse,
      isUser: false,
      timestamp: DateTime.now(),
    );

    _sessionService.addMessage(aiMessage);

    if (mounted) {
      setState(() {
        _messages.add(aiMessage); // Update local state
        _isTyping = false;
        _currentSuggestions = _generateSuggestions(aiResponse); // Generate suggestions
      });
    }

    _scrollToBottom();
  }

  Future<String> _generateAIResponse(String userMessage) async {
    try {
      final userProvider = Provider.of<SupabaseUserProvider>(context, listen: false);

      // Build comprehensive user context
      final comprehensiveContext = UserContextBuilder.buildComprehensiveContext(context);

      // Get recent chat context from database
      String recentContext = '';
      final userId = userProvider.currentUser?.id;
      if (userId != null) {
        try {
          recentContext = await _sessionService.getUserContext(userId);
        } catch (e) {
          print('Warning: Could not load user context: $e');
          // Continue without context rather than failing
        }
      }

      // Generate personalized system prompt with recent context
      final personalizedPrompt = '''
${UserContextBuilder.generatePersonalizedSystemPrompt(comprehensiveContext)}

$recentContext
''';

      // Build conversation history from current session
      final conversationHistory = <Map<String, String>>[];
      // Use local messages instead of service messages for history
      final startIndex = _messages.length > 10 ? _messages.length - 10 : 0;

      for (int i = startIndex; i < _messages.length; i++) {
        final msg = _messages[i];
        conversationHistory.add({
          'role': msg.isUser ? 'user' : 'assistant',
          'content': msg.message,
        });
      }

      // Call GROK API with personalized context
      final response = await _grokService.sendMessage(
        userMessage: userMessage,
        conversationHistory: conversationHistory,
        personalizedSystemPrompt: personalizedPrompt,
      );

      return response;
    } catch (e) {
      print('Error generating AI response: $e');
      // Return a helpful fallback message instead of crashing
      return "I'm having trouble connecting right now, but I'm still here to help! Feel free to ask me about nutrition, workouts, or any fitness questions. I'll do my best to assist you! 💪\n\nError: ${e.toString().split('\n').first}";
    }
  }

  List<String> _generateSuggestions(String aiResponse) {
    final suggestions = <String>[];
    final lowercaseResponse = aiResponse.toLowerCase();

    // Generate contextual suggestions based on AI response content
    if (lowercaseResponse.contains('workout') || lowercaseResponse.contains('exercise')) {
      suggestions.addAll([
        'Can you create a detailed workout plan?',
        'How do I track my workout progress?',
        'What exercises are best for beginners?',
      ]);
    } else if (lowercaseResponse.contains('nutrition') || lowercaseResponse.contains('diet')) {
      suggestions.addAll([
        'Help me plan my meals for the week',
        'What are good protein sources?',
        'How do I calculate my daily calories?',
      ]);
    } else if (lowercaseResponse.contains('weight') || lowercaseResponse.contains('loss') || lowercaseResponse.contains('gain')) {
      suggestions.addAll([
        'How fast is healthy weight loss?',
        'What should I eat to gain muscle?',
        'How do I track my progress?',
      ]);
    } else {
      // Default suggestions
      suggestions.addAll([
        'Create a workout plan for today',
        'Give me nutrition advice',
        'Help me stay motivated',
      ]);
    }

    // Limit to 3 suggestions and shuffle for variety
    suggestions.shuffle();
    return suggestions.take(3).toList();
  }

  Future<void> _endCurrentSession() async {
    if (!_sessionService.hasActiveSession) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryAccent),
        ),
      ),
    );

    try {
      await _sessionService.endSession();
      await _loadChatHistory();

      if (mounted) {
        Navigator.pop(context); // Remove loading indicator
        setState(() {
          _showWelcomeScreen = true;
          _messages = []; // Clear messages after saving
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat session saved successfully!'),
            backgroundColor: AppTheme.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Remove loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save session: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Widget _buildWelcomeScreen() {
    final userProvider = Provider.of<SupabaseUserProvider>(context);
    final profile = userProvider.userProfile;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    String userName = 'there';
    if (profile?.name != null && profile!.name.trim().isNotEmpty) {
      final fullName = profile.name.trim();
      userName = fullName.split(' ').first;
      if (userName.isNotEmpty) {
        userName = userName[0].toUpperCase() + userName.substring(1).toLowerCase();
      }
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDarkMode
              ? [AppTheme.darkBackground, AppTheme.darkCardBackground]
              : [AppTheme.backgroundLight, AppTheme.cardBackgroundLight],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // App Bar with History Button
            _buildAppBar(isDarkMode),

            // Main content - Greeting positioned in middle-left
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 24, top: 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Greeting with highlighted name
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Hello ',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                          ),
                          TextSpan(
                            text: '$userName!',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryAccent, // Orange/coral highlight
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Ready to ignite your fitness journey?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                        height: 1.3,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Input area
            _buildInputArea(isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildChatScreen() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    // Use local state messages instead of service messages

    return Container(
      color: isDarkMode ? AppTheme.darkBackground : AppTheme.backgroundLight,
      child: SafeArea(
        child: Column(
          children: [
            // App Bar
            _buildAppBar(isDarkMode),

            // Messages area
            Expanded(
              child: _messages.isEmpty && !_isTyping
                ? Center(
                    child: Text(
                      'Start a conversation...',
                      style: TextStyle(
                        color: isDarkMode ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isTyping ? 1 : 0) + (_currentSuggestions.isNotEmpty && !_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _isTyping) {
                        return _buildTypingIndicator();
                      }

                      if (index == _messages.length + (_isTyping ? 1 : 0) && _currentSuggestions.isNotEmpty && !_isTyping) {
                        return _buildSuggestions();
                      }

                      final message = _messages[index];
                      return _buildMessageBubble(message);
                    },
                  ),
            ),

            // Session info bar
            if (_sessionService.hasActiveSession)
              _buildSessionInfoBar(isDarkMode),

            // Input area
            _buildInputArea(isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkCardBackground : AppTheme.cardBackgroundLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SvgPicture.asset(
              'assets/images/streaker_logo.svg',
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Streaker AI Coach',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                  ),
                ),
                Text(
                  _sessionService.hasActiveSession
                      ? 'Session ${_sessionService.currentSession?.sessionNumber ?? 1} • ${_messages.length} messages'
                      : 'Your fitness assistant',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // History button
          IconButton(
            icon: Icon(
              _showHistoryPanel ? Icons.close : Icons.history,
              color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
            ),
            onPressed: _toggleHistoryPanel,
            tooltip: 'Chat History',
          ),

          // End session button
          if (_sessionService.hasActiveSession)
            IconButton(
              icon: const Icon(Icons.save_alt, color: AppTheme.primaryAccent),
              onPressed: _endCurrentSession,
              tooltip: 'End & Save Session',
            ),
        ],
      ),
    );
  }

  Widget _buildSessionInfoBar(bool isDarkMode) {
    final duration = _sessionService.sessionDuration;
    final durationText = duration != null
        ? '${duration.inMinutes} min ${duration.inSeconds % 60} sec'
        : '0 min';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode
            ? AppTheme.darkCardBackground.withOpacity(0.5)
            : AppTheme.cardBackgroundLight.withOpacity(0.5),
        border: Border(
          top: BorderSide(
            color: isDarkMode
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Session Duration: $durationText',
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
            ),
          ),
          TextButton.icon(
            icon: const Icon(Icons.save, size: 16),
            label: const Text('Save & End'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryAccent,
              textStyle: const TextStyle(fontSize: 12),
            ),
            onPressed: _endCurrentSession,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPromptsScroller(bool isDarkMode) {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _quickWorkoutPrompts.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final prompt = _quickWorkoutPrompts[index];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _sendMessage(prompt['prompt'] as String),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? AppTheme.darkCardBackground
                      : AppTheme.cardBackgroundLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.primaryAccent.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryAccent.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        prompt['icon'] as IconData, // Use custom icon for each prompt
                        size: 14,
                        color: AppTheme.primaryAccent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      prompt['label'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode
                            ? AppTheme.textPrimaryDark
                            : AppTheme.textPrimary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputArea(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkCardBackground : Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quick prompts horizontal scroller
          _buildQuickPromptsScroller(isDarkMode),

          // Input row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Ask me anything about fitness...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: isDarkMode
                        ? AppTheme.darkBackground
                        : Theme.of(context).scaffoldBackgroundColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: _isTyping ? null : _sendMessage,
                  icon: const Icon(
                    Icons.send,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Try to parse workout if it's an AI message
    WorkoutTemplate? workout;
    if (!isUser) {
      final userProvider = Provider.of<SupabaseUserProvider>(context, listen: false);
      final userId = userProvider.currentUser?.id;
      if (userId != null) {
        workout = WorkoutParser().parseWithCleaning(message.message, userId);
      }
    }

    // Check if AI message contains workout-related content
    final bool hasWorkoutContent = !isUser && _containsWorkoutKeywords(message.message);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User/AI header
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: isUser ? null : AppTheme.primaryGradient,
                    color: isUser ? Colors.grey[600] : null,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    isUser ? Icons.person : Icons.psychology,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isUser ? 'You' : 'Streaker AI',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // Message content - Display interactive workout card if workout detected
          if (workout != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: InteractiveWorkoutCard(
                workout: workout!,
                onStartWorkout: () => _startWorkout(workout!),
                onSaveTemplate: () => _saveWorkoutTemplate(workout!),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: isUser
                  ? Text(
                      message.message,
                      style: TextStyle(
                        color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    )
                  : MarkdownBody(
                      data: message.message,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                          fontSize: 15,
                          height: 1.5,
                        ),
                        h1: TextStyle(
                          color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        h2: TextStyle(
                          color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        listBullet: TextStyle(
                          color: AppTheme.primaryAccent,
                          fontSize: 15,
                        ),
                        strong: TextStyle(
                          color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),

          // Manual "Start Workout" button for AI messages with workout content
          if (workout == null && hasWorkoutContent)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
              child: OutlinedButton.icon(
                onPressed: () => _showManualWorkoutDialog(message.message),
                icon: const Icon(Icons.fitness_center, size: 18),
                label: const Text('Convert to Interactive Workout'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryAccent,
                  side: BorderSide(color: AppTheme.primaryAccent, width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Detect if message contains workout-related keywords
  bool _containsWorkoutKeywords(String message) {
    final lower = message.toLowerCase();
    final workoutKeywords = [
      'workout',
      'exercise',
      'sets',
      'reps',
      'repetitions',
      'training',
      'push-up',
      'pull-up',
      'squat',
      'deadlift',
      'bench press',
      'plank',
      'lunge',
      'curl',
      'dumbbell',
      'barbell',
      'cardio',
      'hiit',
      'strength',
      'muscle',
      'rest period',
      'warm up',
      'cool down',
    ];

    return workoutKeywords.any((keyword) => lower.contains(keyword));
  }

  /// Parse exercise names and details from AI text response
  List<TemplateExercise> _parseExercisesFromText(String aiResponse) {
    final exercises = <TemplateExercise>[];

    // Common exercise patterns in AI responses
    final exercisePatterns = [
      // Pattern: "1. Push-ups" or "1) Push-ups" or "- Push-ups"
      RegExp(r'(?:^|\n)[\d\-\*•]+[\.\)]\s*([A-Z][a-zA-Z\s\-]+?)(?:\s*[-–:]|\s*\(|\s*\n|$)', multiLine: true),
      // Pattern: "Push-ups:" or "Push-ups -"
      RegExp(r'(?:^|\n)([A-Z][a-zA-Z\s\-]+?)(?:\s*[-–:])\s*(?:\d+|for)', multiLine: true),
      // Pattern: Exercise names followed by sets/reps info
      RegExp(r'(?:^|\n)([A-Z][a-zA-Z\s\-]+?)(?:\s*[-–:]\s*)?(?:\d+\s*(?:sets|x|×))', multiLine: true, caseSensitive: false),
    ];

    final foundExercises = <String>{};  // Use Set to avoid duplicates

    for (final pattern in exercisePatterns) {
      final matches = pattern.allMatches(aiResponse);
      for (final match in matches) {
        if (match.groupCount > 0) {
          final exerciseName = match.group(1)?.trim();
          if (exerciseName != null && exerciseName.length > 3 && exerciseName.length < 50) {
            // Filter out common false positives
            final lowerName = exerciseName.toLowerCase();
            if (!lowerName.contains('workout') &&
                !lowerName.contains('minute') &&
                !lowerName.contains('circuit') &&
                !lowerName.contains('round') &&
                !lowerName.startsWith('for ') &&
                !lowerName.startsWith('to ') &&
                !lowerName.startsWith('the ')) {
              foundExercises.add(exerciseName);
            }
          }
        }
      }
    }

    // Convert found exercise names to TemplateExercise objects
    for (final exerciseName in foundExercises.take(10)) {  // Limit to 10 exercises
      // Try to extract sets/reps information from context
      final exerciseContext = _extractExerciseContext(aiResponse, exerciseName);

      exercises.add(TemplateExercise(
        name: exerciseName,
        sets: exerciseContext['sets'] ?? 3,
        reps: exerciseContext['reps'] ?? 10,
        restSeconds: exerciseContext['rest'] ?? 60,
        weightKg: null,
        notes: exerciseContext['notes'] ?? 'See AI suggestions above for details',
        muscleGroups: [],
      ));
    }

    print('🏋️ Parsed ${exercises.length} exercises from AI response');
    for (final ex in exercises) {
      print('   - ${ex.name}: ${ex.sets}×${ex.reps}, ${ex.restSeconds}s rest');
    }

    return exercises;
  }

  /// Extract exercise context (sets, reps, rest) from surrounding text
  Map<String, dynamic> _extractExerciseContext(String text, String exerciseName) {
    final context = <String, dynamic>{};

    // Find the section of text containing this exercise
    final exerciseIndex = text.toLowerCase().indexOf(exerciseName.toLowerCase());
    if (exerciseIndex == -1) return context;

    // Look at ~200 characters around the exercise name
    final start = (exerciseIndex - 50).clamp(0, text.length);
    final end = (exerciseIndex + 150).clamp(0, text.length);
    final section = text.substring(start, end).toLowerCase();

    // Extract sets
    final setsMatch = RegExp(r'(\d+)\s*(?:sets|x|×)').firstMatch(section);
    if (setsMatch != null) {
      context['sets'] = int.tryParse(setsMatch.group(1)!) ?? 3;
    }

    // Extract reps
    final repsMatch = RegExp(r'(?:x|×)\s*(\d+)|(\d+)\s*reps?').firstMatch(section);
    if (repsMatch != null) {
      context['reps'] = int.tryParse(repsMatch.group(1) ?? repsMatch.group(2)!) ?? 10;
    }

    // Extract rest time
    final restMatch = RegExp(r'(\d+)\s*(?:sec|second)s?\s*rest').firstMatch(section);
    if (restMatch != null) {
      context['rest'] = int.tryParse(restMatch.group(1)!) ?? 60;
    }

    return context;
  }

  void _startWorkout(WorkoutTemplate workout) {
    final userProvider = Provider.of<SupabaseUserProvider>(context, listen: false);
    final userId = userProvider.currentUser?.id;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to start workout')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActiveWorkoutScreen(
          template: workout,
          userId: userId,
        ),
      ),
    );
  }

  Future<void> _saveWorkoutTemplate(WorkoutTemplate workout) async {
    final workoutProvider = Provider.of<WorkoutProvider>(context, listen: false);

    try {
      await workoutProvider.saveTemplate(workout);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Workout template saved successfully!'),
            backgroundColor: AppTheme.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save template: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  /// Show dialog to manually create workout from AI text response
  void _showManualWorkoutDialog(String aiResponse) {
    final userProvider = Provider.of<SupabaseUserProvider>(context, listen: false);
    final userId = userProvider.currentUser?.id;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to create workouts')),
      );
      return;
    }

    final TextEditingController nameController = TextEditingController(text: 'Custom Workout');
    final TextEditingController typeController = TextEditingController(text: 'Strength');
    final TextEditingController durationController = TextEditingController(text: '30');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create Workout'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create an interactive workout based on the AI response:',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Workout Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: typeController,
                  decoration: const InputDecoration(
                    labelText: 'Type (e.g., Strength, Cardio, HIIT)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: durationController,
                  decoration: const InputDecoration(
                    labelText: 'Estimated Duration (minutes)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'You\'ll be able to add exercises and customize the workout in the next screen.',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _createManualWorkout(
                  userId: userId,
                  name: nameController.text.trim(),
                  type: typeController.text.trim(),
                  duration: int.tryParse(durationController.text) ?? 30,
                  aiResponse: aiResponse,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Create Workout'),
            ),
          ],
        );
      },
    );
  }

  /// Create a manual workout template from user input
  void _createManualWorkout({
    required String userId,
    required String name,
    required String type,
    required int duration,
    required String aiResponse,
  }) {
    // Parse exercises from AI response text
    final exercises = _parseExercisesFromText(aiResponse);

    // If no exercises were parsed, use generic placeholders
    final List<TemplateExercise> workoutExercises = exercises.isEmpty
        ? [
            TemplateExercise(
              name: 'Exercise 1',
              sets: 3,
              reps: 10,
              restSeconds: 60,
              weightKg: null,
              notes: 'Replace with actual exercise from AI suggestions above',
              muscleGroups: [],
            ),
            TemplateExercise(
              name: 'Exercise 2',
              sets: 3,
              reps: 10,
              restSeconds: 60,
              weightKg: null,
              notes: 'Replace with actual exercise from AI suggestions above',
              muscleGroups: [],
            ),
            TemplateExercise(
              name: 'Exercise 3',
              sets: 3,
              reps: 10,
              restSeconds: 60,
              weightKg: null,
              notes: 'Replace with actual exercise from AI suggestions above',
              muscleGroups: [],
            ),
          ]
        : exercises;

    // Create a basic workout template with parsed or placeholder exercises
    final workout = WorkoutTemplate(
      id: '',
      userId: userId,
      name: name.isEmpty ? 'Custom Workout' : name,
      workoutType: type.isEmpty ? 'Strength' : type,
      estimatedDurationMinutes: duration,
      difficultyLevel: 'Intermediate',
      equipmentNeeded: ['Bodyweight'],
      exercises: workoutExercises,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isFavorite: false,
      source: 'ai',  // Mark as AI-generated workout
    );

    // Show the workout card in a bottom sheet with options
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Content
                  Expanded(
                    child: ListView(
                      controller: controller,
                      padding: const EdgeInsets.all(20),
                      children: [
                        const Text(
                          'Workout Created',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your workout has been created with placeholder exercises. You can customize them during the workout.',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 20),
                        InteractiveWorkoutCard(
                          workout: workout,
                          onStartWorkout: () {
                            Navigator.pop(context);
                            _startWorkout(workout);
                          },
                          // Removed onSaveTemplate - save functionality disabled for now
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.lightbulb, color: Colors.blue, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'AI Suggestions:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                aiResponse,
                                style: const TextStyle(fontSize: 13),
                                maxLines: 8,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTypingIndicator() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.psychology,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDarkMode ? AppTheme.darkCardBackground : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryAccent),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Thinking...',
                  style: TextStyle(
                    color: isDarkMode ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 16, left: 16, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 16,
                color: isDarkMode ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Suggestions',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _currentSuggestions.map((suggestion) =>
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    _sendMessage(suggestion);
                    setState(() {
                      _currentSuggestions.clear(); // Clear suggestions after use
                    });
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.2)
                            : Colors.black.withOpacity(0.1),
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      suggestion,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
              )
            ).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPromptChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(25),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: isDarkMode
                ? AppTheme.darkCardBackground
                : AppTheme.cardBackgroundLight,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: AppTheme.primaryAccent.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryAccent.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: AppTheme.primaryAccent,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode
                      ? AppTheme.textPrimaryDark
                      : AppTheme.textPrimary,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernTopicTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDarkMode,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDarkMode
                ? AppTheme.darkCardBackground
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.08)
                  : Colors.grey.withOpacity(0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode
                      ? AppTheme.textPrimaryDark
                      : AppTheme.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isDarkMode
                      ? AppTheme.textSecondaryDark.withOpacity(0.7)
                      : AppTheme.textSecondary.withOpacity(0.7),
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopicCard({
    required IconData icon,
    required String title,
    required String description,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 95,
            height: 95,
            child: Stack(
              children: [
                // Main 3D card container
                Container(
                  width: 95,
                  height: 95,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      // Deep shadow for 3D effect
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                        spreadRadius: -5,
                      ),
                      // Mid shadow
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                        spreadRadius: -2,
                      ),
                      // Close shadow
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: gradient,
                      borderRadius: BorderRadius.circular(24),
                      // Inner highlight for 3D effect
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        // Inner glow gradient overlay
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.1),
                            Colors.transparent,
                            Colors.black.withOpacity(0.05),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 3D Icon container
                            Container(
                              width: 35,
                              height: 35,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.3),
                                    Colors.white.withOpacity(0.1),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.1),
                                    blurRadius: 1,
                                    offset: const Offset(0, -1),
                                  ),
                                ],
                              ),
                              child: Icon(
                                icon,
                                size: 18,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.3),
                                    offset: const Offset(0, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Title with 3D text effect
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.3,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.5),
                                    offset: const Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            // Description
                            Text(
                              description,
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.white.withOpacity(0.9),
                                height: 1.2,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.3),
                                    offset: const Offset(0, 1),
                                    blurRadius: 1,
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Alternative chip-style layout inspired by Image #3
  Widget _buildTopicChips(bool isDarkMode) {
    final topics = [
      {'icon': Icons.fitness_center, 'title': 'Strength Training', 'message': 'Tell me about effective strength training techniques'},
      {'icon': Icons.directions_run, 'title': 'Cardio & Endurance', 'message': 'How can I improve my cardio endurance?'},
      {'icon': Icons.restaurant, 'title': 'Nutrition Tips', 'message': 'What nutrition tips do you have for my goals?'},
      {'icon': Icons.bedtime, 'title': 'Recovery', 'message': 'How important is recovery and how can I optimize it?'},
      {'icon': Icons.psychology, 'title': 'Mindset', 'message': 'Help me develop a strong fitness mindset'},
      {'icon': Icons.timer, 'title': 'Quick Workout', 'message': 'Give me a 15-minute workout I can do now'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: topics.map((topic) => _buildTopicChip(
          icon: topic['icon'] as IconData,
          title: topic['title'] as String,
          onTap: () => _sendMessage(topic['message'] as String),
          isDarkMode: isDarkMode,
        )).toList(),
      ),
    );
  }

  Widget _buildTopicChip({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.primaryAccent.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryAccent.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Main content
          _showWelcomeScreen && !_sessionService.hasActiveSession
              ? _buildWelcomeScreen()
              : _buildChatScreen(),

          // History panel overlay
          AnimatedBuilder(
            animation: _historyAnimation,
            builder: (context, child) {
              return _showHistoryPanel
                  ? Positioned(
                      top: 0,
                      right: 0,
                      bottom: 0,
                      width: MediaQuery.of(context).size.width * 0.85,
                      child: Transform.translate(
                        offset: Offset(
                          MediaQuery.of(context).size.width * 0.85 * (1 - _historyAnimation.value),
                          0,
                        ),
                        child: _buildHistoryPanel(),
                      ),
                    )
                  : const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryPanel() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkBackground : AppTheme.backgroundLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(-5, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode ? AppTheme.darkCardBackground : AppTheme.cardBackgroundLight,
                border: Border(
                  bottom: BorderSide(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.1),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.history,
                    color: AppTheme.primaryAccent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chat History',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          '${_chatHistory.length} sessions',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _toggleHistoryPanel,
                  ),
                ],
              ),
            ),

            // History list
            Expanded(
              child: _chatHistory.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: isDarkMode
                                ? AppTheme.textSecondaryDark.withOpacity(0.3)
                                : AppTheme.textSecondary.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No chat history yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: isDarkMode ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start a conversation to see it here',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode
                                  ? AppTheme.textSecondaryDark.withOpacity(0.7)
                                  : AppTheme.textSecondary.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _chatHistory.length,
                      itemBuilder: (context, index) {
                        final session = _chatHistory[index];
                        return _buildHistoryItem(session);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(ChatSession session) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Show session details in a dialog
            _showSessionDetails(session);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode ? AppTheme.darkCardBackground : AppTheme.cardBackgroundLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date and sentiment
                Row(
                  children: [
                    Text(
                      session.relativeDateString,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryAccent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      session.formattedTime,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    if (session.userSentiment != null)
                      Text(
                        session.sentimentEmoji,
                        style: const TextStyle(fontSize: 16),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Title
                Text(
                  session.sessionTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Summary
                Text(
                  session.sessionSummary,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Topics
                if (session.topicsDiscussed.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: session.topicsDiscussed.take(3).map((topic) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        topic,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.primaryAccent,
                        ),
                      ),
                    )).toList(),
                  ),

                // Stats
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.message,
                      size: 12,
                      color: isDarkMode ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${session.messageCount} messages',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDarkMode ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (session.durationText.isNotEmpty) ...[
                      Icon(
                        Icons.timer,
                        size: 12,
                        color: isDarkMode ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        session.durationText,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDarkMode ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSessionDetails(ChatSession session) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: isDarkMode ? AppTheme.darkBackground : AppTheme.backgroundLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.3)
                    : Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.sessionTitle,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${session.formattedDate} at ${session.formattedTime}',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                    onPressed: () async {
                      // Confirm deletion
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Session?'),
                          content: const Text('This action cannot be undone.'),
                          actions: [
                            TextButton(
                              child: const Text('Cancel'),
                              onPressed: () => Navigator.pop(context, false),
                            ),
                            TextButton(
                              child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
                              onPressed: () => Navigator.pop(context, true),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await _sessionService.deleteSession(session.id);
                        await _loadChatHistory();
                        if (mounted) {
                          Navigator.pop(context);
                        }
                      }
                    },
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary
                    _buildDetailSection(
                      title: 'Summary',
                      content: session.sessionSummary,
                      icon: Icons.summarize,
                      isDarkMode: isDarkMode,
                    ),

                    // Topics
                    if (session.topicsDiscussed.isNotEmpty)
                      _buildDetailSection(
                        title: 'Topics Discussed',
                        content: session.topicsDiscussed.join(', '),
                        icon: Icons.topic,
                        isDarkMode: isDarkMode,
                      ),

                    // Goals
                    if (session.userGoalsDiscussed != null)
                      _buildDetailSection(
                        title: 'Goals Mentioned',
                        content: session.userGoalsDiscussed!,
                        icon: Icons.flag,
                        isDarkMode: isDarkMode,
                      ),

                    // Recommendations
                    if (session.recommendationsGiven != null)
                      _buildDetailSection(
                        title: 'Recommendations',
                        content: session.recommendationsGiven!,
                        icon: Icons.lightbulb,
                        isDarkMode: isDarkMode,
                      ),

                    // Stats
                    _buildDetailSection(
                      title: 'Session Stats',
                      content: '${session.messageCount} messages • ${session.durationText}',
                      icon: Icons.analytics,
                      isDarkMode: isDarkMode,
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection({
    required String title,
    required String content,
    required IconData icon,
    required bool isDarkMode,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: AppTheme.primaryAccent,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? AppTheme.darkCardBackground
                  : AppTheme.cardBackgroundLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              content,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}