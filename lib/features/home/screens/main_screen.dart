import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/call_service.dart';
import '../../../services/chat_service.dart';
import '../../../services/status_service.dart';
import '../../../core/theme.dart';
import '../../../core/theme_provider.dart';
import '../../../widgets/wave_clipper.dart';
import '../../../widgets/regent_ai_fab.dart';
import '../../chat/screens/chat_list_tab.dart';
import '../../chat/screens/regent_chat_search_delegate.dart';
import '../../calls/screens/calls_tab.dart';
import '../../status/screens/status_tab.dart';
import '../../status/screens/view_status_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../p_questions/screens/academics_tab.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  int _selectedFilter = 0;
  StreamSubscription<QuerySnapshot>? _statusSubscription;
  final Set<String> _knownStatusIds = <String>{};
  bool _hasLoadedStatuses = false;
  Map<String, dynamic>? _newStatusNotice;
  Timer? _statusNoticeTimer;

  final _chatService = ChatService();
  final _callService = CallService();
  final _statusService = StatusService();

  final List<String> _filters = [
    'All',
    'Unread',
    'Favorites',
    'Groups',
    'Archived',
  ];

  @override
  void initState() {
    super.initState();
    _listenForStatusUpdates();
  }

  void _listenForStatusUpdates() {
    _statusSubscription = _statusService.getAllStatuses().listen((snapshot) {
      final isFirstSnapshot = !_hasLoadedStatuses;
      final newStatuses = <Map<String, dynamic>>[];
      for (final change in snapshot.docChanges) {
        final data = change.doc.data() as Map<String, dynamic>;
        final statusId = change.doc.id;
        if (change.type == DocumentChangeType.added &&
            !_knownStatusIds.contains(statusId) &&
            data['userId'] != _statusService.currentUserId) {
          newStatuses.add({...data, 'statusId': statusId});
        }
        _knownStatusIds.add(statusId);
      }
      _hasLoadedStatuses = true;
      if (isFirstSnapshot || newStatuses.isEmpty || !mounted) return;
      _showNewStatusNotice(newStatuses.last);
    });
  }

  void _showNewStatusNotice(Map<String, dynamic> status) {
    _statusNoticeTimer?.cancel();
    setState(() => _newStatusNotice = status);
    _statusNoticeTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _newStatusNotice = null);
    });
  }

  void _openNewStatusNotice() {
    final status = _newStatusNotice;
    _statusNoticeTimer?.cancel();
    setState(() => _newStatusNotice = null);
    if (status == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewStatusScreen(statuses: [status], isOwner: false),
      ),
    );
  }

  @override
  void dispose() {
    _statusNoticeTimer?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final gradientColor1 =
        isDark ? RegentColors.darkBackground : RegentColors.primaryDark;
    final gradientColor2 =
        isDark ? RegentColors.darkSurface : RegentColors.primary;

    return Scaffold(
      body: Stack(
        children: [
          // Main Content with Navigation
          Column(
            children: [
              // Top Wave Header
              _buildTopHeader(gradientColor1, gradientColor2, isDark),

              // Content Area - changes based on tab
              Expanded(
                child: _buildContent(),
              ),
            ],
          ),

          // Bottom Navigation with Wave - Always visible
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child:
                _buildBottomNavigation(gradientColor1, gradientColor2, isDark),
          ),

          // Regent AI FAB
          const RegentAICrystalFab(),

          if (_newStatusNotice != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: GestureDetector(
                onTap: _openNewStatusNotice,
                child: Material(
                  elevation: 10,
                  color: RegentColors.dmSurface,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: RegentColors.violet,
                          backgroundImage:
                              _newStatusNotice!['userPhoto'] != null
                                  ? NetworkImage(
                                      _newStatusNotice!['userPhoto'].toString(),
                                    )
                                  : null,
                          child: _newStatusNotice!['userPhoto'] == null
                              ? Text(
                                  (_newStatusNotice!['userName'] ?? 'U')
                                      .toString()
                                      .characters
                                      .first
                                      .toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${_newStatusNotice!['userName'] ?? 'Someone'} added a new status',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white70),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopHeader(Color color1, Color color2, bool isDark) {
    return SizedBox(
      height: 180,
      child: Stack(
        children: [
          // Wave Background
          CustomPaint(
            size: Size(MediaQuery.of(context).size.width, 180),
            painter: WavePainter(
              color1: color1,
              color2: color2,
              isTop: true,
            ),
          ),

          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // App Title and Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Regent Connect',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Tooltip(
                            message: 'Search',
                            child: IconButton(
                              icon:
                                  const Icon(Icons.search, color: Colors.white),
                              onPressed: () => _showSearch(),
                            ),
                          ),
                          Tooltip(
                            message: 'Find Users',
                            child: IconButton(
                              icon:
                                  const Icon(Icons.people, color: Colors.white),
                              onPressed: () => _showAllUsers(),
                            ),
                          ),
                          Tooltip(
                            message: 'Camera',
                            child: IconButton(
                              icon: const Icon(Icons.camera_alt_outlined,
                                  color: Colors.white),
                              onPressed: () => _navigateToTab(2),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Filter Chips - Only show on Chats tab (index 0)
                  if (_currentIndex == 0)
                    Row(
                      children: [
                        // Filter Chips
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: List.generate(_filters.length, (index) {
                                final isSelected = _selectedFilter == index;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _selectedFilter = index),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _filters[index],
                                        style: TextStyle(
                                          color: isSelected
                                              ? color1
                                              : Colors.white,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),

                        // Add Button
                        Tooltip(
                          message: 'Create New',
                          child: GestureDetector(
                            onTap: () => _showNewOptions(),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 80),
      child: IndexedStack(
        index: _currentIndex,
        children: [
          ChatListTab(filter: _filters[_selectedFilter]),
          const CallsTab(),
          const StatusTab(),
          const AcademicsTab(),
          const SettingsScreen(),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation(Color color1, Color color2, bool isDark) {
    return SizedBox(
      height: 100,
      child: Stack(
        children: [
          // Wave Background
          CustomPaint(
            size: Size(MediaQuery.of(context).size.width, 100),
            painter: WavePainter(
              color1: color1,
              color2: color2,
              isTop: false,
            ),
          ),
          // Navigation Items
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Container(
                height: 70,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(0, Icons.chat_bubble_rounded, 'Chats'),
                    _buildNavItem(1, Icons.call_rounded, 'Calls'),
                    _buildNavItem(2, Icons.donut_large_rounded, 'Status'),
                    _buildNavItem(3, Icons.school_rounded, 'Academics'),
                    _buildNavItem(4, Icons.settings_rounded, 'Settings'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;

    Stream<int>? badgeStream;
    if (index == 0) badgeStream = _chatService.getTotalUnreadCount();
    if (index == 1) badgeStream = _callService.getUnreadCallCount();
    if (index == 2) badgeStream = _statusService.getUnreadStatusCount();

    return GestureDetector(
      onTap: () => _navigateToTab(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.white70,
                  size: isSelected ? 28 : 24,
                ),
                if (badgeStream != null)
                  StreamBuilder<int>(
                    stream: badgeStream,
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      if (count == 0) return const SizedBox.shrink();
                      return Positioned(
                        right: -12,
                        top: -9,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 18),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: RegentColors.green,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: color1ForBadge(context)),
                          ),
                          child: Text(
                            count > 99 ? '99+' : '$count',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color color1ForBadge(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? RegentColors.darkBackground
        : RegentColors.primaryDark;
  }

  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
    if (index == 1) {
      _callService.markCallHistoryAsRead();
    }
  }

  void _showSearch() {
    showSearch(
      context: context,
      delegate: RegentChatSearchDelegate(),
    );
  }

  void _showAllUsers() {
    Navigator.pushNamed(context, '/users');
  }

  void _showNewOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Create New',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: RegentColors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chat, color: RegentColors.green),
                ),
                title: const Text('New Chat'),
                subtitle: const Text('Start a conversation'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/users');
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.group_add, color: Colors.blue),
                ),
                title: const Text('New Group'),
                subtitle: const Text('Create a study group'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/create-group');
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.campaign, color: Colors.orange),
                ),
                title: const Text('New Broadcast'),
                subtitle: const Text('Send to multiple contacts'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/broadcast');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
