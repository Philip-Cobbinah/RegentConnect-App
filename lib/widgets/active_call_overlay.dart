import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/theme.dart';
import '../services/call_service.dart';
import '../features/calls/screens/video_call_screen.dart';

class ActiveCallOverlay extends StatefulWidget {
  final Widget child;

  const ActiveCallOverlay({super.key, required this.child});

  @override
  State<ActiveCallOverlay> createState() => ActiveCallOverlayState();
}

class ActiveCallOverlayState extends State<ActiveCallOverlay>
    with SingleTickerProviderStateMixin {
  final CallService _callService = CallService();

  Map<String, dynamic>? _activeCall;
  bool _isMinimized = false;
  int _callDuration = 0;
  Timer? _durationTimer;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _callSubscription;
  StreamSubscription<User?>? _authSubscription;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        _durationTimer?.cancel();
        _callSubscription?.cancel();
        if (mounted && (_activeCall != null || _isMinimized)) {
          setState(() {
            _activeCall = null;
            _isMinimized = false;
            _callDuration = 0;
          });
        }
        return;
      }
      _checkForActiveCall();
    });
  }

  void _checkForActiveCall() async {
    if (_callService.currentUserId.isEmpty) return;

    try {
      final call = await _callService.getCurrentCall();
      if (!mounted) return;
      if (call != null &&
          const {'calling', 'ringing', 'connecting', 'connected'}
              .contains(call['status'])) {
        setState(() {
          _activeCall = call;
          _isMinimized = true;
        });
        _startListening(call['callId']);
        if (call['status'] == 'connected') {
          _startDurationTimer(call['connectedAt']);
        }
      }
    } on FirebaseException catch (error) {
      debugPrint('Unable to restore active call: ${error.message}');
    }
  }

  void setMinimizedCall(Map<String, dynamic> callData) {
    if (!mounted) return;
    setState(() {
      _activeCall = callData;
      _isMinimized = true;
    });
    _startListening(callData['callId']);
    if (callData['status'] == 'connected') {
      _startDurationTimer(callData['connectedAt']);
    }
  }

  void _startListening(String callId) {
    _callSubscription?.cancel();
    _callSubscription =
        _callService.listenToCallStatus(callId).listen((snapshot) {
      if (!snapshot.exists) {
        _clearActiveCall();
        return;
      }

      final data = snapshot.data()!;
      if (!mounted || _activeCall == null) return;
      setState(() {
        _activeCall = {..._activeCall!, ...data};
      });

      if (const {'ended', 'declined', 'missed', 'failed'}
          .contains(data['status'])) {
        _clearActiveCall();
      } else if (data['status'] == 'connected' && _durationTimer == null) {
        _startDurationTimer(data['connectedAt']);
      }
    });
  }

  void _startDurationTimer(dynamic connectedAt) {
    _durationTimer?.cancel();
    if (connectedAt is Timestamp) {
      _callDuration = DateTime.now()
          .difference(connectedAt.toDate())
          .inSeconds
          .clamp(0, 86400);
    }
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _callDuration++);
    });
  }

  void _clearActiveCall() {
    _durationTimer?.cancel();
    _callSubscription?.cancel();
    if (!mounted) return;
    setState(() {
      _activeCall = null;
      _isMinimized = false;
      _callDuration = 0;
    });
  }

  void _expandCall() {
    if (_activeCall == null) return;

    final isCaller = _activeCall!['callerId'] == _callService.currentUserId;
    final recipientId =
        isCaller ? _activeCall!['receiverId'] : _activeCall!['callerId'];
    final recipientName =
        isCaller ? _activeCall!['receiverName'] : _activeCall!['callerName'];
    final recipientPhoto =
        isCaller ? _activeCall!['receiverPhoto'] : _activeCall!['callerPhoto'];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoCallScreen(
          callId: _activeCall!['callId'],
          recipientId: recipientId,
          recipientName: recipientName ?? 'Unknown',
          recipientPhoto: recipientPhoto,
          isVideo: _activeCall!['isVideo'] ?? false,
          isIncoming: !isCaller,
        ),
      ),
    ).then((result) {
      if (result != null && result is Map && result['minimized'] == true) {
        // Call was minimized again, keep showing overlay
      } else {
        // Check if call is still active
        _checkForActiveCall();
      }
    });
  }

  Future<void> _endCall() async {
    if (_activeCall == null) return;

    final isCaller = _activeCall!['callerId'] == _callService.currentUserId;
    final otherUserId =
        isCaller ? _activeCall!['receiverId'] : _activeCall!['callerId'];

    final callId = _activeCall!['callId']?.toString();
    if (callId == null) return;
    _clearActiveCall();
    try {
      await _callService.endCall(callId, otherUserId);
    } on FirebaseException catch (error) {
      debugPrint('Unable to end call: ${error.message}');
    }
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _callSubscription?.cancel();
    _authSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Add padding to child when call is active
        Padding(
          padding: EdgeInsets.only(
              top: _isMinimized && _activeCall != null ? 70 : 0),
          child: widget.child,
        ),
        // Call banner
        if (_isMinimized && _activeCall != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: GestureDetector(
                onTap: _expandCall,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            RegentColors.green,
                            RegentColors.green.withOpacity(
                                0.8 + (_pulseController.value * 0.2)),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: RegentColors.green.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Pulsing call icon
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _activeCall!['isVideo'] == true
                                  ? Icons.videocam
                                  : Icons.call,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Call info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _activeCall!['callerId'] ==
                                                _callService.currentUserId
                                            ? _activeCall!['receiverName'] ??
                                                'Unknown'
                                            : _activeCall!['callerName'] ??
                                                'Unknown',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        _formatDuration(_callDuration),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.touch_app,
                                      color: Colors.white.withOpacity(0.8),
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Tap to return to call',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // End call button
                          GestureDetector(
                            onTap: () => _endCall(),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.call_end,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// Global key to access the overlay state
final GlobalKey<ActiveCallOverlayState> activeCallOverlayKey =
    GlobalKey<ActiveCallOverlayState>();
