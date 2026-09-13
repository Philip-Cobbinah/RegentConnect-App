import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminService {
  AdminService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  DateTime? _lastActionAt;

  Future<void> requireAdmin() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('You must sign in first.');

    final token = await user.getIdTokenResult(true);
    if (token.claims?['role'] != 'admin') {
      throw StateError('Administrator access is required.');
    }
  }

  Future<bool> isAdmin() async {
    try {
      await requireAdmin();
      return true;
    } catch (_) {
      return false;
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAnnouncements() {
    return _firestore
        .collection('admin_announcements')
        .orderBy('createdAt', descending: true)
        .limit(25)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAuditLog() {
    return _firestore
        .collection('admin_audit_logs')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  Future<void> publishAnnouncement({
    required String title,
    required String body,
  }) async {
    await requireAdmin();
    final cleanTitle = _clean(title, maxLength: 120);
    final cleanBody = _clean(body, maxLength: 4000);
    if (cleanTitle.isEmpty || cleanBody.isEmpty) {
      throw FormatException('Title and message are required.');
    }

    final now = DateTime.now();
    if (_lastActionAt != null &&
        now.difference(_lastActionAt!) < const Duration(seconds: 2)) {
      throw StateError('Please wait before submitting another admin action.');
    }
    _lastActionAt = now;

    final user = _auth.currentUser!;
    final announcement = _firestore.collection('admin_announcements').doc();
    final audit = _firestore.collection('admin_audit_logs').doc();
    final timestamp = FieldValue.serverTimestamp();

    final batch = _firestore.batch();
    batch.set(announcement, {
      'title': cleanTitle,
      'body': cleanBody,
      'createdBy': user.uid,
      'createdByEmail': user.email,
      'createdAt': timestamp,
      'updatedAt': timestamp,
      'active': true,
    });
    batch.set(audit, {
      'actorUid': user.uid,
      'actorEmail': user.email,
      'action': 'publish_announcement',
      'targetId': announcement.id,
      'createdAt': timestamp,
    });
    await batch.commit();
  }

  String _clean(String value, {required int maxLength}) {
    final cleaned = String.fromCharCodes(
      value.codeUnits.where(
        (code) => code == 9 || code == 10 || code == 13 || code >= 32,
      ),
    ).trim();
    return cleaned.substring(0, cleaned.length.clamp(0, maxLength));
  }
}
