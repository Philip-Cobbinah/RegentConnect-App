import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/theme.dart';
import '../../../services/call_service.dart';

class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({
    super.key,
    required this.callId,
    required this.recipientId,
    required this.recipientName,
    this.recipientPhoto,
    required this.isVideo,
    this.isIncoming = false,
  });

  final String callId;
  final String recipientId;
  final String recipientName;
  final String? recipientPhoto;
  final bool isVideo;
  final bool isIncoming;

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final CallService _callService = CallService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  bool _renderersReady = false;
  bool _isStartingMedia = true;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isVideoOn = true;
  bool _isLeaving = false;
  String _callStatus = 'Calling...';
  String? _mediaError;
  int _callDuration = 0;
  Timer? _callTimer;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _callStatusSubscription;

  bool get _hasRemoteVideo =>
      _remoteRenderer.srcObject?.getVideoTracks().isNotEmpty == true;

  @override
  void initState() {
    super.initState();
    _callStatus = widget.isIncoming ? 'Connecting...' : 'Calling...';
    _isSpeakerOn = widget.isVideo;
    _listenToCallStatus();
    _initializeMedia();
  }

  Future<void> _initializeMedia() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      _renderersReady = true;
      _callService.remoteStream.addListener(_syncRemoteStream);

      if (_callService.activeCallId != widget.callId ||
          !_callService.hasMediaSession) {
        if (widget.isIncoming) {
          await _callService.startIncomingSession(
            callId: widget.callId,
            isVideo: widget.isVideo,
          );
        } else {
          await _callService.startOutgoingSession(
            callId: widget.callId,
            isVideo: widget.isVideo,
          );
        }
      }

      _localRenderer.srcObject = _callService.localStream;
      _syncRemoteStream();
      _isMuted = _callService.isMuted;
      _isSpeakerOn = _callService.isSpeakerOn;
      _isVideoOn = _callService.isCameraEnabled;
      if (mounted) {
        setState(() => _isStartingMedia = false);
      }
    } catch (error) {
      final message = error is CallException
          ? error.message
          : 'The call could not access your microphone or camera.';
      if (mounted) {
        setState(() {
          _isStartingMedia = false;
          _mediaError = message;
          _callStatus = 'Could not connect';
        });
      }
      try {
        await _callService.updateCallStatus(widget.callId, 'failed');
      } catch (_) {
        // The call may already have been closed by the other participant.
      }
    }
  }

  void _syncRemoteStream() {
    if (!_renderersReady) return;
    _remoteRenderer.srcObject = _callService.remoteStream.value;
    if (mounted) setState(() {});
  }

  void _listenToCallStatus() {
    _callStatusSubscription =
        _callService.listenToCallStatus(widget.callId).listen((snapshot) {
      if (!snapshot.exists) {
        _closeAfterRemoteEnd();
        return;
      }

      final data = snapshot.data();
      final status = data?['status']?.toString() ?? 'ended';
      if (!mounted) return;
      setState(() {
        switch (status) {
          case 'calling':
            _callStatus =
                data?['isReceiverOnline'] == true ? 'Calling...' : 'Calling...';
          case 'ringing':
            _callStatus = 'Ringing...';
          case 'connecting':
            _callStatus = 'Connecting...';
          case 'connected':
            _callStatus = 'Connected';
            _startCallTimer(data?['connectedAt']);
          case 'declined':
            _callStatus = 'Call declined';
            _closeAfterRemoteEnd();
          case 'missed':
            _callStatus = 'No answer';
            _closeAfterRemoteEnd();
          case 'failed':
            _callStatus = 'Could not connect';
            if (_mediaError == null) _closeAfterRemoteEnd();
          case 'ended':
            _callStatus = 'Call ended';
            _closeAfterRemoteEnd();
        }
      });
    });

    if (!widget.isIncoming) {
      Future<void>.delayed(const Duration(seconds: 60), () async {
        if (!mounted || _isLeaving) return;
        if (_callStatus == 'Calling...' || _callStatus == 'Ringing...') {
          await _callService.updateCallStatus(widget.callId, 'missed');
        }
      });
    }
  }

  void _startCallTimer(dynamic connectedAt) {
    if (_callTimer != null) return;
    if (connectedAt is Timestamp) {
      _callDuration = DateTime.now()
          .difference(connectedAt.toDate())
          .inSeconds
          .clamp(0, 86400);
    }
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callDuration++);
    });
  }

  void _closeAfterRemoteEnd() {
    if (_isLeaving || _mediaError != null) return;
    _isLeaving = true;
    Future<void>.delayed(const Duration(milliseconds: 900), () async {
      await _callService.disposeMediaSession(callId: widget.callId);
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _endCall() async {
    if (_isLeaving) return;
    _isLeaving = true;
    _callTimer?.cancel();
    try {
      await _callService.endCall(widget.callId, widget.recipientId);
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _minimizeCall() {
    if (_isLeaving || _mediaError != null) return;
    Navigator.of(context).pop({
      'minimized': true,
      'callId': widget.callId,
      'callData': {
        'callId': widget.callId,
        'callerId':
            widget.isIncoming ? widget.recipientId : _callService.currentUserId,
        'callerName': widget.isIncoming ? widget.recipientName : 'You',
        'callerPhoto': widget.isIncoming ? widget.recipientPhoto : null,
        'receiverId':
            widget.isIncoming ? _callService.currentUserId : widget.recipientId,
        'receiverName': widget.isIncoming ? 'You' : widget.recipientName,
        'receiverPhoto': widget.isIncoming ? null : widget.recipientPhoto,
        'isVideo': widget.isVideo,
        'status': _callStatus == 'Connected' ? 'connected' : 'connecting',
      },
    });
  }

  Future<void> _toggleMute() async {
    final muted = await _callService.toggleMute();
    if (mounted) setState(() => _isMuted = muted);
  }

  Future<void> _toggleSpeaker() async {
    final enabled = await _callService.setSpeakerphone(!_isSpeakerOn);
    if (mounted) setState(() => _isSpeakerOn = enabled);
  }

  Future<void> _toggleVideo() async {
    final enabled = await _callService.toggleCamera();
    if (mounted) setState(() => _isVideoOn = enabled);
  }

  Future<void> _switchCamera() async {
    try {
      await _callService.switchCamera();
      _localRenderer.srcObject = null;
      _localRenderer.srcObject = _callService.localStream;
    } on CallException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remaining = seconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${remaining.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${remaining.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _callStatusSubscription?.cancel();
    _callService.remoteStream.removeListener(_syncRemoteStream);
    if (_renderersReady) {
      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;
      _localRenderer.dispose();
      _remoteRenderer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _minimizeCall();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF07130F),
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildBackdrop(),
              if (!widget.isVideo || !_hasRemoteVideo) _buildRecipientDetails(),
              if (!widget.isVideo && _renderersReady)
                Positioned(
                  left: 0,
                  top: 0,
                  child: SizedBox(
                    width: 1,
                    height: 1,
                    child: RTCVideoView(_remoteRenderer),
                  ),
                ),
              if (widget.isVideo && _renderersReady && _isVideoOn)
                Positioned(
                  top: 70,
                  right: 16,
                  child: _buildLocalPreview(),
                ),
              Positioned(
                top: 8,
                left: 8,
                child: IconButton.filledTonal(
                  tooltip: 'Minimize call',
                  onPressed: _mediaError == null ? _minimizeCall : null,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  style: IconButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.black38,
                  ),
                ),
              ),
              if (widget.isVideo && _hasRemoteVideo)
                Positioned(
                  top: 18,
                  left: 64,
                  right: 132,
                  child: _buildCompactCallHeader(),
                ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 18,
                child: _buildControls(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackdrop() {
    if (widget.isVideo && _renderersReady && _hasRemoteVideo) {
      return RTCVideoView(
        _remoteRenderer,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      );
    }
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF11251E),
            Color(0xFF07130F),
            Color(0xFF1B1530),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientDetails() {
    return Align(
      alignment: const Alignment(0, -0.2),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAvatar(72),
            const SizedBox(height: 24),
            Text(
              widget.recipientName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _callStatus == 'Connected'
                  ? _formatDuration(_callDuration)
                  : _callStatus,
              style: TextStyle(
                color: _statusColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.isVideo ? Icons.videocam_rounded : Icons.lock_rounded,
                  size: 15,
                  color: Colors.white60,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.isVideo
                      ? 'RegentConnect video call'
                      : 'Peer-to-peer voice call',
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
            if (_isStartingMedia) ...[
              const SizedBox(height: 22),
              const CircularProgressIndicator(
                color: RegentColors.lightViolet,
                strokeWidth: 2,
              ),
            ],
            if (_mediaError != null) ...[
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.redAccent),
                ),
                child: Text(
                  _mediaError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompactCallHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.recipientName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 17,
            shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
          ),
        ),
        Text(
          _callStatus == 'Connected'
              ? _formatDuration(_callDuration)
              : _callStatus,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
          ),
        ),
      ],
    );
  }

  Widget _buildLocalPreview() {
    return Container(
      width: 104,
      height: 148,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white38),
        boxShadow: const [
          BoxShadow(
              color: Colors.black45, blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: _localRenderer.srcObject == null
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : RTCVideoView(
              _localRenderer,
              mirror: true,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xE61B2420),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white12),
        boxShadow: const [
          BoxShadow(
              color: Colors.black45, blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _controlButton(
            icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: _isMuted ? 'Unmute' : 'Mute',
            onPressed: _mediaError == null ? _toggleMute : null,
            selected: _isMuted,
          ),
          _controlButton(
            icon:
                _isSpeakerOn ? Icons.volume_up_rounded : Icons.hearing_rounded,
            label: 'Speaker',
            onPressed: _mediaError == null ? _toggleSpeaker : null,
            selected: _isSpeakerOn,
          ),
          if (widget.isVideo)
            _controlButton(
              icon: _isVideoOn
                  ? Icons.videocam_rounded
                  : Icons.videocam_off_rounded,
              label: 'Camera',
              onPressed: _mediaError == null ? _toggleVideo : null,
              selected: !_isVideoOn,
            ),
          if (widget.isVideo)
            _controlButton(
              icon: Icons.cameraswitch_rounded,
              label: 'Flip',
              onPressed:
                  _mediaError == null && _isVideoOn ? _switchCamera : null,
            ),
          _controlButton(
            icon: Icons.call_end_rounded,
            label: 'End',
            onPressed: _endCall,
            destructive: true,
          ),
        ],
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool selected = false,
    bool destructive = false,
  }) {
    final background = destructive
        ? const Color(0xFFE53935)
        : selected
            ? Colors.white
            : Colors.white12;
    final foreground =
        selected && !destructive ? const Color(0xFF14201B) : Colors.white;
    return Semantics(
      button: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onPressed,
            tooltip: label,
            icon: Icon(icon),
            iconSize: destructive ? 28 : 25,
            style: IconButton.styleFrom(
              backgroundColor: background,
              foregroundColor: foreground,
              disabledBackgroundColor: Colors.white10,
              disabledForegroundColor: Colors.white30,
              minimumSize: const Size(52, 52),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(double radius) {
    final initial = widget.recipientName.trim().isEmpty
        ? '?'
        : widget.recipientName.trim()[0].toUpperCase();
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: RegentColors.lightViolet, width: 2),
        boxShadow: [
          BoxShadow(
            color: RegentColors.violet.withValues(alpha: 0.35),
            blurRadius: 28,
          ),
        ],
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: RegentColors.violet,
        backgroundImage: widget.recipientPhoto?.isNotEmpty == true
            ? NetworkImage(widget.recipientPhoto!)
            : null,
        child: widget.recipientPhoto?.isNotEmpty == true
            ? null
            : Text(
                initial,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: radius * 0.68,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Color get _statusColor {
    switch (_callStatus) {
      case 'Connected':
        return Colors.greenAccent;
      case 'Could not connect':
      case 'Call declined':
      case 'No answer':
        return Colors.redAccent;
      default:
        return Colors.white70;
    }
  }
}
