import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme.dart';
import '../../../core/theme_provider.dart';

class AcademicsTab extends StatelessWidget {
  const AcademicsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Academic Resources',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Access study materials and past questions',
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.grey,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),

          // Main Features Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [
              _buildAcademicCard(
                context,
                icon: Icons.library_books,
                title: 'Past Questions',
                subtitle: 'Access exam papers',
                color: RegentColors.blue,
                onTap: () => Navigator.pushNamed(context, '/past-questions'),
              ),
              _buildAcademicCard(
                context,
                icon: Icons.assignment,
                title: 'Assignments',
                subtitle: 'View coursework',
                color: Colors.purple,
                onTap: () => _showComingSoon(context),
              ),
              _buildAcademicCard(
                context,
                icon: Icons.video_library,
                title: 'Lectures',
                subtitle: 'Watch recordings',
                color: Colors.red,
                onTap: () => _showComingSoon(context),
              ),
              _buildAcademicCard(
                context,
                icon: Icons.note,
                title: 'Study Notes',
                subtitle: 'Course materials',
                color: Colors.orange,
                onTap: () => _showComingSoon(context),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Quick Links Section
          Text(
            'Quick Links',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),

          _buildQuickLinkTile(
            context,
            icon: Icons.calendar_today,
            title: 'Academic Calendar',
            subtitle: 'Important dates and deadlines',
            isDark: isDark,
            onTap: () => _showComingSoon(context),
          ),
          const SizedBox(height: 8),

          _buildQuickLinkTile(
            context,
            icon: Icons.school,
            title: 'Course Information',
            subtitle: 'View course details and credits',
            isDark: isDark,
            onTap: () => _showComingSoon(context),
          ),
          const SizedBox(height: 8),

          _buildQuickLinkTile(
            context,
            icon: Icons.assessment,
            title: 'Results & Grades',
            subtitle: 'Check your performance',
            isDark: isDark,
            onTap: () => _showComingSoon(context),
          ),
          const SizedBox(height: 8),

          _buildQuickLinkTile(
            context,
            icon: Icons.help_outline,
            title: 'Academic Support',
            subtitle: 'Get help from tutors',
            isDark: isDark,
            onTap: () => _showComingSoon(context),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAcademicCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 36),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickLinkTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isDark ? RegentColors.darkCard : RegentColors.primarySoft,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: RegentColors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: RegentColors.blue),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: isDark ? Colors.white54 : Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🚀 Coming soon!'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 2),
      ),
    );
  }
}
