import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../core/media_utils.dart';
import '../models/status_model.dart';
import '../models/group_model.dart';

class StatusMediaUpload {
  const StatusMediaUpload({
    required this.url,
    required this.storagePath,
    required this.contentType,
    required this.size,
  });

  final String url;
  final String storagePath;
  final String contentType;
  final int size;
}

class StatusService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String get currentUserId => _auth.currentUser?.uid ?? '';
  String get currentUserEmail => _auth.currentUser?.email ?? '';

  // Post a new status
  Future<void> postStatus({
    required String type, // 'text', 'image', 'video'
    String? text,
    String? mediaUrl,
    String? backgroundColor,
    bool allowReshare = true,
    bool isMuted = false,
    String? taggedGroupId,
    int? trimStartMs,
    int? trimEndMs,
    int? mediaDurationMs,
    String? mediaMimeType,
    String? mediaStoragePath,
    int? mediaSize,
  }) async {
    if (currentUserId.isEmpty) return;

    // Get user data
    final userDoc =
        await _firestore.collection('users').doc(currentUserId).get();
    final userData = userDoc.data() ?? {};

    final statusId =
        '${currentUserId}_${DateTime.now().millisecondsSinceEpoch}';
    final expiresAt = DateTime.now().add(const Duration(hours: 24));
    GroupModel? taggedGroup;
    if (taggedGroupId != null) {
      final groupDocument =
          await _firestore.collection('groups').doc(taggedGroupId).get();
      if (!groupDocument.exists) {
        throw Exception('The selected group or channel no longer exists.');
      }
      taggedGroup = GroupModel.fromMap({
        ...groupDocument.data()!,
        'id': groupDocument.id,
      });
      if (!taggedGroup.members.contains(currentUserId)) {
        throw Exception('You can only tag a group or channel you joined.');
      }
      if (!taggedGroup.canTagOnStatus(currentUserId)) {
        throw Exception(
          'An admin has disabled member status tags for ${taggedGroup.name}.',
        );
      }
    }

    final statusData = {
      'statusId': statusId,
      'userId': currentUserId,
      'userName': userData['fullName'] ??
          userData['displayName'] ??
          userData['email'] ??
          'Unknown',
      'userPhoto': userData['photoUrl'],
      'type': type,
      'text': text,
      'mediaUrl': mediaUrl,
      'backgroundColor': backgroundColor ?? '#7C4DFF',
      'allowReshare': allowReshare,
      'isMuted': isMuted,
      'trimStartMs': trimStartMs,
      'trimEndMs': trimEndMs,
      'mediaDurationMs': mediaDurationMs,
      'mediaMimeType': mediaMimeType,
      'mediaStoragePath': mediaStoragePath,
      'mediaSize': mediaSize,
      'taggedGroupId': taggedGroup?.id,
      'taggedGroupName': taggedGroup?.name,
      'taggedGroupKind': taggedGroup?.kind,
      'taggedGroup': taggedGroup == null
          ? null
          : {
              'id': taggedGroup.id,
              'name': taggedGroup.name,
              'kind': taggedGroup.kind,
            },
      'views': [],
      'viewCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
    };

    await _firestore.collection('statuses').doc(statusId).set(statusData);
  }

  Stream<QuerySnapshot> getMyGroupsForStatus() {
    return _firestore
        .collection('groups')
        .where('members', arrayContains: currentUserId)
        .snapshots();
  }

  Future<StatusMediaUpload?> uploadStatusMedia(
    Uint8List bytes, {
    required String type,
    required String originalName,
    String? contentType,
  }) async {
    try {
      if (currentUserId.isEmpty || bytes.isEmpty) return null;
      final safeName = MediaUtils.sanitizeFileName(
        originalName,
        fallback: type,
      );
      final resolvedContentType = contentType ??
          MediaUtils.contentTypeForName(
            originalName,
            fallback: type == 'video' ? 'video/mp4' : 'image/jpeg',
          );
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${safeName.isEmpty ? type : safeName}';
      final ref =
          _storage.ref().child('status_media/$currentUserId/$type/$fileName');
      await ref.putData(
        bytes,
        SettableMetadata(
          contentType: resolvedContentType,
          customMetadata: {
            'uploaderUid': currentUserId,
            'mediaType': type,
            'originalName': originalName,
          },
        ),
      );
      return StatusMediaUpload(
        url: await ref.getDownloadURL(),
        storagePath: ref.fullPath,
        contentType: resolvedContentType,
        size: bytes.length,
      );
    } catch (e) {
      debugPrint('Error uploading status media: $e');
      return null;
    }
  }

  // Get all active statuses (not expired)
  Stream<QuerySnapshot> getAllStatuses() {
    final now = Timestamp.now();
    return _firestore
        .collection('statuses')
        .where('expiresAt', isGreaterThan: now)
        .orderBy('expiresAt')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get statuses grouped by user
  Future<Map<String, List<Map<String, dynamic>>>>
      getStatusesGroupedByUser() async {
    final now = Timestamp.now();
    final snapshot = await _firestore
        .collection('statuses')
        .where('expiresAt', isGreaterThan: now)
        .orderBy('expiresAt')
        .orderBy('createdAt', descending: true)
        .get();

    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final userId = data['userId'] as String;
      if (!grouped.containsKey(userId)) {
        grouped[userId] = [];
      }
      grouped[userId]!.add(data);
    }

    return grouped;
  }

  // Get current user's statuses
  Stream<QuerySnapshot> getMyStatuses() {
    final now = Timestamp.now();
    return _firestore
        .collection('statuses')
        .where('userId', isEqualTo: currentUserId)
        .where('expiresAt', isGreaterThan: now)
        .orderBy('expiresAt')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<List<StatusModel>> getActiveStatuses() {
    return getAllStatuses().map(
      (snapshot) => snapshot.docs
          .map(
            (doc) => StatusModel.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ),
          )
          .toList(),
    );
  }

  Stream<int> getUnreadStatusCount() {
    return getActiveStatuses().map((statuses) => statuses.where((status) {
          return status.postedBy != currentUserId &&
              !status.viewedBy.contains(currentUserId);
        }).length);
  }

  // View a status (add current user to views)
  Future<void> viewStatus(String statusId) async {
    if (currentUserId.isEmpty) return;

    final statusRef = _firestore.collection('statuses').doc(statusId);
    final userDoc =
        await _firestore.collection('users').doc(currentUserId).get();
    final userData = userDoc.data() ?? {};
    final viewData = {
      'userId': currentUserId,
      'userName': userData['fullName'] ?? userData['email'] ?? 'Unknown',
      'userPhoto': userData['photoUrl'],
      'viewedAt': Timestamp.now(),
    };
    final viewerReference = statusRef.collection('viewers').doc(currentUserId);

    await _firestore.runTransaction((transaction) async {
      final statusDocument = await transaction.get(statusRef);
      final viewerDocument = await transaction.get(viewerReference);
      if (!statusDocument.exists || viewerDocument.exists) return;
      final data = statusDocument.data()!;
      final views = List<Map<String, dynamic>>.from(data['views'] ?? []);
      views.add(viewData);
      transaction.set(viewerReference, viewData);
      transaction.update(statusRef, {
        'views': views,
        'viewCount': views.length,
      });
    });
  }

  // Get viewers of a status
  Future<List<Map<String, dynamic>>> getStatusViewers(String statusId) async {
    final doc = await _firestore.collection('statuses').doc(statusId).get();
    if (!doc.exists) return [];

    final data = doc.data()!;
    return List<Map<String, dynamic>>.from(data['views'] ?? []);
  }

  Future<Map<String, dynamic>?> getStatus(String statusId) async {
    if (statusId.isEmpty) return null;
    final snapshot =
        await _firestore.collection('statuses').doc(statusId).get();
    if (!snapshot.exists) return null;
    return {
      ...(snapshot.data() ?? <String, dynamic>{}),
      'statusId': snapshot.id,
    };
  }

  Future<bool> toggleLikeStatus(String statusId) async {
    if (currentUserId.isEmpty) return false;
    final reference = _firestore.collection('statuses').doc(statusId);
    return _firestore.runTransaction((transaction) async {
      final document = await transaction.get(reference);
      if (!document.exists) return false;
      final data = document.data()!;
      final likedBy = List<String>.from(data['likedBy'] ?? const <String>[]);
      final isLiked = likedBy.contains(currentUserId);
      if (isLiked) {
        likedBy.remove(currentUserId);
      } else {
        likedBy.add(currentUserId);
      }
      transaction.update(reference, {'likedBy': likedBy});
      return !isLiked;
    });
  }

  // Reshare a status
  Future<void> reshareStatus(String originalStatusId) async {
    if (currentUserId.isEmpty) return;

    final originalDoc =
        await _firestore.collection('statuses').doc(originalStatusId).get();
    if (!originalDoc.exists) return;

    final originalData = originalDoc.data()!;

    // Check if reshare is allowed
    if (originalData['allowReshare'] != true) {
      throw Exception('This status cannot be reshared');
    }

    // Get current user data
    final userDoc =
        await _firestore.collection('users').doc(currentUserId).get();
    final userData = userDoc.data() ?? {};

    final statusId =
        '${currentUserId}_${DateTime.now().millisecondsSinceEpoch}';
    final expiresAt = DateTime.now().add(const Duration(hours: 24));

    final resharedStatus = {
      'statusId': statusId,
      'userId': currentUserId,
      'userName': userData['fullName'] ?? userData['email'] ?? 'Unknown',
      'userPhoto': userData['photoUrl'],
      'type': originalData['type'],
      'text': originalData['text'],
      'mediaUrl': originalData['mediaUrl'],
      'backgroundColor': originalData['backgroundColor'],
      'allowReshare': originalData['allowReshare'],
      'isMuted': originalData['isMuted'] ?? false,
      'trimStartMs': originalData['trimStartMs'],
      'trimEndMs': originalData['trimEndMs'],
      'mediaDurationMs': originalData['mediaDurationMs'],
      'mediaMimeType': originalData['mediaMimeType'],
      'mediaStoragePath': originalData['mediaStoragePath'],
      'mediaSize': originalData['mediaSize'],
      'isReshared': true,
      'originalStatusId': originalStatusId,
      'originalUserId': originalData['userId'],
      'originalUserName': originalData['userName'],
      'taggedGroupId': originalData['taggedGroupId'],
      'taggedGroupName': originalData['taggedGroupName'],
      'taggedGroupKind': originalData['taggedGroupKind'],
      'taggedGroup': originalData['taggedGroup'],
      'views': [],
      'viewCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
    };

    await _firestore.collection('statuses').doc(statusId).set(resharedStatus);
  }

  // Delete a status
  Future<void> deleteStatus(String statusId) async {
    final reference = _firestore.collection('statuses').doc(statusId);
    final document = await reference.get();
    final data = document.data();
    if (data == null) return;
    final storagePath = data['mediaStoragePath']?.toString();
    await reference.delete();

    if (storagePath != null && storagePath.isNotEmpty) {
      final otherReferences = await _firestore
          .collection('statuses')
          .where('mediaStoragePath', isEqualTo: storagePath)
          .limit(1)
          .get();
      if (otherReferences.docs.isEmpty) {
        try {
          await _storage.ref().child(storagePath).delete();
        } on FirebaseException catch (error) {
          if (error.code != 'object-not-found') rethrow;
        }
      }
    }
  }

  // Update reshare settings
  Future<void> updateReshareSettings(String statusId, bool allowReshare) async {
    await _firestore.collection('statuses').doc(statusId).update({
      'allowReshare': allowReshare,
    });
  }
}
