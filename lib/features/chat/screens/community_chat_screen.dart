import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme.dart';
import '../../../models/group_model.dart';
import '../../../services/chat_service.dart';
import 'group_details_screen.dart';
import '../widgets/chat_media_viewer.dart';

class CommunityChatScreen extends StatefulWidget {
  final GroupModel group;

  const CommunityChatScreen({
    super.key,
    required this.group,
  });

  @override
  State<CommunityChatScreen> createState() => _CommunityChatScreenState();
}

class _CommunityChatScreenState extends State<CommunityChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  final Set<String> _mentionedUserIds = <String>{};
  final Map<String, String> _mentionedUserNames = <String, String>{};
  bool _mentionPickerOpen = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(GroupModel group) async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    _messageController.clear();
    try {
      await _chatService.sendGroupMessage(
        groupId: group.id,
        message: message,
        mentionedUserIds: _mentionedUserIds.toList(),
        mentionEveryone: message.contains('@everyone'),
      );
      _mentionedUserIds.clear();
      _mentionedUserNames.clear();
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } catch (error) {
      if (mounted) {
        _messageController.text = message;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _showMentionPicker(GroupModel group) async {
    if (_mentionPickerOpen) return;
    _mentionPickerOpen = true;
    try {
      final users = await Future.wait(group.members.map((id) async {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(id)
            .get();
        final data = snapshot.data() ?? <String, dynamic>{};
        return <String, String>{
          'id': id,
          'name': (data['fullName'] ?? data['displayName'] ?? data['email'] ?? id)
              .toString(),
        };
      }));
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: RegentColors.dmSurface,
        builder: (sheetContext) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              if (group.isAdmin(_chatService.currentUserId) ||
                  !group.everyoneMentionAdminsOnly)
                ListTile(
                  leading: const Icon(Icons.groups, color: RegentColors.lightViolet),
                  title: const Text('@everyone', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Mention every group member', style: TextStyle(color: Colors.white60)),
                  onTap: () {
                    _messageController.text = '${_messageController.text}@everyone ';
                    Navigator.pop(sheetContext);
                  },
                ),
              ...users.where((user) => user['id'] != _chatService.currentUserId).map(
                    (user) => ListTile(
                      leading: const Icon(Icons.person, color: RegentColors.lightViolet),
                      title: Text(user['name']!, style: const TextStyle(color: Colors.white)),
                      onTap: () {
                        _mentionedUserIds.add(user['id']!);
                        _mentionedUserNames[user['id']!] = user['name']!;
                        _messageController.text =
                            '${_messageController.text}@${user['name']} ';
                        Navigator.pop(sheetContext);
                      },
                    ),
                  ),
            ],
          ),
        ),
      );
    } finally {
      _mentionPickerOpen = false;
    }
  }

  Future<void> _sendImage(GroupModel group) async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image == null) return;

    final isViewOnce = await _promptViewOnce('photo');
    if (isViewOnce == null) return;

    await _sendAttachment(
      group,
      bytes: await image.readAsBytes(),
      type: 'image',
      name: image.name,
      contentType: image.mimeType,
      isViewOnce: isViewOnce,
    );
  }

  Future<void> _sendVideo(GroupModel group) async {
    final video = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (video == null) return;

    final isViewOnce = await _promptViewOnce('video');
    if (isViewOnce == null) return;

    await _sendAttachment(
      group,
      bytes: await video.readAsBytes(),
      type: 'video',
      name: video.name,
      contentType: video.mimeType,
      isViewOnce: isViewOnce,
    );
  }

  Future<void> _sendFile(GroupModel group) async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    final file = result?.files.single;
    if (file?.bytes == null) return;
    await _sendAttachment(
      group,
      bytes: file!.bytes!,
      type: 'file',
      name: file.name,
    );
  }

  Future<void> _sendAttachment(
    GroupModel group, {
    required List<int> bytes,
    required String type,
    required String name,
    String? contentType,
    bool isViewOnce = false,
  }) async {
    if (_isSending) return;
    setState(() => _isSending = true);
    try {
      await _chatService.sendGroupMediaMessage(
        groupId: group.id,
        bytes: Uint8List.fromList(bytes),
        type: type,
        originalName: name,
        contentType: contentType,
        message: _messageController.text.trim(),
        isViewOnce: isViewOnce,
      );
      _messageController.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Attachment could not be sent: $error')),
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
          'Do you want to send this $mediaLabel so members can only open it once?',
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

  Future<void> _showPollDialog(GroupModel group) async {
    final questionController = TextEditingController();
    final optionControllers = <TextEditingController>[
      TextEditingController(),
      TextEditingController(),
    ];

    final poll = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          void addOption() {
            if (optionControllers.length >= 6) return;
            setDialogState(() {
              optionControllers.add(TextEditingController());
            });
          }

          void removeOption(int index) {
            if (optionControllers.length <= 2) return;
            final controller = optionControllers.removeAt(index);
            controller.dispose();
            setDialogState(() {});
          }

          return AlertDialog(
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
                  for (var index = 0; index < optionControllers.length; index++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: optionControllers[index],
                              style: const TextStyle(color: Colors.black87),
                              decoration: InputDecoration(
                                labelText: 'Option ${index + 1}',
                              ),
                            ),
                          ),
                          if (optionControllers.length > 2)
                            IconButton(
                              onPressed: () => removeOption(index),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                        ],
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed:
                          optionControllers.length < 6 ? addOption : null,
                      icon: const Icon(Icons.add),
                      label: const Text('Add option'),
                    ),
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
                  final options = optionControllers
                      .map((controller) => controller.text.trim())
                      .where((option) => option.isNotEmpty)
                      .toList();
                  if (question.isNotEmpty && options.length >= 2) {
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
          );
        },
      ),
    );

    for (final controller in optionControllers) {
      controller.dispose();
    }
    questionController.dispose();

    if (poll == null) return;
    await _chatService.sendGroupMessage(
      groupId: group.id,
      message: 'Poll: ${poll['question']}',
      type: 'poll',
      metadata: poll,
    );
  }

  void _showAttachments(GroupModel group) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: RegentColors.violet,
                child: Icon(Icons.image, color: Colors.white),
              ),
              title: const Text('Photo'),
              onTap: () {
                Navigator.pop(context);
                _sendImage(group);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: RegentColors.blue,
                child: Icon(Icons.video_library, color: Colors.white),
              ),
              title: const Text('Video'),
              onTap: () {
                Navigator.pop(context);
                _sendVideo(group);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: RegentColors.darkViolet,
                child: Icon(Icons.attach_file, color: Colors.white),
              ),
              title: const Text('Document'),
              onTap: () {
                Navigator.pop(context);
                _sendFile(group);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: RegentColors.lightViolet,
                child: Icon(Icons.poll, color: Colors.white),
              ),
              title: const Text('Poll'),
              onTap: () {
                Navigator.pop(context);
                _showPollDialog(group);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _chatService.getGroupStream(widget.group.id),
      builder: (context, groupSnapshot) {
        final document = groupSnapshot.data;
        final group = document != null && document.exists
            ? GroupModel.fromMap({
                ...(document.data() as Map<String, dynamic>),
                'id': document.id,
              })
            : widget.group;
        final canPost = group.canPost(_chatService.currentUserId);

        return Scaffold(
          backgroundColor: RegentColors.dmBackground,
          appBar: AppBar(
            backgroundColor: RegentColors.dmSurface,
            foregroundColor: Colors.white,
            titleSpacing: 0,
            title: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor:
                      group.isChannel ? RegentColors.blue : RegentColors.violet,
                  backgroundImage: group.profilePictureUrl != null
                      ? NetworkImage(group.profilePictureUrl!)
                      : null,
                  child: group.profilePictureUrl == null
                      ? Icon(
                          group.isChannel ? Icons.campaign : Icons.groups_2,
                          color: Colors.white,
                          size: 20,
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${group.isChannel ? 'Channel' : 'Group'} • ${group.members.length} members',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: '${group.isChannel ? 'Channel' : 'Group'} settings',
                icon: const Icon(Icons.info_outline),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GroupDetailsScreen(group: group),
                    ),
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              if (group.isChannel)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: RegentColors.blue.withOpacity(0.22),
                  child: Text(
                    canPost
                        ? 'You are an admin and can publish to this channel.'
                        : 'Only channel admins can publish. Members can read and vote in polls.',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              Expanded(child: _buildMessages(group)),
              _buildComposer(group, canPost),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessages(GroupModel group) {
    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.getGroupMessages(group.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Messages could not be loaded: ${snapshot.error}',
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: RegentColors.violet),
          );
        }

        final messages = snapshot.data!.docs;
        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  group.isChannel
                      ? Icons.campaign_outlined
                      : Icons.forum_outlined,
                  color: Colors.white38,
                  size: 58,
                ),
                const SizedBox(height: 12),
                Text(
                  group.isChannel
                      ? 'No channel updates yet.'
                      : 'Start the group conversation.',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
          }
        });

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(12),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final data = messages[index].data() as Map<String, dynamic>;
            final isMe = data['senderId'] == _chatService.currentUserId;
            final timestamp = data['timestamp'] as Timestamp?;
            return _buildGroupMessageBubble(
              group: group,
              data: data,
              isMe: isMe,
              timestamp: timestamp,
              messageId: messages[index].id,
            );
          },
        );
      },
    );
  }

  Widget _buildGroupMessageBubble({
    required GroupModel group,
    required Map<String, dynamic> data,
    required bool isMe,
    required Timestamp? timestamp,
    required String messageId,
  }) {
    final type = (data['type'] ?? 'text').toString();
    final message = (data['message'] ?? '').toString();
    final mediaUrl = (data['mediaUrl'] ?? '').toString();
    final mediaName =
        (data['mediaName'] ?? data['type'] ?? 'Attachment').toString();
    final isViewOnce = data['isViewOnce'] == true;
    final viewedBy = List<String>.from(data['viewedBy'] ?? const []);
    final hasBeenViewed = viewedBy.contains(_chatService.currentUserId);
    final time = timestamp == null
        ? ''
        : '${timestamp.toDate().hour.toString().padLeft(2, '0')}:${timestamp.toDate().minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.76,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: isMe ? RegentColors.violet : RegentColors.dmCard,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(
                (data['senderName'] ?? 'Member').toString(),
                style: const TextStyle(
                  color: RegentColors.lightViolet,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (type == 'poll')
              _buildGroupPollBubble(group, data, messageId)
            else ...[
              if (type == 'image' || type == 'video')
                _buildGroupMediaPreview(
                  mediaUrl: mediaUrl,
                  mediaType: type,
                  isMe: isMe,
                  isViewOnce: isViewOnce,
                  hasBeenViewed: hasBeenViewed,
                  messageId: messageId,
                )
              else if (mediaUrl.isNotEmpty && type == 'file')
                _buildGroupFileAttachment(mediaUrl, mediaName),
              if (message.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: mediaUrl.isNotEmpty ? 6 : 0),
                  child: _buildMentionText(message, data),
                ),
            ],
            const SizedBox(height: 3),
            Text(
              time,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMentionText(String message, Map<String, dynamic> data) {
    final mentioned = List<String>.from(data['mentionedUserIds'] ?? const []);
    final mentionEveryone = data['mentionEveryone'] == true;
    final parts = RegExp(r'@[^ ]+').allMatches(message);
    if (parts.isEmpty) {
      return Text(message, style: const TextStyle(color: Colors.white, fontSize: 15));
    }
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final match in parts) {
      if (match.start > cursor) spans.add(TextSpan(text: message.substring(cursor, match.start)));
      final token = match.group(0)!;
      final isMention = mentionEveryone && token == '@everyone' || mentioned.isNotEmpty;
      spans.add(TextSpan(
        text: token,
        style: TextStyle(color: isMention ? Colors.lightBlueAccent : Colors.white, fontWeight: isMention ? FontWeight.w700 : null),
      ));
      cursor = match.end;
    }
    if (cursor < message.length) spans.add(TextSpan(text: message.substring(cursor)));
    return Text.rich(TextSpan(children: spans), style: const TextStyle(color: Colors.white, fontSize: 15));
  }

  Widget _buildGroupMediaPreview({
    required String mediaUrl,
    required String mediaType,
    required bool isMe,
    required bool isViewOnce,
    required bool hasBeenViewed,
    required String messageId,
  }) {
    final label = mediaType == 'video' ? 'Video' : 'Photo';
    final title = isViewOnce ? 'View once ${label.toLowerCase()}' : label;

    if (mediaUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    if (isViewOnce && !isMe && hasBeenViewed) {
      return _buildGroupViewOnceConsumedPreview(label);
    }

    final shouldMarkViewed = isViewOnce && !isMe && !hasBeenViewed;
    if (mediaType == 'image') {
      return GestureDetector(
        onTap: () => _openGroupMediaViewer(
          mediaUrl: mediaUrl,
          mediaType: mediaType,
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
                width: 260,
                height: 190,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(
                  width: 220,
                  height: 100,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
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
      onTap: () => _openGroupMediaViewer(
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        title: title,
        messageId: messageId,
        shouldMarkViewed: shouldMarkViewed,
      ),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_circle_outline,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
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

  Widget _buildGroupViewOnceConsumedPreview(String label) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white24,
            child: Icon(Icons.visibility_off_outlined, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Column(
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
              Text(
                'No longer available.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGroupFileAttachment(String mediaUrl, String mediaName) {
    return GestureDetector(
      onTap: () => launchUrl(
        Uri.parse(mediaUrl),
        mode: LaunchMode.externalApplication,
      ),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.insert_drive_file_outlined,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                mediaName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupPollBubble(
    GroupModel group,
    Map<String, dynamic> data,
    String messageId,
  ) {
    final metadata = Map<String, dynamic>.from(data['metadata'] ?? const {});
    final question =
        (metadata['question'] ?? data['message'] ?? 'Poll').toString();
    final options = List<dynamic>.from(metadata['options'] ?? const []);
    final votes = Map<String, dynamic>.from(metadata['votes'] ?? const {});
    final totalVotes = votes.values.fold<int>(
      0,
      (total, voters) => total + List<dynamic>.from(voters ?? const []).length,
    );

    return SizedBox(
      width: 280,
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
          const SizedBox(height: 10),
          for (var index = 0; index < options.length; index++)
            _buildPollOptionTile(
              label: options[index].toString(),
              count: List<dynamic>.from(votes['$index'] ?? const []).length,
              progress: totalVotes == 0
                  ? 0
                  : List<dynamic>.from(votes['$index'] ?? const []).length /
                      totalVotes,
              isSelected: List<String>.from(votes['$index'] ?? const [])
                  .contains(_chatService.currentUserId),
              onTap: () => _chatService.voteInGroupPoll(
                groupId: group.id,
                messageId: messageId,
                optionIndex: index,
              ),
            ),
          const SizedBox(height: 6),
          Text(
            '$totalVotes vote${totalVotes == 1 ? '' : 's'}',
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildPollOptionTile({
    required String label,
    required int count,
    required double progress,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? RegentColors.lightViolet
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 5,
                  value: progress.clamp(0, 1),
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    RegentColors.lightViolet,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openGroupMediaViewer({
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
              ? () => _chatService.markGroupMessageAsViewed(
                    groupId: widget.group.id,
                    messageId: messageId,
                  )
              : null,
        ),
      ),
    );
  }

  Widget _buildComposer(GroupModel group, bool canPost) {
    return SafeArea(
      top: false,
      child: Container(
        color: RegentColors.dmSurface,
        padding: const EdgeInsets.all(9),
        child: canPost
            ? Row(
                children: [
                  IconButton(
                    tooltip: 'Attach media',
                    onPressed:
                        _isSending ? null : () => _showAttachments(group),
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: RegentColors.lightViolet,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.black87),
                      cursorColor: RegentColors.darkViolet,
                      decoration: InputDecoration(
                        hintText: group.isChannel
                            ? 'Publish an update...'
                            : 'Message ${group.name}...',
                        hintStyle: const TextStyle(color: Colors.black54),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: RegentColors.lightViolet,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(group),
                      onChanged: (value) {
                        if (value.endsWith('@')) _showMentionPicker(group);
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'Mention a member',
                    onPressed: _isSending ? null : () => _showMentionPicker(group),
                    icon: const Icon(Icons.alternate_email, color: RegentColors.lightViolet),
                  ),
                  const SizedBox(width: 6),
                  _isSending
                      ? const Padding(
                          padding: EdgeInsets.all(11),
                          child: SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              color: RegentColors.lightViolet,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(
                            Icons.send,
                            color: RegentColors.lightViolet,
                          ),
                          onPressed: () => _sendMessage(group),
                        ),
                ],
              )
            : const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline, color: Colors.white54, size: 18),
                    SizedBox(width: 7),
                    Text(
                      'Only channel admins can post',
                      style: TextStyle(color: Colors.white60),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
