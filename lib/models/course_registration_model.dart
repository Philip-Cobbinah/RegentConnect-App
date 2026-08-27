import 'package:cloud_firestore/cloud_firestore.dart';

class RegisteredCourse {
  final String code;
  final String title;
  final int creditHours;
  final bool isElective;

  const RegisteredCourse({
    required this.code,
    required this.title,
    required this.creditHours,
    this.isElective = false,
  });

  factory RegisteredCourse.fromMap(Map<String, dynamic> map) => RegisteredCourse(
        code: _courseString(map['code']),
        title: _courseString(map['title']),
        creditHours: _courseInt(map['creditHours']),
        isElective: map['isElective'] == true,
      );

  Map<String, dynamic> toMap() => {
        'code': code,
        'title': title,
        'creditHours': creditHours,
        'isElective': isElective,
      };

  static String _courseString(dynamic value) => value?.toString().trim() ?? '';
  static int _courseInt(dynamic value) => value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '') ?? 0;
}

class CourseRegistrationModel {
  final String id;
  final String studentUid;
  final String studentId;
  final String fullName;
  final String phoneNumber;
  final int level;
  final int term;
  final String termLabel;
  final String facultyName;
  final String programName;
  final String academicSession;
  final String academicYear;
  final List<RegisteredCourse> courses;
  final String recipientLabel;
  final DateTime registrationDate;
  final String status;
  final String? attachmentUrl;
  final String? attachmentStoragePath;
  final String? attachmentName;
  final String? attachmentContentType;
  final int? attachmentSize;
  final String? pdfUrl;
  final String? pdfStoragePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CourseRegistrationModel({
    required this.id,
    required this.studentUid,
    required this.studentId,
    required this.fullName,
    required this.phoneNumber,
    required this.level,
    required this.term,
    required this.termLabel,
    required this.facultyName,
    required this.programName,
    required this.academicSession,
    required this.academicYear,
    required this.courses,
    required this.recipientLabel,
    required this.registrationDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.attachmentUrl,
    this.attachmentStoragePath,
    this.attachmentName,
    this.attachmentContentType,
    this.attachmentSize,
    this.pdfUrl,
    this.pdfStoragePath,
  });

  factory CourseRegistrationModel.fromMap(
    Map<String, dynamic> map,
    String id,
  ) {
    return CourseRegistrationModel(
      id: id,
      studentUid: _string(map['studentUid']),
      studentId: _string(map['studentId']),
      fullName: _string(map['fullName']),
      phoneNumber: _string(map['phoneNumber']),
      level: _int(map['level'], fallback: 0),
      term: _int(map['term'], fallback: 1),
      termLabel: _string(map['termLabel'], fallback: 'Semester'),
      facultyName: _string(map['facultyName']),
      programName: _string(map['programName']),
      academicSession: _string(map['academicSession'], fallback: 'morning'),
      academicYear: _string(map['academicYear']),
      courses: (map['courses'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(RegisteredCourse.fromMap)
          .toList(growable: false),
      recipientLabel: _string(map['recipientLabel'], fallback: 'Faculty Office'),
      registrationDate: _dateTime(map['registrationDate']) ?? DateTime.now(),
      status: _string(map['status'], fallback: 'pending'),
      attachmentUrl: _nullableString(map['attachmentUrl']),
      attachmentStoragePath: _nullableString(map['attachmentStoragePath']),
      attachmentName: _nullableString(map['attachmentName']),
      attachmentContentType: _nullableString(map['attachmentContentType']),
      attachmentSize: _nullableInt(map['attachmentSize']),
      pdfUrl: _nullableString(map['pdfUrl']),
      pdfStoragePath: _nullableString(map['pdfStoragePath']),
      createdAt: _dateTime(map['createdAt']) ??
          _dateTime(map['updatedAt']) ??
          DateTime.now(),
      updatedAt: _dateTime(map['updatedAt']) ??
          _dateTime(map['createdAt']) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentUid': studentUid,
      'studentId': studentId,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'level': level,
      'term': term,
      'termLabel': termLabel,
      'facultyName': facultyName,
      'programName': programName,
      'academicSession': academicSession,
      'academicYear': academicYear,
      'courses': courses.map((course) => course.toMap()).toList(),
      'recipientLabel': recipientLabel,
      'registrationDate': Timestamp.fromDate(registrationDate),
      'status': status,
      'attachmentUrl': attachmentUrl,
      'attachmentStoragePath': attachmentStoragePath,
      'attachmentName': attachmentName,
      'attachmentContentType': attachmentContentType,
      'attachmentSize': attachmentSize,
      'pdfUrl': pdfUrl,
      'pdfStoragePath': pdfStoragePath,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static String _string(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static int _int(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int? _nullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static DateTime? _dateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
