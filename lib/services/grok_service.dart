import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class GrokService {
  static const String _baseUrl = ApiConfig.grokApiUrl;
  static const String _apiKey = ApiConfig.grokApiKey;
  
  // Optimized system prompt for faster, focused responses
  static const String _systemPrompt = '''
You are Streaker AI, a fitness coach. CRITICAL RULES:

1. **RESPONSE LENGTH**: Maximum 200 words (strictly enforced)
2. **VAGUE QUERIES**: Ask ONE clarifying question if query is unclear
3. **FORMAT**:
   - Direct answer to the specific question asked
   - 2-3 bullet points if needed
   - One follow-up question

4. **FOCUS**: Answer ONLY what was asked, don't add unrelated advice
5. **TONE**: Friendly, concise, actionable

Examples of clarifying questions for vague queries:
- "Want a workout" → "What's your fitness level and available time today?"
- "Help with diet" → "What's your specific goal - weight loss, muscle gain, or energy?"
- "I'm stuck" → "What specific challenge are you facing with your fitness journey?"

**NEVER** provide lengthy explanations or general advice unless specifically requested.''';

  static final GrokService _instance = GrokService._internal();
  factory GrokService() => _instance;
  GrokService._internal();

  Future<String> sendMessage({
    required String userMessage,
    List<Map<String, String>>? conversationHistory,
    Map<String, dynamic>? userContext,
    String? personalizedSystemPrompt,
  }) async {
    print('🤖 GROK API: Starting API call for message: "${userMessage.substring(0, userMessage.length > 50 ? 50 : userMessage.length)}..."');

    // Check if API key is empty
    if (_apiKey.isEmpty) {
      print('🤖 GROK API: API key not configured - returning setup instructions');
      return _getApiKeySetupInstructions();
    }

    // Check for vague queries first (but only if no conversation history)
    if ((conversationHistory == null || conversationHistory.isEmpty) && _isVagueQuery(userMessage)) {
      print('🤖 GROK API: Detected vague query, returning clarifying question');
      return _getClarifyingQuestion(userMessage);
    }

    try {
      // Build messages array with system prompt
      final messages = [
        {
          'role': 'system',
          'content': personalizedSystemPrompt ?? _systemPrompt,
        },
      ];

      // Add user context if provided and no personalized prompt
      if (userContext != null && personalizedSystemPrompt == null) {
        final contextMessage = _buildContextMessage(userContext);
        if (contextMessage.isNotEmpty) {
          messages.add({
            'role': 'system',
            'content': contextMessage,
          });
        }
      }

      // Add conversation history if provided
      if (conversationHistory != null) {
        messages.addAll(conversationHistory);
      }

      // Add current user message
      messages.add({
        'role': 'user',
        'content': userMessage,
      });

      print('🤖 GROK API: Making request to $_baseUrl');
      print('🤖 GROK API: Message count: ${messages.length}');

      // Make API request with timeout
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'model': ApiConfig.grokModel,
              'messages': messages,
              'temperature': ApiConfig.temperature,
              'max_tokens': ApiConfig.maxTokens,
              'top_p': ApiConfig.topP,
              'stream': false,
            }),
          )
          .timeout(
            ApiConfig.apiTimeout,
            onTimeout: () {
              print('🤖 GROK API: Request timed out after ${ApiConfig.apiTimeout.inSeconds} seconds');
              throw TimeoutException('Request timed out', ApiConfig.apiTimeout);
            },
          );

      print('🤖 GROK API: Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        print('🤖 GROK API: SUCCESS - Received AI response: "${content.substring(0, content.length > 100 ? 100 : content.length)}..."');
        return content.trim();
      } else if (response.statusCode == 401) {
        print('🤖 GROK API: AUTH ERROR - Invalid API key');
        return 'API key not configured. Please add your GROK API key to use the AI coach feature.';
      } else if (response.statusCode == 429) {
        print('🤖 GROK API: RATE LIMIT - Too many requests');
        return 'I\'m a bit overwhelmed right now. Please try again in a moment! 😊';
      } else {
        print('🤖 GROK API ERROR: ${response.statusCode} - ${response.body}');
        print('🤖 GROK API: Using fallback response due to API error');
        return _getFallbackResponse(userMessage);
      }
    } on TimeoutException catch (e) {
      print('🤖 GROK API TIMEOUT: $e');
      return _getTimeoutResponse();
    } catch (e) {
      print('🤖 GROK API EXCEPTION: $e');
      print('🤖 GROK API: Using fallback response due to exception');
      return _getFallbackResponse(userMessage);
    }
  }

  String _getTimeoutResponse() {
    return '''I apologize for the delay! The AI service is taking longer than expected.

**Quick Tips While You Wait:**
• Try asking a more specific question
• Check your internet connection
• You can still browse your stats and logs

Feel free to try again in a moment! 💪''';
  }

  bool _isVagueQuery(String message) {
    final vaguePhrases = [
      'help', 'workout', 'diet', 'exercise', 'food', 'nutrition',
      'weight', 'muscle', 'fitness', 'health', 'plan', 'routine',
      'program', 'schedule', 'tips', 'advice', 'motivation', 'stuck'
    ];

    final words = message.toLowerCase().split(' ');

    // Check if message is too short and contains only vague terms
    if (words.length <= 2) {
      for (final word in words) {
        if (vaguePhrases.contains(word)) {
          return true;
        }
      }
    }

    // Check if message is just a single vague word
    if (words.length == 1 && vaguePhrases.contains(words[0])) {
      return true;
    }

    return false;
  }

  String _getClarifyingQuestion(String vagueMessage) {
    final lower = vagueMessage.toLowerCase();

    if (lower.contains('workout') || lower.contains('exercise')) {
      return '''I'd love to help with your workout! To give you the best advice:

**Please tell me:**
• Your fitness level (beginner/intermediate/advanced)?
• How much time do you have today?
• Any specific muscle groups or goals?

Example: "I'm a beginner with 30 minutes for upper body"''';
    }

    if (lower.contains('diet') || lower.contains('nutrition') || lower.contains('food')) {
      return '''I can help with your nutrition! To be more specific:

**What would you like to know?**
• Meal planning for your goals?
• Macro calculations?
• Healthy recipe ideas?
• Pre/post workout nutrition?

Example: "Help me plan high-protein meals for muscle gain"''';
    }

    if (lower.contains('weight')) {
      return '''I can help with weight management! Please clarify:

**Are you looking to:**
• Lose weight? (How much?)
• Gain weight/muscle?
• Maintain current weight?
• Track progress effectively?

Example: "I want to lose 10 pounds in 2 months"''';
    }

    if (lower.contains('stuck') || lower.contains('motivation')) {
      return '''I understand you need support! Let me know:

**What's challenging you?**
• Not seeing results?
• Lost motivation?
• Plateau in progress?
• Need accountability?

Example: "I've hit a plateau in my weight loss"''';
    }

    return '''I'd like to help! Could you be more specific?

**Tell me about:**
• Your current fitness goal
• What you're struggling with
• Your experience level

Example: "I need a strength training plan for beginners"''';
  }

  String _getApiKeySetupInstructions() {
    return '''## 🤖 AI Coach Setup Required

To enable the AI Coach feature, you need to configure your Groq API key.

**📝 Quick Setup Steps:**

1. **Get your FREE API key:**
   • Visit https://console.groq.com/
   • Sign up or log in (it's free!)
   • Go to API Keys section
   • Create a new API key

2. **Add the key to your app:**
   • Open `/lib/config/api_config.dart`
   • Replace `YOUR_GROQ_API_KEY_HERE` with your actual key
   • Restart the app

**✨ Why Groq?**
• Fast AI responses (< 1 second)
• Generous free tier
• Privacy-focused
• High-quality fitness advice

**💪 What you'll get:**
• Personalized workout plans
• Nutrition guidance
• Progress tracking tips
• Motivational support
• Expert fitness knowledge

**Need help?** The setup takes less than 2 minutes and unlocks powerful AI coaching features tailored to your fitness journey!

Meanwhile, you can still use the app's tracking features and view your progress. 📊''';
  }

  String _buildContextMessage(Map<String, dynamic> userContext) {
    final contextParts = <String>[];

    if (userContext['name'] != null) {
      contextParts.add('User name: ${userContext['name']}');
    }

    if (userContext['age'] != null) {
      contextParts.add('Age: ${userContext['age']} years');
    }

    if (userContext['height'] != null) {
      contextParts.add('Height: ${userContext['height']} cm');
    }

    if (userContext['weight'] != null) {
      contextParts.add('Current weight: ${userContext['weight']} kg');
    }

    if (userContext['goal'] != null) {
      contextParts.add('Fitness goal: ${userContext['goal']}');
    }

    if (userContext['activityLevel'] != null) {
      contextParts.add('Activity level: ${userContext['activityLevel']}');
    }

    if (userContext['currentStreak'] != null) {
      contextParts.add('Current streak: ${userContext['currentStreak']} days');
    }

    if (userContext['todayCalories'] != null) {
      contextParts.add('Today\'s calories: ${userContext['todayCalories']}');
    }

    if (userContext['todayProtein'] != null) {
      contextParts.add('Today\'s protein: ${userContext['todayProtein']}g');
    }

    if (userContext['calorieGoal'] != null) {
      contextParts.add('Daily calorie goal: ${userContext['calorieGoal']}');
    }

    if (userContext['proteinGoal'] != null) {
      contextParts.add('Daily protein goal: ${userContext['proteinGoal']}g');
    }

    if (contextParts.isNotEmpty) {
      return 'User context:\n${contextParts.join('\n')}';
    }

    return '';
  }


  String _getFallbackResponse(String userMessage) {
    print('🤖 GROK API: Generating FALLBACK response for: "$userMessage"');
    final lowerMessage = userMessage.toLowerCase();

    // Provide helpful fallback responses for common queries
    if (lowerMessage.contains('diet') || lowerMessage.contains('nutrition')) {
      return '''Great question about nutrition! Here are some general tips:

• Focus on whole, unprocessed foods
• Aim for balanced meals with protein, carbs, and healthy fats
• Stay hydrated with 8-10 glasses of water daily
• Eat plenty of vegetables and fruits
• Listen to your body's hunger and fullness cues

For personalized advice, make sure the AI coach is properly configured!''';
    }

    if (lowerMessage.contains('exercise') || lowerMessage.contains('workout')) {
      return '''Here's a balanced workout approach:

• Strength training: 3-4 times per week
• Cardio: 150 minutes moderate or 75 minutes vigorous weekly
• Include both compound and isolation exercises
• Allow for rest and recovery days
• Progress gradually to avoid injury

Remember to warm up before and cool down after workouts!''';
    }

    if (lowerMessage.contains('weight loss') || lowerMessage.contains('lose weight')) {
      return '''For healthy weight loss:

• Create a moderate calorie deficit (500-750 calories/day)
• Focus on nutrient-dense foods
• Combine cardio and strength training
• Aim for 0.5-1 kg loss per week
• Be patient and consistent
• Track your progress

Remember, sustainable changes beat quick fixes!''';
    }

    if (lowerMessage.contains('muscle') || lowerMessage.contains('gain')) {
      return '''To build muscle effectively:

• Eat adequate protein (1.6-2.2g per kg body weight)
• Progressive overload in training
• Focus on compound movements
• Get 7-9 hours of quality sleep
• Allow muscles time to recover
• Stay consistent with your routine

Building muscle takes time - trust the process!''';
    }

    if (lowerMessage.contains('motivat') || lowerMessage.contains('stuck')) {
      return '''I understand fitness journeys have ups and downs! Remember:

• Progress isn't always linear
• Small consistent actions lead to big results
• Focus on how you feel, not just numbers
• Celebrate non-scale victories
• Find activities you enjoy
• You're stronger than you think!

Every day is a new opportunity. Keep going! 💪''';
    }

    // Generic fallback
    return '''I'm here to help with your fitness journey! While I'm having trouble connecting to my full capabilities right now, I can still offer general advice.

What specific area would you like help with?
• Nutrition and diet
• Exercise and workouts
• Weight management
• Building healthy habits
• Staying motivated

Feel free to ask me anything fitness-related!''';
  }
}