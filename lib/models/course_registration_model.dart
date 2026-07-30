import 'package:cloud_firestore/cloud_firestore.dart';

class CourseRegistrationModel {
  final String id;
  final String studentUid;
  final String studentId;
  final String fullName;
  final int level;
  final int term;
  final String termLabel;
  final String facultyName;
  final String programName;
  final String academicSession;
  final DateTime registrationDate;
  final String status;
  final String? attachmentUrl;
  final String? attachmentStoragePath;
  final String? attachmentName;
  final String? attachmentContentType;
  final int? attachmentSize;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CourseRegistrationModel({
    required this.id,
    required this.studentUid,
    required this.studentId,
    required this.fullName,
    required this.level,
    required this.term,
    required this.termLabel,
    required this.facultyName,
    required this.programName,
    required this.academicSession,
    required this.registrationDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.attachmentUrl,
    this.attachmentStoragePath,
    this.attachmentName,
    this.attachmentContentType,
    this.attachmentSize,
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
      level: _int(map['level'], fallback: 0),
      term: _int(map['term'], fallback: 1),
      termLabel: _string(map['termLabel'], fallback: 'Semester'),
      facultyName: _string(map['facultyName']),
      programName: _string(map['programName']),
      academicSession: _string(map['academicSession'], fallback: 'morning'),
      registrationDate: _dateTime(map['registrationDate']) ?? DateTime.now(),
      status: _string(map['status'], fallback: 'pending'),
      attachmentUrl: _nullableString(map['attachmentUrl']),
      attachmentStoragePath: _nullableString(map['attachmentStoragePath']),
      attachmentName: _nullableString(map['attachmentName']),
      attachmentContentType: _nullableString(map['attachmentContentType']),
      attachmentSize: _nullableInt(map['attachmentSize']),
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
      'level': level,
      'term': term,
      'termLabel': termLabel,
      'facultyName': facultyName,
      'programName': programName,
      'academicSession': academicSession,
      'registrationDate': Timestamp.fromDate(registrationDate),
      'status': status,
      'attachmentUrl': attachmentUrl,
      'attachmentStoragePath': attachmentStoragePath,
      'attachmentName': attachmentName,
      'attachmentContentType': attachmentContentType,
      'attachmentSize': attachmentSize,
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
