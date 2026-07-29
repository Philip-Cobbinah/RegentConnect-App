import 'package:cloud_firestore/cloud_firestore.dart';

class AcademicAttachmentModel {
  final String kind;
  final String name;
  final String url;
  final String storagePath;
  final String contentType;
  final int size;

  const AcademicAttachmentModel({
    required this.kind,
    required this.name,
    required this.url,
    required this.storagePath,
    required this.contentType,
    required this.size,
  });

  bool get isImage => kind == 'image';
  bool get isVideo => kind == 'video';
  bool get isAudio => kind == 'audio';
  bool get isFile => !isImage && !isVideo && !isAudio;

  factory AcademicAttachmentModel.fromMap(Map<String, dynamic> map) {
    return AcademicAttachmentModel(
      kind: _asString(map['kind'], fallback: 'file'),
      name: _asString(map['name'], fallback: 'attachment'),
      url: _asString(map['url']),
      storagePath: _asString(map['storagePath']),
      contentType: _asString(map['contentType']),
      size: _asInt(map['size']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'kind': kind,
      'name': name,
      'url': url,
      'storagePath': storagePath,
      'contentType': contentType,
      'size': size,
    };
  }
}

class AcademicPostModel {
  final String id;
  final String postType;
  final String title;
  final String caption;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String authorRole;
  final String? authorEmail;
  final String? courseCode;
  final String? courseName;
  final List<int> targetLevels;
  final List<String> targetPrograms;
  final List<String> targetCourses;
  final List<AcademicAttachmentModel> attachments;
  final DateTime createdAt;
  final DateTime? dueAt;
  final DateTime? lectureAt;
  final bool isPinned;
  final bool isArchived;
  final int viewCount;
  final int replyCount;
  final String? searchText;

  const AcademicPostModel({
    required this.id,
    required this.postType,
    required this.title,
    required this.caption,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    required this.authorRole,
    this.authorEmail,
    this.courseCode,
    this.courseName,
    required this.targetLevels,
    required this.targetPrograms,
    required this.targetCourses,
    required this.attachments,
    required this.createdAt,
    this.dueAt,
    this.lectureAt,
    this.isPinned = false,
    this.isArchived = false,
    this.viewCount = 0,
    this.replyCount = 0,
    this.searchText,
  });

  bool get isAssignment => postType == 'assignment';
  bool get isLecture => postType == 'lecture';
  bool get hasDueDate => dueAt != null;

  bool isRelevantTo({
    int? level,
    String? program,
    String? course,
  }) {
    final normalizedProgram = _normalize(program);
    final normalizedCourse = _normalize(course);

    if (targetLevels.isEmpty &&
        targetPrograms.isEmpty &&
        targetCourses.isNotEmpty) {
      return true;
    }

    final levelMatch =
        targetLevels.isEmpty || (level != null && targetLevels.contains(level));
    final programMatch = targetPrograms.isEmpty ||
        (normalizedProgram != null &&
            targetPrograms.map(_normalize).contains(normalizedProgram));
    final courseMatch = targetCourses.isEmpty ||
        (normalizedCourse != null &&
            targetCourses.map(_normalize).contains(normalizedCourse));

    return levelMatch || programMatch || courseMatch;
  }

  String audienceLabel() {
    final labels = <String>[];
    if (targetLevels.isNotEmpty) {
      labels.addAll(targetLevels.map((level) => 'Level $level'));
    }
    if (targetPrograms.isNotEmpty) {
      labels.addAll(
        targetPrograms
            .map((program) => program.trim())
            .where((value) => value.isNotEmpty),
      );
    }
    if (targetCourses.isNotEmpty) {
      labels.addAll(
        targetCourses
            .map((course) => course.trim())
            .where((value) => value.isNotEmpty),
      );
    }
    if (labels.isEmpty) return 'All students';
    if (labels.length <= 3) return labels.join(' • ');
    return '${labels.take(3).join(' • ')} +${labels.length - 3} more';
  }

