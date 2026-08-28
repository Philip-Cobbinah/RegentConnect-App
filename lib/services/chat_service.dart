import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../core/media_utils.dart';
import '../core/official_accounts.dart';
import '../core/constants.dart';
import '../models/group_model.dart';
import 'notification_service.dart';

class UploadedMedia {
  const UploadedMedia({
    required this.url,
    required this.storagePath,
    required this.originalName,
    required this.contentType,
    required this.size,
  });

  final String url;
  final String storagePath;
  final String originalName;
  final String contentType;
  final int size;
}

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final NotificationService _notificationService = NotificationService();

  String get currentUserId => _auth.currentUser?.uid ?? '';
  String get currentUserEmail => _auth.currentUser?.email ?? '';
  String get currentMessagingId => OfficialAccounts.messagingIdentity(
        uid: currentUserId,
        email: currentUserEmail,
      );

  // Get or create chat room ID between two users
  String getChatRoomId(String otherUserId) {
    List<String> ids = [currentMessagingId, otherUserId];
    ids.sort();
    return ids.join('_');
  }

  Future<void> ensureChatRoom(String otherUserId) async {
    if (currentUserId.isEmpty) {
      throw Exception('Sign in before opening a conversation.');
    }
    if (otherUserId.isEmpty || otherUserId == currentMessagingId) {
      throw Exception('Choose another user to start a conversation.');
    }
    final otherUser = await getUserData(otherUserId);
    if (otherUser == null) {
      throw Exception('This user is no longer available for messaging.');
    }
    final recipientIdentity =
        (otherUser['chatIdentity'] ?? otherUser['uid'] ?? otherUserId)
            .toString();
    if (recipientIdentity != otherUserId) {
      throw Exception('The selected user has an invalid chat identity.');
    }
    final recipientAuthId =
        (otherUser['authUid'] ??
                (OfficialAccounts.isOfficialIdentity(otherUserId)
                    ? null
                    : otherUserId))
            ?.toString();
    final chatReference =
        _firestore.collection(AppConstants.chatsCollection).doc(getChatRoomId(otherUserId));
    final participantAuthIds = <String>{
      currentUserId,
      if (recipientAuthId != null && recipientAuthId.isNotEmpty)
        recipientAuthId,
    }.toList()
      ..sort();
    final requestedParticipants = [currentMessagingId, otherUserId]..sort();
    await chatReference.set({
      'participants': requestedParticipants,
      'participantAuthIds': participantAuthIds,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Send a text message - updated with reply support
  Future<void> sendMessage({
    required String receiverId,
    required String message,
    String type = 'text',
    String? mediaUrl,
    int? audioDuration,
    bool isViewOnce = false,
    Map<String, dynamic>? replyTo,
    Map<String, dynamic>? metadata,
    String? mediaStoragePath,
    String? mediaName,
    String? mediaContentType,
    int? mediaSize,
  }) async {
    if (currentUserId.isEmpty) {
      throw Exception('Sign in before sending a message.');
    }
    if (message.trim().isEmpty && mediaUrl == null) {
      throw Exception('A message or attachment is required.');
    }

    final chatRoomId = getChatRoomId(receiverId);
    final timestamp = FieldValue.serverTimestamp();
    await ensureChatRoom(receiverId);

    // Get sender info
    final senderDoc =
        await _firestore.collection('users').doc(currentUserId).get();
    final senderData = senderDoc.data() ?? {};

    final chatReference =
        _firestore.collection(AppConstants.chatsCollection).doc(chatRoomId);
    final messageReference = chatReference.collection('messages').doc();
    final messageData = <String, dynamic>{
      'id': messageReference.id,
      'chatId': chatRoomId,
      'senderId': currentMessagingId,
      'senderAuthId': currentUserId,
      'senderEmail': currentUserEmail,
      'senderName': senderData['fullName'] ??
          senderData['displayName'] ??
          currentUserEmail,
      'senderPhoto': senderData['photoUrl'],
      'receiverId': receiverId,
      'message': message.trim(),
      'content': message.trim(),
      'type': type,
      'mediaUrl': mediaUrl,
      'mediaStoragePath': mediaStoragePath,
      'mediaName': mediaName,
      'mediaContentType': mediaContentType,
      'mediaSize': mediaSize,
      'audioDuration': audioDuration,
      'isViewOnce': isViewOnce,
      'viewedBy': <String>[],
      'timestamp': timestamp,
      'createdAt': timestamp,
      'isRead': false,
      'isDeleted': false,
      'reactions': {},
      'starredBy': [],
      'replyTo': replyTo != null
          ? {
              'messageId': replyTo['messageId'],
              'senderId': replyTo['senderId'],
              'senderName': replyTo['senderName'],
              'message': replyTo['message'],
              'type': replyTo['type'],
            }
          : null,
      'metadata': metadata,
    };

    final batch = _firestore.batch();
    batch.set(messageReference, messageData);
    batch.set(
      chatReference,
      {
        'lastMessage': message.trim(),
        'lastMessageType': type,
        'lastMessageTime': timestamp,
        'updatedAt': timestamp,
        'lastSenderId': currentMessagingId,
        'lastSenderName': senderData['fullName'] ??
            senderData['displayName'] ??
            currentUserEmail,
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> sendMediaMessage({
    required String receiverId,
    required Uint8List bytes,
    required String type,
    required String originalName,
    required String message,
    String? contentType,
    int? audioDuration,
    bool isViewOnce = false,
    Map<String, dynamic>? metadata,
  }) async {
    final upload = await uploadMediaBytes(
      bytes,
      MediaUtils.folderForType(type),
      originalName,
      receiverId: receiverId,
      contentType: contentType,
    );
    if (upload == null) {
      throw Exception('The attachment could not be uploaded.');
    }
    await sendMessage(
      receiverId: receiverId,
      message: message,
      type: type,
      mediaUrl: upload.url,
      mediaStoragePath: upload.storagePath,
      mediaName: upload.originalName,
      mediaContentType: upload.contentType,
      mediaSize: upload.size,
      audioDuration: audioDuration,
      isViewOnce: isViewOnce,
      metadata: metadata,
    );
  }

  // Toggle reaction on a message
  Future<void> toggleReaction(
      String otherUserId, String messageId, String emoji) async {
    final chatRoomId = getChatRoomId(otherUserId);
    final messageRef = _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId);

    final doc = await messageRef.get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final reactions = Map<String, List<dynamic>>.from(data['reactions'] ?? {});

    if (reactions[emoji] == null) {
      reactions[emoji] = [currentMessagingId];
    } else if (reactions[emoji]!.contains(currentMessagingId)) {
      reactions[emoji]!.remove(currentMessagingId);
      if (reactions[emoji]!.isEmpty) {
        reactions.remove(emoji);
      }
    } else {
      reactions[emoji]!.add(currentMessagingId);
    }

    await messageRef.update({'reactions': reactions});
  }

  // Toggle star on a message
  Future<void> toggleStar(String otherUserId, String messageId) async {
    final chatRoomId = getChatRoomId(otherUserId);
    final messageRef = _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId);

    final doc = await messageRef.get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final starredBy = List<String>.from(data['starredBy'] ?? []);

    if (starredBy.contains(currentMessagingId)) {
      starredBy.remove(currentMessagingId);
    } else {
      starredBy.add(currentMessagingId);
    }

    await messageRef.update({'starredBy': starredBy});
  }

  // Delete message (soft delete) - updated to show who deleted
  Future<void> deleteMessage(String otherUserId, String messageId) async {
    final chatRoomId = getChatRoomId(otherUserId);

    // Get current user name
    final userDoc =
        await _firestore.collection('users').doc(currentUserId).get();
    final userName = userDoc.data()?['fullName'] ??
        userDoc.data()?['displayName'] ??
        userDoc.data()?['email'] ??
        'Someone';

    await _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId)
        .update({
      'isDeleted': true,
      'deletedBy': currentMessagingId,
      'deletedByName': userName,
      'deletedAt': FieldValue.serverTimestamp(),
      'deletedForMe': true,
    });
  }

  Future<void> editTextMessage({
    required String otherUserId,
    required String messageId,
    required String message,
  }) async {
    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) {
      throw Exception('A message cannot be empty.');
    }

    final reference = _firestore
        .collection(AppConstants.chatsCollection)
        .doc(getChatRoomId(otherUserId))
        .collection('messages')
        .doc(messageId);
    final snapshot = await reference.get();
    final data = snapshot.data();
    final createdAt = data?['timestamp'];
    if (!snapshot.exists ||
        data?['senderAuthId'] != currentUserId ||
        data?['type'] != 'text' ||
        data?['isDeleted'] == true ||
        createdAt is! Timestamp ||
        DateTime.now().difference(createdAt.toDate()) >
            const Duration(minutes: 10)) {
      throw Exception('Text messages can only be edited within 10 minutes.');
    }

    await reference.update({
      'message': trimmedMessage,
      'content': trimmedMessage,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  // Delete for everyone - updated to show who deleted
  Future<void> deleteForEveryone(String otherUserId, String messageId) async {
    final chatRoomId = getChatRoomId(otherUserId);

    // Get current user name
    final userDoc =
        await _firestore.collection('users').doc(currentUserId).get();
    final userName = userDoc.data()?['fullName'] ??
        userDoc.data()?['displayName'] ??
        userDoc.data()?['email'] ??
        'Someone';

    final messageReference = _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId);
    final messageDocument = await messageReference.get();
    final mediaStoragePath =
        messageDocument.data()?['mediaStoragePath']?.toString();

    await messageReference.update({
      'message': '',
      'content': '',
      'isDeleted': true,
      'deletedForEveryone': true,
      'deletedBy': currentMessagingId,
      'deletedByName': userName,
      'deletedAt': FieldValue.serverTimestamp(),
      'mediaUrl': null,
      'type': 'deleted',
    });
    if (mediaStoragePath != null && mediaStoragePath.isNotEmpty) {
      try {
        await _storage.ref().child(mediaStoragePath).delete();
      } on FirebaseException catch (error) {
        if (error.code != 'object-not-found') rethrow;
      }
    }
  }

  // Get messages stream between two users - with notification
  Stream<QuerySnapshot> getMessages(String otherUserId) {
    final chatRoomId = getChatRoomId(otherUserId);
    return _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // Listen for new messages and play sound
  void listenForNewMessages(String otherUserId,
      {Function(Map<String, dynamic>)? onNewMessage}) {
    final chatRoomId = getChatRoomId(otherUserId);

    _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        // Only play sound if message is from other user and recent
        if (data['senderId'] != currentMessagingId) {
          final timestamp = data['timestamp'] as Timestamp?;
          if (timestamp != null) {
            final messageTime = timestamp.toDate();
            final now = DateTime.now();
            // Only if message is within last 5 seconds (new message)
            if (now.difference(messageTime).inSeconds < 5) {
              _notificationService.playMessageSound();
              onNewMessage?.call(data);
            }
          }
        }
      }
    });
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String otherUserId) async {
    final chatRoomId = getChatRoomId(otherUserId);
    final unreadMessages = await _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatRoomId)
        .collection('messages')
        .where('receiverId', isEqualTo: currentMessagingId)
        .get();

    for (var doc in unreadMessages.docs) {
      final data = doc.data();
      if (data['isRead'] != true) {
        await doc.reference.update({'isRead': true});
      }
    }
  }

  // Get all chat rooms for current user
  Stream<QuerySnapshot> getChatRooms() {
    return _firestore
        .collection(AppConstants.chatsCollection)
        .where('participants', arrayContains: currentMessagingId)
        .snapshots();
  }

  Stream<Set<String>> getFavoriteContactIds() {
    if (currentUserId.isEmpty) return Stream.value(<String>{});
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('favorites')
        .snapshots()
        .map(
            (snapshot) => snapshot.docs.map((document) => document.id).toSet());
  }

  Future<bool> toggleFavoriteContact(
    String contactIdentity, {
    String? contactName,
    bool? shouldFavorite,
  }) async {
    if (currentUserId.isEmpty || contactIdentity.isEmpty) {
      throw Exception('Sign in before managing favorites.');
    }
    final reference = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('favorites')
        .doc(contactIdentity);
    final document = await reference.get();
    final favorite = shouldFavorite ?? !document.exists;
    if (favorite) {
      await reference.set({
        'contactIdentity': contactIdentity,
        'contactName': contactName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await reference.delete();
    }
    return favorite;
  }

  Future<UploadedMedia?> uploadMediaBytes(
    Uint8List bytes,
    String folder,
    String originalName, {
    required String receiverId,
    String? contentType,
  }) async {
    if (currentUserId.isEmpty || bytes.isEmpty) return null;
    try {
      await ensureChatRoom(receiverId);
      final chatRoomId = getChatRoomId(receiverId);
      final safeName = MediaUtils.sanitizeFileName(originalName);
      final resolvedContentType = contentType ??
          MediaUtils.contentTypeForName(
            originalName,
            fallback: _contentTypeForFolder(folder),
          );
      final reference = _storage.ref().child(
            'chat_media_v2/$chatRoomId/$currentUserId/$folder/'
            '${DateTime.now().millisecondsSinceEpoch}_$safeName',
          );
      final upload = await reference.putData(
        bytes,
        SettableMetadata(
          contentType: resolvedContentType,
          customMetadata: {
            'chatId': chatRoomId,
            'uploaderUid': currentUserId,
            'receiverIdentity': receiverId,
            'originalName': originalName,
          },
        ),
      );
      return UploadedMedia(
        url: await upload.ref.getDownloadURL(),
        storagePath: upload.ref.fullPath,
        originalName: originalName,
        contentType: resolvedContentType,
        size: bytes.length,
      );
    } catch (error) {
      debugPrint('Chat media upload failed: $error');
      return null;
    }
  }

  String _contentTypeForFolder(String folder) {
    if (folder.contains('image')) return 'image/jpeg';
    if (folder.contains('video')) return 'video/mp4';
    if (folder.contains('audio')) return 'audio/mp4';
    return 'application/octet-stream';
  }

  Future<GroupModel> createGroup({
    required String name,
    required String description,
    required String creatorId,
    String kind = 'group',
    List<String> memberIds = const [],
    String? profilePictureUrl,
    bool allowMemberStatusTagging = true,
  }) async {
    final groupRef = _firestore.collection('groups').doc();
    final creatorDoc =
        await _firestore.collection('users').doc(creatorId).get();
    final creator = creatorDoc.data() ?? <String, dynamic>{};
    final group = GroupModel(
      id: groupRef.id,
      name: name,
      profilePictureUrl: profilePictureUrl,
      createdBy: creatorId,
      creatorName:
          creator['fullName'] ?? creator['displayName'] ?? currentUserEmail,
      creatorPhotoUrl: creator['photoUrl'],
      createdAt: DateTime.now(),
      members: {creatorId, ...memberIds}.toList(),
      admins: [creatorId],
      description: description,
      inviteLink: 'https://regent-connect-85439.web.app/group/${groupRef.id}',
      kind: kind,
      allowMemberStatusTagging: allowMemberStatusTagging,
      membersCanPost: kind != 'channel',
    );
    await groupRef.set(group.toMap());
    return group;
  }

  Future<GroupModel> ensureAlumniNetworkGroup() async {
    if (currentUserId.isEmpty) {
      throw Exception('Sign in before opening the alumni network.');
    }

    const groupId = 'regent-alumni-network';
    final groupRef = _firestore.collection('groups').doc(groupId);
    final existing = await groupRef.get();
    final creatorDoc =
        await _firestore.collection('users').doc(currentUserId).get();
    final creator = creatorDoc.data() ?? <String, dynamic>{};
    final creatorName =
        creator['fullName'] ?? creator['displayName'] ?? currentUserEmail;

    if (!existing.exists) {
      final group = GroupModel(
        id: groupRef.id,
        name: 'Regent Alumni Network',
        createdBy: currentUserId,
        creatorName: creatorName.toString(),
        creatorPhotoUrl: creator['photoUrl']?.toString(),
        createdAt: DateTime.now(),
        members: [currentUserId],
        admins: [currentUserId],
        description:
            'A community for Regent graduates to stay connected, share opportunities and support one another.',
        inviteLink:
            'https://regent-connect-85439.web.app/group/$groupId',
        kind: 'group',
        allowMemberStatusTagging: true,
        membersCanPost: true,
      );
      await groupRef.set(group.toMap());
      return group;
    }

    final data = existing.data() as Map<String, dynamic>? ?? const {};
    final group = GroupModel.fromMap({
      ...data,
      'id': existing.id,
    });
    if (!group.members.contains(currentUserId)) {
      await groupRef.update({
        'members': FieldValue.arrayUnion([currentUserId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    return GroupModel.fromMap({
      ...data,
      'id': existing.id,
      'members': {
        ...group.members,
        currentUserId,
      }.toList(),
    });
  }

  // Get user data
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final officialAccount = OfficialAccounts.byId(userId);
      if (officialAccount != null) {
        var linkedUsers = await _firestore
            .collection('users')
            .where('officialAccountId', isEqualTo: officialAccount.id)
            .limit(1)
            .get();
        if (linkedUsers.docs.isEmpty) {
          linkedUsers = await _firestore
              .collection('users')
              .where('email', isEqualTo: officialAccount.email)
              .limit(1)
              .get();
        }
        final linkedUser =
            linkedUsers.docs.isEmpty ? null : linkedUsers.docs.first;
        return officialAccount.toDirectoryMap(
          linkedUser: linkedUser?.data(),
          authUid: linkedUser?.id,
        );
      }

      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data();
      if (data == null) return null;
      final displayName =
          data['fullName'] ?? data['displayName'] ?? data['email'] ?? 'Unknown';
      return {
        ...data,
        'uid': doc.id,
        'authUid': doc.id,
        'chatIdentity': doc.id,
        'fullName': displayName,
        'displayName': displayName,
      };
    } catch (e) {
      return null;
    }
  }

  // Get user stream
  Stream<DocumentSnapshot> getUserStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }

  Future<void> voteInPoll({
    required String otherUserId,
    required String messageId,
    required int optionIndex,
  }) async {
    final messageReference = _firestore
        .collection(AppConstants.chatsCollection)
        .doc(getChatRoomId(otherUserId))
        .collection('messages')
        .doc(messageId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(messageReference);
      if (!snapshot.exists) return;
      final data = snapshot.data() ?? <String, dynamic>{};
      final metadata = Map<String, dynamic>.from(data['metadata'] ?? const {});
      final options = List<dynamic>.from(metadata['options'] ?? const []);
      if (optionIndex < 0 || optionIndex >= options.length) return;

      final votes = Map<String, dynamic>.from(
        metadata['votes'] ?? const <String, dynamic>{},
      );
      for (final key in votes.keys.toList()) {
        final voters = List<String>.from(votes[key] ?? const []);
        voters.remove(currentMessagingId);
        votes[key] = voters;
      }
      final selectedVoters =
          List<String>.from(votes['$optionIndex'] ?? const []);
      selectedVoters.add(currentMessagingId);
      votes['$optionIndex'] = selectedVoters.toSet().toList();
      metadata['votes'] = votes;
      transaction.update(messageReference, {'metadata': metadata});
    });
  }

  Future<void> voteInGroupPoll({
    required String groupId,
    required String messageId,
    required int optionIndex,
  }) async {
    if (currentUserId.isEmpty) return;

    final groupReference = _firestore.collection('groups').doc(groupId);
    final groupDocument = await groupReference.get();
    if (!groupDocument.exists) return;

    final group = GroupModel.fromMap({
      ...groupDocument.data()!,
      'id': groupDocument.id,
    });
    if (!group.members.contains(currentUserId)) {
      throw Exception('You are no longer a member of this ${group.kind}.');
    }

    final messageReference =
        groupReference.collection('messages').doc(messageId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(messageReference);
      if (!snapshot.exists) return;
      final data = snapshot.data() ?? <String, dynamic>{};
      final metadata = Map<String, dynamic>.from(data['metadata'] ?? const {});
      final options = List<dynamic>.from(metadata['options'] ?? const []);
      if (optionIndex < 0 || optionIndex >= options.length) return;

      final votes = Map<String, dynamic>.from(
        metadata['votes'] ?? const <String, dynamic>{},
      );
      for (final key in votes.keys.toList()) {
        final voters = List<String>.from(votes[key] ?? const []);
        voters.remove(currentUserId);
        votes[key] = voters;
      }
      final selectedVoters =
          List<String>.from(votes['$optionIndex'] ?? const []);
      selectedVoters.add(currentUserId);
      votes['$optionIndex'] = selectedVoters.toSet().toList();
      metadata['votes'] = votes;
      transaction.update(messageReference, {'metadata': metadata});
    });
  }

  Future<void> markMessageAsViewed({
    required String otherUserId,
    required String messageId,
  }) async {
    if (currentMessagingId.isEmpty) return;

    final messageReference = _firestore
        .collection(AppConstants.chatsCollection)
        .doc(getChatRoomId(otherUserId))
        .collection('messages')
        .doc(messageId);

    try {
      await messageReference.update({
        'viewedBy': FieldValue.arrayUnion([currentMessagingId]),
      });
    } catch (_) {
      // If the message disappears or changes while opening it, ignore it.
    }
  }

  Future<void> markGroupMessageAsViewed({
    required String groupId,
    required String messageId,
  }) async {
    if (currentUserId.isEmpty) return;

    final messageReference = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .doc(messageId);

    try {
      await messageReference.update({
        'viewedBy': FieldValue.arrayUnion([currentUserId]),
      });
    } catch (_) {
      // If the message disappears or changes while opening it, ignore it.
    }
  }

  Stream<Map<String, dynamic>?> getUserDataStream(String userId) {
    final officialAccount = OfficialAccounts.byId(userId);
    if (officialAccount != null) {
      return _firestore.collection('users').snapshots().map((snapshot) {
        QueryDocumentSnapshot<Map<String, dynamic>>? linkedUser;
        for (final document in snapshot.docs) {
          final data = document.data();
          if (data['officialAccountId'] == officialAccount.id ||
              OfficialAccounts.byEmail(data['email']?.toString())?.id ==
                  officialAccount.id) {
            linkedUser = document;
            break;
          }
        }
        return officialAccount.toDirectoryMap(
          linkedUser: linkedUser?.data(),
          authUid: linkedUser?.id,
        );
      });
    }

    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return null;
      return {
        ...data,
        'uid': doc.id,
        'authUid': doc.id,
        'chatIdentity': doc.id,
        'fullName': data['fullName'] ??
            data['displayName'] ??
            data['email'] ??
            'Unknown',
      };
    });
  }

  Stream<QuerySnapshot> getMyGroups() {
    return _firestore
        .collection('groups')
        .where('members', arrayContains: currentUserId)
        .snapshots();
  }

  Stream<DocumentSnapshot> getGroupStream(String groupId) {
    return _firestore.collection('groups').doc(groupId).snapshots();
  }

  Stream<QuerySnapshot> getGroupMessages(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots();
  }

  Future<void> sendGroupMessage({
    required String groupId,
    required String message,
    String type = 'text',
    String? mediaUrl,
    String? mediaStoragePath,
    String? mediaName,
    String? mediaContentType,
    int? mediaSize,
    bool isViewOnce = false,
    Map<String, dynamic>? metadata,
  }) async {
    if (currentUserId.isEmpty || (message.trim().isEmpty && mediaUrl == null)) {
      return;
    }

    final groupDocument =
        await _firestore.collection('groups').doc(groupId).get();
    if (!groupDocument.exists) {
      throw Exception('This group or channel no longer exists.');
    }

    final group = GroupModel.fromMap({
      ...groupDocument.data()!,
      'id': groupDocument.id,
    });
    if (!group.members.contains(currentUserId)) {
      throw Exception('You are not a member of this ${group.kind}.');
    }
    if (!group.canPost(currentUserId)) {
      throw Exception('Only channel admins can post here.');
    }

    final senderDocument =
        await _firestore.collection('users').doc(currentUserId).get();
    final sender = senderDocument.data() ?? <String, dynamic>{};
    final senderName =
        sender['fullName'] ?? sender['displayName'] ?? currentUserEmail;

    final timestamp = FieldValue.serverTimestamp();
    final messageReference =
        groupDocument.reference.collection('messages').doc();
    final batch = _firestore.batch();
    batch.set(messageReference, {
      'id': messageReference.id,
      'groupId': groupId,
      'senderId': currentUserId,
      'senderName': senderName,
      'senderPhotoUrl': sender['photoUrl'],
      'message': message.trim(),
      'content': message.trim(),
      'type': type,
      'mediaUrl': mediaUrl,
      'mediaStoragePath': mediaStoragePath,
      'mediaName': mediaName,
      'mediaContentType': mediaContentType,
      'mediaSize': mediaSize,
      'isViewOnce': isViewOnce,
      'viewedBy': <String>[],
      'timestamp': timestamp,
      'isDeleted': false,
      'reactions': {},
      'metadata': metadata,
    });
    batch.update(groupDocument.reference, {
      'lastMessage': message.trim().isNotEmpty ? message.trim() : 'Sent $type',
      'lastMessageType': type,
      'lastMessageTime': timestamp,
      'lastSenderId': currentUserId,
      'lastSenderName': senderName,
    });
    await batch.commit();
  }

  Future<void> sendGroupMediaMessage({
    required String groupId,
    required Uint8List bytes,
    required String type,
    required String originalName,
    String message = '',
    String? contentType,
    bool isViewOnce = false,
    Map<String, dynamic>? metadata,
  }) async {
    final upload = await uploadGroupMediaBytes(
      groupId: groupId,
      bytes: bytes,
      type: type,
      originalName: originalName,
      contentType: contentType,
    );
    if (upload == null) {
      throw Exception('The group attachment could not be uploaded.');
    }
    await sendGroupMessage(
      groupId: groupId,
      message: message,
      type: type,
      mediaUrl: upload.url,
      mediaStoragePath: upload.storagePath,
      mediaName: upload.originalName,
      mediaContentType: upload.contentType,
      mediaSize: upload.size,
      isViewOnce: isViewOnce,
      metadata: metadata,
    );
  }

  Future<UploadedMedia?> uploadGroupMediaBytes({
    required String groupId,
    required Uint8List bytes,
    required String type,
    required String originalName,
    String? contentType,
  }) async {
    if (currentUserId.isEmpty || bytes.isEmpty) return null;
    final groupDocument =
        await _firestore.collection('groups').doc(groupId).get();
    if (!groupDocument.exists) {
      throw Exception('This group or channel no longer exists.');
    }
    final group = GroupModel.fromMap({
      ...groupDocument.data()!,
      'id': groupDocument.id,
    });
    if (!group.members.contains(currentUserId) ||
        !group.canPost(currentUserId)) {
      throw Exception('You cannot post in this ${group.kind}.');
    }

    final safeName = MediaUtils.sanitizeFileName(originalName);
    final resolvedContentType =
        contentType ?? MediaUtils.contentTypeForName(originalName);
    final reference = _storage.ref().child(
          'group_media/$groupId/$currentUserId/$type/'
          '${DateTime.now().millisecondsSinceEpoch}_$safeName',
        );
    final upload = await reference.putData(
      bytes,
      SettableMetadata(
        contentType: resolvedContentType,
        customMetadata: {
          'groupId': groupId,
          'uploaderUid': currentUserId,
          'originalName': originalName,
        },
      ),
    );
    return UploadedMedia(
      url: await upload.ref.getDownloadURL(),
      storagePath: upload.ref.fullPath,
      originalName: originalName,
      contentType: resolvedContentType,
      size: bytes.length,
    );
  }

  Future<void> updateGroupStatusTagging({
    required String groupId,
    required bool allowMembers,
  }) async {
    final groupReference = _firestore.collection('groups').doc(groupId);
    final groupDocument = await groupReference.get();
    if (!groupDocument.exists) {
      throw Exception('This group or channel no longer exists.');
    }

    final group = GroupModel.fromMap({
      ...groupDocument.data()!,
      'id': groupDocument.id,
    });
    if (!group.isAdmin(currentUserId)) {
      throw Exception('Only an admin can change this setting.');
    }

    await groupReference.update({
      'allowMemberStatusTagging': allowMembers,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Clear chat (soft delete all messages for current user)
  Future<void> clearChat(String otherUserId) async {
    final chatRoomId = getChatRoomId(otherUserId);
    final messages = await _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatRoomId)
        .collection('messages')
        .get();

    for (var doc in messages.docs) {
      await doc.reference.update({
        'deletedFor': FieldValue.arrayUnion([currentMessagingId])
      });
    }
  }

  // Set typing status
  Future<void> setTypingStatus(String recipientId, bool isTyping) async {
    if (currentUserId.isEmpty) return;

    final chatRoomId = getChatRoomId(recipientId);

    // Get current user data for name
    final userDoc =
        await _firestore.collection('users').doc(currentUserId).get();
    final userName = userDoc.data()?['fullName'] ??
        userDoc.data()?['displayName'] ??
        userDoc.data()?['email'] ??
        'Someone';

    await _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatRoomId)
        .set({
      'typing': {
        currentMessagingId: isTyping ? userName : null,
      },
    }, SetOptions(merge: true));

    // Auto-clear typing after 5 seconds
    if (isTyping) {
      Future.delayed(const Duration(seconds: 5), () {
        setTypingStatus(recipientId, false);
      });
    }
  }

  // Listen to typing status
  Stream<DocumentSnapshot> getTypingStatus(String recipientId) {
    final chatRoomId = getChatRoomId(recipientId);
    return _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatRoomId)
        .snapshots();
  }

  // Get total unread messages count
  Stream<int> getTotalUnreadCount() {
    return _firestore
        .collection(AppConstants.chatsCollection)
        .where('participants', arrayContains: currentMessagingId)
        .snapshots()
        .asyncMap((chatRooms) async {
      int totalUnread = 0;

      for (var room in chatRooms.docs) {
        final unreadQuery = await _firestore
            .collection(AppConstants.chatsCollection)
            .doc(room.id)
            .collection('messages')
            .where('receiverId', isEqualTo: currentMessagingId)
            .get();

        totalUnread += unreadQuery.docs.where((doc) {
          final data = doc.data();
          return data['isRead'] != true;
        }).length;
      }

      return totalUnread;
    });
  }

  // Get unread count for specific chat
  Stream<int> getUnreadCountForChat(String otherUserId) {
    final chatRoomId = getChatRoomId(otherUserId);
    return _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatRoomId)
        .collection('messages')
        .where('receiverId', isEqualTo: currentMessagingId)
        .snapshots()
        .map((snapshot) => snapshot.docs.where((doc) {
              final data = doc.data();
              return data['isRead'] != true;
            }).length);
  }
}
