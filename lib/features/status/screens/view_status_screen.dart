import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../../core/theme.dart';
import '../../../services/chat_service.dart';
import '../../../services/status_service.dart';

class ViewStatusScreen extends StatefulWidget {
  final List<Map<String, dynamic>> statuses;
  final bool isOwner;

  const ViewStatusScreen({
    super.key,
    required this.statuses,
    required this.isOwner,
  });

  @override
  State<ViewStatusScreen> createState() => _ViewStatusScreenState();
}

class _ViewStatusScreenState extends State<ViewStatusScreen>
    with SingleTickerProviderStateMixin {
  final StatusService _statusService = StatusService();
  final ChatService _chatService = ChatService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  int _currentIndex = 0;
  late AnimationController _progressController;
  VideoPlayerController? _videoController;
  Future<void>? _videoInitialization;
  String? _videoError;
  int _statusLoadGeneration = 0;
  int _videoTrimStartMs = 0;
  int _videoTrimEndMs = 0;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _nextStatus();
        }
      });

    _loadStatus();
  }

  void _loadStatus() {
    _prepareStatus();
  }

  Future<void> _prepareStatus() async {
    final generation = ++_statusLoadGeneration;
    final status = widget.statuses[_currentIndex];
    final previousController = _videoController;
    _videoController = null;
    _videoInitialization = null;
    _videoError = null;
    previousController?.removeListener(_handleVideoProgress);
    await previousController?.dispose();

    // Mark as viewed if not owner
    if (!widget.isOwner) {
      _statusService.viewStatus(status['statusId']);
    }

    if (status['type'] != 'video' || status['mediaUrl'] == null) {
      _progressController.duration = const Duration(seconds: 5);
      _progressController.forward(from: 0);
      if (mounted) setState(() {});
      return;
    }

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(status['mediaUrl'].toString()),
    );
    _videoController = controller;
    final initialization = controller.initialize();
    _videoInitialization = initialization;
    try {
      await initialization;
      if (!mounted || generation != _statusLoadGeneration) {
        await controller.dispose();
        return;
      }

      final totalMs = controller.value.duration.inMilliseconds;
      final rawStart = status['trimStartMs'];
      final rawEnd = status['trimEndMs'];
      _videoTrimStartMs =
          rawStart is num ? rawStart.toInt().clamp(0, totalMs) : 0;
      _videoTrimEndMs = rawEnd is num
          ? rawEnd.toInt().clamp(_videoTrimStartMs, totalMs)
          : totalMs.clamp(0, 30000);
      if (_videoTrimEndMs <= _videoTrimStartMs) {
        _videoTrimEndMs = (_videoTrimStartMs + 30000).clamp(0, totalMs);
      }

      await controller.setVolume(status['isMuted'] == true ? 0 : 1);
      await controller.seekTo(Duration(milliseconds: _videoTrimStartMs));
      controller.addListener(_handleVideoProgress);
      _progressController.duration = Duration(
        milliseconds: (_videoTrimEndMs - _videoTrimStartMs).clamp(500, 30000),
      );
      _progressController.forward(from: 0);
      await controller.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (!mounted || generation != _statusLoadGeneration) return;
      _videoError = 'This video could not be played.';
      _progressController.duration = const Duration(seconds: 5);
      _progressController.forward(from: 0);
      setState(() {});
    }
  }

  void _handleVideoProgress() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.position.inMilliseconds >= _videoTrimEndMs &&
        _progressController.status != AnimationStatus.completed) {
      _progressController.value = 1;
    }
  }

  void _nextStatus() {
    if (_currentIndex < widget.statuses.length - 1) {
      setState(() => _currentIndex++);
      _loadStatus();
    } else {
      Navigator.pop(context);
    }
  }

  void _previousStatus() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _loadStatus();
    }
  }

  @override
  void dispose() {
    _statusLoadGeneration++;
    final controller = _videoController;
    controller?.removeListener(_handleVideoProgress);
    controller?.dispose();
    _audioPlayer.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.statuses[_currentIndex];

    return Scaffold(
      backgroundColor: status['type'] == 'text'
          ? Color(int.parse(
              status['backgroundColor']?.replaceFirst('#', '0xFF') ??
                  '0xFF7C4DFF'))
          : Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.localPosition.dx < width / 2) {
            _previousStatus();
          } else {
            _nextStatus();
          }
        },
        onLongPressStart: (_) {
          _progressController.stop();
          _videoController?.pause();
        },
        onLongPressEnd: (_) {
          _progressController.forward();
          _videoController?.play();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Status content
            _buildStatusContent(status),

            // Top bar
            SafeArea(
              child: Column(
                children: [
                  // Progress indicators
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: List.generate(widget.statuses.length, (index) {
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            height: 3,
                            child: AnimatedBuilder(
                              animation: _progressController,
                              builder: (context, child) {
                                double progress = 0;
                                if (index < _currentIndex) {
                                  progress = 1;
                                } else if (index == _currentIndex) {
                                  progress = _progressController.value;
                                }
                                return LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Colors.white30,
                                  valueColor: const AlwaysStoppedAnimation(
                                      Colors.white),
                                );
                              },
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  // User info
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: RegentColors.violet,
                          backgroundImage: status['userPhoto'] != null
                              ? NetworkImage(status['userPhoto'])
                              : null,
                          child: status['userPhoto'] == null
                              ? Text(
                                  (status['userName'] ?? 'U')[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                status['userName'] ?? 'Unknown',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _getTimeAgo(status['createdAt']),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Status options',
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          onPressed: () => _showStatusOptions(status),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  if (status['taggedGroupId'] != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white38),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              status['taggedGroupKind'] == 'channel'
                                  ? Icons.campaign
                                  : Icons.groups_2,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '@${status['taggedGroupName'] ?? 'Community'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Bottom bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      if (widget.isOwner) ...[
                        // View count for owner
                        GestureDetector(
                          onTap: () => _showViewers(status),
                          child: Row(
                            children: [
                              const Icon(Icons.visibility,
                                  color: Colors.white70, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '${status['viewCount'] ?? 0}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${List<String>.from(status['likedBy'] ?? const []).length} likes',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.white70),
                          onPressed: () => _deleteStatus(status['statusId']),
                        ),
                      ] else ...[
                        // Reply for viewers
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _showReplyComposer(status),
                              borderRadius: BorderRadius.circular(25),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white30),
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: const Text(
                                  'Reply...',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Like',
                          icon: Icon(
                            List<String>.from(status['likedBy'] ?? const [])
                                    .contains(_statusService.currentUserId)
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: Colors.pinkAccent,
                          ),
                          onPressed: () => _toggleLike(status),
                        ),
                        IconButton(
                          tooltip: 'React',
                          icon: const Icon(
                            Icons.emoji_emotions_outlined,
                            color: Colors.white70,
                          ),
                          onPressed: () => _showQuickReactions(status),
                        ),
                        if (status['allowReshare'] == true) ...[
                          const SizedBox(width: 10),
                          IconButton(
                            icon:
                                const Icon(Icons.share, color: Colors.white70),
                            onPressed: () => _reshareStatus(status['statusId']),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Reshared indicator
            if (status['isReshared'] == true)
              Positioned(
                top: status['taggedGroupId'] != null ? 142 : 100,
                left: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.repeat, color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'From ${status['originalUserName']}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showStatusOptions(Map<String, dynamic> status) async {
    _progressController.stop();
    await _videoController?.pause();
    if (!mounted) return;

    final isOwner = widget.isOwner;
    final allowReshare = status['allowReshare'] == true;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: RegentColors.dmSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility, color: Colors.white70),
              title: const Text('Viewers', style: TextStyle(color: Colors.white)),
              onTap: isOwner
                  ? () {
                      Navigator.pop(sheetContext);
                      _showViewers(status);
                    }
                  : null,
            ),
            if (!isOwner)
              ListTile(
                leading: const Icon(Icons.reply, color: Colors.white70),
                title: const Text('Reply', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showReplyComposer(status);
                },
              ),
            if (!isOwner)
              ListTile(
                leading: const Icon(Icons.emoji_emotions_outlined,
                    color: Colors.white70),
                title: const Text('React', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showQuickReactions(status);
                },
              ),
            if (!isOwner && allowReshare)
              ListTile(
                leading: const Icon(Icons.share, color: Colors.white70),
                title: const Text('Reshare', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _reshareStatus(status['statusId'].toString());
                },
              ),
            if (isOwner)
              ListTile(
                leading: Icon(
                  allowReshare ? Icons.repeat_on_rounded : Icons.repeat_rounded,
                  color: Colors.white70,
                ),
                title: Text(
                  allowReshare ? 'Turn off resharing' : 'Turn on resharing',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  try {
                    await _statusService.updateReshareSettings(
                      status['statusId'].toString(),
                      !allowReshare,
                    );
                    if (mounted) {
                      setState(() => status['allowReshare'] = !allowReshare);
                    }
                  } catch (_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Status settings could not be updated.')),
                      );
                    }
                  }
                },
              ),
            if (isOwner)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _deleteStatus(status['statusId'].toString());
                },
              ),
          ],
        ),
      ),
    );
    if (mounted) {
      _progressController.forward();
      _videoController?.play();
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> status) async {
    final statusId = status['statusId']?.toString();
    if (statusId == null || statusId.isEmpty) return;
    try {
      final liked = await _statusService.toggleLikeStatus(statusId);
      final likedBy = List<String>.from(status['likedBy'] ?? const []);
      if (liked && !likedBy.contains(_statusService.currentUserId)) {
        likedBy.add(_statusService.currentUserId);
      } else if (!liked) {
        likedBy.remove(_statusService.currentUserId);
      }
      if (mounted) setState(() => status['likedBy'] = likedBy);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The like could not be updated.')),
        );
      }
    }
  }

  Widget _buildStatusContent(Map<String, dynamic> status) {
    final type = status['type'];

    if (type == 'text') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            status['text'] ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else if (type == 'image') {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (status['mediaUrl'] != null)
            Image.network(
              status['mediaUrl'],
              fit: BoxFit.contain,
            ),
          if (status['text'] != null && status['text'].isNotEmpty)
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status['text'],
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      );
    } else if (type == 'audio') {
      return Center(
        child: InkWell(
          onTap: () => _audioPlayer.play(
            UrlSource(status['mediaUrl']?.toString() ?? ''),
          ),
          borderRadius: BorderRadius.circular(48),
          child: const CircleAvatar(
            radius: 48,
            backgroundColor: RegentColors.violet,
            child: Icon(Icons.play_arrow, color: Colors.white, size: 54),
          ),
        ),
      );
    } else {
      final isMuted = status['isMuted'] == true;

      return Stack(
        fit: StackFit.expand,
        children: [
          _buildVideoContent(),

          // Muted indicator
          if (isMuted)
            Positioned(
              top: 100,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.volume_off, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Muted',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

          if (status['text'] != null && status['text'].isNotEmpty)
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status['text'],
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      );
    }
  }

  Widget _buildVideoContent() {
    if (_videoError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 72,
            ),
            const SizedBox(height: 12),
            Text(
              _videoError!,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    final controller = _videoController;
    final initialization = _videoInitialization;
    if (controller == null || initialization == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return FutureBuilder<void>(
      future: initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            !controller.value.isInitialized) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        return Center(
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio > 0
                ? controller.value.aspectRatio
                : 16 / 9,
            child: VideoPlayer(controller),
          ),
        );
      },
    );
  }

  String _getTimeAgo(dynamic timestamp) {
    if (timestamp == null) return 'Just now';
    DateTime date;
    if (timestamp is DateTime) {
      date = timestamp;
    } else {
      date = timestamp.toDate();
    }
    final diff = DateTime.now().difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _showReplyComposer(Map<String, dynamic> status) async {
    _progressController.stop();
    await _videoController?.pause();
    if (!mounted) return;
    final replyController = TextEditingController();
    var isSending = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: RegentColors.dmSurface,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> sendReply() async {
              final reply = replyController.text.trim();
              final receiverId = status['userId']?.toString() ?? '';
              if (reply.isEmpty || receiverId.isEmpty || isSending) return;
              setSheetState(() => isSending = true);
              try {
                await _chatService.sendMessage(
                  receiverId: receiverId,
                  message: reply,
                  metadata: _statusReplyMetadata(status),
                );
                if (sheetContext.mounted) Navigator.pop(sheetContext);
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Reply sent')),
                  );
                }
              } catch (_) {
                if (sheetContext.mounted) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    const SnackBar(
                      content: Text('The reply could not be sent.'),
                    ),
                  );
                  setSheetState(() => isSending = false);
                }
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  14,
                  16,
                  14 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: replyController,
                        autofocus: true,
                        maxLength: 700,
                        maxLines: 4,
                        minLines: 1,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => sendReply(),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText:
                              'Reply to ${status['userName'] ?? 'status'}',
                          prefixIcon: const Icon(
                            Icons.reply_rounded,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Send reply',
                      onPressed: isSending ? null : sendReply,
                      icon: isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    replyController.dispose();
    if (mounted) {
      _progressController.forward();
      _videoController?.play();
    }
  }

  Future<void> _showQuickReactions(Map<String, dynamic> status) async {
    _progressController.stop();
    await _videoController?.pause();
    if (!mounted) return;
    const reactions = ['❤️', '😂', '😮', '😢', '🙏', '👏'];
    final reaction = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: RegentColors.dmSurface,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: reactions.map((emoji) {
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => Navigator.pop(context, emoji),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(emoji, style: const TextStyle(fontSize: 30)),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
    if (reaction != null) {
      final receiverId = status['userId']?.toString() ?? '';
      if (receiverId.isNotEmpty) {
        try {
          await _chatService.sendMessage(
            receiverId: receiverId,
            message: reaction,
            metadata: {
              ..._statusReplyMetadata(status),
              'isStatusReaction': true,
            },
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$reaction reaction sent')),
            );
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('The reaction could not be sent.'),
              ),
            );
          }
        }
      }
    }
    if (mounted) {
      _progressController.forward();
      _videoController?.play();
    }
  }

  Map<String, dynamic> _statusReplyMetadata(
    Map<String, dynamic> status,
  ) {
    return {
      'isStatusReply': true,
      'statusId': status['statusId'],
      'statusPosterId': status['userId'],
      'statusType': status['type'],
      'statusText': status['text'],
      'statusMediaUrl': status['mediaUrl'],
      'statusPosterName': status['userName'],
    };
  }

  void _showViewers(Map<String, dynamic> status) {
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
        builder: (context, scrollController) {
          final views = List<Map<String, dynamic>>.from(status['views'] ?? []);

          return Column(
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
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.visibility, color: Colors.white70),
                    const SizedBox(width: 8),
                    Text(
                      'Viewed by ${views.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: views.isEmpty
                    ? const Center(
                        child: Text(
                          'No views yet',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: views.length,
                        itemBuilder: (context, index) {
                          final view = views[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: RegentColors.violet,
                              backgroundImage: view['userPhoto'] != null
                                  ? NetworkImage(view['userPhoto'])
                                  : null,
                              child: view['userPhoto'] == null
                                  ? Text(
                                      (view['userName'] ?? 'U')[0]
                                          .toUpperCase(),
                                      style:
                                          const TextStyle(color: Colors.white),
                                    )
                                  : null,
                            ),
                            title: Text(
                              view['userName'] ?? 'Unknown',
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              view['viewedAt'] ?? '',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteStatus(String statusId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RegentColors.dmSurface,
        title:
            const Text('Delete Status', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this status?',
          style: TextStyle(color: Colors.white70),
        ),
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
      await _statusService.deleteStatus(statusId);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _reshareStatus(String statusId) async {
    try {
      await _statusService.reshareStatus(statusId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status reshared!'),
            backgroundColor: RegentColors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
