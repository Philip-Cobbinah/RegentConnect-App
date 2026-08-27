import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../core/media_utils.dart';
import '../models/course_registration_model.dart';

class CourseRegistrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String get currentUserId => _auth.currentUser?.uid ?? '';
  String get currentUserEmail => _auth.currentUser?.email ?? '';

  Future<String> submitRegistration({
    required String studentId,
    required String fullName,
    required String phoneNumber,
    required int level,
    required int term,
    required String termLabel,
    required String academicSession,
    required String facultyName,
    required String programName,
    required DateTime registrationDate,
    required String academicYear,
    required List<RegisteredCourse> courses,
    required String recipientLabel,
    Uint8List? registrationPdfBytes,
    Uint8List? attachmentBytes,
    String? attachmentName,
    String? attachmentContentType,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Please sign in before submitting a course registration.');
    }

    final resolvedStudentId = studentId.trim();
    final resolvedFullName = fullName.trim();
    final resolvedPhoneNumber = phoneNumber.trim();
    final resolvedFaculty = facultyName.trim();
    final resolvedProgram = programName.trim();
    if (resolvedStudentId.isEmpty ||
        resolvedFullName.isEmpty ||
        resolvedPhoneNumber.isEmpty ||
        resolvedFaculty.isEmpty ||
        resolvedProgram.isEmpty) {
      throw Exception('Please complete the registration form.');
    }

    final docRef = _firestore.collection('course_registrations').doc();

    String? uploadedUrl;
    String? uploadedStoragePath;
    String? uploadedFileName;
    String? uploadedContentType;
    int? uploadedSize;
    String? uploadedPdfUrl;
    String? uploadedPdfStoragePath;

    if (attachmentBytes != null && attachmentBytes.isNotEmpty) {
      final safeName = MediaUtils.sanitizeFileName(
        attachmentName ?? 'registration_photo.jpg',
        fallback: 'registration_photo.jpg',
      );
      uploadedContentType = (attachmentContentType != null &&
              attachmentContentType.trim().isNotEmpty)
          ? attachmentContentType.trim()
          : MediaUtils.contentTypeForName(
              safeName,
              fallback: 'image/jpeg',
            );
      final storageRef = _storage
          .ref()
          .child(
            'course_registrations/${docRef.id}/$currentUserId/photo/'
            '${DateTime.now().millisecondsSinceEpoch}_$safeName',
          );
      final task = await storageRef.putData(
        attachmentBytes,
        SettableMetadata(
          contentType: uploadedContentType,
          customMetadata: {
            'registrationId': docRef.id,
            'uploaderUid': currentUserId,
            'originalName': safeName,
            'mediaKind': 'photo',
          },
        ),
      );
      uploadedUrl = await task.ref.getDownloadURL();
      uploadedStoragePath = task.ref.fullPath;
      uploadedFileName = safeName;
      uploadedSize = attachmentBytes.length;
    }

    if (registrationPdfBytes != null && registrationPdfBytes.isNotEmpty) {
      final storageRef = _storage.ref().child(
            'course_registrations/${docRef.id}/$currentUserId/form/'
            'course-registration-${DateTime.now().millisecondsSinceEpoch}.pdf',
          );
      final task = await storageRef.putData(
        registrationPdfBytes,
        SettableMetadata(
          contentType: 'application/pdf',
          customMetadata: {
            'registrationId': docRef.id,
            'uploaderUid': currentUserId,
            'mediaKind': 'registration-form',
          },
        ),
      );
      uploadedPdfUrl = await task.ref.getDownloadURL();
      uploadedPdfStoragePath = task.ref.fullPath;
    }

    final record = CourseRegistrationModel(
      id: docRef.id,
      studentUid: user.uid,
      studentId: resolvedStudentId,
      fullName: resolvedFullName,
      phoneNumber: resolvedPhoneNumber,
      level: level,
      term: term,
      termLabel: termLabel,
      facultyName: resolvedFaculty,
      programName: resolvedProgram,
      academicSession: academicSession,
      academicYear: academicYear,
      courses: courses,
      recipientLabel: recipientLabel,
      registrationDate: registrationDate,
      status: 'pending',
      attachmentUrl: uploadedUrl,
      attachmentStoragePath: uploadedStoragePath,
      attachmentName: uploadedFileName,
      attachmentContentType: uploadedContentType,
      attachmentSize: uploadedSize,
      pdfUrl: uploadedPdfUrl,
      pdfStoragePath: uploadedPdfStoragePath,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await docRef.set({
      ...record.toMap(),
      'submittedByEmail': user.email ?? currentUserEmail,
      'searchText': [
        resolvedStudentId,
        resolvedFullName,
        resolvedPhoneNumber,
        resolvedFaculty,
        resolvedProgram,
        'Level $level',
        termLabel,
        '$term',
        academicSession,
      ].join(' ').toLowerCase(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  Stream<List<CourseRegistrationModel>> watchMyRegistrations() {
    final uid = currentUserId;
    if (uid.isEmpty) return Stream.value(const <CourseRegistrationModel>[]);

    return _firestore
        .collection('course_registrations')
        .where('studentUid', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      final registrations = snapshot.docs
          .map((doc) => CourseRegistrationModel.fromMap(doc.data(), doc.id))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return registrations;
    });
  }
}
