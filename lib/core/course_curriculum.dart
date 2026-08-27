part 'course_curriculum_imported.dart';

class CourseData {
  final String code;
  final String name;
  final int level;
  final int semester;
  final int creditHours;
  final bool isElective;

  const CourseData({
    required this.code,
    required this.name,
    required this.level,
    required this.semester,
    this.creditHours = 3,
    this.isElective = false,
  });
}

List<CourseData> curriculumFromRows(String rows) {
  return rows.trim().split('\n').where((row) => row.trim().isNotEmpty).map((row) {
    final values = row.split('|');
    if (values.length != 6) {
      throw FormatException('Invalid curriculum row: $row');
    }
    return CourseData(
      level: int.parse(values[0]),
      semester: int.parse(values[1]),
      code: values[2],
      name: values[3],
      creditHours: int.parse(values[4]),
      isElective: values[5] == 'elective',
    );
  }).toList(growable: false);
}

final Map<String, List<CourseData>> programmeCurricula = {
  ...importedProgrammeCurricula,
  'BSc. Information Technology': curriculumFromRows('''
100|1|SOED 1533|Introduction to Academic Writing|3|required
100|1|SOGE 1573|Studies in African Development I|3|required
100|1|LAFR 1513|French Language I|3|required
100|1|SICS 1573|Principles of Programming|3|required
100|1|SICS 1533|Foundation of Computer Science|3|required
100|1|SIMS 1572|Linear Algebra|3|required
100|2|SICS 1523|Object Oriented Programming|3|required
100|2|SICS 1543|Digital Computer Fundamental|3|required
100|2|SOGE 1583|Logic & Reasoning|3|required
100|2|SICS 1632|Introduction to Computer Hardware|3|required
100|2|SIIS 1731|Office Applications Lab|3|required
100|2|SIMS 1623|Discrete and Continuous Mathematics|3|required
200|1|SIIS 2573|Application Programming with C# I|3|required
200|1|SIIS 2513|Internet Programming I|3|required
200|1|SICS 2533|Data Communication & Networks I|3|required
200|1|SICS 2583|Operating Systems|3|required
200|1|SIMS 3533|Introduction to Probability & Statistics|3|required
200|1|SIIS 2553|Database Systems I|3|required
200|1|SOMA 1533|Introduction to Management|3|required
200|2|SIIS 2583|Application Programming with C# II|3|required
200|2|SIIS 2543|Internet Programming II|3|required
200|2|SICS 2543|Data Communication & Networks II|3|required
200|2|SICS 3653|E-commerce Technology|3|required
200|2|SICS 3643|Principles of Software Engineering|3|required
200|2|SIIS 2563|Database Systems II|3|required
200|2|SICS 2643|Computer Architecture & Microprocessor|3|required
300|1|SICS 3513|Human Computer Interactions|3|required
300|1|SICS 3773|Research Methods|3|required
300|1|SICS 3883|Mobile Application Development|3|required
300|1|SICS 4583|Multimedia Systems & Web Engineering|3|required
300|1|SIIS 3743|Geographical Information System I|3|required
300|1|SOMA 3513|Entrepreneurship & Innovations|3|required
300|1|SIIS 4523|Knowledge Management|3|required
300|2|SICS 3633|Network Management and System Administration|3|required
300|2|SICS 3523|Project Management for Information System|3|required
300|2|SIIS 3513|Strategic Disposition to Information Management|3|required
300|2|SIIS 3563|Object Oriented Analysis & Design|3|required
300|2|SICS 3623|Cyber Law and Ethical Issues in IS|3|required
300|2|SIIS 3753|Geographical Information System II|3|required
300|2|SICS 3823|Team Software Development and Technical Report Writing|3|required
400|1|SICS 4513|Artificial Intelligence & Expert Systems|3|required
400|1|SICS 4673|Management Information Systems|3|required
400|1|SIIS 4503|IS Dissertation/Project I|3|required
400|1|SICS 4693|Computer Security|3|required
400|1|SICS 4733|Cloud Computing Fundamentals|3|required
400|1|SOGE 4553|Studies in African Development II|3|required
400|2|SIIS 3733|Information Systems Management|3|required
400|2|SICS 4823|Computer Forensics|3|required
400|2|SIIS 4543|Information System Safety|3|required
400|2|SIIS 4603|IS Dissertation/Project II|3|required
400|2|SICS 4863|Spreadsheet Modelling for Business Decisions|3|required
'''),
  'BSc. Computer Science': curriculumFromRows('''
100|1|SOED 1533|Introduction to Academic Writing|3|required
100|1|SOGE 1573|Studies in African Development I|3|required
100|1|LAFR 1513|French Language I|3|required
100|1|SICS 1573|Principles of Programming|3|required
100|1|SICS 1533|Foundation of Computer Science|3|required
100|1|SIMS 1572|Linear Algebra|3|required
100|2|SICS 1523|Object Oriented Programming|3|required
100|2|SICS 1543|Digital Computer Fundamental|3|required
100|2|SOGE 1583|Logic & Reasoning|3|required
100|2|SICS 1632|Introduction to Computer Hardware|3|required
100|2|SIMS 1623|Discrete and Continuous Mathematics|3|required
100|2|SIMS 1633|Calculus I|3|required
100|2|SIIS 1731|Office Applications Lab|3|required
200|1|SICS 2583|Operating Systems|3|required
200|1|SICS 2533|Data Communication & Networks I|3|required
200|1|SICS 2533|Computer Organization|3|required
200|1|SICS 2613|Java Programming|3|required
200|1|SIMS 3533|Introduction to Probability & Statistics|3|required
200|1|SIIS 2553|Database Systems I|3|required
200|1|SIMS 1643|Calculus II|3|required
200|2|SICS 2563|Numerical Methods|3|required
200|2|SICS 2643|Computer Architecture & Micro-Processor|3|required
200|2|SICS 2543|Data Communication & Networks II|3|required
200|2|SICS 3653|E-commerce & E-business|3|required
200|2|SICS 3643|Principles of Software Engineering|3|required
200|2|SIIS 2563|Database Systems II|3|required
200|2|SICS 2643|Computer Architecture & Microprocessor|3|required
300|1|SICS 3513|Human Computer Interactions|3|required
300|1|SICS 3773|Research Methods|3|required
300|1|SICS 3883|Mobile Application Development|3|required
300|1|SICS 4583|Multimedia Systems & Web Engineering|3|required
300|1|SICS 3732|Operations Research|2|required
300|1|SOMA 3513|Entrepreneurship & Innovations|3|required
300|1|SICS 4683|Visual Programming|3|required
300|2|SICS 3633|Network Management and System Administration|3|required
300|2|SICS 3523|Project Management for Information System|3|required
300|2|SICS 3543|Principles of Compiler Design|3|required
300|2|SIIS 3563|Object Oriented Analysis & Design|3|required
300|2|SICS 39833|Introduction to Data Science|3|required
300|2|SICS 3853|Ethical Hacking|3|required
300|2|SICS 3823|Team Software Development and Technical Report Writing|3|required
400|1|SICS 4513|Artificial Intelligence & Expert Systems|3|required
400|1|SICS 4673|Management Information Systems|3|required
400|1|SICS 4503|Computer Science Project I|3|required
400|1|SICS 4693|Computer Security|3|required
400|1|SICS 4733|Cloud Computing Fundamentals|3|required
400|1|SOGE 4553|Studies in African Development II|3|required
400|2|SICS 4603|Computer Science Project II|3|required
400|2|SICS 4823|Computer Forensics|3|required
400|2|SICS 4873|Mathematical Modeling and Simulation|3|required
400|2|SICS 4643|Networks & Telecommunications|3|required
400|2|SICS 3663|Cyber Law and Ethical Issues in Information Systems|3|required
400|2|GSGR 4500|Development of Business Portfolio|3|required
'''),
};

List<CourseData> coursesForProgram(String programName) =>
    programmeCurricula[programName] ?? const <CourseData>[];
