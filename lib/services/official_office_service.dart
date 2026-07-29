import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/official_accounts.dart';

class OfficialOfficeService {
  OfficialOfficeService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? get currentUser => _auth.currentUser;

  OfficialAccountDefinition? get currentOffice =>
      OfficialAccounts.byEmail(currentUser?.email);

  Future<bool> hasOfficerClaims({bool forceRefresh = false}) async {
    final user = currentUser;
    final office = currentOffice;
    if (user == null || office == null) return false;
    return user.email?.trim().toLowerCase() == office.email.toLowerCase();
  }

  Future<void> syncCurrentOfficerBackend() async {
    final user = currentUser;
    final office = currentOffice;
    if (user == null || office == null) return;
    if (user.email?.trim().toLowerCase() != office.email.toLowerCase()) {
      throw Exception(
        'This Regent staff account is not using the approved office email.',
      );
    }

    try {
      final now = FieldValue.serverTimestamp();
      final userReference = _firestore.collection('users').doc(user.uid);
      final officeReference =
          _firestore.collection('official_offices').doc(office.id);

      final batch = _firestore.batch();
      batch.set(
        userReference,
        {
          'uid': user.uid,
          'email': office.email,
          'displayName': office.email,
          'fullName': office.email,
          'program': office.office,
          'department': office.office,
          'role': 'official',
          'isOfficial': true,
          'officialAccountId': office.id,
          'chatIdentity': office.id,
          'about': office.description,
          'emailVerified': user.emailVerified,
          'isOnline': true,
          'lastSeen': now,
        },
        SetOptions(merge: true),
      );
      batch.set(
        officeReference,
        {
          ...office.toFirestoreMap(
            linkedAuthUid: user.uid,
            active: true,
          ),
          'lastActiveAt': now,
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );
      await batch.commit();

      await _attachOfficerUidToExistingChats(office.id, user.uid);
    } catch (error) {
      print('Officer backend sync skipped: $error');
    }
  }

  Future<void> _attachOfficerUidToExistingChats(
    String officeIdentity,
    String authUid,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('chats')
          .where('participants', arrayContains: officeIdentity)
          .get();
      final missing = snapshot.docs.where((document) {
        final ids = List<String>.from(
          document.data()['participantAuthIds'] ?? const [],
        );
        return !ids.contains(authUid);
      }).toList();

      for (var start = 0; start < missing.length; start += 400) {
        final batch = _firestore.batch();
        final end = start + 400 < missing.length ? start + 400 : missing.length;
        for (final document in missing.sublist(start, end)) {
          batch.update(document.reference, {
            'participantAuthIds': FieldValue.arrayUnion([authUid]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }
    } catch (error) {
      print('Could not attach officer UID to existing chats: $error');
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchCurrentOffice() {
    final office = currentOffice;
    if (office == null) return const Stream.empty();
    return _firestore.collection('official_offices').doc(office.id).snapshots();
  }
}
