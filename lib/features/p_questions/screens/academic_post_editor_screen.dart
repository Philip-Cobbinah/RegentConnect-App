import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:intl/intl.dart';

import '../../../core/media_utils.dart';
import '../../../core/programs_data.dart';
import '../../../core/theme.dart';
import '../../../models/academic_post_model.dart';
import '../../../services/academic_service.dart';

class AcademicPostEditorScreen extends StatefulWidget {
  final String initialPostType;
  final int? defaultLevel;
  final String? defaultProgram;

  const AcademicPostEditorScreen({
    super.key,
    required this.initialPostType,
    this.defaultLevel,
    this.defaultProgram,
  });

  @override
  State<AcademicPostEditorScreen> createState() =>
      _AcademicPostEditorScreenState();
}

class _AcademicPostEditorScreenState extends State<AcademicPostEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = AcademicService();
  final _imagePicker = ImagePicker();
  final _audioRecorder = Record();
  final _titleController = TextEditingController();
  final _captionController = TextEditingController();
  final _courseCodeController = TextEditingController();
  final _courseNameController = TextEditingController();

  final List<AcademicAttachmentDraft> _attachments = [];
  final Set<int> _selectedLevels = {};
  final Set<String> _selectedPrograms = {};

  late final List<String> _programOptions;
  late String _postType;
  late String _postingRole;
  bool _isSaving = false;
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  DateTime? _scheduleDateTime;
  String? _pendingProgramValue;

  @override
  void initState() {
    super.initState();
    _postType = widget.initialPostType == 'lecture' ? 'lecture' : 'assignment';
    _postingRole = _postType == 'lecture' ? 'lecturer' : 'class_rep';
    _programOptions = universityFaculties
        .expand((faculty) => faculty.programs.map((program) => program.name))
        .toList()
      ..sort();

    if (widget.defaultLevel != null) {
      _selectedLevels.add(widget.defaultLevel!);
    }
    if ((widget.defaultProgram ?? '').trim().isNotEmpty) {
      final program = widget.defaultProgram!.trim();
      if (_programOptions.contains(program)) {
        _selectedPrograms.add(program);
        _pendingProgramValue = program;
      }
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _titleController.dispose();
    _captionController.dispose();
    _courseCodeController.dispose();
    _courseNameController.dispose();
    super.dispose();
  }

  Future<void> _savePost() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    if (_postType == 'assignment' &&
        _selectedLevels.isEmpty &&
        _selectedPrograms.isEmpty &&
        _courseCodeController.text.trim().isEmpty &&
        _courseNameController.text.trim().isEmpty) {
      _showSnackBar(
        'Please tag the assignment by level, program, or course.',
        isError: true,
      );
      return;
    }

    if (_isRecording) {
      _showSnackBar('Please finish the recording before publishing.',
          isError: true);
      return;
    }

    final combinedCourses = <String>[
      _courseCodeController.text.trim(),
      _courseNameController.text.trim(),
    ].where((value) => value.isNotEmpty).toList();

    setState(() => _isSaving = true);

    try {
      final postId = await _service.createAcademicPost(
        postType: _postType,
        title: _titleController.text.trim(),
        caption: _captionController.text.trim(),
        courseCode: _courseCodeController.text.trim().isEmpty
            ? null
            : _courseCodeController.text.trim(),
        courseName: _courseNameController.text.trim().isEmpty
            ? null
            : _courseNameController.text.trim(),
        targetLevels: _selectedLevels.toList(),
        targetPrograms: _selectedPrograms.toList(),
        targetCourses: combinedCourses,
        dueAt: _postType == 'assignment' ? _scheduleDateTime : null,
        lectureAt: _postType == 'lecture' ? _scheduleDateTime : null,
        authorRole: _postingRole,
        attachments: _attachments,
      );

      if (!mounted) return;
      Navigator.pop(context, postId);
    } catch (error) {
      if (mounted) {
        _showSnackBar('Could not publish the post: $error', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : RegentColors.green,
      ),
    );
  }

  void _addLevel(int level) {
    setState(() {
      if (!_selectedLevels.add(level)) {
        _selectedLevels.remove(level);
      }
    });
  }

  void _addProgram() {
    final program = _pendingProgramValue?.trim();
    if (program == null || program.isEmpty) return;
    setState(() {
      _selectedPrograms.add(program);
    });
  }

  void _removeProgram(String program) {
    setState(() => _selectedPrograms.remove(program));
  }

  void _removeAttachment(AcademicAttachmentDraft attachment) {
    setState(() => _attachments.remove(attachment));
  }

  Future<void> _pickScheduleDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
    );

    setState(() {
      _scheduleDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime?.hour ?? 12,
        pickedTime?.minute ?? 0,
      );
    });
  }

  Future<void> _showAttachmentMenu() async {
    if (_isSaving) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: RegentColors.dmSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Add attachment',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildAttachmentAction(
                      icon: Icons.image_outlined,
                      label: 'Photo',
                      color: Colors.purple,
                      onTap: () {
                        Navigator.pop(context);
                        _pickImageFromGallery();
                      },
                    ),
                    _buildAttachmentAction(
                      icon: Icons.document_scanner_outlined,
                      label: 'Scan',
                      color: RegentColors.green,
                      onTap: () {
                        Navigator.pop(context);
                        _pickScanDocument();
                      },
                    ),
                    _buildAttachmentAction(
                      icon: Icons.insert_drive_file_outlined,
                      label: 'File',
                      color: RegentColors.violet,
                      onTap: () {
                        Navigator.pop(context);
                        _pickDocumentFile();
                      },
                    ),
                    _buildAttachmentAction(
                      icon: Icons.play_circle_outline,
                      label: 'Video',
                      color: Colors.red,
                      onTap: () {
                        Navigator.pop(context);
                        _pickVideoFile();
                      },
                    ),
                    _buildAttachmentAction(
                      icon: Icons.graphic_eq,
                      label: 'Audio',
                      color: Colors.orange,
                      onTap: () {
                        Navigator.pop(context);
                        _pickAudioFile();
                      },
                    ),
                    _buildAttachmentAction(
                      icon: Icons.mic_none_outlined,
                      label: 'Record',
                      color: Colors.blue,
                      onTap: () {
                        Navigator.pop(context);
                        _startRecording();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 104,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromGallery() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    setState(() {
      _attachments.add(
        AcademicAttachmentDraft(
          bytes: bytes,
          fileName: image.name,
          kind: 'image',
          contentType: image.mimeType ?? 'image/jpeg',
        ),
      );
    });
  }

  Future<void> _pickScanDocument() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    final extension = image.name.toLowerCase().contains('.')
        ? image.name.split('.').last
        : 'jpg';
    setState(() {
      _attachments.add(
        AcademicAttachmentDraft(
          bytes: bytes,
          fileName: 'scan_${DateTime.now().millisecondsSinceEpoch}.$extension',
          kind: 'image',
          contentType: image.mimeType ?? 'image/jpeg',
        ),
      );
    });
  }

  Future<void> _pickDocumentFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'doc',
        'docx',
        'ppt',
        'pptx',
        'xls',
        'xlsx',
        'txt',
      ],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    setState(() {
      _attachments.add(
        AcademicAttachmentDraft(
          bytes: bytes,
          fileName: file.name,
          kind: 'file',
          contentType: MediaUtils.contentTypeForName(file.name),
        ),
      );
    });
  }

  Future<void> _pickVideoFile() async {
    final video = await _imagePicker.pickVideo(source: ImageSource.gallery);
    if (video == null) return;
    final bytes = await video.readAsBytes();
    setState(() {
      _attachments.add(
        AcademicAttachmentDraft(
          bytes: bytes,
          fileName: video.name,
          kind: 'video',
          contentType: video.mimeType ?? 'video/mp4',
        ),
      );
    });
  }

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['m4a', 'mp3', 'wav', 'aac', 'ogg', 'webm'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    setState(() {
      _attachments.add(
        AcademicAttachmentDraft(
          bytes: bytes,
          fileName: file.name,
          kind: 'audio',
          contentType: MediaUtils.contentTypeForName(file.name),
        ),
      );
    });
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;
    try {
      if (!await _audioRecorder.hasPermission()) {
        _showSnackBar('Microphone permission is required.', isError: true);
        return;
      }

      String? path;
      if (!kIsWeb) {
        final temporaryDirectory = await getTemporaryDirectory();
        path =
            '${temporaryDirectory.path}/academic_${DateTime.now().millisecondsSinceEpoch}.m4a';
      }

      await _audioRecorder.start(
        encoder: AudioEncoder.aacLc,
        path: path,
      );

      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
      });

      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _isRecording) {
          setState(() => _recordingSeconds++);
        }
      });
    } catch (error) {
      _showSnackBar('Recording could not start: $error', isError: true);
    }
  }

  Future<void> _stopRecording({bool keep = true}) async {
    if (!_isRecording) return;
    _recordingTimer?.cancel();
    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);

    if (!keep) {
      setState(() => _recordingSeconds = 0);
      return;
    }

    if (path == null || path.isEmpty) {
      _showSnackBar('Recording could not be saved.', isError: true);
      setState(() => _recordingSeconds = 0);
      return;
    }

    final bytes = await XFile(path).readAsBytes();
    setState(() {
      _attachments.add(
        AcademicAttachmentDraft(
          bytes: bytes,
          fileName: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
          kind: 'audio',
          contentType: 'audio/mp4',
        ),
      );
      _recordingSeconds = 0;
    });
  }

  Future<void> _cancelRecording() async {
    if (!_isRecording) return;
    await _stopRecording(keep: false);
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
  }

  String _roleLabel(String role) {
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? RegentColors.dmBackground : RegentColors.lightBackground;
    final cardColor = isDark ? RegentColors.dmCard : Colors.white;
    final subtleText = isDark ? Colors.white60 : Colors.grey.shade700;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor:
            isDark ? RegentColors.dmSurface : RegentColors.primaryDark,
        foregroundColor: Colors.white,
        title: Text(
          _postType == 'lecture'
              ? 'Upload Lecture Resource'
              : 'Create Assignment',
        ),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _savePost,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send_rounded, color: Colors.white),
            label: const Text(
              'Publish',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [RegentColors.violet, RegentColors.darkViolet],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.school_outlined,
                        color: Colors.white, size: 34),
                    const SizedBox(height: 10),
                    const Text(
                      'Professional Academic Publisher',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Post assignments, lecture notes, audio clips, slides, videos and scanned documents in one polished workspace.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'assignment',
                          icon: Icon(Icons.assignment_outlined),
                          label: Text('Assignment'),
                        ),
                        ButtonSegment(
                          value: 'lecture',
                          icon: Icon(Icons.video_library_outlined),
                          label: Text('Lecture'),
                        ),
                      ],
                      selected: {_postType},
                      onSelectionChanged: (value) {
                        setState(() {
                          _postType = value.first;
                          _postingRole =
                              _postType == 'lecture' ? 'lecturer' : 'class_rep';
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _postingRole,
                decoration: InputDecoration(
                  labelText: 'Posting as',
                  filled: true,
                  fillColor: cardColor,
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'class_rep', child: Text('Class Rep')),
                  DropdownMenuItem(value: 'lecturer', child: Text('Lecturer')),
                  DropdownMenuItem(
                      value: 'official', child: Text('Academic Office')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _postingRole = value);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: _postType == 'lecture'
                      ? 'Lecture title'
                      : 'Assignment title',
                  hintText: _postType == 'lecture'
                      ? 'e.g. Week 3: Introduction to Networking'
                      : 'e.g. Assignment 2: Database normalization',
                  filled: true,
                  fillColor: cardColor,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _captionController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Caption (optional)',
                  hintText:
                      'Add instructions, learning goals, or extra context',
                  filled: true,
                  fillColor: cardColor,
                ),
              ),
              const SizedBox(height: 16),
              if (_postType == 'assignment' || _postType == 'lecture') ...[
                Card(
                  color: cardColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                        color: RegentColors.violet.withOpacity(0.12)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.local_offer_outlined,
                                color: RegentColors.violet),
                            const SizedBox(width: 8),
                            const Text(
                              'Target audience',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Choose the students who should see this post. Assignments are easiest to find when you tag the right level.',
                          style: TextStyle(color: subtleText, height: 1.3),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [100, 200, 300, 400].map((level) {
                            final selected = _selectedLevels.contains(level);
                            return FilterChip(
                              selected: selected,
                              label: Text('Level $level'),
                              onSelected: (_) => _addLevel(level),
                            );
                          }).toList(),
                        ),
                        if (_selectedLevels.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _selectedLevels.map((level) {
                              return Chip(
                                label: Text('Level $level'),
                                onDeleted: () => _addLevel(level),
                              );
                            }).toList(),
                          ),
                        ],
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _pendingProgramValue,
                          decoration: InputDecoration(
                            labelText: 'Program',
                            filled: true,
                            fillColor: background,
                          ),
                          isExpanded: true,
                          items: _programOptions
                              .map(
                                (program) => DropdownMenuItem(
                                  value: program,
                                  child: Text(
                                    program,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() => _pendingProgramValue = value);
                          },
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _pendingProgramValue == null
                                ? null
                                : _addProgram,
                            icon: const Icon(Icons.add),
                            label: const Text('Add program tag'),
                          ),
                        ),
                        if (_selectedPrograms.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _selectedPrograms.map((program) {
                              return Chip(
                                label: Text(program),
                                onDeleted: () => _removeProgram(program),
                              );
                            }).toList(),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _courseCodeController,
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: InputDecoration(
                                  labelText: 'Course code (optional)',
                                  hintText: 'e.g. CSC 101',
                                  filled: true,
                                  fillColor: background,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _courseNameController,
                                textCapitalization: TextCapitalization.words,
                                decoration: InputDecoration(
                                  labelText: 'Course title (optional)',
                                  hintText: 'e.g. Introduction to Computing',
                                  filled: true,
                                  fillColor: background,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Card(
                color: cardColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side:
                      BorderSide(color: RegentColors.violet.withOpacity(0.12)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.schedule_outlined,
                              color: RegentColors.violet),
                          const SizedBox(width: 8),
                          Text(
                            _postType == 'lecture'
                                ? 'Lecture timing'
                                : 'Assignment deadline',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _scheduleDateTime == null
                            ? 'Optional, but useful for planning and visibility.'
                            : DateFormat('EEE, MMM d • h:mm a')
                                .format(_scheduleDateTime!),
                        style: TextStyle(color: subtleText),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _pickScheduleDate,
                        icon: const Icon(Icons.event_available_outlined),
                        label: Text(
                          _scheduleDateTime == null
                              ? (_postType == 'lecture'
                                  ? 'Set lecture date'
                                  : 'Set due date')
                              : 'Change date and time',
                        ),
                      ),
                      if (_scheduleDateTime != null)
                        TextButton(
                          onPressed: () =>
                              setState(() => _scheduleDateTime = null),
                          child: const Text('Clear date'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: cardColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side:
                      BorderSide(color: RegentColors.violet.withOpacity(0.12)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.attach_file_rounded,
                              color: RegentColors.violet),
                          const SizedBox(width: 8),
                          const Text(
                            'Attachments',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Add text support materials, photos, scanned documents, slides, audio notes or video files.',
                        style: TextStyle(color: subtleText, height: 1.3),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _showAttachmentMenu,
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text('Add attachment'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (_attachments.isNotEmpty)
                            Text(
                              '${_attachments.length} selected',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                      if (_isRecording) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border:
                                Border.all(color: Colors.red.withOpacity(0.25)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.fiber_manual_record,
                                  color: Colors.red),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Recording ${_formatDuration(_recordingSeconds)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                              TextButton(
                                onPressed: () => _stopRecording(),
                                child: const Text('Stop'),
                              ),
                              TextButton(
                                onPressed: _cancelRecording,
                                child: const Text('Cancel'),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_attachments.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        ..._attachments.map((attachment) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _AttachmentPreviewTile(
                              attachment: attachment,
                              onRemove: () => _removeAttachment(attachment),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _savePost,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.publish_outlined),
                  label: Text(
                    _postType == 'lecture'
                        ? 'Publish lecture resource'
                        : 'Publish assignment',
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentPreviewTile extends StatelessWidget {
  final AcademicAttachmentDraft attachment;
  final VoidCallback onRemove;

  const _AttachmentPreviewTile({
    required this.attachment,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isImage = attachment.kind == 'image';
    final color = switch (attachment.kind) {
      'video' => Colors.red,
      'audio' => Colors.orange,
      'file' => RegentColors.violet,
      _ => RegentColors.green,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: isImage
                ? Image.memory(
                    attachment.bytes,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 64,
                    height: 64,
                    color: color.withOpacity(0.12),
                    child: Icon(
                      switch (attachment.kind) {
                        'video' => Icons.play_circle_outline,
                        'audio' => Icons.graphic_eq,
                        'file' => Icons.insert_drive_file_outlined,
                        _ => Icons.image_outlined,
                      },
                      color: color,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  attachment.kind.toUpperCase(),
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}
