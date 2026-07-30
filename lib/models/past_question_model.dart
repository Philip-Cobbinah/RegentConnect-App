import 'package:cloud_firestore/cloud_firestore.dart';

class PastQuestionModel {
  final String id;
  final String courseCode;
  final String courseName;
  final String programName;
  final String facultyName;
  final int level;
  final int semester;
  final int year; // 2015-2025
  final String fileUrl;
  final String fileName;
  final String fileType; // pdf, docx, png, jpeg, etc.
  final String uploadedBy; // user ID
  final String uploaderName;
  final DateTime uploadedAt;
  final int downloadCount;

  PastQuestionModel({
    required this.id,
    required this.courseCode,
    required this.courseName,
    required this.programName,
    required this.facultyName,
    required this.level,
    required this.semester,
    required this.year,
    required this.fileUrl,
    required this.fileName,
    required this.fileType,
    required this.uploadedBy,
    required this.uploaderName,
    required this.uploadedAt,
    this.downloadCount = 0,
  });

  factory PastQuestionModel.fromMap(Map<String, dynamic> map, String id) {
    return PastQuestionModel(
      id: id,
      courseCode: map['courseCode'] ?? '',
      courseName: map['courseName'] ?? '',
      programName: map['programName'] ?? '',
      facultyName: map['facultyName'] ?? '',
      level: map['level'] ?? 100,
      semester: map['semester'] ?? 1,
      year: map['year'] ?? 2020,
      fileUrl: map['fileUrl'] ?? '',
      fileName: map['fileName'] ?? '',
      fileType: map['fileType'] ?? '',
      uploadedBy: map['uploadedBy'] ?? '',
      uploaderName: map['uploaderName'] ?? '',
      uploadedAt: _asDateTime(map['uploadedAt']) ?? DateTime.now(),
      downloadCount: map['downloadCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'courseCode': courseCode,
      'courseName': courseName,
      'programName': programName,
      'facultyName': facultyName,
      'level': level,
      'semester': semester,
      'year': year,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileType': fileType,
      'uploadedBy': uploadedBy,
      'uploaderName': uploaderName,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'downloadCount': downloadCount,
    };
  }
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
