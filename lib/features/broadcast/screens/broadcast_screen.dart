import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import '../../../core/theme_provider.dart';
import '../../../core/programs_data.dart';
import '../../../services/auth_service.dart';
import '../../../services/broadcast_service.dart';

class BroadcastScreen extends StatefulWidget {
  const BroadcastScreen({super.key});

  @override
  State<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends State<BroadcastScreen> {
  final authService = AuthService();
  final _firestore = FirebaseFirestore.instance;
  final _broadcastService = BroadcastService();
  final _messageController = TextEditingController();
  final Set<String> _selectedUserIds = {};
  final ImagePicker _imagePicker = ImagePicker();

  // Filters
  String? _selectedProgram;
  int? _selectedLevel;
  String? _selectedStream;
  List<String> _programs = [];
  final List<int> _levels = [100, 200, 300, 400];
  final List<String> _streams = ['Morning', 'Evening', 'Weekend'];

  // Media
  Uint8List? _selectedImage;
  Uint8List? _selectedVideo;
  Uint8List? _selectedFileBytes;
  String? _selectedFileName;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadPrograms();
  }

  void _loadPrograms() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      final programs = <String>{};

      // Collect all unique programs from users
      for (var doc in snapshot.docs) {
        final program = doc['program'];
        if (program != null && program.toString().isNotEmpty) {
          programs.add(program.toString());
        }
      }

      setState(() => _programs = programs.toList()..sort());

