import 'course_curriculum.dart';

export 'course_curriculum.dart' show CourseData;

class ProgramData {
  final String name;
  final List<CourseData> courses;
  final List<String>? options;

  const ProgramData({
    required this.name,
    required this.courses,
    this.options,
  });
}

class FacultyData {
  final String name;
  final List<ProgramData> programs;

  const FacultyData({
    required this.name,
    required this.programs,
  });
}

// Regent University undergraduate schools and programmes.
//
// The public site clearly surfaces the programme titles, while the full
// semester-by-semester module lists live in curriculum documents and the
// student handbook. The app keeps the structure here so those modules can be
// filled in cleanly when the official curriculum PDFs are imported.
final List<FacultyData> universityFaculties = [
  FacultyData(
    name: 'School of Engineering, Computing and Allied Sciences',
    programs: [
      ProgramData(
        name: 'BSc. Information Technology',
        courses: coursesForProgram('BSc. Information Technology'),
      ),
      ProgramData(
        name: 'BSc. Computer Science',
        courses: coursesForProgram('BSc. Computer Science'),
      ),
      ProgramData(
        name: 'BEng. Computer Engineering',
        courses: coursesForProgram('BEng. Computer Engineering'),
      ),
      ProgramData(
        name: 'BEng. Instrumentation Engineering',
        courses: coursesForProgram('BEng. Instrumentation Engineering'),
      ),
      ProgramData(
        name: 'BEng. Telecommunication Engineering',
        courses: coursesForProgram('BEng. Telecommunication Engineering'),
      ),
      ProgramData(
        name: 'BEng. Applied Electronics and Systems Engineering',
        options: const [
          'Telecommunication Option',
        ],
        courses: [],
      ),
      ProgramData(
        name: 'BSc. Information Systems Sciences',
        courses: [],
      ),
    ],
  ),
  FacultyData(
    name: 'School of Business, Leadership and Legal Studies',
    programs: [
      ProgramData(
        name: 'BSc. Accounting with Information Systems',
        courses: coursesForProgram('BSc. Accounting with Information Systems'),
      ),
      ProgramData(
        name: 'BSc. Banking and Finance',
        courses: [],
      ),
      ProgramData(
        name: 'Bachelor of Business Administration (E-Commerce)',
        courses: coursesForProgram('Bachelor of Business Administration (E-Commerce)'),
      ),
      ProgramData(
        name: 'BSc. Economics with Computing',
        courses: [],
      ),
      ProgramData(
        name: 'BSc. Management with Computing',
        options: const [
          'Marketing Management',
          'Human Resource Management',
        ],
        courses: coursesForProgram('BSc. Management with Computing'),
      ),
      ProgramData(
        name: 'BSc. Marketing',
        courses: [],
      ),
      ProgramData(
        name: 'BSc. Human Resource Management',
        courses: [],
      ),
      ProgramData(
        name: 'BSc. Procurement and Supply Chain Management',
        courses: [],
      ),
      ProgramData(
        name: 'Law-related programmes',
        courses: [],
      ),
    ],
  ),
  FacultyData(
    name: 'Faculty of Arts and Sciences',
    programs: [
      ProgramData(
        name: 'BSc. Psychology and Human Development',
        courses: [],
      ),
      ProgramData(
        name: 'BSc. Statistics',
        courses: [],
      ),
      ProgramData(
        name: 'Sustainability-related programmes',
        courses: [],
      ),
      ProgramData(
        name: 'Other social science programmes',
        courses: [],
      ),
      ProgramData(
        name: 'Bachelor of Theology with Management',
        courses: [],
      ),
    ],
  ),
  FacultyData(
    name: 'School of Theology and Ministry',
    programs: [
      ProgramData(
        name: 'Bachelor of Theology',
        courses: [],
      ),
      ProgramData(
        name: 'Ministry programmes',
        courses: [],
      ),
      ProgramData(
        name: 'Pentecostal Studies',
        courses: [],
      ),
      ProgramData(
        name: 'Graduate Theology programmes',
        courses: [],
      ),
    ],
  ),
];
