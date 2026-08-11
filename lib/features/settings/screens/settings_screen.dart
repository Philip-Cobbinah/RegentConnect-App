import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import '../../../core/theme.dart';
import '../../../core/theme_provider.dart';
import '../../../core/student_progress.dart';
import '../../../services/auth_service.dart';
import '../../../services/block_service.dart';
import '../../auth/screens/officer_access_screen.dart';
import '../../info/screens/regent_university_info_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final authService = AuthService();
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final blockService = BlockService();

  @override
  Widget build(BuildContext context) {
    final user = authService.currentUser;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('users').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};

          return ListView(
            children: [
              // Profile Header
              Container(
                padding: const EdgeInsets.all(24),
                color: isDark
                    ? RegentColors.darkCard
                    : RegentColors.blue.withOpacity(0.1),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => _changeProfilePicture(),
                      child: Tooltip(
                        message: 'Change Profile Picture',
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundImage: userData['photoUrl'] != null
                                  ? NetworkImage(userData['photoUrl'])
                                  : null,
                              backgroundColor:
                                  isDark ? Colors.grey[700] : Colors.grey[300],
                              child: userData['photoUrl'] == null
                                  ? Text(
                                      user?.displayName?[0].toUpperCase() ??
                                          '?',
                                      style: const TextStyle(fontSize: 36),
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: RegentColors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      userData['displayName'] ?? user?.displayName ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      user?.email ?? '',
                      style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.grey),
                    ),
                    if ((userData['session'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Session: ${userData['session']}',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.grey,
                        ),
                      ),
                    ],
                    if ((userData['expectedGraduationYear'] ?? '')
                            .toString()
                            .isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Expected graduation: ${userData['expectedGraduationYear']}',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Appearance Settings
              _buildSectionHeader('Appearance', isDark),

              // Dark Mode Toggle
              SwitchListTile(
                secondary: Icon(
                  isDark ? Icons.dark_mode : Icons.light_mode,
                  color: isDark ? Colors.amber : RegentColors.blue,
                ),
                title: Text(
                  'Dark Mode',
                  style:
                      TextStyle(color: isDark ? Colors.white : Colors.black87),
                ),
                subtitle: Text(
                  isDark ? 'Dark theme enabled' : 'Light theme enabled',
                  style:
                      TextStyle(color: isDark ? Colors.white70 : Colors.grey),
                ),
                value: isDark,
                onChanged: (value) {
                  themeProvider.setDarkMode(value);
                  setState(() {}); // Force rebuild to update subtitle text
                },
              ),
              const Divider(height: 1),

              // Account Settings
              _buildSectionHeader('Account', isDark),

              _buildSettingsTile(
                icon: Icons.person,
                title: 'Display Name',
                subtitle: userData['displayName'] ?? 'Not set',
                isDark: isDark,
                onTap: () => _editDisplayName(userData['displayName']),
              ),

              _buildSettingsTile(
                icon: Icons.school,
                title: 'Program',
                subtitle: userData['program'] ?? 'Not set',
                isDark: isDark,
                onTap: () => _editProgram(userData['program']),
              ),

              _buildSettingsTile(
                icon: Icons.stairs,
                title: 'Level',
                subtitle: 'Level ${userData['level'] ?? 100}',
                isDark: isDark,
                onTap: () => _editLevel(userData['level']),
              ),

              _buildSettingsTile(
                icon: Icons.info_outline,
                title: 'About',
                subtitle:
                    userData['about'] ?? 'Hey there! I\'m using Regent Connect',
                isDark: isDark,
                onTap: () => _editAbout(userData['about']),
              ),

              // Privacy Settings
              _buildSectionHeader('Privacy', isDark),

              SwitchListTile(
                secondary: Icon(Icons.visibility,
                    color: isDark ? Colors.white70 : RegentColors.blue),
                title: Text('Show Online Status',
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87)),
                value: userData['showOnlineStatus'] ?? true,
                onChanged: (value) => _updateSetting('showOnlineStatus', value),
              ),
              const Divider(height: 1),

              SwitchListTile(
                secondary: Icon(Icons.receipt_long,
                    color: isDark ? Colors.white70 : RegentColors.blue),
                title: Text('Read Receipts',
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87)),
                value: userData['readReceipts'] ?? true,
                onChanged: (value) => _updateSetting('readReceipts', value),
              ),

              // Notifications
              _buildSectionHeader('Notifications', isDark),

              SwitchListTile(
                secondary: Icon(Icons.notifications,
                    color: isDark ? Colors.white70 : RegentColors.blue),
                title: Text('Push Notifications',
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87)),
                value: userData['pushNotifications'] ?? true,
                onChanged: (value) =>
                    _updateSetting('pushNotifications', value),
              ),

              _buildSectionHeader('Regent support', isDark),
              _buildSettingsTile(
                icon: Icons.verified_user_outlined,
                title: 'Official office access',
                subtitle: 'See how students contact offices and officers reply',
                isDark: isDark,
                iconColor: RegentColors.violet,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OfficerAccessScreen(),
                  ),
                ),
              ),

              _buildSettingsTile(
                icon: Icons.school_outlined,
                title: 'Regent University info',
                subtitle: 'View the school profile, programmes, and contacts',
                isDark: isDark,
                iconColor: RegentColors.green,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RegentUniversityInfoScreen(),
                  ),
                ),
              ),

              _buildSettingsTile(
                icon: Icons.groups_rounded,
                title: 'Alumni hub',
                subtitle: StudentProgress.isAlumniProfile(userData)
                    ? 'Open the alumni network and graduate updates'
                    : 'See your graduation timeline and alumni network',
                isDark: isDark,
                iconColor: RegentColors.violet,
                onTap: () => Navigator.pushNamed(context, '/alumni'),
              ),

              // Account Actions
              _buildSectionHeader('Account Actions', isDark),

              _buildSettingsTile(
                icon: Icons.lock,
                title: 'Change Password',
                isDark: isDark,
                iconColor: Colors.orange,
                onTap: () => _changePassword(),
              ),

              // Invite Friends Section
              _buildSectionHeader('Invite Friends', isDark),

              ListTile(
                leading: Icon(
                  Icons.person_add,
                  color: isDark ? Colors.white70 : RegentColors.blue,
                ),
                title: Text(
                  'Invite Friends',
                  style:
                      TextStyle(color: isDark ? Colors.white : Colors.black87),
                ),
                subtitle: Text(
                  'Share Regent Connect with friends',
                  style:
                      TextStyle(color: isDark ? Colors.white54 : Colors.grey),
                ),
                trailing: Icon(Icons.chevron_right,
                    color: isDark ? Colors.white54 : Colors.grey),
                onTap: () => _showInviteDialog(isDark),
              ),
              const Divider(height: 1),

              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title:
                    const Text('Logout', style: TextStyle(color: Colors.red)),
                onTap: () => _logout(),
              ),
              const Divider(height: 1),

              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Delete Account',
                    style: TextStyle(color: Colors.red)),
                onTap: () => _deleteAccount(),
              ),

              const SizedBox(height: 32),

              // App Version
              Center(
                child: Text(
                  'Regent Connect v1.0.0',
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white70 : Colors.grey,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool isDark,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon,
              color:
                  iconColor ?? (isDark ? Colors.white70 : RegentColors.blue)),
          title: Text(title,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
          subtitle: subtitle != null
              ? Text(subtitle,
                  style:
                      TextStyle(color: isDark ? Colors.white54 : Colors.grey))
              : null,
          trailing: Icon(Icons.chevron_right,
              color: isDark ? Colors.white54 : Colors.grey),
          onTap: onTap,
        ),
        const Divider(height: 1),
      ],
    );
  }

  Future<void> _changeProfilePicture() async {
    final picker = ImagePicker();
    final image =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (image == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final bytes = await image.readAsBytes();
      final odId = authService.currentUser!.uid;
      final ref = _storage.ref().child(
          'profile_pictures/$odId/profile_${DateTime.now().millisecondsSinceEpoch}.jpg');

      await ref.putData(
        bytes,
        SettableMetadata(
          contentType: image.mimeType ?? 'image/jpeg',
          customMetadata: {'ownerUid': odId},
        ),
      );
      final url = await ref.getDownloadURL();

      await _firestore.collection('users').doc(odId).update({
        'photoUrl': url,
        'photoStoragePath': ref.fullPath,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await authService.currentUser!.updatePhotoURL(url);

      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _editDisplayName(String? currentName) {
    final controller = TextEditingController(text: currentName);
    final isDark =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? RegentColors.darkCard : Colors.white,
        title: Text('Edit Display Name',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            labelText: 'Display Name',
            labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.grey),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                final success = await _updateSetting('displayName', newName);
                if (success && mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editProgram(String? currentProgram) {
    final controller = TextEditingController(text: currentProgram);
    final isDark =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? RegentColors.darkCard : Colors.white,
        title: Text('Edit Program',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            labelText: 'Program',
            labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.grey),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newProgram = controller.text.trim();
              if (newProgram.isNotEmpty) {
                final success = await _updateSetting('program', newProgram);
                if (success && mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editLevel(int? currentLevel) {
    int selected = currentLevel ?? 100;
    final isDark =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: isDark ? RegentColors.darkCard : Colors.white,
          title: Text('Select Level',
              style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [100, 200, 300, 400].map((level) {
              return RadioListTile<int>(
                title: Text('Level $level',
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87)),
                value: level,
                groupValue: selected,
                onChanged: (value) => setState(() => selected = value!),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final success = await _updateSetting('level', selected);
                if (success && mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _editAbout(String? currentAbout) {
    final controller = TextEditingController(text: currentAbout);
    final isDark =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? RegentColors.darkCard : Colors.white,
        title: Text('Edit About',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          maxLength: 150,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            labelText: 'About',
            labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.grey),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await _updateSetting('about', controller.text.trim());
              if (success && mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<bool> _updateSetting(String field, dynamic value) async {
    final user = authService.currentUser;
    if (user == null) return false;

    try {
      final updates = <String, dynamic>{
        field: value,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (field == 'displayName') {
        updates['fullName'] = value.toString().trim();
      }

      if (field == 'level') {
        final level = int.tryParse(value.toString());
        if (level != null) {
          updates.addAll(StudentProgress.graduationMetadataForLevel(level));
        }
      }

      await _firestore.collection('users').doc(user.uid).set(
            updates,
            SetOptions(merge: true),
          );

      if (field == 'displayName' && value.toString().trim().isNotEmpty) {
        await user.updateDisplayName(value.toString().trim());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings updated')),
        );
      }
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update $field: $error')),
        );
      }
      return false;
    }
  }

  void _changePassword() {
    final email = authService.currentUser?.email;
    if (email == null) return;
    final isDark =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? RegentColors.darkCard : Colors.white,
        title: Text('Change Password',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        content: Text(
          'We will send a password reset link to your email.',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await authService.resetPassword(email);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password reset email sent!')),
                  );
                }
              } catch (error) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not send reset email: $error')),
                  );
                }
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _logout() {
    final isDark =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final pageContext = context;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? RegentColors.darkCard : Colors.white,
        title: Text('Logout',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        content: Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(dialogContext, rootNavigator: true).pop();
              try {
                debugPrint('Logout confirmed from settings screen');
                await authService.signOut();
                debugPrint('Logout completed');
                if (!mounted) return;
                Navigator.of(pageContext)
                    .pushNamedAndRemoveUntil('/login', (route) => false);
              } catch (error) {
                if (!mounted) return;
                ScaffoldMessenger.of(pageContext).showSnackBar(
                  SnackBar(content: Text('Logout failed: $error')),
                );
              }
            },
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _deleteAccount() {
    final isDark =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final pageContext = context;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? RegentColors.darkCard : Colors.white,
        title: Text('Delete Account',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        content: Text(
          'This action cannot be undone. All your data will be permanently deleted.',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(dialogContext, rootNavigator: true).pop();
              debugPrint('Delete account confirmed from settings screen');
              await _performAccountDeletion(pageContext);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _performAccountDeletion(BuildContext pageContext) async {
    final user = authService.currentUser;
    if (user == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      final photoPath = userData['photoStoragePath']?.toString();
      final isOfficial = userData['isOfficial'] == true ||
          userData['officialAccountId'] != null;
      final officialAccountId = userData['officialAccountId']?.toString();

      if (photoPath != null && photoPath.isNotEmpty) {
        try {
          await _storage.ref().child(photoPath).delete();
        } catch (error) {
          debugPrint('Photo delete skipped: $error');
        }
      }

      if (isOfficial && officialAccountId != null && officialAccountId.isNotEmpty) {
        try {
          await _firestore.collection('official_offices').doc(officialAccountId).delete();
        } catch (error) {
          debugPrint('Official office delete skipped: $error');
        }
      }

      try {
        await _firestore.collection('users').doc(user.uid).delete();
      } catch (error) {
        debugPrint('User profile delete skipped: $error');
      }

      await user.delete();

      if (!mounted) return;
      await authService.signOut();
      if (!mounted) return;
      Navigator.of(pageContext)
          .pushNamedAndRemoveUntil('/login', (route) => false);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      if (error.code == 'requires-recent-login') {
        final password = await _promptForPassword(pageContext, user.email);
        if (password == null || password.isEmpty) {
          return;
        }

        try {
          final credential = EmailAuthProvider.credential(
            email: user.email!,
            password: password,
          );
          await user.reauthenticateWithCredential(credential);
          await _performAccountDeletion(pageContext);
          return;
        } catch (reauthError) {
          if (!mounted) return;
          ScaffoldMessenger.of(pageContext).showSnackBar(
            SnackBar(content: Text('Re-authentication failed: $reauthError')),
          );
        }
        return;
      }
      ScaffoldMessenger.of(pageContext).showSnackBar(
        SnackBar(content: Text('Delete failed: ${error.message ?? error.code}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(pageContext).showSnackBar(
        SnackBar(content: Text('Delete failed: $error')),
      );
    }
  }

  Future<String?> _promptForPassword(
    BuildContext pageContext,
    String? email,
  ) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: pageContext,
      barrierDismissible: false,
      builder: (dialogContext) {
        final isDark =
            Provider.of<ThemeProvider>(dialogContext, listen: false).isDarkMode;
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          backgroundColor: isDark ? RegentColors.darkCard : Colors.white,
          title: Text(
            'Confirm your password',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          content: TextField(
            controller: controller,
            obscureText: true,
            style: TextStyle(color: colorScheme.onSurface),
            decoration: InputDecoration(
              labelText: email == null || email.isEmpty
                  ? 'Password'
                  : 'Password for $email',
              labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  void _showInviteDialog(bool isDark) {
    final inviteLink = 'https://regent-connect.app/join';
    final inviteMessage = '''🎓 Join Regent Connect!

Hi! I'm inviting you to join Regent Connect - the ultimate academic networking app for students.

📚 Features:
✅ Chat with friends & classmates
✅ Ask Regent AI for homework help
✅ Video & Audio calls
✅ Build study streaks
✅ Access past exam questions
✅ Share status updates
✅ Study groups

Join now: $inviteLink

Let's connect and grow together! 🚀''';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? RegentColors.darkCard : Colors.white,
        title: Text(
          'Invite Friends',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Share Regent Connect with your friends and classmates!',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[700],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Invite Link:',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    inviteLink,
                    style: TextStyle(
                      color: RegentColors.blue,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: RegentColors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: RegentColors.green, width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: RegentColors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your friend will get a personalized invite message',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.grey[700],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: RegentColors.blue,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.copy),
            label: const Text('Copy Link'),
            onPressed: () {
              _copyInviteLink(inviteLink);
              Navigator.pop(context);
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: RegentColors.green,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.share),
            label: const Text('Share'),
            onPressed: () {
              _shareInvite(inviteMessage);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _copyInviteLink(String link) {
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Invite link copied to clipboard!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareInvite(String message) {
    Share.share(
      message,
      subject: '🎓 Join Regent Connect!',
    );
  }
}
