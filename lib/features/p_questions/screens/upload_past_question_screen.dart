import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme.dart';
import '../../../services/past_questions_service.dart';
import '../../../services/auth_service.dart';

class UploadPastQuestionScreen extends StatefulWidget {
  final String facultyName;
  final String programName;
  final String? option;
  final int level;
  final int semester;
  final String termLabel;
  final String? initialCourseCode;
  final String? initialCourseName;
  final int? initialYear;

  const UploadPastQuestionScreen({
    super.key,
    required this.facultyName,
    required this.programName,
    this.option,
    required this.level,
    required this.semester,
    this.termLabel = 'Semester',
    this.initialCourseCode,
    this.initialCourseName,
    this.initialYear,
  });

  @override
  State<UploadPastQuestionScreen> createState() => _UploadPastQuestionScreenState();
}

class _UploadPastQuestionScreenState extends State<UploadPastQuestionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _courseCodeController = TextEditingController();
  final _courseNameController = TextEditingController();
  
  int? selectedYear;
  Uint8List? selectedFileBytes;
  String? selectedFileName;
  String? selectedFileType;
  bool isUploading = false;

  final List<int> years = List.generate(11, (index) => 2025 - index); // 2025-2015
  final pastQuestionsService = PastQuestionsService();
  final authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _courseCodeController.text = widget.initialCourseCode ?? '';
    _courseNameController.text = widget.initialCourseName ?? '';
    selectedYear = widget.initialYear;
  }

  @override
  void dispose() {
    _courseCodeController.dispose();
    _courseNameController.dispose();
    super.dispose();
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Upload Source',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildUploadOption(
                    icon: Icons.picture_as_pdf,
                    label: 'PDF',
                    color: Colors.red,
                    onTap: () {
                      Navigator.pop(context);
                      _pickPDF();
                    },
                  ),
                  _buildUploadOption(
                    icon: Icons.insert_drive_file,
                    label: 'File',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      _pickFile();
                    },
                  ),
                  _buildUploadOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(context);
                      _pickFromCamera();
                    },
                  ),
                  _buildUploadOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pop(context);
                      _pickFromGallery();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPDF() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          selectedFileBytes = file.bytes;
          selectedFileName = file.name;
          selectedFileType = 'pdf';
        });
      }
    } catch (e) {
      _showError('Error picking PDF: $e');
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          selectedFileBytes = file.bytes;
          selectedFileName = file.name;
          selectedFileType = file.extension;
        });
      }
    } catch (e) {
      _showError('Error picking file: $e');
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final extension = image.path.split('.').last.toLowerCase();
        setState(() {
          selectedFileBytes = bytes;
          selectedFileName = 'camera_${DateTime.now().millisecondsSinceEpoch}.$extension';
          selectedFileType = extension;
        });
      }
    } catch (e) {
      _showError('Error capturing image: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final extension = image.path.split('.').last.toLowerCase();
        setState(() {
          selectedFileBytes = bytes;
          selectedFileName = image.name;
          selectedFileType = extension;
        });
      }
    } catch (e) {
      _showError('Error picking image: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _uploadFile() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedFileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file to upload')),
      );
      return;
    }
    if (selectedYear == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a year')),
      );
      return;
    }

    final user = authService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to upload')),
      );
      return;
    }

    setState(() => isUploading = true);

    try {
      final result = await pastQuestionsService.uploadPastQuestion(
        courseCode: _courseCodeController.text.trim().toUpperCase(),
        courseName: _courseNameController.text.trim(),
        programName: widget.programName,
        facultyName: widget.facultyName,
        level: widget.level,
        semester: widget.semester,
        year: selectedYear!,
        fileBytes: selectedFileBytes!,
        fileName: selectedFileName!,
        fileType: selectedFileType!,
        uploadedBy: user.uid,
        uploaderName: user.displayName ?? 'Unknown',
      );

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Past question uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        throw Exception('Upload failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isUploading = false);
      }
    }
  }

  void _clearSelectedFile() {
    setState(() {
      selectedFileBytes = null;
      selectedFileName = null;
      selectedFileType = null;
    });
  }

  Widget _getFilePreview() {
    if (selectedFileBytes == null) return const SizedBox.shrink();

    final isImage = ['png', 'jpg', 'jpeg'].contains(selectedFileType?.toLowerCase());

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RegentColors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RegentColors.green),
      ),
      child: Column(
        children: [
          if (isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                selectedFileBytes!,
                height: 200,
                fit: BoxFit.cover,
              ),
            )
          else
            Icon(
              _getFileIconData(selectedFileType ?? ''),
              size: 64,
              color: _getFileColor(selectedFileType ?? ''),
            ),
          const SizedBox(height: 12),
          Text(
            selectedFileName ?? 'Unknown file',
            style: const TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '${(selectedFileBytes!.length / 1024).toStringAsFixed(1)} KB • ${selectedFileType?.toUpperCase()}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _clearSelectedFile,
            icon: const Icon(Icons.close, color: Colors.red),
            label: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  IconData _getFileIconData(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'png':
      case 'jpg':
      case 'jpeg':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'png':
      case 'jpg':
      case 'jpeg':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: RegentColors.blue,
        title: const Text('Upload Past Question', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Card
              Card(
                color: RegentColors.blue.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline, color: RegentColors.blue),
                          SizedBox(width: 8),
                          Text(
                            'Uploading for:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Program: ${widget.programName}'),
                      if (widget.option != null) Text('Option: ${widget.option}'),
                      Text('Level: ${widget.level}'),
                      Text('${widget.termLabel}: ${widget.semester}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Course Code (Optional)
              TextFormField(
                controller: _courseCodeController,
                decoration: const InputDecoration(
                  labelText: 'Course Code (Optional)',
                  hintText: 'e.g., CS101',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.code),
                  helperText: 'Leave empty if unknown',
                ),
                textCapitalization: TextCapitalization.characters,
                // Remove validator - no longer required
              ),
              const SizedBox(height: 16),

              // Course Name (Required)
              TextFormField(
                controller: _courseNameController,
                decoration: const InputDecoration(
                  labelText: 'Course Name *',
                  hintText: 'e.g., Introduction to Programming',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.book),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter course name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Year Dropdown
              DropdownButtonFormField<int>(
                initialValue: selectedYear,
                decoration: const InputDecoration(
                  labelText: 'Year',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                items: years.map((year) {
                  return DropdownMenuItem(
                    value: year,
                    child: Text('$year'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => selectedYear = value);
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a year';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // File Selection Section
              const Text(
                'Select File',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'Supported formats: PDF, DOC, DOCX, PNG, JPG, JPEG',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 12),
              
              // Upload Button with popup
              if (selectedFileBytes == null)
                InkWell(
                  onTap: _showUploadOptions,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey, width: 2),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.withOpacity(0.1),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.cloud_upload, size: 48, color: Colors.grey),
                        SizedBox(height: 12),
                        Text(
                          'Tap to select file',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'PDF, Document, or Image',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),

              // File Preview
              _getFilePreview(),

              // Change file button
              if (selectedFileBytes != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: OutlinedButton.icon(
                    onPressed: _showUploadOptions,
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Change File'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  ),
                ),

              const SizedBox(height: 32),

              // Upload Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isUploading ? null : _uploadFile,
                  icon: isUploading 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.upload),
                  label: Text(isUploading ? 'Uploading...' : 'Upload Past Question'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RegentColors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
