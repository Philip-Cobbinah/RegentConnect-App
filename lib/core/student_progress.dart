class StudentProgress {
  static const Map<int, int> _yearsRemainingByLevel = {
    100: 4,
    200: 3,
    300: 2,
    400: 1,
  };

  static int yearsRemainingForLevel(int? level) {
    if (level == null) return 4;
    return _yearsRemainingByLevel[level] ?? 4;
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

    final level = int.tryParse(user['level']?.toString() ?? '');
    final expectedGraduationYear =
        int.tryParse(user['expectedGraduationYear']?.toString() ?? '');
    if (level == null || expectedGraduationYear == null) return false;

    final now = referenceDate ?? DateTime.now();
    return level >= 400 && now.year >= expectedGraduationYear;
  }
}
