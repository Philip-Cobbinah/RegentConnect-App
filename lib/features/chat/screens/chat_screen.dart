import 'package:flutter/material.dart';
import '../../../core/theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      // Add to beginning of list so newest appears first in reverse list
      _messages.insert(
          0,
          ChatMessage(
            content: message,
            isUser: true,
            timestamp: DateTime.now(),
          ));
      _messageController.clear();
    });
  }

  void _addAttachmentMessage(String label) {
    Navigator.pop(context);
    setState(() {
      _messages.insert(
        0,
        ChatMessage(
          content: '$label shared',
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
    });
  }

  void _showAttachmentOptions() {
    const tools = <(IconData, String)>[
      (Icons.camera_alt, 'Camera'),
      (Icons.photo_library, 'Photos'),
      (Icons.description, 'Document'),
      (Icons.location_on, 'Location'),
      (Icons.person_pin, 'Contact'),
      (Icons.bolt, 'Quick response'),
      (Icons.poll, 'Poll'),
      (Icons.calendar_month, 'Calendar'),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: RegentColors.dmSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 4,
            mainAxisSpacing: 18,
            children: [
              for (final tool in tools)
                InkWell(
                  onTap: () => _addAttachmentMessage(tool.$2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        backgroundColor: RegentColors.violet,
                        child: Icon(tool.$1, color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tool.$2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStickers() {
    const stickers = ['👍', '❤️', '🎉', '🔥', '😊', '👏'];
    showModalBottomSheet(
      context: context,
      backgroundColor: RegentColors.dmSurface,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final sticker in stickers)
                InkWell(
                  onTap: () {
                    Navigator.pop(sheetContext);
                    setState(() {
                      _messages.insert(
                        0,
                        ChatMessage(
                          content: sticker,
                          isUser: true,
                          timestamp: DateTime.now(),
                        ),
                      );
                    });
                  },
                  child: Text(sticker, style: const TextStyle(fontSize: 32)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(time.year, time.month, time.day);

    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    if (messageDay == today) {
      return timeStr;
    } else if (messageDay == today.subtract(const Duration(days: 1))) {
      return 'Yesterday $timeStr';
    } else {
      return '${time.day}/${time.month} $timeStr';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RegentColors.dmBackground,
      appBar: AppBar(
        backgroundColor: RegentColors.dmSurface,
        title: const Text('Chat', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 64,
                            color: RegentColors.violet.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        const Text('No messages yet',
                            style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    reverse:
                        true, // Newest messages at bottom, scroll up for older
                    itemCount: _messages.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return Align(
                        alignment: msg.isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            color: msg.isUser
                                ? RegentColors.violet
                                : RegentColors.dmCard,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: msg.isUser
                                  ? const Radius.circular(16)
                                  : Radius.zero,
                              bottomRight: msg.isUser
                                  ? Radius.zero
                                  : const Radius.circular(16),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                msg.content,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 15),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTime(msg.timestamp),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: RegentColors.dmSurface,
            child: Row(
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
                  onPressed: _showAttachmentOptions,
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: RegentColors.dmCard,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextField(
                      controller: _messageController,
                      cursorColor: RegentColors.darkViolet,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 15,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: Colors.black54),
                        filled: true,
                        fillColor: Colors.white,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
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
                  onPressed: _showStickers,
                ),
                IconButton(
                  tooltip: _messageController.text.trim().isEmpty
                      ? 'Record audio'
                      : 'Send',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    _messageController.text.trim().isEmpty
                        ? Icons.mic
                        : Icons.send,
                    color: RegentColors.lightViolet,
                  ),
                  onPressed: _messageController.text.trim().isEmpty
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Open a user conversation to record a voice message.',
                              ),
                            ),
                          );
                        }
                      : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.content,
    required this.isUser,
    required this.timestamp,
  });
}
