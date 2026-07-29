import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../models/group_model.dart';
import '../../../models/status_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/chat_service.dart';
import '../../../services/status_service.dart';
import '../../chat/screens/community_chat_screen.dart';
import '../../chat/screens/create_group_screen.dart';
import 'status_screen.dart';

class StatusTab extends StatefulWidget {
  const StatusTab({super.key});

  @override
  State<StatusTab> createState() => _StatusTabState();
}

class _StatusTabState extends State<StatusTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authService = AuthService();
    final statusService = StatusService();
    final chatService = ChatService();
    final currentUser = authService.currentUser;

    return StreamBuilder<List<StatusModel>>(
      stream: statusService.getActiveStatuses(),
      builder: (context, snapshot) {
        final allStatuses = snapshot.data ?? const <StatusModel>[];
        final groupedStatuses = <String, List<StatusModel>>{};
        for (final status in allStatuses) {
          if (!_matchesStatus(status)) continue;
          groupedStatuses.putIfAbsent(status.postedBy, () => []).add(status);
        }

        final myStatuses = allStatuses
            .where((status) => status.postedBy == currentUser?.uid)
            .toList();
        final otherStatuses =
            Map<String, List<StatusModel>>.from(groupedStatuses)
              ..remove(currentUser?.uid);

        return ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 150),
          children: [
            _buildSearchField(context),
            _buildMyStatus(
              context,
              isDark: isDark,
              displayName: currentUser?.displayName,
              statusCount: myStatuses.length,
            ),
            Divider(color: isDark ? Colors.white12 : Colors.grey.shade300),
            _sectionHeader(
              context,
              title: 'Recent updates',
              subtitle: 'Status posts from your connections',
            ),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (snapshot.hasError)
              _inlineMessage(
                context,
                icon: Icons.cloud_off_rounded,
                message: 'Status updates could not be loaded.',
              )
            else if (otherStatuses.isEmpty)
              _inlineMessage(
                context,
                icon: _searchQuery.isEmpty
                    ? Icons.donut_large_outlined
                    : Icons.search_off_rounded,
                message: _searchQuery.isEmpty
                    ? 'No recent status updates.'
                    : 'No status updates match your search.',
              )
            else
              ...otherStatuses.entries.map((entry) {
                final userStatuses = entry.value
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                final latestStatus = userStatuses.first;
                final posterName = latestStatus.posterName.trim().isEmpty
                    ? 'Regent user'
                    : latestStatus.posterName.trim();

                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: RegentColors.statusAccent,
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      backgroundImage: latestStatus.posterPhotoUrl != null
                          ? NetworkImage(latestStatus.posterPhotoUrl!)
                          : null,
                      child: latestStatus.posterPhotoUrl == null
                          ? Text(posterName[0].toUpperCase())
                          : null,
                    ),
                  ),
                  title: Text(
                    posterName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(_getTimeAgo(latestStatus.createdAt)),
                  trailing: userStatuses.length > 1
                      ? _countBadge(context, userStatuses.length)
                      : null,
                  onTap: () => _openStatus(context),
                );
              }),
            const SizedBox(height: 12),
            Divider(color: isDark ? Colors.white12 : Colors.grey.shade300),
            _buildChannelsSection(context, chatService),
          ],
        );
      },
    );
  }

  Widget _buildMyStatus(
    BuildContext context, {
    required bool isDark,
    required String? displayName,
    required int statusCount,
  }) {
    final hasStatus = statusCount > 0;
    final safeName = displayName?.trim();
    final initial =
        safeName == null || safeName.isEmpty ? '?' : safeName[0].toUpperCase();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: hasStatus ? RegentColors.statusAccent : Colors.grey,
                width: 2,
              ),
            ),
            child: CircleAvatar(
              radius: 26,
              backgroundColor:
                  isDark ? RegentColors.darkCard : RegentColors.primarySoft,
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          if (!hasStatus)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: RegentColors.statusAccent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 14),
              ),
            ),
        ],
      ),
      title: const Text(
        'My status',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        hasStatus
            ? '$statusCount update${statusCount == 1 ? '' : 's'}'
            : 'Tap to add status',
      ),
      onTap: () => _openStatus(context),
    );
  }

  Widget _buildChannelsSection(BuildContext context, ChatService chatService) {
    return StreamBuilder<QuerySnapshot>(
      stream: chatService.getMyGroups(),
      builder: (context, snapshot) {
        final channels = _channelsFrom(snapshot.data?.docs ?? const []);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(
              context,
              title: 'Channels',
              subtitle: 'Updates from communities you follow',
              action: TextButton.icon(
                onPressed: () => _createChannel(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New'),
              ),
            ),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (snapshot.hasError)
              _inlineMessage(
                context,
                icon: Icons.cloud_off_rounded,
                message: 'Channels could not be loaded.',
              )
            else if (channels.isEmpty && _searchQuery.isNotEmpty)
              _inlineMessage(
                context,
                icon: Icons.search_off_rounded,
                message: 'No channels match your search.',
              )
            else if (channels.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: RegentColors.primarySoft,
                          child: Icon(
                            Icons.campaign_rounded,
                            color: RegentColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No channels yet',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Create a channel to share announcements and updates.',
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Create channel',
                          onPressed: () => _createChannel(context),
                          icon: const Icon(Icons.arrow_forward_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...channels.map(
                (entry) => _channelTile(context, entry, chatService),
              ),
          ],
        );
      },
    );
  }

  Widget _channelTile(
    BuildContext context,
    _ChannelEntry entry,
    ChatService chatService,
  ) {
    final group = entry.group;
    final lastMessage = entry.data['lastMessage']?.toString().trim();
    final description = group.description.trim();
    final subtitle = lastMessage?.isNotEmpty == true
        ? lastMessage!
        : description.isNotEmpty
            ? description
            : 'Channel updates';
    final time = entry.data['lastMessageTime'];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 25,
        backgroundColor: RegentColors.primary,
        backgroundImage: group.profilePictureUrl?.isNotEmpty == true
            ? NetworkImage(group.profilePictureUrl!)
            : null,
        child: group.profilePictureUrl?.isNotEmpty == true
            ? null
            : const Icon(Icons.campaign_rounded, color: Colors.white),
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
          if (group.isAdmin(chatService.currentUserId))
            const Padding(
              padding: EdgeInsets.only(left: 5),
              child: Icon(
                Icons.verified_rounded,
                size: 17,
                color: RegentColors.primary,
              ),
            ),
        ],
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTimestamp(time),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 3),
          Text(
            '${group.members.length} follower${group.members.length == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
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

  List<_ChannelEntry> _channelsFrom(
    List<QueryDocumentSnapshot> documents,
  ) {
    final channels = documents
        .map((document) {
          final data = document.data() as Map<String, dynamic>;
          final group = GroupModel.fromMap({...data, 'id': document.id});
          return _ChannelEntry(group: group, data: data);
        })
        .where((entry) => entry.group.isChannel && _matchesChannel(entry))
        .toList();
    channels.sort((a, b) {
      return _dateFor(b).compareTo(_dateFor(a));
    });
    return channels;
  }

  DateTime _dateFor(_ChannelEntry entry) {
    final lastMessageTime = entry.data['lastMessageTime'];
    return lastMessageTime is Timestamp
        ? lastMessageTime.toDate()
        : entry.group.createdAt;
  }

  Widget _buildSearchField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: SearchBar(
        controller: _searchController,
        hintText: 'Search status and channels',
        leading: const Icon(Icons.search_rounded),
        trailing: [
          if (_searchQuery.isNotEmpty)
            IconButton(
              tooltip: 'Clear search',
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              icon: const Icon(Icons.close_rounded),
            ),
        ],
        onChanged: (value) {
          setState(() => _searchQuery = value.trim().toLowerCase());
        },
      ),
    );
  }

  bool _matchesStatus(StatusModel status) {
    if (_searchQuery.isEmpty) return true;
    return status.posterName.toLowerCase().contains(_searchQuery) ||
        status.content.toLowerCase().contains(_searchQuery) ||
        (status.taggedGroupName?.toLowerCase().contains(_searchQuery) ?? false);
  }

  bool _matchesChannel(_ChannelEntry entry) {
    if (_searchQuery.isEmpty) return true;
    final lastMessage =
        entry.data['lastMessage']?.toString().toLowerCase() ?? '';
    return entry.group.name.toLowerCase().contains(_searchQuery) ||
        entry.group.description.toLowerCase().contains(_searchQuery) ||
        lastMessage.contains(_searchQuery);
  }

  Widget _sectionHeader(
    BuildContext context, {
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (action != null) action,
        ],
      ),
    );
  }

  Widget _inlineMessage(
    BuildContext context, {
    required IconData icon,
    required String message,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              message,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
        ],
      ),
    );
  }

  Widget _countBadge(BuildContext context, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  void _openStatus(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StatusScreen()),
    );
  }

  void _createChannel(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateGroupScreen(initialKind: 'channel'),
      ),
    );
  }

  String _formatTimestamp(dynamic rawTimestamp) {
    if (rawTimestamp is! Timestamp) return '';
    final date = rawTimestamp.toDate();
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    if (isToday) {
      return '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.day}/${date.month}';
  }

  String _getTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _ChannelEntry {
  final GroupModel group;
  final Map<String, dynamic> data;

  const _ChannelEntry({
    required this.group,
    required this.data,
  });
}
