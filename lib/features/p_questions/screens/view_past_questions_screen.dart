import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme.dart';
import '../../../models/past_question_model.dart';
import '../../../services/past_questions_service.dart';
import '../../../services/auth_service.dart';

class ViewPastQuestionsScreen extends StatefulWidget {
  final String facultyName;
  final String programName;
  final String? option;
  final int level;
  final int semester;
  final String termLabel;
  final String? courseTitleQuery;

  const ViewPastQuestionsScreen({
    super.key,
    required this.facultyName,
    required this.programName,
    this.option,
    required this.level,
    required this.semester,
    this.termLabel = 'Semester',
    this.courseTitleQuery,
  });

  @override
  State<ViewPastQuestionsScreen> createState() =>
      _ViewPastQuestionsScreenState();
}

class _ViewPastQuestionsScreenState extends State<ViewPastQuestionsScreen> {
  int? selectedYear;
  final List<int> years = List.generate(12, (index) => DateTime.now().year - index);
  final pastQuestionsService = PastQuestionsService();
  final authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final query = widget.courseTitleQuery?.trim() ?? '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: RegentColors.blue,
        title: const Text(
          'Past Questions',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.programName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Level ${widget.level} • ${widget.termLabel} ${widget.semester}',
                  style: const TextStyle(color: Colors.grey),
                ),
                if (query.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Search: $query',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  value: selectedYear,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Year',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('All Years'),
                    ),
                    ...years.map(
                      (year) => DropdownMenuItem<int?>(
                        value: year,
                        child: Text('$year'),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => selectedYear = value);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<PastQuestionModel>>(
              stream: pastQuestionsService.watchPastQuestions(
                facultyName: widget.facultyName,
                programName: widget.programName,
                level: widget.level,
                semester: widget.semester,
                query: query,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No past questions found'),
                        SizedBox(height: 8),
                        Text(
                          'Be the first to upload!',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                var questions = snapshot.data!;
                if (selectedYear != null) {
                  questions = questions
                      .where((question) => question.year == selectedYear)
                      .toList();
                }

                if (questions.isEmpty) {
                  return Center(
                    child: Text('No past questions for $selectedYear'),
                  );
                }

                final groupedQuestions = <String, List<PastQuestionModel>>{};
                for (final question in questions) {
                  final key = '${question.courseCode} - ${question.courseName}';
                  groupedQuestions.putIfAbsent(key, () => []).add(question);
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: groupedQuestions.length,
                  itemBuilder: (context, index) {
                    final courseKey = groupedQuestions.keys.elementAt(index);
                    final courseQuestions = groupedQuestions[courseKey]!;
                    return _buildCourseCard(courseKey, courseQuestions);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(String courseKey, List<PastQuestionModel> questions) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Text(
          courseKey,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${questions.length} past question(s)'),
        leading: const Icon(Icons.book, color: RegentColors.blue),
        children: questions.map(_buildQuestionTile).toList(),
      ),
    );
  }

  Widget _buildQuestionTile(PastQuestionModel question) {
    final currentUserId = authService.currentUser?.uid;
    final isOwner = currentUserId == question.uploadedBy;

    return ListTile(
      leading: _getFileIcon(question.fileType),
      title: Text('${question.year} Exam'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question.fileName, style: const TextStyle(fontSize: 12)),
          Text(
            'Uploaded by ${question.uploaderName}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          Row(
            children: [
              const Icon(Icons.download, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                '${question.downloadCount} downloads',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.download, color: RegentColors.green),
            tooltip: 'Download',
            onPressed: () => _downloadFile(question),
          ),
          IconButton(
            icon: const Icon(Icons.visibility, color: RegentColors.blue),
            tooltip: 'View',
            onPressed: () => _viewFile(question),
          ),
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Delete',
              onPressed: () => _deleteQuestion(question),
            ),
        ],
      ),
    );
  }

  Widget _getFileIcon(String fileType) {
    final lower = fileType.toLowerCase();
    IconData icon;
    Color color;

    switch (lower) {
      case 'pdf':
        icon = Icons.picture_as_pdf;
        color = Colors.red;
        break;
      case 'doc':
      case 'docx':
        icon = Icons.description;
        color = Colors.blue;
        break;
      case 'png':
      case 'jpg':
      case 'jpeg':
        icon = Icons.image;
        color = Colors.green;
        break;
      default:
        icon = Icons.insert_drive_file;
        color = Colors.grey;
    }

    return Icon(icon, color: color);
  }

  Future<void> _downloadFile(PastQuestionModel question) async {
    try {
      final uri = Uri.parse(question.fileUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        await pastQuestionsService.incrementDownloadCount(question.id);
      } else {
        throw Exception('Cannot open file');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading: $error')),
        );
      }
    }
  }

  Future<void> _viewFile(PastQuestionModel question) async {
    try {
      final uri = Uri.parse(question.fileUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.inAppWebView);
      } else {
        throw Exception('Cannot open file');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error viewing: $error')),
        );
      }
    }
  }

  Future<void> _deleteQuestion(PastQuestionModel question) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Past Question'),
        content:
            const Text('Are you sure you want to delete this past question?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await pastQuestionsService.deletePastQuestion(
        question.id,
        question.fileUrl,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Deleted successfully' : 'Failed to delete'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }
}
