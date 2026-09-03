class OfficialAccountDefinition {
  final String id;
  final String name;
  final String office;
  final String email;
  final String description;
  final String responseHours;
  final List<String> searchKeywords;
  final String? faculty;
  final bool isDepartmentHead;

  const OfficialAccountDefinition({
    required this.id,
    required this.name,
    required this.office,
    required this.email,
    required this.description,
    required this.responseHours,
    this.searchKeywords = const [],
    this.faculty,
    this.isDepartmentHead = false,
  });

  String get shortId => id.replaceFirst('official:', '');

  String get iconKey {
    if (id == 'official:canteen') return 'restaurant';
    if (id == 'official:academic-unit') return 'menu_book';
    if (id == 'official:registrar') return 'badge';
    if (id == 'official:finance') return 'payments';
    if (id == 'official:admissions') return 'school';
    if (id.startsWith('official:hod-')) return 'groups';
    return 'support_agent';
  }

  Map<String, dynamic> toFirestoreMap({
    String? linkedAuthUid,
    bool active = false,
  }) {
    return {
      'id': id,
      'chatIdentity': id,
      'name': name,
      'office': office,
      'email': email,
      'description': description,
      'responseHours': responseHours,
      'faculty': faculty,
      'isDepartmentHead': isDepartmentHead,
      'isVerified': true,
      'active': active,
      'linkedAuthUid': linkedAuthUid,
      'accessMode': 'firebase_auth',
      'searchKeywords': searchKeywords,
    };
  }

  Map<String, dynamic> toDirectoryMap({
    Map<String, dynamic>? linkedUser,
    String? authUid,
  }) {
    return {
      ...?linkedUser,
      'uid': id,
      'userId': id,
      'chatIdentity': id,
      'authUid': authUid,
      'email': email,
      'displayName': name,
      'fullName': name,
      'program': office,
      'department': office,
      'faculty': faculty,
      'about': description,
      'role': 'official',
      'isOfficial': true,
      'officialAccountId': id,
      'isDepartmentHead': isDepartmentHead,
      'accountActive': linkedUser != null,
      'responseHours': responseHours,
      'session': linkedUser?['session'],
      'searchTerms':
          [name, office, email, description, ...searchKeywords].join(' '),
    };
  }
}

