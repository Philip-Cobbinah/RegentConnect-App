import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/regent_university_profile.dart';
import '../../../core/theme.dart';

class RegentUniversityInfoScreen extends StatelessWidget {
  const RegentUniversityInfoScreen({super.key});

  Future<void> _openUri(BuildContext context, Uri uri) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the link.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the link.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Regent University Info'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
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
                const Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.school_rounded,
                        color: RegentColors.violet,
                        size: 28,
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        RegentUniversityProfile.shortName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  RegentUniversityProfile.institutionName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Motto: ${RegentUniversityProfile.motto}',
                  style: const TextStyle(color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: RegentUniversityProfile.coreValues
                      .map(
                        (value) => Chip(
                          backgroundColor: Colors.white.withOpacity(0.15),
                          label: Text(
                            value,
                            style: const TextStyle(color: Colors.white),
                          ),
                          side: BorderSide.none,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _StatTile(
                      label: 'Established',
                      value: RegentUniversityProfile.established,
                    ),
                    const SizedBox(width: 10),
                    _StatTile(
                      label: 'Accredited',
                      value: RegentUniversityProfile.accredited,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _sectionHeader(
            'Overview',
            'Identity, accreditation, founder and mission',
          ),
          _detailCard(
            children: [
              _detailRow(
                  'Institution', RegentUniversityProfile.institutionName),
              _detailRow('Founder & Chancellor',
                  RegentUniversityProfile.founderAndChancellor),
              _detailRow(
                  'Accreditation', RegentUniversityProfile.accreditation),
              _detailRow('Vision', RegentUniversityProfile.vision),
            ],
          ),
          _sectionHeader('Affiliations', 'Connected universities and partners'),
          _chipWrap(RegentUniversityProfile.affiliations),
          _sectionHeader('Study streams', 'Choose your delivery schedule'),
          _streamCards(),
          _sectionHeader('Undergraduate programmes', 'By faculty'),
          ...RegentUniversityProfile.undergraduateProgrammes
              .map(_programmeGroupCard),
          _sectionHeader('Postgraduate programmes', 'Masters and PhD options'),
          ...RegentUniversityProfile.postgraduateProgrammes
              .map(_programmeGroupCard),
          _sectionHeader(
              'Admissions & entry', 'Application fee and entry rules'),
          ...RegentUniversityProfile.admissions.map(_infoItemCard),
          _sectionHeader('Online services', 'Student tools and portals'),
          ...RegentUniversityProfile.onlineServices.map(_infoItemCard),
          _sectionHeader('Campus contact', 'Find and reach the university'),
          _detailCard(
            children: [
              _detailRow(
                  'Campus address', RegentUniversityProfile.campusAddress),
              _detailRow('Phone contacts',
                  RegentUniversityProfile.phoneContacts.join('\n')),
              _detailRow('Emails', RegentUniversityProfile.emails.join('\n')),
              _detailRow('Website', RegentUniversityProfile.website),
              _detailRow(
                'Social handles',
                RegentUniversityProfile.socialHandles.join('\n'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () => _openUri(
                  context,
                  Uri.parse(RegentUniversityProfile.website),
                ),
                icon: const Icon(Icons.language),
                label: const Text('Open website'),
              ),
              OutlinedButton.icon(
                onPressed: () => _openUri(
                  context,
                  Uri(
                    scheme: 'mailto',
                    path: RegentUniversityProfile.emails.first,
                  ),
                ),
                icon: const Icon(Icons.mail_outline),
                label: const Text('Email admissions'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
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

  Widget _chipWrap(List<String> values) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values
          .map(
            (value) => Chip(
              label: Text(value),
              backgroundColor: RegentColors.violet.withOpacity(0.08),
            ),
          )
          .toList(),
    );
  }

  Widget _streamCards() {
    return Column(
      children: RegentUniversityProfile.studyStreams.map((stream) {
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: RegentColors.violet.withOpacity(0.1),
              child: Icon(stream.icon, color: RegentColors.violet),
            ),
            title: Text(
              stream.title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              stream.description,
              style: TextStyle(color: Colors.grey.shade600, height: 1.35),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _programmeGroupCard(RegentProgrammeGroup group) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              group.title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            for (final programme in group.programmes)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  ', style: TextStyle(fontSize: 16)),
                    Expanded(
                      child: Text(
                        programme,
                        style: const TextStyle(height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoItemCard(RegentInfoItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: CircleAvatar(
          backgroundColor: RegentColors.violet.withOpacity(0.1),
          child: Icon(item.icon, color: RegentColors.violet),
        ),
        title: Text(
          item.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          item.description,
          style: TextStyle(color: Colors.grey.shade600, height: 1.35),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
