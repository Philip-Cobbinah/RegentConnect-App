import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../../services/chat_service.dart';
import '../../../services/status_service.dart';
import 'dm_screen.dart';
import '../../status/screens/view_status_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _chatService = ChatService();
  final _statusService = StatusService();
  final _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _messageSearchResults = [];
  bool _isLoadingSearch = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query != _searchQuery) {
      setState(() => _searchQuery = query);
      if (query.isNotEmpty) {
        _performSearch(query);
      } else {
        setState(() {
          _searchResults = [];
          _messageSearchResults = [];
        });
      }
    }
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoadingSearch = true);

    try {
      // Search users
      final usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();

      final userResults = usersSnapshot.docs
          .where((doc) {
            final data = doc.data();
            final name = (data['fullName'] ?? '').toString().toLowerCase();
            final email = (data['email'] ?? '').toString().toLowerCase();
            return name.contains(query.toLowerCase()) ||
                email.contains(query.toLowerCase());
          })
          .where((doc) => doc.id != _chatService.currentUserId)
          .map((doc) => {
                ...doc.data(),
                'userId': doc.id,
                'type': 'user',
              })
          .toList();

      // Search messages in all chat rooms
      final chatRooms = await FirebaseFirestore.instance
          .collection(AppConstants.chatsCollection)
          .where(
            'participants',
            arrayContains: _chatService.currentMessagingId,
          )
          .get();

      final messageResults = <Map<String, dynamic>>[];

      for (var room in chatRooms.docs) {
        final messages = await FirebaseFirestore.instance
            .collection(AppConstants.chatsCollection)
            .doc(room.id)
            .collection('messages')
            .where('isDeleted', isEqualTo: false)
            .get();

        for (var msg in messages.docs) {
          final data = msg.data();
          final messageText = (data['message'] ?? '').toString().toLowerCase();

          if (messageText.contains(query.toLowerCase())) {
            final participants =
                List<String>.from(room.data()['participants'] ?? []);
            final otherUserId = participants.firstWhere(
              (id) => id != _chatService.currentMessagingId,
              orElse: () => '',
            );

            if (otherUserId.isNotEmpty) {
              final userData = await _chatService.getUserData(otherUserId);
              messageResults.add({
                'messageId': msg.id,
                'message': data['message'],
                'senderId': data['senderId'],
                'senderName': data['senderName'],
                'timestamp': data['timestamp'],
                'otherUserId': otherUserId,
                'otherUserName':
                    userData?['fullName'] ?? userData?['email'] ?? 'Unknown',
                'otherUserPhoto': userData?['photoUrl'],
                'type': 'message',
                'chatRoomId': room.id,
              });
            }
          }
        }
      }

      // Sort messages by timestamp
      messageResults.sort((a, b) {
        final aTime = a['timestamp'] as Timestamp?;
        final bTime = b['timestamp'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      setState(() {
        _searchResults = userResults;
        _messageSearchResults =
            messageResults.take(20).toList(); // Limit to 20 results
        _isLoadingSearch = false;
      });
    } catch (e) {
      setState(() => _isLoadingSearch = false);
      debugPrint('Search error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RegentColors.dmBackground,
      appBar: AppBar(
        backgroundColor: RegentColors.dmSurface,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search users or messages...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                ),
              )
            : Row(
                children: [
                  const Text('Messages', style: TextStyle(color: Colors.white)),
                  const SizedBox(width: 8),
                  // Unread count badge
                  StreamBuilder<int>(
                    stream: _chatService.getTotalUnreadCount(),
                    builder: (context, snapshot) {
                      final unreadCount = snapshot.data ?? 0;
                      if (unreadCount == 0) return const SizedBox.shrink();

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: RegentColors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
        actions: [
          // Unread filter button
          StreamBuilder<int>(
            stream: _chatService.getTotalUnreadCount(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon:
                        const Icon(Icons.mark_chat_unread, color: Colors.white),
                    onPressed: () => _showUnreadChats(),
                    tooltip: 'Unread messages',
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search,
                color: Colors.white),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchResults = [];
                  _messageSearchResults = [];
                  _searchQuery = '';
                }
              });
            },
          ),
        ],
      ),
      body: _isSearching && _searchQuery.isNotEmpty
          ? _buildSearchResults()
          : _buildChatList(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: RegentColors.violet,
        child: const Icon(Icons.chat, color: Colors.white),
        onPressed: () => _showUsersList(context),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isLoadingSearch) {
      return const Center(
        child: CircularProgressIndicator(color: RegentColors.violet),
      );
    }

    if (_searchResults.isEmpty && _messageSearchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off,
                size: 64, color: RegentColors.violet.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'No results for "$_searchQuery"',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try searching for a different name or message',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        // Users section
        if (_searchResults.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.people, color: RegentColors.violet, size: 20),
                const SizedBox(width: 8),
                Text(
                  'People (${_searchResults.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          ..._searchResults.map((user) => _buildUserSearchTile(user)),
          const Divider(color: RegentColors.dmCard, height: 32),
        ],

        // Messages section
        if (_messageSearchResults.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.message, color: RegentColors.violet, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Messages (${_messageSearchResults.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          ..._messageSearchResults.map((msg) => _buildMessageSearchTile(msg)),
        ],
      ],
    );
  }

  Widget _buildUserSearchTile(Map<String, dynamic> user) {
    final userName = user['fullName'] ?? user['email'] ?? 'Unknown';
    final userPhoto = user['photoUrl'];
    final userId = user['userId'] as String;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: RegentColors.violet,
        backgroundImage: userPhoto != null ? NetworkImage(userPhoto) : null,
        child: userPhoto == null
            ? Text(
                userName[0].toUpperCase(),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              )
            : null,
      ),
      title: _highlightText(userName, _searchQuery),
      subtitle: Text(
        user['email'] ?? '',
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
      trailing:
          const Icon(Icons.chat_bubble_outline, color: RegentColors.violet),
      onTap: () {
        setState(() {
          _isSearching = false;
          _searchController.clear();
        });
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DMScreen(
              recipientId: userId,
              recipientName: userName,
              recipientPhoto: userPhoto,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageSearchTile(Map<String, dynamic> msg) {
    final message = msg['message'] ?? '';
    final otherUserName = msg['otherUserName'] ?? 'Unknown';
    final otherUserPhoto = msg['otherUserPhoto'];
    final timestamp = msg['timestamp'] as Timestamp?;
    final senderName = msg['senderName'] ?? 'Unknown';
    final isMe = msg['senderId'] == _chatService.currentMessagingId;

    String timeStr = '';
    if (timestamp != null) {
      final date = timestamp.toDate();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final msgDay = DateTime(date.year, date.month, date.day);

      if (msgDay == today) {
        timeStr =
            '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else if (msgDay == today.subtract(const Duration(days: 1))) {
        timeStr = 'Yesterday';
      } else {
        timeStr = '${date.day}/${date.month}/${date.year}';
      }
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: RegentColors.dmCard,
        backgroundImage:
            otherUserPhoto != null ? NetworkImage(otherUserPhoto) : null,
        child: otherUserPhoto == null
            ? Text(
                otherUserName[0].toUpperCase(),
                style: const TextStyle(color: Colors.white),
              )
            : null,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              otherUserName,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            timeStr,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isMe ? 'You' : senderName,
            style: TextStyle(
              color: RegentColors.lightViolet,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          _highlightText(message, _searchQuery, maxLines: 2),
        ],
      ),
      isThreeLine: true,
      onTap: () {
        setState(() {
          _isSearching = false;
          _searchController.clear();
        });
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DMScreen(
              recipientId: msg['otherUserId'],
              recipientName: otherUserName,
              recipientPhoto: otherUserPhoto,
              highlightMessageId: msg['messageId'], // For scrolling to message
            ),
          ),
        );
      },
    );
  }

  Widget _highlightText(String text, String query, {int maxLines = 1}) {
    if (query.isEmpty) {
      return Text(
        text,
        style: const TextStyle(color: Colors.white),
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final startIndex = lowerText.indexOf(lowerQuery);

    if (startIndex == -1) {
      return Text(
        text,
        style: const TextStyle(color: Colors.white),
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    final endIndex = startIndex + query.length;

    return RichText(
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        children: [
          if (startIndex > 0)
            TextSpan(
              text: text.substring(0, startIndex),
              style: const TextStyle(color: Colors.white70),
            ),
          TextSpan(
            text: text.substring(startIndex, endIndex),
            style: const TextStyle(
              color: Colors.white,
              backgroundColor: RegentColors.violet,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (endIndex < text.length)
            TextSpan(
              text: text.substring(endIndex),
              style: const TextStyle(color: Colors.white70),
            ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.getChatRooms(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
              child: Text('Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white)));
        }

        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: RegentColors.violet));
        }

        final chatRooms = snapshot.data!.docs;

        if (chatRooms.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 80, color: RegentColors.violet.withOpacity(0.5)),
                const SizedBox(height: 16),
                const Text(
                  'No conversations yet',
                  style: TextStyle(color: Colors.white70, fontSize: 18),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Start a chat with someone!',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: chatRooms.length,
          itemBuilder: (context, index) {
            final data = chatRooms[index].data() as Map<String, dynamic>;
            final participants = List<String>.from(data['participants'] ?? []);
            final otherUserId = participants.firstWhere(
              (id) => id != _chatService.currentMessagingId,
              orElse: () => '',
            );

            if (otherUserId.isEmpty) return const SizedBox();

            return FutureBuilder<Map<String, dynamic>?>(
              future: _chatService.getUserData(otherUserId),
              builder: (context, userSnapshot) {
                final userData = userSnapshot.data;
                final userName =
                    userData?['fullName'] ?? userData?['email'] ?? 'Unknown';
                final userPhoto = userData?['photoUrl'];
                final lastMessage = data['lastMessage'] ?? '';
                final lastTime = data['lastMessageTime'] as Timestamp?;

                // Format time based on how recent
                String timeStr = '';
                if (lastTime != null) {
                  final now = DateTime.now();
                  final messageDate = lastTime.toDate();
                  final today = DateTime(now.year, now.month, now.day);
                  final msgDay = DateTime(
                      messageDate.year, messageDate.month, messageDate.day);

                  if (msgDay == today) {
                    // Today - show time
                    timeStr =
                        '${messageDate.hour.toString().padLeft(2, '0')}:${messageDate.minute.toString().padLeft(2, '0')}';
                  } else if (msgDay ==
                      today.subtract(const Duration(days: 1))) {
                    // Yesterday
                    timeStr = 'Yesterday';
                  } else if (now.difference(messageDate).inDays < 7) {
                    // Within a week - show day name
                    final days = [
                      'Mon',
                      'Tue',
                      'Wed',
                      'Thu',
                      'Fri',
                      'Sat',
                      'Sun'
                    ];
                    timeStr = days[messageDate.weekday - 1];
                  } else {
                    // Older - show date
                    timeStr =
                        '${messageDate.day}/${messageDate.month}/${messageDate.year}';
                  }
                }

                // Check if there's typing
                return StreamBuilder<DocumentSnapshot>(
                  stream: _chatService.getTypingStatus(otherUserId),
                  builder: (context, typingSnapshot) {
                    String subtitleText = lastMessage;
                    bool isTyping = false;

                    if (typingSnapshot.hasData && typingSnapshot.data!.exists) {
                      final typingData =
                          typingSnapshot.data!.data() as Map<String, dynamic>?;
                      final typing =
                          typingData?['typing'] as Map<String, dynamic>?;
                      if (typing?[otherUserId] != null) {
                        subtitleText = 'typing...';
                        isTyping = true;
                      }
                    }

                    return _ChatListTile(
                      userId: otherUserId,
                      userName: userName,
                      userPhoto: userPhoto,
                      lastMessage: subtitleText,
                      timeStr: timeStr,
                      isTyping: isTyping,
                      statusService: _statusService,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DMScreen(
                              recipientId: otherUserId,
                              recipientName: userName,
                              recipientPhoto: userPhoto,
                            ),
                          ),
                        );
                      },
                      onStatusTap: (statuses) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ViewStatusScreen(
                              statuses: statuses,
                              isOwner: false,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  void _showUsersList(BuildContext context) {
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
                'Start a conversation',
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
                        subtitle: Text(userData['email'] ?? '',
                            style: const TextStyle(color: Colors.white54)),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DMScreen(
                                recipientId: userId,
                                recipientName: userName,
                                recipientPhoto: userPhoto,
                              ),
                            ),
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
    );
  }

  void _showUnreadChats() {
    showModalBottomSheet(
      context: context,
      backgroundColor: RegentColors.dmSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.mark_chat_unread,
                      color: RegentColors.violet),
                  const SizedBox(width: 12),
                  const Text(
                    'Unread Messages',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      // Mark all as read
                      Navigator.pop(context);
                      _markAllAsRead();
                    },
                    child: const Text('Mark all read'),
                  ),
                ],
              ),
            ),
            const Divider(color: RegentColors.dmCard, height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _chatService.getChatRooms(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child:
                          CircularProgressIndicator(color: RegentColors.violet),
                    );
                  }

                  final chatRooms = snapshot.data!.docs;

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: chatRooms.length,
                    itemBuilder: (context, index) {
                      final data =
                          chatRooms[index].data() as Map<String, dynamic>;
                      final participants =
                          List<String>.from(data['participants'] ?? []);
                      final otherUserId = participants.firstWhere(
                        (id) => id != _chatService.currentMessagingId,
                        orElse: () => '',
                      );

                      if (otherUserId.isEmpty) return const SizedBox();

                      return StreamBuilder<int>(
                        stream: _chatService.getUnreadCountForChat(otherUserId),
                        builder: (context, unreadSnapshot) {
                          final unreadCount = unreadSnapshot.data ?? 0;
                          if (unreadCount == 0) return const SizedBox.shrink();

                          return FutureBuilder<Map<String, dynamic>?>(
                            future: _chatService.getUserData(otherUserId),
                            builder: (context, userSnapshot) {
                              final userData = userSnapshot.data;
                              final userName = userData?['fullName'] ??
                                  userData?['email'] ??
                                  'Unknown';
                              final userPhoto = userData?['photoUrl'];

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: RegentColors.violet,
                                  backgroundImage: userPhoto != null
                                      ? NetworkImage(userPhoto)
                                      : null,
                                  child: userPhoto == null
                                      ? Text(
                                          userName[0].toUpperCase(),
                                          style: const TextStyle(
                                              color: Colors.white),
                                        )
                                      : null,
                                ),
                                title: Text(
                                  userName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  '$unreadCount unread message${unreadCount > 1 ? 's' : ''}',
                                  style: const TextStyle(
                                      color: RegentColors.lightViolet),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: RegentColors.green,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$unreadCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DMScreen(
                                        recipientId: otherUserId,
                                        recipientName: userName,
                                        recipientPhoto: userPhoto,
                                      ),
                                    ),
                                  );
                                },
                              );
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
    );
  }

  Future<void> _markAllAsRead() async {
    // This would mark all messages as read
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All messages marked as read'),
        backgroundColor: RegentColors.violet,
      ),
    );
  }

  // Add this helper method to the class
  Future<bool?> _showCallConfirmationDialog(
    BuildContext context, {
    required String userName,
    required String? userPhoto,
    required bool isVideo,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RegentColors.dmSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: RegentColors.violet.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isVideo ? Icons.videocam : Icons.call,
                color: RegentColors.violet,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isVideo ? 'Video Call' : 'Voice Call',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: RegentColors.violet,
              backgroundImage:
                  userPhoto != null ? NetworkImage(userPhoto) : null,
              child: userPhoto == null
                  ? Text(
                      userName[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              userName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isVideo
                  ? 'Are you sure you want to start a video call with this person?'
                  : 'Are you sure you want to call this person?',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isVideo ? RegentColors.violet : RegentColors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: Icon(isVideo ? Icons.videocam : Icons.call, size: 18),
            label: Text(isVideo ? 'Video Call' : 'Call'),
          ),
        ],
      ),
    );
  }
}

// Separate widget to handle status checking for each chat tile
class _ChatListTile extends StatelessWidget {
  final String userId;
  final String userName;
  final String? userPhoto;
  final String lastMessage;
  final String timeStr;
  final bool isTyping;
  final StatusService statusService;
  final VoidCallback onTap;
  final Function(List<Map<String, dynamic>>) onStatusTap;

  const _ChatListTile({
    required this.userId,
    required this.userName,
    required this.userPhoto,
    required this.lastMessage,
    required this.timeStr,
    this.isTyping = false,
    required this.statusService,
    required this.onTap,
    required this.onStatusTap,
  });

  @override
  Widget build(BuildContext context) {
    final chatService = ChatService();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('statuses')
          .where('userId', isEqualTo: userId)
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .snapshots(),
      builder: (context, statusSnapshot) {
        final hasStatus =
            statusSnapshot.hasData && statusSnapshot.data!.docs.isNotEmpty;
        final statuses = hasStatus
            ? statusSnapshot.data!.docs
                .map((doc) => doc.data() as Map<String, dynamic>)
                .toList()
            : <Map<String, dynamic>>[];

        bool hasUnviewedStatus = false;
        if (hasStatus) {
          for (var status in statuses) {
            final views =
                List<Map<String, dynamic>>.from(status['views'] ?? []);
            final hasViewed = views
                .any((view) => view['userId'] == statusService.currentUserId);
            if (!hasViewed) {
              hasUnviewedStatus = true;
              break;
            }
          }
        }

        return StreamBuilder<int>(
          stream: chatService.getUnreadCountForChat(userId),
          builder: (context, unreadSnapshot) {
            final unreadCount = unreadSnapshot.data ?? 0;

            return ListTile(
              leading: GestureDetector(
                onTap: hasStatus ? () => onStatusTap(statuses) : null,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: hasStatus
                      ? BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: hasUnviewedStatus
                                ? [
                                    RegentColors.violet,
                                    RegentColors.darkViolet,
                                    RegentColors.lightViolet
                                  ]
                                : [Colors.grey, Colors.grey.shade600],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        )
                      : null,
                  child: Container(
                    padding:
                        hasStatus ? const EdgeInsets.all(2) : EdgeInsets.zero,
                    decoration: hasStatus
                        ? const BoxDecoration(
                            shape: BoxShape.circle,
                            color: RegentColors.dmBackground,
                          )
                        : null,
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: RegentColors.violet,
                      backgroundImage:
                          userPhoto != null ? NetworkImage(userPhoto!) : null,
                      child: userPhoto == null
                          ? Text(
                              userName[0].toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              title: Text(
                userName,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                lastMessage,
                style: TextStyle(
                  color: isTyping ? RegentColors.lightViolet : Colors.white54,
                  fontStyle: isTyping ? FontStyle.italic : FontStyle.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeStr,
                    style: TextStyle(
                      color: unreadCount > 0
                          ? RegentColors.violet
                          : Colors.white54,
                      fontSize: 12,
                      fontWeight:
                          unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: RegentColors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else if (hasStatus && hasUnviewedStatus)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: RegentColors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              onTap: onTap,
            );
          },
        );
      },
    );
  }
}