class OfficialAccounts {
  static const List<OfficialAccountDefinition> administrativeAccounts = [
    OfficialAccountDefinition(
      id: 'official:admissions',
      name: 'admissions@regent.edu.gh',
      office: 'Admissions Office',
      email: 'admissions@regent.edu.gh',
      description:
          'Application, admission requirements, enrolment and applicant support.',
      responseHours: 'Monday-Friday, 8:00 AM-5:00 PM',
      searchKeywords: [
        'application',
        'admission',
        'admissions',
        'apply',
        'enrolment',
        'requirements',
      ],
    ),
    OfficialAccountDefinition(
      id: 'official:registrar',
      name: 'registrar@regent.edu.gh',
      office: 'Registrar Office',
      email: 'registrar@regent.edu.gh',
      description:
          'Registration, student records, letters, transcripts and graduation support.',
      responseHours: 'Monday-Friday, 8:00 AM-5:00 PM',
      searchKeywords: [
        'registration',
        'records',
        'transcript',
        'graduation',
        'letter',
      ],
    ),
    OfficialAccountDefinition(
      id: 'official:academic-unit',
      name: 'academics@regent.edu.gh',
      office: 'Academic Affairs',
      email: 'academics@regent.edu.gh',
      description:
          'Academic programmes, course registration, timetables and academic guidance.',
      responseHours: 'Monday-Friday, 8:00 AM-5:00 PM',
      searchKeywords: [
        'exam',
        'exams',
        'examination',
        'assessment',
        'assessments',
        'results',
        'grades',
        'course',
        'timetable',
      ],
    ),
    OfficialAccountDefinition(
      id: 'official:finance',
      name: 'accounts@regent.edu.gh',
      office: 'Finance and Accounts Office',
      email: 'accounts@regent.edu.gh',
      description:
          'Fees, payment confirmation, statements and student account support.',
      responseHours: 'Monday-Friday, 8:00 AM-5:00 PM',
      searchKeywords: [
        'fee',
        'fees',
        'payment',
        'payments',
        'accounts',
        'statement',
      ],
    ),
    OfficialAccountDefinition(
      id: 'official:ess-client-assurance',
      name: 'ess@regent.edu.gh',
      office: 'ESS / Client Assurance',
      email: 'ess@regent.edu.gh',
      description:
          'Student services, client assurance, complaints and general support.',
      responseHours: 'Monday-Friday, 8:00 AM-5:00 PM',
      searchKeywords: [
        'support',
        'complaint',
        'complaints',
        'student services',
        'assurance',
      ],
    ),
    OfficialAccountDefinition(
      id: 'official:src',
      name: 'src@regent.edu.gh',
      office: 'Student Parliament / SRC',
      email: 'src@regent.edu.gh',
      description:
          'Student representation, welfare concerns, campus feedback and advocacy.',
      responseHours: 'Monday-Friday, 8:00 AM-5:00 PM',
      searchKeywords: [
        'student parliament',
        'src',
        'students representative council',
        'welfare',
        'representation',
        'advocacy',
        'student concerns',
      ],
    ),
    OfficialAccountDefinition(
      id: 'official:canteen',
      name: 'Regent Canteen',
      office: 'Regent Canteen and Campus Food Vendors',
      email: 'regentcanteen@gmail.com',
      description: 'Meal pre-orders, pickup times, campus delivery and order enquiries.',
      responseHours: 'Monday-Saturday, 8:00 AM-6:00 PM',
      searchKeywords: ['canteen', 'food', 'jollof', 'fried rice', 'delivery', 'order', 'momo'],
    ),
  ];

  static final List<OfficialAccountDefinition> facultyHeads = [
    _facultyHead(
      id: 'official:hod-computing-it',
      name: 'Faculty HoD – Computing & IT Programmes',
      office: 'Computing & Information Technology Programmes',
      email: 'hod.computing-it@regent.edu.gh',
      faculty: 'School of Engineering, Computing and Allied Sciences',
      programmes: const [
        'Information Technology',
        'Computer Science',
        'Information Systems Sciences',
      ],
    ),
    _facultyHead(
      id: 'official:hod-engineering',
      name: 'Faculty HoD – Engineering Programmes',
      office: 'Engineering Programmes',
      email: 'hod.engineering@regent.edu.gh',
      faculty: 'School of Engineering, Computing and Allied Sciences',
      programmes: const [
        'Computer Engineering',
        'Instrumentation Engineering',
        'Telecommunication Engineering',
        'Applied Electronics and Systems Engineering',
      ],
    ),
    _facultyHead(
      id: 'official:hod-business',
      name: 'Faculty HoD – Business Programmes',
      office: 'Business, Leadership and Legal Studies Programmes',
      email: 'hod.business@regent.edu.gh',
      faculty: 'School of Business, Leadership and Legal Studies',
      programmes: const ['Accounting', 'Banking and Finance', 'Business Administration', 'Economics', 'Management', 'Marketing', 'Human Resource Management', 'Procurement', 'Law'],
    ),
    _facultyHead(
      id: 'official:hod-arts-sciences',
      name: 'Faculty HoD – Arts & Sciences Programmes',
      office: 'Arts and Sciences Programmes',
      email: 'hod.arts-sciences@regent.edu.gh',
      faculty: 'Faculty of Arts and Sciences',
      programmes: const ['Psychology', 'Statistics', 'Sustainability', 'Social Sciences', 'Theology with Management'],
    ),
    _facultyHead(
      id: 'official:hod-theology-ministry',
      name: 'Faculty HoD – Theology & Ministry Programmes',
      office: 'Theology and Ministry Programmes',
      email: 'hod.theology-ministry@regent.edu.gh',
      faculty: 'School of Theology and Ministry',
      programmes: const ['Theology', 'Ministry', 'Pentecostal Studies', 'Graduate Theology'],
    ),
  ];

