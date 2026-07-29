import 'package:flutter/material.dart';

import '../../../core/official_accounts.dart';
import '../../../core/regent_university_profile.dart';
import '../../../core/theme.dart';
import '../../info/screens/regent_university_info_screen.dart';
import 'dm_screen.dart';

class OfficialAccountProfileScreen extends StatelessWidget {
  const OfficialAccountProfileScreen({
    super.key,
    required this.account,
  });

  final Map<String, dynamic> account;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final official = OfficialAccounts.byId(
          account['officialAccountId']?.toString(),
        ) ??
        OfficialAccounts.byEmail(account['email']?.toString());
    final name = (account['fullName'] ??
            account['displayName'] ??
            official?.name ??
            account['email'] ??
            'Official office')
        .toString();
    final office = (account['office'] ??
            account['department'] ??
            official?.office ??
            'Official office')
        .toString();
    final email = (account['email'] ?? official?.email ?? '').toString().trim();
    final description = (account['about'] ??
            official?.description ??
            'Students can message this verified office for support.')
        .toString();
    final responseHours =
        (account['responseHours'] ?? official?.responseHours ?? '').toString();
    final isActive =
        account['accountActive'] == true || account['linkedUser'] != null;
    final identity = (account['chatIdentity'] ??
            account['officialAccountId'] ??
            account['uid'])
        .toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
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
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.account_balance_rounded,
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
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            office,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    if (isActive)
                      const Icon(Icons.verified, color: Colors.white),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white, height: 1.4),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _statusChip(
                      label: 'Verified office',
                      icon: Icons.verified_rounded,
                      isDark: isDark,
                    ),
                    if (responseHours.isNotEmpty)
                      _statusChip(
                        label: responseHours,
                        icon: Icons.schedule_rounded,
                        isDark: isDark,
                      ),
                    if (!isActive)
                      _statusChip(
                        label: 'Awaiting activation',
                        icon: Icons.pause_circle_outline_rounded,
                        isDark: isDark,
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
                onPressed: () =>
                    _openDirectMessage(context, identity, name, account),
                icon: const Icon(Icons.chat_bubble_rounded),
                label: Text('Message $name'),
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
                icon: const Icon(Icons.school_rounded),
                label: const Text('View Regent info'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _sectionHeader(
            'Office details',
            'Contact and live inbox details',
          ),
          _detailCard(
            children: [
              _detailRow('Email', email.isEmpty ? 'Not available' : email),
              _detailRow(
                'Office',
                office,
              ),
              _detailRow(
                'Response hours',
                responseHours.isEmpty
                    ? 'Monday-Friday, 8:00 AM-5:00 PM'
                    : responseHours,
              ),
              _detailRow(
                'Status',
                isActive ? 'Active office inbox' : 'Ready to be activated',
              ),
            ],
          ),
          const SizedBox(height: 18),
          _sectionHeader(
            'About this office',
            'What students can ask here and how it supports them',
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                description,
                style: const TextStyle(height: 1.45),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _sectionHeader(
            'Regent university at a glance',
            'A short summary students can review quickly',
          ),
          _detailCard(
            children: [
              _detailRow('Institution', RegentUniversityProfile.shortName),
              _detailRow('Motto', RegentUniversityProfile.motto),
              _detailRow(
                'Study sessions',
                RegentUniversityProfile.studyStreams
                    .map((stream) => stream.title)
                    .join(', '),
              ),
              _detailRow(
                'Campus',
                RegentUniversityProfile.campusAddress,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _sectionHeader('Student resources', 'Useful school-wide services'),
          ...RegentUniversityProfile.onlineServices.take(2).map((item) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: RegentColors.violet.withOpacity(0.1),
                  child: Icon(item.icon, color: RegentColors.violet),
                ),
                title: Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(item.description),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _openDirectMessage(
    BuildContext context,
    String identity,
    String name,
    Map<String, dynamic> account,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DMScreen(
          recipientId: identity,
          recipientName: name,
          recipientPhoto: account['photoUrl']?.toString(),
        ),
      ),
    );
  }

  Widget _statusChip({
    required String label,
    required IconData icon,
    required bool isDark,
  }) {
    return Chip(
      avatar: Icon(
        icon,
        size: 16,
        color: isDark ? Colors.white : RegentColors.darkViolet,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: isDark ? Colors.white : RegentColors.darkViolet,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor:
          isDark ? Colors.white.withOpacity(0.14) : Colors.white.withOpacity(0.9),
      side: BorderSide(
        color: isDark
            ? Colors.transparent
            : RegentColors.violet.withOpacity(0.18),
      ),
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade600, height: 1.35),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
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
            style: const TextStyle(height: 1.4),
          ),
        ),
      ],
    );
  }
}
