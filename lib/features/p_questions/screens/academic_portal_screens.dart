import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/official_accounts.dart';
import '../../../core/programs_data.dart';
import '../../../core/regent_university_profile.dart';
import '../../../core/theme.dart';
import '../../../models/academic_result_model.dart';
import '../../../models/past_question_model.dart';
import '../../../services/academic_results_service.dart';
import '../../../services/past_questions_service.dart';
import '../../chat/screens/official_account_profile_screen.dart';
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
                      final courseTitles = questions
                          .map((question) => question.courseName.trim())
                          .where((value) => value.isNotEmpty)
                          .toSet()
                          .toList()
                        ..sort();

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
                          _buildQuestionSearchCard(courseTitles),
                          const SizedBox(height: 16),
                          if (courseTitles.isNotEmpty)
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
                          if (courseTitles.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: courseTitles
                                  .take(10)
                                  .map(
                                    (title) => ChoiceChip(
                                      label: Text(title),
                                      selected:
                                          _courseQuery.trim().toLowerCase() ==
                                              title.toLowerCase(),
                                      onSelected: (_) {
                                        setState(() {
                                          _courseQuery = title;
                                          _searchQuery = title;
                                          _searchController.text = title;
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
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                            _courseQuery = '';
                          });
                        },
                        icon: const Icon(Icons.clear_rounded),
                      ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _courseQuery = value;
                });
              },
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
                                initialCourseName: _courseQuery.trim().isEmpty
                                    ? null
                                    : _courseQuery.trim(),
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

  Widget _buildQuestionSearchCard(List<String> courseTitles) {
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
              courseTitles.isEmpty
                  ? 'No related titles have been uploaded for this selection yet.'
                  : 'Tap a title to keep only the related past questions in view.',
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
          ),
        ),
      ],
    );
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
  });

  final PastQuestionModel question;
  final VoidCallback onView;
  final VoidCallback onDownload;

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

class AcademicCalendarScreen extends StatelessWidget {
  const AcademicCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final academicYear =
        '${DateTime.now().year}/${DateTime.now().year + 1} Academic Year';
    final events = _academicTimelineEvents();

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
              child: Row(
                children: [
                  const Icon(Icons.event_available_rounded,
                      color: RegentColors.violet),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      academicYear,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
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
        ],
      ),
    );
  }
}

class AcademicCourseInfoScreen extends StatefulWidget {
  const AcademicCourseInfoScreen({super.key});

  @override
  State<AcademicCourseInfoScreen> createState() =>
      _AcademicCourseInfoScreenState();
}

class _AcademicCourseInfoScreenState extends State<AcademicCourseInfoScreen> {
  final _service = PastQuestionsService();
  FacultyData? _faculty;
  ProgramData? _program;
  int? _level;
  int _semester = 1;
  String _search = '';

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
                        decoration: const InputDecoration(
                          labelText: 'Search course title',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                        onChanged: (value) => setState(() => _search = value),
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
                    final titles = questions
                        .map((question) => question.courseName)
                        .where((value) => value.trim().isNotEmpty)
                        .toSet()
                        .toList()
                      ..sort();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionHeader(
                          'Available titles',
                          'These titles are drawn from uploaded past questions and lecture resources.',
                        ),
                        const SizedBox(height: 10),
                        if (titles.isEmpty)
                          const _EmptyStateCard(
                            icon: Icons.search_off_rounded,
                            title: 'No titles found yet',
                            subtitle:
                                'Try a broader search or upload the first academic file for this course.',
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: titles
                                .map(
                                  (title) => ActionChip(
                                    label: Text(title),
                                    onPressed: () {
                                      setState(() => _search = title);
                                    },
                                  ),
                                )
                                .toList(),
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
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ViewPastQuestionsScreen(
                                      facultyName: _faculty!.name,
                                      programName: _program!.name,
                                      option: null,
                                      level: _level!,
                                      semester: _semester,
                                      courseTitleQuery:
                                          _search.trim().isEmpty ? null : _search,
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.visibility_rounded),
                                label: const Text('Open questions'),
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
                          courseCount: titles.length,
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
}

class AcademicResultsScreen extends StatefulWidget {
  const AcademicResultsScreen({super.key});

  @override
  State<AcademicResultsScreen> createState() => _AcademicResultsScreenState();
}

class _AcademicResultsScreenState extends State<AcademicResultsScreen> {
  final _service = AcademicResultsService();
  final _searchController = TextEditingController();
  int? _selectedLevel;
  int? _selectedTerm;
  bool _bootstrapped = false;

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

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _banner(
                    context,
                    title: 'See the grades you have earned so far',
                    subtitle:
                        'Results are grouped by level and term, with missing submissions clearly marked as awaiting approval.',
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
                  _sectionHeader(
                    'Selected term results',
                    'Everything submitted for the chosen level and term appears here.',
                  ),
                  const SizedBox(height: 10),
                  if (selectedResults.isEmpty)
                    const _EmptyStateCard(
                      icon: Icons.pending_actions_rounded,
                      title: 'Awaiting academic board submission',
                      subtitle:
                          'No results have been published for the selected level and term yet.',
                    )
                  else
                    ...selectedResults.map(
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
          ...OfficialAccounts.accounts.map(
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

List<_AcademicCalendarEvent> _academicTimelineEvents() {
  final now = DateTime.now();
  final month = DateFormat('MMM').format(now);
  return [
    _AcademicCalendarEvent(
      title: 'Registration and clearance',
      subtitle: 'Fee confirmation, registration checks and course advising.',
      dateRange: '$month - First 2 weeks',
      icon: Icons.assignment_turned_in_rounded,
      accent: RegentColors.violet,
    ),
    _AcademicCalendarEvent(
      title: 'Lecture period',
      subtitle: 'Regular classes, seminar discussions and course consultations.',
      dateRange: '$month - Mid term',
      icon: Icons.menu_book_rounded,
      accent: RegentColors.green,
    ),
    _AcademicCalendarEvent(
      title: 'Mid-semester review',
      subtitle: 'Assignments, quizzes and continuous assessment checkpoints.',
      dateRange: '$month - Review week',
      icon: Icons.fact_check_rounded,
      accent: Colors.orange,
    ),
    _AcademicCalendarEvent(
      title: 'Examinations',
      subtitle: 'Final papers and practical assessments for the semester.',
      dateRange: '$month - Examination week',
      icon: Icons.edit_note_rounded,
      accent: Colors.red,
    ),
    _AcademicCalendarEvent(
      title: 'Results release',
      subtitle: 'Academic board release and grade publication.',
      dateRange: '$month - After board approval',
      icon: Icons.verified_rounded,
      accent: Colors.blue,
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
