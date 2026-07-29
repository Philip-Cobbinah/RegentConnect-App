import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../core/media_utils.dart';
import '../models/academic_post_model.dart';

class AcademicAttachmentDraft {
  final Uint8List bytes;
  final String fileName;
  final String kind;
  final String contentType;

  const AcademicAttachmentDraft({
    required this.bytes,
    required this.fileName,
    required this.kind,
    required this.contentType,
  });

  bool get isImage => kind == 'image';
  bool get isVideo => kind == 'video';
  bool get isAudio => kind == 'audio';
  bool get isFile => !isImage && !isVideo && !isAudio;
}

class AcademicAttachmentUpload {
  final String url;
  final String storagePath;
  final String fileName;
  final String kind;
  final String contentType;
  final int size;

  const AcademicAttachmentUpload({
    required this.url,
    required this.storagePath,
    required this.fileName,
    required this.kind,
    required this.contentType,
    required this.size,
  });

  AcademicAttachmentModel toModel() {
    return AcademicAttachmentModel(
      kind: kind,
      name: fileName,
      url: url,
      storagePath: storagePath,
      contentType: contentType,
      size: size,
    );
  }
}

class AcademicService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String get currentUserId => _auth.currentUser?.uid ?? '';
  String get currentUserEmail => _auth.currentUser?.email ?? '';

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAcademicPosts() {
    return _firestore
        .collection('academic_posts')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<Map<String, dynamic>?> getCurrentUserData() async {
    if (currentUserId.isEmpty) return null;
    final snapshot =
        await _firestore.collection('users').doc(currentUserId).get();
    return snapshot.data();
  }

  bool canCreateAcademicPosts(Map<String, dynamic>? userData) {
    if (userData == null) return false;
    final role = userData['role']?.toString().toLowerCase();
    return userData['isOfficial'] == true ||
        userData['academicPostPermission'] == true ||
        userData['academicPostingEnabled'] == true ||
        ['class_rep', 'lecturer', 'academic_staff', 'official'].contains(role);
  }

  Future<List<AcademicAttachmentUpload>> uploadAttachments({
    required String postId,
    required List<AcademicAttachmentDraft> attachments,
  }) async {
    if (currentUserId.isEmpty) {
      throw Exception('Please sign in before uploading academic resources.');
    }
    final uploads = <AcademicAttachmentUpload>[];

    for (final draft in attachments) {
      if (draft.bytes.isEmpty) continue;
      final safeName = MediaUtils.sanitizeFileName(draft.fileName);
      final resolvedContentType = draft.contentType.isEmpty
          ? MediaUtils.contentTypeForName(
              draft.fileName,
              fallback: 'application/octet-stream',
            )
          : draft.contentType;
      final folder = MediaUtils.folderForType(draft.kind);
      final storageRef = _storage.ref().child(
            'academic_posts/$postId/$currentUserId/$folder/'
            '${DateTime.now().millisecondsSinceEpoch}_$safeName',
          );
      final uploadTask = await storageRef.putData(
        draft.bytes,
        SettableMetadata(
          contentType: resolvedContentType,
          customMetadata: {
            'postId': postId,
            'uploaderUid': currentUserId,
            'originalName': draft.fileName,
            'mediaKind': draft.kind,
          },
        ),
      );

      uploads.add(
        AcademicAttachmentUpload(
          url: await uploadTask.ref.getDownloadURL(),
          storagePath: uploadTask.ref.fullPath,
          fileName: draft.fileName,
          kind: draft.kind,
          contentType: resolvedContentType,
          size: draft.bytes.length,
        ),
      );
    }

    return uploads;
  }

  Future<String> createAcademicPost({
    required String postType,
    required String title,
    String caption = '',
    String? courseCode,
    String? courseName,
    List<int> targetLevels = const [],
    List<String> targetPrograms = const [],
    List<String> targetCourses = const [],
    DateTime? dueAt,
    DateTime? lectureAt,
    String? authorRole,
    List<AcademicAttachmentDraft> attachments = const [],
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Sign in before publishing academic content.');
    }

    final userData = await getCurrentUserData();
    final resolvedTitle = title.trim();
    if (resolvedTitle.isEmpty) {
      throw Exception('Please add a title.');
    }
    if (!['assignment', 'lecture'].contains(postType)) {
      throw Exception('Unsupported academic post type.');
    }

    final docRef = _firestore.collection('academic_posts').doc();
    final uploadedAttachments = await uploadAttachments(
      postId: docRef.id,
      attachments: attachments,
    );

    final normalizedLevels = targetLevels.toSet().toList()..sort();
    final normalizedPrograms = targetPrograms
        .map((program) => program.trim())
        .where((program) => program.isNotEmpty)
        .toSet()
        .toList();
    final normalizedCourses = targetCourses
        .map((course) => course.trim())
        .where((course) => course.isNotEmpty)
        .toSet()
        .toList();

    await docRef.set({
      'id': docRef.id,
      'postType': postType,
      'title': resolvedTitle,
      'caption': caption.trim(),
      'authorId': user.uid,
      'authorEmail': user.email ?? currentUserEmail,
      'authorName': userData?['fullName'] ??
          userData?['displayName'] ??
          user.displayName ??
          user.email ??
          'Regent user',
      'authorPhotoUrl': userData?['photoUrl'] ?? user.photoURL,
      'authorRole': authorRole ??
          userData?['role']?.toString() ??
          (userData?['isOfficial'] == true ? 'official' : 'student'),
      'courseCode': courseCode?.trim().isNotEmpty == true
          ? courseCode!.trim().toUpperCase()
          : null,
      'courseName':
          courseName?.trim().isNotEmpty == true ? courseName!.trim() : null,
      'targetLevels': normalizedLevels,
      'targetPrograms': normalizedPrograms,
      'targetCourses': normalizedCourses,
      'attachments': uploadedAttachments
          .map((attachment) => attachment.toModel().toMap())
          .toList(),
      'dueAt': dueAt == null ? null : Timestamp.fromDate(dueAt),
      'lectureAt': lectureAt == null ? null : Timestamp.fromDate(lectureAt),
      'isPinned': false,
      'isArchived': false,
      'viewCount': 0,
      'replyCount': 0,
      'searchText': [
        resolvedTitle,
        caption,
        courseCode,
        courseName,
        ...normalizedPrograms,
        ...normalizedCourses,
        ...normalizedLevels.map((level) => 'Level $level'),
      ].whereType<String>().join(' ').toLowerCase(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  Future<void> deleteAcademicPost(String postId) async {
    final docRef = _firestore.collection('academic_posts').doc(postId);
    final doc = await docRef.get();
    final data = doc.data();
    if (data == null) return;

    final attachments =
        List<Map<String, dynamic>>.from(data['attachments'] ?? const []);
    for (final attachment in attachments) {
      final storagePath = attachment['storagePath']?.toString();
      if (storagePath == null || storagePath.isEmpty) continue;
      try {
        await _storage.ref().child(storagePath).delete();
      } on FirebaseException catch (error) {
        if (error.code != 'object-not-found') {
          rethrow;
        }
      }
    }

    await docRef.delete();
  }

  Future<AcademicPostModel?> getAcademicPost(String postId) async {
    final doc = await _firestore.collection('academic_posts').doc(postId).get();
    final data = doc.data();
    if (data == null) return null;
    return AcademicPostModel.fromMap(data, doc.id);
  }
}
