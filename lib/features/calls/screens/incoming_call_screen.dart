import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../services/call_service.dart';
import '../../../services/notification_service.dart';
import 'video_call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.callerId,
    required this.callerName,
    this.callerPhoto,
    required this.isVideo,
  });

  final String callId;
  final String callerId;
  final String callerName;
  final String? callerPhoto;
  final bool isVideo;

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  final CallService _callService = CallService();
  final NotificationService _notificationService = NotificationService();

  late final AnimationController _animationController;
  late final Animation<double> _pulseAnimation;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _statusSubscription;
  bool _isResponding = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1, end: 1.08).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    unawaited(_callService.markRinging(widget.callId));
    _listenForCancellation();
  }

  void _listenForCancellation() {
    _statusSubscription =
        _callService.listenToCallStatus(widget.callId).listen((snapshot) {
      final status = snapshot.data()?['status']?.toString();
      if (status == null ||
          status == 'ended' ||
          status == 'missed' ||
          status == 'declined' ||
          status == 'failed') {
        unawaited(_notificationService.stopRingtone());
        if (mounted && !_isResponding) Navigator.of(context).pop();
      }
    });
  }

  Future<void> _acceptCall() async {
    if (_isResponding) return;
    setState(() => _isResponding = true);
    await _notificationService.stopRingtone();
    try {
      await _callService.acceptCall(widget.callId);
      if (!mounted) return;
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoCallScreen(
            callId: widget.callId,
            recipientId: widget.callerId,
            recipientName: widget.callerName,
            recipientPhoto: widget.callerPhoto,
            isVideo: widget.isVideo,
            isIncoming: true,
          ),
        ),
      );
      if (mounted) Navigator.of(context).pop(result);
    } on CallException catch (error) {
      if (!mounted) return;
      setState(() => _isResponding = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isResponding = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This call could not be answered.')),
      );
    }
  }

  Future<void> _declineCall() async {
    if (_isResponding) return;
    setState(() => _isResponding = true);
    await _notificationService.stopRingtone();
    try {
      await _callService.declineCall(widget.callId, widget.callerId);
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initial =
        widget.callerName.isEmpty ? '?' : widget.callerName[0].toUpperCase();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_declineCall());
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF07130F),
        body: SafeArea(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF17382D),
                  Color(0xFF07130F),
                  Color(0xFF1B1530),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 48),
                  Text(
                    widget.isVideo
                        ? 'Incoming video call'
                        : 'Incoming voice call',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: RegentColors.lightViolet,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: RegentColors.violet.withValues(alpha: 0.3),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 72,
                        backgroundColor: RegentColors.violet,
                        backgroundImage: widget.callerPhoto?.isNotEmpty == true
                            ? NetworkImage(widget.callerPhoto!)
                            : null,
                        child: widget.callerPhoto?.isNotEmpty == true
                            ? null
                            : Text(
                                initial,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 56,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 34),
                  Text(
                    widget.callerName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 31,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_rounded,
                        color: Colors.white54,
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.isVideo
                            ? 'RegentConnect video call'
                            : 'Peer-to-peer voice call',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (_isResponding)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 26),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 54),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _responseButton(
                          icon: Icons.call_end_rounded,
                          label: 'Decline',
                          color: const Color(0xFFE53935),
                          onPressed: _isResponding ? null : _declineCall,
                        ),
                        _responseButton(
                          icon: widget.isVideo
                              ? Icons.videocam_rounded
                              : Icons.call_rounded,
                          label: 'Accept',
                          color: const Color(0xFF22A559),
                          onPressed: _isResponding ? null : _acceptCall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _responseButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          tooltip: label,
          icon: Icon(icon),
          iconSize: 31,
          style: IconButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            disabledBackgroundColor: color.withValues(alpha: 0.45),
            minimumSize: const Size(68, 68),
          ),
        ),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}
