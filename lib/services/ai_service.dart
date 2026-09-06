import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/api_keys.dart';

class AIService {
  final String _apiKey = ApiKeys.deepseekApiKey;
  final String _baseUrl = 'https://api.deepseek.com/chat/completions';
  final List<Map<String, String>> _chatHistory = [];

  static const String _model = 'deepseek-chat';
  static const double _temperature = 0.35;
  static const int _maxTokens = 1200;

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

      const contextualMessage = '''You are Regent AI, a precise academic assistant for Regent University students.

Answer the user's exact question directly and put the answer first. Be concise: normally use 1-3 short paragraphs or at most 6 bullet points. Give only the explanation needed to answer the question. Do not begin with phrases such as "Great question" or a long introduction. Do not add analogies, extra examples, learning resources, repeated conclusions, or unrelated context unless the user asks for them. Use a small table only when it makes a comparison clearer. For calculations or technical questions, show only the necessary steps. Use clear plain language and accurate facts.''';

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
      final prompt = '''$userPrompt

Answer the request directly and concisely. Do not add an introduction, analogy, unrelated examples, or extra study advice unless requested. If it is a calculation, show only the necessary working. If it is text or a diagram, state the key answer first.''';

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
          '''You are Regent AI. Analyze this image and answer directly in a concise format. State the key answer first. Show only necessary working for mathematics and avoid unrelated examples or explanations.''';

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
