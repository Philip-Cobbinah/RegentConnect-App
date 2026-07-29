import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AIChatMessage {
  final String? id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final Uint8List? imageData;
  final String? imageUrl;
  final String? imageStoragePath;
  final String? audioUrl;
  final String? audioStoragePath;
  final int? audioDuration;

  AIChatMessage({
    this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.imageData,
    this.imageUrl,
    this.imageStoragePath,
    this.audioUrl,
    this.audioStoragePath,
    this.audioDuration,
  });

  String stableId(int index) =>
      id ??
      '${timestamp.microsecondsSinceEpoch}_${isUser ? 'user' : 'assistant'}_$index';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'imageData': imageData != null ? base64Encode(imageData!) : null,
      'imageUrl': imageUrl,
      'imageStoragePath': imageStoragePath,
      'audioUrl': audioUrl,
      'audioStoragePath': audioStoragePath,
      'audioDuration': audioDuration,
    };
  }

  Map<String, dynamic> toFirestore({
    required String messageId,
    String? resolvedImageUrl,
    String? resolvedImageStoragePath,
    String? resolvedAudioUrl,
    String? resolvedAudioStoragePath,
  }) {
    return {
      'id': messageId,
      'content': content,
      'isUser': isUser,
      'role': isUser ? 'user' : 'assistant',
      'timestamp': Timestamp.fromDate(timestamp),
      'imageUrl': resolvedImageUrl ?? imageUrl,
      'imageStoragePath': resolvedImageStoragePath ?? imageStoragePath,
      'audioUrl': resolvedAudioUrl ?? audioUrl,
      'audioStoragePath': resolvedAudioStoragePath ?? audioStoragePath,
      'audioDuration': audioDuration,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory AIChatMessage.fromJson(Map<String, dynamic> json) {
    return AIChatMessage(
      id: json['id']?.toString(),
      content: json['content'] ?? '',
      isUser: json['isUser'] ?? false,
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      imageData:
          json['imageData'] != null ? base64Decode(json['imageData']) : null,
      imageUrl: json['imageUrl']?.toString(),
      imageStoragePath: json['imageStoragePath']?.toString(),
      audioUrl: json['audioUrl']?.toString(),
      audioStoragePath: json['audioStoragePath']?.toString(),
      audioDuration: json['audioDuration'],
    );
  }

  factory AIChatMessage.fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    final timestamp = data['timestamp'];
    return AIChatMessage(
      id: id,
      content: data['content']?.toString() ?? '',
      isUser: data['isUser'] == true || data['role'] == 'user',
      timestamp: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
      imageUrl: data['imageUrl']?.toString(),
      imageStoragePath: data['imageStoragePath']?.toString(),
      audioUrl: data['audioUrl']?.toString(),
      audioStoragePath: data['audioStoragePath']?.toString(),
      audioDuration: data['audioDuration'] as int?,
    );
  }
}

class AIChatStorageService {
  AIChatStorageService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  static const String _storageKey = 'regent_ai_chat_history';
  static const String _sessionId = 'default';

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> _messagesReference(String uid) =>
      _firestore
          .collection('users')
          .doc(uid)
          .collection('ai_chats')
          .doc(_sessionId)
          .collection('messages');

