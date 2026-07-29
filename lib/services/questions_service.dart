import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:typed_data';
import '../models/question_model.dart';
import '../core/constants.dart';
import '../core/media_utils.dart';

class QuestionsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Get all past questions
  Stream<List<QuestionModel>> getQuestions() {
    return _firestore
        .collection(AppConstants.questionsCollection)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => QuestionModel.fromMap(doc.data()))
            .toList());
  }

  // Filter by program
  Stream<List<QuestionModel>> getQuestionsByProgram(String program) {
    return _firestore
        .collection(AppConstants.questionsCollection)
        .where('program', isEqualTo: program)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => QuestionModel.fromMap(doc.data()))
            .toList());
  }

  // Search questions
  Future<List<QuestionModel>> searchQuestions(String query) async {
    final snapshot =
        await _firestore.collection(AppConstants.questionsCollection).get();

    return snapshot.docs
        .map((doc) => QuestionModel.fromMap(doc.data()))
        .where((q) =>
            q.courseCode.toLowerCase().contains(query.toLowerCase()) ||
            q.courseName.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  // Upload question
  Future<void> uploadQuestion({
    required File file,
    required QuestionModel question,
  }) async {
    await uploadQuestionBytes(
      bytes: await file.readAsBytes(),
      fileName: file.path.split(RegExp(r'[/\\]')).last,
      question: question,
    );
  }

  Future<void> uploadQuestionBytes({
    required Uint8List bytes,
    required String fileName,
    required QuestionModel question,
  }) async {
    final ownerUid = _auth.currentUser?.uid;
    if (ownerUid == null || ownerUid != question.uploadedBy) {
      throw Exception('Sign in again before uploading.');
    }
    if (bytes.isEmpty) throw Exception('The selected file is empty.');

    // Upload file to storage
    final safeName = MediaUtils.sanitizeFileName(
      fileName,
      fallback: '${question.id}.pdf',
    );
    final storagePath = 'questions/$ownerUid/${question.id}/$safeName';
    final ref = _storage.ref().child(storagePath);
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: MediaUtils.contentTypeForName(
          fileName,
          fallback: 'application/pdf',
        ),
        customMetadata: {
          'ownerUid': ownerUid,
          'questionId': question.id,
          'originalName': fileName,
        },
      ),
    );
    final fileUrl = await ref.getDownloadURL();

    // Save to Firestore
    final updatedQuestion = QuestionModel(
      id: question.id,
      courseCode: question.courseCode,
      courseName: question.courseName,
      program: question.program,
      level: question.level,
      semester: question.semester,
      academicYear: question.academicYear,
      fileUrl: fileUrl,
      uploadedBy: question.uploadedBy,
      uploadedAt: question.uploadedAt,
      tags: question.tags,
    );

    await _firestore
        .collection(AppConstants.questionsCollection)
        .doc(question.id)
        .set({
      ...updatedQuestion.toMap(),
      'storagePath': storagePath,
      'fileName': fileName,
    });
  }

  // Increment download count
  Future<void> incrementDownload(String questionId) async {
    await _firestore
        .collection(AppConstants.questionsCollection)
        .doc(questionId)
        .update({'downloadCount': FieldValue.increment(1)});
  }
}