      // If no programs found in users, use default from programs_data
      if (_programs.isEmpty) {
        _loadDefaultPrograms();
      }
    } catch (e) {
      print('Error loading programs: $e');
      _loadDefaultPrograms();
    }
  }

  void _loadDefaultPrograms() {
    try {
      final List<String> allPrograms = [];

      // Import the programs data
      for (var faculty in universityFaculties) {
        for (var program in faculty.programs) {
          allPrograms.add(program.name);
        }
      }

      setState(() => _programs = allPrograms..sort());
    } catch (e) {
      print('Error loading default programs: $e');
      setState(() => _programs = [
            'Information Technology',
            'Software Engineering',
            'Computer Science',
            'Electrical Engineering',
            'Mechanical Engineering',
            'Civil Engineering',
            'Business Administration',
            'Accounting',
            'Economics',
          ]);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _captureFromCamera() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() => _selectedImage = bytes);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✓ Photo captured'),
              duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() => _selectedImage = bytes);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✓ Image selected'),
              duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _pickVideo() async {
    try {
      final video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
      );
      if (video != null) {
        final bytes = await video.readAsBytes();
        setState(() => _selectedVideo = bytes);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✓ Video selected'),
              duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        withData: true,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'txt',
          'ppt',
          'pptx'
        ],
      );

      if (result != null) {
        final file = result.files.single;
        if (file.bytes == null) {
          throw Exception('The selected file could not be read.');
        }
        setState(() {
          _selectedFileBytes = file.bytes;
          _selectedFileName = file.name;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('✓ File selected: ${result.files.single.name}'),
              duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _sendBroadcast() async {
    final message = _messageController.text.trim();
    if (message.isEmpty &&
        _selectedImage == null &&
        _selectedVideo == null &&
        _selectedFileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add message or media to send')),
      );
      return;
    }

    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one recipient')),
      );
      return;
    }

    setState(() => _isUploading = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Sending broadcast...', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );

    try {
      BroadcastAttachment? attachment;
      if (_selectedImage != null) {
        attachment = BroadcastAttachment(
          bytes: _selectedImage!,
          name: 'broadcast_image.jpg',
          type: 'image',
          contentType: 'image/jpeg',
        );
      } else if (_selectedVideo != null) {
        attachment = BroadcastAttachment(
          bytes: _selectedVideo!,
          name: 'broadcast_video.mp4',
          type: 'video',
          contentType: 'video/mp4',
        );
      } else if (_selectedFileBytes != null) {
        attachment = BroadcastAttachment(
          bytes: _selectedFileBytes!,
          name: _selectedFileName ?? 'attachment',
          type: 'file',
        );
      }

      await _broadcastService.sendBroadcast(
        recipientIds: _selectedUserIds,
        message: message,
        attachment: attachment,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        _messageController.clear();
        setState(() {
          _selectedUserIds.clear();
          _selectedImage = null;
          _selectedVideo = null;
          _selectedFileBytes = null;
          _selectedFileName = null;
          _isUploading = false;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('✓ Message sent to ${_selectedUserIds.length} recipient(s)'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A148C),
        elevation: 0,
        title: const Text('Broadcast Message',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Filters Section
          Container(
            padding: const EdgeInsets.all(16),
            color: isDark ? const Color(0xFF2D2D2D) : Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filter Recipients',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                // Programs Filter
                _buildFilterSection(
                  isDark: isDark,
                  label: 'Programs',
                  icon: Icons.school,
                  items: _programs,
                  selectedItem: _selectedProgram,
                  onSelected: (value) {
                    setState(() => _selectedProgram = value);
                  },
                ),
                const SizedBox(height: 12),

                // Levels Filter
                _buildFilterSection(
                  isDark: isDark,
                  label: 'Levels',
                  icon: Icons.stairs,
                  items: _levels.map((l) => l.toString()).toList(),
                  selectedItem: _selectedLevel?.toString(),
                  onSelected: (value) {
                    setState(() => _selectedLevel = int.tryParse(value ?? ''));
                  },
                ),
                const SizedBox(height: 12),

                // Streams Filter
                _buildFilterSection(
                  isDark: isDark,
                  label: 'Streams',
                  icon: Icons.schedule,
                  items: _streams,
                  selectedItem: _selectedStream,
                  onSelected: (value) {
                    setState(() => _selectedStream = value);
                  },
                ),

                // Clear Filters Button
                if (_selectedProgram != null ||
                    _selectedLevel != null ||
                    _selectedStream != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedProgram = null;
                            _selectedLevel = null;
                            _selectedStream = null;
                          });
                        },
                        icon: const Icon(Icons.clear, size: 18),
                        label: const Text('Clear All Filters'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF4A148C),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Recipients Count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDark ? Colors.grey[850] : Colors.grey[50],
            child: Row(
              children: [
                Icon(Icons.people, color: const Color(0xFF4A148C), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Recipients: ${_selectedUserIds.length}',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Recipients List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final program = data['program'];
                  final level = data['level'];
                  final stream = data['stream'];
                  final uid = doc.id;

                  // Filter out current user
                  if (uid == authService.currentUser?.uid) return false;

                  // Apply filters
                  if (_selectedProgram != null && program != _selectedProgram) {
                    return false;
                  }
                  if (_selectedLevel != null && level != _selectedLevel) {
                    return false;
                  }
                  if (_selectedStream != null && stream != _selectedStream) {
                    return false;
                  }

                  return true;
                }).toList();

                if (users.isEmpty) {
                  return Center(
                    child: Text(
                      'No users match your filters',
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.grey,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final data = user.data() as Map<String, dynamic>;
                    final isSelected = _selectedUserIds.contains(user.id);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: data['photoUrl'] != null
                            ? NetworkImage(data['photoUrl'])
                            : null,
                        backgroundColor:
                            isDark ? Colors.grey[700] : Colors.grey[300],
                        child: data['photoUrl'] == null
                            ? Text(
                                data['displayName'][0].toUpperCase(),
                                style: const TextStyle(fontSize: 18),
                              )
                            : null,
                      ),
                      title: Text(
                        data['displayName'] ?? 'Unknown',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        '${data['program'] ?? 'N/A'} • Level ${data['level'] ?? 100} • ${data['stream'] ?? 'N/A'}',
                        style: TextStyle(
                            color: isDark ? Colors.white60 : Colors.grey,
                            fontSize: 12),
                      ),
                      trailing: Checkbox(
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value!) {
                              _selectedUserIds.add(user.id);
                            } else {
                              _selectedUserIds.remove(user.id);
                            }
                          });
                        },
                      ),
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedUserIds.remove(user.id);
                          } else {
                            _selectedUserIds.add(user.id);
                          }
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),

          // Message Input & Media Upload
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white12 : Colors.grey[300]!,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Media Upload Buttons
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildMediaButton(
                        icon: Icons.camera_alt,
                        label: 'Camera',
                        color: Colors.red,
                        onTap: _captureFromCamera,
                      ),
                      const SizedBox(width: 8),
                      _buildMediaButton(
                        icon: Icons.image,
                        label: 'Photo',
                        color: Colors.blue,
                        onTap: _pickImageFromGallery,
                      ),
                      const SizedBox(width: 8),
                      _buildMediaButton(
                        icon: Icons.videocam,
                        label: 'Video',
                        color: Colors.purple,
                        onTap: _pickVideo,
                      ),
                      const SizedBox(width: 8),
                      _buildMediaButton(
                        icon: Icons.file_present,
                        label: 'File',
                        color: Colors.orange,
                        onTap: _pickFile,
                      ),
                    ],
                  ),
                ),

                // Selected Media Preview
                if (_selectedImage != null ||
                    _selectedVideo != null ||
                    _selectedFileBytes != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        if (_selectedImage != null) ...[
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: MemoryImage(_selectedImage!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Photo selected',
                              style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.grey),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () =>
                                setState(() => _selectedImage = null),
                          ),
                        ] else if (_selectedVideo != null) ...[
                          const Icon(Icons.videocam,
                              color: Colors.purple, size: 40),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Video selected',
                              style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.grey),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () =>
                                setState(() => _selectedVideo = null),
                          ),
                        ] else if (_selectedFileBytes != null) ...[
                          const Icon(Icons.file_present,
                              color: Colors.orange, size: 40),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedFileName ?? 'File selected',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.grey),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => setState(() {
                              _selectedFileBytes = null;
                              _selectedFileName = null;
                            }),
                          ),
                        ],
                      ],
                    ),
                  ),

                const SizedBox(height: 12),

                // Message Input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        maxLines: 3,
                        minLines: 1,
                        style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          hintText: 'Type your broadcast message...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white60 : Colors.grey,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor:
                              isDark ? Colors.grey[800] : Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF4A148C),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: _isUploading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send, color: Colors.white),
                        onPressed: _isUploading ? null : _sendBroadcast,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection({
    required bool isDark,
    required String label,
    required IconData icon,
    required List<String> items,
    required String? selectedItem,
    required Function(String?) onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon,
                size: 18,
                color: isDark ? Colors.white70 : const Color(0xFF4A148C)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                isDark: isDark,
                label: 'All',
                isSelected: selectedItem == null,
                onTap: () => onSelected(null),
              ),
              const SizedBox(width: 8),
              ...items.map((item) {
                final displayLabel =
                    item.length > 15 ? '${item.substring(0, 15)}...' : item;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildFilterChip(
                    isDark: isDark,
                    label: displayLabel,
                    isSelected: selectedItem == item,
                    onTap: () => onSelected(selectedItem == item ? null : item),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required bool isDark,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4A148C)
              : (isDark ? Colors.grey[800] : Colors.grey[200]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF4A148C) : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF4A148C).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : Colors.grey[700]),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
