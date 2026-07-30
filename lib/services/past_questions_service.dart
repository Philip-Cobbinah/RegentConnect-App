import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../core/media_utils.dart';
import '../models/past_question_model.dart';

class PastQuestionsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const String _collection = 'past_questions';

  // Upload past question
  Future<String?> uploadPastQuestion({
    String? courseCode, // Made optional
    required String courseName,
    required String programName,
    required String facultyName,
    required int level,
    required int semester,
    required int year,
    required Uint8List fileBytes,
    required String fileName,
    required String fileType,
    required String uploadedBy,
    required String uploaderName,
  }) async {
    try {
      final ownerUid = _auth.currentUser?.uid;
      if (ownerUid == null || ownerUid != uploadedBy) {
        throw Exception('Sign in again before uploading.');
      }
      if (fileBytes.isEmpty) throw Exception('The selected file is empty.');
      final docRef = _firestore.collection(_collection).doc();
      // Create unique file path
      final safeName = MediaUtils.sanitizeFileName(fileName);
      final storagePath =
          'past_questions/$ownerUid/${docRef.id}/${year}_$safeName';
      final ref = _storage.ref().child(storagePath);

      // Upload file
      await ref.putData(
        fileBytes,
        SettableMetadata(
          contentType: _getContentType(fileType),
          customMetadata: {
            'ownerUid': ownerUid,
            'questionId': docRef.id,
            'originalName': fileName,
          },
        ),
      );
      final fileUrl = await ref.getDownloadURL();

      // Save to Firestore
      await docRef.set({
        'id': docRef.id,
        'courseCode': courseCode ?? '', // Store empty string if not provided
        'courseName': courseName,
        'programName': programName,
        'facultyName': facultyName,
        'level': level,
        'semester': semester,
        'year': year,
        'fileUrl': fileUrl,
        'storagePath': storagePath,
        'fileName': fileName,
        'fileType': fileType,
        'uploadedBy': uploadedBy,
        'uploaderName': uploaderName,
        'uploadedAt': FieldValue.serverTimestamp(),
        'downloadCount': 0,
      });

      return docRef.id;
    } catch (e) {
      print('Error uploading past question: $e');
      return null;
    }
  }

  // Get past questions for a course
  Stream<List<PastQuestionModel>> getPastQuestions({
    required String courseCode,
    required int level,
    required int semester,
    int? year,
  }) {
    Query query = _firestore
        .collection(_collection)
        .where('courseCode', isEqualTo: courseCode)
        .where('level', isEqualTo: level)
        .where('semester', isEqualTo: semester);

    if (year != null) {
      query = query.where('year', isEqualTo: year);
    }

    return query.orderBy('year', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return PastQuestionModel.fromMap(
            doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  Stream<List<PastQuestionModel>> watchPastQuestions({
    String? facultyName,
    String? programName,
    int? level,
    int? semester,
    int? year,
    String? query,
  }) {
    Query queryRef = _firestore.collection(_collection);

    if (facultyName != null && facultyName.trim().isNotEmpty) {
      queryRef = queryRef.where('facultyName', isEqualTo: facultyName.trim());
    }
    if (programName != null && programName.trim().isNotEmpty) {
      queryRef = queryRef.where('programName', isEqualTo: programName.trim());
    }
    if (level != null) {
      queryRef = queryRef.where('level', isEqualTo: level);
    }
    if (semester != null) {
      queryRef = queryRef.where('semester', isEqualTo: semester);
    }
    if (year != null) {
      queryRef = queryRef.where('year', isEqualTo: year);
    }

    return queryRef.snapshots().map((snapshot) {
      final normalizedQuery = query?.trim().toLowerCase() ?? '';
      final items = snapshot.docs
          .map((doc) => PastQuestionModel.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ))
          .where((question) {
        if (normalizedQuery.isEmpty) return true;
        return [
          question.courseCode,
          question.courseName,
          question.fileName,
          question.programName,
          question.facultyName,
        ].whereType<String>().any(
              (value) => value.toLowerCase().contains(normalizedQuery),
            );
      }).toList();

      items.sort((a, b) {
        final yearCompare = b.year.compareTo(a.year);
        if (yearCompare != 0) return yearCompare;
        return b.uploadedAt.compareTo(a.uploadedAt);
      });
      return items;
    });
  }

  // Get all past questions for a program/level/semester
  Stream<List<PastQuestionModel>> getPastQuestionsByProgram({
    required String programName,
    required int level,
    required int semester,
  }) {
    return watchPastQuestions(
      programName: programName,
      level: level,
      semester: semester,
    );
  }

  // Delete past question
  Future<bool> deletePastQuestion(String questionId, String fileUrl) async {
    try {
      final document =
          await _firestore.collection(_collection).doc(questionId).get();
      final storagePath = document.data()?['storagePath']?.toString();
      // Delete from Storage
      if (storagePath != null && storagePath.isNotEmpty) {
        await _storage.ref().child(storagePath).delete();
      } else {
        await _storage.refFromURL(fileUrl).delete();
      }
      // Delete from Firestore
      await _firestore.collection(_collection).doc(questionId).delete();
      return true;
    } catch (e) {
      print('Error deleting past question: $e');
      return false;
    }
  }

  // Update download count
  Future<void> incrementDownloadCount(String questionId) async {
    await _firestore.collection(_collection).doc(questionId).update({
      'downloadCount': FieldValue.increment(1),
    });
  }

  // Get user's uploaded questions
  Stream<List<PastQuestionModel>> getUserUploadedQuestions(String userId) {
    return _firestore
        .collection(_collection)
        .where('uploadedBy', isEqualTo: userId)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return PastQuestionModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  String _getContentType(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return 'application/octet-stream';
    }
  }
}
