import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/official_accounts.dart';
import '../../../core/programs_data.dart';
import '../../../core/regent_university_profile.dart';
import '../../../core/theme.dart';
import '../../../core/timetable_data.dart';
import '../../../models/academic_result_model.dart';
import '../../../models/past_question_model.dart';
import '../../../services/academic_results_service.dart';
import '../../../services/transcript_pdf_service.dart';
import '../../../services/chat_service.dart';
import '../../../services/past_questions_service.dart';
import '../../../services/status_service.dart';
import '../../chat/screens/official_account_profile_screen.dart';
import '../../ai_bot/screens/regent_ai_screen.dart';
import 'upload_past_question_screen.dart';
import 'view_past_questions_screen.dart';

String resolveAcademicSession(String? value) {
  final normalized = value?.trim().toLowerCase() ?? '';
  if (normalized.contains('weekend')) return 'weekend';
  if (normalized.contains('evening')) return 'evening';
  return 'morning';
}

String academicTermLabelForSession(String session) =>
    session == 'weekend' ? 'Trimester' : 'Semester';

List<int> academicTermOptionsForSession(String session) =>
    session == 'weekend' ? [1, 2, 3] : [1, 2];

class AcademicPastQuestionsScreen extends StatefulWidget {
  const AcademicPastQuestionsScreen({super.key});

  @override
  State<AcademicPastQuestionsScreen> createState() =>
      _AcademicPastQuestionsScreenState();
}

