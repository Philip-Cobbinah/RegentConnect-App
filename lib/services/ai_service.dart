import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';

import '../core/api_keys.dart';

class AIService {
  late GenerativeModel _model;
  late ChatSession _chatSession;

  AIService() {
    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: ApiKeys.geminiApiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 2048,
      ),
    );

    _chatSession = _model.startChat();
  }

  Future<String> sendMessage(String message) async {
    try {
      final contextualMessage =
          '''You are Regent AI, an intelligent academic assistant for Regent University students.
You have access to real-time information and can provide accurate answers to academic questions.

When answering questions:
1. Provide accurate, detailed information
2. Cite sources when relevant
3. Explain concepts clearly for students
4. Offer practical examples
5. Suggest further learning resources

Be helpful, friendly, and educational in your responses.

User Question: $message''';

      final response = await _chatSession.sendMessage(
        Content.text(contextualMessage),
      );

      if (response.text != null && response.text!.isNotEmpty) {
        return response.text!;
      }
      return 'Sorry, I could not process your question. Please try again.';
    } catch (e) {
      return 'Error: Unable to get response. Please check your API key and '
          'internet connection. Error details: $e';
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
      final prompt = customPrompt ??
          '''You are Regent AI, an academic assistant. Analyze this image and provide a detailed explanation.
If it contains a math problem, solve it step by step with clear working.
If it's a diagram or chart, explain what it shows and provide insights.
Be educational and helpful in your response.''';

      final response = await _chatSession.sendMessage(
        Content.multi([
          TextPart(prompt),
          DataPart(mimeType, imageBytes),
        ]),
      );

      if (response.text != null && response.text!.isNotEmpty) {
        return response.text!;
      }
      return 'Sorry, I could not analyze the image. Please try again.';
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
    _chatSession = _model.startChat();
  }

  List<Content> getChatHistory() {
    return _chatSession.history.toList();
  }

  void clearChatHistory() {
    _chatSession = _model.startChat();
  }
}