  static final List<OfficialAccountDefinition> accounts = [
    ...administrativeAccounts,
    ...facultyHeads,
  ];

  static List<OfficialAccountDefinition> facultyHeadsForSchool(
    String faculty,
  ) =>
      facultyHeads.where((account) => account.faculty == faculty).toList();

  static OfficialAccountDefinition _facultyHead({
    required String id,
    required String name,
    required String office,
    required String email,
    required String faculty,
    required List<String> programmes,
  }) =>
      OfficialAccountDefinition(
        id: id,
        name: name,
        office: office,
        email: email,
        description:
            'Supports ${programmes.join(', ')}. Contact this faculty HoD for course enquiries, programme changes, academic advice and other programme-related student matters.',
        responseHours: 'Monday-Friday, 8:00 AM-5:00 PM',
        faculty: faculty,
        isDepartmentHead: true,
        searchKeywords: [
          'hod',
          'faculty hod',
          'course enquiry',
          'programme change',
          ...programmes,
        ],
      );

  static OfficialAccountDefinition? byId(String? id) {
    if (id == null) return null;
    for (final account in accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  static OfficialAccountDefinition? byEmail(String? email) {
    if (email == null) return null;
    final normalizedEmail = email.trim().toLowerCase();
    for (final account in accounts) {
      if (account.email.toLowerCase() == normalizedEmail) return account;
    }
    return null;
  }

  static bool isOfficialIdentity(String? identity) {
    return identity != null && byId(identity) != null;
  }

  static String messagingIdentity({
    required String uid,
    String? email,
    String? officialAccountId,
  }) {
    return byId(officialAccountId)?.id ?? byEmail(email)?.id ?? uid;
  }

  static List<Map<String, dynamic>> mergeDirectory(
    Iterable<Map<String, dynamic>> firestoreUsers,
  ) {
    final regularUsers = <Map<String, dynamic>>[];
    final linkedOfficials = <String, Map<String, dynamic>>{};

    for (final rawUser in firestoreUsers) {
      final user = Map<String, dynamic>.from(rawUser);
      final authUid =
          (user['authUid'] ?? user['uid'] ?? user['documentId'] ?? '')
              .toString();
      final official = byId(user['officialAccountId']?.toString()) ??
          byEmail(user['email']?.toString());

      if (official != null) {
        linkedOfficials[official.id] = {
          ...user,
          'authUid': authUid,
        };
        continue;
      }

      final displayName =
          (user['fullName'] ?? user['displayName'] ?? user['email'] ?? 'User')
              .toString();
      regularUsers.add({
        ...user,
        'uid': authUid,
        'userId': authUid,
        'authUid': authUid,
        'chatIdentity': authUid,
        'displayName': displayName,
        'fullName': displayName,
        'isOfficial': false,
      });
    }

    final officialUsers = accounts.map((account) {
      final linkedUser = linkedOfficials[account.id];
      return account.toDirectoryMap(
        linkedUser: linkedUser,
        authUid: linkedUser?['authUid']?.toString(),
      );
    });

    return [...officialUsers, ...regularUsers];
  }

  static List<Map<String, dynamic>> search(
    Iterable<Map<String, dynamic>> directory,
    String query,
  ) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return directory.toList();

    return directory.where((user) {
      final searchable = [
        user['fullName'],
        user['displayName'],
        user['email'],
        user['program'],
        user['department'],
        user['office'],
        user['searchTerms'],
        user['role'],
        user['session'],
      ].whereType<Object>().join(' ').toLowerCase();
      return searchable.contains(normalizedQuery);
    }).toList();
  }
}