  Future<void> saveMessages(List<AIChatMessage> messages) async {
    await _saveLocally(messages);
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final storedIds = <String>{};
      final payloads = <String, Map<String, dynamic>>{};

      for (var index = 0; index < messages.length; index++) {
        final message = messages[index];
        final id = message.stableId(index);
        storedIds.add(id);

        String? imageUrl = message.imageUrl;
        String? imagePath = message.imageStoragePath;
        if (message.imageData != null && imageUrl == null) {
          final reference =
              _storage.ref().child('ai_media/$uid/images/$id.jpg');
          await reference.putData(
            message.imageData!,
            SettableMetadata(
              contentType: 'image/jpeg',
              customMetadata: {'ownerUid': uid, 'messageId': id},
            ),
          );
          imageUrl = await reference.getDownloadURL();
          imagePath = reference.fullPath;
        }

        String? audioUrl = message.audioUrl;
        String? audioPath = message.audioStoragePath;
        if (audioUrl != null &&
            audioUrl.isNotEmpty &&
            audioPath == null &&
            !_isRemoteUrl(audioUrl)) {
          final bytes = await XFile(audioUrl).readAsBytes();
          final reference = _storage.ref().child('ai_media/$uid/audio/$id.m4a');
          await reference.putData(
            bytes,
            SettableMetadata(
              contentType: 'audio/mp4',
              customMetadata: {'ownerUid': uid, 'messageId': id},
            ),
          );
          audioUrl = await reference.getDownloadURL();
          audioPath = reference.fullPath;
        }

        payloads[id] = message.toFirestore(
          messageId: id,
          resolvedImageUrl: imageUrl,
          resolvedImageStoragePath: imagePath,
          resolvedAudioUrl: audioUrl,
          resolvedAudioStoragePath: audioPath,
        );
      }

      final existing = await _messagesReference(uid).get();
      final operations = <void Function(WriteBatch)>[];
      for (final entry in payloads.entries) {
        operations.add(
          (batch) =>
              batch.set(_messagesReference(uid).doc(entry.key), entry.value),
        );
      }
      for (final document in existing.docs) {
        if (!storedIds.contains(document.id)) {
          operations.add((batch) => batch.delete(document.reference));
        }
      }

      for (var start = 0; start < operations.length; start += 400) {
        final end =
            start + 400 < operations.length ? start + 400 : operations.length;
        final batch = _firestore.batch();
        for (final operation in operations.sublist(start, end)) {
          operation(batch);
        }
        await batch.commit();
      }

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('ai_chats')
          .doc(_sessionId)
          .set({
        'ownerUid': uid,
        'messageCount': messages.length,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      debugPrint(
          'Firebase AI history sync failed; local copy retained: $error');
    }
  }

  Future<List<AIChatMessage>> loadMessages() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      try {
        final snapshot =
            await _messagesReference(uid).orderBy('timestamp').get();
        if (snapshot.docs.isNotEmpty) {
          final messages = snapshot.docs
              .map(
                (document) => AIChatMessage.fromFirestore(
                  document.data(),
                  document.id,
                ),
              )
              .toList();
          await _saveLocally(messages);
          return messages;
        }
      } catch (error) {
        debugPrint('Firebase AI history load failed: $error');
      }
    }
    return _loadLocally();
  }

  Future<void> clearMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final snapshot = await _messagesReference(uid).get();
      for (var start = 0; start < snapshot.docs.length; start += 400) {
        final end = start + 400 < snapshot.docs.length
            ? start + 400
            : snapshot.docs.length;
        final batch = _firestore.batch();
        for (final document in snapshot.docs.sublist(start, end)) {
          batch.delete(document.reference);
        }
        await batch.commit();
      }
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('ai_chats')
          .doc(_sessionId)
          .delete();
      await _deleteStorageTree(_storage.ref().child('ai_media/$uid'));
    } catch (error) {
      debugPrint('Firebase AI history clear failed: $error');
    }
  }

  Future<void> _saveLocally(List<AIChatMessage> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = messages.map((message) => message.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (error) {
      debugPrint('Local AI history save failed: $error');
    }
  }

  Future<List<AIChatMessage>> _loadLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString == null || jsonString.isEmpty) return [];
      final jsonList = jsonDecode(jsonString) as List;
      return jsonList
          .map(
            (json) => AIChatMessage.fromJson(
              Map<String, dynamic>.from(json as Map),
            ),
          )
          .toList();
    } catch (error) {
      debugPrint('Local AI history load failed: $error');
      return [];
    }
  }

  bool _isRemoteUrl(String value) =>
      value.startsWith('https://') || value.startsWith('http://');

  Future<void> _deleteStorageTree(Reference reference) async {
    final result = await reference.listAll();
    for (final item in result.items) {
      await item.delete();
    }
    for (final prefix in result.prefixes) {
      await _deleteStorageTree(prefix);
    }
  }
}
