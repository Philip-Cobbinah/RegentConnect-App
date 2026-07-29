import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class CallException implements Exception {
  const CallException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CallService {
  CallService._();

  static final CallService _instance = CallService._();

  factory CallService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final ValueNotifier<MediaStream?> remoteStream =
      ValueNotifier<MediaStream?>(null);

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _callSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _candidateSubscription;
  final Set<String> _receivedCandidateIds = <String>{};
  final List<RTCIceCandidate> _pendingCandidates = <RTCIceCandidate>[];

  String? _activeCallId;
  bool _isCaller = false;
  bool _isVideo = false;
  bool _remoteDescriptionSet = false;
  bool _isMuted = false;
  bool _isCameraEnabled = true;
  bool _isSpeakerOn = false;

  static const Set<String> _activeStatuses = {
    'calling',
    'ringing',
    'connecting',
    'connected',
  };

  String get currentUserId => _auth.currentUser?.uid ?? '';
  String get currentUserEmail => _auth.currentUser?.email ?? '';
  String? get activeCallId => _activeCallId;
  MediaStream? get localStream => _localStream;
  bool get isMuted => _isMuted;
  bool get isCameraEnabled => _isCameraEnabled;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get hasMediaSession => _peerConnection != null;

  DocumentReference<Map<String, dynamic>> _callRef(String callId) =>
      _firestore.collection('calls').doc(callId);

  Future<String> initiateCall({
    required String receiverId,
    required String receiverName,
    required String callerName,
    required bool isVideo,
    String? callerPhoto,
    String? receiverPhoto,
  }) async {
    if (currentUserId.isEmpty) {
      throw const CallException('Sign in before starting a call.');
    }
    if (receiverId.isEmpty || receiverId == currentUserId) {
      throw const CallException('This person cannot be called.');
    }

    final existingCall = await getCurrentCall();
    if (existingCall != null) {
      throw const CallException(
        'You already have an active call. Return to it before starting another.',
      );
    }

    final receiverDoc =
        await _firestore.collection('users').doc(receiverId).get();
    if (!receiverDoc.exists) {
      throw const CallException('This person is not available for calls.');
    }

    final callId =
        '${currentUserId}_${receiverId}_${DateTime.now().millisecondsSinceEpoch}';
    final isReceiverOnline = receiverDoc.data()?['isOnline'] == true;
    final callData = <String, dynamic>{
      'callId': callId,
      'callerId': currentUserId,
      'callerName': callerName,
      'callerPhoto': callerPhoto,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverPhoto': receiverPhoto,
      'participantIds': [currentUserId, receiverId],
      'isVideo': isVideo,
      'status': 'calling',
      'isReceiverOnline': isReceiverOnline,
      'createdAt': FieldValue.serverTimestamp(),
      'connectedAt': null,
      'endedAt': null,
      'endedBy': null,
      'duration': 0,
    };

    final batch = _firestore.batch();
    batch.set(_callRef(callId), callData);
    batch.set(
      _firestore
          .collection('users')
          .doc(receiverId)
          .collection('incoming_calls')
          .doc(callId),
      {
        ...callData,
        'timestamp': FieldValue.serverTimestamp(),
      },
    );
    await batch.commit();
    return callId;
  }

  Future<void> markRinging(String callId) async {
    final call = await _callRef(callId).get();
    final data = call.data();
    if (data == null || data['receiverId'] != currentUserId) return;
    if (data['status'] != 'calling') return;

    await _callRef(callId).update({'status': 'ringing'});
    await _updateIncomingStatus(currentUserId, callId, 'ringing');
  }

  Future<void> updateCallStatus(String callId, String status) async {
    final updates = <String, dynamic>{'status': status};
    if (status == 'connected') {
      updates['connectedAt'] = FieldValue.serverTimestamp();
    } else if (!_activeStatuses.contains(status)) {
      updates['endedAt'] = FieldValue.serverTimestamp();
    }

    await _callRef(callId).update(updates);
    final call = await _callRef(callId).get();
    final receiverId = call.data()?['receiverId']?.toString();
    if (receiverId != null) {
      await _updateIncomingStatus(receiverId, callId, status);
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> listenForIncomingCalls() {
    if (currentUserId.isEmpty) return const Stream.empty();
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('incoming_calls')
        .where('status', whereIn: ['calling', 'ringing']).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchCallHistory() {
    if (currentUserId.isEmpty) return const Stream.empty();
    return _firestore
        .collection('calls')
        .where('participantIds', arrayContains: currentUserId)
        .snapshots();
  }

  Future<void> acceptCall(String callId) async {
    final call = await _callRef(callId).get();
    final data = call.data();
    if (data == null || data['receiverId'] != currentUserId) {
      throw const CallException('This call is no longer available.');
    }
    if (!_activeStatuses.contains(data['status'])) {
      throw const CallException('This call has already ended.');
    }

    await _callRef(callId).update({'status': 'connecting'});
    await _updateIncomingStatus(currentUserId, callId, 'connecting');
  }

  Future<void> declineCall(String callId, String callerId) async {
    try {
      await _callRef(callId).update({
        'status': 'declined',
        'endedAt': FieldValue.serverTimestamp(),
        'endedBy': currentUserId,
      });
    } finally {
      await _safeDeleteIncoming(currentUserId, callId);
      await disposeMediaSession(callId: callId);
    }
  }

  Future<void> endCall(String callId, String otherUserId) async {
    try {
      final snapshot = await _callRef(callId).get();
      final data = snapshot.data();
      if (data != null && _activeStatuses.contains(data['status'])) {
        var duration = 0;
        final connectedAt = data['connectedAt'];
        if (connectedAt is Timestamp) {
          duration = DateTime.now()
              .difference(connectedAt.toDate())
              .inSeconds
              .clamp(0, 86400);
        }
        await _callRef(callId).update({
          'status': 'ended',
          'endedAt': FieldValue.serverTimestamp(),
          'endedBy': currentUserId,
          'duration': duration,
        });
      }
      await _safeDeleteIncoming(otherUserId, callId);
      await _safeDeleteIncoming(currentUserId, callId);
    } finally {
      await disposeMediaSession(callId: callId);
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> listenToCallStatus(
    String callId,
  ) {
    return _callRef(callId).snapshots();
  }

  Future<Map<String, dynamic>?> getCurrentCall() async {
    if (currentUserId.isEmpty) return null;

    final calls = await _firestore
        .collection('calls')
        .where('participantIds', arrayContains: currentUserId)
        .limit(25)
        .get();

    final active = calls.docs
        .map((document) => document.data())
        .where((data) => _activeStatuses.contains(data['status']))
        .toList()
      ..sort((a, b) {
        final aTime = a['createdAt'] is Timestamp
            ? (a['createdAt'] as Timestamp).millisecondsSinceEpoch
            : 0;
        final bTime = b['createdAt'] is Timestamp
            ? (b['createdAt'] as Timestamp).millisecondsSinceEpoch
            : 0;
        return bTime.compareTo(aTime);
      });
    return active.isEmpty ? null : active.first;
  }

  Future<void> startOutgoingSession({
    required String callId,
    required bool isVideo,
  }) async {
    if (_activeCallId == callId && _peerConnection != null) return;

    await _preparePeerConnection(
      callId: callId,
      isVideo: isVideo,
      isCaller: true,
    );

    try {
      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': isVideo,
      });
      await _peerConnection!.setLocalDescription(offer);
      await _callRef(callId).update({
        'offer': {'sdp': offer.sdp, 'type': offer.type},
        'mediaReady': true,
      });
      _listenForRemoteCandidates(callId, 'calleeCandidates');
      _listenToSignaling(callId);
    } catch (_) {
      await disposeMediaSession(callId: callId);
      rethrow;
    }
  }

  Future<void> startIncomingSession({
    required String callId,
    required bool isVideo,
  }) async {
    if (_activeCallId == callId && _peerConnection != null) return;

    await _preparePeerConnection(
      callId: callId,
      isVideo: isVideo,
      isCaller: false,
    );

    try {
      final callSnapshot =
          await _callRef(callId).snapshots().firstWhere((snapshot) {
        final data = snapshot.data();
        return data == null ||
            data['offer'] != null ||
            !_activeStatuses.contains(data['status']);
      }).timeout(const Duration(seconds: 30));
      final callData = callSnapshot.data();
      final offer = callData?['offer'];
      if (callData == null ||
          offer is! Map ||
          !_activeStatuses.contains(callData['status'])) {
        throw const CallException('The caller ended the call.');
      }

      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(
          offer['sdp']?.toString(),
          offer['type']?.toString(),
        ),
      );
      _remoteDescriptionSet = true;
      _listenForRemoteCandidates(callId, 'callerCandidates');

      final answer = await _peerConnection!.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': isVideo,
      });
      await _peerConnection!.setLocalDescription(answer);
      await _callRef(callId).update({
        'answer': {'sdp': answer.sdp, 'type': answer.type},
        'status': 'connected',
        'connectedAt': FieldValue.serverTimestamp(),
        'mediaReady': true,
      });
      await _updateIncomingStatus(currentUserId, callId, 'connected');
      _listenToSignaling(callId);
    } on TimeoutException {
      await disposeMediaSession(callId: callId);
      throw const CallException(
          'The call could not connect. Please try again.');
    } catch (_) {
      await disposeMediaSession(callId: callId);
      rethrow;
    }
  }

  Future<void> _preparePeerConnection({
    required String callId,
    required bool isVideo,
    required bool isCaller,
  }) async {
    await disposeMediaSession();
    _activeCallId = callId;
    _isCaller = isCaller;
    _isVideo = isVideo;
    _isMuted = false;
    _isCameraEnabled = true;
    _isSpeakerOn = isVideo;
    _remoteDescriptionSet = false;
    _receivedCandidateIds.clear();
    _pendingCandidates.clear();

    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': isVideo
            ? {
                'facingMode': 'user',
                'width': {'ideal': 1280},
                'height': {'ideal': 720},
                'frameRate': {'ideal': 30},
              }
            : false,
      });

      _peerConnection = await createPeerConnection(
        _iceConfiguration,
        {
          'mandatory': {},
          'optional': [
            {'DtlsSrtpKeyAgreement': true},
          ],
        },
      );

      _peerConnection!.onTrack = (event) {
        if (event.streams.isEmpty) return;
        _remoteStream = event.streams.first;
        remoteStream.value = _remoteStream;
      };
      _peerConnection!.onIceCandidate = (candidate) {
        if (candidate.candidate == null) return;
        final collection = _isCaller ? 'callerCandidates' : 'calleeCandidates';
        unawaited(
          _callRef(callId).collection(collection).add({
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
            'createdAt': FieldValue.serverTimestamp(),
          }),
        );
      };
      _peerConnection!.onConnectionState = (state) {
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          unawaited(updateCallStatus(callId, 'failed'));
        }
      };

      for (final track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }
      await setSpeakerphone(isVideo);
    } catch (error) {
      await disposeMediaSession(callId: callId);
      if (error is CallException) rethrow;
      throw CallException(_mediaErrorMessage(error));
    }
  }

  Map<String, dynamic> get _iceConfiguration {
    const turnUrl = String.fromEnvironment('CALL_TURN_URL');
    const turnUsername = String.fromEnvironment('CALL_TURN_USERNAME');
    const turnCredential = String.fromEnvironment('CALL_TURN_CREDENTIAL');
    final servers = <Map<String, dynamic>>[
      {
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
        ],
      },
    ];
    if (turnUrl.isNotEmpty) {
      servers.add({
        'urls': turnUrl,
        if (turnUsername.isNotEmpty) 'username': turnUsername,
        if (turnCredential.isNotEmpty) 'credential': turnCredential,
      });
    }
    return {
      'iceServers': servers,
      'sdpSemantics': 'unified-plan',
    };
  }

  void _listenToSignaling(String callId) {
    _callSubscription?.cancel();
    _callSubscription = _callRef(callId).snapshots().listen((snapshot) async {
      final data = snapshot.data();
      if (data == null || !_activeStatuses.contains(data['status'])) {
        await disposeMediaSession(callId: callId);
        return;
      }

      if (_isCaller && !_remoteDescriptionSet && data['answer'] is Map) {
        final answer = data['answer'] as Map;
        await _peerConnection?.setRemoteDescription(
          RTCSessionDescription(
            answer['sdp']?.toString(),
            answer['type']?.toString(),
          ),
        );
        _remoteDescriptionSet = true;
        await _applyPendingCandidates();
      }
    });
  }

  void _listenForRemoteCandidates(String callId, String collection) {
    _candidateSubscription?.cancel();
    _candidateSubscription =
        _callRef(callId).collection(collection).snapshots().listen(
      (snapshot) async {
        for (final change in snapshot.docChanges) {
          if (change.type != DocumentChangeType.added ||
              !_receivedCandidateIds.add(change.doc.id)) {
            continue;
          }
          final data = change.doc.data();
          final candidate = data?['candidate']?.toString();
          if (candidate == null || candidate.isEmpty) continue;
          await _addRemoteCandidate(
            RTCIceCandidate(
              candidate,
              data?['sdpMid']?.toString(),
              data?['sdpMLineIndex'] as int?,
            ),
          );
        }
      },
    );
  }

  Future<void> _addRemoteCandidate(RTCIceCandidate candidate) async {
    if (!_remoteDescriptionSet) {
      _pendingCandidates.add(candidate);
      return;
    }
    try {
      await _peerConnection?.addCandidate(candidate);
    } catch (error) {
      debugPrint('Unable to add remote call candidate: $error');
    }
  }

  Future<void> _applyPendingCandidates() async {
    final candidates = [..._pendingCandidates];
    _pendingCandidates.clear();
    for (final candidate in candidates) {
      await _addRemoteCandidate(candidate);
    }
  }

  Future<bool> toggleMute() async {
    _isMuted = !_isMuted;
    for (final track
        in _localStream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = !_isMuted;
    }
    return _isMuted;
  }

  Future<bool> toggleCamera() async {
    if (!_isVideo) return false;
    _isCameraEnabled = !_isCameraEnabled;
    for (final track
        in _localStream?.getVideoTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = _isCameraEnabled;
    }
    return _isCameraEnabled;
  }

  Future<void> switchCamera() async {
    final tracks = _localStream?.getVideoTracks() ?? <MediaStreamTrack>[];
    if (tracks.isEmpty) {
      throw const CallException('No camera is available.');
    }
    if (kIsWeb) {
      final cameras = await Helper.cameras;
      if (cameras.length < 2) {
        throw const CallException('No other camera is available.');
      }
      final currentDeviceId =
          tracks.first.getSettings()['deviceId']?.toString();
      final nextCamera = cameras.firstWhere(
        (camera) => camera.deviceId != currentDeviceId,
        orElse: () => cameras.last,
      );
      await Helper.switchCamera(
        tracks.first,
        nextCamera.deviceId,
        _localStream,
      );
      final newTrack = _localStream!.getVideoTracks().first;
      final senders = await _peerConnection?.senders ?? [];
      for (final sender in senders) {
        if (sender.track?.kind == 'video') {
          await sender.replaceTrack(newTrack);
        }
      }
      return;
    }
    await Helper.switchCamera(tracks.first);
  }

  Future<bool> setSpeakerphone(bool enabled) async {
    _isSpeakerOn = enabled;
    if (WebRTC.platformIsAndroid || WebRTC.platformIsIOS) {
      await Helper.setSpeakerphoneOn(enabled);
    }
    return _isSpeakerOn;
  }

  Future<void> disposeMediaSession({String? callId}) async {
    if (callId != null && _activeCallId != null && callId != _activeCallId) {
      return;
    }

    await _callSubscription?.cancel();
    await _candidateSubscription?.cancel();
    _callSubscription = null;
    _candidateSubscription = null;

    for (final track in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      await track.stop();
    }
    await _localStream?.dispose();
    await _remoteStream?.dispose();
    await _peerConnection?.close();
    await _peerConnection?.dispose();

    _peerConnection = null;
    _localStream = null;
    _remoteStream = null;
    remoteStream.value = null;
    _activeCallId = null;
    _receivedCandidateIds.clear();
    _pendingCandidates.clear();
    _remoteDescriptionSet = false;
    _isMuted = false;
    _isCameraEnabled = true;
    _isSpeakerOn = false;
  }

  Future<void> _updateIncomingStatus(
    String receiverId,
    String callId,
    String status,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(receiverId)
          .collection('incoming_calls')
          .doc(callId)
          .update({'status': status});
    } on FirebaseException catch (error) {
      if (error.code != 'not-found') rethrow;
    }
  }

  Future<void> _safeDeleteIncoming(String userId, String callId) async {
    if (userId.isEmpty) return;
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('incoming_calls')
          .doc(callId)
          .delete();
    } on FirebaseException catch (error) {
      if (error.code != 'not-found' && error.code != 'permission-denied') {
        rethrow;
      }
    }
  }

  String _mediaErrorMessage(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('permission') ||
        text.contains('notallowed') ||
        text.contains('denied')) {
      return _isVideo
          ? 'Camera and microphone access are required for video calls.'
          : 'Microphone access is required for voice calls.';
    }
    if (text.contains('notfound') || text.contains('device')) {
      return _isVideo
          ? 'A camera or microphone could not be found on this device.'
          : 'A microphone could not be found on this device.';
    }
    return 'The call media could not start. Check your device and try again.';
  }
}
