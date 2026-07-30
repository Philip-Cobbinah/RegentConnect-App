import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/academic_result_model.dart';

class AcademicResultsService {
  AcademicResultsService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;

  Stream<List<AcademicResultModel>> watchStudentResults({
    required String studentId,
  }) {
    if (studentId.isEmpty) {
      return Stream<List<AcademicResultModel>>.empty();
    }

    return _firestore
        .collection('academic_results')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
      final results = snapshot.docs
          .map((doc) => AcademicResultModel.fromMap(doc.data(), doc.id))
          .toList();
      results.sort((a, b) {
        final levelCompare = a.level.compareTo(b.level);
        if (levelCompare != 0) return levelCompare;
        final semesterCompare = a.semester.compareTo(b.semester);
        if (semesterCompare != 0) return semesterCompare;
        return a.courseName.toLowerCase().compareTo(b.courseName.toLowerCase());
      });
      return results;
    });
  }

  List<AcademicResultModel> filterResults({
    required List<AcademicResultModel> results,
    int? level,
    int? semester,
    String? query,
  }) {
    final normalizedQuery = query?.trim().toLowerCase() ?? '';
    return results.where((result) {
      if (level != null && result.level != level) return false;
      if (semester != null && result.semester != semester) return false;
      if (normalizedQuery.isEmpty) return true;
      return [
        result.courseCode,
        result.courseName,
        result.grade,
        result.remarks,
        result.academicYear,
      ].whereType<String>().any(
            (value) => value.toLowerCase().contains(normalizedQuery),
          );
    }).toList();
  }

  double calculateGpa(List<AcademicResultModel> results) {
    if (results.isEmpty) return 0;
    var weightedPoints = 0.0;
    var totalCredits = 0;
    for (final result in results) {
      final credits = result.creditHours <= 0 ? 1 : result.creditHours;
      weightedPoints += result.gradePoint * credits;
      totalCredits += credits;
    }
    if (totalCredits == 0) return 0;
    return weightedPoints / totalCredits;
  }
}
