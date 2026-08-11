import 'package:cloud_firestore/cloud_firestore.dart';

class StudentProgress {
  static const Map<int, int> _yearsRemainingByLevel = {
    100: 4,
    200: 3,
    300: 2,
    400: 1,
  };

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) {
      return value.toDate();
    }

    final parsed = DateTime.tryParse(value.toString());
    return parsed;
  }

  static int yearsRemainingForLevel(int? level) {
    if (level == null) return 4;
    return _yearsRemainingByLevel[level] ?? 4;
  }

  static int yearsRemainingForProfile(
    Map<String, dynamic>? user, {
    DateTime? referenceDate,
  }) {
    if (user == null) return 4;

    if (isAlumniProfile(user, referenceDate: referenceDate)) {
      return 0;
    }

    final explicitRemaining =
        int.tryParse(user['studyYearsRemaining']?.toString() ?? '');
    if (explicitRemaining != null) {
      return explicitRemaining < 0 ? 0 : explicitRemaining;
    }

    final level = int.tryParse(user['level']?.toString() ?? '');
    final expectedGraduationYear =
        int.tryParse(user['expectedGraduationYear']?.toString() ?? '');

    if (expectedGraduationYear != null) {
      final now = referenceDate ?? DateTime.now();
      final remainingYears = expectedGraduationYear - now.year;
      if (remainingYears > 0) return remainingYears;
      if (remainingYears <= 0) return 0;
    }

    return yearsRemainingForLevel(level);
  }

  static int expectedGraduationYearForLevel(
    int? level, {
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    return now.year + yearsRemainingForLevel(level);
  }

  static Map<String, dynamic> graduationMetadataForLevel(
    int? level, {
    DateTime? referenceDate,
  }) {
    final yearsRemaining = yearsRemainingForLevel(level);
    final expectedGraduationYear = expectedGraduationYearForLevel(
      level,
      referenceDate: referenceDate,
    );
    return {
      'studyYearsRemaining': yearsRemaining,
      'expectedGraduationYear': expectedGraduationYear,
      'graduationStatus':
          yearsRemaining == 1 ? 'final-year' : 'in-progress',
      'isAlumni': false,
    };
  }

  static bool isAlumniProfile(
    Map<String, dynamic>? user, {
    DateTime? referenceDate,
  }) {
    if (user == null) return false;

    final status = user['graduationStatus']?.toString().toLowerCase();
    if (status == 'completed' || status == 'graduated') return true;
    if (user['isAlumni'] == true) return true;

    final now = referenceDate ?? DateTime.now();

    final completionDate = _parseDate(
      user['graduationDate'] ??
          user['completionDate'] ??
          user['completedAt'] ??
          user['graduatedAt'],
    );
    if (completionDate != null &&
        (completionDate.isBefore(now) ||
            completionDate.isAtSameMomentAs(now))) {
      return true;
    }

    final studyYearsRemaining =
        int.tryParse(user['studyYearsRemaining']?.toString() ?? '');
    if (studyYearsRemaining != null && studyYearsRemaining <= 0) {
      return true;
    }

    final level = int.tryParse(user['level']?.toString() ?? '');
    final expectedGraduationYear =
        int.tryParse(user['expectedGraduationYear']?.toString() ?? '');
    if (level == null || expectedGraduationYear == null) return false;

    return level >= 400 && now.year >= expectedGraduationYear;
  }
}
