import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/official_accounts.dart';
import '../../../core/current_location.dart';
import '../../../core/theme.dart';
import '../../../services/chat_service.dart';
import '../../../services/call_service.dart';
import '../../../services/notification_service.dart';
import '../../calls/screens/video_call_screen.dart';
import '../../../widgets/active_call_overlay.dart';
import '../widgets/chat_media_viewer.dart';

class DMScreen extends StatefulWidget {
  final String recipientId;
  final String recipientName;
  final String? recipientPhoto;
  final String? highlightMessageId; // New: for search result navigation

  const DMScreen({
    super.key,
    required this.recipientId,
    required this.recipientName,
    this.recipientPhoto,
    this.highlightMessageId,
  });

  @override
  State<DMScreen> createState() => _DMScreenState();
}

class _SwipeReplyMessage extends StatefulWidget {
  const _SwipeReplyMessage({
    required this.isOutgoing,
    required this.onReply,
    required this.child,
  });

  final bool isOutgoing;
  final VoidCallback onReply;
  final Widget child;

  @override
  State<_SwipeReplyMessage> createState() => _SwipeReplyMessageState();
}

class _SwipeReplyMessageState extends State<_SwipeReplyMessage>
    with SingleTickerProviderStateMixin {
  double _offset = 0;
  late final AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        if (mounted) setState(() => _offset = _animation.value);
      });
  }

  void _animateBack() {
    _animation = Tween<double>(begin: _offset, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final replyProgress = (_offset.abs() / 72).clamp(0.0, 1.0);
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        final delta = details.primaryDelta ?? 0;
        final allowed = widget.isOutgoing ? delta < 0 : delta > 0;
        if (allowed || _offset != 0) {
          setState(() {
            _offset = (_offset + delta).clamp(-96.0, 96.0);
          });
        }
      },
      onHorizontalDragEnd: (_) {
        if (_offset.abs() >= 72) widget.onReply();
        _animateBack();
      },
      child: Stack(
        alignment: widget.isOutgoing
            ? Alignment.centerRight
            : Alignment.centerLeft,
        children: [
          Opacity(
            opacity: replyProgress,
            child: Padding(
              padding: EdgeInsets.only(
                right: widget.isOutgoing ? 12 : 0,
                left: widget.isOutgoing ? 0 : 12,
              ),
              child: Icon(
                Icons.reply_rounded,
                color: RegentColors.lightViolet,
                size: 22 + (replyProgress * 4),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(_offset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

class _DMScreenState extends State<DMScreen> {
  final _messageController = TextEditingController();
  final _chatService = ChatService();
  final _callService = CallService();
  final _scrollController = ScrollController();
  final Record _audioRecorder = Record();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isSending = false;
  bool _isStartingCall = false;
  bool _isChatReady = false;
  String? _chatInitializationError;
  bool _isRecording = false;
  int _recordingDuration = 0;
  Timer? _recordingTimer;
  Timer? _typingTimer;
  bool _isTyping = false;

  Map<String, dynamic>? _replyingTo;
  String? _selectedMessageId;

  // Quick reaction emojis
  final List<String> _quickReactions = [
    '👍',
    '❤️',
    '😂',
    '😢',
    '👏',
    '🔥',
    '😮',
    '🎉'
  ];

  final NotificationService _notificationService = NotificationService();
  StreamSubscription? _messageSubscription;
  int _previousMessageCount = 0;

  String? _highlightedMessageId;
  final Map<String, GlobalKey> _messageKeys = {};
  String _wallpaperId = 'midnight';
  Uint8List? _wallpaperImage;

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _loadWallpaper();

    // Add listener for text changes to detect typing
    _messageController.addListener(_onTextChanged);

    // Set highlighted message if coming from search
    if (widget.highlightMessageId != null) {
      _highlightedMessageId = widget.highlightMessageId;
      // Clear highlight after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _highlightedMessageId = null);
        }
      });
    }
  }

  Future<void> _initializeChat() async {
    try {
      await _chatService.ensureChatRoom(widget.recipientId);
      await _chatService.markMessagesAsRead(widget.recipientId);
      _listenForNewMessages();
      if (mounted) {
        setState(() {
          _isChatReady = true;
          _chatInitializationError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isChatReady = false;
          _chatInitializationError = error.toString();
        });
      }
    }
  }

  String get _wallpaperKey =>
      'regent_chat_wallpaper_${_chatService.currentMessagingId}_${widget.recipientId}';

  static const _wallpaperOptions = <String, Color>{
    'midnight': RegentColors.dmBackground,
    'violet': Color(0xFF24143D),
    'ocean': Color(0xFF0B2636),
    'forest': Color(0xFF102C27),
    'charcoal': Color(0xFF202124),
  };

  Color get _wallpaperColor => _wallpaperOptions[_wallpaperId]!;

  String get _wallpaperImageKey => '${_wallpaperKey}_image';

  String get _wallpaperImageAllKey => 'regent_chat_wallpaper_all_image';

  Future<void> _loadWallpaper() async {
    final preferences = await SharedPreferences.getInstance();
    final encodedImage = preferences.getString(_wallpaperImageKey) ??
        preferences.getString(_wallpaperImageAllKey);
    if (encodedImage != null && encodedImage.isNotEmpty) {
      try {
        final image = base64Decode(encodedImage);
        if (mounted) setState(() => _wallpaperImage = image);
      } catch (_) {
        await preferences.remove(_wallpaperImageKey);
      }
      return;
    }
    final wallpaper = preferences.getString(_wallpaperKey) ??
        preferences.getString('regent_chat_wallpaper_all') ??
        'midnight';
    if (mounted && _wallpaperOptions.containsKey(wallpaper)) {
      setState(() => _wallpaperId = wallpaper);
    }
  }

  Future<void> _showWallpaperPicker() async {
    final target = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: RegentColors.dmSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Chat wallpaper',
                  style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('Choose a private wallpaper for this chat or your default for all chats.',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _wallpaperOptions.entries.map((entry) => InkWell(
                  onTap: () => Navigator.pop(sheetContext, 'chat-colour'),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: entry.value,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: entry.key == _wallpaperId
                            ? RegentColors.lightViolet
                            : Colors.white24,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(entry.key[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(sheetContext, 'all-colour'),
                icon: const Icon(Icons.wallpaper_rounded),
                label: const Text('Apply selected colour to all chats'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(sheetContext, 'chat-image'),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Use image for this chat'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(sheetContext, 'all-image'),
                icon: const Icon(Icons.collections_outlined),
                label: const Text('Use image for all chats'),
              ),
            ],
          ),
        ),
      ),
    );
    if (target == null) return;
    if (!mounted) return;

    final applyToAll = target.startsWith('all-');
    if (target.endsWith('image')) {
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const Text('Choose wallpaper image'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, ImageSource.gallery),
              child: const Text('Choose from gallery'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, ImageSource.camera),
              child: const Text('Take a picture'),
            ),
          ],
        ),
      );
      if (source == null) return;
      final image = await ImagePicker().pickImage(source: source, imageQuality: 80);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        applyToAll ? _wallpaperImageAllKey : _wallpaperImageKey,
        base64Encode(bytes),
      );
      await preferences.remove(
        applyToAll ? 'regent_chat_wallpaper_all' : _wallpaperKey,
      );
      if (!mounted) return;
      setState(() {
        _wallpaperImage = bytes;
        _wallpaperId = 'midnight';
      });
      return;
    }

    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Choose wallpaper colour'),
        children: _wallpaperOptions.keys
            .map((id) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(dialogContext, id),
                  child: Row(children: [
                    CircleAvatar(backgroundColor: _wallpaperOptions[id]),
                    const SizedBox(width: 12),
                    Text(id[0].toUpperCase() + id.substring(1)),
                  ]),
                ))
            .toList(),
      ),
    );
    if (selected == null) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      applyToAll ? 'regent_chat_wallpaper_all' : _wallpaperKey,
      selected,
    );
    await preferences.remove(
      applyToAll ? _wallpaperImageAllKey : _wallpaperImageKey,
    );
    if (!mounted) return;
    setState(() {
      _wallpaperId = selected;
      _wallpaperImage = null;
    });
  }

  void _listenForNewMessages() {
    _messageSubscription =
        _chatService.getMessages(widget.recipientId).listen((snapshot) {
      if (snapshot.docs.length > _previousMessageCount &&
          _previousMessageCount > 0) {
        // New message received
        final latestMessage = snapshot.docs.last.data() as Map<String, dynamic>;
        if (latestMessage['senderId'] != _chatService.currentMessagingId) {
          // Play sound only for received messages
          _notificationService.playMessageSound();
        }
      }
      _previousMessageCount = snapshot.docs.length;
    });
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _messageController.removeListener(_onTextChanged);
    _typingTimer?.cancel();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    // Clear typing status when leaving
    _chatService.setTypingStatus(widget.recipientId, false);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_messageController.text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      _chatService.setTypingStatus(widget.recipientId, true);
    }

    // Reset typing timer
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _isTyping = false;
      _chatService.setTypingStatus(widget.recipientId, false);
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await _chatService.sendMessage(
        receiverId: widget.recipientId,
        message: message,
      );
      _scrollToBottom();
    } catch (error) {
      if (mounted) {
        _messageController.text = message;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Message could not be sent: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, imageQuality: 70);
    if (image == null) return;

    final isViewOnce = await _promptViewOnce('photo');
    if (isViewOnce == null) return;

    setState(() => _isSending = true);
    try {
      await _chatService.sendMediaMessage(
        receiverId: widget.recipientId,
        bytes: await image.readAsBytes(),
        type: 'image',
        originalName: image.name,
        contentType: image.mimeType,
        message: '📷 Photo',
        isViewOnce: isViewOnce,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo could not be sent: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);
    if (video == null) return;

    final isViewOnce = await _promptViewOnce('video');
    if (isViewOnce == null) return;

    setState(() => _isSending = true);
    try {
      await _chatService.sendMediaMessage(
        receiverId: widget.recipientId,
        bytes: await video.readAsBytes(),
        type: 'video',
        originalName: video.name,
        contentType: video.mimeType,
        message: '🎬 Video',
        isViewOnce: isViewOnce,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video could not be sent: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;

    final selectedFile = result.files.single;
    final bytes = selectedFile.bytes ??
        (selectedFile.path == null
            ? null
            : await File(selectedFile.path!).readAsBytes());
    if (bytes == null) return;
    setState(() => _isSending = true);
    try {
      await _chatService.sendMediaMessage(
        receiverId: widget.recipientId,
        bytes: bytes,
        type: 'file',
        originalName: selectedFile.name,
        message: '📎 ${selectedFile.name}',
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File could not be sent: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _startRecording() async {
    try {
      if (!await _audioRecorder.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission is required.')),
          );
        }
        return;
      }

      String? path;
      if (!kIsWeb) {
        final temporaryDirectory = await getTemporaryDirectory();
        path =
            '${temporaryDirectory.path}/dm_${DateTime.now().millisecondsSinceEpoch}.m4a';
      }
      await _audioRecorder.start(
        encoder: AudioEncoder.aacLc,
        path: path,
      );
      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
      });
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordingDuration++);
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recording could not start: $error')),
        );
      }
    }
  }

  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
    final path = await _audioRecorder.stop();
    if (path != null && !kIsWeb) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {
        // Browser recordings use temporary blob URLs instead of local files.
      }
    }
    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordingDuration = 0;
      });
    }
  }

  Future<void> _sendRecording() async {
    _recordingTimer?.cancel();
    final duration = _recordingDuration;
    final path = await _audioRecorder.stop();
    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordingDuration = 0;
        _isSending = true;
      });
    }
    if (path == null) {
      if (mounted) setState(() => _isSending = false);
      return;
    }

    try {
      await _chatService.sendMediaMessage(
        receiverId: widget.recipientId,
        bytes: await XFile(path).readAsBytes(),
        message: 'Voice message',
        type: 'audio',
        originalName: 'voice_message.m4a',
        contentType: 'audio/mp4',
        audioDuration: duration,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Voice message could not be sent: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: RegentColors.dmSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Share with this chat',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 4,
                mainAxisSpacing: 18,
                crossAxisSpacing: 8,
                childAspectRatio: 0.82,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _attachmentOption(Icons.camera_alt, 'Camera', () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  }),
                  _attachmentOption(Icons.photo_library, 'Photos', () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  }),
                  _attachmentOption(Icons.description, 'Document', () {
                    Navigator.pop(context);
                    _pickFile();
                  }),
                  _attachmentOption(Icons.location_on, 'Location', () {
                    Navigator.pop(context);
                    _showLocationDialog();
                  }),
                  _attachmentOption(Icons.person_pin, 'Contact', () {
                    Navigator.pop(context);
                    _showContactPicker();
                  }),
                  _attachmentOption(Icons.bolt, 'Quick response', () {
                    Navigator.pop(context);
                    _showQuickResponses();
                  }),
                  _attachmentOption(Icons.poll, 'Poll', () {
                    Navigator.pop(context);
                    _showPollDialog();
                  }),
                  _attachmentOption(Icons.calendar_month, 'Calendar', () {
                    Navigator.pop(context);
                    _showCalendarPicker();
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachmentOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: RegentColors.violet,
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _sendRichMessage({
    required String type,
    required String message,
    Map<String, dynamic>? metadata,
  }) async {
    if (_isSending) return;
    setState(() => _isSending = true);
    try {
      await _chatService.sendMessage(
        receiverId: widget.recipientId,
        message: message,
        type: type,
        metadata: metadata,
      );
      _scrollToBottom();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item could not be sent: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<bool?> _promptViewOnce(String mediaLabel) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send as view once?'),
        content: Text(
          'Do you want to send this $mediaLabel so it can only be opened once?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Send normally'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Send view once'),
          ),
        ],
      ),
    );
  }

  Future<void> _showLocationDialog() async {
    final controller = TextEditingController();
    final location = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Share a location'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.black87),
          decoration: const InputDecoration(
            hintText: 'Enter a place, address, or Maps link',
            prefixIcon: Icon(Icons.location_on),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(dialogContext, '__current__'),
            icon: const Icon(Icons.my_location),
            label: const Text('Current location'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('Share'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (location == null) return;
    if (location == '__current__') {
      await _shareCurrentLocation();
      return;
    }
    await _sendRichMessage(
      type: 'location',
      message: 'Location: $location',
      metadata: {'location': location},
    );
  }

  Future<void> _shareCurrentLocation() async {
    try {
      final position = await getCurrentLocation();
      final mapUrl =
          'https://maps.google.com/?q=${position.latitude},${position.longitude}';
      await _sendRichMessage(
        type: 'location',
        message: 'Current location: $mapUrl',
        metadata: {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'location': mapUrl,
        },
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location could not be shared: $error')),
        );
      }
    }
  }

  void _showContactPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: RegentColors.dmSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.62,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(18),
                child: Row(
                  children: [
                    Icon(Icons.person_pin, color: RegentColors.lightViolet),
                    SizedBox(width: 10),
                    Text(
                      'Share a Regent contact',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: RegentColors.violet,
                        ),
                      );
                    }
                    final users = snapshot.data!.docs
                        .where(
                          (document) =>
                              document.id != _chatService.currentUserId,
                        )
                        .toList();
                    return ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final document = users[index];
                        final data = document.data() as Map<String, dynamic>;
                        final name = (data['fullName'] ??
                                data['displayName'] ??
                                data['email'] ??
                                'Regent user')
                            .toString();
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: RegentColors.violet,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            (data['email'] ?? '').toString(),
                            style: const TextStyle(color: Colors.white60),
                          ),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _sendRichMessage(
                              type: 'contact',
                              message: 'Contact: $name',
                              metadata: {
                                'contactId': document.id,
                                'contactName': name,
                                'contactEmail': data['email'],
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuickResponses() {
    const responses = [
      'Hello! How can I help?',
      'Thank you.',
      'I will get back to you shortly.',
      'Could you please share more details?',
      'That works for me.',
      'Please check and confirm.',
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: RegentColors.dmSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              leading: Icon(Icons.bolt, color: RegentColors.lightViolet),
              title: Text(
                'Quick responses',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                'Choose one, then edit it before sending.',
                style: TextStyle(color: Colors.white60),
              ),
            ),
            for (final response in responses)
              ListTile(
                title: Text(
                  response,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _messageController.text = response;
                  _messageController.selection = TextSelection.collapsed(
                    offset: response.length,
                  );
                  setState(() {});
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPollDialog() async {
    final questionController = TextEditingController();
    final firstOptionController = TextEditingController();
    final secondOptionController = TextEditingController();
    final poll = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create a poll'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: questionController,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(labelText: 'Question'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: firstOptionController,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(labelText: 'Option 1'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: secondOptionController,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(labelText: 'Option 2'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final question = questionController.text.trim();
              final options = [
                firstOptionController.text.trim(),
                secondOptionController.text.trim(),
              ];
              if (question.isNotEmpty &&
                  options.every((option) => option.isNotEmpty)) {
                Navigator.pop(dialogContext, {
                  'question': question,
                  'options': options,
                  'votes': <String, dynamic>{},
                });
              }
            },
            child: const Text('Send poll'),
          ),
        ],
      ),
    );
    questionController.dispose();
    firstOptionController.dispose();
    secondOptionController.dispose();
    if (poll == null) return;
    await _sendRichMessage(
      type: 'poll',
      message: 'Poll: ${poll['question']}',
      metadata: poll,
    );
  }

  Future<void> _showCalendarPicker() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;
    final eventDate = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    final formatted = DateFormat('EEE, d MMM yyyy • h:mm a').format(eventDate);
    await _sendRichMessage(
      type: 'calendar',
      message: 'Calendar: $formatted',
      metadata: {'eventDate': eventDate.toIso8601String()},
    );
  }

  void _showStickerPicker() {
    const stickers = [
      '\u{1F44D}',
      '\u{2764}\u{FE0F}',
      '\u{1F389}',
      '\u{1F525}',
      '\u{1F64C}',
      '\u{1F60A}',
      '\u{1F602}',
      '\u{1F914}',
      '\u{1F44F}',
      '\u{1F680}',
      '\u{1F4AF}',
      '\u{2B50}',
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: RegentColors.dmSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 6,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _createSticker();
                },
                child: const Center(
                  child: Icon(Icons.add_circle_outline,
                      color: RegentColors.lightViolet, size: 32),
                ),
              ),
              for (final sticker in stickers)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _sendRichMessage(
                      type: 'sticker',
                      message: sticker,
                    );
                  },
                  child: Center(
                    child: Text(sticker, style: const TextStyle(fontSize: 34)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createSticker() async {
    final source = await showDialog<ImageSource?>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Create a sticker'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, ImageSource.gallery),
            child: const Text('Create from gallery image'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, ImageSource.camera),
            child: const Text('Take a picture'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, null),
            child: const Text('Create text sticker'),
          ),
        ],
      ),
    );
    if (source != null) {
      final image = await ImagePicker().pickImage(
        source: source,
        imageQuality: 75,
      );
      if (image == null) return;
      setState(() => _isSending = true);
      try {
        await _chatService.sendMediaMessage(
          receiverId: widget.recipientId,
          bytes: await image.readAsBytes(),
          type: 'sticker',
          originalName: image.name,
          contentType: image.mimeType,
          message: 'Photo sticker',
        );
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sticker could not be sent: $error')),
          );
        }
      } finally {
        if (mounted) setState(() => _isSending = false);
      }
      return;
    }

    final controller = TextEditingController();
    final sticker = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create a sticker'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          decoration: const InputDecoration(
            hintText: 'Emoji or short text',
            prefixIcon: Icon(Icons.emoji_emotions_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Send sticker'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (sticker == null || sticker.trim().isEmpty) return;
    await _sendRichMessage(type: 'sticker', message: sticker.trim());
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '$minutes:${remaining.toString().padLeft(2, '0')}';
  }

  void _startCall(bool isVideo) async {
    if (_isStartingCall) return;
    if (OfficialAccounts.isOfficialIdentity(widget.recipientId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Calls to official offices are not available yet. Please use chat.',
          ),
        ),
      );
      return;
    }

    setState(() => _isStartingCall = true);
    try {
      final currentUserData =
          await _chatService.getUserData(_chatService.currentUserId);
      final callerName = currentUserData?['fullName'] ??
          currentUserData?['displayName'] ??
          currentUserData?['email'] ??
          'Regent user';
      final callerPhoto = currentUserData?['photoUrl']?.toString();

      final callId = await _callService.initiateCall(
        receiverId: widget.recipientId,
        receiverName: widget.recipientName,
        callerName: callerName.toString(),
        isVideo: isVideo,
        callerPhoto: callerPhoto,
        receiverPhoto: widget.recipientPhoto,
      );

      if (!mounted) return;
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoCallScreen(
            callId: callId,
            recipientId: widget.recipientId,
            recipientName: widget.recipientName,
            recipientPhoto: widget.recipientPhoto,
            isVideo: isVideo,
          ),
        ),
      );
      if (result is Map && result['minimized'] == true) {
        final callData = result['callData'];
        if (callData is Map<String, dynamic>) {
          activeCallOverlayKey.currentState?.setMinimizedCall(callData);
        }
      }
    } on CallException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The call could not be started. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isStartingCall = false);
    }
  }

  String _formatMessageTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    final time =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString().padLeft(4, '0');

    if (messageDate == today) {
      return time;
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday $time';
    } else if (now.difference(date).inDays < 7) {
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${days[date.weekday - 1]} $time';
    } else {
      return '$day/$month/$year $time';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RegentColors.dmBackground,
      appBar: AppBar(
        backgroundColor: RegentColors.dmSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: RegentColors.violet,
              backgroundImage: widget.recipientPhoto != null
                  ? NetworkImage(widget.recipientPhoto!)
                  : null,
              child: widget.recipientPhoto == null
                  ? Text(
                      widget.recipientName[0].toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.recipientName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Typing indicator or online status
                  StreamBuilder<DocumentSnapshot>(
                    stream: _chatService.getTypingStatus(widget.recipientId),
                    builder: (context, typingSnapshot) {
                      if (typingSnapshot.hasData &&
                          typingSnapshot.data!.exists) {
                        final data = typingSnapshot.data!.data()
                            as Map<String, dynamic>?;
                        final typing = data?['typing'] as Map<String, dynamic>?;
                        final isRecipientTyping =
                            typing?[widget.recipientId] != null;

                        if (isRecipientTyping) {
                          return const Text(
                            'typing...',
                            style: TextStyle(
                              color: RegentColors.lightViolet,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          );
                        }
                      }

                      // Show online status if not typing
                      return StreamBuilder<Map<String, dynamic>?>(
                        stream:
                            _chatService.getUserDataStream(widget.recipientId),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();
                          final data = snapshot.data;
                          final isOnline = data?['isOnline'] == true &&
                              data?['showOnlineStatus'] != false;
                          return Text(
                            isOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              color: isOnline
                                  ? Colors.greenAccent
                                  : Colors.white54,
                              fontSize: 12,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_isStartingCall)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            )
          else ...[
            IconButton(
              tooltip: 'Voice call',
              icon: const Icon(Icons.call_rounded, color: Colors.white),
              onPressed: () => _startCall(false),
            ),
            IconButton(
              tooltip: 'Video call',
              icon: const Icon(Icons.videocam_rounded, color: Colors.white),
              onPressed: () => _startCall(true),
            ),
          ],
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: RegentColors.dmCard,
            onSelected: (value) {
              if (value == 'clear') {
                _showClearChatDialog();
              } else if (value == 'wallpaper') {
                _showWallpaperPicker();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'wallpaper',
                child: Text('Chat wallpaper',
                    style: TextStyle(color: Colors.white)),
              ),
              const PopupMenuItem(
                value: 'clear',
                child:
                    Text('Clear chat', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: _wallpaperColor,
          image: _wallpaperImage == null
              ? null
              : DecorationImage(
                  image: MemoryImage(_wallpaperImage!),
                  fit: BoxFit.cover,
                  opacity: 0.38,
                ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _wallpaperColor,
              Color.alphaBlend(RegentColors.violet.withOpacity(0.10), _wallpaperColor),
            ],
          ),
        ),
        child: Column(
        children: [
          Expanded(
            child: !_isChatReady
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_chatInitializationError == null)
                            const CircularProgressIndicator(
                              color: RegentColors.violet,
                            )
                          else ...[
                            const Icon(
                              Icons.lock_outline,
                              color: Colors.white54,
                              size: 44,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'This conversation could not be opened.',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _chatInitializationError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(
                                  () => _chatInitializationError = null,
                                );
                                _initializeChat();
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Try again'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: _chatService.getMessages(widget.recipientId),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Error: ${snapshot.error}',
                              style: const TextStyle(color: Colors.white)),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(
                            child: CircularProgressIndicator(
                                color: RegentColors.violet));
                      }

                      final messages = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final deletedFor =
                            List<String>.from(data['deletedFor'] ?? const []);
                        return data['isDeleted'] != true &&
                            !deletedFor.contains(
                                _chatService.currentMessagingId);
                      })
                          .toList();

                      if (messages.isEmpty) {
                        return const Center(
                          child: Text(
                            'No messages yet.\nSay hello! 👋',
                            textAlign: TextAlign.center,
                            style:
                                TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                        );
                      }

                      // Scroll to highlighted message if exists
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_highlightedMessageId != null) {
                          _scrollToMessage(_highlightedMessageId!);
                        } else {
                          _scrollToBottom();
                        }
                      });

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final data =
                              messages[index].data() as Map<String, dynamic>;
                          final messageId = messages[index].id;
                          final isMe = data['senderId'] ==
                              _chatService.currentMessagingId;
                          final isHighlighted =
                              messageId == _highlightedMessageId;

                          // Store key for scrolling
                          _messageKeys[messageId] = GlobalKey();

                          // Check if we should show date header
                          bool showDateHeader = false;
                          if (index == 0) {
                            showDateHeader = true;
                          } else {
                            final prevData = messages[index - 1].data()
                                as Map<String, dynamic>;
                            final prevTimestamp =
                                prevData['timestamp'] as Timestamp?;
                            final currTimestamp =
                                data['timestamp'] as Timestamp?;
                            if (prevTimestamp != null &&
                                currTimestamp != null) {
                              final prevDate = prevTimestamp.toDate();
                              final currDate = currTimestamp.toDate();
                              showDateHeader = prevDate.day != currDate.day ||
                                  prevDate.month != currDate.month ||
                                  prevDate.year != currDate.year;
                            }
                          }

                          return Column(
                            key: _messageKeys[messageId],
                            children: [
                              if (showDateHeader)
                                _buildDateHeader(
                                    data['timestamp'] as Timestamp?),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 500),
                                decoration: BoxDecoration(
                                  color: isHighlighted
                                      ? RegentColors.violet.withOpacity(0.3)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child:
                                    _buildMessageBubble(data, isMe, messageId),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
          ),
          // Typing indicator at bottom
          StreamBuilder<DocumentSnapshot>(
            stream: _chatService.getTypingStatus(widget.recipientId),
            builder: (context, typingSnapshot) {
              if (typingSnapshot.hasData && typingSnapshot.data!.exists) {
                final data =
                    typingSnapshot.data!.data() as Map<String, dynamic>?;
                final typing = data?['typing'] as Map<String, dynamic>?;
                final typingUserName = typing?[widget.recipientId];

                if (typingUserName != null) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        _buildTypingAnimation(),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.recipientName} is typing...',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  );
                }
              }
              return const SizedBox.shrink();
            },
          ),
          _buildInputArea(),
        ],
        ),
      ),
    );
  }

  void _scrollToMessage(String messageId) {
    final key = _messageKeys[messageId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );
    }
  }

  Widget _buildTypingAnimation() {
    return SizedBox(
      width: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (index) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 600 + (index * 200)),
            builder: (context, value, child) {
              return Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: RegentColors.violet.withOpacity(0.5 + (value * 0.5)),
                  shape: BoxShape.circle,
                ),
              );
            },
            onEnd: () {},
          );
        }),
      ),
    );
  }

  Widget _buildDateHeader(Timestamp? timestamp) {
    if (timestamp == null) return const SizedBox();
    final date = timestamp.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    String dateStr;
    if (messageDate == today) {
      dateStr = 'Today';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      dateStr = 'Yesterday';
    } else {
      dateStr = '${date.day}/${date.month}/${date.year}';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: RegentColors.dmCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        dateStr,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
    );
  }

  Widget _buildMessageBubble(
      Map<String, dynamic> data, bool isMe, String messageId) {
    final type = data['type'] ?? 'text';
    final timestamp = data['timestamp'] as Timestamp?;
    final time = _formatMessageTime(timestamp);
    final isDeleted = data['isDeleted'] == true;
    final deletedForEveryone = data['deletedForEveryone'] == true;
    final deletedByName = data['deletedByName'] ?? 'Someone';
    final deletedBy = data['deletedBy'];

    // Check if message was deleted for me only
    final deletedForMe = List<String>.from(data['deletedFor'] ?? const [])
        .contains(_chatService.currentMessagingId);

    // If deleted for me only, don't show to me
    if (deletedForMe && !deletedForEveryone) {
      return const SizedBox.shrink();
    }

    // If deleted for everyone, show deleted placeholder
    if (deletedForEveryone) {
      return _buildDeletedMessageBubble(isMe, deletedByName,
          deletedBy == _chatService.currentMessagingId, time);
    }

    final reactions = Map<String, List<String>>.from(
      (data['reactions'] ?? {})
          .map((key, value) => MapEntry(key, List<String>.from(value))),
    );
    final isStarred =
        data['starredBy']?.contains(_chatService.currentMessagingId) ?? false;
    final pinnedUntil = data['pinnedUntil'];
    final isPinned = pinnedUntil is Timestamp &&
        pinnedUntil.toDate().isAfter(DateTime.now());
    final replyTo = data['replyTo'] as Map<String, dynamic>?;

    return _SwipeReplyMessage(
      isOutgoing: isMe,
      onReply: () => _setReplyTo(data, messageId: messageId),
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(context, data, isMe, messageId),
        child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Reply preview
            if (replyTo != null)
              Container(
                margin: EdgeInsets.only(
                  left: isMe ? 50 : 0,
                  right: isMe ? 0 : 50,
                  bottom: 4,
                ),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: RegentColors.dmCard.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(
                    left: BorderSide(
                      color: RegentColors.violet,
                      width: 3,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      replyTo['senderName'] ?? 'Unknown',
                      style: const TextStyle(
                        color: RegentColors.lightViolet,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      replyTo['message'] ?? '',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            // Message bubble
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                color: isMe ? RegentColors.violet : RegentColors.dmCard,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                  bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sender name for received messages
                  if (!isMe && data['senderName'] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        data['senderName'],
                        style: const TextStyle(
                          color: RegentColors.lightViolet,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  _buildMessageContent(data, type, messageId, isMe),
                  const SizedBox(height: 4),
                  // Time and status
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isPinned)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.push_pin,
                              size: 12, color: RegentColors.lightViolet),
                        ),
                      if (isStarred)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child:
                              Icon(Icons.star, size: 12, color: Colors.amber),
                        ),
                      Text(
                        time,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.6), fontSize: 11),
                      ),
                      if (data['editedAt'] != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          'Edited',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all,
                          size: 14,
                          color: data['isRead'] == true
                              ? Colors.lightBlueAccent
                              : Colors.white60,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Reactions display
            if (reactions.isNotEmpty)
              Container(
                margin: EdgeInsets.only(
                  left: isMe ? 0 : 12,
                  right: isMe ? 12 : 0,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: RegentColors.dmSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: RegentColors.dmCard),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: reactions.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: GestureDetector(
                        onTap: () => _toggleReaction(messageId, entry.key),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(entry.key,
                                style: const TextStyle(fontSize: 14)),
                            if (entry.value.length > 1)
                              Padding(
                                padding: const EdgeInsets.only(left: 2),
                                child: Text(
                                  '${entry.value.length}',
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 10),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildMessageContent(
    Map<String, dynamic> data,
    String type,
    String messageId,
    bool isMe,
  ) {
    final message = (data['message'] ?? '').toString();
    final mediaUrl = data['mediaUrl']?.toString();
    final metadata = Map<String, dynamic>.from(data['metadata'] ?? const {});

    if (metadata['isStatusReply'] == true) {
      final statusType = metadata['statusType']?.toString() ?? 'text';
      final statusText = metadata['statusText']?.toString();
      final statusMediaUrl = metadata['statusMediaUrl']?.toString();
      final isReaction = metadata['isStatusReaction'] == true;
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(9),
                border: const Border(
                  left: BorderSide(
                    color: RegentColors.lightViolet,
                    width: 3,
                  ),
                ),
              ),
              child: Row(
                children: [
                  if (statusMediaUrl?.isNotEmpty == true &&
                      statusType == 'image')
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        statusMediaUrl!,
                        width: 42,
                        height: 42,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Icon(
                      statusType == 'video'
                          ? Icons.videocam_rounded
                          : statusType == 'image'
                              ? Icons.image_rounded
                              : Icons.donut_large_rounded,
                      color: Colors.white70,
                      size: 26,
                    ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Status reply',
                          style: TextStyle(
                            color: RegentColors.lightViolet,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          statusText?.isNotEmpty == true
                              ? statusText!
                              : '${statusType[0].toUpperCase()}${statusType.substring(1)} status',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              style: TextStyle(
                color: Colors.white,
                fontSize: isReaction ? 28 : 15,
              ),
            ),
          ],
        ),
      );
    }

    if (type == 'image' || type == 'video') {
      return _buildMediaMessageContent(
        data: data,
        type: type,
        messageId: messageId,
        isMe: isMe,
      );
    }

    if (type == 'audio') {
      return InkWell(
        onTap: () {
          final url = data['mediaUrl']?.toString();
          if (url != null && url.isNotEmpty) {
            _audioPlayer.play(UrlSource(url));
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white24,
                child: Icon(Icons.play_arrow, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Voice message',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _formatDuration(data['audioDuration'] as int? ?? 0),
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (type == 'sticker') {
      if (mediaUrl != null && mediaUrl.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            mediaUrl,
            width: 150,
            height: 150,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white70,
              size: 48,
            ),
          ),
        );
      }
      return Text(message, style: const TextStyle(fontSize: 52));
    }

    if (type == 'poll') {
      final question = (metadata['question'] ?? message).toString();
      final options = List<dynamic>.from(metadata['options'] ?? const []);
      final votes = Map<String, dynamic>.from(metadata['votes'] ?? const {});
      final totalVotes = votes.values.fold<int>(
        0,
        (total, voters) =>
            total + List<dynamic>.from(voters ?? const []).length,
      );
      return SizedBox(
        width: 230,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.poll, color: Colors.white, size: 18),
                SizedBox(width: 6),
                Text(
                  'POLL',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              question,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < options.length; index++)
              InkWell(
                onTap: () => _chatService.voteInPoll(
                  otherUserId: widget.recipientId,
                  messageId: messageId,
                  optionIndex: index,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Icon(
                        List<String>.from(votes['$index'] ?? const [])
                                .contains(_chatService.currentMessagingId)
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          options[index].toString(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      Text(
                        '${List<dynamic>.from(votes['$index'] ?? const []).length}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            Text(
              '$totalVotes vote${totalVotes == 1 ? '' : 's'}',
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ],
        ),
      );
    }

    if (type == 'location' ||
        type == 'contact' ||
        type == 'calendar' ||
        type == 'file') {
      final icon = switch (type) {
        'location' => Icons.location_on,
        'contact' => Icons.person_pin,
        'calendar' => Icons.calendar_month,
        _ => Icons.description,
      };
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 230),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: Colors.white24,
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Text(
      message,
      style: const TextStyle(color: Colors.white, fontSize: 15),
    );
  }

  Widget _buildMediaMessageContent({
    required Map<String, dynamic> data,
    required String type,
    required bool isMe,
    required String messageId,
  }) {
    final mediaUrl = (data['mediaUrl'] ?? '').toString();
    final isViewOnce = data['isViewOnce'] == true;
    final viewedBy = List<String>.from(data['viewedBy'] ?? const []);
    final hasBeenViewed = viewedBy.contains(_chatService.currentMessagingId);
    final label = type == 'video' ? 'Video' : 'Photo';
    final title = isViewOnce ? 'View once ${label.toLowerCase()}' : label;

    if (mediaUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    if (isViewOnce && !isMe && hasBeenViewed) {
      return _buildViewOnceConsumedPreview(label);
    }

    final shouldMarkViewed = isViewOnce && !isMe && !hasBeenViewed;
    if (type == 'image') {
      return GestureDetector(
        onTap: () => _openMediaViewer(
          mediaUrl: mediaUrl,
          mediaType: type,
          title: title,
          messageId: messageId,
          shouldMarkViewed: shouldMarkViewed,
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                mediaUrl,
                width: 220,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox(
                    width: 220,
                    height: 150,
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  width: 220,
                  height: 150,
                  color: Colors.black26,
                  child: const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 34,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.52),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => _openMediaViewer(
        mediaUrl: mediaUrl,
        mediaType: type,
        title: title,
        messageId: messageId,
        shouldMarkViewed: shouldMarkViewed,
      ),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_circle_fill,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to open',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.72),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewOnceConsumedPreview(String label) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white24,
            child: Icon(Icons.visibility_off_outlined, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$label viewed',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'This view once media is no longer available.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMediaViewer({
    required String mediaUrl,
    required String mediaType,
    required String title,
    required String messageId,
    required bool shouldMarkViewed,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatMediaViewerScreen(
          mediaUrl: mediaUrl,
          mediaType: mediaType,
          title: title,
          isViewOnce: shouldMarkViewed,
          onViewed: shouldMarkViewed
              ? () => _chatService.markMessageAsViewed(
                    otherUserId: widget.recipientId,
                    messageId: messageId,
                  )
              : null,
        ),
      ),
    );
  }

  Widget _buildDeletedMessageBubble(
      bool isMe, String deletedByName, bool deletedByCurrentUser, String time) {
    final displayText = deletedByCurrentUser
        ? 'You deleted this message'
        : '$deletedByName deleted this message';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: (isMe ? RegentColors.violet : RegentColors.dmCard)
              .withOpacity(0.5),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.block,
                  size: 16,
                  color: Colors.white.withOpacity(0.5),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    displayText,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style:
                  TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageOptions(BuildContext context, Map<String, dynamic> data,
      bool isMe, String messageId) {
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: RegentColors.dmSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Quick reactions row
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ..._quickReactions
                      .map((emoji) => _buildReactionButton(emoji, messageId)),
                  _buildAddEmojiButton(messageId),
                ],
              ),
            ),
            const Divider(color: RegentColors.dmCard, height: 1),
            // Message options
            _buildOptionTile(Icons.reply, 'Reply', () {
              Navigator.pop(context);
              _setReplyTo(data, messageId: messageId);
            }),
            _buildOptionTile(Icons.forward, 'Forward', () {
              Navigator.pop(context);
              _forwardMessage(data);
            }),
            _buildOptionTile(Icons.copy, 'Copy', () {
              Navigator.pop(context);
              _copyMessage(data['message'] ?? '');
            }),
            if (_canEditMessage(data, isMe))
              _buildOptionTile(Icons.edit_outlined, 'Edit message', () {
                Navigator.pop(context);
                _showEditMessageDialog(messageId, data['message']?.toString() ?? '');
              }),
            _buildOptionTile(
              data['starredBy']?.contains(_chatService.currentMessagingId) ==
                      true
                  ? Icons.star
                  : Icons.star_border,
              data['starredBy']?.contains(_chatService.currentMessagingId) ==
                      true
                  ? 'Unstar'
                  : 'Star',
              () {
                Navigator.pop(context);
                _toggleStar(messageId);
              },
            ),
            _buildOptionTile(Icons.delete, 'Delete for me', () {
              Navigator.pop(context);
              _deleteMessage(messageId);
            }, isDestructive: true),
            _buildOptionTile(Icons.more_horiz, 'More', () {
              Navigator.pop(context);
              _showMoreOptions(context, data, isMe, messageId);
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  bool _canEditMessage(Map<String, dynamic> data, bool isMe) {
    final timestamp = data['timestamp'];
    return isMe &&
        data['type'] == 'text' &&
        data['isDeleted'] != true &&
        timestamp is Timestamp &&
        DateTime.now().difference(timestamp.toDate()) <=
            const Duration(minutes: 15);
  }

  Future<void> _showEditMessageDialog(
    String messageId,
    String originalMessage,
  ) async {
    final controller = TextEditingController(text: originalMessage);
    final updated = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 1,
          maxLines: 5,
          maxLength: 10000,
          decoration: const InputDecoration(hintText: 'Update your message'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (updated == null || updated.trim() == originalMessage.trim()) return;
    try {
      await _chatService.editTextMessage(
        otherUserId: widget.recipientId,
        messageId: messageId,
        message: updated,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Message could not be edited: $error')),
        );
      }
    }
  }

  Widget _buildReactionButton(String emoji, String messageId) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _toggleReaction(messageId, emoji);
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: RegentColors.dmCard,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 24)),
      ),
    );
  }

  Widget _buildAddEmojiButton(String messageId) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _showEmojiPicker(messageId);
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: RegentColors.dmCard,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildOptionTile(IconData icon, String title, VoidCallback onTap,
      {bool isDestructive = false}) {
    return ListTile(
      leading:
          Icon(icon, color: isDestructive ? Colors.redAccent : Colors.white),
      title: Text(
        title,
        style:
            TextStyle(color: isDestructive ? Colors.redAccent : Colors.white),
      ),
      onTap: onTap,
    );
  }

  void _showMoreOptions(BuildContext context, Map<String, dynamic> data,
      bool isMe, String messageId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: RegentColors.dmSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white30,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          _buildOptionTile(Icons.push_pin, 'Pin message', () {
            Navigator.pop(context);
            _showPinDurationPicker(messageId);
          }),
          _buildOptionTile(Icons.report, 'Report', () {
            Navigator.pop(context);
            _reportMessage(messageId);
          }),
          _buildOptionTile(Icons.quick_contacts_mail, 'Add quick reply', () {
            Navigator.pop(context);
            _addQuickReply(data['message'] ?? '');
          }),
          if (isMe)
            _buildOptionTile(Icons.delete_forever, 'Delete for everyone', () {
              Navigator.pop(context);
              _deleteForEveryone(messageId);
            }, isDestructive: true),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showEmojiPicker(String messageId) {
    final allEmojis = [
      '😀',
      '😃',
      '😄',
      '😁',
      '😆',
      '😅',
      '🤣',
      '😂',
      '🙂',
      '🙃',
      '😉',
      '😊',
      '😇',
      '🥰',
      '😍',
      '🤩',
      '😘',
      '😗',
      '😚',
      '😋',
      '😛',
      '😜',
      '🤪',
      '😝',
      '🤑',
      '🤗',
      '🤭',
      '🤫',
      '🤔',
      '🤐',
      '🤨',
      '😐',
      '😑',
      '😶',
      '😏',
      '😒',
      '🙄',
      '😬',
      '🤥',
      '😌',
      '😔',
      '😪',
      '🤤',
      '😴',
      '😷',
      '🤒',
      '🤕',
      '🤢',
      '🤮',
      '🤧',
      '🥵',
      '🥶',
      '🥴',
      '😵',
      '🤯',
      '🤠',
      '🥳',
      '😎',
      '🤓',
      '🧐',
      '😕',
      '😟',
      '🙁',
      '☹️',
      '😮',
      '😯',
      '😲',
      '😳',
      '🥺',
      '😦',
      '😧',
      '😨',
      '😰',
      '😥',
      '😢',
      '😭',
      '😱',
      '😖',
      '😣',
      '😞',
      '😓',
      '😩',
      '😫',
      '🥱',
      '😤',
      '😡',
      '😠',
      '🤬',
      '😈',
      '👿',
      '👍',
      '👎',
      '👏',
      '🙌',
      '👐',
      '🤲',
      '🤝',
      '🙏',
      '✊',
      '👊',
      '🤛',
      '🤜',
      '🤞',
      '✌️',
      '🤟',
      '🤘',
      '👌',
      '🤏',
      '👈',
      '👉',
      '👆',
      '👇',
      '☝️',
      '✋',
      '🤚',
      '🖐',
      '🖖',
      '👋',
      '🤙',
      '💪',
      '❤️',
      '🧡',
      '💛',
      '💚',
      '💙',
      '💜',
      '🖤',
      '🤍',
      '🤎',
      '💔',
      '❣️',
      '💕',
      '💞',
      '💓',
      '💗',
      '💖',
      '💘',
      '💝',
      '💟',
      '☮️',
      '🔥',
      '✨',
      '🎉',
      '🎊',
      '🎁',
      '🏆',
      '🥇',
      '🥈',
      '🥉',
      '⭐',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: RegentColors.dmSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Choose a reaction',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: GridView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: allEmojis.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _toggleReaction(messageId, allEmojis[index]);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: RegentColors.dmCard,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(allEmojis[index],
                            style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setReplyTo(Map<String, dynamic> message, {String? messageId}) {
    setState(() {
      _replyingTo = {
        'messageId': messageId ?? message['messageId'],
        'senderId': message['senderId'],
        'senderName': message['senderName'] ?? 'Unknown',
        'message': message['message'] ?? message['content'] ?? '',
        'type': message['type'] ?? 'text',
      };
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
    });
  }

  Future<void> _toggleReaction(String messageId, String emoji) async {
    await _chatService.toggleReaction(widget.recipientId, messageId, emoji);
  }

  Future<void> _toggleStar(String messageId) async {
    await _chatService.toggleStar(widget.recipientId, messageId);
  }

  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message copied'),
        backgroundColor: RegentColors.violet,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _forwardMessage(Map<String, dynamic> message) {
    _showForwardDialog(message);
  }

  void _showForwardDialog(Map<String, dynamic> message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: RegentColors.dmSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Forward to',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: RegentColors.violet));
                  }

                  final users = snapshot.data!.docs
                      .where((doc) => doc.id != _chatService.currentUserId)
                      .toList();

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final userData =
                          users[index].data() as Map<String, dynamic>;
                      final userId = users[index].id;
                      final userName = userData['fullName'] ??
                          userData['email'] ??
                          'Unknown';
                      final userPhoto = userData['photoUrl'];

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: RegentColors.violet,
                          backgroundImage: userPhoto != null
                              ? NetworkImage(userPhoto)
                              : null,
                          child: userPhoto == null
                              ? Text(userName[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white))
                              : null,
                        ),
                        title: Text(userName,
                            style: const TextStyle(color: Colors.white)),
                        onTap: () async {
                          Navigator.pop(context);
                          await _chatService.sendMessage(
                            receiverId: userId,
                            message: message['message'] ?? '',
                            type: message['type'] ?? 'text',
                            mediaUrl: message['mediaUrl'],
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Message forwarded to $userName'),
                                backgroundColor: RegentColors.violet,
                              ),
                            );
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteMessage(String messageId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RegentColors.dmSurface,
        title:
            const Text('Delete message', style: TextStyle(color: Colors.white)),
        content: const Text('Delete this message for you?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _chatService.deleteMessage(widget.recipientId, messageId);
    }
  }

  Future<void> _showClearChatDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RegentColors.dmSurface,
        title: const Text(
          'Clear chat?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This clears the conversation from your chat view.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _chatService.clearChat(widget.recipientId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chat cleared')),
    );
  }

  void _deleteForEveryone(String messageId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RegentColors.dmSurface,
        title: const Text('Delete for everyone',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'This message will be deleted for everyone in this chat.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _chatService.deleteForEveryone(widget.recipientId, messageId);
    }
  }

  Future<void> _showPinDurationPicker(String messageId) async {
    final duration = await showModalBottomSheet<Duration>(
      context: context,
      backgroundColor: RegentColors.dmSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Pin message for',
                  style: TextStyle(color: Colors.white)),
            ),
            _buildOptionTile(Icons.today, '24 hours',
                () => Navigator.pop(context, const Duration(hours: 24))),
            _buildOptionTile(Icons.date_range, '7 days',
                () => Navigator.pop(context, const Duration(days: 7))),
            _buildOptionTile(Icons.calendar_month, '1 month',
                () => Navigator.pop(context, const Duration(days: 30))),
          ],
        ),
      ),
    );
    if (duration == null) return;
    try {
      await _chatService.pinMessage(
        otherUserId: widget.recipientId,
        messageId: messageId,
        duration: duration,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Message pinned')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Message could not be pinned: $error')));
      }
    }
  }

  void _reportMessage(String messageId) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Message reported'),
          backgroundColor: RegentColors.violet),
    );
  }

  void _addQuickReply(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Added to quick replies'),
          backgroundColor: RegentColors.violet),
    );
  }

  // Update _buildInputArea to show reply preview
  Widget _buildInputArea() {
    return Column(
      children: [
        // Reply preview
        if (_replyingTo != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: RegentColors.dmCard,
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  color: RegentColors.violet,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _replyingTo!['senderName'] ?? 'Unknown',
                        style: TextStyle(
                          color: RegentColors.lightViolet,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _replyingTo!['message'] ?? '',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.close, color: Colors.white54, size: 20),
                  onPressed: _cancelReply,
                ),
              ],
            ),
          ),
        // Input area
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          color: RegentColors.dmSurface,
          child: _isRecording
              ? Row(
                  children: [
                    IconButton(
                      tooltip: 'Cancel recording',
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent),
                      onPressed: _cancelRecording,
                    ),
                    const Icon(Icons.fiber_manual_record,
                        color: Colors.redAccent, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      'Recording ${_formatDuration(_recordingDuration)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton.filled(
                      tooltip: 'Send voice message',
                      style: IconButton.styleFrom(
                        backgroundColor: RegentColors.violet,
                      ),
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendRecording,
                    ),
                  ],
                )
              : Row(
                  children: [
                    IconButton(
                      tooltip: 'More attachments',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.add_circle,
                        color: RegentColors.lightViolet,
                      ),
                      onPressed: _showAttachmentOptions,
                    ),
                    IconButton(
                      tooltip: 'Camera',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.camera_alt,
                        color: RegentColors.lightViolet,
                      ),
                      onPressed: () => _pickImage(ImageSource.camera),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: RegentColors.violet.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: RegentColors.lightViolet.withOpacity(0.85),
                            width: 1.4,
                          ),
                        ),
                        child: TextField(
                          controller: _messageController,
                          cursorColor: RegentColors.darkViolet,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(color: Colors.white70),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          onSubmitted: (_) => _sendMessageWithReply(),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Stickers',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.emoji_emotions_outlined,
                        color: RegentColors.lightViolet,
                      ),
                      onPressed: _showStickerPicker,
                    ),
                    if (_isSending)
                      const Padding(
                        padding: EdgeInsets.all(10),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: RegentColors.lightViolet,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    else
                      GestureDetector(
                        onLongPress: _messageController.text.trim().isEmpty
                            ? null
                            : () => _sendViewOnceText(),
                        child: IconButton(
                          tooltip: _messageController.text.trim().isEmpty
                              ? 'Record audio'
                              : 'Send message (hold for view once)',
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            _messageController.text.trim().isEmpty
                                ? Icons.mic
                                : Icons.send,
                            color: RegentColors.lightViolet,
                          ),
                          onPressed: _messageController.text.trim().isEmpty
                              ? _startRecording
                              : _sendMessageWithReply,
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _sendViewOnceText() async {
    if (_messageController.text.trim().isEmpty || _isSending) return;
    final confirmed = await _promptViewOnce('message');
    if (confirmed == true) await _sendMessageWithReply(isViewOnce: true);
  }

  Future<void> _sendMessageWithReply({bool isViewOnce = false}) async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await _chatService.sendMessage(
        receiverId: widget.recipientId,
        message: message,
        replyTo: _replyingTo,
        isViewOnce: isViewOnce,
      );
      if (mounted) {
        setState(() => _replyingTo = null);
      }
      _scrollToBottom();
    } catch (error) {
      if (mounted) {
        _messageController.text = message;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Message could not be sent: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}
