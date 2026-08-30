import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../models/group_model.dart';
import '../../../services/chat_service.dart';

class GroupDetailsScreen extends StatefulWidget {
  final GroupModel group;

  const GroupDetailsScreen({
    super.key,
    required this.group,
  });

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  final ChatService _chatService = ChatService();
  bool _isUpdating = false;

  Future<void> _updateTagging(GroupModel group, bool value) async {
    setState(() => _isUpdating = true);
    try {
      await _chatService.updateGroupStatusTagging(
        groupId: group.id,
        allowMembers: value,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? 'Members can now tag ${group.name} in statuses.'
                  : 'Only admins can now tag ${group.name} in statuses.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _updateGovernance(
    String groupId, {
    bool? membersCanPost,
    bool? requireApproval,
    bool? inviteLinkEnabled,
  }) async {
    setState(() => _isUpdating = true);
    try {
      await _chatService.updateGroupGovernance(
        groupId: groupId,
        membersCanPost: membersCanPost,
        requireApproval: requireApproval,
        inviteLinkEnabled: inviteLinkEnabled,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _manageMember(
    String groupId,
    String memberId, {
    required bool add,
  }) async {
    try {
      await _chatService.updateGroupMember(
        groupId: groupId,
        memberId: memberId,
        add: add,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _updateAdmin(
    String groupId,
    String memberId,
    bool makeAdmin,
  ) async {
    try {
      await _chatService.updateGroupAdmin(
        groupId: groupId,
        memberId: memberId,
        makeAdmin: makeAdmin,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _chatService.getGroupStream(widget.group.id),
      builder: (context, snapshot) {
        final document = snapshot.data;
        final group = document != null && document.exists
            ? GroupModel.fromMap({
                ...(document.data() as Map<String, dynamic>),
                'id': document.id,
              })
            : widget.group;
        final isAdmin = group.isAdmin(_chatService.currentUserId);
        final kindLabel = group.isChannel ? 'Channel' : 'Group';

        return Scaffold(
          appBar: AppBar(
            backgroundColor: RegentColors.violet,
            foregroundColor: Colors.white,
            title: Text('$kindLabel settings'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 58,
                  backgroundColor: (group.isChannel
                          ? RegentColors.blue
                          : RegentColors.violet)
                      .withOpacity(0.14),
                  backgroundImage: group.profilePictureUrl != null
                      ? NetworkImage(group.profilePictureUrl!)
                      : null,
                  child: group.profilePictureUrl == null
                      ? Icon(
                          group.isChannel ? Icons.campaign : Icons.groups_2,
                          size: 54,
                          color: group.isChannel
                              ? RegentColors.blue
                              : RegentColors.violet,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                group.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '$kindLabel • ${group.members.length} member${group.members.length == 1 ? '' : 's'}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              if (group.description.isNotEmpty) ...[
                const SizedBox(height: 22),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Text(group.description),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              const Text(
                'Permissions',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(
                        Icons.alternate_email,
                        color: RegentColors.violet,
                      ),
                      title: const Text(
                        'Allow member status tags',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        isAdmin
                            ? 'When off, only admins can tag this $kindLabel in a status.'
                            : group.allowMemberStatusTagging
                                ? 'Members may tag this $kindLabel in their statuses.'
                                : 'The admins have disabled member tagging.',
                      ),
                      value: group.allowMemberStatusTagging,
                      onChanged: isAdmin && !_isUpdating
                          ? (value) => _updateTagging(group, value)
                          : null,
                    ),
                    if (!group.isChannel)
                      SwitchListTile(
                        secondary: const Icon(Icons.forum_outlined),
                        title: const Text('Members can send messages'),
                        subtitle: const Text('Turn off for announcement-only mode.'),
                        value: group.membersCanPost,
                        onChanged: isAdmin && !_isUpdating
                            ? (value) => _updateGovernance(
                                  group.id,
                                  membersCanPost: value,
                                )
                            : null,
                      ),
                    SwitchListTile(
                      secondary: const Icon(Icons.how_to_reg_outlined),
                      title: const Text('Approve new members'),
                      subtitle: const Text('Admins approve requests before users join.'),
                      value: group.requireApproval,
                      onChanged: isAdmin && !_isUpdating
                          ? (value) => _updateGovernance(
                                group.id,
                                requireApproval: value,
                              )
                          : null,
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.link_outlined),
                      title: const Text('Allow invite link'),
                      value: group.inviteLinkEnabled,
                      onChanged: isAdmin && !_isUpdating
                          ? (value) => _updateGovernance(
                                group.id,
                                inviteLinkEnabled: value,
                              )
                            : null,
                    ),
                    if (group.isChannel) ...[
                      const Divider(height: 1),
                      const ListTile(
                        leading: Icon(
                          Icons.lock_outline,
                          color: RegentColors.blue,
                        ),
                        title: Text(
                          'Admin-only publishing',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle:
                            Text('Only channel admins can publish updates.'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Information',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: const Text('Created by'),
                      subtitle: Text(group.creatorName),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.calendar_today_outlined),
                      title: const Text('Created'),
                      subtitle: Text(
                        DateFormat('d MMM yyyy, h:mm a')
                            .format(group.createdAt),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.admin_panel_settings_outlined),
                      title: const Text('Admins'),
                      subtitle: Text('${group.adminIds.length}'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Members (${group.members.length})',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              if (isAdmin && group.pendingMembers.isNotEmpty)
                Card(
                  child: Column(
                    children: [
                      const ListTile(
                        leading: Icon(Icons.pending_actions),
                        title: Text('Pending approvals'),
                      ),
                      for (final memberId in group.pendingMembers)
                        ListTile(
                          title: Text(memberId),
                          trailing: Wrap(
                            children: [
                              IconButton(
                                tooltip: 'Approve',
                                icon: const Icon(Icons.check, color: Colors.green),
                                onPressed: () => _manageMember(
                                  group.id,
                                  memberId,
                                  add: true,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Reject',
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () => _manageMember(
                                  group.id,
                                  memberId,
                                  add: false,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              if (isAdmin && group.pendingMembers.isNotEmpty)
                const SizedBox(height: 8),
              for (final memberId in group.members)
                _MemberTile(
                  memberId: memberId,
                  isAdmin: group.isAdmin(memberId),
                  canManage: isAdmin && memberId != group.createdBy,
                  onToggleAdmin: (value) =>
                      _updateAdmin(group.id, memberId, value),
                  onRemove: () => _manageMember(
                    group.id,
                    memberId,
                    add: false,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MemberTile extends StatelessWidget {
  final String memberId;
  final bool isAdmin;
  final bool canManage;
  final ValueChanged<bool>? onToggleAdmin;
  final VoidCallback? onRemove;

  const _MemberTile({
    required this.memberId,
    required this.isAdmin,
    this.canManage = false,
    this.onToggleAdmin,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('users').doc(memberId).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final name = (data?['fullName'] ??
                data?['displayName'] ??
                data?['email'] ??
                'Member')
            .toString();
        final photo = data?['photoUrl']?.toString();
        return ListTile(
          leading: CircleAvatar(
            backgroundImage:
                photo != null && photo.isNotEmpty ? NetworkImage(photo) : null,
            child: photo == null || photo.isEmpty
                ? const Icon(Icons.person_outline)
                : null,
          ),
          title: Text(name),
          subtitle: isAdmin ? const Text('Admin') : null,
          trailing: canManage
              ? PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'admin') onToggleAdmin?.call(!isAdmin);
                    if (value == 'remove') onRemove?.call();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'admin',
                      child: Text(isAdmin ? 'Dismiss admin' : 'Make admin'),
                    ),
                    const PopupMenuItem(
                      value: 'remove',
                      child: Text('Remove from group'),
                    ),
                  ],
                )
              : isAdmin
                  ? const Icon(
                      Icons.admin_panel_settings,
                      color: RegentColors.violet,
                    )
                  : null,
        );
      },
    );
  }
}
