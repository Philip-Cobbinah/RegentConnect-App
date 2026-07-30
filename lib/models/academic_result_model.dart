import 'package:cloud_firestore/cloud_firestore.dart';

class AcademicResultModel {
  final String id;
  final String studentId;
  final String? studentName;
  final String? programName;
  final String? facultyName;
  final int level;
  final int semester;
  final String termLabel;
  final String academicYear;
  final String courseCode;
  final String courseName;
  final int creditHours;
  final double score;
  final String grade;
  final double gradePoint;
  final String remarks;
  final DateTime? submittedAt;

  const AcademicResultModel({
    required this.id,
    required this.studentId,
    this.studentName,
    this.programName,
    this.facultyName,
    required this.level,
    required this.semester,
    required this.termLabel,
    required this.academicYear,
    required this.courseCode,
    required this.courseName,
    required this.creditHours,
    required this.score,
    required this.grade,
    required this.gradePoint,
    required this.remarks,
    this.submittedAt,
  });

  factory AcademicResultModel.fromMap(Map<String, dynamic> map, String id) {
    return AcademicResultModel(
      id: id,
      studentId: _string(map['studentId']),
      studentName: _nullableString(map['studentName']),
      programName: _nullableString(map['programName']),
      facultyName: _nullableString(map['facultyName']),
      level: _int(map['level'], fallback: 100),
      semester: _int(map['semester'], fallback: 1),
      termLabel: _string(map['termLabel'], fallback: 'Semester'),
      academicYear: _string(map['academicYear'], fallback: '2025/2026'),
      courseCode: _string(map['courseCode']),
      courseName: _string(map['courseName'], fallback: 'Untitled course'),
      creditHours: _int(map['creditHours'], fallback: 3),
      score: _double(map['score'], fallback: 0),
      grade: _string(map['grade'], fallback: 'N/A'),
      gradePoint: _double(map['gradePoint'], fallback: 0),
      remarks: _string(map['remarks'], fallback: 'Awaiting board review'),
      submittedAt: _asDateTime(map['submittedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'programName': programName,
      'facultyName': facultyName,
      'level': level,
      'semester': semester,
      'termLabel': termLabel,
      'academicYear': academicYear,
      'courseCode': courseCode,
      'courseName': courseName,
      'creditHours': creditHours,
      'score': score,
      'grade': grade,
      'gradePoint': gradePoint,
      'remarks': remarks,
      'submittedAt': submittedAt == null
          ? null
          : Timestamp.fromDate(submittedAt!),
    };
  }
}

String _string(dynamic value, {String fallback = ''}) {
  final resolved = value?.toString().trim();
  return resolved == null || resolved.isEmpty ? fallback : resolved;
}

String? _nullableString(dynamic value) {
  final resolved = value?.toString().trim();
  return resolved == null || resolved.isEmpty ? null : resolved;
}

int _int(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _double(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
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
