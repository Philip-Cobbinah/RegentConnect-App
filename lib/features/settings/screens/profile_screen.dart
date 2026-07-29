import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme.dart';
import '../../../services/user_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = UserService();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  bool _isUploading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 512,
      maxHeight: 512,
    );

    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final url = await _userService.uploadProfilePictureBytes(
        await image.readAsBytes(),
        contentType: image.mimeType ?? 'image/jpeg',
      );
      if (url != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated!'),
            backgroundColor: RegentColors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: RegentColors.dmSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Profile Photo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _imageOption(Icons.camera_alt, 'Camera', () {
                  Navigator.pop(context);
                  _pickAndUploadImage(ImageSource.camera);
                }),
                _imageOption(Icons.photo_library, 'Gallery', () {
                  Navigator.pop(context);
                  _pickAndUploadImage(ImageSource.gallery);
                }),
                _imageOption(Icons.delete, 'Remove', () {
                  Navigator.pop(context);
                  _removeProfilePicture();
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: RegentColors.violet,
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _removeProfilePicture() async {
    setState(() => _isUploading = true);
    try {
      await _userService.removeProfilePicture();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture removed'),
            backgroundColor: RegentColors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      await _userService.updateProfile(
        fullName: _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : null,
        bio: _bioController.text.trim().isNotEmpty
            ? _bioController.text.trim()
            : null,
        phone: _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated!'),
            backgroundColor: RegentColors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RegentColors.dmBackground,
      appBar: AppBar(
        backgroundColor: RegentColors.dmSurface,
        title:
            const Text('Edit Profile', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Save',
                    style: TextStyle(color: RegentColors.violet)),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _userService.getCurrentUserStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: RegentColors.violet));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};

          // Initialize controllers with current data
          if (_nameController.text.isEmpty && userData['fullName'] != null) {
            _nameController.text = userData['fullName'];
          }
          if (_bioController.text.isEmpty && userData['bio'] != null) {
            _bioController.text = userData['bio'];
          }
          if (_phoneController.text.isEmpty && userData['phone'] != null) {
            _phoneController.text = userData['phone'];
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Profile Picture
                Stack(
                  children: [
                    GestureDetector(
                      onTap: _isUploading ? null : _showImageOptions,
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: RegentColors.violet,
                        backgroundImage: userData['photoUrl'] != null
                            ? NetworkImage(userData['photoUrl'])
                            : null,
                        child: _isUploading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : userData['photoUrl'] == null
                                ? Text(
                                    (userData['fullName'] ??
                                            userData['email'] ??
                                            'U')[0]
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _isUploading ? null : _showImageOptions,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: RegentColors.violet,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: RegentColors.dmBackground, width: 3),
                          ),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  userData['email'] ?? '',
                  style: const TextStyle(color: Colors.white54),
                ),
                const SizedBox(height: 30),

                // Name field
                _buildTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  icon: Icons.person,
                ),
                const SizedBox(height: 16),

                // Bio field
                _buildTextField(
                  controller: _bioController,
                  label: 'Bio',
                  icon: Icons.info_outline,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                // Phone field
                _buildTextField(
                  controller: _phoneController,
                  label: 'Phone',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),

                // Program (read-only)
                if (userData['program'] != null)
                  _buildInfoTile('Program', userData['program'], Icons.school),

                // Level (read-only)
                if (userData['level'] != null)
                  _buildInfoTile('Level', userData['level'], Icons.layers),

                // Session (read-only)
                if (userData['session'] != null)
                  _buildInfoTile(
                    'Session',
                    userData['session'].toString(),
                    Icons.schedule,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: RegentColors.violet),
        filled: true,
        fillColor: RegentColors.dmCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: RegentColors.violet, width: 2),
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RegentColors.dmCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: RegentColors.violet),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
              Text(value,
                  style: const TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }
}
