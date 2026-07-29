import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../services/call_service.dart';
import '../../../widgets/active_call_overlay.dart';
import 'video_call_screen.dart';

class CallsTab extends StatefulWidget {
  const CallsTab({super.key});

  @override
  State<CallsTab> createState() => _CallsTabState();
}

class _CallsTabState extends State<CallsTab> {
  final CallService _callService = CallService();
  String? _startingRecipientId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _callService.watchCallHistory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _emptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Call history is unavailable',
            subtitle: 'Check your connection and try again.',
          );
        }

        final calls = [...?snapshot.data?.docs]..sort((a, b) {
            final aTime = a.data()['createdAt'];
            final bTime = b.data()['createdAt'];
            if (aTime is Timestamp && bTime is Timestamp) {
              return bTime.compareTo(aTime);
            }
            return 0;
          });

        if (calls.isEmpty) {
          return _emptyState(
            icon: Icons.call_outlined,
            title: 'No recent calls',
            subtitle: 'Voice and video calls will appear here.',
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
          children: [
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: RegentColors.green,
                  child: Icon(Icons.link_rounded, color: Colors.white),
                ),
                title: const Text(
                  'Start a new call',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Choose someone from the directory'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pushNamed(context, '/users'),
              ),
            ),
            for (final document in calls) _callTile(document.data()),
          ],
        );
      },
    );
  }

  Widget _callTile(Map<String, dynamic> call) {
    final isOutgoing = call['callerId'] == _callService.currentUserId;
    final recipientId =
        (isOutgoing ? call['receiverId'] : call['callerId'])?.toString() ?? '';
    final name =
        (isOutgoing ? call['receiverName'] : call['callerName'])?.toString() ??
            'Regent user';
    final photo =
        (isOutgoing ? call['receiverPhoto'] : call['callerPhoto'])?.toString();
    final isVideo = call['isVideo'] == true;
    final status = call['status']?.toString() ?? 'ended';
    final isMissed = status == 'missed' ||
        status == 'declined' && !isOutgoing ||
        status == 'failed';
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final isStarting = _startingRecipientId == recipientId;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: RegentColors.violet,
          backgroundImage:
              photo?.isNotEmpty == true ? NetworkImage(photo!) : null,
          child: photo?.isNotEmpty == true
              ? null
              : Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isMissed ? Colors.redAccent : null,
          ),
        ),
        subtitle: Row(
          children: [
            Icon(
              isOutgoing
                  ? Icons.call_made_rounded
                  : isMissed
                      ? Icons.call_missed_rounded
                      : Icons.call_received_rounded,
              size: 16,
              color: isMissed ? Colors.redAccent : RegentColors.green,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                _historyLabel(call, isOutgoing),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        trailing: isStarting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                tooltip: isVideo ? 'Video call' : 'Voice call',
                icon: Icon(
                  isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                  color: RegentColors.green,
                ),
                onPressed: recipientId.isEmpty
                    ? null
                    : () => _startCall(
                          recipientId: recipientId,
                          recipientName: name,
                          recipientPhoto: photo,
                          isVideo: isVideo,
                        ),
              ),
      ),
    );
  }

  String _historyLabel(Map<String, dynamic> call, bool isOutgoing) {
    final createdAt = call['createdAt'];
    final date = createdAt is Timestamp ? createdAt.toDate() : null;
    final direction = isOutgoing ? 'Outgoing' : 'Incoming';
    final status = call['status']?.toString();
    final statusText = switch (status) {
      'missed' => 'Missed',
      'declined' => 'Declined',
      'failed' => 'Failed',
      _ => direction,
    };
    if (date == null) return statusText;

    final now = DateTime.now();
    final sameDay =
        now.year == date.year && now.month == date.month && now.day == date.day;
    final formatted = sameDay
        ? DateFormat.jm().format(date)
        : DateFormat('MMM d, h:mm a').format(date);
    return '$statusText · $formatted';
  }

  Future<void> _startCall({
    required String recipientId,
    required String recipientName,
    required String? recipientPhoto,
    required bool isVideo,
  }) async {
    if (_startingRecipientId != null) return;
    setState(() => _startingRecipientId = recipientId);
    try {
      final currentUser = await FirebaseFirestore.instance
          .collection('users')
          .doc(_callService.currentUserId)
          .get();
      final data = currentUser.data();
      final callerName = data?['fullName'] ??
          data?['displayName'] ??
          data?['email'] ??
          'Regent user';
      final callId = await _callService.initiateCall(
        receiverId: recipientId,
        receiverName: recipientName,
        callerName: callerName.toString(),
        isVideo: isVideo,
        callerPhoto: data?['photoUrl']?.toString(),
        receiverPhoto: recipientPhoto,
      );
      if (!mounted) return;
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoCallScreen(
            callId: callId,
            recipientId: recipientId,
            recipientName: recipientName,
            recipientPhoto: recipientPhoto,
            isVideo: isVideo,
          ),
        ),
      );
      if (result is Map && result['minimized'] == true) {
        final callData = result['callData'];
        if (callData is Map<String, dynamic>) {
          activeCallOverlayKey.currentState?.setMinimizedCall(callData);
        }
      }
    } on CallException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The call could not be started.')),
        );
      }
    } finally {
      if (mounted) setState(() => _startingRecipientId = null);
    }
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 68, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/users'),
              icon: const Icon(Icons.add_call),
              label: const Text('Start a call'),
              style: ElevatedButton.styleFrom(
                backgroundColor: RegentColors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
