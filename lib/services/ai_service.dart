import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/api_keys.dart';

class AIService {
  final String _apiKey = ApiKeys.deepseekApiKey;
  final String _baseUrl = 'https://api.deepseek.com/chat/completions';
  final List<Map<String, String>> _chatHistory = [];

  static const String _model = 'deepseek-chat';
  static const double _temperature = 0.7;
  static const int _maxTokens = 2048;

  Future<String> sendMessage(String message) async {
    try {
      if (_apiKey.isEmpty) {
        return 'Error: DeepSeek API key not configured. Please set DEEPSEEK_API_KEY environment variable.';
      }

      // Add user message to history
      _chatHistory.add({
        'role': 'user',
        'content': message,
      });

      final contextualMessage =
          '''You are Regent AI, an intelligent academic assistant for Regent University students.
You have access to real-time information and can provide accurate answers to academic questions.

When answering questions:
1. Provide accurate, detailed information
2. Cite sources when relevant
3. Explain concepts clearly for students
4. Offer practical examples
5. Suggest further learning resources

Be helpful, friendly, and educational in your responses.''';

      final messages = [
        {
          'role': 'system',
          'content': contextualMessage,
        },
        ..._chatHistory,
      ];

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': messages,
          'temperature': _temperature,
          'max_tokens': _maxTokens,
          'stream': false,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final assistantMessage =
            data['choices']?[0]?['message']?['content'] ?? '';

        if (assistantMessage.isNotEmpty) {
          // Add assistant response to history
          _chatHistory.add({
            'role': 'assistant',
            'content': assistantMessage,
          });

          return assistantMessage;
        }
        return 'Sorry, I could not process your question. Please try again.';
      } else if (response.statusCode == 401) {
        return 'Error: Invalid DeepSeek API key. Please check your configuration.';
      } else if (response.statusCode == 429) {
        return 'Error: Rate limit exceeded. Please wait a moment and try again.';
      } else {
        return 'Error: Failed to get response from DeepSeek API. Status: ${response.statusCode}';
      }
    } catch (e) {
      return 'Error: Unable to get response. Please check your API key and internet connection. Error details: $e';
    }
  }

  Future<String> analyzeImageWithPrompt(
    Uint8List imageBytes,
    String mimeType,
    String userPrompt,
  ) async {
    try {
      final prompt = '''
$userPrompt

Please analyze the image and provide a detailed, helpful response based on the user's request.
If it's a math problem, solve it step by step.
If it's a diagram, explain it clearly.
If it's text, read and interpret it.
Be thorough but concise in your explanation.
''';

      return await analyzeImage(imageBytes, mimeType, customPrompt: prompt);
    } catch (e) {
      throw Exception('Failed to analyze image: $e');
    }
  }

  Future<String> analyzeImage(
    Uint8List imageBytes,
    String mimeType, {
    String? customPrompt,
  }) async {
    try {
      if (_apiKey.isEmpty) {
        return 'Error: DeepSeek API key not configured.';
      }

      final prompt = customPrompt ??
          '''You are Regent AI, an academic assistant. Analyze this image and provide a detailed explanation.
If it contains a math problem, solve it step by step with clear working.
If it's a diagram or chart, explain what it shows and provide insights.
Be educational and helpful in your response.''';

      // Convert image bytes to base64
      final base64Image = base64Encode(imageBytes);

      // Determine media type for base64 encoding
      String mediaType = 'image/jpeg';
      if (mimeType.contains('png')) {
        mediaType = 'image/png';
      } else if (mimeType.contains('gif')) {
        mediaType = 'image/gif';
      } else if (mimeType.contains('webp')) {
        mediaType = 'image/webp';
      }

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': prompt,
                },
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:$mediaType;base64,$base64Image',
                  },
                },
              ],
            },
          ],
          'temperature': _temperature,
          'max_tokens': _maxTokens,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['choices']?[0]?['message']?['content'] ?? '';

        if (result.isNotEmpty) {
          return result;
        }
        return 'Sorry, I could not analyze the image. Please try again.';
      } else {
        return 'Error analyzing image: Status ${response.statusCode}';
      }
    } catch (e) {
      return 'Error analyzing image: $e';
    }
  }

  Future<String> transcribeAudio(Uint8List audioBytes) async {
    try {
      return '''I received your audio message! 🎤

Unfortunately, audio transcription requires additional setup. Here's what you can do:

1. **Type your question** - I can help you right away
2. **Take a photo** - If it's about a problem or diagram
3. **Try again later** - Audio features are being enhanced

What would you like help with?''';
    } catch (e) {
      throw Exception('Failed to process audio: $e');
    }
  }

  void resetChat() {
    _chatHistory.clear();
  }

  List<Map<String, String>> getChatHistory() {
    return List.from(_chatHistory);
  }

  void clearChatHistory() {
    _chatHistory.clear();
  }
}
