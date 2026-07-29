import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regent_connect/core/official_accounts.dart';
import 'package:regent_connect/models/group_model.dart';
import 'package:regent_connect/models/status_model.dart';

void main() {
  test('StatusModel reads the schema written by StatusService', () {
    final createdAt = DateTime(2026, 7, 26, 12);
    final expiresAt = createdAt.add(const Duration(hours: 24));

    final status = StatusModel.fromMap(
      {
        'userId': 'user-1',
        'userName': 'Regent Student',
        'userPhoto': 'https://example.com/photo.jpg',
        'type': 'text',
        'text': 'Hello Regent',
        'createdAt': Timestamp.fromDate(createdAt),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'views': [
          {'userId': 'viewer-1'},
        ],
      },
      'status-1',
    );

    expect(status.id, 'status-1');
    expect(status.postedBy, 'user-1');
    expect(status.posterName, 'Regent Student');
    expect(status.content, 'Hello Regent');
    expect(status.viewedBy, ['viewer-1']);
    expect(status.createdAt, createdAt);
    expect(status.expiresAt, expiresAt);
  });

  test('Official accounts use a stable messaging identity', () {
    expect(
      OfficialAccounts.messagingIdentity(
        uid: 'firebase-user-id',
        email: 'Admissions@Regent.edu.gh',
      ),
      'official:admissions',
    );
    expect(OfficialAccounts.accounts.length, 5);
  });

  test('Official account keywords support responsibility-based search', () {
    final academic = OfficialAccounts.byId('official:academic-unit')!;
    final directoryEntry = academic.toDirectoryMap();

    expect(academic.searchKeywords, contains('exam'));
    expect(directoryEntry['searchTerms'].toString().toLowerCase(),
        contains('exam'));
  });

  test('Official directory merges a linked staff login without duplicates', () {
    final directory = OfficialAccounts.mergeDirectory([
      {
        'documentId': 'staff-auth-id',
        'email': 'registrar@regent.edu.gh',
        'isOnline': true,
      },
      {
        'documentId': 'student-id',
        'email': 'student@regent.edu.gh',
        'fullName': 'Regent Student',
      },
    ]);

    final registrar = directory
        .where((user) => user['chatIdentity'] == 'official:registrar')
        .single;
    expect(registrar['authUid'], 'staff-auth-id');
    expect(registrar['isOfficial'], isTrue);
    expect(
      directory
          .where((user) => user['chatIdentity'] == 'official:registrar')
          .length,
      1,
    );
    expect(
      directory.any((user) => user['chatIdentity'] == 'student-id'),
      isTrue,
    );
  });

  test('Group and channel permissions apply safe defaults', () {
    final oldGroup = GroupModel.fromMap({
      'id': 'group-1',
      'name': 'Study Group',
      'createdBy': 'admin',
      'creatorName': 'Admin',
      'createdAt': DateTime(2026, 7, 27),
      'members': ['admin', 'member'],
    });
    expect(oldGroup.allowMemberStatusTagging, isTrue);
    expect(oldGroup.canTagOnStatus('member'), isTrue);
    expect(oldGroup.canPost('member'), isTrue);

    final channel = GroupModel(
      id: 'channel-1',
      name: 'News',
      createdBy: 'admin',
      creatorName: 'Admin',
      createdAt: DateTime(2026, 7, 27),
      members: const ['admin', 'member'],
      kind: 'channel',
      allowMemberStatusTagging: false,
    );
    expect(channel.canPost('member'), isFalse);
    expect(channel.canPost('admin'), isTrue);
    expect(channel.canTagOnStatus('member'), isFalse);
    expect(channel.canTagOnStatus('admin'), isTrue);
  });
}