class _AcademicPastQuestionsScreenState extends State<AcademicPastQuestionsScreen>
    with SingleTickerProviderStateMixin {
  final _service = PastQuestionsService();
  final _chatService = ChatService();
  final _statusService = StatusService();
  final _firestore = FirebaseFirestore.instance;
  final _searchController = TextEditingController();

  FacultyData? _selectedFaculty;
  ProgramData? _selectedProgram;
  int? _selectedLevel;
  int? _selectedTerm;
  int? _selectedYear;
  String _courseQuery = '';
  String _searchQuery = '';
  bool _bootstrappedProfile = false;

  List<CourseData> get _selectedCurriculumCourses {
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

  List<CourseData> _matchingCurriculumCourses(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return _selectedCurriculumCourses;
    return _selectedCurriculumCourses
        .where((course) =>
            course.code.toLowerCase().contains(normalized) ||
            course.name.toLowerCase().contains(normalized))
        .toList(growable: false);
  }

  CourseData? get _activeCourse {
    final matches = _matchingCurriculumCourses(_courseQuery);
    return matches.length == 1 ? matches.first : null;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to open Academic Portal.')),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Past Questions'),
        centerTitle: false,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _firestore.collection('users').doc(user.uid).snapshots(),
        builder: (context, userSnapshot) {
          final userData = userSnapshot.data?.data() ?? <String, dynamic>{};
          _bootstrapProfile(userData);
          final session = _resolveSession(userData['session']?.toString());
          final termLabel = _termLabel(session);
          final termOptions = _termOptions(session);
          if (_selectedTerm != null && !termOptions.contains(_selectedTerm)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selectedTerm = null);
            });
          }

          final selectedFaculty = _selectedFaculty;
          final selectedProgram = _selectedProgram;

          final hasSelection = selectedFaculty != null &&
              selectedProgram != null &&
              _selectedLevel != null &&
              _selectedTerm != null;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(session, termLabel, userData),
                const SizedBox(height: 16),
                _buildSelectionCard(
                  termLabel: termLabel,
                  termOptions: termOptions,
                ),
                const SizedBox(height: 16),
                _buildActionsCard(hasSelection, termLabel),
                const SizedBox(height: 16),
                if (hasSelection)
                  StreamBuilder<List<PastQuestionModel>>(
                    stream: _service.watchPastQuestions(
                      facultyName: selectedFaculty!.name,
                      programName: selectedProgram!.name,
                      level: _selectedLevel,
                      semester: _selectedTerm,
                      year: _selectedYear,
                      query: _searchQuery,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final questions = snapshot.data ?? const [];
                      final matchingCourses =
                          _matchingCurriculumCourses(_searchQuery);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSelectionSummary(
                            facultyName: selectedFaculty!.name,
                            programName: selectedProgram!.name,
                            level: _selectedLevel!,
                            termLabel: termLabel,
                            termValue: _selectedTerm!,
                            year: _selectedYear,
                            sessionLabel: session,
                          ),
                          const SizedBox(height: 16),
                          _buildQuestionSearchCard(matchingCourses),
                          const SizedBox(height: 16),
                          if (matchingCourses.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'Related course titles',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                          if (matchingCourses.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: matchingCourses
                                  .take(16)
                                  .map(
                                    (course) => ChoiceChip(
                                      label: Text('${course.code} · ${course.name}'),
                                      selected:
                                          _courseQuery.trim().toLowerCase() ==
                                              course.name.toLowerCase(),
                                      onSelected: (_) {
                                        setState(() {
                                          _courseQuery = course.name;
                                          _searchQuery = course.name;
                                          _searchController.text = course.name;
                                        });
                                      },
                                    ),
                                  )
                                  .toList(),
                            ),
                          const SizedBox(height: 16),
                          _buildQuestionList(
                            context,
                            questions,
                            termLabel,
                            selectedFaculty!.name,
                            selectedProgram!.name,
                            _selectedLevel!,
                            _selectedTerm!,
                          ),
                        ],
                      );
                    },
                  )
                else
                  _buildPrompt(),
              ],
            ),
          );
        },
      ),
    );
  }

  void _bootstrapProfile(Map<String, dynamic> userData) {
    if (_bootstrappedProfile) return;
    _bootstrappedProfile = true;

    final programHint = [
      userData['program'],
      userData['department'],
      userData['faculty'],
    ].whereType<Object>().map((value) => value.toString()).toList();
    final level = int.tryParse(userData['level']?.toString() ?? '');

    FacultyData? matchedFaculty;
    ProgramData? matchedProgram;

    for (final faculty in universityFaculties) {
      for (final program in faculty.programs) {
        final programName = program.name.toLowerCase();
        final facultyName = faculty.name.toLowerCase();
        final matches = programHint.any((hint) {
          final normalized = hint.toLowerCase();
          return normalized == programName ||
              normalized.contains(programName) ||
              normalized.contains(facultyName) ||
              programName.contains(normalized);
        });
        if (matches) {
          matchedFaculty = faculty;
          matchedProgram = program;
          break;
        }
      }
      if (matchedFaculty != null) break;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _selectedFaculty = matchedFaculty ?? _selectedFaculty;
        _selectedProgram = matchedProgram ?? _selectedProgram;
        _selectedLevel = level ?? _selectedLevel;
      });
    });
  }

  String _resolveSession(String? value) {
    final normalized = value?.trim().toLowerCase() ?? '';
    if (normalized.contains('weekend')) return 'weekend';
    if (normalized.contains('evening')) return 'evening';
    return 'morning';
  }

  String _termLabel(String session) => session == 'weekend' ? 'Trimester' : 'Semester';

  List<int> _termOptions(String session) => session == 'weekend' ? [1, 2, 3] : [1, 2];

  Widget _buildHeader(
    String session,
    String termLabel,
    Map<String, dynamic> userData,
  ) {
    final program = _selectedProgram?.name ?? userData['program']?.toString();
    final level = _selectedLevel == null ? 'Any level' : 'Level $_selectedLevel';
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
          Row(
            children: [
              const Icon(Icons.menu_book_rounded, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Past Questions Hub',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Search, view, download and upload questions by course, level and term.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.88),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _headerChip(session == 'weekend' ? 'Weekend stream' : 'Regular stream'),
              _headerChip(termLabel),
              _headerChip(program == null ? 'Program not set' : program),
              _headerChip(level),
            ],
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
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildSelectionCard({
    required String termLabel,
    required List<int> termOptions,
  }) {
    final selectedFaculty = _selectedFaculty;
    final selectedProgram = _selectedProgram;
    final programOptions = selectedFaculty?.programs ?? const <ProgramData>[];
    final yearOptions = List<int>.generate(12, (index) => DateTime.now().year - index);

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: RegentColors.violet.withOpacity(0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.filter_alt_rounded, color: RegentColors.violet),
                const SizedBox(width: 10),
                Text(
                  'Find your question',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<FacultyData>(
              value: selectedFaculty,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Select faculty',
                prefixIcon: Icon(Icons.account_balance_rounded),
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
                  _selectedLevel = null;
                  _selectedTerm = null;
                  _selectedYear = null;
                  _courseQuery = '';
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ProgramData>(
              value: selectedProgram,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Select program',
                prefixIcon: Icon(Icons.school_rounded),
              ),
              items: programOptions
                  .map(
                    (program) => DropdownMenuItem(
                      value: program,
                      child: Text(program.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: selectedFaculty == null
                  ? null
                  : (value) {
                      setState(() {
                        _selectedProgram = value;
                        _selectedLevel = null;
                        _selectedTerm = null;
                        _selectedYear = null;
                        _courseQuery = '';
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _selectedLevel,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Select level',
                prefixIcon: Icon(Icons.stairs_rounded),
              ),
              items: const [100, 200, 300, 400]
                  .map(
                    (level) => DropdownMenuItem(
                      value: level,
                      child: Text('Level $level'),
                    ),
                  )
                  .toList(),
              onChanged: selectedProgram == null
                  ? null
                  : (value) {
                      setState(() {
                        _selectedLevel = value;
                        _selectedTerm = null;
                        _selectedYear = null;
                        _courseQuery = '';
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _selectedTerm,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Select $termLabel',
                prefixIcon: const Icon(Icons.calendar_month_rounded),
              ),
              items: termOptions
                  .map(
                    (term) => DropdownMenuItem(
                      value: term,
                      child: Text('$termLabel $term'),
                    ),
                  )
                  .toList(),
              onChanged: _selectedLevel == null
                  ? null
                  : (value) => setState(() => _selectedTerm = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              value: _selectedYear,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Year (optional)',
                prefixIcon: Icon(Icons.event_rounded),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('All years'),
                ),
                ...yearOptions.map(
                  (year) => DropdownMenuItem<int?>(
                    value: year,
                    child: Text('$year'),
                  ),
                ),
              ],
              onChanged: _selectedTerm == null
                  ? null
                  : (value) => setState(() => _selectedYear = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Course title search',
                hintText: 'Type a course title or code',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                            _courseQuery = '';
                          });
                        },
                        icon: const Icon(Icons.clear_rounded),
                      ),
                    IconButton(
                      tooltip: 'Search courses',
                      onPressed: () => setState(() {
                        _searchQuery = _searchController.text.trim();
                        _courseQuery = _searchQuery;
                      }),
                      icon: const Icon(Icons.search_rounded),
                    ),
                  ],
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _courseQuery = value;
                });
              },
              onSubmitted: (value) => setState(() {
                _searchQuery = value.trim();
                _courseQuery = _searchQuery;
              }),
            ),
            const SizedBox(height: 10),
            Text(
              'Search will surface the matching title first, then the related past questions underneath.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard(bool hasSelection, String termLabel) {
    final faculty = _selectedFaculty;
    final program = _selectedProgram;
    final level = _selectedLevel;
    final term = _selectedTerm;

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: RegentColors.violet.withOpacity(0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actions',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _actionButton(
                  icon: Icons.upload_file_rounded,
                  label: 'Upload',
                  color: RegentColors.green,
                  onPressed: hasSelection
                      ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UploadPastQuestionScreen(
                                facultyName: faculty!.name,
                                programName: program!.name,
                                option: null,
                                level: level!,
                                semester: term!,
                                termLabel: termLabel,
                                initialCourseCode: _activeCourse?.code,
                                initialCourseName: _activeCourse?.name ??
                                    (_courseQuery.trim().isEmpty
                                        ? null
                                        : _courseQuery.trim()),
                              ),
                            ),
                          )
                      : null,
                ),
                _actionButton(
                  icon: Icons.visibility_rounded,
                  label: 'View',
                  color: RegentColors.violet,
                  onPressed: hasSelection
                      ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ViewPastQuestionsScreen(
                                facultyName: faculty!.name,
                                programName: program!.name,
                                option: null,
                                level: level!,
                                semester: term!,
                                termLabel: termLabel,
                                courseTitleQuery: _courseQuery.trim().isEmpty
                                    ? null
                                    : _courseQuery.trim(),
                              ),
                            ),
                          )
                      : null,
                ),
                _actionButton(
                  icon: Icons.download_rounded,
                  label: 'Download',
                  color: Colors.blue,
                  onPressed: hasSelection
                      ? () => _downloadFirstMatchingQuestion(
                            facultyName: faculty!.name,
                            programName: program!.name,
                            level: level!,
                            term: term!,
                          )
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 110,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        label: Text(label),
      ),
    );
  }

  Widget _buildSelectionSummary({
    required String facultyName,
    required String programName,
    required int level,
    required String termLabel,
    required int termValue,
    required int? year,
    required String sessionLabel,
  }) {
    return Card(
      elevation: 0,
      color: RegentColors.violet.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: RegentColors.violet.withOpacity(0.14)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded,
                    color: RegentColors.violet),
                const SizedBox(width: 8),
                Text(
                  'Selection summary',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _summaryRow('Faculty', facultyName),
            _summaryRow('Program', programName),
            _summaryRow('Level', 'Level $level'),
            _summaryRow(termLabel, '$termLabel $termValue'),
            _summaryRow('Session', sessionLabel),
            _summaryRow('Year', year == null ? 'All years' : '$year'),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(height: 1.35)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionSearchCard(List<CourseData> courses) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.search_rounded, color: RegentColors.violet),
                const SizedBox(width: 8),
                Text(
                  'Search results by title',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              courses.isEmpty
                  ? 'No course in this curriculum matches that keyword.'
                  : 'These official courses match your selection. Tap one to filter its uploaded papers.',
              style: TextStyle(color: Colors.grey.shade700, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionList(
    BuildContext context,
    List<PastQuestionModel> questions,
    String termLabel,
    String facultyName,
    String programName,
    int level,
    int term,
  ) {
    if (questions.isEmpty) {
      return Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.folder_open_rounded,
                  size: 56, color: RegentColors.violet),
              const SizedBox(height: 12),
              const Text(
                'No past questions match this filter yet',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Try a different course title, year, or upload the first paper for this course.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, height: 1.35),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Matching past questions',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        ...questions.map(
          (question) => _PastQuestionResultCard(
            question: question,
            onView: () => launchUrl(
              Uri.parse(question.fileUrl),
              mode: LaunchMode.inAppWebView,
            ),
            onDownload: () async {
              await launchUrl(
                Uri.parse(question.fileUrl),
                mode: LaunchMode.externalApplication,
              );
              await _service.incrementDownloadCount(question.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Download opened')),
                );
              }
            },
            onStudyWithAi: () => _openRegentAi(question),
            onShare: () => _shareQuestion(question),
          ),
        ),
      ],
    );
  }

  Future<void> _downloadFirstMatchingQuestion({
    required String facultyName,
    required String programName,
    required int level,
    required int term,
  }) async {
    final questions = await _service
        .watchPastQuestions(
          facultyName: facultyName,
          programName: programName,
          level: level,
          semester: term,
          year: _selectedYear,
          query: _searchQuery,
        )
        .first;
    if (questions.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No matching past question is ready to download.')),
        );
      }
      return;
    }
    final question = questions.first;
    await launchUrl(Uri.parse(question.fileUrl), mode: LaunchMode.externalApplication);
    await _service.incrementDownloadCount(question.id);
  }

  void _openRegentAi(PastQuestionModel question) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegentAIScreen(
          initialPrompt:
              'Help me solve and study this Regent past question. Course: ${question.courseCode} ${question.courseName}. Exam year: ${question.year}. File: ${question.fileUrl}\n\nFirst, ask me which question number or topic I want to work through. Then explain the solution step by step.',
        ),
      ),
    );
  }

  Future<void> _shareQuestion(PastQuestionModel question) async {
    final destination = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Share past question', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ListTile(
                leading: const Icon(Icons.person_add_alt_1_rounded),
                title: const Text('Share with a student or another app'),
                subtitle: const Text('Choose a person, app, or copy the link.'),
                onTap: () => Navigator.pop(context, 'external'),
              ),
              ListTile(
                leading: const Icon(Icons.groups_rounded),
                title: const Text('Send to a group or channel'),
                subtitle: const Text('Post the paper link to one of your communities.'),
                onTap: () => Navigator.pop(context, 'group'),
              ),
              ListTile(
                leading: const Icon(Icons.history_toggle_off_rounded),
                title: const Text('Post to status'),
                subtitle: const Text('Share a 24-hour study link with your contacts.'),
                onTap: () => Navigator.pop(context, 'status'),
              ),
            ],
          ),
        ),
      ),
    );
    if (destination == null) return;
    final message = _shareTextFor(question);
    if (destination == 'external') {
      await Share.share(message, subject: '${question.courseName} past question');
    } else if (destination == 'status') {
      await _statusService.postStatus(type: 'text', text: message);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Past question shared to your status.')),
        );
      }
    } else if (destination == 'group') {
      await _shareQuestionToGroup(question, message);
    }
  }

  String _shareTextFor(PastQuestionModel question) =>
      'Regent past question: ${question.courseCode} ${question.courseName} (${question.year}).\n${question.fileUrl}';

  Future<void> _shareQuestionToGroup(
    PastQuestionModel question,
    String message,
  ) async {
    final groupId = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: _chatService.getMyGroups(),
          builder: (context, snapshot) {
            final groups = snapshot.data?.docs ?? const [];
            return ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              children: [
                const Text('Send to a group or channel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (groups.isEmpty)
                  const ListTile(title: Text('You have not joined any groups yet.')),
                ...groups.map((group) => ListTile(
                      leading: const Icon(Icons.groups_rounded),
                      title: Text(group.data() is Map<String, dynamic>
                          ? ((group.data() as Map<String, dynamic>)['name']?.toString() ?? 'Community')
                          : 'Community'),
                      onTap: () => Navigator.pop(context, group.id),
                    )),
              ],
            );
          },
        ),
      ),
    );
    if (groupId == null) return;
    await _chatService.sendGroupMessage(
      groupId: groupId,
      message: message,
      metadata: {'pastQuestionId': question.id, 'pastQuestionUrl': question.fileUrl},
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Past question shared with the group.')),
      );
    }
  }

  Widget _buildPrompt() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.tune_rounded, size: 56, color: RegentColors.violet),
            const SizedBox(height: 12),
            const Text(
              'Select faculty, program, level and term to unlock past questions',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Once your academic context is set, you can upload, view and download the matching papers immediately.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _PastQuestionResultCard extends StatelessWidget {
  const _PastQuestionResultCard({
    required this.question,
    required this.onView,
    required this.onDownload,
    required this.onStudyWithAi,
    required this.onShare,
  });

  final PastQuestionModel question;
  final VoidCallback onView;
  final VoidCallback onDownload;
  final VoidCallback onStudyWithAi;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: RegentColors.violet.withOpacity(0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: RegentColors.violet.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.description_rounded,
                      color: RegentColors.violet),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        question.courseName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${question.courseCode.isEmpty ? 'No course code' : question.courseCode} • ${question.year}',
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'view') onView();
                    if (value == 'download') onDownload();
                    if (value == 'ai') onStudyWithAi();
                    if (value == 'share') onShare();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_rounded),
                          SizedBox(width: 8),
                          Text('View'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'download',
                      child: Row(
                        children: [
                          Icon(Icons.download_rounded),
                          SizedBox(width: 8),
                          Text('Download'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'ai',
                      child: Row(
                        children: [
                          Icon(Icons.auto_awesome_rounded),
                          SizedBox(width: 8),
                          Text('Study with RegentAI'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.ios_share_rounded),
                          SizedBox(width: 8),
                          Text('Share'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _tag(question.facultyName),
                _tag(question.programName),
                _tag('Level ${question.level}'),
                _tag('Term ${question.semester}'),
                _tag(question.fileType.toUpperCase()),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Uploaded by ${question.uploaderName}',
              style: TextStyle(color: isDark ? Colors.white60 : Colors.grey),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onView,
                  icon: const Icon(Icons.visibility_rounded),
                  label: const Text('View'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onDownload,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Download'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Study with RegentAI',
                  onPressed: onStudyWithAi,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  color: RegentColors.violet,
                ),
                IconButton(
                  tooltip: 'Share',
                  onPressed: onShare,
                  icon: const Icon(Icons.ios_share_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: RegentColors.violet.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: RegentColors.violet,
        ),
      ),
    );
  }
}

enum _CalendarTrack {
  continuing,
  octoberBatch,
  februaryBatch,
  weekendSchool,
  crush,
}

class AcademicCalendarScreen extends StatefulWidget {
  const AcademicCalendarScreen({super.key});

  @override
  State<AcademicCalendarScreen> createState() => _AcademicCalendarScreenState();
}

class _AcademicCalendarScreenState extends State<AcademicCalendarScreen> {
  _CalendarTrack _selectedTrack = _CalendarTrack.continuing;

  @override
  Widget build(BuildContext context) {
    final track = _calendarTrackDetails[_selectedTrack]!;
    final events = _academicTimelineEvents(_selectedTrack);

    return Scaffold(
      appBar: AppBar(title: const Text('Academic Calendar')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _banner(
            context,
            title: 'Stay on top of the academic year',
            subtitle:
                'A visual calendar for registrations, lectures, assessments and result release.',
            icon: Icons.calendar_month_rounded,
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Choose your academic calendar',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<_CalendarTrack>(
                    value: _selectedTrack,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Calendar track',
                      prefixIcon: Icon(Icons.event_available_rounded),
                    ),
                    items: _calendarTrackDetails.entries
                        .map((entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value.title),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _selectedTrack = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${track.period} - ${track.subtitle}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            color: RegentColors.violet.withOpacity(0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: RegentColors.violet.withOpacity(0.16)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.schedule_rounded, color: RegentColors.violet),
                      SizedBox(width: 10),
                      Text('Published teaching timetable',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select your faculty, programme and level to see the published classes that match your registered courses.',
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AcademicTimetableScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.visibility_rounded),
                    label: const Text('View my timetable'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...events.map(
            (event) => _TimelineCard(
              title: event.title,
              subtitle: event.subtitle,
              dateRange: event.dateRange,
              icon: event.icon,
              accent: event.accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Compiled from the official 2026/2027 academic calendars supplied by Regent University. Dates are shown for planning and remain subject to official notices.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class AcademicTimetableScreen extends StatefulWidget {
  const AcademicTimetableScreen({super.key});

  @override
  State<AcademicTimetableScreen> createState() => _AcademicTimetableScreenState();
}

class _AcademicTimetableScreenState extends State<AcademicTimetableScreen> {
  FacultyData? _faculty;
  ProgramData? _program;
  int? _level;
  bool _profileLoaded = false;

  List<TimetableEntry> get _entries {
    if (_program == null || _level == null) return const <TimetableEntry>[];
    return timetableForSelection(program: _program!, level: _level!, semester: 1);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please sign in to view your timetable.')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('My Teaching Timetable')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          _loadProfile(snapshot.data?.data() ?? const <String, dynamic>{});
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _banner(
                context,
                title: '2026/2027 First Semester',
                subtitle: 'Published teaching timetable. Teaching: 24 August–27 November 2026; examinations: 7–18 December 2026.',
                icon: Icons.schedule_rounded,
              ),
              const SizedBox(height: 16),
              _buildTimetableFilters(),
              const SizedBox(height: 16),
              _buildSchedule(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimetableFilters() {
    final programs = _faculty?.programs ?? const <ProgramData>[];
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<FacultyData>(
              value: _faculty,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Faculty', prefixIcon: Icon(Icons.account_balance_rounded)),
              items: universityFaculties.map((faculty) => DropdownMenuItem(value: faculty, child: Text(faculty.name, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (value) => setState(() {
                _faculty = value;
                _program = null;
                _level = null;
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ProgramData>(
              value: _program,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Programme', prefixIcon: Icon(Icons.school_rounded)),
              items: programs.map((program) => DropdownMenuItem(value: program, child: Text(program.name, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: _faculty == null ? null : (value) => setState(() {
                    _program = value;
                    _level = null;
                  }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _level,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Level', prefixIcon: Icon(Icons.stairs_rounded)),
              items: const [100, 200, 300, 400].map((level) => DropdownMenuItem(value: level, child: Text('Level $level'))).toList(),
              onChanged: _program == null ? null : (value) => setState(() => _level = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchedule() {
    if (_program == null || _level == null) {
      return const _EmptyStateCard(
        icon: Icons.tune_rounded,
        title: 'Choose your academic details',
        subtitle: 'Select your faculty, programme and level to view matching first-semester classes.',
      );
    }
    final entries = _entries;
    final publishedCourses = _program!.courses.where((course) => course.level == _level && course.semester == 1).length;
    if (entries.isEmpty) {
      return _EmptyStateCard(
        icon: Icons.event_busy_rounded,
        title: 'No published class slots matched yet',
        subtitle: '$publishedCourses first-semester course(s) are in the curriculum, but this timetable source has no matching class slot for the selected programme. Check with your department for revisions.',
      );
    }
    final grouped = <String, List<TimetableEntry>>{};
    for (final entry in entries) {
      grouped.putIfAbsent(entry.day, () => <TimetableEntry>[]).add(entry);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Your scheduled classes', '${entries.length} published class slot(s) matched to ${_program!.name}.'),
        const SizedBox(height: 12),
        ...grouped.entries.map((day) => Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: ExpansionTile(
                initiallyExpanded: day.key == 'Monday',
                leading: const Icon(Icons.calendar_today_rounded, color: RegentColors.violet),
                title: Text(day.key, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${day.value.length} class slot(s)'),
                children: day.value.map((entry) => ListTile(
                      leading: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(color: RegentColors.violet.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: Text(entry.time, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: RegentColors.violet)),
                      ),
                      title: Text(entry.courseCode, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(
                        _cleanTimetableText(entry.details),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )).toList(),
              ),
            )),
      ],
    );
  }

  void _loadProfile(Map<String, dynamic> data) {
    if (_profileLoaded) return;
    _profileLoaded = true;
    final hints = [data['program'], data['faculty'], data['department']]
        .whereType<Object>()
        .map((value) => value.toString().toLowerCase())
        .toList();
    final profileLevel = int.tryParse(data['level']?.toString() ?? '');
    for (final faculty in universityFaculties) {
      for (final program in faculty.programs) {
        if (hints.any((hint) => hint.contains(program.name.toLowerCase()) || program.name.toLowerCase().contains(hint))) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() {
              _faculty = faculty;
              _program = program;
              _level = profileLevel;
            });
          });
          return;
        }
      }
    }
  }

  String _cleanTimetableText(String text) => text
      .replaceAll('â€“', '–')
      .replaceAll('â€¦', '…');
}

class AcademicCourseInfoScreen extends StatefulWidget {
  const AcademicCourseInfoScreen({super.key});

  @override
  State<AcademicCourseInfoScreen> createState() =>
      _AcademicCourseInfoScreenState();
}

class _AcademicCourseInfoScreenState extends State<AcademicCourseInfoScreen> {
  final _service = PastQuestionsService();
  final _searchController = TextEditingController();
  FacultyData? _faculty;
  ProgramData? _program;
  int? _level;
  int _semester = 1;
  String _search = '';

  List<CourseData> get _selectedCourses {
    final program = _program;
    final level = _level;
    if (program == null || level == null) return const <CourseData>[];
    return program.courses
        .where((course) => course.level == level && course.semester == _semester)
        .toList(growable: false);
  }

  List<CourseData> get _matchingCourses {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return _selectedCourses;
    return _selectedCourses
        .where((course) =>
            course.code.toLowerCase().contains(query) ||
            course.name.toLowerCase().contains(query))
        .toList(growable: false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to open Course Info.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Course Info')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          final userData = userSnapshot.data?.data() ?? <String, dynamic>{};
          final session = resolveAcademicSession(userData['session']?.toString());
          final termLabel = academicTermLabelForSession(session);
          final termOptions = academicTermOptionsForSession(session);
          _bootstrapCourseInfoProfile(userData);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _banner(
                context,
                title: 'Find the course titles attached to your programme',
                subtitle:
                    'Browse by faculty, program and level, then search through the titles that already exist in the academic portal.',
                icon: Icons.library_books_rounded,
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<FacultyData>(
                        value: _faculty,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Faculty',
                          prefixIcon: Icon(Icons.account_balance_rounded),
                        ),
                        items: universityFaculties
                            .map(
                              (faculty) => DropdownMenuItem(
                                value: faculty,
                                child: Text(
                                  faculty.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() {
                          _faculty = value;
                          _program = null;
                          _level = null;
                          _semester = 1;
                          _search = '';
                          _searchController.clear();
                        }),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<ProgramData>(
                        value: _program,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Program',
                          prefixIcon: Icon(Icons.school_rounded),
                        ),
                        items: (_faculty?.programs ?? const <ProgramData>[])
                            .map(
                              (program) => DropdownMenuItem(
                                value: program,
                                child: Text(
                                  program.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _faculty == null
                            ? null
                            : (value) => setState(() {
                                  _program = value;
                                  _level = null;
                                  _semester = 1;
                                  _search = '';
                                  _searchController.clear();
                                }),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: _level,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Level',
                          prefixIcon: Icon(Icons.stairs_rounded),
                        ),
                        items: const [100, 200, 300, 400]
                            .map(
                              (level) => DropdownMenuItem(
                                value: level,
                                child: Text('Level $level'),
                              ),
                            )
                            .toList(),
                        onChanged: _program == null
                            ? null
                            : (value) => setState(() => _level = value),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<int>(
                        segments: termOptions
                            .map(
                              (term) => ButtonSegment(
                                value: term,
                                label: Text('$termLabel $term'),
                              ),
                            )
                            .toList(),
                        selected: {_semester},
                        onSelectionChanged: (value) {
                          setState(() => _semester = value.first);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'Search course title or code',
                          hintText: 'For example: programming, SICS 1573',
                          prefixIcon: Icon(Icons.search_rounded),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_searchController.text.isNotEmpty)
                                IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () => setState(() {
                                    _searchController.clear();
                                    _search = '';
                                  }),
                                  icon: const Icon(Icons.clear_rounded),
                                ),
                              IconButton(
                                tooltip: 'Search courses',
                                onPressed: () => setState(() {
                                  _search = _searchController.text.trim();
                                }),
                                icon: const Icon(Icons.search_rounded),
                              ),
                            ],
                          ),
                        ),
                        onChanged: (value) => setState(() => _search = value),
                        onSubmitted: (value) => setState(() => _search = value.trim()),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_faculty != null && _program != null && _level != null)
                StreamBuilder<List<PastQuestionModel>>(
                  stream: _service.watchPastQuestions(
                    facultyName: _faculty!.name,
                    programName: _program!.name,
                    level: _level,
                    semester: _semester,
                    query: _search,
                  ),
                  builder: (context, snapshot) {
                    final questions = snapshot.data ?? const [];
                    final courses = _matchingCourses;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionHeader(
                          'Available titles',
                          'Courses are drawn from the official programme curriculum for your selected level and term.',
                        ),
                        const SizedBox(height: 10),
                        if (courses.isEmpty)
                          _EmptyStateCard(
                            icon: Icons.search_off_rounded,
                            title: _search.trim().isEmpty
                                ? 'No curriculum has been added for this selection'
                                : 'No related course found',
                            subtitle: _search.trim().isEmpty
                                ? 'Choose another level or term, or ask your department to publish the missing curriculum.'
                                : 'Try part of the course code or title, such as “programming” or “SICS”.',
                          )
                        else
                          ...courses.map(
                            (course) => Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: const Icon(Icons.menu_book_rounded,
                                    color: RegentColors.violet),
                                title: Text(course.name,
                                    style: const TextStyle(fontWeight: FontWeight.w800)),
                                subtitle: Text('${course.code} · ${course.creditHours} credit hours${course.isElective ? ' · Elective' : ''}'),
                                trailing: FilledButton.tonalIcon(
                                  onPressed: () => _openCourseQuestions(course),
                                  icon: const Icon(Icons.visibility_rounded),
                                  label: const Text('Questions'),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        _sectionHeader(
                          'Quick actions',
                          'Open a filtered past-question view from the selected course.',
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: courses.isEmpty
                                    ? null
                                    : () => _openCourseQuestions(
                                          courses.length == 1
                                              ? courses.first
                                              : null,
                                        ),
                                icon: const Icon(Icons.visibility_rounded),
                                label: Text(courses.length == 1
                                    ? 'Open questions'
                                    : 'Open matching questions'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _sectionHeader(
                          'Program snapshot',
                          'Helpful at-a-glance information for students and class reps.',
                        ),
                        const SizedBox(height: 10),
                        _ProgramSnapshotCard(
                          faculty: _faculty!.name,
                          program: _program!.name,
                          level: _level!,
                          courseCount: courses.length,
                          questionCount: questions.length,
                        ),
                      ],
                    );
                  },
                )
              else
                const _EmptyStateCard(
                  icon: Icons.tips_and_updates_rounded,
                  title: 'Select a faculty, program and level',
                  subtitle:
                      'The course info panel becomes more useful once the academic context is chosen.',
                ),
            ],
          );
        },
      ),
    );
  }

  void _bootstrapCourseInfoProfile(Map<String, dynamic> userData) {
    if (_faculty != null || _program != null || _level != null) return;

    final level = int.tryParse(userData['level']?.toString() ?? '');
    final hints = [
      userData['program'],
      userData['department'],
      userData['faculty'],
    ].whereType<Object>().map((value) => value.toString()).toList();

    for (final faculty in universityFaculties) {
      for (final program in faculty.programs) {
        final lowerProgram = program.name.toLowerCase();
        final lowerFaculty = faculty.name.toLowerCase();
        final matched = hints.any(
          (hint) {
            final normalized = hint.toLowerCase();
            return normalized == lowerProgram ||
                normalized.contains(lowerProgram) ||
                normalized.contains(lowerFaculty);
          },
        );
        if (matched) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _faculty = faculty;
              _program = program;
              _level = level;
            });
          });
          return;
        }
      }
    }

    if (level != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _level == null) setState(() => _level = level);
      });
    }
  }

  void _openCourseQuestions(CourseData? course) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewPastQuestionsScreen(
          facultyName: _faculty!.name,
          programName: _program!.name,
          option: null,
          level: _level!,
          semester: _semester,
          termLabel: 'Semester',
          courseTitleQuery: course?.name ??
              (_search.trim().isEmpty ? null : _search.trim()),
        ),
      ),
    );
  }
}

class AcademicResultsScreen extends StatefulWidget {
  const AcademicResultsScreen({super.key});

  @override
  State<AcademicResultsScreen> createState() => _AcademicResultsScreenState();
}

enum _TranscriptScope { selectedCourse, selectedSemester, fullRecord }

class _AcademicResultsScreenState extends State<AcademicResultsScreen> {
  final _service = AcademicResultsService();
  final _searchController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _transcriptPdfService = TranscriptPdfService();
  int? _selectedLevel;
  int? _selectedTerm;
  String? _selectedCourseCode;
  _TranscriptScope _transcriptScope = _TranscriptScope.selectedSemester;
  bool _bootstrapped = false;
  bool _identityVerified = false;
  String? _accessError;
  bool _generatingTranscript = false;

  @override
  void dispose() {
    _searchController.dispose();
    _studentIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view your results.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Results & Grades')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          final userData = userSnapshot.data?.data() ?? <String, dynamic>{};
          _bootstrapResults(userData);
          final session = resolveAcademicSession(userData['session']?.toString());
          final termLabel = academicTermLabelForSession(session);
          final termOptions = academicTermOptionsForSession(session);
          final currentLevel =
              int.tryParse(userData['level']?.toString() ?? '') ?? 100;
          final levels = [100, 200, 300, 400]
              .where((level) => level <= currentLevel)
              .toList();

          if (_selectedTerm != null && !termOptions.contains(_selectedTerm)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selectedTerm = null);
            });
          }

          if (!_identityVerified) {
            return _buildTranscriptAccessGate(userData);
          }

          return StreamBuilder<List<AcademicResultModel>>(
            stream: _service.watchStudentResults(studentId: currentUser.uid),
            builder: (context, snapshot) {
              final allResults = snapshot.data ?? const [];
              final selectedLevel = _selectedLevel ?? currentLevel;
              final selectedTerm = _selectedTerm ?? 1;
              final selectedResults = _service.filterResults(
                results: allResults,
                level: selectedLevel,
                semester: selectedTerm,
                query: _searchController.text,
              );
              final levelResults = allResults
                  .where((result) => levels.contains(result.level))
                  .toList();
              final cgpa = _service.calculateGpa(levelResults);
              final publishedResultNames = allResults
                  .map((result) => result.studentName?.trim() ?? '')
                  .where((name) => name.isNotEmpty)
                  .toList();
              final transcriptNameMatches = allResults.isEmpty ||
                  (publishedResultNames.isNotEmpty &&
                      publishedResultNames.every(
                        (name) =>
                            _normalizedName(name) ==
                            _normalizedName(
                              userData['fullName']?.toString() ?? '',
                            ),
                      ));
              if (!transcriptNameMatches) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _banner(
                      context,
                      title: 'Results access is protected',
                      subtitle:
                          'Your verified profile does not match the published student record.',
                      icon: Icons.security_rounded,
                    ),
                    const SizedBox(height: 16),
                    const _EmptyStateCard(
                      icon: Icons.lock_rounded,
                      title: 'Academic Unit review required',
                      subtitle:
                          'Results and transcripts stay unavailable until your student ID and full name are confirmed against the published record.',
                    ),
                  ],
                );
              }
              final courseOptions = allResults
                  .where((result) =>
                      result.level == selectedLevel &&
                      result.semester == selectedTerm)
                  .map((result) => result.courseCode)
                  .where((value) => value.trim().isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();
              final courseFilteredResults = _selectedCourseCode == null
                  ? selectedResults
                  : selectedResults
                      .where((result) => result.courseCode == _selectedCourseCode)
                      .toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _banner(
                    context,
                    title: 'Results & secure transcript',
                    subtitle:
                        'Your identity is verified. Review published grades, then print or download your provisional transcript.',
                    icon: Icons.grade_rounded,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.insights_rounded,
                                  color: RegentColors.violet),
                              const SizedBox(width: 8),
                              Text(
                                'Result filters',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: levels
                                .map(
                                  (level) => ChoiceChip(
                                    label: Text('Level $level'),
                                    selected: _selectedLevel == level ||
                                        (_selectedLevel == null &&
                                            level == currentLevel),
                                    onSelected: (_) =>
                                        setState(() => _selectedLevel = level),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 12),
                          SegmentedButton<int>(
                            segments: termOptions
                                .map(
                                  (term) => ButtonSegment(
                                    value: term,
                                    label: Text('$termLabel $term'),
                                  ),
                                )
                                .toList(),
                            selected: {_selectedTerm ?? 1},
                            onSelectionChanged: (value) {
                              setState(() => _selectedTerm = value.first);
                            },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              labelText: 'Search results',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _searchController.text.isEmpty
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.clear_rounded),
                                      onPressed: () {
                                        setState(() => _searchController.clear());
                                      },
                                    ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String?>(
                            value: _selectedCourseCode,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Course (optional)',
                              prefixIcon: Icon(Icons.menu_book_rounded),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All courses'),
                              ),
                          ...courseOptions.map(
                            (code) => DropdownMenuItem<String?>(
                              value: code,
                              child: Text(code),
                            ),
                          ),
                        ],
                            onChanged: (value) {
                              setState(() {
                                _selectedCourseCode = value;
                                if (value == null &&
                                    _transcriptScope ==
                                        _TranscriptScope.selectedCourse) {
                                  _transcriptScope =
                                      _TranscriptScope.selectedSemester;
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ResultsSummaryRow(
                    cgpa: cgpa,
                    submittedCount: allResults.length,
                    selectedLevel: selectedLevel,
                    selectedTerm: selectedTerm,
                    termLabel: termLabel,
                  ),
                  const SizedBox(height: 16),
                  _buildTranscriptCard(
                    userData: userData,
                    currentLevel: currentLevel,
                    selectedLevel: selectedLevel,
                    selectedTerm: selectedTerm,
                    termLabel: termLabel,
                    selectedCourseResults: _selectedCourseCode == null
                        ? const []
                        : allResults
                            .where(
                              (result) =>
                                  result.level == selectedLevel &&
                                  result.semester == selectedTerm &&
                                  result.courseCode == _selectedCourseCode,
                            )
                            .toList(),
                    semesterResults: _service.filterResults(
                      results: allResults,
                      level: selectedLevel,
                      semester: selectedTerm,
                    ),
                    fullResults: levelResults,
                  ),
                  const SizedBox(height: 16),
                  _sectionHeader(
                    'Selected term results',
                    'Everything submitted for the chosen level and term appears here.',
                  ),
                  const SizedBox(height: 10),
                  if (courseFilteredResults.isEmpty)
                    const _EmptyStateCard(
                      icon: Icons.pending_actions_rounded,
                      title: 'Awaiting academic board submission',
                      subtitle:
                          'No results have been published for the selected level and term yet.',
                    )
                  else
                    ...courseFilteredResults.map(
                      (result) => _ResultCard(result: result),
                    ),
                  const SizedBox(height: 20),
                  _sectionHeader(
                    'All submitted results',
                    'Browse every level that has been released so far.',
                  ),
                  const SizedBox(height: 10),
                  if (levelResults.isEmpty)
                    const _EmptyStateCard(
                      icon: Icons.search_off_rounded,
                      title: 'No submitted results yet',
                      subtitle:
                          'Once the academic board releases grades, they will appear here automatically.',
                    )
                  else
                    ...levels.map(
                      (level) => _LevelResultsExpansion(
                        level: level,
                        results: allResults
                            .where((result) => result.level == level)
                            .toList(),
                        termLabel: termLabel,
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _bootstrapResults(Map<String, dynamic> userData) {
    if (_bootstrapped) return;
    _bootstrapped = true;
    final level = int.tryParse(userData['level']?.toString() ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _selectedLevel = level ?? _selectedLevel ?? 100;
          _selectedTerm = _selectedTerm ?? 1;
        });
      }
    });
  }

  Widget _buildTranscriptAccessGate(Map<String, dynamic> userData) {
    final linkedStudentId = _linkedStudentId(userData);
    final fullName = userData['fullName']?.toString().trim() ?? '';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _banner(
          context,
          title: 'Secure results and transcripts',
          subtitle: 'Enter the student ID linked to your RegentConnect profile before viewing published grades or generating a transcript.',
          icon: Icons.verified_user_rounded,
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Verify student record', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  linkedStudentId.isEmpty
                      ? 'Your student ID is not linked to this account yet. Ask the Academic Unit to update your profile before requesting a transcript.'
                      : 'For privacy, type your student ID exactly as it appears on your official record. Your full name must also agree with the published transcript record.',
                  style: TextStyle(color: Colors.grey.shade700, height: 1.35),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _studentIdController,
                  enabled: linkedStudentId.isNotEmpty,
                  decoration: const InputDecoration(
                    labelText: 'Student ID / Index number',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  onSubmitted: (_) => _verifyTranscriptAccess(userData),
                ),
                if (_accessError != null) ...[
                  const SizedBox(height: 10),
                  Text(_accessError!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: linkedStudentId.isEmpty ? null : () => _verifyTranscriptAccess(userData),
                    icon: const Icon(Icons.lock_open_rounded),
                    label: const Text('Verify and access results'),
                  ),
                ),
                if (fullName.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Profile name: $fullName', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTranscriptCard({
    required Map<String, dynamic> userData,
    required int currentLevel,
    required int selectedLevel,
    required int selectedTerm,
    required String termLabel,
    required List<AcademicResultModel> selectedCourseResults,
    required List<AcademicResultModel> semesterResults,
    required List<AcademicResultModel> fullResults,
  }) {
    final scopeResults = switch (_transcriptScope) {
      _TranscriptScope.selectedCourse => selectedCourseResults,
      _TranscriptScope.selectedSemester => semesterResults,
      _TranscriptScope.fullRecord => fullResults,
    };
    final scopeLabel = switch (_transcriptScope) {
      _TranscriptScope.selectedCourse => _selectedCourseCode ?? 'Selected course',
      _TranscriptScope.selectedSemester => 'Level $selectedLevel · $termLabel $selectedTerm',
      _TranscriptScope.fullRecord => 'Level 100 to Level $currentLevel',
    };
    return Card(
      elevation: 0,
      color: RegentColors.violet.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: RegentColors.violet.withOpacity(0.18))),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [Icon(Icons.picture_as_pdf_rounded, color: RegentColors.violet), SizedBox(width: 10), Text('Provisional transcript', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))]),
            const SizedBox(height: 7),
            const Text('Generate a professional two-page transcript based on your verified student record. It includes course marks, grades, credit hours, semester averages, CWA and the grading key.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Selected course'),
                  selected:
                      _transcriptScope == _TranscriptScope.selectedCourse,
                  onSelected: _selectedCourseCode == null
                      ? null
                      : (_) => setState(
                            () => _transcriptScope =
                                _TranscriptScope.selectedCourse,
                          ),
                ),
                ChoiceChip(
                  label: Text('Whole $termLabel'),
                  selected:
                      _transcriptScope == _TranscriptScope.selectedSemester,
                  onSelected: (_) => setState(
                    () => _transcriptScope =
                        _TranscriptScope.selectedSemester,
                  ),
                ),
                ChoiceChip(
                  label: const Text('Level 100 to current'),
                  selected: _transcriptScope == _TranscriptScope.fullRecord,
                  onSelected: (_) => setState(
                    () => _transcriptScope = _TranscriptScope.fullRecord,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _selectedCourseCode == null &&
                      _transcriptScope == _TranscriptScope.selectedCourse
                  ? 'Choose a specific course in the result filters to enable this scope.'
                  : '$scopeLabel · ${scopeResults.length} published result(s)',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: scopeResults.isEmpty || _generatingTranscript
                    ? null
                    : () => _prepareTranscript(userData, scopeResults, scopeLabel),
                icon: _generatingTranscript ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.print_rounded),
                label: Text(_generatingTranscript ? 'Preparing transcript...' : 'Print or download PDF'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _verifyTranscriptAccess(Map<String, dynamic> userData) {
    final linkedId = _linkedStudentId(userData);
    if (linkedId.isEmpty || _normalizedId(linkedId) != _normalizedId(_studentIdController.text)) {
      setState(() => _accessError = 'The student ID does not match the student record linked to this account.');
      return;
    }
    final name = userData['fullName']?.toString().trim() ?? '';
    if (name.isEmpty) {
      setState(() => _accessError = 'Your profile name is missing. Ask the Academic Unit to update your record before requesting a transcript.');
      return;
    }
    setState(() {
      _identityVerified = true;
      _accessError = null;
    });
  }

  Future<void> _prepareTranscript(Map<String, dynamic> userData, List<AcademicResultModel> results, String scopeLabel) async {
    setState(() => _generatingTranscript = true);
    try {
      final bytes = await _transcriptPdfService.buildTranscript(
        studentId: _linkedStudentId(userData),
        studentName: userData['fullName']?.toString().trim() ?? '',
        programName: userData['program']?.toString().trim() ?? 'Programme not specified',
        facultyName: userData['faculty']?.toString().trim() ?? 'Regent University College of Science and Technology',
        results: results,
        generatedAt: DateTime.now(),
        scopeLabel: scopeLabel,
      );
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.verified_rounded, size: 42, color: RegentColors.violet),
              const SizedBox(height: 10),
              const Text('Transcript PDF is ready', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('Print it now or download a copy for your records.', textAlign: TextAlign.center),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: () => _transcriptPdfService.print(bytes), icon: const Icon(Icons.print_outlined), label: const Text('Print'))),
                const SizedBox(width: 12),
                Expanded(child: FilledButton.icon(onPressed: () => _transcriptPdfService.download(bytes, 'regent-transcript-${_linkedStudentId(userData)}.pdf'), icon: const Icon(Icons.download_rounded), label: const Text('Download'))),
              ]),
            ]),
          ),
        ),
      );
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not prepare transcript: $error')));
    } finally {
      if (mounted) setState(() => _generatingTranscript = false);
    }
  }

  String _linkedStudentId(Map<String, dynamic> userData) =>
      (userData['studentId'] ?? userData['indexNumber'] ?? userData['indexNo'])?.toString().trim() ?? '';
  String _normalizedId(String value) => value.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
  String _normalizedName(String value) => value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

class AcademicSupportScreen extends StatelessWidget {
  const AcademicSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Academic Support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _banner(
            context,
            title: 'Support that keeps students moving',
            subtitle:
                'Reach academic offices, open official profiles and get the correct emails in one place.',
            icon: Icons.support_agent_rounded,
          ),
          const SizedBox(height: 16),
          _sectionHeader(
            'Official academic offices',
            'Tap an office to open its verified profile and chat directly.',
          ),
          const SizedBox(height: 10),
          ...OfficialAccounts.administrativeAccounts.map(
            (official) => _OfficialOfficeCard(
              official: official,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OfficialAccountProfileScreen(
                      account: official.toDirectoryMap(),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          _sectionHeader(
            'Faculty HoDs',
            'Each programme is routed to its faculty HoD. Ask about courses, programme changes or any faculty concern through a verified shared inbox.',
          ),
          const SizedBox(height: 12),
          for (final faculty in universityFaculties) ...[
            if (OfficialAccounts.facultyHeadsForSchool(faculty.name)
                .isNotEmpty) ...[
              Text(
                faculty.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              ...OfficialAccounts.facultyHeadsForSchool(faculty.name).map(
                (official) => _OfficialOfficeCard(
                  official: official,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OfficialAccountProfileScreen(
                          account: official.toDirectoryMap(),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
          const SizedBox(height: 10),
          _sectionHeader(
            'School contacts and online services',
            'Useful details students often need during the semester.',
          ),
          const SizedBox(height: 10),
          ...RegentUniversityProfile.onlineServices.map(
            (item) => Card(
              elevation: 0,
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
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Campus contacts',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  _contactRow(
                    icon: Icons.location_on_rounded,
                    label: RegentUniversityProfile.campusAddress,
                  ),
                  const SizedBox(height: 8),
                  ...RegentUniversityProfile.phoneContacts.map(
                    (phone) => _contactRow(
                      icon: Icons.call_rounded,
                      label: phone,
                      onTap: () => launchUrl(
                        Uri(
                          scheme: 'tel',
                          path: phone.replaceAll(' ', ''),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...RegentUniversityProfile.emails.map(
                    (email) => _contactRow(
                      icon: Icons.mail_rounded,
                      label: email,
                      onTap: () => launchUrl(
                        Uri(
                          scheme: 'mailto',
                          path: email,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _contactRow(
                    icon: Icons.public_rounded,
                    label: RegentUniversityProfile.website,
                    onTap: () => launchUrl(
                      Uri.parse(RegentUniversityProfile.website),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactRow({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: RegentColors.violet, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

Widget _banner(
  BuildContext context, {
  required String title,
  required String subtitle,
  required IconData icon,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [RegentColors.violet, RegentColors.darkViolet],
      ),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: Colors.white, size: 30),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.88),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _sectionHeader(String title, String subtitle) {
  return Column(
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
  );
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({
    required this.title,
    required this.subtitle,
    required this.dateRange,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final String dateRange;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: accent.withOpacity(0.16)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(height: 1.35)),
                  const SizedBox(height: 6),
                  Text(
                    dateRange,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
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
}

class _AcademicCalendarEvent {
  const _AcademicCalendarEvent({
    required this.title,
    required this.subtitle,
    required this.dateRange,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final String dateRange;
  final IconData icon;
  final Color accent;
}

class _CalendarTrackDetails {
  const _CalendarTrackDetails({required this.title, required this.subtitle, required this.period});

  final String title;
  final String subtitle;
  final String period;
}

const _calendarTrackDetails = <_CalendarTrack, _CalendarTrackDetails>{
  _CalendarTrack.continuing: _CalendarTrackDetails(
    title: 'Continuing students',
    subtitle: 'Main academic year calendar for continuing and top-up students.',
    period: '2026/2027 Academic Year',
  ),
  _CalendarTrack.octoberBatch: _CalendarTrackDetails(
    title: 'Level 100 October batch',
    subtitle: 'Level 100 October intake: 14 weeks including revision and examinations.',
    period: 'September - December 2026',
  ),
  _CalendarTrack.februaryBatch: _CalendarTrackDetails(
    title: 'Level 100 February batch',
    subtitle: 'Level 100 February intake: 13 weeks per semester.',
    period: 'February - August 2027',
  ),
  _CalendarTrack.weekendSchool: _CalendarTrackDetails(
    title: 'Weekend school',
    subtitle: 'Weekend school trimester calendar for the 2026/2027 academic year.',
    period: 'October 2026 - October 2027',
  ),
  _CalendarTrack.crush: _CalendarTrackDetails(
    title: 'CRUSH Level 100',
    subtitle: 'Accelerated calendar with six teaching weeks and two examination weeks.',
    period: 'April - August 2027',
  ),
};

_AcademicCalendarEvent _calendarEvent(String title, String subtitle, String dateRange, IconData icon, Color accent) =>
    _AcademicCalendarEvent(title: title, subtitle: subtitle, dateRange: dateRange, icon: icon, accent: accent);

List<_AcademicCalendarEvent> _academicTimelineEvents(_CalendarTrack track) {
  switch (track) {
    case _CalendarTrack.continuing:
      return [
        _calendarEvent('Reopening date', 'Main academic year reopens for continuing students.', 'Monday, 24 August 2026', Icons.restart_alt_rounded, RegentColors.violet),
        _calendarEvent('Course registration', 'Register and confirm first-semester courses.', '24 - 28 August 2026', Icons.assignment_turned_in_rounded, RegentColors.violet),
        _calendarEvent('Top-up orientation', 'Orientation for fresh top-up students.', '25 - 28 August 2026', Icons.groups_rounded, RegentColors.violet),
        _calendarEvent('Lectures begin', 'First-semester lectures commence for continuing students.', 'Monday, 31 August 2026', Icons.menu_book_rounded, RegentColors.green),
        _calendarEvent('Resit and supplementary examinations', 'Resit and supplementary examination window.', '14 - 18 September 2026', Icons.fact_check_rounded, Colors.orange),
        _calendarEvent('Departmental peer review week', 'Academic peer review activities.', '21 - 25 September 2026', Icons.groups_rounded, Colors.blue),
        _calendarEvent('Mid-semester examinations', 'First-semester assessment window.', '19 - 23 October 2026', Icons.fact_check_rounded, Colors.orange),
        _calendarEvent('End of lectures', 'First-semester teaching concludes.', 'Friday, 27 November 2026', Icons.school_rounded, RegentColors.green),
        _calendarEvent('Revision and appraisal week', 'Online revision and appraisal activities.', '30 November - 4 December 2026', Icons.fact_check_rounded, Colors.orange),
        _calendarEvent('First-semester examinations', 'Continuing students sit first-semester examinations.', '7 - 18 December 2026', Icons.edit_note_rounded, Colors.red),
        _calendarEvent('Second semester reopens', 'Course registration and lectures commence.', 'Monday, 4 January 2027', Icons.restart_alt_rounded, RegentColors.violet),
        _calendarEvent('Second-semester lectures', 'Continuing-student lectures begin.', 'Monday, 11 January 2027', Icons.menu_book_rounded, RegentColors.green),
        _calendarEvent('Mid-semester examinations', 'Second-semester assessment window.', '1 - 5 March 2027', Icons.fact_check_rounded, Colors.orange),
        _calendarEvent('Second-semester examinations', 'Second-semester examination window.', '19 - 29 April 2027', Icons.edit_note_rounded, Colors.red),
      ];
    case _CalendarTrack.octoberBatch:
      return [
        _calendarEvent('Mature applicants programme', 'Classes, examinations and orientation for mature applicants.', '31 July - 5 September 2026', Icons.groups_rounded, Colors.blue),
        _calendarEvent('Top-up orientation', 'Orientation for fresh top-up students; lectures begin 31 August.', '25 - 28 August 2026', Icons.groups_rounded, RegentColors.violet),
        _calendarEvent('Orientation and registration', 'Orientation and registration for fresh Level 100 October students.', '8 - 10 September 2026', Icons.how_to_reg_rounded, RegentColors.violet),
        _calendarEvent('Lectures begin', 'Level 100 October batch lectures commence.', 'Monday, 14 September 2026', Icons.menu_book_rounded, RegentColors.green),
        _calendarEvent('Joint Admission Board meeting', 'Joint Admission Board meeting for the October group.', 'Thursday, 29 October 2026', Icons.groups_rounded, Colors.blue),
        _calendarEvent('Mid-semester examinations', 'Mid-semester examination window.', '26 - 30 October 2026', Icons.fact_check_rounded, Colors.orange),
        _calendarEvent('End of lectures', 'Teaching concludes for the October batch.', 'Friday, 27 November 2026', Icons.school_rounded, RegentColors.green),
        _calendarEvent('Revision and appraisal week', 'Online revision and appraisal activities.', '30 November - 4 December 2026', Icons.fact_check_rounded, Colors.orange),
        _calendarEvent('Farmer\'s Day holiday', 'Public holiday.', 'Friday, 4 December 2026', Icons.event_busy_rounded, Colors.blue),
        _calendarEvent('Graduation ceremony', 'Official graduation ceremony.', 'Saturday, 12 December 2026', Icons.celebration_rounded, RegentColors.violet),
        _calendarEvent('First-semester examinations', 'Level 100 October examination window.', '7 - 18 December 2026', Icons.edit_note_rounded, Colors.red),
      ];
    case _CalendarTrack.februaryBatch:
      return [
        _calendarEvent('Orientation', 'Orientation for the Level 100 February batch.', '1 - 3 February 2027', Icons.groups_rounded, RegentColors.violet),
        _calendarEvent('Registration and lectures begin', 'Register courses and begin first-semester lectures.', '8 - 12 February 2027', Icons.assignment_turned_in_rounded, RegentColors.green),
        _calendarEvent('Lectures', 'First-semester lectures continue through the teaching period.', '8 February - 23 April 2027', Icons.menu_book_rounded, RegentColors.green),
        _calendarEvent('Matriculation', 'Matriculation for all fresh students.', 'Friday, 12 March 2027', Icons.celebration_rounded, RegentColors.violet),
        _calendarEvent('Parliamentary week', 'University parliamentary week.', '15 - 21 March 2027', Icons.groups_rounded, Colors.blue),
        _calendarEvent('Mid-semester examinations', 'First-semester assessment window.', '22 - 25 March 2027', Icons.fact_check_rounded, Colors.orange),
        _calendarEvent('Easter break', 'Public holiday break.', '26 - 29 March 2027', Icons.event_busy_rounded, Colors.blue),
        _calendarEvent('Revision and appraisal week', 'Online revision and appraisal activities.', '20 - 24 April 2027', Icons.fact_check_rounded, Colors.orange),
        _calendarEvent('First-semester examinations', 'End-of-semester examination window.', '26 April - 7 May 2027', Icons.edit_note_rounded, Colors.red),
        _calendarEvent('May Day holiday', 'Public holiday.', 'Saturday, 1 May 2027', Icons.event_busy_rounded, Colors.blue),
        _calendarEvent('Vacation', 'Break following first-semester examinations.', '7 - 14 May 2027', Icons.beach_access_rounded, Colors.blue),
        _calendarEvent('Second semester reopens', 'Second-semester registration and lectures commence.', 'Monday, 17 May 2027', Icons.restart_alt_rounded, RegentColors.violet),
        _calendarEvent('Summer examinations', 'Second-semester summer examination window.', '2 - 13 August 2027', Icons.edit_note_rounded, Colors.red),
      ];
    case _CalendarTrack.weekendSchool:
      return [
        _calendarEvent('Orientation and reopening', 'Weekend school orientation, reopening and course registration.', '2 - 10 October 2026', Icons.how_to_reg_rounded, RegentColors.violet),
        _calendarEvent('Mid-trimester examinations', 'First-trimester assessment window.', '20 - 21 November 2026', Icons.fact_check_rounded, Colors.orange),
        _calendarEvent('End of lectures', 'First-trimester teaching concludes.', 'Saturday, 19 December 2026', Icons.school_rounded, RegentColors.green),
        _calendarEvent('Revision and appraisal week', 'Weekend revision and appraisal activities.', '8 - 9 January 2027', Icons.fact_check_rounded, Colors.orange),
        _calendarEvent('First-trimester examinations', 'First-trimester examination window.', '15 - 23 January 2027', Icons.edit_note_rounded, Colors.red),
        _calendarEvent('Second trimester', 'Registration, teaching, revision and examinations.', '12 February - 15 May 2027', Icons.calendar_month_rounded, RegentColors.violet),
        _calendarEvent('Second-trimester mid examinations', 'Second-trimester mid-trimester examinations.', '2 - 3 April 2027', Icons.fact_check_rounded, Colors.orange),
        _calendarEvent('Third trimester', 'Registration, teaching, revision and examinations.', '4 June - 4 September 2027', Icons.calendar_month_rounded, RegentColors.violet),
        _calendarEvent('Third-trimester mid examinations', 'Third-trimester mid-trimester examinations.', '16 - 17 July 2027', Icons.fact_check_rounded, Colors.orange),
      ];
    case _CalendarTrack.crush:
      return [
        _calendarEvent('CRUSH first semester opens', 'Reopening and registration for Level 100 CRUSH students.', 'Monday, 26 April 2027', Icons.assignment_turned_in_rounded, RegentColors.violet),
        _calendarEvent('First-semester lectures', 'Six-week accelerated teaching period.', '3 May - 11 June 2027', Icons.menu_book_rounded, RegentColors.green),
        _calendarEvent('Question moderation deadline', 'Submission deadline for examination questions and marking schemes.', 'Friday, 4 June 2027', Icons.fact_check_rounded, Colors.orange),
        _calendarEvent('First-semester examinations', 'Two-week CRUSH examination window.', '14 - 25 June 2027', Icons.edit_note_rounded, Colors.red),
        _calendarEvent('CRUSH second semester opens', 'Reopening and registration for the next accelerated semester.', 'Monday, 28 June 2027', Icons.restart_alt_rounded, RegentColors.violet),
        _calendarEvent('Second-semester lectures', 'Six-week accelerated teaching period.', '28 June - 13 August 2027', Icons.menu_book_rounded, RegentColors.green),
        _calendarEvent('Question moderation deadline', 'Submission deadline for examination questions and marking schemes.', 'Friday, 6 August 2027', Icons.fact_check_rounded, Colors.orange),
        _calendarEvent('Second-semester examinations', 'Two-week CRUSH examination window.', '16 - 27 August 2027', Icons.edit_note_rounded, Colors.red),
      ];
  }
}

List<_AcademicCalendarEvent> _legacyAcademicTimelineEvents() {
  return [
    _AcademicCalendarEvent(
      title: 'First semester teaching begins',
      subtitle: 'Published regular-stream teaching timetables begin. Complete registration and confirm your course schedule on Cyber Campus.',
      dateRange: 'Monday, 24 August 2026',
      icon: Icons.assignment_turned_in_rounded,
      accent: RegentColors.violet,
    ),
    _AcademicCalendarEvent(
      title: 'Teaching period',
      subtitle: 'Scheduled lectures, practicals, consultations and continuous assessment across the published first-semester timetable.',
      dateRange: '24 August – 27 November 2026',
      icon: Icons.menu_book_rounded,
      accent: RegentColors.green,
    ),
    _AcademicCalendarEvent(
      title: 'Revision and assessment preparation',
      subtitle: 'Use the final teaching week to complete course requirements and prepare for end-of-semester examinations.',
      dateRange: '28 November – 6 December 2026',
      icon: Icons.fact_check_rounded,
      accent: Colors.orange,
    ),
    _AcademicCalendarEvent(
      title: 'First semester examinations',
      subtitle: 'Published examination window for the 2026/2027 first semester.',
      dateRange: '7 – 18 December 2026',
      icon: Icons.edit_note_rounded,
      accent: Colors.red,
    ),
    _AcademicCalendarEvent(
      title: 'Vacation',
      subtitle: 'Semester break following the examination period.',
      dateRange: '18 December 2026 – 1 January 2027',
      icon: Icons.verified_rounded,
      accent: Colors.blue,
    ),
    _AcademicCalendarEvent(
      title: 'Next semester reopens',
      subtitle: 'Students return for the next semester and should confirm new course and timetable updates.',
      dateRange: 'Monday, 4 January 2027',
      icon: Icons.restart_alt_rounded,
      accent: RegentColors.violet,
    ),
  ];
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final AcademicResultModel result;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.courseName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        result.courseCode,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                _gradeBadge(result.grade),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _infoChip('Score', '${result.score.toStringAsFixed(1)}%'),
                _infoChip('Credit hours', '${result.creditHours}'),
                _infoChip('Point', result.gradePoint.toStringAsFixed(1)),
                _infoChip('Term', '${result.termLabel} ${result.semester}'),
                _infoChip('Year', result.academicYear),
              ],
            ),
            const SizedBox(height: 10),
            Text(result.remarks),
          ],
        ),
      ),
    );
  }

  Widget _gradeBadge(String grade) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: RegentColors.violet.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        grade,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: RegentColors.violet,
        ),
      ),
    );
  }

  Widget _infoChip(String label, String value) {
    return Chip(label: Text('$label: $value'));
  }
}

class _LevelResultsExpansion extends StatelessWidget {
  const _LevelResultsExpansion({
    required this.level,
    required this.results,
    required this.termLabel,
  });

  final int level;
  final List<AcademicResultModel> results;
  final String termLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        title: Text(
          'Level $level',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('${results.length} result(s) submitted'),
        children: [
          if (results.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No results submitted for this level yet.'),
            )
          else
            ...results.map((result) => _ResultCard(result: result)),
        ],
      ),
    );
  }
}

class _ResultsSummaryRow extends StatelessWidget {
  const _ResultsSummaryRow({
    required this.cgpa,
    required this.submittedCount,
    required this.selectedLevel,
    required this.selectedTerm,
    required this.termLabel,
  });

  final double cgpa;
  final int submittedCount;
  final int selectedLevel;
  final int selectedTerm;
  final String termLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            title: 'CGPA',
            value: cgpa == 0 ? '—' : cgpa.toStringAsFixed(2),
            icon: Icons.insights_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryCard(
            title: 'Submitted',
            value: '$submittedCount',
            icon: Icons.upload_file_rounded,
          ),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RegentColors.violet.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: RegentColors.violet),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12)),
              Text(
                value,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OfficialOfficeCard extends StatelessWidget {
  const _OfficialOfficeCard({
    required this.official,
    required this.onTap,
  });

  final OfficialAccountDefinition official;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: RegentColors.violet.withOpacity(0.1),
          child: const Icon(Icons.verified_rounded, color: RegentColors.violet),
        ),
        title: Text(
          official.name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('${official.office}\n${official.email}'),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _ProgramSnapshotCard extends StatelessWidget {
  const _ProgramSnapshotCard({
    required this.faculty,
    required this.program,
    required this.level,
    required this.courseCount,
    required this.questionCount,
  });

  final String faculty;
  final String program;
  final int level;
  final int courseCount;
  final int questionCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              program,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(faculty),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _pill('Level $level'),
                _pill('$questionCount question(s)'),
                _pill('$courseCount course title(s)'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text) {
    return Chip(label: Text(text));
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 54, color: RegentColors.violet),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}
