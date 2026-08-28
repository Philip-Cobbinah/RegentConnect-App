import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/official_accounts.dart';
import '../../../core/theme.dart';
import '../../../models/group_model.dart';
import '../../../services/chat_service.dart';
import '../../../services/official_office_service.dart';
import '../../auth/screens/officer_access_screen.dart';
import 'community_chat_screen.dart';
import 'official_account_profile_screen.dart';
import 'dm_screen.dart';

class ChatListTab extends StatefulWidget {
  final String filter;

  const ChatListTab({super.key, required this.filter});

  @override
  State<ChatListTab> createState() => _ChatListTabState();
}

class _ChatListTabState extends State<ChatListTab> {
  final ChatService _chatService = ChatService();
  final OfficialOfficeService _officeService = OfficialOfficeService();

  @override
  Widget build(BuildContext context) {
    if (widget.filter == 'Groups') {
      return _buildGroups();
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 150),
      children: [
        if (_officeService.currentOffice != null && widget.filter == 'All')
          _buildOfficerInboxBanner(),
        if (widget.filter == 'All') ...[
          _sectionHeader(
            'Official offices',
            'Verified Regent support',
            Icons.verified_rounded,
            action: IconButton(
              tooltip: 'How officers access and reply',
              onPressed: _openOfficerAccess,
              icon: const Icon(Icons.info_outline),
            ),
          ),
          SizedBox(
            height: 118,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: OfficialAccounts.accounts
                  .where(
                    (account) => account.id != _chatService.currentMessagingId,
                  )
                  .map(_buildOfficialCard)
                  .toList(),
            ),
          ),
          _sectionHeader(
            'Groups',
            'Your group conversations',
            Icons.groups_2_rounded,
          ),
          _buildGroupPreview(),
        ],
        _sectionHeader(
          widget.filter == 'Unread'
              ? 'Unread messages'
              : widget.filter == 'Favorites'
                  ? 'Favorite chats'
                  : 'Direct messages',
          widget.filter == 'Unread'
              ? 'Messages waiting for you'
              : widget.filter == 'Favorites'
                  ? 'People and offices you pinned for quick access'
                  : 'Your recent conversations',
          widget.filter == 'Favorites'
              ? Icons.star_rounded
              : Icons.chat_bubble_rounded,
        ),
        _buildDirectMessages(
          unreadOnly: widget.filter == 'Unread',
          favoriteOnly: widget.filter == 'Favorites',
        ),
      ],
    );
  }

  Widget _sectionHeader(
    String title,
    String subtitle,
    IconData icon, {
    Widget? action,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: RegentColors.violet.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: RegentColors.violet, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          if (action != null) action,
        ],
      ),
    );
  }

  Widget _buildOfficerInboxBanner() {
    final office = _officeService.currentOffice!;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 2),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [RegentColors.darkViolet, RegentColors.violet],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(Icons.support_agent, color: RegentColors.violet),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${office.office} inbox',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'You are replying with this verified office identity. Student conversations appear under Direct messages.',
                  style: TextStyle(color: Colors.white, height: 1.35),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Officer access guide',
            onPressed: _openOfficerAccess,
            icon: const Icon(Icons.help_outline, color: Colors.white),
          ),
        ],
      ),
    );
  }

  void _openOfficerAccess() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OfficerAccessScreen()),
    );
  }

  Widget _buildOfficialCard(OfficialAccountDefinition account) {
    return SizedBox(
      width: 190,
      child: Card(
        margin: const EdgeInsets.only(right: 10, bottom: 6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openOfficialProfile(account.toDirectoryMap()),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 22,
                  backgroundColor: RegentColors.violet,
                  child: Icon(Icons.account_balance, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              account.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const Icon(
                            Icons.verified,
                            color: RegentColors.blue,
                            size: 16,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        account.office,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade600,
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
      ),
    );
  }

  Widget _buildGroupPreview() {
    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.getMyGroups(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 76,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final groups = _groupsFrom(snapshot.data?.docs ?? const []);
        if (groups.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Create or join a group to see it here.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          );
        }

        return Column(
          children: groups.take(3).map(_buildGroupTile).toList(),
        );
      },
    );
  }

  Widget _buildGroups() {
    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.getMyGroups(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _emptyState(
            Icons.error_outline,
            'Groups could not be loaded',
            snapshot.error.toString(),
          );
        }

        final groups = _groupsFrom(snapshot.data?.docs ?? const []);
        if (groups.isEmpty) {
          return _emptyState(
            Icons.groups_2_outlined,
            'No groups yet',
            'Use the add button to create your first group.',
          );
        }

        return ListView(
          padding: const EdgeInsets.only(bottom: 150, top: 8),
          children: [
            for (final group in groups) _buildGroupTile(group),
          ],
        );
      },
    );
  }

  List<GroupModel> _groupsFrom(List<QueryDocumentSnapshot> documents) {
    final groups = documents
        .map((document) {
          return GroupModel.fromMap({
            ...(document.data() as Map<String, dynamic>),
            'id': document.id,
          });
        })
        .where((group) => group.isGroup)
        .toList();
    groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return groups;
  }

  Widget _buildGroupTile(GroupModel group) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: RegentColors.violet,
        backgroundImage: group.profilePictureUrl != null
            ? NetworkImage(group.profilePictureUrl!)
            : null,
        child: group.profilePictureUrl == null
            ? const Icon(Icons.groups_2, color: Colors.white)
            : null,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              group.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (group.isAdmin(_chatService.currentUserId))
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(
                Icons.admin_panel_settings,
                size: 17,
                          color: RegentColors.green,
              ),
            ),
        ],
      ),
      subtitle: Text(
        'Group • ${group.members.length} member${group.members.length == 1 ? '' : 's'}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CommunityChatScreen(group: group),
          ),
        );
      },
    );
  }

  Widget _buildDirectMessages({
    required bool unreadOnly,
    required bool favoriteOnly,
  }) {
    return StreamBuilder<Set<String>>(
      stream: _chatService.getFavoriteContactIds(),
      builder: (context, snapshot) {
        final favorites = snapshot.data ?? <String>{};
        return StreamBuilder<QuerySnapshot>(
          stream: _chatService.getChatRooms(),
          builder: (context, chatSnapshot) {
            if (chatSnapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (chatSnapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Messages could not be loaded: ${chatSnapshot.error}',
                ),
              );
            }

            final rooms = [...?chatSnapshot.data?.docs];
            rooms.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aTime = aData['lastMessageTime'] as Timestamp?;
              final bTime = bData['lastMessageTime'] as Timestamp?;
              return (bTime?.millisecondsSinceEpoch ?? 0)
                  .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
            });

            final matchingRooms = rooms.where((room) {
              if (!favoriteOnly) return true;
              final roomData = room.data() as Map<String, dynamic>;
              final participants =
                  List<String>.from(roomData['participants'] ?? const []);
              final otherId = participants.firstWhere(
                (id) => id != _chatService.currentMessagingId,
                orElse: () => '',
              );
              return favorites.contains(otherId);
            }).toList();
            if (matchingRooms.isEmpty) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                child: Text(
                  unreadOnly
                      ? 'You are all caught up.'
                      : favoriteOnly
                          ? 'No favorite chats yet. Long-press a chat to add it here.'
                          : 'No direct messages yet. Open Find Users to start one.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              );
            }

            return Column(
              children: matchingRooms.map((room) {
                final roomData = room.data() as Map<String, dynamic>;
                final participants =
                    List<String>.from(roomData['participants'] ?? const []);
                final otherId = participants.firstWhere(
                  (id) => id != _chatService.currentMessagingId,
                  orElse: () => '',
                );
                if (otherId.isEmpty) return const SizedBox.shrink();
                return _buildDirectMessageTile(
                  otherId: otherId,
                  roomData: roomData,
                  unreadOnly: unreadOnly,
                  isFavorite: favorites.contains(otherId),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  Widget _buildDirectMessageTile({
    required String otherId,
    required Map<String, dynamic> roomData,
    required bool unreadOnly,
    required bool isFavorite,
  }) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _chatService.getUserData(otherId),
      builder: (context, userSnapshot) {
        final user = userSnapshot.data;
        if (user == null) {
          return userSnapshot.connectionState == ConnectionState.waiting
              ? const LinearProgressIndicator(minHeight: 1)
              : const SizedBox.shrink();
        }

        final tile = _directMessageTile(user, roomData, isFavorite: isFavorite);
        if (!unreadOnly) return tile;

        return StreamBuilder<int>(
          stream: _chatService.getUnreadCountForChat(otherId),
          builder: (context, unreadSnapshot) {
            final unreadCount = unreadSnapshot.data ?? 0;
            if (unreadCount == 0) return const SizedBox.shrink();
            return _directMessageTile(
              user,
              roomData,
              unreadCount: unreadCount,
              isFavorite: isFavorite,
            );
          },
        );
      },
    );
  }

  Widget _directMessageTile(
    Map<String, dynamic> user,
    Map<String, dynamic> roomData, {
    int unreadCount = 0,
    required bool isFavorite,
  }) {
    final name =
        (user['fullName'] ?? user['displayName'] ?? 'Unknown user').toString();
    final photo = user['photoUrl']?.toString();
    final isOfficial = user['isOfficial'] == true;
    final time = roomData['lastMessageTime'] as Timestamp?;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            isOfficial ? RegentColors.violet : Colors.grey.shade300,
        backgroundImage:
            photo != null && photo.isNotEmpty ? NetworkImage(photo) : null,
        child: photo == null || photo.isEmpty
            ? Icon(
                isOfficial ? Icons.account_balance : Icons.person,
                color: isOfficial ? Colors.white : Colors.grey.shade700,
              )
            : null,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (isOfficial)
            const Padding(
              padding: EdgeInsets.only(left: 5),
              child: Icon(Icons.verified, color: RegentColors.blue, size: 16),
            ),
        ],
      ),
      subtitle: Text(
        (roomData['lastMessage'] ?? 'Start a conversation').toString(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTime(time),
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
          ),
          if (isFavorite)
            const Padding(
              padding: EdgeInsets.only(top: 3),
              child: Icon(Icons.star_rounded, size: 16, color: Colors.amber),
            ),
          if (unreadCount > 0) ...[
            const SizedBox(height: 5),
            CircleAvatar(
              radius: 10,
              backgroundColor: RegentColors.violet,
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(color: Colors.white, fontSize: 9),
              ),
            ),
          ],
        ],
      ),
      onTap: () => _openDirectMessage(user),
      onLongPress: () => _toggleFavorite(user, isFavorite),
    );
  }

  Future<void> _toggleFavorite(
    Map<String, dynamic> user,
    bool isFavorite,
  ) async {
    final identity =
        (user['chatIdentity'] ?? user['uid'] ?? user['userId']).toString();
    final name =
        (user['fullName'] ?? user['displayName'] ?? 'This chat').toString();
    try {
      final nowFavorite = await _chatService.toggleFavoriteContact(
        identity,
        contactName: name,
        shouldFavorite: !isFavorite,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nowFavorite
              ? '$name added to favorites'
              : '$name removed from favorites'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Favorite could not be updated: $error')),
      );
    }
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.day}/${date.month}';
  }

  void _openDirectMessage(Map<String, dynamic> user) {
    final identity =
        (user['chatIdentity'] ?? user['uid'] ?? user['userId']).toString();
    final name =
        (user['fullName'] ?? user['displayName'] ?? 'Unknown user').toString();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DMScreen(
          recipientId: identity,
          recipientName: name,
          recipientPhoto: user['photoUrl']?.toString(),
        ),
      ),
    );
  }

  void _openOfficialProfile(Map<String, dynamic> account) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OfficialAccountProfileScreen(account: account),
      ),
    );
  }

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
