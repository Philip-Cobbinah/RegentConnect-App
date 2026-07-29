import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../core/media_utils.dart';
import '../core/official_accounts.dart';
import 'chat_service.dart';

class BroadcastAttachment {
  const BroadcastAttachment({
    required this.bytes,
    required this.name,
    required this.type,
    String? contentType,
  }) : contentType = contentType ?? 'application/octet-stream';

  final Uint8List bytes;
  final String name;
  final String type;
  final String contentType;
}

class BroadcastService {
  BroadcastService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    ChatService? chatService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _chatService = chatService ?? ChatService();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final ChatService _chatService;

  Future<String> sendBroadcast({
    required Iterable<String> recipientIds,
    required String message,
    BroadcastAttachment? attachment,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Sign in before sending a broadcast.');
    final senderIdentity = OfficialAccounts.messagingIdentity(
      uid: user.uid,
      email: user.email,
    );
    final recipients = recipientIds.toSet().toList()
      ..remove(user.uid)
      ..remove(senderIdentity);
    if (recipients.isEmpty) throw Exception('Select at least one recipient.');
    if (message.trim().isEmpty && attachment == null) {
      throw Exception('Add a message or attachment.');
    }
    final broadcastReference = _firestore.collection('broadcasts').doc();
    await broadcastReference.set({
      'id': broadcastReference.id,
      'senderAuthId': user.uid,
      'senderId': senderIdentity,
      'senderEmail': user.email,
      'recipientIds': recipients,
      'message': message.trim(),
      'attachmentType': attachment?.type,
      'attachmentName': attachment?.name,
      'status': attachment == null ? 'sending' : 'uploading',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    UploadedMedia? uploadedMedia;
    try {
      if (attachment != null) {
        uploadedMedia = await _uploadAttachment(
          broadcastReference.id,
          user.uid,
          attachment,
        );
      }

      var delivered = 0;
      final failures = <String>[];
      for (final recipientId in recipients) {
        try {
          await _chatService.sendMessage(
            receiverId: recipientId,
            message: message.trim().isNotEmpty
                ? message.trim()
                : 'Sent ${attachment?.type ?? 'attachment'}',
            type: attachment?.type ?? 'text',
            mediaUrl: uploadedMedia?.url,
            mediaStoragePath: uploadedMedia?.storagePath,
            mediaName: uploadedMedia?.originalName,
            mediaContentType: uploadedMedia?.contentType,
            mediaSize: uploadedMedia?.size,
            metadata: {
              'broadcastId': broadcastReference.id,
              'isBroadcast': true,
            },
          );
          delivered++;
        } catch (_) {
          failures.add(recipientId);
        }
      }

      await broadcastReference.update({
        'status': failures.isEmpty ? 'completed' : 'partial',
        'deliveredCount': delivered,
        'failedRecipientIds': failures,
        'mediaUrl': uploadedMedia?.url,
        'mediaStoragePath': uploadedMedia?.storagePath,
        'mediaContentType': uploadedMedia?.contentType,
        'mediaSize': uploadedMedia?.size,
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (delivered == 0) {
        throw Exception('The broadcast could not be delivered.');
      }
      return broadcastReference.id;
    } catch (error) {
      await broadcastReference.update({
        'status': 'failed',
        'error': error.toString(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      rethrow;
    }
  }

  Future<UploadedMedia> _uploadAttachment(
    String broadcastId,
    String uploaderUid,
    BroadcastAttachment attachment,
  ) async {
    final safeName = MediaUtils.sanitizeFileName(attachment.name);
    final contentType = attachment.contentType == 'application/octet-stream'
        ? MediaUtils.contentTypeForName(attachment.name)
        : attachment.contentType;
    final reference = _storage.ref().child(
          'broadcast_media/$broadcastId/$uploaderUid/'
          '${DateTime.now().millisecondsSinceEpoch}_$safeName',
        );
    final upload = await reference.putData(
      attachment.bytes,
      SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'broadcastId': broadcastId,
          'uploaderUid': uploaderUid,
          'originalName': attachment.name,
        },
      ),
    );
    return UploadedMedia(
      url: await upload.ref.getDownloadURL(),
      storagePath: upload.ref.fullPath,
      originalName: attachment.name,
      contentType: contentType,
      size: attachment.bytes.length,
    );
  }
}
