class OfficialAccountDefinition {
  final String id;
  final String name;
  final String office;
  final String email;
  final String description;
  final String responseHours;
  final List<String> searchKeywords;

  const OfficialAccountDefinition({
    required this.id,
    required this.name,
    required this.office,
    required this.email,
    required this.description,
    required this.responseHours,
    this.searchKeywords = const [],
  });

  String get shortId => id.replaceFirst('official:', '');

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
      'about': description,
      'role': 'official',
      'isOfficial': true,
      'officialAccountId': id,
      'accountActive': linkedUser != null,
      'responseHours': responseHours,
      'session': linkedUser?['session'],
      'searchTerms':
          [name, office, email, description, ...searchKeywords].join(' '),
    };
  }
}

class OfficialAccounts {
  static const List<OfficialAccountDefinition> accounts = [
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
  ];

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
        user['role'],
        user['session'],
      ].whereType<Object>().join(' ').toLowerCase();
      return searchable.contains(normalizedQuery);
    }).toList();
  }
}
