import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/official_accounts.dart';
import '../../../core/theme.dart';
import '../../../services/auth_service.dart';
import '../../../services/call_service.dart';
import '../../../services/chat_service.dart';
import '../../../widgets/active_call_overlay.dart';
import '../../calls/screens/video_call_screen.dart';
import '../../chat/screens/official_account_profile_screen.dart';
import '../../chat/screens/dm_screen.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final AuthService _authService = AuthService();
  final CallService _callService = CallService();
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();

  final List<String> _filters = const [
    'All',
    'Officials',
    'Online',
    'My Program',
  ];
  String _selectedFilter = 'All';
  String? _currentProgram;

  @override
  void initState() {
    super.initState();
    _loadCurrentProgram();
  }

  Future<void> _loadCurrentProgram() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;
    final document =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (mounted) {
      setState(() => _currentProgram = document.data()?['program']?.toString());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerColors = isDark
        ? const [RegentColors.darkBackground, RegentColors.darkSurface]
        : const [RegentColors.primaryDark, RegentColors.primary];

    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.paddingOf(context).top + 12,
              16,
              18,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: headerColors,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Find people & offices',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: Colors.black87),
                  cursorColor: RegentColors.darkViolet,
                  decoration: InputDecoration(
                    hintText: 'Search name, office, email, or program',
                    hintStyle: const TextStyle(color: Colors.black54),
                    prefixIcon:
                        const Icon(Icons.search, color: RegentColors.violet),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close),
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: RegentColors.lightViolet,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 58,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              children: [
                for (final filter in _filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: _selectedFilter == filter,
                      onSelected: (_) {
                        setState(() => _selectedFilter = filter);
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _emptyState(
                    Icons.error_outline,
                    'Directory unavailable',
                    snapshot.error.toString(),
                  );
                }

                final firestoreUsers = (snapshot.data?.docs ?? const [])
                    .map(
                      (document) => {
                        ...(document.data() as Map<String, dynamic>),
                        'documentId': document.id,
                        'authUid': document.id,
                      },
                    )
                    .toList();
                var users = OfficialAccounts.search(
                  OfficialAccounts.mergeDirectory(firestoreUsers),
                  _searchController.text,
                );
                users = users.where((user) {
                  final identity =
                      (user['chatIdentity'] ?? user['uid']).toString();
                  if (identity == _chatService.currentMessagingId) return false;
                  if (_selectedFilter == 'Officials') {
                    return user['isOfficial'] == true;
                  }
                  if (_selectedFilter == 'Online') {
                    return user['isOnline'] == true;
                  }
                  if (_selectedFilter == 'My Program') {
                    return _currentProgram != null &&
                        user['program']?.toString() == _currentProgram;
                  }
                  return true;
                }).toList();

                users.sort((a, b) {
                  final officialComparison = (b['isOfficial'] == true ? 1 : 0)
                      .compareTo(a['isOfficial'] == true ? 1 : 0);
                  if (officialComparison != 0) return officialComparison;
                  return _nameOf(a).compareTo(_nameOf(b));
                });

                if (users.isEmpty) {
                  return _emptyState(
                    Icons.people_outline,
                    'No matches',
                    'Try a different name, office, email, or filter.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 24),
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 3),
                  itemBuilder: (context, index) =>
                      _buildUserTile(users[index], isDark),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user, bool isDark) {
    final name = _nameOf(user);
    final isOfficial = user['isOfficial'] == true;
    final photo = user['photoUrl']?.toString();
    final subtitle = isOfficial
        ? (user['department'] ?? user['program'] ?? 'Official Regent office')
            .toString()
        : [
            user['program'],
            user['level'] == null ? null : 'Level ${user['level']}',
            user['session'],
          ].where((value) => value != null && value.toString().isNotEmpty).join(
              ' • ',
            );

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 27,
              backgroundColor: isOfficial
                  ? RegentColors.violet
                  : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
              backgroundImage: photo != null && photo.isNotEmpty
                  ? NetworkImage(photo)
                  : null,
              child: photo == null || photo.isEmpty
                  ? Icon(
                      isOfficial ? Icons.account_balance : Icons.person,
                      color: isOfficial ? Colors.white : Colors.grey.shade700,
                    )
                  : null,
            ),
            if (user['isOnline'] == true)
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).cardColor,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
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
                child: Icon(Icons.verified, color: RegentColors.blue, size: 17),
              ),
          ],
        ),
        subtitle: Text(
          subtitle.isEmpty ? (user['email'] ?? '').toString() : subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Message',
              icon: const Icon(
                Icons.chat_bubble_rounded,
                color: RegentColors.violet,
              ),
              onPressed: () => _startChat(user),
            ),
            if (!isOfficial) ...[
              IconButton(
                tooltip: 'Voice call',
                icon: const Icon(
                  Icons.call_rounded,
                  color: RegentColors.green,
                ),
                onPressed: () => _startCall(user, isVideo: false),
              ),
              IconButton(
                tooltip: 'Video call',
                icon: const Icon(
                  Icons.videocam_rounded,
                  color: RegentColors.blue,
                ),
                onPressed: () => _startCall(user, isVideo: true),
              ),
            ],
          ],
        ),
        onTap: () => _showUserProfile(user),
      ),
    );
  }

  void _startChat(Map<String, dynamic> user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DMScreen(
          recipientId: (user['chatIdentity'] ?? user['uid'] ?? user['userId'])
              .toString(),
          recipientName: _nameOf(user),
          recipientPhoto: user['photoUrl']?.toString(),
        ),
      ),
    );
  }

  Future<void> _startCall(
    Map<String, dynamic> user, {
    required bool isVideo,
  }) async {
    final recipientId =
        (user['authUid'] ?? user['uid'] ?? user['userId'] ?? '').toString();
    if (recipientId.isEmpty) return;

    try {
      final currentUserId = _authService.currentUser?.uid;
      if (currentUserId == null) {
        throw const CallException('Sign in before starting a call.');
      }
      final currentUser = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      final callerData = currentUser.data();
      final callerName = callerData?['fullName'] ??
          callerData?['displayName'] ??
          callerData?['email'] ??
          'Regent user';
      final recipientName = _nameOf(user);
      final recipientPhoto = user['photoUrl']?.toString();
      final callId = await _callService.initiateCall(
        receiverId: recipientId,
        receiverName: recipientName,
        callerName: callerName.toString(),
        isVideo: isVideo,
        callerPhoto: callerData?['photoUrl']?.toString(),
        receiverPhoto: recipientPhoto,
      );

      if (!mounted) return;
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoCallScreen(
            callId: callId,
            recipientId: recipientId,
            recipientName: recipientName,
            recipientPhoto: recipientPhoto,
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
          const SnackBar(content: Text('The call could not be started.')),
        );
      }
    }
  }

  void _showUserProfile(Map<String, dynamic> user) {
    final isOfficial = user['isOfficial'] == true;
    final name = _nameOf(user);

    if (isOfficial) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OfficialAccountProfileScreen(account: user),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor:
                    isOfficial ? RegentColors.violet : Colors.grey.shade300,
                child: Icon(
                  isOfficial ? Icons.account_balance : Icons.person,
                  color: isOfficial ? Colors.white : Colors.grey.shade700,
                  size: 36,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (isOfficial)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(Icons.verified, color: RegentColors.blue),
                    ),
                ],
              ),
              Text(
                (user['email'] ?? '').toString(),
                style: TextStyle(color: Colors.grey.shade600),
              ),
              if ((user['session'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Session: ${user['session']}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
              const SizedBox(height: 18),
              if ((user['about'] ?? '').toString().isNotEmpty)
                Text(
                  user['about'].toString(),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _startChat(user);
                  },
                  icon: const Icon(Icons.chat_bubble),
                  label: Text('Message $name'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _nameOf(Map<String, dynamic> user) {
    return (user['fullName'] ??
            user['displayName'] ??
            user['email'] ??
            'Unknown user')
        .toString();
  }

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
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
