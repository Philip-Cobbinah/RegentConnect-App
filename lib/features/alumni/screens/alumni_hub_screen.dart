import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/student_progress.dart';
import '../../../core/theme.dart';
import '../../../services/auth_service.dart';
import '../../../services/chat_service.dart';
import '../../chat/screens/community_chat_screen.dart';
import '../../info/screens/regent_university_info_screen.dart';

class AlumniHubScreen extends StatefulWidget {
  const AlumniHubScreen({super.key});

  @override
  State<AlumniHubScreen> createState() => _AlumniHubScreenState();
}

class _AlumniHubScreenState extends State<AlumniHubScreen> {
  final _authService = AuthService();
  final _chatService = ChatService();
  bool _openingNetwork = false;

  Future<void> _openAlumniNetwork() async {
    if (_openingNetwork) return;
    setState(() => _openingNetwork = true);
    try {
      final group = await _chatService.ensureAlumniNetworkGroup();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CommunityChatScreen(group: group),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Alumni network could not open: $error')),
      );
    } finally {
      if (mounted) setState(() => _openingNetwork = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.currentUser;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alumni Hub'),
      ),
      body: currentUser == null
          ? Center(
              child: Text(
                'Sign in to view the alumni hub.',
                style: TextStyle(color: colorScheme.onSurface),
              ),
            )
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                final userData = snapshot.data?.data() ?? <String, dynamic>{};
                final isAlumni = StudentProgress.isAlumniProfile(userData);
                final level = int.tryParse(userData['level']?.toString() ?? '');
                final expectedYear =
                    int.tryParse(userData['expectedGraduationYear']?.toString() ?? '');
                final yearsRemaining =
                    StudentProgress.yearsRemainingForProfile(userData);
                final name = (userData['fullName'] ??
                        userData['displayName'] ??
                        currentUser.displayName ??
                        currentUser.email ??
                        'Regent student')
                    .toString();
                final program = (userData['program'] ?? 'Program not set').toString();
                final session = (userData['session'] ?? 'Session not set').toString();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [RegentColors.darkViolet, RegentColors.violet],
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(
                                radius: 26,
                                backgroundColor: Colors.white,
                                child: Icon(
                                  Icons.school_rounded,
                                  color: RegentColors.violet,
                                  size: 29,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isAlumni ? 'Welcome, alumnus/alumna' : 'Your alumni journey',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      name,
                                      style: const TextStyle(color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            isAlumni
                                ? 'You have reached the alumni space. Stay connected with classmates, lecturers and Regent updates.'
                                : 'We calculate your expected graduation year from the level you selected at signup, then bring you here when your student journey is complete.',
                            style: const TextStyle(
                              color: Colors.white,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _statusChip(
                                label: isAlumni ? 'Alumni' : 'Current student',
                                icon: isAlumni
                                    ? Icons.verified_rounded
                                    : Icons.hourglass_bottom_rounded,
                              ),
                              _statusChip(
                                label: 'Level ${level ?? '-'}',
                                icon: Icons.stairs_rounded,
                              ),
                              if (expectedYear != null)
                                _statusChip(
                                  label: 'Expected graduation: $expectedYear',
                                  icon: Icons.event_rounded,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed:
                              _openingNetwork ? null : _openAlumniNetwork,
                          icon: _openingNetwork
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.groups_rounded),
                          label: const Text('Open alumni network'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegentUniversityInfoScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.info_outline_rounded),
                          label: const Text('School info'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _sectionHeader(
                      'Your academic timeline',
                      'A quick summary based on the level you chose during signup',
                    ),
                    _detailCard(
                      children: [
                        _detailRow('Program', program),
                        _detailRow('Session', session),
                        _detailRow('Current level', 'Level ${level ?? '-'}'),
                        _detailRow(
                          'Years remaining',
                          isAlumni ? 'Completed' : '$yearsRemaining year(s)',
                        ),
                        _detailRow(
                          'Status',
                          isAlumni ? 'Alumni' : 'Student',
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _sectionHeader(
                      'What happens next',
                      'This is where alumni stay in touch after school',
                    ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          isAlumni
                              ? 'You can now use the alumni network for updates, reconnect with classmates and receive Regent-wide announcements.'
                              : 'When your graduation period is reached, this hub becomes your alumni entry point and you can continue in the Regent alumni network.',
                          style: TextStyle(
                            height: 1.45,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _statusChip({
    required String label,
    required IconData icon,
  }) {
    return Chip(
      avatar: Icon(icon, size: 16, color: RegentColors.darkViolet),
      label: Text(
        label,
        style: const TextStyle(
          color: RegentColors.darkViolet,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: Colors.white,
      side: BorderSide(color: RegentColors.violet.withOpacity(0.18)),
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailCard({required List<Widget> children}) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(height: 22),
              children[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: RegentColors.violet,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              height: 1.35,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
