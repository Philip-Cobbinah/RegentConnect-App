import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/programs_data.dart';
import '../../../core/theme.dart';
import '../../../models/course_registration_model.dart';
import '../../../services/course_registration_service.dart';
import '../../../services/course_registration_pdf_service.dart';

String _resolveSession(String? value) {
  final normalized = value?.trim().toLowerCase() ?? '';
  if (normalized.contains('weekend')) return 'weekend';
  if (normalized.contains('evening')) return 'evening';
  return 'morning';
}

String _termLabelForSession(String session) =>
    session == 'weekend' ? 'Trimester' : 'Semester';

List<int> _termOptionsForSession(String session) =>
    session == 'weekend' ? [1, 2, 3] : [1, 2];

class CourseRegistrationScreen extends StatefulWidget {
  const CourseRegistrationScreen({super.key});

  @override
  State<CourseRegistrationScreen> createState() =>
      _CourseRegistrationScreenState();
}

class _CourseRegistrationScreenState extends State<CourseRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = CourseRegistrationService();
  final _imagePicker = ImagePicker();
  final _studentIdController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _pdfService = CourseRegistrationPdfService();

  FacultyData? _selectedFaculty;
  ProgramData? _selectedProgram;
  int? _selectedLevel;
  int? _selectedTerm;
  DateTime _selectedDate = DateTime.now();
  String _academicSession = 'morning';
  Uint8List? _attachmentBytes;
  String? _attachmentName;
  String? _attachmentContentType;
  bool _bootstrappedProfile = false;
  bool _submitting = false;
  final Set<String> _selectedCourseKeys = <String>{};

  final List<int> _levels = const [100, 200, 300, 400];
  final TextEditingController _dateController = TextEditingController(
    text: DateTime.now().toLocal().toString().split(' ').first,
  );

  @override
  void dispose() {
    _studentIdController.dispose();
    _fullNameController.dispose();
    _phoneNumberController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to access course registration.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Course Registration'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          final userData = snapshot.data?.data() ?? <String, dynamic>{};
          _bootstrapProfile(userData);
          final session = _resolveSession(userData['session']?.toString());
          final termLabel = _termLabelForSession(session);
          final termOptions = _termOptionsForSession(session);
          final programOptions = _selectedFaculty?.programs ?? const <ProgramData>[];

          if (_selectedTerm != null && !termOptions.contains(_selectedTerm)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selectedTerm = null);
            });
          }

          if (_selectedTerm == null && termOptions.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selectedTerm = termOptions.first);
            });
          }

          final currentFaculty = _selectedFaculty;
          final currentProgram = _selectedProgram;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(session, termLabel, userData),
                const SizedBox(height: 16),
                _buildFormCard(
                  context,
                  termLabel: termLabel,
                  termOptions: termOptions,
                  programOptions: programOptions,
                ),
                const SizedBox(height: 16),
                _buildSelectedCoursesCard(termLabel),
                const SizedBox(height: 16),
                _buildAttachmentCard(context),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : _openPreviewSheet,
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.preview_rounded),
                    label: Text(
                      _submitting ? 'Submitting...' : 'Review & submit',
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _buildRegistrationHistory(),
                if (currentFaculty != null || currentProgram != null)
                  const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(
    String session,
    String termLabel,
    Map<String, dynamic> userData,
  ) {
    final fullName = _fullNameController.text.trim().isEmpty
        ? (userData['fullName']?.toString().trim().isNotEmpty == true
            ? userData['fullName'].toString().trim()
            : FirebaseAuth.instance.currentUser?.displayName ?? 'Student')
        : _fullNameController.text.trim();
    final levelText = _selectedLevel == null ? 'Level not set' : 'Level $_selectedLevel';
    final facultyText = _selectedFaculty?.name ?? 'Faculty not selected';
    final programText = _selectedProgram?.name ?? 'Program not selected';
    final sessionText =
        '${session[0].toUpperCase()}${session.substring(1)} session';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [RegentColors.violet, RegentColors.darkViolet],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.assignment_ind_rounded, color: Colors.white, size: 30),
          const SizedBox(height: 10),
          const Text(
            'Course registration',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Prepare and preview your ${termLabel.toLowerCase()} registration before you submit it to the faculty office.',
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
              _headerChip(fullName),
              _headerChip(levelText),
              _headerChip(sessionText),
              _headerChip(facultyText),
              _headerChip(programText),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Session: ${session[0].toUpperCase()}${session.substring(1)}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.82),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildFormCard(
    BuildContext context, {
    required String termLabel,
    required List<int> termOptions,
    required List<ProgramData> programOptions,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      color: isDark ? RegentColors.dmCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Registration details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Fill the details exactly as they appear on your student record.',
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _studentIdController,
                decoration: const InputDecoration(
                  labelText: 'Student ID',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter your student ID';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter your full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneNumberController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telephone number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter your telephone number'
                    : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<FacultyData>(
                value: _selectedFaculty,
                decoration: const InputDecoration(
                  labelText: 'Select faculty',
                  prefixIcon: Icon(Icons.account_balance_outlined),
                ),
                items: universityFaculties
                    .map(
                      (faculty) => DropdownMenuItem(
                        value: faculty,
                        child: Text(faculty.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedFaculty = value;
                    _selectedProgram = null;
                    _selectedCourseKeys.clear();
                  });
                },
                validator: (value) =>
                    value == null ? 'Select your faculty' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<ProgramData>(
                value: _selectedProgram,
                decoration: const InputDecoration(
                  labelText: 'Select program',
                  prefixIcon: Icon(Icons.school_outlined),
                ),
                items: programOptions
                    .map(
                      (program) => DropdownMenuItem(
                        value: program,
                        child: Text(program.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: _selectedFaculty == null
                    ? null
                    : (value) => setState(() {
                        _selectedProgram = value;
                        _selectDefaultCourses();
                      }),
                validator: (value) =>
                    value == null ? 'Select your program' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                value: _selectedLevel,
                decoration: const InputDecoration(
                  labelText: 'Select level',
                  prefixIcon: Icon(Icons.layers_outlined),
                ),
                items: _levels
                    .map(
                      (level) => DropdownMenuItem(
                        value: level,
                        child: Text('Level $level'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  _selectedLevel = value;
                  _selectDefaultCourses();
                }),
                validator: (value) => value == null ? 'Select your level' : null,
              ),
              const SizedBox(height: 14),
                TextFormField(
                readOnly: true,
                controller: _dateController,
                onTap: _pickDate,
                decoration: InputDecoration(
                  labelText: 'Registration date',
                  prefixIcon: const Icon(Icons.calendar_month_outlined),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.edit_calendar_outlined),
                    onPressed: _pickDate,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                termLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: termOptions.map((term) {
                  final selected = _selectedTerm == term;
                  return ChoiceChip(
                    label: Text('${_ordinal(term)} $termLabel'),
                    selected: selected,
                    onSelected: (_) => setState(() {
                      _selectedTerm = term;
                      _selectDefaultCourses();
                    }),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<CourseData> get _availableCourses {
    final program = _selectedProgram;
    final level = _selectedLevel;
    final term = _selectedTerm;
    if (program == null || level == null || term == null) {
      return const <CourseData>[];
    }
    return program.courses
        .where((course) => course.level == level && course.semester == term)
        .toList(growable: false);
  }

  void _selectDefaultCourses() {
    _selectedCourseKeys
      ..clear()
      ..addAll(_availableCourses
          .where((course) => !course.isElective)
          .map((course) => course.code));
  }

  List<RegisteredCourse> get _selectedCourses => _availableCourses
      .where((course) => _selectedCourseKeys.contains(course.code))
      .map((course) => RegisteredCourse(
            code: course.code,
            title: course.name,
            creditHours: course.creditHours,
            isElective: course.isElective,
          ))
      .toList(growable: false);

  Widget _buildSelectedCoursesCard(String termLabel) {
    final courses = _availableCourses;
    final credits = _selectedCourses.fold<int>(
      0,
      (total, course) => total + course.creditHours,
    );
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Automatically selected courses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text('Required courses are selected from the official curriculum. You may add or remove electives before you confirm.'),
            const SizedBox(height: 12),
            if (_selectedProgram == null || _selectedLevel == null || _selectedTerm == null)
              const Text('Select a programme, level and semester to load your courses.')
            else if (courses.isEmpty)
              Text('No approved $termLabel curriculum is available for this selection yet.')
            else ...[
              ...courses.map((course) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _selectedCourseKeys.contains(course.code),
                    onChanged: (checked) => setState(() {
                      if (checked == true) {
                        _selectedCourseKeys.add(course.code);
                      } else {
                        _selectedCourseKeys.remove(course.code);
                      }
                    }),
                    title: Text('${course.code} · ${course.name}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${course.creditHours} credit hours${course.isElective ? ' · Elective' : ''}'),
                    controlAffinity: ListTileControlAffinity.leading,
                  )),
              const Divider(),
              Text('$credits total credit hours', style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      color: isDark ? RegentColors.dmCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.photo_camera_back_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Attach a picture',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Upload or take a photo of your registration form. You can change or remove it before submitting.',
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_attachmentBytes == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: RegentColors.violet.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: RegentColors.violet.withOpacity(0.25),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 42,
                      color: RegentColors.violet.withOpacity(0.8),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'No picture attached yet',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _showAttachmentOptions,
                          icon: const Icon(Icons.photo_camera),
                          label: const Text('Take / upload'),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.memory(
                      _attachmentBytes!,
                      width: double.infinity,
                      height: 220,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _attachmentName ?? 'Registration image',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _showAttachmentOptions,
                        icon: const Icon(Icons.change_circle_outlined),
                        label: const Text('Change picture'),
                      ),
                      TextButton.icon(
                        onPressed: _removeAttachment,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remove picture'),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationHistory() {
    return StreamBuilder<List<CourseRegistrationModel>>(
      stream: _service.watchMyRegistrations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final registrations = snapshot.data ?? const <CourseRegistrationModel>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your recent registrations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (registrations.isEmpty)
              const Text(
                'No course registrations have been submitted yet.',
              )
            else
              ...registrations.take(4).map(
                    (registration) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildHistoryCard(registration),
                    ),
                  ),
          ],
        );
      },
    );
  }

  Widget _buildHistoryCard(CourseRegistrationModel registration) {
    final date = MaterialLocalizations.of(context).formatMediumDate(
      registration.registrationDate,
    );
    final statusColor = registration.status == 'approved'
        ? Colors.green
        : registration.status == 'rejected'
            ? Colors.red
            : RegentColors.violet;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? RegentColors.dmCard
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: RegentColors.violet.withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  registration.programName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              Chip(
                label: Text(
                  registration.status.toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${registration.facultyName} • Level ${registration.level} • ${registration.termLabel} ${registration.term}',
          ),
          const SizedBox(height: 4),
          Text('Submitted on $date'),
          if (registration.attachmentUrl != null) ...[
            const SizedBox(height: 10),
            Text(
              'Picture attached: ${registration.attachmentName ?? 'Yes'}',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black54,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _bootstrapProfile(Map<String, dynamic> userData) {
    if (_bootstrappedProfile) return;
    _bootstrappedProfile = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final studentId = userData['studentId']?.toString().trim();
      final fullName = userData['fullName']?.toString().trim();
      final phoneNumber = (userData['phoneNumber'] ?? userData['phone'] ?? userData['telephone'])?.toString().trim();
      final level = int.tryParse(userData['level']?.toString() ?? '');
      final session = _resolveSession(userData['session']?.toString());
      final match = _resolveProfileProgram(userData);

      if (studentId != null && studentId.isNotEmpty) {
        _studentIdController.text = studentId;
      }
      if (fullName != null && fullName.isNotEmpty) {
        _fullNameController.text = fullName;
      }
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        _phoneNumberController.text = phoneNumber;
      }
      if (level != null && _levels.contains(level)) {
        _selectedLevel = level;
      } else {
        _selectedLevel ??= _levels.first;
      }
      _academicSession = session;
      _dateController.text =
          '${_selectedDate.toLocal().year.toString().padLeft(4, '0')}-${_selectedDate.toLocal().month.toString().padLeft(2, '0')}-${_selectedDate.toLocal().day.toString().padLeft(2, '0')}';
      _selectedTerm ??= _termOptionsForSession(session).first;

      if (match != null) {
        _selectedFaculty = match.faculty;
        _selectedProgram = match.program;
      }
      _selectDefaultCourses();

      setState(() {});
    });
  }

  ({FacultyData faculty, ProgramData program})? _resolveProfileProgram(
    Map<String, dynamic> userData,
  ) {
    final hints = <String?>[
      userData['program']?.toString(),
      userData['faculty']?.toString(),
    ];

    for (final faculty in universityFaculties) {
      for (final program in faculty.programs) {
        final normalizedProgram = program.name.toLowerCase();
        final normalizedFaculty = faculty.name.toLowerCase();
        final matches = hints.any((hint) {
          final normalized = hint?.trim().toLowerCase() ?? '';
          if (normalized.isEmpty) return false;
          return normalized == normalizedProgram ||
              normalized.contains(normalizedProgram) ||
              normalized.contains(normalizedFaculty) ||
              normalizedProgram.contains(normalized);
        });
        if (matches) {
          return (faculty: faculty, program: program);
        }
      }
    }
    return null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text =
            '${picked.toLocal().year.toString().padLeft(4, '0')}-${picked.toLocal().month.toString().padLeft(2, '0')}-${picked.toLocal().day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _showAttachmentOptions() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add registration picture',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take picture'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Upload from gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickImage(ImageSource.gallery);
                },
              ),
              if (_attachmentBytes != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Remove current picture'),
                  onTap: () {
                    Navigator.pop(context);
                    _removeAttachment();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      final fileName = image.name.isNotEmpty
          ? image.name
          : 'registration_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final extension = fileName.contains('.')
          ? fileName.split('.').last.toLowerCase()
          : 'jpg';
      setState(() {
        _attachmentBytes = bytes;
        _attachmentName = fileName;
        _attachmentContentType = extension == 'png'
            ? 'image/png'
            : extension == 'webp'
                ? 'image/webp'
                : 'image/jpeg';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add picture: $e')),
      );
    }
  }

  void _removeAttachment() {
    setState(() {
      _attachmentBytes = null;
      _attachmentName = null;
      _attachmentContentType = null;
    });
  }

  Future<void> _openPreviewSheet() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFaculty == null || _selectedProgram == null || _selectedLevel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your faculty, program and level.')),
      );
      return;
    }
    if (_selectedTerm == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select the semester or trimester.')),
      );
      return;
    }
    if (_selectedCourses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one course before continuing.')),
      );
      return;
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final termLabel = _termLabelForSession(_academicSession);
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Preview your registration',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Please recheck every detail before sending it to the faculty office.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 14),
                _previewRow('Student ID', _studentIdController.text.trim()),
                _previewRow('Full name', _fullNameController.text.trim()),
                _previewRow('Telephone', _phoneNumberController.text.trim()),
                _previewRow('Faculty', _selectedFaculty!.name),
                _previewRow('Program', _selectedProgram!.name),
                _previewRow('Level', 'Level ${_selectedLevel!}'),
                _previewRow(
                  'Term',
                  '${_ordinal(_selectedTerm!)} $termLabel',
                ),
                _previewRow(
                  'Date',
                  MaterialLocalizations.of(context).formatMediumDate(_selectedDate),
                ),
                _previewRow('Faculty recipient', _recipientLabel),
                const SizedBox(height: 8),
                const Text('Courses to register', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                ..._selectedCourses.map((course) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('${course.code} · ${course.title} (${course.creditHours} credits)'),
                    )),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${_selectedCourses.fold<int>(0, (total, course) => total + course.creditHours)} total credit hours',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (_attachmentBytes != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(
                      _attachmentBytes!,
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _attachmentName ?? 'Attached picture',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Submit'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      await _submitRegistration();
    }
  }

  Widget _previewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _submitRegistration() async {
    setState(() => _submitting = true);
    try {
      final termLabel = _termLabelForSession(_academicSession);
      final pdfBytes = await _buildRegistrationPdf();
      final id = await _service.submitRegistration(
        studentId: _studentIdController.text.trim(),
        fullName: _fullNameController.text.trim(),
        phoneNumber: _phoneNumberController.text.trim(),
        level: _selectedLevel!,
        term: _selectedTerm!,
        termLabel: termLabel,
        academicSession: _academicSession,
        facultyName: _selectedFaculty!.name,
        programName: _selectedProgram!.name,
        registrationDate: _selectedDate,
        academicYear: _academicYearFor(_selectedDate),
        courses: _selectedCourses,
        recipientLabel: _recipientLabel,
        registrationPdfBytes: pdfBytes,
        attachmentBytes: _attachmentBytes,
        attachmentName: _attachmentName,
        attachmentContentType: _attachmentContentType,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration sent to $_recipientLabel. Ref: $id')),
      );
      _removeAttachment();
      await _showPdfActions(pdfBytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit registration: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _ordinal(int value) {
    switch (value) {
      case 1:
        return '1st';
      case 2:
        return '2nd';
      case 3:
        return '3rd';
      default:
        return '${value}th';
    }
  }

  String get _recipientLabel {
    if (_selectedProgram == null) return 'Faculty Office';
    return 'HoD · ${_selectedProgram!.name}';
  }

  String _academicYearFor(DateTime date) => '${date.year}/${date.year + 1}';

  Future<Uint8List> _buildRegistrationPdf() => _pdfService.buildPdf(
        studentId: _studentIdController.text.trim(),
        phoneNumber: _phoneNumberController.text.trim(),
        fullName: _fullNameController.text.trim(),
        facultyName: _selectedFaculty!.name,
        programName: _selectedProgram!.name,
        level: _selectedLevel!,
        academicYear: _academicYearFor(_selectedDate),
        session: _academicSession[0].toUpperCase() + _academicSession.substring(1),
        termLabel: _termLabelForSession(_academicSession),
        term: _selectedTerm!,
        generatedAt: DateTime.now(),
        recipientLabel: _recipientLabel,
        courses: _selectedCourses,
      );

  Future<void> _showPdfActions(Uint8List bytes) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.picture_as_pdf_rounded, size: 42, color: RegentColors.violet),
              const SizedBox(height: 10),
              const Text('Registration form ready', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('Keep a copy for your records or print it for the faculty office.', textAlign: TextAlign.center),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => _pdfService.print(bytes),
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Print'),
                )),
                const SizedBox(width: 12),
                Expanded(child: FilledButton.icon(
                  onPressed: () => _pdfService.download(bytes, 'course-registration-${_studentIdController.text.trim()}.pdf'),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Download'),
                )),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