  String searchBody() {
    return [
      title,
      caption,
      authorName,
      authorRole,
      courseCode,
      courseName,
      ...attachments.map((attachment) => attachment.name),
      ...targetPrograms,
      ...targetCourses,
      ...targetLevels.map((level) => 'Level $level'),
    ].whereType<String>().join(' ').toLowerCase();
  }

  factory AcademicPostModel.fromMap(Map<String, dynamic> map, String id) {
    return AcademicPostModel(
      id: id,
      postType: _asString(map['postType'], fallback: 'assignment'),
      title: _asString(map['title'], fallback: 'Untitled post'),
      caption: _asString(map['caption']),
      authorId: _asString(map['authorId']),
      authorName: _asString(map['authorName'], fallback: 'Regent user'),
      authorPhotoUrl: map['authorPhotoUrl']?.toString(),
      authorRole: _asString(map['authorRole'], fallback: 'student'),
      authorEmail: map['authorEmail']?.toString(),
      courseCode: _nullableString(map['courseCode']),
      courseName: _nullableString(map['courseName']),
      targetLevels: _parseLevels(map['targetLevels']),
      targetPrograms: _parseStringList(map['targetPrograms']),
      targetCourses: _parseStringList(map['targetCourses']),
      attachments: _parseAttachments(map['attachments']),
      createdAt: _asDateTime(map['createdAt']) ?? DateTime.now(),
      dueAt: _asDateTime(map['dueAt']),
      lectureAt: _asDateTime(map['lectureAt']),
      isPinned: map['isPinned'] == true,
      isArchived: map['isArchived'] == true,
      viewCount: _asInt(map['viewCount']),
      replyCount: _asInt(map['replyCount']),
      searchText: map['searchText']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'postType': postType,
      'title': title,
      'caption': caption,
      'authorId': authorId,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
      'authorRole': authorRole,
      'authorEmail': authorEmail,
      'courseCode': courseCode,
      'courseName': courseName,
      'targetLevels': targetLevels,
      'targetPrograms': targetPrograms,
      'targetCourses': targetCourses,
      'attachments':
          attachments.map((attachment) => attachment.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'dueAt': dueAt == null ? null : Timestamp.fromDate(dueAt!),
      'lectureAt': lectureAt == null ? null : Timestamp.fromDate(lectureAt!),
      'isPinned': isPinned,
      'isArchived': isArchived,
      'viewCount': viewCount,
      'replyCount': replyCount,
      'searchText': searchText ?? searchBody(),
    };
  }
}

String _asString(dynamic value, {String fallback = ''}) {
  final resolved = value?.toString().trim();
  return resolved == null || resolved.isEmpty ? fallback : resolved;
}

String? _nullableString(dynamic value) {
  final resolved = value?.toString().trim();
  return resolved == null || resolved.isEmpty ? null : resolved;
}

int _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _asDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  try {
    return (value as dynamic).toDate() as DateTime;
  } catch (_) {
    return DateTime.tryParse(value.toString());
  }
}

List<int> _parseLevels(dynamic value) {
  final raw = value is Iterable ? value : const [];
  return raw
      .map((item) => int.tryParse(item.toString()))
      .whereType<int>()
      .toSet()
      .toList()
    ..sort();
}

List<String> _parseStringList(dynamic value) {
  final raw = value is Iterable ? value : const [];
  return raw
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList();
}

List<AcademicAttachmentModel> _parseAttachments(dynamic value) {
  final raw = value is Iterable ? value : const [];
  return raw
      .whereType<Map>()
      .map((item) =>
          AcademicAttachmentModel.fromMap(Map<String, dynamic>.from(item)))
      .toList();
}

String? _normalize(String? value) {
  final resolved = value?.trim().toLowerCase();
  return resolved == null || resolved.isEmpty ? null : resolved;
}
