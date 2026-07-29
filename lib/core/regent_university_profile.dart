import 'package:flutter/material.dart';

class RegentInfoItem {
  const RegentInfoItem({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}

class RegentProgrammeGroup {
  const RegentProgrammeGroup({
    required this.title,
    required this.programmes,
  });

  final String title;
  final List<String> programmes;
}

class RegentStudyStream {
  const RegentStudyStream({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}

class RegentUniversityProfile {
  static const String institutionName =
      'Regent University College of Science and Technology';
  static const String shortName = 'Regent-Ghana';
  static const String motto = 'Peace, Justice and Industry';
  static const List<String> coreValues = [
    'Innovation',
    'Discipline',
    'Excellence',
    'Appreciation',
    'Speed',
  ];
  static const String established = 'September 2003';
  static const String accredited = '2004';
  static const String founderAndChancellor = 'Rev. Prof. Emmanuel Kingsley Larbi';
  static const String accreditation =
      'Ghana Tertiary Education Commission (GTEC)';
  static const String vision =
      'Raising highly skillful, visionary, ethical, and God-fearing leaders to function as change agents across the globe.';
  static const List<String> affiliations = [
    'Kwame Nkrumah University of Science and Technology (KNUST)',
    'University of Education, Winneba (UEW)',
    'Trinity Theological Seminary',
    'International partners in Germany, Canada, and Spain',
  ];

  static const List<RegentProgrammeGroup> undergraduateProgrammes = [
    RegentProgrammeGroup(
      title: 'Faculty of Engineering, Computing and Allied Science (FECAS)',
      programmes: [
        'BSc. (Hons) Computer Science',
        'BSc. (Hons) Information Technology',
        'BEng. (Hons) Applied Electronics and Systems Engineering',
        'Options: Computer Engineering, Instrumentation Engineering, Telecommunication Engineering',
      ],
    ),
    RegentProgrammeGroup(
      title: 'School of Business, Leadership and Legal Studies (SBLL)',
      programmes: [
        'BSc. (Hons) Accounting and Information Systems',
        'Bachelor of Business Administration (E-Commerce)',
        'BSc. (Hons) Management with Computing',
        'Options: Marketing Management, Human Resource Management',
      ],
    ),
    RegentProgrammeGroup(
      title: 'Faculty of Arts and Sciences (FAS)',
      programmes: [
        'BSc. (Hons) Psychology',
        'Bachelor of Theology with Management',
      ],
    ),
  ];

  static const List<RegentProgrammeGroup> postgraduateProgrammes = [
    RegentProgrammeGroup(
      title: 'Masters Programmes',
      programmes: [
        'MSc. Statistics',
        'Master of Divinity',
        'Master of Theology',
        'MSc. / MPhil. Energy and Sustainability Management',
        'MSc. Law and Corporate Administration',
        'MSc. / MPhil. Enterprise Risk and Business Transformation',
        'MSc. / MPhil. Diplomacy and International Trade',
      ],
    ),
    RegentProgrammeGroup(
      title: 'PhD Programmes',
      programmes: [
        'PhD Business Management',
        'PhD Psychology',
        'PhD Management Information Systems',
        'PhD Communication and Media Management',
        'PhD Political and International Relations',
        'PhD Educational Administration',
        'PhD Tourism and Hospitality Management',
        'PhD Law',
      ],
    ),
  ];

  static const List<RegentStudyStream> studyStreams = [
    RegentStudyStream(
      title: 'Morning Session',
      description: 'Regular daytime delivery for students who study in the morning.',
      icon: Icons.wb_sunny_rounded,
    ),
    RegentStudyStream(
      title: 'Evening Session',
      description: 'Regular evening delivery for students balancing work or daytime commitments.',
      icon: Icons.nights_stay_rounded,
    ),
    RegentStudyStream(
      title: 'Weekend Stream',
      description: 'Weekend delivery for students who prefer Saturday and Sunday classes.',
      icon: Icons.calendar_month_rounded,
    ),
  ];

  static const List<RegentInfoItem> admissions = [
    RegentInfoItem(
      title: 'Application fee rates',
      description:
          'Ghanaian Undergraduate: GHS 100\nGhanaian Graduate: GHS 120\nInternational Applicants: USD 100 (or equivalent Cedi rate)',
      icon: Icons.payments_rounded,
    ),
    RegentInfoItem(
      title: 'General entry requirement',
      description:
          'Credits in 3 Core subjects (English, Core Mathematics, Integrated Science) and 3 Elective subjects relevant to the degree programme.',
      icon: Icons.fact_check_rounded,
    ),
    RegentInfoItem(
      title: 'Post-Diploma / HND entry',
      description:
          'Eligible for direct entry into Level 200 or Level 300 based on qualification evaluation.',
      icon: Icons.school_rounded,
    ),
  ];

  static const List<RegentInfoItem> onlineServices = [
    RegentInfoItem(
      title: 'Student Cyber Campus / LMS',
      description: 'Academic portal for courses, grades, and registrations.',
      icon: Icons.laptop_mac_rounded,
    ),
    RegentInfoItem(
      title: 'Official Student Email',
      description:
          'Official webmail uses the @regent.edu.gh domain for student communication.',
      icon: Icons.mail_rounded,
    ),
    RegentInfoItem(
      title: 'Application & Payment Portal',
      description: 'Online fee and application management.',
      icon: Icons.receipt_long_rounded,
    ),
    RegentInfoItem(
      title: 'Student Handbook & GreenBook',
      description:
          'Official codes of conduct and academic policies for ESS / Client Assurance.',
      icon: Icons.menu_book_rounded,
    ),
  ];

  static const String campusAddress =
      'No. 1 Regent University Avenue, McCarthy Hill, Off Mallam-Kasoa Highway, Accra, Ghana';
  static const List<String> phoneContacts = [
    '+233 26 683 9961',
    '+233 50 303 0999',
  ];
  static const List<String> emails = [
    'admissions@regent.edu.gh',
    'info@regent.edu.gh',
  ];
  static const String website = 'https://regent.edu.gh';
  static const List<String> socialHandles = [
    'Instagram / TikTok: @regentgh_official',
    'Facebook: Regent University College of Science & Technology',
  ];
}
