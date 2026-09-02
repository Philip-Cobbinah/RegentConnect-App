import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/theme.dart';
import '../../../services/ai_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/ai_chat_storage_service.dart';

class RegentAIScreen extends StatefulWidget {
  final String? initialPrompt;

  const RegentAIScreen({super.key, this.initialPrompt});

  @override
  State<RegentAIScreen> createState() => _RegentAIScreenState();
}

class _RegentAIScreenState extends State<RegentAIScreen> {
  static const int _maxPromptLength = 65536;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<AIChatMessage> _messages = [];
  final AIService _aiService = AIService();
  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();
  final AIChatStorageService _storageService = AIChatStorageService();
  final Record _audioRecorder = Record();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isLoading = false;
  bool _isLoadingHistory = true;
  bool _limitWarningShown = false;

  // Image preview
  Uint8List? _pendingImageData;
  String? _pendingImageSource;

  // Audio recording
  bool _isRecording = false;
  bool _isPaused = false;
  String? _recordingPath;
  int _recordingDuration = 0;
  Timer? _recordingTimer;

  @override
  void initState() {
    super.initState();
    final initialPrompt = widget.initialPrompt?.trim();
    if (initialPrompt != null && initialPrompt.isNotEmpty) {
      _messageController.text = initialPrompt;
    }
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    setState(() => _isLoadingHistory = true);

    final savedMessages = await _storageService.loadMessages();

    setState(() {
      if (savedMessages.isEmpty) {
        _addWelcomeMessage();
      } else {
        _messages.addAll(savedMessages);
      }
      _isLoadingHistory = false;
    });

    _scrollToBottom();
  }

