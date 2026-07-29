import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme.dart';
import '../../../features/chat/widgets/chat_media_viewer.dart';
import '../../../models/academic_post_model.dart';
import '../../../services/academic_service.dart';
import 'academic_post_editor_screen.dart';

enum _AcademicFeedScope { forYou, assignments, lectures, mine }

String _academicRoleLabel(String role) {
  switch (role) {
    case 'lecturer':
      return 'Lecturer';
    case 'official':
      return 'Academic Office';
    case 'class_rep':
    default:
      return 'Class Rep';
  }
}

class AcademicsTab extends StatefulWidget {
  const AcademicsTab({super.key});

  @override
  State<AcademicsTab> createState() => _AcademicsTabState();
}

class _AcademicsTabState extends State<AcademicsTab>
    with SingleTickerProviderStateMixin {
  final _service = AcademicService();
  final _searchController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  late final TabController _tabController;

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = currentUser?.uid ?? '';

    if (currentUser == null) {
      return const Center(
        child: Text('Please sign in to access the academics hub.'),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('users').doc(currentUserId).snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting &&
            !userSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final userData = userSnapshot.data?.data() ?? <String, dynamic>{};
        final currentLevel = int.tryParse(userData['level']?.toString() ?? '');
        final programValue = userData['program'] == null
            ? null
            : userData['program'].toString().trim();
        final currentProgram = (programValue != null && programValue.isNotEmpty)
            ? programValue
            : null;
        final sessionValue = userData['session'] == null
            ? null
            : userData['session'].toString().trim();
        final currentSession = (sessionValue != null && sessionValue.isNotEmpty)
            ? sessionValue
            : null;
        final rawName = userData['fullName'] == null
            ? null
            : userData['fullName'].toString().trim();
        final currentName = (rawName != null && rawName.isNotEmpty)
            ? rawName
            : currentUser.displayName ?? 'Student';

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _service.watchAcademicPosts(),
          builder: (context, postsSnapshot) {
            if (postsSnapshot.connectionState == ConnectionState.waiting &&
                !postsSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final allPosts = (postsSnapshot.data?.docs ?? const [])
                .map((doc) => AcademicPostModel.fromMap(doc.data(), doc.id))
                .where((post) => !post.isArchived)
                .toList();

            final visiblePosts = _filterPosts(
              allPosts,
              scope: _AcademicFeedScope.forYou,
              currentUserId: currentUserId,
              currentLevel: currentLevel,
              currentProgram: currentProgram,
            );
            final assignmentPosts = _filterPosts(
              allPosts,
              scope: _AcademicFeedScope.assignments,
              currentUserId: currentUserId,
              currentLevel: currentLevel,
              currentProgram: currentProgram,
            );
            final lecturePosts = _filterPosts(
              allPosts,
              scope: _AcademicFeedScope.lectures,
              currentUserId: currentUserId,
              currentLevel: currentLevel,
              currentProgram: currentProgram,
            );
            final myPosts = _filterPosts(
              allPosts,
              scope: _AcademicFeedScope.mine,
              currentUserId: currentUserId,
              currentLevel: currentLevel,
              currentProgram: currentProgram,
            );

            final dueSoonCount = assignmentPosts.where((post) {
              if (post.dueAt == null) return false;
              final remaining = post.dueAt!.difference(DateTime.now()).inDays;
              return remaining >= 0 && remaining <= 7;
            }).length;

            return Column(
              children: [
                _buildHero(
                  context,
                  userName: currentName,
                  currentLevel: currentLevel,
                  currentProgram: currentProgram,
                  currentSession: currentSession,
                  visibleCount: visiblePosts.length,
                  assignmentCount: assignmentPosts.length,
                  lectureCount: lecturePosts.length,
                  dueSoonCount: dueSoonCount,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildSearchBar(),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: RegentColors.violet,
                    unselectedLabelColor:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.white60
                            : Colors.black54,
                    indicatorColor: RegentColors.violet,
                    tabs: const [
                      Tab(
                          icon: Icon(Icons.auto_awesome_outlined),
                          text: 'For you'),
                      Tab(
                          icon: Icon(Icons.assignment_turned_in_outlined),
                          text: 'Assignments'),
                      Tab(
                          icon: Icon(Icons.video_library_outlined),
                          text: 'Lectures'),
                      Tab(icon: Icon(Icons.person_outline), text: 'Mine'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildFeedList(
                        context,
                        posts: visiblePosts,
                        emptyTitle: 'Nothing new for your cohort yet',
                        emptySubtitle:
                            'When class reps and lecturers publish posts tagged to your level or program, they will appear here automatically.',
                        currentUserId: currentUserId,
                        currentLevel: currentLevel,
                        currentProgram: currentProgram,
                        scope: _AcademicFeedScope.forYou,
                      ),
                      _buildFeedList(
                        context,
                        posts: assignmentPosts,
                        emptyTitle: 'No assignments found yet',
                        emptySubtitle:
                            'Assignments tagged to your level, program or course will appear here once they are published.',
                        currentUserId: currentUserId,
                        currentLevel: currentLevel,
                        currentProgram: currentProgram,
                        scope: _AcademicFeedScope.assignments,
                      ),
                      _buildFeedList(
                        context,
                        posts: lecturePosts,
                        emptyTitle: 'No lecture resources yet',
                        emptySubtitle:
                            'Recorded lectures, slides and audio notes from lecturers or reps will appear here.',
                        currentUserId: currentUserId,
                        currentLevel: currentLevel,
                        currentProgram: currentProgram,
                        scope: _AcademicFeedScope.lectures,
                      ),
                      _buildFeedList(
                        context,
                        posts: myPosts,
                        emptyTitle: 'You have not posted anything yet',
                        emptySubtitle:
                            'Use the publish buttons above to create your first assignment or lecture post.',
                        currentUserId: currentUserId,
                        currentLevel: currentLevel,
                        currentProgram: currentProgram,
                        scope: _AcademicFeedScope.mine,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHero(
    BuildContext context, {
    required String userName,
    required int? currentLevel,
    required String? currentProgram,
    required String? currentSession,
    required int visibleCount,
    required int assignmentCount,
    required int lectureCount,
    required int dueSoonCount,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [RegentColors.violet, RegentColors.darkViolet],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: RegentColors.violet.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school_outlined, color: Colors.white, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Academics Hub',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Personalised for $userName',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Assignments, lecture resources and academic updates for students, class reps and lecturers.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.88),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildHeaderChip(
                label: currentLevel == null
                    ? 'Level not set'
                    : 'Level $currentLevel',
              ),
              _buildHeaderChip(
                label: (currentProgram ?? '').isEmpty
                    ? 'Program not set'
                    : currentProgram!,
              ),
              _buildHeaderChip(
                label: (currentSession ?? '').isEmpty
                    ? 'Session not set'
                    : currentSession!,
              ),
              _buildHeaderChip(label: '$dueSoonCount due soon'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openComposer(
                      context, 'assignment', currentLevel, currentProgram),
                  icon: const Icon(Icons.post_add_outlined),
                  label: const Text('New assignment'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openComposer(
                      context, 'lecture', currentLevel, currentProgram),
                  icon: Icon(
                    Icons.video_library_outlined,
                    color: isDark ? Colors.white : Colors.white,
                  ),
                  label: const Text('Upload lecture'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.7)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildStatCard('Visible', visibleCount.toString(),
                  Icons.visibility_outlined),
              _buildStatCard('Assignments', assignmentCount.toString(),
                  Icons.assignment_outlined),
              _buildStatCard('Lectures', lectureCount.toString(),
                  Icons.video_library_outlined),
              _buildStatCard('Due soon', dueSoonCount.toString(),
                  Icons.event_available_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderChip({required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.28)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.8), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value),
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        hintText: 'Search by title, course, author or caption',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: isDark ? RegentColors.dmCard : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: RegentColors.violet.withOpacity(0.18)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: RegentColors.violet.withOpacity(0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: RegentColors.violet, width: 2),
        ),
      ),
    );
  }

  List<AcademicPostModel> _filterPosts(
    List<AcademicPostModel> posts, {
    required _AcademicFeedScope scope,
    required String currentUserId,
    required int? currentLevel,
    required String? currentProgram,
  }) {
    final normalizedQuery = _searchQuery.trim().toLowerCase();

    bool searchMatches(AcademicPostModel post) {
      if (normalizedQuery.isEmpty) return true;
      return post.searchBody().contains(normalizedQuery);
    }

    bool audienceMatches(AcademicPostModel post) {
      if (scope == _AcademicFeedScope.mine) {
        return post.authorId == currentUserId;
      }

      if (post.authorId == currentUserId) return true;
      return post.isRelevantTo(level: currentLevel, program: currentProgram);
    }

    final filtered = posts.where((post) {
      if (!searchMatches(post)) return false;
      if (!audienceMatches(post)) return false;
      switch (scope) {
        case _AcademicFeedScope.forYou:
          return true;
        case _AcademicFeedScope.assignments:
          return post.isAssignment;
        case _AcademicFeedScope.lectures:
          return post.isLecture;
        case _AcademicFeedScope.mine:
          return post.authorId == currentUserId;
      }
    }).toList();

    filtered.sort((a, b) {
      final aRelevant =
          a.isRelevantTo(level: currentLevel, program: currentProgram);
      final bRelevant =
          b.isRelevantTo(level: currentLevel, program: currentProgram);
      if (aRelevant != bRelevant) return aRelevant ? -1 : 1;
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return filtered;
  }

  Widget _buildFeedList(
    BuildContext context, {
    required List<AcademicPostModel> posts,
    required String emptyTitle,
    required String emptySubtitle,
    required String currentUserId,
    required int? currentLevel,
    required String? currentProgram,
    required _AcademicFeedScope scope,
  }) {
    if (posts.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {},
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            const SizedBox(height: 36),
            _buildEmptyState(emptyTitle, emptySubtitle, scope),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        itemCount: posts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final post = posts[index];
          return AcademicPostCard(
            post: post,
            currentUserId: currentUserId,
            onTap: () => _showPostDetails(context, post, currentUserId),
            onDelete: post.authorId == currentUserId
                ? () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Delete post'),
                        content: const Text(
                          'This will permanently remove the academic post and all uploaded files.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await _service.deleteAcademicPost(post.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Academic post deleted')),
                        );
                      }
                    }
                  }
                : null,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(
      String title, String subtitle, _AcademicFeedScope scope) {
    final icon = switch (scope) {
      _AcademicFeedScope.forYou => Icons.auto_awesome_outlined,
      _AcademicFeedScope.assignments => Icons.assignment_late_outlined,
      _AcademicFeedScope.lectures => Icons.video_library_outlined,
      _AcademicFeedScope.mine => Icons.person_off_outlined,
    };
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: RegentColors.violet.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: RegentColors.violet, size: 44),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white60
                : Colors.grey.shade700,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Future<void> _openComposer(
    BuildContext context,
    String postType,
    int? currentLevel,
    String? currentProgram,
  ) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AcademicPostEditorScreen(
          initialPostType: postType,
          defaultLevel: currentLevel,
          defaultProgram: currentProgram,
        ),
      ),
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            postType == 'lecture'
                ? 'Lecture resource published'
                : 'Assignment published',
          ),
          backgroundColor: RegentColors.green,
        ),
      );
    }
  }

  Future<void> _showPostDetails(
    BuildContext context,
    AcademicPostModel post,
    String currentUserId,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? RegentColors.dmSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.78,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (_, controller) {
              return ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: post.authorPhotoUrl != null
                            ? NetworkImage(post.authorPhotoUrl!)
                            : null,
                        child: post.authorPhotoUrl == null
                            ? Text(
                                post.authorName.isNotEmpty
                                    ? post.authorName[0].toUpperCase()
                                    : '?',
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.authorName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              _academicRoleLabel(post.authorRole),
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white60
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (post.authorId == currentUserId)
                        IconButton(
                          onPressed: () async {
                            Navigator.pop(sheetContext);
                            await Future<void>.delayed(
                                const Duration(milliseconds: 150));
                            if (mounted) {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Delete post'),
                                  content: const Text(
                                    'This will remove the post and its uploaded files.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                await _service.deleteAcademicPost(post.id);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Academic post deleted')),
                                  );
                                }
                              }
                            }
                          },
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: RegentColors.violet.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: RegentColors.violet.withOpacity(0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Chip(
                              label: Text(
                                post.isAssignment ? 'Assignment' : 'Lecture',
                              ),
                              backgroundColor: post.isAssignment
                                  ? Colors.red.withOpacity(0.12)
                                  : Colors.blue.withOpacity(0.12),
                            ),
                            const SizedBox(width: 8),
                            if (post.dueAt != null)
                              Chip(
                                label: Text(
                                  post.isAssignment
                                      ? 'Due ${DateFormat('MMM d, h:mm a').format(post.dueAt!)}'
                                      : 'Scheduled ${DateFormat('MMM d, h:mm a').format(post.dueAt!)}',
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          post.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (post.caption.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            post.caption,
                            style: TextStyle(
                              height: 1.45,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (post.courseCode != null &&
                          post.courseCode!.isNotEmpty)
                        Chip(label: Text(post.courseCode!)),
                      if (post.courseName != null &&
                          post.courseName!.isNotEmpty)
                        Chip(label: Text(post.courseName!)),
                      ...post.targetLevels
                          .map((level) => Chip(label: Text('Level $level'))),
                      ...post.targetPrograms
                          .map((program) => Chip(label: Text(program))),
                      ...post.targetCourses
                          .map((course) => Chip(label: Text(course))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (post.attachments.isNotEmpty) ...[
                    const Text(
                      'Attachments',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    ...post.attachments.map(
                      (attachment) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AcademicAttachmentView(
                          attachment: attachment,
                          expanded: true,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Published ${DateFormat('MMM d, y • h:mm a').format(post.createdAt)}',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.grey.shade700,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class AcademicPostCard extends StatelessWidget {
  final AcademicPostModel post;
  final String currentUserId;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const AcademicPostCard({
    super.key,
    required this.post,
    required this.currentUserId,
    required this.onTap,
    this.onDelete,
  });

  Color _roleColor(String role) {
    switch (role) {
      case 'lecturer':
        return Colors.blue;
      case 'official':
        return RegentColors.green;
      case 'class_rep':
      default:
        return RegentColors.violet;
    }
  }

  Color _typeColor() {
    return post.isAssignment ? Colors.red : Colors.blue;
  }

  String _formatTime(DateTime value) {
    return DateFormat('MMM d • h:mm a').format(value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? RegentColors.dmCard : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtle = isDark ? Colors.white60 : Colors.grey.shade700;
    final dueLabel = post.dueAt == null ? null : _formatDueLabel(post.dueAt!);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Card(
        color: color,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: RegentColors.violet.withOpacity(0.12)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: post.authorPhotoUrl != null
                        ? NetworkImage(post.authorPhotoUrl!)
                        : null,
                    child: post.authorPhotoUrl == null
                        ? Text(
                            post.authorName.isNotEmpty
                                ? post.authorName[0].toUpperCase()
                                : '?',
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                post.authorName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: textColor,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (post.authorId == currentUserId)
                              const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Icon(Icons.person,
                                    size: 16, color: RegentColors.violet),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_academicRoleLabel(post.authorRole)} • ${_formatTime(post.createdAt)}',
                          style: TextStyle(color: subtle, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (onDelete != null)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: subtle),
                      color: isDark ? RegentColors.dmSurface : Colors.white,
                      onSelected: (value) {
                        if (value == 'delete') onDelete?.call();
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Colors.red),
                              SizedBox(width: 10),
                              Text('Delete'),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildChip(
                    label: post.isAssignment ? 'Assignment' : 'Lecture',
                    background: _typeColor().withOpacity(0.12),
                    foreground: _typeColor(),
                  ),
                  if (dueLabel != null)
                    _buildChip(
                      label: dueLabel,
                      background: Colors.orange.withOpacity(0.12),
                      foreground: Colors.orange.shade800,
                    ),
                  if (post.courseCode != null && post.courseCode!.isNotEmpty)
                    _buildChip(
                      label: post.courseCode!,
                      background: RegentColors.violet.withOpacity(0.12),
                      foreground: RegentColors.violet,
                    ),
                  if (post.courseName != null && post.courseName!.isNotEmpty)
                    _buildChip(
                      label: post.courseName!,
                      background: Colors.teal.withOpacity(0.12),
                      foreground: Colors.teal,
                    ),
                  if (post.targetLevels.isNotEmpty)
                    ...post.targetLevels.map(
                      (level) => _buildChip(
                        label: 'Level $level',
                        background: RegentColors.green.withOpacity(0.12),
                        foreground: RegentColors.green,
                      ),
                    ),
                  if (post.targetPrograms.isNotEmpty)
                    _buildChip(
                      label: post.targetPrograms.first,
                      background: Colors.blue.withOpacity(0.12),
                      foreground: Colors.blue,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                post.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              if (post.caption.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  post.caption,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    height: 1.4,
                    color: subtle,
                  ),
                ),
              ],
              if (post.attachments.isNotEmpty) ...[
                const SizedBox(height: 14),
                AcademicAttachmentView(
                  attachment: post.attachments.first,
                  compact: true,
                ),
                if (post.attachments.length > 1) ...[
                  const SizedBox(height: 8),
                  Text(
                    '+${post.attachments.length - 1} more attachment(s)',
                    style: TextStyle(
                      color: subtle,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.how_to_reg_outlined, size: 16, color: subtle),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      post.audienceLabel(),
                      style: TextStyle(
                        color: subtle,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(Icons.touch_app_outlined, size: 16, color: subtle),
                  const SizedBox(width: 4),
                  Text(
                    'Open',
                    style: TextStyle(
                      color: subtle,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _formatDueLabel(DateTime dueAt) {
    final now = DateTime.now();
    final diff = dueAt.difference(now);
    if (diff.isNegative) {
      return 'Overdue';
    }
    if (diff.inDays == 0) {
      return 'Due today';
    }
    if (diff.inDays == 1) {
      return 'Due tomorrow';
    }
    return 'Due in ${diff.inDays} days';
  }
}

class AcademicAttachmentView extends StatelessWidget {
  final AcademicAttachmentModel attachment;
  final bool compact;
  final bool expanded;

  const AcademicAttachmentView({
    super.key,
    required this.attachment,
    this.compact = false,
    this.expanded = false,
  });

  Future<void> _openExternal(BuildContext context) async {
    final uri = Uri.tryParse(attachment.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Color _color() {
    return switch (attachment.kind) {
      'image' => RegentColors.green,
      'video' => Colors.red,
      'audio' => Colors.orange,
      _ => RegentColors.violet,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();

    if (attachment.isImage) {
      final preview = GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatMediaViewerScreen(
                mediaUrl: attachment.url,
                mediaType: 'image',
                title: attachment.name,
              ),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Image.network(
                attachment.url,
                width: double.infinity,
                height: compact ? 180 : 240,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: double.infinity,
                  height: compact ? 180 : 240,
                  color: color.withOpacity(0.1),
                  child: const Center(child: Icon(Icons.broken_image_outlined)),
                ),
              ),
              Container(
                margin: const EdgeInsets.all(12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Open',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
      if (compact) return preview;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          preview,
          const SizedBox(height: 8),
          Text(
            attachment.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      );
    }

    if (attachment.isVideo) {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatMediaViewerScreen(
                mediaUrl: attachment.url,
                mediaType: 'video',
                title: attachment.name,
              ),
            ),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.18)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.play_circle_fill, color: color, size: 36),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to watch the lecture video',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (attachment.isAudio) {
      return _AudioAttachmentTile(attachment: attachment);
    }

    return GestureDetector(
      onTap: () => _openExternal(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.insert_drive_file_outlined,
                  color: color, size: 32),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    attachment.contentType.isNotEmpty
                        ? attachment.contentType
                        : 'Document',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _openExternal(context),
              child: const Text('Open'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioAttachmentTile extends StatefulWidget {
  final AcademicAttachmentModel attachment;

  const _AudioAttachmentTile({required this.attachment});

  @override
  State<_AudioAttachmentTile> createState() => _AudioAttachmentTileState();
}

class _AudioAttachmentTileState extends State<_AudioAttachmentTile> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _loading = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    try {
      if (_isPlaying) {
        await _player.pause();
        if (mounted) setState(() => _isPlaying = false);
        return;
      }

      if (_player.state == PlayerState.stopped) {
        setState(() => _loading = true);
        await _player.play(UrlSource(widget.attachment.url));
        if (mounted) {
          setState(() {
            _isPlaying = true;
            _loading = false;
          });
        }
        return;
      }

      await _player.resume();
      if (mounted) setState(() => _isPlaying = true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _isPlaying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.graphic_eq, color: Colors.orange, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.attachment.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tap to play the audio note',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  onPressed: _togglePlayback,
                  icon: Icon(
                    _isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                    color: Colors.orange,
                    size: 34,
                  ),
                ),
        ],
      ),
    );
  }
}