  void _addWelcomeMessage() {
    final userName = _authService.currentUser?.displayName ?? 'Student';
    _messages.add(AIChatMessage(
      content:
          '''Hi $userName! 👋 I'm **Regent AI**, your personal academic assistant.

I can help you with:
📚 **Academic Questions** - Any subject or topic
💻 **Programming Help** - Code explanations & debugging
📸 **Photo Analysis** - Upload images for solutions
🎤 **Audio Notes** - Record and transcribe your questions
📝 **Study Tips** - Exam prep & learning strategies
🎯 **Career Guidance** - Future planning & advice

How can I assist you today?''',
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  Future<void> _saveMessages() async {
    await _storageService.saveMessages(_messages);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
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

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;
    if (message.length > _maxPromptLength) {
      _showPromptLimitWarning();
      return;
    }

    setState(() {
      _messages.add(AIChatMessage(
        content: message,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _messageController.clear();
      _isLoading = true;
    });

    _scrollToBottom();
    await _saveMessages();

    try {
      final response = await _aiService.sendMessage(message);

      setState(() {
        _messages.add(AIChatMessage(
          content: response,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(AIChatMessage(
          content: 'Sorry, I encountered an error. Please try again.',
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
    }

    await _saveMessages();
    _scrollToBottom();
  }

  // ============ IMAGE METHODS ============

  Future<void> _captureFromCamera() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (image != null) {
        final imageBytes = await image.readAsBytes();
        _showImagePreview(imageBytes, 'camera');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _uploadFromGallery() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        final imageBytes = await image.readAsBytes();
        _showImagePreview(imageBytes, 'gallery');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showImagePreview(Uint8List imageBytes, String source) {
    setState(() {
      _pendingImageData = imageBytes;
      _pendingImageSource = source;
    });
  }

  void _cancelImagePreview() {
    setState(() {
      _pendingImageData = null;
      _pendingImageSource = null;
    });
  }

  Future<void> _sendImageWithMessage() async {
    if (_pendingImageData == null || _isLoading) return;

    final userMessage = _messageController.text.trim();
    if (userMessage.length > _maxPromptLength) {
      _showPromptLimitWarning();
      return;
    }
    final imageData = _pendingImageData!;

    setState(() {
      _messages.add(AIChatMessage(
        content: userMessage.isNotEmpty ? userMessage : 'Analyze this image',
        isUser: true,
        timestamp: DateTime.now(),
        imageData: imageData,
      ));
      _pendingImageData = null;
      _pendingImageSource = null;
      _messageController.clear();
      _isLoading = true;
    });

    _scrollToBottom();
    await _saveMessages();

    try {
      final response = await _aiService.analyzeImage(imageData, 'image/jpeg');

      setState(() {
        _messages.add(AIChatMessage(
          content: response,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(AIChatMessage(
          content: 'Error analyzing image: $e',
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
    }

    await _saveMessages();
    _scrollToBottom();
  }

  void _showPromptLimitWarning() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your message is too long. Regent AI allows up to 65,536 characters.'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  // ============ AUDIO RECORDING METHODS ============

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        _recordingPath =
            '${dir.path}/regent_ai_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          encoder: AudioEncoder.aacLc,
          path: _recordingPath!,
        );

        setState(() {
          _isRecording = true;
          _isPaused = false;
          _recordingDuration = 0;
        });

        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!_isPaused) {
            setState(() => _recordingDuration++);
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting recording: $e')),
      );
    }
  }

  Future<void> _pauseRecording() async {
    await _audioRecorder.pause();
    setState(() => _isPaused = true);
  }

  Future<void> _resumeRecording() async {
    await _audioRecorder.resume();
    setState(() => _isPaused = false);
  }

  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
    await _audioRecorder.stop();

    if (_recordingPath != null) {
      final file = File(_recordingPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    setState(() {
      _isRecording = false;
      _isPaused = false;
      _recordingPath = null;
      _recordingDuration = 0;
    });
  }

  Future<void> _sendRecording() async {
    _recordingTimer?.cancel();
    final path = await _audioRecorder.stop();

    if (path == null) {
      setState(() {
        _isRecording = false;
        _isPaused = false;
        _recordingDuration = 0;
      });
      return;
    }

    final duration = _recordingDuration;

    setState(() {
      _messages.add(AIChatMessage(
        content: '🎤 Voice message (${_formatDuration(duration)})',
        isUser: true,
        timestamp: DateTime.now(),
        audioUrl: path,
        audioDuration: duration,
      ));
      _isRecording = false;
      _isPaused = false;
      _recordingPath = null;
      _recordingDuration = 0;
      _isLoading = true;
    });

    _scrollToBottom();
    await _saveMessages();

    try {
      // Read audio file and send to AI for transcription
      final file = File(path);
      final audioBytes = await file.readAsBytes();

      final response = await _aiService.transcribeAudio(audioBytes);

      setState(() {
        _messages.add(AIChatMessage(
          content: response,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(AIChatMessage(
          content:
              'I received your audio message. Unfortunately, I couldn\'t process it right now. Please try typing your question instead.',
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
    }

    await _saveMessages();
    _scrollToBottom();
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _playAudio(String path) async {
    try {
      await _audioPlayer.play(DeviceFileSource(path));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing audio: $e')),
      );
    }
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RegentColors.dmSurface,
        title: const Text('Clear Chat', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to clear the conversation? This will delete all chat history.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _storageService.clearMessages();
              setState(() {
                _messages.clear();
                _aiService.resetChat();
                _addWelcomeMessage();
              });
              await _saveMessages();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSuggestions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: RegentColors.dmSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Try asking about:',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 16),
            _buildSuggestionTile(
                'Explain the concept of Object-Oriented Programming',
                Icons.code),
            _buildSuggestionTile(
                'What are some effective study techniques for exams?',
                Icons.school),
            _buildSuggestionTile(
                'Help me understand database normalization', Icons.storage),
            _buildSuggestionTile(
                'Analyze this math problem from my photo', Icons.camera_alt),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionTile(String text, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: RegentColors.violet),
      title:
          Text(text, style: const TextStyle(fontSize: 14, color: Colors.white)),
      onTap: () {
        Navigator.pop(context);
        _messageController.text = text;
        _sendMessage();
      },
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RegentColors.dmSurface,
        title: const Row(children: [
          Icon(Icons.smart_toy, color: RegentColors.violet),
          SizedBox(width: 8),
          Text('About Regent AI', style: TextStyle(color: Colors.white))
        ]),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Regent AI is your personal academic assistant powered by advanced AI.',
                style: TextStyle(color: Colors.white70)),
            SizedBox(height: 16),
            Text('Features:',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
            SizedBox(height: 8),
            Text('• Answer academic questions',
                style: TextStyle(color: Colors.white70)),
            Text('• Analyze images (math, diagrams, etc)',
                style: TextStyle(color: Colors.white70)),
            Text('• Transcribe audio notes',
                style: TextStyle(color: Colors.white70)),
            Text('• Help with programming',
                style: TextStyle(color: Colors.white70)),
            Text('• Provide study tips',
                style: TextStyle(color: Colors.white70)),
            Text('• Career guidance', style: TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RegentColors.dmBackground,
      appBar: AppBar(
        backgroundColor: RegentColors.violet,
        elevation: 0,
        title: const Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              child:
                  Icon(Icons.smart_toy, color: RegentColors.violet, size: 20),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Regent AI',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                Text(
                  'Your Academic Assistant',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Tooltip(
            message: 'Clear Chat',
            child: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _clearChat,
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: RegentColors.dmSurface,
            onSelected: (value) {
              if (value == 'suggestions') {
                _showSuggestions();
              } else if (value == 'about') {
                _showAbout();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'suggestions',
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Suggestions', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'about',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white),
                    SizedBox(width: 8),
                    Text('About', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoadingHistory
          ? const Center(
              child: CircularProgressIndicator(color: RegentColors.violet))
          : Column(
              children: [
                // Messages List
                Expanded(
                  child: _messages.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length + (_isLoading ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _messages.length && _isLoading) {
                              return _buildTypingIndicator();
                            }
                            return _buildMessageBubble(_messages[index]);
                          },
                        ),
                ),

                // Quick Actions
                if (_messages.length <= 1 &&
                    _pendingImageData == null &&
                    !_isRecording)
                  _buildQuickActions(),

                // Recording UI
                if (_isRecording) _buildRecordingUI(),

                // Image Preview
                if (_pendingImageData != null && !_isRecording)
                  _buildImagePreview(),

                // Input Field
                if (!_isRecording && _pendingImageData == null)
                  _buildInputField(),
              ],
            ),
    );
  }

  Widget _buildRecordingUI() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RegentColors.dmSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Recording indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _isPaused ? Colors.orange : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _isPaused ? 'Paused' : 'Recording...',
                  style: TextStyle(
                    color: _isPaused ? Colors.orange : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  _formatDuration(_recordingDuration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Recording controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Cancel button
                _buildRecordingButton(
                  icon: Icons.delete,
                  label: 'Cancel',
                  color: Colors.red,
                  onPressed: _cancelRecording,
                ),
                // Pause/Resume button
                _buildRecordingButton(
                  icon: _isPaused ? Icons.play_arrow : Icons.pause,
                  label: _isPaused ? 'Resume' : 'Pause',
                  color: Colors.orange,
                  onPressed: _isPaused ? _resumeRecording : _pauseRecording,
                ),
                // Send button
                _buildRecordingButton(
                  icon: Icons.send,
                  label: 'Send',
                  color: RegentColors.violet,
                  onPressed: _sendRecording,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RegentColors.dmSurface,
        border: Border(top: BorderSide(color: RegentColors.dmCard)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.image, color: RegentColors.violet, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Image ready to send',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: RegentColors.violet),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: _cancelImagePreview,
                tooltip: 'Remove image',
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(_pendingImageData!,
                    width: 80, height: 80, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add a message (optional):',
                        style: TextStyle(fontSize: 12, color: Colors.white54)),
                    const SizedBox(height: 4),
                    Container(
                      decoration: BoxDecoration(
                        color: RegentColors.violet.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: RegentColors.lightViolet.withOpacity(0.75),
                        ),
                      ),
                      child: TextField(
                        controller: _messageController,
                        maxLines: 4,
                        minLines: 1,
                        maxLength: _maxPromptLength,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                        keyboardType: TextInputType.multiline,
                        decoration: const InputDecoration(
                          hintText: 'E.g., "Solve this problem"',
                          hintStyle:
                              TextStyle(fontSize: 12, color: Colors.white38),
                          border: InputBorder.none,
                          counterStyle: TextStyle(color: Colors.white54, fontSize: 10),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: const BoxDecoration(
                    color: RegentColors.violet, shape: BoxShape.circle),
                child: IconButton(
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send, color: Colors.white),
                  onPressed: _isLoading ? null : _sendImageWithMessage,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RegentColors.dmSurface,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Take a photo',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.camera_alt, color: RegentColors.lightViolet),
                  onPressed: _captureFromCamera,
                ),
                IconButton(
                  tooltip: 'Choose an image',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.add_photo_alternate, color: RegentColors.lightViolet),
                  onPressed: _uploadFromGallery,
                ),
              ],
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                    color: RegentColors.violet.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: RegentColors.lightViolet.withOpacity(0.85),
                      width: 1.4,
                    )),
                child: TextField(
                  controller: _messageController,
                  maxLines: 8,
                  minLines: 1,
                  maxLength: _maxPromptLength,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.35,
                  ),
                  cursorColor: RegentColors.lightViolet,
                  enableInteractiveSelection: true,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  onChanged: (value) {
                    if (value.length < _maxPromptLength) {
                      _limitWarningShown = false;
                    } else if (!_limitWarningShown) {
                      _limitWarningShown = true;
                      _showPromptLimitWarning();
                    }
                    setState(() {});
                  },
                  onSubmitted: (_) => _sendMessage(),
                  decoration: const InputDecoration(
                    hintText: 'Ask Regent AI anything...',
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                    counterStyle: TextStyle(color: Colors.white54, fontSize: 10),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Record a voice question',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.mic, color: Colors.redAccent),
                  onPressed: _startRecording,
                ),
                Container(
                  decoration: const BoxDecoration(
                      color: RegentColors.violet, shape: BoxShape.circle),
                  child: IconButton(
                    tooltip: 'Send to Regent AI',
                    visualDensity: VisualDensity.compact,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send, color: Colors.white),
                    onPressed: _isLoading ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(AIChatMessage message) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              radius: 16,
              backgroundColor: RegentColors.violet,
              child: Icon(Icons.smart_toy, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () => _copyMessage(message.content),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isUser ? RegentColors.violet : RegentColors.dmCard,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isUser ? 16 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.imageData != null ||
                        message.imageUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: message.imageData != null
                            ? Image.memory(
                                message.imageData!,
                                width: 200,
                                height: 200,
                                fit: BoxFit.cover,
                              )
                            : Image.network(
                                message.imageUrl!,
                                width: 200,
                                height: 200,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const SizedBox(
                                  width: 200,
                                  height: 120,
                                  child: Center(
                                    child: Icon(Icons.broken_image_outlined),
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (message.audioUrl != null) ...[
                      GestureDetector(
                        onTap: () => _playAudio(message.audioUrl!),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.play_arrow, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                _formatDuration(message.audioDuration ?? 0),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    SelectableText(
                      message.content.replaceAll('**', '').replaceAll('`', ''),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15, height: 1.4),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(message.timestamp),
                      style: TextStyle(
                          fontSize: 10, color: Colors.white.withOpacity(0.6)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: RegentColors.darkViolet,
              child: Text(
                _authService.currentUser?.displayName?[0].toUpperCase() ?? '?',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.smart_toy, size: 80, color: RegentColors.violet),
          SizedBox(height: 24),
          Text('Regent AI',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          SizedBox(height: 8),
          Text('Your intelligent academic assistant',
              style: TextStyle(color: Colors.white54, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const CircleAvatar(
              radius: 16,
              backgroundColor: RegentColors.violet,
              child: Icon(Icons.smart_toy, color: Colors.white, size: 18)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: RegentColors.dmCard,
                borderRadius: BorderRadius.circular(16)),
            child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [_buildDot(0), _buildDot(1), _buildDot(2)]),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (index * 200)),
      builder: (context, value, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
              color: RegentColors.violet.withOpacity(0.3 + (value * 0.7)),
              shape: BoxShape.circle),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    final suggestions = [
      '📚 Explain a concept',
      '💻 Help with code',
      '📝 Study tips',
      '🎯 Career advice'
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: suggestions.map((suggestion) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                label: Text(suggestion,
                    style: const TextStyle(color: Colors.white)),
                backgroundColor: RegentColors.dmCard,
                side: BorderSide(color: RegentColors.violet.withOpacity(0.5)),
                onPressed: () =>
                    _messageController.text = suggestion.substring(2).trim(),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _copyMessage(String content) {
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Message copied to clipboard'),
          duration: Duration(seconds: 1),
          backgroundColor: RegentColors.violet),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

// Add this class at the end of the file
class TrianglePainter extends CustomPainter {
  final double scale;

  TrianglePainter({this.scale = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final scaledSize = Size(size.width * scale, size.height * scale);
    final rect = Rect.fromLTWH(0, 0, scaledSize.width, scaledSize.height);

    // Main violet gradient triangle
    final violetPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF4A148C), // Deep violet
          const Color(0xFF7B1FA2), // Purple
        ],
      ).createShader(rect);

    // Cream accent
    final creamPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          Color(0xFFFFF8E1), // Cream
          Color(0xFFFFECB3), // Light cream
        ],
      ).createShader(rect);

    // Draw rounded triangle shape
    final path = Path();

    const radius = 12.0;
    final centerX = scaledSize.width / 2;

    // Triangle points
    final topPoint = Offset(centerX, 4);
    final bottomLeftPoint = Offset(4, scaledSize.height - 4);
    final bottomRightPoint =
        Offset(scaledSize.width - 4, scaledSize.height - 4);

    path.moveTo(topPoint.dx, topPoint.dy + radius);

    // Top to bottom right
    path.quadraticBezierTo(
      topPoint.dx + radius / 2,
      topPoint.dy,
      topPoint.dx + radius,
      topPoint.dy + radius / 2,
    );
    path.lineTo(bottomRightPoint.dx - radius, bottomRightPoint.dy - radius);

    // Bottom right corner
    path.quadraticBezierTo(
      bottomRightPoint.dx,
      bottomRightPoint.dy - radius / 2,
      bottomRightPoint.dx,
      bottomRightPoint.dy,
    );
    path.quadraticBezierTo(
      bottomRightPoint.dx - radius / 2,
      bottomRightPoint.dy,
      bottomRightPoint.dx - radius,
      bottomRightPoint.dy,
    );

    // Bottom right to bottom left
    path.lineTo(bottomLeftPoint.dx + radius, bottomLeftPoint.dy);

    // Bottom left corner
    path.quadraticBezierTo(
      bottomLeftPoint.dx + radius / 2,
      bottomLeftPoint.dy,
      bottomLeftPoint.dx,
      bottomLeftPoint.dy,
    );
    path.quadraticBezierTo(
      bottomLeftPoint.dx,
      bottomLeftPoint.dy - radius / 2,
      bottomLeftPoint.dx + radius,
      bottomLeftPoint.dy - radius,
    );

    // Bottom left to top
    path.lineTo(topPoint.dx - radius, topPoint.dy + radius / 2);
    path.quadraticBezierTo(
      topPoint.dx - radius / 2,
      topPoint.dy,
      topPoint.dx,
      topPoint.dy + radius,
    );

    path.close();

    // Draw main shape
    canvas.drawPath(path, violetPaint);

    // Draw cream accent triangle (smaller, at top-right)
    final accentPath = Path();
    accentPath.moveTo(scaledSize.width - 8, 16);
    accentPath.lineTo(scaledSize.width - 8, 28);
    accentPath.lineTo(scaledSize.width - 20, 22);
    accentPath.close();

    canvas.drawPath(accentPath, creamPaint);

    // Draw another cream accent (bottom-left)
    final accentPath2 = Path();
    accentPath2.moveTo(12, scaledSize.height - 12);
    accentPath2.lineTo(24, scaledSize.height - 12);
    accentPath2.lineTo(18, scaledSize.height - 22);
    accentPath2.close();

    canvas.drawPath(accentPath2, creamPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
